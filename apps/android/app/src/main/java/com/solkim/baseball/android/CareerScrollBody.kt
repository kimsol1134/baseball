package com.solkim.baseball.android

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp

@Composable
internal fun CareerScrollBody(insets: PaddingValues, content: @Composable ColumnScope.() -> Unit) {
    val scroll = rememberScrollState()
    Column(Modifier.fillMaxSize().padding(insets).consumeWindowInsets(insets).clipToBounds()) {
        Column(Modifier.weight(1f).fillMaxWidth().clipToBounds().verticalScroll(scroll)
            .padding(horizontal = 20.dp, vertical = 16.dp).testTag("career.scrollBody"),
            verticalArrangement = Arrangement.spacedBy(16.dp)) {
            content()
            Spacer(Modifier.fillMaxWidth().height(1.dp).testTag("career.contentEnd"))
        }

    }
}
