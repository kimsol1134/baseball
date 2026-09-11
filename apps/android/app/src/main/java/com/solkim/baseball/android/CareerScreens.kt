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
public data class ScreenUiAction(
    public val screenId: ScreenId,
    public val actionId: String,
    /** The exact immutable command envelopes captured from the rendered state. */
    public val capturedPayloads: List<ScreenCommandPayload>,
)

/** A viewport observation is a product interaction, not a route-render callback. */
public data class ViewportExposure(
    public val eventName: String,
    public val scope: String,
    public val properties: List<Pair<String, String>>,
)

@Composable
@OptIn(ExperimentalMaterial3Api::class, androidx.compose.ui.ExperimentalComposeUiApi::class)
public fun CareerShell(
    state: GameAggregateState,
    busy: Boolean,
    actionError: String?,
    currentScreen: ScreenId,
    commandContext: ScreenCommandContext,
    onNavigate: (ScreenId) -> Unit,
    onAction: (ScreenUiAction) -> Unit,
    platformState: PlatformUiState = PlatformUiState(NotificationPermissionTruth.UNAVAILABLE, null),
    onPlatformAction: (PlatformUiAction) -> Unit = {},
    onViewportExposure: (ViewportExposure) -> Unit = {},
    pendingSeedCode: com.solkim.baseball.application.SeedChallengeCode? = null,
    onSeedChallenge: () -> Unit = {},
    onExitSeedChallenge: () -> Unit = {},
) {
    val preferred = ScreenProjection.preferredScreen(state)
    val visibleScreen = currentScreen.takeIf {
        ScreenProjection.isReachable(state, it) || it == preferred
    } ?: preferred
    val gameCopy = rememberGameCopy()
    val model = ScreenProjection.project(state, visibleScreen, commandContext).localized(gameCopy, state)
    TrainingFeedbackGate(state)
    ProWeekFeedbackGate(state)
    if (visibleScreen == preferred && ConversationFeedbackGate(state, onNavigate)) return
    if (visibleScreen == ScreenId.P007_RELATIONSHIP) {
        ConversationNavigation(state, onNavigate) { RelationshipConversationScreen(state, model, busy, actionError, onAction) }
        return
    }
    if (visibleScreen == ScreenId.P019_PRO_SEASON &&
        CareerUiRules.hasPendingSeasonDecision(state) &&
        model.actions.any { it.id.startsWith("seasonDecision:") && it.enabled }) {
        ConversationNavigation(state, onNavigate) { ProConversationScreen(state, model, busy, actionError, onAction) }
        return
    }
    if (visibleScreen == ScreenId.P017_PRO_WEEK) {
        CareerMilestoneCelebration(state, showTrainingBloom = false)
        var selectedPlan by rememberSaveable(CareerUiRules.proCareerId(state)) { mutableStateOf("proPlan:develop_stuff") }
        val plan = model.actions.firstOrNull { it.id == selectedPlan }
            ?: model.actions.firstOrNull { it.id.startsWith("proPlan:") }
        Scaffold(modifier = Modifier.fillMaxSize().semantics { testTagsAsResourceId = true }, containerColor = BaseballColors.canvas,
            topBar = { Column { TopAppBar(title = { Text(model.title) }); RecentGrowthNotice(state, enabled = true) } },
            bottomBar = { Column {
                HorizontalDivider(color = BaseballColors.border)
                if (plan != null) Button(onClick = { onAction(ScreenUiAction(model.id, plan.id, plan.payloads)) },
                    enabled = plan.enabled && !busy, modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp).heightIn(min = 48.dp).testTag("week.commit")) { Text("이번 주 진행") }
                ProductNavigation(state, ProductTab.CAREER, onNavigate)
            } }) { padding ->
            Column(Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                actionError?.let { Text(it, color = BaseballColors.warning) }
                CareerDecisionChoices(state, model, onAction, busy, selectedPlan, { selectedPlan = it })
                CareerDisclosure("선수와 성장", "week.playerDetails") { CorePlayerHeader(state, compact = true) }
                Spacer(Modifier.height(16.dp))
            }
        }
        return
    }
    if (visibleScreen == ScreenId.P004_PITCH_TUTORIAL ||
        (visibleScreen == ScreenId.P003_PROLOGUE && RebirthContinuity.resolve(state) == null)) {
        PracticeEntryRecovery(state, model, busy, actionError, onAction,
            onExitChallenge = if (state.meta.seedChallenge != null) onExitSeedChallenge else null)
        return
    }
    val bridgesReview = visibleScreen == ScreenId.P010_CHAPTER &&
        (CareerUiRules.chapterNumber(state) ?: 8) < com.solkim.baseball.application.CareerUiRules.chapterCount
    var previewAttempt by remember { mutableStateOf(0) }
    val bridgeKey = "${CareerUiRules.highSchoolCareerId(state)}:${state.revision}"
    val nextTrainingLoad by produceState<Pair<String, Result<com.solkim.baseball.application.NextTrainingPreview?>>?>(null, bridgeKey, visibleScreen, previewAttempt) {
        value = if (bridgesReview) withContext(Dispatchers.Default) {
            bridgeKey to runCatching { com.solkim.baseball.application.SeamlessTrainingPresentation.next(state, commandContext) }
        } else null
    }
    val bridgeResult = nextTrainingLoad?.takeIf { it.first == bridgeKey }?.second
    val nextTraining = bridgeResult?.getOrNull()
    val trainingSurface = visibleScreen == ScreenId.P006_TRAINING || bridgesReview
    CareerMilestoneCelebration(state, showTrainingBloom = false)
    val currentTab = ProductTab.forScreen(visibleScreen)
    if (visibleScreen == ScreenId.P027_SETTINGS) {
        SettingsScreen(state, model, busy, actionError, platformState, onAction, onPlatformAction,
            onExit = { onNavigate(ScreenProjection.preferredScreen(state)) },
            onRestored = { restored -> onNavigate(ScreenProjection.preferredScreen(restored)) },
            bottomBar = { if (CareerUiRules.hasCareer(state)) ProductNavigation(state, currentTab, onNavigate) })
        return
    }
    var trainingResultStart by rememberSaveable(CareerUiRules.highSchoolCareerId(state)) { mutableStateOf(-1) }
    var dismissedTraining by rememberSaveable(CareerUiRules.highSchoolCareerId(state)) { mutableStateOf(0) }
    val growthMarker = state.meta.playerGrowth?.commandId ?: CareerUiRules.lastTrainingMarker(state)
    var spotlightMarker by rememberSaveable { mutableStateOf<String?>(null) }
    var spotlightRevision by rememberSaveable { mutableStateOf<String?>(null) }
    val growthRevision = CareerUiRules.growthRevision(state)
    val showGrowthSpotlight = growthMarker != null && (growthMarker != spotlightMarker || spotlightRevision == growthRevision)
    LaunchedEffect(growthMarker) {
        spotlightMarker = growthMarker
        spotlightRevision = growthRevision
    }
    val isFirstPlay = visibleScreen in setOf(ScreenId.P001_OPENING, ScreenId.P002_SETUP,
        ScreenId.P003_PROLOGUE, ScreenId.P004_PITCH_TUTORIAL)

    // The main action always lives in the same place: the bottom bar. Screens that are a list of equal
    // choices (schools, weekly plans, contracts, legacies) keep their choices inline.
    val genericScreen = visibleScreen !in setOf(ScreenId.P001_OPENING, ScreenId.P002_SETUP, ScreenId.P003_PROLOGUE,
        ScreenId.P004_PITCH_TUTORIAL, ScreenId.P005_SCHOOL_SELECTION, ScreenId.P006_TRAINING, ScreenId.P007_RELATIONSHIP,
        ScreenId.P009_AWAKENING, ScreenId.P014_RUN_RECAP, ScreenId.P015_REBIRTH, ScreenId.P017_PRO_WEEK, ScreenId.P027_SETTINGS)
    val pinnedAction = if (bridgesReview) null else if (visibleScreen == ScreenId.P015_REBIRTH) model.actions.firstOrNull { it.id == "startLinked" && it.enabled } ?: model.actions.firstOrNull { it.id == "quickRebirth" && it.enabled && model.actions.none { path -> path.id.startsWith("rebirthPath:") && path.enabled } }
        else if (visibleScreen in setOf(ScreenId.P008_IMPORTANT_GAME, ScreenId.P010_CHAPTER, ScreenId.P013_DRAFT))
        model.actions.firstOrNull { it.enabled }
        else if (genericScreen && visibleScreen !in setOf(ScreenId.P022_PRO_LEGACY, ScreenId.P026_ACHIEVEMENTS)) model.actions.filter { it.enabled && !it.destructive }.singleOrNull() else null

    val pitchSurface = visibleScreen in setOf(ScreenId.P008_IMPORTANT_GAME, ScreenId.P018_PRO_IMPORTANT_GAME)
    val exitAction = if (pitchSurface) model.actions.firstOrNull { it.id == "abandonPitch" && it.enabled } else null
    Scaffold(
        modifier = Modifier.fillMaxSize().semantics { testTagsAsResourceId = true },
        containerColor = BaseballColors.canvas,
        topBar = {
            Column {
            val preferred = ScreenProjection.preferredScreen(state)
            if (!isFirstPlay) TopAppBar(
                title = { Text(if (visibleScreen == ScreenId.P009_AWAKENING) gameCopy.resolve("awakening.tree.title") else if (trainingSurface) gameCopy.resolve("training.seamless.title") else if (visibleScreen == ScreenId.P015_REBIRTH && com.solkim.baseball.application.ProfessionalStatusPresentation.canEnterPro(state)) gameCopy.legacy("드래프트 결과") else if (state.meta.seedChallenge != null) gameCopy.resolve("android.challenge.screen-title", com.solkim.baseball.application.GameCopyArgument.UserText(model.title)) else model.title, style = MaterialTheme.typography.titleLarge) },
                actions = {
                    if (state.meta.seedChallenge != null) TextButton(onClick = onExitSeedChallenge, enabled = !busy, modifier = Modifier.testTag("challenge.exit")) { Text(gameCopy.resolve("android.challenge.exit")) }
                    else if (visibleScreen == ScreenId.P027_SETTINGS) TextButton(onClick = onSeedChallenge) { Text(gameCopy.resolve("android.challenge.open")) }
                },
                navigationIcon = {
                    if (visibleScreen != preferred) {
                        TextButton(onClick = { onNavigate(preferred) }) {
                            Text("← 내 투수", color = BaseballColors.action, fontWeight = FontWeight.SemiBold)
                        }
                    }
                },
            )
            RecentGrowthNotice(state, enabled = !isFirstPlay && (!trainingSurface || state.meta.playerGrowth?.source != "training"))
            }
        },
        bottomBar = {
            Column {
                exitAction?.let { action ->
                    androidx.compose.material3.OutlinedButton(onClick = { onAction(ScreenUiAction(model.id, action.id, action.payloads)) }, enabled = !busy,
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 4.dp).heightIn(min = 48.dp).testTag("action.abandonPitch")) { Text(action.label, verbatim = true) }
                }
                if (pinnedAction != null) Box(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp)) {
                    CareerActionButton(model.id, pinnedAction.copy(enabled = !busy), onAction)
                }
            if (!isFirstPlay) ProductNavigation(state, currentTab, onNavigate)
            }
        },
    ) { insets ->
        if (visibleScreen == ScreenId.P001_OPENING) {
            val appName = stringResource(R.string.app_name)
            Column(Modifier.fillMaxSize().padding(insets).padding(horizontal = 24.dp, vertical = 20.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp)) {
                Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(22.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                        TextButton(onClick = onSeedChallenge) { Text(gameCopy.resolve(if (pendingSeedCode == null) "android.challenge.open" else "android.challenge.pending")) }
                        TextButton(onClick = { onNavigate(ScreenId.P027_SETTINGS) }) { Text("설정") }
                    }
                    Spacer(Modifier.height(28.dp))
                    Text(appName, verbatim = true, color = BaseballColors.milestone, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Text("한 구씩,\n한 생씩.", style = MaterialTheme.typography.displaySmall, fontWeight = FontWeight.Bold)
                    Text("고교 마운드에서 프로까지, 공은 내가 직접 던진다.\n안 되면 다시 태어나서 더 강해진다.", style = MaterialTheme.typography.bodyLarge, color = BaseballColors.textSecondary)
                }
                model.actions.singleOrNull { it.id == "enterSetup" }?.let { action ->
                    CareerActionButton(model.id, action, onAction, showDescription = false)
                }
                var proSetup by remember { mutableStateOf(false) }
                model.actions.firstOrNull { it.id == "startDirect" && it.enabled }?.let { action ->
                    TextButton(onClick = { proSetup = true }, modifier = Modifier.testTag("opening.proMode")) { Text("프로부터 새로 시작") }
                    if (proSetup) {
                        var proName by rememberSaveable { mutableStateOf("") }
                        var proPreset by rememberSaveable { mutableStateOf("power_prospect") }
                        AlertDialog(onDismissRequest = { proSetup = false }, containerColor = BaseballColors.surfaceRaised, title = { Text("새 프로 선수") },
                            text = { Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text("고교 과정을 건너뛰는 별도 커리어예요.")
                                OutlinedTextField(proName, { proName = it.take(12) }, label = { Text("선수 이름") }, singleLine = true,
                                    supportingText = { Text("비우면 민서준으로 불린다") },
                                    modifier = Modifier.testTag("opening.proName"))
                                HighSchoolDisplayRules.presets.forEach { preset ->
                                    SetupSelectionButton(selected = proPreset == preset.id, onClick = { proPreset = preset.id }, modifier = Modifier.fillMaxWidth()) {
                                        Text(HighSchoolDisplayRules.presetTitle(preset.id))
                                    }
                                }
                            } },
                            confirmButton = { TextButton(enabled = !busy, onClick = {
                                val payloads = com.solkim.baseball.application.CareerUiRules.startProfessional(state, commandContext, proPreset, proName.trim().ifBlank { "민서준" })
                                proSetup = false
                                onAction(ScreenUiAction(model.id, action.id, payloads))
                            }, modifier = Modifier.testTag("opening.startPro")) { Text("프로 시작") } },
                            dismissButton = { TextButton(onClick = { proSetup = false }) { Text("취소") } })
                    }
                }
            }
        } else if (visibleScreen == ScreenId.P002_SETUP) {
            Column(Modifier.fillMaxSize().padding(insets).consumeWindowInsets(insets).imePadding().padding(horizontal = 20.dp, vertical = 12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (actionError != null) CareerErrorCard(actionError)
                CareerSetupFields(state, commandContext, model, onAction, busy)
            }
        } else if (trainingSurface) {
            TrainingScreen(nextTraining?.state ?: state, commandContext, busy || (bridgesReview && nextTraining == null),
                actionError ?: if (bridgeResult?.isFailure == true) gameCopy.resolve("training.seamless.load-error") else null,
                insets, trainingResultStart, dismissedTraining,
                feedbackState = state,
                playerContent = { CompanionLauncher(state, showPortrait = true); AbilityCard(state); CompanionReaction(state) },
                extraActions = {
                    if (bridgeResult?.isFailure == true) TextButton(onClick = { previewAttempt++ }) { Text(gameCopy.resolve("training.seamless.retry")) }
                    if (bridgesReview) model.actions.firstOrNull { it.id == "claimChapterGame" && it.enabled }?.let { action ->
                        TextButton(onClick = { onAction(ScreenUiAction(model.id, action.id, action.payloads)) }, enabled = !busy,
                            modifier = Modifier.testTag("action.claimChapterGame")) { Text(gameCopy.resolve("training.seamless.extra-game"), verbatim = true) }
                    }
                    TextButton(onClick = { onNavigate(ScreenId.P011_HIGH_SCHOOL_CAREER) }, modifier = Modifier.testTag("training.records")) {
                        Text(gameCopy.resolve("training.seamless.records"), verbatim = true)
                    }
                },
                spotlight = showGrowthSpotlight,
                onDismiss = { dismissedTraining = CareerUiRules.lastTrainingNumber(state) },
                onCommit = { action ->
                    trainingResultStart = CareerUiRules.totalTrainingsCompleted(state)
                    dismissedTraining = CareerUiRules.lastTrainingNumber(state)
                    if (nextTraining != null) onAction(ScreenUiAction(ScreenId.P010_CHAPTER, "advanceChapter",
                        com.solkim.baseball.application.SeamlessTrainingPresentation.commit(state, nextTraining, action.capturedPayloads)))
                    else onAction(action)
                })
        } else if (visibleScreen == ScreenId.P009_AWAKENING) {
            Column(Modifier.fillMaxSize().padding(insets)) {
                if (actionError != null) Text(actionError, color = BaseballColors.negative, modifier = Modifier.padding(16.dp))
                AwakeningTreeView(state, model, onAction, modifier = Modifier.weight(1f), busy = busy)
            }
        } else if (visibleScreen == ScreenId.P010_CHAPTER) {
            ChapterProgressScreen(state, model, busy, actionError, insets, onAction, onNavigate)
        } else if (visibleScreen in setOf(ScreenId.P003_PROLOGUE, ScreenId.P004_PITCH_TUTORIAL)) {
            RebirthReadyIntroduction(state, model, busy, actionError, insets, onAction)
        } else CareerScrollBody(insets) {
            if (actionError != null) CareerErrorCard(actionError)

            if (model.id.group in setOf(ScreenGroup.CAREER_CORE, ScreenGroup.PRO, ScreenGroup.RECAP_REBIRTH) && model.id !in setOf(ScreenId.P014_RUN_RECAP, ScreenId.P015_REBIRTH, ScreenId.P008_IMPORTANT_GAME, ScreenId.P018_PRO_IMPORTANT_GAME)) {
                CorePlayerHeader(state, compact = true)
            }
            if (visibleScreen in recordScreens) RecordsSegments(state, visibleScreen, onNavigate)

            CareerScreenContent(
                state = state,
                busy = busy,
                commandContext = commandContext,
                model = model.copy(actions = model.actions.filterNot { (exitAction != null && it.id == exitAction.id) || (pinnedAction != null && pinnedAction.id != "quickRebirth" && it.id == pinnedAction.id) }),
                onAction = onAction,
                platformState = platformState,
                onPlatformAction = onPlatformAction,
                onViewportExposure = onViewportExposure,
            )
            if (visibleScreen in setOf(ScreenId.P013_DRAFT, ScreenId.P014_RUN_RECAP, ScreenId.P021_PRO_RETIREMENT) && state.meta.album.isNotEmpty()) {
                TextButton(onClick = { onNavigate(ScreenId.P028_LIFECARD) }, modifier = Modifier.testTag("career.album")) { Text("선수 앨범") }
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}
