package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import kotlin.test.*

class SchoolChoicePresentationTest {
    private fun fixture(): GameAggregateState {
        val kernel = HighSchoolPhase4Kernel()
        val start = kernel.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "school-compare", "2026-W37", "2026-09-08")).state
        val school = kernel.completePrologue("918220", kernel.beginTutorial(start).state).state
        return GameAggregateState.initial("school-compare").copy(highSchool = school)
    }
    @Test fun goalsRecommendDifferentSpecialtiesWithoutChangingThePlayer() {
        val base = fixture()
        val hs = base.highSchool!!
        val state = base.copy(highSchool = hs.copy(run = hs.run.copy(
            pitcher = hs.run.pitcher.copy(stuff = 50, command = 36, movement = 42, stamina = 25))))
        val before = state.highSchool
        val strength = SchoolChoicePresentation.compare(state, SchoolDevelopmentGoal.STRENGTH)
        val weakness = SchoolChoicePresentation.compare(state, SchoolDevelopmentGoal.WEAKNESS)
        assertEquals(4, strength.map { it.school.strength }.distinct().size)
        assertEquals(listOf(TrainingFocus.VELOCITY), strength.filter { it.recommended }.map { it.school.strength })
        assertEquals(listOf(TrainingFocus.STAMINA), weakness.filter { it.recommended }.map { it.school.strength })
        assertEquals(before, state.highSchool)
        assertNull(state.highSchool!!.run.school)
    }
    @Test fun tiesAndTalentLimitsNeverInventABestSchool() {
        val base = fixture()
        val hs = base.highSchool!!
        val tied = base.copy(highSchool = hs.copy(run = hs.run.copy(
            pitcher = hs.run.pitcher.copy(stuff = 30, command = 30, movement = 30, stamina = 30))))
        for (goal in SchoolDevelopmentGoal.entries) assertTrue(SchoolChoicePresentation.compare(tied, goal).none { it.recommended })
        val capped = base.copy(highSchool = hs.copy(run = hs.run.copy(
            pitcher = hs.run.pitcher.copy(stuff = 80, command = 80, movement = 80, stamina = 80))))
        for (goal in SchoolDevelopmentGoal.entries) {
            assertTrue(SchoolChoicePresentation.compare(capped, goal).all { it.atLimit && !it.recommended })
        }
        val oneOpen = capped.copy(highSchool = capped.highSchool!!.copy(run = capped.highSchool!!.run.copy(
            pitcher = capped.highSchool!!.run.pitcher.copy(stuff = 30))))
        for (goal in SchoolDevelopmentGoal.entries) assertEquals(listOf(TrainingFocus.VELOCITY),
            SchoolChoicePresentation.compare(oneOpen, goal).filter { it.recommended }.map { it.school.strength })
    }
    @Test fun selectionExplainsTrainingInsteadOfNamesAndUnsupportedPenalties() {
        val state = fixture()
        val model = Phase8ScreenProjection.project(state, Phase8ScreenId.P005_SCHOOL_SELECTION)
        val text = model.sections.flatMap { it.rows }.joinToString { "${it.value} ${it.detail}" }
        for (school in SchoolChoicePresentation.schools(state)) {
            assertFalse(text.contains(school.coachName))
            assertFalse(text.contains(school.catcherName))
            assertFalse(text.contains(school.tradeoff))
            for (language in listOf(GameLanguage.ENGLISH, GameLanguage.JAPANESE)) {
                val copy = GameCopy(language)
                assertFalse(copy.legacy(SchoolChoicePresentation.strength(school)).any { it in '가'..'힣' })
                assertFalse(copy.legacy(SchoolChoicePresentation.fit(school)).any { it in '가'..'힣' })
            }
        }
    }
}
