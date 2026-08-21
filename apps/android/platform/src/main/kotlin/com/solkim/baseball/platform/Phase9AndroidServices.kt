package com.solkim.baseball.platform

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.AudioTrack
import android.media.MediaPlayer
import android.media.SoundPool
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.amplitude.api.Amplitude
import com.amplitude.api.AmplitudeClient
import com.google.android.play.core.review.ReviewManagerFactory
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.crashlytics.FirebaseCrashlytics
import com.google.firebase.FirebaseApp
import com.solkim.baseball.model.Hashing
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine
import com.solkim.baseball.model.PresentationMarker
import java.io.File
import java.util.Locale
import kotlin.math.sqrt
import kotlin.coroutines.resume

public data class Phase9NativeSdkConfiguration(
    public val externalSdkEnabled: Boolean = false,
    public val amplitudeApiKey: String? = null,
    public val analyticsConsent: Boolean = false,
    public val diagnosticsConsent: Boolean = false,
    public val distribution: String = "development",
    public val environment: String = "compose-dev",
) {
    init {
        require(distribution in setOf("editor", "development", "internal", "closed", "production")) { "platform.distribution" }
        if (externalSdkEnabled) require(!amplitudeApiKey.isNullOrBlank()) { "platform.amplitude_key_missing" }
    }
}

public class FirebaseAnalyticsDestination(
    context: Context,
    private val configuration: Phase9NativeSdkConfiguration,
) : AnalyticsDestination {
    override val id: String = "firebase"
    private val analytics: FirebaseAnalytics? = if (!configuration.externalSdkEnabled || !configuration.analyticsConsent) {
        null
    } else {
        runCatching {
            FirebaseApp.initializeApp(context)
            FirebaseAnalytics.getInstance(context).also { it.setAnalyticsCollectionEnabled(true) }
        }.getOrNull()
    }
    override val available: Boolean get() = analytics != null

    override fun enqueue(event: NativeAnalyticsEvent, context: AnalyticsContext) {
        val destination = requireNotNull(analytics) { "firebase.unavailable" }
        val bundle = Bundle()
        context.properties("android_native").forEach { (key, value) -> bundle.putProperty(key, value, firebaseBooleanAsLong = true) }
        event.properties.forEach { (key, value) -> bundle.putProperty(key, value, firebaseBooleanAsLong = true) }
        destination.logEvent(event.eventName, bundle)
    }

    override fun flush() = Unit
    override fun clear() { runCatching { analytics?.resetAnalyticsData() } }
}

public class AmplitudeAnalyticsDestination(
    context: Context,
    private val configuration: Phase9NativeSdkConfiguration,
    private val installId: String,
) : AnalyticsDestination {
    override val id: String = "amplitude"
    private val client: AmplitudeClient? = if (!configuration.externalSdkEnabled || !configuration.analyticsConsent) {
        null
    } else {
        runCatching {
            Amplitude.initialize(context, requireNotNull(configuration.amplitudeApiKey))
            Amplitude.getInstance().also {
                it.enableNewDeviceIdPerInstall(true)
                it.disableLocationListening()
                it.setDeviceId(Hashing.sha256Hex(installId).take(32))
                it.setOptOut(false)
            }
        }.getOrNull()
    }
    override val available: Boolean get() = client != null

    override fun enqueue(event: NativeAnalyticsEvent, context: AnalyticsContext) {
        val destination = requireNotNull(client) { "amplitude.unavailable" }
        val json = org.json.JSONObject()
        context.properties("android_native").forEach { (key, value) -> json.put(key, value.toJsonValue()) }
        event.properties.forEach { (key, value) -> json.put(key, value.toJsonValue()) }
        destination.logEvent(event.eventName, json)
    }

    override fun flush() { runCatching { client?.uploadEvents() } }
    override fun clear() { runCatching { client?.setOptOut(true) } }
}

public interface NativeCrashReporter {
    public val available: Boolean
    public fun setContext(context: CrashContext)
    public fun recordException(error: Throwable)
    public fun log(message: String)
}

public data class CrashContext(
    public val distribution: String,
    public val appSchema: String,
    public val phase: String,
    public val life: Int,
    public val qualityTier: String,
    public val unityLoaded: Boolean,
    public val stageReady: Boolean,
) {
    init {
        require(distribution in setOf("editor", "development", "internal", "closed", "production")) { "crash.distribution" }
        require(appSchema.isNotBlank() && appSchema.length <= 48) { "crash.schema" }
        require(phase.isNotBlank() && phase.length <= 48) { "crash.phase" }
        require(life >= 0) { "crash.life" }
        require(qualityTier in setOf("high", "low")) { "crash.quality" }
    }
}

public class FirebaseCrashReporter(
    context: Context,
    private val configuration: Phase9NativeSdkConfiguration,
) : NativeCrashReporter {
    private val crashlytics: FirebaseCrashlytics? = if (!configuration.externalSdkEnabled || !configuration.diagnosticsConsent) {
        null
    } else {
        runCatching {
            FirebaseApp.initializeApp(context)
            FirebaseCrashlytics.getInstance().also { it.setCrashlyticsCollectionEnabled(true) }
        }.getOrNull()
    }
    override val available: Boolean get() = crashlytics != null

    override fun setContext(context: CrashContext) {
        crashlytics?.let {
            it.setCustomKey("distribution", context.distribution)
            it.setCustomKey("app_schema", context.appSchema)
            it.setCustomKey("phase", context.phase)
            it.setCustomKey("life", context.life)
            it.setCustomKey("quality_tier", context.qualityTier)
            it.setCustomKey("unity_loaded", context.unityLoaded)
            it.setCustomKey("stage_ready", context.stageReady)
        }
    }

    override fun recordException(error: Throwable) { runCatching { crashlytics?.recordException(error) } }
    override fun log(message: String) { if (message.length <= 120) runCatching { crashlytics?.log(message) } }
}

public enum class NotificationPermissionTruth {
    ALLOWED,
    /** API 33+ has not yet shown the request dialog and the OS still permits requesting. */
    REQUESTABLE,
    DENIED,
    BLOCKED,
    UNAVAILABLE,
}

public object NotificationPermissionPolicy {
    public fun classify(
        api33OrNewer: Boolean,
        permissionGranted: Boolean,
        notificationsEnabled: Boolean,
        permissionAsked: Boolean,
    ): NotificationPermissionTruth = when {
        !api33OrNewer -> if (notificationsEnabled) NotificationPermissionTruth.ALLOWED else NotificationPermissionTruth.BLOCKED
        permissionGranted -> NotificationPermissionTruth.ALLOWED
        // A fresh API 33+ install must be requestable even when the compatibility notification
        // manager reports the pre-request channel as disabled. Only a durable asked bit turns the
        // same OS reading into DENIED/BLOCKED on subsequent launches.
        !permissionAsked -> NotificationPermissionTruth.REQUESTABLE
        !notificationsEnabled -> NotificationPermissionTruth.BLOCKED
        else -> NotificationPermissionTruth.DENIED
    }

    public fun shouldRequest(truth: NotificationPermissionTruth): Boolean = truth == NotificationPermissionTruth.REQUESTABLE
}

public object ReminderOfferPolicy {
    public fun shouldShow(
        completedGameCount: ULong,
        truth: NotificationPermissionTruth,
        permissionAsked: Boolean,
        offerDeclined: Boolean,
        aggregateEnabled: Boolean,
    ): Boolean = completedGameCount > 0UL &&
        truth == NotificationPermissionTruth.REQUESTABLE &&
        !permissionAsked &&
        !offerDeclined &&
        !aggregateEnabled
}

/**
 * Decides what may be copied from the operating system into the aggregate.  The aggregate never
 * guesses permission state: only a concrete ALLOWED/DENIED/BLOCKED reading can produce an update.
 * Permission callbacks and resume-time external-revoke checks get a stable source/value scope so
 * a process restart retries a missing receipt without turning every resume into a duplicate.
 */
public data class NotificationTruthUpdate(
    public val enabled: Boolean,
    public val shouldPersistAggregate: Boolean,
    public val shouldRecordAnalytics: Boolean,
    public val receiptScope: String,
)

public object NotificationTruthUpdatePolicy {
    public fun decide(
        currentAggregateEnabled: Boolean,
        truth: NotificationPermissionTruth,
        source: String,
        receiptAlreadyPresent: Boolean,
    ): NotificationTruthUpdate? {
        require(source in setOf("after_first_game", "settings", "system")) { "notification.source" }
        val enabled = when (truth) {
            NotificationPermissionTruth.ALLOWED -> true
            NotificationPermissionTruth.DENIED,
            NotificationPermissionTruth.BLOCKED -> false
            NotificationPermissionTruth.REQUESTABLE,
            NotificationPermissionTruth.UNAVAILABLE -> return null
        }
        val truthObservedSource = source == "system"
        return NotificationTruthUpdate(
            enabled = enabled,
            shouldPersistAggregate = currentAggregateEnabled != enabled,
            shouldRecordAnalytics = !receiptAlreadyPresent && (currentAggregateEnabled != enabled || truthObservedSource),
            receiptScope = "notification-settings:$source:${if (enabled) "allowed" else "blocked"}",
        )
    }
}

public class NativeNotificationPermission(
    private val context: Context,
    private val stateStore: PlatformStateStore = InMemoryPlatformStateStore(),
) {
    public fun truth(): NotificationPermissionTruth {
        val notificationsEnabled = NotificationManagerCompat.from(context).areNotificationsEnabled()
        if (Build.VERSION.SDK_INT < 33) return NotificationPermissionPolicy.classify(false, true, notificationsEnabled, true)
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        return NotificationPermissionPolicy.classify(true, granted, notificationsEnabled, stateStore.read().notificationPermissionAsked)
    }

    public fun shouldRequest(): Boolean = Build.VERSION.SDK_INT >= 33 && NotificationPermissionPolicy.shouldRequest(truth())

    /** Must be called before launching the OS dialog, not after a callback that may be lost. */
    public fun markRequestIssued() {
        stateStore.update { if (it.notificationPermissionAsked) it else it.copy(notificationPermissionAsked = true) }
    }

    public fun reminderOfferDeclined(): Boolean = stateStore.read().reminderOfferDeclined

    public fun markReminderOfferDeclined() {
        stateStore.update { if (it.reminderOfferDeclined) it else it.copy(reminderOfferDeclined = true) }
    }

    public fun openSystemSettings() {
        context.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        })
    }
}

public data class NativeReminderPlan(
    public val triggerAtUtcMillis: Long,
    public val destination: NotificationDestination,
    public val reason: String,
    public val planReceipt: String,
    public val token: String,
    public val title: String = "다음 장면을 기다리고 있어요",
    public val body: String = "저장된 복귀 계획을 확인해 보세요.",
) {
    init {
        require(triggerAtUtcMillis > 0L) { "reminder.trigger" }
        require(reason.isNotBlank() && reason.length <= 64) { "reminder.reason" }
        require(planReceipt.isNotBlank() && planReceipt.length <= 64) { "reminder.receipt" }
        require(token.isNotBlank() && token.length <= 256) { "reminder.token" }
        require(title.length <= 64 && body.length <= 120) { "reminder.copy" }
    }
}

public sealed interface ReminderScheduleResult {
    public data class Scheduled(public val tokenHash: String) : ReminderScheduleResult
    public data class Blocked(public val truth: NotificationPermissionTruth) : ReminderScheduleResult
    public data class Rejected(public val reason: String) : ReminderScheduleResult
}

public class NativeReminderScheduler(
    private val context: Context,
    private val stateStore: PlatformStateStore? = null,
    private val permission: NativeNotificationPermission = NativeNotificationPermission(context, stateStore ?: InMemoryPlatformStateStore()),
) {
    public companion object {
        public const val CHANNEL_ID: String = "return-plan-v1"
        public const val NOTIFICATION_ID_BASE: Int = 0x42530000
    }

    public fun schedule(plan: NativeReminderPlan): ReminderScheduleResult {
        val truth = permission.truth()
        if (truth != NotificationPermissionTruth.ALLOWED) return ReminderScheduleResult.Blocked(truth)
        if (plan.destination !in setOf(NotificationDestination.HIGH_SCHOOL, NotificationDestination.PRO, NotificationDestination.RECORDS)) return ReminderScheduleResult.Rejected("destination")
        createChannel()
        val tokenHash = StableNotificationToken.hash(plan.token)
        val intent = Intent(context, ReminderAlarmReceiver::class.java).apply {
            action = NotificationIntentNormalizer.ACTION_OPEN_REMINDER
            putExtra(NotificationIntentNormalizer.EXTRA_TOKEN, plan.token)
            putExtra(NotificationIntentNormalizer.EXTRA_DESTINATION, plan.destination.wire)
            putExtra(NotificationIntentNormalizer.EXTRA_REASON, plan.reason)
            putExtra(NotificationIntentNormalizer.EXTRA_PLAN_RECEIPT, plan.planReceipt)
            putExtra("baseball.notification.title", plan.title)
            putExtra("baseball.notification.body", plan.body)
        }
        val pending = PendingIntent.getBroadcast(
            context,
            tokenHash.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarm = context.getSystemService(AlarmManager::class.java)
        val alreadyRegistered = stateStore?.read()?.scheduledReminderTokenHashes?.contains(tokenHash) == true
        if (!alreadyRegistered) {
            runCatching {
                stateStore?.update { state ->
                    if (tokenHash in state.scheduledReminderTokenHashes) state
                    else state.copy(scheduledReminderTokenHashes = state.scheduledReminderTokenHashes + tokenHash)
                }
            }.getOrElse { return ReminderScheduleResult.Rejected("state") }
        }
        return try {
            alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, plan.triggerAtUtcMillis, pending)
            ReminderScheduleResult.Scheduled(tokenHash)
        } catch (_: Throwable) {
            if (!alreadyRegistered) {
                runCatching {
                    stateStore?.update { state -> state.copy(scheduledReminderTokenHashes = state.scheduledReminderTokenHashes.filterNot { it == tokenHash }) }
                }
            }
            ReminderScheduleResult.Rejected("alarm")
        }
    }

    public fun cancel(token: String) {
        val tokenHash = StableNotificationToken.hash(token)
        pendingIntent(tokenHash, PendingIntent.FLAG_NO_CREATE)?.let { context.getSystemService(AlarmManager::class.java).cancel(it) }
        stateStore?.update { it.copy(scheduledReminderTokenHashes = it.scheduledReminderTokenHashes.filterNot { hash -> hash == tokenHash }) }
    }

    public fun cancelAll() {
        cancelScheduled()
        context.getSystemService(NotificationManager::class.java)?.cancelAll()
    }

    /**
     * External permission revoke must not leave a durable schedule that can become live again
     * when the user toggles notifications later. Keep the asked bit and notification-open
     * receipts intact; only invalidate pending reminder alarms.
     */
    public fun cancelScheduled() {
        val alarm = context.getSystemService(AlarmManager::class.java)
        stateStore?.read()?.scheduledReminderTokenHashes.orEmpty().forEach { tokenHash ->
            runCatching { pendingIntent(tokenHash, PendingIntent.FLAG_NO_CREATE)?.let(alarm::cancel) }
        }
        stateStore?.update { it.copy(scheduledReminderTokenHashes = emptyList()) }
    }

    /** Reconstructs the exact broadcast PendingIntent without creating a new alarm. */
    private fun pendingIntent(tokenHash: String, flags: Int): PendingIntent? {
        val intent = Intent(context, ReminderAlarmReceiver::class.java).apply {
            action = NotificationIntentNormalizer.ACTION_OPEN_REMINDER
        }
        return PendingIntent.getBroadcast(
            context,
            tokenHash.hashCode(),
            intent,
            flags or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "복귀 안내", NotificationManager.IMPORTANCE_DEFAULT),
        )
    }
}

public class NativeNotificationService(
    context: Context,
    stateStore: PlatformStateStore,
) {
    public val permission: NativeNotificationPermission = NativeNotificationPermission(context, stateStore)
    public val scheduler: NativeReminderScheduler = NativeReminderScheduler(context, stateStore, permission)
    public val opens: NotificationOpenCoordinator = NotificationOpenCoordinator(stateStore)

    public fun normalize(intent: Intent?): NormalizedNotificationOpen? = intent?.let {
        NotificationIntentNormalizer.normalize(
            action = it.action,
            rawToken = it.getStringExtra(NotificationIntentNormalizer.EXTRA_TOKEN),
            rawDestination = it.getStringExtra(NotificationIntentNormalizer.EXTRA_DESTINATION),
            reason = it.getStringExtra(NotificationIntentNormalizer.EXTRA_REASON),
            planReceipt = it.getStringExtra(NotificationIntentNormalizer.EXTRA_PLAN_RECEIPT),
        )
    }

    public fun openSettings() = permission.openSystemSettings()
}

/** Reset invalidates pending alarms before the OS has a chance to deliver them. */
public object ReminderDeliveryPolicy {
    public fun shouldDeliver(stateStore: PlatformStateStore, rawToken: String): Boolean =
        runCatching { StableNotificationToken.hash(rawToken) in stateStore.read().scheduledReminderTokenHashes }
            .getOrDefault(false)
}

public class ReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != NotificationIntentNormalizer.ACTION_OPEN_REMINDER) return
        val rawToken = intent.getStringExtra(NotificationIntentNormalizer.EXTRA_TOKEN) ?: return
        val installId = runCatching { FileInstallIdentity(context.noBackupFilesDir.toPath()).getOrCreate() }.getOrNull() ?: return
        val stateStore = InstallScopedPlatformStateStore(context.noBackupFilesDir.toPath(), installId)
        if (!ReminderDeliveryPolicy.shouldDeliver(stateStore, rawToken)) return
        val channelId = NativeReminderScheduler.CHANNEL_ID
        if (Build.VERSION.SDK_INT >= 26) {
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(channelId, "복귀 안내", NotificationManager.IMPORTANCE_DEFAULT),
            )
        }
        val openIntent = Intent(context, Class.forName("com.solkim.baseball.android.MainActivity")).apply {
            action = NotificationIntentNormalizer.ACTION_OPEN_REMINDER
            putExtras(intent)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val pending = PendingIntent.getActivity(context, rawToken.hashCode(), openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.baseball_notification_small)
            .setContentTitle(intent.getStringExtra("baseball.notification.title") ?: "다음 장면을 기다리고 있어요")
            .setContentText(intent.getStringExtra("baseball.notification.body") ?: "저장된 복귀 계획을 확인해 보세요.")
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        if (NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            NotificationManagerCompat.from(context).notify(rawToken.hashCode(), notification)
        }
    }
}

public data class LifeCardSharePayload(
    public val title: String,
    public val text: String,
    public val lines: List<String>,
    /** Exact frozen archive identity captured by the chooser; legacy callers may omit it. */
    public val careerId: String = "",
    public val lifeNumber: Int = 0,
) {
    init {
        require(title.isNotBlank() && title.length <= 96) { "share.title" }
        require(text.isNotBlank() && text.length <= 16_000) { "share.text" }
        require(lines.isNotEmpty() && lines.size <= 256) { "share.lines" }
    }
}

public object LifeCardShareReceiptScope {
    public fun forPayload(payload: LifeCardSharePayload): String {
        require(payload.careerId.isNotBlank() && payload.lifeNumber > 0) { "share.identity" }
        return "archive:${payload.careerId}:share"
    }
}

public data class LifeCardRenderPlan(
    public val sourceWidth: Int,
    public val sourceHeight: Int,
    public val outputWidth: Int,
    public val outputHeight: Int,
    public val uniformScale: Float,
    public val tileHeight: Int,
)

/** Pure geometry boundary used by JVM tests so the Android renderer cannot regress to a giant
 * 1080x16000 ARGB allocation. */
public object NativeLifeCardRenderPolicy {
    public const val SOURCE_WIDTH: Int = 1080
    public const val LINE_HEIGHT: Int = 56
    public const val MAX_OUTPUT_HEIGHT: Int = 4096
    public const val MAX_OUTPUT_PIXELS: Long = 6_000_000L
    public const val TILE_HEIGHT: Int = 512

    public fun plan(lineCount: Int): LifeCardRenderPlan {
        require(lineCount > 0) { "share.lines" }
        val sourceHeight = LINE_HEIGHT * (lineCount + 3)
        val heightScale = MAX_OUTPUT_HEIGHT.toFloat() / sourceHeight.toFloat()
        val pixelScale = sqrt(MAX_OUTPUT_PIXELS.toDouble() / (SOURCE_WIDTH.toDouble() * sourceHeight.toDouble())).toFloat()
        val scale = minOf(1f, heightScale, pixelScale)
        return LifeCardRenderPlan(
            sourceWidth = SOURCE_WIDTH,
            sourceHeight = sourceHeight,
            outputWidth = (SOURCE_WIDTH * scale).toInt().coerceAtLeast(1),
            outputHeight = (sourceHeight * scale).toInt().coerceAtLeast(1),
            uniformScale = scale,
            tileHeight = TILE_HEIGHT,
        )
    }
}

public sealed interface ShareResult {
    public data object ChooserOpened : ShareResult
    public data object TextFallbackChooserOpened : ShareResult
    public data class Failed(public val reason: String) : ShareResult
}

public class NativeLifeCardShareService(
    private val context: Context,
    private val stateStore: PlatformStateStore? = null,
) {
    public fun share(payload: LifeCardSharePayload): ShareResult {
        val epoch = stateStore?.read()?.shareCacheEpoch ?: 0L
        val shareDirectory = File(context.cacheDir, "phase9-share-$epoch").apply { mkdirs() }
        val baseName = "lifecard-${Hashing.sha256Hex("${payload.careerId}|${payload.lifeNumber}|${payload.text}").take(16)}"
        val textIntent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TITLE, payload.title)
            putExtra(Intent.EXTRA_TEXT, payload.text)
        }
        return try {
            val image = render(payload)
            val imageFile = File(shareDirectory, "$baseName.png")
            imageFile.outputStream().use { stream -> check(image.compress(Bitmap.CompressFormat.PNG, 100, stream)) { "share.png_compress" } }
            image.recycle()
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.baseball.share", imageFile)
            val chooser = Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_TITLE, payload.title)
                putExtra(Intent.EXTRA_TEXT, payload.text)
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                clipData = android.content.ClipData.newRawUri(payload.title, uri)
            }, payload.title).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(chooser)
            ShareResult.ChooserOpened
        } catch (_: Throwable) {
            runCatching { context.startActivity(Intent.createChooser(textIntent, payload.title).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
                .fold(onSuccess = { ShareResult.TextFallbackChooserOpened }, onFailure = { ShareResult.Failed("share.chooser") })
        }
    }

    public fun clearCache() {
        context.cacheDir.listFiles().orEmpty()
            .filter { it.name.startsWith("phase9-share-") }
            .forEach { it.deleteRecursively() }
    }

    private fun render(payload: LifeCardSharePayload): Bitmap {
        val wrappedLines = payload.lines.flatMap { line ->
            if (line.isEmpty()) listOf("") else line.chunked(48)
        }
        val plan = NativeLifeCardRenderPolicy.plan(wrappedLines.size)
        val output = Bitmap.createBitmap(plan.outputWidth, plan.outputHeight, Bitmap.Config.ARGB_8888)
        val outputCanvas = Canvas(output)
        val sourcePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(37, 45, 50)
            textSize = 38f
            typeface = Typeface.create("sans-serif", Typeface.NORMAL)
        }
        var sourceTop = 0
        while (sourceTop < plan.sourceHeight) {
            val tileHeight = minOf(plan.tileHeight, plan.sourceHeight - sourceTop)
            val tile = Bitmap.createBitmap(plan.sourceWidth, tileHeight, Bitmap.Config.ARGB_8888)
            try {
                val tileCanvas = Canvas(tile)
                tileCanvas.drawColor(Color.rgb(248, 246, 240))
                tileCanvas.save()
                tileCanvas.translate(0f, -sourceTop.toFloat())
                tileCanvas.drawText(payload.title, 56f, 78f, sourcePaint)
                wrappedLines.forEachIndexed { index, line ->
                    tileCanvas.drawText(line, 56f, 150f + index * NativeLifeCardRenderPolicy.LINE_HEIGHT, sourcePaint)
                }
                tileCanvas.restore()
                outputCanvas.drawBitmap(
                    tile,
                    null,
                    RectF(
                        0f,
                        sourceTop * plan.uniformScale,
                        plan.outputWidth.toFloat(),
                        (sourceTop + tileHeight) * plan.uniformScale,
                    ),
                    Paint(Paint.FILTER_BITMAP_FLAG),
                )
            } finally {
                tile.recycle()
            }
            sourceTop += tileHeight
        }
        return output
    }
}

public sealed interface ReviewResult {
    public data object Ineligible : ReviewResult
    public data object Opened : ReviewResult
    public data class Failed(public val reason: String) : ReviewResult
}

public class NativePlayReviewService(
    context: Context,
    private val gate: ReviewGate,
) {
    private val manager = runCatching { ReviewManagerFactory.create(context) }.getOrNull()

    public fun eligibility(reason: ReviewReason): ReviewGateDecision = gate.canRequest(reason)

    public fun request(activity: Activity, reason: ReviewReason, callback: (ReviewResult) -> Unit) {
        val eligible = runCatching { gate.canRequest(reason) }.getOrElse { callback(ReviewResult.Failed("review.gate")); return }
        if (!eligible.eligible || manager == null) {
            callback(if (!eligible.eligible) ReviewResult.Ineligible else ReviewResult.Failed("review.unavailable"))
            return
        }
        // A reason is consumed only once the native manager is present and a real request is
        // being attempted. Missing Play services/credentials must not burn the product gate.
        val reserved = runCatching { gate.reserve(reason) }.getOrElse { callback(ReviewResult.Failed("review.gate")); return }
        if (!reserved.eligible) { callback(ReviewResult.Ineligible); return }
        try {
            manager.requestReviewFlow().addOnCompleteListener { request ->
                if (!request.isSuccessful || request.result == null) {
                    callback(ReviewResult.Failed("review.request"))
                    return@addOnCompleteListener
                }
                manager.launchReviewFlow(activity, request.result).addOnCompleteListener { launch ->
                    callback(if (launch.isSuccessful) ReviewResult.Opened else ReviewResult.Failed("review.launch"))
                }
            }
        } catch (_: Throwable) {
            callback(ReviewResult.Failed("review.exception"))
        }
    }
}

public data class NativePlaybackSettings(
    public val soundEnabled: Boolean,
    public val musicEnabled: Boolean,
    public val hapticsEnabled: Boolean,
    public val reducedMotionEnabled: Boolean,
)

/** The native copy of the plan-owned presentation map. Unity only supplies trajectory markers. */
public object NativeAudioResources {
    public val MENU_TAP: Int = R.raw.baseball_menu_tap
    public val PAD_CONFIRM: Int = R.raw.baseball_pad_confirm
    public val PITCH_RELEASE: Int = R.raw.baseball_pitch_release
    public val PITCH_PLATE: Int = R.raw.baseball_pitch_plate
    public val PITCH_IMPACT: Int = R.raw.baseball_pitch_impact
    public val MUSIC_CROWD: Int = R.raw.baseball_crowd_loop
}

public object HapticPolicy {
    public fun shouldVibrate(settings: NativePlaybackSettings, systemHapticsEnabled: Boolean): Boolean = settings.hapticsEnabled && !settings.reducedMotionEnabled && systemHapticsEnabled
}

/** iOS `Haptics.heartbeatBeat` — two transients 0.16s apart. Reduce-motion does not mute this pulse. */
public object HeartbeatHaptic {
    public const val PRIMARY_MS: Long = 18
    public const val SECONDARY_DELAY_MS: Long = 160
    public const val SECONDARY_MS: Long = 12

    public fun amplitude(intensity: Double, scale: Double = 1.0): Int {
        if (intensity <= 0.0) return 0
        return (intensity.coerceIn(0.0, 1.0) * scale * 255.0).toInt().coerceIn(1, 255)
    }
}

public class NativeAudioHapticsService(
    private val context: Context,
) {
    private val audioManager = context.getSystemService(AudioManager::class.java)
    private val soundPool = SoundPool.Builder().setMaxStreams(4).setAudioAttributes(
        AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build(),
    ).build()
    private var music: MediaPlayer? = null
    private var focusRequest: AudioFocusRequest? = null
    private var pausedForFocus = false
    private var pausedForLifecycle = false
    private val loadedSamples = linkedMapOf<Int, Int>()
    private val pendingSamples = linkedMapOf<Int, Pair<Float, Float>>()
    private val heartbeatHandler = Handler(Looper.getMainLooper())
    private var heartbeatTrack: AudioTrack? = null

    init {
        soundPool.setOnLoadCompleteListener { pool, sampleId, status ->
            pendingSamples.remove(sampleId)?.let { (volume, rate) ->
                if (status == 0) pool.play(sampleId, volume, volume, 1, 0, rate)
            }
        }
    }

    /** Presentation markers are the only pitch path allowed to produce sound/haptics. */
    public fun presentPitchMarker(marker: PresentationMarker, settings: NativePlaybackSettings, presentationSeed: String) {
        val seed = presentationSeed.toULongOrNull() ?: return
        val resource = when (marker) {
            PresentationMarker.RELEASE -> NativeAudioResources.PITCH_RELEASE
            PresentationMarker.PLATE -> NativeAudioResources.PITCH_PLATE
            PresentationMarker.IMPACT -> NativeAudioResources.PITCH_IMPACT
        }
        playEffect(resource, settings, seed)
        if (marker == PresentationMarker.IMPACT) presentNativeMarker("pitch-impact", settings, seed)
    }

    /** Native menu/pad effects are explicit UI presentation markers, never generic command taps. */
    public fun presentNativeMarker(marker: String, settings: NativePlaybackSettings, presentationSeed: ULong) {
        if (marker == "pitch-impact") {
            vibrate(settings)
            return
        }
        val resource = when (marker) {
            "menu-tap" -> NativeAudioResources.MENU_TAP
            "pad-confirm" -> NativeAudioResources.PAD_CONFIRM
            else -> return
        }
        playEffect(resource, settings, presentationSeed)
    }

    public fun playEffect(resourceId: Int?, settings: NativePlaybackSettings, presentationSeed: ULong, volume: Float = 1f) {
        if (!settings.soundEnabled || resourceId == null || resourceId == 0) return
        runCatching {
            val variation = ((presentationSeed % 3UL).toInt() + 1) / 3f
            val cached = loadedSamples[resourceId]
            if (cached != null) {
                soundPool.play(cached, volume, volume, 1, 0, variation)
            } else {
                val loaded = soundPool.load(context, resourceId, 1)
                loadedSamples[resourceId] = loaded
                pendingSamples[loaded] = volume to variation
            }
        }
    }

    public fun startMusic(resourceId: Int?, settings: NativePlaybackSettings) {
        if (!settings.musicEnabled || resourceId == null || resourceId == 0) {
            stopMusic()
            return
        }
        if (music != null) {
            resumeForLifecycle(settings)
            return
        }
        stopMusic()
        runCatching {
            music = MediaPlayer.create(context, resourceId)?.also { player ->
                player.isLooping = true
                requestFocus()
                player.start()
            }
        }
    }

    public fun playHeartbeat(pcm: ShortArray, sampleRate: Int, settings: NativePlaybackSettings) {
        if (!settings.soundEnabled || pcm.isEmpty() || sampleRate <= 0) return
        stopHeartbeatAudio()
        runCatching {
            val minBytes = AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
            )
            val frameCount = maxOf(pcm.size, if (minBytes > 0) minBytes / 2 else pcm.size)
            val buffer = if (frameCount == pcm.size) pcm else ShortArray(frameCount).also { pcm.copyInto(it) }
            val track = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_GAME)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build(),
                )
                .setBufferSizeInBytes(buffer.size * 2)
                .setTransferMode(AudioTrack.MODE_STATIC)
                .build()
            track.write(buffer, 0, buffer.size)
            track.setNotificationMarkerPosition(pcm.size)
            track.setPlaybackPositionUpdateListener(
                object : AudioTrack.OnPlaybackPositionUpdateListener {
                    override fun onMarkerReached(finished: AudioTrack) {
                        if (heartbeatTrack === finished) stopHeartbeatAudio()
                    }
                    override fun onPeriodicNotification(track: AudioTrack) = Unit
                },
                heartbeatHandler,
            )
            heartbeatTrack = track
            track.play()
        }
    }

    public fun heartbeatBeat(intensity: Double, settings: NativePlaybackSettings) {
        stopHeartbeatHaptics()
        if (!settings.hapticsEnabled || intensity <= 0.0) return
        val systemEnabled = systemHapticsEnabled()
        if (!systemEnabled) return
        vibrateAmplitude(HeartbeatHaptic.PRIMARY_MS, HeartbeatHaptic.amplitude(intensity))
        val secondary = HeartbeatHaptic.amplitude(intensity, 0.62)
        heartbeatHandler.postDelayed(
            { vibrateAmplitude(HeartbeatHaptic.SECONDARY_MS, secondary) },
            HeartbeatHaptic.SECONDARY_DELAY_MS,
        )
    }

    public fun stopHeartbeat() {
        stopHeartbeatAudio()
        stopHeartbeatHaptics()
    }

    public fun pauseForLifecycle() {
        stopHeartbeat()
        if (music?.isPlaying == true) {
            pausedForLifecycle = true
            music?.pause()
        }
        abandonFocus()
    }
    public fun resumeForLifecycle(settings: NativePlaybackSettings) {
        if (settings.musicEnabled && (pausedForFocus || pausedForLifecycle) && music != null) {
            pausedForFocus = false
            pausedForLifecycle = false
            runCatching { music?.start() }
        }
        requestFocusIfMusicPlaying()
    }
    public fun stopMusic() {
        runCatching { music?.stop() }
        music?.release()
        music = null
        pausedForFocus = false
        pausedForLifecycle = false
        abandonFocus()
    }
    public fun release() {
        stopHeartbeat()
        stopMusic()
        loadedSamples.clear()
        pendingSamples.clear()
        soundPool.release()
    }

    public fun vibrate(settings: NativePlaybackSettings, milliseconds: Long = 24L) {
        if (!HapticPolicy.shouldVibrate(settings, systemHapticsEnabled())) return
        vibrateAmplitude(milliseconds, VibrationEffect.DEFAULT_AMPLITUDE)
    }

    private fun stopHeartbeatAudio() {
        val track = heartbeatTrack
        heartbeatTrack = null
        if (track == null) return
        runCatching { track.setPlaybackPositionUpdateListener(null) }
        runCatching { if (track.playState == AudioTrack.PLAYSTATE_PLAYING) track.stop() }
        runCatching { track.release() }
    }

    private fun stopHeartbeatHaptics() {
        heartbeatHandler.removeCallbacksAndMessages(null)
    }

    private fun systemHapticsEnabled(): Boolean = try {
        Settings.System.getInt(context.contentResolver, Settings.System.HAPTIC_FEEDBACK_ENABLED, 1) == 1
    } catch (_: Throwable) {
        true
    }

    private fun vibrateAmplitude(milliseconds: Long, amplitude: Int) {
        if (amplitude == 0) return
        val vibrator = if (Build.VERSION.SDK_INT >= 31) {
            context.getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            context.getSystemService(Vibrator::class.java)
        }
        runCatching {
            if (Build.VERSION.SDK_INT >= 26) {
                val effectAmplitude = if (amplitude == VibrationEffect.DEFAULT_AMPLITUDE) {
                    VibrationEffect.DEFAULT_AMPLITUDE
                } else {
                    amplitude.coerceIn(1, 255)
                }
                vibrator.vibrate(VibrationEffect.createOneShot(milliseconds.coerceIn(1L, 100L), effectAmplitude))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(milliseconds.coerceIn(1L, 100L))
            }
        }
    }

    private fun requestFocusIfMusicPlaying() { if (music?.isPlaying == true) requestFocus() }
    private fun requestFocus() {
        pausedForFocus = false
        if (Build.VERSION.SDK_INT >= 26) {
            focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN).setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()).setOnAudioFocusChangeListener { change ->
                when (change) {
                    AudioManager.AUDIOFOCUS_LOSS, AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> { pausedForFocus = true; music?.pause() }
                    AudioManager.AUDIOFOCUS_GAIN -> if (pausedForFocus) { pausedForFocus = false; music?.start() }
                }
            }.build()
            audioManager.requestAudioFocus(requireNotNull(focusRequest))
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
        }
    }
    private fun abandonFocus() { focusRequest?.let(audioManager::abandonAudioFocusRequest); focusRequest = null }
}

public class NativePhase9Platform(
    context: Context,
    configuration: Phase9NativeSdkConfiguration = Phase9NativeSdkConfiguration(),
) {
    private val identityRoot = context.noBackupFilesDir.toPath()
    public val installIdentity: FileInstallIdentity = FileInstallIdentity(identityRoot)
    public val installId: String = installIdentity.getOrCreate()
    public val stateStore: PlatformStateStore = InstallScopedPlatformStateStore(identityRoot, installId)
    public val analytics: NativeAnalyticsService = NativeAnalyticsService(
        stateStore,
        listOf(FirebaseAnalyticsDestination(context, configuration), AmplitudeAnalyticsDestination(context, configuration, installId)),
        AnalyticsContext("${configuration.distribution}", "phase9", "platform", environment = configuration.environment),
    )
    public val crashReporter: NativeCrashReporter = FirebaseCrashReporter(context, configuration)
    public val notifications: NativeNotificationService = NativeNotificationService(context, stateStore)
    public val review: NativePlayReviewService = NativePlayReviewService(context, ReviewGate(stateStore))
    public val share: NativeLifeCardShareService = NativeLifeCardShareService(context, stateStore)
    public val audioHaptics: NativeAudioHapticsService = NativeAudioHapticsService(context)

    public fun clearAnalytics() = analytics.clear()
    public fun clearReview() { stateStore.clearReview() }
    public fun clearReminders() { notifications.scheduler.cancelAll(); stateStore.clearReminders() }
    public fun clearScopedEpoch() = stateStore.clearScopedEpoch()
    public fun clearShareCache() { share.clearCache(); stateStore.clearShareCache() }

    /** Read-only inspection; aggregate reminder_opened is committed before this token is marked. */
    public fun notificationRecovery(intent: Intent?): NotificationRecovery? = runCatching {
        notifications.normalize(intent)?.let(notifications.opens::onOpen)
    }.getOrNull()
    public fun inspectNotification(intent: Intent?): NotificationRecovery? = runCatching {
        notifications.normalize(intent)?.let(notifications.opens::inspect)
    }.getOrNull()
    public fun markNotificationAnalytics(tokenHash: String) = notifications.opens.markAnalyticsReceipt(tokenHash)
    public fun markNotificationNavigationCompleted(tokenHash: String) = notifications.opens.markNavigationCompleted(tokenHash)
}

private fun Bundle.putProperty(key: String, value: PlatformProperty, firebaseBooleanAsLong: Boolean) {
    when (value) {
        is PlatformProperty.Text -> putString(key, value.value)
        is PlatformProperty.Flag -> if (firebaseBooleanAsLong) putLong(key, if (value.value) 1L else 0L) else putBoolean(key, value.value)
        is PlatformProperty.Whole -> putLong(key, value.value)
        is PlatformProperty.Decimal -> putDouble(key, value.value)
    }
}

private fun PlatformProperty.toJsonValue(): Any = when (this) {
    is PlatformProperty.Text -> value
    is PlatformProperty.Flag -> value
    is PlatformProperty.Whole -> value
    is PlatformProperty.Decimal -> value
}
