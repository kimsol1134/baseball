package com.solkim.baseball.android

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.constrainWidth
import androidx.compose.ui.unit.constrainHeight
import androidx.compose.ui.unit.dp

/** Give labels their natural width; stack whole controls when a row cannot fit. */
@Composable
internal fun AdaptiveActionRow(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Layout(content = content, modifier = modifier) { measurables, constraints ->
        val gap = 8.dp.roundToPx()
        val naturalWidths = measurables.map { it.maxIntrinsicWidth(Constraints.Infinity) }
        val required = naturalWidths.sumOf { it.toLong() } + gap * (measurables.size - 1).coerceAtLeast(0)
        val width = if (constraints.hasBoundedWidth) constraints.maxWidth else constraints.constrainWidth(required.toInt())
        val stacked = required > width
        val extra = if (stacked || measurables.isEmpty()) 0 else (width - required.toInt()) / measurables.size
        val placeables = measurables.mapIndexed { index, measurable ->
            measurable.measure(Constraints.fixedWidth(if (stacked) width else naturalWidths[index] + extra))
        }
        val height = if (stacked) placeables.sumOf { it.height } + gap * (placeables.size - 1).coerceAtLeast(0)
            else placeables.maxOfOrNull { it.height } ?: 0
        layout(width, constraints.constrainHeight(height)) {
            var offset = 0
            placeables.forEach { child ->
                child.placeRelative(if (stacked) 0 else offset, if (stacked) offset else (height - child.height) / 2)
                offset += (if (stacked) child.height else child.width) + gap
            }
        }
    }
}
