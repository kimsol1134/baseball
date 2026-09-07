package com.solkim.baseball.android

import com.solkim.baseball.design.BaseballColors
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import org.junit.Assert.*
import org.junit.Test
import kotlin.math.pow

class StatChangeTextTest {
    private fun colorAt(text: AnnotatedString, token: String): Color {
        val offset = text.text.indexOf(token)
        require(offset >= 0)
        return text.spanStyles.last { offset >= it.start && offset < it.end }.item.color
    }

    @Test fun mixedSkillEffectsKeepEachDirectionAndOriginalAccessibleText() {
        for (source in listOf("구위 30 → 35 · 제구 45 → 43", "Stuff 30 → 35 · Control 45 → 43", "球威 30 → 35 · 制球 45 → 43")) {
            val styled = statChangeText(source)
            assertEquals(source, styled.text)
            assertEquals(BaseballColors.textSecondary, colorAt(styled, "30"))
            assertEquals(BaseballColors.statIncrease, colorAt(styled, "35"))
            assertEquals(BaseballColors.statDecrease, colorAt(styled, "43"))
        }
    }

    @Test fun costsRecoveryZeroAndForecastRangesAreNumericDirections() {
        val text = statChangeText("피로 +6 · 회복 −8 · 팔 부담 +0 · 성장 +1~3 · 구속 -0.2")
        assertEquals(BaseballColors.statIncrease, colorAt(text, "+6"))
        assertEquals(BaseballColors.statDecrease, colorAt(text, "−8"))
        assertEquals(BaseballColors.textSecondary, colorAt(text, "+0"))
        assertEquals(BaseballColors.statIncrease, colorAt(text, "3"))
        assertEquals(BaseballColors.statDecrease, colorAt(text, "-0.2"))
        val range = statChangeText("+0~2")
        assertEquals(BaseballColors.textSecondary, colorAt(range, "+0"))
        assertEquals(BaseballColors.statIncrease, colorAt(range, "2"))
        assertTrue(statChangeText("2026-09-06 · 연습 3/9 · 2번째 생").spanStyles.isEmpty())
    }

    @Test fun directionColorsRemainReadableOnEveryDugoutSurface() {
        fun luminance(c: Color): Double {
            fun linear(v: Float) = if (v <= .04045f) v / 12.92 else ((v + .055) / 1.055).pow(2.4)
            return .2126 * linear(c.red) + .7152 * linear(c.green) + .0722 * linear(c.blue)
        }
        for (foreground in listOf(BaseballColors.statIncrease, BaseballColors.statDecrease)) {
            for (background in listOf(BaseballColors.canvas, BaseballColors.surface, BaseballColors.surfaceRaised, BaseballColors.surfaceSoft)) {
                assertTrue((luminance(foreground) + .05) / (luminance(background) + .05) >= 4.5)
            }
        }
    }
}
