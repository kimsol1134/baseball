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
        val game = CareerGameView("pro:album:1:2:1", "1시즌 · 2주차 · 직접", 6, 4, 0, 0, 0, 2, 3, 1, true, "save")
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
