import Foundation
import XCTest
@testable import SimulationCore

final class ProCareerLegacyWave4Tests: XCTestCase {
    private let engine = ProCareerEngine(journeyEnabled: true)

    func testTeamRecordsUseCurrentRunCanonicalOrderAndExactStatSums() {
        let teamA = ProCareerEngine.proTeams[0].id
        let teamB = ProCareerEngine.proTeams[1].id
        let teamC = ProCareerEngine.proTeams[2].id
        let stats = [
            ProSeasonStats(season: 1, teamID: teamA, games: 10, starts: 2, inningsOuts: 180, strikeouts: 80, wins: 4, saves: 1),
            ProSeasonStats(season: 2, teamID: teamA, games: 11, starts: 3, inningsOuts: 181, strikeouts: 81, wins: 5, saves: 2),
            ProSeasonStats(season: 3, teamID: teamA, games: 12, starts: 4, inningsOuts: 182, strikeouts: 82, wins: 6, saves: 3),
            ProSeasonStats(season: 8, teamID: teamA, games: 18, starts: 5, inningsOuts: 188, strikeouts: 88, wins: 7, saves: 4),
            ProSeasonStats(season: 9, teamID: teamA, games: 19, starts: 6, inningsOuts: 189, strikeouts: 89, wins: 8, saves: 5),
            ProSeasonStats(season: 4, teamID: teamB, games: 7, starts: 1, inningsOuts: 90, strikeouts: 40, wins: 2, saves: 0),
        ]
        let records = ProTeamCareerRecordRules.backfill(
            careerStats: stats,
            existing: [ProTeamCareerRecord(teamID: teamC, completedSeasons: 0, consecutiveSeasons: 0, games: 0, starts: 0, inningsOuts: 0, strikeouts: 0, wins: 0, saves: 0, awardCount: 0, communityPoints: 4, lastSeason: nil)]
        )

        XCTAssertEqual(records.map(\.teamID), [teamA, teamB, teamC].sorted())
        let a = records[records.firstIndex { $0.teamID == teamA }!]
        XCTAssertEqual(a.completedSeasons, 5)
        XCTAssertEqual(a.consecutiveSeasons, 2, "continuity is the final run, not longest-ever")
        XCTAssertEqual(a.lastSeason, 9)
        XCTAssertEqual(a.games, stats.filter { $0.teamID == teamA }.reduce(0) { $0 + $1.games })
        XCTAssertEqual(a.starts, stats.filter { $0.teamID == teamA }.reduce(0) { $0 + $1.starts })
        XCTAssertEqual(a.inningsOuts, stats.filter { $0.teamID == teamA }.reduce(0) { $0 + $1.inningsOuts })
        XCTAssertEqual(a.strikeouts, stats.filter { $0.teamID == teamA }.reduce(0) { $0 + $1.strikeouts })
        XCTAssertEqual(a.wins, stats.filter { $0.teamID == teamA }.reduce(0) { $0 + $1.wins })
        XCTAssertEqual(a.saves, stats.filter { $0.teamID == teamA }.reduce(0) { $0 + $1.saves })
        XCTAssertEqual(records[records.firstIndex { $0.teamID == teamC }!].communityPoints, 4)

        XCTAssertEqual(
            ProTeamCareerRecordRules.backfill(careerStats: stats, existing: records),
            records,
            "backfill is idempotent"
        )
        XCTAssertEqual(
            try JSONDecoder().decode([ProTeamCareerRecord].self, from: JSONEncoder().encode(records)),
            records,
            "team records round-trip canonically"
        )
        let duplicateSeason = ProTeamCareerRecordRules.backfill(
            careerStats: stats + [stats[0]],
            existing: records
        )
        XCTAssertEqual(duplicateSeason, records, "a retry cannot inflate a season")
    }

    func testTeamAwardCountUsesOnlyRecognizedTypedAwards() {
        let teamID = ProCareerEngine.proTeams[0].id
        let stats = [ProSeasonStats(season: 1, teamID: teamID, inningsOuts: 360, strikeouts: 120)]
        let recognitions = [
            ProCareerRecognition(careerID: "wave4", kind: .award, contentID: "pro.award.strikeouts", season: 1, teamID: teamID),
            ProCareerRecognition(careerID: "wave4", kind: .award, contentID: "pro.award.unlisted", season: 1, teamID: teamID),
            ProCareerRecognition(careerID: "wave4", kind: .milestone, contentID: "pro.milestone.season-complete", season: 1, teamID: teamID),
        ]
        let record = ProTeamCareerRecordRules.backfill(careerStats: stats, recognitions: recognitions)[0]
        XCTAssertEqual(record.awardCount, 1)
    }

    func testLegacyScoreCapsAndTierBoundariesAreExact() {
        let record = ProTeamCareerRecord(teamID: "team", completedSeasons: 8, consecutiveSeasons: 8, games: 0, starts: 0, inningsOuts: 3_000, strikeouts: 4_000, wins: 0, saves: 0, awardCount: 20, communityPoints: 20, lastSeason: 8)
        XCTAssertEqual(ProTeamLegacyRules.score(record: record), 100)
        XCTAssertEqual(ProTeamLegacyRules.tier(record: record), .retiredNumberCandidate)

        let cases: [(scoreRecord: ProTeamCareerRecord, tier: ProLegacyTier)] = [
            (.init(teamID: "new", completedSeasons: 2, consecutiveSeasons: 1, games: 0, starts: 0, inningsOuts: 0, strikeouts: 0, wins: 0, saves: 0, awardCount: 0, communityPoints: 0, lastSeason: 2), .newFace),
            (.init(teamID: "pillar", completedSeasons: 3, consecutiveSeasons: 3, games: 0, starts: 0, inningsOuts: 0, strikeouts: 0, wins: 0, saves: 0, awardCount: 0, communityPoints: 0, lastSeason: 3), .supportingPillar),
            (.init(teamID: "core", completedSeasons: 7, consecutiveSeasons: 1, games: 0, starts: 0, inningsOuts: 0, strikeouts: 0, wins: 0, saves: 0, awardCount: 0, communityPoints: 0, lastSeason: 7), .corePlayer),
            (.init(teamID: "ace", completedSeasons: 10, consecutiveSeasons: 1, games: 0, starts: 0, inningsOuts: 0, strikeouts: 0, wins: 0, saves: 0, awardCount: 1, communityPoints: 8, lastSeason: 10), .clubAce),
            (.init(teamID: "symbol", completedSeasons: 13, consecutiveSeasons: 1, games: 0, starts: 0, inningsOuts: 0, strikeouts: 400, wins: 0, saves: 0, awardCount: 2, communityPoints: 8, lastSeason: 13), .clubSymbol),
        ]
        for item in cases {
            XCTAssertEqual(ProTeamLegacyRules.tier(record: item.scoreRecord), item.tier, item.scoreRecord.teamID)
        }
        XCTAssertEqual(ProTeamLegacyRules.nextThreshold(record: cases[0].scoreRecord), 15)
        XCTAssertNil(ProTeamLegacyRules.nextThreshold(record: record))
    }

    func testNextTierProjectionIncludesBothGatesWithoutRegressiveScore() {
        let scoreGateMet = ProTeamCareerRecord(
            teamID: "score-met",
            completedSeasons: 4,
            consecutiveSeasons: 4,
            games: 0,
            starts: 0,
            inningsOuts: 2_700,
            strikeouts: 1_000,
            wins: 0,
            saves: 0,
            awardCount: 0,
            communityPoints: 6,
            lastSeason: 4
        )
        XCTAssertEqual(ProTeamLegacyRules.score(record: scoreGateMet), 70)
        XCTAssertEqual(ProTeamLegacyRules.nextThreshold(record: scoreGateMet), 70)
        XCTAssertEqual(
            ProTeamLegacyRules.nextTierProjection(record: scoreGateMet),
            .init(tier: .clubSymbol, minimumScore: 65, minimumCompletedSeasons: 6)
        )

        let seasonsGateMet = ProTeamCareerRecord(
            teamID: "seasons-met",
            completedSeasons: 8,
            consecutiveSeasons: 8,
            games: 0,
            starts: 0,
            inningsOuts: 0,
            strikeouts: 480,
            wins: 0,
            saves: 0,
            awardCount: 0,
            communityPoints: 0,
            lastSeason: 8
        )
        XCTAssertEqual(ProTeamLegacyRules.score(record: seasonsGateMet), 60)
        XCTAssertEqual(ProTeamLegacyRules.nextThreshold(record: seasonsGateMet), 65)
        XCTAssertEqual(
            ProTeamLegacyRules.nextTierProjection(record: seasonsGateMet),
            .init(tier: .clubSymbol, minimumScore: 65, minimumCompletedSeasons: 6)
        )

        let terminal = ProTeamCareerRecord(
            teamID: "terminal",
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
        XCTAssertEqual(ProTeamLegacyRules.tier(record: terminal), .retiredNumberCandidate)
        XCTAssertNil(ProTeamLegacyRules.nextTierProjection(record: terminal))
        XCTAssertNil(ProTeamLegacyRules.nextThreshold(record: terminal))
    }

    func testRetirementHonorOrderIsSemantic() {
        let honors = [
            ProRetirementHonor(id: "z-earnings", kind: .careerEarnings, teamID: nil, referenceID: nil, value: 1),
            ProRetirementHonor(id: "a-record", kind: .ambitionCompleted, teamID: nil, referenceID: ProCareerAmbition.recordBook.rawValue, value: nil),
            ProRetirementHonor(id: "b-club", kind: .clubHall, teamID: "team-b", referenceID: nil, value: nil),
            ProRetirementHonor(id: "x-hof", kind: .hallOfFame, teamID: nil, referenceID: nil, value: 70),
            ProRetirementHonor(id: "y-retired", kind: .retiredNumber, teamID: "team-z", referenceID: nil, value: nil),
            ProRetirementHonor(id: "a-enduring", kind: .ambitionCompleted, teamID: nil, referenceID: ProCareerAmbition.enduringPro.rawValue, value: nil),
            ProRetirementHonor(id: "a-club", kind: .clubHall, teamID: "team-a", referenceID: nil, value: nil),
            ProRetirementHonor(id: "a-franchise", kind: .ambitionCompleted, teamID: nil, referenceID: ProCareerAmbition.franchiseIcon.rawValue, value: nil),
        ]

        XCTAssertEqual(
            honors.sorted(by: ProRetirementRules.canonicalOrder).map(\.id),
            ["x-hof", "y-retired", "a-club", "b-club", "a-enduring", "a-franchise", "a-record", "z-earnings"]
        )
    }

    func testGoalProgressHasTwoOrderedMetricsAndRequiresBoth() throws {
        let started = try engine.start(startParams(seed: "440401"))
        let accepted = try acceptRookie(started, ambition: .recordBook)
        let teamID = accepted.snapshot.team.id
        let highCurrent = ProSeasonStats(season: 21, teamID: teamID, games: 20, inningsOuts: 3_000, strikeouts: 3_000, wins: 200)
        let strongCareer = (1...20).map {
            ProSeasonStats(season: $0, teamID: teamID, games: 30, inningsOuts: 540, strikeouts: 300, wins: 10)
        }
        let oneAward = try unsignedSnapshot(accepted.snapshot) { object in
            object["season"] = 21
            object["serviceYears"] = 14
            object["currentStats"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(highCurrent))
            object["careerStats"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(strongCareer))
            object["awards"] = ["legacy-award"]
        }
        let recordBook = ProCareerGoalState(id: "goal:record", ambition: .recordBook, selectedSeason: 1, anchorTeamID: nil, completedSeason: nil)
        let recordBookProgress = ProCareerGoalRules.progress(state: oneAward, goal: recordBook)
        XCTAssertEqual(recordBookProgress.metrics.map(\.kind), [.hallOfFameProjection, .awards])
        XCTAssertEqual(recordBookProgress.metrics.map(\.target), [70, 3])
        XCTAssertFalse(recordBookProgress.completed, "HOF projection alone cannot complete the goal")

        let threeAwards = try unsignedSnapshot(oneAward) { object in
            object["awards"] = ["legacy-award-1", "legacy-award-2", "legacy-award-3"]
        }
        XCTAssertTrue(ProCareerGoalRules.progress(state: threeAwards, goal: recordBook).completed)

        let franchise = ProCareerGoalState(id: "goal:franchise", ambition: .franchiseIcon, selectedSeason: 1, anchorTeamID: teamID, completedSeason: nil)
        let franchiseProgress = ProCareerGoalRules.progress(state: accepted.snapshot, goal: franchise)
        XCTAssertEqual(franchiseProgress.metrics.map(\.kind), [.anchorTeamSeasons, .anchorTeamLegacy])
        XCTAssertFalse(franchiseProgress.completed)

        let enduring = ProCareerGoalState(id: "goal:enduring", ambition: .enduringPro, selectedSeason: 1, anchorTeamID: nil, completedSeason: nil)
        let enduringProgress = ProCareerGoalRules.progress(state: accepted.snapshot, goal: enduring)
        XCTAssertEqual(enduringProgress.metrics.map(\.kind), [.proSeasons, .majorServiceYears])
        XCTAssertFalse(enduringProgress.completed)
    }

    func testHallOfFameProjectionDoesNotDoubleCountSettledCurrentRow() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "440405")), ambition: .recordBook)
        let current = ProSeasonStats(
            season: accepted.snapshot.season,
            teamID: accepted.snapshot.team.id,
            games: 20,
            inningsOuts: 1_080,
            strikeouts: 240,
            wins: 8
        )
        let progressing = try unsignedSnapshot(accepted.snapshot) { object in
            object["currentStats"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(current))
        }
        let projected = ProCareerEngine.hallOfFameProjection(for: progressing)
        let settled = try unsignedSnapshot(progressing) { object in
            object["careerStats"] = [try JSONSerialization.jsonObject(with: JSONEncoder().encode(current))]
        }

        XCTAssertEqual(ProCareerEngine.hallOfFameProjection(for: settled), projected)
        XCTAssertEqual(ProCareerEngine.hallOfFameFinalScore(for: settled), projected)
    }

    func testHallOfFameFormulaVersionKeepsLegacyScoreAndUsesV3ForNewJourneys() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "440407")), ambition: .recordBook)
        let teamID = accepted.snapshot.team.id
        let seasons = (1...20).map {
            ProSeasonStats(season: $0, teamID: teamID, games: 30, inningsOuts: 540, strikeouts: 300, wins: 10)
        }
        let legacyV2 = try unsignedSnapshot(accepted.snapshot) { object in
            object["careerStats"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(seasons))
            object["serviceYears"] = 20
            object["awards"] = ["legacy-award"]
            object["proRulesVersion"] = 2
        }
        let legacyV1 = try unsignedSnapshot(legacyV2) { object in
            object["proRulesVersion"] = 1
        }
        let current = try unsignedSnapshot(legacyV2) { object in
            object["proRulesVersion"] = ProCareerEngine.currentRulesVersion
        }

        XCTAssertEqual(ProCareerEngine.currentRulesVersion, 3)
        XCTAssertEqual(ProCareerEngine.hallOfFameFormulaVersion, 3)
        XCTAssertEqual(ProCareerEngine.hallOfFameFinalScore(for: legacyV1), 100, "v1 saves retain the frozen score formula")
        XCTAssertEqual(ProCareerEngine.hallOfFameFinalScore(for: legacyV2), 100, "v2 saves retain the frozen score formula")
        XCTAssertEqual(ProCareerEngine.hallOfFameFinalScore(for: current), 70, "v3 keeps the threshold while slowing ordinary long-career accumulation")
        XCTAssertNotEqual(legacyV2.commitment, current.commitment)
        XCTAssertEqual(try JSONDecoder().decode(ProCareerSnapshot.self, from: JSONEncoder().encode(legacyV1)), legacyV1)
        XCTAssertEqual(try JSONDecoder().decode(ProCareerSnapshot.self, from: JSONEncoder().encode(legacyV2)), legacyV2)
        XCTAssertEqual(try engine.start(startParams(seed: "440408")).snapshot.proRulesVersion, 3)
    }

    func testJourneyStandingDoesNotUsePreviousTeamGlobalFallback() throws {
        let started = try engine.start(startParams(seed: "440402"))
        let accepted = try acceptRookie(started, ambition: .recordBook)
        let oldTeam = accepted.snapshot.team.id
        let newTeam = try XCTUnwrap(ProCareerEngine.proTeams.first { $0.id != oldTeam })
        let oldRecord = ProTeamCareerRecord(teamID: oldTeam, completedSeasons: 12, consecutiveSeasons: 12, games: 0, starts: 0, inningsOuts: 2_400, strikeouts: 1_200, wins: 0, saves: 0, awardCount: 3, communityPoints: 8, lastSeason: 12)
        let zeroRecord = ProTeamCareerRecord(teamID: newTeam.id, completedSeasons: 0, consecutiveSeasons: 0, games: 0, starts: 0, inningsOuts: 0, strikeouts: 0, wins: 0, saves: 0, awardCount: 0, communityPoints: 0, lastSeason: nil)
        let transferred = try unsignedSnapshot(accepted.snapshot) { object in
            object["team"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(newTeam))
            var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
            journey["teamRecords"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode([oldRecord, zeroRecord].sorted { $0.teamID < $1.teamID }))
            object["journeyState"] = journey
        }
        XCTAssertEqual(ProCareerEngine.careerStanding(for: transferred), .prospect)
    }

    func testRetirementThresholdsUseLastTeamAndPreviousTeamGetsOnlyClubHall() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "440404")), ambition: .recordBook)
        let oldTeam = accepted.snapshot.team.id
        let newTeam = try XCTUnwrap(ProCareerEngine.proTeams.first { $0.id != oldTeam })
        let previousTeam = ProTeamCareerRecord(teamID: oldTeam, completedSeasons: 6, consecutiveSeasons: 6, games: 0, starts: 0, inningsOuts: 0, strikeouts: 1_160, wins: 0, saves: 0, awardCount: 0, communityPoints: 4, lastSeason: 6)
        let lastTeamAt79 = ProTeamCareerRecord(teamID: newTeam.id, completedSeasons: 8, consecutiveSeasons: 8, games: 0, starts: 0, inningsOuts: 0, strikeouts: 1_000, wins: 0, saves: 0, awardCount: 0, communityPoints: 6, lastSeason: 8)
        let lastTeamAt80 = ProTeamCareerRecord(teamID: newTeam.id, completedSeasons: 8, consecutiveSeasons: 8, games: 0, starts: 0, inningsOuts: 0, strikeouts: 1_000, wins: 0, saves: 0, awardCount: 0, communityPoints: 7, lastSeason: 8)
        XCTAssertEqual(ProTeamLegacyRules.score(record: lastTeamAt79), 79)
        XCTAssertEqual(ProTeamLegacyRules.score(record: lastTeamAt80), 80)

        func preview(records: [ProTeamCareerRecord], fan: Int) throws -> ProRetirementPreview {
            let state = try unsignedSnapshot(accepted.snapshot) { object in
                object["team"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(newTeam))
                var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
                journey["teamRecords"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(records.sorted { $0.teamID < $1.teamID }))
                var reputation = try XCTUnwrap(journey["reputation"] as? [String: Any])
                reputation["fanSupport"] = fan
                journey["reputation"] = reputation
                object["journeyState"] = journey
            }
            return ProCareerEngine.retirementPreview(for: state)
        }

        let belowLegacy = try preview(records: [previousTeam, lastTeamAt79], fan: 60)
        XCTAssertFalse(belowLegacy.retiredNumberEligible)
        XCTAssertEqual(belowLegacy.clubHallTeamIDs, [oldTeam, newTeam.id].sorted())
        XCTAssertEqual(belowLegacy.lastTeamID, newTeam.id)
        XCTAssertFalse(try preview(records: [previousTeam, lastTeamAt80], fan: 59).retiredNumberEligible)
        let eligible = try preview(records: [previousTeam, lastTeamAt80], fan: 60)
        XCTAssertTrue(eligible.retiredNumberEligible)
        XCTAssertEqual(eligible.clubHallTeamIDs, [oldTeam])
        XCTAssertTrue(eligible.honors.contains { $0.kind == .retiredNumber && $0.teamID == newTeam.id })
    }

    func testSettlementRewardAndRetirementAreAtomicCanonicalAndIdempotent() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "440403")), ambition: .recordBook)
        let teamID = accepted.snapshot.team.id
        let priorStats = (2...20).map {
            ProSeasonStats(season: $0, teamID: teamID, games: 20, inningsOuts: 180, strikeouts: 80, wins: 3)
        }
        let reviewReady = try unsignedSnapshot(accepted.snapshot) { object in
            object["phase"] = ProCareerPhase.seasonReview.rawValue
            object["serviceYears"] = 20
            object["currentStats"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ProSeasonStats(season: 1, teamID: teamID, games: 20, inningsOuts: 5_000, strikeouts: 3_000, wins: 200)))
            object["careerStats"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(priorStats))
            object["awards"] = ["legacy-award"]
            var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
            journey["teamRecords"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ProTeamCareerRecordRules.backfill(careerStats: priorStats)))
            object["journeyState"] = journey
        }
        XCTAssertEqual(reviewReady.careerStats.count, 19)
        XCTAssertEqual(
            ProTeamCareerRecordRules.backfill(careerStats: reviewReady.careerStats, existing: reviewReady.journeyState?.teamRecords ?? []).first?.completedSeasons,
            19,
            "current season remains excluded before settlement"
        )
        let reviewed = try engine.reviewSeason(.init(seed: accepted.nextSeed, state: reviewReady))
        XCTAssertEqual(reviewed.snapshot.journeyState?.teamRecords.first?.completedSeasons, 20)
        let settlement = try XCTUnwrap(reviewed.snapshot.journeyState?.lastSettlement)
        XCTAssertTrue(settlement.goalCompleted)
        XCTAssertEqual(reviewed.snapshot.journeyState?.goalHistory.filter { $0.outcome == .completed }.count, 1)
        XCTAssertEqual(reviewed.snapshot.journeyState?.recognitions.filter { $0.contentID == "pro.ambition.record_book.completed" }.count, 1)
        let fanReasons = settlement.fanReasons.reduce(into: 0) { $0 += $1.delta }
        XCTAssertEqual(
            reviewed.snapshot.journeyState?.reputation.fanSupport,
            min(100, max(0, settlement.fanBefore + min(20, max(-12, fanReasons))))
        )
        XCTAssertEqual(settlement.fanReasons.filter { $0.kind == .careerAmbitionCompleted }.map(\.delta), [10])

        let completionFlagTamper = try unsignedSnapshot(reviewed.snapshot) { object in
            var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
            var settlementObject = try XCTUnwrap(journey["lastSettlement"] as? [String: Any])
            settlementObject["goalCompleted"] = false
            journey["lastSettlement"] = settlementObject
            object["journeyState"] = journey
        }
        XCTAssertEqual(errorCode {
            _ = try engine.acknowledgeSettlement(.init(
                seed: reviewed.nextSeed,
                state: completionFlagTamper,
                expectedRevision: completionFlagTamper.revision,
                settlementID: settlement.id
            ))
        }, "settlement ambition completion is not exact-once")

        let completedProgress = try XCTUnwrap(settlement.goalProgressAfter)
        let completionRecognitionID = settlement.newMilestoneIDs.first { id in
            reviewed.snapshot.journeyState?.recognitions.first(where: { $0.id == id })?.contentID.hasPrefix("pro.ambition.") == true
        }
        let stableMilestones = settlement.newMilestoneIDs.filter { $0 != completionRecognitionID }
        let stableReasons = settlement.fanReasons.filter { $0.kind != .careerAmbitionCompleted }
        let stableRawDelta = stableReasons.reduce(into: 0) { $0 += $1.delta }
        let stableDelta = min(20, max(-12, stableRawDelta))
        let stableAfter = min(100, max(0, settlement.fanBefore + stableDelta))
        let stableSettlement = ProSeasonSettlement(
            id: settlement.id,
            season: settlement.season,
            teamID: settlement.teamID,
            stats: settlement.stats,
            newAwardIDs: settlement.newAwardIDs,
            newMilestoneIDs: stableMilestones,
            salaryIncome: settlement.salaryIncome,
            merchandiseIncome: settlement.merchandiseIncome,
            fanBefore: settlement.fanBefore,
            fanAfter: stableAfter,
            fanDelta: stableDelta,
            fanReasons: stableReasons,
            merchandiseTier: settlement.merchandiseTier,
            teamLegacyBefore: settlement.teamLegacyBefore,
            teamLegacyAfter: settlement.teamLegacyAfter,
            hallOfFameBefore: settlement.hallOfFameBefore,
            hallOfFameAfter: settlement.hallOfFameAfter,
            contractYearsBefore: settlement.contractYearsBefore,
            contractYearsAfter: settlement.contractYearsAfter,
            contractExpectation: settlement.contractExpectation,
            contractExpectationActual: settlement.contractExpectationActual,
            contractExpectationMet: settlement.contractExpectationMet,
            goalProgressBefore: completedProgress,
            goalProgressAfter: completedProgress,
            goalCompleted: false,
            nextRoute: settlement.nextRoute
        )
        let stableProjection = try unsignedSnapshot(reviewed.snapshot) { object in
            var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
            journey["lastSettlement"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(stableSettlement))
            var reputation = try XCTUnwrap(journey["reputation"] as? [String: Any])
            reputation["fanSupport"] = stableAfter
            journey["reputation"] = reputation
            object["journeyState"] = journey
        }
        let stableAcknowledged = try engine.acknowledgeSettlement(.init(
            seed: stableProjection.revision.description,
            state: stableProjection,
            expectedRevision: stableProjection.revision,
            settlementID: stableSettlement.id
        ))
        XCTAssertEqual(stableAcknowledged.snapshot.journeyState?.goalHistory, reviewed.snapshot.journeyState?.goalHistory)
        XCTAssertEqual(stableAcknowledged.snapshot.journeyState?.recognitions, reviewed.snapshot.journeyState?.recognitions)

        let acknowledged = try engine.acknowledgeSettlement(.init(seed: reviewed.nextSeed, state: reviewed.snapshot, expectedRevision: reviewed.snapshot.revision, settlementID: settlement.id))
        let preview = ProCareerEngine.retirementPreview(for: acknowledged.snapshot)
        let retired = try engine.chooseOffseason(.init(seed: acknowledged.nextSeed, state: acknowledged.snapshot, decision: .retire, expectedRevision: acknowledged.snapshot.revision))
        let journey = try XCTUnwrap(retired.snapshot.journeyState)
        XCTAssertEqual(journey.retirementHonors, preview.honors)
        XCTAssertEqual(retired.snapshot.hallOfFameScore, preview.finalScore)
        XCTAssertNil(retired.snapshot.contract)
        XCTAssertNil(journey.activeGoal)
        XCTAssertEqual(journey.contractHistory.filter { $0.endReason == .retired }.count, 1)
        XCTAssertEqual(journey.contractHistory.first?.endedSeason, acknowledged.snapshot.season)
        XCTAssertEqual(journey.retirementHonors.map(\.kind), [.hallOfFame, .clubHall, .ambitionCompleted, .careerEarnings])
        XCTAssertEqual(journey.retirementHonors.filter { $0.kind == .careerEarnings }.count, 1)
        XCTAssertEqual(journey.goalHistory.first?.outcome, .completed)

        let retry = try engine.chooseOffseason(.init(seed: retired.nextSeed, state: retired.snapshot, decision: .retire, expectedRevision: retired.snapshot.revision))
        XCTAssertEqual(retry.snapshot, retired.snapshot)
        XCTAssertEqual(retry.snapshot.journeyState?.retirementHonors.count, journey.retirementHonors.count)
        XCTAssertEqual(
            try JSONDecoder().decode(ProCareerSnapshot.self, from: JSONEncoder().encode(retired.snapshot)),
            retired.snapshot,
            "completed retirement snapshot round-trips"
        )
        XCTAssertEqual(errorCode {
            _ = try engine.chooseOffseason(.init(seed: retry.nextSeed, state: retry.snapshot, decision: .retire, expectedRevision: retry.snapshot.revision - 1))
        }, "stale_revision")
    }

    func testRetirementClosesIncompleteGoalAsRetiredIncomplete() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "440406")), ambition: .enduringPro)
        let teamID = accepted.snapshot.team.id
        let reviewReady = try unsignedSnapshot(accepted.snapshot) { object in
            object["phase"] = ProCareerPhase.seasonReview.rawValue
            object["currentStats"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(
                ProSeasonStats(season: 1, teamID: teamID, games: 1, inningsOuts: 90, strikeouts: 10)
            ))
        }
        let reviewed = try engine.reviewSeason(.init(seed: accepted.nextSeed, state: reviewReady))
        let settlement = try XCTUnwrap(reviewed.snapshot.journeyState?.lastSettlement)
        let acknowledged = try engine.acknowledgeSettlement(.init(
            seed: reviewed.nextSeed,
            state: reviewed.snapshot,
            expectedRevision: reviewed.snapshot.revision,
            settlementID: settlement.id
        ))
        let retired = try engine.chooseOffseason(.init(
            seed: acknowledged.nextSeed,
            state: acknowledged.snapshot,
            decision: .retire,
            expectedRevision: acknowledged.snapshot.revision
        ))
        let journey = try XCTUnwrap(retired.snapshot.journeyState)

        XCTAssertNil(journey.activeGoal)
        XCTAssertEqual(journey.goalHistory.count, 1)
        XCTAssertEqual(journey.goalHistory[0].outcome, .retiredIncomplete)
        XCTAssertEqual(journey.goalHistory[0].endedSeason, acknowledged.snapshot.season)
        XCTAssertEqual(journey.contractHistory.filter { $0.endReason == .retired }.count, 1)
    }

    func testJourneyValidationRejectsMalformedHistoryAndDuplicateAmbitionRewards() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "440407")), ambition: .recordBook)
        let activeGoal = try XCTUnwrap(accepted.snapshot.journeyState?.activeGoal)
        let malformedHistory = try unsignedSnapshot(accepted.snapshot) { object in
            object["phase"] = ProCareerPhase.seasonReview.rawValue
            let record = ProCareerGoalRecord(
                id: activeGoal.id,
                ambition: activeGoal.ambition,
                selectedSeason: activeGoal.selectedSeason,
                anchorTeamID: activeGoal.anchorTeamID,
                completedSeason: nil,
                endedSeason: activeGoal.selectedSeason,
                outcome: .replaced
            )
            var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
            journey["goalHistory"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode([record, record]))
            object["journeyState"] = journey
        }
        XCTAssertEqual(errorCode {
            _ = try engine.reviewSeason(.init(seed: accepted.nextSeed, state: malformedHistory))
        }, "journey audit IDs must be unique")

        let completedRecord = ProCareerGoalRecord(
            id: activeGoal.id,
            ambition: activeGoal.ambition,
            selectedSeason: activeGoal.selectedSeason,
            anchorTeamID: activeGoal.anchorTeamID,
            completedSeason: activeGoal.selectedSeason,
            endedSeason: activeGoal.selectedSeason,
            outcome: .completed
        )
        let rewards = [
            ProCareerRecognition(careerID: accepted.snapshot.proCareerID, kind: .milestone, contentID: "pro.ambition.record_book.completed", season: 1, teamID: accepted.snapshot.team.id),
            ProCareerRecognition(careerID: accepted.snapshot.proCareerID, kind: .milestone, contentID: "pro.ambition.record_book.completed", season: 2, teamID: accepted.snapshot.team.id),
        ].sorted(by: ProCareerJourneyRules.recognitionOrder)
        let duplicateRewards = try unsignedSnapshot(accepted.snapshot) { object in
            object["phase"] = ProCareerPhase.seasonReview.rawValue
            var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
            journey["activeGoal"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(completedRecord))
            journey["goalHistory"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode([completedRecord]))
            journey["recognitions"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(rewards))
            object["journeyState"] = journey
        }
        XCTAssertEqual(errorCode {
            _ = try engine.reviewSeason(.init(seed: accepted.nextSeed, state: duplicateRewards))
        }, "ambition reward is duplicated or unearned")
    }

    private func startParams(seed: String) -> StartProCareerParams {
        .init(
            seed: seed,
            identity: .defaultPitcher,
            pitcher: .init(id: "wave4-pitcher", name: "Wave 4", stuff: 58, command: 55, movement: 56, stamina: 57),
            draftResult: .init(outcome: .drafted, evaluationScore: 72, projectedRange: "2~3라운드", team: ProCareerEngine.proTeams[0], round: 2, overallPick: 18, signingBonus: 120_000_000, firstSeasonGoal: "2군 선발", summary: "지명"),
            entitlement: .init(status: .active, source: .development, verifiedAt: "2026-08-15")
        )
    }

    private func acceptRookie(_ started: ProCareerResult, ambition: ProCareerAmbition) throws -> ProCareerResult {
        let market = try XCTUnwrap(started.snapshot.journeyState?.pendingContractMarket)
        return try engine.acceptContract(.init(seed: started.nextSeed, state: started.snapshot, expectedRevision: started.snapshot.revision, marketID: market.id, offerID: market.offers[0].id, ambition: ambition))
    }

    private func unsignedSnapshot(_ snapshot: ProCareerSnapshot, mutate: (inout [String: Any]) throws -> Void) throws -> ProCareerSnapshot {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        try mutate(&object)
        object["commitment"] = ""
        let unsigned = try JSONDecoder().decode(ProCareerSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        object["commitment"] = engine.commitment(unsigned)
        return try JSONDecoder().decode(ProCareerSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func errorCode(_ work: () throws -> Void) -> String {
        do { try work(); return "no_error" }
        catch let SimulationError.invalidProCareer(detail) { return detail }
        catch { return String(describing: error) }
    }
}

private typealias ProLegacyTier = ProTeamLegacyTier
