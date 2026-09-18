package com.solkim.baseball.android

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.PitchKind
import com.solkim.baseball.application.PitchHudProjection
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.android.LocalizedGameText as Text

/** Wrap whole choices before wrapping their names. Nicknames never displace the pitch type. */
@Composable
internal fun PitchTypeChoices(types: List<PitchKind>, selected: PitchKind?, enabled: Boolean,
    signature: String?, nickname: String, onSelect: (PitchKind) -> Unit) {
    val copy = rememberGameCopy()
    val style = MaterialTheme.typography.labelMedium
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val labels = types.map { copy.legacy(PitchHudProjection.koreanLabel(it)) }
        val widths = labels.map { with(density) { measurer.measure(it, style).size.width.toDp() } + 16.dp }
        val columns = when {
            (widths.maxOfOrNull { it.value } ?: 0f) * types.size + 4 * (types.size - 1).coerceAtLeast(0) <= maxWidth.value -> types.size.coerceAtLeast(1)
            (widths.maxOfOrNull { it.value } ?: 0f) * 2 + 4 <= maxWidth.value -> 2
            else -> 1
        }
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            types.chunked(columns).forEach { row ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    row.forEach { type ->
                        val chosen = type == selected
                        Surface(onClick = { onSelect(type) }, enabled = enabled,
                            color = if (chosen) BaseballColors.action else BaseballColors.surfaceSoft,
                            border = BorderStroke(1.dp, if (chosen) BaseballColors.action else BaseballColors.border), shape = RoundedCornerShape(8.dp),
                            modifier = Modifier.weight(1f).heightIn(min = 48.dp).testTag("pitch.type.${type.wire}").semantics { this.selected = chosen; role = Role.RadioButton }) {
                            Column(Modifier.padding(horizontal = 6.dp, vertical = 5.dp), verticalArrangement = Arrangement.Center) {
                                Text(copy.legacy(PitchHudProjection.koreanLabel(type)), verbatim = true, style = style,
                                    color = if (chosen) BaseballColors.actionInk else BaseballColors.textPrimary)
                                if (signature == type.wire && nickname.isNotBlank()) Text(nickname, verbatim = true, maxLines = 1,
                                    overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.labelSmall,
                                    color = if (chosen) BaseballColors.actionInk else BaseballColors.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }
}
