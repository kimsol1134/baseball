package com.solkim.baseball.android

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.compose.setContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
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
import androidx.compose.ui.zIndex
import com.solkim.baseball.application.BaserunnerStateSnapshot
import com.solkim.baseball.application.KotlinGameStore
import com.solkim.baseball.application.MoundComposureInput
import com.solkim.baseball.application.MoundTensionInput
import com.solkim.baseball.application.MoundTensionModel
import com.solkim.baseball.application.Phase7VerticalController
import com.solkim.baseball.application.BatSide
import com.solkim.baseball.application.BattedBall
import com.solkim.baseball.application.FieldingResolutionSnapshot
import com.solkim.baseball.application.PitchBoundary
import com.solkim.baseball.application.PitchCareerKind
import com.solkim.baseball.application.PitchDelivery
import com.solkim.baseball.application.PitchKind
import com.solkim.baseball.application.PitchOutcome
import com.solkim.baseball.application.PitchZone
import com.solkim.baseball.design.BaseballMigrationTheme
import com.solkim.baseball.model.PitchPresentationRequest
import com.solkim.baseball.model.QualityTier
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * 100% Jetpack Compose Native 투구 화면 액티비티.
 * 기존 Unity 6 UaaL을 완전히 대체하여, 순수 Compose Canvas 기반 2컷 드라마 연출과
 * 핵심 투구 슬라이더 조작(PitchDeliveryControl)을 일체형으로 제공한다.
 */
public class PitchUnityActivity : ComponentActivity() {
    private lateinit var store: KotlinGameStore
    private lateinit var controller: Phase7VerticalController
    private lateinit var sessionId: String
    private lateinit var expectedRevision: String
    private var status by mutableStateOf("투구 준비 완료")
    private var selectedPitchIndex by mutableStateOf(0)
    private var selectedZone by mutableStateOf(PitchZone(1, 1))
    private var request by mutableStateOf<PitchPresentationRequest?>(null)
    private var resultReady by mutableStateOf(false)
    private var isDelivering by mutableStateOf(false)
    private var returningToShell = false
    private val activityScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        store = (application as BaseballApplication).gameStore
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

        loadSavedPresentationOrInput()

        setContent {
            BaseballMigrationTheme {
                val settings = store.current.settings
                val dramaProgress = remember { Animatable(if (resultReady) 1f else 0f) }

                // 투구 제출 시 드라마 애니메이션 실행
                LaunchedEffect(request, isDelivering) {
                    val saved = request
                    if (isDelivering && saved != null) {
                        dramaProgress.snapTo(0f)
                        val duration = if (settings.reducedMotionEnabled) 80 else saved.flightDurationMs
                        val seed = moundSeed()

                        // 1. 릴리스 사운드 / 햅틱
                        platform().audioHaptics.presentNativeMarker("release", playbackSettings(), seed)

                        // 2. 컨택/포구 타이밍 사운드 / 햅틱
                        val contactDelay = (duration * 0.46f).toLong()
                        launch {
                            delay(contactDelay)
                            val outcome = currentOutcome()
                            val isBatted = outcome in setOf(
                                PitchOutcome.FOUL, PitchOutcome.IN_PLAY_OUT,
                                PitchOutcome.SINGLE, PitchOutcome.DOUBLE, PitchOutcome.TRIPLE, PitchOutcome.HOME_RUN,
                            )
                            val marker = if (isBatted) "impact" else "plate"
                            platform().audioHaptics.presentNativeMarker(marker, playbackSettings(), seed)
                        }

                        // 3. 궤적 비행 애니메이션
                        dramaProgress.animateTo(
                            targetValue = 1f,
                            animationSpec = tween(durationMillis = duration, easing = LinearEasing),
                        )

                        // 4. 완료 후 consume 커밋
                        consumeAfterAnimationComplete(saved)
                    }
                }

                Box(modifier = Modifier.fillMaxSize()) {
                    val outcome = currentOutcome()
                    val battedBall = currentBattedBall()
                    val batSide = currentBatSide()

                    // 레이어 0: 순수 Compose 2컷 뷰포트 (PitchDramaView)
                    PitchDramaView(
                        request = request,
                        outcome = outcome,
                        battedBall = battedBall,
                        fielding = null,
                        batSide = batSide,
                        progress = dramaProgress.value,
                        modifier = Modifier.fillMaxSize(),
                    )

                    // 레이어 1: 전경 UI 오버레이 (HUD, 구종/코스 선택, 투구 슬라이더)
                    PitchSessionOverlay(
                        status = status,
                        selectedPitchIndex = selectedPitchIndex,
                        selectedZone = selectedZone,
                        ready = !isDelivering,
                        resultReady = resultReady,
                        autoRelease = settings.autoReleaseEnabled,
                        velocityTenthsKph = selectedPitchVelocity(),
                        fatigue = store.current.pro?.fatigue ?: store.current.highSchool?.run?.fatigue ?: 0,
                        reduceMotion = settings.reducedMotionEnabled,
                        hapticsEnabled = settings.hapticsEnabled,
                        soundEnabled = settings.soundEnabled,
                        tension = moundTension(),
                        disturbanceSeed = moundSeed(),
                        adverseEpisode = moundAdverseEpisode(),
                        onSelectPitch = { selectedPitchIndex = it },
                        onSelectZone = { selectedZone = it },
                        onDeliver = ::submitSelectedPitch,
                        onReplay = {
                            activityScope.launch {
                                dramaProgress.snapTo(0f)
                                dramaProgress.animateTo(1f, tween(request?.flightDurationMs ?: 600, easing = LinearEasing))
                            }
                        },
                        onPostgame = ::completeAndReturn,
                        onBack = ::handleBack,
                    )
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val nextSession = intent.getStringExtra(EXTRA_SESSION_ID) ?: return
        val nextRevision = intent.getStringExtra(EXTRA_EXPECTED_REVISION) ?: return
        if (nextSession != sessionId) {
            sessionId = nextSession
            request = null
            resultReady = false
            isDelivering = false
            selectedPitchIndex = 0
            selectedZone = PitchZone(1, 1)
        }
        expectedRevision = nextRevision
        returningToShell = false
        resultReady = false
        isDelivering = false
        request = null
        if (!lookupSavedSession(expectedRevision)) return
        status = "저장된 투구 세션 재진입 · revision ${store.state.value.revision}"
        loadSavedPresentationOrInput()
    }

    override fun onDestroy() {
        activityScope.cancel()
        super.onDestroy()
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
                            resultReady = pitch.boundary != PitchBoundary.COMMITTED
                            status = if (resultReady) "저장된 결과 · 결과 화면 이동 가능" else "투구 준비 완료"
                        }
                    }
                    PitchBoundary.PLAYING -> {
                        val saved = state.highSchool?.lastPresentation
                        val savedPro = state.pro?.lastPresentation
                        if ((pitch.careerKind.name == "HIGH_SCHOOL" && saved != null) ||
                            (pitch.careerKind.name == "PRO" && savedPro != null)) {
                            val rebuilt = controller.commitSavedPresentation(sessionId, selectedPitchIndex)
                            withContext(Dispatchers.Main) {
                                request = rebuilt
                                resultReady = false
                                status = "저장된 결과를 다시 재생할 준비가 되었습니다"
                            }
                        } else {
                            withContext(Dispatchers.Main) { status = "구종과 코스를 선택하고 투구하세요" }
                        }
                    }
                    PitchBoundary.RESERVED,
                    PitchBoundary.SUSPENDED -> withContext(Dispatchers.Main) {
                        status = "구종과 코스를 선택하고 투구하세요"
                    }
                    PitchBoundary.ABANDONED -> withContext(Dispatchers.Main) {
                        resultReady = true
                        status = "이 투구는 명시적으로 종료되었습니다"
                    }
                }
            } catch (error: Throwable) {
                withContext(Dispatchers.Main) { status = "저장된 pitch 복구 실패 · ${error.message ?: "invalid"}" }
            }
        }
    }

    private fun submitSelectedPitch(delivery: PitchDelivery) {
        if (isDelivering) return
        status = "투구 결과 계산 및 렌더링 중…"
        isDelivering = true
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
                }
            } catch (error: Throwable) {
                withContext(Dispatchers.Main) {
                    isDelivering = false
                    status = "Kotlin 판정/commit 실패 · ${error.message ?: "invalid"}"
                }
            }
        }
    }

    private fun consumeAfterAnimationComplete(saved: PitchPresentationRequest) {
        activityScope.launch {
            try {
                controller.consumePresentation(sessionId, saved)
                withContext(Dispatchers.Main) {
                    isDelivering = false
                    resultReady = true
                    status = "투구 결과 저장 완료 · 결과 화면으로 이동 가능"
                }
            } catch (error: Throwable) {
                withContext(Dispatchers.Main) {
                    isDelivering = false
                    status = "consume save 실패 · ${error.message ?: "invalid"}"
                }
            }
        }
    }

    private fun completeAndReturn() {
        activityScope.launch {
            try {
                controller.completePitchAndPostgame(sessionId)
                withContext(Dispatchers.Main) {
                    returningToShell = true
                    startActivity(Intent(this@PitchUnityActivity, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT))
                    finish()
                }
            } catch (error: Throwable) {
                withContext(Dispatchers.Main) { status = "Postgame 저장 실패 · ${error.message ?: "invalid"}" }
            }
        }
    }

    private fun handleBack() {
        val pitch = store.state.value.pitch ?: run { finish(); return }
        if (pitch.boundary in setOf(PitchBoundary.RESERVED, PitchBoundary.PLAYING, PitchBoundary.COMMITTED, PitchBoundary.CONSUMED)) {
            activityScope.launch {
                runCatching { controller.suspendPitch(sessionId) }
                    .onFailure { Log.w(TAG, "pitch suspend failed", it) }
                withContext(Dispatchers.Main) {
                    returningToShell = true
                    startActivity(Intent(this@PitchUnityActivity, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT))
                    finish()
                }
            }
        } else {
            finish()
        }
    }

    private fun pitchTypeForIndex(index: Int): PitchKind = when (index.coerceIn(0, 3)) {
        0 -> PitchKind.FOUR_SEAM
        1 -> PitchKind.SLIDER
        2 -> PitchKind.CURVEBALL
        else -> PitchKind.CHANGEUP
    }

    private fun currentOutcome(): PitchOutcome? {
        val proEntry = store.current.pro?.activePitch?.log?.entries?.lastOrNull()
        if (proEntry != null) return proEntry.outcome
        val hsEntry = store.current.highSchool?.activePitch?.log?.entries?.lastOrNull()
        if (hsEntry != null) return hsEntry.outcome
        return null
    }

    private fun currentBattedBall(): BattedBall? {
        val proContact = store.current.pro?.activePitch?.log?.entries?.lastOrNull()?.contactQuality
        val hsContact = store.current.highSchool?.activePitch?.log?.entries?.lastOrNull()?.contactQuality
        val contact = proContact ?: hsContact ?: return null
        return BattedBall(exitVelocityTenthsKph = 1400, launchAngleTenthsDegrees = 150, directionTenthsDegrees = 0, contactQuality = contact)
    }

    private fun currentBatSide(): BatSide =
        store.current.pro?.activePitch?.batter?.batSide ?: BatSide.RIGHT

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
        val adverse = moundAdverseEpisode()
        val composure = MoundComposureInput(
            command = pro?.pitcher?.command ?: hs?.run?.pitcher?.command ?: 0,
            stamina = pro?.pitcher?.stamina ?: hs?.run?.pitcher?.stamina ?: 0,
            awakeningWires = hs?.run?.selectedAwakenings.orEmpty().map { it.wire },
            memoryWires = emptyList(),
        )
        val raw = MoundTensionModel.tension(
            MoundTensionInput(official, leverage, runners, balls, strikes, outs, fatigue, threat, adverse, composure),
        )
        return MoundTensionModel.entryTension(raw, official)
    }

    private fun moundAdverseEpisode(): Boolean {
        val last = currentOutcome()
        return last in adverseOutcomes
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
        val profiles = store.current.pro?.pitcher?.pitchProfiles ?: emptyList()
        return profiles.firstOrNull { it.pitchType == kind }?.velocityTenthsKph ?: 1_350
    }

    private fun platform(): com.solkim.baseball.platform.NativePhase9Platform = (application as BaseballApplication).platform

    private fun playbackSettings(): com.solkim.baseball.platform.NativePlaybackSettings {
        val settings = store.current.settings
        return com.solkim.baseball.platform.NativePlaybackSettings(
            settings.soundEnabled,
            settings.musicEnabled,
            settings.hapticsEnabled,
            settings.reducedMotionEnabled,
        )
    }

    public companion object {
        private const val TAG = "PitchUnityActivity"
        public const val EXTRA_SESSION_ID: String = "com.solkim.baseball.android.SESSION_ID"
        public const val EXTRA_EXPECTED_REVISION: String = "com.solkim.baseball.android.EXPECTED_REVISION"

        public fun intent(context: Context, sessionId: String, expectedRevision: String): Intent =
            Intent(context, PitchUnityActivity::class.java).apply {
                putExtra(EXTRA_SESSION_ID, sessionId)
                putExtra(EXTRA_EXPECTED_REVISION, expectedRevision)
            }
    }
}

@Composable
private fun PitchSessionOverlay(
    status: String,
    selectedPitchIndex: Int,
    selectedZone: PitchZone,
    ready: Boolean,
    resultReady: Boolean,
    autoRelease: Boolean,
    velocityTenthsKph: Int,
    fatigue: Int,
    reduceMotion: Boolean,
    hapticsEnabled: Boolean,
    soundEnabled: Boolean,
    tension: Double,
    disturbanceSeed: ULong,
    adverseEpisode: Boolean,
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
                    }
                }
                Spacer(Modifier.height(180.dp))
                Surface(color = ComposeColor(0xE6050A15), shape = MaterialTheme.shapes.large) {
                    Column(
                        Modifier.fillMaxWidth().padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        if (resultReady) {
                            Text("투구가 완료되었습니다.", style = MaterialTheme.typography.titleMedium)
                            Button(onClick = onReplay, modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).semantics { contentDescription = "동일 투구 다시 재생" }) {
                                Text("같은 투구 다시 재생")
                            }
                            Button(onClick = onPostgame, modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).semantics { contentDescription = "결과 화면으로 이동" }) {
                                Text("결과 화면으로")
                            }
                        } else {
                            val kinds = listOf("직구", "슬라이더", "커브", "체인지업")
                            Text("${kinds[selectedPitchIndex.coerceIn(0, 3)]} · ${velocityTenthsKph / 10}km/h", color = ComposeColor.White, style = MaterialTheme.typography.labelLarge)
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                kinds.forEachIndexed { index, label ->
                                    val selected = selectedPitchIndex == index
                                    OutlinedButton(
                                        onClick = { onSelectPitch(index) },
                                        enabled = ready,
                                        modifier = Modifier.weight(1f).heightIn(min = 48.dp).semantics {
                                            role = Role.Button
                                            contentDescription = "$label ${if (selected) "선택됨" else "선택 가능"}"
                                            stateDescription = if (selected) "선택됨" else "선택되지 않음"
                                        },
                                    ) { Text(if (selected) "✓ $label" else label, color = ComposeColor.White, style = MaterialTheme.typography.labelMedium) }
                                }
                            }
                            ZonePicker(selectedZone, onSelectZone, enabled = ready)
                            PitchDeliveryControl(
                                autoRelease = autoRelease,
                                enabled = ready,
                                onDeliver = onDeliver,
                                velocityTenthsKph = velocityTenthsKph,
                                fatigue = fatigue,
                                reduceMotion = reduceMotion,
                                hapticsEnabled = hapticsEnabled,
                                soundEnabled = soundEnabled,
                                tension = tension,
                                disturbanceSeed = disturbanceSeed,
                                adverseEpisode = adverseEpisode,
                            )
                        }
                        OutlinedButton(onClick = onBack, modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).semantics { contentDescription = "투구를 일시정지하고 메인으로 돌아가기" }) {
                            Text("뒤로가기 · 저장 후 일시정지", color = ComposeColor.White)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ZonePicker(selected: PitchZone, onSelect: (PitchZone) -> Unit, enabled: Boolean = true) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        repeat(3) { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                repeat(3) { column ->
                    val zone = PitchZone(row, column)
                    val isSelected = zone == selected
                    OutlinedButton(
                        onClick = { onSelect(zone) },
                        enabled = enabled,
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
