package com.solkim.baseball.core.pro

/**
 * Wave 6 journey contract. These are wire-shaped values: persisted state contains catalog IDs,
 * raw enum values, and integer money only. Localized copy belongs to the presentation catalog.
 */
public enum class ProCareerGoalOutcome(public val wire: String) {
    COMPLETED("completed"),
    REPLACED("replaced"),
    RETIRED_INCOMPLETE("retired_incomplete"),
}

public enum class ProContractEndReason(public val wire: String) {
    EXPIRED("expired"),
    RETIRED("retired"),
    MIGRATED("migrated"),
}

public data class ProCareerGoalRecord(
    val id: String,
    val ambition: ProCareerAmbition,
    val selectedSeason: Int,
    val anchorTeamId: String?,
    val completedSeason: Int?,
    val endedSeason: Int,
    val outcome: ProCareerGoalOutcome,
)

public data class ProContractRecord(
    val contractId: String,
    val teamId: String,
    val kind: ProContractKind?,
    val signedSeason: Int,
    val totalYears: Int,
    val annualSalary: Long,
    val signingBonus: Long?,
    val rolePromise: ProRole,
    val expectation: ProContractExpectation?,
    val coveredSeasons: List<Int>,
    val fulfilledExpectationSeasons: List<Int>,
    val endedSeason: Int?,
    val endReason: ProContractEndReason?,
) {
    val id: String get() = contractId
}

public enum class ProCareerRecognitionKind(public val wire: String) {
    AWARD("award"),
    MILESTONE("milestone"),
}

public data class ProCareerRecognition(
    val id: String,
    val kind: ProCareerRecognitionKind,
    val contentId: String,
    val season: Int,
    val teamId: String?,
    val value: Int?,
)

public enum class ProOffseasonTransitionRoute(public val wire: String) {
    UNDER_CONTRACT("under_contract"),
    RENEWAL_MARKET("renewal_market"),
    FREE_AGENCY_MARKET("free_agency_market"),
}

public data class ProOffseasonTransition(
    val afterSeason: Int,
    val nextSeason: Int,
    val ageAdvanceYears: Int,
    val includesMilitaryService: Boolean,
    val route: ProOffseasonTransitionRoute,
)

public enum class ProJourneyMigrationSource(public val wire: String) {
    NEW_CAREER("new_career"),
    LEGACY_SAFE_BOUNDARY("legacy_safe_boundary"),
}

public data class ProJourneyMigration(
    val source: ProJourneyMigrationSource,
    val initializedSeason: Int,
    val financeStartsSeason: Int,
    val unassignedLegacyAwards: Int,
    val financeNoticePending: Boolean,
)

public data class ProTeamCareerRecord(
    val teamId: String,
    val completedSeasons: Int,
    val consecutiveSeasons: Int,
    val games: Int,
    val starts: Int,
    val inningsOuts: Int,
    val strikeouts: Int,
    val wins: Int,
    val saves: Int,
    val awardCount: Int,
    val communityPoints: Int,
    val lastSeason: Int?,
) {
    val id: String get() = teamId
}

public enum class ProCareerAmbition(public val wire: String) {
    FRANCHISE_ICON("franchise_icon"),
    RECORD_BOOK("record_book"),
    ENDURING_PRO("enduring_pro"),
}

public data class ProCareerGoalState(
    val id: String,
    val ambition: ProCareerAmbition,
    val selectedSeason: Int,
    val anchorTeamId: String?,
    val completedSeason: Int?,
)

public enum class ProCareerGoalMetricKind(public val wire: String) {
    ANCHOR_TEAM_SEASONS("anchor_team_seasons"),
    ANCHOR_TEAM_LEGACY("anchor_team_legacy"),
    HALL_OF_FAME_PROJECTION("hall_of_fame_projection"),
    AWARDS("awards"),
    PRO_SEASONS("pro_seasons"),
    MAJOR_SERVICE_YEARS("major_service_years"),
}

public data class ProCareerGoalMetric(
    val kind: ProCareerGoalMetricKind,
    val current: Int,
    val target: Int,
)

public data class ProCareerGoalProgress(
    val ambition: ProCareerAmbition,
    val metrics: List<ProCareerGoalMetric>,
    val completed: Boolean,
)

public enum class ProMerchandiseTier(public val wire: String) {
    LOCAL("local"),
    RISING("rising"),
    STAR("star"),
    ICON("icon"),
}

public data class ProReputationState(
    val fanSupport: Int = 0,
    val lastMerchandiseTier: ProMerchandiseTier? = null,
    val endorsementSeasons: List<Int> = emptyList(),
)

public enum class ProFanReasonKind(public val wire: String) {
    IMPORTANT_GAME_SCORELESS("important_game_scoreless"),
    IMPORTANT_GAME_RUNS_ALLOWED("important_game_runs_allowed"),
    SEASON_AWARD("season_award"),
    CAREER_MILESTONE("career_milestone"),
    SAME_TEAM_SEASON("same_team_season"),
    CONTRACT_EXPECTATION_MET("contract_expectation_met"),
    CONTRACT_EXPECTATION_MISSED("contract_expectation_missed"),
    CAREER_AMBITION_COMPLETED("career_ambition_completed"),
}

public data class ProFanReason(
    val id: String,
    val kind: ProFanReasonKind,
    val contentId: String,
    val delta: Int,
)

public enum class ProFinanceTransactionKind(public val wire: String) {
    SIGNING_BONUS("signing_bonus"),
    SALARY("salary"),
    MERCHANDISE("merchandise"),
    ENDORSEMENT("endorsement"),
    INVESTMENT("investment"),
}

public data class ProFinanceTransaction(
    val id: String,
    val season: Int,
    val kind: ProFinanceTransactionKind,
    val amount: Long,
)

public data class ProFinanceState(
    val careerEarnings: Long = 0,
    val availableFunds: Long = 0,
    val salaryCreditedThroughSeason: Int = 0,
    val transactions: List<ProFinanceTransaction> = emptyList(),
    val investmentSeason: Int? = null,
)

public enum class ProOffseasonInvestment(public val wire: String) {
    PITCH_LAB("pitch_lab"),
    RECOVERY_TEAM("recovery_team"),
    FAN_FOUNDATION("fan_foundation"),
    NONE("none"),
}

public enum class ProDevelopmentFocus(public val wire: String) {
    STUFF("stuff"),
    COMMAND("command"),
    MOVEMENT("movement"),
    STAMINA("stamina"),
}

public enum class ProSeasonBenefitKind(public val wire: String) {
    DEVELOPMENT_HEAD_START("development_head_start"),
    INJURY_MITIGATION("injury_mitigation"),
}

public data class ProSeasonBenefit(
    val kind: ProSeasonBenefitKind,
    val focus: ProDevelopmentFocus?,
    val remainingCharges: Int,
)

public enum class ProSettlementNextRoute(public val wire: String) {
    UNDER_CONTRACT("under_contract"),
    RENEWAL_MARKET("renewal_market"),
    FREE_AGENCY_ELIGIBLE("free_agency_eligible"),
    FORCED_RETIREMENT("forced_retirement"),
}

public data class ProSeasonSettlement(
    val id: String,
    val season: Int,
    val teamId: String,
    val salaryIncome: Long,
    val merchandiseIncome: Long,
    val fanBefore: Int,
    val fanAfter: Int,
    val fanDelta: Int,
    val fanReasons: List<ProFanReason>,
    val merchandiseTier: ProMerchandiseTier?,
    val teamLegacyBefore: Int,
    val teamLegacyAfter: Int,
    val hallOfFameBefore: Int,
    val hallOfFameAfter: Int,
    val contractYearsBefore: Int,
    val contractYearsAfter: Int,
    val contractExpectation: ProContractExpectation?,
    val contractExpectationActual: Int?,
    val contractExpectationMet: Boolean?,
    val goalProgressBefore: ProCareerGoalProgress?,
    val goalProgressAfter: ProCareerGoalProgress?,
    val goalCompleted: Boolean,
    val nextRoute: ProSettlementNextRoute,
)

public enum class ProContractMarketKind(public val wire: String) {
    ROOKIE("rookie"),
    RENEWAL("renewal"),
    FREE_AGENCY("free_agency"),
}

public enum class ProContractKind(public val wire: String) {
    ROOKIE("rookie"),
    RENEWAL_LONG("renewal_long"),
    PROVE_IT("prove_it"),
    FREE_AGENT("free_agent"),
}

public enum class ProTeamOutlook(public val wire: String) {
    OPPORTUNITY("opportunity"),
    BALANCED("balanced"),
    CONTENDER("contender"),
}

public enum class ProContractExpectationKind(public val wire: String) {
    MAJOR_ROSTER("major_roster"),
    INNINGS("innings"),
    STRIKEOUTS("strikeouts"),
    SAVES("saves"),
    RUN_PREVENTION("run_prevention"),
}

public enum class ProExpectationDifficulty(public val wire: String) {
    ACCESSIBLE("accessible"),
    STANDARD("standard"),
    STRETCH("stretch"),
}

public data class ProContractExpectation(
    val kind: ProContractExpectationKind,
    val target: Int,
    val difficulty: ProExpectationDifficulty,
)

public data class ProContractOffer(
    val id: String,
    val teamId: String,
    val years: Int,
    val annualSalary: Long,
    val signingBonus: Long?,
    val contractKind: ProContractKind,
    val rolePromise: ProRole,
    val outlook: ProTeamOutlook,
    val expectation: ProContractExpectation,
    val preservesTeamLegacy: Boolean,
)

public data class ProContractMarket(
    val id: String,
    val kind: ProContractMarketKind,
    val forSeason: Int,
    val generatedAtRevision: ULong,
    val offers: List<ProContractOffer>,
    val draftRound: Int? = null,
    val overallPick: Int? = null,
)

public enum class ProRetirementHonorKind(public val wire: String) {
    HALL_OF_FAME("hall_of_fame"),
    RETIRED_NUMBER("retired_number"),
    CLUB_HALL("club_hall"),
    AMBITION_COMPLETED("ambition_completed"),
    CAREER_EARNINGS("career_earnings"),
}

public data class ProRetirementHonor(
    val id: String,
    val kind: ProRetirementHonorKind,
    val teamId: String?,
    val referenceId: String?,
    val value: Long?,
)

public data class ProCareerRetirementProjection(
    val finalScore: Int,
    val lastTeamId: String?,
    val lastTeamSeasons: Int,
    val lastTeamLegacy: Int,
    val fanSupport: Int,
    val retiredNumberEligible: Boolean,
    val clubHallTeamIds: List<String>,
    val completedAmbitions: List<ProCareerAmbition>,
    val careerEarnings: Long,
    val honors: List<ProRetirementHonor>,
)

public data class ProCareerJourneyState(
    val rulesVersion: Int = 1,
    val activeGoal: ProCareerGoalState? = null,
    val goalHistory: List<ProCareerGoalRecord> = emptyList(),
    val pendingContractMarket: ProContractMarket? = null,
    val contractHistory: List<ProContractRecord> = emptyList(),
    val teamRecords: List<ProTeamCareerRecord> = emptyList(),
    val recognitions: List<ProCareerRecognition> = emptyList(),
    val reputation: ProReputationState = ProReputationState(),
    val finances: ProFinanceState = ProFinanceState(),
    val activeSeasonBenefit: ProSeasonBenefit? = null,
    val lastSettlement: ProSeasonSettlement? = null,
    val settlementAcknowledged: Boolean = true,
    val offseasonTransition: ProOffseasonTransition? = null,
    val retirementHonors: List<ProRetirementHonor> = emptyList(),
    val migration: ProJourneyMigration = ProJourneyMigration(
        ProJourneyMigrationSource.NEW_CAREER, 1, 1, 0, false,
    ),
) {
    init {
        require(rulesVersion in 1..ProJourneyKernel.CURRENT_JOURNEY_RULES_VERSION) { "pro.journey.rules_version" }
        require(reputation.fanSupport in 0..100) { "pro.journey.fan_support" }
        require(contractHistory.map { it.contractId }.distinct().size == contractHistory.size) { "pro.journey.contract_ids" }
        require(finances.transactions.map { it.id }.distinct().size == finances.transactions.size) { "pro.journey.transaction_ids" }
        require(teamRecords.map { it.teamId }.distinct().size == teamRecords.size) { "pro.journey.team_ids" }
    }
}
