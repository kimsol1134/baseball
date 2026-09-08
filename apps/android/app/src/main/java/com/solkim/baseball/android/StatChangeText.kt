package com.solkim.baseball.android

import androidx.compose.material3.LocalTextStyle
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import com.solkim.baseball.design.BaseballColors

private val comparison = Regex("(\\d+(?:[.,]\\d+)?)\\s*→\\s*(\\d+(?:[.,]\\d+)?)")
private val signedChange = Regex("(?<![0-9A-Za-z])([+−-]\\d+(?:[.,]\\d+)?)(?:[~〜–]([+−-]?\\d+(?:[.,]\\d+)?))?%?")

/** Only called for stat/effect copy, after localization. Never changes the text or saved values. */
private val metricName = Regex("피로|팔 부담|실점|방어율|부상 위험|fatigue|arm strain|runs allowed|ERA|WHIP|疲労|腕の負担|失点|防御率|구위|제구|무브먼트|체력|신뢰|구속|성장|stuff|control|command|movement|stamina|trust|velocity|球威|制球|変化|スタミナ|信頼", RegexOption.IGNORE_CASE)
private val costlyIncrease = setOf("피로", "팔 부담", "실점", "방어율", "부상 위험", "fatigue", "arm strain", "runs allowed", "era", "whip", "疲労", "腕の負担", "失点", "防御率")

internal fun statChangeText(text: String, lowerIsBetter: Boolean? = null): AnnotatedString {
    fun number(value: String) = value.replace(",", "").replace('−', '-').toDouble()
    fun color(rawDelta: Double, position: Int): Color {
        val lower = lowerIsBetter ?: (metricName.findAll(text.take(position)).lastOrNull()?.value?.lowercase() in costlyIncrease)
        val delta = if (lower) -rawDelta else rawDelta
        return when {
        delta > 0 -> BaseballColors.statIncrease
        delta < 0 -> BaseballColors.statDecrease
        else -> BaseballColors.textSecondary
        }
    }
    return AnnotatedString.Builder(text).apply {
        comparison.findAll(text).forEach { match ->
            val before = requireNotNull(match.groups[1])
            val after = requireNotNull(match.groups[2])
            addStyle(SpanStyle(color = BaseballColors.textSecondary), before.range.first, before.range.last + 1)
            addStyle(SpanStyle(color = color(number(after.value) - number(before.value), match.range.first), fontWeight = FontWeight.Bold), after.range.first, after.range.last + 1)
        }
        signedChange.findAll(text).forEach { match ->
            val first = requireNotNull(match.groups[1])
            val last = match.groups[2]
            addStyle(SpanStyle(color = color(number(first.value), match.range.first), fontWeight = FontWeight.Bold), first.range.first,
                if (last == null) match.range.last + 1 else first.range.last + 1)
            if (last != null) addStyle(SpanStyle(color = color(number(last.value), match.range.first), fontWeight = FontWeight.Bold), last.range.first, match.range.last + 1)
        }
    }.toAnnotatedString()
}

@Composable
internal fun StatChangeText(
    text: String,
    modifier: Modifier = Modifier,
    style: TextStyle = LocalTextStyle.current,
    color: Color = BaseballColors.textPrimary,
    fontWeight: FontWeight? = null,
    verbatim: Boolean = false,
    lowerIsBetter: Boolean? = null,
) {
    val copy = rememberGameCopy()
    val localized = if (verbatim) text else copy.legacy(text)
    val annotated = remember(localized, lowerIsBetter) { statChangeText(localized, lowerIsBetter) }
    androidx.compose.material3.Text(annotated, modifier = modifier, style = style, color = color, fontWeight = fontWeight)
}
