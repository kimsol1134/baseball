package com.solkim.baseball.android

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.android.LocalizedGameText as Text

@Composable
internal fun AwakeningTreeView(state: GameAggregateState, model: Phase8ScreenModel, onAction: (Phase8UiAction) -> Unit,
                               modifier: Modifier = Modifier, busy: Boolean = false) {
    val run = state.highSchool?.run ?: return
    val copy = rememberGameCopy()
    val nodes = remember(run) { AwakeningTreePresentation.nodes(state) }
    val owned = run.selectedAwakenings.map { it.wire }
    val preferred = nodes.firstOrNull { it.choice.available && it.parents.any(owned::contains) }
        ?: nodes.firstOrNull { it.choice.available } ?: nodes.first()
    var branch by rememberSaveable(run.careerId) { mutableStateOf(preferred.branch) }
    var selectedId by rememberSaveable(run.careerId) { mutableStateOf(preferred.choice.id) }
    var details by rememberSaveable(run.careerId) { mutableStateOf(false) }
    val selected = nodes.firstOrNull { it.choice.id == selectedId } ?: preferred
    val summary = AwakeningTreePresentation.summary(state, selected, copy)
    val action = model.actions.firstOrNull { it.id == "awakening:${selected.choice.id}" && it.enabled }
    val canConfirm = selected.choice.available && !selected.choice.owned && owned.size < 3 && action != null && !busy
    val rowHeight = 88.dp * LocalDensity.current.fontScale.coerceAtLeast(1f)
    fun inspect(node: AwakeningTreeNode) { branch = node.branch; selectedId = node.choice.id; details = false }

    Column(modifier.fillMaxSize().padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Column(Modifier.fillMaxWidth().padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(copy.resolve("awakening.tree.slots"), verbatim = true, style = MaterialTheme.typography.labelMedium)
                repeat(3) { index ->
                    val node = owned.getOrNull(index)?.let { id -> nodes.single { it.choice.id == id } }
                    if (node != null) Surface(onClick = { inspect(node) }, enabled = !busy, shape = MaterialTheme.shapes.small,
                        color = BaseballColors.action, modifier = Modifier.size(44.dp).gameDescription(node.choice.title)) {
                        Box(contentAlignment = Alignment.Center) { AwakeningGlyph(node.choice.id, BaseballColors.actionInk, Modifier.size(23.dp)) }
                    } else Box(Modifier.size(36.dp).border(1.dp, BaseballColors.border, MaterialTheme.shapes.small)
                        .clearAndSetSemantics { contentDescription = copy.resolve("awakening.tree.empty-slot") }, contentAlignment = Alignment.Center) {
                        Text("+", color = BaseballColors.textTertiary)
                    }
                }
                Spacer(Modifier.weight(1f))
                Text("${owned.size}/3", verbatim = true, style = MaterialTheme.typography.labelMedium, modifier = Modifier.testTag("awakening.slots"))
            }
            Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                AwakeningTreePresentation.branches.forEach { key ->
                    Surface(onClick = {
                        inspect(nodes.firstOrNull { it.branch == key && it.choice.available } ?: nodes.first { it.branch == key })
                    }, enabled = !busy, shape = MaterialTheme.shapes.small, color = BaseballColors.surfaceRaised,
                        border = BorderStroke(if (branch == key) 2.dp else 1.dp, if (branch == key) BaseballColors.action else BaseballColors.border),
                        modifier = Modifier.weight(1f).fillMaxHeight().semantics { this.selected = branch == key; role = Role.Tab }.testTag("awakening.branch.$key")) {
                        Column(Modifier.padding(horizontal = 3.dp, vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            AwakeningGlyph(key, if (branch == key) BaseballColors.action else BaseballColors.textSecondary, Modifier.size(22.dp))
                            Text(copy.resolve("awakening.tree.branch.$key"), verbatim = true, style = MaterialTheme.typography.labelMedium, textAlign = TextAlign.Center)
                        }
                    }
                }
            }
        }
        Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            val visible = nodes.filter { it.branch == branch }
            BoxWithConstraints(Modifier.fillMaxWidth().height(rowHeight * 3).testTag("awakening.tree")) {
                val width = maxWidth
                val nodeWidth = (width * 0.44f).coerceAtMost(156.dp)
                Canvas(Modifier.fillMaxSize()) {
                    visible.forEach { node -> node.parents.forEach { parentId ->
                        val parent = visible.firstOrNull { it.choice.id == parentId } ?: return@forEach
                        val x1 = size.width * parent.column
                        val x2 = size.width * node.column
                        // Connect below the label, never through the text or the glyph.
                        val y1 = rowHeight.toPx() * parent.choice.tier - 8.dp.toPx()
                        val y2 = rowHeight.toPx() * (node.choice.tier - 1) + 3.dp.toPx()
                        val middle = (y1 + y2) / 2
                        val learned = parent.choice.owned && node.choice.owned
                        drawPath(Path().apply { moveTo(x1, y1); lineTo(x1, middle); lineTo(x2, middle); lineTo(x2, y2) },
                            if (learned) BaseballColors.action else BaseballColors.border,
                            style = Stroke(1.5.dp.toPx(), pathEffect = if (node.choice.leap && node.choice.available) PathEffect.dashPathEffect(floatArrayOf(6.dp.toPx(), 4.dp.toPx())) else null))
                    } }
                }
                visible.forEach { node ->
                    val choice = node.choice
                    val isSelected = selectedId == choice.id
                    val filled = choice.owned || (isSelected && choice.available)
                    val status = when { choice.owned -> "owned"; choice.available && choice.leap -> "leap"; choice.available -> "available"; else -> "locked" }
                    Surface(onClick = { inspect(node) }, enabled = !busy,
                        color = if (isSelected) BaseballColors.actionSoft else androidx.compose.ui.graphics.Color.Transparent,
                        shape = MaterialTheme.shapes.medium,
                        border = if (isSelected) BorderStroke(2.dp, BaseballColors.action) else null,
                        modifier = Modifier.offset(x = width * node.column - nodeWidth / 2, y = rowHeight * (choice.tier - 1))
                            .width(nodeWidth).heightIn(min = 76.dp).semantics { this.selected = selectedId == choice.id; role = Role.Button }
                            .testTag("awakening.node.${choice.id}")
                            .gameDescription("${copy.legacy(choice.title)}. ${copy.resolve("awakening.tree.state.$status")}")) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Box(Modifier.size(50.dp), contentAlignment = Alignment.Center) {
                                Surface(shape = CircleShape, color = if (filled) BaseballColors.action else BaseballColors.surfaceRaised,
                                    border = BorderStroke(if (isSelected) 3.dp else 2.dp,
                                        if (isSelected || choice.available || choice.owned) BaseballColors.action else BaseballColors.border),
                                    modifier = Modifier.size(44.dp)) {
                                    Box(contentAlignment = Alignment.Center) { AwakeningGlyph(choice.id,
                                        if (filled) BaseballColors.actionInk else if (choice.available) BaseballColors.action else BaseballColors.textTertiary, Modifier.size(23.dp)) }
                                }
                                if (choice.owned || !choice.available || choice.leap) Surface(shape = CircleShape, color = BaseballColors.surface,
                                    modifier = Modifier.align(Alignment.BottomEnd).size(18.dp)) {
                                    Box(contentAlignment = Alignment.Center) {
                                        when { choice.owned -> Text("✓", verbatim = true, style = MaterialTheme.typography.labelSmall, color = BaseballColors.action)
                                            choice.available && choice.leap -> Text("↗", verbatim = true, style = MaterialTheme.typography.labelSmall, color = BaseballColors.milestone)
                                            else -> AwakeningGlyph("lock", BaseballColors.textSecondary, Modifier.size(13.dp)) }
                                    }
                                }
                            }
                            Text(copy.resolve("awakening.tree.short.${choice.id}"), verbatim = true, textAlign = TextAlign.Center,
                                style = MaterialTheme.typography.labelMedium, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                color = if (isSelected) BaseballColors.action else if (choice.owned || choice.available) BaseballColors.textPrimary else BaseballColors.textTertiary)
                        }
                    }
                }
            }
            Text(copy.resolve("awakening.tree.legend"), verbatim = true, style = MaterialTheme.typography.labelSmall,
                color = BaseballColors.textSecondary, modifier = Modifier.align(Alignment.CenterHorizontally))
        }
        Surface(color = BaseballColors.surfaceRaised, shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth().testTag("awakening.detail")) {
            Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Text(selected.choice.title, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleSmall)
                Text(summary.benefit, verbatim = true, style = MaterialTheme.typography.bodyMedium, color = BaseballColors.action, modifier = Modifier.testTag("awakening.benefit"))
                summary.cost?.let { Text(it, verbatim = true, style = MaterialTheme.typography.bodySmall, color = BaseballColors.warning, modifier = Modifier.testTag("awakening.cost")) }
                if (selected.choice.available && selected.choice.leap) Text(copy.resolve("awakening.tree.leap"), verbatim = true, style = MaterialTheme.typography.bodySmall, color = BaseballColors.milestone)
                else if (!selected.choice.owned && !selected.choice.available && selected.choice.requirement.isNotBlank()) {
                    Text(copy.resolve("awakening.tree.requires", GameCopyArgument.UserText(copy.legacy(selected.choice.requirement))), verbatim = true,
                        style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
                }
                TextButton(onClick = { details = true }, modifier = Modifier.heightIn(min = 40.dp).testTag("awakening.details"), contentPadding = PaddingValues(0.dp)) {
                    Text(copy.resolve("awakening.tree.details"), verbatim = true, style = MaterialTheme.typography.labelSmall)
                }
            }
        }
        Button(onClick = {
            if (canConfirm) onAction(Phase8UiAction(model.id, action.id, action.payloads))
        }, enabled = canConfirm, modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp).testTag("awakening.confirm")) {
            Text(copy.resolve(when { selected.choice.owned -> "awakening.tree.learned"; owned.size >= 3 -> "awakening.tree.complete";
                canConfirm -> "awakening.tree.choose"; else -> "awakening.tree.unavailable" }), verbatim = true)
        }
        Spacer(Modifier.height(4.dp))
    }
    if (details) AlertDialog(onDismissRequest = { details = false }, title = { Text(selected.choice.title) },
        text = { Column(Modifier.heightIn(max = 360.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(if (selected.choice.owned) copy.resolve("awakening.tree.learned") else selected.choice.effect)
            if (selected.choice.voice.isNotBlank()) Text(selected.choice.voice, style = MaterialTheme.typography.bodyMedium)
        } }, confirmButton = { TextButton(onClick = { details = false }) { Text(copy.resolve("action.close"), verbatim = true) } })
}
