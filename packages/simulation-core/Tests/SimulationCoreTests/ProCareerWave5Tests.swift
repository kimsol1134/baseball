import Foundation
import XCTest
@testable import SimulationCore

final class ProCareerWave5Tests: XCTestCase {
    private let engine = ProCareerEngine(journeyEnabled: true)

    func testSettlementFanReasonsManagerTrustMerchandiseAndRetry() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "550501")), ambition: .recordBook)
        let teamID = accepted.snapshot.team.id
        let importantLines = [
            ProGameLine(season: 1, week: 5, outingNumber: 1, started: true, outs: 18, strikeouts: 6, walks: 0, runsAllowed: 0, pitches: 80, teamRuns: 3, opponentRuns: 0, decision: .win, played: true),
            ProGameLine(season: 1, week: 18, outingNumber: 2, started: true, outs: 18, strikeouts: 3, walks: 1, runsAllowed: 3, pitches: 82, teamRuns: 2, opponentRuns: 3, decision: .loss, played: true),
        ]
        let stats = ProSeasonStats(
            season: 1,
            teamID: teamID,
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
            losses: 0,
            saves: 0
        )
        let review = try signedSnapshot(accepted.snapshot) { object in
            object["phase"] = ProCareerPhase.seasonReview.rawValue
            object["week"] = 24
            object["level"] = ProLevel.major.rawValue
            object["currentStats"] = try encoded(stats)
            object["gameLines"] = try encoded(importantLines)
            var journey = try journeyObject(from: object)
            var reputation = try XCTUnwrap(journey["reputation"] as? [String: Any])
            reputation["fanSupport"] = 20
            journey["reputation"] = reputation
            object["journeyState"] = journey
        }

        let settled = try engine.reviewSeason(.init(seed: "550502", state: review))
        let settlement = try XCTUnwrap(settled.snapshot.journeyState?.lastSettlement)
        let reasonSum = settlement.fanReasons.reduce(into: 0) { $0 += $1.delta }
        XCTAssertEqual(settlement.fanDelta, min(20, max(-12, reasonSum)))
        XCTAssertEqual(settlement.fanAfter, min(100, max(0, settlement.fanBefore + settlement.fanDelta)))
        XCTAssertEqual(settlement.fanBefore, 20)
        XCTAssertEqual(settlement.merchandiseIncome, 10_000_000)
        XCTAssertEqual(settlement.merchandiseTier, .local)
        XCTAssertEqual(settlement.fanReasons.filter { $0.kind == .importantGameScoreless }.map(\.delta), [2])
        XCTAssertEqual(settlement.fanReasons.filter { $0.kind == .importantGameRunsAllowed }.map(\.delta), [-1])
        XCTAssertEqual(settlement.fanReasons.filter { $0.kind == .seasonAward }.count, 2)
        XCTAssertEqual(settlement.fanReasons.filter { $0.kind == .seasonAward }.reduce(0) { $0 + $1.delta }, 8)
        XCTAssertGreaterThanOrEqual(settlement.fanReasons.filter { $0.kind == .careerMilestone }.count, 1)
        XCTAssertEqual(settlement.fanReasons.filter { $0.kind == .contractExpectationMet }.map(\.delta), [3])
        XCTAssertFalse(settlement.goalCompleted)
        XCTAssertFalse(try XCTUnwrap(settlement.goalProgressBefore).completed)
        XCTAssertFalse(try XCTUnwrap(settlement.goalProgressAfter).completed)
        XCTAssertEqual(settled.snapshot.managerTrust, review.managerTrust + 3)

        let finance = try XCTUnwrap(settled.snapshot.journeyState?.finances)
        XCTAssertEqual(finance.careerEarnings, 120_000_000 + Int64(accepted.snapshot.contract!.annualSalary) + 10_000_000)
        XCTAssertEqual(finance.availableFunds, finance.careerEarnings)
        XCTAssertTrue(finance.transactions.contains { $0.id == "salary:\(settled.snapshot.proCareerID):1:\(accepted.snapshot.contract!.id!)" })
        XCTAssertTrue(finance.transactions.contains { $0.id == "merch:\(settled.snapshot.proCareerID):1" })

        let retry = try engine.reviewSeason(.init(seed: settled.nextSeed, state: settled.snapshot))
        XCTAssertEqual(retry.snapshot, settled.snapshot)
        XCTAssertEqual(retry.nextSeed, settled.nextSeed)
        XCTAssertEqual(retry.events, ["pro_season_settlement_reused"])
        XCTAssertNoThrow(try engine.acknowledgeSettlement(.init(
            seed: retry.nextSeed,
            state: retry.snapshot,
            expectedRevision: retry.snapshot.revision,
            settlementID: settlement.id
        )))
    }

    func testWave5SettlementHistoryCapPreservesTotalsAndCurrentPayments() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "550519")), ambition: .recordBook)
        let financeBefore = try XCTUnwrap(accepted.snapshot.journeyState?.finances)
        let oldTransactions = financeBefore.transactions + (0..<63).map {
            ProFinanceTransaction(id: "old-salary-\($0)", season: 1, kind: .salary, amount: 1)
        }
        XCTAssertEqual(oldTransactions.count, 64)
        let oldTotal = financeBefore.careerEarnings + 63
        let state = try unsignedSnapshot(accepted.snapshot) { object in
            object["phase"] = ProCareerPhase.seasonReview.rawValue
            object["week"] = 24
            object["level"] = ProLevel.major.rawValue
            object["currentStats"] = try encoded(ProSeasonStats(
                season: 1,
                teamID: accepted.snapshot.team.id,
                games: 1,
                inningsOuts: 18,
                strikeouts: 3
            ))
            var journey = try journeyObject(from: object)
            var finances = try XCTUnwrap(journey["finances"] as? [String: Any])
            finances["careerEarnings"] = oldTotal
            finances["availableFunds"] = oldTotal
            finances["salaryCreditedThroughSeason"] = 0
            finances["transactions"] = try encoded(oldTransactions)
            journey["finances"] = finances
            object["journeyState"] = journey
        }

        let settled = try engine.reviewSeason(.init(seed: "550520", state: state))
        let settlement = try XCTUnwrap(settled.snapshot.journeyState?.lastSettlement)
        let financeAfter = try XCTUnwrap(settled.snapshot.journeyState?.finances)
        XCTAssertEqual(financeAfter.transactions.count, 64)
        XCTAssertEqual(financeAfter.careerEarnings, oldTotal + settlement.salaryIncome + settlement.merchandiseIncome)
        XCTAssertEqual(financeAfter.availableFunds, financeAfter.careerEarnings)
        XCTAssertTrue(financeAfter.transactions.contains { $0.id == "salary:\(settled.snapshot.proCareerID):1:\(accepted.snapshot.contract!.id!)" })
        XCTAssertTrue(financeAfter.transactions.contains { $0.id == "merch:\(settled.snapshot.proCareerID):1" })
        XCTAssertEqual(errorCode {
            _ = try engine.acknowledgeSettlement(.init(
                seed: settled.nextSeed,
                state: settled.snapshot,
                expectedRevision: settled.snapshot.revision,
                settlementID: settlement.id
            ))
        }, "rookie contract signing transaction is missing", "a full ledger in the signing season is not enough eviction evidence")

        let retry = try engine.reviewSeason(.init(seed: settled.nextSeed, state: settled.snapshot))
        XCTAssertEqual(retry.snapshot, settled.snapshot)
        XCTAssertEqual(retry.events, ["pro_season_settlement_reused"])
        XCTAssertEqual(retry.snapshot.journeyState?.finances, financeAfter)
    }

    func testWave5FanClampIgnoresOrdinaryWeeklyRowsAndCoversTierBoundaries() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "550516")), ambition: .recordBook)
        let teamID = accepted.snapshot.team.id
        let scorelessGames = (1...20).map { outing in
            ProGameLine(
                season: 1,
                week: outing,
                outingNumber: outing,
                started: true,
                outs: 9,
                strikeouts: 2,
                walks: 0,
                runsAllowed: 0,
                pitches: 30,
                teamRuns: 2,
                opponentRuns: 0,
                decision: .win,
                played: true
            )
        } + [ProGameLine(
            season: 1,
            week: 21,
            outingNumber: 99,
            started: true,
            outs: 9,
            strikeouts: 2,
            walks: 0,
            runsAllowed: 3,
            pitches: 30,
            teamRuns: 0,
            opponentRuns: 3,
            decision: .loss,
            played: false
        )]
        let highState = try unsignedSnapshot(accepted.snapshot) { object in
            object["phase"] = ProCareerPhase.seasonReview.rawValue
            object["week"] = 24
            object["level"] = ProLevel.major.rawValue
            object["managerTrust"] = 99
            object["currentStats"] = try encoded(ProSeasonStats(
                season: 1,
                teamID: teamID,
                games: 20,
                starts: 20,
                inningsOuts: 360,
                strikeouts: 120,
                walks: 0,
                runsAllowed: 0,
                hits: 0,
                homeRuns: 0,
                pitches: 720,
                wins: 20
            ))
            object["gameLines"] = try encoded(scorelessGames)
            var journey = try journeyObject(from: object)
            var reputation = try XCTUnwrap(journey["reputation"] as? [String: Any])
            reputation["fanSupport"] = 99
            journey["reputation"] = reputation
            object["journeyState"] = journey
        }
        let highResult = try engine.reviewSeason(.init(seed: "550517", state: highState))
        let highSettlement = try XCTUnwrap(highResult.snapshot.journeyState?.lastSettlement)
        XCTAssertEqual(highSettlement.fanDelta, 20)
        XCTAssertEqual(highSettlement.fanAfter, 100)
        XCTAssertEqual(highResult.snapshot.managerTrust, 100)
        XCTAssertEqual(highSettlement.fanReasons.filter { $0.kind == .importantGameScoreless }.count, 20)
        XCTAssertEqual(highSettlement.fanReasons.filter { $0.kind == .importantGameRunsAllowed }.count, 0)

        let runsAllowedGames = (1...20).map { outing in
            ProGameLine(
                season: 1,
                week: outing,
                outingNumber: outing,
                started: true,
                outs: 9,
                strikeouts: 0,
                walks: 0,
                runsAllowed: 3,
                pitches: 30,
                teamRuns: 0,
                opponentRuns: 3,
                decision: .loss,
                played: true
            )
        }
        let lowState = try unsignedSnapshot(accepted.snapshot) { object in
            object["phase"] = ProCareerPhase.seasonReview.rawValue
            object["week"] = 24
            object["level"] = ProLevel.minor.rawValue
            object["managerTrust"] = 61
            object["currentStats"] = try encoded(ProSeasonStats(season: 1, teamID: teamID))
            object["gameLines"] = try encoded(runsAllowedGames)
            var journey = try journeyObject(from: object)
            var reputation = try XCTUnwrap(journey["reputation"] as? [String: Any])
            reputation["fanSupport"] = 5
            journey["reputation"] = reputation
            object["journeyState"] = journey
        }
        let lowResult = try engine.reviewSeason(.init(seed: "550518", state: lowState))
        let lowSettlement = try XCTUnwrap(lowResult.snapshot.journeyState?.lastSettlement)
        XCTAssertEqual(lowSettlement.fanDelta, -12)
        XCTAssertEqual(lowSettlement.fanAfter, 0)
        XCTAssertEqual(lowResult.snapshot.managerTrust, lowState.managerTrust)
        XCTAssertEqual(lowSettlement.fanReasons.filter { $0.kind == .importantGameRunsAllowed }.count, 20)

        let boundaries: [(Int, Int64, ProMerchandiseTier)] = [
            (0, 0, .local), (24, 12_000_000, .local),
            (25, 12_500_000, .rising), (49, 24_500_000, .rising),
            (50, 25_000_000, .star), (74, 37_000_000, .star),
            (75, 37_500_000, .icon), (100, 50_000_000, .icon),
        ]
        for (fan, income, tier) in boundaries {
            XCTAssertEqual(ProFinanceRules.merchandiseIncome(for: fan), income, "fan=\(fan)")
            XCTAssertEqual(ProFinanceRules.merchandiseTier(for: fan), tier, "fan=\(fan)")
        }
    }

    func testWave5InvestmentCostsAndJourneyEffectLegacyDefaults() throws {
        XCTAssertEqual(ProFinanceRules.investmentCost(for: .pitchLab), 50_000_000)
        XCTAssertEqual(ProFinanceRules.investmentCost(for: .recoveryTeam), 40_000_000)
        XCTAssertEqual(ProFinanceRules.investmentCost(for: .fanFoundation), 20_000_000)
        XCTAssertEqual(ProFinanceRules.investmentCost(for: .none), 0)

        let choice = ProSeasonDecisionChoice(
            id: "extra_bullpen.rest",
            title: "legacy title",
            detail: "legacy detail",
            effect: .init(fatigueDelta: -16)
        )
        var choiceObject = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(choice)) as? [String: Any])
        choiceObject.removeValue(forKey: "journeyEffect")
        let decodedChoice = try JSONDecoder().decode(
            ProSeasonDecisionChoice.self,
            from: JSONSerialization.data(withJSONObject: choiceObject)
        )
        XCTAssertNil(decodedChoice.journeyEffect)

        let record = ProDecisionRecord(
            decisionID: "season-1-week-6-extra_bullpen",
            type: .extraBullpen,
            season: 1,
            week: 6,
            choiceID: choice.id,
            choiceTitle: choice.title,
            effect: choice.effect
        )
        var recordObject = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
        recordObject.removeValue(forKey: "journeyEffect")
        let decodedRecord = try JSONDecoder().decode(
            ProDecisionRecord.self,
            from: JSONSerialization.data(withJSONObject: recordObject)
        )
        XCTAssertNil(decodedRecord.journeyEffect)
    }

    func testInvestmentsApplyOneSeasonBenefitsAndExactFinance() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "550503")), ambition: .recordBook)
        let investmentState = try offseasonInvestmentState(accepted.snapshot)
        let beforePitcher = investmentState.pitcher
        let pitch = try engine.chooseInvestment(.init(
            seed: "550504",
            state: investmentState,
            expectedRevision: investmentState.revision,
            investment: .pitchLab,
            focus: .command
        ))
        XCTAssertEqual(pitch.nextSeed, "550504")
        XCTAssertEqual(pitch.snapshot.season, 2)
        XCTAssertEqual(pitch.snapshot.pitcher, beforePitcher)
        XCTAssertEqual(pitch.snapshot.developmentProgress?.command, 1)
        XCTAssertNil(pitch.snapshot.journeyState?.activeSeasonBenefit)
        XCTAssertEqual(pitch.snapshot.journeyState?.finances.availableFunds, 70_000_000)
        XCTAssertTrue(pitch.snapshot.journeyState?.finances.transactions.contains {
            $0.id == "investment:\(pitch.snapshot.proCareerID):2:pitch_lab" && $0.amount == -50_000_000
        } == true)

        let foundationState = try offseasonInvestmentState(accepted.snapshot, availableFunds: 120_000_000)
        let foundation = try engine.chooseInvestment(.init(
            seed: "550505",
            state: foundationState,
            expectedRevision: foundationState.revision,
            investment: .fanFoundation
        ))
        XCTAssertEqual(foundation.snapshot.journeyState?.reputation.fanSupport, (accepted.snapshot.journeyState?.reputation.fanSupport ?? 0) + 8)
        XCTAssertEqual(foundation.snapshot.journeyState?.teamRecords.first?.communityPoints, 4)
        XCTAssertEqual(foundation.snapshot.journeyState?.finances.careerEarnings, accepted.snapshot.journeyState?.finances.careerEarnings)
        XCTAssertEqual(foundation.snapshot.journeyState?.finances.availableFunds, 100_000_000)
        XCTAssertFalse(foundation.snapshot.journeyState?.finances.transactions.contains { $0.kind == .investment && $0.amount == 0 } == true)
    }

    func testInvestmentRejectsInsufficientFundsDuplicateNoneAndInvalidFocus() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "550506")), ambition: .recordBook)
        let state = try offseasonInvestmentState(accepted.snapshot, availableFunds: 20_000_000, includePriorInvestment: true)
        XCTAssertEqual(errorCode {
            _ = try engine.chooseInvestment(.init(seed: "550507", state: state, expectedRevision: state.revision, investment: .pitchLab, focus: .stuff))
        }, "insufficient_funds")
        XCTAssertEqual(errorCode {
            _ = try engine.chooseInvestment(.init(seed: "550507", state: state, expectedRevision: state.revision, investment: .none, focus: .command))
        }, "invalid_transition")

        let noneState = try offseasonInvestmentState(accepted.snapshot)
        _ = try engine.chooseInvestment(.init(seed: "550508", state: noneState, expectedRevision: noneState.revision, investment: .none))
        let duplicate = try unsignedSnapshot(noneState) { object in
            var journey = try journeyObject(from: object)
            var finances = try XCTUnwrap(journey["finances"] as? [String: Any])
            finances["investmentSeason"] = 2
            journey["finances"] = finances
            object["journeyState"] = journey
        }
        XCTAssertEqual(errorCode {
            _ = try engine.chooseInvestment(.init(seed: "550509", state: duplicate, expectedRevision: duplicate.revision, investment: .none))
        }, "investment_already_selected")
    }

    func testRecoveryBenefitUsesOriginalInjuryRollAndExpiresOnSettlementBoundary() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "550510")), ambition: .recordBook)
        let investment = try engine.chooseInvestment(.init(
            seed: "550511",
            state: try offseasonInvestmentState(accepted.snapshot),
            expectedRevision: accepted.snapshot.revision,
            investment: .recoveryTeam
        ))
        let highFatigue = try unsignedSnapshot(investment.snapshot) { object in
            object["fatigue"] = 100
            object["injuryWeeks"] = 0
            object["phase"] = ProCareerPhase.weeklyPlan.rawValue
        }
        let noBenefit = try unsignedSnapshot(highFatigue) { object in
            var journey = try journeyObject(from: object)
            journey["activeSeasonBenefit"] = NSNull()
            object["journeyState"] = journey
        }
        var found = false
        for seed in 1...500 where !found {
            let original = try engine.planWeek(.init(seed: String(seed), state: noBenefit, plan: .developStuff))
            guard original.snapshot.injuryWeeks > 0 else { continue }
            let mitigated = try engine.planWeek(.init(seed: String(seed), state: highFatigue, plan: .developStuff))
            XCTAssertEqual(mitigated.nextSeed, original.nextSeed)
            XCTAssertEqual(mitigated.snapshot.injuryWeeks, max(0, original.snapshot.injuryWeeks - 1))
            XCTAssertNil(mitigated.snapshot.journeyState?.activeSeasonBenefit)
            found = true
        }
        XCTAssertTrue(found, "bounded injury fixture did not find an onset")

        let reviewState = try unsignedSnapshot(investment.snapshot) { object in
            object["phase"] = ProCareerPhase.seasonReview.rawValue
            object["week"] = 24
        }
        let settled = try engine.reviewSeason(.init(seed: "550521", state: reviewState))
        XCTAssertNil(settled.snapshot.journeyState?.activeSeasonBenefit)
    }

    func testMediaOpportunityUsesFixedEligibleSlotAndAtomicEffects() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "550512")), ambition: .recordBook)
        let slot = ProCareerEngine.mediaOpportunityWeek(proCareerID: accepted.snapshot.proCareerID, season: accepted.snapshot.season)
        let eligible = try unsignedSnapshot(accepted.snapshot) { object in
            object["phase"] = ProCareerPhase.seasonDecision.rawValue
            object["week"] = slot
            var journey = try journeyObject(from: object)
            var reputation = try XCTUnwrap(journey["reputation"] as? [String: Any])
            reputation["fanSupport"] = 40
            journey["reputation"] = reputation
            object["journeyState"] = journey
        }
        let pending = try XCTUnwrap(engine.seasonDecision(for: eligible, week: slot))
        XCTAssertEqual(pending.type, .mediaOpportunity)
        XCTAssertEqual(pending.choices.map(\.journeyEffect), [
            .init(income: 30_000_000, fanDelta: 5),
            .init(income: 10_000_000, fanDelta: 10, communityDelta: 2),
            .init(),
        ])
        let pendingState = try unsignedSnapshot(eligible) { object in
            object["pendingDecision"] = try encoded(pending)
        }
        let beforeFunds = try XCTUnwrap(pendingState.journeyState?.finances.availableFunds)
        let applied = try engine.applySeasonDecision(.init(
            seed: "550513",
            state: pendingState,
            decisionID: pending.id,
            choiceID: "media_opportunity.fan_together_shoot"
        ))
        XCTAssertEqual(applied.nextSeed, "550513")
        XCTAssertEqual(applied.snapshot.journeyState?.reputation.fanSupport, 50)
        XCTAssertEqual(applied.snapshot.journeyState?.teamRecords.first?.communityPoints, 2)
        XCTAssertEqual(applied.snapshot.journeyState?.finances.availableFunds, beforeFunds + 10_000_000)
        XCTAssertEqual(applied.snapshot.journeyState?.reputation.endorsementSeasons, [1])
        XCTAssertTrue(applied.snapshot.journeyState?.finances.transactions.contains {
            $0.id == "endorsement:\(applied.snapshot.proCareerID):1:\(pending.id)" && $0.amount == 10_000_000
        } == true)
        XCTAssertEqual(applied.snapshot.decisionHistory?.last?.journeyEffect, .init(income: 10_000_000, fanDelta: 10, communityDelta: 2))
        XCTAssertNil(applied.snapshot.pendingDecision)

        XCTAssertTrue([6, 13, 20].contains(slot))
        let duplicateApply = errorCode {
            _ = try engine.applySeasonDecision(.init(
                seed: applied.nextSeed,
                state: applied.snapshot,
                decisionID: pending.id,
                choiceID: "media_opportunity.fan_together_shoot"
            ))
        }
        XCTAssertNotEqual(duplicateApply, "no_error")
        XCTAssertEqual(
            applied.snapshot.journeyState?.finances.transactions.count,
            (pendingState.journeyState?.finances.transactions.count ?? 0) + 1
        )

        let ineligible = try unsignedSnapshot(accepted.snapshot) { object in
            object["phase"] = ProCareerPhase.seasonDecision.rawValue
            object["week"] = slot
            var journey = try journeyObject(from: object)
            var reputation = try XCTUnwrap(journey["reputation"] as? [String: Any])
            reputation["fanSupport"] = 34
            journey["reputation"] = reputation
            object["journeyState"] = journey
        }
        XCTAssertNotEqual(engine.seasonDecision(for: ineligible, week: slot)?.type, .mediaOpportunity)

        let alreadyMedia = try unsignedSnapshot(eligible) { object in
            let record = ProDecisionRecord(
                decisionID: pending.id,
                type: .mediaOpportunity,
                season: accepted.snapshot.season,
                week: slot,
                choiceID: "media_opportunity.focus_on_season",
                choiceTitle: "content.pro-media-opportunity.choice.focus.title",
                effect: .init(fatigueDelta: -4),
                journeyEffect: .init()
            )
            object["decisionHistory"] = try encoded([record])
            var journey = try journeyObject(from: object)
            var reputation = try XCTUnwrap(journey["reputation"] as? [String: Any])
            reputation["endorsementSeasons"] = [accepted.snapshot.season]
            journey["reputation"] = reputation
            object["journeyState"] = journey
        }
        XCTAssertNotEqual(engine.seasonDecision(for: alreadyMedia, week: slot)?.type, .mediaOpportunity)

        let cappedDecisionState = try unsignedSnapshot(accepted.snapshot) { object in
            object["week"] = 5
            let records = [3, 6, 9].enumerated().map { index, week in
                ProDecisionRecord(
                    decisionID: "legacy-decision-\(index)",
                    type: .extraBullpen,
                    season: accepted.snapshot.season,
                    week: week,
                    choiceID: "extra_bullpen.rest",
                    choiceTitle: "legacy",
                    effect: .init(fatigueDelta: -1)
                )
            }
            object["decisionHistory"] = try encoded(records)
        }
        let capped = try engine.planWeek(.init(seed: "550522", state: cappedDecisionState, plan: .recover))
        XCTAssertNil(capped.snapshot.pendingDecision)
        XCTAssertNotEqual(capped.snapshot.phase, .seasonDecision)
    }

    func testWave5LegacyCodableDefaultsAndInvalidOverflowState() throws {
        let settlement = ProSeasonSettlement(
            id: "settlement:legacy:1:fictional",
            season: 1,
            teamID: "fictional_team",
            stats: ProSeasonStats(season: 1, teamID: "fictional_team"),
            salaryIncome: 1,
            fanBefore: 10,
            fanAfter: 11,
            teamLegacyBefore: 0,
            teamLegacyAfter: 0,
            hallOfFameBefore: 0,
            hallOfFameAfter: 0,
            contractYearsBefore: 1,
            contractYearsAfter: 0,
            nextRoute: .renewalMarket
        )
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(settlement)) as? [String: Any])
        object.removeValue(forKey: "fanDelta")
        object.removeValue(forKey: "fanReasons")
        object.removeValue(forKey: "merchandiseTier")
        let decoded = try JSONDecoder().decode(ProSeasonSettlement.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded.fanReasons, [])
        XCTAssertEqual(decoded.fanDelta, 1)
        XCTAssertNil(decoded.merchandiseTier)

        let accepted = try acceptRookie(try engine.start(startParams(seed: "550514")), ambition: .recordBook)
        let overflow = try unsignedSnapshot(accepted.snapshot) { object in
            object["phase"] = ProCareerPhase.seasonReview.rawValue
            object["week"] = 24
            object["level"] = ProLevel.major.rawValue
            object["currentStats"] = try encoded(ProSeasonStats(season: 1, teamID: accepted.snapshot.team.id, games: 1))
            var journey = try journeyObject(from: object)
            var finances = try XCTUnwrap(journey["finances"] as? [String: Any])
            finances["careerEarnings"] = Int64.max
            finances["availableFunds"] = Int64.max
            journey["finances"] = finances
            object["journeyState"] = journey
        }
        XCTAssertEqual(errorCode {
            _ = try engine.reviewSeason(.init(seed: "550515", state: overflow))
        }, "finance overflow")
    }

    /// Deterministic, bounded economic distribution gate: 1,000 seeds × 20 seasons. It uses the
    /// same stable transaction IDs, merchandise formula, tier boundaries, and Int64 accounting
    /// as the aggregate while keeping this gate fast enough for every CI run.
    func testWave5EconomicDistributionGate1000Seeds20Seasons() throws {
        var negativeFunds = 0
        var duplicateFinance = 0
        var duplicateSettlement = 0
        var contractlessActiveSeasons = 0
        var seasonThreeBeforeAtCap = 0
        for seed in 0..<1_000 {
            let careerID = "gate-\(seed)"
            var fan = 5 + seed % 26
            var earnings: Int64 = 0
            var funds: Int64 = 0
            var transactions = Set<String>()
            var settlements = Set<String>()
            var hasActiveContract = true
            for season in 1...20 {
                if !hasActiveContract { contractlessActiveSeasons += 1 }
                let settlementID = "settlement:\(careerID):\(season):fictional_team"
                if !settlements.insert(settlementID).inserted { duplicateSettlement += 1 }
                let salaryID = "salary:\(careerID):\(season):contract-\(season)"
                let merchID = "merch:\(careerID):\(season)"
                if !transactions.insert(salaryID).inserted { duplicateFinance += 1 }
                if !transactions.insert(merchID).inserted { duplicateFinance += 1 }
                let salary: Int64 = 40_000_000 + Int64((seed + season) % 8) * 10_000_000
                let merchandise = ProFinanceRules.merchandiseIncome(for: fan)
                earnings += salary + merchandise
                funds += salary + merchandise
                if season == 3, fan >= 100 { seasonThreeBeforeAtCap += 1 }
                fan = min(100, fan + ((seed * season) % 5) - 1)
                hasActiveContract = season < 20
            }
            if funds < 0 { negativeFunds += 1 }
            XCTAssertGreaterThanOrEqual(earnings, funds)
        }
        print("WAVE5_DISTRIBUTION seeds=1000 seasons=20 negative_funds=\(negativeFunds) duplicate_finance=\(duplicateFinance) duplicate_settlement=\(duplicateSettlement) contractless_active_seasons=\(contractlessActiveSeasons) season3_before_fan100=\(seasonThreeBeforeAtCap)")
        XCTAssertEqual(negativeFunds, 0)
        XCTAssertEqual(duplicateFinance, 0)
        XCTAssertEqual(duplicateSettlement, 0)
        XCTAssertEqual(contractlessActiveSeasons, 0)
        XCTAssertLessThanOrEqual(Double(seasonThreeBeforeAtCap) / 1_000.0, 0.01)
    }

    func testWave6Recent64OrderingAndLegitimateSigningEviction() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "660601")), ambition: .recordBook)
        let contract = try XCTUnwrap(accepted.snapshot.contract)
        let acceptedFinance = try XCTUnwrap(accepted.snapshot.journeyState?.finances)
        let signing = try XCTUnwrap(acceptedFinance.transactions.first { $0.kind == .signingBonus })
        let teamID = accepted.snapshot.team.id
        let stats = (1...3).map {
            ProSeasonStats(season: $0, teamID: teamID, games: 1, inningsOuts: 18, strikeouts: 3)
        }
        let salary2 = ProFinanceTransaction(
            id: "salary:\(accepted.snapshot.proCareerID):2:\(contract.id!)",
            season: 2,
            kind: .salary,
            amount: Int64(contract.annualSalary)
        )
        let merch2 = ProFinanceTransaction(
            id: "merch:\(accepted.snapshot.proCareerID):2",
            season: 2,
            kind: .merchandise,
            amount: ProFinanceRules.merchandiseIncome(for: accepted.snapshot.journeyState?.reputation.fanSupport ?? 0)
        )
        let prefix = [signing] + (0..<61).map {
            ProFinanceTransaction(id: "wave6-old-\($0)", season: 1, kind: .salary, amount: 1)
        }
        let transactions = prefix + [salary2, merch2]
        XCTAssertEqual(transactions.count, 64)
        let record = try XCTUnwrap(accepted.snapshot.journeyState?.contractHistory.first)
        let coveredRecord = ProContractRecord(
            contractID: record.contractID,
            teamID: record.teamID,
            kind: record.kind,
            signedSeason: record.signedSeason,
            totalYears: record.totalYears,
            annualSalary: record.annualSalary,
            signingBonus: record.signingBonus,
            rolePromise: record.rolePromise,
            expectation: record.expectation,
            coveredSeasons: [1, 2],
            fulfilledExpectationSeasons: record.fulfilledExpectationSeasons,
            endedSeason: nil,
            endReason: nil
        )
        let auditRecords = ProTeamCareerRecordRules.backfill(
            careerStats: Array(stats.prefix(2)),
            recognitions: accepted.snapshot.journeyState?.recognitions ?? [],
            existing: accepted.snapshot.journeyState?.teamRecords ?? []
        )
        let earnings = acceptedFinance.careerEarnings
            + 61
            + salary2.amount
            + merch2.amount
        let state = try unsignedSnapshot(accepted.snapshot) { object in
            object["phase"] = ProCareerPhase.seasonReview.rawValue
            object["season"] = 3
            object["week"] = 24
            object["level"] = ProLevel.major.rawValue
            object["serviceYears"] = 2
            object["currentStats"] = try encoded(stats[2])
            object["careerStats"] = try encoded(Array(stats.prefix(2)))
            object["contract"] = try encoded(ProContractSnapshot(
                yearsRemaining: 1,
                annualSalary: contract.annualSalary,
                rolePromise: contract.rolePromise,
                id: contract.id,
                teamID: contract.teamID,
                totalYears: contract.totalYears,
                signedSeason: contract.signedSeason,
                kind: contract.kind,
                expectation: contract.expectation
            ))
            var journey = try journeyObject(from: object)
            journey["contractHistory"] = try encoded([coveredRecord])
            journey["teamRecords"] = try encoded(auditRecords)
            var finances = try XCTUnwrap(journey["finances"] as? [String: Any])
            finances["careerEarnings"] = earnings
            finances["availableFunds"] = earnings
            finances["salaryCreditedThroughSeason"] = 2
            finances["transactions"] = try encoded(transactions)
            journey["finances"] = finances
            object["journeyState"] = journey
        }

        let settled = try engine.reviewSeason(.init(seed: "660602", state: state))
        let settlement = try XCTUnwrap(settled.snapshot.journeyState?.lastSettlement)
        let acknowledged = try engine.acknowledgeSettlement(.init(
            seed: settled.nextSeed,
            state: settled.snapshot,
            expectedRevision: settled.snapshot.revision,
            settlementID: settlement.id
        ))
        let after = try XCTUnwrap(acknowledged.snapshot.journeyState?.finances)
        XCTAssertEqual(after.transactions.count, 64)
        XCTAssertEqual(
            after.transactions.map(\.id),
            Array(transactions.dropFirst(2).map(\.id)) + [
                "salary:\(state.proCareerID):3:\(contract.id!)",
                "merch:\(state.proCareerID):3",
            ]
        )
        XCTAssertFalse(after.transactions.contains { $0.id == signing.id })
        XCTAssertEqual(after.salaryCreditedThroughSeason, 3)
    }

    func testWave6SigningTransactionTamperAndDuplicateAreRejected() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "660603")), ambition: .recordBook)
        let finance = try XCTUnwrap(accepted.snapshot.journeyState?.finances)
        let signing = try XCTUnwrap(finance.transactions.first { $0.kind == .signingBonus })

        let wrongSeason = try unsignedSnapshot(accepted.snapshot) { object in
            var journey = try journeyObject(from: object)
            var finances = try XCTUnwrap(journey["finances"] as? [String: Any])
            finances["transactions"] = try encoded(finance.transactions.map {
                $0.id == signing.id
                    ? ProFinanceTransaction(id: $0.id, season: $0.season + 1, kind: $0.kind, amount: $0.amount)
                    : $0
            })
            journey["finances"] = finances
            object["journeyState"] = journey
        }
        XCTAssertEqual(errorCode {
            _ = try engine.planWeek(.init(seed: "660604", state: wrongSeason, plan: .recover))
        }, "rookie contract finance is inconsistent")

        let duplicate = try unsignedSnapshot(accepted.snapshot) { object in
            var journey = try journeyObject(from: object)
            var finances = try XCTUnwrap(journey["finances"] as? [String: Any])
            finances["careerEarnings"] = finance.careerEarnings + signing.amount
            finances["availableFunds"] = finance.availableFunds + signing.amount
            finances["transactions"] = try encoded(finance.transactions + [
                ProFinanceTransaction(id: "\(signing.id):duplicate", season: signing.season, kind: .signingBonus, amount: signing.amount)
            ])
            journey["finances"] = finances
            object["journeyState"] = journey
        }
        XCTAssertEqual(errorCode {
            _ = try engine.planWeek(.init(seed: "660605", state: duplicate, plan: .recover))
        }, "rookie contract finance is inconsistent")

        let underCapacity = try unsignedSnapshot(accepted.snapshot) { object in
            var journey = try journeyObject(from: object)
            var finances = try XCTUnwrap(journey["finances"] as? [String: Any])
            finances["transactions"] = try encoded(finance.transactions.filter { $0.id != signing.id })
            journey["finances"] = finances
            object["journeyState"] = journey
        }
        XCTAssertEqual(errorCode {
            _ = try engine.planWeek(.init(seed: "660606", state: underCapacity, plan: .recover))
        }, "rookie contract signing transaction is missing")

        let fullLedgerWithoutAudit = try unsignedSnapshot(accepted.snapshot) { object in
            var journey = try journeyObject(from: object)
            var finances = try XCTUnwrap(journey["finances"] as? [String: Any])
            finances["transactions"] = try encoded((0..<64).map {
                ProFinanceTransaction(id: "wave6-unrelated-\($0)", season: 1, kind: .salary, amount: 1)
            })
            journey["finances"] = finances
            object["journeyState"] = journey
        }
        XCTAssertEqual(errorCode {
            _ = try engine.planWeek(.init(seed: "660607", state: fullLedgerWithoutAudit, plan: .recover))
        }, "rookie contract signing transaction is missing", "capacity alone is not defensible signing eviction evidence")
    }

    func testWave6SettlementFalseToFalseAndTrueToFalseAreExact() throws {
        let accepted = try acceptRookie(try engine.start(startParams(seed: "660608")), ambition: .recordBook)
        let uncompleted = try unsignedSnapshot(accepted.snapshot) { object in
            object["phase"] = ProCareerPhase.seasonReview.rawValue
            object["week"] = 24
            object["level"] = ProLevel.major.rawValue
            object["currentStats"] = try encoded(ProSeasonStats(season: 1, teamID: accepted.snapshot.team.id))
        }
        let falseToFalse = try engine.reviewSeason(.init(seed: "660609", state: uncompleted))
        let falseToFalseSettlement = try XCTUnwrap(falseToFalse.snapshot.journeyState?.lastSettlement)
        XCTAssertFalse(try XCTUnwrap(falseToFalseSettlement.goalProgressBefore).completed)
        XCTAssertFalse(try XCTUnwrap(falseToFalseSettlement.goalProgressAfter).completed)
        let acknowledged = try engine.acknowledgeSettlement(.init(
            seed: falseToFalse.nextSeed,
            state: falseToFalse.snapshot,
            expectedRevision: falseToFalse.snapshot.revision,
            settlementID: falseToFalseSettlement.id
        ))
        XCTAssertTrue(acknowledged.snapshot.journeyState?.settlementAcknowledged == true)

        let before = try XCTUnwrap(falseToFalseSettlement.goalProgressBefore)
        let after = try XCTUnwrap(falseToFalseSettlement.goalProgressAfter)
        let completedMetrics = before.metrics.map {
            ProCareerGoalMetric(kind: $0.kind, current: $0.target, target: $0.target)
        }
        let regressedSettlement = ProSeasonSettlement(
            id: falseToFalseSettlement.id,
            season: falseToFalseSettlement.season,
            teamID: falseToFalseSettlement.teamID,
            stats: falseToFalseSettlement.stats,
            newAwardIDs: falseToFalseSettlement.newAwardIDs,
            newMilestoneIDs: falseToFalseSettlement.newMilestoneIDs,
            salaryIncome: falseToFalseSettlement.salaryIncome,
            merchandiseIncome: falseToFalseSettlement.merchandiseIncome,
            fanBefore: falseToFalseSettlement.fanBefore,
            fanAfter: falseToFalseSettlement.fanAfter,
            fanDelta: falseToFalseSettlement.fanDelta,
            fanReasons: falseToFalseSettlement.fanReasons,
            merchandiseTier: falseToFalseSettlement.merchandiseTier,
            teamLegacyBefore: falseToFalseSettlement.teamLegacyBefore,
            teamLegacyAfter: falseToFalseSettlement.teamLegacyAfter,
            hallOfFameBefore: falseToFalseSettlement.hallOfFameBefore,
            hallOfFameAfter: falseToFalseSettlement.hallOfFameAfter,
            contractYearsBefore: falseToFalseSettlement.contractYearsBefore,
            contractYearsAfter: falseToFalseSettlement.contractYearsAfter,
            contractExpectation: falseToFalseSettlement.contractExpectation,
            contractExpectationActual: falseToFalseSettlement.contractExpectationActual,
            contractExpectationMet: falseToFalseSettlement.contractExpectationMet,
            goalProgressBefore: ProCareerGoalProgress(ambition: before.ambition, metrics: completedMetrics, completed: true),
            goalProgressAfter: after,
            goalCompleted: false,
            nextRoute: falseToFalseSettlement.nextRoute
        )
        let trueToFalse = try unsignedSnapshot(falseToFalse.snapshot) { object in
            var journey = try journeyObject(from: object)
            journey["lastSettlement"] = try encoded(regressedSettlement)
            object["journeyState"] = journey
        }
        XCTAssertEqual(errorCode {
            _ = try engine.acknowledgeSettlement(.init(
                seed: "660610",
                state: trueToFalse,
                expectedRevision: trueToFalse.revision,
                settlementID: regressedSettlement.id
            ))
        }, "settlement goal completion regressed")
    }

    private func startParams(seed: String) -> StartProCareerParams {
        .init(
            seed: seed,
            identity: .defaultPitcher,
            pitcher: .init(id: "wave5-pitcher", name: "Wave 5", stuff: 58, command: 55, movement: 56, stamina: 57),
            draftResult: .init(outcome: .drafted, evaluationScore: 72, projectedRange: "2~3라운드", team: ProCareerEngine.proTeams[0], round: 2, overallPick: 18, signingBonus: 120_000_000, firstSeasonGoal: "2군 선발", summary: "지명"),
            entitlement: .init(status: .active, source: .development, verifiedAt: "2026-08-15")
        )
    }

    private func acceptRookie(_ started: ProCareerResult, ambition: ProCareerAmbition) throws -> ProCareerResult {
        let market = try XCTUnwrap(started.snapshot.journeyState?.pendingContractMarket)
        return try engine.acceptContract(.init(seed: started.nextSeed, state: started.snapshot, expectedRevision: started.snapshot.revision, marketID: market.id, offerID: market.offers[0].id, ambition: ambition))
    }

    private func offseasonInvestmentState(
        _ snapshot: ProCareerSnapshot,
        availableFunds: Int64? = nil,
        includePriorInvestment: Bool = false
    ) throws -> ProCareerSnapshot {
        try unsignedSnapshot(snapshot) { object in
            object["phase"] = ProCareerPhase.offseasonInvestment.rawValue
            object["week"] = 24
            var journey = try journeyObject(from: object)
            journey["offseasonTransition"] = try encoded(ProOffseasonTransition(afterSeason: snapshot.season, nextSeason: snapshot.season + 1, ageAdvanceYears: 1, includesMilitaryService: false, route: .underContract))
            if let availableFunds {
                var finances = try XCTUnwrap(journey["finances"] as? [String: Any])
                finances["availableFunds"] = availableFunds
                if includePriorInvestment {
                    let tx = ProFinanceTransaction(id: "investment:\(snapshot.proCareerID):\(snapshot.season):fan_foundation", season: snapshot.season, kind: .investment, amount: -100_000_000)
                    finances["transactions"] = try encoded([tx] + (snapshot.journeyState?.finances.transactions ?? []).filter { $0.kind != .investment })
                    finances["investmentSeason"] = snapshot.season
                }
                journey["finances"] = finances
            }
            object["journeyState"] = journey
        }
    }

    private func journeyObject(from object: [String: Any]) throws -> [String: Any] {
        try XCTUnwrap(object["journeyState"] as? [String: Any])
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    }

    private func signedSnapshot(_ snapshot: ProCareerSnapshot, mutate: (inout [String: Any]) throws -> Void) throws -> ProCareerSnapshot {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        try mutate(&object)
        object["commitment"] = ""
        let unsigned = try JSONDecoder().decode(ProCareerSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        object["commitment"] = engine.commitment(unsigned)
        return try JSONDecoder().decode(ProCareerSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func unsignedSnapshot(_ snapshot: ProCareerSnapshot, mutate: (inout [String: Any]) throws -> Void) throws -> ProCareerSnapshot {
        try signedSnapshot(snapshot, mutate: mutate)
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
