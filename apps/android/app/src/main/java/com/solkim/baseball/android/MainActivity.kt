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
import com.solkim.baseball.application.ReturnVisitPresentation
import com.solkim.baseball.application.CareerUiRules
import com.solkim.baseball.platform.ReminderScheduleResult
import com.solkim.baseball.application.GameCopyArgument
import com.solkim.baseball.application.GameAggregateState
import com.solkim.baseball.application.AvatarRole
import com.solkim.baseball.application.ScreenCommandContext
import com.solkim.baseball.application.ScreenController
import com.solkim.baseball.application.ScreenPayloads
import com.solkim.baseball.application.ScreenId
import com.solkim.baseball.application.ScreenProjection
import com.solkim.baseball.application.LifeCardProjection
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
import com.solkim.baseball.application.AnalyticsProjector
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
    internal lateinit var screenController: ScreenController
    internal lateinit var platform: com.solkim.baseball.platform.NativePlatform
    internal fun platformReady(): Boolean = ::platform.isInitialized
    internal val commandContext = ScreenCommandContext()
    internal val activityScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    internal var pendingSeedCode by mutableStateOf<SeedChallengeCode?>(null)
    internal var showSeedDialog by mutableStateOf(false)
    internal var showSeedExitDialog by mutableStateOf(false)
    internal var invalidSeedLink by mutableStateOf(false)
    internal var actionError by mutableStateOf<String?>(null)
    internal var showResetConfirmation by mutableStateOf(false)
    internal var restoringProgress by mutableStateOf(false)
    internal var actionInFlight by mutableStateOf(false)
    internal var openingMound by mutableStateOf(false)
    internal var previousActionScreen: ScreenId? = null
    internal var navigationTapBlockUntil = 0L
    internal var navigationTapBlocked by mutableStateOf(false)
    internal var selectedScreen by mutableStateOf<ScreenId?>(null)
    internal var platformUiState by mutableStateOf(
        PlatformUiState(NotificationPermissionTruth.UNAVAILABLE, null),
    )
    internal var pendingNotificationToken by mutableStateOf<String?>(null)
    internal val pendingMatrixEvents = linkedMapOf<String, PendingMatrixEvent>()
    internal val matrixEventsInFlight = mutableSetOf<String>()
    internal var pendingNotificationSource: String? = null
    internal var notificationSettingsReturnPending = false
    internal var sessionEndedRecorded = false
    internal var sessionStartedElapsed = 0L
    internal var sessionStartedCompletedGames = 0UL

    internal data class PendingMatrixEvent(
        val screen: ScreenId,
        val actionId: String,
        val eventName: String,
        val scope: String,
        val properties: List<Pair<String, String>>,
        val onCommitted: (() -> Unit)? = null,
    )

    internal var returnNoticeKey by mutableStateOf<String?>(null)
    internal val returnPreferences get() = getSharedPreferences("return-reminder", MODE_PRIVATE)

    internal val notificationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) {
        if (returnPreferences.getBoolean("pending", false)) scheduleCurrentReturnPlan(showResult = true)
        reconcileNotificationTruth("system")
        refreshPlatformUiState()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        setTheme(R.style.Theme_BaseballMigration)
        super.onCreate(savedInstanceState)
        val store = (application as BaseballApplication).gameStore
        platform = (application as BaseballApplication).platform
        screenController = ScreenController(store, commandContext)
        sessionStartedElapsed = SystemClock.elapsedRealtime()
        sessionStartedCompletedGames = store.current.meta.completedGameCount
        pendingSeedCode = getSharedPreferences("seed-link", MODE_PRIVATE).getString("pending", null)?.let(SeedChallengeCode::parse)
        acceptSeedIntent(intent)
        acceptNotificationIntent(intent)
        inspectPhase10PlatformIntent(intent)
        recordReturnPlanOpenAnalytics("cold")
        refreshPlatformUiState()
        setContent { CareerRoot() }
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
            if (source == "settings" && returnPreferences.getBoolean("pending", false)) scheduleCurrentReturnPlan(showResult = true)
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

    internal fun rememberSeed(code: SeedChallengeCode) {
        pendingSeedCode = code
        getSharedPreferences("seed-link", MODE_PRIVATE).edit().putString("pending", code.token).apply()
    }

    internal fun acceptSeedIntent(intent: Intent?) {
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

    internal fun performSeedCommand(command: GameCommand, onCommitted: () -> Unit = {}) {
        actionError = null
        activityScope.launch {
            try {
                val store = (application as BaseballApplication).gameStore
                val current = store.current
                store.dispatch(GameCommandEnvelope(com.solkim.baseball.application.CommandReceiptRetention.id(current.revision, "seed-action"), com.solkim.baseball.application.CareerWire.UI_SESSION, current.revision, command))
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
    internal val actionFailures = com.solkim.baseball.application.GameActionFailurePresentation.Repetition()

    internal fun performCareerAction(action: ScreenUiAction) {
        if (action.actionId == "prepareReturnPlan") { requestReturnReminder(); return }
        if (action.actionId == "dismissReturnPlan") {
            platform.notifications.scheduler.cancelScheduled()
            returnPreferences.edit().clear().putBoolean("dismissed", true).apply()
            returnNoticeKey = "android.r3.reminder.cancelled"; return
        }

        if (actionInFlight || (application as BaseballApplication).gameStore.busy.value) return
        if (action.screenId != previousActionScreen && android.os.SystemClock.elapsedRealtime() < navigationTapBlockUntil) return
        actionInFlight = true
        openingMound = action.actionId in setOf("startHighSchool", "openTutorialPitch", "resumePitch", "openImportantGame", "openProImportantGame", "nextImportantPitch", "nextProPitch")
        var launchedMound = false
        actionError = null
        val completedGamesBefore = (application as BaseballApplication).gameStore.current.meta.completedGameCount
        activityScope.launch {
            try {
                val beforeAction = (application as BaseballApplication).gameStore.current
                val execution = screenController.executePlayerAction(
                    screenId = action.screenId,
                    actionId = action.actionId,
                    capturedPayloads = action.capturedPayloads,
                )
                withContext(Dispatchers.Main) {
                    saveTrainingFeedback(this@MainActivity, beforeAction, (application as BaseballApplication).gameStore.current)
                    saveConversationFeedback(this@MainActivity, beforeAction, (application as BaseballApplication).gameStore.current)
                    saveProWeekFeedback(this@MainActivity, beforeAction, (application as BaseballApplication).gameStore.current)
                    if (screenController.preferredScreen() != action.screenId) {
                        previousActionScreen = action.screenId
                        val deadline = android.os.SystemClock.elapsedRealtime() + 500
                        navigationTapBlockUntil = deadline
                        navigationTapBlocked = true
                        activityScope.launch {
                            kotlinx.coroutines.delay(500)
                            withContext(Dispatchers.Main) {
                                if (navigationTapBlockUntil == deadline) navigationTapBlocked = false
                            }
                        }
                    }
                    // Preferences keep their current page so multiple changes can be made in place.
                    if (action.screenId != ScreenId.P027_SETTINGS || action.actionId == "resetProgress") selectedScreen = null
                    if (action.actionId == "resetProgress") { showResetConfirmation = false; returnPreferences.edit().clear().putBoolean("dismissed", true).apply() }
                    execution.launch?.let { launch ->
                        launchedMound = true
                        openingMound = true
                        startActivity(PitchActivity.intent(this@MainActivity, launch.sessionId, launch.expectedRevision.toString()))
                    }
                    actionFailures.clear()
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
                android.util.Log.e("MainActivity", "performCareerAction failed", error)
                // Refresh an uncertain earlier commit before allowing another choice.
                val failure = com.solkim.baseball.application.GameActionFailurePresentation.classify(error,
                    com.solkim.baseball.application.GameActionFailurePresentation.causes(error).any {
                        it is android.system.ErrnoException && it.errno == android.system.OsConstants.ENOSPC
                    })
                val reconciliation = if (failure.kind == com.solkim.baseball.application.GameActionFailurePresentation.Kind.RULE) null else try {
                    (application as BaseballApplication).gameStore.reconcilePersistedRevision()
                } catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled }
                catch (refreshError: Exception) { android.util.Log.w("MainActivity", "action reconciliation failed", refreshError); null }
                val refreshed = reconciliation?.reconciled == true
                withContext(Dispatchers.Main) {
                    val restoredState = (application as BaseballApplication).gameStore.current
                    if (action.actionId == "resetProgress" && reconciliation?.durableStateVerified == true && restoredState.stage == com.solkim.baseball.application.GameStage.OPENING &&
                        !CareerUiRules.hasCareer(restoredState)) {
                        showResetConfirmation = false
                        selectedScreen = null
                        actionError = null
                        applyNativeSettings()
                        refreshPlatformUiState()
                        return@withContext
                    }
                    val repeated = actionFailures.record(action.actionId, failure, restoredState.revision)
                    actionError = com.solkim.baseball.application.GameActionFailurePresentation.message(failure, action.actionId, repeated, refreshed)
                }
            } finally {
                withContext(kotlinx.coroutines.NonCancellable + Dispatchers.Main) {
                    actionInFlight = false
                    if (!launchedMound) openingMound = false
                }
            }
        }
    }

    internal fun performPlatformAction(action: PlatformUiAction) {
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
                val selected = LifeCardProjection.selected(state, payload.careerId)
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
                val record = CareerUiRules.archiveRecord(state, payload.careerId)
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
                            screen = ScreenId.P028_LIFECARD,
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
                if (decoded.screenWire !in setOf(ScreenId.P014_RUN_RECAP.wire, ScreenId.P015_REBIRTH.wire)) {
                    actionError = "지금은 리뷰를 묻는 장면이 아니에요."
                    return
                }
                val reason = action.reviewReason ?: run {
                    actionError = "리뷰 창을 열 수 없었어요. 다음 기회에 다시 물어볼게요."
                    return
                }
                val expectedReason = ScreenProjection.reviewTrigger(state)?.let {
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

    internal fun acceptNotificationIntent(intent: Intent?) {
        val recovery = platform.inspectNotification(intent) ?: return
        val state = (application as BaseballApplication).gameStore.current
        if (CareerUiRules.challengeActive(state)) return
        val plan = CareerUiRules.returnPlan(state)?.takeIf { it.receiptId == recovery.open.planReceipt }
        val properties = buildList {
            add("destination" to recovery.open.destination.wire)
            add("reason" to recovery.open.reason)
            add("plan_receipt" to recovery.open.planReceipt)
            plan?.experimentId?.let { add("experiment_id" to it) }
            plan?.experimentVariant?.let { add("variant" to it) }
            plan?.let { add("saved_day_key" to (it.savedDayKey ?: it.createdDayKey)) }
            plan?.developmentRulesVersion?.let { add("development_rules_version" to it.toString()) }
        }
        val requested = if (recovery.open.destination == NotificationDestination.RECORDS) ScreenId.P025_RECORDS_LEAGUE else ReturnVisitPresentation.screen(state)
        val route = requested.takeIf { ScreenProjection.isReachable(state, it) }
            ?: ScreenProjection.preferredScreen(state)
        returnNoticeKey = null
        // Opening the player's game must not wait for telemetry delivery or its retries.
        selectedScreen = route
        pendingNotificationToken = recovery.open.tokenHash
        val receiptId = AnalyticsProjector.receiptId(state.installId, "reminder_opened", "notification:${recovery.open.tokenHash}")
        if (state.analytics.receipts.any { it.receiptId == receiptId }) {
            platform.markNotificationAnalytics(recovery.open.tokenHash)
        } else {
            recordMatrixEvent(
                PendingMatrixEvent(
                    screen = ScreenId.P029_RETURN_PLAN,
                    actionId = "notificationOpen",
                    eventName = "reminder_opened",
                    scope = "notification:${recovery.open.tokenHash}",
                    properties = properties,
                    onCommitted = {
                        platform.markNotificationAnalytics(recovery.open.tokenHash)
                    },
                ),
            )
        }
    }

    /** Read-only internal rehearsal probe; it is unavailable in the debug shadow package. */
    internal fun inspectPhase10PlatformIntent(intent: Intent?) {
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

    internal fun refreshPlatformUiState() {
        if (!::platform.isInitialized) return
        val state = (application as BaseballApplication).gameStore.current
        val reason = ScreenProjection.reviewTrigger(state)?.let {
            when (it) {
                "third-life" -> ReviewReason.THIRD_LIFE
                "good-recap" -> ReviewReason.GOOD_RECAP
                "drafted-reveal-confirmed" -> ReviewReason.DRAFTED_REVEAL_CONFIRMED
                else -> null
            }
        }
        platformUiState = PlatformUiState(
            notificationTruth = platform.notifications.permission.truth(),
            reviewDecision = reason?.let(platform.review::eligibility),
            notificationPermissionAsked = platform.stateStore.read().notificationPermissionAsked,
            reminderOfferDeclined = platform.notifications.permission.reminderOfferDeclined(),
        )
    }

}
