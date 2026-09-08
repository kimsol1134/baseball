package com.solkim.baseball.android

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.runtime.*
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.solkim.baseball.application.PitchIntensity
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Rule
import org.junit.Test

class PitchEffortUiTest {
    @get:Rule val compose = createComposeRule()
    @Test fun fullPitchCardKeepsEffortAndManualSliderOnScreen() {
        var delivered = 0
        compose.setContent {
            BaseballMigrationTheme { Box(Modifier.height(420.dp)) {
                PitchControlsCard(lastPitchLine = null, coachTip = null,
                    repertoire = listOf(com.solkim.baseball.application.PitchKind.FOUR_SEAM), primary = null, alternative = null,
                    selection = com.solkim.baseball.application.PitchHudSelection.Primary,
                    selectedZone = com.solkim.baseball.application.PitchZone(1, 1),
                    batSide = com.solkim.baseball.core.pitch.BatSide.RIGHT, currentPitchLine = "포심", primaryExplanation = "",
                    holdToReleasePrompt = "길게 눌러 와인드업", ready = true, velocityTenthsKph = 1420, commandRating = 50,
                    autoRelease = false, autoReleaseLabel = "", catcherConfidenceLabel = "", catcherTrustLabel = "", fatigue = 0,
                    reduceMotion = true, hapticsEnabled = false, soundEnabled = false, tension = 0.0,
                    disturbanceSeed = 1UL, adverseEpisode = false, onSelect = {}, onDeliver = { delivered++ })
            } }
        }
        compose.onNodeWithTag("pitch.effort.max_effort").assertIsDisplayed()
        val bounds = compose.onNodeWithTag("pitch.slider").assertIsDisplayed().fetchSemanticsNode().boundsInWindow
        val inst = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation()
        val device = androidx.test.uiautomator.UiDevice.getInstance(inst)
        device.takeScreenshot(java.io.File(inst.targetContext.cacheDir, "pitch-effort-review.png"))
        device.swipe(bounds.center.x.toInt(), bounds.center.y.toInt(), bounds.center.x.toInt() + 1, bounds.center.y.toInt(), 80)
        compose.runOnIdle { org.junit.Assert.assertEquals(1, delivered) }
    }

    @Test fun choicesStayVisibleAndSelectedEffortIsSeparateFromRecommendation() {
        compose.setContent {
            var selected by remember { mutableStateOf(PitchIntensity.NORMAL) }
            BaseballMigrationTheme { Column {
                PitchEffortControl(selected, PitchIntensity.CONTROLLED, true) { selected = it }
                PitchDeliveryControl(autoRelease = false, enabled = true, onDeliver = {}, hapticsEnabled = false, soundEnabled = false)
            } }
        }
        PitchIntensity.entries.forEach { intensity ->
            compose.onNodeWithTag("pitch.effort.${intensity.wire}").assertIsDisplayed().performClick().assertIsSelected()
            compose.onNodeWithTag("pitch.slider").assertIsDisplayed()
        }
        compose.onNodeWithTag("pitch.effort.controlled").assertIsNotSelected()
    }
}
