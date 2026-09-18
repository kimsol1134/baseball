package com.solkim.baseball.android

import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.util.Log
import android.view.HapticFeedbackConstants
import android.view.View

/** Bounded wind-up feedback. Unsupported motors retain the discrete timing cues. */
internal class PitchWindUpFeedback(private val view: View) {
    private val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= 31)
        view.context.getSystemService(VibratorManager::class.java)?.defaultVibrator
        else view.context.getSystemService(Vibrator::class.java)
    private var ownsEffect = false
    private var nextUpdate = 0L
    private var lastEdge = 0L
    private var releaseProtectedUntil = 0L
    private val supportsSoftTick = Build.VERSION.SDK_INT >= 31 && vibrator?.areAllPrimitivesSupported(VibrationEffect.Composition.PRIMITIVE_LOW_TICK) == true

    fun update(closeness: Double, enabled: Boolean) {
        if (!enabled || !view.isHapticFeedbackEnabled) { stop(); return }
        val now = android.os.SystemClock.uptimeMillis()
        if (now < nextUpdate) return
        if (!systemEnabled()) { stop(); nextUpdate = now + 250L; return }
        val near = closeness.coerceIn(0.0, 1.0)
        if (Build.VERSION.SDK_INT < 31 || !supportsSoftTick) {
            // Basic Galaxy motors cannot scale primitives. Encode proximity with cadence.
            nextUpdate = now + (320L - (200.0 * near * near).toLong())
            view.pitchTouchFeedback(HapticFeedbackConstants.CLOCK_TICK, enabled)
            return
        }
        nextUpdate = now + 80L
        val effect = VibrationEffect.startComposition()
            .addPrimitive(VibrationEffect.Composition.PRIMITIVE_LOW_TICK, (0.12 + 0.62 * near * near).toFloat())
            .compose()
        runCatching {
            if (Build.VERSION.SDK_INT >= 33) vibrator?.vibrate(effect, VibrationAttributes.Builder().setUsage(VibrationAttributes.USAGE_TOUCH).build())
            else vibrator?.vibrate(effect, AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION).build())
            ownsEffect = true
        }
    }

    fun cue(event: Int, enabled: Boolean, edge: Boolean = false) {
        val now = android.os.SystemClock.uptimeMillis()
        if (event == HapticFeedbackConstants.LONG_PRESS) releaseProtectedUntil = 0L
        else if (now < releaseProtectedUntil) return
        if (edge && now - lastEdge < 200L) return
        if (edge) lastEdge = now
        stop()
        nextUpdate = now + 90L
        if (edge) com.solkim.baseball.platform.NativePitchHaptics.play(view.context, com.solkim.baseball.model.PitchHapticCue.EDGE, enabled && view.isHapticFeedbackEnabled)
        else view.pitchTouchFeedback(event, enabled)
    }

    /** One heavy click the instant the needle enters the gold window — the warning before a perfect. */
    fun perfectZone(enabled: Boolean) {
        val now = android.os.SystemClock.uptimeMillis()
        if (now < releaseProtectedUntil) return
        stop()
        nextUpdate = now + 120L
        com.solkim.baseball.platform.NativePitchHaptics.play(view.context, com.solkim.baseball.model.PitchHapticCue.PERFECT_ZONE, enabled && view.isHapticFeedbackEnabled)
    }

    fun release(quality: Double, perfect: Boolean, enabled: Boolean) {
        stop()
        releaseProtectedUntil = android.os.SystemClock.uptimeMillis() + 180L
        nextUpdate = releaseProtectedUntil
        val cue = when {
            perfect -> com.solkim.baseball.model.PitchHapticCue.PERFECT
            quality < 0.45 -> com.solkim.baseball.model.PitchHapticCue.ERROR
            else -> com.solkim.baseball.model.PitchHapticCue.RELEASE
        }
        com.solkim.baseball.platform.NativePitchHaptics.play(view.context, cue, enabled && view.isHapticFeedbackEnabled)
    }

    fun stop() {
        if (ownsEffect) runCatching { vibrator?.cancel() }
        ownsEffect = false
    }

    private fun systemEnabled(): Boolean = runCatching {
        Settings.System.getInt(view.context.contentResolver, Settings.System.HAPTIC_FEEDBACK_ENABLED, 1) == 1
    }.getOrDefault(true)
}

/** Touch feedback follows the app/system switches and the real motor capabilities. */
internal fun View.pitchTouchFeedback(event: Int, enabled: Boolean): Boolean {
    val cue = when (event) {
        HapticFeedbackConstants.CLOCK_TICK -> com.solkim.baseball.model.PitchHapticCue.SWEET
        HapticFeedbackConstants.CONFIRM -> com.solkim.baseball.model.PitchHapticCue.PERFECT
        HapticFeedbackConstants.LONG_PRESS -> com.solkim.baseball.model.PitchHapticCue.GRIP
        else -> com.solkim.baseball.model.PitchHapticCue.RELEASE
    }
    return com.solkim.baseball.platform.NativePitchHaptics.play(context, cue, enabled && isHapticFeedbackEnabled)
}
