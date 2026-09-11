package com.solkim.baseball.android

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.solkim.baseball.android.LocalizedGameText as Text
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.design.BaseballMigrationTheme
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeoutOrNull

@OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)
@Composable
internal fun PitchActivity.PitchMoundScreen() {

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
            LaunchedEffect(request, isDelivering, replayGeneration, resultReady) {
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
                    kotlinx.coroutines.withTimeoutOrNull(duration.toLong() + 1_500L) {
                        dramaProgress.animateTo(targetValue = 1f, animationSpec = tween(durationMillis = duration, easing = LinearEasing))
                    }
                    dramaProgress.snapTo(1f)

                    if (isDelivering) {
                        consumeAfterAnimationComplete(saved)
                    }
                } else if (saved != null && resultReady) {
                    dramaProgress.snapTo(1f)
                } else if (saved == null) {
                    dramaProgress.snapTo(0f)
                }
            }

            val showingResult = request != null
            val outcome = if (showingResult) currentOutcome() else null
            val battedBall = if (showingResult) currentBattedBall() else null
            val fielding = if (showingResult) currentFielding() else null
            val batSide = currentBatSide()

            val visibleContext = if (isDelivering) contextBeforeDelivery ?: gameState else gameState
            val board = remember(visibleContext) { PitchScoreboardProjection.model(visibleContext) }
            val balls = board.balls
            val strikes = board.strikes
            val outs = board.outs
            val isClutch = strikes == 2 && (balls == 3 || outs == 2)
            val hud = remember(visibleContext) { runCatching { PitchHudProjection.model(visibleContext) }.getOrNull() }
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
            val practiceStep = ((CareerUiRules.lastPresentationPitchNumber(gameState) ?: 0) + if (isDelivering || resultReady) 0 else 1).coerceIn(1, 3)
            val leverage = PitchHudProjection.leverage(gameState)
                ?: if (gameState.pitch?.careerKind == PitchCareerKind.TUTORIAL) 200 else 500

            Surface(
                modifier = Modifier.fillMaxSize().semantics { testTagsAsResourceId = true },
                color = BaseballColors.canvas,
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .wrapContentWidth(Alignment.CenterHorizontally)
                        .widthIn(max = 600.dp)
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
                    if (!practiceMode) com.solkim.baseball.application.OutingPresentation.assignment(visibleContext)?.let { assignment ->
                        Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 4.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(com.solkim.baseball.application.OutingPresentation.goal(visibleContext), style = MaterialTheme.typography.labelLarge,
                                fontWeight = FontWeight.Bold, modifier = Modifier.testTag("pitch.objective"))
                            Text(com.solkim.baseball.application.OutingPresentation.progress(visibleContext).orEmpty(),
                                color = BaseballColors.action, style = MaterialTheme.typography.labelMedium, modifier = Modifier.testTag("pitch.objective.progress"))
                            if (assignment.inheritedRunners > 0) Text("등판 때 주자 ${assignment.inheritedRunners}명 승계", style = MaterialTheme.typography.labelSmall)
                        }
                    }

                    val watchingPitch = isDelivering || resultReady || request != null
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
                                val rivalName = PitchHudProjection.rivalName(gameState)
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

                    if (isDelivering || (request != null && !resultReady)) {
                        if (request != null) OutlinedButton(onClick = { request?.let(::consumeAfterAnimationComplete) },
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).heightIn(min = 48.dp).testTag("pitch.showResult")) { Text("결과 보기") }
                        else Text("투구 결과를 저장하고 있어요.", modifier = Modifier.padding(16.dp).testTag("pitch.saving"))
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
                                starterTrial = com.solkim.baseball.application.OutingPresentation.isStarterTrial(gameState),
                                inningDecision = AceCareerPresentation.inningDecision(gameState),
                                outcome = outcome,
                                battedBall = battedBall,
                                velocityTenthsKph = request?.velocityDeciKph ?: 0,
                                delivery = lastDelivery,
                                perfect = lastDelivery?.isPerfectRelease == true,
                                plateXMm = request?.plateXMm,
                                plateYMm = request?.plateYMm,
                                targetZone = lastTargetZone,
                                practice = gameState.pitch?.careerKind == PitchCareerKind.TUTORIAL,
                                onPracticeAgain = if (gameState.pitch?.careerKind == PitchCareerKind.TUTORIAL && (CareerUiRules.lastPresentationPitchNumber(gameState) ?: 0) < 3) ({ finishPractice(true) }) else null,
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
                                onHandOff = if (PitchHudProjection.hasProActivePitch(gameState)) ({ finishAndReturn(true) }) else null,
                            )
                        }
                    } else if (!isDelivering && request == null) {
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
                                ready = repertoire.isNotEmpty() && !awaitingPractice && !recoveryRequired,
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
                                canFastForward = PitchHudProjection.canFastForward(gameState),
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
                                    getSharedPreferences("pitch.ui", android.content.Context.MODE_PRIVATE).edit().putBoolean("fast.results", enabled).apply()
                                },
                            )
                        }
                    }
                }
            }
            pitchError?.let { message ->
                val copy = rememberGameCopy()
                AlertDialog(modifier = Modifier.semantics { testTagsAsResourceId = true },
                    onDismissRequest = { pitchError = null; if (recoveryRequired) handleBack() },
                    title = { Text(copy.resolve("settings2.error-title"), verbatim = true) },
                    text = { Text(message, modifier = Modifier.testTag("pitch.error")) },
                    confirmButton = { TextButton(onClick = {
                        pitchError = null
                        val pending = recoveryRequest
                        recoveryRequest = null
                        if (pending != null) consumeAfterAnimationComplete(pending) else if (recoveryRequired) handleBack()
                    }, modifier = Modifier.testTag("pitch.error.close")) {
                        if (recoveryRequest != null) Text(copy.resolve("controls.result"), verbatim = true) else if (recoveryRequired) Text("돌아가기") else Text(copy.resolve("settings2.close"), verbatim = true)
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
