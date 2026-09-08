package com.solkim.baseball.android

import com.solkim.baseball.application.fixtures.*
import com.solkim.baseball.application.*

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class SchoolChoicesUiTest {
    @get:Rule val compose = createComposeRule()
    @Test fun comparisonNeverEnrollsAndRemainsReadableWithLargeText() {
        val kernel = HighSchoolPhase4Kernel()
        val start = kernel.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "school-ui", "2026-W37", "2026-09-08")).state
        val schoolState = kernel.completePrologue("918220", kernel.beginTutorial(start).state).state
        val state = GameAggregateState.initial("school-ui").copy(highSchool = schoolState)
        val model = Phase8ScreenProjection.project(state, Phase8ScreenId.P005_SCHOOL_SELECTION)
        val schools = SchoolChoicePresentation.schools(state)
        var chosen: Phase8UiAction? = null
        var scale by mutableFloatStateOf(1f)
        compose.setContent {
            CompositionLocalProvider(LocalDensity provides Density(LocalDensity.current.density, scale)) {
                BaseballMigrationTheme { Column(Modifier.width(340.dp).fillMaxHeight().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Phase8SchoolChoices(state, model) { chosen = it }
                } }
            }
        }
        for (font in listOf(1f, 1.6f)) {
            compose.runOnIdle { scale = font }
            for (school in schools) {
                compose.onNodeWithTag("school.compare.${school.id.wire}").performScrollTo().performClick()
                compose.onNodeWithTag("school.comparison").assertIsDisplayed()
                compose.onNodeWithTag("school.goal.weakness").performScrollTo().performClick().assertIsSelected()
                compose.onNodeWithTag("school.goal.strength").performScrollTo().performClick().assertIsSelected()
                for (row in schools) compose.onNodeWithTag("school.forecast.${row.id.wire}").performScrollTo().assertIsDisplayed()
                compose.onAllNodesWithText(school.coachName, substring = true).assertCountEquals(0)
                compose.onAllNodesWithText(school.catcherName, substring = true).assertCountEquals(0)
                compose.runOnIdle { assertNull(chosen); assertNull(state.highSchool!!.run.school) }
                compose.onNodeWithTag("school.comparison.close").assertIsDisplayed().performClick()
            }
        }
        val target = schools.last()
        compose.onNodeWithTag("school.compare.${target.id.wire}").performScrollTo().performClick()
        val chosenSchool = schools.first()
        compose.onNodeWithTag("school.forecast.${chosenSchool.id.wire}").performScrollTo().performClick().assertIsSelected()
        compose.onNodeWithTag("school.comparison.choose").assertIsDisplayed().performClick()
        compose.runOnIdle {
            assertEquals("chooseSchool:${chosenSchool.id.wire}", chosen!!.actionId)
            assertEquals(model.actions.single { it.id == chosen!!.actionId }.payloads, chosen!!.capturedPayloads)
        }
    }
}
