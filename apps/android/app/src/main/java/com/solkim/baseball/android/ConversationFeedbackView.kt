package com.solkim.baseball.android

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.core.pro.label
import com.solkim.baseball.design.BaseballColors
import org.json.JSONArray
import org.json.JSONObject
import com.solkim.baseball.android.LocalizedGameText as Text

/** Only committed deltas are displayed. Closing this receipt never dispatches a career command. */
internal fun conversationFeedbackRecord(before: GameAggregateState, after: GameAggregateState): JSONObject? {
    val oldPro = before.pro
    val nextPro = after.pro
    if (oldPro != null && nextPro != null && oldPro.careerId == nextPro.careerId && nextPro.decisionHistory.size > oldPro.decisionHistory.size) {
        val lines = mutableListOf<String>()
        fun change(label: String, from: Int, to: Int) { if (from != to) lines += "$label ${if (to > from) "+" else ""}${to - from}" }
        change("감독 신뢰", oldPro.managerTrust, nextPro.managerTrust); change("포수 신뢰", oldPro.catcherTrust, nextPro.catcherTrust)
        change("피로", oldPro.fatigue, nextPro.fatigue)
        val old = oldPro.pitcher.let { listOf(it.stuff, it.command, it.movement, it.stamina) }
        val next = nextPro.pitcher.let { listOf(it.stuff, it.command, it.movement, it.stamina) }
        listOf("구위", "제구", "무브먼트", "체력").forEachIndexed { index, label -> change(label, AbilityDisplayScale.rating(old[index]), AbilityDisplayScale.rating(next[index])) }
        if (nextPro.role != oldPro.role) lines.add(0, "보직: ${nextPro.role.label}")
        if (nextPro.activeDecisionModifiers != oldPro.activeDecisionModifiers) lines += "다음 등판 준비에 반영됐어요."
        return JSONObject().put("kind", "pro").put("career", nextPro.careerId).put("number", nextPro.decisionHistory.size)
            .put("speaker", nextPro.decisionHistory.last().choiceTitle).put("lines", JSONArray(lines.ifEmpty { listOf("선택한 계획으로 다음 일정을 준비해요.") }))
    }
    val old = before.highSchool?.run ?: return null
    val next = after.highSchool?.run ?: return null
    if (old.careerId != next.careerId || next.relationshipsCompleted <= old.relationshipsCompleted) return null
    return JSONObject().put("kind", "school").put("career", next.careerId).put("number", next.relationshipsCompleted)
        .put("speaker", RelationshipNarrative.speaker(old)).put("lines", JSONArray(ConversationPresentation.effects(old, next)))
}

internal fun saveConversationFeedback(context: Context, before: GameAggregateState, after: GameAggregateState) {
    val record = conversationFeedbackRecord(before, after) ?: return
    context.getSharedPreferences("conversation.feedback", Context.MODE_PRIVATE).edit().putString("pending", record.toString()).apply()
}

@Composable
internal fun ConversationFeedbackGate(state: GameAggregateState) {
    val context = LocalContext.current
    val prefs = remember(context) { context.getSharedPreferences("conversation.feedback", Context.MODE_PRIVATE) }
    var raw by remember(prefs) { mutableStateOf(prefs.getString("pending", null)) }
    DisposableEffect(prefs) {
        val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, key -> if (key == "pending") raw = prefs.getString("pending", null) }
        prefs.registerOnSharedPreferenceChangeListener(listener)
        onDispose { prefs.unregisterOnSharedPreferenceChangeListener(listener) }
    }
    val record = remember(raw) { raw?.let { runCatching { JSONObject(it) }.getOrNull() } } ?: return
    val pro = record.optString("kind") == "pro"
    val career = if (pro) state.pro?.careerId else state.highSchool?.run?.careerId
    val count = if (pro) state.pro?.decisionHistory?.size ?: 0 else state.highSchool?.run?.relationshipsCompleted ?: 0
    if (record.optString("career") != career || record.optInt("number") > count) return
    AlertDialog(onDismissRequest = {}, containerColor = BaseballColors.surfaceRaised, modifier = Modifier.testTag("conversation.result"),
        title = { Text("대화로 달라진 것") },
        text = { Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(record.optString("speaker"), style = MaterialTheme.typography.titleMedium)
            val lines = record.getJSONArray("lines")
            repeat(minOf(4, lines.length())) {
                val line = lines.getString(it)
                val cost = line.startsWith("피로 +") || line.startsWith("팔 부담 +") ||
                    Regex("^(구위|제구|무브먼트|체력|신뢰|감독 신뢰|포수 신뢰|관심도) -").containsMatchIn(line)
                Text(line, color = if (cost) BaseballColors.warning else BaseballColors.action)
            }
        } },
        confirmButton = { TextButton(onClick = {
            if (prefs.getString("pending", null) == raw) prefs.edit().remove("pending").apply()
        }, modifier = Modifier.testTag("conversation.continue")) { Text("계속하기") } })
}
