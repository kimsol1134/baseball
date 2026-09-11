package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase4Command
import com.solkim.baseball.core.highschool.HighSchoolPhase4CommandEnvelope
import com.solkim.baseball.core.highschool.HighSchoolPhase4CommandStore
import com.solkim.baseball.core.pro.ProCommand
import com.solkim.baseball.core.pro.ProCommandEnvelope
import com.solkim.baseball.core.pro.ProCommandStore
import com.solkim.baseball.core.pro.ProCareerPhase
import com.solkim.baseball.persistence.KotlinSaveRepository
import com.solkim.baseball.persistence.SaveLoadStatus
import com.solkim.baseball.persistence.SaveRepositoryException
import com.solkim.baseball.persistence.SaveLoadResult
import com.solkim.baseball.persistence.SaveWriteResult
import com.solkim.baseball.persistence.SaveEnvelope
import com.solkim.baseball.model.canonicalSha256
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.runBlocking
import java.util.concurrent.atomic.AtomicBoolean

/**
 * The application-facing repository boundary. File work is deliberately hidden behind
 * suspending methods so the GameStore never performs persistence on a caller/UI thread.
 */
public interface GameStoreRepository {
    public suspend fun save(value: GameAggregateState, revision: ULong): SaveWriteResult<GameAggregateState>
    public suspend fun load(): SaveLoadResult<GameAggregateState>
    public suspend fun reset()
}

/**
 * Explicit Phase 7 fixture boundary. It is process-local and never resolves to the production
 * package/save directory. The store still reports [NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY]
 * so a production composition cannot accidentally turn this vertical into a cutover.
 */
public interface ShadowFixtureGameStoreRepository : GameStoreRepository

/** Only explicit progress deletion may begin a new receipt/revision chain. */
public interface FreshProgressGameStoreRepository : GameStoreRepository {
    public suspend fun saveFreshProgress(value: GameAggregateState): SaveWriteResult<GameAggregateState>
}

public class InMemoryShadowFixtureGameStoreRepository(
    initial: GameAggregateState,
) : ShadowFixtureGameStoreRepository {
    private var current: GameAggregateState = initial
    private val shadowPath = java.nio.file.Paths.get("shadow-fixture", "save.json")

    override suspend fun save(value: GameAggregateState, revision: ULong): SaveWriteResult<GameAggregateState> {
        require(revision == value.revision) { "shadow_fixture.revision" }
        current = value
        val payloadTree = GameAggregateCodec.encodePayload(value)
        val envelope = SaveEnvelope(
            schema = "android-unity-save-v1",
            schemaVersion = 1,
            revision = revision,
            writtenAtUtc = "1970-01-01T00:00:00.000Z",
            payloadSha256 = payloadTree.canonicalSha256(),
            payload = value,
            payloadTree = payloadTree,
        )
        return SaveWriteResult(envelope, shadowPath)
    }

    override suspend fun load(): SaveLoadResult<GameAggregateState> {
        val payloadTree = GameAggregateCodec.encodePayload(current)
        val envelope = SaveEnvelope(
            schema = "android-unity-save-v1",
            schemaVersion = 1,
            revision = current.revision,
            writtenAtUtc = "1970-01-01T00:00:00.000Z",
            payloadSha256 = payloadTree.canonicalSha256(),
            payload = current,
            payloadTree = payloadTree,
        )
        return SaveLoadResult(SaveLoadStatus.LOADED_CANONICAL, envelope, shadowPath)
    }

    override suspend fun reset() {
        current = GameAggregateState.initial(current.installId)
    }
}

/**
 * Debug/emulator-only durable fixture repository. Its directory is supplied by the Compose
 * shadow application and is never the legacy Unity persistentDataPath or a production package
 * save location. Keeping this boundary on the marker interface lets process-kill tests restore
 * the same aggregate while the public authority mode remains nativeShadowReadOnly.
 */
public class FileShadowFixtureGameStoreRepository(
    public val directory: java.nio.file.Path,
    clock: com.solkim.baseball.persistence.SaveClock = com.solkim.baseball.persistence.SystemSaveClock,
    private val resetSideEffects: ResetSideEffects = NoResetSideEffects,
    faults: com.solkim.baseball.persistence.SaveFaultInjector = com.solkim.baseball.persistence.SaveFaultInjector.NONE,
) : ShadowFixtureGameStoreRepository, FreshProgressGameStoreRepository {
    private val delegate = com.solkim.baseball.persistence.AtomicJsonRepository(
        layout = com.solkim.baseball.persistence.SaveFileLayout(directory),
        codec = GameAggregateCodec,
        clock = clock,
        faults = faults,
    )
    // Persist the fresh state outside the files being cleared, before touching the old save.
    private val resetIntent = com.solkim.baseball.persistence.AtomicJsonRepository(
        layout = com.solkim.baseball.persistence.SaveFileLayout(directory.resolve("progress-reset")),
        codec = GameAggregateCodec,
        clock = clock,
    )

    override suspend fun save(value: GameAggregateState, revision: ULong): SaveWriteResult<GameAggregateState> =
        withContext(Dispatchers.IO) { finishPendingReset(); delegate.save(value, revision) }

    override suspend fun load(): SaveLoadResult<GameAggregateState> =
        withContext(Dispatchers.IO) { finishPendingReset(); delegate.load() }

    override suspend fun saveFreshProgress(value: GameAggregateState): SaveWriteResult<GameAggregateState> = withContext(Dispatchers.IO) {
        finishPendingReset()
        validateFreshProgress(value)
        resetIntent.save(value, value.revision)
        requireNotNull(finishPendingReset())
    }

    private fun validateFreshProgress(value: GameAggregateState) {
        value.validate()
        require(value.revision == 1UL && value.stage == GameStage.OPENING && value.highSchool == null && value.pro == null && value.pitch == null &&
            value.commandReceipts.singleOrNull()?.eventName == "game.reset") { "reset.intent_invalid" }
    }

    private fun finishPendingReset(): SaveWriteResult<GameAggregateState>? {
        val pending = resetIntent.load()
        if (pending.status == SaveLoadStatus.NO_SAVE) return null
        require(pending.status in setOf(SaveLoadStatus.LOADED_CANONICAL, SaveLoadStatus.RECOVERED_BACKUP)) { "reset.intent_unavailable" }
        val fresh = requireNotNull(pending.envelope).payload
        validateFreshProgress(fresh)
        delegate.reset()
        val written = delegate.save(fresh, fresh.revision)
        resetSideEffects.clearAnalytics()
        resetSideEffects.clearReview()
        resetSideEffects.clearReminders()
        resetSideEffects.clearScopedEpoch()
        resetSideEffects.clearShareCache()
        resetIntent.reset()
        return written
    }

    override suspend fun reset(): Unit = withContext(Dispatchers.IO) { delegate.reset(); resetIntent.reset() }
}

public class IoGameStoreRepository(
    private val delegate: KotlinSaveRepository<GameAggregateState>,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : GameStoreRepository {
    override suspend fun save(value: GameAggregateState, revision: ULong): SaveWriteResult<GameAggregateState> =
        withContext(ioDispatcher) { delegate.save(value, revision) }

    override suspend fun load(): SaveLoadResult<GameAggregateState> =
        withContext(ioDispatcher) { delegate.load() }

    override suspend fun reset(): Unit = withContext(ioDispatcher) { delegate.reset() }
}
