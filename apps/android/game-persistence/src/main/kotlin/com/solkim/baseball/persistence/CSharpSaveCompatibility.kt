package com.solkim.baseball.persistence

import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import com.solkim.baseball.model.Hashing
import com.solkim.baseball.model.canonicalSha256

/**
 * Compatibility-only bridge for the real Unity v1 payload. Native shadow state uses the typed
 * GameAggregate codec; this bridge deliberately emits only fields understood by the C# reader.
 */
public object CSharpSaveCompatibilityCodec {
    private val payloadFields = setOf(
        "aggregateVersion", "revision", "installId", "stage", "highSchool", "pro", "meta", "pitchResume",
        "pendingPitchCompletion", "settings", "analyticsReceipts", "commandReceipts", "deleted",
    )
    private val stages = setOf("opening", "setup", "highSchool", "draft", "pro", "retirement", "legacy", "betweenLives", "deleted")

    public fun read(bytes: ByteArray): LegacySaveDocument {
        val document = LegacySaveCodec.requireValid(bytes)
        validateKnownCSharpPayload(document.payload)
        return document
    }

    /** Produces a Kotlin-written fixture without adding fields that Newtonsoft rejects. */
    public fun rewriteRevision(document: LegacySaveDocument, revision: ULong): ByteArray {
        require(revision >= document.revision) { "csharp.revision_regression" }
        val payloadEntries = LinkedHashMap(document.payload.entries)
        payloadEntries["revision"] = JsonValue.Num(revision.toString())
        val payload = JsonValue.Obj(payloadEntries)
        val rootEntries = LinkedHashMap(document.root.entries)
        rootEntries["revision"] = JsonValue.Str(revision.toString())
        rootEntries["payload"] = payload
        rootEntries["payloadSha256"] = JsonValue.Str(payload.canonicalSha256())
        return StrictJson.canonical(JsonValue.Obj(rootEntries)).toByteArray(Charsets.UTF_8)
    }

    public fun semantic(document: LegacySaveDocument): CSharpSemanticSave {
        validateKnownCSharpPayload(document.payload)
        val highSchool = document.payload["highSchool"] as? JsonValue.Obj
        val analytics = document.payload["analyticsReceipts"] as? JsonValue.Obj
        val analyticsRecords = analytics?.get("records") as? JsonValue.Arr
        val commandReceipts = document.payload["commandReceipts"] as? JsonValue.Arr
        return CSharpSemanticSave(
            revision = document.revision,
            aggregateRevision = document.payloadRevision,
            installId = document.payload.string("installId"),
            aggregateVersion = document.payload.integer("aggregateVersion"),
            stage = document.payload.string("stage"),
            deleted = document.payload.bool("deleted"),
            payloadCanonicalSha256 = document.payload.canonicalSha256(),
            optionalNullPaths = listOf("pro", "pitchResume", "pendingPitchCompletion").filter { document.payload[it] == JsonValue.Null },
            settingsCanonicalSha256 = (document.payload["settings"] as? JsonValue.Obj)?.canonicalSha256(),
            commandReceiptCount = commandReceipts?.values?.size ?: 0,
            analyticsReceiptCount = analyticsRecords?.values?.size ?: 0,
            coreStateCommitmentSha256 = (highSchool?.get("coreStateJson") as? JsonValue.Str)?.value?.let(Hashing::sha256Hex),
        )
    }

    public fun validatePayload(payload: JsonValue.Obj) {
        val missing = payloadFields - payload.entries.keys
        val unknown = payload.entries.keys - payloadFields
        if (missing.isNotEmpty()) throw LegacySaveCompatibilityException("csharp.payload_missing:${missing.sorted().joinToString(",")}")
        if (unknown.isNotEmpty()) throw LegacySaveCompatibilityException("csharp.payload_unknown:${unknown.sorted().joinToString(",")}")
        val stage = payload.string("stage")
        if (stage !in stages) throw LegacySaveCompatibilityException("csharp.stage_unknown:$stage")
        if (payload["deleted"] !is JsonValue.Bool) throw LegacySaveCompatibilityException("csharp.deleted_invalid")
        payload["highSchool"]?.let { if (it !is JsonValue.Obj && it !== JsonValue.Null) throw LegacySaveCompatibilityException("csharp.highSchool_invalid") }
        payload["pro"]?.let { if (it !is JsonValue.Obj && it !== JsonValue.Null) throw LegacySaveCompatibilityException("csharp.pro_invalid") }
    }

    private fun validateKnownCSharpPayload(payload: JsonValue.Obj) = validatePayload(payload)

    private fun JsonValue.Obj.string(name: String): String = (this[name] as? JsonValue.Str)?.value ?: throw LegacySaveCompatibilityException("csharp.${name}_string")
    private fun JsonValue.Obj.integer(name: String): Int = (this[name] as? JsonValue.Num)?.raw?.toIntOrNull() ?: throw LegacySaveCompatibilityException("csharp.${name}_integer")
    private fun JsonValue.Obj.bool(name: String): Boolean = (this[name] as? JsonValue.Bool)?.value ?: throw LegacySaveCompatibilityException("csharp.${name}_bool")
}

public data class CSharpSemanticSave(
    val revision: ULong,
    val aggregateRevision: ULong,
    val installId: String,
    val aggregateVersion: Int,
    val stage: String,
    val deleted: Boolean,
    val payloadCanonicalSha256: String,
    val optionalNullPaths: List<String>,
    val settingsCanonicalSha256: String? = null,
    val commandReceiptCount: Int = 0,
    val analyticsReceiptCount: Int = 0,
    val coreStateCommitmentSha256: String? = null,
)
