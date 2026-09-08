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
import com.solkim.baseball.core.highschool.toPitcherSnapshot
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.android.LocalizedGameText as Text
import org.json.JSONArray
import org.json.JSONObject

/** Display-only receipt. Acknowledgement never runs or repeats a game command. */
internal fun trainingFeedbackRecord(before: GameAggregateState, after: GameAggregateState): JSONObject? {
    val old = before.highSchool?.run ?: return null
    val next = after.highSchool?.run ?: return null
    if (old.careerId != next.careerId || next.totalTrainingsCompleted <= old.totalTrainingsCompleted) return null
    val last = next.lastTraining ?: return null
    fun ratings(state: GameAggregateState) = state.highSchool!!.run.pitcher.let { JSONArray(listOf(it.stuff, it.command, it.movement, it.stamina)) }
    val evidence = after.highSchool!!.trainingEvidence.filter { it.careerId == next.careerId && it.trainingNumber > old.totalTrainingsCompleted }
    val velocities = JSONArray()
    val oldPitcher = old.toPitcherSnapshot()
    val newPitcher = next.toPitcherSnapshot()
    newPitcher.pitchProfiles.orEmpty().forEach { profile ->
        if (oldPitcher.pitchProfiles.orEmpty().any { it.pitchType == profile.pitchType }) {
            val call = com.solkim.baseball.core.pitch.PitchCall(profile.pitchType, com.solkim.baseball.core.pitch.PitchZone(1, 1), com.solkim.baseball.core.pitch.ZoneIntent.STRIKE, com.solkim.baseball.core.pitch.PitchIntensity.NORMAL)
            val from = com.solkim.baseball.core.pitch.PitchAbilityRules.expectedVelocity(oldPitcher, call, old.fatigue)
            val to = com.solkim.baseball.core.pitch.PitchAbilityRules.expectedVelocity(newPitcher, call, next.fatigue)
            if (from != to) velocities.put(JSONObject().put("pitch", TrainingPresentation.pitchLabel(profile.pitchType)).put("before", from).put("after", to))
        }
    }
    val oldMastery = old.pitcher.effectiveMastery
    val newMastery = next.pitcher.effectiveMastery
    val mastery = listOf(newMastery.stuff, newMastery.command, newMastery.movement, newMastery.stamina).sumOf { it.toLong() } -
        listOf(oldMastery.stuff, oldMastery.command, oldMastery.movement, oldMastery.stamina).sumOf { it.toLong() }
    val forecast = if (next.totalTrainingsCompleted == old.totalTrainingsCompleted + 1 && old.phase == com.solkim.baseball.core.highschool.HighSchoolPhase.TRAINING)
        TrainingPresentation.preview(before, last.focus, last.intensity) else null
    return JSONObject().put("career", next.careerId).put("number", last.number)
        .put("count", next.totalTrainingsCompleted - old.totalTrainingsCompleted)
        .put("before", ratings(before)).put("after", ratings(after))
        .put("fatigueBefore", old.fatigue).put("fatigueAfter", next.fatigue)
        .put("armBefore", old.armRisk).put("armAfter", next.armRisk)
        .put("focus", last.focus.wire).put("intensity", last.intensity.wire).put("bloomed", last.bloomed)
        .put("extraGrowth", forecast != null && last.growth > forecast.maximumGrowth).put("atWall", forecast?.atTalentWall == true)
        .put("learningBefore", old.pitchLearningProject?.practiceCredits ?: 0).put("learningAfter", next.pitchLearningProject?.practiceCredits ?: 0)
        .put("mastery", mastery.coerceAtLeast(0)).put("velocities", velocities).put("rehab", next.injuryRecovery > 0)
        .put("targets", JSONArray(evidence.mapNotNull { it.targetPitch?.let(TrainingPresentation::pitchLabel) }.distinct()))
}

internal fun saveTrainingFeedback(context: Context, before: GameAggregateState, after: GameAggregateState) {
    val record = trainingFeedbackRecord(before, after) ?: return
    context.getSharedPreferences("training.feedback", Context.MODE_PRIVATE).edit().putString("pending", record.toString()).apply()
}

@Composable
internal fun TrainingFeedbackGate(state: GameAggregateState) {
    val context = LocalContext.current
    val prefs = remember(context) { context.getSharedPreferences("training.feedback", Context.MODE_PRIVATE) }
    var raw by remember(prefs) { mutableStateOf(prefs.getString("pending", null)) }
    DisposableEffect(prefs) {
        val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, key -> if (key == "pending") raw = prefs.getString("pending", null) }
        prefs.registerOnSharedPreferenceChangeListener(listener)
        onDispose { prefs.unregisterOnSharedPreferenceChangeListener(listener) }
    }
    val record = remember(raw) { raw?.let { runCatching { JSONObject(it) }.getOrNull() } } ?: return
    val run = state.highSchool?.run ?: return
    // A restored or reset career cannot inherit a receipt from a different life or future revision.
    if (record.optString("career") != run.careerId || record.optInt("number") > run.totalTrainingsCompleted) return
    Dialog(onDismissRequest = {}, properties = DialogProperties(dismissOnBackPress = false, dismissOnClickOutside = false, usePlatformDefaultWidth = false)) {
        Surface(Modifier.fillMaxWidth().padding(16.dp).heightIn(max = 680.dp), shape = MaterialTheme.shapes.extraLarge, color = BaseballColors.surface) {
            TrainingFeedbackPanel(record, onContinue = {
                // Do not clear a newer result if the displayed receipt was replaced.
                if (prefs.getString("pending", null) == raw) prefs.edit().remove("pending").apply()
            })
        }
    }
}

@Composable
internal fun TrainingFeedbackPanel(record: JSONObject, onContinue: () -> Unit) {
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
                Text(labels[index], style = MaterialTheme.typography.labelLarge, color = BaseballColors.textSecondary)
                StatChangeText("$from → $to  (${if (to >= from) "+" else ""}${to - from})", modifier = Modifier.testTag("training.feedback.stat.$index"),
                    style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, verbatim = true)
            }
            if (changed.isEmpty()) Text(if (record.getInt("fatigueAfter") < record.getInt("fatigueBefore")) "몸이 회복됐어요." else "능력치는 유지됐어요.", style = MaterialTheme.typography.titleLarge)
            if (after.getInt(1) > before.getInt(1)) ControlWindowPreview(after.getInt(1), before.getInt(1), titleKey = "loop.growth.base-window")
            val velocities = record.optJSONArray("velocities")
            if (velocities != null && velocities.length() > 0) {
                CareerDisclosure("현재 예상 구속", "training.feedback.velocity") {
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
                record.optBoolean("rehab") || record.getInt("armAfter") >= 55 || record.getInt("fatigueAfter") >= 70 -> "다음에는 회복을 추천해요. 피로와 팔 부담을 낮출 수 있어요."
                record.optBoolean("atWall") && changed.isEmpty() && record.getLong("mastery") == 0L -> "현재 능력치의 성장 한계예요. 다른 능력 훈련을 골라보세요."
                record.getLong("mastery") > 0 && changed.isEmpty() -> "숙련이 쌓였어요. 능력치가 같아도 훈련의 효과는 남아요."
                else -> "현재 몸 상태를 보고 다음 훈련을 골라보세요."
            }, style = MaterialTheme.typography.bodyMedium)
        }
        Button(onClick = onContinue, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("training.feedback.continue")) { Text("계속하기") }
    }
}
