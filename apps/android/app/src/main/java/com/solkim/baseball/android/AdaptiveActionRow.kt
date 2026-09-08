package com.solkim.baseball.android

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.Placeable
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.constrainWidth
import androidx.compose.ui.unit.constrainHeight
import androidx.compose.ui.unit.dp

/** Natural-width actions wrap individually. Segmented choices explicitly request equal columns. */
@Composable
internal fun AdaptiveActionRow(modifier: Modifier = Modifier, equalWidth: Boolean = false, content: @Composable () -> Unit) {
    Layout(content = content, modifier = modifier) { measurables, constraints ->
        val gap = 8.dp.roundToPx()
        val minimumWidth = 48.dp.roundToPx()
        val natural = measurables.map { it.maxIntrinsicWidth(Constraints.Infinity).coerceAtLeast(minimumWidth) }
        val wanted = (natural.sumOf { it.toLong() } + gap * (natural.size - 1).coerceAtLeast(0)).coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
        val width = constraints.constrainWidth(wanted)
        var columns = if (natural.isEmpty()) 1 else minOf(natural.size,
            ((width.toLong() + gap) / (natural.max().toLong() + gap)).toInt().coerceAtLeast(1))
        if (equalWidth && natural.size == 4 && columns == 3) columns = 2
        val cellWidth = ((width - gap * (columns - 1)) / columns).coerceAtLeast(0)
        val children = measurables.mapIndexed { index, measurable ->
            measurable.measure(Constraints.fixedWidth(if (equalWidth) cellWidth else natural[index].coerceAtMost(width)))
        }
        val rows = mutableListOf<MutableList<Placeable>>()
        var rowWidth = 0
        children.forEach { child ->
            if (rows.isEmpty() || (rows.last().isNotEmpty() && rowWidth.toLong() + gap + child.width > width)) {
                rows += mutableListOf<Placeable>()
                rowWidth = 0
            }
            if (rows.last().isNotEmpty()) rowWidth += gap
            rows.last().add(child)
            rowWidth += child.width
        }
        val heights = rows.map { row -> row.maxOf { it.height } }
        val height = heights.sum() + gap * (rows.size - 1).coerceAtLeast(0)
        layout(width, constraints.constrainHeight(height)) {
            var y = 0
            rows.forEachIndexed { index, row ->
                var x = 0
                row.forEach { child ->
                    child.placeRelative(x, y + (heights[index] - child.height) / 2)
                    x += child.width + gap
                }
                y += heights[index] + gap
            }
        }
    }
}
