package com.solkim.baseball.core.pro

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
