package com.solkim.baseball.bridge

import com.solkim.baseball.model.ImpactKind
import com.solkim.baseball.model.PitchAcknowledgementKind
import com.solkim.baseball.model.PitchCommandKind
import com.solkim.baseball.model.PitchIpcAcknowledgement
import com.solkim.baseball.model.PitchIpcCommand
import com.solkim.baseball.model.PitchIpcContract
import com.solkim.baseball.model.PitchTerminalResult
import com.solkim.baseball.model.PresentationTerminalStatus
import com.solkim.baseball.model.PresentationVisual
import com.solkim.baseball.model.PresentationMarker
import com.solkim.baseball.model.QualityTier
import com.solkim.baseball.model.TrailKind
import com.solkim.baseball.model.TrajectoryPoint
import com.solkim.baseball.model.PitchType
import kotlin.test.Test
import kotlin.test.assertEquals

class PitchSessionGateTest {
    private val request = PitchIpcCodec.createRequest(
        "request-1", "pitch-1", 1, PitchType.FOUR_SEAM, 500, 0, 700, 1420,
        listOf(TrajectoryPoint(0, 0, 1800, -16000), TrajectoryPoint(1000, 0, 700, 0)),
        "seed-1", PresentationVisual(TrailKind.STRAIGHT, ImpactKind.GLOVE, false, QualityTier.HIGH),
    )

    @Test
    fun duplicatePlayAndTerminalAreIdempotentButStaleDataIsRejected() {
        val gate = PitchSessionGate()
        assertEquals(ProtocolDecisionKind.ACCEPTED, gate.acceptCommand(initialize("init-1")).kind)
        assertEquals(ProtocolDecisionKind.ACCEPTED, gate.acceptAcknowledgement(ready("ready-1")).kind)
        val play = play("play-1", request)
        assertEquals(ProtocolDecisionKind.ACCEPTED, gate.acceptCommand(play).kind)
        assertEquals(ProtocolDecisionKind.DUPLICATE, gate.acceptCommand(play).kind)
        assertEquals(ProtocolDecisionKind.REJECTED, gate.acceptAcknowledgement(
            started("foreign", "pitch-foreign", request.requestSha256, request.presentationSeed),
        ).kind)
        assertEquals(ProtocolDecisionKind.ACCEPTED, gate.acceptAcknowledgement(
            started("started-1", request.pitchId, request.requestSha256, request.presentationSeed),
        ).kind)
        val terminal = completed("completed-1")
        assertEquals(ProtocolDecisionKind.ACCEPTED, gate.acceptAcknowledgement(terminal).kind)
        assertEquals(ProtocolDecisionKind.DUPLICATE, gate.acceptAcknowledgement(completed("completed-2")).kind)
    }

    @Test
    fun markerOrderAndSessionStalenessAreRejected() {
        val gate = PitchSessionGate()
        gate.acceptCommand(initialize("init-1"))
        assertEquals(ProtocolDecisionKind.REJECTED, gate.acceptAcknowledgement(
            ready("stale-ready", session = "other-session"),
        ).kind)
        gate.acceptAcknowledgement(ready("ready-1"))
        gate.acceptCommand(play("play-1", request))
        assertEquals(ProtocolDecisionKind.REJECTED, gate.acceptAcknowledgement(
            marker("marker-plate", PresentationMarker.PLATE),
        ).kind)
        gate.acceptAcknowledgement(started("started-1", request.pitchId, request.requestSha256, request.presentationSeed))
        assertEquals(ProtocolDecisionKind.ACCEPTED, gate.acceptAcknowledgement(
            marker("marker-release", PresentationMarker.RELEASE),
        ).kind)
        assertEquals(ProtocolDecisionKind.REJECTED, gate.acceptAcknowledgement(
            marker("marker-impact", PresentationMarker.IMPACT),
        ).kind)
    }

    @Test
    fun aNewPresentationMayReenterAfterThePreviousTerminalResult() {
        val gate = PitchSessionGate()
        gate.acceptCommand(initialize("init-1"))
        gate.acceptAcknowledgement(ready("ready-1"))
        gate.acceptCommand(play("play-1", request))
        gate.acceptAcknowledgement(started("started-1", request.pitchId, request.requestSha256, request.presentationSeed))
        gate.acceptAcknowledgement(completed("completed-1"))
        assertEquals(ProtocolDecisionKind.ACCEPTED, gate.acceptCommand(play("play-replay", request)).kind)
        assertEquals(ProtocolDecisionKind.ACCEPTED, gate.acceptAcknowledgement(started("replay-started", request.pitchId, request.requestSha256, request.presentationSeed)).kind)
        assertEquals(ProtocolDecisionKind.ACCEPTED, gate.acceptAcknowledgement(completed("replay-completed")).kind)

        val next = PitchIpcCodec.createRequest(
            "request-2", "pitch-2", 2, PitchType.SLIDER, 500, 0, 700, 1420,
            listOf(TrajectoryPoint(0, 0, 1800, -16000), TrajectoryPoint(1000, 0, 700, 0)),
            "seed-2", PresentationVisual(TrailKind.BREAKING, ImpactKind.PLATE, false, QualityTier.HIGH),
        )
        assertEquals(ProtocolDecisionKind.ACCEPTED, gate.acceptCommand(play("play-2", next)).kind)
    }

    private fun initialize(messageId: String) = PitchIpcCommand(
        PitchIpcContract.SCHEMA, 1, messageId, "session-1", "session-seed", PitchCommandKind.INITIALIZE_BRIDGE,
    )

    private fun play(messageId: String, request: com.solkim.baseball.model.PitchPresentationRequest) = PitchIpcCommand(
        PitchIpcContract.SCHEMA, 1, messageId, "session-1", request.presentationSeed,
        PitchCommandKind.PLAY_PRESENTATION, request,
    )

    private fun ready(messageId: String, session: String = "session-1") = PitchIpcAcknowledgement(
        PitchIpcContract.SCHEMA, 1, messageId, session, "session-seed", PitchAcknowledgementKind.UNITY_READY,
    )

    private fun started(messageId: String, pitchId: String, hash: String, seed: String) = PitchIpcAcknowledgement(
        PitchIpcContract.SCHEMA, 1, messageId, "session-1", seed,
        PitchAcknowledgementKind.PRESENTATION_STARTED, pitchId, hash,
    )

    private fun marker(messageId: String, marker: com.solkim.baseball.model.PresentationMarker) = PitchIpcAcknowledgement(
        PitchIpcContract.SCHEMA, 1, messageId, "session-1", request.presentationSeed,
        PitchAcknowledgementKind.PRESENTATION_MARKER, request.pitchId, request.requestSha256, marker,
    )

    private fun completed(messageId: String) = PitchIpcAcknowledgement(
        PitchIpcContract.SCHEMA, 1, messageId, "session-1", request.presentationSeed,
        PitchAcknowledgementKind.PRESENTATION_COMPLETED, request.pitchId, request.requestSha256,
        terminal = PitchTerminalResult(PresentationTerminalStatus.COMPLETED, request.pitchId, request.requestSha256),
    )
}
