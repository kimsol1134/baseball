package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.pitch.PitchLearningRules
import com.solkim.baseball.core.pitch.BatSide
import com.solkim.baseball.core.pitch.BatterScoutingSnapshot
import com.solkim.baseball.core.pitch.BatterSnapshot
import com.solkim.baseball.core.pitch.BaserunnerStateSnapshot
import com.solkim.baseball.core.pitch.GameLogSnapshot
import com.solkim.baseball.core.pitch.GameStateSnapshot
import com.solkim.baseball.core.pitch.PitchAnalysisEntry
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchProfileSnapshot
import com.solkim.baseball.core.pitch.PitchUsageRole
import com.solkim.baseball.core.pitch.PitchZone
import com.solkim.baseball.core.pitch.PitcherSnapshot
import com.solkim.baseball.core.pitch.RivalMemorySnapshot

internal fun HighSchoolPhase4State.memorySnapshot(): RivalMemorySnapshot? = activePitch?.memory?.toRivalMemory()

internal fun HighSchoolPitchMemory.toRivalMemory(): RivalMemorySnapshot = RivalMemorySnapshot(
    matchupId = "",
    revision = revision,
    plateAppearancesSeen = plateAppearancesSeen,
    totalPitchesSeen = totalPitchesSeen,
    recentObservations = observations.map {
        com.solkim.baseball.core.pitch.RivalPitchObservation(it.pitchType, it.zone, it.zoneIntent, it.balls, it.strikes, it.outcome)
    },
)

internal fun RivalMemorySnapshot.toPhase4Memory(): HighSchoolPitchMemory = HighSchoolPitchMemory(
    revision = revision,
    plateAppearancesSeen = plateAppearancesSeen,
    totalPitchesSeen = totalPitchesSeen,
    observations = recentObservations.map {
        HighSchoolPitchObservation(it.pitchType, it.zone, it.zoneIntent, it.balls, it.strikes, it.outcome)
    },
)

internal fun HighSchoolPitchContext.toPitchContext(): com.solkim.baseball.core.pitch.PlateAppearanceContext =
    com.solkim.baseball.core.pitch.PlateAppearanceContext(
        plateAppearanceId, revision, inning, outs, balls, strikes, pitchNumber,
        scoreDifferential, leverage, fatigue,
    )

internal fun com.solkim.baseball.core.pitch.PlateAppearanceContext.toPhase4Context(): HighSchoolPitchContext =
    HighSchoolPitchContext(
        plateAppearanceId, revision, inning, outs, balls, strikes, pitchNumber,
        scoreDifferential, leverage, fatigue,
    )

internal fun HighSchoolPitchGame.toGameState(): GameStateSnapshot = GameStateSnapshot.standard().copy(
    runners = BaserunnerStateSnapshot(firstOccupied, secondOccupied, thirdOccupied, 50),
    runsAllowed = runsAllowed,
    inningState = com.solkim.baseball.core.pitch.InningStateSnapshot(inning, com.solkim.baseball.core.pitch.HalfInning.TOP, outs),
)

internal fun GameStateSnapshot.toPhase4Game(): HighSchoolPitchGame = HighSchoolPitchGame(
    runsAllowed = runsAllowed,
    inning = inningState?.inning ?: 1,
    outs = inningState?.outs ?: 0,
    firstOccupied = runners.firstOccupied,
    secondOccupied = runners.secondOccupied,
    thirdOccupied = runners.thirdOccupied,
)

internal fun HighSchoolPitchLog.toGameLog(): GameLogSnapshot = GameLogSnapshot(
    gameId = gameId,
    // PitchKernel increments log revision once per pitch; totalPitches is the persisted
    // monotonic source for this compact Phase 4 adapter.
    revision = totalPitches.toULong(),
    totalPitches = totalPitches,
    entries = entries.map {
        PitchAnalysisEntry(
            it.pitchType, it.wasInZone, it.batterSwung, it.outcome, it.selectionQuality,
            it.executionQuality, it.contactQuality, it.expectedDamage, it.actualDamage,
            it.recommendationAccepted, it.velocityTenthsKph,
        )
    },
)

internal fun GameLogSnapshot.toPhase4Log(): HighSchoolPitchLog = HighSchoolPitchLog(
    gameId = gameId,
    totalPitches = totalPitches,
    entries = entries.map {
        HighSchoolPitchLogEntry(
            it.pitchType, it.wasInZone, it.batterSwung, it.outcome, it.selectionQuality,
            it.executionQuality, it.contactQuality, it.expectedDamage, it.actualDamage,
            it.recommendationAccepted, it.velocityTenthsKph,
        )
    },
)

internal fun HighSchoolPitchGame.toBatterGameIdentity(): BatSide = BatSide.RIGHT

/** Adapter with a stable pitch profile shape for HighSchool -> PitchKernel. */
public fun HighSchoolState.toPitcherSnapshot(): PitcherSnapshot = PitchLearningRules.playable(PitcherSnapshot(
    id = pitcher.id,
    name = pitcher.name,
    stuff = pitcher.stuff,
    command = pitcher.command,
    movement = pitcher.movement,
    stamina = pitcher.stamina,
    pitchProfiles = pitcher.pitchProfiles.ifEmpty { listOf(
        com.solkim.baseball.core.pitch.PitchProfileSnapshot(PitchKind.FOUR_SEAM, com.solkim.baseball.core.pitch.PitchUsageRole.PRIMARY, 1420 + (pitcher.stuff - 50) * 2, pitcher.command, pitcher.command, pitcher.stuff, pitcher.stuff, pitcher.command, 1),
        com.solkim.baseball.core.pitch.PitchProfileSnapshot(PitchKind.SLIDER, com.solkim.baseball.core.pitch.PitchUsageRole.SECONDARY, 1275, pitcher.command - 2, pitcher.command, pitcher.movement, pitcher.movement, pitcher.movement, 1),
        com.solkim.baseball.core.pitch.PitchProfileSnapshot(PitchKind.CURVEBALL, com.solkim.baseball.core.pitch.PitchUsageRole.SECONDARY, 1165, pitcher.command - 4, pitcher.command - 1, pitcher.movement + 2, pitcher.movement + 2, pitcher.movement + 1, 2),
        com.solkim.baseball.core.pitch.PitchProfileSnapshot(PitchKind.CHANGEUP, com.solkim.baseball.core.pitch.PitchUsageRole.DEVELOPMENT, 1285, pitcher.command, pitcher.command + 1, pitcher.movement - 1, pitcher.movement, pitcher.movement + 1, 1),
    ) },
    throwingHand = pitcher.throwingHand,
    mastery = pitcher.mastery,
), pitchLearningProject)

public fun HighSchoolState.toBatterSnapshot(): BatterSnapshot = BatterSnapshot(
    id = rival.id,
    name = rival.name,
    contact = rival.contact,
    discipline = rival.discipline,
    power = rival.power,
    batSide = BatSide.RIGHT,
)

internal fun HighSchoolState.toScoutingSnapshot(): BatterScoutingSnapshot {
    val rules = com.solkim.baseball.core.pitch.BatterScoutingProfileRules
    val profile = rules.profile(rules.archetype(rival.archetype), "highschool:${rival.id}")
    return BatterScoutingSnapshot(profile.hotZone, profile.coldZone, profile.pitchStrength,
        profile.pitchWeakness, (100 - rival.discipline).coerceIn(20, 80), reliability = 60)
}

/** Retained only to finish a game reserved before varied scouting was introduced. */
internal fun HighSchoolState.legacyScoutingSnapshot(): BatterScoutingSnapshot = BatterScoutingSnapshot(
    hotZone = PitchZone(1, 1),
    coldZone = PitchZone(0, 2),
    pitchStrength = PitchKind.FOUR_SEAM,
    pitchWeakness = PitchKind.CURVEBALL,
    chaseTendency = rival.discipline.coerceIn(20, 80),
    reliability = 60,
)

/** New outing sessions rotate the opposing lineup; legacy reservations retain their exact batter. */
public fun HighSchoolPhase4State.currentBatter(): BatterSnapshot {
    val base = run.toBatterSnapshot()
    val session = activePitch ?: return base
    if (!session.sessionId.endsWith(":outing-v2") || !session.context.plateAppearanceId.contains(":batter:")) return base
    val turn = session.context.plateAppearanceId.substringAfterLast(":batter:").toIntOrNull() ?: 1
    val spot = (turn - 1) % 9 + 1
    val edge = listOf(0, 2, 6, 8, 4, 0, -3, -5, -2)[spot - 1]
    return base.copy(id = "${run.rival.id}:lineup:$spot", name = "상대 ${spot}번 타자",
        contact = (base.contact + edge).coerceIn(20, 90), power = (base.power + edge).coerceIn(20, 90),
        batSide = if (spot % 3 == 0) BatSide.LEFT else BatSide.RIGHT)
}

internal fun HighSchoolPhase4State.currentScouting(): BatterScoutingSnapshot {
    val batter = currentBatter()
    if (batter.id == run.rival.id) return run.toScoutingSnapshot()
    val rules = com.solkim.baseball.core.pitch.BatterScoutingProfileRules
    val profile = rules.profile(rules.archetype(run.rival.archetype), "highschool:${batter.id}")
    return BatterScoutingSnapshot(profile.hotZone, profile.coldZone, profile.pitchStrength,
        profile.pitchWeakness, (100 - batter.discipline).coerceIn(20, 80), reliability = 60)
}
