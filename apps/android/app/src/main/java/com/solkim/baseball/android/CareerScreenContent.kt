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
internal fun CareerScreenContent(
    state: GameAggregateState,
    busy: Boolean,
    commandContext: ScreenCommandContext,
    model: ScreenModel,
    onAction: (ScreenUiAction) -> Unit,
    platformState: PlatformUiState,
    onPlatformAction: (PlatformUiAction) -> Unit,
    onViewportExposure: (ViewportExposure) -> Unit,
) {
    val archiveIds = CareerUiRules.archive(state).map { it.careerId }
    var selectedLifeCardCareerId by rememberSaveable(archiveIds.joinToString("|")) {
        mutableStateOf(archiveIds.lastOrNull())
    }
    val selectedLifeCardId = selectedLifeCardCareerId?.takeIf { it in archiveIds } ?: archiveIds.lastOrNull()

    Card(
        modifier = Modifier
            .fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            if (model.id == ScreenId.P002_SETUP) {
                CareerSetupFields(state, commandContext, model, onAction)
            } else {
                when (model.id) {
                    ScreenId.P014_RUN_RECAP, ScreenId.P015_REBIRTH -> CoreRebirthChoices(state, model, onAction, onViewportExposure)
                    ScreenId.P028_LIFECARD -> PlayerAlbumView(state, showTitle = false)
                    ScreenId.P027_SETTINGS -> { CareerBackupControls(state); CareerSections(model.sections); CareerActions(model, onAction) }
                    ScreenId.P009_AWAKENING -> AwakeningTreeView(state, model, onAction)
                    ScreenId.P005_SCHOOL_SELECTION -> CareerSchoolChoices(state, model, onAction)
                    ScreenId.P016_PRO_CONTRACT -> if (model.actions.any { it.id.startsWith("acceptOffer:") }) CareerContractChoices(model, onAction, busy) else { CareerSections(model.sections); CareerActions(model, onAction) }
                    ScreenId.P013_DRAFT -> { CareerDraftReveal(state, model); CareerActions(model, onAction) }
                    ScreenId.P008_IMPORTANT_GAME, ScreenId.P018_PRO_IMPORTANT_GAME -> OutingBriefingView(state, model, commandContext, onAction)
                    ScreenId.P017_PRO_WEEK ->
                        CareerDecisionChoices(state, model, onAction, busy)
                    in compactCareerScreens -> {
                        CompactCareerOverview(state, model, onAction)
                        if (model.id !in setOf(ScreenId.P022_PRO_LEGACY, ScreenId.P026_ACHIEVEMENTS)) CareerActions(model, onAction)
                    }
                    else -> {
                        CareerSections(model.sections)
                        CareerActions(model, onAction)
                    }
                }
                if (model.id !in setOf(ScreenId.P028_LIFECARD, ScreenId.P007_RELATIONSHIP, ScreenId.P008_IMPORTANT_GAME, ScreenId.P017_PRO_WEEK, ScreenId.P018_PRO_IMPORTANT_GAME)) {
                var showsDetails by remember(model.id) { mutableStateOf(false) }
                TextButton(onClick = { showsDetails = !showsDetails }, modifier = Modifier.testTag("career.storyDetails")) {
                    Text(rememberGameCopy().resolve("mobile.core.career-details"), verbatim = true)
                }
                if (showsDetails) {
                if (model.id == ScreenId.P015_REBIRTH) CareerSections(model.sections.filterNot { it.id in setOf("professional-status", "rebirth") })
                else CareerShareButton(state, model)
                ViewportCards(state, commandContext, model, platformState, selectedLifeCardId, onViewportExposure)
                PlatformSurface(
                    state = state,
                    model = model,
                    platformState = platformState,
                    selectedLifeCardCareerId = selectedLifeCardId,
                    onSelectedLifeCardCareerIdChanged = { selectedLifeCardCareerId = it },
                    onAction = onPlatformAction,
                    onViewportExposure = onViewportExposure,
                )                }
                }

            }
        }
    }
}

@Composable
private fun CoreRebirthChoices(state: GameAggregateState, model: ScreenModel, onAction: (ScreenUiAction) -> Unit, onExposed: (ViewportExposure) -> Unit) {
    val copy = rememberGameCopy()
    val enteringPro = com.solkim.baseball.application.ProfessionalStatusPresentation.canEnterPro(state)
    val draftSummary = !CareerUiRules.hasPro(state) && CareerUiRules.hasDraftResult(state) && model.id in setOf(ScreenId.P014_RUN_RECAP, ScreenId.P015_REBIRTH)
    if (draftSummary) DraftJourneySummary(state)
    else model.sections.firstOrNull { it.id == "professional-status" }?.let { CareerSection(it, it.rows.size) }
    if (!enteringPro && model.id == ScreenId.P015_REBIRTH) CareerMemorySummary(state)
    if (enteringPro && model.id == ScreenId.P015_REBIRTH) {
        model.actions.firstOrNull { it.id == "startLinked" && it.enabled }?.let { CareerActionButton(model.id, it, onAction) }
        val alternatives = model.actions.filter { it.enabled && it.id in setOf("quickRebirth", "customizeRebirth", "finalizeArchive") }
        if (alternatives.isNotEmpty()) CareerDisclosure("이번 생을 마무리하는 선택", "career.otherPath") {
            val nextLife = alternatives.firstOrNull { it.id == "quickRebirth" }
            var preview by remember(nextLife) { mutableStateOf<RebirthStartPreview?>(null) }
            LaunchedEffect(nextLife) { preview = withContext(Dispatchers.Default) { RebirthStartPreview.resolve(state, nextLife) } }
            if (model.actions.none { it.id.startsWith("rebirthPath:") && it.enabled }) preview?.let { CoreRebirthStartComparison(it) }
            RebirthPathPicker(state, model, onAction)
            alternatives.filter { it.id != "quickRebirth" || model.actions.none { path -> path.id.startsWith("rebirthPath:") && path.enabled } }.forEach { CareerActionButton(model.id, it, onAction, showDescription = true) }
        }
        return
    }
    val quickPath = model.id == ScreenId.P015_REBIRTH && !enteringPro && model.actions.any { it.id == "quickRebirth" && it.enabled }
    if (quickPath) {
        val run = CareerUiRules.schoolFacts(state)
        val name = run?.playerName?.takeIf { it.isNotBlank() }
        if (name != null) {
            Row(Modifier.fillMaxWidth().testTag("rebirth.identity"), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                PlayerPortrait(seed = playerPortraitSeed(state) ?: name, stage = if (CareerUiRules.hasPro(state)) PlayerStage.PRO else PlayerStage.ACE, width = 56.dp)
                Text("→", verbatim = true, style = MaterialTheme.typography.headlineSmall, color = BaseballColors.action)
                PlayerPortrait(seed = playerPortraitSeed(state) ?: name, stage = PlayerStage.FRESHMAN, width = 56.dp)
                Column(Modifier.weight(1f)) {
                    Text(name, verbatim = true, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Text("같은 이름, 같은 얼굴. 1학년부터 다시.", style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
                }
            }
        }
        lineageLine(state)?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = BaseballColors.textTertiary, modifier = Modifier.testTag("rebirth.lineage")) }
        model.sections.firstOrNull { it.id == "rebirth" }?.rows?.firstOrNull()?.let { inherited ->
            Text(copy.resolve("mobile.core.inherited"), verbatim = true, style = MaterialTheme.typography.labelLarge, color = BaseballColors.textSecondary)
            Text(inherited.value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            if (inherited.detail.isNotBlank()) Text(inherited.detail, style = MaterialTheme.typography.bodyMedium, color = BaseballColors.milestone)
        }
        model.sections.firstOrNull { it.id == "rebirth" }?.rows?.getOrNull(1)?.takeIf { it.value.toIntOrNull()?.let { count -> count > 0 } == true }?.let {
            Text("${it.label} ${it.value}", style = MaterialTheme.typography.bodySmall)
        }
        if (run != null && CareerUiRules.archive(state).any { it.careerId == run.careerId }) {
            CareerDisclosure("지난 생의 카드", "rebirth.previousLife") {
                LifeCardVisual(state = state, careerId = run.careerId)
                CareerShareButton(state, model)
            }
        }
    } else if (model.id == ScreenId.P014_RUN_RECAP) CompactLifeRecap(state, model)
    else model.sections.filter { it.id != "professional-status" && (!enteringPro || it.id != "rebirth") }.forEach { CareerSection(it, 1) }
    val actions = model.actions.filter { action ->
        action.enabled && action.id !in setOf("confirmRecap", "confirmDraftResult") &&
            (action.id != "prepareLegacy" || (CareerUiRules.selectedSignatureLegacyId(state) == null && model.actions.none { it.enabled && it.id.startsWith("selectLegacy:") }))
    }
    RebirthPathPicker(state, model, onAction)
    val primary = actions.firstOrNull { it.id == "quickRebirth" }
        ?: actions.firstOrNull { it.id == "finalizeArchive" }
        ?: actions.firstOrNull { it.id == "prepareLegacy" }
    val legacyActions = actions.filter { it.id.startsWith("selectLegacy:") }
    val run = CareerUiRules.schoolFacts(state)
    if (legacyActions.isNotEmpty() && run != null) {
        ViewportExposureBox(exposure = ViewportExposure(
            eventName = "signature_legacy_options_seen", scope = "legacy-options:${run.careerId}",
            properties = listOf("life_number" to run.lifeNumber.toString(),
                "drafted" to (run.drafted == true).toString(),
                "includes_pro_career" to (CareerUiRules.hasProCareerStats(state)).toString(),
                "option_ids" to run.legacyOptions.joinToString(","))), onExposed = onExposed) {
            CareerLegacyPicker(model, legacyActions, onAction)
        }
    }
    val previewKey = remember(primary) { primary?.payloads?.singleOrNull()?.payloadSha256 }
    var preview by remember(previewKey) { mutableStateOf<RebirthStartPreview?>(null) }
    LaunchedEffect(previewKey) {
        preview = withContext(Dispatchers.Default) { RebirthStartPreview.resolve(state, primary) }
    }
    if (model.actions.none { it.id.startsWith("rebirthPath:") && it.enabled }) preview?.let { CoreRebirthStartComparison(it) }
    primary?.takeIf { it.id != "quickRebirth" }?.let { CareerActionButton(model.id, it, onAction) }
    actions.filter { it != primary && !it.id.startsWith("selectLegacy:") && !it.id.startsWith("rebirthPath:") }.forEach { action ->
        OutlinedButton(onClick = { onAction(ScreenUiAction(model.id, action.id, action.payloads)) },
            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("action.${action.id}")) {
            Text(action.label)
        }
        if (action.destructive) Text(action.description, color = MaterialTheme.colorScheme.error)
    }
}

@Composable
internal fun RebirthPathPicker(state: GameAggregateState, model: ScreenModel, onAction: (ScreenUiAction) -> Unit) {
    val actions = model.actions.filter { it.enabled }
    val newPaths = actions.filter { it.id.startsWith("rebirthPath:") }
    if (newPaths.isNotEmpty()) {
        Text("이번 생에는 다른 야구", style = MaterialTheme.typography.titleMedium)
        state.meta.retiredProCareers.lastOrNull()?.let { previous ->
            val rows = previous.careerStats
            if (rows.isNotEmpty() && rows.all { it.completeGames != null && it.shutouts != null }) Text("지난 생의 기록 · 완투 ${rows.sumOf { it.completeGames ?: 0 }}회 · 완봉승 ${rows.sumOf { it.shutouts ?: 0 }}회", style = MaterialTheme.typography.labelSmall)
            else Text("지난 생의 기록은 앨범에 남아요.", style = MaterialTheme.typography.labelSmall)
        }
        var selectedPath by rememberSaveable(CareerUiRules.highSchoolCareerId(state)) { mutableStateOf(newPaths.first().id) }
        val chosen = newPaths.firstOrNull { it.id == selectedPath } ?: newPaths.first()
        AdaptiveActionRow(Modifier.fillMaxWidth(), equalWidth = true) {
            newPaths.forEach { path ->
                FilterChip(selected = chosen.id == path.id, onClick = { selectedPath = path.id },
                    colors = FilterChipDefaults.filterChipColors(selectedContainerColor = BaseballColors.action, selectedLabelColor = BaseballColors.actionInk),
                    label = { Text(when(path.id.substringAfter(':')) { "endurance" -> "선발"; "closer" -> "마무리"; else -> "제구형" }) },
                    modifier = Modifier.testTag("rebirth.path.${path.id.substringAfter(':')}"))
            }
        }
        Text(chosen.label, color = BaseballColors.milestone, style = MaterialTheme.typography.titleSmall)
        Text(chosen.description, style = MaterialTheme.typography.bodySmall)
        RebirthAbilityPreview(state, chosen)
        Text("기록과 유산을 이어받고 학교 선택부터", style = MaterialTheme.typography.labelSmall)
        Button(onClick = { onAction(ScreenUiAction(model.id, chosen.id, chosen.payloads)) }, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("rebirth.path.start")) { Text("이 길로 시작") }
        actions.firstOrNull { it.id == "quickRebirth" }?.let { same ->
            TextButton(onClick = { onAction(ScreenUiAction(model.id, same.id, same.payloads)) }, modifier = Modifier.testTag("action.quickRebirth")) { Text("이전 방식으로 이어가기") }
        }
    }
}

@Composable
private fun CareerSections(sections: List<com.solkim.baseball.application.ScreenSection>) {
    sections.forEach { section ->
        Text(section.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.secondary, modifier = Modifier.semantics { heading() })
        section.rows.forEach { row -> CareerReadOnlyRow(row.label, row.value, row.detail) }
    }
}

/** Contract market: one team at a time. The goal is the second question, not a multiplier on the button list. */
@Composable
private fun CareerContractChoices(model: ScreenModel, onAction: (ScreenUiAction) -> Unit, busy: Boolean = false) {
    var selectedGoal by rememberSaveable(model.id.wire) { mutableStateOf<String?>(null) }
    var submitted by remember(model) { mutableStateOf(false) }
    LaunchedEffect(busy) { if (!busy) submitted = false }
    val offers = model.actions.filter { it.id.startsWith("acceptOffer:") }.groupBy { it.id.split(":")[1] }
    model.sections.firstOrNull { it.id == "professional-status" }?.let { CareerSection(it, it.rows.size) }
    val market = model.sections.firstOrNull { it.id == "pro-contract-market" }
    var selectedOffer by rememberSaveable(model.id.wire) { mutableStateOf<String?>(null) }
    market?.let { Text(it.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.secondary) }
    offers.entries.forEachIndexed { index, (offerId, actions) ->
        val teamName = actions.first().label.substringBefore(" · ")
        val row = market?.rows?.getOrNull(index)
        val selected = selectedOffer == offerId
        OutlinedButton(onClick = { selectedOffer = if (selected) null else offerId; selectedGoal = null }, enabled = !busy && !submitted && actions.any { it.enabled },
            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("contract.offer.$offerId"),
            border = BorderStroke(if (selected) 2.dp else 1.dp, if (selected) BaseballColors.action else BaseballColors.border)) {
            Text(teamName, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold)
        }
        row?.let { Text(it.value, verbatim = true, style = MaterialTheme.typography.bodyMedium) }
        if (selected) row?.let { if (it.detail.isNotBlank()) Text(it.detail, verbatim = true, style = MaterialTheme.typography.bodyMedium, color = BaseballColors.textSecondary) }
        if (selected) {
            Text("이 계약에 걸 목표", style = MaterialTheme.typography.labelLarge, color = BaseballColors.textSecondary)
            actions.forEach { action ->
                FilterChip(selected = selectedGoal == action.id, onClick = { selectedGoal = action.id }, enabled = action.enabled && !submitted && !busy,
                    label = { Text(action.label.substringAfter(" · "), verbatim = true) }, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("contract.goal.${action.id}"))
                Text(action.description, verbatim = true, style = MaterialTheme.typography.bodySmall)
            }
        }
    }
    val chosen = model.actions.firstOrNull { it.id == selectedGoal && it.id.split(":").getOrNull(1) == selectedOffer }
    if (selectedOffer != null) {
        Text("계약하면 구단과 목표가 확정됩니다.")
        Button(onClick = { if (!submitted && chosen != null) { submitted = true; onAction(ScreenUiAction(model.id, chosen.id, chosen.payloads)) } },
            enabled = chosen?.enabled == true && !submitted && !busy, modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp).testTag("contract.confirm")) { Text("이 조건으로 계약하기") }
    }
    if (selectedOffer == null) Text("팀을 먼저 고른다. 목표는 그다음.", style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
    model.actions.filter { !it.id.startsWith("acceptOffer:") && it.enabled }.forEach { CareerActionButton(model.id, it, onAction) }
}

/** Draft day. Before the call: the player's face and one sentence. After: the verdict, big. */
@Composable
private fun CareerDraftReveal(state: GameAggregateState, model: ScreenModel) {
    val facts = CareerUiRules.schoolFacts(state)
    val name = facts?.playerName.orEmpty()
    val first = model.sections.firstOrNull { it.id == "draft" }?.rows?.firstOrNull()
    val drafted = facts?.drafted == true
    val revealed = facts?.drafted != null
    Column(Modifier.fillMaxWidth().testTag("draft.reveal"), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        if (name.isNotBlank()) PlayerPortrait(seed = name, stage = PlayerStage.ACE, width = 96.dp)
        Text(name, verbatim = true, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        first?.let {
            Text(if (revealed) it.label else it.value, verbatim = true, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Black,
                color = if (!revealed) BaseballColors.textPrimary else if (drafted) BaseballColors.action else BaseballColors.textSecondary)
            Text(if (revealed) it.value else it.detail, verbatim = true, style = MaterialTheme.typography.bodyLarge, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            if (revealed && it.detail.isNotBlank()) Text(it.detail, verbatim = true, style = MaterialTheme.typography.bodyMedium, color = BaseballColors.textSecondary, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        }
    }
    if (revealed) model.sections.firstOrNull { it.id == "professional-status" }?.let { CareerSection(it, it.rows.size) }
    if (revealed) CareerDisclosure("지명 평가 보기", "draft.assessment") {
        model.sections.filter { it.id == "draft-reasons" }.forEach { CareerSection(it, it.rows.size) }
    }
}

@Composable
internal fun CareerDecisionChoices(state: GameAggregateState, model: ScreenModel, onAction: (ScreenUiAction) -> Unit, busy: Boolean, selectedPlan: String? = null, onPlanSelected: ((String) -> Unit)? = null) {
    val copy = rememberGameCopy()
    var details by rememberSaveable(model.id.wire) { mutableStateOf(false) }
    var roleChoices by rememberSaveable(CareerUiRules.proCareerId(state), CareerUiRules.proSeason(state)) { mutableStateOf(false) }
    if (model.id == ScreenId.P017_PRO_WEEK) ProWeekPlanner(state, model, busy, onAction, selectedPlan, onPlanSelected)
    when (model.id) {
        ScreenId.P017_PRO_WEEK -> {
            if (CareerUiRules.hasPro(state)) Text(com.solkim.baseball.application.CareerUiRules.proContext(state),
                color = BaseballColors.milestone, style = MaterialTheme.typography.labelLarge)
            model.sections.firstOrNull { it.id == "pitch-learning" }?.let { CareerSections(listOf(it)) }
            model.sections.firstOrNull { it.id.startsWith("followup:") }?.let { section ->
                section.rows.firstOrNull()?.let { CareerFact(it, "week.followup") }
            }
            val roles = model.actions.filter { it.id.startsWith("requestRole:") }
            if (roles.isNotEmpty()) {
                TextButton(onClick = { roleChoices = !roleChoices }) { Text(copy.resolve("android.week.role-request")) }
                if (roleChoices) roles.forEach { CareerActionButton(model.id, it, onAction) }
            } else model.sections.firstOrNull { it.id == "role-result" }?.let { CareerSections(listOf(it)) }
        }
        else -> Unit
    }
    if (model.id == ScreenId.P017_PRO_WEEK) return
    CareerChoiceGrid(model, onAction)
    TextButton(onClick = { details = !details }) { Text(copy.resolve(if (details) "android.details.hide" else "android.details.show")) }
    if (details) CareerSections(model.sections.filterNot { it.id == "pitch-learning" || it.id.startsWith("followup:") || it.id == "role-result" })
}

@Composable
private fun ViewportCards(
    state: GameAggregateState,
    commandContext: ScreenCommandContext,
    model: ScreenModel,
    platformState: PlatformUiState,
    selectedLifeCardCareerId: String?,
    onExposed: (ViewportExposure) -> Unit,
) {
    if (state.meta.seedChallenge != null) return
    // Challenge snapshots are isolated from the lifetime analytics matrix. Do not even mount
    // exposure observers in that state, otherwise a visible card would enqueue a receipt that the
    // reducer correctly rejects and the in-process retry queue would live forever.
    if (CareerUiRules.challengeActive(state)) return
    val legacyCopy = rememberGameCopy()
    val run = CareerUiRules.schoolFacts(state)
    when (model.id) {
        ScreenId.P011_HIGH_SCHOOL_CAREER -> if (
            ReminderOfferPolicy.shouldShow(
                completedGameCount = CareerUiRules.completedGameCount(state),
                truth = platformState.notificationTruth,
                permissionAsked = platformState.notificationPermissionAsked,
                offerDeclined = platformState.reminderOfferDeclined,
                aggregateEnabled = state.settings.notificationsEnabled,
            )
        ) {
            ViewportExposureBox(
                exposure = ViewportExposure(
                    eventName = "reminder_offer_shown",
                    scope = "install:after-first-game",
                    properties = listOf("source" to "after_first_game"),
                ),
                onExposed = onExposed,
            ) {
                CareerReadOnlyRow("돌아올 때", "어디까지 했는지 알려 줄게", "첫 경기를 던졌으니, 다음에 열면 이어 할 장면부터 보여 준다.")
            }
        } else Unit
        ScreenId.P003_PROLOGUE -> if (run != null) {
            ViewportExposureBox(
                exposure = ViewportExposure(
                    eventName = "career_wind_seen",
                    scope = "career:${run.careerId}",
                    properties = listOf(
                        "wind_id" to HighSchoolDisplayRules.windIdFor(run.careerId),
                        "rules_version" to HighSchoolDisplayRules.windRulesVersion.toString(),
                    ),
                ),
                onExposed = onExposed,
            ) {
                CareerReadOnlyRow("이번 생의 바람", windLabel(HighSchoolDisplayRules.windIdFor(run.careerId)), "이 해의 분위기는 3년 내내 이어진다.")
            }
        } else Unit
        ScreenId.P007_RELATIONSHIP -> run?.relationshipEventId?.let { eventId ->
            ViewportExposureBox(
                exposure = ViewportExposure(
                    eventName = "player_heartline_seen",
                    scope = "heartline:${run.careerId}:$eventId",
                    properties = listOf(
                        "branch_id" to run.relationshipCategory.orEmpty(),
                        "life_number" to run.lifeNumber.toString(),
                        "phase" to run.phaseWire,
                    ),
                ),
                onExposed = onExposed,
            ) {
                CareerReadOnlyRow("마음의 갈림길", run.relationshipEventTitle.orEmpty(), run.relationshipEventSummary.orEmpty())
            }
        } ?: Unit
        ScreenId.P014_RUN_RECAP -> {
            if (run != null && run.legacyOptions.isNotEmpty()) {
                ViewportExposureBox(
                    exposure = ViewportExposure(
                        eventName = "signature_legacy_options_seen",
                        scope = "legacy-options:${run.careerId}",
                        properties = listOf(
                            "life_number" to run.lifeNumber.toString(),
                            "drafted" to (run.drafted == true).toString(),
                            "includes_pro_career" to (CareerUiRules.hasProCareerStats(state)).toString(),
                            "option_ids" to run.legacyOptions.joinToString(","),
                        ),
                    ),
                    onExposed = onExposed,
                ) {
                    CareerReadOnlyRow("남길 수 있는 세 가지", run.legacyOptions.joinToString(" · ") { SignatureLegacyDisplay.title(it, legacyCopy) ?: "남겨진 유산" }, "하나만 다음 생으로 간다.")
                }
            }
            PlayerLegacyExposurePolicy.resolve(state, PlayerLegacyExposureSurface.RECAP)?.let { exposure ->
                ViewportExposureBox(
                    exposure = ViewportExposure(
                        eventName = "player_legacy_seen",
                        scope = exposure.scope,
                        properties = listOf(
                            "source" to exposure.source,
                            "life_number" to exposure.lifeNumber.toString(),
                            "drafted" to exposure.drafted.toString(),
                            "has_frozen_legacy" to exposure.hasFrozenLegacy.toString(),
                        ),
                    ),
                    onExposed = onExposed,
                ) {
                    CareerReadOnlyRow("이 생의 마지막 장", "기록은 남았다", "여기서 고른 하나가 다음 생으로 간다.")
                }
            }
        }
        ScreenId.P015_REBIRTH -> PlayerLegacyExposurePolicy.resolve(state, PlayerLegacyExposureSurface.NEXT_LIFE)?.let { exposure ->
            ViewportExposureBox(
                exposure = ViewportExposure(
                    eventName = "player_legacy_seen",
                    scope = exposure.scope,
                    properties = listOf(
                        "source" to exposure.source,
                        "life_number" to exposure.lifeNumber.toString(),
                        "drafted" to exposure.drafted.toString(),
                        "has_frozen_legacy" to exposure.hasFrozenLegacy.toString(),
                    ),
                ),
                onExposed = onExposed,
            ) {
                CareerReadOnlyRow("지난 생의 편지", "기록과 기억이 이어진다", "")
            }
        } ?: Unit
        ScreenId.P024_WEEKLY -> CareerUiRules.weekly(state)?.let { weekly ->
            ViewportExposureBox(
                exposure = ViewportExposure(
                    eventName = "weekly_program_opened",
                    scope = "weekly:${weekly.weekKey}",
                    properties = listOf(
                        "week_key" to weekly.weekKey,
                        "source" to "records",
                        "completed_tasks" to weekly.tasks.count { it.completed }.toString(),
                    ),
                ),
                onExposed = onExposed,
            ) {
                CareerReadOnlyRow("이번 주 기록", "${weekly.tasks.count { it.completed }}/${weekly.tasks.size} 과제", "")
            }
        } ?: Unit
        ScreenId.P028_LIFECARD -> LifeCardProjection.selected(state, selectedLifeCardCareerId)?.let { card ->
            val exposure = PlayerLegacyExposurePolicy.resolve(state, PlayerLegacyExposureSurface.ARCHIVE, card.careerId) ?: return@let
            ViewportExposureBox(
                exposure = ViewportExposure(
                    eventName = "player_legacy_seen",
                    scope = exposure.scope,
                    properties = listOf("source" to exposure.source, "life_number" to exposure.lifeNumber.toString(), "drafted" to exposure.drafted.toString(), "has_frozen_legacy" to exposure.hasFrozenLegacy.toString()),
                ),
                onExposed = onExposed,
            ) {
                LifeCardVisual(state = state, careerId = card.careerId)
            }
        } ?: Unit
        ScreenId.P029_RETURN_PLAN -> CareerUiRules.returnPlan(state)?.takeUnless { it.dismissed }?.let { plan ->
            ViewportExposureBox(
                exposure = ViewportExposure(
                    eventName = "return_plan_shown",
                    scope = "plan:${plan.receiptId}",
                    properties = returnPlanExposureProperties(plan, commandContext.clock.today().toString()),
                ),
                onExposed = onExposed,
            ) {
                CareerReadOnlyRow("저장된 복귀 계획", plan.destination.labelForProduct(), plan.reason)
            }
        } ?: Unit
        else -> Unit
    }
}
