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
        let cues: [GameAudioCue] = [
            .pitchRelease, .gloveCatch, .swingMiss, .batContact(power: 0.8), .batFoul,
            .umpireStrike, .umpireBall, .crowdCheer, .crowdGroan, .growth, .milestone, .uiSelect
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
    func testFailedRunStillCarriesSomethingForward() {
        let state = Self.highSchoolSnapshot(strikeouts: 0, walks: 12, runsAllowed: 9, rewardPermille: 0)
        let next = HighSchoolCareerStore.nextInheritance(from: state, memories: [], previous: .firstLife)
        XCTAssertEqual(next.lifeNumber, 2)
        XCTAssertGreaterThan(next.soulPoints, 0)
    }

    /// 카르마 보상 배율이 계승분을 키운다.
    func testKarmaRewardIncreasesInheritance() {
        let plain = Self.highSchoolSnapshot(strikeouts: 20, walks: 4, runsAllowed: 3, rewardPermille: 0)
        let burdened = Self.highSchoolSnapshot(strikeouts: 20, walks: 4, runsAllowed: 3, rewardPermille: 350)
        let a = HighSchoolCareerStore.nextInheritance(from: plain, memories: [], previous: .firstLife)
        let b = HighSchoolCareerStore.nextInheritance(from: burdened, memories: [], previous: .firstLife)
        XCTAssertGreaterThan(b.soulPoints, a.soulPoints)
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

    // MARK: - 고정물

    private static func snapshot(outcome: PitchOutcome) -> PlateAppearanceSnapshot {
        PlateAppearanceSnapshot(
            revision: 1,
            balls: 0,
            strikes: 1,
            pitchNumber: 1,
            ended: false,
            result: nil,
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
