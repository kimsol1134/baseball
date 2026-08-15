import CryptoKit
import Foundation
@_spi(ProCareerFixture) import SimulationCore

private let schema = "baseball-pro-career-fixture-v2"
private let sourceRevision = "wave6-swift-semantic-oracle-2026-08-15"
private let defaultOutput = "artifacts/android-compose/fixtures/swift-pro-career-oracle-v2.json"

private struct FixtureRow {
    let id: String
    let inputCanonical: String
    let outputCanonical: String
    let output: [String: Any]
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

private func start(seed: String, sourceFanInterest: Int? = nil, journeyEnabled: Bool = true) throws -> ProCareerResult {
    let seedValue = UInt64(seed) ?? 0
    let team = ProCareerEngine.proTeams[Int(seedValue % UInt64(ProCareerEngine.proTeams.count))]
    let pitcher = PitcherPresetCatalog.all.first(where: { $0.id == "power_prospect" })!.pitcher
    return try ProCareerEngine(journeyEnabled: journeyEnabled).start(.init(
        seed: seed,
        identity: .defaultPitcher,
        pitcher: pitcher,
        draftResult: draft(team: team),
        entitlement: activeEntitlement(),
        sourceFanInterest: sourceFanInterest
    ))
}

private func report(for state: ProCareerSnapshot, salt: Int = 0) -> ImportantInningReport {
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

private func stableChoice(_ lhs: ProSeasonDecisionChoice, _ rhs: ProSeasonDecisionChoice) -> Bool {
    if lhs.effect.fatigueDelta != rhs.effect.fatigueDelta { return lhs.effect.fatigueDelta < rhs.effect.fatigueDelta }
    return lhs.id < rhs.id
}

private func playUntilSeasonReview(_ initial: ProCareerResult, engine: ProCareerEngine, salt: Int = 0, preferMediaChoice: Bool = false) throws -> ProCareerResult {
    var result = initial
    var steps = 0
    while result.snapshot.phase != .seasonReview {
        steps += 1
        guard steps <= 180 else { throw NSError(domain: "ProFixtureV2", code: 10) }
        let state = result.snapshot
        switch state.phase {
        case .weeklyPlan:
            let plan: ProWeekPlan = state.fatigue > 72 ? .recover : (state.managerTrust < 68 ? .earnTrust : .refineCommand)
            result = try engine.planWeek(.init(seed: result.nextSeed, state: state, plan: plan))
        case .importantGame:
            result = try engine.resolveImportantGame(.init(seed: result.nextSeed, state: state, report: report(for: state, salt: salt)))
        case .seasonDecision:
            guard let decision = state.pendingDecision else { throw NSError(domain: "ProFixtureV2", code: 11) }
            let choice: ProSeasonDecisionChoice
            if preferMediaChoice, decision.type == .mediaOpportunity {
                choice = decision.choices.first(where: { $0.id == "media_opportunity.fan_together_shoot" }) ?? decision.choices[0]
            } else {
                choice = decision.choices.min(by: stableChoice)!
            }
            result = try engine.applySeasonDecision(.init(seed: result.nextSeed, state: state, decisionID: decision.id, choiceID: choice.id))
        default:
            throw NSError(domain: "ProFixtureV2", code: 12)
        }
    }
    return result
}

private func playSeason(_ initial: ProCareerResult, engine: ProCareerEngine, salt: Int = 0, preferMediaChoice: Bool = false) throws -> ProCareerResult {
    let reviewReady = try playUntilSeasonReview(initial, engine: engine, salt: salt, preferMediaChoice: preferMediaChoice)
    return try engine.reviewSeason(.init(seed: reviewReady.nextSeed, state: reviewReady.snapshot))
}

private func accept(_ result: ProCareerResult, engine: ProCareerEngine, ambition: ProCareerAmbition?) throws -> ProCareerResult {
    let market = result.snapshot.journeyState!.pendingContractMarket!
    let offer = market.offers[0]
    return try engine.acceptContract(.init(
        seed: result.nextSeed,
        state: result.snapshot,
        expectedRevision: result.snapshot.revision,
        marketID: market.id,
        offerID: offer.id,
        ambition: ambition
    ))
}

private struct PositiveRetirementFixture {
    let state: ProCareerSnapshot
    let canonicalInputs: [String: Any]
}

private func positiveRetirementFixture(engine: ProCareerEngine) throws -> PositiveRetirementFixture {
    let careerID = "pro-wave6-positive-retirement"
    let team = ProCareerEngine.proTeams[0]
    let pitcher = PitcherPresetCatalog.all.first(where: { $0.id == "power_prospect" })!.pitcher
    let seasonStats = (1...20).map { season in
        ProSeasonStats(
            season: season,
            teamID: team.id,
            games: 30,
            starts: 30,
            inningsOuts: 540,
            strikeouts: 300,
            walks: 0,
            runsAllowed: 0,
            hits: 0,
            homeRuns: 0,
            pitches: 720,
            wins: 10
        )
    }
    let ambitionSpecs: [(ProCareerAmbition, Int)] = [
        (.franchiseIcon, 8),
        (.recordBook, 12),
        (.enduringPro, 16),
    ]
    let goalHistory = ambitionSpecs.map { ambition, completedSeason in
        let anchorTeamID = ambition == .franchiseIcon ? team.id : nil
        return ProCareerGoalRecord(
            id: ProCareerGoalRules.goalID(careerID: careerID, season: 1, ambition: ambition, anchorTeamID: anchorTeamID),
            ambition: ambition,
            selectedSeason: 1,
            anchorTeamID: anchorTeamID,
            completedSeason: completedSeason,
            endedSeason: completedSeason,
            outcome: .completed
        )
    }.sorted { $0.id < $1.id }
    let seasonRecognitions = seasonStats.flatMap { stats in
        ProCareerRecognitionRules.currentSeasonRecognitions(
            careerID: careerID,
            season: stats.season,
            teamID: team.id,
            stats: stats,
            level: .major
        )
    }
    let ambitionRecognitions = ambitionSpecs.map { ambition, season in
        ProCareerRecognition(
            careerID: careerID,
            kind: .milestone,
            contentID: "pro.ambition.\(ambition.rawValue).completed",
            season: season,
            teamID: team.id
        )
    }
    let recognitions = (seasonRecognitions + ambitionRecognitions).sorted(by: ProCareerJourneyRules.recognitionOrder)

    func contract(
        _ suffix: String,
        kind: ProContractKind,
        signedSeason: Int,
        totalYears: Int,
        coveredSeasons: [Int],
        endedSeason: Int?,
        endReason: ProContractEndReason?,
        annualSalary: Int,
        signingBonus: Int?
    ) -> ProContractRecord {
        ProContractRecord(
            contractID: "contract:\(careerID):\(suffix)",
            teamID: team.id,
            kind: kind,
            signedSeason: signedSeason,
            totalYears: totalYears,
            annualSalary: annualSalary,
            signingBonus: signingBonus,
            rolePromise: .starter,
            expectation: .init(kind: .majorRoster, target: 1, difficulty: .accessible),
            coveredSeasons: coveredSeasons,
            fulfilledExpectationSeasons: [],
            endedSeason: endedSeason,
            endReason: endReason
        )
    }

    let rookieContract = contract("01", kind: .rookie, signedSeason: 1, totalYears: 3, coveredSeasons: [1, 2, 3], endedSeason: 3, endReason: .expired, annualSalary: 60_000_000, signingBonus: 120_000_000)
    let contracts = [
        rookieContract,
        contract("04", kind: .renewalLong, signedSeason: 4, totalYears: 4, coveredSeasons: [4, 5, 6, 7], endedSeason: 7, endReason: .expired, annualSalary: 70_000_000, signingBonus: nil),
        contract("08", kind: .renewalLong, signedSeason: 8, totalYears: 4, coveredSeasons: [8, 9, 10, 11], endedSeason: 11, endReason: .expired, annualSalary: 80_000_000, signingBonus: nil),
        contract("12", kind: .renewalLong, signedSeason: 12, totalYears: 4, coveredSeasons: [12, 13, 14, 15], endedSeason: 15, endReason: .expired, annualSalary: 90_000_000, signingBonus: nil),
        contract("16", kind: .proveIt, signedSeason: 16, totalYears: 1, coveredSeasons: [16], endedSeason: 16, endReason: .expired, annualSalary: 95_000_000, signingBonus: nil),
        contract("17", kind: .renewalLong, signedSeason: 17, totalYears: 4, coveredSeasons: [17, 18, 19], endedSeason: nil, endReason: nil, annualSalary: 100_000_000, signingBonus: nil),
    ].sorted { $0.contractID < $1.contractID }
    let signing = ProFinanceTransaction(
        id: "signing:\(careerID):\(rookieContract.contractID)",
        season: 1,
        kind: .signingBonus,
        amount: 120_000_000
    )
    let teamRecords = ProTeamCareerRecordRules.backfill(careerStats: seasonStats, recognitions: recognitions)
    let currentContract = contracts.last!
    let journey = ProCareerJourneyState(
        rulesVersion: 1,
        activeGoal: nil,
        goalHistory: goalHistory,
        pendingContractMarket: nil,
        contractHistory: contracts,
        teamRecords: teamRecords,
        recognitions: recognitions,
        reputation: .init(fanSupport: 80),
        finances: .init(careerEarnings: signing.amount, availableFunds: signing.amount, transactions: [signing]),
        activeSeasonBenefit: nil,
        lastSettlement: nil,
        settlementAcknowledged: true,
        offseasonTransition: nil,
        retirementHonors: [],
        migration: .init(source: .newCareer, initializedSeason: 1, financeStartsSeason: 1, unassignedLegacyAwards: 0, financeNoticePending: false)
    )
    func makeState(commitment: String) -> ProCareerSnapshot {
        ProCareerSnapshot(
            proCareerID: careerID,
            revision: 0,
            phase: .offseasonDecision,
            identity: .defaultPitcher,
            pitcher: pitcher,
            team: team,
            entitlement: activeEntitlement(),
            age: 38,
            season: 20,
            week: 24,
            level: .major,
            role: .starter,
            rolePreference: .starter,
            managerTrust: 80,
            catcherTrust: 80,
            fatigue: 0,
            injuryWeeks: 0,
            serviceYears: 20,
            militaryCompleted: false,
            contract: .init(
                yearsRemaining: 1,
                annualSalary: currentContract.annualSalary,
                rolePromise: currentContract.rolePromise,
                id: currentContract.contractID,
                teamID: currentContract.teamID,
                totalYears: currentContract.totalYears,
                signedSeason: currentContract.signedSeason,
                kind: currentContract.kind,
                expectation: currentContract.expectation
            ),
            currentStats: seasonStats.last!,
            gameLines: [],
            careerStats: seasonStats,
            awards: [],
            milestones: [],
            news: [],
            hallOfFameScore: nil,
            commitment: commitment,
            balanceVersion: PitcherPresetCatalog.balanceVersion,
            proRulesVersion: ProCareerEngine.currentRulesVersion,
            journeyState: journey
        )
    }
    let unsigned = makeState(commitment: "")
    let signed = makeState(commitment: engine.fixtureCommitment(unsigned))
    let semanticInputs: [String: Any] = [
        "rulesVersion": ProCareerEngine.currentRulesVersion,
        "hallOfFameThreshold": 70,
        "retirementThresholds": ["lastTeamSeasons": 8, "lastTeamLegacy": 80, "fanSupport": 60],
        "careerStats": seasonStats.map { stats in
            [
                "season": stats.season,
                "teamID": stats.teamID,
                "games": stats.games,
                "inningsOuts": stats.inningsOuts,
                "strikeouts": stats.strikeouts,
                "wins": stats.wins,
            ]
        },
        "teamRecord": teamRecords.map { record in
            [
                "teamID": record.teamID,
                "completedSeasons": record.completedSeasons,
                "legacy": ProTeamLegacyRules.score(record: record),
                "awardCount": record.awardCount,
            ]
        },
        "goalWires": goalHistory.map { record in
            [
                "id": record.id,
                "ambition": record.ambition.rawValue,
                "selectedSeason": record.selectedSeason,
                "anchorTeamID": record.anchorTeamID as Any,
                "completedSeason": record.completedSeason as Any,
                "outcome": record.outcome.rawValue,
            ]
        },
        "fanSupport": journey.reputation.fanSupport,
        "careerEarnings": journey.finances.careerEarnings,
    ]
    return PositiveRetirementFixture(state: signed, canonicalInputs: semanticInputs)
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

private func row(_ id: String, input: String, output: [String: Any], canonical: String) -> FixtureRow {
    FixtureRow(id: id, inputCanonical: input, outputCanonical: canonical, output: output)
}

private func errorID(_ work: () throws -> Void) -> String {
    do {
        try work()
        return "none"
    } catch let SimulationError.invalidProCareer(detail) {
        let lower = detail.lowercased()
        if lower.contains("stale") { return "stale_revision_or_market" }
        if lower.contains("settlement") { return "invalid_settlement" }
        if lower.contains("offer") { return "invalid_offer" }
        if lower.contains("transition") { return "invalid_transition" }
        return detail.replacingOccurrences(of: " ", with: "_")
    } catch {
        return String(describing: error).replacingOccurrences(of: " ", with: "_")
    }
}

private func buildRows() throws -> [FixtureRow] {
    let engine = ProCareerEngine(journeyEnabled: true)
    let started = try start(seed: "620001", sourceFanInterest: 30)
    let rookieMarket = started.snapshot.journeyState!.pendingContractMarket!
    let rookie = try accept(started, engine: engine, ambition: .recordBook)
    let rookieOffer = rookieMarket.offers[0]
    let rookieCanonical = [
        started.nextSeed, rookieMarket.id, rookieOffer.id, rookieOffer.teamID, String(rookieOffer.years),
        String(rookieOffer.annualSalary), String(rookieOffer.signingBonus ?? 0), rookie.snapshot.phase.rawValue,
        rookie.snapshot.nextSeedEvidence,
    ].joined(separator: "|")

    var rows: [FixtureRow] = []
    rows.append(row(
        "rookie_contract",
        input: "journey:start:620001|accept:rookie|ambition:record_book",
        output: [
            "nextSeed": rookie.nextSeed,
            "careerID": rookie.snapshot.proCareerID,
            "marketID": rookieMarket.id,
            "offerID": rookieOffer.id,
            "teamID": rookieOffer.teamID,
            "years": rookieOffer.years,
            "annualSalary": rookieOffer.annualSalary,
            "signingBonus": rookieOffer.signingBonus as Any,
            "contractKind": rookieOffer.contractKind.rawValue,
            "phase": rookie.snapshot.phase.rawValue,
            "stateCommitment": rookie.snapshot.commitment,
        ],
        canonical: rookieCanonical
    ))

    let reviewed = try playSeason(rookie, engine: engine, salt: 1)
    let settlement = reviewed.snapshot.journeyState!.lastSettlement!
    let settlementCanonical = [
        settlement.id, String(settlement.season), settlement.teamID, String(settlement.salaryIncome),
        String(settlement.merchandiseIncome), String(settlement.fanBefore), String(settlement.fanAfter),
        String(settlement.fanDelta), String(settlement.teamLegacyBefore), String(settlement.teamLegacyAfter),
        String(settlement.hallOfFameBefore), String(settlement.hallOfFameAfter), String(settlement.contractYearsBefore),
        String(settlement.contractYearsAfter), settlement.nextRoute.rawValue,
    ].joined(separator: "|")
    rows.append(row(
        "season_settlement",
        input: "command:plan_week*|command:resolve_game*|command:review_season|seed_chain:next",
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
            "stateCommitment": reviewed.snapshot.commitment,
            "fanReasonIDs": settlement.fanReasons.map(\.id).sorted(),
        ],
        canonical: settlementCanonical
    ))

    let acknowledged = try engine.acknowledgeSettlement(.init(seed: reviewed.nextSeed, state: reviewed.snapshot, expectedRevision: reviewed.snapshot.revision, settlementID: settlement.id))
    let transition = try engine.chooseOffseason(.init(seed: acknowledged.nextSeed, state: acknowledged.snapshot, decision: .continueCareer, expectedRevision: acknowledged.snapshot.revision))
    let invested = try engine.chooseInvestment(.init(seed: transition.nextSeed, state: transition.snapshot, expectedRevision: transition.snapshot.revision, investment: .pitchLab, focus: .command))
    let investmentTransaction = invested.snapshot.journeyState!.finances.transactions.first(where: { $0.kind == .investment })!
    let investmentCanonical = [investmentTransaction.id, String(investmentTransaction.amount), String(invested.snapshot.journeyState!.finances.availableFunds), String(invested.snapshot.season), invested.snapshot.phase.rawValue].joined(separator: "|")
    rows.append(row(
        "investment",
        input: "settlement:1|acknowledge|offseason:continue|investment:pitch_lab|focus:command",
        output: [
            "transactionID": investmentTransaction.id,
            "amount": investmentTransaction.amount,
            "availableFunds": invested.snapshot.journeyState!.finances.availableFunds,
            "investmentSeason": invested.snapshot.journeyState!.finances.investmentSeason as Any,
            "developmentFocus": invested.snapshot.developmentProgress?.command as Any,
            "phase": invested.snapshot.phase.rawValue,
            "nextSeed": invested.nextSeed,
            "stateCommitment": invested.snapshot.commitment,
        ],
        canonical: investmentCanonical
    ))

    let marketFixtureState = invested.snapshot
    let renewalMarket = ProContractMarketRules.renewalMarket(state: marketFixtureState)
        ?? ProContractMarketRules.makeRenewalMarket(
            careerID: marketFixtureState.proCareerID,
            team: marketFixtureState.team,
            pitcher: marketFixtureState.pitcher,
            level: marketFixtureState.level,
            role: marketFixtureState.role,
            previousStats: marketFixtureState.currentStats,
            marketScore: 65,
            forSeason: marketFixtureState.season + 1,
            generatedAtRevision: marketFixtureState.revision,
            maximumCareerSeasons: ProCareerEngine.maximumCareerSeasons
        )
    if let renewalMarket {
        rows.append(row(
            "renewal_market",
            input: "rules:renewal_market|state:journey|season:\(marketFixtureState.season)|role:\(marketFixtureState.role.rawValue)",
            output: [
                "marketID": renewalMarket.id,
                "kind": renewalMarket.kind.rawValue,
                "offerCount": renewalMarket.offers.count,
                "canonicalRows": renewalMarket.offers.map { $0.id + ":" + String($0.years) + ":" + String($0.annualSalary) + ":" + $0.rolePromise.rawValue + ":" + $0.expectation.difficulty.rawValue },
            ],
            canonical: marketCanonical(renewalMarket)
        ))
    }

    let freeAgencyMarket = ProContractMarketRules.freeAgencyMarket(state: marketFixtureState)
        ?? ProContractMarketRules.makeFreeAgencyMarket(
            careerID: marketFixtureState.proCareerID,
            currentTeam: marketFixtureState.team,
            pitcher: marketFixtureState.pitcher,
            level: marketFixtureState.level,
            role: marketFixtureState.role,
            previousStats: marketFixtureState.currentStats,
            marketScore: 65,
            fanSupport: marketFixtureState.journeyState?.reputation.fanSupport ?? 30,
            forSeason: marketFixtureState.season + 1,
            generatedAtRevision: marketFixtureState.revision,
            maximumCareerSeasons: ProCareerEngine.maximumCareerSeasons
        )
    if let freeAgencyMarket {
        rows.append(row(
            "free_agency_market",
            input: "rules:free_agency_market|state:journey|season:\(marketFixtureState.season)|serviceYears:\(marketFixtureState.serviceYears)",
            output: [
                "marketID": freeAgencyMarket.id,
                "kind": freeAgencyMarket.kind.rawValue,
                "offerCount": freeAgencyMarket.offers.count,
                "teams": freeAgencyMarket.offers.map(\.teamID),
                "canonicalRows": freeAgencyMarket.offers.map { $0.id + ":" + String($0.years) + ":" + String($0.annualSalary) + ":" + $0.rolePromise.rawValue + ":" + $0.outlook.rawValue },
            ],
            canonical: marketCanonical(freeAgencyMarket)
        ))
    }

    var mediaReviewed: ProCareerResult?
    for candidate in 620010...620040 where mediaReviewed == nil {
        let candidateStarted = try start(seed: String(candidate), sourceFanInterest: 30)
        let candidateRookie = try accept(candidateStarted, engine: engine, ambition: .recordBook)
        let candidateSettlement = try playSeason(candidateRookie, engine: engine, salt: candidate)
        let candidateAcknowledged = try engine.acknowledgeSettlement(.init(seed: candidateSettlement.nextSeed, state: candidateSettlement.snapshot, expectedRevision: candidateSettlement.snapshot.revision, settlementID: candidateSettlement.snapshot.journeyState!.lastSettlement!.id))
        let candidateTransition = try engine.chooseOffseason(.init(seed: candidateAcknowledged.nextSeed, state: candidateAcknowledged.snapshot, decision: .continueCareer, expectedRevision: candidateAcknowledged.snapshot.revision))
        let candidateSeason = try engine.chooseInvestment(.init(seed: candidateTransition.nextSeed, state: candidateTransition.snapshot, expectedRevision: candidateTransition.snapshot.revision, investment: .fanFoundation))
        let candidateReviewed = try playSeason(candidateSeason, engine: engine, salt: candidate, preferMediaChoice: true)
        if candidateReviewed.snapshot.decisionHistory?.contains(where: { $0.type == .mediaOpportunity }) == true {
            mediaReviewed = candidateReviewed
        }
    }
    guard let mediaReviewed else { throw NSError(domain: "ProFixtureV2", code: 13) }
    let mediaRecord = mediaReviewed.snapshot.decisionHistory?.last(where: { $0.type == .mediaOpportunity })
    let endorsement = mediaReviewed.snapshot.journeyState?.finances.transactions.last(where: { $0.kind == .endorsement })
    let mediaCanonical = [mediaRecord?.decisionID ?? "none", mediaRecord?.choiceID ?? "none", endorsement?.id ?? "none", String(endorsement?.amount ?? 0), String(mediaReviewed.snapshot.journeyState?.reputation.fanSupport ?? 0)].joined(separator: "|")
    rows.append(row(
        "fan_finance_media",
        input: "fanFoundation|fan>=35|mediaSlot:stable_hash|choice:fan_together_shoot",
        output: [
            "mediaDecisionID": mediaRecord?.decisionID as Any,
            "mediaChoiceID": mediaRecord?.choiceID as Any,
            "endorsementTransactionID": endorsement?.id as Any,
            "endorsementAmount": endorsement?.amount as Any,
            "fanSupport": mediaReviewed.snapshot.journeyState?.reputation.fanSupport as Any,
            "communityPoints": mediaReviewed.snapshot.journeyState?.teamRecords.first(where: { $0.teamID == mediaReviewed.snapshot.team.id })?.communityPoints as Any,
            "nextSeed": mediaReviewed.nextSeed,
        ],
        canonical: mediaCanonical
    ))

    let preview = ProRetirementRules.preview(for: mediaReviewed.snapshot)
    let currentRecord = mediaReviewed.snapshot.journeyState?.teamRecords.first(where: { $0.teamID == mediaReviewed.snapshot.team.id })
    let legacyCanonical = [
        mediaReviewed.snapshot.team.id,
        String(currentRecord?.completedSeasons ?? 0),
        String(currentRecord.map(ProTeamLegacyRules.score(record:)) ?? 0),
        String(preview.finalScore),
        preview.honors.map(\.kind.rawValue).joined(separator: ","),
        preview.completedAmbitions.map(\.rawValue).joined(separator: ","),
    ].joined(separator: "|")
    rows.append(row(
        "team_legacy_ambition_honors",
        input: "projection:retirement|teamRecords:typed|goalHistory:typed|honors:stable_order",
        output: [
            "teamID": mediaReviewed.snapshot.team.id,
            "teamSeasons": currentRecord?.completedSeasons as Any,
            "teamLegacy": currentRecord.map(ProTeamLegacyRules.score(record:)) as Any,
            "hallOfFameProjection": preview.finalScore,
            "retiredNumberEligible": preview.retiredNumberEligible,
            "clubHallTeamIDs": preview.clubHallTeamIDs,
            "completedAmbitions": preview.completedAmbitions.map(\.rawValue),
            "honorKinds": preview.honors.map(\.kind.rawValue),
        ],
        canonical: legacyCanonical
    ))

    let positiveEngine = ProCareerEngine(journeyEnabled: true)
    let positiveInput = try positiveRetirementFixture(engine: positiveEngine)
    let positiveRetirement = try positiveEngine.chooseOffseason(.init(
        seed: "620050",
        state: positiveInput.state,
        decision: .retire,
        expectedRevision: positiveInput.state.revision
    ))
    let positiveJourney = positiveRetirement.snapshot.journeyState!
    let positivePreview = ProRetirementRules.preview(for: positiveRetirement.snapshot)
    let completedWires = positiveJourney.goalHistory
        .filter { $0.outcome == .completed }
        .map { $0.ambition.rawValue }
        .sorted()
    let positiveHonorRows: [[String: Any]] = positiveJourney.retirementHonors.map { honor in
        [
            "id": honor.id,
            "kind": honor.kind.rawValue,
            "teamID": honor.teamID ?? NSNull(),
            "referenceID": honor.referenceID ?? NSNull(),
            "value": honor.value ?? NSNull(),
        ]
    }
    let positiveCanonical = [
        "command:choose_offseason.retire",
        "input:valid_constructed_signed_state",
        "careerID:\(positiveRetirement.snapshot.proCareerID)",
        "season:\(positiveRetirement.snapshot.season)",
        "team:\(positivePreview.lastTeamSeasons):\(positivePreview.lastTeamLegacy)",
        "hof:\(positivePreview.finalScore)",
        "ambitions:\(completedWires.joined(separator: ","))",
        "honors:\(positiveJourney.retirementHonors.map(\.id).joined(separator: ","))",
    ].joined(separator: "|")
    rows.append(row(
        "positive_retirement_semantics",
        input: "command:choose_offseason.retire|input:valid_constructed_signed_state|semantic_inputs:canonical",
        output: [
            "execution": "command:choose_offseason.retire",
            "inputKind": "valid_constructed_signed_state",
            "pureRuleProjection": "ProRetirementRules.preview(command_output)",
            "phase": positiveRetirement.snapshot.phase.rawValue,
            "hallOfFameScore": positiveRetirement.snapshot.hallOfFameScore as Any,
            "lastTeamSeasons": positivePreview.lastTeamSeasons,
            "lastTeamLegacy": positivePreview.lastTeamLegacy,
            "fanSupport": positivePreview.fanSupport,
            "retiredNumberEligible": positivePreview.retiredNumberEligible,
            "completedAmbitionWires": completedWires,
            "allThreeAmbitionsCompleted": completedWires.count == 3,
            "honorKinds": positiveJourney.retirementHonors.map(\.kind.rawValue),
            "honors": positiveHonorRows,
            "canonicalSemanticInputs": positiveInput.canonicalInputs,
        ],
        canonical: positiveCanonical
    ))

    let legacyEngine = ProCareerEngine()
    let legacyStarted = try start(seed: "620007", journeyEnabled: false)
    let legacySigned = try legacyEngine.signContract(.init(seed: legacyStarted.nextSeed, state: legacyStarted.snapshot))
    let legacyReviewReady = try playUntilSeasonReview(legacySigned, engine: legacyEngine, salt: 7)
    let migrated = try ProCareerEngine(journeyEnabled: true).migrateJourneyIfSafe(.init(seed: legacyReviewReady.nextSeed, state: legacyReviewReady.snapshot))
    let migration = migrated.snapshot.journeyState!.migration
    let migrationCanonical = [migration.source.rawValue, String(migration.initializedSeason), String(migration.financeStartsSeason), String(migration.unassignedLegacyAwards), migration.financeNoticePending ? "1" : "0", migrated.snapshot.phase.rawValue].joined(separator: "|")
    rows.append(row(
        "legacy_migration",
        input: "legacy:start|legacy:sign_contract|legacy:season_review|migrate:safe_boundary|seedless:true",
        output: [
            "source": migration.source.rawValue,
            "initializedSeason": migration.initializedSeason,
            "financeStartsSeason": migration.financeStartsSeason,
            "unassignedLegacyAwards": migration.unassignedLegacyAwards,
            "financeNoticePending": migration.financeNoticePending,
            "phase": migrated.snapshot.phase.rawValue,
            "salaryTransactions": migrated.snapshot.journeyState!.finances.transactions.filter { $0.kind == .salary }.count,
            "nextSeed": migrated.nextSeed,
            "stateCommitment": migrated.snapshot.commitment,
        ],
        canonical: migrationCanonical
    ))

    let staleRevisionError = errorID {
        _ = try engine.acceptContract(.init(seed: "620099", state: rookie.snapshot, expectedRevision: rookie.snapshot.revision + 1, marketID: rookieMarket.id, offerID: rookieOffer.id, ambition: .recordBook))
    }
    let invalidOfferStarted = try start(seed: "620002")
    let invalidOfferMarket = invalidOfferStarted.snapshot.journeyState!.pendingContractMarket!
    let invalidOfferError = errorID {
        _ = try engine.acceptContract(.init(
            seed: invalidOfferStarted.nextSeed,
            state: invalidOfferStarted.snapshot,
            expectedRevision: invalidOfferStarted.snapshot.revision,
            marketID: invalidOfferMarket.id,
            offerID: "offer:not-present",
            ambition: .recordBook
        ))
    }
    let invalidSettlementError = errorID {
        _ = try engine.acknowledgeSettlement(.init(
            seed: reviewed.nextSeed,
            state: reviewed.snapshot,
            expectedRevision: reviewed.snapshot.revision,
            settlementID: "settlement:not-present"
        ))
    }
    let commandErrors = [staleRevisionError, invalidOfferError, invalidSettlementError]
    rows.append(row(
        "command_errors",
        input: "accept_contract:stale_revision|accept_contract:invalid_offer|acknowledge_settlement:invalid_id",
        output: ["errorIDs": commandErrors],
        canonical: commandErrors.joined(separator: "|")
    ))

    let deterministicCanonical = [rookie.nextSeed, rookie.snapshot.commitment, reviewed.nextSeed, reviewed.snapshot.commitment, invested.nextSeed, invested.snapshot.commitment].joined(separator: "|")
    rows.append(row(
        "deterministic_next_seed_commitment",
        input: "replay:seed=620001|commands:accept,season_settlement,investment",
        output: [
            "nextSeeds": [rookie.nextSeed, reviewed.nextSeed, invested.nextSeed],
            "commitments": [rookie.snapshot.commitment, reviewed.snapshot.commitment, invested.snapshot.commitment],
            "replayCanonicalSha256": sha256(deterministicCanonical),
        ],
        canonical: deterministicCanonical
    ))

    let finalRows = rows.sorted { $0.id < $1.id }
    return finalRows
}

private extension ProCareerSnapshot {
    var nextSeedEvidence: String { commitment }
}

private func writeFixture(to path: String, rows: [FixtureRow]) throws {
    let inputCanonical = [
        "fixture:ProCareerEngine.JourneyWave6", "journeyEnabled:true", "commands:start,accept,planWeek,resolveImportantGame,applySeasonDecision,reviewSeason,acknowledgeSettlement,chooseOffseason,chooseInvestment,applyMediaChoice,retire,migrate", "cases:rookie_contract,season_settlement,investment,renewal_market,free_agency_market,fan_finance_media,team_legacy_ambition_honors,positive_retirement_semantics,legacy_migration,command_errors,deterministic_next_seed_commitment", "stateFields:stableIDs,rawEnums,decimalMoney,canonicalCommitment", "locale:independent", "timezone:UTC",
    ].joined(separator: "|")
    let outputCanonical = rows.map { "\($0.id)|\($0.outputCanonical)\n" }.joined()
    let root: [String: Any] = [
        "fixtureSchema": schema,
        "sourceRuntime": "swift",
        "sourceRevision": sourceRevision,
        "inputSha256": sha256(inputCanonical),
        "outputSha256": sha256(outputCanonical),
        "authorityScope": "swift-journey-semantic-oracle",
        "input": [
            "fixture": "ProCareerEngine.JourneyWave6",
            "journeyEnabled": true,
            "commandWire": ["start", "accept_contract", "plan_week", "resolve_important_game", "apply_season_decision", "review_season", "acknowledge_settlement", "choose_offseason", "choose_investment", "apply_media_choice", "retire", "migrate"],
            "locale": "stable_ids_only",
            "timezone": "UTC",
        ],
        "expected": [
            "exactRuns": rows.count,
            "canonicalRow": "caseID|outputCanonical\\n",
            "rows": rows.map { ["caseID": $0.id, "inputCanonical": $0.inputCanonical, "inputSha256": sha256($0.inputCanonical), "outputCanonical": $0.outputCanonical, "outputSha256": sha256($0.outputCanonical), "wireCommitment": sha256($0.outputCanonical), "output": $0.output] },
        ],
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
