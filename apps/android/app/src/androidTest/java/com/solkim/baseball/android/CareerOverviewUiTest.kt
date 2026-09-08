package com.solkim.baseball.android

import android.content.res.Configuration
import android.os.LocaleList
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import com.solkim.baseball.application.*
import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.core.highschool.HighSchoolDraftOutcome
import com.solkim.baseball.core.pro.*
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import java.io.File
import java.util.Locale

/** In-memory display fixtures only: no writes to the installed player's game store. */
class CareerOverviewUiTest {
    @get:Rule val compose = createComposeRule()
    private fun fixture(): GameAggregateState {
        val kernel = HighSchoolPhase4Kernel()
        val initial = kernel.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "overview-qa", "2026-W37", "2026-09-08")).state
        val run = initial.run.copy(phase = HighSchoolPhase.LEGACY,
            draftResult = HighSchoolDraftResult(HighSchoolDraftOutcome.UNDRAFTED, 60, "", null),
            legacyOptions = HighSchoolSignatureLegacyRules.definitions.take(3).map { it.id },
            selectedAwakenings = listOf(HighSchoolAwakening.RISING_FOUR_SEAM),
            performance = initial.run.performance.copy(importantGamesCompleted = 6, strikeouts = 21, perfectReleases = 8))
        val line = HighSchoolSeasonLine(run.careerId, 1, 1, 1, 30, 5, 1, 0, 0, 0, emptyList(), outs = 9, teamRuns = 4, opponentRuns = 2, perfectReleases = 2)
        val hs = kernel.commitShadowState(initial.copy(run = HighSchoolKernel().resignShadowState(run), seasonLog = (1..8).map { line.copy(chapter = it, gameNumber = it) },
            achievements = listOf(HighSchoolAchievementRules.FIRST_STRIKEOUT), unacknowledgedAchievements = listOf(HighSchoolAchievementRules.FIRST_STRIKEOUT)))
        val pro = ProKernel().startDirect(ProStartDirectRequest("918220", "power_prospect", "민서준")).state
        return GameAggregateState.initial("overview-qa").copy(stage = GameStage.HIGH_SCHOOL, highSchool = hs, pro = pro.copy(
            phase = ProCareerPhase.LEGACY_SELECTION, currentStats = pro.currentStats.copy(games = 12, inningsOuts = 90, strikeouts = 42),
            legacyCandidates = HighSchoolSignatureLegacyRules.definitions.take(3).map { ProLegacyCandidate(it.id, it.title, "", "", 1) }))
    }
    private fun capture(name: String) {
        compose.waitForIdle()
        val inst = InstrumentationRegistry.getInstrumentation()
        UiDevice.getInstance(inst).takeScreenshot(File(inst.targetContext.cacheDir, "career-overview-$name.png"))
    }
    @Test fun recapIsCompactAndLookingAtLegacyNeverCommitsIt() {
        val state = fixture().copy(pro = null)
        var captured: Phase8UiAction? = null
        compose.setContent { BaseballMigrationTheme {
            Phase8Shell(state, false, null, Phase8ScreenId.P014_RUN_RECAP, Phase8CommandContext(), onNavigate = {}, onAction = { captured = it })
        } }
        compose.onNodeWithTag("recap.hero").assertIsDisplayed()
        compose.onNodeWithText("스카우트의 계산").assertDoesNotExist()
        compose.onNodeWithTag("legacy.confirm").performScrollTo().assertIsNotEnabled()
        compose.onNodeWithTag("legacy.option.selectLegacy:power_imprint").performScrollTo()
        compose.waitForIdle()
        capture("before-choice")
        compose.onNodeWithTag("legacy.option.selectLegacy:power_imprint").performClick()
        capture("after-choice")
        compose.onNodeWithTag("legacy.option.selectLegacy:power_imprint").assertIsSelected()
        assertNull(captured)
        compose.onNodeWithTag("legacy.option.selectLegacy:command_map").performScrollTo().performClick().assertIsSelected()
        assertNull(captured)
        capture("legacy")
        compose.onNodeWithTag("legacy.confirm").performScrollTo().performClick()
        assertEquals("selectLegacy:command_map", captured!!.actionId)
        assertEquals(Phase8ScreenProjection.project(state, Phase8ScreenId.P014_RUN_RECAP).actions.first { it.id == captured!!.actionId }.payloads, captured!!.capturedPayloads)
    }
    @Test fun singleProLegacyStillRequiresReviewInTheActualShell() {
        val base = fixture()
        val state = base.copy(stage = GameStage.PRO, pro = base.pro!!.copy(legacyCandidates = base.pro!!.legacyCandidates.take(1)))
        var captured: Phase8UiAction? = null
        compose.setContent { BaseballMigrationTheme {
            Phase8Shell(state, false, null, Phase8ScreenId.P022_PRO_LEGACY, Phase8CommandContext(), onNavigate = {}, onAction = { captured = it })
        } }
        compose.onNodeWithTag("legacy.confirm").performScrollTo().assertIsNotEnabled()
        compose.onNodeWithTag("legacy.option.selectProLegacy:power_imprint").performScrollTo()
        compose.waitForIdle()
        compose.onNodeWithTag("legacy.option.selectProLegacy:power_imprint").performClick()
        assertNull(captured)
        compose.onNodeWithTag("legacy.confirm").performScrollTo().performClick()
        assertEquals("selectProLegacy:power_imprint", captured!!.actionId)
    }

    @Test fun historyShowsFiveThenLoadsTheRemainingGames() {
        val state = fixture()
        compose.setContent { BaseballMigrationTheme { Surface(color = BaseballColors.canvas) {
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                CompactCareerOverview(state, Phase8ScreenProjection.project(state, Phase8ScreenId.P011_HIGH_SCHOOL_CAREER), {})
            }
        } } }
        compose.onNodeWithTag("records.game.0").assertExists()
        compose.onNodeWithTag("records.game.5").assertDoesNotExist()
        capture("games")
        compose.onNodeWithTag("records.more").performScrollTo().performClick()
        compose.onNodeWithTag("records.game.7").assertExists()
        compose.onNodeWithTag("records.more").assertDoesNotExist()
    }
    @Test fun allOverviewSurfacesRenderInEnglishAndJapaneseAtLargeText() {
        val state = fixture()
        var screen by mutableStateOf(Phase8ScreenId.P019_PRO_SEASON)
        var tag by mutableStateOf("en")
        compose.setContent {
            val config = Configuration(LocalConfiguration.current).apply { setLocales(LocaleList(Locale.forLanguageTag(tag))) }
            CompositionLocalProvider(LocalConfiguration provides config, LocalDensity provides Density(LocalDensity.current.density, 1.6f)) {
                BaseballMigrationTheme { Surface(color = BaseballColors.canvas) {
                    key(screen, tag) {
                        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            val model = Phase8ScreenProjection.project(state, screen).localized(GameCopy(GameLanguage.fromTag(tag)), state)
                            if (screen == Phase8ScreenId.P014_RUN_RECAP) {
                                CompactLifeRecap(state, model)
                                CareerLegacyPicker(model, model.actions.filter { it.enabled && it.id.startsWith("selectLegacy:") }, {})
                            } else CompactCareerOverview(state, model, {})
                        }
                    }
                } }
            }
        }
        for (language in listOf("en", "ja")) for (target in compactCareerScreens + Phase8ScreenId.P014_RUN_RECAP) {
            compose.runOnIdle { tag = language; screen = target }
            compose.waitForIdle()
            assertTrue(compose.onRoot().fetchSemanticsNode().boundsInRoot.height > 0)
            if (target == Phase8ScreenId.P014_RUN_RECAP) {
                compose.onNodeWithTag("recap.hero").assertIsDisplayed()
                compose.onNodeWithText(if (language == "ja") "試合" else "Games").assertExists()
                compose.onAllNodesWithText("나의 투구 스타일").assertCountEquals(0)
                capture("$language-recap")
                compose.onNodeWithTag("legacy.option.selectLegacy:power_imprint").performScrollTo().performClick()
                compose.onNodeWithTag("legacy.confirm").performScrollTo().assertIsEnabled()
            }
            if (target == Phase8ScreenId.P022_PRO_LEGACY) {
                compose.onAllNodesWithText("Season unknown").assertCountEquals(0)
                compose.onNodeWithTag("legacy.option.selectProLegacy:power_imprint").performScrollTo().performClick()
                compose.onNodeWithTag("legacy.confirm").performScrollTo().assertIsEnabled()
                capture("$language-legacy")
            }
            if (target == Phase8ScreenId.P026_ACHIEVEMENTS) {
                compose.onNodeWithTag("achievement.${HighSchoolAchievementRules.FIRST_STRIKEOUT}").performClick()
                compose.onNodeWithTag("achievement.confirm").assertIsDisplayed()
                // Return by changing keyed content, without acknowledging the actual achievement.
            }
        }
    }
}
