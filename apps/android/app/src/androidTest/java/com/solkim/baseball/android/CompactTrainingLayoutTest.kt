package com.solkim.baseball.android

import com.solkim.baseball.application.fixtures.*
import com.solkim.baseball.application.*

import android.content.res.Configuration
import android.os.LocaleList
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import java.util.Locale

class CompactTrainingLayoutTest {
    @get:Rule val compose = createComposeRule()
    @Test fun choicesContainOneLineAcrossLanguagesAndLargeText() {
        val start = CareerFixtures.startHighSchool(HighSchoolPhase4StartRequest("918220", "power_prospect", "training-layout", "2026-W37", "2026-09-08"))
        val ready = CareerFixtures.completePrologue("918220", CareerFixtures.beginTutorial(start))
        val school = CareerFixtures.chooseSchool("918220", ready, HighSchoolSchoolId.HAEDONG_POWER)
        val state = GameAggregateState.initial("training-layout").withCareers(stage = GameStage.HIGH_SCHOOL, highSchool = school)
        var language by mutableStateOf("ko")
        var font by mutableFloatStateOf(1f)
        compose.setContent {
            val configuration = Configuration(LocalConfiguration.current).apply { setLocales(LocaleList(Locale.forLanguageTag(language))) }
            CompositionLocalProvider(LocalConfiguration provides configuration, LocalDensity provides Density(LocalDensity.current.density, font)) {
                BaseballMigrationTheme { Box(Modifier.width(328.dp)) {
                    TrainingScreen(state, ScreenCommandContext(), false, null, PaddingValues(0.dp), 0, 0,
                        onDismiss = {}, onCommit = { error("Preview must not start training") })
                } }
            }
        }
        val density = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext.resources.displayMetrics.density
        fun check(tag: String) {
            val node = compose.onNodeWithTag(tag).performScrollTo().assertIsDisplayed()
            val texts = mutableListOf<TextLayoutResult>()
            node.performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(texts) }
            assertEquals("Button contains extra information: $tag", 1, texts.size)
            assertEquals("$language $font $tag", 1, texts.single().lineCount)
            assertTrue(texts.single().getLineRight(0) <= texts.single().size.width + 1f)
            val height = node.fetchSemanticsNode().boundsInWindow.height / density
            assertTrue("Touch target too small: $tag $height", height >= 47f)
            if (font == 1f) assertTrue("Default button too tall: $tag $height", height <= 50f)
        }
        for (locale in listOf("ko", "en", "ja")) for (scale in listOf(1f, 1.6f)) {
            compose.runOnIdle { language = locale; font = scale }
            TrainingFocus.entries.forEach { check("training.focus.${it.wire}") }
            for (focus in listOf("velocity", "recovery")) {
                compose.onNodeWithTag("training.focus.$focus").performScrollTo().performClick()
                TrainingIntensity.entries.forEach {
                    check("training.intensity.${it.wire}")
                    compose.onNodeWithTag("training.intensity.${it.wire}").performClick().assertIsSelected()
                }
            }
        }
        assertNull(CareerAccess.school(state)!!.run.lastTraining)
    }
}
