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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color as ComposeColor
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
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
import com.solkim.baseball.application.PitchDelivery
import com.solkim.baseball.application.PitchKind
import com.solkim.baseball.application.PitchOutcome
import com.solkim.baseball.application.PitchZone
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
    private var selectedPitchIndex by mutableStateOf(0)
    private var selectedZone by mutableStateOf(PitchZone(1, 1))
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
                val settings = store.current.settings
                val dramaProgress = remember { Animatable(if (resultReady) 1f else 0f) }
                val composeScope = rememberCoroutineScope()

                // 투구 제출 시 드라마 애니메이션 실행
                LaunchedEffect(request, isDelivering) {
                    val saved = request
                    if (isDelivering && saved != null) {
                        dramaProgress.snapTo(0f)
                        val duration = if (settings.reducedMotionEnabled) 80 else 1600
                        val seed = moundSeed()

                        // 1. 릴리스 사운드 / 햅틱
                        platform().audioHaptics.presentNativeMarker("release", playbackSettings(), seed)

                        // 2. 컨택/포구 타이밍 사운드 / 햅틱 (46% 지점)
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

                        // 3. 궤적 비행 애니메이션 (1.6초 영화 같은 템포)
                        dramaProgress.animateTo(
                            targetValue = 1f,
                            animationSpec = tween(durationMillis = duration, easing = LinearEasing),
                        )

                        // 4. 완료 후 consume 커밋
                        consumeAfterAnimationComplete(saved)
                    }
                }

                val outcome = currentOutcome()
                val battedBall = currentBattedBall()
                val batSide = currentBatSide()

                val proSession = store.current.pro?.activePitch
                val hsSession = store.current.highSchool?.activePitch
                val currentInning = proSession?.context?.inning ?: hsSession?.context?.inning ?: 9
                val currentHalf = if (proSession?.game?.inningState?.half?.name == "TOP") "초" else "말"
                val inningText = "${currentInning}회$currentHalf"
                val balls = proSession?.context?.balls ?: hsSession?.context?.balls ?: 0
                val strikes = proSession?.context?.strikes ?: hsSession?.context?.strikes ?: 0
                val outs = proSession?.context?.outs ?: hsSession?.context?.outs ?: 0
                val scoreDiff = proSession?.context?.scoreDifferential ?: hsSession?.context?.scoreDifferential ?: 0
                val scoreText = when {
                    scoreDiff == 0 -> "동점"
                    scoreDiff > 0 -> "${scoreDiff}점 앞섬"
                    else -> "${-scoreDiff}점 뒤짐"
                }
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
                val situationText = when {
                    !runners.firstOccupied && !runners.secondOccupied && !runners.thirdOccupied -> "${outs}사 주자 없음"
                    runners.firstOccupied && runners.secondOccupied && runners.thirdOccupied -> "${outs}사 만루"
                    else -> {
                        val onBases = listOfNotNull(
                            "1루".takeIf { runners.firstOccupied },
                            "2루".takeIf { runners.secondOccupied },
                            "3루".takeIf { runners.thirdOccupied }
                        ).joinToString("·")
                        "${outs}사 $onBases"
                    }
                }
                val isClutch = strikes == 2 && (balls == 3 || outs == 2)
                val batter = proSession?.batter
                val batterName = batter?.name ?: if (hsSession != null) "고교 4번 타자" else "상대 타자"
                val isLeftBatter = (batter?.batSide ?: BatSide.RIGHT) == BatSide.LEFT
                val batterContact = batter?.contact ?: 55
                val batterDiscipline = batter?.discipline ?: 50
                val batterPower = batter?.power ?: 60
                val fatigue = store.current.pro?.fatigue ?: store.current.highSchool?.run?.fatigue ?: 0
                val leverage = proSession?.context?.leverage ?: hsSession?.context?.leverage ?: 500

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
                            title = if (store.current.pitch?.careerKind == PitchCareerKind.PRO) "프로 중요 경기" else "마운드 승부처",
                            subtitle = status,
                            leverage = leverage,
                            onBack = ::handleBack,
                        )

                        // 2. Scoreboard Bar
                        PitchScoreboardBar(
                            scoreText = scoreText,
                            scoreDiff = scoreDiff,
                            inningText = inningText,
                            balls = balls,
                            strikes = strikes,
                            outs = outs,
                            situationText = situationText,
                            fatigue = fatigue,
                        )

                        // 3. Scrollable Content
                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .verticalScroll(rememberScrollState())
                                .padding(horizontal = 16.dp, vertical = 10.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            // Matchup Card
                            PitchMatchupCard(
                                batterName = batterName,
                                isLeftBatter = isLeftBatter,
                                contact = batterContact,
                                discipline = batterDiscipline,
                                power = batterPower,
                            )

                            // 4. Dedicated 320dp Cinema Drama View
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(320.dp)
                                    .clip(RoundedCornerShape(16.dp))
                                    .background(BaseballColors.fieldNight)
                                    .border(1.dp, BaseballColors.border.copy(alpha = 0.5f), RoundedCornerShape(16.dp)),
                            ) {
                                PitchDramaView(
                                    request = request,
                                    outcome = outcome,
                                    battedBall = battedBall,
                                    fielding = null,
                                    batSide = batSide,
                                    progress = dramaProgress.value,
                                    modifier = Modifier.fillMaxSize(),
                                )

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

                            // 5. Result Card OR Pitch Controls
                            if (resultReady) {
                                PitchResultCard(
                                    outcome = outcome,
                                    battedBall = battedBall,
                                    velocityTenthsKph = request?.velocityDeciKph ?: selectedPitchVelocity(),
                                    delivery = lastDelivery,
                                    onReplay = {
                                        composeScope.launch {
                                            dramaProgress.snapTo(0f)
                                            dramaProgress.animateTo(1f, tween(1600, easing = LinearEasing))
                                        }
                                    },
                                    onPostgame = ::completeAndReturn,
                                )
                            } else {
                                PitchControlsCard(
                                    selectedPitchIndex = selectedPitchIndex,
                                    selectedZone = selectedZone,
                                    ready = !isDelivering,
                                    velocityTenthsKph = selectedPitchVelocity(),
                                    autoRelease = settings.autoReleaseEnabled,
                                    fatigue = fatigue,
                                    reduceMotion = settings.reducedMotionEnabled,
                                    hapticsEnabled = settings.hapticsEnabled,
                                    soundEnabled = settings.soundEnabled,
                                    tension = moundTension(),
                                    disturbanceSeed = moundSeed(),
                                    adverseEpisode = moundAdverseEpisode(),
                                    onSelectPitch = { selectedPitchIndex = it },
                                    onSelectZone = { selectedZone = it },
                                    onDeliver = ::submitSelectedPitch,
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
        lastDelivery = delivery
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
private fun PitchTopBar(
    title: String,
    subtitle: String,
    leverage: Int,
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
                    maxLines = 1,
                )
            }
            Spacer(Modifier.width(8.dp))
            if (leverage >= 700) {
                Surface(
                    shape = CircleShape,
                    color = BaseballColors.milestone.copy(alpha = 0.15f),
                    border = BorderStroke(1.dp, BaseballColors.milestone),
                    modifier = Modifier.padding(end = 8.dp),
                ) {
                    Text(
                        text = "결정적 순간",
                        color = BaseballColors.milestone,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                    )
                }
            }
            OutlinedButton(
                onClick = onBack,
                border = BorderStroke(1.dp, BaseballColors.border),
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                modifier = Modifier.height(36.dp),
            ) {
                Text("일시정지", color = BaseballColors.textSecondary, style = MaterialTheme.typography.labelSmall)
            }
        }
    }
}

@Composable
private fun PitchScoreboardBar(
    scoreText: String,
    scoreDiff: Int,
    inningText: String,
    balls: Int,
    strikes: Int,
    outs: Int,
    situationText: String,
    fatigue: Int,
) {
    val scoreTone = when {
        scoreDiff > 0 -> BaseballColors.positive
        scoreDiff < 0 -> BaseballColors.negative
        else -> BaseballColors.textPrimary
    }
    Surface(
        color = BaseballColors.surface,
        modifier = Modifier.fillMaxWidth(),
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
                        text = scoreText,
                        color = scoreTone,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Black,
                    )
                    Text(
                        text = inningText,
                        color = BaseballColors.textSecondary,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    PipGroup(label = "B", count = balls, max = 3, activeColor = BaseballColors.warning)
                    PipGroup(label = "S", count = strikes, max = 2, activeColor = BaseballColors.action)
                    PipGroup(label = "O", count = outs, max = 2, activeColor = BaseballColors.negative)
                }
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    text = situationText,
                    color = if ("만루" in situationText || "1루" in situationText || "2루" in situationText || "3루" in situationText)
                        BaseballColors.warning else BaseballColors.textSecondary,
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    text = "피로 $fatigue",
                    color = if (fatigue >= 70) BaseballColors.warning else BaseballColors.textTertiary,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
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
private fun PitchMatchupCard(
    batterName: String,
    isLeftBatter: Boolean,
    contact: Int,
    discipline: Int,
    power: Int,
) {
    Surface(
        color = BaseballColors.surfaceRaised,
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(1.dp, BaseballColors.border.copy(alpha = 0.4f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 10.dp),
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
                text = "컨택 $contact · 선구 $discipline · 파워 $power",
                color = BaseballColors.textSecondary,
                style = MaterialTheme.typography.bodySmall,
                fontFamily = FontFamily.Monospace,
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
    onReplay: () -> Unit,
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
    selectedPitchIndex: Int,
    selectedZone: PitchZone,
    ready: Boolean,
    velocityTenthsKph: Int,
    autoRelease: Boolean,
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
) {
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
            // 1. Pitch selection
            val kinds = listOf("직구", "슬라이더", "커브", "체인지업")
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                kinds.forEachIndexed { index, label ->
                    val isSelected = selectedPitchIndex == index
                    Surface(
                        color = if (isSelected) BaseballColors.action.copy(alpha = 0.18f) else BaseballColors.surfaceSoft,
                        shape = RoundedCornerShape(8.dp),
                        border = BorderStroke(if (isSelected) 1.5.dp else 1.dp, if (isSelected) BaseballColors.action else BaseballColors.border.copy(alpha = 0.5f)),
                        modifier = Modifier
                            .weight(1f)
                            .height(44.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .clickable(enabled = ready) { onSelectPitch(index) }
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

            // 2. Zone Picker (Strike Zone Grid)
            ZonePicker(selected = selectedZone, onSelect = onSelectZone, enabled = ready)

            // 3. Pitch Delivery Control (Core Slider Invariant)
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
    }
}

@Composable
private fun ZonePicker(
    selected: PitchZone,
    onSelect: (PitchZone) -> Unit,
    enabled: Boolean = true,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        repeat(3) { row ->
            Row(
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                repeat(3) { col ->
                    val zone = PitchZone(row, col)
                    val isSelected = zone == selected
                    Box(
                        modifier = Modifier
                            .size(width = 64.dp, height = 36.dp)
                            .clip(RoundedCornerShape(6.dp))
                            .background(
                                if (isSelected) BaseballColors.action.copy(alpha = 0.28f)
                                else BaseballColors.surfaceSoft
                            )
                            .border(
                                width = if (isSelected) 1.5.dp else 1.dp,
                                color = if (isSelected) BaseballColors.action else BaseballColors.border.copy(alpha = 0.45f),
                                shape = RoundedCornerShape(6.dp),
                            )
                            .clickable(enabled = enabled) { onSelect(zone) }
                            .semantics {
                                role = Role.Button
                                contentDescription = "코스 ${row + 1}행 ${col + 1}열 ${if (isSelected) "선택됨" else "선택 가능"}"
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        if (isSelected) {
                            Box(
                                modifier = Modifier
                                    .size(10.dp)
                                    .clip(CircleShape)
                                    .background(BaseballColors.action)
                            )
                        } else {
                            Box(
                                modifier = Modifier
                                    .size(4.dp)
                                    .clip(CircleShape)
                                    .background(BaseballColors.textTertiary.copy(alpha = 0.5f))
                            )
                        }
                    }
                }
            }
        }
    }
}
