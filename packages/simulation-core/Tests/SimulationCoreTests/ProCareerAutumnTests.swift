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

    func testV7SemifinalNeedsTwoWinsAndPreservesHistoryIntoPlayoff() {
        var state = ProPostseasonState(
            seed: 3,
            currentRound: .semifinal,
            result: .inProgress,
            gamesPlayed: 0,
            series: ProPostseasonRules.openingSeries(
                round: .semifinal,
                seed: 3,
                opponentTeamID: "opponent-a",
                previousDirectAppearances: 0
            )
        )
        state = ProPostseasonRules.resolvingSeriesGame(
            state,
            won: true,
            directlyPlayed: true,
            pitches: 15,
            outs: 3,
            runsAllowed: 0,
            teamRuns: 4,
            opponentRuns: 2
        )
        XCTAssertEqual(state.currentRound, .semifinal)
        XCTAssertEqual(state.series?.playerWins, 1)
        state = ProPostseasonRules.resolvingSeriesGame(
            state,
            won: true,
            directlyPlayed: false,
            teamRuns: 5,
            opponentRuns: 3
        )
        XCTAssertEqual(state.currentRound, .playoff)
        XCTAssertEqual(state.result, .inProgress)
        XCTAssertEqual(state.series?.playerWinsRequired, 2)
        XCTAssertEqual(state.series?.totalDirectAppearances, 1)
        XCTAssertEqual(state.gameHistory?.count, 2)
        XCTAssertEqual(state.gameHistory?.map(\.round), [.semifinal, .semifinal])
    }

    func testSeriesRivalMemoryPersistsWithinRoundAndResetsForNextOpponent() {
        let memory = RivalMemorySnapshot(
            matchupID: "pitcher:bench:semifinal-opponent",
            revision: 1,
            plateAppearancesSeen: 1,
            totalPitchesSeen: 1,
            recentObservations: [
                .init(
                    pitchType: .fourSeam,
                    zone: .init(row: 0, column: 0),
                    zoneIntent: .strike,
                    balls: 0,
                    strikes: 0,
                    outcome: .calledStrike
                )
            ]
        )
        var state = ProPostseasonState(
            seed: 3,
            currentRound: .semifinal,
            result: .inProgress,
            gamesPlayed: 0,
            series: ProPostseasonRules.openingSeries(
                round: .semifinal,
                seed: 3,
                opponentTeamID: "opponent-a",
                previousDirectAppearances: 0
            )
        )
        state = ProPostseasonRules.resolvingSeriesGame(
            state,
            won: true,
            directlyPlayed: true,
            pitches: 12,
            outs: 3,
            runsAllowed: 0,
            teamRuns: 3,
            opponentRuns: 1,
            rivalMemory: memory
        )
        XCTAssertEqual(state.series?.rivalMemory, memory)
        state = ProPostseasonRules.resolvingSeriesGame(
            state,
            won: true,
            directlyPlayed: false,
            teamRuns: 4,
            opponentRuns: 2
        )
        XCTAssertEqual(state.currentRound, .playoff)
        XCTAssertNil(state.series?.rivalMemory)
    }

    func testWildCardSeriesKeepsFourthAndFifthSeedAdvantages() {
        XCTAssertEqual(ProPostseasonRules.winsRequired(round: .wildCard, seed: 4).player, 1)
        XCTAssertEqual(ProPostseasonRules.winsRequired(round: .wildCard, seed: 4).opponent, 2)
        XCTAssertEqual(ProPostseasonRules.winsRequired(round: .wildCard, seed: 5).player, 2)
        XCTAssertEqual(ProPostseasonRules.winsRequired(round: .wildCard, seed: 5).opponent, 1)
    }

    func testPreparedSeriesPinsADeterministicOpponentTeam() throws {
        let engine = ProCareerEngine(journeyEnabled: true)
        let started = try engine.start(startParams(seed: "992019"))
        let accepted = try acceptRookie(engine, started)
        let postseason = ProPostseasonState(
            seed: 2,
            currentRound: .playoff,
            result: .inProgress,
            gamesPlayed: 0
        )
        let prepared = ProPostseasonRules.preparingSeries(postseason, state: accepted.snapshot)
        XCTAssertEqual(prepared.series?.round, .playoff)
        XCTAssertNotNil(prepared.series?.opponentTeamID)
        XCTAssertNotEqual(prepared.series?.opponentTeamID, accepted.snapshot.team.id)
        XCTAssertEqual(
            ProPostseasonRules.preparingSeries(postseason, state: accepted.snapshot).series?.opponentTeamID,
            prepared.series?.opponentTeamID
        )
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

    func testV7FinalSeriesNeedsThreeWinsAndAlternatesDirectGames() {
        var state = ProPostseasonState(
            seed: 1,
            currentRound: .final,
            result: .inProgress,
            gamesPlayed: 0
        )
        XCTAssertTrue(ProPostseasonRules.shouldDirectlyPlayNextFinalGame(state))

        state = ProPostseasonRules.resolvingFinalGame(
            state,
            won: true,
            directlyPlayed: true,
            pitches: 17
        )
        XCTAssertEqual(state.result, .inProgress)
        XCTAssertEqual(state.series?.playerWins, 1)
        XCTAssertEqual(state.series?.nextGameNumber, 2)
        XCTAssertFalse(ProPostseasonRules.shouldDirectlyPlayNextFinalGame(state))

        state = ProPostseasonRules.resolvingFinalGame(state, won: false, directlyPlayed: false)
        XCTAssertEqual(state.series?.opponentWins, 1)
        XCTAssertEqual(state.series?.nextGameNumber, 3)
        XCTAssertTrue(ProPostseasonRules.shouldDirectlyPlayNextFinalGame(state))

        state = ProPostseasonRules.resolvingFinalGame(state, won: true, directlyPlayed: true, pitches: 14)
        state = ProPostseasonRules.resolvingFinalGame(state, won: false, directlyPlayed: false)
        state = ProPostseasonRules.resolvingFinalGame(state, won: true, directlyPlayed: true, pitches: 19)
        XCTAssertEqual(state.result, .champion)
        XCTAssertEqual(state.gamesPlayed, 5)
        XCTAssertEqual(state.series?.playerWins, 3)
        XCTAssertEqual(state.series?.opponentWins, 2)
        XCTAssertEqual(state.series?.totalDirectAppearances, 3)
        XCTAssertEqual(state.series?.lastAppearancePitches, 19)
    }

    func testFinalSeriesHonorsFiveAppearancePostseasonBudget() {
        var state = ProPostseasonState(
            seed: 5,
            currentRound: .final,
            result: .inProgress,
            gamesPlayed: 4
        )
        XCTAssertTrue(ProPostseasonRules.shouldDirectlyPlayNextFinalGame(state))
        state = ProPostseasonRules.resolvingFinalGame(
            state,
            won: true,
            directlyPlayed: true,
            pitches: 12
        )
        XCTAssertEqual(state.series?.totalDirectAppearances, 5)
        XCTAssertFalse(ProPostseasonRules.shouldDirectlyPlayNextFinalGame(state))
    }

    func testLegacyPostseasonPayloadDecodesWithoutSeriesState() throws {
        let state = ProPostseasonState(
            seed: 2,
            currentRound: .playoff,
            result: .inProgress,
            gamesPlayed: 0
        )
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as! [String: Any]
        object.removeValue(forKey: "series")
        let decoded = try JSONDecoder().decode(
            ProPostseasonState.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertNil(decoded.series)
        XCTAssertEqual(decoded, state)
    }

    func testBullpenAvailabilityRoundTripsInSeriesSave() throws {
        let state = ProPostseasonState(
            seed: 1,
            currentRound: .final,
            result: .inProgress,
            gamesPlayed: 1,
            series: .init(
                playerWins: 1,
                opponentWins: 0,
                nextGameNumber: 2,
                totalDirectAppearances: 1,
                lastAppearancePitches: 14,
                lastAppearanceGameNumber: 1,
                availabilityDecision: .pitchAgain
            )
        )
        let decoded = try JSONDecoder().decode(
            ProPostseasonState.self,
            from: JSONEncoder().encode(state)
        )
        XCTAssertEqual(decoded, state)
    }

    func testFinalSeriesValidationRejectsImpossibleScoreAndAppearanceCounts() {
        let impossibleScore = ProPostseasonState(
            seed: 1,
            currentRound: .final,
            result: .inProgress,
            gamesPlayed: 2,
            series: .init(
                playerWins: 2,
                opponentWins: 0,
                nextGameNumber: 2,
                totalDirectAppearances: 1
            )
        )
        let impossibleAppearances = ProPostseasonState(
            seed: 1,
            currentRound: .final,
            result: .inProgress,
            gamesPlayed: 1,
            series: .init(
                playerWins: 1,
                opponentWins: 0,
                nextGameNumber: 2,
                totalDirectAppearances: 2
            )
        )
        XCTAssertFalse(ProPostseasonRules.isValidSeriesState(impossibleScore))
        XCTAssertFalse(ProPostseasonRules.isValidSeriesState(impossibleAppearances))
    }

    func testBullpenMustChooseBeforeConsecutiveFinalAppearance() {
        let opening = ProPostseasonState(
            seed: 1,
            currentRound: .final,
            result: .inProgress,
            gamesPlayed: 0
        )
        let afterGameOne = ProPostseasonRules.resolvingFinalGame(
            opening,
            won: true,
            directlyPlayed: true,
            pitches: 16
        )
        XCTAssertTrue(ProPostseasonRules.requiresAvailabilityDecision(afterGameOne, role: .setup))
        XCTAssertFalse(ProPostseasonRules.canStartDirectAppearance(afterGameOne, role: .setup))
        XCTAssertFalse(ProPostseasonRules.requiresAvailabilityDecision(afterGameOne, role: .starter))

        let committed = ProPostseasonRules.choosingAvailability(afterGameOne, choice: .pitchAgain)
        XCTAssertFalse(ProPostseasonRules.requiresAvailabilityDecision(committed, role: .setup))
        XCTAssertTrue(ProPostseasonRules.canStartDirectAppearance(committed, role: .setup))
    }

    func testBullpenRestChoiceSimulatesOneGameAndReturnsForTheNext() throws {
        let engine = ProCareerEngine(journeyEnabled: true)
        let started = try engine.start(startParams(seed: "992012"))
        let accepted = try acceptRookie(engine, started)
        let postseason = ProPostseasonState(
            seed: 1,
            currentRound: .final,
            result: .inProgress,
            gamesPlayed: 1,
            series: .init(
                playerWins: 1,
                opponentWins: 0,
                nextGameNumber: 2,
                totalDirectAppearances: 1,
                lastAppearancePitches: 16,
                lastAppearanceGameNumber: 1
            )
        )
        let awaiting = try unsignedSnapshot(engine, accepted.snapshot) { object in
            object["week"] = 24
            object["level"] = ProLevel.major.rawValue
            object["role"] = ProRole.setup.rawValue
            object["fatigue"] = 55
            object["phase"] = ProCareerPhase.importantGame.rawValue
            object["seasonTrigger"] = ProSeasonTrigger.autumnFinal.rawValue
            object["postseason"] = try encodeValue(postseason)
        }
        let rested = try engine.choosePostseasonAvailability(.init(
            seed: "99201224",
            state: awaiting,
            choice: .restForDecider
        ))
        XCTAssertEqual(rested.snapshot.postseason?.gamesPlayed, 2)
        XCTAssertEqual(rested.snapshot.postseason?.series?.nextGameNumber, 3)
        XCTAssertEqual(rested.snapshot.postseason?.series?.lastAppearanceGameNumber, 1)
        XCTAssertEqual(rested.snapshot.fatigue, 43)
        XCTAssertEqual(rested.snapshot.phase, .importantGame)
        XCTAssertTrue(ProPostseasonRules.canStartDirectAppearance(
            try XCTUnwrap(rested.snapshot.postseason),
            role: .setup
        ))
        XCTAssertTrue(rested.events.contains("pro_autumn_availability_rest"))
        XCTAssertTrue(rested.events.contains("pro_autumn_team_game_simulated"))
    }

    func testBullpenPitchAgainChoicePersistsAndRaisesFatigue() throws {
        let engine = ProCareerEngine(journeyEnabled: true)
        let started = try engine.start(startParams(seed: "992013"))
        let accepted = try acceptRookie(engine, started)
        let postseason = ProPostseasonState(
            seed: 1,
            currentRound: .final,
            result: .inProgress,
            gamesPlayed: 1,
            series: .init(
                playerWins: 1,
                opponentWins: 0,
                nextGameNumber: 2,
                totalDirectAppearances: 1,
                lastAppearancePitches: 16,
                lastAppearanceGameNumber: 1
            )
        )
        let awaiting = try unsignedSnapshot(engine, accepted.snapshot) { object in
            object["week"] = 24
            object["level"] = ProLevel.major.rawValue
            object["role"] = ProRole.closer.rawValue
            object["fatigue"] = 50
            object["phase"] = ProCareerPhase.importantGame.rawValue
            object["seasonTrigger"] = ProSeasonTrigger.autumnFinal.rawValue
            object["postseason"] = try encodeValue(postseason)
        }
        let committed = try engine.choosePostseasonAvailability(.init(
            seed: "99201324",
            state: awaiting,
            choice: .pitchAgain
        ))
        XCTAssertEqual(committed.snapshot.postseason?.series?.availabilityDecision, .pitchAgain)
        XCTAssertEqual(committed.snapshot.fatigue, 54)
        XCTAssertTrue(ProPostseasonRules.canStartDirectAppearance(
            try XCTUnwrap(committed.snapshot.postseason),
            role: .closer
        ))
        XCTAssertEqual(committed.events, ["pro_autumn_availability_pitch_again"])
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
        let history: [ProPostseasonGameLine] = [
            .init(round: .final, gameNumber: 1, teamRuns: 4, opponentRuns: 2, directlyPlayed: true, playerPitches: 15, playerOuts: 3, playerRunsAllowed: 0),
            .init(round: .final, gameNumber: 2, teamRuns: 3, opponentRuns: 1, directlyPlayed: false),
            .init(round: .final, gameNumber: 3, teamRuns: 5, opponentRuns: 4, directlyPlayed: true, playerPitches: 18, playerOuts: 3, playerRunsAllowed: 1),
        ]
        let champion = ProPostseasonState(
            seed: 1,
            currentRound: .final,
            result: .champion,
            gamesPlayed: 3,
            series: .init(
                round: .final,
                opponentTeamID: "opponent",
                playerWinsRequired: 3,
                opponentWinsRequired: 3,
                playerWins: 3,
                opponentWins: 0,
                nextGameNumber: 4,
                totalDirectAppearances: 2,
                lastAppearancePitches: 18,
                lastAppearanceGameNumber: 3,
                gameLines: history
            ),
            gameHistory: history
        )
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

    func testV7FinalResolvePlaysOneAppearanceAndSimulatesTheEvenGame() throws {
        let engine = ProCareerEngine(journeyEnabled: true)
        let started = try engine.start(startParams(seed: "992011"))
        let accepted = try acceptRookie(engine, started)
        let final = ProPostseasonState(seed: 1, currentRound: .final, result: .inProgress, gamesPlayed: 0)
        let beforeFatigue = accepted.snapshot.fatigue
        let autumn = try unsignedSnapshot(engine, accepted.snapshot) { object in
            object["week"] = 24
            object["level"] = ProLevel.major.rawValue
            object["phase"] = ProCareerPhase.importantGame.rawValue
            object["seasonTrigger"] = ProSeasonTrigger.autumnFinal.rawValue
            object["postseason"] = try encodeValue(final)
        }
        let resolved = try engine.resolveImportantGame(.init(
            seed: "99201124",
            state: autumn,
            report: .init(
                scenarioNumber: 24,
                pitches: 18,
                strikeouts: 3,
                walks: 0,
                runsAllowed: 0,
                expectedDamage: 400,
                actualDamage: 150,
                recommendationAccepted: 12,
                outs: 6,
                teamRuns: 4,
                scoreDifferentialAtEntry: 1,
                hits: 1,
                homeRuns: 0
            )
        ))
        XCTAssertEqual(resolved.snapshot.postseason?.series?.nextGameNumber, 3)
        XCTAssertEqual(resolved.snapshot.postseason?.series?.totalDirectAppearances, 1)
        XCTAssertEqual(resolved.snapshot.postseason?.gamesPlayed, 2)
        XCTAssertEqual(resolved.snapshot.phase, .importantGame)
        XCTAssertEqual(resolved.snapshot.seasonTrigger, .autumnFinal)
        XCTAssertGreaterThanOrEqual(resolved.snapshot.fatigue, beforeFatigue)
        XCTAssertTrue(resolved.events.contains("pro_autumn_team_game_simulated"))
    }

    func testPartialSetupAppearanceNoLongerDirectlyDeterminesTheGameWinner() throws {
        let engine = ProCareerEngine(journeyEnabled: true)
        let started = try engine.start(startParams(seed: "992014"))
        let accepted = try acceptRookie(engine, started)
        let final = ProPostseasonState(seed: 1, currentRound: .final, result: .inProgress, gamesPlayed: 0)
        let state = try unsignedSnapshot(engine, accepted.snapshot) { object in
            object["week"] = 24
            object["level"] = ProLevel.major.rawValue
            object["role"] = ProRole.setup.rawValue
            object["phase"] = ProCareerPhase.importantGame.rawValue
            object["seasonTrigger"] = ProSeasonTrigger.autumnFinal.rawValue
            object["postseason"] = try encodeValue(final)
        }
        let report = ImportantInningReport(
            scenarioNumber: 24,
            pitches: 15,
            strikeouts: 2,
            walks: 0,
            runsAllowed: 0,
            expectedDamage: 300,
            actualDamage: 100,
            recommendationAccepted: 10,
            outs: 3,
            scoreDifferentialAtEntry: 0,
            inningAtEntry: 8,
            outsAtEntry: 0,
            hits: 1,
            homeRuns: 0
        )
        var sawWin = false
        var sawLoss = false
        for seed in 1...120 {
            let resolved = try engine.resolveImportantGame(.init(
                seed: String(880_000 + seed),
                state: state,
                report: report
            ))
            let line = try XCTUnwrap(resolved.snapshot.postseason?.series?.gameLines?.first)
            XCTAssertTrue(line.directlyPlayed)
            XCTAssertEqual(line.playerRunsAllowed, 0)
            XCTAssertNotEqual(line.teamRuns, line.opponentRuns)
            sawWin = sawWin || line.won
            sawLoss = sawLoss || !line.won
        }
        XCTAssertTrue(sawWin, "동점에서 무실점으로 막은 뒤 타선이 이기는 경기가 있어야 한다")
        XCTAssertTrue(sawLoss, "동점에서 무실점으로 막아도 남은 이닝에서 팀이 질 수 있어야 한다")
    }

    func testSemifinalAlsoResolvesTheRemainingGameAfterAPlayerAppearance() throws {
        let engine = ProCareerEngine(journeyEnabled: true)
        let started = try engine.start(startParams(seed: "992017"))
        let accepted = try acceptRookie(engine, started)
        let postseason = ProPostseasonState(seed: 3, currentRound: .semifinal, result: .inProgress, gamesPlayed: 0)
        let state = try unsignedSnapshot(engine, accepted.snapshot) { object in
            object["week"] = 24
            object["level"] = ProLevel.major.rawValue
            object["role"] = ProRole.setup.rawValue
            object["phase"] = ProCareerPhase.importantGame.rawValue
            object["seasonTrigger"] = ProSeasonTrigger.autumnSemifinal.rawValue
            object["postseason"] = try encodeValue(postseason)
        }
        let report = ImportantInningReport(
            scenarioNumber: 24,
            pitches: 15,
            strikeouts: 2,
            walks: 0,
            runsAllowed: 0,
            expectedDamage: 300,
            actualDamage: 100,
            recommendationAccepted: 10,
            outs: 3,
            scoreDifferentialAtEntry: 0,
            inningAtEntry: 8,
            outsAtEntry: 0,
            hits: 1,
            homeRuns: 0
        )
        var wonGameOne = false
        var lostGameOne = false
        for seed in 1...120 {
            let resolved = try engine.resolveImportantGame(.init(
                seed: String(770_000 + seed),
                state: state,
                report: report
            ))
            wonGameOne = wonGameOne || resolved.snapshot.postseason?.series?.playerWins == 1
            lostGameOne = lostGameOne || resolved.snapshot.postseason?.series?.opponentWins == 1
        }
        XCTAssertTrue(wonGameOne)
        XCTAssertTrue(lostGameOne)
    }

    func testRegularSeasonStrengthMovesPostseasonOddsWithoutRemovingUpsets() throws {
        let engine = ProCareerEngine(journeyEnabled: true)
        let started = try engine.start(startParams(seed: "992018"))
        let accepted = try acceptRookie(engine, started)

        func makeState(dominant: Bool) throws -> ProCareerSnapshot {
            let lines = (1...24).map { week in
                ProGameLine(
                    season: 1,
                    week: week,
                    outingNumber: week,
                    started: false,
                    outs: 3,
                    strikeouts: dominant ? 3 : 0,
                    walks: dominant ? 0 : 3,
                    runsAllowed: dominant ? 0 : 5,
                    pitches: 18,
                    teamRuns: dominant ? 7 : 1,
                    opponentRuns: dominant ? 1 : 7,
                    decision: dominant ? .win : .loss,
                    played: false
                )
            }
            let postseason = ProPostseasonState(
                seed: 3,
                currentRound: .semifinal,
                result: .inProgress,
                gamesPlayed: 0
            )
            let base = try unsignedSnapshot(engine, accepted.snapshot) { object in
                object["week"] = 24
                object["level"] = ProLevel.major.rawValue
                object["role"] = ProRole.setup.rawValue
                object["phase"] = ProCareerPhase.importantGame.rawValue
                object["seasonTrigger"] = ProSeasonTrigger.autumnSemifinal.rawValue
                object["gameLines"] = try encodeLines(lines)
                object["postseason"] = try encodeValue(postseason)
            }
            let rows = ProPostseasonRules.standings(state: base, week: 24)
            let candidates = rows.filter { $0.teamID != base.team.id }
            let opponent = dominant ? try XCTUnwrap(candidates.last) : try XCTUnwrap(candidates.first)
            let rival = ProRivalBatter(
                id: "strength-rival-\(opponent.teamID)",
                name: "전력 비교 타자",
                archetype: "중심 타자",
                teamID: opponent.teamID,
                teamName: opponent.teamName,
                record: "시즌 기록",
                profile: "전력 비교"
            )
            return try unsignedSnapshot(engine, base) { object in
                object["currentRival"] = try encodeValue(rival)
            }
        }

        let strong = try makeState(dominant: true)
        let weak = try makeState(dominant: false)
        let strongEdge = ProPostseasonRules.teamStrengthEdgePermille(strong)
        let weakEdge = ProPostseasonRules.teamStrengthEdgePermille(weak)
        XCTAssertTrue((1...180).contains(strongEdge))
        XCTAssertTrue((-180 ... -1).contains(weakEdge))

        let report = ImportantInningReport(
            scenarioNumber: 24,
            pitches: 15,
            strikeouts: 2,
            walks: 0,
            runsAllowed: 0,
            expectedDamage: 300,
            actualDamage: 100,
            recommendationAccepted: 10,
            outs: 3,
            scoreDifferentialAtEntry: 0,
            inningAtEntry: 8,
            outsAtEntry: 0
        )
        var strongWins = 0
        var weakWins = 0
        for seed in 1...600 {
            let seedValue = String(660_000 + seed)
            let strongResult = try engine.resolveImportantGame(.init(seed: seedValue, state: strong, report: report))
            let weakResult = try engine.resolveImportantGame(.init(seed: seedValue, state: weak, report: report))
            if strongResult.snapshot.postseason?.series?.playerWins == 1 { strongWins += 1 }
            if weakResult.snapshot.postseason?.series?.playerWins == 1 { weakWins += 1 }
        }
        XCTAssertGreaterThan(strongWins, weakWins)
        XCTAssertTrue((1..<600).contains(strongWins))
        XCTAssertTrue((1..<600).contains(weakWins))
    }

    func testCloserWhoRecordsTheFinalThreeOutsWithALeadAlwaysWinsTheGame() throws {
        let engine = ProCareerEngine(journeyEnabled: true)
        let started = try engine.start(startParams(seed: "992015"))
        let accepted = try acceptRookie(engine, started)
        let final = ProPostseasonState(seed: 1, currentRound: .final, result: .inProgress, gamesPlayed: 0)
        let state = try unsignedSnapshot(engine, accepted.snapshot) { object in
            object["week"] = 24
            object["level"] = ProLevel.major.rawValue
            object["role"] = ProRole.closer.rawValue
            object["phase"] = ProCareerPhase.importantGame.rawValue
            object["seasonTrigger"] = ProSeasonTrigger.autumnFinal.rawValue
            object["postseason"] = try encodeValue(final)
        }
        let report = ImportantInningReport(
            scenarioNumber: 24,
            pitches: 13,
            strikeouts: 2,
            walks: 0,
            runsAllowed: 0,
            expectedDamage: 260,
            actualDamage: 80,
            recommendationAccepted: 9,
            outs: 3,
            scoreDifferentialAtEntry: 1,
            inningAtEntry: 9,
            outsAtEntry: 0,
            hits: 0,
            homeRuns: 0
        )
        for seed in 1...30 {
            let resolved = try engine.resolveImportantGame(.init(
                seed: String(990_000 + seed),
                state: state,
                report: report
            ))
            let line = try XCTUnwrap(resolved.snapshot.postseason?.series?.gameLines?.first)
            XCTAssertTrue(line.won)
        }
    }

    func testRunsAllowedShiftTheFinalScoreWithoutReplacingTheRemainderSimulation() throws {
        let engine = ProCareerEngine(journeyEnabled: true)
        let started = try engine.start(startParams(seed: "992016"))
        let accepted = try acceptRookie(engine, started)
        let final = ProPostseasonState(seed: 1, currentRound: .final, result: .inProgress, gamesPlayed: 0)
        let state = try unsignedSnapshot(engine, accepted.snapshot) { object in
            object["week"] = 24
            object["level"] = ProLevel.major.rawValue
            object["role"] = ProRole.setup.rawValue
            object["phase"] = ProCareerPhase.importantGame.rawValue
            object["seasonTrigger"] = ProSeasonTrigger.autumnFinal.rawValue
            object["postseason"] = try encodeValue(final)
        }
        func report(runs: Int) -> ImportantInningReport {
            .init(
                scenarioNumber: 24,
                pitches: 16,
                strikeouts: 2,
                walks: 0,
                runsAllowed: runs,
                expectedDamage: 300,
                actualDamage: runs == 0 ? 100 : 900,
                recommendationAccepted: 10,
                outs: 3,
                scoreDifferentialAtEntry: 1,
                inningAtEntry: 8,
                outsAtEntry: 0,
                hits: runs,
                homeRuns: 0
            )
        }
        let clean = try engine.resolveImportantGame(.init(
            seed: "99201624",
            state: state,
            report: report(runs: 0)
        ))
        let damaged = try engine.resolveImportantGame(.init(
            seed: "99201624",
            state: state,
            report: report(runs: 3)
        ))
        let cleanLine = try XCTUnwrap(clean.snapshot.postseason?.series?.gameLines?.first)
        let damagedLine = try XCTUnwrap(damaged.snapshot.postseason?.series?.gameLines?.first)
        XCTAssertEqual(cleanLine.teamRuns, damagedLine.teamRuns)
        XCTAssertEqual(damagedLine.opponentRuns, cleanLine.opponentRuns + 3)
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

    func testChampionSettlementCanBeAcknowledged() throws {
        let engine = ProCareerEngine(journeyEnabled: true)
        let started = try engine.start(startParams(seed: "992040"))
        let accepted = try acceptRookie(engine, started)
        let reviewed = try reachSeasonReview(accepted, engine: engine)
        let history: [ProPostseasonGameLine] = [
            .init(round: .final, gameNumber: 1, teamRuns: 4, opponentRuns: 2, directlyPlayed: true, playerPitches: 15, playerOuts: 3, playerRunsAllowed: 0),
            .init(round: .final, gameNumber: 2, teamRuns: 3, opponentRuns: 1, directlyPlayed: false),
            .init(round: .final, gameNumber: 3, teamRuns: 5, opponentRuns: 4, directlyPlayed: true, playerPitches: 18, playerOuts: 3, playerRunsAllowed: 1),
        ]
        let champion = ProPostseasonState(
            seed: 1,
            currentRound: .final,
            result: .champion,
            gamesPlayed: 3,
            series: .init(
                round: .final,
                opponentTeamID: "opponent",
                playerWinsRequired: 3,
                opponentWinsRequired: 3,
                playerWins: 3,
                opponentWins: 0,
                nextGameNumber: 4,
                totalDirectAppearances: 2,
                lastAppearancePitches: 18,
                lastAppearanceGameNumber: 3,
                gameLines: history
            ),
            gameHistory: history
        )
        let ready = try unsignedSnapshot(engine, reviewed.snapshot) { object in
            object["postseason"] = try encodeValue(champion)
        }
        let settled = try engine.reviewSeason(.init(seed: reviewed.nextSeed, state: ready))
        let settlement = try XCTUnwrap(settled.snapshot.journeyState?.lastSettlement)
        XCTAssertEqual(settled.snapshot.careerStats.last?.postseasonGames, history)
        let championID = "recognition:\(ready.proCareerID):\(ready.season):award:pro.autumn.champion"
        XCTAssertTrue(settlement.newAwardIDs.contains(championID))
        XCTAssertFalse(ProTeamCareerRecordRules.isRecognizedTeamAward(
            try XCTUnwrap(settled.snapshot.journeyState?.recognitions.first { $0.id == championID })
        ))

        let acknowledged = try engine.acknowledgeSettlement(.init(
            seed: settled.nextSeed,
            state: settled.snapshot,
            expectedRevision: settled.snapshot.revision,
            settlementID: settlement.id
        ))
        XCTAssertEqual(acknowledged.snapshot.phase, .offseasonDecision)
        XCTAssertTrue(acknowledged.snapshot.journeyState?.settlementAcknowledged == true)
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

    private func reachSeasonReview(_ initial: ProCareerResult, engine: ProCareerEngine) throws -> ProCareerResult {
        var result = initial
        for _ in 0..<160 {
            switch result.snapshot.phase {
            case .weeklyPlan:
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .earnTrust))
            case .seasonDecision:
                let decision = try XCTUnwrap(result.snapshot.pendingDecision)
                let choice = try XCTUnwrap(decision.choices.first)
                result = try engine.applySeasonDecision(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    decisionID: decision.id,
                    choiceID: choice.id
                ))
            case .importantGame:
                result = try engine.resolveImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: .init(
                        scenarioNumber: result.snapshot.week,
                        pitches: 18,
                        strikeouts: 2,
                        walks: 0,
                        runsAllowed: 0,
                        expectedDamage: 400,
                        actualDamage: 200,
                        recommendationAccepted: 10
                    )
                ))
            case .seasonReview:
                return result
            default:
                throw SimulationError.invalidProCareer("fixture did not reach season review")
            }
        }
        throw SimulationError.invalidProCareer("fixture exceeded season review bound")
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
