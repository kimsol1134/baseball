package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.SplitMix64
import com.solkim.baseball.core.pitch.BatSide
import com.solkim.baseball.core.pitch.BatterScoutingSnapshot
import com.solkim.baseball.core.pitch.BatterSnapshot
import com.solkim.baseball.core.pitch.BaserunnerStateSnapshot
import com.solkim.baseball.core.pitch.GameLogSnapshot
import com.solkim.baseball.core.pitch.GameStateSnapshot
import com.solkim.baseball.core.pitch.HalfInning
import com.solkim.baseball.core.pitch.InningStateSnapshot
import com.solkim.baseball.core.pitch.PitchAnalysisEntry
import com.solkim.baseball.core.pitch.PitchKernel
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchZone
import com.solkim.baseball.core.pitch.PlateAppearanceContext
import com.solkim.baseball.core.pitch.PlateAppearanceResult
import com.solkim.baseball.core.pitch.RivalMemorySnapshot
import com.solkim.baseball.core.pitch.PitchKernelResult
import com.solkim.baseball.core.pitch.PitchOutcome
import kotlin.math.max

/**
 * Swift AutoOutingSimulator's Kotlin boundary for chapter games.
 *
 * Automatic games are still Core Meta state, but their pitch outcomes must come from the same
 * PitchKernel used by the interactive important-game path. This class owns no durable state and
 * returns only the aggregate needed by the chapter ledger/draft evaluation.
 */
internal class HighSchoolAutomaticOutingSimulator(
    private val pitch: PitchKernel = PitchKernel(),
) {
    internal data class Line(
        val outs: Int,
        val strikeouts: Int,
        val walks: Int,
        val runsAllowed: Int,
        val pitches: Int,
        val hits: Int,
    )

    internal fun simulate(
        state: HighSchoolState,
        chapter: HighSchoolChapter,
        seed: ULong,
    ): List<Line> {
        var rng = SplitMix64(seed xor 0x485347414D45UL) // HSGAME
        val offset = (if (chapter.theme.contains("대회")) 0 else -6) + difficultyScale(chapter.number, state.lifeNumber)
        return (0 until 2).map { index ->
            val baseSeed = rng.next()
            val line = simulateOuting(
                state = state,
                startingFatigue = state.fatigue + index * 6,
                outsTarget = 18,
                pitchCap = 90,
                batterOffset = offset,
                baseSeed = baseSeed,
            )
            // Swift HighSchoolCareer.simulateChapterGames advances the chapter RNG after
            // every outing for team support and the rest-of-team run line. The aggregate
            // Kotlin ledger does not currently retain those two values, but the draws are
            // part of the authoritative RNG stream and must still be consumed before the
            // next outing's base seed is selected.
            consumeHighSchoolTeamRunDraws(rng)
            line
        }
    }

    private fun simulateOuting(
        state: HighSchoolState,
        startingFatigue: Int,
        outsTarget: Int,
        pitchCap: Int,
        batterOffset: Int,
        baseSeed: ULong,
    ): Line {
        var rng = SplitMix64(baseSeed)
        val pitcher = state.toPitcherSnapshot()
        var lineOuts = 0
        var strikeouts = 0
        var walks = 0
        var runsAllowed = 0
        var pitches = 0
        var hits = 0
        val extensionOuts = if (outsTarget >= 18) starterExtensionOuts(pitcher) else 0
        val effectiveOutsTarget = outsTarget + extensionOuts
        val effectivePitchCap = pitchCap + extensionOuts * 4
        val fielders = listOf(
            "pitcher", "catcher", "first_base", "second_base", "third_base", "shortstop",
            "left_field", "center_field", "right_field",
        ).map { position ->
            com.solkim.baseball.core.pitch.FielderSnapshot("week-$position", position, position, 50, 50, 50)
        }
        var inning = InningStateSnapshot(1, HalfInning.TOP, 0)
        var runners = BaserunnerStateSnapshot(false, false, false, 52)
        var runsOnBoard = 0
        var currentFatigue = startingFatigue.coerceIn(0, 95)
        var benchMemory: RivalMemorySnapshot? = null
        var plateAppearanceIndex = 0
        var carriedLog = GameLogSnapshot("week-outing", 0UL, 0, emptyList())

        while (lineOuts < effectiveOutsTarget && pitches < effectivePitchCap && plateAppearanceIndex < 60) {
            plateAppearanceIndex += 1
            val batter = BatterSnapshot(
                id = "week-batter-$plateAppearanceIndex",
                name = "상대 타선",
                contact = (50 + batterOffset + rng.nextInt(9) - 4).coerceIn(20, 80),
                discipline = (50 + batterOffset + rng.nextInt(7) - 3).coerceIn(20, 80),
                power = (50 + batterOffset + rng.nextInt(9) - 4).coerceIn(20, 80),
                batSide = if (rng.nextInt(100) < 32) BatSide.LEFT else BatSide.RIGHT,
            )
            val hotZone = PitchZone(rng.nextInt(3), rng.nextInt(3))
            val coldZone = if (hotZone == PitchZone(1, 1)) PitchZone(2, 0)
            else PitchZone(2 - hotZone.row, 2 - hotZone.column)
            val scouting = BatterScoutingSnapshot(
                hotZone = hotZone,
                coldZone = coldZone,
                pitchStrength = PitchKind.FOUR_SEAM,
                pitchWeakness = if (rng.nextInt(2) == 0) PitchKind.SLIDER else PitchKind.CHANGEUP,
                chaseTendency = (48 + rng.nextInt(9) - 4).coerceIn(20, 80),
            )
            var gameState = GameStateSnapshot(
                defense = com.solkim.baseball.core.pitch.DefenseSnapshot(50, 50, 50, fielders),
                park = com.solkim.baseball.core.pitch.ParkSnapshot("league-week-park", "리그 구장", 1_000, 1_000),
                runners = runners,
                runsAllowed = runsOnBoard,
                inningState = inning,
            )
            if (benchMemory == null) {
                benchMemory = RivalMemorySnapshot("${pitcher.id}:bench:outing", 0UL, 0, 0, emptyList())
            }
            var memory = benchMemory
            val outsBefore = (inning.inning - 1) * 3 + inning.outs
            var context = PlateAppearanceContext(
                plateAppearanceId = "week-pa-$plateAppearanceIndex",
                revision = 0UL,
                inning = inning.inning,
                outs = inning.outs,
                balls = 0,
                strikes = 0,
                pitchNumber = 1,
                scoreDifferential = 0,
                leverage = 500,
                fatigue = currentFatigue,
            )
            var seedText = maxOf(1UL, rng.next() shr 1).toString()
            val preparation = pitch.prepare(
                PitchKernel.PrepareRequest(
                    seedText, pitcher, batter, scouting, context, memory, gameState, carriedLog,
                ),
            )
            var nextPreparation = preparation
            while (true) {
                val result: PitchKernelResult = pitch.submit(
                    PitchKernel.SubmitRequest(
                        seedText, pitcher, batter, scouting, context,
                        nextPreparation.preparationToken, nextPreparation.primaryRecommendation.call,
                        memory, gameState, carriedLog,
                    ),
                )
                val snapshot = result.snapshot
                pitches += 1
                if (snapshot.result == PlateAppearanceResult.STRIKEOUT) strikeouts += 1
                if (snapshot.result == PlateAppearanceResult.WALK) walks += 1
                if (snapshot.outcome in setOf(PitchOutcome.SINGLE, PitchOutcome.DOUBLE, PitchOutcome.TRIPLE, PitchOutcome.HOME_RUN)) hits += 1
                currentFatigue = snapshot.fatigueAfterPitch.coerceIn(0, 95)
                if (snapshot.ended) {
                    runsAllowed += snapshot.runsScored
                    runsOnBoard = result.gameState.runsAllowed
                    inning = result.gameState.inningState ?: inning
                    runners = result.gameState.runners
                    val outsAfter = (inning.inning - 1) * 3 + inning.outs
                    lineOuts += max(0, outsAfter - outsBefore)
                    carriedLog = result.gameLog
                    gameState = result.gameState
                    benchMemory = result.rivalMemory
                    break
                }
                gameState = result.gameState
                memory = result.rivalMemory
                benchMemory = memory
                carriedLog = result.gameLog
                seedText = result.nextSeed
                context = context.copy(
                    revision = result.revision,
                    inning = result.gameState.inningState?.inning ?: context.inning,
                    outs = result.gameState.inningState?.outs ?: context.outs,
                    balls = snapshot.balls,
                    strikes = snapshot.strikes,
                    pitchNumber = context.pitchNumber + 1,
                    fatigue = currentFatigue,
                )
                val following = result.nextPreparation ?: break
                nextPreparation = following
            }
        }
        return Line(lineOuts, strikeouts, walks, runsAllowed, pitches, hits)
    }

    private fun consumeHighSchoolTeamRunDraws(rng: SplitMix64) {
        // LeagueBaseline.highSchoolTeamRuns and restOfHighSchoolTeamRuns each call
        // SplitMix64.nextInt(1_000) exactly once. Their returned values are not part of
        // the current Kotlin chapter ledger, but their RNG effects are authoritative.
        rng.nextInt(1_000)
        rng.nextInt(1_000)
    }

    private fun starterExtensionOuts(pitcher: com.solkim.baseball.core.pitch.PitcherSnapshot): Int {
        val edge = max(0, pitcher.stamina - maxOf(pitcher.stuff, pitcher.command, pitcher.movement))
        return if (edge > 0) minOf(3, maxOf(1, (edge + 2) / 3)) else 0
    }

    private fun difficultyScale(chapter: Int, lifeNumber: Int): Int {
        val byChapter = minOf(3, maxOf(0, chapter - 1) * 3 / 7)
        val byLife = minOf(4, maxOf(0, lifeNumber - 1) * 2)
        return byChapter + byLife
    }

}
