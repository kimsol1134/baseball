package com.solkim.baseball.core.pitch

import kotlin.test.*

class PitchRunLedgerTest {
    private fun play(outcome: PitchOutcome, result: PlateAppearanceResult, after: BaserunnerStateSnapshot, runs: Int): PitchSnapshot {
        val kernel = PitchKernel()
        val request = PitchKernel.PrepareRequest("918220", PitcherSnapshot("p", "투수", 50, 50, 50, 50),
            BatterSnapshot("b", "타자", 50, 50, 50), BatterScoutingSnapshot(PitchZone(1, 1), PitchZone(2, 0), PitchKind.FOUR_SEAM, PitchKind.SLIDER, 48),
            PlateAppearanceContext("pa", 0UL, 1, 0, 0, 0, 1, 0, 500, 0))
        val prepared = kernel.prepare(request)
        val snapshot = kernel.submit(PitchKernel.SubmitRequest(request.seed, request.pitcher, request.batter, request.scouting,
            request.context, prepared.preparationToken, prepared.primaryRecommendation.call)).snapshot
        return snapshot.copy(outcome = outcome, result = result, runnersAfter = after, runsScored = runs, stealAttempt = null,
            inningTransition = InningTransitionSnapshot(InningStateSnapshot(1, HalfInning.TOP, 0), InningStateSnapshot(1, HalfInning.TOP, 0), 0, false, false, ""))
    }
    @Test fun inheritedRunnerScoresBeforeOwnedRunnerWithoutChargingReliever() {
        val entry = PitchRunLedger.entry(BaserunnerStateSnapshot(false, true, false, 50))
        val single = entry.advance(play(PitchOutcome.SINGLE, PlateAppearanceResult.HIT, BaserunnerStateSnapshot(true, false, false, 50), 1))
        assertEquals(1, single.inheritedScored); assertEquals(0, single.runs)
        val homer = single.advance(play(PitchOutcome.HOME_RUN, PlateAppearanceResult.HIT, BaserunnerStateSnapshot.EMPTY, 2))
        assertEquals(2, homer.runs); assertEquals(2, homer.earnedRuns); assertEquals(1, homer.inheritedScored)
        assertEquals(homer, PitchRunLedger.decode(homer.token()))
    }
    @Test fun walkAndUnearnedRunnerRetainResponsibility() {
        val loaded = PitchRunLedger(listOf(1, 2, -1))
        val walk = loaded.advance(play(PitchOutcome.BALL, PlateAppearanceResult.WALK, BaserunnerStateSnapshot(true, true, true, 50), 1))
        assertEquals(listOf(1, 1, 2), walk.bases)
        assertEquals(1, walk.inheritedScored)
        val homer = walk.advance(play(PitchOutcome.HOME_RUN, PlateAppearanceResult.HIT, BaserunnerStateSnapshot.EMPTY, 4))
        assertEquals(4, homer.runs); assertEquals(3, homer.earnedRuns)
    }
    @Test fun caughtStealingByAnErrorRunnerIsNotAnExtraCounterfactualOut() {
        val attempt = play(PitchOutcome.BALL, PlateAppearanceResult.WALK, BaserunnerStateSnapshot.EMPTY, 0).let {
            it.copy(result = null, stealAttempt = StealAttemptSnapshot(1, 2, 50, 50, false, ""),
                inningTransition = it.inningTransition.copy(outsRecorded = 1))
        }
        val result = PitchRunLedger(listOf(2, 0, 0), virtualOuts = 1).advance(attempt)
        assertEquals(1, result.virtualOuts)
        assertEquals(listOf(0, 0, 0), result.bases)
    }
    @Test fun twoOutErrorMakesTheFollowingHomeRunUnearned() {
        val error = play(PitchOutcome.REACHED_ON_ERROR, PlateAppearanceResult.REACHED_ON_ERROR, BaserunnerStateSnapshot(true, false, false, 50), 0)
        val afterError = PitchRunLedger(virtualOuts = 2).advance(error)
        assertEquals(listOf(2, 0, 0), afterError.bases)
        val homer = afterError.advance(play(PitchOutcome.HOME_RUN, PlateAppearanceResult.HIT, BaserunnerStateSnapshot.EMPTY, 2))
        assertEquals(2, homer.runs); assertEquals(0, homer.earnedRuns)
        assertEquals(homer, PitchRunLedger.decode(homer.token()))
    }
    @Test fun doublePlayRemovesFirstRunnerAndThirdOutStrandsOthers() {
        val ordinary = play(PitchOutcome.IN_PLAY_OUT, PlateAppearanceResult.IN_PLAY_OUT, BaserunnerStateSnapshot(false, true, true, 50), 0)
        val dp = PitchRunLedger(listOf(1, -1, 2)).advance(ordinary.copy(inningTransition = ordinary.inningTransition.copy(doublePlayCompleted = true, outsRecorded = 2)))
        assertEquals(listOf(0, -1, 2), dp.bases)
        val ended = dp.advance(ordinary.copy(runnersAfter = BaserunnerStateSnapshot.EMPTY, inningTransition = ordinary.inningTransition.copy(inningEnded = true)))
        assertEquals(listOf(0, 0, 0), ended.bases); assertEquals(0, ended.runs)
    }
}
