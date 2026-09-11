package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*

public enum class SchoolDevelopmentGoal { STRENGTH, WEAKNESS }

public data class SchoolFitComparison(
    val school: HighSchoolSchool,
    val currentRating: Int,
    val atLimit: Boolean,
    val recommended: Boolean,
)

/** Compares lasting training specialties against the player's present abilities. */
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

    public fun compare(state: GameAggregateState, goal: SchoolDevelopmentGoal): List<SchoolFitComparison> {
        val run = requireNotNull(state.highSchool).run
        val ratings = schools(state).associateWith { school -> when (school.strength) {
            TrainingFocus.VELOCITY -> run.pitcher.stuff
            TrainingFocus.COMMAND, TrainingFocus.GAME_PLANNING -> run.pitcher.command
            TrainingFocus.BREAKING_BALL -> run.pitcher.movement
            else -> run.pitcher.stamina
        } }
        val eligible = ratings.filter { (school, rating) -> rating < minOf(80, run.talent.grade(school.strength).ceiling) }
        // A tie is kept as a tie; do not invent a single best school for an evenly built player.
        val target = if (eligible.size > 1 && eligible.values.distinct().size == 1) null else when (goal) {
            SchoolDevelopmentGoal.STRENGTH -> eligible.values.maxOrNull()
            SchoolDevelopmentGoal.WEAKNESS -> eligible.values.minOrNull()
        }
        return ratings.map { (school, rating) -> SchoolFitComparison(school, AbilityDisplayScale.rating(rating),
            school !in eligible, target != null && rating == target && school in eligible) }
    }
}

public data class SchoolChoiceView(
    val schools: List<HighSchoolSchool>,
    val strengthComparisons: List<SchoolFitComparison>,
    val weaknessComparisons: List<SchoolFitComparison>,
) {
    public companion object {
        public fun resolve(state: GameAggregateState): SchoolChoiceView = SchoolChoiceView(
            schools = SchoolChoicePresentation.schools(state),
            strengthComparisons = SchoolChoicePresentation.compare(state, SchoolDevelopmentGoal.STRENGTH),
            weaknessComparisons = SchoolChoicePresentation.compare(state, SchoolDevelopmentGoal.WEAKNESS),
        )
    }
}
