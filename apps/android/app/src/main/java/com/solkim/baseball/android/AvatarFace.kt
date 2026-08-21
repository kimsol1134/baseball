package com.solkim.baseball.android

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.solkim.baseball.core.portrait.AvatarParts
import com.solkim.baseball.core.portrait.AvatarRole
import com.solkim.baseball.design.BaseballColors

@Composable
public fun AvatarFace(
    seed: String,
    modifier: Modifier = Modifier,
    role: AvatarRole = AvatarRole.PLAYER,
    width: Dp = 58.dp,
) {
    val parts = AvatarParts.of(seed, role)
    Canvas(modifier.size(width, width * 76f / 58f)) {
        val scale = minOf(size.width / 58f, size.height / 76f)
        scale(scale, scale, pivot = Offset.Zero) {
            drawAvatar(parts)
        }
    }
}

private fun DrawScope.drawAvatar(parts: AvatarParts) {
    val skin = BaseballColors.avatarSkin[parts.skinIndex]
    val hair = BaseballColors.avatarHair[parts.hairColorIndex.coerceIn(0, 3)]
    val jersey = BaseballColors.avatarJersey[parts.jerseyIndex]
    val line = BaseballColors.avatarLine
    val rx = parts.faceRadiusX.toFloat()
    val ry = parts.faceRadiusY.toFloat()

    drawRoundRect(jersey.copy(alpha = 0.28f), size = Size(58f, 76f), cornerRadius = androidx.compose.ui.geometry.CornerRadius(9f, 9f))
    val shoulders = Path().apply {
        moveTo(9f, 76f)
        quadraticBezierTo(9f, 58f, 29f, 57f)
        quadraticBezierTo(49f, 58f, 49f, 76f)
        close()
    }
    drawPath(shoulders, jersey)
    drawRoundRect(skin.copy(alpha = 0.9f), topLeft = Offset(25f, 57f), size = Size(8f, 9f), cornerRadius = androidx.compose.ui.geometry.CornerRadius(3f, 3f))
    drawRoundRect(skin, topLeft = Offset(25.4f, 49f), size = Size(7.2f, 9f), cornerRadius = androidx.compose.ui.geometry.CornerRadius(3f, 3f))
    drawOval(skin, topLeft = Offset(29f - rx, 36f - ry), size = Size(rx * 2, ry * 2))
    drawOval(skin, topLeft = Offset(29f - rx - 2.4f, 36.5f - 2.4f), size = Size(4.8f, 4.8f))
    drawOval(skin, topLeft = Offset(29f + rx - 2.4f, 36.5f - 2.4f), size = Size(4.8f, 4.8f))
    if (!parts.showHat) drawHair(parts, hair, rx, ry)
    if (parts.agedCoach) {
        val wrinkle = Path().apply {
            moveTo(22f, 40.5f)
            quadraticBezierTo(23.4f, 41.6f, 24.8f, 40.5f)
        }
        drawPath(wrinkle, line.copy(alpha = 0.55f), style = Stroke(0.9f, cap = StrokeCap.Round))
    }
    if (parts.cheekMark) {
        drawOval(line.copy(alpha = 0.45f), topLeft = Offset(29f + rx - 4.8f, 39.2f), size = Size(1.6f, 1.6f))
    }
    drawBrows(parts, line)
    drawEyes(parts, line)
    val nose = Path().apply {
        moveTo(28.4f, 36.5f)
        quadraticBezierTo(27.7f, 38.8f, 28.6f, 39.6f)
    }
    drawPath(nose, line.copy(alpha = 0.7f), style = Stroke(1.1f, cap = StrokeCap.Round))
    drawMouth(parts, line)
    drawRoleProp(parts, rx, ry, jersey, line)
}

private fun DrawScope.drawHair(parts: AvatarParts, hair: Color, rx: Float, ry: Float) {
    val path = Path()
    when (parts.hairStyle) {
        0 -> {
            path.moveTo(29f - rx, 32f)
            path.quadraticBezierTo(29f - rx, 30f - ry, 29f, 30f - ry)
            path.quadraticBezierTo(29f + rx, 30f - ry, 29f + rx, 32f)
            path.lineTo(29f + rx, 29f)
            path.quadraticBezierTo(29f, 24f - ry, 29f - rx, 29f)
            path.close()
        }
        2 -> {
            listOf(20f to 24f, 26f to 21.5f, 32.5f to 21.5f, 38f to 24f).forEach { (cx, cy) ->
                path.addOval(androidx.compose.ui.geometry.Rect(cx - 4.6f, cy - 4.6f, cx + 4.6f, cy + 4.6f))
            }
        }
        else -> {
            path.moveTo(29f - rx, 30f)
            path.quadraticBezierTo(29f, 26.5f - ry, 29f + rx, 30f)
            path.lineTo(29f + rx, 27.5f)
            path.quadraticBezierTo(29f, 23.8f - ry, 29f - rx, 27.5f)
            path.close()
        }
    }
    drawPath(path, hair.copy(alpha = if (parts.hairStyle == 3) 0.85f else 1f))
}

private fun DrawScope.drawEyes(parts: AvatarParts, line: Color) {
    when (parts.eyeStyle) {
        1 -> {
            drawLine(line, Offset(21f, 34f), Offset(25f, 34f), 1.7f, StrokeCap.Round)
            drawLine(line, Offset(33f, 34f), Offset(37f, 34f), 1.7f, StrokeCap.Round)
        }
        2 -> {
            listOf(23f, 35f).forEach { x ->
                drawOval(line, topLeft = Offset(x - 2.1f, 32f), size = Size(4.2f, 4.2f))
                drawOval(BaseballColors.avatarHighlight, topLeft = Offset(x + 0.1f, 32.7f), size = Size(1.2f, 1.2f))
            }
        }
        else -> listOf(23f, 35f).forEach { x ->
            drawOval(line, topLeft = Offset(x - 1.7f, 32.3f), size = Size(3.4f, 3.4f))
        }
    }
}

private fun DrawScope.drawBrows(parts: AvatarParts, line: Color) {
    when (parts.browStyle) {
        1 -> {
            drawLine(line, Offset(20.5f, 30f), Offset(25.5f, 28.6f), 1.9f, StrokeCap.Round)
            drawLine(line, Offset(32.5f, 28.6f), Offset(37.5f, 30f), 1.9f, StrokeCap.Round)
        }
        else -> {
            drawLine(line, Offset(20.5f, 29.5f), Offset(25.5f, 29f), 1.6f, StrokeCap.Round)
            drawLine(line, Offset(32.5f, 29f), Offset(37.5f, 29.5f), 1.6f, StrokeCap.Round)
        }
    }
}

private fun DrawScope.drawMouth(parts: AvatarParts, line: Color) {
    when (parts.mouthStyle) {
        1 -> drawLine(line, Offset(25.5f, 44f), Offset(32.5f, 44f), 1.6f, StrokeCap.Round)
        2 -> {
            val path = Path().apply {
                moveTo(25.5f, 44.5f)
                quadraticBezierTo(29f, 42.8f, 32.5f, 44.5f)
            }
            drawPath(path, line, style = Stroke(1.5f, cap = StrokeCap.Round))
        }
        3 -> drawOval(line, topLeft = Offset(26.4f, 42.4f), size = Size(5.2f, 3.2f))
        else -> {
            val path = Path().apply {
                moveTo(25.5f, 43.5f)
                quadraticBezierTo(29f, 45.2f, 32.5f, 43.5f)
            }
            drawPath(path, line, style = Stroke(1.5f, cap = StrokeCap.Round))
        }
    }
}

private fun DrawScope.drawRoleProp(parts: AvatarParts, rx: Float, ry: Float, jersey: Color, line: Color) {
    when (parts.role) {
        AvatarRole.RIVAL -> {
            drawOval(BaseballColors.avatarHelmet, topLeft = Offset(29f - rx - 1.6f, 35.4f - ry - 4.6f), size = Size((rx + 1.6f) * 2, 9.2f))
            drawRoundRect(BaseballColors.avatarHelmet, topLeft = Offset(29f + rx - 3f, 29f), size = Size(7.5f, 3.4f), cornerRadius = androidx.compose.ui.geometry.CornerRadius(1.7f, 1.7f))
        }
        AvatarRole.CATCHER -> {
            drawRoundRect(BaseballColors.avatarMask, topLeft = Offset(29f - rx - 1f, 22.5f), size = Size(rx * 2 + 2f, 3f), cornerRadius = androidx.compose.ui.geometry.CornerRadius(1.5f, 1.5f))
        }
        else -> Unit
    }
    if (parts.showHat && parts.role != AvatarRole.RIVAL) {
        drawOval(BaseballColors.avatarCap, topLeft = Offset(29f - rx - 0.9f, 36.2f - ry - 5.2f), size = Size((rx + 0.9f) * 2, 10.4f))
        drawRoundRect(BaseballColors.avatarCapBrim, topLeft = Offset(20f, 37.4f - ry), size = Size(18f, 2.6f), cornerRadius = androidx.compose.ui.geometry.CornerRadius(1.3f, 1.3f))
    }
}
