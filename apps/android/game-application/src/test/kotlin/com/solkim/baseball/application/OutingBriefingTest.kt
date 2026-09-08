package com.solkim.baseball.application

import com.solkim.baseball.core.pro.*
import kotlin.test.*

class OutingBriefingTest {
    @Test fun everyRoleSeesExactlyTheSituationThatWillBeReserved() {
        val k = ProKernel()
        val base = k.startDirect(ProStartDirectRequest("918220", "power_prospect", "상황투수")).state
        for (role in ProRole.entries) for (trigger in listOf(ProSeasonTrigger.OPENING_STATEMENT, ProSeasonTrigger.MAJOR_DEBUT, ProSeasonTrigger.STANDINGS_RACE)) {
            val pro = base.copy(phase = ProCareerPhase.IMPORTANT_GAME, week = 1, role = role, seasonSegment = ProCatalog.segment(1), seasonTrigger = trigger)
                .let { it.copy(commitment = k.commitment(it)) }
            val state = GameAggregateState.initial("briefing").copy(stage = GameStage.PRO, pro = pro)
            val context = Phase8CommandContext()
            val before = ProStateCodec.encode(pro)
            val preview = assertNotNull(OutingPresentation.briefing(state, context))
            val reserved = k.reserveImportantGame(pro, context.seed(state, "pro-important-game")).state
            val actual = state.copy(pro = reserved)
            assertEquals(OutingPresentation.title(actual), preview.title)
            assertTrue(preview.situation.startsWith("${reserved.activePitch!!.context.inning}회"))
            assertEquals(OutingPresentation.goal(reserved.activePitch!!.assignment!!), preview.goal)
            assertFalse(preview.story.contains("선발 맞대결"))
            assertContentEquals(before, ProStateCodec.encode(pro))
        }
    }
}
