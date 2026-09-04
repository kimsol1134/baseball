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
import androidx.compose.ui.unit.sp
import com.solkim.baseball.application.BatSide
import com.solkim.baseball.application.BattedBall
import com.solkim.baseball.application.FieldingResolutionSnapshot
import com.solkim.baseball.application.PitchDramaCamera
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
    progress: Float,
    modifier: Modifier = Modifier,
) {
    val textMeasurer = rememberTextMeasurer()
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
                contentDescription = PitchDramaCamera.accessibility(
                    outcome,
                    battedBall,
                    fielding,
                    progress,
                    ::localizedVerdict,
                )
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
                fielding = fielding,
                textMeasurer = textMeasurer,
                canvasSize = size,
            )
        } else {
            drawPitchShot(
                request = request,
                outcome = outcome,
                battedBall = battedBall,
                batSide = batSide,
                batterBitmap = batterBitmap,
                catcherBitmap = catcherBitmap,
                progress = progress,
                canvasSize = size,
            )
        }

        // 판정 결과 텍스트 오버레이
        drawVerdict(
            outcome = outcome,
            battedBall = battedBall,
            progress = progress,
            textMeasurer = textMeasurer,
            canvasSize = size,
        )
    }
}

// MARK: - 1컷 · 포수 시점

private fun DrawScope.drawPitchShot(
    request: PitchPresentationRequest?,
    outcome: PitchOutcome?,
    battedBall: BattedBall?,
    batSide: BatSide,
    batterBitmap: ImageBitmap?,
    catcherBitmap: ImageBitmap?,
    progress: Float,
    canvasSize: Size,
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

    // 포수 미트
    val actualX = request?.plateXMm?.toDouble() ?: 0.0
    val actualY = request?.plateYMm?.toDouble() ?: 0.0
    drawCatcherMitt(outcome, progress, actualX, actualY, scale, ::place)

    // 날아오는 공 & 맞은 뒤 떠나는 공
    drawIncomingBall(request, outcome, battedBall, progress, scale, ::place)

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

    // 스트라이크 시 존 플래시
    if (flash > 0f) {
        drawRect(
            color = BaseballColors.action.copy(alpha = flash * 0.18f),
            topLeft = zoneRect.topLeft,
            size = zoneRect.size,
        )
    }

    // 존 외곽선
    drawRect(
        color = BaseballColors.fieldChalk.copy(alpha = 0.5f + flash * 0.5f),
        topLeft = zoneRect.topLeft,
        size = zoneRect.size,
        style = Stroke(width = max(1f, (1.3f + flash * 1.8f) * scale)),
    )

    // 3x3 그리드
    val gridColor = BaseballColors.fieldChalk.copy(alpha = 0.16f)
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
) {
    val isBatted = outcome in PitchDramaCamera.BATTED_OUTCOMES
    if (isBatted) return

    val caught = progress >= CONTACT_PROGRESS
    val target = place(platePoint(actualX, actualY))
    val radius = (if (caught) 15f else 11f) * scale
    val color = BaseballColors.fieldDirt.copy(alpha = if (caught) 0.95f else 0.35f)
    val strokeWidth = max(1f, (if (caught) 3.4f else 1.4f) * scale)
    val style = if (caught) {
        Stroke(width = strokeWidth)
    } else {
        Stroke(width = strokeWidth, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4f * scale, 4f * scale)))
    }
    drawCircle(color = color, radius = radius, center = target, style = style)
}

private fun DrawScope.drawIncomingBall(
    request: PitchPresentationRequest?,
    outcome: PitchOutcome?,
    battedBall: BattedBall?,
    progress: Float,
    scale: Float,
    place: (Offset) -> Offset,
) {
    val points = calculateReplayPoints(request)
    if (points.size < 2) return

    val flight = PitchDramaCamera.incomingFlight(progress)
    val shownCount = max(2, (points.size * flight).roundToInt())
    val visiblePoints = points.take(shownCount)
    val tone = outcomeTone(outcome)
    val departingT = PitchDramaCamera.departureProgress(outcome, progress)

    val trailPath = Path().apply {
        moveTo(place(visiblePoints[0]).x, place(visiblePoints[0]).y)
        for (i in 1 until visiblePoints.size) {
            val pt = place(visiblePoints[i])
            lineTo(pt.x, pt.y)
        }
    }
    val startPt = place(visiblePoints.first())
    val endPt = place(visiblePoints.last())
    val trailWidth = max(1.6f, (2.2f + 5.6f * flight) * scale)
    drawPath(
        trailPath,
        brush = Brush.linearGradient(
            colors = listOf(tone.copy(alpha = 0.04f), tone.copy(alpha = 0.55f + 0.4f * flight)),
            start = startPt,
            end = endPt,
        ),
        style = Stroke(width = trailWidth, cap = StrokeCap.Round, join = StrokeJoin.Round),
    )
    if (visiblePoints.size >= 4 && departingT <= 0f) {
        val streakFrom = place(visiblePoints[visiblePoints.size - 4])
        drawLine(
            color = BaseballColors.fieldChalk.copy(alpha = 0.35f + 0.45f * flight),
            start = streakFrom,
            end = endPt,
            strokeWidth = max(2.4f, (3.2f + 4.8f * flight) * scale),
            cap = StrokeCap.Round,
        )
    }

    val plate = points.last()
    val head = if (departingT > 0f) {
        val delta = PitchDramaCamera.departingBallDelta(outcome, battedBall, departingT)
        Offset(plate.x + delta.x, plate.y + delta.y)
    } else {
        visiblePoints.last()
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

    val center = place(head)
    val caught = (outcome !in PitchDramaCamera.BATTED_OUTCOMES) && progress >= CONTACT_PROGRESS
    val recede = if (departingT > 0f) 1f - 0.55f * departingT else flight
    val approach = recede * recede
    val radius = (if (caught) 3.2f else 1.7f + 2.4f * recede + 5.2f * approach) * scale

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
    battedBall: BattedBall?,
    progress: Float,
    textMeasurer: TextMeasurer,
    canvasSize: Size,
) {
    val flash = calculateVerdictFlash(progress)
    if (flash <= 0f || outcome == null) return

    val scale = min(canvasSize.width / PITCH_BOX_WIDTH, canvasSize.height / PITCH_BOX_HEIGHT)
    val fontScale = (scale / density).coerceIn(1f, 2.5f)
    val label = localizedVerdict(outcome, battedBall)
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
    drawText(
        textLayoutResult = textLayout,
        topLeft = Offset(
            (canvasSize.width - textLayout.size.width) / 2f,
            canvasSize.height * 0.12f + rise,
        ),
    )
}

// MARK: - 유틸리티 및 좌표 변환

private const val PITCH_BOX_MIN_X = 46f
private const val PITCH_BOX_MIN_Y = 62f
private const val PITCH_BOX_WIDTH = 228f
private const val PITCH_BOX_HEIGHT = 246f
private const val PLATE_PLANE_Y = 205f
private const val CONTACT_PROGRESS = PitchDramaCamera.CONTACT_PROGRESS
private const val CUT_PROGRESS = PitchDramaCamera.CUT_PROGRESS

private fun platePoint(x: Double, y: Double): Offset {
    val px = min(272f, max(48f, (160.0 + x * 0.15).toFloat()))
    val py = min(292f, max(48f, (PLATE_PLANE_Y - y * 0.15).toFloat()))
    return Offset(px, py)
}

private fun calculateReplayPoints(request: PitchPresentationRequest?): List<Offset> {
    val release = Offset(160f, 116f)
    val actual = platePoint(
        request?.plateXMm?.toDouble() ?: 0.0,
        request?.plateYMm?.toDouble() ?: 0.0,
    )
    val trajectory = request?.trajectory
    if (trajectory == null || trajectory.size < 2) {
        return (0..24).map { step ->
            val t = step / 24f
            Offset(release.x + (actual.x - release.x) * t, release.y + (actual.y - release.y) * t)
        }
    }

    val first = trajectory.first()
    val last = trajectory.last()
    val spanZ = max(1f, (first.zMm - last.zMm).toFloat())

    val rawProjected = trajectory.map { pt ->
        val t = min(1f, max(0f, (first.zMm - pt.zMm) / spanZ))
        val lateralScale = 0.035f + (0.093f - 0.035f) * t
        val refHeight = first.yMm + (750 - first.yMm) * t
        val verticalScale = 0.070f + (0.160f - 0.070f) * t
        val x = 160f + pt.xMm * lateralScale
        val y = (116f + (PLATE_PLANE_Y - 116f) * t) - (pt.yMm - refHeight) * verticalScale
        Offset(x, y)
    }

    val tail = rawProjected.last()
    val dx = actual.x - tail.x
    val dy = actual.y - tail.y
    return rawProjected.mapIndexed { index, pt ->
        val weight = index / max(1f, (rawProjected.size - 1).toFloat())
        Offset(pt.x + dx * weight, pt.y + dy * weight)
    }
}

private fun calculateImpactPulse(progress: Float): Float {
    val window = 0.12f
    if (progress < CONTACT_PROGRESS || progress >= CONTACT_PROGRESS + window) return 0f
    return 1f - (progress - CONTACT_PROGRESS) / window
}

private fun calculateVerdictFlash(progress: Float): Float {
    val start = CONTACT_PROGRESS + 0.04f
    if (progress < start) return 0f
    return min(1f, (progress - start) / 0.1f)
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
    PitchOutcome.FOUL,
    PitchOutcome.HIT_BY_PITCH -> BaseballColors.warning

    PitchOutcome.SINGLE,
    PitchOutcome.DOUBLE,
    PitchOutcome.TRIPLE,
    PitchOutcome.HOME_RUN,
    null -> BaseballColors.negative
}

internal fun localizedVerdict(outcome: PitchOutcome, battedBall: BattedBall?): String = when (outcome) {
    PitchOutcome.SWINGING_STRIKE -> "헛스윙 삼진"
    PitchOutcome.CALLED_STRIKE -> "루킹 스트라이크"
    PitchOutcome.BALL -> "볼"
    PitchOutcome.FOUL -> "파울"
    PitchOutcome.HIT_BY_PITCH -> "몸에 맞는 공"
    PitchOutcome.IN_PLAY_OUT -> {
        val angle = (battedBall?.launchAngleTenthsDegrees ?: 100) / 10
        if (angle >= 25) "뜬공 아웃" else "땅볼 아웃"
    }
    PitchOutcome.SINGLE -> "1루타"
    PitchOutcome.DOUBLE -> "2루타"
    PitchOutcome.TRIPLE -> "3루타"
    PitchOutcome.HOME_RUN -> "홈런!"
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
