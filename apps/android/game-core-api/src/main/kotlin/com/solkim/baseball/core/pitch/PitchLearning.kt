package com.solkim.baseball.core.pitch

import java.util.Base64

/** Swift PitchLearningRules v1. Absent on legacy careers: never locks an existing weapon. */
public data class PitchLearningProject(
    val pitchType: PitchKind,
    val practiceCredits: Int = 0,
    val qualityUses: Int = 0,
    val awardedAppearances: List<String> = emptyList(),
) {
    init {
        require(pitchType != PitchKind.FOUR_SEAM && practiceCredits in 0..9 && qualityUses in 0..2)
        require(awardedAppearances.size <= 2 && awardedAppearances.distinct().size == awardedAppearances.size)
    }
    public val gameReady: Boolean get() = practiceCredits >= 5
    public val completed: Boolean get() = practiceCredits >= 9 || practiceCredits >= 7 && qualityUses >= 2
    public val stage: String get() = when { completed -> "completed"; gameReady -> "live_trial"; practiceCredits >= 2 -> "bullpen"; else -> "grip" }
    public fun practice(credits: Int): PitchLearningProject = copy(practiceCredits = (practiceCredits + credits.coerceAtLeast(0)).coerceAtMost(9))
    public fun use(pitch: PitchKind, appearance: String, delivery: PitchDelivery, execution: Int): PitchLearningProject {
        if (!gameReady || completed || pitch != pitchType || qualityUses >= 2 || appearance in awardedAppearances) return this
        // Direct release score and execution thresholds mirror the iOS direct-pitch path.
        val qualifies = if (delivery == PitchDelivery.NEUTRAL) execution >= 600 else (delivery.releaseAccuracy + delivery.aimAccuracy) / 2 >= 650 || execution >= 650
        if (!qualifies) return this
        return copy(qualityUses = qualityUses + 1, awardedAppearances = awardedAppearances + appearance)
    }
    public fun token(): String = listOf(pitchType.wire, practiceCredits.toString(), qualityUses.toString(),
        awardedAppearances.joinToString(",") { Base64.getUrlEncoder().withoutPadding().encodeToString(it.toByteArray(Charsets.UTF_8)) }).joinToString("|")
    public companion object {
        public fun decode(token: String): PitchLearningProject {
            require(token.length <= 4096)
            val parts = token.split('|'); require(parts.size == 4)
            return PitchLearningProject(PitchKind.entries.single { it.wire == parts[0] }, parts[1].toInt(), parts[2].toInt(),
                if (parts[3].isEmpty()) emptyList() else parts[3].split(',').map { String(Base64.getUrlDecoder().decode(it), Charsets.UTF_8) })
        }
    }
}
