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
    aimingZone: com.solkim.baseball.application.PitchZone? = null,
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
                aimingZone = aimingZone,
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
