package com.solkim.baseball.android

import com.solkim.baseball.application.CareerAccess

import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** Repeat an already saved pitch to isolate rendering load without farming games or rewards. */
@RunWith(AndroidJUnit4::class)
class PitchSustainedRenderTest {
    @Test(timeout = 1_320_000)
    fun replayRemainsStableWithoutChangingCareerState() {
        val inst = InstrumentationRegistry.getInstrumentation()
        val context = inst.targetContext
        require(context.packageName.endsWith(".compose.qa"))
        val app = context.applicationContext as BaseballApplication
        val duration = (InstrumentationRegistry.getArguments().getString("qaDurationSeconds")?.toIntOrNull() ?: 60).coerceIn(30, 1200)
        context.getSharedPreferences("launch-qa", 0).edit().putInt("refresh-rate", 120).commit()
        val device = UiDevice.getInstance(inst)
        device.wakeUp()
        val existing = app.gameStore.current.pitch
        if (existing != null && existing.boundary !in setOf(com.solkim.baseball.application.PitchBoundary.COMPLETED, com.solkim.baseball.application.PitchBoundary.ABANDONED)) {
            context.startActivity(PitchActivity.intent(context, existing.sessionId, app.gameStore.current.revision.toString()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } else {
        context.startActivity(requireNotNull(context.packageManager.getLaunchIntentForPackage(context.packageName))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
        // A disposable QA install starts at the opening screen, so the career this render sample needs
        // is created here instead of depending on another test class having run first.
        device.wait(Until.findObject(By.res("action.enterSetup")), 20_000)?.click()
        if (device.wait(Until.hasObject(By.res("setup.name")), 10_000)) {
            requireNotNull(device.wait(Until.findObject(By.res("setup.next")), 10_000)).click()
            requireNotNull(device.wait(Until.findObject(By.res("setup.confirm")), 10_000)).click()
        }
        device.wait(Until.findObject(By.res("pitch.practiceIntroduction.start").enabled(true)), 20_000)?.click()
        }
        // The replay this test samples exists only after a pitch has been thrown.
        if (!device.wait(Until.hasObject(By.res("pitch.replay")), 5_000)) {
            val slider = requireNotNull(device.wait(Until.findObject(By.res("pitch.slider")), 20_000)).visibleBounds
            device.swipe(slider.centerX(), slider.centerY(), slider.centerX() + 1, slider.centerY(), 180)
        }
        assertTrue(device.wait(Until.hasObject(By.res("pitch.replay")), 20_000))
        val revision = app.gameStore.current.revision
        val receipts = app.gameStore.current.pitch?.resultHashes
        val careerCommitment = CareerAccess.school(app.gameStore.current)?.stateCommitment
        val completedGames = app.gameStore.current.meta.completedGameCount
        var settledRevision: ULong? = null
        val power = context.getSystemService(PowerManager::class.java)
        val trace = StringBuilder("duration_seconds=$duration\nrevision=$revision\n")
        device.executeShellCommand("dumpsys gfxinfo ${context.packageName} reset")
        val started = SystemClock.elapsedRealtime()
        var count = 0
        try {
            while (SystemClock.elapsedRealtime() - started < duration * 1000L) {
                val replay = device.wait(Until.findObject(By.res("pitch.replay")), 10_000)
                assertNotNull("Replay must remain available", replay)
                requireNotNull(replay).click()
                SystemClock.sleep(4_000)
                assertEquals("Replay must not change the career", careerCommitment, CareerAccess.school(app.gameStore.current)?.stateCommitment)
                assertEquals("Replay must not add a completed game", completedGames, app.gameStore.current.meta.completedGameCount)
                assertEquals(receipts, app.gameStore.current.pitch?.resultHashes)
                // The launcher may finish its screen-view receipt after opening the saved result.
                // Once that first replay settles, subsequent replays must not write anything.
                if (settledRevision == null) settledRevision = app.gameStore.current.revision
                else assertEquals("Repeated replay must not write saves", settledRevision, app.gameStore.current.revision)
                count++
                if (count % 15 == 0) {
                    val thermal = if (Build.VERSION.SDK_INT >= 29) power.currentThermalStatus else 0
                    trace.append("elapsed_ms=${SystemClock.elapsedRealtime() - started} replays=$count thermal_status=$thermal native_heap=${android.os.Debug.getNativeHeapAllocatedSize()}\n")
                    assertTrue("Thermal stress reached severe status", thermal < 3)
                }
            }
        } finally {
            trace.append("completed_replays=$count\n")
            trace.append(device.executeShellCommand("dumpsys gfxinfo ${context.packageName}"))
            File(context.cacheDir, "qa-sustained-render.txt").writeText(trace.toString())
            device.takeScreenshot(File(context.cacheDir, "qa-sustained-render.png"))
        }
    }
}
