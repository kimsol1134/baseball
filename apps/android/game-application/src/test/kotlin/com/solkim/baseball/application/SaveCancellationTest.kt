package com.solkim.baseball.application

import java.nio.file.Files
import kotlinx.coroutines.*
import kotlin.test.*

class SaveCancellationTest {
    @Test fun aBackgroundEventCannotSplitOnePlayerAction() = runBlocking {
        val initial = GameAggregateState.initial("batch-order")
        val delegate = InMemoryShadowFixtureGameStoreRepository(initial)
        val written = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        val repository = object : ShadowFixtureGameStoreRepository by delegate {
            override suspend fun save(value: GameAggregateState, revision: ULong): com.solkim.baseball.persistence.SaveWriteResult<GameAggregateState> {
                val result = delegate.save(value, revision)
                if (revision == 1UL) { written.complete(Unit); release.await() }
                return result
            }
        }
        val store = KotlinGameStore.fromShadowFixture(initial, repository)
        try {
            withTimeout(10_000) {
                val action = async { store.dispatchBatch(listOf(
                    GameCommandEnvelope("enter", "ui", 0UL, GameCommand.EnterSetup),
                    GameCommandEnvelope("setting", "ui", 1UL, GameCommand.UpdateSettings(initial.settings.copy(musicEnabled = false))),
                )) }
                written.await()
                val background = async(start = CoroutineStart.UNDISPATCHED) { runCatching {
                    store.dispatch(GameCommandEnvelope("background", "analytics", 1UL, GameCommand.RecordAnalytics("seen", "screen_view")))
                } }
                release.complete(Unit)
                assertEquals(2, action.await().size)
                assertTrue(background.await().isFailure, "Stale background events must not interrupt the player's action")
                assertEquals(2UL, store.current.revision)
                assertFalse(store.current.settings.musicEnabled)
            }
        } finally { store.close() }
    }

    @Test fun destroyingTheCallerAfterDiskCommitCannotLeaveTheStoreBehind() = runBlocking {
        val folder = Files.createTempDirectory("baseball-cancel-save-")
        val id = "cancel-save"
        val delegate = CSharpLegacyGameStoreRepository(folder, id)
        val written = CompletableDeferred<Unit>()
        val returnFromWrite = CompletableDeferred<Unit>()
        val repository = object : NativeAuthoritativeGameStoreRepository by delegate {
            override suspend fun dispatchLegacy(before: GameAggregateState, envelope: GameCommandEnvelope): GameDispatchResult = withContext(Dispatchers.IO) {
                val result = delegate.dispatchLegacy(before, envelope)
                if (envelope.commandId == "enter") {
                    written.complete(Unit)
                    returnFromWrite.await()
                }
                result
            }
        }
        val store = KotlinGameStore.open(id, repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try {
            withTimeout(10_000) {
                val caller = launch { store.dispatch(GameCommandEnvelope("enter", "ui", 0UL, GameCommand.EnterSetup)) }
                written.await()
                caller.cancel() // Activity destroyed after the file was written, before IO returns.
                returnFromWrite.complete(Unit)
                caller.join()
                assertEquals(delegate.load().envelope!!.payload, store.current, "Disk and UI must agree even when the caller disappears")
                assertFalse(store.busy.value)
                store.dispatch(GameCommandEnvelope("next", "ui", store.current.revision,
                    GameCommand.UpdateSettings(store.current.settings.copy(musicEnabled = false))))
                assertFalse(store.current.settings.musicEnabled)
            }
        } finally {
            store.close()
            Files.walk(folder).use { it.sorted(Comparator.reverseOrder()).forEach(Files::deleteIfExists) }
        }
    }
}
