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
    @Test fun everyBatchPreservesTheSelectedPlanAndTarget() {
        val pro = ProKernel().startDirect(ProStartDirectRequest("918220", "power_prospect", "계획투수")).state
        val state = GameAggregateState.initial("plans").copy(stage = GameStage.PRO, pro = pro)
        val model = ScreenProjection.project(state, ScreenId.P017_PRO_WEEK)
        for (selected in model.actions.filter { it.id.startsWith("proPlan:") }) {
            val single = (selected.payloads.single().envelope.command as GameCommand.Pro).command as ProCommand.PlanWeek
            val batch = assertNotNull(ProWeekPresentation.batchAction(state, model, selected.id))
            val command = (batch.payloads.single().envelope.command as GameCommand.Pro).command as ProCommand.AdvanceSegment
            assertEquals(single.plan, command.plan)
            assertEquals(single.targetPitch, command.targetPitch)
            assertEquals(single.seed, command.seed)
            assertEquals("proAdvanceSegment", batch.id)
            assertEquals(0, state.pro!!.week)
        }
        assertNull(ProWeekPresentation.batchAction(state, model, "unknown"))
    }
    @Test fun selectedBatchExecutesOnceThroughTheNativeSaveStore() = kotlinx.coroutines.runBlocking {
        val root = java.nio.file.Files.createTempDirectory("selected-batch-native-")
        try {
            for (plan in ProWeekPlan.currentChoices) {
                val id = "batch-${plan.wire}"
                val store = KotlinGameStore.open(id, CSharpLegacyGameStoreRepository(root.resolve(plan.wire), id), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
                try {
                    val controller = ScreenController(store)
                    controller.execute(ScreenId.P016_PRO_CONTRACT, "startDirect")
                    val before = store.current
                    val model = controller.projection(ScreenId.P017_PRO_WEEK)
                    val batch = assertNotNull(ProWeekPresentation.batchAction(before, model, "proPlan:${plan.wire}"))
                    val command = (batch.payloads.single().envelope.command as GameCommand.Pro).command as ProCommand.AdvanceSegment
                    val expected = ProKernel().advanceSegment(before.pro!!, command.seed, command.plan, command.targetPitch, command.maximumWeeks).state
                    assertEquals(before, store.current)
                    controller.execute(model.id, batch.id, batch.payloads)
                    assertEquals(expected.pitcher, store.current.pro!!.pitcher)
                    assertEquals(expected.developmentProgress, store.current.pro!!.developmentProgress)
                    assertEquals(expected.currentStats, store.current.pro!!.currentStats)
                    assertEquals(expected.week, store.current.pro!!.week)
                    val saved = store.current
                    assertFailsWith<GameCommandException> { store.dispatchBatch(batch.payloads.map { it.envelope }) }
                    assertEquals(saved, store.current)
                } finally { store.close() }
            }
        } finally { java.nio.file.Files.walk(root).use { it.sorted(Comparator.reverseOrder()).forEach(java.nio.file.Files::deleteIfExists) } }
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
