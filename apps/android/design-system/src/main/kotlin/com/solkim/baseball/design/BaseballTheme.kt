package com.solkim.baseball.design

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/**
 * Midnight Dugout tokens. Values match iOS `DesignSystem.swift` / desktop `:root`.
 * This file is the Android color source; call sites should not invent new hex.
 */
public object BaseballColors {
    public val canvas: Color = Color(0xFF080D0B)
    public val surface: Color = Color(0xFF101815)
    public val surfaceRaised: Color = Color(0xFF17231E)
    public val surfaceSoft: Color = Color(0xFF1E2B25)
    public val border: Color = Color(0xFF3F554B)
    public val textPrimary: Color = Color(0xFFF1F4EE)
    public val textSecondary: Color = Color(0xFFB4C1BB)
    public val textTertiary: Color = Color(0xFF84968E)
    public val action: Color = Color(0xFFB7F36B)
    public val actionInk: Color = Color(0xFF10200D)
    public val actionSoft: Color = Color(0xFF243A20)
    public val milestone: Color = Color(0xFFD8B565)
    public val positive: Color = Color(0xFF55C58A)
    public val warning: Color = Color(0xFFF0A94A)
    public val negative: Color = Color(0xFFEF746A)
    public val fieldChalk: Color = Color(0xFFDCE5DE)
    public val fieldNight: Color = Color(0xFF050A15)
    public val avatarSkin: List<Color> = listOf(
        Color(0xFFF2CFA5), Color(0xFFE8BD8F), Color(0xFFD9A878), Color(0xFFC98E5F), Color(0xFFB97A4E),
    )
    public val avatarHair: List<Color> = listOf(Color(0xFF20242B), Color(0xFF3A2D22), Color(0xFF54402C), Color(0xFF6D6F76))
    public val avatarJersey: List<Color> = listOf(
        Color(0xFF3D5A44), Color(0xFF2F4858), Color(0xFF5A4632), Color(0xFF44415A), Color(0xFF5C3A3A),
    )
    public val avatarCap: Color = Color(0xFF274232)
    public val avatarCapBrim: Color = Color(0xFF1C3125)
    public val avatarHelmet: Color = Color(0xFF32405C)
    public val avatarMask: Color = Color(0xFF8B93A1)
    public val avatarLine: Color = Color(0xFF1A1D22)
    public val avatarHighlight: Color = Color(0xFFFFFFFF)
}

private val DugoutColors = darkColorScheme(
    primary = BaseballColors.action,
    onPrimary = BaseballColors.actionInk,
    secondary = BaseballColors.milestone,
    onSecondary = BaseballColors.actionInk,
    background = BaseballColors.canvas,
    onBackground = BaseballColors.textPrimary,
    surface = BaseballColors.surface,
    onSurface = BaseballColors.textPrimary,
    surfaceVariant = BaseballColors.surfaceRaised,
    onSurfaceVariant = BaseballColors.textSecondary,
    outline = BaseballColors.border,
    error = BaseballColors.negative,
    errorContainer = Color(0xFF261816),
    onErrorContainer = BaseballColors.textPrimary,
)

@Composable
fun BaseballMigrationTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = DugoutColors, content = content)
}
