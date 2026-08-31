import XCTest
@testable import SimulationCore

final class ProCareerAutumnTests: XCTestCase {
    func testLadderStartsMatchRegularSeasonSeeds() {
        XCTAssertEqual(ProPostseasonRules.firstRound(forSeed: 1), .final)
        XCTAssertEqual(ProPostseasonRules.firstRound(forSeed: 2), .playoff)
        XCTAssertEqual(ProPostseasonRules.firstRound(forSeed: 3), .semifinal)
        XCTAssertEqual(ProPostseasonRules.firstRound(forSeed: 4), .wildCard)
        XCTAssertEqual(ProPostseasonRules.firstRound(forSeed: 5), .wildCard)
    }

    func testFourthSeedAdvancesOnOneWildCardWin() {
        var state = ProPostseasonState(seed: 4, currentRound: .wildCard, result: .inProgress, gamesPlayed: 0)
        state = ProPostseasonRules.resolving(state, won: true)
        XCTAssertEqual(state.currentRound, .semifinal)
        XCTAssertEqual(state.result, .inProgress)
        XCTAssertEqual(state.gamesPlayed, 1)
    }

    func testFourthSeedGetsASecondWildCardAfterLosingGameOne() {
        var state = ProPostseasonState(seed: 4, currentRound: .wildCard, result: .inProgress, gamesPlayed: 0)
        state = ProPostseasonRules.resolving(state, won: false)
        XCTAssertEqual(state.currentRound, .wildCard)
        XCTAssertEqual(state.result, .inProgress)
        state = ProPostseasonRules.resolving(state, won: false)
        XCTAssertEqual(state.result, .eliminated)
        XCTAssertEqual(state.gamesPlayed, 2)
    }

    func testFifthSeedMustSweepWildCardThenCanReachTitleInFiveGames() {
        var state = ProPostseasonState(seed: 5, currentRound: .wildCard, result: .inProgress, gamesPlayed: 0)
        state = ProPostseasonRules.resolving(state, won: true)
        XCTAssertEqual(state.currentRound, .wildCard)
        state = ProPostseasonRules.resolving(state, won: true)
        XCTAssertEqual(state.currentRound, .semifinal)
        state = ProPostseasonRules.resolving(state, won: true)
        XCTAssertEqual(state.currentRound, .playoff)
        state = ProPostseasonRules.resolving(state, won: true)
        XCTAssertEqual(state.currentRound, .final)
        state = ProPostseasonRules.resolving(state, won: true)
        XCTAssertEqual(state.result, .champion)
        XCTAssertEqual(state.gamesPlayed, 5)
        XCTAssertLessThanOrEqual(state.gamesPlayed, ProPostseasonRules.maximumPlayerPathGames)
    }

    func testFifthSeedLossEndsAfterOneScene() {
        var state = ProPostseasonState(seed: 5, currentRound: .wildCard, result: .inProgress, gamesPlayed: 0)
        state = ProPostseasonRules.resolving(state, won: false)
        XCTAssertEqual(state.result, .eliminated)
        XCTAssertEqual(state.currentRound, .wildCard)
    }

    func testMinorAndInjuryCannotPitchAutumn() {
        let qualified = ProPostseasonState(seed: 2, currentRound: .playoff, result: .inProgress, gamesPlayed: 0)
        let minor = ProPostseasonRules.playerPath(from: qualified, level: .minor, injuryWeeks: 0)
        XCTAssertEqual(minor.result, .unavailable)
        XCTAssertNil(minor.currentRound)
        let injured = ProPostseasonRules.playerPath(from: qualified, level: .major, injuryWeeks: 2)
        XCTAssertEqual(injured.result, .unavailable)
        let ready = ProPostseasonRules.playerPath(from: qualified, level: .major, injuryWeeks: 0)
        XCTAssertEqual(ready.result, .inProgress)
        XCTAssertEqual(ready.currentRound, .playoff)
    }

    func testRecognitionIDsKeepHowFarYouWent() {
        let wildCardOut = ProPostseasonState(seed: 5, currentRound: .wildCard, result: .eliminated, gamesPlayed: 1)
        XCTAssertEqual(
            ProPostseasonRules.recognitionIDs(for: wildCardOut),
            ["pro.autumn.qualified", "pro.autumn.wild-card"]
        )
        let playoffOut = ProPostseasonState(seed: 2, currentRound: .playoff, result: .eliminated, gamesPlayed: 1)
        XCTAssertEqual(
            ProPostseasonRules.recognitionIDs(for: playoffOut),
            ["pro.autumn.qualified", "pro.autumn.playoff"]
        )
        let champion = ProPostseasonState(seed: 1, currentRound: .final, result: .champion, gamesPlayed: 1)
        XCTAssertEqual(
            ProPostseasonRules.recognitionIDs(for: champion),
            ["pro.autumn.qualified", "pro.autumn.final", "pro.autumn.champion"]
        )
        let sidelined = ProPostseasonState(seed: 1, currentRound: nil, result: .unavailable, gamesPlayed: 0)
        XCTAssertEqual(ProPostseasonRules.recognitionIDs(for: sidelined), [])
    }

    func testHofBonusGivesEliminatedAPoint() {
        XCTAssertEqual(ProPostseasonRules.hofBonus(for: .champion), 4)
        XCTAssertEqual(ProPostseasonRules.hofBonus(for: .runnerUp), 2)
        XCTAssertEqual(ProPostseasonRules.hofBonus(for: .eliminated), 1)
        XCTAssertEqual(ProPostseasonRules.hofBonus(for: .didNotQualify), 0)
        XCTAssertEqual(ProPostseasonRules.hofBonus(for: .unavailable), 0)
    }

    func testEvaluateEndOfSeasonUsesTopFiveCut() throws {
        let engine = ProCareerEngine(journeyEnabled: true)
        let started = try engine.start(startParams(seed: "992001"))
        let accepted = try acceptRookie(engine, started)
        let winningLines = (1...24).map { week in
            ProGameLine(
                season: 1,
                week: week,
                outingNumber: week,
                started: true,
                outs: 18,
                strikeouts: 8,
                walks: 1,
                runsAllowed: 1,
                pitches: 90,
                teamRuns: 6,
                opponentRuns: 1,
                decision: .win,
                played: false,
                hits: 4,
                homeRuns: 0
            )
        }
        let winning = try unsignedSnapshot(engine, accepted.snapshot) { object in
            object["week"] = 24
            object["gameLines"] = try encodeLines(winningLines)
        }
        let qualified = ProPostseasonRules.evaluateEndOfSeason(winning)
        if qualified.result == .didNotQualify {
            // Deterministic league table can still bury a team; the cut itself must reject rank 6+.
            XCTAssertGreaterThan(
                ProPostseasonRules.rank(state: winning, week: 24) ?? 10,
                ProPostseasonRules.qualificationCut
            )
        } else {
            XCTAssertEqual(qualified.result, .inProgress)
            XCTAssertLessThanOrEqual(qualified.seed, 5)
        }

        let losingLines = (1...24).map { week in
            ProGameLine(
                season: 1,
                week: week,
                outingNumber: week,
                started: true,
                outs: 12,
                strikeouts: 2,
                walks: 5,
                runsAllowed: 8,
                pitches: 90,
                teamRuns: 1,
                opponentRuns: 9,
                decision: .loss,
                played: false,
                hits: 12,
                homeRuns: 2
            )
        }
        let losing = try unsignedSnapshot(engine, accepted.snapshot) { object in
            object["week"] = 24
            object["gameLines"] = try encodeLines(losingLines)
        }
        let missed = ProPostseasonRules.evaluateEndOfSeason(losing)
        XCTAssertEqual(missed.result, .didNotQualify)
    }

    func testAutumnResolveDoesNotInflateRegularInnings() throws {
        let engine = ProCareerEngine(journeyEnabled: true)
        let started = try engine.start(startParams(seed: "992010"))
        let accepted = try acceptRookie(engine, started)
        let postseason = ProPostseasonState(seed: 5, currentRound: .wildCard, result: .inProgress, gamesPlayed: 0)
        let beforeOuts = accepted.snapshot.currentStats.inningsOuts
        let autumn = try unsignedSnapshot(engine, accepted.snapshot) { object in
            object["week"] = 24
            object["phase"] = ProCareerPhase.importantGame.rawValue
            object["seasonTrigger"] = ProSeasonTrigger.autumnWildCard.rawValue
            object["postseason"] = try encodeValue(postseason)
        }
        let resolved = try engine.resolveImportantGame(.init(
            seed: "99201024",
            state: autumn,
            report: .init(
                scenarioNumber: 24,
                pitches: 18,
                strikeouts: 2,
                walks: 0,
                runsAllowed: 3,
                expectedDamage: 400,
                actualDamage: 900,
                recommendationAccepted: 4,
                outs: 6,
                teamRuns: 1,
                scoreDifferentialAtEntry: -1,
                hits: 4,
                homeRuns: 1
            )
        ))
        XCTAssertEqual(resolved.snapshot.currentStats.inningsOuts, beforeOuts)
        XCTAssertEqual(resolved.snapshot.postseason?.result, .eliminated)
        XCTAssertEqual(resolved.snapshot.phase, .seasonReview)
        XCTAssertFalse((resolved.snapshot.gameLines ?? []).contains { $0.played })
    }

    func testInjuredOrMinorPlayerDoesNotOpenAutumnWhenTeamQualifies() throws {
        let engine = ProCareerEngine(journeyEnabled: true)
        let started = try engine.start(startParams(seed: "992020"))
        let accepted = try acceptRookie(engine, started)
        let winningLines = (1...23).map { week in
            ProGameLine(
                season: 1,
                week: week,
                outingNumber: week,
                started: true,
                outs: 18,
                strikeouts: 8,
                walks: 1,
                runsAllowed: 1,
                pitches: 90,
                teamRuns: 6,
                opponentRuns: 1,
                decision: .win,
                played: false,
                hits: 4,
                homeRuns: 0
            )
        }
        let injured = try unsignedSnapshot(engine, accepted.snapshot) { object in
            object["week"] = 23
            object["level"] = ProLevel.major.rawValue
            object["injuryWeeks"] = 2
            object["phase"] = ProCareerPhase.weeklyPlan.rawValue
            object["gameLines"] = try encodeLines(winningLines)
        }
        let injuredPlan = try engine.planWeek(.init(seed: "99202023", state: injured, plan: .recover))
        if ProPostseasonRules.evaluateEndOfSeason(injured).result == .inProgress {
            XCTAssertEqual(injuredPlan.snapshot.postseason?.result, .unavailable)
            XCTAssertNotEqual(injuredPlan.snapshot.phase, .importantGame)
            XCTAssertTrue(injuredPlan.snapshot.news.contains { $0.contains("부상") })
        }

        let minor = try unsignedSnapshot(engine, accepted.snapshot) { object in
            object["week"] = 23
            object["level"] = ProLevel.minor.rawValue
            object["managerTrust"] = 40
            object["injuryWeeks"] = 0
            object["phase"] = ProCareerPhase.weeklyPlan.rawValue
            object["gameLines"] = try encodeLines(winningLines)
        }
        let minorPlan = try engine.planWeek(.init(seed: "99202024", state: minor, plan: .recover))
        if ProPostseasonRules.evaluateEndOfSeason(minor).result == .inProgress {
            XCTAssertEqual(minorPlan.snapshot.postseason?.result, .unavailable)
            XCTAssertNotEqual(minorPlan.snapshot.phase, .importantGame)
            XCTAssertTrue(minorPlan.snapshot.news.contains { $0.contains("2군") })
        }
    }

    func testV5SaveDoesNotOpenAutumn() throws {
        let engine = ProCareerEngine(journeyEnabled: true)
        let started = try engine.start(startParams(seed: "992002"))
        let accepted = try acceptRookie(engine, started)
        let v5 = try unsignedSnapshot(engine, accepted.snapshot) { object in
            object["proRulesVersion"] = 5
            object["week"] = 23
            object["phase"] = ProCareerPhase.weeklyPlan.rawValue
        }
        XCTAssertTrue(ProCareerEngine.usesCareerArcRules(v5))
        XCTAssertFalse(ProCareerEngine.usesAutumnRules(v5))
        let planned = try engine.planWeek(.init(seed: "99200223", state: v5, plan: .recover))
        XCTAssertNotEqual(planned.snapshot.phase, .importantGame)
        XCTAssertTrue(
            planned.snapshot.phase == .seasonReview
                || planned.snapshot.phase == .seasonDecision
                || planned.snapshot.phase == .weeklyPlan
        )
    }

    private func startParams(seed: String) -> StartProCareerParams {
        .init(
            seed: seed,
            identity: .defaultPitcher,
            pitcher: .init(id: "autumn-pitcher", name: "Autumn", stuff: 60, command: 58, movement: 57, stamina: 59),
            draftResult: .init(
                outcome: .drafted,
                evaluationScore: 70,
                projectedRange: "2~3라운드",
                team: ProCareerEngine.proTeams[0],
                round: 2,
                overallPick: 20,
                signingBonus: 100_000_000,
                firstSeasonGoal: "2군 선발",
                summary: "지명"
            ),
            entitlement: .init(status: .active, source: .development, verifiedAt: "2026-08-20")
        )
    }

    private func acceptRookie(_ engine: ProCareerEngine, _ started: ProCareerResult) throws -> ProCareerResult {
        let market = try XCTUnwrap(started.snapshot.journeyState?.pendingContractMarket)
        return try engine.acceptContract(.init(
            seed: started.nextSeed,
            state: started.snapshot,
            expectedRevision: started.snapshot.revision,
            marketID: market.id,
            offerID: market.offers[0].id,
            ambition: .franchiseIcon
        ))
    }

    private func unsignedSnapshot(
        _ engine: ProCareerEngine,
        _ snapshot: ProCareerSnapshot,
        mutate: (inout [String: Any]) throws -> Void
    ) throws -> ProCareerSnapshot {
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as! [String: Any]
        try mutate(&object)
        let decoded = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: try JSONSerialization.data(withJSONObject: object)
        )
        return engine.replacing(decoded, commitment: engine.commitment(decoded))
    }

    private func encodeLines(_ lines: [ProGameLine]) throws -> [[String: Any]] {
        try XCTUnwrap(encodeJSON(lines) as? [[String: Any]])
    }

    private func encodeValue<T: Encodable>(_ value: T) throws -> Any {
        try encodeJSON(value)
    }

    private func encodeJSON<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    }
}
