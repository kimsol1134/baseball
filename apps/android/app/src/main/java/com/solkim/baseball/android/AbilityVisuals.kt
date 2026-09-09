package com.solkim.baseball.android

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballColors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private val abilityColors = listOf(Color(0xFFFFAE70), Color(0xFF79BBFF), Color(0xFFC5A0FF), Color(0xFF67D6C6))

@Composable
internal fun RebirthAbilityPreview(state: GameAggregateState, action: Phase8ActionModel) {
    var preview by remember(state.revision, action.id) { mutableStateOf<RebirthStartPreview?>(null) }
    LaunchedEffect(state.revision, action.id) {
        preview = withContext(Dispatchers.Default) { RebirthStartPreview.resolve(state, action) }
    }
    preview?.let { p ->
        val language = rememberGameCopy().language
        Text(abilityCopy(language, "이전 생 시작 → 선택한 다음 생", "Previous start → Selected next life", "前世の開始 → 選んだ次の人生"), style = MaterialTheme.typography.labelSmall)
        listOf(listOf(0, 1), listOf(2, 3)).forEach { row -> Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            row.forEach { i -> AbilityBar(i, p.next[i], p.previous[i], Modifier.weight(1f), tag = "rebirth.preview.$i", showPrevious = true) }
        } }
    }
}
internal fun abilityCopy(language: GameLanguage, ko: String, en: String, ja: String): String = when (language) {
    GameLanguage.KOREAN -> ko; GameLanguage.JAPANESE -> ja; else -> en
}
private fun abilityName(index: Int, language: GameLanguage): String = when(language) {
    GameLanguage.KOREAN -> listOf("구위", "제구", "무브먼트", "체력")
    GameLanguage.JAPANESE -> listOf("球威", "制球", "変化", "体力")
    else -> listOf("Stuff", "Command", "Movement", "Stamina")
}[index]

/** All bars share a true 0–100 scale; the thin marker denotes an observed comparison value. */
@Composable
internal fun AbilityBar(index: Int, rating: Int, previous: Int? = null, modifier: Modifier = Modifier,
    animate: Boolean = false, reducedMotion: Boolean = false, tag: String = "ability.$index", showPrevious: Boolean = false, onClick: (() -> Unit)? = null) {
    val language = rememberGameCopy().language
    val value = AbilityDisplayScale.rating(rating)
    val before = previous?.let(AbilityDisplayScale::rating)
    val change = before?.let { value - it }
    val color = abilityColors[index]
    var revealed by remember(rating, previous) { mutableStateOf(!animate || reducedMotion || before == null) }
    LaunchedEffect(rating, previous, reducedMotion) { revealed = true }
    val fraction by animateFloatAsState((if (revealed) value else before ?: value) / 100f,
        tween(if (reducedMotion) 0 else 450), label = "ability-bar")
    val name = abilityName(index, language)
    Column(modifier.then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
        .heightIn(min = if (onClick != null) 48.dp else 40.dp).testTag(tag)
        .semantics { contentDescription = "$name $value / 100" + (change?.let { ", ${if (it > 0) "+" else ""}$it" } ?: "") },
        verticalArrangement = Arrangement.spacedBy(5.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(name, Modifier.weight(1f), style = MaterialTheme.typography.labelMedium, color = color)
            if (showPrevious && before != null) Text("$before →", style = MaterialTheme.typography.labelSmall, color = BaseballColors.textSecondary)
            Text(value.toString(), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = BaseballColors.textPrimary,
                modifier = Modifier.testTag("$tag.value"))
            if (change != null && change != 0) Text("${if (change > 0) "+" else ""}$change",
                style = MaterialTheme.typography.labelMedium, color = if (change > 0) BaseballColors.action else BaseballColors.textSecondary)
        }
        Canvas(Modifier.fillMaxWidth().height(9.dp)) {
            drawRoundRect(color.copy(alpha = 0.15f), size = size, cornerRadius = androidx.compose.ui.geometry.CornerRadius(4.dp.toPx()))
            drawRoundRect(color, size = Size(size.width * fraction.coerceIn(0f, 1f), size.height), cornerRadius = androidx.compose.ui.geometry.CornerRadius(4.dp.toPx()))
            if (before != null) {
                val x = (size.width * before / 100f).coerceIn(1.dp.toPx(), size.width - 1.dp.toPx())
                drawLine(Color.White.copy(alpha = 0.9f), Offset(x, 0f), Offset(x, size.height), 2.dp.toPx())
                if (value > before) drawLine(Color.White.copy(alpha = 0.35f), Offset(x, size.height / 2), Offset(size.width * fraction, size.height / 2), 3.dp.toPx())
            }
        }
    }
}

@Composable
internal fun AbilityCard(state: GameAggregateState, compact: Boolean = true) {
    val current = AbilityHistory.current(state) ?: return
    val history = state.meta.abilityHistory.filter { it.career == current.career }
    val latest = history.lastOrNull()?.takeIf { it.source !in setOf("start", "observed") }
    val prior = if (latest != null) history.getOrNull(history.lastIndex - 1)?.ratings else null
    val receipt = state.meta.playerGrowth?.takeIf { it.careerId == current.career && it.after == current.ratings && it.before != it.after }
    val baseline = prior ?: receipt?.before
    var selected by remember(current.career) { mutableStateOf<Int?>(null) }
    Surface(color = BaseballColors.surfaceRaised, shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth().testTag("ability.card")) {
        Column(Modifier.padding(horizontal = 12.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            val groups = if (compact) listOf(listOf(0, 1), listOf(2, 3)) else (0..3).map { listOf(it) }
            groups.forEach { row -> Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                row.forEach { index -> AbilityBar(index, current.ratings[index], baseline?.get(index), Modifier.weight(1f),
                    reducedMotion = state.settings.reducedMotionEnabled, tag = "ability.current.$index", onClick = { selected = index }) }
            } }
            val masteryGain = if (latest != null && history.size >= 2) (0..3).sumOf { latest.mastery[it].toLong() - history[history.lastIndex - 1].mastery[it] } else 0L
            if (masteryGain > 0) Text(abilityCopy(rememberGameCopy().language, "숙련 +$masteryGain", "Mastery +$masteryGain", "熟練 +$masteryGain"),
                style = MaterialTheme.typography.labelMedium, color = BaseballColors.action)
            if (baseline != null) Text(abilityCopy(rememberGameCopy().language, "최근 성장 · 선은 이전 능력", "Latest change · Marker: previous value", "最近の成長 · 線は以前の能力"),
                style = MaterialTheme.typography.labelSmall, color = BaseballColors.textSecondary)
        }
    }
    selected?.let { index -> AbilityDetails(state, index) { selected = null } }
}

@Composable
internal fun AbilityChangeBars(before: List<Int>, after: List<Int>, reducedMotion: Boolean = false, tag: String = "ability.change") {
    if (before.size != 4 || after.size != 4) return
    val changed = (0..3).filter { before[it] != after[it] }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        changed.forEach { index -> AbilityBar(index, after[index], before[index], animate = true, reducedMotion = reducedMotion, tag = "$tag.$index") }
    }
}

@Composable
internal fun AbilityDetails(state: GameAggregateState, initial: Int = 0, onClose: () -> Unit) {
    val current = AbilityHistory.current(state) ?: return
    val language = rememberGameCopy().language
    fun t(ko: String, en: String, ja: String) = abilityCopy(language, ko, en, ja)
    var selected by remember(current.career) { mutableIntStateOf(initial) }
    var comparison by remember(current.career) { mutableIntStateOf(0) }
    val points = state.meta.abilityHistory.filter { it.career == current.career }
    val hsStart = state.highSchool?.startingPitcher?.let { listOf(it.stuff, it.command, it.movement, it.stamina) }
    val start = if (!current.pro) hsStart else points.firstOrNull { it.source == "start" }?.ratings
    val previousStart = state.meta.companion?.previousStart?.takeIf { !current.pro && it.size == 4 }
    val previousCareer = if (current.pro) state.meta.retiredProCareers.lastOrNull { it.careerId != current.career }?.careerId
        else state.highSchool?.archive?.lastOrNull { it.lifeNumber < current.life }?.careerId
    val previousPoints = state.meta.abilityHistory.filter { it.career == previousCareer }
    val previousPeak = previousPoints.takeIf { it.isNotEmpty() }?.let { list -> (0..3).map { i -> list.maxOf { it.ratings[i] } } }
    val from = when(comparison) { 1 -> previousStart; 2 -> previousPeak; else -> start }
    val to = if (comparison == 1) hsStart ?: current.ratings else current.ratings
    Dialog(onDismissRequest = onClose, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Surface(Modifier.fillMaxWidth().padding(12.dp).heightIn(max = 760.dp).testTag("ability.details"), shape = MaterialTheme.shapes.extraLarge, color = BaseballColors.surface) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(t("내 투수의 성장", "Player development", "投手の成長"), Modifier.weight(1f), style = MaterialTheme.typography.titleLarge)
                    TextButton(onClick = onClose) { Text(t("닫기", "Close", "閉じる")) }
                }
                Column(Modifier.weight(1f, false).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(t("능력 비교", "Compare abilities", "能力を比較"), style = MaterialTheme.typography.titleMedium)
                    val options = listOf(t(if (current.pro) "입단 후" else "이번 생", "This career", "今のキャリア"), t("환생 전후", "Rebirth", "転生前後"), t("전생 최고", "Past peak", "前世の最高"))
                    AdaptiveActionRow(Modifier.fillMaxWidth(), equalWidth = true) {
                        options.forEachIndexed { i, title -> FilterChip(selected = comparison == i, onClick = { comparison = i },
                            enabled = i == 0 || if (i == 1) previousStart != null else previousPeak != null,
                            colors = FilterChipDefaults.filterChipColors(selectedContainerColor = BaseballColors.action, selectedLabelColor = BaseballColors.actionInk),
                            label = { Text(title) }, modifier = Modifier.testTag("ability.compare.$i")) }
                    }
                    Text(when(comparison) { 1 -> t("이전 생 시작 → 이번 생 시작", "Previous start → Current start", "前世の開始 → 今世の開始"); 2 -> t("저장된 전생 최고 → 현재", "Recorded previous peak → Now", "記録された前世の最高 → 現在"); else -> t("시작 능력 → 현재", "Starting ability → Now", "開始時の能力 → 現在") }, style = MaterialTheme.typography.labelSmall)
                    if (from == null) Text(t("이전 능력 기록이 없어요. 현재부터 기록해요.", "No earlier ability data. Recording begins now.", "以前の能力記録はありません。今から記録します。"), style = MaterialTheme.typography.bodySmall)
                    (0..3).forEach { index -> AbilityBar(index, to[index], from?.get(index), tag = "ability.compare.bar.$index", showPrevious = true, onClick = { selected = index }) }
                    val fourSeam = if (current.pro) state.pro?.pitcher?.profile(PitchKind.FOUR_SEAM) else state.highSchool?.run?.pitcher?.pitchProfiles?.firstOrNull { it.pitchType == PitchKind.FOUR_SEAM }
                    fourSeam?.let { Text(t("포심 기준 구속", "Four-seam base velocity", "フォーシーム基準球速") + " ${it.velocityTenthsKph / 10}.${it.velocityTenthsKph % 10} km/h", style = MaterialTheme.typography.labelMedium, color = BaseballColors.textSecondary) }
                    Text(abilityName(selected, language), color = abilityColors[selected], style = MaterialTheme.typography.titleLarge)
                    val explanations = when(language) {
                        GameLanguage.KOREAN -> listOf("타자의 배트를 이겨내는 힘", "원하는 코스로 던지는 정확성", "타이밍을 빼앗고 강한 타구를 줄이는 움직임", "긴 이닝을 책임지는 힘 · 현재 피로와는 달라요")
                        GameLanguage.JAPANESE -> listOf("打者のバットを上回る力", "狙ったコースへ投げる正確さ", "タイミングを外し強い打球を減らす変化", "長いイニングを投げる力 · 現在の疲労とは別です")
                        else -> listOf("The power to beat the bat", "Accuracy at your chosen location", "Movement that disrupts timing and limits hard contact", "Endurance over longer outings · Separate from current fatigue")
                    }
                    Text(explanations[selected], style = MaterialTheme.typography.bodyMedium)
                    if (selected == 1) ControlWindowPreview(current.ratings[1], start?.get(1), titleKey = "loop.growth.base-window")
                    if (current.mastery[selected] > 0) Text(t("숙련", "Mastery", "熟練") + " ${current.mastery[selected]}", color = abilityColors[selected])
                    Text(t("상세 성장 기록", "Growth history", "成長記録"), style = MaterialTheme.typography.titleMedium)
                    if (points.isEmpty()) Text(t("아직 저장된 성장 변화가 없어요.", "No growth changes have been recorded yet.", "まだ成長の変化は記録されていません。"), style = MaterialTheme.typography.bodySmall)
                    AbilityHistoryChart(points, selected)
                    Text(t("점은 저장된 능력 변화예요. 기록이 없는 과거는 추정하지 않아요.", "Dots are saved changes. Missing history is not estimated.", "点は保存された変化です。未記録の過去は推測しません。"), style = MaterialTheme.typography.labelSmall)
                    var shown by remember(selected) { mutableIntStateOf(8) }
                    points.zipWithNext().filter { (a, b) -> a.ratings[selected] != b.ratings[selected] || a.mastery[selected] != b.mastery[selected] }
                        .asReversed().take(shown).forEach { (a, b) ->
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text(if (b.pro) t("${b.season}시즌 · ${b.step}주차", "Season ${b.season} · Week ${b.step}", "${b.season}シーズン · ${b.step}週") else t("${b.season}학년 · 훈련 ${b.step}회 시점", "Year ${b.season} · Training ${b.step}", "${b.season}年 · 練習${b.step}回時点"), Modifier.weight(1f), style = MaterialTheme.typography.bodySmall)
                                Text("${AbilityDisplayScale.rating(a.ratings[selected])} → ${AbilityDisplayScale.rating(b.ratings[selected])}", color = abilityColors[selected], style = MaterialTheme.typography.bodyMedium)
                            }
                            if (b.mastery[selected] != a.mastery[selected]) Text(t("숙련", "Mastery", "熟練") + " ${a.mastery[selected]} → ${b.mastery[selected]}", style = MaterialTheme.typography.labelSmall)
                        }
                    if (points.size > shown + 1) TextButton(onClick = { shown += 12 }) { Text(t("기록 더 보기", "More history", "さらに表示")) }
                }
            }
        }
    }
}

@Composable
private fun AbilityHistoryChart(points: List<AbilityHistoryPoint>, selected: Int) {
    if (points.isEmpty()) return
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row { Text("100", style = MaterialTheme.typography.labelSmall); Spacer(Modifier.weight(1f)); Text("0–100", style = MaterialTheme.typography.labelSmall) }
        Canvas(Modifier.fillMaxWidth().height(110.dp).testTag("ability.history.chart").semantics {
            contentDescription = points.joinToString { AbilityDisplayScale.rating(it.ratings[selected]).toString() }
        }) {
            for (mark in listOf(0f, 0.5f, 1f)) drawLine(Color.White.copy(alpha = 0.12f), Offset(0f, size.height * mark), Offset(size.width, size.height * mark), 1.dp.toPx())
            fun point(index: Int) = Offset(if (points.size == 1) size.width / 2 else size.width * index / (points.size - 1),
                size.height * (1 - AbilityDisplayScale.rating(points[index].ratings[selected]) / 100f))
            points.indices.forEach { i ->
                if (i > 0) drawLine(abilityColors[selected], point(i - 1), point(i), 2.dp.toPx(), StrokeCap.Round)
                drawCircle(abilityColors[selected], 3.dp.toPx(), point(i))
            }
        }
        Row { Text("0", style = MaterialTheme.typography.labelSmall); Spacer(Modifier.weight(1f)); Text(abilityCopy(rememberGameCopy().language, "성장 순서 · ${points.size}개 기록", "Growth order · ${points.size} records", "成長順 · ${points.size}件"), style = MaterialTheme.typography.labelSmall) }
    }
}
