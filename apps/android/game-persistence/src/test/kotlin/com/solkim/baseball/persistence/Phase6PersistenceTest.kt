package com.solkim.baseball.persistence

import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.canonicalSha256
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertIs
import kotlin.test.assertTrue
import java.nio.file.Files
import java.nio.file.Path

class Phase6PersistenceTest {
    private data class Payload(val revision: ULong, val installId: String, val stage: String, val optional: String?)

    private object PayloadCodec : JsonPayloadCodec<Payload> {
        private val fields = setOf("revision", "installId", "stage", "optional")
        override fun validate(value: Payload) {
            require(value.installId.isNotBlank())
            require(value.revision >= 0UL)
            require(value.stage in setOf("opening", "pitch", "completed"))
        }
        override fun encodePayload(value: Payload): JsonValue.Obj = JsonValue.Obj(linkedMapOf<String, JsonValue>(
            "revision" to JsonValue.Str(value.revision.toString()), "installId" to JsonValue.Str(value.installId), "stage" to JsonValue.Str(value.stage),
            "optional" to if (value.optional == null) JsonValue.Null else JsonValue.Str(value.optional),
        ))
        override fun decodePayload(value: JsonValue.Obj): Payload {
            require(value.entries.keys == fields)
            fun string(name: String): String = (value[name] as JsonValue.Str).value
            fun nullableString(name: String): String? = when (val item = value[name]) {
                null, JsonValue.Null -> null
                is JsonValue.Str -> item.value
                else -> error(name)
            }
            return Payload(string("revision").toULong(), string("installId"), string("stage"), nullableString("optional"))
        }
    }

    @Test
    fun atomicRepositoryRotatesBackupsAndRecoversQuarantinedCanonical() {
        withTempDirectory { directory ->
            val repo = AtomicJsonRepository(SaveFileLayout(directory), PayloadCodec, FixedClock(1_700_000_000_000L))
            (0UL..3UL).forEach { revision -> repo.save(Payload(revision, "install-a", "opening", null), revision) }
            Files.write(directory.resolve("save.json"), byteArrayOf(0x7f))
            val loaded = repo.load()
            assertEquals(SaveLoadStatus.RECOVERED_BACKUP, loaded.status)
            assertEquals(2UL, loaded.envelope?.revision)
            assertEquals(1, loaded.quarantinedPaths.size)
            assertTrue(Files.exists(loaded.quarantinedPaths.single()))
            assertEquals(2UL, repo.load().envelope?.revision)
        }
    }

    @Test
    fun revisionIdempotencyRegressionAndConflictAreFailClosed() {
        withTempDirectory { directory ->
            val repo = AtomicJsonRepository(SaveFileLayout(directory), PayloadCodec, FixedClock(1_700_000_000_000L))
            val first = repo.save(Payload(1UL, "install-a", "opening", null), 1UL)
            assertTrue(repo.save(Payload(1UL, "install-a", "opening", null), 1UL).idempotent)
            assertFailsWith<SaveRepositoryException> { repo.save(Payload(0UL, "install-a", "opening", null), 0UL) }
            assertFailsWith<SaveRepositoryException> { repo.save(Payload(1UL, "install-a", "pitch", "different"), 1UL) }
            assertEquals(first.envelope.payloadSha256, repo.load().envelope?.payloadSha256)
        }
    }

    @Test
    fun futureAndOlderCanonicalFilesArePreservedAndNeverOverwritten() {
        withTempDirectory { directory ->
            val layout = SaveFileLayout(directory)
            val repo = AtomicJsonRepository(layout, PayloadCodec, FixedClock(1_700_000_000_000L))
            repo.save(Payload(1UL, "install-a", "opening", null), 1UL)
            val original = String(Files.readAllBytes(layout.canonical), Charsets.UTF_8)
            Files.write(layout.canonical, original.replace("\"schemaVersion\":1", "\"schemaVersion\":2").toByteArray())
            assertEquals(SaveLoadStatus.FUTURE_VERSION, repo.load().status)
            assertEquals(2, String(Files.readAllBytes(layout.canonical), Charsets.UTF_8).substringAfter("\"schemaVersion\":").substringBefore(',').toInt())
            Files.write(layout.canonical, original.replace("\"schemaVersion\":1", "\"schemaVersion\":0").toByteArray())
            assertEquals(SaveLoadStatus.MIGRATION_REQUIRED, repo.load().status)
        }
    }

    @Test
    fun everySaveFaultLeavesNoPublishedCandidateAndARecoverableRepository() {
        SaveFaultPoint.entries.filterNot { it.name.startsWith("RESET_") }.forEach { point ->
            withTempDirectory { directory ->
                var armed: SaveFaultPoint? = null
                val faults = SaveFaultInjector { candidate -> if (candidate == armed) throw IllegalStateException("fault:$candidate") }
                val repo = AtomicJsonRepository(SaveFileLayout(directory), PayloadCodec, FixedClock(1_700_000_000_000L), faults)
                (0UL..3UL).forEach { revision -> repo.save(Payload(revision, "install-a", "opening", null), revision) }
                armed = point
                assertFailsWith<SaveRepositoryException> { repo.save(Payload(4UL, "install-a", "pitch", "x"), 4UL) }
                armed = null
                val loaded = repo.load()
                assertTrue(loaded.status == SaveLoadStatus.LOADED_CANONICAL || loaded.status == SaveLoadStatus.RECOVERED_BACKUP || loaded.status == SaveLoadStatus.UNRECOVERABLE_CORRUPTION, "fault=$point status=${loaded.status}")
                assertEquals(3UL, loaded.envelope?.revision, "fault=$point must not publish revision 4")
            }
        }
    }

    @Test
    fun everyResetFaultLeavesARepositoryThatCanBeRetried() {
        SaveFaultPoint.entries.filter { it.name.startsWith("RESET_") }.forEach { point ->
            withTempDirectory { directory ->
                var armed: SaveFaultPoint? = null
                val faults = SaveFaultInjector { candidate -> if (candidate == armed) throw IllegalStateException("fault:$candidate") }
                val repo = AtomicJsonRepository(SaveFileLayout(directory), PayloadCodec, FixedClock(1_700_000_000_000L), faults)
                repo.save(Payload(1UL, "install-a", "opening", null), 1UL)
                armed = point
                assertFailsWith<SaveRepositoryException> { repo.reset() }
                armed = null
                repo.reset()
                assertEquals(SaveLoadStatus.NO_SAVE, repo.load().status, "fault=$point reset retry")
            }
        }
    }

    @Test
    fun currentEmulatorCloneAndKotlinRevisionRewriteRemainCSharpSemantic() {
        val bytes = requireNotNull(javaClass.getResourceAsStream("/legacy/save-v1-current.json")).readBytes()
        val current = CSharpSaveCompatibilityCodec.read(bytes)
        val semantic = CSharpSaveCompatibilityCodec.semantic(current)
        assertEquals(6UL, semantic.revision)
        assertEquals(6UL, semantic.aggregateRevision)
        assertEquals("718fa1083cc647d0b169ff301fdb9ad7", semantic.installId)
        assertEquals(listOf("pro", "pitchResume", "pendingPitchCompletion"), semantic.optionalNullPaths)
        val rewritten = CSharpSaveCompatibilityCodec.rewriteRevision(current, 7UL)
        val kotlinWritten = CSharpSaveCompatibilityCodec.read(rewritten)
        assertEquals(7UL, CSharpSaveCompatibilityCodec.semantic(kotlinWritten).revision)
        assertEquals(7UL, CSharpSaveCompatibilityCodec.semantic(kotlinWritten).aggregateRevision)
        assertEquals(semantic.installId, CSharpSaveCompatibilityCodec.semantic(kotlinWritten).installId)
        assertEquals(semantic.stage, CSharpSaveCompatibilityCodec.semantic(kotlinWritten).stage)
    }

    @Test
    fun checkedInKotlinWrittenFixtureIsExactlyProducedByTheKotlinWriter() {
        val current = requireNotNull(javaClass.getResourceAsStream("/legacy/save-v1-current.json")).readBytes()
        val expected = CSharpSaveCompatibilityCodec.rewriteRevision(CSharpSaveCompatibilityCodec.read(current), 7UL)
        val checkedIn = requireNotNull(javaClass.getResourceAsStream("/legacy/kotlin-written-save-v1.json")).readBytes()
        assertEquals(String(expected, Charsets.UTF_8), String(checkedIn, Charsets.UTF_8).removeSuffix("\n"))
        assertEquals(7UL, CSharpSaveCompatibilityCodec.semantic(CSharpSaveCompatibilityCodec.read(checkedIn)).revision)
    }

    @Test
    fun csharpWriterEnvelopeRevisionMayAdvanceWhileAggregateRevisionRemainsSemantic() {
        val bytes = requireNotNull(javaClass.getResourceAsStream("/legacy/csharp-written-after-kotlin-save-v1.json")).readBytes()
        val document = CSharpSaveCompatibilityCodec.read(bytes)
        val semantic = CSharpSaveCompatibilityCodec.semantic(document)
        assertEquals(8UL, semantic.revision)
        assertEquals(7UL, semantic.aggregateRevision)
        assertEquals("718fa1083cc647d0b169ff301fdb9ad7", semantic.installId)
    }

    @Test
    fun csharpUnknownEnumUnknownFieldAndTamperCasesFailClosed() {
        val bytes = requireNotNull(javaClass.getResourceAsStream("/legacy/save-v1-current.json")).readBytes()
        val current = assertIs<LegacySaveDecodeResult.Valid>(LegacySaveCodec.decode(bytes)).document
        val unknownField = current.withPayloadField("futureWireField", JsonValue.Bool(true))
        assertFailsWith<LegacySaveCompatibilityException> { CSharpSaveCompatibilityCodec.read(LegacySaveCodec.reencode(unknownField)) }
        val unknownEnum = current.withPayloadField("stage", JsonValue.Str("futureStage"))
        assertFailsWith<LegacySaveCompatibilityException> { CSharpSaveCompatibilityCodec.read(LegacySaveCodec.reencode(unknownEnum)) }
        val tampered = bytes.copyOf().also { index -> index[index.lastIndex] = if (index[index.lastIndex].toInt() == 10) 32 else 10 }
        assertTrue(LegacySaveCodec.decode(tampered) is LegacySaveDecodeResult.Invalid)
    }

    private fun withTempDirectory(block: (Path) -> Unit) {
        val directory = Files.createTempDirectory("baseball-phase6-")
        try { block(directory) } finally {
            Files.walk(directory).use { stream -> stream.sorted(Comparator.reverseOrder()).forEach { Files.deleteIfExists(it) } }
        }
    }

    private class FixedClock(private val millis: Long) : SaveClock { override fun nowUtcMillis(): Long = millis }
}
