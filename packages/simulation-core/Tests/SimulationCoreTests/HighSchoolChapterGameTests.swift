import XCTest
@testable import SimulationCore

/// 고교 9 — 장별 직접 등판과 이닝 가중.
final class HighSchoolChapterGameTests: XCTestCase {
    private func started(
        rules: Int = HighSchoolGameplayRules.current,
        seed: String = "918220"
    ) throws -> (HighSchoolCareerEngine, HighSchoolCareerResult) {
        let engine = HighSchoolCareerEngine(gameplayRulesVersion: rules)
        var result = try engine.start(.init(seed: seed, presetID: "power_prospect"))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            schoolID: try XCTUnwrap(result.snapshot.schoolOptions.first?.id)
        ))
        return (engine, result)
    }

    private func rewriteBalanceVersion(
        _ state: HighSchoolCareerSnapshot,
        to version: Int,
        engine: HighSchoolCareerEngine
    ) throws -> HighSchoolCareerSnapshot {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try JSONEncoder().encode(state)) as? [String: Any]
        )
        object["balanceVersion"] = version
        object["chapterGameClaimed"] = true
        let rewritten = try JSONDecoder().decode(
            HighSchoolCareerSnapshot.self,
            from: try JSONSerialization.data(withJSONObject: object)
        )
        return engine.resigned(rewritten)
    }

    func testANewCareerIsOnRulesNine() throws {
        XCTAssertEqual(HighSchoolGameplayRules.current, 9)
        XCTAssertTrue(HighSchoolGameplayRules.usesChapterLiveOuting(9))
        XCTAssertTrue(HighSchoolGameplayRules.usesInningsWeightedPerformance(9))
        XCTAssertFalse(HighSchoolGameplayRules.usesChapterLiveOuting(8))
        let started = try started().1
        XCTAssertEqual(started.snapshot.balanceVersion, 9)
        XCTAssertEqual(HighSchoolCareerEngine.draftThreshold(state: started.snapshot), 50)
        let forecast = HighSchoolCareerEngine.draftForecast(state: started.snapshot)
        XCTAssertEqual(forecast.presentation?.bandID, .outside)
    }

    func testOlderRulesStillSimulateTwoAutomaticGames() throws {
        let (engine, started) = try started(rules: 8)
        let games = HighSchoolCareerEngine.simulateChapterGames(
            state: started.snapshot,
            chapter: started.snapshot.chapter,
            seed: 4_242
        )
        XCTAssertEqual(games.count, 2)
        XCTAssertTrue(games.allSatisfy { $0.played == false })
        _ = engine
    }

    func testAClaimedChapterDropsTheFirstAutomaticLineButKeepsTheRngOrder() throws {
        let (engine, started) = try started()
        let unclaimed = HighSchoolCareerEngine.simulateChapterGames(
            state: started.snapshot,
            chapter: started.snapshot.chapter,
            seed: 4_242
        )
        XCTAssertEqual(unclaimed.count, 2)

        let claimedState = try rewriteBalanceVersion(started.snapshot, to: 9, engine: engine)
        XCTAssertEqual(claimedState.chapterGameClaimed, true)
        let claimed = HighSchoolCareerEngine.simulateChapterGames(
            state: claimedState,
            chapter: claimedState.chapter,
            seed: 4_242
        )
        XCTAssertEqual(claimed.count, 1)
        XCTAssertEqual(claimed[0].outs, unclaimed[1].outs)
        XCTAssertEqual(claimed[0].strikeouts, unclaimed[1].strikeouts)
        XCTAssertEqual(claimed[0].walks, unclaimed[1].walks)
        XCTAssertEqual(claimed[0].runsAllowed, unclaimed[1].runsAllowed)
        XCTAssertEqual(claimed[0].pitches, unclaimed[1].pitches)
        XCTAssertEqual(claimed[0].teamRuns, unclaimed[1].teamRuns)
        XCTAssertEqual(claimed[0].opponentRuns, unclaimed[1].opponentRuns)
    }

    func testClaimingAChapterGameReturnsToReviewAfterTheOuting() throws {
        let (engine, started) = try started()
        var result = started
        var guardCount = 0
        while result.snapshot.phase != .chapterReview, guardCount < 80 {
            guardCount += 1
            switch result.snapshot.phase {
            case .training:
                result = try engine.commitTraining(.init(
                    seed: result.nextSeed, state: result.snapshot,
                    focus: .command, intensity: .standard
                ))
            case .relationship:
                result = try engine.resolveRelationship(.init(
                    seed: result.nextSeed, state: result.snapshot, response: .listen
                ))
            case .importantGame:
                result = try engine.recordImportantGame(.init(
                    seed: result.nextSeed, state: result.snapshot,
                    report: .init(
                        scenarioNumber: result.snapshot.performance.importantGamesCompleted + 1,
                        pitches: 12, strikeouts: 1, walks: 1, runsAllowed: 0,
                        expectedDamage: 400, actualDamage: 200, recommendationAccepted: 4,
                        outs: 3
                    )
                ))
            case .awakening:
                let option = try XCTUnwrap(result.snapshot.awakeningOptions.first)
                result = try engine.chooseAwakening(.init(
                    seed: result.nextSeed, state: result.snapshot, awakening: option
                ))
            default:
                XCTFail("unexpected phase \(result.snapshot.phase)")
                return
            }
        }
        XCTAssertEqual(result.snapshot.phase, .chapterReview)
        let review = result
        result = try engine.claimChapterGame(.init(seed: result.nextSeed, state: result.snapshot))
        XCTAssertEqual(result.snapshot.phase, .importantGame)
        XCTAssertEqual(result.snapshot.chapterGameClaimed, true)
        XCTAssertEqual(result.snapshot.currentGameScenario?.id, "regular-chapter")
        XCTAssertEqual(result.snapshot.milestoneIndex, review.snapshot.milestoneIndex)

        let gamesBefore = result.snapshot.performance.importantGamesCompleted
        result = try engine.recordImportantGame(.init(
            seed: result.nextSeed, state: result.snapshot,
            report: .init(
                scenarioNumber: gamesBefore + 1,
                pitches: 18, strikeouts: 2, walks: 1, runsAllowed: 1,
                expectedDamage: 500, actualDamage: 400, recommendationAccepted: 6,
                outs: 6
            )
        ))
        XCTAssertEqual(result.snapshot.phase, .chapterReview)
        XCTAssertEqual(result.snapshot.chapterGameClaimed, true)
        XCTAssertNil(result.snapshot.currentGameScenario)
        XCTAssertEqual(result.snapshot.performance.importantGamesCompleted, gamesBefore + 1)

        XCTAssertThrowsError(
            try engine.claimChapterGame(.init(seed: result.nextSeed, state: result.snapshot))
        )

        let advanced = try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
        XCTAssertEqual(advanced.snapshot.phase, .training)
        XCTAssertEqual(advanced.snapshot.chapterGameClaimed, false)
        let auto = (advanced.snapshot.seasonLog ?? []).filter { !$0.played }
        XCTAssertEqual(auto.count, 1, "claimed chapter keeps one automatic line")
    }

    func testRulesEightCannotClaimAChapterGame() throws {
        let (engine, started) = try started(rules: 8)
        var result = started
        var guardCount = 0
        while result.snapshot.phase != .chapterReview, guardCount < 80 {
            guardCount += 1
            switch result.snapshot.phase {
            case .training:
                result = try engine.commitTraining(.init(
                    seed: result.nextSeed, state: result.snapshot,
                    focus: .command, intensity: .standard
                ))
            case .relationship:
                result = try engine.resolveRelationship(.init(
                    seed: result.nextSeed, state: result.snapshot, response: .listen
                ))
            case .importantGame:
                result = try engine.recordImportantGame(.init(
                    seed: result.nextSeed, state: result.snapshot,
                    report: .init(
                        scenarioNumber: result.snapshot.performance.importantGamesCompleted + 1,
                        pitches: 12, strikeouts: 1, walks: 1, runsAllowed: 0,
                        expectedDamage: 400, actualDamage: 200, recommendationAccepted: 4,
                        outs: 3
                    )
                ))
            case .awakening:
                let option = try XCTUnwrap(result.snapshot.awakeningOptions.first)
                result = try engine.chooseAwakening(.init(
                    seed: result.nextSeed, state: result.snapshot, awakening: option
                ))
            default:
                XCTFail("unexpected phase \(result.snapshot.phase)")
                return
            }
        }
        XCTAssertThrowsError(
            try engine.claimChapterGame(.init(seed: result.nextSeed, state: result.snapshot))
        )
    }

    func testInningsWeightShrinksASmallSampleAndFillsAtTheCap() {
        // 비율 6, 아웃 9 → 가중 9/36 = 1/4 → 1
        // 비율 6, 아웃 36 → 가득 → 6
        XCTAssertEqual(6 * min(36, 9) / 36, 1)
        XCTAssertEqual(6 * min(36, 36) / 36, 6)
        XCTAssertEqual(6 * min(36, 90) / 36, 6)
        XCTAssertEqual(HighSchoolGameplayRules.performanceSampleOuts, 36)
    }
}
