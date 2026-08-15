package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase4Command
import com.solkim.baseball.core.highschool.HighSchoolPhase4StartRequest
import com.solkim.baseball.core.pro.ProCommand
import com.solkim.baseball.core.pro.ProStartDirectRequest
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.persistence.AtomicJsonRepository
import com.solkim.baseball.persistence.FileResetJournal
import com.solkim.baseball.persistence.KotlinSaveRepository
import com.solkim.baseball.persistence.SaveClock
import com.solkim.baseball.persistence.SaveFailureCode
import com.solkim.baseball.persistence.SaveRepositoryException
import kotlinx.coroutines.runBlocking
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertTrue
import java.nio.file.Files
import java.nio.file.Path

class Phase6GameStoreTest {
    @Test
    fun typedReducerPersistsPitchKillBoundariesAndRestarts() = runBlocking {
        withTempDirectory { directory ->
            val repository = AtomicJsonRepository<GameAggregateState>(SaveLayout(directory), GameAggregateCodec, FixedClock(1_700_000_000_000L))
            val store = KotlinGameStore.fromState(GameAggregateState.initial("install-a"), repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            startTutorial(store)
            val reserve = envelope("reserve", store.current.revision, GameCommand.ReservePitch("session-a", PitchCareerKind.TUTORIAL, TUTORIAL_CAREER_ID, "game-a", "seed-a"))
            assertEquals(3UL, store.dispatch(reserve).state.revision)
            assertTrue(store.dispatch(reserve).duplicate)
            assertFailsWith<GameCommandException> { store.dispatch(reserve.copy(command = GameCommand.AbandonPitch("session-a", "tamper"))) }
            assertFailsWith<GameCommandException> { store.dispatch(envelope("stale", 0UL, GameCommand.CommitPitch("session-a", "pitch-1", "result-1"))) }

            store.dispatch(envelope("start", store.current.revision, GameCommand.StartPitch("session-a")))
            var restarted = KotlinGameStore.open("install-a", repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            assertEquals(PitchBoundary.PLAYING, restarted.current.pitch?.boundary)
            restarted.dispatch(envelope("commit", restarted.current.revision, GameCommand.CommitPitch("session-a", "pitch-1", "result-1", "checkpoint-1")))
            restarted = KotlinGameStore.open("install-a", repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            assertEquals(PitchBoundary.COMMITTED, restarted.current.pitch?.boundary)
            restarted.dispatch(envelope("consume", restarted.current.revision, GameCommand.ConsumePitch("session-a", "pitch-1")))
            restarted = KotlinGameStore.open("install-a", repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            assertEquals(PitchBoundary.CONSUMED, restarted.current.pitch?.boundary)
            restarted.dispatch(envelope("terminal", restarted.current.revision, GameCommand.MarkPitchTerminal("session-a", "pitch-1", "terminal-1")))
            restarted = KotlinGameStore.open("install-a", repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            assertEquals(PitchBoundary.TERMINAL, restarted.current.pitch?.boundary)
            restarted.dispatch(envelope("complete", restarted.current.revision, GameCommand.CompletePitch("session-a")))
            restarted = KotlinGameStore.open("install-a", repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            assertEquals(PitchBoundary.COMPLETED, restarted.current.pitch?.boundary)
            assertEquals(0UL, restarted.current.meta.completedGameCount)
            assertEquals(8UL, repository.load().envelope?.revision)
        }
    }

    @Test
    fun suspendResumeAndAbandonAreDurableAndTerminalStatesCannotBeReused() {
        runBlocking {
        val state = GameAggregateState.initial("install-a")
        val store = KotlinGameStore.fromState(state, MemoryRepository(state), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        startTutorial(store)
        store.dispatch(envelope("reserve", store.current.revision, GameCommand.ReservePitch("session-a", PitchCareerKind.TUTORIAL, TUTORIAL_CAREER_ID, "game-a", "seed-a")))
        store.dispatch(envelope("start", store.current.revision, GameCommand.StartPitch("session-a")))
        store.dispatch(envelope("suspend", store.current.revision, GameCommand.SuspendPitch("session-a", "checkpoint-a")))
        assertEquals(PitchBoundary.SUSPENDED, store.current.pitch?.boundary)
        store.dispatch(envelope("resume", store.current.revision, GameCommand.ResumePitch("session-a")))
        store.dispatch(envelope("abandon", store.current.revision, GameCommand.AbandonPitch("session-a", "user-abandoned")))
        assertEquals(PitchBoundary.ABANDONED, store.current.pitch?.boundary)
        assertFailsWith<GameCommandException> { store.dispatch(envelope("commit", store.current.revision, GameCommand.CommitPitch("session-a", "pitch-1", "result"))) }
        }
    }

    @Test
    fun directProCommandRunsThroughTheTypedAggregateReducer() = runBlocking {
        val initial = GameAggregateState.initial("install-a")
        val store = KotlinGameStore.fromState(initial, MemoryRepository(initial), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        val command = GameCommand.Pro(ProCommand.StartDirect(ProStartDirectRequest("42", "power_prospect", "내부 QA 투수", "hs-active")))
        val result = store.dispatch(envelope("pro-start", 0UL, command))
        assertFalse(result.duplicate)
        assertEquals(GameStage.PRO, result.state.stage)
        assertEquals("hs-active", result.state.meta.activeHighSchoolCareerId)
        assertEquals(com.solkim.baseball.core.pro.ProStartMode.DIRECT, result.state.pro?.startMode)
    }

    @Test
    fun commandCodecAndNativeStateCodecAreCanonicalAndStrict() {
        runBlocking {
        val state = GameAggregateState.initial("install-a")
        val command = envelope("reserve", 0UL, GameCommand.ReservePitch("session-a", PitchCareerKind.TUTORIAL, TUTORIAL_CAREER_ID, "game-a", "seed-a"))
        assertEquals(command, GameCommandCodec.decode(GameCommandCodec.encode(command)))
        val encoded = GameAggregateCodec.encodePayload(state)
        assertEquals(state, GameAggregateCodec.decodePayload(encoded))
        val tamperedAggregate = JsonValue.Obj(linkedMapOf<String, JsonValue>().apply {
            putAll(encoded.entries)
            put("commitment", JsonValue.Str("0"))
        })
        assertFailsWith<GameSaveCodecException> { GameAggregateCodec.decodePayload(tamperedAggregate) }
        assertFailsWith<GameCommandException> {
            GameCommandCodec.decode(String(GameCommandCodec.encode(command), Charsets.UTF_8).replace("\"schemaVersion\":1", "\"schemaVersion\":2").toByteArray())
        }
        val proCommand = envelope("pro-codec", 0UL, GameCommand.Pro(ProCommand.StartDirect(ProStartDirectRequest("42", "power_prospect", "내부 QA 투수"))))
        val proTree = com.solkim.baseball.model.StrictJson.parseUtf8(GameCommandCodec.encode(proCommand)) as JsonValue.Obj
        val mismatchedRoot = JsonValue.Obj(linkedMapOf<String, JsonValue>().apply {
            putAll(proTree.entries)
            put("expectedRevision", JsonValue.Str("1"))
        })
        assertFailsWith<GameCommandException> { GameCommandCodec.decode(com.solkim.baseball.model.StrictJson.canonical(mismatchedRoot).toByteArray()) }
        val reserveTree = com.solkim.baseball.model.StrictJson.parseUtf8(GameCommandCodec.encode(command)) as JsonValue.Obj
        val mismatchedSession = JsonValue.Obj(linkedMapOf<String, JsonValue>().apply {
            putAll(reserveTree.entries)
            put("sessionId", JsonValue.Str("other-session"))
        })
        assertFailsWith<GameCommandException> { GameCommandCodec.decode(com.solkim.baseball.model.StrictJson.canonical(mismatchedSession).toByteArray()) }
        }
    }

    @Test
    fun analyticsPublishesOnlyAfterVerifiedSaveAndSaveFailurePublishesNothing() = runBlocking {
        withTempDirectory { directory ->
            val delegate = AtomicJsonRepository<GameAggregateState>(SaveLayout(directory), GameAggregateCodec, FixedClock(1_700_000_000_000L))
            val recording = RecordingRepository(delegate)
            var published = false
            val projection = AnalyticsReceiptProjection(AnalyticsReceiptSink { receipts ->
                assertTrue(recording.didSave)
                assertTrue(receipts.isNotEmpty())
                published = true
            })
            val store = KotlinGameStore.fromState(GameAggregateState.initial("install-a"), recording, NativeAuthorityMode.NATIVE_AUTHORITATIVE, analyticsProjection = projection)
            startTutorial(store)
            store.dispatch(envelope("reserve", store.current.revision, GameCommand.ReservePitch("session-a", PitchCareerKind.TUTORIAL, TUTORIAL_CAREER_ID, "game-a", "seed-a")))
            assertTrue(published)

            val failing = FailingRepository<GameAggregateState>()
            val failureStore = KotlinGameStore.fromState(store.current.copy(pitch = null).committed(), failing, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            assertFailsWith<SaveRepositoryException> {
                failureStore.dispatch(envelope("reserve-failure", failureStore.current.revision, GameCommand.ReservePitch("session-a", PitchCareerKind.TUTORIAL, TUTORIAL_CAREER_ID, "game-a", "seed-a")))
            }
            assertEquals(store.current.revision, failureStore.current.revision)
        }
    }

    @Test
    fun shadowReadOnlyModeRejectsWritesWithoutTouchingRepository() = runBlocking {
        val repository = CountingRepository<GameAggregateState>()
        val store = KotlinGameStore.fromState(GameAggregateState.initial("install-a"), repository, NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY)
        assertFailsWith<SaveRepositoryException> {
            store.dispatch(envelope("shadow-analytics", 0UL, GameCommand.RecordAnalytics("shadow-analytics", "shadow.event")))
        }.also { assertEquals(SaveFailureCode.WRITE_DISABLED, it.code) }
        assertEquals(0, repository.saveCount)
    }

    @Test
    fun resetJournalIsIrrevocableAndResumesAfterSideEffectFailure() = runBlocking {
        withTempDirectory { directory ->
            val repository = CountingRepository<GameAggregateState>()
            val journal = FileResetJournal(directory, clock = FixedClock(1_700_000_000_000L))
            var failAnalytics = true
            val identity = mutableListOf<String>()
            val sideEffects = object : ResetSideEffects {
                override fun clearAnalytics() { if (failAnalytics) throw IllegalStateException("analytics-fault") }
                override fun clearReview() = Unit
                override fun clearReminders() = Unit
                override fun clearScopedEpoch() = Unit
                override fun clearShareCache() = Unit
            }
            val coordinator = ResetCoordinator(journal, repository, InstallIdentityWriter { identity += it }, sideEffects)
            assertFailsWith<IllegalStateException> { coordinator.begin("old-install", "candidate-install") }
            assertTrue(coordinator.isWritePoisoned)
            assertEquals(listOf("candidate-install"), identity)
            val restarted = ResetCoordinator(journal, repository, InstallIdentityWriter { identity += it }, sideEffects)
            assertTrue(restarted.isWritePoisoned)
            assertFailsWith<IllegalStateException> { restarted.requireLifecycleWritesAllowed() }
            failAnalytics = false
            restarted.resume()
            assertFalse(restarted.isWritePoisoned)
            assertFalse(Files.exists(directory.resolve("reset.journal")))
            restarted.requireLifecycleWritesAllowed()
        }
    }

    private fun envelope(id: String, revision: ULong, command: GameCommand): GameCommandEnvelope = GameCommandEnvelope(
        id,
        when (command) {
            GameCommand.EnterSetup -> "session-store"
            is GameCommand.ReservePitch -> command.sessionId
            is GameCommand.StartPitch -> command.sessionId
            is GameCommand.CommitPitch -> command.sessionId
            is GameCommand.ConsumePitch -> command.sessionId
            is GameCommand.MarkPitchTerminal -> command.sessionId
            is GameCommand.CompletePitch -> command.sessionId
            is GameCommand.SuspendPitch -> command.sessionId
            is GameCommand.ResumePitch -> command.sessionId
            is GameCommand.AbandonPitch -> command.sessionId
            is GameCommand.ClearPitchPresentation -> command.sessionId
            is GameCommand.HighSchool, is GameCommand.Pro, is GameCommand.UpdateSettings, is GameCommand.RecordAnalytics -> "session-store"
        },
        revision,
        command,
    )

    private suspend fun startTutorial(store: KotlinGameStore) {
        store.dispatch(envelope(
            "high-school-start",
            store.current.revision,
            GameCommand.HighSchool(HighSchoolPhase4Command.Start(
                HighSchoolPhase4StartRequest("42", "power_prospect", "stable", "2026-W33", "2026-08-14"),
            )),
        ))
        store.dispatch(envelope(
            "begin-tutorial",
            store.current.revision,
            GameCommand.HighSchool(HighSchoolPhase4Command.BeginTutorial),
        ))
    }

    private suspend fun withTempDirectory(block: suspend (Path) -> Unit) {
        val directory = Files.createTempDirectory("baseball-phase6-app-")
        try { block(directory) } finally { Files.walk(directory).use { stream -> stream.sorted(Comparator.reverseOrder()).forEach { Files.deleteIfExists(it) } } }
    }

    private fun SaveLayout(directory: Path) = com.solkim.baseball.persistence.SaveFileLayout(directory)

    private class FixedClock(private val millis: Long) : SaveClock { override fun nowUtcMillis(): Long = millis }

    private class RecordingRepository<T>(private val delegate: KotlinSaveRepository<T>) : KotlinSaveRepository<T> {
        var didSave: Boolean = false
        override fun save(value: T, revision: ULong) = delegate.save(value, revision).also { didSave = true }
        override fun load() = delegate.load()
        override fun reset() = delegate.reset()
    }

    private class FailingRepository<T> : KotlinSaveRepository<T> {
        override fun save(value: T, revision: ULong): Nothing = throw SaveRepositoryException(SaveFailureCode.IO_FAILED, "test.save_failed")
        override fun load(): com.solkim.baseball.persistence.SaveLoadResult<T> = throw IllegalStateException("not used")
        override fun reset(): Nothing = throw IllegalStateException("not used")
    }

    private class CountingRepository<T> : KotlinSaveRepository<T> {
        var saveCount: Int = 0
        override fun save(value: T, revision: ULong): Nothing { saveCount += 1; throw SaveRepositoryException(SaveFailureCode.WRITE_DISABLED, "test.disabled") }
        override fun load(): com.solkim.baseball.persistence.SaveLoadResult<T> = throw IllegalStateException("not used")
        override fun reset() { }
    }

    private class MemoryRepository<T> private constructor(
        private var value: T,
        private var revision: ULong,
    ) : KotlinSaveRepository<T> {
        constructor(value: T) : this(value, 0UL)

        override fun save(value: T, revision: ULong): com.solkim.baseball.persistence.SaveWriteResult<T> {
            this.value = value
            this.revision = revision
            val envelope = com.solkim.baseball.persistence.SaveEnvelope(
                schema = "memory",
                schemaVersion = 1,
                revision = revision,
                writtenAtUtc = "1970-01-01T00:00:00.000Z",
                payloadSha256 = "0".repeat(64),
                payload = value,
                payloadTree = JsonValue.Obj(linkedMapOf()),
            )
            return com.solkim.baseball.persistence.SaveWriteResult(
                envelope = envelope,
                path = Path.of("memory-save.json"),
            )
        }

        override fun load(): com.solkim.baseball.persistence.SaveLoadResult<T> =
            com.solkim.baseball.persistence.SaveLoadResult(com.solkim.baseball.persistence.SaveLoadStatus.NO_SAVE)

        override fun reset() {
            revision = 0UL
        }
    }
}
