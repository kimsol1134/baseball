package com.solkim.baseball.android

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballColors
import org.json.JSONArray
import org.json.JSONObject
import com.solkim.baseball.android.LocalizedGameText as Text

/** Only committed deltas are displayed. Closing this receipt never dispatches a career command. */
internal fun conversationFeedbackRecord(before: GameAggregateState, after: GameAggregateState): JSONObject? {
    val oldPro = before.pro
    val nextPro = after.pro
    if (oldPro != null && nextPro != null && oldPro.careerId == nextPro.careerId && nextPro.decisionHistory.size > oldPro.decisionHistory.size) {
        val lines = ProConversationPresentation.effects(oldPro, nextPro).map { it.source }
        val role = ProConversationPresentation.role(oldPro.pendingDecision?.type)
        return JSONObject().put("kind", "pro").put("career", nextPro.careerId).put("number", nextPro.decisionHistory.size)
            .put("speaker", role?.let { ProPeoplePresentation.name(oldPro.team.id, it) } ?: nextPro.decisionHistory.last().choiceTitle)
            .put("portraitSeed", role?.let { ProPeoplePresentation.seed(oldPro.team.id, it) }.orEmpty())
            .put("role", role.orEmpty()).put("scene", oldPro.pendingDecision?.title.orEmpty())
            .put("choice", nextPro.decisionHistory.last().choiceTitle)
            .put("reaction", when {
                role == "coach" && nextPro.managerTrust < oldPro.managerTrust -> "conversation.reaction.coach.disagree"
                role == "catcher" && nextPro.catcherTrust < oldPro.catcherTrust -> "conversation.reaction.catcher.disagree"
                role != null -> "conversation.reaction.$role"
                else -> "conversation.reaction.done"
            })
            .put("lines", JSONArray(lines.ifEmpty { listOf("선택한 계획으로 다음 일정을 준비해요.") }))
    }
    val old = before.highSchool?.run ?: return null
    val next = after.highSchool?.run ?: return null
    if (old.careerId != next.careerId || next.relationshipsCompleted <= old.relationshipsCompleted) return null
    return JSONObject().put("kind", "school").put("career", next.careerId).put("number", next.relationshipsCompleted)
        .put("speaker", RelationshipNarrative.speaker(old)).put("lines", JSONArray(ConversationPresentation.effects(old, next)))
        .put("role", RelationshipNarrative.speakerRole(old).orEmpty())
        .put("scene", old.currentRelationshipEvent?.title.orEmpty())
        .put("reaction", ConversationPresentation.reactionKey(old, next))
        .put("choice", next.lastRelationship?.response?.let { ConversationPresentation.title(old, it) }.orEmpty())
}

internal fun saveConversationFeedback(context: Context, before: GameAggregateState, after: GameAggregateState) {
    val record = conversationFeedbackRecord(before, after) ?: return
    context.getSharedPreferences("conversation.feedback", Context.MODE_PRIVATE).edit().putString("pending", record.toString()).apply()
}

@Composable
internal fun ConversationFeedbackGate(state: GameAggregateState, onNavigate: (Phase8ScreenId) -> Unit = {}): Boolean {
    val context = LocalContext.current
    val copy = rememberGameCopy()
    val prefs = remember(context) { context.getSharedPreferences("conversation.feedback", Context.MODE_PRIVATE) }
    var raw by remember(prefs) { mutableStateOf(prefs.getString("pending", null)) }
    DisposableEffect(prefs) {
        val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, key -> if (key == "pending") raw = prefs.getString("pending", null) }
        prefs.registerOnSharedPreferenceChangeListener(listener)
        onDispose { prefs.unregisterOnSharedPreferenceChangeListener(listener) }
    }
    val record = remember(raw) { raw?.let { runCatching { JSONObject(it) }.getOrNull() } } ?: return false
    val pro = record.optString("kind") == "pro"
    val career = if (pro) state.pro?.careerId else state.highSchool?.run?.careerId
    val count = if (pro) state.pro?.decisionHistory?.size ?: 0 else state.highSchool?.run?.relationshipsCompleted ?: 0
    if (record.optString("career") != career || record.optInt("number") != count) return false
    val lines = record.optJSONArray("lines") ?: return false
    val effects = List(lines.length()) { ChoiceEffect.fromSource(lines.optString(it)) }
    val reaction = record.optString("reaction").takeIf(copy::hasKey) ?: "conversation.reaction.done"
    val seed = record.optString("speaker")
    ConversationNavigation(state, onNavigate) {
    ConversationStage(if (copy.hasKey(seed)) copy.resolve(seed) else copy.legacy(seed), record.optString("role").takeIf(String::isNotBlank), record.optString("portraitSeed").ifBlank { seed },
        copy.legacy(record.optString("scene")), copy.resolve(reaction), result = true) {
        Column(Modifier.fillMaxWidth().testTag("conversation.result"), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            record.optString("choice").takeIf(String::isNotBlank)?.let {
                Text(copy.legacy(it), verbatim = true, style = MaterialTheme.typography.bodyMedium, color = BaseballColors.textSecondary)
            }
            ConversationEffects(ChoiceEffect.highlighted(effects))
            Button(onClick = {
                if (prefs.getString("pending", null) == raw) prefs.edit().remove("pending").apply()
            }, modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp).testTag("conversation.continue")) {
                Text(copy.resolve("conversation.next"), verbatim = true)
            }
            if (effects.size > ChoiceEffect.highlighted(effects).size || effects.any { it.explanation(copy) != null }) CareerDisclosure(copy.resolve("conversation.effects"), "conversation.result.details") {
                ConversationEffects(effects)
                effects.mapNotNull { it.explanation(copy) }.distinct().forEach { Text(it, verbatim = true, style = MaterialTheme.typography.bodySmall) }
            }
        }
    }
    }
    return true
}
