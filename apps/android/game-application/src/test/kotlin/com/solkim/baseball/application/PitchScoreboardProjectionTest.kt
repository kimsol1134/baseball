package com.solkim.baseball.application

import com.solkim.baseball.core.pitch.BaserunnerStateSnapshot
import kotlinx.coroutines.runBlocking
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class PitchScoreboardProjectionTest {
    @Test
    fun tutorialMoundUsesFirstInningTiedEmptyBasesNotNinth() = runBlocking {
        val store = KotlinGameStore.fromShadowFixture(GameAggregateState.initial("scoreboard-tutorial"))
        val controller = Phase7VerticalController(store)
        controller.enterSetup()
        controller.startHighSchool("민서준")
        controller.beginTutorial()
        val launch = controller.reserveTutorialPitch()
        assertEquals(PitchCareerKind.TUTORIAL, store.current.pitch?.careerKind)
        val board = PitchScoreboardProjection.model(store.current)
        assertEquals("1회", board.inningText)
        assertEquals("동점", board.scoreText)
        assertEquals("0사 주자 없음", board.situationText)
        assertEquals(0, board.balls)
        assertEquals(0, board.strikes)
        assertEquals(0, board.outs)
        assertFalse(board.inningText.contains("9"))
        assertTrue(board.accessibilityLabel.contains("볼 0"))
        assertTrue(board.accessibilityLabel.contains("스트라이크 0"))
        assertTrue(board.accessibilityLabel.contains("아웃 0"))
        assertEquals(launch.sessionId, store.current.pitch?.sessionId)
    }

    @Test
    fun situationLineMatchesIosKoreanGrammar() {
        val empty = BaserunnerStateSnapshot.EMPTY
        assertEquals("2사 주자 없음", PitchScoreboardProjection.situationLine(2, empty))
        val loaded = BaserunnerStateSnapshot(true, true, true, 50)
        assertEquals("0사 만루", PitchScoreboardProjection.situationLine(0, loaded))
        val firstAndThird = BaserunnerStateSnapshot(true, false, true, 50)
        assertEquals("1사 1루·3루", PitchScoreboardProjection.situationLine(1, firstAndThird))
    }
}
