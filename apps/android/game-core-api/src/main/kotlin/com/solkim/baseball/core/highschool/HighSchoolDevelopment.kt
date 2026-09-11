package com.solkim.baseball.core.highschool

/** Additive career progress. A null field preserves every legacy snapshot and commitment. */
public data class HighSchoolDevelopment(
    val experience: List<Int> = listOf(0, 0, 0, 0),
    val lastExperienceEarned: Int = 0,
    val supportFocus: HighSchoolTrainingFocus? = null,
    val starterTrialPending: Boolean = false,
    val lastConversation: Int = 0,
    val lastOffer: String = "none",
    val supportAppliedTraining: Int = 0,
    val trialOutcome: String = "none",
    val supportQueue: List<HighSchoolTrainingFocus> = emptyList(),
) {
    init {
        require(experience.size == 4 && experience.all { it in 0..99 })
        require(lastExperienceEarned in 0..10000 && lastConversation >= 0 && supportAppliedTraining >= 0)
        require(lastOffer in setOf("none", "training", "recovery", "starter_trial"))
        require(trialOutcome in setOf("none", "achieved", "unfinished"))
        require(supportQueue.size <= 5 && supportQueue.distinct().size == supportQueue.size && HighSchoolTrainingFocus.RECOVERY !in supportQueue)
    }
    public fun hasSupport(focus: HighSchoolTrainingFocus): Boolean = supportFocus == focus || focus in supportQueue
    public fun supported(focus: HighSchoolTrainingFocus): HighSchoolDevelopment = copy(supportFocus = focus,
        supportQueue = (supportQueue + listOfNotNull(supportFocus) + focus).distinct().sortedBy { it.ordinal })
    public fun consume(focus: HighSchoolTrainingFocus, training: Int): HighSchoolDevelopment {
        if (!hasSupport(focus)) return this
        val remaining = (supportQueue + listOfNotNull(supportFocus)).distinct().filter { it != focus }
        return copy(supportFocus = remaining.firstOrNull(), supportQueue = remaining, supportAppliedTraining = training)
    }
    public fun token(): String = listOf("1", experience.joinToString(","), lastExperienceEarned,
        supportFocus?.wire ?: "-", if (starterTrialPending) 1 else 0, lastConversation, lastOffer,
        supportAppliedTraining, trialOutcome).joinToString("|") + if (supportQueue.isEmpty()) "" else "|" + supportQueue.joinToString(",") { it.wire }
    public companion object {
        public fun decode(token: String): HighSchoolDevelopment {
            val p = token.split('|'); require(p.size in 9..10 && p[0] == "1" && p[4] in setOf("0", "1"))
            return HighSchoolDevelopment(p[1].split(',').map(String::toInt), p[2].toInt(),
                if (p[3] == "-") null else HighSchoolTrainingFocus.entries.single { it.wire == p[3] },
                p[4] == "1", p[5].toInt(), p[6], p[7].toInt(), p[8],
                if (p.size == 10) p[9].split(',').map { wire -> HighSchoolTrainingFocus.entries.single { it.wire == wire } } else emptyList())
        }
        public fun index(focus: HighSchoolTrainingFocus): Int = when (focus) {
            HighSchoolTrainingFocus.VELOCITY -> 0
            HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingFocus.GAME_PLANNING -> 1
            HighSchoolTrainingFocus.BREAKING_BALL -> 2
            else -> 3
        }
    }
}
