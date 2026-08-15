import Foundation
import XCTest
@testable import SimulationCore

final class ProCareerContractWave3Tests: XCTestCase {
    private let engine = ProCareerEngine(journeyEnabled: true)

    func testMarketRulesUseIntegerWeightedScoreAndFulfillmentAdjustment() throws {
        let pitcher = PitcherSnapshot(id: "wave3", name: "Wave 3", stuff: 60, command: 50, movement: 40, stamina: 30)
        XCTAssertEqual(ProContractMarketRules.weightedRating(for: pitcher), 47)
        let stats = ProSeasonStats(season: 4, teamID: "team", games: 20, inningsOuts: 360, strikeouts: 90, walks: 10, runsAllowed: 60)
        let fulfilled = ProContractRecord(
            contractID: "contract:wave3:4:expired",
            teamID: "team",
            kind: .freeAgent,
            signedSeason: 1,
            totalYears: 3,
            annualSalary: 100_000_000,
            signingBonus: nil,
            rolePromise: .starter,
            expectation: .init(kind: .innings, target: 240, difficulty: .standard),
            coveredSeasons: [1, 2, 3],
            fulfilledExpectationSeasons: [1, 2, 3],
            endedSeason: 3,
            endReason: .expired
        )
        let base = ProContractMarketRules.marketScore(
            pitcher: pitcher,
            currentStats: stats,
            standing: .established,
            age: 30,
            fanSupport: 50
        )
        let adjusted = ProContractMarketRules.marketScore(
            pitcher: pitcher,
            currentStats: stats,
            standing: .established,
            age: 30,
            fanSupport: 50,
            expiredContract: fulfilled
        )
        XCTAssertEqual(adjusted, min(100, base + 5))
        XCTAssertGreaterThanOrEqual(adjusted, 0)
        XCTAssertLessThanOrEqual(adjusted, 100)
    }

    func testSalaryBandsAreTenMillionRoundedAndInt64Safe() {
        XCTAssertEqual(ProContractMarketRules.salaryBand(for: 0), .init(minimum: 40_000_000, maximum: 90_000_000))
        XCTAssertEqual(ProContractMarketRules.salaryBand(for: 100), .init(minimum: 950_000_000, maximum: 1_400_000_000))
        XCTAssertEqual(ProContractMarketRules.roundToNearestTenMillion(15_000_000), 20_000_000)
        let salary = ProContractMarketRules.annualSalary(
            marketScore: 100,
            marketID: "market:wave3:20:free_agency",
            teamID: "team",
            contractKind: .freeAgent,
            multiplierNumerator: Int.max
        )
        XCTAssertEqual(salary % 10_000_000, 0)
        XCTAssertLessThanOrEqual(salary, 1_500_000_000)
    }

    func testRoleMatrixAndExpectationActualHelpersAreExplicit() {
        XCTAssertEqual(ProContractMarketRules.roleValue(current: .starter, promised: .starter), 1)
        XCTAssertEqual(ProContractMarketRules.roleValue(current: .starter, promised: .longRelief), 0)
        XCTAssertEqual(ProContractMarketRules.roleValue(current: .longRelief, promised: .starter), 2)
        XCTAssertEqual(ProContractMarketRules.roleValue(current: .longRelief, promised: .setup), 2)
        XCTAssertEqual(ProContractMarketRules.roleValue(current: .setup, promised: .closer), 2)
        XCTAssertEqual(ProContractMarketRules.roleValue(current: .closer, promised: .starter), 0)

        let expectation = ProContractMarketRules.buildExpectation(
            level: .major,
            role: .starter,
            previousStats: .init(season: 3, teamID: "team", inningsOuts: 400),
            contractKind: .proveIt,
            outlook: .balanced
        )
        XCTAssertEqual(expectation.kind, .innings)
        XCTAssertEqual(expectation.target, 396)
        XCTAssertEqual(expectation.difficulty, .stretch)
        let actual = ProContractMarketRules.actual(
            expectation: .init(kind: .runPrevention, target: 4_000, difficulty: .standard),
            stats: .init(season: 1, teamID: "team", inningsOuts: 30, runsAllowed: 0),
            level: .major
        )
        XCTAssertNil(actual)
        XCTAssertTrue(ProContractMarketRules.met(expectation: .init(kind: .saves, target: 3, difficulty: .standard), actual: 3))
        XCTAssertTrue(ProContractMarketRules.met(expectation: .init(kind: .runPrevention, target: 4_000, difficulty: .standard), actual: 3_900))
    }

    func testCountingExpectationFinalClampIsRoleSpecificForAccessibleAndStretch() {
        let cases: [(role: ProRole, accessible: Int, stretch: Int, stats: ProSeasonStats)] = [
            (.starter, 240, 420, .init(season: 1, teamID: "team", inningsOuts: 1_000)),
            (.longRelief, 120, 240, .init(season: 1, teamID: "team", inningsOuts: 1_000)),
            (.setup, 35, 80, .init(season: 1, teamID: "team", strikeouts: 1_000)),
            (.closer, 12, 30, .init(season: 1, teamID: "team", saves: 1_000)),
        ]

        for item in cases {
            let accessible = ProContractMarketRules.buildExpectation(
                level: .major,
                role: item.role,
                previousStats: .init(season: 1, teamID: "team"),
                contractKind: .renewalLong,
                outlook: .balanced
            )
            let stretch = ProContractMarketRules.buildExpectation(
                level: .major,
                role: item.role,
                previousStats: item.stats,
                contractKind: .proveIt,
                outlook: .balanced
            )
            XCTAssertEqual(accessible.target, item.accessible, item.role.rawValue)
            XCTAssertEqual(stretch.target, item.stretch, item.role.rawValue)
            XCTAssertEqual(accessible.difficulty, .accessible)
            XCTAssertEqual(stretch.difficulty, .stretch)
        }
    }

    func testRenewalMarketIsDeterministicTwoCurrentTeamNonDominatedOffers() throws {
        let expired = try expiredOffseason(seed: "310301")
        let first = try engine.chooseOffseason(.init(seed: expired.nextSeed, state: expired.snapshot, decision: .continueCareer, expectedRevision: expired.snapshot.revision))
        let second = try engine.chooseOffseason(.init(seed: expired.nextSeed, state: expired.snapshot, decision: .continueCareer, expectedRevision: expired.snapshot.revision))
        XCTAssertEqual(first.snapshot, second.snapshot)
        XCTAssertEqual(first.nextSeed, expired.nextSeed)
        XCTAssertEqual(first.snapshot.season, expired.snapshot.season)
        XCTAssertEqual(first.snapshot.phase, .contractOffer)
        let market = try XCTUnwrap(first.snapshot.journeyState?.pendingContractMarket)
        XCTAssertEqual(market.id, "market:\(expired.snapshot.proCareerID):\(expired.snapshot.season + 1):renewal")
        XCTAssertEqual(market.offers.count, 2)
        XCTAssertTrue(market.offers.allSatisfy { $0.teamID == expired.snapshot.team.id && $0.signingBonus == nil })
        XCTAssertEqual(Set(market.offers.map(\.contractKind)), Set([.renewalLong, .proveIt]))
        XCTAssertTrue(ProContractMarketRules.isNonDominated(market.offers, currentRole: expired.snapshot.role))
        let roundTrip = try JSONDecoder().decode(ProCareerSnapshot.self, from: JSONEncoder().encode(first.snapshot))
        XCTAssertEqual(roundTrip, first.snapshot)
    }

    func testRenewalFactoryKeepsTwoOffersNonDominatedAcrossBandsAndLateCap() throws {
        for team in ProCareerEngine.proTeams {
            for role in [ProRole.starter, .longRelief, .setup, .closer] {
                for level in [ProLevel.minor, .major] {
                    for score in [0, 20, 45, 65, 90, 100] {
                        for forSeason in [1, 10, 19, 20] {
                            let market = try XCTUnwrap(ProContractMarketRules.makeRenewalMarket(
                                careerID: "renewal-factory",
                                team: team,
                                pitcher: .init(id: "factory", name: "Factory", stuff: 65, command: 62, movement: 61, stamina: 64),
                                level: level,
                                role: role,
                                previousStats: .init(season: max(1, forSeason - 1), teamID: team.id, inningsOuts: 180, strikeouts: 120, walks: 30, runsAllowed: 55, saves: role == .closer ? 18 : 0),
                                marketScore: score,
                                forSeason: forSeason,
                                generatedAtRevision: 7,
                                maximumCareerSeasons: 20
                            ))
                            XCTAssertTrue(ProContractMarketRules.isValid(market: market, currentTeamID: team.id, currentRole: role, marketScore: score))
                            let long = try XCTUnwrap(market.offers.first { $0.contractKind == .renewalLong })
                            let prove = try XCTUnwrap(market.offers.first { $0.contractKind == .proveIt })
                            let regular = long.annualSalary == ProContractMarketRules.annualSalary(marketScore: score, marketID: market.id, teamID: team.id, contractKind: .renewalLong, multiplierNumerator: 90)
                                && prove.annualSalary == ProContractMarketRules.annualSalary(marketScore: score, marketID: market.id, teamID: team.id, contractKind: .proveIt, multiplierNumerator: 110)
                            let remaining = 20 - forSeason + 1
                            let canonical = long.years == min(4, remaining)
                                && prove.years == 1
                                && long.annualSalary == ProContractMarketRules.canonicalFallbackSalary(marketScore: score, multiplierNumerator: 90)
                                && prove.annualSalary == ProContractMarketRules.canonicalFallbackSalary(marketScore: score, multiplierNumerator: 110)
                            XCTAssertTrue(regular || canonical, "renewal salary tuple must be regular or exact canonical fallback")
                            if canonical {
                                XCTAssertEqual(long.annualSalary, ProContractMarketRules.canonicalFallbackSalary(marketScore: score, multiplierNumerator: 90))
                                XCTAssertEqual(prove.annualSalary, ProContractMarketRules.canonicalFallbackSalary(marketScore: score, multiplierNumerator: 110))
                            }
                        }
                    }
                }
            }
        }
    }

    func testFreeAgencyMarketHasCurrentAndTwoStableTeamsWithTradeoffs() throws {
        let expired = try expiredOffseason(seed: "310302")
        let eligible = try unsignedSnapshot(expired.snapshot) { object in
            object["serviceYears"] = 6
        }
        let opened = try engine.chooseOffseason(.init(seed: expired.nextSeed, state: eligible, decision: .freeAgency, expectedRevision: eligible.revision))
        let market = try XCTUnwrap(opened.snapshot.journeyState?.pendingContractMarket)
        XCTAssertEqual(market.kind, .freeAgency)
        XCTAssertEqual(market.offers.count, 3)
        XCTAssertEqual(Set(market.offers.map(\.teamID)).count, 3)
        XCTAssertTrue(market.offers.contains { $0.teamID == eligible.team.id && $0.preservesTeamLegacy })
        XCTAssertEqual(market.offers.filter { $0.teamID != eligible.team.id }.count, 2)
        XCTAssertTrue(ProContractMarketRules.isNonDominated(market.offers, currentRole: eligible.role))
        XCTAssertTrue(market.offers.allSatisfy { $0.annualSalary % 10_000_000 == 0 && $0.years <= 4 })
        XCTAssertEqual(opened.nextSeed, expired.nextSeed)
    }

    func testFreeAgencyFactoryKeepsEveryCatalogRoleAndLateBandValid() throws {
        let roles: [ProRole] = [.starter, .longRelief, .setup, .closer]
        let levels: [ProLevel] = [.minor, .major]
        for team in ProCareerEngine.proTeams {
            for role in roles {
                for level in levels {
                    for score in [0, 20, 45, 65, 90, 100] {
                        for forSeason in [1, 10, 19, 20] {
                            let marketID = "factory:\(team.id):\(role.rawValue):\(level.rawValue):\(score):\(forSeason)"
                            let market = try XCTUnwrap(ProContractMarketRules.makeFreeAgencyMarket(
                                careerID: marketID,
                                currentTeam: team,
                                pitcher: .init(id: "factory", name: "Factory", stuff: 65, command: 62, movement: 61, stamina: 64),
                                level: level,
                                role: role,
                                previousStats: .init(season: max(1, forSeason - 1), teamID: team.id, inningsOuts: 180, strikeouts: 120, walks: 30, runsAllowed: 55, saves: role == .closer ? 18 : 0),
                                marketScore: score,
                                fanSupport: 50,
                                forSeason: forSeason,
                                generatedAtRevision: 7,
                                maximumCareerSeasons: 20
                            ))
                            XCTAssertTrue(ProContractMarketRules.isValid(market: market, currentTeamID: team.id, currentRole: role, marketScore: score))
                            let expectedMarketID = "market:\(marketID):\(forSeason):free_agency"
                            let rankedCandidates = ProCareerEngine.proTeams
                                .filter { $0.id != team.id }
                                .sorted { lhs, rhs in
                                    let left = Int64(lhs.demand) * 1_000 + Int64(StableHash.fnv1a64Value("\(expectedMarketID)|\(lhs.id)|candidate") % 1_000)
                                    let right = Int64(rhs.demand) * 1_000 + Int64(StableHash.fnv1a64Value("\(expectedMarketID)|\(rhs.id)|candidate") % 1_000)
                                    return left == right ? lhs.id < rhs.id : left > right
                                }
                            let expectedSlots = Array(rankedCandidates.prefix(2)).sorted { lhs, rhs in
                                let left = ProContractMarketRules.teamOutlookSignal(teamID: lhs.id, forSeason: forSeason, demand: lhs.demand)
                                let right = ProContractMarketRules.teamOutlookSignal(teamID: rhs.id, forSeason: forSeason, demand: rhs.demand)
                                return left == right ? lhs.id < rhs.id : left > right
                            }
                            XCTAssertEqual(market.offers.map(\.teamID), [team.id, expectedSlots[0].id, expectedSlots[1].id])
                            let regular = [
                                [90, 95, 100].contains(where: { ProContractMarketRules.annualSalary(marketScore: score, marketID: market.id, teamID: market.offers[0].teamID, contractKind: .freeAgent, multiplierNumerator: $0) == market.offers[0].annualSalary }),
                                [105, 110, 115].contains(where: { ProContractMarketRules.annualSalary(marketScore: score, marketID: market.id, teamID: market.offers[1].teamID, contractKind: .freeAgent, multiplierNumerator: $0) == market.offers[1].annualSalary }),
                                [80, 85, 90, 95].contains(where: { ProContractMarketRules.annualSalary(marketScore: score, marketID: market.id, teamID: market.offers[2].teamID, contractKind: .freeAgent, multiplierNumerator: $0) == market.offers[2].annualSalary }),
                            ].allSatisfy { $0 }
                            let remaining = 20 - forSeason + 1
                            let canonical = market.offers[0].years == min(4, remaining)
                                && market.offers[1].years == min(2, remaining)
                                && market.offers[2].years == 1
                                && market.offers[0].annualSalary == ProContractMarketRules.canonicalFallbackSalary(marketScore: score, multiplierNumerator: 100)
                                && market.offers[1].annualSalary == ProContractMarketRules.canonicalFallbackSalary(marketScore: score, multiplierNumerator: 115)
                                && market.offers[2].annualSalary == ProContractMarketRules.canonicalFallbackSalary(marketScore: score, multiplierNumerator: 85)
                            XCTAssertTrue(regular || canonical, "FA salary tuple must be regular or exact canonical fallback")
                            let repeated = try XCTUnwrap(ProContractMarketRules.makeFreeAgencyMarket(
                                careerID: marketID,
                                currentTeam: team,
                                pitcher: .init(id: "factory", name: "Factory", stuff: 65, command: 62, movement: 61, stamina: 64),
                                level: level,
                                role: role,
                                previousStats: .init(season: max(1, forSeason - 1), teamID: team.id, inningsOuts: 180, strikeouts: 120, walks: 30, runsAllowed: 55, saves: role == .closer ? 18 : 0),
                                marketScore: score,
                                fanSupport: 50,
                                forSeason: forSeason,
                                generatedAtRevision: 7,
                                maximumCareerSeasons: 20
                            ))
                            XCTAssertEqual(repeated, market)
                        }
                    }
                }
            }
        }
    }

    func testLateCareerMarketCapsEveryOfferToRemainingPlayableSeason() throws {
        let expired = try expiredOffseason(seed: "310303")
        let late = try unsignedSnapshot(expired.snapshot) { object in
            object["season"] = 20
            object["serviceYears"] = 6
            var contract = try XCTUnwrap(object["contract"] as? [String: Any])
            contract["yearsRemaining"] = 0
            object["contract"] = contract
        }
        // A season-20 state has no next playable season and must not save a market.
        XCTAssertEqual(errorCode {
            _ = try engine.chooseOffseason(.init(seed: expired.nextSeed, state: late, decision: .freeAgency, expectedRevision: late.revision))
        }, "invalid_transition")
    }

    func testActiveContractContinueAndMilitaryCreateOnlyTransitionUntilInvestment() throws {
        let started = try engine.start(startParams(seed: "310304"))
        let accepted = try acceptRookie(started, ambition: .recordBook)
        let offseason = try acknowledgedAfterOneSeason(accepted)
        let continued = try engine.chooseOffseason(.init(seed: offseason.nextSeed, state: offseason.snapshot, decision: .continueCareer, expectedRevision: offseason.snapshot.revision))
        XCTAssertEqual(continued.snapshot.phase, .offseasonInvestment)
        XCTAssertEqual(continued.snapshot.season, offseason.snapshot.season)
        XCTAssertEqual(continued.snapshot.age, offseason.snapshot.age)
        XCTAssertEqual(continued.snapshot.journeyState?.offseasonTransition?.nextSeason, offseason.snapshot.season + 1)
        XCTAssertEqual(continued.snapshot.journeyState?.lastSettlement?.season, offseason.snapshot.season)

        let next = try engine.chooseInvestment(.init(seed: continued.nextSeed, state: continued.snapshot, expectedRevision: continued.snapshot.revision, investment: .none))
        XCTAssertEqual(next.snapshot.phase, .weeklyPlan)
        XCTAssertEqual(next.snapshot.season, offseason.snapshot.season + 1)
        XCTAssertEqual(next.snapshot.age, offseason.snapshot.age + 1)
        XCTAssertNil(next.snapshot.journeyState?.offseasonTransition)

        let militaryState = try acknowledgedAfterOneSeason(accepted)
        let military = try engine.chooseOffseason(.init(seed: militaryState.nextSeed, state: militaryState.snapshot, decision: .militaryService, expectedRevision: militaryState.snapshot.revision))
        XCTAssertEqual(military.snapshot.phase, .offseasonInvestment)
        XCTAssertTrue(military.snapshot.militaryCompleted)
        XCTAssertEqual(military.snapshot.journeyState?.reputation.fanSupport, (militaryState.snapshot.journeyState?.reputation.fanSupport ?? 0) - 3)
        XCTAssertEqual(military.snapshot.contract?.yearsRemaining, militaryState.snapshot.contract?.yearsRemaining)
    }

    func testExpiredContractRoutesRenewalAndMilitaryToQualificationMarketWithoutAdvancing() throws {
        let expired = try expiredOffseason(seed: "310305")
        XCTAssertEqual(expired.snapshot.contract?.yearsRemaining, 0)
        let renewal = try engine.chooseOffseason(.init(seed: expired.nextSeed, state: expired.snapshot, decision: .continueCareer, expectedRevision: expired.snapshot.revision))
        XCTAssertEqual(renewal.snapshot.phase, .contractOffer)
        XCTAssertEqual(renewal.snapshot.season, expired.snapshot.season)
        XCTAssertEqual(renewal.snapshot.age, expired.snapshot.age)
        XCTAssertEqual(renewal.snapshot.journeyState?.offseasonTransition?.route, .renewalMarket)

        let military = try engine.chooseOffseason(.init(seed: expired.nextSeed, state: expired.snapshot, decision: .militaryService, expectedRevision: expired.snapshot.revision))
        XCTAssertEqual(military.snapshot.phase, .contractOffer)
        XCTAssertEqual(military.snapshot.journeyState?.offseasonTransition?.route, .renewalMarket)
        XCTAssertTrue(military.snapshot.militaryCompleted)
        XCTAssertEqual(military.snapshot.season, expired.snapshot.season)
        XCTAssertEqual(military.snapshot.journeyState?.lastSettlement?.season, expired.snapshot.season)
    }

    func testFreeAgencyAndExpiredOrActiveRejectionsUseStableEligibilityRules() throws {
        let active = try acknowledgedAfterOneSeason(acceptRookie(try engine.start(startParams(seed: "310306")), ambition: .recordBook))
        XCTAssertEqual(errorCode {
            _ = try engine.chooseOffseason(.init(seed: active.nextSeed, state: active.snapshot, decision: .freeAgency, expectedRevision: active.snapshot.revision))
        }, "fa_ineligible")
        let activeWithSixServiceYears = try unsignedSnapshot(active.snapshot) { object in
            object["serviceYears"] = 6
        }
        XCTAssertNil(ProContractMarketRules.freeAgencyMarket(state: activeWithSixServiceYears))
        let expired = try expiredOffseason(seed: "310307")
        XCTAssertEqual(errorCode {
            _ = try engine.chooseOffseason(.init(seed: expired.nextSeed, state: expired.snapshot, decision: .freeAgency, expectedRevision: expired.snapshot.revision))
        }, "fa_ineligible")
        XCTAssertNil(ProContractMarketRules.freeAgencyMarket(state: expired.snapshot))
        let majorFiveYears = try unsignedSnapshot(expired.snapshot) { object in
            object["level"] = ProLevel.major.rawValue
            object["serviceYears"] = 5
        }
        XCTAssertEqual(errorCode {
            _ = try engine.chooseOffseason(.init(seed: expired.nextSeed, state: majorFiveYears, decision: .freeAgency, expectedRevision: majorFiveYears.revision))
        }, "fa_ineligible")
        XCTAssertNil(ProContractMarketRules.freeAgencyMarket(state: majorFiveYears))
        let eligible = try unsignedSnapshot(expired.snapshot) { object in
            object["serviceYears"] = 6
        }
        XCTAssertNotNil(ProContractMarketRules.freeAgencyMarket(state: eligible))
        XCTAssertEqual(errorCode {
            _ = try engine.chooseOffseason(.init(seed: expired.nextSeed, state: expired.snapshot, decision: .continueCareer, expectedRevision: nil))
        }, "stale_revision")
    }

    func testStrictMarketValidatorRejectsRepairsMixedTuplesInvalidOutlookAndIDs() throws {
        let team = ProCareerEngine.proTeams[0]
        let pitcher = PitcherSnapshot(id: "validator", name: "Validator", stuff: 65, command: 62, movement: 61, stamina: 64)
        let previousStats = ProSeasonStats(season: 19, teamID: team.id, inningsOuts: 360, strikeouts: 140, walks: 30, runsAllowed: 60)
        let renewal = try XCTUnwrap(ProContractMarketRules.makeRenewalMarket(
            careerID: "validator-renewal",
            team: team,
            pitcher: pitcher,
            level: .major,
            role: .starter,
            previousStats: previousStats,
            marketScore: 0,
            forSeason: 20,
            generatedAtRevision: 7,
            maximumCareerSeasons: 20
        ))
        XCTAssertTrue(ProContractMarketRules.isValid(market: renewal, currentTeamID: team.id, currentRole: .starter, marketScore: 0))
        let long = try XCTUnwrap(renewal.offers.first)
        let prove = try XCTUnwrap(renewal.offers.last)

        let arbitraryRepair = ProContractMarket(
            id: renewal.id,
            kind: renewal.kind,
            forSeason: renewal.forSeason,
            generatedAtRevision: renewal.generatedAtRevision,
            offers: [replacing(long, annualSalary: long.annualSalary + 10_000_000), prove]
        )
        XCTAssertFalse(ProContractMarketRules.isValid(market: arbitraryRepair, currentTeamID: team.id, currentRole: .starter, marketScore: 0))

        let mixedTuple = ProContractMarket(
            id: renewal.id,
            kind: renewal.kind,
            forSeason: renewal.forSeason,
            generatedAtRevision: renewal.generatedAtRevision,
            offers: [long, replacing(prove, annualSalary: ProContractMarketRules.canonicalFallbackSalary(marketScore: 0, multiplierNumerator: 90))]
        )
        XCTAssertFalse(ProContractMarketRules.isValid(market: mixedTuple, currentTeamID: team.id, currentRole: .starter, marketScore: 0))

        let invalidID = ProContractMarket(
            id: renewal.id,
            kind: renewal.kind,
            forSeason: renewal.forSeason,
            generatedAtRevision: renewal.generatedAtRevision,
            offers: [replacing(long, id: "offer:malformed"), prove]
        )
        XCTAssertFalse(ProContractMarketRules.isValid(market: invalidID, currentTeamID: team.id, currentRole: .starter, marketScore: 0))

        let freeAgency = try XCTUnwrap(ProContractMarketRules.makeFreeAgencyMarket(
            careerID: "validator-fa",
            currentTeam: team,
            pitcher: pitcher,
            level: .major,
            role: .starter,
            previousStats: previousStats,
            marketScore: 0,
            fanSupport: 50,
            forSeason: 20,
            generatedAtRevision: 7,
            maximumCareerSeasons: 20
        ))
        let challenge = freeAgency.offers[1]
        let accessibleContender = ProContractMarket(
            id: freeAgency.id,
            kind: freeAgency.kind,
            forSeason: freeAgency.forSeason,
            generatedAtRevision: freeAgency.generatedAtRevision,
            offers: [freeAgency.offers[0], replacing(challenge, expectation: .init(kind: challenge.expectation.kind, target: challenge.expectation.target, difficulty: .accessible)), freeAgency.offers[2]]
        )
        XCTAssertFalse(ProContractMarketRules.isValid(market: accessibleContender, currentTeamID: team.id, currentRole: .starter, marketScore: 0))
    }

    func testTeamSignalCanSwapExternalSlotsWithoutResamplingCandidateSet() throws {
        let currentTeam = ProCareerEngine.proTeams[0]
        let pitcher = PitcherSnapshot(id: "signal", name: "Signal", stuff: 65, command: 62, movement: 61, stamina: 64)
        let previousStats = ProSeasonStats(season: 1, teamID: currentTeam.id, inningsOuts: 180, strikeouts: 120, walks: 30, runsAllowed: 55)
        var slotOrders = Set<String>()
        var candidateSets = Set<String>()
        for season in 1...20 {
            let market = try XCTUnwrap(ProContractMarketRules.makeFreeAgencyMarket(
                careerID: "signal-career",
                currentTeam: currentTeam,
                pitcher: pitcher,
                level: .major,
                role: .longRelief,
                previousStats: previousStats,
                marketScore: 65,
                fanSupport: 50,
                forSeason: season,
                generatedAtRevision: 7,
                maximumCareerSeasons: 20
            ))
            let external = market.offers.dropFirst().map(\.teamID)
            slotOrders.insert(external.joined(separator: ","))
            candidateSets.insert(external.sorted().joined(separator: ","))
        }
        XCTAssertGreaterThan(slotOrders.count, 1, "teamID|forSeason+demand signal must affect slot assignment")
        XCTAssertEqual(candidateSets.count, 1, "slot assignment must not resample the fixed candidate set")
    }

    func testProjectedPitcherUsesEffectiveAgeAtThirtyThreeBoundary() {
        let pitcher = PitcherSnapshot(id: "age", name: "Age", stuff: 60, command: 55, movement: 58, stamina: 57)
        XCTAssertEqual(ProContractMarketRules.projectedPitcher(for: pitcher, effectiveAge: 32), pitcher)
        let projected = ProContractMarketRules.projectedPitcher(for: pitcher, effectiveAge: 33)
        XCTAssertEqual(projected.stuff, 59)
        XCTAssertEqual(projected.movement, 57)
        XCTAssertEqual(projected.command, pitcher.command)
        XCTAssertEqual(projected.stamina, pitcher.stamina)
    }

    func testMarketScoreUsesLatestCurrentTeamStatsWhenCareerStatsAreMixed() throws {
        let expired = try expiredOffseason(seed: "310311")
        let currentTeam = expired.snapshot.team.id
        let oldTeam = try XCTUnwrap(ProCareerEngine.proTeams.first { $0.id != currentTeam })
        let currentStats = ProSeasonStats(season: 2, teamID: currentTeam, inningsOuts: 120, strikeouts: 30, walks: 25, runsAllowed: 90)
        let oldTeamStats = ProSeasonStats(season: 99, teamID: oldTeam.id, inningsOuts: 1_000, strikeouts: 400, walks: 1, runsAllowed: 10)
        let mixed = try unsignedSnapshot(expired.snapshot) { object in
            object["currentStats"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ProSeasonStats(season: expired.snapshot.season, teamID: currentTeam)))
            object["careerStats"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode([oldTeamStats, currentStats]))
        }
        let currentOnly = try unsignedSnapshot(expired.snapshot) { object in
            object["currentStats"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ProSeasonStats(season: expired.snapshot.season, teamID: currentTeam)))
            object["careerStats"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode([currentStats]))
        }
        XCTAssertEqual(
            ProContractMarketRules.marketScore(state: mixed),
            ProContractMarketRules.marketScore(state: currentOnly)
        )
    }

    func testNonRookieTransferPreservesOldStatsCreatesZeroRowAndAcceptsExactlyOnce() throws {
        let expired = try expiredOffseason(seed: "310308")
        let eligible = try unsignedSnapshot(expired.snapshot) { object in object["serviceYears"] = 6 }
        let opened = try engine.chooseOffseason(.init(seed: expired.nextSeed, state: eligible, decision: .freeAgency, expectedRevision: eligible.revision))
        let market = try XCTUnwrap(opened.snapshot.journeyState?.pendingContractMarket)
        let oldTeam = opened.snapshot.team.id
        let offer = try XCTUnwrap(market.offers.first { $0.teamID != oldTeam })
        let accepted = try engine.acceptContract(.init(seed: opened.nextSeed, state: opened.snapshot, expectedRevision: opened.snapshot.revision, marketID: market.id, offerID: offer.id, ambition: .enduringPro))
        XCTAssertEqual(accepted.snapshot.phase, .offseasonInvestment)
        XCTAssertEqual(accepted.snapshot.season, opened.snapshot.season)
        XCTAssertEqual(accepted.snapshot.team.id, offer.teamID)
        XCTAssertEqual(accepted.snapshot.currentStats.teamID, oldTeam)
        XCTAssertEqual(accepted.snapshot.journeyState?.reputation.fanSupport, (opened.snapshot.journeyState?.reputation.fanSupport ?? 0) - 3)
        XCTAssertEqual(accepted.snapshot.journeyState?.teamRecords.filter { $0.teamID == offer.teamID }.count, 1)
        XCTAssertEqual(accepted.snapshot.journeyState?.teamRecords.first { $0.teamID == offer.teamID }?.completedSeasons, 0)
        XCTAssertTrue(accepted.snapshot.careerStats.allSatisfy { $0.teamID == oldTeam })
        XCTAssertNil(accepted.snapshot.journeyState?.pendingContractMarket)
        XCTAssertEqual(errorCode {
            _ = try engine.acceptContract(.init(seed: accepted.nextSeed, state: accepted.snapshot, expectedRevision: accepted.snapshot.revision, marketID: market.id, offerID: offer.id, ambition: .enduringPro))
        }, "stale_market")
        let next = try engine.chooseInvestment(.init(seed: accepted.nextSeed, state: accepted.snapshot, expectedRevision: accepted.snapshot.revision, investment: .none))
        XCTAssertEqual(next.snapshot.currentStats.teamID, offer.teamID)
        XCTAssertEqual(next.snapshot.season, opened.snapshot.season + 1)
    }

    func testNonRookieAmbitionRetainsReplacesAndAllowsNilOnlyAfterAllComplete() throws {
        let expired = try expiredOffseason(seed: "310309")
        let opened = try engine.chooseOffseason(.init(seed: expired.nextSeed, state: expired.snapshot, decision: .continueCareer, expectedRevision: expired.snapshot.revision))
        let market = try XCTUnwrap(opened.snapshot.journeyState?.pendingContractMarket)
        let offer = try XCTUnwrap(market.offers.first)
        let retained = try engine.acceptContract(.init(seed: opened.nextSeed, state: opened.snapshot, expectedRevision: opened.snapshot.revision, marketID: market.id, offerID: offer.id, ambition: .recordBook))
        XCTAssertEqual(retained.snapshot.journeyState?.activeGoal?.id, expired.snapshot.journeyState?.activeGoal?.id)

        let replacementBase = try unsignedSnapshot(opened.snapshot) { object in
            var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
            journey["pendingContractMarket"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(market))
            object["journeyState"] = journey
        }
        // Re-open from the same state with a different ambition; the old active goal closes at N.
        let replaced = try engine.acceptContract(.init(seed: opened.nextSeed, state: replacementBase, expectedRevision: replacementBase.revision, marketID: market.id, offerID: offer.id, ambition: .enduringPro))
        let history = try XCTUnwrap(replaced.snapshot.journeyState?.goalHistory.first)
        XCTAssertEqual(history.outcome, .replaced)
        XCTAssertEqual(history.endedSeason, replacementBase.season)
        XCTAssertEqual(replaced.snapshot.journeyState?.activeGoal?.ambition, .enduringPro)

        let allComplete = try unsignedSnapshot(expired.snapshot) { object in
            var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
            let goals = ProCareerAmbition.allCases.map { ambition in
                ProCareerGoalRecord(
                    id: ProCareerGoalRules.goalID(
                        careerID: expired.snapshot.proCareerID,
                        season: 1,
                        ambition: ambition,
                        anchorTeamID: ambition == .franchiseIcon ? expired.snapshot.team.id : nil
                    ),
                    ambition: ambition,
                    selectedSeason: 1,
                    anchorTeamID: ambition == .franchiseIcon ? expired.snapshot.team.id : nil,
                    completedSeason: 1,
                    endedSeason: 1,
                    outcome: .completed
                )
            }.sorted { $0.id < $1.id }
            journey["goalHistory"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(goals))
            let rewards = ProCareerAmbition.allCases.map { ambition in
                ProCareerRecognition(
                    careerID: expired.snapshot.proCareerID,
                    kind: .milestone,
                    contentID: "pro.ambition.\(ambition.rawValue).completed",
                    season: 1,
                    teamID: expired.snapshot.team.id
                )
            }.sorted(by: ProCareerJourneyRules.recognitionOrder)
            journey["recognitions"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(rewards))
            journey["activeGoal"] = NSNull()
            object["journeyState"] = journey
        }
        let openedAll = try engine.chooseOffseason(.init(seed: expired.nextSeed, state: allComplete, decision: .continueCareer, expectedRevision: allComplete.revision))
        let allMarket = try XCTUnwrap(openedAll.snapshot.journeyState?.pendingContractMarket)
        let nilGoal = try engine.acceptContract(.init(seed: openedAll.nextSeed, state: openedAll.snapshot, expectedRevision: openedAll.snapshot.revision, marketID: allMarket.id, offerID: allMarket.offers[0].id, ambition: nil))
        XCTAssertNil(nilGoal.snapshot.journeyState?.activeGoal)
    }

    func testStoredMarketAndOfferRevisionAreAtomicAndNonRookieSigningBonusIsNil() throws {
        let expired = try expiredOffseason(seed: "310310")
        let opened = try engine.chooseOffseason(.init(seed: expired.nextSeed, state: expired.snapshot, decision: .continueCareer, expectedRevision: expired.snapshot.revision))
        let market = try XCTUnwrap(opened.snapshot.journeyState?.pendingContractMarket)
        let offer = try XCTUnwrap(market.offers.first)
        XCTAssertEqual(errorCode {
            _ = try engine.acceptContract(.init(seed: opened.nextSeed, state: opened.snapshot, expectedRevision: opened.snapshot.revision + 1, marketID: market.id, offerID: offer.id, ambition: .recordBook))
        }, "stale_revision")
        XCTAssertEqual(errorCode {
            _ = try engine.acceptContract(.init(seed: opened.nextSeed, state: opened.snapshot, expectedRevision: opened.snapshot.revision, marketID: "market:stale", offerID: offer.id, ambition: .recordBook))
        }, "stale_market")
        let tampered = try unsignedSnapshot(opened.snapshot) { object in
            var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
            var storedMarket = try XCTUnwrap(journey["pendingContractMarket"] as? [String: Any])
            var offers = try XCTUnwrap(storedMarket["offers"] as? [[String: Any]])
            offers[0]["annualSalary"] = (offers[0]["annualSalary"] as? Int ?? 0) + 10_000_000
            storedMarket["offers"] = offers
            journey["pendingContractMarket"] = storedMarket
            object["journeyState"] = journey
        }
        XCTAssertEqual(errorCode {
            _ = try engine.acceptContract(.init(seed: opened.nextSeed, state: tampered, expectedRevision: tampered.revision, marketID: market.id, offerID: offer.id, ambition: .recordBook))
        }, "invalid_offer")
        let accepted = try engine.acceptContract(.init(seed: opened.nextSeed, state: opened.snapshot, expectedRevision: opened.snapshot.revision, marketID: market.id, offerID: offer.id, ambition: .recordBook))
        XCTAssertNil(accepted.snapshot.journeyState?.contractHistory.last?.signingBonus)
        XCTAssertFalse(accepted.snapshot.journeyState?.finances.transactions.contains { $0.kind == .signingBonus && $0.season == market.forSeason } ?? true)
    }

    private func startParams(seed: String) -> StartProCareerParams {
        .init(seed: seed, identity: .defaultPitcher, pitcher: .init(id: "wave3-pitcher", name: "Wave 3", stuff: 58, command: 55, movement: 56, stamina: 57), draftResult: .init(outcome: .drafted, evaluationScore: 72, projectedRange: "2~3라운드", team: ProCareerEngine.proTeams[0], round: 2, overallPick: 18, signingBonus: 120_000_000, firstSeasonGoal: "2군 선발", summary: "지명"), entitlement: .init(status: .active, source: .development, verifiedAt: "2026-08-15"))
    }

    private func acceptRookie(_ started: ProCareerResult, ambition: ProCareerAmbition) throws -> ProCareerResult {
        let market = try XCTUnwrap(started.snapshot.journeyState?.pendingContractMarket)
        return try engine.acceptContract(.init(seed: started.nextSeed, state: started.snapshot, expectedRevision: started.snapshot.revision, marketID: market.id, offerID: market.offers[0].id, ambition: ambition))
    }

    private func acknowledgedAfterOneSeason(_ current: ProCareerResult) throws -> ProCareerResult {
        let reviewReady = try unsignedSnapshot(current.snapshot) { object in
            object["phase"] = ProCareerPhase.seasonReview.rawValue
            object["currentStats"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ProSeasonStats(season: current.snapshot.season, teamID: current.snapshot.team.id, games: 1, starts: 1, inningsOuts: 3, strikeouts: 1)))
        }
        let reviewed = try engine.reviewSeason(.init(seed: current.nextSeed, state: reviewReady))
        let settlement = try XCTUnwrap(reviewed.snapshot.journeyState?.lastSettlement)
        return try engine.acknowledgeSettlement(.init(seed: reviewed.nextSeed, state: reviewed.snapshot, expectedRevision: reviewed.snapshot.revision, settlementID: settlement.id))
    }

    private func expiredOffseason(seed: String) throws -> ProCareerResult {
        var current = try acceptRookie(try engine.start(startParams(seed: seed)), ambition: .recordBook)
        for season in 1...3 {
            let offseason = try acknowledgedAfterOneSeason(current)
            if season == 3 { return offseason }
            let transition = try engine.chooseOffseason(.init(seed: offseason.nextSeed, state: offseason.snapshot, decision: .continueCareer, expectedRevision: offseason.snapshot.revision))
            current = try engine.chooseInvestment(.init(seed: transition.nextSeed, state: transition.snapshot, expectedRevision: transition.snapshot.revision, investment: .none))
        }
        fatalError("unreachable")
    }

    private func replacing(
        _ offer: ProContractOffer,
        id: String? = nil,
        annualSalary: Int? = nil,
        expectation: ProContractExpectation? = nil
    ) -> ProContractOffer {
        ProContractOffer(
            id: id ?? offer.id,
            teamID: offer.teamID,
            years: offer.years,
            annualSalary: annualSalary ?? offer.annualSalary,
            signingBonus: offer.signingBonus,
            contractKind: offer.contractKind,
            rolePromise: offer.rolePromise,
            outlook: offer.outlook,
            expectation: expectation ?? offer.expectation,
            preservesTeamLegacy: offer.preservesTeamLegacy
        )
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

private extension ProCareerAmbition {
    static var allCases: [ProCareerAmbition] { [.franchiseIcon, .recordBook, .enduringPro] }
}
