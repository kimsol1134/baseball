package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.highschool.HighSchoolPhase4Command
import com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel
import com.solkim.baseball.core.highschool.HighSchoolPhase4StartRequest
import com.solkim.baseball.core.highschool.HighSchoolKernel
import com.solkim.baseball.core.highschool.HighSchoolSchoolId
import com.solkim.baseball.core.highschool.HighSchoolTutorialState
import com.solkim.baseball.core.pro.ProCommand
import com.solkim.baseball.core.pro.ProStartDirectRequest
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.canonicalSha256
import com.solkim.baseball.persistence.AtomicJsonRepository
import com.solkim.baseball.persistence.KotlinSaveRepository
import com.solkim.baseball.persistence.SaveClock
import com.solkim.baseball.persistence.SaveEnvelope
import com.solkim.baseball.persistence.SaveFileLayout
import com.solkim.baseball.persistence.SaveLoadResult
import com.solkim.baseball.persistence.SaveLoadStatus
import com.solkim.baseball.persistence.SaveWriteResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import java.nio.file.Path
import java.util.Base64
import java.util.concurrent.atomic.AtomicInteger
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class Phase6ContractAuditTest {
    @Test
    fun storeUsesFlowContractMutexAndIOBoundary() {
        runBlocking {
            val initial = GameAggregateState.initial("install-flow")
            val repository = SerializedRepository(initial)
            val store: GameStore = KotlinGameStore.fromState(
                initial,
                authorityMode = NativeAuthorityMode.NATIVE_AUTHORITATIVE,
                ioRepository = repository,
            )
            assertEquals(initial, store.state.value)
            assertFalse(store.busy.value)

            val commands = listOf(
                envelope("flow-a", 0UL, GameCommand.RecordAnalytics("flow-a-receipt", "flow.a")),
                envelope("flow-b", 0UL, GameCommand.RecordAnalytics("flow-b-receipt", "flow.b")),
            )
            val results = commands.map { command ->
                async(Dispatchers.Default) {
                    runCatching { store.dispatch(command) }
                }
            }.awaitAll()
            assertEquals(1, results.count { it.isSuccess })
            assertEquals(1, results.count { it.isFailure })
            assertEquals(1, repository.maximumConcurrentSaves)
            assertEquals(1UL, store.state.value.revision)
            assertFalse(store.busy.value)
        }
    }

    @Test
    fun analyticsBaselinePreventsHistoricReplayAfterRestart() {
        runBlocking {
            withTempDirectory { directory ->
                val repository = AtomicJsonRepository<GameAggregateState>(
                    SaveFileLayout(directory),
                    GameAggregateCodec,
                    FixedClock(1_700_000_000_000L),
                )
                val bootstrap = KotlinGameStore.fromState(
                    GameAggregateState.initial("install-analytics"),
                    repository,
                    NativeAuthorityMode.NATIVE_AUTHORITATIVE,
                )
                startTutorial(bootstrap)
                val firstPublished = mutableListOf<String>()
                val firstProjection = AnalyticsReceiptProjection(AnalyticsReceiptSink { receipts -> firstPublished += receipts.map { it.receiptId } })
                val first = KotlinGameStore.fromState(
                    bootstrap.current,
                    repository,
                    NativeAuthorityMode.NATIVE_AUTHORITATIVE,
                    analyticsProjection = firstProjection,
                )
                first.dispatch(envelope("reserve", first.current.revision, tutorialReserve()))
                val historic = first.current.analytics.receipts.last().receiptId

                val afterRestart = mutableListOf<String>()
                val restartedProjection = AnalyticsReceiptProjection(AnalyticsReceiptSink { receipts -> afterRestart += receipts.map { it.receiptId } })
                val restarted = KotlinGameStore.open(
                    "install-analytics",
                    repository,
                    NativeAuthorityMode.NATIVE_AUTHORITATIVE,
                    restartedProjection,
                )
                restarted.dispatch(envelope("start", restarted.current.revision, GameCommand.StartPitch("session-analytics")))

                assertEquals(listOf("command:start"), afterRestart)
                assertTrue(historic !in afterRestart)
                assertEquals(listOf("command:reserve"), firstPublished)
            }
        }
    }

    @Test
    fun reconcilePersistedRevisionUpdatesTheFlowOnlyForAnExternalHigherRevision() {
        runBlocking {
            val initial = GameAggregateState.initial("install-reconcile")
            val repository = SerializedRepository(initial)
            val writer = KotlinGameStore.fromState(
                initial,
                authorityMode = NativeAuthorityMode.NATIVE_AUTHORITATIVE,
                ioRepository = repository,
            )
            writer.dispatch(envelope("external", 0UL, GameCommand.RecordAnalytics("external-receipt", "external.event")))

            val reader = KotlinGameStore.fromState(
                initial,
                authorityMode = NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY,
                ioRepository = repository,
            )
            val reconciled = reader.reconcilePersistedRevision()
            assertTrue(reconciled.reconciled)
            assertEquals(0UL, reconciled.previousRevision)
            assertEquals(1UL, reconciled.persistedRevision)
            assertEquals(1UL, reader.state.value.revision)

            val unchanged = reader.reconcilePersistedRevision()
            assertFalse(unchanged.reconciled)
            assertEquals(1UL, unchanged.previousRevision)
            assertEquals(1UL, unchanged.persistedRevision)
        }
    }

    @Test
    fun analyticsFailureDoesNotFailCommittedDispatchAndRemainsRetryable() {
        runBlocking {
            val initial = GameAggregateState.initial("install-analytics-failure")
            var fail = true
            val published = mutableListOf<List<String>>()
            val projection = AnalyticsReceiptProjection(AnalyticsReceiptSink { receipts ->
                if (fail) throw IllegalStateException("sdk-down")
                published += receipts.map { it.receiptId }
            })
            val repository = SerializedRepository(initial)
            val bootstrap = KotlinGameStore.fromState(
                initial,
                authorityMode = NativeAuthorityMode.NATIVE_AUTHORITATIVE,
                ioRepository = repository,
            )
            startTutorial(bootstrap)
            val store = KotlinGameStore.fromState(
                bootstrap.current,
                authorityMode = NativeAuthorityMode.NATIVE_AUTHORITATIVE,
                analyticsProjection = projection,
                ioRepository = repository,
            )

            val first = store.dispatch(envelope("reserve", store.current.revision, tutorialReserve("session-analytics-failure")))
            assertEquals(3UL, first.state.revision)
            assertEquals(3UL, store.state.value.revision)
            assertEquals(1, projection.pending(store.state.value).size)

            fail = false
            store.dispatch(envelope("start", store.current.revision, GameCommand.StartPitch("session-analytics-failure")))
            assertTrue(published.flatten().contains("command:reserve"))
            assertTrue(published.flatten().contains("command:start"))
            assertTrue(projection.pending(store.state.value).isEmpty())
        }
    }

    @Test
    fun explicitAnalyticsRetryWorksWithoutASecondDurableCommand() {
        runBlocking {
            val initial = GameAggregateState.initial("install-analytics-retry")
            var fail = true
            var attempts = 0
            val projection = AnalyticsReceiptProjection(AnalyticsReceiptSink {
                attempts += 1
                if (fail) throw IllegalStateException("observer-down")
            })
            val repository = SerializedRepository(initial)
            val bootstrap = KotlinGameStore.fromState(
                initial,
                authorityMode = NativeAuthorityMode.NATIVE_AUTHORITATIVE,
                ioRepository = repository,
            )
            startTutorial(bootstrap)
            val store = KotlinGameStore.fromState(
                bootstrap.current,
                authorityMode = NativeAuthorityMode.NATIVE_AUTHORITATIVE,
                analyticsProjection = projection,
                ioRepository = repository,
            )
            store.dispatch(envelope("reserve", store.current.revision, tutorialReserve()))
            assertEquals(1, projection.pending(store.state.value).size)
            fail = false
            projection.retryPending(store.state.value)
            assertEquals(2, attempts)
            assertTrue(projection.pending(store.state.value).isEmpty())
        }
    }

    @Test
    fun pitchCareerKindIsStrictAndAggregateCareerIdentityIsValidated() {
        runBlocking {
            val initial = GameAggregateState.initial("install-pitch-validation")
            val store = KotlinGameStore.fromState(
                initial,
                authorityMode = NativeAuthorityMode.NATIVE_AUTHORITATIVE,
                ioRepository = SerializedRepository(initial),
            )
            assertFailsWith<GameCommandException> {
                store.dispatch(envelope("wrong-career", 0UL, GameCommand.ReservePitch("session", PitchCareerKind.HIGH_SCHOOL, "missing-career", "game", "seed")))
            }

            val valid = envelope("daily-wire", 0UL, tutorialReserve())
            val root = com.solkim.baseball.model.StrictJson.parseUtf8(GameCommandCodec.encode(valid)) as JsonValue.Obj
            val dailyPayload = "g6:" + listOf("session", "daily", "tutorial", "game", "seed", "false")
                .joinToString(".") { Base64.getUrlEncoder().withoutPadding().encodeToString(it.toByteArray()) }
            val dailyRoot = JsonValue.Obj(linkedMapOf<String, JsonValue>().apply {
                putAll(root.entries)
                put("payload", JsonValue.Str(dailyPayload))
            })
            assertFailsWith<GameCommandException> {
                GameCommandCodec.decode(com.solkim.baseball.model.StrictJson.canonical(dailyRoot).toByteArray())
            }
        }
    }

    @Test
    fun tutorialPitchRequiresTheOwningHighSchoolPrologueLifecycleAtEveryBoundary() {
        runBlocking {
            val opening = GameAggregateState.initial("install-tutorial-opening")
            val openingStore = KotlinGameStore.fromState(
                opening,
                authorityMode = NativeAuthorityMode.NATIVE_AUTHORITATIVE,
                ioRepository = SerializedRepository(opening),
            )
            assertFailsWith<GameCommandException> {
                openingStore.dispatch(envelope("opening-reserve", opening.revision, tutorialReserve("opening-session")))
            }

            val highSchoolOnly = GameAggregateState.initial("install-tutorial-hs-only")
            val highSchoolStore = KotlinGameStore.fromState(
                highSchoolOnly,
                authorityMode = NativeAuthorityMode.NATIVE_AUTHORITATIVE,
                ioRepository = SerializedRepository(highSchoolOnly),
            )
            highSchoolStore.dispatch(envelope(
                "hs-start",
                0UL,
                GameCommand.HighSchool(HighSchoolPhase4Command.Start(
                    HighSchoolPhase4StartRequest("42", "power_prospect", "stable", "2026-W33", "2026-08-14"),
                )),
            ))
            assertFailsWith<GameCommandException> {
                highSchoolStore.dispatch(envelope("not-started", highSchoolStore.current.revision, tutorialReserve("not-started-session")))
            }

            val active = GameAggregateState.initial("install-tutorial-active")
            val activeStore = KotlinGameStore.fromState(
                active,
                authorityMode = NativeAuthorityMode.NATIVE_AUTHORITATIVE,
                ioRepository = SerializedRepository(active),
            )
            startTutorial(activeStore)
            assertFailsWith<GameCommandException> {
                activeStore.dispatch(envelope(
                    "challenge-isolation",
                    activeStore.current.revision,
                    tutorialReserve("challenge-session").copy(challengeRun = true),
                ))
            }
            activeStore.dispatch(envelope("valid-reserve", activeStore.current.revision, tutorialReserve("valid-session")))
            val reserved = activeStore.current
            val activeHighSchool = requireNotNull(reserved.highSchool)
            val kernel = HighSchoolPhase4Kernel()

            val completedTutorial = kernel.commitShadowState(
                activeHighSchool.copy(tutorial = HighSchoolTutorialState(started = true, completed = true)),
            )
            assertFailsWith<IllegalArgumentException> {
                reserved.copy(highSchool = completedTutorial).committed().validate()
            }

            val wrongPhase = kernel.commitShadowState(
                activeHighSchool.copy(
                    run = HighSchoolKernel().resignShadowState(
                        activeHighSchool.run.copy(phase = HighSchoolPhase.SCHOOL_SELECTION),
                    ),
                ),
            )
            assertFailsWith<IllegalArgumentException> {
                reserved.copy(highSchool = wrongPhase).committed().validate()
            }
            assertFailsWith<IllegalArgumentException> {
                reserved.copy(stage = GameStage.OPENING).committed().validate()
            }
            assertFailsWith<IllegalArgumentException> {
                reserved.copy(meta = reserved.meta.copy(activeHighSchoolCareerId = "wrong-active-career")).committed().validate()
            }

            val terminalInitial = GameAggregateState.initial("install-tutorial-terminal")
            val terminalStore = KotlinGameStore.fromState(
                terminalInitial,
                authorityMode = NativeAuthorityMode.NATIVE_AUTHORITATIVE,
                ioRepository = SerializedRepository(terminalInitial),
            )
            startTutorial(terminalStore)
            completePitch(terminalStore, "terminal-session", tutorialReserve("terminal-session"))
            val terminalRetained = terminalStore.current
            assertEquals(PitchBoundary.COMPLETED, terminalRetained.pitch?.boundary)
            terminalRetained.copy(highSchool = completedTutorial).committed().validate()
        }
    }

    @Test
    fun completedTutorialPitchDoesNotBlockTutorialCompletionOrSchoolProgression() {
        runBlocking {
            val initial = GameAggregateState.initial("install-tutorial-progression")
            val store = KotlinGameStore.fromState(
                initial,
                authorityMode = NativeAuthorityMode.NATIVE_AUTHORITATIVE,
                ioRepository = SerializedRepository(initial),
            )
            startTutorial(store)
            completePitch(store, "tutorial-progression-session", tutorialReserve("tutorial-progression-session"))
            assertEquals(PitchBoundary.COMPLETED, store.current.pitch?.boundary)
            assertEquals(0UL, store.current.meta.completedGameCount)

            val completedTutorial = store.dispatch(envelope(
                "complete-tutorial",
                store.current.revision,
                GameCommand.HighSchool(HighSchoolPhase4Command.CompleteTutorial("43")),
            )).state
            assertEquals(HighSchoolPhase.SCHOOL_SELECTION, requireNotNull(completedTutorial.highSchool).run.phase)
            assertTrue(requireNotNull(completedTutorial.highSchool).tutorial.completed)
            assertEquals(PitchBoundary.COMPLETED, completedTutorial.pitch?.boundary)
            assertEquals(0UL, completedTutorial.meta.completedGameCount)

            val selectedSchool = store.dispatch(envelope(
                "choose-school",
                store.current.revision,
                GameCommand.HighSchool(HighSchoolPhase4Command.ChooseSchool(
                    "44",
                    HighSchoolSchoolId.HAEDONG_POWER,
                )),
            )).state
            assertEquals(HighSchoolPhase.TRAINING, requireNotNull(selectedSchool.highSchool).run.phase)
            assertEquals(PitchBoundary.COMPLETED, selectedSchool.pitch?.boundary)
            assertEquals(0UL, selectedSchool.meta.completedGameCount)

            val abandonedInitial = GameAggregateState.initial("install-tutorial-abandoned-progression")
            val abandonedStore = KotlinGameStore.fromState(
                abandonedInitial,
                authorityMode = NativeAuthorityMode.NATIVE_AUTHORITATIVE,
                ioRepository = SerializedRepository(abandonedInitial),
            )
            startTutorial(abandonedStore)
            abandonedStore.dispatch(envelope(
                "abandoned-reserve",
                abandonedStore.current.revision,
                tutorialReserve("abandoned-session"),
            ))
            abandonedStore.dispatch(envelope(
                "abandoned-start",
                abandonedStore.current.revision,
                GameCommand.StartPitch("abandoned-session"),
            ))
            abandonedStore.dispatch(envelope(
                "abandoned-abandon",
                abandonedStore.current.revision,
                GameCommand.AbandonPitch("abandoned-session", "tutorial-exit"),
            ))
            val abandonedAfterTutorial = abandonedStore.dispatch(envelope(
                "abandoned-complete-tutorial",
                abandonedStore.current.revision,
                GameCommand.HighSchool(HighSchoolPhase4Command.CompleteTutorial("45")),
            )).state
            assertEquals(PitchBoundary.ABANDONED, abandonedAfterTutorial.pitch?.boundary)
            assertEquals(HighSchoolPhase.SCHOOL_SELECTION, requireNotNull(abandonedAfterTutorial.highSchool).run.phase)
            assertEquals(0UL, abandonedAfterTutorial.meta.completedGameCount)
        }
    }

    @Test
    fun completedGameCountCountsOnlyOfficialHighSchoolAndProPitches() {
        runBlocking {
            val tutorialInitial = GameAggregateState.initial("install-count-tutorial")
            val tutorialStore = KotlinGameStore.fromState(
                tutorialInitial,
                authorityMode = NativeAuthorityMode.NATIVE_AUTHORITATIVE,
                ioRepository = SerializedRepository(tutorialInitial),
            )
            startTutorial(tutorialStore)
            completePitch(tutorialStore, "tutorial-session", tutorialReserve("tutorial-session"))
            assertEquals(0UL, tutorialStore.current.meta.completedGameCount)

            val highSchoolInitial = GameAggregateState.initial("install-count-hs")
            val highSchoolStore = KotlinGameStore.fromState(
                highSchoolInitial,
                authorityMode = NativeAuthorityMode.NATIVE_AUTHORITATIVE,
                ioRepository = SerializedRepository(highSchoolInitial),
            )
            val start = highSchoolStore.dispatch(envelope("hs-start", 0UL, GameCommand.HighSchool(HighSchoolPhase4Command.Start(
                HighSchoolPhase4StartRequest("42", "power_prospect", "stable", "2026-W33", "2026-08-14"),
            )))).state
            val highSchoolCareerId = requireNotNull(start.highSchool).run.careerId
            completePitch(
                highSchoolStore,
                "hs-session",
                GameCommand.ReservePitch("hs-session", PitchCareerKind.HIGH_SCHOOL, highSchoolCareerId, "hs-game", "hs-seed"),
                challenge = true,
            )
            assertEquals(0UL, highSchoolStore.current.meta.completedGameCount)

            val officialHighSchool = GameAggregateState.initial("install-count-hs-official")
            val officialHsStore = KotlinGameStore.fromState(
                officialHighSchool,
                authorityMode = NativeAuthorityMode.NATIVE_AUTHORITATIVE,
                ioRepository = SerializedRepository(officialHighSchool),
            )
            val hsStarted = officialHsStore.dispatch(envelope("hs-start", 0UL, GameCommand.HighSchool(HighSchoolPhase4Command.Start(
                HighSchoolPhase4StartRequest("43", "power_prospect", "stable", "2026-W33", "2026-08-14"),
            )))).state
            completePitch(
                officialHsStore,
                "hs-official-session",
                GameCommand.ReservePitch("hs-official-session", PitchCareerKind.HIGH_SCHOOL, requireNotNull(hsStarted.highSchool).run.careerId, "hs-game", "hs-seed"),
            )
            assertEquals(1UL, officialHsStore.current.meta.completedGameCount)

            val proInitial = GameAggregateState.initial("install-count-pro")
            val proStore = KotlinGameStore.fromState(
                proInitial,
                authorityMode = NativeAuthorityMode.NATIVE_AUTHORITATIVE,
                ioRepository = SerializedRepository(proInitial),
            )
            val proStarted = proStore.dispatch(envelope("pro-start", 0UL, GameCommand.Pro(ProCommand.StartDirect(
                ProStartDirectRequest("42", "power_prospect", "내부 QA 투수"),
            )))).state
            completePitch(
                proStore,
                "pro-session",
                GameCommand.ReservePitch("pro-session", PitchCareerKind.PRO, requireNotNull(proStarted.pro).careerId, "pro-game", "pro-seed"),
            )
            assertEquals(1UL, proStore.current.meta.completedGameCount)
        }
    }

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

    private suspend fun completePitch(
        store: KotlinGameStore,
        sessionId: String,
        reserve: GameCommand,
        challenge: Boolean = false,
    ) {
        val reserveCommand = if (reserve is GameCommand.ReservePitch && reserve.challengeRun != challenge) reserve.copy(challengeRun = challenge) else reserve
        var revision = store.current.revision
        store.dispatch(envelope("${sessionId}-reserve", revision, reserveCommand)); revision += 1UL
        store.dispatch(envelope("${sessionId}-start", revision, GameCommand.StartPitch(sessionId))); revision += 1UL
        store.dispatch(envelope("${sessionId}-commit", revision, GameCommand.CommitPitch(sessionId, "pitch-1", "result-1"))); revision += 1UL
        store.dispatch(envelope("${sessionId}-consume", revision, GameCommand.ConsumePitch(sessionId, "pitch-1"))); revision += 1UL
        store.dispatch(envelope("${sessionId}-terminal", revision, GameCommand.MarkPitchTerminal(sessionId, "pitch-1", "terminal-1"))); revision += 1UL
        store.dispatch(envelope("${sessionId}-complete", revision, GameCommand.CompletePitch(sessionId)))
    }

    private fun tutorialReserve(sessionId: String = "session-analytics"): GameCommand.ReservePitch =
        GameCommand.ReservePitch(sessionId, PitchCareerKind.TUTORIAL, TUTORIAL_CAREER_ID, "tutorial-game", "tutorial-seed")

    private fun envelope(id: String, revision: ULong, command: GameCommand): GameCommandEnvelope = GameCommandEnvelope(
        commandId = id,
        sessionId = when (command) {
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
        expectedRevision = revision,
        command = command,
    )

    private suspend fun withTempDirectory(block: suspend (Path) -> Unit) {
        val directory = Files.createTempDirectory("baseball-phase6-contract-")
        try {
            block(directory)
        } finally {
            Files.walk(directory).use { stream -> stream.sorted(Comparator.reverseOrder()).forEach { Files.deleteIfExists(it) } }
        }
    }

    private class FixedClock(private val millis: Long) : SaveClock {
        override fun nowUtcMillis(): Long = millis
    }

    private class SerializedRepository(
        private var value: GameAggregateState,
    ) : GameStoreRepository {
        private val concurrent = AtomicInteger(0)
        var maximumConcurrentSaves: Int = 0
            private set

        override suspend fun save(value: GameAggregateState, revision: ULong): SaveWriteResult<GameAggregateState> {
            val active = concurrent.incrementAndGet()
            maximumConcurrentSaves = maxOf(maximumConcurrentSaves, active)
            Thread.sleep(15)
            this.value = value
            concurrent.decrementAndGet()
            return envelope(value, revision)
        }

        override suspend fun load(): SaveLoadResult<GameAggregateState> = SaveLoadResult(
            SaveLoadStatus.LOADED_CANONICAL,
            envelope = envelope(value, value.revision).envelope,
        )

        override suspend fun reset() = Unit

        private fun envelope(value: GameAggregateState, revision: ULong): SaveWriteResult<GameAggregateState> {
            val payload = GameAggregateCodec.encodePayload(value)
            return SaveWriteResult(
                SaveEnvelope("android-unity-save-v1", 1, revision, "2023-11-14T22:13:20.000Z", payload.canonicalSha256(), value, payload),
                Path.of("memory-save.json"),
            )
        }
    }
}
