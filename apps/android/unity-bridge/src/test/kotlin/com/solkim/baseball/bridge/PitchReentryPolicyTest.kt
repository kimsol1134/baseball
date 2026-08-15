package com.solkim.baseball.bridge

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class PitchReentryPolicyTest {
    @Test
    fun sameSessionAfterTerminalReturnConsumesPauseHandshake() {
        val decision = PitchReentryPolicy.decide(
            currentSessionId = "important-session",
            nextSessionId = "important-session",
            returningToShell = true,
            unloadRequested = true,
        )

        assertTrue(decision.accepted)
        assertTrue(decision.resetTerminalReturn)
    }

    @Test
    fun differentSessionStillRequiresTerminalReturn() {
        val rejected = PitchReentryPolicy.decide(
            currentSessionId = "old-session",
            nextSessionId = "new-session",
            returningToShell = false,
            unloadRequested = false,
        )
        assertFalse(rejected.accepted)

        val accepted = PitchReentryPolicy.decide(
            currentSessionId = "old-session",
            nextSessionId = "new-session",
            returningToShell = true,
            unloadRequested = true,
        )
        assertTrue(accepted.accepted)
        assertTrue(accepted.resetTerminalReturn)
    }

    @Test
    fun sameSessionExactReplayWithoutTerminalReturnDoesNotInventReset() {
        val decision = PitchReentryPolicy.decide(
            currentSessionId = "important-session",
            nextSessionId = "important-session",
            returningToShell = false,
            unloadRequested = false,
        )

        assertTrue(decision.accepted)
        assertFalse(decision.resetTerminalReturn)
    }
}
