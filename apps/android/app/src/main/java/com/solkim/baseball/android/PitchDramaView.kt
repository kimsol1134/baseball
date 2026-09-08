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
@Composable
public fun PitchDramaView(
    request: PitchPresentationRequest?,
    outcome: PitchOutcome?,
    battedBall: BattedBall? = null,
    fielding: FieldingResolutionSnapshot? = null,
    batSide: BatSide = BatSide.RIGHT,
    progress: Float = 0f,
    modifier: Modifier = Modifier,
    perfect: Boolean = false,
    movement: Int? = null,
    reduceMotion: Boolean = false,
) {
    val textMeasurer = rememberTextMeasurer()
    val copy = rememberGameCopy()
    val verdict = remember(outcome, battedBall, copy) { outcome?.let { copy.legacy(localizedVerdict(it, battedBall)) }.orEmpty() }
    val replayPoints = remember(request, movement) { calculateReplayPoints(request, movement) }
    val displayFielding = remember(fielding, copy) {
        fielding?.copy(fielderName = fielding.fielderName?.let { copy.legacy(it) })
    }
    val context = LocalContext.current
    val batterBitmap = remember(context) {
        runCatching {
            BitmapFactory.decodeResource(context.resources, R.drawable.batter_stance)?.asImageBitmap()
        }.getOrNull()
    }
    val catcherBitmap = remember(context) {
        runCatching {
            BitmapFactory.decodeResource(context.resources, R.drawable.catcher_stance)?.asImageBitmap()
        }.getOrNull()
    }

    Canvas(
        modifier = modifier
            .fillMaxSize()
            .semantics {
                contentDescription = copy.legacy(PitchDramaCamera.accessibility(
                    outcome,
                    battedBall,
                    displayFielding,
                    progress,
                    ::localizedVerdict,
                ))
            },
    ) {
        val size = this.size
        drawRect(color = BaseballColors.fieldNight)

        val inFieldShot = PitchDramaCamera.usesFieldShot(outcome, progress)

        if (inFieldShot) {
            drawFieldShot(
                progress = progress,
                outcome = outcome,
                battedBall = battedBall,
                fielding = displayFielding,
                textMeasurer = textMeasurer,
                canvasSize = size,
            )
        } else {
            drawPitchShot(
                request = request,
                replayPoints = replayPoints,
                outcome = outcome,
                battedBall = battedBall,
                batSide = batSide,
                batterBitmap = batterBitmap,
                catcherBitmap = catcherBitmap,
                progress = progress,
                canvasSize = size,
                perfect = perfect,
                reduceMotion = reduceMotion,
            )
        }

        // 판정 결과 텍스트 오버레이
        drawVerdict(
            outcome = outcome,
            label = verdict,
            progress = progress,
            textMeasurer = textMeasurer,
            canvasSize = size,
        )
    }
}

// MARK: - 1컷 · 포수 시점

private fun DrawScope.drawPitchShot(
    request: PitchPresentationRequest?,
    replayPoints: List<Offset>,
    outcome: PitchOutcome?,
    battedBall: BattedBall?,
    batSide: BatSide,
    batterBitmap: ImageBitmap?,
    catcherBitmap: ImageBitmap?,
    progress: Float,
    canvasSize: Size,
    perfect: Boolean = false,
    reduceMotion: Boolean = false,
) {
    val scale = min(canvasSize.width / PITCH_BOX_WIDTH, canvasSize.height / PITCH_BOX_HEIGHT)
    val shake = calculateShakeOffset(outcome, battedBall, progress, scale)
    val offsetX = (canvasSize.width - PITCH_BOX_WIDTH * scale) / 2f - PITCH_BOX_MIN_X * scale + shake.x
    val offsetY = (canvasSize.height - PITCH_BOX_HEIGHT * scale) / 2f - PITCH_BOX_MIN_Y * scale + shake.y

    fun place(pt: Offset): Offset = Offset(offsetX + pt.x * scale, offsetY + pt.y * scale)

    // 조명
    drawStadiumLight(canvasSize)

    // 타자 / 포수 실루엣
    drawBatterAndCatcher(batSide, batterBitmap, catcherBitmap, scale, ::place)

    // 스트라이크 존 & 홈플레이트
    drawStrikeZoneAndPlate(outcome, progress, scale, ::place)

    val actualX = request?.plateXMm?.toDouble() ?: 0.0
    val actualY = request?.plateYMm?.toDouble() ?: 0.0
    val takenFreeze = isTakenPitchCatcherFreeze(outcome, progress)
    // 결과 프리즈의 착지 링은 궤적 위에 올려야 점이 가려지지 않는다.
    if (!takenFreeze) {
        drawCatcherMitt(outcome, progress, actualX, actualY, scale, ::place, request?.velocityDeciKph ?: 0, reduceMotion)
    }

    // 날아오는 공 & 맞은 뒤 떠나는 공
    drawIncomingBall(replayPoints, outcome, battedBall, progress, scale, ::place, perfect, reduceMotion, request?.velocityDeciKph ?: 0)

    if (takenFreeze) {
        drawCatcherMitt(outcome, progress, actualX, actualY, scale, ::place, request?.velocityDeciKph ?: 0, reduceMotion)
    }

    // 배트 컨택 시 임팩트 섬광
    drawImpactBurst(outcome, battedBall, actualX, actualY, progress, scale, ::place)
}

private fun DrawScope.drawStadiumLight(size: Size) {
    val center = Offset(size.width / 2f, size.height * 0.16f)
    val radius = size.height * 0.9f
    drawOval(
        brush = Brush.radialGradient(
            colors = listOf(BaseballColors.action.copy(alpha = 0.085f), Color.Transparent),
            center = center,
            radius = radius,
        ),
        topLeft = Offset(center.x - radius, center.y - radius * 0.7f),
        size = Size(radius * 2f, radius * 1.7f),
    )
}

private fun DrawScope.drawBatterAndCatcher(
    batSide: BatSide,
    batterBitmap: ImageBitmap?,
    catcherBitmap: ImageBitmap?,
    scale: Float,
    place: (Offset) -> Offset,
) {
    val zoneTopLeft = place(platePoint(-500.0, 500.0))
    val zoneBottomRight = place(platePoint(500.0, -500.0))
    val zoneWidth = zoneBottomRight.x - zoneTopLeft.x
    val zoneHeight = zoneBottomRight.y - zoneTopLeft.y

    val ink = BaseballColors.fieldChalk.copy(alpha = 0.11f)

    // 타자 실루엣
    val batterHeight = zoneHeight * 1.46f
    val batterWidth = batterHeight * PlateFigures.BATTER_ASPECT
    val isLeftBatter = batSide == BatSide.LEFT
    val batterLeft = if (isLeftBatter) {
        zoneBottomRight.x + zoneWidth * 0.10f - batterWidth * 0.34f
    } else {
        zoneTopLeft.x - zoneWidth * 0.10f - batterWidth * 0.66f
    }
    val batterTop = zoneBottomRight.y + zoneHeight * 0.34f - batterHeight
    val batterRect = Rect(batterLeft, batterTop, batterLeft + batterWidth, batterTop + batterHeight)

    if (batterBitmap != null) {
        withTransform({
            if (isLeftBatter) {
                translate(batterRect.center.x, 0f)
                scale(-1f, 1f, Offset.Zero)
                translate(-batterRect.center.x, 0f)
            }
        }) {
            drawImage(
                image = batterBitmap,
                dstOffset = IntOffset(batterRect.left.roundToInt(), batterRect.top.roundToInt()),
                dstSize = IntSize(batterRect.width.roundToInt(), batterRect.height.roundToInt()),
                alpha = PlateFigures.ASSET_OPACITY,
            )
        }
    } else {
        val batterPath = PlateFigures.scaled(PlateFigures.batterPath(), batterRect, flipped = isLeftBatter)
        drawPath(batterPath, color = ink, style = Fill)
    }

    // 포수 실루엣
    val catcherWidth = zoneWidth * 1.18f
    val catcherHeight = catcherWidth / PlateFigures.CATCHER_ASPECT
    val catcherLeft = (zoneTopLeft.x + zoneBottomRight.x) / 2f - catcherWidth / 2f
    val catcherTop = zoneBottomRight.y + zoneHeight * 0.02f
    val catcherRect = Rect(catcherLeft, catcherTop, catcherLeft + catcherWidth, catcherTop + catcherHeight)

    if (catcherBitmap != null) {
        drawImage(
            image = catcherBitmap,
            dstOffset = IntOffset(catcherRect.left.roundToInt(), catcherRect.top.roundToInt()),
            dstSize = IntSize(catcherRect.width.roundToInt(), catcherRect.height.roundToInt()),
            alpha = PlateFigures.ASSET_OPACITY,
        )
    } else {
        val catcherPath = PlateFigures.scaled(PlateFigures.catcherPath(), catcherRect, flipped = false)
        drawPath(catcherPath, color = ink, style = Fill)
    }
}

private fun DrawScope.drawStrikeZoneAndPlate(
    outcome: PitchOutcome?,
    progress: Float,
    scale: Float,
    place: (Offset) -> Offset,
) {
    val topLeft = place(platePoint(-500.0, 500.0))
    val bottomRight = place(platePoint(500.0, -500.0))
    val zoneRect = Rect(topLeft.x, topLeft.y, bottomRight.x, bottomRight.y)

    val isStrike = outcome == PitchOutcome.CALLED_STRIKE || outcome == PitchOutcome.SWINGING_STRIKE
    val flash = if (isStrike) calculateVerdictFlash(progress) else 0f
    val strokeAlpha = zoneStrokeAlpha(outcome, progress, flash)
    val gridAlpha = zoneGridAlpha(outcome, progress)

    // 스트라이크 시 존 플래시
    if (flash > 0f) {
        drawRect(
            color = BaseballColors.action.copy(alpha = flash * 0.18f),
            topLeft = zoneRect.topLeft,
            size = zoneRect.size,
        )
    }

    // 존 외곽선. 컨택 이후 포수 컷은 iOS 결과 프리즈처럼 밝게 유지한다.
    drawRect(
        color = BaseballColors.fieldChalk.copy(alpha = strokeAlpha),
        topLeft = zoneRect.topLeft,
        size = zoneRect.size,
        style = Stroke(width = max(1f, (1.3f + flash * 1.8f) * scale)),
    )

    // 3x3 그리드
    val gridColor = BaseballColors.fieldChalk.copy(alpha = gridAlpha)
    val gridStroke = Stroke(width = max(0.5f, scale))
    for (step in 1..2) {
        val ratio = step / 3f
        val x = zoneRect.left + zoneRect.width * ratio
        drawLine(gridColor, Offset(x, zoneRect.top), Offset(x, zoneRect.bottom), strokeWidth = gridStroke.width)
        val y = zoneRect.top + zoneRect.height * ratio
        drawLine(gridColor, Offset(zoneRect.left, y), Offset(zoneRect.right, y), strokeWidth = gridStroke.width)
    }

    // 홈플레이트 5각형
    val plateY = zoneRect.bottom + 30f * scale
    val half = zoneRect.width * 0.46f
    val platePath = Path().apply {
        moveTo(zoneRect.center.x - half, plateY)
        lineTo(zoneRect.center.x + half, plateY)
        lineTo(zoneRect.center.x + half * 0.72f, plateY + 11f * scale)
        lineTo(zoneRect.center.x, plateY + 19f * scale)
        lineTo(zoneRect.center.x - half * 0.72f, plateY + 11f * scale)
        close()
    }
    drawPath(platePath, color = BaseballColors.fieldChalk.copy(alpha = 0.42f), style = Fill)
}

private fun DrawScope.drawCatcherMitt(
    outcome: PitchOutcome?,
    progress: Float,
    actualX: Double,
    actualY: Double,
    scale: Float,
    place: (Offset) -> Offset,
    velocityTenthsKph: Int = 0,
    reduceMotion: Boolean = false,
) {
    if (outcome in PitchDramaCamera.FAIR_BALL_OUTCOMES) return

    val target = place(platePoint(actualX, actualY))
    if (isTakenPitchCatcherFreeze(outcome, progress)) {
        val ringColor = outcomeTone(outcome)
        val ringRadius = RESULT_LANDING_RING_RADIUS_DP.dp.toPx()
        val dotRadius = RESULT_LANDING_DOT_RADIUS_DP.dp.toPx()
        val ringStroke = max(2f, 2.2.dp.toPx())
        val hit = ((progress - PitchDramaCamera.CONTACT_PROGRESS) / 0.14f).coerceIn(0f, 1f)
        if (!reduceMotion && hit < 1f) {
            val impact = com.solkim.baseball.application.PitchGrowthFeel.impactScale(velocityTenthsKph)
            drawCircle(BaseballColors.fieldChalk.copy(alpha = (1f - hit) * 0.55f),
                radius = ringRadius * (1f + hit * impact), center = target,
                style = Stroke(width = ringStroke * impact))
        }
        drawCircle(
            color = BaseballColors.fieldChalk.copy(alpha = 0.55f),
            radius = ringRadius * 1.35f,
            center = target,
            style = Stroke(width = max(1.2f, 1.4.dp.toPx()), cap = StrokeCap.Round),
        )
        drawCircle(
            color = ringColor.copy(alpha = 0.95f),
            radius = ringRadius,
            center = target,
            style = Stroke(width = ringStroke, cap = StrokeCap.Round),
        )
        drawCircle(
            color = BaseballColors.fieldChalk,
            radius = dotRadius,
            center = target,
        )
        return
    }

    val radius = 11f * scale
    val strokeWidth = max(1f, 1.4f * scale)
    drawCircle(
        color = BaseballColors.fieldDirt.copy(alpha = 0.35f),
        radius = radius,
        center = target,
        style = Stroke(
            width = strokeWidth,
            pathEffect = PathEffect.dashPathEffect(floatArrayOf(4f * scale, 4f * scale)),
        ),
    )
}

private fun DrawScope.drawIncomingBall(
    points: List<Offset>,
    outcome: PitchOutcome?,
    battedBall: BattedBall?,
    progress: Float,
    scale: Float,
    place: (Offset) -> Offset,
    perfect: Boolean = false,
    reduceMotion: Boolean = false,
    velocityTenthsKph: Int = 0,
) {
    if (points.size < 2) return

    val speedScale = com.solkim.baseball.application.PitchGrowthFeel.trailScale(velocityTenthsKph)
    val flight = PitchDramaCamera.incomingFlight(progress)
    val takenFreeze = isTakenPitchCatcherFreeze(outcome, progress)
    val freezeTrail = keepFullIncomingTrail(outcome, progress)
    val position = (if (takenFreeze) 1f else flight.coerceIn(0f, 1f)) * points.lastIndex
    val lastIndex = position.toInt().coerceAtMost(points.lastIndex)
    val partialHead = if (lastIndex == points.lastIndex) points.last() else {
        val a = points[lastIndex]; val b = points[lastIndex + 1]; val t = position - lastIndex
        Offset(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
    }
    // A perfect release flies gold until the mitt; the result colour takes over at the freeze.
    val tone = if (perfect && !takenFreeze) BaseballColors.milestone else outcomeTone(outcome)
    val departingT = PitchDramaCamera.departureProgress(outcome, progress)

    val trailPath = Path().apply {
        moveTo(place(points[0]).x, place(points[0]).y)
        for (i in 1..lastIndex) {
            val pt = place(points[i])
            lineTo(pt.x, pt.y)
        }
        val head = place(partialHead)
        lineTo(head.x, head.y)
    }
    val startPt = place(points.first())
    val endPt = place(partialHead)
    val trailStartAlpha = if (takenFreeze) RESULT_TRAIL_START_ALPHA else 0.04f
    val trailEndAlpha = if (takenFreeze) RESULT_TRAIL_END_ALPHA else (0.55f + 0.4f * flight)
    val trailWidth = if (takenFreeze) {
        max(2f, 3.6f * scale)
    } else {
        max(1.6f, (2.2f + 5.6f * flight) * scale * speedScale)
    }
    drawPath(
        trailPath,
        brush = Brush.linearGradient(
            colors = listOf(tone.copy(alpha = trailStartAlpha), tone.copy(alpha = trailEndAlpha)),
            start = startPt,
            end = endPt,
        ),
        style = Stroke(width = trailWidth, cap = StrokeCap.Round, join = StrokeJoin.Round),
    )
    if (!takenFreeze && lastIndex >= 3 && departingT <= 0f) {
        val streakFrom = place(points[lastIndex - 3])
        drawLine(
            color = (if (perfect) BaseballColors.milestone else BaseballColors.fieldChalk).copy(alpha = 0.35f + 0.45f * flight),
            start = streakFrom,
            end = endPt,
            strokeWidth = max(2.4f, (3.2f + 4.8f * flight) * scale * speedScale),
            cap = StrokeCap.Round,
        )
    }

    val plate = points.last()
    val head = if (departingT > 0f) {
        val delta = PitchDramaCamera.departingBallDelta(outcome, battedBall, departingT)
        Offset(plate.x + delta.x, plate.y + delta.y)
    } else {
        partialHead
    }
    if (departingT > 0f) {
        val from = place(plate)
        val to = place(head)
        drawLine(
            color = tone.copy(alpha = 0.9f),
            start = from,
            end = to,
            strokeWidth = max(1.8f, 3.2f * scale),
            cap = StrokeCap.Round,
        )
    }

    // 논배트 프리즈의 착지점은 미트의 링+점이 그린다.
    if (freezeTrail) return

    val center = place(head)
    val recede = if (departingT > 0f) 1f - 0.55f * departingT else flight
    val approach = recede * recede
    val radius = (1.7f + 2.4f * recede + 5.2f * approach) * scale

    drawCircle(
        brush = Brush.radialGradient(
            colors = listOf(BaseballColors.fieldChalk.copy(alpha = 0.22f * recede), Color.Transparent),
            center = center,
            radius = radius * 2f,
        ),
        radius = radius * 2f,
        center = center,
    )
    drawCircle(
        color = BaseballColors.fieldChalk,
        radius = radius,
        center = center,
    )
    if (!reduceMotion) drawBallSeams(center, radius, progress, perfect)
}

/**
 * Two seams turning with the flight. A plain white dot reads as a marker; a turning ball reads as a
 * pitch, and it is the cheapest way to sell speed on a flat 2D field.
 */
private fun DrawScope.drawBallSeams(center: Offset, radius: Float, progress: Float, perfect: Boolean) {
    if (radius < 3.2f) return
    val turn = progress * 1_080f
    val seam = if (perfect) BaseballColors.milestone else BaseballColors.fieldDirt
    val box = androidx.compose.ui.geometry.Rect(
        center.x - radius * 0.82f,
        center.y - radius * 0.82f,
        center.x + radius * 0.82f,
        center.y + radius * 0.82f,
    )
    for (side in 0..1) {
        drawArc(
            color = seam.copy(alpha = 0.85f),
            startAngle = turn + side * 180f,
            sweepAngle = 76f,
            useCenter = false,
            topLeft = box.topLeft,
            size = box.size,
            style = Stroke(width = kotlin.math.max(1f, radius * 0.22f), cap = StrokeCap.Round),
        )
    }
}

private fun DrawScope.drawImpactBurst(
    outcome: PitchOutcome?,
    battedBall: BattedBall?,
    actualX: Double,
    actualY: Double,
    progress: Float,
    scale: Float,
    place: (Offset) -> Offset,
) {
    val pulse = calculateImpactPulse(progress)
    if (pulse <= 0f) return

    val isBatted = outcome in PitchDramaCamera.BATTED_OUTCOMES
    val target = place(platePoint(actualX, actualY))
    val quality = (battedBall?.contactQuality ?: 400) / 1000f
    val burst = when {
        outcome == PitchOutcome.FOUL -> 22f
        isBatted -> 30f + 46f * quality
        else -> 20f
    }
    val radius = burst * scale * pulse
    val tone = outcomeTone(outcome)

    drawCircle(
        brush = Brush.radialGradient(
            colors = listOf(
                BaseballColors.fieldChalk.copy(alpha = 0.9f * pulse),
                tone.copy(alpha = 0.4f * pulse),
                Color.Transparent,
            ),
            center = target,
            radius = radius,
        ),
        radius = radius,
        center = target,
    )
}

// MARK: - 2컷 · 탑다운 타구 시점

private fun DrawScope.drawFieldShot(
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

private fun DrawScope.drawVerdict(
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

private const val PITCH_BOX_MIN_X = 46f
private const val PITCH_BOX_MIN_Y = 62f
private const val PITCH_BOX_WIDTH = 228f
private const val PITCH_BOX_HEIGHT = 246f
private const val PLATE_PLANE_Y = 205f
private const val CONTACT_PROGRESS = PitchDramaCamera.CONTACT_PROGRESS
private const val CUT_PROGRESS = PitchDramaCamera.CUT_PROGRESS

internal const val LIVE_ZONE_STROKE_ALPHA = 0.50f
internal const val LIVE_ZONE_GRID_ALPHA = 0.16f
internal const val RESULT_ZONE_STROKE_ALPHA = 0.85f
internal const val RESULT_ZONE_GRID_ALPHA = 0.40f
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
        LIVE_ZONE_STROKE_ALPHA + flash * 0.5f
    }

internal fun zoneGridAlpha(outcome: PitchOutcome?, progress: Float): Float =
    if (isCatcherCutAfterContact(outcome, progress)) {
        RESULT_ZONE_GRID_ALPHA
    } else {
        LIVE_ZONE_GRID_ALPHA
    }

private fun platePoint(x: Double, y: Double): Offset {
    val px = min(272f, max(48f, (160.0 + x * 0.15).toFloat()))
    val py = min(292f, max(48f, (PLATE_PLANE_Y - y * 0.15).toFloat()))
    return Offset(px, py)
}

private fun calculateReplayPoints(request: PitchPresentationRequest?, movement: Int? = null): List<Offset> {
    if (request == null) return listOf(Offset(160f, 116f), platePoint(0.0, 0.0))
    val scale = movement?.let(PitchFlightProjection::movementScale) ?: 1f
    return PitchFlightProjection.points(request, scale).map { Offset(it.x, it.y) }
}

private fun calculateImpactPulse(progress: Float): Float {
    val window = 0.12f
    if (progress < CONTACT_PROGRESS || progress >= CONTACT_PROGRESS + window) return 0f
    return 1f - (progress - CONTACT_PROGRESS) / window
}

private fun calculateVerdictFlash(progress: Float): Float {
    val start = CONTACT_PROGRESS + 0.04f
    if (progress < start) return 0f
    val peak = min(1f, (progress - start) / 0.1f)
    if (progress < 0.92f) return peak
    return (peak * (1f - (progress - 0.92f) / 0.08f)).coerceAtLeast(0f)
}

private fun calculateShakeOffset(
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
