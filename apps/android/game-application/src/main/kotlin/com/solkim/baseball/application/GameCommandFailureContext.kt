package com.solkim.baseball.application

/** Attached to the original failure, preserving its type and code for existing callers. */
public class GameCommandFailureContext(
    public val commandId: String,
    public val sessionId: String,
    public val operation: String,
    public val expectedRevision: ULong,
    public val actualRevision: ULong,
    public val beforeBoundary: PitchBoundary?,
    public val afterBoundary: PitchBoundary?,
    public val pitchId: String?,
) : RuntimeException(
    "command=$commandId operation=$operation session=$sessionId expected=$expectedRevision actual=$actualRevision before=$beforeBoundary after=$afterBoundary pitch=$pitchId",
    null, false, false,
) {
    public companion object {
        public fun from(error: Throwable): GameCommandFailureContext? =
            error.suppressed.filterIsInstance<GameCommandFailureContext>().firstOrNull()

        internal fun capture(envelope: GameCommandEnvelope, before: GameAggregateState, after: GameAggregateState): GameCommandFailureContext =
            GameCommandFailureContext(envelope.commandId, envelope.sessionId, GameCommandCodec.kind(envelope.command),
                envelope.expectedRevision, after.revision, before.pitch?.boundary, after.pitch?.boundary,
                when (val c = envelope.command) {
                    is GameCommand.CommitPitch -> c.pitchId
                    is GameCommand.ConsumePitch -> c.pitchId
                    is GameCommand.MarkPitchTerminal -> c.pitchId
                    else -> null
                })
    }
}
