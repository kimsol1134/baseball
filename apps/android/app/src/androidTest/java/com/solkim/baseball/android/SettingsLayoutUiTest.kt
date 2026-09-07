package com.solkim.baseball.android

import android.content.res.Configuration
import android.graphics.Bitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.Density
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballMigrationTheme
import com.solkim.baseball.platform.NotificationPermissionTruth
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.Locale

@RunWith(AndroidJUnit4::class)
class SettingsLayoutUiTest {
    @get:Rule val compose = createComposeRule()
    @Test fun largerTextKeepsSettingsAndNestedHelpReachableInEveryLanguage() {
        var language by mutableStateOf("ko")
        val state = GameAggregateState.initial("settings-layout")
        compose.setContent {
            val config = Configuration(LocalConfiguration.current).apply { setLocale(Locale.forLanguageTag(language)) }
            CompositionLocalProvider(LocalConfiguration provides config, LocalDensity provides Density(LocalDensity.current.density, 2f)) {
                BaseballMigrationTheme {
                    SettingsScreen(state, Phase8ScreenProjection.project(state, Phase8ScreenId.P027_SETTINGS, Phase8CommandContext()), false, null,
                        Phase9PlatformUiState(NotificationPermissionTruth.BLOCKED, null), {}, {}, {}, {}, {})
                }
            }
        }
        for (code in listOf("ko", "en", "ja")) {
            language = code
            compose.waitForIdle()
            compose.onNodeWithTag("settings.sound").performScrollTo().assertIsDisplayed().assertIsOn()
            compose.onNodeWithTag("settings.assist").assertDoesNotExist()
            compose.mainClock.advanceTimeBy(1_000)
            compose.waitForIdle()
            val inst = InstrumentationRegistry.getInstrumentation()
            compose.onRoot().captureToImage().asAndroidBitmap().let { bitmap ->
                File(inst.targetContext.cacheDir, "settings-v2-large-$code.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
            }
            compose.onNodeWithTag("settings.open.help").performScrollTo().performClick()
            compose.onNodeWithTag("settings.open.glossary").performScrollTo().performClick()
            compose.onNodeWithTag("settings.term.definition").assertDoesNotExist()
            compose.onNodeWithTag("settings.term.command").performScrollTo().performClick()
            compose.onNodeWithTag("settings.term.definition").performScrollTo().assertIsDisplayed()
            compose.onNodeWithTag("settings.back").performClick()
            compose.onNodeWithTag("settings.back").performClick()
            compose.onNodeWithTag("settings.back").performClick()
            compose.onNodeWithTag("settings.open.controls").performScrollTo().performClick()
            compose.onNodeWithTag("settings.assist").performScrollTo().assertIsDisplayed().assertIsOff()
            compose.onNodeWithTag("settings.motion").performScrollTo().assertIsDisplayed()
            compose.onNodeWithTag("settings.back").performClick()
        }
    }
}
