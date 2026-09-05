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
        if (edge && now - lastEdge < 200L) return
        if (edge) lastEdge = now
        stop()
        nextUpdate = now + 90L
        view.pitchTouchFeedback(event, enabled)
    }

    fun stop() {
        if (ownsEffect) runCatching { vibrator?.cancel() }
        ownsEffect = false
    }

    private fun systemEnabled(): Boolean = runCatching {
        Settings.System.getInt(view.context.contentResolver, Settings.System.HAPTIC_FEEDBACK_ENABLED, 1) == 1
    }.getOrDefault(true)
}

/** Touch usage honors device intensity. Predefined effects include Android's hardware fallback. */
internal fun View.pitchTouchFeedback(event: Int, enabled: Boolean): Boolean {
    val systemEnabled = runCatching { Settings.System.getInt(context.contentResolver, Settings.System.HAPTIC_FEEDBACK_ENABLED, 1) == 1 }.getOrDefault(true)
    if (!enabled || !isHapticFeedbackEnabled || !systemEnabled) return false
    val accepted = runCatching {
        if (Build.VERSION.SDK_INT < 29) {
            performHapticFeedback(if (event == HapticFeedbackConstants.CLOCK_TICK) event else HapticFeedbackConstants.LONG_PRESS)
        } else {
            val vibrator = if (Build.VERSION.SDK_INT >= 31) context.getSystemService(VibratorManager::class.java)?.defaultVibrator
                else context.getSystemService(Vibrator::class.java)
            if (vibrator?.hasVibrator() != true) return@runCatching false
            val effect = VibrationEffect.createPredefined(when (event) {
                HapticFeedbackConstants.CLOCK_TICK -> VibrationEffect.EFFECT_TICK
                HapticFeedbackConstants.CONFIRM -> VibrationEffect.EFFECT_DOUBLE_CLICK
                HapticFeedbackConstants.LONG_PRESS -> VibrationEffect.EFFECT_HEAVY_CLICK
                else -> VibrationEffect.EFFECT_CLICK
            })
            if (Build.VERSION.SDK_INT >= 33) vibrator.vibrate(effect, VibrationAttributes.Builder().setUsage(VibrationAttributes.USAGE_TOUCH).build())
            else vibrator.vibrate(effect, AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION).build())
            true
        }
    }.getOrDefault(false)
    if (BuildConfig.DEBUG) Log.i("BaseballPitchHaptics", "event=$event requested=$accepted predefined=${Build.VERSION.SDK_INT >= 29}")
    return accepted
}
