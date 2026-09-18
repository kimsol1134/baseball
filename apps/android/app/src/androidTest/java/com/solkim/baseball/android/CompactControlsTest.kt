package com.solkim.baseball.android

import android.content.res.Configuration
import android.os.LocaleList
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import java.util.Locale

class CompactControlsTest {
    @get:Rule val compose = createComposeRule()
    @Test fun pitchNamesStayWholeAcrossLocalesAndLargeText() {
        var language by mutableStateOf("ko")
        var scale by mutableFloatStateOf(1f)
        compose.setContent {
            val config = Configuration(LocalConfiguration.current).apply { setLocales(LocaleList(Locale.forLanguageTag(language))) }
            CompositionLocalProvider(LocalConfiguration provides config, LocalDensity provides Density(LocalDensity.current.density, scale)) {
                BaseballMigrationTheme { Box(Modifier.width(320.dp)) {
                    PitchTypeChoices(PitchKind.entries, PitchKind.FOUR_SEAM, true, null, "") {}
                } }
            }
        }
        for (locale in listOf("ko", "en", "ja")) for (font in listOf(1f, 1.6f)) {
            compose.runOnIdle { language = locale; scale = font }
            for (type in PitchKind.entries) {
                val node = compose.onNodeWithTag("pitch.type.${type.wire}").assertIsDisplayed()
                val layouts = mutableListOf<TextLayoutResult>()
                node.performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(layouts) }
                assertTrue(layouts.isNotEmpty())
                assertTrue("$locale $font ${type.wire}: " + layouts.map { "${it.layoutInput.text.text} lines=${it.lineCount} overflow=${it.hasVisualOverflow} width=${it.didOverflowWidth} height=${it.didOverflowHeight} size=${it.size} constraints=${it.layoutInput.constraints}" }, layouts.all { it.lineCount == 1 && it.getLineRight(0) <= it.size.width + 1f })
            }
        }
    }
    @Test fun lengthyDescriptionsNeverInflateTheChoiceButton() {
        var selected = 0
        compose.setContent { BaseballMigrationTheme { Surface {
            Column(Modifier.width(320.dp).verticalScroll(rememberScrollState())) {
                CompactChoiceCard("학교를 선택하기 전에 읽을 수 있는 긴 학교 이름", "훈련 지원과 코치의 지도 방침을 충분히 읽을 수 있도록 설명은 버튼 밖에 표시합니다.", true, "choice.test") { selected++ }
            }
        } } }
        val node = compose.onNodeWithTag("choice.test").assertIsDisplayed()
        val density = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext.resources.displayMetrics.density
        assertTrue(node.fetchSemanticsNode().boundsInWindow.height / density <= 52f)
        node.performClick()
        assertEquals(1, selected)
    }
}
