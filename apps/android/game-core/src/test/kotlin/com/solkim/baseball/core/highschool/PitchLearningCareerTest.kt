package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.pitch.*
import com.solkim.baseball.core.pro.*
import kotlin.test.*

class PitchLearningCareerTest {
    private val kernel = HighSchoolPhase4Kernel()
    private val core = HighSchoolKernel()
    private val request = HighSchoolPhase4StartRequest("918220", "power_prospect", "learning-test", "2026-W36", "2026-09-05")
    @Test fun newCareerLearnsUnlocksAndRestoresWhileLegacyKeepsEveryPitch() {
        val legacy = kernel.start(request).state
        assertNull(legacy.run.pitchLearningProject)
        assertFalse(String(HighSchoolStateCodec.encode(legacy.run)).contains("pitchLearningProject"))
        assertEquals(4, legacy.run.toPitcherSnapshot().pitchProfiles!!.size)
        var state = kernel.startConfigured(request, PitchKind.FOUR_SEAM, PitchKind.CURVEBALL).state
        assertEquals(3, state.run.toPitcherSnapshot().pitchProfiles!!.size)
        state = kernel.completePrologue("918220", state).state
        state = kernel.chooseSchool("918220", state, HighSchoolSchoolId.HAEDONG_POWER).state
        var run = state.run
        for (credits in listOf(3, 6, 9)) {
            // Isolate the learning thresholds from randomly scheduled career milestones.
            run = core.resignShadowState(run.copy(phase = HighSchoolPhase.TRAINING, chapterTrainingCount = 0, fatigue = 0, injuryRecovery = 0))
            run = core.commitTraining(HighSchoolKernel.TrainingRequest("918220", run, HighSchoolTrainingFocus.BREAKING_BALL, HighSchoolTrainingIntensity.INTENSIVE, PitchKind.CURVEBALL)).snapshot
            assertEquals(credits, run.pitchLearningProject!!.practiceCredits)
            assertEquals(if (credits < 5) 3 else 4, run.toPitcherSnapshot().pitchProfiles!!.size)
            assertEquals(run, HighSchoolStateCodec.decode(HighSchoolStateCodec.encode(run)))
        }
        assertEquals(PitchUsageRole.SECONDARY, run.pitcher.pitchProfiles.single { it.pitchType == PitchKind.CURVEBALL }.role)
        assertTrue(run.pitchLearningProject!!.completed)
    }
    @Test fun linkedCommandAndProductionProEnvelopePreserveLearningAndWeeklyProgress() {
        val run = kernel.startConfigured(request, PitchKind.FOUR_SEAM, PitchKind.CURVEBALL).state.run
        val fullPitcher = run.copy(pitchLearningProject = null).toPitcherSnapshot()
        val proKernel = ProKernel()
        val request = ProStartLinkedRequest("918220", run.careerId, run.identity.name, fullPitcher, ProCatalog.teamForSeed(918220UL).id, 72, pitchLearningProject = run.pitchLearningProject)
        var pro = proKernel.startLinked(request).state
        assertEquals(run.pitchLearningProject, pro.pitchLearningProject)
        pro = proKernel.signContract(pro, "918220").state
        assertEquals(pro, ProStateCodec.decode(ProStateCodec.encode(pro)))
        val next = proKernel.planWeek(pro, "918220", ProWeekPlan.DEVELOP_MOVEMENT, PitchKind.CURVEBALL).state
        assertEquals(2, next.pitchLearningProject!!.practiceCredits)
        assertEquals(next, ProStateCodec.decode(ProStateCodec.encode(next)))
    }
    @Test fun goodUsesRequireDistinctPlateAppearancesAndSurviveResume() {
        var project = PitchLearningProject(PitchKind.CURVEBALL, 7)
        project = project.use(PitchKind.CURVEBALL, "game:pa:1", PitchDelivery(800, 800), 700)
        project = PitchLearningProject.decode(project.token())
        assertEquals(1, project.use(PitchKind.CURVEBALL, "game:pa:1", PitchDelivery(900, 900), 800).qualityUses)
        assertFalse(project.use(PitchKind.SLIDER, "game:pa:2", PitchDelivery(900, 900), 800).completed)
        assertTrue(project.use(PitchKind.CURVEBALL, "game:pa:2", PitchDelivery(800, 800), 700).completed)
    }
}
