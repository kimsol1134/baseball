package com.solkim.baseball.android

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballColors
import org.json.JSONArray
import org.json.JSONObject
import com.solkim.baseball.android.LocalizedGameText as Text

@Composable
internal fun ProWeekPlanner(state: GameAggregateState, model: Phase8ScreenModel, onAction: (Phase8UiAction) -> Unit) {
    val plans = model.actions.filter { it.id.startsWith("proPlan:") }
    var selected by rememberSaveable(state.pro?.careerId) { mutableStateOf(plans.firstOrNull()?.id) }
    val action = plans.firstOrNull { it.id == selected } ?: plans.firstOrNull() ?: return
    val preview = ProWeekPresentation.preview(state, action.id) ?: return
    Text(preview.title, style = MaterialTheme.typography.titleLarge)
    plans.chunked(3).forEach { row ->
        AdaptiveActionRow(Modifier.fillMaxWidth(), equalWidth = true) {
            row.forEach { choice ->
                FilterChip(selected = action.id == choice.id, enabled = choice.enabled, onClick = { selected = choice.id },
                    colors = FilterChipDefaults.filterChipColors(selectedContainerColor = BaseballColors.action, selectedLabelColor = BaseballColors.actionInk),
                    label = { Text(ProWeekPresentation.title(choice.id)) }, modifier = Modifier.heightIn(min = 48.dp).testTag("week.select.${choice.id}"))
            }
        }
    }
    Column(Modifier.fillMaxWidth().testTag("week.preview"), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(preview.growth); Text(preview.schedule); Text(preview.condition, color = BaseballColors.textSecondary)
    }
    Button(enabled = action.enabled, onClick = { onAction(Phase8UiAction(model.id, action.id, action.payloads)) },
        modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("week.commit")) { Text("이번 주 진행") }
    model.actions.firstOrNull { it.id == "proAdvanceSegment" && it.enabled }?.let { batch ->
        CareerDisclosure("여러 주 진행", "week.batch") {
            Text("대화나 중요한 경기가 나오면 멈춰요.")
            OutlinedButton(onClick = { onAction(Phase8UiAction(model.id, batch.id, batch.payloads)) }) { Text("감독에게 맡기기") }
        }
    }
}

internal fun saveProWeekFeedback(context: Context, before: GameAggregateState, after: GameAggregateState) {
    val r = ProWeekPresentation.result(before, after) ?: return
    val record = JSONObject().put("career", r.careerId).put("season", r.season).put("week", r.week).put("weeks", r.weeks)
        .put("growth", JSONArray(r.growth)).put("games", r.games).put("outs", r.outs).put("strikeouts", r.strikeouts).put("runs", r.runs)
        .put("fatigueBefore", r.fatigueBefore).put("fatigueAfter", r.fatigueAfter).put("injury", r.injuries).put("role", r.role).put("level", r.level)
    context.getSharedPreferences("pro.week.feedback", 0).edit().putString("pending", record.toString()).apply()
}

@Composable
internal fun ProWeekFeedbackGate(state: GameAggregateState) {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("pro.week.feedback", 0) }
    var raw by remember { mutableStateOf(prefs.getString("pending", null)) }
    DisposableEffect(prefs) {
        val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, _ -> raw = prefs.getString("pending", null) }
        prefs.registerOnSharedPreferenceChangeListener(listener)
        onDispose { prefs.unregisterOnSharedPreferenceChangeListener(listener) }
    }
    val r = remember(raw) { raw?.let { runCatching { JSONObject(it) }.getOrNull() } } ?: return
    val pro = state.pro ?: return
    if (r.optString("career") != pro.careerId || r.optInt("season") != pro.season || r.optInt("week") > pro.week) return
    AlertDialog(onDismissRequest = {}, containerColor = BaseballColors.surfaceRaised, modifier = Modifier.testTag("week.result"),
        title = { Text("이번 주의 변화") }, text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("성장", style = MaterialTheme.typography.titleSmall)
                val growth = r.getJSONArray("growth")
                if (growth.length() == 0) Text("몸 상태와 이번 주 경기를 확인해요.")
                repeat(growth.length()) { Text(growth.getString(it), color = BaseballColors.action) }
                Text("이번 주 경기", style = MaterialTheme.typography.titleSmall)
                Text("${r.getInt("games")}경기 · ${r.getInt("outs") / 3}.${r.getInt("outs") % 3}이닝 · ${r.getInt("strikeouts")}탈삼진 · ${r.getInt("runs")}실점")
                Text("몸 상태", style = MaterialTheme.typography.titleSmall)
                Text("피로 ${r.getInt("fatigueBefore")} → ${r.getInt("fatigueAfter")}", color = if (r.getInt("fatigueAfter") > r.getInt("fatigueBefore")) BaseballColors.warning else BaseballColors.action)
                if (r.optInt("injury") > 0) Text("회복까지 ${r.getInt("injury")}주", color = BaseballColors.warning)
                Text(r.getString("role") + " · " + r.getString("level"), style = MaterialTheme.typography.labelMedium)
            }
        }, confirmButton = { TextButton(onClick = {
            if (prefs.getString("pending", null) == raw) prefs.edit().remove("pending").apply()
        }, modifier = Modifier.testTag("week.result.continue")) { Text("다음 일정으로") } })
}
