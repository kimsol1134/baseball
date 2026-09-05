package com.solkim.baseball.android

import android.content.Intent
import android.os.SystemClock
import android.view.MotionEvent
import android.view.InputDevice
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import com.solkim.baseball.application.GameStage
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** Locale-independent real gestures against the disposable launch-QA package only. */
@RunWith(AndroidJUnit4::class)
class FirstPitchLocalizedSmokeTest {
    @Test(timeout = 180_000)
    fun freshPlayerCanThrowWithTheDefaultSlider() {
        val inst = InstrumentationRegistry.getInstrumentation()
        val context = inst.targetContext
        require(context.packageName.endsWith(".compose.qa")) { "Use -PbaseballLaunchQa=true; never reset an existing player save" }
        val app = context.applicationContext as BaseballApplication
        assertEquals("Harness must provide a fresh QA install", GameStage.OPENING, app.gameStore.current.stage)
        assertFalse(app.gameStore.current.settings.autoReleaseEnabled)
        val requestedRate = InstrumentationRegistry.getArguments().getString("qaRefreshRate")?.toIntOrNull() ?: 120
        context.getSharedPreferences("launch-qa", 0).edit().putInt("refresh-rate", requestedRate).commit()
        val device = UiDevice.getInstance(inst)
        val expectedLanguage = InstrumentationRegistry.getArguments().getString("qaLanguage")
        fun capture(stage: String) {
            if (expectedLanguage == null) return
            device.waitForIdle()
            val dump = File(context.cacheDir, "qa-locale-$expectedLanguage-$stage.xml")
            device.dumpWindowHierarchy(dump)
            device.takeScreenshot(File(context.cacheDir, "qa-locale-$expectedLanguage-$stage.png"))
            if (expectedLanguage != "ko") {
                val parser = android.util.Xml.newPullParser()
                parser.setInput(dump.reader())
                val untranslated = mutableListOf<String>()
                while (parser.next() != org.xmlpull.v1.XmlPullParser.END_DOCUMENT) {
                    if (parser.eventType == org.xmlpull.v1.XmlPullParser.START_TAG &&
                        parser.getAttributeValue(null, "package") == context.packageName) {
                        listOf("text", "content-desc").forEach { attribute ->
                            val value = parser.getAttributeValue(null, attribute).orEmpty()
                            if (Regex("[가-힣]").containsMatchIn(value)) untranslated += value
                        }
                    }
                }
                assertTrue("Untranslated $stage text: $untranslated", untranslated.isEmpty())
            }
        }
        device.wakeUp()
        val started = SystemClock.elapsedRealtime()
        context.startActivity(requireNotNull(context.packageManager.getLaunchIntentForPackage(context.packageName))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))

        fun tap(tag: String) {
            val node = device.wait(Until.findObject(By.res(tag).pkg(context.packageName).enabled(true)), 20_000)
            assertNotNull("Visible action missing: $tag", node)
            assertTrue("Action clipped: $tag", requireNotNull(node).visibleBounds.height() > 0)
            device.waitForIdle()
            requireNotNull(device.findObject(By.res(tag).pkg(context.packageName).enabled(true))).click()
        }
        assertNotNull(device.wait(Until.findObject(By.res("action.enterSetup")), 20_000))
        capture("opening")
        tap("action.enterSetup")
        assertTrue(device.wait(Until.hasObject(By.res("setup.name")), 10_000))
        capture("name")
        tap("setup.next")
        assertTrue(device.wait(Until.gone(By.res("setup.name")), 10_000))
        tap("setup.region")
        tap("setup.region.부산")
        capture("region")
        tap("setup.next")
        capture("style")
        tap("setup.confirm")
        tap("action.beginTutorial")
        tap("action.openTutorialPitch")
        val manualPlan = InstrumentationRegistry.getArguments().getString("qaManualPlan") == "true"
        if (manualPlan) {
            tap("pitch.type.curveball")
            val zoneTag = "pitch.zone.2.0"
            for (attempt in 0..8) {
                val region = device.findObject(By.scrollable(true))!!.visibleBounds
                val cell = device.findObject(By.res(zoneTag))?.visibleBounds
                if (cell != null && cell.top >= region.top && cell.bottom <= region.bottom) {
                    device.click(cell.centerX(), cell.centerY())
                    break
                }
                device.swipe(region.centerX(), region.bottom - 30, region.centerX(), region.top + 30, 25)
                device.waitForIdle()
            }
            assertTrue(device.wait(Until.hasObject(By.res("pitch.selected-zone.2.0")), 5_000))
            capture("manual-plan")
        }
        if (InstrumentationRegistry.getArguments().getString("qaStrategy") == "true") {
            tap("pitch.strategy")
            // The opening bullpen may have no prepared catcher rationale.
            device.wait(Until.findObject(By.res("pitch.rationale").pkg(context.packageName)), 1_000)?.click()
            capture("strategy")
            assertTrue("A strategy dialog must remain available after inspecting its rationale", device.wait(Until.hasObject(By.res("pitch.strategy.close").pkg(context.packageName)), 5_000))
            tap("pitch.strategy.close")
        }
        val pad = device.wait(Until.findObject(By.res("pitch.slider").pkg(context.packageName)), 20_000)
        if (pad == null) capture("missing-slider")
        assertNotNull("Manual slider must be visible by default", pad)
        val bounds = requireNotNull(pad).visibleBounds
        val frameTimes = java.util.Collections.synchronizedList(mutableListOf<Long>())
        val frameCallback = object : android.view.Choreographer.FrameCallback {
            override fun doFrame(frameTimeNanos: Long) {
                frameTimes.add(frameTimeNanos)
                android.view.Choreographer.getInstance().postFrameCallback(this)
            }
        }
        inst.runOnMainSync { android.view.Choreographer.getInstance().postFrameCallback(frameCallback) }
        val downTime = SystemClock.uptimeMillis()
        val down = MotionEvent.obtain(downTime, downTime, MotionEvent.ACTION_DOWN, bounds.centerX().toFloat(), bounds.centerY().toFloat(), 0)
        down.source = InputDevice.SOURCE_TOUCHSCREEN
        inst.sendPointerSync(down)
        down.recycle()
        SystemClock.sleep(900)
        val up = MotionEvent.obtain(downTime, SystemClock.uptimeMillis(), MotionEvent.ACTION_UP, bounds.centerX().toFloat(), bounds.centerY().toFloat(), 0)
        up.source = InputDevice.SOURCE_TOUCHSCREEN
        inst.sendPointerSync(up)
        up.recycle()
        inst.runOnMainSync { android.view.Choreographer.getInstance().removeFrameCallback(frameCallback) }
        assertTrue("Saved result must be visible", device.wait(Until.hasObject(By.res("pitch.replay")), 20_000))
        capture("pitch")
        val state = app.gameStore.current
        assertEquals("부산", state.highSchool?.run?.identity?.region)
        assertFalse(state.settings.autoReleaseEnabled)
        assertTrue("A real pitch must be committed", state.pitch?.resultHashes?.isNotEmpty() == true)
        if (manualPlan) assertEquals(com.solkim.baseball.application.PitchKind.CURVEBALL, state.highSchool?.lastPresentation?.snapshot?.pitchType)
        if (InstrumentationRegistry.getArguments().getString("qaNativeStore") == "true") {
            val nativeSave = File(context.getExternalFilesDir(null), "save/save.json")
            assertTrue("Native writer must create the production-format save", nativeSave.isFile)
            assertTrue("Native writer must preserve the full high-school state", nativeSave.readText().contains("nativePhase4State"))
        }
        device.takeScreenshot(File(context.cacheDir, "qa-first-pitch-$requestedRate.png"))
        val display = context.getSystemService(android.hardware.display.DisplayManager::class.java).getDisplay(android.view.Display.DEFAULT_DISPLAY)
        val frameStats = device.executeShellCommand("dumpsys gfxinfo ${context.packageName}")
        File(context.cacheDir, "qa-framestats-$requestedRate.txt").writeText(frameStats)
        val intervals = frameTimes.toList().zipWithNext { a, b -> (b - a) / 1_000_000.0 }.sorted()
        val medianInterval = intervals.getOrNull(intervals.size / 2)
        android.util.Log.i("BASEBALL_LAUNCH_QA", "first_slider elapsed_ms=${SystemClock.elapsedRealtime() - started} requested_hz=$requestedRate actual_hz=${display.mode.refreshRate} meter_interval_ms=$medianInterval meter_frames=${frameTimes.size} revision=${state.revision}")
        tap("pitch.continue")
        tap("action.completeTutorial")
        assertTrue("School choices must follow the first pitch", device.wait(Until.hasObject(By.res(java.util.regex.Pattern.compile("action.chooseSchool:.*"))), 20_000))
        assertTrue(app.gameStore.current.highSchool?.tutorial?.completed == true)
    }
}
