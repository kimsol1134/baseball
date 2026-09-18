package com.solkim.baseball.android

import com.solkim.baseball.application.fixtures.*
import com.solkim.baseball.application.*

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class OutingFeedbackUiTest {
    @get:Rule val compose = createComposeRule()

    @Test fun inningBreakWaitsForAnExplicitChoice() {
        var continued = 0
        var simulated = 0
        compose.setContent { BaseballMigrationTheme {
            PitchResultCard(outcome = PitchOutcome.IN_PLAY_OUT, battedBall = null, velocityTenthsKph = 1420,
                delivery = null, plateXMm = null, plateYMm = null, outingContinues = false, plateEnded = true,
                outingLine = "1.0이닝", onReplay = {}, onInspect = {}, onNextPitch = null,
                onPostgame = { simulated++ }, onContinueInning = { continued++ })
        } }
        compose.mainClock.advanceTimeBy(10_000)
        compose.onNodeWithTag("pitch.nextInning").assertIsDisplayed()
        compose.onNodeWithTag("pitch.simulateRemainder").assertIsDisplayed()
        compose.runOnIdle { assertEquals(0, continued + simulated) }
        compose.onNodeWithTag("pitch.nextInning").performClick()
        compose.runOnIdle { assertEquals(1, continued); assertEquals(0, simulated) }
        compose.onNodeWithTag("pitch.simulateRemainder").performClick()
        compose.runOnIdle { assertEquals(1, simulated) }
    }

    @Test fun everyAwakeningUsesUniqueArtworkAndTapDeliveryRemainsNeutral() {
        val assets = HighSchoolAwakening.entries.map { skillCelebrationArt(it.wire) }
        assertEquals(18, assets.distinct().size)
        var delivery: PitchDelivery? = null
        compose.setContent { BaseballMigrationTheme {
            PitchDeliveryControl(autoRelease = true, enabled = true, hapticsEnabled = false, soundEnabled = false,
                onDeliver = { delivery = it })
        } }
        compose.onNodeWithText("탭 한 번으로 던지기").assertIsDisplayed().performClick()
        compose.runOnIdle { assertEquals(PitchDelivery.NEUTRAL, delivery); assertFalse(delivery!!.isPerfectRelease) }
    }
}
