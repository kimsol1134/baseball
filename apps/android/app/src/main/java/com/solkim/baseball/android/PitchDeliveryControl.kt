package com.solkim.baseball.android

import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.MoundHeartbeatAudio
import com.solkim.baseball.application.MoundHeartbeatCadence
import com.solkim.baseball.application.MoundHeartbeatPattern
import com.solkim.baseball.application.MoundHeartbeatSettings
import com.solkim.baseball.application.MoundMeterDisturbance
import com.solkim.baseball.application.MoundTensionModel
import com.solkim.baseball.application.PitchDelivery
import com.solkim.baseball.application.PitchReleaseMeter
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.platform.NativeAudioHapticsService
import com.solkim.baseball.platform.NativePlaybackSettings
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.PI
import kotlin.math.hypot
import kotlin.random.Random

/**
 * 기본 투구 조작. 누르고 있다가 초록 구간에서 놓는다. 자동 릴리스는 접근성 경로다.
 * 조준점은 스스로 흔들리고 손가락이 상쇄한다. 가만히 두면 만점이 아니다.
 */
@Composable
public fun PitchDeliveryControl(
    autoRelease: Boolean,
    enabled: Boolean,
    onDeliver: (PitchDelivery) -> Unit,
    holdPrompt: String = "길게 눌러 와인드업",
    modifier: Modifier = Modifier,
    velocityTenthsKph: Int = 1_350,
    fatigue: Int = 0,
    reduceMotion: Boolean = false,
    hapticsEnabled: Boolean = true,
    soundEnabled: Boolean = true,
    tension: Double = 0.0,
    disturbanceSeed: ULong = 0UL,
    adverseEpisode: Boolean = false,
    pitchTypeLabel: String = "포심",
    onAutoReleaseChange: ((Boolean) -> Unit)? = null,
    autoReleaseLabel: String = "자동 릴리스 — 탭 한 번으로 중립 투구",
) {
    val density = LocalDensity.current
    val aimRadiusPx = with(density) { PitchReleaseMeter.AIM_RADIUS_POINTS.toFloat().dp.toPx() }
    val context = LocalContext.current
    val vibrator = remember(context) { context.pitchVibrator() }
    val audio = remember(context) { context.pitchAudio() }
    val playback = NativePlaybackSettings(soundEnabled, false, hapticsEnabled, reduceMotion)
    var pressing by remember { mutableStateOf(false) }
    var meter by remember { mutableStateOf(0.0) }
    var drag by remember { mutableStateOf(Offset.Zero) }
    var sway by remember { mutableStateOf(Offset.Zero) }
    var holdHint by remember { mutableStateOf(false) }
    var pressStartedAtNanos by remember { mutableStateOf(0L) }
    var wasInSweetSpot by remember { mutableStateOf(false) }
    var lastHint by remember { mutableStateOf<String?>(null) }
    val sweep = PitchReleaseMeter.sweepSeconds(velocityTenthsKph, fatigue, reduceMotion)
    val amplitude = PitchReleaseMeter.swayAmplitude(fatigue, reduceMotion)
    val amplitudePx = with(density) { amplitude.toFloat().dp.toPx() }.toDouble()

    LaunchedEffect(pressing, sweep, amplitudePx, tension, disturbanceSeed, hapticsEnabled, soundEnabled, reduceMotion, adverseEpisode) {
        if (!pressing) {
            audio?.stopHeartbeat()
            return@LaunchedEffect
        }
        val phases = DoubleArray(4) { Random.nextDouble(0.0, 2 * PI) }
        val beats = mutableListOf<Double>()
        val startNanos = System.nanoTime()
        val heartbeatJob = launch {
            runMoundHeartbeat(tension, disturbanceSeed, includeEntry = true, adverseEpisode) { eventTension, irregular ->
                val elapsed = (System.nanoTime() - startNanos) / 1_000_000_000.0
                beats.add(elapsed)
                if (beats.size > 24) beats.removeAt(0)
                if (MoundHeartbeatSettings.heartbeatAudioEnabled(soundEnabled)) {
                    audio?.playHeartbeat(MoundHeartbeatAudio.renderPcm(eventTension, irregular), MoundHeartbeatAudio.SAMPLE_RATE, playback)
                }
                if (hapticsEnabled) {
                    val intensity = MoundTensionModel.heartbeatHapticIntensity(eventTension) * if (irregular) 1.08 else 1.0
                    audio?.heartbeatBeat(intensity, playback)
                }
            }
        }
        try {
            var last = withFrameNanos { it }
            while (true) {
                val now = withFrameNanos { it }
                val elapsed = ((System.nanoTime() - startNanos).coerceAtLeast(0L)) / 1_000_000_000.0
                val delta = ((now - last).coerceAtLeast(0L)) / 1_000_000_000.0
                last = now
                val step = minOf(0.1, delta)
                val base = PitchReleaseMeter.phase(elapsed, sweep)
                meter = MoundMeterDisturbance.position(base, elapsed, tension, beats, hapticsEnabled, reduceMotion, disturbanceSeed)
                val offset = PitchReleaseMeter.swayOffset(elapsed, amplitudePx, phases)
                sway = Offset(offset.first.toFloat(), offset.second.toFloat())
                val inSweet = kotlin.math.abs(meter - 0.5) <= 0.09
                if (inSweet && !wasInSweetSpot && hapticsEnabled && !reduceMotion) {
                    vibrator.pulse(18)
                }
                wasInSweetSpot = inSweet
                if (step < 0) break
            }
        } finally {
            heartbeatJob.cancel()
            audio?.stopHeartbeat()
        }
    }

    val aim = clampAim(sway + drag, aimRadiusPx)
    val live = PitchReleaseMeter.delivery(meter, aim.x.toDouble(), aim.y.toDouble(), aimRadiusPx.toDouble())
    val onTarget = hypot(aim.x.toDouble(), aim.y.toDouble()) <= with(density) { 14.dp.toPx() }
    val inPerfect = pressing && live.isPerfectRelease
    val inSweet = pressing && kotlin.math.abs(meter - 0.5) <= 0.09
    val prompt = when {
        !enabled -> "연출 준비 중"
        pressing && onTarget && inPerfect -> "지금 놓으면 완벽합니다"
        pressing && onTarget && inSweet -> "지금"
        pressing && onTarget -> "미터를 기다리세요"
        pressing -> "과녁에 맞춰 주세요"
        holdHint -> "짧게 탭하면 던져지지 않습니다. 누르고 있다가 놓으세요."
        lastHint != null -> lastHint!!
        else -> holdPrompt
    }

    val tempoLabel = when {
        velocityTenthsKph >= 1_400 -> "빠름"
        velocityTenthsKph < 1_230 -> "느림"
        else -> "보통"
    }
    val velocityLabel = "${velocityTenthsKph / 10}.${velocityTenthsKph % 10} km/h"

    LaunchedEffect(autoRelease) {
        if (autoRelease) pressing = false
    }

    Column(modifier) {
        if (autoRelease) {
            Button(
                onClick = { if (enabled) onDeliver(PitchDelivery.NEUTRAL) },
                enabled = enabled,
                modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).semantics {
                    contentDescription = "탭 한 번으로 중립 릴리스"
                },
            ) {
                Text("탭 한 번으로 던지기")
            }
        } else {
        Text(
            prompt,
            style = MaterialTheme.typography.bodyMedium,
            color = BaseballColors.fieldChalk,
            modifier = Modifier.semantics { contentDescription = "릴리스 타이밍 안내" },
        )
        Spacer(Modifier.height(10.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                "$pitchTypeLabel 릴리스",
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = BaseballColors.textSecondary,
            )
            Text(
                "$tempoLabel · $velocityLabel",
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                fontFamily = FontFamily.Monospace,
                color = BaseballColors.milestone,
            )
        }
        Spacer(Modifier.height(8.dp))
        ReleaseMeterBar(meter = meter, pressing = pressing, inPerfect = inPerfect)
        Spacer(Modifier.height(12.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(92.dp)
                .background(
                    if (pressing) BaseballColors.action.copy(alpha = 0.18f) else BaseballColors.action,
                    RoundedCornerShape(18.dp),
                )
                .semantics { contentDescription = "투구 슬라이더. 누르고 조준한 뒤 놓으면 던집니다." }
                .pointerInput(enabled, aimRadiusPx, hapticsEnabled, reduceMotion) {
                    if (!enabled) return@pointerInput
                    awaitEachGesture {
                        awaitFirstDown(requireUnconsumed = false)
                        holdHint = false
                        lastHint = null
                        drag = Offset.Zero
                        sway = Offset.Zero
                        wasInSweetSpot = false
                        pressStartedAtNanos = System.nanoTime()
                        pressing = true
                        var released = false
                        try {
                            while (!released) {
                                val event = awaitPointerEvent()
                                val change = event.changes.firstOrNull() ?: break
                                val delta = change.position - change.previousPosition
                                drag += delta
                                change.consume()
                                if (!change.pressed) released = true
                            }
                        } finally {
                            val held = (System.nanoTime() - pressStartedAtNanos) / 1_000_000_000.0
                            pressing = false
                            if (held < PitchReleaseMeter.MINIMUM_HOLD_SECONDS) {
                                holdHint = true
                                drag = Offset.Zero
                                sway = Offset.Zero
                            } else {
                                val releasedAim = clampAim(sway + drag, aimRadiusPx)
                                val scored = PitchReleaseMeter.delivery(
                                    meter,
                                    releasedAim.x.toDouble(),
                                    releasedAim.y.toDouble(),
                                    aimRadiusPx.toDouble(),
                                )
                                if (hapticsEnabled && !reduceMotion) {
                                    vibrator.pulse(if (scored.isPerfectRelease) 42 else 12)
                                }
                                lastHint = PitchReleaseMeter.coachingHint(scored)
                                onDeliver(scored)
                                drag = Offset.Zero
                                sway = Offset.Zero
                            }
                        }
                    }
                },
            contentAlignment = Alignment.Center,
        ) {
            if (pressing) {
                Canvas(Modifier.size(72.dp)) {
                    val center = Offset(size.width / 2f, size.height / 2f)
                    drawCircle(
                        BaseballColors.fieldChalk.copy(alpha = 0.35f),
                        radius = 15.dp.toPx(),
                        center = center,
                        style = Stroke(1.5.dp.toPx()),
                    )
                    drawCircle(BaseballColors.fieldChalk.copy(alpha = 0.5f), radius = 2.5.dp.toPx(), center = center)
                    drawCircle(
                        if (onTarget) BaseballColors.action else BaseballColors.fieldChalk,
                        radius = 13.dp.toPx(),
                        center = center + aim,
                        style = Stroke(2.5.dp.toPx()),
                    )
                }
            } else {
                Text(holdPrompt, color = BaseballColors.actionInk, style = MaterialTheme.typography.titleMedium)
            }
        }
        }
        AutoReleaseToggle(
            label = autoReleaseLabel,
            checked = autoRelease,
            enabled = enabled,
            onAutoReleaseChange = onAutoReleaseChange,
        )
    }
}

@Composable
private fun AutoReleaseToggle(
    label: String,
    checked: Boolean,
    enabled: Boolean,
    onAutoReleaseChange: ((Boolean) -> Unit)?,
) {
    if (onAutoReleaseChange == null) return
    Spacer(Modifier.height(8.dp))
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .semantics { contentDescription = label },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = BaseballColors.textTertiary,
            modifier = Modifier.weight(1f),
        )
        Switch(
            checked = checked,
            enabled = enabled,
            onCheckedChange = { onAutoReleaseChange(!checked) },
        )
    }
}

@Composable
private fun ReleaseMeterBar(meter: Double, pressing: Boolean, inPerfect: Boolean) {
    val perfectWidth = (1_000 - PitchDelivery.PERFECT_RELEASE_THRESHOLD) / 1_000f
    Canvas(
        Modifier
            .fillMaxWidth()
            .height(16.dp)
            .padding(horizontal = 2.dp),
    ) {
        val width = size.width
        val height = size.height
        drawRoundRect(BaseballColors.surfaceRaised, cornerRadius = androidx.compose.ui.geometry.CornerRadius(height / 2f, height / 2f))
        val sweet = width * 0.18f
        drawRoundRect(
            BaseballColors.action.copy(alpha = 0.42f),
            topLeft = Offset(width * 0.41f, 0f),
            size = androidx.compose.ui.geometry.Size(sweet, height),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(height / 2f, height / 2f),
        )
        val perfect = (width * perfectWidth).coerceAtLeast(3f)
        drawRoundRect(
            BaseballColors.milestone,
            topLeft = Offset(width * (0.5f - perfectWidth / 2f), 0f),
            size = androidx.compose.ui.geometry.Size(perfect, height),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(height / 2f, height / 2f),
        )
        val needleX = ((width - 6f) * meter.toFloat()).coerceIn(0f, width - 6f)
        drawRoundRect(
            color = if (inPerfect) BaseballColors.milestone else if (pressing) BaseballColors.action else BaseballColors.border,
            topLeft = Offset(needleX, 0f),
            size = androidx.compose.ui.geometry.Size(6f, height),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(height / 2f, height / 2f),
        )
    }
}

private fun clampAim(aim: Offset, radius: Float): Offset {
    val length = hypot(aim.x.toDouble(), aim.y.toDouble()).toFloat()
    if (length <= radius) return aim
    val scale = radius / length.coerceAtLeast(1f)
    return Offset(aim.x * scale, aim.y * scale)
}

private suspend fun runMoundHeartbeat(
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

private fun android.content.Context.pitchAudio(): NativeAudioHapticsService? =
    (applicationContext as? BaseballApplication)?.platform?.audioHaptics

private fun android.content.Context.pitchVibrator(): Vibrator? = try {
    if (Build.VERSION.SDK_INT >= 31) {
        getSystemService(VibratorManager::class.java)?.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        getSystemService(Vibrator::class.java)
    }
} catch (_: Throwable) {
    null
}

private fun Vibrator?.pulse(milliseconds: Long) {
    val device = this ?: return
    if (!device.hasVibrator()) return
    runCatching {
        if (Build.VERSION.SDK_INT >= 26) {
            device.vibrate(VibrationEffect.createOneShot(milliseconds.coerceIn(1L, 80L), VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            device.vibrate(milliseconds.coerceIn(1L, 80L))
        }
    }
}
