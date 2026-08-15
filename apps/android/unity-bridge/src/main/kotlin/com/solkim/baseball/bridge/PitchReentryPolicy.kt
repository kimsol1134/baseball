package com.solkim.baseball.bridge

/**
 * Decides whether an existing PitchUnityActivity may accept a saved-session re-entry.
 *
 * A same-session re-entry is valid for exact replay and for the next pitch in the same
 * important game. A different session is only valid after the activity has explicitly
 * returned to the Compose shell. The terminal-return flag is consumed for both cases so
 * pause/detach state cannot poison the next same-session launch.
 */
public data class PitchReentryDecision(
    public val accepted: Boolean,
    public val resetTerminalReturn: Boolean,
)

public object PitchReentryPolicy {
    public fun decide(
        currentSessionId: String,
        nextSessionId: String,
        returningToShell: Boolean,
        unloadRequested: Boolean,
    ): PitchReentryDecision {
        require(currentSessionId.isNotBlank()) { "pitch.reentry.current_session" }
        require(nextSessionId.isNotBlank()) { "pitch.reentry.next_session" }
        val terminalReturn = returningToShell && unloadRequested
        val sameSession = currentSessionId == nextSessionId
        return PitchReentryDecision(
            accepted = sameSession || terminalReturn,
            resetTerminalReturn = terminalReturn,
        )
    }
}
