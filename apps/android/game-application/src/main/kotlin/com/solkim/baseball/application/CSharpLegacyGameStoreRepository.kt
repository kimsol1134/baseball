package com.solkim.baseball.application

import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.persistence.AtomicJsonRepository
import com.solkim.baseball.persistence.JsonPayloadCodec
import com.solkim.baseball.persistence.KotlinSaveRepository
import com.solkim.baseball.persistence.LegacySaveCompatibilityException
import com.solkim.baseball.persistence.SaveEnvelope
import com.solkim.baseball.persistence.SaveFailureCode
import com.solkim.baseball.persistence.SaveFileLayout
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
) : NativeAuthoritativeGameStoreRepository {
    private val delegate: KotlinSaveRepository<JsonValue.Obj> = AtomicJsonRepository(
        layout = SaveFileLayout(directory),
        codec = CSharpPayloadCodec,
        preserveUnknownEnvelopeFields = true,
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
        project(delegate.load())
    }

    override suspend fun reset(): Unit = withContext(Dispatchers.IO) { delegate.reset() }

    override suspend fun dispatchLegacy(
        before: GameAggregateState,
        envelope: GameCommandEnvelope,
    ): GameDispatchResult = withContext(Dispatchers.IO) {
        try {
            envelope.validate()
        } catch (error: IllegalArgumentException) {
            throw GameCommandException(error.message ?: "game.command.invalid")
        }

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

        val applied = try {
            CSharpLegacyAggregateBridge.apply(currentPayload, envelope)
        } catch (error: GameCommandException) {
            throw error
        } catch (error: IllegalArgumentException) {
            throw GameCommandException(error.message ?: "game.command.rejected")
        }
        val nextRevision = currentRevision.checkedIncrement()
        val written = delegate.save(applied.payload, nextRevision)
        val after = projectEnvelope(written.envelope).payload
        GameDispatchResult(
            state = after,
            eventHash = GameCommandCodec.resultHash(before, envelope, applied.eventName),
            duplicate = false,
        )
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
