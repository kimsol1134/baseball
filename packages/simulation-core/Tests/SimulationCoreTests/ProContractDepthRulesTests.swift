import Foundation
import XCTest
@testable import SimulationCore

final class ProContractDepthRulesTests: XCTestCase {
    private let engine = ProCareerEngine(journeyEnabled: true)
    private let pitcher = PitcherSnapshot(id: "depth-pitcher", name: "Depth", stuff: 64, command: 59, movement: 61, stamina: 63)

    func testV10FreeAgencyMarketHasFourOffersSigningBonusAndOptionalFiveYearStay() throws {
        let team = ProCareerEngine.proTeams[0]
        let previous = ProSeasonStats(season: 6, teamID: team.id, games: 28, starts: 22, inningsOuts: 420, strikeouts: 150, walks: 36, runsAllowed: 58)
        let market = try XCTUnwrap(ProContractMarketRules.makeFreeAgencyMarket(
            careerID: "depth-fa",
            currentTeam: team,
            pitcher: pitcher,
            level: .major,
            role: .starter,
            previousStats: previous,
            marketScore: 72,
            fanSupport: 60,
            forSeason: 7,
            generatedAtRevision: 11,
            maximumCareerSeasons: 20,
            usesContractDepth: true,
            lastTeamLegacy: 70
        ))
        XCTAssertEqual(market.offers.count, 4)
        XCTAssertEqual(market.offers[0].contractKind, .freeAgent)
        XCTAssertEqual(market.offers[3].contractKind, .longTerm)
        XCTAssertEqual(Set(market.offers.map(\.teamID)).count, 4)
        XCTAssertTrue(market.offers[0].preservesTeamLegacy)
        XCTAssertFalse(market.offers[3].preservesTeamLegacy)
        XCTAssertEqual(market.offers[3].outlook, .balanced)
        XCTAssertEqual(market.offers[3].expectation.difficulty, .accessible)
        XCTAssertTrue((4...5).contains(market.offers[3].years) || market.offers[3].years <= 20 - 7 + 1)
        XCTAssertTrue((3...5).contains(market.offers[0].years))
        for offer in market.offers {
            let bonus = try XCTUnwrap(offer.signingBonus)
            XCTAssertEqual(bonus % 10_000_000, 0)
            XCTAssertGreaterThan(bonus, 0)
            let percent = bonus * 100 / offer.annualSalary
            XCTAssertGreaterThanOrEqual(percent, 55)
            XCTAssertLessThanOrEqual(percent, 145)
            XCTAssertNotNil(offer.interest)
        }
        XCTAssertTrue(ProContractMarketRules.isValid(
            market: market,
            currentTeamID: team.id,
            currentRole: .starter,
            marketScore: 72,
            pitcher: pitcher,
            usesContractDepth: true,
            lastTeamLegacy: 70
        ))
        XCTAssertEqual(
            ProContractMarketRules.totalGuaranteedSalary(for: market.offers[0]),
            market.offers[0].annualSalary * market.offers[0].years + (market.offers[0].signingBonus ?? 0)
        )
    }

    func testV10RenewalLongAllowsFiveYearsWhenLastTeamLegacyIsHigh() throws {
        let team = ProCareerEngine.proTeams[1]
        let market = try XCTUnwrap(ProContractMarketRules.makeRenewalMarket(
            careerID: "depth-renewal",
            team: team,
            pitcher: pitcher,
            level: .major,
            role: .starter,
            previousStats: .init(season: 8, teamID: team.id, inningsOuts: 360, strikeouts: 120),
            marketScore: 70,
            forSeason: 9,
            generatedAtRevision: 4,
            maximumCareerSeasons: 20,
            usesContractDepth: true,
            lastTeamLegacy: 65
        ))
        let long = try XCTUnwrap(market.offers.first { $0.contractKind == .renewalLong })
        XCTAssertLessThanOrEqual(long.years, 5)
        XCTAssertGreaterThanOrEqual(long.years, 3)
        XCTAssertNil(long.signingBonus)
        XCTAssertTrue(ProContractMarketRules.isValid(
            market: market,
            currentTeamID: team.id,
            currentRole: .starter,
            marketScore: 70,
            pitcher: pitcher,
            usesContractDepth: true,
            lastTeamLegacy: 65
        ))
    }

    func testV9FactoryPathStaysThreeOffersAndNilSigningBonus() throws {
        let team = ProCareerEngine.proTeams[2]
        let market = try XCTUnwrap(ProContractMarketRules.makeFreeAgencyMarket(
            careerID: "legacy-fa",
            currentTeam: team,
            pitcher: pitcher,
            level: .major,
            role: .starter,
            previousStats: .init(season: 6, teamID: team.id, inningsOuts: 300, strikeouts: 100),
            marketScore: 50,
            fanSupport: 40,
            forSeason: 7,
            generatedAtRevision: 3,
            maximumCareerSeasons: 20
        ))
        XCTAssertEqual(market.offers.count, 3)
        XCTAssertTrue(market.offers.allSatisfy { $0.signingBonus == nil && $0.interest == nil && $0.years <= 4 })
        XCTAssertNil(market.counterOffer)
    }

    func testV9EngineFreeAgencyKeepsThreeOffersAndAcceptsWithoutSigningBonus() throws {
        let expired = try expiredOffseason(seed: "810101", proRulesVersion: 9)
        let eligible = try unsignedSnapshot(expired.snapshot) { object in
            object["serviceYears"] = 6
            object["proRulesVersion"] = 9
        }
        let opened = try engine.chooseOffseason(.init(
            seed: expired.nextSeed,
            state: eligible,
            decision: .freeAgency,
            expectedRevision: eligible.revision
        ))
        let market = try XCTUnwrap(opened.snapshot.journeyState?.pendingContractMarket)
        XCTAssertEqual(market.offers.count, 3)
        XCTAssertTrue(market.offers.allSatisfy { $0.signingBonus == nil && $0.years <= 4 })
        let stay = try XCTUnwrap(market.offers.first)
        let accepted = try engine.acceptContract(.init(
            seed: opened.nextSeed,
            state: opened.snapshot,
            expectedRevision: opened.snapshot.revision,
            marketID: market.id,
            offerID: stay.id,
            ambition: .recordBook
        ))
        XCTAssertNil(accepted.snapshot.journeyState?.contractHistory.last?.signingBonus)
        XCTAssertFalse(accepted.snapshot.journeyState?.finances.transactions.contains {
            $0.kind == .signingBonus && $0.season == market.forSeason
        } ?? true)
    }

    func testV10AcceptDepositsSigningBonusOnce() throws {
        let opened = try openedFreeAgency(seed: "810102")
        let market = try XCTUnwrap(opened.snapshot.journeyState?.pendingContractMarket)
        XCTAssertEqual(market.offers.count, 4)
        let stay = try XCTUnwrap(market.offers.first)
        let bonus = try XCTUnwrap(stay.signingBonus)
        let before = try XCTUnwrap(opened.snapshot.journeyState?.finances.availableFunds)
        let accepted = try engine.acceptContract(.init(
            seed: opened.nextSeed,
            state: opened.snapshot,
            expectedRevision: opened.snapshot.revision,
            marketID: market.id,
            offerID: stay.id,
            ambition: .recordBook
        ))
        let finances = try XCTUnwrap(accepted.snapshot.journeyState?.finances)
        let transactionID = "signing:\(accepted.snapshot.proCareerID):\(accepted.snapshot.contract!.id!)"
        XCTAssertEqual(finances.availableFunds, before + Int64(bonus))
        XCTAssertEqual(finances.transactions.filter { $0.id == transactionID }.count, 1)
        XCTAssertEqual(accepted.snapshot.journeyState?.contractHistory.last?.signingBonus, bonus)
        XCTAssertEqual(accepted.snapshot.phase, .offseasonInvestment)
        XCTAssertEqual(errorCode {
            _ = try engine.acceptContract(.init(
                seed: accepted.nextSeed,
                state: accepted.snapshot,
                expectedRevision: accepted.snapshot.revision,
                marketID: market.id,
                offerID: stay.id,
                ambition: .recordBook
            ))
        }, "stale_market")
    }

    func testStayCounterIsDeterministicAndSurvivesReload() throws {
        let opened = try openedFreeAgency(seed: "810103")
        let first = try engine.requestContractCounter(.init(
            seed: opened.nextSeed,
            state: opened.snapshot,
            expectedRevision: opened.snapshot.revision,
            kind: .extraYear
        ))
        let second = try engine.requestContractCounter(.init(
            seed: opened.nextSeed,
            state: opened.snapshot,
            expectedRevision: opened.snapshot.revision,
            kind: .extraYear
        ))
        XCTAssertEqual(first.snapshot, second.snapshot)
        XCTAssertEqual(first.nextSeed, opened.nextSeed)
        let counter = try XCTUnwrap(first.snapshot.journeyState?.pendingContractMarket?.counterOffer)
        XCTAssertEqual(counter.kind, .extraYear)
        XCTAssertEqual(counter.accepted, counter.applied)
        if !counter.accepted {
            XCTAssertEqual(
                first.snapshot.journeyState?.reputation.fanSupport,
                (opened.snapshot.journeyState?.reputation.fanSupport ?? 0) - 1
            )
        }
        let encoded = try JSONEncoder().encode(first.snapshot)
        let restored = try JSONDecoder().decode(ProCareerSnapshot.self, from: encoded)
        XCTAssertEqual(restored, first.snapshot)
        let market = try XCTUnwrap(restored.journeyState?.pendingContractMarket)
        let stay = try XCTUnwrap(market.offers.first)
        XCTAssertNoThrow(try engine.acceptContract(.init(
            seed: first.nextSeed,
            state: restored,
            expectedRevision: restored.revision,
            marketID: market.id,
            offerID: stay.id,
            ambition: .recordBook
        )))
        XCTAssertEqual(errorCode {
            _ = try engine.requestContractCounter(.init(
                seed: first.nextSeed,
                state: first.snapshot,
                expectedRevision: first.snapshot.revision,
                kind: .raiseSalary
            ))
        }, "invalid_offer")
    }

    func testV9RejectsContractCounter() throws {
        let expired = try expiredOffseason(seed: "810104", proRulesVersion: 9)
        let eligible = try unsignedSnapshot(expired.snapshot) { object in
            object["serviceYears"] = 6
            object["proRulesVersion"] = 9
        }
        let opened = try engine.chooseOffseason(.init(
            seed: expired.nextSeed,
            state: eligible,
            decision: .freeAgency,
            expectedRevision: eligible.revision
        ))
        XCTAssertEqual(errorCode {
            _ = try engine.requestContractCounter(.init(
                seed: opened.nextSeed,
                state: opened.snapshot,
                expectedRevision: opened.snapshot.revision,
                kind: .raiseSalary
            ))
        }, "invalid_transition")
    }

    func testNegotiationOffseasonInvestmentThenSpringCamp() throws {
        let opened = try openedFreeAgency(seed: "810105")
        let market = try XCTUnwrap(opened.snapshot.journeyState?.pendingContractMarket)
        let stay = try XCTUnwrap(market.offers.first)
        let accepted = try engine.acceptContract(.init(
            seed: opened.nextSeed,
            state: opened.snapshot,
            expectedRevision: opened.snapshot.revision,
            marketID: market.id,
            offerID: stay.id,
            ambition: .recordBook
        ))
        XCTAssertEqual(accepted.snapshot.phase, .offseasonInvestment)
        XCTAssertEqual(accepted.snapshot.journeyState?.offseasonTransition?.route, .underContract)
        let invested = try engine.chooseInvestment(.init(
            seed: accepted.nextSeed,
            state: accepted.snapshot,
            expectedRevision: accepted.snapshot.revision,
            investment: .equipment
        ))
        XCTAssertEqual(invested.snapshot.phase, .weeklyPlan)
        XCTAssertEqual(invested.snapshot.seasonSegment, .springCamp)
        XCTAssertEqual(invested.snapshot.week, 0)
        XCTAssertEqual(invested.snapshot.season, opened.snapshot.season + 1)
        XCTAssertEqual(invested.snapshot.journeyState?.activeSeasonBenefit?.kind, .equipmentEdge)
        XCTAssertNil(invested.snapshot.journeyState?.offseasonTransition)
        XCTAssertNil(invested.snapshot.journeyState?.pendingContractMarket)
    }

    func testEquipmentAndTrainerExpireOnSeasonRollover() throws {
        XCTAssertEqual(ProFinanceRules.investmentCost(for: .equipment), 30_000_000)
        XCTAssertEqual(ProFinanceRules.investmentCost(for: .personalTrainer), 40_000_000)

        let accepted = try acceptRookie(try engine.start(startParams(seed: "810106", proRulesVersion: 10)), ambition: .recordBook)
        let equipmentState = try offseasonInvestmentState(accepted.snapshot)
        let equipped = try engine.chooseInvestment(.init(
            seed: "810107",
            state: equipmentState,
            expectedRevision: equipmentState.revision,
            investment: .equipment
        ))
        XCTAssertEqual(equipped.snapshot.journeyState?.activeSeasonBenefit?.kind, .equipmentEdge)
        let trainerState = try offseasonInvestmentState(accepted.snapshot)
        let trained = try engine.chooseInvestment(.init(
            seed: "810108",
            state: trainerState,
            expectedRevision: trainerState.revision,
            investment: .personalTrainer
        ))
        XCTAssertEqual(trained.snapshot.journeyState?.activeSeasonBenefit?.kind, .trainingEfficiency)

        let review = try unsignedSnapshot(equipped.snapshot) { object in
            object["phase"] = ProCareerPhase.seasonReview.rawValue
            object["week"] = 24
            object["currentStats"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ProSeasonStats(
                season: equipped.snapshot.season,
                teamID: equipped.snapshot.team.id,
                games: 1,
                inningsOuts: 18,
                strikeouts: 3
            )))
        }
        let settled = try engine.reviewSeason(.init(seed: "810109", state: review))
        XCTAssertNil(settled.snapshot.journeyState?.activeSeasonBenefit)

        let trainedWeek = try unsignedSnapshot(trained.snapshot) { object in
            object["developmentProgress"] = ["stuff": 0, "command": 0, "movement": 0, "stamina": 0]
        }
        let without = try unsignedSnapshot(trainedWeek) { object in
            var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
            journey["activeSeasonBenefit"] = NSNull()
            object["journeyState"] = journey
        }
        let boosted = try engine.planWeek(.init(seed: "810110", state: trainedWeek, plan: .developStuff))
        let baseline = try engine.planWeek(.init(seed: "810110", state: without, plan: .developStuff))
        XCTAssertEqual(boosted.snapshot.developmentProgress?.stuff, 1)
        XCTAssertEqual(baseline.snapshot.developmentProgress?.stuff, 1)
        let boosted2 = try engine.planWeek(.init(seed: "810111", state: boosted.snapshot, plan: .developStuff))
        let baseline2 = try engine.planWeek(.init(seed: "810111", state: baseline.snapshot, plan: .developStuff))
        XCTAssertEqual(boosted2.snapshot.developmentProgress?.stuff, 0)
        XCTAssertGreaterThan(boosted2.snapshot.pitcher.stuff, trained.snapshot.pitcher.stuff)
        XCTAssertEqual(baseline2.snapshot.developmentProgress?.stuff, 2)
        XCTAssertEqual(baseline2.snapshot.pitcher.stuff, trained.snapshot.pitcher.stuff)

        let v9State = try offseasonInvestmentState(
            try acceptRookie(try engine.start(startParams(seed: "810114", proRulesVersion: 9)), ambition: .recordBook).snapshot
        )
        XCTAssertEqual(errorCode {
            _ = try engine.chooseInvestment(.init(
                seed: "810115",
                state: v9State,
                expectedRevision: v9State.revision,
                investment: .equipment
            ))
        }, "invalid_transition")
    }

    func testStayCounterAvailabilityMatchesEngineApply() throws {
        for seed in ["810201", "810202", "810203", "810204"] {
            let opened = try openedFreeAgency(seed: seed)
            let market = try XCTUnwrap(opened.snapshot.journeyState?.pendingContractMarket)
            for kind in [ProContractCounterKind.extraYear, .raiseSalary] {
                let availability = ProContractMarketRules.counterAvailability(
                    market: market,
                    state: opened.snapshot,
                    kind: kind
                )
                let code = errorCode {
                    _ = try engine.requestContractCounter(.init(
                        seed: opened.nextSeed,
                        state: opened.snapshot,
                        expectedRevision: opened.snapshot.revision,
                        kind: kind
                    ))
                }
                if availability.isAvailable {
                    XCTAssertEqual(code, "no_error", "\(seed) \(kind.rawValue)")
                } else {
                    XCTAssertEqual(code, "invalid_offer", "\(seed) \(kind.rawValue)")
                }
            }
        }
    }

    func testCanonicalTokenOmitsNilV10Fields() throws {
        let team = ProCareerEngine.proTeams[0]
        let legacy = try XCTUnwrap(ProContractMarketRules.makeFreeAgencyMarket(
            careerID: "token-legacy",
            currentTeam: team,
            pitcher: pitcher,
            level: .major,
            role: .starter,
            previousStats: .init(season: 6, teamID: team.id, inningsOuts: 300),
            marketScore: 40,
            fanSupport: 30,
            forSeason: 7,
            generatedAtRevision: 2,
            maximumCareerSeasons: 20
        ))
        let journey = ProCareerJourneyState(pendingContractMarket: legacy)
        let token = ProCareerJourneyRules.canonicalToken(journey)
        XCTAssertFalse(token.contains(":interest:"))
        XCTAssertFalse(token.contains("counter:"))
    }

    private func openedFreeAgency(seed: String) throws -> ProCareerResult {
        let expired = try expiredOffseason(seed: seed, proRulesVersion: 10)
        let eligible = try unsignedSnapshot(expired.snapshot) { object in
            object["serviceYears"] = 6
        }
        return try engine.chooseOffseason(.init(
            seed: expired.nextSeed,
            state: eligible,
            decision: .freeAgency,
            expectedRevision: eligible.revision
        ))
    }

    private func startParams(seed: String, proRulesVersion: Int) -> StartProCareerParams {
        .init(
            seed: seed,
            identity: .defaultPitcher,
            pitcher: .init(id: "depth-pitcher", name: "Depth", stuff: 58, command: 55, movement: 56, stamina: 57),
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
            entitlement: .init(status: .active, source: .development, verifiedAt: "2026-09-02"),
            sourceFanInterest: nil,
            startingRepertoire: nil,
            repertoireRulesVersion: nil,
            pitchLearningProject: nil,
            proRulesVersion: proRulesVersion
        )
    }

    private func acceptRookie(_ started: ProCareerResult, ambition: ProCareerAmbition) throws -> ProCareerResult {
        let market = try XCTUnwrap(started.snapshot.journeyState?.pendingContractMarket)
        return try engine.acceptContract(.init(
            seed: started.nextSeed,
            state: started.snapshot,
            expectedRevision: started.snapshot.revision,
            marketID: market.id,
            offerID: market.offers[0].id,
            ambition: ambition
        ))
    }

    private func acknowledgedAfterOneSeason(_ current: ProCareerResult) throws -> ProCareerResult {
        let reviewReady = try unsignedSnapshot(current.snapshot) { object in
            object["phase"] = ProCareerPhase.seasonReview.rawValue
            object["currentStats"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ProSeasonStats(
                season: current.snapshot.season,
                teamID: current.snapshot.team.id,
                games: 1,
                starts: 1,
                inningsOuts: 3,
                strikeouts: 1
            )))
        }
        let reviewed = try engine.reviewSeason(.init(seed: current.nextSeed, state: reviewReady))
        let settlement = try XCTUnwrap(reviewed.snapshot.journeyState?.lastSettlement)
        return try engine.acknowledgeSettlement(.init(
            seed: reviewed.nextSeed,
            state: reviewed.snapshot,
            expectedRevision: reviewed.snapshot.revision,
            settlementID: settlement.id
        ))
    }

    private func expiredOffseason(seed: String, proRulesVersion: Int) throws -> ProCareerResult {
        var current = try acceptRookie(try engine.start(startParams(seed: seed, proRulesVersion: proRulesVersion)), ambition: .recordBook)
        for season in 1...3 {
            let offseason = try acknowledgedAfterOneSeason(current)
            if season == 3 { return offseason }
            let transition = try engine.chooseOffseason(.init(
                seed: offseason.nextSeed,
                state: offseason.snapshot,
                decision: .continueCareer,
                expectedRevision: offseason.snapshot.revision
            ))
            current = try engine.chooseInvestment(.init(
                seed: transition.nextSeed,
                state: transition.snapshot,
                expectedRevision: transition.snapshot.revision,
                investment: .none
            ))
        }
        fatalError("unreachable")
    }

    private func offseasonInvestmentState(
        _ snapshot: ProCareerSnapshot,
        availableFunds: Int64? = nil
    ) throws -> ProCareerSnapshot {
        try unsignedSnapshot(snapshot) { object in
            object["phase"] = ProCareerPhase.offseasonInvestment.rawValue
            object["week"] = 24
            var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
            journey["offseasonTransition"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(
                ProOffseasonTransition(
                    afterSeason: snapshot.season,
                    nextSeason: snapshot.season + 1,
                    ageAdvanceYears: 1,
                    includesMilitaryService: false,
                    route: .underContract
                )
            ))
            if let availableFunds {
                var finances = try XCTUnwrap(journey["finances"] as? [String: Any])
                finances["availableFunds"] = availableFunds
                journey["finances"] = finances
            }
            object["journeyState"] = journey
        }
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
        do {
            try work()
            return "no_error"
        } catch let SimulationError.invalidProCareer(detail) {
            return detail
        } catch {
            return String(describing: error)
        }
    }
}
