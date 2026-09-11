package com.solkim.baseball.android

import android.graphics.BitmapFactory
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.solkim.baseball.application.BatSide
import com.solkim.baseball.application.BattedBall
import com.solkim.baseball.application.FieldingResolutionSnapshot
import com.solkim.baseball.application.PitchDramaCamera
import com.solkim.baseball.application.PitchFlightProjection
import com.solkim.baseball.application.PitchOutcome
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.model.PitchPresentationRequest
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * 승부의 5초를 렌더링하는 Jetpack Compose 2컷 드라마 뷰포트.
 * iOS `PitchDramaView.swift`와 동일한 2컷(포수 시점 -> 인플레이 탑다운) 연출을 제공한다.
 *
 * 1컷 (포수 시점): 공이 커지며 날아온다 -> 미트에 꽂히거나 배트에 맞아 섬광이 터진다.
 * 2컷 (탑다운): 맞은 공만. 타구가 실제 낙하 지점까지 날아가고 수비수가 수렴한다.
 */
internal fun DrawScope.drawFieldShot(
    progress: Float,
    outcome: PitchOutcome?,
    battedBall: BattedBall?,
    fielding: FieldingResolutionSnapshot?,
    textMeasurer: TextMeasurer,
    canvasSize: Size,
) {
    val scale = min(canvasSize.width / 320f, canvasSize.height / 300f).coerceAtLeast(0.7f)
    val home = Offset(canvasSize.width * 0.5f, canvasSize.height * 0.90f)
    val maxReach = min(canvasSize.width * 0.48f, home.y - canvasSize.height * 0.06f)
    val metersToPoints = maxReach / 118f

    fun fieldPoint(distanceMeters: Float, degrees: Float): Offset {
        val clamped = min(48f, max(-48f, degrees))
        val radians = clamped * (PI.toFloat() / 180f)
        val length = min(125f, max(0f, distanceMeters)) * metersToPoints
        return Offset(home.x + sin(radians) * length, home.y - cos(radians) * length)
    }

    val fenceRadius = 118f * metersToPoints
    val fairPath = Path().apply {
        moveTo(home.x, home.y)
        val leftFence = fieldPoint(118f, -48f)
        lineTo(leftFence.x, leftFence.y)
        arcTo(
            rect = Rect(home.x - fenceRadius, home.y - fenceRadius, home.x + fenceRadius, home.y + fenceRadius),
            startAngleDegrees = 222f,
            sweepAngleDegrees = 96f,
            forceMoveTo = false,
        )
        close()
    }
    drawPath(
        fairPath,
        brush = Brush.radialGradient(
            colors = listOf(BaseballColors.actionSoft, BaseballColors.canvas.copy(alpha = 0.72f)),
            center = Offset(home.x, home.y - fenceRadius * 0.45f),
            radius = fenceRadius,
        ),
        style = Fill,
    )
    drawPath(fairPath, color = BaseballColors.fieldChalk.copy(alpha = 0.42f), style = Stroke(width = max(1.4f, 1.8f * scale)))

    val diamondPath = Path().apply {
        moveTo(home.x, home.y)
        val firstBase = fieldPoint(27.4f, 45f)
        val secondBase = fieldPoint(38.8f, 0f)
        val thirdBase = fieldPoint(27.4f, -45f)
        lineTo(firstBase.x, firstBase.y)
        lineTo(secondBase.x, secondBase.y)
        lineTo(thirdBase.x, thirdBase.y)
        close()
    }
    drawPath(diamondPath, color = BaseballColors.fieldDirt.copy(alpha = 0.55f), style = Fill)
    drawPath(diamondPath, color = BaseballColors.fieldChalk.copy(alpha = 0.65f), style = Stroke(width = max(1.2f, 1.6f * scale)))

    val after = min(1f, (progress - CUT_PROGRESS) / (1f - CUT_PROGRESS))
    val direction = (battedBall?.directionTenthsDegrees ?: 0) / 10f
    val landing = (fielding?.landingDistanceTenthsMeters ?: 400) / 10f
    val travelled = landing * after
    val ballPt = fieldPoint(travelled, direction)
    val tone = outcomeTone(outcome)

    drawLine(
        color = tone.copy(alpha = 0.9f),
        start = home,
        end = ballPt,
        strokeWidth = max(2.4f, 3.4f * scale),
        cap = StrokeCap.Round,
    )

    val targetPt = fieldPoint(landing, direction)
    val ringRadius = 16f * scale
    drawCircle(
        color = tone.copy(alpha = 0.4f + 0.45f * after),
        radius = ringRadius,
        center = targetPt,
        style = Stroke(width = max(1.4f, 2f * scale), pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f * scale, 4f * scale))),
    )

    val arc = sin(after * PI.toFloat())
    val ballRadius = (5.2f + 5.8f * arc) * scale
    drawCircle(
        brush = Brush.radialGradient(
            colors = listOf(BaseballColors.fieldChalk, tone.copy(alpha = 0.35f)),
            center = ballPt,
            radius = ballRadius * 2.2f,
        ),
        radius = ballRadius * 2.2f,
        center = ballPt,
    )
    drawCircle(
        color = BaseballColors.fieldChalk,
        radius = ballRadius,
        center = ballPt,
    )

    if (fielding != null) {
        val startCoords = fielderHome(fielding.fielderPosition)
        val startPt = fieldPoint(startCoords.first, startCoords.second)
        val endPt = fieldPoint(landing, direction)
        val chase = min(1f, after * 1.15f)
        val currentFielderPt = Offset(
            startPt.x + (endPt.x - startPt.x) * chase,
            startPt.y + (endPt.y - startPt.y) * chase,
        )
        val markerSize = 8f * scale
        drawCircle(
            color = BaseballColors.positive,
            radius = markerSize,
            center = currentFielderPt,
        )

        val fielderName = fielding.fielderName
        if (after > 0.55f && fielderName != null) {
            val fontScale = (scale / density).coerceIn(1f, 2.5f)
            val textLayout = textMeasurer.measure(
                text = fielderName,
                style = TextStyle(
                    color = BaseballColors.positive,
                    fontSize = (14f * fontScale).sp,
                    fontWeight = FontWeight.Bold,
                ),
            )
            drawText(
                textLayoutResult = textLayout,
                topLeft = Offset(currentFielderPt.x - textLayout.size.width / 2f, currentFielderPt.y - 22f * scale),
            )
        }
    }

    if (after > 0.35f) {
        val distanceMeters = (fielding?.landingDistanceTenthsMeters ?: (landing * 10).roundToInt()) / 10
        val distanceStr = "${distanceMeters}m"
        val fontScale = (scale / density).coerceIn(1f, 2.5f)
        val distLayout = textMeasurer.measure(
            text = distanceStr,
            style = TextStyle(
                color = tone,
                fontSize = (28f * fontScale).sp,
                fontWeight = FontWeight.Black,
                fontFamily = FontFamily.Monospace,
            ),
        )
        drawText(
            textLayoutResult = distLayout,
            topLeft = Offset(
                canvasSize.width - 16f * scale - distLayout.size.width,
                canvasSize.height - 14f * scale - distLayout.size.height,
            ),
        )
    }
}

// MARK: - 결과 판정 텍스트

internal fun DrawScope.drawVerdict(
    outcome: PitchOutcome?,
    label: String,
    progress: Float,
    textMeasurer: TextMeasurer,
    canvasSize: Size,
) {
    val flash = calculateVerdictFlash(progress)
    if (flash <= 0f || outcome == null) return

    val scale = min(canvasSize.width / PITCH_BOX_WIDTH, canvasSize.height / PITCH_BOX_HEIGHT)
    val fontScale = (scale / density).coerceIn(1f, 2.5f)
    val tone = outcomeTone(outcome)

    val textLayout = textMeasurer.measure(
        text = label,
        style = TextStyle(
            color = tone.copy(alpha = flash),
            fontSize = (26f * fontScale).sp,
            fontWeight = FontWeight.Black,
        ),
    )
    val rise = (1f - flash) * 16f * scale
    // A call should land like a stamp: it arrives slightly oversized and settles.
    val settle = ((progress - CONTACT_PROGRESS) / 0.10f).coerceIn(0f, 1f)
    val stamp = 1f + (1f - settle) * 0.18f
    val width = textLayout.size.width * stamp
    val height = textLayout.size.height * stamp
    val left = (canvasSize.width - width) / 2f
    val top = canvasSize.height * 0.12f + rise
    withTransform({ scale(stamp, stamp, pivot = Offset(left + width / 2f, top + height / 2f)) }) {
        drawText(
            textLayoutResult = textLayout,
            topLeft = Offset((canvasSize.width - textLayout.size.width) / 2f, top),
        )
    }
}

// MARK: - 유틸리티 및 좌표 변환

internal val PITCH_BOX_MIN_X get() = PitchPlateGeometry.worldBounds.left
internal val PITCH_BOX_MIN_Y get() = PitchPlateGeometry.worldBounds.top
internal val PITCH_BOX_WIDTH get() = PitchPlateGeometry.worldBounds.width
internal val PITCH_BOX_HEIGHT get() = PitchPlateGeometry.worldBounds.height
private const val PLATE_PLANE_Y = 205f
private const val CONTACT_PROGRESS = PitchDramaCamera.CONTACT_PROGRESS
private const val CUT_PROGRESS = PitchDramaCamera.CUT_PROGRESS

internal const val LIVE_ZONE_STROKE_ALPHA = 0.85f
internal const val LIVE_ZONE_GRID_ALPHA = 0.80f
internal const val RESULT_ZONE_STROKE_ALPHA = 0.85f
internal const val RESULT_ZONE_GRID_ALPHA = 0.80f
internal const val RESULT_TRAIL_START_ALPHA = 0.08f
internal const val RESULT_TRAIL_END_ALPHA = 0.90f
internal const val RESULT_LANDING_DOT_RADIUS_DP = 5f
internal const val RESULT_LANDING_RING_RADIUS_DP = 12f

internal fun isCatcherCutAfterContact(outcome: PitchOutcome?, progress: Float): Boolean =
    progress >= PitchDramaCamera.CONTACT_PROGRESS &&
        !PitchDramaCamera.usesFieldShot(outcome, progress)

internal fun isTakenPitchCatcherFreeze(outcome: PitchOutcome?, progress: Float): Boolean =
    isCatcherCutAfterContact(outcome, progress) &&
        outcome != null &&
        outcome !in PitchDramaCamera.FAIR_BALL_OUTCOMES

internal fun keepFullIncomingTrail(outcome: PitchOutcome?, progress: Float): Boolean =
    isTakenPitchCatcherFreeze(outcome, progress) &&
        outcome !in PitchDramaCamera.BATTED_OUTCOMES

internal fun zoneStrokeAlpha(outcome: PitchOutcome?, progress: Float, flash: Float): Float =
    if (isCatcherCutAfterContact(outcome, progress)) {
        RESULT_ZONE_STROKE_ALPHA
    } else {
        (LIVE_ZONE_STROKE_ALPHA + flash * 0.5f).coerceAtMost(1f)
    }

internal fun zoneGridAlpha(outcome: PitchOutcome?, progress: Float): Float =
    if (isCatcherCutAfterContact(outcome, progress)) {
        RESULT_ZONE_GRID_ALPHA
    } else {
        LIVE_ZONE_GRID_ALPHA
    }

internal fun platePoint(x: Double, y: Double): Offset {
    val px = min(272f, max(48f, (160.0 + x * 0.15).toFloat()))
    val py = min(292f, max(48f, (PLATE_PLANE_Y - y * 0.15).toFloat()))
    return Offset(px, py)
}

internal fun calculateReplayPoints(request: PitchPresentationRequest?, movement: Int? = null): List<Offset> {
    if (request == null) return listOf(Offset(160f, 116f), platePoint(0.0, 0.0))
    val scale = movement?.let(PitchFlightProjection::movementScale) ?: 1f
    return PitchFlightProjection.points(request, scale).map { Offset(it.x, it.y) }
}

internal fun calculateImpactPulse(progress: Float): Float {
    val window = 0.12f
    if (progress < CONTACT_PROGRESS || progress >= CONTACT_PROGRESS + window) return 0f
    return 1f - (progress - CONTACT_PROGRESS) / window
}

internal fun calculateVerdictFlash(progress: Float): Float {
    val start = CONTACT_PROGRESS + 0.04f
    if (progress < start) return 0f
    val peak = min(1f, (progress - start) / 0.1f)
    if (progress < 0.92f) return peak
    return (peak * (1f - (progress - 0.92f) / 0.08f)).coerceAtLeast(0f)
}

internal fun calculateShakeOffset(
    outcome: PitchOutcome?,
    battedBall: BattedBall?,
    progress: Float,
    scale: Float,
): Offset {
    val isBatted = outcome in PitchDramaCamera.BATTED_OUTCOMES
    val pulse = calculateImpactPulse(progress)
    if (!isBatted || pulse <= 0f) return Offset.Zero

    val quality = (battedBall?.contactQuality ?: 500) / 1000f
    val amount = 5.5f * quality * pulse * scale
    return Offset(sin(progress * 92f) * amount, cos(progress * 71f) * amount * 0.6f)
}

internal fun outcomeTone(outcome: PitchOutcome?): Color = when (outcome) {
    PitchOutcome.SWINGING_STRIKE,
    PitchOutcome.CALLED_STRIKE,
    PitchOutcome.IN_PLAY_OUT -> BaseballColors.action

    PitchOutcome.BALL,
    PitchOutcome.REACHED_ON_ERROR,
    PitchOutcome.FOUL,
    PitchOutcome.HIT_BY_PITCH -> BaseballColors.warning

    PitchOutcome.SINGLE,
    PitchOutcome.DOUBLE,
    PitchOutcome.TRIPLE,
    PitchOutcome.HOME_RUN,
    null -> BaseballColors.negative
}

internal fun localizedVerdict(outcome: PitchOutcome, battedBall: BattedBall?): String = when (outcome) {
    PitchOutcome.SWINGING_STRIKE -> "헛스윙"
    PitchOutcome.CALLED_STRIKE -> "루킹 스트라이크"
    PitchOutcome.BALL -> "볼"
    PitchOutcome.FOUL -> "파울"
    PitchOutcome.HIT_BY_PITCH -> "몸에 맞는 공"
    PitchOutcome.IN_PLAY_OUT -> {
        val tenths = battedBall?.launchAngleTenthsDegrees ?: 100
        when {
            tenths < 100 -> "땅볼 아웃"
            tenths < 250 -> "직선타 아웃"
            else -> "뜬공 아웃"
        }
    }
    PitchOutcome.REACHED_ON_ERROR -> "실책 출루"
    PitchOutcome.SINGLE -> "안타"
    PitchOutcome.DOUBLE -> "2루타"
    PitchOutcome.TRIPLE -> "3루타"
    PitchOutcome.HOME_RUN -> "홈런"
}

internal fun fielderHome(position: String?): Pair<Float, Float> = when (position) {
    "P", "pitcher" -> 18.4f to 0f
    "C", "catcher" -> 2f to 0f
    "1B", "firstBase" -> 26f to 38f
    "2B", "secondBase" -> 38f to 20f
    "3B", "thirdBase" -> 26f to -38f
    "SS", "shortstop" -> 38f to -20f
    "LF", "leftField" -> 88f to -32f
    "CF", "centerField" -> 96f to 0f
    "RF", "rightField" -> 88f to 32f
    else -> 60f to 0f
}
