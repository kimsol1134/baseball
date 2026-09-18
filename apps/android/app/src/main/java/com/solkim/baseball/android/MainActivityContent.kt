package com.solkim.baseball.android

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import com.solkim.baseball.application.GameCopyArgument
import com.solkim.baseball.application.ScreenId
import com.solkim.baseball.application.ScreenProjection
import com.solkim.baseball.application.SeedChallengeRules
import com.solkim.baseball.design.BaseballMigrationTheme

@OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)
@Composable
internal fun MainActivity.CareerRoot() {
    val store = (application as BaseballApplication).gameStore

        val state by store.state.collectAsState()
        BaseballMigrationTheme(highContrast = state.settings.highContrastEnabled) {
            val busy by store.busy.collectAsState()
            val preferred = screenController.preferredScreen()
            val current = selectedScreen?.takeIf {
                com.solkim.baseball.application.ScreenProjection.isReachable(state, it) || it == preferred
            } ?: preferred
            BackHandler(enabled = selectedScreen != null) {
                selectedScreen = null
            }
            if (openingMound) MoundLoadingView() else CareerShell(
                state = state,
                busy = busy || restoringProgress || actionInFlight || (navigationTapBlocked && current != previousActionScreen),
                actionError = actionError,
                currentScreen = current,
                commandContext = commandContext,
                platformState = platformUiState,
                onNavigate = {
                    selectedScreen = it.takeUnless { destination -> destination == screenController.preferredScreen() }
                    actionError = null
                },
                onAction = { action ->
                    if (action.actionId == "resetProgress") {
                        actionError = null
                        showResetConfirmation = true
                    } else performCareerAction(action)
                },
                onPlatformAction = ::performPlatformAction,
                onViewportExposure = ::recordViewportExposure,
                pendingSeedCode = pendingSeedCode,
                onSeedChallenge = { showSeedDialog = true },
                onExitSeedChallenge = { showSeedExitDialog = true },
            )
            LaunchedEffect(state.settings.musicEnabled) {
                if (lifecycle.currentState.isAtLeast(androidx.lifecycle.Lifecycle.State.RESUMED)) applyNativeSettings()
            }
            val copy = rememberGameCopy()
            returnNoticeKey?.let { key -> AlertDialog(
                modifier = Modifier.semantics { testTagsAsResourceId = true }.testTag("return.notice"),
                onDismissRequest = { returnNoticeKey = null }, title = { Text(copy.resolve("android.r3.reminder.title")) },
                text = { Text(copy.resolve(key)) },
                confirmButton = { TextButton(onClick = { returnNoticeKey = null }) { Text(copy.legacy("확인")) } },
                dismissButton = { if (key == "android.r3.reminder.blocked") TextButton(onClick = {
                    returnNoticeKey = null; returnPreferences.edit().putBoolean("pending", true).apply()
                    notificationSettingsReturnPending = true; platform.notifications.openSettings()
                }) { Text(copy.resolve("android.r3.reminder.settings")) } }) }
            if (showResetConfirmation) AlertDialog(
                modifier = Modifier.semantics { testTagsAsResourceId = true },
                onDismissRequest = { if (!busy) { showResetConfirmation = false; actionError = null } },
                title = { Text(copy.resolve("android.settings.reset-title")) },
                text = { Column {
                    Text(if (busy) copy.resolve("android.settings.reset-working") else copy.resolve("android.settings.reset-body", GameCopyArgument.UserText(copy.resolve("controls.backup.save"))))
                    actionError?.let { Text(it, modifier = Modifier.testTag("settings.reset.error"), color = MaterialTheme.colorScheme.error) }
                } },
                confirmButton = { TextButton(enabled = !busy, modifier = Modifier.testTag("settings.reset.confirm"), onClick = {
                    val action = screenController.projection(ScreenId.P027_SETTINGS).actions.firstOrNull { it.id == "resetProgress" && it.enabled }
                    if (action != null) performCareerAction(ScreenUiAction(ScreenId.P027_SETTINGS, action.id, action.payloads))
                }) { Text(copy.resolve("android.settings.reset-confirm"), color = MaterialTheme.colorScheme.error) } },
                dismissButton = { TextButton(enabled = !busy, modifier = Modifier.testTag("settings.reset.cancel"), onClick = {
                    showResetConfirmation = false; actionError = null
                }) { Text(copy.resolve("android.settings.reset-cancel")) } },
            )
            if (showSeedDialog) SeedChallengeDialog(pendingSeedCode, SeedChallengeRules.canStart(state) && !busy,
                onStart = { code, preset ->
                    rememberSeed(code)
                    showSeedDialog = false
                    performSeedCommand(SeedChallengeRules.startCommand(code, preset)) {
                        if (pendingSeedCode == code) {
                            pendingSeedCode = null
                            getSharedPreferences("seed-link", android.content.Context.MODE_PRIVATE).edit().remove("pending").apply()
                        }
                    }
                },
                onRemember = ::rememberSeed,
                onDismiss = { showSeedDialog = false })
            if (showSeedExitDialog) AlertDialog(modifier = Modifier.semantics { testTagsAsResourceId = true }, onDismissRequest = { showSeedExitDialog = false },
                title = { Text(copy.resolve("android.challenge.exit-title")) },
                text = { Text(copy.resolve("android.challenge.exit-body")) },
                confirmButton = { TextButton(enabled = !busy, modifier = Modifier.testTag("challenge.confirm-exit"), onClick = { showSeedExitDialog = false; performSeedCommand(SeedChallengeRules.endCommand()) }) { Text(copy.resolve("android.challenge.exit")) } },
                dismissButton = { TextButton(onClick = { showSeedExitDialog = false }) { Text(copy.resolve("android.challenge.keep-playing")) } })
            if (invalidSeedLink) AlertDialog(onDismissRequest = { invalidSeedLink = false },
                title = { Text(copy.resolve("android.challenge.invalid-title")) },
                text = { Text(copy.resolve("android.challenge.invalid-body")) },
                confirmButton = { TextButton(onClick = { invalidSeedLink = false }) { Text(copy.resolve("android.challenge.ok")) } })
            LaunchedEffect(pendingNotificationToken, state.revision, current, busy) {
                val token = pendingNotificationToken
                val rendered = ScreenProjection.isReachable(state, current) || current == preferred
                if (token != null && current == selectedScreen && rendered) {
                    platform.markNotificationNavigationCompleted(token)
                    pendingNotificationToken = null
                }
                if (!busy) retryPendingMatrixEvents()
                if (!busy) pendingNotificationSource?.let { source ->
                    pendingNotificationSource = null
                    reconcileNotificationTruth(source)
                }
            }
        }
}
