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
@OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)
internal fun ColumnScope.CareerSetupFields(
    state: GameAggregateState,
    commandContext: ScreenCommandContext,
    model: ScreenModel,
    onAction: (ScreenUiAction) -> Unit,
    busy: Boolean = false,
) {
    val gameCopy = rememberGameCopy()
    val setupAction = model.actions.single { it.id == "startHighSchool" }
    val secondLife = CareerUiRules.archiveSize(state) >= 1 || state.meta.retiredProCareers.isNotEmpty()
    val lastStep = if (secondLife) 3 else 1
    // The reborn player keeps their name unless they type a new one.
    val carriedName = if (secondLife && state.meta.seedChallenge == null)
        CareerUiRules.archive(state).lastOrNull()?.playerName?.takeIf { it.isNotBlank() } ?: state.meta.retiredProCareers.lastOrNull()?.identityName?.takeIf { it.isNotBlank() }
        else null
    var step by rememberSaveable(model.id.wire + ":step") { mutableStateOf(0) }
    var name by rememberSaveable(model.id.wire) { mutableStateOf(carriedName.orEmpty()) }
    var region by rememberSaveable(model.id.wire + ":region") {
        mutableStateOf(HighSchoolDisplayRules.regions.first())
    }
    var presetId by rememberSaveable(model.id.wire + ":preset") {
        mutableStateOf(HighSchoolDisplayRules.presets.first().id)
    }
    var throwingHand by rememberSaveable(model.id.wire + ":hand") { mutableStateOf("right") }
    var selectedKarmas by rememberSaveable(model.id.wire + ":karma") { mutableStateOf("") }
    var regionMenuExpanded by rememberSaveable { mutableStateOf(false) }
    var primaryPitch by rememberSaveable { mutableStateOf(SetupRepertoire.primary(presetId).wire) }
    var learningPitch by rememberSaveable { mutableStateOf(SetupRepertoire.learning(presetId).wire) }
    var harshness by rememberSaveable { mutableStateOf("standard") }
    var soulDomain by rememberSaveable { mutableStateOf("technique") }
    var selectedBoostIds by rememberSaveable { mutableStateOf("") }
    val boosts = SetupSoulBoost.entries.filter { it.wire in selectedBoostIds.split(',') }
    val soulBalance = CareerUiRules.soulPoints(state)
    val boostCost = boosts.sumOf { it.cost }
    val finalName = name.trim().ifBlank { when (gameCopy.language) {
        com.solkim.baseball.application.GameLanguage.ENGLISH -> "Min Seo-jun"
        com.solkim.baseball.application.GameLanguage.JAPANESE -> "ミン・ソジュン"
        else -> "민서준"
    } }
    val karmas = selectedKarmas.split(',').filter { it.isNotBlank() }.toSet()

    Text("${step + 1}/${lastStep + 1}", style = MaterialTheme.typography.labelMedium, color = BaseballColors.textSecondary)
    Text(setupStepTitle(step), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
    Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
    when (step) {
        0 -> {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp), modifier = Modifier.fillMaxWidth()) {
                PlayerPortrait(seed = (if (secondLife && state.meta.seedChallenge == null) lineagePortraitSeed(state) else null) ?: finalName, stage = PlayerStage.FRESHMAN, width = 72.dp, modifier = Modifier.testTag("setup.portrait"))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(finalName, verbatim = true, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Text(if (carriedName != null && finalName == carriedName) "지난 생의 그 얼굴 그대로." else if (carriedName != null) "이름은 달라도 얼굴은 이어진다. 기억을 이어받은 다른 선수." else "이름을 바꾸면 얼굴도 달라져요",
                        style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
                }
            }
            OutlinedTextField(
                value = name,
                onValueChange = { name = it.take(12) },
                label = { Text("선수 이름") },
                supportingText = { Text("비워 두면 민서준으로 시작합니다") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth().testTag("setup.name"),
            )
            Text("지역", style = MaterialTheme.typography.titleSmall)
            Box {
                OutlinedButton(
                    onClick = { regionMenuExpanded = true },
                    modifier = Modifier
                        .fillMaxWidth().heightIn(min = 48.dp).testTag("setup.region")
                        .gameDescription("지역 선택, 현재 $region"),
                ) { Text(region); Spacer(Modifier.weight(1f)); Text("⌄") }
                DropdownMenu(
                    expanded = regionMenuExpanded,
                    onDismissRequest = { regionMenuExpanded = false },
                    modifier = Modifier.semantics { testTagsAsResourceId = true },
                ) {
                    HighSchoolDisplayRules.regions.forEach { option ->
                        DropdownMenuItem(
                            text = { Text(option) },
                            modifier = Modifier.testTag("setup.region.$option"),
                            onClick = {
                                region = option
                                regionMenuExpanded = false
                            },
                        )
                    }
                }
            }
        }
        1 -> {
            Text("투구 손", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                SetupSelectionButton(selected = throwingHand == "right", onClick = { throwingHand = "right" }, modifier = Modifier.weight(1f).testTag("setup.hand.right")) {
                    Text("우투", fontWeight = FontWeight.Bold)
                }
                SetupSelectionButton(selected = throwingHand == "left", onClick = { throwingHand = "left" }, modifier = Modifier.weight(1f).testTag("setup.hand.left")) {
                    Text("좌투", fontWeight = FontWeight.Bold)
                }
            }
            Text("성장 방식", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
            HighSchoolDisplayRules.presets.forEach { preset ->
                val selected = preset.id == presetId
                SetupSelectionButton(
                    selected = selected,
                    onClick = {
                        presetId = preset.id
                        primaryPitch = SetupRepertoire.primary(preset.id).wire
                        learningPitch = SetupRepertoire.learning(preset.id).wire
                    },
                    modifier = Modifier.fillMaxWidth()
                        .heightIn(min = 48.dp)
                        .testTag("setup.preset.${preset.id}")
                        .gameDescription(gameCopy.resolve("android.setup.preset-description",
                            com.solkim.baseball.application.GameCopyArgument.UserText(gameCopy.legacy(presetTitle(preset.id))),
                            com.solkim.baseball.application.GameCopyArgument.Whole(com.solkim.baseball.application.AbilityDisplayScale.rating(preset.baseStuff).toLong()),
                            com.solkim.baseball.application.GameCopyArgument.Whole(com.solkim.baseball.application.AbilityDisplayScale.rating(preset.baseCommand).toLong()),
                            com.solkim.baseball.application.GameCopyArgument.Whole(com.solkim.baseball.application.AbilityDisplayScale.rating(preset.baseMovement).toLong()),
                            com.solkim.baseball.application.GameCopyArgument.Whole(com.solkim.baseball.application.AbilityDisplayScale.rating(preset.baseStamina).toLong())) +
                            if (selected) " · " + gameCopy.legacy("선택됨") else ""),
                ) {
                    Text(presetTitle(preset.id), fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal)
                }
            }
            val chosenPreset = HighSchoolDisplayRules.presets.single { it.id == presetId }
            Text("선택한 유형의 기본 능력", style = MaterialTheme.typography.labelMedium)
            Column(Modifier.testTag("setup.preset.stats")) {
                CareerStatTiles(listOf("구위" to "${com.solkim.baseball.application.AbilityDisplayScale.rating(chosenPreset.baseStuff)} / 100", "제구" to "${com.solkim.baseball.application.AbilityDisplayScale.rating(chosenPreset.baseCommand)} / 100",
                    "무브먼트" to "${com.solkim.baseball.application.AbilityDisplayScale.rating(chosenPreset.baseMovement)} / 100", "체력" to "${com.solkim.baseball.application.AbilityDisplayScale.rating(chosenPreset.baseStamina)} / 100"))
            }
        }
        2 -> {
            Text(presetTitle(presetId), fontWeight = FontWeight.SemiBold)
            Text("주 구종 ${setupPitchLabel(SetupPitch.entries.single { it.wire == primaryPitch })} · 배우는 구종 ${setupPitchLabel(SetupPitch.entries.single { it.wire == learningPitch })}", style = MaterialTheme.typography.bodyLarge)
            var primaryReset by remember { mutableStateOf(false) }
            if (primaryReset) Text("배우는 구종과 겹쳐서 주 구종을 포심으로 되돌렸다.", style = MaterialTheme.typography.bodySmall, color = BaseballColors.warning)
            Text("배우는 구종", style = MaterialTheme.typography.titleSmall)
            Text("3년 동안 익혀서 완성하는 공. 처음엔 제구가 흔들린다.", style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
            AdaptiveActionRow(Modifier.fillMaxWidth(), equalWidth = true) {
                SetupPitch.entries.filter { it != SetupPitch.FOUR_SEAM }.forEach { pitch ->
                    SetupSelectionButton(selected = learningPitch == pitch.wire,
                        onClick = { learningPitch = pitch.wire; primaryReset = primaryPitch == learningPitch; if (primaryPitch == learningPitch) primaryPitch = "four_seam" },
                        modifier = Modifier.testTag("setup.learning.${pitch.wire}")) { Text(setupPitchLabel(pitch)) }
                }
            }
            Text("주 구종", style = MaterialTheme.typography.titleSmall)
            Text("포수가 가장 먼저 내는 사인. 첫 공부터 믿고 던질 수 있다.", style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
            AdaptiveActionRow(Modifier.fillMaxWidth(), equalWidth = true) {
                SetupPitch.entries.filter { it.wire != learningPitch }.forEach { pitch ->
                    SetupSelectionButton(selected = primaryPitch == pitch.wire, onClick = { primaryPitch = pitch.wire },
                        modifier = Modifier.testTag("setup.primary.${pitch.wire}")) { Text(setupPitchLabel(pitch)) }
                }
            }
        }
        else -> {
            Text("이번 생의 난이도", style = MaterialTheme.typography.titleSmall)
            listOf(Triple("relaxed", "부드럽게", "라이벌이 약하고 지명선이 낮다."), Triple("standard", "표준", "기본."), Triple("challenging", "혹독하게", "라이벌이 강하고 지명선이 높다. 야구혼을 더 받는다.")).forEach { (id, label, detail) ->
                SetupOption(label, detail, harshness == id) { harshness = id }
            }
            Text("야구혼이 먼저 키우는 것", style = MaterialTheme.typography.titleSmall)
            Text("지난 생이 남긴 야구혼을 어느 능력에 먼저 쓸지.", style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
            listOf(Triple("body", "몸 · 구위", "공에 힘이 실린 채 시작한다."), Triple("technique", "기술 · 제구", "초록 구간이 넓은 채 시작한다."), Triple("game", "경기 · 운영", "타자를 읽는 눈을 갖고 시작한다.")).forEach { (id, label, detail) ->
                SetupOption(label, detail, soulDomain == id) { soulDomain = id }
            }
            Text("야구혼 $soulBalance · 쓰는 중 $boostCost", style = MaterialTheme.typography.titleSmall)
            Text("야구혼을 써서 이번 생의 출발을 바꾼다.", style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
            SetupSoulBoost.entries.forEach { boost ->
                val selected = boost in boosts
                SetupOption(setupBoostLabel(boost), gameCopy.resolve("controls.setup.boost-cost", GameCopyArgument.Whole(boost.cost.toLong())) + " · " + setupBoostDetail(boost), selected, enabled = selected || boostCost + boost.cost <= soulBalance) {
                    selectedBoostIds = (if (selected) boosts - boost else boosts + boost).joinToString(",") { it.wire }
                }
            }
            Text("핸디캡", style = MaterialTheme.typography.titleSmall)
            Text("최대 둘. 어려워지는 대신 3년을 마치면 야구혼을 더 받는다.", style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
            listOf(
                Triple("unknown_land", "낯선 땅", "연고 밖에서 시작한다. 관계가 늦게 붙는다."),
                Triple("stubborn_coach", "고집 센 코치", "감독이 내 말을 잘 안 듣는다. 믿음이 더디게 쌓인다."),
                Triple("single_weapon", "한 가지 무기", "가장 강한 능력 하나만 빠르게 큰다. 나머지는 더디다."),
                Triple("genius_generation", "천재들의 기수", "같은 해 라이벌들이 유난히 강하다."),
            ).forEach { (id, label, detail) ->
                val selected = id in karmas
                SetupOption(label, detail, selected) {
                    val next = karmas.toMutableSet()
                    if (selected) next.remove(id) else if (next.size < 2) next.add(id)
                    selectedKarmas = next.joinToString(",")
                }
            }
        }
    }
    }
    val canAdvance = when (step) {
        0 -> region in HighSchoolDisplayRules.regions
        else -> true
    }
    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (step > 0) {
            OutlinedButton(onClick = { step -= 1 }, modifier = Modifier.heightIn(min = 48.dp)) {
                Text("이전")
            }
        }
        if (step < lastStep) {
            Button(
                onClick = { if (canAdvance) step += 1 },
                enabled = canAdvance && !busy,
                modifier = Modifier.heightIn(min = 48.dp).testTag("setup.next"),
            ) { Text("다음") }
        } else {
            val valid = setupAction.enabled && boostCost <= soulBalance && region in HighSchoolDisplayRules.regions
            Button(
                onClick = {
                    val command = ScreenPayloads.startHighSchool(
                        state,
                        finalName,
                        region,
                        presetId,
                        commandContext,
                        throwingHand,
                        karmas.toList(),
                        CareerUiRules.archiveSize(state) + 1,
                        difficulty = SetupDifficulty(careerHarshness = harshness),
                        soulDomain = SetupSoulDomain.entries.single { it.wire == soulDomain },
                        soulBoosts = boosts,
                        primaryPitch = SetupPitch.entries.single { it.wire == primaryPitch },
                        learningPitch = SetupPitch.entries.single { it.wire == learningPitch },
                    )
                    val payloads = ScreenPayloads.batch(state, model.id, setupAction.id, listOf(command))
                    onAction(ScreenUiAction(model.id, setupAction.id, payloads))
                },
                enabled = valid && !busy,
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("setup.confirm"),
            ) { Text("시작하기") }
        }
    }
}

private fun setupStepTitle(step: Int): String = when (step) {
    0 -> "어떤 이름으로 불릴까요?"
    1 -> "어떤 투수가 되고 싶나요?"
    2 -> "어떤 공으로 승부할까요?"
    else -> "이번 생에는 무엇을 이어받을까요?"
}

@Composable
internal fun SetupSelectionButton(
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    content: @Composable RowScope.() -> Unit,
) {
    OutlinedButton(
        onClick = onClick,
        enabled = enabled,
        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 8.dp),
        modifier = modifier.heightIn(min = 48.dp).semantics { this.selected = selected },
        colors = ButtonDefaults.outlinedButtonColors(
            containerColor = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surface,
            contentColor = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface,
        ),
        border = BorderStroke(if (selected) 2.dp else 1.dp,
            if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline),
    ) {
        Box(Modifier.width(16.dp), contentAlignment = Alignment.Center) {
            if (selected) Text("✓", verbatim = true, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.width(4.dp))
        content()
    }
}

@Composable
private fun SetupOption(label: String, detail: String, selected: Boolean, enabled: Boolean = true, onClick: () -> Unit) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        SetupSelectionButton(selected = selected, onClick = onClick, enabled = enabled, modifier = Modifier.fillMaxWidth()) {
            Text(label, fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal)
        }
        if (detail.isNotBlank()) Text(detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

private fun setupBoostDetail(boost: SetupSoulBoost): String = when (boost) {
    SetupSoulBoost.TALENT_BREAK -> "가장 낮은 재능의 벽을 한 단계 올린다."
    SetupSoulBoost.EXTRA_MEMORY -> "지난 생의 기억을 하나 더 가져온다."
    SetupSoulBoost.HEAD_START -> "시작 능력에 5를 얹는다."
    SetupSoulBoost.TRAINING_RHYTHM -> "훈련 한 번의 효과가 커진다."
}

private fun presetTitle(id: String): String = HighSchoolDisplayRules.presetTitle(id)

private fun setupPitchLabel(pitch: SetupPitch): String = when (pitch) {
    SetupPitch.FOUR_SEAM -> "포심"
    SetupPitch.SLIDER -> "슬라이더"
    SetupPitch.CURVEBALL -> "커브"
    SetupPitch.CHANGEUP -> "체인지업"
}
private fun setupBoostLabel(boost: SetupSoulBoost): String = when (boost) {
    SetupSoulBoost.TALENT_BREAK -> "재능의 벽 확장"
    SetupSoulBoost.EXTRA_MEMORY -> "기억 한 자리 추가"
    SetupSoulBoost.HEAD_START -> "시작 능력 보너스"
    SetupSoulBoost.TRAINING_RHYTHM -> "훈련 리듬"
}
