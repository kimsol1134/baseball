import Foundation
import XCTest
@testable import SimulationCore

final class ProCareerContractWave2Tests: XCTestCase {
    private let engine = ProCareerEngine(journeyEnabled: true)

    func testJourneyStartCreatesDeterministicSingleRookieOfferWithoutConsumingMarketSeed() throws {
        let first = try engine.start(startParams(seed: "220201"))
        let second = try engine.start(startParams(seed: "220201"))

        XCTAssertEqual(first.snapshot, second.snapshot)
        XCTAssertEqual(first.nextSeed, second.nextSeed)
        XCTAssertEqual(first.snapshot.phase, .contractOffer)
        XCTAssertNil(first.snapshot.contract)
        let market = try XCTUnwrap(first.snapshot.journeyState?.pendingContractMarket)
        let offer = try XCTUnwrap(market.offers.first)
        XCTAssertEqual(market.id, "market:\(first.snapshot.proCareerID):1:rookie")
        XCTAssertEqual(market.generatedAtRevision, 0)
        XCTAssertEqual(market.offers.count, 1)
        XCTAssertEqual(market.draftRound, 2)
        XCTAssertEqual(market.overallPick, 18)
        XCTAssertEqual(offer.id, "offer:\(market.id):\(first.snapshot.team.id):rookie")
        XCTAssertEqual(offer.teamID, first.snapshot.team.id)
        XCTAssertEqual(offer.years, 3)
        XCTAssertEqual(offer.annualSalary, 60_000_000)
        XCTAssertEqual(offer.signingBonus, 120_000_000)
        XCTAssertEqual(offer.contractKind, .rookie)
        XCTAssertEqual(offer.rolePromise, .starter)
        XCTAssertEqual(offer.outlook, .opportunity)
        XCTAssertEqual(offer.expectation, .init(kind: .majorRoster, target: 1, difficulty: .accessible))
        XCTAssertTrue(offer.preservesTeamLegacy)
        XCTAssertEqual(first.snapshot.journeyState?.reputation.fanSupport, 16)
    }

    func testJourneyStartUsesProvidedHighSchoolFanInterest() throws {
        let result = try engine.start(startParams(seed: "220202", sourceFanInterest: 50))
        XCTAssertEqual(result.snapshot.journeyState?.reputation.fanSupport, 30)
    }

    func testJourneyStartRejectsMissingDraftTeamRoundOrBonus() throws {
        for (label, draft) in [
            ("team", draft(team: nil)),
            ("round", draft(round: nil)),
            ("invalid-round", draft(round: 0)),
            ("bonus", draft(signingBonus: nil)),
            ("invalid-bonus", draft(signingBonus: 0)),
        ] {
            XCTAssertEqual(
                errorCode {
                    _ = try engine.start(.init(
                        seed: "220203",
                        identity: .defaultPitcher,
                        pitcher: pitcher(),
                        draftResult: draft,
                        entitlement: entitlement()
                    ))
                },
                "invalid_draft",
                label
            )
        }
    }

    func testAcceptContractRequiresFreshMarketOfferAndAmbition() throws {
        let started = try engine.start(startParams(seed: "220204"))
        let market = try XCTUnwrap(started.snapshot.journeyState?.pendingContractMarket)
        let offer = try XCTUnwrap(market.offers.first)

        XCTAssertEqual(errorCode {
            _ = try engine.acceptContract(.init(
                seed: started.nextSeed,
                state: started.snapshot,
                expectedRevision: started.snapshot.revision + 1,
                marketID: market.id,
                offerID: offer.id,
                ambition: .recordBook
            ))
        }, "stale_revision")
        XCTAssertEqual(errorCode {
            _ = try engine.acceptContract(.init(
                seed: started.nextSeed,
                state: started.snapshot,
                expectedRevision: started.snapshot.revision,
                marketID: "market:stale",
                offerID: offer.id,
                ambition: .recordBook
            ))
        }, "stale_market")
        XCTAssertEqual(errorCode {
            _ = try engine.acceptContract(.init(
                seed: started.nextSeed,
                state: started.snapshot,
                expectedRevision: started.snapshot.revision,
                marketID: market.id,
                offerID: "offer:stale",
                ambition: .recordBook
            ))
        }, "invalid_offer")
        XCTAssertEqual(errorCode {
            _ = try engine.acceptContract(.init(
                seed: started.nextSeed,
                state: started.snapshot,
                expectedRevision: started.snapshot.revision,
                marketID: market.id,
                offerID: offer.id,
                ambition: nil
            ))
        }, "invalid_ambition")
    }

    func testAcceptContractCreatesCanonicalSnapshotGoalRoleAndSigningBonusOnce() throws {
        let started = try engine.start(startParams(seed: "220205"))
        let market = try XCTUnwrap(started.snapshot.journeyState?.pendingContractMarket)
        let offer = try XCTUnwrap(market.offers.first)
        let accepted = try engine.acceptContract(.init(
            seed: started.nextSeed,
            state: started.snapshot,
            expectedRevision: started.snapshot.revision,
            marketID: market.id,
            offerID: offer.id,
            ambition: .recordBook
        ))

        let contract = try XCTUnwrap(accepted.snapshot.contract)
        XCTAssertEqual(accepted.snapshot.phase, .weeklyPlan)
        XCTAssertEqual(accepted.nextSeed, started.nextSeed)
        XCTAssertEqual(contract.id, "contract:\(started.snapshot.proCareerID):1:\(offer.id)")
        XCTAssertEqual(contract.teamID, offer.teamID)
        XCTAssertEqual(contract.yearsRemaining, 3)
        XCTAssertEqual(contract.totalYears, 3)
        XCTAssertEqual(contract.annualSalary, offer.annualSalary)
        XCTAssertEqual(contract.kind, .rookie)
        XCTAssertEqual(contract.expectation, offer.expectation)
        XCTAssertEqual(accepted.snapshot.role, .starter)
        XCTAssertEqual(accepted.snapshot.rolePreference, .starter)

        let journey = try XCTUnwrap(accepted.snapshot.journeyState)
        XCTAssertNil(journey.pendingContractMarket)
        XCTAssertEqual(journey.teamRecords.count, 1)
        let rookieTeamRecord = try XCTUnwrap(journey.teamRecords.first)
        XCTAssertEqual(rookieTeamRecord.teamID, offer.teamID)
        XCTAssertEqual(rookieTeamRecord.completedSeasons, 0)
        XCTAssertEqual(rookieTeamRecord.consecutiveSeasons, 0)
        XCTAssertEqual(rookieTeamRecord.games, 0)
        XCTAssertEqual(rookieTeamRecord.starts, 0)
        XCTAssertEqual(rookieTeamRecord.inningsOuts, 0)
        XCTAssertEqual(rookieTeamRecord.strikeouts, 0)
        XCTAssertEqual(rookieTeamRecord.wins, 0)
        XCTAssertEqual(rookieTeamRecord.saves, 0)
        XCTAssertEqual(rookieTeamRecord.awardCount, 0)
        XCTAssertEqual(rookieTeamRecord.communityPoints, 0)
        XCTAssertNil(rookieTeamRecord.lastSeason)
        let record = try XCTUnwrap(journey.contractHistory.first)
        XCTAssertEqual(record.contractID, contract.id)
        XCTAssertEqual(record.signingBonus, offer.signingBonus)
        XCTAssertEqual(record.coveredSeasons, [])
        let goal = try XCTUnwrap(journey.activeGoal)
        XCTAssertEqual(goal.ambition, .recordBook)
        XCTAssertNil(goal.anchorTeamID)
        XCTAssertEqual(goal.selectedSeason, 1)
        XCTAssertEqual(goal.id, "goal:\(started.snapshot.proCareerID):1:record_book:none")
        let signing = try XCTUnwrap(journey.finances.transactions.first)
        XCTAssertEqual(signing.id, "signing:\(started.snapshot.proCareerID):\(contract.id!)")
        XCTAssertEqual(signing.kind, .signingBonus)
        XCTAssertEqual(signing.amount, 120_000_000)
        XCTAssertEqual(journey.finances.careerEarnings, 120_000_000)
        XCTAssertEqual(journey.finances.availableFunds, 120_000_000)
        XCTAssertEqual(journey.finances.transactions.filter { $0.kind == .signingBonus }.count, 1)

        let roundTrip = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONEncoder().encode(accepted.snapshot)
        )
        XCTAssertEqual(roundTrip, accepted.snapshot)

        XCTAssertEqual(errorCode {
            _ = try engine.acceptContract(.init(
                seed: accepted.nextSeed,
                state: accepted.snapshot,
                expectedRevision: accepted.snapshot.revision,
                marketID: market.id,
                offerID: offer.id,
                ambition: .recordBook
            ))
        }, "stale_market")
    }

    func testJourneyRejectsContractlessActiveState() throws {
        let started = try engine.start(startParams(seed: "220206"))
        let accepted = try accept(started, ambition: .enduringPro)
        let contractless = try unsignedSnapshot(accepted.snapshot) { object in
            object["contract"] = NSNull()
            object["phase"] = ProCareerPhase.weeklyPlan.rawValue
        }
        XCTAssertEqual(errorCode {
            _ = try engine.planWeek(.init(
                seed: accepted.nextSeed,
                state: contractless,
                plan: .recover
            ))
        }, "missing_contract")
    }

    func testThreeYearRookieContractPaysThreeSalariesAndExpiresAtZero() throws {
        var current = try accept(
            try engine.start(startParams(seed: "220207")),
            ambition: .franchiseIcon
        )
        var yearsAfterSettlement: [Int] = []

        for season in 1...3 {
            let reviewReady = try unsignedSnapshot(current.snapshot) { object in
                object["phase"] = ProCareerPhase.seasonReview.rawValue
                object["currentStats"] = try JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(ProSeasonStats(
                        season: current.snapshot.season,
                        teamID: current.snapshot.team.id,
                        games: 1,
                        starts: 1,
                        inningsOuts: 3,
                        strikeouts: 1
                    ))
                )
            }
            let reviewed = try engine.reviewSeason(.init(seed: current.nextSeed, state: reviewReady))
            let settlement = try XCTUnwrap(reviewed.snapshot.journeyState?.lastSettlement)
            yearsAfterSettlement.append(try XCTUnwrap(reviewed.snapshot.contract?.yearsRemaining))
            XCTAssertEqual(settlement.contractYearsBefore, 3 - season + 1)
            XCTAssertEqual(settlement.contractYearsAfter, 3 - season)
            XCTAssertEqual(settlement.salaryIncome, 60_000_000)
            XCTAssertEqual(reviewed.snapshot.journeyState?.finances.salaryCreditedThroughSeason, season)

            if season < 3 {
                let acknowledged = try engine.acknowledgeSettlement(.init(
                    seed: reviewed.nextSeed,
                    state: reviewed.snapshot,
                    expectedRevision: reviewed.snapshot.revision,
                    settlementID: settlement.id
                ))
                let transition = try engine.chooseOffseason(.init(
                    seed: acknowledged.nextSeed,
                    state: acknowledged.snapshot,
                    decision: .continueCareer,
                    expectedRevision: acknowledged.snapshot.revision
                ))
                XCTAssertEqual(transition.snapshot.phase, .offseasonInvestment)
                XCTAssertEqual(transition.snapshot.season, season)
                current = try engine.chooseInvestment(.init(
                    seed: transition.nextSeed,
                    state: transition.snapshot,
                    expectedRevision: transition.snapshot.revision,
                    investment: .none
                ))
                XCTAssertEqual(current.snapshot.season, season + 1)
            } else {
                current = reviewed
            }
        }

        XCTAssertEqual(yearsAfterSettlement, [2, 1, 0])
        let journey = try XCTUnwrap(current.snapshot.journeyState)
        XCTAssertEqual(journey.finances.transactions.filter { $0.kind == .signingBonus }.count, 1)
        XCTAssertEqual(journey.finances.transactions.filter { $0.kind == .salary }.count, 3)
        let record = try XCTUnwrap(journey.contractHistory.first)
        XCTAssertEqual(record.coveredSeasons, [1, 2, 3])
        XCTAssertEqual(record.endedSeason, 3)
        XCTAssertEqual(record.endReason, .expired)

        let acknowledged = try engine.acknowledgeSettlement(.init(
            seed: current.nextSeed,
            state: current.snapshot,
            expectedRevision: current.snapshot.revision,
            settlementID: try XCTUnwrap(journey.lastSettlement?.id)
        ))
        let market = try engine.chooseOffseason(.init(
            seed: acknowledged.nextSeed,
            state: acknowledged.snapshot,
            decision: .continueCareer,
            expectedRevision: acknowledged.snapshot.revision
        ))
        XCTAssertEqual(market.snapshot.phase, .contractOffer)
        XCTAssertEqual(market.snapshot.season, acknowledged.snapshot.season)
        XCTAssertEqual(market.snapshot.journeyState?.pendingContractMarket?.kind, .renewal)
    }

    func testTeamRecordBackfillUnionsAndPreservesExistingZeroTeamRows() throws {
        let zero = ProTeamCareerRecord(
            teamID: "team-b",
            completedSeasons: 0,
            consecutiveSeasons: 0,
            games: 0,
            starts: 0,
            inningsOuts: 0,
            strikeouts: 0,
            wins: 0,
            saves: 0,
            awardCount: 0,
            communityPoints: 4,
            lastSeason: nil
        )
        let records = ProTeamCareerRecordRules.backfill(
            careerStats: [
                ProSeasonStats(season: 1, teamID: "team-a", games: 2, starts: 1, inningsOuts: 18, strikeouts: 4, wins: 1)
            ],
            existing: [zero]
        )

        XCTAssertEqual(records.map(\.teamID), ["team-a", "team-b"])
        XCTAssertEqual(records.last, zero)
        let roundTrip = try JSONDecoder().decode(
            [ProTeamCareerRecord].self,
            from: JSONEncoder().encode(records)
        )
        XCTAssertEqual(roundTrip, records)
    }

    func testJourneyRejectsInvalidZeroTeamRecord() throws {
        let accepted = try accept(
            try engine.start(startParams(seed: "220208")),
            ambition: .recordBook
        )
        let invalid = try unsignedSnapshot(accepted.snapshot) { object in
            var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
            var records = try XCTUnwrap(journey["teamRecords"] as? [[String: Any]])
            records[0]["games"] = 1
            journey["teamRecords"] = records
            object["journeyState"] = journey
        }

        XCTAssertEqual(errorCode {
            _ = try engine.normalizeBalance(.init(seed: accepted.nextSeed, state: invalid))
        }, "zero team record contains completed statistics")
    }

    func testActiveJourneyValidationAllowsOneToFourYearNonRookieContract() throws {
        let accepted = try accept(
            try engine.start(startParams(seed: "220209")),
            ambition: .enduringPro
        )
        func nonRookieSnapshot(totalYears: Int) throws -> ProCareerSnapshot {
            try unsignedSnapshot(accepted.snapshot) { object in
            var contract = try XCTUnwrap(object["contract"] as? [String: Any])
            contract["yearsRemaining"] = totalYears
            contract["totalYears"] = totalYears
            contract["kind"] = ProContractKind.freeAgent.rawValue
            contract["signingBonus"] = NSNull()
            object["contract"] = contract

            var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
            var history = try XCTUnwrap(journey["contractHistory"] as? [[String: Any]])
            history[0]["totalYears"] = totalYears
            history[0]["kind"] = ProContractKind.freeAgent.rawValue
            history[0]["signingBonus"] = NSNull()
            journey["contractHistory"] = history
            var finances = try XCTUnwrap(journey["finances"] as? [String: Any])
            finances["careerEarnings"] = 0
            finances["availableFunds"] = 0
            finances["transactions"] = []
            journey["finances"] = finances
            object["journeyState"] = journey
            }
        }

        for totalYears in 1...4 {
            let validated = try engine.normalizeBalance(.init(
                seed: accepted.nextSeed,
                state: try nonRookieSnapshot(totalYears: totalYears)
            ))
            XCTAssertEqual(validated.snapshot.contract?.kind, .freeAgent)
            XCTAssertEqual(validated.snapshot.contract?.totalYears, totalYears)
            XCTAssertEqual(validated.snapshot.contract?.yearsRemaining, totalYears)
        }
    }

    func testRookieContractValidationRemainsExactlyThreeYears() throws {
        let accepted = try accept(
            try engine.start(startParams(seed: "220211")),
            ambition: .recordBook
        )
        let invalid = try unsignedSnapshot(accepted.snapshot) { object in
            var contract = try XCTUnwrap(object["contract"] as? [String: Any])
            contract["yearsRemaining"] = 4
            contract["totalYears"] = 4
            object["contract"] = contract

            var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
            var history = try XCTUnwrap(journey["contractHistory"] as? [[String: Any]])
            history[0]["totalYears"] = 4
            journey["contractHistory"] = history
            object["journeyState"] = journey
        }

        XCTAssertEqual(errorCode {
            _ = try engine.normalizeBalance(.init(seed: accepted.nextSeed, state: invalid))
        }, "invalid rookie contract record")
    }

    func testFeatureDisabledStartPreservesLegacyRoundBonusInputsAndSeedHash() throws {
        let legacyEngine = ProCareerEngine()
        let baseline = try legacyEngine.start(startParams(seed: "220210"))
        let legacyInputs: [(Int?, Int?)] = [(nil, nil), (0, 0), (nil, 0), (0, nil)]

        for (round, signingBonus) in legacyInputs {
            let result = try legacyEngine.start(.init(
                seed: "220210",
                identity: .defaultPitcher,
                pitcher: pitcher(),
                draftResult: draft(round: round, signingBonus: signingBonus),
                entitlement: entitlement()
            ))
            XCTAssertNil(result.snapshot.journeyState)
            XCTAssertEqual(result.snapshot, baseline.snapshot)
            XCTAssertEqual(result.nextSeed, baseline.nextSeed)
        }

        for (round, signingBonus) in legacyInputs {
            XCTAssertEqual(errorCode {
                _ = try engine.start(.init(
                    seed: "220210",
                    identity: .defaultPitcher,
                    pitcher: pitcher(),
                    draftResult: draft(round: round, signingBonus: signingBonus),
                    entitlement: entitlement()
                ))
            }, "invalid_draft")
        }
    }

    private func accept(_ result: ProCareerResult, ambition: ProCareerAmbition) throws -> ProCareerResult {
        let market = try XCTUnwrap(result.snapshot.journeyState?.pendingContractMarket)
        let offer = try XCTUnwrap(market.offers.first)
        return try engine.acceptContract(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            expectedRevision: result.snapshot.revision,
            marketID: market.id,
            offerID: offer.id,
            ambition: ambition
        ))
    }

    private func unsignedSnapshot(
        _ snapshot: ProCareerSnapshot,
        mutate: (inout [String: Any]) throws -> Void
    ) throws -> ProCareerSnapshot {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any]
        )
        try mutate(&object)
        object["commitment"] = ""
        let unsigned = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        object["commitment"] = engine.commitment(unsigned)
        return try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }

    private func errorCode(_ work: () throws -> Void) -> String {
        do {
            try work()
            return "no_error"
        } catch let SimulationError.invalidProCareer(detail) {
            return detail
        } catch {
            return String(describing: error)
        }
    }

    private func startParams(seed: String, sourceFanInterest: Int? = nil) -> StartProCareerParams {
        .init(
            seed: seed,
            identity: .defaultPitcher,
            pitcher: pitcher(),
            draftResult: draft(),
            entitlement: entitlement(),
            sourceFanInterest: sourceFanInterest
        )
    }

    private func draft(
        team: DraftTeamSnapshot? = ProCareerEngine.proTeams[0],
        round: Int? = 2,
        signingBonus: Int? = 120_000_000
    ) -> DraftResultSnapshot {
        .init(
            outcome: .drafted,
            evaluationScore: 72,
            projectedRange: "2~3라운드",
            team: team,
            round: round,
            overallPick: 18,
            signingBonus: signingBonus,
            firstSeasonGoal: "2군 선발",
            summary: "지명"
        )
    }

    private func pitcher() -> PitcherSnapshot {
        .init(id: "wave2-pitcher", name: "Wave 2", stuff: 58, command: 55, movement: 56, stamina: 57)
    }

    private func entitlement() -> ProEntitlementSnapshot {
        .init(status: .active, source: .development, verifiedAt: "2026-08-14")
    }
}
