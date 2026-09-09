package com.solkim.baseball.android

import android.content.Intent
import androidx.compose.runtime.*
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.*
import com.solkim.baseball.application.*
import com.solkim.baseball.application.fixtures.portableCareerFixture
import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.core.pro.ProKernel
import com.solkim.baseball.core.pro.ProCatalog
import com.solkim.baseball.core.pro.ProStartLinkedRequest
import com.solkim.baseball.model.*
import com.solkim.baseball.design.BaseballMigrationTheme
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import java.io.File

/** Marketing captures use the shipping views; fixtures and screen recorder are test-only. */
class StoreMarketingCaptureTest {
    @get:Rule val compose=createComposeRule()
    private val inst get()=InstrumentationRegistry.getInstrumentation()
    private val device get()=UiDevice.getInstance(inst)
    private fun source(file:String): JsonValue.Obj = (StrictJson.parseUtf8(inst.context.assets.open(file).use {it.readBytes()}) as JsonValue.Obj)["payload"] as JsonValue.Obj
    private fun capture(name:String) {
        compose.waitForIdle()
        device.takeScreenshot(File(inst.targetContext.cacheDir,"store-$name.png"))
    }

    @Test fun careerScreens() {
        val original=CSharpLegacyAggregateBridge.project(source("round3-linked-pro-return-stage.json"),0UL,"marketing")
        val hk=HighSchoolPhase4Kernel()
        val young=hk.chooseSchool("7819",hk.completePrologue("7819",hk.start(HighSchoolPhase4StartRequest("7819","power_prospect","marketing","2026-W37","2026-09-10")).state).state,HighSchoolSchoolId.HAEDONG_POWER).state
        fun aggregate(hs:HighSchoolPhase4State,stage:GameStage=GameStage.HIGH_SCHOOL)=GameAggregateState.initial("marketing").copy(stage=stage,highSchool=hs,meta=GameAggregateState.initial("marketing").meta.copy(activeHighSchoolCareerId=hs.run.careerId))
        var state by mutableStateOf(aggregate(young))
        var screen by mutableStateOf(Phase8ScreenId.P006_TRAINING)
        compose.setContent { BaseballMigrationTheme { Phase8Shell(state,false,null,screen,Phase8CommandContext(),{screen=it},{}) } }
        capture("training")
        var relationship=young
        while (relationship.run.phase==HighSchoolPhase.TRAINING) relationship=hk.commitTraining("7819",relationship,HighSchoolTrainingFocus.VELOCITY,HighSchoolTrainingIntensity.STANDARD).state
        compose.runOnIdle {state=aggregate(relationship);screen=Phase8ScreenId.P007_RELATIONSHIP}
        capture("conversation")
        val school=requireNotNull(original.highSchool)
        compose.runOnIdle {state=original.copy(pro=null,pitch=null,stage=GameStage.BETWEEN_LIVES);screen=Phase8ScreenId.P015_REBIRTH}
        capture("draft")
        val legacy=hk.prepareLegacy(school).state
        compose.runOnIdle {state=aggregate(legacy);screen=Phase8ScreenId.P014_RUN_RECAP}
        capture("legacy")
        val pro=ProKernel().startLinked(ProStartLinkedRequest("7819",school.run.careerId,school.run.identity.name,school.run.pitcher,ProCatalog.teams.first().id,88,draftRound=4,overallPick=38,signingBonus=120_000_000)).state
        compose.runOnIdle {state=GameAggregateState.initial("marketing").copy(stage=GameStage.PRO,pro=pro);screen=Phase8ScreenId.P016_PRO_CONTRACT}
        val offer=Phase8ScreenProjection.project(state,screen).actions.first {it.id.startsWith("acceptOffer:")}
        compose.onNodeWithTag("contract.offer.${offer.id.split(':')[1]}").performScrollTo().performClick()
        capture("contract")
        val week=CSharpLegacyAggregateBridge.project(source("round4-pro-week.json"),0UL,"marketing")
        compose.runOnIdle {state=week;screen=Phase8ScreenId.P017_PRO_WEEK}
        capture("pro-week")
        compose.runOnIdle {state=original;screen=Phase8ScreenId.P028_LIFECARD}
        capture("album")
        File(inst.targetContext.cacheDir,"store-static-proof.json").writeText("""{"source":"shipping Compose views and kernel-created states","screens":7,"width":${device.displayWidth},"height":${device.displayHeight}}""")
    }

    @Test fun livePitch():Unit=runBlocking {
        val context=inst.targetContext
        require(context.packageName=="com.solkim.baseball.android.reset.compose.qa")
        val store=(context.applicationContext as BaseballApplication).gameStore
        while(store.busy.value) kotlinx.coroutines.delay(25)
        store.importCareerBackup(portableCareerFixture(source("round3-linked-pro-return-stage.json")),store.current.revision)
        val c=Phase7VerticalController(store)
        val launch=c.resumePitch(requireNotNull(store.current.pitch).sessionId)
        val activity=inst.startActivitySync(PitchActivity.intent(context,launch.sessionId,store.current.revision.toString()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) as PitchActivity
        val slider=requireNotNull(device.wait(Until.findObject(By.res("pitch.slider").pkg(context.packageName)),20_000))
        device.waitForIdle()
        device.takeScreenshot(File(context.cacheDir,"store-pitch.png"))
        val recorder=device.executeShellCommand("sh -c 'screenrecord --bit-rate 12000000 --time-limit 15 /sdcard/baseball-store-pitch.mp4 >/dev/null 2>&1 & echo $!' ").trim()
        kotlinx.coroutines.delay(900)
        val start=android.os.SystemClock.elapsedRealtime()
        val b=slider.visibleBounds
        device.swipe(b.centerX(),b.centerY(),b.centerX()+1,b.centerY(),90)
        require(device.wait(Until.hasObject(By.res("pitch.continue").pkg(context.packageName)),15_000))
        device.takeScreenshot(File(context.cacheDir,"store-result.png"))
        val resultMs=android.os.SystemClock.elapsedRealtime()-start
        kotlinx.coroutines.delay(1800)
        if(recorder.matches(Regex("[0-9]+"))) device.executeShellCommand("kill -INT $recorder")
        File(context.cacheDir,"store-live-proof.json").writeText("""{"resultMs":$resultMs,"outcome":"${PitchLiveResult.outcome(store.current)}","width":${device.displayWidth},"height":${device.displayHeight}}""")
        inst.runOnMainSync {activity.finish()}
    }
}
