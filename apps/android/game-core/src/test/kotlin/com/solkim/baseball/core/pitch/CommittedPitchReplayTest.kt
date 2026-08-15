package com.solkim.baseball.core.pitch

import com.solkim.baseball.model.PresentationTerminalStatus
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class CommittedPitchReplayTest {
    private val reserved = CommittedPitchReplay(
        replayId = "replay-1",
        sessionId = "session-1",
        messageId = "message-1",
        pitchId = "pitch-1",
        presentationSeed = "seed-1",
        requestSha256 = "a".repeat(64),
        resultRevision = 7UL,
        eventHash = "b".repeat(16),
        outcome = PitchOutcome.CALLED_STRIKE,
        status = CommittedPitchReplayStatus.RESERVED,
    )

    @Test
    fun lifecycleRequiresTerminalBeforeCommitAndConsumesOnce() {
        val lifecycle = CommittedPitchReplayLifecycle()
        assertEquals(ReplayDecision(true, "accepted"), lifecycle.reserve(reserved))
        assertEquals(ReplayDecision(false, "duplicate_replay"), lifecycle.reserve(reserved))
        assertEquals(ReplayDecision(true, "accepted"), lifecycle.markPresenting("message-1"))
        assertEquals(ReplayDecision(false, "terminal_required"), lifecycle.commit("message-1"))
        assertEquals(ReplayDecision(true, "accepted"), lifecycle.markTerminal("message-1", PresentationTerminalStatus.COMPLETED))
        assertEquals(ReplayDecision(true, "accepted"), lifecycle.commit("message-1"))
        assertEquals(ReplayDecision(true, "accepted"), lifecycle.consume("message-1"))
        assertEquals(ReplayDecision(false, "commit_required"), lifecycle.consume("message-1"))
    }

    @Test
    fun codecRejectsFutureUnknownAndCorruptWire() {
        val encoded = CommittedPitchReplayCodec.encode(reserved)
        assertEquals(reserved, CommittedPitchReplayCodec.decode(encoded))
        assertFailsWith<CommittedPitchReplayException> {
            CommittedPitchReplayCodec.decode(encoded.replace("\"schemaVersion\":1", "\"schemaVersion\":2"))
        }
        assertFailsWith<CommittedPitchReplayException> {
            CommittedPitchReplayCodec.decode(encoded.replace("\"status\":\"reserved\"", "\"status\":\"future\""))
        }
        assertFailsWith<CommittedPitchReplayException> {
            CommittedPitchReplayCodec.decode(encoded.replace("\"eventHash\":\"${"b".repeat(16)}\"", "\"eventHash\":\"bad\""))
        }
        assertFailsWith<CommittedPitchReplayException> {
            CommittedPitchReplayCodec.decode(encoded.replaceFirst("}", ",\"unknown\":true}"))
        }
    }
}
