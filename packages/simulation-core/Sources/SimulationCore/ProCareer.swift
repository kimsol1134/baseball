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
        let base = ProCareerSnapshot(proCareerID: id, revision: 0, phase: .contractOffer, identity: params.identity, pitcher: params.pitcher, team: team, entitlement: params.entitlement, age: 19, season: 1, week: 0, level: .minor, role: .starter, managerTrust: 42, catcherTrust: 45, fatigue: 0, injuryWeeks: 0, serviceYears: 0, militaryCompleted: false, contract: nil, currentStats: stats, careerStats: [], awards: [], milestones: ["프로 지명"], news: ["신인 계약 제안 · \(team.name) · \(params.identity.name)"], hallOfFameScore: nil, commitment: "", balanceVersion: PitcherPresetCatalog.balanceVersion, proRulesVersion: Self.currentRulesVersion, seasonSegment: .springCamp, seasonImportantGames: 0, decisionHistory: [], journeyState: journeyState)
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
        var rng = try generator(params.seed)
        let state = params.state
        let nextWeek = state.week + 1
        let recovering = state.injuryWeeks > 0
        let skill = (state.pitcher.stuff + state.pitcher.command + state.pitcher.movement + state.pitcher.stamina) / 4
        // 주간 자동 등판을 수동 중요 경기와 같은 커널로 실행한다(3줄 산식 폐기).
        let usesAgencyRules = (state.proRulesVersion ?? 1) >= Self.currentRulesVersion
        let restingWeek = recovering || (!usesAgencyRules && params.plan == .recover)
        let outings: Int
        let outsTargetPerOuting: Int
        let pitchCapPerOuting: Int
        switch state.role {
        case .starter: outings = 1; outsTargetPerOuting = 18; pitchCapPerOuting = 96
        case .longRelief: outings = 2; outsTargetPerOuting = 6; pitchCapPerOuting = 42
        case .setup, .closer: outings = 3; outsTargetPerOuting = 3; pitchCapPerOuting = 24
        }
        var weekLine = WeeklyOutingLine()
        var newGameLines: [ProGameLine] = []
        if !restingWeek {
            for outingIndex in 0..<outings {
                let outingLine = simulateWeeklyOuting(
                    pitcher: state.pitcher,
                    startingFatigue: state.fatigue + outingIndex * 5,
                    outsTarget: outsTargetPerOuting,
                    pitchCap: pitchCapPerOuting,
                    baseSeed: rng.next() ^ UInt64(bitPattern: Int64(nextWeek &* 0x9E37)) &+ UInt64(outingIndex)
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
        let starts = restingWeek ? 0 : (state.role == .starter ? 1 : 0)
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
        let fatiguePressure = PitchAbilityRules.effectiveFatigue(
            rawFatigue: fatigue,
            stamina: state.pitcher.stamina
        )
        let generatedInjury = !recovering && injuryRoll < max(2, fatiguePressure - 72)
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
        let trustGain = recovering ? -1
            : params.plan == .earnTrust ? 5
            : params.plan == .recover ? 0
            : performanceTrust
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
        let development = resolveDevelopment(
            pitcher: state.pitcher,
            progress: state.developmentProgress ?? .init(),
            plan: params.plan,
            targetPitch: params.targetPitch,
            paused: recovering
        )
        let pitcher = development.pitcher
        let callUpGame = state.level != level && level == .major
        let priorImportantGames = state.seasonImportantGames ?? 0
        // 직접 승부는 그 주의 예정 등판 하나를 대표한다. 회복·부상으로 실제 등판이
        // 하나도 없는 주에 승부처를 열면 resolve 단계에서 별도 보너스 경기가 생긴다.
        let trigger: ProSeasonTrigger? = nextWeek >= 24 || newGameLines.isEmpty ? nil
            : importantGameTrigger(state: state, nextWeek: nextWeek, newLevel: level, newTrust: trust, seasonStats: stats, skill: skill, priorImportantGames: priorImportantGames)
        let decisionsThisSeason = (state.decisionHistory ?? []).count { $0.season == state.season }
        // 중요 경기와 부상은 화면상 더 급한 사건이다. 해당 주의 갈림길은 뒤로 미루거나
        // 중복 노출하지 않고 건너뛴다. 시즌의 세 막에서 한 번씩만 멈춰, 선택이 체크리스트가
        // 아니라 그 시즌을 기억하게 하는 갈림길로 남게 한다.
        let shouldOpenDecision = nextWeek < 24
            && (usesAgencyRules || (state.balanceVersion ?? 1) >= 4)
            && Self.seasonDecisionWeeks.contains(nextWeek)
            && trigger == nil
            && !recovering
            && newInjury == 0
            && decisionsThisSeason < Self.maximumSeasonDecisions
        let pendingDecision: ProSeasonDecision? = shouldOpenDecision
            ? seasonDecision(for: state, week: nextWeek)
            : nil
        let phase: ProCareerPhase = nextWeek >= 24 ? .seasonReview
            : trigger != nil ? .importantGame
            : pendingDecision != nil ? .seasonDecision
            : .weeklyPlan
        let rival: ProRivalBatter? = trigger.map { rivalForGame(state, week: nextWeek, trigger: $0) }
        let importantGames = priorImportantGames + (phase == .importantGame ? 1 : 0)
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
        for mark in [50, 100, 300] where priorGames < mark && nextGames >= mark {
            milestones = addingUnique("프로 통산 \(mark)경기", to: milestones)
        }
        for mark in [50, 100, 200, 500] where priorStrikeouts < mark && nextStrikeouts >= mark {
            milestones = addingUnique("프로 통산 \(mark)탈삼진", to: milestones)
        }
        if newInjury > 0 && state.injuryWeeks == 0 { news.insert("과부하로 \(newInjury)주 부상자 명단에 올랐습니다.", at: 0) }
        if !development.growthLabels.isEmpty {
            news.insert("주간 성장 완성 · \(development.growthLabels.joined(separator: " · "))", at: 0)
        }
        if nextSegment != priorSegment { news.insert(segmentEntryNews(nextSegment), at: 0) }
        if phase == .importantGame, let trigger {
            news.insert(importantMomentHeadline(
                trigger: trigger,
                rival: rival,
                level: level,
                trust: trust,
                build: PitcherBuildRules.identity(for: pitcher)
            ), at: 0)
        }
        let journeyStateAfterInjury: ProCareerJourneyState?? = injuryMitigationConsumed
            ? .some(replacingJourney(
                state.journeyState!,
                activeSeasonBenefit: .some(nil)
            ))
            : nil
        let updated = replacing(state, revision: state.revision + 1, phase: phase, pitcher: pitcher, week: nextWeek, level: level, role: role, managerTrust: trust, fatigue: fatigue, injuryWeeks: newInjury, currentStats: stats, gameLines: (state.gameLines ?? []) + newGameLines, milestones: milestones, news: Array(news.prefix(30)), seasonSegment: nextSegment, seasonTrigger: trigger, currentRival: rival, seasonTensions: seasonTensionsValue, seasonImportantGames: importantGames, pendingDecision: pendingDecision, developmentProgress: development.progress, journeyState: journeyStateAfterInjury)
        var events = ["pro_week_resolved", callUpGame ? "major_call_up" : "weekly_progress"]
        if phase == .seasonDecision { events.append("pro_season_decision_opened") }
        return result(updated, nextSeed: String(rng.next()), events: events)
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
                  pending.week == Self.mediaOpportunityWeek(proCareerID: state.proCareerID, season: state.season),
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
        let rolePreference = pending.type == .roleMeeting
            ? (effect.roleTarget ?? state.role)
            : state.rolePreference
        let record = ProDecisionRecord(
            decisionID: pending.id,
            type: pending.type,
            season: pending.season,
            week: pending.week,
            choiceID: choice.id,
            choiceTitle: choice.title,
            effect: effect,
            journeyEffect: journeyEffect
        )
        let mediaChoiceToken = choice.id.split(separator: ".").last.map(String.init) ?? "choice"
        let summary = pending.type == .mediaOpportunity
            ? "content.pro-media-opportunity.resolved.\(mediaChoiceToken)"
            : "\(pending.title) · \(choice.title) — \(effect.summary)"
        let clearedDecision: ProSeasonDecision? = nil
        let updated = replacing(
            state,
            revision: state.revision + 1,
            phase: .weeklyPlan,
            pitcher: pitcher,
            role: role,
            rolePreference: rolePreference,
            managerTrust: managerTrust,
            catcherTrust: catcherTrust,
            fatigue: fatigue,
            news: Array(([summary] + state.news).prefix(30)),
            pendingDecision: clearedDecision,
            decisionHistory: (state.decisionHistory ?? []) + [record],
            journeyState: nextJourney.map { .some($0) }
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
        var rng = try generator(params.seed)
        let report = params.report
        let soundProcess = report.actualDamage <= report.expectedDamage + 150 || report.recommendationAccepted * 2 >= report.pitches
        let usesAgencyRules = (params.state.proRulesVersion ?? 1) >= Self.currentRulesVersion
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
            return value * complementOuts / scheduledOuts
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
        let foe = params.state.currentRival.map { "\($0.name)(\($0.teamName)) 상대 · " } ?? ""
        let news = ["승부처 등판 · \(foe)\(report.strikeouts)탈삼진 · \(report.walks)볼넷 · \(report.runsAllowed)실점 · 감독의 믿음 \(trustDelta >= 0 ? "+" : "")\(trustDelta). \(evaluation)\(masteryEvaluation)\(followUpEvaluation)"] + params.state.news
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
        let updated = replacing(params.state, revision: params.state.revision + 1, phase: .weeklyPlan, managerTrust: trust, catcherTrust: clamp(params.state.catcherTrust + (soundProcess ? 2 : -1) + sequenceTrustReward, 0, 100), currentStats: stats, gameLines: gameLines, milestones: milestones, news: Array(news.prefix(30)), seasonTrigger: clearedTrigger, currentRival: clearedRival, decisionHistory: resolvedHistory)
        return result(updated, nextSeed: String(rng.next()), events: ["pro_important_game_resolved"])
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
        if state.currentStats.strikeouts >= 120 { awards = addingUnique("시즌 \(state.season) 탈삼진상", to: awards) }
        if runsPer9Permille < 3_000 && state.currentStats.games >= 20 { awards = addingUnique("시즌 \(state.season) 최소 실점상", to: awards) }
        let walksPer9Permille = state.currentStats.inningsOuts == 0
            ? 9_990 : state.currentStats.walks * 27_000 / state.currentStats.inningsOuts
        let hitsPer9Permille = state.currentStats.inningsOuts == 0
            ? 9_990 : state.currentStats.hits * 27_000 / state.currentStats.inningsOuts
        if walksPer9Permille < 2_500, state.currentStats.inningsOuts >= 180 {
            awards = addingUnique("시즌 \(state.season) 정밀 제구상", to: awards)
        }
        if hitsPer9Permille < 8_500, state.currentStats.inningsOuts >= 180 {
            awards = addingUnique("시즌 \(state.season) 피안타 억제상", to: awards)
        }
        if state.currentStats.inningsOuts >= 360 {
            awards = addingUnique("시즌 \(state.season) 이닝 책임상", to: awards)
        }
        milestones = addingUnique("\(state.season)시즌 완주", to: milestones)
        let phase: ProCareerPhase = state.season >= Self.maximumCareerSeasons
            ? .retirementDecision : .offseasonDecision
        let news = ["시즌 \(state.season) 종료 · \(state.currentStats.games)경기 · \(state.currentStats.strikeouts)K · 9이닝당 실점 \(String(format: "%.2f", Double(runsPer9Permille) / 1000))"] + state.news
        let updated = replacing(state, revision: state.revision + 1, phase: phase, careerStats: state.careerStats + [state.currentStats], awards: awards, milestones: milestones, news: Array(news.prefix(30)))
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
        let decline = age >= 33 ? 1 : 0
        let pitcher = decline == 0 ? state.pitcher : PitcherSnapshot(id: state.pitcher.id, name: state.pitcher.name, stuff: clamp(state.pitcher.stuff - decline, 20, 80), command: state.pitcher.command, movement: clamp(state.pitcher.movement - decline, 20, 80), stamina: clamp(state.pitcher.stamina - decline, 20, 80), pitchProfiles: state.pitcher.pitchProfiles, throwingHand: state.pitcher.throwingHand)
        let contract = ProContractSnapshot(yearsRemaining: max(1, (state.contract?.yearsRemaining ?? 1) - 1), annualSalary: max(state.contract?.annualSalary ?? 40_000_000, 40_000_000 + service * 50_000_000), rolePromise: state.role)
        let clearedDecision: ProSeasonDecision? = nil
        let clearedRolePreference: ProRole? = nil
        let baseAdvanced = replacing(state, revision: state.revision + 1, phase: .weeklyPlan, pitcher: pitcher, team: team, age: age, season: season, week: 0, rolePreference: clearedRolePreference, fatigue: 0, injuryWeeks: 0, serviceYears: service, militaryCompleted: military, contract: contract, currentStats: ProSeasonStats(season: season, teamID: team.id),
            // 새 시즌은 빈 기록으로 시작한다. 안 비우면 20시즌 구원 투수가 천 행 넘게 들고
            // 다니고 등판 번호도 시즌을 넘어 계속 늘어난다. 지난 시즌은 careerStats가 맡는다.
            gameLines: [],
            news: Array(news.prefix(30)), proRulesVersion: Self.currentRulesVersion, pendingDecision: clearedDecision)
        let tensions = seasonTensions(for: baseAdvanced)
        let clearedRival: ProRivalBatter? = nil
        let clearedTrigger: ProSeasonTrigger? = nil
        let updated = replacing(baseAdvanced, news: Array(([tensionHeadline(tensions)] + baseAdvanced.news).prefix(30)), seasonSegment: .springCamp, seasonTrigger: clearedTrigger, currentRival: clearedRival, seasonTensions: tensions, seasonImportantGames: 0)
        return result(updated, nextSeed: String(rng.next()), events: ["pro_offseason_resolved"])
    }

    /// 모든 진입 경로가 같은 상한을 쓰게 공개한다. 나이는 강제 은퇴 조건이 아니다 — 군 복무나
    /// 늦은 전성기를 선택해도 플레이어가 원하면 정확히 20시즌을 완주할 수 있다.
    public static let maximumCareerSeasons = 20
    public static let currentRulesVersion = 3

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
            switch ProTeamCareerRecordRules.tier(record: record) {
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
    public static let seasonDecisionWeeks = [6, 13, 20]
    public static let maximumSeasonDecisions = 3

    public static func mediaOpportunityWeek(proCareerID: String, season: Int) -> Int {
        let hash = UInt64(StableHash.fnv1a64("\(proCareerID)|\(season)|media"), radix: 16) ?? 0
        return seasonDecisionWeeks[Int(hash % UInt64(seasonDecisionWeeks.count))]
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
    func seasonDecision(for state: ProCareerSnapshot, week: Int) -> ProSeasonDecision? {
        guard let slot = Self.seasonDecisionWeeks.firstIndex(of: week) else { return nil }
        let mediaSlot = Self.mediaOpportunityWeek(proCareerID: state.proCareerID, season: state.season)
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
        let content = decisionContent(type)
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

    private func decisionContent(_ type: ProSeasonDecisionType) -> (title: String, detail: String, choices: [ProSeasonDecisionChoice]) {
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
            throwingHand: value.throwingHand
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
            guard pending.choices.count == 3,
                  Set(pending.choices.map(\.id)).count == 3 else {
                throw SimulationError.invalidProCareer("pending decision requires three unique choices")
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
                $0.week == Self.mediaOpportunityWeek(proCareerID: state.proCareerID, season: $0.season)
            }), mediaSeasonSet.count == mediaRecords.count else {
                throw SimulationError.invalidProCareer("media opportunity is not a fixed one-per-season slot")
            }
        }
        if let journey = state.journeyState {
            try validateJourneyState(state, journey: journey)
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
        baseSeed: UInt64
    ) -> WeeklyOutingLine {
        let line = AutoOutingSimulator().simulate(
            pitcher: pitcher,
            startingFatigue: startingFatigue,
            outsTarget: outsTarget,
            pitchCap: pitchCap,
            baseSeed: baseSeed
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
    func result(_ state: ProCareerSnapshot, nextSeed: String, events: [String]) -> ProCareerResult { let value = signed(state); return ProCareerResult(snapshot: value, nextSeed: nextSeed, events: events) }
    /// Internal so compatibility tests can emulate a snapshot legitimately signed by an older
    /// catalog. Production callers outside SimulationCore still cannot forge it.
    func commitment(_ s: ProCareerSnapshot) -> String {
        var values = [s.proCareerID, String(s.revision), s.phase.rawValue, s.team.id, String(s.age), String(s.season), String(s.week), s.level.rawValue, s.role.rawValue, String(s.managerTrust), String(s.fatigue), String(s.currentStats.games), String(s.currentStats.strikeouts), String(s.careerStats.count)]
        if let balanceVersion = s.balanceVersion { values.append("balance_version:\(balanceVersion)") }
        if let proRulesVersion = s.proRulesVersion { values.append("pro_rules_version:\(proRulesVersion)") }
        if s.currentStats.hits != 0 || s.currentStats.homeRuns != 0 || s.currentStats.pitches != 0 {
            values.append("extended_stats:\(s.currentStats.hits):\(s.currentStats.homeRuns):\(s.currentStats.pitches)")
        }
        if let progress = s.developmentProgress {
            values.append("development:\(progress.stuff):\(progress.command):\(progress.movement):\(progress.stamina)")
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
        return StableHash.fnv1a64(values.joined(separator: "|"))
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
            rulesVersion: state.proRulesVersion ?? 1
        )
    }

    public static func hallOfFameFinalScore(for state: ProCareerSnapshot) -> Int {
        hofScore(
            seasons: state.careerStats,
            awardCount: ProCareerGoalRules.awardCount(for: state),
            serviceYears: state.serviceYears,
            rulesVersion: state.proRulesVersion ?? 1
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
        rulesVersion: Int
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
        let maximum = (state.proRulesVersion ?? 1) >= Self.currentRulesVersion
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
        if seg == .seasonFinale && nextWeek == anchorWeek(state, salt: "finale", range: 21...23) { return .standingsRace }
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
        }
    }

    /// 시즌·salt별로 흔들리는 앵커 주차. 같은 시드는 같은 주차를, 시즌이 바뀌면 다른 주차를 준다.
    private func anchorWeek(_ state: ProCareerSnapshot, salt: String, range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        let value = hashInt("\(state.proCareerID)|season\(state.season)|\(salt)")
        return range.lowerBound + Int(value % span)
    }

    /// 중요 경기 상대 라이벌 타자를 구단·시즌·주차·트리거로 결정론 선택한다. 자기 구단 소속은 건너뛴다.
    private func rivalForGame(_ state: ProCareerSnapshot, week: Int, trigger: ProSeasonTrigger) -> ProRivalBatter {
        let pool = Self.rivalBatters
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
    }

    private func resolveDevelopment(
        pitcher: PitcherSnapshot,
        progress: ProDevelopmentProgress,
        plan: ProWeekPlan,
        targetPitch: PitchType?,
        paused: Bool
    ) -> DevelopmentResolution {
        guard !paused, plan != .recover, plan != .earnTrust else {
            return DevelopmentResolution(pitcher: pitcher, progress: progress, growthLabels: [])
        }
        var stuff = progress.stuff
        var command = progress.command
        var movement = progress.movement
        var stamina = progress.stamina
        var value = pitcher
        var labels: [String] = []

        func advanced(_ current: inout Int, focus: TrainingFocus, label: String, pitch: PitchType? = nil) {
            if current == 0 {
                current = 1
            } else {
                current = 0
                value = PitcherGrowthRules.grow(
                    value,
                    focus: focus,
                    points: 1,
                    targetPitch: pitch
                )
                labels.append("\(label) +1")
            }
        }

        switch plan {
        case .developStuff:
            advanced(&stuff, focus: .velocity, label: "구위")
        case .refineCommand:
            advanced(&command, focus: .command, label: "제구")
        case .developMovement:
            advanced(&movement, focus: .breakingBall, label: "변화구", pitch: targetPitch)
        case .buildStamina:
            advanced(&stamina, focus: .stamina, label: "체력")
        case .developWeapon:
            // 옛 단일 "무기 개발" 선택은 기존 의미를 잃지 않되 새 게이지 규칙을 따른다.
            advanced(&stuff, focus: .velocity, label: "구위")
            advanced(&movement, focus: .breakingBall, label: "변화구", pitch: targetPitch)
        case .recover, .earnTrust:
            break
        }
        return DevelopmentResolution(
            pitcher: value,
            progress: ProDevelopmentProgress(
                stuff: stuff,
                command: command,
                movement: movement,
                stamina: stamina
            ),
            growthLabels: labels
        )
    }
    func clamp(_ value: Int, _ low: Int, _ high: Int) -> Int { min(high, max(low, value)) }

    func replacing(_ s: ProCareerSnapshot, revision: UInt64? = nil, phase: ProCareerPhase? = nil, pitcher: PitcherSnapshot? = nil, team: DraftTeamSnapshot? = nil, age: Int? = nil, season: Int? = nil, week: Int? = nil, level: ProLevel? = nil, role: ProRole? = nil, rolePreference: ProRole?? = nil, managerTrust: Int? = nil, catcherTrust: Int? = nil, fatigue: Int? = nil, injuryWeeks: Int? = nil, serviceYears: Int? = nil, militaryCompleted: Bool? = nil, contract: ProContractSnapshot?? = nil, currentStats: ProSeasonStats? = nil, gameLines: [ProGameLine]? = nil, careerStats: [ProSeasonStats]? = nil, awards: [String]? = nil, milestones: [String]? = nil, news: [String]? = nil, hallOfFameScore: Int?? = nil, balanceVersion: Int? = nil, proRulesVersion: Int? = nil, commitment: String? = nil, seasonSegment: ProSeasonSegment? = nil, seasonTrigger: ProSeasonTrigger?? = nil, currentRival: ProRivalBatter?? = nil, seasonTensions: [ProSeasonTension]?? = nil, seasonImportantGames: Int? = nil, pendingDecision: ProSeasonDecision?? = nil, decisionHistory: [ProDecisionRecord]?? = nil, developmentProgress: ProDevelopmentProgress? = nil, journeyState: ProCareerJourneyState?? = nil) -> ProCareerSnapshot {
        ProCareerSnapshot(proCareerID: s.proCareerID, revision: revision ?? s.revision, phase: phase ?? s.phase, identity: s.identity, pitcher: pitcher ?? s.pitcher, team: team ?? s.team, entitlement: s.entitlement, age: age ?? s.age, season: season ?? s.season, week: week ?? s.week, level: level ?? s.level, role: role ?? s.role, rolePreference: rolePreference ?? s.rolePreference, managerTrust: managerTrust ?? s.managerTrust, catcherTrust: catcherTrust ?? s.catcherTrust, fatigue: fatigue ?? s.fatigue, injuryWeeks: injuryWeeks ?? s.injuryWeeks, serviceYears: serviceYears ?? s.serviceYears, militaryCompleted: militaryCompleted ?? s.militaryCompleted, contract: contract ?? s.contract, currentStats: currentStats ?? s.currentStats, gameLines: gameLines ?? s.gameLines, careerStats: careerStats ?? s.careerStats, awards: awards ?? s.awards, milestones: milestones ?? s.milestones, news: news ?? s.news, hallOfFameScore: hallOfFameScore ?? s.hallOfFameScore, commitment: commitment ?? "", balanceVersion: balanceVersion ?? s.balanceVersion, proRulesVersion: proRulesVersion ?? s.proRulesVersion, seasonSegment: seasonSegment ?? s.seasonSegment, seasonTrigger: seasonTrigger ?? s.seasonTrigger, currentRival: currentRival ?? s.currentRival, seasonTensions: seasonTensions ?? s.seasonTensions, seasonImportantGames: seasonImportantGames ?? s.seasonImportantGames, pendingDecision: pendingDecision ?? s.pendingDecision, decisionHistory: decisionHistory ?? s.decisionHistory, developmentProgress: developmentProgress ?? s.developmentProgress, journeyState: journeyState ?? s.journeyState)
    }
}
