package com.solkim.baseball.android

import com.solkim.baseball.application.fixtures.*
import com.solkim.baseball.application.*

import androidx.compose.runtime.*
import androidx.compose.material3.Surface
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.unit.dp
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import com.solkim.baseball.design.BaseballMigrationTheme
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.Assert.*
import java.io.File

/** Independent fixture: never clears or advances the installed user's career. */
@RunWith(AndroidJUnit4::class)
class CareerParityUiTest {
    @get:Rule val compose = createComposeRule()
    private fun fixture(awakening: Boolean = false, rebirth: Boolean = false): GameAggregateState = runBlocking {
        val id = "parity-ui"
        val store = KotlinGameStore.open(id, InMemoryShadowFixtureGameStoreRepository(GameAggregateState.initial(id)), NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY)
        try {
            val c = Phase8Controller(store)
            c.execute(Phase8ScreenId.P001_OPENING, "enterSetup")
            c.execute(Phase8ScreenId.P002_SETUP, "startHighSchool")
            c.execute(Phase8ScreenId.P003_PROLOGUE, "beginTutorial")
            c.execute(Phase8ScreenId.P003_PROLOGUE, "completeTutorial")
            c.execute(Phase8ScreenId.P005_SCHOOL_SELECTION, c.projection(Phase8ScreenId.P005_SCHOOL_SELECTION).actions.first().id)
            if (awakening || rebirth) {
                val pitching = Phase7VerticalController(store)
                var turns = 0
                fun arrived() = if (rebirth) store.current.highSchool?.archive?.any { it.careerId == store.current.highSchool?.run?.careerId } == true
                    else c.preferredScreen() == Phase8ScreenId.P009_AWAKENING
                while (!arrived()) {
                    check(turns++ < 300) { "No awakening reached" }
                    val pitch = store.current.pitch
                    if (pitch != null && pitch.boundary != PitchBoundary.COMPLETED) {
                        pitching.fastForwardCurrentBatter()
                        continue
                    }
                    when (val screen = c.preferredScreen()) {
                        Phase8ScreenId.P006_TRAINING -> pitching.commitTraining()
                        Phase8ScreenId.P007_RELATIONSHIP -> pitching.resolveRelationship()
                        Phase8ScreenId.P010_CHAPTER -> pitching.advanceChapter()
                        Phase8ScreenId.P014_RUN_RECAP -> {
                            val actions = c.projection(screen).actions
                            val chosen = actions.firstOrNull { it.enabled && it.id.startsWith("selectLegacy:") }
                                ?: actions.first { it.enabled && it.id == "prepareLegacy" }
                            c.execute(screen, chosen.id)
                        }
                        Phase8ScreenId.P015_REBIRTH -> {
                            if (c.projection(screen).actions.single { it.id == "finalizeArchive" }.enabled) c.execute(screen, "finalizeArchive")
                            else c.execute(Phase8ScreenId.P014_RUN_RECAP, "prepareLegacy")
                        }
                        else -> {
                            val action = c.projection(screen).actions.firstOrNull { it.enabled && it.id !in setOf("abandonPitch", "suspendPitch") } ?: error("No action at $screen")
                            c.execute(screen, action.id)
                        }
                    }
                }
            }
            store.current
        } finally { store.close() }
    }
    @Test fun learningChoiceCommitsAndShowsRealStage() {
        var state by mutableStateOf(fixture())
        val context = Phase8CommandContext()
        val learningPitch = state.highSchool!!.run.pitchLearningProject!!.pitchType.wire
        compose.setContent { BaseballMigrationTheme { Surface {
            TrainingScreen(state, context, false, null, WindowInsets.safeDrawing.asPaddingValues(), 0, 0, {}, { action ->
                action.capturedPayloads.orEmpty().forEach { state = GameStateReducer.dispatch(state, it.envelope).state }
            })
        } } }
        compose.onNodeWithTag("training.learning").performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag("training.focus.breaking_ball").performScrollTo().performClick()
        compose.onNodeWithTag("training.target.$learningPitch").performScrollTo().performClick()
        compose.onNodeWithTag("training.intensity.intensive").performScrollTo().performClick()
        assertEquals(0, state.highSchool!!.run.totalTrainingsCompleted)
        compose.onNodeWithTag("training.commit").performClick()
        compose.waitForIdle()
        assertEquals(3, state.highSchool!!.run.pitchLearningProject!!.practiceCredits)
        compose.onNodeWithTag("training.learning").performScrollTo().assertIsDisplayed()
        UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).takeScreenshot(File(InstrumentationRegistry.getInstrumentation().targetContext.cacheDir, "parity-learning.png"))
    }
    @Test fun treeShowsLockedBranchesAndConfirmsExactlyOneChoice() {
        var state by mutableStateOf(fixture(awakening = true))
        val model = Phase8ScreenProjection.project(state, Phase8ScreenId.P009_AWAKENING, Phase8CommandContext())
        compose.setContent { BaseballMigrationTheme { Surface(color = androidx.compose.material3.MaterialTheme.colorScheme.background) {
            Box(Modifier.fillMaxSize().systemBarsPadding()) {
                AwakeningTreeView(state, model, { action ->
                    action.capturedPayloads.forEach { state = GameStateReducer.dispatch(state, it.envelope).state }
                })
            }
        } } }
        compose.onNodeWithTag("awakening.node.rising_four_seam").performScrollTo().performClick()
        compose.onNodeWithTag("awakening.confirm").assertIsNotEnabled()
        compose.onNodeWithTag("awakening.branch.command").performClick()
        compose.onNodeWithTag("awakening.node.pinpoint_edge").assertExists()
        compose.onNodeWithTag("awakening.node.rising_four_seam").assertDoesNotExist()
        compose.onNodeWithTag("awakening.branch.power").performClick()
        compose.onNodeWithTag("awakening.node.explosive_fastball").performScrollTo().performClick()
        assertEquals(0, state.highSchool!!.run.selectedAwakenings.size)
        compose.onNodeWithTag("awakening.benefit").assertIsDisplayed()
        compose.onNodeWithTag("awakening.cost").assertIsDisplayed()
        compose.onNodeWithTag("awakening.confirm").assertIsDisplayed().assertIsEnabled()
        UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).takeScreenshot(File(InstrumentationRegistry.getInstrumentation().targetContext.cacheDir, "skill-tree-native.png"))
        compose.onNodeWithTag("awakening.confirm").performClick()
        compose.waitForIdle()
        assertEquals(listOf("explosive_fastball"), state.highSchool!!.run.selectedAwakenings.map { it.wire })
        compose.onNodeWithTag("awakening.confirm").assertIsNotEnabled()
    }
    @Test fun treeSupportsLargeJapaneseTextAndShowsOnlyLegalLeap() {
        val original = fixture(awakening = true)
        val school = original.highSchool!!
        val core = com.solkim.baseball.application.fixtures.HighSchoolKernel()
        val root = com.solkim.baseball.application.fixtures.HighSchoolAwakening.PINPOINT_EDGE
        // A legal leap now requires a reborn player in the later school years with enough training and innings.
        var run = school.run.copy(selectedAwakenings = listOf(root), awakeningSparks = 3, lifeNumber = 2,
            chapter = com.solkim.baseball.application.fixtures.HighSchoolContentCatalog.chapters[4],
            totalTrainingsCompleted = 6, automaticOuts = 36,
            pitcher = core.previewAwakening(school.run.pitcher, root).copy(command = 60))
        run = core.resignShadowState(run.copy(awakeningOptions = core.availableAwakenings(run)))
        val nextSchool = com.solkim.baseball.application.fixtures.HighSchoolPhase4Kernel().commitShadowState(school.copy(run = run))
        val state = original.copy(highSchool = nextSchool).let { it.copy(commitment = it.recomputeCommitment()) }
        var config by mutableStateOf(android.content.res.Configuration(InstrumentationRegistry.getInstrumentation().targetContext.resources.configuration).apply { setLocale(java.util.Locale.JAPANESE) })
        compose.setContent {
            CompositionLocalProvider(androidx.compose.ui.platform.LocalConfiguration provides config,
                androidx.compose.ui.platform.LocalDensity provides androidx.compose.ui.unit.Density(androidx.compose.ui.platform.LocalDensity.current.density, 1.6f)) {
                BaseballMigrationTheme { Surface(color = androidx.compose.material3.MaterialTheme.colorScheme.background) {
                    Box(Modifier.requiredSize(360.dp, 620.dp)) {
                        AwakeningTreeView(state, Phase8ScreenProjection.project(state, Phase8ScreenId.P009_AWAKENING), {})
                    }
                } }
            }
        }
        compose.onNodeWithTag("awakening.branch.command").performClick()
        compose.onNodeWithTag("awakening.node.calm_under_pressure").performScrollTo().performClick()
        compose.onNodeWithTag("awakening.confirm").assertIsDisplayed().assertIsEnabled()
        compose.onNodeWithTag("awakening.node.explosive_fastball").assertDoesNotExist()
        compose.onNodeWithTag("awakening.branch.breaking").performClick()
        compose.onNodeWithTag("awakening.node.frozen_changeup").performScrollTo().performClick()
        compose.onNodeWithTag("awakening.confirm").assertIsDisplayed().assertIsNotEnabled()
        compose.runOnIdle { config = android.content.res.Configuration(config).apply { setLocale(java.util.Locale.ENGLISH) } }
        compose.onNodeWithTag("awakening.branch.power").performClick()
        compose.onNodeWithTag("awakening.node.explosive_fastball").performScrollTo().performClick()
        compose.onNodeWithTag("awakening.confirm").assertIsDisplayed().assertIsEnabled()
    }
    @Test fun rebirthPreviewAndPinnedActionMatchActualNextStart() {
        var state by mutableStateOf(fixture(rebirth = true))
        val context = Phase8CommandContext()
        val before = state
        val quick = Phase8ScreenProjection.project(state, Phase8ScreenId.P015_REBIRTH, context).actions.single { it.id == "quickRebirth" }
        val expected = requireNotNull(RebirthStartPreview.resolve(state, quick))
        compose.setContent { BaseballMigrationTheme {
            Phase8Shell(state, false, null, Phase8ScreenProjection.preferredScreen(state), context,
                onNavigate = {}, onAction = { action -> action.capturedPayloads.forEach { state = GameStateReducer.dispatch(state, it.envelope).state } })
        } }
        if (ProfessionalStatusPresentation.canEnterPro(state)) {
            compose.onNodeWithTag("action.startLinked").assertIsDisplayed()
            compose.onNodeWithTag("career.otherPath").performScrollTo().performClick()
        }
        compose.waitUntil(10_000) { compose.onAllNodesWithTag("rebirth.startComparison").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("rebirth.startComparison").performScrollTo()
        if (ProfessionalStatusPresentation.canEnterPro(state)) compose.onNodeWithTag("action.quickRebirth").performScrollTo()
        compose.onNodeWithTag("action.quickRebirth").assertIsDisplayed()
        compose.onNodeWithTag("rebirth.start.3").performScrollTo().assertIsDisplayed()
        val inst = InstrumentationRegistry.getInstrumentation()
        UiDevice.getInstance(inst).takeScreenshot(File(inst.targetContext.cacheDir, "premium-rebirth.png"))
        assertEquals(before, state)
        if (ProfessionalStatusPresentation.canEnterPro(state)) compose.onNodeWithTag("action.quickRebirth").performScrollTo()
        compose.onNodeWithTag("action.quickRebirth").performClick()
        compose.waitForIdle()
        val pitcher = requireNotNull(state.highSchool).startingPitcher
        assertEquals(expected.next, listOf(pitcher.stuff, pitcher.command, pitcher.movement, pitcher.stamina))
        assertEquals(expected.nextLife, state.highSchool?.run?.lifeNumber)
        compose.onNodeWithTag("rebirth.ready").assertIsDisplayed()
        compose.onNodeWithTag("action.completeTutorial").assertIsDisplayed()
        compose.onNodeWithTag("action.openTutorialPitch").assertIsDisplayed()
        compose.onNodeWithTag("rebirth.previousSelf").assertDoesNotExist()
        UiDevice.getInstance(inst).takeScreenshot(File(inst.targetContext.cacheDir, "loop-reborn-ready.png"))
        compose.onNodeWithTag("rebirth.memories").performScrollTo().performClick()
        compose.onNodeWithTag("rebirth.previousSelf").performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag("rebirth.memories").performScrollTo().performClick()
        compose.mainClock.advanceTimeBy(600) // Respect the new-scene tap guard before starting school.
        compose.onNodeWithTag("action.completeTutorial").assertIsEnabled().performClick()
        compose.waitForIdle()
        assertEquals(Phase8ScreenId.P005_SCHOOL_SELECTION, Phase8ScreenProjection.preferredScreen(state))
        assertEquals(pitcher, state.highSchool?.run?.pitcher)
    }

}
