package com.solkim.baseball.application

import com.solkim.baseball.persistence.FileResetJournal
import com.solkim.baseball.persistence.KotlinSaveRepository
import com.solkim.baseball.persistence.ResetJournalReadResult
import com.solkim.baseball.persistence.ResetStep
import com.solkim.baseball.persistence.ResetWritePoison

public fun interface InstallIdentityWriter {
    public fun publish(candidateInstallId: String)
}

public interface ResetSideEffects {
    public fun clearAnalytics()
    public fun clearReview()
    public fun clearReminders()
    public fun clearScopedEpoch()
    public fun clearShareCache()
}

public object NoResetSideEffects : ResetSideEffects {
    override fun clearAnalytics() = Unit
    override fun clearReview() = Unit
    override fun clearReminders() = Unit
    override fun clearScopedEpoch() = Unit
    override fun clearShareCache() = Unit
}

/** Resumes an irrevocable reset one durable receipt at a time after process death. */
public class ResetCoordinator<T>(
    private val journal: FileResetJournal,
    private val repository: KotlinSaveRepository<T>,
    private val identityWriter: InstallIdentityWriter,
    private val sideEffects: ResetSideEffects = NoResetSideEffects,
    private val poison: ResetWritePoison = ResetWritePoison(),
) {
    init {
        when (val pending = journal.read()) {
            is ResetJournalReadResult.Valid -> if (pending.record.writePoisoned) poison.poison()
            ResetJournalReadResult.None -> Unit
            is ResetJournalReadResult.Invalid -> poison.poison()
        }
    }

    public val isWritePoisoned: Boolean get() = poison.isPoisoned

    public fun begin(previousInstallId: String, candidateInstallId: String) {
        val prepared = journal.prepare(previousInstallId, candidateInstallId)
        resume(prepared)
    }

    public fun resume(record: com.solkim.baseball.persistence.ResetJournalRecord? = null) {
        var current = record ?: when (val result = journal.read()) {
            ResetJournalReadResult.None -> throw IllegalStateException("reset.journal_missing")
            is ResetJournalReadResult.Invalid -> throw IllegalStateException(result.reason)
            is ResetJournalReadResult.Valid -> result.record
        }
        poison.poison()
        try {
            if (!current.has(ResetStep.REPOSITORY_RESET)) {
                repository.reset()
                current = journal.mark(current, ResetStep.REPOSITORY_RESET)
            }
            if (!current.has(ResetStep.CANDIDATE_IDENTITY_PUBLISHED)) {
                identityWriter.publish(current.candidateInstallId)
                current = journal.mark(current, ResetStep.CANDIDATE_IDENTITY_PUBLISHED)
            }
            if (!current.has(ResetStep.ANALYTICS_CLEARED)) {
                sideEffects.clearAnalytics()
                current = journal.mark(current, ResetStep.ANALYTICS_CLEARED)
            }
            if (!current.has(ResetStep.REVIEW_CLEARED)) {
                sideEffects.clearReview()
                current = journal.mark(current, ResetStep.REVIEW_CLEARED)
            }
            if (!current.has(ResetStep.REMINDER_CLEARED)) {
                sideEffects.clearReminders()
                current = journal.mark(current, ResetStep.REMINDER_CLEARED)
            }
            if (!current.has(ResetStep.SCOPED_EPOCH_CLEARED)) {
                sideEffects.clearScopedEpoch()
                current = journal.mark(current, ResetStep.SCOPED_EPOCH_CLEARED)
            }
            if (!current.has(ResetStep.SHARE_CACHE_CLEARED)) {
                sideEffects.clearShareCache()
                current = journal.mark(current, ResetStep.SHARE_CACHE_CLEARED)
            }
            if (!current.has(ResetStep.COMPLETED)) {
                current = journal.mark(current, ResetStep.COMPLETED)
            }
            poison.clear()
            journal.clearCompleted(current)
        } catch (error: Exception) {
            poison.poison()
            throw error
        }
    }

    public fun requireLifecycleWritesAllowed() {
        poison.requireWritable()
    }
}
