import XCTest
@testable import SimulationCore

final class ProCareerRetiredNumberBalanceTests: XCTestCase {
    private let engine = ProCareerEngine(journeyEnabled: true)

    func testNewCareerUsesJourneyRulesVersion2AndProRulesVersion4() throws {
        let started = try engine.start(startParams(seed: "820001"))
        XCTAssertEqual(started.snapshot.journeyState?.rulesVersion, 2)
        XCTAssertEqual(started.snapshot.proRulesVersion, 7)
        XCTAssertEqual(ProCareerEngine.currentJourneyRulesVersion, 2)
        XCTAssertEqual(ProCareerEngine.currentRulesVersion, 7)
        XCTAssertTrue(ProCareerEngine.usesAgencyRules(started.snapshot))
        XCTAssertTrue(ProCareerEngine.usesRetiredNumberLiveRules(started.snapshot))
    }

    func testLegacyMigrationKeepsJourneyRulesVersion1() throws {
        let legacyEngine = ProCareerEngine(journeyEnabled: true)
        var result = try legacyEngine.start(startParams(seed: "820002"))
        result = try acceptRookie(result)
        let migrated = try unsignedSnapshot(result.snapshot) { object in
            object["journeyState"] = NSNull()
            object["phase"] = ProCareerPhase.seasonReview.rawValue
        }
        let restored = try legacyEngine.reviewSeason(.init(seed: result.nextSeed, state: migrated))
        XCTAssertEqual(restored.snapshot.journeyState?.rulesVersion, 1)
        XCTAssertEqual(restored.snapshot.journeyState?.migration.source, .legacySafeBoundary)
    }

    func testOffseasonDoesNotRaiseJourneyRulesVersion() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "820003")))
        let offseason = try unsignedSnapshot(accepted.snapshot) { object in
            object["phase"] = ProCareerPhase.offseasonDecision.rawValue
            var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
            journey["rulesVersion"] = 1
            journey["settlementAcknowledged"] = true
            object["journeyState"] = journey
        }
        XCTAssertEqual(offseason.journeyState?.rulesVersion, 1)
        let advanced = try engine.chooseOffseason(.init(
            seed: "820003-off",
            state: offseason,
            decision: .continueCareer,
            expectedRevision: offseason.revision
        ))
        XCTAssertEqual(advanced.snapshot.journeyState?.rulesVersion, 1)
        XCTAssertNotEqual(advanced.snapshot.journeyState?.rulesVersion, 2)
    }

    func testV1LegacyScoreAndHonorThresholdsStayFrozen() {
        let record = ProTeamCareerRecord(
            teamID: "team",
            completedSeasons: 8,
            consecutiveSeasons: 8,
            games: 0,
            starts: 0,
            inningsOuts: 3_000,
            strikeouts: 4_000,
            wins: 0,
            saves: 0,
            awardCount: 20,
            communityPoints: 20,
            lastSeason: 8
        )
        XCTAssertEqual(ProTeamLegacyRules.score(record: record), 100)
        XCTAssertEqual(ProTeamLegacyRules.score(record: record, rulesVersion: 1), 100)
        let lastTeamAt80 = ProTeamCareerRecord(
            teamID: "team",
            completedSeasons: 8,
            consecutiveSeasons: 8,
            games: 0,
            starts: 0,
            inningsOuts: 0,
            strikeouts: 1_000,
            wins: 0,
            saves: 0,
            awardCount: 0,
            communityPoints: 7,
            lastSeason: 8
        )
        XCTAssertEqual(ProTeamLegacyRules.score(record: lastTeamAt80, rulesVersion: 1), 80)
        XCTAssertNotEqual(ProTeamLegacyRules.score(record: lastTeamAt80, rulesVersion: 2), 80)

        let ids = Set(ProCareerRecognitionRules.awardContentIDs(
            stats: .init(season: 1, teamID: "team", inningsOuts: 1, strikeouts: 120),
            rulesVersion: 1
        ))
        XCTAssertTrue(ids.contains("pro.award.strikeouts"))
        XCTAssertFalse(ProCareerRecognitionRules.awardContentIDs(
            stats: .init(season: 1, teamID: "team", inningsOuts: 1, strikeouts: 120),
            rulesVersion: 2
        ).contains("pro.award.strikeouts"))
    }

    func testV2LegacyScoreWorkedExamples() {
        func record(seasons: Int, strikeouts: Int, outs: Int, awards: Int, community: Int = 0) -> ProTeamCareerRecord {
            .init(
                teamID: "team",
                completedSeasons: seasons,
                consecutiveSeasons: seasons,
                games: 0,
                starts: 0,
                inningsOuts: outs,
                strikeouts: strikeouts,
                wins: 0,
                saves: 0,
                awardCount: awards,
                communityPoints: community,
                lastSeason: seasons
            )
        }
        XCTAssertEqual(ProTeamLegacyRules.score(record: record(seasons: 8, strikeouts: 640, outs: 2_400, awards: 0), rulesVersion: 2), 52)
        XCTAssertEqual(ProTeamLegacyRules.score(record: record(seasons: 8, strikeouts: 640, outs: 2_400, awards: 1), rulesVersion: 2), 57)
        XCTAssertEqual(ProTeamLegacyRules.score(record: record(seasons: 8, strikeouts: 1_000, outs: 3_000, awards: 2), rulesVersion: 2), 74)
        XCTAssertEqual(ProTeamLegacyRules.score(record: record(seasons: 8, strikeouts: 1_200, outs: 3_600, awards: 3), rulesVersion: 2), 87)
        XCTAssertEqual(ProTeamLegacyRules.score(record: record(seasons: 8, strikeouts: 1_600, outs: 4_320, awards: 4), rulesVersion: 2), 92)
        XCTAssertEqual(ProTeamLegacyRules.score(record: record(seasons: 6, strikeouts: 480, outs: 1_800, awards: 0), rulesVersion: 2), 39)
        XCTAssertEqual(ProTeamLegacyRules.score(record: record(seasons: 6, strikeouts: 900, outs: 2_700, awards: 2), rulesVersion: 2), 63)
        XCTAssertEqual(ProTeamLegacyRules.tier(record: record(seasons: 8, strikeouts: 640, outs: 2_400, awards: 0), rulesVersion: 2), .clubAce)
        XCTAssertEqual(ProTeamLegacyRules.tier(record: record(seasons: 8, strikeouts: 1_200, outs: 3_600, awards: 3), rulesVersion: 2), .retiredNumberCandidate)
    }

    func testV2HonorThresholdsAreExact() {
        func ids(_ stats: ProSeasonStats) -> Set<String> {
            Set(ProCareerRecognitionRules.awardContentIDs(stats: stats, rulesVersion: 2))
        }
        XCTAssertFalse(ids(.init(season: 1, teamID: "t", inningsOuts: 1, strikeouts: 179)).contains("pro.award.strikeouts"))
        XCTAssertTrue(ids(.init(season: 1, teamID: "t", inningsOuts: 1, strikeouts: 180)).contains("pro.award.strikeouts"))
        XCTAssertFalse(ids(.init(season: 1, teamID: "t", games: 20, inningsOuts: 359, runsAllowed: 35)).contains("pro.award.run-prevention"))
        XCTAssertFalse(ids(.init(season: 1, teamID: "t", games: 20, inningsOuts: 360, runsAllowed: 36)).contains("pro.award.run-prevention"))
        XCTAssertTrue(ids(.init(season: 1, teamID: "t", games: 20, inningsOuts: 360, runsAllowed: 35)).contains("pro.award.run-prevention"))
        XCTAssertFalse(ids(.init(season: 1, teamID: "t", inningsOuts: 359, walks: 20)).contains("pro.award.command"))
        XCTAssertFalse(ids(.init(season: 1, teamID: "t", inningsOuts: 360, walks: 24)).contains("pro.award.command"))
        XCTAssertTrue(ids(.init(season: 1, teamID: "t", inningsOuts: 360, walks: 23)).contains("pro.award.command"))
        XCTAssertFalse(ids(.init(season: 1, teamID: "t", inningsOuts: 360, hits: 100)).contains("pro.award.hits"))
        XCTAssertTrue(ids(.init(season: 1, teamID: "t", inningsOuts: 360, hits: 99)).contains("pro.award.hits"))
        XCTAssertFalse(ids(.init(season: 1, teamID: "t", inningsOuts: 485)).contains("pro.award.innings"))
        XCTAssertTrue(ids(.init(season: 1, teamID: "t", inningsOuts: 486)).contains("pro.award.innings"))
    }

    func testPreviewUsesJourneyRulesVersionAndFanBoundary() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "820010")))
        let face = ProTeamCareerRecord(
            teamID: accepted.snapshot.team.id,
            completedSeasons: 8,
            consecutiveSeasons: 8,
            games: 0,
            starts: 0,
            inningsOuts: 3_600,
            strikeouts: 1_200,
            wins: 0,
            saves: 0,
            awardCount: 3,
            communityPoints: 0,
            lastSeason: 8
        )
        XCTAssertEqual(ProTeamLegacyRules.score(record: face, rulesVersion: 2), 87)

        func preview(record: ProTeamCareerRecord, fan: Int, rulesVersion: Int) throws -> ProRetirementPreview {
            let state = try unsignedSnapshot(accepted.snapshot) { object in
                var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
                journey["rulesVersion"] = rulesVersion
                journey["teamRecords"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode([record]))
                var reputation = try XCTUnwrap(journey["reputation"] as? [String: Any])
                reputation["fanSupport"] = fan
                journey["reputation"] = reputation
                object["journeyState"] = journey
            }
            return ProCareerEngine.retirementPreview(for: state)
        }

        XCTAssertFalse(try preview(record: face, fan: 59, rulesVersion: 2).retiredNumberEligible)
        let eligible = try preview(record: face, fan: 60, rulesVersion: 2)
        XCTAssertTrue(eligible.retiredNumberEligible)
        XCTAssertTrue(eligible.honors.contains { $0.kind == .retiredNumber && $0.teamID == accepted.snapshot.team.id })
        XCTAssertEqual(eligible.honors.filter { $0.kind == .retiredNumber }.count, ProRetirementRules.honors(for: try unsignedSnapshot(accepted.snapshot) { object in
            var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
            journey["rulesVersion"] = 2
            journey["teamRecords"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode([face]))
            var reputation = try XCTUnwrap(journey["reputation"] as? [String: Any])
            reputation["fanSupport"] = 60
            journey["reputation"] = reputation
            object["journeyState"] = journey
        }).filter { $0.kind == .retiredNumber }.count)

        let attendance = ProTeamCareerRecord(
            teamID: accepted.snapshot.team.id,
            completedSeasons: 8,
            consecutiveSeasons: 8,
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
        XCTAssertFalse(try preview(record: attendance, fan: 60, rulesVersion: 2).retiredNumberEligible)
        XCTAssertEqual(try preview(record: attendance, fan: 60, rulesVersion: 2).lastTeamLegacy, 52)
    }

    func testAgencyRulesStayOnForVersion3Saves() {
        let acceptedPitcher = PitcherSnapshot(id: "p", name: "P", stuff: 50, command: 50, movement: 50, stamina: 50)
        let v3 = ProCareerSnapshot(
            proCareerID: "pro-v3",
            revision: 1,
            phase: .weeklyPlan,
            identity: .defaultPitcher,
            pitcher: acceptedPitcher,
            team: ProCareerEngine.proTeams[0],
            entitlement: .init(status: .active, source: .development, verifiedAt: "2026-08-20"),
            age: 19,
            season: 1,
            week: 0,
            level: .minor,
            role: .starter,
            managerTrust: 50,
            catcherTrust: 50,
            fatigue: 0,
            injuryWeeks: 0,
            serviceYears: 0,
            militaryCompleted: false,
            contract: nil,
            currentStats: ProSeasonStats(season: 1, teamID: ProCareerEngine.proTeams[0].id),
            careerStats: [],
            awards: [],
            milestones: [],
            news: [],
            hallOfFameScore: nil,
            commitment: "",
            balanceVersion: 4,
            proRulesVersion: 3
        )
        XCTAssertTrue(ProCareerEngine.usesAgencyRules(v3))
        XCTAssertFalse(ProCareerEngine.usesRetiredNumberLiveRules(v3))
    }

    func testWeeklyOutingOffsetChangesLineAgainstSameSeed() {
        let pitcher = PitcherPresetCatalog.all[0].pitcher
        var offset0Runs = 0
        var offset8Runs = 0
        for seed in 1...24 {
            let zero = engine.simulateWeeklyOuting(
                pitcher: pitcher,
                startingFatigue: 5,
                outsTarget: 18,
                pitchCap: 96,
                batterOffset: 0,
                baseSeed: UInt64(seed) &* 0x9E3779B97F4A7C15
            )
            let eight = engine.simulateWeeklyOuting(
                pitcher: pitcher,
                startingFatigue: 5,
                outsTarget: 18,
                pitchCap: 96,
                batterOffset: 8,
                baseSeed: UInt64(seed) &* 0x9E3779B97F4A7C15
            )
            offset0Runs += zero.runsAllowed
            offset8Runs += eight.runsAllowed
        }
        XCTAssertGreaterThan(offset8Runs, offset0Runs)
        XCTAssertEqual(DifficultyScale.pro(season: 1), 0)
        XCTAssertEqual(DifficultyScale.pro(season: 9), 8)
    }

    func testDevelopmentTicksRequiredBands() {
        XCTAssertEqual(ProCareerEngine.developmentTicksRequired(for: 54), 2)
        XCTAssertEqual(ProCareerEngine.developmentTicksRequired(for: 55), 3)
        XCTAssertEqual(ProCareerEngine.developmentTicksRequired(for: 64), 3)
        XCTAssertEqual(ProCareerEngine.developmentTicksRequired(for: 65), 4)
        XCTAssertEqual(ProCareerEngine.developmentTicksRequired(for: 72), 4)
        XCTAssertEqual(ProCareerEngine.developmentTicksRequired(for: 73), 6)
        XCTAssertEqual(ProCareerEngine.developmentTicksRequired(for: 80), 6)
    }

    func testHighAbilityNeedsSixWeeksBeforeGrowing() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "820020", stuff: 73)))
        var current = try unsignedSnapshot(accepted.snapshot) { object in
            object["phase"] = ProCareerPhase.weeklyPlan.rawValue
            object["week"] = 0
            object["proRulesVersion"] = 4
            object["seasonImportantGames"] = 3
            object["developmentProgress"] = try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(ProDevelopmentProgress())
            )
        }
        let startStuff = current.pitcher.stuff
        for week in 1...5 {
            let planned = try engine.planWeek(.init(seed: String(8_200_200 + week), state: current, plan: .developStuff))
            XCTAssertEqual(planned.snapshot.pitcher.stuff, startStuff, "week \(week) must not grow yet")
            current = planned.snapshot
        }
        let sixth = try engine.planWeek(.init(seed: "8200206", state: current, plan: .developStuff))
        XCTAssertEqual(sixth.snapshot.pitcher.stuff, startStuff + 1)
    }

    func testCompletedGoalStaysCompleteAfterAnchorScoreWouldDrop() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "820030")))
        let attendance = ProTeamCareerRecord(
            teamID: accepted.snapshot.team.id,
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
        let state = try unsignedSnapshot(accepted.snapshot) { object in
            var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
            journey["rulesVersion"] = 2
            journey["teamRecords"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode([attendance]))
            object["journeyState"] = journey
        }
        let open = ProCareerGoalState(
            id: "goal:franchise",
            ambition: .franchiseIcon,
            selectedSeason: 1,
            anchorTeamID: accepted.snapshot.team.id,
            completedSeason: nil
        )
        XCTAssertFalse(ProCareerGoalRules.progress(state: state, goal: open).completed)
        let closed = ProCareerGoalState(
            id: "goal:franchise",
            ambition: .franchiseIcon,
            selectedSeason: 1,
            anchorTeamID: accepted.snapshot.team.id,
            completedSeason: 8
        )
        XCTAssertTrue(ProCareerGoalRules.progress(state: state, goal: closed).completed)
    }

    func testSettlementDoesNotRegressAGoalThatAlreadyMetItsBar() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "820031")))
        let teamID = accepted.snapshot.team.id
        let prior = (1...8).map {
            ProSeasonStats(season: $0, teamID: teamID, games: 24, starts: 24, inningsOuts: 486, strikeouts: 180)
        }
        let awards = (1...3).map {
            ProCareerRecognition(
                careerID: accepted.snapshot.proCareerID,
                kind: .award,
                contentID: "pro.award.strikeouts",
                season: $0,
                teamID: teamID
            )
        }
        let current = ProSeasonStats(season: 10, teamID: teamID, games: 10, starts: 10, inningsOuts: 90, strikeouts: 20)
        let ready = try unsignedSnapshot(accepted.snapshot) { object in
            object["phase"] = ProCareerPhase.seasonReview.rawValue
            object["season"] = 10
            object["currentStats"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(current))
            object["careerStats"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(prior))
            var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
            journey["rulesVersion"] = 2
            journey["recognitions"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(awards))
            journey["teamRecords"] = try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(ProTeamCareerRecordRules.backfill(careerStats: prior, recognitions: awards))
            )
            object["journeyState"] = journey
        }
        let beforeRecord = try XCTUnwrap(ready.journeyState?.teamRecords.first { $0.teamID == teamID })
        XCTAssertGreaterThanOrEqual(ProTeamLegacyRules.score(record: beforeRecord, rulesVersion: 2), 80)
        let reviewed = try engine.reviewSeason(.init(seed: "820032", state: ready))
        XCTAssertEqual(reviewed.snapshot.phase, .seasonSettlement)
        XCTAssertNotNil(reviewed.snapshot.journeyState?.lastSettlement)
        XCTAssertFalse(reviewed.snapshot.journeyState?.lastSettlement?.goalCompleted ?? true)
        XCTAssertEqual(reviewed.snapshot.journeyState?.lastSettlement?.goalProgressBefore?.completed, true)
        XCTAssertEqual(reviewed.snapshot.journeyState?.lastSettlement?.goalProgressAfter?.completed, true)
    }

    func testReviewSeasonAndRecognitionsShareAwardIDs() {
        let stats = ProSeasonStats(
            season: 1,
            teamID: ProCareerEngine.proTeams[0].id,
            games: 20,
            inningsOuts: 486,
            strikeouts: 180,
            walks: 20,
            runsAllowed: 35,
            hits: 90
        )
        let v1 = Set(ProCareerRecognitionRules.awardContentIDs(stats: stats, rulesVersion: 1))
        let v2 = Set(ProCareerRecognitionRules.awardContentIDs(stats: stats, rulesVersion: 2))
        XCTAssertTrue(v1.contains("pro.award.strikeouts"))
        XCTAssertTrue(v2.contains("pro.award.strikeouts"))
        XCTAssertTrue(v2.contains("pro.award.innings"))
        let recognitions = ProCareerRecognitionRules.currentSeasonRecognitions(
            careerID: "same",
            season: 1,
            teamID: stats.teamID,
            stats: stats,
            level: .major,
            rulesVersion: 2
        )
        XCTAssertEqual(Set(recognitions.filter { $0.kind == .award }.map(\.contentID)), v2)
    }

    private func startParams(seed: String, stuff: Int = 58) -> StartProCareerParams {
        .init(
            seed: seed,
            identity: .defaultPitcher,
            pitcher: .init(id: "balance-pitcher", name: "Balance", stuff: stuff, command: 55, movement: 56, stamina: 57),
            draftResult: .init(
                outcome: .drafted,
                evaluationScore: 72,
                projectedRange: "2~3라운드",
                team: ProCareerEngine.proTeams[0],
                round: 2,
                overallPick: 18,
                signingBonus: 120_000_000,
                firstSeasonGoal: "2군 선발",
                summary: "지명"
            ),
            entitlement: .init(status: .active, source: .development, verifiedAt: "2026-08-20")
        )
    }

    private func acceptRookie(_ started: ProCareerResult) throws -> ProCareerResult {
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

    private func unsignedSnapshot(_ snapshot: ProCareerSnapshot, mutate: (inout [String: Any]) throws -> Void) throws -> ProCareerSnapshot {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        try mutate(&object)
        object["commitment"] = ""
        let unsigned = try JSONDecoder().decode(ProCareerSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        object["commitment"] = engine.commitment(unsigned)
        return try JSONDecoder().decode(ProCareerSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
    }
}
