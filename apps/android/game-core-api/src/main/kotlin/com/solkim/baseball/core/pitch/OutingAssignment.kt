package com.solkim.baseball.core.pitch

public enum class OutingRole { STARTER, RELIEF, CLOSER }
public enum class OutingGoal { CLEAN_FRAME, HOLD_LEAD, STARTER_TEST }
public enum class OutingGoalStatus { PENDING, ACHIEVED, FAILED, UNFINISHED }

/** Frozen at reservation; goal completion cannot be undone by pitching an extra inning. */
public data class OutingAssignment(
    val role: OutingRole,
    val goal: OutingGoal,
    val targetOuts: Int,
    val maxRuns: Int,
    val entryInning: Int,
    val entryOuts: Int,
    val entryLead: Int,
    val inheritedRunners: Int,
    val status: OutingGoalStatus = OutingGoalStatus.PENDING,
    val trustReward: Int = 0,
) {
    init { require(targetOuts in 1..27 && maxRuns in 0..20 && entryInning in 1..20 && entryOuts in 0..2 && inheritedRunners in 0..3 && trustReward in 0..8) }
    public fun advance(outs: Int, runs: Int): OutingAssignment = if (status != OutingGoalStatus.PENDING) this else copy(status = when {
        runs > maxRuns -> OutingGoalStatus.FAILED
        outs >= targetOuts -> OutingGoalStatus.ACHIEVED
        else -> OutingGoalStatus.PENDING
    })
    public fun finish(): OutingAssignment = if (status == OutingGoalStatus.PENDING) copy(status = OutingGoalStatus.UNFINISHED) else this
    public fun withTrustReward(currentTrust: Int): OutingAssignment {
        require(status == OutingGoalStatus.ACHIEVED)
        return copy(trustReward = minOf(if (goal == OutingGoal.STARTER_TEST) 8 else 2, (100 - currentTrust).coerceAtLeast(0)))
    }
    public fun token(): String = listOf("1", role.name, goal.name, targetOuts, maxRuns, entryInning, entryOuts, entryLead, inheritedRunners, status.name).joinToString("|") + if (trustReward == 0) "" else "|$trustReward"
    public companion object {
        public fun decode(value: String): OutingAssignment {
            val p = value.split('|'); require(p.size in 10..11 && p[0] == "1")
            return OutingAssignment(OutingRole.valueOf(p[1]), OutingGoal.valueOf(p[2]), p[3].toInt(), p[4].toInt(),
                p[5].toInt(), p[6].toInt(), p[7].toInt(), p[8].toInt(), OutingGoalStatus.valueOf(p[9]), if (p.size == 11) p[10].toInt() else 0)
        }
    }
}
