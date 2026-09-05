package com.solkim.baseball.android

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
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalView
import androidx.compose.material3.Button
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
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.CareerShareCopy
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
    val currentTab = ProductTab.forScreen(visibleScreen)
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

    val pinnedAction = if (visibleScreen == Phase8ScreenId.P015_REBIRTH) model.actions.firstOrNull { it.id == "quickRebirth" && it.enabled }
        else if (visibleScreen in setOf(Phase8ScreenId.P008_IMPORTANT_GAME, Phase8ScreenId.P010_CHAPTER, Phase8ScreenId.P013_DRAFT))
        model.actions.firstOrNull { it.enabled } else null

    Scaffold(
        modifier = Modifier.fillMaxSize().semantics { testTagsAsResourceId = true },
        containerColor = BaseballColors.canvas,
        topBar = {
            val preferred = Phase8ScreenProjection.preferredScreen(state)
            if (!isFirstPlay) TopAppBar(
                title = { Text(if (state.meta.seedChallenge != null) gameCopy.resolve("android.challenge.screen-title", com.solkim.baseball.application.GameCopyArgument.UserText(model.title)) else model.title, style = MaterialTheme.typography.titleLarge) },
                actions = {
                    if (state.meta.seedChallenge != null) TextButton(onClick = onExitSeedChallenge, enabled = !busy, modifier = Modifier.testTag("challenge.exit")) { Text(gameCopy.resolve("android.challenge.exit")) }
                    else if (visibleScreen == Phase8ScreenId.P027_SETTINGS) TextButton(onClick = onSeedChallenge) { Text(gameCopy.resolve("android.challenge.open")) }
                },
                navigationIcon = {
                    if (visibleScreen != preferred) {
                        TextButton(onClick = { onNavigate(preferred) }) {
                            Text("← 이야기", color = BaseballColors.action, fontWeight = FontWeight.SemiBold)
                        }
                    }
                },
            )
        },
        bottomBar = {
            Column {
                if (pinnedAction != null) Box(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp)) {
                    Phase8ActionButton(model.id, pinnedAction.copy(enabled = !busy), onAction)
                }
            if (!isFirstPlay) NavigationBar(
                modifier = Modifier.heightIn(min = if (androidx.compose.ui.platform.LocalDensity.current.fontScale >= 1.5f) 112.dp else 80.dp),
                containerColor = BaseballColors.surface,
                tonalElevation = 0.dp,
            ) {
                ProductTab.entries.forEach { tab ->
                    val destination = tab.landingScreen(state)
                    val isSelected = tab == currentTab
                    NavigationBarItem(
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
        },
    ) { insets ->
        if (visibleScreen == Phase8ScreenId.P001_OPENING) {
            Column(Modifier.fillMaxSize().padding(insets).padding(horizontal = 24.dp, vertical = 20.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp)) {
                Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(22.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                        TextButton(onClick = onSeedChallenge) { Text(gameCopy.resolve(if (pendingSeedCode == null) "android.challenge.open" else "android.challenge.pending")) }
                        TextButton(onClick = { onNavigate(Phase8ScreenId.P027_SETTINGS) }) { Text("설정") }
                    }
                    Text("환생 투수 커리어", color = BaseballColors.milestone, style = MaterialTheme.typography.titleMedium)
                    Text("한 구를 던지고,\n한 생을 남기세요.", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
                    Text("고교에서 배우고, 프로에서 승부하고, 은퇴 뒤에는 다음 생으로 이어집니다.", style = MaterialTheme.typography.bodyLarge)
                    Card(colors = CardDefaults.cardColors(containerColor = BaseballColors.surfaceRaised)) {
                        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("누르고 초록 구간에서 놓기", fontWeight = FontWeight.Bold)
                            Text("슬라이더의 타이밍을 직접 맞춰 공을 던집니다. 처음에는 포수의 사인을 따라 해 보세요.", style = MaterialTheme.typography.bodyMedium)
                        }
                    }
                    Text("진행은 자동으로 저장됩니다.", color = BaseballColors.textSecondary, style = MaterialTheme.typography.bodyMedium)
                }
                model.actions.singleOrNull { it.id == "enterSetup" }?.let { action ->
                    Phase8ActionButton(model.id, action, onAction, showDescription = false)
                }
            }
        } else if (visibleScreen == Phase8ScreenId.P002_SETUP) {
            Column(Modifier.fillMaxSize().padding(insets).consumeWindowInsets(insets).imePadding().padding(horizontal = 20.dp, vertical = 12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (actionError != null) Phase8ErrorCard(actionError)
                Phase8SetupFields(state, commandContext, model, onAction)
            }
        } else if (visibleScreen == Phase8ScreenId.P006_TRAINING) {
            TrainingScreen(state, commandContext, busy, actionError, insets, trainingResultStart, dismissedTraining,
                spotlight = showGrowthSpotlight,
                onDismiss = { dismissedTraining = state.highSchool?.run?.lastTraining?.number ?: 0 },
                onCommit = { action ->
                    trainingResultStart = state.highSchool?.run?.totalTrainingsCompleted ?: 0
                    dismissedTraining = state.highSchool?.run?.lastTraining?.number ?: 0
                    onAction(action)
                })
        } else if (visibleScreen in setOf(Phase8ScreenId.P003_PROLOGUE, Phase8ScreenId.P004_PITCH_TUTORIAL)) {
            Phase8FirstPitchIntroduction(state, model, busy, actionError, insets, onAction)
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

            if (model.id.group in setOf(Phase8Group.CAREER_CORE, Phase8Group.PRO, Phase8Group.RECAP_REBIRTH)) {
                CorePlayerHeader(state, compact = true)
            }

            if (visibleScreen in setOf(Phase8ScreenId.P007_RELATIONSHIP, Phase8ScreenId.P008_IMPORTANT_GAME, Phase8ScreenId.P009_AWAKENING, Phase8ScreenId.P010_CHAPTER) &&
                (state.highSchool?.run?.lastTraining?.number ?: 0) > dismissedTraining) {
                TrainingResultCard(state, trainingResultStart, !showGrowthSpotlight) { dismissedTraining = state.highSchool?.run?.lastTraining?.number ?: 0 }
            }
            val growth = state.meta.playerGrowth?.takeIf {
                it.source != "training" && it.careerId == (state.pro?.takeIf { state.stage in setOf(com.solkim.baseball.application.GameStage.PRO, com.solkim.baseball.application.GameStage.RETIREMENT) }?.careerId ?: state.highSchool?.run?.careerId)
                    && it.before != it.after
            }
            var dismissedGrowth by rememberSaveable { mutableStateOf<String?>(null) }
            if (growth != null && dismissedGrowth != growth.commandId) Card {
                Column(Modifier.padding(16.dp)) {
                    CoreGrowthResult(growth, compact = !showGrowthSpotlight)
                    TextButton(onClick = { dismissedGrowth = growth.commandId }) { Text("닫기") }
                }
            }
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
private fun Phase8FirstPitchIntroduction(
    state: GameAggregateState,
    model: Phase8ScreenModel,
    busy: Boolean,
    actionError: String?,
    insets: androidx.compose.foundation.layout.PaddingValues,
    onAction: (Phase8UiAction) -> Unit,
) {
    val isLetter = model.id == Phase8ScreenId.P003_PROLOGUE
    Column(Modifier.fillMaxSize().padding(insets).padding(horizontal = 24.dp, vertical = 20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)) {
        Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(20.dp)) {
            if (actionError != null) Phase8ErrorCard(actionError)
            if (isLetter) {
                state.highSchool?.run?.identity?.name?.let { name ->
                    Text(name, verbatim = true, style = MaterialTheme.typography.titleMedium)
                }
                Text("도착한 편지", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                model.sections.firstOrNull { it.id == "letter" }?.rows?.getOrNull(1)?.let { letter ->
                    Text(letter.value, verbatim = true, style = MaterialTheme.typography.bodyLarge)
                }
                Text(if (state.highSchool?.tutorial?.started == true) "첫 공의 감각을 기억하며, 이제 나의 학교를 고릅니다." else "마운드에서 포수의 첫 사인을 기다립니다.",
                    style = MaterialTheme.typography.bodyLarge)
            } else {
                Text("누르고 초록 구간에서 놓기", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                Text("누른 채 조준을 맞추고, 슬라이더가 초록 구간에 오면 손을 뗍니다.", style = MaterialTheme.typography.bodyLarge)
                Text("처음에는 포수의 사인을 따라 던져 보세요.", style = MaterialTheme.typography.bodyLarge)
            }
        }
        // Keep the next action stable while saves finish; transient save rows must not move it.
        model.actions.filter { it.enabled }.forEach { action ->
            Phase8ActionButton(model.id, action.copy(enabled = !busy), onAction, showDescription = false)
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
        fun forScreen(screen: Phase8ScreenId): ProductTab = when (screen.group) {
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
            .fillMaxWidth()
            .gameDescription(model.contentDescription),
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
                    Phase8ScreenId.P005_SCHOOL_SELECTION -> Phase8SchoolChoices(model, onAction)
                    Phase8ScreenId.P006_TRAINING, Phase8ScreenId.P007_RELATIONSHIP, Phase8ScreenId.P017_PRO_WEEK ->
                        Phase8DecisionChoices(state, model, onAction)
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
                Phase8ShareButton(state, model)
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
    if (model.id == Phase8ScreenId.P015_REBIRTH && model.actions.any { it.id == "quickRebirth" && it.enabled }) {
        model.sections.firstOrNull { it.id == "rebirth" }?.rows?.firstOrNull()?.let { inherited ->
            Text(copy.resolve("mobile.core.inherited"), verbatim = true, style = MaterialTheme.typography.labelLarge, color = BaseballColors.textSecondary)
            Text(inherited.value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            if (inherited.detail.isNotBlank()) Text(inherited.detail, style = MaterialTheme.typography.bodyMedium, color = BaseballColors.milestone)
        }
        model.sections.firstOrNull { it.id == "rebirth" }?.rows?.getOrNull(1)?.takeIf { it.value.toIntOrNull()?.let { count -> count > 0 } == true }?.let {
            Text("${it.label} ${it.value}", style = MaterialTheme.typography.bodySmall)
        }
    } else Phase8Sections(model.sections)
    val actions = model.actions.filter { action ->
        action.enabled && action.id !in setOf("confirmRecap", "confirmDraftResult") &&
            (action.id != "prepareLegacy" || model.actions.none { it.enabled && it.id.startsWith("selectLegacy:") })
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
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                legacyActions.forEach { action -> Phase8ActionButton(model.id, action, onAction, showDescription = true) }
            }
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

@Composable
private fun Phase8SchoolChoices(model: Phase8ScreenModel, onAction: (Phase8UiAction) -> Unit) {
    val copy = rememberGameCopy()
    Text(copy.resolve("android.school.question"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    model.actions.forEach { action ->
        val people = model.sections.flatMap { it.rows }.firstOrNull { it.label == action.label }?.detail.orEmpty()
        OutlinedButton(onClick = { onAction(Phase8UiAction(model.id, action.id, action.payloads)) }, enabled = action.enabled,
            modifier = Modifier.fillMaxWidth().heightIn(min = 72.dp).testTag("action.${action.id}")) {
            Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(action.label, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Text(action.description, style = MaterialTheme.typography.bodyMedium)
                if (people.isNotBlank()) Text(people, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun Phase8DecisionChoices(state: GameAggregateState, model: Phase8ScreenModel, onAction: (Phase8UiAction) -> Unit) {
    val copy = rememberGameCopy()
    var details by rememberSaveable(model.id.wire) { mutableStateOf(false) }
    var roleChoices by rememberSaveable(state.pro?.careerId, state.pro?.season) { mutableStateOf(false) }
    when (model.id) {
        Phase8ScreenId.P006_TRAINING -> {
            Text(copy.resolve("android.training.question"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text(copy.resolve("android.training.condition", com.solkim.baseball.application.GameCopyArgument.Whole((state.highSchool?.run?.fatigue ?: 0).toLong()),
                com.solkim.baseball.application.GameCopyArgument.Whole((state.highSchool?.run?.armRisk ?: 0).toLong())),
                color = if ((state.highSchool?.run?.fatigue ?: 0) >= 60) BaseballColors.warning else MaterialTheme.colorScheme.onSurfaceVariant)
            if ((state.highSchool?.run?.fatigue ?: 0) >= 60) Text(copy.resolve("android.training.recovery-hint"), color = BaseballColors.warning)
            model.sections.firstOrNull { it.id == "training" }?.rows?.firstOrNull()?.let { Text(it.detail, style = MaterialTheme.typography.bodyMedium) }
        }
        Phase8ScreenId.P007_RELATIONSHIP -> {
            model.sections.firstOrNull()?.let { section ->
                Text(section.title, style = MaterialTheme.typography.titleMedium)
                section.rows.firstOrNull()?.let { row ->
                    Text(row.label, fontWeight = FontWeight.Bold)
                    Text(row.value, verbatim = true, style = MaterialTheme.typography.titleLarge)
                }
            }
        }
        Phase8ScreenId.P017_PRO_WEEK -> {
            Text(copy.resolve("android.week.question"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text(copy.resolve("android.week.condition", com.solkim.baseball.application.GameCopyArgument.Whole((state.pro?.week ?: 0).toLong()),
                com.solkim.baseball.application.GameCopyArgument.Whole((state.pro?.fatigue ?: 0).toLong())))
            model.sections.firstOrNull { it.id == "pitch-learning" }?.let { Phase8Sections(listOf(it)) }
            model.sections.firstOrNull { it.id.startsWith("followup:") }?.let { Phase8Sections(listOf(it)) }
            val roles = model.actions.filter { it.id.startsWith("requestRole:") }
            if (roles.isNotEmpty()) {
                TextButton(onClick = { roleChoices = !roleChoices }) { Text(copy.resolve("android.week.role-request")) }
                if (roleChoices) roles.forEach { Phase8ActionButton(model.id, it, onAction) }
            } else model.sections.firstOrNull { it.id == "role-result" }?.let { Phase8Sections(listOf(it)) }
        }
        else -> Unit
    }
    if (model.id == Phase8ScreenId.P007_RELATIONSHIP) {
        model.actions.forEach { action -> Phase8ActionButton(model.id, action, onAction, showDescription = true) }
    } else Phase8ChoiceGrid(model, onAction)
    TextButton(onClick = { details = !details }) { Text(copy.resolve(if (details) "android.details.hide" else "android.details.show")) }
    if (details) Phase8Sections(model.sections)
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
                Phase8ReadOnlyRow("복귀 안내", "다음 장면을 놓치지 않기", "첫 공식 경기 뒤, 다음에 돌아올 때 이어 볼 장면을 안내할 수 있어요.")
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
                Phase8ReadOnlyRow("이번 생의 바람", windLabel(HighSchoolDisplayRules.windIdFor(run.careerId)), "이번 생의 흐름은 같은 규칙으로 끝까지 이어집니다.")
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
                    Phase8ReadOnlyRow("대표 유산 후보", run.legacyOptions.joinToString(" · ") { "후보 ${it.take(12)}" }, "이번 생의 기록에서 얼어붙은 세 가지 선택입니다.")
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
                    Phase8ReadOnlyRow("이번 생의 동결 기록", "최종 결산", "현재 생이 최종 확정된 뒤에만 이 기록을 보여 줍니다.")
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
                Phase8ReadOnlyRow("이전 생의 편지", "다음 생에 남은 기록", "지난 생에 남긴 기록과 기억이 이어집니다.")
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
                Phase8ReadOnlyRow("이번 주 기록", "${weekly.tasks.count { it.completed }}/${weekly.tasks.size} 과제", "이번 주의 작은 목표를 확인합니다.")
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
                    seed = record.playerName,
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
            Text("스카우트 평가 ${record.draftEvaluation}", style = MaterialTheme.typography.bodyMedium, color = BaseballColors.textTertiary)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                listOf(
                    "경기" to record.importantGames.toString(),
                    "삼진" to record.strikeouts.toString(),
                    "볼넷" to record.walks.toString(),
                    "실점" to record.runsAllowed.toString(),
                ).forEach { (label, value) ->
                    Column(horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally) {
                        Text(value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                        Text(label, style = MaterialTheme.typography.labelSmall, color = BaseballColors.textTertiary)
                    }
                }
            }
            Text("능력 ${record.ratings.map(AbilityDisplayScale::rating).joinToString(" · ")}", style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
        }
    }
}

internal fun playerPortraitSeed(state: GameAggregateState): String? =
    state.pro?.identityName?.takeIf { it.isNotBlank() }
        ?: state.highSchool?.run?.identity?.name?.takeIf { it.isNotBlank() }

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
) {
    val gameCopy = rememberGameCopy()
    val setupAction = model.actions.single { it.id == "startHighSchool" }
    val secondLife = (state.highSchool?.archive?.size ?: 0) >= 1 || state.meta.retiredProCareers.isNotEmpty()
    val lastStep = if (secondLife) 4 else 2
    var step by rememberSaveable(model.id.wire + ":step") { mutableStateOf(0) }
    var name by rememberSaveable(model.id.wire) { mutableStateOf("") }
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
            OutlinedTextField(
                value = name,
                onValueChange = { name = it.take(12) },
                label = { Text("선수 이름") },
                supportingText = { Text("비워 두면 민서준으로 시작합니다") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth().testTag("setup.name"),
            )
        }
        1 -> {
            Text("지역", style = MaterialTheme.typography.titleSmall)
            Box {
                OutlinedButton(
                    onClick = { regionMenuExpanded = true },
                    modifier = Modifier
                        .fillMaxWidth().heightIn(min = 56.dp).testTag("setup.region")
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
        2 -> {
            Text("투구 손", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(onClick = { throwingHand = "right" }) {
                    Text(if (throwingHand == "right") "우투 · 선택됨" else "우투")
                }
                OutlinedButton(onClick = { throwingHand = "left" }) {
                    Text(if (throwingHand == "left") "좌투 · 선택됨" else "좌투")
                }
            }
            Text("성장 방식", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
            HighSchoolDisplayRules.presets.forEach { preset ->
                val selected = preset.id == presetId
                OutlinedButton(
                    onClick = {
                        presetId = preset.id
                        primaryPitch = SetupRepertoire.primary(preset.id).wire
                        learningPitch = SetupRepertoire.learning(preset.id).wire
                    },
                    modifier = Modifier
                        .heightIn(min = 56.dp)
                        .gameDescription(gameCopy.resolve("android.setup.preset-description",
                            com.solkim.baseball.application.GameCopyArgument.UserText(gameCopy.legacy(presetTitle(preset.id))),
                            com.solkim.baseball.application.GameCopyArgument.Whole(preset.baseStuff.toLong()),
                            com.solkim.baseball.application.GameCopyArgument.Whole(preset.baseCommand.toLong()),
                            com.solkim.baseball.application.GameCopyArgument.Whole(preset.baseMovement.toLong()),
                            com.solkim.baseball.application.GameCopyArgument.Whole(preset.baseStamina.toLong())) +
                            if (selected) " · " + gameCopy.legacy("선택됨") else ""),
                ) {
                    Column(Modifier.fillMaxWidth()) {
                        Text(presetTitle(preset.id), fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal)
                        Text("구위 ${preset.baseStuff} · 제구 ${preset.baseCommand} · 무브먼트 ${preset.baseMovement} · 체력 ${preset.baseStamina}", style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        }
        3 -> {
            Text(presetTitle(presetId), fontWeight = FontWeight.SemiBold)
            Text(presetRepertoireLine(presetId), style = MaterialTheme.typography.bodyLarge)
            Text("배우는 구종", style = MaterialTheme.typography.titleSmall)
            SetupPitch.entries.filter { it != SetupPitch.FOUR_SEAM }.forEach { pitch ->
                OutlinedButton(onClick = { learningPitch = pitch.wire; if (primaryPitch == learningPitch) primaryPitch = "four_seam" }, modifier = Modifier.fillMaxWidth()) {
                    Text("${setupPitchLabel(pitch)}${if (learningPitch == pitch.wire) " · 선택됨" else ""}")
                }
            }
            Text("주 구종", style = MaterialTheme.typography.titleSmall)
            SetupPitch.entries.filter { it.wire != learningPitch }.forEach { pitch ->
                OutlinedButton(onClick = { primaryPitch = pitch.wire }, modifier = Modifier.fillMaxWidth()) {
                    Text("${setupPitchLabel(pitch)}${if (primaryPitch == pitch.wire) " · 선택됨" else ""}")
                }
            }
        }
        else -> {
            Text("이번 생의 난이도", style = MaterialTheme.typography.titleSmall)
            listOf("relaxed" to "부드럽게", "standard" to "표준", "challenging" to "혹독하게").forEach { (id, label) ->
                OutlinedButton(onClick = { harshness = id }) { Text(if (harshness == id) "$label · 선택됨" else label) }
            }
            Text("야구혼 계승 분야", style = MaterialTheme.typography.titleSmall)
            listOf("body" to "몸 · 구위", "technique" to "기술 · 제구", "game" to "경기 · 운영").forEach { (id, label) ->
                OutlinedButton(onClick = { soulDomain = id }) { Text(if (soulDomain == id) "$label · 선택됨" else label) }
            }
            Text("영혼 상점 · 잔액 $soulBalance · 사용 $boostCost", style = MaterialTheme.typography.titleSmall)
            SetupSoulBoost.entries.forEach { boost ->
                val selected = boost in boosts
                OutlinedButton(
                    onClick = { selectedBoostIds = (if (selected) boosts - boost else boosts + boost).joinToString(",") { it.wire } },
                    enabled = selected || boostCost + boost.cost <= soulBalance,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("${setupBoostLabel(boost)} · ${boost.cost}${if (selected) " · 선택됨" else ""}") }
            }
            Text("이번 생의 핸디캡을 고를 수 있습니다. 최대 두 개입니다.", style = MaterialTheme.typography.bodyLarge)
            listOf(
                "unknown_land" to "낯선 땅",
                "stubborn_coach" to "고집 센 코치",
                "single_weapon" to "한 가지 무기",
                "genius_generation" to "천재들의 기수",
            ).forEach { (id, label) ->
                val selected = id in karmas
                OutlinedButton(
                    onClick = {
                        val next = karmas.toMutableSet()
                        if (selected) next.remove(id) else if (next.size < 2) next.add(id)
                        selectedKarmas = next.joinToString(",")
                    },
                ) {
                    Text(if (selected) "$label · 선택됨" else label)
                }
            }
        }
    }
    }
    val canAdvance = when (step) {
        0 -> true
        1 -> region in HighSchoolDisplayRules.regions
        else -> true
    }
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
        if (step > 0) {
            OutlinedButton(onClick = { step -= 1 }, modifier = Modifier.weight(1f).heightIn(min = 56.dp)) {
                Text("이전")
            }
        }
        if (step < lastStep) {
            Button(
                onClick = { if (canAdvance) step += 1 },
                enabled = canAdvance,
                modifier = Modifier.weight(1f).heightIn(min = 56.dp).testTag("setup.next"),
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
                enabled = valid,
                modifier = Modifier.weight(1f).heightIn(min = 56.dp).testTag("setup.confirm"),
            ) { Text("이 투수로 시작하기") }
        }
    }
}

private fun setupStepTitle(step: Int): String = when (step) {
    0 -> "어떤 이름으로 불릴까요?"
    1 -> "어디에서 시작할까요?"
    2 -> "어떤 투수가 되고 싶나요?"
    3 -> "어떤 공으로 승부할까요?"
    else -> "이번 생에는 무엇을 이어받을까요?"
}

private fun presetRepertoireLine(id: String): String = when (id) {
    "power_prospect" -> "주 구종 포심 · 배우는 구종 체인지업"
    "precision_commander" -> "주 구종 포심 · 배우는 구종 커브"
    "breaking_ball_artist" -> "주 구종 슬라이더 · 배우는 구종 체인지업"
    "innings_eater" -> "주 구종 포심 · 배우는 구종 체인지업"
    else -> "주 구종 포심 · 배우는 구종 슬라이더"
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
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            row.forEach { action ->
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Button(
                        onClick = { onAction(Phase8UiAction(model.id, action.id, action.payloads)) },
                        enabled = action.enabled,
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 56.dp)
                            .testTag("action.${action.id}").gameDescription(action.contentDescription),
                    ) { Text(action.label) }
                    Text(
                        action.description,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            if (row.size == 1) Spacer(Modifier.weight(1f))
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
    if (model.actions.isEmpty()) return
    HorizontalDivider()
    Text("다음 선택", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
    model.actions.forEach { action ->
        Phase8ActionButton(model.id, action, onAction, showDescription = model.id.group == Phase8Group.PRO && model.actions.count { it.enabled } > 1)
    }
}

@Composable
private fun Phase8ActionButton(
    screenId: Phase8ScreenId,
    action: Phase8ActionModel,
    onAction: (Phase8UiAction) -> Unit,
    showDescription: Boolean = false,
) {
    val description = if (action.enabled) action.contentDescription else "${action.label}. ${action.description}. 지금은 선택할 수 없습니다."
    if (action.destructive) {
        OutlinedButton(
            onClick = { onAction(Phase8UiAction(screenId, action.id, action.payloads)) },
            enabled = action.enabled,
            modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).testTag("action.${action.id}").gameDescription(description),
        ) { Text(action.label, color = MaterialTheme.colorScheme.error) }
    } else {
        Button(
            onClick = { onAction(Phase8UiAction(screenId, action.id, action.payloads)) },
            enabled = action.enabled,
            modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).testTag("action.${action.id}").gameDescription(description),
        ) { Text(action.label) }
    }
    if (showDescription || action.destructive || !action.enabled) Text(
        if (action.enabled) action.description else "이 장면에서는 아직 선택할 수 없습니다.",
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
