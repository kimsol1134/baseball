package com.solkim.baseball.android

import com.solkim.baseball.application.BattedBall
import com.solkim.baseball.application.PitchDramaCamera
import com.solkim.baseball.application.PitchOutcome
import com.solkim.baseball.design.BaseballColors
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PitchDramaViewTest {

    @Test fun stableReleaseFeedbackMatchesTheVisibleGreenThreshold() {
        assertEquals("릴리스 좋았다", releaseTimingLabel(820))
        assertEquals("타이밍이 살짝 어긋났다", releaseTimingLabel(819))
        assertEquals("릴리스는 좋았다. 조준이 흔들렸다", releaseTimingLabel(820, 500))
        assertEquals("★ 퍼펙트 릴리스", releaseTimingLabel(975))
        assertFalse(releaseTimingLabel(974).contains("퍼펙트"))
    }

    @Test
    fun plateFiguresConstantsAreValid() {
        assertTrue("batter aspect ratio must be positive", PlateFigures.BATTER_ASPECT > 0f)
        assertTrue("catcher aspect ratio must be positive", PlateFigures.CATCHER_ASPECT > 0f)
        assertEquals(0.5f, PlateFigures.ASSET_OPACITY, 0.001f)
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
        assertEquals("헛스윙", localizedVerdict(PitchOutcome.SWINGING_STRIKE, null))
        assertEquals("루킹 스트라이크", localizedVerdict(PitchOutcome.CALLED_STRIKE, null))
        assertEquals("볼", localizedVerdict(PitchOutcome.BALL, null))
        assertEquals("파울", localizedVerdict(PitchOutcome.FOUL, null))
        assertEquals("몸에 맞는 공", localizedVerdict(PitchOutcome.HIT_BY_PITCH, null))
        assertEquals("안타", localizedVerdict(PitchOutcome.SINGLE, null))
        assertEquals("2루타", localizedVerdict(PitchOutcome.DOUBLE, null))
        assertEquals("3루타", localizedVerdict(PitchOutcome.TRIPLE, null))
        assertEquals("홈런", localizedVerdict(PitchOutcome.HOME_RUN, null))

        val flyBall = BattedBall(1300, 300, 0, 400)
        assertEquals("뜬공 아웃", localizedVerdict(PitchOutcome.IN_PLAY_OUT, flyBall))
        val lineDrive = BattedBall(1300, 180, 0, 400)
        assertEquals("직선타 아웃", localizedVerdict(PitchOutcome.IN_PLAY_OUT, lineDrive))
        val groundBall = BattedBall(1300, 50, 0, 400)
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

    @Test
    fun catcherCutResultFreezeKeepsTakenPitchesOnCatcherCamera() {
        assertTrue(isTakenPitchCatcherFreeze(PitchOutcome.CALLED_STRIKE, 1f))
        assertTrue(isTakenPitchCatcherFreeze(PitchOutcome.SWINGING_STRIKE, PitchDramaCamera.CONTACT_PROGRESS))
        assertTrue(isTakenPitchCatcherFreeze(PitchOutcome.BALL, 1f))
        assertTrue(isTakenPitchCatcherFreeze(PitchOutcome.FOUL, 1f))
        assertTrue(isTakenPitchCatcherFreeze(PitchOutcome.HIT_BY_PITCH, 1f))
        assertFalse(isTakenPitchCatcherFreeze(PitchOutcome.SINGLE, 1f))
        assertFalse(isTakenPitchCatcherFreeze(PitchOutcome.HOME_RUN, 1f))
        assertFalse(isTakenPitchCatcherFreeze(PitchOutcome.IN_PLAY_OUT, 1f))
        assertFalse(isTakenPitchCatcherFreeze(PitchOutcome.CALLED_STRIKE, 0.2f))
        assertFalse(isTakenPitchCatcherFreeze(null, 1f))
        assertTrue(isCatcherCutAfterContact(PitchOutcome.SINGLE, PitchDramaCamera.CONTACT_PROGRESS))
        assertFalse(isCatcherCutAfterContact(PitchOutcome.SINGLE, PitchDramaCamera.CUT_PROGRESS))
    }

    @Test
    fun resultFreezeZoneAlphasMatchTheVisiblePlate() {
        assertEquals(0.85f, RESULT_ZONE_STROKE_ALPHA, 0.001f)
        assertEquals(0.80f, RESULT_ZONE_GRID_ALPHA, 0.001f)
        assertEquals(0.85f, LIVE_ZONE_STROKE_ALPHA, 0.001f)
        assertEquals(0.80f, LIVE_ZONE_GRID_ALPHA, 0.001f)
        assertEquals(0.85f, zoneStrokeAlpha(PitchOutcome.BALL, 1f, 0f), 0.001f)
        assertEquals(0.80f, zoneGridAlpha(PitchOutcome.BALL, 1f), 0.001f)
        assertEquals(0.85f, zoneStrokeAlpha(PitchOutcome.BALL, 0.1f, 0f), 0.001f)
        assertEquals(0.80f, zoneGridAlpha(PitchOutcome.BALL, 0.1f), 0.001f)
        assertEquals(1.0f, zoneStrokeAlpha(PitchOutcome.CALLED_STRIKE, 0.1f, 1f), 0.001f)
    }

    @Test
    fun keepFullIncomingTrailOnlyForNonBattedCatcherFreeze() {
        assertTrue(keepFullIncomingTrail(PitchOutcome.CALLED_STRIKE, 1f))
        assertTrue(keepFullIncomingTrail(PitchOutcome.SWINGING_STRIKE, 1f))
        assertTrue(keepFullIncomingTrail(PitchOutcome.BALL, 1f))
        assertTrue(keepFullIncomingTrail(PitchOutcome.HIT_BY_PITCH, 1f))
        assertFalse(keepFullIncomingTrail(PitchOutcome.FOUL, 1f))
        assertFalse(keepFullIncomingTrail(PitchOutcome.SINGLE, 1f))
        assertFalse(keepFullIncomingTrail(PitchOutcome.CALLED_STRIKE, 0.1f))
        assertTrue(RESULT_LANDING_DOT_RADIUS_DP in 4f..6f)
        assertTrue(RESULT_LANDING_RING_RADIUS_DP > RESULT_LANDING_DOT_RADIUS_DP)
        // The trail fades in toward the plate so the crossing point, which is what the call reads,
        // stays the brightest thing on the freeze.
        assertEquals(0.08f, RESULT_TRAIL_START_ALPHA, 0.001f)
        assertEquals(0.90f, RESULT_TRAIL_END_ALPHA, 0.001f)
        assertTrue(RESULT_TRAIL_END_ALPHA > RESULT_TRAIL_START_ALPHA * 8f)
    }
}
