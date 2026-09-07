package com.solkim.baseball.android

import android.content.Intent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import com.solkim.baseball.application.*
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** Destructive coverage is restricted to a dedicated disposable package, never the user's QA career. */
@RunWith(AndroidJUnit4::class)
class ProgressResetUiTest {
    @Test(timeout = 120_000) fun resetRequiresConfirmationAndReturnsToOpeningWithManualSliderDefault() {
        val inst = InstrumentationRegistry.getInstrumentation()
        val context = inst.targetContext
        require(context.packageName == "com.solkim.baseball.android.reset.compose.qa")
        val app = context.applicationContext as BaseballApplication
        assertEquals(GameStage.OPENING, app.gameStore.current.stage)
        val controller = Phase8Controller(app.gameStore)
        runBlocking {
            controller.execute(Phase8ScreenId.P001_OPENING, "enterSetup")
            controller.execute(Phase8ScreenId.P002_SETUP, "startHighSchool")
            controller.execute(Phase8ScreenId.P003_PROLOGUE, "beginTutorial")
            controller.execute(Phase8ScreenId.P003_PROLOGUE, "completeTutorial")
            controller.execute(Phase8ScreenId.P005_SCHOOL_SELECTION, controller.projection(Phase8ScreenId.P005_SCHOOL_SELECTION).actions.first().id)
        }
        val before = app.gameStore.current
        val device = UiDevice.getInstance(inst)
        context.startActivity(requireNotNull(context.packageManager.getLaunchIntentForPackage(context.packageName))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
        requireNotNull(device.wait(Until.findObject(By.text("설정").pkg(context.packageName)), 20_000)).click()
        requireNotNull(device.wait(Until.findObject(By.res("settings.open.storage")), 10_000)).click()
        requireNotNull(device.wait(Until.findObject(By.res("action.resetProgress")), 10_000))
        device.takeScreenshot(File(context.cacheDir, "settings-reset-before-click.png"))
        requireNotNull(device.findObject(By.res("action.resetProgress"))).click()
        val confirmed = device.wait(Until.hasObject(By.res("settings.reset.confirm")), 10_000)
        if (!confirmed) {
            device.takeScreenshot(File(context.cacheDir, "settings-reset-no-dialog.png"))
            device.dumpWindowHierarchy(File(context.cacheDir, "settings-reset-no-dialog.xml"))
        }
        assertTrue("Delete must open a confirmation dialog", confirmed)
        device.takeScreenshot(File(context.cacheDir, "settings-reset-confirm.png"))
        assertEquals(before.highSchool, app.gameStore.current.highSchool)
        requireNotNull(device.findObject(By.res("settings.reset.cancel"))).click()
        assertTrue(device.wait(Until.gone(By.res("settings.reset.confirm")), 5_000))
        assertEquals(before.highSchool, app.gameStore.current.highSchool)
        requireNotNull(device.findObject(By.res("action.resetProgress"))).click()
        requireNotNull(device.wait(Until.findObject(By.res("settings.reset.confirm")), 10_000)).click()
        assertTrue("Successful reset must navigate to the opening", device.wait(Until.hasObject(By.res("action.enterSetup")), 15_000))
        assertEquals(GameStage.OPENING, app.gameStore.current.stage)
        assertNull(app.gameStore.current.highSchool)
        assertNull(app.gameStore.current.pro)
        assertFalse(app.gameStore.current.settings.autoReleaseEnabled)
        assertFalse(File(context.getExternalFilesDir(null), "save/save.bak.1").exists())
        device.takeScreenshot(File(context.cacheDir, "settings-reset-complete.png"))
    }
}
