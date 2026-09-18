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

public fun interface AnalyticsReceiptSink {
    public fun publish(receipts: List<AnalyticsReceipt>)
}

public class AnalyticsReceiptProjection(
    private val sink: AnalyticsReceiptSink,
    private val durableReceiptIds: (() -> Set<String>)? = null,
    private val establishDurableBaseline: ((Collection<String>) -> Unit)? = null,
) {
    private val published = linkedSetOf<String>()
    private val baseline = linkedSetOf<String>()
    private val pendingAfterSave = linkedSetOf<String>()
    private var baselineEstablished: Boolean = false

    /** Marks receipts already durable before this process attached; they are never replayed. */
    @Synchronized
    public fun establishBaseline(state: GameAggregateState) {
        ensureBaseline(state)
    }

    /**
     * A platform-state write failure is not permission to treat the current aggregate as a new
     * stream. Keep the baseline closed until the native ledger has acknowledged it; only receipts
     * observed in a verified before→after save are allowed through while that boundary is down.
     */
    @Synchronized
    private fun ensureBaseline(state: GameAggregateState): Boolean {
        if (baselineEstablished) {
            refreshDurableBaseline(state)
            return true
        }
        if (!baselineEstablished) {
            val beforeBaseline = runCatching { durableReceiptIds?.invoke() }.getOrNull()
            val historicIds = state.analytics.receipts.map { it.receiptId }.filterNot(pendingAfterSave::contains)
            // The native platform ledger records the boundary exactly once. If that write or its
            // read-back fails, leave the boundary unopened so historic receipts cannot be replayed
            // merely because this process restarted.
            val boundaryWritten = if (establishDurableBaseline == null) {
                true
            } else {
                runCatching {
                    requireNotNull(establishDurableBaseline).invoke(historicIds)
                    requireNotNull(durableReceiptIds?.invoke()) { "analytics.baseline_read" }
                }.isSuccess
            }
            if (!boundaryWritten) return false
            val durable = runCatching { durableReceiptIds?.invoke() }.getOrNull()
                ?: beforeBaseline
                ?: if (establishDurableBaseline != null) return false else null
            baseline += state.analytics.receipts
                .filter { it.receiptId !in pendingAfterSave && (durable == null || it.receiptId in durable) }
                .map { it.receiptId }
            published += baseline
            baselineEstablished = true
            return true
        }
        return false
    }

    private fun refreshDurableBaseline(state: GameAggregateState) {
        val durable = runCatching { durableReceiptIds?.invoke() }.getOrNull() ?: return
        val newlyHandedOff = state.analytics.receipts
            .filter { it.receiptId in durable }
            .map { it.receiptId }
        baseline += newlyHandedOff
        published += newlyHandedOff
    }

    /**
     * Projects only the durable before→after delta, plus an earlier failed enqueue that is still
     * retryable. Sink/SDK failure is intentionally swallowed after the save has been verified;
     * failed receipt IDs remain absent from [published] and are retried by a later call.
     */
    @Synchronized
    public fun publishAfterSave(before: GameAggregateState, after: GameAggregateState) {
        runCatching {
            val beforeIds = before.analytics.receipts.map { it.receiptId }.toSet()
            val newDurable = after.analytics.receipts.filter { it.receiptId !in beforeIds }
            pendingAfterSave += newDurable.map { it.receiptId }
            val baselineReady = ensureBaseline(before)
            // A missing platform baseline must not replay old receipts. New receipts are still
            // handed off after the aggregate save and remain in pendingAfterSave on failure.
            refreshDurableBaseline(after)
            val retryable = if (baselineReady) {
                after.analytics.receipts.filter { it.receiptId in pendingAfterSave && it.receiptId !in newDurable.map(AnalyticsReceipt::receiptId).toSet() }
            } else {
                emptyList()
            }
            enqueue(newDurable + retryable)
        }
    }

    /** Explicit in-process retry hook for a receipt whose observer enqueue failed. */
    @Synchronized
    public fun retryPending(state: GameAggregateState) {
        runCatching {
            if (!ensureBaseline(state)) return@runCatching
            refreshDurableBaseline(state)
            enqueue(state.analytics.receipts.filter { it.receiptId in pendingAfterSave && it.receiptId !in published })
        }
    }

    @Synchronized
    public fun pending(state: GameAggregateState): List<AnalyticsReceipt> {
        return try {
            if (!ensureBaseline(state)) return state.analytics.receipts.filter { it.receiptId in pendingAfterSave && it.receiptId !in published }
            refreshDurableBaseline(state)
            state.analytics.receipts.filter { it.receiptId in pendingAfterSave && it.receiptId !in published }
        } catch (_: Throwable) {
            // A failed durable-ledger read is itself a retryable handoff failure. Never report a
            // historic receipt as new merely because the observer could not be inspected.
            state.analytics.receipts.filter { it.receiptId in pendingAfterSave && it.receiptId !in published }
        }
    }

    private fun enqueue(receipts: List<AnalyticsReceipt>) {
        val unique = receipts.distinctBy { it.receiptId }.filter { it.receiptId !in published }
        if (unique.isEmpty()) return
        try {
            sink.publish(unique)
            published += unique.map { it.receiptId }
            pendingAfterSave.removeAll(unique.map(AnalyticsReceipt::receiptId).toSet())
        } catch (_: Throwable) {
            // A verified save has already committed. Leave IDs unacknowledged for retry.
        }
    }
}
