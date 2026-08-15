package com.solkim.baseball.persistence

import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import java.nio.file.Path
import java.time.Instant

public object ResetJournalContract {
    public const val SCHEMA: String = "baseball-reset-journal-v1"
    public const val VERSION: Int = 1
}

public enum class ResetStep(public val wire: String, public val order: Int) {
    INTENT("intent", 0),
    REPOSITORY_RESET("repositoryReset", 1),
    CANDIDATE_IDENTITY_PUBLISHED("candidateIdentityPublished", 2),
    ANALYTICS_CLEARED("analyticsCleared", 3),
    REVIEW_CLEARED("reviewCleared", 4),
    REMINDER_CLEARED("reminderCleared", 5),
    SCOPED_EPOCH_CLEARED("scopedEpochCleared", 6),
    SHARE_CACHE_CLEARED("shareCacheCleared", 7),
    COMPLETED("completed", 8),
}

public data class ResetStepReceipt(
    val step: ResetStep,
    val receiptId: String,
    val completedAtUtc: String,
)

public data class ResetJournalRecord(
    val previousInstallId: String,
    val candidateInstallId: String,
    val irrevocable: Boolean,
    val writePoisoned: Boolean,
    val receipts: List<ResetStepReceipt>,
) {
    public val lastStep: ResetStep get() = receipts.maxByOrNull { it.step.order }?.step ?: ResetStep.INTENT

    public fun has(step: ResetStep): Boolean = receipts.any { it.step == step }
}

public sealed interface ResetJournalReadResult {
    public data object None : ResetJournalReadResult
    public data class Valid(val record: ResetJournalRecord) : ResetJournalReadResult
    public data class Invalid(val reason: String) : ResetJournalReadResult
}

public class ResetJournalException(message: String) : IllegalStateException(message)

public class FileResetJournal(
    private val directory: Path,
    private val fileSystem: KotlinSaveFileSystem = NioKotlinSaveFileSystem,
    private val clock: SaveClock = SystemSaveClock,
) {
    private val path: Path = directory.resolve("reset.journal")
    private val tempPath: Path = directory.resolve("reset.journal.tmp")

    public fun read(): ResetJournalReadResult {
        if (!fileSystem.exists(path)) return ResetJournalReadResult.None
        return try {
            val bytes = fileSystem.read(path)
            val root = StrictJson.parseUtf8(bytes) as? JsonValue.Obj ?: throw ResetJournalException("reset.root")
            val decoded = decode(root)
            if (!bytes.contentEquals(StrictJson.canonical(encode(decoded.record)).toByteArray(Charsets.UTF_8))) {
                throw ResetJournalException("reset.noncanonical")
            }
            decoded
        } catch (error: ResetJournalException) {
            ResetJournalReadResult.Invalid(error.message ?: "reset.invalid")
        } catch (error: Exception) {
            ResetJournalReadResult.Invalid("reset.invalid:${error.javaClass.simpleName}")
        }
    }

    public fun prepare(previousInstallId: String, candidateInstallId: String): ResetJournalRecord {
        require(previousInstallId.isNotBlank() && candidateInstallId.isNotBlank() && previousInstallId != candidateInstallId) { "reset.install_identity" }
        val existing = read()
        when (existing) {
            is ResetJournalReadResult.Valid -> {
                val record = existing.record
                require(record.previousInstallId == previousInstallId && record.candidateInstallId == candidateInstallId) { "reset.journal_identity_conflict" }
                return record
            }
            is ResetJournalReadResult.Invalid -> throw ResetJournalException(existing.reason)
            ResetJournalReadResult.None -> Unit
        }
        val record = ResetJournalRecord(
            previousInstallId = previousInstallId,
            candidateInstallId = candidateInstallId,
            irrevocable = true,
            writePoisoned = true,
            receipts = listOf(receipt(ResetStep.INTENT, "reset:intent:$candidateInstallId")),
        )
        write(record)
        return record
    }

    public fun mark(record: ResetJournalRecord, step: ResetStep, receiptId: String = "reset:${step.wire}:${record.candidateInstallId}"): ResetJournalRecord {
        require(record.irrevocable) { "reset.intent_required" }
        if (record.has(step)) return record
        require(step.order == record.lastStep.order + 1) { "reset.step_order" }
        require(receiptId.isNotBlank()) { "reset.receipt_id" }
        val next = record.copy(receipts = record.receipts + receipt(step, receiptId), writePoisoned = step != ResetStep.COMPLETED)
        write(next)
        return next
    }

    public fun poison(record: ResetJournalRecord): ResetJournalRecord {
        if (record.writePoisoned) return record
        val next = record.copy(writePoisoned = true)
        write(next)
        return next
    }

    public fun clearCompleted(record: ResetJournalRecord) {
        require(record.has(ResetStep.COMPLETED) && !record.writePoisoned) { "reset.not_completed" }
        fileSystem.deleteIfExists(tempPath)
        fileSystem.deleteIfExists(path)
        check(!fileSystem.exists(path) && !fileSystem.exists(tempPath)) { "reset.clear_verification" }
    }

    private fun receipt(step: ResetStep, id: String): ResetStepReceipt = ResetStepReceipt(step, id, KotlinSaveContract.timestampFormatter.format(Instant.ofEpochMilli(clock.nowUtcMillis())))

    private fun write(record: ResetJournalRecord) {
        fileSystem.createDirectory(directory)
        val bytes = StrictJson.canonical(encode(record)).toByteArray(Charsets.UTF_8)
        fileSystem.writeAndSync(tempPath, bytes)
        fileSystem.moveReplace(tempPath, path)
        val restored = read()
        if (restored !is ResetJournalReadResult.Valid || restored.record != record) throw ResetJournalException("reset.read_back")
    }

    private fun encode(record: ResetJournalRecord): JsonValue.Obj = JsonValue.Obj(linkedMapOf(
        "schema" to JsonValue.Str(ResetJournalContract.SCHEMA),
        "schemaVersion" to JsonValue.Num(ResetJournalContract.VERSION.toString()),
        "previousInstallId" to JsonValue.Str(record.previousInstallId),
        "candidateInstallId" to JsonValue.Str(record.candidateInstallId),
        "irrevocable" to JsonValue.Bool(record.irrevocable),
        "writePoisoned" to JsonValue.Bool(record.writePoisoned),
        "receipts" to JsonValue.Arr(record.receipts.map { receipt -> JsonValue.Obj(linkedMapOf(
            "step" to JsonValue.Str(receipt.step.wire), "receiptId" to JsonValue.Str(receipt.receiptId), "completedAtUtc" to JsonValue.Str(receipt.completedAtUtc),
        )) }),
    ))

    private fun decode(root: JsonValue.Obj): ResetJournalReadResult.Valid {
        val expected = setOf("schema", "schemaVersion", "previousInstallId", "candidateInstallId", "irrevocable", "writePoisoned", "receipts")
        requireExact(root, expected, "reset")
        if (root.string("schema") != ResetJournalContract.SCHEMA || root.integer("schemaVersion") != ResetJournalContract.VERSION) throw ResetJournalException("reset.schema")
        val receiptValues = root.array("receipts")
        val receipts = receiptValues.mapIndexed { index, item ->
            val value = item as? JsonValue.Obj ?: throw ResetJournalException("reset.receipts[$index].object")
            requireExact(value, setOf("step", "receiptId", "completedAtUtc"), "reset.receipt")
            val completedAt = value.string("completedAtUtc")
            if (!KotlinSaveContract.timestampPattern.matches(completedAt)) throw ResetJournalException("reset.receipt.time")
            Instant.parse(completedAt)
            val receiptId = value.string("receiptId")
            if (receiptId.isBlank()) throw ResetJournalException("reset.receipt.id")
            ResetStepReceipt(enumWire(value.string("step"), ResetStep.entries), receiptId, completedAt)
        }
        if (receipts.isEmpty() || receipts.first().step != ResetStep.INTENT) throw ResetJournalException("reset.intent_missing")
        if (receipts.map { it.step }.distinct().size != receipts.size) throw ResetJournalException("reset.step_duplicate")
        if (receipts.zipWithNext().any { it.second.step.order != it.first.step.order + 1 }) throw ResetJournalException("reset.step_order")
        val record = ResetJournalRecord(root.string("previousInstallId"), root.string("candidateInstallId"), root.bool("irrevocable"), root.bool("writePoisoned"), receipts)
        if (!record.irrevocable) throw ResetJournalException("reset.not_irrevocable")
        if (record.previousInstallId.isBlank() || record.candidateInstallId.isBlank() || record.previousInstallId == record.candidateInstallId) throw ResetJournalException("reset.install_identity")
        if (record.writePoisoned == record.has(ResetStep.COMPLETED)) throw ResetJournalException("reset.poison_state")
        return ResetJournalReadResult.Valid(record)
    }

    private fun requireExact(value: JsonValue.Obj, expected: Set<String>, field: String) {
        val missing = expected - value.entries.keys
        val unknown = value.entries.keys - expected
        if (missing.isNotEmpty() || unknown.isNotEmpty()) throw ResetJournalException("$field.fields")
    }
    private fun enumWire(raw: String, values: Iterable<ResetStep>): ResetStep = values.firstOrNull { it.wire == raw } ?: throw ResetJournalException("reset.step_unknown")
    private fun JsonValue.Obj.string(name: String): String = (this[name] as? JsonValue.Str)?.value ?: throw ResetJournalException("reset.$name.string")
    private fun JsonValue.Obj.integer(name: String): Int = (this[name] as? JsonValue.Num)?.raw?.toIntOrNull() ?: throw ResetJournalException("reset.$name.integer")
    private fun JsonValue.Obj.bool(name: String): Boolean = (this[name] as? JsonValue.Bool)?.value ?: throw ResetJournalException("reset.$name.boolean")
    private fun JsonValue.Obj.array(name: String): List<JsonValue> = (this[name] as? JsonValue.Arr)?.values ?: throw ResetJournalException("reset.$name.array")
}

public class ResetWritePoison {
    private var poisoned: Boolean = false

    public val isPoisoned: Boolean get() = poisoned

    public fun poison() { poisoned = true }
    public fun clear() { poisoned = false }
    public fun requireWritable() { check(!poisoned) { "reset.write_poisoned" } }
}
