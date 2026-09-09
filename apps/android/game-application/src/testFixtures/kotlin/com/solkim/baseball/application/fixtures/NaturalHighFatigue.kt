package com.solkim.baseball.application.fixtures

import com.solkim.baseball.core.pro.*
import com.solkim.baseball.core.pitch.*
import com.solkim.baseball.application.KotlinGameStore
import com.solkim.baseball.application.PitchLaunch
import com.solkim.baseball.application.GameCommand
import com.solkim.baseball.application.GameCommandEnvelope
import com.solkim.baseball.application.CommandReceiptRetention
import com.solkim.baseball.application.CSharpLegacyProBridge
import com.solkim.baseball.application.PitchCareerKind
import com.solkim.baseball.application.Phase7VerticalController
import com.solkim.baseball.model.JsonValue

/** Reproduces the round-five seed journey without overwriting fatigue, phase, or pitch counters. */
public fun naturalHighFatiguePro(): ProState {
    val kernel = ProKernel()
    val seed = "7819"
    var state = kernel.startDirect(ProStartDirectRequest(seed, "power_prospect", "QA")).state
    var steps = 0
    while (steps++ < 120 && state.week < 30) {
        when (state.phase) {
            ProCareerPhase.WEEKLY_PLAN -> state = kernel.planWeek(state, seed, ProWeekPlan.DEVELOP_STUFF).state
            ProCareerPhase.SEASON_DECISION -> {
                val d = requireNotNull(state.pendingDecision)
                state = kernel.applySeasonDecision(state, seed, d.id, d.choices.first().id).state
            }
            ProCareerPhase.IMPORTANT_GAME -> {
                state = kernel.reserveImportantGame(state, seed).state
                var thrown = 0
                while (thrown++ < 150) {
                    val session = requireNotNull(state.activePitch)
                    if (session.ended) {
                        if (ProOutingUsageRules.canContinue(state)) { state = kernel.continueOuting(state).state; continue }
                        break
                    }
                    if (session.context.fatigue >= 80) return state
                    state = kernel.submitPitch(state, session.sessionId,
                        PitchCall(PitchKind.FOUR_SEAM, PitchZone(1, 1), ZoneIntent.STRIKE, PitchIntensity.MAX_EFFORT), PitchDelivery(1000, 1000)).state
                }
                state = kernel.finishImportantGame(state).state
            }
            else -> error("natural-fatigue.unexpected_phase:${state.phase}")
        }
    }
    error("natural-fatigue.not_reached")
}

/** Attach the normally generated career via native import, then finish its saved last pitch. */
public suspend fun prepareNaturalHighFatigueInput(store: KotlinGameStore, freshDirectPayload: JsonValue.Obj): PitchLaunch {
    val pro = naturalHighFatiguePro()
    val active = requireNotNull(pro.activePitch)
    val payload = JsonValue.Obj(LinkedHashMap(freshDirectPayload.entries).apply {
        put("pro", CSharpLegacyProBridge.encodeReadModel(pro, "7819", freshDirectPayload["pro"] as JsonValue.Obj))
    })
    store.importCareerBackup(portableCareerFixture(payload), store.current.revision)
    suspend fun dispatch(command: GameCommand) {
        store.dispatch(GameCommandEnvelope(CommandReceiptRetention.id(store.current.revision, "natural-fixture"), active.sessionId, store.current.revision, command))
    }
    dispatch(GameCommand.ReservePitch(active.sessionId, PitchCareerKind.PRO, pro.careerId, active.log.gameId, active.seed, false))
    dispatch(GameCommand.StartPitch(active.sessionId))
    val controller = Phase7VerticalController(store)
    val saved = controller.commitSavedPresentation(active.sessionId)
    controller.consumePresentation(active.sessionId, saved)
    controller.completePitchAndPostgame(active.sessionId)
    return requireNotNull(controller.continueOfficialPitch())
}
