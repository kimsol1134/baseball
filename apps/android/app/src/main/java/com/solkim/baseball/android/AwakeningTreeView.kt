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
    if (showsTree) Text("한 갈래를 깊게 파도 되고, 여러 갈래를 섞어도 된다. 전조가 3 이상이면 한 단계를 건너뛴다.")
    (if (showsTree) nodes else nodes.filter { it.available }).groupBy { it.branch }.forEach { (branch, branchNodes) ->
        Text(branch, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        branchNodes.forEach { node ->
            OutlinedCard(Modifier.fillMaxWidth().padding(start = ((node.tier - 1) * 10).dp).testTag("awakening.node.${node.id}")) {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(node.title, fontWeight = FontWeight.Bold)
                    Text(when { node.owned -> "내 것"; node.available && node.leap -> "지금 건너뛸 수 있다"; node.available -> "지금 익힐 수 있다"; else -> "아직 잠겨 있다" })
                    if (!node.owned) StatChangeText(node.effect)
                    if (!node.owned && !node.available && node.requirement.isNotEmpty()) Text("먼저 ${node.requirement}부터")
                    if (node.available) Button(onClick = { pending = node }, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("action.awakening:${node.id}")) { Text("이 각성 선택") }
                }
            }
        }
    }
    pending?.let { node ->
        AlertDialog(onDismissRequest = { pending = null }, title = { Text(node.title) },
            text = { Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                if (node.voice.isNotBlank()) Text(node.voice, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
                StatChangeText(node.effect)
                Text("한 생에 셋. 이걸로 갈까?")
            } },
            confirmButton = { TextButton(onClick = {
                model.actions.firstOrNull { it.id == "awakening:${node.id}" && it.enabled }?.let { onAction(Phase8UiAction(model.id, it.id, it.payloads)) }
                pending = null
            }, modifier = Modifier.testTag("awakening.confirm")) { Text("익히기") } },
            dismissButton = { TextButton(onClick = { pending = null }) { Text("다시 보기") } })
    }
}
