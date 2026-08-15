import Foundation
import SimulationCore

private enum DistributionPolicy: String, CaseIterable, Sendable {
    case salaryFirst = "salary_first"
    case legacyFirst = "legacy_first"
    case roleFirst = "role_first"
    case securityFirst = "security_first"
    case stableRandom = "stable_random"
}

private let ambitionWires: [ProCareerAmbition] = [.franchiseIcon, .recordBook, .enduringPro]

private struct DistributionMetrics: Sendable {
    var careers = 0
    var completedSeasons = 0
    var failedRuns = 0
    var errors: [String] = []
    var negativeFunds = 0
    var duplicateFinance = 0
    var duplicateSalary = 0
    var duplicateSettlement = 0
    var activeExpiredOrMissingContract = 0
    var marketOfferCountMismatch = 0
    var renewalOfferCountMismatch = 0
    var freeAgencyOfferCountMismatch = 0
    var dominatedMarkets = 0
    var renewalMarkets = 0
    var freeAgencyMarkets = 0
    var teamRecordMismatches = 0
    var earlyFan100Careers = 0
    var longCareerDenominator = 0
    var retiredNumbers = 0
    var hallOfFame = 0
    var longCareerRetiredNumbers = 0
    var longCareerHallOfFame = 0
    var ambitionAttempts: [String: Int] = [:]
    var ambitionCompletions: [String: Int] = [:]
    var hallOfFameScoreMin: Int?
    var hallOfFameScoreMax: Int?
    var majorServiceYearsMin: Int?
    var majorServiceYearsMax: Int?
    var careerInningsOutsMin: Int?
    var careerInningsOutsMax: Int?
    var careerStrikeoutsMin: Int?
    var careerStrikeoutsMax: Int?
    var careerAwardCountMin: Int?
    var careerAwardCountMax: Int?
    var lastTeamSeasonsMin: Int?
    var lastTeamSeasonsMax: Int?
    var teamChangeCareers = 0
    var finalRoles: [String: Int] = [:]
    var contractSelections: [String: Int] = [:]
    var selectedOfferCount = 0
    var selectedSalaryTotal: Int64 = 0
    var selectedYearsTotal = 0
    var selectedRoleValueTotal = 0
    var selectedLegacyCount = 0
    var selectedAccessibleCount = 0
    var selectedOfferSignatures: [String: Int] = [:]

    mutating func merge(_ other: DistributionMetrics) {
        careers += other.careers
        completedSeasons += other.completedSeasons
        failedRuns += other.failedRuns
        errors.append(contentsOf: other.errors)
        negativeFunds += other.negativeFunds
        duplicateFinance += other.duplicateFinance
        duplicateSalary += other.duplicateSalary
        duplicateSettlement += other.duplicateSettlement
        activeExpiredOrMissingContract += other.activeExpiredOrMissingContract
        marketOfferCountMismatch += other.marketOfferCountMismatch
        renewalOfferCountMismatch += other.renewalOfferCountMismatch
        freeAgencyOfferCountMismatch += other.freeAgencyOfferCountMismatch
        dominatedMarkets += other.dominatedMarkets
        renewalMarkets += other.renewalMarkets
        freeAgencyMarkets += other.freeAgencyMarkets
        teamRecordMismatches += other.teamRecordMismatches
        earlyFan100Careers += other.earlyFan100Careers
        longCareerDenominator += other.longCareerDenominator
        retiredNumbers += other.retiredNumbers
        hallOfFame += other.hallOfFame
        longCareerRetiredNumbers += other.longCareerRetiredNumbers
        longCareerHallOfFame += other.longCareerHallOfFame
        for (key, value) in other.ambitionAttempts { ambitionAttempts[key, default: 0] += value }
        for (key, value) in other.ambitionCompletions { ambitionCompletions[key, default: 0] += value }
        hallOfFameScoreMin = minOptional(hallOfFameScoreMin, other.hallOfFameScoreMin)
        hallOfFameScoreMax = maxOptional(hallOfFameScoreMax, other.hallOfFameScoreMax)
        majorServiceYearsMin = minOptional(majorServiceYearsMin, other.majorServiceYearsMin)
        majorServiceYearsMax = maxOptional(majorServiceYearsMax, other.majorServiceYearsMax)
        careerInningsOutsMin = minOptional(careerInningsOutsMin, other.careerInningsOutsMin)
        careerInningsOutsMax = maxOptional(careerInningsOutsMax, other.careerInningsOutsMax)
        careerStrikeoutsMin = minOptional(careerStrikeoutsMin, other.careerStrikeoutsMin)
        careerStrikeoutsMax = maxOptional(careerStrikeoutsMax, other.careerStrikeoutsMax)
        careerAwardCountMin = minOptional(careerAwardCountMin, other.careerAwardCountMin)
        careerAwardCountMax = maxOptional(careerAwardCountMax, other.careerAwardCountMax)
        lastTeamSeasonsMin = minOptional(lastTeamSeasonsMin, other.lastTeamSeasonsMin)
        lastTeamSeasonsMax = maxOptional(lastTeamSeasonsMax, other.lastTeamSeasonsMax)
        teamChangeCareers += other.teamChangeCareers
        for (key, value) in other.finalRoles { finalRoles[key, default: 0] += value }
        for (key, value) in other.contractSelections { contractSelections[key, default: 0] += value }
        selectedOfferCount += other.selectedOfferCount
        selectedSalaryTotal += other.selectedSalaryTotal
        selectedYearsTotal += other.selectedYearsTotal
        selectedRoleValueTotal += other.selectedRoleValueTotal
        selectedLegacyCount += other.selectedLegacyCount
        selectedAccessibleCount += other.selectedAccessibleCount
        for (key, value) in other.selectedOfferSignatures { selectedOfferSignatures[key, default: 0] += value }
    }
}

private func minOptional(_ lhs: Int?, _ rhs: Int?) -> Int? {
    switch (lhs, rhs) {
    case let (left?, right?): return min(left, right)
    case let (left?, nil): return left
    case let (nil, right?): return right
    case (nil, nil): return nil
    }
}

private func maxOptional(_ lhs: Int?, _ rhs: Int?) -> Int? {
    switch (lhs, rhs) {
    case let (left?, right?): return max(left, right)
    case let (left?, nil): return left
    case let (nil, right?): return right
    case (nil, nil): return nil
    }
}

private struct CareerRun: Sendable {
    let seed: Int
    let policy: DistributionPolicy
    let metrics: DistributionMetrics
    let selectionSequence: [String]
}

private enum RunnerError: Error, CustomStringConvertible {
    case invalidArgument(String)

    var description: String {
        switch self {
        case let .invalidArgument(value): return value
        }
    }
}

private func activeEntitlement() -> ProEntitlementSnapshot {
    .init(status: .active, source: .development, verifiedAt: "2026-08-15", offlineValidUntil: "2026-09-15")
}

private func stableHashValue(_ value: String) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in value.utf8 {
        hash ^= UInt64(byte)
        hash &*= 0x100000001b3
    }
    return hash
}

private func draft(team: DraftTeamSnapshot, seed: Int) -> DraftResultSnapshot {
    let round = seed % 4 + 1
    let evaluation = 55 + Int(stableHashValue("draft|\(seed)") % 26)
    let bonus = ProContractMarketRules.rookieAnnualSalary(forDraftRound: round)! + 60_000_000
    return .init(
        outcome: .drafted,
        evaluationScore: evaluation,
        projectedRange: "\(round)라운드",
        team: team,
        round: round,
        overallPick: 1 + seed % 60,
        signingBonus: bonus,
        firstSeasonGoal: "1군 진입",
        summary: "지명"
    )
}

private func start(seed: Int) throws -> ProCareerResult {
    let team = ProCareerEngine.proTeams[seed % ProCareerEngine.proTeams.count]
    let presets = PitcherPresetCatalog.all
    let preset = presets[seed % presets.count]
    let fanInterest = 5 + Int(stableHashValue("fan|\(seed)") % 46)
    return try ProCareerEngine(journeyEnabled: true).start(.init(
        seed: String(seed),
        identity: .defaultPitcher,
        pitcher: preset.pitcher,
        draftResult: draft(team: team, seed: seed),
        entitlement: activeEntitlement(),
        sourceFanInterest: fanInterest
    ))
}

private func report(for state: ProCareerSnapshot, seed: Int) -> ImportantInningReport {
    let value = stableHashValue("important|\(seed)|\(state.season)|\(state.week)")
    let variation = Int(value % 5)
    let runsAllowed = [0, 1, 2, 3, 1][variation]
    let walks = [0, 1, 1, 2, 0][variation]
    let strikeouts = [3, 2, 1, 0, 2][variation]
    let teamRuns = [2, 2, 1, 0, 3][variation]
    return .init(
        scenarioNumber: state.week,
        pitches: 18 + Int(value % 8),
        strikeouts: strikeouts,
        walks: walks,
        runsAllowed: runsAllowed,
        expectedDamage: 380,
        actualDamage: 240 + runsAllowed * 90 + walks * 25,
        recommendationAccepted: [12, 12, 6, 0, 12][variation],
        outs: 3,
        teamRuns: teamRuns,
        scoreDifferentialAtEntry: max(-3, min(3, teamRuns - runsAllowed)),
        sequenceMasteryCount: variation == 0 ? 1 : 0,
        hits: variation == 3 ? 2 : variation == 2 ? 1 : 0,
        homeRuns: variation == 3 ? 1 : 0
    )
}

private func weekPlan(for state: ProCareerSnapshot, seed: Int) -> ProWeekPlan {
    if state.injuryWeeks > 0 { return .recover }
    if state.managerTrust < 52 { return .earnTrust }
    let options: [ProWeekPlan] = [.developStuff, .developMovement, .refineCommand, .buildStamina, .recover]
    return options[Int(stableHashValue("plan|\(seed)|\(state.season)|\(state.week)") % UInt64(options.count))]
}

private func decisionChoice(
    _ decision: ProSeasonDecision,
    state: ProCareerSnapshot,
    seed: Int
) -> ProSeasonDecisionChoice? {
    guard !decision.choices.isEmpty else { return nil }
    let index = Int(stableHashValue("decision|\(seed)|\(state.season)|\(decision.id)") % UInt64(decision.choices.count))
    return decision.choices[index]
}

private func rookieAmbition(for seed: Int) -> ProCareerAmbition {
    let remainder = seed % ambitionWires.count
    let nonnegativeIndex = remainder >= 0 ? remainder : remainder + ambitionWires.count
    return ambitionWires[nonnegativeIndex]
}

private func ambition(for state: ProCareerSnapshot, rookieAmbition: ProCareerAmbition) -> ProCareerAmbition? {
    if let activeGoal = state.journeyState?.activeGoal {
        guard activeGoal.completedSeason != nil else { return activeGoal.ambition }

        let completed = Set(
            (state.journeyState?.goalHistory ?? [])
                .filter { $0.outcome == .completed }
                .map(\.ambition)
                + [activeGoal.ambition]
        )
        guard completed.count < ambitionWires.count else { return nil }
        guard let rookieIndex = ambitionWires.firstIndex(of: rookieAmbition) else { return nil }
        for offset in 1...ambitionWires.count {
            let candidate = ambitionWires[(rookieIndex + offset) % ambitionWires.count]
            if !completed.contains(candidate) { return candidate }
        }
        return nil
    }

    // A nil active goal is a valid persisted state only after all three ambitions are closed.
    // Leave the strict product validation authoritative rather than inventing a replacement
    // goal here if a malformed runner input ever reaches this point.
    return nil
}

private func weakestFocus(for pitcher: PitcherSnapshot) -> ProDevelopmentFocus {
    let values: [(ProDevelopmentFocus, Int)] = [
        (.stuff, pitcher.stuff), (.command, pitcher.command), (.movement, pitcher.movement), (.stamina, pitcher.stamina),
    ]
    return values.min { lhs, rhs in lhs.1 == rhs.1 ? lhs.0.rawValue < rhs.0.rawValue : lhs.1 < rhs.1 }!.0
}

private func investment(
    for state: ProCareerSnapshot,
    seed: Int
) -> (ProOffseasonInvestment, ProDevelopmentFocus?) {
    let funds = state.journeyState?.finances.availableFunds ?? 0
    let affordable: [ProOffseasonInvestment] = [.fanFoundation, .recoveryTeam, .pitchLab].filter {
        funds >= ProFinanceRules.investmentCost(for: $0)
    }
    guard !affordable.isEmpty else { return (.none, nil) }
    let options = [.none] + affordable
    let selected = options[Int(stableHashValue("investment|\(seed)|\(state.season)") % UInt64(options.count))]
    guard selected != .none, affordable.contains(selected) else { return (.none, nil) }
    return (selected, selected == .pitchLab ? weakestFocus(for: state.pitcher) : nil)
}

private func offseasonDecision(for state: ProCareerSnapshot, policy: DistributionPolicy, seed: Int) -> OffseasonDecision {
    guard state.contract?.yearsRemaining == 0 else { return .continueCareer }
    guard state.serviceYears >= 6 else { return .continueCareer }
    switch policy {
    case .salaryFirst, .roleFirst:
        return .freeAgency
    case .legacyFirst, .securityFirst:
        return .continueCareer
    case .stableRandom:
        return stableHashValue("market-route|\(seed)|\(state.season)") % 2 == 0 ? .freeAgency : .continueCareer
    }
}

private func selectedOffer(
    from market: ProContractMarket,
    state: ProCareerSnapshot,
    policy: DistributionPolicy,
    seed: Int
) -> ProContractOffer {
    func roleValue(_ offer: ProContractOffer) -> Int {
        ProContractMarketRules.roleValue(current: state.role, promised: offer.rolePromise)
    }
    func tieBreak(_ lhs: ProContractOffer, _ rhs: ProContractOffer, by left: Int, _ right: Int) -> Bool {
        left == right ? lhs.id > rhs.id : left < right
    }
    let selectionOffers = market.offers
    switch policy {
    case .salaryFirst:
        return selectionOffers.max { lhs, rhs in tieBreak(lhs, rhs, by: lhs.annualSalary, rhs.annualSalary) }!
    case .legacyFirst:
        return selectionOffers.max { lhs, rhs in
            let left = (lhs.preservesTeamLegacy ? 500 : 0) + lhs.years * 100 + roleValue(lhs) * 50 + lhs.annualSalary / 1_000_000
            let right = (rhs.preservesTeamLegacy ? 500 : 0) + rhs.years * 100 + roleValue(rhs) * 50 + rhs.annualSalary / 1_000_000
            return tieBreak(lhs, rhs, by: left, right)
        }!
    case .roleFirst:
        return selectionOffers.max { lhs, rhs in
            let left = roleValue(lhs) * 10_000 + lhs.years * 100 + lhs.annualSalary / 10_000_000
            let right = roleValue(rhs) * 10_000 + rhs.years * 100 + rhs.annualSalary / 10_000_000
            return tieBreak(lhs, rhs, by: left, right)
        }!
    case .securityFirst:
        return selectionOffers.max { lhs, rhs in
            let left = lhs.years * 400 + (lhs.expectation.difficulty == .accessible ? 1_000 : 0) + roleValue(lhs) * 25 + lhs.annualSalary / 1_000_000
            let right = rhs.years * 400 + (rhs.expectation.difficulty == .accessible ? 1_000 : 0) + roleValue(rhs) * 25 + rhs.annualSalary / 1_000_000
            return tieBreak(lhs, rhs, by: left, right)
        }!
    case .stableRandom:
        let sorted = selectionOffers.sorted { lhs, rhs in
            let left = stableHashValue("offer|\(seed)|\(lhs.id)")
            let right = stableHashValue("offer|\(seed)|\(rhs.id)")
            return left == right ? lhs.id < rhs.id : left < right
        }
        return sorted[Int(stableHashValue("offer-index|\(seed)|\(market.id)") % UInt64(sorted.count))]
    }
}

private func offerSignature(_ offer: ProContractOffer) -> String {
    [
        offer.contractKind.rawValue, offer.teamID, String(offer.years), String(offer.annualSalary),
        offer.rolePromise.rawValue, offer.outlook.rawValue, offer.preservesTeamLegacy ? "1" : "0",
        offer.expectation.difficulty.rawValue,
    ].joined(separator: ":")
}

private func advanceSeason(
    _ initial: ProCareerResult,
    engine: ProCareerEngine,
    seed: Int,
    metrics: inout DistributionMetrics
) throws -> ProCareerResult {
    var result = initial
    var steps = 0
    while result.snapshot.phase != .seasonReview {
        steps += 1
        guard steps <= 180 else { throw RunnerError.invalidArgument("step_limit season=\(result.snapshot.season) phase=\(result.snapshot.phase.rawValue)") }
        let state = result.snapshot
        if state.journeyState?.finances.availableFunds ?? 0 < 0 { metrics.negativeFunds += 1 }
        if [.weeklyPlan, .seasonDecision, .importantGame].contains(state.phase), state.contract?.yearsRemaining ?? 0 <= 0 {
            metrics.activeExpiredOrMissingContract += 1
        }
        switch state.phase {
        case .weeklyPlan:
            result = try engine.planWeek(.init(seed: result.nextSeed, state: state, plan: weekPlan(for: state, seed: seed)))
        case .importantGame:
            result = try engine.resolveImportantGame(.init(seed: result.nextSeed, state: state, report: report(for: state, seed: seed)))
        case .seasonDecision:
            guard let decision = state.pendingDecision,
                  let choice = decisionChoice(decision, state: state, seed: seed) else {
                throw RunnerError.invalidArgument("missing_decision_choice")
            }
            result = try engine.applySeasonDecision(.init(seed: result.nextSeed, state: state, decisionID: decision.id, choiceID: choice.id))
        default:
            throw RunnerError.invalidArgument("unexpected_phase_\(state.phase.rawValue)")
        }
    }
    return try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
}

private func mergeCareerEvidence(
    _ state: ProCareerSnapshot,
    rookieAmbition: ProCareerAmbition,
    into metrics: inout DistributionMetrics
) {
    let journey = state.journeyState!
    let transactionIDs = journey.finances.transactions.map(\.id)
    metrics.duplicateFinance += transactionIDs.count - Set(transactionIDs).count
    let salaryIDs = transactionIDs.filter { $0.hasPrefix("salary:") }
    metrics.duplicateSalary += salaryIDs.count - Set(salaryIDs).count
    let hasRetiredNumber = journey.retirementHonors.contains(where: { $0.kind == .retiredNumber })
    let hasHallOfFame = journey.retirementHonors.contains(where: { $0.kind == .hallOfFame })
    metrics.retiredNumbers += hasRetiredNumber ? 1 : 0
    metrics.hallOfFame += hasHallOfFame ? 1 : 0
    let seasons = state.careerStats.count
    if seasons >= 12 {
        metrics.longCareerDenominator += 1
        metrics.longCareerRetiredNumbers += hasRetiredNumber ? 1 : 0
        metrics.longCareerHallOfFame += hasHallOfFame ? 1 : 0
    }
    let completedAmbitions = Set(journey.goalHistory.filter { $0.outcome == .completed }.map(\.ambition))
    if completedAmbitions.contains(rookieAmbition) {
        metrics.ambitionCompletions[rookieAmbition.rawValue, default: 0] += 1
    }
    let score = ProCareerEngine.hallOfFameFinalScore(for: state)
    metrics.hallOfFameScoreMin = minOptional(metrics.hallOfFameScoreMin, score)
    metrics.hallOfFameScoreMax = maxOptional(metrics.hallOfFameScoreMax, score)
    metrics.majorServiceYearsMin = minOptional(metrics.majorServiceYearsMin, state.serviceYears)
    metrics.majorServiceYearsMax = maxOptional(metrics.majorServiceYearsMax, state.serviceYears)
    let outs = journey.teamRecords.reduce(0) { $0 + $1.inningsOuts }
    let strikeouts = journey.teamRecords.reduce(0) { $0 + $1.strikeouts }
    let awards = journey.teamRecords.reduce(0) { $0 + $1.awardCount }
    metrics.careerInningsOutsMin = minOptional(metrics.careerInningsOutsMin, outs)
    metrics.careerInningsOutsMax = maxOptional(metrics.careerInningsOutsMax, outs)
    metrics.careerStrikeoutsMin = minOptional(metrics.careerStrikeoutsMin, strikeouts)
    metrics.careerStrikeoutsMax = maxOptional(metrics.careerStrikeoutsMax, strikeouts)
    metrics.careerAwardCountMin = minOptional(metrics.careerAwardCountMin, awards)
    metrics.careerAwardCountMax = maxOptional(metrics.careerAwardCountMax, awards)
    let lastTeamSeasons = journey.teamRecords.first(where: { $0.teamID == state.team.id })?.completedSeasons ?? 0
    metrics.lastTeamSeasonsMin = minOptional(metrics.lastTeamSeasonsMin, lastTeamSeasons)
    metrics.lastTeamSeasonsMax = maxOptional(metrics.lastTeamSeasonsMax, lastTeamSeasons)
    if Set(journey.contractHistory.map(\.teamID)).count > 1 { metrics.teamChangeCareers += 1 }
    metrics.finalRoles[state.role.rawValue, default: 0] += 1
    let expectedRecords = ProTeamCareerRecordRules.backfill(careerStats: state.careerStats, recognitions: journey.recognitions, existing: journey.teamRecords)
    if expectedRecords != journey.teamRecords { metrics.teamRecordMismatches += 1 }
}

private func runCareer(seed: Int, policy: DistributionPolicy, seasons: Int) -> CareerRun {
    var metrics = DistributionMetrics(careers: 1)
    var selectionSequence: [String] = []
    var seenSettlementIDs = Set<String>()
    var earlyFan100 = false
    do {
        let engine = ProCareerEngine(journeyEnabled: true)
        var result = try start(seed: seed)
        let rookieMarket = try unwrapMarket(result.snapshot)
        let rookie = selectedOffer(from: rookieMarket, state: result.snapshot, policy: policy, seed: seed)
        let rookieAmbition = rookieAmbition(for: seed)
        recordOffer(rookie, state: result.snapshot, policy: policy, metrics: &metrics, sequence: &selectionSequence)
        result = try engine.acceptContract(.init(seed: result.nextSeed, state: result.snapshot, expectedRevision: result.snapshot.revision, marketID: rookieMarket.id, offerID: rookie.id, ambition: rookieAmbition))

        while metrics.completedSeasons < seasons {
            result = try advanceSeason(result, engine: engine, seed: seed, metrics: &metrics)
            metrics.completedSeasons += 1
            if let settlement = result.snapshot.journeyState?.lastSettlement {
                if !seenSettlementIDs.insert(settlement.id).inserted { metrics.duplicateSettlement += 1 }
                if settlement.season < 3, settlement.fanAfter == 100 { earlyFan100 = true }
            }
            if result.snapshot.journeyState?.finances.availableFunds ?? 0 < 0 { metrics.negativeFunds += 1 }

            let isFinal = metrics.completedSeasons == seasons
            let settlement = try unwrapSettlement(result.snapshot)
            result = try engine.acknowledgeSettlement(.init(seed: result.nextSeed, state: result.snapshot, expectedRevision: result.snapshot.revision, settlementID: settlement.id))
            if isFinal {
                result = try engine.chooseOffseason(.init(seed: result.nextSeed, state: result.snapshot, decision: .retire, expectedRevision: result.snapshot.revision))
                break
            }

            let decision = offseasonDecision(for: result.snapshot, policy: policy, seed: seed)
            result = try engine.chooseOffseason(.init(seed: result.nextSeed, state: result.snapshot, decision: decision, expectedRevision: result.snapshot.revision))
            if let market = result.snapshot.journeyState?.pendingContractMarket {
                if market.kind == .renewal { metrics.renewalMarkets += 1; if market.offers.count != 2 { metrics.renewalOfferCountMismatch += 1 } }
                if market.kind == .freeAgency { metrics.freeAgencyMarkets += 1; if market.offers.count != 3 { metrics.freeAgencyOfferCountMismatch += 1 } }
                let expectedCount = market.kind == .renewal ? 2 : 3
                if market.offers.count != expectedCount { metrics.marketOfferCountMismatch += 1 }
                if !ProContractMarketRules.isNonDominated(market.offers, currentRole: result.snapshot.role) { metrics.dominatedMarkets += 1 }
                let selected = selectedOffer(from: market, state: result.snapshot, policy: policy, seed: seed + result.snapshot.season)
                let selectedAmbition = ambition(for: result.snapshot, rookieAmbition: rookieAmbition)
                recordOffer(selected, state: result.snapshot, policy: policy, metrics: &metrics, sequence: &selectionSequence)
                result = try engine.acceptContract(.init(seed: result.nextSeed, state: result.snapshot, expectedRevision: result.snapshot.revision, marketID: market.id, offerID: selected.id, ambition: selectedAmbition))
            }
            if result.snapshot.phase == .offseasonInvestment {
                let selectedInvestment = investment(for: result.snapshot, seed: seed)
                result = try engine.chooseInvestment(.init(seed: result.nextSeed, state: result.snapshot, expectedRevision: result.snapshot.revision, investment: selectedInvestment.0, focus: selectedInvestment.1))
            }
        }
        guard result.snapshot.phase == .completed else { throw RunnerError.invalidArgument("career_did_not_complete") }
        if earlyFan100 { metrics.earlyFan100Careers = 1 }
        metrics.ambitionAttempts[rookieAmbition.rawValue, default: 0] += 1
        mergeCareerEvidence(result.snapshot, rookieAmbition: rookieAmbition, into: &metrics)
        if metrics.longCareerDenominator > 0, metrics.longCareerRetiredNumbers > metrics.longCareerDenominator {
            throw RunnerError.invalidArgument("retired-number denominator accounting overflow")
        }
        return CareerRun(seed: seed, policy: policy, metrics: metrics, selectionSequence: selectionSequence)
    } catch {
        metrics.failedRuns = 1
        metrics.errors = ["policy=\(policy.rawValue) seed=\(seed) error=\(error)"]
        return CareerRun(seed: seed, policy: policy, metrics: metrics, selectionSequence: selectionSequence)
    }
}

private func unwrapMarket(_ state: ProCareerSnapshot) throws -> ProContractMarket {
    guard let market = state.journeyState?.pendingContractMarket else { throw RunnerError.invalidArgument("missing_contract_market") }
    return market
}

private func unwrapSettlement(_ state: ProCareerSnapshot) throws -> ProSeasonSettlement {
    guard let settlement = state.journeyState?.lastSettlement else { throw RunnerError.invalidArgument("missing_settlement") }
    return settlement
}

private func recordOffer(
    _ offer: ProContractOffer,
    state: ProCareerSnapshot,
    policy: DistributionPolicy,
    metrics: inout DistributionMetrics,
    sequence: inout [String]
) {
    metrics.contractSelections["\(policy.rawValue):\(offer.contractKind.rawValue)", default: 0] += 1
    metrics.selectedOfferCount += 1
    metrics.selectedSalaryTotal += Int64(offer.annualSalary)
    metrics.selectedYearsTotal += offer.years
    metrics.selectedRoleValueTotal += ProContractMarketRules.roleValue(current: state.role, promised: offer.rolePromise)
    metrics.selectedLegacyCount += offer.preservesTeamLegacy ? 1 : 0
    metrics.selectedAccessibleCount += offer.expectation.difficulty == .accessible ? 1 : 0
    let signature = offerSignature(offer)
    metrics.selectedOfferSignatures[signature, default: 0] += 1
    sequence.append(signature)
}

private func ratePermille(numerator: Int, denominator: Int) -> Int? {
    guard denominator > 0 else { return nil }
    return numerator * 1_000 / denominator
}

private func optionalJSON(_ value: Int?) -> Any {
    value.map { $0 } ?? NSNull()
}

private func policySummary(_ metrics: DistributionMetrics) -> [String: Any] {
    var ambitions: [String: Any] = [:]
    for ambition in ambitionWires {
        let attempts = metrics.ambitionAttempts[ambition.rawValue, default: 0]
        let completions = metrics.ambitionCompletions[ambition.rawValue, default: 0]
        ambitions[ambition.rawValue] = [
            "attempts": attempts,
            "completions": completions,
            "successRate": attempts == 0 ? NSNull() : Double(completions) / Double(attempts),
            "successRatePermille": optionalJSON(ratePermille(numerator: completions, denominator: attempts)),
        ]
    }
    return [
        "careers": metrics.careers,
        "completedSeasons": metrics.completedSeasons,
        "failedRuns": metrics.failedRuns,
        "errors": metrics.errors,
        "negativeFunds": metrics.negativeFunds,
        "duplicateFinance": metrics.duplicateFinance,
        "duplicateSalary": metrics.duplicateSalary,
        "duplicateSettlement": metrics.duplicateSettlement,
        "activeExpiredOrMissingContract": metrics.activeExpiredOrMissingContract,
        "marketOfferCountMismatch": metrics.marketOfferCountMismatch,
        "renewalOfferCountMismatch": metrics.renewalOfferCountMismatch,
        "freeAgencyOfferCountMismatch": metrics.freeAgencyOfferCountMismatch,
        "dominatedMarkets": metrics.dominatedMarkets,
        "renewalMarkets": metrics.renewalMarkets,
        "freeAgencyMarkets": metrics.freeAgencyMarkets,
        "teamRecordMismatches": metrics.teamRecordMismatches,
        "earlyFan100CareerIncidence": metrics.careers == 0 ? NSNull() : Double(metrics.earlyFan100Careers) / Double(metrics.careers),
        "earlyFan100Careers": metrics.earlyFan100Careers,
        "longCareerDenominator": metrics.longCareerDenominator,
        "retiredNumberNumerator": metrics.longCareerRetiredNumbers,
        "retiredNumberRate": optionalJSON(ratePermille(numerator: metrics.longCareerRetiredNumbers, denominator: metrics.longCareerDenominator)),
        "hallOfFameNumerator": metrics.longCareerHallOfFame,
        "hallOfFameRate": optionalJSON(ratePermille(numerator: metrics.longCareerHallOfFame, denominator: metrics.longCareerDenominator)),
        "retiredNumbers": metrics.retiredNumbers,
        "hallOfFame": metrics.hallOfFame,
        "ambitions": ambitions,
        "hallOfFameScoreMin": optionalJSON(metrics.hallOfFameScoreMin),
        "hallOfFameScoreMax": optionalJSON(metrics.hallOfFameScoreMax),
        "majorServiceYearsMin": optionalJSON(metrics.majorServiceYearsMin),
        "majorServiceYearsMax": optionalJSON(metrics.majorServiceYearsMax),
        "careerInningsOutsMin": optionalJSON(metrics.careerInningsOutsMin),
        "careerInningsOutsMax": optionalJSON(metrics.careerInningsOutsMax),
        "careerStrikeoutsMin": optionalJSON(metrics.careerStrikeoutsMin),
        "careerStrikeoutsMax": optionalJSON(metrics.careerStrikeoutsMax),
        "careerAwardCountMin": optionalJSON(metrics.careerAwardCountMin),
        "careerAwardCountMax": optionalJSON(metrics.careerAwardCountMax),
        "lastTeamSeasonsMin": optionalJSON(metrics.lastTeamSeasonsMin),
        "lastTeamSeasonsMax": optionalJSON(metrics.lastTeamSeasonsMax),
        "teamChangeCareers": metrics.teamChangeCareers,
        "finalRoles": metrics.finalRoles,
        "contractSelections": metrics.contractSelections,
        "selectedOfferCount": metrics.selectedOfferCount,
        "selectedOfferAxisMeans": metrics.selectedOfferCount == 0 ? NSNull() : [
            "annualSalary": Double(metrics.selectedSalaryTotal) / Double(metrics.selectedOfferCount),
            "years": Double(metrics.selectedYearsTotal) / Double(metrics.selectedOfferCount),
            "roleValue": Double(metrics.selectedRoleValueTotal) / Double(metrics.selectedOfferCount),
            "preservesLegacyRate": Double(metrics.selectedLegacyCount) / Double(metrics.selectedOfferCount),
            "accessibleExpectationRate": Double(metrics.selectedAccessibleCount) / Double(metrics.selectedOfferCount),
        ],
        "selectedOfferSignatures": metrics.selectedOfferSignatures,
    ]
}

private func normalizedProfile(_ metrics: DistributionMetrics) -> String {
    guard metrics.selectedOfferCount > 0 else { return "none" }
    let salary = metrics.selectedSalaryTotal / Int64(metrics.selectedOfferCount)
    let years = metrics.selectedYearsTotal * 1_000 / metrics.selectedOfferCount
    let role = metrics.selectedRoleValueTotal * 1_000 / metrics.selectedOfferCount
    let legacy = metrics.selectedLegacyCount * 1_000 / metrics.selectedOfferCount
    let accessible = metrics.selectedAccessibleCount * 1_000 / metrics.selectedOfferCount
    return "\(salary)|\(years)|\(role)|\(legacy)|\(accessible)"
}

private func runTradeoffReport(
    runs: [CareerRun],
    byPolicy: [DistributionPolicy: DistributionMetrics]
) -> [String: Any] {
    var bySeed: [Int: [DistributionPolicy: [String]]] = [:]
    for run in runs { bySeed[run.seed, default: [:]][run.policy] = run.selectionSequence }
    var comparableSelections = 0
    var differingSelections = 0
    var policyPairsWithDifferences = 0
    for seed in bySeed.keys.sorted() {
        let values = bySeed[seed] ?? [:]
        for lhsIndex in 0..<DistributionPolicy.allCases.count {
            for rhsIndex in (lhsIndex + 1)..<DistributionPolicy.allCases.count {
                let lhsPolicy = DistributionPolicy.allCases[lhsIndex]
                let rhsPolicy = DistributionPolicy.allCases[rhsIndex]
                guard let lhs = values[lhsPolicy], let rhs = values[rhsPolicy] else { continue }
                let count = min(lhs.count, rhs.count)
                var pairDifferent = false
                for index in 0..<count {
                    comparableSelections += 1
                    if lhs[index] != rhs[index] { differingSelections += 1; pairDifferent = true }
                }
                if pairDifferent { policyPairsWithDifferences += 1 }
            }
        }
    }
    let profiles = Dictionary(uniqueKeysWithValues: DistributionPolicy.allCases.map { policy in
        (policy.rawValue, normalizedProfile(byPolicy[policy] ?? DistributionMetrics()))
    })
    let distinctProfiles = Set(profiles.values).count
    let verdict = distinctProfiles >= 3 && differingSelections > 0 && policyPairsWithDifferences > 0
    return [
        "basis": "same_seed_set_policy_selection_sequences_and_selected_contract_axes",
        "comparableSelectionCount": comparableSelections,
        "differingSelectionCount": differingSelections,
        "policyPairsWithDifferentSelections": policyPairsWithDifferences,
        "distinctPolicyAxisProfiles": distinctProfiles,
        "policyAxisProfiles": profiles,
        "noUniversallyOptimalOfferArchetype": verdict,
    ]
}

private func verdict(
    _ id: String,
    observed: Any,
    pass: Bool,
    enforced: Bool,
    detail: String
) -> [String: Any] {
    [
        "id": id,
        "observed": observed,
        "enforced": enforced,
        "pass": pass,
        "status": enforced ? (pass ? "pass" : "fail") : "not_enforced_smoke",
        "detail": detail,
    ]
}

private func run() async throws {
    let arguments = CommandLine.arguments.dropFirst()
    let release = arguments.contains("--release")
    let seedCount = Int(ProcessInfo.processInfo.environment["BASEBALL_PRO_DISTRIBUTION_SEEDS"] ?? (release ? "1000" : "8")) ?? (release ? 1000 : 8)
    let seasons = Int(ProcessInfo.processInfo.environment["BASEBALL_PRO_DISTRIBUTION_SEASONS"] ?? (release ? "20" : "4")) ?? (release ? 20 : 4)
    let seedOffset = Int(ProcessInfo.processInfo.environment["BASEBALL_PRO_DISTRIBUTION_SEED_OFFSET"] ?? "0") ?? 0
    guard seedCount > 0, seasons > 0, seasons <= ProCareerEngine.maximumCareerSeasons else {
        throw RunnerError.invalidArgument("seedCount must be positive and seasons must be 1...\(ProCareerEngine.maximumCareerSeasons)")
    }
    var failingChecks: [String] = []
    if release, seedCount < 1_000 { failingChecks.append("release.seedCountMustBeAtLeast1000") }
    if release, seasons < 20 { failingChecks.append("release.seasonsMustBeAtLeast20") }
    let policies = DistributionPolicy.allCases
    let workerCount = min(max(1, ProcessInfo.processInfo.activeProcessorCount), 16)
    var allRuns: [CareerRun] = []
    await withTaskGroup(of: CareerRun.self) { group in
        var next = 0
        func enqueue(_ index: Int) {
            let policy = policies[index / seedCount]
            let seed = seedOffset + index % seedCount
            group.addTask { runCareer(seed: seed, policy: policy, seasons: seasons) }
        }
        let total = seedCount * policies.count
        while next < min(workerCount, total) { enqueue(next); next += 1 }
        while let run = await group.next() {
            allRuns.append(run)
            if next < total { enqueue(next); next += 1 }
        }
    }
    var byPolicy: [DistributionPolicy: DistributionMetrics] = [:]
    for run in allRuns { byPolicy[run.policy, default: DistributionMetrics()].merge(run.metrics) }
    let balancePolicy: DistributionPolicy = .stableRandom
    let balanceMetrics = byPolicy[balancePolicy] ?? DistributionMetrics()
    let tradeoff = runTradeoffReport(runs: allRuns, byPolicy: byPolicy)
    let thresholdEnforced = release
    func addCorrectness(_ id: String, _ value: Int) {
        let passed = value == 0
        if !passed { failingChecks.append(id) }
    }
    for policy in policies {
        let metrics = byPolicy[policy] ?? DistributionMetrics()
        addCorrectness("\(policy.rawValue).failedRuns", metrics.failedRuns)
        addCorrectness("\(policy.rawValue).activeExpiredOrMissingContract", metrics.activeExpiredOrMissingContract)
        addCorrectness("\(policy.rawValue).duplicateFinance", metrics.duplicateFinance)
        addCorrectness("\(policy.rawValue).duplicateSalary", metrics.duplicateSalary)
        addCorrectness("\(policy.rawValue).duplicateSettlement", metrics.duplicateSettlement)
        addCorrectness("\(policy.rawValue).negativeFunds", metrics.negativeFunds)
        addCorrectness("\(policy.rawValue).marketOfferCountMismatch", metrics.marketOfferCountMismatch)
        addCorrectness("\(policy.rawValue).renewalOfferCountMismatch", metrics.renewalOfferCountMismatch)
        addCorrectness("\(policy.rawValue).freeAgencyOfferCountMismatch", metrics.freeAgencyOfferCountMismatch)
        addCorrectness("\(policy.rawValue).dominatedMarkets", metrics.dominatedMarkets)
        addCorrectness("\(policy.rawValue).teamRecordMismatches", metrics.teamRecordMismatches)
    }
    let correctnessVerdicts: [[String: Any]] = [
        verdict("correctness.failedRuns", observed: allRuns.reduce(0) { $0 + $1.metrics.failedRuns }, pass: allRuns.allSatisfy { $0.metrics.failedRuns == 0 }, enforced: true, detail: "Every seed/policy career must finish through real engine commands."),
        verdict("correctness.activeExpiredOrMissingContract", observed: byPolicy.values.reduce(0) { $0 + $1.activeExpiredOrMissingContract }, pass: byPolicy.values.allSatisfy { $0.activeExpiredOrMissingContract == 0 }, enforced: true, detail: "No weekly/decision/important-game phase may run without a live contract."),
        verdict("correctness.duplicateFinance", observed: byPolicy.values.reduce(0) { $0 + $1.duplicateFinance }, pass: byPolicy.values.allSatisfy { $0.duplicateFinance == 0 }, enforced: true, detail: "Finance IDs are exact-once within the bounded ledger."),
        verdict("correctness.duplicateSalary", observed: byPolicy.values.reduce(0) { $0 + $1.duplicateSalary }, pass: byPolicy.values.allSatisfy { $0.duplicateSalary == 0 }, enforced: true, detail: "Salary IDs are exact-once."),
        verdict("correctness.duplicateSettlement", observed: byPolicy.values.reduce(0) { $0 + $1.duplicateSettlement }, pass: byPolicy.values.allSatisfy { $0.duplicateSettlement == 0 }, enforced: true, detail: "Settlement IDs are exact-once."),
        verdict("correctness.negativeFunds", observed: byPolicy.values.reduce(0) { $0 + $1.negativeFunds }, pass: byPolicy.values.allSatisfy { $0.negativeFunds == 0 }, enforced: true, detail: "Available funds must remain non-negative."),
        verdict("correctness.offerCounts", observed: byPolicy.values.reduce(0) { $0 + $1.marketOfferCountMismatch }, pass: byPolicy.values.allSatisfy { $0.marketOfferCountMismatch == 0 }, enforced: true, detail: "Renewal markets have 2 offers and free-agency markets have 3."),
        verdict("correctness.dominatedMarkets", observed: byPolicy.values.reduce(0) { $0 + $1.dominatedMarkets }, pass: byPolicy.values.allSatisfy { $0.dominatedMarkets == 0 }, enforced: true, detail: "Persisted markets must pass the core non-dominance validator."),
        verdict("correctness.teamRecordMismatches", observed: byPolicy.values.reduce(0) { $0 + $1.teamRecordMismatches }, pass: byPolicy.values.allSatisfy { $0.teamRecordMismatches == 0 }, enforced: true, detail: "Team records must equal the career-stat aggregation."),
    ]

    var policyOutput: [String: Any] = [:]
    var distributionVerdicts: [[String: Any]] = []
    for policy in policies {
        let metrics = byPolicy[policy] ?? DistributionMetrics()
        let summary = policySummary(metrics)
        policyOutput[policy.rawValue] = summary
        let longDenominator = metrics.longCareerDenominator
        let retiredRate = ratePermille(numerator: metrics.longCareerRetiredNumbers, denominator: longDenominator)
        let hofRate = ratePermille(numerator: metrics.longCareerHallOfFame, denominator: longDenominator)
        let retiredPass = retiredRate.map { (50...250).contains($0) } ?? false
        let hofPass = hofRate.map { (50...350).contains($0) } ?? false
        distributionVerdicts.append(verdict("\(policy.rawValue).earlyFan100CareerIncidence", observed: summary["earlyFan100CareerIncidence"] ?? NSNull(), pass: metrics.careers > 0 && metrics.earlyFan100Careers * 100 <= metrics.careers, enforced: false, detail: "Policy diagnostic; release bounds use the combined policy-run denominator."))
        distributionVerdicts.append(verdict("\(policy.rawValue).retiredNumberRateAmong12SeasonCareers", observed: optionalJSON(retiredRate), pass: retiredPass, enforced: false, detail: "Policy diagnostic; release bounds use the combined policy-run denominator."))
        distributionVerdicts.append(verdict("\(policy.rawValue).hallOfFameRateAmong12SeasonCareers", observed: optionalJSON(hofRate), pass: hofPass, enforced: false, detail: "Policy diagnostic; release bounds use the combined policy-run denominator."))
        for ambition in ambitionWires {
            let attempts = metrics.ambitionAttempts[ambition.rawValue, default: 0]
            let completions = metrics.ambitionCompletions[ambition.rawValue, default: 0]
            let rate = ratePermille(numerator: completions, denominator: attempts)
            let pass = rate.map { (100...500).contains($0) && completions <= attempts } ?? false
            distributionVerdicts.append(verdict("\(policy.rawValue).ambition.\(ambition.rawValue)", observed: optionalJSON(rate), pass: pass, enforced: false, detail: "Policy diagnostic; release bounds use the combined policy-run denominator."))
        }
    }
    let balanceSummary = policySummary(balanceMetrics)
    let balanceLongDenominator = balanceMetrics.longCareerDenominator
    let balanceRetiredRate = ratePermille(numerator: balanceMetrics.longCareerRetiredNumbers, denominator: balanceLongDenominator)
    let balanceHOFRate = ratePermille(numerator: balanceMetrics.longCareerHallOfFame, denominator: balanceLongDenominator)
    distributionVerdicts.append(verdict(
        "balance.stable_random.earlyFan100CareerIncidence",
        observed: balanceSummary["earlyFan100CareerIncidence"] ?? NSNull(),
        pass: balanceMetrics.careers > 0 && balanceMetrics.earlyFan100Careers * 100 <= balanceMetrics.careers,
        enforced: thresholdEnforced,
        detail: "Unbiased balance cohort is stable_random only; denominator is one completed career per seed. Target is at most 1% before season 3."
    ))
    distributionVerdicts.append(verdict(
        "balance.stable_random.retiredNumberRateAmong12SeasonCareers",
        observed: optionalJSON(balanceRetiredRate),
        pass: balanceRetiredRate.map { (50...250).contains($0) } ?? false,
        enforced: thresholdEnforced,
        detail: "Unbiased stable_random cohort only; denominator is careers with completedSeasons >= 12; target 5%...25%."
    ))
    distributionVerdicts.append(verdict(
        "balance.stable_random.hallOfFameRateAmong12SeasonCareers",
        observed: optionalJSON(balanceHOFRate),
        pass: balanceHOFRate.map { (50...350).contains($0) } ?? false,
        enforced: thresholdEnforced,
        detail: "Unbiased stable_random cohort only; denominator is careers with completedSeasons >= 12; target 5%...35%."
    ))
    for ambition in ambitionWires {
        let attempts = balanceMetrics.ambitionAttempts[ambition.rawValue, default: 0]
        let completions = balanceMetrics.ambitionCompletions[ambition.rawValue, default: 0]
        let rate = ratePermille(numerator: completions, denominator: attempts)
        distributionVerdicts.append(verdict(
            "balance.stable_random.ambition.\(ambition.rawValue)",
            observed: optionalJSON(rate),
            pass: rate.map { (100...500).contains($0) && completions <= attempts } ?? false,
            enforced: thresholdEnforced,
            detail: "Unbiased stable_random cohort only; denominator is unique careers whose stable rookie mapping selected \(ambition.rawValue); target 10%...50%."
        ))
    }
    let tradeoffPass = (tradeoff["noUniversallyOptimalOfferArchetype"] as? Bool) == true
    distributionVerdicts.append(verdict("tradeoff.noUniversallyOptimalOfferArchetype", observed: tradeoff, pass: tradeoffPass, enforced: thresholdEnforced, detail: "Uses same-seed policy offer choices and separate per-policy axis profiles; policies are sensitivity probes, not population weights."))
    if thresholdEnforced {
        for item in distributionVerdicts where (item["enforced"] as? Bool) == true && (item["pass"] as? Bool) != true {
            failingChecks.append(item["id"] as? String ?? "distribution")
        }
    }
    let allVerdicts = correctnessVerdicts + distributionVerdicts
    let output: [String: Any] = [
        "schema": "pro-career-distribution-v2",
        "runner": "pro-career-distribution-v2",
        "mode": release ? "release" : "smoke",
        "journeyEnabled": true,
        "actualCommandSimulation": true,
        "syntheticOutputAdjustment": false,
        "population": [
            "seedSet": "\(seedOffset)...\(seedOffset + seedCount - 1)",
            "sameSeedSetAcrossPolicies": true,
            "presetCatalog": "PitcherPresetCatalog.all",
            "presetSelection": "seed-stable-index",
            "rookieAmbitionMapping": "nonnegative_seed_modulo_3; same mapping across all policies",
            "laterAmbitionPolicy": "retain unfinished active goal; after completion choose the next not-yet-completed ambition in fixed cyclic order after the rookie ambition; nil only after all three complete",
            "forcedAbilityOverride": false,
            "forcedTargetSeasons": false,
            "representativeDraftInputs": true,
        ],
        "seedCount": seedCount,
        "seedOffset": seedOffset,
        "seasons": seasons,
        "policyCount": policies.count,
        "balanceCohort": [
            "policy": balancePolicy.rawValue,
            "unbiased": true,
            "oneCareerPerSeed": true,
            "thresholdsApplyHereOnly": true,
            "otherPoliciesAreDiagnostics": true,
        ],
        "policies": policyOutput,
        "balance": balanceSummary,
        "balanceMetric": [
            "name": "rookie_ambition_only",
            "attempts": "exactly one original rookie ambition assignment per career",
            "completion": "one completion only when that exact rookie ambition completes",
            "laterAmbitionsIncluded": false,
            "policy": balancePolicy.rawValue,
        ],
        "tradeoff": tradeoff,
        "thresholds": [
            "release mode requires 1000 seeds x 20 seasons",
            "release distribution bounds are applied to the stable_random balance cohort only",
            "salary_first, legacy_first, role_first, and security_first balance figures are diagnostics only",
            "smoke mode reports rates but does not enforce small-sample bounds",
        ],
        "thresholdEnforced": thresholdEnforced,
        "thresholdVerdicts": allVerdicts,
        "failingChecks": failingChecks.sorted(),
        "valid": failingChecks.isEmpty,
        "rules": [
            "hall_of_fame_threshold=70",
            "hall_of_fame_formula_version=\(ProCareerEngine.hallOfFameFormulaVersion)",
            "pro_rules_version=\(ProCareerEngine.currentRulesVersion)",
        ],
    ]
    let data = try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys, .prettyPrinted])
    if let path = ProcessInfo.processInfo.environment["BASEBALL_PRO_DISTRIBUTION_OUTPUT"] {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
    print(String(decoding: data, as: UTF8.self))
    guard failingChecks.isEmpty else {
        throw RunnerError.invalidArgument("release gate failed: \(failingChecks.sorted().joined(separator: ","))")
    }
}

try await run()
