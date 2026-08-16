import CryptoKit
import Foundation
import SimulationCore

private let schema = "baseball-pro-career-fixture-v2"
private let sourceRevision = "wave6-swift-semantic-oracle-2026-08-15"
private let defaultOutput = "artifacts/android-compose/fixtures/swift-pro-career-oracle-v2.json"
private let realGoalOrder: [ProCareerAmbition] = [.franchiseIcon, .enduringPro, .recordBook]

private struct FixtureRow {
    let id: String
    let inputCanonical: String
    let outputCanonical: String
    let output: [String: Any]
    let hashReason: String
}

private struct RealJourneyEvidence {
    let final: ProCareerResult
    let trace: [String]
    let selectedAmbitions: [String]
    let selectedOffers: [String]
    let firstRenewalMarket: ProContractMarket?
    let projectionState: ProCareerSnapshot
}

private func sha256(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
}

private func activeEntitlement() -> ProEntitlementSnapshot {
    .init(status: .active, source: .development, verifiedAt: "2026-08-15", offlineValidUntil: "2026-09-15")
}

private func draft(team: DraftTeamSnapshot) -> DraftResultSnapshot {
    .init(
        outcome: .drafted,
        evaluationScore: 72,
        projectedRange: "2~3라운드",
        team: team,
        round: 2,
        overallPick: 18,
        signingBonus: 120_000_000,
        firstSeasonGoal: "2군 선발",
        summary: "지명"
    )
}

private func start(seed: String, sourceFanInterest: Int? = nil, journeyEnabled: Bool = true, presetID: String = "power_prospect") throws -> ProCareerResult {
    let seedValue = UInt64(seed) ?? 0
    let team = ProCareerEngine.proTeams[Int(seedValue % UInt64(ProCareerEngine.proTeams.count))]
    let pitcher = PitcherPresetCatalog.all.first(where: { $0.id == presetID })!.pitcher
    return try ProCareerEngine(journeyEnabled: journeyEnabled).start(.init(
        seed: seed,
        identity: .defaultPitcher,
        pitcher: pitcher,
        draftResult: draft(team: team),
        entitlement: activeEntitlement(),
        sourceFanInterest: sourceFanInterest
    ))
}

private func stableChoice(_ lhs: ProSeasonDecisionChoice, _ rhs: ProSeasonDecisionChoice) -> Bool {
    if lhs.effect.fatigueDelta != rhs.effect.fatigueDelta {
        return lhs.effect.fatigueDelta < rhs.effect.fatigueDelta
    }
    return lhs.id < rhs.id
}

private func strongReport(for state: ProCareerSnapshot) -> ImportantInningReport {
    .init(
        scenarioNumber: state.week,
        pitches: 24,
        strikeouts: 4,
        walks: 0,
        runsAllowed: 0,
        expectedDamage: 420,
        actualDamage: 160,
        recommendationAccepted: 16,
        outs: 3,
        teamRuns: 4,
        scoreDifferentialAtEntry: 2,
        sequenceMasteryCount: 1,
        hits: 0,
        homeRuns: 0
    )
}

private func ordinaryReport(for state: ProCareerSnapshot, salt: Int = 0) -> ImportantInningReport {
    let variation = (state.season + state.week + salt) % 3
    return .init(
        scenarioNumber: state.week,
        pitches: 18 + variation,
        strikeouts: 2 + (variation == 0 ? 1 : 0),
        walks: variation == 2 ? 1 : 0,
        runsAllowed: variation == 2 ? 1 : 0,
        expectedDamage: 380,
        actualDamage: 220 + variation * 20,
        recommendationAccepted: 12,
        outs: 3,
        teamRuns: 2,
        scoreDifferentialAtEntry: 1,
        sequenceMasteryCount: variation == 0 ? 1 : 0,
        hits: variation == 2 ? 1 : 0,
        homeRuns: 0
    )
}

private func playUntilSeasonReview(
    _ initial: ProCareerResult,
    engine: ProCareerEngine,
    report: (ProCareerSnapshot) -> ImportantInningReport,
    trace: inout [String],
    preferMediaChoice: Bool = false
) throws -> ProCareerResult {
    var result = initial
    var steps = 0
    while result.snapshot.phase != .seasonReview {
        steps += 1
        guard steps <= 220 else { throw NSError(domain: "ProFixtureV2", code: 10) }
        let state = result.snapshot
        switch state.phase {
        case .weeklyPlan:
            let plan: ProWeekPlan
            if state.injuryWeeks > 0 || state.fatigue > 72 {
                plan = .recover
            } else if state.managerTrust < 68 {
                plan = .earnTrust
            } else {
                plan = .refineCommand
            }
            result = try engine.planWeek(.init(seed: result.nextSeed, state: state, plan: plan))
            trace.append("plan_week:\(plan.rawValue)")
        case .importantGame:
            result = try engine.resolveImportantGame(.init(seed: result.nextSeed, state: state, report: report(state)))
            trace.append("resolve_important_game")
        case .seasonDecision:
            guard let decision = state.pendingDecision else { throw NSError(domain: "ProFixtureV2", code: 11) }
            let choice: ProSeasonDecisionChoice
            if preferMediaChoice, decision.type == .mediaOpportunity {
                choice = decision.choices.first(where: { $0.id == "media_opportunity.fan_together_shoot" }) ?? decision.choices[0]
            } else {
                choice = decision.choices.min(by: stableChoice)!
            }
            result = try engine.applySeasonDecision(.init(seed: result.nextSeed, state: state, decisionID: decision.id, choiceID: choice.id))
            trace.append("apply_season_decision:\(decision.type.rawValue):\(choice.id)")
        default:
            throw NSError(domain: "ProFixtureV2", code: 12)
        }
    }
    result = try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
    trace.append("review_season:season=\(result.snapshot.season):level=\(result.snapshot.level.rawValue):games=\(result.snapshot.currentStats.games):outs=\(result.snapshot.currentStats.inningsOuts)")
    return result
}

private func accept(
    _ result: ProCareerResult,
    engine: ProCareerEngine,
    ambition: ProCareerAmbition?,
    trace: inout [String],
    selectedOffers: inout [String]
) throws -> ProCareerResult {
    guard let market = result.snapshot.journeyState?.pendingContractMarket,
          let offer = market.offers.first else {
        throw NSError(domain: "ProFixtureV2", code: 20)
    }
    selectedOffers.append(offer.id)
    trace.append("accept_contract:\(market.kind.rawValue):\(offer.id):ambition=\(ambition?.rawValue ?? "nil")")
    return try engine.acceptContract(.init(
        seed: result.nextSeed,
        state: result.snapshot,
        expectedRevision: result.snapshot.revision,
        marketID: market.id,
        offerID: offer.id,
        ambition: ambition
    ))
}

private func nextAmbition(for state: ProCareerSnapshot) -> ProCareerAmbition? {
    let completed = Set(state.journeyState?.goalHistory.filter { $0.outcome == .completed }.map(\.ambition) ?? [])
    return realGoalOrder.first(where: { !completed.contains($0) })
}

private func runRealJourney() throws -> RealJourneyEvidence {
    let engine = ProCareerEngine(journeyEnabled: true)
    var trace: [String] = []
    var selectedAmbitions: [String] = []
    var selectedOffers: [String] = []

    var result = try start(seed: "620050", sourceFanInterest: 30, presetID: "power_prospect")
    trace.append("start:620050:preset=power_prospect")
    let rookieAmbition: ProCareerAmbition = .franchiseIcon
    selectedAmbitions.append(rookieAmbition.rawValue)
    result = try accept(result, engine: engine, ambition: rookieAmbition, trace: &trace, selectedOffers: &selectedOffers)

    var firstRenewalMarket: ProContractMarket?
    var projectionState = result.snapshot
    while result.snapshot.phase != .completed {
        result = try playUntilSeasonReview(result, engine: engine, report: strongReport, trace: &trace)
        if result.snapshot.season == 1 { projectionState = result.snapshot }
        let settlement = try unwrapSettlement(result.snapshot)
        result = try engine.acknowledgeSettlement(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            expectedRevision: result.snapshot.revision,
            settlementID: settlement.id
        ))
        trace.append("acknowledge_settlement:\(settlement.id)")

        if result.snapshot.phase == .retirementDecision {
            guard result.snapshot.season == ProCareerEngine.maximumCareerSeasons else {
                throw NSError(domain: "ProFixtureV2", code: 21)
            }
            result = try engine.chooseOffseason(.init(
                seed: result.nextSeed,
                state: result.snapshot,
                decision: .retire,
                expectedRevision: result.snapshot.revision
            ))
            trace.append("choose_offseason:retire")
            break
        }

        result = try engine.chooseOffseason(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            decision: .continueCareer,
            expectedRevision: result.snapshot.revision
        ))
        trace.append("choose_offseason:continue")

        if let market = result.snapshot.journeyState?.pendingContractMarket {
            if firstRenewalMarket == nil, market.kind == .renewal {
                firstRenewalMarket = market
            }
            let ambition = nextAmbition(for: result.snapshot)
            if let ambition { selectedAmbitions.append(ambition.rawValue) }
            result = try accept(result, engine: engine, ambition: ambition, trace: &trace, selectedOffers: &selectedOffers)
        }

        if result.snapshot.phase == .offseasonInvestment {
            let funds = result.snapshot.journeyState?.finances.availableFunds ?? 0
            let investment: ProOffseasonInvestment = funds >= ProFinanceRules.investmentCost(for: .fanFoundation)
                ? .fanFoundation
                : .none
            result = try engine.chooseInvestment(.init(
                seed: result.nextSeed,
                state: result.snapshot,
                expectedRevision: result.snapshot.revision,
                investment: investment
            ))
            trace.append("choose_investment:\(investment.rawValue)")
        }
    }

    let journey = try unwrapJourney(result.snapshot)
    let preview = ProRetirementRules.preview(for: result.snapshot)
    guard result.snapshot.phase == .completed else { throw NSError(domain: "ProFixtureV2", code: 22) }
    guard result.snapshot.careerStats.count == ProCareerEngine.maximumCareerSeasons else { throw NSError(domain: "ProFixtureV2", code: 23) }
    guard journey.activeGoal == nil else { throw NSError(domain: "ProFixtureV2", code: 24) }
    guard !selectedOffers.isEmpty,
          !selectedAmbitions.isEmpty,
          trace.contains(where: { $0.hasPrefix("plan_week:") }),
          trace.contains(where: { $0 == "resolve_important_game" }),
          trace.contains(where: { $0.hasPrefix("review_season:") }),
          trace.contains(where: { $0.hasPrefix("acknowledge_settlement:") }),
          trace.contains("choose_offseason:retire") else {
        throw NSError(domain: "ProFixtureV2", code: 25)
    }
    guard journey.retirementHonors == preview.honors else { throw NSError(domain: "ProFixtureV2", code: 26) }
    return RealJourneyEvidence(
        final: result,
        trace: trace,
        selectedAmbitions: selectedAmbitions,
        selectedOffers: selectedOffers,
        firstRenewalMarket: firstRenewalMarket,
        projectionState: projectionState
    )
}

private func unwrapJourney(_ state: ProCareerSnapshot) throws -> ProCareerJourneyState {
    guard let journey = state.journeyState else { throw NSError(domain: "ProFixtureV2", code: 30) }
    return journey
}

private func unwrapSettlement(_ state: ProCareerSnapshot) throws -> ProSeasonSettlement {
    guard let settlement = state.journeyState?.lastSettlement else { throw NSError(domain: "ProFixtureV2", code: 31) }
    return settlement
}

private func marketCanonical(_ market: ProContractMarket) -> String {
    func offer(_ value: ProContractOffer) -> String {
        [
            value.id, value.teamID, String(value.years), String(value.annualSalary), value.signingBonus.map(String.init) ?? "-",
            value.contractKind.rawValue, value.rolePromise.rawValue, value.outlook.rawValue,
            value.expectation.kind.rawValue, String(value.expectation.target), value.expectation.difficulty.rawValue,
            value.preservesTeamLegacy ? "1" : "0",
        ].joined(separator: ":")
    }
    return [market.id, market.kind.rawValue, String(market.forSeason), String(market.generatedAtRevision), market.offers.map(offer).joined(separator: ";")].joined(separator: "|")
}

private func row(_ id: String, input: String, output: [String: Any], canonical: String, hashReason: String = "SHA-256(UTF-8(inputCanonical)) and SHA-256(UTF-8(outputCanonical)); public command semantic fields are independently recomputable") -> FixtureRow {
    FixtureRow(id: id, inputCanonical: input, outputCanonical: canonical, output: output, hashReason: hashReason)
}

private func actualErrorID(_ work: () throws -> Void) -> String {
    do {
        try work()
        return "none"
    } catch let SimulationError.invalidProCareer(detail) {
        // These command surfaces already publish stable machine IDs. Preserve the actual ID;
        // do not collapse distinct stale-market, stale-revision, or validation errors.
        return detail
    } catch {
        return String(describing: error)
    }
}

private func commandCounts(_ trace: [String]) -> [String: Int] {
    var counts: [String: Int] = [:]
    for item in trace {
        let command = item.split(separator: ":", maxSplits: 1).first.map(String.init) ?? item
        counts[command, default: 0] += 1
    }
    return counts
}

private func canonicalCommandCounts(_ trace: [String]) -> String {
    let counts = commandCounts(trace)
    return counts.keys.sorted().map { "\($0)=\(counts[$0] ?? 0)" }.joined(separator: ",")
}

private func buildRows() throws -> [FixtureRow] {
    let engine = ProCareerEngine(journeyEnabled: true)
    let real = try runRealJourney()

    let started = try start(seed: "620001", sourceFanInterest: 30)
    var sampleTrace = ["start:620001:preset=power_prospect"]
    var sampleOffers: [String] = []
    let rookieMarket = try XCTMarket(started.snapshot)
    let rookie = try accept(started, engine: engine, ambition: .recordBook, trace: &sampleTrace, selectedOffers: &sampleOffers)
    let rookieOffer = rookieMarket.offers[0]
    let rookieCanonical = [
        "seed=620001", "market=\(rookieMarket.id)", "offer=\(rookieOffer.id)", "team=\(rookieOffer.teamID)",
        "years=\(rookieOffer.years)", "salary=\(rookieOffer.annualSalary)", "bonus=\(rookieOffer.signingBonus ?? 0)",
        "phase=\(rookie.snapshot.phase.rawValue)", "ambition=record_book",
    ].joined(separator: "|")

    var rows: [FixtureRow] = []
    rows.append(row(
        "rookie_contract",
        input: "commands=start(seed=620001,preset=power_prospect)|accept_contract(market=rookie,offer=first,ambition=record_book)",
        output: [
            "nextSeed": rookie.nextSeed,
            "careerID": rookie.snapshot.proCareerID,
            "marketID": rookieMarket.id,
            "offerID": rookieOffer.id,
            "teamID": rookieOffer.teamID,
            "years": rookieOffer.years,
            "annualSalary": rookieOffer.annualSalary,
            "signingBonus": rookieOffer.signingBonus ?? NSNull(),
            "contractKind": rookieOffer.contractKind.rawValue,
            "phase": rookie.snapshot.phase.rawValue,
        ],
        canonical: rookieCanonical
    ))

    let reviewed = try playUntilSeasonReview(
        rookie,
        engine: engine,
        report: { ordinaryReport(for: $0, salt: 1) },
        trace: &sampleTrace
    )
    let settlement = try unwrapSettlement(reviewed.snapshot)
    let settlementCanonical = [
        "id=\(settlement.id)", "season=\(settlement.season)", "team=\(settlement.teamID)",
        "salary=\(settlement.salaryIncome)", "merchandise=\(settlement.merchandiseIncome)",
        "fan=\(settlement.fanBefore)->\(settlement.fanAfter)", "legacy=\(settlement.teamLegacyBefore)->\(settlement.teamLegacyAfter)",
        "hof=\(settlement.hallOfFameBefore)->\(settlement.hallOfFameAfter)", "route=\(settlement.nextRoute.rawValue)",
    ].joined(separator: "|")
    rows.append(row(
        "season_settlement",
        input: "commands=plan_week*,resolve_important_game*,apply_season_decision*,review_season|seed_chain=public_results",
        output: [
            "settlementID": settlement.id,
            "salaryIncome": settlement.salaryIncome,
            "merchandiseIncome": settlement.merchandiseIncome,
            "fanBefore": settlement.fanBefore,
            "fanAfter": settlement.fanAfter,
            "fanDelta": settlement.fanDelta,
            "teamLegacyBefore": settlement.teamLegacyBefore,
            "teamLegacyAfter": settlement.teamLegacyAfter,
            "hallOfFameBefore": settlement.hallOfFameBefore,
            "hallOfFameAfter": settlement.hallOfFameAfter,
            "contractYearsBefore": settlement.contractYearsBefore,
            "contractYearsAfter": settlement.contractYearsAfter,
            "nextRoute": settlement.nextRoute.rawValue,
            "nextSeed": reviewed.nextSeed,
            "fanReasonIDs": settlement.fanReasons.map(\.id).sorted(),
        ],
        canonical: settlementCanonical
    ))

    let acknowledged = try engine.acknowledgeSettlement(.init(seed: reviewed.nextSeed, state: reviewed.snapshot, expectedRevision: reviewed.snapshot.revision, settlementID: settlement.id))
    sampleTrace.append("acknowledge_settlement:\(settlement.id)")
    let transition = try engine.chooseOffseason(.init(seed: acknowledged.nextSeed, state: acknowledged.snapshot, decision: .continueCareer, expectedRevision: acknowledged.snapshot.revision))
    sampleTrace.append("choose_offseason:continue")
    let invested = try engine.chooseInvestment(.init(seed: transition.nextSeed, state: transition.snapshot, expectedRevision: transition.snapshot.revision, investment: .pitchLab, focus: .command))
    sampleTrace.append("choose_investment:pitch_lab")
    guard let investmentTransaction = invested.snapshot.journeyState?.finances.transactions.first(where: { $0.kind == .investment }) else {
        throw NSError(domain: "ProFixtureV2", code: 32)
    }
    let investmentCanonical = [
        "id=\(investmentTransaction.id)", "amount=\(investmentTransaction.amount)",
        "availableFunds=\(invested.snapshot.journeyState!.finances.availableFunds)", "season=\(invested.snapshot.season)",
        "focus=command", "phase=\(invested.snapshot.phase.rawValue)",
    ].joined(separator: "|")
    rows.append(row(
        "investment",
        input: "commands=acknowledge_settlement(season=1)|choose_offseason(continue)|choose_investment(pitch_lab,focus=command)",
        output: [
            "transactionID": investmentTransaction.id,
            "amount": investmentTransaction.amount,
            "availableFunds": invested.snapshot.journeyState!.finances.availableFunds,
            "investmentSeason": invested.snapshot.journeyState!.finances.investmentSeason ?? NSNull(),
            "developmentFocus": invested.snapshot.developmentProgress?.command ?? NSNull(),
            "phase": invested.snapshot.phase.rawValue,
            "nextSeed": invested.nextSeed,
        ],
        canonical: investmentCanonical
    ))

    guard let renewalMarket = real.firstRenewalMarket else {
        throw NSError(domain: "ProFixtureV2", code: 34)
    }
    rows.append(row(
        "renewal_market",
        input: "inputKind=real_command_generated|start(seed=620050,preset=power_prospect,fan=30)|accept_rookie_contract|complete_three_seasons|acknowledge_settlement|choose_offseason(continue)|capture_first_renewal_market",
        output: [
            "inputKind": "real_command_generated",
            "marketID": renewalMarket.id,
            "kind": renewalMarket.kind.rawValue,
            "offerCount": renewalMarket.offers.count,
            "canonicalRows": renewalMarket.offers.map { $0.id + ":" + String($0.years) + ":" + String($0.annualSalary) + ":" + $0.rolePromise.rawValue + ":" + $0.expectation.difficulty.rawValue },
        ],
        canonical: marketCanonical(renewalMarket),
        hashReason: "SHA-256(UTF-8(inputCanonical)) and SHA-256(UTF-8(outputCanonical)); persisted renewal market captured from public command output, not an engine signature"
    ))

    guard let freeAgencyMarket = ProContractMarketRules.makeFreeAgencyMarket(
        careerID: invested.snapshot.proCareerID,
        currentTeam: invested.snapshot.team,
        pitcher: invested.snapshot.pitcher,
        level: invested.snapshot.level,
        role: invested.snapshot.role,
        previousStats: invested.snapshot.currentStats,
        marketScore: 65,
        fanSupport: invested.snapshot.journeyState?.reputation.fanSupport ?? 30,
        forSeason: invested.snapshot.season + 1,
        generatedAtRevision: invested.snapshot.revision,
        maximumCareerSeasons: ProCareerEngine.maximumCareerSeasons
    ) else {
        throw NSError(domain: "ProFixtureV2", code: 35)
    }
    rows.append(row(
        "free_agency_market",
        input: "inputKind=pure_rules_projection|rules=makeFreeAgencyMarket|marketScore=65|fanSupport=derived|forSeason=next",
        output: [
            "inputKind": "pure_rules_projection",
            "marketID": freeAgencyMarket.id,
            "kind": freeAgencyMarket.kind.rawValue,
            "offerCount": freeAgencyMarket.offers.count,
            "teams": freeAgencyMarket.offers.map(\.teamID),
            "canonicalRows": freeAgencyMarket.offers.map { $0.id + ":" + String($0.years) + ":" + String($0.annualSalary) + ":" + $0.rolePromise.rawValue + ":" + $0.outlook.rawValue },
        ],
        canonical: marketCanonical(freeAgencyMarket),
        hashReason: "SHA-256(UTF-8(inputCanonical)) and SHA-256(UTF-8(outputCanonical)); pure rules projection from canonical market inputs, not an engine signature"
    ))

    let mediaStarted = try start(seed: "620010", sourceFanInterest: 30)
    var mediaTrace = ["start:620010:preset=power_prospect"]
    var mediaOffers: [String] = []
    let mediaRookie = try accept(mediaStarted, engine: engine, ambition: .recordBook, trace: &mediaTrace, selectedOffers: &mediaOffers)
    let mediaSeason1 = try playUntilSeasonReview(mediaRookie, engine: engine, report: { ordinaryReport(for: $0, salt: 10) }, trace: &mediaTrace)
    let mediaSettlement1 = try unwrapSettlement(mediaSeason1.snapshot)
    let mediaAcknowledged1 = try engine.acknowledgeSettlement(.init(seed: mediaSeason1.nextSeed, state: mediaSeason1.snapshot, expectedRevision: mediaSeason1.snapshot.revision, settlementID: mediaSettlement1.id))
    mediaTrace.append("acknowledge_settlement:\(mediaSettlement1.id)")
    let mediaTransition = try engine.chooseOffseason(.init(seed: mediaAcknowledged1.nextSeed, state: mediaAcknowledged1.snapshot, decision: .continueCareer, expectedRevision: mediaAcknowledged1.snapshot.revision))
    mediaTrace.append("choose_offseason:continue")
    let mediaInvested = try engine.chooseInvestment(.init(seed: mediaTransition.nextSeed, state: mediaTransition.snapshot, expectedRevision: mediaTransition.snapshot.revision, investment: .fanFoundation))
    mediaTrace.append("choose_investment:fan_foundation")
    let mediaReviewed = try playUntilSeasonReview(mediaInvested, engine: engine, report: { ordinaryReport(for: $0, salt: 11) }, trace: &mediaTrace, preferMediaChoice: true)
    let mediaRecord = mediaReviewed.snapshot.decisionHistory?.last(where: { $0.type == .mediaOpportunity })
    let endorsement = mediaReviewed.snapshot.journeyState?.finances.transactions.last(where: { $0.kind == .endorsement })
    let mediaCanonical = [
        "mediaDecision=\(mediaRecord?.decisionID ?? "none")", "mediaChoice=\(mediaRecord?.choiceID ?? "none")",
        "endorsement=\(endorsement?.id ?? "none")", "amount=\(endorsement?.amount ?? 0)",
        "fan=\(mediaReviewed.snapshot.journeyState?.reputation.fanSupport ?? 0)",
    ].joined(separator: "|")
    rows.append(row(
        "fan_finance_media",
        input: "commands=start(seed=620010)|accept_contract(record_book)|season_1|acknowledge|offseason=continue|investment=fan_foundation|season_2|media_choice=stable_first_if_present",
        output: [
            "mediaObserved": mediaRecord != nil,
            "mediaDecisionID": mediaRecord?.decisionID ?? NSNull(),
            "mediaChoiceID": mediaRecord?.choiceID ?? NSNull(),
            "endorsementTransactionID": endorsement?.id ?? NSNull(),
            "endorsementAmount": endorsement?.amount ?? NSNull(),
            "fanSupport": mediaReviewed.snapshot.journeyState?.reputation.fanSupport ?? NSNull(),
            "communityPoints": mediaReviewed.snapshot.journeyState?.teamRecords.first(where: { $0.teamID == mediaReviewed.snapshot.team.id })?.communityPoints ?? NSNull(),
            "nextSeed": mediaReviewed.nextSeed,
        ],
        canonical: mediaCanonical
    ))

    let projection = ProRetirementRules.preview(for: real.projectionState)
    let projectionRecord = real.projectionState.journeyState?.teamRecords.first(where: { $0.teamID == real.projectionState.team.id })
    let projectionCanonical = [
        "inputKind=pure_rule_projection", "team=\(real.projectionState.team.id)",
        "seasons=\(projectionRecord?.completedSeasons ?? 0)", "legacy=\(projectionRecord.map(ProTeamLegacyRules.score(record:)) ?? 0)",
        "hof=\(projection.finalScore)", "honors=\(projection.honors.map(\.kind.rawValue).joined(separator: ","))",
    ].joined(separator: "|")
    rows.append(row(
        "team_legacy_ambition_honors",
        input: "inputKind=pure_rule_projection|rules=ProRetirementRules.preview|state=real_journey_season_1_review_output",
        output: [
            "inputKind": "pure_rule_projection",
            "teamID": real.projectionState.team.id,
            "teamSeasons": projectionRecord?.completedSeasons ?? NSNull(),
            "teamLegacy": projectionRecord.map(ProTeamLegacyRules.score(record:)) ?? NSNull(),
            "hallOfFameProjection": projection.finalScore,
            "retiredNumberEligible": projection.retiredNumberEligible,
            "clubHallTeamIDs": projection.clubHallTeamIDs,
            "completedAmbitions": projection.completedAmbitions.map(\.rawValue),
            "honorKinds": projection.honors.map(\.kind.rawValue),
        ],
        canonical: projectionCanonical,
        hashReason: "SHA-256(UTF-8(inputCanonical)) and SHA-256(UTF-8(outputCanonical)); pure retirement projection over a real command-produced intermediate state"
    ))

    let finalJourney = try unwrapJourney(real.final.snapshot)
    let finalPreview = ProRetirementRules.preview(for: real.final.snapshot)
    let completedAmbitions = finalJourney.goalHistory.filter { $0.outcome == .completed }.map(\.ambition.rawValue).sorted()
    let honorRows: [[String: Any]] = finalJourney.retirementHonors.map { honor in
        [
            "id": honor.id,
            "kind": honor.kind.rawValue,
            "teamID": honor.teamID ?? NSNull(),
            "referenceID": honor.referenceID ?? NSNull(),
            "value": honor.value ?? NSNull(),
        ]
    }
    let realCanonical = [
        "inputKind=real_command_generated", "commands=\(canonicalCommandCounts(real.trace))",
        "completedSeasons=\(real.final.snapshot.careerStats.count)", "hof=\(finalPreview.finalScore)",
        "team=\(finalPreview.lastTeamSeasons):\(finalPreview.lastTeamLegacy)",
        "ambitions=\(completedAmbitions.joined(separator: ","))",
        "honors=\(finalJourney.retirementHonors.map(\.id).joined(separator: ","))",
    ].joined(separator: "|")
    rows.append(row(
        "real_retirement_command",
        input: "inputKind=real_command_generated|start(seed=620050,preset=power_prospect,fan=30)|accept_contract(ambition=franchise_icon)|repeat(public_weekly_commands,season_review,acknowledge,continue_or_renew,investment_or_skip) until exact_20_seasons|choose_offseason(retire)",
        output: [
            "inputKind": "real_command_generated",
            "actualRetirementCommand": "choose_offseason.retire",
            "retirementMode": "maximum_season_evaluation_horizon",
            "voluntaryRetirement": false,
            "phase": real.final.snapshot.phase.rawValue,
            "completedSeasons": real.final.snapshot.careerStats.count,
            "hallOfFameScore": real.final.snapshot.hallOfFameScore ?? NSNull(),
            "lastTeamSeasons": finalPreview.lastTeamSeasons,
            "lastTeamLegacy": finalPreview.lastTeamLegacy,
            "fanSupport": finalPreview.fanSupport,
            "retiredNumberEligible": finalPreview.retiredNumberEligible,
            "completedAmbitions": completedAmbitions,
            "allThreeAmbitionsCompleted": completedAmbitions.count == 3,
            "honorKinds": finalJourney.retirementHonors.map(\.kind.rawValue),
            "honors": honorRows,
            "selectedAmbitions": real.selectedAmbitions,
            "selectedOffers": real.selectedOffers,
            "commandCounts": commandCounts(real.trace),
            "commandTraceSha256": sha256(real.trace.joined(separator: "\n")),
            "retirementProjectionMatchesCommand": finalJourney.retirementHonors == finalPreview.honors,
        ],
        canonical: realCanonical
    ))

    let legacyEngine = ProCareerEngine()
    let legacyStarted = try start(seed: "620007", journeyEnabled: false)
    let legacySigned = try legacyEngine.signContract(.init(seed: legacyStarted.nextSeed, state: legacyStarted.snapshot))
    var legacyTrace = ["start:620007:legacy", "sign_contract"]
    let legacyReviewReady = try playUntilSeasonReview(legacySigned, engine: legacyEngine, report: { ordinaryReport(for: $0, salt: 7) }, trace: &legacyTrace)
    let migrated = try ProCareerEngine(journeyEnabled: true).migrateJourneyIfSafe(.init(seed: legacyReviewReady.nextSeed, state: legacyReviewReady.snapshot))
    let migration = try unwrapJourney(migrated.snapshot).migration
    let migrationCanonical = [migration.source.rawValue, String(migration.initializedSeason), String(migration.financeStartsSeason), String(migration.unassignedLegacyAwards), migration.financeNoticePending ? "1" : "0", migrated.snapshot.phase.rawValue].joined(separator: "|")
    rows.append(row(
        "legacy_migration",
        input: "commands=legacy_start|legacy_sign_contract|legacy_weekly_play|legacy_review_season|migrateJourneyIfSafe",
        output: [
            "source": migration.source.rawValue,
            "initializedSeason": migration.initializedSeason,
            "financeStartsSeason": migration.financeStartsSeason,
            "unassignedLegacyAwards": migration.unassignedLegacyAwards,
            "financeNoticePending": migration.financeNoticePending,
            "phase": migrated.snapshot.phase.rawValue,
            "salaryTransactions": try unwrapJourney(migrated.snapshot).finances.transactions.filter { $0.kind == .salary }.count,
            "nextSeed": migrated.nextSeed,
        ],
        canonical: migrationCanonical
    ))

    let staleRevisionError = actualErrorID {
        _ = try engine.acceptContract(.init(seed: "620099", state: rookie.snapshot, expectedRevision: rookie.snapshot.revision + 1, marketID: rookieMarket.id, offerID: rookieOffer.id, ambition: .recordBook))
    }
    let invalidOfferStarted = try start(seed: "620002")
    let invalidOfferMarket = try XCTMarket(invalidOfferStarted.snapshot)
    let invalidOfferError = actualErrorID {
        _ = try engine.acceptContract(.init(seed: invalidOfferStarted.nextSeed, state: invalidOfferStarted.snapshot, expectedRevision: invalidOfferStarted.snapshot.revision, marketID: invalidOfferMarket.id, offerID: "offer:not-present", ambition: .recordBook))
    }
    let invalidSettlementError = actualErrorID {
        _ = try engine.acknowledgeSettlement(.init(seed: reviewed.nextSeed, state: reviewed.snapshot, expectedRevision: reviewed.snapshot.revision, settlementID: "settlement:not-present"))
    }
    let commandErrors = [staleRevisionError, invalidOfferError, invalidSettlementError]
    rows.append(row(
        "command_errors",
        input: "commands=accept_contract(stale_revision)|accept_contract(invalid_offer)|acknowledge_settlement(invalid_settlement_id)",
        output: ["errorIDs": commandErrors, "executedCases": ["stale_revision", "invalid_offer", "invalid_settlement"]],
        canonical: commandErrors.joined(separator: "|")
    ))

    let replayCanonical = [
        "rookie.nextSeed=\(rookie.nextSeed)", "reviewed.nextSeed=\(reviewed.nextSeed)", "invested.nextSeed=\(invested.nextSeed)",
        "rookie.phase=\(rookie.snapshot.phase.rawValue)", "settlement.id=\(settlement.id)", "investment.id=\(investmentTransaction.id)",
    ].joined(separator: "|")
    rows.append(row(
        "deterministic_replay_hash",
        input: "replay=seed=620001|commands=accept_contract,weekly_play,review_season,acknowledge,choose_offseason,choose_investment",
        output: [
            "nextSeeds": [rookie.nextSeed, reviewed.nextSeed, invested.nextSeed],
            "semanticReplaySha256": sha256(replayCanonical),
        ],
        canonical: replayCanonical,
        hashReason: "SHA-256 over independently recomputable next-seed and semantic-ID fields; no state signature material is exported"
    ))

    guard rows.count == 11, Set(rows.map(\.id)).count == rows.count else {
        throw NSError(domain: "ProFixtureV2", code: 36)
    }
    return rows.sorted { $0.id < $1.id }
}

private func XCTMarket(_ state: ProCareerSnapshot) throws -> ProContractMarket {
    guard let market = state.journeyState?.pendingContractMarket else {
        throw NSError(domain: "ProFixtureV2", code: 33)
    }
    return market
}

private func writeFixture(to path: String, rows: [FixtureRow]) throws {
    let caseIDs = rows.map(\.id)
    let inputCanonical = [
        "fixture=ProCareerEngine.JourneyWave6",
        "journeyEnabled=true",
        "commands=start,accept_contract,plan_week,resolve_important_game,apply_season_decision,review_season,acknowledge_settlement,choose_offseason,choose_investment,migrateJourneyIfSafe",
        "cases=\(caseIDs.joined(separator: ","))",
        "canonicalFields=semantic-inputs,actual-command-output,stable-error-id",
        "locale=stable_ids_only",
        "timezone=UTC",
    ].joined(separator: "|")
    let outputCanonical = rows.map { "\($0.id)|\($0.outputCanonical)\n" }.joined()
    let cases: [[String: Any]] = rows.map {
        [
            "caseID": $0.id,
            "inputCanonical": $0.inputCanonical,
            "inputSha256": sha256($0.inputCanonical),
            "outputCanonical": $0.outputCanonical,
            "outputSha256": sha256($0.outputCanonical),
            "hashReason": $0.hashReason,
            "output": $0.output,
        ]
    }
    let root: [String: Any] = [
        "fixtureSchema": schema,
        "sourceRuntime": "swift",
        "sourceRevision": sourceRevision,
        "inputSha256": sha256(inputCanonical),
        "outputSha256": sha256(outputCanonical),
        "authorityScope": "swift-journey-semantic-oracle",
        "canonicalization": [
            "inputHash": "SHA-256(UTF-8(inputCanonical))",
            "caseOutputHash": "SHA-256(UTF-8(outputCanonical))",
            "fixtureOutputHash": "SHA-256(concat(caseID|outputCanonical\\n))",
            "independentConsumer": "recompute from semantic inputs and public rules/commands",
        ],
        "input": [
            "fixture": "ProCareerEngine.JourneyWave6",
            "journeyEnabled": true,
            "commandWire": ["start", "accept_contract", "plan_week", "resolve_important_game", "apply_season_decision", "review_season", "acknowledge_settlement", "choose_offseason", "choose_investment", "migrateJourneyIfSafe"],
            "caseOrder": caseIDs,
            "locale": "stable_ids_only",
            "timezone": "UTC",
        ],
        "cases": cases,
    ]
    let data = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys, .prettyPrinted])
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
}

let output = ProcessInfo.processInfo.environment["BASEBALL_PRO_ORACLE_V2_OUTPUT"] ?? defaultOutput
private let rows = try buildRows()
try writeFixture(to: output, rows: rows)
print("swift-pro-career-fixture-v2 rows=\(rows.count) output=\(output)")
