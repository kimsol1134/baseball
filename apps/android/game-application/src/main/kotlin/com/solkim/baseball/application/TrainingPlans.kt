package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.highschool.HighSchoolPhase4Command

public data class TrainingPlan(val id: String, val steps: List<Pair<TrainingFocus, TrainingIntensity>>)

/** Short mixed plans stop at real schedule/safety boundaries, just like individual training. */
public object TrainingPlans {
    public val options: List<TrainingPlan> = listOf(
        TrainingPlan("balanced", listOf(TrainingFocus.VELOCITY to TrainingIntensity.STANDARD, TrainingFocus.RECOVERY to TrainingIntensity.LIGHT, TrainingFocus.COMMAND to TrainingIntensity.STANDARD)),
        TrainingPlan("control", listOf(TrainingFocus.COMMAND to TrainingIntensity.STANDARD, TrainingFocus.GAME_PLANNING to TrainingIntensity.STANDARD, TrainingFocus.RECOVERY to TrainingIntensity.LIGHT)),
        TrainingPlan("condition", listOf(TrainingFocus.RECOVERY to TrainingIntensity.LIGHT, TrainingFocus.STAMINA to TrainingIntensity.STANDARD, TrainingFocus.RECOVERY to TrainingIntensity.LIGHT)),
    )

    public fun label(focus: TrainingFocus): String = when (focus) {
        TrainingFocus.RECOVERY -> "회복"
        TrainingFocus.GAME_PLANNING -> "수싸움"
        TrainingFocus.BREAKING_BALL -> "변화구"
        else -> TrainingPresentation.metric(focus)
    }

    private fun safeSteps(state: GameAggregateState, plan: TrainingPlan): List<Pair<TrainingFocus, TrainingIntensity>> {
        var run = requireNotNull(state.highSchool).run
        if (run.injuryRecovery > 0) return emptyList()
        val remaining = TrainingPresentation.remaining(state)
        val steps = mutableListOf<Pair<TrainingFocus, TrainingIntensity>>()
        for (step in plan.steps.take(remaining)) {
            if (step.first != TrainingFocus.RECOVERY && (run.fatigue >= 75 || run.armRisk >= 55)) break
            steps += step
            val preview = com.solkim.baseball.core.highschool.HighSchoolKernel().trainingPreview(run, step.first, step.second)
            run = run.copy(fatigue = run.fatigue + preview.fatigueChange, armRisk = run.armRisk + preview.armRiskChange)
            if (step.first != TrainingFocus.RECOVERY && (run.fatigue >= 75 || run.armRisk >= 55)) break
        }
        return steps
    }

    public fun availableSteps(state: GameAggregateState, plan: TrainingPlan): Int = safeSteps(state, plan).size

    public fun payloads(state: GameAggregateState, context: Phase8CommandContext, planId: String): List<Phase8CommandPayload> {
        val plan = options.single { it.id == planId }
        val run = requireNotNull(state.highSchool).run
        require(run.phase == HighSchoolPhase.TRAINING && run.injuryRecovery == 0) { "training.plan_unavailable" }
        val steps = safeSteps(state, plan)
        require(steps.isNotEmpty()) { "training.plan_needs_rest" }
        val command = HighSchoolPhase4Command.TrainingBlock(context.seed(state, "training-plan:${plan.id}"), steps, stopForSafety = true)
        // Reuse the existing first-focus action authorization; the captured batch owns the whole plan.
        return Phase8Payloads.batch(state, Phase8ScreenId.P006_TRAINING, "train:${plan.steps.first().first.wire}", listOf(GameCommand.HighSchool(command)))
    }
}
