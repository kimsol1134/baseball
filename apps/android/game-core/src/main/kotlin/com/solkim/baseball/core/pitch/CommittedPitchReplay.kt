package com.solkim.baseball.core.pitch

import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.PresentationTerminalStatus
import com.solkim.baseball.model.StrictJson

public object CommittedPitchReplayContract {
    public const val SCHEMA: String = "baseball-committed-pitch-replay-v1"
    public const val SCHEMA_VERSION: Int = 1
}

public enum class CommittedPitchReplayStatus(public val wire: String) {
    RESERVED("reserved"),
    PRESENTING("presenting"),
    TERMINAL("terminal"),
    COMMITTED("committed"),
    CONSUMED("consumed"),
    ;

    public companion object {
        public fun fromWire(wire: String): CommittedPitchReplayStatus = entries.firstOrNull { it.wire == wire }
            ?: throw CommittedPitchReplayException("status.unknown:$wire")
    }
}

public data class CommittedPitchReplay(
    val replayId: String,
    val sessionId: String,
    val messageId: String,
    val pitchId: String,
    val presentationSeed: String,
    val requestSha256: String,
    val resultRevision: ULong,
    val eventHash: String,
    val outcome: PitchOutcome,
    val status: CommittedPitchReplayStatus,
    val terminalStatus: PresentationTerminalStatus? = null,
    val terminalErrorCode: String? = null,
) {
    public fun validate() {
        replayIdentifier(replayId, "replayId")
        replayIdentifier(sessionId, "sessionId")
        replayIdentifier(messageId, "messageId")
        replayIdentifier(pitchId, "pitchId")
        replayIdentifier(presentationSeed, "presentationSeed")
        if (!SHA256.matches(requestSha256)) throw CommittedPitchReplayException("requestSha256.invalid")
        if (!EVENT_HASH.matches(eventHash)) throw CommittedPitchReplayException("eventHash.invalid")
        if (status == CommittedPitchReplayStatus.TERMINAL || status == CommittedPitchReplayStatus.COMMITTED ||
            status == CommittedPitchReplayStatus.CONSUMED
        ) {
            if (terminalStatus == null) throw CommittedPitchReplayException("terminalStatus.required")
        } else if (terminalStatus != null || terminalErrorCode != null) {
            throw CommittedPitchReplayException("terminalStatus.unexpected")
        }
        terminalErrorCode?.let { replayIdentifier(it, "terminalErrorCode") }
    }

    public companion object {
        private val SHA256 = Regex("[0-9a-f]{64}")
        private val EVENT_HASH = Regex("[0-9a-f]{16}")
    }
}

public class CommittedPitchReplayException(message: String) : IllegalArgumentException(message)

public object CommittedPitchReplayCodec {
    public fun encode(replay: CommittedPitchReplay): String {
        replay.validate()
        return StrictJson.compact(JsonValue.Obj(linkedMapOf<String, JsonValue>(
            "schema" to JsonValue.Str(CommittedPitchReplayContract.SCHEMA),
            "schemaVersion" to JsonValue.Num(CommittedPitchReplayContract.SCHEMA_VERSION.toString()),
            "replayId" to JsonValue.Str(replay.replayId),
            "sessionId" to JsonValue.Str(replay.sessionId),
            "messageId" to JsonValue.Str(replay.messageId),
            "pitchId" to JsonValue.Str(replay.pitchId),
            "presentationSeed" to JsonValue.Str(replay.presentationSeed),
            "requestSha256" to JsonValue.Str(replay.requestSha256),
            "resultRevision" to JsonValue.Str(replay.resultRevision.toString()),
            "eventHash" to JsonValue.Str(replay.eventHash),
            "outcome" to JsonValue.Str(replay.outcome.wire),
            "status" to JsonValue.Str(replay.status.wire),
            "terminalStatus" to (replay.terminalStatus?.let { JsonValue.Str(it.wire) } ?: JsonValue.Null),
            "terminalErrorCode" to (replay.terminalErrorCode?.let { JsonValue.Str(it) } ?: JsonValue.Null),
        )))
    }

    public fun decode(json: String): CommittedPitchReplay {
        val root = try {
            StrictJson.parse(json).asObject()
        } catch (error: Exception) {
            throw CommittedPitchReplayException("json.invalid:${error.javaClass.simpleName}")
        }
        val allowed = setOf(
            "schema", "schemaVersion", "replayId", "sessionId", "messageId", "pitchId", "presentationSeed",
            "requestSha256", "resultRevision", "eventHash", "outcome", "status", "terminalStatus", "terminalErrorCode",
        )
        root.entries.keys.firstOrNull { it !in allowed }?.let { throw CommittedPitchReplayException("json.unknown_field:$it") }
        val schema = root.requiredString("schema")
        if (schema != CommittedPitchReplayContract.SCHEMA) throw CommittedPitchReplayException("schema.invalid")
        val schemaVersion = root.requiredInt("schemaVersion")
        if (schemaVersion != CommittedPitchReplayContract.SCHEMA_VERSION) {
            throw CommittedPitchReplayException("schemaVersion.unsupported:$schemaVersion")
        }
        val revision = root.requiredString("resultRevision")
        if (!Regex("[0-9]+").matches(revision)) throw CommittedPitchReplayException("resultRevision.invalid")
        val replay = CommittedPitchReplay(
            replayId = root.requiredString("replayId"),
            sessionId = root.requiredString("sessionId"),
            messageId = root.requiredString("messageId"),
            pitchId = root.requiredString("pitchId"),
            presentationSeed = root.requiredString("presentationSeed"),
            requestSha256 = root.requiredString("requestSha256"),
            resultRevision = revision.toULongOrNull() ?: throw CommittedPitchReplayException("resultRevision.bounds"),
            eventHash = root.requiredString("eventHash"),
            outcome = PitchOutcome.entries.firstOrNull { it.wire == root.requiredString("outcome") }
                ?: throw CommittedPitchReplayException("outcome.unknown"),
            status = CommittedPitchReplayStatus.fromWire(root.requiredString("status")),
            terminalStatus = root.optionalString("terminalStatus")?.let { wire ->
                PresentationTerminalStatus.entries.firstOrNull { it.wire == wire }
                    ?: throw CommittedPitchReplayException("terminalStatus.unknown:$wire")
            },
            terminalErrorCode = root.optionalString("terminalErrorCode"),
        )
        replay.validate()
        return replay
    }

    private fun JsonValue.asObject(): JsonValue.Obj = this as? JsonValue.Obj
        ?: throw CommittedPitchReplayException("json.object_required")

    private fun JsonValue.Obj.requiredString(name: String): String = (entries[name] as? JsonValue.Str)?.value
        ?: throw CommittedPitchReplayException("$name.string_required")

    private fun JsonValue.Obj.optionalString(name: String): String? = when (val value = entries[name]) {
        null, JsonValue.Null -> null
        is JsonValue.Str -> value.value
        else -> throw CommittedPitchReplayException("$name.string_optional")
    }

    private fun JsonValue.Obj.requiredInt(name: String): Int {
        val raw = (entries[name] as? JsonValue.Num)?.raw
            ?: throw CommittedPitchReplayException("$name.integer_required")
        return raw.toIntOrNull() ?: throw CommittedPitchReplayException("$name.integer_invalid")
    }
}

public data class ReplayDecision(val accepted: Boolean, val code: String)

/** In-memory atomic replay lifecycle; callers persist only after the committed state is reached. */
public class CommittedPitchReplayLifecycle {
    public var current: CommittedPitchReplay? = null
        private set

    public fun reserve(replay: CommittedPitchReplay): ReplayDecision {
        replay.validate()
        val existing = current
        if (existing != null) {
            return if (existing == replay) ReplayDecision(false, "duplicate_replay")
            else ReplayDecision(false, "stale_replay")
        }
        if (replay.status != CommittedPitchReplayStatus.RESERVED) return ReplayDecision(false, "reserve_status")
        current = replay
        return ReplayDecision(true, "accepted")
    }

    public fun markPresenting(messageId: String): ReplayDecision = transition(CommittedPitchReplayStatus.PRESENTING, messageId)

    public fun markTerminal(
        messageId: String,
        terminalStatus: PresentationTerminalStatus,
        errorCode: String? = null,
    ): ReplayDecision = transition(CommittedPitchReplayStatus.TERMINAL, messageId, terminalStatus, errorCode)

    public fun commit(messageId: String): ReplayDecision {
        val replay = current ?: return ReplayDecision(false, "no_replay")
        if (replay.messageId != messageId) return ReplayDecision(false, "stale_message")
        if (replay.status != CommittedPitchReplayStatus.TERMINAL || replay.terminalStatus == null) {
            return ReplayDecision(false, "terminal_required")
        }
        current = replay.copy(status = CommittedPitchReplayStatus.COMMITTED)
        return ReplayDecision(true, "accepted")
    }

    public fun consume(messageId: String): ReplayDecision {
        val replay = current ?: return ReplayDecision(false, "no_replay")
        if (replay.messageId != messageId) return ReplayDecision(false, "stale_message")
        if (replay.status != CommittedPitchReplayStatus.COMMITTED) return ReplayDecision(false, "commit_required")
        current = replay.copy(status = CommittedPitchReplayStatus.CONSUMED)
        return ReplayDecision(true, "accepted")
    }

    private fun transition(
        status: CommittedPitchReplayStatus,
        messageId: String,
        terminalStatus: PresentationTerminalStatus? = null,
        errorCode: String? = null,
    ): ReplayDecision {
        val replay = current ?: return ReplayDecision(false, "no_replay")
        if (replay.messageId != messageId) return ReplayDecision(false, "stale_message")
        val valid = when (status) {
            CommittedPitchReplayStatus.PRESENTING -> replay.status == CommittedPitchReplayStatus.RESERVED
            CommittedPitchReplayStatus.TERMINAL -> replay.status == CommittedPitchReplayStatus.PRESENTING
            else -> false
        }
        if (!valid) return ReplayDecision(false, "invalid_transition")
        current = replay.copy(status = status, terminalStatus = terminalStatus, terminalErrorCode = errorCode)
        return ReplayDecision(true, "accepted")
    }
}

private fun replayIdentifier(value: String, field: String) {
    if (value.isBlank() || value.length > 128 || value.any { it.code < 0x20 }) {
        throw CommittedPitchReplayException("$field.invalid")
    }
}
