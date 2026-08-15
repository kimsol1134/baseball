package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.highschool.HighSchoolPhase4State
import com.solkim.baseball.core.highschool.HighSchoolPhase4StartRequest
import com.solkim.baseball.core.pro.ProState
import com.solkim.baseball.core.highschool.HighSchoolPhase4Command
import com.solkim.baseball.core.pro.ProCommand
import com.solkim.baseball.model.Hashing

public enum class NativeAuthorityMode(public val wire: String) {
    LEGACY_ORACLE("legacyOracle"),
    NATIVE_SHADOW_READ_ONLY("nativeShadowReadOnly"),
    NATIVE_AUTHORITATIVE("nativeAuthoritative"),
}

public enum class GameStage(public val wire: String) {
    OPENING("opening"),
    SETUP("setup"),
    HIGH_SCHOOL("highSchool"),
    DRAFT("draft"),
    PRO("pro"),
    RETIREMENT("retirement"),
    LEGACY("legacy"),
    BETWEEN_LIVES("betweenLives"),
    DELETED("deleted"),
}

public enum class PitchBoundary(public val wire: String) {
    RESERVED("reserved"),
    PLAYING("playing"),
    COMMITTED("committed"),
    CONSUMED("consumed"),
    TERMINAL("terminal"),
    COMPLETED("completed"),
    SUSPENDED("suspended"),
    ABANDONED("abandoned"),
}

/** The only career kinds that may own an aggregate pitch. Daily is retired and has no wire. */
public enum class PitchCareerKind(public val wire: String) {
    HIGH_SCHOOL("highSchool"),
    PRO("pro"),
    TUTORIAL("tutorial"),
}

public const val TUTORIAL_CAREER_ID: String = "tutorial"

/**
 * Tutorial is a wire-compatible pitch kind, not an independent career.  Nonterminal pitches
 * belong to the active HighSchool prologue, and the tutorial lifecycle is durable HighSchool state.
 * Keep this rule in one place so reservation and restored aggregate validation cannot drift.
 */
internal fun GameAggregateState.requireActiveTutorialPitch(
    careerId: String,
    boundary: PitchBoundary,
    challengeRun: Boolean,
    errorPrefix: String,
) {
    require(careerId == TUTORIAL_CAREER_ID) { "$errorPrefix.career_mismatch" }
    require(!challengeRun) { "$errorPrefix.challenge_isolation" }
    val activeHighSchool = highSchool ?: throw IllegalArgumentException("$errorPrefix.highSchool_missing")
    require(meta.activeHighSchoolCareerId == activeHighSchool.run.careerId) { "$errorPrefix.active_career" }
    if (boundary in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED)) {
        // Retained terminal pitches keep the wire-safe tutorial identity and owner binding, but
        // do not require the old PROLOGUE/tutorial lifecycle after completion.
        require(stage != GameStage.OPENING && stage != GameStage.SETUP) { "$errorPrefix.stage" }
        return
    }
    require(stage == GameStage.HIGH_SCHOOL) { "$errorPrefix.stage" }
    require(activeHighSchool.run.phase == HighSchoolPhase.PROLOGUE) { "$errorPrefix.phase" }
    require(activeHighSchool.tutorial.started && !activeHighSchool.tutorial.completed) { "$errorPrefix.lifecycle" }
}

public data class PitchDurableState(
    val sessionId: String,
    val careerKind: PitchCareerKind,
    val careerId: String,
    val gameId: String,
    val seed: String,
    val boundary: PitchBoundary,
    val challengeRun: Boolean = false,
    val pitchIndex: Int = 0,
    val committedPitchIds: List<String> = emptyList(),
    val consumedPitchIds: List<String> = emptyList(),
    val terminalPitchId: String? = null,
    val resultHashes: List<String> = emptyList(),
    val checkpoint: String? = null,
    val suspendedFrom: PitchBoundary? = null,
    val abandonedReason: String? = null,
) {
    public fun validate() {
        require(sessionId.isNotBlank() && sessionId.length <= 128) { "pitch.session" }
        require(careerId.isNotBlank() && careerId.length <= 128) { "pitch.careerId" }
        require(gameId.isNotBlank() && gameId.length <= 128) { "pitch.gameId" }
        require(seed.isNotBlank() && seed.length <= 128) { "pitch.seed" }
        require(pitchIndex >= 0) { "pitch.index" }
        require(pitchIndex == committedPitchIds.size) { "pitch.index_committed_mismatch" }
        require(committedPitchIds.distinct().size == committedPitchIds.size) { "pitch.committed_duplicate" }
        require(consumedPitchIds.distinct().size == consumedPitchIds.size) { "pitch.consumed_duplicate" }
        require(consumedPitchIds.all { it in committedPitchIds }) { "pitch.consumed_unknown" }
        require(resultHashes.size == committedPitchIds.size) { "pitch.result_hash_count" }
        if (terminalPitchId != null) require(terminalPitchId in consumedPitchIds) { "pitch.terminal_unconsumed" }
        when (boundary) {
            PitchBoundary.RESERVED -> require(committedPitchIds.isEmpty() && consumedPitchIds.isEmpty() && terminalPitchId == null && suspendedFrom == null && abandonedReason == null) { "pitch.reserved_shape" }
            PitchBoundary.PLAYING -> require(committedPitchIds.isEmpty() && consumedPitchIds.isEmpty() && terminalPitchId == null && suspendedFrom == null && abandonedReason == null) { "pitch.playing_shape" }
            PitchBoundary.COMMITTED -> require(committedPitchIds.size == consumedPitchIds.size + 1 && terminalPitchId == null && suspendedFrom == null && abandonedReason == null) { "pitch.committed_shape" }
            PitchBoundary.CONSUMED -> require(committedPitchIds.size == consumedPitchIds.size && terminalPitchId == null && suspendedFrom == null && abandonedReason == null) { "pitch.consumed_shape" }
            PitchBoundary.TERMINAL -> require(terminalPitchId != null && committedPitchIds.size == consumedPitchIds.size && suspendedFrom == null && abandonedReason == null) { "pitch.terminal_shape" }
            PitchBoundary.COMPLETED -> require(terminalPitchId != null && committedPitchIds.size == consumedPitchIds.size && suspendedFrom == null && abandonedReason == null) { "pitch.completed_shape" }
            PitchBoundary.SUSPENDED -> require(suspendedFrom != null && suspendedFrom != PitchBoundary.COMPLETED && suspendedFrom != PitchBoundary.ABANDONED && abandonedReason == null) { "pitch.suspended_shape" }
            PitchBoundary.ABANDONED -> require(!abandonedReason.isNullOrBlank() && suspendedFrom == null && terminalPitchId == null) { "pitch.abandoned_shape" }
        }
    }
}

public data class GameSettingsState(
    val autoReleaseEnabled: Boolean = false,
    val soundEnabled: Boolean = true,
    val musicEnabled: Boolean = true,
    val hapticsEnabled: Boolean = true,
    val notificationsEnabled: Boolean = false,
    val highContrastEnabled: Boolean = false,
    val reducedMotionEnabled: Boolean = false,
)

public data class AnalyticsReceipt(
    val receiptId: String,
    val eventName: String,
    val revision: ULong,
    val commitment: String,
    val properties: List<Pair<String, String>> = emptyList(),
) {
    init {
        require(receiptId.isNotBlank() && receiptId.length <= 160) { "analytics.receiptId" }
        require(eventName.isNotBlank() && eventName.length <= 96) { "analytics.eventName" }
        require(properties.map { it.first }.distinct().size == properties.size) { "analytics.properties_duplicate" }
    }
}

public data class AnalyticsReceiptState(
    val receipts: List<AnalyticsReceipt> = emptyList(),
) {
    public fun contains(receiptId: String): Boolean = receipts.any { it.receiptId == receiptId }

    public fun validate(currentRevision: ULong) {
        require(receipts.map { it.receiptId }.distinct().size == receipts.size) { "analytics.receipt_duplicate" }
        require(receipts.all { it.revision in 1UL..currentRevision }) { "analytics.receipt_revision" }
    }
}

public data class GameMetaState(
    val completedGameCount: ULong = 0UL,
    val achievementIds: List<String> = emptyList(),
    val weeklyReceiptIds: List<String> = emptyList(),
    val returnPlanReceiptIds: List<String> = emptyList(),
    val decisionReceiptIds: List<String> = emptyList(),
    val activeHighSchoolCareerId: String? = null,
    val lifeArchiveCareerIds: List<String> = emptyList(),
) {
    public fun validate() {
        require(completedGameCount >= 0UL) { "meta.completed_games" }
        listOf(achievementIds, weeklyReceiptIds, returnPlanReceiptIds, decisionReceiptIds, lifeArchiveCareerIds)
            .forEach { values -> require(values.distinct().size == values.size && values.all(String::isNotBlank)) { "meta.receipts" } }
    }
}

public data class GameCommandReceipt(
    val commandId: String,
    val sessionId: String,
    val expectedRevision: ULong,
    val committedRevision: ULong,
    val commandHash: String,
    val resultHash: String,
    val eventName: String,
) {
    init {
        require(commandId.isNotBlank() && sessionId.isNotBlank()) { "receipt.identity" }
        require(commandHash.matches(Regex("[0-9a-f]{64}"))) { "receipt.commandHash" }
        require(resultHash.isNotBlank()) { "receipt.resultHash" }
    }
}

public data class GameAggregateState(
    val aggregateVersion: Int = CURRENT_AGGREGATE_VERSION,
    val revision: ULong,
    val installId: String,
    val stage: GameStage,
    val highSchool: HighSchoolPhase4State? = null,
    val pro: ProState? = null,
    val meta: GameMetaState = GameMetaState(),
    val pitch: PitchDurableState? = null,
    val settings: GameSettingsState = GameSettingsState(),
    val analytics: AnalyticsReceiptState = AnalyticsReceiptState(),
    val commandReceipts: List<GameCommandReceipt> = emptyList(),
    val deleted: Boolean = false,
    val commitment: String,
) {
    public fun validate() {
        require(aggregateVersion == CURRENT_AGGREGATE_VERSION) { "aggregate.version" }
        require(revision >= 0UL && installId.isNotBlank() && installId.length <= 128) { "aggregate.identity" }
        require(commandReceipts.map { it.commandId }.distinct().size == commandReceipts.size) { "aggregate.receipt_duplicate" }
        require(commandReceipts.zipWithNext().all { (a, b) -> b.committedRevision > a.committedRevision }) { "aggregate.receipt_order" }
        if (commandReceipts.isEmpty()) {
            require(revision == 0UL) { "aggregate.receipt_missing" }
        } else {
            require(commandReceipts.first().expectedRevision == 0UL && commandReceipts.first().committedRevision == 1UL) { "aggregate.receipt_first" }
            require(commandReceipts.zipWithNext().all { (a, b) -> b.expectedRevision == a.committedRevision && b.committedRevision == a.committedRevision + 1UL }) { "aggregate.receipt_revision" }
            require(commandReceipts.last().committedRevision == revision) { "aggregate.receipt_tail" }
        }
        meta.validate()
        analytics.validate(revision)
        pitch?.let {
            it.validate()
            when (it.careerKind) {
                PitchCareerKind.HIGH_SCHOOL -> {
                    val matchesCurrent = highSchool?.run?.careerId == it.careerId
                    val matchesArchive = highSchool?.archive?.any { archive -> archive.careerId == it.careerId } == true
                    require(matchesCurrent || matchesArchive) { "aggregate.pitch_highSchool_career_mismatch" }
                    if (it.boundary !in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED)) {
                        require(matchesCurrent && highSchool?.run?.phase != com.solkim.baseball.core.highschool.HighSchoolPhase.COMPLETED) { "aggregate.pitch_highSchool_not_active" }
                    }
                }
                PitchCareerKind.PRO -> {
                    require(pro != null && pro.careerId == it.careerId) { "aggregate.pitch_pro_career_mismatch" }
                    if (it.boundary !in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED)) {
                        require(pro.phase != com.solkim.baseball.core.pro.ProCareerPhase.COMPLETED) { "aggregate.pitch_pro_not_active" }
                    }
                }
                PitchCareerKind.TUTORIAL -> requireActiveTutorialPitch(
                    careerId = it.careerId,
                    boundary = it.boundary,
                    challengeRun = it.challengeRun,
                    errorPrefix = "aggregate.pitch_tutorial",
                )
            }
            require(!deleted) { "aggregate.pitch_deleted" }
        }
        highSchool?.let { com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel().validateSavedState(it) }
        pro?.let { com.solkim.baseball.core.pro.ProKernel().validateSavedState(it) }
        if (stage == GameStage.HIGH_SCHOOL) require(highSchool != null) { "aggregate.highSchool_missing" }
        if (stage == GameStage.PRO) require(pro != null) { "aggregate.pro_missing" }
        require(deleted == (stage == GameStage.DELETED)) { "aggregate.deleted_stage" }
        if (deleted) require(stage == GameStage.DELETED) { "aggregate.deleted_stage" }
        require(commitment == recomputeCommitment()) { "aggregate.commitment" }
    }

    public fun recomputeCommitment(): String {
        val receipts = commandReceipts.joinToString(",") { "${it.commandId}:${it.committedRevision}:${it.commandHash}:${it.resultHash}" }
        val pitchValue = pitch?.let {
            listOf(it.sessionId, it.careerKind.wire, it.careerId, it.gameId, it.seed, it.boundary.wire, it.challengeRun, it.pitchIndex, it.committedPitchIds.joinToString(";"), it.consumedPitchIds.joinToString(";"), it.terminalPitchId.orEmpty(), it.resultHashes.joinToString(";"), it.checkpoint.orEmpty(), it.suspendedFrom?.wire.orEmpty(), it.abandonedReason.orEmpty()).joinToString("|")
        }.orEmpty()
        val analytics = analytics.receipts.joinToString(",") { receipt ->
            "${receipt.receiptId}:${receipt.eventName}:${receipt.revision}:${receipt.commitment}:${receipt.properties.joinToString(";") { "${it.first}=${it.second}" }}"
        }
        val receiptsValue = commandReceipts.joinToString(",") {
            "${it.commandId}:${it.sessionId}:${it.expectedRevision}:${it.committedRevision}:${it.commandHash}:${it.resultHash}:${it.eventName}"
        }
        return Hashing.fnv1a64Hex(
            listOf(
                aggregateVersion, revision, installId, stage.wire,
                highSchool?.stateCommitment.orEmpty(), pro?.commitment.orEmpty(),
                meta.completedGameCount, meta.achievementIds.joinToString(";"), meta.weeklyReceiptIds.joinToString(";"),
                meta.returnPlanReceiptIds.joinToString(";"), meta.decisionReceiptIds.joinToString(";"),
                meta.activeHighSchoolCareerId.orEmpty(), meta.lifeArchiveCareerIds.joinToString(";"),
                pitchValue, settings.toString(), analytics, receiptsValue, deleted,
            ).joinToString("|")
        )
    }

    public fun committed(): GameAggregateState = copy(commitment = recomputeCommitment())

    public companion object {
        public const val CURRENT_AGGREGATE_VERSION: Int = 4

        public fun initial(installId: String): GameAggregateState = GameAggregateState(
            revision = 0UL,
            installId = installId,
            stage = GameStage.OPENING,
            commitment = "",
        ).committed()
    }
}

public sealed interface GameCommand {
    public data object EnterSetup : GameCommand
    public data class HighSchool(public val command: HighSchoolPhase4Command) : GameCommand
    public data class Pro(public val command: ProCommand) : GameCommand
    public data class ReservePitch(
        public val sessionId: String,
        public val careerKind: PitchCareerKind,
        public val careerId: String,
        public val gameId: String,
        public val seed: String,
        public val challengeRun: Boolean = false,
    ) : GameCommand
    public data class StartPitch(public val sessionId: String) : GameCommand
    public data class CommitPitch(
        public val sessionId: String,
        public val pitchId: String,
        public val resultHash: String,
        public val checkpoint: String? = null,
    ) : GameCommand
    public data class ConsumePitch(public val sessionId: String, public val pitchId: String) : GameCommand
    public data class MarkPitchTerminal(public val sessionId: String, public val pitchId: String, public val terminalHash: String) : GameCommand
    public data class CompletePitch(public val sessionId: String) : GameCommand
    public data class SuspendPitch(public val sessionId: String, public val checkpoint: String) : GameCommand
    public data class ResumePitch(public val sessionId: String) : GameCommand
    public data class AbandonPitch(public val sessionId: String, public val reason: String) : GameCommand
    /** Clears a previously consumed presentation snapshot before the next pitch input. */
    public data class ClearPitchPresentation(public val sessionId: String) : GameCommand
    /** Compose-owned durable settings; production persistence remains guarded by the store mode. */
    public data class UpdateSettings(public val settings: GameSettingsState) : GameCommand
    public data class RecordAnalytics(
        public val receiptId: String,
        public val eventName: String,
        public val properties: List<Pair<String, String>> = emptyList(),
    ) : GameCommand
}

public data class GameCommandEnvelope(
    val commandId: String,
    val sessionId: String,
    val expectedRevision: ULong,
    val command: GameCommand,
    val schema: String = GAME_COMMAND_SCHEMA,
    val schemaVersion: Int = 1,
) {
    public fun validate() {
        require(schema == GAME_COMMAND_SCHEMA && schemaVersion == 1) { "game.command.schema" }
        require(commandId.isNotBlank() && commandId.length <= 128) { "game.command.id" }
        require(sessionId.isNotBlank() && sessionId.length <= 128) { "game.command.session" }
        when (val value = command) {
            is GameCommand.ReservePitch -> require(value.sessionId == sessionId) { "game.command.session_mismatch" }
            is GameCommand.StartPitch -> require(value.sessionId == sessionId) { "game.command.session_mismatch" }
            is GameCommand.CommitPitch -> require(value.sessionId == sessionId) { "game.command.session_mismatch" }
            is GameCommand.ConsumePitch -> require(value.sessionId == sessionId) { "game.command.session_mismatch" }
            is GameCommand.MarkPitchTerminal -> require(value.sessionId == sessionId) { "game.command.session_mismatch" }
            is GameCommand.CompletePitch -> require(value.sessionId == sessionId) { "game.command.session_mismatch" }
            is GameCommand.SuspendPitch -> require(value.sessionId == sessionId) { "game.command.session_mismatch" }
            is GameCommand.ResumePitch -> require(value.sessionId == sessionId) { "game.command.session_mismatch" }
            is GameCommand.AbandonPitch -> require(value.sessionId == sessionId) { "game.command.session_mismatch" }
            GameCommand.EnterSetup,
            is GameCommand.HighSchool,
            is GameCommand.Pro,
            is GameCommand.UpdateSettings,
            is GameCommand.RecordAnalytics -> Unit
            is GameCommand.ClearPitchPresentation -> require(value.sessionId == sessionId) { "game.command.session_mismatch" }
        }
    }
}

public data class GameDispatchResult(
    val state: GameAggregateState,
    val eventHash: String,
    val duplicate: Boolean,
)

public class GameCommandException(message: String) : IllegalArgumentException(message)

public const val GAME_COMMAND_SCHEMA: String = "baseball-game-command-v1"

/** Contract names from migration plan §4.1; the Phase 6 port keeps its concrete model names too. */
public typealias GameSaveAggregate = GameAggregateState
public typealias CommandEnvelope<T> = GameCommandEnvelope
public typealias DispatchResult = GameDispatchResult
