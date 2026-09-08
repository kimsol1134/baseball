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
    val briefing = remember(state, context) { OutingPresentation.briefing(state, context) }
    if (briefing != null) {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
            playerPortraitSeed(state)?.let { PlayerPortrait(seed = it, width = 36.dp) }
            Text(briefing.title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, modifier = Modifier.testTag("outing.role"))
        }
        Text(briefing.score, style = MaterialTheme.typography.headlineMedium, color = BaseballColors.milestone)
        Text(briefing.situation, style = MaterialTheme.typography.titleMedium, modifier = Modifier.testTag("outing.situation"))
        HorizontalDivider()
        Text("이번 목표", style = MaterialTheme.typography.labelLarge)
        Text(briefing.goal, style = MaterialTheme.typography.titleLarge, modifier = Modifier.testTag("outing.goal"))
        if (briefing.reward.isNotBlank()) Text(briefing.reward, color = BaseballColors.action)
        if (briefing.story.isNotBlank()) CareerDisclosure("상대와 경기 이야기", "outing.details") { Text(briefing.story) }
    }
    model.actions.filter { it.enabled }.forEach { action ->
        OutlinedButton(onClick = { onAction(Phase8UiAction(model.id, action.id, action.payloads)) },
            modifier = Modifier.heightIn(min = 48.dp).testTag("action.${action.id}")) { Text(action.label) }
    }
}
