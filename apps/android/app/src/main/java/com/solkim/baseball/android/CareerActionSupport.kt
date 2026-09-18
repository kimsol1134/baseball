package com.solkim.baseball.android

import com.solkim.baseball.application.PitchBoundary

import androidx.compose.foundation.background

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.width

import android.content.Intent
import com.solkim.baseball.application.SetupRepertoire
import com.solkim.baseball.application.AbilityDisplayScale
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.ui.platform.LocalContext
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Alignment
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import com.solkim.baseball.application.AvatarRole
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.horizontalScroll
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalView
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.foundation.layout.RowScope
import androidx.compose.ui.semantics.selected
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import com.solkim.baseball.android.LocalizedGameText as Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import com.solkim.baseball.application.ScreenGroup
import com.solkim.baseball.design.BaseballColors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import com.solkim.baseball.application.RebirthStartPreview
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.produceState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.CareerShareCopy
import com.solkim.baseball.application.CareerUiRules
import com.solkim.baseball.application.RebirthContinuity
import com.solkim.baseball.application.RelationshipNarrative
import androidx.compose.foundation.BorderStroke
import com.solkim.baseball.application.SignatureLegacyDisplay
import com.solkim.baseball.application.GameCopyArgument
import com.solkim.baseball.application.GameAggregateState
import com.solkim.baseball.application.ScreenActionModel
import com.solkim.baseball.application.ScreenCommandContext
import com.solkim.baseball.application.ScreenCommandPayload
import com.solkim.baseball.application.LifeCardProjection
import com.solkim.baseball.application.PlayerLegacyExposurePolicy
import com.solkim.baseball.application.PlayerLegacyExposureSurface
import com.solkim.baseball.application.ScreenId
import com.solkim.baseball.application.ScreenModel
import com.solkim.baseball.application.ScreenProjection
import com.solkim.baseball.application.ScreenPayloads
import com.solkim.baseball.application.SetupDifficulty
import com.solkim.baseball.application.SetupSoulDomain
import com.solkim.baseball.application.SetupSoulBoost
import com.solkim.baseball.application.SetupPitch
import androidx.compose.material3.AlertDialog
import com.solkim.baseball.application.BaseballGlossary
import com.solkim.baseball.application.HighSchoolDisplayRules
import com.solkim.baseball.application.localized
import com.solkim.baseball.application.HighSchoolDraftOutcome
import com.solkim.baseball.application.HighSchoolReturnDestination

import com.solkim.baseball.platform.NotificationPermissionTruth
import com.solkim.baseball.platform.ReminderOfferPolicy
@Composable
internal fun CareerReadOnlyRow(label: String, value: String, detail: String) {
    var showHelp by remember { mutableStateOf(false) }
    val terms = BaseballGlossary.terms.filter { term -> label.contains(term.name) || value.contains(term.name) }.take(3)
    if (showHelp && terms.isNotEmpty()) AlertDialog(onDismissRequest = { showHelp = false },
        title = { Text("야구 용어") },
        text = { Column(verticalArrangement = Arrangement.spacedBy(12.dp)) { terms.forEach { Text("${it.name} · ${it.definition}") } } },
        confirmButton = { TextButton(onClick = { showHelp = false }) { Text("확인") } })
    Column(
        Modifier
            .fillMaxWidth()
            .gameDescription(listOf(label, value, detail).filter(String::isNotBlank).joinToString(". ")),
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        if (terms.isEmpty()) Text(label, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
        else TextButton(onClick = { showHelp = true }) { Text("$label ⓘ") }
        Text(value, verbatim = true, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
        if (detail.isNotBlank()) {
            Text(detail, verbatim = true, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
internal fun CareerChoiceGrid(
    model: ScreenModel,
    onAction: (ScreenUiAction) -> Unit,
) {
    if (model.actions.isEmpty()) return
    val heading = when (model.id) {
        ScreenId.P006_TRAINING -> stringResource(R.string.choice_heading_training)
        ScreenId.P007_RELATIONSHIP -> stringResource(R.string.choice_heading_relationship)
        else -> stringResource(R.string.choice_heading_week)
    }
    Text(heading, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
    val weekly = model.actions.filter { it.id != "proAdvanceSegment" && !it.id.startsWith("requestRole:") }
    val skip = model.actions.filter { it.id == "proAdvanceSegment" }
    weekly.chunked(2).forEach { row ->
        AdaptiveActionRow(Modifier.fillMaxWidth()) {
            row.forEach { action ->
                Column(Modifier, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Button(
                        onClick = { onAction(ScreenUiAction(model.id, action.id, action.payloads)) },
                        enabled = action.enabled,
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 48.dp)
                            .testTag("action.${action.id}").gameDescription(action.contentDescription),
                    ) { Text(action.label) }
                    Text(
                        action.description,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
    skip.forEach { action ->
        OutlinedButton(
            onClick = { onAction(ScreenUiAction(model.id, action.id, action.payloads)) },
            enabled = action.enabled,
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 48.dp)
                .testTag("action.${action.id}").gameDescription(action.contentDescription),
        ) { Text(action.label) }
        Text(
            action.description,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
internal fun CareerShareButton(
    state: GameAggregateState,
    model: ScreenModel,
) {
    val copy = rememberGameCopy()
    val rawText = when {
        state.meta.seedChallenge != null && model.id in setOf(ScreenId.P013_DRAFT, ScreenId.P014_RUN_RECAP, ScreenId.P025_RECORDS_LEAGUE) -> CareerShareCopy.challenge(state)
        else -> when (model.id) {
        ScreenId.P013_DRAFT -> CareerShareCopy.draft(state)
        ScreenId.P019_PRO_SEASON -> CareerShareCopy.nationalMedal(state)
        ScreenId.P021_PRO_RETIREMENT -> CareerShareCopy.retirement(state)
        ScreenId.P015_REBIRTH -> CareerShareCopy.retirement(state) ?: CareerShareCopy.draft(state)
        ScreenId.P025_RECORDS_LEAGUE -> CareerShareCopy.retirement(state) ?: CareerShareCopy.records(state)
        else -> null
        }
    } ?: return
    val names = if (state.meta.seedChallenge == null) setOfNotNull(CareerUiRules.playerName(state), CareerUiRules.playerName(state)) else emptySet()
    val text = copy.legacy(rawText, names)
    val context = LocalContext.current
    val title = if (state.meta.seedChallenge != null) copy.resolve("android.challenge.result") else when (model.id) {
        ScreenId.P013_DRAFT -> stringResource(R.string.share_draft_title)
        ScreenId.P019_PRO_SEASON -> stringResource(R.string.share_national_title)
        ScreenId.P021_PRO_RETIREMENT -> stringResource(R.string.share_retirement_title)
        else -> stringResource(R.string.share_records_title)
    }
    val shareLabel = stringResource(R.string.share_action)
    val appName = stringResource(R.string.app_name)
    OutlinedButton(
        onClick = {
            com.solkim.baseball.platform.NativeAchievementShareService(context).share(
                title, text, appName,
                "https://play.google.com/store/apps/details?id=com.solkim.baseball.android", state.meta.seedChallenge?.code?.webUrl,
            )
        },
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .gameDescription("$title $shareLabel"),
    ) {
        Text(shareLabel)
    }
}

@Composable
internal fun CareerActions(
    model: ScreenModel,
    onAction: (ScreenUiAction) -> Unit,
) {
    val actions = if (model.id in setOf(ScreenId.P008_IMPORTANT_GAME, ScreenId.P018_PRO_IMPORTANT_GAME)) model.actions.filter { it.enabled } else model.actions
    if (actions.isEmpty()) return
    HorizontalDivider()
    actions.forEach { action ->
        CareerActionButton(model.id, action, onAction, showDescription = model.id.group == ScreenGroup.PRO && actions.count { it.enabled } > 1)
    }
}

@Composable
internal fun CareerActionButton(
    screenId: ScreenId,
    action: ScreenActionModel,
    onAction: (ScreenUiAction) -> Unit,
    showDescription: Boolean = false,
) {
    val label = when (action.id) {
        "completeTutorial" -> "학교 선택"
        "prepareLegacy" -> "능력 고르기"
        "quickRebirth" -> "환생하기"
        "finalizeArchive" -> "이번 생 마무리"
        "openImportantGame", "openProImportantGame" -> "등판하기"
        else -> action.label
    }
    val description = if (action.enabled || (screenId == ScreenId.P024_WEEKLY && action.id == "claimWeeklyReward")) action.contentDescription else "${action.label}. 아직 열리지 않았다."
    if (action.destructive) {
        OutlinedButton(
            onClick = { onAction(ScreenUiAction(screenId, action.id, action.payloads)) },
            enabled = action.enabled,
            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("action.${action.id}").gameDescription(description),
        ) { Text(label, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.error) }
    } else {
        Button(
            onClick = { onAction(ScreenUiAction(screenId, action.id, action.payloads)) },
            enabled = action.enabled,
            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("action.${action.id}").gameDescription(description),
        ) { Text(label, style = MaterialTheme.typography.labelLarge) }
    }
    if ((showDescription || action.destructive) && action.description.isNotBlank()) Text(
        action.description,
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

@Composable
internal fun CareerErrorCard(message: String) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)) {
        Text(
            message,
            modifier = Modifier.padding(16.dp).gameDescription(message),
            color = MaterialTheme.colorScheme.onErrorContainer,
        )
    }
}
