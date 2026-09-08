package com.solkim.baseball.android

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.material3.Surface
import com.solkim.baseball.design.BaseballColors
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Rule
import org.junit.Test
import org.junit.Assert.*

class PlayerAlbumUiTest {
    @get:Rule val compose = createComposeRule()
    private fun state(): GameAggregateState {
        val game = CareerGameView("pro:album:1:2:1", "1시즌 · 2주차 · 직접", 6, 4, 0, 0, 0, 2, 3, 1, true, "save", earnedRuns = 0)
        val pitch = AlbumPitch("saved-pitch", "four_seam", 1492, (0..24).flatMap { listOf(it, it*8, 18000-it*700, 1500-it*10) }, "saved-game", "swinging_strike", listOf(9, 2, 1, 1, 0))
        val page = PlayerAlbumPage(RecordScope("pro:album:1", "프로 1시즌", "앨범투수"), 1, 6, 0, 4, true, listOf(game), listOf(pitch), affiliation = "대구 포지")
        return GameAggregateState.initial("album-test").copy(meta = GameMetaState(album = listOf(page))).committed()
    }
    @Test fun previewAndReplayNeverChangeTheCareer() {
        val state = state(); val original = state.recomputeCommitment()
        compose.setContent { BaseballMigrationTheme {
            Surface(color = BaseballColors.canvas, contentColor = BaseballColors.textPrimary) { Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) { PlayerAlbumView(state) } }
        } }
        compose.waitForIdle()
        Thread.sleep(350)
        androidx.test.uiautomator.UiDevice.getInstance(androidx.test.platform.app.InstrumentationRegistry.getInstrumentation()).takeScreenshot(java.io.File(androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext.cacheDir, "album-overview.png"))
        compose.onNodeWithTag("album.card").performScrollTo().performClick()
        compose.onNodeWithText("카드 미리보기").assertIsDisplayed()
        compose.waitForIdle()
        Thread.sleep(350)
        androidx.test.uiautomator.UiDevice.getInstance(androidx.test.platform.app.InstrumentationRegistry.getInstrumentation()).takeScreenshot(java.io.File(androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext.cacheDir, "album-card-preview.png"))
        compose.onNodeWithText("닫기").performClick()
        compose.onNodeWithTag("album.replay").performScrollTo().performClick()
        compose.onNodeWithTag("album.replay.canvas").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("재생").performScrollTo().performClick()
        compose.waitUntil(5000) { compose.onAllNodesWithText("헛스윙").fetchSemanticsNodes().isNotEmpty() }
        assertEquals(original, state.recomputeCommitment())
    }
    @Test fun sharingStaysAboveExpandedDetailedStats() {
        compose.setContent { BaseballMigrationTheme {
            Surface(color = BaseballColors.canvas, contentColor = BaseballColors.textPrimary) {
                Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) { PlayerAlbumView(state()) }
            }
        } }
        compose.onNodeWithTag("album.pitching.stats").performScrollTo().performClick()
        val share = compose.onNodeWithTag("album.card").fetchSemanticsNode().boundsInRoot
        val details = compose.onNodeWithTag("album.pitching.stats").fetchSemanticsNode().boundsInRoot
        assertTrue("Share entry must remain above the details", share.bottom <= details.top)
        compose.onNodeWithTag("album.card").performScrollTo().performClick()
        compose.onNodeWithText("카드 미리보기").assertIsDisplayed()
    }
    @Test fun exportContainsACompleteBaseballStatLine() {
        val context = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext
        val stats = AlbumPitchingStats(28, 486, 184, 43, 122, 36, 25, 15, 4, 0, 12, 2480, earnedRuns = 35)
        val card = com.solkim.baseball.platform.AlbumShareCard("시즌 결산", "민서준", "대구 포지 · 프로 3시즌", emptyList(), "1번째 생 · 대표 구종 포심", "야구 못하면 또 환생함", stats.line, stats.rates)
        val name = PlayerPortraitResolver.resolveDrawableName("민서준", AvatarRole.PLAYER, PlayerStage.PRO)
        val id = context.resources.getIdentifier(name, "drawable", context.packageName)
        val portrait = android.graphics.BitmapFactory.decodeResource(context.resources, id)
        val bitmap = com.solkim.baseball.platform.NativePlayerAlbumShareService(context).render(card, portrait)
        try {
            assertEquals(1080, bitmap.width); assertEquals(1350, bitmap.height)
            java.io.File(context.cacheDir, "card-redesign-season.png").outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
        } finally { bitmap.recycle(); portrait.recycle() }
    }
    @Test fun albumControlsUseEnglishAndJapanese() {
        var language by mutableStateOf("en")
        compose.setContent {
            val config = android.content.res.Configuration(androidx.compose.ui.platform.LocalConfiguration.current).apply {
                setLocales(android.os.LocaleList(java.util.Locale.forLanguageTag(language)))
            }
            CompositionLocalProvider(androidx.compose.ui.platform.LocalConfiguration provides config) { BaseballMigrationTheme {
                Surface(color = BaseballColors.canvas, contentColor = BaseballColors.textPrimary) {
                    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) { PlayerAlbumView(state()) }
                }
            } }
        }
        compose.onNodeWithText("Player album").assertExists()
        compose.onNodeWithTag("album.card").performScrollTo().performClick()
        compose.onNodeWithText("Card preview").assertIsDisplayed()
        compose.onNodeWithText("Close").performClick()
        compose.runOnIdle { language = "ja" }
        compose.onNodeWithText("選手アルバム").assertExists()
        compose.onNodeWithTag("album.card").performScrollTo().performClick()
        compose.onNodeWithText("カードのプレビュー").assertIsDisplayed()
        compose.onNodeWithText("閉じる").performClick()
    }
    @Test fun detailedNumbersStayOnOneLineForALargeTextBaseballFan() {
        compose.setContent {
            val density = LocalDensity.current
            CompositionLocalProvider(LocalDensity provides Density(density.density, 2f)) { BaseballMigrationTheme {
                Surface(color = BaseballColors.canvas, contentColor = BaseballColors.textPrimary) {
                    Column(Modifier.width(280.dp)) { AlbumStatGrid(listOf("IP" to "162.2", "NP" to "2480", "WHIP" to "1.08", "K/BB" to "10.25")) }
                }
            } }
        }
        for (value in listOf("162.2", "2480", "1.08", "10.25")) {
            val layouts = mutableListOf<androidx.compose.ui.text.TextLayoutResult>()
            compose.onNodeWithText(value).performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.GetTextLayoutResult) { it(layouts) }
            assertEquals("A baseball number must not wrap: $value", 1, layouts.single().lineCount)
            val layout = layouts.single()
            assertEquals("The complete number must be on the line", value.length, layout.getLineEnd(0, visibleEnd = true))
            assertTrue("Number extends beyond the cell: $value", layout.getLineRight(0) <= layout.size.width + 1f)
            assertTrue("Number is clipped vertically: $value", layout.getBoundingBox(value.lastIndex).bottom <= layout.size.height + 1f)
        }
        val inst = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation()
        androidx.test.uiautomator.UiDevice.getInstance(inst).takeScreenshot(java.io.File(inst.targetContext.cacheDir, "persona-large-stats.png"))
    }
    @Test fun largeTextStillAllowsCardPreviewAndClosing() {
        compose.setContent { val density = LocalDensity.current
            CompositionLocalProvider(LocalDensity provides Density(density.density, 2f)) { BaseballMigrationTheme {
                Surface(color = BaseballColors.canvas, contentColor = BaseballColors.textPrimary) { Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) { PlayerAlbumView(state()) } }
            } }
        }
        compose.onNodeWithTag("album.card").performScrollTo().performClick()
        compose.onNodeWithText("닫기").assertIsDisplayed().performClick()
        compose.onNodeWithTag("album.card").assertExists()
    }
}
