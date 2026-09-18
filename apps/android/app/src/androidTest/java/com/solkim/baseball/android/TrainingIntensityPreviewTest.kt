package com.solkim.baseball.android

import com.solkim.baseball.application.fixtures.*
import com.solkim.baseball.application.*

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.unit.dp
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Rule
import org.junit.Test

class TrainingIntensityPreviewTest {
    @get:Rule val compose = createComposeRule()

    @Test fun changingIntensityUpdatesTheVisibleChanceWithoutTraining() {
        val begun = CareerFixtures.startHighSchool(HighSchoolPhase4StartRequest("918220", "power_prospect", "training-odds-ui", "2026-W36", "2026-09-05"))
        val ready = CareerFixtures.completePrologue("918220", CareerFixtures.beginTutorial(begun))
        val school = CareerFixtures.chooseSchool("918220", ready, HighSchoolSchoolId.CHEONGAM_DEVELOPMENT)
        val state = GameAggregateState.initial("training-odds-ui").withCareers(stage = GameStage.HIGH_SCHOOL, highSchool = school)
        compose.setContent {
            BaseballMigrationTheme {
                TrainingScreen(state, ScreenCommandContext(), false, null, PaddingValues(0.dp), 0, 0,
                    onDismiss = {}, onCommit = { error("A preview must not commit training") })
            }
        }
        compose.onNodeWithTag("training.focus.velocity").performClick()
        listOf("light" to 22, "standard" to 37, "intensive" to 52).forEach { (intensity, chance) ->
            compose.onNodeWithTag("training.intensity.$intensity").performScrollTo().performClick()
            compose.onNodeWithTag("training.jackpot").performScrollTo().assertTextContains("$chance%", substring = true)
        }
    }
}
