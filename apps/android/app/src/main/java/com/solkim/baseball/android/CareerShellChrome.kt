package com.solkim.baseball.android

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.solkim.baseball.android.LocalizedGameText as Text
import com.solkim.baseball.application.CareerUiRules
import com.solkim.baseball.application.GameAggregateState
import com.solkim.baseball.application.GameCopyArgument
import com.solkim.baseball.application.PitchBoundary
import com.solkim.baseball.application.RebirthContinuity
import com.solkim.baseball.application.ScreenGroup
import com.solkim.baseball.application.ScreenId
import com.solkim.baseball.application.ScreenModel
import com.solkim.baseball.application.ScreenProjection
import com.solkim.baseball.design.BaseballColors

@Composable
internal fun RebirthReadyIntroduction(
    state: GameAggregateState,
    model: ScreenModel,
    busy: Boolean,
    actionError: String?,
    insets: androidx.compose.foundation.layout.PaddingValues,
    onAction: (ScreenUiAction) -> Unit,
) {
    var acceptsFreshTap by remember(CareerUiRules.highSchoolCareerId(state), model.id) { mutableStateOf(false) }
    LaunchedEffect(CareerUiRules.highSchoolCareerId(state), model.id) {
        androidx.compose.runtime.withFrameNanos { }
        kotlinx.coroutines.delay(500)
        acceptsFreshTap = true
    }
    val continuity = RebirthContinuity.resolve(state) ?: return
    val copy = rememberGameCopy()
    var memories by rememberSaveable(CareerUiRules.highSchoolCareerId(state)) { mutableStateOf(false) }
    Column(Modifier.fillMaxSize().padding(insets).padding(horizontal = 24.dp, vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (actionError != null) CareerErrorCard(actionError)
        CorePlayerHeader(state, compact = true)
        Text(copy.resolve(if (continuity.samePlayer) "loop.reborn.same" else "loop.reborn.different"), verbatim = true,
            style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, modifier = Modifier.testTag("rebirth.ready"))
        Text(copy.resolve("loop.reborn.next"), verbatim = true, style = MaterialTheme.typography.bodyMedium)
        model.actions.firstOrNull { it.id == "completeTutorial" }?.let { action -> CareerActionButton(model.id, action.copy(enabled = action.enabled && !busy && acceptsFreshTap), onAction, showDescription = false) }
        model.actions.firstOrNull { it.id == "resumePitch" && it.enabled }?.let { action -> CareerActionButton(model.id, action.copy(enabled = !busy && acceptsFreshTap), onAction, showDescription = false) }
            ?: model.actions.firstOrNull { it.id == "openTutorialPitch" }?.let { action ->
                OutlinedButton(onClick = { onAction(ScreenUiAction(model.id, action.id, action.payloads)) }, enabled = action.enabled && !busy,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("action.openTutorialPitch")) { Text(if (state.pitch?.boundary in setOf(PitchBoundary.COMMITTED, PitchBoundary.CONSUMED, PitchBoundary.TERMINAL)) "결과 확인" else "연습 투구") }
            }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            continuity.legacyTitle?.let { Text(copy.resolve("loop.reborn.inherited", GameCopyArgument.UserText(copy.legacy(it))), verbatim = true, color = BaseballColors.milestone) }
            val handicaps = CareerUiRules.karmaCount(state) ?: 0
            if (handicaps > 0) Text(copy.resolve("loop.reborn.handicaps", GameCopyArgument.Whole(handicaps.toLong())), verbatim = true, color = BaseballColors.warning)
            val previousName = continuity.previousName
            if (previousName != null) {
                TextButton(onClick = { memories = !memories }, modifier = Modifier.testTag("rebirth.memories")) {
                    Text(copy.resolve(if (continuity.samePlayer) "loop.reborn.memories" else "loop.reborn.other-record"), verbatim = true)
                }
                if (memories) {
                    Text(if (continuity.samePlayer) copy.resolve("loop.letter.self-title") else previousName,
                        verbatim = true, style = MaterialTheme.typography.titleMedium, modifier = Modifier.testTag("rebirth.previousSelf"))
                    val body = if (continuity.samePlayer) continuity.legacyTitle?.let { copy.resolve("loop.letter.self-body", GameCopyArgument.UserText(copy.legacy(it))) }
                        ?: copy.resolve("loop.letter.self-basic") else copy.resolve("loop.reborn.other-history", GameCopyArgument.UserText(previousName))
                    Text(body, verbatim = true)
                    Text(copy.resolve("loop.reborn.record-line", GameCopyArgument.Whole(continuity.games.toLong()), GameCopyArgument.Whole(continuity.strikeouts.toLong())), verbatim = true)
                }
            }
        }
    }
}

internal val recordScreens = listOf(ScreenId.P025_RECORDS_LEAGUE, ScreenId.P011_HIGH_SCHOOL_CAREER, ScreenId.P026_ACHIEVEMENTS, ScreenId.P024_WEEKLY, ScreenId.P028_LIFECARD, ScreenId.P029_RETURN_PLAN)

/** The records tab used to land on the first reachable screen and stop there. Every record screen is one tap away. */
@Composable
internal fun RecordsSegments(state: GameAggregateState, current: ScreenId, onNavigate: (ScreenId) -> Unit) {
    val copy = rememberGameCopy()
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        recordScreens.filter { it != ScreenId.P024_WEEKLY || com.solkim.baseball.application.WeeklyNotePolicy.isAvailable(state) }.chunked(3).forEach { group ->
            AdaptiveActionRow(Modifier.fillMaxWidth(), equalWidth = true) {
                group.forEach { screen ->
                    val fullLabel = when (screen) {
                        ScreenId.P025_RECORDS_LEAGUE -> "통산 기록"
                        ScreenId.P011_HIGH_SCHOOL_CAREER -> "경기 기록"
                        ScreenId.P026_ACHIEVEMENTS -> "업적"
                        ScreenId.P024_WEEKLY -> "주간 노트"
                        ScreenId.P028_LIFECARD -> "선수 앨범"
                        else -> "돌아올 자리"
                    }
                    val label = when (screen) {
                        ScreenId.P025_RECORDS_LEAGUE -> "career"
                        ScreenId.P011_HIGH_SCHOOL_CAREER -> "games"
                        ScreenId.P026_ACHIEVEMENTS -> "achievements"
                        ScreenId.P024_WEEKLY -> "week"
                        ScreenId.P028_LIFECARD -> "card"
                        else -> "return"
                    }
                    val badge = when (screen) {
                        ScreenId.P026_ACHIEVEMENTS -> CareerUiRules.hasUnacknowledgedAchievements(state)
                        ScreenId.P024_WEEKLY -> com.solkim.baseball.application.WeeklyNotePolicy.canClaim(state)
                        else -> false
                    }
                    androidx.compose.material3.FilterChip(selected = screen == current,
                        colors = androidx.compose.material3.FilterChipDefaults.filterChipColors(selectedContainerColor = BaseballColors.action, selectedLabelColor = BaseballColors.actionInk),
                        onClick = { if (screen != current) onNavigate(screen) }, enabled = ScreenProjection.isReachable(state, screen),
                        label = { Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(copy.resolve("controls.records.$label"), verbatim = true)
                            Box(Modifier.size(6.dp).background(if (badge) BaseballColors.milestone else androidx.compose.ui.graphics.Color.Transparent,
                                androidx.compose.foundation.shape.CircleShape))
                        } },
                        modifier = Modifier.heightIn(min = 48.dp).testTag("records.tab.${screen.wire}")
                            .gameDescription(copy.legacy(fullLabel) + if (badge) " · " + copy.legacy("새 소식") else ""))
                }
            }
        }
    }
}

internal enum class ProductTab(val label: String) {
    CAREER("내 투수"),
    RECORDS("기록"),
    SETTINGS("설정"),
    ;

    fun landingScreen(state: GameAggregateState): ScreenId? {
        val preferred = ScreenProjection.preferredScreen(state)
        val candidates = when (this) {
            CAREER -> {
                if (preferred.group in setOf(ScreenGroup.CAREER_CORE, ScreenGroup.RECAP_REBIRTH, ScreenGroup.PRO)) {
                    listOf(preferred)
                } else if (CareerUiRules.hasPro(state)) {
                    listOf(
                        preferred,
                        ScreenId.P017_PRO_WEEK,
                        ScreenId.P016_PRO_CONTRACT,
                        ScreenId.P021_PRO_RETIREMENT,
                        ScreenId.P020_OFFSEASON,
                    )
                } else {
                    listOf(
                        preferred,
                        ScreenId.P005_SCHOOL_SELECTION,
                        ScreenId.P006_TRAINING,
                        ScreenId.P007_RELATIONSHIP,
                        ScreenId.P008_IMPORTANT_GAME,
                        ScreenId.P009_AWAKENING,
                        ScreenId.P010_CHAPTER,
                        ScreenId.P011_HIGH_SCHOOL_CAREER,
                        ScreenId.P003_PROLOGUE,
                        ScreenId.P002_SETUP,
                        ScreenId.P001_OPENING,
                    )
                }
            }
            RECORDS -> listOf(
                ScreenId.P025_RECORDS_LEAGUE,
                ScreenId.P024_WEEKLY,
                ScreenId.P026_ACHIEVEMENTS,
                ScreenId.P028_LIFECARD,
            )
            SETTINGS -> listOf(ScreenId.P027_SETTINGS)
        }
        return candidates.firstOrNull { ScreenProjection.isReachable(state, it) }
    }

    companion object {
        fun forScreen(screen: ScreenId): ProductTab = if (screen in setOf(ScreenId.P028_LIFECARD, ScreenId.P011_HIGH_SCHOOL_CAREER)) RECORDS else when (screen.group) {
            ScreenGroup.PRO, ScreenGroup.CAREER_CORE, ScreenGroup.RECAP_REBIRTH -> CAREER
            ScreenGroup.RECORDS_META, ScreenGroup.RETURN_REVIEW -> RECORDS
            ScreenGroup.SETTINGS_PLATFORM -> SETTINGS
        }
    }
}

@Composable
internal fun TabIcon(tab: ProductTab, isSelected: Boolean) {
    val tint = if (isSelected) BaseballColors.action else BaseballColors.textTertiary
    val iconRes = when (tab) {
        ProductTab.CAREER -> R.drawable.ic_tab_career
        ProductTab.RECORDS -> R.drawable.ic_tab_records
        ProductTab.SETTINGS -> R.drawable.ic_tab_settings
    }
    Icon(
        painter = painterResource(iconRes),
        contentDescription = null,
        tint = tint,
        modifier = Modifier.size(24.dp),
    )
}

@Composable
internal fun ProductNavigation(state: GameAggregateState, currentTab: ProductTab, onNavigate: (ScreenId) -> Unit) {
    androidx.compose.material3.Surface(color = BaseballColors.surface, modifier = Modifier.fillMaxWidth().clipToBounds()) {
        Row(Modifier.fillMaxWidth().selectableGroup().windowInsetsPadding(androidx.compose.material3.NavigationBarDefaults.windowInsets)
            .height(if (androidx.compose.ui.platform.LocalDensity.current.fontScale >= 1.5f) 112.dp else 80.dp).testTag("navigation.bar")) {
            ProductTab.entries.forEach { tab ->
                val destination = tab.landingScreen(state)
                val selected = tab == currentTab
                Column(Modifier.weight(1f).fillMaxHeight().clipToBounds().testTag("navigation.${tab.name.lowercase()}")
                    .selectable(selected = selected, enabled = destination != null, role = androidx.compose.ui.semantics.Role.Tab,
                        onClick = { destination?.let(onNavigate) }),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterVertically)) {
                    TabIcon(tab, selected)
                    Text(tab.label, style = MaterialTheme.typography.labelMedium,
                        color = if (selected) BaseballColors.action else BaseballColors.textTertiary,
                        fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal)
                }
            }
        }
    }
}

@Composable
@OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)
internal fun ConversationNavigation(state: GameAggregateState, onNavigate: (ScreenId) -> Unit, content: @Composable () -> Unit) {
    val destination = ProductTab.RECORDS.landingScreen(state) ?: ScreenId.P027_SETTINGS
    androidx.activity.compose.BackHandler { onNavigate(destination) }
    Scaffold(modifier = Modifier.fillMaxSize().semantics { testTagsAsResourceId = true },
        bottomBar = { ProductNavigation(state, ProductTab.CAREER, onNavigate) }) { padding ->
        Box(Modifier.fillMaxSize().padding(padding).consumeWindowInsets(padding)) { content() }
    }
}
