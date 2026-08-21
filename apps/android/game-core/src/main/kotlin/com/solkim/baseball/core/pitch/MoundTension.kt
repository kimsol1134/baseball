package com.solkim.baseball.core.pitch

import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

public data class MoundComposureInput(
    val command: Int,
    val stamina: Int,
    val awakeningWires: List<String> = emptyList(),
    val memoryWires: List<String> = emptyList(),
)

public data class MoundTensionInput(
    val officialGame: Boolean,
    val leverage: Int,
    val runners: BaserunnerStateSnapshot,
    val balls: Int,
    val strikes: Int,
    val outs: Int,
    val fatigue: Int,
    val batterThreat: Int,
    val recentAdverseEvent: Boolean,
    val composure: MoundComposureInput,
)

public enum class MoundTensionBand { LOW, MEDIUM, HIGH, CLIMAX }

public object MoundTensionModel {
    public const val MEDIUM_THRESHOLD: Double = 0.32
    public const val HIGH_THRESHOLD: Double = 0.58
    public const val CLIMAX_THRESHOLD: Double = 0.80

    public fun composure(from: MoundComposureInput): Double {
        var value = normalized(from.command.toDouble()) * 0.38 + normalized(from.stamina.toDouble()) * 0.27
        from.awakeningWires.forEach { value += awakeningBonus(it) }
        from.memoryWires.forEach { value += memoryBonus(it) }
        return clamp(value)
    }

    public fun damping(composure: Double): Double = 1.0 - 0.92 * clamp(composure)

    public fun baseTension(input: MoundTensionInput): Double {
        if (!input.officialGame) return 0.0
        val leverage = normalized(input.leverage.toDouble(), 1_000.0)
        val stakes = max(0.0, (leverage - 0.62) / 0.38)
        if (stakes <= 0.0) return 0.0
        val runnerPressure = (if (input.runners.firstOccupied) 0.07 else 0.0) +
            (if (input.runners.secondOccupied) 0.16 else 0.0) +
            (if (input.runners.thirdOccupied) 0.25 else 0.0)
        val balls = min(3, max(0, input.balls))
        val strikes = min(2, max(0, input.strikes))
        val countPressure = when {
            balls == 3 && strikes == 2 -> 0.25
            strikes == 2 -> 0.13
            balls == 3 -> 0.10
            else -> 0.0
        }
        val outsPressure = if (min(2, max(0, input.outs)) == 2) 0.08 else 0.0
        val fatiguePressure = max(0.0, (normalized(input.fatigue.toDouble()) - 0.45) / 0.55) * 0.08
        val threatPressure = max(0.0, (normalized(input.batterThreat.toDouble()) - 0.55) / 0.45) * 0.10
        val adversePressure = if (input.recentAdverseEvent) 0.10 else 0.0
        return clamp(stakes * 0.55 + runnerPressure + countPressure + outsPressure + fatiguePressure + threatPressure + adversePressure)
    }

    public fun tension(input: MoundTensionInput): Double =
        baseTension(input) * damping(composure(input.composure))

    public fun band(tension: Double): MoundTensionBand = when (clamp(tension)) {
        in 0.0..<MEDIUM_THRESHOLD -> MoundTensionBand.LOW
        in MEDIUM_THRESHOLD..<HIGH_THRESHOLD -> MoundTensionBand.MEDIUM
        in HIGH_THRESHOLD..<CLIMAX_THRESHOLD -> MoundTensionBand.HIGH
        else -> MoundTensionBand.CLIMAX
    }

    public fun jitterCap(tension: Double): Double {
        val value = clamp(tension)
        return when {
            value < MEDIUM_THRESHOLD -> interpolate(value, 0.0, MEDIUM_THRESHOLD, 0.0, 0.01)
            value < HIGH_THRESHOLD -> interpolate(value, MEDIUM_THRESHOLD, HIGH_THRESHOLD, 0.01, 0.03)
            value < CLIMAX_THRESHOLD -> interpolate(value, HIGH_THRESHOLD, CLIMAX_THRESHOLD, 0.03, 0.05)
            else -> 0.06
        }
    }

    public fun entryTension(rawTension: Double, officialGame: Boolean): Double {
        if (!officialGame) return 0.0
        return max(0.06, clamp(rawTension))
    }

    public fun sweetSpotHapticClarity(effectiveTension: Double): Double = clamp(1.0 - 0.72 * clamp(effectiveTension))

    public fun heartbeatHapticIntensity(effectiveTension: Double): Double = 0.52 * clamp(effectiveTension)

    public fun batterThreat(contact: Int, discipline: Int, power: Int): Int {
        val value = normalized(contact.toDouble()) * 0.45 +
            normalized(discipline.toDouble()) * 0.30 +
            normalized(power.toDouble()) * 0.25
        return kotlin.math.round(value * 100.0).toInt()
    }

    public fun seed(text: String): ULong {
        var hash = 14_695_981_039_346_656_037UL
        for (byte in text.encodeToByteArray()) {
            hash = (hash xor byte.toUByte().toULong()) * 1_099_511_628_211UL
        }
        return hash
    }

    public fun deterministicUnit(seed: ULong): Double {
        var value = seed + 0x9E3779B97F4A7C15UL
        value = value xor (value shr 30)
        value *= 0xBF58476D1CE4E5B9UL
        value = value xor (value shr 27)
        value *= 0x94D049BB133111EBUL
        value = value xor (value shr 31)
        return (value shr 11).toDouble() / 9_007_199_254_740_992.0
    }

    private fun awakeningBonus(wire: String): Double = when (wire) {
        "calm_under_pressure" -> 0.14
        "scout_composure" -> 0.12
        "repeatable_release" -> 0.08
        "two_strike_plan" -> 0.06
        "traffic_controller" -> 0.06
        "late_inning_reserve" -> 0.04
        else -> 0.0
    }

    private fun memoryBonus(wire: String): Double = when (wire) {
        "pressure_rehearsal" -> 0.10
        "two_strike_sequence" -> 0.06
        "bullpen_compass" -> 0.04
        "fatigue_diary" -> 0.03
        "coach_letter" -> 0.02
        else -> 0.0
    }

    private fun normalized(value: Double, maximum: Double = 100.0): Double = clamp(value / maximum)
    private fun clamp(value: Double): Double = min(1.0, max(0.0, value))
    private fun interpolate(value: Double, from: Double, to: Double, low: Double, high: Double): Double {
        val span = max(0.000001, to - from)
        val progress = min(1.0, max(0.0, (value - from) / span))
        return low + (high - low) * progress
    }
}

public object MoundHeartbeatSettings {
    public fun meterJitterEnabled(hapticsEnabled: Boolean): Boolean = hapticsEnabled
}

public data class MoundHeartbeatCadence(
    val band: MoundTensionBand,
    val cycles: Int,
    val restStart: Double,
    val restEnd: Double,
    val cycleInterval: Double,
) {
    public companion object {
        public fun forTension(tension: Double): MoundHeartbeatCadence = when (MoundTensionModel.band(tension)) {
            MoundTensionBand.LOW -> MoundHeartbeatCadence(MoundTensionBand.LOW, 0, 0.0, 0.0, 0.82)
            MoundTensionBand.MEDIUM -> MoundHeartbeatCadence(MoundTensionBand.MEDIUM, 2, 4.0, 6.0, 0.72)
            MoundTensionBand.HIGH -> MoundHeartbeatCadence(MoundTensionBand.HIGH, 3, 2.0, 4.0, 0.63)
            MoundTensionBand.CLIMAX -> MoundHeartbeatCadence(MoundTensionBand.CLIMAX, 4, 0.8, 1.5, 0.54)
        }
    }
}

public data class MoundHeartbeatBeat(val offset: Double, val cycle: Int, val isIrregular: Boolean)

public data class MoundHeartbeatPattern(val beats: List<MoundHeartbeatBeat>, val rest: Double) {
    public companion object {
        public fun entry(tension: Double): MoundHeartbeatPattern {
            val cadence = MoundHeartbeatCadence.forTension(tension)
            return MoundHeartbeatPattern(
                beats = (0 until 3).map { MoundHeartbeatBeat(it * cadence.cycleInterval, it, false) },
                rest = cadence.cycleInterval * 1.15,
            )
        }

        public fun burst(tension: Double, seed: ULong, burstIndex: Int = 0, adverseEpisode: Boolean = false): MoundHeartbeatPattern {
            val cadence = MoundHeartbeatCadence.forTension(tension)
            if (cadence.cycles <= 0) return MoundHeartbeatPattern(emptyList(), 0.0)
            val irregularCycle = if (adverseEpisode) (seed % max(1, cadence.cycles - 1).toULong()).toInt() + 1 else -1
            val direction = if (MoundTensionModel.deterministicUnit(seed xor 0xD1B54A32D192ED03UL) < 0.5) -1.0 else 1.0
            val intervalJitter = if (direction < 0) -cadence.cycleInterval * 0.18 else cadence.cycleInterval * 0.32
            val beats = (0 until cadence.cycles).map { cycle ->
                val irregular = cycle == irregularCycle
                MoundHeartbeatBeat(max(0.0, cycle * cadence.cycleInterval + if (irregular) intervalJitter else 0.0), cycle, irregular)
            }
            val mixed = seed + burstIndex.toULong() * 0x9E3779B97F4A7C15UL
            val rest = if (cadence.restStart < cadence.restEnd) {
                cadence.restStart + (cadence.restEnd - cadence.restStart) * MoundTensionModel.deterministicUnit(mixed)
            } else {
                cadence.restStart
            }
            return MoundHeartbeatPattern(beats, rest)
        }
    }
}

public object MoundMeterDisturbance {
    public fun offset(
        at: Double,
        effectiveTension: Double,
        beatTimes: List<Double>,
        hapticsEnabled: Boolean,
        reduceMotion: Boolean,
        seed: ULong,
    ): Double {
        if (!MoundHeartbeatSettings.meterJitterEnabled(hapticsEnabled)) return 0.0
        val cap = MoundTensionModel.jitterCap(effectiveTension)
        if (cap <= 0.0) return 0.0
        val phase = MoundTensionModel.deterministicUnit(seed xor 0xA24BAED4963EE407UL) * 2 * PI
        val frequency = 0.55 + 0.25 * MoundTensionModel.deterministicUnit(seed xor 0x9FB21C651E98DF25UL)
        val lowFrequency = 0.22 * sin(2 * PI * frequency * max(0.0, at) + phase)
        val heartbeatImpulse = beatTimes.fold(0.0) { partial, beatTime ->
            val age = at - beatTime
            if (age < 0.0 || age >= 0.50) partial
            else {
                val primary = exp(-age / 0.13)
                val rebound = if (age > 0.14) -0.20 * exp(-(age - 0.14) / 0.12) else 0.0
                partial + primary + rebound
            }
        }
        val normalized = min(1.0, max(-1.0, lowFrequency * 0.35 + heartbeatImpulse * 0.72))
        val motionScale = if (reduceMotion) 0.5 else 1.0
        return min(cap, max(-cap, cap * normalized * motionScale))
    }

    public fun position(
        base: Double,
        at: Double,
        effectiveTension: Double,
        beatTimes: List<Double>,
        hapticsEnabled: Boolean,
        reduceMotion: Boolean,
        seed: ULong,
    ): Double = min(
        1.0,
        max(
            0.0,
            base + offset(at, effectiveTension, beatTimes, hapticsEnabled, reduceMotion, seed),
        ),
    )
}
