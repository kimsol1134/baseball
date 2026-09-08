package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import kotlin.test.*

class TrainingPlansTest {
    private fun fixture(): GameAggregateState {
        val k = HighSchoolPhase4Kernel()
        val school = (918220..918250).firstNotNullOf { seed ->
            val begun = k.start(HighSchoolPhase4StartRequest("$seed", "power_prospect", "plans", "2026-W36", "2026-09-05")).state
            val ready = k.completePrologue("$seed", k.beginTutorial(begun).state).state
            k.chooseSchool("$seed", ready, HighSchoolSchoolId.CHEONGAM_DEVELOPMENT).state.takeIf { it.run.schedule.trainingsByChapter.first() >= 3 }
        }
        return GameAggregateState.initial("plans").copy(stage = GameStage.HIGH_SCHOOL, highSchool = school).let { it.copy(commitment = it.recomputeCommitment()) }
    }
    @Test fun balancedPlanExecutesMixedStepsOnceAndKeepsEachReceipt() = runBlocking {
        val store = KotlinGameStore.fromShadowFixture(fixture())
        try {
            val controller = Phase8Controller(store)
            val before = store.current
            val payloads = TrainingPlans.payloads(before, controller.context, "balanced")
            controller.execute(Phase8ScreenId.P006_TRAINING, payloads.first().actionId, payloads)
            val after = store.current
            assertEquals(3, after.highSchool!!.run.totalTrainingsCompleted)
            assertEquals(listOf(TrainingFocus.VELOCITY, TrainingFocus.RECOVERY, TrainingFocus.COMMAND), after.highSchool!!.trainingEvidence.map { it.focus })
            store.dispatchBatch(payloads.map { it.envelope })
            assertEquals(after, store.current)
            assertEquals(before.highSchool!!.run.chapter.number, after.highSchool!!.run.chapter.number)
        } finally { store.close() }
    }
    @Test fun fatigueAndScheduleLimitsNeverPushUnsafeSteps() {
        val state = fixture()
        val school = state.highSchool!!
        val tired = state.copy(highSchool = school.copy(run = school.run.copy(fatigue = 100, armRisk = 60)))
        assertEquals(0, TrainingPlans.availableSteps(tired, TrainingPlans.options.first()))
        assertFailsWith<IllegalArgumentException> { TrainingPlans.payloads(tired, Phase8CommandContext(), "balanced") }
        assertEquals(1, TrainingPlans.availableSteps(tired, TrainingPlans.options.last()))
        val command = TrainingPlans.payloads(tired, Phase8CommandContext(), "condition").single().envelope.command as GameCommand.HighSchool
        assertEquals(listOf(TrainingFocus.RECOVERY to TrainingIntensity.LIGHT), (command.command as HighSchoolPhase4Command.TrainingBlock).requests)
        val lastSlot = state.copy(highSchool = school.copy(run = school.run.copy(chapterTrainingCount = school.run.schedule.trainingsByChapter.first() - 1)))
        assertEquals(1, TrainingPlans.availableSteps(lastSlot, TrainingPlans.options.first()))
    }
    @Test fun planPersistsThroughTheProductionWriter() = runBlocking {
        val directory = Files.createTempDirectory("training-plan-native-")
        try {
            val repo = CSharpLegacyGameStoreRepository(directory, "plan-native")
            val store = KotlinGameStore.open("plan-native", repo, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            val controller = Phase8Controller(store)
            controller.execute(Phase8ScreenId.P001_OPENING, "enterSetup")
            controller.execute(Phase8ScreenId.P002_SETUP, "startHighSchool")
            controller.execute(Phase8ScreenId.P003_PROLOGUE, "beginTutorial")
            controller.execute(Phase8ScreenId.P003_PROLOGUE, "completeTutorial")
            controller.execute(Phase8ScreenId.P005_SCHOOL_SELECTION, "chooseSchool:cheongam_development")
            val plan = TrainingPlans.options.first()
            val count = TrainingPlans.availableSteps(store.current, plan)
            val payloads = TrainingPlans.payloads(store.current, controller.context, plan.id)
            controller.execute(Phase8ScreenId.P006_TRAINING, payloads.first().actionId, payloads)
            assertEquals(plan.steps.take(count).map { it.first }, store.current.highSchool!!.trainingEvidence.map { it.focus })
            assertEquals(store.current.highSchool, repo.load().envelope!!.payload.highSchool)
            store.close()
        } finally { directory.toFile().deleteRecursively() }
    }
}
