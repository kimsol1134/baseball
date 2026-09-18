package com.solkim.baseball.android

import com.solkim.baseball.application.fixtures.*
import com.solkim.baseball.application.*

import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class SetupChoiceLayoutTest {
    @get:Rule val compose = createComposeRule()
    @Test fun rebirthPitchChoicesKeepTheirLabelsAndSelectionAcrossLargeText() {
        val hs = CareerFixtures.startHighSchool(HighSchoolPhase4StartRequest("918220", "power_prospect", "setup-choice", "2026-W37", "2026-09-08"))
        val archive = HighSchoolArchiveRecord("previous", 1, "민서준", null, null, false, 55, null,
            listOf(40, 40, 40, 40), 5, 50, 10, 2, 3, emptyList(), null, null, false, 0, 5UL)
        val state = GameAggregateState.initial("setup-choice").withCareers(stage = GameStage.SETUP, highSchool = hs.copy(archive = listOf(archive)))
        var scale by mutableFloatStateOf(1f)
        compose.setContent { CompositionLocalProvider(LocalDensity provides Density(LocalDensity.current.density, scale)) {
            BaseballMigrationTheme { CareerShell(state, false, null, ScreenId.P002_SETUP, ScreenCommandContext(), onNavigate = {}, onAction = {}) }
        } }
        compose.onNodeWithTag("setup.next").assertIsDisplayed().performClick()
        compose.onNodeWithTag("setup.preset.stats").performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag("setup.next").assertIsDisplayed().performClick()
        for (font in listOf(1f, 1.6f)) {
            compose.runOnIdle { scale = font }
            for (pitch in listOf("slider", "curveball", "changeup")) {
                compose.onNodeWithTag("setup.learning.$pitch").performScrollTo().performClick().assertIsSelected()
                compose.onNodeWithTag("setup.primary.four_seam").performScrollTo().performClick().assertIsSelected()
            }
            compose.onAllNodes(hasText("선택됨", substring = true)).assertCountEquals(0)
        }
        compose.onNodeWithTag("setup.next").assertIsDisplayed().performClick()
        compose.onNodeWithText("혹독하게").performScrollTo().performClick().assertIsSelected()
        compose.onAllNodes(hasText("야구혼", substring = true) and hasClickAction()).assertCountEquals(0)
    }
}
