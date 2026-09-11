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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.android.LocalizedGameText as Text
import org.json.JSONArray
import org.json.JSONObject

/** Display-only receipt. Acknowledgement never runs or repeats a game command. */
internal fun trainingFeedbackRecord(before: GameAggregateState, after: GameAggregateState): JSONObject? = trainingReceipt(before, after)?.let(::JSONObject)

internal fun saveTrainingFeedback(context: Context, before: GameAggregateState, after: GameAggregateState) {
    val record = trainingFeedbackRecord(before, after) ?: return
    context.getSharedPreferences("training.feedback", Context.MODE_PRIVATE).edit().putString("pending", record.toString()).apply()
}

@Composable
internal fun TrainingFeedbackGate(state: GameAggregateState) {
    TrainingFeedbackGate(CareerUiRules.highSchoolCareerId(state), CareerUiRules.totalTrainingsCompleted(state), state.settings.reducedMotionEnabled)
}

@Composable
internal fun TrainingFeedbackGate(careerId: String?, trainingsCompleted: Int, reducedMotion: Boolean) {
    val context = LocalContext.current
    val prefs = remember(context) { context.getSharedPreferences("training.feedback", Context.MODE_PRIVATE) }
    var raw by remember(prefs) { mutableStateOf(prefs.getString("pending", null)) }
    DisposableEffect(prefs) {
        val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, key -> if (key == "pending") raw = prefs.getString("pending", null) }
        prefs.registerOnSharedPreferenceChangeListener(listener)
        onDispose { prefs.unregisterOnSharedPreferenceChangeListener(listener) }
    }
    val record = remember(raw) { raw?.let { runCatching { JSONObject(it) }.getOrNull() } } ?: return
    if (careerId == null) return
    // A restored or reset career cannot inherit a receipt from a different life or future revision.
    if (record.optString("career") != careerId || record.optInt("number") > trainingsCompleted) return
    Dialog(onDismissRequest = {}, properties = DialogProperties(dismissOnBackPress = false, dismissOnClickOutside = false, usePlatformDefaultWidth = false)) {
        Surface(Modifier.fillMaxWidth().padding(16.dp).heightIn(max = 680.dp), shape = MaterialTheme.shapes.extraLarge, color = BaseballColors.surface) {
            TrainingFeedbackPanel(record, reducedMotion = reducedMotion, onContinue = {
                // Do not clear a newer result if the displayed receipt was replaced.
                if (prefs.getString("pending", null) == raw) prefs.edit().remove("pending").apply()
            })
        }
    }
}

@Composable
internal fun TrainingFeedbackPanel(record: JSONObject, reducedMotion: Boolean = false, onContinue: () -> Unit) {
    val before = record.getJSONArray("before")
    val after = record.getJSONArray("after")
    val labels = listOf("구위", "제구", "무브먼트", "체력")
    val copy = rememberGameCopy()
    Column(Modifier.fillMaxWidth().padding(20.dp).testTag("training.feedback"), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text("훈련 완료", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        if (record.getInt("count") == 1) {
            val focus = TrainingFocus.entries.firstOrNull { it.wire == record.optString("focus") }
            val intensity = TrainingIntensity.entries.firstOrNull { it.wire == record.optString("intensity") }
            if (focus != null && intensity != null) Text(copy.legacy(TrainingPlans.label(focus)) + " · " + copy.legacy(TrainingPresentation.intensityTitle(intensity, focus)), verbatim = true, style = MaterialTheme.typography.titleMedium)
        }
        if (record.getInt("count") > 1) Text(copy.resolve("feedback.training.count", GameCopyArgument.Whole(record.getInt("count").toLong())), verbatim = true,
            style = MaterialTheme.typography.labelMedium, color = BaseballColors.textSecondary)
        Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (record.optBoolean("extraGrowth")) Text("추가 성장!", color = BaseballColors.milestone, style = MaterialTheme.typography.titleMedium)
            val changed = (0..3).filter { before.getInt(it) != after.getInt(it) }
            changed.forEach { index ->
                val from = AbilityDisplayScale.rating(before.getInt(index))
                val to = AbilityDisplayScale.rating(after.getInt(index))
                AbilityBar(index, after.getInt(index), before.getInt(index), animate = true, reducedMotion = reducedMotion, tag = "training.growth.bar.$index")
                StatChangeText("$from → $to  (${if (to >= from) "+" else ""}${to - from})", modifier = Modifier.testTag("training.feedback.stat.$index"),
                    style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold, verbatim = true)
            }
            if (changed.isEmpty()) Text(if (record.getInt("fatigueAfter") < record.getInt("fatigueBefore")) "몸이 회복됐어요." else "능력치는 유지됐어요.", style = MaterialTheme.typography.titleLarge)
            if (after.getInt(1) > before.getInt(1)) ControlWindowPreview(after.getInt(1), before.getInt(1), titleKey = "loop.growth.base-window")
            val velocities = record.optJSONArray("velocities")
            if (velocities != null && velocities.length() > 0) {
                CareerDisclosure(copy.legacy("현재 예상 구속") + " · " + String.format(java.util.Locale.US, "%.1f km/h", velocities.getJSONObject(0).getInt("after") / 10.0), "training.feedback.velocity") {
                    Text("현재 피로와 균형 힘 배분을 반영했어요.", style = MaterialTheme.typography.bodySmall)
                    for (index in 0 until velocities.length()) {
                        val value = velocities.getJSONObject(index)
                        Text(value.getString("pitch"), style = MaterialTheme.typography.labelMedium)
                        Text(String.format(java.util.Locale.US, "%.1f → %.1f km/h", value.getInt("before") / 10.0, value.getInt("after") / 10.0), verbatim = true)
                    }
                }
            }
            val targets = record.optJSONArray("targets")
            if (targets != null && targets.length() > 0) {
                Text("훈련한 구종", style = MaterialTheme.typography.labelMedium)
                Text((0 until targets.length()).joinToString(" · ") { targets.getString(it) }, style = MaterialTheme.typography.bodyMedium)
            }
            if (record.optInt("learningAfter") > record.optInt("learningBefore")) {
                Text("구종 익히기", style = MaterialTheme.typography.labelMedium)
                Text("${record.getInt("learningBefore")} → ${record.getInt("learningAfter")} / 9", verbatim = true, color = BaseballColors.action)
            }
            if (record.optLong("mastery") > 0) Text(copy.resolve("feedback.training.mastery", GameCopyArgument.Whole(record.getLong("mastery"))), verbatim = true, color = BaseballColors.milestone)
            if (record.optBoolean("bloomed")) Text("재능의 한계를 넘었어요!", color = BaseballColors.milestone)
            listOf("피로" to "fatigue", "팔 부담" to "arm").forEach { (label, key) ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(label, color = BaseballColors.textSecondary)
                    Text("${record.getInt(key + "Before")} → ${record.getInt(key + "After")}", verbatim = true,
                        color = if (record.getInt(key + "After") > record.getInt(key + "Before")) BaseballColors.warning else BaseballColors.action)
                }
            }
            Text(when {
                record.optBoolean("bloomed") -> "잠재력을 돌파했어요. 더 높은 능력으로 성장할 수 있어요."
                record.getLong("mastery") > 0 && changed.isEmpty() -> "숙련이 쌓였어요. 능력치가 같아도 훈련의 효과는 남아요."
                record.optBoolean("atWall") && record.optInt("breakthroughTarget") > 0 && changed.isEmpty() -> "돌파 준비 ${record.optInt("breakthrough")}/${record.optInt("breakthroughTarget")} · 훈련 성과가 남았어요."
                changed.isEmpty() && record.optInt("experienceEarned") > 0 -> "성장 준비 ${record.optInt("experience")}/100 · 다음 훈련으로 이어집니다."
                record.optBoolean("rehab") || record.getInt("armAfter") >= 55 || record.getInt("fatigueAfter") >= 70 -> "다음에는 회복을 추천해요. 피로와 팔 부담을 낮출 수 있어요."
                else -> "현재 몸 상태를 보고 다음 훈련을 골라보세요."
            }, style = MaterialTheme.typography.bodyMedium)
        }
        if (record.optBoolean("supportApplied")) Text("대화에서 받은 훈련 지원을 사용했어요.", color = BaseballColors.milestone)
        Button(onClick = onContinue, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("training.feedback.continue")) { Text("계속하기") }
    }
}
