import XCTest
@testable import SimulationCore

final class ProCareerGoalBoardTests: XCTestCase {
    func testMilestoneThresholdsStayByteIdenticalToShippedOutput() {
        XCTAssertEqual(ProCareerMilestoneRules.gameMarks, [50, 100, 300])
        XCTAssertEqual(ProCareerMilestoneRules.strikeoutMarks, [50, 100, 200, 500])
        XCTAssertEqual(ProCareerMilestoneRules.gamesLine(50), "프로 통산 50경기")
        XCTAssertEqual(ProCareerMilestoneRules.gamesLine(100), "프로 통산 100경기")
        XCTAssertEqual(ProCareerMilestoneRules.gamesLine(300), "프로 통산 300경기")
        XCTAssertEqual(ProCareerMilestoneRules.strikeoutsLine(50), "프로 통산 50탈삼진")
        XCTAssertEqual(ProCareerMilestoneRules.strikeoutsLine(100), "프로 통산 100탈삼진")
        XCTAssertEqual(ProCareerMilestoneRules.strikeoutsLine(200), "프로 통산 200탈삼진")
        XCTAssertEqual(ProCareerMilestoneRules.strikeoutsLine(500), "프로 통산 500탈삼진")
        XCTAssertEqual(ProCareerMilestoneRules.gamesContentID(50), "pro.milestone.career.games.50")
        XCTAssertEqual(ProCareerMilestoneRules.gamesContentID(300), "pro.milestone.career.games.300")
        XCTAssertEqual(ProCareerMilestoneRules.strikeoutsContentID(200), "pro.milestone.career.strikeouts.200")
        XCTAssertEqual(ProCareerMilestoneRules.strikeoutsContentID(500), "pro.milestone.career.strikeouts.500")
    }

    func testPermilleUsesIntegerTruncationAndNeverDividesByZero() {
        XCTAssertEqual(ProCareerGoalBoardRules.permille(current: 4, target: 8), 500)
        XCTAssertEqual(ProCareerGoalBoardRules.permille(current: 49, target: 50), 980)
        XCTAssertEqual(ProCareerGoalBoardRules.permille(current: 0, target: 8), 0)
        XCTAssertEqual(ProCareerGoalBoardRules.permille(current: 8, target: 8), 1000)
        XCTAssertEqual(ProCareerGoalBoardRules.permille(current: 9, target: 8), 1000)
        XCTAssertEqual(ProCareerGoalBoardRules.permille(current: 5, target: 0), 1000)
        XCTAssertEqual(ProCareerGoalBoardRules.permille(current: 0, target: 0), 0)
        XCTAssertEqual(ProCareerGoalBoardRules.permille(current: 3, target: 8, completed: true), 1000)
        XCTAssertEqual(ProCareerGoalBoardRules.permilleBand(0), "0_249")
        XCTAssertEqual(ProCareerGoalBoardRules.permilleBand(249), "0_249")
        XCTAssertEqual(ProCareerGoalBoardRules.permilleBand(250), "250_499")
        XCTAssertEqual(ProCareerGoalBoardRules.permilleBand(500), "500_749")
        XCTAssertEqual(ProCareerGoalBoardRules.permilleBand(750), "750_999")
        XCTAssertEqual(ProCareerGoalBoardRules.permilleBand(999), "750_999")
        XCTAssertEqual(ProCareerGoalBoardRules.permilleBand(1000), "1000")
    }

    func testEachKindComputesPermilleAndKeepsTargetsPositive() {
        let team = ProCareerEngine.proTeams[0]
        let state = snapshot(
            team: team,
            currentStats: ProSeasonStats(season: 1, teamID: team.id, games: 20, strikeouts: 40),
            careerStats: [],
            journey: ProCareerJourneyState(
                rulesVersion: 2,
                activeGoal: ProCareerGoalState(
                    id: "goal:franchise",
                    ambition: .franchiseIcon,
                    selectedSeason: 1,
                    anchorTeamID: team.id,
                    completedSeason: nil
                ),
                teamRecords: [
                    ProTeamCareerRecord(
                        teamID: team.id,
                        completedSeasons: 4,
                        consecutiveSeasons: 4,
                        games: 80,
                        starts: 80,
                        inningsOuts: 960,
                        strikeouts: 320,
                        wins: 20,
                        saves: 0,
                        awardCount: 0,
                        communityPoints: 0,
                        lastSeason: 4
                    ),
                ],
                reputation: ProReputationState(fanSupport: 30)
            )
        )
        let board = ProCareerGoalBoardRules.board(state: state)
        XCTAssertTrue(board.rows.allSatisfy { $0.target > 0 })
        XCTAssertEqual(Set(board.rows.map(\.kind)).isSuperset(of: [
            ProGoalBoardRowKind.ambitionMetric,
            .retiredNumber,
            .clubHall,
            .hallOfFame,
            .milestoneGames,
            .milestoneStrikeouts,
            .teamLegacyTier,
        ]), true)

        let seasons = try! XCTUnwrap(board.rows.first { $0.id == "ambition.franchise_icon.anchor_team_seasons" })
        XCTAssertEqual(seasons.current, 4)
        XCTAssertEqual(seasons.target, 8)
        XCTAssertEqual(seasons.permille, 500)
        XCTAssertFalse(seasons.completed)

        let games = try! XCTUnwrap(board.rows.first { $0.kind == .milestoneGames })
        XCTAssertEqual(games.current, 20)
        XCTAssertEqual(games.target, 50)
        XCTAssertEqual(games.permille, 400)
        XCTAssertFalse(games.completed)

        let strikeouts = try! XCTUnwrap(board.rows.first { $0.kind == .milestoneStrikeouts })
        XCTAssertEqual(strikeouts.current, 40)
        XCTAssertEqual(strikeouts.target, 50)
        XCTAssertEqual(strikeouts.permille, 800)
        XCTAssertFalse(strikeouts.completed)

        let retired = try! XCTUnwrap(board.rows.first { $0.kind == .retiredNumber })
        XCTAssertEqual(retired.subRows.count, 3)
        XCTAssertEqual(retired.permille, retired.subRows.map(\.permille).min())
        XCTAssertFalse(retired.completed)
        XCTAssertEqual(retired.hintKey, "content.goal-board.retired-number.hint")

        let club = try! XCTUnwrap(board.rows.first { $0.kind == .clubHall })
        XCTAssertEqual(club.subRows.count, 2)
        XCTAssertFalse(club.completed)

        let hof = try! XCTUnwrap(board.rows.first { $0.kind == .hallOfFame })
        XCTAssertEqual(hof.target, 70)
        XCTAssertEqual(hof.current, ProCareerEngine.hallOfFameProjection(for: state))
        XCTAssertEqual(hof.permille, ProCareerGoalBoardRules.permille(current: hof.current, target: 70))
        XCTAssertNil(state.hallOfFameScore)
    }

    func testLockedAmbitionKeepsPermilleAt1000WhenLiveScoreDips() {
        let team = ProCareerEngine.proTeams[0]
        let attendance = ProTeamCareerRecord(
            teamID: team.id,
            completedSeasons: 8,
            consecutiveSeasons: 1,
            games: 0,
            starts: 0,
            inningsOuts: 2_400,
            strikeouts: 640,
            wins: 0,
            saves: 0,
            awardCount: 0,
            communityPoints: 0,
            lastSeason: 8
        )
        XCTAssertLessThan(ProTeamLegacyRules.score(record: attendance, rulesVersion: 2), 80)
        let locked = snapshot(
            team: team,
            journey: ProCareerJourneyState(
                rulesVersion: 2,
                activeGoal: ProCareerGoalState(
                    id: "goal:franchise",
                    ambition: .franchiseIcon,
                    selectedSeason: 1,
                    anchorTeamID: team.id,
                    completedSeason: 8
                ),
                teamRecords: [attendance]
            )
        )
        let open = snapshot(
            team: team,
            journey: ProCareerJourneyState(
                rulesVersion: 2,
                activeGoal: ProCareerGoalState(
                    id: "goal:franchise",
                    ambition: .franchiseIcon,
                    selectedSeason: 1,
                    anchorTeamID: team.id,
                    completedSeason: nil
                ),
                teamRecords: [attendance]
            )
        )
        let lockedBoard = ProCareerGoalBoardRules.board(state: locked)
        let openBoard = ProCareerGoalBoardRules.board(state: open)
        let lockedLegacy = try! XCTUnwrap(lockedBoard.rows.first { $0.id == "ambition.franchise_icon.anchor_team_legacy" })
        let openLegacy = try! XCTUnwrap(openBoard.rows.first { $0.id == "ambition.franchise_icon.anchor_team_legacy" })
        XCTAssertLessThan(lockedLegacy.current, lockedLegacy.target)
        XCTAssertTrue(lockedLegacy.completed)
        XCTAssertEqual(lockedLegacy.permille, 1000)
        XCTAssertFalse(openLegacy.completed)
        XCTAssertLessThan(openLegacy.permille, 1000)
        XCTAssertTrue(ProCareerGoalRules.settlementMetricsAreConsistent(
            ProCareerGoalRules.progress(state: locked, goal: locked.journeyState!.activeGoal!),
            allowingLockedDip: true
        ))
    }

    func testRetiredNumberUsesLastTeamAndResetsAfterTransfer() {
        let first = ProCareerEngine.proTeams[0]
        let second = ProCareerEngine.proTeams[1]
        let longStay = ProTeamCareerRecord(
            teamID: first.id,
            completedSeasons: 8,
            consecutiveSeasons: 8,
            games: 240,
            starts: 240,
            inningsOuts: 3_888,
            strikeouts: 1_440,
            wins: 80,
            saves: 0,
            awardCount: 3,
            communityPoints: 20,
            lastSeason: 8
        )
        let eligible = snapshot(
            team: first,
            journey: ProCareerJourneyState(
                rulesVersion: 2,
                teamRecords: [longStay],
                reputation: ProReputationState(fanSupport: 60)
            )
        )
        let preview = ProRetirementRules.preview(for: eligible)
        let eligibleBoard = ProCareerGoalBoardRules.board(state: eligible)
        let retired = try! XCTUnwrap(eligibleBoard.rows.first { $0.kind == .retiredNumber })
        XCTAssertEqual(preview.retiredNumberEligible, retired.completed)
        XCTAssertEqual(retired.subRows.map(\.id), [
            "retiredNumber.seasons",
            "retiredNumber.legacy",
            "retiredNumber.fan",
        ])
        if preview.retiredNumberEligible {
            XCTAssertEqual(retired.permille, 1000)
            XCTAssertTrue(retired.subRows.allSatisfy(\.completed))
        }

        let transferred = snapshot(
            team: second,
            journey: ProCareerJourneyState(
                rulesVersion: 2,
                teamRecords: [
                    longStay,
                    ProTeamCareerRecord(
                        teamID: second.id,
                        completedSeasons: 1,
                        consecutiveSeasons: 1,
                        games: 20,
                        starts: 20,
                        inningsOuts: 180,
                        strikeouts: 40,
                        wins: 4,
                        saves: 0,
                        awardCount: 0,
                        communityPoints: 0,
                        lastSeason: 9
                    ),
                ],
                reputation: ProReputationState(fanSupport: 60)
            )
        )
        let afterTransfer = ProRetirementRules.preview(for: transferred)
        XCTAssertEqual(afterTransfer.lastTeamID, second.id)
        XCTAssertEqual(afterTransfer.lastTeamSeasons, 1)
        let transferredRow = try! XCTUnwrap(
            ProCareerGoalBoardRules.board(state: transferred).rows.first { $0.kind == .retiredNumber }
        )
        XCTAssertFalse(transferredRow.completed)
        XCTAssertEqual(transferredRow.subRows.first { $0.id == "retiredNumber.seasons" }?.current, 1)
        XCTAssertEqual(transferredRow.permille, transferredRow.subRows.map(\.permille).min())
        XCTAssertLessThan(transferredRow.permille, 1000)
        XCTAssertEqual(transferredRow.hintKey, "content.goal-board.retired-number.hint")

        let club = try! XCTUnwrap(
            ProCareerGoalBoardRules.board(state: transferred).rows.first { $0.kind == .clubHall }
        )
        if afterTransfer.retiredNumberEligible {
            XCTAssertFalse(afterTransfer.clubHallTeamIDs.contains(second.id))
        }
        XCTAssertEqual(club.subRows.count, 2)
    }

    func testHallOfFameUsesFinalScoreAfterRetirement() {
        let team = ProCareerEngine.proTeams[0]
        let live = snapshot(team: team, hallOfFameScore: nil)
        let retired = snapshot(team: team, phase: .completed, hallOfFameScore: 81)
        let liveRow = try! XCTUnwrap(
            ProCareerGoalBoardRules.board(state: live).rows.first { $0.kind == .hallOfFame }
        )
        let retiredRow = try! XCTUnwrap(
            ProCareerGoalBoardRules.board(state: retired).rows.first { $0.kind == .hallOfFame }
        )
        XCTAssertEqual(liveRow.current, ProCareerEngine.hallOfFameProjection(for: live))
        XCTAssertEqual(retiredRow.current, 81)
        XCTAssertEqual(retiredRow.target, 70)
        XCTAssertTrue(retiredRow.completed)
        XCTAssertEqual(retiredRow.permille, 1000)
    }

    func testMilestoneNextThresholdAndCompletion() {
        let team = ProCareerEngine.proTeams[0]
        let mid = snapshot(
            team: team,
            currentStats: ProSeasonStats(season: 3, teamID: team.id, games: 10, strikeouts: 20),
            careerStats: [
                ProSeasonStats(season: 1, teamID: team.id, games: 40, strikeouts: 80),
                ProSeasonStats(season: 2, teamID: team.id, games: 50, strikeouts: 100),
            ]
        )
        let board = ProCareerGoalBoardRules.board(state: mid)
        let games = try! XCTUnwrap(board.rows.first { $0.kind == .milestoneGames })
        XCTAssertEqual(games.current, 100)
        XCTAssertEqual(games.target, 300)
        XCTAssertEqual(games.permille, 333)
        XCTAssertFalse(games.completed)

        let punchouts = try! XCTUnwrap(board.rows.first { $0.kind == .milestoneStrikeouts })
        XCTAssertEqual(punchouts.current, 200)
        XCTAssertEqual(punchouts.target, 500)
        XCTAssertEqual(punchouts.permille, 400)
        XCTAssertFalse(punchouts.completed)

        let done = snapshot(
            team: team,
            currentStats: ProSeasonStats(season: 12, teamID: team.id, games: 0, strikeouts: 0),
            careerStats: [ProSeasonStats(season: 1, teamID: team.id, games: 300, strikeouts: 500)]
        )
        let finished = ProCareerGoalBoardRules.board(state: done)
        let finishedGames = try! XCTUnwrap(finished.rows.first { $0.kind == .milestoneGames })
        XCTAssertEqual(finishedGames.current, 300)
        XCTAssertEqual(finishedGames.target, 300)
        XCTAssertTrue(finishedGames.completed)
        XCTAssertEqual(finishedGames.permille, 1000)
        let finishedK = try! XCTUnwrap(finished.rows.first { $0.kind == .milestoneStrikeouts })
        XCTAssertTrue(finishedK.completed)
        XCTAssertEqual(finishedK.target, 500)
    }

    func testTeamLegacyUsesRecordRulesVersionAndNextTierScore() throws {
        let team = ProCareerEngine.proTeams[0]
        let record = ProTeamCareerRecord(
            teamID: team.id,
            completedSeasons: 2,
            consecutiveSeasons: 2,
            games: 40,
            starts: 40,
            inningsOuts: 360,
            strikeouts: 120,
            wins: 10,
            saves: 0,
            awardCount: 0,
            communityPoints: 0,
            lastSeason: 2
        )
        let state = snapshot(
            team: team,
            journey: ProCareerJourneyState(rulesVersion: 2, teamRecords: [record])
        )
        let score = ProTeamLegacyRules.score(record: record, rulesVersion: 2)
        let next = try XCTUnwrap(ProTeamLegacyRules.nextTierProjection(record: record, rulesVersion: 2))
        let row = try XCTUnwrap(
            ProCareerGoalBoardRules.board(state: state).rows.first { $0.kind == .teamLegacyTier }
        )
        XCTAssertEqual(row.current, score)
        XCTAssertEqual(row.target, next.minimumScore)
        XCTAssertFalse(row.completed)
        XCTAssertGreaterThan(row.target, 0)
    }

    func testIncompleteRowsSortByPermilleThenCompletedLastAndNearestIsFirstIncomplete() {
        let team = ProCareerEngine.proTeams[0]
        let state = snapshot(
            team: team,
            currentStats: ProSeasonStats(season: 1, teamID: team.id, games: 49, strikeouts: 49),
            hallOfFameScore: 70,
            journey: ProCareerJourneyState(
                rulesVersion: 2,
                reputation: ProReputationState(fanSupport: 0)
            )
        )
        let board = ProCareerGoalBoardRules.board(state: state)
        XCTAssertTrue(board.rows.allSatisfy { $0.target > 0 })
        let incomplete = board.rows.filter { !$0.completed }
        let completed = board.rows.filter(\.completed)
        XCTAssertEqual(incomplete.map(\.permille), incomplete.map(\.permille).sorted(by: >))
        XCTAssertTrue(board.rows.suffix(completed.count).allSatisfy(\.completed))
        XCTAssertEqual(board.nearest?.id, incomplete.first?.id)
        XCTAssertFalse(board.nearest?.completed ?? true)
        let hof = try! XCTUnwrap(board.rows.first { $0.kind == .hallOfFame })
        XCTAssertTrue(hof.completed)
        XCTAssertTrue(completed.contains { $0.kind == .hallOfFame })
    }

    func testContentKeysAreStableSemanticIDs() {
        XCTAssertFalse(ProCareerGoalBoardRules.contentKeys.isEmpty)
        XCTAssertEqual(Set(ProCareerGoalBoardRules.contentKeys).count, ProCareerGoalBoardRules.contentKeys.count)
        for key in ProCareerGoalBoardRules.contentKeys {
            XCTAssertTrue(key.hasPrefix("content.goal-board."))
            XCTAssertTrue(key.hasSuffix(".title") || key.hasSuffix(".hint"))
            XCTAssertFalse(key.contains(" "))
            XCTAssertEqual(key, key.lowercased())
        }
    }

    private func snapshot(
        team: DraftTeamSnapshot,
        phase: ProCareerPhase = .weeklyPlan,
        currentStats: ProSeasonStats? = nil,
        careerStats: [ProSeasonStats] = [],
        hallOfFameScore: Int? = nil,
        journey: ProCareerJourneyState? = nil
    ) -> ProCareerSnapshot {
        ProCareerSnapshot(
            proCareerID: "pro-goal-board",
            revision: 1,
            phase: phase,
            identity: .defaultPitcher,
            pitcher: PitcherSnapshot(id: "p", name: "P", stuff: 50, command: 50, movement: 50, stamina: 50),
            team: team,
            entitlement: .init(status: .active, source: .development, verifiedAt: "2026-09-02"),
            age: 24,
            season: 4,
            week: 8,
            level: .major,
            role: .starter,
            managerTrust: 50,
            catcherTrust: 50,
            fatigue: 0,
            injuryWeeks: 0,
            serviceYears: 3,
            militaryCompleted: false,
            contract: nil,
            currentStats: currentStats ?? ProSeasonStats(season: 4, teamID: team.id),
            careerStats: careerStats,
            awards: [],
            milestones: [],
            news: [],
            hallOfFameScore: hallOfFameScore,
            commitment: "",
            balanceVersion: 4,
            proRulesVersion: 9,
            journeyState: journey
        )
    }
}
