package com.solkim.baseball.android

import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballMigrationTheme
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class Round2FlowUiTest {
    @get:Rule val compose = createComposeRule()

    @Test fun emptyProNameStartsAndChosenWeeklyActionRemainsVisibleAtLargeText() = runBlocking {
        val store = KotlinGameStore.fromShadowFixture(GameAggregateState.initial("round2-pro-ui"))
        try {
            var state by mutableStateOf(store.current)
            var language by mutableStateOf("ko")
            var scale by mutableFloatStateOf(1f)
            var chosen: String? = null
            compose.setContent {
                val config = android.content.res.Configuration(LocalConfiguration.current).apply { setLocale(java.util.Locale.forLanguageTag(language)) }
                CompositionLocalProvider(LocalConfiguration provides config, LocalDensity provides Density(LocalDensity.current.density, scale)) {
                    BaseballMigrationTheme { CareerShell(state, false, null, ScreenProjection.preferredScreen(state), ScreenCommandContext(), {}, { action ->
                        if (action.actionId == "startDirect") {
                            runBlocking { ScreenController(store).execute(action.screenId, action.actionId, action.capturedPayloads) }
                            state = store.current
                        } else chosen = action.actionId
                    }) }
                }
            }
            compose.onNodeWithTag("opening.proMode").performClick()
            compose.onNodeWithTag("opening.startPro").assertIsEnabled().performClick()
            compose.runOnIdle { assertEquals("민서준", CareerAccess.pro(state)!!.identityName) }
            for (locale in listOf("ko", "en", "ja")) for (font in listOf(1f, 1.3f, 1.5f)) {
                compose.runOnIdle { language = locale; scale = font }
                compose.onNodeWithTag("week.commit").assertIsDisplayed()
                compose.onNodeWithTag("week.select.proPlan:refine_command").performScrollTo().performClick()
                compose.onNodeWithTag("week.commit").assertIsDisplayed().performClick()
                compose.runOnIdle { assertEquals("proPlan:refine_command", chosen) }
            }
        } finally { store.close() }
    }

    @Test fun allSetupPresetsUseTheSameHundredPointScaleForTextAndAccessibility() {
        val state = GameAggregateState.initial("round2-setup").withCareers(stage = GameStage.SETUP)
        compose.setContent { BaseballMigrationTheme { CareerShell(state, false, null, ScreenId.P002_SETUP, ScreenCommandContext(), {}, {}) } }
        compose.onNodeWithTag("setup.next").performClick()
        for (preset in HighSchoolDisplayRules.presets) {
            compose.onNodeWithTag("setup.preset.${preset.id}").performScrollTo().performClick()
            compose.onNodeWithTag("setup.preset.stats").performScrollTo()
            for (raw in listOf(preset.baseStuff, preset.baseCommand, preset.baseMovement, preset.baseStamina).distinct()) {
                compose.onAllNodesWithText("${AbilityDisplayScale.rating(raw)} / 100", substring = true).onFirst().assertExists()
            }
        }
        val button = compose.onNodeWithTag("setup.confirm").assertIsDisplayed().fetchSemanticsNode().boundsInWindow
        val width = compose.onRoot().fetchSemanticsNode().boundsInWindow.width
        assertTrue(button.width > width * 0.8f)
    }
}
