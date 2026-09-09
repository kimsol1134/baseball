package com.solkim.baseball.android

import androidx.compose.runtime.*
import androidx.compose.foundation.layout.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.test.platform.app.InstrumentationRegistry
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballMigrationTheme
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import java.io.File

class Round4SurfaceUiTest {
    @get:Rule val compose = createComposeRule()
    @Test fun shortBodyDoesNotCreateFalseScrollingOrAHint() {
        compose.setContent { BaseballMigrationTheme {
            CareerScrollBody(PaddingValues()) { LocalizedGameText("이번 목표") }
        } }
        compose.onNodeWithTag("career.moreContent").assertDoesNotExist()
        val range = compose.onNodeWithTag("career.scrollBody").fetchSemanticsNode()
            .config[androidx.compose.ui.semantics.SemanticsProperties.VerticalScrollAxisRange]
        assertEquals(0f, range.maxValue(), 0f)
    }
    private fun source(file: String = "round3-linked-pro-return-stage.json"): GameAggregateState = runBlocking {
        val inst = InstrumentationRegistry.getInstrumentation()
        val dir = File(inst.targetContext.cacheDir, "round4-surface").apply { mkdirs() }
        File(dir,"save.json").writeBytes(inst.context.assets.open(file).use { it.readBytes() })
        val store = KotlinGameStore.open("r4-ui", CSharpLegacyGameStoreRepository(dir.toPath(), "r4-ui", allowDeviceRestore = true), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try { store.current } finally { store.close(); dir.deleteRecursively() }
    }
    private fun capture(name: String) {
        File(InstrumentationRegistry.getInstrumentation().targetContext.cacheDir,"round4-$name.png").outputStream().use {
            compose.onRoot().captureToImage().asAndroidBitmap().compress(android.graphics.Bitmap.CompressFormat.PNG,100,it)
        }
    }
    @Test fun errorBannerNeverCrushesEitherPitchAction() {
        val state = source()
        var font by mutableFloatStateOf(1f)
        var language by mutableStateOf("ko")
        var message by mutableStateOf<String?>(null)
        compose.setContent {
            val config = android.content.res.Configuration(LocalConfiguration.current).apply { fontScale=font; setLocale(java.util.Locale.forLanguageTag(language)) }
            CompositionLocalProvider(LocalConfiguration provides config, LocalDensity provides Density(LocalDensity.current.density,font)) {
                BaseballMigrationTheme { Phase8Shell(state,false,message,Phase8ScreenId.P018_PRO_IMPORTANT_GAME,Phase8CommandContext(),{}, {}) }
            }
        }
        for (locale in listOf("ko","en","ja")) for (scale in listOf(1f,1.3f,1.5f)) for (error in listOf(null, "중단 처리를 마치지 못했어요. 아래에서 투구를 이어 하거나 저장된 결과를 확인해 주세요.")) {
            compose.runOnIdle { language=locale; font=scale; message=error }
            val density = InstrumentationRegistry.getInstrumentation().targetContext.resources.displayMetrics.density
            val exit = compose.onNodeWithTag("action.abandonPitch").assertIsDisplayed().fetchSemanticsNode().boundsInWindow
            val resume = compose.onNodeWithTag("action.resumePitch").assertIsDisplayed().fetchSemanticsNode().boundsInWindow
            assertTrue(exit.height/density>=47f); assertTrue(resume.height/density>=47f); assertTrue(exit.bottom<=resume.top)
        }
        capture("error-actions")
    }
    @Test fun finalDraftWordsAndFooterAreFullyReachable() {
        val state = source().copy(stage=GameStage.BETWEEN_LIVES,pro=null,pitch=null)
        var font by mutableFloatStateOf(1f)
        var language by mutableStateOf("ko")
        compose.setContent {
            val config=android.content.res.Configuration(LocalConfiguration.current).apply { setLocale(java.util.Locale.forLanguageTag(language)) }
            CompositionLocalProvider(LocalConfiguration provides config, LocalDensity provides Density(LocalDensity.current.density,font)) {
                BaseballMigrationTheme { Phase8Shell(state,false,null,Phase8ScreenId.P015_REBIRTH,Phase8CommandContext(),{}, {}) }
            }
        }
        for (scale in listOf(1f,1.3f,1.5f)) {
            compose.runOnIdle { font=scale }
            compose.onNodeWithTag("career.contentEnd").performScrollTo().assertIsDisplayed()
            val words=compose.onNodeWithTag("draft.finalWords").assertIsDisplayed().fetchSemanticsNode().boundsInWindow
            val body=compose.onNodeWithTag("career.scrollBody").fetchSemanticsNode().boundsInWindow
            assertTrue(words.top>=body.top); assertTrue(words.bottom<=body.bottom)
            val layouts=mutableListOf<androidx.compose.ui.text.TextLayoutResult>()
            compose.onNodeWithTag("draft.finalWords").performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.GetTextLayoutResult) { it(layouts) }
            assertEquals("Every line of the final paragraph must be visible",layouts.single().size.height.toFloat(),words.height,2f)
        }
        capture("draft-end")
        compose.onNodeWithTag("draft.decreases").performScrollTo().performClick()
        val awakening=GameCopy(GameLanguage.KOREAN).legacy(HighSchoolDisplayRules.awakeningTitle("explosive_fastball"))
        compose.onAllNodes(hasText(awakening,substring=true)).onFirst().performScrollTo().assertIsDisplayed()
        for(locale in listOf("en","ja")) {
            compose.runOnIdle {language=locale}
            val node=compose.onAllNodes(hasText("-3",substring=true)).onFirst().performScrollTo().assertIsDisplayed().fetchSemanticsNode()
            val line=node.config[androidx.compose.ui.semantics.SemanticsProperties.Text].joinToString {it.text}
            assertFalse(line,Regex("[가-힣]").containsMatchIn(line))
        }
        capture("ability-history")
    }
    @Test fun navigationLabelsStayInsideTheirBarAcrossScreenChanges() {
        val state=source()
        var screen by mutableStateOf(Phase8ScreenId.P027_SETTINGS)
        compose.setContent { BaseballMigrationTheme { Phase8Shell(state,false,null,screen,Phase8CommandContext(),{screen=it}, {}) } }
        repeat(3) {
            compose.onNodeWithTag("navigation.records").performClick()
            compose.onNodeWithTag("navigation.settings").performClick()
            val root=compose.onRoot().fetchSemanticsNode().boundsInRoot
            val bar=compose.onNodeWithTag("navigation.bar").fetchSemanticsNode().boundsInRoot
            assertTrue(bar.top>root.height*.6f)
            for (tab in listOf("career","records","settings")) {
                val item=compose.onNodeWithTag("navigation.$tab").fetchSemanticsNode().boundsInRoot
                assertTrue(item.top>=bar.top); assertTrue(item.bottom<=bar.bottom)
            }
            // This test covers layout bounds only. The actual status-bar pixels are checked
            // with a full UiDevice screenshot in Round5LiveSurfaceUiTest.

        }
        capture("navigation")
    }
    @Test fun minorCallUpRulesAreReadableInEveryLanguage() {
        val state=source("round4-pro-week.json")
        var language by mutableStateOf("ko")
        compose.setContent {
            val config=android.content.res.Configuration(LocalConfiguration.current).apply { setLocale(java.util.Locale.forLanguageTag(language)) }
            CompositionLocalProvider(LocalConfiguration provides config) { BaseballMigrationTheme {
                Phase8Shell(state,false,null,Phase8ScreenId.P017_PRO_WEEK,Phase8CommandContext(),{}, {})
            } }
        }
        compose.onNodeWithTag("week.promotion").performScrollTo().performClick()
        for(locale in listOf("ko","en","ja")) {
            compose.runOnIdle {language=locale}
            for(index in 0..4) {
                val node=compose.onNodeWithTag("week.promotion.rule.$index").performScrollTo().assertIsDisplayed().fetchSemanticsNode()
                val text=node.config[androidx.compose.ui.semantics.SemanticsProperties.Text].joinToString {it.text}
                if(locale!="ko") assertFalse(text,Regex("[가-힣]").containsMatchIn(text))
            }
        }
        capture("promotion")
    }
    @Test fun singleEffectChoicesStillExposeTheirExplanationWithoutCommitting() {
        var commands=0
        val action=Phase8ActionModel("defer","맞대결까지 보류한다","다음 맞대결에서 판단합니다.",true,effects=listOf(ChoiceEffect("피로",-1)))
        compose.setContent { BaseballMigrationTheme { Column {
            ConversationChoice(action,true,"r4") {commands++}
            ConversationChoice(action.copy(id="complete",description=""),true,"r4") {commands++}
        } } }
        compose.onNodeWithTag("effect.details.defer").performClick()
        compose.onNodeWithText(action.description).assertIsDisplayed()
        compose.onNodeWithTag("effect.details.complete").assertDoesNotExist()
        assertEquals(0,commands)
    }

    @Test fun bothFlightSidesFitAndThePlateIsBelowTheCatcher() {
        for (side in BatSide.entries) {
            val geometry=PitchPlateGeometry.layout(Rect(85f,130f,235f,280f),side)
            for(rect in listOf(geometry.batter,geometry.catcher,geometry.plate)) {
                assertTrue(rect.left>=PitchPlateGeometry.worldBounds.left); assertTrue(rect.right<=PitchPlateGeometry.worldBounds.right)
                assertTrue(rect.top>=PitchPlateGeometry.worldBounds.top); assertTrue(rect.bottom<=PitchPlateGeometry.worldBounds.bottom)
            }
            assertTrue(geometry.plate.top>geometry.catcher.bottom)
        }
        val session=KotlinPitchPresentationSession()
        var side by mutableStateOf(BatSide.RIGHT)
        compose.setContent { BaseballMigrationTheme { Box(Modifier.fillMaxSize()) { PitchDramaView(session.request("r4-flight",0),PitchOutcome.CALLED_STRIKE,batSide=side,progress=.55f,reduceMotion=true) } } }
        for(s in BatSide.entries) { compose.runOnIdle {side=s}; capture("flight-${s.name.lowercase()}") }
    }
}
