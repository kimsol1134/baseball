package com.solkim.baseball.android

import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballMigrationTheme
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class TrainingUiTest {
    @get:Rule val compose = createComposeRule()

    @Test fun selectingDoesNotSpendTrainingAndCommitUsesChosenIntensityAndPitch() {
        val inst = InstrumentationRegistry.getInstrumentation()
        val context = inst.targetContext
        require(context.packageName.endsWith(".compose.qa"))
        val app = context.applicationContext as BaseballApplication
        assertEquals("Use a fresh disposable QA install", GameStage.OPENING, app.gameStore.current.stage)
        val controller = Phase8Controller(app.gameStore)
        runBlocking {
            controller.execute(Phase8ScreenId.P001_OPENING, "enterSetup")
            controller.execute(Phase8ScreenId.P002_SETUP, "startHighSchool")
            controller.execute(Phase8ScreenId.P003_PROLOGUE, "beginTutorial")
            controller.execute(Phase8ScreenId.P003_PROLOGUE, "completeTutorial")
            val school = controller.projection(Phase8ScreenId.P005_SCHOOL_SELECTION).actions.first().id
            controller.execute(Phase8ScreenId.P005_SCHOOL_SELECTION, school)
        }
        val before = app.gameStore.current
        val fontScale = InstrumentationRegistry.getArguments().getString("trainingFontScale")?.toFloatOrNull() ?: 1f
        val focus = if (InstrumentationRegistry.getArguments().getString("trainingFocus") == "command") TrainingFocus.COMMAND else TrainingFocus.BREAKING_BALL
        val intensity = if (focus == TrainingFocus.COMMAND) TrainingIntensity.STANDARD else TrainingIntensity.LIGHT
        val target = TrainingPresentation.targets(before).last()
        compose.setContent {
            val state by app.gameStore.state.collectAsState()
            val busy by app.gameStore.busy.collectAsState()
            CompositionLocalProvider(LocalDensity provides Density(LocalDensity.current.density, fontScale)) { BaseballMigrationTheme {
                Phase8Shell(state, busy, null, Phase8ScreenProjection.preferredScreen(state), controller.context,
                    onNavigate = {}, onAction = { action -> runBlocking { controller.execute(action.screenId, action.actionId, action.capturedPayloads) }; Unit })
            } }
        }
        val device = UiDevice.getInstance(inst)
        compose.waitForIdle()
        device.takeScreenshot(File(context.cacheDir, "training-before.png"))
        compose.onNodeWithTag("training.change").performScrollTo().performClick()
        compose.onNodeWithTag("training.focus.${focus.wire}").performScrollTo().performClick()
        if (focus == TrainingFocus.BREAKING_BALL) compose.onNodeWithTag("training.target.${target.wire}").performScrollTo().performClick()
        compose.onNodeWithTag("training.intensity.${intensity.wire}").performScrollTo().performClick()
        compose.waitForIdle()
        assertEquals(before.highSchool!!.run.totalTrainingsCompleted, app.gameStore.current.highSchool!!.run.totalTrainingsCompleted)
        device.takeScreenshot(File(context.cacheDir, "training-selected.png"))
        compose.onNodeWithTag("training.commit").assertIsDisplayed().performClick()
        compose.waitForIdle()
        compose.onNodeWithTag("training.result").performScrollTo().assertIsDisplayed()
        val after = app.gameStore.current
        val evidence = after.highSchool!!.trainingEvidence.last()
        assertEquals(focus, evidence.focus)
        assertEquals(intensity, evidence.intensity)
        assertEquals(if (focus == TrainingFocus.BREAKING_BALL) target else null, evidence.targetPitch)
        assertEquals(before.highSchool!!.run.totalTrainingsCompleted + 1, after.highSchool!!.run.totalTrainingsCompleted)
        compose.onNodeWithTag("training.result.gains").assertIsDisplayed()
        if (focus == TrainingFocus.COMMAND && before.highSchool!!.run.pitcher.command != after.highSchool!!.run.pitcher.command) {
            compose.onNodeWithTag("growth.controlWindow").performScrollTo().assertIsDisplayed()
        }
        device.takeScreenshot(File(context.cacheDir, "training-after.png"))
        runBlocking {
            val reopened = KotlinGameStore.open(after.installId,
                CSharpLegacyGameStoreRepository(File(context.getExternalFilesDir(null), "save").toPath(), after.installId),
                NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            try {
                assertEquals(after.highSchool!!.trainingEvidence, reopened.current.highSchool!!.trainingEvidence)
                assertEquals(after.meta.playerGrowth, reopened.current.meta.playerGrowth)
            }
            finally { reopened.close() }
        }
    }
}
