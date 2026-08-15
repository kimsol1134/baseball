package com.solkim.baseball.core.pro

import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.util.Base64

/**
 * Additive v2 save envelope. The old v1 JSON and binary payload are embedded as a length-prefixed
 * block; the optional journey block is a second length-prefixed block. This keeps old saves
 * readable without pretending a v1 decoder can understand journey state.
 */
public object ProStateCodecV2 {
    public const val SCHEMA: String = "baseball-pro-state-v2"
    public const val SCHEMA_VERSION: Int = 2
    private const val MAGIC: String = "PRM2"
    private const val MAX_BYTES: Int = 4 * 1024 * 1024
    private val ROOT_FIELDS = setOf("schema", "schemaVersion", "payload", "stateCommitment")

    public fun encode(state: ProState): ByteArray {
        try { ProKernel().validateSavedState(state) } catch (error: IllegalArgumentException) { throw ProStateCodecException(error.message ?: "pro.state.invalid") }
        val legacy = state.copy(journeyState = null, commitment = "")
        val legacyWithCommitment = legacy.copy(commitment = ProKernel().commitment(legacy))
        val legacyBytes = ProStateCodec.encode(legacyWithCommitment)
        val journeyBytes = state.journeyState?.let(ProJourneyStateCodec::encode) ?: ByteArray(0)
        val payload = ByteArrayOutputStream().also { output ->
            DataOutputStream(output).use { data ->
                data.writeUTF(MAGIC)
                data.writeInt(legacyBytes.size)
                data.write(legacyBytes)
                data.writeInt(journeyBytes.size)
                data.write(journeyBytes)
            }
        }.toByteArray()
        val root = JsonValue.Obj(linkedMapOf(
            "schema" to JsonValue.Str(SCHEMA),
            "schemaVersion" to JsonValue.Num(SCHEMA_VERSION.toString()),
            "payload" to JsonValue.Str(Base64.getEncoder().encodeToString(payload)),
            "stateCommitment" to JsonValue.Str(state.commitment),
        ))
        return StrictJson.canonical(root).toByteArray(Charsets.UTF_8)
    }

    /** Decodes both a v2 save and an unchanged v1 save. v1 returns the legacy aggregate unchanged. */
    public fun decode(bytes: ByteArray): ProState {
        if (bytes.isEmpty()) throw ProStateCodecException("pro.state.empty")
        if (bytes.size > MAX_BYTES) throw ProStateCodecException("pro.state.too_large")
        val root = parseRoot(bytes)
        val schema = root.string("schema")
        if (schema == ProStateCodec.SCHEMA) return ProStateCodec.decode(bytes)
        require(schema == SCHEMA) { "pro.state.schema" }
        val version = root.integer("schemaVersion")
        require(version == SCHEMA_VERSION) { if (version > SCHEMA_VERSION) "pro.state.future:$version" else "pro.state.migration:$version" }
        val payload = try { Base64.getDecoder().decode(root.string("payload")) } catch (_: Exception) { throw ProStateCodecException("pro.state.payload") }
        val input = try { DataInputStream(ByteArrayInputStream(payload)) } catch (_: Exception) { throw ProStateCodecException("pro.state.payload_invalid") }
        val legacyBytes: ByteArray
        val journeyBytes: ByteArray
        try {
            require(input.readUTF() == MAGIC) { "pro.state.magic" }
            legacyBytes = input.readLengthPrefixed()
            journeyBytes = input.readLengthPrefixed()
            require(input.available() == 0) { "pro.state.trailing_bytes" }
        } catch (error: ProStateCodecException) { throw error } catch (_: Exception) { throw ProStateCodecException("pro.state.payload_invalid") }
        val legacy = ProStateCodec.decode(legacyBytes)
        val journey = if (journeyBytes.isEmpty()) null else ProJourneyStateCodec.decode(journeyBytes)
        val state = legacy.copy(journeyState = journey, commitment = root.string("stateCommitment"))
        try { ProKernel().validateSavedState(state) } catch (error: IllegalArgumentException) { throw ProStateCodecException(error.message ?: "pro.state.invalid") }
        return state
    }

    /** Safe-boundary upgrade for a legacy save. It consumes no RNG and is idempotent by state. */
    public fun decodeAndMigrate(bytes: ByteArray): ProState {
        val root = parseRoot(bytes)
        return if (root.string("schema") == ProStateCodec.SCHEMA) ProJourneyStateCodec.migrateV1(bytes) else decode(bytes)
    }

    private fun parseRoot(bytes: ByteArray): JsonValue.Obj {
        val root = try { StrictJson.parseUtf8(bytes) as? JsonValue.Obj ?: throw ProStateCodecException("pro.state.root") } catch (error: ProStateCodecException) { throw error } catch (_: Exception) { throw ProStateCodecException("pro.state.json") }
        requireExact(root, ROOT_FIELDS, "pro.state.root")
        require(bytes.contentEquals(StrictJson.canonical(root).toByteArray(Charsets.UTF_8))) { "pro.state.noncanonical" }
        return root
    }

    private fun DataInputStream.readLengthPrefixed(): ByteArray {
        val size = readInt()
        require(size in 0..MAX_BYTES) { "pro.state.length" }
        return ByteArray(size).also(::readFully)
    }

    private fun requireExact(value: JsonValue.Obj, expected: Set<String>, field: String) {
        val missing = expected - value.entries.keys
        val unknown = value.entries.keys - expected
        require(missing.isEmpty()) { "$field.missing:${missing.sorted().joinToString(",")}" }
        require(unknown.isEmpty()) { "$field.unknown:${unknown.sorted().joinToString(",")}" }
    }

    private fun JsonValue.Obj.string(name: String): String = (entries[name] as? JsonValue.Str)?.value ?: throw ProStateCodecException("pro.state.$name")
    private fun JsonValue.Obj.integer(name: String): Int = (entries[name] as? JsonValue.Num)?.raw?.toIntOrNull() ?: throw ProStateCodecException("pro.state.$name")
}
