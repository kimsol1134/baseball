package com.solkim.baseball.android

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.application.fixtures.HighSchoolPhase4Kernel
import com.solkim.baseball.application.fixtures.HighSchoolPhase4StartRequest
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Rule
import org.junit.Test

class RebirthGrowthUiTest {
    @get:Rule val compose = createComposeRule()
    @Test fun inheritedStartComparisonUsesTheActualSavedStartingStats() {
        val school = HighSchoolPhase4Kernel().start(HighSchoolPhase4StartRequest("918220", "power_prospect", "growth-ui", "2026-W37", "2026-09-09", lifeNumber = 2)).state
        val previous = listOf(30, 31, 32, 33)
        val state = GameAggregateState.initial("growth-ui").copy(stage = GameStage.HIGH_SCHOOL, highSchool = school,
            meta = GameMetaState(companion = PitcherCompanion(career = school.run.careerId, previousStart = previous)))
        compose.setContent { BaseballMigrationTheme { Surface { Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
            CompanionProfile(state, false) { _, _ -> }
        } } } }
        compose.onNodeWithTag("companion.rebirthGrowth").performScrollTo().assertIsDisplayed()
        val p = school.startingPitcher
        listOf(p.stuff, p.command, p.movement, p.stamina).forEachIndexed { index, value ->
            compose.onNodeWithText("${AbilityDisplayScale.rating(previous[index])} → ${AbilityDisplayScale.rating(value)}").assertExists()
        }
    }
}
