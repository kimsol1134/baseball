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
internal fun statChangeText(text: String): AnnotatedString {
    fun number(value: String) = value.replace(",", "").replace('−', '-').toDouble()
    fun color(delta: Double) = when {
        delta > 0 -> BaseballColors.statIncrease
        delta < 0 -> BaseballColors.statDecrease
        else -> BaseballColors.textSecondary
    }
    return AnnotatedString.Builder(text).apply {
        comparison.findAll(text).forEach { match ->
            val before = requireNotNull(match.groups[1])
            val after = requireNotNull(match.groups[2])
            addStyle(SpanStyle(color = BaseballColors.textSecondary), before.range.first, before.range.last + 1)
            addStyle(SpanStyle(color = color(number(after.value) - number(before.value)), fontWeight = FontWeight.Bold), after.range.first, after.range.last + 1)
        }
        signedChange.findAll(text).forEach { match ->
            val first = requireNotNull(match.groups[1])
            val last = match.groups[2]
            addStyle(SpanStyle(color = color(number(first.value)), fontWeight = FontWeight.Bold), first.range.first,
                if (last == null) match.range.last + 1 else first.range.last + 1)
            if (last != null) addStyle(SpanStyle(color = color(number(last.value)), fontWeight = FontWeight.Bold), last.range.first, match.range.last + 1)
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
) {
    val copy = rememberGameCopy()
    val localized = if (verbatim) text else copy.legacy(text)
    val annotated = remember(localized) { statChangeText(localized) }
    androidx.compose.material3.Text(annotated, modifier = modifier, style = style, color = color, fontWeight = fontWeight)
}
