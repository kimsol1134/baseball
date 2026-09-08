package com.solkim.baseball.android

import androidx.compose.foundation.layout.*
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.dp
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import com.solkim.baseball.application.*
import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class GrowthAndPlansUiTest {
    @get:Rule val compose = createComposeRule()
    @Test fun planSelectionDoesNotTrainUntilExecuteAndCapturesMixedSteps() {
        val k = HighSchoolPhase4Kernel()
        val school = (918220..918250).firstNotNullOf { seed ->
            val begun = k.start(HighSchoolPhase4StartRequest("$seed", "power_prospect", "plan-ui", "2026-W36", "2026-09-05")).state
            val ready = k.completePrologue("$seed", k.beginTutorial(begun).state).state
            k.chooseSchool("$seed", ready, HighSchoolSchoolId.CHEONGAM_DEVELOPMENT).state.takeIf { it.run.schedule.trainingsByChapter.first() >= 3 }
        }
        val state = GameAggregateState.initial("plan-ui").copy(stage = GameStage.HIGH_SCHOOL, highSchool = school)
        var captured: Phase8UiAction? = null
        compose.setContent { BaseballMigrationTheme { Surface(color = BaseballColors.canvas) {
            TrainingScreen(state, Phase8CommandContext(), false, null, PaddingValues(0.dp), 0, 0, onDismiss = {}, onCommit = { captured = it })
        } } }
        compose.onNodeWithTag("training.repeat").performClick()
        compose.onNodeWithTag("training.plan.control").performClick()
        assertNull(captured)
        compose.onNodeWithTag("training.plan.balanced").performClick()
        compose.onNodeWithTag("training.plan.execute").assertIsDisplayed().performClick()
        val command = (captured!!.capturedPayloads.single().envelope.command as GameCommand.HighSchool).command as HighSchoolPhase4Command.TrainingBlock
        assertEquals(listOf(TrainingFocus.VELOCITY, TrainingFocus.RECOVERY, TrainingFocus.COMMAND), command.requests.map { it.first })
        assertTrue(command.stopForSafety)
        compose.onNodeWithTag("training.plan.execute").assertDoesNotExist()
    }
    @Test fun growthHighlightKeepsActualManualSliderPlayable() {
        compose.mainClock.autoAdvance = false
        var delivered = 0
        compose.setContent { BaseballMigrationTheme { Surface(color = BaseballColors.canvas) {
            Column(Modifier.padding(24.dp)) {
                PitchDeliveryControl(autoRelease = false, enabled = true, commandRating = 50, previousCommand = 35,
                    velocityTenthsKph = 1_450, previousVelocity = 1_420,
                    hapticsEnabled = false, soundEnabled = false, onDeliver = { delivered++ })
            }
        } } }
        compose.mainClock.advanceTimeByFrame()
        compose.onNodeWithTag("pitch.controlWindow.growth").assertIsDisplayed()
        compose.onNodeWithTag("pitch.velocity.growth").assertIsDisplayed()
        val bounds = compose.onNodeWithTag("pitch.slider").assertIsDisplayed().fetchSemanticsNode().boundsInWindow
        UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).swipe(bounds.center.x.toInt(), bounds.center.y.toInt(),
            bounds.center.x.toInt() + 1, bounds.center.y.toInt(), 120)
        compose.mainClock.advanceTimeByFrame()
        compose.runOnIdle { assertEquals(1, delivered) }
    }
}
