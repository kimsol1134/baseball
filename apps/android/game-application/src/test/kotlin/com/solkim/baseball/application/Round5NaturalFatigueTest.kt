package com.solkim.baseball.application

import com.solkim.baseball.core.pro.*
import com.solkim.baseball.core.pitch.*
import kotlin.test.*

class Round5NaturalFatigueTest {
    @Test fun normalKernelJourneyCanReachHighFatigueBeforeManagerRelief() {
        val kernel = ProKernel()
        var reached = false
        var maximum = 0
        val trace = mutableListOf<String>()
        for (seed in listOf("918220", "7819", "20260909")) {
            var state = kernel.startDirect(ProStartDirectRequest(seed, "power_prospect", "QA")).state
            var steps = 0
            while (state.week < 30 && steps++ < 120 && !reached) {
                when (state.phase) {
                    ProCareerPhase.WEEKLY_PLAN -> state = kernel.planWeek(state, seed, ProWeekPlan.DEVELOP_STUFF).state
                    ProCareerPhase.SEASON_DECISION -> {
                        val decision = state.pendingDecision!!
                        state = kernel.applySeasonDecision(state, seed, decision.id, decision.choices.first().id).state
                    }
                    ProCareerPhase.IMPORTANT_GAME -> {
                        state = kernel.reserveImportantGame(state, seed).state
                        var thrown = 0
                        while (thrown++ < 150 && !reached) {
                            val session = state.activePitch!!
                            maximum = maxOf(maximum, session.context.fatigue)
                            if (session.ended) {
                                if (ProOutingUsageRules.canContinue(state)) {
                                    state = kernel.continueOuting(state).state
                                    continue
                                }
                                trace += "$seed week=${state.week} relief fatigue=${session.context.fatigue} pitches=${session.pitches}"
                                break
                            }
                            if (session.context.fatigue >= 80) {
                                reached = true
                                val pitch = PitchDurableState(session.sessionId, PitchCareerKind.PRO, state.careerId, session.sessionId, seed, PitchBoundary.PLAYING)
                                assertTrue(PitchHudProjection.canFastForward(GameAggregateState.initial("natural").copy(stage=GameStage.PRO, pro=state, pitch=pitch)))
                                trace += "$seed week=${state.week} INPUT fatigue=${session.context.fatigue} pitches=${session.pitches}"
                                break
                            }
                            state = kernel.submitPitch(state, session.sessionId,
                                PitchCall(PitchKind.FOUR_SEAM, PitchZone(1, 1), ZoneIntent.STRIKE, PitchIntensity.MAX_EFFORT), PitchDelivery(1000, 1000)).state
                        }
                        if (!reached) state = kernel.finishImportantGame(state).state
                    }
                    else -> break
                }
            }
            if (reached) break
        }
        println(trace.joinToString("\n"))
        assertTrue(reached, "No input >=80; max=$maximum; ${trace.joinToString()}")
    }
}
