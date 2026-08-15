import Foundation

public enum ProCareerGoalOutcome: String, Codable, Sendable {
    case completed
    case replaced
    case retiredIncomplete = "retired_incomplete"
}

public struct ProCareerGoalRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let ambition: ProCareerAmbition
    public let selectedSeason: Int
    public let anchorTeamID: String?
    public let completedSeason: Int?
    public let endedSeason: Int
    public let outcome: ProCareerGoalOutcome

    public init(
        id: String,
        ambition: ProCareerAmbition,
        selectedSeason: Int,
        anchorTeamID: String?,
        completedSeason: Int?,
        endedSeason: Int,
        outcome: ProCareerGoalOutcome
    ) {
        self.id = id
        self.ambition = ambition
        self.selectedSeason = selectedSeason
        self.anchorTeamID = anchorTeamID
        self.completedSeason = completedSeason
        self.endedSeason = endedSeason
        self.outcome = outcome
    }
}

public enum ProContractEndReason: String, Codable, Sendable {
    case expired
    case retired
    case migrated
}

public struct ProContractRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String { contractID }
    public let contractID: String
    public let teamID: String
    public let kind: ProContractKind?
    public let signedSeason: Int
    public let totalYears: Int
    public let annualSalary: Int
    public let signingBonus: Int?
    public let rolePromise: ProRole
    public let expectation: ProContractExpectation?
    public let coveredSeasons: [Int]
    public let fulfilledExpectationSeasons: [Int]
    public let endedSeason: Int?
    public let endReason: ProContractEndReason?

    public init(
        contractID: String,
        teamID: String,
        kind: ProContractKind?,
        signedSeason: Int,
        totalYears: Int,
        annualSalary: Int,
        signingBonus: Int?,
        rolePromise: ProRole,
        expectation: ProContractExpectation?,
        coveredSeasons: [Int],
        fulfilledExpectationSeasons: [Int],
        endedSeason: Int?,
        endReason: ProContractEndReason?
    ) {
        self.contractID = contractID
        self.teamID = teamID
        self.kind = kind
        self.signedSeason = signedSeason
        self.totalYears = totalYears
        self.annualSalary = annualSalary
        self.signingBonus = signingBonus
        self.rolePromise = rolePromise
        self.expectation = expectation
        self.coveredSeasons = coveredSeasons
        self.fulfilledExpectationSeasons = fulfilledExpectationSeasons
        self.endedSeason = endedSeason
        self.endReason = endReason
    }
}

public enum ProCareerRecognitionKind: String, Codable, Sendable {
    case award
    case milestone
}

public struct ProCareerRecognition: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let kind: ProCareerRecognitionKind
    public let contentID: String
    public let season: Int
    public let teamID: String?
    public let value: Int?

    public init(
        id: String,
        kind: ProCareerRecognitionKind,
        contentID: String,
        season: Int,
        teamID: String?,
        value: Int?
    ) {
        self.id = id
        self.kind = kind
        self.contentID = contentID
        self.season = season
        self.teamID = teamID
        self.value = value
    }

    public init(
        careerID: String,
        kind: ProCareerRecognitionKind,
        contentID: String,
        season: Int,
        teamID: String? = nil,
        value: Int? = nil
    ) {
        self.init(
            id: "recognition:\(careerID):\(season):\(kind.rawValue):\(contentID)",
            kind: kind,
            contentID: contentID,
            season: season,
            teamID: teamID,
            value: value
        )
    }
}

public enum ProOffseasonTransitionRoute: String, Codable, Sendable {
    case underContract = "under_contract"
    case renewalMarket = "renewal_market"
    case freeAgencyMarket = "free_agency_market"
}

public struct ProOffseasonTransition: Codable, Equatable, Sendable {
    public let afterSeason: Int
    public let nextSeason: Int
    public let ageAdvanceYears: Int
    public let includesMilitaryService: Bool
    public let route: ProOffseasonTransitionRoute

    public init(
        afterSeason: Int,
        nextSeason: Int,
        ageAdvanceYears: Int,
        includesMilitaryService: Bool,
        route: ProOffseasonTransitionRoute
    ) {
        self.afterSeason = afterSeason
        self.nextSeason = nextSeason
        self.ageAdvanceYears = ageAdvanceYears
        self.includesMilitaryService = includesMilitaryService
        self.route = route
    }
}

public enum ProJourneyMigrationSource: String, Codable, Sendable {
    case newCareer = "new_career"
    case legacySafeBoundary = "legacy_safe_boundary"
}

public struct ProJourneyMigration: Codable, Equatable, Sendable {
    public let source: ProJourneyMigrationSource
    public let initializedSeason: Int
    public let financeStartsSeason: Int
    public let unassignedLegacyAwards: Int
    public let financeNoticePending: Bool

    public init(
        source: ProJourneyMigrationSource,
        initializedSeason: Int,
        financeStartsSeason: Int,
        unassignedLegacyAwards: Int,
        financeNoticePending: Bool
    ) {
        self.source = source
        self.initializedSeason = initializedSeason
        self.financeStartsSeason = financeStartsSeason
        self.unassignedLegacyAwards = unassignedLegacyAwards
        self.financeNoticePending = financeNoticePending
    }
}

public struct ProTeamCareerRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String { teamID }
    public let teamID: String
    public let completedSeasons: Int
    public let consecutiveSeasons: Int
    public let games: Int
    public let starts: Int
    public let inningsOuts: Int
    public let strikeouts: Int
    public let wins: Int
    public let saves: Int
    public let awardCount: Int
    public let communityPoints: Int
    public let lastSeason: Int?

    public init(
        teamID: String,
        completedSeasons: Int,
        consecutiveSeasons: Int,
        games: Int,
        starts: Int,
        inningsOuts: Int,
        strikeouts: Int,
        wins: Int,
        saves: Int,
        awardCount: Int,
        communityPoints: Int,
        lastSeason: Int?
    ) {
        self.teamID = teamID
        self.completedSeasons = completedSeasons
        self.consecutiveSeasons = consecutiveSeasons
        self.games = games
        self.starts = starts
        self.inningsOuts = inningsOuts
        self.strikeouts = strikeouts
        self.wins = wins
        self.saves = saves
        self.awardCount = awardCount
        self.communityPoints = communityPoints
        self.lastSeason = lastSeason
    }
}

public enum ProCareerAmbition: String, Codable, Sendable {
    case franchiseIcon = "franchise_icon"
    case recordBook = "record_book"
    case enduringPro = "enduring_pro"
}

public struct ProCareerGoalState: Codable, Equatable, Sendable {
    public let id: String
    public let ambition: ProCareerAmbition
    public let selectedSeason: Int
    public let anchorTeamID: String?
    public let completedSeason: Int?

    public init(
        id: String,
        ambition: ProCareerAmbition,
        selectedSeason: Int,
        anchorTeamID: String?,
        completedSeason: Int?
    ) {
        self.id = id
        self.ambition = ambition
        self.selectedSeason = selectedSeason
        self.anchorTeamID = anchorTeamID
        self.completedSeason = completedSeason
    }
}

public enum ProCareerGoalMetricKind: String, Codable, Sendable {
    case anchorTeamSeasons = "anchor_team_seasons"
    case anchorTeamLegacy = "anchor_team_legacy"
    case hallOfFameProjection = "hall_of_fame_projection"
    case awards
    case proSeasons = "pro_seasons"
    case majorServiceYears = "major_service_years"
}

public struct ProCareerGoalMetric: Codable, Equatable, Sendable {
    public let kind: ProCareerGoalMetricKind
    public let current: Int
    public let target: Int

    public init(kind: ProCareerGoalMetricKind, current: Int, target: Int) {
        self.kind = kind
        self.current = current
        self.target = target
    }
}

public struct ProCareerGoalProgress: Codable, Equatable, Sendable {
    public let ambition: ProCareerAmbition
    public let metrics: [ProCareerGoalMetric]
    public let completed: Bool

    public init(ambition: ProCareerAmbition, metrics: [ProCareerGoalMetric], completed: Bool) {
        self.ambition = ambition
        self.metrics = metrics
        self.completed = completed
    }
}

public struct ProReputationState: Codable, Equatable, Sendable {
    public let fanSupport: Int
    public let lastMerchandiseTier: ProMerchandiseTier?
    public let endorsementSeasons: [Int]

    public init(
        fanSupport: Int = 0,
        lastMerchandiseTier: ProMerchandiseTier? = nil,
        endorsementSeasons: [Int] = []
    ) {
        self.fanSupport = fanSupport
        self.lastMerchandiseTier = lastMerchandiseTier
        self.endorsementSeasons = endorsementSeasons
    }
}

/// Stable, locale-independent inputs used to explain a settlement's fan movement.
/// The presentation layer resolves `contentID`; this type deliberately contains no prose.
public enum ProFanReasonKind: String, Codable, Sendable {
    case importantGameScoreless = "important_game_scoreless"
    case importantGameRunsAllowed = "important_game_runs_allowed"
    case seasonAward = "season_award"
    case careerMilestone = "career_milestone"
    case sameTeamSeason = "same_team_season"
    case contractExpectationMet = "contract_expectation_met"
    case contractExpectationMissed = "contract_expectation_missed"
    case careerAmbitionCompleted = "career_ambition_completed"
}

public struct ProFanReason: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let kind: ProFanReasonKind
    public let contentID: String
    public let delta: Int

    public init(id: String, kind: ProFanReasonKind, contentID: String, delta: Int) {
        self.id = id
        self.kind = kind
        self.contentID = contentID
        self.delta = delta
    }

    public init(
        careerID: String,
        season: Int,
        kind: ProFanReasonKind,
        contentID: String,
        ordinal: Int = 0,
        delta: Int
    ) {
        self.init(
            id: "fan-reason:\(careerID):\(season):\(kind.rawValue):\(contentID):\(ordinal)",
            kind: kind,
            contentID: contentID,
            delta: delta
        )
    }
}

public enum ProMerchandiseTier: String, Codable, Sendable {
    case local
    case rising
    case star
    case icon
}

public struct ProFinanceState: Codable, Equatable, Sendable {
    public let careerEarnings: Int64
    public let availableFunds: Int64
    public let salaryCreditedThroughSeason: Int
    public let transactions: [ProFinanceTransaction]
    public let investmentSeason: Int?

    public init(
        careerEarnings: Int64 = 0,
        availableFunds: Int64 = 0,
        salaryCreditedThroughSeason: Int = 0,
        transactions: [ProFinanceTransaction] = [],
        investmentSeason: Int? = nil
    ) {
        self.careerEarnings = careerEarnings
        self.availableFunds = availableFunds
        self.salaryCreditedThroughSeason = salaryCreditedThroughSeason
        self.transactions = transactions
        self.investmentSeason = investmentSeason
    }
}

public struct ProFinanceTransaction: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let season: Int
    public let kind: ProFinanceTransactionKind
    public let amount: Int64

    public init(id: String, season: Int, kind: ProFinanceTransactionKind, amount: Int64) {
        self.id = id
        self.season = season
        self.kind = kind
        self.amount = amount
    }
}

public enum ProFinanceTransactionKind: String, Codable, Sendable {
    case signingBonus = "signing_bonus"
    case salary
    case merchandise
    case endorsement
    case investment
}

public enum ProOffseasonInvestment: String, Codable, Sendable {
    case pitchLab = "pitch_lab"
    case recoveryTeam = "recovery_team"
    case fanFoundation = "fan_foundation"
    case none
}

public enum ProDevelopmentFocus: String, Codable, CaseIterable, Sendable {
    case stuff
    case command
    case movement
    case stamina
}

public enum ProSeasonBenefitKind: String, Codable, Sendable {
    case developmentHeadStart = "development_head_start"
    case injuryMitigation = "injury_mitigation"
}

public struct ProSeasonBenefit: Codable, Equatable, Sendable {
    public let kind: ProSeasonBenefitKind
    public let focus: ProDevelopmentFocus?
    public let remainingCharges: Int

    public init(kind: ProSeasonBenefitKind, focus: ProDevelopmentFocus?, remainingCharges: Int) {
        self.kind = kind
        self.focus = focus
        self.remainingCharges = remainingCharges
    }
}

/// Journey-only income and reputation effects. Existing decision effects remain the source of
/// truth for ability, trust, role, and fatigue changes.
public struct ProJourneyEffect: Codable, Equatable, Sendable {
    public let income: Int64
    public let fanDelta: Int
    public let communityDelta: Int

    public init(income: Int64 = 0, fanDelta: Int = 0, communityDelta: Int = 0) {
        self.income = income
        self.fanDelta = fanDelta
        self.communityDelta = communityDelta
    }
}

public struct ProSeasonSettlement: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let season: Int
    public let teamID: String
    public let stats: ProSeasonStats
    public let newAwardIDs: [String]
    public let newMilestoneIDs: [String]
    public let salaryIncome: Int64
    public let merchandiseIncome: Int64
    public let fanBefore: Int
    public let fanAfter: Int
    /// The season delta after the documented -12...+20 clamp, before the 0...100 fan clamp.
    public let fanDelta: Int
    /// Additive Wave 5 explanation rows. Legacy settlements decode as an empty array.
    public let fanReasons: [ProFanReason]
    /// The merchandise tier derived from fanBefore and stored with the settlement.
    public let merchandiseTier: ProMerchandiseTier?
    public let teamLegacyBefore: Int
    public let teamLegacyAfter: Int
    public let hallOfFameBefore: Int
    public let hallOfFameAfter: Int
    public let contractYearsBefore: Int
    public let contractYearsAfter: Int
    public let contractExpectation: ProContractExpectation?
    public let contractExpectationActual: Int?
    public let contractExpectationMet: Bool?
    public let goalProgressBefore: ProCareerGoalProgress?
    public let goalProgressAfter: ProCareerGoalProgress?
    public let goalCompleted: Bool
    public let nextRoute: ProSettlementNextRoute

    public init(
        id: String,
        season: Int,
        teamID: String,
        stats: ProSeasonStats,
        newAwardIDs: [String] = [],
        newMilestoneIDs: [String] = [],
        salaryIncome: Int64,
        merchandiseIncome: Int64 = 0,
        fanBefore: Int,
        fanAfter: Int,
        fanDelta: Int? = nil,
        fanReasons: [ProFanReason] = [],
        merchandiseTier: ProMerchandiseTier? = nil,
        teamLegacyBefore: Int,
        teamLegacyAfter: Int,
        hallOfFameBefore: Int,
        hallOfFameAfter: Int,
        contractYearsBefore: Int,
        contractYearsAfter: Int,
        contractExpectation: ProContractExpectation? = nil,
        contractExpectationActual: Int? = nil,
        contractExpectationMet: Bool? = nil,
        goalProgressBefore: ProCareerGoalProgress? = nil,
        goalProgressAfter: ProCareerGoalProgress? = nil,
        goalCompleted: Bool = false,
        nextRoute: ProSettlementNextRoute
    ) {
        self.id = id
        self.season = season
        self.teamID = teamID
        self.stats = stats
        self.newAwardIDs = newAwardIDs
        self.newMilestoneIDs = newMilestoneIDs
        self.salaryIncome = salaryIncome
        self.merchandiseIncome = merchandiseIncome
        self.fanBefore = fanBefore
        self.fanAfter = fanAfter
        self.fanDelta = fanDelta ?? min(20, max(-12, fanAfter - fanBefore))
        self.fanReasons = fanReasons
        self.merchandiseTier = merchandiseTier
        self.teamLegacyBefore = teamLegacyBefore
        self.teamLegacyAfter = teamLegacyAfter
        self.hallOfFameBefore = hallOfFameBefore
        self.hallOfFameAfter = hallOfFameAfter
        self.contractYearsBefore = contractYearsBefore
        self.contractYearsAfter = contractYearsAfter
        self.contractExpectation = contractExpectation
        self.contractExpectationActual = contractExpectationActual
        self.contractExpectationMet = contractExpectationMet
        self.goalProgressBefore = goalProgressBefore
        self.goalProgressAfter = goalProgressAfter
        self.goalCompleted = goalCompleted
        self.nextRoute = nextRoute
    }

    private enum CodingKeys: String, CodingKey {
        case id, season, teamID, stats, newAwardIDs, newMilestoneIDs, salaryIncome, merchandiseIncome
        case fanBefore, fanAfter, fanDelta, fanReasons, merchandiseTier
        case teamLegacyBefore, teamLegacyAfter, hallOfFameBefore, hallOfFameAfter
        case contractYearsBefore, contractYearsAfter, contractExpectation, contractExpectationActual
        case contractExpectationMet, goalProgressBefore, goalProgressAfter, goalCompleted, nextRoute
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fanBefore = try container.decode(Int.self, forKey: .fanBefore)
        let fanAfter = try container.decode(Int.self, forKey: .fanAfter)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            season: try container.decode(Int.self, forKey: .season),
            teamID: try container.decode(String.self, forKey: .teamID),
            stats: try container.decode(ProSeasonStats.self, forKey: .stats),
            newAwardIDs: try container.decodeIfPresent([String].self, forKey: .newAwardIDs) ?? [],
            newMilestoneIDs: try container.decodeIfPresent([String].self, forKey: .newMilestoneIDs) ?? [],
            salaryIncome: try container.decode(Int64.self, forKey: .salaryIncome),
            merchandiseIncome: try container.decodeIfPresent(Int64.self, forKey: .merchandiseIncome) ?? 0,
            fanBefore: fanBefore,
            fanAfter: fanAfter,
            fanDelta: try container.decodeIfPresent(Int.self, forKey: .fanDelta),
            fanReasons: try container.decodeIfPresent([ProFanReason].self, forKey: .fanReasons) ?? [],
            merchandiseTier: try container.decodeIfPresent(ProMerchandiseTier.self, forKey: .merchandiseTier),
            teamLegacyBefore: try container.decode(Int.self, forKey: .teamLegacyBefore),
            teamLegacyAfter: try container.decode(Int.self, forKey: .teamLegacyAfter),
            hallOfFameBefore: try container.decode(Int.self, forKey: .hallOfFameBefore),
            hallOfFameAfter: try container.decode(Int.self, forKey: .hallOfFameAfter),
            contractYearsBefore: try container.decode(Int.self, forKey: .contractYearsBefore),
            contractYearsAfter: try container.decode(Int.self, forKey: .contractYearsAfter),
            contractExpectation: try container.decodeIfPresent(ProContractExpectation.self, forKey: .contractExpectation),
            contractExpectationActual: try container.decodeIfPresent(Int.self, forKey: .contractExpectationActual),
            contractExpectationMet: try container.decodeIfPresent(Bool.self, forKey: .contractExpectationMet),
            goalProgressBefore: try container.decodeIfPresent(ProCareerGoalProgress.self, forKey: .goalProgressBefore),
            goalProgressAfter: try container.decodeIfPresent(ProCareerGoalProgress.self, forKey: .goalProgressAfter),
            goalCompleted: try container.decodeIfPresent(Bool.self, forKey: .goalCompleted) ?? false,
            nextRoute: try container.decode(ProSettlementNextRoute.self, forKey: .nextRoute)
        )
    }
}

public enum ProSettlementNextRoute: String, Codable, Sendable {
    case underContract = "under_contract"
    case renewalMarket = "renewal_market"
    case freeAgencyEligible = "free_agency_eligible"
    case forcedRetirement = "forced_retirement"
}

public enum ProContractMarketKind: String, Codable, Sendable {
    case rookie
    case renewal
    case freeAgency = "free_agency"
}

public enum ProContractKind: String, Codable, Sendable {
    case rookie
    case renewalLong = "renewal_long"
    case proveIt = "prove_it"
    case freeAgent = "free_agent"
}

public enum ProTeamOutlook: String, Codable, Sendable {
    case opportunity
    case balanced
    case contender
}

public struct ProContractExpectation: Codable, Equatable, Sendable {
    public let kind: ProContractExpectationKind
    public let target: Int
    public let difficulty: ProExpectationDifficulty

    public init(kind: ProContractExpectationKind, target: Int, difficulty: ProExpectationDifficulty) {
        self.kind = kind
        self.target = target
        self.difficulty = difficulty
    }
}

public enum ProContractExpectationKind: String, Codable, Sendable {
    case majorRoster = "major_roster"
    case innings
    case strikeouts
    case saves
    case runPrevention = "run_prevention"
}

public enum ProExpectationDifficulty: String, Codable, Sendable {
    case accessible
    case standard
    case stretch
}

public struct ProContractOffer: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let teamID: String
    public let years: Int
    public let annualSalary: Int
    public let signingBonus: Int?
    public let contractKind: ProContractKind
    public let rolePromise: ProRole
    public let outlook: ProTeamOutlook
    public let expectation: ProContractExpectation
    public let preservesTeamLegacy: Bool

    public init(
        id: String,
        teamID: String,
        years: Int,
        annualSalary: Int,
        signingBonus: Int?,
        contractKind: ProContractKind,
        rolePromise: ProRole,
        outlook: ProTeamOutlook,
        expectation: ProContractExpectation,
        preservesTeamLegacy: Bool
    ) {
        self.id = id
        self.teamID = teamID
        self.years = years
        self.annualSalary = annualSalary
        self.signingBonus = signingBonus
        self.contractKind = contractKind
        self.rolePromise = rolePromise
        self.outlook = outlook
        self.expectation = expectation
        self.preservesTeamLegacy = preservesTeamLegacy
    }
}

public struct ProContractMarket: Codable, Equatable, Sendable {
    public let id: String
    public let kind: ProContractMarketKind
    public let forSeason: Int
    public let generatedAtRevision: UInt64
    public let offers: [ProContractOffer]
    /// Draft context belongs to the persisted rookie market rather than the offer itself. This
    /// keeps the offer payload reusable for later markets while allowing the first contract
    /// screen to explain the player's round/pick after a reload.
    public let draftRound: Int?
    public let overallPick: Int?

    public init(
        id: String,
        kind: ProContractMarketKind,
        forSeason: Int,
        generatedAtRevision: UInt64,
        offers: [ProContractOffer],
        draftRound: Int? = nil,
        overallPick: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.forSeason = forSeason
        self.generatedAtRevision = generatedAtRevision
        self.offers = offers
        self.draftRound = draftRound
        self.overallPick = overallPick
    }
}

public struct ProCareerJourneyState: Codable, Equatable, Sendable {
    public let rulesVersion: Int
    public let activeGoal: ProCareerGoalState?
    public let goalHistory: [ProCareerGoalRecord]
    public let pendingContractMarket: ProContractMarket?
    public let contractHistory: [ProContractRecord]
    public let teamRecords: [ProTeamCareerRecord]
    public let recognitions: [ProCareerRecognition]
    public let reputation: ProReputationState
    public let finances: ProFinanceState
    public let activeSeasonBenefit: ProSeasonBenefit?
    public let lastSettlement: ProSeasonSettlement?
    public let settlementAcknowledged: Bool
    public let offseasonTransition: ProOffseasonTransition?
    public let retirementHonors: [ProRetirementHonor]
    public let migration: ProJourneyMigration

    public init(
        rulesVersion: Int = 1,
        activeGoal: ProCareerGoalState? = nil,
        goalHistory: [ProCareerGoalRecord] = [],
        pendingContractMarket: ProContractMarket? = nil,
        contractHistory: [ProContractRecord] = [],
        teamRecords: [ProTeamCareerRecord] = [],
        recognitions: [ProCareerRecognition] = [],
        reputation: ProReputationState = .init(),
        finances: ProFinanceState = .init(),
        activeSeasonBenefit: ProSeasonBenefit? = nil,
        lastSettlement: ProSeasonSettlement? = nil,
        settlementAcknowledged: Bool = true,
        offseasonTransition: ProOffseasonTransition? = nil,
        retirementHonors: [ProRetirementHonor] = [],
        migration: ProJourneyMigration = .init(
            source: .newCareer,
            initializedSeason: 1,
            financeStartsSeason: 1,
            unassignedLegacyAwards: 0,
            financeNoticePending: false
        )
    ) {
        self.rulesVersion = rulesVersion
        self.activeGoal = activeGoal
        self.goalHistory = goalHistory
        self.pendingContractMarket = pendingContractMarket
        self.contractHistory = contractHistory
        self.teamRecords = teamRecords
        self.recognitions = recognitions
        self.reputation = reputation
        self.finances = finances
        self.activeSeasonBenefit = activeSeasonBenefit
        self.lastSettlement = lastSettlement
        self.settlementAcknowledged = settlementAcknowledged
        self.offseasonTransition = offseasonTransition
        self.retirementHonors = retirementHonors
        self.migration = migration
    }
}

public enum ProRetirementHonorKind: String, Codable, Identifiable, Sendable {
    case hallOfFame = "hall_of_fame"
    case retiredNumber = "retired_number"
    case clubHall = "club_hall"
    case ambitionCompleted = "ambition_completed"
    case careerEarnings = "career_earnings"

    public var id: String { rawValue }
}

public struct ProRetirementHonor: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let kind: ProRetirementHonorKind
    public let teamID: String?
    public let referenceID: String?
    public let value: Int64?

    public init(id: String, kind: ProRetirementHonorKind, teamID: String?, referenceID: String?, value: Int64?) {
        self.id = id
        self.kind = kind
        self.teamID = teamID
        self.referenceID = referenceID
        self.value = value
    }
}

public struct ProRetirementPreview: Codable, Equatable, Sendable {
    public let finalScore: Int
    public let lastTeamID: String?
    public let lastTeamSeasons: Int
    public let lastTeamLegacy: Int
    public let fanSupport: Int
    public let retiredNumberEligible: Bool
    public let clubHallTeamIDs: [String]
    public let completedAmbitions: [ProCareerAmbition]
    public let careerEarnings: Int64
    public let honors: [ProRetirementHonor]

    public init(
        finalScore: Int,
        lastTeamID: String?,
        lastTeamSeasons: Int = 0,
        lastTeamLegacy: Int = 0,
        fanSupport: Int = 0,
        retiredNumberEligible: Bool,
        clubHallTeamIDs: [String],
        completedAmbitions: [ProCareerAmbition],
        careerEarnings: Int64,
        honors: [ProRetirementHonor]
    ) {
        self.finalScore = finalScore
        self.lastTeamID = lastTeamID
        self.lastTeamSeasons = lastTeamSeasons
        self.lastTeamLegacy = lastTeamLegacy
        self.fanSupport = fanSupport
        self.retiredNumberEligible = retiredNumberEligible
        self.clubHallTeamIDs = clubHallTeamIDs
        self.completedAmbitions = completedAmbitions
        self.careerEarnings = careerEarnings
        self.honors = honors
    }
}

public enum ProRetirementRules {
    public static func preview(for state: ProCareerSnapshot) -> ProRetirementPreview {
        let finalScore = ProCareerEngine.hallOfFameFinalScore(for: state)
        let journey = state.journeyState
        let records = ProTeamCareerRecordRules.backfill(
            careerStats: state.careerStats,
            recognitions: journey?.recognitions ?? [],
            existing: journey?.teamRecords ?? []
        )
        // Retirement eligibility belongs to the final/current team. Inferring it from the
        // globally latest stat row would let a previous team's tenure leak through a transfer.
        let lastTeamID = state.team.id
        let lastRecord = ProTeamCareerRecordRules.record(teamID: lastTeamID, in: records)
        let fanSupport = journey?.reputation.fanSupport ?? 0
        let lastTeamSeasons = lastRecord?.completedSeasons ?? 0
        let lastTeamLegacy = lastRecord.map(ProTeamLegacyRules.score(record:)) ?? 0
        let retiredNumberEligible = lastRecord.map {
            $0.completedSeasons >= 8
                && lastTeamLegacy >= 80
                && fanSupport >= 60
        } ?? false
        let clubHallTeamIDs = records
            .filter {
                $0.completedSeasons >= 6
                    && ProTeamLegacyRules.score(record: $0) >= 65
                    && (!retiredNumberEligible || $0.teamID != lastTeamID)
            }
            .map(\.teamID)
            .sorted()
        let completedAmbitions = completedAmbitions(for: journey)
        let honors = makeHonors(
            careerID: state.proCareerID,
            finalScore: finalScore,
            retiredNumberTeamID: retiredNumberEligible ? lastTeamID : nil,
            clubHallTeamIDs: clubHallTeamIDs,
            completedAmbitions: completedAmbitions,
            careerEarnings: journey?.finances.careerEarnings ?? 0
        )
        return ProRetirementPreview(
            finalScore: finalScore,
            lastTeamID: lastTeamID,
            lastTeamSeasons: lastTeamSeasons,
            lastTeamLegacy: lastTeamLegacy,
            fanSupport: fanSupport,
            retiredNumberEligible: retiredNumberEligible,
            clubHallTeamIDs: clubHallTeamIDs,
            completedAmbitions: completedAmbitions,
            careerEarnings: journey?.finances.careerEarnings ?? 0,
            honors: honors
        )
    }

    public static func honors(for state: ProCareerSnapshot) -> [ProRetirementHonor] {
        preview(for: state).honors
    }

    public static func canonicalOrder(_ lhs: ProRetirementHonor, _ rhs: ProRetirementHonor) -> Bool {
        let lhsRank = rank(for: lhs.kind)
        let rhsRank = rank(for: rhs.kind)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        switch lhs.kind {
        case .clubHall:
            return (lhs.teamID ?? "") < (rhs.teamID ?? "")
        case .ambitionCompleted:
            return (lhs.referenceID ?? "") < (rhs.referenceID ?? "")
        default:
            return lhs.id < rhs.id
        }
    }

    private static func completedAmbitions(for journey: ProCareerJourneyState?) -> [ProCareerAmbition] {
        guard let journey else { return [] }
        var values = Set(
            journey.goalHistory
                .filter { $0.outcome == .completed }
                .map(\.ambition)
        )
        if let activeGoal = journey.activeGoal, activeGoal.completedSeason != nil {
            values.insert(activeGoal.ambition)
        }
        return values.sorted { $0.rawValue < $1.rawValue }
    }

    private static func makeHonors(
        careerID: String,
        finalScore: Int,
        retiredNumberTeamID: String?,
        clubHallTeamIDs: [String],
        completedAmbitions: [ProCareerAmbition],
        careerEarnings: Int64
    ) -> [ProRetirementHonor] {
        var honors: [ProRetirementHonor] = []
        if finalScore >= 70 {
            honors.append(ProRetirementHonor(
                id: "honor:\(careerID):\(ProRetirementHonorKind.hallOfFame.rawValue):none",
                kind: .hallOfFame,
                teamID: nil,
                referenceID: nil,
                value: Int64(finalScore)
            ))
        }
        if let retiredNumberTeamID {
            honors.append(ProRetirementHonor(
                id: "honor:\(careerID):\(ProRetirementHonorKind.retiredNumber.rawValue):\(retiredNumberTeamID)",
                kind: .retiredNumber,
                teamID: retiredNumberTeamID,
                referenceID: nil,
                value: nil
            ))
        }
        honors.append(contentsOf: clubHallTeamIDs.map { teamID in
            ProRetirementHonor(
                id: "honor:\(careerID):\(ProRetirementHonorKind.clubHall.rawValue):\(teamID)",
                kind: .clubHall,
                teamID: teamID,
                referenceID: nil,
                value: nil
            )
        })
        honors.append(contentsOf: completedAmbitions.map { ambition in
            ProRetirementHonor(
                id: "honor:\(careerID):\(ProRetirementHonorKind.ambitionCompleted.rawValue):\(ambition.rawValue)",
                kind: .ambitionCompleted,
                teamID: nil,
                referenceID: ambition.rawValue,
                value: nil
            )
        })
        honors.append(ProRetirementHonor(
            id: "honor:\(careerID):\(ProRetirementHonorKind.careerEarnings.rawValue):none",
            kind: .careerEarnings,
            teamID: nil,
            referenceID: nil,
            value: careerEarnings
        ))
        return honors
    }

    private static func rank(for kind: ProRetirementHonorKind) -> Int {
        switch kind {
        case .hallOfFame: 0
        case .retiredNumber: 1
        case .clubHall: 2
        case .ambitionCompleted: 3
        case .careerEarnings: 4
        }
    }
}

public enum ProTeamLegacyTier: String, Codable, Sendable {
    case newFace = "new_face"
    case supportingPillar = "supporting_pillar"
    case corePlayer = "core_player"
    case clubAce = "club_ace"
    case clubSymbol = "club_symbol"
    case retiredNumberCandidate = "retired_number_candidate"
}

/// Frozen parser for the Korean sentences that shipped before typed recognitions existed.
/// It intentionally recognizes only the fixed legacy forms and never parses new copy.
public struct ProLegacyRecognitionDescriptor: Equatable, Sendable {
    public let kind: ProCareerRecognitionKind
    public let contentID: String
    public let season: Int
    public let value: Int?

    public init(kind: ProCareerRecognitionKind, contentID: String, season: Int, value: Int?) {
        self.kind = kind
        self.contentID = contentID
        self.season = season
        self.value = value
    }
}

public enum ProLegacyRecognitionAdapter {
    private static let awards: [(String, String)] = [
        ("탈삼진상", "pro.award.strikeouts"),
        ("최소 실점상", "pro.award.run-prevention"),
        ("정밀 제구상", "pro.award.command"),
        ("피안타 억제상", "pro.award.hits"),
        ("이닝 책임상", "pro.award.innings"),
    ]

    public static func descriptor(for raw: String) -> ProLegacyRecognitionDescriptor? {
        let components = raw.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard components.count == 3,
              components[0] == "시즌",
              let season = Int(components[1]) else { return nil }
        let suffix = String(components[2])
        guard let contentID = awards.first(where: { suffix == $0.0 })?.1 else { return nil }
        return ProLegacyRecognitionDescriptor(
            kind: .award,
            contentID: contentID,
            season: season,
            value: nil
        )
    }

    public static func milestoneDescriptor(for raw: String) -> ProLegacyRecognitionDescriptor? {
        if raw.hasSuffix("시즌 완주"),
           let season = Int(raw.dropLast("시즌 완주".count)) {
            return .init(kind: .milestone, contentID: "pro.milestone.season-complete", season: season, value: nil)
        }
        let prefixes: [(String, String, String)] = [
            ("프로 통산 ", "경기", "pro.milestone.games"),
            ("프로 통산 ", "탈삼진", "pro.milestone.strikeouts"),
        ].map { ($0.0, $0.1, $0.2) }
        for (prefix, suffix, contentID) in prefixes {
            guard raw.hasPrefix(prefix), raw.hasSuffix(suffix) else { continue }
            let number = raw.dropFirst(prefix.count).dropLast(suffix.count)
            if let value = Int(number) {
                return .init(kind: .milestone, contentID: contentID, season: 0, value: value)
            }
        }
        return nil
    }

    public static func recognitions(
        careerID: String,
        awards: [String],
        milestones: [String],
        teamIDBySeason: [Int: String]
    ) -> (recognitions: [ProCareerRecognition], unassignedAwards: Int) {
        var values: [ProCareerRecognition] = []
        var unassigned = 0
        for raw in awards {
            guard let descriptor = descriptor(for: raw) else {
                unassigned += 1
                continue
            }
            let teamID = teamIDBySeason[descriptor.season]
            if teamID == nil || teamID?.isEmpty == true {
                // Keep the typed recognition for the career-wide honor view, but do not let a
                // season award with no provable team silently inflate a team record.
                unassigned += 1
            }
            values.append(ProCareerRecognition(
                careerID: careerID,
                kind: descriptor.kind,
                contentID: descriptor.contentID,
                season: descriptor.season,
                teamID: teamID,
                value: descriptor.value
            ))
        }
        for raw in milestones {
            guard let descriptor = milestoneDescriptor(for: raw) else { continue }
            values.append(ProCareerRecognition(
                careerID: careerID,
                kind: descriptor.kind,
                contentID: descriptor.contentID,
                season: descriptor.season,
                teamID: descriptor.season == 0 ? nil : teamIDBySeason[descriptor.season],
                value: descriptor.value
            ))
        }
        var unique: [String: ProCareerRecognition] = [:]
        for recognition in values {
            unique[recognition.id] = recognition
        }
        return (
            unique.values.sorted(by: ProCareerJourneyRules.recognitionOrder),
            unassigned
        )
    }
}

public enum ProCareerRecognitionRules {
    public static func currentSeasonRecognitions(
        careerID: String,
        season: Int,
        teamID: String,
        stats: ProSeasonStats,
        level: ProLevel
    ) -> [ProCareerRecognition] {
        var values: [ProCareerRecognition] = []
        if stats.strikeouts >= 120 {
            values.append(.init(careerID: careerID, kind: .award, contentID: "pro.award.strikeouts", season: season, teamID: teamID))
        }
        let ra9 = stats.inningsOuts == 0 ? Int.max : stats.runsAllowed * 27_000 / stats.inningsOuts
        if ra9 < 3_000, stats.games >= 20 {
            values.append(.init(careerID: careerID, kind: .award, contentID: "pro.award.run-prevention", season: season, teamID: teamID))
        }
        let bb9 = stats.inningsOuts == 0 ? Int.max : stats.walks * 27_000 / stats.inningsOuts
        if bb9 < 2_500, stats.inningsOuts >= 180 {
            values.append(.init(careerID: careerID, kind: .award, contentID: "pro.award.command", season: season, teamID: teamID))
        }
        let h9 = stats.inningsOuts == 0 ? Int.max : stats.hits * 27_000 / stats.inningsOuts
        if h9 < 8_500, stats.inningsOuts >= 180 {
            values.append(.init(careerID: careerID, kind: .award, contentID: "pro.award.hits", season: season, teamID: teamID))
        }
        if stats.inningsOuts >= 360 {
            values.append(.init(careerID: careerID, kind: .award, contentID: "pro.award.innings", season: season, teamID: teamID))
        }
        values.append(.init(careerID: careerID, kind: .milestone, contentID: "pro.milestone.season-complete", season: season, teamID: teamID))
        if level == .major {
            values.append(.init(careerID: careerID, kind: .milestone, contentID: "pro.milestone.major-roster", season: season, teamID: teamID))
        }
        return values.sorted(by: ProCareerJourneyRules.recognitionOrder)
    }
}

public enum ProTeamCareerRecordRules {
    private static let recognizedAwardContentIDs: Set<String> = [
        "pro.award.strikeouts",
        "pro.award.run-prevention",
        "pro.award.command",
        "pro.award.hits",
        "pro.award.innings",
    ]

    public static func isRecognizedTeamAward(_ recognition: ProCareerRecognition) -> Bool {
        recognition.kind == .award && recognizedAwardContentIDs.contains(recognition.contentID)
    }

    public static func backfill(
        careerStats: [ProSeasonStats],
        recognitions: [ProCareerRecognition] = [],
        existing: [ProTeamCareerRecord] = []
    ) -> [ProTeamCareerRecord] {
        let existingByTeam = Dictionary(uniqueKeysWithValues: existing.map { ($0.teamID, $0) })
        let grouped = Dictionary(grouping: careerStats, by: \.teamID)
        let teamIDs = Set(grouped.keys).union(existingByTeam.keys).sorted()
        return teamIDs.map { teamID in
            // A repeated season is invalid in a saved snapshot, but the pure aggregator is
            // also used by migrations and previews. Collapse identical season keys here so a
            // retry/backfill cannot inflate a team record; strict state validation rejects the
            // malformed source instead of silently repairing it.
            let seasons = (grouped[teamID] ?? [])
                .sorted { lhs, rhs in
                    if lhs.season != rhs.season { return lhs.season < rhs.season }
                    return statsToken(lhs) < statsToken(rhs)
                }
                .reduce(into: [ProSeasonStats]()) { values, season in
                    if values.last?.season != season.season { values.append(season) }
                }
            if seasons.isEmpty, let existingRecord = existingByTeam[teamID] {
                // A newly signed team needs a canonical zero-stat row before its first
                // settlement. Preserve that row (including any community points earned
                // before the first completed season) across every backfill and round trip.
                return existingRecord
            }
            var currentRun = 0
            var previousSeason: Int?
            for season in seasons {
                if previousSeason.map({ $0 + 1 == season.season }) == true {
                    currentRun += 1
                } else {
                    currentRun = 1
                }
                previousSeason = season.season
            }
            let seasonIDs = Set(seasons.map(\.season))
            let awardCount = recognitions.filter {
                isRecognizedTeamAward($0)
                    && $0.teamID == teamID
                    && !seasonIDs.isEmpty
                    && seasonIDs.contains($0.season)
            }.count
            let old = existingByTeam[teamID]
            return ProTeamCareerRecord(
                teamID: teamID,
                completedSeasons: seasons.count,
                consecutiveSeasons: currentRun,
                games: seasons.reduce(0) { $0 + $1.games },
                starts: seasons.reduce(0) { $0 + $1.starts },
                inningsOuts: seasons.reduce(0) { $0 + $1.inningsOuts },
                strikeouts: seasons.reduce(0) { $0 + $1.strikeouts },
                wins: seasons.reduce(0) { $0 + $1.wins },
                saves: seasons.reduce(0) { $0 + $1.saves },
                awardCount: awardCount,
                communityPoints: old?.communityPoints ?? 0,
                lastSeason: seasons.last?.season
            )
        }
    }

    private static func statsToken(_ stats: ProSeasonStats) -> String {
        [
            stats.teamID, String(stats.season), String(stats.games), String(stats.starts),
            String(stats.inningsOuts), String(stats.strikeouts), String(stats.walks),
            String(stats.runsAllowed), String(stats.hits), String(stats.homeRuns),
            String(stats.pitches), String(stats.wins), String(stats.losses), String(stats.saves),
        ].joined(separator: ":")
    }

    public static func record(teamID: String, in records: [ProTeamCareerRecord]) -> ProTeamCareerRecord? {
        records.first { $0.teamID == teamID }
    }

    public static func score(record: ProTeamCareerRecord) -> Int {
        let tenure = min(40, max(0, record.completedSeasons) * 5)
        let strikeouts = min(25, max(0, record.strikeouts) / 40)
        let workload = min(15, max(0, record.inningsOuts) / 180)
        let awards = min(12, max(0, record.awardCount) * 4)
        let continuity = min(8, max(0, record.consecutiveSeasons))
        let community = min(8, max(0, record.communityPoints))
        return min(100, tenure + strikeouts + workload + awards + continuity + community)
    }

    public static func tier(record: ProTeamCareerRecord) -> ProTeamLegacyTier {
        let score = score(record: record)
        if score >= 80, record.completedSeasons >= 8 { return .retiredNumberCandidate }
        if score >= 65, record.completedSeasons >= 6 { return .clubSymbol }
        if score >= 50, record.completedSeasons >= 4 { return .clubAce }
        if score >= 35 { return .corePlayer }
        if score >= 15 { return .supportingPillar }
        return .newFace
    }
}

/// Public Wave 1 name for the pure team-legacy calculation. The record aggregator remains
/// separate so migration and settlement can share the same source of truth.
public enum ProTeamLegacyRules {
    public struct Threshold: Equatable, Sendable {
        public let tier: ProTeamLegacyTier
        public let minimumScore: Int
        public let minimumCompletedSeasons: Int?

        public init(
            tier: ProTeamLegacyTier,
            minimumScore: Int,
            minimumCompletedSeasons: Int?
        ) {
            self.tier = tier
            self.minimumScore = minimumScore
            self.minimumCompletedSeasons = minimumCompletedSeasons
        }
    }

    public static func score(record: ProTeamCareerRecord) -> Int {
        ProTeamCareerRecordRules.score(record: record)
    }

    public static func tier(record: ProTeamCareerRecord) -> ProTeamLegacyTier {
        ProTeamCareerRecordRules.tier(record: record)
    }

    /// Returns the next tier's complete gate projection. Score-only consumers should use
    /// `nextThreshold(record:)` below; UI that explains progress must use this value so a
    /// satisfied score gate cannot hide a remaining completed-season gate.
    public static func nextTierProjection(record: ProTeamCareerRecord) -> Threshold? {
        switch tier(record: record) {
        case .newFace:
            return .init(tier: .supportingPillar, minimumScore: 15, minimumCompletedSeasons: nil)
        case .supportingPillar:
            return .init(tier: .corePlayer, minimumScore: 35, minimumCompletedSeasons: nil)
        case .corePlayer:
            return .init(tier: .clubAce, minimumScore: 50, minimumCompletedSeasons: 4)
        case .clubAce:
            return .init(tier: .clubSymbol, minimumScore: 65, minimumCompletedSeasons: 6)
        case .clubSymbol:
            return .init(tier: .retiredNumberCandidate, minimumScore: 80, minimumCompletedSeasons: 8)
        case .retiredNumberCandidate:
            return nil
        }
    }

    /// Backward-compatible score-only projection. It is never lower than the current score;
    /// callers that need to explain all gates should use `nextTierProjection(record:)`.
    public static func nextThreshold(record: ProTeamCareerRecord) -> Int? {
        guard let projection = nextTierProjection(record: record) else { return nil }
        return max(score(record: record), projection.minimumScore)
    }
}

public enum ProCareerGoalRules {
    public static func expectedMetrics(for ambition: ProCareerAmbition) -> [(kind: ProCareerGoalMetricKind, target: Int)] {
        switch ambition {
        case .franchiseIcon:
            return [(.anchorTeamSeasons, 8), (.anchorTeamLegacy, 80)]
        case .recordBook:
            return [(.hallOfFameProjection, 70), (.awards, 3)]
        case .enduringPro:
            return [(.proSeasons, 12), (.majorServiceYears, 8)]
        }
    }

    public static func goalID(careerID: String, season: Int, ambition: ProCareerAmbition, anchorTeamID: String?) -> String {
        "goal:\(careerID):\(season):\(ambition.rawValue):\(anchorTeamID ?? "none")"
    }

    public static func progress(
        state: ProCareerSnapshot,
        goal: ProCareerGoalState
    ) -> ProCareerGoalProgress {
        let records = ProTeamCareerRecordRules.backfill(
            careerStats: state.careerStats,
            recognitions: state.journeyState?.recognitions ?? [],
            existing: state.journeyState?.teamRecords ?? []
        )
        let record = goal.anchorTeamID.flatMap {
            ProTeamCareerRecordRules.record(teamID: $0, in: records)
        }
        let metrics: [ProCareerGoalMetric]
        switch goal.ambition {
        case .franchiseIcon:
            metrics = [
                .init(kind: .anchorTeamSeasons, current: record?.completedSeasons ?? 0, target: 8),
                .init(kind: .anchorTeamLegacy, current: record.map(ProTeamCareerRecordRules.score(record:)) ?? 0, target: 80),
            ]
        case .recordBook:
            metrics = [
                .init(kind: .hallOfFameProjection, current: ProCareerEngine.hallOfFameProjection(for: state), target: 70),
                .init(kind: .awards, current: awardCount(for: state), target: 3),
            ]
        case .enduringPro:
            metrics = [
                .init(kind: .proSeasons, current: state.careerStats.count + currentSeasonCount(state), target: 12),
                .init(kind: .majorServiceYears, current: state.serviceYears + (state.level == .major && currentSeasonCount(state) > 0 ? 1 : 0), target: 8),
            ]
        }
        return .init(ambition: goal.ambition, metrics: metrics, completed: metrics.allSatisfy { $0.current >= $0.target })
    }

    public static func awardCount(for state: ProCareerSnapshot) -> Int {
        guard let journey = state.journeyState else { return state.awards.count }
        let typedRecognitions = journey.recognitions.filter {
            ProTeamCareerRecordRules.isRecognizedTeamAward($0)
        }
        let typed = typedRecognitions.count
        let typedLegacyIDs = Set(typedRecognitions.map(\.id))
        let unknownLegacy = state.awards.filter { raw in
            guard let descriptor = ProLegacyRecognitionAdapter.descriptor(for: raw) else { return true }
            let id = "recognition:\(state.proCareerID):\(descriptor.season):\(descriptor.kind.rawValue):\(descriptor.contentID)"
            return !typedLegacyIDs.contains(id)
        }.count
        return typed + unknownLegacy
    }

    private static func currentSeasonCount(_ state: ProCareerSnapshot) -> Int {
        let hasCurrentStats = state.currentStats.games > 0 || state.currentStats.inningsOuts > 0
        let alreadySettled = state.careerStats.contains {
            $0.season == state.currentStats.season && $0.teamID == state.currentStats.teamID
        }
        return hasCurrentStats && !alreadySettled ? 1 : 0
    }
}

public enum ProCareerJourneyRules {
    public static func recognitionOrder(_ lhs: ProCareerRecognition, _ rhs: ProCareerRecognition) -> Bool {
        if lhs.season != rhs.season { return lhs.season < rhs.season }
        if lhs.kind.rawValue != rhs.kind.rawValue { return lhs.kind.rawValue < rhs.kind.rawValue }
        if lhs.contentID != rhs.contentID { return lhs.contentID < rhs.contentID }
        return lhs.id < rhs.id
    }

    public static func canonicalToken(_ journey: ProCareerJourneyState) -> String {
        func expectationToken(_ expectation: ProContractExpectation?) -> String {
            guard let expectation else { return "none" }
            return "\(expectation.kind.rawValue):\(expectation.target):\(expectation.difficulty.rawValue)"
        }
        func statsToken(_ stats: ProSeasonStats) -> String {
            [
                String(stats.season), stats.teamID, String(stats.games), String(stats.starts), String(stats.inningsOuts),
                String(stats.strikeouts), String(stats.walks), String(stats.runsAllowed), String(stats.hits), String(stats.homeRuns),
                String(stats.pitches), String(stats.wins), String(stats.losses), String(stats.saves),
            ].joined(separator: ":")
        }
        func progressToken(_ progress: ProCareerGoalProgress?) -> String {
            guard let progress else { return "none" }
            let metrics = progress.metrics.map {
                "\($0.kind.rawValue):\($0.current):\($0.target)"
            }.joined(separator: ",")
            return "\(progress.ambition.rawValue):\(progress.completed ? 1 : 0):\(metrics)"
        }

        var values = ["rules:\(journey.rulesVersion)", "ack:\(journey.settlementAcknowledged ? 1 : 0)"]
        if let goal = journey.activeGoal {
            values.append("goal:\(goal.id):\(goal.ambition.rawValue):\(goal.selectedSeason):\(goal.anchorTeamID ?? "none"):\(goal.completedSeason.map(String.init) ?? "none")")
        } else {
            values.append("goal:none")
        }
        values.append(contentsOf: journey.goalHistory.sorted { $0.id < $1.id }.map {
            "goal-record:\($0.id):\($0.ambition.rawValue):\($0.selectedSeason):\($0.anchorTeamID ?? "none"):\($0.outcome.rawValue):\($0.endedSeason):\($0.completedSeason.map(String.init) ?? "none")"
        })
        if let market = journey.pendingContractMarket {
            values.append("market:\(market.id):\(market.kind.rawValue):\(market.forSeason):\(market.generatedAtRevision):round:\(market.draftRound.map(String.init) ?? "none"):pick:\(market.overallPick.map(String.init) ?? "none")")
            values.append(contentsOf: market.offers.sorted { $0.id < $1.id }.map {
                "offer:\($0.id):\($0.teamID):\($0.years):\($0.annualSalary):\($0.signingBonus.map(String.init) ?? "none"):\($0.contractKind.rawValue):\($0.rolePromise.rawValue):\($0.outlook.rawValue):\($0.expectation.kind.rawValue):\($0.expectation.target):\($0.expectation.difficulty.rawValue):\($0.preservesTeamLegacy ? 1 : 0)"
            })
        } else {
            values.append("market:none")
        }
        values.append(contentsOf: journey.contractHistory.sorted { $0.contractID < $1.contractID }.map {
            "contract:\($0.contractID):\($0.teamID):\($0.kind?.rawValue ?? "legacy"):\($0.signedSeason):\($0.totalYears):\($0.annualSalary):\($0.signingBonus.map(String.init) ?? "none"):\($0.rolePromise.rawValue):\(expectationToken($0.expectation)):\($0.coveredSeasons.sorted().map(String.init).joined(separator: ",")):\($0.fulfilledExpectationSeasons.sorted().map(String.init).joined(separator: ",")):\($0.endedSeason.map(String.init) ?? "none"):\($0.endReason?.rawValue ?? "none")"
        })
        values.append(contentsOf: journey.teamRecords.sorted { $0.teamID < $1.teamID }.map {
            "team:\($0.teamID):\($0.completedSeasons):\($0.consecutiveSeasons):\($0.games):\($0.starts):\($0.inningsOuts):\($0.strikeouts):\($0.wins):\($0.saves):\($0.awardCount):\($0.communityPoints):\($0.lastSeason.map(String.init) ?? "none")"
        })
        values.append(contentsOf: journey.recognitions.sorted(by: recognitionOrder).map {
            "recognition:\($0.id):\($0.kind.rawValue):\($0.contentID):\($0.season):\($0.teamID ?? "none"):\($0.value.map(String.init) ?? "none")"
        })
        values += [
            "reputation:\(journey.reputation.fanSupport):\(journey.reputation.lastMerchandiseTier?.rawValue ?? "none"):\(journey.reputation.endorsementSeasons.sorted().map(String.init).joined(separator: ","))",
            "finance:\(journey.finances.careerEarnings):\(journey.finances.availableFunds):\(journey.finances.salaryCreditedThroughSeason):\(journey.finances.investmentSeason.map(String.init) ?? "none")",
        ]
        values.append(contentsOf: journey.finances.transactions.sorted { $0.id < $1.id }.map {
            "transaction:\($0.id):\($0.season):\($0.kind.rawValue):\($0.amount)"
        })
        if let benefit = journey.activeSeasonBenefit {
            values.append("benefit:\(benefit.kind.rawValue):\(benefit.focus?.rawValue ?? "none"):\(benefit.remainingCharges)")
        } else {
            values.append("benefit:none")
        }
        if let settlement = journey.lastSettlement {
            values.append("settlement:\(settlement.id):\(settlement.season):\(settlement.teamID):stats:\(statsToken(settlement.stats)):awards:\(settlement.newAwardIDs.sorted().joined(separator: ",")):milestones:\(settlement.newMilestoneIDs.sorted().joined(separator: ",")):salary:\(settlement.salaryIncome):merch:\(settlement.merchandiseIncome):fan:\(settlement.fanBefore):\(settlement.fanAfter):legacy:\(settlement.teamLegacyBefore):\(settlement.teamLegacyAfter):hof:\(settlement.hallOfFameBefore):\(settlement.hallOfFameAfter):contract:\(settlement.contractYearsBefore):\(settlement.contractYearsAfter):expectation:\(expectationToken(settlement.contractExpectation)):\(settlement.contractExpectationActual.map(String.init) ?? "none"):\(settlement.contractExpectationMet.map { $0 ? "1" : "0" } ?? "none"):goal-before:\(progressToken(settlement.goalProgressBefore)):goal-after:\(progressToken(settlement.goalProgressAfter)):goal-completed:\(settlement.goalCompleted ? 1 : 0):next:\(settlement.nextRoute.rawValue)")
            // These fields were appended in Wave 5. Keep the old token intact for legacy
            // settlements so old signed snapshots remain readable, while signing new values
            // makes the stored fan explanation and merchandise tier tamper-evident.
            if !settlement.fanReasons.isEmpty || settlement.fanDelta != min(20, max(-12, settlement.fanAfter - settlement.fanBefore)) || settlement.merchandiseTier != nil {
                values.append("settlement-wave5:\(settlement.fanDelta):\(settlement.fanReasons.map { "\($0.id):\($0.kind.rawValue):\($0.contentID):\($0.delta)" }.joined(separator: ",")):\(settlement.merchandiseTier?.rawValue ?? "none")")
            }
        } else {
            values.append("settlement:none")
        }
        if let transition = journey.offseasonTransition {
            values.append("transition:\(transition.afterSeason):\(transition.nextSeason):\(transition.ageAdvanceYears):\(transition.includesMilitaryService ? 1 : 0):\(transition.route.rawValue)")
        } else {
            values.append("transition:none")
        }
        values.append(contentsOf: journey.retirementHonors.sorted(by: ProRetirementRules.canonicalOrder).map {
            "honor:\($0.id):\($0.kind.rawValue):\($0.teamID ?? "none"):\($0.referenceID ?? "none"):\($0.value.map(String.init) ?? "none")"
        })
        values.append("migration:\(journey.migration.source.rawValue):\(journey.migration.initializedSeason):\(journey.migration.financeStartsSeason):\(journey.migration.unassignedLegacyAwards):\(journey.migration.financeNoticePending ? 1 : 0)")
        return values.joined(separator: "|")
    }
}

public enum ProFinanceRules {
    public static func investmentCost(for investment: ProOffseasonInvestment) -> Int64 {
        switch investment {
        case .pitchLab: 50_000_000
        case .recoveryTeam: 40_000_000
        case .fanFoundation: 20_000_000
        case .none: 0
        }
    }

    public static func merchandiseIncome(for fanSupport: Int) -> Int64 {
        let boundedFan = Int64(max(0, min(100, fanSupport)))
        return min(50_000_000, boundedFan * 500_000)
    }

    public static func merchandiseTier(for fanSupport: Int) -> ProMerchandiseTier {
        switch max(0, min(100, fanSupport)) {
        case 75...100: .icon
        case 50..<75: .star
        case 25..<50: .rising
        default: .local
        }
    }
}

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
                .max { ($0.endedSeason ?? 0, $0.contractID) < ($1.endedSeason ?? 0, $1.contractID) }
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
                .max { ($0.endedSeason ?? 0, $0.contractID) < ($1.endedSeason ?? 0, $1.contractID) }
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
        currentContract: ProContractRecord? = nil
    ) -> ProContractMarket? {
        let marketID = marketID(careerID: careerID, season: forSeason, kind: .renewal)
        guard cappedYears(1, forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) != nil else { return nil }

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
                choose([3, 4], key: "renewal-long-years", marketID: marketID, teamID: team.id, attempt: attempt),
                forSeason: forSeason,
                maximumCareerSeasons: maximumCareerSeasons
            ), cappedYears(1, forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) != nil else { continue }
            let market = buildMarket(longYears: longYears, canonicalSalary: false)
            if isValid(market: market, currentTeamID: team.id, currentRole: role, maximumCareerSeasons: maximumCareerSeasons, marketScore: marketScore, pitcher: pitcher) {
                return market
            }
        }

        // All regular renewal years have now been exhausted. The canonical fallback deliberately
        // changes only the salary base; it keeps the documented years, roles, outlooks,
        // difficulties, IDs, and the post-cap duration semantics intact.
        let regularLongYears = Array(Set([3, 4].compactMap {
            cappedYears($0, forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons)
        })).sorted()
        for longYears in regularLongYears {
            let market = buildMarket(longYears: longYears, canonicalSalary: false)
            if isValid(market: market, currentTeamID: team.id, currentRole: role, maximumCareerSeasons: maximumCareerSeasons, marketScore: marketScore, pitcher: pitcher) {
                return market
            }
        }

        guard let fallbackLongYears = cappedYears(4, forSeason: forSeason, maximumCareerSeasons: maximumCareerSeasons) else { return nil }
        let fallback = buildMarket(longYears: fallbackLongYears, canonicalSalary: true)
        return isValid(market: fallback, currentTeamID: team.id, currentRole: role, maximumCareerSeasons: maximumCareerSeasons, marketScore: marketScore, pitcher: pitcher) ? fallback : nil
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
        currentContract: ProContractRecord? = nil
    ) -> ProContractMarket? {
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
        pitcher: PitcherSnapshot? = nil
    ) -> Bool {
        let remainingSeasons = maximumCareerSeasons - market.forSeason + 1
        let marketSuffix = ":\(market.forSeason):\(market.kind.rawValue)"
        let marketIdentity = market.id.hasPrefix("market:") && market.id.hasSuffix(marketSuffix)
            ? String(market.id.dropFirst("market:".count).dropLast(marketSuffix.count))
            : ""
        guard !market.id.isEmpty,
              !marketIdentity.isEmpty,
              !marketIdentity.contains("::"),
              market.forSeason >= 1,
              market.forSeason <= maximumCareerSeasons,
              remainingSeasons >= 1,
              !market.offers.isEmpty,
              Set(market.offers.map(\.id)).count == market.offers.count,
              market.offers.allSatisfy({ offer in
                  (1...4).contains(offer.years)
                      && offer.years <= maximumCareerSeasons - market.forSeason + 1
                      && offer.annualSalary >= 30_000_000
                      && offer.annualSalary <= 1_500_000_000
                      && offer.annualSalary % 10_000_000 == 0
                      && !offer.teamID.isEmpty
                      && offer.id == "offer:\(market.id):\(offer.teamID):\(offer.contractKind.rawValue)"
                      && offer.signingBonus == nil
                      && offer.expectation.target >= 1
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
                  long.years <= min(4, remainingSeasons),
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
                let canonicalTuple = long.years == min(4, remainingSeasons)
                    && prove.years == 1
                    && long.annualSalary == canonicalLongSalary
                    && prove.annualSalary == canonicalProveSalary
                guard canonicalTuple || regularTuple else { return false }
            }
        } else if market.kind == .freeAgency {
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
        } else {
            return false
        }
        return nonDominated(market.offers, currentRole: currentRole)
    }

    public static func isNonDominated(_ offers: [ProContractOffer], currentRole: ProRole) -> Bool {
        nonDominated(offers, currentRole: currentRole)
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

    private static func nonDominated(_ offers: [ProContractOffer], currentRole: ProRole) -> Bool {
        guard Set(offers.map(\.id)).count == offers.count else { return false }
        for index in offers.indices {
            for other in offers.indices where index != other {
                let lhs = axes(for: offers[index], currentRole: currentRole)
                let rhs = axes(for: offers[other], currentRole: currentRole)
                let pairs = zip(lhs, rhs)
                let dominates = pairs.allSatisfy { $0.0 >= $0.1 }
                    && pairs.contains { $0.0 > $0.1 }
                if dominates { return false }
            }
        }
        return true
    }

    private static func axes(for offer: ProContractOffer, currentRole: ProRole) -> [Int] {
        let expectationValue: Int = switch offer.expectation.difficulty {
        case .accessible: 2
        case .standard: 1
        case .stretch: 0
        }
        return [
            offer.annualSalary,
            offer.years,
            roleValue(current: currentRole, promised: offer.rolePromise),
            offer.preservesTeamLegacy ? 2 : (offer.outlook == .opportunity ? 1 : 0),
            expectationValue,
        ]
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
        preservesTeamLegacy: Bool
    ) -> ProContractOffer {
        ProContractOffer(
            id: "offer:\(marketID):\(teamID):\(contractKind.rawValue)",
            teamID: teamID,
            years: years,
            annualSalary: annualSalary,
            signingBonus: nil,
            contractKind: contractKind,
            rolePromise: role,
            outlook: outlook,
            expectation: expectation,
            preservesTeamLegacy: preservesTeamLegacy
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

    public static func projectedPitcher(for pitcher: PitcherSnapshot, effectiveAge: Int) -> PitcherSnapshot {
        let decline = effectiveAge >= 33 ? 1 : 0
        guard decline > 0 else { return pitcher }
        return PitcherSnapshot(
            id: pitcher.id,
            name: pitcher.name,
            stuff: clamp(pitcher.stuff - decline, 20, 80),
            command: pitcher.command,
            movement: clamp(pitcher.movement - decline, 20, 80),
            stamina: pitcher.stamina,
            pitchProfiles: pitcher.pitchProfiles,
            throwingHand: pitcher.throwingHand
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
