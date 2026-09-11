package com.solkim.baseball.android

import android.Manifest
import android.os.Build
import android.os.SystemClock
import com.solkim.baseball.application.AnalyticsProjector
import com.solkim.baseball.application.CareerUiRules
import com.solkim.baseball.application.GameCommand
import com.solkim.baseball.application.HighSchoolDisplayRules
import com.solkim.baseball.application.HighSchoolReturnDestination
import com.solkim.baseball.application.ReturnVisitPresentation
import com.solkim.baseball.application.ScreenId
import com.solkim.baseball.application.ScreenPayloads
import com.solkim.baseball.application.ScreenProjection
import com.solkim.baseball.platform.NativeAudioResources
import com.solkim.baseball.platform.NativePlaybackSettings
import com.solkim.baseball.platform.NativeReminderPlan
import com.solkim.baseball.platform.NotificationDestination
import com.solkim.baseball.platform.NotificationPermissionTruth
import com.solkim.baseball.platform.NotificationTruthUpdatePolicy
import com.solkim.baseball.platform.ReminderScheduleResult
import com.solkim.baseball.platform.ReviewReason
import com.solkim.baseball.platform.ReviewResult
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Mirrors the iOS callers: the request is attempted only after the exact rendered product
 * moment has been durably acknowledged by the aggregate. A route visit alone can never prompt.
 */
internal fun MainActivity.requestReviewAtProductMoment(actionId: String) {
    val reason = when (actionId) {
        "confirmDraftResult" -> ReviewReason.DRAFTED_REVEAL_CONFIRMED
        "confirmRecap" -> ReviewReason.GOOD_RECAP
        "quickRebirth",
        "startHighSchool" -> ReviewReason.THIRD_LIFE
        else -> return
    }
    val state = (application as BaseballApplication).gameStore.current
    val trigger = ScreenProjection.reviewTrigger(state)
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

internal fun MainActivity.applyNativeSettings() {
    if (!playbackSettings().soundEnabled) platform.audioHaptics.stopEffects()
    platform.audioHaptics.startMusic(NativeAudioResources.musicToggleResource(), playbackSettings())
}

internal fun MainActivity.recordReturnPlanOpenAnalytics(launchType: String) {
    if (launchType !in setOf("cold", "warm")) return
    val state = (application as BaseballApplication).gameStore.current
    if (state.meta.completedGameCount == 0UL) return
    val plan = CareerUiRules.returnPlan(state) ?: return
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
        MainActivity.PendingMatrixEvent(
            screen = ScreenId.P029_RETURN_PLAN,
            actionId = "returnPlanNextDayOpen",
            eventName = "return_plan_next_day_open",
            scope = scope,
            properties = properties,
        ),
    )
    if (launchType == "cold") {
        recordMatrixEvent(
            MainActivity.PendingMatrixEvent(
                screen = ScreenId.P029_RETURN_PLAN,
                actionId = "returnPlanColdStart",
                eventName = "return_plan_cold_start",
                scope = scope,
                properties = properties,
            ),
        )
    }
}

internal fun MainActivity.playbackSettings(): NativePlaybackSettings {
    val settings = (application as BaseballApplication).gameStore.current.settings
    return NativePlaybackSettings(settings.soundEnabled, settings.musicEnabled, settings.hapticsEnabled, settings.reducedMotionEnabled)
}

internal fun MainActivity.requestReturnReminder() {
    val state = (application as BaseballApplication).gameStore.current
    val owner = ReturnVisitPresentation.owner(state)
    if (owner.isBlank() || state.meta.seedChallenge != null) return
    selectedScreen = ScreenId.P029_RETURN_PLAN
    val day = commandContext.clock.today()
    val trigger = day.plusDays(1).atTime(9, 0).atZone(ZoneId.of("Asia/Seoul")).toInstant().toEpochMilli()
    returnPreferences.edit().putString("owner", owner).putString("day", day.toString()).putLong("trigger", trigger)
        .putBoolean("enabled", true).putBoolean("pending", true).putBoolean("dismissed", false).commit()
    if (platform.notifications.permission.truth() == NotificationPermissionTruth.ALLOWED) scheduleCurrentReturnPlan(true)
    else if (Build.VERSION.SDK_INT >= 33 && platform.notifications.permission.shouldRequest()) {
        platform.notifications.permission.markRequestIssued()
        notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
    } else {
        returnPreferences.edit().putBoolean("pending", false).apply()
        returnNoticeKey = "android.r3.reminder.blocked"
    }
}

internal fun MainActivity.scheduleCurrentReturnPlan(showResult: Boolean) {
    val state = (application as BaseballApplication).gameStore.current
    if (state.meta.seedChallenge != null) return
    val prefs = returnPreferences
    if (!prefs.getBoolean("enabled", false)) return
    if (prefs.getString("owner", null) != ReturnVisitPresentation.owner(state)) {
        prefs.getString("token", null)?.let { platform.notifications.scheduler.cancel(it) }
        prefs.edit().putBoolean("enabled", false).putBoolean("pending", false).apply()
        return
    }
    val trigger = prefs.getLong("trigger", 0)
    if (trigger <= System.currentTimeMillis()) {
        prefs.edit().putBoolean("enabled", false).putBoolean("pending", false).apply()
        if (showResult) returnNoticeKey = "android.r3.reminder.expired"
        return
    }
    val destination = if (ReturnVisitPresentation.isPro(state)) NotificationDestination.PRO else NotificationDestination.HIGH_SCHOOL
    val receipt = "return:" + com.solkim.baseball.platform.StableNotificationToken.hash("${ReturnVisitPresentation.owner(state)}:${prefs.getString("day", "")}").take(40)
    val token = "$receipt|${destination.wire}"
    val copy = com.solkim.baseball.application.GameCopy(com.solkim.baseball.application.GameLanguage.fromTag(resources.configuration.locales[0].language))
    val result = runCatching { platform.notifications.scheduler.scheduleReplacing(NativeReminderPlan(trigger, destination, "continue", receipt, token,
        copy.resolve("android.r3.reminder.title"), copy.legacy(ReturnVisitPresentation.detail(state)))) }.getOrElse { ReminderScheduleResult.Rejected("alarm") }
    prefs.edit().putBoolean("pending", false).apply()
    when (result) {
        is ReminderScheduleResult.Scheduled -> {
            prefs.getString("token", null)?.takeIf { it != token }?.let { platform.notifications.scheduler.cancel(it) }
            prefs.edit().putString("token", token).apply()
            if (showResult) returnNoticeKey = "android.r3.reminder.scheduled"
        }
        is ReminderScheduleResult.Blocked -> if (showResult) returnNoticeKey = "android.r3.reminder.blocked"
        is ReminderScheduleResult.Rejected -> if (showResult) returnNoticeKey = "android.r3.reminder.failed"
    }
}

internal fun MainActivity.scheduleSavedReturnPlan() {
    if (returnPreferences.getBoolean("dismissed", false)) return
    if (returnPreferences.contains("owner")) {
        scheduleCurrentReturnPlan(returnPreferences.getBoolean("pending", false)); return
    }

    val current = (application as BaseballApplication).gameStore.current
    if (ReturnVisitPresentation.isPro(current)) return
    val plan = CareerUiRules.returnPlan(current) ?: return
    if (plan.dismissed || plan.destination == HighSchoolReturnDestination.DAILY_INNING) return
    val destination = when (plan.destination) {
        HighSchoolReturnDestination.HIGH_SCHOOL -> NotificationDestination.HIGH_SCHOOL
        HighSchoolReturnDestination.PRO -> NotificationDestination.PRO
        HighSchoolReturnDestination.DAILY_INNING -> return
    }
    val savedDay = runCatching { LocalDate.parse(plan.savedDayKey ?: plan.createdDayKey) }.getOrElse { commandContext.clock.today() }
    val trigger = savedDay.plusDays(1).atTime(LocalTime.of(9, 0)).atZone(ZoneId.of("Asia/Seoul")).toInstant().toEpochMilli()
    val state = (application as BaseballApplication).gameStore.current
    val playerName = CareerUiRules.playerName(state)
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

internal fun MainActivity.recordViewportExposure(exposure: ViewportExposure) {
    recordMatrixEvent(
        MainActivity.PendingMatrixEvent(
            screen = ScreenProjection.preferredScreen((application as BaseballApplication).gameStore.current),
            actionId = "viewport:${exposure.eventName}",
            eventName = exposure.eventName,
            scope = exposure.scope,
            properties = exposure.properties,
        ),
    )
}

internal fun MainActivity.recordMatrixEvent(event: MainActivity.PendingMatrixEvent) {
    if (CareerUiRules.challengeActive((application as BaseballApplication).gameStore.current)) return
    val key = "${event.eventName}|${event.scope}"
    pendingMatrixEvents[key] = event
    attemptMatrixEvent(key)
}

internal fun MainActivity.attemptMatrixEvent(key: String) {
    if (matrixEventsInFlight.contains(key) || (application as BaseballApplication).gameStore.busy.value) return
    val event = pendingMatrixEvents[key] ?: return
    matrixEventsInFlight += key
    activityScope.launch {
        try {
            val state = (application as BaseballApplication).gameStore.current
            val payload = ScreenPayloads.analytics(state, event.screen, event.actionId, event.eventName, event.scope, event.properties)
            val receiptId = AnalyticsProjector.receiptId(state.installId, event.eventName, event.scope)
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

internal fun MainActivity.retryPendingMatrixEvents() {
    if ((application as BaseballApplication).gameStore.busy.value) return
    (application as BaseballApplication).gameStore.retryAnalyticsHandoff()
    pendingMatrixEvents.keys.toList().forEach(::attemptMatrixEvent)
}

internal fun MainActivity.reconcileNotificationTruth(source: String) {
    if (!platformReady()) return
    if ((application as BaseballApplication).gameStore.busy.value) {
        pendingNotificationSource = source
        return
    }
    val truth = platform.notifications.permission.truth()
    val state = (application as BaseballApplication).gameStore.current
    val receiptScope = "notification-settings:$source:allowed"
    val allowedReceiptId = AnalyticsProjector.receiptId(state.installId, "reminder_changed", receiptScope)
    val blockedReceiptId = AnalyticsProjector.receiptId(state.installId, "reminder_changed", "notification-settings:$source:blocked")
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
                receiptId = AnalyticsProjector.receiptId(state.installId, "reminder_changed", update.receiptScope),
                eventName = "reminder_changed",
                properties = listOf("enabled" to update.enabled.toString(), "source" to source),
            ),
        )
    }
    if (commands.isEmpty()) {
        if (update.enabled) scheduleSavedReturnPlan()
        return
    }
    val payloads = ScreenPayloads.batch(state, ScreenId.P027_SETTINGS, "notificationTruth:$source", commands)
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
internal fun MainActivity.nativePresentationMarker(actionId: String): String? = when {
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

internal fun MainActivity.recordSessionEnded() {
    if (sessionEndedRecorded || !platformReady()) return
    sessionEndedRecorded = true
    val state = (application as BaseballApplication).gameStore.current
    val run = CareerUiRules.schoolFacts(state)
    val plan = CareerUiRules.returnPlan(state)
    val sessionGames = if (state.meta.completedGameCount >= sessionStartedCompletedGames) {
        state.meta.completedGameCount - sessionStartedCompletedGames
    } else {
        0UL
    }
    recordMatrixEvent(
        MainActivity.PendingMatrixEvent(
            screen = ScreenProjection.preferredScreen(state),
            actionId = "sessionEnded",
            eventName = "session_ended",
            scope = "session:${state.revision}:${sessionStartedElapsed}",
            properties = buildList {
                add("minutes" to ((SystemClock.elapsedRealtime() - sessionStartedElapsed) / 60_000L).toString())
                add("life_number" to (run?.lifeNumber ?: 0).toString())
                add("games" to sessionGames.toString())
                add("important_games_total" to (run?.importantGames ?: 0).toString())
                add("phase" to (run?.phaseWire ?: state.stage.wire))
                add("act_number" to (run?.chapterNumber?.let { (it + 1) / 2 } ?: 0).toString())
                add("lives_finished" to CareerUiRules.archiveSize(state).toString())
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
