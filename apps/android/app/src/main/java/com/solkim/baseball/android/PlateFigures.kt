package com.solkim.baseball.android

import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.graphics.Matrix
import androidx.compose.ui.graphics.Path

/**
 * 홈플레이트 위의 두 사람 — 타자와 포수 실루엣 벡터 패스.
 * iOS `PlateFigures.swift`와 1:1로 일치하는 단위 상자(0~1) 패스를 제공한다.
 */
public object PlateFigures {
    public const val BATTER_ASPECT: Float = 613.0f / 850.0f
    public const val CATCHER_ASPECT: Float = 694.0f / 850.0f
    public const val ASSET_OPACITY: Float = 0.13f

    /**
     * 단위 상자 안의 타자. 우타자 기본 자세 — 배트를 든 손이 뒤쪽(왼쪽 위)에 있고,
     * 몸과 시선은 투수 및 홈플레이트(오른쪽)를 향한다.
     * 좌타자는 [flipped] = true 로 반전한다.
     */
    public fun batterPath(): Path {
        val path = Path()

        // 헬멧
        path.addOval(Rect(0.300f, 0.010f, 0.450f, 0.160f))
        // 귀덮개
        path.addOval(Rect(0.283f, 0.070f, 0.368f, 0.165f))
        // 챙
        val brim = Path().apply {
            moveTo(0.420f, 0.062f)
            lineTo(0.520f, 0.076f)
            lineTo(0.518f, 0.100f)
            lineTo(0.420f, 0.096f)
            close()
        }
        path.addPath(brim)

        // 몸통
        val torso = Path().apply {
            moveTo(0.238f, 0.205f)
            quadraticTo(0.222f, 0.330f, 0.262f, 0.430f)
            lineTo(0.300f, 0.545f)
            lineTo(0.452f, 0.545f)
            quadraticTo(0.505f, 0.360f, 0.470f, 0.205f)
            close()
        }
        path.addPath(torso)

        // 뒷다리
        val backLeg = Path().apply {
            moveTo(0.300f, 0.520f)
            quadraticTo(0.214f, 0.640f, 0.196f, 0.760f)
            lineTo(0.128f, 0.960f)
            lineTo(0.222f, 0.978f)
            lineTo(0.282f, 0.782f)
            quadraticTo(0.330f, 0.660f, 0.386f, 0.545f)
            close()
        }
        path.addPath(backLeg)

        // 앞다리
        val frontLeg = Path().apply {
            moveTo(0.386f, 0.530f)
            quadraticTo(0.492f, 0.640f, 0.520f, 0.780f)
            lineTo(0.560f, 0.962f)
            lineTo(0.462f, 0.980f)
            lineTo(0.416f, 0.790f)
            quadraticTo(0.330f, 0.660f, 0.300f, 0.545f)
            close()
        }
        path.addPath(frontLeg)

        // 발
        path.addRoundRect(RoundRect(0.098f, 0.948f, 0.248f, 0.990f, CornerRadius(0.018f, 0.018f)))
        path.addRoundRect(RoundRect(0.450f, 0.950f, 0.600f, 0.992f, CornerRadius(0.018f, 0.018f)))

        // 양팔
        val arms = Path().apply {
            moveTo(0.250f, 0.215f)
            quadraticTo(0.246f, 0.150f, 0.330f, 0.118f)
            lineTo(0.500f, 0.150f)
            lineTo(0.494f, 0.216f)
            lineTo(0.352f, 0.196f)
            quadraticTo(0.318f, 0.214f, 0.318f, 0.262f)
            close()
        }
        path.addPath(arms)

        // 손
        path.addOval(Rect(0.474f, 0.140f, 0.544f, 0.220f))

        // 배트
        val bat = Path().apply {
            moveTo(0.500f, 0.196f)
            lineTo(0.518f, 0.150f)
            lineTo(0.940f, 0.020f)
            lineTo(0.980f, 0.062f)
            lineTo(0.548f, 0.216f)
            close()
        }
        path.addPath(bat)

        // 노브
        path.addOval(Rect(0.478f, 0.186f, 0.534f, 0.236f))

        return path
    }

    /**
     * 단위 상자 안의 포수. 존 아래에 등을 보이고 앉아 있다.
     */
    public fun catcherPath(): Path {
        val path = Path()

        // 마스크
        path.addOval(Rect(0.395f, 0.020f, 0.605f, 0.235f))

        // 등/몸통
        val back = Path().apply {
            moveTo(0.300f, 0.330f)
            quadraticTo(0.352f, 0.228f, 0.500f, 0.205f)
            quadraticTo(0.648f, 0.228f, 0.700f, 0.330f)
            quadraticTo(0.800f, 0.520f, 0.760f, 0.720f)
            lineTo(0.240f, 0.720f)
            quadraticTo(0.200f, 0.520f, 0.300f, 0.330f)
            close()
        }
        path.addPath(back)

        // 무릎
        path.addOval(Rect(0.075f, 0.560f, 0.365f, 0.850f))
        path.addOval(Rect(0.635f, 0.560f, 0.925f, 0.850f))

        // 발끝
        path.addRoundRect(RoundRect(0.100f, 0.850f, 0.330f, 0.960f, CornerRadius(0.045f, 0.045f)))
        path.addRoundRect(RoundRect(0.670f, 0.850f, 0.900f, 0.960f, CornerRadius(0.045f, 0.045f)))

        return path
    }

    /**
     * 단위 상자의 도형을 실제 사각형으로 변환한다. [flipped]이면 좌우 반전.
     */
    public fun scaled(unitPath: Path, rect: Rect, flipped: Boolean = false): Path {
        val path = Path().apply { addPath(unitPath) }
        val matrix = Matrix().apply {
            translate(rect.left, rect.top)
            scale(rect.width, rect.height)
            if (flipped) {
                translate(1f, 0f)
                scale(-1f, 1f)
            }
        }
        path.transform(matrix)
        return path
    }
}
