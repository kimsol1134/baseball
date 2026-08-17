import Foundation

extension ProCareerEngine {
    func initialJourneyFanSupport(draftEvaluation: Int, sourceFanInterest: Int?) -> Int {
        if let sourceFanInterest {
            return min(30, max(5, 5 + max(0, sourceFanInterest) / 2))
        }
        return min(25, max(5, 5 + max(0, draftEvaluation - 50) / 2))
    }

    func replacingJourney(
        _ journey: ProCareerJourneyState,
        rulesVersion: Int? = nil,
        activeGoal: ProCareerGoalState?? = nil,
        goalHistory: [ProCareerGoalRecord]? = nil,
        pendingContractMarket: ProContractMarket?? = nil,
        contractHistory: [ProContractRecord]? = nil,
        teamRecords: [ProTeamCareerRecord]? = nil,
        recognitions: [ProCareerRecognition]? = nil,
        reputation: ProReputationState? = nil,
        finances: ProFinanceState? = nil,
        activeSeasonBenefit: ProSeasonBenefit?? = nil,
        lastSettlement: ProSeasonSettlement?? = nil,
        settlementAcknowledged: Bool? = nil,
        offseasonTransition: ProOffseasonTransition?? = nil,
        retirementHonors: [ProRetirementHonor]? = nil,
        migration: ProJourneyMigration? = nil
    ) -> ProCareerJourneyState {
        ProCareerJourneyState(
            rulesVersion: rulesVersion ?? journey.rulesVersion,
            activeGoal: activeGoal ?? journey.activeGoal,
            goalHistory: goalHistory ?? journey.goalHistory,
            pendingContractMarket: pendingContractMarket ?? journey.pendingContractMarket,
            contractHistory: contractHistory ?? journey.contractHistory,
            teamRecords: teamRecords ?? journey.teamRecords,
            recognitions: recognitions ?? journey.recognitions,
            reputation: reputation ?? journey.reputation,
            finances: finances ?? journey.finances,
            activeSeasonBenefit: activeSeasonBenefit ?? journey.activeSeasonBenefit,
            lastSettlement: lastSettlement ?? journey.lastSettlement,
            settlementAcknowledged: settlementAcknowledged ?? journey.settlementAcknowledged,
            offseasonTransition: offseasonTransition ?? journey.offseasonTransition,
            retirementHonors: retirementHonors ?? journey.retirementHonors,
            migration: migration ?? journey.migration
        )
    }

    func emptyCurrentStats(for state: ProCareerSnapshot) -> ProSeasonStats {
        ProSeasonStats(season: state.currentStats.season, teamID: state.currentStats.teamID)
    }

    func recordReplacing(
        _ record: ProContractRecord,
        coveredSeasons: [Int],
        fulfilledExpectationSeasons: [Int],
        endedSeason: Int?,
        endReason: ProContractEndReason?
    ) -> ProContractRecord {
        ProContractRecord(
            contractID: record.contractID,
            teamID: record.teamID,
            kind: record.kind,
            signedSeason: record.signedSeason,
            totalYears: record.totalYears,
            annualSalary: record.annualSalary,
            signingBonus: record.signingBonus,
            rolePromise: record.rolePromise,
            expectation: record.expectation,
            coveredSeasons: coveredSeasons,
            fulfilledExpectationSeasons: fulfilledExpectationSeasons,
            endedSeason: endedSeason,
            endReason: endReason
        )
    }

    func mergeContractRecord(_ record: ProContractRecord, into records: [ProContractRecord]) -> [ProContractRecord] {
        var values = records.filter { $0.contractID != record.contractID }
        values.append(record)
        return values.sorted { $0.contractID < $1.contractID }
    }

    func mergeGoalRecord(
        _ record: ProCareerGoalRecord,
        into records: [ProCareerGoalRecord]
    ) throws -> [ProCareerGoalRecord] {
        if let existing = records.first(where: { $0.id == record.id }) {
            guard existing == record else {
                throw SimulationError.invalidProCareer("invalid_goal_history")
            }
            return records.sorted { $0.id < $1.id }
        }
        guard records.count < 20 else {
            throw SimulationError.invalidProCareer("invalid_goal_history")
        }
        return (records + [record]).sorted { $0.id < $1.id }
    }

    /// Keep the finance ledger as an application-order window. Totals and contract history are
    /// the durable lifetime evidence; this array is deliberately only the most recent 64 rows.
    func boundedFinanceTransactions(_ transactions: [ProFinanceTransaction]) -> [ProFinanceTransaction] {
        Array(transactions.suffix(64))
    }

    /// A signing row may disappear only after the bounded ledger is full and the existing
    /// contract/transaction fields prove that the signed contract reached a later paid season.
    /// No new eviction marker is added to the save schema: without both durable contract
    /// coverage and an auditable later salary row, a missing signing row is indistinguishable
    /// from a tampered deletion.
    func signingTransactionWasLegitimatelyEvicted(
        record: ProContractRecord,
        state: ProCareerSnapshot,
        journey: ProCareerJourneyState
    ) -> Bool {
        let signingID = "signing:\(state.proCareerID):\(record.contractID)"
        let auditableSalaryIDs = Set(
            journey.contractHistory.flatMap { contract in
                contract.coveredSeasons.map { season in
                    "salary:\(state.proCareerID):\(season):\(contract.contractID)"
                }
            }
        )
        guard journey.finances.transactions.count == 64,
              !journey.finances.transactions.contains(where: { $0.id == signingID }),
              record.coveredSeasons.contains(record.signedSeason),
              record.coveredSeasons.contains(where: { $0 > record.signedSeason }),
              journey.finances.salaryCreditedThroughSeason > record.signedSeason,
              journey.finances.transactions.contains(where: {
                  $0.kind == .salary
                      && $0.season > record.signedSeason
                      && auditableSalaryIDs.contains($0.id)
              }) else {
            return false
        }
        return true
    }

    func goalRecord(
        for goal: ProCareerGoalState,
        endedSeason: Int,
        outcome: ProCareerGoalOutcome,
        completedSeason: Int? = nil
    ) -> ProCareerGoalRecord {
        ProCareerGoalRecord(
            id: goal.id,
            ambition: goal.ambition,
            selectedSeason: goal.selectedSeason,
            anchorTeamID: goal.anchorTeamID,
            completedSeason: completedSeason ?? goal.completedSeason,
            endedSeason: endedSeason,
            outcome: outcome
        )
    }

    func closedGoalHistoryForRetirement(
        state: ProCareerSnapshot,
        journey: ProCareerJourneyState
    ) throws -> [ProCareerGoalRecord] {
        guard let activeGoal = journey.activeGoal else { return journey.goalHistory }
        if let completedSeason = activeGoal.completedSeason {
            if let existing = journey.goalHistory.first(where: { $0.id == activeGoal.id }) {
                guard existing.ambition == activeGoal.ambition,
                      existing.selectedSeason == activeGoal.selectedSeason,
                      existing.anchorTeamID == activeGoal.anchorTeamID,
                      existing.completedSeason == completedSeason,
                      existing.outcome == .completed else {
                    throw SimulationError.invalidProCareer("invalid_goal_history")
                }
                return journey.goalHistory
            }
            let record = goalRecord(
                for: activeGoal,
                endedSeason: completedSeason,
                outcome: .completed,
                completedSeason: completedSeason
            )
            return try mergeGoalRecord(record, into: journey.goalHistory)
        }
        let outcome: ProCareerGoalOutcome = activeGoal.completedSeason == nil ? .retiredIncomplete : .completed
        let record = goalRecord(
            for: activeGoal,
            endedSeason: state.season,
            outcome: outcome,
            completedSeason: activeGoal.completedSeason
        )
        return try mergeGoalRecord(record, into: journey.goalHistory)
    }

    func mergeRecognitions(
        _ additions: [ProCareerRecognition],
        into existing: [ProCareerRecognition]
    ) -> (all: [ProCareerRecognition], added: [ProCareerRecognition]) {
        var byID: [String: ProCareerRecognition] = [:]
        for recognition in existing {
            byID[recognition.id] = recognition
        }
        var added: [ProCareerRecognition] = []
        for recognition in additions where byID[recognition.id] == nil {
            byID[recognition.id] = recognition
            added.append(recognition)
        }
        return (
            byID.values.sorted(by: ProCareerJourneyRules.recognitionOrder),
            added.sorted(by: ProCareerJourneyRules.recognitionOrder)
        )
    }

    func currentTeamRecord(
        for state: ProCareerSnapshot,
        journey: ProCareerJourneyState,
        careerStats: [ProSeasonStats]
    ) -> ProTeamCareerRecord? {
        ProTeamCareerRecordRules.record(
            teamID: state.team.id,
            in: ProTeamCareerRecordRules.backfill(
                careerStats: careerStats,
                recognitions: journey.recognitions,
                existing: journey.teamRecords
            )
        ) ?? journey.teamRecords.first { $0.teamID == state.team.id }
    }

    func expectationActual(
        _ expectation: ProContractExpectation,
        state: ProCareerSnapshot
    ) -> Int? {
        ProContractMarketRules.actual(expectation: expectation, state: state)
    }

    func expectationMet(_ expectation: ProContractExpectation, actual: Int?) -> Bool {
        ProContractMarketRules.met(expectation: expectation, actual: actual)
    }

    func newlyReachedCareerMilestoneRecognitions(
        state: ProCareerSnapshot,
        completedCareerStats: [ProSeasonStats]
    ) -> [ProCareerRecognition] {
        func games(_ rows: [ProSeasonStats]) -> Int {
            rows.reduce(into: 0) { $0 += $1.games }
        }
        func strikeouts(_ rows: [ProSeasonStats]) -> Int {
            rows.reduce(into: 0) { $0 += $1.strikeouts }
        }
        let priorGames = games(state.careerStats)
        let nextGames = games(completedCareerStats)
        let priorStrikeouts = strikeouts(state.careerStats)
        let nextStrikeouts = strikeouts(completedCareerStats)
        var values: [ProCareerRecognition] = []
        for mark in [50, 100, 300] where priorGames < mark && nextGames >= mark {
            values.append(.init(
                careerID: state.proCareerID,
                kind: .milestone,
                contentID: "pro.milestone.career.games.\(mark)",
                season: state.season,
                teamID: state.team.id,
                value: mark
            ))
        }
        for mark in [50, 100, 200, 500] where priorStrikeouts < mark && nextStrikeouts >= mark {
            values.append(.init(
                careerID: state.proCareerID,
                kind: .milestone,
                contentID: "pro.milestone.career.strikeouts.\(mark)",
                season: state.season,
                teamID: state.team.id,
                value: mark
            ))
        }
        return values
    }

    func settlementFanReasons(
        state: ProCareerSnapshot,
        addedRecognitions: [ProCareerRecognition],
        goalCompleted: Bool,
        expectationMet: Bool?
    ) -> [ProFanReason] {
        var reasons: [ProFanReason] = []
        let importantOutings = (state.gameLines ?? [])
            .filter { $0.season == state.season && $0.played }
            .sorted { lhs, rhs in
                if lhs.week != rhs.week { return lhs.week < rhs.week }
                return lhs.outingNumber < rhs.outingNumber
            }
        for line in importantOutings {
            if line.runsAllowed == 0 {
                reasons.append(.init(
                    careerID: state.proCareerID,
                    season: state.season,
                    kind: .importantGameScoreless,
                    contentID: "pro.fan.important-game.scoreless",
                    ordinal: line.outingNumber,
                    delta: 2
                ))
            } else if line.runsAllowed >= 3 {
                reasons.append(.init(
                    careerID: state.proCareerID,
                    season: state.season,
                    kind: .importantGameRunsAllowed,
                    contentID: "pro.fan.important-game.runs-allowed",
                    ordinal: line.outingNumber,
                    delta: -1
                ))
            }
        }

        let newAwards = addedRecognitions
            .filter { $0.kind == .award }
            .sorted { $0.contentID < $1.contentID }
            .prefix(2)
        for (index, recognition) in newAwards.enumerated() {
            reasons.append(.init(
                careerID: state.proCareerID,
                season: state.season,
                kind: .seasonAward,
                contentID: recognition.contentID,
                ordinal: index,
                delta: 4
            ))
        }

        // Only the explicit career-threshold recognitions count here. In particular, the
        // ambition-completion recognition is a separate +10 reason and must not become another
        // generic milestone +2.
        let careerMilestones = addedRecognitions
            .filter { $0.kind == .milestone && $0.contentID.hasPrefix("pro.milestone.career.") }
            .sorted { $0.contentID < $1.contentID }
        for (index, recognition) in careerMilestones.enumerated() {
            reasons.append(.init(
                careerID: state.proCareerID,
                season: state.season,
                kind: .careerMilestone,
                contentID: recognition.contentID,
                ordinal: index,
                delta: 2
            ))
        }

        if state.currentStats.teamID == state.team.id {
            reasons.append(.init(
                careerID: state.proCareerID,
                season: state.season,
                kind: .sameTeamSeason,
                contentID: "pro.fan.same-team-season",
                delta: 1
            ))
        }
        if expectationMet == true {
            reasons.append(.init(
                careerID: state.proCareerID,
                season: state.season,
                kind: .contractExpectationMet,
                contentID: "pro.fan.contract-expectation.met",
                delta: 3
            ))
        } else if expectationMet == false {
            reasons.append(.init(
                careerID: state.proCareerID,
                season: state.season,
                kind: .contractExpectationMissed,
                contentID: "pro.fan.contract-expectation.missed",
                delta: -1
            ))
        }
        if goalCompleted {
            reasons.append(.init(
                careerID: state.proCareerID,
                season: state.season,
                kind: .careerAmbitionCompleted,
                contentID: "pro.fan.career-ambition-completed",
                delta: 10
            ))
        }
        return reasons.sorted { $0.id < $1.id }
    }

    /// Append a complete settlement payment in one finance calculation. The totals are checked
    /// before the recent-64 history is trimmed, so dropping old transaction IDs never changes the
    /// accumulated earnings or available funds.
    func creditSeasonSettlement(
        state: ProCareerSnapshot,
        journey: ProCareerJourneyState,
        contract: ProContractSnapshot
    ) throws -> (finance: ProFinanceState, salary: Int64, merchandise: Int64, tier: ProMerchandiseTier) {
        guard contract.annualSalary > 0 else {
            throw SimulationError.invalidProCareer("current contract salary must be positive")
        }
        let salary = Int64(contract.annualSalary)
        let contractID = contract.id ?? "legacy"
        let salaryID = "salary:\(state.proCareerID):\(state.season):\(contractID)"
        let merchandiseID = "merch:\(state.proCareerID):\(state.season)"
        let existingSalary = journey.finances.transactions.first { $0.id == salaryID }
        let existingMerchandise = journey.finances.transactions.first { $0.id == merchandiseID }
        let merchandise = ProFinanceRules.merchandiseIncome(for: journey.reputation.fanSupport)
        let tier = ProFinanceRules.merchandiseTier(for: journey.reputation.fanSupport)

        if journey.finances.salaryCreditedThroughSeason >= state.season {
            guard let existingSalary,
                  existingSalary.kind == .salary,
                  existingSalary.season == state.season,
                  existingSalary.amount == salary,
                  let existingMerchandise,
                  existingMerchandise.kind == .merchandise,
                  existingMerchandise.season == state.season,
                  existingMerchandise.amount == merchandise else {
                throw SimulationError.invalidProCareer("salary watermark has no matching transaction")
            }
            return (journey.finances, 0, 0, tier)
        }
        guard existingSalary == nil, existingMerchandise == nil else {
            throw SimulationError.invalidProCareer("settlement transaction is ahead of its watermark")
        }
        guard journey.finances.careerEarnings <= Int64.max - salary,
              journey.finances.availableFunds <= Int64.max - salary,
              journey.finances.careerEarnings + salary <= Int64.max - merchandise,
              journey.finances.availableFunds + salary <= Int64.max - merchandise else {
            throw SimulationError.invalidProCareer("finance overflow")
        }
        let salaryTransaction = ProFinanceTransaction(
            id: salaryID,
            season: state.season,
            kind: .salary,
            amount: salary
        )
        let merchandiseTransaction = ProFinanceTransaction(
            id: merchandiseID,
            season: state.season,
            kind: .merchandise,
            amount: merchandise
        )
        let transactions = boundedFinanceTransactions(journey.finances.transactions + [salaryTransaction, merchandiseTransaction])
        return (
            ProFinanceState(
                careerEarnings: journey.finances.careerEarnings + salary + merchandise,
                availableFunds: journey.finances.availableFunds + salary + merchandise,
                salaryCreditedThroughSeason: max(journey.finances.salaryCreditedThroughSeason, state.season),
                transactions: transactions,
                investmentSeason: journey.finances.investmentSeason
            ),
            salary,
            merchandise,
            tier
        )
    }

    func reviewJourneySeason(_ params: ProStateParams) throws -> ProCareerResult {
        guard let journey = params.state.journeyState else {
            throw SimulationError.invalidProCareer("missing journey state")
        }
        try validate(params.state, phase: .seasonReview)
        guard let oldContract = params.state.contract,
              oldContract.yearsRemaining >= 1 else {
            throw SimulationError.invalidProCareer("season review requires an active contract")
        }
        guard !params.state.careerStats.contains(where: {
            $0.season == params.state.currentStats.season && $0.teamID == params.state.currentStats.teamID
        }) else {
            throw SimulationError.invalidProCareer("current season is already settled")
        }
        let currentSalaryTransactionID = "salary:\(params.state.proCareerID):\(params.state.season):\(params.state.contract?.id ?? "legacy")"
        guard journey.finances.salaryCreditedThroughSeason < params.state.season,
              !journey.finances.transactions.contains(where: { $0.id == currentSalaryTransactionID }) else {
            throw SimulationError.invalidProCareer("current salary is credited without a stored settlement")
        }
        let state = params.state
        let oldRecords = ProTeamCareerRecordRules.backfill(
            careerStats: state.careerStats,
            recognitions: journey.recognitions,
            existing: journey.teamRecords
        )
        let completedCareerStats = state.careerStats + [state.currentStats]
        let typedAdditions = ProCareerRecognitionRules.currentSeasonRecognitions(
            careerID: state.proCareerID,
            season: state.season,
            teamID: state.team.id,
            stats: state.currentStats,
            level: state.level
        ) + newlyReachedCareerMilestoneRecognitions(
            state: state,
            completedCareerStats: completedCareerStats
        )
        let baseRecognitionMerge = mergeRecognitions(typedAdditions, into: journey.recognitions)
        let completedRecords = ProTeamCareerRecordRules.backfill(
            careerStats: completedCareerStats,
            recognitions: baseRecognitionMerge.all,
            existing: oldRecords
        )

        let journeyBefore = replacingJourney(journey, teamRecords: oldRecords)
        let beforeState = replacing(
            state,
            currentStats: emptyCurrentStats(for: state),
            journeyState: .some(journeyBefore)
        )
        let journeyAfterRecords = replacingJourney(
            journey,
            teamRecords: completedRecords,
            recognitions: baseRecognitionMerge.all
        )
        let afterState = replacing(
            state,
            serviceYears: state.serviceYears + (state.level == .major ? 1 : 0),
            careerStats: completedCareerStats,
            journeyState: .some(journeyAfterRecords)
        )

        let beforeRecord = currentTeamRecord(for: beforeState, journey: journeyBefore, careerStats: state.careerStats)
        let afterRecord = currentTeamRecord(for: afterState, journey: journeyAfterRecords, careerStats: completedCareerStats)
        let teamLegacyBefore = beforeRecord.map(ProTeamLegacyRules.score(record:)) ?? 0
        let teamLegacyAfter = afterRecord.map(ProTeamLegacyRules.score(record:)) ?? 0
        let hallOfFameBefore = Self.hallOfFameProjection(for: beforeState)
        let hallOfFameAfter = Self.hallOfFameProjection(for: afterState)

        let goalBefore = journey.activeGoal.map { ProCareerGoalRules.progress(state: beforeState, goal: $0) }
        let goalAfter = journey.activeGoal.map { ProCareerGoalRules.progress(state: afterState, goal: $0) }
        let goalCompleted = goalBefore?.completed == false && goalAfter?.completed == true
        // A completed ambition is closed into history at the same settlement boundary as its
        // reward. Keep the completed snapshot until the next contract choice so activeGoal is
        // never nil between ambitions; nil is reserved for the all-complete contract state.
        let completedGoal = goalCompleted ? journey.activeGoal.map {
            ProCareerGoalState(
                id: $0.id,
                ambition: $0.ambition,
                selectedSeason: $0.selectedSeason,
                anchorTeamID: $0.anchorTeamID,
                completedSeason: state.season
            )
        } : nil
        let activeGoal: ProCareerGoalState? = goalCompleted ? completedGoal : journey.activeGoal

        var goalHistory = journey.goalHistory
        var recognitionInputs = typedAdditions
        if goalCompleted, let goal = completedGoal {
            goalHistory = try mergeGoalRecord(
                goalRecord(
                    for: goal,
                    endedSeason: state.season,
                    outcome: .completed,
                    completedSeason: state.season
                ),
                into: goalHistory
            )
            recognitionInputs.append(.init(
                careerID: state.proCareerID,
                kind: .milestone,
                contentID: "pro.ambition.\(goal.ambition.rawValue).completed",
                season: state.season,
                teamID: state.team.id
            ))
        }
        let recognitionMerge = mergeRecognitions(recognitionInputs, into: journey.recognitions)
        let completedRecordsWithRecognition = ProTeamCareerRecordRules.backfill(
            careerStats: completedCareerStats,
            recognitions: recognitionMerge.all,
            existing: oldRecords
        )
        let expectation = oldContract.expectation
        let actual = expectation.map { expectationActual($0, state: state) }
        let met = expectation.map { expectationMet($0, actual: actual ?? nil) }
        let fanReasons = settlementFanReasons(
            state: state,
            addedRecognitions: recognitionMerge.added,
            goalCompleted: goalCompleted,
            expectationMet: met ?? nil
        )
        let rawFanDelta = fanReasons.reduce(into: 0) { $0 += $1.delta }
        let fanDelta = clamp(rawFanDelta, -12, 20)
        let fanAfter = clamp(journey.reputation.fanSupport + fanDelta, 0, 100)
        let managerTrustAfter = met == true
            ? clamp(state.managerTrust + 3, 0, 100)
            : state.managerTrust
        let contractID = oldContract.id ?? "contract:\(state.proCareerID):legacy:\(journey.migration.initializedSeason)"
        let existingRecord = journey.contractHistory.first(where: { $0.contractID == contractID })
            ?? ProContractRecord(
                contractID: contractID,
                teamID: oldContract.teamID ?? state.team.id,
                kind: oldContract.kind,
                signedSeason: oldContract.signedSeason ?? journey.migration.initializedSeason,
                totalYears: oldContract.totalYears ?? max(1, oldContract.yearsRemaining),
                annualSalary: oldContract.annualSalary,
                signingBonus: nil,
                rolePromise: oldContract.rolePromise,
                expectation: oldContract.expectation,
                coveredSeasons: [],
                fulfilledExpectationSeasons: [],
                endedSeason: nil,
                endReason: nil
            )
        let coveredSeasons = Array(Set(existingRecord.coveredSeasons + [state.season])).sorted()
        let fulfilledSeasons: [Int]
        if met == true {
            fulfilledSeasons = Array(Set(existingRecord.fulfilledExpectationSeasons + [state.season])).sorted()
        } else {
            fulfilledSeasons = existingRecord.fulfilledExpectationSeasons.sorted()
        }
        let contractYearsBefore = oldContract.yearsRemaining
        let contractYearsAfter = max(0, contractYearsBefore - 1)
        let ended = contractYearsAfter == 0 ? state.season : existingRecord.endedSeason
        let endReason = contractYearsAfter == 0 ? ProContractEndReason.expired : existingRecord.endReason
        let updatedRecord = recordReplacing(
            existingRecord,
            coveredSeasons: coveredSeasons,
            fulfilledExpectationSeasons: fulfilledSeasons,
            endedSeason: ended,
            endReason: endReason
        )
        let updatedContract = ProContractSnapshot(
            yearsRemaining: contractYearsAfter,
            annualSalary: oldContract.annualSalary,
            rolePromise: oldContract.rolePromise,
            id: contractID,
            teamID: oldContract.teamID ?? state.team.id,
            totalYears: oldContract.totalYears ?? existingRecord.totalYears,
            signedSeason: oldContract.signedSeason ?? existingRecord.signedSeason,
            kind: oldContract.kind ?? existingRecord.kind,
            expectation: oldContract.expectation ?? existingRecord.expectation
        )
        let financeResult = try creditSeasonSettlement(state: state, journey: journey, contract: updatedContract)
        let serviceYearsAfter = state.serviceYears + (state.level == .major ? 1 : 0)
        let nextRoute: ProSettlementNextRoute
        if state.season >= Self.maximumCareerSeasons {
            nextRoute = .forcedRetirement
        } else if contractYearsAfter > 0 {
            nextRoute = .underContract
        } else if serviceYearsAfter >= 6 {
            nextRoute = .freeAgencyEligible
        } else {
            nextRoute = .renewalMarket
        }
        let settlement = ProSeasonSettlement(
            id: "settlement:\(state.proCareerID):\(state.season):\(state.team.id)",
            season: state.season,
            teamID: state.team.id,
            stats: state.currentStats,
            newAwardIDs: recognitionMerge.added.filter { $0.kind == .award }.map(\.id).sorted(),
            newMilestoneIDs: recognitionMerge.added.filter { $0.kind == .milestone }.map(\.id).sorted(),
            salaryIncome: financeResult.salary,
            merchandiseIncome: financeResult.merchandise,
            fanBefore: journey.reputation.fanSupport,
            fanAfter: fanAfter,
            fanDelta: fanDelta,
            fanReasons: fanReasons,
            merchandiseTier: financeResult.tier,
            teamLegacyBefore: teamLegacyBefore,
            teamLegacyAfter: teamLegacyAfter,
            hallOfFameBefore: hallOfFameBefore,
            hallOfFameAfter: hallOfFameAfter,
            contractYearsBefore: contractYearsBefore,
            contractYearsAfter: contractYearsAfter,
            contractExpectation: expectation,
            contractExpectationActual: actual ?? nil,
            contractExpectationMet: met ?? nil,
            goalProgressBefore: goalBefore,
            goalProgressAfter: goalAfter,
            goalCompleted: goalCompleted,
            nextRoute: nextRoute
        )
        let nextJourney = replacingJourney(
            journey,
            activeGoal: .some(activeGoal),
            goalHistory: goalHistory,
            pendingContractMarket: .some(nil),
            contractHistory: mergeContractRecord(updatedRecord, into: journey.contractHistory),
            teamRecords: completedRecordsWithRecognition,
            recognitions: recognitionMerge.all,
            reputation: ProReputationState(
                fanSupport: fanAfter,
                lastMerchandiseTier: financeResult.tier,
                endorsementSeasons: journey.reputation.endorsementSeasons
            ),
            finances: financeResult.finance,
            activeSeasonBenefit: .some(nil),
            lastSettlement: .some(settlement),
            settlementAcknowledged: false,
            offseasonTransition: .some(nil)
        )
        let updated = replacing(
            state,
            revision: state.revision + 1,
            phase: .seasonSettlement,
            managerTrust: managerTrustAfter,
            serviceYears: serviceYearsAfter,
            contract: .some(updatedContract),
            careerStats: completedCareerStats,
            journeyState: .some(nextJourney)
        )
        return result(updated, nextSeed: params.seed, events: ["pro_season_settlement_created"])
    }

    /// Migrates only at a boundary where no user choice is waiting. It is intentionally a
    /// read/construct operation: no random generator is touched and a second call is a byte-stable
    /// no-op because the aggregate is already present.
    func migrateLegacyJourney(_ params: ProStateParams) throws -> ProCareerResult {
        guard journeyEnabled else {
            return ProCareerResult(snapshot: params.state, nextSeed: params.seed, events: [])
        }
        if params.state.journeyState != nil {
            return ProCareerResult(snapshot: params.state, nextSeed: params.seed, events: [])
        }
        try validateState(params.state)
        let safePhases: Set<ProCareerPhase> = [.weeklyPlan, .seasonReview, .offseasonDecision, .retirementDecision]
        guard safePhases.contains(params.state.phase) else {
            return ProCareerResult(snapshot: params.state, nextSeed: params.seed, events: ["journey_migration_deferred"])
        }

        let state = params.state
        let teamIDBySeason = Dictionary(uniqueKeysWithValues: state.careerStats.map { ($0.season, $0.teamID) })
        let legacyRecognition = ProLegacyRecognitionAdapter.recognitions(
            careerID: state.proCareerID,
            awards: state.awards,
            milestones: state.milestones,
            teamIDBySeason: teamIDBySeason
        )
        var history: [ProContractRecord] = []
        var expandedContract: ProContractSnapshot?
        if let contract = state.contract {
            let contractID = "contract:\(state.proCareerID):legacy:\(state.season)"
            let years = max(1, contract.yearsRemaining)
            let record = ProContractRecord(
                contractID: contractID,
                teamID: contract.teamID ?? state.team.id,
                kind: nil,
                signedSeason: state.season,
                totalYears: years,
                annualSalary: contract.annualSalary,
                signingBonus: nil,
                rolePromise: contract.rolePromise,
                expectation: nil,
                coveredSeasons: [],
                fulfilledExpectationSeasons: [],
                endedSeason: nil,
                endReason: nil
            )
            history = [record]
            expandedContract = ProContractSnapshot(
                yearsRemaining: contract.yearsRemaining,
                annualSalary: contract.annualSalary,
                rolePromise: contract.rolePromise,
                id: contractID,
                teamID: contract.teamID ?? state.team.id,
                totalYears: years,
                signedSeason: state.season,
                kind: nil,
                expectation: nil
            )
        }
        let financeStartsSeason: Int
        switch state.phase {
        case .weeklyPlan, .seasonReview:
            financeStartsSeason = state.season
        case .offseasonDecision, .retirementDecision:
            financeStartsSeason = state.season + 1
        default:
            financeStartsSeason = state.season
        }
        let teamRecords = ProTeamCareerRecordRules.backfill(
            careerStats: state.careerStats,
            recognitions: legacyRecognition.recognitions,
            existing: []
        )
        let journey = ProCareerJourneyState(
            rulesVersion: 1,
            activeGoal: nil,
            goalHistory: [],
            pendingContractMarket: nil,
            contractHistory: history,
            teamRecords: teamRecords,
            recognitions: legacyRecognition.recognitions,
            reputation: ProReputationState(fanSupport: min(60, max(10, 10 + state.awards.count * 5 + state.milestones.count * 2 + state.serviceYears * 2))),
            finances: ProFinanceState(salaryCreditedThroughSeason: financeStartsSeason - 1),
            activeSeasonBenefit: nil,
            lastSettlement: nil,
            settlementAcknowledged: true,
            offseasonTransition: nil,
            retirementHonors: [],
            migration: ProJourneyMigration(
                source: .legacySafeBoundary,
                initializedSeason: state.season,
                financeStartsSeason: financeStartsSeason,
                unassignedLegacyAwards: legacyRecognition.unassignedAwards,
                financeNoticePending: true
            )
        )
        let migrated = replacing(
            state,
            revision: state.revision + 1,
            contract: expandedContract.map { .some($0) } ?? .some(nil),
            journeyState: .some(journey)
        )
        let signedMigration = result(migrated, nextSeed: params.seed, events: ["journey_migrated_at_safe_boundary"])
        if state.phase == .seasonReview {
            return try reviewJourneySeason(.init(seed: signedMigration.nextSeed, state: signedMigration.snapshot))
        }
        return signedMigration
    }

    func rookieOffer(in market: ProContractMarket, state: ProCareerSnapshot) throws -> ProContractOffer {
        guard market.kind == .rookie,
              market.id == "market:\(state.proCareerID):\(market.forSeason):rookie",
              market.forSeason == state.season,
              market.forSeason == 1,
              market.draftRound.map({ $0 >= 1 }) ?? false,
              market.overallPick.map({ $0 >= 1 }) ?? true,
              market.offers.count == 1,
              let offer = market.offers.first,
              offer.id == "offer:\(market.id):\(state.team.id):rookie",
              offer.teamID == state.team.id,
              offer.years == 3,
              (market.draftRound.flatMap { ProContractMarketRules.rookieAnnualSalary(forDraftRound: $0) } ?? -1) == offer.annualSalary,
              offer.signingBonus.map({ $0 > 0 }) ?? false,
              offer.contractKind == .rookie,
              offer.rolePromise == .starter,
              offer.outlook == .opportunity,
              offer.expectation == ProContractExpectation(kind: .majorRoster, target: 1, difficulty: .accessible),
              offer.preservesTeamLegacy else {
            throw SimulationError.invalidProCareer("invalid_offer")
        }
        return offer
    }

    func validateStoredJourneyMarket(
        _ market: ProContractMarket,
        state: ProCareerSnapshot
    ) throws {
        guard market.generatedAtRevision == state.revision else {
            throw SimulationError.invalidProCareer("stale_market")
        }
        let projectedPitcher = ProContractMarketRules.projectedPitcher(
            for: state.pitcher,
            effectiveAge: state.age + (state.journeyState?.offseasonTransition?.ageAdvanceYears ?? 0)
        )
        switch market.kind {
        case .rookie:
            _ = try rookieOffer(in: market, state: state)
        case .renewal:
            guard let expected = ProContractMarketRules.renewalMarket(state: state),
                  expected == market,
                  ProContractMarketRules.isValid(
                      market: market,
                      currentTeamID: state.team.id,
                      currentRole: state.role,
                      maximumCareerSeasons: Self.maximumCareerSeasons,
                      marketScore: ProContractMarketRules.marketScore(state: state),
                      pitcher: projectedPitcher
                  ) else {
                throw SimulationError.invalidProCareer("invalid_offer")
            }
        case .freeAgency:
            guard let expected = ProContractMarketRules.freeAgencyMarket(state: state),
                  expected == market,
                  ProContractMarketRules.isValid(
                      market: market,
                      currentTeamID: state.team.id,
                      currentRole: state.role,
                      maximumCareerSeasons: Self.maximumCareerSeasons,
                      marketScore: ProContractMarketRules.marketScore(state: state),
                      pitcher: projectedPitcher
                  ) else {
                throw SimulationError.invalidProCareer("invalid_offer")
            }
        }
    }

    func validateJourneyState(_ state: ProCareerSnapshot, journey: ProCareerJourneyState) throws {
        guard journey.rulesVersion == 1 else { throw SimulationError.invalidProCareer("unsupported journey rules version") }
        guard (0...100).contains(journey.reputation.fanSupport) else { throw SimulationError.invalidProCareer("fan support out of range") }
        guard journey.reputation.endorsementSeasons == Array(Set(journey.reputation.endorsementSeasons)).sorted(),
              journey.reputation.endorsementSeasons.allSatisfy({ $0 >= 1 }) else {
            throw SimulationError.invalidProCareer("endorsement seasons are not canonical")
        }
        let mediaRecords = (state.decisionHistory ?? []).filter { $0.type == .mediaOpportunity }
        let mediaSeasons = mediaRecords.map(\.season)
        guard Set(mediaSeasons).count == mediaSeasons.count,
              Set(journey.reputation.endorsementSeasons) == Set(mediaSeasons) else {
            throw SimulationError.invalidProCareer("media opportunity marker is not exact-once")
        }
        for transaction in journey.finances.transactions where transaction.kind == .endorsement {
            guard let record = mediaRecords.first(where: {
                transaction.id == "endorsement:\(state.proCareerID):\($0.season):\($0.decisionID)"
            }), transaction.amount == record.journeyEffect?.income else {
                throw SimulationError.invalidProCareer("endorsement transaction has no matching decision")
            }
        }
        if let benefit = journey.activeSeasonBenefit {
            let validBenefit = switch benefit.kind {
            case .developmentHeadStart:
                benefit.focus != nil && benefit.remainingCharges == 1
            case .injuryMitigation:
                benefit.focus == nil && benefit.remainingCharges == 1
            }
            guard validBenefit else {
                throw SimulationError.invalidProCareer("invalid season benefit")
            }
        }
        guard journey.goalHistory.count <= 20,
              journey.contractHistory.count <= 20,
              journey.teamRecords.count <= 10,
              journey.recognitions.count <= 256,
              journey.retirementHonors.count <= 16 else {
            throw SimulationError.invalidProCareer("journey history exceeds its cap")
        }
        guard journey.teamRecords.map(\.teamID) == journey.teamRecords.map(\.teamID).sorted(),
              Set(journey.teamRecords.map(\.teamID)).count == journey.teamRecords.count else {
            throw SimulationError.invalidProCareer("team records must be canonical and unique")
        }
        guard Set(journey.recognitions.map(\.id)).count == journey.recognitions.count,
              journey.recognitions == journey.recognitions.sorted(by: ProCareerJourneyRules.recognitionOrder) else {
            throw SimulationError.invalidProCareer("recognitions must be canonical and unique")
        }
        guard journey.recognitions.allSatisfy({ recognition in
            recognition.season >= 0
                && !recognition.contentID.isEmpty
                && recognition.teamID.map({ !$0.isEmpty }) ?? true
                && recognition.id == "recognition:\(state.proCareerID):\(recognition.season):\(recognition.kind.rawValue):\(recognition.contentID)"
        }) else {
            throw SimulationError.invalidProCareer("recognition identity is malformed")
        }
        guard Set(journey.contractHistory.map(\.contractID)).count == journey.contractHistory.count,
              journey.contractHistory.map(\.contractID) == journey.contractHistory.map(\.contractID).sorted(),
              Set(journey.goalHistory.map(\.id)).count == journey.goalHistory.count,
              journey.goalHistory.map(\.id) == journey.goalHistory.map(\.id).sorted(),
              Set(journey.retirementHonors.map(\.id)).count == journey.retirementHonors.count else {
            throw SimulationError.invalidProCareer("journey audit IDs must be unique")
        }
        func validGoalShape(
            ambition: ProCareerAmbition,
            selectedSeason: Int,
            anchorTeamID: String?,
            completedSeason: Int?,
            endedSeason: Int?
        ) -> Bool {
            guard selectedSeason >= 1,
                  anchorTeamID.map({ !$0.isEmpty }) ?? true,
                  (ambition == .franchiseIcon) == (anchorTeamID != nil) else {
                return false
            }
            if let completedSeason {
                guard completedSeason >= selectedSeason, completedSeason <= state.season else { return false }
            }
            if let endedSeason {
                guard endedSeason >= selectedSeason, endedSeason <= state.season else { return false }
            }
            return true
        }
        guard journey.goalHistory.allSatisfy({ record in
            validGoalShape(
                ambition: record.ambition,
                selectedSeason: record.selectedSeason,
                anchorTeamID: record.anchorTeamID,
                completedSeason: record.completedSeason,
                endedSeason: record.endedSeason
            ) && record.id == ProCareerGoalRules.goalID(
                careerID: state.proCareerID,
                season: record.selectedSeason,
                ambition: record.ambition,
                anchorTeamID: record.anchorTeamID
            ) && (record.outcome == .completed
                ? record.completedSeason != nil && record.completedSeason! <= record.endedSeason
                : record.completedSeason == nil)
        }) else {
            throw SimulationError.invalidProCareer("goal history is malformed")
        }
        let completedHistoryAmbitions = journey.goalHistory.filter { $0.outcome == .completed }.map(\.ambition)
        guard Set(completedHistoryAmbitions).count == completedHistoryAmbitions.count,
              completedHistoryAmbitions.count <= 3 else {
            throw SimulationError.invalidProCareer("goal history contains duplicate completions")
        }
        if journey.migration.source == .newCareer, journey.activeGoal == nil {
            let rookieChoicePending = state.phase == .contractOffer
                && journey.pendingContractMarket?.kind == .rookie
                && state.contract == nil
            let retirementClosed = state.phase == .completed
            guard rookieChoicePending || retirementClosed || completedHistoryAmbitions.count == 3 else {
                throw SimulationError.invalidProCareer("active goal is required until all ambitions are complete")
            }
        }
        if let activeGoal = journey.activeGoal {
            guard validGoalShape(
                ambition: activeGoal.ambition,
                selectedSeason: activeGoal.selectedSeason,
                anchorTeamID: activeGoal.anchorTeamID,
                completedSeason: activeGoal.completedSeason,
                endedSeason: nil
            ), activeGoal.id == ProCareerGoalRules.goalID(
                careerID: state.proCareerID,
                season: activeGoal.selectedSeason,
                ambition: activeGoal.ambition,
                anchorTeamID: activeGoal.anchorTeamID
            ) else {
                throw SimulationError.invalidProCareer("active goal is malformed")
            }
            if let completedSeason = activeGoal.completedSeason {
                guard journey.goalHistory.contains(where: {
                    $0.id == activeGoal.id
                        && $0.ambition == activeGoal.ambition
                        && $0.selectedSeason == activeGoal.selectedSeason
                        && $0.anchorTeamID == activeGoal.anchorTeamID
                        && $0.outcome == .completed
                        && $0.completedSeason == completedSeason
                }) else {
                    throw SimulationError.invalidProCareer("completed active goal is missing history")
                }
            } else {
                guard !journey.goalHistory.contains(where: { $0.id == activeGoal.id }) else {
                    throw SimulationError.invalidProCareer("active goal is already closed")
                }
            }
        }
        let ambitionRewardPrefix = "pro.ambition."
        let ambitionRewardSuffix = ".completed"
        var rewardedAmbitions = Set<ProCareerAmbition>()
        for recognition in journey.recognitions where recognition.contentID.hasPrefix(ambitionRewardPrefix) {
            guard recognition.kind == .milestone,
                  recognition.contentID.hasSuffix(ambitionRewardSuffix) else {
                throw SimulationError.invalidProCareer("invalid ambition reward recognition")
            }
            let raw = recognition.contentID.dropFirst(ambitionRewardPrefix.count)
                .dropLast(ambitionRewardSuffix.count)
            guard let ambition = ProCareerAmbition(rawValue: String(raw)),
                  rewardedAmbitions.insert(ambition).inserted,
                  journey.goalHistory.contains(where: { $0.ambition == ambition && $0.outcome == .completed }) else {
                throw SimulationError.invalidProCareer("ambition reward is duplicated or unearned")
            }
        }
        guard rewardedAmbitions.count <= 3 else {
            throw SimulationError.invalidProCareer("too many ambition rewards")
        }
        for record in journey.goalHistory where record.outcome == .completed {
            guard let completedSeason = record.completedSeason,
                  journey.recognitions.filter({ recognition in
                      recognition.kind == .milestone
                          && recognition.contentID == "pro.ambition.\(record.ambition.rawValue).completed"
                          && recognition.season == completedSeason
                          && recognition.teamID != nil
                  }).count == 1 else {
                throw SimulationError.invalidProCareer("completed goal is missing its reward")
            }
        }
        guard journey.finances.transactions.count <= 64,
              Set(journey.finances.transactions.map(\.id)).count == journey.finances.transactions.count,
              journey.finances.transactions.allSatisfy({ transaction in
                  if transaction.kind == .investment { return transaction.amount < 0 }
                  if transaction.kind == .merchandise || transaction.kind == .endorsement {
                      return transaction.amount >= 0
                  }
                  return transaction.amount > 0
              }) else {
            throw SimulationError.invalidProCareer("invalid finance transaction")
        }
        guard journey.finances.careerEarnings >= 0,
              journey.finances.availableFunds >= 0,
              journey.finances.salaryCreditedThroughSeason >= 0,
              journey.finances.transactions.allSatisfy({ $0.season >= 1 }) else {
            throw SimulationError.invalidProCareer("invalid finance totals")
        }
        var positiveTransactions: Int64 = 0
        var negativeTransactions: Int64 = 0
        for transaction in journey.finances.transactions {
            if transaction.amount > 0 {
                guard positiveTransactions <= Int64.max - transaction.amount else {
                    throw SimulationError.invalidProCareer("finance overflow")
                }
                positiveTransactions += transaction.amount
            } else {
                guard transaction.amount != Int64.min else {
                    throw SimulationError.invalidProCareer("finance overflow")
                }
                let magnitude = -transaction.amount
                guard negativeTransactions <= Int64.max - magnitude else {
                    throw SimulationError.invalidProCareer("finance overflow")
                }
                negativeTransactions += magnitude
            }
        }
        guard journey.finances.careerEarnings >= positiveTransactions else {
            throw SimulationError.invalidProCareer("finance earnings do not cover transactions")
        }
        if journey.finances.transactions.count < 64 {
            guard negativeTransactions <= journey.finances.careerEarnings,
                  journey.finances.availableFunds == journey.finances.careerEarnings - negativeTransactions else {
                throw SimulationError.invalidProCareer("finance totals do not match transactions")
            }
        } else {
            guard journey.finances.availableFunds <= journey.finances.careerEarnings else {
                throw SimulationError.invalidProCareer("finance funds exceed earnings")
            }
        }
        let rookieRecords = journey.contractHistory.filter { $0.kind == .rookie }
        for transaction in journey.finances.transactions where transaction.kind == .signingBonus {
            guard let record = rookieRecords.first(where: {
                transaction.id == "signing:\(state.proCareerID):\($0.contractID)"
            }),
            transaction.season == record.signedSeason,
            transaction.amount == Int64(record.signingBonus ?? 0) else {
                throw SimulationError.invalidProCareer("rookie contract finance is inconsistent")
            }
        }
        func validStats(_ stats: ProSeasonStats) -> Bool {
            stats.season >= 1 && !stats.teamID.isEmpty
                && stats.games >= 0 && stats.starts >= 0 && stats.inningsOuts >= 0
                && stats.strikeouts >= 0 && stats.walks >= 0 && stats.runsAllowed >= 0
                && stats.hits >= 0 && stats.homeRuns >= 0 && stats.pitches >= 0
                && stats.wins >= 0 && stats.losses >= 0 && stats.saves >= 0
        }
        guard validStats(state.currentStats), state.careerStats.allSatisfy(validStats) else {
            throw SimulationError.invalidProCareer("invalid career stat row")
        }
        if let transition = journey.offseasonTransition {
            guard transition.afterSeason == state.season,
                  transition.nextSeason == state.season + 1,
                  transition.ageAdvanceYears == (transition.includesMilitaryService ? 2 : 1),
                  [.contractOffer, .offseasonInvestment].contains(state.phase) else {
                throw SimulationError.invalidProCareer("invalid_transition")
            }
            if transition.route == .underContract {
                guard state.contract?.yearsRemaining ?? 0 >= 1 else {
                    throw SimulationError.invalidProCareer("expired_contract")
                }
            } else {
                guard state.contract?.yearsRemaining == 0,
                      state.phase == .contractOffer,
                      let market = journey.pendingContractMarket,
                      market.forSeason == transition.nextSeason else {
                    throw SimulationError.invalidProCareer("invalid_transition")
                }
                let expectedKind: ProContractMarketKind = transition.route == .renewalMarket ? .renewal : .freeAgency
                guard market.kind == expectedKind else {
                    throw SimulationError.invalidProCareer("invalid_transition")
                }
            }
        }
        for record in journey.contractHistory {
            let hasKind = record.kind != nil
            let hasExpectation = record.expectation != nil
            let isMigratedLegacy = journey.migration.source == .legacySafeBoundary
                && record.contractID == "contract:\(state.proCareerID):legacy:\(journey.migration.initializedSeason)"
            guard hasKind == hasExpectation,
                  hasKind || isMigratedLegacy else {
                throw SimulationError.invalidProCareer("new journey contracts require kind and expectation")
            }
            guard !record.contractID.isEmpty,
                  !record.teamID.isEmpty,
                  record.signedSeason >= 1,
                  (1...4).contains(record.totalYears),
                  record.annualSalary > 0,
                  record.coveredSeasons == Array(Set(record.coveredSeasons)).sorted(),
                  record.coveredSeasons.count <= record.totalYears,
                  record.coveredSeasons.allSatisfy({ $0 >= record.signedSeason }),
                  record.fulfilledExpectationSeasons == Array(Set(record.fulfilledExpectationSeasons)).sorted(),
                  Set(record.fulfilledExpectationSeasons).isSubset(of: Set(record.coveredSeasons)),
                  record.endedSeason.map({ $0 >= record.signedSeason }) ?? true else {
                throw SimulationError.invalidProCareer("invalid contract audit record")
            }
            if record.endReason == .expired {
                guard record.endedSeason != nil,
                      record.coveredSeasons.count == record.totalYears else {
                    throw SimulationError.invalidProCareer("expired contract audit is incomplete")
                }
            } else if record.endedSeason != nil || record.endReason != nil {
                guard record.endReason == .retired else {
                    throw SimulationError.invalidProCareer("contract end reason is inconsistent")
                }
            }
            if record.kind == .rookie {
                guard record.totalYears == 3,
                      record.signingBonus.map({ $0 > 0 }) ?? false,
                      let bonus = record.signingBonus else {
                    throw SimulationError.invalidProCareer("invalid rookie contract record")
                }
                let signingID = "signing:\(state.proCareerID):\(record.contractID)"
                let signingRows = journey.finances.transactions.filter { $0.id == signingID }
                if let signing = signingRows.first {
                    guard signingRows.count == 1,
                          signing.kind == .signingBonus,
                          signing.season == record.signedSeason,
                          signing.amount == Int64(bonus) else {
                        throw SimulationError.invalidProCareer("rookie contract finance is inconsistent")
                    }
                } else {
                    guard signingTransactionWasLegitimatelyEvicted(
                        record: record,
                        state: state,
                        journey: journey
                    ) else {
                        throw SimulationError.invalidProCareer("rookie contract signing transaction is missing")
                    }
                }
            }
        }
        let statKeys = state.careerStats.map { "\($0.season):\($0.teamID)" }
        guard Set(statKeys).count == statKeys.count else { throw SimulationError.invalidProCareer("duplicate career stat row") }
        let summed = ProTeamCareerRecordRules.backfill(
            careerStats: state.careerStats,
            recognitions: journey.recognitions,
            existing: journey.teamRecords
        )
        let statsOnly = ProTeamCareerRecordRules.backfill(
            careerStats: state.careerStats,
            recognitions: journey.recognitions,
            existing: []
        )
        let statsOnlyByTeam = Dictionary(uniqueKeysWithValues: statsOnly.map { ($0.teamID, $0) })
        let providedByTeam = Dictionary(uniqueKeysWithValues: journey.teamRecords.map { ($0.teamID, $0) })
        guard Set(providedByTeam.keys) == Set(summed.map(\.teamID)) else {
            throw SimulationError.invalidProCareer("team records do not match career stat teams")
        }
        for record in summed {
            guard let provided = providedByTeam[record.teamID],
                  !provided.teamID.isEmpty,
                  provided.completedSeasons == record.completedSeasons,
                  provided.consecutiveSeasons == record.consecutiveSeasons,
                  provided.games == record.games,
                  provided.starts == record.starts,
                  provided.inningsOuts == record.inningsOuts,
                  provided.strikeouts == record.strikeouts,
                  provided.wins == record.wins,
                  provided.saves == record.saves,
                  provided.awardCount == record.awardCount,
                  provided.lastSeason == record.lastSeason,
                  provided.communityPoints >= 0 else {
                throw SimulationError.invalidProCareer("team record totals do not match career stats")
            }
            if let computed = statsOnlyByTeam[record.teamID] {
                guard provided.completedSeasons == computed.completedSeasons,
                      provided.consecutiveSeasons == computed.consecutiveSeasons,
                      provided.games == computed.games,
                      provided.starts == computed.starts,
                      provided.inningsOuts == computed.inningsOuts,
                      provided.strikeouts == computed.strikeouts,
                      provided.wins == computed.wins,
                      provided.saves == computed.saves,
                      provided.awardCount == computed.awardCount,
                      provided.lastSeason == computed.lastSeason else {
                    throw SimulationError.invalidProCareer("team record stat sums do not match career stats")
                }
            } else if provided.completedSeasons > 0 {
                guard provided.completedSeasons == 0,
                      provided.consecutiveSeasons == 0,
                      provided.games == 0,
                      provided.starts == 0,
                      provided.inningsOuts == 0,
                      provided.strikeouts == 0,
                      provided.wins == 0,
                      provided.saves == 0,
                      provided.awardCount == 0,
                      provided.lastSeason == nil else {
                    throw SimulationError.invalidProCareer("team record has stats without career rows")
                }
            }
            if provided.completedSeasons == 0 {
                guard provided.consecutiveSeasons == 0,
                      provided.games == 0,
                      provided.starts == 0,
                      provided.inningsOuts == 0,
                      provided.strikeouts == 0,
                      provided.wins == 0,
                      provided.saves == 0,
                      provided.awardCount == 0,
                      provided.lastSeason == nil else {
                    throw SimulationError.invalidProCareer("zero team record contains completed statistics")
                }
            } else {
                guard provided.consecutiveSeasons >= 1,
                      provided.consecutiveSeasons <= provided.completedSeasons else {
                    throw SimulationError.invalidProCareer("team record continuity is invalid")
                }
            }
        }

        if let market = journey.pendingContractMarket {
            guard !market.id.isEmpty,
                  market.forSeason >= 1,
                  market.generatedAtRevision <= state.revision,
                  !market.offers.isEmpty,
                  Set(market.offers.map(\.id)).count == market.offers.count,
                  market.offers.allSatisfy({ $0.years >= 1 && $0.annualSalary > 0 }) else {
                throw SimulationError.invalidProCareer("invalid contract market")
            }
            try validateStoredJourneyMarket(market, state: state)
        }
        let activePhases: Set<ProCareerPhase> = [.weeklyPlan, .seasonDecision, .importantGame, .seasonReview]
        if activePhases.contains(state.phase) {
            guard !state.careerStats.contains(where: {
                $0.season == state.season && $0.teamID == state.currentStats.teamID
            }) else {
                throw SimulationError.invalidProCareer("active journey phase already contains current season")
            }
            guard let contract = state.contract else {
                throw SimulationError.invalidProCareer("missing_contract")
            }
            guard contract.yearsRemaining >= 1 else {
                throw SimulationError.invalidProCareer("expired_contract")
            }
            guard let contractID = contract.id,
                  contract.teamID == state.team.id,
                  let totalYears = contract.totalYears,
                  let signedSeason = contract.signedSeason,
                  ((contract.kind != nil && contract.expectation != nil)
                    || (journey.migration.source == .legacySafeBoundary
                        && contract.kind == nil
                        && contract.expectation == nil)),
                  journey.contractHistory.contains(where: { $0.contractID == contractID }),
                  (contract.kind == .rookie ? totalYears == 3 : (1...4).contains(totalYears))
                    || journey.migration.source == .legacySafeBoundary,
                  signedSeason >= 1 else {
                throw SimulationError.invalidProCareer("active journey phase requires a full contract")
            }
            guard journey.pendingContractMarket == nil, journey.offseasonTransition == nil else {
                throw SimulationError.invalidProCareer("active journey phase cannot have a market or transition")
            }
        }
        if let contract = state.contract {
            guard contract.yearsRemaining >= 0,
                  contract.annualSalary > 0,
                  contract.totalYears.map({ (1...4).contains($0) }) ?? true,
                  contract.teamID.map({ $0 == state.team.id }) ?? true else {
                throw SimulationError.invalidProCareer("invalid journey contract snapshot")
            }
            if let contractID = contract.id,
               let record = journey.contractHistory.first(where: { $0.contractID == contractID }) {
                guard contract.kind == record.kind,
                      contract.expectation == record.expectation,
                      contract.teamID == record.teamID,
                      contract.annualSalary == record.annualSalary,
                      contract.rolePromise == record.rolePromise,
                      contract.totalYears == record.totalYears,
                      contract.signedSeason == record.signedSeason else {
                    throw SimulationError.invalidProCareer("contract kind and expectation do not match audit record")
                }
                let covered = record.coveredSeasons
                guard covered == Array(Set(covered)).sorted(),
                      record.signedSeason >= 1,
                      (1...4).contains(record.totalYears),
                      record.annualSalary > 0,
                      covered.allSatisfy({ $0 >= record.signedSeason }),
                      covered.count <= record.totalYears,
                      record.fulfilledExpectationSeasons == Array(Set(record.fulfilledExpectationSeasons)).sorted(),
                      Set(record.fulfilledExpectationSeasons).isSubset(of: Set(covered)) else {
                    throw SimulationError.invalidProCareer("contract season audit is not canonical")
                }
                if state.phase != .contractOffer {
                    guard record.totalYears == covered.count + contract.yearsRemaining
                        || record.endReason == .retired else {
                        throw SimulationError.invalidProCareer("contract coverage does not match remaining years")
                    }
                    if contract.yearsRemaining == 0 {
                        guard record.endReason == .expired || record.endReason == .retired else {
                            throw SimulationError.invalidProCareer("expired_contract")
                        }
                    } else {
                        guard record.endReason == nil, record.endedSeason == nil else {
                            throw SimulationError.invalidProCareer("active contract is already ended")
                        }
                    }
                }
            } else if state.phase != .contractOffer {
                throw SimulationError.invalidProCareer("journey contract is missing its audit record")
            }
        }
        if journey.migration.source == .newCareer,
           let contract = state.contract,
           contract.kind == .rookie,
           let signedSeason = contract.signedSeason {
            let expiredNonRookieMarket = state.phase == .contractOffer
                && contract.yearsRemaining == 0
                && journey.pendingContractMarket?.kind != .rookie
            let completedCareerBoundary = contract.yearsRemaining == 0
                && [.seasonSettlement, .offseasonDecision].contains(state.phase)
            if let goal = journey.activeGoal {
                guard goal.selectedSeason == signedSeason,
                      goal.anchorTeamID == (goal.ambition == .franchiseIcon ? state.team.id : nil),
                      goal.id == ProCareerGoalRules.goalID(
                        careerID: state.proCareerID,
                        season: goal.selectedSeason,
                        ambition: goal.ambition,
                        anchorTeamID: goal.anchorTeamID
                      ) else {
                    throw SimulationError.invalidProCareer("goal and rookie contract are inconsistent")
                }
            } else if !(expiredNonRookieMarket || completedCareerBoundary
                        || journey.goalHistory.contains(where: { $0.outcome == .completed })) {
                throw SimulationError.invalidProCareer("goal and rookie contract are inconsistent")
            } else if expiredNonRookieMarket || completedCareerBoundary {
                let completedAmbitions = Set(journey.goalHistory.filter { $0.outcome == .completed }.map(\.ambition))
                guard completedAmbitions.count == 3 else {
                    throw SimulationError.invalidProCareer("goal and rookie contract are inconsistent")
                }
            }
        }
        switch state.phase {
        case .contractOffer:
            if let market = journey.pendingContractMarket {
                if market.kind == .rookie {
                    guard state.contract == nil,
                          journey.contractHistory.isEmpty,
                          journey.activeGoal == nil,
                          market.forSeason == 1,
                          market.offers.count == 1 else {
                        throw SimulationError.invalidProCareer("invalid rookie market state")
                    }
                } else {
                    guard state.contract?.yearsRemaining == 0,
                          journey.offseasonTransition != nil else {
                        throw SimulationError.invalidProCareer("invalid non-rookie market state")
                    }
                }
            } else {
                throw SimulationError.invalidProCareer("contract offer requires a market")
            }
            guard journey.settlementAcknowledged else {
                throw SimulationError.invalidProCareer("unacknowledged offer cannot contain a settlement")
            }
        case .seasonSettlement:
            guard let settlement = journey.lastSettlement,
                  !journey.settlementAcknowledged,
                  settlement.season == state.season,
                  settlement.teamID == state.team.id,
                  settlement.stats == state.currentStats,
                  settlement.salaryIncome > 0,
                  settlement.merchandiseIncome >= 0,
                  (0...100).contains(settlement.fanBefore),
                  (0...100).contains(settlement.fanAfter),
                  (0...100).contains(settlement.teamLegacyBefore),
                  (0...100).contains(settlement.teamLegacyAfter),
                  (0...100).contains(settlement.hallOfFameBefore),
                  (0...100).contains(settlement.hallOfFameAfter),
                  settlement.contractYearsBefore >= 1,
                  settlement.contractYearsBefore <= 4,
                  settlement.contractYearsAfter >= 0,
                  settlement.contractYearsAfter <= settlement.contractYearsBefore,
                  state.careerStats.contains(where: { $0.season == state.season && $0.teamID == settlement.teamID }) else {
                throw SimulationError.invalidProCareer("settlement phase requires an unacknowledged saved settlement")
            }
            let awardIDs = settlement.newAwardIDs
            let milestoneIDs = settlement.newMilestoneIDs
            guard awardIDs == awardIDs.sorted(),
                  milestoneIDs == milestoneIDs.sorted(),
                  Set(awardIDs).count == awardIDs.count,
                  Set(milestoneIDs).count == milestoneIDs.count,
                  Set(awardIDs).isDisjoint(with: Set(milestoneIDs)) else {
                throw SimulationError.invalidProCareer("settlement recognition IDs are not canonical")
            }
            let recognitionsByID = Dictionary(uniqueKeysWithValues: journey.recognitions.map { ($0.id, $0) })
            guard awardIDs.allSatisfy({ id in
                guard let recognition = recognitionsByID[id] else { return false }
                return recognition.kind == .award
                    && recognition.season == settlement.season
                    && recognition.teamID == settlement.teamID
                    && ProTeamCareerRecordRules.isRecognizedTeamAward(recognition)
            }), milestoneIDs.allSatisfy({ id in
                guard let recognition = recognitionsByID[id] else { return false }
                return recognition.kind == .milestone
                    && recognition.season == settlement.season
                    && recognition.teamID == settlement.teamID
            }) else {
                throw SimulationError.invalidProCareer("settlement recognition IDs do not match the season and team")
            }
            if settlement.merchandiseTier != nil {
                let contractID = state.contract?.id ?? "contract:\(state.proCareerID):legacy:\(journey.migration.initializedSeason)"
                let salaryID = "salary:\(state.proCareerID):\(state.season):\(contractID)"
                let merchandiseID = "merch:\(state.proCareerID):\(state.season)"
                guard journey.finances.salaryCreditedThroughSeason >= state.season,
                      let salary = journey.finances.transactions.first(where: { $0.id == salaryID }),
                      salary.kind == .salary,
                      salary.season == state.season,
                      salary.amount == settlement.salaryIncome,
                      let merchandise = journey.finances.transactions.first(where: { $0.id == merchandiseID }),
                      merchandise.kind == .merchandise,
                      merchandise.season == state.season,
                      merchandise.amount == settlement.merchandiseIncome else {
                    throw SimulationError.invalidProCareer("settlement finance transactions are incomplete")
                }
            }
            if settlement.fanReasons.isEmpty && settlement.merchandiseTier == nil {
                // Legacy Wave 1–4 settlements only stored the ambition reward. Preserve their
                // signed meaning while allowing all new settlements to use the typed breakdown.
                guard settlement.fanAfter == min(100, settlement.fanBefore + (settlement.goalCompleted ? 10 : 0)) else {
                    throw SimulationError.invalidProCareer("settlement fan reward is inconsistent")
                }
            } else {
                guard settlement.fanBefore >= 0, settlement.fanBefore <= 100,
                      settlement.fanAfter >= 0, settlement.fanAfter <= 100,
                      settlement.fanDelta >= -12, settlement.fanDelta <= 20,
                      settlement.fanReasons.map(\.id) == settlement.fanReasons.map(\.id).sorted(),
                      Set(settlement.fanReasons.map(\.id)).count == settlement.fanReasons.count else {
                    throw SimulationError.invalidProCareer("settlement fan reasons are not canonical")
                }
                var rawDelta = 0
                for reason in settlement.fanReasons {
                    guard !reason.contentID.isEmpty, reason.delta != 0,
                          (-20...20).contains(reason.delta) else {
                        throw SimulationError.invalidProCareer("settlement fan reason is invalid")
                    }
                    let (sum, overflow) = rawDelta.addingReportingOverflow(reason.delta)
                    guard !overflow else { throw SimulationError.invalidProCareer("settlement fan reason overflow") }
                    rawDelta = sum
                }
                let expectedDelta = clamp(rawDelta, -12, 20)
                guard settlement.fanDelta == expectedDelta,
                      settlement.fanAfter == clamp(settlement.fanBefore + expectedDelta, 0, 100),
                      settlement.merchandiseIncome == ProFinanceRules.merchandiseIncome(for: settlement.fanBefore),
                      settlement.merchandiseTier == ProFinanceRules.merchandiseTier(for: settlement.fanBefore),
                      journey.reputation.lastMerchandiseTier == settlement.merchandiseTier else {
                    throw SimulationError.invalidProCareer("settlement fan or merchandise values are inconsistent")
                }
            }
            if let before = settlement.goalProgressBefore {
                guard let after = settlement.goalProgressAfter,
                      before.ambition == after.ambition else {
                    throw SimulationError.invalidProCareer("settlement goal progress is incomplete")
                }
                let expected = ProCareerGoalRules.expectedMetrics(for: before.ambition)
                guard before.metrics.map(\.kind) == expected.map(\.kind),
                      after.metrics.map(\.kind) == expected.map(\.kind),
                      before.metrics.map(\.target) == expected.map(\.target),
                      after.metrics.map(\.target) == expected.map(\.target),
                      before.completed == before.metrics.allSatisfy({ $0.current >= $0.target }),
                      after.completed == after.metrics.allSatisfy({ $0.current >= $0.target }) else {
                    throw SimulationError.invalidProCareer("settlement goal metrics are malformed")
                }
                let completionRecognitionID = "recognition:\(state.proCareerID):\(settlement.season):milestone:pro.ambition.\(after.ambition.rawValue).completed"
                let completionIDs = milestoneIDs.filter { id in
                    recognitionsByID[id]?.contentID.hasPrefix("pro.ambition.") == true
                }
                let completionFanReasonCount = settlement.fanReasons.filter { $0.kind == .careerAmbitionCompleted }.count
                switch (before.completed, after.completed) {
                case (false, true):
                    guard settlement.goalCompleted,
                          completionFanReasonCount == 1,
                          journey.goalHistory.contains(where: { $0.ambition == after.ambition && $0.outcome == .completed }),
                          completionIDs == [completionRecognitionID] else {
                        throw SimulationError.invalidProCareer("settlement ambition completion is not exact-once")
                    }
                case (false, false):
                    guard !settlement.goalCompleted,
                          completionFanReasonCount == 0,
                          completionIDs.isEmpty else {
                        throw SimulationError.invalidProCareer("settlement false-to-false transition emitted a completion")
                    }
                case (true, true):
                    guard !settlement.goalCompleted,
                          completionFanReasonCount == 0,
                          completionIDs.isEmpty else {
                        throw SimulationError.invalidProCareer("settlement true-to-true transition emitted a duplicate completion")
                    }
                case (true, false):
                    throw SimulationError.invalidProCareer("settlement goal completion regressed")
                }
            } else {
                guard settlement.goalProgressAfter == nil,
                      !settlement.goalCompleted,
                      !milestoneIDs.contains(where: { recognitionsByID[$0]?.contentID.hasPrefix("pro.ambition.") == true }) else {
                    throw SimulationError.invalidProCareer("settlement contains an invalid goal completion")
                }
            }
            guard journey.pendingContractMarket == nil, journey.offseasonTransition == nil else {
                throw SimulationError.invalidProCareer("settlement cannot have a market or transition")
            }
            guard state.currentStats.season == state.season,
                  state.currentStats.teamID == state.team.id,
                  state.careerStats.filter({ $0.season == state.season && $0.teamID == state.team.id }).count == 1 else {
                throw SimulationError.invalidProCareer("settlement current season row is inconsistent")
            }
        case .offseasonDecision, .retirementDecision:
            guard journey.settlementAcknowledged,
                  journey.pendingContractMarket == nil,
                  journey.offseasonTransition == nil else {
                throw SimulationError.invalidProCareer("offseason requires an acknowledged settlement")
            }
            if let settlement = journey.lastSettlement {
                guard state.careerStats.filter({ $0.season == settlement.season && $0.teamID == settlement.teamID }).count == 1 else {
                    throw SimulationError.invalidProCareer("acknowledged settlement row is inconsistent")
                }
            }
        case .offseasonInvestment:
            guard journey.settlementAcknowledged,
                  let transition = journey.offseasonTransition,
                  transition.route == .underContract,
                  state.contract?.yearsRemaining ?? 0 >= 1,
                  journey.pendingContractMarket == nil else {
                throw SimulationError.invalidProCareer("investment phase requires an active contract transition")
            }
        case .completed:
            guard journey.settlementAcknowledged,
                  journey.pendingContractMarket == nil,
                  journey.offseasonTransition == nil,
                  journey.activeGoal == nil,
                  state.contract == nil,
                  state.hallOfFameScore == ProCareerEngine.hallOfFameFinalScore(for: state),
                  journey.retirementHonors == ProRetirementRules.honors(for: state),
                  journey.retirementHonors == journey.retirementHonors.sorted(by: ProRetirementRules.canonicalOrder),
                  journey.retirementHonors.filter({ $0.kind == .careerEarnings }).count == 1 else {
                throw SimulationError.invalidProCareer("completed journey state is not canonical")
            }
            for honor in journey.retirementHonors {
                switch honor.kind {
                case .hallOfFame:
                    guard honor.teamID == nil, honor.referenceID == nil,
                          honor.value == Int64(ProCareerEngine.hallOfFameFinalScore(for: state)) else {
                        throw SimulationError.invalidProCareer("invalid hall of fame honor")
                    }
                case .retiredNumber, .clubHall:
                    guard let teamID = honor.teamID, !teamID.isEmpty,
                          honor.referenceID == nil, honor.value == nil else {
                        throw SimulationError.invalidProCareer("invalid team honor")
                    }
                case .ambitionCompleted:
                    guard let referenceID = honor.referenceID,
                          ProCareerAmbition(rawValue: referenceID) != nil,
                          honor.teamID == nil, honor.value == nil else {
                        throw SimulationError.invalidProCareer("invalid ambition honor")
                    }
                case .careerEarnings:
                    guard honor.teamID == nil, honor.referenceID == nil,
                          honor.value == journey.finances.careerEarnings else {
                        throw SimulationError.invalidProCareer("invalid earnings honor")
                    }
                }
            }
        case .seasonReview, .weeklyPlan, .seasonDecision, .importantGame:
            break
        }
        if state.phase != .seasonSettlement && state.phase != .contractOffer {
            guard journey.settlementAcknowledged else {
                throw SimulationError.invalidProCareer("only settlement phase may be unacknowledged")
            }
        }
    }

    func chooseJourneyInvestment(_ params: ChooseProInvestmentParams) throws -> ProCareerResult {
        guard let journey = params.state.journeyState else {
            throw SimulationError.invalidProCareer("missing journey state")
        }
        guard params.expectedRevision == params.state.revision else {
            throw SimulationError.invalidProCareer("stale_revision")
        }
        try validate(params.state, phase: .offseasonInvestment)
        guard let transition = journey.offseasonTransition,
              transition.route == .underContract,
              let contract = params.state.contract,
              contract.yearsRemaining >= 1 else {
            throw SimulationError.invalidProCareer("invalid_transition")
        }
        guard journey.finances.investmentSeason != transition.nextSeason else {
            throw SimulationError.invalidProCareer("investment_already_selected")
        }
        if params.investment == .pitchLab, params.focus == nil {
            throw SimulationError.invalidProCareer("investment_focus_required")
        }
        if params.investment != .pitchLab, params.focus != nil {
            throw SimulationError.invalidProCareer("invalid_transition")
        }

        let nextSeason = transition.nextSeason
        let nextAge = params.state.age + transition.ageAdvanceYears
        let cost = ProFinanceRules.investmentCost(for: params.investment)
        guard journey.finances.availableFunds >= cost else {
            throw SimulationError.invalidProCareer("insufficient_funds")
        }
        let pitcher = ProContractMarketRules.projectedPitcher(
            for: params.state.pitcher,
            effectiveAge: nextAge
        )

        var transactions = journey.finances.transactions
        var availableFunds = journey.finances.availableFunds
        if cost > 0 {
            let transactionID = "investment:\(params.state.proCareerID):\(nextSeason):\(params.investment.rawValue)"
            guard !transactions.contains(where: { $0.id == transactionID }) else {
                throw SimulationError.invalidProCareer("investment_already_selected")
            }
            availableFunds -= cost
            guard availableFunds >= 0 else {
                throw SimulationError.invalidProCareer("insufficient_funds")
            }
            transactions = boundedFinanceTransactions(transactions + [ProFinanceTransaction(
                id: transactionID,
                season: nextSeason,
                kind: .investment,
                amount: -cost
            )])
        }
        let finances = ProFinanceState(
            careerEarnings: journey.finances.careerEarnings,
            availableFunds: availableFunds,
            salaryCreditedThroughSeason: journey.finances.salaryCreditedThroughSeason,
            transactions: transactions,
            investmentSeason: nextSeason
        )

        var developmentProgress = params.state.developmentProgress ?? .init()
        switch params.investment {
        case .pitchLab:
            guard let focus = params.focus else {
                throw SimulationError.invalidProCareer("investment_focus_required")
            }
            developmentProgress = seededDevelopmentProgress(developmentProgress, focus: focus)
        case .recoveryTeam, .fanFoundation, .none:
            break
        }
        let activeBenefit: ProSeasonBenefit?
        switch params.investment {
        case .recoveryTeam:
            activeBenefit = ProSeasonBenefit(kind: .injuryMitigation, focus: nil, remainingCharges: 1)
        case .pitchLab:
            activeBenefit = nil
        case .fanFoundation, .none:
            activeBenefit = nil
        }

        var teamRecords = ProTeamCareerRecordRules.backfill(
            careerStats: params.state.careerStats,
            recognitions: journey.recognitions,
            existing: journey.teamRecords
        )
        if params.investment == .fanFoundation {
            guard let existing = teamRecords.first(where: { $0.teamID == params.state.team.id }) else {
                throw SimulationError.invalidProCareer("missing_current_team_record")
            }
            guard existing.communityPoints <= Int.max - 4 else {
                throw SimulationError.invalidProCareer("community overflow")
            }
            let updatedRecord = ProTeamCareerRecord(
                teamID: existing.teamID,
                completedSeasons: existing.completedSeasons,
                consecutiveSeasons: existing.consecutiveSeasons,
                games: existing.games,
                starts: existing.starts,
                inningsOuts: existing.inningsOuts,
                strikeouts: existing.strikeouts,
                wins: existing.wins,
                saves: existing.saves,
                awardCount: existing.awardCount,
                communityPoints: existing.communityPoints + 4,
                lastSeason: existing.lastSeason
            )
            teamRecords = teamRecords.map { $0.teamID == updatedRecord.teamID ? updatedRecord : $0 }
        }
        let fanSupport = params.investment == .fanFoundation
            ? clamp(journey.reputation.fanSupport + 8, 0, 100)
            : journey.reputation.fanSupport
        let reputation = ProReputationState(
            fanSupport: fanSupport,
            lastMerchandiseTier: journey.reputation.lastMerchandiseTier,
            endorsementSeasons: journey.reputation.endorsementSeasons
        )
        let base = replacing(
            params.state,
            revision: params.state.revision + 1,
            phase: .weeklyPlan,
            pitcher: pitcher,
            age: nextAge,
            season: nextSeason,
            week: 0,
            role: contract.rolePromise,
            rolePreference: .some(contract.rolePromise),
            fatigue: 0,
            injuryWeeks: 0,
            currentStats: ProSeasonStats(season: nextSeason, teamID: params.state.team.id),
            gameLines: [],
            seasonSegment: .springCamp,
            seasonTrigger: .some(nil),
            currentRival: .some(nil),
            seasonTensions: .some(nil),
            seasonImportantGames: 0,
            pendingDecision: .some(nil),
            developmentProgress: developmentProgress,
            journeyState: .some(replacingJourney(
                journey,
                pendingContractMarket: .some(nil),
                teamRecords: teamRecords,
                reputation: reputation,
                finances: finances,
                activeSeasonBenefit: .some(activeBenefit),
                settlementAcknowledged: true,
                offseasonTransition: .some(nil)
            ))
        )
        let tensions = seasonTensions(for: base)
        let updated = replacing(base, seasonTensions: tensions)
        try validateState(signed(updated))
        return result(updated, nextSeed: params.seed, events: ["pro_offseason_resolved", "pro_offseason_investment_selected"])
    }

    private func seededDevelopmentProgress(
        _ progress: ProDevelopmentProgress,
        focus: ProDevelopmentFocus
    ) -> ProDevelopmentProgress {
        switch focus {
        case .stuff:
            return .init(stuff: 1, command: progress.command, movement: progress.movement, stamina: progress.stamina)
        case .command:
            return .init(stuff: progress.stuff, command: 1, movement: progress.movement, stamina: progress.stamina)
        case .movement:
            return .init(stuff: progress.stuff, command: progress.command, movement: 1, stamina: progress.stamina)
        case .stamina:
            return .init(stuff: progress.stuff, command: progress.command, movement: progress.movement, stamina: 1)
        }
    }

    func chooseJourneyOffseason(_ params: ProOffseasonParams) throws -> ProCareerResult {
        guard let journey = params.state.journeyState else {
            throw SimulationError.invalidProCareer("missing journey state")
        }
        guard let expectedRevision = params.expectedRevision,
              expectedRevision == params.state.revision else {
            throw SimulationError.invalidProCareer("stale_revision")
        }
        try validate(params.state, phase: params.state.phase)

        if params.decision == .retire {
            guard [.offseasonDecision, .retirementDecision].contains(params.state.phase) else {
                throw SimulationError.invalidProCareer("invalid_transition")
            }
            var contractHistory = journey.contractHistory
            if let contract = params.state.contract,
               let contractID = contract.id,
               let record = contractHistory.first(where: { $0.contractID == contractID && $0.endReason == nil }) {
                var coveredSeasons = record.coveredSeasons
                if params.state.careerStats.contains(where: {
                    $0.season == params.state.season && $0.teamID == params.state.team.id
                }) {
                    coveredSeasons.append(params.state.season)
                }
                let closedRecord = recordReplacing(
                    record,
                    coveredSeasons: Array(Set(coveredSeasons)).sorted(),
                    fulfilledExpectationSeasons: record.fulfilledExpectationSeasons,
                    endedSeason: params.state.season,
                    endReason: .retired
                )
                contractHistory = mergeContractRecord(closedRecord, into: contractHistory)
            }
            let goalHistory = try closedGoalHistoryForRetirement(state: params.state, journey: journey)
            let completed = replacingJourney(
                journey,
                activeGoal: .some(nil),
                goalHistory: goalHistory,
                pendingContractMarket: .some(nil),
                contractHistory: contractHistory,
                settlementAcknowledged: true,
                offseasonTransition: .some(nil)
            )
            let closing = replacing(
                params.state,
                revision: params.state.revision + 1,
                phase: .completed,
                contract: .some(nil),
                journeyState: .some(completed)
            )
            let preview = ProRetirementRules.preview(for: closing)
            let retiredJourney = replacingJourney(completed, retirementHonors: preview.honors)
            let retired = replacing(
                closing,
                hallOfFameScore: .some(preview.finalScore),
                journeyState: .some(retiredJourney)
            )
            let canonical = signed(retired)
            try validateState(canonical)
            return ProCareerResult(snapshot: canonical, nextSeed: params.seed, events: ["pro_career_retired"])
        }
        guard params.state.phase == .offseasonDecision,
              journey.settlementAcknowledged,
              journey.pendingContractMarket == nil,
              journey.offseasonTransition == nil,
              params.state.season < Self.maximumCareerSeasons else {
            throw SimulationError.invalidProCareer("invalid_transition")
        }

        // This is the read-only adapter for a migrated pre-Wave-3 contract. It preserves the
        // established Wave 1 safe-boundary behavior without ever invoking the old +3-team FA
        // path for a production journey contract.
        if journey.migration.source == .legacySafeBoundary,
           params.state.contract?.kind == nil,
           params.decision == .continueCareer,
           let contract = params.state.contract,
           contract.yearsRemaining >= 1 {
            let nextSeason = params.state.season + 1
            let nextState = replacing(
                params.state,
                revision: params.state.revision + 1,
                phase: .weeklyPlan,
                age: params.state.age + 1,
                season: nextSeason,
                week: 0,
                role: contract.rolePromise,
                rolePreference: .some(contract.rolePromise),
                fatigue: 0,
                injuryWeeks: 0,
                currentStats: ProSeasonStats(season: nextSeason, teamID: params.state.team.id),
                gameLines: [],
                seasonSegment: .springCamp,
                seasonTrigger: .some(nil),
                currentRival: .some(nil),
                seasonTensions: .some(nil),
                seasonImportantGames: 0,
                pendingDecision: .some(nil),
                journeyState: .some(replacingJourney(
                    journey,
                    pendingContractMarket: .some(nil),
                    settlementAcknowledged: true,
                    offseasonTransition: .some(nil)
                ))
            )
            let tensions = seasonTensions(for: nextState)
            return result(replacing(nextState, seasonTensions: tensions), nextSeed: params.seed, events: ["pro_offseason_resolved"])
        }

        guard let contract = params.state.contract else {
            throw SimulationError.invalidProCareer("missing_contract")
        }
        let isExpired = contract.yearsRemaining == 0
        let isMilitary = params.decision == .militaryService
        if isMilitary {
            guard !params.state.militaryCompleted else {
                throw SimulationError.invalidProCareer("military_already_completed")
            }
        }
        if !isExpired, params.decision == .freeAgency {
            throw SimulationError.invalidProCareer("fa_ineligible")
        }
        // Journey settlement has already credited the completed season to serviceYears. The
        // legacy path retains its historical pre-settlement calculation elsewhere; journey
        // markets must not count the just-finished major season a second time.
        let service = params.state.serviceYears
        if isExpired, params.decision == .freeAgency, service < 6 {
            throw SimulationError.invalidProCareer("fa_ineligible")
        }
        guard [.continueCareer, .militaryService, .freeAgency].contains(params.decision) else {
            throw SimulationError.invalidProCareer("invalid_transition")
        }

        let route: ProOffseasonTransitionRoute
        if isExpired {
            route = params.decision == .freeAgency || (isMilitary && service >= 6)
                ? .freeAgencyMarket
                : .renewalMarket
        } else {
            route = .underContract
        }
        let transition = ProOffseasonTransition(
            afterSeason: params.state.season,
            nextSeason: params.state.season + 1,
            ageAdvanceYears: isMilitary ? 2 : 1,
            includesMilitaryService: isMilitary,
            route: route
        )
        let fanAfter = isMilitary
            ? max(0, journey.reputation.fanSupport - 3)
            : journey.reputation.fanSupport
        let nextJourney = replacingJourney(
            journey,
            pendingContractMarket: .some(nil),
            reputation: ProReputationState(
                fanSupport: fanAfter,
                lastMerchandiseTier: journey.reputation.lastMerchandiseTier,
                endorsementSeasons: journey.reputation.endorsementSeasons
            ),
            settlementAcknowledged: true,
            offseasonTransition: .some(transition)
        )
        let nextRevision = params.state.revision + 1
        let waiting = replacing(
            params.state,
            revision: nextRevision,
            phase: route == .underContract ? .offseasonInvestment : .contractOffer,
            militaryCompleted: isMilitary ? true : nil,
            journeyState: .some(nextJourney)
        )
        if route == .underContract {
            try validateState(signed(waiting))
            return result(waiting, nextSeed: params.seed, events: ["pro_offseason_transition_saved"])
        }

        let market: ProContractMarket?
        switch route {
        case .renewalMarket:
            market = ProContractMarketRules.renewalMarket(state: waiting)
        case .freeAgencyMarket:
            market = ProContractMarketRules.freeAgencyMarket(state: waiting)
        case .underContract:
            market = nil
        }
        guard let market else {
            throw SimulationError.invalidProCareer("invalid_transition")
        }
        let withMarket = replacing(
            waiting,
            journeyState: .some(replacingJourney(nextJourney, pendingContractMarket: .some(market)))
        )
        try validateState(signed(withMarket))
        return result(withMarket, nextSeed: params.seed, events: ["pro_offseason_transition_saved", "pro_contract_market_opened"])
    }
}

public extension ProCareerEngine {
    /// Public migration entry point used by store and fixture tests. The implementation is kept
    /// on the engine so the feature flag and the frozen legacy validation share one boundary.
    func migrateJourneyIfSafe(_ params: ProStateParams) throws -> ProCareerResult {
        try migrateLegacyJourney(params)
    }
}

