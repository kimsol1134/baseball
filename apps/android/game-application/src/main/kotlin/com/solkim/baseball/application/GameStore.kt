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

public data class ReconcileResult(
    public val reconciled: Boolean,
    public val previousRevision: ULong,
    public val persistedRevision: ULong,
    public val state: GameAggregateState,
    public val durableStateVerified: Boolean = false,
)

/** The single asynchronous aggregate authority used by the Compose application scope. */
public interface GameStore {
    public val state: StateFlow<GameSaveAggregate>
    public val busy: StateFlow<Boolean>

    public suspend fun dispatch(envelope: CommandEnvelope<GameCommand>): DispatchResult

    public suspend fun dispatchBatch(envelopes: List<GameCommandEnvelope>): List<GameDispatchResult> =
        envelopes.map { dispatch(it) }

    public suspend fun reconcilePersistedRevision(): ReconcileResult
}

public class KotlinGameStore private constructor(
    initial: GameAggregateState,
    private val repository: GameStoreRepository?,
    public val authorityMode: NativeAuthorityMode,
    private val analyticsProjection: AnalyticsReceiptProjection? = null,
    private val allowShadowFixtureWrites: Boolean = false,
) : GameStore {
    private val closed = AtomicBoolean(false)
    private val mutex = Mutex()
    private val _state = MutableStateFlow(initial)
    private val _busy = MutableStateFlow(false)
    private var pendingFreshProgressCommandId: String? = null

    override val state: StateFlow<GameAggregateState> = _state.asStateFlow()
    override val busy: StateFlow<Boolean> = _busy.asStateFlow()
    public val current: GameAggregateState get() = state.value

    public val supportsCareerBackup: Boolean get() = repository is CSharpLegacyGameStoreRepository || repository is ShadowFixtureGameStoreRepository && allowShadowFixtureWrites

    public suspend fun exportCareerBackup(): ByteArray = mutex.withLock {
        check(!closed.get()) { "game.store.closed" }
        require(CareerBackup.isAvailable(current)) { "backup.challenge_active" }
        (repository as? CSharpLegacyGameStoreRepository)?.exportCareer() ?: run {
            require(supportsCareerBackup) { "backup.unsupported_store" }; CareerBackup.encodeShadow(current)
        }
    }

    public suspend fun importCareerBackup(bytes: ByteArray, expectedRevision: ULong): Unit = mutex.withLock {
        check(!closed.get()) { "game.store.closed" }
        require(CareerBackup.isAvailable(current)) { "backup.challenge_active" }
        require(current.revision == expectedRevision) { "backup.stale_revision" }
        _busy.value = true
        try {
            withContext(kotlinx.coroutines.NonCancellable) {
                val restored = (repository as? CSharpLegacyGameStoreRepository)?.importCareer(bytes, expectedRevision) ?: run {
                    require(supportsCareerBackup) { "backup.unsupported_store" }
                    val source = requireNotNull(CareerBackup.shadow(bytes)) { "backup.store_format" }
                    val revision = current.revision + 1UL
                    require(revision > current.revision) { "backup.revision_overflow" }
                    val hash = com.solkim.baseball.model.Hashing.sha256Hex(bytes.toString(Charsets.UTF_8))
                    val receipt = GameCommandReceipt("backup:${java.util.UUID.randomUUID()}", "backup", current.revision, revision, hash, hash, "backup.imported")
                    val next = source.copy(installId = current.installId, revision = revision,
                        commandReceipts = current.commandReceipts + receipt, analytics = current.analytics).committed()
                    requireNotNull(repository).save(next, next.revision).envelope.payload
                }
                _state.value = restored
                analyticsProjection?.establishBaseline(restored)
            }
        } finally { _busy.value = false }
    }

    init {
        analyticsProjection?.establishBaseline(initial)
        // Reconcile only receipts that were not durably handed to the native boundary.  A
        // process-local baseline is retained for legacy test sinks, while the app composition
        // supplies the native outbox/once ledger through [durableReceiptIds].
        analyticsProjection?.retryPending(initial)
    }

    override suspend fun dispatch(envelope: GameCommandEnvelope): GameDispatchResult = mutex.withLock {
        withContext(kotlinx.coroutines.NonCancellable) { dispatchLocked(envelope) }
    }

    override suspend fun dispatchBatch(envelopes: List<GameCommandEnvelope>): List<GameDispatchResult> = mutex.withLock {
        withContext(kotlinx.coroutines.NonCancellable) {
            envelopes.map { dispatchLocked(it) }
        }
    }

    // Once a file write begins, publication must finish even if its Activity is destroyed.
    // Cancellation may stop a caller waiting for the mutex, but cannot split this commit.
    private suspend fun dispatchLocked(envelope: GameCommandEnvelope): GameDispatchResult {
        ensureOpen()
        _busy.value = true
        val before = state.value
        try {
            check(pendingFreshProgressCommandId == null || envelope.command == GameCommand.ResetProgress) { "game.store.reset_pending" }
            val nativeLegacyRepository = repository as? NativeAuthoritativeGameStoreRepository
            val reduced = nativeLegacyRepository?.dispatchLegacy(before, envelope)
                ?: GameStateReducer.dispatch(before, envelope)
            if (reduced.duplicate) return reduced
            if (nativeLegacyRepository == null && authorityMode != NativeAuthorityMode.NATIVE_AUTHORITATIVE && !allowShadowFixtureWrites) {
                throw SaveRepositoryException(com.solkim.baseball.persistence.SaveFailureCode.WRITE_DISABLED, "nativeShadowReadOnly.save_disabled")
            }
            if (nativeLegacyRepository == null) {
                val save = repository ?: throw IllegalStateException("game.store.repository_missing")
                if (envelope.command == GameCommand.ResetProgress && save is FreshProgressGameStoreRepository) {
                    pendingFreshProgressCommandId = envelope.commandId
                    save.saveFreshProgress(reduced.state)
                } else save.save(reduced.state, reduced.state.revision)
            }
            // StateFlow publication is after verified read-back and before observer/SDK work.
            _state.value = reduced.state
            pendingFreshProgressCommandId = null
            analyticsProjection?.publishAfterSave(before, reduced.state)
            return reduced
        } catch (cancelled: kotlinx.coroutines.CancellationException) {
            throw cancelled
        } catch (error: Exception) {
            error.addSuppressed(GameCommandFailureContext.capture(envelope, before, state.value))
            throw error
        } finally {
            _busy.value = false
        }
    }

    override suspend fun reconcilePersistedRevision(): ReconcileResult = mutex.withLock {
        ensureOpen()
        _busy.value = true
        try {
            val before = state.value
            val load = repository?.load()
            if (load == null || load.status == SaveLoadStatus.NO_SAVE) {
                return@withLock ReconcileResult(false, before.revision, before.revision, before)
            }
            if (load.status != SaveLoadStatus.LOADED_CANONICAL && load.status != SaveLoadStatus.RECOVERED_BACKUP) {
                throw IllegalStateException("game.store.reconcile_unsupported:${load.status}")
            }
            val candidate = requireNotNull(load.envelope).payload
            require(candidate.installId == before.installId) { "game.store.reconcile_install" }
            val confirmedFreshProgress = repository is FreshProgressGameStoreRepository && pendingFreshProgressCommandId != null &&
                candidate.commandReceipts.singleOrNull()?.let { it.commandId == pendingFreshProgressCommandId && it.eventName == "game.reset" } == true &&
                candidate.revision == 1UL && candidate.stage == GameStage.OPENING && candidate.highSchool == null && candidate.pro == null && candidate.pitch == null
            require(candidate.revision >= before.revision || confirmedFreshProgress) { "game.store.reconcile_rollback" }
            if (candidate.revision == before.revision && !confirmedFreshProgress) {
                pendingFreshProgressCommandId = null
                require(candidate.commitment == before.commitment) { "game.store.reconcile_same_revision_conflict" }
                return@withLock ReconcileResult(false, before.revision, candidate.revision, candidate, durableStateVerified = true)
            }
            if (repository !is NativeAuthoritativeGameStoreRepository) candidate.validate()
            _state.value = candidate
            pendingFreshProgressCommandId = null
            analyticsProjection?.publishAfterSave(before, candidate)
            ReconcileResult(true, before.revision, candidate.revision, candidate, durableStateVerified = true)
        } finally {
            _busy.value = false
        }
    }

    /** Compatibility alias for callers that already used the old name; it remains suspending. */
    public suspend fun reconcile(): Boolean = reconcilePersistedRevision().reconciled

    /**
     * Retries the post-save analytics handoff without dispatching a game command.  The aggregate
     * is already durable at this point; this hook is deliberately separate so an SDK/file
     * observer failure can never turn into a second command or a lost in-process receipt.
     */
    public fun retryAnalyticsHandoff() {
        analyticsProjection?.retryPending(current)
    }

    /** True when the native/observer handoff still needs an in-process retry. */
    public fun analyticsHandoffPending(receiptId: String): Boolean =
        analyticsProjection?.pending(current)?.any { it.receiptId == receiptId } == true

    public fun close() { closed.set(true) }

    private fun ensureOpen() {
        check(!closed.get()) { "game.store.closed" }
    }

    public companion object {
        public fun fromState(
            state: GameAggregateState,
            repository: KotlinSaveRepository<GameAggregateState>? = null,
            authorityMode: NativeAuthorityMode = NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY,
            analyticsProjection: AnalyticsReceiptProjection? = null,
            ioRepository: GameStoreRepository? = null,
        ): KotlinGameStore {
            state.validate()
            require(repository == null || ioRepository == null) { "game.store.repository_ambiguous" }
            val boundary = ioRepository ?: repository?.let(::IoGameStoreRepository)
            if (authorityMode == NativeAuthorityMode.NATIVE_AUTHORITATIVE) requireNotNull(boundary) { "game.store.repository_required" }
            return KotlinGameStore(state, boundary, authorityMode, analyticsProjection)
        }

        /**
         * Phase 7 composition only: state advances through a process-local fixture repository.
         * This keeps the public authority mode shadow-read-only and makes a production file write
         * impossible from the Compose vertical until the later cutover gate.
         */
        public fun fromShadowFixture(
            state: GameAggregateState,
            repository: ShadowFixtureGameStoreRepository = InMemoryShadowFixtureGameStoreRepository(state),
            analyticsProjection: AnalyticsReceiptProjection? = null,
        ): KotlinGameStore {
            state.validate()
            return KotlinGameStore(
                initial = state,
                repository = repository,
                authorityMode = NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY,
                analyticsProjection = analyticsProjection,
                allowShadowFixtureWrites = true,
            )
        }

        public suspend fun open(
            installId: String,
            repository: KotlinSaveRepository<GameAggregateState>,
            authorityMode: NativeAuthorityMode,
            analyticsProjection: AnalyticsReceiptProjection? = null,
        ): KotlinGameStore {
            return open(installId, IoGameStoreRepository(repository), authorityMode, analyticsProjection)
        }

        public suspend fun open(
            installId: String,
            repository: GameStoreRepository,
            authorityMode: NativeAuthorityMode,
            analyticsProjection: AnalyticsReceiptProjection? = null,
        ): KotlinGameStore {
            require(installId.isNotBlank()) { "game.store.install" }
            val loaded = repository.load()
            val initial = when (loaded.status) {
                SaveLoadStatus.NO_SAVE -> GameAggregateState.initial(installId)
                SaveLoadStatus.LOADED_CANONICAL, SaveLoadStatus.RECOVERED_BACKUP -> {
                    val payload = requireNotNull(loaded.envelope).payload
                    require(payload.installId == installId) { "game.store.install_mismatch" }
                    if (repository !is NativeAuthoritativeGameStoreRepository) payload.validate()
                    payload
                }
                SaveLoadStatus.FUTURE_VERSION -> throw IllegalStateException("game.store.future_schema")
                SaveLoadStatus.MIGRATION_REQUIRED -> throw IllegalStateException("game.store.migration_required")
                SaveLoadStatus.UNRECOVERABLE_CORRUPTION -> throw IllegalStateException("game.store.unrecoverable")
            }
            return KotlinGameStore(
                initial,
                repository,
                authorityMode,
                analyticsProjection,
                allowShadowFixtureWrites = repository is ShadowFixtureGameStoreRepository,
            )
        }

        /** Test/composition convenience; production callers should open from a coroutine scope. */
        public fun openBlocking(
            installId: String,
            repository: KotlinSaveRepository<GameAggregateState>,
            authorityMode: NativeAuthorityMode,
            analyticsProjection: AnalyticsReceiptProjection? = null,
        ): KotlinGameStore = runBlocking { open(installId, repository, authorityMode, analyticsProjection) }
    }
}
