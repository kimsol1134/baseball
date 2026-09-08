package com.solkim.baseball.android

import android.os.Build
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
import com.solkim.baseball.android.LocalizedGameText as Text
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.runtime.DisposableEffect
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
import androidx.compose.ui.platform.LocalView
import android.view.HapticFeedbackConstants
import androidx.compose.ui.platform.testTag
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
import com.solkim.baseball.application.PitchReleaseWindow
import androidx.compose.runtime.rememberUpdatedState
import com.solkim.baseball.application.PitchReleaseMeter
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.platform.NativeAudioHapticsService
import com.solkim.baseball.platform.NativePlaybackSettings
import kotlinx.coroutines.delay
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
    onPressingChange: (Boolean) -> Unit = {},
    holdPrompt: String = "길게 눌러 와인드업",
    modifier: Modifier = Modifier,
    velocityTenthsKph: Int = 1_350,
    fatigue: Int = 0,
    commandRating: Int = PitchReleaseWindow.BASELINE_COMMAND,
    previousCommand: Int? = null,
    previousVelocity: Int? = null,
    holdComparison: Boolean = false,
    compact: Boolean = false,
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
    val sliderDescription = rememberGameCopy().resolve("android.pitch.slider-description")
    SliderFrameRate(enabled && !autoRelease && !reduceMotion)
    val density = LocalDensity.current
    val aimRadiusPx = with(density) { PitchReleaseMeter.AIM_RADIUS_POINTS.toFloat().dp.toPx() }
    val context = LocalContext.current
    val touchView = LocalView.current
    var windowFocused by remember(touchView) { mutableStateOf(touchView.hasWindowFocus()) }
    DisposableEffect(touchView) {
        val observer = touchView.viewTreeObserver
        val listener = android.view.ViewTreeObserver.OnWindowFocusChangeListener { windowFocused = it }
        observer.addOnWindowFocusChangeListener(listener)
        onDispose { if (observer.isAlive) observer.removeOnWindowFocusChangeListener(listener) }
    }
    val windUp = remember(touchView) { PitchWindUpFeedback(touchView) }
    DisposableEffect(windUp) { onDispose { windUp.stop() } }
    val audio = remember(context) { context.pitchAudio() }
    val playback = NativePlaybackSettings(soundEnabled, false, hapticsEnabled, reduceMotion)
    val latestPressingChange by rememberUpdatedState(onPressingChange)
    val latestCommand by rememberUpdatedState(commandRating)
    var heldCommand by remember { mutableStateOf(commandRating) }
    var pressing by remember { mutableStateOf(false) }
    val windowCommand = if (pressing) heldCommand else commandRating
    var meter by remember { mutableStateOf(0.0) }
    var drag by remember { mutableStateOf(Offset.Zero) }
    var sway by remember { mutableStateOf(Offset.Zero) }
    var holdHint by remember { mutableStateOf(false) }
    var pressStartedAtNanos by remember { mutableStateOf(0L) }
    var wasInSweetSpot by remember { mutableStateOf(false) }
    var baseMeter by remember { mutableStateOf(0.5) }
    var leadWarned by remember { mutableStateOf(false) }
    var perfectRing by remember { mutableStateOf(0) }
    val ringProgress = remember { androidx.compose.animation.core.Animatable(0f) }
    LaunchedEffect(perfectRing) {
        if (perfectRing <= 0) return@LaunchedEffect
        ringProgress.snapTo(0.001f)
        ringProgress.animateTo(1f, androidx.compose.animation.core.tween(durationMillis = if (reduceMotion) 160 else 520))
    }
    // The old window stays on the bar for a moment after 제구 grows, so the wider green is visible.
    var showPrevious by remember(previousCommand) { mutableStateOf(previousCommand != null) }
    val growthGlow = remember(previousCommand) { androidx.compose.animation.core.Animatable(0f) }
    LaunchedEffect(previousCommand, reduceMotion, holdComparison) {
        if (previousCommand == null) return@LaunchedEffect
        growthGlow.snapTo(1f)
        if (holdComparison) return@LaunchedEffect
        if (reduceMotion) delay(2_500L) else growthGlow.animateTo(0f, androidx.compose.animation.core.tween(2_500))
        showPrevious = false
    }
    var showVelocityGrowth by remember(previousVelocity, velocityTenthsKph) { mutableStateOf(previousVelocity != null && previousVelocity < velocityTenthsKph) }
    LaunchedEffect(previousVelocity, velocityTenthsKph) { delay(2_500L); showVelocityGrowth = false }
    var lastHint by remember { mutableStateOf<String?>(null) }
    val sweep = PitchReleaseMeter.sweepSeconds(velocityTenthsKph, fatigue, reduceMotion)
    val amplitude = PitchReleaseMeter.swayAmplitude(fatigue, reduceMotion)
    val amplitudePx = with(density) { amplitude.toFloat().dp.toPx() }.toDouble()

    val idleBeats = remember { mutableListOf<Double>() }
    LaunchedEffect(enabled, pressing, tension, disturbanceSeed, hapticsEnabled, soundEnabled, adverseEpisode, windowFocused) {
        if (!enabled || pressing || !windowFocused) {
            audio?.stopHeartbeat()
            return@LaunchedEffect
        }
        val heartbeatPcm = if (MoundHeartbeatSettings.heartbeatAudioEnabled(soundEnabled)) {
            kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Default) {
                Pair(MoundHeartbeatAudio.renderPcm(tension, false), MoundHeartbeatAudio.renderPcm(tension, true))
            }
        } else null
        val startNanos = System.nanoTime()
        try {
            runMoundHeartbeat(tension, disturbanceSeed, includeEntry = true, adverseEpisode) { eventTension, irregular ->
                val elapsed = (System.nanoTime() - startNanos) / 1_000_000_000.0
                idleBeats.add(elapsed)
                if (idleBeats.size > 24) idleBeats.removeAt(0)
                if (heartbeatPcm != null) {
                    audio?.playHeartbeat(if (irregular) heartbeatPcm.second else heartbeatPcm.first, MoundHeartbeatAudio.SAMPLE_RATE, playback)
                }
                if (hapticsEnabled) {
                    val intensity = MoundTensionModel.heartbeatHapticIntensity(eventTension) * if (irregular) 1.08 else 1.0
                    audio?.heartbeatBeat(intensity, playback)
                }
            }
        } finally {
            audio?.stopHeartbeat()
        }
    }
    LaunchedEffect(pressing, sweep, amplitudePx, tension, disturbanceSeed, hapticsEnabled, reduceMotion) {
        if (!pressing) return@LaunchedEffect
        val phases = DoubleArray(4) { Random.nextDouble(0.0, 2 * PI) }
        val startNanos = System.nanoTime()
        var last = withFrameNanos { it }
        var previousBase = 0.0
        var direction = 0
        try { while (true) {
            val now = withFrameNanos { it }
            // A frame queued before release must not overwrite its haptic with a late tick.
            if (!pressing || !touchView.hasWindowFocus()) break
            val elapsed = ((System.nanoTime() - startNanos).coerceAtLeast(0L)) / 1_000_000_000.0
            val delta = ((now - last).coerceAtLeast(0L)) / 1_000_000_000.0
            last = now
            val step = minOf(0.1, delta)
            val base = PitchReleaseMeter.phase(elapsed, sweep, heldCommand)
            // Tension may shake the needle, but never by more than a quarter of the player's own
            // window: a mastered pitcher's hand shakes less relative to what they can hit.
            val shaken = MoundMeterDisturbance.position(base, elapsed, tension, idleBeats, hapticsEnabled, reduceMotion, disturbanceSeed)
            val shakeLimit = PitchReleaseWindow.width(heldCommand) / 4.0
            meter = (base + (shaken - base).coerceIn(-shakeLimit, shakeLimit)).coerceIn(0.0, 1.0)
            val nextDirection = if (base > previousBase) 1 else if (base < previousBase) -1 else direction
            if (direction != 0 && nextDirection != direction) windUp.cue(HapticFeedbackConstants.CLOCK_TICK, hapticsEnabled, edge = true)
            direction = nextDirection
            previousBase = base
            val offset = PitchReleaseMeter.swayOffset(elapsed, amplitudePx, phases)
            sway = Offset(offset.first.toFloat(), offset.second.toFloat())
            val inSweet = PitchReleaseWindow.contains(meter, heldCommand)
            if (inSweet && !wasInSweetSpot && hapticsEnabled) {
                windUp.cue(HapticFeedbackConstants.CLOCK_TICK, hapticsEnabled)
            }
            wasInSweetSpot = inSweet
            // 금색 구간은 들어간 뒤 알리면 늦다. 릴리스 지점 도착 시각을 정확히 계산해 앞당겨 알린다.
            baseMeter = base
            val toCenter = PitchReleaseMeter.secondsToRelease(elapsed, sweep)
            val lead = perfectLeadSeconds(heldCommand)
            if (toCenter > lead * 1.5) leadWarned = false
            else if (!leadWarned && toCenter <= lead) {
                leadWarned = true
                windUp.perfectZone(hapticsEnabled)
            }
            windUp.update(1.0 - kotlin.math.abs(meter - 0.5) * 2.0, hapticsEnabled)
            if (step < 0) break
        } } finally { windUp.stop() }
    }

    val aim = clampAim(sway + drag, aimRadiusPx)
    val live = PitchReleaseMeter.delivery(meter, aim.x.toDouble(), aim.y.toDouble(), aimRadiusPx.toDouble(), windowCommand)
    val onTarget = hypot(aim.x.toDouble(), aim.y.toDouble()) <= with(density) { 14.dp.toPx() }
    val timedLive = PitchReleaseMeter.delivery(baseMeter, aim.x.toDouble(), aim.y.toDouble(), aimRadiusPx.toDouble(), windowCommand)
    val inPerfect = pressing && (live.isPerfectRelease || timedLive.isPerfectRelease)
    val inSweet = pressing && PitchReleaseWindow.contains(meter, windowCommand)
    val prompt = when {
        !enabled -> "잠깐"
        pressing && onTarget && inPerfect -> "지금! 퍼펙트"
        pressing && onTarget && inSweet -> "지금"
        pressing && onTarget -> "초록까지 기다려"
        pressing -> "조준점을 가운데로"
        holdHint -> "짧게 탭하면 안 던져진다. 누르고 있다가 놓자."
        lastHint != null -> lastHint!!
        else -> holdPrompt
    }

    val tempo = when {
        sweep <= 0.90 -> "빠름"
        sweep >= 1.06 -> "느림"
        else -> "보통"
    }
    val meterCopy = rememberGameCopy()
    val tempoLabel = meterCopy.resolve(if (fatigue > 0) "loop.meter.tired" else "loop.meter.rested", com.solkim.baseball.application.GameCopyArgument.UserText(meterCopy.legacy(tempo)))

    LaunchedEffect(autoRelease) {
        if (autoRelease) pressing = false
    }

    Column(modifier) {
        if (autoRelease) {
            Button(
                onClick = { if (enabled) {
                    windUp.release(0.5, false, hapticsEnabled)
                    onDeliver(PitchDelivery.NEUTRAL)
                } },
                enabled = enabled,
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).gameDescription("탭 한 번으로 중립 릴리스"),
            ) {
                Text("탭 한 번으로 던지기")
            }
        } else {
        if (!compact) {
        Text(
            prompt,
            style = MaterialTheme.typography.bodyMedium,
            color = BaseballColors.fieldChalk,
            modifier = Modifier.gameDescription("릴리스 타이밍 안내"),
        )
        Spacer(Modifier.height(10.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                rememberGameCopy().resolve("control.window.title"), verbatim = true,
                modifier = Modifier.weight(1f),
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = BaseballColors.textSecondary,
            )
            Text(
                tempoLabel, verbatim = true,
                modifier = Modifier.weight(1f),
                textAlign = androidx.compose.ui.text.style.TextAlign.End,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                fontFamily = FontFamily.Monospace,
                color = BaseballColors.milestone,
            )
        }
        Spacer(Modifier.height(8.dp))
        }
        ReleaseMeterBar(meter = meter, pressing = pressing, inPerfect = inPerfect, commandRating = windowCommand,
            previousCommand = previousCommand.takeIf { showPrevious }, growthGlow = if (showPrevious) growthGlow.value else 0f)
        if (showVelocityGrowth && previousVelocity != null) Text(
            "${previousVelocity / 10}.${previousVelocity % 10} → ${velocityTenthsKph / 10}.${velocityTenthsKph % 10} km/h", verbatim = true,
            color = BaseballColors.action, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(top = 4.dp).testTag("pitch.velocity.growth"))
        if (showPrevious && previousCommand != null && previousCommand < commandRating) {
            Text(
                rememberGameCopy().resolve("pitch.growth.wider-window"), verbatim = true,
                color = BaseballColors.milestone,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(top = 4.dp).testTag("pitch.controlWindow.growth"),
            )
        }
        Spacer(Modifier.height(if (compact) 4.dp else 12.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(if (compact) 64.dp else 92.dp)
                .background(
                    if (!enabled) BaseballColors.surfaceSoft else if (pressing) BaseballColors.action.copy(alpha = 0.18f) else BaseballColors.action,
                    RoundedCornerShape(18.dp),
                )
                .testTag("pitch.slider").gameDescription(sliderDescription)
                .pointerInput(enabled, aimRadiusPx, hapticsEnabled, reduceMotion) {
                    if (!enabled) return@pointerInput
                    awaitEachGesture {
                        val down = awaitFirstDown(requireUnconsumed = true)
                        down.consume()
                        audio?.stopHeartbeat()
                        windUp.cue(HapticFeedbackConstants.LONG_PRESS, hapticsEnabled)
                        holdHint = false
                        lastHint = null
                        drag = Offset.Zero
                        sway = Offset.Zero
                        wasInSweetSpot = false
                        leadWarned = false
                        heldCommand = latestCommand
                        pressStartedAtNanos = System.nanoTime()
                        pressing = true
                        latestPressingChange(true)
                        var released = false
                        try {
                            while (!released) {
                                val event = awaitPointerEvent()
                                val change = event.changes.firstOrNull { it.id == down.id } ?: break
                                if (change.isConsumed || event.changes.any { it.id != down.id && it.pressed }) break
                                val delta = change.position - change.previousPosition
                                drag += delta
                                change.consume()
                                if (!change.pressed) released = true
                            }
                        } finally {
                            val held = (System.nanoTime() - pressStartedAtNanos) / 1_000_000_000.0
                            pressing = false
                            latestPressingChange(false)
                            windUp.stop()
                            if (!released || held < PitchReleaseMeter.MINIMUM_HOLD_SECONDS) {
                                holdHint = released
                                drag = Offset.Zero
                                sway = Offset.Zero
                            } else {
                                val releasedAim = clampAim(sway + drag, aimRadiusPx)
                                val shown = PitchReleaseMeter.delivery(
                                    meter,
                                    releasedAim.x.toDouble(),
                                    releasedAim.y.toDouble(),
                                    aimRadiusPx.toDouble(),
                                    heldCommand,
                                )
                                // 흔들림은 정확도에 남기되, 손끝이 정확히 가운데였던 퍼펙트까지 뺏지는 않는다.
                                val timed = PitchReleaseMeter.delivery(
                                    baseMeter,
                                    releasedAim.x.toDouble(),
                                    releasedAim.y.toDouble(),
                                    aimRadiusPx.toDouble(),
                                    heldCommand,
                                )
                                val scored = if (timed.isPerfectRelease) {
                                    shown.copy(releaseAccuracy = maxOf(shown.releaseAccuracy, timed.releaseAccuracy))
                                } else {
                                    shown
                                }
                                windUp.release((scored.releaseAccuracy + scored.aimAccuracy) / 2_000.0, scored.isPerfectRelease, hapticsEnabled)
                                if (scored.isPerfectRelease) {
                                    perfectRing += 1
                                    audio?.playPitchCue(com.solkim.baseball.model.PitchAudioCue.PERFECT_RELEASE, playback, disturbanceSeed)
                                }
                                showPrevious = false
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
                Canvas(if (compact) Modifier.size(64.dp).align(Alignment.CenterEnd).padding(end = 8.dp) else Modifier.size(72.dp)) {
                    val center = Offset(size.width / 2f, size.height / 2f)
                    // Only the drawing is scaled. Drag distance and scoring keep the same units.
                    val visualScale = if (compact) 0.4f else 1f
                    drawCircle(
                        BaseballColors.fieldChalk.copy(alpha = 0.35f),
                        radius = 15.dp.toPx() * visualScale,
                        center = center,
                        style = Stroke(1.5.dp.toPx()),
                    )
                    drawCircle(BaseballColors.fieldChalk.copy(alpha = 0.5f), radius = 2.5.dp.toPx(), center = center)
                    drawCircle(
                        if (onTarget) BaseballColors.action else BaseballColors.fieldChalk,
                        radius = 13.dp.toPx() * visualScale,
                        center = center + aim * visualScale,
                        style = Stroke(2.5.dp.toPx()),
                    )
                }
                if (compact) Text(prompt, modifier = Modifier.align(Alignment.CenterStart).padding(start = 12.dp, end = 76.dp),
                    style = MaterialTheme.typography.labelMedium, color = BaseballColors.textPrimary)
            } else {
                Text(if (compact && !enabled) rememberGameCopy().resolve("compact.pitch.wait")
                    else if (compact && holdHint) rememberGameCopy().resolve("compact.pitch.hold-too-short") else holdPrompt,
                    color = if (enabled) BaseballColors.actionInk else BaseballColors.textSecondary, style = MaterialTheme.typography.titleMedium)
            }
            val ring = ringProgress.value
            if (ring > 0f && ring < 1f) {
                Canvas(Modifier.matchParentSize()) {
                    val center = Offset(size.width / 2f, size.height / 2f)
                    val radius = 18.dp.toPx() + (size.width * 0.55f) * ring
                    drawCircle(BaseballColors.milestone.copy(alpha = (1f - ring) * 0.9f), radius = radius, center = center, style = Stroke(width = (7f - 5f * ring).dp.toPx()))
                    drawCircle(BaseballColors.milestone.copy(alpha = (1f - ring) * 0.22f), radius = radius * 0.7f, center = center)
                }
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
            .gameDescription(label),
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
private fun ReleaseMeterBar(meter: Double, pressing: Boolean, inPerfect: Boolean, commandRating: Int, previousCommand: Int? = null, growthGlow: Float = 0f) {
    val perfectWidth = (1_000 - PitchDelivery.PERFECT_RELEASE_THRESHOLD) / 1_000f
    val windowWidth = PitchReleaseWindow.width(commandRating).toFloat()
    val copy = rememberGameCopy()
    val windowLabel = copy.resolve("control.window.accessibility", com.solkim.baseball.application.GameCopyArgument.Decimal(PitchReleaseWindow.widthPermille(commandRating) / 10.0))
    Canvas(
        Modifier
            .fillMaxWidth()
            .height(16.dp)
            .testTag("pitch.controlWindow").semantics { contentDescription = windowLabel }
            .padding(horizontal = 2.dp),
    ) {
        val width = size.width
        val height = size.height
        drawRoundRect(BaseballColors.surfaceRaised, cornerRadius = androidx.compose.ui.geometry.CornerRadius(height / 2f, height / 2f))
        val sweet = width * windowWidth
        drawRoundRect(
            BaseballColors.action.copy(alpha = 0.42f + 0.38f * growthGlow),
            topLeft = Offset(width * (0.5f - windowWidth / 2f), 0f),
            size = androidx.compose.ui.geometry.Size(sweet, height),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(height / 2f, height / 2f),
        )
        previousCommand?.let { previous ->
            val previousWidth = PitchReleaseWindow.width(previous).toFloat()
            drawRoundRect(
                BaseballColors.fieldChalk.copy(alpha = 0.85f),
                topLeft = Offset(width * (0.5f - previousWidth / 2f), 1f),
                size = androidx.compose.ui.geometry.Size(width * previousWidth, height - 2f),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(height / 2f, height / 2f),
                style = Stroke(width = 2f, pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(6f, 5f))),
            )
        }
        val perfect = (width * perfectWidth).coerceAtLeast(3f)
        drawRoundRect(
            BaseballColors.milestone.copy(alpha = if (inPerfect) 1f else 0.92f),
            topLeft = Offset(width * (0.5f - perfectWidth / 2f), -(if (inPerfect) 3f else 0f)),
            size = androidx.compose.ui.geometry.Size(perfect, height + if (inPerfect) 6f else 0f),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(height / 2f, height / 2f),
        )
        if (inPerfect) {
            drawRoundRect(
                BaseballColors.milestone.copy(alpha = 0.28f),
                topLeft = Offset(width * (0.5f - perfectWidth / 2f) - 4f, -5f),
                size = androidx.compose.ui.geometry.Size(perfect + 8f, height + 10f),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(height, height),
            )
        }
        val needleX = ((width - 6f) * meter.toFloat()).coerceIn(0f, width - 6f)
        drawRoundRect(
            color = if (inPerfect) BaseballColors.milestone else if (pressing) BaseballColors.action else BaseballColors.border,
            topLeft = Offset(needleX, 0f),
            size = androidx.compose.ui.geometry.Size(6f, height),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(height / 2f, height / 2f),
        )
    }
}

/** 제구가 오를수록 예고가 일찍 온다. 35에서 120ms, 80에서 220ms. */
internal fun perfectLeadSeconds(command: Int): Double =
    0.12 + (command.coerceIn(PitchReleaseWindow.BASELINE_COMMAND, 80) - PitchReleaseWindow.BASELINE_COMMAND) / 45.0 * 0.10

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
