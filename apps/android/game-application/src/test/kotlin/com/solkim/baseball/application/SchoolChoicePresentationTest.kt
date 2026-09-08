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
    @Test fun forecastsMatchActualPostEnrollmentTrainingAndLeaveCareerUntouched() {
        val state = fixture()
        val before = HighSchoolPhase4StateCodec.encode(state.highSchool!!)
        val kernel = HighSchoolKernel()
        for (specialty in SchoolChoicePresentation.schools(state)) {
            val rows = SchoolChoicePresentation.compare(state, specialty.strength)
            assertEquals(4, rows.size)
            for (row in rows) {
                val enrolled = kernel.chooseSchool(HighSchoolKernel.ChooseSchoolRequest("918220", state.highSchool!!.run, row.school.id)).snapshot
                val expected = kernel.trainingPreview(enrolled, specialty.strength, TrainingIntensity.STANDARD)
                val projected = state.copy(highSchool = state.highSchool!!.copy(run = enrolled))
                assertEquals(TrainingPresentation.displayGrowth(projected, specialty.strength, expected.minimumGrowth), row.minimum)
                assertEquals(TrainingPresentation.displayGrowth(projected, specialty.strength, expected.maximumGrowth), row.maximum)
                assertEquals(expected.jackpotChancePercent, row.breakthroughChance)
                assertEquals(expected.atTalentWall, row.atLimit)
            }
        }
        assertContentEquals(before, HighSchoolPhase4StateCodec.encode(state.highSchool!!))
        assertNull(state.highSchool!!.run.school)
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
