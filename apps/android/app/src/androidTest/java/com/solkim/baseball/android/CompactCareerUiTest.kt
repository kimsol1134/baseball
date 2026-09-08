package com.solkim.baseball.android

import androidx.compose.foundation.layout.*
import androidx.compose.material3.Surface
import androidx.compose.ui.semantics.SemanticsProperties
import com.solkim.baseball.design.BaseballColors
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import com.solkim.baseball.application.*
import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.design.BaseballMigrationTheme
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import java.io.File

class CompactCareerUiTest {
    @get:Rule val compose = createComposeRule()
    private fun trainingFixture(): GameAggregateState {
        val k = HighSchoolPhase4Kernel()
        val school = (918220..918240).firstNotNullOf { seed ->
            val begun = k.start(HighSchoolPhase4StartRequest("$seed", "power_prospect", "compact-ui", "2026-W36", "2026-09-05")).state
            val ready = k.completePrologue("$seed", k.beginTutorial(begun).state).state
            k.chooseSchool("$seed", ready, HighSchoolSchoolId.CHEONGAM_DEVELOPMENT).state.takeIf { it.run.schedule.trainingsByChapter.first() >= 2 }
        }
        val state = GameAggregateState.initial("compact-ui").copy(stage = GameStage.HIGH_SCHOOL, highSchool = school)
        return state.copy(commitment = state.recomputeCommitment())
    }
    private fun capture(name: String) {
        val inst = InstrumentationRegistry.getInstrumentation()
        UiDevice.getInstance(inst).takeScreenshot(File(inst.targetContext.cacheDir, name))
    }

    @Test fun normalTrainingNeedsNoScrollAndKeepsChoicesAfterCommit() = runBlocking {
        val store = KotlinGameStore.fromShadowFixture(trainingFixture())
        try {
            val controller = Phase8Controller(store)
            compose.setContent {
                val state by store.state.collectAsState()
                BaseballMigrationTheme {
                    Surface(Modifier.fillMaxSize(), color = BaseballColors.canvas, contentColor = BaseballColors.textPrimary) {
                    Box(Modifier.requiredSize(360.dp, 620.dp)) {
                        TrainingScreen(state, controller.context, false, null, PaddingValues(0.dp), 0, 0, onDismiss = {},
                            onCommit = { action -> runBlocking { controller.execute(action.screenId, action.actionId, action.capturedPayloads) }; Unit })
                    }
                    }
                }
            }
            for (focus in TrainingFocus.entries) compose.onNodeWithTag("training.focus.${focus.wire}").assertIsDisplayed()
            compose.onNodeWithTag("training.focus.breaking_ball").performClick()
            for (level in TrainingIntensity.entries) compose.onNodeWithTag("training.intensity.${level.wire}").assertIsDisplayed()
            compose.onNodeWithTag("training.outlook").assertIsDisplayed()
            compose.onNodeWithTag("training.commit").assertIsDisplayed()
            capture("compact-training.png")
            compose.onNodeWithTag("training.intensity.light").performClick()
            compose.onNodeWithTag("training.commit").performClick()
            compose.onNodeWithTag("training.focus.breaking_ball").assertIsSelected()
            compose.onNodeWithTag("training.intensity.light").assertIsSelected()
            compose.onNodeWithTag("training.result").assertIsDisplayed()
            assertEquals(1, store.current.highSchool!!.run.totalTrainingsCompleted)
            capture("compact-training-result.png")
        } finally { store.close() }
    }

    @Test fun largeTextRetainsReachableControlsAndOpensDetailsSeparately() {
        var state by mutableStateOf(trainingFixture())
        compose.setContent {
            CompositionLocalProvider(LocalDensity provides Density(LocalDensity.current.density, 1.6f)) {
                BaseballMigrationTheme {
                    Box(Modifier.requiredSize(360.dp, 620.dp)) {
                        TrainingScreen(state, Phase8CommandContext(), false, null, PaddingValues(0.dp), 0, 0,
                            onDismiss = {}, onCommit = {
                                val next = HighSchoolPhase4Kernel().commitTraining("918220", state.highSchool!!,
                                    HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.INTENSIVE).state
                                state = state.copy(highSchool = next)
                            })
                    }
                }
            }
        }
        compose.onNodeWithTag("training.focus.command").performClick()
        compose.onNodeWithTag("training.commit").assertIsDisplayed()
        compose.onNodeWithTag("training.details").performScrollTo().performClick()
        compose.onNodeWithTag("training.sheet.close").performScrollTo().performClick()
        compose.onNodeWithTag("training.intensity.intensive").performScrollTo().performClick()
        compose.onNodeWithTag("training.intensity.intensive").assertIsSelected()
        compose.onNodeWithTag("training.jackpot").performScrollTo()
        val before = compose.onNodeWithTag("training.scroll").fetchSemanticsNode().config[SemanticsProperties.VerticalScrollAxisRange].value()
        assertTrue(before > 0f)
        compose.onNodeWithTag("training.commit").performClick()
        val after = compose.onNodeWithTag("training.scroll").fetchSemanticsNode().config[SemanticsProperties.VerticalScrollAxisRange].value()
        assertEquals(before, after, 1f)
        compose.onNodeWithTag("training.result").assertIsDisplayed()
    }

    @Test fun chapterGoesStraightToNextTrainingAndKeepsOptionalGame() {
        val base = trainingFixture()
        val kernel = HighSchoolPhase4Kernel()
        var school = base.highSchool!!
        repeat(school.run.schedule.trainingsByChapter.first()) {
            school = kernel.commitTraining("918220", school, HighSchoolTrainingFocus.VELOCITY, HighSchoolTrainingIntensity.LIGHT).state
        }
        val run = HighSchoolKernel().resignShadowState(school.run.copy(phase = HighSchoolPhase.CHAPTER_REVIEW))
        school = kernel.commitShadowState(school.copy(run = run))
        val state = base.copy(highSchool = school).let { it.copy(commitment = it.recomputeCommitment()) }
        var captured: Phase8UiAction? = null
        compose.setContent { BaseballMigrationTheme {
            Phase8Shell(state, false, null, Phase8ScreenId.P010_CHAPTER, Phase8CommandContext(), onNavigate = {}, onAction = { captured = it })
        } }
        compose.waitUntil(10_000) {
            compose.onAllNodesWithTag("training.commit").fetchSemanticsNodes().any { !it.config.contains(SemanticsProperties.Disabled) }
        }
        compose.onNodeWithTag("training.choices").assertIsDisplayed()
        compose.onNodeWithTag("training.commit").assertIsDisplayed().assertIsEnabled()
        compose.onNodeWithTag("action.advanceChapter").assertDoesNotExist()
        compose.onNodeWithTag("action.claimChapterGame").assertExists()
        compose.onNodeWithTag("training.records").assertExists()
        compose.onNodeWithText("이번에 쌓은 것").assertDoesNotExist()
        compose.onNodeWithText("아직 안 던졌다").assertDoesNotExist()
        compose.onNodeWithTag("career.milestone").assertDoesNotExist()
        capture("compact-chapter.png")
        compose.onNodeWithTag("action.claimChapterGame").performScrollTo().performClick()
        assertEquals("claimChapterGame", captured?.actionId)
        compose.onNodeWithTag("training.commit").performClick()
        assertEquals(Phase8ScreenId.P010_CHAPTER, captured?.screenId)
        assertEquals("advanceChapter", captured?.actionId)
        val commands = captured!!.capturedPayloads.map { (it.envelope.command as GameCommand.HighSchool).command }
        assertTrue(commands.first() is HighSchoolPhase4Command.AdvanceChapter)
        assertTrue(commands.last() is HighSchoolPhase4Command.Training)
    }
}
