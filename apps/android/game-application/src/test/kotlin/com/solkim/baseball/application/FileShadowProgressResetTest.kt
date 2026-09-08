package com.solkim.baseball.application

import com.solkim.baseball.persistence.*
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import java.nio.file.Path
import kotlin.test.*

class FileShadowProgressResetTest {
    private fun command(store: KotlinGameStore, id: String, value: GameCommand) = GameCommandEnvelope(id, "reset-regression", store.current.revision, value)
    private suspend fun progressed(repo: FileShadowFixtureGameStoreRepository): KotlinGameStore {
        val store = KotlinGameStore.open("reset-regression", repo, NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY)
        val controller = Phase8Controller(store)
        controller.execute(Phase8ScreenId.P001_OPENING, "enterSetup")
        controller.execute(Phase8ScreenId.P002_SETUP, "startHighSchool")
        store.dispatch(command(store, "assist-on", GameCommand.UpdateSettings(store.current.settings.copy(autoReleaseEnabled = true))))
        return store
    }

    @Test fun realFileResetStartsFreshAndNextGamePersistsWithoutDisablingRollbackGuard() = runBlocking {
        val directory = Files.createTempDirectory("baseball-reset-test-")
        try {
            val repo = FileShadowFixtureGameStoreRepository(directory)
            val store = progressed(repo)
            val before = store.current
            store.dispatch(command(store, "reset", GameCommand.ResetProgress))
            assertFresh(store.current)
            assertEquals(store.current, repo.load().envelope!!.payload)
            assertFailsWith<SaveRepositoryException> { repo.save(GameAggregateState.initial(before.installId), 0UL) }
            for (i in 1..3) assertFalse(Files.exists(directory.resolve("save.bak.$i")))
            assertFalse(Files.exists(directory.resolve("progress-reset/save.json")))
            store.close()
            val reopened = KotlinGameStore.open(before.installId, FileShadowFixtureGameStoreRepository(directory), NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY)
            assertFresh(reopened.current)
            val controller = Phase8Controller(reopened)
            controller.execute(Phase8ScreenId.P001_OPENING, "enterSetup")
            controller.execute(Phase8ScreenId.P002_SETUP, "startHighSchool")
            assertNotNull(controller.execute(Phase8ScreenId.P003_PROLOGUE, "openTutorialPitch").launch)
            assertEquals(reopened.current, repo.load().envelope!!.payload)
            reopened.close()
        } finally { directory.toFile().deleteRecursively() }
    }

    @Test fun interruptedResetCannotRestoreDeletedCareerAndRecoversInProcessOrAfterRestart() = runBlocking {
        for (point in listOf(SaveFaultPoint.RESET_BEFORE_CANONICAL, SaveFaultPoint.RESET_AFTER_CANONICAL, SaveFaultPoint.BEFORE_CANONICAL_SWAP)) {
            val directory = Files.createTempDirectory("baseball-reset-fault-")
            try {
                var armed = false
                val repo = FileShadowFixtureGameStoreRepository(directory, faults = SaveFaultInjector {
                    if (armed && it == point) { armed = false; error("injected reset failure") }
                })
                val store = progressed(repo)
                val before = store.current
                armed = true
                assertFailsWith<SaveRepositoryException> { store.dispatch(command(store, "reset", GameCommand.ResetProgress)) }
                assertEquals(before, store.current)
                assertTrue(Files.exists(directory.resolve("progress-reset/save.json")))
                val blocked = assertFailsWith<IllegalStateException> {
                    store.dispatch(command(store, "stale-settings", GameCommand.UpdateSettings(before.settings)))
                }
                assertEquals("game.store.reset_pending", blocked.message)
                if (point == SaveFaultPoint.BEFORE_CANONICAL_SWAP) {
                    assertTrue(store.reconcilePersistedRevision().reconciled)
                    assertFresh(store.current)
                }
                store.close()
                val reopened = KotlinGameStore.open(before.installId, FileShadowFixtureGameStoreRepository(directory), NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY)
                assertFresh(reopened.current)
                assertFalse(Files.exists(directory.resolve("progress-reset/save.json")))
                reopened.dispatch(command(reopened, "new-start", GameCommand.EnterSetup))
                assertEquals(GameStage.SETUP, reopened.current.stage)
                reopened.close()
            } finally { directory.toFile().deleteRecursively() }
        }
    }

    @Test fun sideEffectFailureReconcilesTheCommittedResetBeforeAnyNewGameWrite() = runBlocking {
        val directory = Files.createTempDirectory("baseball-reset-effects-")
        try {
            var fail = true
            val effects = object : ResetSideEffects by NoResetSideEffects {
                override fun clearReview() { if (fail) { fail = false; error("review cleanup failed") } }
            }
            val repo = FileShadowFixtureGameStoreRepository(directory, resetSideEffects = effects)
            val store = progressed(repo)
            assertFailsWith<IllegalStateException> { store.dispatch(command(store, "reset", GameCommand.ResetProgress)) }
            assertTrue(store.reconcilePersistedRevision().reconciled)
            assertFresh(store.current)
            store.dispatch(command(store, "start-after-reset", GameCommand.EnterSetup))
            assertEquals(GameStage.SETUP, repo.load().envelope!!.payload.stage)
            store.close()
        } finally { directory.toFile().deleteRecursively() }
    }

    private fun assertFresh(state: GameAggregateState) {
        assertEquals(GameStage.OPENING, state.stage)
        assertEquals(1UL, state.revision)
        assertNull(state.highSchool)
        assertNull(state.pro)
        assertNull(state.pitch)
        assertFalse(state.settings.autoReleaseEnabled)
        assertEquals("game.reset", state.commandReceipts.single().eventName)
    }
}
