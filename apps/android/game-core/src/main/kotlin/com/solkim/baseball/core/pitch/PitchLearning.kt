package com.solkim.baseball.core.pitch

public object PitchLearningRules {
    private fun compensation(pitch: PitchKind): Triple<Int, Int, Int> = when (pitch) {
        PitchKind.SLIDER -> Triple(10, 10, 4)
        PitchKind.CURVEBALL -> Triple(5, 5, 3)
        else -> Triple(0, 0, 0)
    }
    public fun configure(profiles: List<PitchProfileSnapshot>, primary: PitchKind, learning: PitchKind): List<PitchProfileSnapshot> {
        require(primary != learning && learning != PitchKind.FOUR_SEAM && profiles.map { it.pitchType }.toSet() == PitchKind.entries.toSet())
        val bonus = compensation(learning)
        return profiles.map { p ->
            val eligible = p.pitchType != PitchKind.FOUR_SEAM && p.pitchType != learning
            p.copy(role = when(p.pitchType) { primary -> PitchUsageRole.PRIMARY; learning -> PitchUsageRole.DEVELOPMENT; else -> PitchUsageRole.SECONDARY },
                command = (p.command + if (eligible) bonus.first else 0).coerceAtMost(80),
                whiff = (p.whiff + if (eligible) bonus.second else 0).coerceAtMost(80),
                weakContact = (p.weakContact + if (eligible) bonus.third else 0).coerceAtMost(80))
        }
    }
    public fun advance(profiles: List<PitchProfileSnapshot>, before: PitchLearningProject, after: PitchLearningProject): List<PitchProfileSnapshot> {
        val bonus = compensation(before.pitchType)
        return profiles.map { p ->
            if (p.pitchType == after.pitchType) p.copy(role = if (after.completed) PitchUsageRole.SECONDARY else PitchUsageRole.DEVELOPMENT)
            else if (!before.gameReady && after.gameReady && p.pitchType != PitchKind.FOUR_SEAM) p.copy(
                command = (p.command - bonus.first).coerceAtLeast(20), whiff = (p.whiff - bonus.second).coerceAtLeast(20), weakContact = (p.weakContact - bonus.third).coerceAtLeast(20))
            else p
        }
    }
    public fun playable(pitcher: PitcherSnapshot, project: PitchLearningProject?): PitcherSnapshot =
        if (project == null || project.gameReady) pitcher else pitcher.copy(pitchProfiles = pitcher.pitchProfiles?.filter { it.pitchType != project.pitchType })
}
