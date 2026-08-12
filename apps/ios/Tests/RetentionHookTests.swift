import XCTest
import SimulationCore
@testable import BaseballIOS

/// 리텐션 훅(연속 기록·복귀 알림)의 순수 판정.
///
/// 배경: 2026-08 정식 신규 코호트는 첫날 평균 11.6경기를 했지만 D1 의미 세션은 5/36이었다.
/// 첫날 플레이를 제한하는 대신, 사용자가 직접 남긴 목표를 3일 비반복 알림과 정확한 화면으로
/// 이어 준다. 여기 있는 판정들은 그 복귀 약속과 기존 일일 연속 기록을 함께 고정한다.
final class RetentionHookTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "RetentionHookTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    /// 서울 자정 기준의 날짜 키. 판이 서울 자정에 바뀌므로 연속 판정도 같은 경계를 쓴다.
    private func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.date(from: text)!
    }

    private func markPlayed(_ days: [String]) {
        for day in days {
            defaults.set(true, forKey: DailyStreak.playedKeyPrefix + day)
        }
    }

    // MARK: - 연속 기록

    func testStreakCountsConsecutiveDaysBackwards() {
        markPlayed(["20260807", "20260808", "20260809"])
        XCTAssertEqual(DailyStreak.current(now: date("2026-08-09 21:00"), defaults: defaults), 3)
    }

    /// 오늘을 아직 안 했어도 어제까지의 연속은 살아 있어야 한다. 그래야 "오늘 던지면
    /// N+1일째"를 말할 수 있고, 그 문장이 오늘 켜는 유일한 이유다.
    func testStreakSurvivesUntilTodayEndsSoTheNudgeCanSayNextDay() {
        markPlayed(["20260807", "20260808"])
        let now = date("2026-08-09 10:00")
        XCTAssertEqual(DailyStreak.current(now: now, defaults: defaults), 2)
        XCTAssertFalse(DailyStreak.playedToday(now: now, defaults: defaults))
        XCTAssertEqual(DailyStreak.caption(now: now, defaults: defaults), "2일 연속 — 오늘 던지면 3일째")
    }

    func testStreakBreaksWhenADayIsMissed() {
        markPlayed(["20260805", "20260806", "20260808"])
        // 8/9은 아직 안 했고 8/8은 했다 — 8/7이 비어 있으므로 연속은 1이다.
        XCTAssertEqual(DailyStreak.current(now: date("2026-08-09 10:00"), defaults: defaults), 1)
    }

    func testStreakIsZeroAndCaptionAbsentWithoutHistory() {
        let now = date("2026-08-09 10:00")
        XCTAssertEqual(DailyStreak.current(now: now, defaults: defaults), 0)
        XCTAssertNil(DailyStreak.caption(now: now, defaults: defaults), "0일째를 자랑하면 안 됩니다")
    }

    /// 자정을 넘겨 어제도 비면 끊긴다.
    func testStreakResetsAfterTwoIdleDays() {
        markPlayed(["20260806", "20260807"])
        XCTAssertEqual(DailyStreak.current(now: date("2026-08-09 10:00"), defaults: defaults), 0)
    }

    // MARK: - 복귀 알림 예약

    /// 반복 트리거를 쓰지 않는다 — 떠난 사람에게 영원히 울리기 때문이다.
    /// 앞으로 며칠치만 예약하고, 앱을 열지 않으면 저절로 조용해져야 한다.
    func testScheduleCoversOnlyTheHorizon() {
        let entries = DailyReminder.schedule(from: date("2026-08-09 10:00"), horizon: 3)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries.map(\.id), [
            DailyReminder.requestPrefix + "20260809",
            DailyReminder.requestPrefix + "20260810",
            DailyReminder.requestPrefix + "20260811",
        ])
    }

    /// 이미 지난 시각은 예약하지 않는다 — iOS가 즉시 발사해서 "지금 저녁 7시 30분입니다"
    /// 알림이 밤 11시에 튀어나온다.
    func testScheduleSkipsTodayWhenTheHourHasPassed() {
        let entries = DailyReminder.schedule(from: date("2026-08-09 23:00"), horizon: 3)
        XCTAssertEqual(entries.first?.id, DailyReminder.requestPrefix + "20260810")
        XCTAssertEqual(entries.count, 2, "오늘 몫이 빠지고 남은 이틀만 남아야 합니다")
    }

    /// 이미 던진 날은 부르지 않는다. 한 일을 하라고 부르면 다음 알림까지 통째로 무시된다.
    func testScheduleSkipsDaysAlreadyPlayed() {
        let entries = DailyReminder.schedule(
            from: date("2026-08-09 10:00"), horizon: 3, playedKeys: ["20260809", "20260810"]
        )
        XCTAssertEqual(entries.map(\.id), [DailyReminder.requestPrefix + "20260811"])
    }

    /// 첫날 실제 유저는 평균 2회차 이상을 끝냈다. 다음날 알림은 막연한 출석 요구가
    /// 아니라 사용자가 직접 남긴 목표와 그 화면으로 이어져야 한다.
    func testCareerReturnPlanPersistsAndBuildsMatchingDeepLinkCopy() throws {
        let plan = DailyReminder.Plan(
            title: "이번 선수의 목표가 남아 있습니다",
            body: "시즌 5탈삼진 · 탈삼진 3/5 — 이어서 완성해 보세요.",
            destination: .highSchool,
            reason: "run_pledge",
            experimentVariant: DailyReminder.ReturnExperimentVariant.guided.rawValue
        )

        DailyReminder.savePlan(plan, defaults: defaults)
        XCTAssertEqual(DailyReminder.storedPlan(defaults: defaults), plan)

        let copy = try XCTUnwrap(DailyReminder.notificationCopy(plan: plan))
        XCTAssertEqual(copy.title, plan.title)
        XCTAssertEqual(copy.body, plan.body)
        XCTAssertEqual(copy.link, "com.solkim.baseball.ios://high-school")
        XCTAssertEqual(copy.destination, "high_school")
        XCTAssertEqual(copy.reason, "run_pledge")
        XCTAssertFalse(copy.body.contains("7일 연속"), "커리어 목표를 출석 문구로 덮으면 안 됩니다")

        DailyReminder.savePlan(nil, defaults: defaults)
        XCTAssertNil(DailyReminder.storedPlan(defaults: defaults))
    }

    func testUITestResetClearsReturnPlanAndHandledWelcome() {
        let plan = DailyReminder.Plan(
            title: "이번 선수의 목표가 남아 있습니다",
            body: "탈삼진 4/5",
            destination: .highSchool,
            reason: "run_pledge"
        )
        DailyReminder.savePlan(plan, defaults: defaults)
        DailyReminder.markWelcomeHandled(
            plan,
            now: date("2026-08-10 12:00"),
            defaults: defaults
        )
        XCTAssertNotNil(DailyReminder.storedPlan(defaults: defaults))
        XCTAssertNotNil(DailyReminder.storedWelcomeHandled(defaults: defaults))

        DailyReminder.resetForUITesting(defaults: defaults)

        XCTAssertNil(DailyReminder.storedPlan(defaults: defaults))
        XCTAssertNil(DailyReminder.storedWelcomeHandled(defaults: defaults))
    }

    /// 첫 설치에는 카드가 없고, 한 번 떠났다가 돌아왔을 때만 현재 진행을 보여 준다.
    func testWelcomePlanRequiresAPreviousSessionAndUsesCurrentProgress() {
        let previous = DailyReminder.Plan(
            title: "이번 선수의 목표가 남아 있습니다",
            body: "탈삼진 2/5",
            destination: .highSchool,
            reason: "run_pledge",
            receiptID: "receipt-a",
            savedDayKey: "20260809",
            experimentVariant: DailyReminder.ReturnExperimentVariant.guided.rawValue,
            developmentRulesVersion: 4
        )
        let current = DailyReminder.Plan(
            title: "이번 선수의 목표가 남아 있습니다",
            body: "탈삼진 4/5",
            destination: .highSchool,
            reason: "run_pledge"
        )

        XCTAssertNil(DailyReminder.welcomePlan(previous: nil, current: current))
        XCTAssertEqual(DailyReminder.welcomePlan(previous: previous, current: current), current)
        XCTAssertNil(DailyReminder.welcomePlan(previous: previous, current: nil))
    }

    func testHandledWelcomePlanDoesNotNagAgainUntilThePlanOrDayChanges() {
        let previous = DailyReminder.Plan(
            title: "이번 선수의 목표가 남아 있습니다",
            body: "탈삼진 2/5",
            destination: .highSchool,
            reason: "run_pledge",
            receiptID: "receipt-a",
            savedDayKey: "20260809",
            experimentVariant: DailyReminder.ReturnExperimentVariant.guided.rawValue,
            developmentRulesVersion: 4
        )
        let current = DailyReminder.Plan(
            title: "이번 선수의 목표가 남아 있습니다",
            body: "탈삼진 4/5",
            destination: .highSchool,
            reason: "run_pledge"
        )
        let today = date("2026-08-10 12:00")
        let tomorrow = date("2026-08-11 12:00")

        DailyReminder.markWelcomeHandled(current, now: today, defaults: defaults)
        let handled = DailyReminder.storedWelcomeHandled(defaults: defaults)

        XCTAssertNil(DailyReminder.welcomePlan(
            previous: previous, current: current, handled: handled, now: today
        ))
        XCTAssertEqual(DailyReminder.welcomePlan(
            previous: previous, current: current, handled: handled, now: tomorrow
        ), current)
        XCTAssertEqual(DailyReminder.welcomePlan(
            previous: previous, current: previous, handled: handled, now: today
        ), previous, "진행 문구가 달라지면 같은 날에도 새 목표를 보여 줘야 합니다")
    }

    func testReturnPlanButtonsNameTheActualDestination() {
        XCTAssertEqual(DailyReminder.Destination.highSchool.continueTitle, "이 선수 이어서 키우기")
        XCTAssertEqual(DailyReminder.Destination.pro.continueTitle, "프로 시즌 이어가기")
        XCTAssertEqual(DailyReminder.Destination.dailyInning.continueTitle, "게임으로 돌아가기")
    }

    @MainActor
    func testReturnCopyMatchesTheActualPrologueAction() {
        XCTAssertEqual(
            BaseballApp.highSchoolReturnDetail(for: .prologue),
            "감독이 기다립니다. 불펜에서 첫 공을 던질 차례입니다."
        )
        XCTAssertNotEqual(
            BaseballApp.highSchoolReturnDetail(for: .prologue),
            BaseballApp.highSchoolReturnDetail(for: .schoolSelection)
        )
    }

    @MainActor
    func testReturnExperimentRulesVersionFollowsItsResolvedDestination() {
        XCTAssertEqual(
            BaseballApp.developmentRulesVersion(
                for: .pro,
                proRulesVersion: 4,
                highSchoolRulesVersion: 3
            ),
            4,
            "활성 프로와 옛 고교 저장이 함께 있어도 프로 경기와 같은 코호트여야 합니다"
        )
        XCTAssertEqual(
            BaseballApp.developmentRulesVersion(
                for: .highSchool,
                proRulesVersion: 4,
                highSchoolRulesVersion: 3
            ),
            3
        )
        XCTAssertEqual(
            BaseballApp.developmentRulesVersion(
                for: .dailyInning,
                proRulesVersion: 3,
                highSchoolRulesVersion: 3
            ),
            PitcherPresetCatalog.balanceVersion,
            "기록에 남지 않는 도전의 일일 fallback은 현재 규칙으로 비교합니다"
        )
    }

    func testRetiredDestinationAndMissingPlanNeverCreateANotification() {
        XCTAssertNil(DailyReminder.notificationCopy(plan: nil))
        let retired = DailyReminder.Plan(
            title: "이전 알림", body: "이전 목적지",
            destination: .dailyInning, reason: "legacy",
            experimentVariant: DailyReminder.ReturnExperimentVariant.guided.rawValue
        )
        XCTAssertNil(DailyReminder.notificationCopy(plan: retired))
    }

    func testReminderOpenedPropertiesSupportNewAndLegacyRequests() {
        let current = DailyReminder.openedProperties(userInfo: [
            DailyReminder.linkUserInfoKey: "com.solkim.baseball.ios://pro",
            DailyReminder.destinationUserInfoKey: "pro",
            DailyReminder.reasonUserInfoKey: "pro_phase",
            DailyReminder.receiptUserInfoKey: "receipt-a",
            DailyReminder.experimentUserInfoKey: DailyReminder.returnExperimentID,
            DailyReminder.variantUserInfoKey: "guided",
            DailyReminder.savedDayUserInfoKey: "20260809",
            DailyReminder.rulesVersionUserInfoKey: 4,
        ])
        XCTAssertEqual(current["destination"] as? String, "pro")
        XCTAssertEqual(current["reason"] as? String, "pro_phase")
        XCTAssertEqual(current["plan_receipt"] as? String, "receipt-a")
        XCTAssertEqual(current["variant"] as? String, "guided")
        XCTAssertEqual(current["development_rules_version"] as? Int, 4)

        let legacy = DailyReminder.openedProperties(userInfo: [
            DailyReminder.linkUserInfoKey: DailyReminder.deepLink,
        ])
        XCTAssertEqual(legacy["destination"] as? String, "daily_inning")
        XCTAssertEqual(legacy["reason"] as? String, "legacy")
        XCTAssertEqual(legacy["plan_receipt"] as? String, "legacy")
        XCTAssertEqual(legacy["development_rules_version"] as? Int, 0)
    }

    @MainActor
    func testReturnExperimentFreezesAStableReceiptVariantAndRulesVersion() {
        let base = DailyReminder.Plan(
            title: "이번 선수 이어가기", body: "다음 훈련이 기다립니다.",
            destination: .highSchool, reason: "high_school_phase"
        )
        let now = date("2026-08-09 21:00")
        let first = DailyReminder.preparedForNextReturn(
            base, stableID: "stable-player", rulesVersion: 4, now: now
        )
        let replay = DailyReminder.preparedForNextReturn(
            base, stableID: "stable-player", rulesVersion: 4, now: now
        )
        let nextDay = DailyReminder.preparedForNextReturn(
            base, stableID: "stable-player", rulesVersion: 4,
            now: date("2026-08-10 21:00")
        )
        let legacyRules = DailyReminder.preparedForNextReturn(
            base, stableID: "stable-player", rulesVersion: 3, now: now
        )

        XCTAssertEqual(first.receiptID, replay.receiptID)
        XCTAssertEqual(first.experimentID, DailyReminder.returnExperimentID)
        XCTAssertEqual(first.experimentVariant, replay.experimentVariant)
        XCTAssertEqual(first.savedDayKey, "20260809")
        XCTAssertEqual(first.developmentRulesVersion, 4)
        XCTAssertNotEqual(first.receiptID, nextDay.receiptID)
        XCTAssertNotEqual(
            first.receiptID,
            legacyRules.receiptID,
            "같은 날 같은 화면이어도 규칙 버전이 다르면 별도 D1 코호트여야 합니다"
        )

        let assignments = (0..<10_000).map {
            DailyReminder.experimentVariant(stableID: "player-\($0)")
        }
        let guidedCount = assignments.filter { $0 == .guided }.count
        XCTAssertTrue(
            4_800...5_200 ~= guidedCount,
            "안정 ID 10,000개의 50:50 배정이 허용 오차를 벗어났습니다: guided=\(guidedCount)"
        )
        XCTAssertEqual(
            assignments,
            (0..<10_000).map {
                DailyReminder.experimentVariant(stableID: "player-\($0)")
            },
            "같은 안정 ID의 실험군은 재실행해도 바뀌면 안 됩니다"
        )
    }

    func testOnlyGuidedCohortGetsPersonalizedCardAndNotification() {
        let current = DailyReminder.Plan(
            title: "프로 시즌의 다음 선택", body: "3주차 결정을 이어 가세요.",
            destination: .pro, reason: "pro_phase"
        )
        let holdout = DailyReminder.Plan(
            title: current.title, body: current.body,
            destination: current.destination, reason: current.reason,
            receiptID: "holdout-r", savedDayKey: "20260809",
            experimentVariant: DailyReminder.ReturnExperimentVariant.holdout.rawValue,
            developmentRulesVersion: 4
        )
        let guided = DailyReminder.Plan(
            title: current.title, body: current.body,
            destination: current.destination, reason: current.reason,
            receiptID: "guided-r", savedDayKey: "20260809",
            experimentVariant: DailyReminder.ReturnExperimentVariant.guided.rawValue,
            developmentRulesVersion: 4
        )

        XCTAssertNil(DailyReminder.welcomePlan(previous: holdout, current: current))
        let card = DailyReminder.welcomePlan(previous: guided, current: current)
        XCTAssertEqual(card?.receiptID, "guided-r")

        XCTAssertNil(DailyReminder.notificationCopy(plan: holdout))
        let guidedCopy = DailyReminder.notificationCopy(plan: guided)
        XCTAssertEqual(guidedCopy?.destination, "pro")
        XCTAssertEqual(guidedCopy?.reason, "pro_phase")
    }

    func testColdStartUsesNextKSTDateAndCarriesComparableProperties() {
        let plan = DailyReminder.Plan(
            title: "이번 선수 이어가기", body: "다음 훈련이 기다립니다.",
            destination: .highSchool, reason: "high_school_phase",
            experimentID: DailyReminder.returnExperimentID,
            receiptID: "receipt-a", savedDayKey: "20260809",
            experimentVariant: "guided", developmentRulesVersion: 4
        )
        XCTAssertNil(DailyReminder.coldStartProperties(
            plan, now: date("2026-08-09 23:59")
        ))
        let properties = DailyReminder.coldStartProperties(
            plan, now: date("2026-08-10 00:01")
        )
        XCTAssertEqual(properties?["day_gap"] as? Int, 1)
        XCTAssertEqual(properties?["return_day_key"] as? String, "20260810")
        XCTAssertEqual(properties?["plan_receipt"] as? String, "receipt-a")
        XCTAssertEqual(properties?["experiment_id"] as? String, DailyReminder.returnExperimentID)
        XCTAssertEqual(properties?["launch_type"] as? String, "cold")
        XCTAssertEqual(properties?["development_rules_version"] as? Int, 4)

        let warm = DailyReminder.nextDayOpenProperties(
            plan, launchType: "warm", now: date("2026-08-10 00:01")
        )
        XCTAssertEqual(warm?["launch_type"] as? String, "warm")
        XCTAssertEqual(
            DailyReminder.nextDayOpenScope(properties: properties!),
            DailyReminder.nextDayOpenScope(properties: warm!)
        )
        XCTAssertEqual(
            DailyReminder.nextDayOpenScope(properties: properties!),
            "\(DailyReminder.returnExperimentID)|receipt-a|20260810"
        )
        XCTAssertNil(DailyReminder.nextDayOpenProperties(
            plan, launchType: "cold", now: date("2026-08-09 23:59")
        ))
        XCTAssertNil(DailyReminder.nextDayOpenProperties(
            plan, launchType: "unknown", now: date("2026-08-10 00:01")
        ))
        let noReceipt = DailyReminder.Plan(
            title: plan.title, body: plan.body, destination: plan.destination,
            reason: plan.reason, experimentID: DailyReminder.returnExperimentID,
            savedDayKey: plan.savedDayKey, experimentVariant: plan.experimentVariant,
            developmentRulesVersion: plan.developmentRulesVersion
        )
        XCTAssertNil(DailyReminder.nextDayOpenProperties(
            noReceipt, launchType: "cold", now: date("2026-08-10 00:01")
        ))
    }

    func testNextDayOpenPropertiesCarryBothReturnExperimentVariants() {
        for variant in DailyReminder.ReturnExperimentVariant.allCases {
            let plan = DailyReminder.Plan(
                title: "이어가기", body: "다음 목표", destination: .highSchool,
                reason: "high_school_phase", experimentID: DailyReminder.returnExperimentID,
                receiptID: "receipt-\(variant.rawValue)", savedDayKey: "20260809",
                experimentVariant: variant.rawValue, developmentRulesVersion: 4
            )
            let properties = DailyReminder.nextDayOpenProperties(
                plan, launchType: "warm", now: date("2026-08-10 12:00")
            )
            XCTAssertEqual(properties?["variant"] as? String, variant.rawValue)
            XCTAssertEqual(properties?["day_gap"] as? Int, 1)
        }
    }

    @MainActor
    func testColdThenWarmNextDayOpenIsRecordedOnlyOnceForTheSameReceiptAndDay() {
        let plan = DailyReminder.Plan(
            title: "이어가기", body: "다음 목표", destination: .highSchool,
            reason: "high_school_phase", experimentID: DailyReminder.returnExperimentID,
            receiptID: "receipt-a", savedDayKey: "20260809",
            experimentVariant: DailyReminder.ReturnExperimentVariant.guided.rawValue,
            developmentRulesVersion: 4
        )
        let cold = DailyReminder.nextDayOpenProperties(
            plan, launchType: "cold", now: date("2026-08-10 00:01")
        )!
        let warm = DailyReminder.nextDayOpenProperties(
            plan, launchType: "warm", now: date("2026-08-10 12:00")
        )!
        let coldScope = DailyReminder.nextDayOpenScope(properties: cold)!
        let warmScope = DailyReminder.nextDayOpenScope(properties: warm)!

        XCTAssertEqual(coldScope, warmScope)
        XCTAssertTrue(GameAnalytics.logOnce(
            .returnPlanNextDayOpen, scope: coldScope, properties: cold, defaults: defaults
        ))
        XCTAssertFalse(GameAnalytics.logOnce(
            .returnPlanNextDayOpen, scope: warmScope, properties: warm, defaults: defaults
        ))
    }

    func testReturnEligibilityStartsOnlyAfterACompletedGame() {
        XCTAssertFalse(DailyReminder.ReturnPlanEligibility.isEligible(completedGameCount: 0))
        XCTAssertTrue(DailyReminder.ReturnPlanEligibility.isEligible(completedGameCount: 1))

        let ineligible = DailyReminder.sessionEndReturnProperties(
            plan: nil, completedGameCount: 0
        )
        XCTAssertEqual(ineligible["return_eligible"] as? Bool, false)
        XCTAssertEqual(ineligible["experiment_id"] as? String, "none")
        XCTAssertEqual(ineligible["variant"] as? String, "ineligible")
        XCTAssertEqual(ineligible["plan_receipt"] as? String, "none")

        let plan = DailyReminder.Plan(
            title: "이어가기", body: "다음 목표", destination: .highSchool,
            reason: "high_school_phase", experimentID: DailyReminder.returnExperimentID,
            receiptID: "receipt-a", savedDayKey: "20260809",
            experimentVariant: DailyReminder.ReturnExperimentVariant.guided.rawValue,
            developmentRulesVersion: 4
        )
        let eligible = DailyReminder.sessionEndReturnProperties(
            plan: plan, completedGameCount: 1
        )
        XCTAssertEqual(eligible["return_eligible"] as? Bool, true)
        XCTAssertEqual(eligible["experiment_id"] as? String, DailyReminder.returnExperimentID)
        XCTAssertEqual(eligible["variant"] as? String, "guided")
        XCTAssertEqual(eligible["plan_receipt"] as? String, "receipt-a")
    }

    func testLegacyPlanDecodesAndSavingCurrentCopyPreservesFrozenExperiment() throws {
        let legacy = try JSONDecoder().decode(
            DailyReminder.Plan.self,
            from: Data(#"{"title":"이어가기","body":"다음 훈련","destination":"high_school","reason":"high_school_phase"}"#.utf8)
        )
        XCTAssertNil(legacy.receiptID)
        XCTAssertNil(legacy.experimentID)
        XCTAssertNil(legacy.experimentVariant)
        XCTAssertEqual(
            DailyReminder.analyticsProperties(legacy)["experiment_id"] as? String,
            DailyReminder.legacyReturnExperimentID
        )

        let prepared = DailyReminder.Plan(
            title: legacy.title, body: legacy.body,
            destination: legacy.destination, reason: legacy.reason,
            receiptID: "receipt-a", savedDayKey: "20260809",
            experimentVariant: "guided", developmentRulesVersion: 4
        )
        DailyReminder.savePlan(prepared, defaults: defaults)
        DailyReminder.savePlan(legacy, defaults: defaults)
        let restored = DailyReminder.storedPlan(defaults: defaults)
        XCTAssertEqual(restored?.receiptID, "receipt-a")
        XCTAssertEqual(restored?.experimentVariant, "guided")
        XCTAssertEqual(restored?.developmentRulesVersion, 4)
        XCTAssertEqual(
            DailyReminder.nextDayOpenProperties(
                restored, launchType: "warm", now: date("2026-08-10 12:00")
            )?["experiment_id"] as? String,
            DailyReminder.legacyReturnExperimentID,
            "experimentID가 없던 v1 영수증을 앱 업데이트 뒤 v2로 다시 쓰면 안 됩니다"
        )
    }

    func testLegacyPlanDefaultsNewPresentationFieldsAndVersionedReferencesRoundTrip() throws {
        let legacy = try JSONDecoder().decode(
            DailyReminder.Plan.self,
            from: Data(#"{"title":"이어가기","body":"다음 훈련","destination":"high_school","reason":"high_school_phase"}"#.utf8)
        )
        XCTAssertNil(legacy.copyReferences)
        XCTAssertNil(legacy.scheduledLanguage)
        XCTAssertNil(legacy.scheduledCopySchemaVersion)

        let title = DailyReminder.SemanticCopyReference(
            key: "content.notification.return.title",
            arguments: [.contentID("high_school")]
        )
        let body = DailyReminder.SemanticCopyReference(
            schemaVersion: 3,
            key: "content.notification.return.body",
            arguments: [.integer(2), .decimal(1.5)]
        )
        let plan = DailyReminder.Plan(
            title: "legacy title",
            body: "legacy body",
            destination: .highSchool,
            reason: "high_school_phase",
            copyReferences: .init(title: title, body: body),
            scheduledLanguage: .english,
            scheduledCopySchemaVersion: 3
        )

        let restored = try JSONDecoder().decode(
            DailyReminder.Plan.self,
            from: JSONEncoder().encode(plan)
        )
        XCTAssertEqual(restored.copyReferences, plan.copyReferences)
        XCTAssertEqual(restored.scheduledLanguage, .english)
        XCTAssertEqual(restored.scheduledCopySchemaVersion, 3)
        XCTAssertEqual(restored.copyReferences?.title?.coreToken.key, title.key)
        XCTAssertEqual(
            restored.copyReferences?.body?.coreToken.arguments,
            [.integer(2), .decimal(1.5)]
        )
        XCTAssertEqual(restored.destination, plan.destination)
        XCTAssertEqual(restored.reason, plan.reason)

        DailyReminder.savePlan(plan, defaults: defaults)
        let defaultsRestored = DailyReminder.storedPlan(defaults: defaults)
        XCTAssertEqual(defaultsRestored?.copyReferences, plan.copyReferences)
        XCTAssertEqual(defaultsRestored?.scheduledLanguage, .english)
        XCTAssertEqual(defaultsRestored?.scheduledCopySchemaVersion, 3)
    }

    func testSemanticNotificationReferencesResolveWithoutLegacyKoreanLookup() throws {
        let title = DailyReminder.SemanticCopyReference(
            key: "content.notification.return.title",
            arguments: []
        )
        let body = DailyReminder.SemanticCopyReference(
            key: "content.notification.return.body",
            arguments: [.contentID("high_school")]
        )
        let plan = DailyReminder.Plan(
            title: "옛 한국어 제목",
            body: "옛 한국어 본문",
            destination: .highSchool,
            reason: "high_school_phase",
            experimentVariant: DailyReminder.ReturnExperimentVariant.guided.rawValue,
            copyReferences: .init(title: title, body: body)
        )
        let resolver = GameCopyResolver(
            language: .english,
            catalog: [
                .english: [
                    title.key: "Return to the mound",
                    body.key: "Your next move at %@ is waiting.",
                ],
                .korean: [
                    title.key: "마운드로 돌아오세요",
                    body.key: "%@에서 다음 행동이 기다립니다.",
                ],
            ]
        )

        let copy = try XCTUnwrap(DailyReminder.notificationCopy(plan: plan, resolver: resolver))
        XCTAssertEqual(copy.title, "Return to the mound")
        XCTAssertEqual(copy.body, "Your next move at high_school is waiting.")
        XCTAssertFalse(copy.title.contains("옛 한국어"))
        XCTAssertFalse(copy.body.contains("옛 한국어"))
    }

    func testLegacyNotificationPlanUsesReviewedGenericCopyInEnglish() throws {
        let plan = DailyReminder.Plan(
            title: "옛 한국어 제목",
            body: "옛 한국어 본문",
            destination: .highSchool,
            reason: "high_school_phase",
            experimentVariant: DailyReminder.ReturnExperimentVariant.guided.rawValue
        )
        let resolver = GameCopyResolver(
            language: .english,
            catalog: [
                .english: [
                    GameCopyKey.notificationReturnTitle.rawValue: "Return to the mound",
                    GameCopyKey.notificationReturnBody.rawValue: "Your next baseball decision is waiting.",
                ],
            ]
        )

        let copy = try XCTUnwrap(DailyReminder.notificationCopy(plan: plan, resolver: resolver))
        XCTAssertEqual(copy.title, "Return to the mound")
        XCTAssertEqual(copy.body, "Your next baseball decision is waiting.")
        XCTAssertFalse(copy.title.contains("한국어"))
        XCTAssertFalse(copy.body.contains("한국어"))
    }

    func testLanguageOrCopySchemaChangeReschedulesWithoutChangingPlanIdentity() {
        let plan = DailyReminder.Plan(
            title: "title",
            body: "body",
            destination: .pro,
            reason: "pro_phase",
            experimentID: DailyReminder.returnExperimentID,
            receiptID: "receipt-a",
            savedDayKey: "20260809",
            experimentVariant: DailyReminder.ReturnExperimentVariant.guided.rawValue,
            developmentRulesVersion: 4,
            scheduledLanguage: .korean,
            scheduledCopySchemaVersion: GameCopySchema.currentVersion
        )

        XCTAssertFalse(DailyReminder.needsPresentationReschedule(
            plan: plan, language: .korean, copySchemaVersion: GameCopySchema.currentVersion
        ))
        XCTAssertTrue(DailyReminder.needsPresentationReschedule(
            plan: plan, language: .english, copySchemaVersion: GameCopySchema.currentVersion
        ))
        XCTAssertTrue(DailyReminder.needsPresentationReschedule(
            plan: plan, language: .korean, copySchemaVersion: GameCopySchema.currentVersion + 1
        ))

        let rescheduled = DailyReminder.planScheduledForPresentation(
            plan, language: .english, copySchemaVersion: GameCopySchema.currentVersion + 1
        )
        XCTAssertEqual(rescheduled.destination, plan.destination)
        XCTAssertEqual(rescheduled.reason, plan.reason)
        XCTAssertEqual(rescheduled.receiptID, plan.receiptID)
        XCTAssertEqual(rescheduled.experimentID, plan.experimentID)
        XCTAssertEqual(rescheduled.experimentVariant, plan.experimentVariant)
        XCTAssertEqual(rescheduled.scheduledLanguage, .english)
        XCTAssertEqual(
            rescheduled.scheduledCopySchemaVersion,
            GameCopySchema.currentVersion + 1
        )
    }

    @MainActor
    func testV2PlanExperimentIDAndVariantRoundTripThroughStorage() {
        let base = DailyReminder.Plan(
            title: "이어가기", body: "다음 목표", destination: .highSchool,
            reason: "high_school_phase"
        )
        let prepared = DailyReminder.preparedForNextReturn(
            base, stableID: "stable-player", rulesVersion: 4,
            now: date("2026-08-09 21:00")
        )
        DailyReminder.savePlan(prepared, defaults: defaults)
        let restored = DailyReminder.storedPlan(defaults: defaults)

        XCTAssertEqual(restored?.experimentID, DailyReminder.returnExperimentID)
        XCTAssertEqual(restored?.experimentVariant, prepared.experimentVariant)
        XCTAssertEqual(restored?.receiptID, prepared.receiptID)
        XCTAssertEqual(restored?.savedDayKey, prepared.savedDayKey)
        XCTAssertEqual(
            prepared.carryingExperiment(from: restored).experimentID,
            DailyReminder.returnExperimentID
        )
    }

    @MainActor
    func testChapterGoalAndNameFieldRemainHiddenUntilTheirExplicitlyValidState() {
        let noGameSchedule = CareerScheduleSnapshot(
            trainingsByChapter: [1], milestonesByChapter: [[.relationship]]
        )
        let gameSchedule = CareerScheduleSnapshot(
            trainingsByChapter: [1], milestonesByChapter: [[.importantGame]]
        )
        XCTAssertFalse(HighSchoolCareerView.showsChapterGoal(
            phase: .training, draftResult: nil, chapterNumber: 1, schedule: noGameSchedule
        ))
        XCTAssertTrue(HighSchoolCareerView.showsChapterGoal(
            phase: .training, draftResult: nil, chapterNumber: 1, schedule: gameSchedule
        ))
        XCTAssertFalse(HighSchoolCareerView.showsChapterGoal(
            phase: .awakening, draftResult: nil, chapterNumber: 1, schedule: gameSchedule
        ))
        XCTAssertFalse(HighSchoolSetupView.shouldAutoFocusName(isRebirth: false))
        XCTAssertFalse(HighSchoolSetupView.shouldAutoFocusName(isRebirth: true))
    }

    func testReminderDeepLinksResolveOnlyKnownAppRoutes() {
        XCTAssertEqual(
            DailyReminder.Destination.resolve(URL(string: DailyReminder.deepLink)!),
            .dailyInning
        )
        XCTAssertEqual(
            DailyReminder.Destination.resolve(URL(string: "com.solkim.baseball.ios://high-school")!),
            .highSchool
        )
        XCTAssertEqual(
            DailyReminder.Destination.resolve(URL(string: "com.solkim.baseball.ios://pro")!),
            .pro
        )
        XCTAssertNil(DailyReminder.Destination.resolve(URL(string: "https://example.com/pro")!))
    }

    // MARK: - 옵트인 관문

    /// 한 번 물어봤으면 다시 묻지 않는다. 거절한 사람에게 반복해서 권하면 그게 곧 이탈 사유다.
    func testOptInIsOfferedOnceAndNeverAgainAfterAnAnswer() {
        XCTAssertTrue(DailyReminder.shouldOfferOptIn(defaults: defaults))
        defaults.set(true, forKey: DailyReminder.promptedKey)
        XCTAssertFalse(DailyReminder.shouldOfferOptIn(defaults: defaults))
    }

    func testOptInIsNotOfferedWhenAlreadyEnabled() {
        defaults.set(true, forKey: DailyReminder.enabledKey)
        XCTAssertFalse(DailyReminder.shouldOfferOptIn(defaults: defaults))
    }

    // MARK: - 제거된 링크 호환

    func testRetiredDailyLinkFallsBackToAPlayableTab() {
        XCTAssertEqual(
            AppShell.retiredDailyInningFallbackTab(
                hasActiveProCareer: true, showsHighSchool: true
            ),
            .pro
        )
        XCTAssertEqual(
            AppShell.retiredDailyInningFallbackTab(
                hasActiveProCareer: false, showsHighSchool: true
            ),
            .highSchool
        )
        XCTAssertEqual(
            AppShell.retiredDailyInningFallbackTab(
                hasActiveProCareer: false, showsHighSchool: false
            ),
            .pro
        )
    }

    // MARK: - 안정 식별자

    /// 재설치해도 같은 사람으로 이어져야 리텐션 통계가 낙관적으로 왜곡되지 않는다.
    @MainActor
    func testStableIDIsGeneratedOnceAndReused() {
        let first = GameAnalytics.stableID(defaults: defaults)
        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(GameAnalytics.stableID(defaults: defaults), first)
    }
}

/// 회차 종료 → 다음 회차의 마찰. 2026-08 데이터에서 드래프트를 본 42명 중 27명만
/// 다음 회차를 시작했다.
final class RebirthFrictionTests: XCTestCase {

    /// 다음 회차 추천은 동기 장치이자 저장 데이터다. 새 필드는 왕복하고, 필드가 없는
    /// 기존 저장본은 추천 없이 그대로 열려야 한다.
    func testNextRunIntentRoundTripsAndOldSaveDefaultsToNone() throws {
        let intent = NextRunIntent(
            pledgeID: "strikeout_master", sourceLifeNumber: 3,
            reason: "탈삼진 목표까지 다섯 개가 남았습니다."
        )
        let record = HighSchoolCareerStore.SaveRecord(
            result: nil, inheritance: .firstLife, nextRunIntent: intent, revision: 7
        )
        let decoded = try JSONDecoder().decode(
            HighSchoolCareerStore.SaveRecord.self, from: JSONEncoder().encode(record)
        )
        XCTAssertEqual(decoded.nextRunIntent, intent)

        let legacy = """
        {"inheritance":{"lifeNumber":1,"memories":[],"soulPoints":0,"karmas":[]},"revision":1}
        """
        XCTAssertNil(try JSONDecoder().decode(
            HighSchoolCareerStore.SaveRecord.self, from: Data(legacy.utf8)
        ).nextRunIntent)
    }

    /// 정산 화면에서 곧장 다음 판으로 가려면 지난 설정이 재생 가능해야 한다.
    @MainActor
    func testQuickRebirthPresetIsAvailableAfterAStartedCareer() throws {
        let store = HighSchoolCareerStore()
        store.deleteCareer()
        store.startCareer(preset: PitcherPresetCatalog.all[0], playerName: "환생 마찰")
        guard store.result != nil else { throw XCTSkip("커리어 시작 실패 — 환경 문제") }
        XCTAssertNotNil(store.quickRebirthPreset, "지난 설정이 있으면 원탭 환생이 가능해야 합니다")
        XCTAssertEqual(store.quickRebirthPreset?.id, PitcherPresetCatalog.all[0].id)
    }

    /// 도전 런은 기록에도 계승에도 남지 않는다 — 그 설정으로 "다시 태어나기"를 열면
    /// 맨몸 판의 조건이 실제 회차로 새어 들어간다.
    @MainActor
    func testQuickRebirthIsUnavailableInAChallengeRun() throws {
        let store = HighSchoolCareerStore()
        store.deleteCareer()
        store.startCareer(preset: PitcherPresetCatalog.all[0], playerName: "도전자",
                          seedOverride: "424242", challengeLifeNumber: 1)
        guard store.result != nil else { throw XCTSkip("커리어 시작 실패 — 환경 문제") }
        XCTAssertTrue(store.isChallengeRun)
        XCTAssertNil(store.quickRebirthPreset, "도전 런에서는 원탭 환생이 열리면 안 됩니다")
    }

    /// 진행을 지우면 원탭 환생의 재료도 사라져야 한다.
    @MainActor
    func testQuickRebirthClearsWithProgress() throws {
        let store = HighSchoolCareerStore()
        store.startCareer(preset: PitcherPresetCatalog.all[0], playerName: "삭제")
        guard store.result != nil else { throw XCTSkip("커리어 시작 실패 — 환경 문제") }
        store.deleteCareer()
        XCTAssertNil(store.quickRebirthPreset)
    }
}
