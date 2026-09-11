package com.solkim.baseball.android
import android.content.Intent
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.*
import com.solkim.baseball.application.*
import com.solkim.baseball.application.fixtures.portableCareerFixture
import com.solkim.baseball.model.*
import kotlinx.coroutines.runBlocking
import org.junit.Test
import java.io.File
class StoreMarketingLiveCaptureTest {
    private val inst get()=InstrumentationRegistry.getInstrumentation()
    private val device get()=UiDevice.getInstance(inst)
    private val language get()=InstrumentationRegistry.getArguments().getString("storeLocale","ko").also { require(it in setOf("ko","en","ja")) }
    private fun source(file:String): JsonValue.Obj = (StrictJson.parseUtf8(inst.context.assets.open(file).use {it.readBytes()}) as JsonValue.Obj)["payload"] as JsonValue.Obj
    @Test fun livePitch():Unit=runBlocking {
        val context=inst.targetContext
        require(context.packageName=="com.solkim.baseball.android.reset.compose.qa")
        val store=(context.applicationContext as BaseballApplication).gameStore
        while(store.busy.value) kotlinx.coroutines.delay(25)
        store.importCareerBackup(portableCareerFixture(source("round3-linked-pro-return-stage.json")),store.current.revision)
        val c=PitchSessionController(store)
        val launch=c.resumePitch(requireNotNull(store.current.pitch).sessionId)
        val activity=inst.startActivitySync(PitchActivity.intent(context,launch.sessionId,store.current.revision.toString()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) as PitchActivity
        val slider=requireNotNull(device.wait(Until.findObject(By.res("pitch.slider").pkg(context.packageName)),20_000))
        device.waitForIdle()
        device.takeScreenshot(File(context.cacheDir,"store-$language-pitch.png"))
        File(context.cacheDir,"store-$language-ready").writeText("ready")
        kotlinx.coroutines.withTimeout(15_000) {
            while(!File(context.cacheDir,"store-$language-recording").exists()) kotlinx.coroutines.delay(25)
        }
        kotlinx.coroutines.delay(800)
        val start=android.os.SystemClock.elapsedRealtime()
        val b=slider.visibleBounds
        device.swipe(b.centerX(),b.centerY(),b.centerX()+1,b.centerY(),90)
        require(device.wait(Until.hasObject(By.res("pitch.continue").pkg(context.packageName)),15_000))
        device.takeScreenshot(File(context.cacheDir,"store-$language-result.png"))
        val resultMs=android.os.SystemClock.elapsedRealtime()-start
        kotlinx.coroutines.delay(1800)
        File(context.cacheDir,"store-$language-live-proof.json").writeText("""{"resultMs":$resultMs,"outcome":"${PitchLiveResult.outcome(store.current)}","width":${device.displayWidth},"height":${device.displayHeight}}""")
        inst.runOnMainSync {activity.finish()}
    }
}
