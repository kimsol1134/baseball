package com.solkim.baseball.android

import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import com.solkim.baseball.application.*
import com.solkim.baseball.application.fixtures.*
import com.solkim.baseball.model.*
import com.solkim.baseball.design.BaseballMigrationTheme
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import java.io.File

class Round7WeeklyUiTest {
    @get:Rule val compose=createComposeRule()
    @get:Rule val failureEvidence=object: org.junit.rules.TestWatcher() {
        override fun failed(error: Throwable, description: org.junit.runner.Description) {
            val inst=InstrumentationRegistry.getInstrumentation()
            val device=UiDevice.getInstance(inst)
            device.takeScreenshot(File(inst.targetContext.cacheDir,"round7-failure.png"))
            device.dumpWindowHierarchy(File(inst.targetContext.cacheDir,"round7-failure.xml"))
        }
    }
    private fun payload(file: String): JsonValue.Obj {
        val inst=InstrumentationRegistry.getInstrumentation()
        return (StrictJson.parseUtf8(inst.context.assets.open("$file.json").use { it.readBytes() }) as JsonValue.Obj)["payload"] as JsonValue.Obj
    }
    private fun capture(name: String) {
        val inst=InstrumentationRegistry.getInstrumentation()
        UiDevice.getInstance(inst).takeScreenshot(File(inst.targetContext.cacheDir,"round7-$name.png"))
    }

    @Test fun oneTaskIsDisabledAndTwoTasksClaimExactlyOnce(): Unit = runBlocking {
        val context=InstrumentationRegistry.getInstrumentation().targetContext
        require(context.packageName=="com.solkim.baseball.android.reset.compose.qa")
        val dir=File(context.cacheDir,"round7-weekly-store").apply { mkdirs() }
        val store=KotlinGameStore.open("round7-ui",CSharpLegacyGameStoreRepository(dir.toPath(),"round7-ui"),NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try {
            store.importCareerBackup(portableCareerFixture(weeklyNoteFixture(payload("high-school-terminal-v42"),1)),store.current.revision)
            val c=ScreenController(store)
            var calls=0
            compose.setContent {
                val state by store.state.collectAsState()
                val busy by store.busy.collectAsState()
                BaseballMigrationTheme { CareerShell(state,busy,null,ScreenId.P024_WEEKLY,ScreenCommandContext(),{}, { a ->
                    calls++
                    runBlocking { c.execute(a.screenId,a.actionId,a.capturedPayloads) }
                }) }
            }
            compose.onNodeWithTag("weekly.requirement").assertIsDisplayed().assertTextContains("2개",substring=true)
            capture("weekly-rule")
            compose.onNodeWithTag("action.claimWeeklyReward").performScrollTo().assertIsDisplayed().assertIsNotEnabled()
            compose.onNodeWithTag("action.claimWeeklyReward").assertContentDescriptionContains("2개",substring=true)
            capture("weekly-one")
            assertEquals(0,calls)
            store.importCareerBackup(portableCareerFixture(weeklyNoteFixture(payload("high-school-terminal-v42"),2)),store.current.revision)
            compose.waitForIdle()
            val before=CareerAccess.school(store.current)!!.inheritance.soulPoints
            compose.onNodeWithTag("action.claimWeeklyReward").assertIsEnabled().performClick()
            compose.waitForIdle()
            compose.onNodeWithTag("action.claimWeeklyReward").performScrollTo().assertIsNotEnabled()
            assertEquals(1,calls)
            assertEquals(before+15,CareerAccess.school(store.current)!!.inheritance.soulPoints)
            assertTrue(CareerAccess.school(store.current)!!.weekly.rewardClaimed)
            capture("weekly-claimed")
        } finally {store.close()}
    }

    @Test fun proRecordTabsHideTheHighSchoolNotebookAndTranslationsExplainTheRule() {
        val state=CSharpLegacyAggregateBridge.project(payload("round4-pro-week"),0UL,"fixture")
        var language by mutableStateOf("ko")
        compose.setContent {
            val config=android.content.res.Configuration(LocalConfiguration.current).apply { setLocale(java.util.Locale.forLanguageTag(language)) }
            CompositionLocalProvider(LocalConfiguration provides config) { BaseballMigrationTheme {
                CareerShell(state,false,null,ScreenId.P025_RECORDS_LEAGUE,ScreenCommandContext(),{}, {})
            } }
        }
        for (locale in listOf("ko","en","ja")) {
            compose.runOnIdle {language=locale}
            compose.onNodeWithTag("records.tab.P-024").assertDoesNotExist()
            compose.onNodeWithTag("action.claimWeeklyReward").assertDoesNotExist()
            val copy=GameCopy(GameLanguage.fromTag(locale))
            val rule=copy.legacy(WeeklyNotePolicy.requirement())
            assertTrue(rule.contains("2"))
            if(locale!="ko") assertFalse(rule.contains("주간"))
        }
        capture("pro-records")
    }

    @Test fun policyLinkFallbackDoesNotThrowWhenNoBrowserCanOpen() {
        var external=0
        assertEquals(PolicyLinks.Launch.CUSTOM_TAB,PolicyLinks.launchWithFallback({}, {external++}))
        assertEquals(0,external)
        assertEquals(PolicyLinks.Launch.EXTERNAL,PolicyLinks.launchWithFallback({throw android.content.ActivityNotFoundException()}, {external++}))
        assertEquals(1,external)
        assertEquals(PolicyLinks.Launch.UNAVAILABLE,PolicyLinks.launchWithFallback(null, {throw android.content.ActivityNotFoundException()}))
        assertEquals(PolicyLinks.Launch.UNAVAILABLE,PolicyLinks.launchWithFallback({throw SecurityException()}, {throw SecurityException()}))
    }

    @Test fun policyAndSupportBodiesOpenAndReturnToSettings() {
        val state=CSharpLegacyAggregateBridge.project(payload("round4-pro-week"),0UL,"fixture")
        compose.setContent { BaseballMigrationTheme { CareerShell(state,false,null,ScreenId.P027_SETTINGS,ScreenCommandContext(),{}, {}) } }
        compose.onNodeWithTag("settings.open.help").performScrollTo().performClick()
        compose.onNodeWithTag("settings.privacy.copy").performScrollTo().assertIsDisplayed()
        val device=UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        for ((key,heading) in listOf("privacy" to "게임 데이터와 품질 정보를", "support" to "게임 이용을 도와드릴게요")) {
            compose.onNodeWithTag("settings.$key").performScrollTo().performClick()
            assertTrue("Policy body must load: $key",device.wait(androidx.test.uiautomator.Until.hasObject(androidx.test.uiautomator.By.textContains(heading)),20_000))
            val activities=device.executeShellCommand("dumpsys activity activities")
            val resumed=activities.lines().filter { it.contains("mResumedActivity") || it.contains("topResumedActivity") }.joinToString("\n")
            assertTrue("Expected policy reader: $resumed",resumed.contains("PolicyDocumentActivity"))
            val context=InstrumentationRegistry.getInstrumentation().targetContext
            File(context.cacheDir,"round7-$key-activity.txt").writeText(resumed)
            capture(key)
            device.pressBack()
            compose.onNodeWithTag("settings.$key.copy").performScrollTo().assertIsDisplayed()
        }
    }
}
