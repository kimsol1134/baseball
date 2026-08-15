package com.solkim.baseball.design

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val MigrationColors = darkColorScheme(
    primary = Color(0xFFC8A96B),
    secondary = Color(0xFF8DB5A4),
    background = Color(0xFF101820),
    surface = Color(0xFF19242D),
    onBackground = Color(0xFFF4F1E8),
    onSurface = Color(0xFFF4F1E8),
)

@Composable
fun BaseballMigrationTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = MigrationColors, content = content)
}
