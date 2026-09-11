package com.solkim.baseball.android

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballColors
import kotlinx.coroutines.delay
import com.solkim.baseball.android.LocalizedGameText as Text

@Composable
internal fun MoundLoadingView() {
    Surface(Modifier.fillMaxSize(), color = BaseballColors.canvas) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
    }
}

/** Only a display acknowledgement: no pitch, reward or career command is sent by this button. */
@Composable
@OptIn(ExperimentalComposeUiApi::class)
internal fun FirstPracticeIntroduction(autoRelease: Boolean = false, onStart: () -> Unit) {
    var ready by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { withFrameNanos { }; delay(500); ready = true }
    AlertDialog(onDismissRequest = {}, containerColor = BaseballColors.surfaceRaised,
        modifier = Modifier.semantics { testTagsAsResourceId = true }.testTag("pitch.practiceIntroduction"),
        title = { Text("연습 투구") },
        text = { Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("포수가 구종과 코스를 골라뒀어요.")
            Text(if (autoRelease) "투구 버튼을 누르면 공을 던져요." else "버튼을 누르고, 초록 구간에서 놓아보세요.")
        } },
        confirmButton = { TextButton(onClick = onStart, enabled = ready, modifier = Modifier.testTag("pitch.practiceIntroduction.start")) { Text("연습 시작") } })
}

/** Resume old saves/explicitly paused practice without bringing back the discarded instruction page. */
@Composable
@OptIn(ExperimentalComposeUiApi::class)
internal fun PracticeEntryRecovery(state: GameAggregateState, model: ScreenModel, busy: Boolean, error: String?, onAction: (ScreenUiAction) -> Unit, onExitChallenge: (() -> Unit)? = null) {
    var requested by remember(CareerUiRules.highSchoolCareerId(state)) { mutableStateOf(false) }
    val open = model.actions.firstOrNull { it.id == "openTutorialPitch" && it.enabled }
    val fresh = state.pitch == null && !CareerUiRules.hasLastPresentation(state)
    fun run(action: ScreenActionModel) {
        requested = true
        onAction(ScreenUiAction(model.id, action.id, action.payloads))
    }
    LaunchedEffect(fresh, busy, error, requested) {
        if (fresh && !busy && error == null && !requested && open != null) run(open)
    }
    if (busy || (fresh && error == null)) { MoundLoadingView(); return }
    Surface(Modifier.fillMaxSize().semantics { testTagsAsResourceId = true }, color = BaseballColors.canvas, contentColor = BaseballColors.textPrimary) {
    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("연습 투구", style = MaterialTheme.typography.headlineSmall)
        error?.let { Text(it, color = BaseballColors.warning) }
        model.actions.filter { it.enabled && it.id in setOf("openTutorialPitch", "resumePitch", "completeTutorial") }.forEach { action ->
            Button(onClick = { run(action) }, modifier = Modifier.testTag("action.${action.id}")) {
                Text(when (action.id) { "completeTutorial" -> "학교 선택"; "resumePitch" -> "연습 이어가기"; else -> "연습 투구" })
            }
        }
        onExitChallenge?.let { leave -> TextButton(onClick = leave) { Text(rememberGameCopy().resolve("android.challenge.exit"), verbatim = true) } }
    }
    }
}
