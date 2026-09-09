package com.solkim.baseball.core.highschool

import kotlin.test.*

class RebirthDifficultyTest {
    @Test fun upgradingAnExistingChapterKeepsAggregateAndGameLogInAgreement() {
        val old = HighSchoolPhase4Kernel(highSchool = HighSchoolKernel(6))
        var state = old.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "migration", "2026-W37", "2026-09-09")).state
        repeat(150) {
            if (state.run.phase == HighSchoolPhase.CHAPTER_REVIEW) return@repeat
            state = when (state.run.phase) {
                HighSchoolPhase.PROLOGUE -> old.completePrologue("99881", state).state
                HighSchoolPhase.SCHOOL_SELECTION -> old.chooseSchool("99881", state, state.run.schoolOptions.first().id).state
                HighSchoolPhase.TRAINING -> old.commitTraining("99881", state, HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.STANDARD).state
                HighSchoolPhase.RELATIONSHIP -> old.resolveRelationship("99881", state, HighSchoolRelationshipResponse.LISTEN).state
                HighSchoolPhase.AWAKENING -> old.chooseAwakening("99881", state, state.run.awakeningOptions.first()).state
                HighSchoolPhase.IMPORTANT_GAME -> when {
                    state.activePitch == null -> old.reserveImportantGame("99881", state).state
                    state.activePitch!!.ended -> old.finishImportantGame(state).state
                    else -> old.submitPitch(state, state.activePitch!!.sessionId, old.prepareActivePitch(state).primaryRecommendation.call).state
                }
                else -> error("Unexpected phase ${state.run.phase}")
            }
        }
        assertEquals(HighSchoolPhase.CHAPTER_REVIEW, state.run.phase)
        val next = HighSchoolPhase4Kernel().advanceChapter("882211", state).state
        assertEquals(7, next.run.balanceVersion)
        assertEquals(next.run.performance.outs + next.run.automaticOuts, next.seasonLog.sumOf { it.outs })
        assertEquals(next.run.performance.runsAllowed + next.run.automaticRunsAllowed, next.seasonLog.sumOf { it.runsAllowed })
        assertEquals(next, HighSchoolPhase4StateCodec.decode(HighSchoolPhase4StateCodec.encode(next)))
    }
    @Test fun eachCompletedLifeImprovesTheSameStartingBuildAndRepertoire() {
        val base = HighSchoolKernel().start(HighSchoolKernel.StartRequest("918220", "power_prospect")).snapshot.pitcher
        assertEquals(base, HighSchoolRebirthGrowthRules.apply(base, 0))
        var previous = base
        for (completed in 1..8) {
            val current = HighSchoolRebirthGrowthRules.apply(base, completed)
            assertTrue(current.command > previous.command)
            assertTrue(current.stuff > previous.stuff)
            assertTrue(current.pitchProfiles.first().command > previous.pitchProfiles.first().command)
            assertTrue(current.pitchProfiles.first().velocityTenthsKph > previous.pitchProfiles.first().velocityTenthsKph)
            previous = current
        }
        assertEquals(16, HighSchoolRebirthGrowthRules.bonus(Int.MAX_VALUE))
    }
    @Test fun laterLivesBeatTheSameOppositionWithoutForcedOutcomes() {
        val base = HighSchoolKernel().start(HighSchoolKernel.StartRequest("918220", "power_prospect")).snapshot
        val simulator = HighSchoolAutomaticOutingSimulator(schoolBalance = true)
        val rates = (0..6).map { completed ->
            val state = base.copy(lifeNumber = completed + 1, pitcher = HighSchoolRebirthGrowthRules.apply(base.pitcher, completed))
            val lines = (1..100).flatMap { simulator.simulate(state, state.chapter, it.toULong() * 991873UL) }
            val outs = lines.sumOf { it.outs }
            val ra = lines.sumOf { it.runsAllowed } * 27.0 / outs
            println("REBIRTH_FIXED life=${completed + 1} RA9=$ra HR9=${lines.sumOf { it.homeRuns } * 27.0 / outs} BB9=${lines.sumOf { it.walks } * 27.0 / outs} K9=${lines.sumOf { it.strikeouts } * 27.0 / outs}")
            assertTrue(lines.any { it.homeRuns > 0 })
            assertTrue(lines.any { it.runsAllowed == 0 })
            ra
        }
        assertTrue(rates.first() > rates.last() * 1.3)
        assertTrue(rates.first() > 4.0)
        assertTrue(rates.last() > 1.0, "rebirth must not guarantee shutouts")
    }
}
