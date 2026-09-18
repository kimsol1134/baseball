package com.solkim.baseball.android

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.withCareers
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class AdaptiveActionRowTest {
    @get:Rule val compose = createComposeRule()

    @Test fun shortActionsKeepNaturalWidthAndOnlyOverflowingActionsWrap() {
        compose.setContent { BaseballMigrationTheme {
            AdaptiveActionRow(Modifier.width(280.dp)) {
                Button(onClick = {}, modifier = Modifier.testTag("natural.first")) { Text("선택") }
                Button(onClick = {}, modifier = Modifier.testTag("natural.second")) { Text("닫기") }
                Button(onClick = {}, modifier = Modifier.testTag("natural.third")) { Text("남은 경기 자동 진행") }
            }
        } }
        val first = compose.onNodeWithTag("natural.first").fetchSemanticsNode().boundsInRoot
        val second = compose.onNodeWithTag("natural.second").fetchSemanticsNode().boundsInRoot
        val third = compose.onNodeWithTag("natural.third").fetchSemanticsNode().boundsInRoot
        val density = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext.resources.displayMetrics.density
        assertTrue(first.width / density < 110f)
        assertEquals(first.top, second.top, 1f)
        assertTrue(third.top >= first.bottom)
        assertTrue(first.width / density >= 48f)
    }

    @Test fun shortActionsStayReadableAcrossWidthsLanguagesAndFontSizes() {
        val layouts = mutableMapOf<String, androidx.compose.ui.text.TextLayoutResult>()
        var clicks = 0
        compose.setContent {
            BaseballMigrationTheme {
                Column {
                    listOf(Triple(328, 1f, "이 투수로 시작하기"), Triple(280, 1.3f, "이 투수로 시작하기"),
                        Triple(328, 1f, "Start with this pitcher"), Triple(328, 1f, "この投手で始める")).forEachIndexed { i, (width, scale, label) ->
                        CompositionLocalProvider(LocalDensity provides Density(LocalDensity.current.density, scale)) {
                            AdaptiveActionRow(Modifier.width(width.dp).testTag("row.$i")) {
                                OutlinedButton(onClick = {}, modifier = Modifier.testTag("back.$i")) { Text("이전") }
                                Button(onClick = { clicks++ }, modifier = Modifier.testTag("start.$i")) {
                                    Text(label, onTextLayout = { layouts["$i"] = it })
                                }
                            }
                        }
                    }
                }
            }
        }
        compose.waitForIdle()
        compose.runOnIdle {
            assertEquals(4, layouts.size)
            layouts.forEach { (key, result) ->
                assertEquals("Label $key wrapped", 1, result.lineCount)
                assertFalse("Label $key clipped", result.hasVisualOverflow)
            }
        }
        for (i in 0..3) {
            val row = compose.onNodeWithTag("row.$i").fetchSemanticsNode().boundsInRoot
            val start = compose.onNodeWithTag("start.$i").fetchSemanticsNode().boundsInRoot
            val back = compose.onNodeWithTag("back.$i").fetchSemanticsNode().boundsInRoot
            assertTrue(start.left >= row.left && start.right <= row.right)
            assertTrue("Buttons overlap", start.left >= back.right || start.top >= back.bottom)
            compose.onNodeWithTag("start.$i").performClick()
        }
        compose.runOnIdle { assertEquals(4, clicks) }
    }
    @Test fun actualSetupStartLabelFitsAndSelectionRemainsVisible() {
        val initial = com.solkim.baseball.application.GameAggregateState.initial("layout-qa")
        val setup = initial.withCareers(stage = com.solkim.baseball.application.GameStage.SETUP).committed()
        compose.setContent {
            BaseballMigrationTheme {
                androidx.compose.foundation.layout.Box(Modifier.width(360.dp)) {
                    CareerShell(setup, false, null, com.solkim.baseball.application.ScreenId.P002_SETUP,
                        com.solkim.baseball.application.ScreenCommandContext(com.solkim.baseball.application.KoreaClock { java.time.LocalDate.of(2026, 9, 7) }),
                        onNavigate = {}, onAction = {})
                }
            }
        }
        compose.onNodeWithTag("setup.next").performClick()
        compose.onNodeWithTag("setup.hand.left").performClick()
        compose.onNodeWithTag("setup.hand.left").assertIsSelected()
        val results = mutableListOf<androidx.compose.ui.text.TextLayoutResult>()
        compose.onNodeWithText("시작하기", useUnmergedTree = true)
            .performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.GetTextLayoutResult) { it(results) }
        assertEquals(1, results.single().lineCount)
        // Compose may retain a paragraph wider than the shrink-wrapped Text node.
        // Check the rendered glyph bounds and full string, rather than that paragraph box.
        val result = results.single()
        assertEquals(result.layoutInput.text.length, result.getLineEnd(0))
        assertTrue(result.getLineLeft(0) >= 0)
        assertTrue(result.getLineRight(0) <= result.size.width)
        assertTrue(result.getLineBottom(0) <= result.size.height)
    }

    @Test fun defaultSliderStillCompletesOneDelivery() {
        var deliveries = 0
        val initial = com.solkim.baseball.application.GameAggregateState.initial("layout-slider-qa")
        assertFalse(initial.settings.autoReleaseEnabled)
        compose.setContent {
            BaseballMigrationTheme {
                PitchDeliveryControl(autoRelease = initial.settings.autoReleaseEnabled, enabled = true,
                    onDeliver = { deliveries++ }, hapticsEnabled = false, soundEnabled = false)
            }
        }
        val bounds = compose.onNodeWithTag("pitch.slider").assertIsDisplayed().fetchSemanticsNode().boundsInWindow
        val device = androidx.test.uiautomator.UiDevice.getInstance(androidx.test.platform.app.InstrumentationRegistry.getInstrumentation())
        // Use a real gesture: the slider measures wall time and animates continuously while held.
        device.swipe(bounds.center.x.toInt(), bounds.center.y.toInt(), bounds.center.x.toInt() + 1, bounds.center.y.toInt(), 120)
        compose.runOnIdle { assertEquals(1, deliveries) }
    }

}
