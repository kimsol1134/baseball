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

@RunWith(AndroidJUnit4::class)
class ContinuousPitchUiTest {
    @Test(timeout = 120_000) fun savedResultReturnsToManualSliderWithoutAnExtraPitch() {
        val inst = InstrumentationRegistry.getInstrumentation()
        val context = inst.targetContext
        require(context.packageName == "com.solkim.baseball.android.reset.compose.qa")
        val app = context.applicationContext as BaseballApplication
        val controller = Phase8Controller(app.gameStore)
        runBlocking {
            controller.execute(Phase8ScreenId.P001_OPENING, "enterSetup")
            controller.execute(Phase8ScreenId.P002_SETUP, "startHighSchool")
            controller.execute(Phase8ScreenId.P003_PROLOGUE, "beginTutorial")
            controller.execute(Phase8ScreenId.P003_PROLOGUE, "completeTutorial")
            repeat(40) {
                val screen = controller.preferredScreen()
                if (screen == Phase8ScreenId.P008_IMPORTANT_GAME) return@repeat
                val action = controller.projection(screen).actions.first { it.enabled }
                controller.execute(screen, action.id)
            }
            assertEquals(Phase8ScreenId.P008_IMPORTANT_GAME, controller.preferredScreen())
            val action = controller.projection(Phase8ScreenId.P008_IMPORTANT_GAME).actions.first { it.enabled && it.id == "openImportantGame" }
            val launch = requireNotNull(controller.execute(Phase8ScreenId.P008_IMPORTANT_GAME, action.id).launch)
            val pitching = Phase7VerticalController(app.gameStore)
            val result = pitching.submitPitch(launch.sessionId, 0, PitchKind.FOUR_SEAM, PitchZone(0, 0), PitchDelivery(0, 0))
            pitching.consumePresentation(launch.sessionId, result)
            assertTrue("Fixture needs an unfinished outing", pitching.canContinueOfficialPitch())
            val resume = controller.projection(Phase8ScreenId.P008_IMPORTANT_GAME).actions.single { it.id == "resumePitch" }
            assertTrue("A saved result must offer a career continuation", resume.enabled)
            val recovered = requireNotNull(controller.execute(Phase8ScreenId.P008_IMPORTANT_GAME, resume.id).launch)
            assertEquals(launch.sessionId, recovered.sessionId)
            context.startActivity(PitchActivity.intent(context, recovered.sessionId, app.gameStore.current.revision.toString()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
        val device = UiDevice.getInstance(inst)
        val before = requireNotNull(app.gameStore.current.highSchool?.activePitch).pitches
        // Normal mode explicitly acknowledges a restored result before the next manual pitch.
        val next = requireNotNull(device.wait(Until.findObject(By.res("pitch.continue")), 20_000))
        assertEquals(before, app.gameStore.current.highSchool?.activePitch?.pitches)
        device.takeScreenshot(java.io.File(context.getExternalFilesDir(null), "qa-restored-result.png"))
        next.click()
        val pad = requireNotNull(device.wait(Until.findObject(By.res("pitch.slider")), 20_000))
        assertEquals(before, app.gameStore.current.highSchool?.activePitch?.pitches)
        assertFalse(app.gameStore.current.settings.autoReleaseEnabled)
        assertFalse(device.hasObject(By.res("pitch.continue")))
        val recommended = PitchHudProjection.model(app.gameStore.current).preparation.primaryRecommendation.call.zone
        assertNotNull(device.findObject(By.res("pitch.selected-zone.${recommended.row}.${recommended.column}")))
        device.takeScreenshot(java.io.File(context.getExternalFilesDir(null), "qa-aiming-field.png"))
        device.waitForIdle()
        val manual = if (recommended == PitchZone(0, 0)) PitchZone(2, 2) else PitchZone(0, 0)
        requireNotNull(device.findObject(By.res("pitch.zone.${manual.row}.${manual.column}"))).click()
        assertNotNull(device.wait(Until.findObject(By.res("pitch.selected-zone.${manual.row}.${manual.column}")), 3_000))
        val repertoire = PitchHudProjection.repertoire(app.gameStore.current)
        requireNotNull(device.findObject(By.res("pitch.type.${repertoire.last().wire}"))).click()
        assertNotNull(device.findObject(By.res("pitch.selected-zone.${manual.row}.${manual.column}")))
        requireNotNull(device.findObject(By.res("pitch.recommendation"))).click()
        assertNotNull(device.wait(Until.findObject(By.res("pitch.selected-zone.${recommended.row}.${recommended.column}")), 3_000))
        assertNotNull(device.findObject(By.res("pitch.aimingField")))
        device.takeScreenshot(java.io.File(context.getExternalFilesDir(null), "qa-aiming-field.png"))
        val bounds = pad.visibleBounds
        device.swipe(bounds.centerX(), bounds.centerY(), bounds.centerX() + 1, bounds.centerY(), 55)
        assertTrue(device.wait(Until.hasObject(By.res("pitch.replay")), 15_000) ||
            device.hasObject(By.res("pitch.slider")))
        assertEquals(before + 1, app.gameStore.current.highSchool?.activePitch?.pitches)
        device.pressHome()
        android.os.SystemClock.sleep(1_000)
        assertEquals(before + 1, app.gameStore.current.highSchool?.activePitch?.pitches)
    }
}
