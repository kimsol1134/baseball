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
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import com.solkim.baseball.android.LocalizedGameText as Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import com.solkim.baseball.application.Phase8Group
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.CareerShareCopy
import com.solkim.baseball.application.RebirthContinuity
import com.solkim.baseball.application.RelationshipNarrative
import androidx.compose.foundation.BorderStroke
import com.solkim.baseball.application.SignatureLegacyDisplay
import com.solkim.baseball.application.GameCopyArgument
import com.solkim.baseball.application.GameAggregateState
import com.solkim.baseball.application.Phase8ActionModel
import com.solkim.baseball.application.Phase8CommandContext
import com.solkim.baseball.application.Phase8CommandPayload
import com.solkim.baseball.application.Phase9LifeCardProjection
import com.solkim.baseball.application.Phase9PlayerLegacyExposurePolicy
import com.solkim.baseball.application.Phase9PlayerLegacyExposureSurface
import com.solkim.baseball.application.Phase8ScreenId
import com.solkim.baseball.application.Phase8ScreenModel
import com.solkim.baseball.application.Phase8ScreenProjection
import com.solkim.baseball.application.Phase8Payloads
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
import com.solkim.baseball.application.HighSchoolReturnPlan
import com.solkim.baseball.platform.NotificationPermissionTruth
import com.solkim.baseball.platform.ReminderOfferPolicy

public data class Phase8UiAction(
    public val screenId: Phase8ScreenId,
    public val actionId: String,
    /** The exact immutable command envelopes captured from the rendered state. */
    public val capturedPayloads: List<Phase8CommandPayload>,
)

/** A viewport observation is a product interaction, not a route-render callback. */
public data class Phase9ViewportExposure(
    public val eventName: String,
    public val scope: String,
    public val properties: List<Pair<String, String>>,
)

@Composable
@OptIn(ExperimentalMaterial3Api::class, androidx.compose.ui.ExperimentalComposeUiApi::class)
public fun Phase8Shell(
    state: GameAggregateState,
    busy: Boolean,
    actionError: String?,
    currentScreen: Phase8ScreenId,
    commandContext: Phase8CommandContext,
    onNavigate: (Phase8ScreenId) -> Unit,
    onAction: (Phase8UiAction) -> Unit,
    platformState: Phase9PlatformUiState = Phase9PlatformUiState(NotificationPermissionTruth.UNAVAILABLE, null),
    onPlatformAction: (Phase9UiAction) -> Unit = {},
    onViewportExposure: (Phase9ViewportExposure) -> Unit = {},
    pendingSeedCode: com.solkim.baseball.application.SeedChallengeCode? = null,
    onSeedChallenge: () -> Unit = {},
    onExitSeedChallenge: () -> Unit = {},
) {
    val preferred = Phase8ScreenProjection.preferredScreen(state)
    val visibleScreen = currentScreen.takeIf {
        Phase8ScreenProjection.isReachable(state, it) || it == preferred
    } ?: preferred
    val gameCopy = rememberGameCopy()
    val model = Phase8ScreenProjection.project(state, visibleScreen, commandContext).localized(gameCopy, state)
    if (visibleScreen == Phase8ScreenId.P004_PITCH_TUTORIAL ||
        (visibleScreen == Phase8ScreenId.P003_PROLOGUE && RebirthContinuity.resolve(state) == null)) {
        PracticeEntryRecovery(state, model, busy, actionError, onAction,
            onExitChallenge = if (state.meta.seedChallenge != null) onExitSeedChallenge else null)
        return
    }
    val bridgesReview = visibleScreen == Phase8ScreenId.P010_CHAPTER &&
        (state.highSchool?.run?.chapter?.number ?: 8) < com.solkim.baseball.core.highschool.HighSchoolContentCatalog.chapters.size
    var previewAttempt by remember { mutableStateOf(0) }
    val bridgeKey = "${state.highSchool?.run?.careerId}:${state.revision}"
    val nextTrainingLoad by produceState<Pair<String, Result<com.solkim.baseball.application.NextTrainingPreview?>>?>(null, bridgeKey, visibleScreen, previewAttempt) {
        value = if (bridgesReview) withContext(Dispatchers.Default) {
            bridgeKey to runCatching { com.solkim.baseball.application.SeamlessTrainingPresentation.next(state, commandContext) }
        } else null
    }
    val bridgeResult = nextTrainingLoad?.takeIf { it.first == bridgeKey }?.second
    val nextTraining = bridgeResult?.getOrNull()
    val trainingSurface = visibleScreen == Phase8ScreenId.P006_TRAINING || bridgesReview
    TrainingFeedbackGate(state)
    ConversationFeedbackGate(state)
    ProWeekFeedbackGate(state)
    CareerMilestoneCelebration(state, showTrainingBloom = false)
    val currentTab = ProductTab.forScreen(visibleScreen)
    if (visibleScreen == Phase8ScreenId.P027_SETTINGS) {
        SettingsScreen(state, model, busy, actionError, platformState, onAction, onPlatformAction,
            onExit = { onNavigate(Phase8ScreenProjection.preferredScreen(state)) },
            onRestored = { restored -> onNavigate(Phase8ScreenProjection.preferredScreen(restored)) },
            bottomBar = { if (state.highSchool != null || state.pro != null) ProductNavigation(state, currentTab, onNavigate) })
        return
    }
    var trainingResultStart by rememberSaveable(state.highSchool?.run?.careerId) { mutableStateOf(-1) }
    var dismissedTraining by rememberSaveable(state.highSchool?.run?.careerId) { mutableStateOf(0) }
    val growthMarker = state.meta.playerGrowth?.commandId
        ?: state.highSchool?.run?.lastTraining?.let { "${state.highSchool?.run?.careerId}:training:${it.number}" }
    var spotlightMarker by rememberSaveable { mutableStateOf<String?>(null) }
    var spotlightRevision by rememberSaveable { mutableStateOf<String?>(null) }
    val growthRevision = if (state.stage in setOf(com.solkim.baseball.application.GameStage.PRO, com.solkim.baseball.application.GameStage.RETIREMENT))
        state.pro?.revision?.toString() else state.highSchool?.run?.revision?.toString()
    val showGrowthSpotlight = growthMarker != null && (growthMarker != spotlightMarker || spotlightRevision == growthRevision)
    LaunchedEffect(growthMarker) {
        spotlightMarker = growthMarker
        spotlightRevision = growthRevision
    }
    val isFirstPlay = visibleScreen in setOf(Phase8ScreenId.P001_OPENING, Phase8ScreenId.P002_SETUP,
        Phase8ScreenId.P003_PROLOGUE, Phase8ScreenId.P004_PITCH_TUTORIAL)

    // The main action always lives in the same place: the bottom bar. Screens that are a list of equal
    // choices (schools, weekly plans, contracts, legacies) keep their choices inline.
    val genericScreen = visibleScreen !in setOf(Phase8ScreenId.P001_OPENING, Phase8ScreenId.P002_SETUP, Phase8ScreenId.P003_PROLOGUE,
        Phase8ScreenId.P004_PITCH_TUTORIAL, Phase8ScreenId.P005_SCHOOL_SELECTION, Phase8ScreenId.P006_TRAINING, Phase8ScreenId.P007_RELATIONSHIP,
        Phase8ScreenId.P009_AWAKENING, Phase8ScreenId.P014_RUN_RECAP, Phase8ScreenId.P015_REBIRTH, Phase8ScreenId.P017_PRO_WEEK, Phase8ScreenId.P027_SETTINGS)
    val pinnedAction = if (bridgesReview) null else if (visibleScreen == Phase8ScreenId.P015_REBIRTH) model.actions.firstOrNull { it.id == "startLinked" && it.enabled } ?: model.actions.firstOrNull { it.id == "quickRebirth" && it.enabled }
        else if (visibleScreen in setOf(Phase8ScreenId.P008_IMPORTANT_GAME, Phase8ScreenId.P010_CHAPTER, Phase8ScreenId.P013_DRAFT))
        model.actions.firstOrNull { it.enabled }
        else if (genericScreen && visibleScreen !in setOf(Phase8ScreenId.P022_PRO_LEGACY, Phase8ScreenId.P026_ACHIEVEMENTS)) model.actions.filter { it.enabled && !it.destructive }.singleOrNull() else null

    Scaffold(
        modifier = Modifier.fillMaxSize().semantics { testTagsAsResourceId = true },
        containerColor = BaseballColors.canvas,
        topBar = {
            Column {
            val preferred = Phase8ScreenProjection.preferredScreen(state)
            if (!isFirstPlay) TopAppBar(
                title = { Text(if (visibleScreen == Phase8ScreenId.P009_AWAKENING) gameCopy.resolve("awakening.tree.title") else if (trainingSurface) gameCopy.resolve("training.seamless.title") else if (visibleScreen == Phase8ScreenId.P015_REBIRTH && com.solkim.baseball.application.ProfessionalStatusPresentation.canEnterPro(state)) gameCopy.legacy("현재 진로") else if (state.meta.seedChallenge != null) gameCopy.resolve("android.challenge.screen-title", com.solkim.baseball.application.GameCopyArgument.UserText(model.title)) else model.title, style = MaterialTheme.typography.titleLarge) },
                actions = {
                    if (state.meta.seedChallenge != null) TextButton(onClick = onExitSeedChallenge, enabled = !busy, modifier = Modifier.testTag("challenge.exit")) { Text(gameCopy.resolve("android.challenge.exit")) }
                    else if (visibleScreen == Phase8ScreenId.P027_SETTINGS) TextButton(onClick = onSeedChallenge) { Text(gameCopy.resolve("android.challenge.open")) }
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
                if (pinnedAction != null) Box(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp)) {
                    Phase8ActionButton(model.id, pinnedAction.copy(enabled = !busy), onAction)
                }
            if (!isFirstPlay) ProductNavigation(state, currentTab, onNavigate)
            }
        },
    ) { insets ->
        if (visibleScreen == Phase8ScreenId.P001_OPENING) {
            val appName = stringResource(R.string.app_name)
            Column(Modifier.fillMaxSize().padding(insets).padding(horizontal = 24.dp, vertical = 20.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp)) {
                Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(22.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                        TextButton(onClick = onSeedChallenge) { Text(gameCopy.resolve(if (pendingSeedCode == null) "android.challenge.open" else "android.challenge.pending")) }
                        TextButton(onClick = { onNavigate(Phase8ScreenId.P027_SETTINGS) }) { Text("설정") }
                    }
                    Spacer(Modifier.height(28.dp))
                    Text(appName, verbatim = true, color = BaseballColors.milestone, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Text("한 구씩,\n한 생씩.", style = MaterialTheme.typography.displaySmall, fontWeight = FontWeight.Bold)
                    Text("고교 마운드에서 프로까지, 공은 내가 직접 던진다.\n안 되면 다시 태어나서 더 강해진다.", style = MaterialTheme.typography.bodyLarge, color = BaseballColors.textSecondary)
                }
                model.actions.singleOrNull { it.id == "enterSetup" }?.let { action ->
                    Phase8ActionButton(model.id, action, onAction, showDescription = false)
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
                                    modifier = Modifier.testTag("opening.proName"))
                                HighSchoolDisplayRules.presets.forEach { preset ->
                                    SetupSelectionButton(selected = proPreset == preset.id, onClick = { proPreset = preset.id }, modifier = Modifier.fillMaxWidth()) {
                                        Text(HighSchoolDisplayRules.presetTitle(preset.id))
                                    }
                                }
                            } },
                            confirmButton = { TextButton(enabled = proName.isNotBlank() && !busy, onClick = {
                                val command = com.solkim.baseball.application.GameCommand.Pro(com.solkim.baseball.core.pro.ProCommand.StartDirect(
                                    com.solkim.baseball.core.pro.ProStartDirectRequest(commandContext.seed(state, "pro-direct"), proPreset, proName.trim())))
                                val payloads = Phase8Payloads.batch(state, model.id, action.id, listOf(command))
                                proSetup = false
                                onAction(Phase8UiAction(model.id, action.id, payloads))
                            }, modifier = Modifier.testTag("opening.startPro")) { Text("프로 시작") } },
                            dismissButton = { TextButton(onClick = { proSetup = false }) { Text("취소") } })
                    }
                }
            }
        } else if (visibleScreen == Phase8ScreenId.P002_SETUP) {
            Column(Modifier.fillMaxSize().padding(insets).consumeWindowInsets(insets).imePadding().padding(horizontal = 20.dp, vertical = 12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (actionError != null) Phase8ErrorCard(actionError)
                Phase8SetupFields(state, commandContext, model, onAction, busy)
            }
        } else if (trainingSurface) {
            TrainingScreen(nextTraining?.state ?: state, commandContext, busy || (bridgesReview && nextTraining == null),
                actionError ?: if (bridgeResult?.isFailure == true) gameCopy.resolve("training.seamless.load-error") else null,
                insets, trainingResultStart, dismissedTraining,
                feedbackState = state,
                playerContent = { CompanionLauncher(state, showPortrait = true); CompanionReaction(state) },
                extraActions = {
                    if (bridgeResult?.isFailure == true) TextButton(onClick = { previewAttempt++ }) { Text(gameCopy.resolve("training.seamless.retry")) }
                    if (bridgesReview) model.actions.firstOrNull { it.id == "claimChapterGame" && it.enabled }?.let { action ->
                        TextButton(onClick = { onAction(Phase8UiAction(model.id, action.id, action.payloads)) }, enabled = !busy,
                            modifier = Modifier.testTag("action.claimChapterGame")) { Text(gameCopy.resolve("training.seamless.extra-game"), verbatim = true) }
                    }
                    TextButton(onClick = { onNavigate(Phase8ScreenId.P011_HIGH_SCHOOL_CAREER) }, modifier = Modifier.testTag("training.records")) {
                        Text(gameCopy.resolve("training.seamless.records"), verbatim = true)
                    }
                },
                spotlight = showGrowthSpotlight,
                onDismiss = { dismissedTraining = state.highSchool?.run?.lastTraining?.number ?: 0 },
                onCommit = { action ->
                    trainingResultStart = state.highSchool?.run?.totalTrainingsCompleted ?: 0
                    dismissedTraining = state.highSchool?.run?.lastTraining?.number ?: 0
                    if (nextTraining != null) onAction(Phase8UiAction(Phase8ScreenId.P010_CHAPTER, "advanceChapter",
                        com.solkim.baseball.application.SeamlessTrainingPresentation.commit(state, nextTraining, action.capturedPayloads)))
                    else onAction(action)
                })
        } else if (visibleScreen == Phase8ScreenId.P009_AWAKENING) {
            Column(Modifier.fillMaxSize().padding(insets)) {
                if (actionError != null) Text(actionError, color = BaseballColors.negative, modifier = Modifier.padding(16.dp))
                AwakeningTreeView(state, model, onAction, modifier = Modifier.weight(1f), busy = busy)
            }
        } else if (visibleScreen == Phase8ScreenId.P010_CHAPTER) {
            ChapterProgressScreen(state, model, busy, actionError, insets, onAction, onNavigate)
        } else if (visibleScreen in setOf(Phase8ScreenId.P003_PROLOGUE, Phase8ScreenId.P004_PITCH_TUTORIAL)) {
            RebirthReadyIntroduction(state, model, busy, actionError, insets, onAction)
        } else Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(insets)
                .consumeWindowInsets(insets)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            if (actionError != null) Phase8ErrorCard(actionError)

            if (model.id.group in setOf(Phase8Group.CAREER_CORE, Phase8Group.PRO, Phase8Group.RECAP_REBIRTH) && model.id !in setOf(Phase8ScreenId.P014_RUN_RECAP, Phase8ScreenId.P015_REBIRTH, Phase8ScreenId.P008_IMPORTANT_GAME, Phase8ScreenId.P018_PRO_IMPORTANT_GAME)) {
                CorePlayerHeader(state, compact = true)
            }
            if (visibleScreen in recordScreens) RecordsSegments(state, visibleScreen, onNavigate)

            Phase8ScreenContent(
                state = state,
                commandContext = commandContext,
                model = if (pinnedAction == null || pinnedAction.id == "quickRebirth") model else model.copy(actions = model.actions.filterNot { it.id == pinnedAction.id }),
                onAction = onAction,
                platformState = platformState,
                onPlatformAction = onPlatformAction,
                onViewportExposure = onViewportExposure,
            )
            Spacer(Modifier.height(8.dp))
        }
    }
}

@Composable
private fun RebirthReadyIntroduction(
    state: GameAggregateState,
    model: Phase8ScreenModel,
    busy: Boolean,
    actionError: String?,
    insets: androidx.compose.foundation.layout.PaddingValues,
    onAction: (Phase8UiAction) -> Unit,
) {
    var acceptsFreshTap by remember(state.highSchool?.run?.careerId, model.id) { mutableStateOf(false) }
    LaunchedEffect(state.highSchool?.run?.careerId, model.id) {
        androidx.compose.runtime.withFrameNanos { }
        kotlinx.coroutines.delay(500)
        acceptsFreshTap = true
    }
    val continuity = RebirthContinuity.resolve(state) ?: return
    val copy = rememberGameCopy()
    var memories by rememberSaveable(state.highSchool?.run?.careerId) { mutableStateOf(false) }
    Column(Modifier.fillMaxSize().padding(insets).padding(horizontal = 24.dp, vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (actionError != null) Phase8ErrorCard(actionError)
        CorePlayerHeader(state, compact = true)
        Text(copy.resolve(if (continuity.samePlayer) "loop.reborn.same" else "loop.reborn.different"), verbatim = true,
            style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, modifier = Modifier.testTag("rebirth.ready"))
        Text(copy.resolve("loop.reborn.next"), verbatim = true, style = MaterialTheme.typography.bodyMedium)
        model.actions.firstOrNull { it.id == "completeTutorial" }?.let { action -> Phase8ActionButton(model.id, action.copy(enabled = action.enabled && !busy && acceptsFreshTap), onAction, showDescription = false) }
        model.actions.firstOrNull { it.id == "resumePitch" && it.enabled }?.let { action -> Phase8ActionButton(model.id, action.copy(enabled = !busy && acceptsFreshTap), onAction, showDescription = false) }
            ?: model.actions.firstOrNull { it.id == "openTutorialPitch" }?.let { action ->
                OutlinedButton(onClick = { onAction(Phase8UiAction(model.id, action.id, action.payloads)) }, enabled = action.enabled && !busy,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("action.openTutorialPitch")) { Text(if (state.pitch?.boundary in setOf(PitchBoundary.COMMITTED, PitchBoundary.CONSUMED, PitchBoundary.TERMINAL)) "결과 확인" else "연습 투구") }
            }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            continuity.legacyTitle?.let { Text(copy.resolve("loop.reborn.inherited", GameCopyArgument.UserText(copy.legacy(it))), verbatim = true, color = BaseballColors.milestone) }
            val handicaps = state.highSchool?.run?.karmas?.size ?: 0
            if (handicaps > 0) Text(copy.resolve("loop.reborn.handicaps", GameCopyArgument.Whole(handicaps.toLong())), verbatim = true, color = BaseballColors.warning)
            val previousName = continuity.previousName
            if (previousName != null) {
                TextButton(onClick = { memories = !memories }, modifier = Modifier.testTag("rebirth.memories")) {
                    Text(copy.resolve(if (continuity.samePlayer) "loop.reborn.memories" else "loop.reborn.other-record"), verbatim = true)
                }
                if (memories) {
                    Text(if (continuity.samePlayer) copy.resolve("loop.letter.self-title") else previousName,
                        verbatim = true, style = MaterialTheme.typography.titleMedium, modifier = Modifier.testTag("rebirth.previousSelf"))
                    val body = if (continuity.samePlayer) continuity.legacyTitle?.let { copy.resolve("loop.letter.self-body", GameCopyArgument.UserText(copy.legacy(it))) }
                        ?: copy.resolve("loop.letter.self-basic") else copy.resolve("loop.reborn.other-history", GameCopyArgument.UserText(previousName))
                    Text(body, verbatim = true)
                    Text(copy.resolve("loop.reborn.record-line", GameCopyArgument.Whole(continuity.games.toLong()), GameCopyArgument.Whole(continuity.strikeouts.toLong())), verbatim = true)
                }
            }
        }
    }
}

private val recordScreens = listOf(Phase8ScreenId.P025_RECORDS_LEAGUE, Phase8ScreenId.P011_HIGH_SCHOOL_CAREER, Phase8ScreenId.P026_ACHIEVEMENTS, Phase8ScreenId.P024_WEEKLY, Phase8ScreenId.P028_LIFECARD, Phase8ScreenId.P029_RETURN_PLAN)

/** The records tab used to land on the first reachable screen and stop there. Every record screen is one tap away. */
@Composable
private fun RecordsSegments(state: GameAggregateState, current: Phase8ScreenId, onNavigate: (Phase8ScreenId) -> Unit) {
    val copy = rememberGameCopy()
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        recordScreens.chunked(3).forEach { group ->
            AdaptiveActionRow(Modifier.fillMaxWidth(), equalWidth = true) {
                group.forEach { screen ->
                    val fullLabel = when (screen) {
                        Phase8ScreenId.P025_RECORDS_LEAGUE -> "통산 기록"
                        Phase8ScreenId.P011_HIGH_SCHOOL_CAREER -> "경기 기록"
                        Phase8ScreenId.P026_ACHIEVEMENTS -> "업적"
                        Phase8ScreenId.P024_WEEKLY -> "주간 노트"
                        Phase8ScreenId.P028_LIFECARD -> "라이프 카드"
                        else -> "돌아올 자리"
                    }
                    val label = when (screen) {
                        Phase8ScreenId.P025_RECORDS_LEAGUE -> "career"
                        Phase8ScreenId.P011_HIGH_SCHOOL_CAREER -> "games"
                        Phase8ScreenId.P026_ACHIEVEMENTS -> "achievements"
                        Phase8ScreenId.P024_WEEKLY -> "week"
                        Phase8ScreenId.P028_LIFECARD -> "card"
                        else -> "return"
                    }
                    val badge = when (screen) {
                        Phase8ScreenId.P026_ACHIEVEMENTS -> state.highSchool?.unacknowledgedAchievements?.isNotEmpty() == true
                        Phase8ScreenId.P024_WEEKLY -> state.highSchool?.weekly?.let { !it.rewardClaimed && it.tasks.any { task -> task.completed } } == true
                        else -> false
                    }
                    androidx.compose.material3.FilterChip(selected = screen == current,
                        colors = androidx.compose.material3.FilterChipDefaults.filterChipColors(selectedContainerColor = BaseballColors.action, selectedLabelColor = BaseballColors.actionInk),
                        onClick = { if (screen != current) onNavigate(screen) }, enabled = Phase8ScreenProjection.isReachable(state, screen),
                        label = { Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(copy.resolve("controls.records.$label"), verbatim = true)
                            Box(Modifier.size(6.dp).background(if (badge) BaseballColors.milestone else androidx.compose.ui.graphics.Color.Transparent,
                                androidx.compose.foundation.shape.CircleShape))
                        } },
                        modifier = Modifier.heightIn(min = 48.dp).testTag("records.tab.${screen.wire}")
                            .gameDescription(copy.legacy(fullLabel) + if (badge) " · " + copy.legacy("새 소식") else ""))
                }
            }
        }
    }
}

private enum class ProductTab(val label: String) {
    CAREER("내 투수"),
    RECORDS("기록"),
    SETTINGS("설정"),
    ;

    fun landingScreen(state: GameAggregateState): Phase8ScreenId? {
        val preferred = Phase8ScreenProjection.preferredScreen(state)
        val candidates = when (this) {
            CAREER -> {
                if (preferred.group in setOf(Phase8Group.CAREER_CORE, Phase8Group.RECAP_REBIRTH, Phase8Group.PRO)) {
                    listOf(preferred)
                } else if (state.pro != null) {
                    listOf(
                        preferred,
                        Phase8ScreenId.P017_PRO_WEEK,
                        Phase8ScreenId.P016_PRO_CONTRACT,
                        Phase8ScreenId.P021_PRO_RETIREMENT,
                        Phase8ScreenId.P020_OFFSEASON,
                    )
                } else {
                    listOf(
                        preferred,
                        Phase8ScreenId.P005_SCHOOL_SELECTION,
                        Phase8ScreenId.P006_TRAINING,
                        Phase8ScreenId.P007_RELATIONSHIP,
                        Phase8ScreenId.P008_IMPORTANT_GAME,
                        Phase8ScreenId.P009_AWAKENING,
                        Phase8ScreenId.P010_CHAPTER,
                        Phase8ScreenId.P011_HIGH_SCHOOL_CAREER,
                        Phase8ScreenId.P003_PROLOGUE,
                        Phase8ScreenId.P002_SETUP,
                        Phase8ScreenId.P001_OPENING,
                    )
                }
            }
            RECORDS -> listOf(
                Phase8ScreenId.P025_RECORDS_LEAGUE,
                Phase8ScreenId.P024_WEEKLY,
                Phase8ScreenId.P026_ACHIEVEMENTS,
                Phase8ScreenId.P028_LIFECARD,
            )
            SETTINGS -> listOf(Phase8ScreenId.P027_SETTINGS)
        }
        return candidates.firstOrNull { Phase8ScreenProjection.isReachable(state, it) }
    }

    companion object {
        fun forScreen(screen: Phase8ScreenId): ProductTab = if (screen in setOf(Phase8ScreenId.P028_LIFECARD, Phase8ScreenId.P011_HIGH_SCHOOL_CAREER)) RECORDS else when (screen.group) {
            Phase8Group.PRO, Phase8Group.CAREER_CORE, Phase8Group.RECAP_REBIRTH -> CAREER
            Phase8Group.RECORDS_META, Phase8Group.RETURN_REVIEW -> RECORDS
            Phase8Group.SETTINGS_PLATFORM -> SETTINGS
        }
    }
}

@Composable
private fun TabIcon(tab: ProductTab, isSelected: Boolean) {
    val tint = if (isSelected) BaseballColors.action else BaseballColors.textTertiary
    val iconRes = when (tab) {
        ProductTab.CAREER -> R.drawable.ic_tab_career
        ProductTab.RECORDS -> R.drawable.ic_tab_records
        ProductTab.SETTINGS -> R.drawable.ic_tab_settings
    }
    Icon(
        painter = painterResource(iconRes),
        contentDescription = null,
        tint = tint,
        modifier = Modifier.size(24.dp),
    )
}

@Composable
private fun Phase8ScreenContent(
    state: GameAggregateState,
    commandContext: Phase8CommandContext,
    model: Phase8ScreenModel,
    onAction: (Phase8UiAction) -> Unit,
    platformState: Phase9PlatformUiState,
    onPlatformAction: (Phase9UiAction) -> Unit,
    onViewportExposure: (Phase9ViewportExposure) -> Unit,
) {
    val archiveIds = state.highSchool?.archive.orEmpty().map { it.careerId }
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
            if (model.id == Phase8ScreenId.P002_SETUP) {
                Phase8SetupFields(state, commandContext, model, onAction)
            } else {
                when (model.id) {
                    Phase8ScreenId.P014_RUN_RECAP, Phase8ScreenId.P015_REBIRTH -> CoreRebirthChoices(state, model, onAction, onViewportExposure)
                    Phase8ScreenId.P027_SETTINGS -> { CareerBackupControls(state); Phase8Sections(model.sections); Phase8Actions(model, onAction) }
                    Phase8ScreenId.P009_AWAKENING -> AwakeningTreeView(state, model, onAction)
                    Phase8ScreenId.P005_SCHOOL_SELECTION -> Phase8SchoolChoices(state, model, onAction)
                    Phase8ScreenId.P016_PRO_CONTRACT -> if (model.actions.any { it.id.startsWith("acceptOffer:") }) Phase8ContractChoices(model, onAction) else { Phase8Sections(model.sections); Phase8Actions(model, onAction) }
                    Phase8ScreenId.P013_DRAFT -> { Phase8DraftReveal(state, model); Phase8Actions(model, onAction) }
                    Phase8ScreenId.P008_IMPORTANT_GAME, Phase8ScreenId.P018_PRO_IMPORTANT_GAME -> OutingBriefingView(state, model, commandContext, onAction)
                    Phase8ScreenId.P007_RELATIONSHIP, Phase8ScreenId.P017_PRO_WEEK ->
                        Phase8DecisionChoices(state, model, onAction)
                    in compactCareerScreens -> {
                        CompactCareerOverview(state, model, onAction)
                        if (model.id !in setOf(Phase8ScreenId.P022_PRO_LEGACY, Phase8ScreenId.P026_ACHIEVEMENTS)) Phase8Actions(model, onAction)
                    }
                    else -> {
                        Phase8Sections(model.sections)
                        Phase8Actions(model, onAction)
                    }
                }
                var showsDetails by remember(model.id) { mutableStateOf(false) }
                TextButton(onClick = { showsDetails = !showsDetails }, modifier = Modifier.testTag("career.storyDetails")) {
                    Text(rememberGameCopy().resolve("mobile.core.career-details"), verbatim = true)
                }
                if (showsDetails) {
                if (model.id == Phase8ScreenId.P015_REBIRTH) Phase8Sections(model.sections)
                else Phase8ShareButton(state, model)
                Phase9ViewportCards(state, commandContext, model, platformState, selectedLifeCardId, onViewportExposure)
                Phase9PlatformSurface(
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

@Composable
private fun CoreRebirthChoices(state: GameAggregateState, model: Phase8ScreenModel, onAction: (Phase8UiAction) -> Unit, onExposed: (Phase9ViewportExposure) -> Unit) {
    val copy = rememberGameCopy()
    model.sections.firstOrNull { it.id == "professional-status" }?.let { CareerSection(it, it.rows.size) }
    val enteringPro = com.solkim.baseball.application.ProfessionalStatusPresentation.canEnterPro(state)
    if (enteringPro && model.id == Phase8ScreenId.P015_REBIRTH) {
        model.actions.firstOrNull { it.id == "startLinked" && it.enabled }?.let { Phase8ActionButton(model.id, it, onAction) }
        val alternatives = model.actions.filter { it.enabled && it.id in setOf("quickRebirth", "customizeRebirth", "finalizeArchive") }
        if (alternatives.isNotEmpty()) CareerDisclosure("이번 생을 마무리하는 선택", "career.otherPath") {
            val nextLife = alternatives.firstOrNull { it.id == "quickRebirth" }
            var preview by remember(nextLife) { mutableStateOf<RebirthStartPreview?>(null) }
            LaunchedEffect(nextLife) { preview = withContext(Dispatchers.Default) { RebirthStartPreview.resolve(state, nextLife) } }
            preview?.let { CoreRebirthStartComparison(it) }
            alternatives.forEach { Phase8ActionButton(model.id, it, onAction, showDescription = true) }
        }
        return
    }
    val quickPath = model.id == Phase8ScreenId.P015_REBIRTH && !enteringPro && model.actions.any { it.id == "quickRebirth" && it.enabled }
    if (quickPath) {
        val run = state.highSchool?.run
        val name = run?.identity?.name?.takeIf { it.isNotBlank() }
        if (name != null) {
            Row(Modifier.fillMaxWidth().testTag("rebirth.identity"), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                PlayerPortrait(seed = playerPortraitSeed(state) ?: name, stage = if (state.pro != null) PlayerStage.PRO else PlayerStage.ACE, width = 56.dp)
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
        if (run != null && state.highSchool?.archive?.any { it.careerId == run.careerId } == true) {
            CareerDisclosure("지난 생의 카드", "rebirth.previousLife") {
                LifeCardVisual(state = state, careerId = run.careerId)
                Phase8ShareButton(state, model)
            }
        }
    } else if (model.id == Phase8ScreenId.P014_RUN_RECAP) CompactLifeRecap(state, model)
    else model.sections.filter { it.id != "professional-status" && (!enteringPro || it.id != "rebirth") }.forEach { CareerSection(it, 1) }
    val actions = model.actions.filter { action ->
        action.enabled && action.id !in setOf("confirmRecap", "confirmDraftResult") &&
            (action.id != "prepareLegacy" || (state.highSchool?.selectedSignatureLegacyId == null && model.actions.none { it.enabled && it.id.startsWith("selectLegacy:") }))
    }
    val primary = actions.firstOrNull { it.id == "quickRebirth" }
        ?: actions.firstOrNull { it.id == "finalizeArchive" }
        ?: actions.firstOrNull { it.id == "prepareLegacy" }
    val legacyActions = actions.filter { it.id.startsWith("selectLegacy:") }
    val run = state.highSchool?.run
    if (legacyActions.isNotEmpty() && run != null) {
        Phase9ViewportExposureBox(exposure = Phase9ViewportExposure(
            eventName = "signature_legacy_options_seen", scope = "legacy-options:${run.careerId}",
            properties = listOf("life_number" to run.lifeNumber.toString(),
                "drafted" to (run.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED).toString(),
                "includes_pro_career" to (state.pro?.careerStats?.isNotEmpty() == true).toString(),
                "option_ids" to run.legacyOptions.joinToString(","))), onExposed = onExposed) {
            CareerLegacyPicker(model, legacyActions, onAction)
        }
    }
    val previewKey = remember(primary) { primary?.payloads?.singleOrNull()?.payloadSha256 }
    var preview by remember(previewKey) { mutableStateOf<RebirthStartPreview?>(null) }
    LaunchedEffect(previewKey) {
        preview = withContext(Dispatchers.Default) { RebirthStartPreview.resolve(state, primary) }
    }
    preview?.let { CoreRebirthStartComparison(it) }
    primary?.takeIf { it.id != "quickRebirth" }?.let { Phase8ActionButton(model.id, it, onAction) }
    actions.filter { it != primary && !it.id.startsWith("selectLegacy:") }.forEach { action ->
        OutlinedButton(onClick = { onAction(Phase8UiAction(model.id, action.id, action.payloads)) },
            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("action.${action.id}")) {
            Text(action.label)
        }
        if (action.destructive) Text(action.description, color = MaterialTheme.colorScheme.error)
    }
}

@Composable
private fun Phase8Sections(sections: List<com.solkim.baseball.application.Phase8Section>) {
    sections.forEach { section ->
        Text(section.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.secondary, modifier = Modifier.semantics { heading() })
        section.rows.forEach { row -> Phase8ReadOnlyRow(row.label, row.value, row.detail) }
    }
}

/** Contract market: one team at a time. The goal is the second question, not a multiplier on the button list. */
@Composable
private fun Phase8ContractChoices(model: Phase8ScreenModel, onAction: (Phase8UiAction) -> Unit) {
    val offers = model.actions.filter { it.id.startsWith("acceptOffer:") }.groupBy { it.id.split(":")[1] }
    model.sections.firstOrNull { it.id == "professional-status" }?.let { CareerSection(it, it.rows.size) }
    val market = model.sections.firstOrNull { it.id == "pro-contract-market" }
    var selectedOffer by rememberSaveable(model.id.wire) { mutableStateOf<String?>(null) }
    market?.let { Text(it.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.secondary) }
    offers.entries.forEachIndexed { index, (offerId, actions) ->
        val teamName = actions.first().label.substringBefore(" · ")
        val row = market?.rows?.getOrNull(index)
        val selected = selectedOffer == offerId
        OutlinedButton(onClick = { selectedOffer = if (selected) null else offerId }, enabled = actions.any { it.enabled },
            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("contract.offer.$offerId"),
            border = BorderStroke(if (selected) 2.dp else 1.dp, if (selected) BaseballColors.action else BaseballColors.border)) {
            Text(teamName, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold)
        }
        row?.let { Text(it.value, verbatim = true, style = MaterialTheme.typography.bodyMedium) }
        if (selected) row?.let { if (it.detail.isNotBlank()) Text(it.detail, verbatim = true, style = MaterialTheme.typography.bodyMedium, color = BaseballColors.textSecondary) }
        if (selected) {
            Text("이 계약에 걸 목표", style = MaterialTheme.typography.labelLarge, color = BaseballColors.textSecondary)
            actions.forEach { action ->
                Phase8ActionButton(model.id, action.copy(label = action.label.substringAfter(" · ")), onAction, showDescription = true)
            }
        }
    }
    if (selectedOffer == null) Text("팀을 먼저 고른다. 목표는 그다음.", style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
    model.actions.filter { !it.id.startsWith("acceptOffer:") && it.enabled }.forEach { Phase8ActionButton(model.id, it, onAction) }
}

/** Draft day. Before the call: the player's face and one sentence. After: the verdict, big. */
@Composable
private fun Phase8DraftReveal(state: GameAggregateState, model: Phase8ScreenModel) {
    val run = state.highSchool?.run
    val name = run?.identity?.name.orEmpty()
    val first = model.sections.firstOrNull { it.id == "draft" }?.rows?.firstOrNull()
    val drafted = run?.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED
    val revealed = run?.draftResult != null
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
private fun Phase8DecisionChoices(state: GameAggregateState, model: Phase8ScreenModel, onAction: (Phase8UiAction) -> Unit) {
    val copy = rememberGameCopy()
    var details by rememberSaveable(model.id.wire) { mutableStateOf(false) }
    var roleChoices by rememberSaveable(state.pro?.careerId, state.pro?.season) { mutableStateOf(false) }
    when (model.id) {
        Phase8ScreenId.P007_RELATIONSHIP -> {
            val run = state.highSchool?.run
            val role = run?.let { RelationshipNarrative.speakerRole(it) }
            model.sections.firstOrNull()?.let { section ->
                Text(section.title, style = MaterialTheme.typography.titleMedium)
                section.rows.firstOrNull()?.let { row ->
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        when (role) {
                            "coach" -> PlayerPortrait(seed = run?.let(RelationshipNarrative::speaker) ?: row.label, role = AvatarRole.COACH, width = 44.dp, modifier = Modifier.testTag("relationship.portrait"))
                            "catcher" -> PlayerPortrait(seed = run?.let(RelationshipNarrative::speaker) ?: row.label, role = AvatarRole.CATCHER, width = 44.dp, modifier = Modifier.testTag("relationship.portrait"))
                            "rival" -> PlayerPortrait(seed = run?.let(RelationshipNarrative::speaker) ?: row.label, role = AvatarRole.RIVAL, width = 44.dp, modifier = Modifier.testTag("relationship.portrait"))
                            else -> Unit
                        }
                        Text(row.label, fontWeight = FontWeight.Bold)
                    }
                    Text(row.value, verbatim = true, style = MaterialTheme.typography.titleLarge)
                }
            }
        }
        Phase8ScreenId.P017_PRO_WEEK -> {
            state.pro?.let { pro -> Text("프로 선수 · ${pro.team.name} · ${if (pro.level == com.solkim.baseball.core.pro.ProLevel.MAJOR) "1군" else "2군"}",
                color = BaseballColors.milestone, style = MaterialTheme.typography.labelLarge) }
            model.sections.firstOrNull { it.id == "pitch-learning" }?.let { Phase8Sections(listOf(it)) }
            model.sections.firstOrNull { it.id.startsWith("followup:") }?.let { section ->
                section.rows.firstOrNull()?.let { CareerFact(it, "week.followup") }
            }
            val roles = model.actions.filter { it.id.startsWith("requestRole:") }
            if (roles.isNotEmpty()) {
                TextButton(onClick = { roleChoices = !roleChoices }) { Text(copy.resolve("android.week.role-request")) }
                if (roleChoices) roles.forEach { Phase8ActionButton(model.id, it, onAction) }
            } else model.sections.firstOrNull { it.id == "role-result" }?.let { Phase8Sections(listOf(it)) }
        }
        else -> Unit
    }
    if (model.id == Phase8ScreenId.P017_PRO_WEEK) {
        ProWeekPlanner(state, model, onAction)
        return
    }
    if (model.id == Phase8ScreenId.P007_RELATIONSHIP) {
        model.actions.filter { it.enabled }.forEach { action ->
            CompactChoiceCard(action.label, action.description, action.enabled, "action.${action.id}") {
                onAction(Phase8UiAction(model.id, action.id, action.payloads))
            }
            if (action.effects.size > com.solkim.baseball.application.ChoiceEffect.highlighted(action.effects).size) CareerDisclosure("효과 자세히", "effect.details.${action.id}") {
                action.effects.forEach { effect -> Text(effect.localized(copy), verbatim = true,
                    color = if (effect.favorable) BaseballColors.action else BaseballColors.warning) }
            }
        }
    } else Phase8ChoiceGrid(model, onAction)
    TextButton(onClick = { details = !details }) { Text(copy.resolve(if (details) "android.details.hide" else "android.details.show")) }
    if (details) Phase8Sections(model.sections.filterNot { it.id == "pitch-learning" || it.id.startsWith("followup:") || it.id == "role-result" })
}

@Composable
private fun Phase9ViewportCards(
    state: GameAggregateState,
    commandContext: Phase8CommandContext,
    model: Phase8ScreenModel,
    platformState: Phase9PlatformUiState,
    selectedLifeCardCareerId: String?,
    onExposed: (Phase9ViewportExposure) -> Unit,
) {
    if (state.meta.seedChallenge != null) return
    // Challenge snapshots are isolated from the lifetime analytics matrix. Do not even mount
    // exposure observers in that state, otherwise a visible card would enqueue a receipt that the
    // reducer correctly rejects and the in-process retry queue would live forever.
    if (state.highSchool?.challenge?.active == true) return
    val legacyCopy = rememberGameCopy()
    val run = state.highSchool?.run
    when (model.id) {
        Phase8ScreenId.P011_HIGH_SCHOOL_CAREER -> if (
            ReminderOfferPolicy.shouldShow(
                completedGameCount = state.highSchool?.completedGameCounter ?: 0UL,
                truth = platformState.notificationTruth,
                permissionAsked = platformState.notificationPermissionAsked,
                offerDeclined = platformState.reminderOfferDeclined,
                aggregateEnabled = state.settings.notificationsEnabled,
            )
        ) {
            Phase9ViewportExposureBox(
                exposure = Phase9ViewportExposure(
                    eventName = "reminder_offer_shown",
                    scope = "install:after-first-game",
                    properties = listOf("source" to "after_first_game"),
                ),
                onExposed = onExposed,
            ) {
                Phase8ReadOnlyRow("돌아올 때", "어디까지 했는지 알려 줄게", "첫 경기를 던졌으니, 다음에 열면 이어 할 장면부터 보여 준다.")
            }
        } else Unit
        Phase8ScreenId.P003_PROLOGUE -> if (run != null) {
            Phase9ViewportExposureBox(
                exposure = Phase9ViewportExposure(
                    eventName = "career_wind_seen",
                    scope = "career:${run.careerId}",
                    properties = listOf(
                        "wind_id" to HighSchoolDisplayRules.windIdFor(run.careerId),
                        "rules_version" to HighSchoolDisplayRules.windRulesVersion.toString(),
                    ),
                ),
                onExposed = onExposed,
            ) {
                Phase8ReadOnlyRow("이번 생의 바람", windLabel(HighSchoolDisplayRules.windIdFor(run.careerId)), "이 해의 분위기는 3년 내내 이어진다.")
            }
        } else Unit
        Phase8ScreenId.P007_RELATIONSHIP -> run?.currentRelationshipEvent?.let { event ->
            Phase9ViewportExposureBox(
                exposure = Phase9ViewportExposure(
                    eventName = "player_heartline_seen",
                    scope = "heartline:${run.careerId}:${event.id}",
                    properties = listOf(
                        "branch_id" to event.category,
                        "life_number" to run.lifeNumber.toString(),
                        "phase" to run.phase.wire,
                    ),
                ),
                onExposed = onExposed,
            ) {
                Phase8ReadOnlyRow("마음의 갈림길", event.title, event.summary)
            }
        } ?: Unit
        Phase8ScreenId.P014_RUN_RECAP -> {
            if (run != null && run.legacyOptions.isNotEmpty()) {
                Phase9ViewportExposureBox(
                    exposure = Phase9ViewportExposure(
                        eventName = "signature_legacy_options_seen",
                        scope = "legacy-options:${run.careerId}",
                        properties = listOf(
                            "life_number" to run.lifeNumber.toString(),
                            "drafted" to (run.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED).toString(),
                            "includes_pro_career" to (state.pro?.careerStats?.isNotEmpty() == true).toString(),
                            "option_ids" to run.legacyOptions.joinToString(","),
                        ),
                    ),
                    onExposed = onExposed,
                ) {
                    Phase8ReadOnlyRow("남길 수 있는 세 가지", run.legacyOptions.joinToString(" · ") { SignatureLegacyDisplay.title(it, legacyCopy) ?: "남겨진 유산" }, "하나만 다음 생으로 간다.")
                }
            }
            Phase9PlayerLegacyExposurePolicy.resolve(state, Phase9PlayerLegacyExposureSurface.RECAP)?.let { exposure ->
                Phase9ViewportExposureBox(
                    exposure = Phase9ViewportExposure(
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
                    Phase8ReadOnlyRow("이 생의 마지막 장", "기록은 남았다", "여기서 고른 하나가 다음 생으로 간다.")
                }
            }
        }
        Phase8ScreenId.P015_REBIRTH -> Phase9PlayerLegacyExposurePolicy.resolve(state, Phase9PlayerLegacyExposureSurface.NEXT_LIFE)?.let { exposure ->
            Phase9ViewportExposureBox(
                exposure = Phase9ViewportExposure(
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
                Phase8ReadOnlyRow("지난 생의 편지", "기록과 기억이 이어진다", "")
            }
        } ?: Unit
        Phase8ScreenId.P024_WEEKLY -> state.highSchool?.weekly?.let { weekly ->
            Phase9ViewportExposureBox(
                exposure = Phase9ViewportExposure(
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
                Phase8ReadOnlyRow("이번 주 기록", "${weekly.tasks.count { it.completed }}/${weekly.tasks.size} 과제", "")
            }
        } ?: Unit
        Phase8ScreenId.P028_LIFECARD -> Phase9LifeCardProjection.selected(state, selectedLifeCardCareerId)?.let { card ->
            val exposure = Phase9PlayerLegacyExposurePolicy.resolve(state, Phase9PlayerLegacyExposureSurface.ARCHIVE, card.careerId) ?: return@let
            Phase9ViewportExposureBox(
                exposure = Phase9ViewportExposure(
                    eventName = "player_legacy_seen",
                    scope = exposure.scope,
                    properties = listOf("source" to exposure.source, "life_number" to exposure.lifeNumber.toString(), "drafted" to exposure.drafted.toString(), "has_frozen_legacy" to exposure.hasFrozenLegacy.toString()),
                ),
                onExposed = onExposed,
            ) {
                LifeCardVisual(state = state, careerId = card.careerId)
            }
        } ?: Unit
        Phase8ScreenId.P029_RETURN_PLAN -> state.highSchool?.returnPlan?.takeUnless { it.dismissed }?.let { plan ->
            Phase9ViewportExposureBox(
                exposure = Phase9ViewportExposure(
                    eventName = "return_plan_shown",
                    scope = "plan:${plan.receiptId}",
                    properties = returnPlanExposureProperties(plan, commandContext.clock.today().toString()),
                ),
                onExposed = onExposed,
            ) {
                Phase8ReadOnlyRow("저장된 복귀 계획", plan.destination.labelForProduct(), plan.reason)
            }
        } ?: Unit
        else -> Unit
    }
}

@Composable
public fun Phase9ViewportExposureBox(
    exposure: Phase9ViewportExposure,
    onExposed: (Phase9ViewportExposure) -> Unit,
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
    val record = state.highSchool?.archive?.firstOrNull { it.careerId == careerId } ?: return
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
internal fun playerPortraitSeed(state: GameAggregateState): String? =
    lineagePortraitSeed(state)
        ?: state.pro?.identityName?.takeIf { it.isNotBlank() }
        ?: state.highSchool?.run?.identity?.name?.takeIf { it.isNotBlank() }

internal fun lineagePortraitSeed(state: GameAggregateState): String? =
    state.highSchool?.archive?.firstOrNull()?.playerName?.takeIf { it.isNotBlank() }

/** Last three lives in one line: who they were and how it ended. */
internal fun lineageLine(state: GameAggregateState, upToLife: Int? = null): String? {
    val records = state.highSchool?.archive.orEmpty().filter { upToLife == null || it.lifeNumber <= upToLife }.takeLast(3)
    if (records.isEmpty()) return null
    return "계보 " + records.joinToString(" → ") { "${it.lifeNumber}생 ${it.playerName} ${if (it.drafted) "지명" else "미지명"} K${it.strikeouts}" }
}

private fun windLabel(id: String): String = when (id) {
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

private fun returnPlanExposureProperties(
    plan: HighSchoolReturnPlan,
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

private fun HighSchoolReturnDestination.labelForProduct(): String =
    HighSchoolDisplayRules.returnDestinationProductLabel(this)

@Composable
@OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)
private fun ColumnScope.Phase8SetupFields(
    state: GameAggregateState,
    commandContext: Phase8CommandContext,
    model: Phase8ScreenModel,
    onAction: (Phase8UiAction) -> Unit,
    busy: Boolean = false,
) {
    val gameCopy = rememberGameCopy()
    val setupAction = model.actions.single { it.id == "startHighSchool" }
    val secondLife = (state.highSchool?.archive?.size ?: 0) >= 1 || state.meta.retiredProCareers.isNotEmpty()
    val lastStep = if (secondLife) 3 else 1
    // The reborn player keeps their name unless they type a new one.
    val carriedName = if (secondLife && state.meta.seedChallenge == null)
        state.highSchool?.archive?.lastOrNull()?.playerName?.takeIf { it.isNotBlank() } ?: state.meta.retiredProCareers.lastOrNull()?.identityName?.takeIf { it.isNotBlank() }
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
    val soulBalance = state.highSchool?.inheritance?.soulPoints ?: state.meta.standaloneSoulBalance
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
                            com.solkim.baseball.application.GameCopyArgument.Whole(preset.baseStuff.toLong()),
                            com.solkim.baseball.application.GameCopyArgument.Whole(preset.baseCommand.toLong()),
                            com.solkim.baseball.application.GameCopyArgument.Whole(preset.baseMovement.toLong()),
                            com.solkim.baseball.application.GameCopyArgument.Whole(preset.baseStamina.toLong())) +
                            if (selected) " · " + gameCopy.legacy("선택됨") else ""),
                ) {
                    Text(presetTitle(preset.id), fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal)
                }
            }
            val chosenPreset = HighSchoolDisplayRules.presets.single { it.id == presetId }
            Text("선택한 유형의 기본 능력", style = MaterialTheme.typography.labelMedium)
            Column(Modifier.testTag("setup.preset.stats")) {
                CareerStatTiles(listOf("구위" to chosenPreset.baseStuff.toString(), "제구" to chosenPreset.baseCommand.toString(),
                    "무브먼트" to chosenPreset.baseMovement.toString(), "체력" to chosenPreset.baseStamina.toString()))
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
    AdaptiveActionRow(modifier = Modifier.fillMaxWidth()) {
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
                    val command = Phase8Payloads.startHighSchool(
                        state,
                        finalName,
                        region,
                        presetId,
                        commandContext,
                        throwingHand,
                        karmas.toList(),
                        (state.highSchool?.archive?.size ?: 0) + 1,
                        difficulty = SetupDifficulty(careerHarshness = harshness),
                        soulDomain = SetupSoulDomain.entries.single { it.wire == soulDomain },
                        soulBoosts = boosts,
                        primaryPitch = SetupPitch.entries.single { it.wire == primaryPitch },
                        learningPitch = SetupPitch.entries.single { it.wire == learningPitch },
                    )
                    val payloads = Phase8Payloads.batch(state, model.id, setupAction.id, listOf(command))
                    onAction(Phase8UiAction(model.id, setupAction.id, payloads))
                },
                enabled = valid && !busy,
                modifier = Modifier.heightIn(min = 48.dp).testTag("setup.confirm"),
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

@Composable
private fun Phase8ReadOnlyRow(label: String, value: String, detail: String) {
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
private fun Phase8ChoiceGrid(
    model: Phase8ScreenModel,
    onAction: (Phase8UiAction) -> Unit,
) {
    if (model.actions.isEmpty()) return
    val heading = when (model.id) {
        Phase8ScreenId.P006_TRAINING -> stringResource(R.string.choice_heading_training)
        Phase8ScreenId.P007_RELATIONSHIP -> stringResource(R.string.choice_heading_relationship)
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
                        onClick = { onAction(Phase8UiAction(model.id, action.id, action.payloads)) },
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
            onClick = { onAction(Phase8UiAction(model.id, action.id, action.payloads)) },
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
private fun Phase8ShareButton(
    state: GameAggregateState,
    model: Phase8ScreenModel,
) {
    val copy = rememberGameCopy()
    val rawText = when {
        state.meta.seedChallenge != null && model.id in setOf(Phase8ScreenId.P013_DRAFT, Phase8ScreenId.P014_RUN_RECAP, Phase8ScreenId.P025_RECORDS_LEAGUE) -> CareerShareCopy.challenge(state)
        else -> when (model.id) {
        Phase8ScreenId.P013_DRAFT -> CareerShareCopy.draft(state)
        Phase8ScreenId.P019_PRO_SEASON -> CareerShareCopy.nationalMedal(state)
        Phase8ScreenId.P021_PRO_RETIREMENT -> CareerShareCopy.retirement(state)
        Phase8ScreenId.P015_REBIRTH -> CareerShareCopy.retirement(state) ?: CareerShareCopy.draft(state)
        Phase8ScreenId.P025_RECORDS_LEAGUE -> CareerShareCopy.retirement(state) ?: CareerShareCopy.records(state)
        else -> null
        }
    } ?: return
    val names = if (state.meta.seedChallenge == null) setOfNotNull(state.highSchool?.run?.identity?.name, state.pro?.identityName) else emptySet()
    val text = copy.legacy(rawText, names)
    val context = LocalContext.current
    val title = if (state.meta.seedChallenge != null) copy.resolve("android.challenge.result") else when (model.id) {
        Phase8ScreenId.P013_DRAFT -> stringResource(R.string.share_draft_title)
        Phase8ScreenId.P019_PRO_SEASON -> stringResource(R.string.share_national_title)
        Phase8ScreenId.P021_PRO_RETIREMENT -> stringResource(R.string.share_retirement_title)
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
private fun Phase8Actions(
    model: Phase8ScreenModel,
    onAction: (Phase8UiAction) -> Unit,
) {
    val actions = if (model.id in setOf(Phase8ScreenId.P008_IMPORTANT_GAME, Phase8ScreenId.P018_PRO_IMPORTANT_GAME)) model.actions.filter { it.enabled } else model.actions
    if (actions.isEmpty()) return
    HorizontalDivider()
    actions.forEach { action ->
        Phase8ActionButton(model.id, action, onAction, showDescription = model.id.group == Phase8Group.PRO && actions.count { it.enabled } > 1)
    }
}

@Composable
private fun Phase8ActionButton(
    screenId: Phase8ScreenId,
    action: Phase8ActionModel,
    onAction: (Phase8UiAction) -> Unit,
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
    val description = if (action.enabled) action.contentDescription else "${action.label}. 아직 열리지 않았다."
    if (action.destructive) {
        OutlinedButton(
            onClick = { onAction(Phase8UiAction(screenId, action.id, action.payloads)) },
            enabled = action.enabled,
            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("action.${action.id}").gameDescription(description),
        ) { Text(label, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.error) }
    } else {
        Button(
            onClick = { onAction(Phase8UiAction(screenId, action.id, action.payloads)) },
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
private fun Phase8ErrorCard(message: String) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)) {
        Text(
            message,
            modifier = Modifier.padding(16.dp).gameDescription(message),
            color = MaterialTheme.colorScheme.onErrorContainer,
        )
    }
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

@Composable
private fun ProductNavigation(state: GameAggregateState, currentTab: ProductTab, onNavigate: (Phase8ScreenId) -> Unit) {
            NavigationBar(
                modifier = Modifier.heightIn(min = if (androidx.compose.ui.platform.LocalDensity.current.fontScale >= 1.5f) 112.dp else 80.dp),
                containerColor = BaseballColors.surface,
                tonalElevation = 0.dp,
            ) {
                ProductTab.entries.forEach { tab ->
                    val destination = tab.landingScreen(state)
                    val isSelected = tab == currentTab
                    NavigationBarItem(
                        modifier = Modifier.testTag("navigation.${tab.name.lowercase()}"),
                        selected = isSelected,
                        onClick = { destination?.let(onNavigate) },
                        enabled = destination != null,
                        icon = {
                            TabIcon(tab = tab, isSelected = isSelected)
                        },
                        label = {
                            Text(
                                text = tab.label,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                            )
                        },
                        colors = NavigationBarItemDefaults.colors(
                            indicatorColor = Color.Transparent,
                            selectedIconColor = BaseballColors.action,
                            selectedTextColor = BaseballColors.action,
                            unselectedIconColor = BaseballColors.textTertiary,
                            unselectedTextColor = BaseballColors.textTertiary,
                        ),
                    )
                }
            }
}
