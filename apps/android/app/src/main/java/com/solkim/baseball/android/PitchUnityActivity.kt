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
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color as ComposeColor
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
import com.solkim.baseball.application.PitchDramaCamera
import com.solkim.baseball.application.PitchDelivery
import com.solkim.baseball.application.PitchKind
import com.solkim.baseball.application.PitchOutcome
import com.solkim.baseball.application.PitchHudProjection
import com.solkim.baseball.application.PitchHudSelection
import com.solkim.baseball.application.PitchLiveResult
import com.solkim.baseball.application.PitchScoreboardModel
import com.solkim.baseball.application.PitchScoreboardProjection
import com.solkim.baseball.application.PitchRecommendation
import com.solkim.baseball.application.PitchZone
import com.solkim.baseball.core.pitch.PitchIntensity
import com.solkim.baseball.core.pitch.ZoneIntent
import com.solkim.baseball.design.BaseballColors
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
    private var selectedSign by mutableStateOf<PitchHudSelection>(PitchHudSelection.Primary)
    private var selectedPitchIndex by mutableStateOf(0)
    private var selectedZone by mutableStateOf(PitchZone(1, 1))
    private var selectedIntent by mutableStateOf(ZoneIntent.EDGE)
    private var selectedIntensity by mutableStateOf(PitchIntensity.NORMAL)
    private var holdCall by mutableStateOf(false)
    private var chromeExpanded by mutableStateOf(false)
    private var request by mutableStateOf<PitchPresentationRequest?>(null)
    private var lastDelivery by mutableStateOf<PitchDelivery?>(null)
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
                val gameState by store.state.collectAsState()
                val settings = gameState.settings
                val dramaProgress = remember { Animatable(if (resultReady) 1f else 0f) }
                val composeScope = rememberCoroutineScope()

                // 투구 제출 시 드라마 애니메이션 실행
                LaunchedEffect(request, isDelivering) {
                    val saved = request
                    if (isDelivering && saved != null) {
                        dramaProgress.snapTo(0f)
                        val duration = PitchDramaCamera.replayDurationMs(
                            saved.flightDurationMs,
                            settings.reducedMotionEnabled,
                        )
                        val seed = moundSeed()

                        // 1. 릴리스 사운드 / 햅틱
                        platform().audioHaptics.presentNativeMarker("release", playbackSettings(), seed)

                        // 2. 컨택/포구 타이밍 사운드 / 햅틱
                        val contactDelay = (duration * PitchDramaCamera.CONTACT_PROGRESS).toLong()
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

                        dramaProgress.animateTo(
                            targetValue = 1f,
                            animationSpec = tween(durationMillis = duration, easing = LinearEasing),
                        )

                        // 4. 완료 후 consume 커밋
                        consumeAfterAnimationComplete(saved)
                    } else if (saved == null) {
                        dramaProgress.snapTo(0f)
                    }
                }

                val showingResult = request != null
                val outcome = if (showingResult) currentOutcome() else null
                val battedBall = if (showingResult) currentBattedBall() else null
                val fielding = if (showingResult) currentFielding() else null
                val batSide = currentBatSide()

                val board = PitchScoreboardProjection.model(gameState)
                val balls = board.balls
                val strikes = board.strikes
                val outs = board.outs
                val isClutch = strikes == 2 && (balls == 3 || outs == 2)
                val hud = runCatching { PitchHudProjection.model(gameState) }.getOrNull()
                val batter = hud?.batter
                val batterName = batter?.name ?: "상대 타자"
                val isLeftBatter = (batter?.batSide ?: BatSide.RIGHT) == BatSide.LEFT
                val batterContact = batter?.contact ?: 0
                val batterDiscipline = batter?.discipline ?: 0
                val batterPower = batter?.power ?: 0
                val fatigue = gameState.pro?.fatigue ?: gameState.highSchool?.run?.fatigue ?: 0
                val leverage = gameState.pro?.activePitch?.context?.leverage
                    ?: gameState.highSchool?.activePitch?.context?.leverage
                    ?: if (gameState.pitch?.careerKind == PitchCareerKind.TUTORIAL) 200 else 500

                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = BaseballColors.canvas,
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .statusBarsPadding()
                            .navigationBarsPadding(),
                    ) {
                        // 1. Top Header Bar
                        PitchTopBar(
                            title = hud?.scenarioTitle ?: "마운드 승부처",
                            subtitle = hud?.scenarioDetail ?: status,
                            stakesLabel = hud?.stakesLabel ?: "중요도",
                            stakesValue = hud?.stakesValue ?: PitchHudProjection.stakesValue(leverage),
                            abortLabel = hud?.abortLabel ?: "중단",
                            onBack = ::handleBack,
                        )

                        // 2. Scoreboard Bar
                        PitchScoreboardBar(board)

                        val watchingPitch = isDelivering || resultReady
                        val coachTip = hud?.coachTip
                        if (coachTip != null) {
                            PitchCoachStrip(label = hud?.coachLabel ?: "코치", tip = coachTip)
                        }
                        if (!watchingPitch) {
                            Box(Modifier.padding(horizontal = 16.dp, vertical = 6.dp)) {
                                val compact = (hud?.sessionPitches ?: 0) >= 3 && !chromeExpanded
                                if (compact) {
                                    PitchCompactMatchup(
                                        batterName = batterName,
                                        isLeftBatter = isLeftBatter,
                                        adaptationPercent = ((hud?.adaptationLevel ?: 0) * 100) / 900,
                                        onExpand = { chromeExpanded = true },
                                    )
                                } else {
                                PitchMatchupCard(
                                    batterName = batterName,
                                    isLeftBatter = isLeftBatter,
                                    contactLabel = hud?.contactLabel ?: "공 맞히기",
                                    disciplineLabel = hud?.disciplineLabel ?: "볼 고르기",
                                    powerLabel = hud?.powerLabel ?: "장타력",
                                    contact = batterContact,
                                    discipline = batterDiscipline,
                                    power = batterPower,
                                    adaptationTitle = hud?.adaptationTitle ?: "타자가 내 공을 읽는 정도",
                                    adaptationBandLabel = hud?.adaptationBandLabel ?: "",
                                    adaptationWarning = hud?.adaptationWarning ?: "",
                                    adaptationLevel = hud?.adaptationLevel ?: 0,
                                )
                                }
                            }
                        }

                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = if (watchingPitch) 4.dp else 8.dp)
                                .clip(RoundedCornerShape(16.dp))
                                .background(BaseballColors.fieldNight)
                                .border(1.dp, BaseballColors.border.copy(alpha = 0.5f), RoundedCornerShape(16.dp)),
                        ) {
                            PitchDramaView(
                                request = request,
                                outcome = outcome,
                                battedBall = battedBall,
                                fielding = fielding,
                                batSide = batSide,
                                progress = dramaProgress.value,
                                modifier = Modifier.fillMaxSize(),
                            )

                            if (showingResult && outcome != null) {
                                Text(
                                    text = localizedVerdict(outcome, battedBall),
                                    color = BaseballColors.action,
                                    style = MaterialTheme.typography.headlineMedium,
                                    fontWeight = FontWeight.Black,
                                    modifier = Modifier
                                        .align(Alignment.TopCenter)
                                        .padding(top = 16.dp)
                                        .semantics { contentDescription = "투구 판정 ${localizedVerdict(outcome, battedBall)}" },
                                )
                            }
                            if (isClutch && dramaProgress.value < 1f) {
                                Surface(
                                    modifier = Modifier
                                        .padding(12.dp)
                                        .align(Alignment.TopStart),
                                    color = BaseballColors.canvas.copy(alpha = 0.85f),
                                    shape = CircleShape,
                                    border = BorderStroke(1.dp, BaseballColors.milestone),
                                ) {
                                    Text(
                                        text = "승부구",
                                        color = BaseballColors.milestone,
                                        style = MaterialTheme.typography.labelSmall,
                                        fontWeight = FontWeight.Black,
                                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                                    )
                                }
                            }
                        }

                        if (!isDelivering) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp, vertical = 8.dp),
                                verticalArrangement = Arrangement.spacedBy(10.dp),
                            ) {
                                val repertoire = hud?.repertoire.orEmpty()
                                PitchControlsCard(
                                    repertoire = repertoire,
                                    primary = hud?.preparation?.primaryRecommendation,
                                    alternative = hud?.preparation?.alternativeRecommendation,
                                    selection = selectedSign,
                                    selectedZone = selectedCallZone(hud),
                                    selectedIntent = selectedIntent,
                                    selectedIntensity = selectedIntensity,
                                    batSide = batter?.batSide ?: BatSide.RIGHT,
                                    currentPitchLine = hud?.currentPitchLine ?: "",
                                    primaryExplanation = hud?.primaryExplanation ?: "",
                                    holdToReleasePrompt = hud?.holdToReleasePrompt ?: "길게 눌러 와인드업",
                                    ready = repertoire.isNotEmpty(),
                                    velocityTenthsKph = selectedPitchVelocity(),
                                    autoRelease = settings.autoReleaseEnabled,
                                    autoReleaseLabel = hud?.autoReleaseLabel ?: "자동 릴리스 — 탭 한 번으로 중립 투구",
                                    catcherConfidenceLabel = hud?.catcherConfidenceLabel ?: "",
                                    catcherTrustLabel = hud?.catcherTrustLabel ?: "",
                                    fatigue = fatigue,
                                    reduceMotion = settings.reducedMotionEnabled,
                                    hapticsEnabled = settings.hapticsEnabled,
                                    soundEnabled = settings.soundEnabled,
                                    tension = moundTension(),
                                    disturbanceSeed = moundSeed(),
                                    adverseEpisode = moundAdverseEpisode(),
                                    holdCall = holdCall,
                                    scoutingTitle = hud?.scoutingTitle ?: "상대 분석",
                                    scoutingBody = hud?.scoutingBody ?: "",
                                    scoutingAvoid = hud?.scoutingAvoid ?: "",
                                    canFastForward = hud?.canFastForward == true,
                                    onSelect = { sign ->
                                        selectedSign = sign
                                        when (sign) {
                                            is PitchHudSelection.Manual -> {
                                                selectedZone = sign.zone
                                                selectedIntent = sign.intent
                                                selectedIntensity = sign.intensity
                                            }
                                            PitchHudSelection.Primary -> {
                                                hud?.preparation?.primaryRecommendation?.call?.let { call ->
                                                    selectedZone = call.zone
                                                    selectedIntent = call.zoneIntent
                                                    selectedIntensity = call.intensity
                                                }
                                            }
                                            PitchHudSelection.Alternative -> {
                                                hud?.preparation?.alternativeRecommendation?.call?.let { call ->
                                                    selectedZone = call.zone
                                                    selectedIntent = call.zoneIntent
                                                    selectedIntensity = call.intensity
                                                }
                                            }
                                        }
                                    },
                                    onDeliver = ::submitSelectedPitch,
                                    onHoldCallChange = { holdCall = it },
                                    onFastForward = ::fastForwardCurrentBatter,
                                    onAutoReleaseChange = { enabled ->
                                        activityScope.launch {
                                            controller.updateSettings(
                                                store.current.settings.copy(autoReleaseEnabled = enabled),
                                            )
                                        }
                                    },
                                )
                            }
                        }
                    }
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
            selectedSign = PitchHudSelection.Primary
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
                        if (controller.shouldRecoverPlayingPresentation(state, sessionId)) {
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
        lastDelivery = delivery
        activityScope.launch {
            try {
                val boundary = store.current.pitch?.boundary
                if (boundary == PitchBoundary.TERMINAL || boundary == PitchBoundary.COMPLETED) {
                    if (boundary == PitchBoundary.TERMINAL) {
                        controller.completePitchAndPostgame(sessionId)
                    }
                    val launch = controller.continueOfficialPitch()
                    if (launch == null) {
                        withContext(Dispatchers.Main) {
                            status = "이 타석의 투구가 끝났습니다"
                        }
                        return@launch
                    }
                    sessionId = launch.sessionId
                    expectedRevision = launch.expectedRevision.toString()
                }
                withContext(Dispatchers.Main) {
                    resultReady = false
                    request = null
                    isDelivering = true
                    status = "투구 결과 계산 및 렌더링 중…"
                }
                val saved = controller.submitPitch(
                    sessionId = sessionId,
                    selection = selectedSign,
                    delivery = delivery,
                )
                withContext(Dispatchers.Main) {
                    request = saved
                }
            } catch (error: Throwable) {
                Log.e(TAG, "submitPitch error: ${error.javaClass.name}: ${error.message}", error)
                withContext(Dispatchers.Main) {
                    isDelivering = false
                    status = "Kotlin 판정/commit 실패 · ${error.javaClass.simpleName}: ${error.message ?: "invalid"}"
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

    private fun continueInSession() {
        activityScope.launch {
            try {
                controller.completePitchAndPostgame(sessionId)
                val launch = controller.continueOfficialPitch()
                withContext(Dispatchers.Main) {
                    if (launch == null) {
                        returningToShell = true
                        startActivity(Intent(this@PitchUnityActivity, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT))
                        finish()
                    } else {
                        sessionId = launch.sessionId
                        expectedRevision = launch.expectedRevision.toString()
                        resultReady = false
                        isDelivering = false
                        request = null
                        lastDelivery = null
                        if (!holdCall) selectedSign = PitchHudSelection.Primary
                        status = "다음 타석 · 포수 사인을 보고 던지세요"
                    }
                }
            } catch (error: Throwable) {
                withContext(Dispatchers.Main) { status = "다음 타석 준비 실패 · ${error.message ?: "invalid"}" }
            }
        }
    }

    private fun fastForwardCurrentBatter() {
        if (isDelivering) return
        activityScope.launch {
            try {
                withContext(Dispatchers.Main) { isDelivering = true }
                val saved = controller.fastForwardCurrentBatter()
                withContext(Dispatchers.Main) {
                    request = saved
                    isDelivering = false
                    resultReady = saved != null
                    status = "타석을 빠르게 진행했습니다"
                }
            } catch (error: Throwable) {
                withContext(Dispatchers.Main) {
                    isDelivering = false
                    status = "빠른 진행 실패 · ${error.message ?: "invalid"}"
                }
            }
        }
    }

    private fun selectedCallZone(hud: com.solkim.baseball.application.PitchHudModel?): PitchZone {
        val preparation = hud?.preparation
        return when (val sign = selectedSign) {
            PitchHudSelection.Primary -> preparation?.primaryRecommendation?.call?.zone ?: selectedZone
            PitchHudSelection.Alternative -> preparation?.alternativeRecommendation?.call?.zone ?: selectedZone
            is PitchHudSelection.Manual -> sign.zone
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

    private fun selectedPitchType(): PitchKind {
        val hud = runCatching { PitchHudProjection.model(store.current) }.getOrNull()
        val repertoire = hud?.repertoire.orEmpty()
        return when (val sign = selectedSign) {
            PitchHudSelection.Primary -> hud?.preparation?.primaryRecommendation?.call?.pitchType
            PitchHudSelection.Alternative -> hud?.preparation?.alternativeRecommendation?.call?.pitchType
            is PitchHudSelection.Manual -> sign.pitchType
        } ?: repertoire.firstOrNull() ?: PitchKind.FOUR_SEAM
    }

    private fun currentOutcome(): PitchOutcome? = PitchLiveResult.outcome(store.current)

    private fun currentBattedBall(): BattedBall? = PitchLiveResult.battedBall(store.current)

    private fun currentFielding(): com.solkim.baseball.application.FieldingResolutionSnapshot? =
        PitchLiveResult.fielding(store.current)

    private fun currentBatSide(): BatSide =
        runCatching { PitchHudProjection.batter(store.current).batSide }.getOrDefault(BatSide.RIGHT)

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
        val batter = runCatching { PitchHudProjection.batter(state) }.getOrNull()
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
        val kind = selectedPitchType()
        val pitcher = runCatching { PitchHudProjection.pitcher(store.current) }.getOrNull()
        return pitcher?.pitchProfiles?.firstOrNull { it.pitchType == kind }?.velocityTenthsKph ?: 1_350
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
private fun PitchTopBar(
    title: String,
    subtitle: String,
    stakesLabel: String,
    stakesValue: String,
    abortLabel: String,
    onBack: () -> Unit,
) {
    Surface(
        color = BaseballColors.surface,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = BaseballColors.textPrimary,
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = BaseballColors.textTertiary,
                    maxLines = 2,
                )
            }
            Spacer(Modifier.width(8.dp))
            Surface(
                shape = RoundedCornerShape(10.dp),
                color = BaseballColors.surfaceSoft,
                border = BorderStroke(1.dp, BaseballColors.border.copy(alpha = 0.5f)),
                modifier = Modifier.padding(end = 8.dp),
            ) {
                Column(
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                    horizontalAlignment = Alignment.End,
                ) {
                    Text(
                        text = stakesLabel,
                        color = BaseballColors.textTertiary,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        text = stakesValue,
                        color = BaseballColors.textPrimary,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Black,
                    )
                }
            }
            OutlinedButton(
                onClick = onBack,
                border = BorderStroke(1.dp, BaseballColors.border),
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                modifier = Modifier.height(36.dp),
            ) {
                Text(abortLabel, color = BaseballColors.textSecondary, style = MaterialTheme.typography.labelSmall)
            }
        }
    }
}

@Composable
private fun PitchScoreboardBar(board: PitchScoreboardModel) {
    val scoreTone = when {
        board.scoreDiff > 0 -> BaseballColors.positive
        board.scoreDiff < 0 -> BaseballColors.negative
        else -> BaseballColors.textPrimary
    }
    val occupied = board.runners.firstOccupied || board.runners.secondOccupied || board.runners.thirdOccupied
    Surface(
        color = BaseballColors.surface,
        modifier = Modifier
            .fillMaxWidth()
            .semantics { contentDescription = board.accessibilityLabel },
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text(
                        text = board.scoreText,
                        color = scoreTone,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Black,
                    )
                    Text(
                        text = board.inningText,
                        color = BaseballColors.textSecondary,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    PipGroup(label = "OUT", count = board.outs, max = 2, activeColor = BaseballColors.negative)
                }
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                PipGroup(label = "B", count = board.balls, max = 3, activeColor = BaseballColors.warning)
                PipGroup(label = "S", count = board.strikes, max = 2, activeColor = BaseballColors.action)
                RunnerDiamond(board.runners)
                Text(
                    text = board.situationText,
                    color = if (occupied) BaseballColors.warning else BaseballColors.textSecondary,
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f),
                    maxLines = 1,
                )
                Text(
                    text = "피로 ${board.fatigue}",
                    color = if (board.fatigue >= 70) BaseballColors.warning else BaseballColors.textTertiary,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                )
            }
            board.outingLine?.let { line ->
                Text(
                    text = line,
                    color = BaseballColors.textTertiary,
                    style = MaterialTheme.typography.labelSmall,
                    fontFamily = FontFamily.Monospace,
                )
            }
        }
    }
}

@Composable
private fun PipGroup(label: String, count: Int, max: Int, activeColor: ComposeColor) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
        modifier = Modifier.clearAndSetSemantics { },
    ) {
        Text(
            text = label,
            color = BaseballColors.textTertiary,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
        )
        repeat(max) { index ->
            val isFilled = index < count
            Box(
                modifier = Modifier
                    .size(7.dp)
                    .clip(CircleShape)
                    .background(if (isFilled) activeColor else BaseballColors.border.copy(alpha = 0.5f)),
            )
        }
    }
}

@Composable
private fun RunnerDiamond(runners: BaserunnerStateSnapshot) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.clearAndSetSemantics { },
    ) {
        DiamondPip(filled = runners.secondOccupied)
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            DiamondPip(filled = runners.thirdOccupied)
            DiamondPip(filled = runners.firstOccupied)
        }
    }
}

@Composable
private fun DiamondPip(filled: Boolean) {
    Box(
        modifier = Modifier
            .size(8.dp)
            .clip(RoundedCornerShape(1.dp))
            .background(if (filled) BaseballColors.warning else BaseballColors.border.copy(alpha = 0.45f)),
    )
}

@Composable
private fun PitchMatchupCard(
    batterName: String,
    isLeftBatter: Boolean,
    contactLabel: String,
    disciplineLabel: String,
    powerLabel: String,
    contact: Int,
    discipline: Int,
    power: Int,
    adaptationTitle: String,
    adaptationBandLabel: String,
    adaptationWarning: String,
    adaptationLevel: Int,
) {
    Surface(
        color = BaseballColors.surfaceRaised,
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(1.dp, BaseballColors.border.copy(alpha = 0.4f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        text = batterName,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = BaseballColors.textPrimary,
                    )
                    Surface(
                        color = BaseballColors.action,
                        shape = CircleShape,
                    ) {
                        Text(
                            text = if (isLeftBatter) "좌타" else "우타",
                            color = BaseballColors.actionInk,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Black,
                            modifier = Modifier.padding(horizontal = 7.dp, vertical = 2.dp),
                        )
                    }
                }
                Text(
                    text = "$contactLabel $contact · $disciplineLabel $discipline · $powerLabel $power",
                    color = BaseballColors.textSecondary,
                    style = MaterialTheme.typography.bodySmall,
                    fontFamily = FontFamily.Monospace,
                )
            }
            AdaptationBar(
                title = adaptationTitle,
                bandLabel = adaptationBandLabel,
                warning = adaptationWarning,
                level = adaptationLevel,
            )
        }
    }
}

@Composable
private fun PitchCoachStrip(label: String, tip: String) {
    Surface(
        color = BaseballColors.surfaceRaised,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 7.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = label,
                color = BaseballColors.textTertiary,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = tip,
                color = BaseballColors.textPrimary,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun AdaptationBar(
    title: String,
    bandLabel: String,
    warning: String,
    level: Int,
) {
    val progress = (level / 900f).coerceIn(0f, 1f)
    val fill = when {
        level >= 600 -> BaseballColors.warning
        else -> BaseballColors.action
    }
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = title,
                color = BaseballColors.textTertiary,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
            )
            if (bandLabel.isNotBlank()) {
                Text(
                    text = bandLabel,
                    color = fill,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(50))
                .background(BaseballColors.surfaceSoft),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(progress)
                    .height(6.dp)
                    .clip(RoundedCornerShape(50))
                    .background(fill)
                    .align(Alignment.CenterStart),
            )
        }
        if (warning.isNotBlank()) {
            Text(
                text = warning,
                color = BaseballColors.textPrimary,
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}

@Composable
private fun PitchResultCard(
    outcome: PitchOutcome?,
    battedBall: BattedBall?,
    velocityTenthsKph: Int,
    delivery: PitchDelivery?,
    continueInSession: Boolean = false,
    onReplay: () -> Unit,
    onNextPitch: (() -> Unit)? = null,
    onPostgame: () -> Unit,
) {
    val tone = outcomeTone(outcome)
    val verdictTitle = if (outcome != null) localizedVerdict(outcome, battedBall) else "투구 완료"
    Surface(
        color = BaseballColors.surfaceRaised,
        shape = RoundedCornerShape(16.dp),
        border = BorderStroke(1.dp, tone.copy(alpha = 0.6f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    text = verdictTitle,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Black,
                    color = tone,
                )
                if (delivery != null) {
                    val verdictText = when {
                        delivery.isPerfectRelease -> "★ 퍼펙트 릴리스"
                        delivery.releaseAccuracy in 460..540 -> "타이밍 적절"
                        delivery.releaseAccuracy > 540 -> "타이밍 빠름"
                        else -> "타이밍 늦음"
                    }
                    val chipColor = if (delivery.isPerfectRelease || delivery.releaseAccuracy in 460..540)
                        BaseballColors.action else BaseballColors.warning
                    Surface(
                        shape = CircleShape,
                        color = chipColor.copy(alpha = 0.18f),
                        border = BorderStroke(1.dp, chipColor),
                    ) {
                        Text(
                            text = verdictText,
                            color = chipColor,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                        )
                    }
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    text = "${velocityTenthsKph / 10}.${velocityTenthsKph % 10} km/h",
                    color = BaseballColors.action,
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Black,
                    fontFamily = FontFamily.Monospace,
                )
                Text(
                    text = resultCommentary(outcome),
                    color = BaseballColors.textSecondary,
                    style = MaterialTheme.typography.bodySmall,
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                OutlinedButton(
                    onClick = onReplay,
                    modifier = Modifier
                        .weight(1f)
                        .heightIn(min = 50.dp),
                    border = BorderStroke(1.dp, BaseballColors.border),
                ) {
                    Text("투구 다시 보기", color = BaseballColors.textPrimary)
                }
                if (continueInSession && onNextPitch != null) {
                    Button(
                        onClick = onNextPitch,
                        modifier = Modifier
                            .weight(1f)
                            .heightIn(min = 50.dp),
                    ) {
                        Text("다음 공 던지기")
                    }
                } else {
                    Button(
                        onClick = onPostgame,
                        modifier = Modifier
                            .weight(1f)
                            .heightIn(min = 50.dp),
                    ) {
                        Text("결과 화면으로")
                    }
                }
            }
            if (continueInSession && onNextPitch != null) {
                OutlinedButton(
                    onClick = onPostgame,
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 44.dp),
                    border = BorderStroke(1.dp, BaseballColors.border),
                ) {
                    Text("잠시 나가기", color = BaseballColors.textSecondary)
                }
            }
        }
    }
}

private fun resultCommentary(outcome: PitchOutcome?): String = when (outcome) {
    PitchOutcome.SWINGING_STRIKE -> "배트가 허공을 갈랐습니다"
    PitchOutcome.CALLED_STRIKE -> "존 모서리를 완벽히 찔렀습니다"
    PitchOutcome.BALL -> "존을 살짝 벗어났습니다"
    PitchOutcome.FOUL -> "타자의 배트에 빗맞았습니다"
    PitchOutcome.HIT_BY_PITCH -> "몸에 맞는 공입니다"
    PitchOutcome.IN_PLAY_OUT -> "야수 정면 타구로 유도했습니다"
    PitchOutcome.SINGLE -> "타자가 빈틈을 노려 안타를 만들었습니다"
    PitchOutcome.DOUBLE -> "장타로 이어졌습니다"
    PitchOutcome.TRIPLE -> "외야 깊숙한 타구입니다"
    PitchOutcome.HOME_RUN -> "담장을 넘기는 홈런을 허용했습니다"
    null -> ""
}

@Composable
private fun PitchControlsCard(
    repertoire: List<PitchKind>,
    primary: PitchRecommendation?,
    alternative: PitchRecommendation?,
    selection: PitchHudSelection,
    selectedZone: PitchZone,
    selectedIntent: ZoneIntent = ZoneIntent.EDGE,
    selectedIntensity: PitchIntensity = PitchIntensity.NORMAL,
    batSide: BatSide,
    currentPitchLine: String,
    primaryExplanation: String,
    holdToReleasePrompt: String,
    ready: Boolean,
    velocityTenthsKph: Int,
    autoRelease: Boolean,
    autoReleaseLabel: String,
    catcherConfidenceLabel: String,
    catcherTrustLabel: String,
    fatigue: Int,
    reduceMotion: Boolean,
    hapticsEnabled: Boolean,
    soundEnabled: Boolean,
    tension: Double,
    disturbanceSeed: ULong,
    adverseEpisode: Boolean,
    holdCall: Boolean = false,
    scoutingTitle: String = "",
    scoutingBody: String = "",
    scoutingAvoid: String = "",
    canFastForward: Boolean = false,
    onSelect: (PitchHudSelection) -> Unit,
    onDeliver: (PitchDelivery) -> Unit,
    onHoldCallChange: (Boolean) -> Unit = {},
    onFastForward: () -> Unit = {},
    onAutoReleaseChange: ((Boolean) -> Unit)? = null,
) {
    val selectedType = when (selection) {
        PitchHudSelection.Primary -> primary?.call?.pitchType
        PitchHudSelection.Alternative -> alternative?.call?.pitchType
        is PitchHudSelection.Manual -> selection.pitchType
    }
    val selectedPitchLine = when (val sign = selection) {
        PitchHudSelection.Primary -> primary?.call?.let { PitchHudProjection.callLine(it, batSide) } ?: currentPitchLine
        PitchHudSelection.Alternative -> alternative?.call?.let { PitchHudProjection.callLine(it, batSide) } ?: currentPitchLine
        is PitchHudSelection.Manual -> listOf(
            PitchHudProjection.koreanLabel(sign.pitchType),
            PitchHudProjection.zoneLabel(sign.zone, batSide),
        ).joinToString(" · ")
    }
    val selectedReason = when (selection) {
        PitchHudSelection.Primary -> primary?.shortReason
        PitchHudSelection.Alternative -> alternative?.shortReason
        is PitchHudSelection.Manual -> primary?.shortReason
    }.orEmpty().ifBlank { primaryExplanation }
    Surface(
        color = BaseballColors.surfaceRaised,
        shape = RoundedCornerShape(16.dp),
        border = BorderStroke(1.dp, BaseballColors.border.copy(alpha = 0.4f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            if (selectedPitchLine.isNotBlank()) {
                Text("지금 던질 공", style = MaterialTheme.typography.labelMedium, color = BaseballColors.milestone)
                Text(
                    text = selectedPitchLine,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = BaseballColors.textPrimary,
                )
            }
            if (catcherConfidenceLabel.isNotBlank() || catcherTrustLabel.isNotBlank()) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    if (catcherConfidenceLabel.isNotBlank()) {
                        CatcherMetaChip(catcherConfidenceLabel, modifier = Modifier.weight(1f))
                    }
                    if (catcherTrustLabel.isNotBlank()) {
                        CatcherMetaChip(catcherTrustLabel, modifier = Modifier.weight(1f))
                    }
                }
            }
            if (primary != null && alternative != null) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    CatcherOptionSegment(
                        label = "1안",
                        selected = selection is PitchHudSelection.Primary,
                        enabled = ready,
                        modifier = Modifier.weight(1f),
                        onClick = { onSelect(PitchHudSelection.Primary) },
                    )
                    CatcherOptionSegment(
                        label = "2안",
                        selected = selection is PitchHudSelection.Alternative,
                        enabled = ready,
                        modifier = Modifier.weight(1f),
                        onClick = { onSelect(PitchHudSelection.Alternative) },
                    )
                }
                if (selectedReason.isNotBlank()) {
                    Text(
                        text = selectedReason,
                        color = BaseballColors.textSecondary,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                repertoire.forEach { kind ->
                    val label = PitchHudProjection.koreanLabel(kind)
                    val isSelected = selectedType == kind
                    Surface(
                        color = if (isSelected) BaseballColors.action.copy(alpha = 0.18f) else BaseballColors.surfaceSoft,
                        shape = RoundedCornerShape(8.dp),
                        border = BorderStroke(if (isSelected) 1.5.dp else 1.dp, if (isSelected) BaseballColors.action else BaseballColors.border.copy(alpha = 0.5f)),
                        modifier = Modifier
                            .weight(1f)
                            .height(44.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .clickable(enabled = ready) {
                                onSelect(PitchHudSelection.Manual(kind, selectedZone, selectedIntent, selectedIntensity))
                            }
                            .semantics {
                                role = Role.Button
                                contentDescription = "$label ${if (isSelected) "선택됨" else "선택 가능"}"
                            },
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text(
                                text = label,
                                color = if (isSelected) BaseballColors.action else BaseballColors.textSecondary,
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                            )
                        }
                    }
                }
            }

            PitchDeliveryControl(
                autoRelease = autoRelease,
                enabled = ready,
                holdPrompt = holdToReleasePrompt,
                onDeliver = onDeliver,
                velocityTenthsKph = velocityTenthsKph,
                fatigue = fatigue,
                reduceMotion = reduceMotion,
                hapticsEnabled = hapticsEnabled,
                soundEnabled = soundEnabled,
                tension = tension,
                disturbanceSeed = disturbanceSeed,
                adverseEpisode = adverseEpisode,
                pitchTypeLabel = PitchHudProjection.koreanLabel(selectedType ?: PitchKind.FOUR_SEAM),
                onAutoReleaseChange = onAutoReleaseChange,
                autoReleaseLabel = autoReleaseLabel,
            )
            if (canFastForward) {
                OutlinedButton(
                    onClick = onFastForward,
                    enabled = ready,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 44.dp),
                    border = BorderStroke(1.dp, BaseballColors.border),
                ) {
                    Column(horizontalAlignment = Alignment.Start, modifier = Modifier.fillMaxWidth()) {
                        Text("이 타석 빠르게 진행", color = BaseballColors.textPrimary, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
                        Text("포수 추천과 무난한 릴리스로 타석이 끝날 때까지 던집니다.", color = BaseballColors.textTertiary, style = MaterialTheme.typography.labelSmall)
                    }
                }
            }
            PitchManualPlan(
                repertoireType = selectedType ?: repertoire.firstOrNull() ?: PitchKind.FOUR_SEAM,
                selectedZone = selectedZone,
                selectedIntent = selectedIntent,
                selectedIntensity = selectedIntensity,
                batSide = batSide,
                enabled = ready,
                onChange = { type, zone, intent, intensity ->
                    onSelect(PitchHudSelection.Manual(type, zone, intent, intensity))
                },
            )
            PitchCatcherSettings(
                holdCall = holdCall,
                scoutingTitle = scoutingTitle,
                scoutingBody = scoutingBody,
                scoutingAvoid = scoutingAvoid,
                onHoldCallChange = onHoldCallChange,
            )
        }
    }
}

@Composable
private fun PitchCompactMatchup(
    batterName: String,
    isLeftBatter: Boolean,
    adaptationPercent: Int,
    onExpand: () -> Unit,
) {
    Surface(
        color = BaseballColors.surfaceRaised,
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(1.dp, BaseballColors.border.copy(alpha = 0.4f)),
        modifier = Modifier.fillMaxWidth().clickable(onClick = onExpand),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                "$batterName ${if (isLeftBatter) "좌타" else "우타"} · 읽힘 $adaptationPercent%",
                color = BaseballColors.textPrimary,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Text("자세히", color = BaseballColors.action, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun PitchManualPlan(
    repertoireType: PitchKind,
    selectedZone: PitchZone,
    selectedIntent: ZoneIntent,
    selectedIntensity: PitchIntensity,
    batSide: BatSide,
    enabled: Boolean,
    onChange: (PitchKind, PitchZone, ZoneIntent, PitchIntensity) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            if (expanded) "노림 · 힘 배분 ▴" else "노림 · 힘 배분 ▾",
            style = MaterialTheme.typography.labelMedium,
            color = BaseballColors.milestone,
            modifier = Modifier.clickable { expanded = !expanded },
        )
        if (expanded) {
        Text("코스 · ${PitchHudProjection.zoneLabel(selectedZone, batSide)}", style = MaterialTheme.typography.labelSmall, color = BaseballColors.textSecondary)
        PitchZoneGrid(
            selected = selectedZone,
            enabled = enabled,
            onSelect = { onChange(repertoireType, it, selectedIntent, selectedIntensity) },
        )
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
            ZoneIntent.entries.forEach { intent ->
                val selected = intent == selectedIntent
                Surface(
                    color = if (selected) BaseballColors.action.copy(alpha = 0.14f) else BaseballColors.surfaceSoft,
                    shape = RoundedCornerShape(8.dp),
                    border = BorderStroke(if (selected) 1.5.dp else 1.dp, if (selected) BaseballColors.action else BaseballColors.border.copy(alpha = 0.5f)),
                    modifier = Modifier.weight(1f).clickable(enabled = enabled) { onChange(repertoireType, selectedZone, intent, selectedIntensity) },
                ) {
                    Text(
                        PitchHudProjection.intentLabel(intent),
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 8.dp),
                        color = if (selected) BaseballColors.action else BaseballColors.textSecondary,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
            PitchIntensity.entries.forEach { intensity ->
                val selected = intensity == selectedIntensity
                Surface(
                    color = if (selected) BaseballColors.action.copy(alpha = 0.14f) else BaseballColors.surfaceSoft,
                    shape = RoundedCornerShape(8.dp),
                    border = BorderStroke(if (selected) 1.5.dp else 1.dp, if (selected) BaseballColors.action else BaseballColors.border.copy(alpha = 0.5f)),
                    modifier = Modifier.weight(1f).clickable(enabled = enabled) { onChange(repertoireType, selectedZone, selectedIntent, intensity) },
                ) {
                    Text(
                        PitchHudProjection.intensityLabel(intensity),
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 8.dp),
                        color = if (selected) BaseballColors.action else BaseballColors.textSecondary,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }
        }
    }
}

@Composable
private fun PitchCatcherSettings(
    holdCall: Boolean,
    scoutingTitle: String,
    scoutingBody: String,
    scoutingAvoid: String,
    onHoldCallChange: (Boolean) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            if (expanded) "설정 ▴" else "설정 ▾",
            style = MaterialTheme.typography.labelMedium,
            color = BaseballColors.milestone,
            modifier = Modifier.clickable { expanded = !expanded },
        )
        if (expanded) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text("내 선택 유지", color = BaseballColors.textPrimary, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
                Text("다음 공에도 내 배합을 그대로 이어 갑니다.", color = BaseballColors.textTertiary, style = MaterialTheme.typography.labelSmall)
            }
            Switch(checked = holdCall, onCheckedChange = onHoldCallChange)
        }
        if (scoutingTitle.isNotBlank()) {
            Text(scoutingTitle, color = BaseballColors.textPrimary, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold)
        }
        if (scoutingBody.isNotBlank()) {
            Text(scoutingBody, color = BaseballColors.textSecondary, style = MaterialTheme.typography.bodySmall)
        }
        if (scoutingAvoid.isNotBlank()) {
            Text(scoutingAvoid, color = BaseballColors.warning, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.SemiBold)
        }
        }
    }
}

@Composable
private fun PitchZoneGrid(
    selected: PitchZone,
    enabled: Boolean,
    onSelect: (PitchZone) -> Unit,
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.fillMaxWidth()) {
        repeat(3) { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                repeat(3) { col ->
                    val zone = PitchZone(row, col)
                    val isSelected = zone == selected
                    Box(
                        modifier = Modifier
                            .size(width = 64.dp, height = 36.dp)
                            .clip(RoundedCornerShape(6.dp))
                            .background(if (isSelected) BaseballColors.action.copy(alpha = 0.28f) else BaseballColors.surfaceSoft)
                            .border(if (isSelected) 1.5.dp else 1.dp, if (isSelected) BaseballColors.action else BaseballColors.border.copy(alpha = 0.45f), RoundedCornerShape(6.dp))
                            .clickable(enabled = enabled) { onSelect(zone) },
                        contentAlignment = Alignment.Center,
                    ) {
                        Box(
                            modifier = Modifier
                                .size(if (isSelected) 10.dp else 4.dp)
                                .clip(CircleShape)
                                .background(if (isSelected) BaseballColors.action else BaseballColors.textTertiary.copy(alpha = 0.5f)),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun CatcherMetaChip(text: String, modifier: Modifier = Modifier) {
    Surface(
        color = BaseballColors.surfaceSoft,
        shape = RoundedCornerShape(8.dp),
        border = BorderStroke(1.dp, BaseballColors.border.copy(alpha = 0.45f)),
        modifier = modifier,
    ) {
        Text(
            text = text,
            color = BaseballColors.textSecondary,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp),
        )
    }
}

@Composable
private fun CatcherOptionSegment(
    label: String,
    selected: Boolean,
    enabled: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Surface(
        color = if (selected) BaseballColors.action.copy(alpha = 0.12f) else BaseballColors.surface,
        shape = RoundedCornerShape(10.dp),
        border = BorderStroke(if (selected) 2.dp else 1.dp, if (selected) BaseballColors.action else BaseballColors.border),
        modifier = modifier
            .heightIn(min = 44.dp)
            .clip(RoundedCornerShape(10.dp))
            .clickable(enabled = enabled, onClick = onClick)
            .semantics {
                role = Role.Button
                contentDescription = "$label ${if (selected) "선택됨" else "선택 가능"}"
            },
    ) {
        Box(contentAlignment = Alignment.Center, modifier = Modifier.fillMaxWidth().padding(vertical = 10.dp)) {
            Text(
                text = label,
                color = if (selected) BaseballColors.action else BaseballColors.textPrimary,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}
