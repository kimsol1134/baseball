package com.solkim.baseball.application

import com.solkim.baseball.core.pitch.PitchOutcome
import com.solkim.baseball.model.PitchAudioCue
import com.solkim.baseball.model.PitchHapticCue

public data class PitchFeedbackEvent(val delayMs: Long, val cue: PitchAudioCue, val haptic: PitchHapticCue? = null, val gain: Float = 1f, val rate: Float = 1f)

/** iOS GameAudioMapping semantics, timed to Android's actual ball arrival. No game writes. */
public object PitchFeedbackPlan {
    public fun forState(state: GameAggregateState, replayMs: Int, reducedMotion: Boolean, perfect: Boolean = false, velocityTenthsKph: Int = 0): List<PitchFeedbackEvent> {
        val terminal = when (state.pitch?.careerKind) {
            PitchCareerKind.PRO -> state.pro?.activePitch?.ended == true
            else -> state.highSchool?.lastPresentation?.terminal == true
        }
        return make(PitchLiveResult.outcome(state), terminal, PitchLiveResult.battedBall(state)?.contactQuality ?: 500, replayMs, reducedMotion, perfect, velocityTenthsKph)
    }

    /** Perfect release: the whole clip waits [PERFECT_HOLD_MS], the mitt pops louder and lower, the call comes sooner. */
    public const val PERFECT_HOLD_MS: Long = 100L

    /** Mitt loudness grows with the pitch: 130 km/h → 0.8, 150 km/h → 1.2 (feel of 구위 growth). */
    public fun mittGain(velocityTenthsKph: Int): Float =
        if (velocityTenthsKph <= 0) 1f else (0.8f + (velocityTenthsKph - 1_300).coerceIn(0, 200) / 200f * 0.4f)

    /** Faster pitches hit the mitt with a lower, heavier tone; perfect retains its extra accent. */
    public fun mittRate(velocityTenthsKph: Int, perfect: Boolean): Float {
        val base = if (velocityTenthsKph <= 0) 1f else 1.04f - PitchGrowthFeel.speedWeight(velocityTenthsKph) * 0.14f
        return if (perfect) base * 0.9f else base
    }

    public fun make(outcome: PitchOutcome?, terminal: Boolean, contactQuality: Int, replayMs: Int, reducedMotion: Boolean, perfect: Boolean = false, velocityTenthsKph: Int = 0): List<PitchFeedbackEvent> {
        if (outcome == null) return emptyList()
        val hold = if (perfect && !reducedMotion) PERFECT_HOLD_MS else 0L
        val contact = hold + if (reducedMotion) 220L else (replayMs * PitchDramaCamera.CONTACT_PROGRESS).toLong()
        val mittGain = if (perfect) mittGain(velocityTenthsKph) * 1.3f else mittGain(velocityTenthsKph)
        val mittRate = mittRate(velocityTenthsKph, perfect)
        val callLead = if (perfect) 200L else 0L
        val strike = outcome in setOf(PitchOutcome.CALLED_STRIKE, PitchOutcome.SWINGING_STRIKE)
        val strikeout = strike && terminal
        val success = strike || outcome == PitchOutcome.IN_PLAY_OUT
        val contactCue = when (outcome) {
            PitchOutcome.BALL, PitchOutcome.CALLED_STRIKE -> PitchAudioCue.CATCH
            PitchOutcome.SWINGING_STRIKE -> PitchAudioCue.SWING_MISS
            PitchOutcome.FOUL -> PitchAudioCue.FOUL
            PitchOutcome.HIT_BY_PITCH -> PitchAudioCue.WEAK_CONTACT
            else -> if (contactQuality >= 550) PitchAudioCue.CONTACT else PitchAudioCue.WEAK_CONTACT
        }
        return buildList {
            add(PitchFeedbackEvent(0, PitchAudioCue.RELEASE))
            // The air rush rides between the hand and the mitt, louder the harder the pitch is thrown.
            if (!reducedMotion && contact > 200) {
                add(PitchFeedbackEvent(hold + 70, PitchAudioCue.FLIGHT, gain = mittGain(velocityTenthsKph), rate = 0.95f + PitchGrowthFeel.speedWeight(velocityTenthsKph) * 0.1f))
            }
            val mitt = contactCue == PitchAudioCue.CATCH
            add(PitchFeedbackEvent(contact, contactCue, when { outcome == PitchOutcome.FOUL -> PitchHapticCue.FOUL; outcome == PitchOutcome.BALL -> if (terminal) PitchHapticCue.WALK else null; outcome == PitchOutcome.HOME_RUN -> PitchHapticCue.HOME_RUN; outcome in setOf(PitchOutcome.SINGLE, PitchOutcome.DOUBLE, PitchOutcome.TRIPLE) -> PitchHapticCue.HIT; strikeout -> PitchHapticCue.STRIKEOUT; success -> PitchHapticCue.SUCCESS; else -> PitchHapticCue.ERROR },
                gain = if (mitt) mittGain else 1f, rate = if (mitt) mittRate else 1f))
            if (strike) add(PitchFeedbackEvent(contact + (if (strikeout) 400 else 250) - callLead, if (strikeout) PitchAudioCue.STRIKEOUT else PitchAudioCue.STRIKE))
            when {
                strikeout -> add(PitchFeedbackEvent(contact + 2_450, PitchAudioCue.CHEER))
                outcome == PitchOutcome.IN_PLAY_OUT -> add(PitchFeedbackEvent(contact + 500, PitchAudioCue.CHEER))
                outcome in setOf(PitchOutcome.SINGLE, PitchOutcome.DOUBLE, PitchOutcome.TRIPLE, PitchOutcome.HOME_RUN, PitchOutcome.HIT_BY_PITCH) || (outcome == PitchOutcome.BALL && terminal) ->
                    add(PitchFeedbackEvent(contact + 500, PitchAudioCue.GROAN))
            }
        }
    }
}
