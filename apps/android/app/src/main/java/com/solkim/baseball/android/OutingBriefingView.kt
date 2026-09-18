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
internal fun OutingBriefingView(state: GameAggregateState, model: ScreenModel, context: ScreenCommandContext, onAction: (ScreenUiAction) -> Unit) {
    OutingBriefingView(OutingBriefingModel.resolve(state, context), model, onAction)
}

@Composable
internal fun OutingBriefingView(view: OutingBriefingModel, model: ScreenModel, onAction: (ScreenUiAction) -> Unit) {
    val copy = rememberGameCopy()
    val briefing = view.briefing?.localized(copy)
    if (briefing != null) {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
            view.portraitSeed?.let {
                PlayerPortrait(seed = it, stage = if (view.isPro) PlayerStage.PRO else if (view.isAceYear) PlayerStage.ACE else PlayerStage.FRESHMAN, width = 36.dp)
            }
            Text(briefing.title, verbatim = true, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, modifier = Modifier.testTag("outing.role"))
        }
        VisualOutingSituation(briefing)
        view.live?.let { live ->
            Text(live.batterName, modifier = Modifier.testTag("outing.opponent"))
            Text("지금까지 ${live.sessionPitches}구 · ${live.outs}아웃", modifier = Modifier.testTag("outing.progress"))
            Text("피로 ${live.fatigue}")
        }
        HorizontalDivider()
        Text("이번 목표", style = MaterialTheme.typography.labelLarge)
        Text(briefing.goal, verbatim = true, style = MaterialTheme.typography.titleLarge, modifier = Modifier.testTag("outing.goal"))
        if (briefing.reward.isNotBlank()) Text(briefing.reward, verbatim = true, color = BaseballColors.action)
        if (briefing.story.isNotBlank()) CareerDisclosure("상대와 경기 이야기", "outing.details") { Text(briefing.story, verbatim = true) }
    }
    model.actions.filter { it.enabled }.forEach { action ->
        OutlinedButton(onClick = { onAction(ScreenUiAction(model.id, action.id, action.payloads)) },
            modifier = Modifier.heightIn(min = 48.dp).testTag("action.${action.id}")) { Text(action.label) }
    }
}
