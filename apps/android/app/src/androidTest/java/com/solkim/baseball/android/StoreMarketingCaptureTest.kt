package com.solkim.baseball.android

import android.content.Intent
import androidx.compose.runtime.*
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.*
import com.solkim.baseball.application.*
import com.solkim.baseball.application.fixtures.portableCareerFixture
import com.solkim.baseball.application.fixtures.*
import com.solkim.baseball.application.fixtures.ProStartLinkedRequest
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
    private val language get()=InstrumentationRegistry.getArguments().getString("storeLocale","ko").also { require(it in setOf("ko","en","ja")) }
    private fun source(file:String): JsonValue.Obj = (StrictJson.parseUtf8(inst.context.assets.open(file).use {it.readBytes()}) as JsonValue.Obj)["payload"] as JsonValue.Obj
    private fun capture(name:String) {
        compose.waitForIdle()
        device.takeScreenshot(File(inst.targetContext.cacheDir,"store-$language-$name.png"))
    }

    @Test fun careerScreens() {
        val original=CSharpLegacyAggregateBridge.project(source("round3-linked-pro-return-stage.json"),0UL,"marketing")
        val young=CareerFixtures.chooseSchool("7819",CareerFixtures.completePrologue("7819",CareerFixtures.startHighSchool(HighSchoolPhase4StartRequest("7819","power_prospect","marketing","2026-W37","2026-09-10"))),HighSchoolSchoolId.HAEDONG_POWER)
        fun aggregate(hs:HighSchoolPhase4State,stage:GameStage=GameStage.HIGH_SCHOOL)=GameAggregateState.initial("marketing").withCareers(stage=stage,highSchool=hs,meta=GameAggregateState.initial("marketing").meta.copy(activeHighSchoolCareerId=hs.run.careerId))
        var state by mutableStateOf(aggregate(young))
        var screen by mutableStateOf(ScreenId.P006_TRAINING)
        compose.setContent {
            val config=android.content.res.Configuration(androidx.compose.ui.platform.LocalConfiguration.current).apply {setLocale(java.util.Locale.forLanguageTag(language))}
            CompositionLocalProvider(androidx.compose.ui.platform.LocalConfiguration provides config) { BaseballMigrationTheme { CareerShell(state,false,null,screen,ScreenCommandContext(),{screen=it},{}) } }
        }
        capture("training")
        var talk=CareerFixtures.startDirectPro(ProStartDirectRequest("7819","power_prospect","민서준"))
        var weeks=0
        while(talk.phase!=ProCareerPhase.SEASON_DECISION && weeks++<30) {
            if(talk.phase==ProCareerPhase.WEEKLY_PLAN) talk=CareerFixtures.planWeek(talk,"7819",ProWeekPlan.DEVELOP_STUFF)
            else if(talk.phase==ProCareerPhase.IMPORTANT_GAME) {
                talk=CareerFixtures.reserveProGame(talk,"7819")
                var balls=0
                while(talk.activePitch?.ended==false && balls++<150) talk=CareerFixtures.submitProPitch(talk,talk.activePitch!!.sessionId,
                    PitchCall(PitchKind.FOUR_SEAM,PitchZone(1,1),ZoneIntent.STRIKE,PitchIntensity.NORMAL))
                talk=CareerFixtures.finishProGame(talk)
            } else error("conversation fixture phase: ${talk.phase}")
        }
        require(talk.pendingDecision!=null)
        compose.runOnIdle {state=GameAggregateState.initial("marketing").withCareers(stage=GameStage.PRO,pro=talk);screen=ScreenId.P019_PRO_SEASON}
        val decisionAction=ScreenProjection.project(state,screen).actions.first { it.id.startsWith("seasonDecision:") }
        compose.onNodeWithTag("action.${decisionAction.id}").performScrollTo().performClick()
        capture("conversation")
        val school=requireNotNull(CareerAccess.school(original))
        compose.runOnIdle {state=original.withCareers(pro=null,pitch=null,stage=GameStage.BETWEEN_LIVES);screen=ScreenId.P015_REBIRTH}
        capture("draft")
        val legacy=CareerFixtures.prepareLegacy(school)
        compose.runOnIdle {state=aggregate(legacy);screen=ScreenId.P014_RUN_RECAP}
        val legacyAction=ScreenProjection.project(state,screen).actions.last {it.id.startsWith("selectLegacy:")}
        compose.onNodeWithTag("legacy.option.${legacyAction.id}").performScrollTo().performClick()
        compose.onNodeWithTag("legacy.confirm").performScrollTo()
        capture("legacy")
        val hp=school.run.pitcher
        val draft=requireNotNull(school.run.draftResult)
        val pitcher=PitcherSnapshot(hp.id,hp.name,hp.stuff,hp.command,hp.movement,hp.stamina,pitchProfiles=hp.pitchProfiles,throwingHand=hp.throwingHand,mastery=hp.mastery)
        val pro=CareerFixtures.startLinkedPro(ProStartLinkedRequest("7819",school.run.careerId,school.run.identity.name,pitcher,requireNotNull(draft.teamId),draft.evaluationScore,draftRound=draft.round,overallPick=draft.overallPick,signingBonus=draft.signingBonus?.toLong()))
        compose.runOnIdle {state=GameAggregateState.initial("marketing").withCareers(stage=GameStage.PRO,pro=pro);screen=ScreenId.P016_PRO_CONTRACT}
        val offer=ScreenProjection.project(state,screen).actions.first {it.id.startsWith("acceptOffer:")}
        compose.onNodeWithTag("contract.offer.${offer.id.split(':')[1]}").performScrollTo().performClick()
        compose.onNodeWithTag("contract.goal.${offer.id}").performScrollTo().performClick()
        capture("contract")
        val week=CSharpLegacyAggregateBridge.project(source("round4-pro-week.json"),0UL,"marketing")
        compose.runOnIdle {state=week;screen=ScreenId.P017_PRO_WEEK}
        capture("pro-week")
        compose.runOnIdle {state=original;screen=ScreenId.P028_LIFECARD}
        capture("album")
        File(inst.targetContext.cacheDir,"store-$language-static-proof.json").writeText("""{"source":"shipping Compose views and kernel-created states","screens":7,"width":${device.displayWidth},"height":${device.displayHeight}}""")
    }

}
