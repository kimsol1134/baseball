package com.solkim.baseball.android

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.testTagsAsResourceId
import android.content.Context
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color as ComposeColor
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.solkim.baseball.android.LocalizedGameText as Text
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.model.QualityTier

@Composable
internal fun PitchTopBar(
    title: String,
    subtitle: String,
    stakesLabel: String,
    stakesValue: String,
    abortLabel: String,
    onBack: () -> Unit,
) {
    Surface(
        color = BaseballColors.surface,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = BaseballColors.textPrimary,
                )
                if (subtitle.isNotBlank()) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = BaseballColors.textTertiary,
                    maxLines = 2,
                )
                }
            }
            Spacer(Modifier.width(8.dp))
            OutlinedButton(
                onClick = onBack,
                border = BorderStroke(1.dp, BaseballColors.border),
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                modifier = Modifier.heightIn(min = 44.dp),
            ) {
                Text(abortLabel, color = BaseballColors.textSecondary, style = MaterialTheme.typography.labelSmall)
            }
        }
    }
}

@Composable
internal fun PitchScoreboardBar(board: PitchScoreboardModel, perfectStreak: Int = 0) {
    val copy = rememberGameCopy()
    val inningText = if (copy.language == com.solkim.baseball.application.GameLanguage.KOREAN) board.inningText else
        copy.resolve("android.pitch.inning", com.solkim.baseball.application.GameCopyArgument.Whole(board.inning.toLong()))
    val spokenScore = board.accessibilityLabel.split(", ").joinToString(", ") { if (it == board.inningText) inningText else copy.legacy(it) }
    val scoreTone = when {
        board.scoreDiff > 0 -> BaseballColors.positive
        board.scoreDiff < 0 -> BaseballColors.negative
        else -> BaseballColors.textPrimary
    }
    Surface(
        color = BaseballColors.surface,
        modifier = Modifier
            .fillMaxWidth()
            .gameDescription(spokenScore),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text(
                        text = board.scoreText,
                        color = scoreTone,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Black,
                    )
                    Text(
                        text = inningText,
                        color = BaseballColors.textSecondary,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    PipGroup(label = "OUT", count = board.outs, max = 2, activeColor = BaseballColors.negative)
                }
                if (perfectStreak > 0) {
                    Text(
                        text = if (perfectStreak >= 2) "★ 퍼펙트 ${perfectStreak}연속" else "★ 퍼펙트",
                        color = BaseballColors.milestone,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Black,
                        modifier = Modifier.testTag("pitch.perfectStreak"),
                    )
                }
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                PipGroup(label = "B", count = board.balls, max = 3, activeColor = BaseballColors.warning)
                PipGroup(label = "S", count = board.strikes, max = 2, activeColor = BaseballColors.action)
                BaseOccupancyDiagram(listOfNotNull(1.takeIf { board.runners.firstOccupied }, 2.takeIf { board.runners.secondOccupied }, 3.takeIf { board.runners.thirdOccupied }), Modifier.size(44.dp), compact = true)
                val pressure = PitchScoreboardProjection.pressureLine(board.scoreDiff, board.runners)
                if (pressure != null) Text(pressure, modifier = Modifier.weight(1f), color = BaseballColors.warning,
                    style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold)
                else Spacer(Modifier.weight(1f))
                Text(
                    text = "피로 ${board.fatigue}",
                    color = if (board.fatigue >= 70) BaseballColors.warning else BaseballColors.textTertiary,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                )
            }

        }
    }
}

@Composable
internal fun PipGroup(label: String, count: Int, max: Int, activeColor: ComposeColor) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
        modifier = Modifier.clearAndSetSemantics { },
    ) {
        Text(
            text = label,
            color = BaseballColors.textTertiary,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
        )
        repeat(max) { index ->
            val isFilled = index < count
            Box(
                modifier = Modifier
                    .size(7.dp)
                    .clip(CircleShape)
                    .background(if (isFilled) activeColor else BaseballColors.border.copy(alpha = 0.5f)),
            )
        }
    }
}



@Composable
internal fun PitchMatchupCard(
    batterName: String,
    isLeftBatter: Boolean,
    contactLabel: String,
    disciplineLabel: String,
    powerLabel: String,
    contact: Int,
    discipline: Int,
    power: Int,
    adaptationTitle: String,
    adaptationBandLabel: String,
    adaptationWarning: String,
    adaptationLevel: Int,
    onCollapse: (() -> Unit)? = null,
) {
    Surface(
        color = BaseballColors.surfaceRaised,
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(1.dp, BaseballColors.border.copy(alpha = 0.4f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.weight(1f),
                ) {
                    Text(
                        text = batterName,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = BaseballColors.textPrimary,
                    )
                    Surface(
                        color = BaseballColors.action,
                        shape = CircleShape,
                    ) {
                        Text(
                            text = if (isLeftBatter) "좌타" else "우타",
                            color = BaseballColors.actionInk,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Black,
                            modifier = Modifier.padding(horizontal = 7.dp, vertical = 2.dp),
                        )
                    }
                }
                Text(
                    text = "$contactLabel $contact · $disciplineLabel $discipline · $powerLabel $power",
                    color = BaseballColors.textSecondary,
                    style = MaterialTheme.typography.bodySmall,
                    fontFamily = FontFamily.Monospace,
                    modifier = Modifier.weight(1f),
                )
                if (onCollapse != null) {
                    Text(
                        text = "접기",
                        color = BaseballColors.action,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier
                            .clickable(onClick = onCollapse)
                            .padding(start = 8.dp)
                            .gameDescription("타자 정보 접기"),
                    )
                }
            }
            AdaptationBar(
                title = adaptationTitle,
                bandLabel = adaptationBandLabel,
                warning = adaptationWarning,
                level = adaptationLevel,
            )
        }
    }
}

@Composable
internal fun PitchCoachStrip(label: String, tip: String, modifier: Modifier = Modifier) {
    Surface(
        color = BaseballColors.surfaceRaised,
        shape = RoundedCornerShape(10.dp),
        modifier = modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 7.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = label,
                color = BaseballColors.textTertiary,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = tip,
                color = BaseballColors.textPrimary,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
internal fun AdaptationBar(
    title: String,
    bandLabel: String,
    warning: String,
    level: Int,
) {
    val progress = (level / 900f).coerceIn(0f, 1f)
    val fill = when {
        level >= 600 -> BaseballColors.warning
        else -> BaseballColors.action
    }
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = title,
                color = BaseballColors.textTertiary,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
            )
            if (bandLabel.isNotBlank()) {
                Text(
                    text = bandLabel,
                    color = fill,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(50))
                .background(BaseballColors.surfaceSoft),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(progress)
                    .height(6.dp)
                    .clip(RoundedCornerShape(50))
                    .background(fill)
                    .align(Alignment.CenterStart),
            )
        }
        if (warning.isNotBlank()) {
            Text(
                text = warning,
                color = BaseballColors.textPrimary,
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}
