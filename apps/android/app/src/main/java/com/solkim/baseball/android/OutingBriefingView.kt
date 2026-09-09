package com.solkim.baseball.android

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.android.LocalizedGameText as Text

@Composable
internal fun OutingBriefingView(state: GameAggregateState, model: Phase8ScreenModel, context: Phase8CommandContext, onAction: (Phase8UiAction) -> Unit) {
    val copy = rememberGameCopy()
    val briefing = remember(state, context) { OutingPresentation.briefing(state, context) }?.localized(copy)
    if (briefing != null) {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
            playerPortraitSeed(state)?.let { PlayerPortrait(seed = it, stage = if (state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT)) PlayerStage.PRO else if ((state.highSchool?.run?.chapter?.schoolYear ?: 1) >= 3) PlayerStage.ACE else PlayerStage.FRESHMAN, width = 36.dp) }
            Text(briefing.title, verbatim = true, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, modifier = Modifier.testTag("outing.role"))
        }
        VisualOutingSituation(briefing)
        if (state.pitch != null && (state.pro?.activePitch != null || state.highSchool?.activePitch != null)) {
            val batter = PitchHudProjection.batter(state)
            Text(batter.name, modifier = Modifier.testTag("outing.opponent"))
            val outs = if (state.pitch?.careerKind == PitchCareerKind.PRO) state.pro?.activePitch?.outs ?: 0 else state.highSchool?.activePitch?.outs ?: 0
            Text("지금까지 ${PitchHudProjection.sessionPitches(state)}구 · ${outs}아웃", modifier = Modifier.testTag("outing.progress"))
            Text("피로 ${PitchHudProjection.fatigue(state)}")
        }
        HorizontalDivider()
        Text("이번 목표", style = MaterialTheme.typography.labelLarge)
        Text(briefing.goal, verbatim = true, style = MaterialTheme.typography.titleLarge, modifier = Modifier.testTag("outing.goal"))
        if (briefing.reward.isNotBlank()) Text(briefing.reward, verbatim = true, color = BaseballColors.action)
        if (briefing.story.isNotBlank()) CareerDisclosure("상대와 경기 이야기", "outing.details") { Text(briefing.story, verbatim = true) }
    }
    model.actions.filter { it.enabled }.forEach { action ->
        OutlinedButton(onClick = { onAction(Phase8UiAction(model.id, action.id, action.payloads)) },
            modifier = Modifier.heightIn(min = 48.dp).testTag("action.${action.id}")) { Text(action.label) }
    }
}
