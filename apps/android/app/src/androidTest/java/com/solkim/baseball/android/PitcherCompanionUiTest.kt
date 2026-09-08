package com.solkim.baseball.android

import com.solkim.baseball.application.fixtures.*
import com.solkim.baseball.application.*

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Rule
import org.junit.Test
import org.junit.Assert.*

class PitcherCompanionUiTest {
    @get:Rule val compose = createComposeRule()
    @Test fun goalAndPinnedMemoryAreChosenWithoutAdvancingTheCareer() {
        val hs = HighSchoolPhase4Kernel().start(HighSchoolPhase4StartRequest("918220", "power_prospect", "companion-ui", "2026-W37", "2026-09-08")).state
        val c = PitcherCompanion(career = hs.run.careerId, experience = listOf(SignatureExperience("four_seam", 4, 5, 1)),
            memories = listOf(PitchMemory("memory-one", hs.run.careerId, 1, "pitch_strikeout", "four_seam", 1)))
        var state by mutableStateOf(GameAggregateState.initial("companion-ui").copy(stage = GameStage.HIGH_SCHOOL, highSchool = hs, meta = GameMetaState(companion = c)))
        compose.setContent { BaseballMigrationTheme { Surface {
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                CompanionProfile(state, false) { operation, value -> state = state.copy(meta = state.meta.copy(companion = PitcherCompanionRules.apply(state, operation, value))) }
            }
        } } }
        val inst = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation()
        androidx.test.uiautomator.UiDevice.getInstance(inst).takeScreenshot(java.io.File(inst.targetContext.cacheDir, "companion-profile.png"))
        compose.onNodeWithTag("companion.nickname.edit").performScrollTo().performClick()
        compose.onNodeWithTag("companion.nickname").performScrollTo().performTextInput("별빛 포심")
        compose.onNodeWithTag("companion.nickname.save").performScrollTo().performClick()
        assertEquals("별빛 포심", state.meta.companion!!.nickname)
        compose.onNodeWithTag("companion.goal.signature").performScrollTo().performClick()
        compose.onNodeWithTag("companion.goal.progress").performScrollTo().assertTextEquals("0 / 1")
        compose.onNodeWithTag("companion.pin.memory-one").performScrollTo().performClick()
        assertEquals("memory-one", state.meta.companion!!.pinned)
        assertEquals(hs, state.highSchool)
    }
    @Test fun rebornComparisonRemainsUntilThePlayerThrows() {
        var pitches = 0
        compose.setContent { BaseballMigrationTheme {
            PitchDeliveryControl(autoRelease = false, enabled = true, onDeliver = { pitches++ }, previousCommand = 35,
                commandRating = 50, holdComparison = true, soundEnabled = false, hapticsEnabled = false)
        } }
        compose.mainClock.advanceTimeBy(10_000)
        compose.onNodeWithTag("pitch.controlWindow.growth").assertIsDisplayed()
        val bounds = compose.onNodeWithTag("pitch.slider").assertIsDisplayed().fetchSemanticsNode().boundsInWindow
        val inst = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation()
        androidx.test.uiautomator.UiDevice.getInstance(inst).swipe(bounds.center.x.toInt(), bounds.center.y.toInt(), bounds.center.x.toInt() + 1, bounds.center.y.toInt(), 80)
        compose.runOnIdle { assertEquals(1, pitches) }
    }

    @Test fun profileRemainsReadableAtLargeText() {
        val hs = HighSchoolPhase4Kernel().start(HighSchoolPhase4StartRequest("918220", "power_prospect", "companion-font", "2026-W37", "2026-09-08")).state
        val state = GameAggregateState.initial("companion-font").copy(stage = GameStage.HIGH_SCHOOL, highSchool = hs)
        compose.setContent { CompositionLocalProvider(LocalDensity provides Density(LocalDensity.current.density, 1.6f)) {
            BaseballMigrationTheme { Surface { Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                CompanionProfile(state, false) { _, _ -> }
            } } }
        } }
        compose.onNodeWithTag("companion.goal.clean").performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag("companion.goal.best").performScrollTo().assertIsDisplayed()
    }
}
