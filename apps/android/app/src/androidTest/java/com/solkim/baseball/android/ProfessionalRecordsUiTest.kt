package com.solkim.baseball.android

import com.solkim.baseball.application.fixtures.*
import com.solkim.baseball.application.*

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Rule
import org.junit.Test

class ProfessionalRecordsUiTest {
    @get:Rule val compose = createComposeRule()
    @Test fun aCompletedProOutingAppearsOnTheGamesTab() {
        val pro = CareerFixtures.planWeek(CareerFixtures.startDirectPro(ProStartDirectRequest("918220", "power_prospect", "기록투수")), "99881", ProWeekPlan.DEVELOP_STUFF)
        val state = GameAggregateState.initial("pro-record-ui").withCareers(stage = GameStage.PRO, pro = pro)
        compose.setContent { BaseballMigrationTheme {
            CareerShell(state, false, null, ScreenId.P011_HIGH_SCHOOL_CAREER, ScreenCommandContext(), onNavigate = {}, onAction = {})
        } }
        compose.onNodeWithText("첫 등판을 마치면 기록이 쌓여요.").assertDoesNotExist()
        compose.onNodeWithTag("records.game.0").performScrollTo().assertExists()
        compose.onNodeWithTag("records.scope").performScrollTo().performClick()
        compose.onNodeWithTag("records.scope.pro:${pro.careerId}:1").performScrollTo().performClick().assertIsSelected()
        compose.onNodeWithTag("records.game.0").performScrollTo().assertExists()
    }
}
