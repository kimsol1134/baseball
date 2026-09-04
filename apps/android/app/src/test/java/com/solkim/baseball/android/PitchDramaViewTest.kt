package com.solkim.baseball.android

import com.solkim.baseball.application.BattedBall
import com.solkim.baseball.application.PitchOutcome
import com.solkim.baseball.design.BaseballColors
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PitchDramaViewTest {

    @Test
    fun plateFiguresConstantsAreValid() {
        assertTrue("batter aspect ratio must be positive", PlateFigures.BATTER_ASPECT > 0f)
        assertTrue("catcher aspect ratio must be positive", PlateFigures.CATCHER_ASPECT > 0f)
        assertEquals(PlateFigures.ASSET_OPACITY, 0.13f, 0.001f)
    }

    @Test
    fun outcomeToneMapsExpectedColors() {
        // 스트라이크 및 인플레이 아웃 -> action (라임 계열)
        assertEquals(BaseballColors.action, outcomeTone(PitchOutcome.SWINGING_STRIKE))
        assertEquals(BaseballColors.action, outcomeTone(PitchOutcome.CALLED_STRIKE))
        assertEquals(BaseballColors.action, outcomeTone(PitchOutcome.IN_PLAY_OUT))

        // 볼, 파울, 사구 -> warning (주황/황색 계열)
        assertEquals(BaseballColors.warning, outcomeTone(PitchOutcome.BALL))
        assertEquals(BaseballColors.warning, outcomeTone(PitchOutcome.FOUL))
        assertEquals(BaseballColors.warning, outcomeTone(PitchOutcome.HIT_BY_PITCH))

        // 안타, 장타, 홈런 -> negative (빨강/핑크 계열)
        assertEquals(BaseballColors.negative, outcomeTone(PitchOutcome.SINGLE))
        assertEquals(BaseballColors.negative, outcomeTone(PitchOutcome.DOUBLE))
        assertEquals(BaseballColors.negative, outcomeTone(PitchOutcome.TRIPLE))
        assertEquals(BaseballColors.negative, outcomeTone(PitchOutcome.HOME_RUN))
    }

    @Test
    fun localizedVerdictProducesReadableKoreanLabels() {
        assertEquals("헛스윙 삼진", localizedVerdict(PitchOutcome.SWINGING_STRIKE, null))
        assertEquals("루킹 스트라이크", localizedVerdict(PitchOutcome.CALLED_STRIKE, null))
        assertEquals("볼", localizedVerdict(PitchOutcome.BALL, null))
        assertEquals("파울", localizedVerdict(PitchOutcome.FOUL, null))
        assertEquals("몸에 맞는 공", localizedVerdict(PitchOutcome.HIT_BY_PITCH, null))
        assertEquals("1루타", localizedVerdict(PitchOutcome.SINGLE, null))
        assertEquals("2루타", localizedVerdict(PitchOutcome.DOUBLE, null))
        assertEquals("3루타", localizedVerdict(PitchOutcome.TRIPLE, null))
        assertEquals("홈런!", localizedVerdict(PitchOutcome.HOME_RUN, null))

        // 인플레이 아웃은 발사각도에 따라 뜬공/땅볼 분류
        val flyBall = BattedBall(1300, 300, 0, 400) // 30도
        assertEquals("뜬공 아웃", localizedVerdict(PitchOutcome.IN_PLAY_OUT, flyBall))

        val groundBall = BattedBall(1300, 50, 0, 400) // 5도
        assertEquals("땅볼 아웃", localizedVerdict(PitchOutcome.IN_PLAY_OUT, groundBall))
    }

    @Test
    fun fielderHomePositionsAreValid() {
        val (pitcherDist, pitcherDeg) = fielderHome("pitcher")
        assertEquals(18.4f, pitcherDist, 0.1f)
        assertEquals(0f, pitcherDeg, 0.1f)

        val (cfDist, cfDeg) = fielderHome("centerField")
        assertEquals(96f, cfDist, 0.1f)
        assertEquals(0f, cfDeg, 0.1f)

        val (ssDist, ssDeg) = fielderHome("shortstop")
        assertEquals(38f, ssDist, 0.1f)
        assertEquals(-20f, ssDeg, 0.1f)
    }
}
