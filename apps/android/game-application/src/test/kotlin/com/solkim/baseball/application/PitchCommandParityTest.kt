package com.solkim.baseball.application

import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.persistence.LegacySaveCodec
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import java.nio.file.Files
import java.nio.file.Path

class PitchCommandParityTest {
    @Test
    fun reducerAndCSharpBridgeReserveThroughPitchCommands() {
        val document = LegacySaveCodec.requireValid(Files.readAllBytes(realFixture()))
        val projected = CSharpLegacyAggregateBridge.project(document.payload, document.revision, "pitch-parity")
        val careerId = requireNotNull(projected.highSchool).run.careerId
        val sessionId = "pitch-parity"
        val command = GameCommand.ReservePitch(
            sessionId = sessionId,
            careerKind = PitchCareerKind.HIGH_SCHOOL,
            careerId = careerId,
            gameId = "game-parity",
            seed = "1",
        )
        val csharpEnvelope = GameCommandEnvelope(
            commandId = CareerWire.commandId("parity", "reserve", document.revision, 0),
            sessionId = sessionId,
            expectedRevision = document.revision,
            command = command,
        )
        val fromCommands = PitchCommands.reserve(projected, command)
        val fromCSharp = CSharpLegacyAggregateBridge.apply(document.payload, csharpEnvelope)
        assertEquals(fromCommands.eventName, fromCSharp.eventName)
        val resume = fromCSharp.payload["pitchResume"] as JsonValue.Obj
        assertEquals(fromCommands.state.pitch, CSharpLegacyPitch.projectPitch(resume))

        val native = GameAggregateState.initial("pitch-parity").copy(
            stage = GameStage.HIGH_SCHOOL,
            highSchool = projected.highSchool,
            meta = GameMetaState(activeHighSchoolCareerId = careerId),
        ).committed()
        native.validate()
        val nativeEnvelope = GameCommandEnvelope(
            commandId = CareerWire.commandId("parity", "reserve", 0UL, 0),
            sessionId = sessionId,
            expectedRevision = 0UL,
            command = command,
        )
        val fromNativeCommands = PitchCommands.reserve(native, command)
        val fromReducer = GameStateReducer.dispatch(native, nativeEnvelope)
        assertEquals(fromNativeCommands.state.pitch, fromReducer.state.pitch)
        assertEquals(fromNativeCommands.eventName, fromReducer.state.commandReceipts.last().eventName)
        assertNotNull(fromReducer.state.pitch)
    }

    private fun realFixture(): Path {
        val candidates = listOf(
            Path.of("game-persistence/src/test/resources/legacy/save-v1-current.json"),
            Path.of("../game-persistence/src/test/resources/legacy/save-v1-current.json"),
        )
        return candidates.firstOrNull { Files.isRegularFile(it) }
            ?: error("missing C# save-v1-current fixture")
    }
}
