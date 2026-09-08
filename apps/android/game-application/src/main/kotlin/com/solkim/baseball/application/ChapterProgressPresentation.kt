package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolTrainingFocus

public data class ChapterTrainingProgress(val focus: TrainingFocus, val count: Int, val currentRating: Int?)

/** Current-chapter facts only. Old saves without evidence never acquire invented growth. */
public object ChapterProgressPresentation {
    public fun training(state: GameAggregateState): List<ChapterTrainingProgress> {
        val school = state.highSchool ?: return emptyList()
        val run = school.run
        return school.trainingEvidence.filter { it.careerId == run.careerId && it.chapterNumber == run.chapter.number }
            .groupBy { it.focus }.map { (focus, evidence) ->
                val rating = if (focus == HighSchoolTrainingFocus.RECOVERY || evidence.sumOf { it.growthPoints } <= 0) null else when (focus) {
                    TrainingFocus.VELOCITY -> run.pitcher.stuff
                    TrainingFocus.COMMAND, TrainingFocus.GAME_PLANNING -> run.pitcher.command
                    TrainingFocus.BREAKING_BALL -> run.pitcher.movement
                    else -> run.pitcher.stamina
                }
                ChapterTrainingProgress(focus, evidence.size, rating?.let(AbilityDisplayScale::rating))
            }
    }

    public fun games(state: GameAggregateState) = state.highSchool?.let { school ->
        school.seasonLog.filter { it.careerId == school.run.careerId && it.chapter == school.run.chapter.number && it.played }
    }.orEmpty()

    public fun nextTrainings(state: GameAggregateState): Int = state.highSchool?.run?.let {
        it.schedule.trainingsByChapter.getOrNull(it.chapter.number)
    } ?: 0
}
