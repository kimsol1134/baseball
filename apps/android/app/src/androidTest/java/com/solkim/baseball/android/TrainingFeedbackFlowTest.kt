package com.solkim.baseball.android

import com.solkim.baseball.application.fixtures.*
import com.solkim.baseball.application.*

import androidx.compose.foundation.layout.*
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.dp
import androidx.test.platform.app.InstrumentationRegistry
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class TrainingFeedbackFlowTest {
    @get:Rule val compose = createComposeRule()
    private fun transitions(focus: TrainingFocus = TrainingFocus.COMMAND): Pair<GameAggregateState, GameAggregateState> {
        val k = HighSchoolPhase4Kernel()
        val start = k.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "feedback-fixture", "2026-W37", "2026-09-08")).state
        val ready = k.completePrologue("918220", k.beginTutorial(start).state).state
        val school = k.chooseSchool("918220", ready, HighSchoolSchoolId.HAEDONG_POWER).state
        val before = GameAggregateState.initial("feedback-fixture").copy(stage = GameStage.HIGH_SCHOOL, highSchool = school)
        val after = before.copy(highSchool = k.commitTraining("918220", school, focus, TrainingIntensity.STANDARD).state)
        return before to after
    }
    @Test fun trainingResultIsVisibleEvenWhenTheNextScreenIsAConversation() {
        val (before, after) = transitions()
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        saveTrainingFeedback(context, before, after)
        compose.setContent { BaseballMigrationTheme {
            Phase8Shell(after, false, null, Phase8ScreenProjection.preferredScreen(after), Phase8CommandContext(), onNavigate = {}, onAction = {})
        } }
        compose.onNodeWithText("훈련 완료").assertIsDisplayed()
        compose.onNodeWithTag("training.growth.bar.1").assertExists()
        context.getSharedPreferences("training.feedback", 0).edit().remove("pending").commit()
    }
    @Test fun actualTrainingChangesAreShownUntilExplicitContinue() {
        val (before, after) = transitions()
        val record = requireNotNull(trainingFeedbackRecord(before, after))
        assertEquals(before.highSchool!!.run.fatigue, record.getInt("fatigueBefore"))
        assertEquals(after.highSchool!!.run.fatigue, record.getInt("fatigueAfter"))
        assertEquals(after.highSchool!!.run.pitcher.command, record.getJSONArray("after").getInt(1))
        var continued = 0
        compose.setContent { BaseballMigrationTheme { Surface { Box(Modifier.height(560.dp)) { TrainingFeedbackPanel(record) { continued++ } } } } }
        compose.onNodeWithTag("training.feedback.stat.1").assertExists()
        compose.mainClock.advanceTimeBy(15_000)
        compose.onNodeWithTag("training.feedback").assertIsDisplayed()
        compose.onNodeWithTag("training.feedback.continue").assertIsDisplayed()
        assertEquals(0, continued)
        val inst = InstrumentationRegistry.getInstrumentation()
        androidx.test.uiautomator.UiDevice.getInstance(inst).takeScreenshot(java.io.File(inst.targetContext.cacheDir, "training-feedback-review.png"))
        compose.onNodeWithTag("training.feedback.continue").performClick()
        assertEquals(1, continued)
        assertNull(trainingFeedbackRecord(after, after))
    }
    @Test fun pendingReceiptSurvivesRemountWithoutRepeatingTraining() {
        val (before, after) = transitions(TrainingFocus.RECOVERY)
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val prefs = context.getSharedPreferences("training.feedback", 0)
        val saved = prefs.getString("pending", null)
        try {
            saveTrainingFeedback(context, before, after)
            var mount by mutableIntStateOf(0)
            compose.setContent { BaseballMigrationTheme { key(mount) { TrainingFeedbackGate(after) } } }
            compose.onNodeWithTag("training.feedback").assertIsDisplayed()
            compose.runOnIdle { mount++ }
            compose.onNodeWithTag("training.feedback").assertIsDisplayed()
            compose.onNodeWithTag("training.feedback.continue").performClick()
            compose.onNodeWithTag("training.feedback").assertDoesNotExist()
            assertNull(prefs.getString("pending", null))
            assertEquals(1, after.highSchool!!.run.totalTrainingsCompleted)
        } finally { prefs.edit().putString("pending", saved).commit() }
    }
    @Test fun resultsWaitAndPracticeAdviceMatchesTheActualProblem() {
        assertTrue(practiceFeedback(PitchDelivery(900, 100)).startsWith("타이밍은 좋아요"))
        assertTrue(practiceFeedback(PitchDelivery(100, 900)).startsWith("조준은 좋아요"))
        var next = 0
        compose.setContent { BaseballMigrationTheme {
            PitchResultCard(outcome = PitchOutcome.BALL, battedBall = null, velocityTenthsKph = 1400,
                delivery = PitchDelivery(900, 900), plateXMm = 0, plateYMm = -650,
                outingContinues = true, plateEnded = false, outingLine = null, onReplay = {}, onInspect = {}, onNextPitch = { next++ }, onPostgame = {})
        } }
        compose.mainClock.advanceTimeBy(15_000)
        assertEquals(0, next)
        compose.onNodeWithTag("pitch.continue").assertIsDisplayed().performClick()
        assertEquals(1, next)
        compose.onNodeWithTag("pitch.plateDiagram").assertIsDisplayed()
    }
}
