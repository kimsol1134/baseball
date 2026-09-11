package com.solkim.baseball.android

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.testTagsAsResourceId
import android.content.Context
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color as ComposeColor
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.solkim.baseball.android.LocalizedGameText as Text
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.model.QualityTier

@Composable
@OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)
internal fun PitchControlsCard(
    practice: Boolean = false,
    practiceStep: Int = 1,
    signaturePitch: String? = null,
    signatureName: String = "",
    lastPitchLine: String?,
    coachTip: String?,
    repertoire: List<PitchKind>,
    primary: PitchRecommendation?,
    alternative: PitchRecommendation?,
    selection: PitchHudSelection,
    selectedZone: PitchZone,
    selectedIntent: ZoneIntent = ZoneIntent.EDGE,
    selectedIntensity: PitchIntensity = PitchIntensity.NORMAL,
    batSide: BatSide,
    currentPitchLine: String,
    primaryExplanation: String,
    holdToReleasePrompt: String,
    ready: Boolean,
    velocityTenthsKph: Int,
    commandRating: Int,
    previousCommand: Int? = null,
    previousVelocity: Int? = null,
    autoRelease: Boolean,
    autoReleaseLabel: String,
    catcherConfidenceLabel: String,
    catcherTrustLabel: String,
    fatigue: Int,
    reduceMotion: Boolean,
    hapticsEnabled: Boolean,
    soundEnabled: Boolean,
    tension: Double,
    disturbanceSeed: ULong,
    adverseEpisode: Boolean,
    holdCall: Boolean = false,
    scoutingTitle: String = "",
    scoutingBody: String = "",
    scoutingAvoid: String = "",
    canFastForward: Boolean = false,
    onSelect: (PitchHudSelection) -> Unit,
    onDeliver: (PitchDelivery) -> Unit,
    onHoldCallChange: (Boolean) -> Unit = {},
    onFastForward: () -> Unit = {},
    onAutoReleaseChange: ((Boolean) -> Unit)? = null,
    onHapticsChange: (Boolean) -> Unit = {},
    fastResults: Boolean = false,
    onFastResultsChange: (Boolean) -> Unit = {},
) {
    var aimingLocked by remember { mutableStateOf(false) }
    val choose: (PitchHudSelection) -> Unit = { if (ready && !aimingLocked) onSelect(it) }
    val selectedType = when (selection) {
        PitchHudSelection.Primary -> primary?.call?.pitchType
        PitchHudSelection.Alternative -> alternative?.call?.pitchType
        is PitchHudSelection.Manual -> selection.pitchType
    }
    val selectedPitchLine = when (val sign = selection) {
        PitchHudSelection.Primary -> primary?.call?.let { PitchHudProjection.callLine(it, batSide) } ?: currentPitchLine
        PitchHudSelection.Alternative -> alternative?.call?.let { PitchHudProjection.callLine(it, batSide) } ?: currentPitchLine
        is PitchHudSelection.Manual -> listOf(
            PitchHudProjection.koreanLabel(sign.pitchType),
            PitchHudProjection.zoneLabel(sign.zone, batSide),
        ).joinToString(" · ")
    }
    val selectedReason = when (selection) {
        PitchHudSelection.Primary -> primary?.shortReason
        PitchHudSelection.Alternative -> alternative?.shortReason
        is PitchHudSelection.Manual -> primary?.shortReason
    }.orEmpty().let { if (selection is PitchHudSelection.Manual) "" else it.ifBlank { primaryExplanation } }
    var rationaleOpen by remember { mutableStateOf(false) }
    var settingsOpen by remember { mutableStateOf(false) }
    var hapticTestAccepted by remember { mutableStateOf<Boolean?>(null) }
    val copy = rememberGameCopy()
    val controlsView = LocalView.current
    Surface(
        color = BaseballColors.surfaceRaised,
        shape = RoundedCornerShape(16.dp),
        border = BorderStroke(1.dp, BaseballColors.border.copy(alpha = 0.4f)),
        modifier = Modifier.fillMaxSize(),
    ) {
        BoxWithConstraints(Modifier.fillMaxSize()) {
        val choicesHeight = (maxHeight - 286.dp - if (canFastForward && fatigue >= 80) 48.dp else 0.dp).coerceIn(48.dp, 400.dp)
        Column(Modifier.fillMaxSize().padding(4.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            // The core choices come first. Scrolling is a fallback for accessibility text sizes.
            Column(Modifier.fillMaxWidth().heightIn(max = choicesHeight).verticalScroll(rememberScrollState()).testTag("pitch.choices"), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                PitchTypeChoices(repertoire, selectedType, ready && !aimingLocked, signaturePitch, signatureName) { type ->
                    if (hapticsEnabled) controlsView.pitchTouchFeedback(android.view.HapticFeedbackConstants.CLOCK_TICK, hapticsEnabled)
                    choose(PitchHudSelection.Manual(type, selectedZone, selectedIntent, selectedIntensity))
                }
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(PitchHudProjection.zoneLabel(selectedZone, batSide), modifier = Modifier.weight(1f).testTag("pitch.selected-zone.${selectedZone.row}.${selectedZone.column}"),
                        style = MaterialTheme.typography.labelMedium, color = BaseballColors.action)
                    CatcherOptionSegment(copy.resolve("compact.pitch.sign"), selection is PitchHudSelection.Primary, ready && !aimingLocked,
                        modifier = Modifier.widthIn(min = 48.dp).testTag("pitch.recommendation")) { choose(PitchHudSelection.Primary) }
                    if (alternative != null) CatcherOptionSegment(copy.resolve("compact.pitch.alternative"), selection is PitchHudSelection.Alternative, ready && !aimingLocked,
                        modifier = Modifier.widthIn(min = 48.dp).testTag("pitch.alternative")) { choose(PitchHudSelection.Alternative) }
                    TextButton(onClick = { settingsOpen = true }, contentPadding = PaddingValues(horizontal = 4.dp), modifier = Modifier.testTag("pitch.settings")) { Text("설정", style = MaterialTheme.typography.labelMedium) }
                }
                PitchEffortControl(selectedIntensity, primary?.call?.intensity, ready && !aimingLocked,
                    expectedVelocity = velocityTenthsKph, compact = true, onChange = { intensity ->
                        if (hapticsEnabled) controlsView.pitchTouchFeedback(android.view.HapticFeedbackConstants.CLOCK_TICK, hapticsEnabled)
                        choose(PitchHudSelection.Manual(selectedType ?: repertoire.firstOrNull() ?: PitchKind.FOUR_SEAM, selectedZone, selectedIntent, intensity))
                    })
            }
            Box(Modifier.weight(1f).fillMaxWidth().testTag("pitch.aimingField")) {
                BoxWithConstraints(Modifier.fillMaxWidth().heightIn(min = 180.dp).fillMaxHeight().clip(RoundedCornerShape(12.dp)).background(BaseballColors.fieldNight)) {
                    val catcherHeight = (maxHeight - 24.dp).coerceIn(172.dp, 300.dp)
                    val catcherWidth = catcherHeight * (154f / 172f)
                    val zoneWidth = (catcherWidth * 0.98f).coerceIn(156.dp, 240.dp)
                    val batterHeight = catcherHeight * (164f / 172f)
                    androidx.compose.foundation.Image(androidx.compose.ui.res.painterResource(R.drawable.catcher_stance), contentDescription = null,
                        modifier = Modifier.align(Alignment.Center).size(width = catcherWidth, height = catcherHeight).alpha(PlateFigures.ASSET_OPACITY))
                    androidx.compose.foundation.Image(androidx.compose.ui.res.painterResource(R.drawable.batter_stance), contentDescription = null,
                        modifier = Modifier.align(if (batSide == BatSide.LEFT) Alignment.CenterEnd else Alignment.CenterStart).size(width = batterHeight * (84f / 164f), height = batterHeight)
                            .graphicsLayer { scaleX = if (batSide == BatSide.LEFT) -1f else 1f }.alpha(PlateFigures.ASSET_OPACITY))
                    Box(Modifier.align(Alignment.Center).width(zoneWidth)) {
                        PitchZoneGrid(selected = selectedZone, recommended = primary?.call?.zone, enabled = ready && !aimingLocked, showsLabels = false, cellHeight = (zoneWidth - 8.dp) / 3) { zone ->
                            choose(PitchHudSelection.Manual(selectedType ?: repertoire.firstOrNull() ?: PitchKind.FOUR_SEAM, zone, selectedIntent, selectedIntensity))
                        }
                    }
                    androidx.compose.foundation.Canvas(Modifier.align(Alignment.BottomCenter).size(30.dp, 14.dp).testTag("pitch.aimingPlate")) {
                        val plate = androidx.compose.ui.graphics.Path().apply { moveTo(0f,0f); lineTo(size.width,0f); lineTo(size.width,size.height*0.5f); lineTo(size.width*0.5f,size.height); lineTo(0f,size.height*0.5f); close() }
                        drawPath(plate, BaseballColors.fieldChalk)
                    }
                }
            }
            if (canFastForward && fatigue >= 80) TextButton(onClick = onFastForward, enabled = ready && !aimingLocked, modifier = Modifier.fillMaxWidth().testTag("pitch.exhaustionExit")) { Text("남은 등판 자동 진행") }
            PitchDeliveryControl(
                autoRelease = autoRelease,
                enabled = ready,
                holdPrompt = copy.resolve("compact.pitch.hold"),
                compact = true,
                onDeliver = onDeliver,
                onPressingChange = { aimingLocked = it },
                velocityTenthsKph = velocityTenthsKph,
                fatigue = fatigue,
                commandRating = commandRating,
                previousCommand = previousCommand,
                previousVelocity = previousVelocity,
                holdComparison = practice && previousCommand != null,
                reduceMotion = reduceMotion,
                hapticsEnabled = hapticsEnabled,
                soundEnabled = soundEnabled,
                tension = tension,
                disturbanceSeed = disturbanceSeed,
                adverseEpisode = adverseEpisode,
                pitchTypeLabel = PitchHudProjection.koreanLabel(selectedType ?: PitchKind.FOUR_SEAM),
            )
        }
    }
        }
    if (settingsOpen) {
        AlertDialog(
            modifier = Modifier.semantics { testTagsAsResourceId = true },
            onDismissRequest = { settingsOpen = false },
            title = { Text("조작 설정") },
            text = {
                Column(Modifier.fillMaxWidth().heightIn(max = 480.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(selectedPitchLine, style = MaterialTheme.typography.titleMedium)
                    if (selectedReason.isNotBlank()) Text(copy.sentences(selectedReason), verbatim = true, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.testTag("pitch.rationale"))
                    if (practice) Text(copy.resolve("feedback.practice.guide.$practiceStep"), verbatim = true, style = MaterialTheme.typography.bodyMedium)
                    lastPitchLine?.let { Text(it, style = MaterialTheme.typography.bodySmall, modifier = Modifier.testTag("pitch.lastPitch")) }
                    Text(when (selectedIntensity) {
                        PitchIntensity.CONTROLLED -> "제구 ↑ · 구속 ↓ · 체력 절약"
                        PitchIntensity.NORMAL -> "구속과 제구의 균형"
                        PitchIntensity.MAX_EFFORT -> "구속 ↑ · 제구 ↓ · 체력 소모 ↑"
                    }, style = MaterialTheme.typography.bodySmall)
                    PitchManualPlan(selectedType ?: repertoire.firstOrNull() ?: PitchKind.FOUR_SEAM, selectedZone, selectedIntent, selectedIntensity, ready && !aimingLocked) { type, zone, intent, intensity ->
                        choose(PitchHudSelection.Manual(type, zone, intent, intensity))
                    }
                    if (canFastForward && fatigue >= 80) Text("피로가 높아요. 남은 등판을 자동으로 진행할 수 있어요. 결과는 기록에 반영됩니다.")
                    if (canFastForward) TextButton(onClick = { settingsOpen = false; onFastForward() }, enabled = ready && !aimingLocked, modifier = Modifier.testTag("pitch.fastForward")) { Text(if (fatigue >= 80) "남은 등판 자동 진행" else "이 타석 자동 진행") }
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("빠른 진행")
                            Text("일반 투구만 자동으로 넘겨요. 연습·퍼펙트·다음 타자는 직접 확인해요.", style = MaterialTheme.typography.bodySmall)
                        }
                        Switch(fastResults, onCheckedChange = onFastResultsChange, modifier = Modifier.testTag("pitch.fastResults"))
                    }
                    onAutoReleaseChange?.let { change ->
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text("자동 릴리스")
                                Text("탭 한 번으로 던진다. 퍼펙트는 없다.", style = MaterialTheme.typography.bodySmall, color = BaseballColors.textTertiary)
                            }
                            Switch(autoRelease, onCheckedChange = change, modifier = Modifier.testTag("pitch.autoRelease.toggle"))
                        }
                    }
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text("진동", modifier = Modifier.weight(1f))
                        TextButton(onClick = { hapticTestAccepted = controlsView.pitchTouchFeedback(android.view.HapticFeedbackConstants.LONG_PRESS, hapticsEnabled) },
                            enabled = hapticsEnabled, modifier = Modifier.testTag("pitch.haptics.test")) { Text("진동 확인") }
                        Switch(hapticsEnabled, onCheckedChange = onHapticsChange, modifier = Modifier.testTag("pitch.haptics.toggle"))
                    }
                    if (hapticTestAccepted == false) Text("기기의 터치 진동 설정을 확인해 주세요.", style = MaterialTheme.typography.bodySmall)
                }
            },
            confirmButton = { TextButton(onClick = { settingsOpen = false }, modifier = Modifier.testTag("pitch.settings.close")) { Text("닫기") } },
        )
    }
}

@Composable
internal fun PitchCompactMatchup(
    batterName: String,
    batSide: BatSide,
    adaptationBandLabel: String,
    onExpand: () -> Unit,
) {
    val copy = rememberGameCopy()
    Surface(
        color = BaseballColors.surfaceRaised,
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(1.dp, BaseballColors.border.copy(alpha = 0.4f)),
        modifier = Modifier.fillMaxWidth().clickable(onClick = onExpand),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                listOf(copy.legacy(batterName),
                    copy.resolve(when (batSide) { BatSide.LEFT -> "content.batter-side.left.label"; BatSide.RIGHT -> "content.batter-side.right.label"; BatSide.SWITCH -> "content.batter-side.switch.label" })).filter { it.isNotBlank() }.joinToString(" · "),
                verbatim = true,
                modifier = Modifier.weight(1f),
                color = BaseballColors.textPrimary,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Text("타자 정보", color = BaseballColors.action, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
internal fun PitchManualPlan(
    repertoireType: PitchKind,
    selectedZone: PitchZone,
    selectedIntent: ZoneIntent,
    selectedIntensity: PitchIntensity,
    enabled: Boolean,
    onChange: (PitchKind, PitchZone, ZoneIntent, PitchIntensity) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            if (expanded) "노림 ▴" else "노림 ▾",
            style = MaterialTheme.typography.labelMedium,
            color = BaseballColors.milestone,
            modifier = Modifier.clickable { expanded = !expanded }.testTag("pitch.manualPlan"),
        )
        if (expanded) {
        AdaptiveActionRow(Modifier.fillMaxWidth()) {
            ZoneIntent.entries.forEach { intent ->
                val selected = intent == selectedIntent
                Surface(
                    color = if (selected) BaseballColors.action.copy(alpha = 0.14f) else BaseballColors.surfaceSoft,
                    shape = RoundedCornerShape(8.dp),
                    border = BorderStroke(if (selected) 1.5.dp else 1.dp, if (selected) BaseballColors.action else BaseballColors.border.copy(alpha = 0.5f)),
                    modifier = Modifier.heightIn(min = 48.dp).clickable(enabled = enabled) { onChange(repertoireType, selectedZone, intent, selectedIntensity) },
                ) {
                    Text(
                        PitchHudProjection.intentLabel(intent),
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 8.dp),
                        color = if (selected) BaseballColors.action else BaseballColors.textSecondary,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }

        }
    }
}

@Composable
internal fun PitchZoneGrid(
    selected: PitchZone,
    enabled: Boolean,
    showsLabels: Boolean = true,
    cellHeight: androidx.compose.ui.unit.Dp = 48.dp,
    recommended: PitchZone? = null,
    onSelect: (PitchZone) -> Unit,
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.fillMaxWidth()) {
        repeat(3) { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                repeat(3) { col ->
                    val zone = PitchZone(row, col)
                    val isSelected = zone == selected
                    val zoneName = listOf("높게", "가운데", "낮게")[row] + "\n" + listOf("왼쪽", "중앙", "오른쪽")[col]
                    Box(
                        modifier = Modifier
                            .weight(1f).heightIn(min = cellHeight.coerceAtLeast(48.dp)).testTag("pitch.zone.$row.$col")
                            .semantics { this.selected = isSelected; role = Role.RadioButton }.gameDescription(zoneName)
                            .clip(RoundedCornerShape(6.dp))
                            .background(if (isSelected) BaseballColors.action.copy(alpha = 0.28f) else BaseballColors.fieldNight.copy(alpha = 0.65f))
                            .border(if (isSelected) 1.5.dp else 1.dp, if (isSelected) BaseballColors.action else BaseballColors.fieldChalk.copy(alpha = 0.8f), RoundedCornerShape(6.dp))
                            .clickable(enabled = enabled) { onSelect(zone) },
                        contentAlignment = Alignment.Center,
                    ) {
                        if (showsLabels) Text(zoneName, style = MaterialTheme.typography.labelSmall, color = if (isSelected) BaseballColors.action else BaseballColors.textSecondary)
                        else if (isSelected) Box(Modifier.size(18.dp).border(2.dp, BaseballColors.action, CircleShape))
                        if (!showsLabels && zone == recommended) Box(Modifier.align(Alignment.TopEnd).padding(5.dp).size(6.dp)
                            .background(BaseballColors.milestone, CircleShape).testTag("pitch.recommended.$row.$col"))
                    }
                }
            }
        }
    }
}

@Composable
internal fun CatcherMetaChip(text: String, modifier: Modifier = Modifier) {
    Surface(
        color = BaseballColors.surfaceSoft,
        shape = RoundedCornerShape(8.dp),
        border = BorderStroke(1.dp, BaseballColors.fieldChalk.copy(alpha = 0.8f)),
        modifier = modifier,
    ) {
        Text(
            text = text,
            color = BaseballColors.textSecondary,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp),
        )
    }
}

@Composable
internal fun CatcherOptionSegment(
    label: String,
    selected: Boolean,
    enabled: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Surface(
        color = if (selected) BaseballColors.action.copy(alpha = 0.12f) else BaseballColors.surface,
        shape = RoundedCornerShape(10.dp),
        border = BorderStroke(if (selected) 2.dp else 1.dp, if (selected) BaseballColors.action else BaseballColors.border),
        modifier = modifier
            .heightIn(min = 48.dp)
            .clip(RoundedCornerShape(10.dp))
            .clickable(enabled = enabled, onClick = onClick)
            .semantics { role = Role.Button }.gameDescription("$label ${if (selected) "선택됨" else "선택 가능"}"),
    ) {
        Box(contentAlignment = Alignment.Center, modifier = Modifier.padding(horizontal = 4.dp, vertical = 6.dp)) {
            Text(
                text = label,
                color = if (selected) BaseballColors.action else BaseballColors.textPrimary,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

internal fun releaseTimingLabel(accuracy: Int, aimAccuracy: Int = 1_000): String = when {
    accuracy >= 975 -> "★ 퍼펙트 릴리스"
    accuracy >= com.solkim.baseball.application.PitchReleaseWindow.STABLE_RELEASE_THRESHOLD -> if (aimAccuracy < 650) "릴리스는 좋았다. 조준이 흔들렸다" else "릴리스 좋았다"
    accuracy >= 650 -> "타이밍이 살짝 어긋났다"
    else -> "타이밍을 놓쳤다"
}

@Composable
internal fun PitchEffortControl(
    selectedIntensity: PitchIntensity,
    recommendedIntensity: PitchIntensity?,
    enabled: Boolean,
    expectedVelocity: Int? = null,
    compact: Boolean = false,
    onChange: (PitchIntensity) -> Unit,
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val preferences = remember(context) { context.getSharedPreferences("pitch.ui", Context.MODE_PRIVATE) }
    var discovered by remember { mutableStateOf(preferences.getBoolean("effort.discovered", false)) }
    Column(Modifier.fillMaxWidth().testTag("pitch.effort"), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("힘 배분", style = MaterialTheme.typography.labelMedium, color = BaseballColors.textSecondary)
            expectedVelocity?.let { velocity ->
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    if (!compact) Text("예상 구속", style = MaterialTheme.typography.labelSmall, color = BaseballColors.textSecondary)
                    Text(String.format(java.util.Locale.US, "%.1f km/h", velocity / 10.0),
                        style = MaterialTheme.typography.labelSmall, color = BaseballColors.action, verbatim = true)
                }
            }
        }
        AdaptiveActionRow(Modifier.fillMaxWidth(), equalWidth = true) {
            PitchIntensity.entries.forEach { intensity ->
                val isSelected = selectedIntensity == intensity
                Surface(
                    color = if (isSelected) BaseballColors.action else BaseballColors.surfaceSoft,
                    shape = RoundedCornerShape(8.dp),
                    border = BorderStroke(1.dp, if (isSelected) BaseballColors.action else BaseballColors.border),
                    modifier = Modifier.heightIn(min = 48.dp).testTag("pitch.effort.${intensity.wire}")
                        .semantics { selected = isSelected; role = Role.RadioButton }
                        .clickable(enabled = enabled) {
                            discovered = true
                            preferences.edit().putBoolean("effort.discovered", true).apply()
                            onChange(intensity)
                        },
                ) {
                    Box(Modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 7.dp), contentAlignment = Alignment.Center) {
                        Text(when (intensity) {
                            PitchIntensity.CONTROLLED -> "제구 우선"
                            PitchIntensity.NORMAL -> "균형"
                            PitchIntensity.MAX_EFFORT -> "전력"
                        }, color = if (isSelected) BaseballColors.actionInk else BaseballColors.textPrimary,
                            style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold,
                            modifier = Modifier.testTag("pitch.effort.label.${intensity.wire}"))
                    }
                }
            }
        }
        if (!compact && recommendedIntensity != null) {
            val copy = rememberGameCopy()
            val label = when (recommendedIntensity) {
                PitchIntensity.CONTROLLED -> "제구 우선"
                PitchIntensity.NORMAL -> "균형"
                PitchIntensity.MAX_EFFORT -> "전력"
            }
            Text(copy.resolve("controls.pitch.recommended", GameCopyArgument.UserText(copy.legacy(label))),
                verbatim = true, style = MaterialTheme.typography.labelSmall, color = BaseballColors.textSecondary)
        }
        if (!compact) Text(when (selectedIntensity) {
            PitchIntensity.CONTROLLED -> "제구 ↑ · 구속 ↓ · 체력 절약"
            PitchIntensity.NORMAL -> "구속과 제구의 균형"
            PitchIntensity.MAX_EFFORT -> "구속 ↑ · 제구 ↓ · 체력 소모 ↑"
        }, style = MaterialTheme.typography.labelSmall, color = BaseballColors.textSecondary)
        if (!discovered && !compact) Text("던지기 전에 힘을 골라보세요.", style = MaterialTheme.typography.labelSmall, color = BaseballColors.action)
    }
}

internal fun practiceFeedback(delivery: PitchDelivery?): String = when {
    delivery == null -> "포수 사인을 보고 한 구 더 던져 보세요."
    delivery.releaseAccuracy < com.solkim.baseball.application.PitchReleaseWindow.STABLE_RELEASE_THRESHOLD && delivery.aimAccuracy < 650 -> "조준점을 가운데에 두고 초록 구간에서 놓아 보세요."
    delivery.aimAccuracy < 650 -> "타이밍은 좋아요. 누른 채 손가락을 움직여 조준점을 가운데로 맞춰 보세요."
    delivery.releaseAccuracy < com.solkim.baseball.application.PitchReleaseWindow.STABLE_RELEASE_THRESHOLD -> "조준은 좋아요. 초록 구간에서 손을 놓아 보세요."
    else -> "타이밍과 조준이 모두 좋았어요."
}

@Composable
internal fun PitchPlateFeedback(xMm: Int, yMm: Int, target: PitchZone?) {
    androidx.compose.foundation.Canvas(Modifier.size(84.dp).testTag("pitch.plateDiagram").gameDescription("공이 지나간 곳")) {
        val range = maxOf(750f, kotlin.math.abs(xMm.toFloat()) + 100f, kotlin.math.abs(yMm.toFloat()) + 100f)
        val scale = size.minDimension / (range * 2)
        val left = center.x - 500 * scale
        val top = center.y - 500 * scale
        val unit = 1000 * scale / 3
        target?.let { drawRect(BaseballColors.actionSoft,
            androidx.compose.ui.geometry.Offset(left + it.column * unit, top + it.row * unit), androidx.compose.ui.geometry.Size(unit, unit)) }
        for (i in 0..3) {
            drawLine(BaseballColors.border, androidx.compose.ui.geometry.Offset(left + i * unit, top), androidx.compose.ui.geometry.Offset(left + i * unit, top + unit * 3), 1.dp.toPx())
            drawLine(BaseballColors.border, androidx.compose.ui.geometry.Offset(left, top + i * unit), androidx.compose.ui.geometry.Offset(left + unit * 3, top + i * unit), 1.dp.toPx())
        }
        drawCircle(BaseballColors.action, 4.dp.toPx(), androidx.compose.ui.geometry.Offset(center.x + xMm * scale, center.y - yMm * scale))
    }
}
