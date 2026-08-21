package com.solkim.baseball.android

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import com.solkim.baseball.core.portrait.AvatarRole
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
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import com.solkim.baseball.application.Phase8Group
import com.solkim.baseball.design.BaseballColors
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
import com.solkim.baseball.core.highschool.HighSchoolContentCatalog
import com.solkim.baseball.core.highschool.HighSchoolWindRules
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
@OptIn(ExperimentalMaterial3Api::class)
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
) {
    val preferred = Phase8ScreenProjection.preferredScreen(state)
    val visibleScreen = currentScreen.takeIf {
        Phase8ScreenProjection.isReachable(state, it) || it == preferred
    } ?: preferred
    val model = Phase8ScreenProjection.project(state, visibleScreen, commandContext)
    val currentTab = ProductTab.forScreen(visibleScreen)

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        containerColor = BaseballColors.canvas,
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("야구 못하면 또 환생함", style = MaterialTheme.typography.titleLarge)
                        Text(model.title, style = MaterialTheme.typography.labelMedium)
                    }
                },
            )
        },
        bottomBar = {
            NavigationBar(containerColor = BaseballColors.surface) {
                ProductTab.entries.forEach { tab ->
                    val destination = tab.landingScreen(state)
                    NavigationBarItem(
                        selected = tab == currentTab,
                        onClick = { destination?.let(onNavigate) },
                        enabled = destination != null,
                        icon = {},
                        label = { Text(tab.label) },
                    )
                }
            }
        },
    ) { insets ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(insets)
                .safeDrawingPadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            if (busy) Phase8SaveStatus(busy = true)
            if (actionError != null) Phase8ErrorCard()

            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                playerPortraitSeed(state)?.let { seed ->
                    AvatarFace(seed = seed, role = if (state.pro != null) AvatarRole.PLAYER else AvatarRole.PLAYER, width = 48.dp)
                }
                Text(
                    model.title,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.semantics { heading() },
                )
            }
            Text(
                model.subtitle,
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.semantics { contentDescription = model.contentDescription },
            )

            Phase8ScreenContent(
                state = state,
                commandContext = commandContext,
                model = model,
                onAction = onAction,
                platformState = platformState,
                onPlatformAction = onPlatformAction,
                onViewportExposure = onViewportExposure,
            )
            Spacer(Modifier.height(8.dp))
        }
    }
}

private enum class ProductTab(val label: String) {
    HIGH_SCHOOL("고교"),
    PRO("프로"),
    RECORDS("기록"),
    SETTINGS("설정"),
    ;

    fun landingScreen(state: GameAggregateState): Phase8ScreenId? {
        val candidates = when (this) {
            HIGH_SCHOOL -> listOf(
                Phase8ScreenId.P011_HIGH_SCHOOL_CAREER,
                Phase8ScreenId.P006_TRAINING,
                Phase8ScreenId.P003_PROLOGUE,
                Phase8ScreenId.P002_SETUP,
                Phase8ScreenId.P001_OPENING,
            )
            PRO -> listOf(
                Phase8ScreenId.P017_PRO_WEEK,
                Phase8ScreenId.P016_PRO_CONTRACT,
                Phase8ScreenId.P021_PRO_RETIREMENT,
                Phase8ScreenId.P020_OFFSEASON,
            )
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
            Phase8Group.PRO -> PRO
            Phase8Group.RECORDS_META, Phase8Group.RETURN_REVIEW -> RECORDS
            Phase8Group.SETTINGS_PLATFORM -> SETTINGS
            Phase8Group.CAREER_CORE, Phase8Group.RECAP_REBIRTH -> HIGH_SCHOOL
        }
    }
}

@Composable
private fun Phase8SaveStatus(busy: Boolean) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .semantics {
                contentDescription = if (busy) "선택을 저장하는 중" else "저장된 장면을 표시하는 중"
            },
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("저장된 장면", fontWeight = FontWeight.SemiBold)
            Text(if (busy) "저장 중" else "저장됨", color = MaterialTheme.colorScheme.primary)
        }
    }
}

private data class Phase8ProductDestination(
    val screen: Phase8ScreenId,
    val label: String,
    val description: String,
)

@Suppress("unused")
private fun phase8ProductDestinations(
    state: GameAggregateState,
    currentScreen: Phase8ScreenId,
): List<Phase8ProductDestination> = buildList {
    fun add(screen: Phase8ScreenId, label: String, description: String) {
        if (screen != currentScreen && Phase8ScreenProjection.isReachable(state, screen)) {
            add(Phase8ProductDestination(screen, label, description))
        }
    }
    if (state.highSchool != null || state.pro != null) {
        add(Phase8ScreenId.P011_HIGH_SCHOOL_CAREER, "고교 커리어", "지금까지의 성장과 장면을 봅니다.")
        add(Phase8ScreenId.P012_TOURNAMENT_LEAGUE, "대회와 리그", "대회 흐름과 라이벌 기록을 봅니다.")
        add(Phase8ScreenId.P024_WEEKLY, "주간 야구 노트", "이번 주 목표와 도장을 확인합니다.")
        add(Phase8ScreenId.P025_RECORDS_LEAGUE, "기록과 순위", "고교와 프로의 기록을 확인합니다.")
        add(Phase8ScreenId.P026_ACHIEVEMENTS, "업적", "커리어에서 쌓은 기록을 확인합니다.")
        add(Phase8ScreenId.P028_LIFECARD, "라이프 카드", "선택한 생의 이야기를 돌아봅니다.")
        add(Phase8ScreenId.P029_RETURN_PLAN, "복귀 계획", "다음에 돌아올 장면을 준비합니다.")
        add(Phase8ScreenId.P030_REVIEW, "리뷰 안내", "현재 리뷰 안내 조건을 확인합니다.")
    }
    add(Phase8ScreenId.P027_SETTINGS, "설정", "소리와 조작, 읽기 설정을 바꿉니다.")
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
            .semantics { contentDescription = model.contentDescription },
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            if (model.id == Phase8ScreenId.P002_SETUP) {
                Phase8SetupFields(state, commandContext, model, onAction)
            } else {
                model.sections.forEach { section ->
                    Text(
                        section.title,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = BaseballColors.milestone,
                        modifier = Modifier.semantics { heading() },
                    )
                    section.rows.forEach { row ->
                        Phase8ReadOnlyRow(row.label, row.value, row.detail)
                    }
                }
                if (model.id == Phase8ScreenId.P006_TRAINING || model.id == Phase8ScreenId.P017_PRO_WEEK) {
                    Phase8ChoiceGrid(model, onAction)
                } else {
                    Phase8Actions(model, onAction)
                }
                Phase9ViewportCards(state, commandContext, model, platformState, selectedLifeCardId, onViewportExposure)
                Phase9PlatformSurface(
                    state = state,
                    model = model,
                    platformState = platformState,
                    selectedLifeCardCareerId = selectedLifeCardId,
                    onSelectedLifeCardCareerIdChanged = { selectedLifeCardCareerId = it },
                    onAction = onPlatformAction,
                    onViewportExposure = onViewportExposure,
                )
            }
        }
    }
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
                        "wind_id" to HighSchoolWindRules.idFor(run.careerId),
                        "rules_version" to HighSchoolWindRules.RULES_VERSION.toString(),
                    ),
                ),
                onExposed = onExposed,
            ) {
                Phase8ReadOnlyRow("이번 생의 바람", windLabel(HighSchoolWindRules.idFor(run.careerId)), "이번 생의 흐름은 같은 규칙으로 끝까지 이어집니다.")
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
                            "drafted" to (run.draftResult?.outcome == com.solkim.baseball.core.highschool.HighSchoolDraftOutcome.DRAFTED).toString(),
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
                Phase8ReadOnlyRow("이전 생의 편지", "다음 생에 남은 기록", "도전 모드가 아닌 실제 이전 생의 동결 기록만 이어집니다.")
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
                AvatarFace(seed = record.playerName, role = if (record.drafted) AvatarRole.PLAYER else AvatarRole.PLAYER, width = 58.dp)
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text("${record.lifeNumber}번째 생", style = MaterialTheme.typography.labelMedium, color = BaseballColors.milestone)
                    Text(record.playerName, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
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
            Text("능력 ${record.ratings.joinToString(" · ")}", style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
        }
    }
}

private fun playerPortraitSeed(state: GameAggregateState): String? =
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
    plan: com.solkim.baseball.core.highschool.HighSchoolReturnPlan,
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
    com.solkim.baseball.core.highschool.HighSchoolReturnPlanRules.dayGap(savedDay, returnDayKey)?.let { add("day_gap" to it.toString()) }
    plan.developmentRulesVersion?.let { add("development_rules_version" to it.toString()) }
}

private fun com.solkim.baseball.core.highschool.HighSchoolReturnDestination.labelForProduct(): String = when (this) {
    com.solkim.baseball.core.highschool.HighSchoolReturnDestination.HIGH_SCHOOL -> "고교 커리어"
    com.solkim.baseball.core.highschool.HighSchoolReturnDestination.PRO -> "프로 커리어"
    com.solkim.baseball.core.highschool.HighSchoolReturnDestination.DAILY_INNING -> "현재 커리어"
}

@Composable
private fun Phase8SetupFields(
    state: GameAggregateState,
    commandContext: Phase8CommandContext,
    model: Phase8ScreenModel,
    onAction: (Phase8UiAction) -> Unit,
) {
    val setupAction = model.actions.single { it.id == "startHighSchool" }
    var name by rememberSaveable(model.id.wire) { mutableStateOf("") }
    var region by rememberSaveable(model.id.wire + ":region") {
        mutableStateOf(HighSchoolContentCatalog.regions.first())
    }
    var presetId by rememberSaveable(model.id.wire + ":preset") {
        mutableStateOf(HighSchoolContentCatalog.presets.first().id)
    }
    var regionMenuExpanded by rememberSaveable { mutableStateOf(false) }

    Text("선수 만들기", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
    Text("이름과 지역을 고르면 이번 생의 흐름이 시작됩니다.", style = MaterialTheme.typography.bodyLarge)
    OutlinedTextField(
        value = name,
        onValueChange = { name = it.take(12) },
        label = { Text("선수 이름") },
        supportingText = { Text("한글 이름을 입력해 주세요") },
        singleLine = true,
        modifier = Modifier.fillMaxWidth().semantics { contentDescription = "선수 이름 입력" },
    )
    Box {
        OutlinedTextField(
            value = region,
            onValueChange = {},
            readOnly = true,
            label = { Text("지역") },
            supportingText = { Text("선수의 첫 학교가 이 지역에서 정해집니다") },
            modifier = Modifier
                .fillMaxWidth()
                .clickable { regionMenuExpanded = true }
                .semantics { contentDescription = "지역 선택, 현재 $region" },
        )
        DropdownMenu(
            expanded = regionMenuExpanded,
            onDismissRequest = { regionMenuExpanded = false },
        ) {
            HighSchoolContentCatalog.regions.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option) },
                    onClick = {
                        region = option
                        regionMenuExpanded = false
                    },
                )
            }
        }
    }
    Text("성장 방식", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
    HighSchoolContentCatalog.presets.forEach { preset ->
        val selected = preset.id == presetId
        OutlinedButton(
            onClick = { presetId = preset.id },
            modifier = Modifier
                .heightIn(min = 56.dp)
                .semantics {
                    contentDescription = "${presetTitle(preset.id)}. 구위 ${preset.baseStuff}, 제구 ${preset.baseCommand}, 무브먼트 ${preset.baseMovement}, 체력 ${preset.baseStamina}${if (selected) ", 선택됨" else ""}"
                },
        ) {
            Column(Modifier.fillMaxWidth()) {
                Text(presetTitle(preset.id), fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal)
                Text("구위 ${preset.baseStuff} · 제구 ${preset.baseCommand} · 무브먼트 ${preset.baseMovement} · 체력 ${preset.baseStamina}", style = MaterialTheme.typography.bodySmall)
            }
        }
    }
    val valid = setupAction.enabled && name.trim().isNotBlank() && region in HighSchoolContentCatalog.regions
    Button(
        onClick = {
            val command = Phase8Payloads.startHighSchool(state, name, region, presetId, commandContext)
            val payloads = Phase8Payloads.batch(state, model.id, setupAction.id, listOf(command))
            onAction(Phase8UiAction(model.id, setupAction.id, payloads))
        },
        enabled = valid,
        modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).semantics {
            contentDescription = "고교 이야기 시작. 입력한 선수 정보를 저장합니다."
        },
    ) { Text("고교 이야기 시작") }
    if (!valid) {
        Text("이름과 지역을 확인하면 시작할 수 있습니다.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun Phase8ReadOnlyRow(label: String, value: String, detail: String) {
    Column(
        Modifier
            .fillMaxWidth()
            .semantics {
                contentDescription = listOf(label, value, detail).filter(String::isNotBlank).joinToString(". ")
            },
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Text(label, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
        Text(value, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
        if (detail.isNotBlank()) {
            Text(detail, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun Phase8ChoiceGrid(
    model: Phase8ScreenModel,
    onAction: (Phase8UiAction) -> Unit,
) {
    if (model.actions.isEmpty()) return
    Text("이번 주 선택", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
    model.actions.chunked(2).forEach { row ->
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            row.forEach { action ->
                Button(
                    onClick = { onAction(Phase8UiAction(model.id, action.id, action.payloads)) },
                    enabled = action.enabled,
                    modifier = Modifier
                        .weight(1f)
                        .heightIn(min = 56.dp)
                        .semantics { contentDescription = action.contentDescription },
                ) { Text(action.label) }
            }
            if (row.size == 1) Spacer(Modifier.weight(1f))
        }
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
        Phase8ActionButton(model.id, action, onAction)
    }
}

@Composable
private fun Phase8ActionButton(
    screenId: Phase8ScreenId,
    action: Phase8ActionModel,
    onAction: (Phase8UiAction) -> Unit,
) {
    val description = if (action.enabled) action.contentDescription else "${action.label}. ${action.description}. 지금은 선택할 수 없습니다."
    if (action.destructive) {
        OutlinedButton(
            onClick = { onAction(Phase8UiAction(screenId, action.id, action.payloads)) },
            enabled = action.enabled,
            modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).semantics { contentDescription = description },
        ) { Text(action.label, color = MaterialTheme.colorScheme.error) }
    } else {
        Button(
            onClick = { onAction(Phase8UiAction(screenId, action.id, action.payloads)) },
            enabled = action.enabled,
            modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).semantics { contentDescription = description },
        ) { Text(action.label) }
    }
    Text(
        if (action.enabled) action.description else "이 장면에서는 아직 선택할 수 없습니다.",
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

@Composable
private fun Phase8ErrorCard() {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)) {
        Text(
            "저장하지 못했습니다. 잠시 후 다시 시도해 주세요.",
            modifier = Modifier.padding(16.dp).semantics { contentDescription = "저장하지 못했습니다. 잠시 후 다시 시도해 주세요." },
            color = MaterialTheme.colorScheme.onErrorContainer,
        )
    }
}

private fun presetTitle(id: String): String = when (id) {
    "power_prospect" -> "힘으로 승부하는 투수"
    "precision_commander" -> "정교하게 읽는 투수"
    "breaking_ball_artist" -> "변화구를 그리는 투수"
    "innings_eater" -> "긴 이닝을 버티는 투수"
    else -> "나만의 성장 방식"
}
