package com.solkim.baseball.core.pitch

import com.solkim.baseball.core.SplitMix64
import com.solkim.baseball.model.Hashing
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.PI
import kotlin.math.sin
import kotlin.math.sqrt

public enum class PitchKind(public val wire: String) {
    FOUR_SEAM("four_seam"),
    SLIDER("slider"),
    CURVEBALL("curveball"),
    CHANGEUP("changeup"),
}

public enum class PitchIntensity(public val wire: String) {
    CONTROLLED("controlled"),
    NORMAL("normal"),
    MAX_EFFORT("max_effort"),
}

public enum class PitchUsageRole(public val wire: String) {
    PRIMARY("primary"),
    SECONDARY("secondary"),
    DEVELOPMENT("development"),
}

public enum class BatSide { RIGHT, LEFT, SWITCH }

public enum class ThrowingHand { RIGHT, LEFT }

public enum class ZoneIntent(public val wire: String) {
    STRIKE("strike"),
    EDGE("edge"),
    CHASE("chase"),
}

public enum class PitchOutcome(public val wire: String) {
    BALL("ball"),
    CALLED_STRIKE("called_strike"),
    SWINGING_STRIKE("swinging_strike"),
    FOUL("foul"),
    IN_PLAY_OUT("in_play_out"),
    SINGLE("single"),
    DOUBLE("double"),
    TRIPLE("triple"),
    HOME_RUN("home_run"),
    HIT_BY_PITCH("hit_by_pitch"),
}

public enum class SelectionQuality(public val wire: String) {
    POOR("poor"),
    RISKY("risky"),
    GOOD("good"),
    EXCELLENT("excellent"),
}

public enum class PlateAppearanceResult(public val wire: String) {
    STRIKEOUT("strikeout"),
    WALK("walk"),
    IN_PLAY_OUT("in_play_out"),
    HIT("hit"),
}

public enum class PitchAbilityKind(public val wire: String) {
    POWER("power"),
    COMMAND("command"),
    MOVEMENT("movement"),
    STAMINA("stamina"),
}

public enum class RivalAdaptationBand(public val wire: String) {
    NO_DATA("no_data"),
    WATCHING("watching"),
    LEARNING("learning"),
    LOCKED_ON("locked_on"),
}

public enum class FieldingSector { INFIELD, OUTFIELD, FENCE }
public enum class DefenseImpact { HELPED_PITCHER, NEUTRAL, HURT_PITCHER }
public enum class HalfInning { TOP, BOTTOM }
public enum class AnalysisConfidenceBand { LOW, DEVELOPING, RELIABLE }

public data class PitchZone(val row: Int, val column: Int)

public data class PitchProfileSnapshot(
    val pitchType: PitchKind,
    val role: PitchUsageRole,
    val velocityTenthsKph: Int,
    val control: Int,
    val command: Int,
    val movement: Int,
    val whiff: Int,
    val weakContact: Int,
    val fatigueCost: Int,
)

public data class PitcherSnapshot(
    val id: String,
    val name: String,
    val stuff: Int,
    val command: Int,
    val movement: Int,
    val stamina: Int,
    val pitchProfiles: List<PitchProfileSnapshot>? = null,
    val throwingHand: ThrowingHand = ThrowingHand.RIGHT,
) {
    public fun profile(pitchType: PitchKind): PitchProfileSnapshot? =
        pitchProfiles?.firstOrNull { it.pitchType == pitchType }
}

public data class BatterSnapshot(
    val id: String,
    val name: String,
    val contact: Int,
    val discipline: Int,
    val power: Int,
    val batSide: BatSide = BatSide.RIGHT,
)

public data class BatterScoutingSnapshot(
    val hotZone: PitchZone,
    val coldZone: PitchZone,
    val pitchStrength: PitchKind,
    val pitchWeakness: PitchKind,
    val chaseTendency: Int,
    val reliability: Int = ScoutingEstimate.TRUSTED_RELIABILITY,
)

public data class PlateAppearanceContext(
    val plateAppearanceId: String,
    val revision: ULong,
    val inning: Int,
    val outs: Int,
    val balls: Int,
    val strikes: Int,
    val pitchNumber: Int,
    val scoreDifferential: Int,
    val leverage: Int,
    val fatigue: Int,
)

public data class PitchCall(
    val pitchType: PitchKind,
    val zone: PitchZone,
    val zoneIntent: ZoneIntent,
    val intensity: PitchIntensity,
)

public data class PitchDelivery(
    val releaseAccuracy: Int,
    val aimAccuracy: Int,
) {
    public val isPerfectRelease: Boolean get() = releaseAccuracy >= PERFECT_RELEASE_THRESHOLD

    public companion object {
        public const val PERFECT_RELEASE_THRESHOLD: Int = 975
        public val NEUTRAL: PitchDelivery = PitchDelivery(500, 500)
    }
}

public data class RivalPitchObservation(
    val pitchType: PitchKind,
    val zone: PitchZone,
    val zoneIntent: ZoneIntent,
    val balls: Int,
    val strikes: Int,
    val outcome: PitchOutcome,
)

public data class RivalMemorySnapshot(
    val matchupId: String,
    val revision: ULong,
    val plateAppearancesSeen: Int,
    val totalPitchesSeen: Int,
    val recentObservations: List<RivalPitchObservation>,
)

public data class RivalAdaptationSnapshot(
    val level: Int,
    val band: RivalAdaptationBand,
    val evidenceCount: Int,
    val detectedPitch: PitchKind?,
    val detectedZone: PitchZone?,
    val leanPitch: PitchKind,
    val leanZone: PitchZone,
    val pitchReadStrength: Int,
    val zoneReadStrength: Int,
    val confidence: Int,
    val warning: String,
)

public data class ScoutingReportSnapshot(
    val reliability: Int,
    val observationCount: Int,
    val band: String,
    val estimatedWeakness: PitchKind,
    val estimatedColdZone: PitchZone,
    val estimatedStrength: PitchKind?,
    val estimatedHotZone: PitchZone?,
    val estimatedChaseTendency: Int,
    val chaseTendencyMargin: Int,
)

public data class PitchRecommendation(
    val call: PitchCall,
    val confidence: Int,
    val reasonCodes: List<String>,
    val shortReason: String,
)

public data class PitchPreparation(
    val seed: String,
    val revision: ULong,
    val pitchNumber: Int,
    val preparationToken: String,
    val planCommitment: String,
    val primaryRecommendation: PitchRecommendation,
    val alternativeRecommendation: PitchRecommendation,
    val rivalAdaptation: RivalAdaptationSnapshot,
    val scoutingReport: ScoutingReportSnapshot,
)

public data class PitchExecution(
    val targetX: Int,
    val targetY: Int,
    val actualX: Int,
    val actualY: Int,
    val velocityTenthsKph: Int,
    val horizontalBreakTenthsCm: Int,
    val verticalBreakTenthsCm: Int,
    val executionQuality: Int,
    val flightTimeMilliseconds: Int,
    val trajectoryControlX: Int,
    val trajectoryControlY: Int,
    val trajectorySeries: List<Int>,
)

/**
 * Renderer-facing snapshot derived by the authoritative kernel. It contains only the bounded
 * physical flight data needed by Unity; outcome, count, fielding, and persistence stay on the
 * surrounding [PitchSnapshot] and [PitchKernelResult].
 */
public data class TrajectoryPresentationSnapshot(
    val pitchType: PitchKind,
    val presentationSeed: String,
    val flightDurationMilliseconds: Int,
    val plateXMm: Int,
    val plateYMm: Int,
    val velocityTenthsKph: Int,
    val trajectorySeries: List<Int>,
)

public data class BattedBall(
    val exitVelocityTenthsKph: Int,
    val launchAngleTenthsDegrees: Int,
    val directionTenthsDegrees: Int,
    val contactQuality: Int,
)

public data class FielderSnapshot(
    val id: String,
    val name: String,
    val position: String,
    val range: Int,
    val glove: Int,
    val arm: Int,
)

public data class DefenseSnapshot(
    val infield: Int,
    val outfield: Int,
    val arm: Int,
    val fielders: List<FielderSnapshot>? = null,
) {
    public fun fielder(position: String): FielderSnapshot? = fielders?.firstOrNull { it.position == position }
}

public data class ParkSnapshot(
    val id: String,
    val name: String,
    val hitFactor: Int,
    val homeRunFactor: Int,
)

public data class BaserunnerStateSnapshot(
    val firstOccupied: Boolean,
    val secondOccupied: Boolean,
    val thirdOccupied: Boolean,
    val leadRunnerSpeed: Int,
) {
    public val occupiedCount: Int
        get() = (if (firstOccupied) 1 else 0) + (if (secondOccupied) 1 else 0) +
            (if (thirdOccupied) 1 else 0)

    public companion object {
        public val EMPTY: BaserunnerStateSnapshot = BaserunnerStateSnapshot(false, false, false, 50)
    }
}

public data class InningStateSnapshot(
    val inning: Int,
    val half: HalfInning,
    val outs: Int,
)

public data class GameStateSnapshot(
    val defense: DefenseSnapshot,
    val park: ParkSnapshot,
    val runners: BaserunnerStateSnapshot,
    val runsAllowed: Int,
    val inningState: InningStateSnapshot? = null,
) {
    public companion object {
        public fun standard(): GameStateSnapshot = GameStateSnapshot(
            defense = DefenseSnapshot(50, 50, 50),
            park = ParkSnapshot("neutral-park", "중립 구장", 1000, 1000),
            runners = BaserunnerStateSnapshot.EMPTY,
            runsAllowed = 0,
        )
    }
}

public data class FieldingResolutionSnapshot(
    val neutralOutcome: PitchOutcome,
    val finalOutcome: PitchOutcome,
    val sector: FieldingSector,
    val difficulty: Int,
    val defenseRating: Int,
    val defenseAdjustment: Int,
    val parkAdjustment: Int,
    val impact: DefenseImpact,
    val fielderPosition: String?,
    val fielderName: String?,
    val landingDistanceTenthsMeters: Int?,
    val hangTimeMilliseconds: Int?,
    val apexHeightTenthsMeters: Int?,
    val ballFlightSeries: List<Int>?,
    val shortExplanation: String,
)

public data class StealAttemptSnapshot(
    val fromBase: Int,
    val toBase: Int,
    val runnerSpeed: Int,
    val catcherArm: Int,
    val succeeded: Boolean,
    val shortExplanation: String,
)

public data class InningTransitionSnapshot(
    val before: InningStateSnapshot,
    val after: InningStateSnapshot,
    val outsRecorded: Int,
    val doublePlayCompleted: Boolean,
    val inningEnded: Boolean,
    val shortExplanation: String,
)

public data class BaserunnerAdvanceSnapshot(
    val before: BaserunnerStateSnapshot,
    val after: BaserunnerStateSnapshot,
    val runsScored: Int,
    val shortExplanation: String,
)

public data class PitchAnalysisEntry(
    val pitchType: PitchKind,
    val wasInZone: Boolean,
    val batterSwung: Boolean,
    val outcome: PitchOutcome,
    val selectionQuality: SelectionQuality,
    val executionQuality: Int,
    val contactQuality: Int?,
    val expectedDamage: Int,
    val actualDamage: Int,
    val recommendationAccepted: Boolean,
    val velocityTenthsKph: Int?,
)

public data class GameLogSnapshot(
    val gameId: String,
    val revision: ULong,
    val totalPitches: Int,
    val entries: List<PitchAnalysisEntry>,
)

public data class PitchAbilityReadout(
    val pitchType: PitchKind,
    val stuffRating: Int,
    val commandRating: Int,
    val movementRating: Int,
    val staminaRating: Int,
    val whiffRating: Int,
    val weakContactRating: Int,
    val nominalVelocityTenthsKph: Int,
    val fatigueCost: Int,
    val effectiveFatigue: Int,
    val rawFatigue: Int,
) {
    public val fatiguePrevented: Int get() = max(0, rawFatigue - effectiveFatigue)
}

public data class PitchSnapshot(
    val revision: ULong,
    val balls: Int,
    val strikes: Int,
    val pitchNumber: Int,
    val ended: Boolean,
    val result: PlateAppearanceResult?,
    val outcome: PitchOutcome,
    val selectionQuality: SelectionQuality,
    val recommendationAccepted: Boolean,
    val fatigueAfterPitch: Int,
    val execution: PitchExecution,
    val trajectoryPresentation: TrajectoryPresentationSnapshot,
    val battedBall: BattedBall?,
    val fieldingResolution: FieldingResolutionSnapshot?,
    val runnersBefore: BaserunnerStateSnapshot,
    val runnersAfter: BaserunnerStateSnapshot,
    val runsScored: Int,
    val stealAttempt: StealAttemptSnapshot?,
    val inningTransition: InningTransitionSnapshot,
    val reasonCodes: List<String>,
)

public data class PitchKernelEvent(
    val eventType: String,
    val sequence: Int,
)

public data class PitchKernelResult(
    val revision: ULong,
    val nextSeed: String,
    val snapshot: PitchSnapshot,
    val nextPreparation: PitchPreparation?,
    val rivalMemory: RivalMemorySnapshot,
    val rivalAdaptation: RivalAdaptationSnapshot,
    val gameState: GameStateSnapshot,
    val gameLog: GameLogSnapshot,
    val eventHash: String,
    val events: List<PitchKernelEvent>,
    val abilityMoment: PitchAbilityKind?,
) {
    public val eventTypes: List<String> get() = events.map { it.eventType }
}

public class PitchKernelException(public val code: String, message: String) : IllegalArgumentException(message)

public object PitchAbilityRules {
    public const val MAXIMUM_PROFILE_VELOCITY_TENTHS_KPH: Int = 1600
    public const val MAXIMUM_EXECUTED_VELOCITY_TENTHS_KPH: Int = 1650

    public fun maximumProfileVelocity(pitchType: PitchKind): Int = when (pitchType) {
        PitchKind.FOUR_SEAM -> 1600
        PitchKind.SLIDER -> 1500
        PitchKind.CURVEBALL -> 1370
        PitchKind.CHANGEUP -> 1480
    }

    public fun readout(pitcher: PitcherSnapshot, call: PitchCall, context: PlateAppearanceContext): PitchAbilityReadout {
        val profile = pitcher.profile(call.pitchType)
        return PitchAbilityReadout(
            pitchType = call.pitchType,
            stuffRating = pitcher.stuff,
            commandRating = commandRating(pitcher, profile),
            movementRating = profile?.let { (pitcher.movement + it.movement) / 2 } ?: pitcher.movement,
            staminaRating = pitcher.stamina,
            whiffRating = profile?.whiff ?: pitcher.stuff,
            weakContactRating = profile?.weakContact ?: 50,
            nominalVelocityTenthsKph = nominalVelocity(pitcher, call.pitchType, call.intensity, context.fatigue),
            fatigueCost = fatigueCost(call.intensity, profile),
            effectiveFatigue = effectiveFatigue(context.fatigue, pitcher.stamina),
            rawFatigue = context.fatigue,
        )
    }

    public fun moment(
        outcome: PitchOutcome,
        execution: PitchExecution,
        readout: PitchAbilityReadout,
    ): PitchAbilityKind? {
        if (outcome != PitchOutcome.CALLED_STRIKE && outcome != PitchOutcome.SWINGING_STRIKE &&
            outcome != PitchOutcome.IN_PLAY_OUT) return null
        if (outcome == PitchOutcome.CALLED_STRIKE && readout.commandRating >= 55 && execution.executionQuality >= 650) {
            return PitchAbilityKind.COMMAND
        }
        if (outcome == PitchOutcome.SWINGING_STRIKE) {
            val powerContribution = max(0, readout.stuffRating - 50) * 4
            val movementContribution = max(0, readout.movementRating - 50) * 6
            if (readout.pitchType != PitchKind.FOUR_SEAM && readout.movementRating >= 55 &&
                movementContribution >= powerContribution
            ) return PitchAbilityKind.MOVEMENT
            if (readout.stuffRating >= 55) return PitchAbilityKind.POWER
        }
        if (outcome == PitchOutcome.IN_PLAY_OUT && readout.movementRating >= 55) {
            return PitchAbilityKind.MOVEMENT
        }
        if (readout.staminaRating >= 55 && readout.fatiguePrevented >= 5) return PitchAbilityKind.STAMINA
        return null
    }

    internal fun intensity(intensity: PitchIntensity): IntensityEffect = when (intensity) {
        PitchIntensity.CONTROLLED -> IntensityEffect(-18, -105)
        PitchIntensity.NORMAL -> IntensityEffect(0, 0)
        PitchIntensity.MAX_EFFORT -> IntensityEffect(34, 130)
    }

    internal fun commandRating(pitcher: PitcherSnapshot, profile: PitchProfileSnapshot?): Int =
        profile?.let { (pitcher.command * 4 + it.control * 4 + it.command * 2) / 10 } ?: pitcher.command

    internal fun nominalVelocity(
        pitcher: PitcherSnapshot,
        type: PitchKind,
        intensity: PitchIntensity,
        fatigue: Int,
    ): Int {
        val profile = pitcher.profile(type)
        val base = profile?.velocityTenthsKph ?: baseVelocity(type) + (pitcher.stuff - 50) * 2
        val pressure = effectiveFatigue(fatigue, pitcher.stamina)
        val raw = base + intensity(intensity).velocityBonusTenthsKph - pressure
        val ceiling = when (intensity) {
            PitchIntensity.CONTROLLED -> maximumProfileVelocity(type) - 20
            PitchIntensity.NORMAL -> maximumProfileVelocity(type)
            PitchIntensity.MAX_EFFORT -> maximumProfileVelocity(type) + if (type == PitchKind.FOUR_SEAM) 40 else 30
        }
        return min(raw, ceiling)
    }

    public fun effectiveFatigue(rawFatigue: Int, stamina: Int): Int {
        val boundedRaw = min(100, max(0, rawFatigue))
        val boundedStamina = min(80, max(20, stamina))
        val multiplierPermille = 1250 - (boundedStamina - 20) * 500 / 60
        return min(100, max(0, boundedRaw * multiplierPermille / 1000))
    }

    internal fun fatigueCost(intensity: PitchIntensity, profile: PitchProfileSnapshot?): Int = profile?.let {
        max(0, it.fatigueCost + when (intensity) {
            PitchIntensity.CONTROLLED -> -1
            PitchIntensity.NORMAL -> 0
            PitchIntensity.MAX_EFFORT -> 1
        })
    } ?: when (intensity) {
        PitchIntensity.CONTROLLED -> 0
        PitchIntensity.NORMAL -> 1
        PitchIntensity.MAX_EFFORT -> 2
    }

    private fun baseVelocity(type: PitchKind): Int = when (type) {
        PitchKind.FOUR_SEAM -> 1420
        PitchKind.SLIDER -> 1275
        PitchKind.CURVEBALL -> 1165
        PitchKind.CHANGEUP -> 1285
    }

    internal data class IntensityEffect(val commandPenalty: Int, val velocityBonusTenthsKph: Int)
}

public object ScoutingEstimate {
    public const val TRUSTED_RELIABILITY: Int = 60
    private const val OBSERVATION_PITCH_GAIN: Int = 5
    private const val OBSERVATION_REMATCH_GAIN: Int = 12
    private const val OBSERVATION_BONUS_CAP: Int = 100
    private const val CONFIDENCE_PENALTY_PER_POINT: Int = 6
    private const val CONFIDENCE_FLOOR: Int = 180
    private const val CHASE_UNCERTAINTY_SCALE: Int = 12
    private const val DEVELOPING_RELIABILITY: Int = 40

    public fun effectiveReliability(baseline: Int, memory: RivalMemorySnapshot?): Int {
        val pitchesSeen = memory?.totalPitchesSeen ?: 0
        val rematches = memory?.plateAppearancesSeen ?: 0
        val bonus = min(OBSERVATION_BONUS_CAP, pitchesSeen * OBSERVATION_PITCH_GAIN + rematches * OBSERVATION_REMATCH_GAIN)
        return clamp(baseline + bonus, 0, 100)
    }

    public fun adjustedConfidence(raw: Int, reliability: Int): Int =
        min(raw, max(CONFIDENCE_FLOOR, raw - max(0, TRUSTED_RELIABILITY - reliability) * CONFIDENCE_PENALTY_PER_POINT))

    public fun matchupSeed(pitcherId: String, batterId: String): ULong =
        Hashing.fnv1a64Hex("$pitcherId|$batterId|scouting").toULong(16)

    public fun estimatedScouting(truth: BatterScoutingSnapshot, reliability: Int, matchupSeed: ULong): BatterScoutingSnapshot {
        if (reliability >= TRUSTED_RELIABILITY) return truth
        val generator = SplitMix64(matchupSeed)
        val weaknessThreshold = 30 + generator.nextInt(29)
        val coldZoneThreshold = 24 + generator.nextInt(35)
        val hotZoneThreshold = 24 + generator.nextInt(35)
        val decoyWeakness = pitchDecoy(truth.pitchWeakness, generator)
        val decoyColdZone = zoneDecoy(truth.coldZone, generator)
        val decoyHotZone = zoneDecoy(truth.hotZone, generator)
        val chaseMagnitude = 6 + generator.nextInt(9)
        val chaseOffset = if (generator.nextInt(2) == 0) -chaseMagnitude else chaseMagnitude
        val gap = max(0, TRUSTED_RELIABILITY - reliability)
        return BatterScoutingSnapshot(
            hotZone = if (reliability >= hotZoneThreshold) truth.hotZone else decoyHotZone,
            coldZone = if (reliability >= coldZoneThreshold) truth.coldZone else decoyColdZone,
            pitchStrength = truth.pitchStrength,
            pitchWeakness = if (reliability >= weaknessThreshold) truth.pitchWeakness else decoyWeakness,
            chaseTendency = clamp(truth.chaseTendency + chaseOffset * gap / TRUSTED_RELIABILITY, 20, 80),
            reliability = reliability,
        )
    }

    public fun report(estimate: BatterScoutingSnapshot, effectiveReliability: Int, observationCount: Int): ScoutingReportSnapshot {
        val band = when {
            effectiveReliability >= TRUSTED_RELIABILITY -> "trusted"
            effectiveReliability >= DEVELOPING_RELIABILITY -> "developing"
            else -> "low"
        }
        return ScoutingReportSnapshot(
            reliability = effectiveReliability,
            observationCount = observationCount,
            band = band,
            estimatedWeakness = estimate.pitchWeakness,
            estimatedColdZone = estimate.coldZone,
            estimatedStrength = estimate.pitchStrength,
            estimatedHotZone = estimate.hotZone,
            estimatedChaseTendency = estimate.chaseTendency,
            chaseTendencyMargin = max(0, TRUSTED_RELIABILITY - effectiveReliability) * CHASE_UNCERTAINTY_SCALE / TRUSTED_RELIABILITY,
        )
    }

    private fun pitchDecoy(truth: PitchKind, generator: SplitMix64): PitchKind {
        val options = PitchKind.entries.filter { it != truth }
        return options[generator.nextInt(options.size)]
    }

    private fun zoneDecoy(truth: PitchZone, generator: SplitMix64): PitchZone {
        val candidates = buildList {
            for (deltaRow in -1..1) for (deltaColumn in -1..1) {
                if (deltaRow == 0 && deltaColumn == 0) continue
                val row = truth.row + deltaRow
                val column = truth.column + deltaColumn
                if (row in 0..2 && column in 0..2) add(PitchZone(row, column))
            }
        }
        return candidates[generator.nextInt(candidates.size)]
    }
}

public object ZoneIntentRules {
    public fun clamp(intent: ZoneIntent, zone: PitchZone): ZoneIntent =
        if (zone.row == 1 && zone.column == 1 && intent == ZoneIntent.EDGE) ZoneIntent.STRIKE else intent
}

private class SignSituation(
    private val context: PlateAppearanceContext,
    private val gameState: GameStateSnapshot?,
    private val lastPitch: PitchAnalysisEntry?,
) {
    private val count: SignCount = when {
        context.balls == 0 && context.strikes == 0 -> SignCount.FIRST
        context.balls == 3 && context.strikes == 0 -> SignCount.MUST_THROW_STRIKE
        (context.balls == 0 || context.balls == 1) && context.strikes == 2 -> SignCount.AHEAD
        (context.balls == 2 && context.strikes == 0) || (context.balls == 3 && context.strikes == 1) -> SignCount.BEHIND
        else -> SignCount.EVEN
    }
    private val runners: BaserunnerStateSnapshot = gameState?.runners ?: BaserunnerStateSnapshot.EMPTY
    public val doublePlayChance: Boolean = context.outs < 2 && runners.firstOccupied
    public val sacrificeFlyRisk: Boolean = context.outs < 2 && runners.thirdOccupied
    public val avoidsRepeat: Boolean = lastPitch != null && (
        lastPitch.outcome == PitchOutcome.SINGLE || lastPitch.outcome == PitchOutcome.DOUBLE ||
            lastPitch.outcome == PitchOutcome.TRIPLE || lastPitch.outcome == PitchOutcome.HOME_RUN ||
            (lastPitch.outcome == PitchOutcome.FOUL && context.strikes == 2)
        )

    public val demandsControl: Boolean get() = count == SignCount.MUST_THROW_STRIKE || count == SignCount.BEHIND || doublePlayChance
    public val countCode: String get() = when (count) {
        SignCount.FIRST -> "count.first_pitch"
        SignCount.AHEAD -> "count.pitcher_ahead"
        SignCount.BEHIND -> "count.pitcher_behind"
        SignCount.MUST_THROW_STRIKE -> "count.avoid_walk"
        SignCount.EVEN -> "count.standard"
    }

    public fun shift(zone: PitchZone): PitchZone {
        var row = zone.row
        var column = zone.column
        when (count) {
            SignCount.MUST_THROW_STRIKE -> { row = 1; column = 1 }
            SignCount.BEHIND -> { row = pullInward(row); column = pullInward(column) }
            SignCount.AHEAD -> row = min(2, row + 1)
            else -> Unit
        }
        if ((doublePlayChance || sacrificeFlyRisk) && count != SignCount.MUST_THROW_STRIKE) row = max(row, 1)
        return PitchZone(row, column)
    }

    public fun zoneIntent(protectZone: Boolean, twoStrikes: Boolean): ZoneIntent = when {
        protectZone || count == SignCount.MUST_THROW_STRIKE || count == SignCount.BEHIND -> ZoneIntent.STRIKE
        count == SignCount.AHEAD -> ZoneIntent.CHASE
        count == SignCount.FIRST -> ZoneIntent.EDGE
        else -> if (twoStrikes) ZoneIntent.CHASE else ZoneIntent.EDGE
    }

    public val extraReasonCodes: List<String> get() = buildList {
        if (doublePlayChance) add("runners.double_play_setup")
        if (sacrificeFlyRisk) add("runners.suppress_sacrifice_fly")
    }

    private fun pullInward(value: Int): Int = if (value == 0 || value == 2) 1 else value
    private enum class SignCount { FIRST, AHEAD, BEHIND, MUST_THROW_STRIKE, EVEN }
}

private class RivalMemoryEngine {
    public fun emptyMemory(pitcher: PitcherSnapshot, batter: BatterSnapshot): RivalMemorySnapshot = RivalMemorySnapshot(
        matchupId = "${pitcher.id}:${batter.id}",
        revision = 0UL,
        plateAppearancesSeen = 0,
        totalPitchesSeen = 0,
        recentObservations = emptyList(),
    )

    public fun validate(memory: RivalMemorySnapshot?, pitcher: PitcherSnapshot, batter: BatterSnapshot) {
        if (memory == null) return
        val direct = "${pitcher.id}:${batter.id}"
        requireKernel(memory.matchupId == direct || memory.matchupId.startsWith("${pitcher.id}:bench:"), "invalid_rival_memory")
        requireKernel(memory.plateAppearancesSeen >= 0 && memory.totalPitchesSeen >= memory.recentObservations.size &&
            memory.recentObservations.size <= MAXIMUM_OBSERVATIONS, "invalid_rival_memory")
        memory.recentObservations.forEach {
            requireKernel(it.zone.row in 0..2 && it.zone.column in 0..2 && it.balls in 0..3 && it.strikes in 0..2, "invalid_rival_memory")
        }
    }

    public fun analyze(memory: RivalMemorySnapshot?, context: PlateAppearanceContext): RivalAdaptationSnapshot {
        if (memory == null || memory.recentObservations.isEmpty()) {
            return RivalAdaptationSnapshot(
                level = 0,
                band = RivalAdaptationBand.NO_DATA,
                evidenceCount = 0,
                detectedPitch = null,
                detectedZone = null,
                leanPitch = PitchKind.FOUR_SEAM,
                leanZone = PitchZone(1, 1),
                pitchReadStrength = 0,
                zoneReadStrength = 0,
                confidence = 0,
                warning = "아직 이 투수의 공을 충분히 보지 못했습니다.",
            )
        }
        val matching = memory.recentObservations.filter {
            (it.strikes == 2) == (context.strikes == 2) && (it.balls == 3) == (context.balls == 3)
        }
        val evidence = if (matching.size >= 3) matching else memory.recentObservations
        val effectiveCount = max(1, evidence.sumOf(::observationWeight) / 2)
        val topPitch = mostFrequentPitch(evidence)
        val topZone = mostFrequentZone(evidence)
        val pitchShare = topPitch.second * 1000 / evidence.size
        val zoneShare = topZone.second * 1000 / evidence.size
        val sampleSignal = max(0, effectiveCount - 2) * 15
        val pitchSignal = max(0, pitchShare - 400) / 2
        val zoneSignal = max(0, zoneShare - 350) / 4
        val rematchSignal = min(memory.plateAppearancesSeen * 80, 240)
        val level = min(900, sampleSignal + pitchSignal + zoneSignal + rematchSignal).let {
            if (memory.plateAppearancesSeen == 0) min(it, 420) else it
        }
        val sampleWeight = min(effectiveCount, READ_SAMPLE_SATURATION)
        val patternSample = max(0, sampleWeight - READ_SAMPLE_FLOOR)
        val patternSpan = READ_SAMPLE_SATURATION - READ_SAMPLE_FLOOR
        val pitchExcess = max(0, pitchShare - PITCH_READ_BASELINE)
        val zoneExcess = max(0, zoneShare - ZONE_READ_BASELINE)
        val pitchReadStrength = min(PITCH_READ_CAP,
            pitchExcess * patternSample / patternSpan + patternSample * PITCH_FAMILIARITY_FLOOR / patternSpan)
        val zoneReadStrength = min(ZONE_READ_CAP,
            zoneExcess * patternSample / patternSpan + patternSample * ZONE_FAMILIARITY_FLOOR / patternSpan)
        val detectedPitch = if (evidence.size >= 4 && pitchShare >= 500) topPitch.first else null
        val detectedZone = if (evidence.size >= 4 && zoneShare >= 500) topZone.first else null
        val confidence = min(950, evidence.size * 28 + max(pitchShare, zoneShare) / 2)
        val band = when {
            level == 0 -> RivalAdaptationBand.NO_DATA
            level < 250 -> RivalAdaptationBand.WATCHING
            level < 600 -> RivalAdaptationBand.LEARNING
            else -> RivalAdaptationBand.LOCKED_ON
        }
        return RivalAdaptationSnapshot(
            level = level,
            band = band,
            evidenceCount = evidence.size,
            detectedPitch = detectedPitch,
            detectedZone = detectedZone,
            leanPitch = topPitch.first,
            leanZone = topZone.first,
            pitchReadStrength = pitchReadStrength,
            zoneReadStrength = zoneReadStrength,
            confidence = confidence,
            warning = "아직 확정적인 패턴은 없지만 투구 기록을 쌓고 있습니다.",
        )
    }

    public fun record(
        memory: RivalMemorySnapshot?,
        pitcher: PitcherSnapshot,
        batter: BatterSnapshot,
        context: PlateAppearanceContext,
        call: PitchCall,
        outcome: PitchOutcome,
        plateAppearanceEnded: Boolean,
    ): RivalMemorySnapshot {
        val current = memory ?: emptyMemory(pitcher, batter)
        val observation = RivalPitchObservation(call.pitchType, call.zone, call.zoneIntent, context.balls, context.strikes, outcome)
        val observations = (current.recentObservations + observation).takeLast(MAXIMUM_OBSERVATIONS)
        return current.copy(
            revision = current.revision + 1UL,
            plateAppearancesSeen = current.plateAppearancesSeen + if (plateAppearanceEnded) 1 else 0,
            totalPitchesSeen = current.totalPitchesSeen + 1,
            recentObservations = observations,
        )
    }

    private fun observationWeight(observation: RivalPitchObservation): Int = when (observation.outcome) {
        PitchOutcome.SINGLE, PitchOutcome.DOUBLE, PitchOutcome.TRIPLE, PitchOutcome.HOME_RUN -> 6
        PitchOutcome.FOUL, PitchOutcome.IN_PLAY_OUT -> 4
        PitchOutcome.BALL, PitchOutcome.CALLED_STRIKE, PitchOutcome.HIT_BY_PITCH -> 2
        PitchOutcome.SWINGING_STRIKE -> 1
    }

    private fun mostFrequentPitch(observations: List<RivalPitchObservation>): Pair<PitchKind, Int> {
        var best = PitchKind.FOUR_SEAM
        var bestCount = -1
        val totalWeight = max(1, observations.sumOf(::observationWeight))
        PitchKind.entries.forEach { pitchType ->
            val count = observations.filter { it.pitchType == pitchType }.sumOf(::observationWeight) * observations.size / totalWeight
            if (count > bestCount) { best = pitchType; bestCount = count }
        }
        return best to bestCount
    }

    private fun mostFrequentZone(observations: List<RivalPitchObservation>): Pair<PitchZone, Int> {
        var best = PitchZone(0, 0)
        var bestCount = -1
        val totalWeight = max(1, observations.sumOf(::observationWeight))
        for (index in 0..8) {
            val zone = PitchZone(index / 3, index % 3)
            val count = observations.filter { it.zone == zone }.sumOf(::observationWeight) * observations.size / totalWeight
            if (count > bestCount) { best = zone; bestCount = count }
        }
        return best to bestCount
    }

    private companion object {
        const val MAXIMUM_OBSERVATIONS: Int = 24
        const val READ_SAMPLE_FLOOR: Int = 3
        const val READ_SAMPLE_SATURATION: Int = 18
        const val PITCH_READ_BASELINE: Int = 260
        const val ZONE_READ_BASELINE: Int = 150
        const val PITCH_FAMILIARITY_FLOOR: Int = 60
        const val ZONE_FAMILIARITY_FLOOR: Int = 40
        const val PITCH_READ_CAP: Int = 300
        const val ZONE_READ_CAP: Int = 250
    }
}

private class CatcherRecommendationEngine {
    public fun recommend(
        pitcher: PitcherSnapshot,
        batter: BatterSnapshot,
        scouting: BatterScoutingSnapshot,
        context: PlateAppearanceContext,
        adaptation: RivalAdaptationSnapshot,
        reliability: Int,
        gameState: GameStateSnapshot?,
        lastPitch: PitchAnalysisEntry?,
    ): Pair<PitchRecommendation, PitchRecommendation> {
        val twoStrikes = context.strikes == 2
        val protectZone = context.balls == 3
        val situation = SignSituation(context, gameState, lastPitch)
        val desired = recommendedPrimaryPitch(pitcher, scouting.pitchWeakness, twoStrikes, protectZone, lastPitch?.pitchType)
        val repetitionAvoided = adaptation.level >= 500 && adaptation.detectedPitch == desired
        val mustChange = repetitionAvoided || (situation.avoidsRepeat && lastPitch?.pitchType == desired)
        val primaryPitch = if (mustChange) recommendedAlternativePitch(
            pitcher, desired, if (desired == PitchKind.FOUR_SEAM) PitchKind.SLIDER else PitchKind.FOUR_SEAM
        ) else desired
        val primaryProfile = pitcher.profile(primaryPitch)
        val primaryZone = situation.shift(scouting.coldZone)
        val primaryReasons = buildList {
            add(if (repetitionAvoided) "rival.pattern_detected" else if (mustChange) "sequence.avoid_repeat" else if (primaryPitch == scouting.pitchWeakness) "scouting.pitch_weakness" else "arsenal.best_available")
            add("scouting.cold_zone")
            add(situation.countCode)
            add("build.${pitcherBuildIdentity(pitcher)}")
            addAll(situation.extraReasonCodes)
        }
        val primaryCall = PitchCall(
            pitchType = primaryPitch,
            zone = primaryZone,
            zoneIntent = ZoneIntentRules.clamp(situation.zoneIntent(protectZone, twoStrikes), primaryZone),
            intensity = if (situation.demandsControl || protectZone || primaryProfile?.role == PitchUsageRole.DEVELOPMENT) {
                PitchIntensity.CONTROLLED
            } else PitchIntensity.NORMAL,
        )
        val primary = PitchRecommendation(
            call = primaryCall,
            confidence = ScoutingEstimate.adjustedConfidence(
                clamp(520 + (pitcher.command - 50) * 4 + ((primaryProfile?.command ?: 50) - 50) * 2 + if (batter.discipline < 50) 45 else 0, 350, 850),
                reliability,
            ),
            reasonCodes = primaryReasons,
            shortReason = recommendationReason(primaryReasons, ""),
        )
        val alternativePitch = if (repetitionAvoided) desired else recommendedAlternativePitch(
            pitcher, primaryPitch, if (scouting.pitchWeakness == PitchKind.FOUR_SEAM) PitchKind.SLIDER else PitchKind.FOUR_SEAM
        )
        val mirrored = PitchZone(2 - scouting.hotZone.row, 2 - scouting.hotZone.column)
        val alternativeZone = if (mirrored == scouting.hotZone) PitchZone(0, 2) else mirrored
        val alternativeCall = PitchCall(
            pitchType = alternativePitch,
            zone = alternativeZone,
            zoneIntent = ZoneIntentRules.clamp(if (protectZone) ZoneIntent.STRIKE else ZoneIntent.EDGE, alternativeZone),
            intensity = if (context.fatigue >= 60) PitchIntensity.CONTROLLED else PitchIntensity.NORMAL,
        )
        val alternative = PitchRecommendation(
            call = alternativeCall,
            confidence = ScoutingEstimate.adjustedConfidence(clamp(430 + (pitcher.stuff - 50) * 3, 300, 760), reliability),
            reasonCodes = listOf("scouting.avoid_hot_zone", "sequence.change_speed", if (protectZone) "count.avoid_walk" else "count.alternative"),
            shortReason = recommendationReason(listOf("scouting.avoid_hot_zone"), ""),
        )
        return primary to alternative
    }

    private fun recommendedPrimaryPitch(
        pitcher: PitcherSnapshot,
        desired: PitchKind,
        twoStrikes: Boolean,
        protectZone: Boolean,
        lastPitchType: PitchKind?,
    ): PitchKind {
        val profiles = pitcher.pitchProfiles ?: return desired
        if (profiles.isEmpty()) return desired
        var best: PitchProfileSnapshot? = null
        var bestScore = Int.MIN_VALUE
        profiles.forEach { profile ->
            var score = profileScore(profile, pitcher)
            if (profile.pitchType == desired) score += 90
            if (profile.role == PitchUsageRole.DEVELOPMENT) score -= 120
            if (lastPitchType != null && profile.pitchType == lastPitchType) score -= 70
            if (twoStrikes) score += profile.whiff - 50
            if (protectZone) score += profile.command - 50
            if (score > bestScore) { bestScore = score; best = profile }
        }
        return best?.pitchType ?: desired
    }

    private fun recommendedAlternativePitch(pitcher: PitcherSnapshot, excluding: PitchKind, legacy: PitchKind): PitchKind {
        val profiles = pitcher.pitchProfiles ?: return legacy
        return profiles.filter { it.pitchType != excluding && it.role != PitchUsageRole.DEVELOPMENT }
            .maxByOrNull { profileScore(it, pitcher) }?.pitchType ?: legacy
    }

    private fun profileScore(profile: PitchProfileSnapshot, pitcher: PitcherSnapshot): Int {
        var score = profile.command + profile.whiff + profile.weakContact
        when (pitcherBuildIdentity(pitcher)) {
            "power" -> {
                if (profile.pitchType == PitchKind.FOUR_SEAM) score += 35 + (pitcher.stuff - 50) * 2
                score += (profile.velocityTenthsKph - 1300) / 12
            }
            "command" -> {
                score += profile.control - 50
                score += (profile.command - 50) * 2
            }
            "movement" -> {
                if (profile.pitchType != PitchKind.FOUR_SEAM) score += 28 + (pitcher.movement - 50) * 2
                score += (profile.movement - 50) * 2
            }
            "stamina" -> {
                score += max(0, 4 - profile.fatigueCost) * 10
                score += profile.control - 50
            }
        }
        return score
    }

    private fun pitcherBuildIdentity(pitcher: PitcherSnapshot): String = when {
        pitcher.stuff >= pitcher.command && pitcher.stuff >= pitcher.movement && pitcher.stuff >= pitcher.stamina -> "power"
        pitcher.command >= pitcher.movement && pitcher.command >= pitcher.stamina -> "command"
        pitcher.movement >= pitcher.stamina -> "movement"
        else -> "stamina"
    }

    private fun recommendationReason(reasonCodes: List<String>, situationNote: String): String {
        var reason = when {
            "rival.pattern_detected" in reasonCodes -> "반복 패턴을 읽고 있어 배합을 바꿉니다."
            "sequence.avoid_repeat" in reasonCodes -> "방금 공과 다른 배합을 요구합니다."
            "scouting.pitch_weakness" in reasonCodes -> "타자의 약점 구종과 코스를 공략합니다."
            else -> "강한 코스를 피해 타이밍을 바꿉니다."
        }
        reason += when {
            "build.power" in reasonCodes -> " 강속구형의 포심·구속 강점을 반영한 사인입니다."
            "build.command" in reasonCodes -> " 정밀 제구형의 코스 반복 정확도를 반영한 사인입니다."
            "build.movement" in reasonCodes -> " 변화구형의 결정구 움직임을 반영한 사인입니다."
            "build.stamina" in reasonCodes -> " 이닝 소화형의 효율 좋은 구종을 반영한 사인입니다."
            else -> ""
        }
        if (situationNote.isNotEmpty()) reason += " $situationNote"
        return reason
    }
}

public class PitchKernel {
    private val recommendationEngine = CatcherRecommendationEngine()
    private val rivalMemoryEngine = RivalMemoryEngine()

    public fun preparePitch(parameters: PreparePitchParams): PitchPreparation {
        val seed = validate(parameters)
        val adaptation = rivalMemoryEngine.analyze(parameters.rivalMemory, parameters.context)
        val plan = commitBatterPlan(parameters, adaptation, seed)
        val reliability = ScoutingEstimate.effectiveReliability(parameters.scouting.reliability, parameters.rivalMemory)
        val estimate = ScoutingEstimate.estimatedScouting(
            parameters.scouting,
            reliability,
            ScoutingEstimate.matchupSeed(parameters.pitcher.id, parameters.batter.id),
        )
        val recommendations = recommendationEngine.recommend(
            parameters.pitcher,
            parameters.batter,
            estimate,
            parameters.context,
            adaptation,
            reliability,
            parameters.gameState,
            parameters.gameLog?.entries?.lastOrNull(),
        )
        val token = preparationToken(parameters, plan.commitment, recommendations.first, recommendations.second)
        return PitchPreparation(
            seed = parameters.seed,
            revision = parameters.context.revision,
            pitchNumber = parameters.context.pitchNumber,
            preparationToken = token,
            planCommitment = plan.commitment,
            primaryRecommendation = recommendations.first,
            alternativeRecommendation = recommendations.second,
            rivalAdaptation = adaptation,
            scoutingReport = ScoutingEstimate.report(estimate, reliability, parameters.rivalMemory?.totalPitchesSeen ?: 0),
        )
    }

    public fun submitPitch(parameters: SubmitPitchParams, delivery: PitchDelivery? = null): PitchKernelResult {
        val prepareParameters = PreparePitchParams(
            seed = parameters.seed,
            pitcher = parameters.pitcher,
            batter = parameters.batter,
            scouting = parameters.scouting,
            context = parameters.context,
            rivalMemory = parameters.rivalMemory,
            gameState = parameters.gameState,
            gameLog = parameters.gameLog,
        )
        val seed = validate(prepareParameters)
        validateCall(parameters.call, parameters.pitcher)
        validateDelivery(delivery)
        val adaptation = rivalMemoryEngine.analyze(parameters.rivalMemory, parameters.context)
        val plan = commitBatterPlan(prepareParameters, adaptation, seed)
        val reliability = ScoutingEstimate.effectiveReliability(parameters.scouting.reliability, parameters.rivalMemory)
        val estimate = ScoutingEstimate.estimatedScouting(
            parameters.scouting,
            reliability,
            ScoutingEstimate.matchupSeed(parameters.pitcher.id, parameters.batter.id),
        )
        val recommendations = recommendationEngine.recommend(
            parameters.pitcher,
            parameters.batter,
            estimate,
            parameters.context,
            adaptation,
            reliability,
            parameters.gameState,
            parameters.gameLog?.entries?.lastOrNull(),
        )
        val expectedToken = preparationToken(prepareParameters, plan.commitment, recommendations.first, recommendations.second)
        if (parameters.preparationToken != expectedToken) {
            throw PitchKernelException("invalid_preparation_token", "pitch preparation token is invalid or stale")
        }
        val execution = executePitch(parameters, delivery, seed)
        val wasInZone = abs(execution.actualX) <= 500 && abs(execution.actualY) <= 500
        val neutral = resolvePitch(parameters, plan, execution, wasInZone, adaptation, seed)
        val currentGame = parameters.gameState ?: GameStateSnapshot.standard()
        val fielding = neutral.battedBall?.let { resolveFielding(it, currentGame, seed, parameters.context.pitchNumber) }
        val outcome = fielding?.finalOutcome ?: neutral.outcome
        val batterSwung = outcome != PitchOutcome.BALL && outcome != PitchOutcome.CALLED_STRIKE
        val selection = selectionQuality(parameters.call, parameters.pitcher, parameters.scouting, parameters.context, adaptation)
        val accepted = parameters.call == recommendations.first.call || parameters.call == recommendations.second.call
        val count = advanceCount(parameters.context, outcome)
        val nextSeed = deriveNextSeed(seed)
        val revision = parameters.context.revision + 1UL
        val fatigue = min(100, parameters.context.fatigue + PitchAbilityRules.fatigueCost(parameters.call.intensity, parameters.pitcher.profile(parameters.call.pitchType)))
        val memory = rivalMemoryEngine.record(
            parameters.rivalMemory,
            parameters.pitcher,
            parameters.batter,
            parameters.context,
            parameters.call,
            outcome,
            count.result != null,
        )
        val steal = resolveSteal(currentGame.runners, currentGame.defense, parameters.context, seed)
        val inning = resolveInning(parameters.context, currentGame, count.result, neutral.battedBall, fielding, steal.runnersAfter, steal.outsRecorded, seed)
        val ended = count.result != null || inning.inningEnded
        val advance = count.result?.let {
            advanceRunners(steal.runnersAfter, outcome, it, currentGame.defense, seed, inning.doublePlayCompleted, neutral.battedBall, fielding, inning.inningEnded)
        }
        val runnersAfter = if (inning.inningEnded) BaserunnerStateSnapshot.EMPTY else advance?.after ?: steal.runnersAfter
        val updatedGame = currentGame.copy(
            runners = runnersAfter,
            runsAllowed = currentGame.runsAllowed + (advance?.runsScored ?: 0),
            inningState = inning.after,
        )
        val updatedLog = recordGameLog(
            parameters.gameLog,
            parameters.gameLog?.gameId ?: "game-${parameters.pitcher.id}",
            parameters.call.pitchType,
            wasInZone,
            batterSwung,
            outcome,
            count.result,
            selection,
            execution.executionQuality,
            neutral.battedBall,
            fielding,
            accepted,
            execution.velocityTenthsKph,
        )
        val nextContext = PlateAppearanceContext(
            plateAppearanceId = parameters.context.plateAppearanceId,
            revision = revision,
            inning = inning.after.inning,
            outs = inning.after.outs,
            balls = if (count.result == null) count.balls else 0,
            strikes = if (count.result == null) count.strikes else 0,
            pitchNumber = if (count.result == null) parameters.context.pitchNumber + 1 else 1,
            scoreDifferential = parameters.context.scoreDifferential,
            leverage = parameters.context.leverage,
            fatigue = fatigue,
        )
        val updatedAdaptation = rivalMemoryEngine.analyze(memory, nextContext)
        val reasons = resolutionReasons(
            outcome,
            wasInZone,
            plan.expectedPitch == parameters.call.pitchType,
            zonesNear(plan.expectedZone, parameters.call.zone),
            selection,
            execution.executionQuality,
            adaptation,
            fielding,
        )
        val snapshot = PitchSnapshot(
            revision = revision,
            balls = count.balls,
            strikes = count.strikes,
            pitchNumber = parameters.context.pitchNumber,
            ended = ended,
            result = count.result,
            outcome = outcome,
            selectionQuality = selection,
            recommendationAccepted = accepted,
            fatigueAfterPitch = fatigue,
            execution = execution,
            trajectoryPresentation = TrajectoryPresentationSnapshot(
                pitchType = parameters.call.pitchType,
                presentationSeed = nextSeed,
                flightDurationMilliseconds = execution.flightTimeMilliseconds,
                plateXMm = execution.actualX,
                plateYMm = execution.actualY,
                velocityTenthsKph = execution.velocityTenthsKph,
                trajectorySeries = execution.trajectorySeries,
            ),
            battedBall = neutral.battedBall,
            fieldingResolution = fielding,
            runnersBefore = currentGame.runners,
            runnersAfter = updatedGame.runners,
            runsScored = advance?.runsScored ?: 0,
            stealAttempt = steal.attempt,
            inningTransition = inning,
            reasonCodes = reasons,
        )
        val deliveryComponent = if (delivery != null) "|delivery:${delivery.releaseAccuracy}:${delivery.aimAccuracy}" else ""
        val eventHash = Hashing.fnv1a64Hex(
            listOf(
                parameters.seed,
                plan.commitment,
                canonical(parameters.call) + deliveryComponent,
                canonical(parameters.pitcher.profile(parameters.call.pitchType)),
                execution.targetX.toString(),
                execution.targetY.toString(),
                execution.actualX.toString(),
                execution.actualY.toString(),
                execution.velocityTenthsKph.toString(),
                outcome.wire,
                count.balls.toString(),
                count.strikes.toString(),
                count.result?.wire ?: "active",
                canonical(memory),
                updatedAdaptation.level.toString(),
                canonical(updatedGame),
                canonical(updatedLog),
                nextSeed,
            ).joinToString("|"),
        )
        val events = buildList {
            add(PitchKernelEvent("batter_plan_committed", size))
            add(PitchKernelEvent("catcher_recommendations_generated", size))
            add(PitchKernelEvent("pitch_call_committed", size))
            add(PitchKernelEvent("pitch_executed", size))
            add(PitchKernelEvent("pitch_resolved", size))
            if (steal.attempt != null) add(PitchKernelEvent("steal_attempt_resolved", size))
            if (neutral.battedBall != null) add(PitchKernelEvent("batted_ball_created", size))
            if (fielding != null) add(PitchKernelEvent("fielding_resolved", size))
            add(PitchKernelEvent("rival_memory_updated", size))
            if (count.result != null) {
                if (advance != null) add(PitchKernelEvent("baserunners_advanced", size))
                add(PitchKernelEvent("plate_appearance_ended", size))
            }
            if (inning.outsRecorded > 0 || inning.inningEnded) add(
                PitchKernelEvent(if (inning.inningEnded) "half_inning_ended" else "outs_recorded", size)
            )
            add(PitchKernelEvent("game_analysis_updated", size))
        }
        val nextPreparation = if (!ended) preparePitch(
            PreparePitchParams(
                nextSeed,
                parameters.pitcher,
                parameters.batter,
                parameters.scouting,
                nextContext,
                memory,
                updatedGame,
                updatedLog,
            )
        ) else null
        return PitchKernelResult(
            revision = revision,
            nextSeed = nextSeed,
            snapshot = snapshot,
            nextPreparation = nextPreparation,
            rivalMemory = memory,
            rivalAdaptation = updatedAdaptation,
            gameState = updatedGame,
            gameLog = updatedLog,
            eventHash = eventHash,
            events = events,
            abilityMoment = PitchAbilityRules.moment(outcome, execution, PitchAbilityRules.readout(parameters.pitcher, parameters.call, parameters.context)),
        )
    }

    public companion object {
        public fun executionBand(quality: Int): String = when {
            quality >= 850 -> "정확히 꽂혔습니다"
            quality >= 700 -> "거의 붙었습니다"
            quality >= 520 -> "조금 벗어났습니다"
            quality >= 350 -> "많이 벗어났습니다"
            else -> "손에서 빠졌습니다"
        }

        public fun pullShift(batSide: BatSide, column: Int): Int {
            val direction = if (batSide == BatSide.LEFT) 1 else -1
            return (1 - column) * 90 * direction
        }

        public fun battedQuality(exitVelocity: Int, launchAngle: Int): Int {
            val fit = if (launchAngle < 90) 30 + max(0, launchAngle + 150) / 5 else max(0, 240 - abs(launchAngle - 170) * 7 / 10 - if (launchAngle > 340) launchAngle - 340 else 0)
            val baseQuality = max(0, min(758, exitVelocity * 7 / 10 + fit - 600))
            if (exitVelocity < 1470 || launchAngle < 170 || launchAngle > 340) return baseQuality
            return max(700, min(940, 765 + (exitVelocity - 1470) / 3 + (90 - abs(launchAngle - 250)) / 3))
        }
    }

    public data class PreparePitchParams(
        val seed: String,
        val pitcher: PitcherSnapshot,
        val batter: BatterSnapshot,
        val scouting: BatterScoutingSnapshot,
        val context: PlateAppearanceContext,
        val rivalMemory: RivalMemorySnapshot? = null,
        val gameState: GameStateSnapshot? = null,
        val gameLog: GameLogSnapshot? = null,
    )

    public data class PrepareRequest(
        val seed: String,
        val pitcher: PitcherSnapshot,
        val batter: BatterSnapshot,
        val scouting: BatterScoutingSnapshot,
        val context: PlateAppearanceContext,
        val rivalMemory: RivalMemorySnapshot? = null,
        val gameState: GameStateSnapshot? = null,
        val gameLog: GameLogSnapshot? = null,
    )

    public data class SubmitRequest(
        val seed: String,
        val pitcher: PitcherSnapshot,
        val batter: BatterSnapshot,
        val scouting: BatterScoutingSnapshot,
        val context: PlateAppearanceContext,
        val preparationToken: String,
        val call: PitchCall,
        val rivalMemory: RivalMemorySnapshot? = null,
        val gameState: GameStateSnapshot? = null,
        val gameLog: GameLogSnapshot? = null,
    )

    public fun prepare(request: PrepareRequest): PitchPreparation = preparePitch(
        PreparePitchParams(request.seed, request.pitcher, request.batter, request.scouting, request.context, request.rivalMemory, request.gameState, request.gameLog)
    )

    public fun submit(request: SubmitRequest, delivery: PitchDelivery? = null): PitchKernelResult = submitPitch(
        SubmitPitchParams(request.seed, request.pitcher, request.batter, request.scouting, request.context, request.preparationToken, request.call, request.rivalMemory, request.gameState, request.gameLog),
        delivery,
    )

    private data class BatterPlan(
        val expectedPitch: PitchKind,
        val expectedZone: PitchZone,
        val approach: BatterApproach,
        val bias: SituationalBias,
        val commitment: String,
    )

    private data class SituationalBias(val zoneSwing: Int, val chase: Int, val contact: Int, val foul: Int, val note: String)
    private enum class BatterApproach { PATIENT, AGGRESSIVE, PROTECT, POWER }
    private data class Resolution(val outcome: PitchOutcome, val battedBall: BattedBall?)
    private data class CountAdvance(val balls: Int, val strikes: Int, val result: PlateAppearanceResult?)
    private data class StealResolution(val attempt: StealAttemptSnapshot?, val runnersAfter: BaserunnerStateSnapshot, val outsRecorded: Int)
    private data class Flight(val distanceTenthsMeters: Int, val hangMilliseconds: Int, val apexTenthsMeters: Int)

    private fun validate(parameters: PreparePitchParams): ULong {
        if (!parameters.seed.matches(Regex("[0-9]+"))) throw PitchKernelException("invalid_seed", "seed must be an unsigned 64-bit integer")
        val seed = runCatching { parameters.seed.toULong() }.getOrElse {
            throw PitchKernelException("invalid_seed", "seed must be an unsigned 64-bit integer")
        }
        val ratings = listOf(
            parameters.pitcher.stuff, parameters.pitcher.command, parameters.pitcher.movement, parameters.pitcher.stamina,
            parameters.batter.contact, parameters.batter.discipline, parameters.batter.power,
        )
        if (ratings.any { it !in 20..80 }) throw PitchKernelException("invalid_rating", "ratings must be between 20 and 80")
        parameters.pitcher.pitchProfiles?.let { profiles ->
            if (profiles.isEmpty() || profiles.map { it.pitchType }.toSet().size != profiles.size) {
                throw PitchKernelException("invalid_pitch_profile", "pitch profiles must be non-empty and unique")
            }
            profiles.forEach { profile ->
                if (listOf(profile.control, profile.command, profile.movement, profile.whiff, profile.weakContact).any { it !in 20..80 } ||
                    profile.velocityTenthsKph !in 1000..1700 || profile.fatigueCost !in 0..3
                ) throw PitchKernelException("invalid_pitch_profile", "pitch profile is outside the valid range")
            }
        }
        if (!validZone(parameters.scouting.hotZone) || !validZone(parameters.scouting.coldZone) ||
            parameters.scouting.chaseTendency !in 20..80 || parameters.scouting.reliability !in 0..100
        ) throw PitchKernelException("invalid_scouting", "scouting is outside the valid range")
        rivalMemoryEngine.validate(parameters.rivalMemory, parameters.pitcher, parameters.batter)
        validateLog(parameters.gameLog)
        val context = parameters.context
        if (context.plateAppearanceId.isEmpty() || context.inning !in 1..20 || context.outs !in 0..2 ||
            context.balls !in 0..3 || context.strikes !in 0..2 || context.pitchNumber < 1 ||
            context.leverage !in 0..1000 || context.fatigue !in 0..100
        ) throw PitchKernelException("invalid_plate_appearance", "plate appearance is outside the valid range")
        return seed
    }

    private fun validateLog(log: GameLogSnapshot?) {
        if (log != null && (log.gameId.isEmpty() || log.totalPitches < log.entries.size || log.entries.size > 120)) {
            throw PitchKernelException("invalid_game_log", "game log metadata is inconsistent")
        }
    }

    private fun validateCall(call: PitchCall, pitcher: PitcherSnapshot) {
        if (!validZone(call.zone)) throw PitchKernelException("invalid_zone", "zone must be in the 3x3 grid")
        if (pitcher.pitchProfiles != null && pitcher.profile(call.pitchType) == null) {
            throw PitchKernelException("invalid_pitch_profile", "pitch is not in the repertoire")
        }
    }

    private fun validateDelivery(delivery: PitchDelivery?) {
        if (delivery != null && (delivery.releaseAccuracy !in 0..1000 || delivery.aimAccuracy !in 0..1000)) {
            throw PitchKernelException("invalid_pitch_delivery", "release and aim accuracy must be between 0 and 1000")
        }
    }

    private fun validZone(zone: PitchZone): Boolean = zone.row in 0..2 && zone.column in 0..2

    private fun commitBatterPlan(parameters: PreparePitchParams, adaptation: RivalAdaptationSnapshot, seed: ULong): BatterPlan {
        val generator = SplitMix64(derivedSeed(seed, 0x504C414EUL, parameters.context.pitchNumber))
        val baseWeights = listOf(
            PitchKind.FOUR_SEAM to 340,
            PitchKind.SLIDER to 260,
            PitchKind.CHANGEUP to 200,
            PitchKind.CURVEBALL to 200,
        )
        val weights = baseWeights.map { (pitch, weight) ->
            pitch to (weight + if (pitch == adaptation.leanPitch) adaptation.pitchReadStrength * 2 else 0)
        }
        var roll = generator.nextInt(weights.sumOf { it.second })
        var expectedPitch = PitchKind.FOUR_SEAM
        for ((pitch, weight) in weights) {
            if (roll < weight) { expectedPitch = pitch; break }
            roll -= weight
        }
        val expectedZone = if (adaptation.zoneReadStrength > 0 && generator.nextInt(100) < min(60, 12 + adaptation.zoneReadStrength / 6)) {
            adaptation.leanZone
        } else if (generator.nextInt(100) < 45) {
            parameters.scouting.hotZone
        } else PitchZone(generator.nextInt(3), generator.nextInt(3))
        val approach = when {
            parameters.context.strikes == 2 -> BatterApproach.PROTECT
            parameters.context.balls == 3 -> BatterApproach.PATIENT
            else -> if (generator.nextInt(100) < 55) BatterApproach.AGGRESSIVE else BatterApproach.POWER
        }
        val bias = situationalBiasFor(
            parameters.context,
            parameters.gameState?.runners ?: BaserunnerStateSnapshot.EMPTY,
            parameters.batter.discipline,
        )
        val commitment = Hashing.fnv1a64Hex(
            listOf(
                parameters.context.plateAppearanceId,
                parameters.context.pitchNumber.toString(),
                expectedPitch.wire,
                expectedZone.row.toString(),
                expectedZone.column.toString(),
                approachValue(approach),
                bias.zoneSwing.toString(),
                bias.chase.toString(),
                bias.contact.toString(),
                bias.foul.toString(),
                generator.next().toString(),
            ).joinToString("|"),
        )
        return BatterPlan(expectedPitch, expectedZone, approach, bias, commitment)
    }

    private fun situationalBiasFor(context: PlateAppearanceContext, runners: BaserunnerStateSnapshot, discipline: Int): SituationalBias {
        val scoring = runners.secondOccupied || runners.thirdOccupied
        val driveIn = scoring && context.outs < 2
        val patient = runners.occupiedCount == 0 && context.leverage < 400
        var zone = 0
        var chase = 0
        var contact = 0
        var foul = 0
        if (driveIn) { zone += 40; chase += 20; contact += 25; foul += 35 }
        if (patient) { zone -= 30; chase -= 40 }
        if (context.strikes == 2) { foul += 100; contact -= 45 }
        else if (context.balls >= 3 || (context.balls == 2 && context.strikes == 0)) { zone += 35; contact += 55; foul -= 25 }
        chase -= (discipline - 50) * max(0, context.leverage - 500) / 250
        val note = when {
            context.strikes == 2 -> "몰린 타자가 배트를 짧게 잡습니다 — 커트를 노립니다."
            context.balls >= 3 -> "앞선 카운트라 타자가 스트라이크를 노리고 들어옵니다."
            driveIn -> "득점권이라 타자가 컨택 위주로 적극적입니다."
            patient -> "주자가 없어 타자가 공을 신중히 고릅니다."
            context.leverage >= 750 -> "중요한 승부라 타자의 집중력이 올라갑니다."
            else -> ""
        }
        return SituationalBias(zone, chase, contact, foul, note)
    }

    private fun preparationToken(parameters: PreparePitchParams, planCommitment: String, primary: PitchRecommendation, alternative: PitchRecommendation): String =
        Hashing.fnv1a64Hex(
            listOf(
                "pitch-preparation-v1",
                parameters.seed,
                parameters.context.plateAppearanceId,
                parameters.context.revision.toString(),
                parameters.context.pitchNumber.toString(),
                parameters.context.balls.toString(),
                parameters.context.strikes.toString(),
                canonical(parameters.pitcher),
                canonical(parameters.rivalMemory),
                canonical(parameters.gameState),
                canonical(parameters.gameLog),
                planCommitment,
                canonical(primary.call),
                canonical(alternative.call),
            ).joinToString("|"),
        )

    private fun executePitch(parameters: SubmitPitchParams, delivery: PitchDelivery?, seed: ULong): PitchExecution {
        val generator = SplitMix64(derivedSeed(seed, 0x45584543UL, parameters.context.pitchNumber))
        val target = targetCoordinates(parameters.call)
        val effect = PitchAbilityRules.intensity(parameters.call.intensity)
        val profile = parameters.pitcher.profile(parameters.call.pitchType)
        val command = PitchAbilityRules.commandRating(parameters.pitcher, profile)
        val fatiguePressure = PitchAbilityRules.effectiveFatigue(parameters.context.fatigue, parameters.pitcher.stamina)
        val effective = clamp(command * 10 - fatiguePressure * 2 - effect.commandPenalty, 100, 900)
        val spread = clamp(520 - effective / 2, 70, 470)
        var offsetX = generator.nextInt(spread * 2 + 1) - spread
        var offsetY = generator.nextInt(spread * 2 + 1) - spread
        val wildChance = clamp(
            8 + fatiguePressure / 10 + (if (parameters.call.intensity == PitchIntensity.MAX_EFFORT) 2 else 0) -
                (command - 50) / 4,
            3,
            20,
        )
        if (generator.nextInt(100) < wildChance) {
            val wild = 240 + generator.nextInt(321)
            if (generator.nextInt(2) == 0) offsetX += if (generator.nextInt(2) == 0) -wild else wild
            else offsetY += if (generator.nextInt(2) == 0) -wild else wild
        }
        val aimShift = (delivery?.aimAccuracy ?: 500) - 500
        val releaseShift = (delivery?.releaseAccuracy ?: 500) - 500
        val aimScale = 1000 - if (aimShift >= 0) aimShift * 240 / 500 else aimShift * 340 / 500
        offsetX = offsetX * aimScale / 1000
        offsetY = offsetY * aimScale / 1000
        val releaseBonus = if (releaseShift >= 0) releaseShift * 120 / 500 else releaseShift * 200 / 500
        val quality = clamp(1000 - abs(offsetX) - abs(offsetY) + effective / 5 + releaseBonus + if (delivery?.isPerfectRelease == true) 90 else 0, 0, 1000)
        var horizontal: Int
        var vertical: Int
        when (parameters.call.pitchType) {
            PitchKind.FOUR_SEAM -> { horizontal = 70; vertical = 160 }
            PitchKind.SLIDER -> { horizontal = -145; vertical = 35 }
            PitchKind.CURVEBALL -> { horizontal = -65; vertical = -185 }
            PitchKind.CHANGEUP -> { horizontal = 105; vertical = -45 }
        }
        val rawVelocity = PitchAbilityRules.nominalVelocity(parameters.pitcher, parameters.call.pitchType, parameters.call.intensity, parameters.context.fatigue) +
            generator.nextInt(21) - 10 + releaseShift * 10 / 500 + if (delivery?.isPerfectRelease == true) 6 else 0
        val velocity = min(PitchAbilityRules.MAXIMUM_EXECUTED_VELOCITY_TENTHS_KPH, rawVelocity)
        val movementScale = (profile?.movement ?: parameters.pitcher.movement) - 50
        val actualX = target.first + offsetX
        val actualY = target.second + offsetY
        horizontal += movementScale * 2
        vertical += movementScale * 2
        val releaseSpeed = velocity / 36.0
        val drag = 0.0053
        val seconds = (exp(drag * 18.44) - 1.0) / (drag * releaseSpeed)
        val flightMs = clamp(roundAway(seconds * 1000.0), 330, 620)
        val plateLateral = actualX * 432.0 / 500.0 / 1000.0
        val plateHeight = (750.0 + actualY * 250.0 / 500.0) / 1000.0
        val duration = flightMs / 1000.0
        val horizontalMeters = horizontal / 1000.0
        val verticalMeters = vertical / 1000.0
        val initialLateral = (plateLateral - horizontalMeters) / duration
        val initialVertical = (plateHeight - verticalMeters - 1.85 + 0.5 * 9.81 * duration * duration) / duration
        val trajectory = ArrayList<Int>(100)
        for (index in 0..24) {
            val progress = index / 24.0
            val elapsed = duration * progress
            val travelled = kotlin.math.ln(1.0 + drag * releaseSpeed * elapsed) / (drag * 18.44)
            val magnus = progress * progress
            val lateral = initialLateral * elapsed + horizontalMeters * magnus
            val height = 1.85 + initialVertical * elapsed - 0.5 * 9.81 * elapsed * elapsed + verticalMeters * magnus
            val remainingDistance = if (index == 24) 0 else roundAway(18440.0 * (1.0 - travelled))
            trajectory += flightMs * index / 24
            trajectory += roundAway(lateral * 1000.0)
            trajectory += remainingDistance
            trajectory += roundAway(height * 1000.0)
        }
        val controlOffset = 60
        val controlX = roundAway(trajectory[controlOffset + 1] * 500.0 / 432.0)
        val controlY = roundAway((trajectory[controlOffset + 3] - 750.0) * 500.0 / 250.0)
        return PitchExecution(target.first, target.second, actualX, actualY, velocity, horizontal, vertical, quality, flightMs, controlX, controlY, trajectory)
    }

    private fun resolvePitch(
        parameters: SubmitPitchParams,
        plan: BatterPlan,
        execution: PitchExecution,
        wasInZone: Boolean,
        adaptation: RivalAdaptationSnapshot,
        seed: ULong,
    ): Resolution {
        val generator = SplitMix64(derivedSeed(seed, 0x5245534FUL, parameters.context.pitchNumber))
        val pitchMatched = plan.expectedPitch == parameters.call.pitchType
        val zoneMatched = zonesNear(plan.expectedZone, parameters.call.zone)
        val landed = PitchZone(
            row = if (execution.actualY >= 165) 0 else if (execution.actualY <= -165) 2 else 1,
            column = if (execution.actualX <= -165) 0 else if (execution.actualX >= 165) 2 else 1,
        )
        val weakness = parameters.call.pitchType == parameters.scouting.pitchWeakness
        val strength = parameters.call.pitchType == parameters.scouting.pitchStrength
        val cold = wasInZone && landed == parameters.scouting.coldZone
        val hot = wasInZone && landed == parameters.scouting.hotZone
        val hasRunner = parameters.gameState?.runners?.occupiedCount?.let { it > 0 } ?: false
        val scoutingContact = (if (weakness) -30 else 0) + (if (strength) 26 else 0) + (if (cold) -22 else 0) + (if (hot) 24 else 0)
        val scoutingQuality = (if (weakness) -36 else 0) + (if (strength) 32 else 0) + (if (cold) -28 else 0) + (if (hot) 29 else 0)
        val capped = min(420, adaptation.level)
        val recognition = (if (pitchMatched) 95 else -65) + (if (zoneMatched) 70 else -35) +
            (if (pitchMatched) capped / 6 else 0) + (if (zoneMatched) capped / 10 else 0)
        val approachSwing = when (plan.approach) {
            BatterApproach.PATIENT -> -150
            BatterApproach.AGGRESSIVE -> 120
            BatterApproach.PROTECT -> 80
            BatterApproach.POWER -> 35
        }
        val swingChance = clamp(
            (if (wasInZone) 640 else 110) + parameters.scouting.chaseTendency * (if (wasInZone) 1 else 4) -
                parameters.batter.discipline * 2 + recognition + approachSwing + if (wasInZone) plan.bias.zoneSwing else plan.bias.chase,
            25,
            960,
        )
        if (generator.nextInt(1000) >= swingChance) {
            if (!wasInZone && isHitByPitch(parameters.call, execution, parameters.pitcher.throwingHand, parameters.batter.batSide, generator)) {
                return Resolution(PitchOutcome.HIT_BY_PITCH, null)
            }
            return Resolution(if (wasInZone) PitchOutcome.CALLED_STRIKE else PitchOutcome.BALL, null)
        }
        val profile = parameters.pitcher.profile(parameters.call.pitchType)
        val powerEdge = max(
            0,
            parameters.pitcher.stuff - max(parameters.pitcher.command, max(parameters.pitcher.movement, parameters.pitcher.stamina)),
        )
        val fullPowerSpecialization = min(120, powerEdge * 30)
        val powerSpecialization = if (parameters.call.pitchType == PitchKind.FOUR_SEAM) fullPowerSpecialization else 0
        val difficulty = if (profile == null) {
            (parameters.pitcher.stuff - 50) * 7 + (parameters.pitcher.movement - 50) * 6 +
                powerSpecialization + 30 + max(0, execution.executionQuality - 500) / 3
        } else {
            (parameters.pitcher.stuff - 50) * 5 + (profile.whiff - 50) * 4 +
                (parameters.pitcher.movement - 50) * 3 + (profile.movement - 50) * 3 +
                powerSpecialization + 30 + max(0, execution.executionQuality - 500) / 3
        }
        val velocityEdge = clamp((execution.velocityTenthsKph - 1370) / 2, -80, 180)
        val speedGap = if (parameters.context.pitchNumber > 1 && parameters.gameLog?.entries?.lastOrNull()?.velocityTenthsKph != null) {
            min(70, max(0, abs(execution.velocityTenthsKph - parameters.gameLog.entries.last().velocityTenthsKph!!) - 80) / 3)
        } else 0
        val fastball = parameters.call.pitchType == PitchKind.FOUR_SEAM
        val heightMatch = if (fastball && landed.row == 0) 55 else if (fastball && landed.row == 2) -30 else if (!fastball && landed.row == 2) 50 else if (!fastball && landed.row == 0) -55 else 0
        val platoon = platoonContactBonus(parameters.pitcher.throwingHand, parameters.batter.batSide, parameters.call.pitchType)
        val contactChance = clamp(
            790 + (parameters.batter.contact - 50) * 6 + (if (pitchMatched) 90 else -70) + (if (zoneMatched) 50 else -35) +
                (if (pitchMatched) capped / 5 else 0) + plan.bias.contact + platoon + scoutingContact -
                (difficulty + velocityEdge + speedGap + heightMatch),
            120,
            940,
        )
        if (generator.nextInt(1000) >= contactChance) return Resolution(PitchOutcome.SWINGING_STRIKE, null)
        val foulChance = clamp(470 + ((profile?.movement ?: parameters.pitcher.movement) - parameters.batter.contact) * 3 + plan.bias.foul, 260, 620)
        if (generator.nextInt(1000) < foulChance) return Resolution(PitchOutcome.FOUL, null)
        val contactQuality = clamp(
            429 + (parameters.batter.power - 50) * 3 + (parameters.batter.contact - 50) * 2 + (if (pitchMatched) 90 else -70) +
                (if (zoneMatched) 45 else -35) + (if (pitchMatched) capped / 8 else 0) -
                ((profile?.weakContact ?: 50) - 50) * 2 - (parameters.pitcher.movement - 50) -
                ((profile?.movement ?: parameters.pitcher.movement) - 50) - powerSpecialization / 2 -
                max(0, execution.executionQuality - 500) / 5 + scoutingQuality -
                max(0, execution.velocityTenthsKph - 1400) / 5 - heightMatch / 2 + generator.nextInt(301) - 150,
            0,
            1000,
        )
        val pull = pullShift(parameters.batter.batSide, landed.column)
        val exitVelocity = clamp(1000 + contactQuality * 3 / 4 + (parameters.batter.power - 50) * 6 + generator.nextInt(181) - 90, 700, 1900)
        val launchAngle = clamp(-100 + generator.nextInt(521) + (contactQuality - 450) / 8 + (1 - landed.row) * 55, -150, 520)
        val quality = battedQuality(exitVelocity, launchAngle)
        return Resolution(
            BattedBallBands.outcome(quality),
            BattedBall(exitVelocity, launchAngle, -450 + max(0, pull) + generator.nextInt(901 - abs(pull)), quality),
        )
    }

    private fun isHitByPitch(call: PitchCall, execution: PitchExecution, hand: ThrowingHand, batSide: BatSide, generator: SplitMix64): Boolean {
        val batsLeft = batsLeft(batSide, hand)
        val insideMiss = if (batsLeft) execution.actualX else -execution.actualX
        if (insideMiss < 1000) return false
        val calledInside = if (batsLeft) call.zone.column == 2 else call.zone.column == 0
        return generator.nextInt(1000) < 120 + if (calledInside) 60 else 0
    }

    private fun batsLeft(batSide: BatSide, hand: ThrowingHand): Boolean =
        batSide == BatSide.LEFT || (batSide == BatSide.SWITCH && hand == ThrowingHand.RIGHT)

    private fun platoonContactBonus(hand: ThrowingHand, batSide: BatSide, type: PitchKind): Int {
        val sameHand = batsLeft(batSide, hand) == (hand == ThrowingHand.LEFT)
        if (sameHand) return 0
        return when (type) {
            PitchKind.SLIDER, PitchKind.CURVEBALL -> 42
            PitchKind.FOUR_SEAM -> 24
            PitchKind.CHANGEUP -> 14
        }
    }

    private fun advanceCount(context: PlateAppearanceContext, outcome: PitchOutcome): CountAdvance = when (outcome) {
        PitchOutcome.BALL -> if (context.balls == 3) CountAdvance(3, context.strikes, PlateAppearanceResult.WALK) else CountAdvance(context.balls + 1, context.strikes, null)
        PitchOutcome.CALLED_STRIKE, PitchOutcome.SWINGING_STRIKE -> if (context.strikes == 2) CountAdvance(context.balls, 2, PlateAppearanceResult.STRIKEOUT) else CountAdvance(context.balls, context.strikes + 1, null)
        PitchOutcome.FOUL -> CountAdvance(context.balls, min(2, context.strikes + 1), null)
        PitchOutcome.IN_PLAY_OUT -> CountAdvance(context.balls, context.strikes, PlateAppearanceResult.IN_PLAY_OUT)
        PitchOutcome.SINGLE, PitchOutcome.DOUBLE, PitchOutcome.TRIPLE, PitchOutcome.HOME_RUN -> CountAdvance(context.balls, context.strikes, PlateAppearanceResult.HIT)
        PitchOutcome.HIT_BY_PITCH -> CountAdvance(context.balls, context.strikes, PlateAppearanceResult.WALK)
    }

    private fun selectionQuality(
        call: PitchCall,
        pitcher: PitcherSnapshot,
        scouting: BatterScoutingSnapshot,
        context: PlateAppearanceContext,
        adaptation: RivalAdaptationSnapshot,
    ): SelectionQuality {
        var score = 500 + (if (call.pitchType == scouting.pitchWeakness) 170 else 0) - (if (call.pitchType == scouting.pitchStrength) 190 else 0) +
            (if (call.zone == scouting.coldZone) 130 else 0) - (if (call.zone == scouting.hotZone) 170 else 0) +
            (if (context.strikes == 2 && call.zoneIntent == ZoneIntent.CHASE) 90 else 0) -
            (if (context.balls == 3 && call.zoneIntent == ZoneIntent.CHASE) 260 else 0) +
            (if (context.fatigue >= 60 && call.intensity == PitchIntensity.MAX_EFFORT) 140 else 0) +
            (if (call.zoneIntent == ZoneIntent.EDGE) 35 else 0)
        pitcher.profile(call.pitchType)?.let { profile ->
            score += if (profile.role == PitchUsageRole.PRIMARY) 45 else if (profile.role == PitchUsageRole.DEVELOPMENT) -120 else 0
            if (call.zoneIntent == ZoneIntent.EDGE) score += (profile.command - 50) * 3
            if (call.zoneIntent == ZoneIntent.CHASE) score += (profile.whiff - 50) * 2
        }
        if (adaptation.detectedPitch == call.pitchType) score -= adaptation.level / 3
        if (adaptation.detectedZone == call.zone) score -= adaptation.level / 5
        return when {
            score < 340 -> SelectionQuality.POOR
            score < 540 -> SelectionQuality.RISKY
            score < 740 -> SelectionQuality.GOOD
            else -> SelectionQuality.EXCELLENT
        }
    }

    private fun targetCoordinates(call: PitchCall): Pair<Int, Int> {
        var x = (call.zone.column - 1) * 330
        var y = (1 - call.zone.row) * 330
        when (call.zoneIntent) {
            ZoneIntent.STRIKE -> { x = x * 7 / 10; y = y * 7 / 10 }
            ZoneIntent.CHASE -> {
                if (abs(x) >= abs(y) && x != 0) x = if (x > 0) 650 else -650
                else if (y != 0) y = if (y > 0) 650 else -650
                else y = -650
            }
            ZoneIntent.EDGE -> Unit
        }
        return x to y
    }

    private fun resolveFielding(ball: BattedBall, gameState: GameStateSnapshot, seed: ULong, ordinal: Int): FieldingResolutionSnapshot {
        val neutral = BattedBallBands.outcome(ball.contactQuality)
        val flight = flight(ball)
        val sector = when {
            ball.launchAngleTenthsDegrees < 90 -> FieldingSector.INFIELD
            neutral == PitchOutcome.HOME_RUN || (ball.contactQuality >= 700 && ball.launchAngleTenthsDegrees in 150..350) -> FieldingSector.FENCE
            flight.distanceTenthsMeters < 500 -> FieldingSector.INFIELD
            else -> FieldingSector.OUTFIELD
        }
        val position = position(sector, ball.directionTenthsDegrees)
        val fielder = gameState.defense.fielder(position)
        val aggregate = if (sector == FieldingSector.INFIELD) gameState.defense.infield else gameState.defense.outfield
        val defenseRating = fielder?.let { (it.range * 6 + it.glove * 4) / 10 } ?: aggregate
        val defenseAdjustment = -(defenseRating - 50) * if (sector == FieldingSector.FENCE) 1 else 4
        val hitAdjustment = (gameState.park.hitFactor - 1000) / 3
        val homeRunAdjustment = if (neutral == PitchOutcome.HOME_RUN || ball.contactQuality >= 720) (gameState.park.homeRunFactor - 1000) / 2 else 0
        val parkAdjustment = hitAdjustment + homeRunAdjustment
        val generator = SplitMix64(seed xor 0x4649454C44UL xor (ordinal.toULong() * 0x9E3779B9UL))
        val randomRange = if (sector == FieldingSector.FENCE) 81 else 241
        val randomAdjustment = generator.nextInt(randomRange) - randomRange / 2
        val adjusted = clamp(ball.contactQuality + defenseAdjustment + parkAdjustment + randomAdjustment, 0, 1000)
        var final = BattedBallBands.outcome(adjusted)
        if (sector == FieldingSector.INFIELD && (final == PitchOutcome.DOUBLE || final == PitchOutcome.HOME_RUN)) final = PitchOutcome.SINGLE
        else if (sector == FieldingSector.OUTFIELD && final == PitchOutcome.HOME_RUN) final = PitchOutcome.DOUBLE
        if (final == PitchOutcome.DOUBLE && sector != FieldingSector.INFIELD && isTripleShape(ball) && generator.nextInt(1000) < 245) final = PitchOutcome.TRIPLE
        val impact = when {
            outcomeValue(final) < outcomeValue(neutral) -> DefenseImpact.HELPED_PITCHER
            outcomeValue(final) > outcomeValue(neutral) -> DefenseImpact.HURT_PITCHER
            else -> DefenseImpact.NEUTRAL
        }
        return FieldingResolutionSnapshot(
            neutralOutcome = neutral,
            finalOutcome = final,
            sector = sector,
            difficulty = clamp(1000 - ball.contactQuality + abs(randomAdjustment), 0, 1000),
            defenseRating = defenseRating,
            defenseAdjustment = defenseAdjustment,
            parkAdjustment = parkAdjustment,
            impact = impact,
            fielderPosition = position,
            fielderName = fielder?.name,
            landingDistanceTenthsMeters = sectorDistance(flight.distanceTenthsMeters, sector),
            hangTimeMilliseconds = flight.hangMilliseconds,
            apexHeightTenthsMeters = flight.apexTenthsMeters,
            ballFlightSeries = null,
            shortExplanation = "타구 강도에 걸맞은 결과가 나왔습니다.",
        )
    }

    private fun flight(ball: BattedBall): Flight {
        val speed = ball.exitVelocityTenthsKph / 36.0
        val degrees = ball.launchAngleTenthsDegrees / 10.0
        val radians = max(-8.0, min(48.0, degrees)) * PI / 180.0
        val mass = 0.145
        val radius = 0.0369
        val airDensity = 1.225
        val dragCoefficient = 0.30
        val step = 0.005
        val crossSection = PI * radius * radius
        val liftCoefficient = min(0.20, max(0.12, 0.15 + (24.0 - degrees) * 0.0015))
        val drag = 0.5 * airDensity * crossSection * dragCoefficient / mass
        val lift = 0.5 * airDensity * crossSection * liftCoefficient / mass
        var elapsed = 0.0
        var forward = 0.0
        var height = 1.0
        var forwardVelocity = speed * cos(radians)
        var verticalVelocity = speed * sin(radians)
        var apex = height
        while (elapsed < 6.5) {
            val previousHeight = height
            val previousForward = forward
            val magnitude = sqrt(forwardVelocity * forwardVelocity + verticalVelocity * verticalVelocity)
            val forwardAcceleration = -drag * magnitude * forwardVelocity - lift * magnitude * verticalVelocity
            val verticalAcceleration = -9.81 - drag * magnitude * verticalVelocity + lift * magnitude * forwardVelocity
            val nextForwardVelocity = max(0.0, forwardVelocity + forwardAcceleration * step)
            val nextVerticalVelocity = verticalVelocity + verticalAcceleration * step
            val nextForward = forward + (forwardVelocity + nextForwardVelocity) * 0.5 * step
            val nextHeight = height + (verticalVelocity + nextVerticalVelocity) * 0.5 * step
            if (nextHeight <= 0 && elapsed + step > 0.05) {
                val ratio = previousHeight / max(0.000001, previousHeight - nextHeight)
                elapsed += step * ratio
                forward = previousForward + (nextForward - previousForward) * ratio
                break
            }
            elapsed += step
            forward = nextForward
            height = nextHeight
            forwardVelocity = nextForwardVelocity
            verticalVelocity = nextVerticalVelocity
            apex = max(apex, height)
        }
        return Flight(roundAway(max(1.0, forward) * 10.0), roundAway(elapsed * 1000.0), roundAway(apex * 10.0))
    }

    private fun position(sector: FieldingSector, direction: Int): String = if (sector == FieldingSector.INFIELD) {
        when {
            direction < -180 -> "third_base"
            direction < 0 -> "shortstop"
            direction < 180 -> "second_base"
            else -> "first_base"
        }
    } else when {
        direction < -150 -> "left_field"
        direction < 150 -> "center_field"
        else -> "right_field"
    }

    private fun isTripleShape(ball: BattedBall): Boolean = abs(ball.directionTenthsDegrees) >= 250 && ball.launchAngleTenthsDegrees in 120..280

    private fun outcomeValue(outcome: PitchOutcome): Int = when (outcome) {
        PitchOutcome.SINGLE -> 1
        PitchOutcome.DOUBLE -> 2
        PitchOutcome.TRIPLE -> 3
        PitchOutcome.HOME_RUN -> 4
        else -> 0
    }

    private fun sectorDistance(raw: Int, sector: FieldingSector): Int = when (sector) {
        FieldingSector.INFIELD -> clamp(raw, 120, 420)
        FieldingSector.OUTFIELD -> clamp(raw, 480, 1040)
        FieldingSector.FENCE -> clamp(raw, 1050, 1400)
    }

    private fun resolveSteal(runners: BaserunnerStateSnapshot, defense: DefenseSnapshot, context: PlateAppearanceContext, seed: ULong): StealResolution {
        if (context.outs > 1) return StealResolution(null, runners, 0)
        val from: Int
        val to: Int
        if (runners.secondOccupied && !runners.thirdOccupied) { from = 2; to = 3 }
        else if (runners.firstOccupied && !runners.secondOccupied) { from = 1; to = 2 }
        else return StealResolution(null, runners, 0)
        val arm = defense.fielder("catcher")?.arm ?: defense.arm
        val generator = SplitMix64(seed xor 0x535445414CUL xor (context.pitchNumber.toULong() * 0x9E3779B9UL))
        val attemptChance = clamp(55 + (runners.leadRunnerSpeed - 50) * 3 + context.leverage / 20, 20, 260)
        if (generator.nextInt(1000) >= attemptChance) return StealResolution(null, runners, 0)
        val succeeded = generator.nextInt(1000) < clamp(650 + (runners.leadRunnerSpeed - arm) * 7, 280, 900)
        val after = if (from == 1) BaserunnerStateSnapshot(false, succeeded, runners.thirdOccupied, runners.leadRunnerSpeed)
        else BaserunnerStateSnapshot(runners.firstOccupied, false, succeeded, runners.leadRunnerSpeed)
        return StealResolution(StealAttemptSnapshot(from, to, runners.leadRunnerSpeed, arm, succeeded, ""), after, if (succeeded) 0 else 1)
    }

    private fun advanceRunners(
        runners: BaserunnerStateSnapshot,
        outcome: PitchOutcome,
        result: PlateAppearanceResult,
        defense: DefenseSnapshot,
        seed: ULong,
        doublePlayCompleted: Boolean,
        battedBall: BattedBall?,
        fielding: FieldingResolutionSnapshot?,
        inningEnded: Boolean,
    ): BaserunnerAdvanceSnapshot {
        var after = runners
        var runs = 0
        val generator = SplitMix64(seed xor 0x52554E4E4552UL)
        if (result == PlateAppearanceResult.IN_PLAY_OUT) {
            val distance = fielding?.landingDistanceTenthsMeters
            val sacrificeFly = !inningEnded && !doublePlayCompleted && runners.thirdOccupied && battedBall != null &&
                battedBall.launchAngleTenthsDegrees >= 90 && fielding != null &&
                (fielding.sector == FieldingSector.OUTFIELD || fielding.sector == FieldingSector.FENCE) &&
                distance != null && distance >= 620
            if (sacrificeFly) {
                val secondTags = runners.secondOccupied && distance!! >= 900
                after = BaserunnerStateSnapshot(runners.firstOccupied, runners.secondOccupied && !secondTags, secondTags, runners.leadRunnerSpeed)
                runs = 1
            } else if (doublePlayCompleted) {
                after = BaserunnerStateSnapshot(false, runners.secondOccupied, runners.thirdOccupied, runners.leadRunnerSpeed)
            }
        } else if (result == PlateAppearanceResult.WALK) {
            runs = if (runners.firstOccupied && runners.secondOccupied && runners.thirdOccupied) 1 else 0
            after = BaserunnerStateSnapshot(true, runners.secondOccupied || runners.firstOccupied, runners.thirdOccupied || (runners.firstOccupied && runners.secondOccupied), runners.leadRunnerSpeed)
        } else if (result == PlateAppearanceResult.HIT) {
            when (outcome) {
                PitchOutcome.SINGLE -> {
                    val secondScores = runners.secondOccupied && extraBase(runners.leadRunnerSpeed, defense.arm, generator.nextInt(1000), 500)
                    val firstTakesThird = runners.firstOccupied && !runners.secondOccupied && extraBase(runners.leadRunnerSpeed, defense.arm, generator.nextInt(1000), 650)
                    after = BaserunnerStateSnapshot(true, runners.firstOccupied && !firstTakesThird, (runners.secondOccupied && !secondScores) || firstTakesThird, 50)
                    runs = (if (runners.thirdOccupied) 1 else 0) + (if (secondScores) 1 else 0)
                }
                PitchOutcome.DOUBLE -> {
                    val firstScores = runners.firstOccupied && extraBase(runners.leadRunnerSpeed, defense.arm, generator.nextInt(1000), 540)
                    after = BaserunnerStateSnapshot(false, true, runners.firstOccupied && !firstScores, 50)
                    runs = (if (runners.secondOccupied) 1 else 0) + (if (runners.thirdOccupied) 1 else 0) + (if (firstScores) 1 else 0)
                }
                PitchOutcome.TRIPLE -> { after = BaserunnerStateSnapshot(false, false, true, 50); runs = runners.occupiedCount }
                PitchOutcome.HOME_RUN -> { after = BaserunnerStateSnapshot.EMPTY; runs = runners.occupiedCount + 1 }
                else -> Unit
            }
        }
        return BaserunnerAdvanceSnapshot(runners, after, runs, "")
    }

    private fun resolveInning(
        context: PlateAppearanceContext,
        gameState: GameStateSnapshot,
        result: PlateAppearanceResult?,
        battedBall: BattedBall?,
        fielding: FieldingResolutionSnapshot?,
        runners: BaserunnerStateSnapshot,
        stealOuts: Int,
        seed: ULong,
    ): InningTransitionSnapshot {
        val before = gameState.inningState ?: InningStateSnapshot(context.inning, HalfInning.BOTTOM, context.outs)
        val ordinaryOut = result == PlateAppearanceResult.STRIKEOUT || result == PlateAppearanceResult.IN_PLAY_OUT
        var doublePlay = false
        if (result == PlateAppearanceResult.IN_PLAY_OUT && battedBall != null && battedBall.launchAngleTenthsDegrees < 90 &&
            runners.firstOccupied && before.outs + stealOuts <= 1
        ) {
            val chance = clamp(470 + (gameState.defense.infield - 50) * 5 + (gameState.defense.arm - 50) * 3 - max(0, battedBall.contactQuality - 450) / 2, 180, 820)
            doublePlay = SplitMix64(seed xor 0x444F55424C45UL).nextInt(1000) < chance
        }
        val outsRecorded = min(3 - before.outs, stealOuts + (if (ordinaryOut) 1 + if (doublePlay) 1 else 0 else 0))
        val ended = before.outs + outsRecorded >= 3
        val after = if (ended) {
            if (before.half == HalfInning.TOP) InningStateSnapshot(before.inning, HalfInning.BOTTOM, 0)
            else InningStateSnapshot(before.inning + 1, HalfInning.TOP, 0)
        } else InningStateSnapshot(before.inning, before.half, before.outs + outsRecorded)
        return InningTransitionSnapshot(before, after, outsRecorded, doublePlay, ended, "")
    }

    private fun recordGameLog(
        log: GameLogSnapshot?,
        gameId: String,
        pitchType: PitchKind,
        wasInZone: Boolean,
        batterSwung: Boolean,
        outcome: PitchOutcome,
        result: PlateAppearanceResult?,
        quality: SelectionQuality,
        executionQuality: Int,
        battedBall: BattedBall?,
        fielding: FieldingResolutionSnapshot?,
        recommendationAccepted: Boolean,
        velocityTenthsKph: Int?,
    ): GameLogSnapshot {
        val current = log ?: GameLogSnapshot(gameId, 0UL, 0, emptyList())
        val neutralOutcome = fielding?.neutralOutcome ?: outcome
        val entry = PitchAnalysisEntry(
            pitchType, wasInZone, batterSwung, outcome, quality, executionQuality,
            battedBall?.contactQuality,
            damage(neutralOutcome, result),
            damage(outcome, result),
            recommendationAccepted,
            velocityTenthsKph,
        )
        val entries = (current.entries + entry).takeLast(120)
        return current.copy(revision = current.revision + 1UL, totalPitches = current.totalPitches + 1, entries = entries)
    }

    private fun damage(outcome: PitchOutcome, result: PlateAppearanceResult?): Int = when {
        result == PlateAppearanceResult.WALK -> 330
        outcome == PitchOutcome.SINGLE -> 470
        outcome == PitchOutcome.DOUBLE -> 780
        outcome == PitchOutcome.TRIPLE -> 1050
        outcome == PitchOutcome.HOME_RUN -> 1400
        else -> 0
    }

    private fun resolutionReasons(
        outcome: PitchOutcome,
        wasInZone: Boolean,
        pitchMatched: Boolean,
        zoneMatched: Boolean,
        selection: SelectionQuality,
        executionQuality: Int,
        adaptation: RivalAdaptationSnapshot,
        fielding: FieldingResolutionSnapshot?,
    ): List<String> = buildList {
        add("outcome.${outcome.wire}")
        add(if (wasInZone) "abs.in_zone" else "abs.out_of_zone")
        add(if (pitchMatched) "batter_plan.pitch_matched" else "batter_plan.pitch_missed")
        add(if (zoneMatched) "batter_plan.zone_matched" else "batter_plan.zone_missed")
        add("selection.${selection.wire}")
        add(if (executionQuality < 350) "execution.missed_target" else if (executionQuality < 600) "execution.location_vulnerable" else if (executionQuality < 800) "execution.near_target" else "execution.precise")
        if (adaptation.detectedPitch != null || adaptation.detectedZone != null) add("rival.pattern")
        if (fielding != null) add("fielding.impact.${fielding.impact.name.lowercase()}")
    }

    private fun zonesNear(first: PitchZone, second: PitchZone): Boolean = abs(first.row - second.row) + abs(first.column - second.column) <= 1

    private fun deriveNextSeed(seed: ULong): String = (seed + 0x9E3779B97F4A7C15UL).toString()

    private fun derivedSeed(seed: ULong, domain: ULong, ordinal: Int): ULong =
        SplitMix64(seed xor domain xor (ordinal.toULong() * 0x9E3779B9UL)).next()

    private fun canonical(call: PitchCall): String = listOf(call.pitchType.wire, call.zone.row, call.zone.column, call.zoneIntent.wire, call.intensity.wire).joinToString(":")

    private fun canonical(profile: PitchProfileSnapshot?): String = profile?.let {
        listOf(it.pitchType.wire, it.role.wire, it.velocityTenthsKph, it.control, it.command, it.movement, it.whiff, it.weakContact, it.fatigueCost).joinToString(":")
    } ?: "legacy"

    private fun canonical(pitcher: PitcherSnapshot): String {
        val profiles = pitcher.pitchProfiles?.sortedBy { it.pitchType.wire }?.joinToString(",") { canonical(it) } ?: "legacy"
        return listOf(pitcher.id, pitcher.stuff, pitcher.command, pitcher.movement, pitcher.stamina, profiles).joinToString(":")
    }

    private fun canonical(memory: RivalMemorySnapshot?): String {
        if (memory == null) return "no-rival-memory"
        val observations = memory.recentObservations.joinToString(",") {
            listOf(it.pitchType.wire, it.zone.row, it.zone.column, it.zoneIntent.wire, it.balls, it.strikes, it.outcome.wire).joinToString(":")
        }
        return listOf(memory.matchupId, memory.revision, memory.plateAppearancesSeen, memory.totalPitchesSeen, observations).joinToString("|")
    }

    private fun canonical(gameState: GameStateSnapshot?): String {
        if (gameState == null) return "standard-game-state"
        val fielders = gameState.defense.fielders?.sortedBy { it.position }?.joinToString(",") {
            listOf(it.id, it.position, it.range, it.glove, it.arm).joinToString(":")
        } ?: "aggregate-defense"
        val inning = gameState.inningState?.let { listOf(it.inning, if (it.half == HalfInning.TOP) "top" else "bottom", it.outs).joinToString(":") } ?: "context-inning"
        return listOf(
            gameState.defense.infield, gameState.defense.outfield, gameState.defense.arm, fielders,
            gameState.park.id, gameState.park.hitFactor, gameState.park.homeRunFactor,
            if (gameState.runners.firstOccupied) "1" else "0", if (gameState.runners.secondOccupied) "1" else "0",
            if (gameState.runners.thirdOccupied) "1" else "0", gameState.runners.leadRunnerSpeed,
            gameState.runsAllowed, inning,
        ).joinToString(":")
    }

    private fun canonical(log: GameLogSnapshot?): String {
        if (log == null) return "empty-game-log"
        val entries = log.entries.joinToString(",") {
            listOf(
                it.pitchType.wire,
                if (it.wasInZone) "1" else "0",
                if (it.batterSwung) "1" else "0",
                it.outcome.wire,
                it.selectionQuality.wire,
                it.executionQuality,
                it.contactQuality ?: -1,
                it.expectedDamage,
                it.actualDamage,
                if (it.recommendationAccepted) "1" else "0",
            ).joinToString(":")
        }
        return listOf(log.gameId, log.revision, log.totalPitches, entries).joinToString("|")
    }

    private fun approachValue(approach: BatterApproach): String = when (approach) {
        BatterApproach.PATIENT -> "patient"
        BatterApproach.AGGRESSIVE -> "aggressive"
        BatterApproach.PROTECT -> "protect"
        BatterApproach.POWER -> "power"
    }

    private fun clamp(value: Int, low: Int, high: Int): Int = min(max(value, low), high)
    private fun extraBase(speed: Int, arm: Int, roll: Int, threshold: Int): Boolean = roll + (speed - arm) * 8 >= threshold
    private fun roundAway(value: Double): Int = if (value >= 0.0) floor(value + 0.5).toInt() else ceil(value - 0.5).toInt()
}

public data class SubmitPitchParams(
    val seed: String,
    val pitcher: PitcherSnapshot,
    val batter: BatterSnapshot,
    val scouting: BatterScoutingSnapshot,
    val context: PlateAppearanceContext,
    val preparationToken: String,
    val call: PitchCall,
    val rivalMemory: RivalMemorySnapshot? = null,
    val gameState: GameStateSnapshot? = null,
    val gameLog: GameLogSnapshot? = null,
)

public object BattedBallBands {
    public const val SINGLE_FLOOR: Int = 500
    public const val DOUBLE_FLOOR: Int = 620
    public const val HOME_RUN_FLOOR: Int = 775

    public fun outcome(quality: Int): PitchOutcome = when {
        quality < SINGLE_FLOOR -> PitchOutcome.IN_PLAY_OUT
        quality < DOUBLE_FLOOR -> PitchOutcome.SINGLE
        quality < HOME_RUN_FLOOR -> PitchOutcome.DOUBLE
        else -> PitchOutcome.HOME_RUN
    }
}

private fun requireKernel(condition: Boolean, code: String) {
    if (!condition) throw PitchKernelException(code, code)
}

private fun clamp(value: Int, low: Int, high: Int): Int = min(max(value, low), high)
