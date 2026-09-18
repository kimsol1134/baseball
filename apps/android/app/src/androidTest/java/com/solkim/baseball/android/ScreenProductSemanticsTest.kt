package com.solkim.baseball.android

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.solkim.baseball.application.GameAggregateState
import com.solkim.baseball.application.GameStage
import com.solkim.baseball.application.withCareers
import com.solkim.baseball.application.ScreenCommandContext
import com.solkim.baseball.application.KoreaClock
import com.solkim.baseball.application.ScreenId
import com.solkim.baseball.design.BaseballMigrationTheme
import java.time.LocalDate
import org.junit.Rule
import org.junit.Test
import org.junit.Assert.assertTrue
import org.junit.runner.RunWith

/** Instrumented semantics/layout checks for the actual product shell, not a model-only math test. */
@RunWith(AndroidJUnit4::class)
class ScreenProductSemanticsTest {
    @get:Rule
    val composeRule = createComposeRule()

    private val commandContext = ScreenCommandContext(KoreaClock { LocalDate.of(2026, 8, 14) })

    @Test
    fun openingUsesProductCopyAndExcludesDiagnosticMatrixContent() {
        composeRule.setContent {
            BaseballMigrationTheme {
                CareerShell(
                    state = GameAggregateState.initial("screen-opening"),
                    busy = false,
                    actionError = null,
                    currentScreen = ScreenId.P001_OPENING,
                    commandContext = commandContext,
                    onNavigate = {},
                    onAction = {},
                )
            }
        }

        composeRule.onNodeWithText("야구 못하면 또 환생함").assertIsDisplayed()
        composeRule.onNodeWithText("한 구씩,\n한 생씩.").assertIsDisplayed()
        composeRule.onNodeWithText("시작하기").assertHasClickAction()
        listOf("환생 투수 커리어", "첫 화면", "선수 준비", "다음 선택").forEach { label ->
            assertTrue(composeRule.onAllNodesWithText(label, useUnmergedTree = true).fetchSemanticsNodes().isEmpty())
        }
        assertTrue(composeRule.onAllNodesWithText("P-001", useUnmergedTree = true).fetchSemanticsNodes().isEmpty())
        assertTrue(composeRule.onAllNodesWithText("nativeShadowReadOnly", useUnmergedTree = true).fetchSemanticsNodes().isEmpty())
        assertTrue(composeRule.onAllNodesWithText("payload", useUnmergedTree = true).fetchSemanticsNodes().isEmpty())
        assertTrue(composeRule.onAllNodesWithText("Phase 7", useUnmergedTree = true).fetchSemanticsNodes().isEmpty())
        assertTrue(composeRule.onAllNodesWithText("오늘의 한 이닝", useUnmergedTree = true).fetchSemanticsNodes().isEmpty())
    }

    @Test
    fun setupFieldsAndActionsRemainReadableAtEveryRequiredFontScale() {
        val initial = GameAggregateState.initial("screen-setup")
        val setup = initial.withCareers(stage = GameStage.SETUP).committed()
        var fontScale by mutableStateOf(1.0f)
        composeRule.setContent {
            CompositionLocalProvider(LocalDensity provides Density(density = 1.0f, fontScale = fontScale)) {
                BaseballMigrationTheme {
                    CareerShell(
                        state = setup,
                        busy = false,
                        actionError = null,
                        currentScreen = ScreenId.P002_SETUP,
                        commandContext = commandContext,
                        onNavigate = {},
                        onAction = {},
                    )
                }
            }
        }

        listOf(1.0f, 1.3f, 1.5f, 2.0f).forEach { scale ->
            fontScale = scale
            composeRule.waitForIdle()
            composeRule.onNodeWithText("선수 이름").assertIsDisplayed()
            composeRule.onNodeWithText("선수 이름을 정해 주세요").assertIsDisplayed()
            composeRule.onNodeWithText("지역").assertIsDisplayed()
            composeRule.onNodeWithTag("setup.portrait").assertIsDisplayed()
            composeRule.onNodeWithText("다음").assertIsDisplayed().performClick()
            composeRule.onNodeWithTag("setup.confirm").assertIsDisplayed()
            composeRule.onNodeWithText("이전").performClick()
        }
    }
}
