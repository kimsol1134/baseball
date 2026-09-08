package com.solkim.baseball.android

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.core.highschool.HighSchoolLineageRules
import com.solkim.baseball.design.BaseballColors
import kotlinx.coroutines.launch
import com.solkim.baseball.android.LocalizedGameText as Text

@Composable
@OptIn(ExperimentalMaterial3Api::class)
internal fun CompanionLauncher(state: GameAggregateState, showPortrait: Boolean = false) {
    if (state.meta.seedChallenge != null || state.highSchool?.challenge?.active == true) return
    var open by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var saving by remember { mutableStateOf(false) }
    val c = PitcherCompanionRules.current(state)
    val copy = rememberGameCopy()
    val pro = state.pro.takeIf { state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT) }
    val name = c.nickname.ifEmpty { copy.legacy(PitchHudProjection.koreanLabel(PitchKind.entries.first { it.wire == c.representative })) }
    TextButton(onClick = { open = true }, modifier = Modifier.testTag("companion.open")) {
        if (showPortrait) {
            PlayerPortrait(seed = playerPortraitSeed(state) ?: "pitcher", stage = if (pro != null) PlayerStage.PRO else if ((state.highSchool?.run?.chapter?.schoolYear ?: 1) >= 3) PlayerStage.ACE else PlayerStage.FRESHMAN, width = 28.dp)
            Spacer(Modifier.width(8.dp))
            Text("#${c.jersey} " + (pro?.identityName ?: state.highSchool?.run?.identity?.name.orEmpty()), verbatim = true)
        } else Text("선수 상세")
        if (showPortrait) Text(" · $name", verbatim = true, color = BaseballColors.milestone)
    }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    if (open) ModalBottomSheet(onDismissRequest = { if (!saving) open = false }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            error?.let { Text(it, color = BaseballColors.warning) }
            CompanionProfile(state, saving) { operation, value ->
                scope.launch {
                    saving = true
                    val store = (context.applicationContext as BaseballApplication).gameStore
                    try {
                        val current = store.current
                        store.dispatch(GameCommandEnvelope("companion:${current.revision}:$operation", "companion-ui", current.revision, GameCommand.UpdateCompanion(operation, value)))
                        error = null
                    } catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled }
                    catch (failure: Exception) {
                        runCatching { store.reconcilePersistedRevision() }
                        error = "저장하지 못했어요. 다시 시도해 주세요."
                    }
                    finally { saving = false }
                }
            }
            Spacer(Modifier.navigationBarsPadding())
        }
    }
}

@Composable
internal fun CompanionProfile(state: GameAggregateState, busy: Boolean, onChange: (String, String) -> Unit) {
    val c = PitcherCompanionRules.current(state)
    val copy = rememberGameCopy()
    val pro = state.pro.takeIf { state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT) }
    val run = state.highSchool?.run
    Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        PlayerPortrait(modifier = Modifier.graphicsLayer { rotationZ = if ((pro?.fatigue ?: run?.fatigue ?: 0) >= 70) -3f else 0f }, seed = playerPortraitSeed(state) ?: "pitcher", stage = if (pro != null) PlayerStage.PRO else if ((run?.chapter?.schoolYear ?: 1) >= 3) PlayerStage.ACE else PlayerStage.FRESHMAN, width = 68.dp)
        Column {
            Text(pro?.identityName ?: run?.identity?.name.orEmpty(), verbatim = true, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            Text("#${c.jersey}", verbatim = true, style = MaterialTheme.typography.titleLarge, color = BaseballColors.milestone)
            val fatigue = pro?.fatigue ?: run?.fatigue ?: 0
            Text(if (fatigue >= 70) "잠깐 쉬고 다시 던지고 싶어요." else if (fatigue <= 20) "몸이 가벼워요. 다음 공이 기대돼요." else "한 구씩 제 공을 만들어갈게요.", style = MaterialTheme.typography.bodySmall)
        }
    }
    var jersey by remember(c.jersey) { mutableStateOf(c.jersey.toString()) }
    CareerDisclosure("등번호 바꾸기", "companion.jersey") {
        OutlinedTextField(jersey, { jersey = it.filter(Char::isDigit).take(2) }, label = { Text("등번호") }, singleLine = true)
        Button(onClick = { onChange("jersey", jersey) }, enabled = !busy && jersey.toIntOrNull() in 1..99) { Text("저장") }
    }
    Text("대표 구종", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    val profiles = pro?.pitcher?.pitchProfiles ?: run?.pitcher?.pitchProfiles.orEmpty()
    AdaptiveActionRow(Modifier.fillMaxWidth()) {
        profiles.forEach { pitch ->
            FilterChip(selected = pitch.pitchType.wire == c.representative, onClick = { onChange("pitch", pitch.pitchType.wire) }, enabled = !busy,
                colors = FilterChipDefaults.filterChipColors(selectedContainerColor = BaseballColors.action, selectedLabelColor = BaseballColors.actionInk),
                label = { Text(PitchHudProjection.koreanLabel(pitch.pitchType)) }, modifier = Modifier.testTag("companion.pitch.${pitch.pitchType.wire}"))
        }
    }
    val experience = c.experience.firstOrNull { it.pitch == c.representative } ?: SignatureExperience(c.representative)
    Text(c.nickname.ifEmpty { copy.resolve("companion.rank.${experience.rank}") }, verbatim = true, color = BaseballColors.milestone, style = MaterialTheme.typography.titleMedium)
    CareerStatTiles(listOf("훈련" to "${experience.training}", "투구" to "${experience.uses}", "탈삼진" to "${experience.strikeouts}"))
    Text("이 공의 기록은 환생해도 남아요. 구위와 제구는 훈련으로 키워요.", style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
    val target = when(experience.rank) { 0 -> 3; 1 -> 1; else -> 10 }
    val progress = when(experience.rank) { 0 -> maxOf(experience.training, experience.uses); else -> experience.strikeouts }
    if (experience.rank < 3) {
        LinearProgressIndicator(progress = { (progress.toFloat() / target).coerceIn(0f, 1f) }, trackColor = BaseballColors.border, modifier = Modifier.fillMaxWidth())
        Text(copy.resolve("companion.rank.next.${experience.rank}", GameCopyArgument.Whole((target - progress).coerceAtLeast(0).toLong())), verbatim = true, style = MaterialTheme.typography.labelSmall)
    }
    var nickname by remember(c.nickname, c.representative) { mutableStateOf(c.nickname) }
    if (experience.rank >= 2) {
        CareerDisclosure(if (c.nickname.isEmpty()) "별명 붙이기" else "별명 바꾸기", "companion.nickname.edit") {
        OutlinedTextField(nickname, { nickname = it.take(20) }, label = { Text("내 공의 별명") }, singleLine = true, modifier = Modifier.fillMaxWidth().testTag("companion.nickname"))
        Button(onClick = { onChange("nickname", nickname) }, enabled = !busy && nickname != c.nickname, modifier = Modifier.testTag("companion.nickname.save")) { Text("별명 붙이기") }
        }
    } else Text("이 공으로 공식 경기 삼진을 잡으면 별명을 붙일 수 있어요.", style = MaterialTheme.typography.bodySmall)
    if (c.goal.isNotEmpty() || PitcherCompanionRules.canChooseGoal(state)) {
    Text("이번 생의 작은 꿈", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    if (c.goal.isNotEmpty()) {
        Text(copy.resolve("companion.goal.${c.goal}"), verbatim = true)
        Text("${(PitcherCompanionRules.progress(c) - c.goalBaseline).coerceAtLeast(0)} / ${c.goalTarget - c.goalBaseline}", verbatim = true, color = BaseballColors.action, modifier = Modifier.testTag("companion.goal.progress"))
        if (c.goalCompleted) Text("해냈어요. 이 순간을 기억할게요.", color = BaseballColors.milestone)
    }
    if (PitcherCompanionRules.canChooseGoal(state) && (c.goal.isEmpty() || c.goalCompleted)) {
        listOf("signature", "clean", "best").filter { goal -> c.memories.none { it.career == c.career && it.kind == "goal_$goal" } }.forEach { goal ->
            val preview = PitcherCompanionRules.apply(state, "goal", goal)
            CompactChoiceCard(copy.resolve("companion.goal.$goal"),
                copy.resolve("companion.goal.remaining", GameCopyArgument.Whole((preview.goalTarget - preview.goalBaseline).toLong())),
                !busy, "companion.goal.$goal", actionLabel = "도전") { onChange("goal", goal) }

        }
    }
    }
    Text("함께한 기억", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    if (c.memories.isEmpty()) Text("첫 공식 경기부터 우리만의 기억을 남겨요.", style = MaterialTheme.typography.bodyMedium)
    c.memories.firstOrNull { it.id == c.pinned }?.let { CompanionMemory(it, true, busy, onChange) }
    c.memories.asReversed().filterNot { it.id == c.pinned }.take(3).forEach { CompanionMemory(it, false, busy, onChange) }
    var memoriesShown by remember(c.career) { mutableIntStateOf(12) }
    if (c.memories.size > 3) CareerDisclosure("기억첩 펼치기", "companion.memories") {
        c.memories.asReversed().filterNot { it.id == c.pinned }.drop(3).take(memoriesShown).forEach { CompanionMemory(it, false, busy, onChange) }
        if (c.memories.size > memoriesShown + 3) TextButton(onClick = { memoriesShown += 12 }) { Text("기억 더 보기") }
    }
    state.highSchool?.let { school ->
        val recovered = HighSchoolLineageRules.recovered(school.inheritance, school.archive)
        val active = recovered.lineageLoadout
        if (active != null) {
            Text("다음 생으로 이어지는 힘", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text(SignatureLegacyDisplay.title(active.legacyId, copy).orEmpty(), verbatim = true)
            val mastery = recovered.lineageMasteries.first { it.family == com.solkim.baseball.core.highschool.HighSchoolSignatureLegacyRules.definition(active.legacyId).family }
            Text(copy.resolve("companion.lineage", GameCopyArgument.Whole(mastery.rank.toLong()), GameCopyArgument.Whole(mastery.contributions.toLong())), verbatim = true)
            Text(copy.resolve("companion.lineage.effect.${if (mastery.family == "battery" && mastery.rank >= 2) "battery" else mastery.rank}"), verbatim = true, style = MaterialTheme.typography.bodySmall)
            mastery.nextThreshold?.let { Text(copy.resolve("companion.lineage.next", GameCopyArgument.Whole((it - mastery.contributions).toLong())), verbatim = true) }
            Text("계보의 힘은 환생할 때 적용돼요. 현재 경기의 능력치는 바뀌지 않아요.", style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
private fun CompanionMemory(memory: PitchMemory, pinned: Boolean, busy: Boolean, onChange: (String, String) -> Unit) {
    val copy = rememberGameCopy()
    Surface(color = BaseballColors.surfaceRaised, shape = MaterialTheme.shapes.medium) {
        Column(Modifier.fillMaxWidth().padding(12.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Text(copy.resolve("mobile.core.life", GameCopyArgument.Whole(memory.life.toLong())), verbatim = true, style = MaterialTheme.typography.labelSmall)
            Text(copy.resolve("companion.memory.${memory.kind}"), verbatim = true, style = MaterialTheme.typography.titleMedium)
            CareerMemoryPresentation.detail(memory, copy).takeIf { it.isNotBlank() }?.let { Text(it, verbatim = true, style = MaterialTheme.typography.bodySmall) }
            if (memory.pitch.isNotEmpty()) Text(PitchHudProjection.koreanLabel(PitchKind.entries.first { it.wire == memory.pitch }), style = MaterialTheme.typography.bodySmall)
            TextButton(onClick = { onChange("pin", if (pinned) "" else memory.id) }, enabled = !busy, modifier = Modifier.testTag("companion.pin.${memory.id}")) { Text(if (pinned) "고정 해제" else "선수 화면에 고정") }
        }
    }
}

@Composable
internal fun CompanionReaction(state: GameAggregateState) {
    val c = state.meta.companion ?: return
    val pinned = c.memories.firstOrNull { it.id == c.pinned }
    val memory = pinned ?: c.memories.lastOrNull()?.takeIf { it.career == PitcherCompanionRules.career(state) } ?: return
    val copy = rememberGameCopy()
    Text(copy.resolve(if (pinned != null) "companion.memory.${memory.kind}" else "companion.reaction.${when { memory.kind.startsWith("goal_") -> "goal"; memory.kind.startsWith("signature_rank") -> "signature"; else -> memory.kind }}"),
        verbatim = true, color = BaseballColors.milestone, style = MaterialTheme.typography.bodySmall)
}
