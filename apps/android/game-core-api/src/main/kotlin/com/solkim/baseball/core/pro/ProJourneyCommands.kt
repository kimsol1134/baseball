package com.solkim.baseball.core.pro


public object ProJourneyWire {
    public const val COMMAND_SCHEMA: String = "baseball-pro-career-command-v2"
    public const val SCHEMA_VERSION: Int = 2
}

public sealed interface ProJourneyCommand {
    public data class Start(
        val careerId: String,
        val teamId: String,
        val draftRound: Int = 2,
        val overallPick: Int = 18,
        val signingBonus: Long = 120_000_000L,
    ) : ProJourneyCommand

    public data class AcceptContract(val marketId: String, val offerId: String, val ambition: ProCareerAmbition?) : ProJourneyCommand
    public data class ReviewSeason(
        val season: Int,
        val teamId: String,
        val salary: Long,
        val merchandise: Long,
        val fanDelta: Int,
        val legacyDelta: Int,
        val hallOfFameDelta: Int,
        val contractYearsBefore: Int,
        val contractYearsAfter: Int,
        val nextRoute: ProSettlementNextRoute,
    ) : ProJourneyCommand
    public data class AcknowledgeSettlement(val settlementId: String) : ProJourneyCommand
    public data class ChooseInvestment(val season: Int, val investment: ProOffseasonInvestment, val focus: ProDevelopmentFocus?) : ProJourneyCommand
    public data class ApplyMediaChoice(
        val season: Int,
        val decisionId: String,
        val choiceId: String,
        val endorsementAmount: Long,
        val fanDelta: Int,
        val communityDelta: Int,
    ) : ProJourneyCommand
    public data class Retire(val lastTeamId: String?) : ProJourneyCommand
}

public data class ProJourneyCommandEnvelope(
    val commandId: String,
    val sessionId: String,
    val expectedRevision: ULong,
    val command: ProJourneyCommand,
    val schema: String = ProJourneyWire.COMMAND_SCHEMA,
    val schemaVersion: Int = ProJourneyWire.SCHEMA_VERSION,
) {
    init {
        require(commandId.isNotBlank() && commandId.length <= 128) { "pro.journey.command_id" }
        require(sessionId.isNotBlank() && sessionId.length <= 128) { "pro.journey.session_id" }
        require(schema == ProJourneyWire.COMMAND_SCHEMA) { "pro.journey.command_schema" }
        require(schemaVersion == ProJourneyWire.SCHEMA_VERSION) { "pro.journey.command_version" }
    }
}

public data class ProJourneyCommandResult(
    val state: ProCareerJourneyState,
    val nextSeed: ULong,
    val commandHash: String,
)
