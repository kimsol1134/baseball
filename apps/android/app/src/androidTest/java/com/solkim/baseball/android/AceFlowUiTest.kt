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
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class AceFlowUiTest {
    @get:Rule val compose = createComposeRule()
    private fun capture(name: String) {
        val inst = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation()
        androidx.test.uiautomator.UiDevice.getInstance(inst).takeScreenshot(java.io.File(inst.targetContext.cacheDir, name))
    }
    @Test fun eighthInningDecisionWaitsAndHasSeparateHandOffAndSimulationActions() {
        var continued = 0; var handedOff = 0; var simulated = 0
        compose.setContent { BaseballMigrationTheme { Surface { Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
            PitchResultCard(outcome = PitchOutcome.IN_PLAY_OUT, battedBall = null, velocityTenthsKph = 1490, delivery = null,
                plateXMm = 0, plateYMm = 0, outingContinues = false, plateEnded = true, outingLine = "8이닝 무실점",
                onReplay = {}, onInspect = {}, onNextPitch = null, onPostgame = { simulated++ },
                onContinueInning = { continued++ }, onHandOff = { handedOff++ },
                inningDecision = "8회 종료 · 94구 · 0실점\n완봉 도전까지 아웃 3개")
        } } } }
        compose.onNodeWithText("8회 종료 · 94구 · 0실점").assertExists()
        compose.mainClock.advanceTimeBy(10_000)
        assertEquals(0, continued + handedOff + simulated)
        capture("ace-eight-inning.png")
        compose.onNodeWithTag("pitch.nextInning").performScrollTo().performClick()
        assertEquals(1, continued); assertEquals(0, handedOff + simulated)
        compose.onNodeWithTag("pitch.simulateRemainder").performScrollTo().performClick()
        assertEquals(1, handedOff); assertEquals(0, simulated)
        compose.onNodeWithTag("pitch.autoOuting").performScrollTo().performClick()
        assertEquals(1, simulated)
    }
    @Test fun rebirthPathSelectionDoesNotStartUntilTheChosenPathIsConfirmed() {
        val state = GameAggregateState.initial("path-ui")
        val id = ScreenId.P015_REBIRTH
        val paths = listOf("endurance", "closer", "command").map { ScreenActionModel("rebirthPath:$it", AceCareerPresentation.pathTitle(it), "새로운 구종과 성장 유형", true) }
        val model = ScreenModel(id, "환생", "새로운 길", emptyList(), paths, ScreenPayloads.view(state, id))
        var selected: String? = null
        compose.setContent { BaseballMigrationTheme { Surface { Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
            RebirthPathPicker(state, model) { selected = it.actionId }
        } } } }
        compose.onNodeWithTag("rebirth.path.closer").performClick().assertIsSelected()
        compose.onNodeWithTag("rebirth.path.endurance").assertIsNotSelected()
        assertNull(selected)
        capture("ace-rebirth-path.png")
        compose.onNodeWithTag("rebirth.path.start").performScrollTo().performClick()
        assertEquals("rebirthPath:closer", selected)
    }
}
