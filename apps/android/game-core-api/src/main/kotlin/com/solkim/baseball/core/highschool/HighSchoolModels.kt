package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.pitch.PitchLearningProject
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.AbilityMasterySnapshot
import com.solkim.baseball.core.pitch.PitchProfileSnapshot
import com.solkim.baseball.core.pitch.PitchUsageRole
import com.solkim.baseball.core.pitch.ThrowingHand
import kotlin.math.max
import kotlin.math.min
/** Immutable player setup copied from the Swift/C# high-school career contract. */
public data class HighSchoolIdentity(
    val name: String = "민서준",
    val throwingHand: String = "right",
    val bodyType: String = "balanced",
    val region: String = "서울",
)

public data class HighSchoolDifficulty(
    val careerHarshness: String = "standard",
    val informationClarity: String = "standard",
    val simulationDifficulty: String = "standard",
    val interventionAssist: String = "standard",
)

public data class HighSchoolAllocation(
    val stuff: Int = 2,
    val command: Int = 1,
    val movement: Int = 1,
    val stamina: Int = 1,
) {
    public val total: Int get() = stuff + command + movement + stamina
}

public data class HighSchoolPitcher(
    val id: String,
    val name: String,
    val stuff: Int,
    val command: Int,
    val movement: Int,
    val stamina: Int,
    /** The source profile is durable shadow state; Unity never receives this object. */
    val pitchProfiles: List<PitchProfileSnapshot> = emptyList(),
    val throwingHand: ThrowingHand = ThrowingHand.RIGHT,
    /** Missing on legacy saves; zero is supplied by the projection boundary. */
    val mastery: AbilityMasterySnapshot? = null,
) {
    public val effectiveMastery: AbilityMasterySnapshot get() = mastery ?: AbilityMasterySnapshot.ZERO
}

public data class HighSchoolTrainingOpportunity(
    val focus: HighSchoolTrainingFocus,
    val reason: String,
)

public data class HighSchoolPerformance(
    val importantGamesCompleted: Int = 0,
    val pitches: Int = 0,
    val strikeouts: Int = 0,
    val walks: Int = 0,
    val runsAllowed: Int = 0,
    val expectedDamage: Int = 0,
    val actualDamage: Int = 0,
    val outs: Int = 0,
    val hits: Int = 0,
    /** Perfect releases across every recorded game; absent from the Swift oracle, so it stays 0 on fixture paths. */
    val perfectReleases: Int = 0,
)

public data class HighSchoolGameReport(
    val scenarioNumber: Int,
    val pitches: Int,
    val strikeouts: Int,
    val walks: Int,
    val runsAllowed: Int,
    val expectedDamage: Int,
    val actualDamage: Int,
    val recommendationAccepted: Int,
    val outs: Int? = null,
    val hits: Int? = null,
    /** Swift ImportantInningReport.sequenceMasteryCount; null preserves pre-v4 reports. */
    val sequenceMasteryCount: Int? = null,
    /** Swift scoreDifferentialAtEntry; nullable for old report callers. */
    val scoreDifferentialAtEntry: Int? = null,
    /** Source ProGameLine support projection; populated by the Phase 4 boundary. */
    val teamRuns: Int? = null,
    val homeRuns: Int? = null,
    /** Android-first: perfect releases in this game; null keeps oracle reports unchanged. */
    val perfectReleases: Int? = null,
)

public data class HighSchoolTrainingPreview(
    val minimumGrowth: Int, val maximumGrowth: Int,
    val fatigueChange: Int, val armRiskChange: Int,
    val atTalentWall: Boolean, val rehabilitation: Boolean,
    val schoolBonus: Boolean, val opportunityBonus: Boolean,
    val jackpotChancePercent: Int = 0,
    val jackpotMinimumGrowth: Int = 0, val jackpotMaximumGrowth: Int = 0,
    val firstTrainingGuaranteed: Boolean = false,
    val experience: Int = 0,
    val practiceStep: Int = 0,
    val breakthroughProgress: Int = 0,
    val breakthroughTarget: Int = 0,
    val masteryTraining: Boolean = false,
)

public data class HighSchoolTrainingResult(
    val number: Int,
    val focus: HighSchoolTrainingFocus,
    val intensity: HighSchoolTrainingIntensity,
    val growth: Int,
    val fatigueChange: Int,
    val opportunityHit: Boolean,
    val bloomed: Boolean,
    val masteryBefore: Int? = null,
    val masteryAfter: Int? = null,
)

/**
 * Durable evidence for one committed training session.  The Phase 4 state codec carries this
 * separately from HighSchoolState.lastTraining because lastTraining is only a presentation
 * pointer and is intentionally overwritten by the next session.
 */
public data class HighSchoolTrainingEvidence(
    val careerId: String,
    val lifeNumber: Int,
    val chapterNumber: Int,
    val trainingNumber: Int,
    val focus: HighSchoolTrainingFocus,
    val intensity: HighSchoolTrainingIntensity,
    val targetPitch: PitchKind? = null,
    val growthPoints: Int,
    val fatigueDelta: Int,
    val codecVersion: Int = 1,
)

public data class HighSchoolRelationshipResult(
    val number: Int,
    val target: HighSchoolRelationshipTarget,
    val response: HighSchoolRelationshipResponse,
    val trustBefore: Int,
    val trustAfter: Int,
    val fatigueBefore: Int,
    val fatigueAfter: Int,
    val fanInterestBefore: Int,
    val fanInterestAfter: Int,
    val growthFocus: HighSchoolTrainingFocus?,
    val masteryBefore: Int? = null,
    val masteryAfter: Int? = null,
)

/** Source-shaped draft read model. All names and copy are the current fictional-world catalog. */
public data class HighSchoolDraftTeam(
    val id: String,
    val name: String,
    val need: HighSchoolTrainingFocus,
    val demand: Int,
    val developmentPlan: String,
    val positionCompetitor: String,
    val proCoach: String,
    val competitorProfile: String? = null,
    val competitorRecord: String? = null,
    val coachProfile: String? = null,
    val coachRecord: String? = null,
)

public data class HighSchoolDraftResult(
    val outcome: HighSchoolDraftOutcome,
    val evaluationScore: Int,
    val projectedRange: String,
    val teamId: String?,
    val team: HighSchoolDraftTeam? = null,
    val round: Int? = null,
    val overallPick: Int? = null,
    val signingBonus: Int? = null,
    val firstSeasonGoal: String? = null,
    val evaluationBreakdown: List<String>? = null,
    val summary: String = "",
)

public data class HighSchoolState(
    val careerId: String,
    val revision: ULong,
    val lifeNumber: Int,
    val presetId: String,
    val phase: HighSchoolPhase,
    val identity: HighSchoolIdentity,
    val difficulty: HighSchoolDifficulty,
    val karmas: List<HighSchoolKarma>,
    val soulBoosts: List<HighSchoolSoulBoost>,
    val legacyRewardPermille: Int,
    val memorySlots: Int,
    val pitcher: HighSchoolPitcher,
    val talent: HighSchoolTalent,
    val schoolOptions: List<HighSchoolSchool>,
    val school: HighSchoolSchool?,
    val rival: HighSchoolRival,
    val chapter: HighSchoolChapter,
    val schedule: HighSchoolSchedule,
    val chapterTrainingCount: Int,
    val totalTrainingsCompleted: Int,
    val milestoneIndex: Int,
    val relationshipsCompleted: Int,
    val relationshipTrust: Int,
    val managerTrust: Int,
    val catcherTrust: Int,
    val rivalTrust: Int,
    val selectedAwakenings: List<HighSchoolAwakening>,
    val awakeningOptions: List<HighSchoolAwakening>,
    val awakeningSparks: Int,
    val fatigue: Int,
    val performance: HighSchoolPerformance,
    val currentGameScenarioId: String?,
    val currentRelationshipTarget: HighSchoolRelationshipTarget?,
    val trainingOpportunity: HighSchoolTrainingOpportunity?,
    val lastTraining: HighSchoolTrainingResult?,
    val lastRelationship: HighSchoolRelationshipResult?,
    val fanInterest: Int,
    val armRisk: Int,
    val injuryRecovery: Int,
    val automaticGames: Int,
    val automaticOuts: Int,
    val automaticRunsAllowed: Int,
    val draftResult: HighSchoolDraftResult?,
    val legacyOptions: List<String>,
    val selectedMemories: List<String>,
    /** Persisted source event category; Swift stores the full current event snapshot. */
    val currentRelationshipCategory: String? = null,
    /** Additive source-shaped content snapshots. IDs remain for old read models. */
    val currentGameScenario: HighSchoolGameScenario? = null,
    val currentRelationshipEvent: HighSchoolRelationshipEvent? = null,
    val news: List<String> = emptyList(),
    val balanceVersion: Int = HighSchoolContentCatalog.BALANCE_VERSION,
    val worldRulesVersion: Int = HighSchoolContentCatalog.WORLD_RULES_VERSION,
    val rebirthEcho: HighSchoolRebirthEcho? = null,
    val recentRelationshipEventIds: List<String> = emptyList(),
    val stateCommitment: String,
    val pitchLearningProject: PitchLearningProject? = null,
    /** "이 경기는 내가 던진다": the chapter's regular game was claimed; cleared by advanceChapter. */
    val chapterGameClaimed: Boolean = false,
    val development: HighSchoolDevelopment? = null,
)

public data class HighSchoolEvent(
    val eventType: String,
    val sequence: Int = 0,
    val reasonCodes: List<String> = emptyList(),
)

public data class HighSchoolResult(
    val revision: ULong,
    val nextSeed: String,
    val events: List<HighSchoolEvent>,
    val snapshot: HighSchoolState,
    val eventHash: String,
)
