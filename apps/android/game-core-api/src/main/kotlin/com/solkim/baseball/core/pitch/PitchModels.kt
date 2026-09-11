package com.solkim.baseball.core.pitch

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
    REACHED_ON_ERROR("reached_on_error"),
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
    REACHED_ON_ERROR("reached_on_error"),
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

/**
 * Growth that continues after a stored 20–80 ability reaches its base ceiling.
 *
 * The gameplay contract intentionally has no design hard cap.  The signed 32-bit
 * saturation is only a cross-platform wire/storage safety boundary and is never
 * presented as a player-facing limit.
 */
public class AbilityMasterySnapshot(
    stuff: Int = 0,
    command: Int = 0,
    movement: Int = 0,
    stamina: Int = 0,
) {
    public companion object {
        public const val TECHNICAL_MAXIMUM: Int = Int.MAX_VALUE
        public val ZERO: AbilityMasterySnapshot = AbilityMasterySnapshot()
        public const val technicalMaximum: Int = TECHNICAL_MAXIMUM
        public val zero: AbilityMasterySnapshot = ZERO
    }

    public val stuff: Int = stuff.coerceIn(0, TECHNICAL_MAXIMUM)
    public val command: Int = command.coerceIn(0, TECHNICAL_MAXIMUM)
    public val movement: Int = movement.coerceIn(0, TECHNICAL_MAXIMUM)
    public val stamina: Int = stamina.coerceIn(0, TECHNICAL_MAXIMUM)

    public fun value(kind: PitchAbilityKind): Int = when (kind) {
        PitchAbilityKind.POWER -> stuff
        PitchAbilityKind.COMMAND -> command
        PitchAbilityKind.MOVEMENT -> movement
        PitchAbilityKind.STAMINA -> stamina
    }

    public fun valueFor(kind: PitchAbilityKind): Int = value(kind)

    public fun withValue(kind: PitchAbilityKind, value: Int): AbilityMasterySnapshot = when (kind) {
        PitchAbilityKind.POWER -> AbilityMasterySnapshot(value, command, movement, stamina)
        PitchAbilityKind.COMMAND -> AbilityMasterySnapshot(stuff, value, movement, stamina)
        PitchAbilityKind.MOVEMENT -> AbilityMasterySnapshot(stuff, command, value, stamina)
        PitchAbilityKind.STAMINA -> AbilityMasterySnapshot(stuff, command, movement, value)
    }

    public fun replacing(kind: PitchAbilityKind, value: Int): AbilityMasterySnapshot = withValue(kind, value)

    public fun add(kind: PitchAbilityKind, points: Int): AbilityMasterySnapshot {
        if (points <= 0) return this
        val next = minOf(TECHNICAL_MAXIMUM.toLong(), value(kind).toLong() + points.toLong()).toInt()
        return withValue(kind, next)
    }

    public fun adding(points: Int, to: PitchAbilityKind): AbilityMasterySnapshot = add(to, points)

    override fun equals(other: Any?): Boolean = other is AbilityMasterySnapshot
        && stuff == other.stuff && command == other.command
        && movement == other.movement && stamina == other.stamina

    override fun hashCode(): Int = (((stuff * 31 + command) * 31 + movement) * 31 + stamina)

    override fun toString(): String = "AbilityMasterySnapshot(stuff=$stuff, command=$command, movement=$movement, stamina=$stamina)"
}

public data class PitcherSnapshot(
    val id: String,
    val name: String,
    val stuff: Int,
    val command: Int,
    val movement: Int,
    val stamina: Int,
    val pitchProfiles: List<PitchProfileSnapshot>? = null,
    val throwingHand: ThrowingHand = ThrowingHand.RIGHT,
    /** Missing on old saves; readers use [effectiveMastery] as zero. */
    val mastery: AbilityMasterySnapshot? = null,
) {
    public fun profile(pitchType: PitchKind): PitchProfileSnapshot? =
        pitchProfiles?.firstOrNull { it.pitchType == pitchType }

    public val effectiveMastery: AbilityMasterySnapshot get() = mastery ?: AbilityMasterySnapshot.ZERO
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
    val reliability: Int = 60,
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
