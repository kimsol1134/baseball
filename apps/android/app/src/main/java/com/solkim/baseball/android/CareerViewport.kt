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
import com.solkim.baseball.application.ReturnPlanView
import com.solkim.baseball.platform.NotificationPermissionTruth
import com.solkim.baseball.platform.ReminderOfferPolicy
@Composable
public fun ViewportExposureBox(
    exposure: ViewportExposure,
    onExposed: (ViewportExposure) -> Unit,
    modifier: Modifier = Modifier,
        content: @Composable () -> Unit,
) {
    val view = LocalView.current
    var emitted by remember(exposure.eventName, exposure.scope) { mutableStateOf(false) }
    Box(
        modifier = modifier
            .fillMaxWidth()
            .onGloballyPositioned { coordinates ->
                if (emitted) return@onGloballyPositioned
                val bounds = coordinates.boundsInWindow()
                val width = view.rootView.width.toFloat()
                val height = view.rootView.height.toFloat()
                val visibleWidth = (bounds.right.coerceAtMost(width) - bounds.left.coerceAtLeast(0f)).coerceAtLeast(0f)
                val visibleHeight = (bounds.bottom.coerceAtMost(height) - bounds.top.coerceAtLeast(0f)).coerceAtLeast(0f)
                val visible = bounds.width > 0f && bounds.height > 0f && visibleWidth > 0f && visibleHeight > 0f
                if (visible) {
                    emitted = true
                    onExposed(exposure)
                }
            },
    ) { content() }
}

@Composable
internal fun LifeCardVisual(state: GameAggregateState, careerId: String) {
    val record = CareerUiRules.archiveRecord(state, careerId) ?: return
    Card(colors = CardDefaults.cardColors(containerColor = BaseballColors.surfaceRaised)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                PlayerPortrait(
                    seed = lineagePortraitSeed(state) ?: record.playerName,
                    role = AvatarRole.PLAYER,
                    stage = if (record.drafted) PlayerStage.PRO else PlayerStage.ACE,
                    width = 58.dp,
                )
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text("${record.lifeNumber}번째 생", style = MaterialTheme.typography.labelMedium, color = BaseballColors.milestone)
                    Text(record.playerName, verbatim = true, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                    Text(
                        if (record.drafted) "지명" else "미지명",
                        color = if (record.drafted) BaseballColors.action else BaseballColors.textTertiary,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(record.schoolName ?: "학교 기록 없음", style = MaterialTheme.typography.bodyMedium, color = BaseballColors.textSecondary)
                }
            }

            CareerStatTiles(listOf("경기" to record.importantGames.toString(), "탈삼진" to record.strikeouts.toString(), "퍼펙트 릴리스" to record.perfectReleases.toString()))
            CareerDisclosure("전체 성적", "life.details.${record.careerId}") {
                CareerStatTiles(listOf("볼넷" to record.walks.toString(), "실점" to record.runsAllowed.toString(), "스카우트 평가" to record.draftEvaluation.toString()))

            Text(listOf("구위", "제구", "무브먼트", "체력").zip(record.ratings.map(AbilityDisplayScale::rating)).joinToString(" · ") { (label, value) -> "$label $value" }, style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
            lineageLine(state, upToLife = record.lifeNumber)?.let { Text(it, style = MaterialTheme.typography.labelSmall, color = BaseballColors.textTertiary) }
            }
        }
    }
}


/** The face belongs to the lineage: the first life's name seeds every later life, even after a rename. */
internal fun playerPortraitSeed(state: GameAggregateState): String? = CareerUiRules.portraitSeed(state)

internal fun lineagePortraitSeed(state: GameAggregateState): String? =
    CareerUiRules.archive(state).firstOrNull()?.playerName?.takeIf { it.isNotBlank() }

/** Last three lives in one line: who they were and how it ended. */
internal fun lineageLine(state: GameAggregateState, upToLife: Int? = null): String? {
    val records = CareerUiRules.archive(state).filter { upToLife == null || it.lifeNumber <= upToLife }.takeLast(3)
    if (records.isEmpty()) return null
    return "계보 " + records.joinToString(" → ") { "${it.lifeNumber}생 ${it.playerName} ${if (it.drafted) "지명" else "미지명"} K${it.strikeouts}" }
}

internal fun windLabel(id: String): String = when (id) {
    "calm" -> "고요한 해"
    "monster_generation" -> "괴물 세대"
    "scout_frenzy" -> "스카우트 풍년"
    "quiet_season" -> "무명의 해"
    "heatwave" -> "긴 여름"
    "command_year" -> "코스의 해"
    "power_year" -> "강한 공의 해"
    "battery_year" -> "배터리의 해"
    "spotlight_year" -> "조명의 해"
    else -> "언더독의 해"
}

internal fun returnPlanExposureProperties(
    plan: ReturnPlanView,
    returnDayKey: String,
): List<Pair<String, String>> = buildList {
    add("destination" to plan.destination.wire)
    add("reason" to plan.reason)
    add("plan_receipt" to plan.receiptId)
    plan.experimentId?.let { add("experiment_id" to it) }
    plan.experimentVariant?.let { add("variant" to it) }
    val savedDay = plan.savedDayKey ?: plan.createdDayKey
    add("saved_day_key" to savedDay)
    add("return_day_key" to returnDayKey)
    HighSchoolDisplayRules.returnPlanDayGap(savedDay, returnDayKey)?.let { add("day_gap" to it.toString()) }
    plan.developmentRulesVersion?.let { add("development_rules_version" to it.toString()) }
}

internal fun HighSchoolReturnDestination.labelForProduct(): String =
    HighSchoolDisplayRules.returnDestinationProductLabel(this)
