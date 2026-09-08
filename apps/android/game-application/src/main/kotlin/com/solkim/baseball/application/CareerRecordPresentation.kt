package com.solkim.baseball.application

/** Stable selectors include the career: a new life never inherits the previous player's filter. */
public data class RecordScope(val id: String, val title: String, val player: String)
public data class CareerGameView(val id: String, val label: String, val outs: Int, val strikeouts: Int, val runs: Int,
    val walks: Int, val hits: Int, val perfect: Int, val team: Int, val opponent: Int, val manual: Boolean)
public data class CareerRecordView(val scope: RecordScope, val games: Int, val outs: Int, val runs: Int, val strikeouts: Int,
    val rows: List<CareerGameView>, val incomplete: Boolean, val inningsKnown: Boolean = true) {
    public val innings: String get() = if (inningsKnown) "${outs / 3}.${outs % 3}" else "—"
}
public object CareerRecordPresentation {
    public fun scopes(state: GameAggregateState): List<RecordScope> {
        val hs = state.highSchool
        val schools = (listOfNotNull(hs?.run?.let { RecordScope("hs:${it.careerId}", "고교", it.identity.name) }) +
            hs?.archive.orEmpty().asReversed().map { RecordScope("hs:${it.careerId}", "${it.lifeNumber}번째 생 · 고교", it.playerName) }).distinctBy { it.id }
        val pros = (listOfNotNull(state.pro) + state.meta.retiredProCareers.asReversed()).distinctBy { it.careerId }.flatMap { pro ->
            listOf(RecordScope("pro:${pro.careerId}:all", "프로 통산", pro.identityName)) +
                (pro.careerStats.map { it.season } + pro.currentStats.season).distinct().sortedDescending().map {
                    RecordScope("pro:${pro.careerId}:$it", "프로 ${it}시즌", pro.identityName)
                }
        }
        return if (state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT, GameStage.LEGACY)) pros + schools else schools + pros
    }
    public fun resolve(state: GameAggregateState, selection: String? = null): CareerRecordView? {
        val scopes = scopes(state)
        val scope = scopes.firstOrNull { it.id == selection } ?: scopes.firstOrNull() ?: return null
        val pro = (listOfNotNull(state.pro) + state.meta.retiredProCareers).firstOrNull { scope.id.startsWith("pro:${it.careerId}:") }
        if (pro != null) {
            val season = scope.id.substringAfterLast(':').toIntOrNull()
            val stats = (pro.careerStats.filter { it.season != pro.currentStats.season } + pro.currentStats).filter { season == null || it.season == season }
            val liveRows = pro.currentGameLines.filter { season == null || it.season == season }
                .distinctBy { "${it.season}:${it.week}:${it.outingNumber}" }.asReversed().map {
                    CareerGameView("pro:${pro.careerId}:${it.season}:${it.week}:${it.outingNumber}", "${it.season}시즌 · ${it.week}주차 · ${if (it.played) "직접" else "자동"}",
                        it.outs, it.strikeouts, it.runsAllowed, it.walks, it.hits, it.perfectReleases, it.teamRuns, it.opponentRuns, it.played)
                }
            val archived = state.meta.album.filter { it.scope.id.startsWith("pro:${pro.careerId}:") && (season == null || it.scope.id.substringAfterLast(':').toIntOrNull() == season) }.flatMap { it.rows }
            val rows = (archived + liveRows).associateBy { it.id }.values.toList().sortedByDescending { it.id }
            val games = stats.sumOf { it.games }
            return CareerRecordView(scope, games, stats.sumOf { it.inningsOuts }, stats.sumOf { it.runsAllowed }, stats.sumOf { it.strikeouts }, rows, rows.size < games)
        }
        val hs = state.highSchool ?: return null
        val id = scope.id.removePrefix("hs:")
        val source = hs.seasonLog.filter { it.careerId == id }
        val groups = source.groupBy { it.gameNumber }
        val rows = groups.values.toList().asReversed().map { parts ->
            val first = parts.firstOrNull { it.played } ?: parts.first()
            val mode = if (parts.any { it.played } && parts.any { !it.played }) "직접+자동" else if (first.played) "직접" else "자동"
            CareerGameView("${scope.id}:${first.gameNumber}", "${first.chapter}장 · $mode", parts.sumOf { it.outs }, parts.sumOf { it.strikeouts },
                parts.sumOf { it.runsAllowed }, parts.sumOf { it.walks }, parts.sumOf { it.hits }, parts.sumOf { it.perfectReleases }, first.teamRuns, first.opponentRuns, parts.any { it.played })
        }
        val run = hs.run.takeIf { it.careerId == id }
        val historical = hs.archive.firstOrNull { it.careerId == id }
        val manual = source.filter { it.played }
        val knownAuto = source.filter { !it.played }
        val expectedManual = run?.performance?.importantGamesCompleted ?: historical?.importantGames ?: 0
        val automaticGames = groups.values.count { parts -> parts.none { it.played } }
        val expectedGames = expectedManual + (run?.automaticGames ?: automaticGames)
        val totalOuts = maxOf(rows.sumOf { it.outs }, maxOf(manual.sumOf { it.outs }, run?.performance?.outs ?: 0) + (run?.automaticOuts ?: knownAuto.sumOf { it.outs }))
        val totalRuns = maxOf(rows.sumOf { it.runs }, (run?.performance?.runsAllowed ?: historical?.runsAllowed ?: manual.sumOf { it.runsAllowed }) + (run?.automaticRunsAllowed ?: knownAuto.sumOf { it.runsAllowed }))
        val inningsKnown = (manual.map { it.gameNumber }.distinct().size >= expectedManual || (run?.performance?.outs ?: 0) > 0) &&
            (run == null || run.automaticGames <= automaticGames || run.automaticOuts > 0)
        val missing = expectedGames > rows.size || totalOuts > rows.sumOf { it.outs } || !inningsKnown
        return CareerRecordView(scope, maxOf(rows.size, expectedGames), totalOuts, totalRuns,
            maxOf(manual.sumOf { it.strikeouts }, run?.performance?.strikeouts ?: historical?.strikeouts ?: 0) + knownAuto.sumOf { it.strikeouts }, rows, missing, inningsKnown)
    }
}
