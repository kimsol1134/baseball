package com.solkim.baseball.core.pro

import com.solkim.baseball.core.pitch.*

/** Finish the half-inning after a pitching change. The departing pitcher receives only runs
 * charged to runners they left, never the replacement's outs, hits, walks or new baserunners. */
internal fun settleReliefRuns(pitch: PitchKernel, game: GameStateSnapshot, ledger: PitchRunLedger, seed: String): PitchRunLedger {
    if (ledger.bases.none { it > 0 } || game.runners.occupiedCount == 0) return ledger
    var state = game
    var scoring = ledger
    var nextSeed = seed
    var turn = 1
    var context = PlateAppearanceContext("relief:outing-v2", 0UL, game.inningState?.inning ?: 1, game.inningState?.outs ?: 0, 0, 0, 1, 0, 500, 10)
    val replacement = PitcherSnapshot("relief", "구원 투수", 55, 55, 55, 55)
    repeat(240) {
        val batter = ProfessionalLineup.batter("relief-$seed", turn)
        val scouting = BatterScoutingSnapshot(PitchZone(1, 1), PitchZone(2, 0), PitchKind.FOUR_SEAM, PitchKind.SLIDER, 45)
        val prepared = pitch.prepare(PitchKernel.PrepareRequest(nextSeed, replacement, batter, scouting, context, gameState = state))
        val submitted = pitch.submit(PitchKernel.SubmitRequest(nextSeed, replacement, batter, scouting, context,
            prepared.preparationToken, prepared.primaryRecommendation.call, gameState = state))
        val snapshot = submitted.snapshot
        val before = scoring
        scoring = scoring.advance(snapshot)
        // New runners belong to the replacement. Its runs are excluded as well.
        if (snapshot.result == PlateAppearanceResult.HIT || snapshot.result == PlateAppearanceResult.WALK || snapshot.result == PlateAppearanceResult.REACHED_ON_ERROR) {
            val base = when (snapshot.outcome) { PitchOutcome.DOUBLE -> 1; PitchOutcome.TRIPLE -> 2; else -> 0 }
            scoring = if (snapshot.outcome == PitchOutcome.HOME_RUN) scoring.copy(runs = scoring.runs - 1, earnedRuns = scoring.earnedRuns - if (scoring.earnedRuns > before.earnedRuns) 1 else 0)
                else scoring.copy(bases = scoring.bases.mapIndexed { index, owner -> if (index == base && owner > 0) (if (owner == 2) -2 else -1) else owner })
        }
        // Inherited here includes the replacement's own runners; retain the original entry counter.
        scoring = scoring.copy(inheritedScored = before.inheritedScored)
        if (snapshot.inningTransition.inningEnded || scoring.bases.none { it > 0 }) return scoring
        state = submitted.gameState; nextSeed = submitted.nextSeed
        if (snapshot.ended) turn++
        context = context.copy(revision = submitted.revision, outs = state.inningState?.outs ?: context.outs,
            balls = if (snapshot.ended) 0 else snapshot.balls, strikes = if (snapshot.ended) 0 else snapshot.strikes,
            pitchNumber = if (snapshot.ended) 1 else context.pitchNumber + 1, fatigue = snapshot.fatigueAfterPitch)
    }
    error("pro.relief_settlement_limit")
}
