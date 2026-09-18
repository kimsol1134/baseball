package com.solkim.baseball.application

import com.solkim.baseball.model.StrictJson
import com.solkim.baseball.persistence.LegacySaveCodec
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue
import java.nio.file.Files
import java.nio.file.Path

class CareerWireMigrationTest {
    @Test
    fun encodedLegacyCheckpointAndReceiptsMigrateOnLoadAndRewriteCurrentPrefixes() {
        val hash = "0".repeat(64)
        val highSchool = requireNotNull(
            CSharpLegacyAggregateBridge.project(
                LegacySaveCodec.requireValid(Files.readAllBytes(realFixture())).payload,
                0UL,
                "legacy-save",
            ).highSchool,
        )
        val legacyPitch = PitchDurableState(
            sessionId = "hs-session",
            careerKind = PitchCareerKind.HIGH_SCHOOL,
            careerId = highSchool.run.careerId,
            gameId = "game-1",
            seed = "seed",
            boundary = PitchBoundary.PLAYING,
            checkpoint = "phase7-index:3:abc",
        )
        val receipt = GameCommandReceipt(
            commandId = "phase8-P-001-startHighSchool-0-0",
            sessionId = "phase8-ui",
            expectedRevision = 0UL,
            committedRevision = 1UL,
            commandHash = hash,
            resultHash = hash,
            eventName = "setup.opened",
        )
        val saved = GameAggregateState.initial("legacy-save").copy(
            revision = 1UL,
            stage = GameStage.HIGH_SCHOOL,
            highSchool = highSchool,
            meta = GameMetaState(activeHighSchoolCareerId = highSchool.run.careerId),
            pitch = legacyPitch,
            commandReceipts = listOf(receipt),
        ).committed()
        saved.validate()

        val encoded = GameAggregateCodec.encodePayload(saved)
        val raw = StrictJson.canonical(encoded)
        assertTrue(raw.contains("phase7-index:3:abc"))
        assertTrue(raw.contains("phase8-P-001-startHighSchool-0-0"))
        assertTrue(raw.contains("phase8-ui"))

        val loaded = GameAggregateCodec.decodePayload(encoded)
        assertEquals("pitch-index:3:abc", loaded.pitch?.checkpoint)
        assertEquals("career-P-001-startHighSchool-0-0", loaded.commandReceipts.single().commandId)
        assertEquals(CareerWire.UI_SESSION, loaded.commandReceipts.single().sessionId)
        loaded.validate()

        val rewritten = StrictJson.canonical(GameAggregateCodec.encodePayload(loaded))
        assertFalse(rewritten.contains("phase7-index:"))
        assertFalse(rewritten.contains("phase8-P-001"))
        assertFalse(rewritten.contains("\"phase8-ui\""))
        assertTrue(rewritten.contains("pitch-index:3:abc"))
        assertTrue(rewritten.contains("career-P-001-startHighSchool-0-0"))
        assertNull(CareerWire.parsePitchIndex("phase7-index:3:abc"))
        assertEquals(3, CareerWire.parsePitchIndex(loaded.pitch?.checkpoint))
    }

    @Test
    fun kernelBoundSessionsAndJourneyInstallIdsStayPut() {
        val hash = "1".repeat(64)
        val saved = GameAggregateState.initial("phase8-high-school").copy(
            revision = 1UL,
            commandReceipts = listOf(
                GameCommandReceipt(
                    commandId = "career-P-001-startHighSchool-0-0",
                    sessionId = "high-school-kernel-1",
                    expectedRevision = 0UL,
                    committedRevision = 1UL,
                    commandHash = hash,
                    resultHash = hash,
                    eventName = "setup.opened",
                ),
            ),
        ).committed()
        val loaded = GameAggregateCodec.decodePayload(GameAggregateCodec.encodePayload(saved))
        assertEquals("phase8-high-school", loaded.installId)
        assertEquals("high-school-kernel-1", loaded.commandReceipts.single().sessionId)
        assertEquals("career-P-001-startHighSchool-0-0", loaded.commandReceipts.single().commandId)
    }

    @Test
    fun seedChallengeReturnPitchMigratesAfterValidate() {
        val returnPitch = PitchDurableState(
            sessionId = "tutorial:career",
            careerKind = PitchCareerKind.TUTORIAL,
            careerId = "career",
            gameId = "game-1",
            seed = "seed",
            boundary = PitchBoundary.PLAYING,
            checkpoint = "phase7-index:2:xyz",
        )
        val encoded = SeedChallengeCodec.encode(
            SeedChallengeSession(
                code = SeedChallengeCode("1", 1),
                presetId = "power_prospect",
                returnStage = GameStage.HIGH_SCHOOL,
                returnPitch = returnPitch,
                hadHighSchool = true,
                returnActiveCareerId = "career",
                returnArchiveIds = emptyList(),
                returnGameCount = 0UL,
            ),
        )
        val decoded = requireNotNull(SeedChallengeCodec.decode(encoded))
        assertEquals("phase7-index:2:xyz", decoded.returnPitch?.checkpoint)
        assertEquals("pitch-index:2:xyz", CareerWire.migrateCheckpoint(decoded.returnPitch?.checkpoint))
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
