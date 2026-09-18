package com.solkim.baseball.android

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform

/** Original monochrome baseball glyphs; native vectors stay crisp at every display scale. */
@Composable
internal fun AwakeningGlyph(id: String, color: Color, modifier: Modifier) {
    Canvas(modifier) {
        withTransform({ scale(size.width / 32f, size.height / 32f, pivot = Offset.Zero) }) {
            fun line(x: Float, y: Float, x2: Float, y2: Float) = drawLine(color, Offset(x,y), Offset(x2,y2), 2f, StrokeCap.Round)
            fun circle(radius: Float, x: Float = 16f, y: Float = 16f) = drawCircle(color, radius, Offset(x,y), style = Stroke(2f))
            fun path(block: Path.() -> Unit) = drawPath(Path().apply(block), color, style = Stroke(2f, cap = StrokeCap.Round))
            when (id) {
                "power", "explosive_fastball" -> { circle(8f,20f,16f); line(2f,10f,9f,10f);line(1f,16f,8f,16f);line(2f,22f,9f,22f);path { moveTo(18f,9f);quadraticTo(24f,16f,18f,23f) } }
                "rising_four_seam" -> { path { moveTo(4f,26f);quadraticTo(20f,25f,25f,5f) };line(18f,8f,25f,5f);line(25f,5f,28f,13f) }
                "iron_arm", "calm_under_pressure" -> { path { moveTo(16f,3f);lineTo(27f,8f);lineTo(25f,22f);lineTo(16f,29f);lineTo(7f,22f);lineTo(5f,8f);close() };line(11f,16f,15f,20f);line(15f,20f,22f,12f) }
                "late_inning_reserve" -> { path { moveTo(4f,9f);lineTo(25f,9f);lineTo(25f,24f);lineTo(4f,24f);close() };line(28f,14f,28f,19f);line(10f,13f,10f,20f);line(16f,13f,16f,20f) }
                "command", "pinpoint_edge", "first_pitch_strike" -> { circle(11f);circle(5f);line(16f,1f,16f,8f);line(16f,24f,16f,31f);if(id!="first_pitch_strike"){line(1f,16f,8f,16f);line(24f,16f,31f,16f)} }
                "repeatable_release" -> { drawArc(color,40f,270f,false,Offset(5f,5f),Size(22f,22f),style=Stroke(2f));line(25f,5f,26f,13f);line(26f,13f,19f,11f);circle(3f) }
                "scout_composure" -> { path { moveTo(2f,16f);quadraticTo(16f,0f,30f,16f);quadraticTo(16f,32f,2f,16f) };circle(5f) }
                "breaking", "disappearing_breaker", "sweeping_slider" -> { path { moveTo(4f,6f);cubicTo(28f,4f,6f,25f,28f,25f) };line(22f,19f,28f,25f);line(28f,25f,21f,29f) }
                "curveball_clock" -> { path { moveTo(4f,7f);cubicTo(24f,2f,24f,11f,20f,27f) };line(15f,21f,20f,27f);line(20f,27f,27f,23f) }
                "frozen_changeup" -> { line(16f,3f,16f,29f);line(5f,9f,27f,23f);line(5f,23f,27f,9f);circle(6f) }
                "sinker_tunnel" -> { path { moveTo(4f,4f);lineTo(15f,16f);lineTo(6f,28f) };line(15f,16f,28f,24f);circle(3f,25f,7f) }
                "game", "battery_sync" -> { circle(5f,10f,9f);circle(5f,24f,9f);path { moveTo(2f,28f);quadraticTo(10f,13f,18f,28f) };path { moveTo(18f,19f);quadraticTo(26f,15f,30f,28f) } }
                "two_strike_plan" -> { circle(4f,8f,8f);circle(4f,24f,8f);line(5f,26f,14f,17f);line(14f,17f,26f,26f) }
                "pickoff_rhythm" -> { path { moveTo(16f,3f);lineTo(29f,16f);lineTo(16f,29f);lineTo(3f,16f);close() };circle(3f,16f,16f) }
                "traffic_controller" -> { line(5f,28f,5f,5f);line(16f,28f,16f,13f);line(27f,28f,27f,5f);line(2f,8f,5f,5f);line(5f,5f,8f,8f);circle(3f,16f,7f) }
                "lock" -> { path { moveTo(8f,14f);lineTo(24f,14f);lineTo(24f,28f);lineTo(8f,28f);close() };drawArc(color,180f,180f,false,Offset(10f,3f),Size(12f,18f),style=Stroke(2f));line(16f,19f,16f,23f) }
                else -> { circle(10f);line(16f,10f,16f,22f);line(10f,16f,22f,16f) }
            }
        }
    }
}
