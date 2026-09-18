package com.solkim.baseball.android

import androidx.compose.foundation.layout.*
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class VisualGameContextTest {
    @get:Rule val compose = createComposeRule()
    @Test fun runnersAndOutLightsFollowTheSituationWithoutAParagraph() {
        var bases by mutableStateOf(listOf(1, 3))
        var outs by mutableIntStateOf(1)
        var scale by mutableFloatStateOf(1f)
        compose.setContent { CompositionLocalProvider(LocalDensity provides Density(LocalDensity.current.density, scale)) {
            BaseballMigrationTheme { Surface { Column(Modifier.width(320.dp).padding(12.dp)) {
                VisualOutingSituation(OutingBriefing("마무리 등판", "9회 · 1사 · 1·3루", "2점 앞섬", "", "", "", 9, outs, bases, 2, false, 0))
            } } }
        } }
        fun base(n: Int) = compose.onNodeWithTag("visual.base.$n", useUnmergedTree = true)
        base(1).assertIsSelected(); base(2).assertIsNotSelected(); base(3).assertIsSelected()
        assertTrue(base(1).fetchSemanticsNode().boundsInRoot.center.x > base(2).fetchSemanticsNode().boundsInRoot.center.x)
        assertTrue(base(3).fetchSemanticsNode().boundsInRoot.center.x < base(2).fetchSemanticsNode().boundsInRoot.center.x)
        compose.onNodeWithTag("visual.out.0", useUnmergedTree = true).assertIsSelected()
        compose.onNodeWithTag("visual.out.1", useUnmergedTree = true).assertIsNotSelected()
        compose.runOnIdle { bases = emptyList(); outs = 0; scale = 2f }
        (1..3).forEach { base(it).assertIsNotSelected().assertIsDisplayed() }
        (0..1).forEach { compose.onNodeWithTag("visual.out.$it", useUnmergedTree = true).assertIsNotSelected().assertIsDisplayed() }
        compose.onNodeWithTag("outing.situation").assertIsDisplayed()
    }
}
