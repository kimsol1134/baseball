package com.solkim.baseball.android

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.GameCopyArgument
import com.solkim.baseball.application.OutingBriefing
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.android.LocalizedGameText as Text

/** Same diamond orientation before and during pitching: first right, second top, third left. */
@Composable
internal fun BaseOccupancyDiagram(bases: List<Int>, modifier: Modifier = Modifier, compact: Boolean = false) {
    val copy = rememberGameCopy()
    BoxWithConstraints(modifier) {
        val baseSize = if (compact) 10.dp else 22.dp
        Canvas(Modifier.fillMaxSize()) {
            val points = listOf(Offset(size.width * .5f, size.height * .84f), Offset(size.width * .84f, size.height * .5f),
                Offset(size.width * .5f, size.height * .16f), Offset(size.width * .16f, size.height * .5f))
            points.indices.forEach { drawLine(BaseballColors.border, points[it], points[(it + 1) % 4], if (compact) 1.dp.toPx() else 2.dp.toPx()) }
            val w = if (compact) 3.dp.toPx() else 5.dp.toPx()
            val home = points[0]
            drawPath(Path().apply {
                moveTo(home.x - w, home.y - w); lineTo(home.x + w, home.y - w)
                lineTo(home.x + w, home.y); lineTo(home.x, home.y + w); lineTo(home.x - w, home.y); close()
            }, BaseballColors.textSecondary)
        }
        listOf(1 to (.84f to .5f), 2 to (.5f to .16f), 3 to (.16f to .5f)).forEach { (base, position) ->
            val occupied = base in bases
            val description = copy.resolve(if (occupied) "visual.base.occupied" else "visual.base.empty", GameCopyArgument.Whole(base.toLong()))
            Box(Modifier.offset(x = maxWidth * position.first - baseSize / 2, y = maxHeight * position.second - baseSize / 2)
                .size(baseSize).testTag("visual.base.$base").semantics { selected = occupied; contentDescription = description }, contentAlignment = Alignment.Center) {
                Box(Modifier.fillMaxSize().graphicsLayer { rotationZ = 45f }
                    .background(if (occupied) BaseballColors.action else BaseballColors.surfaceSoft, RoundedCornerShape(2.dp))
                    .border(if (occupied) 2.dp else 1.dp, if (occupied) BaseballColors.action else BaseballColors.textTertiary, RoundedCornerShape(2.dp)))
                if (!compact) Text(base.toString(), verbatim = true, style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold, color = if (occupied) BaseballColors.actionInk else BaseballColors.textSecondary)
                else if (occupied) Box(Modifier.size(3.dp).background(BaseballColors.actionInk, CircleShape))
            }
        }
    }
}

@Composable
internal fun VisualOutingSituation(briefing: OutingBriefing) {
    val copy = rememberGameCopy()
    Row(Modifier.fillMaxWidth().testTag("outing.situation").semantics(mergeDescendants = true) {
        contentDescription = briefing.situation + ", " + briefing.score
    }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(briefing.inning.toString(), verbatim = true, style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Black)
            Text(copy.resolve("visual.inning"), verbatim = true, style = MaterialTheme.typography.labelSmall)
            Spacer(Modifier.height(4.dp))
            Text(copy.resolve("visual.outs"), verbatim = true, style = MaterialTheme.typography.labelSmall, color = BaseballColors.textSecondary)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                repeat(2) { index ->
                    Box(Modifier.size(12.dp).testTag("visual.out.$index").semantics { selected = index < briefing.outs }
                        .background(if (index < briefing.outs) BaseballColors.warning else BaseballColors.surfaceSoft, CircleShape)
                        .border(1.dp, if (index < briefing.outs) BaseballColors.warning else BaseballColors.textTertiary, CircleShape))
                }
            }
        }
        BaseOccupancyDiagram(briefing.bases, Modifier.size(112.dp))
        Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(if (briefing.lead > 0) "+${briefing.lead}" else briefing.lead.toString(), verbatim = true,
                style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Black,
                color = if (briefing.lead > 0) BaseballColors.action else if (briefing.lead < 0) BaseballColors.warning else BaseballColors.textPrimary)
            Text(copy.resolve(if (briefing.lead > 0) "visual.leading" else if (briefing.lead < 0) "visual.trailing" else "improve.outing.tied"),
                verbatim = true, style = MaterialTheme.typography.labelSmall)
        }
    }
}
