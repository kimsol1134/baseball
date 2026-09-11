package com.solkim.baseball.android

import com.solkim.baseball.application.CareerAccess

import android.content.Intent
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import com.solkim.baseball.model.PitchAudioCue
import com.solkim.baseball.model.PitchHapticCue
import com.solkim.baseball.platform.NativePitchHaptics
import com.solkim.baseball.platform.NativePlaybackSettings
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

/** Output smoke in the disposable app; no player career is advanced to force a strikeout. */
@RunWith(AndroidJUnit4::class)
class PitchOutputDeviceTest {
    @Test fun preloadedStrikeBallAndStrikeoutPlayWithBasicMotorFallback() {
        val inst = InstrumentationRegistry.getInstrumentation()
        val context = inst.targetContext
        require(context.packageName == "com.solkim.baseball.android.reset.compose.qa")
        val app = context.applicationContext as BaseballApplication
        val audio = app.platform.audioHaptics
        val device = UiDevice.getInstance(inst)
        context.startActivity(requireNotNull(context.packageManager.getLaunchIntentForPackage(context.packageName)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        assertTrue(device.wait(Until.hasObject(By.res("action.enterSetup")), 15_000))
        val before = CareerAccess.school(app.gameStore.current)
        inst.runOnMainSync { audio.stopMusic(); audio.preparePitchSounds() }
        val end = SystemClock.uptimeMillis() + 5_000
        while (!audio.isPitchAudioReady() && SystemClock.uptimeMillis() < end) SystemClock.sleep(40)
        assertTrue(audio.isPitchAudioReady())
        val settings = NativePlaybackSettings(true, false, true, false)
        fun cue(cue: PitchAudioCue, haptic: PitchHapticCue? = null, wait: Long = 300) {
            inst.runOnMainSync { audio.playPitchCue(cue, settings, 42UL, haptic) }
            SystemClock.sleep(wait)
        }
        assertTrue(NativePitchHaptics.play(context, PitchHapticCue.GRIP, true))
        SystemClock.sleep(100)
        cue(PitchAudioCue.RELEASE)
        cue(PitchAudioCue.CATCH, PitchHapticCue.SUCCESS)
        cue(PitchAudioCue.STRIKE, wait = 600)
        cue(PitchAudioCue.RELEASE)
        cue(PitchAudioCue.CATCH, wait = 600)
        cue(PitchAudioCue.WEAK_CONTACT, PitchHapticCue.ERROR, wait = 500)
        cue(PitchAudioCue.RELEASE)
        cue(PitchAudioCue.SWING_MISS, PitchHapticCue.STRIKEOUT, wait = 400)
        cue(PitchAudioCue.STRIKEOUT, wait = 2_150)
        cue(PitchAudioCue.CHEER, wait = 700)
        cue(PitchAudioCue.FOUL, PitchHapticCue.FOUL)
        cue(PitchAudioCue.CONTACT, PitchHapticCue.HIT)
        cue(PitchAudioCue.CONTACT, PitchHapticCue.HOME_RUN)
        inst.runOnMainSync { audio.heartbeatBeat(0.45, settings) }
        SystemClock.sleep(300)
        inst.runOnMainSync { audio.stopHeartbeat() }
        assertFalse(NativePitchHaptics.play(context, PitchHapticCue.GRIP, false))
        inst.runOnMainSync { audio.stopEffects() }
        assertEquals(before, CareerAccess.school(app.gameStore.current))
    }
}
