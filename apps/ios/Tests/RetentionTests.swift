import XCTest
import SimulationCore
@testable import BaseballIOS

/// 손맛·소리·업적·환생 계승의 순수 판정을 지킨다. 모두 엔진/Game Center 없이 돈다.
final class RetentionTests: XCTestCase {

    // MARK: - 투구 제스처

    /// 미터 한가운데 + 중심 조준이 만점이어야 한다.
    func testPerfectGestureScoresFull() {
        let delivery = DeliveryControl.delivery(meter: 0.5, aim: .zero, aimRadius: 46)
        XCTAssertEqual(delivery.releaseAccuracy, 1_000)
        XCTAssertEqual(delivery.aimAccuracy, 1_000)
    }

    /// 끝에서 떼면 0. 값은 항상 코어가 받는 0~1000 범위 안이어야 한다.
    func testGestureStaysInRange() {
        for meter in stride(from: 0.0, through: 1.0, by: 0.05) {
            for offset in stride(from: -80.0, through: 80.0, by: 20) {
                let delivery = DeliveryControl.delivery(
                    meter: meter,
                    aim: CGSize(width: offset, height: offset / 2),
                    aimRadius: 46
                )
                XCTAssertTrue((0...1_000).contains(delivery.releaseAccuracy))
                XCTAssertTrue((0...1_000).contains(delivery.aimAccuracy))
            }
        }
        XCTAssertEqual(DeliveryControl.delivery(meter: 0, aim: .zero, aimRadius: 46).releaseAccuracy, 0)
        XCTAssertEqual(DeliveryControl.delivery(meter: 1, aim: .zero, aimRadius: 46).releaseAccuracy, 0)
    }

    /// 조준이 멀어질수록 점수가 단조 감소해야 한다.
    func testAimScoreDecreasesWithDistance() {
        let near = DeliveryControl.delivery(meter: 0.5, aim: CGSize(width: 10, height: 0), aimRadius: 46)
        let far = DeliveryControl.delivery(meter: 0.5, aim: CGSize(width: 40, height: 0), aimRadius: 46)
        XCTAssertGreaterThan(near.aimAccuracy, far.aimAccuracy)
    }

    /// 자동 릴리스가 쓰는 중립값은 판정 문구를 만들지 않는다. 손맛 판정이 없을 때는 조용해야 한다.
    func testNeutralDeliveryHasNoVerdict() {
        XCTAssertNil(DeliveryControl.verdict(.neutral))
        XCTAssertNotNil(DeliveryControl.verdict(PitchDelivery(releaseAccuracy: 950, aimAccuracy: 950)))
    }

    // MARK: - 분석

    /// 전환으로 집계되는 이벤트는 1인 1회여야 한다 — 두 번 세면 광고 데이터가 거짓이 된다.
    @MainActor
    func testActivationEventLogsExactlyOnce() {
        GameAnalytics.resetOnceFlags()
        XCTAssertTrue(GameAnalytics.logOnce(.activationFirstGame), "첫 호출은 기록돼야 합니다.")
        XCTAssertFalse(GameAnalytics.logOnce(.activationFirstGame), "두 번째 호출은 무시돼야 합니다.")
        GameAnalytics.resetOnceFlags()
        XCTAssertTrue(GameAnalytics.logOnce(.activationFirstGame), "리셋 후에는 다시 기록됩니다.")
        GameAnalytics.resetOnceFlags()
    }

    // MARK: - 소리

    /// 소리 매핑은 결과마다 반드시 무언가를 낸다. 조용한 투구는 없다.
    func testEveryOutcomeMakesSound() {
        for outcome in PitchOutcome.allCases {
            let snapshot = Self.snapshot(outcome: outcome)
            let cues = GameAudioMapping.cues(for: snapshot)
            XCTAssertFalse(cues.isEmpty, "\(outcome)에 소리가 없습니다.")
            XCTAssertEqual(cues.first, .pitchRelease, "모든 투구는 릴리스 소리로 시작해야 합니다.")
        }
    }

    /// 삼진은 낱개 스트라이크 콜 대신 풀콜("스트라이크 쓰리, 유어 아웃") 하나로 나간다.
    /// 둘 다 나가면 "스트라이크"를 두 번 외치는 심판이 된다.
    func testStrikeoutUsesTheFullCallInsteadOfTheStrikeCall() {
        for outcome in [PitchOutcome.calledStrike, .swingingStrike] {
            let cues = GameAudioMapping.cues(for: Self.snapshot(outcome: outcome, result: .strikeout))
            XCTAssertTrue(cues.contains(.umpireStrikeout), "\(outcome) 삼진에 풀콜이 없습니다.")
            XCTAssertFalse(cues.contains(.umpireStrike), "\(outcome) 삼진에 낱개 콜이 겹칩니다.")
            XCTAssertTrue(cues.contains(.crowdCheer))
        }
        // 삼진이 아닌 스트라이크는 여전히 낱개 콜이다.
        let ordinary = GameAudioMapping.cues(for: Self.snapshot(outcome: .calledStrike))
        XCTAssertTrue(ordinary.contains(.umpireStrike))
        XCTAssertFalse(ordinary.contains(.umpireStrikeout))
    }

    /// 잘 맞은 타구는 더 두꺼운 소리를 낸다.
    func testContactPowerFollowsContactQuality() {
        XCTAssertEqual(GameAudioMapping.contactPower(nil), 0.5)
        let weak = GameAudioMapping.contactPower(BattedBall(exitVelocityTenthsKPH: 900, launchAngleTenthsDegrees: 100, directionTenthsDegrees: 0, contactQuality: 200))
        let hard = GameAudioMapping.contactPower(BattedBall(exitVelocityTenthsKPH: 1_600, launchAngleTenthsDegrees: 250, directionTenthsDegrees: 0, contactQuality: 900))
        XCTAssertLessThan(weak, hard)
        XCTAssertTrue((0...1).contains(hard))
    }

    /// 레버리지가 높을수록 관중이 두꺼워지고, 값은 항상 0~1이다.
    func testCrowdIntensityRange() {
        XCTAssertLessThan(
            GameAudioMapping.crowdIntensity(leverage: 100),
            GameAudioMapping.crowdIntensity(leverage: 1_000)
        )
        for leverage in stride(from: 0, through: 1_000, by: 50) {
            let value = GameAudioMapping.crowdIntensity(leverage: leverage)
            XCTAssertTrue((0...1).contains(value))
        }
    }

    /// 모든 큐가 실제로 소리 낼 보이스를 만들어야 한다. 정의만 있고 소리가 없는 큐는 버그다.
    func testEveryCueProducesVoices() {
        // umpireBall은 **의도적 무음**이라 여기서 빠진다. 실제 심판은 볼을 외치지 않고,
        // 미트 소리가 이미 공 하나를 표시한다(UmpireVoiceTests.testBallCallIsSilent가 지킨다).
        let cues: [GameAudioCue] = [
            .pitchRelease, .gloveCatch, .swingMiss, .batContact(power: 0.8), .batFoul,
            .umpireStrike, .umpireStrikeout, .crowdCheer, .crowdGroan, .growth, .milestone, .uiSelect
        ]
        for cue in cues {
            let voices = GameAudio.voices(for: cue)
            XCTAssertFalse(voices.isEmpty, "\(cue)에 보이스가 없습니다.")
            for voice in voices {
                XCTAssertGreaterThan(voice.duration, 0)
                XCTAssertGreaterThan(voice.gain, 0)
                XCTAssertGreaterThanOrEqual(voice.delay, 0)
            }
        }
    }

    // MARK: - 업적

    func testInningAchievements() {
        let clean = ImportantInningReport(scenarioNumber: 1, pitches: 12, strikeouts: 2, walks: 0, runsAllowed: 0, expectedDamage: 300, actualDamage: 200, recommendationAccepted: 8)
        XCTAssertTrue(AchievementRules.fromInning(report: clean).contains(.cleanInning))
        XCTAssertTrue(AchievementRules.fromInning(report: clean).contains(.firstStrikeout))

        let messy = ImportantInningReport(scenarioNumber: 1, pitches: 20, strikeouts: 0, walks: 3, runsAllowed: 2, expectedDamage: 600, actualDamage: 800, recommendationAccepted: 2)
        XCTAssertFalse(AchievementRules.fromInning(report: messy).contains(.cleanInning))
        XCTAssertFalse(AchievementRules.fromInning(report: messy).contains(.firstStrikeout))

        // 던지지 않은 이닝은 무실점이 아니다.
        let empty = ImportantInningReport(scenarioNumber: 1, pitches: 0, strikeouts: 0, walks: 0, runsAllowed: 0, expectedDamage: 0, actualDamage: 0, recommendationAccepted: 0)
        XCTAssertFalse(AchievementRules.fromInning(report: empty).contains(.cleanInning))
    }

    func testDeliveryAchievementNeedsBothAxes() {
        XCTAssertTrue(AchievementRules.fromDelivery(PitchDelivery(releaseAccuracy: 950, aimAccuracy: 920)).contains(.perfectDelivery))
        XCTAssertTrue(AchievementRules.fromDelivery(PitchDelivery(releaseAccuracy: 950, aimAccuracy: 800)).isEmpty)
        XCTAssertTrue(AchievementRules.fromDelivery(nil).isEmpty)
        XCTAssertTrue(AchievementRules.fromDelivery(.neutral).isEmpty)
    }

    func testLifeNumberAchievement() {
        XCTAssertTrue(AchievementRules.fromLifeNumber(1).isEmpty)
        XCTAssertTrue(AchievementRules.fromLifeNumber(3).contains(.thirdLife))
        XCTAssertTrue(AchievementRules.fromLifeNumber(7).contains(.thirdLife))
        // 회차 사다리: 3회차 하나로 끝나면 3회차 시작 순간 회차 목표가 소진된다.
        XCTAssertFalse(AchievementRules.fromLifeNumber(4).contains(.fifthLife))
        XCTAssertTrue(AchievementRules.fromLifeNumber(5).contains(.fifthLife))
        XCTAssertTrue(AchievementRules.fromLifeNumber(10).contains(.tenthLife))
    }

    /// 수집형 업적: 아카이브가 콘텐츠 풀(학교·지명)을 가리켜야 반복 이유가 생긴다.
    func testArchiveAchievements() {
        func life(_ number: Int, school: String, drafted: Bool) -> HighSchoolCareerStore.LifeRecord {
            HighSchoolCareerStore.LifeRecord(
                lifeNumber: number, playerName: "테스트", schoolName: school, drafted: drafted,
                evaluationScore: 60, teamName: drafted ? "구단" : nil, memories: [], games: 5,
                strikeouts: 30, walks: 8, runsAllowed: 10, soulPoints: 40
            )
        }
        let threeSchools = [life(1, school: "가", drafted: true), life(2, school: "나", drafted: true), life(3, school: "다", drafted: false)]
        XCTAssertFalse(AchievementRules.fromArchive(threeSchools).contains(.fourSchools))
        let fourSchools = threeSchools + [life(4, school: "라", drafted: true)]
        XCTAssertTrue(AchievementRules.fromArchive(fourSchools).contains(.fourSchools))
        XCTAssertFalse(AchievementRules.fromArchive(fourSchools).contains(.fiveDrafts))
        let fiveDrafts = fourSchools + [life(5, school: "가", drafted: true), life(6, school: "나", drafted: true)]
        XCTAssertTrue(AchievementRules.fromArchive(fiveDrafts).contains(.fiveDrafts))
    }

    /// 같은 업적을 두 번 기록해도 새로 달성한 것으로 치지 않는다.
    func testProgressOnlyReportsFreshUnlocks() {
        var progress = AchievementProgress()
        XCTAssertEqual(progress.unlock([.firstDraft, .cleanInning]).count, 2)
        XCTAssertEqual(progress.unlock([.firstDraft]).count, 0)
        XCTAssertEqual(progress.unlock([.firstDraft, .thirdLife]), [.thirdLife])
        XCTAssertTrue(progress.has(.firstDraft))
        XCTAssertFalse(progress.has(.hallOfFame))
    }

    /// 업적은 저장/복원돼야 한다. 앱을 껐다 켜면 사라지는 업적은 리텐션 장치가 아니다.
    func testProgressRoundTrips() throws {
        var progress = AchievementProgress()
        _ = progress.unlock([.majorDebut, .karmaRun])
        let data = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(AchievementProgress.self, from: data)
        XCTAssertEqual(decoded, progress)
        XCTAssertTrue(decoded.has(.majorDebut))
    }

    /// 모든 업적과 리더보드는 고유한 Game Center 식별자를 가져야 한다.
    func testGameCenterIdentifiersAreUnique() {
        let achievementIDs = Achievement.allCases.map(\.gameCenterID)
        XCTAssertEqual(Set(achievementIDs).count, achievementIDs.count)
        let boardIDs = Leaderboard.allCases.map(\.gameCenterID)
        XCTAssertEqual(Set(boardIDs).count, boardIDs.count)
    }

    // MARK: - 환생 계승

    /// 실패한 회차도 다음 생에 무언가를 남긴다. 0이 되면 다시 켤 이유가 사라진다.
    /// 코어의 legacyRewardPermille는 1000이 ×1.0이다(카르마 없음).
    func testFailedRunStillCarriesSomethingForward() {
        let state = Self.highSchoolSnapshot(strikeouts: 0, walks: 12, runsAllowed: 9, rewardPermille: 1_000)
        let next = HighSchoolCareerStore.nextInheritance(from: state, memories: [], previous: .firstLife)
        XCTAssertEqual(next.lifeNumber, 2)
        XCTAssertGreaterThan(next.soulPoints, 0)
    }

    /// 카르마 보상 배율이 계승분을 정확히 표기만큼 키운다. 예전에는 스토어가 1000을 한 번
    /// 더 더해서 기본이 ×2.0이 됐고, 화면의 "+35%"가 실제로는 +17.5%만 전달됐다.
    func testKarmaRewardIncreasesInheritanceExactly() {
        let plain = Self.highSchoolSnapshot(strikeouts: 20, walks: 4, runsAllowed: 3, rewardPermille: 1_000)
        let burdened = Self.highSchoolSnapshot(strikeouts: 20, walks: 4, runsAllowed: 3, rewardPermille: 1_350)
        let a = HighSchoolCareerStore.nextInheritance(from: plain, memories: [], previous: .firstLife)
        let b = HighSchoolCareerStore.nextInheritance(from: burdened, memories: [], previous: .firstLife)
        XCTAssertGreaterThan(b.soulPoints, a.soulPoints)
        // 정수 나눗셈 오차 1 이내에서 정확히 ×1.35여야 한다.
        XCTAssertLessThanOrEqual(abs(b.soulPoints - a.soulPoints * 1_350 / 1_000), 1)
    }

    /// 배율 필드가 없거나 0인 저장본(구버전 데스크톱 등)도 ×1.0 밑으로 떨어지지 않는다.
    func testDegenerateRewardPermilleStillPaysFull() {
        let zero = Self.highSchoolSnapshot(strikeouts: 20, walks: 4, runsAllowed: 3, rewardPermille: 0)
        let full = Self.highSchoolSnapshot(strikeouts: 20, walks: 4, runsAllowed: 3, rewardPermille: 1_000)
        XCTAssertEqual(
            HighSchoolCareerStore.nextInheritance(from: zero, memories: [], previous: .firstLife).soulPoints,
            HighSchoolCareerStore.nextInheritance(from: full, memories: [], previous: .firstLife).soulPoints
        )
    }

    /// 회차가 쌓이면 영혼도 쌓인다.
    func testInheritanceAccumulatesAcrossLives() {
        let state = Self.highSchoolSnapshot(strikeouts: 15, walks: 5, runsAllowed: 4, rewardPermille: 150)
        var carried = HighSchoolCareerStore.Inheritance.firstLife
        var previousPoints = 0
        for expectedLife in 2...5 {
            carried = HighSchoolCareerStore.nextInheritance(from: state, memories: [.coachLetter], previous: carried)
            XCTAssertEqual(carried.lifeNumber, expectedLife)
            XCTAssertGreaterThan(carried.soulPoints, previousPoints)
            XCTAssertEqual(carried.memories, [.coachLetter])
            previousPoints = carried.soulPoints
        }
    }

    /// 프로 커리어가 길고 빛날수록 다음 회차에 남기는 야구혼이 커야 한다.
    /// 예전에는 15년 명예의 전당 커리어도 계승에 0을 남겼다.
    func testProCareerLeavesSoulProportionalToItsWeight() {
        let short = HighSchoolCareerStore.proSoulBonus(seasons: 2, strikeouts: 90, awards: 0, hallOfFameScore: 0)
        let steady = HighSchoolCareerStore.proSoulBonus(seasons: 8, strikeouts: 700, awards: 1, hallOfFameScore: 30)
        let legend = HighSchoolCareerStore.proSoulBonus(seasons: 12, strikeouts: 1_800, awards: 6, hallOfFameScore: 90)
        XCTAssertGreaterThan(short, 0)
        XCTAssertGreaterThan(steady, short)
        XCTAssertGreaterThan(legend, steady)
        // 전설 커리어는 스펙의 프로 계승 스케일(~220+)에 닿아야 한다.
        XCTAssertGreaterThanOrEqual(legend, 200)
    }

    /// 회차 사이(진행 없음)에도 계승분이 저장 레코드로 남아야 한다. 이게 깨지면
    /// "다시 태어나기" 직후 앱이 내려갈 때 야구혼·기억·아카이브가 통째로 사라진다.
    /// 별명·연대기가 없는 옛 저장본이 그대로 열리고, 있는 것은 온전히 돌아온다.
    func testNicknamesAndChronicleSurviveTheRoundTripAndOldSavesStillOpen() throws {
        let life = HighSchoolCareerStore.LifeRecord(
            lifeNumber: 4, playerName: "테스트", schoolName: nil, drafted: true,
            evaluationScore: 70, teamName: "부산 돌핀스", memories: [], games: 4,
            strikeouts: 30, walks: 3, runsAllowed: 0, soulPoints: 50,
            nicknames: ["제로", "핀포인트"],
            chronicle: ["1학년 봄 — 입학.", "3학년 여름 — 드래프트 1라운드 지명."]
        )
        let record = HighSchoolCareerStore.SaveRecord(
            result: nil,
            inheritance: .init(lifeNumber: 4, memories: [], soulPoints: 10, karmas: []),
            archive: [life],
            nicknames: [Nickname(id: "zero", title: "제로", reason: "무실점")],
            chronicle: [.init(stage: "3학년 여름", text: "드래프트 지명.")],
            revision: 9
        )
        let decoded = try JSONDecoder().decode(
            HighSchoolCareerStore.SaveRecord.self, from: JSONEncoder().encode(record)
        )
        XCTAssertEqual(decoded.archive?.first?.nicknames, ["제로", "핀포인트"])
        XCTAssertEqual(decoded.archive?.first?.chronicle?.count, 2)
        XCTAssertEqual(decoded.nicknames?.first?.title, "제로")
        XCTAssertEqual(decoded.chronicle?.first?.text, "드래프트 지명.")

        // 새 키가 하나도 없는 옛 저장본 — 필드 추가가 복원을 깨면 안 된다.
        let old = """
        {"inheritance":{"lifeNumber":1,"memories":[],"soulPoints":0,"karmas":[]},"revision":1}
        """
        let legacy = try JSONDecoder().decode(
            HighSchoolCareerStore.SaveRecord.self, from: Data(old.utf8)
        )
        XCTAssertNil(legacy.nicknames)
        XCTAssertNil(legacy.chronicle)
    }

    func testLegacyOnlyRecordRoundTrips() throws {
        let inheritance = HighSchoolCareerStore.Inheritance(
            lifeNumber: 3, memories: [.coachLetter, .recoveryRoutine], soulPoints: 87, karmas: [.noLastChance]
        )
        let life = HighSchoolCareerStore.LifeRecord(
            lifeNumber: 2, playerName: "테스트", schoolName: "서울덕성고", drafted: false,
            evaluationScore: 55, teamName: nil, memories: [.coachLetter], games: 5,
            strikeouts: 40, walks: 9, runsAllowed: 12, soulPoints: 41
        )
        let record = HighSchoolCareerStore.SaveRecord(
            result: nil, inheritance: inheritance, archive: [life], revision: 42
        )
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(HighSchoolCareerStore.SaveRecord.self, from: data)
        XCTAssertNil(decoded.result)
        XCTAssertEqual(decoded.inheritance, inheritance)
        XCTAssertEqual(decoded.archive, [life])
        XCTAssertEqual(decoded.effectiveRevision, 42)
    }

    // MARK: - 고정물

    private static func snapshot(
        outcome: PitchOutcome, result: PlateAppearanceResult? = nil
    ) -> PlateAppearanceSnapshot {
        PlateAppearanceSnapshot(
            revision: 1,
            balls: 0,
            strikes: 1,
            pitchNumber: 1,
            ended: result != nil,
            result: result,
            outcome: outcome,
            selectionQuality: .good,
            recommendationAccepted: true,
            fatigueAfterPitch: 20,
            execution: PitchExecution(
                targetX: 0, targetY: 0, actualX: 10, actualY: -20,
                velocityTenthsKPH: 1_400, horizontalBreakTenthsCM: 40,
                verticalBreakTenthsCM: 120, executionQuality: 700
            ),
            battedBall: BattedBall(
                exitVelocityTenthsKPH: 1_400,
                launchAngleTenthsDegrees: 200,
                directionTenthsDegrees: 50,
                contactQuality: 600
            ),
            reasonCodes: [],
            shortFeedback: "테스트",
            detailFeedback: "테스트",
            accessibilitySummary: "테스트"
        )
    }

    private static func highSchoolSnapshot(
        strikeouts: Int,
        walks: Int,
        runsAllowed: Int,
        rewardPermille: Int
    ) -> HighSchoolCareerSnapshot {
        HighSchoolCareerSnapshot(
            careerID: "hs-test",
            revision: 1,
            lifeNumber: 1,
            phase: .legacy,
            identity: .defaultPitcher,
            difficulty: .standard,
            karmas: [],
            legacyRewardPermille: rewardPermille,
            memorySlots: 2,
            pitcher: PitcherSnapshot(id: "p", name: "테스트", stuff: 45, command: 44, movement: 43, stamina: 46),
            schoolOptions: [],
            school: nil,
            rival: RivalSnapshot(id: "r", name: "라이벌", archetype: "거포", contact: 50, discipline: 48, power: 60),
            chapter: CareerChapterSnapshot(number: 8, title: "마지막", schoolYear: 3, season: "가을", theme: "끝"),
            chapterTrainingCount: 2,
            totalTrainingsCompleted: 16,
            milestoneIndex: 0,
            relationshipsCompleted: 5,
            relationshipTrust: 55,
            selectedAwakenings: [],
            awakeningOptions: [],
            fatigue: 30,
            performance: CareerPerformanceSnapshot(
                importantGamesCompleted: 5,
                pitches: 90,
                strikeouts: strikeouts,
                walks: walks,
                runsAllowed: runsAllowed,
                expectedDamage: 1_000,
                actualDamage: 900
            ),
            currentGameScenario: nil,
            currentRelationshipEvent: nil,
            lastTraining: nil,
            news: [],
            fanInterest: 40,
            draftResult: nil,
            legacyOptions: [],
            selectedMemories: [],
            stateCommitment: ""
        )
    }
}
