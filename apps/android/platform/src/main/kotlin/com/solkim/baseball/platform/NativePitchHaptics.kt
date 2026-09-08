package com.solkim.baseball.platform

import android.content.Context
import android.content.pm.ApplicationInfo
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.util.Log
import com.solkim.baseball.model.PitchHapticCue

/** Short game-touch fallbacks for motors whose predefined effects are not implemented. */
public object NativePitchHaptics {
    public fun timings(cue: PitchHapticCue): LongArray = when (cue) {
        PitchHapticCue.FOUL -> longArrayOf(0, 16)
        PitchHapticCue.HIT -> longArrayOf(0, 32, 65, 22)
        PitchHapticCue.HOME_RUN -> longArrayOf(0, 38, 65, 32, 70, 22)
        PitchHapticCue.WALK -> longArrayOf(0, 20, 90, 20)
        PitchHapticCue.EDGE -> longArrayOf(0, 12)
        PitchHapticCue.SWEET -> longArrayOf(0, 18)
        PitchHapticCue.GRIP -> longArrayOf(0, 32)
        PitchHapticCue.RELEASE -> longArrayOf(0, 28)
        // A heavy first hit and a tight aftershock, distinct even on on/off-only motors.
        PitchHapticCue.PERFECT -> longArrayOf(0, 75, 30, 45)
        PitchHapticCue.PERFECT_ZONE -> longArrayOf(0, 20)
        PitchHapticCue.ERROR -> longArrayOf(0, 18, 80, 18)
        PitchHapticCue.SUCCESS -> longArrayOf(0, 18, 60, 28)
        PitchHapticCue.STRIKEOUT -> longArrayOf(0, 24, 55, 30, 65, 36)
    }

    private fun vibrator(context: Context): Vibrator? = if (Build.VERSION.SDK_INT >= 31)
        context.getSystemService(VibratorManager::class.java)?.defaultVibrator else context.getSystemService(Vibrator::class.java)

    public fun play(context: Context, cue: PitchHapticCue, enabled: Boolean): Boolean {
        val systemEnabled = runCatching { Settings.System.getInt(context.contentResolver, Settings.System.HAPTIC_FEEDBACK_ENABLED, 1) == 1 }.getOrDefault(true)
        if (!enabled || !systemEnabled) return false
        return runCatching {
            val motor = vibrator(context) ?: return@runCatching false
            if (!motor.hasVibrator()) return@runCatching false
            val preset = when (cue) {
                PitchHapticCue.EDGE, PitchHapticCue.SWEET -> VibrationEffect.EFFECT_TICK
                PitchHapticCue.GRIP, PitchHapticCue.PERFECT_ZONE -> VibrationEffect.EFFECT_HEAVY_CLICK
                PitchHapticCue.PERFECT, PitchHapticCue.SUCCESS, PitchHapticCue.STRIKEOUT -> VibrationEffect.EFFECT_DOUBLE_CLICK
                else -> VibrationEffect.EFFECT_CLICK
            }
            // Perfect uses our impact pattern even when the device supports a softer stock double click.
            val optimized = cue != PitchHapticCue.PERFECT && Build.VERSION.SDK_INT >= 30 && motor.areEffectsSupported(preset).firstOrNull() == Vibrator.VIBRATION_EFFECT_SUPPORT_YES
            val amplitudePerfect = cue == PitchHapticCue.PERFECT && motor.hasAmplitudeControl()
            val effect = when {
                amplitudePerfect -> VibrationEffect.createWaveform(timings(cue), intArrayOf(0, 255, 0, 220), -1)
                optimized -> VibrationEffect.createPredefined(preset)
                else -> VibrationEffect.createWaveform(timings(cue), -1)
            }
            if (Build.VERSION.SDK_INT >= 33) motor.vibrate(effect, VibrationAttributes.Builder().setUsage(VibrationAttributes.USAGE_TOUCH).build())
            else motor.vibrate(effect, AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION).build())
            if (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) Log.i("BaseballPitchHaptics", "cue=$cue route=${if (amplitudePerfect) "amplitude-waveform" else if (optimized) "preset" else "waveform"} requested=true")
            true
        }.getOrDefault(false)
    }

    public fun cancel(context: Context) { runCatching { vibrator(context)?.cancel() } }
}
