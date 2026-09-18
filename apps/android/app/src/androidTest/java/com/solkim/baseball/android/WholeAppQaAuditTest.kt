package com.solkim.baseball.android

import com.solkim.baseball.application.fixtures.*
import com.solkim.baseball.application.*

import androidx.compose.runtime.*
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import com.solkim.baseball.design.BaseballMigrationTheme
import java.io.File
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

/** Read-only visual audit: all career fixtures live in memory; never touches the player's store. */
class WholeAppQaAuditTest {
    @get:Rule val compose = createComposeRule()
    private fun school(): HighSchoolPhase4State {
        val s = CareerFixtures.startHighSchool(HighSchoolPhase4StartRequest("918220", "power_prospect", "whole-audit", "2026-W37", "2026-09-08"))
        return CareerFixtures.chooseSchool("918220", CareerFixtures.completePrologue("918220", CareerFixtures.beginTutorial(s)), HighSchoolSchoolId.HAEDONG_POWER)
    }
    private fun aggregate(hs: HighSchoolPhase4State): GameAggregateState = GameAggregateState.initial("whole-audit").withCareers(stage = GameStage.HIGH_SCHOOL, highSchool = hs).committed()
    private fun proAggregate(pro: ProState): GameAggregateState = GameAggregateState.initial("whole-audit-pro").withCareers(stage = GameStage.PRO, pro = pro).committed()
    private fun capture(name: String) {
        compose.waitForIdle()
        android.os.SystemClock.sleep(450)
        val inst = InstrumentationRegistry.getInstrumentation()
        val device = UiDevice.getInstance(inst)
        device.takeScreenshot(File(inst.targetContext.cacheDir, "whole-audit-$name.png"))
        device.dumpWindowHierarchy(File(inst.targetContext.cacheDir, "whole-audit-$name.xml"))
    }
    @Test fun inspectSchoolAndProfessionalSurfacesWithActualCorePreviews() {
        val base = school()
        val coach = CareerFixtures.resignRun(base.run.copy(phase = HighSchoolPhase.RELATIONSHIP,
            milestoneIndex = base.run.schedule.milestonesByChapter[0].indexOf(HighSchoolPhase.RELATIONSHIP).coerceAtLeast(0),
            currentRelationshipCategory = "coach", currentRelationshipTarget = HighSchoolRelationshipTarget.COACH,
            currentRelationshipEvent = HighSchoolContentCatalog.events.first { it.id == "evt-coach-role" }))
        val scenario = HighSchoolContentCatalog.scenarios.first()
        val trial = CareerFixtures.resignRun(base.run.copy(phase = HighSchoolPhase.IMPORTANT_GAME,
            currentGameScenario = scenario, currentGameScenarioId = scenario.id, development = HighSchoolDevelopment(starterTrialPending = true)))
        val pro = CareerFixtures.startDirectPro(ProStartDirectRequest("918220", "power_prospect", "검증투수"))
        val trained = CareerFixtures.planWeek(pro, "99881", ProWeekPlan.DEVELOP_STUFF)
        val closer = pro.copy(phase = ProCareerPhase.IMPORTANT_GAME, week = 1, seasonSegment = CareerFixtures.proSegment(1),
            role = ProRole.CLOSER, seasonTrigger = ProSeasonTrigger.OPENING_STATEMENT).let { it.copy(commitment = CareerFixtures.proCommitment(it)) }
        val cases = listOf(
            Triple("training", ScreenId.P006_TRAINING, aggregate(base)),
            Triple("coach", ScreenId.P007_RELATIONSHIP, aggregate(CareerFixtures.commitShadow(base.copy(run = coach)))),
            Triple("trial-entry", ScreenId.P008_IMPORTANT_GAME, aggregate(CareerFixtures.commitShadow(base.copy(run = trial)))),
            Triple("pro-week", ScreenId.P017_PRO_WEEK, proAggregate(pro)),
            Triple("closer-entry", ScreenId.P018_PRO_IMPORTANT_GAME, proAggregate(closer)),
            Triple("pro-records", ScreenId.P025_RECORDS_LEAGUE, proAggregate(pro)),
            Triple("pro-games", ScreenId.P011_HIGH_SCHOOL_CAREER, proAggregate(trained)),
            Triple("settings", ScreenId.P027_SETTINGS, aggregate(base)),
        )
        var selected by mutableIntStateOf(0)
        var language by mutableStateOf("ko")
        compose.setContent { BaseballMigrationTheme {
            val (_, screen, state) = cases[selected]
            val config = android.content.res.Configuration(androidx.compose.ui.platform.LocalConfiguration.current)
                .apply { setLocale(java.util.Locale.forLanguageTag(language)) }
            CompositionLocalProvider(androidx.compose.ui.platform.LocalConfiguration provides config) {
                key(selected, language) { CareerShell(state, false, null, screen, ScreenCommandContext(), onNavigate = {}, onAction = {}) }
            }
        } }
        cases.forEachIndexed { index, (name, screen, state) ->
            assertTrue("Audit screen must actually be reachable: $name", ScreenProjection.isReachable(state, screen))
            compose.runOnIdle { selected = index }
            capture(name)
        }
        for (locale in listOf("en", "ja")) for (index in listOf(1, 2, 3)) {
            compose.runOnIdle { language = locale; selected = index }
            capture("$locale-${cases[index].first}")
        }
        val reserved = CareerFixtures.reserveProGame(closer, "55123").activePitch!!
        val before = proAggregate(pro)
        val after = proAggregate(trained)
        val data = JSONObject()
            .put("proTraining", JSONObject().put("stuffBefore", pro.pitcher.stuff).put("stuffAfter", trained.pitcher.stuff)
                .put("fatigueBefore", pro.fatigue).put("fatigueAfter", trained.fatigue)
                .put("progressBefore", pro.developmentProgress.stuff).put("progressAfter", trained.developmentProgress.stuff)
                .put("gamesBefore", pro.currentStats.games).put("gamesAfter", trained.currentStats.games)
                .put("trainingReceiptExists", trainingFeedbackRecord(before, after) != null)
                .put("conversationReceiptExists", conversationFeedbackRecord(before, after) != null))
            .put("closer", JSONObject().put("headline", CareerFixtures.importantHeadline(closer.seasonTrigger!!, closer.currentRival, closer.level))
                .put("entryInning", reserved.context.inning).put("role", reserved.assignment!!.role.name)
                .put("lead", reserved.context.scoreDifferential).put("goal", OutingPresentation.goal(reserved.assignment!!)))
        File(InstrumentationRegistry.getInstrumentation().targetContext.cacheDir, "whole-audit-facts.json").writeText(data.toString(2))
    }
}
