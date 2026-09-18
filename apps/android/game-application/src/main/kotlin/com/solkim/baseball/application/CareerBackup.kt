package com.solkim.baseball.application

import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import com.solkim.baseball.model.canonicalSha256
import com.solkim.baseball.persistence.CSharpSaveCompatibilityCodec

/** Portable native career only; no platform credentials, files, or external analytics outbox. */
public object CareerBackup {
    public const val MAX_BYTES: Int = 8 * 1024 * 1024
    public fun isAvailable(state: GameAggregateState): Boolean = state.meta.seedChallenge == null && state.highSchool?.challenge?.active != true
    internal fun encode(payload: JsonValue.Obj): ByteArray {
        val bytes = StrictJson.canonical(JsonValue.Obj(linkedMapOf(
            "format" to JsonValue.Str("baseball-career-backup-v1"),
            "checksum" to JsonValue.Str(payload.canonicalSha256()),
            "payload" to payload,
        ))).toByteArray(Charsets.UTF_8)
        require(bytes.size <= MAX_BYTES) { "backup.too_large" }
        return bytes
    }
    internal fun decode(bytes: ByteArray): JsonValue.Obj {
        require(bytes.isNotEmpty() && bytes.size <= MAX_BYTES) { "backup.size" }
        val root = StrictJson.parseUtf8(bytes) as? JsonValue.Obj ?: error("backup.format")
        require(root.entries.keys == setOf("format", "checksum", "payload")) { "backup.fields" }
        require((root["format"] as? JsonValue.Str)?.value == "baseball-career-backup-v1") { "backup.version" }
        val payload = root["payload"] as? JsonValue.Obj ?: error("backup.payload")
        require(payload.canonicalSha256() == (root["checksum"] as? JsonValue.Str)?.value) { "backup.checksum" }
        CSharpSaveCompatibilityCodec.validatePayload(payload)
        val state = CSharpLegacyAggregateBridge.project(payload, 0UL, payload.canonicalSha256())
        state.meta.validate()
        require(isAvailable(state)) { "backup.challenge_snapshot" }
        return payload
    }
    internal fun encodeShadow(state: GameAggregateState): ByteArray {
        require(isAvailable(state))
        val payload = GameAggregateCodec.encodePayload(state)
        val bytes = StrictJson.canonical(JsonValue.Obj(linkedMapOf("format" to JsonValue.Str("baseball-shadow-backup-v1"),
            "checksum" to JsonValue.Str(payload.canonicalSha256()), "payload" to payload))).toByteArray(Charsets.UTF_8)
        require(bytes.size <= MAX_BYTES)
        return bytes
    }
    internal fun shadow(bytes: ByteArray): GameAggregateState? {
        require(bytes.isNotEmpty() && bytes.size <= MAX_BYTES)
        val root = StrictJson.parseUtf8(bytes) as? JsonValue.Obj ?: error("backup.format")
        if ((root["format"] as? JsonValue.Str)?.value != "baseball-shadow-backup-v1") return null
        require(root.entries.keys == setOf("format", "checksum", "payload"))
        val payload = root["payload"] as? JsonValue.Obj ?: error("backup.payload")
        require(payload.canonicalSha256() == (root["checksum"] as? JsonValue.Str)?.value)
        return GameAggregateCodec.decodePayload(payload).also { require(isAvailable(it)) }
    }
    public fun preview(bytes: ByteArray): GameAggregateState {
        shadow(bytes)?.let { return it }
        val payload = decode(bytes)
        return CSharpLegacyAggregateBridge.project(payload, 0UL, payload.canonicalSha256())
    }
}
