package com.solkim.baseball.android

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.android.LocalizedGameText as Text

@Composable
internal fun DraftJourneySummary(state: GameAggregateState) {
    val hs = state.highSchool ?: return
    val run = hs.run
    val draft = run.draftResult ?: return
    val record = CareerRecordPresentation.resolve(state, "hs:${run.careerId}")
    Column(Modifier.fillMaxWidth().testTag("draft.journey"), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("3년의 결과", style = MaterialTheme.typography.headlineMedium)
        Text(draft.team?.name ?: "이번 드래프트 미지명", style = MaterialTheme.typography.headlineSmall, color = BaseballColors.milestone)
        if (draft.round != null && draft.overallPick != null) Text("${draft.round}라운드 · 전체 ${draft.overallPick}순위", style = MaterialTheme.typography.titleSmall)
        Text(run.identity.name, verbatim = true, style = MaterialTheme.typography.titleMedium)
        run.school?.let { Text(it.name, style = MaterialTheme.typography.titleMedium) }
        record?.let { Text("${it.games}경기 · ${it.innings}이닝 · ${it.strikeouts}탈삼진", modifier = Modifier.testTag("draft.record")) }
        Text("처음의 나 → 지금의 나", style = MaterialTheme.typography.titleSmall)
        AbilityChangeBars(hs.startingPitcher.let { listOf(it.stuff, it.command, it.movement, it.stamina) },
            run.pitcher.let { listOf(it.stuff, it.command, it.movement, it.stamina) }, state.settings.reducedMotionEnabled, "draft.growth")
        val start = hs.startingPitcher.let { listOf(it.stuff, it.command, it.movement, it.stamina) }
        val current = run.pitcher.let { listOf(it.stuff, it.command, it.movement, it.stamina) }
        if (current.indices.any { current[it] < start[it] }) {
            Text("표시된 변화는 훈련뿐 아니라 경기와 선택의 영향까지 합친 값입니다.", style = MaterialTheme.typography.bodySmall)
            CareerDisclosure("능력 감소 기록", "draft.decreases") {
                val points = state.meta.abilityHistory.filter { it.career == run.careerId && !it.pro }
                val drops = points.zipWithNext().flatMap { (before, after) ->
                    current.indices.filter { current[it] < start[it] && after.ratings[it] != before.ratings[it] }.map { index ->
                        val awakening = run.selectedAwakenings.firstOrNull { after.id.contains("-awakening-${it.wire}-") }
                        val cause = if (awakening != null) "각성 ${HighSchoolDisplayRules.awakeningTitle(awakening.wire)}" else when (after.source) { "training" -> "훈련 진행"; "game" -> "경기 진행"; else -> "커리어 진행" }
                        val delta = AbilityDisplayScale.rating(after.ratings[index]) - AbilityDisplayScale.rating(before.ratings[index])
                        "${after.season}학년 · $cause · ${listOf("구위", "제구", "무브먼트", "체력")[index]} ${if (delta > 0) "+$delta" else delta.toString()}"
                    }
                }
                if (drops.isEmpty()) Text("이전의 세부 변경 기록이 없어 정확한 감소 원인은 확인할 수 없어요.")
                else { drops.forEach { Text(it) }; Text("기록된 진행 구간의 변화입니다. 개별 선택의 세부 원인은 남아 있지 않을 수 있어요.") }
            }
        }
        Text(HighSchoolDisplayRules.presetTitle(run.presetId), style = MaterialTheme.typography.labelLarge)
        Text("${run.totalTrainingsCompleted}번의 훈련 · ${run.relationshipsCompleted}번의 대화")
        run.school?.coachName?.let { Text(it, color = BaseballColors.milestone) }
        Text(if (run.managerTrust >= 65) "네가 쌓은 3년을 믿는다. 다음 마운드에서도 네 공을 던져라." else "여기서 끝은 아니다. 다음 마운드에서 네 공을 보여 줘라.", modifier = Modifier.testTag("draft.finalWords"))
    }
}
