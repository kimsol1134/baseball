package com.solkim.baseball.android

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.PitchDelivery
import com.solkim.baseball.application.PitchReleaseWindow
import com.solkim.baseball.design.BaseballColors
import kotlin.math.hypot

@Composable
internal fun ReleaseMeterBar(meter: Double, pressing: Boolean, inPerfect: Boolean, commandRating: Int, previousCommand: Int? = null, growthGlow: Float = 0f) {
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

internal fun clampAim(aim: Offset, radius: Float): Offset {
    val length = hypot(aim.x.toDouble(), aim.y.toDouble()).toFloat()
    if (length <= radius) return aim
    val scale = radius / length.coerceAtLeast(1f)
    return Offset(aim.x * scale, aim.y * scale)
}
