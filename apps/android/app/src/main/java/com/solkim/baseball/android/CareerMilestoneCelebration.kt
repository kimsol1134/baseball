package com.solkim.baseball.android

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.core.highschool.HighSchoolPitchingDecision
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.android.LocalizedGameText as Text

/** Only newly observed milestones interrupt play. Loading an old career does not replay praise. */
@Composable
internal fun CareerMilestoneCelebration(state: GameAggregateState, showTrainingBloom: Boolean = true) {
    val school = state.highSchool ?: return
    val run = school.run
    val copy = rememberGameCopy()
    val wins = school.seasonLog.count { it.played && it.decision == HighSchoolPitchingDecision.WIN }
    var seenTraining by rememberSaveable(run.careerId) { mutableStateOf(run.totalTrainingsCompleted) }
    var seenLearning by rememberSaveable(run.careerId) { mutableStateOf(run.pitchLearningProject?.completed == true) }
    var seenAwakenings by rememberSaveable(run.careerId) { mutableStateOf(run.selectedAwakenings.size) }
    var seenWins by rememberSaveable(run.careerId) { mutableStateOf(wins) }
    var moment by rememberSaveable(run.careerId) { mutableStateOf<String?>(null) }
    var detail by rememberSaveable(run.careerId) { mutableStateOf<String?>(null) }
    var artBranch by rememberSaveable(run.careerId) { mutableStateOf("game") }
    LaunchedEffect(run.revision, wins) {
        when {
            run.pitchLearningProject?.completed == true && !seenLearning -> {
                moment = "pitch"
                artBranch = "breaking"
                detail = TrainingPresentation.pitchLabel(run.pitchLearningProject!!.pitchType)
            }
            run.selectedAwakenings.size > seenAwakenings -> {
                moment = "awakening"
                artBranch = com.solkim.baseball.core.highschool.HighSchoolContentCatalog.awakeningNodes
                    .firstOrNull { it.id == run.selectedAwakenings.last() }?.branch ?: "game"
                detail = HighSchoolDisplayRules.awakeningTitle(run.selectedAwakenings.last().wire)
            }
            wins > 0 && seenWins == 0 -> { moment = "win"; detail = null }
            showTrainingBloom && run.totalTrainingsCompleted > seenTraining && run.lastTraining?.bloomed == true -> {
                moment = "bloom"
                artBranch = when (run.lastTraining?.focus) {
                    TrainingFocus.VELOCITY, TrainingFocus.STAMINA -> "power"
                    TrainingFocus.COMMAND -> "command"
                    TrainingFocus.BREAKING_BALL -> "breaking"
                    else -> "game"
                }
                detail = null
            }
        }
        seenTraining = run.totalTrainingsCompleted
        seenLearning = run.pitchLearningProject?.completed == true
        seenAwakenings = run.selectedAwakenings.size
        seenWins = wins
    }
    moment?.let { kind ->
        AlertDialog(onDismissRequest = { moment = null }, modifier = Modifier.testTag("career.milestone"),
            containerColor = BaseballColors.surfaceRaised,
            title = {
                Text(copy.resolve("career.moment.$kind"), verbatim = true, style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold, color = BaseballColors.action)
            },
            text = {
                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    if (kind == "win") PlayerPortrait(seed = playerPortraitSeed(state) ?: run.identity.name,
                        stage = if (run.chapter.number >= 5) PlayerStage.ACE else PlayerStage.FRESHMAN, width = 88.dp)
                    else SkillCelebrationArtwork(artBranch)
                    detail?.let { Text(it, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
                }
            },
            confirmButton = { TextButton(onClick = { moment = null }, modifier = Modifier.testTag("career.milestone.continue")) {
                Text(copy.resolve("career.moment.continue"), verbatim = true)
            } })
    }
}

/** Ordinary growth is a short-lived line, never a report or an extra continue button. */
@Composable
internal fun RecentGrowthNotice(state: GameAggregateState, enabled: Boolean) {
    val receipt = state.meta.playerGrowth
    val career = state.highSchool?.run?.careerId ?: state.pro?.careerId
    var consumed by rememberSaveable(career) { mutableStateOf(receipt?.commandId) }
    LaunchedEffect(receipt?.commandId, enabled) {
        if (receipt != null && receipt.commandId != consumed) {
            if (enabled) kotlinx.coroutines.delay(3_500)
            consumed = receipt.commandId
        }
    }
    if (!enabled || receipt == null || receipt.commandId == consumed) return
    val copy = rememberGameCopy()
    val labels = listOf("구위", "제구", "무브먼트", "체력")
    val lines = labels.indices.mapNotNull { index ->
        val delta = AbilityDisplayScale.delta(receipt.before[index], receipt.after[index])
        if (delta > 0) "${copy.legacy(labels[index])} +$delta" else null
    }
    if (lines.isNotEmpty()) StatChangeText(lines.joinToString(" · "), verbatim = true, fontWeight = FontWeight.Bold,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 6.dp).testTag("career.growthNotice"))
}


internal fun skillCelebrationArt(branch: String): Int = when (branch) {
    "power" -> R.drawable.awakening_art_power
    "command" -> R.drawable.awakening_art_command
    "breaking" -> R.drawable.awakening_art_breaking
    else -> R.drawable.awakening_art_game
}

@Composable
internal fun SkillCelebrationArtwork(branch: String) {
    Image(painter = painterResource(skillCelebrationArt(branch)), contentDescription = null,
        contentScale = ContentScale.Fit,
        modifier = Modifier.fillMaxWidth().aspectRatio(1.5f).clip(MaterialTheme.shapes.medium).testTag("career.milestone.art.$branch"))
}
