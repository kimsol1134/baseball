package com.solkim.baseball.core.pitch

/** Runner responsibility is independent of the scoreboard. Zero is empty, -1 inherited,
 * 1 earned responsibility and 2 unearned responsibility; -2 is an unearned foreign runner. No fielding difficulty is an error.
 * Old sessions have no ledger: their earned runs must remain unknown. */
public data class PitchRunLedger(
    val bases: List<Int> = listOf(0, 0, 0),
    val runs: Int = 0,
    val earnedRuns: Int = 0,
    val inheritedScored: Int = 0,
    val virtualOuts: Int = 0,
) {
    init {
        require(bases.size == 3 && bases.all { it in -2..2 })
        require(virtualOuts in 0..3)
        require(runs >= 0 && earnedRuns in 0..runs && inheritedScored >= 0)
    }

    public fun advance(pitch: PitchSnapshot): PitchRunLedger {
        val next = bases.toMutableList()
        val caughtErrorRunner = pitch.stealAttempt?.let { !it.succeeded && kotlin.math.abs(next[it.fromBase - 1]) == 2 } == true
        pitch.stealAttempt?.let { steal ->
            val runner = next[steal.fromBase - 1]
            next[steal.fromBase - 1] = 0
            if (steal.succeeded) next[steal.toBase - 1] = runner
        }
        val errorRunnerDoublePlay = pitch.inningTransition.doublePlayCompleted && (next[0] == 2 || next[0] == -2)
        if (pitch.inningTransition.doublePlayCompleted) next[0] = 0
        val error = pitch.result == PlateAppearanceResult.REACHED_ON_ERROR
        val reconstructedOuts = (virtualOuts + pitch.inningTransition.outsRecorded + (if (error) 1 else 0) - (if (errorRunnerDoublePlay) 1 else 0) - (if (caughtErrorRunner) 1 else 0)).coerceAtMost(3)
        val queue = next.asReversed().filter { it != 0 }.toMutableList()
        if (pitch.result == PlateAppearanceResult.HIT || pitch.result == PlateAppearanceResult.WALK) queue += 1
        if (error) queue += 2
        require(pitch.runsScored <= queue.size) { "scoring.runner_missing" }
        val scored = queue.take(pitch.runsScored)
        val remaining = queue.drop(pitch.runsScored).iterator()
        val occupancy = listOf(pitch.runnersAfter.firstOccupied, pitch.runnersAfter.secondOccupied, pitch.runnersAfter.thirdOccupied)
        val after = MutableList(3) { 0 }
        if (!pitch.inningTransition.inningEnded) {
            for (base in 2 downTo 0) if (occupancy[base]) {
                require(remaining.hasNext()) { "scoring.runner_missing" }
                after[base] = remaining.next()
            }
            require(!remaining.hasNext()) { "scoring.runner_lost" }
        }
        return copy(bases = after, runs = runs + scored.count { it > 0 },
            earnedRuns = earnedRuns + (if (reconstructedOuts >= 3) 0 else scored.count { it == 1 }),
            virtualOuts = if (pitch.inningTransition.inningEnded) 0 else reconstructedOuts, inheritedScored = inheritedScored + scored.count { it == -1 })
    }

    public fun token(): String = (bases + listOf(runs, earnedRuns, inheritedScored, virtualOuts)).joinToString(",")

    public companion object {
        public fun entry(runners: BaserunnerStateSnapshot, outs: Int = 0): PitchRunLedger = PitchRunLedger(
            listOf(runners.firstOccupied, runners.secondOccupied, runners.thirdOccupied).map { if (it) -1 else 0 }, virtualOuts = outs)
        public fun decode(token: String): PitchRunLedger {
            val values = token.split(',').map(String::toInt)
            require(values.size in 6..7)
            return PitchRunLedger(values.take(3), values[3], values[4], values[5], values.getOrElse(6) { 0 })
        }
    }
}
