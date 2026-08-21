package com.solkim.baseball.core.pro

import com.solkim.baseball.core.highschool.HighSchoolArchiveRecord
import com.solkim.baseball.core.highschool.HighSchoolDraftResult
import com.solkim.baseball.core.highschool.HighSchoolPerformance
import com.solkim.baseball.core.highschool.HighSchoolPitcher
import com.solkim.baseball.core.highschool.HighSchoolPhase4State
import com.solkim.baseball.core.highschool.HighSchoolState
import com.solkim.baseball.core.pitch.BatterScoutingSnapshot
import com.solkim.baseball.core.pitch.BatterSnapshot
import com.solkim.baseball.core.pitch.GameLogSnapshot
import com.solkim.baseball.core.pitch.GameStateSnapshot
import com.solkim.baseball.core.pitch.PitchCall
import com.solkim.baseball.core.pitch.PitchDelivery
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchPreparation
import com.solkim.baseball.core.pitch.PitchSequencePitch
import com.solkim.baseball.core.pitch.PitcherSnapshot
import com.solkim.baseball.core.pitch.RivalMemorySnapshot
import com.solkim.baseball.core.pitch.TrajectoryPresentationSnapshot
import com.solkim.baseball.core.pitch.ThrowingHand

/** The source-shaped entry point. Direct Pro is deliberately not a synthetic HS life. */
public enum class ProStartMode(public val wire: String) {
    LINKED("linked"),
    DIRECT("direct"),
}

public enum class ProCareerPhase(public val wire: String) {
    CONTRACT_OFFER("contract_offer"),
    WEEKLY_PLAN("weekly_plan"),
    SEASON_DECISION("season_decision"),
    IMPORTANT_GAME("important_game"),
    SEASON_REVIEW("season_review"),
    OFFSEASON_DECISION("offseason_decision"),
    RETIREMENT_DECISION("retirement_decision"),
    LEGACY_SELECTION("legacy_selection"),
    COMPLETED("completed"),
}

public enum class ProLevel(public val wire: String) { MINOR("minor"), MAJOR("major") }

public enum class ProRole(public val wire: String) {
    STARTER("starter"),
    LONG_RELIEF("long_relief"),
    SETUP("setup"),
    CLOSER("closer"),
}

/** Six current choices. DEVELOP_WEAPON is retained only for pre-Phase-5 saves. */
public enum class ProWeekPlan(public val wire: String) {
    DEVELOP_STUFF("develop_stuff"),
    DEVELOP_MOVEMENT("develop_movement"),
    REFINE_COMMAND("refine_command"),
    BUILD_STAMINA("build_stamina"),
    RECOVER("recover"),
    EARN_TRUST("earn_trust"),
    DEVELOP_WEAPON("develop_weapon"),
    ;

    public companion object {
        public val currentChoices: List<ProWeekPlan> = listOf(
            DEVELOP_STUFF, DEVELOP_MOVEMENT, REFINE_COMMAND, BUILD_STAMINA, RECOVER, EARN_TRUST,
        )
    }
}

public enum class OffseasonDecision(public val wire: String) {
    CONTINUE("continue"),
    MILITARY_SERVICE("military_service"),
    FREE_AGENCY("free_agency"),
    RETIRE("retire"),
}

public enum class ProSeasonSegment(public val wire: String) {
    SPRING_CAMP("spring_camp"),
    OPENING("opening"),
    FIRST_HALF("first_half"),
    ALL_STAR_BREAK("all_star_break"),
    PENNANT_RACE("pennant_race"),
    SEASON_FINALE("season_finale"),
}

public enum class ProSeasonTrigger(public val wire: String) {
    OPENING_STATEMENT("opening_statement"),
    CALL_UP_AUDITION("call_up_audition"),
    MAJOR_DEBUT("major_debut"),
    RECORD_CHASE("record_chase"),
    ROLE_SHOWDOWN("role_showdown"),
    STANDINGS_RACE("standings_race"),
}

public enum class ProSeasonDecisionType(public val wire: String) {
    EXTRA_BULLPEN("extra_bullpen"),
    CATCHER_GAME_PLAN("catcher_game_plan"),
    ROLE_MEETING("role_meeting"),
    RECORD_CHASE("record_chase"),
    RIVAL_ANALYSIS("rival_analysis"),
    SEASON_FINALE("season_finale"),
}

public enum class ProPitchBoundary(public val wire: String) {
    RESERVED("reserved"),
    PLAYING("playing"),
    COMPLETED("completed"),
}

public data class ProTeam(
    val id: String,
    val name: String,
    val positionCompetitor: String,
    val developmentPlan: String,
    val demand: Int,
)

public data class ProEntitlement(
    val active: Boolean = true,
    val source: String = "development",
    val verifiedAt: String = "shadow",
)

public data class ProDevelopmentProgress(
    val stuff: Int = 0,
    val command: Int = 0,
    val movement: Int = 0,
    val stamina: Int = 0,
) {
    init {
        require(stuff in 0..8 && command in 0..8 && movement in 0..8 && stamina in 0..8) { "development.progress" }
    }

    public fun value(plan: ProWeekPlan): Int = when (plan) {
        ProWeekPlan.DEVELOP_STUFF -> stuff
        ProWeekPlan.REFINE_COMMAND -> command
        ProWeekPlan.DEVELOP_MOVEMENT -> movement
        ProWeekPlan.BUILD_STAMINA -> stamina
        ProWeekPlan.DEVELOP_WEAPON -> minOf(stuff, movement)
        else -> 0
    }
}

public data class ProContract(
    val yearsRemaining: Int,
    val annualSalary: Int,
    val rolePromise: ProRole,
)

public data class ProDecisionEffect(
    val stuffDelta: Int = 0,
    val commandDelta: Int = 0,
    val movementDelta: Int = 0,
    val staminaDelta: Int = 0,
    val managerTrustDelta: Int = 0,
    val catcherTrustDelta: Int = 0,
    val fatigueDelta: Int = 0,
    val roleTarget: ProRole? = null,
) {
    public fun summary(): String = buildList {
        addDelta(stuffDelta, "구위")
        addDelta(commandDelta, "제구")
        addDelta(movementDelta, "변화구")
        addDelta(staminaDelta, "체력")
        addDelta(managerTrustDelta, "감독의 믿음")
        addDelta(catcherTrustDelta, "포수와의 호흡")
        addDelta(fatigueDelta, "피로")
        roleTarget?.let { add("역할 → ${it.label}") }
    }.joinToString(" · ")

    private fun MutableList<String>.addDelta(value: Int, label: String) {
        if (value != 0) add("$label ${if (value > 0) "+" else ""}$value")
    }
}

public val ProRole.label: String
    get() = when (this) {
        ProRole.STARTER -> "선발"
        ProRole.LONG_RELIEF -> "긴 이닝 구원"
        ProRole.SETUP -> "필승조"
        ProRole.CLOSER -> "마무리"
    }

public data class ProDecisionChoice(
    val id: String,
    val title: String,
    val detail: String,
    val effect: ProDecisionEffect,
)

public data class ProSeasonDecision(
    val id: String,
    val type: ProSeasonDecisionType,
    val season: Int,
    val week: Int,
    val title: String,
    val detail: String,
    val choices: List<ProDecisionChoice>,
)

public data class ProDecisionRecord(
    val decisionId: String,
    val type: ProSeasonDecisionType,
    val season: Int,
    val week: Int,
    val choiceId: String,
    val choiceTitle: String,
    val effect: ProDecisionEffect,
    val followUpResolvedWeek: Int? = null,
)

public data class ProSeasonStats(
    val season: Int,
    val teamId: String,
    val games: Int = 0,
    val starts: Int = 0,
    val inningsOuts: Int = 0,
    val strikeouts: Int = 0,
    val walks: Int = 0,
    val runsAllowed: Int = 0,
    val hits: Int = 0,
    val homeRuns: Int = 0,
    val pitches: Int = 0,
    val wins: Int = 0,
    val losses: Int = 0,
    val saves: Int = 0,
) {
    public val runPerNinePermille: Int
        get() = if (inningsOuts == 0) 9_990 else runsAllowed * 27_000 / inningsOuts
}

public enum class ProPitchingDecision(public val wire: String) {
    WIN("win"), LOSS("loss"), SAVE("save"), NO_DECISION("no_decision"),
}

public data class ProGameLine(
    val season: Int,
    val week: Int,
    val outingNumber: Int,
    val started: Boolean,
    val outs: Int,
    val strikeouts: Int,
    val walks: Int,
    val runsAllowed: Int,
    val pitches: Int,
    val teamRuns: Int,
    val opponentRuns: Int,
    val decision: ProPitchingDecision,
    val played: Boolean,
    val hits: Int = 0,
    val homeRuns: Int = 0,
)

public data class ProRivalBatter(
    val id: String,
    val name: String,
    val archetype: String,
    val teamId: String,
    val teamName: String,
    val record: String,
    val profile: String,
)

public data class ProSeasonTension(val kind: String, val title: String, val detail: String)

public data class ProStanding(
    val rank: Int,
    val teamId: String,
    val teamName: String,
    val wins: Int,
    val losses: Int,
    val draws: Int,
    val gamesBehindPermille: Int,
    val isPlayerTeam: Boolean,
)

public data class ProLeaderboardRow(
    val category: String,
    val rank: Int,
    val playerId: String,
    val playerName: String,
    val teamId: String,
    val value: Int,
    val isCurrentPlayer: Boolean,
)

public data class ProSeasonLedger(
    val season: Int,
    val teamId: String,
    val record: ProSeasonStats,
    val standings: List<ProStanding>,
    val leaderboards: List<ProLeaderboardRow>,
    val awards: List<String>,
    val milestones: List<String>,
    val decisionCount: Int,
)

public data class ProLegacyCandidate(
    val id: String,
    val title: String,
    val evidenceSummary: String,
    val farewell: String,
    val score: Int,
)

public data class ProHighSchoolArchiveSettlement(
    val highSchoolCareerId: String,
    val proCareerId: String,
    val selectedLegacyId: String,
    val playerName: String,
    val teamId: String,
    val careerSeasons: Int,
    val careerGames: Int,
    val careerStrikeouts: Int,
    val archiveReceipt: String,
)

public data class ProPitchSession(
    val sessionId: String,
    val week: Int,
    val seed: String,
    val pitchIndex: Int,
    val preparationToken: String,
    val context: com.solkim.baseball.core.pitch.PlateAppearanceContext,
    val memory: RivalMemorySnapshot,
    val game: GameStateSnapshot,
    val log: GameLogSnapshot,
    val batter: BatterSnapshot,
    val scouting: BatterScoutingSnapshot,
    val pitches: Int = 0,
    val strikeouts: Int = 0,
    val walks: Int = 0,
    val runsAllowed: Int = 0,
    val expectedDamage: Int = 0,
    val actualDamage: Int = 0,
    val recommendationAccepted: Int = 0,
    val outs: Int = 0,
    val hits: Int = 0,
    val homeRuns: Int = 0,
    val abilityMoments: List<String> = emptyList(),
    val sequenceMasteryCount: Int = 0,
    val sequencePitches: List<PitchSequencePitch> = emptyList(),
    val ended: Boolean = false,
    val boundary: ProPitchBoundary = ProPitchBoundary.PLAYING,
)

public data class ProStartLinkedRequest(
    val seed: String,
    val highSchoolCareerId: String,
    val identityName: String,
    val pitcher: PitcherSnapshot,
    val teamId: String,
    val draftEvaluation: Int,
    val entitlement: ProEntitlement = ProEntitlement(),
    val activeHighSchoolPreserved: Boolean = true,
    val highSchoolLegacyContext: ProHighSchoolLegacyContext? = null,
) {
    public companion object
}

public data class ProStartDirectRequest(
    val seed: String,
    val presetId: String,
    val playerName: String,
    val activeHighSchoolCareerId: String? = null,
)

public data class ProHighSchoolLegacyContext(
    val startingPitcher: PitcherSnapshot,
    val highSchoolPitcher: PitcherSnapshot,
    val performance: HighSchoolPerformance,
    val selectedAwakenings: List<String>,
    val managerTrust: Int,
    val catcherTrust: Int,
    val rivalTrust: Int,
)

public data class ProImportantGameReport(
    val pitches: Int,
    val strikeouts: Int,
    val walks: Int,
    val runsAllowed: Int,
    val expectedDamage: Int,
    val actualDamage: Int,
    val recommendationAccepted: Int,
    val outs: Int? = null,
    val hits: Int? = null,
    val homeRuns: Int? = null,
    val teamRuns: Int? = null,
    val scoreDifferentialAtEntry: Int? = null,
    val sequenceMasteryCount: Int? = null,
)

public data class ProSegmentProgress(
    val advancedWeeks: Int,
    val startingSegment: ProSeasonSegment,
    val endingSegment: ProSeasonSegment,
    val stopReason: String,
    val plan: ProWeekPlan,
    val targetPitch: PitchKind?,
)

public data class ProCommandReceipt(
    val commandId: String,
    val sessionId: String,
    val commandHash: String,
    val resultHash: String,
    val revision: ULong,
)

/** Immutable shadow aggregate. Production package/save writes remain disabled in Phase 5. */
public data class ProState(
    val careerId: String,
    val revision: ULong,
    val startMode: ProStartMode,
    val sourceHighSchoolCareerId: String?,
    val highSchoolLegacyContext: ProHighSchoolLegacyContext?,
    val activeHighSchoolPreserved: Boolean,
    val seed: String,
    val identityName: String,
    val pitcher: PitcherSnapshot,
    val team: ProTeam,
    val entitlement: ProEntitlement,
    val age: Int,
    val season: Int,
    val week: Int,
    val phase: ProCareerPhase,
    val level: ProLevel,
    val role: ProRole,
    val rolePreference: ProRole?,
    val managerTrust: Int,
    val catcherTrust: Int,
    val fatigue: Int,
    val injuryWeeks: Int,
    val serviceYears: Int,
    val militaryCompleted: Boolean,
    val contract: ProContract?,
    val currentStats: ProSeasonStats,
    val currentGameLines: List<ProGameLine>,
    val careerStats: List<ProSeasonStats>,
    val seasonLedgers: List<ProSeasonLedger>,
    val awards: List<String>,
    val milestones: List<String>,
    val decisionHistory: List<ProDecisionRecord>,
    val pendingDecision: ProSeasonDecision?,
    val developmentProgress: ProDevelopmentProgress,
    val seasonSegment: ProSeasonSegment,
    val seasonTrigger: ProSeasonTrigger?,
    val currentRival: ProRivalBatter?,
    val seasonTensions: List<ProSeasonTension>,
    val importantGames: Int,
    val standings: List<ProStanding>,
    val leaderboards: List<ProLeaderboardRow>,
    val legacyCandidates: List<ProLegacyCandidate>,
    val selectedLegacyId: String?,
    val highSchoolArchiveSettlement: ProHighSchoolArchiveSettlement?,
    val activePitch: ProPitchSession?,
    val lastPresentation: TrajectoryPresentationSnapshot?,
    val lastSegmentProgress: ProSegmentProgress?,
    val hallOfFameScore: Int?,
    val news: List<String>,
    val commandReceipts: List<ProCommandReceipt> = emptyList(),
    val commitment: String = "",
    /** Live outing offset and weekly ticks. 1 = frozen, 4 = current iOS live rules. */
    val proRulesVersion: Int = 1,
    /** Optional Wave 6 journey block. Legacy ProState callers and v1 saves remain nil. */
    val journeyState: ProCareerJourneyState? = null,
)

public typealias ProCareerSnapshot = ProState

public data class ProResult(
    val state: ProState,
    val nextSeed: String,
    val events: List<String>,
    val preparation: PitchPreparation? = null,
    val presentation: TrajectoryPresentationSnapshot? = null,
    val segmentProgress: ProSegmentProgress? = null,
)

public data class ProDispatchResult(
    val state: ProState,
    val eventHash: String,
    val duplicate: Boolean,
)

/** Link helper: the Pro core reads the finished HS result but never mutates the active HS save. */
public fun ProStartLinkedRequest.Companion.fromHighSchool(
    seed: String,
    state: HighSchoolPhase4State,
): ProStartLinkedRequest {
    val run: HighSchoolState = state.run
    val draft: HighSchoolDraftResult = run.draftResult ?: error("pro.linked.draft_missing")
    val teamId = draft.teamId ?: draft.team?.id ?: error("pro.linked.team_missing")
    return ProStartLinkedRequest(
        seed = seed,
        highSchoolCareerId = run.careerId,
        identityName = run.identity.name,
        pitcher = run.toPitcherSnapshotForPro(),
        teamId = teamId,
        draftEvaluation = draft.evaluationScore,
        highSchoolLegacyContext = ProHighSchoolLegacyContext(
            startingPitcher = state.startingPitcher.toPitcherSnapshotForPro(),
            highSchoolPitcher = run.toPitcherSnapshotForPro(),
            performance = run.performance,
            selectedAwakenings = run.selectedAwakenings.map { it.wire },
            managerTrust = run.managerTrust,
            catcherTrust = run.catcherTrust,
            rivalTrust = run.rivalTrust,
        ),
    )
}

public fun HighSchoolState.toPitcherSnapshotForPro(): PitcherSnapshot = PitcherSnapshot(
    id = pitcher.id,
    name = pitcher.name,
    stuff = pitcher.stuff,
    command = pitcher.command,
    movement = pitcher.movement,
    stamina = pitcher.stamina,
    pitchProfiles = pitcher.pitchProfiles,
    throwingHand = pitcher.throwingHand,
)

public fun HighSchoolPitcher.toPitcherSnapshotForPro(): PitcherSnapshot = PitcherSnapshot(
    id = id,
    name = name,
    stuff = stuff,
    command = command,
    movement = movement,
    stamina = stamina,
    pitchProfiles = pitchProfiles,
    throwingHand = throwingHand,
)
