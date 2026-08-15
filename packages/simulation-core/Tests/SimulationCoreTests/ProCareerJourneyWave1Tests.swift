import Foundation
import XCTest
@testable import SimulationCore

final class ProCareerJourneyWave1Tests: XCTestCase {
    private let legacy = ProCareerEngine()
    private let journey = ProCareerEngine(journeyEnabled: true)

    func testLegacyReviewMigratesAtBoundaryAndPaysCurrentSalaryOnce() throws {
        var legacyResult = try legacy.start(startParams(seed: "10101"))
        legacyResult = try legacy.signContract(.init(seed: legacyResult.nextSeed, state: legacyResult.snapshot))
        legacyResult = try reachSeasonReview(legacyResult, engine: legacy)
        let salary = try XCTUnwrap(legacyResult.snapshot.contract?.annualSalary)

        let migrated = try journey.migrateJourneyIfSafe(.init(seed: legacyResult.nextSeed, state: legacyResult.snapshot))
        XCTAssertEqual(migrated.nextSeed, legacyResult.nextSeed, "safe migration is seedless")
        XCTAssertEqual(migrated.snapshot.phase, .seasonSettlement)
        let repeatedMigration = try journey.migrateJourneyIfSafe(.init(seed: migrated.nextSeed, state: migrated.snapshot))
        XCTAssertEqual(repeatedMigration.snapshot, migrated.snapshot)
        XCTAssertEqual(repeatedMigration.nextSeed, migrated.nextSeed)
        let settlement = try XCTUnwrap(migrated.snapshot.journeyState?.lastSettlement)
        XCTAssertEqual(settlement.salaryIncome, Int64(salary))
        XCTAssertTrue(migrated.snapshot.journeyState?.migration.financeNoticePending == true)
        XCTAssertEqual(
            migrated.snapshot.journeyState?.finances.transactions.filter { $0.kind == .salary }.count,
            1
        )
        XCTAssertEqual(migrated.snapshot.journeyState?.finances.salaryCreditedThroughSeason, 1)
        XCTAssertEqual(migrated.snapshot.careerStats.count, 1)
        let roundTrip = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONEncoder().encode(migrated.snapshot)
        )
        XCTAssertEqual(roundTrip, migrated.snapshot)

        let reentered = try journey.reviewSeason(.init(seed: migrated.nextSeed, state: migrated.snapshot))
        XCTAssertEqual(reentered.snapshot, migrated.snapshot)
        XCTAssertEqual(reentered.nextSeed, migrated.nextSeed)
        XCTAssertEqual(reentered.snapshot.journeyState?.finances.transactions.filter { $0.kind == .salary }.count, 1)

        let acknowledged = try journey.acknowledgeSettlement(.init(
            seed: reentered.nextSeed,
            state: reentered.snapshot,
            expectedRevision: reentered.snapshot.revision,
            settlementID: settlement.id
        ))
        XCTAssertEqual(acknowledged.snapshot.phase, .offseasonDecision)
        XCTAssertTrue(acknowledged.snapshot.journeyState?.settlementAcknowledged == true)
        XCTAssertFalse(acknowledged.snapshot.journeyState?.migration.financeNoticePending == true)

        let duplicateAcknowledgement = try journey.acknowledgeSettlement(.init(
            seed: acknowledged.nextSeed,
            state: acknowledged.snapshot,
            expectedRevision: acknowledged.snapshot.revision,
            settlementID: settlement.id
        ))
        XCTAssertEqual(duplicateAcknowledgement.snapshot, acknowledged.snapshot)
        XCTAssertEqual(duplicateAcknowledgement.nextSeed, acknowledged.nextSeed)
        XCTAssertEqual(duplicateAcknowledgement.snapshot.revision, acknowledged.snapshot.revision)
        XCTAssertEqual(duplicateAcknowledgement.snapshot.journeyState?.finances.transactions.count, 2)

        let continued = try journey.chooseOffseason(.init(
            seed: acknowledged.nextSeed,
            state: acknowledged.snapshot,
            decision: .continueCareer,
            expectedRevision: acknowledged.snapshot.revision
        ))
        XCTAssertEqual(continued.snapshot.phase, .weeklyPlan)
        XCTAssertEqual(continued.snapshot.season, acknowledged.snapshot.season + 1)
        XCTAssertEqual(continued.snapshot.currentStats.games, 0)
        XCTAssertEqual(continued.snapshot.contract?.yearsRemaining, settlement.contractYearsAfter)
        XCTAssertEqual(continued.nextSeed, acknowledged.nextSeed)
    }

    func testLegacyAwardAdapterCountsUnknownAndUnassignedSeasonAwards() throws {
        let teamID = ProCareerEngine.proTeams[0].id
        let adapted = ProLegacyRecognitionAdapter.recognitions(
            careerID: "legacy-award-fixture",
            awards: ["시즌 1 탈삼진상", "시즌 99 탈삼진상", "알 수 없는 수상"],
            milestones: [],
            teamIDBySeason: [1: teamID]
        )

        XCTAssertEqual(adapted.unassignedAwards, 2)
        XCTAssertEqual(adapted.recognitions.count, 2)
        XCTAssertEqual(adapted.recognitions.first { $0.season == 1 }?.teamID, teamID)
        XCTAssertNil(adapted.recognitions.first { $0.season == 99 }?.teamID)
    }

    func testLegacyFanBackfillIncludesServiceYearsAndClampsToLegacyRange() throws {
        var signed = try legacy.start(startParams(seed: "10106"))
        signed = try legacy.signContract(.init(seed: signed.nextSeed, state: signed.snapshot))
        let enriched = try signedSnapshot(signed.snapshot) { object in
            object["serviceYears"] = 5
            object["awards"] = ["시즌 1 탈삼진상"]
            object["milestones"] = ["1시즌 완주", "프로 통산 3경기"]
        }
        let migrated = try journey.migrateJourneyIfSafe(.init(seed: signed.nextSeed, state: enriched))
        XCTAssertEqual(migrated.snapshot.journeyState?.reputation.fanSupport, 29)

        let capped = try signedSnapshot(signed.snapshot) { object in
            object["serviceYears"] = 40
            object["awards"] = Array(repeating: "legacy award", count: 20)
            object["milestones"] = Array(repeating: "legacy milestone", count: 20)
        }
        let cappedMigration = try journey.migrateJourneyIfSafe(.init(seed: signed.nextSeed, state: capped))
        XCTAssertEqual(cappedMigration.snapshot.journeyState?.reputation.fanSupport, 60)
    }

    func testPendingLegacyContractOfferRemainsFrozen() throws {
        let pending = try legacy.start(startParams(seed: "10102"))
        let migrated = try journey.migrateJourneyIfSafe(.init(seed: pending.nextSeed, state: pending.snapshot))
        XCTAssertEqual(migrated.snapshot, pending.snapshot)
        XCTAssertEqual(migrated.nextSeed, pending.nextSeed)
        XCTAssertTrue(migrated.events.contains("journey_migration_deferred"))
        XCTAssertNil(migrated.snapshot.journeyState)
    }

    func testPendingLegacyDecisionAndImportantGameRemainFrozen() throws {
        for target in [ProCareerPhase.seasonDecision, .importantGame] {
            let pending = try reachPendingPhase(target, seed: target == .seasonDecision ? "10104" : "10105")
            let migrated = try journey.migrateJourneyIfSafe(.init(seed: pending.nextSeed, state: pending.snapshot))
            XCTAssertEqual(migrated.snapshot, pending.snapshot, target.rawValue)
            XCTAssertEqual(migrated.nextSeed, pending.nextSeed, target.rawValue)
            XCTAssertEqual(migrated.events, ["journey_migration_deferred"], target.rawValue)
            XCTAssertNil(migrated.snapshot.journeyState, target.rawValue)
        }
    }

    func testSalaryWatermarkWithoutCurrentSettlementIsRejected() throws {
        var signed = try legacy.start(startParams(seed: "10107"))
        signed = try legacy.signContract(.init(seed: signed.nextSeed, state: signed.snapshot))
        let migrated = try journey.migrateJourneyIfSafe(.init(seed: signed.nextSeed, state: signed.snapshot))
        let review = try reachSeasonReview(migrated, engine: journey)
        let corrupted = try signedSnapshot(review.snapshot) { object in
            try mutateJourney(&object) { journeyObject in
                var finances = try XCTUnwrap(journeyObject["finances"] as? [String: Any])
                finances["salaryCreditedThroughSeason"] = review.snapshot.season
                journeyObject["finances"] = finances
            }
        }

        XCTAssertThrowsError(try journey.reviewSeason(.init(seed: review.nextSeed, state: corrupted))) { error in
            XCTAssertEqual(
                error as? SimulationError,
                .invalidProCareer("current salary is credited without a stored settlement")
            )
        }
    }

    func testSettlementRecognitionIDsAreCanonicalTypedAndCurrentTeamBound() throws {
        var legacyReview = try legacy.start(startParams(seed: "10108"))
        legacyReview = try legacy.signContract(.init(seed: legacyReview.nextSeed, state: legacyReview.snapshot))
        legacyReview = try reachSeasonReview(legacyReview, engine: legacy)
        let boostedReview = try signedSnapshot(legacyReview.snapshot) { object in
            object["currentStats"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(
                ProSeasonStats(
                    season: legacyReview.snapshot.season,
                    teamID: legacyReview.snapshot.team.id,
                    games: 20,
                    starts: 20,
                    inningsOuts: 360,
                    strikeouts: 120,
                    walks: 0,
                    runsAllowed: 0,
                    hits: 0,
                    homeRuns: 0,
                    pitches: 720,
                    wins: 8,
                    saves: 0
                )
            ))
        }
        let settled = try journey.migrateJourneyIfSafe(.init(seed: legacyReview.nextSeed, state: boostedReview))
        let settlement = try XCTUnwrap(settled.snapshot.journeyState?.lastSettlement)
        XCTAssertGreaterThan(settlement.newAwardIDs.count, 1)
        XCTAssertEqual(settlement.newAwardIDs, settlement.newAwardIDs.sorted())
        XCTAssertEqual(Set(settlement.newAwardIDs).count, settlement.newAwardIDs.count)

        let mutations: [(String, [String], [String])] = [
            ("noncanonical order", Array(settlement.newAwardIDs.reversed()), settlement.newMilestoneIDs),
            ("duplicate", [settlement.newAwardIDs[0], settlement.newAwardIDs[0]], settlement.newMilestoneIDs),
            ("wrong type", [try XCTUnwrap(settlement.newMilestoneIDs.first)], settlement.newMilestoneIDs),
            ("unknown reference", ["recognition:missing:award"], settlement.newMilestoneIDs),
        ]
        for (label, awardIDs, milestoneIDs) in mutations {
            let corrupted = try signedSnapshot(settled.snapshot) { object in
                try self.mutateJourney(&object) { journeyObject in
                    var storedSettlement = try XCTUnwrap(journeyObject["lastSettlement"] as? [String: Any])
                    storedSettlement["newAwardIDs"] = awardIDs
                    storedSettlement["newMilestoneIDs"] = milestoneIDs
                    journeyObject["lastSettlement"] = storedSettlement
                }
            }
            XCTAssertThrowsError(try journey.acknowledgeSettlement(.init(
                seed: settled.nextSeed,
                state: corrupted,
                expectedRevision: corrupted.revision,
                settlementID: settlement.id
            )), label)
        }
    }

    func testOnlyMigratedLegacyContractsMayOmitKindAndExpectation() throws {
        var signed = try legacy.start(startParams(seed: "10109"))
        signed = try legacy.signContract(.init(seed: signed.nextSeed, state: signed.snapshot))
        let migrated = try journey.migrateJourneyIfSafe(.init(seed: signed.nextSeed, state: signed.snapshot))
        XCTAssertNoThrow(try journey.planWeek(.init(seed: migrated.nextSeed, state: migrated.snapshot, plan: .earnTrust)))

        let newlyGeneratedContractState = try signedSnapshot(migrated.snapshot) { object in
            try mutateJourney(&object) { journeyObject in
                var migration = try XCTUnwrap(journeyObject["migration"] as? [String: Any])
                migration["source"] = ProJourneyMigrationSource.newCareer.rawValue
                journeyObject["migration"] = migration
            }
        }
        XCTAssertThrowsError(try journey.planWeek(.init(
            seed: migrated.nextSeed,
            state: newlyGeneratedContractState,
            plan: .earnTrust
        )))

        let rookieMarket = ProContractMarketRules.rookieMarket(
            careerID: migrated.snapshot.proCareerID,
            teamID: migrated.snapshot.team.id,
            draftRound: 2,
            signingBonus: 100_000_000,
            generatedAtRevision: migrated.snapshot.revision
        )
        XCTAssertNotNil(rookieMarket.offers.first?.contractKind)
        XCTAssertNotNil(rookieMarket.offers.first?.expectation)
    }

    func testJourneyCommitmentCoversWave1MutableAggregates() throws {
        let started = try legacy.start(startParams(seed: "10110"))
        let teamID = started.snapshot.team.id
        let offer = ProContractMarketRules.rookieMarket(
            careerID: started.snapshot.proCareerID,
            teamID: teamID,
            draftRound: 2,
            signingBonus: 100_000_000,
            generatedAtRevision: started.snapshot.revision
        ).offers[0]
        let market = ProContractMarket(
            id: "market:commitment",
            kind: .rookie,
            forSeason: 1,
            generatedAtRevision: started.snapshot.revision,
            offers: [offer]
        )
        let goal = ProCareerGoalState(
            id: "goal:commitment",
            ambition: .recordBook,
            selectedSeason: 1,
            anchorTeamID: teamID,
            completedSeason: nil
        )
        let record = ProTeamCareerRecord(
            teamID: teamID,
            completedSeasons: 1,
            consecutiveSeasons: 1,
            games: 1,
            starts: 1,
            inningsOuts: 3,
            strikeouts: 1,
            wins: 0,
            saves: 0,
            awardCount: 0,
            communityPoints: 0,
            lastSeason: 1
        )
        let settlement = ProSeasonSettlement(
            id: "settlement:commitment",
            season: 1,
            teamID: teamID,
            stats: started.snapshot.currentStats,
            salaryIncome: 1,
            fanBefore: 10,
            fanAfter: 10,
            teamLegacyBefore: 0,
            teamLegacyAfter: 0,
            hallOfFameBefore: 0,
            hallOfFameAfter: 0,
            contractYearsBefore: 3,
            contractYearsAfter: 2,
            nextRoute: .underContract
        )
        let journeyState = ProCareerJourneyState(
            activeGoal: goal,
            pendingContractMarket: market,
            teamRecords: [record],
            finances: ProFinanceState(
                careerEarnings: 1,
                availableFunds: 1,
                salaryCreditedThroughSeason: 1,
                transactions: [ProFinanceTransaction(id: "tx:commitment", season: 1, kind: .salary, amount: 1)]
            ),
            lastSettlement: settlement,
            settlementAcknowledged: false,
            migration: .init(source: .newCareer, initializedSeason: 1, financeStartsSeason: 1, unassignedLegacyAwards: 0, financeNoticePending: false)
        )
        let base = try snapshotWithJourney(started.snapshot, journey: journeyState)
        let baseline = base.commitment
        let mutations: [(String, (inout [String: Any]) throws -> Void)] = [
            ("market", { object in
                try self.mutateJourney(&object) { journeyObject in
                    var market = try XCTUnwrap(journeyObject["pendingContractMarket"] as? [String: Any])
                    var offers = try XCTUnwrap(market["offers"] as? [[String: Any]])
                    offers[0]["annualSalary"] = 60_000_001
                    market["offers"] = offers
                    journeyObject["pendingContractMarket"] = market
                }
            }),
            ("settlement", { object in
                try self.mutateJourney(&object) { journeyObject in
                    var settlement = try XCTUnwrap(journeyObject["lastSettlement"] as? [String: Any])
                    settlement["salaryIncome"] = 2
                    journeyObject["lastSettlement"] = settlement
                }
            }),
            ("finances", { object in
                try self.mutateJourney(&object) { journeyObject in
                    var finances = try XCTUnwrap(journeyObject["finances"] as? [String: Any])
                    finances["availableFunds"] = 2
                    journeyObject["finances"] = finances
                }
            }),
            ("team records", { object in
                try self.mutateJourney(&object) { journeyObject in
                    var records = try XCTUnwrap(journeyObject["teamRecords"] as? [[String: Any]])
                    records[0]["games"] = 2
                    journeyObject["teamRecords"] = records
                }
            }),
            ("goal completion", { object in
                try self.mutateJourney(&object) { journeyObject in
                    var goal = try XCTUnwrap(journeyObject["activeGoal"] as? [String: Any])
                    goal["completedSeason"] = 1
                    journeyObject["activeGoal"] = goal
                }
            }),
        ]
        for (label, mutation) in mutations {
            let changed = try signedSnapshot(base, mutation: mutation)
            XCTAssertNotEqual(changed.commitment, baseline, label)
        }
    }

    func testTeamBackfillAndLegacyScoreAreCurrentTeamPureRules() throws {
        let teamA = ProCareerEngine.proTeams[0].id
        let teamB = ProCareerEngine.proTeams[1].id
        let stats = [
            ProSeasonStats(season: 1, teamID: teamA, games: 10, starts: 10, inningsOuts: 180, strikeouts: 80, wins: 4, saves: 0),
            ProSeasonStats(season: 2, teamID: teamA, games: 12, starts: 12, inningsOuts: 216, strikeouts: 100, wins: 6, saves: 0),
            ProSeasonStats(season: 3, teamID: teamB, games: 8, starts: 8, inningsOuts: 120, strikeouts: 40, wins: 3, saves: 0),
        ]
        let recognition = ProCareerRecognition(
            id: "recognition:fixture:1:award:pro.award.strikeouts",
            kind: .award,
            contentID: "pro.award.strikeouts",
            season: 1,
            teamID: teamA,
            value: nil
        )
        let records = ProTeamCareerRecordRules.backfill(careerStats: stats, recognitions: [recognition])
        let a = try XCTUnwrap(records.first { $0.teamID == teamA })
        let b = try XCTUnwrap(records.first { $0.teamID == teamB })
        XCTAssertEqual(a.completedSeasons, 2)
        XCTAssertEqual(a.consecutiveSeasons, 2)
        XCTAssertEqual(a.awardCount, 1)
        XCTAssertEqual(b.completedSeasons, 1)
        XCTAssertEqual(b.consecutiveSeasons, 1)
        XCTAssertEqual(ProTeamLegacyRules.score(record: a), 22)
        XCTAssertEqual(ProTeamLegacyRules.score(record: b), 7)
    }

    func testHallOfFameProjectionAddsCurrentSeasonOnlyOnce() throws {
        let started = try legacy.start(startParams(seed: "10103"))
        let current = ProSeasonStats(
            season: started.snapshot.season,
            teamID: started.snapshot.team.id,
            games: 20,
            starts: 20,
            inningsOuts: 180,
            strikeouts: 120,
            wins: 8,
            saves: 0
        )
        let progressing = try snapshot(started.snapshot, currentStats: current)
        let projection = ProCareerEngine.hallOfFameProjection(for: progressing)
        let settled = try snapshot(progressing, careerStats: [current])
        XCTAssertEqual(projection, ProCareerEngine.hallOfFameProjection(for: settled))
        XCTAssertEqual(ProCareerEngine.hallOfFameFinalScore(for: progressing), 0)
    }

    private func reachSeasonReview(_ initial: ProCareerResult, engine: ProCareerEngine) throws -> ProCareerResult {
        var result = initial
        for _ in 0..<120 {
            switch result.snapshot.phase {
            case .weeklyPlan:
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .earnTrust))
            case .seasonDecision:
                let decision = try XCTUnwrap(result.snapshot.pendingDecision)
                let choice = try XCTUnwrap(decision.choices.first)
                result = try engine.applySeasonDecision(.init(seed: result.nextSeed, state: result.snapshot, decisionID: decision.id, choiceID: choice.id))
            case .importantGame:
                result = try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: .init(
                    scenarioNumber: result.snapshot.week,
                    pitches: 18,
                    strikeouts: 2,
                    walks: 0,
                    runsAllowed: 0,
                    expectedDamage: 400,
                    actualDamage: 200,
                    recommendationAccepted: 10
                )))
            case .seasonReview:
                return result
            default:
                throw SimulationError.invalidProCareer("fixture did not reach season review")
            }
        }
        throw SimulationError.invalidProCareer("fixture exceeded season review bound")
    }

    private func signedSnapshot(
        _ source: ProCareerSnapshot,
        mutation: (inout [String: Any]) throws -> Void
    ) throws -> ProCareerSnapshot {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(source)) as? [String: Any])
        try mutation(&object)
        object["commitment"] = ""
        let unsigned = try XCTUnwrap(
            JSONDecoder().decode(
                ProCareerSnapshot.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
        )
        object["commitment"] = legacy.commitment(unsigned)
        return try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }

    private func snapshotWithJourney(
        _ source: ProCareerSnapshot,
        journey: ProCareerJourneyState
    ) throws -> ProCareerSnapshot {
        try signedSnapshot(source) { object in
            object["journeyState"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(journey))
        }
    }

    private func mutateJourney(
        _ object: inout [String: Any],
        _ mutation: (inout [String: Any]) throws -> Void
    ) throws {
        var journeyObject = try XCTUnwrap(object["journeyState"] as? [String: Any])
        try mutation(&journeyObject)
        object["journeyState"] = journeyObject
    }

    private func reachPendingPhase(_ target: ProCareerPhase, seed: String) throws -> ProCareerResult {
        var result = try legacy.start(startParams(seed: seed))
        result = try legacy.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        for _ in 0..<160 {
            if result.snapshot.phase == target { return result }
            switch result.snapshot.phase {
            case .weeklyPlan:
                result = try legacy.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .earnTrust))
            case .seasonDecision:
                let decision = try XCTUnwrap(result.snapshot.pendingDecision)
                let choice = try XCTUnwrap(decision.choices.first)
                result = try legacy.applySeasonDecision(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    decisionID: decision.id,
                    choiceID: choice.id
                ))
            case .importantGame:
                result = try legacy.resolveImportantGame(.init(
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
            default:
                throw SimulationError.invalidProCareer("fixture did not reach " + target.rawValue)
            }
        }
        throw SimulationError.invalidProCareer("fixture exceeded " + target.rawValue + " bound")
    }

    private func snapshot(
        _ source: ProCareerSnapshot,
        currentStats: ProSeasonStats? = nil,
        careerStats: [ProSeasonStats]? = nil
    ) throws -> ProCareerSnapshot {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(source)) as? [String: Any])
        if let currentStats {
            object["currentStats"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(currentStats))
        }
        if let careerStats {
            object["careerStats"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(careerStats))
        }
        object["commitment"] = ""
        let unsigned = try JSONDecoder().decode(ProCareerSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        object["commitment"] = legacy.commitment(unsigned)
        return try JSONDecoder().decode(ProCareerSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func startParams(seed: String) -> StartProCareerParams {
        .init(
            seed: seed,
            identity: .defaultPitcher,
            pitcher: .init(id: "wave1-pitcher", name: "Wave 1", stuff: 58, command: 55, movement: 56, stamina: 57),
            draftResult: .init(
                outcome: .drafted,
                evaluationScore: 72,
                projectedRange: "2~3",
                team: ProCareerEngine.proTeams[0],
                round: 2,
                overallPick: 18,
                signingBonus: 120_000_000,
                firstSeasonGoal: nil,
                summary: "fixture"
            ),
            entitlement: .init(status: .active, source: .development, verifiedAt: "2026-08-14")
        )
    }
}
