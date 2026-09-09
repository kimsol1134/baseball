package com.solkim.baseball.android

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.platform.NotificationPermissionTruth
import com.solkim.baseball.platform.PlatformAction
import com.solkim.baseball.android.LocalizedGameText as Text

private enum class SettingsPage(val key: String) {
    ROOT("title"), CONTROLS("controls"), NOTIFICATIONS("notifications"), STORAGE("storage"),
    HELP("help"), PITCH_HELP("pitch-help"), GLOSSARY("glossary");
    val parent: SettingsPage get() = if (this in setOf(PITCH_HELP, GLOSSARY)) HELP else ROOT
}

@OptIn(ExperimentalMaterial3Api::class, androidx.compose.ui.ExperimentalComposeUiApi::class)
@Composable
internal fun SettingsScreen(
    state: GameAggregateState,
    model: Phase8ScreenModel,
    busy: Boolean,
    actionError: String?,
    platformState: Phase9PlatformUiState,
    onAction: (Phase8UiAction) -> Unit,
    onPlatformAction: (Phase9UiAction) -> Unit,
    onExit: () -> Unit,
    onRestored: (GameAggregateState) -> Unit,
    bottomBar: @Composable () -> Unit,
) {
    val copy = rememberGameCopy()
    fun label(key: String) = copy.resolve("settings2.$key")
    var page by rememberSaveable { mutableStateOf(SettingsPage.ROOT) }
    var query by rememberSaveable { mutableStateOf("") }
    var expandedTerm by rememberSaveable { mutableStateOf<String?>(null) }
    var linkError by remember { mutableStateOf<String?>(null) }
    val uri = LocalUriHandler.current
    fun back() {
        linkError = null
        if (page == SettingsPage.GLOSSARY && expandedTerm != null) expandedTerm = null
        else if (page == SettingsPage.ROOT) onExit() else page = page.parent
    }
    fun submit(id: String) {
        model.actions.firstOrNull { it.id == id && it.enabled }?.takeUnless { busy }?.let {
            onAction(Phase8UiAction(model.id, it.id, it.payloads))
        }
    }
    BackHandler { back() }
    Scaffold(
        modifier = Modifier.fillMaxSize().semantics { testTagsAsResourceId = true },
        containerColor = BaseballColors.canvas,
        topBar = {
            TopAppBar(title = { Text(label(page.key), verbatim = true, modifier = Modifier.testTag("settings.title")) },
                navigationIcon = { if (page != SettingsPage.ROOT) TextButton(onClick = ::back, modifier = Modifier.testTag("settings.back")) {
                    Text("‹", modifier = Modifier.semantics { contentDescription = label("back") }, style = MaterialTheme.typography.headlineMedium)
                } },
                actions = { Box(Modifier.size(40.dp), contentAlignment = Alignment.Center) {
                    if (busy) CircularProgressIndicator(Modifier.size(18.dp).semantics { contentDescription = label("saving") }, strokeWidth = 2.dp)
                } })
        },
        bottomBar = bottomBar,
    ) { insets ->
        Column(Modifier.fillMaxSize().padding(insets).consumeWindowInsets(insets)) {
            (actionError ?: linkError)?.let { message ->
                Text(message, modifier = Modifier.fillMaxWidth().padding(20.dp).testTag("settings.error").semantics { liveRegion = LiveRegionMode.Polite },
                    color = BaseballColors.warning, style = MaterialTheme.typography.bodyMedium)
            }
            key(page) {
                Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    when (page) {
                        SettingsPage.ROOT -> {
                            SettingsGroup {
                                SettingsSwitch(label("sound"), state.settings.soundEnabled, !busy, "settings.sound") { submit("toggleSound") }
                                HorizontalDivider()
                                SettingsSwitch(label("music"), state.settings.musicEnabled, !busy, "settings.music") { submit("toggleMusic") }
                                HorizontalDivider()
                                SettingsSwitch(label("haptics"), state.settings.hapticsEnabled, !busy, "settings.haptics") { submit("toggleHaptics") }
                            }
                            SettingsGroup {
                                for ((index, target) in listOf(SettingsPage.CONTROLS, SettingsPage.NOTIFICATIONS, SettingsPage.STORAGE, SettingsPage.HELP).withIndex()) {
                                    if (index > 0) HorizontalDivider()
                                    SettingsLink(label(target.key), "settings.open.${target.key}") { page = target }
                                }
                            }
                        }
                        SettingsPage.CONTROLS -> {
                            Text(label("manual-default"), verbatim = true, color = BaseballColors.textSecondary, style = MaterialTheme.typography.bodyMedium)
                            SettingsGroup {
                                SettingsSwitch(label("assist"), state.settings.autoReleaseEnabled, !busy, "settings.assist") { submit("toggleAutoRelease") }
                                HorizontalDivider()
                                SettingsSwitch(label("contrast"), state.settings.highContrastEnabled, !busy, "settings.contrast") { submit("toggleContrast") }
                                HorizontalDivider()
                                SettingsSwitch(label("motion"), state.settings.reducedMotionEnabled, !busy, "settings.motion") { submit("toggleMotion") }
                            }
                            Text(label("system-font"), verbatim = true, color = BaseballColors.textSecondary, style = MaterialTheme.typography.bodySmall)
                        }
                        SettingsPage.NOTIFICATIONS -> {
                            val truthKey = when (platformState.notificationTruth) {
                                NotificationPermissionTruth.ALLOWED -> "notification-on"
                                NotificationPermissionTruth.REQUESTABLE -> "notification-off"
                                NotificationPermissionTruth.DENIED, NotificationPermissionTruth.BLOCKED -> "notification-blocked"
                                NotificationPermissionTruth.UNAVAILABLE -> "notification-unavailable"
                            }
                            Text(label(truthKey), verbatim = true, style = MaterialTheme.typography.titleMedium, modifier = Modifier.testTag("settings.notification.state"))
                            Text(label("notification-detail"), verbatim = true, style = MaterialTheme.typography.bodyMedium, color = BaseballColors.textSecondary)
                            val action = if (platformState.notificationTruth == NotificationPermissionTruth.REQUESTABLE) PlatformAction.REQUEST_NOTIFICATION_PERMISSION else PlatformAction.OPEN_NOTIFICATION_SETTINGS
                            OutlinedButton(onClick = { onPlatformAction(capturePlatformAction(state, model.id, action)) },
                                enabled = !busy && platformState.notificationTruth != NotificationPermissionTruth.UNAVAILABLE,
                                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("settings.notification.change")) {
                                Text(label(if (action == PlatformAction.REQUEST_NOTIFICATION_PERMISSION) "notification-enable" else "notification-settings"), verbatim = true)
                            }
                        }
                        SettingsPage.STORAGE -> {
                            if (!CareerBackup.isAvailable(state)) {
                                Text(label("challenge-storage"), verbatim = true, color = BaseballColors.textSecondary)
                            } else {
                                CareerBackupControls(state, busy = busy, onContinue = onRestored)
                                HorizontalDivider(Modifier.padding(vertical = 4.dp))
                                model.actions.firstOrNull { it.id == "resetProgress" }?.let { action ->
                                    OutlinedButton(onClick = { submit(action.id) }, enabled = action.enabled && !busy,
                                        modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("action.resetProgress")) {
                                        Text(label("delete"), verbatim = true, color = MaterialTheme.colorScheme.error)
                                    }
                                }
                            }
                        }
                        SettingsPage.HELP -> SettingsGroup {
                            SettingsLink(label("pitch-help"), "settings.open.pitch-help") { page = SettingsPage.PITCH_HELP }
                            HorizontalDivider()
                            SettingsLink(label("glossary"), "settings.open.glossary") { page = SettingsPage.GLOSSARY }
                            HorizontalDivider()
                            SettingsLink(label("support"), "settings.support") {
                                runCatching { uri.openUri("https://baseball-reincarnation.vercel.app/support") }.onFailure { linkError = label("link-error") }
                            }
                            HorizontalDivider()
                            SettingsLink(label("privacy"), "settings.privacy") {
                                runCatching { uri.openUri("https://baseball-reincarnation.vercel.app/privacy") }.onFailure { linkError = label("link-error") }
                            }
                        }
                        SettingsPage.PITCH_HELP -> {
                            for (index in 1..3) Text(label("pitch-step-$index"), verbatim = true, style = MaterialTheme.typography.bodyLarge)
                            Text(label("pitch-result"), verbatim = true, color = BaseballColors.textSecondary, style = MaterialTheme.typography.bodyMedium)
                        }
                        SettingsPage.GLOSSARY -> {
                            OutlinedTextField(value = query, onValueChange = { query = it; expandedTerm = null },
                                label = { Text(label("search"), verbatim = true) }, singleLine = true,
                                modifier = Modifier.fillMaxWidth().testTag("settings.glossary.search"))
                            val terms = BaseballGlossary.terms.filter { copy.legacy(it.name).contains(query.trim(), ignoreCase = true) }
                            if (terms.isEmpty()) Text(label("no-results"), verbatim = true, color = BaseballColors.textSecondary)
                            SettingsGroup {
                                for ((index, term) in terms.withIndex()) key(term.id) {
                                    if (index > 0) HorizontalDivider()
                                    SettingsLink(copy.legacy(term.name), "settings.term.${term.id}") { expandedTerm = if (expandedTerm == term.id) null else term.id }
                                    if (expandedTerm == term.id) Text(copy.legacy(term.definition), verbatim = true,
                                        modifier = Modifier.padding(start = 16.dp, end = 16.dp, bottom = 16.dp).testTag("settings.term.definition"),
                                        color = BaseballColors.textSecondary, style = MaterialTheme.typography.bodyMedium)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SettingsGroup(content: @Composable ColumnScope.() -> Unit) {
    Surface(color = BaseballColors.surface, shape = MaterialTheme.shapes.large) {
        Column(Modifier.fillMaxWidth(), content = content)
    }
}

@Composable
private fun SettingsSwitch(title: String, checked: Boolean, enabled: Boolean, tag: String, onToggle: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).toggleable(value = checked, enabled = enabled, role = Role.Switch) { onToggle() }
        .padding(horizontal = 16.dp, vertical = 8.dp).testTag(tag), verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(title, verbatim = true, modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
        Switch(checked = checked, onCheckedChange = null, enabled = enabled)
    }
}

@Composable
private fun SettingsLink(title: String, tag: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(onClick = onClick).padding(horizontal = 16.dp, vertical = 12.dp).testTag(tag),
        horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(title, verbatim = true, modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
        Text("›", color = BaseballColors.textTertiary, modifier = Modifier.clearAndSetSemantics {}, fontWeight = FontWeight.SemiBold)
    }
}
