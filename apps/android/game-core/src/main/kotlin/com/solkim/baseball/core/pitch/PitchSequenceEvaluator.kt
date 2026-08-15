package com.solkim.baseball.core.pitch

import kotlin.math.abs

/** Source-shaped tags for the deterministic, post-resolution pitch-sequence read. */
public enum class PitchSequenceTag(public val wire: String) {
    SPEED_LADDER("speed_ladder"),
    EYE_LEVEL_CHANGE("eye_level_change"),
    INSIDE_OUTSIDE("inside_outside"),
    EXPAND_AFTER_TWO_STRIKES("expand_after_two_strikes"),
    STEAL_STRIKE("steal_strike"),
    COUNTER_READ("counter_read"),
}

/** The called pitch data needed by the source evaluator; measured velocity is intentionally absent. */
public data class PitchSequencePitch(
    val pitchType: PitchKind,
    val zone: PitchZone,
    val intent: ZoneIntent,
    val expectedVelocityKph: Int,
    val outcome: PitchOutcome,
)

public data class PitchSequenceMoment(
    val pitchNumber: Int,
    val tag: PitchSequenceTag,
    val headline: String,
    val detail: String,
)

/**
 * Pure port of the current Swift PitchSequenceEvaluator. It is downstream of PitchKernel:
 * recognizing a pattern never changes the already-resolved pitch result.
 *
 * The optional adaptation is the pre-pitch preparation read. Passing the post-pitch read would
 * make counter-read recognition depend on the newly recorded pitch and would not be source parity.
 */
public object PitchSequenceEvaluator {
    public const val MINIMUM_SPEED_DIFFERENCE_KPH: Int = 12

    public fun evaluate(
        recent: List<PitchSequencePitch>,
        context: PlateAppearanceContext,
        current: PitchSequencePitch,
        rivalAdaptation: RivalAdaptationSnapshot? = null,
    ): PitchSequenceMoment? {
        if (!isValid(current) || context.balls !in 0..3 || context.strikes !in 0..2 || context.pitchNumber <= 0) {
            return null
        }
        val recentWindow = recent.takeLast(3)
        if (recognizesCounterRead(current, rivalAdaptation)) {
            return moment(context, PitchSequenceTag.COUNTER_READ, "읽힘을 역이용했다", "상대 벤치가 읽은 반복을 끊고 좋은 결과를 만들었습니다.")
        }
        if (context.strikes == 2 && current.intent == ZoneIntent.CHASE && current.outcome == PitchOutcome.SWINGING_STRIKE) {
            return moment(context, PitchSequenceTag.EXPAND_AFTER_TWO_STRIKES, "결정구 유인 성공", "2스트라이크 뒤 존 밖으로 유도해 헛스윙 삼진을 만들었습니다.")
        }
        if (context.balls > context.strikes && context.strikes < 2 && current.intent == ZoneIntent.STRIKE && addsStrike(current.outcome)) {
            return moment(context, PitchSequenceTag.STEAL_STRIKE, "카운트를 되찾았다", "타자 우세 카운트에서 스트라이크를 넣어 승부를 원점으로 돌렸습니다.")
        }
        val previous = recentWindow.lastOrNull()?.takeIf(::isValid) ?: return null
        val velocityDifference = abs(current.expectedVelocityKph - previous.expectedVelocityKph)
        if (velocityDifference >= MINIMUM_SPEED_DIFFERENCE_KPH && disruptsTiming(current.outcome)) {
            return moment(context, PitchSequenceTag.SPEED_LADDER, "속도차 적중 · ${velocityDifference}km/h", "앞선 공과 ${velocityDifference}km/h 차이를 만들어 타자의 타이밍을 무너뜨렸습니다.")
        }
        if (usesOppositeExtremes(previous.zone.row, current.zone.row) && disruptsTiming(current.outcome)) {
            return moment(context, PitchSequenceTag.EYE_LEVEL_CHANGE, "눈높이를 바꿨다", "높은 코스와 낮은 코스를 이어 타자의 시선을 흔들었습니다.")
        }
        if (usesOppositeExtremes(previous.zone.column, current.zone.column) && securesResult(current.outcome)) {
            return moment(context, PitchSequenceTag.INSIDE_OUTSIDE, "가로 폭을 썼다", "몸쪽과 바깥쪽을 연달아 갈라 좋은 결과를 만들었습니다.")
        }
        return null
    }

    private fun recognizesCounterRead(current: PitchSequencePitch, adaptation: RivalAdaptationSnapshot?): Boolean {
        if (adaptation == null || !securesResult(current.outcome)) return false
        if (adaptation.detectedPitch == null && adaptation.detectedZone == null) return false
        val changedPitch = adaptation.detectedPitch?.let { it != current.pitchType } ?: false
        val changedZone = adaptation.detectedZone?.let { it != current.zone } ?: false
        return changedPitch || changedZone
    }

    private fun moment(context: PlateAppearanceContext, tag: PitchSequenceTag, headline: String, detail: String): PitchSequenceMoment =
        PitchSequenceMoment(context.pitchNumber, tag, headline, detail)

    private fun usesOppositeExtremes(lhs: Int, rhs: Int): Boolean = (lhs == 0 && rhs == 2) || (lhs == 2 && rhs == 0)
    private fun disruptsTiming(outcome: PitchOutcome): Boolean = outcome == PitchOutcome.SWINGING_STRIKE || outcome == PitchOutcome.IN_PLAY_OUT
    private fun securesResult(outcome: PitchOutcome): Boolean = outcome == PitchOutcome.CALLED_STRIKE || disruptsTiming(outcome)
    private fun addsStrike(outcome: PitchOutcome): Boolean = outcome == PitchOutcome.CALLED_STRIKE || outcome == PitchOutcome.SWINGING_STRIKE || outcome == PitchOutcome.FOUL
    private fun isValid(pitch: PitchSequencePitch): Boolean = pitch.zone.row in 0..2 && pitch.zone.column in 0..2 && pitch.expectedVelocityKph > 0
}

public object PitchSequenceMasteryRules {
    public const val MAXIMUM_TRUST_REWARD: Int = 3

    public fun trustReward(sequenceMasteryCount: Int?): Int = sequenceMasteryCount?.coerceIn(0, MAXIMUM_TRUST_REWARD) ?: 0
}
