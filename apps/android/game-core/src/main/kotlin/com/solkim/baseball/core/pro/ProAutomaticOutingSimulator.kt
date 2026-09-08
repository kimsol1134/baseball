package com.solkim.baseball.core.pro

import com.solkim.baseball.core.SplitMix64
import com.solkim.baseball.core.StableHash
import com.solkim.baseball.core.pitch.BatSide
import com.solkim.baseball.core.pitch.BatterScoutingArchetype
import com.solkim.baseball.core.pitch.BatterScoutingProfileRules
import com.solkim.baseball.core.pitch.BatterScoutingSnapshot
import com.solkim.baseball.core.pitch.BatterSnapshot
import com.solkim.baseball.core.pitch.BaserunnerStateSnapshot
import com.solkim.baseball.core.pitch.DefenseSnapshot
import com.solkim.baseball.core.pitch.FielderSnapshot
import com.solkim.baseball.core.pitch.GameLogSnapshot
import com.solkim.baseball.core.pitch.GameStateSnapshot
import com.solkim.baseball.core.pitch.HalfInning
import com.solkim.baseball.core.pitch.InningStateSnapshot
import com.solkim.baseball.core.pitch.ParkSnapshot
import com.solkim.baseball.core.pitch.PitchKernel
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchOutcome
import com.solkim.baseball.core.pitch.PitcherSnapshot
import com.solkim.baseball.core.pitch.PlateAppearanceContext
import com.solkim.baseball.core.pitch.PlateAppearanceResult
import com.solkim.baseball.core.pitch.RivalMemorySnapshot
import com.solkim.baseball.core.pitch.PitchKernelResult
import kotlin.math.max

/** Automatic Pro games use the same Kotlin PitchKernel as the interactive boundary. */
internal class ProAutomaticOutingSimulator(
    private val pitch: PitchKernel = PitchKernel(),
    private val modernPitching: Boolean = true,
    private val professionalBalance: Boolean = false,
) {
    internal data class Line(
        val outs: Int,
        val strikeouts: Int,
        val walks: Int,
        val runsAllowed: Int,
        val pitches: Int,
        val hits: Int,
        val homeRuns: Int,
        val doubles: Int = 0,
        val triples: Int = 0,
        val earnedRuns: Int? = null,
    )

    /**
     * @param callPolicy PERFECT keeps the existing seed stream. Other policies draw one extra
     *   integer per plate appearance.
     * @param diverseScouting defaults to false so v8 careers and fixtures keep the same RNG
     *   count. Existing nextInt calls stay in the same order even when this is true.
     */
    internal fun simulate(
        pitcher: PitcherSnapshot,
        startingFatigue: Int,
        outsTarget: Int,
        pitchCap: Int,
        baseSeed: ULong,
        batterOffset: Int = 0,
        callPolicy: AutoCallPolicy = AutoCallPolicy.PERFECT,
        diverseScouting: Boolean = false,
        delivery: com.solkim.baseball.core.pitch.PitchDelivery? = null,
    ): Line {
        val rng = SplitMix64(baseSeed)
        val fielders = listOf(
            "pitcher", "catcher", "first_base", "second_base", "third_base", "shortstop",
            "left_field", "center_field", "right_field",
        ).map { position -> FielderSnapshot("week-$position", position, position, 50, 50, 50) }
        var inning = InningStateSnapshot(1, HalfInning.TOP, 0)
        var runners = BaserunnerStateSnapshot(false, false, false, 52)
        var runsOnBoard = 0
        var currentFatigue = startingFatigue.coerceIn(0, 95)
        var benchMemory: RivalMemorySnapshot? = null
        var carriedLog = GameLogSnapshot("week-outing", 0UL, 0, emptyList())
        var outsTotal = 0
        var strikeouts = 0
        var walks = 0
        var runsAllowed = 0
        var pitches = 0
        var hits = 0
        var homeRuns = 0
        var doubles = 0
        var triples = 0
        var scoring = com.solkim.baseball.core.pitch.PitchRunLedger()
        var lastGame: GameStateSnapshot? = null
        var lastSeed = baseSeed.toString()
        var plateAppearanceIndex = 0
        val extensionOuts = if (outsTarget >= 18) starterExtensionOuts(pitcher) else 0
        val effectiveOutsTarget = outsTarget + extensionOuts
        val effectivePitchCap = pitchCap + extensionOuts * 4

        while (outsTotal < effectiveOutsTarget && pitches < effectivePitchCap && plateAppearanceIndex < 60) {
            plateAppearanceIndex += 1
            val legacyBatter = BatterSnapshot(
                id = "week-batter-$plateAppearanceIndex",
                name = "상대 타선",
                contact = (50 + batterOffset + rng.nextInt(9) - 4).coerceIn(20, 80),
                discipline = (50 + batterOffset + rng.nextInt(7) - 3).coerceIn(20, 80),
                power = (50 + batterOffset + rng.nextInt(9) - 4).coerceIn(20, 80),
                batSide = if (rng.nextInt(100) < 32) BatSide.LEFT else BatSide.RIGHT,
            )
            val batter = if (professionalBalance) ProfessionalLineup.batter("lineup-$baseSeed", plateAppearanceIndex, batterOffset) else legacyBatter
            val hotZone = com.solkim.baseball.core.pitch.PitchZone(rng.nextInt(3), rng.nextInt(3))
            val mirrored = com.solkim.baseball.core.pitch.PitchZone(2 - hotZone.row, 2 - hotZone.column)
            val weaknessDraw = rng.nextInt(2)
            val chaseTendency = (48 + rng.nextInt(9) - 4).coerceIn(20, 80)
            val scouting: BatterScoutingSnapshot = if (diverseScouting) {
                val seedToken = "${batter.id}|$baseSeed"
                val archetypes = BatterScoutingArchetype.entries
                val archetype = archetypes[
                    (StableHash.fnv1a64Value("$seedToken|archetype") % archetypes.size.toULong()).toInt(),
                ]
                val profile = BatterScoutingProfileRules.profile(archetype, seedToken)
                val mixedWeakness = listOf(PitchKind.SLIDER, PitchKind.CHANGEUP, PitchKind.CURVEBALL, PitchKind.FOUR_SEAM)
                val hashBit = (StableHash.fnv1a64Value("$seedToken|mix") % 2UL).toInt()
                BatterScoutingSnapshot(
                    hotZone = profile.hotZone,
                    coldZone = profile.coldZone,
                    pitchStrength = profile.pitchStrength,
                    pitchWeakness = mixedWeakness[weaknessDraw + hashBit * 2],
                    chaseTendency = chaseTendency,
                )
            } else {
                BatterScoutingSnapshot(
                    hotZone = hotZone,
                    coldZone = if (mirrored == hotZone) com.solkim.baseball.core.pitch.PitchZone(2, 0) else mirrored,
                    pitchStrength = PitchKind.FOUR_SEAM,
                    pitchWeakness = if (weaknessDraw == 0) PitchKind.SLIDER else PitchKind.CHANGEUP,
                    chaseTendency = chaseTendency,
                )
            }
            var game = GameStateSnapshot(
                defense = DefenseSnapshot(50, 50, 50, fielders),
                park = ParkSnapshot("league-week-park", "리그 구장", 1_000, 1_000),
                runners = runners,
                runsAllowed = runsOnBoard,
                inningState = inning,
            )
            if (benchMemory == null) benchMemory = RivalMemorySnapshot("${pitcher.id}:bench:outing", 0UL, 0, 0, emptyList())
            var memory = benchMemory
            val outsBefore = absoluteOuts(inning)
            var context = PlateAppearanceContext(
                plateAppearanceId = "week-pa-$plateAppearanceIndex" + if (modernPitching) ":outing-v2" else "",
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
            var preparation = prepare(
                PitchKernel.PrepareRequest(seedText, pitcher, batter, scouting, context, memory, game, carriedLog),
            )
            val missThisPa = if (callPolicy == AutoCallPolicy.PERFECT) {
                false
            } else {
                val threshold = if (callPolicy == AutoCallPolicy.SLUMP) 35 else 18
                rng.nextInt(100) < threshold
            }
            while (true) {
                val call = if (missThisPa) {
                    preparation.alternativeRecommendation.call
                } else {
                    preparation.primaryRecommendation.call
                }
                val result: PitchKernelResult = pitch.submit(
                    PitchKernel.SubmitRequest(
                        seedText, pitcher, batter, scouting, context,
                        preparation.preparationToken, call,
                        memory, game, carriedLog,
                    ), delivery,
                )
                val snapshot = result.snapshot
                if (professionalBalance) scoring = scoring.advance(snapshot)
                lastGame = result.gameState
                lastSeed = result.nextSeed
                pitches += 1
                if (snapshot.result == PlateAppearanceResult.STRIKEOUT) strikeouts += 1
                if (snapshot.result == PlateAppearanceResult.WALK && (!professionalBalance || snapshot.outcome != PitchOutcome.HIT_BY_PITCH)) walks += 1
                if (snapshot.result == PlateAppearanceResult.HIT) {
                    hits += 1
                    when (snapshot.outcome) {
                        PitchOutcome.HOME_RUN -> homeRuns += 1
                        PitchOutcome.TRIPLE -> triples += 1
                        PitchOutcome.DOUBLE -> doubles += 1
                        else -> Unit
                    }
                }
                currentFatigue = snapshot.fatigueAfterPitch.coerceIn(0, 95)
                memory = result.rivalMemory
                benchMemory = memory
                game = result.gameState
                carriedLog = result.gameLog
                if (snapshot.ended) {
                    runsAllowed += snapshot.runsScored
                    runsOnBoard = result.gameState.runsAllowed
                    inning = result.gameState.inningState ?: inning
                    runners = result.gameState.runners
                    outsTotal += max(0, absoluteOuts(inning) - outsBefore)
                    break
                }
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
                preparation = if (modernPitching) result.nextPreparation ?: break else pitch.prepareLegacy(PitchKernel.PrepareRequest(seedText, pitcher, batter, scouting, context, memory, game, carriedLog))
            }
        }
        if (professionalBalance && lastGame != null) {
            scoring = settleReliefRuns(pitch, lastGame!!, scoring, lastSeed)
            runsAllowed = scoring.runs
        }
        return Line(outsTotal, strikeouts, walks, runsAllowed, pitches, hits, homeRuns, doubles, triples, if (professionalBalance) scoring.earnedRuns else null)
    }

    private fun prepare(request: PitchKernel.PrepareRequest): com.solkim.baseball.core.pitch.PitchPreparation =
        if (modernPitching) pitch.prepare(request) else pitch.prepareLegacy(request)

    private fun starterExtensionOuts(pitcher: PitcherSnapshot): Int {
        val edge = max(0, pitcher.stamina - maxOf(pitcher.stuff, pitcher.command, pitcher.movement))
        return if (edge > 0) minOf(3, maxOf(1, (edge + 2) / 3)) else 0
    }

    private fun absoluteOuts(state: InningStateSnapshot): Int =
        (state.inning - 1) * 6 + (if (state.half == HalfInning.BOTTOM) 3 else 0) + state.outs
}
