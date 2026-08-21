package com.solkim.baseball.android

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.util.Log
import android.view.KeyEvent
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color as ComposeColor
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.zIndex
import androidx.compose.ui.platform.ComposeView
import com.solkim.baseball.application.GameAggregateState
import com.solkim.baseball.application.KotlinGameStore
import com.solkim.baseball.application.Phase7VerticalController
import com.solkim.baseball.application.PitchBoundary
import com.solkim.baseball.application.PitchCareerKind
import com.solkim.baseball.application.PitchPresentationFactory
import com.solkim.baseball.bridge.PitchIpcCodec
import com.solkim.baseball.bridge.PitchReentryPolicy
import com.solkim.baseball.bridge.PitchSessionGate
import com.solkim.baseball.bridge.ProtocolDecisionKind
import com.solkim.baseball.bridge.UnityRuntimeHost
import com.solkim.baseball.bridge.UnityRuntimeHostRegistry
import com.solkim.baseball.bridge.UnityRuntimeUnavailableException
import com.solkim.baseball.core.pitch.BaserunnerStateSnapshot
import com.solkim.baseball.core.pitch.MoundComposureInput
import com.solkim.baseball.core.pitch.MoundTensionInput
import com.solkim.baseball.core.pitch.MoundTensionModel
import com.solkim.baseball.core.pitch.PitchDelivery
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchOutcome
import com.solkim.baseball.core.pitch.PitchZone
import com.solkim.baseball.design.BaseballMigrationTheme
import com.solkim.baseball.model.PitchAcknowledgementKind
import com.solkim.baseball.model.PitchCommandKind
import com.solkim.baseball.model.PitchIpcAcknowledgement
import com.solkim.baseball.model.PitchIpcCommand
import com.solkim.baseball.model.PitchIpcContract
import com.solkim.baseball.model.PitchPresentationRequest
import com.solkim.baseball.model.QualityTier
import com.solkim.baseball.platform.NativeAudioResources
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.atomic.AtomicLong

/** Full-screen Unity as a Library host. Unity is a trajectory renderer; the store stays native. */
public class PitchUnityActivity : ComponentActivity(), UnityBridgeCallbacks.Listener {
    // KotlinPitchPresentationSession remains the tutorial authority; this activity only hosts the
    // saved renderer request and never moves PitchKernel decisions into Unity.
    private lateinit var store: KotlinGameStore
    private lateinit var controller: Phase7VerticalController
    private lateinit var unityHost: UnityRuntimeHost
    private lateinit var unityRoot: FrameLayout
    private lateinit var sessionId: String
    private lateinit var expectedRevision: String
    private var gate = PitchSessionGate()
    private var bridgeInitialized = false
    private var status by mutableStateOf("저장된 투구 세션 확인 중…")
    private var selectedPitchIndex by mutableStateOf(0)
    private var selectedZone by mutableStateOf(PitchZone(1, 1))
    private var unityAvailable by mutableStateOf(false)
    private var unityReady by mutableStateOf(false)
    private var request by mutableStateOf<PitchPresentationRequest?>(null)
    private var resultReady by mutableStateOf(false)
    private var returningToShell = false
    private var unloadRequested = false
    private var presentationReplaySequence = 0L
    private val activityScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        store = (application as BaseballApplication).gameStore
        (application as BaseballApplication).updateCrashContext(unityLoaded = false, stageReady = false)
        controller = Phase7VerticalController(store)
        sessionId = intent.getStringExtra(EXTRA_SESSION_ID) ?: error("pitch.session_id_missing")
        expectedRevision = intent.getStringExtra(EXTRA_EXPECTED_REVISION) ?: error("pitch.revision_missing")
        if (!lookupSavedSession(expectedRevision)) {
            finish()
            return
        }

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = handleBack()
        })
        unityRoot = FrameLayout(this).apply { setBackgroundColor(Color.rgb(12, 19, 27)) }
        setContentView(unityRoot)
        UnityBridgeCallbacks.bind(this)
        unityHost = UnityRuntimeHostRegistry.get()
        attachUnity()

        val overlay = ComposeView(this)
        unityRoot.addView(
            overlay,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
        )
        overlay.setContent {
            BaseballMigrationTheme {
                val settings = store.current.settings
                PitchSessionOverlay(
                    status = status,
                    selectedPitchIndex = selectedPitchIndex,
                    selectedZone = selectedZone,
                    unityReady = unityReady,
                    resultReady = resultReady,
                    autoRelease = settings.autoReleaseEnabled,
                    velocityTenthsKph = selectedPitchVelocity(),
                    fatigue = store.current.pro?.fatigue ?: store.current.highSchool?.run?.fatigue ?: 0,
                    reduceMotion = settings.reducedMotionEnabled,
                    hapticsEnabled = settings.hapticsEnabled,
                    tension = moundTension(),
                    disturbanceSeed = moundSeed(),
                    onSelectPitch = { selectedPitchIndex = it },
                    onSelectZone = { selectedZone = it },
                    onDeliver = ::submitSelectedPitch,
                    onReplay = ::replayExact,
                    onPostgame = ::completeAndReturn,
                    onBack = ::handleBack,
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val nextSession = intent.getStringExtra(EXTRA_SESSION_ID) ?: return
        val nextRevision = intent.getStringExtra(EXTRA_EXPECTED_REVISION) ?: return
        val reentry = PitchReentryPolicy.decide(
            currentSessionId = sessionId,
            nextSessionId = nextSession,
            returningToShell = returningToShell,
            unloadRequested = unloadRequested,
        )
        if (!reentry.accepted) {
            Log.w(TAG, "rejecting mismatched same-process pitch re-entry")
            return
        }
        // pauseAndDetach uses unloadRequested as the terminal-return handshake. Consume it
        // for same-session re-entry too; otherwise the second pitch in one important-game
        // session reaches closeToCompose with a stale true flag and cannot return to Compose.
        if (reentry.resetTerminalReturn) unloadRequested = false
        if (nextSession != sessionId) {
            sessionId = nextSession
            gate = PitchSessionGate()
            bridgeInitialized = false
            unityReady = false
            unityAvailable = false
            request = null
            resultReady = false
            selectedPitchIndex = 0
            selectedZone = PitchZone(1, 1)
        }
        expectedRevision = nextRevision
        returningToShell = false
        resultReady = false
        request = null
        if (!lookupSavedSession(expectedRevision)) return
        if (::unityHost.isInitialized) {
            runCatching {
                unityHost.attach(this, unityRoot)
                unityAvailable = true
                (application as BaseballApplication).updateCrashContext(unityLoaded = true, stageReady = unityReady)
            }.onFailure {
                (application as BaseballApplication).recordUnityFailure("attach_failed")
                status = "Unity runtime 재진입 실패"
            }
            if (!bridgeInitialized) {
                unityRoot.postDelayed({ if (!isFinishing && !isDestroyed) sendInitialize() }, 250L)
            } else {
                unityHost.onResume()
                status = "저장된 pitch session 재진입 · revision ${store.state.value.revision}"
                loadSavedPresentationOrInput()
            }
        }
    }

    override fun onStart() {
        super.onStart()
        if (::unityHost.isInitialized) unityHost.onStart()
    }

    override fun onResume() {
        super.onResume()
        if (::unityHost.isInitialized) unityHost.onResume()
        if (::unityHost.isInitialized) {
            (application as BaseballApplication).updateCrashContext(unityLoaded = unityAvailable, stageReady = unityReady)
            platform().audioHaptics.resumeForLifecycle(playbackSettings())
        }
    }

    override fun onPause() {
        if (::unityHost.isInitialized) unityHost.onPause()
        platform().audioHaptics.pauseForLifecycle()
        if (::unityHost.isInitialized) (application as BaseballApplication).updateCrashContext(unityLoaded = unityAvailable, stageReady = false)
        super.onPause()
    }

    override fun onStop() {
        if (::unityHost.isInitialized) unityHost.onStop()
        if (::unityHost.isInitialized) (application as BaseballApplication).updateCrashContext(unityLoaded = unityAvailable, stageReady = false)
        super.onStop()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (::unityHost.isInitialized) unityHost.onWindowFocusChanged(hasFocus)
    }

    @SuppressLint("GestureBackNavigation")
    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            handleBack()
            return true
        }
        return super.onKeyUp(keyCode, event)
    }

    override fun onLowMemory() {
        if (::unityHost.isInitialized) unityHost.onLowMemory()
        super.onLowMemory()
    }

    override fun onDestroy() {
        if (::unityHost.isInitialized && !returningToShell && !unloadRequested) {
            unloadRequested = true
            unityHost.close()
        }
        if (::unityHost.isInitialized) (application as BaseballApplication).updateCrashContext(unityLoaded = false, stageReady = false)
        UnityBridgeCallbacks.unbind(this)
        activityScope.cancel()
        super.onDestroy()
    }

    override fun onBridgeAcknowledgement(json: String) {
        runOnUiThread {
            val acknowledgement = runCatching { PitchIpcCodec.decodeAcknowledgement(json) }
                .getOrElse {
                    status = "Unity callback 거부 · invalid wire"
                    (application as BaseballApplication).recordUnityFailure("protocol_rejected")
                    return@runOnUiThread
                }
            val decision = gate.acceptAcknowledgement(acknowledgement)
            when (decision.kind) {
                ProtocolDecisionKind.REJECTED -> {
                    status = "Unity callback 거부 · ${decision.code}"
                    (application as BaseballApplication).recordUnityFailure("protocol_rejected")
                    return@runOnUiThread
                }
                ProtocolDecisionKind.DUPLICATE -> {
                    status = "중복 callback 무시 · ${decision.code}"
                    return@runOnUiThread
                }
                ProtocolDecisionKind.ACCEPTED -> Unit
            }
            when (acknowledgement.acknowledgement) {
                PitchAcknowledgementKind.UNITY_READY -> {
                    unityReady = true
                    (application as BaseballApplication).updateCrashContext(unityLoaded = true, stageReady = true)
                    status = "Unity trajectory renderer 준비 · Kotlin revision ${store.state.value.revision}"
                    sendQuality()
                    loadSavedPresentationOrInput()
                }
                PitchAcknowledgementKind.PRESENTATION_STARTED -> status = "공 비행 중 · Compose HUD는 native overlay"
                PitchAcknowledgementKind.PRESENTATION_MARKER -> {
                    acknowledgement.marker?.let { marker ->
                        platform().audioHaptics.presentPitchMarker(marker, playbackSettings(), acknowledgement.presentationSeed)
                    }
                    status = "궤적 marker · ${acknowledgement.marker?.wire}"
                }
                PitchAcknowledgementKind.PRESENTATION_COMPLETED,
                PitchAcknowledgementKind.PRESENTATION_FAILED -> {
                    if (acknowledgement.acknowledgement == PitchAcknowledgementKind.PRESENTATION_FAILED) {
                        (application as BaseballApplication).recordUnityFailure("terminal_failure")
                    }
                    consumeAfterVerifiedTerminal(acknowledgement)
                }
                PitchAcknowledgementKind.PRESENTATION_PAUSED -> status = "투구 연출 일시정지 · 결과 권위는 유지됨"
                PitchAcknowledgementKind.PRESENTATION_RESUMED -> status = "투구 연출 재개"
                PitchAcknowledgementKind.PRESENTATION_CANCELLED -> status = "연출 취소 · 저장된 결과를 다시 재생할 수 있음"
                PitchAcknowledgementKind.UNITY_UNLOADED -> {
                    (application as BaseballApplication).updateCrashContext(unityLoaded = false, stageReady = false)
                    status = "Unity runtime unload 확인"
                }
            }
        }
    }

    private fun attachUnity() {
        try {
            unityHost.attach(this, unityRoot)
            unityAvailable = true
            (application as BaseballApplication).updateCrashContext(unityLoaded = true, stageReady = false)
            platform().audioHaptics.startMusic(NativeAudioResources.MUSIC_CROWD, playbackSettings())
            unityRoot.postDelayed({ if (!isFinishing && !isDestroyed) sendInitialize() }, 350L)
        } catch (error: UnityRuntimeUnavailableException) {
            Log.e(TAG, "Unity runtime attach failed", error)
            (application as BaseballApplication).recordUnityFailure("runtime_unavailable")
            status = "Unity runtime을 찾을 수 없습니다 · renderer gate 실패"
        } catch (error: Throwable) {
            Log.e(TAG, "Unity runtime attach failed", error)
            (application as BaseballApplication).recordUnityFailure("attach_failed")
            status = "Unity runtime attach 실패"
        }
    }

    private fun lookupSavedSession(expected: String): Boolean {
        val revision = expected.toULongOrNull() ?: run {
            status = "revision wire 거부"
            return false
        }
        val pitch = store.state.value.pitch
        val valid = pitch != null && pitch.sessionId == sessionId && store.state.value.revision == revision
        if (!valid) {
            status = "stale 또는 mismatched saved pitch callback/session 거부"
            Log.w(TAG, "pitch lookup rejected session=$sessionId expected=$revision actual=${store.state.value.revision}")
        }
        return valid
    }

    private fun sendInitialize() {
        if (bridgeInitialized || !unityAvailable) return
        val command = PitchIpcCommand(
            PitchIpcContract.SCHEMA,
            PitchIpcContract.SCHEMA_VERSION,
            "$sessionId:initialize:${bridgeInitializationSequence.incrementAndGet()}",
            sessionId,
            "phase7-presentation-session",
            PitchCommandKind.INITIALIZE_BRIDGE,
        )
        bridgeInitialized = true
        dispatchGatedBridge(command)
    }

    private fun sendQuality() {
        dispatchGatedBridge(
            PitchIpcCommand(
                PitchIpcContract.SCHEMA,
                PitchIpcContract.SCHEMA_VERSION,
                "$sessionId:quality:high",
                sessionId,
                "phase7-presentation-session",
                PitchCommandKind.SET_QUALITY_TIER,
                qualityTier = request?.visual?.qualityTier ?: QualityTier.HIGH,
            ),
        )
    }

    private fun loadSavedPresentationOrInput() {
        activityScope.launch {
            try {
                val state = store.state.value
                val pitch = requireNotNull(state.pitch) { "phase7.pitch_missing" }
                when (pitch.boundary) {
                    PitchBoundary.COMMITTED,
                    PitchBoundary.CONSUMED,
                    PitchBoundary.TERMINAL,
                    PitchBoundary.COMPLETED -> {
                        val saved = controller.preparePresentation(sessionId, selectedPitchIndex)
                        withContext(Dispatchers.Main) {
                            request = saved
                            updateCrashPresentationContext(saved)
                            if (pitch.boundary == PitchBoundary.COMMITTED && unityReady) play(saved)
                            else {
                                resultReady = pitch.boundary != PitchBoundary.COMMITTED
                                status = if (resultReady) "저장된 결과 · consume 이후 재생 가능" else "저장된 presentation 재생 준비"
                            }
                        }
                    }
                    PitchBoundary.PLAYING -> {
                        // A process death can happen after Kotlin submitted the result but before
                        // the commit receipt. The saved HighSchool snapshot is re-committed first.
                        val saved = state.highSchool?.lastPresentation
                        val savedPro = state.pro?.lastPresentation
                        if ((pitch.careerKind.name == "HIGH_SCHOOL" && saved != null) ||
                            (pitch.careerKind.name == "PRO" && savedPro != null)) {
                            val rebuilt = controller.commitSavedPresentation(sessionId, selectedPitchIndex)
                            withContext(Dispatchers.Main) {
                                request = rebuilt
                                updateCrashPresentationContext(rebuilt)
                                if (unityReady) play(rebuilt) else status = "저장된 HighSchool 결과를 다시 재생할 준비 중입니다"
                            }
                        } else {
                            withContext(Dispatchers.Main) { status = "Compose에서 구종과 코스를 선택하세요" }
                        }
                    }
                    PitchBoundary.RESERVED,
                    PitchBoundary.SUSPENDED -> withContext(Dispatchers.Main) {
                        status = "Compose에서 구종과 코스를 선택하세요"
                    }
                    PitchBoundary.ABANDONED -> withContext(Dispatchers.Main) {
                        resultReady = true
                        status = "이 투구는 명시적으로 abandon 되었습니다"
                    }
                }
            } catch (error: Throwable) {
                withContext(Dispatchers.Main) { status = "저장된 pitch 복구 실패 · ${error.message ?: "invalid"}" }
            }
        }
    }

    private fun submitSelectedPitch(delivery: PitchDelivery) {
        if (!unityReady) {
            status = "Unity 준비 전에는 투구를 시작할 수 없습니다"
            return
        }
        status = "Kotlin PitchKernel 결과 저장 중…"
        activityScope.launch {
            try {
                val saved = controller.submitPitch(
                    sessionId = sessionId,
                    pitchIndex = selectedPitchIndex,
                    pitchType = pitchTypeForIndex(selectedPitchIndex),
                    zone = selectedZone,
                    delivery = delivery,
                )
                withContext(Dispatchers.Main) {
                    request = saved
                    updateCrashPresentationContext(saved)
                    play(saved)
                }
            } catch (error: Throwable) {
                withContext(Dispatchers.Main) { status = "Kotlin 판정/commit 실패 · ${error.message ?: "invalid"}" }
            }
        }
    }

    private fun play(saved: PitchPresentationRequest) {
        updateCrashPresentationContext(saved)
        val command = PitchIpcCommand(
            PitchIpcContract.SCHEMA,
            PitchIpcContract.SCHEMA_VERSION,
            "$sessionId:play:${saved.pitchId}:${saved.requestSha256.take(8)}:${++presentationReplaySequence}",
            sessionId,
            saved.presentationSeed,
            PitchCommandKind.PLAY_PRESENTATION,
            request = saved,
        )
        val decision = gate.acceptCommand(command)
        when (decision.kind) {
            ProtocolDecisionKind.ACCEPTED -> dispatchBridge(command)
            ProtocolDecisionKind.DUPLICATE -> status = "같은 pitch snapshot replay가 이미 진행 중입니다"
            ProtocolDecisionKind.REJECTED -> {
                (application as BaseballApplication).recordUnityFailure("protocol_rejected")
                status = "renderer command 거부 · ${decision.code}"
            }
        }
    }

    private fun replayExact() {
        val saved = request ?: return
        resultReady = false
        status = "동일 pitchId·hash exact replay 요청"
        play(saved)
    }

    private fun updateCrashPresentationContext(saved: PitchPresentationRequest) {
        (application as BaseballApplication).updateCrashContext(
            unityLoaded = unityAvailable,
            stageReady = unityReady,
            qualityTier = saved.visual.qualityTier.wire,
        )
    }

    private fun consumeAfterVerifiedTerminal(acknowledgement: PitchIpcAcknowledgement) {
        val saved = request ?: return
        activityScope.launch {
            try {
                controller.consumePresentation(sessionId, saved)
                withContext(Dispatchers.Main) {
                    resultReady = true
                    status = if (acknowledgement.acknowledgement == PitchAcknowledgementKind.PRESENTATION_FAILED) {
                        "Unity 연출 실패 · 결과는 consume save 뒤 표시"
                    } else {
                        "투구 결과 저장 완료 · Postgame으로 이동 가능"
                    }
                }
            } catch (error: Throwable) {
                withContext(Dispatchers.Main) { status = "consume save 실패 · ${error.message ?: "invalid"}" }
            }
        }
    }

    private fun completeAndReturn() {
        val saved = request ?: return
        activityScope.launch {
            try {
                controller.completePitchAndPostgame(sessionId)
                closeToCompose()
            } catch (error: Throwable) {
                withContext(Dispatchers.Main) { status = "Postgame 저장 실패 · ${error.message ?: "invalid"}" }
            }
        }
    }

    private fun handleBack() {
        val pitch = store.state.value.pitch ?: run { closeToCompose(); return }
        if (pitch.boundary in setOf(PitchBoundary.RESERVED, PitchBoundary.PLAYING, PitchBoundary.COMMITTED, PitchBoundary.CONSUMED)) {
            activityScope.launch {
                runCatching { controller.suspendPitch(sessionId) }
                    .onFailure { Log.w(TAG, "pitch suspend failed", it) }
                withContext(Dispatchers.Main) {
                    returningToShell = true
                    startActivity(Intent(this@PitchUnityActivity, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT))
                }
            }
        } else {
            closeToCompose()
        }
    }

    private fun closeToCompose() {
        if (unloadRequested) return
        unloadRequested = true
        returningToShell = true
        unityAvailable = false
        if (::unityHost.isInitialized) {
            unityHost.pauseAndDetach {
                runOnUiThread {
                    if (!isDestroyed) {
                        startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT))
                    }
                }
            }
        } else {
            startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT))
            finish()
        }
    }

    private fun dispatchBridge(command: PitchIpcCommand) {
        if (!unityAvailable) return
        runCatching { unityHost.sendCommand(PitchIpcCodec.encodeCommand(command)) }
            .onFailure {
                Log.e(TAG, "Unity bridge send failed", it)
                (application as BaseballApplication).recordUnityFailure("bridge_send_failed")
                status = "Unity bridge 전송 실패"
            }
    }

    private fun dispatchGatedBridge(command: PitchIpcCommand) {
        val decision = gate.acceptCommand(command)
        when (decision.kind) {
            ProtocolDecisionKind.ACCEPTED,
            ProtocolDecisionKind.DUPLICATE -> dispatchBridge(command)
            ProtocolDecisionKind.REJECTED -> status = "renderer command 거부 · ${decision.code}"
        }
    }

    public companion object {
        private const val TAG = "PitchUnityActivity"
        private const val EXTRA_SESSION_ID = "com.solkim.baseball.android.extra.SESSION_ID"
        private const val EXTRA_EXPECTED_REVISION = "com.solkim.baseball.android.extra.EXPECTED_REVISION"
        private val bridgeInitializationSequence = AtomicLong(0L)

        public fun intent(context: Context, sessionId: String, expectedRevision: String): Intent =
            Intent(context, PitchUnityActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                putExtra(EXTRA_SESSION_ID, sessionId)
                putExtra(EXTRA_EXPECTED_REVISION, expectedRevision)
            }

        private fun pitchTypeForIndex(index: Int): PitchKind = when (index.coerceIn(0, 3)) {
            0 -> PitchKind.FOUR_SEAM
            1 -> PitchKind.SLIDER
            2 -> PitchKind.CURVEBALL
            else -> PitchKind.CHANGEUP
        }
    }

    private fun moundTension(): Double {
        val state = store.current
        val pitch = state.pitch
        val official = pitch != null && pitch.careerKind != PitchCareerKind.TUTORIAL && !pitch.challengeRun
        val hs = state.highSchool
        val pro = state.pro
        val hsSession = hs?.activePitch
        val proSession = pro?.activePitch
        val runners = when {
            proSession != null -> proSession.game.runners
            hsSession != null -> BaserunnerStateSnapshot(
                hsSession.game.firstOccupied,
                hsSession.game.secondOccupied,
                hsSession.game.thirdOccupied,
                52,
            )
            else -> BaserunnerStateSnapshot.EMPTY
        }
        val leverage = proSession?.context?.leverage ?: hsSession?.context?.leverage ?: 500
        val balls = proSession?.context?.balls ?: hsSession?.context?.balls ?: 0
        val strikes = proSession?.context?.strikes ?: hsSession?.context?.strikes ?: 0
        val outs = proSession?.context?.outs ?: hsSession?.context?.outs ?: 0
        val fatigue = pro?.fatigue ?: hs?.run?.fatigue ?: 0
        val batter = proSession?.batter
        val threat = if (batter != null) MoundTensionModel.batterThreat(batter.contact, batter.discipline, batter.power) else 50
        val adverse = when {
            proSession != null -> proSession.log.entries.lastOrNull()?.outcome in adverseOutcomes
            hsSession != null -> hsSession.log.entries.lastOrNull()?.outcome in adverseOutcomes
            else -> false
        }
        val composure = MoundComposureInput(
            command = pro?.pitcher?.command ?: hs?.run?.pitcher?.command ?: 0,
            stamina = pro?.pitcher?.stamina ?: hs?.run?.pitcher?.stamina ?: 0,
            awakeningWires = hs?.run?.selectedAwakenings.orEmpty().map { it.wire },
            memoryWires = hs?.run?.let { emptyList() } ?: emptyList(),
        )
        return MoundTensionModel.tension(
            MoundTensionInput(official, leverage, runners, balls, strikes, outs, fatigue, threat, adverse, composure),
        )
    }

    private fun moundSeed(): ULong {
        val pitch = store.current.pitch
        return MoundTensionModel.seed(pitch?.gameId ?: pitch?.sessionId ?: "mound")
    }

    private val adverseOutcomes = setOf(
        PitchOutcome.SINGLE,
        PitchOutcome.DOUBLE,
        PitchOutcome.TRIPLE,
        PitchOutcome.HOME_RUN,
        PitchOutcome.HIT_BY_PITCH,
    )

    private fun selectedPitchVelocity(): Int {
        val kind = pitchTypeForIndex(selectedPitchIndex)
        val profiles = store.current.pro?.pitcher?.pitchProfiles
            ?: emptyList()
        return profiles.firstOrNull { it.pitchType == kind }?.velocityTenthsKph ?: 1_350
    }

    private fun platform(): com.solkim.baseball.platform.NativePhase9Platform = (application as BaseballApplication).platform

    private fun playbackSettings(): com.solkim.baseball.platform.NativePlaybackSettings {
        val settings = store.current.settings
        return com.solkim.baseball.platform.NativePlaybackSettings(settings.soundEnabled, settings.musicEnabled, settings.hapticsEnabled, settings.reducedMotionEnabled)
    }
}

@Composable
private fun PitchSessionOverlay(
    status: String,
    selectedPitchIndex: Int,
    selectedZone: PitchZone,
    unityReady: Boolean,
    resultReady: Boolean,
    autoRelease: Boolean,
    velocityTenthsKph: Int,
    fatigue: Int,
    reduceMotion: Boolean,
    hapticsEnabled: Boolean,
    tension: Double,
    disturbanceSeed: ULong,
    onSelectPitch: (Int) -> Unit,
    onSelectZone: (PitchZone) -> Unit,
    onDeliver: (PitchDelivery) -> Unit,
    onReplay: () -> Unit,
    onPostgame: () -> Unit,
    onBack: () -> Unit,
) {
    Box(modifier = Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().zIndex(1f)) {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = ComposeColor.Transparent,
        ) {
            Column(
                modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
                verticalArrangement = Arrangement.SpaceBetween,
            ) {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text("직접 투구", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                        Text(status, style = MaterialTheme.typography.bodyMedium)
                        Text(
                            if (unityReady) "공 궤적 준비 완료" else "공 궤적 연결 대기",
                            style = MaterialTheme.typography.labelMedium,
                            modifier = Modifier.semantics { stateDescription = if (unityReady) "Unity 준비 완료" else "Unity 연결 대기" },
                        )
                    }
                }
                Spacer(Modifier.height(180.dp))
                Surface(color = ComposeColor(0xE6050A15), shape = MaterialTheme.shapes.large) {
                    Column(
                        Modifier.fillMaxWidth().padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        if (resultReady) {
                            Text("결과는 저장 뒤에 열립니다.", style = MaterialTheme.typography.titleMedium)
                            Button(onClick = onReplay, modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).semantics { contentDescription = "동일 투구 exact replay" }) { Text("같은 투구 다시 재생") }
                            Button(onClick = onPostgame, modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).semantics { contentDescription = "Postgame 결과 화면으로 이동" }) { Text("결과 화면으로") }
                        } else {
                            val kinds = listOf("직구", "슬라이더", "커브", "체인지업")
                            Text("${kinds[selectedPitchIndex.coerceIn(0, 3)]} · ${velocityTenthsKph / 10}km/h", color = ComposeColor.White, style = MaterialTheme.typography.labelLarge)
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                kinds.forEachIndexed { index, label ->
                                    val selected = selectedPitchIndex == index
                                    OutlinedButton(
                                        onClick = { onSelectPitch(index) },
                                        modifier = Modifier.weight(1f).heightIn(min = 48.dp).semantics {
                                            role = Role.Button
                                            contentDescription = "$label ${if (selected) "선택됨" else "선택 가능"}"
                                            stateDescription = if (selected) "선택됨" else "선택되지 않음"
                                        },
                                    ) { Text(if (selected) "✓ $label" else label, color = ComposeColor.White, style = MaterialTheme.typography.labelMedium) }
                                }
                            }
                            ZonePicker(selectedZone, onSelectZone)
                            PitchDeliveryControl(
                                autoRelease = autoRelease,
                                enabled = unityReady,
                                onDeliver = onDeliver,
                                velocityTenthsKph = velocityTenthsKph,
                                fatigue = fatigue,
                                reduceMotion = reduceMotion,
                                hapticsEnabled = hapticsEnabled,
                                tension = tension,
                                disturbanceSeed = disturbanceSeed,
                            )
                        }
                        OutlinedButton(onClick = onBack, modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).semantics { contentDescription = "투구를 일시정지하고 Compose로 돌아가기" }) {
                            Text("뒤로가기 · 저장 후 일시정지", color = ComposeColor.White)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ZonePicker(selected: PitchZone, onSelect: (PitchZone) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        repeat(3) { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                repeat(3) { column ->
                    val zone = PitchZone(row, column)
                    val isSelected = zone == selected
                    OutlinedButton(
                        onClick = { onSelect(zone) },
                        modifier = Modifier.weight(1f).heightIn(min = 56.dp).semantics {
                            role = Role.Button
                            contentDescription = "코스 ${row + 1}, ${column + 1} ${if (isSelected) "선택됨" else "선택 가능"}"
                        },
                    ) { Text(if (isSelected) "●" else "○", color = ComposeColor.White) }
                }
            }
        }
    }
}
