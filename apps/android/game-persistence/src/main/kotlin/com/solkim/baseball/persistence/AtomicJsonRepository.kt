package com.solkim.baseball.persistence

import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import com.solkim.baseball.model.Hashing
import com.solkim.baseball.model.canonicalSha256
import java.io.IOException
import java.nio.channels.FileChannel
import java.nio.file.AtomicMoveNotSupportedException
import java.nio.file.DirectoryStream
import java.nio.file.Files
import java.nio.file.LinkOption
import java.nio.file.Path
import java.nio.file.StandardCopyOption
import java.nio.file.StandardOpenOption
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

public object KotlinSaveContract {
    public const val SCHEMA: String = "android-unity-save-v1"
    public const val SCHEMA_VERSION: Int = 1
    public const val BACKUP_COUNT: Int = 3
    public const val MAX_BYTES: Int = 4 * 1024 * 1024
    public const val MAX_DEPTH: Int = 128

    internal val timestampFormatter: DateTimeFormatter = DateTimeFormatter
        .ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
        .withZone(ZoneOffset.UTC)
    internal val revisionPattern: Regex = Regex("0|[1-9][0-9]*")
    internal val timestampPattern: Regex = Regex("\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}Z")
    internal val sha256Pattern: Regex = Regex("[0-9a-f]{64}")
}

public data class SaveFileLayout(public val directory: Path) {
    init {
        require(directory.toString().isNotBlank()) { "save.directory" }
    }

    public val canonical: Path = directory.resolve("save.json")
    public val temporary: Path = directory.resolve("save.tmp")
    public val rollbackTemporary: Path = directory.resolve("save.tmp.rollback")

    public fun backup(position: Int): Path {
        require(position in 1..KotlinSaveContract.BACKUP_COUNT) { "save.backup_position" }
        return directory.resolve("save.bak.$position")
    }

    public fun quarantine(origin: String, nowUtcMillis: Long, collision: Int = 0): Path {
        val timestamp = KotlinSaveContract.timestampFormatter.format(Instant.ofEpochMilli(nowUtcMillis))
        val safeOrigin = origin.ifBlank { "unknown" }.replace('.', '-')
        val suffix = if (collision == 0) "" else ".${collision}"
        return directory.resolve("save.corrupt.${timestamp.replace(':', '-')}.${safeOrigin}${suffix}.json")
    }
}

public enum class SaveLoadStatus {
    NO_SAVE,
    LOADED_CANONICAL,
    RECOVERED_BACKUP,
    UNRECOVERABLE_CORRUPTION,
    FUTURE_VERSION,
    MIGRATION_REQUIRED,
}

public sealed interface SaveDecodeResult<out T> {
    public data class Valid<T>(public val envelope: SaveEnvelope<T>) : SaveDecodeResult<T>
    public data class Future(public val schemaVersion: Int, public val raw: ByteArray) : SaveDecodeResult<Nothing>
    public data class Older(public val schemaVersion: Int, public val raw: ByteArray) : SaveDecodeResult<Nothing>
    public data class Invalid(public val reason: String) : SaveDecodeResult<Nothing>
}

public data class SaveEnvelope<T>(
    public val schema: String,
    public val schemaVersion: Int,
    public val revision: ULong,
    public val writtenAtUtc: String,
    public val payloadSha256: String,
    public val payload: T,
    public val payloadTree: JsonValue.Obj,
    /**
     * Legacy C# Newtonsoft saves are allowed to carry additive envelope fields.  The typed
     * Kotlin aggregate remains exact by default; the compatibility repository opts into retaining
     * these fields so a native settings write cannot silently erase a future/legacy extension.
    */
    public val extraRootFields: Map<String, JsonValue> = emptyMap(),
) {
    public val rootTree: JsonValue.Obj
        get() = JsonValue.Obj(LinkedHashMap<String, JsonValue>().apply {
            putAll(extraRootFields)
            put("schema", JsonValue.Str(schema))
            put("schemaVersion", JsonValue.Num(schemaVersion.toString()))
            put("revision", JsonValue.Str(revision.toString()))
            put("writtenAtUtc", JsonValue.Str(writtenAtUtc))
            put("payloadSha256", JsonValue.Str(payloadSha256))
            put("payload", payloadTree)
        })

    public val canonicalBytes: ByteArray
        get() = StrictJson.canonical(rootTree).toByteArray(Charsets.UTF_8)
}

public data class SaveLoadResult<T>(
    public val status: SaveLoadStatus,
    public val envelope: SaveEnvelope<T>? = null,
    public val sourcePath: Path? = null,
    public val quarantinedPaths: List<Path> = emptyList(),
    public val diagnostics: List<String> = emptyList(),
)

public data class SaveWriteResult<T>(
    public val envelope: SaveEnvelope<T>,
    public val path: Path,
    public val idempotent: Boolean = false,
)

public interface JsonPayloadCodec<T> {
    public fun encodePayload(value: T): JsonValue.Obj
    public fun decodePayload(value: JsonValue.Obj): T
    public fun validate(value: T)
}

public interface SaveClock {
    public fun nowUtcMillis(): Long
}

public object SystemSaveClock : SaveClock {
    override fun nowUtcMillis(): Long = System.currentTimeMillis()
}

public enum class SaveFaultPoint {
    BEFORE_CANDIDATE_VALIDATION,
    AFTER_CANDIDATE_VALIDATION,
    AFTER_TEMP_WRITE,
    AFTER_TEMP_VALIDATION,
    AFTER_BACKUP_3,
    AFTER_BACKUP_2,
    AFTER_BACKUP_1,
    AFTER_BACKUP_ROTATION,
    BEFORE_CANONICAL_SWAP,
    AFTER_CANONICAL_SWAP,
    BEFORE_CANONICAL_VERIFICATION,
    AFTER_CANONICAL_VERIFICATION,
    BEFORE_READ_BACK,
    AFTER_READ_BACK,
    RESET_BEFORE_TEMP,
    RESET_AFTER_BACKUPS,
    RESET_BEFORE_CANONICAL,
    RESET_AFTER_CANONICAL,
}

public fun interface SaveFaultInjector {
    public fun checkpoint(point: SaveFaultPoint)

    public companion object {
        public val NONE: SaveFaultInjector = SaveFaultInjector { }
    }
}

public class SaveRepositoryException(
    public val code: SaveFailureCode,
    message: String,
    cause: Throwable? = null,
) : IllegalStateException(message, cause)

public enum class SaveFailureCode {
    SERIALIZATION_FAILED,
    CANDIDATE_INVALID,
    REVISION_REGRESSION,
    REVISION_CONFLICT,
    FUTURE_VERSION_WOULD_BE_OVERWRITTEN,
    MIGRATION_REQUIRED,
    VERIFICATION_FAILED,
    IO_FAILED,
    WRITE_DISABLED,
}

public interface KotlinSaveRepository<T> {
    public fun save(value: T, revision: ULong): SaveWriteResult<T>
    public fun load(): SaveLoadResult<T>
    public fun reset()
}

public class ReadOnlySaveRepository<T>(
    private val delegate: KotlinSaveRepository<T>,
) : KotlinSaveRepository<T> {
    override fun save(value: T, revision: ULong): SaveWriteResult<T> =
        throw SaveRepositoryException(SaveFailureCode.WRITE_DISABLED, "nativeShadowReadOnly.save_disabled")

    override fun load(): SaveLoadResult<T> = delegate.load()

    override fun reset(): Unit =
        throw SaveRepositoryException(SaveFailureCode.WRITE_DISABLED, "nativeShadowReadOnly.reset_disabled")
}

/**
 * Kotlin port of the C# AtomicSaveRepository. The repository publishes no application state;
 * callers must perform their state swap only after [save] returns its verified read-back.
 */
public class AtomicJsonRepository<T>(
    private val layout: SaveFileLayout,
    private val codec: JsonPayloadCodec<T>,
    private val clock: SaveClock = SystemSaveClock,
    private val faults: SaveFaultInjector = SaveFaultInjector.NONE,
    private val fileSystem: KotlinSaveFileSystem = NioKotlinSaveFileSystem,
    private val semanticPriority: (T) -> Int = { 0 },
    private val preserveUnknownEnvelopeFields: Boolean = false,
) : KotlinSaveRepository<T> {
    private val envelopeFields = setOf("schema", "schemaVersion", "revision", "writtenAtUtc", "payloadSha256", "payload")

    override fun save(value: T, revision: ULong): SaveWriteResult<T> {
        var canonicalExisted = false
        var originalCanonicalBytes: ByteArray? = null
        var canonicalSwapAttempted = false
        try {
            faults.checkpoint(SaveFaultPoint.BEFORE_CANDIDATE_VALIDATION)
            codec.validate(value)
            val payload = codec.encodePayload(value)
            val payloadHash = payload.canonicalSha256()
            val writtenAt = KotlinSaveContract.timestampFormatter.format(Instant.ofEpochMilli(clock.nowUtcMillis()))
            fileSystem.createDirectory(layout.directory)
            canonicalExisted = fileSystem.exists(layout.canonical)
            originalCanonicalBytes = if (canonicalExisted) fileSystem.read(layout.canonical) else null

            val current = if (fileSystem.exists(layout.canonical)) decodePath(layout.canonical) else null
            when (current) {
                is SaveDecodeResult.Future -> throw SaveRepositoryException(
                    SaveFailureCode.FUTURE_VERSION_WOULD_BE_OVERWRITTEN,
                    "save.future_schema_would_be_overwritten",
                )
                is SaveDecodeResult.Older -> throw SaveRepositoryException(
                    SaveFailureCode.MIGRATION_REQUIRED,
                    "save.older_schema_requires_migration",
                )
                is SaveDecodeResult.Valid -> {
                    if (revision < current.envelope.revision) {
                        throw SaveRepositoryException(SaveFailureCode.REVISION_REGRESSION, "save.revision_regression")
                    }
                    if (revision == current.envelope.revision) {
                        if (payloadHash != current.envelope.payloadSha256) {
                            throw SaveRepositoryException(SaveFailureCode.REVISION_CONFLICT, "save.revision_conflict")
                        }
                        return SaveWriteResult(current.envelope, layout.canonical, idempotent = true)
                    }
                }
                is SaveDecodeResult.Invalid -> Unit
                null -> Unit
            }

            // A raw legacy repository carries unknown envelope fields forward. Typed repositories
            // keep the historical exact-envelope behavior by leaving this map empty.
            val preservedRootFields = if (preserveUnknownEnvelopeFields) {
                (current as? SaveDecodeResult.Valid<T>)?.envelope?.extraRootFields.orEmpty()
            } else {
                emptyMap()
            }
            val candidate = SaveEnvelope(
                schema = KotlinSaveContract.SCHEMA,
                schemaVersion = KotlinSaveContract.SCHEMA_VERSION,
                revision = revision,
                writtenAtUtc = writtenAt,
                payloadSha256 = payloadHash,
                payload = value,
                payloadTree = payload,
                extraRootFields = preservedRootFields,
            )
            val candidateBytes = candidate.canonicalBytes
            faults.checkpoint(SaveFaultPoint.AFTER_CANDIDATE_VALIDATION)

            fileSystem.deleteIfExists(layout.temporary)
            fileSystem.writeAndSync(layout.temporary, candidateBytes)
            faults.checkpoint(SaveFaultPoint.AFTER_TEMP_WRITE)
            requireSame(decodePath(layout.temporary), candidate, "temp")
            faults.checkpoint(SaveFaultPoint.AFTER_TEMP_VALIDATION)

            if (current is SaveDecodeResult.Valid) {
                rotateBackups()
            } else if (fileSystem.exists(layout.canonical)) {
                quarantine(layout.canonical, "canonical")
            }
            faults.checkpoint(SaveFaultPoint.AFTER_BACKUP_ROTATION)
            faults.checkpoint(SaveFaultPoint.BEFORE_CANONICAL_SWAP)
            canonicalSwapAttempted = true
            fileSystem.moveReplace(layout.temporary, layout.canonical)
            faults.checkpoint(SaveFaultPoint.AFTER_CANONICAL_SWAP)
            faults.checkpoint(SaveFaultPoint.BEFORE_CANONICAL_VERIFICATION)
            faults.checkpoint(SaveFaultPoint.BEFORE_READ_BACK)
            val committed = decodePath(layout.canonical)
            requireSame(committed, candidate, "canonical")
            faults.checkpoint(SaveFaultPoint.AFTER_CANONICAL_VERIFICATION)
            faults.checkpoint(SaveFaultPoint.AFTER_READ_BACK)
            return SaveWriteResult((committed as SaveDecodeResult.Valid).envelope, layout.canonical)
        } catch (error: SaveRepositoryException) {
            val rollbackError = rollbackAfterFailedSwap(canonicalSwapAttempted, canonicalExisted, originalCanonicalBytes)
            fileSystem.deleteQuietly(layout.temporary)
            fileSystem.deleteQuietly(layout.rollbackTemporary)
            if (rollbackError != null) throw SaveRepositoryException(SaveFailureCode.VERIFICATION_FAILED, "save.rollback_failed", rollbackError)
            throw error
        } catch (error: Exception) {
            val rollbackError = rollbackAfterFailedSwap(canonicalSwapAttempted, canonicalExisted, originalCanonicalBytes)
            fileSystem.deleteQuietly(layout.temporary)
            fileSystem.deleteQuietly(layout.rollbackTemporary)
            if (rollbackError != null) throw SaveRepositoryException(SaveFailureCode.VERIFICATION_FAILED, "save.rollback_failed", rollbackError)
            throw SaveRepositoryException(SaveFailureCode.IO_FAILED, "save.io_failed", error)
        }
    }

    override fun load(): SaveLoadResult<T> {
        fileSystem.createDirectory(layout.directory)
        val diagnostics = mutableListOf<String>()
        val canonical = located(layout.canonical, "canonical", diagnostics)
        if (canonical?.decode is SaveDecodeResult.Valid) {
            return SaveLoadResult(SaveLoadStatus.LOADED_CANONICAL, (canonical.decode as SaveDecodeResult.Valid).envelope, canonical.path, diagnostics = diagnostics)
        }
        if (canonical?.decode is SaveDecodeResult.Future) {
            return SaveLoadResult(SaveLoadStatus.FUTURE_VERSION, sourcePath = canonical.path, diagnostics = diagnostics)
        }
        if (canonical?.decode is SaveDecodeResult.Older) {
            return SaveLoadResult(SaveLoadStatus.MIGRATION_REQUIRED, sourcePath = canonical.path, diagnostics = diagnostics)
        }

        val backups = (1..KotlinSaveContract.BACKUP_COUNT).mapNotNull { position ->
            located(layout.backup(position), "bak$position", diagnostics)
        }
        val validBackup = backups
            .mapNotNull { located ->
                val valid = located.decode as? SaveDecodeResult.Valid<T> ?: return@mapNotNull null
                located to valid.envelope
            }
            .maxWithOrNull(compareBy<Pair<Located<T>, SaveEnvelope<T>>> { it.second.revision }
                .thenBy { semanticPriority(it.second.payload) }
                .thenBy { -it.first.rank })
        if (validBackup != null) {
            val quarantined = if (canonical?.decode is SaveDecodeResult.Invalid) listOf(quarantine(canonical.path, "canonical")) else emptyList()
            installRecovered(validBackup.second.canonicalBytes)
            val restored = decodePath(layout.canonical)
            requireSame(restored, validBackup.second, "recovered canonical")
            return SaveLoadResult(
                SaveLoadStatus.RECOVERED_BACKUP,
                (restored as SaveDecodeResult.Valid).envelope,
                validBackup.first.path,
                quarantined,
                diagnostics,
            )
        }

        val all = listOfNotNull(canonical) + backups
        all.firstOrNull { it.decode is SaveDecodeResult.Future }?.let {
            return SaveLoadResult(SaveLoadStatus.FUTURE_VERSION, sourcePath = it.path, diagnostics = diagnostics)
        }
        all.firstOrNull { it.decode is SaveDecodeResult.Older }?.let {
            return SaveLoadResult(SaveLoadStatus.MIGRATION_REQUIRED, sourcePath = it.path, diagnostics = diagnostics)
        }
        if (all.isEmpty()) return SaveLoadResult(SaveLoadStatus.NO_SAVE, diagnostics = diagnostics)
        val quarantined = all.filter { it.decode is SaveDecodeResult.Invalid }.map { quarantine(it.path, it.origin) }
        return SaveLoadResult(SaveLoadStatus.UNRECOVERABLE_CORRUPTION, quarantinedPaths = quarantined, diagnostics = diagnostics)
    }

    override fun reset() {
        try {
            faults.checkpoint(SaveFaultPoint.RESET_BEFORE_TEMP)
            fileSystem.deleteIfExists(layout.temporary)
            fileSystem.deleteIfExists(layout.rollbackTemporary)
            faults.checkpoint(SaveFaultPoint.RESET_AFTER_BACKUPS)
            for (position in KotlinSaveContract.BACKUP_COUNT downTo 1) fileSystem.deleteIfExists(layout.backup(position))
            fileSystem.list(layout.directory, "save.corrupt.*.json").forEach(fileSystem::deleteIfExists)
            faults.checkpoint(SaveFaultPoint.RESET_BEFORE_CANONICAL)
            fileSystem.deleteIfExists(layout.canonical)
            faults.checkpoint(SaveFaultPoint.RESET_AFTER_CANONICAL)
            check(!fileSystem.exists(layout.canonical) && !fileSystem.exists(layout.temporary)) { "save.reset_verification" }
        } catch (error: SaveRepositoryException) {
            throw error
        } catch (error: Exception) {
            throw SaveRepositoryException(SaveFailureCode.IO_FAILED, "save.reset_failed", error)
        }
    }

    private fun rotateBackups() {
        if (fileSystem.exists(layout.backup(2))) {
            fileSystem.copyReplace(layout.backup(2), layout.backup(3))
            faults.checkpoint(SaveFaultPoint.AFTER_BACKUP_3)
        }
        if (fileSystem.exists(layout.backup(1))) {
            fileSystem.copyReplace(layout.backup(1), layout.backup(2))
            faults.checkpoint(SaveFaultPoint.AFTER_BACKUP_2)
        }
        fileSystem.copyReplace(layout.canonical, layout.backup(1))
        faults.checkpoint(SaveFaultPoint.AFTER_BACKUP_1)
    }

    private fun installRecovered(bytes: ByteArray) {
        fileSystem.deleteIfExists(layout.temporary)
        fileSystem.writeAndSync(layout.temporary, bytes)
        requireSame(decodePath(layout.temporary), decodePathBytes(bytes), "recovery temp")
        fileSystem.moveReplace(layout.temporary, layout.canonical)
    }

    private fun rollbackAfterFailedSwap(
        canonicalSwapAttempted: Boolean,
        canonicalExisted: Boolean,
        originalCanonicalBytes: ByteArray?,
    ): Throwable? {
        if (!canonicalSwapAttempted) return null
        return runCatching {
            if (!canonicalExisted) {
                fileSystem.deleteIfExists(layout.canonical)
            } else {
                val original = requireNotNull(originalCanonicalBytes) { "save.rollback_original_missing" }
                fileSystem.deleteIfExists(layout.rollbackTemporary)
                fileSystem.writeAndSync(layout.rollbackTemporary, original)
                fileSystem.moveReplace(layout.rollbackTemporary, layout.canonical)
                check(fileSystem.read(layout.canonical).contentEquals(original)) { "save.rollback_verification" }
            }
        }.exceptionOrNull()
    }

    private fun quarantine(path: Path, origin: String): Path {
        var collision = 0
        var destination = layout.quarantine(origin, clock.nowUtcMillis(), collision)
        while (fileSystem.exists(destination)) {
            collision += 1
            destination = layout.quarantine(origin, clock.nowUtcMillis(), collision)
        }
        fileSystem.moveReplace(path, destination)
        return destination
    }

    private fun decodePath(path: Path): SaveDecodeResult<T> = decodeBytes(fileSystem.read(path))

    private fun decodePathBytes(bytes: ByteArray): SaveDecodeResult<T> = decodeBytes(bytes)

    private fun decodeBytes(bytes: ByteArray): SaveDecodeResult<T> {
        if (bytes.isEmpty()) return SaveDecodeResult.Invalid("file.empty")
        if (bytes.size > KotlinSaveContract.MAX_BYTES) return SaveDecodeResult.Invalid("file.too_large")
        val root = try { StrictJson.parseUtf8(bytes, KotlinSaveContract.MAX_DEPTH) as? JsonValue.Obj ?: return SaveDecodeResult.Invalid("root.object") }
        catch (error: Exception) { return SaveDecodeResult.Invalid("json.invalid:${error.javaClass.simpleName}") }
        val unknown = root.entries.keys - envelopeFields
        if (unknown.isNotEmpty() && !preserveUnknownEnvelopeFields) {
            return SaveDecodeResult.Invalid("root.unknown:${unknown.sorted().joinToString(",")}")
        }
        val schema = (root["schema"] as? JsonValue.Str)?.value ?: return SaveDecodeResult.Invalid("schema.invalid")
        if (schema != KotlinSaveContract.SCHEMA) return SaveDecodeResult.Invalid("schema.unknown")
        val version = (root["schemaVersion"] as? JsonValue.Num)?.raw?.toIntOrNull() ?: return SaveDecodeResult.Invalid("schemaVersion.invalid")
        if (version > KotlinSaveContract.SCHEMA_VERSION) return SaveDecodeResult.Future(version, bytes)
        if (version < KotlinSaveContract.SCHEMA_VERSION) return SaveDecodeResult.Older(version, bytes)
        return try {
            val revisionText = (root["revision"] as? JsonValue.Str)?.value ?: throw SaveRepositoryException(SaveFailureCode.CANDIDATE_INVALID, "revision.invalid")
            if (!KotlinSaveContract.revisionPattern.matches(revisionText)) throw SaveRepositoryException(SaveFailureCode.CANDIDATE_INVALID, "revision.invalid")
            val revision = revisionText.toULongOrNull() ?: throw SaveRepositoryException(SaveFailureCode.CANDIDATE_INVALID, "revision.bounds")
            val writtenAt = (root["writtenAtUtc"] as? JsonValue.Str)?.value ?: throw SaveRepositoryException(SaveFailureCode.CANDIDATE_INVALID, "writtenAtUtc.invalid")
            if (!KotlinSaveContract.timestampPattern.matches(writtenAt)) throw SaveRepositoryException(SaveFailureCode.CANDIDATE_INVALID, "writtenAtUtc.invalid")
            Instant.parse(writtenAt)
            val payload = root["payload"] as? JsonValue.Obj ?: throw SaveRepositoryException(SaveFailureCode.CANDIDATE_INVALID, "payload.object_required")
            val declaredHash = (root["payloadSha256"] as? JsonValue.Str)?.value ?: throw SaveRepositoryException(SaveFailureCode.CANDIDATE_INVALID, "payloadSha256.invalid")
            if (!KotlinSaveContract.sha256Pattern.matches(declaredHash)) throw SaveRepositoryException(SaveFailureCode.CANDIDATE_INVALID, "payloadSha256.invalid")
            val actualHash = payload.canonicalSha256()
            if (declaredHash != actualHash) throw SaveRepositoryException(SaveFailureCode.CANDIDATE_INVALID, "payloadSha256.mismatch")
            val decoded = codec.decodePayload(payload)
            codec.validate(decoded)
            val extraRootFields = if (preserveUnknownEnvelopeFields) {
                root.entries.filterKeys { it !in envelopeFields }
            } else {
                emptyMap()
            }
            SaveDecodeResult.Valid(SaveEnvelope(schema, version, revision, writtenAt, actualHash, decoded, payload, extraRootFields))
        } catch (error: SaveRepositoryException) {
            SaveDecodeResult.Invalid(error.message ?: "save.invalid")
        } catch (error: Exception) {
            SaveDecodeResult.Invalid("payload.invalid:${error.javaClass.simpleName}")
        }
    }

    private fun requireSame(actual: SaveDecodeResult<T>, expected: SaveEnvelope<T>, location: String) {
        val valid = actual as? SaveDecodeResult.Valid ?: throw SaveRepositoryException(SaveFailureCode.VERIFICATION_FAILED, "save.$location.invalid")
        if (valid.envelope.revision != expected.revision || valid.envelope.payloadSha256 != expected.payloadSha256) {
            throw SaveRepositoryException(SaveFailureCode.VERIFICATION_FAILED, "save.$location.mismatch")
        }
    }

    private fun requireSame(actual: SaveDecodeResult<T>, expected: SaveDecodeResult<T>, location: String) {
        val left = actual as? SaveDecodeResult.Valid ?: throw SaveRepositoryException(SaveFailureCode.VERIFICATION_FAILED, "save.$location.invalid")
        val right = expected as? SaveDecodeResult.Valid ?: throw SaveRepositoryException(SaveFailureCode.VERIFICATION_FAILED, "save.$location.expected_invalid")
        requireSame(left, right.envelope, location)
    }

    private data class Located<T>(val path: Path, val origin: String, val rank: Int, val decode: SaveDecodeResult<T>)

    private fun located(path: Path, origin: String, diagnostics: MutableList<String>): Located<T>? {
        if (!fileSystem.exists(path)) return null
        val decoded = try { decodePath(path) } catch (error: Exception) { SaveDecodeResult.Invalid("read:${error.javaClass.simpleName}") }
        if (decoded is SaveDecodeResult.Invalid) diagnostics += "$origin:${decoded.reason}"
        return Located(path, origin, if (origin == "canonical") 0 else origin.removePrefix("bak").toIntOrNull() ?: 99, decoded)
    }
}

public interface KotlinSaveFileSystem {
    public fun createDirectory(directory: Path)
    public fun exists(path: Path): Boolean
    public fun read(path: Path): ByteArray
    public fun writeAndSync(path: Path, bytes: ByteArray)
    public fun copyReplace(source: Path, target: Path)
    public fun moveReplace(source: Path, target: Path)
    public fun deleteIfExists(path: Path)
    public fun deleteQuietly(path: Path)
    public fun list(directory: Path, glob: String): List<Path>
}

public object NioKotlinSaveFileSystem : KotlinSaveFileSystem {
    override fun createDirectory(directory: Path) { Files.createDirectories(directory) }
    override fun exists(path: Path): Boolean = Files.exists(path, LinkOption.NOFOLLOW_LINKS)
    override fun read(path: Path): ByteArray = Files.readAllBytes(path)

    override fun writeAndSync(path: Path, bytes: ByteArray) {
        createDirectory(path.parent)
        FileChannel.open(path, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING, StandardOpenOption.WRITE).use { channel ->
            var offset = 0
            while (offset < bytes.size) offset += channel.write(java.nio.ByteBuffer.wrap(bytes, offset, bytes.size - offset))
            channel.force(true)
        }
        syncDirectory(path.parent)
    }

    override fun copyReplace(source: Path, target: Path) {
        createDirectory(target.parent)
        // Android app-private files already inherit the directory SELinux label. Copying
        // POSIX/extended attributes across replacement backups asks the emulator's policy to
        // relabel save.bak.* and produces relabelfrom denials without improving durability.
        // The bytes are verified by the repository after every rotation, so copy data only.
        Files.copy(source, target, StandardCopyOption.REPLACE_EXISTING)
        syncDirectory(target.parent)
    }

    override fun moveReplace(source: Path, target: Path) {
        createDirectory(target.parent)
        try {
            Files.move(source, target, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
        } catch (_: AtomicMoveNotSupportedException) {
            Files.move(source, target, StandardCopyOption.REPLACE_EXISTING)
        }
        syncDirectory(target.parent)
    }

    override fun deleteIfExists(path: Path) { Files.deleteIfExists(path) }
    override fun deleteQuietly(path: Path) { try { deleteIfExists(path) } catch (_: Exception) { } }

    override fun list(directory: Path, glob: String): List<Path> {
        if (!exists(directory)) return emptyList()
        Files.newDirectoryStream(directory, glob).use { stream: DirectoryStream<Path> -> return stream.toList() }
    }

    private fun syncDirectory(directory: Path?) {
        if (directory == null) return
        try {
            FileChannel.open(directory, StandardOpenOption.READ).use { it.force(true) }
        } catch (_: IOException) {
            // Android filesystems may reject directory fsync while still guaranteeing the file
            // fsync above. The read-back verification remains mandatory.
        }
    }
}
