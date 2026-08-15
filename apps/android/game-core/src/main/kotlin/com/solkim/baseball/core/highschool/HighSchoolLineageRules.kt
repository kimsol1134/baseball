package com.solkim.baseball.core.highschool

import kotlin.math.max
import kotlin.math.min

/**
 * Pure port of the current Swift CareerLineageMasteryRules v1.
 *
 * Contributions are derived from archived selected IDs. They are not an independently mutable
 * counter, which keeps archive replay and save/restart deterministic. The loadout is frozen on
 * archive finalization and applied once when the next life starts.
 */
public object HighSchoolLineageRules {
    public const val RULES_VERSION: Int = 1

    private val families = listOf("power", "command", "breaking", "endurance", "gamecraft", "battery")

    public fun masteryRank(contributions: Int): Int = when {
        contributions >= 6 -> 3
        contributions >= 3 -> 2
        contributions >= 1 -> 1
        else -> 0
    }

    public fun nextThreshold(contributions: Int): Int? = when (masteryRank(contributions)) {
        0 -> 1
        1 -> 3
        2 -> 6
        else -> null
    }

    public fun masteries(selectedLegacyIds: List<String>): List<HighSchoolLineageMastery> {
        val known = selectedLegacyIds.map { HighSchoolSignatureLegacyRules.definition(it) }
        return families.map { family ->
            val contributions = known.count { it.family == family }
            HighSchoolLineageMastery(
                family = family,
                contributions = contributions,
                rank = masteryRank(contributions),
                nextThreshold = nextThreshold(contributions),
            )
        }
    }

    public fun loadout(
        legacyId: String,
        selectedLegacyIds: List<String>,
        sourceLifeNumber: Int?,
    ): HighSchoolLineageLoadout {
        val family = HighSchoolSignatureLegacyRules.definition(legacyId).family
        val mastery = masteries(selectedLegacyIds).first { it.family == family }
        return HighSchoolLineageLoadout(
            rulesVersion = RULES_VERSION,
            legacyId = legacyId,
            masteryRank = mastery.rank,
            contributions = mastery.contributions,
            sourceLifeNumber = sourceLifeNumber,
        )
    }

    public data class Applied(
        val pitcher: HighSchoolPitcher,
        val talent: HighSchoolTalent,
        val catcherTrust: Int,
    )

    public fun apply(
        loadout: HighSchoolLineageLoadout?,
        pitcher: HighSchoolPitcher,
        talent: HighSchoolTalent,
    ): Applied {
        if (loadout == null) return Applied(pitcher, talent, 50)
        require(loadout.rulesVersion == RULES_VERSION) { "lineage.rules_version" }
        require(loadout.masteryRank in 0..3 && loadout.contributions >= 0) { "lineage.loadout" }
        val family = HighSchoolSignatureLegacyRules.definition(loadout.legacyId).family
        var updatedTalent = talent
        if (loadout.masteryRank >= 2) {
            val focus = when (family) {
                "power" -> HighSchoolTrainingFocus.VELOCITY
                "command" -> HighSchoolTrainingFocus.COMMAND
                "breaking" -> HighSchoolTrainingFocus.BREAKING_BALL
                "endurance" -> HighSchoolTrainingFocus.STAMINA
                "gamecraft" -> if (pitcher.command <= pitcher.movement) {
                    HighSchoolTrainingFocus.COMMAND
                } else {
                    HighSchoolTrainingFocus.BREAKING_BALL
                }
                "battery" -> null
                else -> error("lineage.family")
            }
            if (focus != null) {
                val grade = updatedTalent.grade(focus)
                val pressure = min(grade.bloomThreshold - 1, updatedTalent.pressure(focus) + 2)
                updatedTalent = updatedTalent.withPressure(focus, max(0, pressure))
            }
        }

        val catcherTrust = if (family == "battery" && loadout.masteryRank >= 2) 55 else 50
        if (loadout.masteryRank < 3) return Applied(pitcher, updatedTalent, catcherTrust)

        fun cap(value: Int, focus: HighSchoolTrainingFocus): Int =
            min(updatedTalent.grade(focus).ceiling, value)

        val updatedPitcher = when (family) {
            "power", "endurance" -> pitcher.copy(
                stuff = cap(pitcher.stuff + 1, HighSchoolTrainingFocus.VELOCITY),
                stamina = cap(pitcher.stamina + 1, HighSchoolTrainingFocus.STAMINA),
            )
            "command", "breaking" -> pitcher.copy(
                command = cap(pitcher.command + 1, HighSchoolTrainingFocus.COMMAND),
                movement = cap(pitcher.movement + 1, HighSchoolTrainingFocus.BREAKING_BALL),
            )
            "gamecraft", "battery" -> pitcher.copy(
                command = cap(pitcher.command + 1, HighSchoolTrainingFocus.COMMAND),
                stamina = cap(pitcher.stamina + 1, HighSchoolTrainingFocus.STAMINA),
            )
            else -> error("lineage.family")
        }
        return Applied(updatedPitcher, updatedTalent, catcherTrust)
    }
}
