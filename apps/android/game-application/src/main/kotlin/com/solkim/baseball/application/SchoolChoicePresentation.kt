package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*

public data class SchoolGrowthComparison(
    val school: HighSchoolSchool,
    val minimum: Int,
    val maximum: Int,
    val breakthroughMinimum: Int,
    val breakthroughMaximum: Int,
    val breakthroughChance: Int,
    val atLimit: Boolean,
)

/** Read-only comparison of the actual first training after choosing each school. */
public object SchoolChoicePresentation {
    public fun strength(school: HighSchoolSchool): String = "${TrainingPresentation.title(school.strength)}에 강점"
    public fun fit(school: HighSchoolSchool): String = when (school.strength) {
        TrainingFocus.STAMINA -> "긴 이닝을 책임지는 투수로"
        TrainingFocus.GAME_PLANNING -> "타자를 읽고 배합으로 승부하는 투수로"
        TrainingFocus.VELOCITY -> "빠른 직구를 주무기로 쓰는 투수로"
        TrainingFocus.BREAKING_BALL -> "결정구로 헛스윙을 끌어내는 투수로"
        else -> "원하는 코스로 승부하는 투수로"
    }
    public fun schools(state: GameAggregateState): List<HighSchoolSchool> = state.highSchool?.run?.let {
        it.schoolOptions.ifEmpty { HighSchoolContentCatalog.schools(it.identity.region) }
    }.orEmpty()

    public fun compare(state: GameAggregateState, focus: TrainingFocus): List<SchoolGrowthComparison> {
        val run = requireNotNull(state.highSchool).run
        require(run.phase == HighSchoolPhase.SCHOOL_SELECTION)
        val kernel = HighSchoolKernel()
        return schools(state).map { school ->
            // chooseSchool is a pure kernel operation. No store dispatch, seed consumption,
            // or saved-state write occurs, and the real first-training opportunity is included.
            val candidate = kernel.chooseSchool(HighSchoolKernel.ChooseSchoolRequest("1", run, school.id)).snapshot
            val preview = kernel.trainingPreview(candidate, focus, TrainingIntensity.STANDARD)
            val before = when (focus) {
                TrainingFocus.VELOCITY -> candidate.pitcher.stuff
                TrainingFocus.COMMAND, TrainingFocus.GAME_PLANNING -> candidate.pitcher.command
                TrainingFocus.BREAKING_BALL -> candidate.pitcher.movement
                else -> candidate.pitcher.stamina
            }
            fun displayed(growth: Int) = AbilityDisplayScale.delta(before, before + growth)
            SchoolGrowthComparison(school, displayed(preview.minimumGrowth), displayed(preview.maximumGrowth),
                displayed(preview.jackpotMinimumGrowth), displayed(preview.jackpotMaximumGrowth),
                preview.jackpotChancePercent, preview.atTalentWall)
        }
    }
    public fun range(minimum: Int, maximum: Int): String = if (minimum == maximum) "+$minimum" else "+$minimum~$maximum"
}
