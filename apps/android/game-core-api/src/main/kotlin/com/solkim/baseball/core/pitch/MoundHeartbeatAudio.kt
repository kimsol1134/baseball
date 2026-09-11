package com.solkim.baseball.core.pitch

import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

/** iOS `GameAudio.heartbeatVoices` — two descending sine sweeps that read as lub-dub. */
public data class MoundHeartbeatVoice(
    val duration: Double,
    val attack: Double,
    val gain: Double,
    val fromHz: Double,
    val toHz: Double,
    val curve: Double,
    val delay: Double,
)

public object MoundHeartbeatAudio {
    public const val SAMPLE_RATE: Int = 44_100

    public fun voices(tension: Double, irregular: Boolean = false): List<MoundHeartbeatVoice> {
        val clamped = min(1.0, max(0.0, tension))
        val irregularScale = if (irregular) 1.08 else 1.0
        return listOf(
            MoundHeartbeatVoice(
                duration = 0.11,
                attack = 0.003,
                gain = 0.040 * clamped * irregularScale,
                fromHz = 78.0 - 12.0 * clamped,
                toHz = 42.0 - 8.0 * clamped,
                curve = 2.2,
                delay = 0.0,
            ),
            MoundHeartbeatVoice(
                duration = 0.13,
                attack = 0.003,
                gain = 0.027 * clamped * irregularScale,
                fromHz = 55.0 - 8.0 * clamped,
                toHz = 32.0 - 5.0 * clamped,
                curve = 2.1,
                delay = 0.16,
            ),
        )
    }

    /** 16-bit mono PCM at [SAMPLE_RATE], matching iOS VoiceBank sweep rendering. */
    public fun renderPcm(tension: Double, irregular: Boolean = false): ShortArray {
        val voices = voices(tension, irregular)
        if (voices.all { it.gain <= 0.0 }) return ShortArray(0)
        val seconds = voices.maxOf { it.delay + it.duration }
        val frames = max(1, (seconds * SAMPLE_RATE).toInt() + 1)
        val mix = DoubleArray(frames)
        for (voice in voices) mixVoice(mix, voice)
        return ShortArray(frames) { index ->
            val clipped = softClip(mix[index])
            (clipped * Short.MAX_VALUE).toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
        }
    }

    private fun mixVoice(mix: DoubleArray, voice: MoundHeartbeatVoice) {
        if (voice.gain <= 0.0 || voice.duration <= 0.0) return
        val sampleRate = SAMPLE_RATE.toDouble()
        val delayFrames = (voice.delay * sampleRate).toInt()
        val totalFrames = max(1, (voice.duration * sampleRate).toInt())
        val attackFrames = max(1, (voice.attack * sampleRate).toInt())
        val decayFrames = max(1, totalFrames - attackFrames)
        val ratio = max(0.02, voice.toHz / voice.fromHz)
        var phase = 0.0
        for (frame in 0 until totalFrames) {
            val index = delayFrames + frame
            if (index !in mix.indices) continue
            val envelope = if (frame < attackFrames) {
                frame.toDouble() / attackFrames
            } else {
                val decayProgress = (frame - attackFrames).toDouble() / decayFrames
                (1.0 - decayProgress).pow(voice.curve)
            }
            val progress = frame.toDouble() / totalFrames
            val frequency = voice.fromHz * ratio.pow(progress)
            phase += frequency / sampleRate
            if (phase > 1.0) phase -= 1.0
            mix[index] += sin(phase * 2.0 * PI) * envelope * voice.gain
        }
    }

    private fun softClip(value: Double): Double = when {
        value > 1.2 -> 1.0
        value < -1.2 -> -1.0
        else -> value - (value * value * value) / 3.6
    }
}

public data class MoundHeartbeatEvent(
    val time: Double,
    val tension: Double,
    val cycle: Int,
    val isIrregular: Boolean,
)

/** Finite schedule used by tests and as the pattern source for the live windup runner. */
public object MoundHeartbeatTimeline {
    public fun beats(
        tension: Double,
        seed: ULong,
        includeEntry: Boolean = true,
        adverseEpisode: Boolean = false,
        burstCount: Int = 0,
    ): List<MoundHeartbeatEvent> {
        if (tension <= 0.0) return emptyList()
        val events = mutableListOf<MoundHeartbeatEvent>()
        var origin = 0.0
        if (includeEntry) {
            val entry = MoundHeartbeatPattern.entry(tension)
            append(events, entry, origin, tension)
            origin += (entry.beats.lastOrNull()?.offset ?: 0.0) + entry.rest
        }
        val cadence = MoundHeartbeatCadence.forTension(tension)
        if (cadence.cycles <= 0) return events
        var irregular = adverseEpisode
        for (burstIndex in 0 until burstCount) {
            val pattern = MoundHeartbeatPattern.burst(
                tension,
                seed + burstIndex.toULong(),
                burstIndex,
                irregular,
            )
            append(events, pattern, origin, tension)
            origin += (pattern.beats.lastOrNull()?.offset ?: 0.0) + pattern.rest
            irregular = false
        }
        return events
    }

    private fun append(
        events: MutableList<MoundHeartbeatEvent>,
        pattern: MoundHeartbeatPattern,
        origin: Double,
        tension: Double,
    ) {
        for (beat in pattern.beats) {
            events += MoundHeartbeatEvent(origin + beat.offset, tension, beat.cycle, beat.isIrregular)
        }
    }
}
