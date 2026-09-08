package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolLineageRules
import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel
import com.solkim.baseball.core.highschool.HighSchoolPhase4Command
import com.solkim.baseball.core.highschool.HighSchoolPhase4State
import com.solkim.baseball.core.pro.ProCareerPhase
import com.solkim.baseball.core.pro.ProKernel
import com.solkim.baseball.core.pro.ProStartMode
import com.solkim.baseball.core.pro.ProState

/** Retired careers are read-only records. Preserve stats/story; omit obsolete command receipts. */
public object ProRetirementLedger {
    public fun isHighSchoolStart(command: HighSchoolPhase4Command): Boolean =
        command is HighSchoolPhase4Command.Start || command is HighSchoolPhase4Command.StartConfigured

    public fun prepareInitialCommand(state: GameAggregateState, command: HighSchoolPhase4Command): HighSchoolPhase4Command {
        val balance = state.meta.standaloneSoulBalance
        if (balance == 0 || !isHighSchoolStart(command)) return command
        val request = when (command) {
            is HighSchoolPhase4Command.Start -> command.request
            is HighSchoolPhase4Command.StartConfigured -> command.request
            else -> error("unreachable")
        }
        require(request.soulBoosts.distinct().size == request.soulBoosts.size) { "setup.boost_duplicate" }
        val cost = request.soulBoosts.sumOf { it.cost }
        require(cost <= balance) { "setup.insufficient_soul" }
        val funded = request.copy(inheritedSoulPoints = balance - cost, inheritedSoulTotal = 0)
        return when (command) {
            is HighSchoolPhase4Command.Start -> command.copy(request = funded)
            is HighSchoolPhase4Command.StartConfigured -> command.copy(request = funded)
            else -> error("unreachable")
        }
    }

    public fun attachInitialWallet(state: HighSchoolPhase4State, lifetimeBalance: Int): HighSchoolPhase4State =
        if (lifetimeBalance == 0) state else HighSchoolPhase4Kernel().commitShadowState(state.copy(
            inheritance = state.inheritance.copy(soulTotalEarned = lifetimeBalance, automaticSoulEarned = 0),
        ))

    public fun soulBonus(pro: ProState): Int {
        val stats = pro.careerStats
        val achievement = maxOf(stats.sumOf { it.strikeouts.toLong() }, stats.sumOf { it.inningsOuts.toLong() } / 3,
            stats.sumOf { it.wins.toLong() + it.saves.toLong() } * 4)
        return (20L + stats.size * 3L + achievement / 25 + pro.awards.size * 8L + (pro.hallOfFameScore ?: 0) / 2)
            .coerceIn(0, Int.MAX_VALUE.toLong()).toInt()
    }

    public fun settle(state: GameAggregateState): GameAggregateState {
        val pro = state.pro?.takeIf { it.phase == ProCareerPhase.COMPLETED } ?: return state
        if (state.meta.retiredProCareers.any { it.careerId == pro.careerId }) return state
        val unsigned = pro.copy(commandReceipts = emptyList(), commitment = "")
        val archived = unsigned.copy(commitment = ProKernel().commitment(unsigned))
        val bonus = soulBonus(pro)
        val highSchool = state.highSchool
        var meta = state.meta.copy(retiredProCareers = state.meta.retiredProCareers + archived)
        val nextHighSchool = if (highSchool == null) {
            meta = meta.copy(standaloneSoulBalance = Math.addExact(meta.standaloneSoulBalance, bonus))
            null
        } else {
            val inherited = highSchool.inheritance
            var next = inherited.copy(soulPoints = Math.addExact(inherited.soulPoints, bonus),
                soulTotalEarned = Math.addExact(inherited.soulTotalEarned, bonus))
            // Standalone Pro rewards the wallet and never fabricates a high-school story.
            val linked = pro.startMode == ProStartMode.LINKED && pro.sourceHighSchoolCareerId == highSchool.run.careerId
            val legacy = pro.selectedLegacyId?.takeIf { linked }
            if (legacy != null) {
                val discoveries = highSchool.archive.mapNotNull { if (it.careerId == highSchool.run.careerId) legacy else it.selectedSignatureLegacyId } +
                    listOfNotNull(legacy.takeIf { highSchool.archive.none { it.careerId == highSchool.run.careerId } })
                next = next.copy(selectedSignatureLegacyId = legacy,
                    unlockedSignatureLegacyIds = (inherited.unlockedSignatureLegacyIds + legacy).distinct(),
                    lineageMasteries = HighSchoolLineageRules.masteries(discoveries),
                    lineageLoadout = HighSchoolLineageRules.loadout(legacy, discoveries, highSchool.run.lifeNumber))
            }
            HighSchoolPhase4Kernel().commitShadowState(highSchool.copy(inheritance = next,
                selectedSignatureLegacyId = legacy ?: highSchool.selectedSignatureLegacyId))
        }
        return state.copy(meta = meta, highSchool = nextHighSchool,
            stage = if (nextHighSchool != null && nextHighSchool.run.phase != HighSchoolPhase.COMPLETED) GameStage.HIGH_SCHOOL else GameStage.BETWEEN_LIVES)
    }
}
