import XCTest
@testable import SimulationCore

/// 고교 규칙 5~7에서 실제로 달라지는 것들. 고정 참조(4)의 계산은 건드리지 않는다.
final class HighSchoolGameplayRulesTests: XCTestCase {

    private func startedCareer(
        rules: Int = HighSchoolGameplayRules.current,
        seed: String = "918220",
        preset: String = "power_prospect",
        lifeNumber: Int = 1,
        completedLives: Int? = nil
    ) throws -> (engine: HighSchoolCareerEngine, result: HighSchoolCareerResult) {
        let engine = HighSchoolCareerEngine(gameplayRulesVersion: rules)
        var result = try engine.start(.init(
            seed: seed, presetID: preset, lifeNumber: lifeNumber,
            signatureLegacyID: nil, inheritanceRulesVersion: nil,
            completedLives: completedLives))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(
            seed: result.nextSeed, state: result.snapshot,
            schoolID: try XCTUnwrap(result.snapshot.schoolOptions.first?.id)))
        return (engine, result)
    }

    // MARK: 버전 기록

    func testNewCareersRecordTheCurrentRulesAndReferenceEnginesStayOnFour() throws {
        XCTAssertEqual(try startedCareer().result.snapshot.balanceVersion, HighSchoolGameplayRules.current)
        XCTAssertEqual(
            try startedCareer(rules: HighSchoolGameplayRules.reference).result.snapshot.balanceVersion,
            HighSchoolGameplayRules.reference)
    }

    func testAnInProgressV4CareerMovesToTheCurrentRulesButAPreV4SaveDoesNot() throws {
        let (engine, started) = try startedCareer(rules: HighSchoolGameplayRules.reference)
        XCTAssertEqual(started.snapshot.balanceVersion, 4)

        let currentEngine = HighSchoolCareerEngine()
        let advanced = try currentEngine.commitTraining(.init(
            seed: started.nextSeed, state: started.snapshot, focus: .velocity, intensity: .standard))
        XCTAssertEqual(advanced.snapshot.balanceVersion, HighSchoolGameplayRules.current)

        // v3 이하는 그 시절 계산에 묶여 있다. 진행 중인 회차의 당락선이 업데이트만으로 움직이면
        // 3년 내내 화면이 약속한 숫자와 실제 결과가 어긋난다.
        let legacyState = try rewritingBalanceVersion(started.snapshot, to: 3, engine: engine)
        let legacyAdvanced = try currentEngine.commitTraining(.init(
            seed: started.nextSeed, state: legacyState, focus: .velocity, intensity: .standard))
        XCTAssertEqual(legacyAdvanced.snapshot.balanceVersion, 3)
    }

    /// 저장 파일을 직접 고쳐 옛 버전 상태를 만든다. 커밋은 그 상태로 다시 계산한다.
    private func rewritingBalanceVersion(
        _ state: HighSchoolCareerSnapshot, to version: Int, engine: HighSchoolCareerEngine
    ) throws -> HighSchoolCareerSnapshot {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try JSONEncoder().encode(state)) as? [String: Any])
        object["balanceVersion"] = version
        let rewritten = try JSONDecoder().decode(
            HighSchoolCareerSnapshot.self,
            from: try JSONSerialization.data(withJSONObject: object))
        return engine.resigned(rewritten)
    }

    // MARK: v6 — 강한 훈련의 피로

    func testIntensiveTrainingCostsElevenFatigueFromRulesSix() throws {
        let (engine, started) = try startedCareer()
        let intensive = try engine.commitTraining(.init(
            seed: started.nextSeed, state: started.snapshot, focus: .stamina, intensity: .intensive))
        let (referenceEngine, referenceStarted) = try startedCareer(rules: HighSchoolGameplayRules.reference)
        let referenceIntensive = try referenceEngine.commitTraining(.init(
            seed: referenceStarted.nextSeed, state: referenceStarted.snapshot,
            focus: .stamina, intensity: .intensive))
        let current = try XCTUnwrap(intensive.snapshot.lastTraining?.fatigueChange)
        let reference = try XCTUnwrap(referenceIntensive.snapshot.lastTraining?.fatigueChange)
        XCTAssertEqual(reference - current, 4, "강한 훈련의 기본 피로가 15에서 11로 내려간다")
    }

    // MARK: v5 — 훈련 진도

    func testTrainingProgressAccumulatesAndConvertsAtOneHundred() throws {
        let (engine, started) = try startedCareer()
        var result = started
        var sawProgressWithoutGrowth = false
        for _ in 0..<6 where result.snapshot.phase == .training {
            result = try engine.commitTraining(.init(
                seed: result.nextSeed, state: result.snapshot, focus: .stamina, intensity: .light))
            let progress = try XCTUnwrap(result.snapshot.trainingProgress)
            XCTAssertTrue(progress.experience.allSatisfy { (0...99).contains($0) })
            if result.snapshot.lastTraining?.growth == 0 {
                sawProgressWithoutGrowth = sawProgressWithoutGrowth || progress.experience[3] > 0
            }
        }
        XCTAssertTrue(sawProgressWithoutGrowth, "성장하지 않은 훈련도 진도를 남긴다")
    }

    func testReferenceRulesLeaveNoTrainingProgress() throws {
        let (engine, started) = try startedCareer(rules: HighSchoolGameplayRules.reference)
        let trained = try engine.commitTraining(.init(
            seed: started.nextSeed, state: started.snapshot, focus: .stamina, intensity: .light))
        XCTAssertNil(trained.snapshot.trainingProgress)
    }

    // MARK: v7 — 계승과 문턱

    func testCompletedLivesRaiseTheStartingPitcherAndCapAtSixteen() {
        XCTAssertEqual(HighSchoolRebirthGrowthRules.bonus(completedLives: 0), 0)
        XCTAssertEqual(HighSchoolRebirthGrowthRules.bonus(completedLives: 1), 3)
        XCTAssertEqual(HighSchoolRebirthGrowthRules.bonus(completedLives: 4), 12)
        XCTAssertEqual(HighSchoolRebirthGrowthRules.bonus(completedLives: 5), 13)
        XCTAssertEqual(HighSchoolRebirthGrowthRules.bonus(completedLives: 8), 16)
        XCTAssertEqual(HighSchoolRebirthGrowthRules.bonus(completedLives: 40), 16)
    }

    func testTheFourthLifeStartsStrongerThanTheFirstOnlyWhenLivesWereCompleted() throws {
        let first = try startedCareer(lifeNumber: 1).result.snapshot.pitcher
        let fourth = try startedCareer(lifeNumber: 4, completedLives: 3).result.snapshot.pitcher
        XCTAssertEqual(fourth.stuff - first.stuff, 9)
        XCTAssertEqual(fourth.command - first.command, 9)
        // 그만두고 다시 시작한 회차는 완주한 생이 없으므로 보상도 없다.
        let restarted = try startedCareer(lifeNumber: 4, completedLives: 0).result.snapshot.pitcher
        XCTAssertEqual(restarted.stuff, first.stuff)
    }

    /// 문턱은 **그 버전의 경기 난이도와 짝**이다. 세 자리 전부를 못 박는다.
    ///
    /// v4(66)는 판정식이 실제 리그 수준으로 옮겨 오면서 올린 값이고, v7(61)은 자동 경기가
    /// 어려워진 만큼 되돌린 값이다. v8(52)은 **직접 던지는 공까지** 재조정된 곡선을 쓰면서
    /// 같은 투구가 더 낮은 성적을 만들기 때문이다 — 실측으로 중립 릴리스 47% · 거의 완벽
    /// 60%가 나오는 자리다(계획 문서 §2.8).
    func testEachVersionsDraftThresholdMatchesItsDifficulty() throws {
        let reference = try startedCareer(rules: HighSchoolGameplayRules.reference).result.snapshot
        let schoolBalance = try startedCareer(rules: 7).result.snapshot
        let current = try startedCareer().result.snapshot
        XCTAssertEqual(HighSchoolCareerEngine.draftThreshold(state: reference), 66)
        XCTAssertEqual(HighSchoolCareerEngine.draftThreshold(state: schoolBalance), 61)
        XCTAssertEqual(HighSchoolCareerEngine.draftThreshold(state: current), 52)
    }

    func testChapterGamesStopScalingWithRebirthsUnderSchoolBalance() {
        XCTAssertEqual(DifficultyScale.highSchool(chapter: 1, lifeNumber: 5), 4)
        XCTAssertEqual(DifficultyScale.highSchool(chapter: 1, lifeNumber: 5, scalesWithRebirths: false), 0)
    }

    // MARK: 퍼펙트 릴리스

    func testPerfectReleasesAccumulateAndEveryThirdOneIsAnAwakeningSign() throws {
        let (engine, started) = try startedCareer()
        var result = started
        var guardCount = 0
        while result.snapshot.phase != .importantGame, guardCount < 40 {
            guardCount += 1
            switch result.snapshot.phase {
            case .training:
                result = try engine.commitTraining(.init(
                    seed: result.nextSeed, state: result.snapshot, focus: .velocity, intensity: .standard))
            case .relationship:
                result = try engine.resolveRelationship(.init(
                    seed: result.nextSeed, state: result.snapshot, response: .listen))
            default:
                XCTFail("첫 승부처 전에 예상하지 못한 국면 \(result.snapshot.phase)")
                return
            }
        }
        func record(perfectReleases: Int) throws -> HighSchoolCareerResult {
            try engine.recordImportantGame(.init(
                seed: result.nextSeed, state: result.snapshot,
                report: .init(
                    scenarioNumber: result.snapshot.performance.importantGamesCompleted + 1,
                    pitches: 18, strikeouts: 1, walks: 2, runsAllowed: 3,
                    expectedDamage: 900, actualDamage: 900, recommendationAccepted: 4,
                    outs: 6, perfectReleases: perfectReleases)))
        }
        let without = try record(perfectReleases: 0)
        let with = try record(perfectReleases: 6)
        // 0을 보고한 등판은 0으로 남는다. 아예 보고하지 않은 옛 리포트만 nil이다.
        XCTAssertEqual(without.snapshot.performance.perfectReleases, 0)
        XCTAssertEqual(with.snapshot.performance.perfectReleases, 6)
        // 세 번에 하나가 전조다. 나머지 적립은 두 경우가 같으므로 차이가 곧 퍼펙트의 몫이다.
        XCTAssertEqual((with.snapshot.awakeningSparks ?? 0) - (without.snapshot.awakeningSparks ?? 0), 2)
        // 새 값은 서명에 들어가고, 값이 없던 저장본의 서명은 그대로다.
        XCTAssertNotEqual(with.snapshot.stateCommitment, without.snapshot.stateCommitment)
    }
}
