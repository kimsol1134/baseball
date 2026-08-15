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
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.solkim.baseball.application.GameAggregateState
import com.solkim.baseball.application.GameStage
import com.solkim.baseball.application.Phase8CommandContext
import com.solkim.baseball.application.Phase8KoreaClock
import com.solkim.baseball.application.Phase8ScreenId
import com.solkim.baseball.design.BaseballMigrationTheme
import java.time.LocalDate
import org.junit.Rule
import org.junit.Test
import org.junit.Assert.assertTrue
import org.junit.runner.RunWith

/** Instrumented semantics/layout checks for the actual product shell, not a model-only math test. */
@RunWith(AndroidJUnit4::class)
class Phase8ProductSemanticsTest {
    @get:Rule
    val composeRule = createComposeRule()

    private val commandContext = Phase8CommandContext(Phase8KoreaClock { LocalDate.of(2026, 8, 14) })

    @Test
    fun openingUsesProductCopyAndExcludesDiagnosticMatrixContent() {
        composeRule.setContent {
            BaseballMigrationTheme {
                Phase8Shell(
                    state = GameAggregateState.initial("phase8-ui-opening"),
                    busy = false,
                    actionError = null,
                    currentScreen = Phase8ScreenId.P001_OPENING,
                    commandContext = commandContext,
                    onNavigate = {},
                    onAction = {},
                )
            }
        }

        composeRule.onNodeWithText("마운드의 계절").assertIsDisplayed()
        composeRule.onNodeWithText("선수 준비하기").assertHasClickAction()
        assertTrue(composeRule.onAllNodesWithText("P-001", useUnmergedTree = true).fetchSemanticsNodes().isEmpty())
        assertTrue(composeRule.onAllNodesWithText("nativeShadowReadOnly", useUnmergedTree = true).fetchSemanticsNodes().isEmpty())
        assertTrue(composeRule.onAllNodesWithText("payload", useUnmergedTree = true).fetchSemanticsNodes().isEmpty())
        assertTrue(composeRule.onAllNodesWithText("Phase 7", useUnmergedTree = true).fetchSemanticsNodes().isEmpty())
        assertTrue(composeRule.onAllNodesWithText("오늘의 한 이닝", useUnmergedTree = true).fetchSemanticsNodes().isEmpty())
    }

    @Test
    fun setupFieldsAndActionsRemainReadableAtEveryRequiredFontScale() {
        val initial = GameAggregateState.initial("phase8-ui-setup")
        val setup = initial.copy(stage = GameStage.SETUP).let { it.copy(commitment = it.recomputeCommitment()) }
        var fontScale by mutableStateOf(1.0f)
        composeRule.setContent {
            CompositionLocalProvider(LocalDensity provides Density(density = 1.0f, fontScale = fontScale)) {
                BaseballMigrationTheme {
                    Phase8Shell(
                        state = setup,
                        busy = false,
                        actionError = null,
                        currentScreen = Phase8ScreenId.P002_SETUP,
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
            composeRule.onNodeWithText("지역").assertIsDisplayed()
            composeRule.onNodeWithText("고교 이야기 시작").assertIsDisplayed()
        }
    }
}
