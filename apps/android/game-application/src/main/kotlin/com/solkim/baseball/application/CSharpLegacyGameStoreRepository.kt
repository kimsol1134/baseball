package com.solkim.baseball.application

import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.canonicalSha256
import com.solkim.baseball.persistence.AtomicJsonRepository
import com.solkim.baseball.persistence.JsonPayloadCodec
import com.solkim.baseball.persistence.KotlinSaveRepository
import com.solkim.baseball.persistence.LegacySaveCompatibilityException
import com.solkim.baseball.persistence.SaveEnvelope
import com.solkim.baseball.persistence.SaveFailureCode
import com.solkim.baseball.persistence.SaveFileLayout
import com.solkim.baseball.persistence.SaveFaultInjector
import com.solkim.baseball.persistence.SaveLoadResult
import com.solkim.baseball.persistence.SaveLoadStatus
import com.solkim.baseball.persistence.SaveRepositoryException
import com.solkim.baseball.persistence.SaveWriteResult
import com.solkim.baseball.persistence.CSharpSaveCompatibilityCodec
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.nio.file.Path

/**
 * The production cutover boundary for the frozen Unity v1 save.  It intentionally stores the
 * legacy payload tree rather than translating it into the newer typed aggregate codec: the C#
 * reader must see the same field/null/default/enumeration wire after a Kotlin settings command.
 * All writes still pass through [AtomicJsonRepository], including fsync, backup rotation,
 * checksum validation, read-back, rollback, quarantine, and recovery.
 */
public interface NativeAuthoritativeGameStoreRepository : GameStoreRepository {
    public suspend fun dispatchLegacy(
        before: GameAggregateState,
        envelope: GameCommandEnvelope,
    ): GameDispatchResult
}

private object CSharpPayloadCodec : JsonPayloadCodec<JsonValue.Obj> {
    override fun encodePayload(value: JsonValue.Obj): JsonValue.Obj = value

    override fun decodePayload(value: JsonValue.Obj): JsonValue.Obj = value

    override fun validate(value: JsonValue.Obj) {
        try {
            CSharpSaveCompatibilityCodec.validatePayload(value)
            // A valid outer checksum is not enough if a native career sidecar is damaged.
            // Deep validation lets the atomic repository recover a known-good backup.
            CSharpLegacyAggregateBridge.project(value, 0UL, value.canonicalSha256()).meta.validate()
        } catch (error: LegacySaveCompatibilityException) {
            throw error
        } catch (error: Exception) {
            throw LegacySaveCompatibilityException(error.message ?: "csharp.payload_invalid")
        }
    }
}

/**
 * Raw legacy adapter used only by the production package.  The `.compose.dev` application never
 * constructs this type and therefore cannot reach the production external save directory.
 */
public class CSharpLegacyGameStoreRepository(
    public val directory: Path,
    private val installId: String,
    private val resetSideEffects: ResetSideEffects = NoResetSideEffects,
    faults: SaveFaultInjector = SaveFaultInjector.NONE,
) : NativeAuthoritativeGameStoreRepository {
    private val delegate: KotlinSaveRepository<JsonValue.Obj> = AtomicJsonRepository(
        layout = SaveFileLayout(directory),
        codec = CSharpPayloadCodec,
        faults = faults,
        preserveUnknownEnvelopeFields = true,
    )

    // A durable fresh-state intent lives outside the save files being erased. It is replayed
    // before any load/write so process death can never restore a pre-reset backup.
    private val resetIntent: KotlinSaveRepository<JsonValue.Obj> = AtomicJsonRepository(
        layout = SaveFileLayout(directory.resolve("progress-reset")), codec = CSharpPayloadCodec,
    )

    init {
        require(installId.isNotBlank()) { "game.store.install" }
    }

    /** Typed aggregate writes are prohibited; [dispatchLegacy] is the only production writer. */
    override suspend fun save(value: GameAggregateState, revision: ULong): SaveWriteResult<GameAggregateState> =
        throw SaveRepositoryException(
            SaveFailureCode.WRITE_DISABLED,
            "nativeAuthoritative.typed_save_forbidden",
        )

    override suspend fun load(): SaveLoadResult<GameAggregateState> = withContext(Dispatchers.IO) {
        finishPendingReset()
        project(delegate.load())
    }

    override suspend fun reset(): Unit = withContext(Dispatchers.IO) { delegate.reset(); resetIntent.reset() }

    public suspend fun exportCareer(): ByteArray = withContext(Dispatchers.IO) {
        finishPendingReset()
        val loaded = delegate.load()
        require(loaded.status in setOf(SaveLoadStatus.LOADED_CANONICAL, SaveLoadStatus.RECOVERED_BACKUP)) { "backup.no_save" }
        val saved = requireNotNull(loaded.envelope)
        require(CareerBackup.isAvailable(projectEnvelope(saved).payload)) { "backup.challenge_active" }
        CareerBackup.encode(saved.payload)
    }

    public suspend fun importCareer(bytes: ByteArray, expectedRevision: ULong): GameAggregateState = withContext(Dispatchers.IO) {
        val source = CareerBackup.decode(bytes)
        finishPendingReset()
        val loaded = delegate.load()
        require(loaded.status in setOf(SaveLoadStatus.NO_SAVE, SaveLoadStatus.LOADED_CANONICAL, SaveLoadStatus.RECOVERED_BACKUP)) { "backup.current_save_unavailable" }
        require(loaded.envelope?.let { CareerBackup.isAvailable(projectEnvelope(it).payload) } != false) { "backup.challenge_active" }
        require((loaded.envelope?.revision ?: 0UL) == expectedRevision) { "backup.stale_revision" }
        val sourceRevision = (source["revision"] as? JsonValue.Num)?.raw?.toULongOrNull() ?: error("backup.revision")
        val revision = maxOf(expectedRevision, sourceRevision).checkedIncrement()
        val payload = JsonValue.Obj(LinkedHashMap(source.entries).apply {
            put("installId", JsonValue.Str(installId))
            put("revision", JsonValue.Num(revision.toString()))
        })
        CSharpPayloadCodec.validate(payload)
        projectEnvelope(delegate.save(payload, revision).envelope).payload
    }

    override suspend fun dispatchLegacy(
        before: GameAggregateState,
        envelope: GameCommandEnvelope,
    ): GameDispatchResult = withContext(Dispatchers.IO) {
        try {
            envelope.validate()
        } catch (error: IllegalArgumentException) {
            throw GameCommandException(error.message ?: "game.command.invalid")
        }

        finishPendingReset()
        val loaded = delegate.load()
        val currentEnvelope = when (loaded.status) {
            SaveLoadStatus.NO_SAVE -> null
            SaveLoadStatus.LOADED_CANONICAL,
            SaveLoadStatus.RECOVERED_BACKUP -> requireNotNull(loaded.envelope)
            SaveLoadStatus.FUTURE_VERSION -> throw IllegalStateException("game.store.future_schema")
            SaveLoadStatus.MIGRATION_REQUIRED -> throw IllegalStateException("game.store.migration_required")
            SaveLoadStatus.UNRECOVERABLE_CORRUPTION -> throw IllegalStateException("game.store.unrecoverable")
        }
        val currentRevision = currentEnvelope?.revision ?: 0UL
        if (currentRevision != before.revision) throw GameCommandException("game.command.stale_revision")
        if (envelope.expectedRevision != currentRevision) throw GameCommandException("game.command.stale_revision")

        val currentPayload = currentEnvelope?.payload ?: initialPayload(installId)
        val commandReceipts = currentPayload.stringArray("commandReceipts")
        if (envelope.commandId in commandReceipts) {
            // The C# v1 wire stores command IDs, not command/result hashes.  Replaying a durable
            // ID is therefore safe and idempotent, while a new ID still requires the exact
            // expected revision above.
            return@withContext GameDispatchResult(
                state = currentEnvelope?.let(::projectEnvelope)?.payload ?: before,
                eventHash = GameCommandCodec.resultHash(before, envelope, "legacy.duplicate"),
                duplicate = true,
            )
        }

        if (envelope.command == GameCommand.ResetProgress) {
            val revision = currentRevision.checkedIncrement()
            val fresh = JsonValue.Obj(LinkedHashMap(initialPayload(installId).entries).apply {
                put("revision", JsonValue.Num(revision.toString()))
                put("commandReceipts", JsonValue.Arr(listOf(JsonValue.Str(envelope.commandId))))
            })
            resetIntent.save(fresh, revision)
            val after = projectEnvelope(requireNotNull(finishPendingReset())).payload
            return@withContext GameDispatchResult(after, GameCommandCodec.resultHash(before, envelope, "game.reset"), duplicate = false)
        }

        val applied = try {
            CSharpLegacyAggregateBridge.apply(currentPayload, envelope)
        } catch (error: GameCommandException) {
            throw error
        } catch (error: IllegalArgumentException) {
            throw GameCommandException(error.message ?: "game.command.rejected")
        }
        val nextRevision = currentRevision.checkedIncrement()
        val projected = CSharpLegacyAggregateBridge.project(applied.payload, nextRevision, applied.payload.canonicalSha256())
        val growth = PlayerGrowthReceipt.transition(before, projected, envelope.commandId)
        val nextMeta = LinkedHashMap((applied.payload["meta"] as JsonValue.Obj).entries)
        if (growth == null) nextMeta.remove("playerGrowth") else nextMeta["playerGrowth"] = PlayerGrowthReceipt.encode(growth)
        val companion = PitcherCompanionRules.transition(before, projected)
        if (companion == null) nextMeta.remove("companion") else nextMeta["companion"] = PitcherCompanionCodec.encode(companion)
        val payload = JsonValue.Obj(LinkedHashMap(applied.payload.entries).apply { put("meta", JsonValue.Obj(nextMeta)) })
        val written = delegate.save(payload, nextRevision)
        val after = projectEnvelope(written.envelope).payload
        GameDispatchResult(
            state = after,
            eventHash = GameCommandCodec.resultHash(before, envelope, applied.eventName),
            duplicate = false,
        )
    }

    private fun finishPendingReset(): SaveEnvelope<JsonValue.Obj>? {
        val pending = resetIntent.load()
        if (pending.status == SaveLoadStatus.NO_SAVE) return null
        require(pending.status in setOf(SaveLoadStatus.LOADED_CANONICAL, SaveLoadStatus.RECOVERED_BACKUP)) { "reset.intent_unavailable" }
        val intent = requireNotNull(pending.envelope)
        val fresh = intent.payload
        require(fresh.string("installId") == installId && fresh.string("stage") == GameStage.OPENING.wire &&
            fresh["highSchool"] == JsonValue.Null && fresh["pro"] == JsonValue.Null && fresh.stringArray("commandReceipts").size == 1) { "reset.intent_invalid" }
        delegate.reset()
        val written = delegate.save(fresh, intent.revision).envelope
        resetSideEffects.clearAnalytics()
        resetSideEffects.clearReview()
        resetSideEffects.clearReminders()
        resetSideEffects.clearScopedEpoch()
        resetSideEffects.clearShareCache()
        resetIntent.reset()
        return written
    }

    private fun project(source: SaveLoadResult<JsonValue.Obj>): SaveLoadResult<GameAggregateState> {
        val envelope = source.envelope ?: return SaveLoadResult(
            status = source.status,
            sourcePath = source.sourcePath,
            quarantinedPaths = source.quarantinedPaths,
            diagnostics = source.diagnostics,
        )
        return SaveLoadResult(
            status = source.status,
            envelope = projectEnvelope(envelope),
            sourcePath = source.sourcePath,
            quarantinedPaths = source.quarantinedPaths,
            diagnostics = source.diagnostics,
        )
    }

    private fun projectEnvelope(envelope: SaveEnvelope<JsonValue.Obj>): SaveEnvelope<GameAggregateState> {
        val payload = envelope.payload
        val payloadInstallId = payload.string("installId")
        if (payloadInstallId != installId) throw IllegalStateException("game.store.install_mismatch")
        val state = CSharpLegacyAggregateBridge.project(payload, envelope.revision, envelope.payloadSha256)
        return SaveEnvelope(
            schema = envelope.schema,
            schemaVersion = envelope.schemaVersion,
            revision = envelope.revision,
            writtenAtUtc = envelope.writtenAtUtc,
            payloadSha256 = envelope.payloadSha256,
            payload = state,
            payloadTree = envelope.payloadTree,
            extraRootFields = envelope.extraRootFields,
        )
    }

    private fun initialPayload(installId: String): JsonValue.Obj = JsonValue.Obj(linkedMapOf(
        "aggregateVersion" to JsonValue.Num(GameAggregateState.CURRENT_AGGREGATE_VERSION.toString()),
        "revision" to JsonValue.Num("0"),
        "installId" to JsonValue.Str(installId),
        "stage" to JsonValue.Str(GameStage.OPENING.wire),
        "highSchool" to JsonValue.Null,
        "pro" to JsonValue.Null,
        "meta" to JsonValue.Obj(linkedMapOf()),
        "pitchResume" to JsonValue.Null,
        "pendingPitchCompletion" to JsonValue.Null,
        "settings" to defaultSettings(),
        "analyticsReceipts" to JsonValue.Obj(linkedMapOf(
            "schemaVersion" to JsonValue.Num("1"),
            "records" to JsonValue.Arr(emptyList()),
        )),
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

    private fun JsonValue.Obj.string(name: String): String =
        (this[name] as? JsonValue.Str)?.value ?: throw IllegalStateException("game.store.${name}_missing")
    private fun ULong.checkedIncrement(): ULong =
        if (this == ULong.MAX_VALUE) throw SaveRepositoryException(SaveFailureCode.REVISION_REGRESSION, "save.revision_exhausted") else this + 1UL
}
