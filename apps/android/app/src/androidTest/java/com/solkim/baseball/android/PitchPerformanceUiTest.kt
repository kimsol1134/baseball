package com.solkim.baseball.android

import android.content.Intent
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import com.solkim.baseball.application.*
import kotlinx.coroutines.runBlocking
import java.io.File
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

/** Fixed saved pitch, warm renderer, no farming or mutations of a user's install. */
@RunWith(AndroidJUnit4::class)
class PitchPerformanceUiTest {
    @Test(timeout = 180_000) fun fixedReplayFrameSample() {
        val inst = InstrumentationRegistry.getInstrumentation()
        val context = inst.targetContext
        require(context.packageName == "com.solkim.baseball.android.reset.compose.qa")
        val app = context.applicationContext as BaseballApplication
        val store = app.gameStore
        context.getSharedPreferences("launch-qa", 0).edit().putInt("refresh-rate", 60).commit()
        runBlocking {
            if (store.current.pitch == null) {
                val controller = Phase8Controller(store)
                controller.execute(Phase8ScreenId.P001_OPENING, "enterSetup")
                controller.execute(Phase8ScreenId.P002_SETUP, "startHighSchool")
                controller.execute(Phase8ScreenId.P003_PROLOGUE, "beginTutorial")
                val launch = requireNotNull(controller.execute(Phase8ScreenId.P004_PITCH_TUTORIAL, "openTutorialPitch").launch)
                val pitching = Phase7VerticalController(store)
                val result = pitching.submitPitch(launch.sessionId, 0, PitchKind.SLIDER, PitchZone(1, 1), PitchDelivery(850, 900))
                pitching.consumePresentation(launch.sessionId, result)
            }
            context.startActivity(PitchActivity.intent(context, requireNotNull(store.current.pitch).sessionId, store.current.revision.toString()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
        val device = UiDevice.getInstance(inst)
        assertNotNull(device.wait(Until.findObject(By.res("pitch.replay")), 20_000))
        fun replay() {
            requireNotNull(device.findObject(By.res("pitch.replay"))).click()
            SystemClock.sleep(2_200)
        }
        replay(); replay()
        val before = store.current.highSchool
        device.executeShellCommand("dumpsys gfxinfo ${context.packageName} reset")
        repeat(12) { replay() }
        assertEquals(before, store.current.highSchool)
        File(context.cacheDir, "pitch-performance.txt").writeText(device.executeShellCommand("dumpsys gfxinfo ${context.packageName}"))
    }
}
