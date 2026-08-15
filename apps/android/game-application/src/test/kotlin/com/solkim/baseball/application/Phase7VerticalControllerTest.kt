package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchZone
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import java.nio.file.Path
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class Phase7VerticalControllerTest {
    @Test
    fun fileRepositoryReopensAfterReservedProcessDeath() = runBlocking {
        assertFileRepositoryReopensAtBoundary(PitchBoundary.RESERVED)
    }

    @Test
    fun fileRepositoryReopensAfterPlayingProcessDeath() = runBlocking {
        assertFileRepositoryReopensAtBoundary(PitchBoundary.PLAYING)
    }

    @Test
    fun fileRepositoryReopensAfterCommittedProcessDeath() = runBlocking {
        assertFileRepositoryReopensAtBoundary(PitchBoundary.COMMITTED)
    }

    @Test
    fun fileRepositoryReopensAfterConsumedProcessDeath() = runBlocking {
        assertFileRepositoryReopensAtBoundary(PitchBoundary.CONSUMED)
    }

    @Test
    fun fileRepositoryReopensAfterTerminalProcessDeath() = runBlocking {
        assertFileRepositoryReopensAtBoundary(PitchBoundary.TERMINAL)
    }

    @Test
    fun fileRepositoryReopensAfterCompletedProcessDeath() = runBlocking {
        assertFileRepositoryReopensAtBoundary(PitchBoundary.COMPLETED)
    }

    @Test
    fun fileRepositoryReopensAtEveryDurablePitchBoundary() = runBlocking {
        withTempDirectory { directory ->
            val repository = FileShadowFixtureGameStoreRepository(directory)
            var store = KotlinGameStore.open(
                "phase7-boundaries",
                repository,
                NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY,
            )
            var controller = Phase7VerticalController(store)
            controller.enterSetup()
            controller.startHighSchool("민서준")
            controller.beginTutorial()

            val sessionId = "phase7-boundary-session"
            val reserve = GameCommand.ReservePitch(
                sessionId,
                PitchCareerKind.TUTORIAL,
                TUTORIAL_CAREER_ID,
                "tutorial",
                "phase7-boundary-seed",
            )
            send(store, "boundary-reserve", reserve)
            assertEquals(PitchBoundary.RESERVED, store.current.pitch?.boundary)

            store = reopen(store, repository)
            assertEquals(PitchBoundary.RESERVED, store.current.pitch?.boundary)
            send(store, "boundary-start", GameCommand.StartPitch(sessionId))
            assertEquals(PitchBoundary.PLAYING, store.current.pitch?.boundary)

            store = reopen(store, repository)
            assertEquals(PitchBoundary.PLAYING, store.current.pitch?.boundary)
            val presentation = Phase7VerticalController(store).submitPitch(
                sessionId,
                0,
                PitchKind.FOUR_SEAM,
                PitchZone(1, 1),
            )
            assertEquals(PitchBoundary.COMMITTED, store.current.pitch?.boundary)

            store = reopen(store, repository)
            assertEquals(PitchBoundary.COMMITTED, store.current.pitch?.boundary)
            send(store, "boundary-consume", GameCommand.ConsumePitch(sessionId, presentation.pitchId))
            assertEquals(PitchBoundary.CONSUMED, store.current.pitch?.boundary)

            store = reopen(store, repository)
            assertEquals(PitchBoundary.CONSUMED, store.current.pitch?.boundary)
            send(
                store,
                "boundary-terminal",
                GameCommand.MarkPitchTerminal(sessionId, presentation.pitchId, presentation.requestSha256),
            )
            assertEquals(PitchBoundary.TERMINAL, store.current.pitch?.boundary)

            store = reopen(store, repository)
            assertEquals(PitchBoundary.TERMINAL, store.current.pitch?.boundary)
            send(store, "boundary-complete", GameCommand.CompletePitch(sessionId))
            assertEquals(PitchBoundary.COMPLETED, store.current.pitch?.boundary)

            store = reopen(store, repository)
            controller = Phase7VerticalController(store)
            assertEquals(PitchBoundary.COMPLETED, store.current.pitch?.boundary)
            assertEquals(0UL, store.current.meta.completedGameCount)
            assertFalse(store.busy.value)
            controller.completePitchAndPostgame(sessionId)
            assertEquals(PitchBoundary.COMPLETED, store.current.pitch?.boundary)
        }
    }

    @Test
    fun openingToTutorialPitchSurvivesReservedPlayingCommitConsumeTerminalAndCompletionRestart() = runBlocking {
        val repository = InMemoryShadowFixtureGameStoreRepository(GameAggregateState.initial("phase7-vertical"))
        var store = KotlinGameStore.fromShadowFixture(GameAggregateState.initial("phase7-vertical"), repository)
        var controller = Phase7VerticalController(store)

        assertEquals(Phase7Route.OPENING, controller.route())
        controller.enterSetup()
        assertEquals(Phase7Route.SETUP, controller.route())
        controller.startHighSchool("민서준")
        assertEquals(Phase7Route.PROLOGUE, controller.route())
        controller.beginTutorial()
        assertEquals(Phase7Route.TUTORIAL, controller.route())

        val reservedSession = "phase7-reserved"
        send(store, "reserve", GameCommand.ReservePitch(
            reservedSession,
            PitchCareerKind.TUTORIAL,
            TUTORIAL_CAREER_ID,
            "tutorial",
            "phase7-seed",
        ))
        assertEquals(PitchBoundary.RESERVED, store.current.pitch?.boundary)

        store = restart(store, repository, "phase7-vertical")
        controller = Phase7VerticalController(store)
        assertEquals(PitchBoundary.RESERVED, store.current.pitch?.boundary)
        send(store, "start", GameCommand.StartPitch(reservedSession))
        assertEquals(PitchBoundary.PLAYING, store.current.pitch?.boundary)

        store = restart(store, repository, "phase7-vertical")
        controller = Phase7VerticalController(store)
        assertEquals(PitchBoundary.PLAYING, store.current.pitch?.boundary)
        val request = controller.submitPitch(reservedSession, 2, PitchKind.SLIDER, PitchZone(1, 1))
        assertEquals(PitchBoundary.COMMITTED, store.current.pitch?.boundary)

        store = restart(store, repository, "phase7-vertical")
        controller = Phase7VerticalController(store)
        assertEquals(PitchBoundary.COMMITTED, store.current.pitch?.boundary)
        assertEquals(request, controller.preparePresentation(reservedSession, 2))
        controller.consumePresentation(reservedSession, request)
        assertEquals(PitchBoundary.TERMINAL, store.current.pitch?.boundary)

        store = restart(store, repository, "phase7-vertical")
        controller = Phase7VerticalController(store)
        controller.completePitchAndPostgame(reservedSession)
        assertEquals(PitchBoundary.COMPLETED, store.current.pitch?.boundary)
        controller.completePitchAndPostgame(reservedSession)
        assertEquals(PitchBoundary.COMPLETED, store.current.pitch?.boundary)
        assertEquals(0UL, store.current.meta.completedGameCount)

        // The retained terminal tutorial wire shape must not block the next durable HS phase.
        controller.completeTutorial()
        assertEquals(HighSchoolPhase.SCHOOL_SELECTION, requireNotNull(store.current.highSchool).run.phase)
        assertEquals(Phase7Route.SCHOOL, controller.route())
        controller.chooseSchool()
        assertEquals(Phase7Route.TRAINING, controller.route())
        assertEquals(0UL, store.current.meta.completedGameCount)
    }

    @Test
    fun backSuspendAndExplicitAbandonRemainDistinctAcrossRestart() = runBlocking {
        val repository = InMemoryShadowFixtureGameStoreRepository(GameAggregateState.initial("phase7-back"))
        var store = KotlinGameStore.fromShadowFixture(GameAggregateState.initial("phase7-back"), repository)
        var controller = Phase7VerticalController(store)
        controller.enterSetup()
        controller.startHighSchool("민서준")
        controller.beginTutorial()
        val launch = controller.reserveTutorialPitch()
        controller.suspendPitch(launch.sessionId)
        assertEquals(PitchBoundary.SUSPENDED, store.current.pitch?.boundary)

        store = restart(store, repository, "phase7-back")
        controller = Phase7VerticalController(store)
        assertEquals(PitchBoundary.SUSPENDED, store.current.pitch?.boundary)
        controller.resumePitch(launch.sessionId)
        controller.abandonPitch(launch.sessionId, "user-abandoned")
        assertEquals(PitchBoundary.ABANDONED, store.current.pitch?.boundary)
        assertEquals(0UL, store.current.meta.completedGameCount)
        assertTrue(store.current.pitch?.abandonedReason == "user-abandoned")
    }

    @Test
    fun analyticsBaselineDoesNotReplayDurableHistoryAfterRestart() = runBlocking {
        val repository = InMemoryShadowFixtureGameStoreRepository(GameAggregateState.initial("phase7-analytics"))
        val firstPublished = mutableListOf<String>()
        var store = KotlinGameStore.fromShadowFixture(
            GameAggregateState.initial("phase7-analytics"),
            repository,
            AnalyticsReceiptProjection(sink = AnalyticsReceiptSink { receipts -> firstPublished += receipts.map { it.receiptId } }),
        )
        val controller = Phase7VerticalController(store)
        controller.enterSetup()
        assertTrue(firstPublished.isNotEmpty())
        val durableHistory = firstPublished.toList()

        val afterRestartPublished = mutableListOf<String>()
        store = KotlinGameStore.open(
            "phase7-analytics",
            repository,
            NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY,
            AnalyticsReceiptProjection(sink = AnalyticsReceiptSink { receipts -> afterRestartPublished += receipts.map { it.receiptId } }),
        )
        assertTrue(afterRestartPublished.isEmpty())
        Phase7VerticalController(store).startHighSchool("민서준")
        assertTrue(afterRestartPublished.isNotEmpty())
        assertTrue(afterRestartPublished.none { it in durableHistory })
        assertEquals(afterRestartPublished.size, afterRestartPublished.distinct().size)
        assertFalse(store.busy.value)
    }

    @Test
    fun trainingRelationshipImportantGamePostgameAwakeningAndChapterRoutesAreExecutable() = runBlocking {
        val repository = InMemoryShadowFixtureGameStoreRepository(GameAggregateState.initial("phase7-routes"))
        val store = KotlinGameStore.fromShadowFixture(GameAggregateState.initial("phase7-routes"), repository)
        val controller = Phase7VerticalController(store)
        controller.enterSetup()
        controller.startHighSchool("민서준")
        controller.beginTutorial()
        controller.completeTutorial()
        controller.chooseSchool()

        var safety = 0
        var observedMultiPitchGame = false
        while (controller.route() != Phase7Route.AWAKENING) {
            assertTrue(++safety < 120, "Phase 7 route loop did not advance")
            when (controller.route()) {
                Phase7Route.TRAINING -> controller.commitTraining()
                Phase7Route.RELATIONSHIP -> controller.resolveRelationship()
                Phase7Route.IMPORTANT_GAME -> {
                    val gamesBefore = store.current.meta.completedGameCount
                    var launch = controller.reserveImportantGame()
                    var pitchCount = 0
                    while (store.current.highSchool?.activePitch != null) {
                        val request = controller.submitPitch(
                            sessionId = launch.sessionId,
                            pitchIndex = pitchCount % 4,
                            pitchType = PitchKind.FOUR_SEAM,
                            zone = PitchZone(1, 1),
                        )
                        controller.consumePresentation(launch.sessionId, request)
                        controller.completePitchAndPostgame(launch.sessionId)
                        pitchCount++
                        assertTrue(pitchCount < 64, "important game did not terminate")
                        if (store.current.highSchool?.activePitch != null) {
                            launch = controller.reserveNextImportantPitch()
                        }
                    }
                    assertTrue(pitchCount > 0)
                    observedMultiPitchGame = observedMultiPitchGame || pitchCount > 1
                    assertEquals(gamesBefore + 1UL, store.current.meta.completedGameCount)
                    if (controller.route() == Phase7Route.POSTGAME) controller.dismissPostgame()
                }
                Phase7Route.POSTGAME -> controller.dismissPostgame()
                Phase7Route.CHAPTER -> controller.advanceChapter()
                else -> error("unexpected Phase 7 route ${controller.route()}")
            }
        }

        assertEquals(Phase7Route.AWAKENING, controller.route())
        assertTrue(observedMultiPitchGame, "Phase 7 must exercise a multi-pitch important game")
        assertTrue(store.current.meta.completedGameCount > 0UL)
        assertEquals(
            store.current.highSchool?.completedGameReceipts?.size?.toULong(),
            store.current.highSchool?.completedGameCounter,
        )
        assertEquals(
            store.current.analytics.receipts.size,
            store.current.analytics.receipts.map { it.receiptId }.distinct().size,
        )
        controller.chooseAwakening()
        assertEquals(Phase7Route.CHAPTER, controller.route())
        controller.advanceChapter()
        assertEquals(Phase7Route.TRAINING, controller.route())
    }

    @Test
    fun phase7CommandWireRoundTripsShellAndPresentationCommandsStrictly() {
        val setup = GameCommandEnvelope("setup", "phase7-shell", 0UL, GameCommand.EnterSetup)
        val clear = GameCommandEnvelope("clear", "phase7-pitch", 8UL, GameCommand.ClearPitchPresentation("phase7-pitch"))
        assertEquals(setup, GameCommandCodec.decode(GameCommandCodec.encode(setup)))
        assertEquals(clear, GameCommandCodec.decode(GameCommandCodec.encode(clear)))
    }

    private suspend fun send(store: KotlinGameStore, id: String, command: GameCommand) {
        store.dispatch(
            GameCommandEnvelope(
                commandId = id,
                sessionId = commandSession(command),
                expectedRevision = store.current.revision,
                command = command,
            ),
        )
    }

    private suspend fun restart(
        old: KotlinGameStore,
        repository: InMemoryShadowFixtureGameStoreRepository,
        installId: String,
    ): KotlinGameStore {
        old.close()
        return KotlinGameStore.open(installId, repository, NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY)
    }

    private suspend fun reopen(
        old: KotlinGameStore,
        repository: FileShadowFixtureGameStoreRepository,
        installId: String = "phase7-boundaries",
    ): KotlinGameStore {
        old.close()
        return KotlinGameStore.open(installId, repository, NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY)
    }

    private suspend fun withTempDirectory(block: suspend (Path) -> Unit) {
        val directory = Files.createTempDirectory("baseball-phase7-boundaries-")
        try {
            block(directory)
        } finally {
            Files.walk(directory).use { stream ->
                stream.sorted(Comparator.reverseOrder()).forEach { Files.deleteIfExists(it) }
            }
        }
    }

    private suspend fun assertFileRepositoryReopensAtBoundary(target: PitchBoundary) {
        withTempDirectory { directory ->
            val repository = FileShadowFixtureGameStoreRepository(directory)
            val boundaryName = target.name.lowercase()
            val installId = "phase7-boundary-$boundaryName"
            var store = KotlinGameStore.open(
                installId,
                repository,
                NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY,
            )
            var controller = Phase7VerticalController(store)
            controller.enterSetup()
            controller.startHighSchool("민서준")
            controller.beginTutorial()

            val sessionId = "phase7-boundary-$boundaryName-session"
            send(
                store,
                "boundary-$boundaryName-reserve",
                GameCommand.ReservePitch(
                    sessionId,
                    PitchCareerKind.TUTORIAL,
                    TUTORIAL_CAREER_ID,
                    "tutorial",
                    "phase7-boundary-$boundaryName-seed",
                ),
            )
            if (target == PitchBoundary.RESERVED) {
                store = reopen(store, repository, installId)
                assertEquals(target, store.current.pitch?.boundary)
                return@withTempDirectory
            }

            store = reopen(store, repository, installId)
            send(store, "boundary-$boundaryName-start", GameCommand.StartPitch(sessionId))
            if (target == PitchBoundary.PLAYING) {
                store = reopen(store, repository, installId)
                assertEquals(target, store.current.pitch?.boundary)
                return@withTempDirectory
            }

            store = reopen(store, repository, installId)
            controller = Phase7VerticalController(store)
            val presentation = controller.submitPitch(sessionId, 0, PitchKind.FOUR_SEAM, PitchZone(1, 1))
            if (target == PitchBoundary.COMMITTED) {
                store = reopen(store, repository, installId)
                assertEquals(target, store.current.pitch?.boundary)
                return@withTempDirectory
            }

            store = reopen(store, repository, installId)
            send(store, "boundary-$boundaryName-consume", GameCommand.ConsumePitch(sessionId, presentation.pitchId))
            if (target == PitchBoundary.CONSUMED) {
                store = reopen(store, repository, installId)
                assertEquals(target, store.current.pitch?.boundary)
                return@withTempDirectory
            }

            store = reopen(store, repository, installId)
            send(
                store,
                "boundary-$boundaryName-terminal",
                GameCommand.MarkPitchTerminal(sessionId, presentation.pitchId, presentation.requestSha256),
            )
            if (target == PitchBoundary.TERMINAL) {
                store = reopen(store, repository, installId)
                assertEquals(target, store.current.pitch?.boundary)
                return@withTempDirectory
            }

            store = reopen(store, repository, installId)
            send(store, "boundary-$boundaryName-complete", GameCommand.CompletePitch(sessionId))
            store = reopen(store, repository, installId)
            assertEquals(PitchBoundary.COMPLETED, store.current.pitch?.boundary)
        }
    }

    private fun commandSession(command: GameCommand): String = when (command) {
        GameCommand.EnterSetup -> "phase7-shell"
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
        is GameCommand.HighSchool,
        is GameCommand.Pro,
        is GameCommand.UpdateSettings,
        is GameCommand.RecordAnalytics -> "phase7-shell"
    }
}
