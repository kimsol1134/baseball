package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import kotlin.test.*

class ChapterProgressPresentationTest {
    @Test fun onlyCurrentChapterTrainingAndPlayedGamesAreAttributedToPlayer() {
        val kernel = HighSchoolPhase4Kernel()
        val hs = kernel.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "chapter-progress", "2026-W36", "2026-09-05")).state
        val id = hs.run.careerId
        val evidence = HighSchoolTrainingEvidence(id, 1, 1, 1, HighSchoolTrainingFocus.VELOCITY, HighSchoolTrainingIntensity.LIGHT, growthPoints = 1, fatigueDelta = 4)
        val game = HighSchoolSeasonLine(id, 1, 1, 1, 12, 2, 1, 1, 0, 0, emptyList(), outs = 3)
        val state = GameAggregateState.initial("chapter-progress").copy(highSchool = hs.copy(
            trainingEvidence = listOf(evidence, evidence.copy(chapterNumber = 2, trainingNumber = 2), evidence.copy(careerId = "other", trainingNumber = 3)),
            seasonLog = listOf(game, game.copy(played = false), game.copy(chapter = 2), game.copy(careerId = "other"))))
        val rows = ChapterProgressPresentation.training(state)
        assertEquals(1, rows.size)
        assertEquals(1, rows.single().count)
        assertEquals(AbilityDisplayScale.rating(hs.run.pitcher.stuff), rows.single().currentRating)
        assertEquals(listOf(game), ChapterProgressPresentation.games(state))
        assertEquals(hs.run.schedule.trainingsByChapter[1], ChapterProgressPresentation.nextTrainings(state))
        val oldSave = state.copy(highSchool = hs.copy(trainingEvidence = emptyList(), seasonLog = emptyList()))
        assertTrue(ChapterProgressPresentation.training(oldSave).isEmpty())
        assertTrue(ChapterProgressPresentation.games(oldSave).isEmpty())
        val noGrowth = state.copy(highSchool = hs.copy(trainingEvidence = listOf(evidence.copy(growthPoints = 0))))
        assertNull(ChapterProgressPresentation.training(noGrowth).single().currentRating)
    }
}
