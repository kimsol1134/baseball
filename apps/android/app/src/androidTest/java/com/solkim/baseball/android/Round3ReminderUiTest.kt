package com.solkim.baseball.android

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.*
import com.solkim.baseball.application.*
import com.solkim.baseball.platform.*
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class Round3ReminderUiTest {
    @get:org.junit.Rule val evidenceOnFailure = object : org.junit.rules.TestWatcher() {
        override fun failed(error: Throwable, description: org.junit.runner.Description) {
            val inst = InstrumentationRegistry.getInstrumentation()
            UiDevice.getInstance(inst).dumpWindowHierarchy(java.io.File(inst.targetContext.cacheDir, "round3-reminder-failure.xml"))
            UiDevice.getInstance(inst).takeScreenshot(java.io.File(inst.targetContext.cacheDir, "round3-reminder-failure.png"))
        }
    }

    @Test(timeout = 90_000) fun deniedAndGrantedReminderReportTruthAndNotificationReopensCurrentPro() = runBlocking {
        val inst = InstrumentationRegistry.getInstrumentation()
        val context = inst.targetContext
        require(context.packageName == "com.solkim.baseball.android.reset.compose.qa")
        val app = context.applicationContext as BaseballApplication
        val store = app.gameStore
        assertEquals(PackageManager.PERMISSION_DENIED, context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS))
        if (store.current.stage == GameStage.OPENING) Phase8Controller(store).execute(Phase8ScreenId.P001_OPENING, "startDirect")
        assertNotNull(store.current.pro)
        val originalPro = store.current.pro
        try {
        val device = UiDevice.getInstance(inst)
        device.wakeUp()
        context.startActivity(context.packageManager.getLaunchIntentForPackage(context.packageName)!!.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
        device.executeShellCommand("am start -W -n ${context.packageName}/com.solkim.baseball.android.MainActivity")
        fun tap(tag: String) {
            repeat(8) {
                val node = device.wait(Until.findObject(By.res(tag).pkg(context.packageName)), 1000)
                if (node != null && node.visibleBounds.height() > 8) { android.os.SystemClock.sleep(600); node.click(); device.waitForIdle(); return }
                device.swipe(device.displayWidth/2, device.displayHeight*3/4, device.displayWidth/2, device.displayHeight/3, 30)
            }
            device.dumpWindowHierarchy(java.io.File(context.cacheDir, "round3-reminder-missing.xml"))
            device.takeScreenshot(java.io.File(context.cacheDir, "round3-reminder-missing.png"))
            error("Missing $tag; stage=${store.current.stage}")
        }
        tap("navigation.records"); tap("records.tab.P-029"); tap("action.prepareReturnPlan")
        device.wait(Until.findObject(By.res(java.util.regex.Pattern.compile(".*:id/permission_deny_button"))), 3000)?.click()
        assertTrue(device.wait(Until.hasObject(By.res("return.notice")), 8000))
        assertTrue(app.platform.stateStore.read().scheduledReminderTokenHashes.isEmpty())
        assertEquals(originalPro, store.current.pro)
        device.pressBack()
        inst.uiAutomation.grantRuntimePermission(context.packageName, Manifest.permission.POST_NOTIFICATIONS)
        assertTrue(app.platform.notifications.scheduler.schedule(NativeReminderPlan(System.currentTimeMillis()+3_600_000,
            NotificationDestination.PRO, "continue", "previous", "previous", "Previous QA", "Previous reminder")) is ReminderScheduleResult.Scheduled)
        tap("action.prepareReturnPlan")
        assertTrue(device.wait(Until.hasObject(By.res("return.notice")), 8000))
        assertEquals(1, app.platform.stateStore.read().scheduledReminderTokenHashes.size)
        assertTrue(device.executeShellCommand("dumpsys alarm").contains(context.packageName))
        device.pressBack()
        tap("action.prepareReturnPlan")
        assertTrue(device.wait(Until.hasObject(By.res("return.notice")), 8000))
        device.waitForIdle()
        device.pressBack()
        assertEquals(1, app.platform.stateStore.read().scheduledReminderTokenHashes.size)
        val prefs = context.getSharedPreferences("return-reminder", android.content.Context.MODE_PRIVATE)
        val token = prefs.getString("token", null)!!
        // Accelerate only this disposable QA alarm, keeping the actual receiver and click route.
        val result = app.platform.notifications.scheduler.schedule(NativeReminderPlan(System.currentTimeMillis()+1200, NotificationDestination.PRO,
            "continue", token.substringBefore('|'), token, "QA return", "Resume current career"))
        assertTrue(result is ReminderScheduleResult.Scheduled)
        device.pressHome()
        device.openNotification()
        val notification = device.wait(Until.findObject(By.text("QA return")), 20_000)
        assertNotNull(notification)
        notification!!.click()
        assertTrue(device.wait(Until.hasObject(By.res("week.commit")), 10_000))
        assertEquals(originalPro, store.current.pro)
        } finally {
            app.platform.notifications.scheduler.cancelAll()
            context.getSharedPreferences("return-reminder", android.content.Context.MODE_PRIVATE).edit().clear().putBoolean("dismissed", true).commit()
        }
    }
}
