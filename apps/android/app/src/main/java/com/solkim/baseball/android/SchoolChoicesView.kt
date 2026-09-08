package com.solkim.baseball.android

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
internal fun Phase8SchoolChoices(state: GameAggregateState, model: Phase8ScreenModel, onAction: (Phase8UiAction) -> Unit) {
    val copy = rememberGameCopy()
    val schools = SchoolChoicePresentation.schools(state)
    var comparing by remember { mutableStateOf<String?>(null) }
    Text("어떤 강점을 키울까요?", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Text("다른 능력도 모두 훈련할 수 있어요.",
        style = MaterialTheme.typography.bodyMedium, color = BaseballColors.textSecondary)
    schools.forEach { school ->
        val action = model.actions.firstOrNull { it.id == "chooseSchool:${school.id.wire}" } ?: return@forEach
        Surface(color = BaseballColors.surfaceRaised, shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.padding(horizontal = 14.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(school.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Text(SchoolChoicePresentation.strength(school), color = BaseballColors.action, style = MaterialTheme.typography.bodyMedium)
                Text(SchoolChoicePresentation.fit(school), color = BaseballColors.textSecondary, style = MaterialTheme.typography.bodySmall)
                AdaptiveActionRow(Modifier.fillMaxWidth()) {
                    TextButton(onClick = { comparing = school.id.wire }, modifier = Modifier.testTag("school.compare.${school.id.wire}")) { Text("성장 비교") }
                    Button(onClick = { onAction(Phase8UiAction(model.id, action.id, action.payloads)) }, enabled = action.enabled,
                        modifier = Modifier.testTag("action.${action.id}")) { Text("이 학교 선택") }
                }
            }
        }
    }
    val selected = schools.firstOrNull { it.id.wire == comparing }
    if (selected != null) {
        val comparisons = remember(state.highSchool?.run?.stateCommitment, selected.id) { SchoolChoicePresentation.compare(state, selected.strength) }
        val chosen = comparisons.single { it.school.id == selected.id }
        val action = model.actions.first { it.id == "chooseSchool:${selected.id.wire}" }
        AlertDialog(onDismissRequest = { comparing = null }, containerColor = BaseballColors.surfaceRaised, modifier = Modifier.testTag("school.comparison"),
            title = { Text("성장 비교", style = MaterialTheme.typography.titleLarge) },
            text = { Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(selected.name, fontWeight = FontWeight.Bold)
                Text("${copy.legacy(TrainingPresentation.title(selected.strength))} · ${copy.legacy("보통 강도")}", verbatim = true,
                    color = BaseballColors.action, fontWeight = FontWeight.Bold)
                Text("현재 능력 · 입학 후 첫 훈련 1회 기준", style = MaterialTheme.typography.bodySmall)
                comparisons.forEach { row ->
                    Surface(color = if (row.school.id == selected.id) BaseballColors.actionSoft else BaseballColors.surfaceRaised,
                        border = BorderStroke(1.dp, if (row.school.id == selected.id) BaseballColors.action else BaseballColors.border),
                        shape = MaterialTheme.shapes.small, modifier = Modifier.fillMaxWidth().testTag("school.forecast.${row.school.id.wire}")) {
                        Row(Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Text(row.school.name, modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
                            Text("${copy.legacy(TrainingPresentation.metric(selected.strength))} ${SchoolChoicePresentation.range(row.minimum, row.maximum)}",
                                verbatim = true, color = BaseballColors.action, fontWeight = FontWeight.Bold)
                        }
                    }
                }
                if (comparisons.map { it.minimum to it.maximum }.distinct().size == 1)
                    Text("현재 조건에서는 기본 성장 예상이 같아요.", style = MaterialTheme.typography.bodySmall)
                if (chosen.atLimit) Text("현재 재능 한계에 도달해 기본 성장이 제한돼요.", style = MaterialTheme.typography.bodySmall)
                if (chosen.breakthroughChance > 0 && chosen.breakthroughMaximum > chosen.maximum)
                    Text(copy.resolve("school.choice.breakthrough", GameCopyArgument.Whole(chosen.breakthroughChance.toLong()),
                        GameCopyArgument.UserText(copy.legacy(TrainingPresentation.metric(selected.strength))),
                        GameCopyArgument.UserText(SchoolChoicePresentation.range(chosen.breakthroughMinimum, chosen.breakthroughMaximum))),
                        verbatim = true, style = MaterialTheme.typography.bodySmall)
                Text("훈련 강도와 몸 상태가 바뀌면 성장 예상도 달라져요.", style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
            } },
            confirmButton = { TextButton(onClick = { comparing = null; onAction(Phase8UiAction(model.id, action.id, action.payloads)) },
                enabled = action.enabled, modifier = Modifier.testTag("school.comparison.choose")) { Text("이 학교 선택") } },
            dismissButton = { TextButton(onClick = { comparing = null }, modifier = Modifier.testTag("school.comparison.close")) { Text("닫기") } })
    }
}
