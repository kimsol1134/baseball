package com.solkim.baseball.android

import android.os.Bundle
import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.solkim.baseball.application.GameAggregateState
import com.solkim.baseball.application.AvatarRole
import com.solkim.baseball.application.Phase8CommandContext
import com.solkim.baseball.application.Phase8Controller
import com.solkim.baseball.application.Phase8Payloads
import com.solkim.baseball.application.Phase8ScreenId
import com.solkim.baseball.application.Phase8ScreenProjection
import com.solkim.baseball.application.Phase9LifeCardProjection
import com.solkim.baseball.application.GameCommand
import com.solkim.baseball.application.GameCommandEnvelope
import com.solkim.baseball.application.SeedChallengeCode
import com.solkim.baseball.application.SeedChallengeRules
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import com.solkim.baseball.application.Phase9AnalyticsProjector
import com.solkim.baseball.design.BaseballMigrationTheme
import com.solkim.baseball.platform.LifeCardSharePayload
import com.solkim.baseball.platform.LifeCardShareReceiptScope
import com.solkim.baseball.platform.NativePlaybackSettings
import com.solkim.baseball.platform.NotificationDestination
import com.solkim.baseball.platform.NotificationPermissionTruth
import com.solkim.baseball.platform.NotificationTruthUpdatePolicy
import com.solkim.baseball.platform.PlatformActionCodec
import com.solkim.baseball.platform.PlatformAction
import com.solkim.baseball.platform.ReviewReason
import com.solkim.baseball.platform.ReviewResult
import com.solkim.baseball.platform.NativeReminderPlan
import com.solkim.baseball.platform.StableNotificationToken
import com.solkim.baseball.platform.NativeAudioResources
import com.solkim.baseball.model.Hashing
import com.solkim.baseball.application.HighSchoolDisplayRules
import com.solkim.baseball.application.HighSchoolReturnDestination
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val PHASE10_PLATFORM_INSPECT_ACTION =
    "com.solkim.baseball.android.action.PHASE10_PLATFORM_INSPECT"

/** The product launcher: route is always derived from the committed Kotlin aggregate. */
@OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)
public class MainActivity : ComponentActivity() {
    private lateinit var phase8Controller: Phase8Controller
    private lateinit var platform: com.solkim.baseball.platform.NativePhase9Platform
    private val commandContext = Phase8CommandContext()
    private val activityScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var pendingSeedCode by mutableStateOf<SeedChallengeCode?>(null)
    private var showSeedDialog by mutableStateOf(false)
    private var showSeedExitDialog by mutableStateOf(false)
    private var invalidSeedLink by mutableStateOf(false)
    private var actionError by mutableStateOf<String?>(null)
    private var showResetConfirmation by mutableStateOf(false)
    private var restoringProgress by mutableStateOf(false)
    private var actionInFlight by mutableStateOf(false)
    private var openingMound by mutableStateOf(false)
    private var previousActionScreen: Phase8ScreenId? = null
    private var navigationTapBlockUntil = 0L
    private var selectedScreen by mutableStateOf<Phase8ScreenId?>(null)
    private var platformUiState by mutableStateOf(
        Phase9PlatformUiState(NotificationPermissionTruth.UNAVAILABLE, null),
    )
    private var pendingNotificationToken by mutableStateOf<String?>(null)
    private val pendingMatrixEvents = linkedMapOf<String, PendingMatrixEvent>()
    private val matrixEventsInFlight = mutableSetOf<String>()
    private var pendingNotificationSource: String? = null
    private var notificationSettingsReturnPending = false
    private var sessionEndedRecorded = false
    private var sessionStartedElapsed = 0L
    private var sessionStartedCompletedGames = 0UL

    private data class PendingMatrixEvent(
        val screen: Phase8ScreenId,
        val actionId: String,
        val eventName: String,
        val scope: String,
        val properties: List<Pair<String, String>>,
        val onCommitted: (() -> Unit)? = null,
    )

    private val notificationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) {
        reconcileNotificationTruth("system")
        refreshPlatformUiState()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        setTheme(R.style.Theme_BaseballMigration)
        super.onCreate(savedInstanceState)
        val store = (application as BaseballApplication).gameStore
        platform = (application as BaseballApplication).platform
        phase8Controller = Phase8Controller(store, commandContext)
        sessionStartedElapsed = SystemClock.elapsedRealtime()
        sessionStartedCompletedGames = store.current.meta.completedGameCount
        pendingSeedCode = getSharedPreferences("seed-link", MODE_PRIVATE).getString("pending", null)?.let(SeedChallengeCode::parse)
        acceptSeedIntent(intent)
        acceptNotificationIntent(intent)
        inspectPhase10PlatformIntent(intent)
        recordReturnPlanOpenAnalytics("cold")
        refreshPlatformUiState()
        setContent {
            val state by store.state.collectAsState()
            BaseballMigrationTheme(highContrast = state.settings.highContrastEnabled) {
                val busy by store.busy.collectAsState()
                val preferred = phase8Controller.preferredScreen()
                val current = selectedScreen?.takeIf {
                    com.solkim.baseball.application.Phase8ScreenProjection.isReachable(state, it) || it == preferred
                } ?: preferred
                BackHandler(enabled = selectedScreen != null) {
                    selectedScreen = null
                }
                if (openingMound) MoundLoadingView() else Phase8Shell(
                    state = state,
                    busy = busy || restoringProgress || actionInFlight,
                    actionError = actionError,
                    currentScreen = current,
                    commandContext = commandContext,
                    platformState = platformUiState,
                    onNavigate = {
                        selectedScreen = it.takeUnless { destination -> destination == phase8Controller.preferredScreen() }
                        actionError = null
                    },
                    onAction = { action ->
                        if (action.actionId == "resetProgress") {
                            actionError = null
                            showResetConfirmation = true
                        } else performPhase8(action)
                    },
                    onPlatformAction = ::performPlatformAction,
                    onViewportExposure = ::recordViewportExposure,
                    pendingSeedCode = pendingSeedCode,
                    onSeedChallenge = { showSeedDialog = true },
                    onExitSeedChallenge = { showSeedExitDialog = true },
                )
                LaunchedEffect(state.settings.musicEnabled) {
                    if (lifecycle.currentState.isAtLeast(androidx.lifecycle.Lifecycle.State.RESUMED)) applyNativeSettings()
                }
                val copy = rememberGameCopy()
                if (showResetConfirmation) AlertDialog(
                    modifier = Modifier.semantics { testTagsAsResourceId = true },
                    onDismissRequest = { if (!busy) { showResetConfirmation = false; actionError = null } },
                    title = { Text(copy.resolve("android.settings.reset-title")) },
                    text = { Column {
                        Text(copy.resolve(if (busy) "android.settings.reset-working" else "android.settings.reset-body"))
                        actionError?.let { Text(it, modifier = Modifier.testTag("settings.reset.error"), color = MaterialTheme.colorScheme.error) }
                    } },
                    confirmButton = { TextButton(enabled = !busy, modifier = Modifier.testTag("settings.reset.confirm"), onClick = {
                        val action = phase8Controller.projection(Phase8ScreenId.P027_SETTINGS).actions.firstOrNull { it.id == "resetProgress" && it.enabled }
                        if (action != null) performPhase8(Phase8UiAction(Phase8ScreenId.P027_SETTINGS, action.id, action.payloads))
                    }) { Text(copy.resolve("android.settings.reset-confirm"), color = MaterialTheme.colorScheme.error) } },
                    dismissButton = { TextButton(enabled = !busy, modifier = Modifier.testTag("settings.reset.cancel"), onClick = {
                        showResetConfirmation = false; actionError = null
                    }) { Text(copy.resolve("android.settings.reset-cancel")) } },
                )
                if (showSeedDialog) SeedChallengeDialog(pendingSeedCode, SeedChallengeRules.canStart(state) && !busy,
                    onStart = { code, preset ->
                        rememberSeed(code)
                        showSeedDialog = false
                        performSeedCommand(SeedChallengeRules.startCommand(code, preset)) {
                            if (pendingSeedCode == code) {
                                pendingSeedCode = null
                                getSharedPreferences("seed-link", MODE_PRIVATE).edit().remove("pending").apply()
                            }
                        }
                    },
                    onRemember = ::rememberSeed,
                    onDismiss = { showSeedDialog = false })
                if (showSeedExitDialog) AlertDialog(modifier = Modifier.semantics { testTagsAsResourceId = true }, onDismissRequest = { showSeedExitDialog = false },
                    title = { Text(copy.resolve("android.challenge.exit-title")) },
                    text = { Text(copy.resolve("android.challenge.exit-body")) },
                    confirmButton = { TextButton(enabled = !busy, modifier = Modifier.testTag("challenge.confirm-exit"), onClick = { showSeedExitDialog = false; performSeedCommand(SeedChallengeRules.endCommand()) }) { Text(copy.resolve("android.challenge.exit")) } },
                    dismissButton = { TextButton(onClick = { showSeedExitDialog = false }) { Text(copy.resolve("android.challenge.keep-playing")) } })
                if (invalidSeedLink) AlertDialog(onDismissRequest = { invalidSeedLink = false },
                    title = { Text(copy.resolve("android.challenge.invalid-title")) },
                    text = { Text(copy.resolve("android.challenge.invalid-body")) },
                    confirmButton = { TextButton(onClick = { invalidSeedLink = false }) { Text(copy.resolve("android.challenge.ok")) } })
                LaunchedEffect(pendingNotificationToken, state.revision, current, busy) {
                    val token = pendingNotificationToken
                    val rendered = Phase8ScreenProjection.isReachable(state, current) || current == preferred
                    if (token != null && current == selectedScreen && rendered) {
                        platform.markNotificationNavigationCompleted(token)
                        pendingNotificationToken = null
                    }
                    if (!busy) retryPendingMatrixEvents()
                    if (!busy) pendingNotificationSource?.let { source ->
                        pendingNotificationSource = null
                        reconcileNotificationTruth(source)
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        acceptSeedIntent(intent)
        acceptNotificationIntent(intent)
        inspectPhase10PlatformIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        openingMound = false
        if (::platform.isInitialized) {
            restoringProgress = true
            activityScope.launch {
                try {
                    (application as BaseballApplication).gameStore.reconcilePersistedRevision()
                } catch (cancelled: kotlinx.coroutines.CancellationException) {
                    throw cancelled
                } catch (error: Exception) {
                    Log.e("MainActivity", "Progress reconciliation failed", error)
                    withContext(Dispatchers.Main) { actionError = "기록을 불러오지 못했어요. 잠시 뒤 다시 열어 주세요." }
                } finally {
                    withContext(kotlinx.coroutines.NonCancellable + Dispatchers.Main) { restoringProgress = false }
                }
            }
            // A previously durable native outbox may become deliverable after process restart or
            // an SDK/network transition. Retry it independently of aggregate command receipts.
            platform.analytics.retryOutbox()
            applyNativeSettings()
            refreshPlatformUiState()
            val source = if (notificationSettingsReturnPending) {
                notificationSettingsReturnPending = false
                "settings"
            } else {
                "system"
            }
            reconcileNotificationTruth(source)
            recordReturnPlanOpenAnalytics("warm")
            retryPendingMatrixEvents()
        }
    }

    override fun onPause() {
        if (::platform.isInitialized) platform.audioHaptics.pauseForLifecycle()
        super.onPause()
    }

    override fun onStop() {
        if (::platform.isInitialized) recordSessionEnded()
        super.onStop()
    }

    override fun onDestroy() {
        activityScope.cancel()
        super.onDestroy()
    }

    private fun rememberSeed(code: SeedChallengeCode) {
        pendingSeedCode = code
        getSharedPreferences("seed-link", MODE_PRIVATE).edit().putString("pending", code.token).apply()
    }

    private fun acceptSeedIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        val candidate = (uri.scheme.equals("yagurebirth", true) && uri.host.equals("challenge", true)) ||
            (uri.scheme.equals("https", true) && uri.host.equals("baseball-reincarnation.vercel.app", true) && uri.path.orEmpty().startsWith("/challenge/", true))
        if (!candidate) return
        val code = SeedChallengeCode.parse(uri.toString())
        if (code == null) { invalidSeedLink = true; return }
        if ((application as BaseballApplication).gameStore.current.meta.seedChallenge?.code == code) return
        rememberSeed(code)
        showSeedDialog = true
    }

    private fun performSeedCommand(command: GameCommand, onCommitted: () -> Unit = {}) {
        actionError = null
        activityScope.launch {
            try {
                val store = (application as BaseballApplication).gameStore
                val current = store.current
                store.dispatch(GameCommandEnvelope("seed-action-${current.revision}", "phase8-ui", current.revision, command))
                withContext(Dispatchers.Main) {
                    selectedScreen = null
                    onCommitted()
                    applyNativeSettings()
                    (application as BaseballApplication).updateCrashContext()
                    refreshPlatformUiState()
                }
            } catch (error: Exception) {
                Log.e("MainActivity", "Seed challenge command failed", error)
                withContext(Dispatchers.Main) { actionError = "저장하지 못했어요. 같은 버튼을 한 번 더 눌러 주세요." }
            }
        }
    }

    /** Same button, same failure, twice: telling the player to press again a third time is a dead end. */
    private var failingActionId: String? = null

    private fun performPhase8(action: Phase8UiAction) {
        if (actionInFlight || (application as BaseballApplication).gameStore.busy.value) return
        if (action.screenId != previousActionScreen && android.os.SystemClock.elapsedRealtime() < navigationTapBlockUntil) return
        actionInFlight = true
        openingMound = action.actionId in setOf("startHighSchool", "openTutorialPitch", "resumePitch")
        var launchedMound = false
        actionError = null
        val completedGamesBefore = (application as BaseballApplication).gameStore.current.meta.completedGameCount
        activityScope.launch {
            try {
                val beforeAction = (application as BaseballApplication).gameStore.current
                val execution = phase8Controller.executePlayerAction(
                    screenId = action.screenId,
                    actionId = action.actionId,
                    capturedPayloads = action.capturedPayloads,
                )
                withContext(Dispatchers.Main) {
                    saveTrainingFeedback(this@MainActivity, beforeAction, (application as BaseballApplication).gameStore.current)
                    saveConversationFeedback(this@MainActivity, beforeAction, (application as BaseballApplication).gameStore.current)
                    saveProWeekFeedback(this@MainActivity, beforeAction, (application as BaseballApplication).gameStore.current)
                    if (phase8Controller.preferredScreen() != action.screenId) {
                        previousActionScreen = action.screenId
                        navigationTapBlockUntil = android.os.SystemClock.elapsedRealtime() + 500
                    }
                    // Preferences keep their current page so multiple changes can be made in place.
                    if (action.screenId != Phase8ScreenId.P027_SETTINGS || action.actionId == "resetProgress") selectedScreen = null
                    if (action.actionId == "resetProgress") showResetConfirmation = false
                    execution.launch?.let { launch ->
                        launchedMound = true
                        openingMound = true
                        startActivity(PitchActivity.intent(this@MainActivity, launch.sessionId, launch.expectedRevision.toString()))
                    }
                    failingActionId = null
                    applyNativeSettings()
                    (application as BaseballApplication).updateCrashContext()
                    nativePresentationMarker(action.actionId)?.let { marker ->
                        val markerSeed = commandContext.seed((application as BaseballApplication).gameStore.current, "presentation:$marker").toULongOrNull() ?: 0UL
                        platform.audioHaptics.presentNativeMarker(marker, playbackSettings(), markerSeed)
                    }
                    requestReviewAtProductMoment(action.actionId)
                    if (action.actionId == "prepareReturnPlan") scheduleSavedReturnPlan()
                    refreshPlatformUiState()
                    val completedGamesAfter = (application as BaseballApplication).gameStore.current.meta.completedGameCount
                    reconcileNotificationTruth(if (completedGamesBefore == 0UL && completedGamesAfter > 0UL) "after_first_game" else "system")
                    retryPendingMatrixEvents()
                }
            } catch (cancelled: kotlinx.coroutines.CancellationException) {
                throw cancelled
            } catch (error: Throwable) {
                android.util.Log.e("MainActivity", "performPhase8 failed", error)
                // Refresh an uncertain earlier commit before allowing another choice.
                val refreshed = runCatching { (application as BaseballApplication).gameStore.reconcilePersistedRevision() }.isSuccess
                withContext(Dispatchers.Main) {
                    val restoredState = (application as BaseballApplication).gameStore.current
                    if (action.actionId == "resetProgress" && refreshed && restoredState.stage == com.solkim.baseball.application.GameStage.OPENING &&
                        restoredState.highSchool == null && restoredState.pro == null) {
                        showResetConfirmation = false
                        selectedScreen = null
                        actionError = null
                        applyNativeSettings()
                        refreshPlatformUiState()
                        return@withContext
                    }
                    val repeated = failingActionId == action.actionId
                    failingActionId = action.actionId
                    actionError = when {
                        error.message == "game.command.stale_revision" && refreshed ->
                            "기록을 다시 불러왔어요. 방금 누른 버튼을 한 번 더 눌러 주세요."
                        repeated ->
                            "저장이 계속 실패하고 있어요. 설정의 저장과 기록에서 기록을 파일로 보관한 뒤, 기기의 남은 저장 공간을 확인해 주세요."
                        else -> "저장하지 못했어요. 같은 버튼을 한 번 더 눌러 주세요."
                    }
                }
            } finally {
                withContext(kotlinx.coroutines.NonCancellable + Dispatchers.Main) {
                    actionInFlight = false
                    if (!launchedMound) openingMound = false
                }
            }
        }
    }

    private fun performPlatformAction(action: Phase9UiAction) {
        actionError = null
        val state = (application as BaseballApplication).gameStore.current
        val decoded = runCatching { PlatformActionCodec.decode(action.encodedPayload) }.getOrElse {
            actionError = "이 선택이 저장되지 않았어요. 한 번 더 눌러 주세요."
            return
        }
        if (decoded != action.payload || decoded.expectedRevision != state.revision || decoded.stateCommitment != state.commitment) {
            actionError = "그사이 이야기가 앞으로 갔어요. 뒤로 갔다가 다시 들어와 주세요."
            return
        }
        val expectedParameters = when (decoded.action) {
            PlatformAction.SHARE_LIFE_CARD -> buildMap {
                action.sharePayload?.let {
                    put("share", it.text)
                    put("career_id", it.careerId)
                    put("life_number", it.lifeNumber.toString())
                }
            }
            PlatformAction.REQUEST_REVIEW -> mapOf("reason" to (action.reviewReason?.wire ?: ""))
            else -> emptyMap()
        }
        if (decoded.parameterHash != PlatformActionCodec.parameterHash(expectedParameters)) {
            actionError = "이 선택은 지금 화면과 맞지 않아요. 뒤로 갔다가 다시 들어와 주세요."
            return
        }
        when (decoded.action) {
            PlatformAction.REQUEST_NOTIFICATION_PERMISSION -> {
                if (Build.VERSION.SDK_INT >= 33 && platform.notifications.permission.shouldRequest()) {
                    platform.notifications.permission.markRequestIssued()
                    notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                } else {
                    notificationSettingsReturnPending = true
                    platform.notifications.openSettings()
                }
            }
            PlatformAction.DISMISS_REMINDER_OFFER -> platform.notifications.permission.markReminderOfferDeclined()
            PlatformAction.OPEN_NOTIFICATION_SETTINGS -> {
                notificationSettingsReturnPending = true
                platform.notifications.openSettings()
            }
            PlatformAction.SHARE_LIFE_CARD -> {
                val payload = action.sharePayload ?: run {
                    actionError = "카드를 만들지 못했어요. 기록 탭에서 다시 시도해 주세요."
                    return
                }
                if (payload.careerId.isBlank() || payload.lifeNumber <= 0) {
                    actionError = "이 카드의 생을 찾지 못했어요. 기록 탭에서 다른 생을 골라 주세요."
                    return
                }
                val selected = Phase9LifeCardProjection.selected(state, payload.careerId)
                val expectedPayload = selected?.let {
                    LifeCardSharePayload(
                        title = com.solkim.baseball.application.CareerShareCopy.LIFE_CARD_TITLE,
                        text = it.text,
                        lines = it.lines,
                        careerId = it.careerId,
                        lifeNumber = it.lifeNumber,
                    )
                }
                if (payload != expectedPayload) {
                    actionError = "카드가 그사이 바뀌었어요. 다시 골라 주세요."
                    return
                }
                val copy = com.solkim.baseball.application.GameCopy(com.solkim.baseball.application.GameLanguage.fromTag(resources.configuration.locales[0].toLanguageTag()))
                val record = state.highSchool?.archive?.firstOrNull { it.careerId == payload.careerId }
                val playerName = record?.playerName
                val names = listOfNotNull(playerName).toSet()
                val lines = payload.lines.map { copy.legacy(it, names) }
                val appName = getString(R.string.app_name)
                val installUrl = "https://play.google.com/store/apps/details?id=com.solkim.baseball.android"
                val portrait = playerName?.let { name ->
                    val drawableName = PlayerPortraitResolver.resolveDrawableName(name, AvatarRole.PLAYER, if (record.drafted) PlayerStage.PRO else PlayerStage.ACE)
                    val id = resources.getIdentifier(drawableName, "drawable", packageName)
                    if (id != 0) runCatching { android.graphics.BitmapFactory.decodeResource(resources, id) }.getOrNull() else null
                }
                val result = platform.share.share(payload.copy(title = copy.legacy(payload.title), text = (lines + listOf("", appName, installUrl)).joinToString("\n"), lines = lines),
                    portrait = portrait, appName = appName)
                if (result is com.solkim.baseball.platform.ShareResult.ChooserOpened || result is com.solkim.baseball.platform.ShareResult.TextFallbackChooserOpened) {
                    // The chooser receipt belongs to the exact frozen record captured by the
                    // payload. Never substitute the active player or a later archive entry if a
                    // reducer update races the external sharesheet.
                    recordMatrixEvent(
                        PendingMatrixEvent(
                            screen = Phase8ScreenId.P028_LIFECARD,
                            actionId = "shareLifeCard",
                            eventName = "life_card_share_tapped",
                            scope = LifeCardShareReceiptScope.forPayload(payload),
                            properties = listOf("life_number" to payload.lifeNumber.toString()),
                        ),
                    )
                }
                if (result is com.solkim.baseball.platform.ShareResult.Failed) actionError = "공유 창을 열지 못했어요. 다른 앱을 잠시 닫고 다시 눌러 주세요."
            }
            PlatformAction.REQUEST_REVIEW -> {
                if (decoded.screenWire !in setOf(Phase8ScreenId.P014_RUN_RECAP.wire, Phase8ScreenId.P015_REBIRTH.wire)) {
                    actionError = "지금은 리뷰를 묻는 장면이 아니에요."
                    return
                }
                val reason = action.reviewReason ?: run {
                    actionError = "리뷰 창을 열 수 없었어요. 다음 기회에 다시 물어볼게요."
                    return
                }
                val expectedReason = Phase8ScreenProjection.reviewTrigger(state)?.let {
                    when (it) {
                        "third-life" -> ReviewReason.THIRD_LIFE
                        "good-recap" -> ReviewReason.GOOD_RECAP
                        "drafted-reveal-confirmed" -> ReviewReason.DRAFTED_REVEAL_CONFIRMED
                        else -> null
                    }
                }
                if (reason != expectedReason) {
                    actionError = "지금은 리뷰를 남길 수 없어요. 다음 기회에 다시 물어볼게요."
                    return
                }
                platform.review.request(this, reason) { result ->
                    if (result is ReviewResult.Failed) runOnUiThread { actionError = "지금은 리뷰 창을 열 수 없어요. 스토어에서 직접 남길 수 있어요." }
                }
            }
        }
    }

    private fun acceptNotificationIntent(intent: Intent?) {
        val recovery = platform.inspectNotification(intent) ?: return
        val state = (application as BaseballApplication).gameStore.current
        if (state.highSchool?.challenge?.active == true) return
        val plan = state.highSchool?.returnPlan?.takeIf { it.receiptId == recovery.open.planReceipt }
        val properties = buildList {
            add("destination" to recovery.open.destination.wire)
            add("reason" to recovery.open.reason)
            add("plan_receipt" to recovery.open.planReceipt)
            plan?.experimentId?.let { add("experiment_id" to it) }
            plan?.experimentVariant?.let { add("variant" to it) }
            plan?.let { add("saved_day_key" to (it.savedDayKey ?: it.createdDayKey)) }
            plan?.developmentRulesVersion?.let { add("development_rules_version" to it.toString()) }
        }
        val requested = when (recovery.open.destination) {
            NotificationDestination.HIGH_SCHOOL -> Phase8ScreenId.P011_HIGH_SCHOOL_CAREER
            NotificationDestination.PRO -> Phase8ScreenId.P016_PRO_CONTRACT
            NotificationDestination.RECORDS -> Phase8ScreenId.P025_RECORDS_LEAGUE
        }
        val route = requested.takeIf { Phase8ScreenProjection.isReachable(state, it) }
            ?: Phase8ScreenProjection.preferredScreen(state)
        val receiptId = Phase9AnalyticsProjector.receiptId(state.installId, "reminder_opened", "notification:${recovery.open.tokenHash}")
        if (state.analytics.receipts.any { it.receiptId == receiptId }) {
            platform.markNotificationAnalytics(recovery.open.tokenHash)
            selectedScreen = route
            pendingNotificationToken = recovery.open.tokenHash
        } else {
            recordMatrixEvent(
                PendingMatrixEvent(
                    screen = Phase8ScreenId.P029_RETURN_PLAN,
                    actionId = "notificationOpen",
                    eventName = "reminder_opened",
                    scope = "notification:${recovery.open.tokenHash}",
                    properties = properties,
                    onCommitted = {
                        platform.markNotificationAnalytics(recovery.open.tokenHash)
                        selectedScreen = route
                        pendingNotificationToken = recovery.open.tokenHash
                    },
                ),
            )
        }
    }

    /** Read-only internal rehearsal probe; it is unavailable in the debug shadow package. */
    private fun inspectPhase10PlatformIntent(intent: Intent?) {
        if (!BuildConfig.PHASE10_PRODUCTION_BUILD || BuildConfig.RELEASE_DISTRIBUTION == "production" || intent?.action != PHASE10_PLATFORM_INSPECT_ACTION) return
        val state = platform.stateStore.read()
        Log.i(
            "BASEBALL_PHASE10",
            "PHASE10_PLATFORM_INSPECT status=passed " +
                "installIdSha256=${Hashing.sha256Hex(platform.installId)} " +
                "analyticsOnce=${state.analyticsOnceReceiptIds.size} " +
                "analyticsOutbox=${state.analyticsOutbox.size} " +
                "knownAggregate=${state.knownAggregateReceiptIds.size} " +
                "reviewAttempts=${state.reviewAttempts.size} " +
                "scheduledReminders=${state.scheduledReminderTokenHashes.size} " +
                "notificationAnalytics=${state.notificationAnalyticsTokenHashes.size} " +
                "notificationNavigation=${state.notificationNavigationTokenHashes.size} " +
                "notificationPermissionAsked=${state.notificationPermissionAsked} " +
                "reminderOfferDeclined=${state.reminderOfferDeclined} " +
                "notificationTruth=${platform.notifications.permission.truth().name} " +
                "scopedEpoch=${state.scopedEpoch} shareCacheEpoch=${state.shareCacheEpoch}",
        )
    }

    private fun refreshPlatformUiState() {
        if (!::platform.isInitialized) return
        val state = (application as BaseballApplication).gameStore.current
        val reason = Phase8ScreenProjection.reviewTrigger(state)?.let {
            when (it) {
                "third-life" -> ReviewReason.THIRD_LIFE
                "good-recap" -> ReviewReason.GOOD_RECAP
                "drafted-reveal-confirmed" -> ReviewReason.DRAFTED_REVEAL_CONFIRMED
                else -> null
            }
        }
        platformUiState = Phase9PlatformUiState(
            notificationTruth = platform.notifications.permission.truth(),
            reviewDecision = reason?.let(platform.review::eligibility),
            notificationPermissionAsked = platform.stateStore.read().notificationPermissionAsked,
            reminderOfferDeclined = platform.notifications.permission.reminderOfferDeclined(),
        )
    }

    /**
     * Mirrors the iOS callers: the request is attempted only after the exact rendered product
     * moment has been durably acknowledged by the aggregate. A route visit alone can never prompt.
     */
    private fun requestReviewAtProductMoment(actionId: String) {
        val reason = when (actionId) {
            "confirmDraftResult" -> ReviewReason.DRAFTED_REVEAL_CONFIRMED
            "confirmRecap" -> ReviewReason.GOOD_RECAP
            "quickRebirth",
            "startHighSchool" -> ReviewReason.THIRD_LIFE
            else -> return
        }
        val state = (application as BaseballApplication).gameStore.current
        val trigger = Phase8ScreenProjection.reviewTrigger(state)
        val expectedTrigger = when (reason) {
            ReviewReason.DRAFTED_REVEAL_CONFIRMED -> "drafted-reveal-confirmed"
            ReviewReason.GOOD_RECAP -> "good-recap"
            ReviewReason.THIRD_LIFE -> "third-life"
        }
        if (trigger != expectedTrigger || platform.review.eligibility(reason).eligible.not()) return
        platform.review.request(this, reason) { result ->
            if (result is ReviewResult.Failed) {
                // Play failures are external platform results; they never mutate the game state.
                refreshPlatformUiState()
            }
        }
    }

    private fun applyNativeSettings() {
        if (!playbackSettings().soundEnabled) platform.audioHaptics.stopEffects()
        platform.audioHaptics.startMusic(NativeAudioResources.musicToggleResource(), playbackSettings())
    }

    private fun recordReturnPlanOpenAnalytics(launchType: String) {
        if (launchType !in setOf("cold", "warm")) return
        val state = (application as BaseballApplication).gameStore.current
        if (state.meta.completedGameCount == 0UL) return
        val plan = state.highSchool?.returnPlan ?: return
        if (plan.destination == HighSchoolReturnDestination.DAILY_INNING) return
        val savedDay = plan.savedDayKey ?: return
        val experimentId = plan.experimentId ?: return
        val variant = plan.experimentVariant ?: return
        val developmentRulesVersion = plan.developmentRulesVersion ?: return
        if (plan.receiptId.isBlank() || variant !in setOf("holdout", "guided")) return
        val returnDay = commandContext.clock.today().toString()
        val dayGap = HighSchoolDisplayRules.returnPlanDayGap(savedDay, returnDay) ?: return
        if (dayGap < 1) return
        val properties = buildList {
            add("destination" to plan.destination.wire)
            add("reason" to plan.reason)
            add("plan_receipt" to plan.receiptId)
            add("experiment_id" to experimentId)
            add("variant" to variant)
            add("saved_day_key" to savedDay)
            add("return_day_key" to returnDay)
            add("day_gap" to dayGap.toString())
            add("development_rules_version" to developmentRulesVersion.toString())
            add("launch_type" to launchType)
        }
        val scope = "return-next-day:${plan.receiptId}:$returnDay"
        recordMatrixEvent(
            PendingMatrixEvent(
                screen = Phase8ScreenId.P029_RETURN_PLAN,
                actionId = "returnPlanNextDayOpen",
                eventName = "return_plan_next_day_open",
                scope = scope,
                properties = properties,
            ),
        )
        if (launchType == "cold") {
            recordMatrixEvent(
                PendingMatrixEvent(
                    screen = Phase8ScreenId.P029_RETURN_PLAN,
                    actionId = "returnPlanColdStart",
                    eventName = "return_plan_cold_start",
                    scope = scope,
                    properties = properties,
                ),
            )
        }
    }

    private fun playbackSettings(): NativePlaybackSettings {
        val settings = (application as BaseballApplication).gameStore.current.settings
        return NativePlaybackSettings(settings.soundEnabled, settings.musicEnabled, settings.hapticsEnabled, settings.reducedMotionEnabled)
    }

    private fun scheduleSavedReturnPlan() {
        val plan = (application as BaseballApplication).gameStore.current.highSchool?.returnPlan ?: return
        if (plan.dismissed || plan.destination == HighSchoolReturnDestination.DAILY_INNING) return
        val destination = when (plan.destination) {
            HighSchoolReturnDestination.HIGH_SCHOOL -> NotificationDestination.HIGH_SCHOOL
            HighSchoolReturnDestination.PRO -> NotificationDestination.PRO
            HighSchoolReturnDestination.DAILY_INNING -> return
        }
        val savedDay = runCatching { LocalDate.parse(plan.savedDayKey ?: plan.createdDayKey) }.getOrElse { commandContext.clock.today() }
        val trigger = savedDay.plusDays(1).atTime(LocalTime.of(9, 0)).atZone(ZoneId.of("Asia/Seoul")).toInstant().toEpochMilli()
        val state = (application as BaseballApplication).gameStore.current
        val playerName = state.pro?.identityName?.takeIf { it.isNotBlank() } ?: state.highSchool?.run?.identity?.name?.takeIf { it.isNotBlank() }
        val body = plan.body.takeIf { it.isNotBlank() && it != plan.reason } ?: "어디까지 했는지 알려 줄게."
        // One reminder at a time. A new plan replaces the old alarm instead of stacking on it.
        runCatching { platform.notifications.scheduler.cancelScheduled() }
        platform.notifications.scheduler.schedule(
            NativeReminderPlan(
                triggerAtUtcMillis = trigger,
                destination = destination,
                reason = plan.reason,
                planReceipt = plan.receiptId,
                token = "${plan.receiptId}|${plan.createdDayKey}|${destination.wire}",
                title = if (playerName != null) "$playerName, 다음 경기가 기다린다" else "다음 경기가 기다린다",
                body = body,
            ),
        )
    }

    private fun recordViewportExposure(exposure: Phase9ViewportExposure) {
        recordMatrixEvent(
            PendingMatrixEvent(
                screen = Phase8ScreenProjection.preferredScreen((application as BaseballApplication).gameStore.current),
                actionId = "viewport:${exposure.eventName}",
                eventName = exposure.eventName,
                scope = exposure.scope,
                properties = exposure.properties,
            ),
        )
    }

    private fun recordMatrixEvent(event: PendingMatrixEvent) {
        if ((application as BaseballApplication).gameStore.current.highSchool?.challenge?.active == true) return
        val key = "${event.eventName}|${event.scope}"
        pendingMatrixEvents[key] = event
        attemptMatrixEvent(key)
    }

    private fun attemptMatrixEvent(key: String) {
        if (matrixEventsInFlight.contains(key) || (application as BaseballApplication).gameStore.busy.value) return
        val event = pendingMatrixEvents[key] ?: return
        matrixEventsInFlight += key
        activityScope.launch {
            try {
                val state = (application as BaseballApplication).gameStore.current
                val payload = Phase8Payloads.analytics(state, event.screen, event.actionId, event.eventName, event.scope, event.properties)
                val receiptId = Phase9AnalyticsProjector.receiptId(state.installId, event.eventName, event.scope)
                if (state.analytics.receipts.none { it.receiptId == receiptId }) {
                    (application as BaseballApplication).gameStore.dispatch(payload.envelope)
                }
                val store = (application as BaseballApplication).gameStore
                // The aggregate save is already committed. Retry the observer/native handoff
                // separately, and keep the UI receipt pending until that handoff has its own
                // durable outbox/once acknowledgement.
                store.retryAnalyticsHandoff()
                val committed = store.current
                check(committed.analytics.receipts.any { it.receiptId == receiptId }) { "analytics.receipt_missing_after_dispatch" }
                check(!store.analyticsHandoffPending(receiptId)) { "analytics.handoff_retryable" }
                withContext(Dispatchers.Main) {
                    pendingMatrixEvents.remove(key)
                    matrixEventsInFlight.remove(key)
                    event.onCommitted?.invoke()
                }
            } catch (_: Throwable) {
                withContext(Dispatchers.Main) { matrixEventsInFlight.remove(key) }
            }
        }
    }

    private fun retryPendingMatrixEvents() {
        if ((application as BaseballApplication).gameStore.busy.value) return
        (application as BaseballApplication).gameStore.retryAnalyticsHandoff()
        pendingMatrixEvents.keys.toList().forEach(::attemptMatrixEvent)
    }

    private fun reconcileNotificationTruth(source: String) {
        if (!::platform.isInitialized) return
        if ((application as BaseballApplication).gameStore.busy.value) {
            pendingNotificationSource = source
            return
        }
        val truth = platform.notifications.permission.truth()
        val state = (application as BaseballApplication).gameStore.current
        val receiptScope = "notification-settings:$source:allowed"
        val allowedReceiptId = Phase9AnalyticsProjector.receiptId(state.installId, "reminder_changed", receiptScope)
        val blockedReceiptId = Phase9AnalyticsProjector.receiptId(state.installId, "reminder_changed", "notification-settings:$source:blocked")
        val update = NotificationTruthUpdatePolicy.decide(
            currentAggregateEnabled = state.settings.notificationsEnabled,
            truth = truth,
            source = source,
            receiptAlreadyPresent = state.analytics.receipts.any { it.receiptId == allowedReceiptId || it.receiptId == blockedReceiptId },
        ) ?: return
        if (!update.enabled) platform.notifications.scheduler.cancelScheduled()
        val commands = buildList {
            if (update.shouldPersistAggregate) add(GameCommand.UpdateSettings(state.settings.copy(notificationsEnabled = update.enabled)))
            if (update.shouldRecordAnalytics) add(
                GameCommand.RecordAnalytics(
                    receiptId = Phase9AnalyticsProjector.receiptId(state.installId, "reminder_changed", update.receiptScope),
                    eventName = "reminder_changed",
                    properties = listOf("enabled" to update.enabled.toString(), "source" to source),
                ),
            )
        }
        if (commands.isEmpty()) {
            if (update.enabled) scheduleSavedReturnPlan()
            return
        }
        val payloads = Phase8Payloads.batch(state, Phase8ScreenId.P027_SETTINGS, "notificationTruth:$source", commands)
        activityScope.launch {
            try {
                (application as BaseballApplication).gameStore.dispatchBatch(payloads.map { it.envelope })
                withContext(Dispatchers.Main) {
                    if (update.enabled) scheduleSavedReturnPlan()
                    refreshPlatformUiState()
                }
            } catch (_: Throwable) {
                // The next idle/resume pass retries from the latest OS truth.
            }
        }
    }

    /** Only explicit native presentation markers may reach the media service. */
    private fun nativePresentationMarker(actionId: String): String? = when {
        actionId.startsWith("chooseSchool:") ||
            actionId.startsWith("relationship:") ||
            actionId.startsWith("train:") ||
            actionId.startsWith("proPlan:") ||
            actionId.startsWith("seasonDecision:") ||
            actionId.startsWith("offseason:") ||
            actionId.startsWith("selectLegacy:") ||
            actionId.startsWith("toggle") -> "menu-tap"
            actionId.startsWith("awakening:") ||
            actionId.startsWith("acceptOffer:") ||
            actionId.startsWith("selectProLegacy:") ||
            actionId in setOf("resolveDraft", "confirmDraftResult", "nationalTeam:acknowledge", "acknowledgeSettlement", "quickRebirth", "retire", "startLinked") -> "milestone"
            actionId.startsWith("investment:") ||
            actionId.startsWith("ack:") ||
            actionId in setOf("startHighSchool", "beginTutorial", "completeTutorial", "prepareReturnPlan", "claimWeeklyReward", "finalizeArchive", "customizeRebirth", "signContract", "advanceChapter", "chooseSchool") -> "pad-confirm"
        else -> null
    }

    private fun recordSessionEnded() {
        if (sessionEndedRecorded || !::platform.isInitialized) return
        sessionEndedRecorded = true
        val state = (application as BaseballApplication).gameStore.current
        val run = state.highSchool?.run
        val plan = state.highSchool?.returnPlan
        val sessionGames = if (state.meta.completedGameCount >= sessionStartedCompletedGames) {
            state.meta.completedGameCount - sessionStartedCompletedGames
        } else {
            0UL
        }
        recordMatrixEvent(
            PendingMatrixEvent(
                screen = Phase8ScreenProjection.preferredScreen(state),
                actionId = "sessionEnded",
                eventName = "session_ended",
                scope = "session:${state.revision}:${sessionStartedElapsed}",
                properties = buildList {
                    add("minutes" to ((SystemClock.elapsedRealtime() - sessionStartedElapsed) / 60_000L).toString())
                    add("life_number" to (run?.lifeNumber ?: 0).toString())
                    add("games" to sessionGames.toString())
                    add("important_games_total" to (run?.performance?.importantGamesCompleted ?: 0).toString())
                    add("phase" to (run?.phase?.wire ?: state.stage.wire))
                    add("act_number" to (run?.chapter?.number?.let { (it + 1) / 2 } ?: 0).toString())
                    add("lives_finished" to (state.highSchool?.archive?.size ?: 0).toString())
                    val eligible = state.meta.completedGameCount > 0UL && plan != null && !plan.dismissed &&
                        plan.experimentId != null && plan.experimentVariant in setOf("holdout", "guided") &&
                        plan.savedDayKey != null && plan.developmentRulesVersion != null
                    add("return_eligible" to eligible.toString())
                    if (eligible) plan?.let {
                        add("return_destination" to it.destination.wire)
                        add("return_reason" to it.reason)
                        add("plan_receipt" to it.receiptId)
                        it.experimentId?.let { id -> add("experiment_id" to id) }
                        it.experimentVariant?.let { variant -> add("variant" to variant) }
                        it.developmentRulesVersion?.let { version -> add("development_rules_version" to version.toString()) }
                    } else {
                        add("return_destination" to "none")
                        add("return_reason" to "ineligible")
                        add("plan_receipt" to "none")
                        add("experiment_id" to "none")
                        add("variant" to "ineligible")
                        add("development_rules_version" to "0")
                    }
                },
            ),
        )
    }
}
