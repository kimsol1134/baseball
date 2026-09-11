package com.solkim.baseball.android

import com.solkim.baseball.application.CareerUiRules
import com.solkim.baseball.application.GameAggregateState

import com.solkim.baseball.application.AceCareerPresentation
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
import androidx.compose.foundation.layout.fillMaxHeight
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
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.BoxWithConstraints
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
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.graphicsLayer
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
import com.solkim.baseball.application.PitchSessionController
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
    internal lateinit var store: KotlinGameStore
    internal lateinit var controller: PitchSessionController
    internal lateinit var sessionId: String
    internal lateinit var expectedRevision: String
    internal var status by mutableStateOf("투구 준비 완료")
    internal var pitchError by mutableStateOf<String?>(null)
    internal var recoveryRequest by mutableStateOf<PitchPresentationRequest?>(null)
    internal var recoveryRequired by mutableStateOf(false)
    internal var feedbackActive by mutableStateOf(false)
    internal var advancingPitch by mutableStateOf(false)
    internal var inspectingPitch by mutableStateOf(false)
    internal var recentAdversePitch = false
    internal var selectedSign by mutableStateOf<PitchHudSelection>(PitchHudSelection.Primary)
    internal var selectedPitchIndex by mutableStateOf(0)
    internal var selectedZone by mutableStateOf(PitchZone(1, 1))
    internal var lastTargetZone by mutableStateOf<PitchZone?>(null)
    internal var selectedIntent by mutableStateOf(ZoneIntent.EDGE)
    internal var selectedIntensity by mutableStateOf(PitchIntensity.NORMAL)
    internal var fastResults by mutableStateOf(false)
    internal var holdCall by mutableStateOf(false)
    internal var chromeExpanded by mutableStateOf(false)
    internal var request by mutableStateOf<PitchPresentationRequest?>(null)
    internal var lastDelivery by mutableStateOf<PitchDelivery?>(null)
    internal var perfectStreak by mutableStateOf(0)
    internal var practiceIntroductionAccepted by mutableStateOf(false)
    internal var lastPitchLine by mutableStateOf<String?>(null)
    internal var consumingPitchId: String? = null
    internal var resultReady by mutableStateOf(false)
    internal var isDelivering by mutableStateOf(false)
    internal var contextBeforeDelivery by mutableStateOf<GameAggregateState?>(null)
    internal var clutchReplay by mutableStateOf(false)
    internal var plateEnded by mutableStateOf(false)
    internal var replayGeneration by mutableStateOf(0)
    internal var confirmAbort by mutableStateOf(false)
    internal var returningToShell = false
    internal val activityScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putInt(PERFECT_STREAK_KEY, perfectStreak)
        outState.putBoolean("practice.introduction.accepted", practiceIntroductionAccepted)
    }

    internal data class GrowthFeedback(val command: Int?, val velocities: Map<PitchKind, Int>)

    /** Compare with the last mound visit, so training growth survives intervening choices/saves. */
    internal fun consumeGrowthOverlay(state: com.solkim.baseball.application.GameAggregateState): GrowthFeedback {
        if (state.pitch?.boundary !in setOf(PitchBoundary.RESERVED, PitchBoundary.PLAYING, PitchBoundary.SUSPENDED)) return GrowthFeedback(null, emptyMap())
        val pro = state.pitch?.careerKind == PitchCareerKind.PRO
        val career = if (pro) CareerUiRules.proCareerId(state) else CareerUiRules.highSchoolCareerId(state)
        if (career == null) return GrowthFeedback(null, emptyMap())
        val current = PitchHudProjection.pitcher(state)
        val initial = PitchHudProjection.startingPitcher(state)
        val preferences = getSharedPreferences("pitch.ui", MODE_PRIVATE)
        val prefix = "feel.$career"
        val revision = if (pro) CareerUiRules.proRevision(state) else CareerUiRules.schoolRevision(state)
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
        controller = PitchSessionController(store)
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

        setContent { PitchMoundScreen() }
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

    internal fun showPitchError(message: String) {
        if (isFinishing || isDestroyed) return
        Log.w(TAG, "pitch.error_dialog session=${if (::sessionId.isInitialized) sessionId else "missing"} revision=${if (::store.isInitialized) store.current.revision else "missing"} boundary=${if (::store.isInitialized) store.current.pitch?.boundary else null}")
        status = message; pitchError = message
    }

    internal suspend fun reportPitchFailure(stage: String, error: Exception, attemptSession: String = sessionId, attemptPitchId: String? = null) {
        val correlation = java.util.UUID.randomUUID().toString()
        val command = com.solkim.baseball.application.GameCommandFailureContext.from(error)
        Log.e(TAG, "pitch.failure correlation=$correlation stage=$stage session=$attemptSession pitch=$attemptPitchId command=${command?.commandId} expected=${command?.expectedRevision ?: expectedRevision} actual=${store.current.revision} boundary=${store.current.pitch?.boundary} lifecycle=${lifecycle.currentState} version=${BuildConfig.VERSION_NAME}/${BuildConfig.VERSION_CODE}", error)
        val verified = try { store.reconcilePersistedRevision() }
        catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled }
        catch (failure: Exception) {
            Log.e(TAG, "pitch.reconcile_failed correlation=$correlation", failure)
            null
        }
        val targetId = attemptPitchId ?: command?.pitchId
        val confirmed = verified?.durableStateVerified == true &&
            com.solkim.baseball.application.PitchFailureRecovery.hasSavedResult(verified.state, attemptSession, targetId)
        val restored = if (confirmed) try {
            controller.preparePresentation(attemptSession, selectedPitchIndex).takeIf { it.pitchId == targetId }
        } catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled }
        catch (failure: Exception) { Log.e(TAG, "pitch.rebuild_failed correlation=$correlation", failure); null } else null
        Log.i(TAG, "pitch.recovery correlation=$correlation verified=${verified?.durableStateVerified == true} savedResult=${restored != null} persistedRevision=${verified?.persistedRevision} boundary=${verified?.state?.pitch?.boundary}")
        withContext(Dispatchers.Main) {
            if (isFinishing || isDestroyed) return@withContext
            isDelivering = false
            consumingPitchId = null
            advancingPitch = false
            recoveryRequest = restored
            recoveryRequired = restored == null
            if (restored != null) {
                request = restored
                inspectingPitch = true
                resultReady = false
                showPitchError("투구 결과는 저장됐어요. 결과 확인을 눌러 이어서 진행해 주세요.")
            } else {
                showPitchError("진행 상태를 확인하지 못했어요. 돌아간 뒤 멈춰 둔 투구를 다시 열어 주세요.")
            }
        }
    }

    internal fun persistPitchSettings(transform: (com.solkim.baseball.application.GameSettingsState) -> com.solkim.baseball.application.GameSettingsState) {
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

    internal fun persistHoldCall(enabled: Boolean) {
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

    internal fun lookupSavedSession(expected: String): Boolean {
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

    internal fun loadSavedPresentationOrInput() {
        activityScope.launch {
            try {
                val state = store.state.value
                val pitch = requireNotNull(state.pitch) { "pitch.missing" }
                when (pitch.boundary) {
                    PitchBoundary.COMMITTED,
                    PitchBoundary.CONSUMED,
                    PitchBoundary.TERMINAL,
                    PitchBoundary.COMPLETED -> {
                        val saved = controller.preparePresentation(sessionId, selectedPitchIndex)
                        withContext(Dispatchers.Main) {
                            request = saved
                            resultReady = pitch.boundary != PitchBoundary.COMMITTED
                            isDelivering = !resultReady
                            status = if (resultReady) "투구 결과를 확인해 보세요." else "투구 준비 완료"
                        }
                    }
                    PitchBoundary.PLAYING -> {
                        if (controller.shouldRecoverPlayingPresentation(state, sessionId)) {
                            val rebuilt = controller.commitSavedPresentation(sessionId, selectedPitchIndex)
                            withContext(Dispatchers.Main) {
                                request = rebuilt
                                resultReady = false
                                isDelivering = true
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
            } catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled }
            catch (error: Exception) { reportPitchFailure("load", error) }
        }
    }

    internal fun needsPracticeIntroduction(state: GameAggregateState): Boolean =
        !practiceIntroductionAccepted && state.pitch?.careerKind == PitchCareerKind.TUTORIAL &&
            CareerUiRules.lifeNumber(state) == 1 && !CareerUiRules.hasLastPresentation(state) && request == null

    internal fun submitSelectedPitch(delivery: PitchDelivery) {
        if (isDelivering || resultReady || recoveryRequired || needsPracticeIntroduction(store.current)) return
        contextBeforeDelivery = store.current
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
                            com.solkim.baseball.application.CommandReceiptRetention.id(store.current.revision, "manual-release:${saved.pitchId}"), "native-pitch", store.current.revision,
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
            } catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled }
            catch (error: Exception) { reportPitchFailure("submit", error)
            }
        }
    }

    internal fun consumeAfterAnimationComplete(saved: PitchPresentationRequest) {
        if (consumingPitchId == saved.pitchId || pitchError != null) return
        if (request?.pitchId != saved.pitchId) {
            Log.w(TAG, "pitch.stale_animation requested=${saved.pitchId} current=${request?.pitchId}")
            return
        }
        val attemptSession = sessionId
        consumingPitchId = saved.pitchId
        activityScope.launch {
            try {
                controller.consumePresentation(attemptSession, saved)
                withContext(Dispatchers.Main) {
                    isDelivering = false
                    contextBeforeDelivery = null
                    resultReady = true
                    status = "투구 결과를 확인해 보세요."
                }
            } catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled }
            catch (error: Exception) { reportPitchFailure("consume", error, attemptSession, saved.pitchId)
            }
        }
    }

    internal fun finishPractice(repeat: Boolean) {
        if (advancingPitch) return
        advancingPitch = true
        activityScope.launch {
            try {
                val result = com.solkim.baseball.application.ScreenController(store).finishPractice(sessionId, repeat)
                withContext(Dispatchers.Main) {
                    returningToShell = true
                    val launch = result.launch
                    if (launch != null) startActivity(intent(this@PitchActivity, launch.sessionId, launch.expectedRevision.toString()))
                    else startActivity(Intent(this@PitchActivity, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT))
                    finish()
                }
            } catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled }
            catch (error: Exception) { reportPitchFailure("finishPractice", error)
            }
        }
    }

    internal fun completeAndReturn() = finishAndReturn(false)

    internal fun finishAndReturn(handOff: Boolean) {
        activityScope.launch {
            try {
                controller.completePitchAndPostgame(sessionId, handOff)
                withContext(Dispatchers.Main) {
                    returningToShell = true
                    startActivity(Intent(this@PitchActivity, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT))
                    finish()
                }
            } catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled }
            catch (error: Exception) { reportPitchFailure("finish", error)
            }
        }
    }

    internal fun continueInSession(continueOuting: Boolean = false) {
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
            } catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled }
            catch (error: Exception) { reportPitchFailure("next", error)
            } finally { withContext(Dispatchers.Main) { advancingPitch = false } }
        }
    }

    internal fun fastForwardCurrentBatter() {
        if (isDelivering || advancingPitch || resultReady || recoveryRequired) return
        isDelivering = true
        lastDelivery = null
        activityScope.launch {
            try {
                withContext(Dispatchers.Main) { isDelivering = true }
                val saved = controller.fastForwardCurrentBatter(finishOuting = PitchHudProjection.fatigue(store.current) >= 80)
                withContext(Dispatchers.Main) {
                    request = saved
                    isDelivering = false
                    resultReady = saved != null
                    status = "타석을 빠르게 진행했습니다"
                }
            } catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled }
            catch (error: Exception) { reportPitchFailure("fastForward", error)
            }
        }
    }

    internal fun selectedCallZone(hud: com.solkim.baseball.application.PitchHudModel?): PitchZone {
        val preparation = hud?.preparation
        return when (val sign = selectedSign) {
            PitchHudSelection.Primary -> preparation?.primaryRecommendation?.call?.zone ?: selectedZone
            PitchHudSelection.Alternative -> preparation?.alternativeRecommendation?.call?.zone ?: selectedZone
            is PitchHudSelection.Manual -> sign.zone
        }
    }

    internal fun handleBack() {
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

    internal fun selectedPitchType(): PitchKind {
        val hud = runCatching { PitchHudProjection.model(store.current) }.getOrNull()
        val repertoire = hud?.repertoire.orEmpty()
        return when (val sign = selectedSign) {
            PitchHudSelection.Primary -> hud?.preparation?.primaryRecommendation?.call?.pitchType
            PitchHudSelection.Alternative -> hud?.preparation?.alternativeRecommendation?.call?.pitchType
            is PitchHudSelection.Manual -> sign.pitchType
        } ?: repertoire.firstOrNull() ?: PitchKind.FOUR_SEAM
    }

    internal fun currentOutcome(): PitchOutcome? = PitchLiveResult.outcome(store.current)

    internal fun currentBattedBall(): BattedBall? = PitchLiveResult.battedBall(store.current)

    internal fun currentFielding(): com.solkim.baseball.application.FieldingResolutionSnapshot? =
        PitchLiveResult.fielding(store.current)

    internal fun currentBatSide(): BatSide =
        runCatching { PitchHudProjection.batter(store.current).batSide }.getOrDefault(BatSide.RIGHT)

    internal fun moundTension(): Double {
        val state = store.current
        val scene = PitchHudProjection.moundScene(state)
        val fatigue = PitchHudProjection.fatigue(state)
        val batter = runCatching { PitchHudProjection.batter(state) }.getOrNull()
        val threat = if (batter != null) MoundTensionModel.batterThreat(batter.contact, batter.discipline, batter.power) else 50
        val raw = MoundTensionModel.tension(
            MoundTensionInput(scene.official, scene.leverage, scene.runners, scene.balls, scene.strikes, scene.outs, fatigue, threat, moundAdverseEpisode(), scene.composure),
        )
        return MoundTensionModel.entryTension(raw, scene.official)
    }

    internal fun moundAdverseEpisode(): Boolean {
        val last = currentOutcome()
        return recentAdversePitch || last in adverseOutcomes
    }

    internal fun moundSeed(): ULong {
        val pitch = store.current.pitch
        return MoundTensionModel.seed(pitch?.gameId ?: pitch?.sessionId ?: "mound")
    }

    internal val adverseOutcomes = setOf(
        PitchOutcome.SINGLE,
        PitchOutcome.DOUBLE,
        PitchOutcome.TRIPLE,
        PitchOutcome.HOME_RUN,
        PitchOutcome.HIT_BY_PITCH,
    )

    internal fun selectedPitchVelocity(): Int = runCatching {
        val state = store.current
        com.solkim.baseball.application.CareerUiRules.selectedVelocity(state, selectedSign)
    }.getOrDefault(1_350)

    internal fun platform(): com.solkim.baseball.platform.NativePlatform = (application as BaseballApplication).platform

    internal fun playbackSettings(): com.solkim.baseball.platform.NativePlaybackSettings {
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
