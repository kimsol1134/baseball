package com.solkim.baseball.core.pro

import com.solkim.baseball.core.pitch.PitchCall
import com.solkim.baseball.core.pitch.PitchDelivery
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchIntensity
import com.solkim.baseball.core.pitch.PitchZone
import com.solkim.baseball.core.pitch.ThrowingHand
import com.solkim.baseball.core.pitch.ZoneIntent

public object ProWire {
    public const val STATE_SCHEMA: String = "baseball-pro-state-v1"
    public const val COMMAND_SCHEMA: String = "baseball-pro-command-v1"
    /** Command envelopes and state payloads evolve independently. */
    public const val STATE_SCHEMA_VERSION: Int = 7
    public const val SCHEMA_VERSION: Int = 1
    public const val MAX_COMMAND_ID_LENGTH: Int = 128
}

public sealed interface ProCommand {
    public data class StartLinked(val request: ProStartLinkedRequest) : ProCommand
    public data class StartDirect(val request: ProStartDirectRequest) : ProCommand
    public data class RequestRole(val seed: String, val requested: ProRole) : ProCommand
    public data object SignContract : ProCommand
    public data class AcceptContractOffer(
        val seed: String,
        val offerId: String,
        val ambition: ProCareerAmbition? = null,
    ) : ProCommand
    public data class PlanWeek(val seed: String, val plan: ProWeekPlan, val targetPitch: PitchKind? = null) : ProCommand
    public data class AdvanceSegment(
        val seed: String,
        val plan: ProWeekPlan,
        val targetPitch: PitchKind? = null,
        val maximumWeeks: Int = 24,
    ) : ProCommand
    public data class ApplySeasonDecision(val seed: String, val decisionId: String, val choiceId: String) : ProCommand
    public data class ReserveImportantGame(val seed: String) : ProCommand
    public data class SubmitPitch(val pitchSessionId: String, val call: PitchCall, val delivery: PitchDelivery = PitchDelivery.NEUTRAL) : ProCommand
    public data object ContinueOuting : ProCommand
    public data object FinishImportantGame : ProCommand
    public data object HandOffOuting : ProCommand
    public data class ReviewSeason(val seed: String) : ProCommand
    public data class AcknowledgeSeasonSettlement(val seed: String, val settlementId: String) : ProCommand
    public data class ChooseOffseason(val seed: String, val decision: OffseasonDecision) : ProCommand
    public data class ChooseInvestment(
        val seed: String,
        val investment: ProOffseasonInvestment,
        val focus: ProDevelopmentFocus? = null,
    ) : ProCommand
    public data class SelectLegacy(val legacyId: String) : ProCommand
    public data object NormalizeBalance : ProCommand
    public data class RespondNationalTeamCall(val seed: String, val accepted: Boolean) : ProCommand
    public data class StartNationalFinal(val seed: String) : ProCommand
    public data class ResolveNationalFinalAutomatically(val seed: String) : ProCommand
    public data class AcknowledgeNationalTeamResult(val seed: String) : ProCommand
}

public data class ProCommandEnvelope(
    val schema: String = ProWire.COMMAND_SCHEMA,
    val schemaVersion: Int = ProWire.SCHEMA_VERSION,
    val commandId: String,
    val sessionId: String,
    val expectedRevision: ULong,
    val command: ProCommand,
) {
    public fun validate() {
        require(schema == ProWire.COMMAND_SCHEMA) { "pro.command.schema" }
        require(schemaVersion == ProWire.SCHEMA_VERSION) { "pro.command.version" }
        require(commandId.isNotBlank() && commandId.length <= ProWire.MAX_COMMAND_ID_LENGTH) { "pro.command.id" }
        require(sessionId.isNotBlank() && sessionId.length <= ProWire.MAX_COMMAND_ID_LENGTH) { "pro.command.session" }
    }
}

public class ProCommandException(message: String) : IllegalArgumentException(message)
