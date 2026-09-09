package com.solkim.baseball.android

import android.content.Intent
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.*
import com.solkim.baseball.application.*
import com.solkim.baseball.application.fixtures.prepareNaturalHighFatigueInput
import com.solkim.baseball.core.pitch.PitchDelivery
import com.solkim.baseball.model.*
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

class Round6PitchUiTest {
    private val inst get() = InstrumentationRegistry.getInstrumentation()
    private val context get() = inst.targetContext
    private val device get() = UiDevice.getInstance(inst)
    private val store get() = (context.applicationContext as BaseballApplication).gameStore

    private suspend fun prepare(): PitchLaunch {
        require(context.packageName == "com.solkim.baseball.android.reset.compose.qa")
        inst.runOnMainSync {
            val monitor = androidx.test.runner.lifecycle.ActivityLifecycleMonitorRegistry.getInstance()
            androidx.test.runner.lifecycle.Stage.values().filter { it != androidx.test.runner.lifecycle.Stage.DESTROYED }
                .flatMap { monitor.getActivitiesInStage(it) }.toSet().forEach { it.finish() }
        }
        inst.waitForIdleSync()
        while (store.busy.value) kotlinx.coroutines.delay(25)
        val controller = Phase8Controller(store)
        if (store.current.stage != GameStage.OPENING) controller.execute(Phase8ScreenId.P027_SETTINGS,"resetProgress")
        controller.execute(Phase8ScreenId.P001_OPENING,"startDirect")
        val root = StrictJson.parseUtf8(File(context.getExternalFilesDir(null),"save/save.json").readBytes()) as JsonValue.Obj
        return prepareNaturalHighFatigueInput(store, root["payload"] as JsonValue.Obj)
    }

    private fun open(session: String, replacement: GameStore? = null): PitchActivity {
        val activity = inst.startActivitySync(PitchActivity.intent(context,session,store.current.revision.toString()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) as PitchActivity
        if (replacement != null) inst.runOnMainSync {
            PitchActivity::class.java.getDeclaredField("controller").apply { isAccessible = true }.set(activity,Phase7VerticalController(replacement))
        }
        return activity
    }

    private fun waitFor(tag: String): UiObject2 = requireNotNull(device.wait(Until.findObject(By.res(tag).pkg(context.packageName)),15_000)) { tag }

    @Test fun failureBeforeCommitDoesNotClaimTheResultWasSaved(): Unit = runBlocking {
        val launch = prepare()
        val pro = store.current.pro
        val failing = object : GameStore by store {
            override suspend fun dispatch(envelope: GameCommandEnvelope): GameDispatchResult {
                if (envelope.command is GameCommand.Pro) throw GameCommandException("round6.injected_submit")
                return store.dispatch(envelope)
            }
        }
        open(launch.sessionId,failing)
        val bounds = waitFor("pitch.slider").visibleBounds
        device.swipe(bounds.centerX(),bounds.centerY(),bounds.centerX()+1,bounds.centerY(),90)
        assertTrue(waitFor("pitch.error").text.contains("진행 상태를 확인하지 못했어요"))
        assertEquals(pro,store.current.pro)
        assertEquals(PitchBoundary.PLAYING,store.current.pitch!!.boundary)
        device.takeScreenshot(File(context.cacheDir,"round6-unconfirmed-dialog.png"))
        waitFor("pitch.error.close").click()
        waitFor("action.resumePitch")
        assertEquals(PitchBoundary.SUSPENDED,store.current.pitch!!.boundary)
        assertEquals(pro,store.current.pro)
    }

    @Test fun seed7819NaturalStateReachesAndExecutesTheHighFatigueButton(): Unit = runBlocking {
        val launch = prepare()
        assertEquals(4,store.current.pro!!.week)
        assertEquals(18,store.current.pro!!.activePitch!!.pitches)
        assertEquals(80,PitchHudProjection.fatigue(store.current))
        assertEquals(PitchBoundary.PLAYING,store.current.pitch!!.boundary)
        open(launch.sessionId)
        waitFor("pitch.slider")
        val exit = waitFor("pitch.exhaustionExit")
        device.takeScreenshot(File(context.cacheDir,"round6-natural-80.png"))
        device.waitForIdle(); exit.click()
        waitFor("pitch.continue")
        assertTrue(store.current.pro!!.activePitch!!.ended)
        val result = store.current.pro
        assertEquals(PitchBoundary.TERMINAL,store.current.pitch!!.boundary)
        assertTrue(store.reconcilePersistedRevision().durableStateVerified)
        assertEquals(result,store.current.pro)
        device.takeScreenshot(File(context.cacheDir,"round6-natural-ended.png"))
        File(context.cacheDir,"round6-natural-proof.json").writeText("""{"seed":7819,"week":4,"inputPitches":18,"inputFatigue":80,"boundary":"${store.current.pitch!!.boundary}","ended":true}""")
        device.pressBack()
    }

    @Test fun savedResultFailureHasAccurateDialogAndRetriesOnlyConsumption(): Unit = runBlocking {
        val launch = prepare()
        Phase7VerticalController(store).submitPitch(launch.sessionId,PitchHudSelection.Primary,PitchDelivery(1000,1000))
        val pro = store.current.pro
        val failing = object : GameStore by store {
            override suspend fun dispatch(envelope: GameCommandEnvelope): GameDispatchResult {
                if (envelope.command is GameCommand.ConsumePitch) throw GameCommandException("round6.injected_consume").also {
                    it.addSuppressed(GameCommandFailureContext(envelope.commandId,envelope.sessionId,"consumePitch",envelope.expectedRevision,store.current.revision,store.current.pitch?.boundary,store.current.pitch?.boundary,(envelope.command as GameCommand.ConsumePitch).pitchId))
                }
                return store.dispatch(envelope)
            }
        }
        val activity = open(launch.sessionId,failing)
        val error = waitFor("pitch.error")
        assertTrue(error.text.contains("투구 결과는 저장됐어요"))
        assertEquals(PitchBoundary.COMMITTED,store.current.pitch!!.boundary)
        assertEquals(pro,store.current.pro)
        device.takeScreenshot(File(context.cacheDir,"round6-saved-result-dialog.png"))
        inst.runOnMainSync { PitchActivity::class.java.getDeclaredField("controller").apply { isAccessible=true }.set(activity,Phase7VerticalController(store)) }
        waitFor("pitch.error.close").click()
        waitFor("pitch.continue")
        assertEquals(PitchBoundary.TERMINAL,store.current.pitch!!.boundary)
        assertEquals(pro,store.current.pro)
        assertFalse(device.hasObject(By.res("pitch.error").pkg(context.packageName)))
        device.takeScreenshot(File(context.cacheDir,"round6-recovered-result.png"))
    }

    @Test fun destroyingActivityDuringConsumptionDoesNotReportSaveFailure(): Unit = runBlocking {
        val launch = prepare()
        Phase7VerticalController(store).submitPitch(launch.sessionId,PitchHudSelection.Primary,PitchDelivery(1000,1000))
        val pro = store.current.pro
        val entered = AtomicBoolean(false)
        val pending = object : GameStore by store {
            override suspend fun dispatch(envelope: GameCommandEnvelope): GameDispatchResult {
                if (envelope.command is GameCommand.ConsumePitch) { entered.set(true); kotlinx.coroutines.awaitCancellation() }
                return store.dispatch(envelope)
            }
        }
        val activity = open(launch.sessionId,pending)
        kotlinx.coroutines.withTimeout(15_000) { while (!entered.get()) kotlinx.coroutines.delay(25) }
        inst.runOnMainSync { activity.finish() }
        inst.waitForIdleSync()
        inst.runOnMainSync {
            val value = PitchActivity::class.java.getDeclaredField("pitchError\$delegate").apply { isAccessible=true }.get(activity) as androidx.compose.runtime.State<*>
            assertNull(value.value)
        }
        assertEquals(PitchBoundary.COMMITTED,store.current.pitch!!.boundary)
        open(launch.sessionId)
        waitFor("pitch.continue")
        assertFalse(device.hasObject(By.res("pitch.error").pkg(context.packageName)))
        assertEquals(pro,store.current.pro)
    }
}
