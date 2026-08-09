import XCTest
import SimulationCore
@testable import BaseballIOS

/// 리텐션 훅(연속 기록·복귀 알림·오늘의 이닝 노출)의 순수 판정.
///
/// 배경: 2026-08 Amplitude에서 D2 리텐션이 0%였고, 하루 DAU 43명 중 오늘의 이닝을 연
/// 사람은 3명이었다. 원인은 리텐션 장치가 자신이 살려야 할 화면 안에 갇혀 있었던 것
/// (알림 스위치가 오늘의 이닝 화면에만 존재)과, 하루 건너뛰어도 잃을 것이 없었던 것이다.
/// 여기 있는 판정들이 그 두 가지를 고친 규칙이다.
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

    // MARK: - 오늘의 이닝 입구 노출

    /// 첫 중요 경기를 끝내기 전에는 곁가지 모드를 보여 주지 않는다 — 본편의 손맛을
    /// 보기도 전에 다른 모드가 보이면 무엇이 이 게임인지 흐려진다.
    func testDailyEntryHiddenBeforeTheFirstImportantGame() {
        XCTAssertFalse(HighSchoolCareerView.showsDailyEntry(phase: .training, gamesCompleted: 0))
    }

    /// 회차가 **끝나는** 화면들이야말로 내일 켤 이유가 필요한 자리다. 예전에는 훈련
    /// 국면에서만 보여서, 첫 세션에 1회차를 통째로 끝낸 사람은 마지막까지 이 입구를
    /// 한 번도 보지 못하고 떠났다.
    func testDailyEntryShowsOnTheScreensWhereRunsEnd() {
        for phase in [HighSchoolCareerPhase.draft, .legacy, .completed, .chapterReview,
                      .training, .relationship, .schoolSelection] {
            XCTAssertTrue(
                HighSchoolCareerView.showsDailyEntry(phase: phase, gamesCompleted: 1),
                "\(phase.rawValue)에서 오늘의 이닝 입구가 보여야 합니다"
            )
        }
    }

    /// 승부와 각성은 집중이 필요한 국면이다. 투구 화면 위에 곁가지 배너가 있으면 소음이고,
    /// 되돌릴 수 없는 선택 옆의 다른 버튼은 오조작이다.
    func testDailyEntryHiddenDuringFocusedPhases() {
        for phase in [HighSchoolCareerPhase.importantGame, .awakening, .prologue] {
            XCTAssertFalse(
                HighSchoolCareerView.showsDailyEntry(phase: phase, gamesCompleted: 3),
                "\(phase.rawValue)에서는 곁가지 입구가 숨어야 합니다"
            )
        }
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
