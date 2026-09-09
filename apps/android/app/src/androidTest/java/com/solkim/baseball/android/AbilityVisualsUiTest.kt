package com.solkim.baseball.android

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Surface
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.platform.app.InstrumentationRegistry
import com.solkim.baseball.application.*
import com.solkim.baseball.application.fixtures.HighSchoolPhase4Kernel
import com.solkim.baseball.application.fixtures.HighSchoolPhase4StartRequest
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import java.io.File

class AbilityVisualsUiTest {
    @get:Rule val compose = createComposeRule()
    private fun state(): GameAggregateState {
        val hs = HighSchoolPhase4Kernel().start(HighSchoolPhase4StartRequest("918220", "power_prospect", "visual", "2026-W37", "2026-09-09", lifeNumber = 2)).state
        val p = hs.startingPitcher
        val start = listOf(p.stuff, p.command, p.movement, p.stamina)
        val current = listOf(p.stuff + 3, p.command + 2, p.movement + 1, p.stamina)
        val history = listOf(
            AbilityHistoryPoint("prev-start", "previous", 1, false, 1, 0, "start", listOf(30, 30, 30, 30), List(4) { 0 }),
            AbilityHistoryPoint("start", hs.run.careerId, 2, false, 1, 0, "start", start, List(4) { 0 }),
            AbilityHistoryPoint("train", hs.run.careerId, 2, false, 1, 1, "training", current, List(4) { 0 }))
        return GameAggregateState.initial("visual").copy(stage = GameStage.HIGH_SCHOOL,
            highSchool = hs.copy(run = hs.run.copy(pitcher = hs.run.pitcher.copy(stuff = current[0], command = current[1], movement = current[2]))),
            meta = GameMetaState(abilityHistory = history, companion = PitcherCompanion(career = hs.run.careerId, previousStart = listOf(30, 30, 30, 30))))
    }
    private fun capture(name: String) {
        val inst = InstrumentationRegistry.getInstrumentation()
        androidx.test.uiautomator.UiDevice.getInstance(inst).takeScreenshot(File(inst.targetContext.cacheDir, "$name.png"))
    }
    @Test fun fourAbilitiesStayVisibleAndOpenHistoryWithoutChangingThePlayer() {
        val state = state()
        val original = state.recomputeCommitment()
        compose.setContent { BaseballMigrationTheme { Surface { Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
            CorePlayerHeader(state, compact = true)
        } } } }
        (0..3).forEach { compose.onNodeWithTag("ability.current.$it").assertIsDisplayed() }
        capture("ability-home")
        compose.onNodeWithTag("ability.current.1").performClick()
        compose.onNodeWithTag("ability.details").assertIsDisplayed()
        compose.onNodeWithTag("ability.compare.1").performClick()
        compose.onNodeWithText("이전 생 시작 → 이번 생 시작").assertExists()
        capture("ability-rebirth-compare")
        compose.onNodeWithTag("ability.history.chart").performScrollTo().assertIsDisplayed()
        capture("ability-history")
        compose.onNodeWithText("닫기").performClick()
        assertEquals(original, state.recomputeCommitment())
    }
    @Test fun largeTextAndReducedMotionKeepValuesReadable() {
        val state = state().let { it.copy(settings = it.settings.copy(reducedMotionEnabled = true)) }
        compose.setContent {
            val density = LocalDensity.current
            CompositionLocalProvider(LocalDensity provides Density(density.density, 2f)) { BaseballMigrationTheme { Surface {
                Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) { AbilityCard(state, compact = false) }
            } } }
        }
        (0..3).forEach { index ->
            val node = compose.onNodeWithTag("ability.current.$index.value", useUnmergedTree = true)
            node.performScrollTo().assertIsDisplayed()
            val results = mutableListOf<androidx.compose.ui.text.TextLayoutResult>()
            node.performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.GetTextLayoutResult) { it(results) }
            assertTrue(results.isNotEmpty())
            assertEquals(1, results.first().lineCount)
        }
        capture("ability-large-text")
    }
    @Test fun actualChangeBarKeepsTheFinalValueAfterAnimation() {
        compose.setContent { BaseballMigrationTheme { Surface { Column(Modifier.fillMaxWidth().padding(24.dp)) {
            AbilityChangeBars(listOf(40, 40, 40, 40), listOf(42, 40, 41, 40))
        } } } }
        compose.mainClock.advanceTimeBy(1000)
        compose.onNodeWithTag("ability.change.0.value", useUnmergedTree = true).assertTextEquals(AbilityDisplayScale.rating(42).toString())
        compose.onNodeWithTag("ability.change.1").assertDoesNotExist()
        compose.mainClock.advanceTimeBy(10_000)
        compose.onNodeWithTag("ability.change.0").assertIsDisplayed()
        capture("ability-training-growth")
    }
}
