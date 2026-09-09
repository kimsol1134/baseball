package com.solkim.baseball.android

import com.solkim.baseball.application.fixtures.*
import com.solkim.baseball.application.*

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
        var fontScale by mutableFloatStateOf(1f)
        var tired by mutableIntStateOf(0)
        var side by mutableStateOf(com.solkim.baseball.application.BatSide.RIGHT)
        var selection by mutableStateOf<com.solkim.baseball.application.PitchHudSelection>(com.solkim.baseball.application.PitchHudSelection.Primary)
        val primary = com.solkim.baseball.application.PitchRecommendation(
            com.solkim.baseball.application.PitchCall(com.solkim.baseball.application.PitchKind.FOUR_SEAM, com.solkim.baseball.application.PitchZone(1, 1), com.solkim.baseball.application.ZoneIntent.STRIKE, PitchIntensity.NORMAL), 700, emptyList(), "")
        compose.setContent {
            CompositionLocalProvider(androidx.compose.ui.platform.LocalDensity provides androidx.compose.ui.unit.Density(androidx.compose.ui.platform.LocalDensity.current.density, fontScale)) {
            BaseballMigrationTheme { Box(Modifier.height(420.dp)) {
                PitchControlsCard(lastPitchLine = null, coachTip = null,
                    repertoire = com.solkim.baseball.application.PitchKind.entries, primary = primary, alternative = primary.copy(call = primary.call.copy(pitchType = com.solkim.baseball.application.PitchKind.SLIDER, zone = com.solkim.baseball.application.PitchZone(2, 0))),
                    selection = selection,
                    selectedZone = (selection as? com.solkim.baseball.application.PitchHudSelection.Manual)?.zone ?: primary.call.zone,
                    selectedIntensity = (selection as? com.solkim.baseball.application.PitchHudSelection.Manual)?.intensity ?: PitchIntensity.NORMAL,
                    batSide = side, currentPitchLine = "포심", primaryExplanation = "",
                    holdToReleasePrompt = "길게 눌러 와인드업", ready = true, velocityTenthsKph = 1420, commandRating = 50,
                    autoRelease = false, autoReleaseLabel = "", catcherConfidenceLabel = "", catcherTrustLabel = "", fatigue = tired, canFastForward = tired >= 80,
                    reduceMotion = true, hapticsEnabled = false, soundEnabled = false, tension = 0.0,
                    disturbanceSeed = 1UL, adverseEpisode = false, onSelect = { selection = it }, onDeliver = { delivered++ })
            } }
            }
        }
        val choices = compose.onNodeWithTag("pitch.aimingField").fetchSemanticsNode().boundsInWindow
        for (type in com.solkim.baseball.application.PitchKind.entries) compose.onNodeWithTag("pitch.type.${type.wire}").assertIsDisplayed()
        for (row in 0..2) for (col in 0..2) {
            val zone = compose.onNodeWithTag("pitch.zone.$row.$col").assertIsDisplayed().fetchSemanticsNode().boundsInWindow
            org.junit.Assert.assertTrue("Zone clipped below aiming scene", zone.bottom <= choices.bottom + 1)
            org.junit.Assert.assertTrue("Entire zone must remain tappable", zone.height / androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext.resources.displayMetrics.density >= 47f)
            org.junit.Assert.assertTrue("Zone clipped above aiming scene", zone.top >= choices.top - 1)
        }
        val plate = compose.onNodeWithTag("pitch.aimingPlate").assertIsDisplayed().fetchSemanticsNode().boundsInWindow
        org.junit.Assert.assertTrue("Home plate must not be clipped", plate.height / androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext.resources.displayMetrics.density >= 13f)
        compose.onNodeWithTag("pitch.effort.max_effort").performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag("pitch.type.slider").performScrollTo().performClick().assertIsSelected()
        compose.onNodeWithTag("pitch.zone.2.0").performClick().assertIsSelected()
        compose.onNodeWithTag("pitch.effort.max_effort").performScrollTo().performClick().assertIsSelected()
        compose.runOnIdle {
            val planned = selection as com.solkim.baseball.application.PitchHudSelection.Manual
            org.junit.Assert.assertEquals(com.solkim.baseball.application.PitchKind.SLIDER, planned.pitchType)
            org.junit.Assert.assertEquals(com.solkim.baseball.application.PitchZone(2, 0), planned.zone)
            org.junit.Assert.assertEquals(PitchIntensity.MAX_EFFORT, planned.intensity)
        }
        val bounds = compose.onNodeWithTag("pitch.slider").assertIsDisplayed().fetchSemanticsNode().boundsInWindow
        org.junit.Assert.assertEquals(64f, bounds.height / androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext.resources.displayMetrics.density, 1f)
        for (font in listOf(1f, 1.5f)) for (fatigue in listOf(0, 87)) for (bat in com.solkim.baseball.application.BatSide.entries) {
            compose.runOnIdle { fontScale = font; tired = fatigue; side = bat }
            compose.onNodeWithTag("pitch.slider").assertIsDisplayed()
            if (fatigue >= 80) compose.onNodeWithTag("pitch.exhaustionExit").assertIsDisplayed()
            val density = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext.resources.displayMetrics.density
            for (row in 0..2) for (col in 0..2) {
                val cell = compose.onNodeWithTag("pitch.zone.$row.$col").assertIsDisplayed().fetchSemanticsNode().boundsInWindow
                org.junit.Assert.assertTrue("Full zone at font=$font fatigue=$fatigue side=$bat", cell.height / density >= 47f)
            }
            val home = compose.onNodeWithTag("pitch.aimingPlate").assertIsDisplayed().fetchSemanticsNode().boundsInWindow
            org.junit.Assert.assertTrue("Full plate at font=$font fatigue=$fatigue", home.height / density >= 13f)
        }
        compose.runOnIdle { fontScale = 1f; tired = 0; side = com.solkim.baseball.application.BatSide.RIGHT }
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
            val button = compose.onNodeWithTag("pitch.effort.${intensity.wire}").assertIsDisplayed().performClick().assertIsSelected()
            val outer = button.fetchSemanticsNode().boundsInRoot
            val label = compose.onNodeWithTag("pitch.effort.label.${intensity.wire}", useUnmergedTree = true).fetchSemanticsNode().boundsInRoot
            org.junit.Assert.assertEquals(outer.center.x, label.center.x, 1f)
            org.junit.Assert.assertEquals(outer.center.y, label.center.y, 1f)
            compose.onNodeWithTag("pitch.slider").assertIsDisplayed()
        }
        compose.onNodeWithTag("pitch.effort.controlled").assertIsNotSelected()
    }
}
