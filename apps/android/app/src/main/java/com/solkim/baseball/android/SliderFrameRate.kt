package com.solkim.baseball.android

import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.view.Display
import androidx.annotation.RequiresApi
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView

/** High-rate input is useful for the timing meter; restore the system vote when it leaves. */
@Composable
internal fun SliderFrameRate(enabled: Boolean) {
    if (Build.VERSION.SDK_INT >= 35) SliderFrameRate35(enabled)
}

@RequiresApi(35)
@Composable
private fun SliderFrameRate35(enabled: Boolean) {
    val view = LocalView.current
    val context = LocalContext.current
    val maximum = remember(view) {
        val display = view.display ?: context.getSystemService(DisplayManager::class.java).getDisplay(Display.DEFAULT_DISPLAY)
        (display?.supportedModes?.maxOfOrNull { it.refreshRate } ?: 60f).coerceAtMost(120f)
    }
    val qaRate = remember(context) {
        if (BuildConfig.DEBUG && context.packageName.endsWith(".compose.qa")) {
            context.getSharedPreferences("launch-qa", Context.MODE_PRIVATE).getInt("refresh-rate", 0)
        } else 0
    }
    val requested = if (!enabled) android.view.View.REQUESTED_FRAME_RATE_CATEGORY_DEFAULT
        else if (qaRate in setOf(60, 120)) minOf(qaRate.toFloat(), maximum) else maximum
    DisposableEffect(view, requested) {
        val previous = view.requestedFrameRate
        view.requestedFrameRate = requested
        onDispose { view.requestedFrameRate = previous }
    }
}
