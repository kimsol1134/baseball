package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase4CommandCodec
import com.solkim.baseball.core.highschool.HighSchoolPhase4CommandEnvelope
import com.solkim.baseball.core.pro.ProCommandCodec
import com.solkim.baseball.core.pro.ProCommandEnvelope
import com.solkim.baseball.model.Hashing
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import java.util.Base64

/** Strict aggregate command envelope. Feature command codecs remain the inner authorities. */
public object GameCommandCodec {
    private val fields = setOf("schema", "schemaVersion", "commandId", "sessionId", "expectedRevision", "kind", "payload")

    public fun encode(envelope: GameCommandEnvelope): ByteArray {
        try { envelope.validate() } catch (error: IllegalArgumentException) { throw GameCommandException(error.message ?: "game.command.invalid") }
        val root = JsonValue.Obj(linkedMapOf(
            "schema" to JsonValue.Str(envelope.schema),
            "schemaVersion" to JsonValue.Num(envelope.schemaVersion.toString()),
            "commandId" to JsonValue.Str(envelope.commandId),
            "sessionId" to JsonValue.Str(envelope.sessionId),
            "expectedRevision" to JsonValue.Str(envelope.expectedRevision.toString()),
            "kind" to JsonValue.Str(kind(envelope.command)),
            "payload" to JsonValue.Str(payload(envelope)),
        ))
        return StrictJson.canonical(root).toByteArray(Charsets.UTF_8)
    }

    public fun decode(bytes: ByteArray): GameCommandEnvelope {
        val root = try { StrictJson.parseUtf8(bytes) as? JsonValue.Obj ?: fail("game.command.root") }
        catch (error: GameCommandException) { throw error }
        catch (_: Exception) { fail("game.command.json") }
        requireExact(root, fields, "game.command.root")
        if (!bytes.contentEquals(StrictJson.canonical(root).toByteArray(Charsets.UTF_8))) fail("game.command.noncanonical")
        val schema = root.string("schema")
        val version = root.integer("schemaVersion")
        if (schema != GAME_COMMAND_SCHEMA) fail("game.command.schema")
        if (version != 1) fail("game.command.future_or_old:$version")
        val envelope = GameCommandEnvelope(
            commandId = root.string("commandId"), sessionId = root.string("sessionId"), expectedRevision = root.decimal("expectedRevision"),
            command = decodeCommand(root.string("kind"), root.string("payload"), root), schema = schema, schemaVersion = version,
        )
        try { envelope.validate() } catch (error: IllegalArgumentException) { fail(error.message ?: "game.command.invalid") }
        return envelope
    }

    public fun commandHash(envelope: GameCommandEnvelope): String = Hashing.sha256Hex(encode(envelope))

    public fun resultHash(state: GameAggregateState, envelope: GameCommandEnvelope, eventName: String): String =
        Hashing.fnv1a64Hex("${state.commitment}|${envelope.commandId}|${envelope.sessionId}|$eventName")

    private fun kind(command: GameCommand): String = when (command) {
        GameCommand.EnterSetup -> "enterSetup"
        is GameCommand.HighSchool -> "highSchool"
        is GameCommand.Pro -> "pro"
        is GameCommand.ReservePitch -> "reservePitch"
        is GameCommand.StartPitch -> "startPitch"
        is GameCommand.CommitPitch -> "commitPitch"
        is GameCommand.ConsumePitch -> "consumePitch"
        is GameCommand.MarkPitchTerminal -> "terminalPitch"
        is GameCommand.CompletePitch -> "completePitch"
        is GameCommand.SuspendPitch -> "suspendPitch"
        is GameCommand.ResumePitch -> "resumePitch"
        is GameCommand.AbandonPitch -> "abandonPitch"
        is GameCommand.ClearPitchPresentation -> "clearPitchPresentation"
        is GameCommand.UpdateSettings -> "updateSettings"
        is GameCommand.RecordAnalytics -> "recordAnalytics"
    }

    private fun payload(envelope: GameCommandEnvelope): String = when (val command = envelope.command) {
        GameCommand.EnterSetup -> pack(emptyList())
        is GameCommand.HighSchool -> encodeInner(
            HighSchoolPhase4CommandCodec.encode(
                HighSchoolPhase4CommandEnvelope(commandId = envelope.commandId, sessionId = envelope.sessionId, expectedRevision = envelope.expectedRevision, command = command.command),
            ),
        )
        is GameCommand.Pro -> encodeInner(
            ProCommandCodec.encode(
                ProCommandEnvelope(commandId = envelope.commandId, sessionId = envelope.sessionId, expectedRevision = envelope.expectedRevision, command = command.command),
            ),
        )
        is GameCommand.ReservePitch -> pack(listOf(command.sessionId, command.careerKind.wire, command.careerId, command.gameId, command.seed, command.challengeRun.toString()))
        is GameCommand.StartPitch -> pack(listOf(command.sessionId))
        is GameCommand.CommitPitch -> pack(listOf(command.sessionId, command.pitchId, command.resultHash, command.checkpoint.orEmpty()))
        is GameCommand.ConsumePitch -> pack(listOf(command.sessionId, command.pitchId))
        is GameCommand.MarkPitchTerminal -> pack(listOf(command.sessionId, command.pitchId, command.terminalHash))
        is GameCommand.CompletePitch -> pack(listOf(command.sessionId))
        is GameCommand.SuspendPitch -> pack(listOf(command.sessionId, command.checkpoint))
        is GameCommand.ResumePitch -> pack(listOf(command.sessionId))
        is GameCommand.AbandonPitch -> pack(listOf(command.sessionId, command.reason))
        is GameCommand.ClearPitchPresentation -> pack(listOf(command.sessionId))
        is GameCommand.UpdateSettings -> pack(listOf(
            command.settings.autoReleaseEnabled.toString(),
            command.settings.soundEnabled.toString(),
            command.settings.musicEnabled.toString(),
            command.settings.hapticsEnabled.toString(),
            command.settings.notificationsEnabled.toString(),
            command.settings.highContrastEnabled.toString(),
            command.settings.reducedMotionEnabled.toString(),
        ))
        is GameCommand.RecordAnalytics -> pack(listOf(command.receiptId, command.eventName, command.properties.joinToString(";") { encodeInner(pack(listOf(it.first, it.second)).toByteArray(Charsets.UTF_8)) }))
    }

    private fun decodeCommand(kind: String, payload: String, root: JsonValue.Obj): GameCommand = when (kind) {
        "enterSetup" -> unpack(payload, 0).let { GameCommand.EnterSetup }
        "highSchool" -> {
            val inner = HighSchoolPhase4CommandCodec.decode(decodeInner(payload))
            requireInnerMatches(inner.commandId, inner.sessionId, inner.expectedRevision, root)
            GameCommand.HighSchool(inner.command)
        }
        "pro" -> {
            val inner = ProCommandCodec.decode(decodeInner(payload))
            requireInnerMatches(inner.commandId, inner.sessionId, inner.expectedRevision, root)
            GameCommand.Pro(inner.command)
        }
        "reservePitch" -> unpack(payload, 6).let { GameCommand.ReservePitch(requireSession(root, it[0]), enumWire(it[1], PitchCareerKind.entries, "pitch.careerKind") { value -> value.wire }, it[2], it[3], it[4], it[5].toBooleanStrictOrNull() ?: fail("pitch.challengeRun.boolean")) }
        "startPitch" -> unpack(payload, 1).let { GameCommand.StartPitch(requireSession(root, it.single())) }
        "commitPitch" -> unpack(payload, 4).let { GameCommand.CommitPitch(requireSession(root, it[0]), it[1], it[2], it[3].ifEmpty { null }) }
        "consumePitch" -> unpack(payload, 2).let { GameCommand.ConsumePitch(requireSession(root, it[0]), it[1]) }
        "terminalPitch" -> unpack(payload, 3).let { GameCommand.MarkPitchTerminal(requireSession(root, it[0]), it[1], it[2]) }
        "completePitch" -> unpack(payload, 1).let { GameCommand.CompletePitch(requireSession(root, it.single())) }
        "suspendPitch" -> unpack(payload, 2).let { GameCommand.SuspendPitch(requireSession(root, it[0]), it[1]) }
        "resumePitch" -> unpack(payload, 1).let { GameCommand.ResumePitch(requireSession(root, it.single())) }
        "abandonPitch" -> unpack(payload, 2).let { GameCommand.AbandonPitch(requireSession(root, it[0]), it[1]) }
        "clearPitchPresentation" -> unpack(payload, 1).let { GameCommand.ClearPitchPresentation(requireSession(root, it.single())) }
        "updateSettings" -> unpack(payload, 7).let { values ->
            GameCommand.UpdateSettings(GameSettingsState(
                autoReleaseEnabled = strictBoolean(values[0], "settings.autoRelease"),
                soundEnabled = strictBoolean(values[1], "settings.sound"),
                musicEnabled = strictBoolean(values[2], "settings.music"),
                hapticsEnabled = strictBoolean(values[3], "settings.haptics"),
                notificationsEnabled = strictBoolean(values[4], "settings.notifications"),
                highContrastEnabled = strictBoolean(values[5], "settings.contrast"),
                reducedMotionEnabled = strictBoolean(values[6], "settings.motion"),
            ))
        }
        "recordAnalytics" -> unpack(payload, 3).let { values ->
            val properties = if (values[2].isEmpty()) emptyList() else values[2].split(';').map { encoded ->
                val raw = String(decodeInner(encoded), Charsets.UTF_8)
                unpack(raw, 2).let { it[0] to it[1] }
            }
            GameCommand.RecordAnalytics(values[0], values[1], properties)
        }
        else -> fail("game.command.kind_unknown:$kind")
    }

    private fun encodeInner(bytes: ByteArray): String = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)

    private fun decodeInner(value: String): ByteArray = try {
        val bytes = Base64.getUrlDecoder().decode(value)
        if (Base64.getUrlEncoder().withoutPadding().encodeToString(bytes) != value) fail("game.command.payload_noncanonical")
        bytes
    } catch (error: GameCommandException) { throw error }
    catch (_: Exception) { fail("game.command.payload_encoding") }

    private fun pack(values: List<String>): String = "g6:" + values.joinToString(".") { encodeInner(it.toByteArray(Charsets.UTF_8)) }
    private fun unpack(value: String, expected: Int): List<String> {
        if (!value.startsWith("g6:")) fail("game.command.payload_prefix")
        val body = value.removePrefix("g6:")
        val parts = if (body.isEmpty()) emptyList() else body.split('.')
        if (parts.size != expected) fail("game.command.payload_count")
        return parts.map { String(decodeInner(it), Charsets.UTF_8) }
    }

    private fun requireExact(value: JsonValue.Obj, expected: Set<String>, field: String) {
        val missing = expected - value.entries.keys
        val unknown = value.entries.keys - expected
        if (missing.isNotEmpty()) fail("$field.missing:${missing.sorted().joinToString(",")}")
        if (unknown.isNotEmpty()) fail("$field.unknown:${unknown.sorted().joinToString(",")}")
    }

    private fun requireInnerMatches(
        commandId: String,
        sessionId: String,
        expectedRevision: ULong,
        root: JsonValue.Obj,
    ) {
        if (commandId != root.string("commandId") || sessionId != root.string("sessionId") || expectedRevision != root.decimal("expectedRevision")) {
            fail("game.command.inner_metadata_mismatch")
        }
    }

    private fun requireSession(root: JsonValue.Obj, sessionId: String): String {
        if (sessionId != root.string("sessionId")) fail("game.command.session_mismatch")
        return sessionId
    }

    private fun JsonValue.Obj.string(name: String): String = (this[name] as? JsonValue.Str)?.value ?: fail("$name.string")
    private fun JsonValue.Obj.integer(name: String): Int = (this[name] as? JsonValue.Num)?.raw?.toIntOrNull() ?: fail("$name.integer")
    private fun JsonValue.Obj.decimal(name: String): ULong {
        val raw = (this[name] as? JsonValue.Str)?.value ?: fail("$name.decimal")
        if (!Regex("0|[1-9][0-9]*").matches(raw)) fail("$name.decimal")
        return raw.toULongOrNull() ?: fail("$name.bounds")
    }
    private fun strictBoolean(raw: String, field: String): Boolean = raw.toBooleanStrictOrNull() ?: fail("$field.boolean")
    private inline fun <reified E : Enum<E>> enumWire(raw: String, values: Iterable<E>, field: String, wire: (E) -> String): E =
        values.firstOrNull { wire(it) == raw } ?: fail("$field.unknown:$raw")
    private fun fail(message: String): Nothing = throw GameCommandException(message)
}
