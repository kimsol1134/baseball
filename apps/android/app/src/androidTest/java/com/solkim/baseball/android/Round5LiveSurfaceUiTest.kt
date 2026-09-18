package com.solkim.baseball.android

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.*
import com.solkim.baseball.application.*
import com.solkim.baseball.model.*
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import java.io.File

class Round5LiveSurfaceUiTest {
    private fun hasCenterInk(bitmap: Bitmap, barHeight: Int): Boolean {
        // Screen coordinates, including the status bar (not Compose root coordinates).
        for (y in 0 until barHeight) {
            val expected = bitmap.getPixel(bitmap.width / 3, y)
            for (x in bitmap.width * 2 / 5 until bitmap.width * 3 / 5) {
                val actual = bitmap.getPixel(x, y)
                if (listOf(Color.red(actual)-Color.red(expected), Color.green(actual)-Color.green(expected), Color.blue(actual)-Color.blue(expected)).any { kotlin.math.abs(it) > 8 }) return true
            }
        }
        return false
    }

    @Test fun actualActivityStatusBarHasNoTabLabelAfterNavigationAndReturn() = runBlocking {
        val inst = InstrumentationRegistry.getInstrumentation()
        val context = inst.targetContext
        require(context.packageName == "com.solkim.baseball.android.reset.compose.qa")
        val store = (context.applicationContext as BaseballApplication).gameStore
        while (store.busy.value) kotlinx.coroutines.delay(25)
        val root = StrictJson.parseUtf8(inst.context.assets.open("round4-pro-week.json").use { it.readBytes() }) as JsonValue.Obj
        store.importCareerBackup(com.solkim.baseball.application.fixtures.portableCareerFixture(root["payload"] as JsonValue.Obj), store.current.revision)
        val device = UiDevice.getInstance(inst)
        device.executeShellCommand("am start -W -n ${context.packageName}/com.solkim.baseball.android.MainActivity -f 0x10008000")
        val barHeight = context.resources.getDimensionPixelSize(context.resources.getIdentifier("status_bar_height", "dimen", "android"))
        assertTrue(barHeight > 30)
        for ((index, tab) in listOf("settings", "records", "career", "records", "settings").withIndex()) {
            val node = device.wait(Until.findObject(By.res("navigation.$tab").pkg(context.packageName)), 10_000)!!
            node.click(); device.waitForIdle()
            if (index == 3) {
                device.pressHome(); device.waitForIdle()
                device.takeScreenshot(File(context.cacheDir, "round5-launcher.png"))
                device.executeShellCommand("am start -W -n ${context.packageName}/com.solkim.baseball.android.MainActivity")
                device.waitForIdle()
            }
            val file = File(context.cacheDir, "round5-status-$index-$tab.png")
            assertTrue(device.takeScreenshot(file))
            val bitmap = BitmapFactory.decodeFile(file.path)
            assertFalse("Extra ink in actual status-bar center: $file", hasCenterInk(bitmap, barHeight))
            // Prove the detector sees a label-sized defect in the band missed by the old y=4..29 check.
            val injected = bitmap.copy(Bitmap.Config.ARGB_8888, true)
            Canvas(injected).drawText("기록", bitmap.width / 2f - 20, barHeight - 5f,
                Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.GRAY; textSize = 28f })
            assertTrue(hasCenterInk(injected, barHeight))
            bitmap.recycle(); injected.recycle()
        }
    }
}
