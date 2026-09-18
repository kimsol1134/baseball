package com.solkim.baseball.android

import com.solkim.baseball.application.MoundHeartbeatCadence
import com.solkim.baseball.application.MoundHeartbeatPattern
import kotlinx.coroutines.delay

internal suspend fun runMoundHeartbeat(
    tension: Double,
    seed: ULong,
    includeEntry: Boolean,
    adverseEpisode: Boolean,
    onBeat: (tension: Double, irregular: Boolean) -> Unit,
) {
    if (tension <= 0.0) return
    val cadence = MoundHeartbeatCadence.forTension(tension)
    if (includeEntry) {
        val entry = MoundHeartbeatPattern.entry(tension)
        emitHeartbeatPattern(entry, tension, onBeat)
        delaySeconds(entry.rest)
    }
    if (cadence.cycles <= 0) return
    var burstIndex = 0
    var irregularEpisode = adverseEpisode
    while (true) {
        val pattern = MoundHeartbeatPattern.burst(
            tension,
            seed + burstIndex.toULong(),
            burstIndex,
            irregularEpisode,
        )
        emitHeartbeatPattern(pattern, tension, onBeat)
        delaySeconds(pattern.rest)
        irregularEpisode = false
        burstIndex += 1
    }
}

private suspend fun emitHeartbeatPattern(
    pattern: MoundHeartbeatPattern,
    tension: Double,
    onBeat: (tension: Double, irregular: Boolean) -> Unit,
) {
    var elapsed = 0.0
    for (beat in pattern.beats) {
        delaySeconds(beat.offset - elapsed)
        onBeat(tension, beat.isIrregular)
        elapsed = beat.offset
    }
}

private suspend fun delaySeconds(seconds: Double) {
    if (seconds <= 0.0) return
    delay((seconds * 1_000.0).toLong())
}
