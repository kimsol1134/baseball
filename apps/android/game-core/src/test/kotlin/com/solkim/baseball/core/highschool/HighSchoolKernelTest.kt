package com.solkim.baseball.core.highschool

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue
import kotlin.test.fail

class HighSchoolKernelTest {
    private val kernel = HighSchoolKernel()

    @Test
    fun catalogAndScheduleAreTheSourceBackedPhase4Shape() {
        assertEquals(8, HighSchoolContentCatalog.chapters.size)
        assertEquals(
            listOf("power_prospect", "precision_commander", "breaking_ball_artist", "innings_eater"),
            HighSchoolContentCatalog.presets.map { it.id },
        )
        assertEquals(4, HighSchoolContentCatalog.schools("서울").size)
        assertEquals(18, HighSchoolContentCatalog.awakeningNodes.size)

        val state = kernel.start(
            HighSchoolKernel.StartRequest(seed = "918220", presetId = "power_prospect"),
        ).snapshot
        assertEquals(HighSchoolPhase.PROLOGUE, state.phase)
        assertTrue(state.schedule.trainingTotal in 12..16)
        assertEquals(8, state.schedule.trainingsByChapter.size)
        assertTrue(state.schedule.trainingsByChapter.all { it in 1..3 })
        assertEquals(
            listOf(HighSchoolPhase.AWAKENING, HighSchoolPhase.IMPORTANT_GAME),
            state.schedule.milestonesByChapter.last(),
        )
        assertEquals(0, state.performance.importantGamesCompleted)
        assertTrue(state.stateCommitment.matches(Regex("[0-9a-f]{16}")))
    }

    @Test
    fun setupPrologueSchoolAndTrainingAreDeterministicAndRestartable() {
        val request = HighSchoolKernel.StartRequest(seed = "918220", presetId = "power_prospect")
        val first = runUntilAfterTraining(request)
        val second = runUntilAfterTraining(request)

        assertEquals(first, second)
        assertEquals(1, first.totalTrainingsCompleted)
        // Re-signing is intentionally represented by a fresh command result, not by mutable
        // state. A valid saved snapshot can be supplied to the next command unchanged.
        assertTrue(first.stateCommitment.matches(Regex("[0-9a-f]{16}")))
        assertTrue(first.trainingOpportunity != null || first.phase != HighSchoolPhase.TRAINING)
    }

    @Test
    fun allPhaseTransitionsCompleteAcrossTwentySeedsAndCountersNeverGoBackward() {
        repeat(20) { offset ->
            val seed = (918220 + offset).toString()
            var result = kernel.start(HighSchoolKernel.StartRequest(seed, "power_prospect"))
            result = kernel.completePrologue(HighSchoolKernel.AdvanceRequest(result.nextSeed, result.snapshot))
            result = kernel.chooseSchool(
                HighSchoolKernel.ChooseSchoolRequest(
                    result.nextSeed,
                    result.snapshot,
                    HighSchoolSchoolId.values()[offset % HighSchoolSchoolId.values().size],
                ),
            )
            var previousGames = 0
            var guard = 0
            while (result.snapshot.phase != HighSchoolPhase.COMPLETED && guard++ < 160) {
                val state = result.snapshot
                result = when (state.phase) {
                    HighSchoolPhase.TRAINING -> kernel.commitTraining(
                        HighSchoolKernel.TrainingRequest(
                            result.nextSeed,
                            state,
                            HighSchoolTrainingFocus.COMMAND,
                            HighSchoolTrainingIntensity.STANDARD,
                        ),
                    )
                    HighSchoolPhase.RELATIONSHIP -> kernel.resolveRelationship(
                        HighSchoolKernel.RelationshipRequest(
                            result.nextSeed,
                            state,
                            HighSchoolRelationshipResponse.LISTEN,
                        ),
                    )
                    HighSchoolPhase.IMPORTANT_GAME -> {
                        val reportNumber = state.performance.importantGamesCompleted + 1
                        val next = kernel.recordImportantGame(
                            HighSchoolKernel.GameRequest(
                                result.nextSeed,
                                state,
                                HighSchoolGameReport(
                                    scenarioNumber = reportNumber,
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
                        assertTrue(next.snapshot.performance.importantGamesCompleted >= previousGames)
                        previousGames = next.snapshot.performance.importantGamesCompleted
                        next
                    }
                    HighSchoolPhase.AWAKENING -> kernel.chooseAwakening(
                        HighSchoolKernel.AwakeningRequest(result.nextSeed, state, state.awakeningOptions.first()),
                    )
                    HighSchoolPhase.CHAPTER_REVIEW -> kernel.advanceChapter(
                        HighSchoolKernel.AdvanceRequest(result.nextSeed, state),
                    )
                    HighSchoolPhase.DRAFT -> kernel.resolveDraft(
                        HighSchoolKernel.AdvanceRequest(result.nextSeed, state),
                    )
                    HighSchoolPhase.LEGACY -> kernel.selectLegacy(
                        HighSchoolKernel.LegacyRequest(result.nextSeed, state, state.legacyOptions.take(state.memorySlots)),
                    )
                    HighSchoolPhase.PROLOGUE,
                    HighSchoolPhase.SCHOOL_SELECTION,
                    HighSchoolPhase.COMPLETED,
                    -> fail("unexpected phase ${state.phase}")
                }
            }
            assertTrue(guard < 160, "seed=$seed did not complete")
            assertEquals(HighSchoolPhase.COMPLETED, result.snapshot.phase, "seed=$seed")
            assertTrue(result.snapshot.performance.importantGamesCompleted >= previousGames)
            assertEquals(result.snapshot, result.snapshot.copy())
        }
    }

    @Test
    fun duplicateOrTamperedStateIsRejectedAndChallengeRunsDoNotShareState() {
        val first = kernel.start(HighSchoolKernel.StartRequest("918220", "power_prospect"))
        val other = kernel.start(HighSchoolKernel.StartRequest("918221", "power_prospect"))
        assertNotEquals(first.snapshot.careerId, other.snapshot.careerId)
        assertNotEquals(first.snapshot.stateCommitment, other.snapshot.stateCommitment)

        val tampered = first.snapshot.copy(fatigue = 99)
        try {
            kernel.completePrologue(HighSchoolKernel.AdvanceRequest(first.nextSeed, tampered))
            fail("tampered state must be rejected")
        } catch (error: IllegalArgumentException) {
            assertTrue(error.message.orEmpty().contains("state.commitment"))
        }
        try {
            val progressed = kernel.completePrologue(HighSchoolKernel.AdvanceRequest(first.nextSeed, first.snapshot))
            kernel.completePrologue(HighSchoolKernel.AdvanceRequest(progressed.nextSeed, progressed.snapshot))
            fail("stale phase must be rejected")
        } catch (error: IllegalArgumentException) {
            assertTrue(error.message.orEmpty().contains("state.phase"))
        }
    }

    @Test
    fun inheritanceCurveAndAwakeningAvailabilityUseTheFrozenRules() {
        assertEquals(8, kernel.inheritancePointCap(0, 1))
        assertEquals(8, kernel.inheritancePointCap(23, 1))
        assertEquals(1, kernel.inheritancePointCap(23, 2))
        assertEquals(16, kernel.inheritancePointCap(500, 1))
        assertEquals(20, kernel.inheritancePointCap(800, 1))
        assertEquals(20, kernel.inheritancePointCap(100, 2))

        val state = kernel.start(HighSchoolKernel.StartRequest("918220", "power_prospect")).snapshot
        assertEquals(
            listOf(
                HighSchoolAwakening.EXPLOSIVE_FASTBALL,
                HighSchoolAwakening.PINPOINT_EDGE,
                HighSchoolAwakening.DISAPPEARING_BREAKER,
                HighSchoolAwakening.BATTERY_SYNC,
            ),
            kernel.availableAwakenings(state),
        )
    }

    private fun runUntilAfterTraining(request: HighSchoolKernel.StartRequest): HighSchoolState {
        var result = kernel.start(request)
        result = kernel.completePrologue(HighSchoolKernel.AdvanceRequest(result.nextSeed, result.snapshot))
        result = kernel.chooseSchool(
            HighSchoolKernel.ChooseSchoolRequest(
                result.nextSeed,
                result.snapshot,
                HighSchoolSchoolId.HANBIT_TRADITIONAL,
            ),
        )
        return kernel.commitTraining(
            HighSchoolKernel.TrainingRequest(
                result.nextSeed,
                result.snapshot,
                HighSchoolTrainingFocus.COMMAND,
                HighSchoolTrainingIntensity.STANDARD,
            ),
        ).snapshot
    }
}
