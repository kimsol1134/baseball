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

@OptIn(ExperimentalLayoutApi::class, ExperimentalMaterial3Api::class)
@Composable
internal fun TrainingScreen(state: GameAggregateState, context: Phase8CommandContext, busy: Boolean,
                            error: String?, insets: PaddingValues, resultStart: Int, dismissedResult: Int,
                            onDismiss: () -> Unit, onCommit: (Phase8UiAction) -> Unit, spotlight: Boolean = true,
                            feedbackState: GameAggregateState = state, playerContent: @Composable () -> Unit = {}, extraActions: @Composable () -> Unit = {}) {
    val school = state.highSchool ?: return
    val run = school.run
    var focusWire by rememberSaveable(run.careerId) { mutableStateOf(TrainingPresentation.initialFocus(state).wire) }
    var intensityWire by rememberSaveable(run.careerId) { mutableStateOf(TrainingPresentation.initialIntensity(state).wire) }
    var targetWire by rememberSaveable(run.careerId) { mutableStateOf(TrainingPresentation.initialTarget(state)?.wire) }
    var sheet by rememberSaveable(run.careerId) { mutableStateOf<String?>(null) }
    var selectedPlan by rememberSaveable(run.careerId) { mutableStateOf("balanced") }
    val rehab = run.injuryRecovery > 0
    val focus = if (rehab) TrainingFocus.RECOVERY else TrainingFocus.entries.single { it.wire == focusWire }
    val intensity = TrainingIntensity.entries.single { it.wire == intensityWire }
    val targets = TrainingPresentation.targets(state)
    val target = targets.firstOrNull { it.wire == targetWire } ?: targets.firstOrNull()
    val recommended = TrainingPresentation.recommended(state)
    val copy = rememberGameCopy()
    val preview = TrainingPresentation.preview(state, focus, intensity)
    val remaining = TrainingPresentation.remaining(state)
    val scroll = rememberScrollState()
    fun commit(repeat: Boolean) {
        onCommit(Phase8UiAction(Phase8ScreenId.P006_TRAINING, "train:${focus.wire}",
            TrainingPresentation.payloads(state, context, focus, intensity, target, repeat)))
    }
    Column(Modifier.fillMaxSize().padding(insets).padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        // Keep the current scroll and selections when a training receipt arrives.
        Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(scroll).testTag("training.scroll").padding(top = 8.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)) {
            playerContent()
            if (error != null) Text(error, color = MaterialTheme.colorScheme.error)
            Text(copy.resolve("training.compact.condition", GameCopyArgument.Whole(run.fatigue.toLong()),
                GameCopyArgument.Whole(run.armRisk.toLong()), GameCopyArgument.Whole(remaining.toLong())), verbatim = true,
                style = MaterialTheme.typography.bodyMedium,
                color = if (run.fatigue >= 70 || run.armRisk >= 55) BaseballColors.warning else BaseballColors.textSecondary)
            run.development?.let { if (it.hasSupport(focus)) focus else it.supportFocus }?.let { support ->
                Text(ChoiceEffect.trainingSupportLabel(support, copy), verbatim = true,
                    color = BaseballColors.milestone, style = MaterialTheme.typography.labelMedium, modifier = Modifier.testTag("training.conversationSupport"))
            }
            if (run.development?.starterTrialPending == true) Text("다음 등판: 선발 테스트", color = BaseballColors.milestone, style = MaterialTheme.typography.labelMedium)
            if (rehab) Text("재활 중이다. 오늘은 회복만.", color = BaseballColors.warning)
            else if (recommended == TrainingFocus.RECOVERY) Text("코치: 몸이 무겁다. 오늘은 쉬자.", color = BaseballColors.warning)
            FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("훈련 선택", style = MaterialTheme.typography.labelLarge)
                Text(copy.resolve("training.controls.recommended", GameCopyArgument.UserText(copy.legacy(trainingChoiceLabel(recommended)))),
                    verbatim = true, color = BaseballColors.textSecondary, style = MaterialTheme.typography.labelMedium,
                    modifier = Modifier.testTag("training.recommendation"))
            }
            Column(Modifier.testTag("training.choices"), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                TrainingFocus.entries.chunked(3).forEach { row ->
                    AdaptiveActionRow(Modifier.fillMaxWidth(), equalWidth = true) {
                        row.forEach { option ->
                            TrainingChoice(focus == option, !busy && (!rehab || option == TrainingFocus.RECOVERY),
                                Modifier.testTag("training.focus.${option.wire}"),
                                onClick = { focusWire = option.wire }) {
                                Text(trainingChoiceLabel(option), fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }
            if (focus == TrainingFocus.BREAKING_BALL && targets.isNotEmpty()) {
                FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    targets.forEach { pitch ->
                        FilterChip(selected = target == pitch, onClick = { targetWire = pitch.wire }, enabled = !busy,
                            colors = FilterChipDefaults.filterChipColors(selectedContainerColor = BaseballColors.action,
                                selectedLabelColor = BaseballColors.actionInk),
                            label = { Text(TrainingPresentation.pitchLabel(pitch)) },
                            modifier = Modifier.heightIn(min = 48.dp).testTag("training.target.${pitch.wire}"))
                    }
                }
            }
            if (!rehab) {
                Text(copy.resolve("training.compact.intensity"), verbatim = true, style = MaterialTheme.typography.labelLarge)
                AdaptiveActionRow(Modifier.fillMaxWidth(), equalWidth = true) {
                    TrainingIntensity.entries.forEach { level ->
                        TrainingChoice(intensity == level, !busy,
                            Modifier.testTag("training.intensity.${level.wire}"),
                            onClick = { intensityWire = level.wire }) {
                            Text(TrainingPresentation.intensityTitle(level, focus), style = MaterialTheme.typography.labelLarge,
                                fontWeight = FontWeight.Bold)

                        }
                    }
                }
            }
            Surface(color = BaseballColors.surfaceRaised, shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth().testTag("training.selectedDetail")) {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    val outlook = when {
                        focus == TrainingFocus.RECOVERY || rehab -> "성장 대신 피로를 던다."
                        else -> TrainingPresentation.growthOutlook(state, focus, preview, copy)
                    }
                    StatChangeText(outlook, modifier = Modifier.testTag("training.outlook"), style = MaterialTheme.typography.bodyMedium)
                    if (focus == TrainingFocus.GAME_PLANNING) Text(TrainingPresentation.detail(focus), style = MaterialTheme.typography.bodySmall)
                    TrainingPresentation.jackpotOutlook(state, focus, preview, copy)?.let { bonus ->
                        StatChangeText(bonus, modifier = Modifier.testTag("training.jackpot"), style = MaterialTheme.typography.bodySmall,
                            color = BaseballColors.milestone, verbatim = true)
                    }
                    StatChangeText("피로 ${run.fatigue} → ${(run.fatigue + preview.fatigueChange).coerceIn(0, 100)} · 팔 부담 ${run.armRisk} → ${(run.armRisk + preview.armRiskChange).coerceIn(0, 100)}",
                        style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
                }
            }
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                extraActions()
                TextButton(onClick = { sheet = "training" }, modifier = Modifier.testTag("training.details")) {
                    Text(copy.resolve("mobile.polish.training-details"), verbatim = true)
                }
                if (TrainingPresentation.learningLines(state).isNotEmpty()) TextButton(onClick = { sheet = "learning" }, modifier = Modifier.testTag("training.learning")) {
                    Text(copy.resolve("training.compact.learning"), verbatim = true)
                }
            }
        }
        if ((run.lastTraining?.number ?: 0) > dismissedResult) {
            Surface(color = BaseballColors.actionSoft, shape = MaterialTheme.shapes.small,
                modifier = Modifier.fillMaxWidth().testTag("training.result")) {
                Row(Modifier.padding(start = 12.dp), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                    val lines = TrainingPresentation.resultLines(feedbackState, resultStart)
                    StatChangeText(lines.drop(1).take(2).joinToString(" · "), modifier = Modifier.weight(1f).testTag("training.result.gains"),
                        style = MaterialTheme.typography.bodyMedium)
                    TextButton(onClick = { sheet = "result" }, modifier = Modifier.testTag("training.result.open")) {
                        Text(copy.resolve("training.compact.result"), verbatim = true)
                    }
                }
            }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { commit(false) }, enabled = !busy, modifier = Modifier.weight(1f).heightIn(min = 48.dp).testTag("training.commit")) { Text("훈련하기") }
            OutlinedButton(onClick = {
                if (TrainingPlans.availableSteps(state, TrainingPlans.options.single { it.id == selectedPlan }) == 0) selectedPlan = "condition"
                sheet = "plans"
            }, enabled = !busy, modifier = Modifier.heightIn(min = 48.dp).testTag("training.repeat")) {
                Text(copy.resolve("training.plan.open"), verbatim = true)
            }
        }
        Spacer(Modifier.height(4.dp))
    }
    if (sheet != null) ModalBottomSheet(onDismissRequest = { sheet = null }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
        Column(Modifier.fillMaxWidth().heightIn(max = if (sheet == "plans") 430.dp else 560.dp).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)) {
            when (sheet) {
                "plans" -> {
                    Text(copy.resolve("training.plan.title"), verbatim = true, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    if (!rehab) {
                        TrainingPlans.options.forEach { plan ->
                            TrainingChoice(selectedPlan == plan.id, !busy && TrainingPlans.availableSteps(state, plan) > 0, Modifier.fillMaxWidth().testTag("training.plan.${plan.id}"),
                                onClick = { selectedPlan = plan.id }) {
                                Text(copy.resolve("training.plan.${plan.id}"), verbatim = true, fontWeight = FontWeight.Bold)
                            }
                        }
                        val plan = TrainingPlans.options.single { it.id == selectedPlan }
                        Text(plan.steps.joinToString(" → ") { (step, _) -> copy.legacy(TrainingPlans.label(step)) },
                            verbatim = true, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.testTag("training.plan.steps"))
                        Text(copy.resolve("training.plan.limit", GameCopyArgument.Whole(TrainingPlans.availableSteps(state, plan).toLong())),
                            verbatim = true, style = MaterialTheme.typography.bodySmall)
                        Text(copy.resolve("training.plan.intensities"), verbatim = true, style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
                    }
                    OutlinedButton(onClick = { sheet = null; commit(true) }, enabled = !busy && remaining > 1, modifier = Modifier.testTag("training.plan.repeat")) {
                        Text(copy.resolve("training.plan.repeat-count", GameCopyArgument.Whole(TrainingPresentation.repeatCount(state).toLong())), verbatim = true)
                    }
                    Text(copy.resolve("training.compact.repeat-help"), verbatim = true, style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
                }
                "result" -> TrainingResultCard(feedbackState, resultStart, compact = false, onDismiss = { onDismiss(); sheet = null })
                "learning" -> {
                    TrainingPresentation.learningLines(state).forEach { Text(it) }
                    run.pitchLearningProject?.takeIf { !it.completed }?.let { project ->
                        Button(onClick = { focusWire = TrainingFocus.BREAKING_BALL.wire; targetWire = project.pitchType.wire; sheet = null },
                            enabled = !busy && !rehab, modifier = Modifier.fillMaxWidth().testTag("training.learning.practice")) {
                            Text(copy.resolve("training.clear.select-practice"), verbatim = true)
                        }
                    }
                }
                else -> {
                    Text(TrainingPresentation.title(focus), style = MaterialTheme.typography.titleLarge)
                    Text(TrainingPresentation.detail(focus))
                    if (preview.schoolBonus) Text("학교 특기", color = BaseballColors.milestone)
                    if (preview.opportunityBonus) run.trainingOpportunity?.reason?.let { Text(it) }
                    if (focus == TrainingFocus.COMMAND || focus == TrainingFocus.GAME_PLANNING) ControlMilestoneGoal(run.pitcher.command)
                    Text(copy.resolve("training.compact.repeat-help"), verbatim = true, color = BaseballColors.textSecondary)
                }
            }
            TextButton(onClick = { sheet = null }, modifier = Modifier.testTag("training.sheet.close")) { Text(copy.resolve("action.close"), verbatim = true) }
        }
        if (sheet == "plans" && !rehab) {
            val plan = TrainingPlans.options.single { it.id == selectedPlan }
            Button(onClick = {
                val payloads = TrainingPlans.payloads(state, context, selectedPlan)
                sheet = null
                onCommit(Phase8UiAction(Phase8ScreenId.P006_TRAINING, payloads.first().actionId, payloads))
            }, enabled = !busy && TrainingPlans.availableSteps(state, plan) > 0,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp).heightIn(min = 48.dp).testTag("training.plan.execute")) {
                Text(copy.resolve("training.plan.execute"), verbatim = true)
            }
        }
    }
}

@Composable
private fun TrainingChoice(selected: Boolean, enabled: Boolean, modifier: Modifier, onClick: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    Surface(onClick = onClick, enabled = enabled,
        color = if (selected) BaseballColors.action else BaseballColors.surfaceRaised,
        contentColor = if (selected) BaseballColors.actionInk else BaseballColors.textPrimary,
        shape = MaterialTheme.shapes.small,
        border = BorderStroke(if (selected) 2.dp else 1.dp, if (selected) BaseballColors.action else BaseballColors.border),
        modifier = modifier.heightIn(min = 48.dp).semantics { this.selected = selected }) {
        Column(Modifier.padding(horizontal = 8.dp, vertical = 6.dp), horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center, content = content)
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

private fun trainingChoiceLabel(focus: TrainingFocus): String = when (focus) {
    TrainingFocus.VELOCITY -> "구위"
    TrainingFocus.COMMAND -> "제구"
    TrainingFocus.BREAKING_BALL -> "변화구"
    TrainingFocus.STAMINA -> "체력"
    TrainingFocus.RECOVERY -> "회복"
    TrainingFocus.GAME_PLANNING -> "배합 연습"
}
