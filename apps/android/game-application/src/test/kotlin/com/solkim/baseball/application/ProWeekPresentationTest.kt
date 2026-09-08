package com.solkim.baseball.application

import com.solkim.baseball.core.pro.*
import kotlin.test.*

class ProWeekPresentationTest {
    @Test fun previewDoesNotAdvanceAndBoundsActualFatigueForEveryRoleAndPlan() {
        val k = ProKernel()
        val base = k.startDirect(ProStartDirectRequest("918220", "power_prospect", "주간투수")).state
        for (role in ProRole.entries) for (plan in ProWeekPlan.currentChoices) for (seed in listOf("1", "99881", "991")) {
            val pro = base.copy(role = role).let { it.copy(commitment = k.commitment(it)) }
            val before = ProStateCodec.encode(pro)
            val forecast = proWeekForecast(pro, plan)
            assertContentEquals(before, ProStateCodec.encode(pro))
            val next = k.planWeek(pro, seed, plan).state
            assertEquals(forecast.outings, next.currentStats.games)
            assertTrue(next.fatigue in forecast.fatigueMinimum..forecast.fatigueMaximum)
        }
    }
    @Test fun zeroRatingGrowthStillProducesAResultWithRealProgressAndGames() {
        val k = ProKernel()
        val pro = k.startDirect(ProStartDirectRequest("918220", "power_prospect", "주간투수")).state
        val next = k.planWeek(pro, "99881", ProWeekPlan.DEVELOP_STUFF).state
        val state = GameAggregateState.initial("week").copy(stage = GameStage.PRO, pro = pro)
        val result = assertNotNull(ProWeekPresentation.result(state, state.copy(pro = next)))
        assertEquals(pro.pitcher.stuff, next.pitcher.stuff)
        assertTrue(result.growth.single().contains("1/2"))
        assertEquals(next.currentStats.games, result.games)
        assertNull(ProWeekPresentation.result(state.copy(pro = next), state.copy(pro = next)))
    }
}
