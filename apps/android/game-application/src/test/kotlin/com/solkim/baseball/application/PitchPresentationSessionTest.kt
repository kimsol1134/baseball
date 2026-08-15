package com.solkim.baseball.application

import com.solkim.baseball.bridge.PitchIpcCodec
import com.solkim.baseball.bridge.ProtocolDecisionKind
import com.solkim.baseball.model.ImpactKind
import com.solkim.baseball.model.PitchAcknowledgementKind
import com.solkim.baseball.model.PitchCommandKind
import com.solkim.baseball.model.PitchIpcAcknowledgement
import com.solkim.baseball.model.PitchIpcCommand
import com.solkim.baseball.model.PitchIpcContract
import com.solkim.baseball.model.PitchTerminalResult
import com.solkim.baseball.model.PresentationTerminalStatus
import com.solkim.baseball.model.PresentationVisual
import com.solkim.baseball.model.QualityTier
import com.solkim.baseball.model.TrailKind
import com.solkim.baseball.model.TrajectoryPoint
import com.solkim.baseball.model.PitchType
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

class PitchPresentationSessionTest {
    private val request = PitchIpcCodec.createRequest(
        "request", "pitch", 1, PitchType.CHANGEUP, 600, 0, 720, 1040,
        listOf(TrajectoryPoint(0, 0, 1800, -16000), TrajectoryPoint(1000, 0, 720, 0)),
        "seed", PresentationVisual(TrailKind.FADE, ImpactKind.MISS, false, QualityTier.LOW),
    )

    @Test
    fun terminalResultIsProjectedOnlyAfterUnityAcknowledgesExactPitch() {
        val coordinator = PitchPresentationSessionCoordinator()
        assertEquals(ProtocolDecisionKind.ACCEPTED, coordinator.acceptCommand(initialize()).kind)
        assertEquals(ProtocolDecisionKind.ACCEPTED, coordinator.acceptAcknowledgement(ready()).kind)
        assertEquals(ProtocolDecisionKind.ACCEPTED, coordinator.acceptCommand(play()).kind)
        assertEquals(ProtocolDecisionKind.ACCEPTED, coordinator.acceptAcknowledgement(started()).kind)
        val terminal = completed()
        assertEquals(ProtocolDecisionKind.ACCEPTED, coordinator.acceptAcknowledgement(terminal).kind)
        val state = assertIs<PitchPresentationSessionState.Terminal>(coordinator.state)
        assertEquals(PresentationTerminalStatus.COMPLETED, state.result.status)
        assertEquals(request.pitchId, state.result.pitchId)
        assertEquals(ProtocolDecisionKind.DUPLICATE, coordinator.acceptAcknowledgement(completed("terminal-replay")).kind)
    }

    private fun initialize() = PitchIpcCommand(
        PitchIpcContract.SCHEMA, 1, "initialize", "session", "session-seed", PitchCommandKind.INITIALIZE_BRIDGE,
    )

    private fun ready() = PitchIpcAcknowledgement(
        PitchIpcContract.SCHEMA, 1, "ready", "session", "session-seed", PitchAcknowledgementKind.UNITY_READY,
    )

    private fun play() = PitchIpcCommand(
        PitchIpcContract.SCHEMA, 1, "play", "session", request.presentationSeed, PitchCommandKind.PLAY_PRESENTATION, request,
    )

    private fun started() = PitchIpcAcknowledgement(
        PitchIpcContract.SCHEMA, 1, "started", "session", request.presentationSeed,
        PitchAcknowledgementKind.PRESENTATION_STARTED, request.pitchId, request.requestSha256,
    )

    private fun completed(messageId: String = "terminal") = PitchIpcAcknowledgement(
        PitchIpcContract.SCHEMA, 1, messageId, "session", request.presentationSeed,
        PitchAcknowledgementKind.PRESENTATION_COMPLETED, request.pitchId, request.requestSha256,
        terminal = PitchTerminalResult(PresentationTerminalStatus.COMPLETED, request.pitchId, request.requestSha256),
    )
}
