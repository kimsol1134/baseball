package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.pitch.PitchKind
import kotlin.test.*

class TrainingParityTest {
    private val core = HighSchoolKernel()
    private val kernel = HighSchoolPhase4Kernel()
    private fun start(seed: String = "918220"): HighSchoolPhase4State {
        val begun = kernel.start(HighSchoolPhase4StartRequest(seed, "power_prospect", "training-test", "2026-W36", "2026-09-05")).state
        val ready = kernel.completePrologue(seed, kernel.beginTutorial(begun).state).state
        return kernel.chooseSchool(seed, ready, HighSchoolSchoolId.HAEDONG_POWER).state
    }
    @Test fun fatigueAndArmForecastsMatchActualTrainingAcrossAllChoicesAndRehabilitation() {
        for (seed in 918220..918229) for (rehab in listOf(false, true)) {
            val base = start(seed.toString()).run
            val run = core.resignShadowState(base.copy(fatigue = 62, armRisk = 30, injuryRecovery = if (rehab) 2 else 0))
            for (focus in HighSchoolTrainingFocus.entries) for (intensity in HighSchoolTrainingIntensity.entries) {
                val before = run.stateCommitment
                val preview = core.trainingPreview(run, focus, intensity)
                assertEquals(before, run.stateCommitment)
                val after = core.commitTraining(HighSchoolKernel.TrainingRequest(seed.toString(), run, focus, intensity)).snapshot
                assertEquals(after.fatigue - run.fatigue, preview.fatigueChange, "$seed/$focus/$intensity")
                assertEquals(after.armRisk - run.armRisk, preview.armRiskChange)
                assertTrue(preview.minimumGrowth <= preview.maximumGrowth)
                if (focus == HighSchoolTrainingFocus.RECOVERY || rehab) assertEquals(0, preview.maximumGrowth)
            }
        }
    }
    @Test fun repeatPreservesSelectedPitchAndStopsAtFatigueRiskOrScheduleBoundary() {
        val base = start()
        val target = base.run.pitcher.pitchProfiles.first { it.pitchType != PitchKind.FOUR_SEAM }.pitchType
        val command = HighSchoolPhase4Command.TrainingBlock("918220", List(3) { HighSchoolTrainingFocus.BREAKING_BALL to HighSchoolTrainingIntensity.INTENSIVE }, target, true)
        val envelope = HighSchoolPhase4CommandEnvelope(commandId = "repeat", sessionId = "training", expectedRevision = base.revision, command = command)
        assertEquals(envelope, HighSchoolPhase4CommandCodec.decode(HighSchoolPhase4CommandCodec.encode(envelope)))
        val run = core.resignShadowState(base.run.copy(fatigue = 74))
        val tired = kernel.commitShadowState(base.copy(run = run))
        val after = kernel.commitTrainingBlock(command.seed, tired, command.requests, target, true).state
        assertEquals(1, after.trainingEvidence.size)
        assertEquals(target, after.trainingEvidence.single().targetPitch)
        val untouched = base.run.pitcher.pitchProfiles.filter { it.pitchType != target }
        assertEquals(untouched, after.run.pitcher.pitchProfiles.filter { it.pitchType != target })
        assertEquals(after, HighSchoolPhase4StateCodec.decode(HighSchoolPhase4StateCodec.encode(after)))
        val risky = kernel.commitShadowState(base.copy(run = core.resignShadowState(base.run.copy(armRisk = 54))))
        val stopped = kernel.commitTrainingBlock("918220", risky, List(3) { HighSchoolTrainingFocus.VELOCITY to HighSchoolTrainingIntensity.INTENSIVE }, stopForSafety = true).state
        assertEquals(1, stopped.trainingEvidence.size)
        val regular = kernel.commitTrainingBlock("918220", base, List(3) { HighSchoolTrainingFocus.COMMAND to HighSchoolTrainingIntensity.LIGHT }, stopForSafety = true).state
        assertTrue(regular.trainingEvidence.size in 1..3)
        assertTrue(regular.trainingEvidence.size == 3 || regular.run.phase != HighSchoolPhase.TRAINING || regular.run.lastTraining!!.bloomed)
    }
}
