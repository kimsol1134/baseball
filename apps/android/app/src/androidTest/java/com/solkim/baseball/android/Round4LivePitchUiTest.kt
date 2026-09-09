package com.solkim.baseball.android

import android.content.Intent
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.*
import com.solkim.baseball.application.*
import com.solkim.baseball.core.pro.ProKernel
import com.solkim.baseball.core.pro.ProCareerPhase
import com.solkim.baseball.core.pro.ProCatalog
import com.solkim.baseball.core.pro.ProSeasonTrigger
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import java.io.File

/** Valid prepared high-fatigue fixtures; no edits to the existing launch-QA player's save. */
class Round4LivePitchUiTest {
    @get:org.junit.Rule val failureEvidence=object: org.junit.rules.TestWatcher() {
        override fun failed(error:Throwable, description:org.junit.runner.Description) {
            val inst=InstrumentationRegistry.getInstrumentation()
            val device=UiDevice.getInstance(inst)
            device.dumpWindowHierarchy(File(inst.targetContext.cacheDir,"round4-live-failure.xml"))
            device.takeScreenshot(File(inst.targetContext.cacheDir,"round4-live-failure.png"))
            val state=(inst.targetContext.applicationContext as BaseballApplication).gameStore.current
            File(inst.targetContext.cacheDir,"round4-live-failure.txt").writeText("${state.pitch?.boundary} / ${state.pro?.activePitch?.pitches} / ${state.pro?.fatigue} / $error")
        }
    }

    private fun closeQaActivities() {
        val inst=InstrumentationRegistry.getInstrumentation()
        inst.runOnMainSync {
            val monitor=androidx.test.runner.lifecycle.ActivityLifecycleMonitorRegistry.getInstance()
            androidx.test.runner.lifecycle.Stage.values().filter {it!=androidx.test.runner.lifecycle.Stage.DESTROYED}
                .flatMap {monitor.getActivitiesInStage(it)}.toSet().filter {it.packageName==inst.targetContext.packageName}.forEach {it.finish()}
        }
        inst.waitForIdleSync()
        android.os.SystemClock.sleep(200)
    }
    @Test(timeout=90_000) fun suspendedSaveCanLeaveThroughTheRealButtonAndResumeUnchanged() = runBlocking {
        val inst=InstrumentationRegistry.getInstrumentation()
        val context=inst.targetContext
        require(context.packageName=="com.solkim.baseball.android.reset.compose.qa")
        val store=(context.applicationContext as BaseballApplication).gameStore
        closeQaActivities()
        while (store.busy.value) kotlinx.coroutines.delay(25)
        val root=StrictJson.parseUtf8(inst.context.assets.open("round3-linked-pro-return-stage.json").use {it.readBytes()}) as JsonValue.Obj
        store.importCareerBackup(com.solkim.baseball.application.fixtures.portableCareerFixture(root["payload"] as JsonValue.Obj),store.current.revision)
        val pro=store.current.pro
        val school=store.current.highSchool
        assertEquals(PitchBoundary.SUSPENDED,store.current.pitch!!.boundary)
        val device=UiDevice.getInstance(inst)
        device.executeShellCommand("am start -W -n ${context.packageName}/com.solkim.baseball.android.MainActivity -f 0x10008000")
        fun tap(tag:String) {
            val node=device.wait(Until.findObject(By.res(tag).pkg(context.packageName).enabled(true)),10_000)!!
            device.waitForIdle(); android.os.SystemClock.sleep(350)
            val b=device.findObject(By.res(tag).pkg(context.packageName)).visibleBounds
            device.executeShellCommand("input tap ${b.centerX()} ${b.centerY()}")
        }
        tap("action.abandonPitch")
        assertTrue(device.wait(Until.hasObject(By.res("action.nextProPitch").pkg(context.packageName)),8000))
        assertEquals(PitchBoundary.ABANDONED,store.current.pitch!!.boundary)
        assertNull(store.current.pitch!!.suspendedFrom)
        assertEquals(pro,store.current.pro); assertEquals(school,store.current.highSchool)
        val started=android.os.SystemClock.elapsedRealtime()
        tap("action.nextProPitch")
        assertTrue(device.wait(Until.hasObject(By.res("pitch.slider").pkg(context.packageName)),30_000))
        File(context.cacheDir,"round4-suspend-ui-proof.json").writeText(org.json.JSONObject().put("resumeMs",android.os.SystemClock.elapsedRealtime()-started).toString())
        assertEquals(PitchBoundary.PLAYING,store.current.pitch!!.boundary)
        assertEquals(pro,store.current.pro); assertEquals(school,store.current.highSchool)
        device.takeScreenshot(File(context.cacheDir,"round4-suspended-resumed.png"))
        device.pressBack(); device.waitForIdle()
    }

    @Test(timeout=150_000) fun flightFinishesWithoutATapAndExhaustionExitWorksOnTheActualInputScreen() = runBlocking {
        val inst=InstrumentationRegistry.getInstrumentation()
        val context=inst.targetContext
        require(context.packageName=="com.solkim.baseball.android.reset.compose.qa")
        val store=(context.applicationContext as BaseballApplication).gameStore
        val c=Phase8Controller(store)
        val device=UiDevice.getInstance(inst)
        val evidence=org.json.JSONArray()
        for (fatigue in listOf(47,79,80,86,87)) {
            closeQaActivities()
            while (store.busy.value) kotlinx.coroutines.delay(25)
            if (store.current.stage != GameStage.OPENING) c.execute(Phase8ScreenId.P027_SETTINGS,"resetProgress")
            c.execute(Phase8ScreenId.P001_OPENING,"startDirect")
            val k=ProKernel()
            val ready=store.current.pro!!.copy(phase=ProCareerPhase.IMPORTANT_GAME, fatigue=fatigue,week=1,
                seasonSegment=ProCatalog.segment(1),seasonTrigger=ProSeasonTrigger.STANDINGS_RACE).let { it.copy(commitment=k.commitment(it)) }
            val root=StrictJson.parseUtf8(File(context.getExternalFilesDir(null),"save/save.json").readBytes()) as JsonValue.Obj
            val payload=root["payload"] as JsonValue.Obj
            val fixture=JsonValue.Obj(LinkedHashMap(payload.entries).apply { put("pro",CSharpLegacyProBridge.encodeReadModel(ready,"918220",payload["pro"] as JsonValue.Obj)) })
            store.importCareerBackup(com.solkim.baseball.application.fixtures.portableCareerFixture(fixture),store.current.revision)
            val launch=c.execute(Phase8ScreenId.P018_PRO_IMPORTANT_GAME,"openProImportantGame").launch!!
            context.getSharedPreferences("pitch.ui",0).edit().putBoolean("fast.results",false).commit()
            inst.startActivitySync(PitchActivity.intent(context,launch.sessionId,store.current.revision.toString()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            val slider=device.wait(Until.findObject(By.res("pitch.slider").pkg(context.packageName)),10_000)
            assertNotNull(slider)
            val available=PitchHudProjection.canFastForward(store.current)
            if (fatigue>=80) {
                val exit=device.wait(Until.findObject(By.res("pitch.exhaustionExit").pkg(context.packageName)),3000)
                assertNotNull("High fatigue input exit: $fatigue",exit)
                assertTrue(available)
                device.takeScreenshot(File(context.cacheDir,"round4-exhaustion-$fatigue.png"))
                device.waitForIdle()
                android.os.SystemClock.sleep(350)
                val target=device.findObject(By.res("pitch.exhaustionExit").pkg(context.packageName)).visibleBounds
                device.executeShellCommand("input tap ${target.centerX()} ${target.centerY()}")
                assertTrue(device.wait(Until.hasObject(By.res("pitch.continue").pkg(context.packageName)),20_000))
                assertTrue(store.current.pro!!.activePitch!!.ended)
                evidence.put(org.json.JSONObject().put("fatigue",fatigue).put("exitShown",true).put("ended",true))
            } else {
                assertFalse(device.hasObject(By.res("pitch.exhaustionExit").pkg(context.packageName)))
                device.takeScreenshot(File(context.cacheDir,"round5-aiming-$fatigue.png"))
                for (row in 0..2) for (col in 0..2) {
                    val cell=device.findObject(By.res("pitch.zone.$row.$col").pkg(context.packageName)).visibleBounds
                    assertTrue(cell.height()/context.resources.displayMetrics.density >= 47f)
                }
                val before=store.current.pro!!.activePitch!!.pitches
                val bounds=slider!!.visibleBounds
                val start=android.os.SystemClock.elapsedRealtime()
                device.swipe(bounds.centerX(),bounds.centerY(),bounds.centerX()+1,bounds.centerY(),90)
                device.takeScreenshot(File(context.cacheDir,"round5-flight-$fatigue.png"))
                assertTrue("Flight must complete without a tap",device.wait(Until.hasObject(By.res("pitch.continue").pkg(context.packageName)),8000))
                assertEquals(before+1,store.current.pro!!.activePitch!!.pitches)
                evidence.put(org.json.JSONObject().put("fatigue",fatigue).put("resultMs",android.os.SystemClock.elapsedRealtime()-start))
            }
            assertEquals(PitchBoundary.TERMINAL,store.current.pitch!!.boundary)
            assertNotNull(PitchLiveResult.outcome(store.current))
            assertFalse(store.current.settings.autoReleaseEnabled)
            device.pressBack(); device.waitForIdle()
        }
        File(context.cacheDir,"round4-live-proof.json").writeText(evidence.toString(2))
    }
}
