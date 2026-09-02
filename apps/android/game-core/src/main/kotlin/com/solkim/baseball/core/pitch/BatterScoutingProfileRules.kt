package com.solkim.baseball.core.pitch

import com.solkim.baseball.core.StableHash
import kotlin.math.max

public data class BatterScoutingProfile(
    val pitchWeakness: PitchKind,
    val pitchStrength: PitchKind,
    val hotZone: PitchZone,
    val coldZone: PitchZone,
    val reliability: Int,
)

public enum class BatterScoutingArchetype {
    SLUGGER,
    HOME_RUN,
    POWER,
    CONTACT,
    SPRAY,
    PATIENT,
    GAP,
    SPEED,
    CLUTCH,
}

public object BatterScoutingProfileRules {
    public val allZones: List<PitchZone> = (0 until 3).flatMap { row ->
        (0 until 3).map { PitchZone(row, it) }
    }

    public fun archetype(text: String): BatterScoutingArchetype {
        val pairs = listOf(
            BatterScoutingArchetype.SLUGGER to listOf("거포"),
            BatterScoutingArchetype.HOME_RUN to listOf("홈런"),
            BatterScoutingArchetype.POWER to listOf("파워"),
            BatterScoutingArchetype.CONTACT to listOf("컨택", "무결점"),
            BatterScoutingArchetype.SPRAY to listOf("교타", "정확"),
            BatterScoutingArchetype.PATIENT to listOf("선구안", "출루"),
            BatterScoutingArchetype.GAP to listOf("갭"),
            BatterScoutingArchetype.SPEED to listOf("빠른 발", "빠른발", "도루"),
            BatterScoutingArchetype.CLUTCH to listOf("득점권", "해결사", "중심"),
        )
        for ((archetype, keywords) in pairs) {
            if (keywords.any { text.contains(it) }) return archetype
        }
        return BatterScoutingArchetype.CLUTCH
    }

    public fun profile(archetype: BatterScoutingArchetype, seedToken: String): BatterScoutingProfile {
        val weakness = pick(weaknessCandidates(archetype), "$seedToken|weakness")
        val strength = pick(strengthCandidates(archetype, weakness), "$seedToken|strength")
        val hot = pick(hotZoneCandidates(archetype).map { it to 1 }, "$seedToken|hot")
        var cold = pick(
            coldZoneCandidates(archetype).filter { it != hot }.map { it to 1 },
            "$seedToken|cold",
        )
        if (cold == hot) {
            cold = allZones.firstOrNull { it != hot } ?: PitchZone(2, 0)
        }
        val reliability = 42 + (StableHash.fnv1a64Value("$seedToken|reliability") % 17UL).toInt()
        return BatterScoutingProfile(weakness, strength, hot, cold, reliability)
    }

    private fun weaknessCandidates(archetype: BatterScoutingArchetype): List<Pair<PitchKind, Int>> = when (archetype) {
        BatterScoutingArchetype.SLUGGER -> listOf(PitchKind.CHANGEUP to 50, PitchKind.CURVEBALL to 35, PitchKind.SLIDER to 15)
        BatterScoutingArchetype.HOME_RUN -> listOf(PitchKind.CHANGEUP to 45, PitchKind.CURVEBALL to 40, PitchKind.SLIDER to 15)
        BatterScoutingArchetype.POWER -> listOf(PitchKind.CHANGEUP to 40, PitchKind.CURVEBALL to 35, PitchKind.SLIDER to 25)
        BatterScoutingArchetype.CONTACT -> listOf(PitchKind.FOUR_SEAM to 55, PitchKind.SLIDER to 45)
        BatterScoutingArchetype.SPRAY -> listOf(PitchKind.FOUR_SEAM to 50, PitchKind.SLIDER to 35, PitchKind.CHANGEUP to 15)
        BatterScoutingArchetype.PATIENT -> listOf(PitchKind.CURVEBALL to 50, PitchKind.CHANGEUP to 50)
        BatterScoutingArchetype.GAP -> listOf(PitchKind.SLIDER to 40, PitchKind.CHANGEUP to 35, PitchKind.FOUR_SEAM to 25)
        BatterScoutingArchetype.SPEED -> listOf(PitchKind.CURVEBALL to 40, PitchKind.CHANGEUP to 35, PitchKind.FOUR_SEAM to 25)
        BatterScoutingArchetype.CLUTCH -> listOf(PitchKind.SLIDER to 35, PitchKind.CURVEBALL to 35, PitchKind.CHANGEUP to 30)
    }

    private fun strengthCandidates(archetype: BatterScoutingArchetype, excluding: PitchKind): List<Pair<PitchKind, Int>> {
        val raw = when (archetype) {
            BatterScoutingArchetype.SLUGGER, BatterScoutingArchetype.HOME_RUN, BatterScoutingArchetype.POWER ->
                listOf(PitchKind.FOUR_SEAM to 55, PitchKind.SLIDER to 30, PitchKind.CURVEBALL to 15)
            BatterScoutingArchetype.CONTACT, BatterScoutingArchetype.SPRAY ->
                listOf(PitchKind.SLIDER to 20, PitchKind.CHANGEUP to 35, PitchKind.CURVEBALL to 25, PitchKind.FOUR_SEAM to 20)
            BatterScoutingArchetype.PATIENT ->
                listOf(PitchKind.FOUR_SEAM to 50, PitchKind.SLIDER to 35, PitchKind.CURVEBALL to 15)
            BatterScoutingArchetype.GAP ->
                listOf(PitchKind.FOUR_SEAM to 40, PitchKind.CURVEBALL to 30, PitchKind.SLIDER to 20, PitchKind.CHANGEUP to 10)
            BatterScoutingArchetype.SPEED ->
                listOf(PitchKind.FOUR_SEAM to 45, PitchKind.SLIDER to 35, PitchKind.CHANGEUP to 20)
            BatterScoutingArchetype.CLUTCH ->
                listOf(PitchKind.FOUR_SEAM to 45, PitchKind.SLIDER to 25, PitchKind.CHANGEUP to 20, PitchKind.CURVEBALL to 10)
        }
        val filtered = raw.filter { it.first != excluding }
        return if (filtered.isEmpty()) {
            listOf(PitchKind.FOUR_SEAM to 1).filter { it.first != excluding } + (PitchKind.SLIDER to 1)
        } else filtered
    }

    private fun hotZoneCandidates(archetype: BatterScoutingArchetype): List<PitchZone> = when (archetype) {
        BatterScoutingArchetype.SLUGGER, BatterScoutingArchetype.HOME_RUN, BatterScoutingArchetype.POWER ->
            zones(listOf(0 to 0, 0 to 1, 1 to 0, 1 to 1))
        BatterScoutingArchetype.CONTACT, BatterScoutingArchetype.SPRAY ->
            zones(listOf(1 to 2, 1 to 1, 2 to 2, 1 to 0))
        BatterScoutingArchetype.PATIENT -> zones(listOf(1 to 1, 0 to 1, 1 to 0))
        BatterScoutingArchetype.GAP -> zones(listOf(1 to 2, 2 to 2, 1 to 0, 0 to 2))
        BatterScoutingArchetype.SPEED -> zones(listOf(1 to 2, 2 to 2, 1 to 1))
        BatterScoutingArchetype.CLUTCH -> zones(listOf(1 to 1, 1 to 0, 0 to 1, 1 to 2))
    }

    private fun coldZoneCandidates(archetype: BatterScoutingArchetype): List<PitchZone> = when (archetype) {
        BatterScoutingArchetype.SLUGGER, BatterScoutingArchetype.HOME_RUN, BatterScoutingArchetype.POWER ->
            zones(listOf(2 to 2, 2 to 1, 0 to 2, 2 to 0))
        BatterScoutingArchetype.CONTACT, BatterScoutingArchetype.SPRAY ->
            zones(listOf(0 to 0, 0 to 1, 2 to 0))
        BatterScoutingArchetype.PATIENT -> zones(listOf(2 to 2, 0 to 2, 2 to 0, 2 to 1))
        BatterScoutingArchetype.GAP -> zones(listOf(1 to 1, 0 to 0, 2 to 1))
        BatterScoutingArchetype.SPEED -> zones(listOf(0 to 0, 0 to 1, 2 to 0, 0 to 2))
        BatterScoutingArchetype.CLUTCH -> zones(listOf(2 to 2, 2 to 0, 0 to 2))
    }

    private fun zones(pairs: List<Pair<Int, Int>>): List<PitchZone> = pairs.map { PitchZone(it.first, it.second) }

    private fun <T> pick(items: List<Pair<T, Int>>, token: String): T {
        val total = items.sumOf { max(0, it.second) }
        require(items.isNotEmpty() && total > 0) { "scouting pick requires a weighted candidate" }
        var slot = (StableHash.fnv1a64Value(token) % total.toULong()).toInt()
        for ((item, weight) in items) {
            slot -= max(0, weight)
            if (slot < 0) return item
        }
        return items[0].first
    }
}
