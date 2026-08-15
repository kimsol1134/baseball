package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase4StateCodec
import com.solkim.baseball.core.pro.ProStateCodec
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.persistence.JsonPayloadCodec
import java.util.Base64

/** Strict native shadow payload. The outer save envelope stays the legacy v1 contract. */
public object GameAggregateCodec : JsonPayloadCodec<GameAggregateState> {
    private val fields = setOf(
        "aggregateVersion", "revision", "installId", "stage", "highSchool", "pro", "meta", "pitch",
        "settings", "analytics", "commandReceipts", "deleted", "commitment",
    )
    private val metaFields = setOf("completedGameCount", "achievementIds", "weeklyReceiptIds", "returnPlanReceiptIds", "decisionReceiptIds", "activeHighSchoolCareerId", "lifeArchiveCareerIds")
    private val settingsFields = setOf("autoReleaseEnabled", "soundEnabled", "musicEnabled", "hapticsEnabled", "notificationsEnabled", "highContrastEnabled", "reducedMotionEnabled")
    private val pitchFields = setOf("sessionId", "careerKind", "careerId", "gameId", "seed", "boundary", "challengeRun", "pitchIndex", "committedPitchIds", "consumedPitchIds", "terminalPitchId", "resultHashes", "checkpoint", "suspendedFrom", "abandonedReason")
    private val analyticsFields = setOf("receipts")
    private val receiptFields = setOf("commandId", "sessionId", "expectedRevision", "committedRevision", "commandHash", "resultHash", "eventName")
    private val analyticsReceiptFields = setOf("receiptId", "eventName", "revision", "commitment", "properties")
    private val propertyFields = setOf("key", "value")

    override fun validate(value: GameAggregateState) {
        value.validate()
    }

    override fun encodePayload(value: GameAggregateState): JsonValue.Obj {
        value.validate()
        return JsonValue.Obj(linkedMapOf<String, JsonValue>(
            "aggregateVersion" to JsonValue.Num(value.aggregateVersion.toString()),
            "revision" to JsonValue.Str(value.revision.toString()),
            "installId" to JsonValue.Str(value.installId),
            "stage" to JsonValue.Str(value.stage.wire),
            "highSchool" to if (value.highSchool == null) JsonValue.Null else JsonValue.Str(encodeBytes(HighSchoolPhase4StateCodec.encode(value.highSchool))),
            "pro" to if (value.pro == null) JsonValue.Null else JsonValue.Str(encodeBytes(ProStateCodec.encode(value.pro))),
            "meta" to encodeMeta(value.meta),
            "pitch" to if (value.pitch == null) JsonValue.Null else encodePitch(value.pitch),
            "settings" to encodeSettings(value.settings),
            "analytics" to JsonValue.Obj(linkedMapOf("receipts" to JsonValue.Arr(value.analytics.receipts.map(::encodeAnalyticsReceipt)))),
            "commandReceipts" to JsonValue.Arr(value.commandReceipts.map(::encodeCommandReceipt)),
            "deleted" to JsonValue.Bool(value.deleted),
            "commitment" to JsonValue.Str(value.commitment),
        ))
    }

    override fun decodePayload(value: JsonValue.Obj): GameAggregateState {
        requireExact(value, fields, "aggregate")
        val state = GameAggregateState(
            aggregateVersion = value.integer("aggregateVersion"),
            revision = value.decimal("revision"),
            installId = value.string("installId"),
            stage = enumWire(value.string("stage"), GameStage.entries, "stage") { it.wire },
            highSchool = value.nullableString("highSchool")?.let { decodeBytes(it).let(HighSchoolPhase4StateCodec::decode) },
            pro = value.nullableString("pro")?.let { decodeBytes(it).let(ProStateCodec::decode) },
            meta = decodeMeta(value.objectValue("meta")),
            pitch = value.nullableObject("pitch")?.let(::decodePitch),
            settings = decodeSettings(value.objectValue("settings")),
            analytics = decodeAnalytics(value.objectValue("analytics")),
            commandReceipts = value.array("commandReceipts").mapIndexed { index, item -> decodeCommandReceipt(item.asObject("commandReceipts[$index]")) },
            deleted = value.bool("deleted"),
            commitment = value.string("commitment"),
        )
        try { state.validate() } catch (error: IllegalArgumentException) { throw GameSaveCodecException(error.message ?: "aggregate.invalid") }
        return state
    }

    private fun encodeMeta(value: GameMetaState): JsonValue.Obj = JsonValue.Obj(linkedMapOf<String, JsonValue>(
        "completedGameCount" to JsonValue.Str(value.completedGameCount.toString()),
        "achievementIds" to JsonValue.Arr(value.achievementIds.map { JsonValue.Str(it) }),
        "weeklyReceiptIds" to JsonValue.Arr(value.weeklyReceiptIds.map { JsonValue.Str(it) }),
        "returnPlanReceiptIds" to JsonValue.Arr(value.returnPlanReceiptIds.map { JsonValue.Str(it) }),
        "decisionReceiptIds" to JsonValue.Arr(value.decisionReceiptIds.map { JsonValue.Str(it) }),
        "activeHighSchoolCareerId" to if (value.activeHighSchoolCareerId == null) JsonValue.Null else JsonValue.Str(value.activeHighSchoolCareerId),
        "lifeArchiveCareerIds" to JsonValue.Arr(value.lifeArchiveCareerIds.map { JsonValue.Str(it) }),
    ))

    private fun decodeMeta(value: JsonValue.Obj): GameMetaState {
        requireExact(value, metaFields, "meta")
        return GameMetaState(
            completedGameCount = value.decimal("completedGameCount"),
            achievementIds = value.strings("achievementIds"),
            weeklyReceiptIds = value.strings("weeklyReceiptIds"),
            returnPlanReceiptIds = value.strings("returnPlanReceiptIds"),
            decisionReceiptIds = value.strings("decisionReceiptIds"),
            activeHighSchoolCareerId = value.nullableString("activeHighSchoolCareerId"),
            lifeArchiveCareerIds = value.strings("lifeArchiveCareerIds"),
        )
    }

    private fun encodeSettings(value: GameSettingsState): JsonValue.Obj = JsonValue.Obj(linkedMapOf<String, JsonValue>(
        "autoReleaseEnabled" to JsonValue.Bool(value.autoReleaseEnabled), "soundEnabled" to JsonValue.Bool(value.soundEnabled),
        "musicEnabled" to JsonValue.Bool(value.musicEnabled), "hapticsEnabled" to JsonValue.Bool(value.hapticsEnabled),
        "notificationsEnabled" to JsonValue.Bool(value.notificationsEnabled), "highContrastEnabled" to JsonValue.Bool(value.highContrastEnabled),
        "reducedMotionEnabled" to JsonValue.Bool(value.reducedMotionEnabled),
    ))

    private fun decodeSettings(value: JsonValue.Obj): GameSettingsState {
        requireExact(value, settingsFields, "settings")
        return GameSettingsState(
            autoReleaseEnabled = value.bool("autoReleaseEnabled"), soundEnabled = value.bool("soundEnabled"), musicEnabled = value.bool("musicEnabled"),
            hapticsEnabled = value.bool("hapticsEnabled"), notificationsEnabled = value.bool("notificationsEnabled"), highContrastEnabled = value.bool("highContrastEnabled"), reducedMotionEnabled = value.bool("reducedMotionEnabled"),
        )
    }

    private fun encodePitch(value: PitchDurableState): JsonValue.Obj = JsonValue.Obj(linkedMapOf<String, JsonValue>(
        "sessionId" to JsonValue.Str(value.sessionId), "careerKind" to JsonValue.Str(value.careerKind.wire), "careerId" to JsonValue.Str(value.careerId), "gameId" to JsonValue.Str(value.gameId), "seed" to JsonValue.Str(value.seed),
        "boundary" to JsonValue.Str(value.boundary.wire), "challengeRun" to JsonValue.Bool(value.challengeRun), "pitchIndex" to JsonValue.Num(value.pitchIndex.toString()),
        "committedPitchIds" to JsonValue.Arr(value.committedPitchIds.map { JsonValue.Str(it) }), "consumedPitchIds" to JsonValue.Arr(value.consumedPitchIds.map { JsonValue.Str(it) }),
        "terminalPitchId" to if (value.terminalPitchId == null) JsonValue.Null else JsonValue.Str(value.terminalPitchId), "resultHashes" to JsonValue.Arr(value.resultHashes.map { JsonValue.Str(it) }),
        "checkpoint" to if (value.checkpoint == null) JsonValue.Null else JsonValue.Str(value.checkpoint), "suspendedFrom" to if (value.suspendedFrom == null) JsonValue.Null else JsonValue.Str(value.suspendedFrom.wire),
        "abandonedReason" to if (value.abandonedReason == null) JsonValue.Null else JsonValue.Str(value.abandonedReason),
    ))

    private fun decodePitch(value: JsonValue.Obj): PitchDurableState {
        requireExact(value, pitchFields, "pitch")
        return PitchDurableState(
            sessionId = value.string("sessionId"), careerKind = enumWire(value.string("careerKind"), PitchCareerKind.entries, "pitch.careerKind") { it.wire }, careerId = value.string("careerId"), gameId = value.string("gameId"), seed = value.string("seed"),
            boundary = enumWire(value.string("boundary"), PitchBoundary.entries, "pitch.boundary") { it.wire }, pitchIndex = value.integer("pitchIndex"),
            challengeRun = value.bool("challengeRun"),
            committedPitchIds = value.strings("committedPitchIds"), consumedPitchIds = value.strings("consumedPitchIds"), terminalPitchId = value.nullableString("terminalPitchId"), resultHashes = value.strings("resultHashes"),
            checkpoint = value.nullableString("checkpoint"), suspendedFrom = value.nullableString("suspendedFrom")?.let { enumWire(it, PitchBoundary.entries, "pitch.suspendedFrom") { item -> item.wire } }, abandonedReason = value.nullableString("abandonedReason"),
        )
    }

    private fun encodeCommandReceipt(value: GameCommandReceipt): JsonValue.Obj = JsonValue.Obj(linkedMapOf<String, JsonValue>(
        "commandId" to JsonValue.Str(value.commandId), "sessionId" to JsonValue.Str(value.sessionId), "expectedRevision" to JsonValue.Str(value.expectedRevision.toString()), "committedRevision" to JsonValue.Str(value.committedRevision.toString()), "commandHash" to JsonValue.Str(value.commandHash), "resultHash" to JsonValue.Str(value.resultHash), "eventName" to JsonValue.Str(value.eventName),
    ))

    private fun decodeCommandReceipt(value: JsonValue.Obj): GameCommandReceipt {
        requireExact(value, receiptFields, "commandReceipt")
        return GameCommandReceipt(value.string("commandId"), value.string("sessionId"), value.decimal("expectedRevision"), value.decimal("committedRevision"), value.string("commandHash"), value.string("resultHash"), value.string("eventName"))
    }

    private fun encodeAnalyticsReceipt(value: AnalyticsReceipt): JsonValue.Obj = JsonValue.Obj(linkedMapOf<String, JsonValue>(
        "receiptId" to JsonValue.Str(value.receiptId), "eventName" to JsonValue.Str(value.eventName), "revision" to JsonValue.Str(value.revision.toString()), "commitment" to JsonValue.Str(value.commitment),
        "properties" to JsonValue.Arr(value.properties.map { (key, item) -> JsonValue.Obj(linkedMapOf<String, JsonValue>("key" to JsonValue.Str(key), "value" to JsonValue.Str(item))) }),
    ))

    private fun decodeAnalyticsReceipt(value: JsonValue.Obj): AnalyticsReceipt {
        requireExact(value, analyticsReceiptFields, "analyticsReceipt")
        val properties = value.array("properties").mapIndexed { index, item ->
            val property = item.asObject("analytics.properties[$index]")
            requireExact(property, propertyFields, "analytics.property")
            property.string("key") to property.string("value")
        }
        return AnalyticsReceipt(value.string("receiptId"), value.string("eventName"), value.decimal("revision"), value.string("commitment"), properties)
    }

    private fun decodeAnalytics(value: JsonValue.Obj): AnalyticsReceiptState {
        requireExact(value, analyticsFields, "analytics")
        return AnalyticsReceiptState(value.array("receipts").mapIndexed { index, item -> decodeAnalyticsReceipt(item.asObject("analytics.receipts[$index]")) })
    }

    private fun encodeBytes(bytes: ByteArray): String = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
    private fun decodeBytes(value: String): ByteArray = try {
        val bytes = Base64.getUrlDecoder().decode(value)
        require(Base64.getUrlEncoder().withoutPadding().encodeToString(bytes) == value) { "aggregate.base64_noncanonical" }
        bytes
    } catch (error: IllegalArgumentException) { throw GameSaveCodecException(error.message ?: "aggregate.base64") }

    private fun requireExact(value: JsonValue.Obj, expected: Set<String>, field: String) {
        val missing = expected - value.entries.keys
        val unknown = value.entries.keys - expected
        if (missing.isNotEmpty()) throw GameSaveCodecException("$field.missing:${missing.sorted().joinToString(",")}")
        if (unknown.isNotEmpty()) throw GameSaveCodecException("$field.unknown:${unknown.sorted().joinToString(",")}")
    }

    private inline fun <reified E : Enum<E>> enumWire(raw: String, values: Iterable<E>, field: String, wire: (E) -> String): E =
        values.firstOrNull { wire(it) == raw } ?: throw GameSaveCodecException("$field.unknown:$raw")

    private fun JsonValue.Obj.string(name: String): String = (this[name] as? JsonValue.Str)?.value ?: throw GameSaveCodecException("$name.string")
    private fun JsonValue.Obj.nullableString(name: String): String? = when (val value = this[name]) { null, JsonValue.Null -> null; is JsonValue.Str -> value.value; else -> throw GameSaveCodecException("$name.string_or_null") }
    private fun JsonValue.Obj.integer(name: String): Int { val raw = (this[name] as? JsonValue.Num)?.raw ?: throw GameSaveCodecException("$name.integer"); if (!Regex("-?(0|[1-9][0-9]*)").matches(raw)) throw GameSaveCodecException("$name.integer"); return raw.toIntOrNull() ?: throw GameSaveCodecException("$name.bounds") }
    private fun JsonValue.Obj.decimal(name: String): ULong { val raw = when (val value = this[name]) { is JsonValue.Str -> value.value; is JsonValue.Num -> value.raw; else -> throw GameSaveCodecException("$name.decimal") }; if (!Regex("0|[1-9][0-9]*").matches(raw)) throw GameSaveCodecException("$name.decimal"); return raw.toULongOrNull() ?: throw GameSaveCodecException("$name.bounds") }
    private fun JsonValue.Obj.bool(name: String): Boolean = (this[name] as? JsonValue.Bool)?.value ?: throw GameSaveCodecException("$name.boolean")
    private fun JsonValue.Obj.array(name: String): List<JsonValue> = (this[name] as? JsonValue.Arr)?.values ?: throw GameSaveCodecException("$name.array")
    private fun JsonValue.Obj.strings(name: String): List<String> = array(name).mapIndexed { index, value -> (value as? JsonValue.Str)?.value ?: throw GameSaveCodecException("$name[$index].string") }
    private fun JsonValue.Obj.objectValue(name: String): JsonValue.Obj = (this[name] as? JsonValue.Obj) ?: throw GameSaveCodecException("$name.object")
    private fun JsonValue.Obj.nullableObject(name: String): JsonValue.Obj? = when (val value = this[name]) { null, JsonValue.Null -> null; is JsonValue.Obj -> value; else -> throw GameSaveCodecException("$name.object_or_null") }
    private fun JsonValue.asObject(field: String): JsonValue.Obj = this as? JsonValue.Obj ?: throw GameSaveCodecException("$field.object")
}

public class GameSaveCodecException(message: String) : IllegalArgumentException(message)
