package com.solkim.baseball.android

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.solkim.baseball.core.pitch.PitchDelivery
import com.solkim.baseball.core.pitch.PitchReleaseMeter
import kotlin.math.hypot

/**
 * 기본 투구 조작. 누르고 있다가 초록 구간에서 놓는다. 자동 릴리스는 접근성 경로다.
 */
@Composable
public fun PitchDeliveryControl(
    autoRelease: Boolean,
    enabled: Boolean,
    onDeliver: (PitchDelivery) -> Unit,
    modifier: Modifier = Modifier,
) {
    if (autoRelease) {
        Button(
            onClick = { if (enabled) onDeliver(PitchDelivery.NEUTRAL) },
            enabled = enabled,
            modifier = modifier.fillMaxWidth().heightIn(min = 56.dp).semantics {
                contentDescription = "탭 한 번으로 중립 릴리스"
            },
        ) {
            Text("탭 한 번으로 던지기")
        }
        return
    }

    val density = LocalDensity.current
    val aimRadiusPx = with(density) { PitchReleaseMeter.AIM_RADIUS_POINTS.toFloat().dp.toPx() }
    var pressing by remember { mutableStateOf(false) }
    var meter by remember { mutableStateOf(0.0) }
    var aim by remember { mutableStateOf(Offset.Zero) }
    var holdHint by remember { mutableStateOf(false) }
    var pressStartedAtNanos by remember { mutableStateOf(0L) }

    LaunchedEffect(pressing) {
        if (!pressing) return@LaunchedEffect
        val start = withFrameNanos { it }
        while (true) {
            val now = withFrameNanos { it }
            meter = PitchReleaseMeter.phase((now - start) / 1_000_000_000.0)
        }
    }

    Column(modifier) {
        Text(
            if (!enabled) {
                "연출 준비 중"
            } else if (pressing) {
                if (PitchReleaseMeter.delivery(meter, 0.0, 0.0).isPerfectRelease) {
                    "지금 놓으면 완벽합니다"
                } else {
                    "초록 지점에 맞춰 놓으세요"
                }
            } else if (holdHint) {
                "짧게 탭하면 던져지지 않습니다. 누르고 있다가 놓으세요."
            } else {
                "누르고 있다가 초록 지점에서 놓으세요"
            },
            style = MaterialTheme.typography.bodyMedium,
            color = Color.White,
            modifier = Modifier.semantics { contentDescription = "릴리스 타이밍 안내" },
        )
        Spacer(Modifier.height(10.dp))
        ReleaseMeterBar(meter = meter, pressing = pressing)
        Spacer(Modifier.height(12.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(92.dp)
                .background(
                    if (pressing) Color(0xFFC8A96B).copy(alpha = 0.22f) else Color(0xFFC8A96B),
                    RoundedCornerShape(18.dp),
                )
                .semantics { contentDescription = "투구 슬라이더. 누르고 조준한 뒤 놓으면 던집니다." }
                .pointerInput(enabled) {
                    if (!enabled) return@pointerInput
                    awaitEachGesture {
                        awaitFirstDown(requireUnconsumed = false)
                        holdHint = false
                        aim = Offset.Zero
                        pressStartedAtNanos = System.nanoTime()
                        pressing = true
                        var released = false
                        try {
                            while (!released) {
                                val event = awaitPointerEvent()
                                val change = event.changes.firstOrNull() ?: break
                                val delta = change.position - change.previousPosition
                                val next = Offset(
                                    (aim.x + delta.x).coerceIn(-aimRadiusPx, aimRadiusPx),
                                    (aim.y + delta.y).coerceIn(-aimRadiusPx, aimRadiusPx),
                                )
                                if (hypot(next.x.toDouble(), next.y.toDouble()) <= aimRadiusPx) aim = next
                                else {
                                    val length = hypot(next.x.toDouble(), next.y.toDouble()).toFloat().coerceAtLeast(1f)
                                    aim = Offset(next.x / length * aimRadiusPx, next.y / length * aimRadiusPx)
                                }
                                change.consume()
                                if (!change.pressed) released = true
                            }
                        } finally {
                            val held = (System.nanoTime() - pressStartedAtNanos) / 1_000_000_000.0
                            pressing = false
                            if (held < PitchReleaseMeter.MINIMUM_HOLD_SECONDS) {
                                holdHint = true
                                aim = Offset.Zero
                            } else {
                                onDeliver(
                                    PitchReleaseMeter.delivery(
                                        meter,
                                        aim.x.toDouble(),
                                        aim.y.toDouble(),
                                        aimRadiusPx.toDouble(),
                                    ),
                                )
                                aim = Offset.Zero
                            }
                        }
                    }
                },
            contentAlignment = Alignment.Center,
        ) {
            if (pressing) {
                Canvas(Modifier.size(72.dp)) {
                    val center = Offset(size.width / 2f, size.height / 2f)
                    drawCircle(Color(0xFFF4F1E8).copy(alpha = 0.35f), radius = 14.dp.toPx(), center = center, style = Stroke(2.dp.toPx()))
                    drawCircle(Color(0xFFF4F1E8), radius = 7.dp.toPx(), center = center + aim)
                }
            } else {
                Text("누르고 있다가 놓기", color = Color(0xFF101820), style = MaterialTheme.typography.titleMedium)
            }
        }
    }
}

@Composable
private fun ReleaseMeterBar(meter: Double, pressing: Boolean) {
    val perfectWidth = (1_000 - PitchDelivery.PERFECT_RELEASE_THRESHOLD) / 1_000f
    Canvas(
        Modifier
            .fillMaxWidth()
            .height(16.dp)
            .padding(horizontal = 2.dp),
    ) {
        val width = size.width
        val height = size.height
        drawRoundRect(Color(0xFF19242D), cornerRadius = androidx.compose.ui.geometry.CornerRadius(height / 2f, height / 2f))
        val sweet = width * 0.18f
        drawRoundRect(
            Color(0xFFC8A96B).copy(alpha = 0.42f),
            topLeft = Offset(width * 0.41f, 0f),
            size = androidx.compose.ui.geometry.Size(sweet, height),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(height / 2f, height / 2f),
        )
        val perfect = (width * perfectWidth).coerceAtLeast(3f)
        drawRoundRect(
            Color(0xFF8DB5A4),
            topLeft = Offset(width * (0.5f - perfectWidth / 2f), 0f),
            size = androidx.compose.ui.geometry.Size(perfect, height),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(height / 2f, height / 2f),
        )
        val needleX = ((width - 6f) * meter.toFloat()).coerceIn(0f, width - 6f)
        drawRoundRect(
            color = if (pressing && PitchReleaseMeter.delivery(meter, 0.0, 0.0).isPerfectRelease) Color(0xFF8DB5A4) else Color(0xFFC8A96B),
            topLeft = Offset(needleX, 0f),
            size = androidx.compose.ui.geometry.Size(6f, height),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(3f, 3f),
        )
    }
}
