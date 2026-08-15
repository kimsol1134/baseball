package com.solkim.baseball.core.pro

import com.solkim.baseball.core.StableHash
import com.solkim.baseball.core.pitch.PitchCall
import com.solkim.baseball.core.pitch.PitchDelivery
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchIntensity
import com.solkim.baseball.core.pitch.PitchZone
import com.solkim.baseball.core.pitch.ThrowingHand
import com.solkim.baseball.core.pitch.ZoneIntent
import com.solkim.baseball.core.highschool.HighSchoolPerformance
import com.solkim.baseball.model.Hashing
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import java.util.Base64

public object ProWire {
    public const val STATE_SCHEMA: String = "baseball-pro-state-v1"
    public const val COMMAND_SCHEMA: String = "baseball-pro-command-v1"
    public const val SCHEMA_VERSION: Int = 1
    public const val MAX_COMMAND_ID_LENGTH: Int = 128
}

public sealed interface ProCommand {
    public data class StartLinked(val request: ProStartLinkedRequest) : ProCommand
    public data class StartDirect(val request: ProStartDirectRequest) : ProCommand
    public data object SignContract : ProCommand
    public data class PlanWeek(val seed: String, val plan: ProWeekPlan, val targetPitch: PitchKind? = null) : ProCommand
    public data class AdvanceSegment(
        val seed: String,
        val plan: ProWeekPlan,
        val targetPitch: PitchKind? = null,
        val maximumWeeks: Int = ProCatalog.WEEKS_PER_SEASON,
    ) : ProCommand
    public data class ApplySeasonDecision(val seed: String, val decisionId: String, val choiceId: String) : ProCommand
    public data class ReserveImportantGame(val seed: String) : ProCommand
    public data class SubmitPitch(val pitchSessionId: String, val call: PitchCall, val delivery: PitchDelivery = PitchDelivery.NEUTRAL) : ProCommand
    public data object FinishImportantGame : ProCommand
    public data class ReviewSeason(val seed: String) : ProCommand
    public data class ChooseOffseason(val seed: String, val decision: OffseasonDecision) : ProCommand
    public data class SelectLegacy(val legacyId: String) : ProCommand
    public data object NormalizeBalance : ProCommand
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

/** Strict, canonical command wire. Every variable payload is URL-safe base64 packed. */
public object ProCommandCodec {
    private val ROOT_FIELDS = setOf("schema", "schemaVersion", "commandId", "sessionId", "expectedRevision", "kind", "payload")

    public fun commandHash(command: ProCommand): String = Hashing.sha256Hex(canonical(command))

    public fun envelopeHash(envelope: ProCommandEnvelope): String = Hashing.sha256Hex(
        listOf(envelope.schema, envelope.schemaVersion, envelope.sessionId, envelope.expectedRevision, canonical(envelope.command)).joinToString("|"),
    )

    public fun resultHash(state: ProState, envelope: ProCommandEnvelope): String =
        StableHash.fnv1a64("${state.commitment}|${envelope.sessionId}|${envelope.expectedRevision}|${canonical(envelope.command)}")

    public fun encode(envelope: ProCommandEnvelope): ByteArray {
        try { envelope.validate() } catch (error: IllegalArgumentException) { fail(error.message ?: "pro.command.invalid") }
        val root = JsonValue.Obj(linkedMapOf(
            "schema" to JsonValue.Str(envelope.schema),
            "schemaVersion" to JsonValue.Num(envelope.schemaVersion.toString()),
            "commandId" to JsonValue.Str(envelope.commandId),
            "sessionId" to JsonValue.Str(envelope.sessionId),
            "expectedRevision" to JsonValue.Str(envelope.expectedRevision.toString()),
            "kind" to JsonValue.Str(kind(envelope.command)),
            "payload" to JsonValue.Str(payload(envelope.command)),
        ))
        return StrictJson.canonical(root).toByteArray(Charsets.UTF_8)
    }

    public fun decode(bytes: ByteArray): ProCommandEnvelope {
        val root = try { StrictJson.parseUtf8(bytes) as? JsonValue.Obj ?: fail("pro.command.root") }
        catch (error: ProCommandException) { throw error }
        catch (_: Exception) { fail("pro.command.json") }
        requireExact(root, ROOT_FIELDS, "pro.command.root")
        if (!bytes.contentEquals(StrictJson.canonical(root).toByteArray(Charsets.UTF_8))) fail("pro.command.noncanonical")
        val schema = root.string("schema")
        if (schema != ProWire.COMMAND_SCHEMA) fail("pro.command.schema")
        val version = root.integer("schemaVersion")
        if (version != ProWire.SCHEMA_VERSION) fail("pro.command.future_or_old:$version")
        val envelope = ProCommandEnvelope(
            schema = schema,
            schemaVersion = version,
            commandId = root.string("commandId"),
            sessionId = root.string("sessionId"),
            expectedRevision = root.decimal("expectedRevision"),
            command = decodeCommand(root.string("kind"), root.string("payload")),
        )
        try { envelope.validate() } catch (error: IllegalArgumentException) { fail(error.message ?: "pro.command.invalid") }
        return envelope
    }

    private fun kind(command: ProCommand): String = when (command) {
        is ProCommand.StartLinked -> "startLinked"
        is ProCommand.StartDirect -> "startDirect"
        ProCommand.SignContract -> "signContract"
        is ProCommand.PlanWeek -> "planWeek"
        is ProCommand.AdvanceSegment -> "advanceSegment"
        is ProCommand.ApplySeasonDecision -> "applySeasonDecision"
        is ProCommand.ReserveImportantGame -> "reserveImportantGame"
        is ProCommand.SubmitPitch -> "submitPitch"
        ProCommand.FinishImportantGame -> "finishImportantGame"
        is ProCommand.ReviewSeason -> "reviewSeason"
        is ProCommand.ChooseOffseason -> "chooseOffseason"
        is ProCommand.SelectLegacy -> "selectLegacy"
        ProCommand.NormalizeBalance -> "normalizeBalance"
    }

    private fun payload(command: ProCommand): String = when (command) {
        is ProCommand.StartLinked -> pack(listOf(
            command.request.seed, command.request.highSchoolCareerId, command.request.identityName, command.request.teamId,
            command.request.draftEvaluation.toString(), command.request.activeHighSchoolPreserved.toString(),
            command.request.entitlement.active.toString(), command.request.entitlement.source, command.request.entitlement.verifiedAt,
            pitcherWire(command.request.pitcher), legacyContextWire(command.request.highSchoolLegacyContext),
        ))
        is ProCommand.StartDirect -> pack(listOf(command.request.seed, command.request.presetId, command.request.playerName, command.request.activeHighSchoolCareerId.orEmpty()))
        ProCommand.SignContract -> pack(emptyList())
        is ProCommand.PlanWeek -> pack(listOf(command.seed, command.plan.wire, command.targetPitch?.wire.orEmpty()))
        is ProCommand.AdvanceSegment -> pack(listOf(command.seed, command.plan.wire, command.targetPitch?.wire.orEmpty(), command.maximumWeeks.toString()))
        is ProCommand.ApplySeasonDecision -> pack(listOf(command.seed, command.decisionId, command.choiceId))
        is ProCommand.ReserveImportantGame -> pack(listOf(command.seed))
        is ProCommand.SubmitPitch -> pack(listOf(
            command.pitchSessionId, command.call.pitchType.wire, command.call.zone.row.toString(), command.call.zone.column.toString(),
            command.call.zoneIntent.wire, command.call.intensity.wire, command.delivery.releaseAccuracy.toString(), command.delivery.aimAccuracy.toString(),
        ))
        ProCommand.FinishImportantGame -> pack(emptyList())
        is ProCommand.ReviewSeason -> pack(listOf(command.seed))
        is ProCommand.ChooseOffseason -> pack(listOf(command.seed, command.decision.wire))
        is ProCommand.SelectLegacy -> pack(listOf(command.legacyId))
        ProCommand.NormalizeBalance -> pack(emptyList())
    }

    private fun canonical(command: ProCommand): String = "${kind(command)}|${payload(command)}"

    private fun decodeCommand(kind: String, payload: String): ProCommand = when (kind) {
        "startLinked" -> unpack(payload, 11).let { values ->
            ProCommand.StartLinked(ProStartLinkedRequest(
                seed = values[0], highSchoolCareerId = values[1], identityName = values[2], teamId = values[3],
                draftEvaluation = values[4].int("startLinked.draftEvaluation"), activeHighSchoolPreserved = values[5].bool("startLinked.activeHighSchoolPreserved"),
                entitlement = ProEntitlement(values[6].bool("startLinked.entitlement.active"), values[7], values[8]), pitcher = readPitcher(values[9]),
                highSchoolLegacyContext = values[10].ifEmpty { null }?.let(::readLegacyContext),
            ))
        }
        "startDirect" -> unpack(payload, 4).let { values -> ProCommand.StartDirect(ProStartDirectRequest(values[0], values[1], values[2], values[3].ifEmpty { null })) }
        "signContract" -> exactPayload(payload) { ProCommand.SignContract }
        "planWeek" -> unpack(payload, 3).let { values -> ProCommand.PlanWeek(values[0], plan(values[1]), values[2].ifEmpty { null }?.let(::pitchKind)) }
        "advanceSegment" -> unpack(payload, 4).let { values -> ProCommand.AdvanceSegment(values[0], plan(values[1]), values[2].ifEmpty { null }?.let(::pitchKind), values[3].int("advanceSegment.maximumWeeks")) }
        "applySeasonDecision" -> unpack(payload, 3).let { ProCommand.ApplySeasonDecision(it[0], it[1], it[2]) }
        "reserveImportantGame" -> unpack(payload, 1).let { ProCommand.ReserveImportantGame(it.single()) }
        "submitPitch" -> unpack(payload, 8).let { values ->
            ProCommand.SubmitPitch(values[0], PitchCall(pitchKind(values[1]), PitchZone(values[2].int("pitch.row"), values[3].int("pitch.column")), zoneIntent(values[4]), intensity(values[5])), PitchDelivery(values[6].int("pitch.release"), values[7].int("pitch.aim")))
        }
        "finishImportantGame" -> exactPayload(payload) { ProCommand.FinishImportantGame }
        "reviewSeason" -> unpack(payload, 1).let { ProCommand.ReviewSeason(it.single()) }
        "chooseOffseason" -> unpack(payload, 2).let { ProCommand.ChooseOffseason(it[0], offseason(it[1])) }
        "selectLegacy" -> unpack(payload, 1).let { ProCommand.SelectLegacy(it.single()) }
        "normalizeBalance" -> exactPayload(payload) { ProCommand.NormalizeBalance }
        else -> fail("pro.command.kind_unknown:$kind")
    }

    private fun pitcherWire(value: com.solkim.baseball.core.pitch.PitcherSnapshot): String {
        val profiles = value.pitchProfiles.orEmpty().joinToString(";") { profile ->
            pack(listOf(profile.pitchType.wire, profile.role.wire, profile.velocityTenthsKph.toString(), profile.control.toString(), profile.command.toString(), profile.movement.toString(), profile.whiff.toString(), profile.weakContact.toString(), profile.fatigueCost.toString()))
        }
        return pack(listOf(value.id, value.name, value.stuff.toString(), value.command.toString(), value.movement.toString(), value.stamina.toString(), value.throwingHand.wire(), profiles))
    }

    private fun legacyContextWire(value: ProHighSchoolLegacyContext?): String = value?.let {
        pack(listOf(
            pitcherWire(it.startingPitcher), pitcherWire(it.highSchoolPitcher),
            it.performance.importantGamesCompleted.toString(), it.performance.pitches.toString(), it.performance.strikeouts.toString(), it.performance.walks.toString(), it.performance.runsAllowed.toString(), it.performance.expectedDamage.toString(), it.performance.actualDamage.toString(), it.performance.outs.toString(), it.performance.hits.toString(),
            it.selectedAwakenings.joinToString(";"), it.managerTrust.toString(), it.catcherTrust.toString(), it.rivalTrust.toString(),
        ))
    }.orEmpty()

    private fun readLegacyContext(value: String): ProHighSchoolLegacyContext {
        val fields = unpack(value, 15)
        return ProHighSchoolLegacyContext(
            startingPitcher = readPitcher(fields[0]), highSchoolPitcher = readPitcher(fields[1]),
            performance = HighSchoolPerformance(fields[2].int("legacy.performance.games"), fields[3].int("legacy.performance.pitches"), fields[4].int("legacy.performance.strikeouts"), fields[5].int("legacy.performance.walks"), fields[6].int("legacy.performance.runs"), fields[7].int("legacy.performance.expected"), fields[8].int("legacy.performance.actual"), fields[9].int("legacy.performance.outs"), fields[10].int("legacy.performance.hits")),
            selectedAwakenings = fields[11].split(';').filter { it.isNotEmpty() }, managerTrust = fields[12].int("legacy.managerTrust"), catcherTrust = fields[13].int("legacy.catcherTrust"), rivalTrust = fields[14].int("legacy.rivalTrust"),
        )
    }

    private fun readPitcher(value: String): com.solkim.baseball.core.pitch.PitcherSnapshot {
        val fields = unpack(value, 8)
        val profiles = if (fields[7].isEmpty()) null else fields[7].split(';').map { encoded ->
            val p = unpack(encoded, 9)
            com.solkim.baseball.core.pitch.PitchProfileSnapshot(pitchKind(p[0]), role(p[1]), p[2].int("pitcher.velocity"), p[3].int("pitcher.control"), p[4].int("pitcher.command"), p[5].int("pitcher.movement"), p[6].int("pitcher.whiff"), p[7].int("pitcher.weakContact"), p[8].int("pitcher.fatigue"))
        }
        return com.solkim.baseball.core.pitch.PitcherSnapshot(fields[0], fields[1], fields[2].int("pitcher.stuff"), fields[3].int("pitcher.command"), fields[4].int("pitcher.movement"), fields[5].int("pitcher.stamina"), profiles, hand(fields[6]))
    }

    private fun pack(values: List<String>): String = "p5:" + values.joinToString(".") { Base64.getUrlEncoder().withoutPadding().encodeToString(it.toByteArray(Charsets.UTF_8)) }

    private fun unpack(value: String, expected: Int): List<String> {
        val result = unpackValues(value)
        if (result.size != expected) fail("pro.command.payload_count")
        return result
    }

    private fun unpackValues(value: String): List<String> {
        if (!value.startsWith("p5:")) fail("pro.command.payload_prefix")
        val encoded = value.removePrefix("p5:")
        if (encoded.isEmpty()) return emptyList()
        return encoded.split('.').map { part ->
            try {
                val bytes = Base64.getUrlDecoder().decode(part)
                if (Base64.getUrlEncoder().withoutPadding().encodeToString(bytes) != part) fail("pro.command.payload_noncanonical")
                bytes.toString(Charsets.UTF_8)
            } catch (error: ProCommandException) { throw error }
            catch (_: Exception) { fail("pro.command.payload_encoding") }
        }
    }

    private fun exactPayload(value: String, factory: () -> ProCommand): ProCommand {
        if (unpackValues(value).isNotEmpty()) fail("pro.command.payload_count")
        return factory()
    }

    private fun plan(value: String): ProWeekPlan = ProWeekPlan.entries.firstOrNull { it.wire == value } ?: fail("pro.command.plan_unknown")
    private fun pitchKind(value: String): PitchKind = PitchKind.entries.firstOrNull { it.wire == value } ?: fail("pro.command.pitch_unknown")
    private fun intensity(value: String): PitchIntensity = PitchIntensity.entries.firstOrNull { it.wire == value } ?: fail("pro.command.intensity_unknown")
    private fun zoneIntent(value: String): ZoneIntent = ZoneIntent.entries.firstOrNull { it.wire == value } ?: fail("pro.command.zone_unknown")
    private fun role(value: String): com.solkim.baseball.core.pitch.PitchUsageRole = com.solkim.baseball.core.pitch.PitchUsageRole.entries.firstOrNull { it.wire == value } ?: fail("pro.command.role_unknown")
    private fun offseason(value: String): OffseasonDecision = OffseasonDecision.entries.firstOrNull { it.wire == value } ?: fail("pro.command.offseason_unknown")
    private fun hand(value: String): com.solkim.baseball.core.pitch.ThrowingHand = com.solkim.baseball.core.pitch.ThrowingHand.entries.firstOrNull { it.wire() == value } ?: fail("pro.command.hand_unknown")
    private fun com.solkim.baseball.core.pitch.ThrowingHand.wire(): String = name.lowercase()

    private fun String.int(field: String): Int = toIntOrNull() ?: fail(field)
    private fun String.bool(field: String): Boolean = when (this) { "true" -> true; "false" -> false; else -> fail(field) }
    private fun requireExact(value: JsonValue.Obj, expected: Set<String>, field: String) {
        val missing = expected - value.entries.keys
        val unknown = value.entries.keys - expected
        if (missing.isNotEmpty()) fail("$field.missing:${missing.sorted().joinToString(",")}")
        if (unknown.isNotEmpty()) fail("$field.unknown:${unknown.sorted().joinToString(",")}")
    }
    private fun JsonValue.Obj.string(name: String): String = (this[name] as? JsonValue.Str)?.value ?: fail("pro.command.$name")
    private fun JsonValue.Obj.integer(name: String): Int = (this[name] as? JsonValue.Num)?.raw?.toIntOrNull() ?: fail("pro.command.$name")
    private fun JsonValue.Obj.decimal(name: String): ULong {
        val value = string(name)
        if (!Regex("0|[1-9][0-9]*").matches(value)) fail("pro.command.$name")
        return value.toULongOrNull() ?: fail("pro.command.$name")
    }
    private fun fail(code: String): Nothing = throw ProCommandException(code)
}

/** In-memory durable command boundary; production package/save repositories stay disabled. */
public class ProCommandStore(
    private val kernel: ProKernel = ProKernel(),
    initialState: ProState? = null,
) {
    private var current: ProState? = initialState

    init { current?.let(kernel::validateSavedState) }

    public fun snapshot(): ProState? = current

    public fun dispatch(envelope: ProCommandEnvelope): ProDispatchResult {
        try { envelope.validate() } catch (error: IllegalArgumentException) { throw ProCommandException(error.message ?: "pro.command.invalid") }
        val commandHash = ProCommandCodec.envelopeHash(envelope)
        val state = current
        val boundSession = state?.commandReceipts?.firstOrNull()?.sessionId
        if (boundSession != null && boundSession != envelope.sessionId) throw ProCommandException("pro.command.session_mismatch")
        val existing = state?.commandReceipts?.firstOrNull { it.commandId == envelope.commandId }
        if (existing != null) {
            if (existing.commandHash != commandHash) throw ProCommandException("pro.command.duplicate_tampered")
            return ProDispatchResult(state ?: error("pro.command.state"), existing.resultHash, duplicate = true)
        }
        if (state == null) {
            if (envelope.expectedRevision != 0UL || (envelope.command !is ProCommand.StartLinked && envelope.command !is ProCommand.StartDirect)) throw ProCommandException("pro.command.start_required")
            val result = when (val command = envelope.command) {
                is ProCommand.StartLinked -> kernel.startLinked(command.request)
                is ProCommand.StartDirect -> kernel.startDirect(command.request)
                else -> error("unreachable")
            }
            return commit(result, envelope, commandHash)
        }
        kernel.validateSavedState(state)
        if (envelope.expectedRevision != state.revision) throw ProCommandException("pro.command.stale_revision")
        if (envelope.command is ProCommand.StartLinked || envelope.command is ProCommand.StartDirect) throw ProCommandException("pro.command.start_duplicate")
        return commit(apply(state, envelope.command), envelope, commandHash)
    }

    private fun commit(result: ProResult, envelope: ProCommandEnvelope, commandHash: String): ProDispatchResult {
        val priorRevision = current?.revision ?: 0UL
        val revision = maxOf(result.state.revision, priorRevision + 1UL)
        val resultHash = ProCommandCodec.resultHash(result.state, envelope)
        val receipt = ProCommandReceipt(envelope.commandId, envelope.sessionId, commandHash, resultHash, revision)
        val unsigned = result.state.copy(revision = revision, commandReceipts = result.state.commandReceipts + receipt, commitment = "")
        val committed = unsigned.copy(commitment = ProKernel().commitment(unsigned))
        kernel.validateSavedState(committed)
        current = committed
        return ProDispatchResult(committed, resultHash, duplicate = false)
    }

    private fun apply(state: ProState, command: ProCommand): ProResult = when (command) {
        is ProCommand.StartLinked, is ProCommand.StartDirect -> error("pro.command.start_duplicate")
        ProCommand.SignContract -> kernel.signContract(state, state.seed)
        is ProCommand.PlanWeek -> kernel.planWeek(state, command.seed, command.plan, command.targetPitch)
        is ProCommand.AdvanceSegment -> kernel.advanceSegment(state, command.seed, command.plan, command.targetPitch, command.maximumWeeks)
        is ProCommand.ApplySeasonDecision -> kernel.applySeasonDecision(state, command.seed, command.decisionId, command.choiceId)
        is ProCommand.ReserveImportantGame -> kernel.reserveImportantGame(state, command.seed)
        is ProCommand.SubmitPitch -> {
            require(command.pitchSessionId == state.activePitch?.sessionId) { "pro.command.pitch_session_mismatch" }
            kernel.submitPitch(state, command.pitchSessionId, command.call, command.delivery)
        }
        ProCommand.FinishImportantGame -> kernel.finishImportantGame(state)
        is ProCommand.ReviewSeason -> kernel.reviewSeason(state, command.seed)
        is ProCommand.ChooseOffseason -> kernel.chooseOffseason(state, command.seed, command.decision)
        is ProCommand.SelectLegacy -> kernel.selectLegacy(state, command.legacyId)
        ProCommand.NormalizeBalance -> kernel.normalizeBalance(state)
    }
}
