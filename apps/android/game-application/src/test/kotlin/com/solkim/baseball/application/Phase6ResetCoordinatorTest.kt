package com.solkim.baseball.application

import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.persistence.FileResetJournal
import com.solkim.baseball.persistence.KotlinSaveRepository
import com.solkim.baseball.persistence.ResetJournalReadResult
import com.solkim.baseball.persistence.ResetStep
import com.solkim.baseball.persistence.ResetWritePoison
import com.solkim.baseball.persistence.SaveClock
import com.solkim.baseball.persistence.SaveLoadResult
import com.solkim.baseball.persistence.SaveLoadStatus
import com.solkim.baseball.persistence.SaveWriteResult
import java.nio.file.Files
import java.nio.file.Path
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class Phase6ResetCoordinatorTest {
    @Test
    fun resetReceiptsAreExactContiguousAndIncludeEveryScopedSideEffect() {
        withTempDirectory { directory ->
            val journal = FileResetJournal(directory, clock = FixedClock(1_700_000_000_000L))
            var record = journal.prepare("old-install", "candidate-install")
            ResetStep.entries.drop(1).forEach { step -> record = journal.mark(record, step) }

            assertEquals(ResetStep.entries.toList(), record.receipts.map { it.step })
            assertEquals(
                listOf("intent", "repositoryReset", "candidateIdentityPublished", "analyticsCleared", "reviewCleared", "reminderCleared", "scopedEpochCleared", "shareCacheCleared", "completed"),
                record.receipts.map { it.step.wire },
            )
            assertTrue(record.irrevocable)
            assertFalse(record.writePoisoned)
        }
    }

    @Test
    fun processDeathAndRestartResumesFromEveryDurableResetBoundary() {
        ResetStep.entries.forEach { restartBoundary ->
            withTempDirectory { directory ->
                val clock = FixedClock(1_700_000_000_000L)
                val journal = FileResetJournal(directory, clock = clock)
                var record = journal.prepare("old-install", "candidate-install")
                ResetStep.entries.drop(1)
                    .takeWhile { it.order < restartBoundary.order }
                    .forEach { step -> record = journal.mark(record, step) }

                val calls = mutableListOf<String>()
                val coordinator = ResetCoordinator(
                    journal = journal,
                    repository = ResetRepository { calls += "repository" },
                    identityWriter = InstallIdentityWriter { candidate -> calls += "identity:$candidate" },
                    sideEffects = RecordingEffects(calls),
                )
                assertTrue(coordinator.isWritePoisoned)
                coordinator.resume()

                assertFalse(coordinator.isWritePoisoned)
                assertFalse(Files.exists(directory.resolve("reset.journal")))
                if (restartBoundary.order <= ResetStep.REPOSITORY_RESET.order) assertTrue(calls.any { it == "repository" })
                if (restartBoundary.order <= ResetStep.CANDIDATE_IDENTITY_PUBLISHED.order) {
                    assertTrue(calls.any { it == "identity:candidate-install" })
                }
                if (restartBoundary.order <= ResetStep.ANALYTICS_CLEARED.order) assertTrue(calls.contains("analytics"))
                if (restartBoundary.order <= ResetStep.REVIEW_CLEARED.order) assertTrue(calls.contains("review"))
                if (restartBoundary.order <= ResetStep.REMINDER_CLEARED.order) assertTrue(calls.contains("reminder"))
                if (restartBoundary.order <= ResetStep.SCOPED_EPOCH_CLEARED.order) assertTrue(calls.contains("scopedEpoch"))
                if (restartBoundary.order <= ResetStep.SHARE_CACHE_CLEARED.order) assertTrue(calls.contains("shareCache"))
            }
        }
    }

    @Test
    fun eachExternalResetStepIsRetryableAfterProcessDeathAndKeepsWritePoison() {
        listOf(
            ResetStep.REPOSITORY_RESET,
            ResetStep.CANDIDATE_IDENTITY_PUBLISHED,
            ResetStep.ANALYTICS_CLEARED,
            ResetStep.REVIEW_CLEARED,
            ResetStep.REMINDER_CLEARED,
            ResetStep.SCOPED_EPOCH_CLEARED,
            ResetStep.SHARE_CACHE_CLEARED,
        ).forEach { faultStep ->
            withTempDirectory { directory ->
                val clock = FixedClock(1_700_000_000_000L)
                val journal = FileResetJournal(directory, clock = clock)
                val fault = FaultPlan(faultStep)
                val calls = mutableListOf<String>()
                val first = ResetCoordinator(
                    journal = journal,
                    repository = ResetRepository { calls += "repository"; fault.failIf(ResetStep.REPOSITORY_RESET) },
                    identityWriter = InstallIdentityWriter { candidate -> fault.failIf(ResetStep.CANDIDATE_IDENTITY_PUBLISHED); calls += "identity:$candidate" },
                    sideEffects = RecordingEffects(calls, fault),
                )
                assertFailsWith<IllegalStateException> { first.begin("old-install", "candidate-install") }
                assertTrue(first.isWritePoisoned)
                val pending = journal.read() as ResetJournalReadResult.Valid
                assertEquals(faultStep.order - 1, pending.record.lastStep.order)

                fault.step = null
                val restarted = ResetCoordinator(
                    journal = journal,
                    repository = ResetRepository { calls += "repository-retry" },
                    identityWriter = InstallIdentityWriter { candidate -> calls += "identity-retry:$candidate" },
                    sideEffects = RecordingEffects(calls),
                    poison = ResetWritePoison(),
                )
                assertTrue(restarted.isWritePoisoned)
                assertFailsWith<IllegalStateException> { restarted.requireLifecycleWritesAllowed() }
                restarted.resume()
                assertFalse(restarted.isWritePoisoned)
                assertFalse(Files.exists(directory.resolve("reset.journal")))
            }
        }
    }

    private class FaultPlan(var step: ResetStep?) {
        fun failIf(step: ResetStep) {
            if (this.step == step) throw IllegalStateException("fault:${step.wire}")
        }
    }

    private class RecordingEffects(
        private val calls: MutableList<String>,
        private val fault: FaultPlan? = null,
    ) : ResetSideEffects {
        override fun clearAnalytics() { fault?.failIf(ResetStep.ANALYTICS_CLEARED); calls += "analytics" }
        override fun clearReview() { fault?.failIf(ResetStep.REVIEW_CLEARED); calls += "review" }
        override fun clearReminders() { fault?.failIf(ResetStep.REMINDER_CLEARED); calls += "reminder" }
        override fun clearScopedEpoch() { fault?.failIf(ResetStep.SCOPED_EPOCH_CLEARED); calls += "scopedEpoch" }
        override fun clearShareCache() { fault?.failIf(ResetStep.SHARE_CACHE_CLEARED); calls += "shareCache" }
    }

    private class ResetRepository(private val resetAction: () -> Unit) : KotlinSaveRepository<Unit> {
        override fun save(value: Unit, revision: ULong): SaveWriteResult<Unit> = error("not used")
        override fun load(): SaveLoadResult<Unit> = SaveLoadResult(SaveLoadStatus.NO_SAVE)
        override fun reset() = resetAction()
    }

    private class FixedClock(private val millis: Long) : SaveClock {
        override fun nowUtcMillis(): Long = millis
    }

    private fun withTempDirectory(block: (Path) -> Unit) {
        val directory = Files.createTempDirectory("baseball-phase6-reset-")
        try {
            block(directory)
        } finally {
            Files.walk(directory).use { stream -> stream.sorted(Comparator.reverseOrder()).forEach { Files.deleteIfExists(it) } }
        }
    }
}
