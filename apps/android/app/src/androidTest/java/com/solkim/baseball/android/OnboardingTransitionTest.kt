package com.solkim.baseball.android

import androidx.compose.runtime.*
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballMigrationTheme
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

/** Disposable store and the actual mound guidance: no writes to the installed career. */
class OnboardingTransitionTest {
    @get:Rule val compose = createComposeRule()
    @Test fun setupOpensMoundDirectlyAndRepeatedTapCannotSkipGuidance() = runBlocking {
        val store = KotlinGameStore.fromShadowFixture(GameAggregateState.initial("intro-tap-qa"))
        try {
            val controller = ScreenController(store)
            controller.execute(ScreenId.P001_OPENING, "enterSetup")
            var state by mutableStateOf(store.current)
            var launches by mutableIntStateOf(0)
            var started by mutableStateOf(false)
            var deliveries = 0
            compose.setContent { BaseballMigrationTheme {
                if (launches > 0) {
                    PitchDeliveryControl(autoRelease = false, enabled = started, hapticsEnabled = false, soundEnabled = false,
                        onDeliver = { deliveries++ })
                    if (!started) FirstPracticeIntroduction { started = true }
                } else CareerShell(state, false, null, ScreenProjection.preferredScreen(state), controller.context,
                    onNavigate = {}, onAction = { action -> runBlocking {
                        val result = controller.executePlayerAction(action.screenId, action.actionId, action.capturedPayloads)
                        if (result.launch != null) launches++
                        state = store.current
                    } })
            } }
            compose.onNodeWithTag("setup.next").performClick()
            val bounds = compose.onNodeWithTag("setup.confirm").assertIsDisplayed().fetchSemanticsNode().boundsInWindow
            val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
            compose.mainClock.autoAdvance = false
            device.click(bounds.center.x.toInt(), bounds.center.y.toInt())
            compose.mainClock.advanceTimeByFrame()
            compose.waitForIdle()
            assertEquals(1, launches)
            compose.onNodeWithTag("pitch.practiceIntroduction.start").assertIsNotEnabled()
            device.click(bounds.center.x.toInt(), bounds.center.y.toInt())
            compose.mainClock.advanceTimeBy(10_000)
            compose.waitForIdle()
            assertFalse(started)
            assertEquals(0, deliveries)
            assertNull(CareerAccess.school(state)!!.lastPresentation)
            assertEquals(PitchCareerKind.TUTORIAL, state.pitch!!.careerKind)
            compose.onAllNodesWithText("첫 공").assertCountEquals(0)
            compose.onNodeWithTag("pitch.practiceIntroduction").assertIsDisplayed()
            compose.onNodeWithTag("pitch.practiceIntroduction.start").performClick()
            compose.mainClock.advanceTimeByFrame()
            assertTrue(started)
            assertEquals(0, deliveries)
            compose.onNodeWithTag("pitch.practiceIntroduction").assertDoesNotExist()
            compose.onNodeWithTag("pitch.slider").assertIsDisplayed()
            Unit
        } finally { store.close() }
    }
}
