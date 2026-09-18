package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.pitch.PitchCall
import com.solkim.baseball.core.pitch.PitchDelivery
import com.solkim.baseball.core.pitch.PitchKind

public object HighSchoolPhase4Wire {
    public const val SCHEMA: String = "baseball-high-school-phase4-command-v1"
    public const val SCHEMA_VERSION: Int = 1
    public const val MAX_COMMAND_ID_LENGTH: Int = 128
}

public object HighSchoolRebirthEntryPath {
    public const val QUICK_REBIRTH: String = "quick_rebirth"
    public const val CUSTOMIZE: String = "customize"
    public const val COMPLETION_FLOW: String = "completion_flow"
    public val values: Set<String> = setOf(QUICK_REBIRTH, CUSTOMIZE, COMPLETION_FLOW)

    public fun requireValid(value: String) {
        require(value in values) { "rebirth.entry_path" }
    }
}

public sealed interface HighSchoolPhase4Command {
    public data class Start(val request: HighSchoolPhase4StartRequest) : HighSchoolPhase4Command
    public data class StartConfigured(val request: HighSchoolPhase4StartRequest, val primaryPitch: PitchKind, val learningPitch: PitchKind) : HighSchoolPhase4Command
    public data class ConfigureRebirth(val seed: String, val dayKey: String, val setup: HighSchoolRebirthSetup) : HighSchoolPhase4Command
    public data object BeginTutorial : HighSchoolPhase4Command
    public data class CompleteTutorial(val seed: String) : HighSchoolPhase4Command
    public data class ChooseSchool(val seed: String, val schoolId: HighSchoolSchoolId) : HighSchoolPhase4Command
    public data class SelectPledge(val pledgeId: String) : HighSchoolPhase4Command
    public data class Training(
        val seed: String,
        val focus: HighSchoolTrainingFocus,
        val intensity: HighSchoolTrainingIntensity,
        val targetPitch: PitchKind? = null,
    ) : HighSchoolPhase4Command
    public data class TrainingBlock(
        val seed: String,
        val requests: List<Pair<HighSchoolTrainingFocus, HighSchoolTrainingIntensity>>,
        val targetPitch: PitchKind? = null,
        val stopForSafety: Boolean = false,
    ) : HighSchoolPhase4Command
    public data class Relationship(
        val seed: String,
        val response: HighSchoolRelationshipResponse,
    ) : HighSchoolPhase4Command
    public data class ReserveImportantGame(val seed: String) : HighSchoolPhase4Command
    public data class SubmitPitch(
        val sessionId: String,
        val call: PitchCall,
        val delivery: PitchDelivery = PitchDelivery.NEUTRAL,
    ) : HighSchoolPhase4Command
    public data object ContinueOuting : HighSchoolPhase4Command
    public data object FinishImportantGame : HighSchoolPhase4Command
    public data class ChooseAwakening(val seed: String, val awakening: HighSchoolAwakening) : HighSchoolPhase4Command
    public data class AdvanceChapter(val seed: String) : HighSchoolPhase4Command
    public data class ClaimChapterGame(val seed: String) : HighSchoolPhase4Command
    public data class ResolveDraft(val seed: String) : HighSchoolPhase4Command
    public data object PrepareLegacy : HighSchoolPhase4Command
    public data class SelectLegacy(val legacyId: String) : HighSchoolPhase4Command
    public data object FinalizeArchive : HighSchoolPhase4Command
    public data class BeginRebirth(
        val seed: String,
        val dayKey: String,
        /** The actual product entry path; old two-field command wires mean completion_flow. */
        val entryPath: String = HighSchoolRebirthEntryPath.COMPLETION_FLOW,
    ) : HighSchoolPhase4Command {
        init { HighSchoolRebirthEntryPath.requireValid(entryPath) }
    }
    public data object StartChallenge : HighSchoolPhase4Command
    public data class StartSeedChallenge(val seed: String, val life: Int, val presetId: String) : HighSchoolPhase4Command
    public data object EndChallenge : HighSchoolPhase4Command
    public data object ClaimWeeklyReward : HighSchoolPhase4Command
    public data class SaveReturnPlan(val plan: HighSchoolReturnPlan) : HighSchoolPhase4Command
    /** C# Meta's save-backed experiment/receipt preparation command. */
    public data class PrepareReturnPlan(val dayKey: String, val developmentRulesVersion: Int) : HighSchoolPhase4Command
    public data class SaveNextRunIntent(val intent: HighSchoolNextRunIntent) : HighSchoolPhase4Command
    public data object ClearNextRunIntent : HighSchoolPhase4Command
    public data object DismissReturnPlan : HighSchoolPhase4Command
    public data class AcknowledgeAchievement(val achievementId: String) : HighSchoolPhase4Command
}

public data class HighSchoolPhase4CommandEnvelope(
    val schema: String = HighSchoolPhase4Wire.SCHEMA,
    val schemaVersion: Int = HighSchoolPhase4Wire.SCHEMA_VERSION,
    val commandId: String,
    val sessionId: String,
    val expectedRevision: ULong,
    val command: HighSchoolPhase4Command,
) {
    public fun validate() {
        require(schema == HighSchoolPhase4Wire.SCHEMA) { "command.schema" }
        require(schemaVersion == HighSchoolPhase4Wire.SCHEMA_VERSION) { "command.schemaVersion" }
        require(commandId.isNotBlank() && commandId.length <= HighSchoolPhase4Wire.MAX_COMMAND_ID_LENGTH) { "command.commandId" }
        require(sessionId.isNotBlank() && sessionId.length <= HighSchoolPhase4Wire.MAX_COMMAND_ID_LENGTH) { "command.sessionId" }
    }
}

public data class HighSchoolPhase4DispatchResult(
    val state: HighSchoolPhase4State,
    val eventHash: String,
    val duplicate: Boolean,
)

public class HighSchoolPhase4CommandException(message: String) : IllegalArgumentException(message)
