package com.solkim.baseball.android

import com.solkim.baseball.application.fixtures.*
import com.solkim.baseball.application.*

import androidx.compose.runtime.*
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.platform.app.InstrumentationRegistry
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class ProWeekUiTest {
    @get:Rule val compose = createComposeRule()
    @Test fun batchUsesTheVisibleRecoveryChoice() {
        val pro = ProKernel().startDirect(ProStartDirectRequest("918220", "power_prospect", "회복투수")).state
        val state = GameAggregateState.initial("batch-ui").copy(stage = GameStage.PRO, pro = pro)
        var captured: Phase8UiAction? = null
        compose.setContent { BaseballMigrationTheme {
            Phase8Shell(state, false, null, Phase8ScreenId.P017_PRO_WEEK, Phase8CommandContext(), onNavigate = {}, onAction = { captured = it })
        } }
        compose.onNodeWithTag("week.select.proPlan:recover").performScrollTo().performClick()
        compose.onNodeWithTag("week.batch").performScrollTo().performClick()
        compose.onNodeWithText("진행 계획 · 회복").assertExists()
        assertNull(captured)
        compose.onNodeWithTag("week.batch.commit").performScrollTo().performClick()
        val command = (captured!!.capturedPayloads.single().envelope.command as GameCommand.Pro).command as FixtureProAdvanceSegment
        assertEquals(ProWeekPlan.RECOVER, command.plan)
        assertEquals("proAdvanceSegment", captured!!.actionId)
    }
    @Test fun selectionWaitsForCommitAndUnacknowledgedResultsSurviveRemount() {
        val k = ProKernel()
        val pro = k.startDirect(ProStartDirectRequest("918220", "power_prospect", "주간투수")).state
        var state by mutableStateOf(GameAggregateState.initial("week-ui").copy(stage = GameStage.PRO, pro = pro))
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val prefs = context.getSharedPreferences("pro.week.feedback", 0)
        val saved = prefs.getString("pending", null)
        var mount by mutableIntStateOf(0)
        var commits = 0
        try {
            prefs.edit().remove("pending").commit()
            compose.setContent { BaseballMigrationTheme { key(mount) {
                Phase8Shell(state, false, null, Phase8ScreenId.P017_PRO_WEEK, Phase8CommandContext(), onNavigate = {}, onAction = { action ->
                    val before = state
                    action.capturedPayloads.forEach { state = GameStateReducer.dispatch(state, it.envelope).state }
                    saveProWeekFeedback(context, before, state)
                    commits++
                })
            } } }
            compose.onNodeWithTag("week.select.proPlan:refine_command").performScrollTo().performClick().assertIsSelected()
            assertEquals(0, commits); assertEquals(0, state.pro!!.week)
            compose.onNodeWithTag("week.commit").performScrollTo().performClick()
            compose.onNodeWithTag("week.result").assertIsDisplayed()
            compose.mainClock.advanceTimeBy(15_000)
            compose.runOnIdle { mount++ }
            compose.onNodeWithTag("week.result").assertIsDisplayed()
            compose.onNodeWithTag("week.result.continue").performClick()
            compose.onNodeWithTag("week.result").assertDoesNotExist()
            assertEquals(1, commits); assertEquals(1, state.pro!!.week)
        } finally { prefs.edit().putString("pending", saved).commit() }
    }
}
