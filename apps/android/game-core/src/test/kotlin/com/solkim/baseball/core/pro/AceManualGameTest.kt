package com.solkim.baseball.core.pro

import com.solkim.baseball.core.pitch.*
import kotlin.test.*

class AceManualGameTest {
    private val kernel = ProKernel()
    private fun ready(seed: String): ProState {
        val start = kernel.startDirect(ProStartDirectRequest(seed, "power_prospect", "마지막아웃")).state
        val state = start.copy(phase = ProCareerPhase.IMPORTANT_GAME, week = 1, seasonSegment = ProCatalog.segment(1),
            role = ProRole.STARTER, rolePreference = ProRole.STARTER, fatigue = 0,
            pitcher = PitcherSnapshot("ace", "마지막아웃", 80, 80, 80, 80),
            seasonTrigger = ProSeasonTrigger.OPENING_STATEMENT, currentRival = ProCatalog.rivalFor(start.team.id, 1, 1, ProSeasonTrigger.OPENING_STATEMENT), commitment = "")
        return kernel.reserveImportantGame(state.copy(commitment = kernel.commitment(state)), seed).state
    }
    private fun inning(initial: ProState): ProState {
        var state = initial
        repeat(100) {
            val p = state.activePitch!!
            if (p.ended) return state
            val prep = PitchKernel().prepare(PitchKernel.PrepareRequest(p.seed, state.pitcher, p.batter, p.scouting, p.context, p.memory, p.game, p.log))
            state = kernel.submitPitch(state, p.sessionId, prep.primaryRecommendation.call, PitchDelivery(950, 950)).state
        }
        error("inning did not finish")
    }
    @Test fun ninthInningAndCompleteGameAreRealDurableEvents() {
        var found = false
        for (seed in 1..80) {
            var state = ready((seed * 772019L).toString())
            while (true) {
                state = inning(state)
                if (!ProOutingUsageRules.canContinue(state)) break
                val before = state.activePitch!!
                state = kernel.continueOuting(state).state
                assertEquals(before.context.inning + 1, state.activePitch!!.context.inning)
                state = ProStateCodec.decode(ProStateCodec.encode(state))
            }
            val outs = state.activePitch!!.outs
            val runs = state.activePitch!!.runsAllowed
            state = kernel.finishImportantGame(state).state
            assertEquals(outs, state.currentGameLines.single().outs)
            if (state.currentGameLines.single().completeGame == true && runs == 0) {
                assertEquals(27, outs); assertEquals(1, state.currentStats.completeGames)
                assertEquals(1, state.currentStats.shutouts); assertEquals(0, state.currentGameLines.single().opponentRuns)
                assertEquals(state, ProStateCodec.decode(ProStateCodec.encode(state)))
                println("MANUAL_SHUTOUT seed=${seed * 772019L} pitches=${state.currentStats.pitches} score=${state.currentGameLines.single().teamRuns}:0")
                found = true; break
            }
        }
        assertTrue(found, "real pitches must be able to produce a complete-game shutout")
    }
    @Test fun handingOffDoesNotBorrowTheBullpensOuts() {
        val state = inning(ready("918220"))
        val actual = state.activePitch!!.outs
        val finished = kernel.finishImportantGame(state, handOff = true).state
        assertEquals(actual, finished.currentStats.inningsOuts)
        assertEquals(false, finished.currentGameLines.single().completeGame)
        assertEquals(0, finished.currentStats.shutouts)
    }
}
