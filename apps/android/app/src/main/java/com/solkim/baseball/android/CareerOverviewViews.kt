package com.solkim.baseball.android

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.*
import com.solkim.baseball.design.BaseballColors
import com.solkim.baseball.android.LocalizedGameText as Text

/** Local disclosure state never commits a career choice or changes the saved record. */
@Composable
internal fun CareerDisclosure(title: String, tag: String, content: @Composable () -> Unit) {
    var open by remember(tag) { mutableStateOf(false) }
    TextButton(onClick = { open = !open }, modifier = Modifier.testTag(tag)) {
        Text(title)
        Text(if (open) " ▴" else " ▾", verbatim = true)
    }
    if (open) content()
}

@Composable
internal fun CareerStatTiles(stats: List<Pair<String, String>>) {
    val copy = rememberGameCopy()
    // Statistic tiles use equal columns; actions keep their natural width.
    AdaptiveActionRow(Modifier.fillMaxWidth(), equalWidth = true) {
        stats.forEach { (label, value) ->
            Surface(color = BaseballColors.surfaceRaised, shape = RoundedCornerShape(12.dp)) {
                Column(Modifier.padding(12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(value, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = BaseballColors.action)
                    val statKey = when (label) {
                        "경기" -> "games"; "탈삼진" -> "strikeouts"; "퍼펙트 릴리스" -> "perfect"
                        "등판" -> "appearances"; "이닝" -> "innings"; "실점" -> "runs"
                        "볼넷" -> "walks"; "피안타" -> "hits"; "시즌" -> "seasons"
                        "완료" -> "completed"; "도장" -> "stamps"; "스카우트 평가" -> "evaluation"
                        else -> null
                    }
                    Text(if (statKey != null) copy.resolve("career.compact.stat.$statKey") else copy.legacy(label), verbatim = true,
                        style = MaterialTheme.typography.labelMedium, color = BaseballColors.textSecondary)
                }
            }
        }
    }
}

@Composable
internal fun CareerFact(row: ScreenRow, tag: String, revealDetail: Boolean = false) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(3.dp)) {
        if (row.label.isNotBlank()) Text(row.label, style = MaterialTheme.typography.labelMedium, color = BaseballColors.textSecondary)
        Text(row.value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        if (row.detail.isNotBlank()) {
            if (revealDetail) Text(row.detail, style = MaterialTheme.typography.bodyMedium, color = BaseballColors.textSecondary)
            else CareerDisclosure("자세히 보기", tag) { Text(row.detail, style = MaterialTheme.typography.bodyMedium, color = BaseballColors.textSecondary) }
        }
    }
}

@Composable
internal fun CareerSection(section: ScreenSection, initialCount: Int = 1) {
    Text(section.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, modifier = Modifier.semantics { heading() })
    val complete = initialCount >= section.rows.size
    section.rows.take(initialCount).forEachIndexed { index, row -> CareerFact(if (complete) row else row.copy(detail = ""), "career.${section.id}.$index", revealDetail = true) }
    if (!complete) CareerDisclosure("자세히 보기", "career.${section.id}.more") {
        section.rows.forEachIndexed { index, row -> CareerFact(row, "career.${section.id}.more.$index", revealDetail = true) }
    }
}

@Composable
internal fun CompactLifeRecap(state: GameAggregateState, model: ScreenModel) {
    // Seed challenges have a separate score contract; show their supplied result intact.
    if (state.meta.seedChallenge != null) {
        model.sections.forEach { CareerSection(it, 3) }
        return
    }
    val run = CareerUiRules.schoolFacts(state) ?: return
    Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.testTag("recap.hero")) {
        PlayerPortrait(seed = playerPortraitSeed(state) ?: run.playerName, stage = PlayerStage.ACE, width = 76.dp)
        Column(Modifier.weight(1f)) {
            Text(run.playerName, verbatim = true, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            run.drafted?.let { drafted ->
                Text(if (drafted) "프로 지명" else "고교 여정 완료",
                    style = MaterialTheme.typography.titleMedium, color = BaseballColors.milestone)
                if (!drafted) Text("드래프트 미지명", style = MaterialTheme.typography.labelMedium, color = BaseballColors.textSecondary)
            }
        }
    }
    CareerStatTiles(listOf("경기" to run.importantGames.toString(),
        "탈삼진" to run.strikeouts.toString(), "퍼펙트 릴리스" to run.perfectReleases.toString()))
    if (run.awakeningWires.isNotEmpty()) {
        Text(rememberGameCopy().resolve("awakening.tree.title"), verbatim = true, style = MaterialTheme.typography.labelLarge, color = BaseballColors.textSecondary)
        run.awakeningWires.chunked(3).forEach { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { skill ->
                    Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                        AwakeningGlyph(skill, BaseballColors.action, Modifier.size(36.dp))
                        Text(HighSchoolDisplayRules.awakeningTitle(skill), style = MaterialTheme.typography.labelSmall)
                    }
                }
            }
        }
    }
    CareerMemorySummary(state)
    CareerDisclosure("성적과 지명 평가", "recap.details") {
        model.sections.filter { it.id in setOf("draft-reasons", "life-story") }.forEach { CareerSection(it, it.rows.size) }
    }
}

/** Reviewing a candidate is reversible; only the explicit confirmation invokes its command. */
@Composable
internal fun CareerLegacyPicker(model: ScreenModel, actions: List<ScreenActionModel>, onAction: (ScreenUiAction) -> Unit) {
    var selectedId by remember(model.id, actions.map { it.id }) { mutableStateOf<String?>(null) }
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
    Text("이어받을 능력", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    actions.forEach { action ->
        val chosen = action.id == selectedId
        Surface(color = if (chosen) BaseballColors.actionSoft else BaseballColors.surfaceRaised,
            border = BorderStroke(if (chosen) 2.dp else 1.dp, if (chosen) BaseballColors.action else BaseballColors.border),
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth().testTag("legacy.option.${action.id}")
                .semantics { selected = chosen; role = Role.RadioButton }
                .clickable(enabled = action.enabled) { selectedId = action.id }) {
            Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    val family = CareerUiRules.legacyFamily(action.id.substringAfter(':'))
                    val glyph = when (family) { "power" -> "rising_four_seam"; "command" -> "pinpoint_edge"; "breaking" -> "curveball_clock"; "endurance" -> "iron_arm"; else -> "calm_under_pressure" }
                    AwakeningGlyph(glyph, if (chosen) BaseballColors.action else BaseballColors.milestone, Modifier.size(30.dp))
                    Text(action.label, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold,
                        color = if (chosen) BaseballColors.action else BaseballColors.textPrimary)
                }
                // Effect text is decision-critical and is never clipped or hidden behind a tooltip.
                if (action.description.isNotBlank()) Text(action.description, style = MaterialTheme.typography.bodySmall, color = BaseballColors.textSecondary)
            }
        }
    }
    val selected = actions.firstOrNull { it.id == selectedId }
    if (selected != null) {
        val evidence = model.sections.firstOrNull { it.id == "pro-legacy" }?.rows?.firstOrNull { it.label == selected.label }
        if (evidence != null) CareerDisclosure("이 능력을 남긴 기록", "legacy.evidence") { CareerFact(evidence, "legacy.evidence.detail") }
    }
    Button(enabled = selected?.enabled == true, onClick = { selected?.let { onAction(ScreenUiAction(model.id, it.id, it.payloads)) } },
        modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("legacy.confirm")) {
        Text("이 능력 이어받기")
    }
    }
}

private data class CareerGameCard(val label: String, val outs: Int, val strikeouts: Int, val runs: Int,
    val walks: Int, val hits: Int, val perfect: Int, val team: Int, val opponent: Int)

@Composable
private fun CareerGameList(games: List<CareerGameCard>) {
    if (games.isEmpty()) { Text("첫 등판을 마치면 기록이 쌓여요.", color = BaseballColors.textSecondary); return }
    var count by remember(games.size) { mutableIntStateOf(5) }
    games.take(count).forEachIndexed { index, game ->
        if (index > 0) {
            var expanded by remember(game) { mutableStateOf(false) }
            Surface(color = BaseballColors.surfaceRaised, shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth().testTag("records.game.$index").clickable { expanded = !expanded }) {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(game.label, style = MaterialTheme.typography.labelMedium, color = BaseballColors.textSecondary)
                        Text("${game.team}–${game.opponent} ${if (expanded) "▴" else "▾"}", verbatim = true, style = MaterialTheme.typography.titleSmall)
                    }
                    Text(rememberGameCopy().resolve("career.compact.game-line", GameCopyArgument.UserText("${game.outs / 3}.${game.outs % 3}"),
                        GameCopyArgument.Whole(game.strikeouts.toLong()), GameCopyArgument.Whole(game.runs.toLong())), verbatim = true, style = MaterialTheme.typography.bodyMedium)
                    if (expanded) {
                        Text(when { game.team > game.opponent -> "팀 승리"; game.team < game.opponent -> "팀 패배"; else -> "팀 무승부" }, style = MaterialTheme.typography.labelMedium)
                        CareerStatTiles(listOf("볼넷" to "${game.walks}", "피안타" to "${game.hits}", "퍼펙트 릴리스" to "${game.perfect}"))
                    }
                }
            }
            return@forEachIndexed
        }
        Surface(color = BaseballColors.surfaceRaised, shape = RoundedCornerShape(12.dp)) {
            Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(game.label, style = MaterialTheme.typography.labelMedium)
                    Text(when { game.team > game.opponent -> "팀 승리"; game.team < game.opponent -> "팀 패배"; else -> "팀 무승부" },
                        color = if (game.team > game.opponent) BaseballColors.action else BaseballColors.textSecondary,
                        style = MaterialTheme.typography.labelMedium)
                }
                Text("${game.team}–${game.opponent}", verbatim = true, style = if (index == 0) MaterialTheme.typography.headlineMedium else MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold)
                CareerStatTiles(listOf("이닝" to "${game.outs / 3}.${game.outs % 3}", "탈삼진" to "${game.strikeouts}", "실점" to "${game.runs}"))
                if (game.perfect > 0) {
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text("퍼펙트 릴리스", style = MaterialTheme.typography.labelMedium, color = BaseballColors.milestone)
                        Text("${game.perfect}", verbatim = true, style = MaterialTheme.typography.labelMedium, color = BaseballColors.milestone)
                    }
                }
                CareerDisclosure("투구 상세", "records.game.$index") {
                    CareerStatTiles(listOf("볼넷" to "${game.walks}", "피안타" to "${game.hits}"))
                }
            }
        }
    }
    if (games.size > count) TextButton(onClick = { count += 5 }, modifier = Modifier.testTag("records.more")) { Text("지난 경기 더 보기") }
}

@Composable
@OptIn(ExperimentalMaterial3Api::class)
internal fun CompactCareerOverview(state: GameAggregateState, model: ScreenModel, onAction: (ScreenUiAction) -> Unit) {
    val copy = rememberGameCopy()
    when (model.id) {
        ScreenId.P011_HIGH_SCHOOL_CAREER -> {
            var scope by remember(state.stage, CareerUiRules.highSchoolCareerId(state), CareerUiRules.proCareerId(state)) { mutableStateOf<String?>(null) }
            val records = CareerRecordPresentation.resolve(state, scope)
            if (records != null) {
                val scopes = CareerRecordPresentation.scopes(state)
                if (scopes.size > 1) CareerDisclosure("기록 범위", "records.scope") {
                    scopes.forEach { option ->
                        FilterChip(selected = records.scope.id == option.id, onClick = { scope = option.id },
                            colors = FilterChipDefaults.filterChipColors(selectedContainerColor = BaseballColors.action, selectedLabelColor = BaseballColors.actionInk),
                            label = { Text(option.title + " · " + option.player) }, modifier = Modifier.testTag("records.scope.${option.id}"))
                    }
                }
                Text(records.scope.title + " · " + records.scope.player, style = MaterialTheme.typography.labelMedium)
                CareerStatTiles(listOf("등판" to records.games.toString(), "이닝" to records.innings, "실점" to records.runs.toString()))
                CareerDisclosure("상세 투구 기록", "records.pitching.stats") {
                    val pitching = AlbumPitchingStats.from(records)
                    AlbumStatGrid(pitching.line)
                    AlbumStatGrid(pitching.rates)
                }
                if (records.incomplete) Text("누적 기록은 보존했어요. 개별 등판은 저장된 경기부터 보여드려요.", style = MaterialTheme.typography.bodySmall)
                Text("최근 등판", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                if (records.rows.isEmpty() && records.games > 0) Text("이전 경기의 개별 기록은 남아 있지 않아요.", style = MaterialTheme.typography.bodySmall)
                else key(records.scope.id) { CareerGameList(records.rows.map { CareerGameCard(it.label, it.outs, it.strikeouts, it.runs,
                    it.walks, it.hits, it.perfect, it.team, it.opponent) }) }
            }

        }
        ScreenId.P024_WEEKLY -> {
            val weekly = CareerUiRules.weekly(state)
            val tasks = weekly?.tasks.orEmpty()
            CareerStatTiles(listOf("완료" to "${tasks.count { it.completed }}/${tasks.size}", "도장" to "${weekly?.stamps?.size ?: 0}"))
            Text(WeeklyNotePolicy.explanation(state), style = MaterialTheme.typography.bodyMedium, color = BaseballColors.textSecondary, modifier = Modifier.testTag("weekly.requirement"))
            val rows = model.sections.firstOrNull { it.id == "weekly" }?.rows.orEmpty().drop(4).take(tasks.size)
            tasks.forEachIndexed { index, task ->
                Text(rows.getOrNull(index)?.label.orEmpty(), style = MaterialTheme.typography.titleMedium)
                LinearProgressIndicator(progress = { (task.progress.toFloat() / task.target.coerceAtLeast(1)).coerceIn(0f, 1f) }, modifier = Modifier.fillMaxWidth())
                Text("${task.progress}/${task.target}", verbatim = true, style = MaterialTheme.typography.labelMedium)
            }
            CareerDisclosure("지난 도장과 보상 안내", "weekly.details") { model.sections.forEach { CareerSection(it, it.rows.size) } }
        }
        ScreenId.P026_ACHIEVEMENTS -> {
            val rows = model.sections.firstOrNull { it.id == "achievements" }?.rows.orEmpty()
            val unlocked = CareerUiRules.achievements(state)
            val pending = CareerUiRules.unacknowledgedAchievements(state)
            val ids = CareerUiRules.achievementIds(state)
            val items = ids.zip(rows).sortedBy { (id, _) -> if (id in pending) 0 else if (id in unlocked) 1 else 2 }
            var selectedId by remember { mutableStateOf<String?>(null) }
            items.chunked(2).forEach { pair ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    pair.forEach { (id, row) ->
                        Surface(color = if (selectedId == id) BaseballColors.actionSoft else BaseballColors.surfaceRaised,
                            border = BorderStroke(1.dp, if (selectedId == id) BaseballColors.action else BaseballColors.border),
                            shape = RoundedCornerShape(12.dp), modifier = Modifier.weight(1f).heightIn(min = 90.dp).testTag("achievement.$id")
                                .semantics { selected = selectedId == id; role = Role.Button }.clickable { selectedId = id }) {
                            Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text(if (id in unlocked) "◆" else "◇", verbatim = true, color = if (id in unlocked) BaseballColors.milestone else BaseballColors.textTertiary)
                                Text(row.label, style = MaterialTheme.typography.titleSmall)
                                Text(row.value, style = MaterialTheme.typography.labelSmall, color = BaseballColors.textSecondary)
                            }
                        }
                    }
                }
            }
            items.firstOrNull { it.first == selectedId }?.let { (id, row) ->
                ModalBottomSheet(onDismissRequest = { selectedId = null }) {
                    Column(Modifier.padding(20.dp).navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text(row.label, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                        Text(row.detail, style = MaterialTheme.typography.bodyMedium)
                        model.actions.firstOrNull { it.enabled && it.id == "ack:$id" }?.let { action ->
                            Button(onClick = { onAction(ScreenUiAction(model.id, action.id, action.payloads)); selectedId = null }, modifier = Modifier.testTag("achievement.confirm")) { Text("확인") }
                        }
                    }
                }
            }
        }
        ScreenId.P028_LIFECARD -> {
            val archive = CareerUiRules.archive(state).asReversed()
            if (archive.isEmpty()) Text("한 생을 마치면 카드가 남아요.", color = BaseballColors.textSecondary)
            archive.forEachIndexed { index, record ->
                if (index == 0) LifeCardVisual(state, record.careerId)
                else CareerDisclosure(record.playerName, "life.${record.careerId}") { LifeCardVisual(state, record.careerId) }
            }
        }
        ScreenId.P029_RETURN_PLAN -> {
            model.sections.firstOrNull()?.rows?.firstOrNull()?.let { CareerFact(it, "return.destination") }
            // Notification timing must remain visible before choosing the reminder.
            model.sections.firstOrNull()?.rows?.lastOrNull()?.let { Text(it.value, style = MaterialTheme.typography.bodyMedium) }
        }
        ScreenId.P022_PRO_LEGACY -> {
            val pro = ProfessionalStatusPresentation.season(state)
            CareerStatTiles(listOf("시즌" to "${pro?.seasonCount ?: 0}", "탈삼진" to "${pro?.totalStrikeouts ?: 0}"))
            CareerLegacyPicker(model, model.actions.filter { it.id.startsWith("selectProLegacy:") && it.enabled }, onAction)
            model.sections.filter { it.id != "pro-legacy" }.forEach { section -> CareerDisclosure(section.title, "legacy.${section.id}") { CareerSection(section, section.rows.size) } }
        }
        ScreenId.P019_PRO_SEASON -> {
            val pro = ProfessionalStatusPresentation.season(state)
            val ordinary = model.sections.all { it.id in setOf("season-settlement", "pro-season", "pro-game-log") }
            if (ordinary && pro != null) {
                Text(model.sections.firstOrNull()?.title.orEmpty(), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                CareerStatTiles(listOf("등판" to "${pro.games}", "이닝" to "${pro.inningsOuts / 3}.${pro.inningsOuts % 3}", "탈삼진" to "${pro.strikeouts}"))
                model.sections.firstOrNull { it.id == "pro-season" }?.rows?.getOrNull(2)?.let { CareerFact(it, "season.team") }
                if (pro.pendingTitle != null) CareerMemoryPresentation.conversationRecall(state, copy)?.let { Text(it, verbatim = true, color = BaseballColors.milestone) }
                pro.pendingTitle?.let { title -> CareerFact(ScreenRow(title, pro.pendingDetail.orEmpty()), "season.decision", revealDetail = true) }
                if (pro.awards.isNotEmpty()) Text("최근 수상", style = MaterialTheme.typography.labelMedium, color = BaseballColors.textSecondary)
                pro.awards.takeLast(3).forEach { Text(it, style = MaterialTheme.typography.labelLarge, color = BaseballColors.milestone) }
                CareerDisclosure("시즌 성적과 정산", "season.details") {
                    model.sections.filter { it.id != "pro-game-log" }.forEach { CareerSection(it, it.rows.size) }
                }
            } else {
                // National-team call-ups and branching decisions keep their conditions visible.
                model.sections.filter { it.id != "pro-game-log" }.forEach { section ->
                    Text(section.title, style = MaterialTheme.typography.titleLarge)
                    section.rows.forEachIndexed { index, row -> CareerFact(row, "season.decision.${section.id}.$index", revealDetail = true) }
                }
            }
            val games = pro?.weekLines.orEmpty()
            if (games.isNotEmpty()) CareerDisclosure("시즌 등판 기록", "season.games") {
                CareerGameList(games.asReversed().map { CareerGameCard(copy.resolve("career.compact.week", GameCopyArgument.Whole(it.week.toLong())), it.outs, it.strikeouts, it.runs, it.walks, it.hits, it.perfectReleases, it.teamRuns, it.opponentRuns) })
            }
        }
        ScreenId.P025_RECORDS_LEAGUE -> {
            val records = CareerRecordPresentation.resolve(state)
            if (records == null || records.games == 0) {
                Text("첫 등판 전", style = MaterialTheme.typography.titleLarge)
                Text("등판을 마치면 내 기록이 여기에 쌓여요.")
            } else {
                Text(records.scope.player, verbatim = true, style = MaterialTheme.typography.titleLarge)
                CareerStatTiles(listOf("등판" to records.games.toString(), "이닝" to records.innings, "탈삼진" to records.strikeouts.toString()))
            }
            model.sections.filter { it.id.startsWith("retired:") }.forEach { CareerSection(it, 3) }
            val ranking = model.sections.firstOrNull { it.id == "records" }?.rows.orEmpty().filter { it.detail in setOf("내 구단", "리그 순위") }
            if (ranking.isNotEmpty()) CareerDisclosure("리그 순위", "records.standings") {
                ranking.forEachIndexed { index, row -> CareerFact(row, "records.rank.$index", revealDetail = true) }
            }

        }
        ScreenId.P021_PRO_RETIREMENT -> {
            CareerMemorySummary(state)
            val pro = ProfessionalStatusPresentation.season(state)
            if (pro != null) {
                CareerStatTiles(listOf("시즌" to "${pro.seasonCount}", "등판" to "${pro.totalGames}", "탈삼진" to "${pro.totalStrikeouts}"))
            }
            model.sections.forEach { section ->
                Text(section.rows.firstOrNull()?.label ?: section.title, style = MaterialTheme.typography.headlineSmall)
                // Career outcome and the next-life reward are visible before irreversible retirement.
                section.rows.drop(1).take(2).forEachIndexed { index, row -> CareerFact(row, "retirement.$index") }
                if (section.rows.size > 3) CareerDisclosure("통산 수입과 훈장", "retirement.honors") {
                    section.rows.drop(3).forEachIndexed { index, row -> CareerFact(row, "retirement.honor.$index") }
                }
            }
        }
        else -> model.sections.forEach { CareerSection(it, if (it.id == "league") 3 else 1) }
    }
}

internal val compactCareerScreens = setOf(ScreenId.P011_HIGH_SCHOOL_CAREER, ScreenId.P012_TOURNAMENT_LEAGUE,
    ScreenId.P019_PRO_SEASON, ScreenId.P021_PRO_RETIREMENT, ScreenId.P022_PRO_LEGACY,
    ScreenId.P024_WEEKLY, ScreenId.P025_RECORDS_LEAGUE, ScreenId.P026_ACHIEVEMENTS,
    ScreenId.P028_LIFECARD, ScreenId.P029_RETURN_PLAN)

@Composable
internal fun CareerMemorySummary(state: GameAggregateState) {
    val memories = CareerMemoryPresentation.featured(state, includePrevious = true)
    if (memories.isEmpty()) return
    val copy = rememberGameCopy()
    Text("내 투수가 해낸 일", style = MaterialTheme.typography.titleMedium, color = BaseballColors.milestone)
    memories.forEach { memory ->
        Text(copy.resolve("companion.memory.${memory.kind}"), verbatim = true, style = MaterialTheme.typography.bodyMedium)
        Text(CareerMemoryPresentation.detail(memory, copy), verbatim = true, style = MaterialTheme.typography.bodySmall)
    }
}
