package com.solkim.baseball.android

import android.content.Intent
import android.net.Uri
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import com.solkim.baseball.application.CareerAccess
import com.solkim.baseball.application.GameStage
import com.solkim.baseball.application.SeedChallengeCode
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SeedChallengeUiTest {
    @Test(timeout = 120_000)
    fun incomingLinkNeedsAChoiceAndReturnsToTheOriginalEmptyCareer() {
        val inst = InstrumentationRegistry.getInstrumentation()
        val context = inst.targetContext
        require(context.packageName.endsWith(".compose.qa"))
        val app = context.applicationContext as BaseballApplication
        assertEquals(GameStage.OPENING, app.gameStore.current.stage)
        val code = SeedChallengeCode("730001", 3)
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(code.appUrl)).setPackage(context.packageName)
            .addCategory(Intent.CATEGORY_BROWSABLE).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        assertNotNull(context.packageManager.resolveActivity(intent, 0))
        context.startActivity(intent)
        val device = UiDevice.getInstance(inst)
        fun tap(tag: String) {
            val node = device.wait(Until.findObject(By.res(tag)), 20_000)
            assertNotNull(tag, node)
            requireNotNull(node).click()
        }
        assertTrue(device.wait(Until.hasObject(By.res("challenge.code")), 20_000))
        assertNull("A link alone must not start or overwrite a career", CareerAccess.school(app.gameStore.current))
        tap("challenge.start")
        assertTrue(device.wait(Until.hasObject(By.res("challenge.exit")), 20_000))
        assertEquals(code, app.gameStore.current.meta.seedChallenge?.code)
        assertTrue(CareerAccess.school(app.gameStore.current)!!.challenge.active)
        assertFalse(app.gameStore.current.settings.autoReleaseEnabled)
        tap("challenge.exit")
        tap("challenge.confirm-exit")
        assertTrue(device.wait(Until.hasObject(By.res("action.enterSetup")), 20_000))
        assertNull(CareerAccess.school(app.gameStore.current))
        assertNull(app.gameStore.current.meta.seedChallenge)
        assertEquals(GameStage.OPENING, app.gameStore.current.stage)
        assertEquals(0UL, app.gameStore.current.meta.completedGameCount)
    }
}
