package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import kotlin.test.*

class Round2ProgressIntegrityTest {
    private suspend fun recovered(action: suspend (KotlinGameStore, java.nio.file.Path) -> Unit) {
        val directory = Files.createTempDirectory("round2-progress-")
        try {
            Files.write(directory.resolve("save.json"), requireNotNull(javaClass.getResourceAsStream("/regression/high-school-terminal-v42.json")).use { it.readBytes() })
            val store = KotlinGameStore.open("round2", CSharpLegacyGameStoreRepository(directory, "round2", allowDeviceRestore = true), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            try {
                val c = Phase7VerticalController(store)
                val id = store.current.pitch!!.sessionId
                c.consumePresentation(id, c.preparePresentation(id, 0))
                c.completePitchAndPostgame(id)
                assertNotNull(c.continueOfficialPitch())
                action(store, directory)
            } finally { store.close() }
        } finally { directory.toFile().deleteRecursively() }
    }

    @Test fun repeatedAbandonAndNativeRestartPreserveOpponentRngAndEveryRecord() = runBlocking {
        recovered { original, directory ->
            var store = original
            val highSchool = store.current.highSchool
            val meta = store.current.meta
            try {
                repeat(3) {
                    val c = Phase7VerticalController(store)
                    c.abandonPitch(store.current.pitch!!.sessionId)
                    store.close()
                    store = KotlinGameStore.open("round2", CSharpLegacyGameStoreRepository(directory, "round2"), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
                    assertEquals(PitchBoundary.ABANDONED, store.current.pitch!!.boundary)
                    assertNotNull(Phase7VerticalController(store).continueOfficialPitch())
                    assertEquals(highSchool, store.current.highSchool)
                    assertEquals(meta.completedGameCount, store.current.meta.completedGameCount)
                }
            } finally { store.close() }
        }
    }

    @Test fun oneAtBatSimulationDoesNotSilentlySimulateAnotherBatter() = runBlocking {
        recovered { store, _ ->
            val before = store.current.highSchool!!.activePitch!!
            val batterNumber = before.context.plateAppearanceId.substringAfterLast(":batter:").toIntOrNull() ?: 1
            assertNotNull(Phase7VerticalController(store).fastForwardCurrentBatter())
            val after = store.current.highSchool?.activePitch
            if (after != null && !after.ended) {
                assertEquals(batterNumber + 1, after.context.plateAppearanceId.substringAfterLast(":batter:").toInt())
                assertEquals(0, after.context.balls)
                assertEquals(0, after.context.strikes)
                assertEquals(PitchBoundary.COMPLETED, store.current.pitch!!.boundary)
            }
            assertFalse(store.current.settings.autoReleaseEnabled)
        }
    }

    @Test fun proAbandonPreservesTheBatterAndExhaustedAutoOutingSettlesOnce() = runBlocking {
        val kernel = com.solkim.baseball.core.pro.ProKernel()
        val start = kernel.startDirect(com.solkim.baseball.core.pro.ProStartDirectRequest("918220", "power_prospect", "QA")).state
        val ready = start.copy(phase = com.solkim.baseball.core.pro.ProCareerPhase.IMPORTANT_GAME, fatigue = 87,
            week = 1, seasonSegment = com.solkim.baseball.core.pro.ProCatalog.segment(1), seasonTrigger = com.solkim.baseball.core.pro.ProSeasonTrigger.STANDINGS_RACE)
            .let { it.copy(commitment = kernel.commitment(it)) }
        val base = GameAggregateState.initial("round2-pro").copy(stage = GameStage.PRO, pro = ready)
        var store = KotlinGameStore.fromShadowFixture(base.copy(commitment = base.recomputeCommitment()))
        try {
            Phase8Controller(store).execute(Phase8ScreenId.P018_PRO_IMPORTANT_GAME, "openProImportantGame")
            val before = store.current.pro
            repeat(3) {
                Phase7VerticalController(store).abandonPitch(store.current.pitch!!.sessionId)
                val saved = store.current
                store.close()
                store = KotlinGameStore.fromShadowFixture(saved)
                assertNotNull(Phase7VerticalController(store).continueOfficialPitch())
                assertEquals(before, store.current.pro)
            }
            assertNotNull(Phase7VerticalController(store).fastForwardCurrentBatter(finishOuting = true))
            assertTrue(store.current.pro?.activePitch == null || store.current.pro!!.activePitch!!.ended)
            val settled = store.current
            Phase7VerticalController(store).fastForwardCurrentBatter(finishOuting = true)
            assertEquals(settled, store.current)
            assertFalse(store.current.settings.autoReleaseEnabled)
        } finally { store.close() }
    }

    @Test fun exhaustedOutingHasExplicitAutomaticExitWithoutChangingSliderDefault() = runBlocking {
        recovered { original, _ ->
            val kernel = HighSchoolPhase4Kernel()
            val source = original.current.highSchool!!
            for (fatigue in listOf(80, 87, 95)) {
                val run = com.solkim.baseball.core.highschool.HighSchoolKernel().resignShadowState(source.run.copy(fatigue = fatigue))
                val hs = kernel.commitShadowState(source.copy(run = run, activePitch = null, lastPresentation = null))
                val base = GameAggregateState.initial("round2-fatigue-$fatigue").copy(stage = GameStage.HIGH_SCHOOL, highSchool = hs, meta = GameMetaState(activeHighSchoolCareerId = hs.run.careerId))
                val state = base.copy(commitment = base.recomputeCommitment())
                val store = KotlinGameStore.fromShadowFixture(state)
                try {
                    val c = Phase7VerticalController(store)
                    c.reserveImportantGame()
                    assertTrue(PitchHudProjection.canFastForward(store.current))
                    assertNotNull(c.fastForwardCurrentBatter(finishOuting = true))
                    assertTrue(store.current.highSchool?.activePitch == null || store.current.highSchool!!.activePitch!!.ended)
                    assertFalse(store.current.settings.autoReleaseEnabled)
                    assertTrue(store.current.highSchool!!.seasonLog.size >= source.seasonLog.size)
                    val settled = store.current
                    c.fastForwardCurrentBatter(finishOuting = true)
                    assertEquals(settled, store.current)
                } finally { store.close() }
            }
        }
    }
}
