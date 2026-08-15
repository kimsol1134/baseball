package com.solkim.baseball.application

import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.persistence.AtomicJsonRepository
import com.solkim.baseball.persistence.CSharpSaveCompatibilityCodec
import com.solkim.baseball.persistence.JsonPayloadCodec
import com.solkim.baseball.persistence.LegacySaveCodec
import com.solkim.baseball.persistence.SaveFileLayout
import kotlinx.coroutines.runBlocking
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import java.nio.file.Files
import java.nio.file.Path

class Phase10CSharpLegacyGameStoreRepositoryTest {
    @Test
    fun nativeSettingsCommandIsAtomicAndRoundTripsTheCSharpWire() = runBlocking {
        withTempDirectory { directory ->
            val installId = "0123456789abcdef0123456789abcdef"
            val seed = AtomicJsonRepository(
                SaveFileLayout(directory),
                object : JsonPayloadCodec<JsonValue.Obj> {
                    override fun encodePayload(value: JsonValue.Obj): JsonValue.Obj = value
                    override fun decodePayload(value: JsonValue.Obj): JsonValue.Obj = value
                    override fun validate(value: JsonValue.Obj) = CSharpSaveCompatibilityCodec.validatePayload(value)
                },
                preserveUnknownEnvelopeFields = true,
            )
            seed.save(legacyPayload(installId, 6UL), 6UL)
            val seeded = LegacySaveCodec.requireValid(Files.readAllBytes(directory.resolve("save.json")))
                .withTopLevelField("futureRootExtension", JsonValue.Str("must-survive"))
            Files.write(directory.resolve("save.json"), LegacySaveCodec.reencode(seeded))

            val repository = CSharpLegacyGameStoreRepository(directory, installId)
            val store = KotlinGameStore.open(installId, repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            val command = GameCommandEnvelope(
                commandId = "phase10-settings-command",
                sessionId = "phase10-session",
                expectedRevision = 6UL,
                command = GameCommand.UpdateSettings(GameSettingsState(
                    autoReleaseEnabled = true,
                    soundEnabled = true,
                    musicEnabled = false,
                    hapticsEnabled = true,
                    notificationsEnabled = true,
                    highContrastEnabled = true,
                    reducedMotionEnabled = false,
                )),
            )
            val result = store.dispatch(command)
            assertEquals(7UL, result.state.revision)
            assertEquals(GameStage.HIGH_SCHOOL, result.state.stage)
            assertTrue(Files.isRegularFile(directory.resolve("save.bak.1")))

            val document = CSharpSaveCompatibilityCodec.read(Files.readAllBytes(directory.resolve("save.json")))
            val semantic = CSharpSaveCompatibilityCodec.semantic(document)
            assertEquals(7UL, semantic.revision)
            assertEquals(7UL, semantic.aggregateRevision)
            assertEquals(listOf("pro", "pitchResume", "pendingPitchCompletion"), semantic.optionalNullPaths)
            assertEquals(1, semantic.commandReceiptCount)
            assertEquals(0, semantic.analyticsReceiptCount)
            assertTrue(document.root.entries.containsKey("futureRootExtension"))

            val mismatched = CSharpLegacyGameStoreRepository(directory, "fedcba9876543210fedcba9876543210")
            var mismatchRejected = false
            try {
                mismatched.load()
            } catch (_: IllegalStateException) {
                mismatchRejected = true
            }
            assertTrue(mismatchRejected)
        }
    }

    private fun legacyPayload(installId: String, revision: ULong): JsonValue.Obj = JsonValue.Obj(linkedMapOf(
        "aggregateVersion" to JsonValue.Num("4"),
        "revision" to JsonValue.Num(revision.toString()),
        "installId" to JsonValue.Str(installId),
        "stage" to JsonValue.Str("highSchool"),
        "highSchool" to JsonValue.Obj(linkedMapOf("coreStateJson" to JsonValue.Str("{\"commitment\":\"phase10\"}"))),
        "pro" to JsonValue.Null,
        "meta" to JsonValue.Obj(linkedMapOf("completedGameCount" to JsonValue.Num("2"))),
        "pitchResume" to JsonValue.Null,
        "pendingPitchCompletion" to JsonValue.Null,
        "settings" to JsonValue.Obj(linkedMapOf(
            "schemaVersion" to JsonValue.Num("1"),
            "autoReleaseEnabled" to JsonValue.Bool(false),
            "soundEnabled" to JsonValue.Bool(true),
            "musicEnabled" to JsonValue.Bool(true),
            "hapticsEnabled" to JsonValue.Bool(true),
            "notificationsEnabled" to JsonValue.Bool(false),
            "highContrastEnabled" to JsonValue.Bool(false),
            "reducedMotionEnabled" to JsonValue.Bool(false),
        )),
        "analyticsReceipts" to JsonValue.Obj(linkedMapOf(
            "schemaVersion" to JsonValue.Num("1"),
            "records" to JsonValue.Arr(emptyList()),
        )),
        "commandReceipts" to JsonValue.Arr(emptyList()),
        "deleted" to JsonValue.Bool(false),
    ))

    private suspend fun withTempDirectory(block: suspend (Path) -> Unit) {
        val directory = Files.createTempDirectory("baseball-phase10-legacy-")
        try {
            block(directory)
        } finally {
            Files.walk(directory).use { stream ->
                stream.sorted(Comparator.reverseOrder()).forEach { Files.deleteIfExists(it) }
            }
        }
    }
}
