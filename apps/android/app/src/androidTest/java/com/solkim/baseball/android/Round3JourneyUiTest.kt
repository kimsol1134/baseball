package com.solkim.baseball.android

import androidx.compose.runtime.*
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.solkim.baseball.application.*
import com.solkim.baseball.core.pro.ProStartLinkedRequest
import com.solkim.baseball.core.pro.ProSeasonDecision
import com.solkim.baseball.core.pro.ProSeasonDecisionType
import com.solkim.baseball.core.pro.ProDecisionChoice
import com.solkim.baseball.core.pro.ProDecisionEffect
import com.solkim.baseball.application.fixtures.*
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class Round3JourneyUiTest {
    @get:Rule val compose = createComposeRule()
    private fun base(pro: ProState): GameAggregateState = GameAggregateState.initial("round3-ui").copy(stage = GameStage.PRO, pro = pro)

    @Test fun contractCardsOnlySelectAndSigningIsExplicit() {
        val k = ProKernel()
        val pro = k.startLinked(ProStartLinkedRequest("918220", "hs-ui", "QA", ProCatalog.pitcherForPreset("power_prospect", "QA"), ProCatalog.teams.first().id, 88, draftRound = 4, overallPick = 38, signingBonus = 120_000_000)).state
        val state = base(pro)
        val model = Phase8ScreenProjection.project(state, Phase8ScreenId.P016_PRO_CONTRACT)
        val choice = model.actions.first { it.id.startsWith("acceptOffer:") }
        var calls = 0
        var language by mutableStateOf("ko")
        var scale by mutableFloatStateOf(1f)
        compose.setContent {
            val config = android.content.res.Configuration(androidx.compose.ui.platform.LocalConfiguration.current).apply { setLocale(java.util.Locale.forLanguageTag(language)); fontScale = scale }
            CompositionLocalProvider(androidx.compose.ui.platform.LocalConfiguration provides config,
                androidx.compose.ui.platform.LocalDensity provides androidx.compose.ui.unit.Density(androidx.compose.ui.platform.LocalDensity.current.density, scale)) {
                BaseballMigrationTheme { Phase8Shell(state, false, null, Phase8ScreenId.P016_PRO_CONTRACT, Phase8CommandContext(), {}, { calls++ }) }
            }
        }
        compose.onNodeWithTag("contract.offer.${choice.id.split(':')[1]}").performScrollTo().performClick()
        compose.onNodeWithTag("contract.goal.${choice.id}").performScrollTo().performClick()
        assertEquals(0, calls)
        capture("contract")
        for (locale in listOf("ko", "en", "ja")) for (font in listOf(1f, 1.5f)) {
            compose.runOnIdle { language = locale; scale = font }
            compose.onNodeWithTag("contract.confirm").performScrollTo().assertIsDisplayed()
            assertEquals(0, calls)
        }
        compose.onNodeWithTag("contract.confirm").performScrollTo().performClick()
        compose.onNodeWithTag("contract.confirm").assertIsNotEnabled()
        assertEquals(1, calls)
    }

    @Test fun slumpChoiceShowsCostBeforeExplicitCommitInEveryLanguage() {
        val k = ProKernel()
        val start = k.startDirect(ProStartDirectRequest("918220", "power_prospect", "QA")).state
        val decision = ProSeasonDecision("season-1-week-1-form_crisis", ProSeasonDecisionType.FORM_CRISIS, 1, 1, "슬럼프 갈림길", "감독: 요즘 공이 흔들린다. 남은 주, 어떻게 버틸 거냐.", listOf(
            ProDecisionChoice("form_crisis.recover", "회복 주를 택한다", "몸 상태를 회복한다", ProDecisionEffect(managerTrustDelta = -2, fatigueDelta = -16)),
            ProDecisionChoice("form_crisis.push", "밀어붙인다", "훈련을 이어간다", ProDecisionEffect(stuffDelta = 1, fatigueDelta = 8)),
            ProDecisionChoice("form_crisis.relief", "구원으로 몸을 낮춘다", "보직을 바꾼다", ProDecisionEffect(roleTarget = ProRole.LONG_RELIEF))))
        val pro = start.copy(phase = ProCareerPhase.SEASON_DECISION, week = 1, seasonSegment = ProCatalog.segment(1), fatigue = 50, pendingDecision = decision).let { it.copy(commitment = k.commitment(it)) }
        var language by mutableStateOf("ko")
        var calls = 0
        compose.setContent {
            val config = android.content.res.Configuration(androidx.compose.ui.platform.LocalConfiguration.current).apply { setLocale(java.util.Locale.forLanguageTag(language)) }
            CompositionLocalProvider(androidx.compose.ui.platform.LocalConfiguration provides config) { BaseballMigrationTheme {
                Phase8Shell(base(pro), false, null, Phase8ScreenId.P019_PRO_SEASON, Phase8CommandContext(), {}, { calls++ })
            } }
        }
        for (locale in listOf("ko", "en", "ja")) {
            compose.runOnIdle { language = locale }
            compose.onNodeWithTag("action.seasonDecision:form_crisis.recover").performScrollTo().performClick()
            compose.onAllNodes(hasText("-2", substring = true)).onFirst().assertExists()
            assertEquals(0, calls)
        }
        capture("season-choice")
        compose.onNodeWithTag("conversation.confirm").performScrollTo().performClick()
        assertEquals(1, calls)
    }

    private fun capture(name: String) {
        val context = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext
        java.io.File(context.cacheDir, "round3-$name.png").outputStream().use { out ->
            compose.onRoot().captureToImage().asAndroidBitmap().compress(android.graphics.Bitmap.CompressFormat.PNG, 100, out)
        }
    }

    @Test fun conversationReceiptHasNavigationAndNeverReappliesTheDecision() {
        val inst = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation()
        val prefs = inst.targetContext.getSharedPreferences("conversation.feedback", android.content.Context.MODE_PRIVATE)
        val previous = prefs.getString("pending", null)
        val k = ProKernel()
        val pro = k.startDirect(ProStartDirectRequest("918220", "power_prospect", "QA")).state
        val state = base(pro)
        val record = org.json.JSONObject().put("kind", "pro").put("career", pro.careerId).put("number", pro.decisionHistory.size)
            .put("speaker", ProPeoplePresentation.name(pro.team.id, "coach")).put("role", "coach")
            .put("scene", "선택이 남긴 변화").put("reaction", "conversation.reaction.done").put("choice", "회복 주를 택한다")
            .put("lines", org.json.JSONArray(listOf("피로 -16", "감독 신뢰 -2")))
        prefs.edit().putString("pending", record.toString()).commit()
        var screen by mutableStateOf(Phase8ScreenProjection.preferredScreen(state))
        var commands = 0
        try {
            compose.setContent { BaseballMigrationTheme { Phase8Shell(state, false, null, screen, Phase8CommandContext(), { screen = it }, { commands++ }) } }
            compose.onNodeWithTag("conversation.result").assertIsDisplayed()
            capture("conversation-result")
            compose.onNodeWithTag("navigation.records").performClick().assertIsSelected()
            compose.onNodeWithTag("navigation.career").performClick()
            compose.onNodeWithTag("conversation.result").assertIsDisplayed()
            androidx.test.uiautomator.UiDevice.getInstance(inst).pressBack()
            compose.waitForIdle()
            compose.onNodeWithTag("navigation.records").assertIsSelected()
            compose.onNodeWithTag("navigation.career").performClick()
            compose.onNodeWithTag("conversation.continue").performScrollTo().performClick()
            compose.onNodeWithTag("conversation.result").assertDoesNotExist()
            assertEquals(0, commands)
        } finally {
            prefs.edit().apply { if (previous == null) remove("pending") else putString("pending", previous) }.commit()
        }
    }

    @Test fun reportedDraftJourneyShowsRecordsAndDoesNotDuplicateTheStatusCard(): Unit = kotlinx.coroutines.runBlocking {
        val inst = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation()
        val dir = java.io.File(inst.targetContext.cacheDir, "round3-draft-ui").apply { mkdirs() }
        java.io.File(dir, "save.json").writeBytes(inst.context.assets.open("round3-linked-pro-return-stage.json").use { it.readBytes() })
        val store = KotlinGameStore.open("round3-draft", CSharpLegacyGameStoreRepository(dir.toPath(), "round3-draft", allowDeviceRestore = true), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try {
            val state = GameAggregateState.initial("draft-ui").copy(stage = GameStage.BETWEEN_LIVES, highSchool = store.current.highSchool)
            val record = CareerRecordPresentation.resolve(state, "hs:${state.highSchool!!.run.careerId}")!!
            compose.setContent { BaseballMigrationTheme { Phase8Shell(state, false, null, Phase8ScreenId.P015_REBIRTH, Phase8CommandContext(), {}, {}) } }
            compose.onNodeWithTag("draft.record").performScrollTo().assertTextContains("${record.innings}이닝", substring = true)
            capture("draft")
            compose.onNodeWithTag("career.storyDetails").performScrollTo().performClick()
            compose.onAllNodesWithText(state.highSchool!!.run.draftResult!!.team!!.name).assertCountEquals(1)
        } finally { store.close(); dir.deleteRecursively() }
    }

    @Test fun actualSavedProResumeShowsSituationWithoutCommittingAnything() = kotlinx.coroutines.runBlocking {
        val inst = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation()
        val dir = java.io.File(inst.targetContext.cacheDir, "round3-resume-ui").apply { mkdirs() }
        java.io.File(dir, "save.json").writeBytes(inst.context.assets.open("round3-linked-pro-return-stage.json").use { it.readBytes() })
        val store = KotlinGameStore.open("round3-ui", CSharpLegacyGameStoreRepository(dir.toPath(), "round3-ui", allowDeviceRestore = true), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try {
            val state = store.current
            var calls = 0
            compose.setContent { BaseballMigrationTheme { Phase8Shell(state, false, null, Phase8ScreenId.P018_PRO_IMPORTANT_GAME, Phase8CommandContext(), {}, { calls++ }) } }
            compose.onNodeWithTag("outing.goal").performScrollTo().assertIsDisplayed()
            compose.onNodeWithTag("outing.role").performScrollTo().assertIsDisplayed()
            assertEquals(0, calls)
            compose.onNodeWithTag("outing.opponent").assertExists()
            compose.onNodeWithTag("outing.progress").assertExists()
            assertEquals(state, store.current)
            capture("resume")
        } finally { store.close(); dir.deleteRecursively() }
    }
}
