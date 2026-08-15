package com.solkim.baseball.core.highschool

/**
 * Current Swift signature-legacy rules copied as data and kept outside the base v1 memory-card
 * path.  The ids, families, effects, and candidate score terms are wire-visible migration data;
 * changing them requires a new rules version and a new oracle fixture.
 */
public object HighSchoolSignatureLegacyRules {
    public const val RULES_VERSION: Int = 1

    public data class Definition(
        val id: String,
        val family: String,
        val title: String,
        val stuff: Int,
        val command: Int,
        val movement: Int,
        val stamina: Int,
    )

    public data class Candidate(
        val definition: Definition,
        val score: Int,
        val matchedAwakeningCount: Int,
    )

    public val definitions: List<Definition> = listOf(
        Definition("power_imprint", "power", "마운드에 남은 불꽃", stuff = 3, command = 0, movement = 0, stamina = 1),
        Definition("command_map", "command", "미트 끝의 지도", stuff = 0, command = 3, movement = 1, stamina = 0),
        Definition("breaking_trace", "breaking", "손끝에 남은 궤적", stuff = 0, command = 1, movement = 3, stamina = 0),
        Definition("endurance_rhythm", "endurance", "긴 이닝의 호흡", stuff = 1, command = 0, movement = 0, stamina = 3),
        Definition("gamecraft_ledger", "gamecraft", "이닝을 읽는 장부", stuff = 0, command = 2, movement = 1, stamina = 1),
        Definition("battery_promise", "battery", "사인 사이의 약속", stuff = 0, command = 2, movement = 0, stamina = 2),
    )

    public fun definition(id: String): Definition = definitions.firstOrNull { it.id == id }
        ?: throw IllegalArgumentException("signatureLegacy.unknown:$id")

    public fun apply(id: String, pitcher: HighSchoolPitcher): HighSchoolPitcher {
        val effect = definition(id)
        return pitcher.copy(
            stuff = (pitcher.stuff + effect.stuff).coerceIn(20, 80),
            command = (pitcher.command + effect.command).coerceIn(20, 80),
            movement = (pitcher.movement + effect.movement).coerceIn(20, 80),
            stamina = (pitcher.stamina + effect.stamina).coerceIn(20, 80),
        )
    }

    public fun candidates(
        starting: HighSchoolPitcher,
        state: HighSchoolState,
        requested: Int = 3,
    ): List<Candidate> {
        val growth = intArrayOf(
            (state.pitcher.stuff - starting.stuff).coerceAtLeast(0),
            (state.pitcher.command - starting.command).coerceAtLeast(0),
            (state.pitcher.movement - starting.movement).coerceAtLeast(0),
            (state.pitcher.stamina - starting.stamina).coerceAtLeast(0),
        )
        val performance = state.performance
        val games = performance.importantGamesCompleted
        val coach = state.managerTrust
        val catcher = state.catcherTrust
        val rival = state.rivalTrust
        return definitions.map { definition ->
            val matched = matched(definition.family, state.selectedAwakenings).size
            val score = when (definition.family) {
                "power" -> growth[0] * 120 + performance.strikeouts * 12 + matched * 80 + rival
                "command" -> growth[1] * 120 + (games * 3 - performance.walks).coerceAtLeast(0) * 18 + matched * 80 + coach
                "breaking" -> growth[2] * 120 + performance.strikeouts * 9 + matched * 80 + catcher
                "endurance" -> growth[3] * 120 + performance.pitches / 2 + matched * 80 + coach
                "gamecraft" -> (growth[1] + growth[2]) * 60 +
                    (performance.expectedDamage - performance.actualDamage).coerceAtLeast(0) / 20 + matched * 80 +
                    maxOf(coach, catcher, rival)
                else -> growth[1] * 60 + (games * 3 - performance.walks).coerceAtLeast(0) * 12 + matched * 100 + catcher * 2
            }
            Candidate(definition, score, matched)
        }.sortedWith(compareByDescending<Candidate> { it.score }.thenBy { it.definition.id })
            .take(requested.coerceIn(1, definitions.size))
    }

    public fun matched(family: String, awakenings: List<HighSchoolAwakening>): List<HighSchoolAwakening> {
        val ids = when (family) {
            "power" -> setOf(HighSchoolAwakening.EXPLOSIVE_FASTBALL, HighSchoolAwakening.RISING_FOUR_SEAM)
            "command" -> setOf(
                HighSchoolAwakening.PINPOINT_EDGE, HighSchoolAwakening.REPEATABLE_RELEASE,
                HighSchoolAwakening.FIRST_PITCH_STRIKE, HighSchoolAwakening.SCOUT_COMPOSURE,
            )
            "breaking" -> setOf(
                HighSchoolAwakening.DISAPPEARING_BREAKER, HighSchoolAwakening.SINKER_TUNNEL,
                HighSchoolAwakening.FROZEN_CHANGEUP, HighSchoolAwakening.SWEEPING_SLIDER,
                HighSchoolAwakening.CURVEBALL_CLOCK,
            )
            "endurance" -> setOf(HighSchoolAwakening.IRON_ARM, HighSchoolAwakening.LATE_INNING_RESERVE)
            "gamecraft" -> setOf(
                HighSchoolAwakening.CALM_UNDER_PRESSURE, HighSchoolAwakening.PICKOFF_RHYTHM,
                HighSchoolAwakening.TWO_STRIKE_PLAN, HighSchoolAwakening.TRAFFIC_CONTROLLER,
                HighSchoolAwakening.SCOUT_COMPOSURE,
            )
            else -> setOf(
                HighSchoolAwakening.BATTERY_SYNC, HighSchoolAwakening.PICKOFF_RHYTHM,
                HighSchoolAwakening.TRAFFIC_CONTROLLER,
            )
        }
        return awakenings.filter { it in ids }
    }
}
