package com.solkim.baseball.core.highschool

import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class HighSchoolStateCodecTest {
    private val kernel = HighSchoolKernel()

    @Test
    fun everyVerticalCheckpointRoundTripsBeforeTheNextCommand() {
        repeat(8) { offset ->
            var result = kernel.start(
                HighSchoolKernel.StartRequest(
                    seed = (9_180_00L + offset).toString(),
                    presetId = HighSchoolContentCatalog.presets[offset % HighSchoolContentCatalog.presets.size].id,
                ),
            )
            result = checkpoint(result)
            result = kernel.completePrologue(HighSchoolKernel.AdvanceRequest(result.nextSeed, result.snapshot)).let(::checkpoint)
            result = kernel.chooseSchool(
                HighSchoolKernel.ChooseSchoolRequest(result.nextSeed, result.snapshot, HighSchoolSchoolId.values()[offset % 4]),
            ).let(::checkpoint)

            var guard = 0
            while (result.snapshot.phase != HighSchoolPhase.COMPLETED && guard++ < 160) {
                result = when (val state = result.snapshot) {
                    is HighSchoolState -> when (state.phase) {
                        HighSchoolPhase.TRAINING -> kernel.commitTraining(
                            HighSchoolKernel.TrainingRequest(result.nextSeed, state, HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.STANDARD),
                        )
                        HighSchoolPhase.RELATIONSHIP -> kernel.resolveRelationship(
                            HighSchoolKernel.RelationshipRequest(result.nextSeed, state, HighSchoolRelationshipResponse.LISTEN),
                        )
                        HighSchoolPhase.IMPORTANT_GAME -> kernel.recordImportantGame(
                            HighSchoolKernel.GameRequest(
                                result.nextSeed,
                                state,
                                HighSchoolGameReport(
                                    scenarioNumber = state.performance.importantGamesCompleted + 1,
                                    pitches = 18,
                                    strikeouts = 2,
                                    walks = 0,
                                    runsAllowed = 0,
                                    expectedDamage = 400,
                                    actualDamage = 250,
                                    recommendationAccepted = 12,
                                    outs = 3,
                                    hits = 0,
                                ),
                            ),
                        )
                        HighSchoolPhase.AWAKENING -> kernel.chooseAwakening(
                            HighSchoolKernel.AwakeningRequest(result.nextSeed, state, state.awakeningOptions.first()),
                        )
                        HighSchoolPhase.CHAPTER_REVIEW -> kernel.advanceChapter(HighSchoolKernel.AdvanceRequest(result.nextSeed, state))
                        HighSchoolPhase.DRAFT -> kernel.resolveDraft(HighSchoolKernel.AdvanceRequest(result.nextSeed, state))
                        HighSchoolPhase.LEGACY -> kernel.selectLegacy(
                            HighSchoolKernel.LegacyRequest(result.nextSeed, state, state.legacyOptions.take(state.memorySlots)),
                        )
                        HighSchoolPhase.PROLOGUE,
                        HighSchoolPhase.SCHOOL_SELECTION,
                        HighSchoolPhase.COMPLETED,
                        -> error("unexpected phase ${state.phase}")
                    }
                }.let(::checkpoint)
            }
            assertTrue(guard < 160, "seed offset=$offset did not reach completion")
            assertEquals(HighSchoolPhase.COMPLETED, result.snapshot.phase)

            // A drafted run reaches completion before the legacy screen; opening and selecting
            // legacy is a separate durable boundary and must also survive a restart.
            if (result.snapshot.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED) {
                result = kernel.openLegacy(HighSchoolKernel.AdvanceRequest(result.nextSeed, result.snapshot)).let(::checkpoint)
                result = kernel.selectLegacy(
                    HighSchoolKernel.LegacyRequest(result.nextSeed, result.snapshot, result.snapshot.legacyOptions.take(result.snapshot.memorySlots)),
                ).let(::checkpoint)
            }
            assertEquals(HighSchoolPhase.COMPLETED, result.snapshot.phase)
        }
    }

    @Test
    fun encodingIsCanonicalAndPreservesEveryField() {
        val state = kernel.start(HighSchoolKernel.StartRequest("918220", "power_prospect")).snapshot
        val first = HighSchoolStateCodec.encode(state)
        val second = HighSchoolStateCodec.encode(state)
        assertContentEquals(first, second)
        assertEquals(state, HighSchoolStateCodec.decode(first))
        assertTrue(first.decodeToString().startsWith("{\"schema\":\"baseball-high-school-state-v1\""))
    }

    @Test
    fun futureUnknownAndCorruptSnapshotsFailClosed() {
        val encoded = HighSchoolStateCodec.encode(
            kernel.start(HighSchoolKernel.StartRequest("918220", "power_prospect")).snapshot,
        ).decodeToString()
        assertFailsWith<HighSchoolStateCodecException> {
            HighSchoolStateCodec.decode(encoded.replace("\"schemaVersion\":1", "\"schemaVersion\":2").toByteArray())
        }
        assertFailsWith<HighSchoolStateCodecException> {
            HighSchoolStateCodec.decode(encoded.replace("\"state\":{", "\"state\":{\"unknown\":true,").toByteArray())
        }
        assertFailsWith<HighSchoolStateCodecException> {
            HighSchoolStateCodec.decode("{\"schema\":\"baseball-high-school-state-v1\"}".toByteArray())
        }
        assertFailsWith<HighSchoolStateCodecException> {
            HighSchoolStateCodec.decode(byteArrayOf(0xC3.toByte(), 0x28))
        }
    }

    private fun checkpoint(result: HighSchoolResult): HighSchoolResult = result.copy(
        snapshot = HighSchoolStateCodec.decode(HighSchoolStateCodec.encode(result.snapshot)),
    )
}
