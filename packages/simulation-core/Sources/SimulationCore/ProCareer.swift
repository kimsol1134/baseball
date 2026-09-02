import Foundation

public enum EntitlementStatus: String, Codable, Sendable { case locked, active }
public enum EntitlementSource: String, Codable, Sendable { case purchase, restore, offlineCache = "offline_cache", development }

public struct ProEntitlementSnapshot: Codable, Equatable, Sendable {
    public let productID: String
    public let status: EntitlementStatus
    public let source: EntitlementSource
    public let verifiedAt: String
    public let offlineValidUntil: String?
    public init(productID: String = "baseball_pro_career", status: EntitlementStatus, source: EntitlementSource, verifiedAt: String, offlineValidUntil: String? = nil) {
        self.productID = productID; self.status = status; self.source = source; self.verifiedAt = verifiedAt; self.offlineValidUntil = offlineValidUntil
    }
}


public struct ProCareerEngine: Sendable {
    public let journeyEnabled: Bool

    public init(journeyEnabled: Bool = false) {
        self.journeyEnabled = journeyEnabled
    }

    public func start(_ params: StartProCareerParams) throws -> ProCareerResult {
        guard let seed = UInt64(params.seed) else { throw SimulationError.invalidSeed(params.seed) }
        guard params.entitlement.status == .active else { throw SimulationError.invalidProCareer("프로 커리어 이용 권한을 확인할 수 없습니다.") }
        guard params.draftResult.outcome == .drafted,
              let draftedTeam = params.draftResult.team else {
            if journeyEnabled {
                throw SimulationError.invalidProCareer("invalid_draft")
            }
            throw SimulationError.invalidProCareer("고교 드래프트 지명 기록이 필요합니다.")
        }
        let team = HighSchoolCareerEngine.teams.first(where: { $0.id == draftedTeam.id }) ?? draftedTeam
        var rng = SplitMix64(seed: seed)
        let id = "pro-\(StableHash.fnv1a64("\(seed)|\(params.pitcher.id)|\(team.id)"))"
        let stats = ProSeasonStats(season: 1, teamID: team.id)
        let journeyState: ProCareerJourneyState?
        if journeyEnabled {
            guard !team.id.isEmpty,
                  let draftRound = params.draftResult.round,
                  draftRound >= 1,
                  let signingBonus = params.draftResult.signingBonus,
                  signingBonus > 0 else {
                throw SimulationError.invalidProCareer("invalid_draft")
            }
            journeyState = ProCareerJourneyState(
                rulesVersion: Self.currentJourneyRulesVersion,
                pendingContractMarket: ProContractMarketRules.rookieMarket(
                    careerID: id,
                    teamID: team.id,
                    draftRound: draftRound,
                    signingBonus: signingBonus,
                    generatedAtRevision: 0,
                    overallPick: params.draftResult.overallPick
                ),
                reputation: ProReputationState(
                    fanSupport: initialJourneyFanSupport(
                        draftEvaluation: params.draftResult.evaluationScore,
                        sourceFanInterest: params.sourceFanInterest
                    )
                )
            )
        } else {
            journeyState = nil
        }
        // Nil is the wire-compatible representation of a zero mastery track. It remains nil until
        // the first real overflow so legacy repertoire-only saves can continue using schema 4;
        // all readers expose the same `.zero` value through `effectiveMastery`.
        var pitcher = params.pitcher
        var repertoireRulesVersion = params.repertoireRulesVersion
        var pitchLearningProject = params.pitchLearningProject
        if let selection = params.startingRepertoire {
            guard repertoireRulesVersion == nil, pitchLearningProject == nil else {
                throw SimulationError.invalidProCareer("starting repertoire conflicts with inherited repertoire state")
            }
            let repertoire = try PitchLearningRules.apply(selection: selection, to: pitcher, chapter: nil)
            pitcher = repertoire.pitcher
            repertoireRulesVersion = PitchLearningRules.rulesVersion
            pitchLearningProject = repertoire.project
        }
        do {
            try PitchLearningRules.validateState(
                pitcher: pitcher,
                rulesVersion: repertoireRulesVersion,
                project: pitchLearningProject
            )
        } catch {
            throw SimulationError.invalidProCareer("invalid starting repertoire")
        }
        let base = ProCareerSnapshot(proCareerID: id, revision: 0, phase: .contractOffer, identity: params.identity, pitcher: pitcher, team: team, entitlement: params.entitlement, age: 19, season: 1, week: 0, level: .minor, role: .starter, managerTrust: 42, catcherTrust: 45, fatigue: 0, injuryWeeks: 0, serviceYears: 0, militaryCompleted: false, contract: nil, currentStats: stats, careerStats: [], awards: [], milestones: ["프로 지명"], news: ["신인 계약 제안 · \(team.name) · \(params.identity.name)"], hallOfFameScore: nil, commitment: "", balanceVersion: PitcherPresetCatalog.balanceVersion, proRulesVersion: params.proRulesVersion ?? Self.currentRulesVersion, seasonSegment: .springCamp, seasonImportantGames: 0, decisionHistory: [], repertoireRulesVersion: repertoireRulesVersion, pitchLearningProject: pitchLearningProject, journeyState: journeyState)
        let state = signed(base)
        if journeyEnabled {
            try validateState(state)
        }
        return result(state, nextSeed: String(rng.next()), events: ["pro_career_started"])
    }

    public func normalizeBalance(_ params: ProStateParams) throws -> ProCareerResult {
        _ = try generator(params.seed)
        try validateState(params.state)
        let sourceVersion = params.state.balanceVersion
            ?? PitcherPresetCatalog.inferredLegacyVersion(for: params.state.pitcher)
        let normalizationTargetVersion = 3
        let pitcher = PitcherPresetCatalog.migrate(
            params.state.pitcher,
            fromVersion: sourceVersion,
            targetVersion: normalizationTargetVersion
        )?.pitcher
            ?? params.state.pitcher
        let normalized = signed(replacing(params.state, pitcher: pitcher,
            balanceVersion: max(sourceVersion, normalizationTargetVersion)))
        return ProCareerResult(snapshot: normalized, nextSeed: params.seed, events: [])
    }

    public func signContract(_ params: ProStateParams) throws -> ProCareerResult {
        guard params.state.journeyState == nil else {
            throw SimulationError.invalidProCareer("journey contract requires an explicit offer")
        }
        try validate(params.state, phase: .contractOffer)
        var rng = try generator(params.seed)
        let bonus = max(30_000_000, params.state.pitcher.stuff * 1_000_000)
        let contract = ProContractSnapshot(yearsRemaining: 3, annualSalary: bonus, rolePromise: .starter)
        let tensions = seasonTensions(for: params.state)
        let state = replacing(params.state, revision: params.state.revision + 1, phase: .weeklyPlan, contract: contract,
            milestones: addingUnique("신인 계약", to: params.state.milestones),
            news: ["신인 계약에 서명했습니다. 2군 선발 경쟁이 시작됩니다.", tensionHeadline(tensions)] + params.state.news,
            seasonSegment: segment(forWeek: params.state.week), seasonTensions: tensions, seasonImportantGames: 0)
        return result(state, nextSeed: String(rng.next()), events: ["rookie_contract_signed"])
    }

    /// Accept one persisted offer. This command is deliberately seedless: the offer, contract,
    /// goal, and any finance change are all derived from the stored market, so a retry cannot
    /// consume a new offer or produce a second side effect.
    public func acceptContract(_ params: AcceptProContractParams) throws -> ProCareerResult {
        guard let journey = params.state.journeyState else {
            throw SimulationError.invalidProCareer("invalid_offer")
        }
        guard params.expectedRevision == params.state.revision else {
            throw SimulationError.invalidProCareer("stale_revision")
        }
        guard params.state.phase == .contractOffer else {
            throw SimulationError.invalidProCareer(
                params.state.journeyState?.pendingContractMarket == nil ? "stale_market" : "invalid_transition"
            )
        }
        try validate(params.state, phase: .contractOffer)
        guard let market = journey.pendingContractMarket else {
            throw SimulationError.invalidProCareer("stale_market")
        }
        guard market.id == params.marketID,
              market.generatedAtRevision == params.state.revision else {
            throw SimulationError.invalidProCareer("stale_market")
        }
        try validateStoredJourneyMarket(market, state: params.state)
        guard let offer = market.offers.first(where: { $0.id == params.offerID }) else {
            throw SimulationError.invalidProCareer("invalid_offer")
        }

        let isRookie = market.kind == .rookie
        if isRookie {
            _ = try rookieOffer(in: market, state: params.state)
            guard params.ambition != nil else {
                throw SimulationError.invalidProCareer("invalid_ambition")
            }
            guard params.state.contract == nil,
                  journey.contractHistory.isEmpty,
                  journey.activeGoal == nil,
                  !journey.finances.transactions.contains(where: { $0.id.hasPrefix("signing:\(params.state.proCareerID):") }) else {
                throw SimulationError.invalidProCareer("invalid_offer")
            }
        } else {
            guard params.state.contract?.yearsRemaining == 0,
                  offer.signingBonus == nil,
                  (1...4).contains(offer.years),
                  journey.offseasonTransition?.route != .underContract else {
                throw SimulationError.invalidProCareer("invalid_offer")
            }
        }

        let completedAmbitions = Set(
            journey.goalHistory.filter { $0.outcome == .completed }.map(\.ambition)
                + (journey.activeGoal?.completedSeason != nil ? [journey.activeGoal!.ambition] : [])
        )
        if !isRookie, params.ambition == nil {
            guard completedAmbitions.count == 3 else {
                throw SimulationError.invalidProCareer("invalid_ambition")
            }
        }
        if let ambition = params.ambition, !isRookie {
            guard !completedAmbitions.contains(ambition)
                || (journey.activeGoal?.ambition == ambition && journey.activeGoal?.completedSeason == nil) else {
                throw SimulationError.invalidProCareer("invalid_ambition")
            }
        }

        let contractID = "contract:\(params.state.proCareerID):\(market.forSeason):\(offer.id)"
        let contract = ProContractSnapshot(
            yearsRemaining: offer.years,
            annualSalary: offer.annualSalary,
            rolePromise: offer.rolePromise,
            id: contractID,
            teamID: offer.teamID,
            totalYears: offer.years,
            signedSeason: market.forSeason,
            kind: offer.contractKind,
            expectation: offer.expectation
        )
        let record = ProContractRecord(
            contractID: contractID,
            teamID: offer.teamID,
            kind: offer.contractKind,
            signedSeason: market.forSeason,
            totalYears: offer.years,
            annualSalary: offer.annualSalary,
            signingBonus: offer.signingBonus,
            rolePromise: offer.rolePromise,
            expectation: offer.expectation,
            coveredSeasons: [],
            fulfilledExpectationSeasons: [],
            endedSeason: nil,
            endReason: nil
        )

        let goalAnchor = params.ambition == .franchiseIcon ? offer.teamID : nil
        var goalHistory = journey.goalHistory
        let goal: ProCareerGoalState?
        if isRookie {
            guard let ambition = params.ambition else { throw SimulationError.invalidProCareer("invalid_ambition") }
            goal = ProCareerGoalState(
                id: ProCareerGoalRules.goalID(careerID: params.state.proCareerID, season: market.forSeason, ambition: ambition, anchorTeamID: goalAnchor),
                ambition: ambition,
                selectedSeason: market.forSeason,
                anchorTeamID: goalAnchor,
                completedSeason: nil
            )
        } else if let ambition = params.ambition {
            if let active = journey.activeGoal,
               active.completedSeason == nil,
               active.ambition == ambition,
               active.anchorTeamID == goalAnchor {
                goal = active
            } else {
                if let active = journey.activeGoal, active.completedSeason == nil {
                    goalHistory.append(ProCareerGoalRecord(
                        id: active.id,
                        ambition: active.ambition,
                        selectedSeason: active.selectedSeason,
                        anchorTeamID: active.anchorTeamID,
                        completedSeason: active.completedSeason,
                        endedSeason: params.state.season,
                        outcome: active.completedSeason == nil ? .replaced : .completed
                    ))
                }
                goal = ProCareerGoalState(
                    id: ProCareerGoalRules.goalID(careerID: params.state.proCareerID, season: market.forSeason, ambition: ambition, anchorTeamID: goalAnchor),
                    ambition: ambition,
                    selectedSeason: market.forSeason,
                    anchorTeamID: goalAnchor,
                    completedSeason: nil
                )
            }
        } else {
            if let active = journey.activeGoal {
                goalHistory.append(ProCareerGoalRecord(
                    id: active.id,
                    ambition: active.ambition,
                    selectedSeason: active.selectedSeason,
                    anchorTeamID: active.anchorTeamID,
                    completedSeason: active.completedSeason,
                    endedSeason: params.state.season,
                    outcome: .completed
                ))
            }
            goal = nil
        }
        var uniqueGoalHistory: [String: ProCareerGoalRecord] = [:]
        goalHistory.forEach { uniqueGoalHistory[$0.id] = $0 }
        goalHistory = uniqueGoalHistory.values.sorted { $0.id < $1.id }

        let zeroTeamRecord = ProTeamCareerRecord(
            teamID: offer.teamID,
            completedSeasons: 0,
            consecutiveSeasons: 0,
            games: 0,
            starts: 0,
            inningsOuts: 0,
            strikeouts: 0,
            wins: 0,
            saves: 0,
            awardCount: 0,
            communityPoints: 0,
            lastSeason: nil
        )
        var teamRecords = journey.teamRecords
        if teamRecords.first(where: { $0.teamID == offer.teamID }) == nil {
            teamRecords.append(zeroTeamRecord)
        }
        teamRecords = ProTeamCareerRecordRules.backfill(
            careerStats: params.state.careerStats,
            recognitions: journey.recognitions,
            existing: teamRecords
        )

        let bonus: Int64
        let finances: ProFinanceState
        if isRookie {
            guard let signingBonus = offer.signingBonus,
                  signingBonus > 0 else {
                throw SimulationError.invalidProCareer("invalid_offer")
            }
            bonus = Int64(signingBonus)
            guard journey.finances.careerEarnings <= Int64.max - bonus,
                  journey.finances.availableFunds <= Int64.max - bonus else {
                throw SimulationError.invalidProCareer("finance_overflow")
            }
            let transactionID = "signing:\(params.state.proCareerID):\(contractID)"
            let transaction = ProFinanceTransaction(id: transactionID, season: market.forSeason, kind: .signingBonus, amount: bonus)
            finances = ProFinanceState(
                careerEarnings: journey.finances.careerEarnings + bonus,
                availableFunds: journey.finances.availableFunds + bonus,
                salaryCreditedThroughSeason: journey.finances.salaryCreditedThroughSeason,
                transactions: boundedFinanceTransactions(journey.finances.transactions + [transaction]),
                investmentSeason: journey.finances.investmentSeason
            )
        } else {
            guard offer.signingBonus == nil else { throw SimulationError.invalidProCareer("invalid_offer") }
            bonus = 0
            finances = journey.finances
        }
        let preservesCurrentTeam = offer.teamID == params.state.team.id
        let fanSupport = preservesCurrentTeam ? journey.reputation.fanSupport : max(0, journey.reputation.fanSupport - 3)
        let reputation = ProReputationState(
            fanSupport: fanSupport,
            lastMerchandiseTier: journey.reputation.lastMerchandiseTier,
            endorsementSeasons: journey.reputation.endorsementSeasons
        )
        let transition: ProOffseasonTransition?
        if isRookie {
            transition = nil
        } else {
            guard let oldTransition = journey.offseasonTransition,
                  oldTransition.nextSeason == params.state.season + 1 else {
                throw SimulationError.invalidProCareer("invalid_transition")
            }
            transition = ProOffseasonTransition(
                afterSeason: oldTransition.afterSeason,
                nextSeason: oldTransition.nextSeason,
                ageAdvanceYears: oldTransition.ageAdvanceYears,
                includesMilitaryService: oldTransition.includesMilitaryService,
                route: .underContract
            )
        }
        let nextJourney = replacingJourney(
            journey,
            activeGoal: .some(goal),
            goalHistory: goalHistory,
            pendingContractMarket: .some(nil),
            contractHistory: mergeContractRecord(record, into: journey.contractHistory),
            teamRecords: teamRecords,
            reputation: reputation,
            finances: finances,
            settlementAcknowledged: true,
            offseasonTransition: .some(transition)
        )
        let nextState = replacing(
            params.state,
            revision: params.state.revision + 1,
            phase: isRookie ? .weeklyPlan : .offseasonInvestment,
            team: params.state.team.id == offer.teamID ? nil : Self.proTeams.first(where: { $0.id == offer.teamID }),
            role: offer.rolePromise,
            rolePreference: .some(offer.rolePromise),
            contract: .some(contract),
            milestones: isRookie ? addingUnique("신인 계약", to: params.state.milestones) : nil,
            journeyState: .some(nextJourney)
        )
        let canonical = signed(nextState)
        try validateState(canonical)
        return ProCareerResult(snapshot: canonical, nextSeed: params.seed, events: ["pro_contract_signed"])
    }

    public func acknowledgeSettlement(_ params: AcknowledgeProSettlementParams) throws -> ProCareerResult {
        guard let journey = params.state.journeyState,
              let settlement = journey.lastSettlement,
              settlement.id == params.settlementID else {
            throw SimulationError.invalidProCareer("invalid_settlement")
        }
        // A reload may already have moved past the settlement screen. A repeated tap is a
        // successful no-op only when it names the current stored settlement.
        if journey.settlementAcknowledged, params.state.phase != .seasonSettlement {
            return result(params.state, nextSeed: params.seed, events: ["pro_settlement_acknowledged_idempotent"])
        }
        guard params.expectedRevision == params.state.revision else {
            throw SimulationError.invalidProCareer("stale_revision")
        }
        try validate(params.state, phase: .seasonSettlement)
        let nextPhase: ProCareerPhase = settlement.nextRoute == .forcedRetirement
            ? .retirementDecision
            : .offseasonDecision
        let nextMigration = ProJourneyMigration(
            source: journey.migration.source,
            initializedSeason: journey.migration.initializedSeason,
            financeStartsSeason: journey.migration.financeStartsSeason,
            unassignedLegacyAwards: journey.migration.unassignedLegacyAwards,
            financeNoticePending: false
        )
        let nextJourney = replacingJourney(
            journey,
            settlementAcknowledged: .some(true),
            migration: nextMigration
        )
        let updated = replacing(
            params.state,
            revision: params.state.revision + 1,
            phase: nextPhase,
            journeyState: .some(nextJourney)
        )
        return result(updated, nextSeed: params.seed, events: ["pro_settlement_acknowledged"])
    }

    public func chooseInvestment(_ params: ChooseProInvestmentParams) throws -> ProCareerResult {
        guard journeyEnabled, params.state.journeyState != nil else {
            throw SimulationError.invalidProCareer("invalid_transition")
        }
        return try chooseJourneyInvestment(params)
    }

    public func planWeek(_ params: PlanProWeekParams) throws -> ProCareerResult {
        try validate(params.state, phase: .weeklyPlan)
        if params.plan == .developMovement {
            do {
                try PitchLearningRules.validateTrainingTarget(
                    params.targetPitch,
                    pitcher: params.state.pitcher,
                    rulesVersion: params.state.repertoireRulesVersion,
                    project: params.state.pitchLearningProject
                )
            } catch {
                throw SimulationError.invalidProCareer("invalid pitch development target")
            }
        }
        var rng = try generator(params.seed)
        let state = params.state
        let nextWeek = state.week + 1
        let recovering = state.injuryWeeks > 0
        let skill = (state.pitcher.stuff + state.pitcher.command + state.pitcher.movement + state.pitcher.stamina) / 4
        // 주간 자동 등판을 수동 중요 경기와 같은 커널로 실행한다(3줄 산식 폐기).
        let usesAgencyRules = Self.usesAgencyRules(state)
        let restingWeek = recovering || (!usesAgencyRules && params.plan == .recover)
        var outings: Int
        let outsTargetPerOuting: Int
        let pitchCapPerOuting: Int
        switch state.role {
        case .starter: outings = 1; outsTargetPerOuting = 18; pitchCapPerOuting = 96
        case .longRelief: outings = 2; outsTargetPerOuting = 6; pitchCapPerOuting = 42
        case .setup, .closer: outings = 3; outsTargetPerOuting = 3; pitchCapPerOuting = 24
        }
        var weekLine = WeeklyOutingLine()
        var newGameLines: [ProGameLine] = []
        let weekClimate = Self.liveClimate(for: state, week: nextWeek)
        let weekOffset = Self.liveBatterOffset(for: state, week: nextWeek)
        let weekCallPolicy: AutoCallPolicy = Self.usesCareerArcRules(state)
            ? ProSeasonClimateRules.callPolicy(for: weekClimate ?? .even)
            : .perfect
        var activeModifiers = (state.activeDecisionModifiers ?? []).filter { $0.expiresWeek >= nextWeek }
        if activeModifiers.contains(where: \.suppressOutings) {
            outings = 0
        } else if !restingWeek {
            var extraOutings = 0
            activeModifiers = activeModifiers.map { modifier in
                let remaining = max(0, modifier.extraOutingChance - (modifier.extraOutingsGranted ?? 0))
                guard remaining > 0 else { return modifier }
                extraOutings += remaining
                return modifier.granting(extraOutings: remaining)
            }
            outings = max(0, outings + extraOutings)
        }
        if !restingWeek {
            for outingIndex in 0..<outings {
                let outingLine = simulateWeeklyOuting(
                    pitcher: state.pitcher,
                    startingFatigue: state.fatigue + outingIndex * 5,
                    outsTarget: outsTargetPerOuting,
                    pitchCap: pitchCapPerOuting,
                    batterOffset: weekOffset,
                    callPolicy: weekCallPolicy,
                    baseSeed: rng.next() ^ UInt64(bitPattern: Int64(nextWeek &* 0x9E37)) &+ UInt64(outingIndex),
                    diverseScouting: Self.usesWeeklyDecisionRules(state)
                )
                weekLine.outs += outingLine.outs
                weekLine.strikeouts += outingLine.strikeouts
                weekLine.walks += outingLine.walks
                weekLine.runsAllowed += outingLine.runsAllowed
                weekLine.pitches += outingLine.pitches
                weekLine.hits += outingLine.hits
                weekLine.homeRuns += outingLine.homeRuns

                // 우리 타선이 몇 점을 냈는지를 실제 득점 분포에서 뽑는다. 이 값이 있어야
                // 승패가 규칙대로 붙고, 무엇보다 "잘 던지고도 못 이긴 날"이 생긴다.
                let support = LeagueBaseline.teamRuns(using: &rng)
                // 내가 던지지 않은 이닝의 실점. 선발이면 불펜 3~4이닝, 구원이면 나머지
                // 여덟 이닝 몫이다. 역할에 따라 따로 두면 마무리 등판 날만 상대 점수가
                // 비현실적으로 낮아진다.
                let othersOuts = max(0, 27 - outingLine.outs)
                let othersRuns = LeagueBaseline.restOfTeamRuns(outsCovered: othersOuts, using: &rng)
                let opponentRuns = outingLine.runsAllowed + othersRuns
                let started = state.role == .starter
                newGameLines.append(
                    ProGameLine(
                        season: state.season,
                        week: nextWeek,
                        outingNumber: (state.gameLines?.count ?? 0) + newGameLines.count + 1,
                        started: started,
                        outs: outingLine.outs,
                        strikeouts: outingLine.strikeouts,
                        walks: outingLine.walks,
                        runsAllowed: outingLine.runsAllowed,
                        pitches: outingLine.pitches,
                        teamRuns: support,
                        opponentRuns: opponentRuns,
                        decision: DecisionRules.decide(
                            started: started,
                            isCloser: state.role == .closer,
                            outs: outingLine.outs,
                            runsAllowed: outingLine.runsAllowed,
                            teamRuns: support,
                            opponentRuns: opponentRuns
                        ),
                        played: false,
                        hits: outingLine.hits,
                        homeRuns: outingLine.homeRuns
                    )
                )
            }
        }
        let games = restingWeek ? 0 : outings
        let starts = restingWeek ? 0 : (state.role == .starter ? outings : 0)
        let strikeouts = weekLine.strikeouts
        let walks = weekLine.walks
        let runs = weekLine.runsAllowed
        let fatigueDelta: Int
        if recovering {
            fatigueDelta = -20
        } else if usesAgencyRules {
            let trainingLoad = switch params.plan {
            case .developStuff: 10
            case .developMovement: 8
            case .developWeapon: 9
            case .refineCommand: 6
            case .buildStamina: 7
            case .earnTrust: 5
            case .recover: -16
            }
            let outingLoad = (weekLine.pitches + 14) / 15
            let staminaRelief = max(0, (state.pitcher.stamina - 50) / 15)
            fatigueDelta = trainingLoad + outingLoad - staminaRelief
        } else if params.plan == .recover {
            fatigueDelta = -20
        } else {
            fatigueDelta = switch params.plan {
            case .developStuff: 16
            case .developMovement: 13
            case .developWeapon: 15
            case .refineCommand: 9
            case .buildStamina: 10
            case .earnTrust, .recover: 10
            }
        }
        let fatigue = clamp(state.fatigue + fatigueDelta, 0, 100)
        let injuryRoll = rng.nextInt(upperBound: 100)
        var fatiguePressure = Self.injuryPressure(
            rawFatigue: fatigue,
            stamina: state.pitcher.stamina,
            mastery: state.pitcher.effectiveMastery.stamina,
            challengeRules: Self.usesChallengeRules(state)
        )
        if let injuryFloor = activeModifiers.compactMap(\.injuryPressureFloor).max() {
            fatiguePressure = max(fatiguePressure, injuryFloor)
        }
        // A low-fatigue week is safe.  The old `max(2, …)` made every healthy pitcher roll a
        // hidden injury event, so the result could not be connected to a choice.  A week without
        // an outing cannot be an overload event either; recovery is allowed to be a reliable
        // answer to a high-fatigue forecast.
        let injuryChancePercent = max(0, fatiguePressure - 72)
        let generatedInjury = !recovering
            && weekLine.pitches > 0
            && injuryRoll < injuryChancePercent
            ? 2 + rng.nextInt(upperBound: 4)
            : max(0, state.injuryWeeks - 1)
        let injuryMitigationConsumed = state.injuryWeeks == 0
            && generatedInjury > 0
            && state.journeyState?.activeSeasonBenefit?.kind == .injuryMitigation
            && state.journeyState?.activeSeasonBenefit?.remainingCharges == 1
        let newInjury = injuryMitigationConsumed ? max(0, generatedInjury - 1) : generatedInjury
        // 감독의 믿음은 **내려가기도 해야 한다.**
        //
        // 예전에는 잘 던지면 오르고 아니면 그대로였다(0). 한 방향으로만 움직이는 값은
        // 스테이크가 아니라 시간의 함수다 — 주차를 넘기기만 하면 언젠가 선발이 된다.
        // 실측상 프로 등판이 감독의 믿음을 평균 +1.9밖에 못 움직였던 이유가 이것이다.
        let performanceTrust: Int
        switch runs {
        case ...2: performanceTrust = 3
        case 3: performanceTrust = 0
        case 4...5: performanceTrust = -3
        default: performanceTrust = -6
        }
        let rawTrustGain = recovering ? -1
            : params.plan == .earnTrust ? 5
            : params.plan == .recover ? 0
            : performanceTrust
        // v8: 85를 넘긴 신뢰는 절반 속도로만 오른다. 이전에는 매주 +3이 그대로 쌓여 한
        // 시즌 만에 100에 붙었고, 그 뒤로는 스테이크가 사라졌다("감독믿음은 높을대로
        // 높으니까" 리뷰). 내려가는 폭은 그대로 둔다 — 부진의 대가는 여전히 즉각적이다.
        let trustGain = Self.usesChallengeRules(state) && state.managerTrust >= 85 && rawTrustGain > 0
            ? rawTrustGain / 2
            : rawTrustGain
        let trust = clamp(state.managerTrust + trustGain, 0, 100)
        let stats = ProSeasonStats(
            season: state.season, teamID: state.team.id,
            games: state.currentStats.games + games,
            starts: state.currentStats.starts + starts,
            inningsOuts: state.currentStats.inningsOuts + weekLine.outs,
            strikeouts: state.currentStats.strikeouts + strikeouts,
            walks: state.currentStats.walks + walks,
            runsAllowed: state.currentStats.runsAllowed + runs,
            hits: state.currentStats.hits + weekLine.hits,
            homeRuns: state.currentStats.homeRuns + weekLine.homeRuns,
            pitches: state.currentStats.pitches + weekLine.pitches,
            wins: state.currentStats.wins + newGameLines.count { $0.decision == .win },
            losses: state.currentStats.losses + newGameLines.count { $0.decision == .loss },
            saves: state.currentStats.saves + newGameLines.count { $0.decision == .save }
        )
        let earnedCallUp = trust >= 60 && skill >= 46
            && (state.season > 1 || stats.games >= 12 || stats.strikeouts >= 40)
        // **2군행이 있다.** 예전에는 한번 올라가면 내려오지 않았다 — 1군이 승급이 아니라
        // 통과 지점이었다는 뜻이고, 그러면 남은 시즌에 걸린 것이 없어진다.
        //
        // 되돌릴 수 있는 세트백이다. 다시 던져서 믿음을 쌓으면 올라온다.
        let demoted = state.level == .major && trust < Self.demotionTrust && !recovering
        let level: ProLevel = demoted ? .minor : (state.level == .major || earnedCallUp ? .major : .minor)
        let trustAssignedRole: ProRole = level == .major
            ? trust >= 74 ? .starter : trust >= 62 ? .longRelief : .setup
            : trust >= 52 ? .starter : .longRelief
        // 역할 면담은 '남은 시즌'에 대한 약속이다. 다음 주 신뢰도 밴드가 곧바로 덮어쓰면
        // 선택이 가짜가 되므로, 오프시즌 전까지는 명시한 보직을 우선한다.
        let role = state.rolePreference ?? trustAssignedRole
        let development = try resolveDevelopment(
            pitcher: state.pitcher,
            progress: state.developmentProgress ?? .init(),
            project: state.pitchLearningProject,
            plan: params.plan,
            targetPitch: params.targetPitch,
            paused: recovering || state.journeyState?.recoveryYearPending == true,
            proRulesVersion: state.proRulesVersion,
            trainingEfficiencyPermille: activeModifiers.compactMap(\.trainingEfficiencyPermille).min() ?? 1_000
        )
        let pitcher = development.pitcher
        let callUpGame = state.level != level && level == .major
        let priorImportantGames = state.seasonImportantGames ?? 0
        // 직접 승부는 그 주의 예정 등판 하나를 대표한다. 회복·부상으로 실제 등판이
        // 하나도 없는 주에 승부처를 열면 resolve 단계에서 별도 보너스 경기가 생긴다.
        let regularTrigger: ProSeasonTrigger? = nextWeek >= 24 || newGameLines.isEmpty || newInjury > 0 ? nil
            : importantGameTrigger(state: state, nextWeek: nextWeek, newLevel: level, newTrust: trust, seasonStats: stats, skill: skill, priorImportantGames: priorImportantGames)
        let postseasonEvaluationState = replacing(
            state,
            week: nextWeek,
            currentStats: stats,
            gameLines: (state.gameLines ?? []) + newGameLines
        )
        let endOfSeasonPostseason: ProPostseasonState? = {
            guard nextWeek >= 24, Self.usesAutumnRules(state) else { return nil }
            let evaluated = ProPostseasonRules.playerPath(
                from: ProPostseasonRules.evaluateEndOfSeason(postseasonEvaluationState),
                level: level,
                injuryWeeks: newInjury
            )
            return Self.usesFinalSeriesRules(state)
                ? ProPostseasonRules.preparingSeries(evaluated, state: postseasonEvaluationState)
                : evaluated
        }()
        let autumnTrigger: ProSeasonTrigger? = {
            guard let postseason = endOfSeasonPostseason,
                  postseason.result == .inProgress,
                  let round = postseason.currentRound else { return nil }
            return ProPostseasonRules.trigger(for: round)
        }()
        let trigger = autumnTrigger ?? regularTrigger
        let decisionsThisSeason = (state.decisionHistory ?? []).count { $0.season == state.season }
        // 중요 경기와 부상은 화면상 더 급한 사건이다. 해당 주의 갈림길은 뒤로 미루거나
        // 중복 노출하지 않고 건너뛴다. 시즌의 세 막에서 한 번씩만 멈춰, 선택이 체크리스트가
        // 아니라 그 시즌을 기억하게 하는 갈림길로 남게 한다.
        // 조건부 보직 지원의 6주차 재검토만 다음 결정 주로 이월한다.
        let scheduledDecisionWeeks = Self.decisionWeeks(for: state)
        let canOpenDecisionSlot = nextWeek < 24
            && (usesAgencyRules || (state.balanceVersion ?? 1) >= 4)
            && scheduledDecisionWeeks.contains(nextWeek)
            && decisionsThisSeason < Self.maximumDecisions(for: state)
        let blockedByCrisis = trigger != nil || recovering || newInjury > 0
        let reviewDue = ProRoleRequestRules.pendingConditionalReview(state, week: nextWeek)
        let decisionSource = Self.usesWeeklyDecisionRules(state)
            ? replacing(
                state,
                pitcher: pitcher,
                role: role,
                managerTrust: trust,
                fatigue: fatigue,
                currentStats: stats,
                gameLines: (state.gameLines ?? []) + newGameLines
            )
            : state
        let pendingDecision: ProSeasonDecision? = {
            if reviewDue, canOpenDecisionSlot {
                return blockedByCrisis
                    ? nil
                    : makeDecision(type: .roleMeeting, state: decisionSource, week: nextWeek)
            }
            let shouldOpenDecision = canOpenDecisionSlot && !blockedByCrisis
            return shouldOpenDecision
                ? seasonDecision(for: decisionSource, week: nextWeek, climate: weekClimate, trust: trust, level: level)
                : nil
        }()
        let phase: ProCareerPhase = {
            if nextWeek >= 24 {
                return autumnTrigger != nil ? .importantGame : .seasonReview
            }
            if trigger != nil { return .importantGame }
            if pendingDecision != nil { return .seasonDecision }
            return .weeklyPlan
        }()
        let rival: ProRivalBatter? = trigger.map { trigger in
            if let opponentID = endOfSeasonPostseason?.series?.opponentTeamID {
                return rivalForGame(state, week: nextWeek, trigger: trigger, opponentTeamID: opponentID)
            }
            return rivalForGame(state, week: nextWeek, trigger: trigger)
        }
        let importantGames = priorImportantGames + (phase == .importantGame && autumnTrigger == nil ? 1 : 0)
        let seasonTensionsValue = state.seasonTensions ?? seasonTensions(for: state)
        let priorSegment = state.seasonSegment ?? segment(forWeek: state.week)
        let nextSegment = segment(forWeek: nextWeek)
        var news = state.news
        var milestones = state.milestones
        if state.week == 0 {
            milestones = addingUnique("프로 첫 공식 등판", to: milestones)
            news.insert("프로 첫 공식 등판을 마쳤습니다. \(games)경기에서 \(strikeouts)개의 삼진을 잡았습니다.", at: 0)
        } else {
            news.insert("\(nextWeek)주차 · \(games)경기 · \(strikeouts)K · \(walks)볼넷 · \(runs)실점", at: 0)
        }
        if state.level != level {
            if level == .major {
                milestones = addingUnique("1군 콜업", to: milestones)
                news.insert("2군 기록과 감독의 믿음을 쌓아 1군 출전 명단에 합류했습니다.", at: 0)
            } else {
                news.insert("최근 등판이 이어지지 않아 2군으로 내려갑니다. 기록을 다시 쌓아야 합니다.", at: 0)
            }
        }
        if state.role != role {
            let roleName = role == .starter ? "선발" : role == .longRelief ? "긴 이닝 구원" : role == .setup ? "필승조" : "마무리"
            milestones = addingUnique("\(state.season)시즌 \(roleName) 역할", to: milestones)
            news.insert("감독 면담 뒤 다음 등판부터 \(roleName) 역할을 맡습니다.", at: 0)
        }
        let priorGames = careerGames(state)
        let nextGames = priorGames + games
        let priorStrikeouts = careerStrikeouts(state)
        let nextStrikeouts = priorStrikeouts + strikeouts
        for mark in ProCareerMilestoneRules.gameMarks where priorGames < mark && nextGames >= mark {
            milestones = addingUnique(ProCareerMilestoneRules.gamesLine(mark), to: milestones)
        }
        for mark in ProCareerMilestoneRules.strikeoutMarks where priorStrikeouts < mark && nextStrikeouts >= mark {
            milestones = addingUnique(ProCareerMilestoneRules.strikeoutsLine(mark), to: milestones)
        }
        let injuryEvent: ProInjuryEventSnapshot? = newInjury > 0 && state.injuryWeeks == 0
            ? ProInjuryEventSnapshot(
                cause: .overload,
                season: state.season,
                week: nextWeek,
                plan: params.plan,
                rawFatigue: fatigue,
                effectiveFatigue: fatiguePressure,
                pitches: weekLine.pitches,
                recoveryWeeks: newInjury,
                careerID: state.proCareerID,
                revision: state.revision + 1
            )
            : nil
        if injuryEvent != nil {
            news.insert("과부하로 \(newInjury)주 부상자 명단에 올랐습니다.", at: 0)
        }
        if !development.growthLabels.isEmpty {
            news.insert("주간 성장 완성 · \(development.growthLabels.joined(separator: " · "))", at: 0)
        }
        if let receipt = development.pitchLearningReceipt {
            let line = receipt.justCompleted
                ? "새 구종 완성 · 이제 보조 구종으로 승부합니다."
                : receipt.justUnlockedForGames
                    ? "구종 연구 진전 · 다음 공식 경기에서 개발 구종을 시험할 수 있습니다."
                    : "구종 연구 진전 · 반복 감각 +\(receipt.practiceCreditsAfter - receipt.practiceCreditsBefore)"
            news.insert(line, at: 0)
        }
        if nextSegment != priorSegment { news.insert(segmentEntryNews(nextSegment), at: 0) }
        if Self.usesCareerArcRules(state), let weekClimate, weekClimate != .even {
            news.insert(ProSeasonClimateRules.newsLine(for: weekClimate, week: nextWeek), at: 0)
        }
        if let endOfSeasonPostseason {
            switch endOfSeasonPostseason.result {
            case .didNotQualify:
                news.insert("정규시즌이 끝났습니다. 올해는 플레이오프에 들지 못했습니다.", at: 0)
            case .inProgress:
                news.insert(ProPostseasonRules.qualificationNews(for: endOfSeasonPostseason.seed), at: 0)
            case .unavailable:
                news.insert(ProPostseasonRules.unavailableNews(level: level), at: 0)
            default:
                break
            }
        }
        if phase == .importantGame, let trigger {
            news.insert(importantMomentHeadline(
                trigger: trigger,
                rival: rival,
                level: level,
                trust: trust,
                build: PitcherBuildRules.identity(for: pitcher)
            ), at: 0)
        }
        var nextJourney = state.journeyState
        if injuryMitigationConsumed, let journey = nextJourney {
            nextJourney = replacingJourney(journey, activeSeasonBenefit: .some(nil))
        } else if Self.usesCareerArcRules(state),
                  let journey = nextJourney,
                  journey.activeSeasonBenefit?.kind == .climateStabilization,
                  let charges = journey.activeSeasonBenefit?.remainingCharges,
                  charges > 0 {
            let remaining = charges - 1
            nextJourney = replacingJourney(
                journey,
                activeSeasonBenefit: remaining > 0
                    ? .some(ProSeasonBenefit(kind: .climateStabilization, focus: nil, remainingCharges: remaining))
                    : .some(nil)
            )
        }
        let journeyOverride: ProCareerJourneyState?? = nextJourney == state.journeyState ? nil : nextJourney.map { .some($0) }
        let postseasonOverride: ProPostseasonState?? = endOfSeasonPostseason.map { .some($0) }
        let weekQualityStarts = newGameLines.filter { line in
            line.started && line.outs >= 18 && line.runsAllowed <= 3
        }.count
        var trackedModifiers = activeModifiers.map { modifier in
            modifier.tracking(
                qualityStarts: modifier.qualityStarts + weekQualityStarts,
                runsAllowed: modifier.runsAllowed + weekLine.runsAllowed
            )
        }
        var resolvedFollowUps = state.resolvedFollowUps ?? []
        var followUpEvents: [String] = []
        var nextPitcher = pitcher
        var nextTrust = trust
        for modifier in trackedModifiers where nextWeek >= modifier.expiresWeek {
            let resolved = resolveWeeklyFollowUp(
                modifier: modifier,
                pitcher: nextPitcher,
                managerTrust: nextTrust,
                season: state.season,
                week: nextWeek
            )
            nextPitcher = resolved.pitcher
            nextTrust = resolved.managerTrust
            resolvedFollowUps.append(resolved.followUp)
            news.insert(resolved.newsLine, at: 0)
            followUpEvents.append("pro_weekly_decision_followup_resolved")
        }
        trackedModifiers.removeAll { $0.expiresWeek <= nextWeek }
        let modifiersOverride: [ProDecisionModifier]?? = trackedModifiers.isEmpty ? .some(nil) : .some(trackedModifiers)
        let followUpsOverride: [ProDecisionFollowUp]?? = resolvedFollowUps.isEmpty ? .some(nil) : .some(resolvedFollowUps)
        let updated = replacing(state, revision: state.revision + 1, phase: phase, pitcher: nextPitcher, week: nextWeek, level: level, role: role, managerTrust: nextTrust, fatigue: fatigue, injuryWeeks: newInjury, currentStats: stats, gameLines: (state.gameLines ?? []) + newGameLines, milestones: milestones, news: Array(news.prefix(30)), seasonSegment: nextSegment, seasonTrigger: trigger, currentRival: rival, seasonTensions: seasonTensionsValue, seasonImportantGames: importantGames, pendingDecision: pendingDecision, developmentProgress: development.progress, pitchLearningProject: development.pitchLearningProject, journeyState: journeyOverride, postseason: postseasonOverride, activeDecisionModifiers: modifiersOverride, resolvedFollowUps: followUpsOverride)
        var events = ["pro_week_resolved", callUpGame ? "major_call_up" : "weekly_progress"]
        if injuryEvent != nil { events.append("pro_injury_started") }
        if phase == .seasonDecision { events.append("pro_season_decision_opened") }
        events.append(contentsOf: followUpEvents)
        return result(
            updated,
            nextSeed: String(rng.next()),
            events: events,
            injuryEvent: injuryEvent
        )
    }

    /// Spring-camp role request. Deterministic; the weekly RNG stream is not consumed.
    public func requestRole(_ params: RequestProRoleParams) throws -> ProCareerResult {
        _ = try generator(params.seed)
        try validate(params.state, phase: .weeklyPlan)
        guard ProRoleRequestRules.shouldOffer(params.state) else {
            throw SimulationError.invalidProCareer("보직 지원을 할 수 없는 시점입니다.")
        }
        let requested = params.requested == .setup ? .longRelief : params.requested
        guard ProRoleRequestRules.requestableRoles.contains(requested) else {
            throw SimulationError.invalidProCareer("지원할 수 없는 보직입니다.")
        }
        let evaluation = ProRoleRequestRules.evaluate(state: params.state, requested: requested)
        let request = ProRoleRequestState(
            requested: evaluation.requested,
            outcome: evaluation.outcome,
            reviewWeek: evaluation.reviewWeek,
            season: params.state.season
        )
        let nextPreference: ProRole?
        let nextTrust: Int
        var news = params.state.news
        switch evaluation.outcome {
        case .accepted, .conditional:
            nextPreference = evaluation.requested
            nextTrust = params.state.managerTrust
        case .rejected:
            nextPreference = params.state.rolePreference
            nextTrust = clamp(params.state.managerTrust - 1, 0, 100)
            if let key = evaluation.rejectionNewsKey {
                news.insert(key, at: 0)
            }
        }
        let next = replacing(
            params.state,
            revision: params.state.revision + 1,
            rolePreference: .some(nextPreference),
            managerTrust: nextTrust,
            news: news,
            roleRequest: .some(request)
        )
        return result(next, nextSeed: params.seed, events: ["pro_role_requested"])
    }

    /// 확인한 시즌 선택을 한 번만 적용한다.
    ///
    /// 결정 ID까지 다시 받는 이유는 확인 시트가 떠 있는 동안 상태가 바뀌었을 때 예전 선택을
    /// 새 pending 결정에 잘못 적용하지 않기 위해서다. 이 동작에는 무작위가 없으므로 시드도
    /// 소비하지 않는다. 저장 후 재개해 같은 입력을 보내면 같은 결과가 나온다.
    public func applySeasonDecision(_ params: ApplyProSeasonDecisionParams) throws -> ProCareerResult {
        try validate(params.state, phase: .seasonDecision)
        _ = try generator(params.seed)
        let state = params.state
        guard let pending = state.pendingDecision else {
            throw SimulationError.invalidProCareer("적용할 시즌 결정이 없습니다.")
        }
        guard pending.id == params.decisionID else {
            throw SimulationError.invalidProCareer("확인한 시즌 결정이 현재 결정과 다릅니다.")
        }
        guard !(state.decisionHistory ?? []).contains(where: { $0.decisionID == pending.id }) else {
            throw SimulationError.invalidProCareer("이미 적용한 시즌 결정입니다.")
        }
        // 이미 열린 결정은 플레이어가 실제로 본 약속이다. 예전 빌드에서 시즌 네 번째 이후에
        // 저장한 pending 결정도 그대로 적용할 수 있어야 하므로, 여기만 옛 상한을 허용한다.
        // 새 결정 생성은 `maximumSeasonDecisions`(3회)에서 이미 막힌다.
        guard (state.decisionHistory ?? []).count(where: { $0.season == state.season }) < Self.persistedSeasonDecisionLimit else {
            throw SimulationError.invalidProCareer("한 시즌에는 일곱 번까지만 결정할 수 있습니다.")
        }
        guard let choice = pending.choices.first(where: { $0.id == params.choiceID }) else {
            throw SimulationError.invalidProCareer("현재 결정에 없는 선택지입니다.")
        }

        let journeyEffect = choice.journeyEffect
        var nextJourney: ProCareerJourneyState?
        if pending.type == .mediaOpportunity {
            guard let journey = state.journeyState,
                  pending.week == Self.mediaOpportunityWeek(proCareerID: state.proCareerID, season: state.season, proRulesVersion: state.proRulesVersion),
                  (journey.reputation.fanSupport >= 35),
                  !(state.decisionHistory ?? []).contains(where: {
                      $0.season == state.season && $0.type == .mediaOpportunity
                  }),
                  journeyEffect != nil else {
                throw SimulationError.invalidProCareer("media opportunity is not eligible")
            }
            guard journeyEffectMatchesMediaChoice(choice) else {
                throw SimulationError.invalidProCareer("invalid media opportunity effect")
            }
            let endorsementID = "endorsement:\(state.proCareerID):\(state.season):\(pending.id)"
            guard !journey.finances.transactions.contains(where: { $0.id == endorsementID }),
                  !journey.reputation.endorsementSeasons.contains(state.season) else {
                throw SimulationError.invalidProCareer("endorsement_already_selected")
            }
            let income = journeyEffect?.income ?? 0
            guard income >= 0,
                  journey.finances.careerEarnings <= Int64.max - income,
                  journey.finances.availableFunds <= Int64.max - income else {
                throw SimulationError.invalidProCareer("finance overflow")
            }
            let endorsement = ProFinanceTransaction(
                id: endorsementID,
                season: state.season,
                kind: .endorsement,
                amount: income
            )
            var teamRecords = ProTeamCareerRecordRules.backfill(
                careerStats: state.careerStats,
                recognitions: journey.recognitions,
                existing: journey.teamRecords
            )
            if let communityDelta = journeyEffect?.communityDelta,
               communityDelta != 0 {
                guard let existing = teamRecords.first(where: { $0.teamID == state.team.id }),
                      communityDelta > 0,
                      existing.communityPoints <= Int.max - communityDelta else {
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
                    communityPoints: existing.communityPoints + communityDelta,
                    lastSeason: existing.lastSeason
                )
                teamRecords = teamRecords.map { $0.teamID == updatedRecord.teamID ? updatedRecord : $0 }
            }
            let endorsementSeasons = Array(Set(journey.reputation.endorsementSeasons + [state.season])).sorted()
            let reputation = ProReputationState(
                fanSupport: clamp(journey.reputation.fanSupport + (journeyEffect?.fanDelta ?? 0), 0, 100),
                lastMerchandiseTier: journey.reputation.lastMerchandiseTier,
                endorsementSeasons: endorsementSeasons
            )
            let finance = ProFinanceState(
                careerEarnings: journey.finances.careerEarnings + income,
                availableFunds: journey.finances.availableFunds + income,
                salaryCreditedThroughSeason: journey.finances.salaryCreditedThroughSeason,
                transactions: boundedFinanceTransactions(journey.finances.transactions + [endorsement]),
                investmentSeason: journey.finances.investmentSeason
            )
            nextJourney = replacingJourney(
                journey,
                teamRecords: teamRecords,
                reputation: reputation,
                finances: finance
            )
        } else {
            guard journeyEffect == nil else {
                throw SimulationError.invalidProCareer("unexpected journey effect")
            }
        }

        let effect = choice.effect
        let pitcher = applying(effect, to: state.pitcher)
        let managerTrust = clamp(state.managerTrust + effect.managerTrustDelta, 0, 100)
        let catcherTrust = clamp(state.catcherTrust + effect.catcherTrustDelta, 0, 100)
        let fatigue = clamp(state.fatigue + effect.fatigueDelta, 0, 100)
        let role = effect.roleTarget ?? state.role
        let rolePreference = (pending.type == .roleMeeting || pending.type == .formCrisis || pending.type == .agingCrossroads)
            ? (effect.roleTarget ?? state.rolePreference)
            : state.rolePreference
        if pending.type == .formCrisis, choice.id.hasSuffix(".recover"), let journey = nextJourney ?? state.journeyState {
            nextJourney = replacingJourney(
                journey,
                activeSeasonBenefit: .some(ProSeasonBenefit(kind: .climateStabilization, focus: nil, remainingCharges: 2))
            )
        }
        if pending.type == .agingCrossroads, choice.id.hasSuffix(".recovery_year"), let journey = nextJourney ?? state.journeyState {
            nextJourney = replacingJourney(journey, recoveryYearPending: .some(true))
        }
        var appliedPitcher = pitcher
        if pending.type == .newPitchTrial,
           let targetPitch = lowMasteryPitch(in: state.pitcher) {
            let points = choice.id.hasSuffix(".live_trial") ? 2 : 1
            appliedPitcher = growPitchProfile(appliedPitcher, pitch: targetPitch, points: points)
        }
        let followUpWeek = pending.type.isWeeklyBinaryDecision
            && weeklyChoiceSchedulesFollowUp(choice.id)
            ? pending.week + 3
            : nil
        let record = ProDecisionRecord(
            decisionID: pending.id,
            type: pending.type,
            season: pending.season,
            week: pending.week,
            choiceID: choice.id,
            choiceTitle: choice.title,
            effect: effect,
            journeyEffect: journeyEffect,
            followUpResolvedWeek: followUpWeek
        )
        var nextModifiers = state.activeDecisionModifiers ?? []
        if let followUpWeek,
           let modifier = weeklyModifier(
            for: pending,
            choice: choice,
            pitcher: appliedPitcher,
            expiresWeek: min(24, followUpWeek)
           ) {
            nextModifiers.append(modifier)
        }
        let mediaChoiceToken = choice.id.split(separator: ".").last.map(String.init) ?? "choice"
        let summary: String
        if pending.type == .mediaOpportunity {
            summary = "content.pro-media-opportunity.resolved.\(mediaChoiceToken)"
        } else if pending.type.isWeeklyBinaryDecision {
            summary = "시즌 결정 · \(pending.week)주차"
        } else {
            summary = "\(pending.title) · \(choice.title) — \(effect.summary)"
        }
        let clearedDecision: ProSeasonDecision? = nil
        let modifiersOverride: [ProDecisionModifier]?? = nextModifiers.isEmpty ? nil : .some(nextModifiers)
        let updated = replacing(
            state,
            revision: state.revision + 1,
            phase: .weeklyPlan,
            pitcher: appliedPitcher,
            role: role,
            rolePreference: rolePreference,
            managerTrust: managerTrust,
            catcherTrust: catcherTrust,
            fatigue: fatigue,
            news: Array(([summary] + state.news).prefix(30)),
            pendingDecision: clearedDecision,
            decisionHistory: (state.decisionHistory ?? []) + [record],
            journeyState: nextJourney.map { .some($0) },
            activeDecisionModifiers: modifiersOverride
        )
        let events = pending.type == .mediaOpportunity
            ? ["pro_season_decision_resolved", "pro_endorsement_selected"]
            : ["pro_season_decision_resolved"]
        return result(updated, nextSeed: params.seed, events: events)
    }

    /// 시즌 결정 국면인데 pending 결정이 없는 손상 저장을 다음 국면으로 되돌린다.
    ///
    /// 이 조합은 `validateState`가 모든 엔진 호출을 거부하는 상태다 — 복구 경로가 없으면
    /// 화면에는 "시즌 결정을 불러올 수 없습니다"만 남고, 어떤 조작도
    /// "커리어를 열 수 없습니다"로 끝난다(1.0.x 리뷰의 '진행 불가'가 이 모양이었다).
    /// 잃어버린 결정을 재구성하지 않고 그 주를 결정 없이 지나간 것으로 정리한다.
    /// 무작위를 쓰지 않으므로 재시도해도 같은 결과가 나온다.
    public func recoverMissingSeasonDecision(_ params: ProStateParams) throws -> ProCareerResult {
        _ = try generator(params.seed)
        let state = params.state
        guard state.phase == .seasonDecision, state.pendingDecision == nil else {
            throw SimulationError.invalidProCareer("복구할 손상된 시즌 결정 상태가 아닙니다.")
        }
        // 24주를 다 쓴 저장이면 주간 계획으로 보내지 않는다 — planWeek가 즉시 시즌
        // 리뷰로 넘기지 못하는 마지막 주 손상도 여기서 함께 풀린다.
        let updated = replacing(
            state,
            revision: state.revision + 1,
            phase: state.week >= 24 ? .seasonReview : .weeklyPlan,
            commitment: state.commitment
        )
        return result(updated, nextSeed: params.seed, events: ["pro_season_decision_recovered"])
    }

    public func resolveImportantGame(_ params: ResolveProGameParams) throws -> ProCareerResult {
        try validate(params.state, phase: .importantGame)
        if ProPostseasonRules.isAutumn(params.state.seasonTrigger) {
            return try resolveAutumnGame(params)
        }
        var rng = try generator(params.seed)
        let report = params.report
        let soundProcess = report.actualDamage <= report.expectedDamage + 150 || report.recommendationAccepted * 2 >= report.pitches
        let usesAgencyRules = Self.usesAgencyRules(params.state)
        // 수싸움 적중은 이미 끝난 투구 결과 위에 붙는 관계 보상이다. 확률이나 RNG에는 손대지
        // 않으며 nil/0이면 이전 산식과 바이트 단위로 같은 결과를 만든다.
        let sequenceTrustReward = (params.state.balanceVersion ?? 1) >= 4
            ? PitchSequenceMasteryRules.trustReward(for: report.sequenceMasteryCount)
            : 0
        // 중요 경기 사이에 선택이 둘 이상 생길 수 있다. 가장 최근 선택 하나만 회수하면
        // 먼저 한 선택은 영원히 반응을 받지 못하므로, 직전 중요 경기 뒤에 쌓인 선택을
        // 이번 직접 승부에서 모두 회수한다.
        let decisionHistory = params.state.decisionHistory ?? []
        let unresolvedIndices = decisionHistory.indices.filter {
            usesAgencyRules
                && decisionHistory[$0].season == params.state.season
                && decisionHistory[$0].followUpResolvedWeek == nil
        }
        let followUpRecords = unresolvedIndices.map { decisionHistory[$0] }
        let followUpReward = followUpRecords.count * (soundProcess ? 2 : -1)
        let trust = clamp(params.state.managerTrust + report.strikeouts * 2 - report.walks * 2 - report.runsAllowed * 3 + (soundProcess ? 2 : 0) + sequenceTrustReward + followUpReward, 0, 100)
        // 실제로 잡은 아웃을 쓴다. 없으면 예전처럼 어림하되, 그건 옛 저장본 호환용 경로다.
        let directOuts = report.outs ?? max(3, report.pitches / 5)
        var gameLines = params.state.gameLines ?? []
        // v4에서 새로 열린 중요 경기는 이미 같은 주의 자동 등판을 하나 갖는다. 그 행을
        // 직접 승부가 포함된 한 경기로 바꿔야 경기 수가 늘지 않는다. 이 행이 없는 예전
        // pending 저장은 아래 legacy append 경로를 타서 계속 복구할 수 있다.
        let scheduledIndex = usesAgencyRules
            ? gameLines.lastIndex { $0.week == params.state.week && !$0.played }
            : nil
        let scheduledLine = scheduledIndex.map { gameLines[$0] }
        let started = scheduledLine?.started ?? (params.state.role == .starter)
        let scheduledOuts = scheduledLine?.outs ?? 0
        let complementOuts = max(0, scheduledOuts - directOuts)

        func retained(_ value: Int) -> Int {
            guard scheduledOuts > 0 else { return 0 }
            // 반올림 나눗셈. 내림을 쓰면 중요 경기를 치를 때마다 시즌 안타·삼진·볼넷이
            // 조금씩 깎여 나갔다(실측: 18→16, 133→132처럼 resolve마다 손실).
            return (value * complementOuts + scheduledOuts / 2) / scheduledOuts
        }

        // 자동 등판의 같은 비율만 남기고 사용자가 직접 만든 승부처 성적을 합친다.
        // 선발은 나머지 이닝이 보존되고, 한 이닝 구원은 거의 전부 직접 결과가 된다.
        let outs = scheduledLine == nil ? directOuts : complementOuts + directOuts
        let strikeouts = retained(scheduledLine?.strikeouts ?? 0) + report.strikeouts
        let walks = retained(scheduledLine?.walks ?? 0) + report.walks
        let runsAllowed = retained(scheduledLine?.runsAllowed ?? 0) + report.runsAllowed
        let pitches = retained(scheduledLine?.pitches ?? 0) + report.pitches
        let hits = retained(scheduledLine?.hits ?? 0) + (report.hits ?? 0)
        let homeRuns = retained(scheduledLine?.homeRuns ?? 0) + (report.homeRuns ?? 0)
        // 최종 스코어를 등판 시점의 점수 차에서 파생시킨다. 그래야 "1점 리드로 올라가
        // 무실점으로 막았는데 패배" 같은 모순이 생기지 않는다. 지는 경기는 반드시
        // 내 실점이나 불펜 실점으로 설명된다.
        let support: Int
        let opponentRuns: Int
        if let entryDifferential = report.scoreDifferentialAtEntry {
            let opponentEarlier = rng.nextInt(upperBound: 4)
            let lateTeam = rng.nextInt(upperBound: 3)
            let lateBullpen = started ? rng.nextInt(upperBound: 3) : 0
            opponentRuns = opponentEarlier + runsAllowed + lateBullpen
            support = max(0, opponentEarlier + entryDifferential + lateTeam)
        } else {
            // 옛 저장본과 데스크톱 경로. 등판 시점 정보가 없으면 분포에서 뽑는다.
            support = report.teamRuns ?? LeagueBaseline.teamRuns(using: &rng)
            let othersOuts = max(0, 27 - outs)
            opponentRuns = runsAllowed
                + LeagueBaseline.restOfTeamRuns(outsCovered: othersOuts, using: &rng)
        }
        let decision = DecisionRules.decide(
            started: started,
            isCloser: params.state.role == .closer,
            outs: outs,
            runsAllowed: runsAllowed,
            teamRuns: support,
            opponentRuns: opponentRuns
        )
        let replacedGame = scheduledLine != nil
        let oldDecision = scheduledLine?.decision
        let stats = ProSeasonStats(
            season: params.state.season, teamID: params.state.team.id,
            games: params.state.currentStats.games + (replacedGame ? 0 : 1),
            starts: params.state.currentStats.starts + (replacedGame ? 0 : (started ? 1 : 0)),
            inningsOuts: params.state.currentStats.inningsOuts - (scheduledLine?.outs ?? 0) + outs,
            strikeouts: params.state.currentStats.strikeouts - (scheduledLine?.strikeouts ?? 0) + strikeouts,
            walks: params.state.currentStats.walks - (scheduledLine?.walks ?? 0) + walks,
            runsAllowed: params.state.currentStats.runsAllowed - (scheduledLine?.runsAllowed ?? 0) + runsAllowed,
            hits: params.state.currentStats.hits - (scheduledLine?.hits ?? 0) + hits,
            homeRuns: params.state.currentStats.homeRuns - (scheduledLine?.homeRuns ?? 0) + homeRuns,
            pitches: params.state.currentStats.pitches - (scheduledLine?.pitches ?? 0) + pitches,
            wins: params.state.currentStats.wins - (oldDecision == .win ? 1 : 0) + (decision == .win ? 1 : 0),
            losses: params.state.currentStats.losses - (oldDecision == .loss ? 1 : 0) + (decision == .loss ? 1 : 0),
            saves: params.state.currentStats.saves - (oldDecision == .save ? 1 : 0) + (decision == .save ? 1 : 0)
        )
        // 직접 던진 경기는 기록에 그렇게 표시된다. 자동으로 지나간 경기와 섞이면
        // "내가 만든 성적"이라는 감각이 사라진다.
        let playedLine = ProGameLine(
            season: params.state.season,
            week: params.state.week,
            outingNumber: scheduledLine?.outingNumber ?? (gameLines.count + 1),
            started: started,
            outs: outs,
            strikeouts: strikeouts,
            walks: walks,
            runsAllowed: runsAllowed,
            pitches: pitches,
            teamRuns: support,
            opponentRuns: opponentRuns,
            decision: decision,
            played: true,
            hits: hits,
            homeRuns: homeRuns
        )
        if let scheduledIndex {
            gameLines[scheduledIndex] = playedLine
        } else {
            gameLines.append(playedLine)
        }
        let trustDelta = trust - params.state.managerTrust
        let evaluation = soundProcess ? "고른 구종과 코스도 좋았다는 평가를 받았습니다." : "경기 결과와 별개로 구종 순서를 다시 맞춥니다."
        let masteryEvaluation = sequenceTrustReward > 0 ? " 수싸움 적중으로 감독과 포수의 믿음 +\(sequenceTrustReward)." : ""
        let followUpEvaluation: String
        if followUpRecords.isEmpty {
            followUpEvaluation = ""
        } else {
            let choices = followUpRecords.map { "‘\($0.choiceTitle)’" }.joined(separator: ", ")
            followUpEvaluation = " 지난 선택 \(choices)이 이번 준비로 이어져 감독의 믿음 \(followUpReward >= 0 ? "+" : "")\(followUpReward)."
        }
        var nextPitcher = params.state.pitcher
        var nextLearningProject = params.state.pitchLearningProject
        var learningLine: String?
        var learningEvent: String?
        if let receipts = report.pitchLearningUses {
            guard receipts.allSatisfy({
                $0.pitchesThrown >= 0 && (0...2).contains($0.qualityUses)
                    && $0.qualityUses <= $0.pitchesThrown
            }) else {
                throw SimulationError.invalidProCareer("pitch learning game receipt is invalid")
            }
            if let project = nextLearningProject,
               !project.isCompleted,
               let use = receipts.first(where: { $0.pitchType == project.pitchType }),
               use.qualityUses > 0 {
                let learning = try PitchLearningRules.advancing(
                    pitcher: nextPitcher,
                    project: project,
                    qualityUses: use.qualityUses
                )
                nextPitcher = learning.pitcher
                nextLearningProject = learning.project
                learningLine = learning.receipt.justCompleted
                    ? "새 구종을 보조 구종으로 완성했습니다."
                    : "개발 구종 실전 감각 +\(use.qualityUses)."
                learningEvent = learning.receipt.justCompleted
                    ? "pitch_learning_completed"
                    : "pitch_learning_quality_use"
            }
        }
        let foe = params.state.currentRival.map { "\($0.name)(\($0.teamName)) 상대 · " } ?? ""
        let news = (["승부처 등판 · \(foe)\(report.strikeouts)탈삼진 · \(report.walks)볼넷 · \(report.runsAllowed)실점 · 감독의 믿음 \(trustDelta >= 0 ? "+" : "")\(trustDelta). \(evaluation)\(masteryEvaluation)\(followUpEvaluation)"]
            + (learningLine.map { [$0] } ?? [])) + params.state.news
        var milestones = params.state.milestones
        if params.state.level == .major { milestones = addingUnique("1군 첫 중요 승부", to: milestones) }
        let clearedRival: ProRivalBatter? = nil
        let clearedTrigger: ProSeasonTrigger? = nil
        var resolvedHistory = decisionHistory
        for index in unresolvedIndices {
            let record = resolvedHistory[index]
            resolvedHistory[index] = ProDecisionRecord(
                decisionID: record.decisionID,
                type: record.type,
                season: record.season,
                week: record.week,
                choiceID: record.choiceID,
                choiceTitle: record.choiceTitle,
                effect: record.effect,
                journeyEffect: record.journeyEffect,
                followUpResolvedWeek: params.state.week
            )
        }
        let updated = replacing(params.state, revision: params.state.revision + 1, phase: .weeklyPlan, pitcher: nextPitcher, managerTrust: trust, catcherTrust: clamp(params.state.catcherTrust + (soundProcess ? 2 : -1) + sequenceTrustReward, 0, 100), currentStats: stats, gameLines: gameLines, milestones: milestones, news: Array(news.prefix(30)), seasonTrigger: clearedTrigger, currentRival: clearedRival, decisionHistory: resolvedHistory, pitchLearningProject: nextLearningProject)
        return result(updated, nextSeed: String(rng.next()), events: ["pro_important_game_resolved"] + (learningEvent.map { [$0] } ?? []))
    }

    /// 가을 장면은 정규시즌 24주 밖에 있으므로 통산 이닝에 합치지 않는다.
    /// 감독의 믿음과 시즌 선택 회수는 직접 승부와 같은 공식을 쓴다. 이닝만 빼면
    /// 가을이 기록 밖의 무위험 연출이 된다.
    private func resolveAutumnGame(_ params: ResolveProGameParams) throws -> ProCareerResult {
        var rng = try generator(params.seed)
        let report = params.report
        let rawPostseason = params.state.postseason ?? ProPostseasonRules.evaluateEndOfSeason(params.state)
        let usesSeriesRules = Self.usesFinalSeriesRules(params.state)
        let current = usesSeriesRules
            ? ProPostseasonRules.preparingSeries(rawPostseason, state: params.state)
            : rawPostseason
        let support = report.teamRuns ?? max(0, (report.scoreDifferentialAtEntry ?? 0) + report.runsAllowed + 1)
        let opponent = report.runsAllowed + max(0, -(report.scoreDifferentialAtEntry ?? 0))
        let legacyWon = support > opponent || (support == opponent && report.runsAllowed <= 1)
        let strengthEdge = ProPostseasonRules.teamStrengthEdgePermille(params.state)
        let resolvedGame = usesSeriesRules
            ? resolvePostseasonGame(
                state: params.state,
                report: report,
                strengthEdgePermille: strengthEdge,
                using: &rng
            )
            : nil
        let won = resolvedGame?.won ?? legacyWon
        var automaticSummaries: [String] = []
        var automaticGames = 0
        let nextPostseason: ProPostseasonState
        if usesSeriesRules {
            guard let game = resolvedGame else {
                throw SimulationError.invalidProCareer("postseason remainder game was not resolved")
            }
            let gameNumber = current.series?.nextGameNumber ?? 1
            let played = ProPostseasonRules.resolvingSeriesGame(
                current,
                won: game.won,
                directlyPlayed: true,
                pitches: report.pitches,
                outs: report.outs,
                runsAllowed: report.runsAllowed,
                teamRuns: game.teamRuns,
                opponentRuns: game.opponentRuns,
                rivalMemory: report.rivalMemory,
                strikeouts: report.strikeouts,
                walks: report.walks,
                hits: report.hits,
                started: params.state.role == .starter
            )
            let prepared = played.result == .inProgress
                ? ProPostseasonRules.preparingSeries(played, state: params.state)
                : played
            let simulated = simulatePostseasonTeamGames(
                from: prepared,
                careerState: params.state,
                role: params.state.role,
                strengthEdgePermille: strengthEdge,
                forceCurrentGame: false,
                using: &rng
            )
            nextPostseason = simulated.state
            let directSummary = current.currentRound == .final
                ? "우승 결정전 \(gameNumber)차전 잔여 경기 진행 · \(game.teamRuns)-\(game.opponentRuns) \(game.won ? "승" : "패")"
                : "가을 직접 등판 뒤 잔여 경기 진행 · \(game.teamRuns)-\(game.opponentRuns) \(game.won ? "승" : "패")"
            automaticSummaries = [directSummary] + simulated.summaries
            automaticGames = simulated.count
        } else {
            nextPostseason = ProPostseasonRules.resolving(current, won: won)
        }
        let nextRound = nextPostseason.currentRound
        let continues = nextPostseason.result == .inProgress && nextRound != nil
        let nextTrigger = nextRound.map { ProPostseasonRules.trigger(for: $0) }
        let rival = nextTrigger.map { trigger in
            rivalForGame(
                params.state,
                week: params.state.week,
                trigger: trigger,
                opponentTeamID: nextPostseason.series?.opponentTeamID
            )
        }
        let soundProcess = report.actualDamage <= report.expectedDamage + 150 || report.recommendationAccepted * 2 >= report.pitches
        let sequenceTrustReward = (params.state.balanceVersion ?? 1) >= 4
            ? PitchSequenceMasteryRules.trustReward(for: report.sequenceMasteryCount)
            : 0
        let usesAgencyRules = Self.usesAgencyRules(params.state)
        let decisionHistory = params.state.decisionHistory ?? []
        let unresolvedIndices = decisionHistory.indices.filter {
            usesAgencyRules
                && decisionHistory[$0].season == params.state.season
                && decisionHistory[$0].followUpResolvedWeek == nil
        }
        let followUpRecords = unresolvedIndices.map { decisionHistory[$0] }
        let followUpReward = followUpRecords.count * (soundProcess ? 2 : -1)
        let trust = clamp(
            params.state.managerTrust
                + report.strikeouts * 2
                - report.walks * 2
                - report.runsAllowed * 3
                + (soundProcess ? 2 : 0)
                + sequenceTrustReward
                + followUpReward,
            0,
            100
        )
        var resolvedHistory = decisionHistory
        for index in unresolvedIndices {
            let record = resolvedHistory[index]
            resolvedHistory[index] = ProDecisionRecord(
                decisionID: record.decisionID,
                type: record.type,
                season: record.season,
                week: record.week,
                choiceID: record.choiceID,
                choiceTitle: record.choiceTitle,
                effect: record.effect,
                journeyEffect: record.journeyEffect,
                followUpResolvedWeek: params.state.week
            )
        }
        let trustDelta = trust - params.state.managerTrust
        let followUpEvaluation: String
        if followUpRecords.isEmpty {
            followUpEvaluation = ""
        } else {
            let choices = followUpRecords.map { "‘\($0.choiceTitle)’" }.joined(separator: ", ")
            followUpEvaluation = " 지난 선택 \(choices)이 이번 준비로 이어져 감독의 믿음 \(followUpReward >= 0 ? "+" : "")\(followUpReward)."
        }
        let headline: String
        switch nextPostseason.result {
        case .champion:
            headline = "플레이오프 우승. 올해의 마지막 공이 남았습니다."
        case .runnerUp:
            headline = "결승에서 멈췄습니다. 가을은 여기까지입니다."
        case .eliminated:
            headline = ProPostseasonRules.eliminationNews(for: nextPostseason.currentRound)
        case .inProgress:
            if usesSeriesRules, let series = nextPostseason.series {
                let roundTitle: String = switch nextPostseason.currentRound {
                case .wildCard: "와일드카드"
                case .semifinal: "준플레이오프"
                case .playoff: "플레이오프"
                case .final: "우승 결정전"
                case nil: "가을 시리즈"
                }
                headline = "\(roundTitle) \(series.nextGameNumber)차전이 남았습니다. 시리즈 \(series.playerWins)-\(series.opponentWins)."
            } else {
                headline = nextTrigger == .autumnWildCard
                    ? "와일드카드 2차전이 남았습니다."
                    : (won ? "다음 라운드가 열립니다." : "가을이 이어집니다.")
            }
        case .didNotQualify, .unavailable:
            headline = "가을이 닫혔습니다."
        }
        let trustLine = "가을 승부 · \(report.strikeouts)탈삼진 · \(report.walks)볼넷 · \(report.runsAllowed)실점 · 감독의 믿음 \(trustDelta >= 0 ? "+" : "")\(trustDelta).\(followUpEvaluation)"
        let phase: ProCareerPhase = continues ? .importantGame : .seasonReview
        let appearanceLoad = usesSeriesRules ? max(1, (report.pitches + 14) / 15) : 0
        let postseasonFatigue = clamp(
            params.state.fatigue + appearanceLoad - automaticGames * 4,
            0,
            100
        )
        let updated = replacing(
            params.state,
            revision: params.state.revision + 1,
            phase: phase,
            managerTrust: trust,
            catcherTrust: clamp(params.state.catcherTrust + (soundProcess ? 2 : -1) + sequenceTrustReward, 0, 100),
            fatigue: postseasonFatigue,
            news: Array(([headline] + automaticSummaries + [trustLine] + params.state.news).prefix(30)),
            seasonTrigger: .some(continues ? nextTrigger : nil),
            currentRival: .some(continues ? rival : nil),
            decisionHistory: resolvedHistory,
            postseason: .some(nextPostseason)
        )
        _ = rng.next()
        return result(
            updated,
            nextSeed: String(rng.next()),
            events: ["pro_autumn_game_resolved"]
                + (automaticGames > 0 ? ["pro_autumn_team_game_simulated"] : [])
                + [continues ? "pro_autumn_advanced" : "pro_autumn_finished"]
        )
    }

    public func choosePostseasonAvailability(
        _ params: ChooseProPostseasonAvailabilityParams
    ) throws -> ProCareerResult {
        try validate(params.state, phase: .importantGame)
        guard Self.usesFinalSeriesRules(params.state),
              let postseason = params.state.postseason,
              postseason.currentRound != nil,
              postseason.result == .inProgress,
              ProPostseasonRules.requiresAvailabilityDecision(postseason, role: params.state.role) else {
            throw SimulationError.invalidProCareer("postseason availability decision is not pending")
        }
        var rng = try generator(params.seed)
        switch params.choice {
        case .pitchAgain:
            let selected = ProPostseasonRules.choosingAvailability(postseason, choice: .pitchAgain)
            let pitches = postseason.series?.lastAppearancePitches ?? 0
            let penalty = ProPostseasonRules.consecutiveAppearanceFatiguePenalty(
                role: params.state.role,
                lastAppearancePitches: pitches
            )
            let updated = replacing(
                params.state,
                revision: params.state.revision + 1,
                fatigue: clamp(params.state.fatigue + penalty, 0, 100),
                news: Array((["연투를 택했습니다. 다음 경기에도 마운드에 오릅니다."] + params.state.news).prefix(30)),
                postseason: .some(selected)
            )
            return result(
                updated,
                nextSeed: String(rng.next()),
                events: ["pro_autumn_availability_pitch_again"]
            )

        case .restForDecider:
            let simulated = simulatePostseasonTeamGames(
                from: postseason,
                careerState: params.state,
                role: params.state.role,
                strengthEdgePermille: ProPostseasonRules.teamStrengthEdgePermille(params.state),
                forceCurrentGame: true,
                using: &rng
            )
            let continues = simulated.state.result == .inProgress
            let trigger: ProSeasonTrigger? = continues
                ? simulated.state.currentRound.map { ProPostseasonRules.trigger(for: $0) }
                : nil
            let rival = continues
                ? trigger.map { trigger in
                    rivalForGame(
                        params.state,
                        week: params.state.week,
                        trigger: trigger,
                        opponentTeamID: simulated.state.series?.opponentTeamID
                    )
                }
                : nil
            let headline: String
            switch simulated.state.result {
            case .champion: headline = "플레이오프 우승. 올해의 마지막 공이 남았습니다."
            case .runnerUp: headline = "결승에서 멈췄습니다. 가을은 여기까지입니다."
            case .inProgress:
                let series = simulated.state.series
                let roundTitle: String = switch simulated.state.currentRound {
                case .wildCard: "와일드카드"
                case .semifinal: "준플레이오프"
                case .playoff: "플레이오프"
                case .final: "우승 결정전"
                case nil: "가을 시리즈"
                }
                headline = "한 경기를 쉬었습니다. \(roundTitle) \(series?.nextGameNumber ?? 1)차전을 준비합니다."
            case .eliminated, .didNotQualify, .unavailable:
                headline = "가을이 닫혔습니다."
            }
            let updated = replacing(
                params.state,
                revision: params.state.revision + 1,
                phase: continues ? .importantGame : .seasonReview,
                fatigue: clamp(params.state.fatigue - 12, 0, 100),
                news: Array(([headline] + simulated.summaries + params.state.news).prefix(30)),
                seasonTrigger: .some(trigger),
                currentRival: .some(rival),
                postseason: .some(simulated.state)
            )
            return result(
                updated,
                nextSeed: String(rng.next()),
                events: ["pro_autumn_availability_rest"]
                    + (simulated.count > 0 ? ["pro_autumn_team_game_simulated"] : [])
                    + [continues ? "pro_autumn_advanced" : "pro_autumn_finished"]
            )
        }
    }

    private func simulatePostseasonTeamGames(
        from initial: ProPostseasonState,
        careerState: ProCareerSnapshot,
        role: ProRole,
        strengthEdgePermille: Int,
        forceCurrentGame: Bool,
        using rng: inout SplitMix64
    ) -> (state: ProPostseasonState, summaries: [String], count: Int) {
        var state = initial
        var summaries: [String] = []
        var force = forceCurrentGame
        while state.result == .inProgress
            && (force || !ProPostseasonRules.shouldDirectlyPlayNextGame(state, role: role)) {
            force = false
            var teamRuns = LeagueBaseline.teamRuns(using: &rng)
            var opponentRuns = LeagueBaseline.teamRuns(using: &rng)
            let liveStrengthEdge = ProPostseasonRules.teamStrengthEdgePermille(
                careerState,
                opponentTeamID: state.series?.opponentTeamID
            )
            applyPostseasonStrength(
                state.series?.opponentTeamID == nil ? strengthEdgePermille : liveStrengthEdge,
                teamRuns: &teamRuns,
                opponentRuns: &opponentRuns,
                using: &rng
            )
            if teamRuns == opponentRuns {
                if rng.nextInt(upperBound: 2) == 0 { teamRuns += 1 } else { opponentRuns += 1 }
            }
            let won = teamRuns > opponentRuns
            let gameNumber = state.series?.nextGameNumber ?? 1
            state = ProPostseasonRules.resolvingSeriesGame(
                state,
                won: won,
                directlyPlayed: false,
                teamRuns: teamRuns,
                opponentRuns: opponentRuns
            )
            if state.result == .inProgress {
                state = ProPostseasonRules.preparingSeries(state, state: careerState)
            }
            summaries.append(
                "우승 결정전 \(gameNumber)차전 자동 진행 · \(teamRuns)-\(opponentRuns) \(won ? "승" : "패")"
            )
        }
        return (state, summaries, summaries.count)
    }

    private func resolvePostseasonGame(
        state: ProCareerSnapshot,
        report: ImportantInningReport,
        strengthEdgePermille: Int,
        using rng: inout SplitMix64
    ) -> (teamRuns: Int, opponentRuns: Int, won: Bool) {
        let inning = min(9, max(1, report.inningAtEntry ?? postseasonEntryInning(state)))
        let entryOuts = min(2, max(0, report.outsAtEntry ?? 0))
        let directOuts = min(27, max(0, report.outs ?? 0))
        let differential = report.scoreDifferentialAtEntry ?? 0

        // 등판 전까지의 절대 점수는 화면에 없으므로, 진행된 이닝 비율만큼 리그 득점
        // 분포를 축소해 만든다. 점수 차는 화면에 보인 값을 그대로 보존한다.
        var opponentAtEntry = LeagueBaseline.teamRuns(using: &rng) * max(0, inning - 1) / 9
        var teamAtEntry = opponentAtEntry + differential
        if let reportedTeamRuns = report.teamRuns {
            teamAtEntry = max(0, reportedTeamRuns)
            if report.scoreDifferentialAtEntry != nil {
                opponentAtEntry = max(0, teamAtEntry - differential)
            }
        }
        if teamAtEntry < 0 {
            opponentAtEntry += -teamAtEntry
            teamAtEntry = 0
        }

        var teamRuns = max(0, teamAtEntry)
        var opponentRuns = max(0, opponentAtEntry) + report.runsAllowed
        let opponentOutsRemaining = max(
            0,
            (10 - inning) * 3 - entryOuts - directOuts
        )
        if opponentOutsRemaining > 0 {
            opponentRuns += LeagueBaseline.restOfTeamRuns(
                outsCovered: opponentOutsRemaining,
                using: &rng
            )
        }

        let teamOutsRemaining = max(0, (10 - inning) * 3)
        let gameAlreadyEnded = inning == 9
            && opponentOutsRemaining == 0
            && teamRuns > opponentRuns
        if report.teamRuns == nil, teamOutsRemaining > 0, !gameAlreadyEnded {
            teamRuns += LeagueBaseline.restOfTeamRuns(
                outsCovered: teamOutsRemaining,
                using: &rng
            )
        }

        applyPostseasonStrength(
            strengthEdgePermille,
            teamRuns: &teamRuns,
            opponentRuns: &opponentRuns,
            using: &rng
        )

        // 동점이면 최대 세 번의 연장 한 이닝을 진행하고, 그래도 같으면 마지막 한 점을
        // 결정론적으로 배정한다. 포스트시즌 경기에는 무승부가 없다.
        for _ in 0..<3 where teamRuns == opponentRuns {
            teamRuns += LeagueBaseline.restOfTeamRuns(outsCovered: 3, using: &rng)
            opponentRuns += LeagueBaseline.restOfTeamRuns(outsCovered: 3, using: &rng)
        }
        if teamRuns == opponentRuns {
            if rng.nextInt(upperBound: 2) == 0 { teamRuns += 1 } else { opponentRuns += 1 }
        }
        return (teamRuns, opponentRuns, teamRuns > opponentRuns)
    }

    private func applyPostseasonStrength(
        _ edgePermille: Int,
        teamRuns: inout Int,
        opponentRuns: inout Int,
        using rng: inout SplitMix64
    ) {
        let edge = min(180, max(-180, edgePermille))
        guard edge != 0 else { return }
        let roll = rng.nextInt(upperBound: 1_000)
        if edge > 0, roll < edge {
            teamRuns += 1
        } else if edge < 0, roll < -edge {
            opponentRuns += 1
        }
    }

    private func postseasonEntryInning(_ state: ProCareerSnapshot) -> Int {
        switch state.seasonTrigger {
        case .autumnWildCard: return 9
        case .autumnSemifinal, .autumnPlayoff: return 8
        case .autumnFinal:
            switch state.role {
            case .starter: return 6
            case .longRelief: return 5
            case .setup: return 8
            case .closer: return 9
            }
        default: return 7
        }
    }

    public func reviewSeason(_ params: ProStateParams) throws -> ProCareerResult {
        if let journey = params.state.journeyState {
            if params.state.phase == .seasonSettlement, journey.lastSettlement != nil {
                return result(params.state, nextSeed: params.seed, events: ["pro_season_settlement_reused"])
            }
            return try reviewJourneySeason(params)
        }
        if journeyEnabled, params.state.phase == .seasonReview {
            let migrated = try migrateLegacyJourney(params)
            guard migrated.snapshot.journeyState != nil else { return migrated }
            if migrated.snapshot.phase == .seasonSettlement {
                return migrated
            }
            return try reviewJourneySeason(.init(seed: migrated.nextSeed, state: migrated.snapshot))
        }
        try validate(params.state, phase: .seasonReview)
        var rng = try generator(params.seed)
        let state = params.state
        // Runs allowed per nine innings (RA/9). The sim never separates earned runs,
        // so the copy reads "9이닝당 실점" rather than the incorrect "평균자책(ERA)".
        let runsPer9Permille = state.currentStats.inningsOuts == 0 ? 9_990 : state.currentStats.runsAllowed * 27_000 / state.currentStats.inningsOuts
        var awards = state.awards
        var milestones = state.milestones
        let honorVersion = Self.usesRetiredNumberLiveRules(state) ? 2 : 1
        let honorIDs = Set(ProCareerRecognitionRules.awardContentIDs(
            stats: state.currentStats,
            rulesVersion: honorVersion
        ))
        if honorIDs.contains("pro.award.strikeouts") {
            awards = addingUnique("시즌 \(state.season) 탈삼진상", to: awards)
        }
        if honorIDs.contains("pro.award.run-prevention") {
            awards = addingUnique("시즌 \(state.season) 최소 실점상", to: awards)
        }
        if honorIDs.contains("pro.award.command") {
            awards = addingUnique("시즌 \(state.season) 정밀 제구상", to: awards)
        }
        if honorIDs.contains("pro.award.hits") {
            awards = addingUnique("시즌 \(state.season) 피안타 억제상", to: awards)
        }
        if honorIDs.contains("pro.award.innings") {
            awards = addingUnique("시즌 \(state.season) 이닝 책임상", to: awards)
        }
        milestones = addingUnique("\(state.season)시즌 완주", to: milestones)
        let phase: ProCareerPhase = state.season >= Self.maximumCareerSeasons
            ? .retirementDecision : .offseasonDecision
        let news = ["시즌 \(state.season) 종료 · \(state.currentStats.games)경기 · \(state.currentStats.strikeouts)K · 9이닝당 실점 \(String(format: "%.2f", Double(runsPer9Permille) / 1000))"] + state.news
        let archivedStats = state.currentStats.archivingPostseason(state.postseason?.gameHistory)
        let updated = replacing(state, revision: state.revision + 1, phase: phase, careerStats: state.careerStats + [archivedStats], awards: awards, milestones: milestones, news: Array(news.prefix(30)))
        return result(updated, nextSeed: String(rng.next()), events: ["pro_season_reviewed"])
    }

    public func chooseOffseason(_ params: ProOffseasonParams) throws -> ProCareerResult {
        let isCompletedRetirementRetry = params.decision == .retire && params.state.phase == .completed
        guard [.offseasonDecision, .retirementDecision].contains(params.state.phase) || isCompletedRetirementRetry else { throw SimulationError.invalidProCareer("지금은 오프시즌 선택을 할 수 없습니다.") }
        if isCompletedRetirementRetry, journeyEnabled, params.state.journeyState != nil {
            guard let expectedRevision = params.expectedRevision,
                  expectedRevision == params.state.revision else {
                throw SimulationError.invalidProCareer("stale_revision")
            }
            try validateState(params.state)
            return result(params.state, nextSeed: params.seed, events: ["pro_career_retired_idempotent"])
        }
        if journeyEnabled {
            if params.state.journeyState == nil {
                let migrated = try migrateLegacyJourney(.init(seed: params.seed, state: params.state))
                if migrated.snapshot.journeyState != nil {
                    return try chooseOffseason(.init(
                        seed: migrated.nextSeed,
                        state: migrated.snapshot,
                        decision: params.decision,
                        expectedRevision: params.expectedRevision
                    ))
                }
            }
            if params.state.journeyState != nil {
                return try chooseJourneyOffseason(params)
            }
        }
        try validateState(params.state)
        var rng = try generator(params.seed)
        let state = params.state
        if params.decision == .retire || state.phase == .retirementDecision {
            let score = hallOfFameScore(state)
            let news = retirementRetrospective(state: state, hallOfFameScore: score) + state.news
            let retired = replacing(state, revision: state.revision + 1, phase: .completed,
                milestones: addingUnique("은퇴 · 통산 \(state.careerStats.count)시즌", to: state.milestones),
                news: news, hallOfFameScore: score)
            return result(retired, nextSeed: String(rng.next()), events: ["pro_career_retired"])
        }
        var age = state.age + 1
        var military = state.militaryCompleted
        let service = state.serviceYears + (state.level == .major ? 1 : 0)
        var team = state.team
        var news = state.news
        if params.decision == .militaryService {
            guard !military else { throw SimulationError.invalidProCareer("이미 군 복무를 마쳤습니다.") }
            age += 1; military = true; news.insert("두 시즌의 군 복무를 마치고 복귀했습니다.", at: 0)
        } else if params.decision == .freeAgency {
            guard service >= 6 else { throw SimulationError.invalidProCareer("FA 신청에는 1군 등록 6년이 필요합니다.") }
            team = Self.proTeams[((Self.proTeams.firstIndex { $0.id == state.team.id } ?? 0) + 3) % Self.proTeams.count]
            news.insert("FA 계약: \(team.name)과 새 도전을 시작합니다.", at: 0)
        }
        let season = state.season + 1
        let recoveryYear = state.journeyState?.recoveryYearPending == true
        let pitcher = ProContractMarketRules.projectedPitcher(
            for: state.pitcher,
            effectiveAge: age,
            proRulesVersion: Self.currentRulesVersion,
            recoveryYear: recoveryYear
        )
        let contract = ProContractSnapshot(yearsRemaining: max(1, (state.contract?.yearsRemaining ?? 1) - 1), annualSalary: max(state.contract?.annualSalary ?? 40_000_000, 40_000_000 + service * 50_000_000), rolePromise: state.role)
        let clearedDecision: ProSeasonDecision? = nil
        // 시즌을 마친 보직을 다음 시즌에도 유지한다. 예전에는 여기서 선호를 비워서,
        // 신뢰 기반 배정이 closer를 돌려줄 수 없는 탓에 마무리로 끝낸 시즌이 이듬해
        // 선발로 리셋됐다("왜 새 시즌엔 또 선발로 가는지" 리뷰). 새 계약의
        // rolePromise(state.role)와도 일치한다.
        let carriedRolePreference: ProRole? = state.role
        let baseAdvanced = replacing(state, revision: state.revision + 1, phase: .weeklyPlan, pitcher: pitcher, team: team, age: age, season: season, week: 0, rolePreference: carriedRolePreference, fatigue: 0, injuryWeeks: 0, serviceYears: service, militaryCompleted: military, contract: contract, currentStats: ProSeasonStats(season: season, teamID: team.id),
            // 새 시즌은 빈 기록으로 시작한다. 안 비우면 20시즌 구원 투수가 천 행 넘게 들고
            // 다니고 등판 번호도 시즌을 넘어 계속 늘어난다. 지난 시즌은 careerStats가 맡는다.
            gameLines: [],
            news: Array(news.prefix(30)), proRulesVersion: Self.currentRulesVersion, pendingDecision: clearedDecision,
            activeDecisionModifiers: .some(nil), resolvedFollowUps: .some(nil), roleRequest: .some(nil))
        let tensions = seasonTensions(for: baseAdvanced)
        let clearedRival: ProRivalBatter? = nil
        let clearedTrigger: ProSeasonTrigger? = nil
        // v8 에이징은 31세부터 시작한다(위 projectedPitcher). 뉴스도 같은 나이에 맞춘다.
        let declineNews = age >= 31 ? ["\(age)세 · 전성기가 기울며 구위가 한 단계 떨어졌습니다."] : []
        let updated = replacing(baseAdvanced, news: Array((declineNews + [tensionHeadline(tensions)] + baseAdvanced.news).prefix(30)), seasonSegment: .springCamp, seasonTrigger: clearedTrigger, currentRival: clearedRival, seasonTensions: tensions, seasonImportantGames: 0, postseason: .some(nil))
        return result(updated, nextSeed: String(rng.next()), events: ["pro_offseason_resolved"])
    }

    /// 모든 진입 경로가 같은 상한을 쓰게 공개한다. 나이는 강제 은퇴 조건이 아니다 — 군 복무나
    /// 늦은 전성기를 선택해도 플레이어가 원하면 정확히 20시즌을 완주할 수 있다.
    public static let maximumCareerSeasons = 20
    /// Live schedule/fatigue/agency rules. New careers start here. Offseason may raise an
    /// in-progress save to this value without rewriting already stored season records.
    public static let currentRulesVersion = 10
    /// First version that owns the agency weekly-plan and important-game contracts.
    /// Must stay below `currentRulesVersion` so a version bump cannot turn agency off.
    public static let agencyRulesVersion = 3
    /// Season climate, skill tracking, imperfect auto calls, visible aging.
    public static let careerArcRulesVersion = 5
    /// Highlight autumn series after the 24-week regular season.
    public static let autumnRulesVersion = 6
    /// Compressed best-of-five final with role-aware direct appearances and bullpen availability.
    public static let finalSeriesRulesVersion = 7
    /// v8 도전 규칙: 리그가 3년차부터 가파르게 추적하고, 에이징이 31세부터 네 능력에
    /// 걸쳐 진행되며, 체력이 부상 위험을 완전히 지우지 못하고, 감독의 믿음이 85 이상에서
    /// 천천히 오른다. 리뷰의 "프로가 너무 쉽다·굴곡이 없다"에 대한 응답.
    public static let careerChallengeRulesVersion = 8
    /// Journey scoring/awards/retired-number content. New careers only; never raised in offseason.
    /// v3: 아웃 유실 수정으로 이닝·비율 지표가 실측값으로 돌아오자 v2 수상 문턱이 일제히
    /// 쉬워졌다(수상 빈도 95‰→225‰, 영구결번 198‰→310‰). 문턱을 보정 후 지표에 맞춘다.
    public static let currentJourneyRulesVersion = 3

    public static func usesAgencyRules(_ state: ProCareerSnapshot) -> Bool {
        (state.proRulesVersion ?? 1) >= agencyRulesVersion
    }

    public static func usesRetiredNumberLiveRules(_ state: ProCareerSnapshot) -> Bool {
        (state.proRulesVersion ?? 1) >= 4
    }

    public static func usesCareerArcRules(_ state: ProCareerSnapshot) -> Bool {
        (state.proRulesVersion ?? 1) >= careerArcRulesVersion
    }

    public static func usesAutumnRules(_ state: ProCareerSnapshot) -> Bool {
        (state.proRulesVersion ?? 1) >= autumnRulesVersion
    }

    public static func usesFinalSeriesRules(_ state: ProCareerSnapshot) -> Bool {
        (state.proRulesVersion ?? 1) >= finalSeriesRulesVersion
    }

    public static func usesChallengeRules(_ state: ProCareerSnapshot) -> Bool {
        (state.proRulesVersion ?? 1) >= careerChallengeRulesVersion
    }

    /// v9 weekly decisions: 3-week cadence, follow-up modifiers, four new types.
    public static let weeklyDecisionRulesVersion = 9

    public static func usesWeeklyDecisionRules(_ state: ProCareerSnapshot) -> Bool {
        (state.proRulesVersion ?? 1) >= weeklyDecisionRulesVersion
    }

    /// v10: FA 다년 계약·계약금·잔류 협상·연봉 사용처 확장 (P1-3).
    public static let contractDepthRulesVersion = 10
    /// v10: 국가대표 대회 (P1-4). contractDepth와 같은 세대에 출시된다.
    public static let nationalTeamRulesVersion = 10

    public static func usesContractDepthRules(_ state: ProCareerSnapshot) -> Bool {
        (state.proRulesVersion ?? 1) >= contractDepthRulesVersion
    }

    public static func usesNationalTeamRules(_ state: ProCareerSnapshot) -> Bool {
        (state.proRulesVersion ?? 1) >= nationalTeamRulesVersion
    }

    public static func decisionWeeks(for state: ProCareerSnapshot) -> [Int] {
        usesWeeklyDecisionRules(state) ? weeklySeasonDecisionWeeks : seasonDecisionWeeks
    }

    public static func maximumDecisions(for state: ProCareerSnapshot) -> Int {
        usesWeeklyDecisionRules(state) ? weeklyMaximumSeasonDecisions : maximumSeasonDecisions
    }

    /// 부상 판정에 쓰는 압력. 유효 피로를 기본으로 하되, v8부터는 원피로의 80%를 바닥으로
    /// 둔다 — 체력 특화가 부상을 **수학적으로 불가능**하게 만들던 구멍(체력 80이면 원피로
    /// 100에서도 유효 75)을 막는다. 관리된 피로(원 90 이하)는 여전히 안전하다.
    /// 구속 계산이 쓰는 `effectiveFatigue` 자체는 건드리지 않는다.
    public static func injuryPressure(
        rawFatigue: Int,
        stamina: Int,
        mastery: Int,
        challengeRules: Bool
    ) -> Int {
        let effective = PitchAbilityRules.effectiveFatigue(
            rawFatigue: rawFatigue,
            stamina: stamina,
            mastery: mastery
        )
        guard challengeRules else { return effective }
        return max(effective, min(100, max(0, rawFatigue)) * 800 / 1_000)
    }

    public static func liveClimate(for state: ProCareerSnapshot, week: Int? = nil) -> ProSeasonClimate? {
        guard usesCareerArcRules(state) else { return nil }
        let stabilize = state.journeyState?.activeSeasonBenefit?.kind == .climateStabilization
            ? (state.journeyState?.activeSeasonBenefit?.remainingCharges ?? 0)
            : 0
        return ProSeasonClimateRules.climate(
            careerID: state.proCareerID,
            season: state.season,
            week: week ?? max(1, state.week),
            strikeouts: state.currentStats.strikeouts,
            inningsOuts: state.currentStats.inningsOuts,
            stabilizeCharges: stabilize
        )
    }

    public static func liveBatterOffset(for state: ProCareerSnapshot, week: Int? = nil) -> Int {
        let skill = (state.pitcher.stuff + state.pitcher.command + state.pitcher.movement + state.pitcher.stamina) / 4
        if usesCareerArcRules(state), let climate = liveClimate(for: state, week: week) {
            return DifficultyScale.proArc(
                season: state.season,
                level: state.level,
                skill: skill,
                climate: climate,
                challenge: usesChallengeRules(state)
            )
        }
        return usesRetiredNumberLiveRules(state) ? DifficultyScale.pro(season: state.season) : 0
    }

    public static func journeyRulesVersion(for state: ProCareerSnapshot) -> Int {
        state.journeyState?.rulesVersion ?? 1
    }

    public static func developmentTicksRequired(for ability: Int) -> Int {
        switch ability {
        case ..<55: return 2
        case 55..<65: return 3
        case 65..<73: return 4
        default: return 6
        }
    }

    /// 화면과 시뮬레이션이 같은 성장 목표를 말하도록 주간 계획의 현재 목표를 공개한다.
    /// v4 이전 저장은 당시 약속한 2회 규칙을 유지하고, 성장 계획이 아닌 선택은 nil이다.
    public static func developmentTicksRequired(
        for plan: ProWeekPlan,
        pitcher: PitcherSnapshot,
        proRulesVersion: Int?
    ) -> Int? {
        let abilities: [Int]
        switch plan {
        case .developStuff:
            abilities = [pitcher.stuff]
        case .refineCommand:
            abilities = [pitcher.command]
        case .developMovement:
            abilities = [pitcher.movement]
        case .buildStamina:
            abilities = [pitcher.stamina]
        case .developWeapon:
            abilities = [pitcher.stuff, pitcher.movement]
        case .recover, .earnTrust:
            return nil
        }
        guard (proRulesVersion ?? 1) >= 4 else { return 2 }
        return abilities.map(Self.developmentTicksRequired(for:)).max()
    }

    public static func healthForecast(
        for state: ProCareerSnapshot,
        plan: ProWeekPlan
    ) -> ProWeekHealthForecast {
        ProWeekHealthForecast.forecast(state: state, plan: plan)
    }

    /// 현재 선수의 대우는 나이나 시즌 번호가 아니라 실제 커리어에서 파생한다. 저장 문자열을
    /// 새로 만들지 않고 언제나 같은 기록에서 같은 위상을 계산하므로 구저장에도 바로 적용된다.
    public static func careerStanding(for state: ProCareerSnapshot) -> ProCareerStanding {
        if let journey = state.journeyState {
            let records = ProTeamCareerRecordRules.backfill(
                careerStats: state.careerStats,
                recognitions: journey.recognitions,
                existing: journey.teamRecords
            )
            guard let record = ProTeamCareerRecordRules.record(teamID: state.team.id, in: records) else {
                return .prospect
            }
            switch ProTeamCareerRecordRules.tier(
                record: record,
                rulesVersion: journey.rulesVersion
            ) {
            case .newFace: return .prospect
            case .supportingPillar: return .roster
            case .corePlayer: return .established
            case .clubAce: return .ace
            case .clubSymbol, .retiredNumberCandidate: return .clubSymbol
            }
        }
        let completedGames = state.careerStats.reduce(0) { $0 + $1.games }
        let completedOuts = state.careerStats.reduce(0) { $0 + $1.inningsOuts }
        let currentGames = state.currentStats.games
        let recent = Array(state.careerStats.suffix(2)) + (currentGames > 0 ? [state.currentStats] : [])
        let recentOuts = recent.reduce(0) { $0 + $1.inningsOuts }
        let recentRuns = recent.reduce(0) { $0 + $1.runsAllowed }
        let recentRA9Permille = recentOuts == 0 ? Int.max : recentRuns * 27_000 / recentOuts

        if state.serviceYears >= 8,
           completedOuts >= 2_400 || state.awards.count >= 3 {
            return .clubSymbol
        }
        if state.serviceYears >= 3,
           recentOuts >= 720,
           recentRA9Permille <= 3_200 {
            return .ace
        }
        if state.serviceYears >= 4 || completedGames >= 80 { return .established }
        if state.serviceYears >= 1 || state.level == .major { return .roster }
        return .prospect
    }

    /// 직접 플레이 장면 수와 실제 등판 수를 분리해 설명할 때 쓰는 역할별 일정 원본.
    public static func expectedRemainingOutings(for state: ProCareerSnapshot) -> Int {
        let remainingWeeks = max(0, 24 - state.week - max(0, state.injuryWeeks))
        let perWeek = switch state.role {
        case .starter: 1
        case .longRelief: 2
        case .setup, .closer: 3
        }
        return remainingWeeks * perWeek
    }

    /// 결정 후보 주차와 시즌 상한은 UI·테스트에서도 같은 원본을 쓸 수 있게 공개한다.
    /// 개막 직후·올스타 휴식기·순위 경쟁의 세 막에 한 번씩만 멈춘다.
    /// v8 and earlier keep this cadence; v9 uses `weeklySeasonDecisionWeeks`.
    public static let seasonDecisionWeeks = [6, 13, 20]
    public static let maximumSeasonDecisions = 3
    public static let weeklySeasonDecisionWeeks = [3, 6, 9, 12, 15, 18, 21]
    public static let weeklyMaximumSeasonDecisions = 7

    public static func mediaOpportunityWeek(proCareerID: String, season: Int, proRulesVersion: Int? = nil) -> Int {
        let weeks = (proRulesVersion ?? 1) >= weeklyDecisionRulesVersion
            ? weeklySeasonDecisionWeeks
            : seasonDecisionWeeks
        let hash = UInt64(StableHash.fnv1a64("\(proCareerID)|\(season)|media"), radix: 16) ?? 0
        return weeks[Int(hash % UInt64(weeks.count))]
    }

    /// 시즌 결정 압축 전 저장본의 서명된 기록과 pending 결정을 계속 읽기 위한 호환 범위.
    /// 새 커리어에서는 절대 이 주차나 상한으로 결정을 생성하지 않는다.
    static let legacySeasonDecisionWeeks = [3, 6, 9, 12, 15, 18, 21]
    static let persistedSeasonDecisionLimit = 7

    private static func isCompatibleDecisionWeek(_ week: Int) -> Bool {
        seasonDecisionWeeks.contains(week) || legacySeasonDecisionWeeks.contains(week)
    }

    /// 같은 커리어·시즌·주차에는 상태나 진행 시드와 무관하게 같은 세 선택지를 만든다.
    /// 세 슬롯을 여섯 종류 위에서 회전시켜 시즌마다 다른 조합을 만나게 한다. 한 시즌에
    /// 전부 보여 주지 않는 것이 다음 선수로 다시 시작할 이유가 된다.
    func seasonDecision(
        for state: ProCareerSnapshot,
        week: Int,
        climate: ProSeasonClimate? = nil,
        trust: Int? = nil,
        level _: ProLevel? = nil
    ) -> ProSeasonDecision? {
        if Self.usesWeeklyDecisionRules(state) {
            return weeklySeasonDecision(for: state, week: week, climate: climate, trust: trust)
        }
        guard let slot = Self.seasonDecisionWeeks.firstIndex(of: week) else { return nil }
        if Self.usesCareerArcRules(state) {
            let history = state.decisionHistory ?? []
            let hadFormCrisis = history.contains { $0.season == state.season && $0.type == .formCrisis }
            if !hadFormCrisis,
               climate == .slump,
               (trust ?? state.managerTrust) < 55 {
                return makeDecision(type: .formCrisis, state: state, week: week)
            }
            let hadAging = history.contains { $0.season == state.season && $0.type == .agingCrossroads }
            if !hadAging, week == 20, state.age >= 32 {
                return makeDecision(type: .agingCrossroads, state: state, week: week)
            }
        }
        let mediaSlot = Self.mediaOpportunityWeek(proCareerID: state.proCareerID, season: state.season, proRulesVersion: state.proRulesVersion)
        let hasMediaThisSeason = (state.decisionHistory ?? []).contains {
            $0.season == state.season && $0.type == .mediaOpportunity
        }
        if week == mediaSlot,
           state.journeyState != nil,
           (state.journeyState?.reputation.fanSupport ?? 0) >= 35,
           !hasMediaThisSeason {
            let content = decisionContent(.mediaOpportunity)
            return ProSeasonDecision(
                id: "season-\(state.season)-week-\(week)-\(ProSeasonDecisionType.mediaOpportunity.rawValue)",
                type: .mediaOpportunity,
                season: state.season,
                week: week,
                title: content.title,
                detail: content.detail,
                choices: content.choices
            )
        }
        // Media is a Wave 5 replacement for an eligible fixed slot. Ordinary decisions keep
        // the Wave 4 six-type rotation so old content and replay expectations do not shift.
        let types: [ProSeasonDecisionType] = [
            .extraBullpen, .catcherGamePlan, .roleMeeting,
            .recordChase, .rivalAnalysis, .seasonFinale,
        ]
        let offset = Int(hashInt("\(state.proCareerID)|season\(state.season)|season-decisions") % UInt64(types.count))
        let type = types[(offset + slot) % types.count]
        return makeDecision(type: type, state: state, week: week)
    }

    private func weeklySeasonDecision(
        for state: ProCareerSnapshot,
        week: Int,
        climate: ProSeasonClimate?,
        trust: Int?
    ) -> ProSeasonDecision? {
        guard let slot = Self.weeklySeasonDecisionWeeks.firstIndex(of: week) else { return nil }
        let history = state.decisionHistory ?? []
        let used = Set(history.filter { $0.season == state.season }.map(\.type))
        if Self.usesCareerArcRules(state) {
            if !used.contains(.formCrisis),
               climate == .slump,
               (trust ?? state.managerTrust) < 55 {
                return makeDecision(type: .formCrisis, state: state, week: week)
            }
            if !used.contains(.agingCrossroads),
               week == Self.weeklySeasonDecisionWeeks.last,
               state.age >= 32 {
                return makeDecision(type: .agingCrossroads, state: state, week: week)
            }
        }
        let mediaSlot = Self.mediaOpportunityWeek(proCareerID: state.proCareerID, season: state.season, proRulesVersion: state.proRulesVersion)
        if week == mediaSlot,
           !used.contains(.mediaOpportunity),
           state.journeyState != nil,
           (state.journeyState?.reputation.fanSupport ?? 0) >= 35 {
            return makeDecision(type: .mediaOpportunity, state: state, week: week)
        }
        let rotationPushEligible = state.role == .starter && state.fatigue < 60
        let pitchTrialEligible = lowMasteryPitch(in: state.pitcher) != nil
        let farmResetEligible = (trust ?? state.managerTrust) < 40
            || recentERAWorsened(state: state, throughWeek: week)
        let specialEligible = rotationPushEligible || pitchTrialEligible || farmResetEligible
        var candidates: [ProSeasonDecisionType] = [
            .extraBullpen, .catcherGamePlan, .roleMeeting,
            .recordChase, .rivalAnalysis, .seasonFinale,
        ]
        if rotationPushEligible { candidates.append(.rotationPush) }
        if pitchTrialEligible { candidates.append(.newPitchTrial) }
        if farmResetEligible { candidates.append(.farmReset) }
        if state.season >= 2, !specialEligible { candidates.append(.veteranMentor) }
        candidates.removeAll { used.contains($0) }
        guard !candidates.isEmpty else { return nil }
        let offset = Int(
            hashInt("\(state.proCareerID)|season\(state.season)|weekly-decisions")
                % UInt64(candidates.count)
        )
        let type = candidates[(offset + slot) % candidates.count]
        return makeDecision(type: type, state: state, week: week)
    }

    private func makeDecision(
        type: ProSeasonDecisionType,
        state: ProCareerSnapshot,
        week: Int
    ) -> ProSeasonDecision {
        let content = decisionContent(type, pitcher: state.pitcher)
        return ProSeasonDecision(
            id: "season-\(state.season)-week-\(week)-\(type.rawValue)",
            type: type,
            season: state.season,
            week: week,
            title: content.title,
            detail: content.detail,
            choices: content.choices
        )
    }

    private func decisionContent(
        _ type: ProSeasonDecisionType,
        pitcher: PitcherSnapshot? = nil
    ) -> (title: String, detail: String, choices: [ProSeasonDecisionChoice]) {
        switch type {
        case .extraBullpen:
            return (
                "추가 불펜",
                "정규 훈련이 끝난 뒤 마운드 사용 시간이 남았습니다.",
                [
                    choice(type, "high_intensity", "강하게 더 던진다", "구위와 변화구를 함께 끌어올립니다.", .init(stuffDelta: 1, movementDelta: 1, fatigueDelta: 14)),
                    choice(type, "shape_work", "변화구만 다듬는다", "부담을 줄이고 변화구 감각에 집중합니다.", .init(movementDelta: 1, fatigueDelta: 7)),
                    choice(type, "rest", "오늘은 멈춘다", "성장 대신 몸을 회복합니다.", .init(fatigueDelta: -16)),
                ]
            )
        case .catcherGamePlan:
            return (
                "포수와 경기 계획",
                "다음 등판의 구종 순서와 승부 방식을 정합니다.",
                [
                    choice(type, "battery_plan", "포수와 함께 짠다", "배터리 호흡과 코스 실행을 우선합니다.", .init(commandDelta: 1, catcherTrustDelta: 8, fatigueDelta: 4)),
                    choice(type, "staff_report", "감독 보고서를 따른다", "벤치가 원하는 경기 운영에 맞춥니다.", .init(managerTrustDelta: 7, catcherTrustDelta: 1, fatigueDelta: 3)),
                    choice(type, "own_sequence", "내 공을 밀어붙인다", "변화구 감각을 얻는 대신 두 사람의 믿음을 겁니다.", .init(movementDelta: 1, managerTrustDelta: -2, catcherTrustDelta: -3, fatigueDelta: 5)),
                ]
            )
        case .roleMeeting:
            return (
                "역할 면담",
                "코칭스태프가 남은 시즌의 등판 역할을 묻습니다.",
                [
                    choice(type, "challenge_starter", "선발에 도전한다", "긴 이닝 준비와 경쟁 부담을 받아들입니다.", .init(staminaDelta: 1, managerTrustDelta: -3, fatigueDelta: 10, roleTarget: .starter)),
                    choice(type, "focus_relief", "구원에 집중한다", "짧은 등판의 구위와 포수 호흡을 택합니다.", .init(stuffDelta: 1, catcherTrustDelta: 3, fatigueDelta: 6, roleTarget: .longRelief)),
                    choice(type, "close_games", "마무리를 맡는다", "9회의 압박을 받아들이고 한 점 차 승부를 책임집니다.", .init(commandDelta: 1, managerTrustDelta: -4, catcherTrustDelta: 4, fatigueDelta: 8, roleTarget: .closer)),
                ]
            )
        case .recordChase:
            return (
                "기록 추격",
                "개인 기록과 팀에 필요한 투구 사이에서 훈련 방향을 고릅니다.",
                [
                    choice(type, "strikeouts", "탈삼진을 노린다", "결정구 두 가지를 강하게 연마합니다.", .init(stuffDelta: 1, movementDelta: 1, fatigueDelta: 12)),
                    choice(type, "run_prevention", "실점 억제를 택한다", "제구와 배터리 운영을 다듬습니다.", .init(commandDelta: 1, catcherTrustDelta: 4, fatigueDelta: 7)),
                    choice(type, "body_management", "몸을 관리한다", "긴 시즌을 버틸 체력과 회복을 택합니다.", .init(staminaDelta: 1, fatigueDelta: -12)),
                ]
            )
        case .rivalAnalysis:
            return (
                "라이벌 분석",
                "다음 맞대결을 앞두고 분석 시간을 어디에 쓸지 정합니다.",
                [
                    choice(type, "attack_weakness", "약점을 깊게 판다", "포수와 코스를 정교하게 맞춥니다.", .init(commandDelta: 1, catcherTrustDelta: 5, fatigueDelta: 6)),
                    choice(type, "keep_strength", "내 장점을 유지한다", "구위와 변화구 완성도를 높입니다.", .init(stuffDelta: 1, movementDelta: 1, fatigueDelta: 8)),
                    choice(type, "defer", "맞대결까지 보류한다", "추가 훈련 없이 몸을 가볍게 만듭니다.", .init(fatigueDelta: -8)),
                ]
            )
        case .seasonFinale:
            return (
                "시즌 막바지",
                "순위 경쟁과 회복, 동료 지원 사이에서 마지막 힘을 배분합니다.",
                [
                    choice(type, "push_race", "순위 경쟁에 건다", "감독의 믿음을 얻는 대신 피로를 감수합니다.", .init(managerTrustDelta: 8, fatigueDelta: 14)),
                    choice(type, "recover_first", "회복을 우선한다", "출전 의지를 의심받더라도 몸을 회복합니다.", .init(managerTrustDelta: -2, fatigueDelta: -18)),
                    choice(type, "support_youth", "젊은 선수를 돕는다", "벤치와 배터리의 신뢰를 함께 쌓습니다.", .init(managerTrustDelta: 4, catcherTrustDelta: 6, fatigueDelta: 3)),
                ]
            )
        case .mediaOpportunity:
            return (
                "content.pro-media-opportunity.title",
                "content.pro-media-opportunity.detail",
                [
                    choice(
                        type,
                        "advertising_shoot",
                        "content.pro-media-opportunity.choice.advertising.title",
                        "content.pro-media-opportunity.choice.advertising.detail",
                        .init(fatigueDelta: 6),
                        journeyEffect: .init(income: 30_000_000, fanDelta: 5)
                    ),
                    choice(
                        type,
                        "fan_together_shoot",
                        "content.pro-media-opportunity.choice.fan_together.title",
                        "content.pro-media-opportunity.choice.fan_together.detail",
                        .init(fatigueDelta: 4),
                        journeyEffect: .init(income: 10_000_000, fanDelta: 10, communityDelta: 2)
                    ),
                    choice(
                        type,
                        "focus_on_season",
                        "content.pro-media-opportunity.choice.focus.title",
                        "content.pro-media-opportunity.choice.focus.detail",
                        .init(fatigueDelta: -4),
                        journeyEffect: .init()
                    ),
                ]
            )
        case .formCrisis:
            return (
                "슬럼프 갈림길",
                "최근 등판이 흔들리고 감독의 믿음도 얇아졌습니다. 남은 주를 어떻게 버티겠습니까.",
                [
                    choice(type, "recover", "회복 주를 택한다", "다음 이틀을 평온하게 만들고 몸을 낮춥니다.", .init(managerTrustDelta: -2, fatigueDelta: -16)),
                    choice(type, "push_through", "밀어붙인다", "피로를 감수하고 선발 자리를 지킵니다.", .init(managerTrustDelta: 3, fatigueDelta: 12)),
                    choice(type, "move_bullpen", "구원으로 몸을 낮춘다", "짧은 이닝으로 슬럼프 피해를 줄입니다.", .init(managerTrustDelta: 1, fatigueDelta: -8, roleTarget: .longRelief)),
                ]
            )
        case .agingCrossroads:
            return (
                "전성기가 기울고 있다",
                "몸이 예전 같지 않습니다. 다음 시즌을 어떤 자세로 맞겠습니까.",
                [
                    choice(type, "keep_starter", "선발을 지킨다", "하락을 감수하고 로테이션에 남습니다.", .init(staminaDelta: 1, managerTrustDelta: 2, fatigueDelta: 6, roleTarget: .starter)),
                    choice(type, "move_bullpen", "불펜으로 옮긴다", "짧은 승부로 몸을 아끼며 남습니다.", .init(commandDelta: 1, fatigueDelta: -8, roleTarget: .longRelief)),
                    choice(type, "recovery_year", "회복 연도를 택한다", "성장을 멈추고 하락을 한 단계 줄입니다.", .init(managerTrustDelta: -2, fatigueDelta: -16)),
                ]
            )
        case .rotationPush:
            return (
                "content.pro-decision.rotation_push.title",
                "content.pro-decision.rotation_push.detail",
                [
                    choice(
                        type,
                        "accept_short_rest",
                        "content.pro-decision.choice.accept_short_rest.title",
                        "content.pro-decision.choice.accept_short_rest.detail",
                        .init(managerTrustDelta: 4, fatigueDelta: 12)
                    ),
                    choice(
                        type,
                        "keep_normal_rest",
                        "content.pro-decision.choice.keep_normal_rest.title",
                        "content.pro-decision.choice.keep_normal_rest.detail",
                        .init(managerTrustDelta: -2)
                    ),
                ]
            )
        case .newPitchTrial:
            return (
                "content.pro-decision.new_pitch_trial.title",
                "content.pro-decision.new_pitch_trial.detail",
                [
                    choice(
                        type,
                        "live_trial",
                        "content.pro-decision.choice.live_trial.title",
                        "content.pro-decision.choice.live_trial.detail",
                        .init(commandDelta: -3)
                    ),
                    choice(
                        type,
                        "bullpen_only",
                        "content.pro-decision.choice.bullpen_only.title",
                        "content.pro-decision.choice.bullpen_only.detail",
                        .init()
                    ),
                ]
            )
        case .farmReset:
            let growStuff = (pitcher?.stuff ?? 50) <= (pitcher?.command ?? 50)
            return (
                "content.pro-decision.farm_reset.title",
                "content.pro-decision.farm_reset.detail",
                [
                    choice(
                        type,
                        "accept_farm",
                        "content.pro-decision.choice.accept_farm.title",
                        "content.pro-decision.choice.accept_farm.detail",
                        growStuff
                            ? .init(stuffDelta: 2, managerTrustDelta: -6, fatigueDelta: -25)
                            : .init(commandDelta: 2, managerTrustDelta: -6, fatigueDelta: -25)
                    ),
                    choice(
                        type,
                        "stay_roster",
                        "content.pro-decision.choice.stay_roster.title",
                        "content.pro-decision.choice.stay_roster.detail",
                        .init(managerTrustDelta: -3)
                    ),
                ]
            )
        case .veteranMentor:
            return (
                "content.pro-decision.veteran_mentor.title",
                "content.pro-decision.veteran_mentor.detail",
                [
                    choice(
                        type,
                        "take_mentor",
                        "content.pro-decision.choice.take_mentor.title",
                        "content.pro-decision.choice.take_mentor.detail",
                        .init(movementDelta: 1, catcherTrustDelta: 5)
                    ),
                    choice(
                        type,
                        "keep_own_way",
                        "content.pro-decision.choice.keep_own_way.title",
                        "content.pro-decision.choice.keep_own_way.detail",
                        .init(catcherTrustDelta: -2)
                    ),
                ]
            )
        }
    }

    private func choice(
        _ type: ProSeasonDecisionType,
        _ suffix: String,
        _ title: String,
        _ detail: String,
        _ effect: ProDecisionEffect,
        journeyEffect: ProJourneyEffect? = nil
    ) -> ProSeasonDecisionChoice {
        ProSeasonDecisionChoice(
            id: "\(type.rawValue).\(suffix)",
            title: title,
            detail: detail,
            effect: effect,
            journeyEffect: journeyEffect
        )
    }

    private func weeklyChoiceSchedulesFollowUp(_ choiceID: String) -> Bool {
        choiceID.hasSuffix(".accept_short_rest")
            || choiceID.hasSuffix(".live_trial")
            || choiceID.hasSuffix(".accept_farm")
            || choiceID.hasSuffix(".take_mentor")
    }

    private func weeklyModifier(
        for pending: ProSeasonDecision,
        choice: ProSeasonDecisionChoice,
        pitcher: PitcherSnapshot,
        expiresWeek: Int
    ) -> ProDecisionModifier? {
        switch pending.type {
        case .rotationPush where choice.id.hasSuffix(".accept_short_rest"):
            return ProDecisionModifier(
                decisionID: pending.id,
                type: pending.type,
                expiresWeek: expiresWeek,
                extraOutingChance: 1,
                injuryPressureFloor: 80,
                baselineStuff: pitcher.stuff,
                baselineCommand: pitcher.command,
                baselineMovement: pitcher.movement,
                baselineStamina: pitcher.stamina,
                choiceID: choice.id
            )
        case .newPitchTrial where choice.id.hasSuffix(".live_trial"):
            return ProDecisionModifier(
                decisionID: pending.id,
                type: pending.type,
                expiresWeek: expiresWeek,
                commandDelta: choice.effect.commandDelta,
                targetPitch: lowMasteryPitch(in: pitcher),
                baselineStuff: pitcher.stuff,
                baselineCommand: pitcher.command,
                baselineMovement: pitcher.movement,
                baselineStamina: pitcher.stamina,
                choiceID: choice.id
            )
        case .farmReset where choice.id.hasSuffix(".accept_farm"):
            return ProDecisionModifier(
                decisionID: pending.id,
                type: pending.type,
                expiresWeek: expiresWeek,
                suppressOutings: true,
                baselineStuff: pitcher.stuff,
                baselineCommand: pitcher.command,
                baselineMovement: pitcher.movement,
                baselineStamina: pitcher.stamina,
                choiceID: choice.id
            )
        case .veteranMentor where choice.id.hasSuffix(".take_mentor"):
            return ProDecisionModifier(
                decisionID: pending.id,
                type: pending.type,
                expiresWeek: expiresWeek,
                trainingEfficiencyPermille: 800,
                baselineStuff: pitcher.stuff,
                baselineCommand: pitcher.command,
                baselineMovement: pitcher.movement,
                baselineStamina: pitcher.stamina,
                choiceID: choice.id
            )
        default:
            return nil
        }
    }

    private struct WeeklyFollowUpResolution {
        let pitcher: PitcherSnapshot
        let managerTrust: Int
        let followUp: ProDecisionFollowUp
        let newsLine: String
    }

    private func resolveWeeklyFollowUp(
        modifier: ProDecisionModifier,
        pitcher: PitcherSnapshot,
        managerTrust: Int,
        season: Int,
        week: Int
    ) -> WeeklyFollowUpResolution {
        var nextPitcher = pitcher
        var nextTrust = managerTrust
        var commandRestored: Int?
        var trustDelta: Int?
        if modifier.commandDelta != 0 {
            let restored = applying(.init(commandDelta: -modifier.commandDelta), to: nextPitcher)
            commandRestored = restored.command - nextPitcher.command
            nextPitcher = restored
        }
        if modifier.type == .farmReset, modifier.suppressOutings {
            trustDelta = 4
            nextTrust = clamp(nextTrust + 4, 0, 100)
        }
        let stuffDelta = nextPitcher.stuff - modifier.baselineStuff
        let commandDelta = nextPitcher.command - modifier.baselineCommand
        let movementDelta = nextPitcher.movement - modifier.baselineMovement
        let staminaDelta = nextPitcher.stamina - modifier.baselineStamina
        let summaryKey: String
        let newsLine: String
        switch modifier.type {
        case .rotationPush:
            summaryKey = "content.pro-decision.followup.rotation_push"
            newsLine = "결정 결과 · 등판 간격 · QS \(modifier.qualityStarts) · 실점 \(modifier.runsAllowed)"
        case .newPitchTrial:
            summaryKey = "content.pro-decision.followup.new_pitch_trial"
            newsLine = "결정 결과 · 신구종 실전 · 제구 회복 +\(commandRestored ?? 0)"
        case .farmReset:
            summaryKey = "content.pro-decision.followup.farm_reset"
            newsLine = "결정 결과 · 2군 재정비 · 복귀 · 감독의 믿음 +4"
        case .veteranMentor:
            summaryKey = "content.pro-decision.followup.veteran_mentor"
            newsLine = "결정 결과 · 베테랑 조언 · 성장 구위 \(signed(stuffDelta)) · 제구 \(signed(commandDelta)) · 변화구 \(signed(movementDelta))"
        default:
            summaryKey = "content.pro-decision.followup.rotation_push"
            newsLine = "결정 결과"
        }
        let followUp = ProDecisionFollowUp(
            decisionID: modifier.decisionID,
            type: modifier.type,
            season: season,
            week: week,
            summaryKey: summaryKey,
            qualityStarts: modifier.type == .rotationPush ? modifier.qualityStarts : nil,
            runsAllowed: modifier.type == .rotationPush ? modifier.runsAllowed : nil,
            commandRestored: commandRestored,
            managerTrustDelta: trustDelta,
            stuffDelta: modifier.type == .veteranMentor ? stuffDelta : nil,
            commandDelta: modifier.type == .veteranMentor ? commandDelta : nil,
            movementDelta: modifier.type == .veteranMentor ? movementDelta : nil,
            staminaDelta: modifier.type == .veteranMentor ? staminaDelta : nil,
            choiceID: modifier.choiceID
        )
        return WeeklyFollowUpResolution(
            pitcher: nextPitcher,
            managerTrust: nextTrust,
            followUp: followUp,
            newsLine: newsLine
        )
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    func lowMasteryPitch(in pitcher: PitcherSnapshot) -> PitchType? {
        guard let profiles = pitcher.pitchProfiles, !profiles.isEmpty else { return nil }
        let ranked = profiles.sorted {
            ($0.command + $0.movement + $0.whiff) < ($1.command + $1.movement + $1.whiff)
        }
        if let development = ranked.first(where: { $0.role == .development || $0.availability == .locked }) {
            return development.pitchType
        }
        if let secondary = ranked.first(where: { $0.role != .primary }) {
            return secondary.pitchType
        }
        return ranked.first?.pitchType
    }

    private func growPitchProfile(_ pitcher: PitcherSnapshot, pitch: PitchType, points: Int) -> PitcherSnapshot {
        guard points > 0, let profiles = pitcher.pitchProfiles else { return pitcher }
        let updated = profiles.map { profile -> PitchProfileSnapshot in
            guard profile.pitchType == pitch else { return profile }
            return PitchProfileSnapshot(
                pitchType: profile.pitchType,
                role: profile.role,
                velocityTenthsKPH: profile.velocityTenthsKPH,
                control: clamp(profile.control + points, 20, 80),
                command: clamp(profile.command + points, 20, 80),
                movement: clamp(profile.movement + points * 2, 20, 80),
                whiff: clamp(profile.whiff + points, 20, 80),
                weakContact: profile.weakContact,
                fatigueCost: profile.fatigueCost,
                availability: profile.availability
            )
        }
        return PitcherSnapshot(
            id: pitcher.id,
            name: pitcher.name,
            stuff: pitcher.stuff,
            command: pitcher.command,
            movement: pitcher.movement,
            stamina: pitcher.stamina,
            pitchProfiles: updated,
            throwingHand: pitcher.throwingHand,
            mastery: pitcher.mastery
        )
    }

    private func recentERAWorsened(state: ProCareerSnapshot, throughWeek: Int) -> Bool {
        let lines = (state.gameLines ?? []).filter { $0.season == state.season && $0.week <= throughWeek }
        let recent = lines.filter { $0.week > throughWeek - 3 }
        let previous = lines.filter { $0.week > throughWeek - 6 && $0.week <= throughWeek - 3 }
        let recentOuts = recent.reduce(0) { $0 + $1.outs }
        let previousOuts = previous.reduce(0) { $0 + $1.outs }
        guard recentOuts > 0, previousOuts > 0 else { return false }
        let recentRA9 = recent.reduce(0) { $0 + $1.runsAllowed } * 27_000 / recentOuts
        let previousRA9 = previous.reduce(0) { $0 + $1.runsAllowed } * 27_000 / previousOuts
        return recentRA9 > previousRA9
    }

    private func modifierCommitment(_ modifier: ProDecisionModifier) -> String {
        let efficiency = modifier.trainingEfficiencyPermille.map(String.init) ?? "-"
        let floor = modifier.injuryPressureFloor.map(String.init) ?? "-"
        let pitch = modifier.targetPitch?.rawValue ?? "-"
        return "\(modifier.decisionID):\(modifier.type.rawValue):\(modifier.expiresWeek):\(modifier.commandDelta):\(efficiency):\(modifier.extraOutingChance):\(modifier.extraOutingsGranted ?? 0):\(modifier.suppressOutings ? "1" : "0"):\(floor):\(pitch):\(modifier.qualityStarts):\(modifier.runsAllowed):\(modifier.choiceID)"
    }

    private func followUpCommitment(_ followUp: ProDecisionFollowUp) -> String {
        let quality = followUp.qualityStarts.map(String.init) ?? "-"
        let runs = followUp.runsAllowed.map(String.init) ?? "-"
        let restored = followUp.commandRestored.map(String.init) ?? "-"
        let trust = followUp.managerTrustDelta.map(String.init) ?? "-"
        return "\(followUp.decisionID):\(followUp.type.rawValue):\(followUp.season):\(followUp.week):\(followUp.summaryKey):\(quality):\(runs):\(restored):\(trust):\(followUp.choiceID ?? "-")"
    }

    private func journeyEffectMatchesMediaChoice(_ choice: ProSeasonDecisionChoice) -> Bool {
        switch choice.id {
        case "media_opportunity.advertising_shoot":
            return choice.effect == .init(fatigueDelta: 6)
                && choice.journeyEffect == .init(income: 30_000_000, fanDelta: 5)
        case "media_opportunity.fan_together_shoot":
            return choice.effect == .init(fatigueDelta: 4)
                && choice.journeyEffect == .init(income: 10_000_000, fanDelta: 10, communityDelta: 2)
        case "media_opportunity.focus_on_season":
            return choice.effect == .init(fatigueDelta: -4)
                && choice.journeyEffect == .init()
        default:
            return false
        }
    }

    private func mediaJourneyEffectMatches(
        choiceID: String,
        effect: ProDecisionEffect,
        journeyEffect: ProJourneyEffect?
    ) -> Bool {
        switch choiceID {
        case "media_opportunity.advertising_shoot":
            return effect == .init(fatigueDelta: 6)
                && journeyEffect == .init(income: 30_000_000, fanDelta: 5)
        case "media_opportunity.fan_together_shoot":
            return effect == .init(fatigueDelta: 4)
                && journeyEffect == .init(income: 10_000_000, fanDelta: 10, communityDelta: 2)
        case "media_opportunity.focus_on_season":
            return effect == .init(fatigueDelta: -4)
                && journeyEffect == .init()
        default:
            return false
        }
    }

    private func applying(_ effect: ProDecisionEffect, to pitcher: PitcherSnapshot) -> PitcherSnapshot {
        var value = pitcher
        if effect.stuffDelta > 0 {
            value = PitcherGrowthRules.grow(value, ability: .stuff, points: effect.stuffDelta)
        }
        if effect.commandDelta > 0 {
            value = PitcherGrowthRules.grow(value, ability: .command, points: effect.commandDelta)
        }
        if effect.movementDelta > 0 {
            value = PitcherGrowthRules.grow(value, ability: .movement, points: effect.movementDelta)
        }
        if effect.staminaDelta > 0 {
            value = PitcherGrowthRules.grow(value, ability: .stamina, points: effect.staminaDelta)
        }
        // 현재 카탈로그에는 능력 감소 선택이 없지만, 서명된 옛/향후 결정의 음수 효과도
        // 글로벌 수치에서 잃지 않도록 보존한다. 양수는 위 공용 규칙이 프로필까지 성장시킨다.
        guard effect.stuffDelta < 0 || effect.commandDelta < 0
            || effect.movementDelta < 0 || effect.staminaDelta < 0 else { return value }
        return PitcherSnapshot(
            id: value.id,
            name: value.name,
            stuff: clamp(value.stuff + min(0, effect.stuffDelta), 20, 80),
            command: clamp(value.command + min(0, effect.commandDelta), 20, 80),
            movement: clamp(value.movement + min(0, effect.movementDelta), 20, 80),
            stamina: clamp(value.stamina + min(0, effect.staminaDelta), 20, 80),
            pitchProfiles: value.pitchProfiles,
            throwingHand: value.throwingHand,
            mastery: value.mastery
        )
    }

    /// 이 아래로 내려가면 1군에서 빠진다. 콜업 기준(60)보다 한참 낮게 둔다 —
    /// 한 주 못 던졌다고 내려가면 세트백이 아니라 변덕이다.
    static let demotionTrust = 34

    public static let proTeams: [DraftTeamSnapshot] = HighSchoolCareerEngine.teams

    func validate(_ state: ProCareerSnapshot, phase: ProCareerPhase) throws {
        guard state.phase == phase else { throw SimulationError.invalidProCareer("expected \(phase.rawValue), got \(state.phase.rawValue)") }
        try validateState(state)
    }
    func validateState(_ state: ProCareerSnapshot) throws {
        let expectsPending = state.phase == .seasonDecision
        guard expectsPending == (state.pendingDecision != nil) else {
            throw SimulationError.invalidProCareer("season decision phase and pending decision must match")
        }
        if let pending = state.pendingDecision {
            guard pending.season == state.season, pending.week == state.week else {
                throw SimulationError.invalidProCareer("pending decision season or week mismatch")
            }
            let requiredChoices = pending.type.isWeeklyBinaryDecision ? 2 : 3
            guard pending.choices.count == requiredChoices,
                  Set(pending.choices.map(\.id)).count == requiredChoices else {
                throw SimulationError.invalidProCareer(
                    pending.type.isWeeklyBinaryDecision
                        ? "pending decision requires two unique choices"
                        : "pending decision requires three unique choices"
                )
            }
            try validatePendingDecisionStructure(pending)
        }
        if let history = state.decisionHistory, !history.isEmpty {
            guard Set(history.map(\.decisionID)).count == history.count else {
                throw SimulationError.invalidProCareer("decision history contains duplicate decisions")
            }
            guard history.allSatisfy({ Self.isCompatibleDecisionWeek($0.week) && !$0.choiceID.isEmpty }) else {
                throw SimulationError.invalidProCareer("decision history contains an invalid record")
            }
            guard history.allSatisfy({ record in
                if record.type == .mediaOpportunity {
                    return record.journeyEffect != nil
                        && mediaJourneyEffectMatches(
                            choiceID: record.choiceID,
                            effect: record.effect,
                            journeyEffect: record.journeyEffect
                        )
                }
                return record.journeyEffect == nil
            }) else {
                throw SimulationError.invalidProCareer("decision history journey effect is invalid")
            }
            guard history.allSatisfy({ record in
                guard let resolvedWeek = record.followUpResolvedWeek else { return true }
                return (record.week...24).contains(resolvedWeek)
            }) else {
                throw SimulationError.invalidProCareer("decision history contains an invalid follow-up week")
            }
            let counts = Dictionary(grouping: history, by: \.season).mapValues(\.count)
            guard counts.values.allSatisfy({ $0 <= Self.persistedSeasonDecisionLimit }) else {
                throw SimulationError.invalidProCareer("decision history exceeds the season limit")
            }
            let mediaRecords = history.filter { $0.type == .mediaOpportunity }
            let mediaSeasonSet = Set(mediaRecords.map(\.season))
            guard mediaRecords.allSatisfy({
                $0.week == Self.mediaOpportunityWeek(proCareerID: state.proCareerID, season: $0.season, proRulesVersion: state.proRulesVersion)
            }), mediaSeasonSet.count == mediaRecords.count else {
                throw SimulationError.invalidProCareer("media opportunity is not a fixed one-per-season slot")
            }
        }
        if let journey = state.journeyState {
            try validateJourneyState(state, journey: journey)
        }
        if let postseason = state.postseason,
           !ProPostseasonRules.isValidSeriesState(postseason) {
            throw SimulationError.invalidProCareer("postseason series state is invalid")
        }
        if let postseason = state.postseason,
           !ProPostseasonRules.isValidGameHistory(postseason) {
            throw SimulationError.invalidProCareer("postseason game history is invalid")
        }
        if let postseason = state.postseason,
           !ProPostseasonRules.isValidSeriesRivalMemory(postseason, pitcherID: state.pitcher.id) {
            throw SimulationError.invalidProCareer("postseason rival memory is invalid")
        }
        if let postseason = state.postseason,
           let decision = postseason.series?.availabilityDecision {
            guard decision == .pitchAgain,
                  ProPostseasonRules.isConsecutiveAppearanceSituation(postseason, role: state.role) else {
                throw SimulationError.invalidProCareer("postseason availability choice is invalid")
            }
        }
        do {
            try PitchLearningRules.validateState(
                pitcher: state.pitcher,
                rulesVersion: state.repertoireRulesVersion,
                project: state.pitchLearningProject
            )
        } catch {
            throw SimulationError.invalidProCareer("pro repertoire state is invalid")
        }
        guard state.commitment == commitment(state) else { throw SimulationError.invalidProCareer("state commitment mismatch") }
    }

    /// Persisted decision content is the contract the player saw. Catalog copy and tuning may
    /// evolve after a save was written, so validation checks its stable shape and signed payload
    /// rather than regenerating today's catalog and requiring byte-for-byte equality.
    private func validatePendingDecisionStructure(_ pending: ProSeasonDecision) throws {
        guard Self.isCompatibleDecisionWeek(pending.week) else {
            throw SimulationError.invalidProCareer("pending decision week is not scheduled")
        }
        let expectedID = "season-\(pending.season)-week-\(pending.week)-\(pending.type.rawValue)"
        guard pending.id == expectedID else {
            throw SimulationError.invalidProCareer("pending decision id mismatch")
        }
        guard !pending.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !pending.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SimulationError.invalidProCareer("pending decision copy is empty")
        }
        let prefix = "\(pending.type.rawValue)."
        for choice in pending.choices {
            let suffix = String(choice.id.dropFirst(prefix.count))
            guard choice.id.hasPrefix(prefix), isStableDecisionIdentifier(suffix) else {
                throw SimulationError.invalidProCareer("pending decision choice id mismatch")
            }
            guard !choice.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !choice.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SimulationError.invalidProCareer("pending decision choice copy is empty")
            }
            guard isReasonable(choice.effect) else {
                throw SimulationError.invalidProCareer("pending decision effect is out of range")
            }
        }
        if pending.type == .mediaOpportunity {
            guard pending.title == "content.pro-media-opportunity.title",
                  pending.detail == "content.pro-media-opportunity.detail",
                  pending.choices.allSatisfy({ journeyEffectMatchesMediaChoice($0) }) else {
                throw SimulationError.invalidProCareer("pending media content is not canonical")
            }
        } else {
            guard pending.choices.allSatisfy({ $0.journeyEffect == nil }) else {
                throw SimulationError.invalidProCareer("legacy decision contains a journey effect")
            }
        }
    }

    private func isStableDecisionIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { byte in
            (97...122).contains(byte) || (48...57).contains(byte) || byte == 95
        }
    }

    private func isReasonable(_ effect: ProDecisionEffect) -> Bool {
        let abilities = [
            effect.stuffDelta, effect.commandDelta, effect.movementDelta, effect.staminaDelta,
        ]
        let trust = [effect.managerTrustDelta, effect.catcherTrustDelta]
        return abilities.allSatisfy { (-4...4).contains($0) }
            && trust.allSatisfy { (-20...20).contains($0) }
            && (-30...30).contains(effect.fatigueDelta)
    }
    func generator(_ seed: String) throws -> SplitMix64 { guard let value = UInt64(seed) else { throw SimulationError.invalidSeed(seed) }; return SplitMix64(seed: value) }

    /// 주간 자동 등판 집계. 수동 중요 경기와 같은 커널이 만든 결과라 통계 분포가 연속적이다.
    struct WeeklyOutingLine {
        var outs = 0
        var strikeouts = 0
        var walks = 0
        var runsAllowed = 0
        var pitches = 0
        /// 피안타·피홈런. 삼진과 볼넷만 세면 "6이닝 2실점"이 어떻게 만들어졌는지 알 수 없다.
        var hits = 0
        var homeRuns = 0
    }

    /// 주간 자동 등판을 PitchKernelEngine 실제 타석 루프로 실행한다(투구 UI 없이 결과만 집계).
    /// 상대는 리그 평균(50) 기준 시드 변주 타자이고 좌우 타석도 섞인다. 투수의 피로는
    /// 커널의 구속·제구 저하로 그대로 반영되므로 "지친 주의 등판"은 자연히 나빠진다.
    /// 주간 자동 등판. 실제 구현은 `AutoOutingSimulator`에 있다 — 고교 자동 경기와
    /// 밸런스 CLI가 같은 것을 쓴다.
    func simulateWeeklyOuting(
        pitcher: PitcherSnapshot,
        startingFatigue: Int,
        outsTarget: Int,
        pitchCap: Int,
        batterOffset: Int = 0,
        callPolicy: AutoCallPolicy = .perfect,
        baseSeed: UInt64,
        diverseScouting: Bool = false
    ) -> WeeklyOutingLine {
        let line = AutoOutingSimulator().simulate(
            pitcher: pitcher,
            startingFatigue: startingFatigue,
            outsTarget: outsTarget,
            pitchCap: pitchCap,
            batterOffset: batterOffset,
            callPolicy: callPolicy,
            baseSeed: baseSeed,
            diverseScouting: diverseScouting
        )
        var weekly = WeeklyOutingLine()
        weekly.outs = line.outs
        weekly.strikeouts = line.strikeouts
        weekly.walks = line.walks
        weekly.runsAllowed = line.runsAllowed
        weekly.pitches = line.pitches
        weekly.hits = line.hits
        weekly.homeRuns = line.homeRuns
        return weekly
    }
    func signed(_ state: ProCareerSnapshot) -> ProCareerSnapshot { replacing(state, commitment: commitment(state)) }
    func result(
        _ state: ProCareerSnapshot,
        nextSeed: String,
        events: [String],
        injuryEvent: ProInjuryEventSnapshot? = nil
    ) -> ProCareerResult {
        let value = signed(state)
        return ProCareerResult(snapshot: value, nextSeed: nextSeed, events: events, injuryEvent: injuryEvent)
    }
    /// Internal so compatibility tests can emulate a snapshot legitimately signed by an older
    /// catalog. Production callers outside SimulationCore still cannot forge it.
    func commitment(_ s: ProCareerSnapshot) -> String {
        var values = [s.proCareerID, String(s.revision), s.phase.rawValue, s.team.id, String(s.age), String(s.season), String(s.week), s.level.rawValue, s.role.rawValue, String(s.managerTrust), String(s.fatigue), String(s.currentStats.games), String(s.currentStats.strikeouts), String(s.careerStats.count)]
        if let mastery = s.pitcher.mastery {
            values.append("mastery:\(mastery.stuff):\(mastery.command):\(mastery.movement):\(mastery.stamina)")
        }
        if let balanceVersion = s.balanceVersion { values.append("balance_version:\(balanceVersion)") }
        if let proRulesVersion = s.proRulesVersion { values.append("pro_rules_version:\(proRulesVersion)") }
        if s.currentStats.hits != 0 || s.currentStats.homeRuns != 0 || s.currentStats.pitches != 0 {
            values.append("extended_stats:\(s.currentStats.hits):\(s.currentStats.homeRuns):\(s.currentStats.pitches)")
        }
        if let progress = s.developmentProgress {
            values.append("development:\(progress.stuff):\(progress.command):\(progress.movement):\(progress.stamina)")
        }
        if let repertoireRulesVersion = s.repertoireRulesVersion,
           let project = s.pitchLearningProject {
            let ready = s.pitcher.gameReadyPitchTypes.map(\.rawValue).sorted().joined(separator: ",")
            let primary = s.pitcher.pitchProfiles?.first(where: { $0.role == .primary })?.pitchType.rawValue ?? "none"
            let profiles = PitchLearningRules.profileCommitmentToken(for: s.pitcher)
            values.append("repertoire:v\(repertoireRulesVersion):\(primary):\(ready):\(project.commitmentToken):\(profiles)")
        }
        if let rolePreference = s.rolePreference {
            values.append("role_preference:\(rolePreference.rawValue)")
        }
        // 구저장본과 아직 결정을 만나지 않은 저장본은 기존 해시를 그대로 쓴다. 결정이 실제로
        // 존재할 때만 중첩 해시를 붙여 pending/history 변조를 감지한다.
        if let pending = s.pendingDecision {
            values.append("pending_decision:\(decisionCommitment(pending))")
        }
        if let history = s.decisionHistory, !history.isEmpty {
            let records = history.map(recordCommitment).joined(separator: ",")
            values.append("decision_history:\(history.count):\(StableHash.fnv1a64(records))")
        }
        if let journey = s.journeyState {
            values.append("journey:v1:\(ProCareerJourneyRules.canonicalToken(journey))")
        }
        if let postseason = s.postseason {
            values.append("postseason:\(postseason.seed):\(postseason.currentRound?.rawValue ?? "none"):\(postseason.result.rawValue):\(postseason.gamesPlayed)")
            if let series = postseason.series {
                values.append(
                    "postseason_series:\(series.round?.rawValue ?? "none"):\(series.opponentTeamID ?? "none"):\(series.playerWinsRequired.map(String.init) ?? "none"):\(series.opponentWinsRequired.map(String.init) ?? "none"):\(series.playerWins):\(series.opponentWins):\(series.nextGameNumber):\(series.totalDirectAppearances):\(series.lastAppearancePitches.map(String.init) ?? "none"):\(series.lastAppearanceGameNumber.map(String.init) ?? "none"):\(series.availabilityDecision?.rawValue ?? "none")"
                )
                if let lines = series.gameLines {
                    let token = lines.map(postseasonGameCommitment).joined(separator: ";")
                    values.append("postseason_games:\(lines.count):\(StableHash.fnv1a64(token))")
                }
                if let memory = series.rivalMemory {
                    values.append("postseason_rival_memory:\(StableHash.fnv1a64(rivalMemoryCommitment(memory)))")
                }
            }
            if let history = postseason.gameHistory {
                let token = history.map(postseasonGameCommitment).joined(separator: ";")
                values.append("postseason_history:\(history.count):\(StableHash.fnv1a64(token))")
            }
        }
        if let modifiers = s.activeDecisionModifiers, !modifiers.isEmpty {
            let token = modifiers.map(modifierCommitment).joined(separator: ",")
            values.append("decision_modifiers:\(modifiers.count):\(StableHash.fnv1a64(token))")
        }
        if let followUps = s.resolvedFollowUps, !followUps.isEmpty {
            let token = followUps.map(followUpCommitment).joined(separator: ",")
            values.append("resolved_followups:\(followUps.count):\(StableHash.fnv1a64(token))")
        }
        if let request = s.roleRequest {
            values.append(
                "role_request:\(request.season):\(request.reviewWeek):\(request.requested.rawValue):\(request.outcome.rawValue)"
            )
        }
        return StableHash.fnv1a64(values.joined(separator: "|"))
    }

#if DEBUG
    /// Debug UI fixtures only. Release builds cannot manufacture signed career snapshots.
    public func resignFixtureForTesting(_ state: ProCareerSnapshot) -> ProCareerSnapshot {
        replacing(state, commitment: commitment(state))
    }
#endif

    private func postseasonGameCommitment(_ line: ProPostseasonGameLine) -> String {
        let values = [
            line.round?.rawValue ?? "none",
            String(line.gameNumber),
            String(line.teamRuns),
            String(line.opponentRuns),
            line.directlyPlayed ? "1" : "0",
            line.playerPitches.map(String.init) ?? "-1",
            line.playerOuts.map(String.init) ?? "-1",
            line.playerRunsAllowed.map(String.init) ?? "-1",
        ]
        return values.joined(separator: ",")
    }

    private func rivalMemoryCommitment(_ memory: RivalMemorySnapshot) -> String {
        let observations = memory.recentObservations.map { observation in
            [
                observation.pitchType.rawValue,
                String(observation.zone.row),
                String(observation.zone.column),
                observation.zoneIntent.rawValue,
                String(observation.balls),
                String(observation.strikes),
                observation.outcome.rawValue,
            ].joined(separator: ":")
        }.joined(separator: ",")
        return [
            memory.matchupID,
            String(memory.revision),
            String(memory.plateAppearancesSeen),
            String(memory.totalPitchesSeen),
            observations,
        ].joined(separator: "|")
    }

    private func decisionCommitment(_ decision: ProSeasonDecision) -> String {
        var values = [
            decision.id,
            decision.type.rawValue,
            String(decision.season),
            String(decision.week),
            decision.title,
            decision.detail,
            String(decision.choices.count),
        ]
        values.append(contentsOf: decision.choices.map(choiceCommitment))
        return StableHash.fnv1a64(values.joined(separator: "|"))
    }

    private func choiceCommitment(_ choice: ProSeasonDecisionChoice) -> String {
        var values = [
            choice.id,
            choice.title,
            choice.detail,
            effectCommitment(choice.effect),
        ]
        if let journeyEffect = choice.journeyEffect {
            values.append(journeyEffectCommitment(journeyEffect))
        }
        return StableHash.fnv1a64(values.joined(separator: "|"))
    }

    private func recordCommitment(_ record: ProDecisionRecord) -> String {
        var values = [
            record.decisionID,
            record.type.rawValue,
            String(record.season),
            String(record.week),
            record.choiceID,
            record.choiceTitle,
            effectCommitment(record.effect),
        ]
        if let journeyEffect = record.journeyEffect {
            values.append(journeyEffectCommitment(journeyEffect))
        }
        if let resolvedWeek = record.followUpResolvedWeek {
            values.append("follow_up:\(resolvedWeek)")
        }
        return StableHash.fnv1a64(values.joined(separator: "|"))
    }

    private func effectCommitment(_ effect: ProDecisionEffect) -> String {
        [
            effect.stuffDelta,
            effect.commandDelta,
            effect.movementDelta,
            effect.staminaDelta,
            effect.managerTrustDelta,
            effect.catcherTrustDelta,
            effect.fatigueDelta,
        ].map(String.init).joined(separator: ",") + "," + (effect.roleTarget?.rawValue ?? "-")
    }

    private func journeyEffectCommitment(_ effect: ProJourneyEffect) -> String {
        "journey-effect:\(effect.income):\(effect.fanDelta):\(effect.communityDelta)"
    }
    public static func hallOfFameProjection(for state: ProCareerSnapshot) -> Int {
        var seasons = state.careerStats
        let hasCurrentRow = seasons.contains { $0.season == state.currentStats.season && $0.teamID == state.currentStats.teamID }
        if !hasCurrentRow {
            seasons.append(state.currentStats)
        }
        let serviceYears = state.serviceYears
            + (!hasCurrentRow && state.level == .major && (state.currentStats.games > 0 || state.currentStats.inningsOuts > 0) ? 1 : 0)
        return hofScore(
            seasons: seasons,
            awardCount: ProCareerGoalRules.awardCount(for: state),
            serviceYears: serviceYears,
            rulesVersion: state.proRulesVersion ?? 1,
            autumnBonus: Self.usesAutumnRules(state)
                ? ProPostseasonRules.hofBonus(for: state.postseason?.result ?? .didNotQualify)
                : 0
        )
    }

    public static func hallOfFameFinalScore(for state: ProCareerSnapshot) -> Int {
        hofScore(
            seasons: state.careerStats,
            awardCount: ProCareerGoalRules.awardCount(for: state),
            serviceYears: state.serviceYears,
            rulesVersion: state.proRulesVersion ?? 1,
            autumnBonus: Self.usesAutumnRules(state)
                ? ProPostseasonRules.hofBonus(for: state.postseason?.result ?? .didNotQualify)
                : 0
        )
    }

    /// The retirement screen and the final retirement mutation share this pure projection so a
    /// preview cannot drift from the honors persisted at the retirement boundary.
    public static func retirementPreview(for state: ProCareerSnapshot) -> ProRetirementPreview {
        ProRetirementRules.preview(for: state)
    }

    private static func hofScore(
        seasons: [ProSeasonStats],
        awardCount: Int,
        serviceYears: Int,
        rulesVersion: Int,
        autumnBonus: Int = 0
    ) -> Int {
        let strikeouts = seasons.reduce(0) { $0 + $1.strikeouts }
        let outs = seasons.reduce(0) { $0 + $1.inningsOuts }
        let decisions = seasons.reduce(0) { $0 + $1.wins + $1.saves }
        let qualitySeasons = seasons.count { season in
            season.inningsOuts >= 180
                && season.runsAllowed * 27_000 / max(1, season.inningsOuts) < 4_000
        }
        guard rulesVersion >= Self.hallOfFameFormulaVersion else {
            // Frozen formula for legacy, v1, and v2 saves. Their stored commitment and
            // completed score must remain byte-compatible after the v3 balance correction.
            return min(100, max(0,
                strikeouts / 150
                    + outs / 300
                    + decisions / 12
                    + qualitySeasons * 2
                    + awardCount * 8
                    + serviceYears * 3
            ))
        }

        // v3 is a new, explicitly versioned projection for new journeys. It keeps the fixed
        // 70-point induction threshold while weighting bounded longevity, workload, quality,
        // decisions, and awards as independent semantic career evidence. Older saves stay on
        // the frozen branch above so their stored HOF results remain byte-compatible.
        let longevity = min(15, max(0, serviceYears))
        let strikeoutContribution = min(22, max(0, strikeouts) / 200)
        let workloadContribution = min(15, max(0, outs) / 600)
        let decisionContribution = min(9, max(0, decisions) / 25)
        let qualityContribution = min(10, max(0, qualitySeasons) / 2)
        let awardContribution = awardCount >= 3
            ? min(12, 2 + (awardCount - 3) / 8)
            : 0
        return min(100, max(0,
            longevity
                + strikeoutContribution
                + workloadContribution
                + decisionContribution
                + qualityContribution
                + awardContribution
                + max(0, autumnBonus)
        ))
    }

    /// The current HOF formula version is part of the rules contract. Do not change the
    /// versioned branch without adding a compatibility test for completed older saves.
    public static let hallOfFameFormulaVersion = 3

    private func hallOfFameScore(_ state: ProCareerSnapshot) -> Int {
        Self.hallOfFameFinalScore(for: state)
    }

    /// 은퇴를 한 줄 뉴스가 아니라 통산 회고 시퀀스로 만든다.
    /// 통산 합계 → 가장 빛난 시즌 → 첫 기록과 마지막 수상 → 마지막 유니폼 순서로 쌓는다.
    private func retirementRetrospective(state: ProCareerSnapshot, hallOfFameScore score: Int) -> [String] {
        var lines = [score >= 70 ? "명예의 전당 헌액이 확정됐습니다." : "은퇴식에서 선수 생활의 마지막 공을 돌아봤습니다."]
        let seasons = state.careerStats
        if !seasons.isEmpty {
            let games = seasons.reduce(0) { $0 + $1.games }
            let strikeouts = seasons.reduce(0) { $0 + $1.strikeouts }
            let outs = seasons.reduce(0) { $0 + $1.inningsOuts }
            let runs = seasons.reduce(0) { $0 + $1.runsAllowed }
            let runsPer9 = outs == 0 ? 0 : runs * 27_000 / outs
            lines.append("통산 \(seasons.count)시즌 · \(games)경기 · \(strikeouts)탈삼진 · 9이닝당 실점 \(String(format: "%.2f", Double(runsPer9) / 1_000))")
            if let best = seasons.max(by: { $0.strikeouts < $1.strikeouts }), best.strikeouts > 0 {
                lines.append("가장 빛난 해는 \(best.season)시즌 — \(best.games)경기에서 \(best.strikeouts)개의 탈삼진을 잡았습니다.")
            }
        }
        if let firstMilestone = state.milestones.first {
            let lastAward = state.awards.last.map { " · 마지막 수상: \($0)" } ?? ""
            lines.append("첫 기록: \(firstMilestone)\(lastAward)")
        }
        lines.append("마지막 공은 \(state.team.name)의 유니폼으로 던졌습니다.")
        return lines
    }
    private func addingUnique(_ value: String, to values: [String]) -> [String] { values.contains(value) ? values : values + [value] }
    private func careerGames(_ state: ProCareerSnapshot) -> Int { state.careerStats.reduce(0) { $0 + $1.games } + state.currentStats.games }
    private func careerStrikeouts(_ state: ProCareerSnapshot) -> Int { state.careerStats.reduce(0) { $0 + $1.strikeouts } + state.currentStats.strikeouts }
    // MARK: - 시즌 아크 (Phase 3-2)

    /// 24주를 6구간으로 나눈다. 순수하게 주차에서 파생된다.
    private func segment(forWeek week: Int) -> ProSeasonSegment {
        switch week {
        case ..<1: return .springCamp
        case 1...4: return .opening
        case 5...10: return .firstHalf
        case 11...13: return .allStarBreak
        case 14...20: return .pennantRace
        default: return .seasonFinale
        }
    }

    func segmentLabel(_ segment: ProSeasonSegment) -> String {
        switch segment {
        case .springCamp: return "스프링캠프"
        case .opening: return "개막"
        case .firstHalf: return "전반기"
        case .allStarBreak: return "올스타 휴식기"
        case .pennantRace: return "순위 경쟁"
        case .seasonFinale: return "시즌 결말"
        }
    }

    private func segmentEntryNews(_ segment: ProSeasonSegment) -> String {
        switch segment {
        case .springCamp: return "스프링캠프가 열렸습니다. 새 시즌 준비를 시작합니다."
        case .opening: return "개막 시리즈가 시작됐습니다. 첫인상을 남길 시간입니다."
        case .firstHalf: return "전반기 레이스에 들어섰습니다. 긴 시즌의 리듬을 잡습니다."
        case .allStarBreak: return "올스타 휴식기입니다. 몸을 추스르고 후반기를 준비합니다."
        case .pennantRace: return "순위 경쟁이 뜨거워집니다. 한 경기의 무게가 커집니다."
        case .seasonFinale: return "시즌 막바지, 마지막 순위 싸움이 남았습니다."
        }
    }

    /// 상황 트리거로 중요 경기를 판정한다. 고정 주차 대신 상태(콜업·기록·보직·순위)로 발동한다.
    /// 모든 시즌에서 최대 3회의 대표 장면을 직접 던진다. 직접 승부는 예정 등판 하나를
    /// 대체하므로 베테랑의 기록을 부풀리지 않으면서도 끝까지 같은 플레이 권한을 보장한다.
    private func importantGameTrigger(state: ProCareerSnapshot, nextWeek: Int, newLevel: ProLevel, newTrust: Int, seasonStats: ProSeasonStats, skill: Int, priorImportantGames: Int) -> ProSeasonTrigger? {
        let maximum = Self.usesAutumnRules(state)
            ? 2
            : Self.usesAgencyRules(state)
                ? Self.maximumImportantGames(for: state.season)
                : (state.season >= 9 ? 2 : 3)
        guard priorImportantGames < maximum else { return nil }
        let seg = segment(forWeek: nextWeek)
        // 1군 데뷔는 고유한 장면이지만, 시즌 마지막 한 자리는 결말 승부를 위해 남긴다.
        if state.level == .minor && newLevel == .major,
           seg == .seasonFinale || priorImportantGames < maximum - 1 {
            return .majorDebut
        }
        // 앵커 ① 개막 무대 — 개막 구간의 시즌별 흔들리는 한 주.
        if seg == .opening && nextWeek == anchorWeek(state, salt: "opening", range: 2...4) { return .openingStatement }
        // 앵커 ② 시즌 종반 순위 승부 — 시즌 결말 구간의 시즌별 흔들리는 한 주.
        // 가을은 정규 예산 밖의 별도 장면이다. 4~7위만 결말을 열면 개막 뒤에 선택이
        // 쌓여도 회수할 직접 승부가 사라지므로, 남은 정규 자리는 시즌 결말로 남긴다.
        if seg == .seasonFinale && nextWeek == anchorWeek(state, salt: "finale", range: 21...23) {
            return .standingsRace
        }
        // 남은 상황 트리거가 마지막 슬롯까지 소비하면 시즌 결말이 사라진다. 대표 장면 수를
        // 줄인 대신 시작과 끝의 리듬은 모든 시즌에서 보장한다.
        guard priorImportantGames < maximum - 1 else { return nil }
        // 상황 ③ 콜업 직전 증명 — 2군에서 콜업 임계에 접근할 때(기록 추격보다 먼저 판정해 실제로 노출되게 한다).
        if newLevel == .minor && skill >= 44 && state.managerTrust < 57 && newTrust >= 57 { return .callUpAudition }
        // 상황 ④ 기록 추격 — 지금 성장 유형이 약속한 기록을 넘어서는 주.
        switch PitcherBuildRules.identity(for: state.pitcher) {
        case .power:
            for mark in Self.seasonStrikeoutMarks
                where state.currentStats.strikeouts < mark && seasonStats.strikeouts >= mark {
                return .recordChase
            }
        case .command:
            let bb9 = seasonStats.walks * 27_000 / max(1, seasonStats.inningsOuts)
            if bb9 < 3_000, crossedOutsMark(from: state.currentStats.inningsOuts, to: seasonStats.inningsOuts) {
                return .recordChase
            }
        case .movement:
            let h9 = seasonStats.hits * 27_000 / max(1, seasonStats.inningsOuts)
            if h9 < 9_000, crossedOutsMark(from: state.currentStats.inningsOuts, to: seasonStats.inningsOuts) {
                return .recordChase
            }
        case .stamina:
            if crossedOutsMark(from: state.currentStats.inningsOuts, to: seasonStats.inningsOuts) {
                return .recordChase
            }
        }
        // 상황 ⑤ 보직 경쟁 — 1군에서 감독의 믿음이 역할 경계를 넘어설 때.
        if newLevel == .major {
            for band in [63, 75] where state.managerTrust < band && newTrust >= band { return .roleShowdown }
        }
        return nil
    }

    private func crossedOutsMark(from prior: Int, to current: Int) -> Bool {
        Self.seasonOutsMarks.contains { prior < $0 && current >= $0 }
    }

    /// 시즌 번호와 무관하게 대표 장면 세 번을 보장한다. 기록에는 같은 주의 예정 등판을
    /// 대체해 반영하므로 직접 플레이 횟수와 실제 총등판 수가 섞이지 않는다.
    static func maximumImportantGames(for season: Int) -> Int {
        // 직접 승부가 이제 예정 등판을 대체하므로 베테랑의 기록을 부풀리지 않는다. 시즌
        // 번호만으로 플레이 기회를 줄일 이유가 없고, 20시즌에도 기억할 장면 세 번을 보장한다.
        _ = season
        return 3
    }

    private func importantMomentHeadline(trigger: ProSeasonTrigger, rival: ProRivalBatter?, level: ProLevel, trust: Int, build: PitcherBuildIdentity) -> String {
        let foe = rival.map { "\($0.teamName) \($0.name)" } ?? "상대 팀 중심타자"
        switch trigger {
        case .majorDebut: return "처음으로 1군 마운드에 오릅니다. \(foe)와의 승부가 기다립니다."
        case .openingStatement: return "개막 시리즈 선발 맞대결. \(foe) 앞에서 올 시즌 첫인상을 만듭니다."
        case .callUpAudition: return "콜업이 눈앞입니다. \(foe)를 막으면 1군 문이 열립니다."
        case .recordChase:
            let objective: String = switch build {
            case .power: "탈삼진 기록"
            case .command: "볼넷 억제 기록"
            case .movement: "피안타 억제 기록"
            case .stamina: "이닝 기록"
            }
            return "\(objective)에 다가서는 등판. \(foe)를 상대로 자신의 투구를 증명합니다."
        case .roleShowdown: return "\(foe)와의 승부로 다음 역할이 갈립니다."
        case .standingsRace: return "순위가 걸린 한 경기. \(foe)를 넘어야 가을이 보입니다."
        case .autumnWildCard: return "와일드카드. \(foe)를 넘어야 준플레이오프가 열립니다."
        case .autumnSemifinal: return "준플레이오프 한 판. \(foe)와의 승부가 플레이오프를 가릅니다."
        case .autumnPlayoff: return "플레이오프 한 판. \(foe)를 넘어야 우승 결정전이 열립니다."
        case .autumnFinal: return "우승 결정전 한 판. \(foe) 앞에서 올해의 마지막 공을 던집니다."
        }
    }

    /// 시즌·salt별로 흔들리는 앵커 주차. 같은 시드는 같은 주차를, 시즌이 바뀌면 다른 주차를 준다.
    private func anchorWeek(_ state: ProCareerSnapshot, salt: String, range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        let value = hashInt("\(state.proCareerID)|season\(state.season)|\(salt)")
        return range.lowerBound + Int(value % span)
    }

    /// 중요 경기 상대 라이벌 타자를 구단·시즌·주차·트리거로 결정론 선택한다. 자기 구단 소속은 건너뛴다.
    private func rivalForGame(
        _ state: ProCareerSnapshot,
        week: Int,
        trigger: ProSeasonTrigger,
        opponentTeamID: String? = nil
    ) -> ProRivalBatter {
        let matched = opponentTeamID.map { opponentID in
            Self.rivalBatters.filter { $0.teamID == opponentID }
        } ?? []
        let pool = matched.isEmpty ? Self.rivalBatters : matched
        let value = hashInt("\(state.team.id)|season\(state.season)|week\(week)|\(trigger.rawValue)")
        var index = Int(value % UInt64(pool.count))
        if pool[index].teamID == state.team.id { index = (index + 1) % pool.count }
        return pool[index]
    }

    /// "올해의 세 가지 긴장" — 보직 경쟁·기록 목표·라이벌 맞대결을 결정론 생성한다.
    func seasonTensions(for state: ProCareerSnapshot) -> [ProSeasonTension] {
        let skill = (state.pitcher.stuff + state.pitcher.command + state.pitcher.movement + state.pitcher.stamina) / 4
        let role = ProSeasonTension(kind: "role",
            title: "\(state.team.positionCompetitor)와의 자리 싸움",
            detail: "\(roleLabel(state.role)) 한 자리를 두고 시즌 내내 성적을 견줍니다.")
        let record: ProSeasonTension
        switch PitcherBuildRules.identity(for: state.pitcher) {
        case .power:
            let goal = state.level == .major ? max(120, skill * 2) : max(80, skill * 3 / 2)
            record = ProSeasonTension(kind: "record", title: "시즌 \(goal)탈삼진",
                detail: "빠른 공으로 타자를 압도해 한 시즌 탈삼진 기록에 도전합니다.")
        case .command:
            let goal = state.level == .major ? "2.5" : "3.0"
            record = ProSeasonTension(kind: "record", title: "9이닝당 볼넷 \(goal) 이하",
                detail: "정교한 코스 승부로 불필요한 주자를 내보내지 않습니다.")
        case .movement:
            let goal = state.level == .major ? "8.5" : "9.0"
            record = ProSeasonTension(kind: "record", title: "9이닝당 피안타 \(goal) 이하",
                detail: "결정구의 변화와 약한 타구로 안타를 억제합니다.")
        case .stamina:
            let innings = state.role == .starter ? max(120, skill * 2) : max(70, skill)
            record = ProSeasonTension(kind: "record", title: "시즌 \(innings)이닝",
                detail: "후반에도 구위를 지키며 맡은 아웃카운트를 끝까지 책임집니다.")
        }
        let rival = rivalForGame(state, week: 0, trigger: .standingsRace)
        let rivalTension = ProSeasonTension(kind: "rival",
            title: "\(rival.name) 맞대결",
            detail: "\(rival.teamName)의 \(rival.archetype). 올 시즌 몇 번이고 마운드에서 마주칩니다.")
        return [role, record, rivalTension]
    }

    private func tensionHeadline(_ tensions: [ProSeasonTension]) -> String {
        "올해의 세 가지 긴장 · " + tensions.map(\.title).joined(separator: " · ")
    }

    private func roleLabel(_ role: ProRole) -> String {
        role == .starter ? "선발" : role == .longRelief ? "긴 이닝 구원" : role == .setup ? "필승조" : "마무리"
    }

    private func hashInt(_ value: String) -> UInt64 { UInt64(StableHash.fnv1a64(value), radix: 16) ?? 0 }

    private static let seasonStrikeoutMarks = [45, 85, 125]
    private static let seasonOutsMarks = [120, 240, 360]

    /// 구단별 라이벌 타자 풀. 각 라이벌은 한 프로 구단의 간판 타자이며, 중요 경기마다
    /// 상대 구단의 중심타자로 등장한다. 이름·아키타입·기록은 모두 가상이다.
    static let rivalBatters: [ProRivalBatter] = [
        .init(id: "pro-rival-seoul", name: "강도훈", archetype: "중심 타선 해결사형", teamID: "seoul_comets", teamName: "서울 코메츠",
            record: "최근 3시즌 82홈런 · OPS .901", profile: "카운트가 몰려도 스윙이 짧아지지 않습니다. 바깥쪽 승부를 기다렸다 밀어칩니다."),
        .init(id: "pro-rival-busan", name: "마태오", archetype: "우측 담장 거포형", teamID: "busan_marines", teamName: "부산 블루웨일스",
            record: "최근 3시즌 96홈런 · 장타율 .571", profile: "낮게 깔린 공을 퍼올려 우측 담장을 넘깁니다. 몸쪽 실투 한 개를 놓치지 않습니다."),
        .init(id: "pro-rival-incheon", name: "백건우", archetype: "교타 정확형", teamID: "incheon_waves", teamName: "인천 크레스트핀스",
            record: "통산 타율 .318 · 3년 연속 150안타", profile: "파울로 승부를 늘리다 결정구를 받아칩니다. 삼진보다 인플레이 타구가 많습니다."),
        .init(id: "pro-rival-daegu", name: "노진성", archetype: "당겨치는 홈런형", teamID: "daegu_forge", teamName: "대구 포지",
            record: "지난 시즌 34홈런 · 최다 장타", profile: "빠른 배트로 안쪽 공을 끌어당깁니다. 초구부터 노림수를 숨기지 않습니다."),
        .init(id: "pro-rival-daejeon", name: "천우재", archetype: "선구안 출루형", teamID: "daejeon_rockets", teamName: "대전 로켓츠",
            record: "출루율 .420 · 볼넷 최다", profile: "존을 벗어난 공에는 손이 나가지 않습니다. 풀카운트 승부를 두려워하지 않습니다."),
        .init(id: "pro-rival-gwangju", name: "서강윤", archetype: "중장거리 갭 히터형", teamID: "gwangju_phoenix", teamName: "광주 피닉스",
            record: "2루타 최다 · OPS .880", profile: "좌중간 갭을 노려 장타를 만듭니다. 변화구 타이밍에 강합니다."),
        .init(id: "pro-rival-suwon", name: "구본혁", archetype: "컨택 무결점형", teamID: "suwon_guardians", teamName: "수원 가디언즈",
            record: "5년 연속 3할·두 자릿수 홈런", profile: "약점 코스가 뚜렷하지 않습니다. 어떤 구종이든 중심에 맞힙니다."),
        .init(id: "pro-rival-changwon", name: "류성권", archetype: "장신 파워형", teamID: "changwon_meteors", teamName: "창원 미티어스",
            record: "지난 시즌 40홈런 · 장타율 .612", profile: "긴 리치로 바깥쪽까지 커버합니다. 높은 공을 그대로 받아넘깁니다."),
        .init(id: "pro-rival-jeonju", name: "문태경", archetype: "빠른 발 갭 타자형", teamID: "jeonju_hanok", teamName: "전주 한울스",
            record: "3년 연속 3할·30도루", profile: "짧게 끊어치고 곧바로 다음 베이스를 노립니다. 실투가 곧 실점입니다."),
        .init(id: "pro-rival-jeju", name: "한도결", archetype: "득점권 해결사형", teamID: "jeju_storm", teamName: "제주 스톰",
            record: "득점권 타율 .352 · 끝내기 다수", profile: "주자가 있을 때 스윙이 더 단단해집니다. 넓은 존을 커버하는 배드볼 히터입니다."),
    ]
    private struct DevelopmentResolution {
        let pitcher: PitcherSnapshot
        let progress: ProDevelopmentProgress
        let growthLabels: [String]
        let pitchLearningProject: PitchLearningProjectSnapshot?
        let pitchLearningReceipt: PitchLearningReceiptSnapshot?
    }

    private func resolveDevelopment(
        pitcher: PitcherSnapshot,
        progress: ProDevelopmentProgress,
        project: PitchLearningProjectSnapshot?,
        plan: ProWeekPlan,
        targetPitch: PitchType?,
        paused: Bool,
        proRulesVersion: Int?,
        trainingEfficiencyPermille: Int = 1_000
    ) throws -> DevelopmentResolution {
        guard !paused, plan != .recover, plan != .earnTrust else {
            return DevelopmentResolution(
                pitcher: pitcher,
                progress: progress,
                growthLabels: [],
                pitchLearningProject: project,
                pitchLearningReceipt: nil
            )
        }
        var stuff = progress.stuff
        var command = progress.command
        var movement = progress.movement
        var stamina = progress.stamina
        var value = pitcher
        var labels: [String] = []
        var learningProject = project
        var learningReceipt: PitchLearningReceiptSnapshot?
        let usesLiveTicks = (proRulesVersion ?? 1) >= 4

        func advanced(_ current: inout Int, ability: TalentAbility, focus: TrainingFocus, label: String, pitch: PitchType? = nil) {
            let currentRating: Int = switch ability {
            case .stuff: value.stuff
            case .command: value.command
            case .movement: value.movement
            case .stamina: value.stamina
            }
            let needed = usesLiveTicks ? Self.developmentTicksRequired(for: currentRating) : 2
            let efficiency = min(1_000, max(1, trainingEfficiencyPermille))
            let scaledNeeded = efficiency >= 1_000
                ? needed
                : max(needed, (needed * 1_000 + efficiency - 1) / efficiency)
            current += 1
            if current >= scaledNeeded {
                current = 0
                let receipt = PitcherGrowthRules.advance(
                    value,
                    focus: focus,
                    points: 1,
                    targetPitch: pitch
                )
                value = receipt.pitcher
                if receipt.baseDelta > 0 {
                    labels.append("\(label) +\(receipt.baseDelta)")
                }
                if receipt.masteryDelta > 0 {
                    labels.append(
                        "\(MasteryEffectRules.displayName(for: ability)) Lv.\(receipt.masteryAfter)"
                    )
                }
            }
        }

        switch plan {
        case .developStuff:
            advanced(&stuff, ability: .stuff, focus: .velocity, label: "구위")
        case .refineCommand:
            advanced(&command, ability: .command, focus: .command, label: "제구")
        case .developMovement:
            advanced(&movement, ability: .movement, focus: .breakingBall, label: "변화구", pitch: targetPitch)
        case .buildStamina:
            advanced(&stamina, ability: .stamina, focus: .stamina, label: "체력")
        case .developWeapon:
            // 옛 단일 "무기 개발" 선택은 기존 의미를 잃지 않되 새 게이지 규칙을 따른다.
            advanced(&stuff, ability: .stuff, focus: .velocity, label: "구위")
            advanced(&movement, ability: .movement, focus: .breakingBall, label: "변화구", pitch: targetPitch)
        case .recover, .earnTrust:
            break
        }
        if plan == .developMovement,
           let current = learningProject,
           !current.isCompleted,
           targetPitch == current.pitchType {
            let learning = try PitchLearningRules.advancing(
                pitcher: value,
                project: current,
                practiceCredits: 2
            )
            value = learning.pitcher
            learningProject = learning.project
            learningReceipt = learning.receipt
        }
        return DevelopmentResolution(
            pitcher: value,
            progress: ProDevelopmentProgress(
                stuff: stuff,
                command: command,
                movement: movement,
                stamina: stamina
            ),
            growthLabels: labels,
            pitchLearningProject: learningProject,
            pitchLearningReceipt: learningReceipt
        )
    }
    func clamp(_ value: Int, _ low: Int, _ high: Int) -> Int { min(high, max(low, value)) }

    func replacing(_ s: ProCareerSnapshot, revision: UInt64? = nil, phase: ProCareerPhase? = nil, pitcher: PitcherSnapshot? = nil, team: DraftTeamSnapshot? = nil, age: Int? = nil, season: Int? = nil, week: Int? = nil, level: ProLevel? = nil, role: ProRole? = nil, rolePreference: ProRole?? = nil, managerTrust: Int? = nil, catcherTrust: Int? = nil, fatigue: Int? = nil, injuryWeeks: Int? = nil, serviceYears: Int? = nil, militaryCompleted: Bool? = nil, contract: ProContractSnapshot?? = nil, currentStats: ProSeasonStats? = nil, gameLines: [ProGameLine]? = nil, careerStats: [ProSeasonStats]? = nil, awards: [String]? = nil, milestones: [String]? = nil, news: [String]? = nil, hallOfFameScore: Int?? = nil, balanceVersion: Int? = nil, proRulesVersion: Int? = nil, commitment: String? = nil, seasonSegment: ProSeasonSegment? = nil, seasonTrigger: ProSeasonTrigger?? = nil, currentRival: ProRivalBatter?? = nil, seasonTensions: [ProSeasonTension]?? = nil, seasonImportantGames: Int? = nil, pendingDecision: ProSeasonDecision?? = nil, decisionHistory: [ProDecisionRecord]?? = nil, developmentProgress: ProDevelopmentProgress? = nil, repertoireRulesVersion: Int?? = nil, pitchLearningProject: PitchLearningProjectSnapshot?? = nil, journeyState: ProCareerJourneyState?? = nil, postseason: ProPostseasonState?? = nil, activeDecisionModifiers: [ProDecisionModifier]?? = nil, resolvedFollowUps: [ProDecisionFollowUp]?? = nil, roleRequest: ProRoleRequestState?? = nil) -> ProCareerSnapshot {
        ProCareerSnapshot(proCareerID: s.proCareerID, revision: revision ?? s.revision, phase: phase ?? s.phase, identity: s.identity, pitcher: pitcher ?? s.pitcher, team: team ?? s.team, entitlement: s.entitlement, age: age ?? s.age, season: season ?? s.season, week: week ?? s.week, level: level ?? s.level, role: role ?? s.role, rolePreference: rolePreference ?? s.rolePreference, managerTrust: managerTrust ?? s.managerTrust, catcherTrust: catcherTrust ?? s.catcherTrust, fatigue: fatigue ?? s.fatigue, injuryWeeks: injuryWeeks ?? s.injuryWeeks, serviceYears: serviceYears ?? s.serviceYears, militaryCompleted: militaryCompleted ?? s.militaryCompleted, contract: contract ?? s.contract, currentStats: currentStats ?? s.currentStats, gameLines: gameLines ?? s.gameLines, careerStats: careerStats ?? s.careerStats, awards: awards ?? s.awards, milestones: milestones ?? s.milestones, news: news ?? s.news, hallOfFameScore: hallOfFameScore ?? s.hallOfFameScore, commitment: commitment ?? "", balanceVersion: balanceVersion ?? s.balanceVersion, proRulesVersion: proRulesVersion ?? s.proRulesVersion, seasonSegment: seasonSegment ?? s.seasonSegment, seasonTrigger: seasonTrigger ?? s.seasonTrigger, currentRival: currentRival ?? s.currentRival, seasonTensions: seasonTensions ?? s.seasonTensions, seasonImportantGames: seasonImportantGames ?? s.seasonImportantGames, pendingDecision: pendingDecision ?? s.pendingDecision, decisionHistory: decisionHistory ?? s.decisionHistory, developmentProgress: developmentProgress ?? s.developmentProgress, repertoireRulesVersion: repertoireRulesVersion ?? s.repertoireRulesVersion, pitchLearningProject: pitchLearningProject ?? s.pitchLearningProject, journeyState: journeyState ?? s.journeyState, postseason: postseason ?? s.postseason, activeDecisionModifiers: activeDecisionModifiers ?? s.activeDecisionModifiers, resolvedFollowUps: resolvedFollowUps ?? s.resolvedFollowUps, roleRequest: roleRequest ?? s.roleRequest)
    }
}
