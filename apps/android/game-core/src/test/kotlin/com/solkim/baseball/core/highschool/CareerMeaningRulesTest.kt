package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.pitch.*
import com.solkim.baseball.core.pro.*
import kotlin.test.*

class CareerMeaningRulesTest {
    private val core = HighSchoolKernel()
    private val phase4 = HighSchoolPhase4Kernel()
    private fun school(seed: String = "918220"): HighSchoolPhase4State {
        val start = phase4.start(HighSchoolPhase4StartRequest(seed, "power_prospect", "meaning", "2026-W37", "2026-09-08")).state
        val ready = phase4.completePrologue(seed, phase4.beginTutorial(start).state).state
        return phase4.chooseSchool(seed, ready, HighSchoolSchoolId.HAEDONG_POWER).state
    }
    private fun zeroGrowthState(): HighSchoolState = (918220..918250).firstNotNullOf { number ->
        val base = school(number.toString()).run
        val state = core.resignShadowState(base.copy(totalTrainingsCompleted = 1, chapterTrainingCount = 0,
            trainingOpportunity = null, fatigue = 0, pitcher = base.pitcher.copy(command = 30),
            schedule = HighSchoolSchedule(List(8) { 3 }, List(8) { emptyList() })))
        state.takeIf { core.trainingPreview(it, HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.LIGHT).maximumGrowth == 0 }
    }
    @Test fun unproductiveTrainingAccumulatesAndConvertsWithoutLosingProgressOnReload() {
        var state = zeroGrowthState()
        val before = state.pitcher.command
        var earned = 0
        repeat(3) { index ->
            val preview = core.trainingPreview(state, HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.LIGHT)
            state = core.commitTraining(HighSchoolKernel.TrainingRequest((99001 + index).toString(), state,
                HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.LIGHT)).snapshot
            earned += state.development!!.lastExperienceEarned
            assertTrue(state.lastTraining!!.growth in preview.minimumGrowth..maxOf(preview.maximumGrowth, preview.jackpotMaximumGrowth))
            state = HighSchoolStateCodec.decode(HighSchoolStateCodec.encode(state))
        }
        assertTrue(earned >= 105)
        assertEquals(earned / 100, state.pitcher.command - before)
        assertEquals(earned % 100, state.development!!.experience[1])
    }
    @Test fun queuedConversationSupportIsConsumedOnlyByItsTraining() {
        var state = zeroGrowthState()
        state = core.resignShadowState(state.copy(development = HighSchoolDevelopment().supported(HighSchoolTrainingFocus.COMMAND).supported(HighSchoolTrainingFocus.VELOCITY)))
        val preview = core.trainingPreview(state, HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.LIGHT)
        assertTrue(preview.maximumGrowth > 0)
        state = core.commitTraining(HighSchoolKernel.TrainingRequest("1001", state, HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.LIGHT)).snapshot
        state = HighSchoolStateCodec.decode(HighSchoolStateCodec.encode(state))
        assertFalse(state.development!!.hasSupport(HighSchoolTrainingFocus.COMMAND))
        assertTrue(state.development!!.hasSupport(HighSchoolTrainingFocus.VELOCITY))
        assertEquals(state.totalTrainingsCompleted, state.development!!.supportAppliedTraining)
    }
    @Test fun cappedTrainingPreviewsDistinguishBreakthroughAndMastery() {
        val base = zeroGrowthState()
        val capped = core.resignShadowState(base.copy(pitcher = base.pitcher.copy(command = base.talent.command.ceiling)))
        val wall = core.trainingPreview(capped, HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.STANDARD)
        assertTrue(wall.atTalentWall && wall.breakthroughTarget > 0 && !wall.masteryTraining)
        val master = core.resignShadowState(base.copy(pitcher = base.pitcher.copy(command = 80),
            talent = base.talent.copy(command = HighSchoolTalentGrade.S), development = HighSchoolDevelopment().supported(HighSchoolTrainingFocus.COMMAND)))
        assertTrue(core.trainingPreview(master, HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.STANDARD).masteryTraining)
        val after = core.commitTraining(HighSchoolKernel.TrainingRequest("501", master, HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.STANDARD)).snapshot
        assertEquals(80, after.pitcher.command)
        assertTrue(after.pitcher.effectiveMastery.command > master.pitcher.effectiveMastery.command)
    }
    @Test fun roleDeterminesProEntryAndGoalIsSavedAndFrozen() {
        val kernel = ProKernel()
        val base = kernel.startDirect(ProStartDirectRequest("918220", "power_prospect", "목표투수")).state
        for (role in ProRole.entries) {
            val forced = base.copy(phase = ProCareerPhase.IMPORTANT_GAME, week = 1, seasonSegment = ProCatalog.segment(1), role = role, seasonTrigger = ProSeasonTrigger.STANDINGS_RACE)
                .let { it.copy(commitment = kernel.commitment(it)) }
            val state = kernel.reserveImportantGame(forced, "55123").state
            val session = state.activePitch!!
            assertEquals(when (role) { ProRole.STARTER -> 1; ProRole.LONG_RELIEF -> 5; ProRole.SETUP -> 8; ProRole.CLOSER -> 9 }, session.context.inning)
            if (role == ProRole.CLOSER) assertTrue(session.context.scoreDifferential > 0)
            assertNotNull(session.assignment)
            assertEquals(state, ProStateCodec.decode(ProStateCodec.encode(state)))
        }
        val objective = OutingAssignment(OutingRole.STARTER, OutingGoal.CLEAN_FRAME, 3, 0, 1, 0, 0, 0)
        assertEquals(OutingGoalStatus.ACHIEVED, objective.advance(3, 0).advance(6, 4).status)
        assertEquals(1, objective.advance(3, 0).withTrustReward(99).trustReward)
        assertEquals(0, objective.advance(3, 0).withTrustReward(100).trustReward)
        assertEquals(OutingGoalStatus.FAILED, objective.advance(0, 1).advance(3, 1).status)
        assertEquals(OutingGoalStatus.UNFINISHED, objective.advance(1, 0).finish().status)
    }
    @Test fun coachPromiseCreatesAnEarnableStarterTrialAndUnlocksFutureStarts() {
        val base = school()
        val event = HighSchoolContentCatalog.events.first { it.id == "evt-coach-role" }
        val conversation = phase4.commitShadowState(base.copy(run = core.resignShadowState(base.run.copy(
            phase = HighSchoolPhase.RELATIONSHIP, currentRelationshipCategory = "coach", currentRelationshipTarget = HighSchoolRelationshipTarget.COACH, currentRelationshipEvent = event))))
        val offered = phase4.resolveRelationship("77123", conversation, HighSchoolRelationshipResponse.CHALLENGE).state
        assertTrue(offered.run.development!!.starterTrialPending)
        val scenario = HighSchoolContentCatalog.scenarios.first()
        val ready = phase4.commitShadowState(offered.copy(run = core.resignShadowState(offered.run.copy(
            phase = HighSchoolPhase.IMPORTANT_GAME, currentGameScenario = scenario, currentGameScenarioId = scenario.id))))
        val success = (77423..77443).firstNotNullOf { seed ->
            var state = phase4.reserveImportantGame(seed.toString(), ready).state
            assertEquals(1, state.activePitch!!.context.inning)
            assertEquals(OutingGoal.STARTER_TEST, state.activePitch!!.assignment!!.goal)
            var guard = 0
            repeat(2) { inning ->
                while (!state.activePitch!!.ended && guard++ < 100) {
                    val prep = phase4.prepareActivePitch(state)
                    state = phase4.submitPitch(state, state.activePitch!!.sessionId, prep.primaryRecommendation.call, PitchDelivery(1000, 1000)).state
                    state = HighSchoolPhase4StateCodec.decode(HighSchoolPhase4StateCodec.encode(state))
                }
                if (inning == 0 && state.activePitch!!.context.fatigue < 90) state = phase4.continueOuting(state).state
            }
            state.takeIf { it.activePitch!!.ended && it.activePitch!!.assignment!!.status == OutingGoalStatus.ACHIEVED }
        }
        assertEquals(ready.run.managerTrust + 8, success.run.managerTrust)
        val finished = phase4.finishImportantGame(success).state
        assertEquals("achieved", finished.run.development!!.trialOutcome)
        val another = phase4.commitShadowState(finished.copy(run = core.resignShadowState(finished.run.copy(
            phase = HighSchoolPhase.IMPORTANT_GAME, currentGameScenario = scenario, currentGameScenarioId = scenario.id))))
        val next = phase4.reserveImportantGame("81123", another).state
        assertEquals(OutingRole.STARTER, next.activePitch!!.assignment!!.role)
        assertEquals("earned-starter-appearance", next.run.currentGameScenarioId)
    }
}
