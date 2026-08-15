package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.pitch.BatSide
import com.solkim.baseball.core.pitch.BatterScoutingSnapshot
import com.solkim.baseball.core.pitch.BatterSnapshot
import com.solkim.baseball.core.pitch.BaserunnerStateSnapshot
import com.solkim.baseball.core.pitch.GameLogSnapshot
import com.solkim.baseball.core.pitch.GameStateSnapshot
import com.solkim.baseball.core.pitch.PitchAnalysisEntry
import com.solkim.baseball.core.pitch.PitchCall
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchPreparation
import com.solkim.baseball.core.pitch.PitchZone
import com.solkim.baseball.core.pitch.PitcherSnapshot
import com.solkim.baseball.core.pitch.RivalMemorySnapshot
import com.solkim.baseball.core.pitch.TrajectoryPresentationSnapshot

public enum class HighSchoolPledgeTier(public val wire: String, public val rewardPermille: Int) {
    SAFE("safe", 100),
    BOLD("bold", 200),
    LEGENDARY("legendary", 350),
}

public data class HighSchoolPledgeDefinition(
    val id: String,
    val tier: HighSchoolPledgeTier,
    val target: Int,
    val title: String,
    val detail: String,
)

public data class HighSchoolPledgeState(
    val definition: HighSchoolPledgeDefinition,
    val progress: Int = 0,
    val achieved: Boolean = false,
    val rewardApplied: Boolean = false,
)

/** Swift `NextRunIntent`: an explicit, durable pledge suggestion for the next life. */
public data class HighSchoolNextRunIntent(
    val pledgeId: String,
    val sourceLifeNumber: Int,
    val reason: String,
)

public data class HighSchoolWeeklyTask(
    val id: String,
    val target: Int,
    val progress: Int = 0,
    val completed: Boolean = false,
    /** C# Meta's stable task kind; old Phase 4 snapshots use `id` as this value. */
    val kind: String = id,
)

public data class HighSchoolWeeklyStamp(
    val weekKey: String,
    val completedTaskCount: Int,
    val perfect: Boolean,
    val earnedAtUnixSeconds: Long,
)

public data class HighSchoolWeeklyState(
    val stableUserId: String,
    val weekKey: String,
    val tasks: List<HighSchoolWeeklyTask>,
    val rewardClaimed: Boolean = false,
    val processedReceiptIds: List<String> = emptyList(),
    val playedDayKeys: List<String> = emptyList(),
    val stamps: List<HighSchoolWeeklyStamp> = emptyList(),
    val lastObservedWeekStartDayKey: String? = null,
)

public enum class HighSchoolReturnDestination(public val wire: String) {
    HIGH_SCHOOL("high_school"),
    PRO("pro"),
    DAILY_INNING("daily_inning"),
}

public data class HighSchoolReturnPlan(
    val destination: HighSchoolReturnDestination,
    val reason: String,
    val createdDayKey: String,
    val receiptId: String,
    val dismissed: Boolean = false,
    /** C# Meta compatibility fields. Legacy callers may leave these at their defaults. */
    val route: String = destination.wire,
    val title: String = reason,
    val body: String = reason,
    val experimentId: String? = null,
    val savedDayKey: String? = null,
    val experimentVariant: String? = null,
    val developmentRulesVersion: Int? = null,
)

public data class HighSchoolInheritanceState(
    val nextLifeNumber: Int,
    val soulPoints: Int,
    val soulTotalEarned: Int,
    val automaticSoulEarned: Int,
    val inheritedMemories: List<String> = emptyList(),
    val selectedSignatureLegacyId: String? = null,
    val unlockedSignatureLegacyIds: List<String> = emptyList(),
    /** null preserves the current Swift/C# legacy default (inheritance v1). */
    val inheritanceRulesVersion: Int? = null,
    val lineageMasteries: List<HighSchoolLineageMastery> = emptyList(),
    val lineageLoadout: HighSchoolLineageLoadout? = null,
)

/** The six-family mastery projection used by the current Swift archive rules. */
public data class HighSchoolLineageMastery(
    val family: String,
    val contributions: Int,
    val rank: Int,
    val nextThreshold: Int?,
)

/** A frozen effect equipped by the next life. It is shadow metadata, not a new currency. */
public data class HighSchoolLineageLoadout(
    val rulesVersion: Int = 1,
    val legacyId: String,
    val masteryRank: Int,
    val contributions: Int,
    val sourceLifeNumber: Int? = null,
)

public data class HighSchoolRebirthEcho(
    val previousLifeNumber: Int,
    val previousPlayerName: String,
    val previousSchoolName: String?,
    val previousCareerId: String,
    val inheritedMemoryCount: Int,
    val inheritedSignatureLegacyId: String?,
    val previousArmWarning: Boolean,
    val previousUndrafted: Boolean,
    val recentEventIds: List<String>,
    val previousNickname: String? = null,
    val previousCoachName: String? = null,
    val previousRivalName: String? = null,
    val inheritedLegacyId: String? = null,
    val automaticInheritanceTotal: Int? = null,
    val hadRunsAllowed: Boolean? = null,
    val hadCollapseGame: Boolean = false,
)

public val HighSchoolRebirthEcho.hasInheritedPower: Boolean
    get() = inheritedMemoryCount > 0 || inheritedLegacyId != null || (automaticInheritanceTotal ?: 0) > 0

public val HighSchoolRebirthEcho.hasRunsAllowedFact: Boolean
    get() = hadRunsAllowed ?: hadCollapseGame

public data class HighSchoolArchiveRecord(
    val careerId: String,
    val lifeNumber: Int,
    val playerName: String,
    val schoolId: String?,
    val schoolName: String?,
    val drafted: Boolean,
    val draftEvaluation: Int,
    val teamId: String?,
    val ratings: List<Int>,
    val importantGames: Int,
    val pitches: Int,
    val strikeouts: Int,
    val walks: Int,
    val runsAllowed: Int,
    val selectedAwakenings: List<String>,
    val selectedSignatureLegacyId: String?,
    val pledgeId: String?,
    val pledgeAchieved: Boolean,
    val soulEarned: Int,
    val completedGameCounterAtArchive: ULong,
)

public enum class HighSchoolPitchingDecision(public val wire: String) {
    WIN("win"),
    LOSS("loss"),
    NO_DECISION("no_decision"),
}

public data class HighSchoolSeasonLine(
    val careerId: String,
    val lifeNumber: Int,
    val chapter: Int,
    val gameNumber: Int,
    val pitches: Int,
    val strikeouts: Int,
    val walks: Int,
    val runsAllowed: Int,
    val expectedDamage: Int,
    val actualDamage: Int,
    val abilityMoments: List<String>,
    val rivalStrikeouts: Int = 0,
    val season: Int = 0,
    val week: Int = 0,
    val outingNumber: Int = 0,
    val started: Boolean = false,
    val outs: Int = 0,
    val teamRuns: Int = 0,
    val opponentRuns: Int = 0,
    val decision: HighSchoolPitchingDecision = HighSchoolPitchingDecision.NO_DECISION,
    val played: Boolean = true,
    val hits: Int = 0,
    val homeRuns: Int = 0,
)

public data class HighSchoolTournamentSnapshot(
    val chapter: Int,
    val name: String,
    val playerRound: String,
    val bracketSeed: String,
    val completed: Boolean,
    /** The deterministic eight-school field shown by the current C#/Swift projection. */
    val schools: List<String> = emptyList(),
)

public data class HighSchoolProspectEntry(
    val playerId: String,
    val name: String,
    val schoolName: String,
    val rank: Int,
    val score: Int,
    val isCurrentPlayer: Boolean,
    /** The source scouting one-line description; empty is retained only for old snapshots. */
    val tag: String = "",
)

public data class HighSchoolTutorialState(
    val started: Boolean = false,
    val completed: Boolean = false,
)

/** A backup of the durable shadow state. It is never written by the production repository. */
public data class HighSchoolChallengeBackup(
    val run: HighSchoolState,
    val startingPitcher: HighSchoolPitcher,
    val inheritance: HighSchoolInheritanceState,
    val archive: List<HighSchoolArchiveRecord>,
    val achievements: List<String>,
    val weekly: HighSchoolWeeklyState,
    val pledge: HighSchoolPledgeState?,
    val selectedSignatureLegacyId: String?,
    val returnPlan: HighSchoolReturnPlan?,
    val rebirthEcho: HighSchoolRebirthEcho?,
    val seasonLog: List<HighSchoolSeasonLine>,
    val tournaments: List<HighSchoolTournamentSnapshot>,
    val prospectBoard: List<HighSchoolProspectEntry>,
    val completedGameCounter: ULong,
    val completedGameReceipts: List<String>,
    val selectedDayKey: String,
    val tutorial: HighSchoolTutorialState = HighSchoolTutorialState(),
    val commandReceipts: List<HighSchoolCommandReceipt> = emptyList(),
    val revision: ULong = 0UL,
    val lastPresentation: HighSchoolPresentationState? = null,
    val nextRunIntent: HighSchoolNextRunIntent? = null,
    val unacknowledgedAchievements: List<String> = emptyList(),
    val trainingEvidence: List<HighSchoolTrainingEvidence> = emptyList(),
)

public data class HighSchoolChallengeState(
    val active: Boolean = false,
    val backup: HighSchoolChallengeBackup? = null,
)

/**
 * Only deterministic runtime data required to resume an important-game pitch boundary is kept.
 * The pitcher, batter, scouting, and standard defense are reconstructed from the authoritative
 * run/catalog; Unity receives none of this state.
 */
public data class HighSchoolPitchSession(
    val sessionId: String,
    val gameNumber: Int,
    val seed: String,
    val pitchIndex: Int,
    val preparationToken: String,
    val context: HighSchoolPitchContext,
    val memory: HighSchoolPitchMemory,
    val game: HighSchoolPitchGame,
    val log: HighSchoolPitchLog,
    val pitches: Int = 0,
    val strikeouts: Int = 0,
    val walks: Int = 0,
    val runsAllowed: Int = 0,
    val expectedDamage: Int = 0,
    val actualDamage: Int = 0,
    val recommendationAccepted: Int = 0,
    val outs: Int = 0,
    val hits: Int = 0,
    val abilityMoments: List<String> = emptyList(),
    val ended: Boolean = false,
    /** Count of source PitchSequenceEvaluator moments for this important game. */
    val sequenceMasteryCount: Int = 0,
    /** Current plate appearance only; it is reset after a terminal plate appearance. */
    val sequencePitches: List<com.solkim.baseball.core.pitch.PitchSequencePitch> = emptyList(),
)

public data class HighSchoolPitchContext(
    val plateAppearanceId: String,
    val revision: ULong,
    val inning: Int,
    val outs: Int,
    val balls: Int,
    val strikes: Int,
    val pitchNumber: Int,
    val scoreDifferential: Int,
    val leverage: Int,
    val fatigue: Int,
)

public data class HighSchoolPitchMemory(
    val revision: ULong = 0UL,
    val plateAppearancesSeen: Int = 0,
    val totalPitchesSeen: Int = 0,
    val observations: List<HighSchoolPitchObservation> = emptyList(),
)

public data class HighSchoolPitchObservation(
    val pitchType: PitchKind,
    val zone: PitchZone,
    val zoneIntent: com.solkim.baseball.core.pitch.ZoneIntent,
    val balls: Int,
    val strikes: Int,
    val outcome: com.solkim.baseball.core.pitch.PitchOutcome,
)

public data class HighSchoolPitchGame(
    val runsAllowed: Int = 0,
    val inning: Int = 1,
    val outs: Int = 0,
    val firstOccupied: Boolean = false,
    val secondOccupied: Boolean = false,
    val thirdOccupied: Boolean = false,
)

public data class HighSchoolPitchLog(
    val gameId: String,
    val totalPitches: Int = 0,
    val entries: List<HighSchoolPitchLogEntry> = emptyList(),
)

public data class HighSchoolPitchLogEntry(
    val pitchType: PitchKind,
    val wasInZone: Boolean,
    val batterSwung: Boolean,
    val outcome: com.solkim.baseball.core.pitch.PitchOutcome,
    val selectionQuality: com.solkim.baseball.core.pitch.SelectionQuality,
    val executionQuality: Int,
    val contactQuality: Int?,
    val expectedDamage: Int,
    val actualDamage: Int,
    val recommendationAccepted: Boolean,
    val velocityTenthsKph: Int?,
)

public data class HighSchoolPresentationState(
    val snapshot: TrajectoryPresentationSnapshot,
    val pitchNumber: Int,
    val outcome: String,
    val terminal: Boolean,
)

public data class HighSchoolCommandReceipt(
    val commandId: String,
    val revision: ULong,
    val resultHash: String,
    val commandHash: String,
    /** The session that first committed this command; blank is reserved for pre-store snapshots. */
    val sessionId: String = "",
)

public data class HighSchoolPhase4State(
    val run: HighSchoolState,
    val startingPitcher: HighSchoolPitcher,
    val inheritance: HighSchoolInheritanceState,
    val archive: List<HighSchoolArchiveRecord> = emptyList(),
    val achievements: List<String> = emptyList(),
    val weekly: HighSchoolWeeklyState,
    val unacknowledgedAchievements: List<String> = emptyList(),
    val pledge: HighSchoolPledgeState? = null,
    val nextRunIntent: HighSchoolNextRunIntent? = null,
    val selectedSignatureLegacyId: String? = null,
    val returnPlan: HighSchoolReturnPlan? = null,
    val rebirthEcho: HighSchoolRebirthEcho? = null,
    val seasonLog: List<HighSchoolSeasonLine> = emptyList(),
    val tournaments: List<HighSchoolTournamentSnapshot> = emptyList(),
    val prospectBoard: List<HighSchoolProspectEntry> = emptyList(),
    val activePitch: HighSchoolPitchSession? = null,
    val lastPresentation: HighSchoolPresentationState? = null,
    val tutorial: HighSchoolTutorialState = HighSchoolTutorialState(),
    val challenge: HighSchoolChallengeState = HighSchoolChallengeState(),
    val completedGameCounter: ULong = 0UL,
    val completedGameReceipts: List<String> = emptyList(),
    val commandReceipts: List<HighSchoolCommandReceipt> = emptyList(),
    val selectedDayKey: String = "1970-01-01",
    val revision: ULong = 0UL,
    val stateCommitment: String = "",
    /** Versioned, append-only evidence for every training session committed in this state. */
    val trainingEvidence: List<HighSchoolTrainingEvidence> = emptyList(),
)

public data class HighSchoolPhase4StartRequest(
    val seed: String,
    val presetId: String,
    val stableUserId: String,
    val weekKey: String,
    val dayKey: String,
    val lifeNumber: Int = 1,
    val creationAllocation: HighSchoolAllocation = HighSchoolAllocation(),
    val inheritedSoulPoints: Int = 0,
    val inheritedSoulTotal: Int? = null,
    val inheritedSoulDomain: HighSchoolSoulDomain? = null,
    val inheritedMemories: List<String> = emptyList(),
    val inheritedSignatureLegacyId: String? = null,
    val inheritedLineageMasteries: List<HighSchoolLineageMastery> = emptyList(),
    val lineageLoadout: HighSchoolLineageLoadout? = null,
    val inheritanceRulesVersion: Int? = null,
    val inheritedNextRunIntent: HighSchoolNextRunIntent? = null,
    val identity: HighSchoolIdentity = HighSchoolIdentity(),
    val difficulty: HighSchoolDifficulty = HighSchoolDifficulty(),
    val karmas: List<HighSchoolKarma> = emptyList(),
    val soulBoosts: List<HighSchoolSoulBoost> = emptyList(),
    val inheritedRebirthEcho: HighSchoolRebirthEcho? = null,
)

public data class HighSchoolPhase4Result(
    val state: HighSchoolPhase4State,
    val events: List<HighSchoolEvent>,
    val eventHash: String,
    val preparation: PitchPreparation? = null,
    val presentation: HighSchoolPresentationState? = null,
)

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
internal fun HighSchoolState.toPitcherSnapshot(): PitcherSnapshot = PitcherSnapshot(
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
)

internal fun HighSchoolState.toBatterSnapshot(): BatterSnapshot = BatterSnapshot(
    id = rival.id,
    name = rival.name,
    contact = rival.contact,
    discipline = rival.discipline,
    power = rival.power,
    batSide = BatSide.RIGHT,
)

internal fun HighSchoolState.toScoutingSnapshot(): BatterScoutingSnapshot = BatterScoutingSnapshot(
    hotZone = PitchZone(1, 1),
    coldZone = PitchZone(0, 2),
    pitchStrength = PitchKind.FOUR_SEAM,
    pitchWeakness = PitchKind.CURVEBALL,
    chaseTendency = rival.discipline.coerceIn(20, 80),
    reliability = 60,
)
