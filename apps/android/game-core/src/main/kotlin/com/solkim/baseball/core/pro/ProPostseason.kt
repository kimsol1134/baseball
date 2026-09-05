package com.solkim.baseball.core.pro

import com.solkim.baseball.core.StableHash
import com.solkim.baseball.core.pitch.RivalMemorySnapshot
import kotlin.math.max
import kotlin.math.min

public enum class ProAutumnRound(public val wire: String) {
    WILD_CARD("wild_card"),
    SEMIFINAL("semifinal"),
    PLAYOFF("playoff"),
    FINAL("final"),
}

public enum class ProPostseasonResult(public val wire: String) {
    IN_PROGRESS("in_progress"),
    ELIMINATED("eliminated"),
    CHAMPION("champion"),
    RUNNER_UP("runner_up"),
    DID_NOT_QUALIFY("did_not_qualify"),
    UNAVAILABLE("unavailable"),
}

public enum class ProPostseasonAvailabilityChoice(public val wire: String) {
    PITCH_AGAIN("pitch_again"),
    REST_FOR_DECIDER("rest_for_decider"),
}

public enum class ProPostseasonGameStakes(public val wire: String) {
    STANDARD("standard"),
    CLINCH("clinch"),
    ELIMINATION("elimination"),
    WINNER_TAKE_ALL("winner_take_all"),
}

public enum class ProPostseasonArmRisk(public val wire: String) {
    MANAGEABLE("manageable"),
    ELEVATED("elevated"),
    SEVERE("severe"),
}

public data class ProPostseasonGameLine(
    val round: ProAutumnRound? = null,
    val gameNumber: Int,
    val teamRuns: Int,
    val opponentRuns: Int,
    val directlyPlayed: Boolean,
    val playerPitches: Int? = null,
    val playerOuts: Int? = null,
    val playerRunsAllowed: Int? = null,
    val playerStrikeouts: Int? = null,
    val playerWalks: Int? = null,
    val playerHits: Int? = null,
    val playerStarted: Boolean? = null,
) {
    public val id: String get() = "${round?.wire ?: "unknown"}-$gameNumber"
    public val won: Boolean get() = teamRuns > opponentRuns
}

public data class ProPostseasonSeriesState(
    val round: ProAutumnRound? = null,
    val opponentTeamId: String? = null,
    val playerWinsRequired: Int? = null,
    val opponentWinsRequired: Int? = null,
    val playerWins: Int = 0,
    val opponentWins: Int = 0,
    val nextGameNumber: Int = 1,
    val totalDirectAppearances: Int = 0,
    val lastAppearancePitches: Int? = null,
    val lastAppearanceGameNumber: Int? = null,
    val availabilityDecision: ProPostseasonAvailabilityChoice? = null,
    val gameLines: List<ProPostseasonGameLine>? = null,
    val rivalMemory: RivalMemorySnapshot? = null,
)

public data class ProPostseasonState(
    val seed: Int,
    val currentRound: ProAutumnRound?,
    val result: ProPostseasonResult,
    val gamesPlayed: Int,
    val series: ProPostseasonSeriesState? = null,
    val gameHistory: List<ProPostseasonGameLine>? = null,
)

public object ProPostseasonRules {
    public const val QUALIFICATION_CUT: Int = 5
    public const val MAXIMUM_PLAYER_PATH_GAMES: Int = 5
    public const val MAXIMUM_DIRECT_APPEARANCES: Int = 5
    public const val FINAL_WINS_REQUIRED: Int = 3

    public fun trigger(round: ProAutumnRound): ProSeasonTrigger = when (round) {
        ProAutumnRound.WILD_CARD -> ProSeasonTrigger.AUTUMN_WILD_CARD
        ProAutumnRound.SEMIFINAL -> ProSeasonTrigger.AUTUMN_SEMIFINAL
        ProAutumnRound.PLAYOFF -> ProSeasonTrigger.AUTUMN_PLAYOFF
        ProAutumnRound.FINAL -> ProSeasonTrigger.AUTUMN_FINAL
    }

    public fun isAutumn(trigger: ProSeasonTrigger?): Boolean = when (trigger) {
        ProSeasonTrigger.AUTUMN_WILD_CARD,
        ProSeasonTrigger.AUTUMN_SEMIFINAL,
        ProSeasonTrigger.AUTUMN_PLAYOFF,
        ProSeasonTrigger.AUTUMN_FINAL,
        -> true
        else -> false
    }

    public fun firstRound(seed: Int): ProAutumnRound = when (seed) {
        1 -> ProAutumnRound.FINAL
        2 -> ProAutumnRound.PLAYOFF
        3 -> ProAutumnRound.SEMIFINAL
        else -> ProAutumnRound.WILD_CARD
    }

    public fun nextRound(after: ProAutumnRound): ProAutumnRound? = when (after) {
        ProAutumnRound.WILD_CARD -> ProAutumnRound.SEMIFINAL
        ProAutumnRound.SEMIFINAL -> ProAutumnRound.PLAYOFF
        ProAutumnRound.PLAYOFF -> ProAutumnRound.FINAL
        ProAutumnRound.FINAL -> null
    }

    public fun extraOffset(round: ProAutumnRound): Int = when (round) {
        ProAutumnRound.WILD_CARD -> 3
        ProAutumnRound.SEMIFINAL -> 4
        ProAutumnRound.PLAYOFF -> 5
        ProAutumnRound.FINAL -> 6
    }

    public fun maximumBatters(round: ProAutumnRound): Int = when (round) {
        ProAutumnRound.WILD_CARD -> 4
        ProAutumnRound.SEMIFINAL -> 5
        ProAutumnRound.PLAYOFF -> 6
        ProAutumnRound.FINAL -> 7
    }

    public fun maximumBatters(role: ProRole, round: ProAutumnRound): Int = when (role) {
        ProRole.STARTER -> if (round == ProAutumnRound.FINAL) 7 else 6
        ProRole.LONG_RELIEF -> if (round == ProAutumnRound.FINAL) 6 else 5
        ProRole.SETUP -> 4
        ProRole.CLOSER -> 3
    }

    public fun winsRequired(round: ProAutumnRound, seed: Int): Pair<Int, Int> = when (round) {
        ProAutumnRound.WILD_CARD -> if (seed == 4) 1 to 2 else 2 to 1
        ProAutumnRound.SEMIFINAL, ProAutumnRound.PLAYOFF -> 2 to 2
        ProAutumnRound.FINAL -> FINAL_WINS_REQUIRED to FINAL_WINS_REQUIRED
    }

    public fun openingSeries(
        round: ProAutumnRound,
        seed: Int,
        opponentTeamId: String?,
        previousDirectAppearances: Int,
    ): ProPostseasonSeriesState {
        val requirements = winsRequired(round, seed)
        return ProPostseasonSeriesState(
            round = round,
            opponentTeamId = opponentTeamId,
            playerWinsRequired = requirements.first,
            opponentWinsRequired = requirements.second,
            totalDirectAppearances = min(MAXIMUM_DIRECT_APPEARANCES, max(0, previousDirectAppearances)),
            gameLines = emptyList(),
        )
    }

    public fun shouldDirectlyPlayNextGame(state: ProPostseasonState, role: ProRole): Boolean {
        val round = state.currentRound ?: return false
        if (state.result != ProPostseasonResult.IN_PROGRESS) return false
        val series = state.series ?: openingSeries(round, state.seed, null, state.gamesPlayed)
        if (series.totalDirectAppearances >= MAXIMUM_DIRECT_APPEARANCES) return false
        return when (role) {
            ProRole.STARTER -> series.nextGameNumber % 2 == 1
            ProRole.LONG_RELIEF, ProRole.SETUP, ProRole.CLOSER -> true
        }
    }

    public fun isConsecutiveAppearanceSituation(state: ProPostseasonState, role: ProRole): Boolean {
        if (role == ProRole.STARTER) return false
        if (!shouldDirectlyPlayNextGame(state, role)) return false
        val series = state.series ?: return false
        val lastGame = series.lastAppearanceGameNumber ?: return false
        return series.nextGameNumber == lastGame + 1
    }

    public fun requiresAvailabilityDecision(state: ProPostseasonState, role: ProRole): Boolean =
        isConsecutiveAppearanceSituation(state, role) && state.series?.availabilityDecision == null

    public fun canStartDirectAppearance(state: ProPostseasonState, role: ProRole): Boolean {
        if (!shouldDirectlyPlayNextGame(state, role)) return false
        if (!isConsecutiveAppearanceSituation(state, role)) return true
        return state.series?.availabilityDecision == ProPostseasonAvailabilityChoice.PITCH_AGAIN
    }

    public fun choosingAvailability(
        state: ProPostseasonState,
        choice: ProPostseasonAvailabilityChoice,
    ): ProPostseasonState {
        val current = state.series ?: return state
        return state.copy(series = current.copy(availabilityDecision = choice))
    }

    public fun consecutiveAppearanceFatiguePenalty(role: ProRole, lastAppearancePitches: Int): Int {
        val pitchLoad = max(4, (max(0, lastAppearancePitches) + 4) / 5)
        return when (role) {
            ProRole.STARTER -> 0
            ProRole.LONG_RELIEF -> pitchLoad + 2
            ProRole.SETUP -> pitchLoad + 1
            ProRole.CLOSER -> pitchLoad
        }
    }

    public fun stakes(state: ProPostseasonState): ProPostseasonGameStakes {
        val round = state.currentRound ?: return ProPostseasonGameStakes.STANDARD
        val series = state.series ?: openingSeries(round, state.seed, null, state.gamesPlayed)
        val requirements = winsRequired(round, state.seed)
        val playerRequired = series.playerWinsRequired ?: requirements.first
        val opponentRequired = series.opponentWinsRequired ?: requirements.second
        val canClinch = series.playerWins + 1 >= playerRequired
        val canBeEliminated = series.opponentWins + 1 >= opponentRequired
        return when {
            canClinch && canBeEliminated -> ProPostseasonGameStakes.WINNER_TAKE_ALL
            canClinch -> ProPostseasonGameStakes.CLINCH
            canBeEliminated -> ProPostseasonGameStakes.ELIMINATION
            else -> ProPostseasonGameStakes.STANDARD
        }
    }

    public fun armRisk(projectedFatigue: Int): ProPostseasonArmRisk = when (min(100, max(0, projectedFatigue))) {
        in 0 until 72 -> ProPostseasonArmRisk.MANAGEABLE
        in 72 until 88 -> ProPostseasonArmRisk.ELEVATED
        else -> ProPostseasonArmRisk.SEVERE
    }

    public fun resolvingSeriesGame(
        state: ProPostseasonState,
        won: Boolean,
        directlyPlayed: Boolean,
        pitches: Int? = null,
        outs: Int? = null,
        runsAllowed: Int? = null,
        teamRuns: Int? = null,
        opponentRuns: Int? = null,
        rivalMemory: RivalMemorySnapshot? = null,
        strikeouts: Int? = null,
        walks: Int? = null,
        hits: Int? = null,
        started: Boolean? = null,
    ): ProPostseasonState {
        require(state.result == ProPostseasonResult.IN_PROGRESS && state.currentRound != null)
        val round = state.currentRound ?: ProAutumnRound.FINAL
        val current = state.series ?: openingSeries(round, state.seed, null, state.gamesPlayed)
        val requirements = winsRequired(round, state.seed)
        val playerRequired = current.playerWinsRequired ?: requirements.first
        val opponentRequired = current.opponentWinsRequired ?: requirements.second
        val playerWins = current.playerWins + if (won) 1 else 0
        val opponentWins = current.opponentWins + if (won) 0 else 1
        val appearances = min(
            MAXIMUM_DIRECT_APPEARANCES,
            current.totalDirectAppearances + if (directlyPlayed) 1 else 0,
        )
        val canContinueGameLedger = current.gameLines != null || current.nextGameNumber == 1
        val newLine = if (teamRuns != null && opponentRuns != null) {
            ProPostseasonGameLine(
                round = round,
                gameNumber = current.nextGameNumber,
                teamRuns = teamRuns,
                opponentRuns = opponentRuns,
                directlyPlayed = directlyPlayed,
                playerPitches = if (directlyPlayed) max(0, pitches ?: 0) else null,
                playerOuts = if (directlyPlayed) max(0, outs ?: 0) else null,
                playerRunsAllowed = if (directlyPlayed) max(0, runsAllowed ?: 0) else null,
                playerStrikeouts = if (directlyPlayed) strikeouts?.let { max(0, it) } else null,
                playerWalks = if (directlyPlayed) walks?.let { max(0, it) } else null,
                playerHits = if (directlyPlayed) hits?.let { max(0, it) } else null,
                playerStarted = if (directlyPlayed) started else null,
            )
        } else null
        val gameLines = if (canContinueGameLedger && newLine != null) {
            (current.gameLines ?: emptyList()) + newLine
        } else current.gameLines
        val canContinueHistory = state.gameHistory != null || state.gamesPlayed == 0
        val history = if (canContinueHistory && newLine != null) {
            (state.gameHistory ?: emptyList()) + newLine
        } else state.gameHistory
        val series = ProPostseasonSeriesState(
            round = round,
            opponentTeamId = current.opponentTeamId,
            playerWinsRequired = playerRequired,
            opponentWinsRequired = opponentRequired,
            playerWins = playerWins,
            opponentWins = opponentWins,
            nextGameNumber = current.nextGameNumber + 1,
            totalDirectAppearances = appearances,
            lastAppearancePitches = if (directlyPlayed) max(0, pitches ?: 0) else current.lastAppearancePitches,
            lastAppearanceGameNumber = if (directlyPlayed) current.nextGameNumber else current.lastAppearanceGameNumber,
            availabilityDecision = null,
            gameLines = gameLines,
            rivalMemory = if (directlyPlayed) (rivalMemory ?: current.rivalMemory) else current.rivalMemory,
        )
        val played = state.gamesPlayed + 1
        if (playerWins >= playerRequired) {
            val next = nextRound(round)
            if (next != null) {
                return ProPostseasonState(
                    seed = state.seed,
                    currentRound = next,
                    result = ProPostseasonResult.IN_PROGRESS,
                    gamesPlayed = played,
                    series = openingSeries(next, state.seed, null, appearances),
                    gameHistory = history,
                )
            }
            return ProPostseasonState(
                seed = state.seed,
                currentRound = ProAutumnRound.FINAL,
                result = ProPostseasonResult.CHAMPION,
                gamesPlayed = played,
                series = series,
                gameHistory = history,
            )
        }
        if (opponentWins >= opponentRequired) {
            return ProPostseasonState(
                seed = state.seed,
                currentRound = round,
                result = if (round == ProAutumnRound.FINAL) ProPostseasonResult.RUNNER_UP else ProPostseasonResult.ELIMINATED,
                gamesPlayed = played,
                series = series,
                gameHistory = history,
            )
        }
        return ProPostseasonState(
            seed = state.seed,
            currentRound = round,
            result = ProPostseasonResult.IN_PROGRESS,
            gamesPlayed = played,
            series = series,
            gameHistory = history,
        )
    }

    public fun resolving(state: ProPostseasonState, won: Boolean): ProPostseasonState {
        val played = state.gamesPlayed + 1
        val round = state.currentRound ?: return ProPostseasonState(state.seed, null, ProPostseasonResult.ELIMINATED, played)
        if (round == ProAutumnRound.WILD_CARD) return resolvingWildCard(state, won, played)
        if (won) {
            val next = nextRound(round)
            return if (next != null) {
                ProPostseasonState(state.seed, next, ProPostseasonResult.IN_PROGRESS, played)
            } else {
                ProPostseasonState(state.seed, ProAutumnRound.FINAL, ProPostseasonResult.CHAMPION, played)
            }
        }
        val result = if (round == ProAutumnRound.FINAL) ProPostseasonResult.RUNNER_UP else ProPostseasonResult.ELIMINATED
        return ProPostseasonState(state.seed, round, result, played)
    }

    private fun resolvingWildCard(state: ProPostseasonState, won: Boolean, played: Int): ProPostseasonState {
        val advance = ProPostseasonState(state.seed, ProAutumnRound.SEMIFINAL, ProPostseasonResult.IN_PROGRESS, played)
        val stay = ProPostseasonState(state.seed, ProAutumnRound.WILD_CARD, ProPostseasonResult.IN_PROGRESS, played)
        val out = ProPostseasonState(state.seed, ProAutumnRound.WILD_CARD, ProPostseasonResult.ELIMINATED, played)
        if (state.seed == 4) {
            return if (won) advance else if (played == 1) stay else out
        }
        if (!won) return out
        return if (played == 1) stay else advance
    }

    public fun evaluateEndOfSeason(state: ProState): ProPostseasonState {
        val rows = standings(state, ProCatalog.WEEKS_PER_SEASON)
        val rank = rows.indexOfFirst { it.teamId == state.team.id }.let { if (it >= 0) it + 1 else 10 }
        if (rank > QUALIFICATION_CUT) {
            return ProPostseasonState(0, null, ProPostseasonResult.DID_NOT_QUALIFY, 0)
        }
        val round = firstRound(rank)
        return ProPostseasonState(rank, round, ProPostseasonResult.IN_PROGRESS, 0)
    }

    public fun canPitchAutumn(level: ProLevel, injuryWeeks: Int): Boolean =
        level == ProLevel.MAJOR && injuryWeeks <= 0

    public fun playerPath(
        evaluated: ProPostseasonState,
        level: ProLevel,
        injuryWeeks: Int,
    ): ProPostseasonState {
        if (evaluated.result != ProPostseasonResult.IN_PROGRESS) return evaluated
        if (!canPitchAutumn(level, injuryWeeks)) {
            return ProPostseasonState(evaluated.seed, null, ProPostseasonResult.UNAVAILABLE, 0)
        }
        return evaluated
    }

    public fun preparingSeries(postseason: ProPostseasonState, state: ProState): ProPostseasonState {
        if (postseason.result != ProPostseasonResult.IN_PROGRESS) return postseason
        val round = postseason.currentRound ?: return postseason
        if (postseason.series?.round == round && postseason.series.opponentTeamId != null) return postseason
        val opponentId = opponentTeamId(state, postseason, round)
        val requirements = winsRequired(round, postseason.seed)
        val series = if (postseason.series != null) {
            postseason.series.copy(
                round = round,
                opponentTeamId = opponentId,
                playerWinsRequired = requirements.first,
                opponentWinsRequired = requirements.second,
            )
        } else {
            openingSeries(round, postseason.seed, opponentId, postseason.gamesPlayed)
        }
        return postseason.copy(series = series)
    }

    public fun opponentTeamId(
        state: ProState,
        postseason: ProPostseasonState,
        round: ProAutumnRound,
    ): String? {
        val rows = standings(state, ProCatalog.WEEKS_PER_SEASON)
        fun teamId(seed: Int): String? = rows.getOrNull(seed - 1)?.teamId
        val candidates = when (round) {
            ProAutumnRound.WILD_CARD -> listOf(if (postseason.seed == 4) 5 else 4)
            ProAutumnRound.SEMIFINAL -> if (postseason.seed == 3) listOf(4, 5) else listOf(3)
            ProAutumnRound.PLAYOFF -> if (postseason.seed == 2) listOf(3, 4, 5) else listOf(2)
            ProAutumnRound.FINAL -> if (postseason.seed == 1) listOf(2, 3, 4, 5) else listOf(1)
        }
        val available = candidates.mapNotNull { seed -> teamId(seed)?.let { seed to it } }
        if (available.isEmpty()) return null
        if (available.size == 1) return available[0].second
        val weights = available.indices.map { index ->
            val value = available.size - index
            value * value
        }
        val total = weights.sum()
        var roll = (StableHash.fnv1a64Value(
            "postseason-opponent|${state.careerId}|${state.season}|${round.wire}",
        ) % total.toULong()).toInt()
        weights.forEachIndexed { index, weight ->
            if (roll < weight) return available[index].second
            roll -= weight
        }
        return available[0].second
    }

    public fun standings(state: ProState, week: Int): List<ProStanding> {
        val games = (week * 144 / ProCatalog.WEEKS_PER_SEASON).coerceIn(0, 144)
        return deriveStandingsForPostseason(state.copy(week = week), games)
    }

    public fun teamStrengthEdgePermille(state: ProState, opponentTeamId: String? = null): Int {
        val opponentId = opponentTeamId ?: state.currentRival?.teamId ?: return 0
        val rows = standings(state, ProCatalog.WEEKS_PER_SEASON)
        val playerIndex = rows.indexOfFirst { it.teamId == state.team.id }
        val opponentIndex = rows.indexOfFirst { it.teamId == opponentId }
        if (playerIndex < 0 || opponentIndex < 0) return 0
        val player = rows[playerIndex]
        val opponent = rows[opponentIndex]
        val playerRate = player.wins * 1_000 / max(1, player.wins + player.losses)
        val opponentRate = opponent.wins * 1_000 / max(1, opponent.wins + opponent.losses)
        val rankEdge = opponentIndex - playerIndex
        return min(180, max(-180, playerRate - opponentRate + rankEdge * 20))
    }

    public fun qualificationNews(seed: Int): String = when (seed) {
        1 -> "정규시즌 1위입니다. 우승 결정전 한 판이 남았습니다."
        2 -> "정규시즌 2위입니다. 플레이오프 한 판부터 올라갑니다."
        3 -> "정규시즌 3위입니다. 준플레이오프 한 판부터 시작합니다."
        4 -> "정규시즌 4위입니다. 와일드카드에서 한 승이면 올라갑니다."
        5 -> "정규시즌 5위입니다. 와일드카드에서 두 번을 이겨야 합니다."
        else -> "플레이오프가 열립니다."
    }

    public fun unavailableNews(level: ProLevel): String =
        if (level == ProLevel.MINOR) "구단은 가을에 올랐지만 2군이라 마운드에 서지 못했습니다."
        else "구단은 가을에 올랐지만 부상으로 마운드에 서지 못했습니다."

    public fun eliminationNews(round: ProAutumnRound?): String = when (round) {
        ProAutumnRound.WILD_CARD -> "와일드카드에서 탈락했습니다."
        ProAutumnRound.SEMIFINAL -> "준플레이오프에서 탈락했습니다."
        ProAutumnRound.PLAYOFF -> "플레이오프에서 탈락했습니다."
        else -> "플레이오프에서 탈락했습니다."
    }

    public fun hofBonus(result: ProPostseasonResult): Int = when (result) {
        ProPostseasonResult.CHAMPION -> 4
        ProPostseasonResult.RUNNER_UP -> 2
        ProPostseasonResult.ELIMINATED -> 1
        ProPostseasonResult.IN_PROGRESS, ProPostseasonResult.DID_NOT_QUALIFY, ProPostseasonResult.UNAVAILABLE -> 0
    }

    public fun recognitionIds(postseason: ProPostseasonState): List<String> = when (postseason.result) {
        ProPostseasonResult.DID_NOT_QUALIFY, ProPostseasonResult.IN_PROGRESS, ProPostseasonResult.UNAVAILABLE -> emptyList()
        ProPostseasonResult.CHAMPION -> pathIds(postseason.seed, ProAutumnRound.FINAL) + "pro.autumn.champion"
        ProPostseasonResult.RUNNER_UP -> pathIds(postseason.seed, ProAutumnRound.FINAL)
        ProPostseasonResult.ELIMINATED -> pathIds(
            postseason.seed,
            postseason.currentRound ?: firstRound(postseason.seed),
        )
    }

    private fun pathIds(seed: Int, last: ProAutumnRound): List<String> {
        val order = listOf(
            ProAutumnRound.WILD_CARD,
            ProAutumnRound.SEMIFINAL,
            ProAutumnRound.PLAYOFF,
            ProAutumnRound.FINAL,
        )
        val start = firstRound(seed)
        val ids = mutableListOf("pro.autumn.qualified")
        for (round in order) {
            if (index(round) >= index(start) && index(round) <= index(last)) {
                ids += contentId(round)
            }
        }
        return ids
    }

    private fun index(round: ProAutumnRound): Int = when (round) {
        ProAutumnRound.WILD_CARD -> 0
        ProAutumnRound.SEMIFINAL -> 1
        ProAutumnRound.PLAYOFF -> 2
        ProAutumnRound.FINAL -> 3
    }

    private fun contentId(round: ProAutumnRound): String = when (round) {
        ProAutumnRound.WILD_CARD -> "pro.autumn.wild-card"
        ProAutumnRound.SEMIFINAL -> "pro.autumn.semifinal"
        ProAutumnRound.PLAYOFF -> "pro.autumn.playoff"
        ProAutumnRound.FINAL -> "pro.autumn.final"
    }
}

internal fun deriveStandingsForPostseason(state: ProState, gamesPlayed: Int): List<ProStanding> {
    if (gamesPlayed == 0) {
        return ProCatalog.teams.mapIndexed { index, team ->
            ProStanding(index + 1, team.id, team.name, 0, 0, 0, 0, team.id == state.team.id)
        }
    }
    val rng = com.solkim.baseball.core.SplitMix64(proHash("league|${state.careerId}|${state.season}") xor state.season.toULong())
    val rawStrengths = ProCatalog.teams.map { 380 + rng.nextInt(241) }
    val mean = rawStrengths.sum() / rawStrengths.size
    val strengths = rawStrengths.map { it - mean + 500 }
    val draws = ProCatalog.teams.map { (2 + rng.nextInt(4)) * gamesPlayed / 144 }.toMutableList()
    if ((gamesPlayed * draws.size - draws.sum()) % 2 != 0) draws[0] += 1
    val rows = ProCatalog.teams.mapIndexed { index, team ->
        val decided = gamesPlayed - draws[index]
        val wins = (decided * strengths[index] / 1000 + rng.nextInt(7) - 3).coerceIn(0, decided)
        ProStanding(0, team.id, team.name, wins, decided - wins, draws[index], 0, team.id == state.team.id)
    }.toMutableList()
    val playerLines = state.currentGameLines
    val playerIndex = rows.indexOfFirst { it.teamId == state.team.id }
    if (playerIndex >= 0 && playerLines.isNotEmpty()) {
        val generated = rows[playerIndex]
        val mine = playerLines.take(gamesPlayed)
        val wins = mine.count { it.teamRuns > it.opponentRuns }
        val losses = mine.count { it.teamRuns < it.opponentRuns }
        val draws = mine.size - wins - losses
        val remaining = max(0, gamesPlayed - mine.size)
        val scaledWins = generated.wins * remaining / max(1, gamesPlayed)
        val scaledDraws = min(remaining - min(remaining, scaledWins), generated.draws * remaining / max(1, gamesPlayed))
        rows[playerIndex] = generated.copy(
            wins = wins + scaledWins,
            losses = losses + max(0, remaining - scaledWins - scaledDraws),
            draws = draws + scaledDraws,
        )
    }
    var surplus = rows.sumOf { it.wins - it.losses }
    val order = rows.indices.filter { rows[it].teamId != state.team.id }.sortedWith(if (surplus > 0) compareByDescending { rows[it].wins } else compareBy { rows[it].wins })
    if (surplus % 2 != 0) for (index in order) {
        val r = rows[index]
        if (surplus > 0 && r.wins > 0) { rows[index] = r.copy(wins = r.wins - 1, draws = r.draws + 1); surplus--; break }
        if (surplus < 0 && r.losses > 0) { rows[index] = r.copy(losses = r.losses - 1, draws = r.draws + 1); surplus++; break }
    }
    var cursor = 0; var stalled = 0
    while (surplus != 0 && surplus % 2 == 0 && stalled < order.size) {
        val index = order[cursor++ % order.size]; val r = rows[index]
        if (surplus > 0 && r.wins > 0) { rows[index] = r.copy(wins = r.wins - 1, losses = r.losses + 1); surplus -= 2; stalled = 0 }
        else if (surplus < 0 && r.losses > 0) { rows[index] = r.copy(wins = r.wins + 1, losses = r.losses - 1); surplus += 2; stalled = 0 }
        else stalled++
    }
    val ranked = rows.sortedWith(compareByDescending<ProStanding> { it.wins.toDouble() / max(1, it.wins + it.losses) }.thenByDescending { it.wins })
    val leader = ranked.first()
    return ranked.mapIndexed { index, row -> row.copy(rank = index + 1, gamesBehindPermille = ((leader.wins - row.wins) + (row.losses - leader.losses)) * 500) }
}
