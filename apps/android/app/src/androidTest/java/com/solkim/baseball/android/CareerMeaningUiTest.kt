package com.solkim.baseball.android

import androidx.compose.runtime.*
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.platform.app.InstrumentationRegistry
import com.solkim.baseball.application.*
import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

/** Uses independent fixtures and restores the single pending UI receipt. */
class CareerMeaningUiTest {
    @get:Rule val compose = createComposeRule()
    private fun capture(name: String) {
        compose.waitForIdle()
        android.os.SystemClock.sleep(400) // Let native dialog window transitions finish before screenshots.
        val inst = InstrumentationRegistry.getInstrumentation()
        androidx.test.uiautomator.UiDevice.getInstance(inst).takeScreenshot(java.io.File(inst.targetContext.cacheDir, "meaning-$name.png"))
    }
    private fun school(): HighSchoolPhase4State {
        val k = HighSchoolPhase4Kernel()
        val start = k.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "meaning-ui", "2026-W37", "2026-09-08")).state
        return k.chooseSchool("918220", k.completePrologue("918220", k.beginTutorial(start).state).state, HighSchoolSchoolId.HAEDONG_POWER).state
    }
    @Test fun conversationResultPersistsUntilAcknowledgedWithoutReplayingTheChoice() {
        val core = HighSchoolKernel()
        val school = school()
        val event = HighSchoolContentCatalog.events.first { it.id == "evt-coach-role" }
        val run = core.resignShadowState(school.run.copy(phase = HighSchoolPhase.RELATIONSHIP,
            currentRelationshipCategory = "coach", currentRelationshipTarget = HighSchoolRelationshipTarget.COACH, currentRelationshipEvent = event))
        val next = core.resolveRelationship(HighSchoolKernel.RelationshipRequest("99881", run, HighSchoolRelationshipResponse.CHALLENGE)).snapshot
        val before = GameAggregateState.initial("meaning-ui").copy(stage = GameStage.HIGH_SCHOOL, highSchool = school.copy(run = run))
        val after = before.copy(highSchool = school.copy(run = next))
        val record = requireNotNull(conversationFeedbackRecord(before, after))
        assertEquals("다음 등판: 선발 테스트", record.getJSONArray("lines").getString(0))
        assertNull(conversationFeedbackRecord(after, after))
        val prefs = InstrumentationRegistry.getInstrumentation().targetContext.getSharedPreferences("conversation.feedback", 0)
        val saved = prefs.getString("pending", null)
        try {
            prefs.edit().putString("pending", record.toString()).commit()
            var mount by mutableIntStateOf(0)
            compose.setContent { BaseballMigrationTheme { androidx.compose.material3.Surface(color = com.solkim.baseball.design.BaseballColors.canvas) { key(mount) { ConversationFeedbackGate(after) } } } }
            compose.onNodeWithTag("conversation.result").assertIsDisplayed()
            compose.mainClock.advanceTimeBy(15_000)
            compose.onNodeWithTag("conversation.result").assertIsDisplayed()
            compose.runOnIdle { mount++ }
            compose.onNodeWithTag("conversation.result").assertIsDisplayed()
            capture("conversation")
            compose.onNodeWithTag("conversation.continue").performClick()
            compose.onNodeWithTag("conversation.result").assertDoesNotExist()
            assertNull(prefs.getString("pending", null))
            assertTrue(after.highSchool!!.run.development!!.starterTrialPending)
            assertEquals(run.relationshipsCompleted + 1, after.highSchool!!.run.relationshipsCompleted)
        } finally { prefs.edit().putString("pending", saved).commit() }
    }
    @Test fun draftedPlayerSeesContractAsPrimaryAndNoSeparateNewProShortcut() {
        val school = school()
        val team = HighSchoolDraftTeamRules.bestTeam(school.run.pitcher)
        val run = HighSchoolKernel().resignShadowState(school.run.copy(phase = HighSchoolPhase.COMPLETED,
            draftResult = HighSchoolDraftResult(com.solkim.baseball.core.highschool.HighSchoolDraftOutcome.DRAFTED, 72, "4라운드", team.id, team, 4, 32, 120000000)))
        val hs = HighSchoolPhase4Kernel().commitShadowState(school.copy(run = run))
        val state = GameAggregateState.initial("meaning-ui").copy(stage = GameStage.HIGH_SCHOOL, highSchool = hs)
        compose.setContent { BaseballMigrationTheme {
            Phase8Shell(state, false, null, Phase8ScreenId.P015_REBIRTH, Phase8CommandContext(), onNavigate = {}, onAction = {})
        } }
        compose.onNodeWithText("지명 완료 · 입단 계약 전").assertIsDisplayed()
        compose.onNodeWithTag("action.startLinked").assertIsDisplayed().assertIsEnabled()
        compose.onNodeWithTag("action.startDirect").assertDoesNotExist()
        compose.onNodeWithText("다음 생").assertDoesNotExist()
        compose.onNodeWithTag("rebirth.startComparison").assertDoesNotExist()
        capture("draft")
    }
    @Test fun separateProCareerRequiresNameAndExplicitStart() {
        var state by mutableStateOf(GameAggregateState.initial("meaning-new-pro"))
        var commits = 0
        compose.setContent { BaseballMigrationTheme {
            Phase8Shell(state, false, null, Phase8ScreenId.P001_OPENING, Phase8CommandContext(), onNavigate = {}, onAction = { action ->
                commits++
                action.capturedPayloads.forEach { state = GameStateReducer.dispatch(state, it.envelope).state }
            })
        } }
        compose.onNodeWithTag("opening.proMode").performClick()
        compose.onNodeWithTag("opening.startPro").assertIsNotEnabled()
        assertNull(state.pro)
        compose.onNodeWithTag("opening.proName").performTextInput("테스트선수")
        assertEquals(0, commits)
        capture("new-pro")
        compose.onNodeWithTag("opening.startPro").assertIsEnabled().performClick()
        assertEquals(1, commits)
        assertEquals("테스트선수", state.pro!!.identityName)
        assertNull(state.highSchool)
    }
}
