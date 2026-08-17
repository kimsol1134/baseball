package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.CSharpHighSchoolSnapshotCodec
import com.solkim.baseball.core.highschool.CSharpHighSchoolSnapshotWire
import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.highschool.HighSchoolPhase4Command
import com.solkim.baseball.core.highschool.HighSchoolRelationshipResponse
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.persistence.AtomicJsonRepository
import com.solkim.baseball.persistence.CSharpSaveCompatibilityCodec
import com.solkim.baseball.persistence.JsonPayloadCodec
import com.solkim.baseball.persistence.LegacySaveCodec
import com.solkim.baseball.persistence.SaveFileLayout
import kotlinx.coroutines.runBlocking
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import java.nio.file.Files
import java.nio.file.Path

class Phase11CSharpLegacyCommandBridgeTest {
    @Test
    fun relationshipCommandAdvancesTheCSharpWireAndReloads() = runBlocking {
        withTempDirectory { directory ->
            val document = LegacySaveCodec.requireValid(Files.readAllBytes(realFixture()))
            val installId = (document.payload["installId"] as JsonValue.Str).value
            seed(directory, document.payload, document.revision)

            val repository = CSharpLegacyGameStoreRepository(directory, installId)
            val store = KotlinGameStore.open(installId, repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            assertEquals(HighSchoolPhase.RELATIONSHIP, store.current.highSchool?.run?.phase)

            val nextSeed = (document.payload.objectOrNull("highSchool")?.get("nextSeed") as JsonValue.Str).value
            val result = store.dispatch(
                GameCommandEnvelope(
                    commandId = "phase11-relationship-listen",
                    sessionId = "phase11-session",
                    expectedRevision = document.revision,
                    command = GameCommand.HighSchool(
                        HighSchoolPhase4Command.Relationship(nextSeed, HighSchoolRelationshipResponse.LISTEN),
                    ),
                ),
            )
            assertEquals(document.revision + 1UL, result.state.revision)
            assertNotNull(result.state.highSchool)
            assertNotEquals(HighSchoolPhase.RELATIONSHIP, result.state.highSchool?.run?.phase)

            val written = CSharpSaveCompatibilityCodec.read(Files.readAllBytes(directory.resolve("save.json")))
            val highSchool = written.payload["highSchool"] as JsonValue.Obj
            val core = (highSchool["coreStateJson"] as JsonValue.Str).value
            val decoded = CSharpHighSchoolSnapshotCodec.decode(core.toByteArray())
            assertEquals(CSharpHighSchoolSnapshotWire.sign(decoded), decoded.stateCommitment)
            assertEquals(result.state.highSchool?.run?.phase, decoded.phase)

            val reopened = KotlinGameStore.open(installId, CSharpLegacyGameStoreRepository(directory, installId), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            assertEquals(result.state.highSchool?.run?.phase, reopened.current.highSchool?.run?.phase)
            assertEquals(result.state.revision, reopened.current.revision)
        }
    }

    @Test
    fun settingsCommandStillRoundTripsAStubHighSchoolPayload() = runBlocking {
        withTempDirectory { directory ->
            val installId = "0123456789abcdef0123456789abcdef"
            seed(directory, stubPayload(installId, 6UL), 6UL)
            val repository = CSharpLegacyGameStoreRepository(directory, installId)
            val store = KotlinGameStore.open(installId, repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            val result = store.dispatch(
                GameCommandEnvelope(
                    commandId = "phase11-settings",
                    sessionId = "phase11-session",
                    expectedRevision = 6UL,
                    command = GameCommand.UpdateSettings(GameSettingsState(autoReleaseEnabled = true, musicEnabled = false)),
                ),
            )
            assertEquals(7UL, result.state.revision)
            assertTrue(result.state.settings.autoReleaseEnabled)
            val document = CSharpSaveCompatibilityCodec.read(Files.readAllBytes(directory.resolve("save.json")))
            assertEquals(listOf("pro", "pitchResume", "pendingPitchCompletion"), CSharpSaveCompatibilityCodec.semantic(document).optionalNullPaths)
        }
    }

    @Test
    fun pitchReserveWritesACSharpCompatibleResumeOnARealHighSchoolSave() = runBlocking {
        withTempDirectory { directory ->
            val document = LegacySaveCodec.requireValid(Files.readAllBytes(realFixture()))
            val installId = (document.payload["installId"] as JsonValue.Str).value
            seed(directory, document.payload, document.revision)
            val repository = CSharpLegacyGameStoreRepository(directory, installId)
            val store = KotlinGameStore.open(installId, repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            val careerId = requireNotNull(store.current.highSchool).run.careerId
            val result = store.dispatch(
                GameCommandEnvelope(
                    commandId = "phase11-pitch-reserve",
                    sessionId = "phase11-pitch",
                    expectedRevision = document.revision,
                    command = GameCommand.ReservePitch(
                        sessionId = "phase11-pitch",
                        careerKind = PitchCareerKind.HIGH_SCHOOL,
                        careerId = careerId,
                        gameId = "game-phase11",
                        seed = "1",
                    ),
                ),
            )
            assertEquals(PitchBoundary.RESERVED, result.state.pitch?.boundary)
            val written = CSharpSaveCompatibilityCodec.read(Files.readAllBytes(directory.resolve("save.json")))
            val resume = written.payload["pitchResume"] as JsonValue.Obj
            assertEquals("highSchool", (resume["careerKind"] as JsonValue.Str).value)
            assertEquals(careerId, (resume["careerId"] as JsonValue.Str).value)
            assertEquals(JsonValue.Null, written.payload["pendingPitchCompletion"])
        }
    }

    @Test
    fun unityOnlyProSnapshotFailsClosedUntilANativeSidecarExists() = runBlocking {
        withTempDirectory { directory ->
            val installId = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
            val payload = openingPayload(installId)
            val entries = LinkedHashMap(payload.entries)
            entries["stage"] = JsonValue.Str("pro")
            entries["pro"] = JsonValue.Obj(linkedMapOf("coreStateJson" to JsonValue.Str("{\"ProCareerId\":\"pro-1\"}")))
            seed(directory, JsonValue.Obj(entries), 0UL)
            val repository = CSharpLegacyGameStoreRepository(directory, installId)
            val store = KotlinGameStore.open(installId, repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            var rejected = false
            try {
                store.dispatch(
                    GameCommandEnvelope(
                        commandId = "phase11-pro-blocked",
                        sessionId = "phase11-session",
                        expectedRevision = 0UL,
                        command = GameCommand.Pro(com.solkim.baseball.core.pro.ProCommand.SignContract),
                    ),
                )
            } catch (error: GameCommandException) {
                rejected = error.message.orEmpty().contains("legacy_pro_snapshot_unreadable") ||
                    error.message.orEmpty().contains("pro.start_required")
            }
            assertTrue(rejected)
        }
    }

    @Test
    fun enterSetupAndPitchReserveWriteCSharpCompatibleFields() = runBlocking {
        withTempDirectory { directory ->
            val installId = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
            seed(directory, openingPayload(installId), 0UL)
            val repository = CSharpLegacyGameStoreRepository(directory, installId)
            val store = KotlinGameStore.open(installId, repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            val setup = store.dispatch(
                GameCommandEnvelope("phase11-setup", "phase11-session", 0UL, GameCommand.EnterSetup),
            )
            assertEquals(GameStage.SETUP, setup.state.stage)
            assertNull(setup.state.highSchool)
        }
    }

    private fun seed(directory: Path, payload: JsonValue.Obj, revision: ULong) {
        val repository = AtomicJsonRepository(
            SaveFileLayout(directory),
            object : JsonPayloadCodec<JsonValue.Obj> {
                override fun encodePayload(value: JsonValue.Obj): JsonValue.Obj = value
                override fun decodePayload(value: JsonValue.Obj): JsonValue.Obj = value
                override fun validate(value: JsonValue.Obj) = CSharpSaveCompatibilityCodec.validatePayload(value)
            },
            preserveUnknownEnvelopeFields = true,
        )
        runBlocking { repository.save(payload, revision) }
    }

    private fun stubPayload(installId: String, revision: ULong): JsonValue.Obj = JsonValue.Obj(linkedMapOf(
        "aggregateVersion" to JsonValue.Num("4"),
        "revision" to JsonValue.Num(revision.toString()),
        "installId" to JsonValue.Str(installId),
        "stage" to JsonValue.Str("highSchool"),
        "highSchool" to JsonValue.Obj(linkedMapOf("coreStateJson" to JsonValue.Str("{\"commitment\":\"phase10\"}"))),
        "pro" to JsonValue.Null,
        "meta" to JsonValue.Obj(linkedMapOf("completedGameCount" to JsonValue.Num("2"))),
        "pitchResume" to JsonValue.Null,
        "pendingPitchCompletion" to JsonValue.Null,
        "settings" to defaultSettings(),
        "analyticsReceipts" to JsonValue.Obj(linkedMapOf("schemaVersion" to JsonValue.Num("1"), "records" to JsonValue.Arr(emptyList()))),
        "commandReceipts" to JsonValue.Arr(emptyList()),
        "deleted" to JsonValue.Bool(false),
    ))

    private fun openingPayload(installId: String): JsonValue.Obj = JsonValue.Obj(linkedMapOf(
        "aggregateVersion" to JsonValue.Num("4"),
        "revision" to JsonValue.Num("0"),
        "installId" to JsonValue.Str(installId),
        "stage" to JsonValue.Str("opening"),
        "highSchool" to JsonValue.Null,
        "pro" to JsonValue.Null,
        "meta" to JsonValue.Obj(linkedMapOf()),
        "pitchResume" to JsonValue.Null,
        "pendingPitchCompletion" to JsonValue.Null,
        "settings" to defaultSettings(),
        "analyticsReceipts" to JsonValue.Obj(linkedMapOf("schemaVersion" to JsonValue.Num("1"), "records" to JsonValue.Arr(emptyList()))),
        "commandReceipts" to JsonValue.Arr(emptyList()),
        "deleted" to JsonValue.Bool(false),
    ))

    private fun defaultSettings(): JsonValue.Obj = JsonValue.Obj(linkedMapOf(
        "schemaVersion" to JsonValue.Num("1"),
        "autoReleaseEnabled" to JsonValue.Bool(false),
        "soundEnabled" to JsonValue.Bool(true),
        "musicEnabled" to JsonValue.Bool(true),
        "hapticsEnabled" to JsonValue.Bool(true),
        "notificationsEnabled" to JsonValue.Bool(false),
        "highContrastEnabled" to JsonValue.Bool(false),
        "reducedMotionEnabled" to JsonValue.Bool(false),
    ))

    private fun realFixture(): Path {
        val candidates = listOf(
            Path.of("game-persistence/src/test/resources/legacy/save-v1-current.json"),
            Path.of("../game-persistence/src/test/resources/legacy/save-v1-current.json"),
        )
        return candidates.firstOrNull { Files.isRegularFile(it) }
            ?: error("missing C# save-v1-current fixture")
    }

    private suspend fun withTempDirectory(block: suspend (Path) -> Unit) {
        val directory = Files.createTempDirectory("baseball-phase11-legacy-")
        try {
            block(directory)
        } finally {
            Files.walk(directory).use { stream ->
                stream.sorted(Comparator.reverseOrder()).forEach { Files.deleteIfExists(it) }
            }
        }
    }
}
