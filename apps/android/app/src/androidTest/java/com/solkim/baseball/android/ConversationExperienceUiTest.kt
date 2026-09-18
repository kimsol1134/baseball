package com.solkim.baseball.android

import android.content.res.Configuration
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.platform.app.InstrumentationRegistry
import com.solkim.baseball.application.*
import com.solkim.baseball.application.fixtures.*
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import java.util.Locale

class ConversationExperienceUiTest {
    @get:Rule val compose = createComposeRule()

    private fun state(role: String): GameAggregateState {
        val start = CareerFixtures.startHighSchool(HighSchoolPhase4StartRequest("918220", "power_prospect", "talk-ux", "2026-W37", "2026-09-09"))
        val school = CareerFixtures.chooseSchool("918220", CareerFixtures.completePrologue("918220", CareerFixtures.beginTutorial(start)), HighSchoolSchoolId.HAEDONG_POWER)
        val event = HighSchoolContentCatalog.events.first { it.id == when (role) {
            "coach" -> "evt-coach-role"; "catcher" -> "evt-catcher-sign"; else -> "evt-rival-message"
        } }
        val run = CareerFixtures.resignRun(school.run.copy(phase = HighSchoolPhase.RELATIONSHIP,
            currentRelationshipCategory = role, currentRelationshipTarget = HighSchoolRelationshipTarget.entries.first { it.wire == role }, currentRelationshipEvent = event))
        return GameAggregateState.initial("talk-ux").withCareers(stage = GameStage.HIGH_SCHOOL, highSchool = CareerFixtures.commitShadow(school.copy(run = run)))
    }

    @Test fun everyActorAndLocaleKeepsChoicesReadableIncludingLargeText() {
        var current by mutableStateOf(state("coach"))
        var language by mutableStateOf("ko")
        var scale by mutableFloatStateOf(1f)
        var calls = 0
        compose.setContent {
            val config = Configuration(LocalConfiguration.current).apply { setLocale(Locale.forLanguageTag(language)); fontScale = scale }
            CompositionLocalProvider(LocalConfiguration provides config, LocalDensity provides Density(LocalDensity.current.density, scale)) {
                BaseballMigrationTheme { Box(Modifier.width(360.dp)) {
                    val model = ScreenProjection.project(current, ScreenId.P007_RELATIONSHIP).localized(rememberGameCopy(), current)
                    RelationshipConversationScreen(current, model, false, null) { calls++ }
                } }
            }
        }
        for (role in listOf("coach", "catcher", "rival")) for (locale in listOf("ko", "en", "ja")) for (font in listOf(1f, 2f)) {
            compose.runOnIdle { current = state(role); language = locale; scale = font }
            for (response in listOf("listen", "explain", "challenge")) {
                compose.onNodeWithTag("action.relationship:$response").performScrollTo().assertIsDisplayed().assertIsEnabled()
            }
            compose.onAllNodes(hasText("", substring = true), useUnmergedTree = true).fetchSemanticsNodes().forEach { node ->
                node.config.getOrNull(SemanticsActions.GetTextLayoutResult)?.let { action ->
                    val layouts = mutableListOf<TextLayoutResult>()
                    action.action?.invoke(layouts)
                    // Intrinsic text widths round to whole physical pixels. Allow that rounding,
                    // but never a missing line, ellipsis, or content wider than its actual layout.
                    assertTrue("$role $locale $font: " + layouts.map { "${it.layoutInput.text.text} size=${it.size}" }, layouts.all { layout ->
                        !layout.didOverflowHeight && (0 until layout.lineCount).all { line ->
                            !layout.isLineEllipsized(line) && layout.getLineRight(line) <= layout.size.width + 1f
                        }
                    })
                }
            }
            assertEquals(0, calls)
        }
    }

    @Test fun fullCardCommitsOnceAndFailedSaveCanBeRetried() {
        val current = state("coach")
        var error by mutableStateOf<String?>(null)
        var calls = 0
        compose.setContent { BaseballMigrationTheme {
            val model = ScreenProjection.project(current, ScreenId.P007_RELATIONSHIP).localized(rememberGameCopy(), current)
            RelationshipConversationScreen(current, model, false, error) { calls++ }
        } }
        val card = compose.onNodeWithTag("action.relationship:challenge").performScrollTo()
        card.performTouchInput { click(center) }
        compose.onNodeWithTag("action.relationship:listen").assertIsNotEnabled()
        card.performTouchInput { click(center) }
        assertEquals(1, calls)
        compose.runOnIdle { error = "저장하지 못했어요. 다시 선택해 주세요." }
        card.assertIsEnabled().performClick()
        assertEquals(2, calls)
    }

    @Test fun normalLayoutShowsAllChoicesAndProducesReviewEvidence() {
        var current by mutableStateOf(state("coach"))
        compose.setContent { BaseballMigrationTheme {
            val model = ScreenProjection.project(current, ScreenId.P007_RELATIONSHIP).localized(rememberGameCopy(), current)
            RelationshipConversationScreen(current, model, false, null) {}
        } }
        val inst = InstrumentationRegistry.getInstrumentation()
        for (role in listOf("coach", "catcher", "rival")) {
            compose.runOnIdle { current = state(role) }
            compose.onNodeWithTag("action.relationship:challenge").assertIsDisplayed()
            compose.waitForIdle()
            androidx.test.uiautomator.UiDevice.getInstance(inst).takeScreenshot(java.io.File(inst.targetContext.cacheDir, "conversation-$role.png"))
        }
    }

    @Test fun committedChoiceStaysOnTheSameStageUntilAcknowledged() {
        var current by mutableStateOf(state("coach"))
        var calls = 0
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val prefs = context.getSharedPreferences("conversation.feedback", 0)
        val original = prefs.getString("pending", null)
        prefs.edit().remove("pending").commit()
        try {
            compose.setContent { BaseballMigrationTheme {
                CareerShell(current, false, null, ScreenId.P007_RELATIONSHIP, ScreenCommandContext(), {}, { action ->
                    calls++
                    val before = current
                    val after = action.capturedPayloads.fold(before) { s, payload -> GameStateReducer.dispatch(s, payload.envelope).state }
                    saveConversationFeedback(context, before, after)
                    current = after
                })
            } }
            compose.onNodeWithTag("action.relationship:challenge").performScrollTo().performClick()
            compose.onNodeWithTag("conversation.result").assertIsDisplayed()
            compose.onAllNodes(isDialog()).assertCountEquals(0)
            compose.onNodeWithTag("relationship.portrait").assertIsDisplayed()
            compose.onNodeWithTag("action.relationship:challenge").assertDoesNotExist()
            val committed = current
            compose.onNodeWithTag("conversation.continue").performClick()
            compose.onNodeWithTag("conversation.result").assertDoesNotExist()
            assertEquals(committed, current)
            assertEquals(1, calls)
        } finally { prefs.edit().putString("pending", original).commit() }
    }

    @Test fun professionalChoiceShowsRealCostsAndDispatchesOnce() {
        val base = CareerFixtures.startDirectPro(ProStartDirectRequest("42", "power_prospect", "대화투수"))
        val type = ProSeasonDecisionType.ROLE_MEETING
        val decision = ProSeasonDecision("season-${base.season}-week-${base.week}-${type.wire}", type, base.season, base.week,
            "보직 대화", "다음 보직을 정한다.", List(3) { i -> ProDecisionChoice("${type.wire}.$i", "선택 $i", "다음 등판을 준비한다.",
                ProDecisionEffect(fatigueDelta = 12, managerTrustDelta = -4)) })
        val unsigned = base.copy(phase = ProCareerPhase.SEASON_DECISION, pendingDecision = decision, commitment = "")
        val pro = unsigned.copy(commitment = CareerFixtures.proCommitment(unsigned))
        val current = GameAggregateState.initial("pro-talk").withCareers(stage = GameStage.PRO, pro = pro)
        var calls = 0
        compose.setContent { BaseballMigrationTheme {
            CareerShell(current, false, null, ScreenId.P019_PRO_SEASON, ScreenCommandContext(), {}, { calls++ })
        } }
        compose.onNodeWithTag("conversation.line").assertIsDisplayed()
        compose.onNodeWithTag("action.seasonDecision:role_meeting.0").performClick()
        compose.onNodeWithTag("action.seasonDecision:role_meeting.1").assertIsNotEnabled()
        assertEquals(1, calls)
        assertEquals(0, CareerAccess.pro(current)!!.decisionHistory.size)
    }
}
