package com.solkim.baseball.android

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.platform.*
import kotlinx.coroutines.delay
import com.solkim.baseball.android.LocalizedGameText as Text

@Composable
internal fun PlayerAlbumView(state: GameAggregateState, showTitle: Boolean = true) {
    val pages = remember(state) { PlayerAlbum.pages(state) }
    var selection by remember { mutableStateOf<String?>(null) }
    val activeScope = if (state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT, GameStage.LEGACY) ) state.pro?.let { "pro:${it.careerId}:${it.season}" } else state.highSchool?.run?.let { "hs:${it.careerId}" }
    val page = pages.firstOrNull { it.scope.id == selection } ?: pages.firstOrNull { it.scope.id == activeScope } ?: pages.lastOrNull()
    val copy = rememberGameCopy()
    if (showTitle) Text("선수 앨범", style = MaterialTheme.typography.headlineSmall)
    if (page == null) { Text("첫 등판부터 나만의 야구 인생이 여기에 쌓여요."); return }
    CareerDisclosure("선수와 시즌 선택", "album.scopes") {
        pages.asReversed().forEach { option ->
            FilterChip(selected = option.scope.id == page.scope.id, onClick = { selection = option.scope.id },
                colors = FilterChipDefaults.filterChipColors(selectedContainerColor = BaseballColors.action, selectedLabelColor = BaseballColors.actionInk),
                label = { Text(option.scope.player + " · " + option.scope.title) })
        }
    }
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        PlayerPortrait(seed = page.portraitSeed,
            stage = if (page.scope.id.startsWith("pro:")) PlayerStage.PRO else PlayerStage.ACE, width = 72.dp)
        Column { Text(page.scope.player, verbatim = true, style = MaterialTheme.typography.headlineSmall); Text(page.scope.title); if (page.affiliation.isNotBlank()) Text(page.affiliation) }
    }
    val innings = if (page.inningsKnown) "${page.outs/3}.${page.outs%3}" else "—"
    if (page.signature.isNotBlank()) Text(copy.resolve("content.pitch-type.${page.signature}.name"), verbatim = true, color = BaseballColors.action)
    val pitching = AlbumPitchingStats.from(page)
    val stats = listOf("WHIP" to pitching.whip, "이닝" to innings, "탈삼진" to page.strikeouts.toString())
    CareerStatTiles(stats)
    var card by remember(page.scope.id) { mutableStateOf<AlbumShareCard?>(null) }
    var replay by remember(page.scope.id) { mutableStateOf(false) }
    fun shareCard(title: String, values: List<Pair<String, String>>, caption: String, game: CareerGameView? = null): AlbumShareCard {
        val detail = game?.let { AlbumPitchingStats.from(it) } ?: pitching
        return AlbumShareCard(copy.legacy(title), page.scope.player,
        copy.legacy(listOf(page.scope.title, page.affiliation).filter { it.isNotBlank() }.joinToString(" · ")), values.map { copy.legacy(it.first) to it.second }, listOfNotNull(copy.legacy("${page.life}번째 생"),
            page.signature.takeIf { it.isNotBlank() }?.let { copy.legacy("대표 구종") + " · " + copy.resolve("content.pitch-type.$it.name") },
            copy.legacy(caption, pages.map { it.scope.player }.toSet())).joinToString("\n"), copy.resolve("android.app.name"), line = detail.line, rates = detail.rates)
    }
    TextButton(onClick = { card = shareCard("내 투수", stats, "나의 야구 인생") }, modifier = Modifier.testTag("album.card")) { Text("카드 보기") }
    CareerDisclosure("상세 투구 기록", "album.pitching.stats") {
        AlbumStatGrid(pitching.line)
        AlbumStatGrid(pitching.rates)
        CareerDisclosure("기록 용어", "album.pitching.glossary") {
            listOf("G 경기 · GS 선발 · W 승 · L 패 · SV 세이브", "IP 이닝 · H 피안타 · HR 피홈런 · BB 볼넷", "SO 탈삼진 · R 실점 · ER 자책점 · NP 투구 수", "ERA · 9이닝당 자책점", "CG 완투 · SHO 완봉승", "WHIP · 이닝당 허용한 피안타와 볼넷", "K/9 · 9이닝당 탈삼진", "BB/9 · 9이닝당 볼넷", "H/9 · 9이닝당 피안타", "K/BB · 볼넷당 탈삼진", "RA/9 · 9이닝당 실점, 자책점 기준 ERA와 달라요.", "— · 계산에 필요한 기록이 없거나 분모가 0이에요.").forEach {
                Text(it, style = MaterialTheme.typography.bodySmall)
            }
        }
    }
    val best = page.rows.maxByOrNull { it.outs * 4 + it.strikeouts * 3 - it.runs * 8 }
    if (best != null) {
        Text(best.achievementTitle ?: "기억할 경기", style = MaterialTheme.typography.titleMedium)
        CareerStatTiles(listOf("이닝" to "${best.outs/3}.${best.outs%3}", "탈삼진" to best.strikeouts.toString(), "실점" to best.runs.toString()))
        Text(best.label, style = MaterialTheme.typography.labelMedium)
        TextButton(onClick = { card = shareCard(best.achievementTitle ?: "인생 경기", listOf("이닝" to "${best.outs/3}.${best.outs%3}", "탈삼진" to best.strikeouts.toString(), "실점" to best.runs.toString()), best.label, best) }) { Text("경기 카드") }
    }
    CareerDisclosure("기념할 순간", "album.milestones") {
        val chronological = page.rows.sortedBy { it.chronologicalKey }
        listOf("첫 완봉승" to chronological.firstOrNull { it.isShutout }, "첫 완투" to chronological.firstOrNull { it.completeGame == true }, "첫 승" to chronological.firstOrNull { it.decision == "win" }, "첫 세이브" to chronological.firstOrNull { it.decision == "save" },
            "첫 선발" to chronological.firstOrNull { it.started }, "첫 무실점 등판" to chronological.firstOrNull { it.outs > 0 && it.runs == 0 }).forEach { (title, game) ->
            if (game != null) TextButton(onClick = { card = shareCard(title, listOf("이닝" to "${game.outs/3}.${game.outs%3}", "탈삼진" to game.strikeouts.toString(), "실점" to game.runs.toString()), game.label, game) }) { Text(title) }
        }
        Text("선택한 기간에 저장된 경기 기준", style = MaterialTheme.typography.bodySmall)
    }
    if (page.scope.id.startsWith("pro:")) TextButton(onClick = { card = shareCard("시즌 결산", stats, "나의 야구 인생") }) { Text("시즌 카드") }
    var shownGames by remember(page.scope.id) { mutableIntStateOf(5) }
    CareerDisclosure("모든 등판", "album.games") {
        page.rows.asReversed().take(shownGames).forEach { game ->
            TextButton(onClick = { card = shareCard("기억할 경기", listOf("이닝" to "${game.outs/3}.${game.outs%3}", "탈삼진" to game.strikeouts.toString(), "실점" to game.runs.toString()), game.label, game) }) { Text(game.label, style = MaterialTheme.typography.labelMedium) }
            CareerStatTiles(listOf("이닝" to "${game.outs/3}.${game.outs%3}", "탈삼진" to game.strikeouts.toString(), "실점" to game.runs.toString()))
        }
        if (shownGames < page.rows.size) TextButton(onClick = { shownGames += 5 }) { Text("더 보기") }
        if (page.games > page.rows.size) Text("이전 경기의 개별 기록은 남아 있지 않아요.")
    }
    CareerDisclosure("환생 계보", "album.lineage") {
        state.highSchool?.archive.orEmpty().forEach { life ->
            Text("${life.lifeNumber} · ${life.playerName}", verbatim = true, style = MaterialTheme.typography.titleMedium)
            TextButton(onClick = { selection = "hs:${life.careerId}" }) { Text("앨범 열기") }
            life.selectedSignatureLegacyId?.let { Text(CareerUiRules.legacyTitle(it)) }
        }
        TextButton(onClick = {
            val lives = state.highSchool?.archive.orEmpty()
            card = shareCard("환생 계보", stats, lives.takeLast(3).joinToString(" → ") { "${it.lifeNumber} · ${it.playerName}" })
        }) { Text("계보 카드") }
    }
    val completedSchoolIds = state.highSchool?.archive.orEmpty().map { "hs:${it.careerId}" }
    val previous = pages.filter { it.scope.id in completedSchoolIds && it.life < page.life }.maxByOrNull { it.life }
    if (page.scope.id in completedSchoolIds && previous != null && page.ratings.size == 4 && previous.ratings.size == 4) {
        CareerDisclosure("지난 생과 성장 비교", "album.compare") {
            Text("같은 고교 기간의 최종 능력 비교", style = MaterialTheme.typography.bodySmall)
            listOf("구위", "제구", "무브먼트", "체력").forEachIndexed { i, label ->
                Row { Text(label); Text("  ${AbilityDisplayScale.rating(previous.ratings[i])} → ${AbilityDisplayScale.rating(page.ratings[i])}", verbatim = true) }
            }
        }
    }
    if (page.pitches.isNotEmpty()) TextButton(onClick = { replay = !replay }, modifier = Modifier.testTag("album.replay")) { Text("투구 궤적 다시 보기") }
    else Text("투구 재생은 저장된 직접 투구부터 제공해요.", style = MaterialTheme.typography.bodySmall)
    if (replay) AlbumPitchReplay(page.pitches)
    Text("앨범은 게임 백업에 함께 보관돼요.", style = MaterialTheme.typography.bodySmall)
    card?.let { AlbumCardPreview(it, page.portraitSeed, page.scope.id.startsWith("pro:")) { card = null } }
}

/** Read-only trajectory playback: no game command, RNG or rewards enter this view. */
@Composable
private fun AlbumPitchReplay(pitches: List<AlbumPitch>) {
    var index by remember(pitches) { mutableIntStateOf(pitches.lastIndex) }
    var frame by remember(index) { mutableIntStateOf(0) }
    var playing by remember(index) { mutableStateOf(false) }
    val pitch = pitches[index]
    val copy = rememberGameCopy()
    val points = pitch.trajectory.chunked(4)
    LaunchedEffect(playing, index) {
        if (playing) {
            frame = 0
            for (i in points.indices) { frame = i; delay(65) }
            playing = false
        }
    }
    Text(copy.resolve("content.pitch-type.${pitch.kind}.name"), verbatim = true, style = MaterialTheme.typography.titleMedium)
    if (pitch.context.size == 5) Row {
        Text("${pitch.context[0]}", verbatim = true, style = MaterialTheme.typography.headlineMedium)
        Text("회"); Text("  " + "●".repeat(pitch.context[1].coerceIn(0, 2)) + "○".repeat(2-pitch.context[1].coerceIn(0, 2)), verbatim = true)
        BaseOccupancyDiagram((1..3).filter { pitch.context[it+1] == 1 }, Modifier.size(58.dp))
    }
    Text("${index+1}/${pitches.size} · ${pitch.velocity/10}.${pitch.velocity%10} km/h", verbatim = true)
    val request = remember(pitch) { PlayerAlbum.replayRequest(pitch) }
    PitchDramaView(request, outcome = null,
        progress = frame.toFloat() / points.lastIndex.coerceAtLeast(1),
        modifier = Modifier.fillMaxWidth().height(240.dp).testTag("album.replay.canvas"))
    if (!playing && frame == points.lastIndex && pitch.outcome.isNotBlank()) Text(copy.resolve("content.pitch-outcome.${pitch.outcome}.label"), verbatim = true)
    Row {
        TextButton(enabled = index > 0, onClick = { index-- }) { Text("이전") }
        TextButton(enabled = !playing, onClick = { playing = true }) { Text("재생") }
        TextButton(enabled = index < pitches.lastIndex, onClick = { index++ }) { Text("다음") }
    }
}

@Composable
private fun AlbumCardPreview(card: AlbumShareCard, seed: String, pro: Boolean, close: () -> Unit) {
    val copy = rememberGameCopy()
    val context = LocalContext.current
    val service = remember(context) { NativePlayerAlbumShareService(context) }
    val bitmap = remember(card, seed) {
        val drawable = PlayerPortraitResolver.resolveDrawableName(seed, AvatarRole.PLAYER, if (pro) PlayerStage.PRO else PlayerStage.ACE)
        val id = context.resources.getIdentifier(drawable, "drawable", context.packageName)
        val portrait = if (id != 0) BitmapFactory.decodeResource(context.resources, id) else null
        try { service.render(card, portrait) } finally { portrait?.recycle() }
    }
    DisposableEffect(bitmap) { onDispose { bitmap.recycle() } }
    var status by remember { mutableStateOf("") }
    AlertDialog(onDismissRequest = close, title = { Text(copy.legacy("카드 미리보기"), verbatim = true) }, text = {
        Column {
            Image(bitmap.asImageBitmap(), card.title, Modifier.fillMaxWidth().aspectRatio(.8f))
            if (status.isNotBlank()) Text(copy.legacy(status), verbatim = true)
        }
    }, confirmButton = {
        TextButton(onClick = { status = if (service.share(bitmap, card.title) is ShareResult.Failed) "공유하지 못했어요. 다시 시도해 주세요." else "" }) { Text(copy.legacy("공유"), verbatim = true) }
    }, dismissButton = {
        Row {
            TextButton(onClick = { status = if (service.save(bitmap)) "사진에 저장했어요." else "저장하지 못했어요. 공유 메뉴를 이용해 주세요." }) { Text(copy.legacy("이미지 저장"), verbatim = true) }
            TextButton(onClick = close) { Text(copy.legacy("닫기"), verbatim = true) }
        }
    })
}

@Composable
internal fun AlbumStatGrid(stats: List<Pair<String, String>>) {
    val density = androidx.compose.ui.platform.LocalDensity.current
    val measurer = androidx.compose.ui.text.rememberTextMeasurer()
    val valueStyle = MaterialTheme.typography.titleMedium
    val widestValue = stats.maxOfOrNull { measurer.measure(androidx.compose.ui.text.AnnotatedString(it.second), valueStyle).size.width } ?: 0
    val minCellWidth = (with(density) { widestValue.toDp() } + 22.dp).coerceAtLeast(76.dp)
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val columns = ((maxWidth + 8.dp) / (minCellWidth + 8.dp)).toInt().coerceIn(1, 3)
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            stats.chunked(columns).forEach { row ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    row.forEach { (label, value) ->
                        Surface(color = BaseballColors.surfaceRaised, modifier = Modifier.weight(1f)) {
                            Column(Modifier.padding(horizontal = 10.dp, vertical = 8.dp)) {
                                Text(label, verbatim = true, style = MaterialTheme.typography.labelSmall, color = BaseballColors.textSecondary)
                                Text(value, verbatim = true, style = valueStyle)
                            }
                        }
                    }
                    repeat(columns-row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
    }
}
