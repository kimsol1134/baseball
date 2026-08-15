package com.solkim.baseball.android

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.Density
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.InstrumentationRegistry
import com.solkim.baseball.application.GameAggregateState
import com.solkim.baseball.application.Phase8CommandContext
import com.solkim.baseball.application.Phase8KoreaClock
import com.solkim.baseball.application.Phase8ScreenId
import com.solkim.baseball.application.Phase8ScreenProjection
import com.solkim.baseball.design.BaseballMigrationTheme
import com.solkim.baseball.platform.NotificationPermissionTruth
import com.solkim.baseball.platform.NativeNotificationPermission
import com.solkim.baseball.platform.PlatformAction
import com.solkim.baseball.platform.PlatformActionCodec
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Native platform surfaces must expose real state and the exact payload captured at tap time. */
@RunWith(AndroidJUnit4::class)
class Phase9PlatformSemanticsTest {
    @get:Rule
    val composeRule = createComposeRule()

    private val context = Phase8CommandContext(Phase8KoreaClock { LocalDate.of(2026, 8, 14) })

    @Test
    fun notificationPermissionActionCapturesCanonicalTypedPayload() {
        val state = GameAggregateState.initial("phase9-platform-settings")
        val model = Phase8ScreenProjection.project(state, Phase8ScreenId.P027_SETTINGS, context)
        var captured by mutableStateOf<Phase9UiAction?>(null)
        composeRule.setContent {
            BaseballMigrationTheme {
                Phase9PlatformSurface(
                    state = state,
                    model = model,
                    platformState = Phase9PlatformUiState(NotificationPermissionTruth.REQUESTABLE, null),
                    onAction = { captured = it },
                )
            }
        }

        composeRule.onNodeWithText("알림 권한 요청").assertHasClickAction().performClick()
        val action = requireNotNull(captured)
        assertEquals(PlatformAction.REQUEST_NOTIFICATION_PERMISSION, action.payload.action)
        assertEquals(action.payload, PlatformActionCodec.decode(action.encodedPayload))
        assertEquals(state.revision, action.payload.expectedRevision)
        assertEquals(state.commitment, action.payload.stateCommitment)
    }

    @Test
    fun blockedNotificationUsesSettingsTruthAndRemainsReadableAtRequiredFontScales() {
        val state = GameAggregateState.initial("phase9-platform-blocked")
        val model = Phase8ScreenProjection.project(state, Phase8ScreenId.P027_SETTINGS, context)
        var fontScale by mutableStateOf(1.0f)
        composeRule.setContent {
            CompositionLocalProvider(LocalDensity provides Density(1f, fontScale)) {
                BaseballMigrationTheme {
                    Phase9PlatformSurface(
                        state = state,
                        model = model,
                        platformState = Phase9PlatformUiState(NotificationPermissionTruth.BLOCKED, null),
                        onAction = {},
                    )
                }
            }
        }

        listOf(1.0f, 1.3f, 1.5f, 2.0f).forEach { scale ->
            fontScale = scale
            composeRule.waitForIdle()
            composeRule.onNodeWithText("알림 설정 열기").assertIsDisplayed()
            composeRule.onNodeWithText("기기 설정에서 알림이 차단됨").assertIsDisplayed()
        }
    }

    @Test
    fun devicePermissionTruthIsReadFromTheSystemOnEveryCheck() {
        val permission = NativeNotificationPermission(InstrumentationRegistry.getTargetContext())
        val first = permission.truth()
        val second = permission.truth()
        assertEquals(first, second)
        assertEquals(true, first in NotificationPermissionTruth.entries)
    }

    @Test
    fun productShellIncludesNativeSettingsSurface() {
        val state = GameAggregateState.initial("phase9-shell-settings")
        composeRule.setContent {
            BaseballMigrationTheme {
                Phase8Shell(
                    state = state,
                    busy = false,
                    actionError = null,
                    currentScreen = Phase8ScreenId.P027_SETTINGS,
                    commandContext = context,
                    onNavigate = {},
                    onAction = {},
                    platformState = Phase9PlatformUiState(NotificationPermissionTruth.REQUESTABLE, null),
                    onPlatformAction = {},
                )
            }
        }

        composeRule.onNodeWithText("기기 알림").performScrollTo().assertIsDisplayed()
        composeRule.onNodeWithText("알림 권한 요청").assertHasClickAction()
    }

    @Test
    fun viewportExposureWaitsForActualIntersectionBeforeEmitting() {
        val exposures = mutableListOf<Phase9ViewportExposure>()
        composeRule.setContent {
            Box(Modifier.fillMaxSize()) {
                Column(
                    Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState()),
                ) {
                    // Keep this fixture below even the tallest API35 emulator viewport. The
                    // assertion is about intersection, not a device-specific fold height.
                    Spacer(Modifier.height(4000.dp))
                    Phase9ViewportExposureBox(
                        exposure = Phase9ViewportExposure(
                            eventName = "weekly_program_opened",
                            scope = "weekly:viewport-test",
                            properties = listOf("week_key" to "2026-W33", "source" to "records", "completed_tasks" to "0"),
                        ),
                        onExposed = { exposures += it },
                    ) {
                        Text("이번 주 기록 카드")
                    }
                }
            }
        }

        composeRule.waitForIdle()
        assertTrue(exposures.isEmpty())
        composeRule.onNodeWithText("이번 주 기록 카드").performScrollTo().assertIsDisplayed()
        composeRule.waitForIdle()
        assertEquals(1, exposures.size)
        composeRule.onNodeWithText("이번 주 기록 카드").performScrollTo()
        composeRule.waitForIdle()
        assertEquals(1, exposures.size)
    }
}
