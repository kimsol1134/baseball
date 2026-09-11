package com.solkim.baseball.core.pro

import com.solkim.baseball.core.StableHash

public object ProNationalTeamRules {
    public const val CALL_INTERVAL: Int = 2
    public const val MINIMUM_SEASON: Int = 2
    public const val MAXIMUM_AGE: Int = 31
    public const val MARKET_SCORE_THRESHOLD: Int = 55
    public const val FAN_SUPPORT_THRESHOLD: Int = 60
    public const val WINS_TO_FINAL: Int = 2
    public const val FATIGUE_CARRY: Int = 15
    public const val FATIGUE_CARRY_HEAVY: Int = 25
    public const val HEAVY_PITCH_THRESHOLD: Int = 80
    public const val GOLD_FAN_DELTA: Int = 8
    public const val GOLD_FAN_DELTA_ALREADY_COMPLETED: Int = 10
    public const val SILVER_FAN_DELTA: Int = 4
    public const val BRONZE_FAN_DELTA: Int = 2
    public const val DECLINE_FAN_DELTA: Int = -2
    public const val HOF_GOLD_BONUS: Int = 4
    public const val GROUP_OUTS_TARGET: Int = 18
    public const val GROUP_PITCH_CAP: Int = 96
    public const val INJURY_RECOVERY_MIN: Int = 2
    public const val INJURY_RECOVERY_SPAN: Int = 3
    public const val FINAL_BATTER_OFFSET: Int = 6

    public val opponents: List<ProNationalOpponent> = listOf(
        ProNationalOpponent("east-coast", ProNationalOpponentGrade.A, FINAL_BATTER_OFFSET),
        ProNationalOpponent("southwest-isles", ProNationalOpponentGrade.B, 5),
        ProNationalOpponent("northern-plains", ProNationalOpponentGrade.C, 4),
        ProNationalOpponent("south-harbor", ProNationalOpponentGrade.D, 2),
    )

    public fun opponent(id: String): ProNationalOpponent? = opponents.firstOrNull { it.id == id }

    public fun derivedSeed(nextSeed: String): ULong = StableHash.fnv1a64Value("national-tournament:$nextSeed")

    public fun derivedFinalSeed(nextSeed: String): ULong = StableHash.fnv1a64Value("national-final:$nextSeed")

    public fun groupOpponents(): List<ProNationalOpponent> = opponents.filter { it.grade != ProNationalOpponentGrade.A }

    public fun finalOpponent(): ProNationalOpponent = opponents.first { it.grade == ProNationalOpponentGrade.A }

    public fun goldCount(history: List<ProNationalTeamRecord>?): Int = history.orEmpty().count { it.result == ProNationalTournamentResult.GOLD }

    public fun fanDelta(result: ProNationalTournamentResult, militaryCompleted: Boolean): Int = when (result) {
        ProNationalTournamentResult.GOLD -> if (militaryCompleted) GOLD_FAN_DELTA_ALREADY_COMPLETED else GOLD_FAN_DELTA
        ProNationalTournamentResult.SILVER -> SILVER_FAN_DELTA
        ProNationalTournamentResult.BRONZE -> BRONZE_FAN_DELTA
        ProNationalTournamentResult.GROUP_EXIT -> 0
    }

    public fun fatigueCarry(pitches: Int?): Int =
        if ((pitches ?: 0) >= HEAVY_PITCH_THRESHOLD) FATIGUE_CARRY_HEAVY else FATIGUE_CARRY

    public fun opponentLabel(id: String): String = when (id) {
        "east-coast" -> "동해안 연합"
        "southwest-isles" -> "남서제도"
        "northern-plains" -> "북부평원"
        "south-harbor" -> "남항구"
        else -> id
    }

    public fun resultLabel(result: ProNationalTournamentResult): String = when (result) {
        ProNationalTournamentResult.GOLD -> "금메달"
        ProNationalTournamentResult.SILVER -> "은메달"
        ProNationalTournamentResult.BRONZE -> "동메달"
        ProNationalTournamentResult.GROUP_EXIT -> "조별 탈락"
    }

    public fun news(result: ProNationalTournamentResult): String = when (result) {
        ProNationalTournamentResult.GOLD -> "대표팀 금메달. 이번 겨울의 얼굴이 됐다."
        ProNationalTournamentResult.SILVER -> "대표팀 은메달. 결승까지 올라 이름을 남겼다."
        ProNationalTournamentResult.BRONZE -> "대표팀 동메달. 메달은 걸고 돌아온다."
        ProNationalTournamentResult.GROUP_EXIT -> "대표팀 조별 리그에서 멈췄다."
    }
}
