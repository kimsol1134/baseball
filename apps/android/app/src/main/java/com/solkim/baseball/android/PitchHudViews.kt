package com.solkim.baseball.android

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.testTagsAsResourceId
import android.content.Context
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color as ComposeColor
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.solkim.baseball.android.LocalizedGameText as Text
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.model.QualityTier

@Composable
internal fun PitchResultCard(
    starterTrial: Boolean = false,
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
    inningDecision: String? = null,
    onHandOff: (() -> Unit)? = null,
) {
    val tone = if (outcome == null) BaseballColors.textSecondary else outcomeTone(outcome)
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
            delivery?.let { Text(releaseTimingLabel(it.releaseAccuracy, it.aimAccuracy), color = if (it.releaseAccuracy >= 820 && it.aimAccuracy >= 650) BaseballColors.action else BaseballColors.textSecondary) }
            if (plateXMm != null && plateYMm != null) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    PitchPlateFeedback(plateXMm, plateYMm, targetZone)
                    Column(Modifier.weight(1f)) {
                        Text("공이 지나간 곳", style = MaterialTheme.typography.labelMedium)
                        plateLocationLine(plateXMm, plateYMm)?.let { Text(it, style = MaterialTheme.typography.bodySmall, modifier = Modifier.testTag("pitch.plateLocation")) }
                    }
                }
            }
            if (!practice && onContinueInning == null && inningDecision != null) inningDecision.lines().forEach { Text(it, style = MaterialTheme.typography.bodyMedium) }
            if (practice) {
                val copy = rememberGameCopy()
                Text(practiceFeedback(delivery),
                    style = MaterialTheme.typography.bodyLarge, modifier = Modifier.testTag("pitch.practiceReaction"))
                Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    onPracticeAgain?.let { again ->
                        Button(onClick = again, enabled = !practiceBusy, modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp).testTag("pitch.practiceAgain")) {
                            Text(copy.resolve("android.onboarding.again"))
                        }
                    }
                    if (onPracticeAgain != null) {
                        OutlinedButton(onClick = onPracticeSchool, enabled = !practiceBusy, modifier = Modifier.heightIn(min = 52.dp).testTag("pitch.practiceSchool")) {
                            Text(copy.resolve("android.onboarding.skip-school"))
                        }
                    } else Button(onClick = onPracticeSchool, enabled = !practiceBusy, modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp).testTag("pitch.practiceSchool")) {
                        Text(copy.resolve("android.onboarding.choose-school"))
                    }
                }
            } else if (onContinueInning != null) {
                (inningDecision ?: "이닝을 마쳤어요. 계속 던질까요?").lines().forEach { Text(it, style = MaterialTheme.typography.bodyMedium) }
                if (starterTrial) Text("자동 진행하면 직접 투구 테스트는 여기서 끝나요.", color = BaseballColors.warning, style = MaterialTheme.typography.bodySmall)
                AdaptiveActionRow(Modifier.fillMaxWidth()) {
                    Button(onClick = onContinueInning, modifier = Modifier.testTag("pitch.nextInning")) { Text(if (starterTrial) "테스트 이어 던지기" else "마운드를 지킨다") }
                    OutlinedButton(onClick = onHandOff ?: onPostgame, modifier = Modifier.testTag("pitch.simulateRemainder")) { Text(if (onHandOff != null) "불펜에 맡긴다" else "남은 경기 자동") }
                }
                if (onHandOff != null) TextButton(onClick = onPostgame, modifier = Modifier.testTag("pitch.autoOuting")) { Text("내 투수 자동 진행") }
            } else if (!automaticNext) Button(onClick = if (outingContinues) (onNextPitch ?: onPostgame) else onPostgame,
                modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp).testTag("pitch.continue")) { Text(nextLabel) }
            AdaptiveActionRow(Modifier.fillMaxWidth()) {
                TextButton(onClick = onReplay, modifier = Modifier.testTag("pitch.replay")) { Text("투구 다시 보기") }
                if (!practice) TextButton(onClick = { onInspect(); details = true }, modifier = Modifier.testTag("pitch.resultDetails")) { Text("투구 결과 자세히") }
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


internal fun plateAppearanceEnds(outcome: PitchOutcome?, balls: Int, strikes: Int): Boolean = when (outcome) {
    PitchOutcome.SWINGING_STRIKE, PitchOutcome.CALLED_STRIKE -> strikes >= 2
    PitchOutcome.BALL -> balls >= 3
    PitchOutcome.HIT_BY_PITCH,
    PitchOutcome.REACHED_ON_ERROR,
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
internal fun perfectCatcherLine(outcome: PitchOutcome?): String = when (outcome) {
    PitchOutcome.SWINGING_STRIKE, PitchOutcome.CALLED_STRIKE -> "포수: 미트가 울렸다. 그 공이다."
    PitchOutcome.BALL -> "포수: 손끝은 완벽했다. 코스만 다시."
    PitchOutcome.FOUL -> "포수: 릴리스는 완벽했다. 한 번 더."
    PitchOutcome.REACHED_ON_ERROR -> "포수: 잘 던졌어. 다음 타자에 집중하자."
    PitchOutcome.IN_PLAY_OUT -> "포수: 완벽한 공. 야수가 마무리했다."
    PitchOutcome.HIT_BY_PITCH, PitchOutcome.SINGLE, PitchOutcome.DOUBLE, PitchOutcome.TRIPLE, PitchOutcome.HOME_RUN -> "포수: 릴리스는 완벽했다. 맞은 건 상대 몫."
    null -> "포수: 그 감각을 기억해."
}

/** Tutorial third pitch only: a wider window so the beginner meets the green once. Practice, never recorded. */
internal fun tutorialCommandAssist(state: com.solkim.baseball.application.GameAggregateState): Int =
    if (state.pitch?.careerKind == PitchCareerKind.TUTORIAL && CareerUiRules.lastPresentationPitchNumber(state) == 2) 15 else 0

/** The 제구 value before the latest growth of this career, so the first pitch can show the old window. */
internal fun previousCommandAfterGrowth(state: com.solkim.baseball.application.GameAggregateState): Int? {
    val careerId = CareerUiRules.proCareerId(state) ?: CareerUiRules.highSchoolCareerId(state) ?: return null
    val growth = state.meta.playerGrowth ?: return null
    if (growth.careerId != careerId || growth.before.size < 2 || growth.after.size < 2) return null
    return growth.before[1].takeIf { it < growth.after[1] }
}

internal fun resultCommentary(outcome: PitchOutcome?): String = when (outcome) {
    PitchOutcome.SWINGING_STRIKE -> "배트가 허공을 갈랐다"
    PitchOutcome.CALLED_STRIKE -> "존 구석에 꽂혔다"
    PitchOutcome.BALL -> "존을 살짝 벗어났다"
    PitchOutcome.FOUL -> "빗맞았다. 다시"
    PitchOutcome.HIT_BY_PITCH -> "몸에 맞았다"
    PitchOutcome.IN_PLAY_OUT -> "야수 정면. 잡았다"
    PitchOutcome.REACHED_ON_ERROR -> "야수가 놓쳤다 · 실책 출루"
    PitchOutcome.SINGLE -> "빈틈을 뚫렸다"
    PitchOutcome.DOUBLE -> "장타. 주자가 뛴다"
    PitchOutcome.TRIPLE -> "외야 깊숙이. 3루까지"
    PitchOutcome.HOME_RUN -> "담장을 넘겼다"
    null -> ""
}
