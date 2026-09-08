package com.solkim.baseball.android

import com.solkim.baseball.application.GameAggregateState

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.activity.OnBackPressedCallback
import androidx.activity.compose.setContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.draw.alpha
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import com.solkim.baseball.android.LocalizedGameText as Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.derivedStateOf
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
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.res.stringResource
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
import com.solkim.baseball.application.PitchReleaseMeter
import com.solkim.baseball.application.PitchKind
import com.solkim.baseball.application.PitchOutcome
import com.solkim.baseball.application.PitchHudProjection
import com.solkim.baseball.application.PitchHudSelection
import com.solkim.baseball.application.PitchLiveResult
import com.solkim.baseball.application.PitchScoreboardModel
import com.solkim.baseball.application.PitchScoreboardProjection
import com.solkim.baseball.application.GameCopyArgument
import com.solkim.baseball.application.PitchRecommendation
import com.solkim.baseball.application.AvatarRole
import com.solkim.baseball.application.PitchZone
import com.solkim.baseball.application.PitchIntensity
import com.solkim.baseball.application.ZoneIntent
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
 * Compose native pitch host: 2-cut canvas drama plus the hold-to-release slider.
 */
@OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)
public class PitchActivity : ComponentActivity() {
    private lateinit var store: KotlinGameStore
    private lateinit var controller: Phase7VerticalController
    private lateinit var sessionId: String
    private lateinit var expectedRevision: String
    private var status by mutableStateOf("투구 준비 완료")
    private var pitchError by mutableStateOf<String?>(null)
    private var feedbackActive by mutableStateOf(false)
    private var advancingPitch by mutableStateOf(false)
    private var inspectingPitch by mutableStateOf(false)
    private var recentAdversePitch = false
    private var selectedSign by mutableStateOf<PitchHudSelection>(PitchHudSelection.Primary)
    private var selectedPitchIndex by mutableStateOf(0)
    private var selectedZone by mutableStateOf(PitchZone(1, 1))
    private var lastTargetZone by mutableStateOf<PitchZone?>(null)
    private var selectedIntent by mutableStateOf(ZoneIntent.EDGE)
    private var selectedIntensity by mutableStateOf(PitchIntensity.NORMAL)
    private var fastResults by mutableStateOf(false)
    private var holdCall by mutableStateOf(false)
    private var chromeExpanded by mutableStateOf(false)
    private var request by mutableStateOf<PitchPresentationRequest?>(null)
    private var lastDelivery by mutableStateOf<PitchDelivery?>(null)
    private var perfectStreak by mutableStateOf(0)
    private var practiceIntroductionAccepted by mutableStateOf(false)
    private var lastPitchLine by mutableStateOf<String?>(null)
    private var resultReady by mutableStateOf(false)
    private var isDelivering by mutableStateOf(false)
    private var clutchReplay by mutableStateOf(false)
    private var plateEnded by mutableStateOf(false)
    private var replayGeneration by mutableStateOf(0)
    private var confirmAbort by mutableStateOf(false)
    private var returningToShell = false
    private val activityScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putInt(PERFECT_STREAK_KEY, perfectStreak)
        outState.putBoolean("practice.introduction.accepted", practiceIntroductionAccepted)
    }

    private data class GrowthFeedback(val command: Int?, val velocities: Map<PitchKind, Int>)

    /** Compare with the last mound visit, so training growth survives intervening choices/saves. */
    private fun consumeGrowthOverlay(state: com.solkim.baseball.application.GameAggregateState): GrowthFeedback {
        if (state.pitch?.boundary !in setOf(PitchBoundary.RESERVED, PitchBoundary.PLAYING, PitchBoundary.SUSPENDED)) return GrowthFeedback(null, emptyMap())
        val pro = state.pitch?.careerKind == PitchCareerKind.PRO
        val career = if (pro) state.pro?.careerId else state.highSchool?.run?.careerId
        if (career == null) return GrowthFeedback(null, emptyMap())
        val current = PitchHudProjection.pitcher(state)
        val initial = if (pro) null else state.highSchool?.startingPitcher
        val preferences = getSharedPreferences("pitch.ui", MODE_PRIVATE)
        val prefix = "feel.$career"
        val revision = if (pro) state.pro?.revision else state.highSchool?.run?.revision
        val oldRevision = preferences.getString("$prefix.revision", null)?.toULongOrNull()
        val reset = oldRevision != null && revision != null && revision < oldRevision
        val beforeCommand = if (reset) initial?.command ?: current.command
            else preferences.getInt("$prefix.command", initial?.command ?: current.command)
        val velocities = current.pitchProfiles.orEmpty().mapNotNull { profile ->
            val initialVelocity = initial?.pitchProfiles?.firstOrNull { it.pitchType == profile.pitchType }?.velocityTenthsKph ?: profile.velocityTenthsKph
            val before = if (reset) initialVelocity else preferences.getInt("$prefix.velocity.${profile.pitchType.wire}", initialVelocity)
            if (before < profile.velocityTenthsKph) profile.pitchType to before else null
        }.toMap()
        preferences.edit().apply {
            putInt("$prefix.command", current.command)
            putString("$prefix.revision", revision?.toString())
            current.pitchProfiles.orEmpty().forEach { putInt("$prefix.velocity.${it.pitchType.wire}", it.velocityTenthsKph) }
        }.apply()
        return GrowthFeedback(beforeCommand.takeIf { com.solkim.baseball.application.PitchReleaseWindow.width(it) < com.solkim.baseball.application.PitchReleaseWindow.width(current.command) }, velocities)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        perfectStreak = savedInstanceState?.getInt(PERFECT_STREAK_KEY) ?: 0
        practiceIntroductionAccepted = savedInstanceState?.getBoolean("practice.introduction.accepted") ?: false
        if (BuildConfig.DEBUG && packageName.endsWith(".compose.qa")) {
            window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            val requestedRate = getSharedPreferences("launch-qa", MODE_PRIVATE).getInt("refresh-rate", 0)
            if (requestedRate in setOf(60, 120)) window.attributes = window.attributes.apply { preferredRefreshRate = requestedRate.toFloat() }
        }
        store = (application as BaseballApplication).gameStore
        controller = Phase7VerticalController(store)
        sessionId = intent.getStringExtra(EXTRA_SESSION_ID) ?: error("pitch.session_id_missing")
        expectedRevision = intent.getStringExtra(EXTRA_EXPECTED_REVISION) ?: error("pitch.revision_missing")
        if (!lookupSavedSession(expectedRevision)) {
            finish()
            return
        }
        holdCall = false
        fastResults = getSharedPreferences("pitch.ui", MODE_PRIVATE).getBoolean("fast.results", false)

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = handleBack()
        })

        loadSavedPresentationOrInput()

        setContent {
            val gameState by store.state.collectAsState()
            BaseballMigrationTheme(highContrast = gameState.settings.highContrastEnabled) {
                val settings = gameState.settings
                val awaitingPractice = needsPracticeIntroduction(gameState)
                if (awaitingPractice && pitchError == null) FirstPracticeIntroduction(autoRelease = settings.autoReleaseEnabled) {
                    practiceIntroductionAccepted = true
                }
                val dramaProgress = remember { Animatable(if (resultReady) 1f else 0f) }
                val composeScope = rememberCoroutineScope()
                val showStrikeout by remember { derivedStateOf { dramaProgress.value >= 0.7f } }
                val showHomeRun by remember { derivedStateOf { dramaProgress.value >= PitchDramaCamera.CUT_PROGRESS } }
                val replayInMotion by remember { derivedStateOf { dramaProgress.value < 1f } }

                var lastFeedbackKey by remember { mutableStateOf<String?>(null) }
                LaunchedEffect(request, replayGeneration, feedbackActive) {
                    val saved = request ?: return@LaunchedEffect
                    val key = "${saved.pitchId}:$replayGeneration"
                    if (!feedbackActive || key == lastFeedbackKey) return@LaunchedEffect
                    lastFeedbackKey = key
                    val perfect = lastDelivery?.isPerfectRelease == true
                    val duration = PitchDramaCamera.replayDurationMs(saved.flightDurationMs, settings.reducedMotionEnabled, clutchReplay, perfect)
                    val events = com.solkim.baseball.application.PitchFeedbackPlan.forState(store.current, duration, settings.reducedMotionEnabled, perfect, saved.velocityDeciKph)
                    val withHaptics = isDelivering
                    val sink = platform().audioHaptics
                    sink.stopEffects()
                    var elapsed = 0L
                    for (event in events) {
                        delay((event.delayMs - elapsed).coerceAtLeast(0))
                        if (!feedbackActive) break
                        sink.playPitchCue(event.cue, playbackSettings(), moundSeed(), if (withHaptics) event.haptic else null, gain = event.gain, rate = event.rate)
                        elapsed = event.delayMs
                    }
                }
                // Optional fast mode applies only to ordinary pitches, never a new batter or milestone.
                val mayAdvance = fastResults && lastDelivery != null && gameState.pitch?.careerKind != PitchCareerKind.TUTORIAL && !plateEnded && lastDelivery?.isPerfectRelease != true
                LaunchedEffect(resultReady, request?.pitchId, fastResults, inspectingPitch, feedbackActive, pitchError) {
                    val saved = request ?: return@LaunchedEffect
                    if (!mayAdvance || !resultReady || !feedbackActive || inspectingPitch || pitchError != null || !controller.canContinueOfficialPitch()) return@LaunchedEffect
                    delay(1_000L)
                    if (request?.pitchId == saved.pitchId && fastResults && !inspectingPitch && pitchError == null && !advancingPitch) continueInSession()
                }
                // 투구 제출 시 드라마 애니메이션 실행
                LaunchedEffect(request, isDelivering, replayGeneration) {
                    val saved = request
                    if ((isDelivering || (resultReady && replayGeneration > 0)) && saved != null) {
                        dramaProgress.snapTo(0f)
                        val perfect = lastDelivery?.isPerfectRelease == true
                        val duration = PitchDramaCamera.replayDurationMs(
                            saved.flightDurationMs,
                            settings.reducedMotionEnabled,
                            clutchReplay,
                            perfect,
                        )
                        // Perfect release: the ball hangs in the hand for a beat before it jumps.
                        if (perfect && !settings.reducedMotionEnabled) delay(com.solkim.baseball.application.PitchFeedbackPlan.PERFECT_HOLD_MS)
                        dramaProgress.animateTo(
                            targetValue = 1f,
                            animationSpec = tween(durationMillis = duration, easing = LinearEasing),
                        )

                        if (isDelivering) {
                            consumeAfterAnimationComplete(saved)
                        }
                    } else if (saved == null) {
                        dramaProgress.snapTo(0f)
                    }
                }

                val showingResult = request != null
                val outcome = if (showingResult) currentOutcome() else null
                val battedBall = if (showingResult) currentBattedBall() else null
                val fielding = if (showingResult) currentFielding() else null
                val batSide = currentBatSide()

                val board = remember(gameState) { PitchScoreboardProjection.model(gameState) }
                val balls = board.balls
                val strikes = board.strikes
                val outs = board.outs
                val isClutch = strikes == 2 && (balls == 3 || outs == 2)
                val hud = remember(gameState) { runCatching { PitchHudProjection.model(gameState) }.getOrNull() }
                val pitcherMovement = remember(gameState) { runCatching { PitchHudProjection.pitcher(gameState).movement }.getOrNull() }
                val growthFeedback = remember(sessionId) { consumeGrowthOverlay(gameState) }
                val previousCommand = if (lastPitchLine != null || lastDelivery != null) null else if (gameState.pitch?.careerKind == PitchCareerKind.TUTORIAL) gameState.meta.companion?.previousStart?.getOrNull(1) ?: growthFeedback.command else growthFeedback.command
                val previousVelocity = if (lastPitchLine != null || lastDelivery != null) null else growthFeedback.velocities[selectedPitchType()]
                val batter = hud?.batter
                val batterName = batter?.name ?: "상대 타자"
                val isLeftBatter = (batter?.batSide ?: BatSide.RIGHT) == BatSide.LEFT
                val batterContact = batter?.contact ?: 0
                val batterDiscipline = batter?.discipline ?: 0
                val batterPower = batter?.power ?: 0
                val fatigue = PitchHudProjection.fatigue(gameState)
                val practiceMode = gameState.pitch?.careerKind == PitchCareerKind.TUTORIAL
                val practiceStep = ((gameState.highSchool?.lastPresentation?.pitchNumber ?: 0) + if (isDelivering || resultReady) 0 else 1).coerceIn(1, 3)
                val leverage = gameState.pro?.activePitch?.context?.leverage
                    ?: gameState.highSchool?.activePitch?.context?.leverage
                    ?: if (gameState.pitch?.careerKind == PitchCareerKind.TUTORIAL) 200 else 500

                Surface(
                    modifier = Modifier.fillMaxSize().semantics { testTagsAsResourceId = true },
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
                            subtitle = "",
                            stakesLabel = hud?.stakesLabel ?: "중요도",
                            stakesValue = hud?.stakesValue ?: PitchHudProjection.stakesValue(leverage),
                            abortLabel = "나중에 이어하기",
                            onBack = { confirmAbort = true },
                        )

                        // 2. Scoreboard Bar
                        if (practiceMode) Text(rememberGameCopy().resolve("feedback.practice.step", GameCopyArgument.Whole(practiceStep.toLong())),
                            modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp).testTag("pitch.practice.step"), style = MaterialTheme.typography.titleMedium)
                        else PitchScoreboardBar(board, perfectStreak)

                        val watchingPitch = isDelivering || resultReady
                        val coachTip = hud?.coachTip

                        if (!practiceMode) Box(Modifier.padding(horizontal = 16.dp, vertical = 2.dp)) {
                            PitchCompactMatchup(batterName, batter?.batSide ?: BatSide.RIGHT,
                                hud?.adaptationBandLabel ?: "", onExpand = { chromeExpanded = true })
                        }
                        if (chromeExpanded) AlertDialog(
                            onDismissRequest = { chromeExpanded = false },
                            title = { Text(batterName, verbatim = true) },
                            text = {
                                Column(Modifier.heightIn(max = 420.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                    val rivalName = gameState.pro?.currentRival?.name ?: gameState.highSchool?.run?.rival?.name
                                    if (rivalName != null && rivalName == batterName) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                        PlayerPortrait(seed = rivalName, role = AvatarRole.RIVAL, width = 48.dp)
                                        Text("라이벌", color = BaseballColors.milestone, fontWeight = FontWeight.Bold)
                                    }
                                    Text(hud?.scenarioDetail ?: status)
                                    PitchMatchupCard(batterName, isLeftBatter,
                                        hud?.contactLabel ?: "공 맞히기", hud?.disciplineLabel ?: "볼 고르기",
                                        hud?.powerLabel ?: "장타력", batterContact, batterDiscipline, batterPower,
                                        hud?.adaptationTitle ?: "타자가 내 공을 읽는 정도", hud?.adaptationBandLabel ?: "",
                                        hud?.adaptationWarning ?: "", hud?.adaptationLevel ?: 0,
                                        onCollapse = { chromeExpanded = false })
                                    hud?.scoutingTitle?.takeIf { it.isNotBlank() }?.let { Text(it, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.labelMedium) }
                                    hud?.scoutingBody?.takeIf { it.isNotBlank() }?.let { Text(it, color = BaseballColors.textSecondary, style = MaterialTheme.typography.bodySmall) }
                                    hud?.scoutingAvoid?.takeIf { it.isNotBlank() }?.let { Text(it, color = BaseballColors.warning, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.SemiBold) }
                                    board.outingLine?.let { Text(it, style = MaterialTheme.typography.bodySmall) }
                                    hud?.catcherTrustLabel?.takeIf { it.isNotBlank() }?.let { Text(it, color = BaseballColors.textSecondary, style = MaterialTheme.typography.bodySmall) }
                                }
                            },
                            confirmButton = { TextButton(onClick = { chromeExpanded = false }) { Text("닫기") } },
                        )

                        if (watchingPitch) Box(
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
                                perfect = lastDelivery?.isPerfectRelease == true,
                                movement = pitcherMovement,
                                reduceMotion = settings.reducedMotionEnabled,
                            )

                            if (showingResult && plateEnded && outcome in setOf(PitchOutcome.SWINGING_STRIKE, PitchOutcome.CALLED_STRIKE) && showStrikeout) {
                                Text(
                                    text = "K",
                                    color = BaseballColors.milestone,
                                    style = MaterialTheme.typography.displaySmall,
                                    fontWeight = FontWeight.Black,
                                    modifier = Modifier
                                        .align(Alignment.CenterEnd)
                                        .padding(end = 20.dp)
                                        .gameDescription("삼진"),
                                )
                            }
                            if (showingResult && lastDelivery?.isPerfectRelease == true) {
                                Text(
                                    text = "퍼펙트 릴리스",
                                    color = BaseballColors.milestone,
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Black,
                                    modifier = Modifier
                                        .align(Alignment.TopCenter)
                                        .padding(top = 12.dp)
                                        .gameDescription("퍼펙트 릴리스"),
                                )
                            }
                            if (showingResult && outcome == PitchOutcome.HOME_RUN && showHomeRun) {
                                Text(
                                    text = "홈런",
                                    color = BaseballColors.milestone,
                                    style = MaterialTheme.typography.headlineSmall,
                                    fontWeight = FontWeight.Black,
                                    modifier = Modifier
                                        .align(Alignment.BottomEnd)
                                        .padding(16.dp)
                                        .gameDescription("홈런"),
                                )
                            }
                            if ((isClutch || clutchReplay) && replayInMotion) {
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

                        if (!isDelivering && resultReady) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp, vertical = 8.dp),
                                verticalArrangement = Arrangement.spacedBy(10.dp),
                            ) {
                                val outingContinues = hud?.canContinueInSession == true
                                PitchResultCard(
                                    outcome = outcome,
                                    battedBall = battedBall,
                                    velocityTenthsKph = request?.velocityDeciKph ?: 0,
                                    delivery = lastDelivery,
                                    perfect = lastDelivery?.isPerfectRelease == true,
                                    plateXMm = request?.plateXMm,
                                    plateYMm = request?.plateYMm,
                                    targetZone = lastTargetZone,
                                    practice = gameState.pitch?.careerKind == PitchCareerKind.TUTORIAL,
                                    onPracticeAgain = if (gameState.pitch?.careerKind == PitchCareerKind.TUTORIAL && (gameState.highSchool?.lastPresentation?.pitchNumber ?: 0) < 3) ({ finishPractice(true) }) else null,
                                    onPracticeSchool = { finishPractice(false) },
                                    practiceBusy = advancingPitch,
                                    outingContinues = outingContinues,
                                    automaticNext = mayAdvance && !inspectingPitch && pitchError == null,
                                    plateEnded = plateEnded,
                                    outingLine = board.outingLine,
                                    onInspect = { inspectingPitch = true },
                                    onReplay = { inspectingPitch = true; replayGeneration += 1 },
                                    onContinueInning = if (controller.canContinueInning()) ({ continueInSession(true) }) else null,
                                    onNextPitch = if (outingContinues) ({ continueInSession() }) else null,
                                    onPostgame = ::completeAndReturn,
                                )
                            }
                        } else if (!isDelivering) {
                            Column(
                                modifier = Modifier
                                    .weight(1f).fillMaxWidth()
                                    .padding(horizontal = 16.dp, vertical = 8.dp),
                                verticalArrangement = Arrangement.spacedBy(10.dp),
                            ) {
                                val repertoire = hud?.repertoire.orEmpty()
                                val chosenCall = runCatching { PitchHudProjection.resolveCall(store.current, selectedSign) }.getOrNull()
                                PitchControlsCard(
                                    practice = gameState.pitch?.careerKind == PitchCareerKind.TUTORIAL,
                                    practiceStep = practiceStep,
                                    signaturePitch = gameState.meta.companion?.representative,
                                    signatureName = gameState.meta.companion?.nickname.orEmpty(),
                                    lastPitchLine = lastPitchLine,
                                    coachTip = coachTip,
                                    repertoire = repertoire,
                                    primary = hud?.preparation?.primaryRecommendation,
                                    alternative = hud?.preparation?.alternativeRecommendation,
                                    selection = selectedSign,
                                    selectedZone = selectedCallZone(hud),
                                    selectedIntent = chosenCall?.zoneIntent ?: selectedIntent,
                                    selectedIntensity = chosenCall?.intensity ?: selectedIntensity,
                                    batSide = batter?.batSide ?: BatSide.RIGHT,
                                    currentPitchLine = hud?.currentPitchLine ?: "",
                                    primaryExplanation = hud?.primaryExplanation ?: "",
                                    holdToReleasePrompt = hud?.holdToReleasePrompt ?: stringResource(R.string.pitch_hold_to_release),
                                    ready = repertoire.isNotEmpty() && !awaitingPractice,
                                    velocityTenthsKph = selectedPitchVelocity(),
                                    commandRating = runCatching { PitchHudProjection.pitcher(store.current).command }.getOrDefault(35) + tutorialCommandAssist(gameState),
                                    previousCommand = previousCommand,
                                    previousVelocity = previousVelocity,
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
                                                persistHoldCall(true)
                                            }
                                            PitchHudSelection.Primary -> {
                                                hud?.preparation?.primaryRecommendation?.call?.let { call ->
                                                    selectedZone = call.zone
                                                    selectedIntent = call.zoneIntent
                                                    selectedIntensity = call.intensity
                                                }
                                                persistHoldCall(false)
                                            }
                                            PitchHudSelection.Alternative -> {
                                                hud?.preparation?.alternativeRecommendation?.call?.let { call ->
                                                    selectedZone = call.zone
                                                    selectedIntent = call.zoneIntent
                                                    selectedIntensity = call.intensity
                                                }
                                                persistHoldCall(false)
                                            }
                                        }
                                    },
                                    onDeliver = ::submitSelectedPitch,
                                    onHoldCallChange = { enabled ->
                                        persistHoldCall(enabled)
                                        if (!enabled) {
                                            selectedSign = PitchHudSelection.Primary
                                            hud?.preparation?.primaryRecommendation?.call?.let { call ->
                                                selectedZone = call.zone
                                                selectedIntent = call.zoneIntent
                                                selectedIntensity = call.intensity
                                            }
                                        }
                                    },
                                    onFastForward = ::fastForwardCurrentBatter,
                                    onAutoReleaseChange = { enabled -> persistPitchSettings { it.copy(autoReleaseEnabled = enabled) } },
                                    onHapticsChange = { enabled -> persistPitchSettings { it.copy(hapticsEnabled = enabled) } },
                                    fastResults = fastResults,
                                    onFastResultsChange = { enabled ->
                                        fastResults = enabled
                                        getSharedPreferences("pitch.ui", MODE_PRIVATE).edit().putBoolean("fast.results", enabled).apply()
                                    },
                                )
                            }
                        }
                    }
                }
                pitchError?.let { message ->
                    val copy = rememberGameCopy()
                    AlertDialog(modifier = Modifier.semantics { testTagsAsResourceId = true },
                        onDismissRequest = { pitchError = null },
                        title = { Text(copy.resolve("settings2.error-title"), verbatim = true) },
                        text = { Text(message, modifier = Modifier.testTag("pitch.error")) },
                        confirmButton = { TextButton(onClick = { pitchError = null }, modifier = Modifier.testTag("pitch.error.close")) {
                            Text(copy.resolve("settings2.close"), verbatim = true)
                        } })
                }
                if (confirmAbort) {
                    AlertDialog(
                        onDismissRequest = { confirmAbort = false },
                        title = { Text("저장하고 나갈까요?") },
                        text = { Text("이 타석은 그대로 남는다. 언제든 이어서 던질 수 있다.") },
                        confirmButton = {
                            TextButton(
                                onClick = {
                                    confirmAbort = false
                                    handleBack()
                                },
                            ) { Text("나가기") }
                        },
                        dismissButton = {
                            TextButton(onClick = { confirmAbort = false }) { Text("계속 던지기") }
                        },
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
            selectedSign = PitchHudSelection.Primary
            selectedZone = PitchZone(1, 1)
        }
        expectedRevision = nextRevision
        returningToShell = false
        resultReady = false
        isDelivering = false
        request = null
        if (!lookupSavedSession(expectedRevision)) return
        status = "이어서 던질 준비가 됐습니다."
        loadSavedPresentationOrInput()
    }

    override fun onResume() {
        super.onResume()
        feedbackActive = true
        if (::store.isInitialized) {
            platform().audioHaptics.preparePitchSounds()
        }
    }

    override fun onPause() {
        feedbackActive = false
        if (::store.isInitialized) platform().audioHaptics.pauseForLifecycle()
        super.onPause()
    }

    override fun onDestroy() {
        activityScope.cancel()
        super.onDestroy()
    }

    private fun showPitchError(message: String) { status = message; pitchError = message }

    private fun persistPitchSettings(transform: (com.solkim.baseball.application.GameSettingsState) -> com.solkim.baseball.application.GameSettingsState) {
        activityScope.launch {
            try { controller.updateSettings(transform(store.current.settings)) }
            catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled }
            catch (error: Exception) {
                Log.e(TAG, "Pitch setting save failed", error)
                runCatching { store.reconcilePersistedRevision() }
                withContext(Dispatchers.Main) { showPitchError("설정을 저장하지 못했어요. 다시 시도해 주세요.") }
            }
        }
    }

    private fun persistHoldCall(enabled: Boolean) {
        activityScope.launch {
            try {
                controller.setPitchHoldCall(enabled)
                withContext(Dispatchers.Main) { holdCall = enabled }
            } catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled }
            catch (error: Exception) {
                Log.e(TAG, "Pitch call preference save failed", error)
                withContext(Dispatchers.Main) { showPitchError("설정을 저장하지 못했어요. 다시 시도해 주세요.") }
            }
        }
    }

    private fun lookupSavedSession(expected: String): Boolean {
        val revision = expected.toULongOrNull() ?: run {
            showPitchError("투구 상태를 다시 확인해 주세요.")
            return false
        }
        val pitch = store.state.value.pitch
        val valid = pitch != null && pitch.sessionId == sessionId && store.state.value.revision == revision
        if (!valid) {
            showPitchError("투구 상태를 다시 확인해 주세요.")
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
                            status = if (resultReady) "투구 결과를 확인해 보세요." else "투구 준비 완료"
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
                        status = "이번 투구를 마쳤습니다."
                    }
                }
            } catch (error: Throwable) {
                withContext(Dispatchers.Main) { showPitchError("투구를 불러오지 못했습니다. 다시 시도해 주세요.") }
            }
        }
    }

    private fun needsPracticeIntroduction(state: GameAggregateState): Boolean =
        !practiceIntroductionAccepted && state.pitch?.careerKind == PitchCareerKind.TUTORIAL &&
            state.highSchool?.run?.lifeNumber == 1 && state.highSchool?.lastPresentation == null && request == null

    private fun submitSelectedPitch(delivery: PitchDelivery) {
        if (isDelivering || resultReady || needsPracticeIntroduction(store.current)) return
        val deliveredSelection = selectedSign
        lastTargetZone = runCatching { PitchHudProjection.resolveCall(store.current, deliveredSelection).zone }.getOrNull()
        val manualRelease = !store.current.settings.autoReleaseEnabled
        isDelivering = true
        lastDelivery = delivery
        perfectStreak = if (delivery.isPerfectRelease) perfectStreak + 1 else 0
        val board = PitchScoreboardProjection.model(store.current)
        val preBalls = board.balls
        val preStrikes = board.strikes
        clutchReplay = preStrikes == 2 && (preBalls == 3 || board.outs == 2)
        activityScope.launch {
            try {
                withContext(Dispatchers.Main) {
                    resultReady = false
                    request = null
                    isDelivering = true
                    status = "공이 날아갑니다…"
                }
                val saved = controller.submitPitch(
                    sessionId = sessionId,
                    selection = deliveredSelection,
                    delivery = delivery,
                )
                if (manualRelease) {
                    // Telemetry failure must never turn an already saved pitch into a retry.
                    runCatching {
                        store.dispatch(com.solkim.baseball.application.GameCommandEnvelope(
                            "manual-release:${saved.pitchId}", "native-pitch", store.current.revision,
                            com.solkim.baseball.application.GameCommand.RecordAnalytics(
                                "manual-release:${saved.pitchId}", "manual_pitch_released_v2",
                                listOf("release_accuracy" to delivery.releaseAccuracy.toString(), "aim_accuracy" to delivery.aimAccuracy.toString())
                            )
                        ))
                    }
                }
                withContext(Dispatchers.Main) {
                    recentAdversePitch = currentOutcome() in adverseOutcomes || (currentOutcome() == PitchOutcome.BALL && preBalls == 3)
                    request = saved
                    plateEnded = plateAppearanceEnds(currentOutcome(), preBalls, preStrikes)
                }
            } catch (error: Throwable) {
                Log.e(TAG, "submitPitch error: ${error.javaClass.name}: ${error.message}", error)
                withContext(Dispatchers.Main) {
                    isDelivering = false
                    showPitchError("투구를 저장하지 못했습니다. 다시 시도해 주세요.")
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
                    status = "투구 결과를 확인해 보세요."
                }
            } catch (error: Throwable) {
                withContext(Dispatchers.Main) {
                    isDelivering = false
                    showPitchError("투구를 저장하지 못했습니다. 다시 시도해 주세요.")
                }
            }
        }
    }

    private fun finishPractice(repeat: Boolean) {
        if (advancingPitch) return
        advancingPitch = true
        activityScope.launch {
            try {
                val result = com.solkim.baseball.application.Phase8Controller(store).finishPractice(sessionId, repeat)
                withContext(Dispatchers.Main) {
                    returningToShell = true
                    val launch = result.launch
                    if (launch != null) startActivity(intent(this@PitchActivity, launch.sessionId, launch.expectedRevision.toString()))
                    else startActivity(Intent(this@PitchActivity, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT))
                    finish()
                }
            } catch (error: Throwable) {
                withContext(Dispatchers.Main) {
                    advancingPitch = false
                    showPitchError("경기 결과를 저장하지 못했습니다. 다시 시도해 주세요.")
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
                    startActivity(Intent(this@PitchActivity, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT))
                    finish()
                }
            } catch (error: Throwable) {
                withContext(Dispatchers.Main) { showPitchError("경기 결과를 저장하지 못했습니다. 다시 시도해 주세요.") }
            }
        }
    }

    private fun continueInSession(continueOuting: Boolean = false) {
        if (advancingPitch || !feedbackActive) return
        advancingPitch = true
        // Read the finished pitch before the store moves on to the next session.
        val finishedLine = listOfNotNull(
            currentOutcome()?.let { localizedVerdict(it, currentBattedBall()) },
            lastDelivery?.let { releaseTimingLabel(it.releaseAccuracy, it.aimAccuracy) },
        ).joinToString(" · ").ifBlank { null }
        activityScope.launch {
            try {
                if (continueOuting) controller.continueInning()
                controller.completePitchAndPostgame(sessionId)
                val launch = controller.continueOfficialPitch()
                withContext(Dispatchers.Main) {
                    if (launch == null) {
                        returningToShell = true
                        startActivity(Intent(this@PitchActivity, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT))
                        finish()
                    } else {
                        sessionId = launch.sessionId
                        expectedRevision = launch.expectedRevision.toString()
                        lastPitchLine = finishedLine
                        resultReady = false
                        inspectingPitch = false
                        isDelivering = false
                        request = null
                        lastDelivery = null
                        clutchReplay = false
                        plateEnded = false
                        replayGeneration = 0
                        selectedSign = PitchHudSelection.Primary
                        persistHoldCall(holdCall)
                        status = "다음 타석 · 포수 사인을 보고 던지세요"
                    }
                }
            } catch (error: Throwable) {
                withContext(Dispatchers.Main) { showPitchError("다음 타석을 준비하지 못했습니다. 다시 시도해 주세요.") }
            } finally { withContext(Dispatchers.Main) { advancingPitch = false } }
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
                    showPitchError("진행을 마치지 못했습니다. 다시 시도해 주세요.")
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
                    startActivity(Intent(this@PitchActivity, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT))
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
        val pro = state.pro?.takeIf { pitch?.careerKind == PitchCareerKind.PRO }
        val hsSession = hs?.activePitch?.takeIf { pitch?.careerKind == PitchCareerKind.HIGH_SCHOOL }
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
        val fatigue = PitchHudProjection.fatigue(state)
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
        return recentAdversePitch || last in adverseOutcomes
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

    private fun selectedPitchVelocity(): Int = runCatching {
        val state = store.current
        val call = PitchHudProjection.resolveCall(state, selectedSign)
        com.solkim.baseball.core.pitch.PitchAbilityRules.expectedVelocity(
            PitchHudProjection.pitcher(state), call, PitchHudProjection.fatigue(state),
            (state.highSchool?.activePitch?.sessionId ?: state.pro?.activePitch?.sessionId).orEmpty().endsWith(":outing-v2"))
    }.getOrDefault(1_350)

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
        private const val TAG = "PitchActivity"
        private const val PERFECT_STREAK_KEY = "pitch.perfectStreak"
        private const val GROWTH_SHOWN_KEY = "pitch.growthShown"
        public const val EXTRA_SESSION_ID: String = "com.solkim.baseball.android.SESSION_ID"
        public const val EXTRA_EXPECTED_REVISION: String = "com.solkim.baseball.android.EXPECTED_REVISION"

        public fun intent(context: Context, sessionId: String, expectedRevision: String): Intent =
            Intent(context, PitchActivity::class.java).apply {
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
                if (subtitle.isNotBlank()) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = BaseballColors.textTertiary,
                    maxLines = 2,
                )
                }
            }
            Spacer(Modifier.width(8.dp))
            OutlinedButton(
                onClick = onBack,
                border = BorderStroke(1.dp, BaseballColors.border),
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                modifier = Modifier.heightIn(min = 44.dp),
            ) {
                Text(abortLabel, color = BaseballColors.textSecondary, style = MaterialTheme.typography.labelSmall)
            }
        }
    }
}

@Composable
private fun PitchScoreboardBar(board: PitchScoreboardModel, perfectStreak: Int = 0) {
    val copy = rememberGameCopy()
    val inningText = if (copy.language == com.solkim.baseball.application.GameLanguage.KOREAN) board.inningText else
        copy.resolve("android.pitch.inning", com.solkim.baseball.application.GameCopyArgument.Whole(board.inning.toLong()))
    val spokenScore = board.accessibilityLabel.split(", ").joinToString(", ") { if (it == board.inningText) inningText else copy.legacy(it) }
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
            .gameDescription(spokenScore),
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
                        text = inningText,
                        color = BaseballColors.textSecondary,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    PipGroup(label = "OUT", count = board.outs, max = 2, activeColor = BaseballColors.negative)
                }
                if (perfectStreak > 0) {
                    Text(
                        text = if (perfectStreak >= 2) "★ 퍼펙트 ${perfectStreak}연속" else "★ 퍼펙트",
                        color = BaseballColors.milestone,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Black,
                        modifier = Modifier.testTag("pitch.perfectStreak"),
                    )
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
                    overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                )
                Text(
                    text = "피로 ${board.fatigue}",
                    color = if (board.fatigue >= 70) BaseballColors.warning else BaseballColors.textTertiary,
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
    onCollapse: (() -> Unit)? = null,
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
                    modifier = Modifier.weight(1f),
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
                    modifier = Modifier.weight(1f),
                )
                if (onCollapse != null) {
                    Text(
                        text = "접기",
                        color = BaseballColors.action,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier
                            .clickable(onClick = onCollapse)
                            .padding(start = 8.dp)
                            .gameDescription("타자 정보 접기"),
                    )
                }
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
private fun PitchCoachStrip(label: String, tip: String, modifier: Modifier = Modifier) {
    Surface(
        color = BaseballColors.surfaceRaised,
        shape = RoundedCornerShape(10.dp),
        modifier = modifier.fillMaxWidth(),
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
internal fun PitchResultCard(
    practice: Boolean = false,
    onPracticeAgain: (() -> Unit)? = null,
    onPracticeSchool: () -> Unit = {},
    practiceBusy: Boolean = false,
    outcome: PitchOutcome?,
    battedBall: BattedBall?,
    velocityTenthsKph: Int,
    delivery: PitchDelivery?,
    perfect: Boolean = false,
    plateXMm: Int?,
    plateYMm: Int?,
    targetZone: PitchZone? = null,
    outingContinues: Boolean,
    plateEnded: Boolean,
    outingLine: String?,
    onReplay: () -> Unit,
    onInspect: () -> Unit,
    automaticNext: Boolean = false,
    onNextPitch: (() -> Unit)?,
    onPostgame: () -> Unit,
    onContinueInning: (() -> Unit)? = null,
) {
    val tone = outcomeTone(outcome)
    val verdictTitle = outcome?.let { localizedVerdict(it, battedBall) } ?: "투구 완료"
    val nextLabel = when { !outingContinues -> "등판 마치기"; plateEnded -> "다음 타자"; else -> "다음 공" }
    var details by remember { mutableStateOf(false) }
    Surface(color = BaseballColors.surfaceRaised, shape = RoundedCornerShape(16.dp),
        border = BorderStroke(1.dp, tone.copy(alpha = 0.6f)), modifier = Modifier.fillMaxWidth().gameDescription("투구 결과 $verdictTitle")) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(verdictTitle, modifier = Modifier.weight(1f), style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = tone)
                Text("${velocityTenthsKph / 10}.${velocityTenthsKph % 10} km/h", color = if (perfect) BaseballColors.milestone else BaseballColors.action, fontWeight = FontWeight.Bold)
            }
            if (perfect && !practice) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.testTag("pitch.perfectStamp")) {
                    Surface(color = BaseballColors.milestone, shape = RoundedCornerShape(6.dp)) {
                        Text("★ 퍼펙트", color = BaseballColors.fieldNight, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Black, modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp))
                    }
                    Text(perfectCatcherLine(outcome), color = BaseballColors.textSecondary, style = MaterialTheme.typography.bodySmall, modifier = Modifier.weight(1f))
                }
            }
            delivery?.let { Text(releaseTimingLabel(it.releaseAccuracy, it.aimAccuracy), color = if (it.releaseAccuracy >= 820 && it.aimAccuracy >= 650) BaseballColors.action else BaseballColors.warning) }
            if (plateXMm != null && plateYMm != null) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    PitchPlateFeedback(plateXMm, plateYMm, targetZone)
                    Column(Modifier.weight(1f)) {
                        Text("공이 지나간 곳", style = MaterialTheme.typography.labelMedium)
                        plateLocationLine(plateXMm, plateYMm)?.let { Text(it, style = MaterialTheme.typography.bodySmall, modifier = Modifier.testTag("pitch.plateLocation")) }
                    }
                }
            }
            if (practice) {
                val copy = rememberGameCopy()
                Text(practiceFeedback(delivery),
                    style = MaterialTheme.typography.bodyLarge, modifier = Modifier.testTag("pitch.practiceReaction"))
                AdaptiveActionRow(Modifier.fillMaxWidth()) {
                    onPracticeAgain?.let { again ->
                        OutlinedButton(onClick = again, enabled = !practiceBusy, modifier = Modifier.heightIn(min = 52.dp).testTag("pitch.practiceAgain")) {
                            Text(copy.resolve("android.onboarding.again"))
                        }
                    }
                    Button(onClick = onPracticeSchool, enabled = !practiceBusy, modifier = Modifier.heightIn(min = 52.dp).testTag("pitch.practiceSchool")) {
                        Text(copy.resolve("android.onboarding.choose-school"))
                    }
                }
            } else if (onContinueInning != null) {
                Text("이닝을 마쳤어요. 계속 던질까요?", style = MaterialTheme.typography.bodyMedium)
                AdaptiveActionRow(Modifier.fillMaxWidth()) {
                    Button(onClick = onContinueInning, modifier = Modifier.testTag("pitch.nextInning")) { Text("다음 이닝") }
                    OutlinedButton(onClick = onPostgame, modifier = Modifier.testTag("pitch.simulateRemainder")) { Text("남은 경기 자동") }
                }
            } else if (!automaticNext) Button(onClick = if (outingContinues) (onNextPitch ?: onPostgame) else onPostgame,
                modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp).testTag("pitch.continue")) { Text(nextLabel) }
            AdaptiveActionRow(Modifier.fillMaxWidth()) {
                TextButton(onClick = onReplay, modifier = Modifier.testTag("pitch.replay")) { Text("투구 다시 보기") }
                if (!practice) TextButton(onClick = { onInspect(); details = true }, modifier = Modifier.testTag("pitch.resultDetails")) { Text("자세히") }
            }
        }
    }
    if (details) AlertDialog(onDismissRequest = { details = false }, title = { Text(verdictTitle) },
        text = {
            Column(Modifier.heightIn(max = 420.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(practiceFeedback(delivery))
                plateLocationLine(plateXMm, plateYMm)?.let { Text(it) }
                if (!outingContinues && !practice) Text(outingLine ?: "이번 등판은 여기까지.")
                if (outingContinues) TextButton(onClick = onPostgame) { Text("잠시 나가기") }
            }
        }, confirmButton = { TextButton(onClick = { details = false }) { Text("닫기") } })
}


private fun plateAppearanceEnds(outcome: PitchOutcome?, balls: Int, strikes: Int): Boolean = when (outcome) {
    PitchOutcome.SWINGING_STRIKE, PitchOutcome.CALLED_STRIKE -> strikes >= 2
    PitchOutcome.BALL -> balls >= 3
    PitchOutcome.HIT_BY_PITCH,
    PitchOutcome.IN_PLAY_OUT,
    PitchOutcome.SINGLE,
    PitchOutcome.DOUBLE,
    PitchOutcome.TRIPLE,
    PitchOutcome.HOME_RUN -> true
    PitchOutcome.FOUL, null -> false
}

/**
 * Where the ball crossed the plate. The zone is 500mm each way from the middle, and only this
 * crossing point decides ball or strike, so a breaking ball that sweeps across the box mid-flight
 * can still miss. The card says which way and by how much.
 */
internal fun plateLocationLine(plateXMm: Int?, plateYMm: Int?): String? {
    if (plateXMm == null || plateYMm == null) return null
    val sideMiss = kotlin.math.abs(plateXMm) - 500
    val heightMiss = kotlin.math.abs(plateYMm) - 500
    if (sideMiss <= 0 && heightMiss <= 0) return "존 안 · 홈플레이트를 지날 때 존 안이었다"
    val centimetres = { millimetres: Int -> kotlin.math.max(1, (millimetres + 5) / 10) }
    return when {
        sideMiss >= heightMiss -> "존 밖 · 옆으로 ${centimetres(sideMiss)}cm 벗어났다"
        plateYMm > 0 -> "존 밖 · 위로 ${centimetres(heightMiss)}cm 벗어났다"
        else -> "존 밖 · 아래로 ${centimetres(heightMiss)}cm 벗어났다"
    }
}

/** The catcher's one line after a perfect release — the feel is separate from the outcome. */
private fun perfectCatcherLine(outcome: PitchOutcome?): String = when (outcome) {
    PitchOutcome.SWINGING_STRIKE, PitchOutcome.CALLED_STRIKE -> "포수: 미트가 울렸다. 그 공이다."
    PitchOutcome.BALL -> "포수: 손끝은 완벽했다. 코스만 다시."
    PitchOutcome.FOUL -> "포수: 릴리스는 완벽했다. 한 번 더."
    PitchOutcome.IN_PLAY_OUT -> "포수: 완벽한 공. 야수가 마무리했다."
    PitchOutcome.HIT_BY_PITCH, PitchOutcome.SINGLE, PitchOutcome.DOUBLE, PitchOutcome.TRIPLE, PitchOutcome.HOME_RUN -> "포수: 릴리스는 완벽했다. 맞은 건 상대 몫."
    null -> "포수: 그 감각을 기억해."
}

/** Tutorial third pitch only: a wider window so the beginner meets the green once. Practice, never recorded. */
internal fun tutorialCommandAssist(state: com.solkim.baseball.application.GameAggregateState): Int =
    if (state.pitch?.careerKind == PitchCareerKind.TUTORIAL && state.highSchool?.lastPresentation?.pitchNumber == 2) 15 else 0

/** The 제구 value before the latest growth of this career, so the first pitch can show the old window. */
internal fun previousCommandAfterGrowth(state: com.solkim.baseball.application.GameAggregateState): Int? {
    val careerId = state.pro?.careerId ?: state.highSchool?.run?.careerId ?: return null
    val growth = state.meta.playerGrowth ?: return null
    if (growth.careerId != careerId || growth.before.size < 2 || growth.after.size < 2) return null
    return growth.before[1].takeIf { it < growth.after[1] }
}

private fun resultCommentary(outcome: PitchOutcome?): String = when (outcome) {
    PitchOutcome.SWINGING_STRIKE -> "배트가 허공을 갈랐다"
    PitchOutcome.CALLED_STRIKE -> "존 구석에 꽂혔다"
    PitchOutcome.BALL -> "존을 살짝 벗어났다"
    PitchOutcome.FOUL -> "빗맞았다. 다시"
    PitchOutcome.HIT_BY_PITCH -> "몸에 맞았다"
    PitchOutcome.IN_PLAY_OUT -> "야수 정면. 잡았다"
    PitchOutcome.SINGLE -> "빈틈을 뚫렸다"
    PitchOutcome.DOUBLE -> "장타. 주자가 뛴다"
    PitchOutcome.TRIPLE -> "외야 깊숙이. 3루까지"
    PitchOutcome.HOME_RUN -> "담장을 넘겼다"
    null -> ""
}

@Composable
@OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)
internal fun PitchControlsCard(
    practice: Boolean = false,
    practiceStep: Int = 1,
    signaturePitch: String? = null,
    signatureName: String = "",
    lastPitchLine: String?,
    coachTip: String?,
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
    commandRating: Int,
    previousCommand: Int? = null,
    previousVelocity: Int? = null,
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
    onHapticsChange: (Boolean) -> Unit = {},
    fastResults: Boolean = false,
    onFastResultsChange: (Boolean) -> Unit = {},
) {
    var aimingLocked by remember { mutableStateOf(false) }
    val choose: (PitchHudSelection) -> Unit = { if (ready && !aimingLocked) onSelect(it) }
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
    }.orEmpty().let { if (selection is PitchHudSelection.Manual) "" else it.ifBlank { primaryExplanation } }
    var rationaleOpen by remember { mutableStateOf(false) }
    var settingsOpen by remember { mutableStateOf(false) }
    var hapticTestAccepted by remember { mutableStateOf<Boolean?>(null) }
    val copy = rememberGameCopy()
    val controlsView = LocalView.current
    Surface(
        color = BaseballColors.surfaceRaised,
        shape = RoundedCornerShape(16.dp),
        border = BorderStroke(1.dp, BaseballColors.border.copy(alpha = 0.4f)),
        modifier = Modifier.fillMaxSize(),
    ) {
        Column(Modifier.fillMaxSize().padding(4.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            // The core choices come first. Scrolling is a fallback for accessibility text sizes.
            Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).testTag("pitch.choices"), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                PitchTypeChoices(repertoire, selectedType, ready && !aimingLocked, signaturePitch, signatureName) { type ->
                    if (hapticsEnabled) controlsView.pitchTouchFeedback(android.view.HapticFeedbackConstants.CLOCK_TICK, hapticsEnabled)
                    choose(PitchHudSelection.Manual(type, selectedZone, selectedIntent, selectedIntensity))
                }
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(PitchHudProjection.zoneLabel(selectedZone, batSide), modifier = Modifier.weight(1f).testTag("pitch.selected-zone.${selectedZone.row}.${selectedZone.column}"),
                        style = MaterialTheme.typography.labelMedium, color = BaseballColors.action)
                    CatcherOptionSegment(copy.resolve("compact.pitch.sign"), selection is PitchHudSelection.Primary, ready && !aimingLocked,
                        modifier = Modifier.widthIn(min = 48.dp).testTag("pitch.recommendation")) { choose(PitchHudSelection.Primary) }
                    if (alternative != null) CatcherOptionSegment(copy.resolve("compact.pitch.alternative"), selection is PitchHudSelection.Alternative, ready && !aimingLocked,
                        modifier = Modifier.widthIn(min = 48.dp).testTag("pitch.alternative")) { choose(PitchHudSelection.Alternative) }
                    TextButton(onClick = { settingsOpen = true }, contentPadding = PaddingValues(horizontal = 4.dp), modifier = Modifier.testTag("pitch.settings")) { Text("설정", style = MaterialTheme.typography.labelMedium) }
                }
                PitchZoneGrid(selected = selectedZone, recommended = primary?.call?.zone, enabled = ready && !aimingLocked, showsLabels = false) { zone ->
                    choose(PitchHudSelection.Manual(selectedType ?: repertoire.firstOrNull() ?: PitchKind.FOUR_SEAM, zone, selectedIntent, selectedIntensity))
                }
                PitchEffortControl(selectedIntensity, primary?.call?.intensity, ready && !aimingLocked,
                    expectedVelocity = velocityTenthsKph, compact = true, onChange = { intensity ->
                        if (hapticsEnabled) controlsView.pitchTouchFeedback(android.view.HapticFeedbackConstants.CLOCK_TICK, hapticsEnabled)
                        choose(PitchHudSelection.Manual(selectedType ?: repertoire.firstOrNull() ?: PitchKind.FOUR_SEAM, selectedZone, selectedIntent, intensity))
                    })
            }
            PitchDeliveryControl(
                autoRelease = autoRelease,
                enabled = ready,
                holdPrompt = copy.resolve("compact.pitch.hold"),
                compact = true,
                onDeliver = onDeliver,
                onPressingChange = { aimingLocked = it },
                velocityTenthsKph = velocityTenthsKph,
                fatigue = fatigue,
                commandRating = commandRating,
                previousCommand = previousCommand,
                previousVelocity = previousVelocity,
                holdComparison = practice && previousCommand != null,
                reduceMotion = reduceMotion,
                hapticsEnabled = hapticsEnabled,
                soundEnabled = soundEnabled,
                tension = tension,
                disturbanceSeed = disturbanceSeed,
                adverseEpisode = adverseEpisode,
                pitchTypeLabel = PitchHudProjection.koreanLabel(selectedType ?: PitchKind.FOUR_SEAM),
                onAutoReleaseChange = null,
                autoReleaseLabel = autoReleaseLabel,
            )
        }
    }
    if (settingsOpen) {
        AlertDialog(
            modifier = Modifier.semantics { testTagsAsResourceId = true },
            onDismissRequest = { settingsOpen = false },
            title = { Text("조작 설정") },
            text = {
                Column(Modifier.fillMaxWidth().heightIn(max = 480.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(selectedPitchLine, style = MaterialTheme.typography.titleMedium)
                    if (selectedReason.isNotBlank()) Text(copy.sentences(selectedReason), verbatim = true, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.testTag("pitch.rationale"))
                    if (practice) Text(copy.resolve("feedback.practice.guide.$practiceStep"), verbatim = true, style = MaterialTheme.typography.bodyMedium)
                    lastPitchLine?.let { Text(it, style = MaterialTheme.typography.bodySmall, modifier = Modifier.testTag("pitch.lastPitch")) }
                    Text(when (selectedIntensity) {
                        PitchIntensity.CONTROLLED -> "제구 ↑ · 구속 ↓ · 체력 절약"
                        PitchIntensity.NORMAL -> "구속과 제구의 균형"
                        PitchIntensity.MAX_EFFORT -> "구속 ↑ · 제구 ↓ · 체력 소모 ↑"
                    }, style = MaterialTheme.typography.bodySmall)
                    PitchManualPlan(selectedType ?: repertoire.firstOrNull() ?: PitchKind.FOUR_SEAM, selectedZone, selectedIntent, selectedIntensity, ready && !aimingLocked) { type, zone, intent, intensity ->
                        choose(PitchHudSelection.Manual(type, zone, intent, intensity))
                    }
                    if (canFastForward) TextButton(onClick = { settingsOpen = false; onFastForward() }, enabled = ready && !aimingLocked, modifier = Modifier.testTag("pitch.fastForward")) { Text("이 타석 넘기기") }
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("빠른 진행")
                            Text("일반 투구만 자동으로 넘겨요. 연습·퍼펙트·다음 타자는 직접 확인해요.", style = MaterialTheme.typography.bodySmall)
                        }
                        Switch(fastResults, onCheckedChange = onFastResultsChange, modifier = Modifier.testTag("pitch.fastResults"))
                    }
                    onAutoReleaseChange?.let { change ->
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text("자동 릴리스")
                                Text("탭 한 번으로 던진다. 퍼펙트는 없다.", style = MaterialTheme.typography.bodySmall, color = BaseballColors.textTertiary)
                            }
                            Switch(autoRelease, onCheckedChange = change, modifier = Modifier.testTag("pitch.autoRelease.toggle"))
                        }
                    }
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text("진동", modifier = Modifier.weight(1f))
                        TextButton(onClick = { hapticTestAccepted = controlsView.pitchTouchFeedback(android.view.HapticFeedbackConstants.LONG_PRESS, hapticsEnabled) },
                            enabled = hapticsEnabled, modifier = Modifier.testTag("pitch.haptics.test")) { Text("진동 확인") }
                        Switch(hapticsEnabled, onCheckedChange = onHapticsChange, modifier = Modifier.testTag("pitch.haptics.toggle"))
                    }
                    if (hapticTestAccepted == false) Text("기기의 터치 진동 설정을 확인해 주세요.", style = MaterialTheme.typography.bodySmall)
                }
            },
            confirmButton = { TextButton(onClick = { settingsOpen = false }, modifier = Modifier.testTag("pitch.settings.close")) { Text("닫기") } },
        )
    }
}

@Composable
private fun PitchCompactMatchup(
    batterName: String,
    batSide: BatSide,
    adaptationBandLabel: String,
    onExpand: () -> Unit,
) {
    val copy = rememberGameCopy()
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
                listOf(copy.legacy(batterName),
                    copy.resolve(when (batSide) { BatSide.LEFT -> "content.batter-side.left.label"; BatSide.RIGHT -> "content.batter-side.right.label"; BatSide.SWITCH -> "content.batter-side.switch.label" })).filter { it.isNotBlank() }.joinToString(" · "),
                verbatim = true,
                modifier = Modifier.weight(1f),
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
    enabled: Boolean,
    onChange: (PitchKind, PitchZone, ZoneIntent, PitchIntensity) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            if (expanded) "노림 ▴" else "노림 ▾",
            style = MaterialTheme.typography.labelMedium,
            color = BaseballColors.milestone,
            modifier = Modifier.clickable { expanded = !expanded }.testTag("pitch.manualPlan"),
        )
        if (expanded) {
        AdaptiveActionRow(Modifier.fillMaxWidth()) {
            ZoneIntent.entries.forEach { intent ->
                val selected = intent == selectedIntent
                Surface(
                    color = if (selected) BaseballColors.action.copy(alpha = 0.14f) else BaseballColors.surfaceSoft,
                    shape = RoundedCornerShape(8.dp),
                    border = BorderStroke(if (selected) 1.5.dp else 1.dp, if (selected) BaseballColors.action else BaseballColors.border.copy(alpha = 0.5f)),
                    modifier = Modifier.heightIn(min = 48.dp).clickable(enabled = enabled) { onChange(repertoireType, selectedZone, intent, selectedIntensity) },
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

        }
    }
}

@Composable
private fun PitchZoneGrid(
    selected: PitchZone,
    enabled: Boolean,
    showsLabels: Boolean = true,
    recommended: PitchZone? = null,
    onSelect: (PitchZone) -> Unit,
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.fillMaxWidth()) {
        repeat(3) { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                repeat(3) { col ->
                    val zone = PitchZone(row, col)
                    val isSelected = zone == selected
                    val zoneName = listOf("높게", "가운데", "낮게")[row] + "\n" + listOf("왼쪽", "중앙", "오른쪽")[col]
                    Box(
                        modifier = Modifier
                            .weight(1f).heightIn(min = 48.dp).testTag("pitch.zone.$row.$col")
                            .semantics { this.selected = isSelected; role = Role.RadioButton }.gameDescription(zoneName)
                            .clip(RoundedCornerShape(6.dp))
                            .background(if (isSelected) BaseballColors.action.copy(alpha = 0.28f) else BaseballColors.surfaceSoft)
                            .border(if (isSelected) 1.5.dp else 1.dp, if (isSelected) BaseballColors.action else BaseballColors.border.copy(alpha = 0.45f), RoundedCornerShape(6.dp))
                            .clickable(enabled = enabled) { onSelect(zone) },
                        contentAlignment = Alignment.Center,
                    ) {
                        if (showsLabels) Text(zoneName, style = MaterialTheme.typography.labelSmall, color = if (isSelected) BaseballColors.action else BaseballColors.textSecondary)
                        else if (isSelected) Box(Modifier.size(18.dp).border(2.dp, BaseballColors.action, CircleShape))
                        if (!showsLabels && zone == recommended) Box(Modifier.align(Alignment.TopEnd).padding(5.dp).size(6.dp)
                            .background(BaseballColors.milestone, CircleShape).testTag("pitch.recommended.$row.$col"))
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
            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
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
            .heightIn(min = 48.dp)
            .clip(RoundedCornerShape(10.dp))
            .clickable(enabled = enabled, onClick = onClick)
            .semantics { role = Role.Button }.gameDescription("$label ${if (selected) "선택됨" else "선택 가능"}"),
    ) {
        Box(contentAlignment = Alignment.Center, modifier = Modifier.padding(horizontal = 4.dp, vertical = 6.dp)) {
            Text(
                text = label,
                color = if (selected) BaseballColors.action else BaseballColors.textPrimary,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

internal fun releaseTimingLabel(accuracy: Int, aimAccuracy: Int = 1_000): String = when {
    accuracy >= 975 -> "★ 퍼펙트 릴리스"
    accuracy >= com.solkim.baseball.application.PitchReleaseWindow.STABLE_RELEASE_THRESHOLD -> if (aimAccuracy < 650) "릴리스는 좋았다. 조준이 흔들렸다" else "릴리스 좋았다"
    accuracy >= 650 -> "타이밍이 살짝 어긋났다"
    else -> "타이밍을 놓쳤다"
}

@Composable
internal fun PitchEffortControl(
    selectedIntensity: PitchIntensity,
    recommendedIntensity: PitchIntensity?,
    enabled: Boolean,
    expectedVelocity: Int? = null,
    compact: Boolean = false,
    onChange: (PitchIntensity) -> Unit,
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val preferences = remember(context) { context.getSharedPreferences("pitch.ui", Context.MODE_PRIVATE) }
    var discovered by remember { mutableStateOf(preferences.getBoolean("effort.discovered", false)) }
    Column(Modifier.fillMaxWidth().testTag("pitch.effort"), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("힘 배분", style = MaterialTheme.typography.labelMedium, color = BaseballColors.textSecondary)
            expectedVelocity?.let { velocity ->
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    if (!compact) Text("예상 구속", style = MaterialTheme.typography.labelSmall, color = BaseballColors.textSecondary)
                    Text(String.format(java.util.Locale.US, "%.1f km/h", velocity / 10.0),
                        style = MaterialTheme.typography.labelSmall, color = BaseballColors.action, verbatim = true)
                }
            }
        }
        AdaptiveActionRow(Modifier.fillMaxWidth(), equalWidth = true) {
            PitchIntensity.entries.forEach { intensity ->
                val isSelected = selectedIntensity == intensity
                Surface(
                    color = if (isSelected) BaseballColors.action else BaseballColors.surfaceSoft,
                    shape = RoundedCornerShape(8.dp),
                    border = BorderStroke(1.dp, if (isSelected) BaseballColors.action else BaseballColors.border),
                    modifier = Modifier.heightIn(min = 48.dp).testTag("pitch.effort.${intensity.wire}")
                        .semantics { selected = isSelected; role = Role.RadioButton }
                        .clickable(enabled = enabled) {
                            discovered = true
                            preferences.edit().putBoolean("effort.discovered", true).apply()
                            onChange(intensity)
                        },
                ) {
                    Box(Modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 7.dp), contentAlignment = Alignment.Center) {
                        Text(when (intensity) {
                            PitchIntensity.CONTROLLED -> "제구 우선"
                            PitchIntensity.NORMAL -> "균형"
                            PitchIntensity.MAX_EFFORT -> "전력"
                        }, color = if (isSelected) BaseballColors.actionInk else BaseballColors.textPrimary,
                            style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold,
                            modifier = Modifier.testTag("pitch.effort.label.${intensity.wire}"))
                    }
                }
            }
        }
        if (!compact && recommendedIntensity != null) {
            val copy = rememberGameCopy()
            val label = when (recommendedIntensity) {
                PitchIntensity.CONTROLLED -> "제구 우선"
                PitchIntensity.NORMAL -> "균형"
                PitchIntensity.MAX_EFFORT -> "전력"
            }
            Text(copy.resolve("controls.pitch.recommended", GameCopyArgument.UserText(copy.legacy(label))),
                verbatim = true, style = MaterialTheme.typography.labelSmall, color = BaseballColors.textSecondary)
        }
        if (!compact) Text(when (selectedIntensity) {
            PitchIntensity.CONTROLLED -> "제구 ↑ · 구속 ↓ · 체력 절약"
            PitchIntensity.NORMAL -> "구속과 제구의 균형"
            PitchIntensity.MAX_EFFORT -> "구속 ↑ · 제구 ↓ · 체력 소모 ↑"
        }, style = MaterialTheme.typography.labelSmall, color = BaseballColors.textSecondary)
        if (!discovered && !compact) Text("던지기 전에 힘을 골라보세요.", style = MaterialTheme.typography.labelSmall, color = BaseballColors.action)
    }
}

internal fun practiceFeedback(delivery: PitchDelivery?): String = when {
    delivery == null -> "포수 사인을 보고 한 구 더 던져 보세요."
    delivery.releaseAccuracy < com.solkim.baseball.application.PitchReleaseWindow.STABLE_RELEASE_THRESHOLD && delivery.aimAccuracy < 650 -> "조준점을 가운데에 두고 초록 구간에서 놓아 보세요."
    delivery.aimAccuracy < 650 -> "타이밍은 좋아요. 누른 채 손가락을 움직여 조준점을 가운데로 맞춰 보세요."
    delivery.releaseAccuracy < com.solkim.baseball.application.PitchReleaseWindow.STABLE_RELEASE_THRESHOLD -> "조준은 좋아요. 초록 구간에서 손을 놓아 보세요."
    else -> "타이밍과 조준이 모두 좋았어요."
}

@Composable
private fun PitchPlateFeedback(xMm: Int, yMm: Int, target: PitchZone?) {
    androidx.compose.foundation.Canvas(Modifier.size(84.dp).testTag("pitch.plateDiagram").gameDescription("공이 지나간 곳")) {
        val range = maxOf(750f, kotlin.math.abs(xMm.toFloat()) + 100f, kotlin.math.abs(yMm.toFloat()) + 100f)
        val scale = size.minDimension / (range * 2)
        val left = center.x - 500 * scale
        val top = center.y - 500 * scale
        val unit = 1000 * scale / 3
        target?.let { drawRect(BaseballColors.actionSoft,
            androidx.compose.ui.geometry.Offset(left + it.column * unit, top + it.row * unit), androidx.compose.ui.geometry.Size(unit, unit)) }
        for (i in 0..3) {
            drawLine(BaseballColors.border, androidx.compose.ui.geometry.Offset(left + i * unit, top), androidx.compose.ui.geometry.Offset(left + i * unit, top + unit * 3), 1.dp.toPx())
            drawLine(BaseballColors.border, androidx.compose.ui.geometry.Offset(left, top + i * unit), androidx.compose.ui.geometry.Offset(left + unit * 3, top + i * unit), 1.dp.toPx())
        }
        drawCircle(BaseballColors.action, 4.dp.toPx(), androidx.compose.ui.geometry.Offset(center.x + xMm * scale, center.y - yMm * scale))
    }
}
