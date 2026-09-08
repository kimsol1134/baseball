package com.solkim.baseball.android

import com.solkim.baseball.application.fixtures.*
import com.solkim.baseball.application.*

import androidx.compose.runtime.*
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Rule
import org.junit.Test

class OutingBriefingUiTest {
    @get:Rule val compose = createComposeRule()
    @Test fun closerSeesNinthInningAndGoalWithoutExpandingTheStory() {
        val k = ProKernel()
        val base = k.startDirect(ProStartDirectRequest("918220", "power_prospect", "마무리투수")).state
        val pro = base.copy(phase = ProCareerPhase.IMPORTANT_GAME, role = ProRole.CLOSER, seasonTrigger = ProSeasonTrigger.OPENING_STATEMENT,
            week = 1, seasonSegment = ProCatalog.segment(1)).let { it.copy(commitment = k.commitment(it)) }
        val state = GameAggregateState.initial("briefing-ui").copy(stage = GameStage.PRO, pro = pro)
        compose.setContent { BaseballMigrationTheme {
            Phase8Shell(state, false, null, Phase8ScreenId.P018_PRO_IMPORTANT_GAME, Phase8CommandContext(), onNavigate = {}, onAction = {})
        } }
        compose.onNodeWithTag("outing.role").assertTextEquals("마무리 등판").assertIsDisplayed()
        compose.onNodeWithTag("outing.situation").assertTextContains("9회", substring = true).assertIsDisplayed()
        compose.onNodeWithTag("outing.goal").assertTextEquals("리드를 지켜 이닝 마무리").assertIsDisplayed()
        compose.onAllNodesWithText("선발 맞대결", substring = true).assertCountEquals(0)
        compose.onNodeWithTag("action.openProImportantGame").assertIsDisplayed()
    }
}
