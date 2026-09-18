package com.solkim.baseball.android

import androidx.compose.ui.geometry.Rect
import com.solkim.baseball.application.BatSide
import kotlin.math.max

internal data class PitchActorGeometry(val batter: Rect, val catcher: Rect, val plate: Rect)
internal object PitchPlateGeometry {
    val worldBounds = Rect(-50f, 60f, 370f, 360f)
    fun layout(zone: Rect, side: BatSide): PitchActorGeometry {
        val scale = zone.width / 150f
        val bh = zone.height * 1.46f
        val bw = bh * PlateFigures.BATTER_ASPECT
        val bx = if (side == BatSide.LEFT) zone.right + zone.width * .10f - bw * .34f else zone.left - zone.width * .10f - bw * .66f
        val by = zone.bottom + zone.height * .34f - bh
        val cw = zone.width * 1.18f
        val ch = cw / PlateFigures.CATCHER_ASPECT
        val cy = zone.center.y - ch * .55f
        val py = max(zone.bottom + 30f * scale, cy + ch + 12f * scale)
        return PitchActorGeometry(Rect(bx, by, bx + bw, by + bh),
            Rect(zone.center.x - cw/2, cy, zone.center.x + cw/2, cy+ch),
            Rect(zone.center.x-zone.width*.22f, py, zone.center.x+zone.width*.22f, py+19f*scale))
    }
}
