package com.solkim.baseball.persistence

import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import com.solkim.baseball.model.StrictJsonException
import com.solkim.baseball.model.canonicalSha256
import java.time.Instant
import java.time.format.DateTimeParseException

public object LegacySaveContract {
    public const val SCHEMA: String = "android-unity-save-v1"
    public const val SCHEMA_VERSION: Int = 1
    public const val MAX_BYTES: Int = 4 * 1024 * 1024
    public const val MAX_DEPTH: Int = 128
    private val timestampPattern = Regex("\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}Z")
    private val decimalPattern = Regex("0|[1-9][0-9]*")
    private val sha256Pattern = Regex("[0-9a-fA-F]{64}")

    internal fun validateRevision(value: String, field: String): ULong =
        if (decimalPattern.matches(value)) {
            value.toULongOrNull() ?: throw LegacySaveCompatibilityException("$field.bounds")
        } else {
            throw LegacySaveCompatibilityException("$field.invalid")
        }

    internal fun validateTimestamp(value: String) {
        if (!timestampPattern.matches(value)) throw LegacySaveCompatibilityException("writtenAtUtc.invalid")
        try {
            Instant.parse(value)
        } catch (_: DateTimeParseException) {
            throw LegacySaveCompatibilityException("writtenAtUtc.invalid")
        }
    }

    internal fun validateSha(value: String) {
        if (!sha256Pattern.matches(value)) throw LegacySaveCompatibilityException("payloadSha256.invalid")
    }
}

public sealed interface LegacySaveDecodeResult {
    public data class Valid(public val document: LegacySaveDocument) : LegacySaveDecodeResult
    public data class FutureSchema(public val schemaVersion: Int, public val raw: JsonValue.Obj) : LegacySaveDecodeResult
    public data class MigrationRequired(public val schemaVersion: Int, public val raw: JsonValue.Obj) : LegacySaveDecodeResult
    public data class Invalid(public val reason: String) : LegacySaveDecodeResult
}

public class LegacySaveCompatibilityException(message: String) : IllegalArgumentException(message)

/** A valid v1 envelope retained as a tree so additive fields are never silently dropped. */
public data class LegacySaveDocument(
    public val root: JsonValue.Obj,
    public val revision: ULong,
    public val payloadRevision: ULong,
    public val payloadSha256: String,
) {
    public val schema: String = LegacySaveContract.SCHEMA
    public val schemaVersion: Int = LegacySaveContract.SCHEMA_VERSION
    public val payload: JsonValue.Obj = root.requiredObject("payload")

    public fun withPayloadField(name: String, value: JsonValue): LegacySaveDocument {
        requireSafeFieldName(name)
        val payloadEntries = LinkedHashMap(payload.entries)
        payloadEntries[name] = value
        val rootEntries = LinkedHashMap(root.entries)
        val updatedPayload = JsonValue.Obj(payloadEntries)
        rootEntries["payload"] = updatedPayload
        rootEntries["payloadSha256"] = JsonValue.Str(updatedPayload.canonicalSha256())
        return LegacySaveCodec.requireValid(StrictJson.compact(JsonValue.Obj(rootEntries)).toByteArray())
    }

    public fun withTopLevelField(name: String, value: JsonValue): LegacySaveDocument {
        requireSafeFieldName(name)
        val rootEntries = LinkedHashMap(root.entries)
        rootEntries[name] = value
        return LegacySaveCodec.requireValid(StrictJson.compact(JsonValue.Obj(rootEntries)).toByteArray())
    }

    private fun requireSafeFieldName(name: String) {
        if (name.isBlank() || name.any { it.code < 0x20 }) {
            throw LegacySaveCompatibilityException("field.name.invalid")
        }
    }
}

public object LegacySaveCodec {
    private val envelopeFields = setOf(
        "schema", "schemaVersion", "revision", "writtenAtUtc", "payloadSha256", "payload",
    )

    public fun decode(bytes: ByteArray): LegacySaveDecodeResult {
        if (bytes.isEmpty()) return LegacySaveDecodeResult.Invalid("file.empty")
        if (bytes.size > LegacySaveContract.MAX_BYTES) return LegacySaveDecodeResult.Invalid("file.too_large")
        val root = try {
            StrictJson.parseUtf8(bytes, LegacySaveContract.MAX_DEPTH)
        } catch (error: Exception) {
            return LegacySaveDecodeResult.Invalid(
                "json.invalid:${error.javaClass.simpleName}",
            )
        }
        val envelope = root as? JsonValue.Obj
            ?: return LegacySaveDecodeResult.Invalid("top_level.object_required")
        val schema = envelope.string("schema")
            ?: return LegacySaveDecodeResult.Invalid("schema.invalid")
        if (schema != LegacySaveContract.SCHEMA) return LegacySaveDecodeResult.Invalid("schema.unknown")
        val schemaVersion = envelope.integer("schemaVersion")
            ?: return LegacySaveDecodeResult.Invalid("schemaVersion.invalid")
        if (schemaVersion > LegacySaveContract.SCHEMA_VERSION) {
            return LegacySaveDecodeResult.FutureSchema(schemaVersion, envelope)
        }
        if (schemaVersion < LegacySaveContract.SCHEMA_VERSION) {
            return LegacySaveDecodeResult.MigrationRequired(schemaVersion, envelope)
        }
        return try {
            validateKnownEnvelope(envelope)
            val revisionText = envelope.requiredString("revision")
            val revision = LegacySaveContract.validateRevision(revisionText, "revision")
            LegacySaveContract.validateTimestamp(envelope.requiredString("writtenAtUtc"))
            val payload = envelope.requiredObject("payload")
            val payloadRevision = validatePayload(payload)
            val declaredHash = envelope.requiredString("payloadSha256")
            LegacySaveContract.validateSha(declaredHash)
            val actualHash = payload.canonicalSha256()
            if (!actualHash.equals(declaredHash, ignoreCase = true)) {
                throw LegacySaveCompatibilityException("payloadSha256.mismatch")
            }
            LegacySaveDecodeResult.Valid(
                LegacySaveDocument(envelope, revision, payloadRevision, actualHash),
            )
        } catch (error: LegacySaveCompatibilityException) {
            LegacySaveDecodeResult.Invalid(error.message ?: "save.invalid")
        } catch (error: Exception) {
            LegacySaveDecodeResult.Invalid("save.invalid:${error.javaClass.simpleName}")
        }
    }

    public fun reencode(document: LegacySaveDocument): ByteArray {
        // Re-parse before writing so callers cannot bypass the fail-closed contract by mutating a
        // retained JsonObject map after decode.
        val encoded = StrictJson.compact(document.root).toByteArray(Charsets.UTF_8)
        requireValid(encoded)
        return encoded
    }

    public fun requireValid(bytes: ByteArray): LegacySaveDocument = when (val result = decode(bytes)) {
        is LegacySaveDecodeResult.Valid -> result.document
        is LegacySaveDecodeResult.FutureSchema ->
            throw LegacySaveCompatibilityException("schema.future:${result.schemaVersion}")
        is LegacySaveDecodeResult.MigrationRequired ->
            throw LegacySaveCompatibilityException("schema.migration:${result.schemaVersion}")
        is LegacySaveDecodeResult.Invalid -> throw LegacySaveCompatibilityException(result.reason)
    }

    private fun validateKnownEnvelope(envelope: JsonValue.Obj) {
        envelope.entries.keys.filter { it in envelopeFields }.forEach { field ->
            if (envelope[field] is JsonValue.Null) throw LegacySaveCompatibilityException("$field.null")
        }
        envelope.requiredString("schema")
        envelope.integer("schemaVersion") ?: throw LegacySaveCompatibilityException("schemaVersion.invalid")
    }

    private fun validatePayload(payload: JsonValue.Obj): ULong {
        val aggregateVersion = payload.integer("aggregateVersion")
            ?: throw LegacySaveCompatibilityException("payload.aggregateVersion.invalid")
        if (aggregateVersion !in 0..4) throw LegacySaveCompatibilityException("payload.aggregateVersion.unsupported")
        // The current C# payload serializes its aggregate revision as a JSON integer, while the
        // envelope revision is a decimal string. Accept both wire representations and retain the
        // exact unsigned aggregate revision separately: C# may advance the envelope revision
        // without mutating an already-materialized aggregate payload.
        val payloadRevision = when (val value = payload["revision"]) {
            is JsonValue.Str -> value.value
            is JsonValue.Num -> value.raw
            else -> throw LegacySaveCompatibilityException("payload.revision.invalid")
        }
        val aggregateRevision = LegacySaveContract.validateRevision(payloadRevision, "payload.revision")
        if (payload.requiredString("installId").isBlank()) {
            throw LegacySaveCompatibilityException("payload.installId.empty")
        }
        if (payload.requiredString("stage").isBlank()) {
            throw LegacySaveCompatibilityException("payload.stage.empty")
        }
        if (payload["deleted"] != null && payload["deleted"] !is JsonValue.Bool) {
            throw LegacySaveCompatibilityException("payload.deleted.invalid")
        }
        payload["commandReceipts"]?.let { value ->
            if (value !is JsonValue.Arr || value.values.any { it !is JsonValue.Str }) {
                throw LegacySaveCompatibilityException("payload.commandReceipts.invalid")
            }
        }
        return aggregateRevision
    }
}

private fun JsonValue.Obj.string(name: String): String? = (this[name] as? JsonValue.Str)?.value

private fun JsonValue.Obj.requiredString(name: String): String = string(name)
    ?: throw LegacySaveCompatibilityException("$name.invalid")

private fun JsonValue.Obj.integer(name: String): Int? {
    val raw = (this[name] as? JsonValue.Num)?.raw ?: return null
    if (!Regex("-?(0|[1-9][0-9]*)").matches(raw)) return null
    return raw.toLongOrNull()?.takeIf { it in Int.MIN_VALUE..Int.MAX_VALUE }?.toInt()
}

private fun JsonValue.Obj.requiredObject(name: String): JsonValue.Obj = this[name] as? JsonValue.Obj
    ?: throw LegacySaveCompatibilityException("$name.object_required")
