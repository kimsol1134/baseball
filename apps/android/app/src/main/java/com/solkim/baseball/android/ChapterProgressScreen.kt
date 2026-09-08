package com.solkim.baseball.android

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.android.LocalizedGameText as Text

@Composable
internal fun ChapterProgressScreen(state: GameAggregateState, model: Phase8ScreenModel, busy: Boolean, error: String?,
                                   insets: PaddingValues, onAction: (Phase8UiAction) -> Unit, onNavigate: (Phase8ScreenId) -> Unit) {
    val run = state.highSchool?.run ?: return
    val copy = rememberGameCopy()
    val training = ChapterProgressPresentation.training(state)
    val games = ChapterProgressPresentation.games(state)
    Column(Modifier.fillMaxSize().padding(insets).verticalScroll(rememberScrollState()).padding(20.dp).testTag("chapter.progress"),
        verticalArrangement = Arrangement.spacedBy(16.dp)) {
        if (error != null) Text(error, color = MaterialTheme.colorScheme.error)
        Text(copy.resolve("chapter.compact.heading"), verbatim = true, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        if (run.chapterTrainingCount > 0) Card(colors = CardDefaults.cardColors(containerColor = BaseballColors.surfaceRaised)) {
            Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(copy.resolve("chapter.compact.training-count", GameCopyArgument.Whole(run.chapterTrainingCount.toLong())),
                    verbatim = true, style = MaterialTheme.typography.titleMedium, color = BaseballColors.action, modifier = Modifier.testTag("chapter.training"))
                training.forEach { item ->
                    val label = GameCopyArgument.UserText(copy.legacy(TrainingPresentation.title(item.focus)))
                    Text(copy.resolve("chapter.compact.training-row", label, GameCopyArgument.Whole(item.count.toLong())), verbatim = true)
                    item.currentRating?.let { rating ->
                        Text(copy.resolve("chapter.compact.current-ability", GameCopyArgument.UserText(copy.legacy(TrainingPresentation.metric(item.focus))),
                            GameCopyArgument.Whole(rating.toLong())), verbatim = true,
                            style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
                    }
                }
            }
        }
        if (games.isNotEmpty()) Card(colors = CardDefaults.cardColors(containerColor = BaseballColors.surfaceRaised)) {
            Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(copy.resolve("chapter.compact.games"), verbatim = true, color = BaseballColors.milestone, style = MaterialTheme.typography.titleMedium)
                Text(copy.resolve("chapter.compact.game-line", GameCopyArgument.Whole(games.size.toLong()),
                    GameCopyArgument.UserText("${games.sumOf { it.outs } / 3}.${games.sumOf { it.outs } % 3}"),
                    GameCopyArgument.Whole(games.sumOf { it.strikeouts }.toLong()), GameCopyArgument.Whole(games.sumOf { it.runsAllowed }.toLong())),
                    verbatim = true, modifier = Modifier.testTag("chapter.games"))
                games.sumOf { it.perfectReleases }.takeIf { it > 0 }?.let { count ->
                    Text(copy.resolve("chapter.compact.perfect", GameCopyArgument.Whole(count.toLong())), verbatim = true, color = BaseballColors.action)
                }
            }
        }
        Surface(color = BaseballColors.actionSoft, shape = MaterialTheme.shapes.medium) {
            Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(copy.resolve("chapter.compact.next"), verbatim = true, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Text(copy.resolve("chapter.compact.next-detail", GameCopyArgument.Whole(ChapterProgressPresentation.nextTrainings(state).toLong())), verbatim = true)
            }
        }
        model.actions.firstOrNull { it.id == "claimChapterGame" && it.enabled }?.let { action ->
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(copy.resolve("chapter.compact.optional"), verbatim = true, color = BaseballColors.textSecondary, style = MaterialTheme.typography.bodyMedium)
                OutlinedButton(onClick = { onAction(Phase8UiAction(model.id, action.id, action.payloads)) }, enabled = !busy,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp).testTag("action.claimChapterGame")) { Text(action.label) }
            }
        }
        TextButton(onClick = { onNavigate(Phase8ScreenId.P011_HIGH_SCHOOL_CAREER) }, modifier = Modifier.testTag("chapter.allRecords")) {
            Text(copy.resolve("chapter.compact.records"), verbatim = true)
        }
    }
}
