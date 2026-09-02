import Foundation

public enum ProContractMarketRules {
    public struct SalaryBand: Equatable, Sendable {
        public let minimum: Int
        public let maximum: Int

        public init(minimum: Int, maximum: Int) {
            self.minimum = minimum
            self.maximum = maximum
        }
    }

    public static func rookieAnnualSalary(forDraftRound draftRound: Int) -> Int? {
        guard draftRound >= 1 else { return nil }
        switch draftRound {
        case 1: return 80_000_000
        case 2: return 60_000_000
        case 3: return 50_000_000
        default: return 40_000_000
        }
    }

    // MARK: Market score

    /// The rating weighting is shared with the draft evaluation: stuff and command carry
    /// three parts each, movement and stamina carry two parts each. It is deliberately integer
    /// only so the same snapshot has the same market value on every locale and platform.
    public static func weightedRating(for pitcher: PitcherSnapshot) -> Int {
        (pitcher.stuff * 3 + pitcher.command * 3 + pitcher.movement * 2 + pitcher.stamina * 2) / 10
    }

    public static func weightedRating(
        stuff: Int,
        command: Int,
        movement: Int,
        stamina: Int
    ) -> Int {
        (stuff * 3 + command * 3 + movement * 2 + stamina * 2) / 10
    }

    public static func marketScore(state: ProCareerSnapshot) -> Int {
        guard let journey = state.journeyState else { return 0 }
        let effectiveAge = state.age + (journey.offseasonTransition?.ageAdvanceYears ?? 0)
        let projectedPitcher = projectedPitcher(for: state.pitcher, effectiveAge: effectiveAge)
        let latestStats = latestStats(state)
        let recentExpired = journey.contractHistory
            .filter { $0.endReason == .expired }
            .max {
                ($0.endedSeason ?? $0.signedSeason, $0.contractID)
                    < ($1.endedSeason ?? $1.signedSeason, $1.contractID)
        }
        return marketScore(
            weightedRating: weightedRating(for: projectedPitcher),
            currentStats: latestStats,
            standing: ProCareerEngine.careerStanding(for: state),
            age: effectiveAge,
            fanSupport: journey.reputation.fanSupport,
            expiredContract: recentExpired
        )
    }

    public static func marketScore(
        pitcher: PitcherSnapshot,
        currentStats: ProSeasonStats,
        standing: ProCareerStanding,
        age: Int,
        fanSupport: Int,
        expiredContract: ProContractRecord? = nil
    ) -> Int {
        marketScore(
            weightedRating: weightedRating(for: pitcher),
            currentStats: currentStats,
            standing: standing,
            age: age,
            fanSupport: fanSupport,
            expiredContract: expiredContract
        )
    }

    public static func marketScore(
        weightedRating: Int,
        currentStats: ProSeasonStats,
        standing: ProCareerStanding,
        age: Int,
        fanSupport: Int,
        expiredContract: ProContractRecord? = nil
    ) -> Int {
        let ratingScore = clamp((weightedRating - 35) * 2, 0, 100)
        let ra9Score: Int
        if currentStats.inningsOuts < 60 {
            ra9Score = 50
        } else {
            let ra9 = safeRate(
                numerator: currentStats.runsAllowed,
                multiplier: 27_000,
                denominator: currentStats.inningsOuts,
                fallback: 9_990
            )
            ra9Score = clamp((6_000 - ra9) / 40, 0, 100)
        }
        let workloadScore = clamp(safeProduct(currentStats.inningsOuts, 100) / 360, 0, 100)
        let commandNumerator = max(0, currentStats.strikeouts - currentStats.walks)
        let commandScore = clamp(
            safeProduct(commandNumerator, 100) / max(1, currentStats.strikeouts),
            0,
            100
        )
        let seasonPerformance = (ra9Score * 45 + workloadScore * 30 + commandScore * 25) / 100
        let standingScore: Int = switch standing {
        case .prospect: 20
        case .roster: 40
        case .established: 60
        case .ace: 80
        case .clubSymbol: 90
        }
        let ageScore = age <= 30 ? 100 : max(40, 100 - max(0, age - 30) * 8)
        let base = (
            ratingScore * 35
                + seasonPerformance * 30
                + standingScore * 15
                + ageScore * 10
                + clamp(fanSupport, 0, 100) * 10
        ) / 100

        let expectationAdjustment: Int
        if let expiredContract, expiredContract.expectation != nil,
           !expiredContract.coveredSeasons.isEmpty {
            let fulfilled = Set(expiredContract.fulfilledExpectationSeasons).count
            let covered = Set(expiredContract.coveredSeasons).count
            let rate = fulfilled * 100 / max(1, covered)
            expectationAdjustment = rate >= 75 ? 5 : rate >= 50 ? 0 : -3
        } else {
            expectationAdjustment = 0
        }
        return clamp(base + expectationAdjustment, 0, 100)
    }

    // MARK: Expectations and roles

    public static func buildExpectation(
        level: ProLevel,
        role: ProRole,
        previousStats: ProSeasonStats?,
        contractKind: ProContractKind? = nil,
        outlook: ProTeamOutlook = .balanced
    ) -> ProContractExpectation {
        let previous = previousStats
        var kind: ProContractExpectationKind
        var target: Int
        if level == .minor {
            kind = .majorRoster
            target = 1
        } else {
            switch role {
            case .starter:
                kind = .innings
                target = clamp(max(240, scaled(previous?.inningsOuts ?? 0, percent: 90)), 240, 420)
            case .longRelief:
                kind = .innings
                target = clamp(max(120, scaled(previous?.inningsOuts ?? 0, percent: 90)), 120, 240)
            case .setup:
                kind = .strikeouts
                target = clamp(max(35, scaled(previous?.strikeouts ?? 0, percent: 90)), 35, 80)
            case .closer:
                kind = .saves
                target = clamp(max(12, scaled(previous?.saves ?? 0, percent: 90)), 12, 30)
            }
        }

        if outlook == .contender, (previous?.inningsOuts ?? 0) >= 60 {
            kind = .runPrevention
            let priorRA9 = safeRate(
                numerator: previous?.runsAllowed ?? 0,
                multiplier: 27_000,
                denominator: previous?.inningsOuts ?? 0,
                fallback: 5_000
            )
            target = clamp(priorRA9, 3_500, 5_000)
        }

        let isAccessible = contractKind == .renewalLong
            || outlook == .opportunity
        let difficulty: ProExpectationDifficulty
        if contractKind == .proveIt || outlook == .contender {
            difficulty = .stretch
        } else if isAccessible {
            difficulty = .accessible
        } else {
            difficulty = .standard
        }

        if kind == .runPrevention {
            switch difficulty {
            case .stretch: target = clamp(safeProduct(target, 90) / 100, 3_500, 5_000)
            case .accessible: target = clamp(safeProduct(target, 110) / 100, 3_500, 5_000)
            case .standard: break
            }
        } else {
            let bounds = countingBounds(for: kind, role: role)
            switch difficulty {
            case .stretch: target = safeProduct(target, 110) / 100
            case .accessible: target = safeProduct(target, 90) / 100
            case .standard: break
            }
            // The role-specific table is the final clamp. Applying it after the
            // difficulty modifier keeps accessible/stretch offers inside the
            // documented starter/long-relief/setup/closer ranges.
            target = clamp(target, bounds.minimum, bounds.maximum)
        }
        return ProContractExpectation(kind: kind, target: target, difficulty: difficulty)
    }

    public static func expectation(
        level: ProLevel,
        role: ProRole,
        previousStats: ProSeasonStats?,
        contractKind: ProContractKind? = nil,
        outlook: ProTeamOutlook = .balanced
    ) -> ProContractExpectation {
        buildExpectation(
            level: level,
            role: role,
            previousStats: previousStats,
            contractKind: contractKind,
            outlook: outlook
        )
    }

    public static func actual(
        expectation: ProContractExpectation,
        state: ProCareerSnapshot
    ) -> Int? {
        actual(expectation: expectation, stats: state.currentStats, level: state.level)
    }

    public static func actual(
        expectation: ProContractExpectation,
        stats: ProSeasonStats,
        level: ProLevel
    ) -> Int? {
        switch expectation.kind {
        case .majorRoster:
            return level == .major ? 1 : 0
        case .innings:
            return stats.inningsOuts
        case .strikeouts:
            return stats.strikeouts
        case .saves:
            return stats.saves
        case .runPrevention:
            guard stats.inningsOuts >= 60 else { return nil }
            return safeRate(
                numerator: stats.runsAllowed,
                multiplier: 27_000,
                denominator: stats.inningsOuts,
                fallback: Int.max
            )
        }
    }

    public static func met(expectation: ProContractExpectation, actual: Int?) -> Bool {
        guard let actual else { return false }
        switch expectation.kind {
        case .runPrevention: return actual <= expectation.target
        case .majorRoster, .innings, .strikeouts, .saves: return actual >= expectation.target
        }
    }

    public static func expectationMet(_ expectation: ProContractExpectation, actual: Int?) -> Bool {
        met(expectation: expectation, actual: actual)
    }

    public static func lowerRole(for current: ProRole) -> ProRole {
        switch current {
        case .starter: .longRelief
        case .longRelief: .longRelief
        case .setup: .longRelief
        case .closer: .setup
        }
    }

    public static func higherRole(for current: ProRole, pitcher: PitcherSnapshot) -> ProRole {
        switch current {
        case .starter: return .starter
        case .longRelief:
            let stuffMovementAverage = (pitcher.stuff + pitcher.movement) / 2
            return pitcher.stamina >= 55 && stuffMovementAverage >= 55 ? .starter : .setup
        case .setup: return .closer
        case .closer: return .closer
        }
    }

    /// Explicit role matrix. It never relies on the declaration order of `ProRole`.
    public static func roleValue(current: ProRole, promised: ProRole) -> Int {
        if current == promised { return 1 }
        switch (current, promised) {
        case (.longRelief, .starter), (.longRelief, .setup), (.setup, .closer): return 2
        case (.starter, .longRelief), (.setup, .longRelief), (.closer, .setup): return 0
        default: return 0
        }
    }

    public static func roleValue(currentRole: ProRole, promisedRole: ProRole) -> Int {
        roleValue(current: currentRole, promised: promisedRole)
    }

    // MARK: Salary bands

    public static func salaryBand(for marketScore: Int) -> SalaryBand {
        switch clamp(marketScore, 0, 100) {
        case 0...39: return SalaryBand(minimum: 40_000_000, maximum: 90_000_000)
        case 40...54: return SalaryBand(minimum: 100_000_000, maximum: 240_000_000)
        case 55...69: return SalaryBand(minimum: 250_000_000, maximum: 500_000_000)
        case 70...84: return SalaryBand(minimum: 550_000_000, maximum: 900_000_000)
        default: return SalaryBand(minimum: 950_000_000, maximum: 1_400_000_000)
        }
    }

    public static func roundToNearestTenMillion(_ value: Int64) -> Int64 {
        guard value > 0 else { return 0 }
        let adjusted = value > Int64.max - 5_000_000 ? Int64.max : value + 5_000_000
        return adjusted / 10_000_000 * 10_000_000
    }

    public static func annualSalary(
        marketScore: Int,
        marketID: String,
        teamID: String,
        contractKind: ProContractKind,
        multiplierNumerator: Int = 100,
        multiplierDenominator: Int = 100
    ) -> Int {
        let band = salaryBand(for: marketScore)
        let stepCount = (band.maximum - band.minimum) / 10_000_000
        let hash = StableHash.fnv1a64Value("\(marketID)|\(teamID)|\(contractKind.rawValue)")
        let base = Int64(band.minimum) + Int64(hash % UInt64(stepCount + 1)) * 10_000_000
        return salary(fromBase: base, multiplierNumerator: multiplierNumerator, multiplierDenominator: multiplierDenominator)
    }

    /// Collision-safe fallback salary. This is intentionally not a second market hash: the
    /// selected salary band's maximum is the only base permitted here, followed by the
    /// documented canonical multiplier and the same integer rounding/global clamp as regular
    /// offers.
    public static func canonicalFallbackSalary(
        marketScore: Int,
        multiplierNumerator: Int,
        multiplierDenominator: Int = 100
    ) -> Int {
        salary(
            fromBase: Int64(salaryBand(for: marketScore).maximum),
            multiplierNumerator: multiplierNumerator,
            multiplierDenominator: multiplierDenominator
        )
    }

    private static func salary(
        fromBase base: Int64,
        multiplierNumerator: Int,
        multiplierDenominator: Int
    ) -> Int {
        let numerator = Int64(max(0, multiplierNumerator))
        let denominator = Int64(max(1, multiplierDenominator))
        let product: Int64
        if numerator == 0 || base == 0 {
            product = 0
        } else if base > Int64.max / numerator {
            product = Int64.max
        } else {
            product = base * numerator
        }
        let adjusted = product / denominator
        let rounded = roundToNearestTenMillion(adjusted)
        return Int(clamping: min(Int64(1_500_000_000), max(Int64(30_000_000), rounded)))
    }

    public static func salary(
        marketScore: Int,
        marketID: String,
        teamID: String,
        contractKind: ProContractKind,
        multiplierNumerator: Int,
        multiplierDenominator: Int = 100
    ) -> Int {
        annualSalary(
            marketScore: marketScore,
            marketID: marketID,
            teamID: teamID,
            contractKind: contractKind,
            multiplierNumerator: multiplierNumerator,
            multiplierDenominator: multiplierDenominator
        )
    }

    // MARK: Persisted markets

    public static func renewalMarket(state: ProCareerSnapshot) -> ProContractMarket? {
        guard let journey = state.journeyState,
              state.contract?.yearsRemaining == 0,
              state.season < ProCareerEngine.maximumCareerSeasons else { return nil }
        let forSeason = state.season + 1
        return makeRenewalMarket(
            careerID: state.proCareerID,
            team: state.team,
            pitcher: projectedPitcher(
                for: state.pitcher,
                effectiveAge: state.age + (journey.offseasonTransition?.ageAdvanceYears ?? 0)
            ),
            level: state.level,
            role: state.role,
            previousStats: latestStats(state),
            marketScore: marketScore(state: state),
            forSeason: forSeason,
            generatedAtRevision: state.revision,
            maximumCareerSeasons: ProCareerEngine.maximumCareerSeasons,
            currentContract: journey.contractHistory
                .filter { $0.endReason == .expired }
                .max { ($0.endedSeason ?? 0, $0.contractID) < ($1.endedSeason ?? 0, $1.contractID) },
            usesContractDepth: ProCareerEngine.usesContractDepthRules(state),
            lastTeamLegacy: lastTeamLegacy(for: state)
        )
    }

    public static func freeAgencyMarket(state: ProCareerSnapshot) -> ProContractMarket? {
        guard state.journeyState != nil,
              state.contract?.yearsRemaining == 0,
              state.serviceYears >= 6,
              state.season < ProCareerEngine.maximumCareerSeasons else { return nil }
        let forSeason = state.season + 1
        return makeFreeAgencyMarket(
            careerID: state.proCareerID,
            currentTeam: state.team,
            pitcher: projectedPitcher(
                for: state.pitcher,
                effectiveAge: state.age + (state.journeyState?.offseasonTransition?.ageAdvanceYears ?? 0)
            ),
            level: state.level,
            role: state.role,
            previousStats: latestStats(state),
            marketScore: marketScore(state: state),
            fanSupport: state.journeyState?.reputation.fanSupport ?? 0,
            forSeason: forSeason,
            generatedAtRevision: state.revision,
            maximumCareerSeasons: ProCareerEngine.maximumCareerSeasons,
            currentContract: state.journeyState?.contractHistory
                .filter { $0.endReason == .expired }
                .max { ($0.endedSeason ?? 0, $0.contractID) < ($1.endedSeason ?? 0, $1.contractID) },
            usesContractDepth: ProCareerEngine.usesContractDepthRules(state),
            lastTeamLegacy: lastTeamLegacy(for: state)
        )
    }

    public static func makeRenewalMarket(
        careerID: String,
        team: DraftTeamSnapshot,
        pitcher: PitcherSnapshot,
        level: ProLevel,
        role: ProRole,
        previousStats: ProSeasonStats,
        marketScore: Int,
        forSeason: Int,
        generatedAtRevision: UInt64,
        maximumCareerSeasons: Int,
        currentContract: ProContractRecord? = nil,
        usesContractDepth: Bool = false,
        lastTeamLegacy: Int = 0
    ) -> ProContractMarket? {
        let marketID = marketID(careerID: careerID, season: forSeason, kind: .renewal)
        guard cappedYears(1, forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) != nil else { return nil }
        let longYearChoices = renewalLongYearChoices(
            usesContractDepth: usesContractDepth,
            lastTeamLegacy: lastTeamLegacy
        )
        let maxLongYears = longYearChoices.max() ?? 4

        func buildMarket(longYears: Int, canonicalSalary: Bool) -> ProContractMarket {
            let longExpectation = buildExpectation(level: level, role: role, previousStats: previousStats, contractKind: .renewalLong, outlook: .balanced)
            let proveExpectation = buildExpectation(level: level, role: role, previousStats: previousStats, contractKind: .proveIt, outlook: .opportunity)
            let longSalary = canonicalSalary
                ? canonicalFallbackSalary(marketScore: marketScore, multiplierNumerator: 90)
                : annualSalary(marketScore: marketScore, marketID: marketID, teamID: team.id, contractKind: .renewalLong, multiplierNumerator: 90)
            let proveSalary = canonicalSalary
                ? canonicalFallbackSalary(marketScore: marketScore, multiplierNumerator: 110)
                : annualSalary(marketScore: marketScore, marketID: marketID, teamID: team.id, contractKind: .proveIt, multiplierNumerator: 110)
            let longOffer = offer(
                marketID: marketID,
                teamID: team.id,
                years: longYears,
                annualSalary: longSalary,
                contractKind: .renewalLong,
                role: role,
                outlook: .balanced,
                expectation: longExpectation,
                preservesTeamLegacy: true
            )
            let proveOffer = offer(
                marketID: marketID,
                teamID: team.id,
                years: cappedYears(1, forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) ?? 1,
                annualSalary: proveSalary,
                contractKind: .proveIt,
                role: role,
                outlook: .opportunity,
                expectation: proveExpectation,
                preservesTeamLegacy: true
            )
            return ProContractMarket(
                id: marketID,
                kind: .renewal,
                forSeason: forSeason,
                generatedAtRevision: generatedAtRevision,
                offers: [longOffer, proveOffer]
            )
        }

        for attempt in 0...7 {
            guard let longYears = cappedYears(
                choose(longYearChoices, key: "renewal-long-years", marketID: marketID, teamID: team.id, attempt: attempt),
                forSeason: forSeason,
                maximumCareerSeasons: maximumCareerSeasons
            ), cappedYears(1, forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) != nil else { continue }
            let market = buildMarket(longYears: longYears, canonicalSalary: false)
            if isValid(
                market: market,
                currentTeamID: team.id,
                currentRole: role,
                maximumCareerSeasons: maximumCareerSeasons,
                marketScore: marketScore,
                pitcher: pitcher,
                usesContractDepth: usesContractDepth,
                lastTeamLegacy: lastTeamLegacy
            ) {
                return market
            }
        }

        // All regular renewal years have now been exhausted. The canonical fallback deliberately
        // changes only the salary base; it keeps the documented years, roles, outlooks,
        // difficulties, IDs, and the post-cap duration semantics intact.
        let regularLongYears = Array(Set(longYearChoices.compactMap {
            cappedYears($0, forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons)
        })).sorted()
        for longYears in regularLongYears {
            let market = buildMarket(longYears: longYears, canonicalSalary: false)
            if isValid(
                market: market,
                currentTeamID: team.id,
                currentRole: role,
                maximumCareerSeasons: maximumCareerSeasons,
                marketScore: marketScore,
                pitcher: pitcher,
                usesContractDepth: usesContractDepth,
                lastTeamLegacy: lastTeamLegacy
            ) {
                return market
            }
        }

        guard let fallbackLongYears = cappedYears(maxLongYears, forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) else { return nil }
        let fallback = buildMarket(longYears: fallbackLongYears, canonicalSalary: true)
        return isValid(
            market: fallback,
            currentTeamID: team.id,
            currentRole: role,
            maximumCareerSeasons: maximumCareerSeasons,
            marketScore: marketScore,
            pitcher: pitcher,
            usesContractDepth: usesContractDepth,
            lastTeamLegacy: lastTeamLegacy
        ) ? fallback : nil
    }

    public static func makeFreeAgencyMarket(
        careerID: String,
        currentTeam: DraftTeamSnapshot,
        pitcher: PitcherSnapshot,
        level: ProLevel,
        role: ProRole,
        previousStats: ProSeasonStats,
        marketScore: Int,
        fanSupport: Int,
        forSeason: Int,
        generatedAtRevision: UInt64,
        maximumCareerSeasons: Int,
        currentContract: ProContractRecord? = nil,
        usesContractDepth: Bool = false,
        lastTeamLegacy: Int = 0
    ) -> ProContractMarket? {
        if usesContractDepth {
            return makeFreeAgencyMarketWithDepth(
                careerID: careerID,
                currentTeam: currentTeam,
                pitcher: pitcher,
                level: level,
                role: role,
                previousStats: previousStats,
                marketScore: marketScore,
                fanSupport: fanSupport,
                forSeason: forSeason,
                generatedAtRevision: generatedAtRevision,
                maximumCareerSeasons: maximumCareerSeasons,
                lastTeamLegacy: lastTeamLegacy
            )
        }
        let marketID = marketID(careerID: careerID, season: forSeason, kind: .freeAgency)
        let currentExpectation = buildExpectation(level: level, role: role, previousStats: previousStats, contractKind: .freeAgent, outlook: .balanced)
        guard let externalSlots = assignedExternalTeams(currentTeam: currentTeam, marketID: marketID) else { return nil }
        let challengeTeam = externalSlots.challenge
        let opportunityTeam = externalSlots.opportunity
        func buildMarket(
            attempt: Int,
            canonical: Bool = false,
            yearsOverride: (stay: Int, challenge: Int, opportunity: Int)? = nil,
            multipliersOverride: (stay: Int, challenge: Int, opportunity: Int)? = nil
        ) -> ProContractMarket {
            let stayYears = cappedYears(yearsOverride?.stay ?? (canonical ? 4 : choose([3, 4], key: "free-agent-stay-years", marketID: marketID, teamID: currentTeam.id, attempt: attempt)), forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) ?? 1
            let challengeYears = cappedYears(yearsOverride?.challenge ?? (canonical ? 2 : choose([2, 3], key: "free-agent-challenge-years", marketID: marketID, teamID: challengeTeam.id, attempt: attempt)), forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) ?? 1
            let opportunityYears = cappedYears(yearsOverride?.opportunity ?? (canonical ? 1 : choose([1, 2], key: "free-agent-opportunity-years", marketID: marketID, teamID: opportunityTeam.id, attempt: attempt)), forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) ?? 1
            let challengeRole = lowerRole(for: role)
            let opportunityRole = higherRole(for: role, pitcher: pitcher)
            let challengeExpectationBase = buildExpectation(level: level, role: challengeRole, previousStats: previousStats, contractKind: .freeAgent, outlook: .contender)
            let stayMultiplier = multipliersOverride?.stay ?? (canonical ? 100 : choose([90, 95, 100], key: "free-agent-stay-multiplier", marketID: marketID, teamID: currentTeam.id, attempt: attempt))
            let challengeMultiplier = multipliersOverride?.challenge ?? (canonical ? 115 : choose([105, 110, 115], key: "free-agent-challenge-multiplier", marketID: marketID, teamID: challengeTeam.id, attempt: attempt))
            let opportunityMultiplier = multipliersOverride?.opportunity ?? (canonical ? 85 : choose([80, 85, 90, 95], key: "free-agent-opportunity-multiplier", marketID: marketID, teamID: opportunityTeam.id, attempt: attempt))
            let salary: (String, Int) -> Int = { teamID, multiplier in
                canonical
                    ? canonicalFallbackSalary(marketScore: marketScore, multiplierNumerator: multiplier)
                    : annualSalary(marketScore: marketScore, marketID: marketID, teamID: teamID, contractKind: .freeAgent, multiplierNumerator: multiplier)
            }
            let staySalary = salary(currentTeam.id, stayMultiplier)
            let challengeSalary = salary(challengeTeam.id, challengeMultiplier)
            let opportunitySalary = salary(opportunityTeam.id, opportunityMultiplier)
            return ProContractMarket(
                id: marketID,
                kind: .freeAgency,
                forSeason: forSeason,
                generatedAtRevision: generatedAtRevision,
                offers: [
                    offer(marketID: marketID, teamID: currentTeam.id, years: stayYears, annualSalary: staySalary, contractKind: .freeAgent, role: role, outlook: .balanced, expectation: currentExpectation, preservesTeamLegacy: true),
                    offer(marketID: marketID, teamID: challengeTeam.id, years: challengeYears, annualSalary: challengeSalary, contractKind: .freeAgent, role: challengeRole, outlook: .contender, expectation: challengeExpectationBase, preservesTeamLegacy: false),
                    offer(marketID: marketID, teamID: opportunityTeam.id, years: opportunityYears, annualSalary: opportunitySalary, contractKind: .freeAgent, role: opportunityRole, outlook: .opportunity, expectation: buildExpectation(level: level, role: opportunityRole, previousStats: previousStats, contractKind: .freeAgent, outlook: .opportunity), preservesTeamLegacy: false),
                ]
            )
        }
        for attempt in 0...7 {
            let market = buildMarket(attempt: attempt)
            if isValid(market: market, currentTeamID: currentTeam.id, currentRole: role, maximumCareerSeasons: maximumCareerSeasons, marketScore: marketScore, pitcher: pitcher) {
                return market
            }
        }
        // A band can make the preferred hash picks collapse onto one dominant salary. The
        // documented ranges are still integer-only; exhaust the finite range before refusing to
        // persist a market, including after the late-career duration cap.
        let stayYearChoices = Array(Set([3, 4].compactMap { cappedYears($0, forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) })).sorted()
        let challengeYearChoices = Array(Set([2, 3].compactMap { cappedYears($0, forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) })).sorted()
        let opportunityYearChoices = Array(Set([1, 2].compactMap { cappedYears($0, forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) })).sorted()
        for stayYears in stayYearChoices {
            for challengeYears in challengeYearChoices {
                for opportunityYears in opportunityYearChoices {
                    for stayMultiplier in [90, 95, 100] {
                        for challengeMultiplier in [105, 110, 115] {
                            for opportunityMultiplier in [80, 85, 90, 95] {
                                let market = buildMarket(
                                    attempt: 0,
                                    yearsOverride: (stay: stayYears, challenge: challengeYears, opportunity: opportunityYears),
                                    multipliersOverride: (stay: stayMultiplier, challenge: challengeMultiplier, opportunity: opportunityMultiplier)
                                )
                                if isValid(market: market, currentTeamID: currentTeam.id, currentRole: role, maximumCareerSeasons: maximumCareerSeasons, marketScore: marketScore, pitcher: pitcher) {
                                    return market
                                }
                            }
                        }
                    }
                }
            }
        }
        // The finite regular duration/multiplier range is exhausted. Canonical fallback is a
        // complete tuple with the shared band-maximum base and fixed documented multipliers;
        // it is not an arbitrary salary repair.
        let fallback = buildMarket(attempt: 0, canonical: true)
        if isValid(market: fallback, currentTeamID: currentTeam.id, currentRole: role, maximumCareerSeasons: maximumCareerSeasons, marketScore: marketScore, pitcher: pitcher) {
            return fallback
        }
        return nil
    }

    public static func isValid(
        market: ProContractMarket,
        currentTeamID: String,
        currentRole: ProRole,
        maximumCareerSeasons: Int = 20,
        marketScore: Int? = nil,
        pitcher: PitcherSnapshot? = nil,
        usesContractDepth: Bool = false,
        lastTeamLegacy: Int = 0
    ) -> Bool {
        let remainingSeasons = maximumCareerSeasons - market.forSeason + 1
        let marketSuffix = ":\(market.forSeason):\(market.kind.rawValue)"
        let marketIdentity = market.id.hasPrefix("market:") && market.id.hasSuffix(marketSuffix)
            ? String(market.id.dropFirst("market:".count).dropLast(marketSuffix.count))
            : ""
        let maxYears = usesContractDepth ? 5 : 4
        let allowFASigningBonus = usesContractDepth && market.kind == .freeAgency
        guard !market.id.isEmpty,
              !marketIdentity.isEmpty,
              !marketIdentity.contains("::"),
              market.forSeason >= 1,
              market.forSeason <= maximumCareerSeasons,
              remainingSeasons >= 1,
              !market.offers.isEmpty,
              Set(market.offers.map(\.id)).count == market.offers.count,
              market.offers.allSatisfy({ offer in
                  (1...maxYears).contains(offer.years)
                      && offer.years <= maximumCareerSeasons - market.forSeason + 1
                      && offer.annualSalary >= 30_000_000
                      && offer.annualSalary <= 1_500_000_000
                      && offer.annualSalary % 10_000_000 == 0
                      && !offer.teamID.isEmpty
                      && offer.id == "offer:\(market.id):\(offer.teamID):\(offer.contractKind.rawValue)"
                      && (allowFASigningBonus
                          ? signingBonusIsValid(
                              offer.signingBonus,
                              annualSalary: offer.annualSalary,
                              relaxedPercent: market.counterOffer?.applied == true
                                  && market.counterOffer?.kind == .raiseSalary
                                  && offer.preservesTeamLegacy
                          )
                          : offer.signingBonus == nil)
                      && offer.expectation.target >= 1
                      && (usesContractDepth || offer.interest == nil)
              }) else { return false }
        if let marketScore {
            guard (0...100).contains(marketScore) else { return false }
        }
        if market.kind == .renewal {
            guard market.offers.count == 2,
                  market.offers[0].contractKind == .renewalLong,
                  market.offers[1].contractKind == .proveIt,
                  let long = market.offers.first,
                  let prove = market.offers.last,
                  long.teamID == currentTeamID,
                  prove.teamID == currentTeamID,
                  long.preservesTeamLegacy,
                  prove.preservesTeamLegacy,
                  long.rolePromise == currentRole,
                  prove.rolePromise == currentRole,
                  long.outlook == .balanced,
                  prove.outlook == .opportunity,
                  long.expectation.difficulty == .accessible,
                  prove.expectation.difficulty == .stretch,
                  long.years >= min(3, remainingSeasons),
                  long.years <= min(renewalLongYearChoices(usesContractDepth: usesContractDepth, lastTeamLegacy: lastTeamLegacy).max() ?? 4, remainingSeasons),
                  prove.years == 1 else { return false }
            if let marketScore {
                let regularLongSalary = annualSalary(
                    marketScore: marketScore,
                    marketID: market.id,
                    teamID: currentTeamID,
                    contractKind: .renewalLong,
                    multiplierNumerator: 90
                )
                let regularProveSalary = annualSalary(
                    marketScore: marketScore,
                    marketID: market.id,
                    teamID: currentTeamID,
                    contractKind: .proveIt,
                    multiplierNumerator: 110
                )
                let canonicalLongSalary = canonicalFallbackSalary(marketScore: marketScore, multiplierNumerator: 90)
                let canonicalProveSalary = canonicalFallbackSalary(marketScore: marketScore, multiplierNumerator: 110)
                let regularTuple = long.annualSalary == regularLongSalary && prove.annualSalary == regularProveSalary
                let canonicalTuple = long.years == min(renewalLongYearChoices(usesContractDepth: usesContractDepth, lastTeamLegacy: lastTeamLegacy).max() ?? 4, remainingSeasons)
                    && prove.years == 1
                    && long.annualSalary == canonicalLongSalary
                    && prove.annualSalary == canonicalProveSalary
                guard canonicalTuple || regularTuple else { return false }
            }
        } else if market.kind == .freeAgency {
            if usesContractDepth {
                guard isValidFreeAgencyDepth(
                    market: market,
                    currentTeamID: currentTeamID,
                    currentRole: currentRole,
                    remainingSeasons: remainingSeasons,
                    marketScore: marketScore,
                    pitcher: pitcher,
                    lastTeamLegacy: lastTeamLegacy
                ) else { return false }
            } else {
                guard market.offers.count == 3,
                      market.offers.allSatisfy({ $0.contractKind == .freeAgent }),
                      market.offers[0].teamID == currentTeamID,
                      market.offers[0].outlook == .balanced,
                      market.offers[1].outlook == .contender,
                      market.offers[2].outlook == .opportunity,
                      let stay = market.offers.first,
                      let challenge = market.offers.dropFirst().first,
                      let opportunity = market.offers.last,
                      Set(market.offers.map(\.teamID)).count == 3,
                      stay.preservesTeamLegacy,
                      !challenge.preservesTeamLegacy,
                      !opportunity.preservesTeamLegacy,
                      challenge.teamID != currentTeamID,
                      opportunity.teamID != currentTeamID,
                      challenge.teamID != opportunity.teamID,
                      challenge.rolePromise == lowerRole(for: currentRole),
                      opportunityRoleIsValid(opportunity.rolePromise, currentRole: currentRole, pitcher: pitcher),
                      stay.expectation.difficulty == .standard,
                      challenge.expectation.difficulty == .stretch,
                      opportunity.expectation.difficulty == .accessible,
                      stay.years >= min(3, remainingSeasons),
                      stay.years <= min(4, remainingSeasons),
                      challenge.years >= min(2, remainingSeasons),
                      challenge.years <= min(3, remainingSeasons),
                      opportunity.years >= 1,
                      opportunity.years <= min(2, remainingSeasons) else { return false }

                guard let currentTeam = ProCareerEngine.proTeams.first(where: { $0.id == currentTeamID }),
                      let slots = assignedExternalTeams(currentTeam: currentTeam, marketID: market.id),
                      challenge.teamID == slots.challenge.id,
                      opportunity.teamID == slots.opportunity.id else { return false }

                if let marketScore {
                    let regularStaySalaries = [90, 95, 100].map {
                        annualSalary(marketScore: marketScore, marketID: market.id, teamID: stay.teamID, contractKind: .freeAgent, multiplierNumerator: $0)
                    }
                    let regularChallengeSalaries = [105, 110, 115].map {
                        annualSalary(marketScore: marketScore, marketID: market.id, teamID: challenge.teamID, contractKind: .freeAgent, multiplierNumerator: $0)
                    }
                    let regularOpportunitySalaries = [80, 85, 90, 95].map {
                        annualSalary(marketScore: marketScore, marketID: market.id, teamID: opportunity.teamID, contractKind: .freeAgent, multiplierNumerator: $0)
                    }
                    let regularTuple = regularStaySalaries.contains(stay.annualSalary)
                        && regularChallengeSalaries.contains(challenge.annualSalary)
                        && regularOpportunitySalaries.contains(opportunity.annualSalary)
                    let canonicalTuple = stay.years == min(4, remainingSeasons)
                        && challenge.years == min(2, remainingSeasons)
                        && opportunity.years == 1
                        && stay.annualSalary == canonicalFallbackSalary(marketScore: marketScore, multiplierNumerator: 100)
                        && challenge.annualSalary == canonicalFallbackSalary(marketScore: marketScore, multiplierNumerator: 115)
                        && opportunity.annualSalary == canonicalFallbackSalary(marketScore: marketScore, multiplierNumerator: 85)
                    guard canonicalTuple || regularTuple else { return false }
                }
            }
        } else {
            return false
        }
        return nonDominated(market.offers, currentRole: currentRole, usesContractDepth: usesContractDepth)
    }

    public static func isNonDominated(_ offers: [ProContractOffer], currentRole: ProRole, usesContractDepth: Bool = false) -> Bool {
        nonDominated(offers, currentRole: currentRole, usesContractDepth: usesContractDepth)
    }

    private static func opportunityRoleIsValid(
        _ role: ProRole,
        currentRole: ProRole,
        pitcher: PitcherSnapshot?
    ) -> Bool {
        if let pitcher {
            return role == higherRole(for: currentRole, pitcher: pitcher)
        }
        switch currentRole {
        case .starter, .closer:
            return role == currentRole
        case .longRelief:
            return role == .starter || role == .setup
        case .setup:
            return role == .closer
        }
    }

    // MARK: Rookie market

    public static func rookieMarket(
        careerID: String,
        teamID: String,
        draftRound: Int,
        signingBonus: Int,
        generatedAtRevision: UInt64,
        forSeason: Int = 1,
        overallPick: Int? = nil
    ) -> ProContractMarket {
        let salary = rookieAnnualSalary(forDraftRound: draftRound) ?? 40_000_000
        let expectation = ProContractExpectation(
            kind: .majorRoster,
            target: 1,
            difficulty: .accessible
        )
        let marketID = "market:\(careerID):\(forSeason):rookie"
        let offer = ProContractOffer(
            id: "offer:\(marketID):\(teamID):rookie",
            teamID: teamID,
            years: 3,
            annualSalary: salary,
            signingBonus: signingBonus,
            contractKind: .rookie,
            rolePromise: .starter,
            outlook: .opportunity,
            expectation: expectation,
            preservesTeamLegacy: true
        )
        return ProContractMarket(
            id: marketID,
            kind: .rookie,
            forSeason: forSeason,
            generatedAtRevision: generatedAtRevision,
            offers: [offer],
            draftRound: draftRound,
            overallPick: overallPick
        )
    }

    private static func nonDominated(_ offers: [ProContractOffer], currentRole: ProRole, usesContractDepth: Bool = false) -> Bool {
        guard Set(offers.map(\.id)).count == offers.count else { return false }
        for index in offers.indices {
            for other in offers.indices where index != other {
                let lhs = axes(for: offers[index], currentRole: currentRole, usesContractDepth: usesContractDepth)
                let rhs = axes(for: offers[other], currentRole: currentRole, usesContractDepth: usesContractDepth)
                let pairs = zip(lhs, rhs)
                let dominates = pairs.allSatisfy { $0.0 >= $0.1 }
                    && pairs.contains { $0.0 > $0.1 }
                if dominates { return false }
            }
        }
        return true
    }

    private static func axes(for offer: ProContractOffer, currentRole: ProRole, usesContractDepth: Bool) -> [Int] {
        let expectationValue: Int = switch offer.expectation.difficulty {
        case .accessible: 2
        case .standard: 1
        case .stretch: 0
        }
        var values = [
            offer.annualSalary,
            offer.years,
            roleValue(current: currentRole, promised: offer.rolePromise),
            offer.preservesTeamLegacy ? 2 : (offer.outlook == .opportunity ? 1 : 0),
            expectationValue,
        ]
        if usesContractDepth {
            values.append(offer.signingBonus ?? 0)
        }
        return values
    }

    private static func offer(
        marketID: String,
        teamID: String,
        years: Int,
        annualSalary: Int,
        contractKind: ProContractKind,
        role: ProRole,
        outlook: ProTeamOutlook,
        expectation: ProContractExpectation,
        preservesTeamLegacy: Bool,
        signingBonus: Int? = nil,
        interest: ProClubInterestSignal? = nil
    ) -> ProContractOffer {
        ProContractOffer(
            id: "offer:\(marketID):\(teamID):\(contractKind.rawValue)",
            teamID: teamID,
            years: years,
            annualSalary: annualSalary,
            signingBonus: signingBonus,
            contractKind: contractKind,
            rolePromise: role,
            outlook: outlook,
            expectation: expectation,
            preservesTeamLegacy: preservesTeamLegacy,
            interest: interest
        )
    }

    private static func marketID(careerID: String, season: Int, kind: ProContractMarketKind) -> String {
        "market:\(careerID):\(season):\(kind.rawValue)"
    }

    /// A deterministic team signal used to assign the already-selected external candidates to
    /// the challenge/opportunity slots. The larger noise range is intentional: changing season
    /// can change slot assignment without changing the demand-ranked candidate set. Persisted
    /// offer outlook remains the public contender/opportunity trade-off axis.
    public static func teamOutlookSignal(teamID: String, forSeason: Int, demand: Int) -> Int {
        let boundedDemand = max(0, min(100, demand))
        let seasonalNoise = Int(StableHash.fnv1a64Value("\(teamID)|\(forSeason)|\(boundedDemand)") % 101)
        return boundedDemand * 2 + seasonalNoise
    }

    public static func teamOutlook(teamID: String, forSeason: Int, demand: Int) -> ProTeamOutlook {
        let signal = teamOutlookSignal(teamID: teamID, forSeason: forSeason, demand: demand)
        switch signal {
        case 240...: return .contender
        case ..<130: return .opportunity
        default: return .balanced
        }
    }

    private static func candidatePair(currentTeam: DraftTeamSnapshot, marketID: String) -> [DraftTeamSnapshot] {
        let ranked = ProCareerEngine.proTeams
            .filter { $0.id != currentTeam.id }
            .sorted { lhs, rhs in
                let left = Int64(lhs.demand) * 1_000 + Int64(StableHash.fnv1a64Value("\(marketID)|\(lhs.id)|candidate") % 1_000)
                let right = Int64(rhs.demand) * 1_000 + Int64(StableHash.fnv1a64Value("\(marketID)|\(rhs.id)|candidate") % 1_000)
                if left != right { return left > right }
                return lhs.id < rhs.id
            }
        guard ranked.count >= 2 else { return [] }
        return [ranked[0], ranked[1]]
    }

    private static func assignedExternalTeams(
        currentTeam: DraftTeamSnapshot,
        marketID: String
    ) -> (challenge: DraftTeamSnapshot, opportunity: DraftTeamSnapshot)? {
        let candidates = candidatePair(currentTeam: currentTeam, marketID: marketID)
        guard candidates.count == 2 else { return nil }
        let slots = candidates.sorted { lhs, rhs in
            let left = teamOutlookSignal(teamID: lhs.id, forSeason: marketSeason(from: marketID), demand: lhs.demand)
            let right = teamOutlookSignal(teamID: rhs.id, forSeason: marketSeason(from: marketID), demand: rhs.demand)
            if left != right { return left > right }
            return lhs.id < rhs.id
        }
        return (challenge: slots[0], opportunity: slots[1])
    }

    private static func marketSeason(from marketID: String) -> Int {
        let parts = marketID.split(separator: ":")
        guard parts.count >= 3, let season = Int(parts[parts.count - 2]) else { return 1 }
        return season
    }

    private static func choose(_ values: [Int], key: String, marketID: String, teamID: String, attempt: Int) -> Int {
        guard !values.isEmpty else { return 0 }
        let hash = StableHash.fnv1a64Value("\(marketID)|\(teamID)|\(key)|attempt:\(attempt)")
        return values[Int(hash % UInt64(values.count))]
    }

    public static func maximumContractYears(usesContractDepth: Bool) -> Int {
        usesContractDepth ? 5 : 4
    }

    public static func lastTeamLegacy(for state: ProCareerSnapshot) -> Int {
        guard let journey = state.journeyState,
              let record = ProTeamCareerRecordRules.record(teamID: state.team.id, in: journey.teamRecords) else {
            return 0
        }
        return ProTeamCareerRecordRules.score(record: record, rulesVersion: journey.rulesVersion)
    }

    public static func totalGuaranteedSalary(for offer: ProContractOffer) -> Int {
        Int(clamping: Int64(offer.annualSalary) * Int64(offer.years) + Int64(offer.signingBonus ?? 0))
    }

    public static func evaluateStayCounter(fanSupport: Int, marketScore: Int) -> Bool {
        if marketScore >= 70 { return true }
        return fanSupport >= 55 && marketScore >= 60
    }

    /// Pure pre-check for the FA stay counter. Uses the same extra-year cap, acceptance
    /// rule, applied-market `isValid`, and non-dominance test as `requestContractCounter`.
    public static func counterAvailability(
        market: ProContractMarket,
        state: ProCareerSnapshot,
        kind: ProContractCounterKind
    ) -> ProCounterAvailability {
        guard ProCareerEngine.usesContractDepthRules(state),
              market.kind == .freeAgency,
              market.counterOffer == nil,
              let stay = market.offers.first(where: { $0.preservesTeamLegacy && $0.teamID == state.team.id }) else {
            return .unavailable(.years)
        }
        let remainingSeasons = ProCareerEngine.maximumCareerSeasons - market.forSeason + 1
        if kind == .extraYear, !(stay.years < 5 && stay.years < remainingSeasons) {
            return .unavailable(.years)
        }
        let score = marketScore(state: state)
        let accepted = evaluateStayCounter(
            fanSupport: state.journeyState?.reputation.fanSupport ?? 0,
            marketScore: score
        )
        guard accepted else { return .available }
        let probed = applyingStayCounter(
            ProContractCounterState(kind: kind, accepted: true, applied: true),
            to: market,
            generatedAtRevision: state.revision + 1
        )
        let projected = projectedPitcher(
            for: state.pitcher,
            effectiveAge: state.age + (state.journeyState?.offseasonTransition?.ageAdvanceYears ?? 0)
        )
        let lastTeamLegacy = lastTeamLegacy(for: state)
        if isValid(
            market: probed,
            currentTeamID: state.team.id,
            currentRole: state.role,
            maximumCareerSeasons: ProCareerEngine.maximumCareerSeasons,
            marketScore: score,
            pitcher: projected,
            usesContractDepth: true,
            lastTeamLegacy: lastTeamLegacy
        ) {
            return .available
        }
        if !isNonDominated(probed.offers, currentRole: state.role, usesContractDepth: true) {
            return .unavailable(.dominance)
        }
        return .unavailable(.salaryBand)
    }

    public static func applyingStayCounter(
        _ counter: ProContractCounterState,
        to market: ProContractMarket,
        generatedAtRevision: UInt64
    ) -> ProContractMarket {
        guard counter.applied, let stayIndex = market.offers.firstIndex(where: { $0.preservesTeamLegacy }) else {
            return ProContractMarket(
                id: market.id,
                kind: market.kind,
                forSeason: market.forSeason,
                generatedAtRevision: generatedAtRevision,
                offers: market.offers,
                draftRound: market.draftRound,
                overallPick: market.overallPick,
                counterOffer: counter
            )
        }
        let stay = market.offers[stayIndex]
        let remainingSeasons = ProCareerEngine.maximumCareerSeasons - market.forSeason + 1
        let updatedStay: ProContractOffer
        switch counter.kind {
        case .extraYear:
            updatedStay = ProContractOffer(
                id: stay.id,
                teamID: stay.teamID,
                years: min(5, min(remainingSeasons, stay.years + 1)),
                annualSalary: stay.annualSalary,
                signingBonus: stay.signingBonus,
                contractKind: stay.contractKind,
                rolePromise: stay.rolePromise,
                outlook: stay.outlook,
                expectation: stay.expectation,
                preservesTeamLegacy: stay.preservesTeamLegacy,
                interest: stay.interest
            )
        case .raiseSalary:
            let raised = salary(
                fromBase: Int64(stay.annualSalary),
                multiplierNumerator: 110,
                multiplierDenominator: 100
            )
            updatedStay = ProContractOffer(
                id: stay.id,
                teamID: stay.teamID,
                years: stay.years,
                annualSalary: raised,
                signingBonus: stay.signingBonus,
                contractKind: stay.contractKind,
                rolePromise: stay.rolePromise,
                outlook: stay.outlook,
                expectation: stay.expectation,
                preservesTeamLegacy: stay.preservesTeamLegacy,
                interest: stay.interest
            )
        }
        var offers = market.offers
        offers[stayIndex] = updatedStay
        return ProContractMarket(
            id: market.id,
            kind: market.kind,
            forSeason: market.forSeason,
            generatedAtRevision: generatedAtRevision,
            offers: offers,
            draftRound: market.draftRound,
            overallPick: market.overallPick,
            counterOffer: counter
        )
    }

    public static func signingBonusBand(for offer: ProContractOffer) -> String {
        guard let bonus = offer.signingBonus, offer.annualSalary > 0 else { return "none" }
        let percent = bonus * 100 / offer.annualSalary
        switch percent {
        case ..<90: return "low"
        case 90...110: return "mid"
        default: return "high"
        }
    }

    private static func renewalLongYearChoices(usesContractDepth: Bool, lastTeamLegacy: Int) -> [Int] {
        if usesContractDepth, lastTeamLegacy >= 65 { return [3, 4, 5] }
        return [3, 4]
    }

    private static func stayYearChoices(usesContractDepth: Bool, lastTeamLegacy: Int) -> [Int] {
        if usesContractDepth, lastTeamLegacy >= 65 { return [3, 4, 5] }
        return [3, 4]
    }

    private static func signingBonusIsValid(_ bonus: Int?, annualSalary: Int, relaxedPercent: Bool = false) -> Bool {
        guard let bonus, bonus > 0, bonus % 10_000_000 == 0 else { return false }
        if relaxedPercent { return true }
        let minimum = roundToNearestTenMillion(Int64(annualSalary) * 60 / 100)
        let maximum = roundToNearestTenMillion(Int64(annualSalary) * 140 / 100)
        return bonus >= minimum && bonus <= maximum
    }

    private static func hashedSigningBonus(
        annualSalary: Int,
        marketID: String,
        teamID: String,
        percents: [Int]
    ) -> Int {
        let percent = choose(percents, key: "free-agent-signing-bonus", marketID: marketID, teamID: teamID, attempt: 0)
        return Int(clamping: roundToNearestTenMillion(Int64(annualSalary) * Int64(percent) / 100))
    }

    private static func clubInterest(
        marketID: String,
        team: DraftTeamSnapshot,
        outlook: ProTeamOutlook,
        preservesTeamLegacy: Bool,
        fanSupport: Int,
        demandRank: Int
    ) -> ProClubInterestSignal {
        let noise = Int(StableHash.fnv1a64Value("\(marketID)|\(team.id)|interest") % 101)
        var score = team.demand + noise - demandRank * 4
        if outlook == .contender { score += 28 }
        if outlook == .opportunity { score -= 18 }
        if preservesTeamLegacy { score += fanSupport / 2 }
        let level: ProClubInterest
        let reason: String
        if score >= 150 {
            level = .hot
            reason = outlook == .contender ? "contention" : "demand"
        } else if score < 90 {
            level = .cool
            reason = outlook == .opportunity ? "opportunity" : "depth"
        } else {
            level = .warm
            reason = preservesTeamLegacy ? "loyalty" : "demand"
        }
        return ProClubInterestSignal(level: level, reason: reason)
    }

    private static func makeFreeAgencyMarketWithDepth(
        careerID: String,
        currentTeam: DraftTeamSnapshot,
        pitcher: PitcherSnapshot,
        level: ProLevel,
        role: ProRole,
        previousStats: ProSeasonStats,
        marketScore: Int,
        fanSupport: Int,
        forSeason: Int,
        generatedAtRevision: UInt64,
        maximumCareerSeasons: Int,
        lastTeamLegacy: Int
    ) -> ProContractMarket? {
        let marketID = marketID(careerID: careerID, season: forSeason, kind: .freeAgency)
        let currentExpectation = buildExpectation(level: level, role: role, previousStats: previousStats, contractKind: .freeAgent, outlook: .balanced)
        guard let externalSlots = assignedExternalTeamsWithDepth(currentTeam: currentTeam, marketID: marketID) else { return nil }
        let challengeTeam = externalSlots.challenge
        let opportunityTeam = externalSlots.opportunity
        let longTermTeam = externalSlots.longTerm
        let stayChoices = stayYearChoices(usesContractDepth: true, lastTeamLegacy: lastTeamLegacy)
        let rankedIDs = rankedExternalTeamIDs(currentTeam: currentTeam, marketID: marketID)

        func interest(for team: DraftTeamSnapshot, outlook: ProTeamOutlook, preserves: Bool) -> ProClubInterestSignal {
            let rank = rankedIDs.firstIndex(of: team.id) ?? 9
            return clubInterest(
                marketID: marketID,
                team: team,
                outlook: outlook,
                preservesTeamLegacy: preserves,
                fanSupport: fanSupport,
                demandRank: rank
            )
        }

        func buildMarket(
            attempt: Int,
            canonical: Bool = false,
            yearsOverride: (stay: Int, challenge: Int, opportunity: Int, longTerm: Int)? = nil,
            multipliersOverride: (stay: Int, challenge: Int, opportunity: Int, longTerm: Int)? = nil
        ) -> ProContractMarket {
            let stayYears = cappedYears(yearsOverride?.stay ?? (canonical ? (stayChoices.max() ?? 4) : choose(stayChoices, key: "free-agent-stay-years", marketID: marketID, teamID: currentTeam.id, attempt: attempt)), forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) ?? 1
            let challengeYears = cappedYears(yearsOverride?.challenge ?? (canonical ? 2 : choose([2, 3], key: "free-agent-challenge-years", marketID: marketID, teamID: challengeTeam.id, attempt: attempt)), forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) ?? 1
            let opportunityYears = cappedYears(yearsOverride?.opportunity ?? (canonical ? 1 : choose([1, 2], key: "free-agent-opportunity-years", marketID: marketID, teamID: opportunityTeam.id, attempt: attempt)), forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) ?? 1
            let longTermYears = cappedYears(yearsOverride?.longTerm ?? (canonical ? 5 : choose([4, 5], key: "free-agent-long-term-years", marketID: marketID, teamID: longTermTeam.id, attempt: attempt)), forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) ?? 1
            let challengeRole = lowerRole(for: role)
            let opportunityRole = higherRole(for: role, pitcher: pitcher)
            let challengeExpectationBase = buildExpectation(level: level, role: challengeRole, previousStats: previousStats, contractKind: .freeAgent, outlook: .contender)
            let longTermExpectation = buildExpectation(level: level, role: role, previousStats: previousStats, contractKind: .longTerm, outlook: .opportunity)
            let stayMultiplier = multipliersOverride?.stay ?? (canonical ? 100 : choose([90, 95, 100], key: "free-agent-stay-multiplier", marketID: marketID, teamID: currentTeam.id, attempt: attempt))
            let challengeMultiplier = multipliersOverride?.challenge ?? (canonical ? 115 : choose([105, 110, 115], key: "free-agent-challenge-multiplier", marketID: marketID, teamID: challengeTeam.id, attempt: attempt))
            let opportunityMultiplier = multipliersOverride?.opportunity ?? (canonical ? 85 : choose([80, 85, 90, 95], key: "free-agent-opportunity-multiplier", marketID: marketID, teamID: opportunityTeam.id, attempt: attempt))
            let longTermMultiplier = multipliersOverride?.longTerm ?? (canonical ? 90 : choose([85, 90, 95], key: "free-agent-long-term-multiplier", marketID: marketID, teamID: longTermTeam.id, attempt: attempt))
            let salary: (String, Int, ProContractKind) -> Int = { teamID, multiplier, kind in
                canonical
                    ? canonicalFallbackSalary(marketScore: marketScore, multiplierNumerator: multiplier)
                    : annualSalary(marketScore: marketScore, marketID: marketID, teamID: teamID, contractKind: kind, multiplierNumerator: multiplier)
            }
            let staySalary = salary(currentTeam.id, stayMultiplier, .freeAgent)
            let challengeSalary = salary(challengeTeam.id, challengeMultiplier, .freeAgent)
            let opportunitySalary = salary(opportunityTeam.id, opportunityMultiplier, .freeAgent)
            let longTermSalary = salary(longTermTeam.id, longTermMultiplier, .longTerm)
            let stayBonus = hashedSigningBonus(annualSalary: staySalary, marketID: marketID, teamID: currentTeam.id, percents: canonical ? [100] : [80, 90, 100, 110, 120])
            let challengeBonus = hashedSigningBonus(annualSalary: challengeSalary, marketID: marketID, teamID: challengeTeam.id, percents: canonical ? [70] : [60, 70, 80, 90])
            let opportunityBonus = hashedSigningBonus(annualSalary: opportunitySalary, marketID: marketID, teamID: opportunityTeam.id, percents: canonical ? [80] : [70, 80, 90, 100, 110])
            let longTermBonus = hashedSigningBonus(annualSalary: longTermSalary, marketID: marketID, teamID: longTermTeam.id, percents: canonical ? [130] : [110, 120, 130, 140])
            return ProContractMarket(
                id: marketID,
                kind: .freeAgency,
                forSeason: forSeason,
                generatedAtRevision: generatedAtRevision,
                offers: [
                    offer(
                        marketID: marketID,
                        teamID: currentTeam.id,
                        years: stayYears,
                        annualSalary: staySalary,
                        contractKind: .freeAgent,
                        role: role,
                        outlook: .balanced,
                        expectation: currentExpectation,
                        preservesTeamLegacy: true,
                        signingBonus: stayBonus,
                        interest: interest(for: currentTeam, outlook: .balanced, preserves: true)
                    ),
                    offer(
                        marketID: marketID,
                        teamID: challengeTeam.id,
                        years: challengeYears,
                        annualSalary: challengeSalary,
                        contractKind: .freeAgent,
                        role: challengeRole,
                        outlook: .contender,
                        expectation: challengeExpectationBase,
                        preservesTeamLegacy: false,
                        signingBonus: challengeBonus,
                        interest: interest(for: challengeTeam, outlook: .contender, preserves: false)
                    ),
                    offer(
                        marketID: marketID,
                        teamID: opportunityTeam.id,
                        years: opportunityYears,
                        annualSalary: opportunitySalary,
                        contractKind: .freeAgent,
                        role: opportunityRole,
                        outlook: .opportunity,
                        expectation: buildExpectation(level: level, role: opportunityRole, previousStats: previousStats, contractKind: .freeAgent, outlook: .opportunity),
                        preservesTeamLegacy: false,
                        signingBonus: opportunityBonus,
                        interest: interest(for: opportunityTeam, outlook: .opportunity, preserves: false)
                    ),
                    offer(
                        marketID: marketID,
                        teamID: longTermTeam.id,
                        years: longTermYears,
                        annualSalary: longTermSalary,
                        contractKind: .longTerm,
                        role: role,
                        outlook: .balanced,
                        expectation: longTermExpectation,
                        preservesTeamLegacy: false,
                        signingBonus: longTermBonus,
                        interest: interest(for: longTermTeam, outlook: .balanced, preserves: false)
                    ),
                ]
            )
        }

        for attempt in 0...7 {
            let market = buildMarket(attempt: attempt)
            if isValid(
                market: market,
                currentTeamID: currentTeam.id,
                currentRole: role,
                maximumCareerSeasons: maximumCareerSeasons,
                marketScore: marketScore,
                pitcher: pitcher,
                usesContractDepth: true,
                lastTeamLegacy: lastTeamLegacy
            ) {
                return market
            }
        }

        let stayYearPool = Array(Set(stayChoices.compactMap { cappedYears($0, forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) })).sorted()
        let challengeYearPool = Array(Set([2, 3].compactMap { cappedYears($0, forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) })).sorted()
        let opportunityYearPool = Array(Set([1, 2].compactMap { cappedYears($0, forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) })).sorted()
        let longTermYearPool = Array(Set([4, 5].compactMap { cappedYears($0, forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) })).sorted()
        for stayYears in stayYearPool {
            for challengeYears in challengeYearPool {
                for opportunityYears in opportunityYearPool {
                    for longTermYears in longTermYearPool {
                        for stayMultiplier in [90, 95, 100] {
                            for challengeMultiplier in [105, 110, 115] {
                                for opportunityMultiplier in [80, 85, 90, 95] {
                                    for longTermMultiplier in [85, 90, 95] {
                                        let market = buildMarket(
                                            attempt: 0,
                                            yearsOverride: (stay: stayYears, challenge: challengeYears, opportunity: opportunityYears, longTerm: longTermYears),
                                            multipliersOverride: (stay: stayMultiplier, challenge: challengeMultiplier, opportunity: opportunityMultiplier, longTerm: longTermMultiplier)
                                        )
                                        if isValid(
                                            market: market,
                                            currentTeamID: currentTeam.id,
                                            currentRole: role,
                                            maximumCareerSeasons: maximumCareerSeasons,
                                            marketScore: marketScore,
                                            pitcher: pitcher,
                                            usesContractDepth: true,
                                            lastTeamLegacy: lastTeamLegacy
                                        ) {
                                            return market
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        let fallback = buildMarket(attempt: 0, canonical: true)
        if isValid(
            market: fallback,
            currentTeamID: currentTeam.id,
            currentRole: role,
            maximumCareerSeasons: maximumCareerSeasons,
            marketScore: marketScore,
            pitcher: pitcher,
            usesContractDepth: true,
            lastTeamLegacy: lastTeamLegacy
        ) {
            return fallback
        }
        return nil
    }

    private static func isValidFreeAgencyDepth(
        market: ProContractMarket,
        currentTeamID: String,
        currentRole: ProRole,
        remainingSeasons: Int,
        marketScore: Int?,
        pitcher: PitcherSnapshot?,
        lastTeamLegacy: Int
    ) -> Bool {
        guard market.offers.count == 4,
              market.offers[0].contractKind == .freeAgent,
              market.offers[1].contractKind == .freeAgent,
              market.offers[2].contractKind == .freeAgent,
              market.offers[3].contractKind == .longTerm,
              market.offers[0].teamID == currentTeamID,
              market.offers[0].outlook == .balanced,
              market.offers[1].outlook == .contender,
              market.offers[2].outlook == .opportunity,
              market.offers[3].outlook == .balanced,
              Set(market.offers.map(\.teamID)).count == 4 else { return false }
        let stay = market.offers[0]
        let challenge = market.offers[1]
        let opportunity = market.offers[2]
        let longTerm = market.offers[3]
        let maxStayYears = stayYearChoices(usesContractDepth: true, lastTeamLegacy: lastTeamLegacy).max() ?? 4
        let counter = market.counterOffer
        let stayYearsCeiling: Int
        if counter?.applied == true, counter?.kind == .extraYear {
            stayYearsCeiling = min(5, remainingSeasons)
        } else {
            stayYearsCeiling = min(maxStayYears, remainingSeasons)
        }
        guard stay.preservesTeamLegacy,
              !challenge.preservesTeamLegacy,
              !opportunity.preservesTeamLegacy,
              !longTerm.preservesTeamLegacy,
              challenge.teamID != currentTeamID,
              opportunity.teamID != currentTeamID,
              longTerm.teamID != currentTeamID,
              challenge.rolePromise == lowerRole(for: currentRole),
              opportunityRoleIsValid(opportunity.rolePromise, currentRole: currentRole, pitcher: pitcher),
              longTerm.rolePromise == currentRole,
              stay.expectation.difficulty == .standard,
              challenge.expectation.difficulty == .stretch,
              opportunity.expectation.difficulty == .accessible,
              longTerm.expectation.difficulty == .accessible,
              stay.years >= min(3, remainingSeasons),
              stay.years <= stayYearsCeiling,
              challenge.years >= min(2, remainingSeasons),
              challenge.years <= min(3, remainingSeasons),
              opportunity.years >= 1,
              opportunity.years <= min(2, remainingSeasons),
              longTerm.years >= min(4, remainingSeasons),
              longTerm.years <= min(5, remainingSeasons),
              stay.interest != nil,
              challenge.interest != nil,
              opportunity.interest != nil,
              longTerm.interest != nil else { return false }

        guard let currentTeam = ProCareerEngine.proTeams.first(where: { $0.id == currentTeamID }),
              let slots = assignedExternalTeamsWithDepth(currentTeam: currentTeam, marketID: market.id),
              challenge.teamID == slots.challenge.id,
              opportunity.teamID == slots.opportunity.id,
              longTerm.teamID == slots.longTerm.id else { return false }

        if let marketScore {
            let regularStaySalaries = [90, 95, 100].map {
                annualSalary(marketScore: marketScore, marketID: market.id, teamID: stay.teamID, contractKind: .freeAgent, multiplierNumerator: $0)
            }
            let raisedStaySalaries = regularStaySalaries.map {
                salary(fromBase: Int64($0), multiplierNumerator: 110, multiplierDenominator: 100)
            }
            let regularChallengeSalaries = [105, 110, 115].map {
                annualSalary(marketScore: marketScore, marketID: market.id, teamID: challenge.teamID, contractKind: .freeAgent, multiplierNumerator: $0)
            }
            let regularOpportunitySalaries = [80, 85, 90, 95].map {
                annualSalary(marketScore: marketScore, marketID: market.id, teamID: opportunity.teamID, contractKind: .freeAgent, multiplierNumerator: $0)
            }
            let regularLongTermSalaries = [85, 90, 95].map {
                annualSalary(marketScore: marketScore, marketID: market.id, teamID: longTerm.teamID, contractKind: .longTerm, multiplierNumerator: $0)
            }
            let staySalaryOK: Bool
            if counter?.applied == true, counter?.kind == .raiseSalary {
                staySalaryOK = raisedStaySalaries.contains(stay.annualSalary) || regularStaySalaries.contains(stay.annualSalary)
            } else {
                staySalaryOK = regularStaySalaries.contains(stay.annualSalary)
                    || stay.annualSalary == canonicalFallbackSalary(marketScore: marketScore, multiplierNumerator: 100)
            }
            let regularTuple = staySalaryOK
                && regularChallengeSalaries.contains(challenge.annualSalary)
                && regularOpportunitySalaries.contains(opportunity.annualSalary)
                && regularLongTermSalaries.contains(longTerm.annualSalary)
            let canonicalTuple = stay.years == min(maxStayYears, remainingSeasons)
                && challenge.years == min(2, remainingSeasons)
                && opportunity.years == 1
                && longTerm.years == min(5, remainingSeasons)
                && stay.annualSalary == canonicalFallbackSalary(marketScore: marketScore, multiplierNumerator: 100)
                && challenge.annualSalary == canonicalFallbackSalary(marketScore: marketScore, multiplierNumerator: 115)
                && opportunity.annualSalary == canonicalFallbackSalary(marketScore: marketScore, multiplierNumerator: 85)
                && longTerm.annualSalary == canonicalFallbackSalary(marketScore: marketScore, multiplierNumerator: 90)
            guard canonicalTuple || regularTuple else { return false }
        }
        return true
    }

    private static func rankedExternalTeamIDs(currentTeam: DraftTeamSnapshot, marketID: String) -> [String] {
        ProCareerEngine.proTeams
            .filter { $0.id != currentTeam.id }
            .sorted { lhs, rhs in
                let left = Int64(lhs.demand) * 1_000 + Int64(StableHash.fnv1a64Value("\(marketID)|\(lhs.id)|candidate") % 1_000)
                let right = Int64(rhs.demand) * 1_000 + Int64(StableHash.fnv1a64Value("\(marketID)|\(rhs.id)|candidate") % 1_000)
                if left != right { return left > right }
                return lhs.id < rhs.id
            }
            .map(\.id)
    }

    private static func assignedExternalTeamsWithDepth(
        currentTeam: DraftTeamSnapshot,
        marketID: String
    ) -> (challenge: DraftTeamSnapshot, opportunity: DraftTeamSnapshot, longTerm: DraftTeamSnapshot)? {
        let ranked = ProCareerEngine.proTeams
            .filter { $0.id != currentTeam.id }
            .sorted { lhs, rhs in
                let left = Int64(lhs.demand) * 1_000 + Int64(StableHash.fnv1a64Value("\(marketID)|\(lhs.id)|candidate") % 1_000)
                let right = Int64(rhs.demand) * 1_000 + Int64(StableHash.fnv1a64Value("\(marketID)|\(rhs.id)|candidate") % 1_000)
                if left != right { return left > right }
                return lhs.id < rhs.id
            }
        guard ranked.count >= 3 else { return nil }
        let candidates = Array(ranked.prefix(3))
        let byOutlook = candidates.sorted { lhs, rhs in
            let left = teamOutlookSignal(teamID: lhs.id, forSeason: marketSeason(from: marketID), demand: lhs.demand)
            let right = teamOutlookSignal(teamID: rhs.id, forSeason: marketSeason(from: marketID), demand: rhs.demand)
            if left != right { return left > right }
            return lhs.id < rhs.id
        }
        return (challenge: byOutlook[0], opportunity: byOutlook[2], longTerm: byOutlook[1])
    }

    private static func cappedYears(_ years: Int, forSeason: Int, maximumCareerSeasons: Int) -> Int? {
        guard forSeason >= 1, forSeason <= maximumCareerSeasons else { return nil }
        return min(max(1, years), maximumCareerSeasons - forSeason + 1)
    }

    private static func latestStats(_ state: ProCareerSnapshot) -> ProSeasonStats {
        let currentTeamStats = state.careerStats
            .filter { $0.teamID == state.team.id }
        if let latest = currentTeamStats.max(by: { $0.season < $1.season }) {
            return latest
        }
        guard state.currentStats.teamID == state.team.id else {
            return ProSeasonStats(season: state.currentStats.season, teamID: state.team.id)
        }
        return state.currentStats
    }

    public static func projectedPitcher(
        for pitcher: PitcherSnapshot,
        effectiveAge: Int,
        proRulesVersion: Int? = nil,
        recoveryYear: Bool = false
    ) -> PitcherSnapshot {
        let usesArc = (proRulesVersion ?? 1) >= ProCareerEngine.careerArcRulesVersion
        let usesChallenge = (proRulesVersion ?? 1) >= ProCareerEngine.careerChallengeRulesVersion
        if usesChallenge {
            // v8: 에이징이 커리어 아크를 만든다. 이전 규칙은 33세(시즌 15+)까지 어떤
            // 하락도 없고 command·stamina는 영원히 그대로여서, 시즌 1~14가 굴곡 없는
            // 단조 상승이었다("선수생활에 굴곡이 있어야 재밌을듯" 리뷰). 31세부터 구위·
            // 변화구가 완만히, 34세부터 가파르게 내려가고 제구·체력도 함께 기운다.
            // 회복 시즌 투자(recoveryYear)는 하락을 한 단계 줄인다.
            let primary: Int = effectiveAge < 31 ? 0 : effectiveAge < 34 ? 1 : 2
            let secondary: Int = effectiveAge < 34 ? 0 : 1
            let primaryDecline = recoveryYear ? max(0, primary - 1) : primary
            let secondaryDecline = recoveryYear ? 0 : secondary
            guard primaryDecline > 0 || secondaryDecline > 0 else { return pitcher }
            return PitcherSnapshot(
                id: pitcher.id,
                name: pitcher.name,
                stuff: clamp(pitcher.stuff - primaryDecline, 20, 80),
                command: clamp(pitcher.command - secondaryDecline, 20, 80),
                movement: clamp(pitcher.movement - primaryDecline, 20, 80),
                stamina: clamp(pitcher.stamina - secondaryDecline, 20, 80),
                pitchProfiles: pitcher.pitchProfiles,
                throwingHand: pitcher.throwingHand,
                mastery: pitcher.mastery
            )
        }
        let decline: Int
        if effectiveAge < 33 {
            decline = 0
        } else if usesArc, effectiveAge >= 35 {
            decline = recoveryYear ? 1 : 2
        } else {
            decline = 1
        }
        guard decline > 0 else { return pitcher }
        return PitcherSnapshot(
            id: pitcher.id,
            name: pitcher.name,
            stuff: clamp(pitcher.stuff - decline, 20, 80),
            command: pitcher.command,
            movement: clamp(pitcher.movement - decline, 20, 80),
            stamina: pitcher.stamina,
            pitchProfiles: pitcher.pitchProfiles,
            throwingHand: pitcher.throwingHand,
            mastery: pitcher.mastery
        )
    }

    private static func countingBounds(for kind: ProContractExpectationKind, role: ProRole) -> SalaryBand {
        switch kind {
        case .majorRoster: return SalaryBand(minimum: 1, maximum: 1)
        case .innings:
            switch role {
            case .starter: return SalaryBand(minimum: 240, maximum: 420)
            case .longRelief: return SalaryBand(minimum: 120, maximum: 240)
            case .setup, .closer: return SalaryBand(minimum: 1, maximum: 420)
            }
        case .strikeouts: return SalaryBand(minimum: role == .setup ? 35 : 1, maximum: role == .setup ? 80 : 80)
        case .saves: return SalaryBand(minimum: role == .closer ? 12 : 1, maximum: role == .closer ? 30 : 30)
        case .runPrevention: return SalaryBand(minimum: 3_500, maximum: 5_000)
        }
    }

    private static func clamp(_ value: Int, _ minimum: Int, _ maximum: Int) -> Int {
        min(maximum, max(minimum, value))
    }

    private static func safeProduct(_ lhs: Int, _ rhs: Int) -> Int {
        let product = Int64(lhs).multipliedReportingOverflow(by: Int64(rhs))
        if product.overflow { return Int.max }
        return Int(clamping: product.partialValue)
    }

    private static func scaled(_ value: Int, percent: Int) -> Int {
        safeProduct(value, percent) / 100
    }

    private static func safeRate(numerator: Int, multiplier: Int, denominator: Int, fallback: Int) -> Int {
        guard denominator > 0 else { return fallback }
        let product = Int64(numerator).multipliedReportingOverflow(by: Int64(multiplier))
        if product.overflow { return Int.max }
        return Int(clamping: product.partialValue / Int64(denominator))
    }
}
