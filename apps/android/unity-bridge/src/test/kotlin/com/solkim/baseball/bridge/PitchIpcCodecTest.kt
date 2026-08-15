package com.solkim.baseball.bridge

import com.solkim.baseball.model.ImpactKind
import com.solkim.baseball.model.PitchCommandKind
import com.solkim.baseball.model.PitchIpcAcknowledgement
import com.solkim.baseball.model.PitchIpcCommand
import com.solkim.baseball.model.PitchIpcContract
import com.solkim.baseball.model.PitchPresentationRequest
import com.solkim.baseball.model.PresentationMarker
import com.solkim.baseball.model.PresentationTerminalStatus
import com.solkim.baseball.model.PresentationVisual
import com.solkim.baseball.model.QualityTier
import com.solkim.baseball.model.StrictJson
import com.solkim.baseball.model.TrailKind
import com.solkim.baseball.model.TrajectoryPoint
import com.solkim.baseball.model.PitchType
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class PitchIpcCodecTest {
    private val request = PitchIpcCodec.createRequest(
        requestId = "presentation-1",
        pitchId = "pitch-1",
        sequence = 12,
        pitchType = PitchType.SLIDER,
        flightDurationMs = 612,
        plateXMm = -84,
        plateYMm = 731,
        velocityDeciKph = 1374,
        trajectory = listOf(
            TrajectoryPoint(0, 0, 1810, -16800),
            TrajectoryPoint(500, -43, 1220, -8400),
            TrajectoryPoint(1000, -84, 731, 0),
        ),
        presentationSeed = "demo-seed-1",
        visual = PresentationVisual(TrailKind.BREAKING, ImpactKind.GLOVE, false, QualityTier.HIGH),
    )

    @Test
    fun commandRoundTripPreservesVersionedIdentityAndHash() {
        val command = PitchIpcCommand(
            schema = PitchIpcContract.SCHEMA,
            schemaVersion = 1,
            messageId = "native-play-1",
            sessionId = "session-1",
            presentationSeed = request.presentationSeed,
            command = PitchCommandKind.PLAY_PRESENTATION,
            request = request,
        )
        val decoded = PitchIpcCodec.decodeCommand(PitchIpcCodec.encodeCommand(command))
        assertEquals(command, decoded)
        assertEquals(request.requestSha256, decoded.request?.requestSha256)
    }

    @Test
    fun unknownBridgeFieldAndHashMismatchFailClosed() {
        val command = PitchIpcCommand(
            PitchIpcContract.SCHEMA, 1, "native-play-1", "session-1", request.presentationSeed,
            PitchCommandKind.PLAY_PRESENTATION, request,
        )
        val encoded = PitchIpcCodec.encodeCommand(command)
        val unknown = encoded.dropLast(1) + ",\"future\":true}"
        assertFailsWith<Exception> { PitchIpcCodec.decodeCommand(unknown) }

        val hashMismatch = encoded.replace(request.requestSha256, "0".repeat(64))
        assertFailsWith<Exception> { PitchIpcCodec.decodeCommand(hashMismatch) }
    }

    @Test
    fun acknowledgementRoundTripCarriesTerminalResult() {
        val acknowledgement = PitchIpcAcknowledgement(
            schema = PitchIpcContract.SCHEMA,
            schemaVersion = 1,
            messageId = "unity-completed-1",
            sessionId = "session-1",
            presentationSeed = request.presentationSeed,
            acknowledgement = com.solkim.baseball.model.PitchAcknowledgementKind.PRESENTATION_COMPLETED,
            pitchId = request.pitchId,
            requestSha256 = request.requestSha256,
            terminal = com.solkim.baseball.model.PitchTerminalResult(
                PresentationTerminalStatus.COMPLETED,
                request.pitchId,
                request.requestSha256,
            ),
        )
        assertEquals(acknowledgement, PitchIpcCodec.decodeAcknowledgement(PitchIpcCodec.encodeAcknowledgement(acknowledgement)))
    }

    @Test
    fun boundedMessageSizeIsEnforced() {
        assertFailsWith<Exception> {
            PitchIpcCodec.decodeCommand("x".repeat(PitchIpcContract.MAX_MESSAGE_BYTES + 1))
        }
        assertEquals("baseball-pitch-ipc-v1", StrictJson.parse("{\"schema\":\"baseball-pitch-ipc-v1\"}")
            .let { (it as com.solkim.baseball.model.JsonValue.Obj)["schema"] }
            .let { (it as com.solkim.baseball.model.JsonValue.Str).value })
    }
}
