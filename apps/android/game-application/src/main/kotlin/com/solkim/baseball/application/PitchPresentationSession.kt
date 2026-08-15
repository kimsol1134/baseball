package com.solkim.baseball.application

import com.solkim.baseball.bridge.PitchSessionGate
import com.solkim.baseball.bridge.ProtocolDecision
import com.solkim.baseball.model.PitchIpcAcknowledgement
import com.solkim.baseball.model.PitchIpcCommand
import com.solkim.baseball.model.PitchPresentationRequest

/** Application-owned lifecycle projection; Unity callbacks cannot mutate gameplay state. */
public sealed interface PitchPresentationSessionState {
    public data object Idle : PitchPresentationSessionState
    public data class Ready(public val sessionId: String) : PitchPresentationSessionState
    public data class Playing(public val request: PitchPresentationRequest) : PitchPresentationSessionState
    public data class Terminal(
        public val request: PitchPresentationRequest,
        public val result: com.solkim.baseball.model.PitchTerminalResult,
    ) : PitchPresentationSessionState
    public data object Closed : PitchPresentationSessionState
}

public class PitchPresentationSessionCoordinator(
    private val gate: PitchSessionGate = PitchSessionGate(),
) {
    public var state: PitchPresentationSessionState = PitchPresentationSessionState.Idle
        private set

    public fun acceptCommand(command: PitchIpcCommand): ProtocolDecision {
        val decision = gate.acceptCommand(command)
        if (decision.accepted) {
            when (command.command) {
                com.solkim.baseball.model.PitchCommandKind.INITIALIZE_BRIDGE ->
                    state = PitchPresentationSessionState.Ready(command.sessionId)
                com.solkim.baseball.model.PitchCommandKind.PLAY_PRESENTATION ->
                    state = PitchPresentationSessionState.Playing(requireNotNull(command.request))
                else -> Unit
            }
        }
        return decision
    }

    public fun acceptAcknowledgement(acknowledgement: PitchIpcAcknowledgement): ProtocolDecision {
        val decision = gate.acceptAcknowledgement(acknowledgement)
        if (decision.accepted) {
            val request = gate.activeRequest()
            val terminal = acknowledgement.terminal
            if (terminal != null && request != null) {
                state = PitchPresentationSessionState.Terminal(request, terminal)
            } else if (acknowledgement.acknowledgement == com.solkim.baseball.model.PitchAcknowledgementKind.UNITY_UNLOADED) {
                state = PitchPresentationSessionState.Closed
            }
        }
        return decision
    }
}
