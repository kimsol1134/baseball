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
internal fun ProWeekPlanner(state: GameAggregateState, model: Phase8ScreenModel, busy: Boolean = false, onAction: (Phase8UiAction) -> Unit) {
    val order = listOf("develop_stuff", "refine_command", "develop_movement", "build_stamina", "recover", "earn_trust")
    val plans = model.actions.filter { it.id.startsWith("proPlan:") }.sortedBy { order.indexOf(it.id.substringAfter(':')) }
    var selected by rememberSaveable(state.pro?.careerId) { mutableStateOf(plans.firstOrNull()?.id) }
    val action = plans.firstOrNull { it.id == selected } ?: plans.firstOrNull() ?: return
    val preview = ProWeekPresentation.preview(state, action.id) ?: return
    AceCareerPresentation.leagueLine(state)?.let { Text(it, style = MaterialTheme.typography.labelMedium, modifier = Modifier.testTag("week.league")) }
    AceCareerPresentation.goal(state)?.let { (title, progress) ->
        Text(title, color = BaseballColors.milestone, style = MaterialTheme.typography.titleMedium, modifier = Modifier.testTag("week.aceGoal"))
        Text(progress, style = MaterialTheme.typography.bodySmall)
    }
    val desiredRole = AceCareerPresentation.preferredRole(state)
    model.actions.firstOrNull { it.id == "requestRole:$desiredRole" && it.enabled }?.let { role ->
        OutlinedButton(onClick = { onAction(Phase8UiAction(model.id, role.id, role.payloads)) }, enabled = !busy, modifier = Modifier.testTag("week.pathRole")) { Text(role.label) }
    }
    Text(preview.title, style = MaterialTheme.typography.titleLarge)
    plans.chunked(3).forEach { row ->
        AdaptiveActionRow(Modifier.fillMaxWidth(), equalWidth = true) {
            row.forEach { choice ->
                FilterChip(selected = action.id == choice.id, enabled = choice.enabled && !busy, onClick = { selected = choice.id },
                    colors = FilterChipDefaults.filterChipColors(selectedContainerColor = BaseballColors.action, selectedLabelColor = BaseballColors.actionInk),
                    label = { Text(ProWeekPresentation.title(choice.id)) }, modifier = Modifier.heightIn(min = 48.dp).testTag("week.select.${choice.id}"))
            }
        }
    }
    Column(Modifier.fillMaxWidth().testTag("week.preview"), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(preview.growth); Text(preview.schedule); Text(preview.condition, color = BaseballColors.textSecondary)
    }
    Button(enabled = action.enabled && !busy, onClick = { onAction(Phase8UiAction(model.id, action.id, action.payloads)) },
        modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("week.commit")) { Text("이번 주 진행") }
    if (busy) LinearProgressIndicator(Modifier.fillMaxWidth().testTag("week.busy"))
    ProWeekPresentation.batchAction(state, model, action.id)?.let { batch ->
        CareerDisclosure("여러 주 진행", "week.batch") {
            val copy = rememberGameCopy()
            Text(copy.resolve("week.batch.plan", GameCopyArgument.UserText(copy.legacy(ProWeekPresentation.title(action.id)))),
                verbatim = true, modifier = Modifier.testTag("week.batch.plan"))
            Text("대화나 중요한 경기가 나오면 멈춰요.")
            OutlinedButton(enabled = !busy, onClick = { onAction(Phase8UiAction(model.id, batch.id, batch.payloads)) }, modifier = Modifier.testTag("week.batch.commit")) { Text(batch.label) }
        }
    }
}

internal fun saveProWeekFeedback(context: Context, before: GameAggregateState, after: GameAggregateState) {
    val r = ProWeekPresentation.result(before, after) ?: return
    val record = JSONObject().put("beforeRatings", JSONArray(before.pro!!.pitcher.let { listOf(it.stuff, it.command, it.movement, it.stamina) }))
        .put("afterRatings", JSONArray(after.pro!!.pitcher.let { listOf(it.stuff, it.command, it.movement, it.stamina) }))
        .put("career", r.careerId).put("season", r.season).put("week", r.week).put("weeks", r.weeks)
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
                val from = r.optJSONArray("beforeRatings")
                val to = r.optJSONArray("afterRatings")
                if (from?.length() == 4 && to?.length() == 4) AbilityChangeBars((0..3).map { from.getInt(it) }, (0..3).map { to.getInt(it) }, state.settings.reducedMotionEnabled, "week.growth.bar")
                val growth = r.getJSONArray("growth")
                if (growth.length() == 0) Text("몸 상태와 이번 주 경기를 확인해요.")
                repeat(growth.length()) { StatChangeText(growth.getString(it), color = BaseballColors.action) }
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
