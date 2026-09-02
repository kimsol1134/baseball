package com.solkim.baseball.core.pro

import com.solkim.baseball.core.StableHash

/** 한 주의 시즌 온도. 저장하지 않고 `careerID|season|week` 해시로 다시 만든다. */
public enum class ProSeasonClimate(public val wire: String) {
    HOT("hot"),
    EVEN("even"),
    SLUMP("slump"),
    ADAPTED("adapted"),
}

/**
 * 자동 등판이 포수 추천을 얼마나 따를지.
 * 기본값 PERFECT는 고교·밸런스 CLI·구 프로 저장본의 기존 결과를 그대로 둔다.
 */
public enum class AutoCallPolicy(public val wire: String) {
    PERFECT("perfect"),
    MIXED("mixed"),
    SLUMP("slump"),
}

/** 시즌 안 파도. 난이도 숫자만 바꾸지 않고, 같은 주차를 다시 계산해도 같은 온도가 나오게 한다. */
public object ProSeasonClimateRules {
    public fun offset(climate: ProSeasonClimate): Int = when (climate) {
        ProSeasonClimate.HOT -> -2
        ProSeasonClimate.EVEN -> 0
        ProSeasonClimate.SLUMP -> 3
        ProSeasonClimate.ADAPTED -> 2
    }

    public fun callPolicy(climate: ProSeasonClimate): AutoCallPolicy = when (climate) {
        ProSeasonClimate.HOT, ProSeasonClimate.EVEN, ProSeasonClimate.ADAPTED -> AutoCallPolicy.MIXED
        ProSeasonClimate.SLUMP -> AutoCallPolicy.SLUMP
    }

    public fun newsLine(climate: ProSeasonClimate, week: Int): String = when (climate) {
        ProSeasonClimate.HOT -> "${week}주차 · 상대 타선이 흔들린다. 오늘 공은 잘 먹힐 공기가 있다."
        ProSeasonClimate.EVEN -> "${week}주차 · 리그는 평이하다. 리듬을 지키는 주다."
        ProSeasonClimate.SLUMP -> "${week}주차 · 타선이 직구를 기다리기 시작했다. 한동안 쉽지 않다."
        ProSeasonClimate.ADAPTED -> "${week}주차 · 상대 벤치가 내 구종 순서를 읽고 있다."
    }

    /** 슬럼프는 시즌당 한 블록(2~4주)으로 묶는다. 주마다 주사위를 던지면 파도가 아니라 노이즈다. */
    public fun climate(
        careerId: String,
        season: Int,
        week: Int,
        strikeouts: Int = 0,
        inningsOuts: Int = 0,
        stabilizeCharges: Int = 0,
    ): ProSeasonClimate {
        if (week < 1) return ProSeasonClimate.EVEN
        if (stabilizeCharges > 0) return ProSeasonClimate.EVEN

        val slump = slumpBlock(careerId, season)
        if (week in slump) return ProSeasonClimate.SLUMP

        if (week >= 14) {
            val k9 = strikeouts * 27_000 / maxOf(1, inningsOuts)
            if (k9 >= 9_000) {
                val adaptedRoll = hashInt("$careerId|season$season|week$week|adapted") % 100UL
                if (adaptedRoll < 40UL) return ProSeasonClimate.ADAPTED
            }
        }

        val hotRoll = hashInt("$careerId|season$season|week$week|hot") % 100UL
        if (hotRoll < 15UL) return ProSeasonClimate.HOT
        return ProSeasonClimate.EVEN
    }

    public fun slumpBlock(careerId: String, season: Int): IntRange {
        val startBase = hashInt("$careerId|season$season|slump-start")
        val lengthBase = hashInt("$careerId|season$season|slump-length")
        val start = 7 + (startBase % 10UL).toInt()
        val length = 2 + (lengthBase % 3UL).toInt()
        val end = minOf(20, start + length - 1)
        return start..end
    }

    private fun hashInt(value: String): ULong = StableHash.fnv1a64Value(value)
}
