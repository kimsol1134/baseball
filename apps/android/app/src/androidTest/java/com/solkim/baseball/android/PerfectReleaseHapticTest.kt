package com.solkim.baseball.android

import android.os.SystemClock
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Test
import org.junit.runner.RunWith

/** Physical comparison through the same release path as the slider; never edits a career. */
@RunWith(AndroidJUnit4::class)
class PerfectReleaseHapticTest {
    @Test fun normalThenPerfectRelease() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            lateinit var feedback: PitchWindUpFeedback
            scenario.onActivity { activity ->
                feedback = PitchWindUpFeedback(activity.window.decorView)
                feedback.release(0.8, perfect = false, enabled = true)
            }
            SystemClock.sleep(650)
            scenario.onActivity { feedback.release(1.0, perfect = true, enabled = true) }
            SystemClock.sleep(250)
            scenario.onActivity { feedback.stop() }
        }
    }
}
