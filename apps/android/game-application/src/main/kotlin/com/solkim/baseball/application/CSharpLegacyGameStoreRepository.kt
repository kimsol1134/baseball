package com.solkim.baseball.application

import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.Hashing
import com.solkim.baseball.persistence.AtomicJsonRepository
import com.solkim.baseball.persistence.JsonPayloadCodec
import com.solkim.baseball.persistence.KotlinSaveRepository
import com.solkim.baseball.persistence.KotlinSaveContract
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

        val nextPayload = when (val command = envelope.command) {
            is GameCommand.UpdateSettings -> currentPayload.withSettings(command.settings, envelope.commandId)
            else -> throw GameCommandException("nativeAuthoritative.legacy_command_not_ported")
        }
        val nextRevision = currentRevision.checkedIncrement()
        val written = delegate.save(nextPayload, nextRevision)
        val after = projectEnvelope(written.envelope).payload
        GameDispatchResult(
            state = after,
            eventHash = GameCommandCodec.resultHash(before, envelope, "legacy.settings.updated"),
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
        val state = GameAggregateState(
            aggregateVersion = payload.intOrDefault("aggregateVersion", GameAggregateState.CURRENT_AGGREGATE_VERSION),
            revision = envelope.revision,
            installId = installId,
            stage = GameStage.entries.firstOrNull { it.wire == payload.string("stage") }
                ?: throw IllegalStateException("game.store.stage_unknown"),
            meta = GameMetaState(
                completedGameCount = payload.objectOrNull("meta")?.ulongOrDefault("completedGameCount", 0UL) ?: 0UL,
            ),
            settings = payload.objectOrNull("settings")?.toSettings() ?: GameSettingsState(),
            deleted = payload.boolOrDefault("deleted", false),
            // The typed commitment is not a legacy field.  This stable projection value lets the
            // Kotlin command hash and rollback evidence bind to the exact canonical payload.
            commitment = envelope.payloadSha256,
        )
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

    private fun JsonValue.Obj.withSettings(settings: GameSettingsState, commandId: String): JsonValue.Obj {
        val next = LinkedHashMap(entries)
        next["revision"] = JsonValue.Num((ulong("revision") + 1UL).toString())
        next["settings"] = JsonValue.Obj(linkedMapOf(
            "schemaVersion" to JsonValue.Num("1"),
            "autoReleaseEnabled" to JsonValue.Bool(settings.autoReleaseEnabled),
            "soundEnabled" to JsonValue.Bool(settings.soundEnabled),
            "musicEnabled" to JsonValue.Bool(settings.musicEnabled),
            "hapticsEnabled" to JsonValue.Bool(settings.hapticsEnabled),
            "notificationsEnabled" to JsonValue.Bool(settings.notificationsEnabled),
            "highContrastEnabled" to JsonValue.Bool(settings.highContrastEnabled),
            "reducedMotionEnabled" to JsonValue.Bool(settings.reducedMotionEnabled),
        ))
        val receipts = stringArray("commandReceipts").toMutableSet()
        receipts += commandId
        next["commandReceipts"] = JsonValue.Arr(receipts.toList().sorted().map(JsonValue::Str))
        return JsonValue.Obj(next)
    }

    private fun JsonValue.Obj.toSettings(): GameSettingsState = GameSettingsState(
        autoReleaseEnabled = boolOrDefault("autoReleaseEnabled", false),
        soundEnabled = boolOrDefault("soundEnabled", true),
        musicEnabled = boolOrDefault("musicEnabled", true),
        hapticsEnabled = boolOrDefault("hapticsEnabled", true),
        notificationsEnabled = boolOrDefault("notificationsEnabled", false),
        highContrastEnabled = boolOrDefault("highContrastEnabled", false),
        reducedMotionEnabled = boolOrDefault("reducedMotionEnabled", false),
    )

    private fun JsonValue.Obj.objectOrNull(name: String): JsonValue.Obj? = this[name] as? JsonValue.Obj
    private fun JsonValue.Obj.string(name: String): String =
        (this[name] as? JsonValue.Str)?.value ?: throw IllegalStateException("game.store.${name}_missing")
    private fun JsonValue.Obj.intOrDefault(name: String, default: Int): Int =
        (this[name] as? JsonValue.Num)?.raw?.toIntOrNull() ?: default
    private fun JsonValue.Obj.ulong(name: String): ULong =
        when (val value = this[name]) {
            is JsonValue.Num -> value.raw.toULongOrNull() ?: 0UL
            is JsonValue.Str -> value.value.toULongOrNull() ?: 0UL
            else -> 0UL
        }
    private fun JsonValue.Obj.ulongOrDefault(name: String, default: ULong): ULong =
        when (val value = this[name]) {
            is JsonValue.Num -> value.raw.toULongOrNull() ?: default
            is JsonValue.Str -> value.value.toULongOrNull() ?: default
            else -> default
        }
    private fun JsonValue.Obj.boolOrDefault(name: String, default: Boolean): Boolean =
        (this[name] as? JsonValue.Bool)?.value ?: default
    private fun JsonValue.Obj.stringArray(name: String): List<String> =
        (this[name] as? JsonValue.Arr)?.values?.mapNotNull { (it as? JsonValue.Str)?.value } ?: emptyList()
    private fun ULong.checkedIncrement(): ULong =
        if (this == ULong.MAX_VALUE) throw SaveRepositoryException(SaveFailureCode.REVISION_REGRESSION, "save.revision_exhausted") else this + 1UL
}
