package com.solkim.baseball.android

import com.solkim.baseball.application.CareerAccess

import android.content.Intent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** Continue the player's existing QA save. Never clears or replaces their career. */
@RunWith(AndroidJUnit4::class)
class ResumePlayerTutorialTest {
    @Test fun existingPlayerCanFinishPracticeAndReachSchoolChoices() {
        val inst = InstrumentationRegistry.getInstrumentation()
        val context = inst.targetContext
        require(context.packageName.endsWith(".compose.qa"))
        val app = context.applicationContext as BaseballApplication
        val identity = requireNotNull(CareerAccess.school(app.gameStore.current)).run.identity
        val career = CareerAccess.school(app.gameStore.current)!!.run.careerId
        assertTrue(CareerAccess.school(app.gameStore.current)!!.tutorial.started)
        org.junit.Assume.assumeFalse("The player has already completed practice; do not replay their career.", CareerAccess.school(app.gameStore.current)!!.tutorial.completed)
        val device = UiDevice.getInstance(inst)
        context.startActivity(context.packageManager.getLaunchIntentForPackage(context.packageName)!!.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        fun tap(tag: String) {
            val node = device.wait(Until.findObject(By.res(tag).enabled(true)), 20_000)
            assertNotNull("Missing action: $tag", node)
            node!!.click()
        }
        tap("action.openTutorialPitch")
        val slider = device.wait(Until.findObject(By.res("pitch.slider")), 20_000)
        assertNotNull(slider)
        val bounds = slider!!.visibleBounds
        // UiAutomator injects a hold with small finger movement, like a real player.
        device.swipe(bounds.centerX(), bounds.centerY(), bounds.centerX() + 1, bounds.centerY(), 180)
        assertTrue(device.wait(Until.hasObject(By.res("pitch.replay")), 20_000))
        tap("pitch.continue")
        tap("action.completeTutorial")
        assertTrue(device.wait(Until.hasObject(By.res(java.util.regex.Pattern.compile("action.chooseSchool:.*"))), 20_000))
        assertEquals(identity, CareerAccess.school(app.gameStore.current)!!.run.identity)
        assertEquals(career, CareerAccess.school(app.gameStore.current)!!.run.careerId)
        assertTrue(CareerAccess.school(app.gameStore.current)!!.tutorial.completed)
        device.takeScreenshot(File(context.cacheDir, "player-resumed-school.png"))
    }
}
