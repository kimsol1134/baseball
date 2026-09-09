package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.core.pro.*
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import kotlin.test.*

class Round3JourneyTest {
    @Test fun realQaSaveRecoversProfessionalStageAndReturnPlanCannotDemoteItAgain() = runBlocking {
        val directory = Files.createTempDirectory("round3-stage-")
        try {
            Files.write(directory.resolve("save.json"), javaClass.getResourceAsStream("/regression/round3-linked-pro-return-stage.json")!!.use { it.readBytes() })
            var store = KotlinGameStore.open("round3-recovery", CSharpLegacyGameStoreRepository(directory, "round3-recovery", allowDeviceRestore = true), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            try {
                assertEquals(GameStage.PRO, store.current.stage)
                assertEquals(Phase8ScreenId.P018_PRO_IMPORTANT_GAME, ReturnVisitPresentation.screen(store.current))
                assertTrue(ReturnVisitPresentation.isPro(store.current))
                val pro = store.current.pro
                val briefing = assertNotNull(OutingPresentation.briefing(store.current))
                assertEquals(pro!!.activePitch!!.context.inning, briefing.inning)
                store.dispatch(GameCommandEnvelope("old-return-plan", store.current.highSchool!!.commandReceipts.first().sessionId, store.current.revision,
                    GameCommand.HighSchool(HighSchoolPhase4Command.PrepareReturnPlan("2026-09-09", HighSchoolContentCatalog.WORLD_RULES_VERSION))))
                assertEquals(GameStage.PRO, store.current.stage)
                assertEquals(pro, store.current.pro)
                store.close()
                store = KotlinGameStore.open("round3-recovery", CSharpLegacyGameStoreRepository(directory, "round3-recovery"), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
                assertEquals(GameStage.PRO, store.current.stage)
                assertEquals(pro, store.current.pro)
            } finally { store.close() }
        } finally { directory.toFile().deleteRecursively() }
    }

    @Test fun finalAutomaticPitchRetainsResultAndScoreboardUntilAcknowledgement() = runBlocking {
        val k = ProKernel()
        val start = k.startDirect(ProStartDirectRequest("918220", "power_prospect", "QA")).state
        val ready = start.copy(phase = ProCareerPhase.IMPORTANT_GAME, fatigue = 87, week = 1,
            seasonSegment = ProCatalog.segment(1), seasonTrigger = ProSeasonTrigger.STANDINGS_RACE).let { it.copy(commitment = k.commitment(it)) }
        val base = GameAggregateState.initial("round3-last").copy(stage = GameStage.PRO, pro = ready)
        var store = KotlinGameStore.fromShadowFixture(base.copy(commitment = base.recomputeCommitment()))
        try {
            Phase8Controller(store).execute(Phase8ScreenId.P018_PRO_IMPORTANT_GAME, "openProImportantGame")
            val c = Phase7VerticalController(store)
            val result = assertNotNull(c.fastForwardCurrentBatter(finishOuting = true))
            assertEquals(PitchBoundary.TERMINAL, store.current.pitch!!.boundary)
            assertNotNull(PitchLiveResult.outcome(store.current))
            assertTrue(PitchScoreboardProjection.model(store.current).fatigue >= 87)
            assertEquals(store.current.pro!!.activePitch!!.context.inning, PitchScoreboardProjection.model(store.current).inning)
            val saved = store.current
            store.close(); store = KotlinGameStore.fromShadowFixture(saved)
            val resumed = Phase7VerticalController(store)
            assertEquals(result.pitchId, resumed.preparePresentation(store.current.pitch!!.sessionId, 0).pitchId)
            resumed.completePitchAndPostgame(store.current.pitch!!.sessionId)
            val settled = store.current
            resumed.completePitchAndPostgame(store.current.pitch!!.sessionId)
            assertEquals(settled, store.current)
        } finally { store.close() }
    }

    @Test fun everySeasonDecisionHasPresentationAndEraUsesEarnedRuns() {
        ProSeasonDecisionType.entries.forEach { assertNotNull(ProConversationPresentation.role(it), it.wire) }
        val stats = ProSeasonStats(1, "team", inningsOuts = 20, runsAllowed = 10, earnedRuns = 2)
        assertEquals("2.70", ProSeasonRecordPresentation.era(stats))
        assertTrue(ProSeasonRecordPresentation.line(stats).contains("6.2"))
        assertEquals("—", ProSeasonRecordPresentation.era(stats.copy(inningsOuts = 0)))
        assertEquals("—", ProSeasonRecordPresentation.era(stats.copy(earnedRuns = null)))
    }
}
