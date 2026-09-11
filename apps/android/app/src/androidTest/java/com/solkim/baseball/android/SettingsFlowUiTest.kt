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
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class SettingsFlowUiTest {
    @Test(timeout = 180_000) fun settingsStayInPlaceSaveHonestlyAndKeepExplanationsOutOfTheOverview() {
        val inst = InstrumentationRegistry.getInstrumentation()
        val context = inst.targetContext
        require(context.packageName == "com.solkim.baseball.android.reset.compose.qa")
        val app = context.applicationContext as BaseballApplication
        assertEquals(GameStage.OPENING, app.gameStore.current.stage)
        val controller = ScreenController(app.gameStore)
        runBlocking {
            controller.execute(ScreenId.P001_OPENING, "enterSetup")
            controller.execute(ScreenId.P002_SETUP, "startHighSchool")
            controller.execute(ScreenId.P003_PROLOGUE, "beginTutorial")
            controller.execute(ScreenId.P003_PROLOGUE, "completeTutorial")
            controller.execute(ScreenId.P005_SCHOOL_SELECTION, controller.projection(ScreenId.P005_SCHOOL_SELECTION).actions.first().id)
        }
        val career = CareerAccess.school(app.gameStore.current)
        val language = GameLanguage.fromTag(context.resources.configuration.locales[0].toLanguageTag())
        val copy = GameCopy(language)
        val device = UiDevice.getInstance(inst)
        context.startActivity(requireNotNull(context.packageManager.getLaunchIntentForPackage(context.packageName))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
        fun tap(tag: String) {
            repeat(3) { attempt ->
                try {
                    requireNotNull(device.wait(Until.findObject(By.res(tag).pkg(context.packageName).enabled(true)), 15_000)) { tag }
                    device.waitForIdle()
                    val bounds = requireNotNull(device.findObject(By.res(tag).pkg(context.packageName).enabled(true))) { tag }.visibleBounds
                    device.click(bounds.centerX(), bounds.centerY())
                    device.waitForIdle()
                    return
                } catch (stale: androidx.test.uiautomator.StaleObjectException) { if (attempt == 2) throw stale }
            }
        }
        fun awaitState(check: () -> Boolean) {
            val end = SystemClock.uptimeMillis() + 10_000
            while (!check() && SystemClock.uptimeMillis() < end) SystemClock.sleep(40)
            assertTrue(check()); device.waitForIdle()
        }
        fun capture(name: String) {
            device.waitForIdle()
            device.takeScreenshot(File(context.cacheDir, "settings-v2-$name-${language.tag}.png"))
            if (language != GameLanguage.KOREAN) {
                val file = File(context.cacheDir, "settings-v2-ui.xml")
                device.dumpWindowHierarchy(file)
                val parser = android.util.Xml.newPullParser().apply { setInput(file.reader()) }
                while (parser.next() != org.xmlpull.v1.XmlPullParser.END_DOCUMENT) {
                    if (parser.eventType == org.xmlpull.v1.XmlPullParser.START_TAG && parser.getAttributeValue(null, "package") == context.packageName) {
                        for (attribute in listOf("text", "content-desc")) assertFalse(Regex("[가-힣]").containsMatchIn(parser.getAttributeValue(null, attribute).orEmpty()))
                    }
                }
            }
        }
        tap("navigation.settings")
        assertNotNull(device.wait(Until.findObject(By.res("settings.sound")), 10_000))
        assertNull(device.findObject(By.res("settings.assist")))
        assertNull(device.findObject(By.res("backup.import")))
        assertNull(device.findObject(By.res("settings.term.command")))
        capture("overview")
        tap("settings.sound"); awaitState { !app.gameStore.current.settings.soundEnabled }
        assertNotNull(device.findObject(By.res("settings.open.storage")))
        tap("settings.music"); awaitState { !app.gameStore.current.settings.musicEnabled }
        tap("settings.haptics"); awaitState { !app.gameStore.current.settings.hapticsEnabled }

        // Fail one atomic write inside this disposable app. The visible switch must stay at
        // its saved value and the error must be visible on the current settings page.
        val blockedTemp = File(context.getExternalFilesDir(null), "save/save.tmp")
        assertTrue(blockedTemp.mkdir())
        val blocker = File(blockedTemp, "qa-blocker").apply { writeText("disposable write fault") }
        try {
            tap("settings.haptics")
            assertTrue(device.wait(Until.hasObject(By.res("settings.error")), 10_000))
            assertFalse(app.gameStore.current.settings.hapticsEnabled)
            capture("save-error")
        } finally { blocker.delete(); if (blockedTemp.isDirectory) assertTrue(blockedTemp.delete()) }
        tap("settings.haptics"); awaitState { app.gameStore.current.settings.hapticsEnabled }
        assertTrue(device.wait(Until.gone(By.res("settings.error")), 5_000))

        tap("settings.open.controls")
        assertFalse(app.gameStore.current.settings.autoReleaseEnabled)
        tap("settings.assist"); awaitState { app.gameStore.current.settings.autoReleaseEnabled }
        tap("settings.assist"); awaitState { !app.gameStore.current.settings.autoReleaseEnabled }
        tap("settings.contrast"); awaitState { app.gameStore.current.settings.highContrastEnabled }
        assertNotNull(device.findObject(By.res("settings.motion")))
        tap("settings.contrast"); awaitState { !app.gameStore.current.settings.highContrastEnabled }
        tap("settings.motion"); awaitState { app.gameStore.current.settings.reducedMotionEnabled }
        capture("controls")
        tap("settings.back")
        tap("settings.open.help")
        tap("settings.open.glossary")
        assertNull(device.findObject(By.res("settings.term.definition")))
        requireNotNull(device.wait(Until.findObject(By.clazz("android.widget.EditText").pkg(context.packageName)), 5_000)).text = copy.legacy("제구")
        // Typing re-filters the list. Let it settle before the toggle, and press once more if the tap
        // landed while the row was being recomposed; a swallowed toggle is not a product failure.
        assertNotNull(device.wait(Until.findObject(By.res("settings.term.command")), 10_000))
        device.waitForIdle()
        tap("settings.term.command")
        if (!device.wait(Until.hasObject(By.res("settings.term.definition")), 5_000)) {
            tap("settings.term.command")
        }
        assertTrue(device.wait(Until.hasObject(By.res("settings.term.definition")), 10_000))
        capture("glossary")
        tap("settings.back"); tap("settings.back"); tap("settings.back")
        tap("settings.open.notifications")
        assertNotNull(device.wait(Until.findObject(By.res("settings.notification.state")), 5_000))
        capture("notifications")
        tap("settings.back")
        tap("settings.open.storage")
        tap("backup.import")
        assertTrue(device.wait(Until.gone(By.res("backup.import")), 10_000))
        device.pressBack()
        assertTrue(device.wait(Until.hasObject(By.res("backup.import")), 10_000))
        assertEquals(career, CareerAccess.school(app.gameStore.current))
        capture("storage")
        val settings = app.gameStore.current.settings
        runBlocking {
            val reopened = KotlinGameStore.open(app.gameStore.current.installId,
                CSharpLegacyGameStoreRepository(File(context.getExternalFilesDir(null), "save").toPath(), app.gameStore.current.installId), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            try { assertEquals(settings, reopened.current.settings); assertEquals(career, CareerAccess.school(reopened.current)) } finally { reopened.close() }
        }
    }
}
