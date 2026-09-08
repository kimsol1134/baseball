package com.solkim.baseball.android

import android.content.Intent
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import com.solkim.baseball.application.*
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import java.io.File

/** Runs only against the dedicated audit package after its first-pitch smoke; never resets a career. */
class DirectOutingAuditTest {
    @Test(timeout = 120_000) fun actualMoundShowsGoalAndCommitsOnlyOneManualPitch() = runBlocking {
        val inst = InstrumentationRegistry.getInstrumentation()
        val context = inst.targetContext
        require(context.packageName == "com.solkim.baseball.android.audit.compose.qa")
        val store = (context.applicationContext as BaseballApplication).gameStore
        val c = Phase8Controller(store)
        var turns = 0
        while (turns++ < 60) {
            val active = store.current.pitch
            if (active?.boundary == PitchBoundary.TERMINAL) {
                Phase7VerticalController(store).completePitchAndPostgame(active.sessionId)
                continue
            }
            val screen = c.preferredScreen()
            val actions = c.projection(screen).actions
            if (screen == Phase8ScreenId.P008_IMPORTANT_GAME && actions.any { it.enabled && it.id in setOf("openImportantGame", "resumePitch", "nextImportantPitch") }) break
            val action = actions.first { it.enabled && it.id !in setOf("abandonPitch", "suspendPitch") }
            c.execute(screen, action.id)
        }
        assertTrue(turns < 60)
        val entry = c.projection(Phase8ScreenId.P008_IMPORTANT_GAME).actions.first { it.enabled && it.id in setOf("openImportantGame", "resumePitch", "nextImportantPitch") }
        val launch = c.execute(Phase8ScreenId.P008_IMPORTANT_GAME, entry.id).launch!!
        val before = store.current.highSchool!!.activePitch!!.pitches
        assertFalse(store.current.settings.autoReleaseEnabled)
        context.startActivity(PitchActivity.intent(context, launch.sessionId, store.current.revision.toString()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        val device = UiDevice.getInstance(inst)
        assertTrue(device.wait(Until.hasObject(By.res("pitch.objective")), 20_000))
        val slider = device.wait(Until.findObject(By.res("pitch.slider")), 10_000)!!
        assertTrue(slider.visibleBounds.height() > 0)
        val runners = store.current.highSchool!!.activePitch!!.game
        for ((base, occupied) in listOf(1 to runners.firstOccupied, 2 to runners.secondOccupied, 3 to runners.thirdOccupied)) {
            val marker = device.wait(Until.findObject(By.res("visual.base.$base")), 5_000)
            assertNotNull("Each base must be visible", marker)
            assertEquals(occupied, marker!!.isSelected)
        }
        device.takeScreenshot(File(context.cacheDir, "audit-live-mound.png"))
        val b = slider.visibleBounds
        device.swipe(b.centerX(), b.centerY(), b.centerX() + 1, b.centerY(), 70)
        assertTrue(device.wait(Until.hasObject(By.res("pitch.replay")), 20_000))
        assertEquals(before + 1, store.current.highSchool!!.activePitch!!.pitches)
        device.takeScreenshot(File(context.cacheDir, "audit-live-result.png"))
        device.pressHome()
        android.os.SystemClock.sleep(800)
        context.startActivity(PitchActivity.intent(context, launch.sessionId, store.current.revision.toString()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        device.waitForIdle()
        assertEquals(before + 1, store.current.highSchool!!.activePitch!!.pitches)
        assertFalse(store.current.settings.autoReleaseEnabled)
        val reopened = KotlinGameStore.open(store.current.installId,
            CSharpLegacyGameStoreRepository(File(context.getExternalFilesDir(null), "save").toPath(), store.current.installId), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try { assertEquals(store.current, reopened.current) } finally { reopened.close() }
    }
}
