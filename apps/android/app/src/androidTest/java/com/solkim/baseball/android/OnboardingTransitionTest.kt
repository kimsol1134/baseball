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

/** Disposable store; replay real consecutive taps without touching the installed career. */
class OnboardingTransitionTest {
    @get:Rule val compose = createComposeRule()
    @Test fun rapidRepeatedTapCannotSkipIntroduction() = runBlocking {
        val store = KotlinGameStore.fromShadowFixture(GameAggregateState.initial("intro-tap-qa"))
        try {
            val controller = Phase8Controller(store)
            controller.execute(Phase8ScreenId.P001_OPENING, "enterSetup")
            var state by mutableStateOf(store.current)
            var launches = 0
            compose.setContent { BaseballMigrationTheme {
                Phase8Shell(state, false, null, Phase8ScreenProjection.preferredScreen(state), controller.context,
                    onNavigate = {}, onAction = { action ->
                        runBlocking {
                            val result = controller.executePlayerAction(action.screenId, action.actionId, action.capturedPayloads)
                            if (result.launch != null) launches++
                            state = store.current
                        }
                    })
            } }
            compose.onNodeWithTag("setup.next").performClick()
            val bounds = compose.onNodeWithTag("setup.confirm").assertIsDisplayed().fetchSemanticsNode().boundsInWindow
            val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
            compose.mainClock.autoAdvance = false
            device.click(bounds.center.x.toInt(), bounds.center.y.toInt())
            compose.mainClock.advanceTimeByFrame()
            compose.waitForIdle()
            device.click(bounds.center.x.toInt(), bounds.center.y.toInt())
            compose.waitForIdle()
            assertEquals("A repeated tap must not skip the introduction", 0, launches)
            compose.mainClock.advanceTimeBy(10_000)
            compose.waitForIdle()
            assertEquals(0, launches)
            compose.onNodeWithTag("action.beginTutorial").assertIsDisplayed().performClick()
            compose.mainClock.advanceTimeByFrame()
            compose.waitForIdle()
            assertEquals("First-pitch instructions must not launch the mound", 0, launches)
            assertEquals(Phase8ScreenId.P004_PITCH_TUTORIAL, Phase8ScreenProjection.preferredScreen(state))
            assertNull(store.current.pitch)
            compose.onNodeWithText("길게 눌러 와인드업, 초록에서 손을 뗀다. 구종과 코스는 포수가 골라 뒀다.").assertIsDisplayed()
            compose.onNodeWithTag("action.openTutorialPitch").assertIsNotEnabled()
            compose.mainClock.advanceTimeBy(10_000)
            compose.waitForIdle()
            assertEquals("Instructions must remain until an explicit second action", 0, launches)
            compose.onNodeWithTag("action.openTutorialPitch").assertIsDisplayed().performClick()
            compose.mainClock.advanceTimeByFrame()
            assertEquals(1, launches)
        } finally { store.close() }
    }
}
