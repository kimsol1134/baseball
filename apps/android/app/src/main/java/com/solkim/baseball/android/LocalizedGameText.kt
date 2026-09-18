package com.solkim.baseball.android

import androidx.compose.material3.LocalTextStyle
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import com.solkim.baseball.application.CareerUiRules
import com.solkim.baseball.application.GameCopy
import com.solkim.baseball.application.GameLanguage

@Composable
internal fun rememberGameCopy(): GameCopy {
    val language = GameLanguage.fromTag(LocalConfiguration.current.locales[0].toLanguageTag())
    return remember(language) { GameCopy(language) }
}

/** TalkBack uses the same presentation language as the visible text. */
@Composable
internal fun Modifier.gameDescription(text: String): Modifier {
    val copy = rememberGameCopy()
    val app = LocalContext.current.applicationContext as? BaseballApplication
    val state = app?.gameStore?.current
    val names = state?.let(CareerUiRules::userDisplayNames).orEmpty()
    val description = copy.legacy(text, names)
    return semantics { contentDescription = description }
}

/** All legacy string adaptation happens at the visual boundary, never in game state. */
@Composable
internal fun LocalizedGameText(
    text: String,
    modifier: Modifier = Modifier,
    color: Color = Color.Unspecified,
    fontSize: TextUnit = TextUnit.Unspecified,
    fontStyle: FontStyle? = null,
    fontWeight: FontWeight? = null,
    fontFamily: FontFamily? = null,
    letterSpacing: TextUnit = TextUnit.Unspecified,
    textDecoration: TextDecoration? = null,
    textAlign: TextAlign? = null,
    lineHeight: TextUnit = TextUnit.Unspecified,
    overflow: TextOverflow = TextOverflow.Clip,
    softWrap: Boolean = true,
    maxLines: Int = Int.MAX_VALUE,
    minLines: Int = 1,
    onTextLayout: ((TextLayoutResult) -> Unit)? = null,
    style: TextStyle = LocalTextStyle.current,
    verbatim: Boolean = false,
) {
    val copy = rememberGameCopy()
    val app = LocalContext.current.applicationContext as? BaseballApplication
    val state = app?.gameStore?.current
    val userTexts = remember(state?.revision) {
        state?.let(CareerUiRules::userDisplayNames).orEmpty()
    }
    androidx.compose.material3.Text(
        text = if (verbatim) text else copy.legacy(text, userTexts), modifier = modifier, color = color,
        fontSize = fontSize, fontStyle = fontStyle, fontWeight = fontWeight, fontFamily = fontFamily,
        letterSpacing = letterSpacing, textDecoration = textDecoration, textAlign = textAlign, lineHeight = lineHeight,
        overflow = overflow, softWrap = softWrap, maxLines = maxLines, minLines = minLines,
        onTextLayout = onTextLayout, style = style,
    )
}
