package com.solkim.baseball.android

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.android.LocalizedGameText as Text

/** One shared stage for the decision and its durable receipt; no modal over the next task. */
@Composable
internal fun ConversationStage(
    speaker: String, role: String?, portraitSeed: String, scene: String,
    line: String, result: Boolean = false, content: @Composable ColumnScope.() -> Unit,
) {
    val copy = rememberGameCopy()
    val largeText = LocalConfiguration.current.fontScale > 1.3f
    Surface(Modifier.fillMaxSize(), color = BaseballColors.canvas) {
        Column(Modifier.fillMaxSize().safeDrawingPadding().verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(copy.resolve(if (result) "conversation.result" else "conversation.title"), verbatim = true,
                color = BaseballColors.textSecondary, style = MaterialTheme.typography.labelLarge)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                val avatarRole = when (role) { "coach" -> AvatarRole.COACH; "catcher" -> AvatarRole.CATCHER; "rival" -> AvatarRole.RIVAL; else -> null }
                if (avatarRole != null) PlayerPortrait(seed = portraitSeed, role = avatarRole, width = if (largeText) 64.dp else 84.dp,
                    modifier = Modifier.testTag("relationship.portrait"))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    if (role != null && copy.hasKey("conversation.role.$role")) Text(copy.resolve("conversation.role.$role"),
                        verbatim = true, color = BaseballColors.milestone, style = MaterialTheme.typography.labelMedium)
                    Text(speaker, verbatim = true, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold,
                        modifier = Modifier.semantics { heading() })
                    if (scene.isNotBlank()) Text(scene, verbatim = true, style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
                }
            }
            Text(line, verbatim = true, style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.testTag("conversation.line").semantics { if (result) liveRegion = LiveRegionMode.Polite })
            content()
        }
    }
}

/** Costs remain visible even when they outnumber the highlighted benefits. */
@Composable
@OptIn(ExperimentalLayoutApi::class)
internal fun ConversationEffects(effects: List<ChoiceEffect>, modifier: Modifier = Modifier) {
    val copy = rememberGameCopy()
    FlowRow(modifier, horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        effects.forEach { effect ->
            Surface(color = (if (effect.favorable) BaseballColors.action else BaseballColors.warning).copy(alpha = 0.09f), shape = MaterialTheme.shapes.small) {
                Text(effect.localized(copy), verbatim = true, color = if (effect.favorable) BaseballColors.action else BaseballColors.warning,
                    style = MaterialTheme.typography.labelMedium, modifier = Modifier.padding(horizontal = 7.dp, vertical = 4.dp))
            }
        }
    }
}

@Composable
internal fun RelationshipConversationScreen(state: GameAggregateState, model: Phase8ScreenModel, busy: Boolean,
    actionError: String?, onAction: (Phase8UiAction) -> Unit) {
    val run = state.highSchool?.run ?: return
    val copy = rememberGameCopy()
    val eventKey = "${run.careerId}:${run.relationshipsCompleted}:${run.currentRelationshipEvent?.id}"
    var submitted by remember(eventKey, state.revision) { mutableStateOf(false) }
    LaunchedEffect(actionError, busy) { if (actionError != null && !busy) submitted = false }
    val row = model.sections.firstOrNull()?.rows?.firstOrNull()
    val seed = RelationshipNarrative.speaker(run)
    val player = if (state.meta.seedChallenge != null) copy.resolve("android.challenge.player") else run.identity.name
    ConversationStage(copy.legacy(seed), RelationshipNarrative.speakerRole(run), seed,
        model.sections.firstOrNull()?.title.orEmpty(), row?.value.orEmpty()) {
        if (actionError != null) Text(actionError, verbatim = true, color = BaseballColors.warning,
            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive })
        model.actions.forEach { action ->
            ConversationChoice(action, !busy && !submitted, eventKey) {
                if (!submitted && !busy) {
                    submitted = true
                    onAction(Phase8UiAction(model.id, action.id, action.payloads))
                }
            }
        }
        if (busy || submitted) Text(copy.resolve("conversation.saving"), verbatim = true, color = BaseballColors.textSecondary,
            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite })
        CareerDisclosure(copy.resolve("conversation.scene"), "conversation.scene.$eventKey") {
            Text(copy.legacy(RelationshipNarrative.line(run)).replace("{player}", player), verbatim = true, style = MaterialTheme.typography.bodyMedium)
        }
        CareerMemoryPresentation.conversationRecall(state, copy)?.let { recall ->
            CareerDisclosure(copy.resolve("conversation.history"), "conversation.history.$eventKey") { Text(recall, verbatim = true) }
        }
    }
}

@Composable
internal fun ProConversationScreen(state: GameAggregateState, model: Phase8ScreenModel, busy: Boolean,
    actionError: String?, onAction: (Phase8UiAction) -> Unit) {
    val pro = state.pro ?: return
    val decision = pro.pendingDecision ?: return
    val role = ProConversationPresentation.role(decision.type) ?: return
    val copy = rememberGameCopy()
    var submitted by remember(state.revision, decision.id) { mutableStateOf(false) }
    LaunchedEffect(actionError, busy) { if (actionError != null && !busy) submitted = false }
    ConversationStage(copy.resolve("conversation.role.$role"), role, "${pro.careerId}:$role",
        copy.legacy(decision.title), copy.resolve("conversation.pro.${decision.type.wire}")) {
        if (actionError != null) Text(actionError, verbatim = true, color = BaseballColors.warning)
        model.actions.filter { it.id.startsWith("seasonDecision:") }.forEach { action ->
            ConversationChoice(action, !busy && !submitted, decision.id) {
                if (!submitted && !busy) { submitted = true; onAction(Phase8UiAction(model.id, action.id, action.payloads)) }
            }
        }
        if (busy || submitted) Text(copy.resolve("conversation.saving"), verbatim = true, color = BaseballColors.textSecondary)
        CareerDisclosure(copy.resolve("conversation.scene"), "conversation.scene.${decision.id}") {
            Text(copy.legacy(decision.detail), verbatim = true)
            decision.choices.forEach { choice ->
                Text(copy.legacy(choice.title), verbatim = true, fontWeight = FontWeight.SemiBold)
                Text(copy.legacy(choice.detail), verbatim = true)
            }
        }
        CareerMemoryPresentation.conversationRecall(state, copy)?.let { recall ->
            CareerDisclosure(copy.resolve("conversation.history"), "conversation.history.${decision.id}") { Text(recall, verbatim = true) }
        }
    }
}

@Composable
internal fun ConversationChoice(action: Phase8ActionModel, enabled: Boolean, eventKey: String, onSelect: () -> Unit) {
    val copy = rememberGameCopy()
    var details by rememberSaveable(eventKey, action.id) { mutableStateOf(false) }
    val highlighted = ChoiceEffect.highlighted(action.effects)
    val explanations = action.effects.mapNotNull { it.explanation(copy) }.distinct()
    val expandable = action.effects.size > highlighted.size || explanations.isNotEmpty()
    Card(onClick = onSelect, enabled = enabled && action.enabled, modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).testTag("action.${action.id}"),
        colors = CardDefaults.cardColors(containerColor = BaseballColors.surfaceRaised, disabledContainerColor = BaseballColors.surfaceRaised),
        border = BorderStroke(1.dp, BaseballColors.border)) {
        Column(Modifier.padding(horizontal = 14.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(action.label, verbatim = true, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.titleSmall,
                    color = BaseballColors.textPrimary, modifier = Modifier.weight(1f))
                if (expandable) TextButton(onClick = { details = !details },
                    contentPadding = PaddingValues(horizontal = 6.dp, vertical = 0.dp),
                    modifier = Modifier.heightIn(min = 48.dp).testTag("effect.details.${action.id}")) {
                    Text(copy.resolve(if (details) "android.details.hide" else "conversation.effects"), verbatim = true,
                        style = MaterialTheme.typography.labelMedium)
                }
            }
            ConversationEffects(highlighted)
            if (action.effects.isEmpty() && action.description.isNotBlank()) Text(action.description, verbatim = true, style = MaterialTheme.typography.bodySmall)
        }
    }
    if (expandable) {
        // The child button consumes its click; expansion never dispatches a career command.
        if (details) {
            ConversationEffects(action.effects.filterNot { it in highlighted })
            explanations.forEach { Text(it, verbatim = true, style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary) }
        }
    }
}
