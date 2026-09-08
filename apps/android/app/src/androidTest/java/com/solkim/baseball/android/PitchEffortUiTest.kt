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
        var selection by mutableStateOf<com.solkim.baseball.application.PitchHudSelection>(com.solkim.baseball.application.PitchHudSelection.Primary)
        val primary = com.solkim.baseball.application.PitchRecommendation(
            com.solkim.baseball.application.PitchCall(com.solkim.baseball.application.PitchKind.FOUR_SEAM, com.solkim.baseball.application.PitchZone(1, 1), com.solkim.baseball.application.ZoneIntent.STRIKE, PitchIntensity.NORMAL), 700, emptyList(), "")
        compose.setContent {
            BaseballMigrationTheme { Box(Modifier.height(420.dp)) {
                PitchControlsCard(lastPitchLine = null, coachTip = null,
                    repertoire = com.solkim.baseball.application.PitchKind.entries, primary = primary, alternative = primary.copy(call = primary.call.copy(pitchType = com.solkim.baseball.application.PitchKind.SLIDER, zone = com.solkim.baseball.application.PitchZone(2, 0))),
                    selection = selection,
                    selectedZone = (selection as? com.solkim.baseball.application.PitchHudSelection.Manual)?.zone ?: primary.call.zone,
                    selectedIntensity = (selection as? com.solkim.baseball.application.PitchHudSelection.Manual)?.intensity ?: PitchIntensity.NORMAL,
                    batSide = com.solkim.baseball.core.pitch.BatSide.RIGHT, currentPitchLine = "포심", primaryExplanation = "",
                    holdToReleasePrompt = "길게 눌러 와인드업", ready = true, velocityTenthsKph = 1420, commandRating = 50,
                    autoRelease = false, autoReleaseLabel = "", catcherConfidenceLabel = "", catcherTrustLabel = "", fatigue = 0,
                    reduceMotion = true, hapticsEnabled = false, soundEnabled = false, tension = 0.0,
                    disturbanceSeed = 1UL, adverseEpisode = false, onSelect = { selection = it }, onDeliver = { delivered++ })
            } }
        }
        val choices = compose.onNodeWithTag("pitch.choices").fetchSemanticsNode().boundsInWindow
        for (type in com.solkim.baseball.application.PitchKind.entries) compose.onNodeWithTag("pitch.type.${type.wire}").assertIsDisplayed()
        for (row in 0..2) for (col in 0..2) {
            val zone = compose.onNodeWithTag("pitch.zone.$row.$col").assertIsDisplayed().fetchSemanticsNode().boundsInWindow
            org.junit.Assert.assertTrue("Zone clipped below selection area", zone.bottom <= choices.bottom + 1)
            org.junit.Assert.assertTrue("Zone clipped above selection area", zone.top >= choices.top - 1)
        }
        compose.onNodeWithTag("pitch.effort.max_effort").assertIsDisplayed()
        compose.onNodeWithTag("pitch.type.slider").performClick().assertIsSelected()
        compose.onNodeWithTag("pitch.zone.2.0").performClick().assertIsSelected()
        compose.onNodeWithTag("pitch.effort.max_effort").performClick().assertIsSelected()
        compose.runOnIdle {
            val planned = selection as com.solkim.baseball.application.PitchHudSelection.Manual
            org.junit.Assert.assertEquals(com.solkim.baseball.application.PitchKind.SLIDER, planned.pitchType)
            org.junit.Assert.assertEquals(com.solkim.baseball.application.PitchZone(2, 0), planned.zone)
            org.junit.Assert.assertEquals(PitchIntensity.MAX_EFFORT, planned.intensity)
        }
        val bounds = compose.onNodeWithTag("pitch.slider").assertIsDisplayed().fetchSemanticsNode().boundsInWindow
        org.junit.Assert.assertEquals(64f, bounds.height / androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext.resources.displayMetrics.density, 1f)
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
