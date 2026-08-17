package com.solkim.baseball.android

import android.app.Application
import com.solkim.baseball.application.CSharpLegacyGameStoreRepository
import com.solkim.baseball.application.FileShadowFixtureGameStoreRepository
import com.solkim.baseball.application.AnalyticsReceiptProjection
import com.solkim.baseball.application.AnalyticsReceiptSink
import com.solkim.baseball.application.ResetSideEffects
import com.solkim.baseball.application.KotlinGameStore
import com.solkim.baseball.application.NativeAuthorityMode
import com.solkim.baseball.platform.NativePhase9Platform
import com.solkim.baseball.platform.Phase9NativeSdkConfiguration
import com.solkim.baseball.platform.CrashContext
import com.solkim.baseball.model.Hashing
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking

/** Single process composition root for the Compose shadow vertical and native platform adapters. */
public class BaseballApplication : Application() {
    public lateinit var gameStore: KotlinGameStore
        private set
    public lateinit var platform: NativePhase9Platform
        private set
    private var crashUnityLoaded: Boolean = false
    private var crashStageReady: Boolean = false
    private var crashQualityTier: String = "high"

    override fun onCreate() {
        super.onCreate()
        val nativeAuthoritative = BuildConfig.PHASE10_PRODUCTION_BUILD &&
            BuildConfig.NATIVE_AUTHORITY_MODE == NativeAuthorityMode.NATIVE_AUTHORITATIVE.wire
        val distribution = if (nativeAuthoritative) BuildConfig.RELEASE_DISTRIBUTION else "development"
        val environment = when {
            !nativeAuthoritative -> "compose-dev"
            BuildConfig.RELEASE_DISTRIBUTION == "production" -> "production"
            else -> "phase10-rehearsal"
        }
        platform = NativePhase9Platform(
            this,
            Phase9NativeSdkConfiguration(
                externalSdkEnabled = BuildConfig.PHASE9_EXTERNAL_SDKS_ENABLED,
                amplitudeApiKey = BuildConfig.PHASE9_AMPLITUDE_API_KEY.takeIf(String::isNotBlank),
                analyticsConsent = BuildConfig.PHASE9_EXTERNAL_SDKS_ENABLED,
                diagnosticsConsent = BuildConfig.PHASE9_EXTERNAL_SDKS_ENABLED,
                distribution = distribution,
                environment = environment,
            ),
        )
        val analyticsProjection = AnalyticsReceiptProjection(
            sink = AnalyticsReceiptSink { receipts ->
            // screen_view and other non-matrix command receipts remain local game receipts. The
            // native destinations receive only the frozen, privacy-validated product matrix.
            platform.analytics.publish(receipts.mapNotNull { receipt ->
                if (receipt.eventName !in com.solkim.baseball.platform.Phase9AnalyticsSchema.eventNames ||
                    receipt.eventName in com.solkim.baseball.platform.Phase9AnalyticsSchema.retiredEventNames ||
                    receipt.eventName in com.solkim.baseball.platform.Phase9AnalyticsSchema.intentionalZeroCallerEventNames) return@mapNotNull null
                com.solkim.baseball.platform.Phase9AnalyticsSchema.fromStrings(
                    receiptId = receipt.receiptId,
                    eventName = receipt.eventName,
                    properties = receipt.properties,
                )
            })
            },
            durableReceiptIds = { platform.analytics.durableReceiptIds() },
            establishDurableBaseline = { receiptIds -> platform.analytics.establishAggregateBaseline(receiptIds) },
        )
        val installId = platform.installId
        val repository = if (nativeAuthoritative) {
            CSharpLegacyGameStoreRepository(
                directory = requireNotNull(getExternalFilesDir(null)).toPath().resolve("save"),
                installId = installId,
            )
        } else {
            val shadowDirectory = filesDir.toPath().resolve(
                "compose-dev-shadow-${Hashing.sha256Hex("$installId|aggregate-shadow").take(32)}",
            )
            FileShadowFixtureGameStoreRepository(shadowDirectory)
        }
        gameStore = runBlocking(Dispatchers.IO) {
            KotlinGameStore.open(
                installId,
                repository,
                if (nativeAuthoritative) NativeAuthorityMode.NATIVE_AUTHORITATIVE else NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY,
                analyticsProjection,
            )
        }
        platform.analytics.retryOutbox()
        updateCrashContext(unityLoaded = false, stageReady = false)
    }

    /** Dynamic allowlisted crash context; callers never pass raw save, intent, or player input. */
    public fun updateCrashContext(
        unityLoaded: Boolean = crashUnityLoaded,
        stageReady: Boolean = crashStageReady,
        qualityTier: String = crashQualityTier,
    ) {
        crashUnityLoaded = unityLoaded
        crashStageReady = stageReady
        crashQualityTier = qualityTier
        val state = gameStore.current
        platform.crashReporter.setContext(
            CrashContext(
                distribution = if (BuildConfig.PHASE10_PRODUCTION_BUILD) BuildConfig.RELEASE_DISTRIBUTION else "development",
                appSchema = "phase9",
                phase = state.stage.wire,
                life = state.highSchool?.run?.lifeNumber ?: 0,
                qualityTier = qualityTier,
                unityLoaded = unityLoaded,
                stageReady = stageReady,
            ),
        )
    }

    public fun recordUnityFailure(category: String) {
        val safe = category.takeIf {
            it in setOf("attach_failed", "runtime_unavailable", "bridge_send_failed", "protocol_rejected", "terminal_failure", "unload_failed")
        } ?: return
        platform.crashReporter.log("unity_failure:$safe")
        platform.crashReporter.recordException(IllegalStateException("unity_failure:$safe"))
    }

    public fun phase9ResetSideEffects(): ResetSideEffects = object : ResetSideEffects {
        override fun clearAnalytics() = platform.clearAnalytics()
        override fun clearReview() = platform.clearReview()
        override fun clearReminders() = platform.clearReminders()
        override fun clearScopedEpoch() = platform.clearScopedEpoch()
        override fun clearShareCache() = platform.clearShareCache()
    }

}
