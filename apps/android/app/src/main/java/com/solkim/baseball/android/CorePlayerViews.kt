package com.solkim.baseball.android

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.clickable
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.android.LocalizedGameText as Text

@Composable
@OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)
internal fun CorePlayerHeader(state: GameAggregateState, compact: Boolean = false) {
    val pro = state.pro.takeIf { state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT) }
    val run = state.highSchool?.run
    val command = pro?.pitcher?.command ?: run?.pitcher?.command ?: return
    val stamina = pro?.pitcher?.stamina ?: run?.pitcher?.stamina ?: return
    val copy = rememberGameCopy()
    val name = if (state.meta.seedChallenge != null) copy.resolve("android.challenge.player") else pro?.identityName ?: run?.identity?.name ?: return
    val seed = playerPortraitSeed(state) ?: name
    val stage = if (pro != null) PlayerStage.PRO else if (run?.chapter?.schoolYear == 1) PlayerStage.FRESHMAN else PlayerStage.ACE
    var details by remember { mutableStateOf(false) }
    if (compact) {
        Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.weight(1f)) { CompanionLauncher(state, showPortrait = true) }
                TextButton(onClick = { details = true }, modifier = Modifier.testTag("career.playerDetails")) { Text("능력") }
            }
            CompanionReaction(state)
            NextAppearanceCue.resolve(state)?.let { CoreNextAppearance(it) }
        }
        if (details) AlertDialog(onDismissRequest = { details = false },
            modifier = Modifier.semantics { testTagsAsResourceId = true },
            title = { Text(copy.resolve("mobile.core.stats"), verbatim = true) },
            text = { Column(Modifier.heightIn(max = 480.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                CorePlayerHeader(state, compact = false)
                Text(copy.resolve("control.window.explanation"), verbatim = true, style = MaterialTheme.typography.bodyMedium)
                val stuff = pro?.pitcher?.stuff ?: run?.pitcher?.stuff ?: 20
                val movement = pro?.pitcher?.movement ?: run?.pitcher?.movement ?: 20
                Text("${copy.legacy("구위")} ${AbilityDisplayScale.rating(stuff)} · ${copy.legacy("무브먼트")} ${AbilityDisplayScale.rating(movement)}", verbatim = true)
            } },
            confirmButton = { TextButton(onClick = { details = false }) { Text(copy.resolve("action.close"), verbatim = true) } })
        return
    }
    Column(Modifier.fillMaxWidth().testTag("career.player"), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            PlayerPortrait(seed = seed, stage = stage, width = if (compact) 48.dp else 72.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(name, verbatim = true, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                Text(copy.resolve("mobile.core.life", GameCopyArgument.Whole((run?.lifeNumber ?: 1).toLong())),
                    verbatim = true, color = BaseballColors.action)
                Text(pro?.let { copy.resolve("mobile.core.pro-season", GameCopyArgument.Whole(it.season.toLong())) }
                    ?: run?.chapter?.title.orEmpty(), style = MaterialTheme.typography.bodySmall)
            }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            val velocity = pro?.pitcher?.profile(PitchKind.FOUR_SEAM)?.velocityTenthsKph
                ?: run?.pitcher?.pitchProfiles?.firstOrNull { it.pitchType == PitchKind.FOUR_SEAM }?.velocityTenthsKph
            CorePlayerStat(copy.resolve("mobile.core.velocity"), velocity?.let { "${it / 10}.${it % 10} km/h" } ?: "—", Modifier.weight(1f))
            CorePlayerStat(copy.legacy("제구"), AbilityDisplayScale.rating(command).toString(), Modifier.weight(1f), commandRating = command)
            CorePlayerStat(copy.legacy("체력"), AbilityDisplayScale.rating(stamina).toString(), Modifier.weight(1f))
        }
    }
}

@Composable
private fun CorePlayerStat(label: String, value: String, modifier: Modifier, commandRating: Int? = null) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(label, verbatim = true, color = BaseballColors.textSecondary, style = MaterialTheme.typography.labelMedium)
        if (commandRating != null) ControlWindowPreview(commandRating, compact = true)
        Text(value.removeSuffix(" km/h"), verbatim = true, style = if (commandRating == null) MaterialTheme.typography.titleLarge else MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold)
        if (value.endsWith(" km/h")) Text("km/h", verbatim = true, color = BaseballColors.textSecondary, style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
internal fun CoreGrowthResult(receipt: PlayerGrowthReceipt, compact: Boolean = false, detailsToggle: Boolean = true, modifier: Modifier = Modifier) {
    val copy = rememberGameCopy()
    val labels = listOf("구위", "제구", "무브먼트", "체력")
    val primary = GrowthFeedbackPresentation.primary(receipt)
    val milestone = GrowthFeedbackPresentation.controlMilestone(receipt)
    var details by remember(receipt.commandId) { mutableStateOf(false) }
    Column(modifier.fillMaxWidth().testTag("growth.beforeAfter"), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        val headline = if (milestone) copy.resolve("loop.growth.milestone") else primary?.let { ability ->
            copy.resolve("loop.growth.row", GameCopyArgument.UserText(copy.legacy(labels[ability])),
                GameCopyArgument.Whole(AbilityDisplayScale.rating(receipt.before[ability]).toLong()),
                GameCopyArgument.Whole(AbilityDisplayScale.rating(receipt.after[ability]).toLong()))
        } ?: copy.resolve("mobile.core.no-growth")
        StatChangeText(headline, verbatim = true, style = if (milestone && !compact) MaterialTheme.typography.titleLarge else MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold, color = if (milestone) BaseballColors.milestone else BaseballColors.textPrimary)
        if (milestone) StatChangeText("${copy.legacy(labels[1])} ${AbilityDisplayScale.rating(receipt.before[1])} → ${AbilityDisplayScale.rating(receipt.after[1])}", verbatim = true)
        if (milestone && !compact) ControlWindowPreview(receipt.after[1], receipt.before[1], showsLegend = false, titleKey = "loop.growth.base-window")
        if (detailsToggle) {
            TextButton(onClick = { details = !details }) { Text(copy.resolve("mobile.core.growth-details"), verbatim = true) }
            if (details) {
                for (ability in 0..3) if (receipt.before[ability] != receipt.after[ability]) {
                    StatChangeText("${copy.legacy(labels[ability])} ${AbilityDisplayScale.rating(receipt.before[ability])} → ${AbilityDisplayScale.rating(receipt.after[ability])}", verbatim = true)
                }
                if (!milestone && receipt.before[1] != receipt.after[1]) ControlWindowPreview(receipt.after[1], receipt.before[1], titleKey = "loop.growth.base-window")
            }
        }
    }
}

@Composable
private fun CoreNextAppearance(cue: NextAppearanceCue) {
    val copy = rememberGameCopy()
    Surface(color = BaseballColors.surfaceRaised, shape = androidx.compose.foundation.shape.RoundedCornerShape(12.dp)) {
        Column(Modifier.fillMaxWidth().padding(12.dp).testTag("career.nextAppearance"), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(copy.resolve(if (cue.trainings == 0 && cue.choices == 0) "mobile.polish.game-ready" else "mobile.polish.next-game"),
                verbatim = true, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, color = BaseballColors.action)
            val detail = when {
                cue.trainings == 0 && cue.choices == 0 -> null
                cue.choices == 0 -> copy.resolve("mobile.polish.training-count", GameCopyArgument.Whole(cue.trainings.toLong()))
                cue.trainings == 0 -> copy.resolve("mobile.polish.choice-count", GameCopyArgument.Whole(cue.choices.toLong()))
                else -> copy.resolve("mobile.polish.preparation-counts", GameCopyArgument.Whole(cue.trainings.toLong()), GameCopyArgument.Whole(cue.choices.toLong()))
            }
            if (detail != null) Text(detail, verbatim = true, style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
        }
    }
}

@Composable
internal fun CoreRebirthStartComparison(preview: RebirthStartPreview) {
    val copy = rememberGameCopy()
    Column(Modifier.fillMaxWidth().testTag("rebirth.startComparison"), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(copy.resolve("mobile.polish.life-transition", GameCopyArgument.Whole(preview.previousLife.toLong()), GameCopyArgument.Whole(preview.nextLife.toLong())),
            verbatim = true, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = BaseballColors.action)
        Text(copy.resolve("mobile.polish.start-comparison"), verbatim = true, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Spacer(Modifier.weight(1f))
            Text(copy.resolve("mobile.polish.previous-start"), verbatim = true, modifier = Modifier.weight(1f), style = MaterialTheme.typography.labelMedium)
            Text(copy.resolve("mobile.polish.next-start"), verbatim = true, modifier = Modifier.weight(1f), style = MaterialTheme.typography.labelMedium)
        }
        listOf("구위", "제구", "무브먼트", "체력").forEachIndexed { index, label ->
            Row(Modifier.fillMaxWidth().testTag("rebirth.start.$index"), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(copy.legacy(label), verbatim = true, modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
                Text(AbilityDisplayScale.rating(preview.previous[index]).toString(), verbatim = true,
                    modifier = Modifier.weight(1f), color = BaseballColors.textSecondary, style = MaterialTheme.typography.titleMedium)
                Text(AbilityDisplayScale.rating(preview.next[index]).toString(), verbatim = true, modifier = Modifier.weight(1f),
                    color = if (preview.next[index] >= preview.previous[index]) BaseballColors.action else BaseballColors.warning,
                    style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            }
        }
        ControlWindowPreview(preview.next[1], preview.previous[1])
    }
}

@Composable
internal fun ControlWindowPreview(command: Int, before: Int? = null, compact: Boolean = false, showsLegend: Boolean = true, titleKey: String? = null) {
    val copy = rememberGameCopy()
    val width = PitchReleaseWindow.width(command).toFloat()
    val old = before?.let { PitchReleaseWindow.width(it).toFloat() }
    val expanded = old != null && width > old
    val description = if (old == null) copy.resolve("control.window.accessibility", GameCopyArgument.Decimal(width * 100.0))
        else copy.resolve("control.window.comparison", GameCopyArgument.Decimal(old * 100.0), GameCopyArgument.Decimal(width * 100.0))
    Column(Modifier.fillMaxWidth().testTag("growth.controlWindow").semantics { contentDescription = description }, verticalArrangement = Arrangement.spacedBy(7.dp)) {
        Text(copy.resolve(titleKey ?: if (expanded) "control.window.expanded" else "control.window.short"), verbatim = true,
            style = if (compact) MaterialTheme.typography.labelSmall else MaterialTheme.typography.bodyMedium,
            color = if (expanded) BaseballColors.action else BaseballColors.textSecondary)
        androidx.compose.foundation.Canvas(Modifier.fillMaxWidth().height(if (compact) 12.dp else 18.dp)) {
            val radius = androidx.compose.ui.geometry.CornerRadius(3.dp.toPx())
            drawRoundRect(BaseballColors.canvas, cornerRadius = radius)
            drawRoundRect(BaseballColors.action.copy(alpha = 0.6f), topLeft = androidx.compose.ui.geometry.Offset(size.width * (0.5f - width / 2), 0f),
                size = androidx.compose.ui.geometry.Size(size.width * width, size.height), cornerRadius = radius)
            if (old != null && old != width) for (side in listOf(-1, 1)) {
                val x = size.width * (0.5f + side * old / 2)
                drawLine(BaseballColors.textSecondary, androidx.compose.ui.geometry.Offset(x, -2.dp.toPx()), androidx.compose.ui.geometry.Offset(x, size.height + 2.dp.toPx()), strokeWidth = 1.dp.toPx())
            }
            drawRect(BaseballColors.milestone, topLeft = androidx.compose.ui.geometry.Offset(size.width * 0.4875f, 0f),
                size = androidx.compose.ui.geometry.Size(maxOf(2.dp.toPx(), size.width * 0.025f), size.height))
        }
        if (old != null && !compact && showsLegend) Text(copy.resolve("control.window.legend"), verbatim = true, style = MaterialTheme.typography.labelSmall, color = BaseballColors.textSecondary)
    }
}

@Composable
internal fun ControlMilestoneGoal(command: Int) {
    val target = PitchReleaseWindow.nextMilestone(command) ?: return
    val lower = PitchReleaseWindow.milestones.lastOrNull { it <= command } ?: PitchReleaseWindow.BASELINE_COMMAND
    val copy = rememberGameCopy()
    Column(Modifier.fillMaxWidth().testTag("growth.controlGoal"), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(copy.resolve("loop.growth.next", GameCopyArgument.Whole((AbilityDisplayScale.rating(target) - AbilityDisplayScale.rating(command)).toLong())), verbatim = true,
            style = MaterialTheme.typography.labelSmall, color = BaseballColors.textSecondary)
        LinearProgressIndicator(progress = { ((command - lower).toFloat() / (target - lower)).coerceIn(0f, 1f) }, modifier = Modifier.fillMaxWidth().height(4.dp), color = BaseballColors.action)
    }
}
