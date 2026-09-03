import XCTest
@testable import SimulationCore

final class SabermetricsRulesTests: XCTestCase {
    private let constants = SabermetricsRules.LeagueConstants.v1

    func testKnown200InningSeasonLocksFIPAndWARIntegers() {
        let stats = ProSeasonStats(
            season: 3,
            teamID: "daegu-forge",
            games: 32,
            starts: 32,
            inningsOuts: 600,
            strikeouts: 200,
            walks: 50,
            runsAllowed: 80,
            hits: 180,
            homeRuns: 15,
            pitches: 3_200,
            wins: 14,
            losses: 8,
            saves: 0
        )
        let line = SabermetricsRules.season(stats)

        XCTAssertEqual(line.plateAppearances, 830)
        XCTAssertEqual(line.k9Centi, 900)
        XCTAssertEqual(line.bb9Centi, 225)
        XCTAssertEqual(line.hr9Centi, 68)
        XCTAssertEqual(line.kPermille, 241)
        XCTAssertEqual(line.bbPermille, 60)
        XCTAssertEqual(line.kMinusBBPermille, 181)
        XCTAssertEqual(line.whipCenti, 115)
        XCTAssertEqual(line.ra9Centi, 360)
        XCTAssertEqual(line.fipCenti, 305)
        XCTAssertEqual(line.ra9Plus, 96)
        XCTAssertEqual(line.fipMinus, 88)
        XCTAssertEqual(line.warCenti, 365)
        XCTAssertEqual(line.inningsText, "200")
        XCTAssertEqual(line.ra9Text, "3.60")
        XCTAssertEqual(line.fipText, "3.05")
        XCTAssertEqual(line.kPercentText, "24.1%")
        XCTAssertEqual(line.bbPercentText, "6.0%")
        XCTAssertEqual(line.whipText, "1.15")
        XCTAssertEqual(line.warText, "3.7")
        XCTAssertEqual(line.ra9Tone, .worse)
        XCTAssertEqual(line.fipTone, .better)
        XCTAssertEqual(line.kPercentTone, .better)
        XCTAssertEqual(line.bbPercentTone, .worse)
        XCTAssertEqual(line.whipTone, .better)
        XCTAssertEqual(line.warTone, .better)
        XCTAssertLessThanOrEqual(stats.strikeouts, line.plateAppearances)
    }

    func testZeroInningsAndZeroPAReturnDashesAndZeroWAR() {
        let empty = ProSeasonStats(season: 1, teamID: "daegu-forge")
        let line = SabermetricsRules.season(empty)
        XCTAssertEqual(line.inningsOuts, 0)
        XCTAssertEqual(line.plateAppearances, 0)
        XCTAssertNil(line.ra9Centi)
        XCTAssertNil(line.fipCenti)
        XCTAssertNil(line.kPermille)
        XCTAssertNil(line.whipCenti)
        XCTAssertEqual(line.warCenti, 0)
        XCTAssertEqual(line.ra9Text, "—")
        XCTAssertEqual(line.fipText, "—")
        XCTAssertEqual(line.kPercentText, "—")
        XCTAssertEqual(line.warText, "0.0")
        XCTAssertEqual(line.ra9Tone, .even)
        XCTAssertEqual(line.warTone, .even)
    }

    func testIntegerRoundingIsDeterministicAndHalfAwayFromZero() {
        XCTAssertEqual(SabermetricsRules.divRound(5, 2), 3)
        XCTAssertEqual(SabermetricsRules.divRound(-5, 2), -3)
        XCTAssertEqual(SabermetricsRules.divRound(4, 2), 2)
        XCTAssertEqual(SabermetricsRules.divRound(0, 2), 0)
        XCTAssertEqual(SabermetricsRules.divRound(7, 0), 0)
        let stats = ProSeasonStats(
            season: 1,
            teamID: "daegu-forge",
            games: 32,
            starts: 32,
            inningsOuts: 600,
            strikeouts: 200,
            walks: 50,
            runsAllowed: 80,
            hits: 180,
            homeRuns: 15
        )
        let first = SabermetricsRules.season(stats)
        for _ in 0..<1_000 {
            XCTAssertEqual(SabermetricsRules.season(stats), first)
        }
    }

    func testQualityStartCompleteGameAndInningsTextUseGameLines() {
        let stats = ProSeasonStats(
            season: 1,
            teamID: "daegu-forge",
            games: 3,
            starts: 3,
            inningsOuts: 62,
            strikeouts: 15,
            walks: 4,
            runsAllowed: 5,
            hits: 18,
            homeRuns: 1,
            pitches: 280
        )
        let lines = [
            ProGameLine(
                season: 1, week: 1, outingNumber: 1, started: true,
                outs: 18, strikeouts: 6, walks: 1, runsAllowed: 3, pitches: 95,
                teamRuns: 4, opponentRuns: 3, decision: .win, played: true,
                hits: 6, homeRuns: 1
            ),
            ProGameLine(
                season: 1, week: 2, outingNumber: 2, started: true,
                outs: 27, strikeouts: 7, walks: 1, runsAllowed: 0, pitches: 108,
                teamRuns: 2, opponentRuns: 0, decision: .win, played: true,
                hits: 4, homeRuns: 0
            ),
            ProGameLine(
                season: 1, week: 3, outingNumber: 3, started: true,
                outs: 17, strikeouts: 2, walks: 2, runsAllowed: 2, pitches: 77,
                teamRuns: 1, opponentRuns: 2, decision: .noDecision, played: true,
                hits: 8, homeRuns: 0
            ),
        ]
        let line = SabermetricsRules.season(stats, lines: lines)
        XCTAssertEqual(line.qualityStarts, 2)
        XCTAssertEqual(line.qualityStartPermille, 667)
        XCTAssertEqual(line.completeGames, 1)
        XCTAssertEqual(line.shutouts, 1)
        XCTAssertEqual(PitchingMetrics.inningsText(outs: 17), "5.2")
        XCTAssertEqual(line.inningsText, "20.2")
    }

    func testCareerWARIsTheSumOfSeasonWARNotARecompute() {
        let seasonA = ProSeasonStats(
            season: 1,
            teamID: "daegu-forge",
            games: 32,
            starts: 32,
            inningsOuts: 600,
            strikeouts: 200,
            walks: 50,
            runsAllowed: 80,
            hits: 180,
            homeRuns: 15
        )
        let seasonB = ProSeasonStats(
            season: 2,
            teamID: "daegu-forge",
            games: 32,
            starts: 32,
            inningsOuts: 600,
            strikeouts: 200,
            walks: 50,
            runsAllowed: 80,
            hits: 180,
            homeRuns: 15
        )
        let board = SabermetricsRules.board(completed: [seasonA, seasonB], current: nil)
        XCTAssertEqual(board.rows.map(\.warCenti), [365, 365])
        XCTAssertEqual(board.career.warCenti, 730)
        XCTAssertEqual(board.career.warText, "7.3")
        XCTAssertEqual(board.career.inningsOuts, 1_200)
        XCTAssertNil(board.career.season)
        let recomputed = SabermetricsRules.season(
            ProSeasonStats(
                season: 0,
                teamID: "",
                games: 64,
                starts: 64,
                inningsOuts: 1_200,
                strikeouts: 400,
                walks: 100,
                runsAllowed: 160,
                hits: 360,
                homeRuns: 30
            )
        )
        XCTAssertEqual(recomputed.warCenti, 731)
        XCTAssertNotEqual(board.career.warCenti, recomputed.warCenti)
    }

    func testCurrentSeasonJoinsBoardAndPostseasonStatsAreIgnored() {
        let completed = ProSeasonStats(
            season: 1,
            teamID: "daegu-forge",
            games: 10,
            starts: 10,
            inningsOuts: 180,
            strikeouts: 40,
            walks: 12,
            runsAllowed: 20,
            hits: 50,
            homeRuns: 4,
            postseasonGames: [
                ProPostseasonGameLine(
                    round: .wildCard,
                    gameNumber: 1,
                    teamRuns: 3,
                    opponentRuns: 1,
                    directlyPlayed: true,
                    playerPitches: 90,
                    playerOuts: 18,
                    playerRunsAllowed: 1,
                    playerStrikeouts: 8,
                    playerWalks: 1,
                    playerHits: 4,
                    playerStarted: true
                )
            ]
        )
        let current = ProSeasonStats(
            season: 2,
            teamID: "daegu-forge",
            games: 8,
            starts: 8,
            inningsOuts: 120,
            strikeouts: 30,
            walks: 8,
            runsAllowed: 16,
            hits: 40,
            homeRuns: 3
        )
        let board = SabermetricsRules.board(completed: [completed], current: current)
        XCTAssertEqual(board.rows.map(\.season), [1, 2])
        XCTAssertEqual(board.career.inningsOuts, 300)
        XCTAssertEqual(board.career.warCenti, board.rows[0].warCenti + board.rows[1].warCenti)
        XCTAssertEqual(completed.postseasonGames?.first?.playerOuts, 18)
        XCTAssertNotEqual(board.career.inningsOuts, 318)
    }

    func testLeagueAverageRatesKeepFIPWithinPointThreeOfRA9() throws {
        let outs = 2_700
        let stats = ProSeasonStats(
            season: 1,
            teamID: "league",
            games: 32,
            starts: 32,
            inningsOuts: outs,
            strikeouts: constants.k9Centi,
            walks: constants.bb9Centi,
            runsAllowed: constants.ra9Centi,
            hits: constants.h9Centi,
            homeRuns: constants.hr9Centi
        )
        let line = SabermetricsRules.season(stats)
        let fip = try XCTUnwrap(line.fipCenti)
        let ra9 = try XCTUnwrap(line.ra9Centi)
        XCTAssertEqual(ra9, constants.ra9Centi)
        XCTAssertLessThanOrEqual(abs(fip - ra9), 30)
        XCTAssertEqual(line.warCenti, 1_200)
        XCTAssertEqual(line.warText, "12.0")
    }

    func testCloserLeverageAndReplacementStayInsideReliefBand() {
        let stats = ProSeasonStats(
            season: 4,
            teamID: "daegu-forge",
            games: 65,
            starts: 0,
            inningsOuts: 210,
            strikeouts: 60,
            walks: 15,
            runsAllowed: 25,
            hits: 60,
            homeRuns: 6,
            saves: 20
        )
        let line = SabermetricsRules.season(stats)
        XCTAssertGreaterThanOrEqual(line.warCenti, -50)
        XCTAssertLessThanOrEqual(line.warCenti, 250)
        let asMiddle = ProSeasonStats(
            season: 4,
            teamID: "daegu-forge",
            games: 65,
            starts: 0,
            inningsOuts: 210,
            strikeouts: 60,
            walks: 15,
            runsAllowed: 25,
            hits: 60,
            homeRuns: 6,
            saves: 4
        )
        XCTAssertGreaterThan(line.warCenti, SabermetricsRules.season(asMiddle).warCenti)
    }

    func testScoringRulesDoNotImportDisplayWAR() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/SimulationCore")
        let files = [
            "ProCareer.swift",
            "ProCareer+Journey.swift",
            "ProContractMarketRules.swift",
            "ProCareerGoalBoardRules.swift",
            "ProCareerGoalBoardRules.swift",
        ]
        for name in files {
            let text = try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
            XCTAssertFalse(text.contains("SabermetricsRules"), name)
            XCTAssertFalse(text.contains("SaberMetrics"), name)
            XCTAssertFalse(text.contains("warCenti"), name)
        }
    }
}


