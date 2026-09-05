package com.solkim.baseball.android

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.android.LocalizedGameText as Text

@Composable
internal fun AwakeningTreeView(state: GameAggregateState, model: Phase8ScreenModel, onAction: (Phase8UiAction) -> Unit) {
    val copy = rememberGameCopy()
    var showsTree by remember { mutableStateOf(false) }
    val nodes = remember(state.highSchool?.run) { CareerChoicePresentation.awakeningTree(state) }
    var pending by remember(state.highSchool?.run?.revision) { mutableStateOf<AwakeningChoiceView?>(null) }
    Text("어떤 투수로 성장할까요?", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Text("이번 생의 각성 ${state.highSchool?.run?.selectedAwakenings?.size ?: 0}/3 · 전조 ${state.highSchool?.run?.awakeningSparks ?: 0}")
    TextButton(onClick = { showsTree = !showsTree }, modifier = Modifier.testTag("awakening.fullTree")) {
        Text(copy.resolve(if (showsTree) "mobile.polish.available-awakenings" else "mobile.polish.full-tree"), verbatim = true)
    }
    if (showsTree) Text("한 갈래를 깊게 익히거나 여러 갈래를 골라 보세요. 전조가 3 이상이면 한 단계를 건너뛸 수 있어요.")
    (if (showsTree) nodes else nodes.filter { it.available }).groupBy { it.branch }.forEach { (branch, branchNodes) ->
        Text(branch, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        branchNodes.forEach { node ->
            OutlinedCard(Modifier.fillMaxWidth().padding(start = ((node.tier - 1) * 10).dp).testTag("awakening.node.${node.id}")) {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(node.title, fontWeight = FontWeight.Bold)
                    Text(when { node.owned -> "습득함"; node.available && node.leap -> "단계 건너뛰기 가능"; node.available -> "선택 가능"; else -> "아직 잠겨 있어요" })
                    if (!node.owned) Text(node.effect)
                    if (!node.owned && !node.available && node.requirement.isNotEmpty()) Text("먼저 익힐 각성: ${node.requirement}")
                    if (node.available) Button(onClick = { pending = node }, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("action.awakening:${node.id}")) { Text("이 각성 선택") }
                }
            }
        }
    }
    pending?.let { node ->
        AlertDialog(onDismissRequest = { pending = null }, title = { Text(node.title) },
            text = { Column(verticalArrangement = Arrangement.spacedBy(10.dp)) { Text(node.effect); Text("이번 생에 익힐 각성으로 선택할까요?") } },
            confirmButton = { TextButton(onClick = {
                model.actions.firstOrNull { it.id == "awakening:${node.id}" && it.enabled }?.let { onAction(Phase8UiAction(model.id, it.id, it.payloads)) }
                pending = null
            }, modifier = Modifier.testTag("awakening.confirm")) { Text("익히기") } },
            dismissButton = { TextButton(onClick = { pending = null }) { Text("다시 보기") } })
    }
}
