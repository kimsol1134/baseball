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
    /// v10 national-team hook. Missing on legacy saves; nil means no overseas interest yet.
    public let overseasInterest: Bool?

    public init(
        fanSupport: Int = 0,
        lastMerchandiseTier: ProMerchandiseTier? = nil,
        endorsementSeasons: [Int] = [],
        overseasInterest: Bool? = nil
    ) {
        self.fanSupport = fanSupport
        self.lastMerchandiseTier = lastMerchandiseTier
        self.endorsementSeasons = endorsementSeasons
        self.overseasInterest = overseasInterest
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
    case equipment
    case personalTrainer = "personal_trainer"
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
    case climateStabilization = "climate_stabilization"
    case equipmentEdge = "equipment_edge"
    case trainingEfficiency = "training_efficiency"
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
    public let arcTitleID: String?
    public let arcSummaryID: String?

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
        nextRoute: ProSettlementNextRoute,
        arcTitleID: String? = nil,
        arcSummaryID: String? = nil
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
        self.arcTitleID = arcTitleID
        self.arcSummaryID = arcSummaryID
    }

    private enum CodingKeys: String, CodingKey {
        case id, season, teamID, stats, newAwardIDs, newMilestoneIDs, salaryIncome, merchandiseIncome
        case fanBefore, fanAfter, fanDelta, fanReasons, merchandiseTier
        case teamLegacyBefore, teamLegacyAfter, hallOfFameBefore, hallOfFameAfter
        case contractYearsBefore, contractYearsAfter, contractExpectation, contractExpectationActual
        case contractExpectationMet, goalProgressBefore, goalProgressAfter, goalCompleted, nextRoute
        case arcTitleID, arcSummaryID
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
            nextRoute: try container.decode(ProSettlementNextRoute.self, forKey: .nextRoute),
            arcTitleID: try container.decodeIfPresent(String.self, forKey: .arcTitleID),
            arcSummaryID: try container.decodeIfPresent(String.self, forKey: .arcSummaryID)
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
    case longTerm = "long_term"
}

public enum ProTeamOutlook: String, Codable, Sendable {
    case opportunity
    case balanced
    case contender
}

public enum ProClubInterest: String, Codable, Sendable {
    case hot
    case warm
    case cool
}

public struct ProClubInterestSignal: Codable, Equatable, Sendable {
    public let level: ProClubInterest
    public let reason: String

    public init(level: ProClubInterest, reason: String) {
        self.level = level
        self.reason = reason
    }
}

public enum ProContractCounterKind: String, Codable, Sendable {
    case extraYear = "extra_year"
    case raiseSalary = "raise_salary"
}

public struct ProContractCounterState: Codable, Equatable, Sendable {
    public let kind: ProContractCounterKind
    public let accepted: Bool
    public let applied: Bool

    public init(kind: ProContractCounterKind, accepted: Bool, applied: Bool) {
        self.kind = kind
        self.accepted = accepted
        self.applied = applied
    }
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
    /// v10 FA contact signal. Missing on v9 and earlier markets.
    public let interest: ProClubInterestSignal?

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
        preservesTeamLegacy: Bool,
        interest: ProClubInterestSignal? = nil
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
        self.interest = interest
    }

    private enum CodingKeys: String, CodingKey {
        case id, teamID, years, annualSalary, signingBonus, contractKind, rolePromise, outlook, expectation, preservesTeamLegacy, interest
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            teamID: try container.decode(String.self, forKey: .teamID),
            years: try container.decode(Int.self, forKey: .years),
            annualSalary: try container.decode(Int.self, forKey: .annualSalary),
            signingBonus: try container.decodeIfPresent(Int.self, forKey: .signingBonus),
            contractKind: try container.decode(ProContractKind.self, forKey: .contractKind),
            rolePromise: try container.decode(ProRole.self, forKey: .rolePromise),
            outlook: try container.decode(ProTeamOutlook.self, forKey: .outlook),
            expectation: try container.decode(ProContractExpectation.self, forKey: .expectation),
            preservesTeamLegacy: try container.decode(Bool.self, forKey: .preservesTeamLegacy),
            interest: try container.decodeIfPresent(ProClubInterestSignal.self, forKey: .interest)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(teamID, forKey: .teamID)
        try container.encode(years, forKey: .years)
        try container.encode(annualSalary, forKey: .annualSalary)
        try container.encode(signingBonus, forKey: .signingBonus)
        try container.encode(contractKind, forKey: .contractKind)
        try container.encode(rolePromise, forKey: .rolePromise)
        try container.encode(outlook, forKey: .outlook)
        try container.encode(expectation, forKey: .expectation)
        try container.encode(preservesTeamLegacy, forKey: .preservesTeamLegacy)
        try container.encodeIfPresent(interest, forKey: .interest)
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
    /// v10 stay negotiation. Missing on v9 and earlier markets.
    public let counterOffer: ProContractCounterState?

    public init(
        id: String,
        kind: ProContractMarketKind,
        forSeason: Int,
        generatedAtRevision: UInt64,
        offers: [ProContractOffer],
        draftRound: Int? = nil,
        overallPick: Int? = nil,
        counterOffer: ProContractCounterState? = nil
    ) {
        self.id = id
        self.kind = kind
        self.forSeason = forSeason
        self.generatedAtRevision = generatedAtRevision
        self.offers = offers
        self.draftRound = draftRound
        self.overallPick = overallPick
        self.counterOffer = counterOffer
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, forSeason, generatedAtRevision, offers, draftRound, overallPick, counterOffer
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            kind: try container.decode(ProContractMarketKind.self, forKey: .kind),
            forSeason: try container.decode(Int.self, forKey: .forSeason),
            generatedAtRevision: try container.decode(UInt64.self, forKey: .generatedAtRevision),
            offers: try container.decode([ProContractOffer].self, forKey: .offers),
            draftRound: try container.decodeIfPresent(Int.self, forKey: .draftRound),
            overallPick: try container.decodeIfPresent(Int.self, forKey: .overallPick),
            counterOffer: try container.decodeIfPresent(ProContractCounterState.self, forKey: .counterOffer)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(forSeason, forKey: .forSeason)
        try container.encode(generatedAtRevision, forKey: .generatedAtRevision)
        try container.encode(offers, forKey: .offers)
        try container.encodeIfPresent(draftRound, forKey: .draftRound)
        try container.encodeIfPresent(overallPick, forKey: .overallPick)
        try container.encodeIfPresent(counterOffer, forKey: .counterOffer)
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
    /// v5 노화 갈림길에서 회복 연도를 고르면 true. 다음 오프시즌 하락만 완화한다.
    public let recoveryYearPending: Bool?

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
        ),
        recoveryYearPending: Bool? = nil
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
        self.recoveryYearPending = recoveryYearPending
    }
}

public enum ProRetirementHonorKind: String, Codable, Identifiable, Sendable {
    case hallOfFame = "hall_of_fame"
    case retiredNumber = "retired_number"
    case clubHall = "club_hall"
    case ambitionCompleted = "ambition_completed"
    case careerEarnings = "career_earnings"
    case nationalGold = "national_gold"

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
        let rulesVersion = journey?.rulesVersion ?? 1
        let lastTeamLegacy = lastRecord.map { ProTeamLegacyRules.score(record: $0, rulesVersion: rulesVersion) } ?? 0
        let retiredNumberEligible = lastRecord.map {
            $0.completedSeasons >= 8
                && lastTeamLegacy >= 80
                && fanSupport >= 60
        } ?? false
        let clubHallTeamIDs = records
            .filter {
                $0.completedSeasons >= 6
                    && ProTeamLegacyRules.score(record: $0, rulesVersion: rulesVersion) >= 65
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
            careerEarnings: journey?.finances.careerEarnings ?? 0,
            nationalGoldCount: ProNationalTeamRules.goldCount(in: state.nationalTeamHistory)
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
        careerEarnings: Int64,
        nationalGoldCount: Int = 0
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
        if nationalGoldCount > 0 {
            honors.append(ProRetirementHonor(
                id: "honor:\(careerID):\(ProRetirementHonorKind.nationalGold.rawValue):none",
                kind: .nationalGold,
                teamID: nil,
                referenceID: nil,
                value: Int64(nationalGoldCount)
            ))
        }
        return honors
    }

    private static func rank(for kind: ProRetirementHonorKind) -> Int {
        switch kind {
        case .hallOfFame: 0
        case .retiredNumber: 1
        case .clubHall: 2
        case .ambitionCompleted: 3
        case .careerEarnings: 4
        case .nationalGold: 5
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
    public static func awardContentIDs(stats: ProSeasonStats, rulesVersion: Int) -> [String] {
        var ids: [String] = []
        let ra9 = stats.inningsOuts == 0 ? Int.max : stats.runsAllowed * 27_000 / stats.inningsOuts
        let bb9 = stats.inningsOuts == 0 ? Int.max : stats.walks * 27_000 / stats.inningsOuts
        let h9 = stats.inningsOuts == 0 ? Int.max : stats.hits * 27_000 / stats.inningsOuts
        if rulesVersion >= 3 {
            // v2 문턱은 초말 전환 아웃이 유실되던 시절(이닝 ~1/6 과소집계, 비율 지표
            // 과대평가)에 맞춰져 있었다. 집계 수정 후 같은 문턱의 수상 빈도가 2.4배로
            // 뛰어 영구결번률이 밴드(8~20%)를 넘었다 — 실측 지표 기준으로 되돌린다.
            if stats.strikeouts >= 180 { ids.append("pro.award.strikeouts") }
            if ra9 < 2_400, stats.games >= 20, stats.inningsOuts >= 380 {
                ids.append("pro.award.run-prevention")
            }
            if bb9 < 1_500, stats.inningsOuts >= 380 { ids.append("pro.award.command") }
            if h9 < 6_800, stats.inningsOuts >= 380 { ids.append("pro.award.hits") }
            if stats.inningsOuts >= 540 { ids.append("pro.award.innings") }
        } else if rulesVersion >= 2 {
            if stats.strikeouts >= 180 { ids.append("pro.award.strikeouts") }
            if ra9 < 2_700, stats.games >= 20, stats.inningsOuts >= 360 {
                ids.append("pro.award.run-prevention")
            }
            if bb9 < 1_800, stats.inningsOuts >= 360 { ids.append("pro.award.command") }
            if h9 < 7_500, stats.inningsOuts >= 360 { ids.append("pro.award.hits") }
            if stats.inningsOuts >= 486 { ids.append("pro.award.innings") }
        } else {
            if stats.strikeouts >= 120 { ids.append("pro.award.strikeouts") }
            if ra9 < 3_000, stats.games >= 20 { ids.append("pro.award.run-prevention") }
            if bb9 < 2_500, stats.inningsOuts >= 180 { ids.append("pro.award.command") }
            if h9 < 8_500, stats.inningsOuts >= 180 { ids.append("pro.award.hits") }
            if stats.inningsOuts >= 360 { ids.append("pro.award.innings") }
        }
        return ids
    }

    public static func currentSeasonRecognitions(
        careerID: String,
        season: Int,
        teamID: String,
        stats: ProSeasonStats,
        level: ProLevel,
        rulesVersion: Int
    ) -> [ProCareerRecognition] {
        var values: [ProCareerRecognition] = awardContentIDs(stats: stats, rulesVersion: rulesVersion).map {
            .init(careerID: careerID, kind: .award, contentID: $0, season: season, teamID: teamID)
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
        score(record: record, rulesVersion: 1)
    }

    public static func score(record: ProTeamCareerRecord, rulesVersion: Int) -> Int {
        if rulesVersion >= 2 {
            let tenure = min(20, max(0, record.completedSeasons) * 2)
            let strikeouts = min(30, max(0, record.strikeouts) / 40)
            let workload = min(18, max(0, record.inningsOuts) / 200)
            let awards = min(20, max(0, record.awardCount) * 5)
            let continuity = min(8, max(0, record.consecutiveSeasons))
            let community = min(8, max(0, record.communityPoints))
            return min(100, tenure + strikeouts + workload + awards + continuity + community)
        }
        let tenure = min(40, max(0, record.completedSeasons) * 5)
        let strikeouts = min(25, max(0, record.strikeouts) / 40)
        let workload = min(15, max(0, record.inningsOuts) / 180)
        let awards = min(12, max(0, record.awardCount) * 4)
        let continuity = min(8, max(0, record.consecutiveSeasons))
        let community = min(8, max(0, record.communityPoints))
        return min(100, tenure + strikeouts + workload + awards + continuity + community)
    }

    public static func tier(record: ProTeamCareerRecord) -> ProTeamLegacyTier {
        tier(record: record, rulesVersion: 1)
    }

    public static func tier(record: ProTeamCareerRecord, rulesVersion: Int) -> ProTeamLegacyTier {
        let score = score(record: record, rulesVersion: rulesVersion)
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
        score(record: record, rulesVersion: 1)
    }

    public static func score(record: ProTeamCareerRecord, rulesVersion: Int) -> Int {
        ProTeamCareerRecordRules.score(record: record, rulesVersion: rulesVersion)
    }

    public static func tier(record: ProTeamCareerRecord) -> ProTeamLegacyTier {
        tier(record: record, rulesVersion: 1)
    }

    public static func tier(record: ProTeamCareerRecord, rulesVersion: Int) -> ProTeamLegacyTier {
        ProTeamCareerRecordRules.tier(record: record, rulesVersion: rulesVersion)
    }

    /// Returns the next tier's complete gate projection. Score-only consumers should use
    /// `nextThreshold(record:)` below; UI that explains progress must use this value so a
    /// satisfied score gate cannot hide a remaining completed-season gate.
    public static func nextTierProjection(record: ProTeamCareerRecord) -> Threshold? {
        nextTierProjection(record: record, rulesVersion: 1)
    }

    public static func nextTierProjection(record: ProTeamCareerRecord, rulesVersion: Int) -> Threshold? {
        switch tier(record: record, rulesVersion: rulesVersion) {
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
        nextThreshold(record: record, rulesVersion: 1)
    }

    public static func nextThreshold(record: ProTeamCareerRecord, rulesVersion: Int) -> Int? {
        guard let projection = nextTierProjection(record: record, rulesVersion: rulesVersion) else { return nil }
        return max(score(record: record, rulesVersion: rulesVersion), projection.minimumScore)
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
        let rulesVersion = state.journeyState?.rulesVersion ?? 1
        let record = goal.anchorTeamID.flatMap {
            ProTeamCareerRecordRules.record(teamID: $0, in: records)
        }
        let metrics: [ProCareerGoalMetric]
        switch goal.ambition {
        case .franchiseIcon:
            metrics = [
                .init(kind: .anchorTeamSeasons, current: record?.completedSeasons ?? 0, target: 8),
                .init(kind: .anchorTeamLegacy, current: record.map { ProTeamCareerRecordRules.score(record: $0, rulesVersion: rulesVersion) } ?? 0, target: 80),
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
        let currentlyMeets = metrics.allSatisfy { $0.current >= $0.target }
        return .init(
            ambition: goal.ambition,
            metrics: metrics,
            completed: goal.completedSeason != nil || currentlyMeets
        )
    }

    /// Settlement snapshots keep `completed` locked once an ambition is done. A later
    /// gap year or free-agency return can drop the live score, so a locked completion
    /// may show currents below target. A first completion still has to meet every bar.
    public static func settlementMetricsAreConsistent(
        _ progress: ProCareerGoalProgress,
        allowingLockedDip: Bool
    ) -> Bool {
        let meets = progress.metrics.allSatisfy { $0.current >= $0.target }
        if progress.completed {
            return meets || allowingLockedDip
        }
        return !meets
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
            values.append(contentsOf: market.offers.sorted { $0.id < $1.id }.map { offer in
                var token = "offer:\(offer.id):\(offer.teamID):\(offer.years):\(offer.annualSalary):\(offer.signingBonus.map(String.init) ?? "none"):\(offer.contractKind.rawValue):\(offer.rolePromise.rawValue):\(offer.outlook.rawValue):\(offer.expectation.kind.rawValue):\(offer.expectation.target):\(offer.expectation.difficulty.rawValue):\(offer.preservesTeamLegacy ? 1 : 0)"
                if let interest = offer.interest {
                    token += ":interest:\(interest.level.rawValue):\(interest.reason)"
                }
                return token
            })
            if let counter = market.counterOffer {
                values.append("counter:\(counter.kind.rawValue):\(counter.accepted ? 1 : 0):\(counter.applied ? 1 : 0)")
            }
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
        if journey.recoveryYearPending == true {
            values.append("recovery_year:1")
        }
        if let settlement = journey.lastSettlement {
            values.append("settlement:\(settlement.id):\(settlement.season):\(settlement.teamID):stats:\(statsToken(settlement.stats)):awards:\(settlement.newAwardIDs.sorted().joined(separator: ",")):milestones:\(settlement.newMilestoneIDs.sorted().joined(separator: ",")):salary:\(settlement.salaryIncome):merch:\(settlement.merchandiseIncome):fan:\(settlement.fanBefore):\(settlement.fanAfter):legacy:\(settlement.teamLegacyBefore):\(settlement.teamLegacyAfter):hof:\(settlement.hallOfFameBefore):\(settlement.hallOfFameAfter):contract:\(settlement.contractYearsBefore):\(settlement.contractYearsAfter):expectation:\(expectationToken(settlement.contractExpectation)):\(settlement.contractExpectationActual.map(String.init) ?? "none"):\(settlement.contractExpectationMet.map { $0 ? "1" : "0" } ?? "none"):goal-before:\(progressToken(settlement.goalProgressBefore)):goal-after:\(progressToken(settlement.goalProgressAfter)):goal-completed:\(settlement.goalCompleted ? 1 : 0):next:\(settlement.nextRoute.rawValue)")
            if let arcTitleID = settlement.arcTitleID {
                values.append("settlement-arc:\(arcTitleID):\(settlement.arcSummaryID ?? "none")")
            }
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
        case .equipment: 30_000_000
        case .personalTrainer: 40_000_000
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

