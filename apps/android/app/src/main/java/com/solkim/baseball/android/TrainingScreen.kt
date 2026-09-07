package com.solkim.baseball.android

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.android.LocalizedGameText as Text

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun TrainingScreen(state: GameAggregateState, context: Phase8CommandContext, busy: Boolean,
                            error: String?, insets: PaddingValues, resultStart: Int, dismissedResult: Int,
                            onDismiss: () -> Unit, onCommit: (Phase8UiAction) -> Unit, spotlight: Boolean = true) {
    val school = state.highSchool ?: return
    val run = school.run
    var focusWire by rememberSaveable(run.careerId) { mutableStateOf(TrainingPresentation.initialFocus(state).wire) }
    var intensityWire by rememberSaveable(run.careerId) { mutableStateOf(TrainingPresentation.initialIntensity(state).wire) }
    var targetWire by rememberSaveable(run.careerId) { mutableStateOf(TrainingPresentation.initialTarget(state)?.wire) }
    val rehab = run.injuryRecovery > 0
    val focus = if (rehab) TrainingFocus.RECOVERY else TrainingFocus.entries.single { it.wire == focusWire }
    val intensity = TrainingIntensity.entries.single { it.wire == intensityWire }
    val targets = TrainingPresentation.targets(state)
    val target = targets.firstOrNull { it.wire == targetWire } ?: targets.firstOrNull()
    val recommended = TrainingPresentation.recommended(state)
    val copy = rememberGameCopy()
    val chipColors = FilterChipDefaults.filterChipColors(selectedContainerColor = BaseballColors.action.copy(alpha = 0.18f),
        selectedLabelColor = BaseballColors.action, selectedLeadingIconColor = BaseballColors.action)
    val scroll = rememberScrollState()
    var showsFocusDetails by rememberSaveable(run.careerId, focusWire) { mutableStateOf(false) }
    var showsLearningDetails by rememberSaveable(run.careerId) { mutableStateOf(false) }
    LaunchedEffect(run.totalTrainingsCompleted) {
        if ((run.lastTraining?.number ?: 0) > dismissedResult) scroll.animateScrollTo(0)
    }
    fun commit(repeat: Boolean) {
        val payloads = TrainingPresentation.payloads(state, context, focus, intensity, target, repeat)
        onCommit(Phase8UiAction(Phase8ScreenId.P006_TRAINING, "train:${focus.wire}", payloads))
    }
    Column(Modifier.fillMaxSize().padding(insets).padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(scroll).padding(top = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (error != null) Text(error, color = MaterialTheme.colorScheme.error)
            CorePlayerHeader(state, compact = true)
            Text("피로 ${run.fatigue} · 팔 부담 ${run.armRisk}", color = if (run.fatigue >= 70 || run.armRisk >= 55) BaseballColors.warning else BaseballColors.textSecondary)
            if (rehab) Text("재활 중이다. 오늘은 회복만.", color = BaseballColors.warning)
            else if (recommended == TrainingFocus.RECOVERY) Text("코치: 몸이 무겁다. 오늘은 쉬자.", color = BaseballColors.warning)
            if ((run.lastTraining?.number ?: 0) > dismissedResult) TrainingResultCard(state, resultStart, !spotlight, onDismiss)
            Text(copy.resolve("training.prompt"), verbatim = true, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            FlowRow(Modifier.fillMaxWidth().testTag("training.choices"), maxItemsInEachRow = 3, horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                TrainingFocus.entries.forEach { option ->
                    val title = when (option) {
                        TrainingFocus.VELOCITY -> "구위"
                        TrainingFocus.COMMAND -> "제구"
                        TrainingFocus.BREAKING_BALL -> "변화구"
                        TrainingFocus.STAMINA -> "체력"
                        TrainingFocus.RECOVERY -> "회복"
                        TrainingFocus.GAME_PLANNING -> "수싸움"
                    }
                    FilterChip(selected = focus == option, onClick = { focusWire = option.wire },
                        enabled = !busy && (!rehab || option == TrainingFocus.RECOVERY), colors = chipColors,
                        label = { Text(title) }, modifier = Modifier.heightIn(min = 48.dp).testTag("training.focus.${option.wire}"))
                }
            }
            listOf(focus).forEach { option ->
                val selected = option == focus
                val preview = TrainingPresentation.preview(state, option, intensity)
                Card(
                    modifier = Modifier.fillMaxWidth().testTag("training.selectedDetail"),
                    border = BorderStroke(if (selected) 2.dp else 1.dp, if (selected) BaseballColors.action else BaseballColors.border),
                    colors = CardDefaults.cardColors(containerColor = if (selected) BaseballColors.surfaceRaised else BaseballColors.surface),
                ) {
                    Column(Modifier.fillMaxWidth().padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(TrainingPresentation.title(option), fontWeight = FontWeight.Bold, color = if (selected) BaseballColors.action else BaseballColors.textPrimary)
                        val badges = buildList {
                            if (option == recommended) add(copy.resolve("mobile.polish.focus-recommended"))
                            if (preview.schoolBonus) add("학교 특기")
                            if (preview.opportunityBonus) add("오늘의 기회")
                        }
                        if (badges.isNotEmpty()) Text(badges.joinToString(" · "), style = MaterialTheme.typography.labelSmall, color = BaseballColors.milestone)
                        StatChangeText("피로 ${if (preview.fatigueChange >= 0) "+" else ""}${preview.fatigueChange} · 팔 부담 ${if (preview.armRiskChange >= 0) "+" else ""}${preview.armRiskChange}", style = MaterialTheme.typography.bodySmall)
                        if (selected) {
                            if (option == TrainingFocus.BREAKING_BALL) {
                                Text("연습할 구종", fontWeight = FontWeight.SemiBold)
                                FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) { targets.forEach { pitch ->
                                    FilterChip(selected = target == pitch, onClick = { targetWire = pitch.wire }, enabled = !busy, colors = chipColors,
                                        label = { Text(TrainingPresentation.pitchLabel(pitch)) }, modifier = Modifier.heightIn(min = 48.dp).testTag("training.target.${pitch.wire}"))
                                } }
                                target?.let { Text(TrainingPresentation.targetStatus(state, it), style = MaterialTheme.typography.bodySmall) }
                            }
                            if (!rehab) {
                                Text("훈련 강도", fontWeight = FontWeight.SemiBold)
                                FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) { TrainingIntensity.entries.forEach { level ->
                                    FilterChip(selected = intensity == level, onClick = { intensityWire = level.wire }, enabled = !busy, colors = chipColors,
                                        label = { Text(TrainingPresentation.intensityTitle(level, option)) }, modifier = Modifier.heightIn(min = 48.dp).testTag("training.intensity.${level.wire}"))
                                } }
                            }
                            val outlook = when {
                                option == TrainingFocus.RECOVERY || rehab -> "성장 대신 피로를 던다."
                                preview.atTalentWall -> "재능의 벽이다. 숙련을 쌓거나 벽이 열리길 기다리자."
                                else -> TrainingPresentation.growthOutlook(state, option, preview, copy)
                            }
                            StatChangeText(outlook, modifier = Modifier.testTag("training.outlook"), style = MaterialTheme.typography.bodyMedium)
                            if (option == TrainingFocus.COMMAND || option == TrainingFocus.GAME_PLANNING) ControlMilestoneGoal(run.pitcher.command)
                            TextButton(onClick = { showsFocusDetails = !showsFocusDetails }) { Text(copy.resolve("mobile.polish.training-details"), verbatim = true) }
                            if (showsFocusDetails) {
                                Text(TrainingPresentation.detail(option), style = MaterialTheme.typography.bodyMedium)
                                if (preview.opportunityBonus) run.trainingOpportunity?.reason?.let { Text(it, style = MaterialTheme.typography.bodySmall) }
                            }
                        }
                    }
                }
            }
            TrainingPresentation.learningLines(state).takeIf { it.isNotEmpty() }?.let { lines ->
                Card(Modifier.fillMaxWidth().testTag("training.learning").clickable(enabled = !busy && !rehab && run.pitchLearningProject?.completed != true) {
                    focusWire = TrainingFocus.BREAKING_BALL.wire
                    targetWire = run.pitchLearningProject?.pitchType?.wire
                    showsLearningDetails = true
                }.semantics { role = Role.Button }) {
                    Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(lines.first(), fontWeight = FontWeight.SemiBold)
                        if (lines.size > 1) Text(lines[1], style = MaterialTheme.typography.bodySmall)
                        if (!rehab && run.pitchLearningProject?.completed != true) Text(copy.resolve("training.clear.select-practice"), verbatim = true, color = BaseballColors.action, style = MaterialTheme.typography.labelLarge)
                        TextButton(onClick = { showsLearningDetails = !showsLearningDetails }) { Text(copy.resolve("mobile.polish.pitch-project"), verbatim = true) }
                        if (showsLearningDetails) lines.drop(2).forEach { Text(it) }
                    }
                }
            }
            Spacer(Modifier.height(8.dp))
        }
        HorizontalDivider()
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { commit(false) }, enabled = !busy, modifier = Modifier.weight(1f).heightIn(min = 56.dp).testTag("training.commit")) { Text("훈련하기") }
            OutlinedButton(onClick = { commit(true) }, enabled = !busy, modifier = Modifier.heightIn(min = 56.dp).testTag("training.repeat").gameDescription("같은 훈련 3번 연속. 일정이 바뀌거나 몸이 지치면 멈춘다.")) { Text("×3") }
        }
        Spacer(Modifier.height(4.dp))
    }
}

@Composable
internal fun TrainingResultCard(state: GameAggregateState, afterNumber: Int, compact: Boolean, onDismiss: () -> Unit) {
    val lines = TrainingPresentation.resultLines(state, afterNumber)
    if (lines.isEmpty()) return
    val copy = rememberGameCopy()
    val receipt = state.meta.playerGrowth?.takeIf { it.careerId == state.highSchool?.run?.careerId && it.source == "training" }
    var details by remember(receipt?.commandId, state.highSchool?.run?.lastTraining?.number) { mutableStateOf(false) }
    val change = TrainingPresentation.fatigueChange(state, afterNumber)
    val fatigue = state.highSchool?.run?.fatigue ?: 0
    Card(Modifier.fillMaxWidth().testTag("training.result"), colors = CardDefaults.cardColors(containerColor = BaseballColors.surfaceRaised)) {
        Column(Modifier.padding(if (compact) 10.dp else 14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                if (receipt != null) CoreGrowthResult(receipt, compact, detailsToggle = false, modifier = Modifier.weight(1f))
                else Text(lines.getOrElse(1) { lines.first() }, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                TextButton(onClick = onDismiss, modifier = Modifier.testTag("training.result.dismiss")) { Text("닫기") }
            }
            StatChangeText(GrowthFeedbackPresentation.condition(copy, fatigue, change), verbatim = true,
                style = MaterialTheme.typography.bodyMedium, color = BaseballColors.textSecondary,
                modifier = Modifier.testTag("training.result.gains"))
            if (state.highSchool?.run?.lastTraining?.bloomed == true) Text("재능의 한계를 넘었어요!", color = BaseballColors.milestone)
            TrainingPresentation.coachLine(state)?.let { Text(it, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.testTag("training.result.coach")) }
            TextButton(onClick = { details = !details }, modifier = Modifier.testTag("training.result.details")) { Text(copy.resolve("loop.growth.details"), verbatim = true) }
            if (details) {
                lines.forEach { StatChangeText(it, style = MaterialTheme.typography.bodySmall) }
                if (receipt != null && !GrowthFeedbackPresentation.controlMilestone(receipt) && receipt.before[1] != receipt.after[1]) {
                    ControlWindowPreview(receipt.after[1], receipt.before[1], titleKey = "loop.growth.base-window")
                }
                Text(copy.resolve("loop.condition.explanation"), verbatim = true, style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}
