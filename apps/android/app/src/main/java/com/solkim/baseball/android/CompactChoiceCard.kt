package com.solkim.baseball.android

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.android.LocalizedGameText as Text

/** Descriptions may grow; the action itself stays a compact, clearly labelled touch target. */
@Composable
internal fun CompactChoiceCard(title: String, detail: String, enabled: Boolean, tag: String,
    actionLabel: String = "선택", onInfo: (() -> Unit)? = null, onSelect: () -> Unit) {
    Surface(color = BaseballColors.surfaceRaised, shape = MaterialTheme.shapes.medium) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(title, modifier = Modifier.weight(1f), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                onInfo?.let { TextButton(onClick = it, contentPadding = PaddingValues(horizontal = 8.dp)) { Text("정보") } }
                TextButton(onClick = onSelect, enabled = enabled, contentPadding = PaddingValues(horizontal = 8.dp),
                    modifier = Modifier.heightIn(min = 48.dp).testTag(tag).gameDescription("$title. $detail")) { Text(actionLabel) }
            }
            if (detail.isNotBlank()) Text(detail, modifier = Modifier.padding(bottom = 6.dp), style = MaterialTheme.typography.bodyMedium, color = BaseballColors.textSecondary)
        }
    }
}
