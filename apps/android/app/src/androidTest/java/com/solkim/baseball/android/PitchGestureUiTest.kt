package com.solkim.baseball.android

import android.app.Instrumentation
import android.os.SystemClock
import android.view.InputDevice
import android.view.MotionEvent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.test.assertContentDescriptionEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTouchInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import com.solkim.baseball.application.PitchDelivery
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
@OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)
class PitchGestureUiTest {
    @get:Rule val compose = createComposeRule()

    @Test fun defaultSliderIsVisibleAndOneHoldReleaseThrows() {
        val pitches = java.util.Collections.synchronizedList(mutableListOf<PitchDelivery>())
        compose.setContent {
            BaseballMigrationTheme {
                Box(Modifier.fillMaxWidth().semantics { testTagsAsResourceId = true }) {
                    PitchDeliveryControl(
                        autoRelease = false,
                        enabled = true,
                        onDeliver = { pitches.add(it) },
                        hapticsEnabled = false,
                        soundEnabled = false,
                    )
                }
            }
        }
        compose.onNodeWithTag("pitch.slider").assertExists()
        compose.onNodeWithTag("pitch.slider").performTouchInput {
            down(center)
            advanceEventTime(700)
            up()
        }
        compose.waitForIdle()
        assertEquals("hold-to-release slider must throw exactly one pitch", 1, pitches.size)
    }

    @Test fun commandGrowthCannotMoveTheWindowDuringAnActiveGesture() {
        val inst = InstrumentationRegistry.getInstrumentation()
        val command = mutableStateOf(35)
        val delivered = java.util.concurrent.atomic.AtomicInteger(0)
        val copy = com.solkim.baseball.application.GameCopy(com.solkim.baseball.application.GameLanguage.fromTag(inst.targetContext.resources.configuration.locales[0].toLanguageTag()))
        fun label(width: Double) = copy.resolve("control.window.accessibility", com.solkim.baseball.application.GameCopyArgument.Decimal(width))
        compose.mainClock.autoAdvance = false
        compose.setContent { BaseballMigrationTheme { Box(Modifier.fillMaxWidth().semantics { testTagsAsResourceId = true }) {
            PitchDeliveryControl(autoRelease = false, enabled = true, commandRating = command.value,
                onDeliver = { delivered.incrementAndGet() }, soundEnabled = false, hapticsEnabled = false)
        } } }
        compose.mainClock.advanceTimeByFrame()
        compose.waitForIdle()
        val center = sliderCenter()
        val down = SystemClock.uptimeMillis()
        fun event(action: Int) = sendPointer(inst, action, down, center)
        compose.onNodeWithTag("pitch.controlWindow").assertContentDescriptionEquals(label(18.0))
        event(MotionEvent.ACTION_DOWN)
        SystemClock.sleep(200)
        compose.mainClock.advanceTimeBy(200)
        inst.runOnMainSync { command.value = 80 }
        compose.mainClock.advanceTimeByFrame()
        compose.waitForIdle()
        compose.onNodeWithTag("pitch.controlWindow").assertContentDescriptionEquals(label(18.0))
        event(MotionEvent.ACTION_CANCEL)
        compose.mainClock.advanceTimeByFrame()
        compose.waitForIdle()
        assertEquals(0, delivered.get())
        compose.onNodeWithTag("pitch.controlWindow").assertContentDescriptionEquals(label(24.0))
        UiDevice.getInstance(inst).takeScreenshot(java.io.File(inst.targetContext.cacheDir, "control-window-max.png"))
    }

    @Test fun cancellationNeverThrowsAndReleaseStillWorksWithReducedMotion() {
        val inst = InstrumentationRegistry.getInstrumentation()
        val pitches = java.util.Collections.synchronizedList(mutableListOf<PitchDelivery>())
        val host = java.util.concurrent.atomic.AtomicReference<android.view.View>()
        compose.mainClock.autoAdvance = false
        compose.setContent {
            val view = androidx.compose.ui.platform.LocalView.current
            androidx.compose.runtime.SideEffect { host.set(view) }
            BaseballMigrationTheme {
                Box(Modifier.fillMaxWidth().semantics { testTagsAsResourceId = true }) {
                    PitchDeliveryControl(autoRelease = false, enabled = true, onDeliver = { pitches.add(it) },
                        reduceMotion = true, hapticsEnabled = true, soundEnabled = false)
                }
            }
        }
        compose.mainClock.advanceTimeByFrame()
        compose.waitForIdle()
        val center = sliderCenter()
        var down = SystemClock.uptimeMillis()
        sendPointer(inst, MotionEvent.ACTION_DOWN, down, center)
        SystemClock.sleep(400)
        sendPointer(inst, MotionEvent.ACTION_CANCEL, down, center)
        compose.mainClock.advanceTimeByFrame()
        compose.waitForIdle()
        assertTrue("A cancelled gesture must not throw a pitch", pitches.isEmpty())
        down = SystemClock.uptimeMillis()
        sendPointer(inst, MotionEvent.ACTION_DOWN, down, center)
        repeat(6) { SystemClock.sleep(100); compose.mainClock.advanceTimeBy(100) }
        sendPointer(inst, MotionEvent.ACTION_UP, down, center)
        compose.mainClock.advanceTimeByFrame()
        compose.waitForIdle()
        assertEquals("One deliberate release throws exactly once", 1, pitches.size)
        SystemClock.sleep(150)
        inst.runOnMainSync { host.get().pitchTouchFeedback(android.view.HapticFeedbackConstants.CLOCK_TICK, true) }
        SystemClock.sleep(150)
        if (android.os.Build.VERSION.SDK_INT >= 30) {
            inst.runOnMainSync { host.get().pitchTouchFeedback(android.view.HapticFeedbackConstants.CONFIRM, true) }
            SystemClock.sleep(200)
        }
    }

    private fun sliderCenter(): Offset {
        val bounds = compose.onNodeWithTag("pitch.slider").assertExists().fetchSemanticsNode().boundsInWindow
        return bounds.center
    }

    private fun sendPointer(inst: Instrumentation, action: Int, down: Long, position: Offset) {
        val event = MotionEvent.obtain(down, SystemClock.uptimeMillis(), action, position.x, position.y, 0)
        event.source = InputDevice.SOURCE_TOUCHSCREEN
        inst.sendPointerSync(event)
        event.recycle()
    }
}
