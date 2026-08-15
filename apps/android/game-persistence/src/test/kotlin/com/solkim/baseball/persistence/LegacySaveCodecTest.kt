package com.solkim.baseball.persistence

import com.solkim.baseball.model.JsonValue
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue

class LegacySaveCodecTest {
    private val currentSave: ByteArray
        get() = requireNotNull(javaClass.getResourceAsStream("/legacy/save-v1-current.json"))
            .readBytes()

    private val backupSave: ByteArray
        get() = requireNotNull(javaClass.getResourceAsStream("/legacy/save-v1-backup-1.json"))
            .readBytes()

    @Test
    fun realCurrentEmulatorFixtureDecodesAndReencodesSemantically() {
        val original = assertIs<LegacySaveDecodeResult.Valid>(LegacySaveCodec.decode(currentSave)).document
        val encoded = LegacySaveCodec.reencode(original)
        val restored = assertIs<LegacySaveDecodeResult.Valid>(LegacySaveCodec.decode(encoded)).document
        assertEquals(original.revision, restored.revision)
        assertEquals(original.payloadSha256, restored.payloadSha256)
        assertEquals(original.payload, restored.payload)
    }

    @Test
    fun realBackupEmulatorFixtureDecodesAndReencodesSemantically() {
        val original = assertIs<LegacySaveDecodeResult.Valid>(LegacySaveCodec.decode(backupSave)).document
        val encoded = LegacySaveCodec.reencode(original)
        val restored = assertIs<LegacySaveDecodeResult.Valid>(LegacySaveCodec.decode(encoded)).document
        assertEquals(original.revision, restored.revision)
        assertEquals(original.payloadSha256, restored.payloadSha256)
        assertEquals(original.payload, restored.payload)
    }

    @Test
    fun additiveEnvelopeAndPayloadFieldsSurviveReencode() {
        val original = assertIs<LegacySaveDecodeResult.Valid>(LegacySaveCodec.decode(currentSave)).document
        val additive = original
            .withTopLevelField("futureEnvelopeField", JsonValue.Str("kept"))
            .withPayloadField("futurePayloadField", JsonValue.Obj(linkedMapOf("enabled" to JsonValue.Bool(true))))
        val encoded = LegacySaveCodec.reencode(additive)
        val restored = LegacySaveCodec.requireValid(encoded)
        assertEquals("kept", (restored.root["futureEnvelopeField"] as JsonValue.Str).value)
        assertTrue(restored.payload.entries.containsKey("futurePayloadField"))
        assertEquals(additive.payloadSha256, restored.payloadSha256)
    }

    @Test
    fun corruptDuplicateTrailingChecksumAndSemanticInputsFailClosed() {
        val original = String(currentSave, Charsets.UTF_8)
        assertTrue(LegacySaveCodec.decode("$original\nfalse".toByteArray()) is LegacySaveDecodeResult.Invalid)
        val duplicate = original.replaceFirst(
            "\"schema\": \"android-unity-save-v1\",",
            "\"schema\": \"android-unity-save-v1\",\n  \"schema\": \"android-unity-save-v1\",",
        )
        assertTrue(LegacySaveCodec.decode(duplicate.toByteArray()) is LegacySaveDecodeResult.Invalid)
        val checksum = original.replaceFirst("4de30c", "0de30c")
        assertTrue(LegacySaveCodec.decode(checksum.toByteArray()) is LegacySaveDecodeResult.Invalid)
        val invalidPayload = original.replaceFirst("\"aggregateVersion\": 4", "\"aggregateVersion\": 99")
        assertTrue(LegacySaveCodec.decode(invalidPayload.toByteArray()) is LegacySaveDecodeResult.Invalid)
    }

    @Test
    fun futureAndOlderSchemasArePreservedButCannotBeWrittenAsCurrent() {
        val original = String(currentSave, Charsets.UTF_8)
        val future = original.replaceFirst("\"schemaVersion\": 1", "\"schemaVersion\": 2")
        val futureResult = assertIs<LegacySaveDecodeResult.FutureSchema>(LegacySaveCodec.decode(future.toByteArray()))
        assertEquals(2, futureResult.schemaVersion)
        val older = original.replaceFirst("\"schemaVersion\": 1", "\"schemaVersion\": 0")
        assertIs<LegacySaveDecodeResult.MigrationRequired>(LegacySaveCodec.decode(older.toByteArray()))
    }
}
