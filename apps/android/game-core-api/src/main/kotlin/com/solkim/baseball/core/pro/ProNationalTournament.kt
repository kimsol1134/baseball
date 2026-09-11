package com.solkim.baseball.core.pro


public enum class ProNationalTournamentStage(public val wire: String) {
    GROUP("group"),
    AWAITING_FINAL("awaiting_final"),
    RESULT("result"),
}

public enum class ProNationalTournamentResult(public val wire: String) {
    GOLD("gold"),
    SILVER("silver"),
    BRONZE("bronze"),
    GROUP_EXIT("group_exit"),
}

public enum class ProNationalOpponentGrade(public val wire: String) {
    A("a"),
    B("b"),
    C("c"),
    D("d"),
}

public data class ProNationalOpponent(
    val id: String,
    val grade: ProNationalOpponentGrade,
    val batterOffset: Int,
)

public data class ProNationalTournamentGameLine(
    val opponentId: String,
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
) {
    public val won: Boolean get() = teamRuns > opponentRuns
}

public data class ProNationalTournamentState(
    val seed: ULong,
    val resumeSeed: String,
    val startingFatigue: Int,
    val groupGames: List<ProNationalTournamentGameLine>,
    val stage: ProNationalTournamentStage,
    val finalOpponentId: String,
    val finalLine: ProNationalTournamentGameLine? = null,
    val result: ProNationalTournamentResult? = null,
    val fatigueCarry: Int,
    val injuryWeeks: Int,
    val fanDelta: Int = 0,
    val exempted: Boolean = false,
) {
    public val groupWins: Int get() = groupGames.count { it.won }
}

public data class ProNationalTeamRecord(
    val season: Int,
    val result: ProNationalTournamentResult,
    val directGameLine: ProNationalTournamentGameLine? = null,
)

public data class ProNationalTeamCarryState(
    val season: Int,
    val fatigue: Int,
    val injuryWeeks: Int,
)

