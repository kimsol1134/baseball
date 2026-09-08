package com.solkim.baseball.android

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.solkim.baseball.application.*
import com.solkim.baseball.core.pro.*
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Rule
import org.junit.Test

class ProfessionalRecordsUiTest {
    @get:Rule val compose = createComposeRule()
    @Test fun aCompletedProOutingAppearsOnTheGamesTab() {
        val k = ProKernel()
        val pro = k.planWeek(k.startDirect(ProStartDirectRequest("918220", "power_prospect", "기록투수")).state, "99881", ProWeekPlan.DEVELOP_STUFF).state
        val state = GameAggregateState.initial("pro-record-ui").copy(stage = GameStage.PRO, pro = pro)
        compose.setContent { BaseballMigrationTheme {
            Phase8Shell(state, false, null, Phase8ScreenId.P011_HIGH_SCHOOL_CAREER, Phase8CommandContext(), onNavigate = {}, onAction = {})
        } }
        compose.onNodeWithText("첫 등판을 마치면 기록이 쌓여요.").assertDoesNotExist()
        compose.onNodeWithTag("records.game.0").performScrollTo().assertExists()
        compose.onNodeWithTag("records.scope").performScrollTo().performClick()
        compose.onNodeWithTag("records.scope.pro:${pro.careerId}:1").performScrollTo().performClick().assertIsSelected()
        compose.onNodeWithTag("records.game.0").performScrollTo().assertExists()
    }
}
