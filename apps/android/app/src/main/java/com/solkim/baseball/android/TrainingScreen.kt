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
    var showsRepeatHelp by rememberSaveable { mutableStateOf(false) }
    var showsLearningDetails by rememberSaveable(run.careerId) { mutableStateOf(false) }
    var showsOtherTraining by rememberSaveable(run.careerId) { mutableStateOf(false) }
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
            if (rehab) Text("재활 중에는 회복 훈련을 합니다.", color = BaseballColors.warning)
            else if (recommended == TrainingFocus.RECOVERY) Text("몸이 많이 지쳤어요. 이번에는 회복을 추천해요.", color = BaseballColors.warning)
            if ((run.lastTraining?.number ?: 0) > dismissedResult) TrainingResultCard(state, resultStart, !spotlight, onDismiss)
            Text(copy.resolve("training.prompt"), verbatim = true, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            TextButton(onClick = { showsOtherTraining = !showsOtherTraining }, modifier = Modifier.testTag("training.change")) {
                Text(rememberGameCopy().resolve("mobile.core.change-training"), verbatim = true)
            }
            (listOf(focus) + if (showsOtherTraining) TrainingFocus.entries.filter { it != focus } else emptyList()).forEach { option ->
                val selected = option == focus
                val preview = TrainingPresentation.preview(state, option, intensity)
                Card(
                    modifier = Modifier.fillMaxWidth().testTag("training.focus.${option.wire}")
                        .clickable(enabled = !busy && (!rehab || option == TrainingFocus.RECOVERY)) { focusWire = option.wire }
                        .semantics { this.selected = selected; role = Role.RadioButton },
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
                        Text("피로 ${if (preview.fatigueChange >= 0) "+" else ""}${preview.fatigueChange} · 팔 부담 ${if (preview.armRiskChange >= 0) "+" else ""}${preview.armRiskChange}", style = MaterialTheme.typography.bodySmall)
                        if (selected) {
                            if (option == TrainingFocus.BREAKING_BALL) {
                                Text("연습할 구종", fontWeight = FontWeight.SemiBold)
                                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) { targets.forEach { pitch ->
                                    FilterChip(selected = target == pitch, onClick = { targetWire = pitch.wire }, enabled = !busy, colors = chipColors,
                                        label = { Text(TrainingPresentation.pitchLabel(pitch)) }, modifier = Modifier.weight(1f).heightIn(min = 48.dp).testTag("training.target.${pitch.wire}"))
                                } }
                                target?.let { Text(TrainingPresentation.targetStatus(state, it), style = MaterialTheme.typography.bodySmall) }
                            }
                            if (!rehab) {
                                Text("훈련 강도", fontWeight = FontWeight.SemiBold)
                                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) { TrainingIntensity.entries.forEach { level ->
                                    FilterChip(selected = intensity == level, onClick = { intensityWire = level.wire }, enabled = !busy, colors = chipColors,
                                        label = { Text(TrainingPresentation.intensityTitle(level, option)) }, modifier = Modifier.weight(1f).heightIn(min = 48.dp).testTag("training.intensity.${level.wire}"))
                                } }
                            }
                            val outlook = when {
                                option == TrainingFocus.RECOVERY || rehab -> "휴식은 능력 성장 대신 피로를 줄여요."
                                preview.atTalentWall -> "능력 한계에 도달했어요. 숙련이나 재능 발현을 노려보세요."
                                else -> "성장 예상 +${TrainingPresentation.displayGrowth(state, option, preview.minimumGrowth)}~${TrainingPresentation.displayGrowth(state, option, preview.maximumGrowth)} · 대성공은 별도"
                            }
                            Text(outlook, modifier = Modifier.testTag("training.outlook"), style = MaterialTheme.typography.bodyMedium)
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
                Card(Modifier.fillMaxWidth().testTag("training.learning")) {
                    Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(lines.first(), fontWeight = FontWeight.SemiBold)
                        if (lines.size > 1) Text(lines[1], style = MaterialTheme.typography.bodySmall)
                        TextButton(onClick = { showsLearningDetails = !showsLearningDetails }) { Text(copy.resolve("mobile.polish.pitch-project"), verbatim = true) }
                        if (showsLearningDetails) lines.drop(2).forEach { Text(it) }
                    }
                }
            }
            TextButton(onClick = { showsRepeatHelp = !showsRepeatHelp }) { Text(copy.resolve("mobile.polish.repeat-help"), verbatim = true) }
            if (showsRepeatHelp) Text("연속 훈련은 일정이 바뀌거나 재능이 발현되면 멈춰요. 회복 외 훈련은 피로 75 이상이거나 팔 상태가 나빠져도 멈춰요.", style = MaterialTheme.typography.bodySmall)
            Spacer(Modifier.height(8.dp))
        }
        HorizontalDivider()
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { commit(false) }, enabled = !busy, modifier = Modifier.weight(1f).heightIn(min = 56.dp).testTag("training.commit")) { Text("훈련하기") }
            OutlinedButton(onClick = { commit(true) }, enabled = !busy, modifier = Modifier.heightIn(min = 56.dp).testTag("training.repeat").gameDescription("같은 훈련 최대 3회")) { Text("×3") }
        }
        Spacer(Modifier.height(4.dp))
    }
}

@Composable
internal fun TrainingResultCard(state: GameAggregateState, afterNumber: Int, compact: Boolean, onDismiss: () -> Unit) {
    val lines = TrainingPresentation.resultLines(state, afterNumber)
    if (lines.isEmpty()) return
    Card(Modifier.fillMaxWidth().testTag("training.result"), colors = CardDefaults.cardColors(containerColor = BaseballColors.surfaceRaised)) {
        Column(Modifier.padding(if (compact) 10.dp else 14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(lines.first(), fontWeight = FontWeight.Bold)
                TextButton(onClick = onDismiss, modifier = Modifier.testTag("training.result.dismiss")) { Text("닫기") }
            }
            val receipt = state.meta.playerGrowth?.takeIf { it.careerId == state.highSchool?.run?.careerId && it.source == "training" }
            if (receipt != null) {
                CoreGrowthResult(receipt, compact)
                Text(lines.drop(1).filterNot { it.startsWith("구위 ") || it.startsWith("제구 ") || it.startsWith("무브먼트 ") || it.startsWith("체력 ") }.joinToString(" · "),
                    style = MaterialTheme.typography.bodyMedium, modifier = Modifier.testTag("training.result.gains"))
            } else Text(lines.drop(1).joinToString(" · "), style = if (compact) MaterialTheme.typography.bodyMedium else MaterialTheme.typography.titleLarge,
                color = BaseballColors.action, modifier = Modifier.testTag("training.result.gains"))
        }
    }
}
