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
                    TextButton(onClick = { comparing = school.id.wire }, modifier = Modifier.testTag("school.compare.${school.id.wire}")) { Text("학교 비교") }
                    Button(onClick = { onAction(Phase8UiAction(model.id, action.id, action.payloads)) }, enabled = action.enabled,
                        modifier = Modifier.testTag("action.${action.id}")) { Text("이 학교 선택") }
                }
            }
        }
    }
    val selected = schools.firstOrNull { it.id.wire == comparing }
    if (selected != null) {
        var goal by remember { mutableStateOf(SchoolDevelopmentGoal.STRENGTH) }
        val comparisons = remember(state.highSchool?.run?.stateCommitment, goal) { SchoolChoicePresentation.compare(state, goal) }
        val action = model.actions.first { it.id == "chooseSchool:${selected.id.wire}" }
        AlertDialog(onDismissRequest = { comparing = null }, containerColor = BaseballColors.surfaceRaised, modifier = Modifier.testTag("school.comparison"),
            title = { Text("학교 비교", style = MaterialTheme.typography.titleLarge) },
            text = { Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                AdaptiveActionRow(Modifier.fillMaxWidth()) {
                    FilterChip(selected = goal == SchoolDevelopmentGoal.STRENGTH, onClick = { goal = SchoolDevelopmentGoal.STRENGTH },
                        label = { Text("강점 더 키우기") }, modifier = Modifier.testTag("school.goal.strength"))
                    FilterChip(selected = goal == SchoolDevelopmentGoal.WEAKNESS, onClick = { goal = SchoolDevelopmentGoal.WEAKNESS },
                        label = { Text("약점 보완하기") }, modifier = Modifier.testTag("school.goal.weakness"))
                }
                Text(if (goal == SchoolDevelopmentGoal.STRENGTH) "현재 높은 능력을 더 키우는 학교를 추천해요."
                    else "현재 낮은 능력을 보완하는 학교를 추천해요.", style = MaterialTheme.typography.bodySmall)
                comparisons.forEach { row ->
                    val picked = row.school.id == selected.id
                    Surface(selected = picked, onClick = { comparing = row.school.id.wire },
                        color = if (picked) BaseballColors.actionSoft else BaseballColors.surfaceRaised,
                        border = BorderStroke(if (picked) 2.dp else 1.dp, if (picked) BaseballColors.action else BaseballColors.border),
                        shape = MaterialTheme.shapes.small, modifier = Modifier.fillMaxWidth().testTag("school.forecast.${row.school.id.wire}")) {
                        Column(Modifier.padding(10.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text(row.school.name, modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold)
                                if (row.recommended) Text("추천", color = BaseballColors.action, style = MaterialTheme.typography.labelMedium,
                                    modifier = Modifier.testTag("school.recommended.${row.school.id.wire}"))
                                if (picked) Text("✓", color = BaseballColors.action)
                            }
                            Text(SchoolChoicePresentation.strength(row.school), color = BaseballColors.action, style = MaterialTheme.typography.bodyMedium)
                            Text(copy.resolve("school.direction.current", GameCopyArgument.UserText(copy.legacy(TrainingPresentation.metric(row.school.strength))),
                                GameCopyArgument.Whole(row.currentRating.toLong())), verbatim = true, style = MaterialTheme.typography.bodySmall)
                            if (row.atLimit) Text("현재 재능 한계에 도달했어요.", color = BaseballColors.warning, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
                if (comparisons.none { it.recommended }) Text("능력과 성장 여유가 비슷하면 원하는 투구 스타일로 골라 주세요.", style = MaterialTheme.typography.bodySmall)
                Text("앞으로 자주 할 훈련을 기준으로 고르세요.", style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
            } },
            confirmButton = { TextButton(onClick = { comparing = null; onAction(Phase8UiAction(model.id, action.id, action.payloads)) },
                enabled = action.enabled, modifier = Modifier.testTag("school.comparison.choose")) { Text("이 학교 선택") } },
            dismissButton = { TextButton(onClick = { comparing = null }, modifier = Modifier.testTag("school.comparison.close")) { Text("닫기") } })
    }
}
