package com.solkim.baseball.application

import com.solkim.baseball.persistence.SaveFaultInjector
import com.solkim.baseball.persistence.SaveFaultPoint
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import java.nio.file.Path
import kotlin.test.*

class NativeProgressResetTest {
    @Test fun confirmedResetRemovesCareerAndBackupsAndDuplicateCannotEraseNewProgress() = runBlocking {
        withDirectory { directory ->
            val repository = CSharpLegacyGameStoreRepository(directory, "reset-player")
            val store = KotlinGameStore.open("reset-player", repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            try {
                seedCareer(store)
                assertTrue(Files.exists(directory.resolve("save.bak.1")))
                val envelope = GameCommandEnvelope("confirmed-reset", "settings", store.current.revision, GameCommand.ResetProgress)
                store.dispatch(envelope)
                assertFresh(store.current)
                assertNoOldSaveFiles(directory)
                val reopened = KotlinGameStore.open("reset-player", repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
                try { assertEquals(store.current, reopened.current) } finally { reopened.close() }
                store.dispatch(GameCommandEnvelope("new-setup", "settings", store.current.revision, GameCommand.EnterSetup))
                val newProgress = store.current
                assertTrue(store.dispatch(envelope.copy(expectedRevision = newProgress.revision)).duplicate)
                assertEquals(newProgress, store.current)
            } finally { store.close() }
        }
    }

    @Test fun interruptedResetFinishesBeforeLoadingOrRecoveringAnOldBackup() = runBlocking {
        for (point in listOf(SaveFaultPoint.RESET_BEFORE_TEMP, SaveFaultPoint.RESET_BEFORE_CANONICAL,
                SaveFaultPoint.RESET_AFTER_CANONICAL, SaveFaultPoint.BEFORE_CANONICAL_SWAP)) withDirectory { directory ->
            var armed = false
            val repository = CSharpLegacyGameStoreRepository(directory, "reset-player", faults = SaveFaultInjector {
                if (armed && it == point) error("injected-reset-interruption")
            })
            val store = KotlinGameStore.open("reset-player", repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            seedCareer(store)
            armed = true
            assertFails { store.dispatch(GameCommandEnvelope("interrupted-reset", "settings", store.current.revision, GameCommand.ResetProgress)) }
            store.close()
            // A new process has no memory of the button press. The durable intent must resume it.
            val reopened = KotlinGameStore.open("reset-player", CSharpLegacyGameStoreRepository(directory, "reset-player"), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            try { assertFresh(reopened.current); assertNoOldSaveFiles(directory) } finally { reopened.close() }
        }
    }

    @Test fun platformCleanupFailureRemainsRetryableAndCannotResurrectProgress() = runBlocking {
        withDirectory { directory ->
            val effects = object : ResetSideEffects by NoResetSideEffects {
                override fun clearReminders() { error("reminder-cleanup-failed") }
            }
            val repository = CSharpLegacyGameStoreRepository(directory, "reset-player", resetSideEffects = effects)
            val store = KotlinGameStore.open("reset-player", repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            seedCareer(store)
            assertFails { store.dispatch(GameCommandEnvelope("cleanup-reset", "settings", store.current.revision, GameCommand.ResetProgress)) }
            store.close()
            val reopened = KotlinGameStore.open("reset-player", CSharpLegacyGameStoreRepository(directory, "reset-player"), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            try { assertFresh(reopened.current); assertNoOldSaveFiles(directory) } finally { reopened.close() }
        }
    }

    private suspend fun seedCareer(store: KotlinGameStore) {
        val controller = Phase8Controller(store)
        controller.execute(Phase8ScreenId.P001_OPENING, "enterSetup")
        controller.execute(Phase8ScreenId.P002_SETUP, "startHighSchool")
        controller.execute(Phase8ScreenId.P027_SETTINGS, "toggleSound")
        assertNotNull(store.current.highSchool)
        assertFalse(store.current.settings.soundEnabled)
    }

    private fun assertFresh(state: GameAggregateState) {
        assertEquals(GameStage.OPENING, state.stage)
        assertNull(state.highSchool); assertNull(state.pro); assertNull(state.pitch)
        assertTrue(state.meta.lifeArchiveCareerIds.isEmpty())
        assertTrue(state.meta.retiredProCareers.isEmpty())
        assertEquals(0UL, state.meta.completedGameCount)
        assertEquals(GameSettingsState(), state.settings)
        assertFalse(state.settings.autoReleaseEnabled)
    }

    private fun assertNoOldSaveFiles(directory: Path) {
        for (position in 1..3) assertFalse(Files.exists(directory.resolve("save.bak.$position")))
        assertFalse(Files.exists(directory.resolve("progress-reset/save.json")))
    }

    private suspend fun withDirectory(block: suspend (Path) -> Unit) {
        val path = Files.createTempDirectory("baseball-reset-test-")
        try { block(path) } finally { Files.walk(path).use { it.sorted(Comparator.reverseOrder()).forEach(Files::deleteIfExists) } }
    }
}
