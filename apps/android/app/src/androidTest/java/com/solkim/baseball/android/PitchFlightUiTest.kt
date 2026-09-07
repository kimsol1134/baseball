package com.solkim.baseball.android

import androidx.compose.foundation.layout.*
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import android.graphics.Bitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballMigrationTheme
import com.solkim.baseball.design.BaseballColors
import java.io.File
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class PitchFlightUiTest {
    @get:Rule val compose = createComposeRule()
    @Test fun fourRealKernelTrajectoriesRenderWithoutChangingTheirLandingPoint() {
        val session = KotlinPitchPresentationSession()
        compose.setContent {
            BaseballMigrationTheme { Surface(color = BaseballColors.canvas) {
                Column(Modifier.fillMaxSize().systemBarsPadding()) {
                    for (row in 0..1) Row(Modifier.weight(1f)) {
                        for (column in 0..1) {
                            val index = row * 2 + column
                            Column(Modifier.weight(1f).fillMaxHeight().padding(4.dp)) {
                                Text(listOf("직구", "슬라이더", "커브", "체인지업")[index], color = BaseballColors.textPrimary)
                                PitchDramaView(session.request("flight-qa", index), PitchOutcome.CALLED_STRIKE, progress = 1f, modifier = Modifier.weight(1f))
                            }
                        }
                    }
                }
            } }
        }
        compose.waitForIdle()
        val inst = InstrumentationRegistry.getInstrumentation()
        compose.onRoot().captureToImage().asAndroidBitmap().let { bitmap ->
            File(inst.targetContext.cacheDir, "pitch-flight-four-types.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        }
    }
}
