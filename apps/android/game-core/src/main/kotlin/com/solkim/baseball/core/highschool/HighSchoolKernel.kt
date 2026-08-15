package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.SplitMix64
import com.solkim.baseball.core.StableHash
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchAbilityRules
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
)

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
)

public data class HighSchoolTrainingResult(
    val number: Int,
    val focus: HighSchoolTrainingFocus,
    val intensity: HighSchoolTrainingIntensity,
    val growth: Int,
    val fatigueChange: Int,
    val opportunityHit: Boolean,
    val bloomed: Boolean,
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

public class HighSchoolKernel {
    private val automaticOuting = HighSchoolAutomaticOutingSimulator()
    public data class StartRequest(
        val seed: String,
        val presetId: String,
        val lifeNumber: Int = 1,
        val creationAllocation: HighSchoolAllocation = HighSchoolAllocation(),
        val inheritedSoulPoints: Int = 0,
        val inheritedSoulDomain: HighSchoolSoulDomain? = null,
        val inheritedMemories: List<String> = emptyList(),
        val identity: HighSchoolIdentity = HighSchoolIdentity(),
        val difficulty: HighSchoolDifficulty = HighSchoolDifficulty(),
        val karmas: List<HighSchoolKarma> = emptyList(),
        val soulBoosts: List<HighSchoolSoulBoost> = emptyList(),
        val inheritedSoulTotal: Int? = null,
        /** Stored inheritance rules are resolved at the durable run boundary. */
        val inheritanceRulesVersion: Int? = null,
        /** Shadow-only signature legacy carried from the archived previous life. */
        val signatureLegacyId: String? = null,
        /** Source-shaped rebirth fact receipt used only for deterministic event selection. */
        val rebirthEcho: HighSchoolRebirthEcho? = null,
    )

    public data class AdvanceRequest(val seed: String, val state: HighSchoolState)
    public data class ChooseSchoolRequest(
        val seed: String,
        val state: HighSchoolState,
        val schoolId: HighSchoolSchoolId,
    )

    public data class TrainingRequest(
        val seed: String,
        val state: HighSchoolState,
        val focus: HighSchoolTrainingFocus,
        val intensity: HighSchoolTrainingIntensity,
        val targetPitch: PitchKind? = null,
    )

    public data class RelationshipRequest(
        val seed: String,
        val state: HighSchoolState,
        val response: HighSchoolRelationshipResponse,
    )

    public data class GameRequest(
        val seed: String,
        val state: HighSchoolState,
        val report: HighSchoolGameReport,
    )

    public data class AwakeningRequest(
        val seed: String,
        val state: HighSchoolState,
        val awakening: HighSchoolAwakening,
    )

    public data class LegacyRequest(
        val seed: String,
        val state: HighSchoolState,
        val memoryCards: List<String> = emptyList(),
        /** The current Swift path carries one selected signature legacy instead of memory cards. */
        val signatureLegacyId: String? = null,
    )

    public fun start(request: StartRequest): HighSchoolResult {
        val seed = parseSeed(request.seed)
        require(request.lifeNumber > 0) { "lifeNumber.invalid" }
        require(request.creationAllocation.total == 5) { "creationAllocation.total" }
        require(request.inheritedMemories.size <= 4) { "inheritedMemories.count" }
        require(request.karmas.size == request.karmas.toSet().size && request.karmas.size <= 2) {
            "karmas.invalid"
        }
        require(request.identity.name.isNotBlank() && request.identity.region.isNotBlank()) {
            "identity.invalid"
        }
        val preset = HighSchoolContentCatalog.presets.firstOrNull { it.id == request.presetId }
            ?: error("preset.unknown")
        val careerId = "career-${request.seed}-life-${request.lifeNumber}"
        val wind = windFor(careerId)
        var talent = makeTalent(careerId)
        if (HighSchoolSoulBoost.TALENT_BREAK in request.soulBoosts) {
            talent = raiseLowestTalent(talent)
        }
        var pitcher = applyCreation(
            basePitcher(request.presetId, request.identity.name, request.identity.throwingHand),
            request.creationAllocation,
        )
        val inheritance = applyInheritance(
            pitcher = pitcher,
            points = max(request.inheritedSoulTotal ?: 0, request.inheritedSoulPoints),
            domain = request.inheritedSoulDomain,
            memories = request.inheritedMemories,
            talent = talent,
            rulesVersion = request.inheritanceRulesVersion ?: 1,
            bonusPoints = if (HighSchoolSoulBoost.HEAD_START in request.soulBoosts) 5 else 0,
        )
        pitcher = inheritance.pitcher
        talent = inheritance.talent
        if (HighSchoolKarma.SINGLE_WEAPON in request.karmas) {
            val strongest = when {
                pitcher.stuff >= pitcher.command && pitcher.stuff >= pitcher.movement -> HighSchoolTrainingFocus.VELOCITY
                pitcher.command >= pitcher.movement -> HighSchoolTrainingFocus.COMMAND
                else -> HighSchoolTrainingFocus.BREAKING_BALL
            }
            pitcher = grow(pitcher, strongest, 3).copy(
                stuff = if (strongest == HighSchoolTrainingFocus.VELOCITY) pitcher.stuff else max(20, pitcher.stuff - 2),
                command = if (strongest == HighSchoolTrainingFocus.COMMAND) pitcher.command else max(20, pitcher.command - 2),
                movement = if (strongest == HighSchoolTrainingFocus.BREAKING_BALL) pitcher.movement else max(20, pitcher.movement - 2),
                stamina = max(20, pitcher.stamina - 2),
            )
        }
        request.signatureLegacyId?.let { legacyId ->
            pitcher = HighSchoolSignatureLegacyRules.apply(legacyId, pitcher)
        }
        val schools = HighSchoolContentCatalog.schools(request.identity.region)
        val schedule = makeSchedule(careerId)
        val memorySlots = (if (HighSchoolKarma.ERASED_MEMORY in request.karmas) 2 else 3) +
            if (HighSchoolSoulBoost.EXTRA_MEMORY in request.soulBoosts) 1 else 0
        val state = HighSchoolState(
            careerId = careerId,
            revision = 0UL,
            lifeNumber = request.lifeNumber,
            presetId = request.presetId,
            phase = HighSchoolPhase.PROLOGUE,
            identity = request.identity,
            difficulty = request.difficulty,
            karmas = request.karmas,
            soulBoosts = request.soulBoosts.distinct().sortedBy { it.wire },
            legacyRewardPermille = 1_000 + request.karmas.sumOf { it.rewardPermille } + wind.rewardBonusPermille,
            memorySlots = memorySlots,
            pitcher = pitcher,
            talent = talent,
            schoolOptions = schools,
            school = null,
            rival = makeRival(seed, request.difficulty.simulationDifficulty, request.karmas, wind.rivalBonus),
            chapter = HighSchoolContentCatalog.chapters.first(),
            schedule = schedule,
            chapterTrainingCount = 0,
            totalTrainingsCompleted = 0,
            milestoneIndex = 0,
            relationshipsCompleted = 0,
            relationshipTrust = 50,
            managerTrust = 50,
            catcherTrust = 50,
            rivalTrust = 50,
            selectedAwakenings = emptyList(),
            awakeningOptions = emptyList(),
            awakeningSparks = 0,
            fatigue = 5,
            performance = HighSchoolPerformance(),
            currentGameScenarioId = null,
            currentRelationshipTarget = null,
            currentRelationshipCategory = null,
            currentGameScenario = null,
            currentRelationshipEvent = null,
            news = prologueNews(request.identity, request.lifeNumber, request.inheritedMemories.size, wind.newsLine),
            balanceVersion = HighSchoolContentCatalog.BALANCE_VERSION,
            worldRulesVersion = HighSchoolContentCatalog.WORLD_RULES_VERSION,
            rebirthEcho = request.rebirthEcho,
            trainingOpportunity = null,
            lastTraining = null,
            lastRelationship = null,
            fanInterest = wind.startingFanInterest,
            armRisk = 0,
            injuryRecovery = 0,
            automaticGames = 0,
            automaticOuts = 0,
            automaticRunsAllowed = 0,
            draftResult = null,
            legacyOptions = emptyList(),
            selectedMemories = emptyList(),
            stateCommitment = "",
        )
        return result(seed, signed(state), "high_school_career_started")
    }

    public fun completePrologue(request: AdvanceRequest): HighSchoolResult {
        val seed = validate(request.seed, request.state, HighSchoolPhase.PROLOGUE)
        val state = request.state.copy(
            revision = request.state.revision + 1UL,
            phase = HighSchoolPhase.SCHOOL_SELECTION,
        )
        return result(seed, signed(state), "middle_school_prologue_completed")
    }

    public fun chooseSchool(request: ChooseSchoolRequest): HighSchoolResult {
        val seed = validate(request.seed, request.state, HighSchoolPhase.SCHOOL_SELECTION)
        val options = HighSchoolContentCatalog.schools(request.state.identity.region)
        val school = options.firstOrNull { it.id == request.schoolId } ?: error("school.unavailable")
        val state = request.state.copy(
            revision = request.state.revision + 1UL,
            phase = HighSchoolPhase.TRAINING,
            schoolOptions = options,
            school = school,
            trainingOpportunity = trainingOpportunity(request.state.careerId, 0, request.state.fatigue, 0),
        )
        return result(seed, signed(state), "school_selected", listOf("school.${school.id.wire}"))
    }

    public fun commitTraining(request: TrainingRequest): HighSchoolResult {
        val seed = validate(request.seed, request.state, HighSchoolPhase.TRAINING)
        val state = request.state
        val school = state.school ?: error("school.required")
        val required = state.schedule.trainingsByChapter[state.chapter.number - 1]
        require(state.chapterTrainingCount < required) { "training.out_of_order" }
        val number = state.totalTrainingsCompleted + 1
        val rehab = state.injuryRecovery > 0
        val focus = if (rehab) HighSchoolTrainingFocus.RECOVERY else request.focus
        val wind = windFor(state.careerId)
        // Source: Swift CareerTrainingRules.trainingSignalBase. This is the
        // ASCII salt for "CAREER" and is part of the deterministic contract.
        val generator = SplitMix64(seed xor number.toULong() xor 0x434152454552UL)
        val opportunityHit = !rehab && state.trainingOpportunity?.focus == request.focus
        val differentiated = HighSchoolContentCatalog.BALANCE_VERSION >= 4
        val variance = trainingVariance(focus)
        val base = when (request.intensity) {
            HighSchoolTrainingIntensity.LIGHT -> 130
            HighSchoolTrainingIntensity.STANDARD -> 210
            HighSchoolTrainingIntensity.INTENSIVE -> 280
        }
        val signalBase = base +
            (if (school.strength == request.focus) 110 else 0) +
            (if (opportunityHit) 90 else 0) -
            max(0, state.fatigue - 45) * 3 +
            max(0, 16 - state.schedule.trainingTotal) * 24
        val signal = max(60, signalBase + generator.nextInt(variance * 2 + 1) - variance)
        val jackpotChance = clamp(
            (if (HighSchoolSoulBoost.TRAINING_RHYTHM in state.soulBoosts) 26 else 16) +
                if (differentiated) jackpotModifier(focus) else 0,
            0,
            40,
        )
        val jackpot = !rehab && focus != HighSchoolTrainingFocus.RECOVERY &&
            generator.nextInt(100) < jackpotChance
        var rawGrowth = if (rehab || focus == HighSchoolTrainingFocus.RECOVERY) 0 else trainingGrowth(signal)
        if (rawGrowth == 0 && number == 1 && state.lifeNumber == 1 && !rehab &&
            focus != HighSchoolTrainingFocus.RECOVERY
        ) {
            rawGrowth = 1
        }
        rawGrowth = (if (jackpot) rawGrowth * 2 else rawGrowth) +
            if (rehab) 0 else wind.trainingGrowthBonus(focus)
        val before = rating(focus, state.pitcher)
        val talentApplication = if (rawGrowth > 0) {
            applyTalent(state.talent, focus, before, rawGrowth)
        } else {
            TalentApplication(0, state.talent, false)
        }
        val pitcher = grow(state.pitcher, focus, talentApplication.allowed, request.targetPitch)
        val baseFatigue = when (request.intensity) {
            HighSchoolTrainingIntensity.LIGHT -> 3
            HighSchoolTrainingIntensity.STANDARD -> 8
            HighSchoolTrainingIntensity.INTENSIVE -> 15
        }
        val fatigue = if (rehab) {
            clamp(state.fatigue + wind.trainingFatigueModifier(focus) - wind.recoveryBonus - 24, 0, 100)
        } else {
            clamp(
                state.fatigue + baseFatigue +
                    (if (differentiated) trainingFatigueModifier(focus) else 0) +
                    wind.trainingFatigueModifier(focus) +
                    (if (request.focus == HighSchoolTrainingFocus.RECOVERY) -wind.recoveryBonus - 18 else 0),
                0, 100,
            )
        }
        val after = rating(focus, pitcher)
        val growth = after - before
        val training = HighSchoolTrainingResult(
            number = number,
            focus = focus,
            intensity = request.intensity,
            growth = growth,
            fatigueChange = fatigue - state.fatigue,
            opportunityHit = opportunityHit,
            bloomed = talentApplication.bloomed,
        )
        var next = state.copy(
            revision = state.revision + 1UL,
            pitcher = pitcher,
            talent = talentApplication.talent,
            fatigue = fatigue,
            chapterTrainingCount = state.chapterTrainingCount + 1,
            totalTrainingsCompleted = number,
            lastTraining = training,
            injuryRecovery = if (rehab) state.injuryRecovery - 1 else state.injuryRecovery,
            armRisk = if (rehab) max(0, state.armRisk - 10) else clamp(state.armRisk + trainingArmRisk(focus, request.intensity), 0, 100),
            awakeningSparks = if (talentApplication.bloomed) min(6, state.awakeningSparks + 1) else state.awakeningSparks,
        )
        next = if (next.chapterTrainingCount >= required) {
            enterMilestone(next, seed, 0)
        } else {
            next.copy(
                phase = HighSchoolPhase.TRAINING,
                trainingOpportunity = trainingOpportunity(next.careerId, next.totalTrainingsCompleted, next.fatigue, next.injuryRecovery),
            )
        }
        return result(
            seed,
            signed(next),
            if (rehab) "career_training_rehab" else "career_training_completed",
            listOf("training.${focus.wire}"),
        )
    }

    public fun resolveRelationship(request: RelationshipRequest): HighSchoolResult {
        val seed = validate(request.seed, request.state, HighSchoolPhase.RELATIONSHIP)
        val state = request.state
        if (state.currentRelationshipEvent?.id == "evt-arm-care") {
            return resolveArmCare(seed, state, request.response)
        }
        val category = state.currentRelationshipCategory ?: state.currentRelationshipTarget?.wire ?: "coach"
        val target = relationshipTargetForCategory(category)
        val impact = relationshipImpact(state, category, request.response)
        val wind = windFor(state.careerId)
        var trustChange = impact.trust + if (target == wind.favoredRelationship) wind.favoredRelationshipBonus else 0
        if (impact.trust < 0) trustChange -= wind.relationshipLossPenalty
        if (HighSchoolKarma.STUBBORN_COACH in state.karmas && target == HighSchoolRelationshipTarget.COACH) {
            trustChange = if (trustChange < 0) trustChange * 2 else trustChange / 2
        }
        var manager = state.managerTrust
        var catcher = state.catcherTrust
        var rival = state.rivalTrust
        val before = when (target) {
            HighSchoolRelationshipTarget.COACH -> manager
            HighSchoolRelationshipTarget.CATCHER -> catcher
            HighSchoolRelationshipTarget.RIVAL -> rival
        }
        when (target) {
            HighSchoolRelationshipTarget.COACH -> manager = clamp(manager + trustChange, 0, 100)
            HighSchoolRelationshipTarget.CATCHER -> catcher = clamp(catcher + trustChange, 0, 100)
            HighSchoolRelationshipTarget.RIVAL -> rival = clamp(rival + trustChange, 0, 100)
        }
        val fanChange = if (impact.fanInterest > 0) impact.fanInterest + wind.fanInterestGainBonus else impact.fanInterest
        val fanInterest = clamp(state.fanInterest + fanChange, 0, 100)
        val pitcher = impact.growthFocus?.let { grow(state.pitcher, it, 1) } ?: state.pitcher
        val after = when (target) {
            HighSchoolRelationshipTarget.COACH -> manager
            HighSchoolRelationshipTarget.CATCHER -> catcher
            HighSchoolRelationshipTarget.RIVAL -> rival
        }
        val relationship = HighSchoolRelationshipResult(
            number = state.relationshipsCompleted + 1,
            target = target,
            response = request.response,
            trustBefore = before,
            trustAfter = after,
            fatigueBefore = state.fatigue,
            fatigueAfter = clamp(state.fatigue + impact.fatigue, 0, 100),
            fanInterestBefore = state.fanInterest,
            fanInterestAfter = fanInterest,
            growthFocus = impact.growthFocus,
        )
        val next = enterMilestone(
            state.copy(
                revision = state.revision + 1UL,
                pitcher = pitcher,
                managerTrust = manager,
                catcherTrust = catcher,
                rivalTrust = rival,
                relationshipTrust = (manager + catcher + rival) / 3,
                relationshipsCompleted = state.relationshipsCompleted + 1,
                fatigue = relationship.fatigueAfter,
                fanInterest = fanInterest,
                lastRelationship = relationship,
                currentRelationshipTarget = null,
                currentRelationshipCategory = null,
                currentRelationshipEvent = null,
                recentRelationshipEventIds = (state.recentRelationshipEventIds + (state.currentRelationshipEvent?.id ?: "")).filter { it.isNotBlank() }.takeLast(8),
            ),
            seed,
            state.milestoneIndex + 1,
        )
        return result(seed, signed(next), "career_relationship_resolved", listOf("relationship.${request.response.wire}"))
    }

    /** Exact Swift arm-care branch. It is a relationship-shaped boundary, but never a generic
     * relationship impact: the three choices alter only durable health/fatigue/trust state. */
    private fun resolveArmCare(
        seed: ULong,
        state: HighSchoolState,
        response: HighSchoolRelationshipResponse,
    ): HighSchoolResult {
        val priorRisk = state.armRisk
        var nextRisk = priorRisk
        var injuryRecovery = state.injuryRecovery
        var fatigueDelta: Int
        var trustDelta: Int
        var fanDelta: Int
        var injured = false
        val event: String
        val headline: String
        when (response) {
            HighSchoolRelationshipResponse.CHALLENGE -> {
                nextRisk = clamp(priorRisk + HighSchoolContentCatalog.ARM_PUSH_THROUGH_RISK, 0, 100)
                trustDelta = -2
                fanDelta = 1
                if (nextRisk >= HighSchoolContentCatalog.ARM_INJURY_THRESHOLD) {
                    injured = true
                    val severity = if (nextRisk >= 92) 2 else 1
                    injuryRecovery = severity
                    nextRisk = 50
                    fatigueDelta = 6
                    if (HighSchoolKarma.NO_LAST_CHANCE in state.karmas) {
                        event = "팔이 버티지 못했습니다. 시즌이 여기서 끝났고, 지금까지의 기록으로 평가받습니다."
                        headline = "시즌 아웃 · ${state.pitcher.name}, 부상으로 조기 드래프트 평가에 들어갑니다."
                    } else {
                        event = "무리한 등판이 겹쳐 팔에 이상이 왔습니다. 다음 훈련 ${severity}회는 재활로 씁니다."
                        headline = "팔 부상 · ${state.pitcher.name}, 무리한 등판이 반복돼 재활에 들어갑니다."
                    }
                } else {
                    fatigueDelta = 4
                    event = "오늘도 예정대로 던졌습니다. 능력은 지켰지만 팔의 위험이 더 커졌습니다."
                    headline = "${state.pitcher.name}, 경고에도 등판을 강행했습니다 · 팔 위험 누적."
                }
            }
            HighSchoolRelationshipResponse.LISTEN -> {
                nextRisk = max(0, priorRisk - HighSchoolContentCatalog.ARM_REST_RELIEF)
                fatigueDelta = -30
                trustDelta = 2
                fanDelta = 0
                event = "이번 등판은 건너뛰고 팔을 쉬게 했습니다. 피로와 위험이 크게 줄었습니다."
                headline = "${state.pitcher.name}, 짧은 휴식으로 팔을 아꼈습니다 · 회복 우선."
            }
            HighSchoolRelationshipResponse.EXPLAIN -> {
                nextRisk = 0
                fatigueDelta = -HighSchoolContentCatalog.ARM_EXAM_RELIEF
                trustDelta = 1
                fanDelta = 0
                event = "정밀 검진 결과 큰 손상은 없었습니다. 검진 전 위험 수치는 $priorRisk, 관리 계획을 새로 세웠습니다."
                headline = "${state.pitcher.name}, 정밀 검진으로 팔 상태를 확인했습니다 · 위험 관리 시작."
            }
        }
        val wind = windFor(state.careerId)
        val adjustedTrust = trustDelta + if (wind.favoredRelationship == HighSchoolRelationshipTarget.COACH) wind.favoredRelationshipBonus else 0
        val finalTrust = if (trustDelta < 0) adjustedTrust - wind.relationshipLossPenalty else adjustedTrust
        val managerBefore = state.managerTrust
        val managerAfter = clamp(managerBefore + finalTrust, 0, 100)
        val fanAfter = clamp(state.fanInterest + if (fanDelta > 0) fanDelta + wind.fanInterestGainBonus else fanDelta, 0, 100)
        val relationship = HighSchoolRelationshipResult(
            number = state.relationshipsCompleted + 1,
            target = HighSchoolRelationshipTarget.COACH,
            response = response,
            trustBefore = managerBefore,
            trustAfter = managerAfter,
            fatigueBefore = state.fatigue,
            fatigueAfter = clamp(state.fatigue + fatigueDelta, 0, 100),
            fanInterestBefore = state.fanInterest,
            fanInterestAfter = fanAfter,
            growthFocus = null,
        )
        val base = state.copy(
            revision = state.revision + 1UL,
            relationshipsCompleted = state.relationshipsCompleted + 1,
            relationshipTrust = (managerAfter + state.catcherTrust + state.rivalTrust) / 3,
            managerTrust = managerAfter,
            fatigue = relationship.fatigueAfter,
            lastRelationship = relationship,
            fanInterest = fanAfter,
            armRisk = nextRisk,
            injuryRecovery = injuryRecovery,
            news = listOf(headline, event) + state.news,
            currentRelationshipEvent = null,
            recentRelationshipEventIds = (state.recentRelationshipEventIds + (state.currentRelationshipEvent?.id ?: "")).filter { it.isNotBlank() }.takeLast(8),
        )
        val next = if (injured && HighSchoolKarma.NO_LAST_CHANCE in state.karmas) {
            base.copy(
                phase = HighSchoolPhase.DRAFT,
                awakeningOptions = emptyList(),
                currentGameScenarioId = null,
                currentGameScenario = null,
                currentRelationshipTarget = null,
                currentRelationshipCategory = null,
                currentRelationshipEvent = null,
            )
        } else {
            enterMilestone(base, seed, state.milestoneIndex + 1)
        }
        return result(
            seed,
            signed(next),
            if (injured) "career_arm_injury" else "career_arm_care",
            listOf("arm_care.${response.wire}") + if (injured && HighSchoolKarma.NO_LAST_CHANCE in state.karmas) listOf("karma.no_last_chance") else emptyList(),
        )
    }

    public fun recordImportantGame(request: GameRequest): HighSchoolResult {
        val seed = validate(request.seed, request.state, HighSchoolPhase.IMPORTANT_GAME)
        val state = request.state
        val report = request.report
        val expected = state.performance.importantGamesCompleted + 1
        require(report.scenarioNumber == expected) { "importantGame.scenario_order" }
        require(report.pitches > 0 && report.strikeouts >= 0 && report.walks >= 0 && report.runsAllowed >= 0) {
            "importantGame.report_invalid"
        }
        require(report.recommendationAccepted in 0..report.pitches) { "importantGame.accepted_invalid" }
        val performance = state.performance.copy(
            importantGamesCompleted = expected,
            pitches = state.performance.pitches + report.pitches,
            strikeouts = state.performance.strikeouts + report.strikeouts,
            walks = state.performance.walks + report.walks,
            runsAllowed = state.performance.runsAllowed + report.runsAllowed,
            expectedDamage = state.performance.expectedDamage + report.expectedDamage,
            actualDamage = state.performance.actualDamage + report.actualDamage,
            outs = state.performance.outs + (report.outs ?: min(27, report.pitches / 5)),
            hits = state.performance.hits + (report.hits ?: 0),
        )
        val gameGrowth = applyGameGrowth(state, report)
        val wind = windFor(state.careerId)
        val fanBase = max(2, report.strikeouts * 2 - report.runsAllowed * 2)
        val riskAdd = if (report.pitches > HighSchoolContentCatalog.ARM_PITCH_FLOOR) {
            report.pitches - HighSchoolContentCatalog.ARM_PITCH_FLOOR +
                max(0, state.fatigue - HighSchoolContentCatalog.ARM_FATIGUE_FLOOR)
        } else {
            0
        }
        val sparks = min(
            6,
            state.awakeningSparks +
                (if (report.runsAllowed == 0 || report.strikeouts >= 4) 2 else 0) +
                (if (report.actualDamage <= report.expectedDamage) 1 else 0) +
                (if (gameGrowth.bloomed) 1 else 0),
        )
        val sequenceTrustReward = min(max(report.sequenceMasteryCount ?: 0, 0), 3)
        val managerTrust = if (sequenceTrustReward > 0) {
            clamp(state.managerTrust + sequenceTrustReward, 0, 100)
        } else {
            state.managerTrust
        }
        val catcherTrust = if (sequenceTrustReward > 0) {
            clamp(state.catcherTrust + sequenceTrustReward, 0, 100)
        } else {
            state.catcherTrust
        }
        val next = enterMilestone(
            state.copy(
                revision = state.revision + 1UL,
                pitcher = gameGrowth.pitcher,
                talent = gameGrowth.talent,
                performance = performance,
                relationshipTrust = (managerTrust + catcherTrust + state.rivalTrust) / 3,
                managerTrust = managerTrust,
                catcherTrust = catcherTrust,
                fanInterest = clamp(state.fanInterest + fanBase + wind.fanInterestGainBonus, 0, 100),
                armRisk = clamp(state.armRisk + riskAdd, 0, 100),
                awakeningSparks = sparks,
                fatigue = clamp(state.fatigue + max(5, report.pitches * max(60, 140 - state.pitcher.stamina) / 200), 0, 100),
                currentGameScenarioId = null,
            ),
            seed,
            state.milestoneIndex + 1,
        )
        return result(seed, signed(next), "career_important_game_completed", listOf("important_game.$expected"))
    }

    public fun chooseAwakening(request: AwakeningRequest): HighSchoolResult {
        val seed = validate(request.seed, request.state, HighSchoolPhase.AWAKENING)
        require(request.awakening in request.state.awakeningOptions && request.awakening !in request.state.selectedAwakenings) {
            "awakening.unavailable"
        }
        val pitcher = applyAwakening(request.state.pitcher, request.awakening)
        val next = enterMilestone(
            request.state.copy(
                revision = request.state.revision + 1UL,
                pitcher = pitcher,
                selectedAwakenings = request.state.selectedAwakenings + request.awakening,
                awakeningOptions = emptyList(),
                awakeningSparks = 0,
            ),
            seed,
            request.state.milestoneIndex + 1,
        )
        return result(seed, signed(next), "career_awakening_selected", listOf("awakening.${request.awakening.wire}"))
    }

    public fun advanceChapter(request: AdvanceRequest): HighSchoolResult {
        val seed = validate(request.seed, request.state, HighSchoolPhase.CHAPTER_REVIEW)
        val state = request.state
        require(state.chapter.number < HighSchoolContentCatalog.chapters.size) { "chapter.final" }
        val automaticLines = automaticOuting.simulate(state, state.chapter, seed)
        require(automaticLines.size == 2) { "automaticGame.incomplete" }
        val automaticOuts = state.automaticOuts + automaticLines.sumOf { it.outs }
        val automaticRuns = state.automaticRunsAllowed + automaticLines.sumOf { it.runsAllowed }
        val nextChapter = HighSchoolContentCatalog.chapters[state.chapter.number]
        val next = state.copy(
            revision = state.revision + 1UL,
            phase = HighSchoolPhase.TRAINING,
            chapter = nextChapter,
            chapterTrainingCount = 0,
            milestoneIndex = 0,
            trainingOpportunity = trainingOpportunity(state.careerId, state.totalTrainingsCompleted, state.fatigue, state.injuryRecovery),
            automaticGames = state.automaticGames + automaticLines.size,
            automaticOuts = automaticOuts,
            automaticRunsAllowed = automaticRuns,
        )
        return result(seed, signed(next), "career_chapter_advanced", listOf("chapter.${nextChapter.number}"))
    }

    public fun resolveDraft(request: AdvanceRequest): HighSchoolResult {
        val seed = validate(request.seed, request.state, HighSchoolPhase.DRAFT)
        val state = request.state
        // Current Swift HighSchoolCareerEngine.resolveDraft uses the fixed-width v4 salt
        // 0x4452_4146_5400; keep the trailing byte rather than the legacy shortened salt.
        val generator = SplitMix64(seed xor 0x445241465400UL)
        val variance = when (generator.nextInt(5)) {
            0 -> -1
            4 -> 1
            else -> 0
        }
        val score = clamp(draftScore(state) + variance, 20, 95)
        val threshold = draftThreshold(state)
        val drafted = score >= threshold
        val team = if (drafted) HighSchoolDraftTeamRules.bestTeam(state.pitcher) else null
        val round = if (!drafted) null else when {
            score >= 78 -> 1
            score >= 70 -> 2
            else -> 4
        }
        val overallPick = round?.let { (it - 1) * 10 + generator.nextInt(10) + 1 }
        val draft = HighSchoolDraftResult(
            outcome = if (drafted) HighSchoolDraftOutcome.DRAFTED else HighSchoolDraftOutcome.UNDRAFTED,
            evaluationScore = score,
            projectedRange = when {
                !drafted -> "미지명"
                score >= 78 -> "1라운드"
                score >= 70 -> "2~3라운드"
                else -> "4~6라운드"
            },
            teamId = team?.id,
            team = team,
            round = round,
            overallPick = overallPick,
            signingBonus = round?.let { max(40_000_000, 300_000_000 - it * 45_000_000) },
            firstSeasonGoal = team?.let { "퓨처스 선발 10경기와 볼넷률 8% 이하" },
            evaluationBreakdown = draftEvaluationBreakdown(state),
            summary = if (drafted) {
                "지명 구단 · ${team?.name ?: "프로 구단"}. 구위와 고교 경기 기록에서 높은 평가를 받았습니다."
            } else {
                "마지막 라운드까지 이름이 불리지 않았습니다. 다음 선수에게 남길 기록을 고르세요."
            },
        )
        val next = state.copy(
            revision = state.revision + 1UL,
            phase = if (drafted) HighSchoolPhase.COMPLETED else HighSchoolPhase.LEGACY,
            draftResult = draft,
            legacyOptions = memoryOptions(state, seed, drafted),
        )
        return result(seed, signed(next), "career_draft_resolved", listOf("draft.${draft.outcome.wire}"))
    }

    public fun openLegacy(request: AdvanceRequest): HighSchoolResult {
        val seed = validate(request.seed, request.state, HighSchoolPhase.COMPLETED)
        require(request.state.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED) { "legacy.drafted_required" }
        val next = request.state.copy(revision = request.state.revision + 1UL, phase = HighSchoolPhase.LEGACY)
        return result(seed, signed(next), "career_legacy_opened", listOf("legacy.opened"))
    }

    public fun selectLegacy(request: LegacyRequest): HighSchoolResult {
        val seed = validate(request.seed, request.state, HighSchoolPhase.LEGACY)
        val unique = request.memoryCards.distinct()
        if (request.signatureLegacyId == null) {
            require(unique.size == request.state.memorySlots && unique.all { it in request.state.legacyOptions }) {
                "legacy.memory_selection_invalid"
            }
        } else {
            require(unique.isEmpty()) { "legacy.signature_memory_mixed" }
            require(request.signatureLegacyId in request.state.legacyOptions) { "legacy.signature_unknown" }
        }
        val next = request.state.copy(
            revision = request.state.revision + 1UL,
            phase = HighSchoolPhase.COMPLETED,
            selectedMemories = unique,
            legacyOptions = if (request.signatureLegacyId == null) request.state.legacyOptions else listOf(request.signatureLegacyId),
        )
        return result(
            seed,
            signed(next),
            "career_legacy_selected",
            if (request.signatureLegacyId == null) unique.map { "memory.$it" } else listOf("signature.${request.signatureLegacyId}"),
        )
    }

    public fun availableAwakenings(state: HighSchoolState): List<HighSchoolAwakening> {
        val taken = state.selectedAwakenings.toSet()
        val canLeap = state.awakeningSparks >= 3
        return HighSchoolContentCatalog.awakeningNodes.mapNotNull { node ->
            if (node.id in taken) return@mapNotNull null
            val unmet = node.parents.filterNot { it in taken }
            if (unmet.isEmpty()) return@mapNotNull node.id
            if (canLeap && unmet.size == 1 && taken.any { selected ->
                    HighSchoolContentCatalog.awakeningNodes.first { it.id == selected }.branch == node.branch
                }
            ) node.id else null
        }
    }

    public fun inheritancePointCap(points: Int, rulesVersion: Int = 1): Int = if (rulesVersion == 1) {
        min(20, 8 + max(0, points) / 60)
    } else {
        min(20, max(1, (max(0, points) - 20) / 4))
    }

    public fun appliedInheritance(points: Int, rulesVersion: Int = 1): Int =
        min(max(0, points), inheritancePointCap(points, rulesVersion))

    /**
     * Verifies a state restored from a durable boundary without advancing the career.
     * Persistence owns the bytes; the kernel remains the only authority for the commitment.
     */
    public fun validateSavedState(state: HighSchoolState) {
        require(state.stateCommitment.isNotBlank() && state.stateCommitment == commitment(state)) {
            "state.commitment"
        }
    }

    /** Re-signs an additive Phase 4 shadow projection; callers validate the prior snapshot first. */
    public fun resignShadowState(state: HighSchoolState): HighSchoolState = signed(state)

    private fun enterMilestone(state: HighSchoolState, seed: ULong, index: Int): HighSchoolState {
        val phases = state.schedule.milestonesByChapter[state.chapter.number - 1].toMutableList()
        if (state.chapter.number == 8) phases += HighSchoolPhase.DRAFT
        val phase = phases.getOrNull(index) ?: HighSchoolPhase.CHAPTER_REVIEW
        val relationshipEvent = if (phase == HighSchoolPhase.RELATIONSHIP) relationshipEventFor(state, seed) else null
        val gameScenario = if (phase == HighSchoolPhase.IMPORTANT_GAME) gameScenario(state) else null
        val next = state.copy(
            phase = phase,
            milestoneIndex = index,
            awakeningOptions = if (phase == HighSchoolPhase.AWAKENING) availableAwakenings(state) else emptyList(),
            currentGameScenarioId = gameScenario?.id,
            currentGameScenario = gameScenario,
            currentRelationshipEvent = relationshipEvent,
            currentRelationshipCategory = relationshipEvent?.category,
            currentRelationshipTarget = relationshipEvent?.let { relationshipTargetForCategory(it.category) },
            trainingOpportunity = null,
        )
        return if (phase == HighSchoolPhase.CHAPTER_REVIEW) {
            next.copy(
                currentGameScenarioId = null,
                currentGameScenario = null,
                currentRelationshipEvent = null,
                currentRelationshipTarget = null,
                currentRelationshipCategory = null,
            )
        } else {
            next
        }
    }

    private fun relationshipEventFor(state: HighSchoolState, seed: ULong): HighSchoolRelationshipEvent {
        if (state.relationshipsCompleted >= 3 && state.armRisk >= HighSchoolContentCatalog.ARM_WARNING_THRESHOLD && state.injuryRecovery == 0) {
            return HighSchoolContentCatalog.relationshipEvents.first { it.id == "evt-arm-care" }
        }
        val slot = state.relationshipsCompleted
        if (slot < CORE_RELATIONSHIP_CATEGORIES.size) {
            val order = CORE_RELATIONSHIP_CATEGORIES.toMutableList()
            val generator = SplitMix64(hashValue("core_order|${state.careerId}"))
            for (index in order.lastIndex downTo 1) {
                val swap = generator.nextInt(index + 1)
                val value = order[index]
                order[index] = order[swap]
                order[swap] = value
            }
            val category = order[slot]
            val candidates = HighSchoolContentCatalog.events.filter { it.category == category }
            val rotation = (state.lifeNumber - 1).coerceAtLeast(0) % candidates.size
            return candidates[((seed % candidates.size.toULong()).toInt() + rotation) % candidates.size]
        }
        if (state.lifeNumber > 1) {
            val rebirthGenerator = SplitMix64(hashValue("rebirth_event|${state.careerId}|$slot"))
            val extendedSlot = slot - CORE_RELATIONSHIP_CATEGORIES.size
            val extendedSlotCount = max(1, state.schedule.milestonesByChapter.flatten().count { it == HighSchoolPhase.RELATIONSHIP } - CORE_RELATIONSHIP_CATEGORIES.size)
            val guaranteeGenerator = SplitMix64(hashValue("rebirth_guarantee|${state.careerId}"))
            val guaranteedSlot = guaranteeGenerator.nextInt(extendedSlotCount)
            if (extendedSlot == guaranteedSlot || rebirthGenerator.nextInt(3) == 0) {
                val eligible = HighSchoolContentCatalog.prioritizedRebirthEvents(
                    HighSchoolContentCatalog.eligibleRebirthEvents(state.rebirthEcho),
                    state.rebirthEcho?.recentEventIds.orEmpty(),
                )
                if (eligible.isNotEmpty()) return eligible[rebirthGenerator.nextInt(eligible.size)]
            }
        }
        val categories = EXTENDED_RELATIONSHIP_CATEGORIES.toMutableList()
        val generator = SplitMix64(hashValue("relationship_pool|${state.careerId}"))
        for (index in categories.lastIndex downTo 1) {
            val swap = generator.nextInt(index + 1)
            val value = categories[index]
            categories[index] = categories[swap]
            categories[swap] = value
        }
        val category = categories[(slot - CORE_RELATIONSHIP_CATEGORIES.size) % categories.size]
        val candidates = HighSchoolContentCatalog.events.filter { it.category == category }
        return candidates[(generator.next() % candidates.size.toULong()).toInt()]
    }

    private fun gameScenario(state: HighSchoolState): HighSchoolGameScenario {
        if (state.chapter.number == 8) return HighSchoolContentCatalog.scenarios.first { it.id == "game-one-run" }
        if (state.chapter.number == 4) return HighSchoolContentCatalog.scenarios.first { it.id == "game-national-final" }
        val pool = HighSchoolContentCatalog.scenarios.filter { it.minChapter <= 1 }
        val base = (hashValue("game_scenario|${state.careerId}") % pool.size.toULong()).toInt()
        return pool[(base + state.performance.importantGamesCompleted * 7) % pool.size]
    }

    private fun relationshipEventCategory(state: HighSchoolState, seed: ULong): String = relationshipEventFor(state, seed).category

    private fun relationshipTargetForCategory(category: String): HighSchoolRelationshipTarget = when (category) {
        "coach", "health", "team", "draft", "media", "life", "legacy" -> HighSchoolRelationshipTarget.COACH
        "catcher", "growth", "game", "awakening", "fan" -> HighSchoolRelationshipTarget.CATCHER
        "rival" -> HighSchoolRelationshipTarget.RIVAL
        else -> HighSchoolRelationshipTarget.COACH
    }

    private fun relationshipTarget(state: HighSchoolState): HighSchoolRelationshipTarget {
        return state.currentRelationshipCategory?.let(::relationshipTargetForCategory)
            ?: relationshipTargetForCategory(relationshipEventCategory(state, 0UL))
    }

    private fun legacyRelationshipTarget(state: HighSchoolState): HighSchoolRelationshipTarget {
        val values = mutableListOf(
            HighSchoolRelationshipTarget.COACH,
            HighSchoolRelationshipTarget.CATCHER,
            HighSchoolRelationshipTarget.RIVAL,
        )
        val generator = SplitMix64(hashValue("core_order|${state.careerId}"))
        for (index in 2 downTo 1) {
            val swap = generator.nextInt(index + 1)
            val value = values[index]
            values[index] = values[swap]
            values[swap] = value
        }
        return values[state.relationshipsCompleted.coerceAtMost(2)]
    }

    private fun trainingOpportunity(
        careerId: String,
        index: Int,
        fatigue: Int,
        injuryRecovery: Int,
    ): HighSchoolTrainingOpportunity {
        val focuses = HighSchoolTrainingFocus.entries
        val seed = hashValue("$careerId|opportunity|$index")
        val recoveryEarned = fatigue >= HighSchoolContentCatalog.RECOVERY_OPPORTUNITY_FATIGUE || injuryRecovery > 0
        fun skipRecovery(start: Int): Int {
            if (recoveryEarned) return start
            var candidate = start
            var steps = 0
            while (focuses[candidate] == HighSchoolTrainingFocus.RECOVERY && steps < focuses.size) {
                candidate = (candidate + 1) % focuses.size
                steps++
            }
            return candidate
        }
        var pick = skipRecovery((seed % focuses.size.toULong()).toInt())
        if (index > 0) {
            val previous = hashValue("$careerId|opportunity|${index - 1}")
            val previousPick = skipRecovery((previous % focuses.size.toULong()).toInt())
            if (pick == previousPick) pick = skipRecovery((pick + 1) % focuses.size)
        }
        val focus = focuses[pick]
        val reasons = OPPORTUNITY_REASONS.getValue(focus)
        val reason = reasons[((seed shr 8) % reasons.size.toULong()).toInt()]
        return HighSchoolTrainingOpportunity(focus, reason)
    }

    private fun applyTalent(
        talent: HighSchoolTalent,
        focus: HighSchoolTrainingFocus,
        current: Int,
        points: Int,
    ): TalentApplication {
        val grade = talent.grade(focus)
        val allowed = max(0, min(points, grade.ceiling - current))
        if (allowed >= points || grade == HighSchoolTalentGrade.S) return TalentApplication(allowed, talent, false)
        val next = when (grade) {
            HighSchoolTalentGrade.D -> HighSchoolTalentGrade.C
            HighSchoolTalentGrade.C -> HighSchoolTalentGrade.B
            HighSchoolTalentGrade.B -> HighSchoolTalentGrade.A
            HighSchoolTalentGrade.A -> HighSchoolTalentGrade.S
            HighSchoolTalentGrade.S -> null
        } ?: return TalentApplication(allowed, talent, false)
        val pressure = talent.pressure(focus) + 1
        return if (pressure >= grade.bloomThreshold) {
            TalentApplication(allowed, talent.withGrade(focus, next).withPressure(focus, 0), true)
        } else {
            TalentApplication(allowed, talent.withPressure(focus, pressure), false)
        }
    }

    /** Pure port of CareerGameGrowth.evaluating plus its single-point application. */
    private fun applyGameGrowth(state: HighSchoolState, report: HighSchoolGameReport): GameGrowthApplication {
        if (HighSchoolContentCatalog.BALANCE_VERSION < 4) return GameGrowthApplication(state.pitcher, state.talent, false)
        val focus = when {
            report.strikeouts >= 2 && report.runsAllowed <= 1 && report.actualDamage <= report.expectedDamage ->
                if (state.pitcher.stuff >= state.pitcher.movement) HighSchoolTrainingFocus.VELOCITY else HighSchoolTrainingFocus.BREAKING_BALL
            report.outs == 3 && report.pitches >= 9 && report.runsAllowed <= 1 && report.actualDamage <= report.expectedDamage ->
                HighSchoolTrainingFocus.STAMINA
            (report.sequenceMasteryCount ?: 0) >= 4 && report.walks == 0 && report.actualDamage <= report.expectedDamage ->
                HighSchoolTrainingFocus.COMMAND
            else -> null
        } ?: return GameGrowthApplication(state.pitcher, state.talent, false)
        val abilityBefore = rating(focus, state.pitcher)
        val applied = applyTalent(state.talent, focus, abilityBefore, 1)
        return GameGrowthApplication(
            pitcher = grow(state.pitcher, focus, applied.allowed),
            talent = applied.talent,
            bloomed = applied.bloomed,
        )
    }

    private fun makeTalent(careerId: String): HighSchoolTalent {
        val generator = SplitMix64(hashValue("talent|$careerId"))
        val grades = MutableList(4) { drawTalentGrade(generator) }
        if (grades.none { it >= HighSchoolTalentGrade.B }) {
            grades[generator.nextInt(4)] = if (generator.nextInt(2) == 0) HighSchoolTalentGrade.B else HighSchoolTalentGrade.A
        }
        if (grades.none { it <= HighSchoolTalentGrade.C }) {
            grades[generator.nextInt(4)] = if (generator.nextInt(2) == 0) HighSchoolTalentGrade.C else HighSchoolTalentGrade.D
        }
        return HighSchoolTalent(grades[0], grades[1], grades[2], grades[3])
    }

    private fun raiseLowestTalent(talent: HighSchoolTalent): HighSchoolTalent {
        val candidates = listOf(
            HighSchoolTrainingFocus.VELOCITY to talent.stuff,
            HighSchoolTrainingFocus.COMMAND to talent.command,
            HighSchoolTrainingFocus.BREAKING_BALL to talent.movement,
            HighSchoolTrainingFocus.STAMINA to talent.stamina,
        )
        val focus = candidates.minBy { it.second.ordinal }.first
        val grade = talent.grade(focus)
        val next = when (grade) {
            HighSchoolTalentGrade.D -> HighSchoolTalentGrade.C
            HighSchoolTalentGrade.C -> HighSchoolTalentGrade.B
            HighSchoolTalentGrade.B -> HighSchoolTalentGrade.A
            HighSchoolTalentGrade.A -> HighSchoolTalentGrade.S
            HighSchoolTalentGrade.S -> HighSchoolTalentGrade.S
        }
        return talent.withGrade(focus, next)
    }

    private fun drawTalentGrade(generator: SplitMix64): HighSchoolTalentGrade = when (generator.nextInt(100)) {
        in 0..17 -> HighSchoolTalentGrade.D
        in 18..44 -> HighSchoolTalentGrade.C
        in 45..74 -> HighSchoolTalentGrade.B
        in 75..92 -> HighSchoolTalentGrade.A
        else -> HighSchoolTalentGrade.S
    }

    private fun applyCreation(pitcher: HighSchoolPitcher, allocation: HighSchoolAllocation): HighSchoolPitcher {
        var value = grow(pitcher, HighSchoolTrainingFocus.VELOCITY, allocation.stuff)
        value = grow(value, HighSchoolTrainingFocus.COMMAND, allocation.command)
        value = grow(value, HighSchoolTrainingFocus.BREAKING_BALL, allocation.movement)
        return grow(value, HighSchoolTrainingFocus.STAMINA, allocation.stamina)
    }

    private fun basePitcher(presetId: String, name: String, hand: String): HighSchoolPitcher {
        val power = listOf(
            profile(PitchKind.FOUR_SEAM, PitchUsageRole.PRIMARY, 1410, 35, 32, 37, 45, 41, 2),
            profile(PitchKind.SLIDER, PitchUsageRole.SECONDARY, 1240, 31, 29, 40, 41, 38, 2),
            profile(PitchKind.CURVEBALL, PitchUsageRole.SECONDARY, 1090, 27, 26, 38, 33, 35, 2),
            profile(PitchKind.CHANGEUP, PitchUsageRole.DEVELOPMENT, 1210, 23, 22, 31, 28, 31, 2),
        )
        val command = listOf(
            profile(PitchKind.FOUR_SEAM, PitchUsageRole.PRIMARY, 1340, 45, 44, 34, 33, 39, 1),
            profile(PitchKind.SLIDER, PitchUsageRole.SECONDARY, 1190, 41, 42, 39, 37, 40, 1),
            profile(PitchKind.CURVEBALL, PitchUsageRole.DEVELOPMENT, 1060, 31, 33, 37, 29, 34, 2),
            profile(PitchKind.CHANGEUP, PitchUsageRole.SECONDARY, 1210, 43, 44, 39, 36, 42, 1),
        )
        val movement = listOf(
            profile(PitchKind.FOUR_SEAM, PitchUsageRole.SECONDARY, 1360, 38, 35, 34, 33, 37, 1),
            profile(PitchKind.SLIDER, PitchUsageRole.PRIMARY, 1220, 39, 40, 46, 44, 45, 2),
            profile(PitchKind.CURVEBALL, PitchUsageRole.SECONDARY, 1080, 37, 39, 45, 41, 46, 2),
            profile(PitchKind.CHANGEUP, PitchUsageRole.DEVELOPMENT, 1200, 31, 33, 41, 38, 41, 2),
        )
        val stamina = listOf(
            profile(PitchKind.FOUR_SEAM, PitchUsageRole.PRIMARY, 1370, 41, 40, 34, 32, 39, 0),
            profile(PitchKind.SLIDER, PitchUsageRole.SECONDARY, 1200, 38, 40, 37, 33, 39, 1),
            profile(PitchKind.CURVEBALL, PitchUsageRole.DEVELOPMENT, 1060, 33, 32, 35, 28, 34, 1),
            profile(PitchKind.CHANGEUP, PitchUsageRole.SECONDARY, 1210, 40, 41, 39, 34, 43, 0),
        )
        val id = when (presetId) {
            "power_prospect" -> "pitcher-power"
            "precision_commander" -> "pitcher-command"
            "breaking_ball_artist" -> "pitcher-artist"
            else -> "pitcher-stamina"
        }
        val presetProfiles = when (presetId) {
            "precision_commander" -> command
            "breaking_ball_artist" -> movement
            else -> stamina.takeIf { presetId == "innings_eater" } ?: power
        }.map { source ->
            if (presetId == "innings_eater") source.copy(
                control = (source.control - 4).coerceAtLeast(20),
                command = (source.command - 4).coerceAtLeast(20),
            ) else source
        }
        val scalar = when (presetId) {
            "precision_commander" -> intArrayOf(34, 43, 35, 38)
            "breaking_ball_artist" -> intArrayOf(37, 34, 44, 35)
            "innings_eater" -> intArrayOf(37, 32, 37, 44)
            else -> intArrayOf(42, 34, 36, 38)
        }
        return HighSchoolPitcher(
            id = id,
            name = name,
            stuff = scalar[0],
            command = scalar[1],
            movement = scalar[2],
            stamina = scalar[3],
            pitchProfiles = presetProfiles,
            throwingHand = if (hand.lowercase() == "left") ThrowingHand.LEFT else ThrowingHand.RIGHT,
        )
    }

    private fun profile(
        type: PitchKind,
        role: PitchUsageRole,
        velocity: Int,
        control: Int,
        command: Int,
        movement: Int,
        whiff: Int,
        weakContact: Int,
        fatigueCost: Int,
    ): PitchProfileSnapshot = PitchProfileSnapshot(
        pitchType = type,
        role = role,
        velocityTenthsKph = velocity,
        control = control,
        command = command,
        movement = movement,
        whiff = whiff,
        weakContact = weakContact,
        fatigueCost = fatigueCost,
    )

    private fun applyInheritance(
        pitcher: HighSchoolPitcher,
        points: Int,
        domain: HighSchoolSoulDomain?,
        memories: List<String>,
        talent: HighSchoolTalent,
        rulesVersion: Int,
        bonusPoints: Int,
    ): InheritanceApplication {
        // Swift resolves unknown or absent stored values to v1. A future wire value must not
        // silently opt a shadow run into a different economy.
        val resolvedRulesVersion = if (rulesVersion == 2) 2 else 1
        var remaining = appliedInheritance(points, resolvedRulesVersion) + max(0, bonusPoints)
        var value = pitcher
        var updatedTalent = talent
        fun headroom(focus: HighSchoolTrainingFocus): Boolean = rating(focus, value) < talent.grade(focus).ceiling
        if (domain != null && remaining > 0) {
            val focus = when (domain) {
                HighSchoolSoulDomain.BODY -> HighSchoolTrainingFocus.VELOCITY
                HighSchoolSoulDomain.TECHNIQUE -> HighSchoolTrainingFocus.COMMAND
                HighSchoolSoulDomain.GAME -> HighSchoolTrainingFocus.GAME_PLANNING
            }
            var share = remaining / 2
            while (share > 0 && headroom(focus)) {
                value = grow(value, focus, 1)
                share--
                remaining--
            }
        }
        val rotation = listOf(
            HighSchoolTrainingFocus.VELOCITY,
            HighSchoolTrainingFocus.COMMAND,
            HighSchoolTrainingFocus.BREAKING_BALL,
            HighSchoolTrainingFocus.STAMINA,
        )
        while (remaining > 0) {
            val lowest = rotation.filter(::headroom).minByOrNull { rating(it, value) } ?: break
            value = grow(value, lowest, 1)
            remaining--
        }
        // Source rule: points that hit an ability wall are retained as pre-bloom pressure,
        // four points at a time. This belongs to the durable talent state, not the pitcher.
        if (remaining >= 4) {
            val target = listOf(
                HighSchoolTrainingFocus.VELOCITY,
                HighSchoolTrainingFocus.COMMAND,
                HighSchoolTrainingFocus.BREAKING_BALL,
                HighSchoolTrainingFocus.STAMINA,
            ).minWithOrNull(compareBy<HighSchoolTrainingFocus> { updatedTalent.grade(it).ceiling }
                .thenBy { updatedTalent.pressure(it) })
            if (target != null) {
                val knocks = remaining / 4
                val capped = min(
                    updatedTalent.grade(target).bloomThreshold - 1,
                    updatedTalent.pressure(target) + knocks,
                )
                updatedTalent = updatedTalent.withPressure(
                    target,
                    max(updatedTalent.pressure(target), capped),
                )
            }
        }
        memories.forEach { memory ->
            value = when (memory) {
                "velocity_blueprint" -> tune(value, stuff = 2, command = -1, pitch = PitchKind.FOUR_SEAM, velocity = 10, whiff = 2)
                "fingertip_memory" -> tune(value, movement = 2, stamina = -1, nonFastball = true, profileMovement = 3, whiff = 2)
                "catcher_notebook" -> tune(value, command = 2, profileCommand = 1, weakContact = 2)
                "rival_notebook" -> tune(value, command = 1, movement = 1, nonFastball = true, whiff = 2)
                "recovery_routine" -> tune(value, stamina = 2, fatigueCost = -1)
                "pressure_rehearsal" -> tune(value, command = 1, stamina = 1, control = 2)
                "first_pitch_map" -> tune(value, command = 2, stamina = -1, control = 2)
                "two_strike_sequence" -> tune(value, movement = 2, stamina = -1, nonFastball = true, whiff = 3)
                "fatigue_diary" -> tune(value, stamina = 2, control = 1, fatigueCost = -1)
                "mechanics_video" -> tune(value, stuff = -1, command = 2, control = 3)
                "school_playbook" -> tune(value, command = 1, movement = 1, profileCommand = 1)
                "coach_letter" -> tune(value, command = 1, stamina = 1)
                "draft_report" -> tune(value, stuff = 1, command = 1)
                "stadium_echo" -> tune(value, stuff = 2, command = -1, whiff = 1)
                "team_first_promise" -> tune(value, command = 1, stamina = 1, weakContact = 2)
                "failure_scorebook" -> tune(value, command = 2, movement = 1, stamina = -1)
                "winter_program" -> tune(value, stuff = 1, stamina = 2, fatigueCost = -1)
                "bullpen_compass" -> tune(value, stuff = 1, stamina = 1, fatigueCost = -1)
                else -> value
            }
        }
        return InheritanceApplication(value, updatedTalent)
    }

    private fun applyAwakening(pitcher: HighSchoolPitcher, awakening: HighSchoolAwakening): HighSchoolPitcher {
        // Source: HighSchoolCareer.applyAwakening (current Swift). Keep the profile-level
        // deltas together with the scalar trade-offs; the automatic PitchKernel path consumes
        // these profiles in the next chapter.
        return when (awakening) {
            HighSchoolAwakening.EXPLOSIVE_FASTBALL -> tune(pitcher, stuff = 4, command = -2, pitch = PitchKind.FOUR_SEAM, velocity = 15, whiff = 5, fatigueCost = 1)
            HighSchoolAwakening.RISING_FOUR_SEAM -> tune(pitcher, stuff = 3, movement = -1, pitch = PitchKind.FOUR_SEAM, profileMovement = 4, whiff = 6, weakContact = 2)
            HighSchoolAwakening.PINPOINT_EDGE -> tune(pitcher, stuff = -1, command = 4, control = 2, profileCommand = 3)
            HighSchoolAwakening.BATTERY_SYNC -> tune(pitcher, command = 2, movement = 1, control = 2, profileCommand = 2, weakContact = 3)
            HighSchoolAwakening.REPEATABLE_RELEASE -> tune(pitcher, stuff = -1, command = 4, control = 3, profileCommand = 2)
            HighSchoolAwakening.FIRST_PITCH_STRIKE -> tune(pitcher, command = 3, stamina = -1, control = 3)
            HighSchoolAwakening.DISAPPEARING_BREAKER -> tune(pitcher, command = -1, movement = 4, nonFastball = true, profileMovement = 4, whiff = 5)
            HighSchoolAwakening.SINKER_TUNNEL -> tune(pitcher, movement = 3, pitchSet = setOf(PitchKind.FOUR_SEAM, PitchKind.CHANGEUP), profileMovement = 3, weakContact = 5)
            HighSchoolAwakening.FROZEN_CHANGEUP -> tune(pitcher, movement = 3, stamina = -1, pitch = PitchKind.CHANGEUP, profileMovement = 6, whiff = 7)
            HighSchoolAwakening.SWEEPING_SLIDER -> tune(pitcher, command = -1, movement = 4, pitch = PitchKind.SLIDER, profileMovement = 7, whiff = 6)
            HighSchoolAwakening.CURVEBALL_CLOCK -> tune(pitcher, movement = 4, stamina = -1, pitch = PitchKind.CURVEBALL, profileMovement = 7, whiff = 5)
            HighSchoolAwakening.IRON_ARM -> tune(pitcher, movement = -1, stamina = 5, fatigueCost = -2)
            HighSchoolAwakening.LATE_INNING_RESERVE -> tune(pitcher, stamina = 4, pitch = PitchKind.FOUR_SEAM, whiff = 2, fatigueCost = -2)
            HighSchoolAwakening.CALM_UNDER_PRESSURE -> tune(pitcher, command = 2, stamina = 1, control = 2, profileCommand = 2)
            HighSchoolAwakening.PICKOFF_RHYTHM -> tune(pitcher, command = 1, stamina = 2, control = 1, weakContact = 1)
            HighSchoolAwakening.TWO_STRIKE_PLAN -> tune(pitcher, command = 2, movement = 2, stamina = -1, nonFastball = true, whiff = 3)
            HighSchoolAwakening.TRAFFIC_CONTROLLER -> tune(pitcher, stuff = -1, command = 2, stamina = 2, weakContact = 3)
            HighSchoolAwakening.SCOUT_COMPOSURE -> tune(pitcher, stuff = 2, command = 2, stamina = -1, control = 1)
        }
    }

    private fun relationshipImpact(
        state: HighSchoolState,
        category: String,
        response: HighSchoolRelationshipResponse,
    ): RelationshipImpact {
        // v4 changed listen for the two core staff channels into a deliberately neutral,
        // source-backed trust step. Keep the older archetype matrix for other responses and
        // pre-v4 save replay.
        if (HighSchoolContentCatalog.BALANCE_VERSION >= 4 &&
            response == HighSchoolRelationshipResponse.LISTEN &&
            category in setOf("coach", "catcher")
        ) {
            return RelationshipImpact(4, 0, 0, null)
        }
        val archetype = when (category) {
            "coach" -> state.school?.coachArchetype
            "catcher" -> state.school?.catcherArchetype
            "rival" -> state.rival.archetype
            else -> null
        }
        if (category == "rival") {
            return when (response) {
                HighSchoolRelationshipResponse.LISTEN -> RelationshipImpact(3, 0, 1, HighSchoolTrainingFocus.GAME_PLANNING)
                HighSchoolRelationshipResponse.EXPLAIN -> RelationshipImpact(1, 0, 3, HighSchoolTrainingFocus.COMMAND)
                HighSchoolRelationshipResponse.CHALLENGE -> RelationshipImpact(-1, 2, 7, HighSchoolTrainingFocus.BREAKING_BALL)
            }
        }
        return when (category) {
            "coach" -> when (archetype to response) {
                "원칙형" to HighSchoolRelationshipResponse.LISTEN -> RelationshipImpact(8, 0, 0, HighSchoolTrainingFocus.STAMINA)
                "원칙형" to HighSchoolRelationshipResponse.EXPLAIN -> RelationshipImpact(2, 0, 0, HighSchoolTrainingFocus.COMMAND)
                "원칙형" to HighSchoolRelationshipResponse.CHALLENGE -> RelationshipImpact(if (state.fatigue < 45) 5 else -7, 6, 2, if (state.fatigue < 45) HighSchoolTrainingFocus.VELOCITY else null)
                "분석형" to HighSchoolRelationshipResponse.LISTEN -> RelationshipImpact(3, 0, 0, null)
                "분석형" to HighSchoolRelationshipResponse.EXPLAIN -> RelationshipImpact(8, 0, 0, HighSchoolTrainingFocus.GAME_PLANNING)
                "분석형" to HighSchoolRelationshipResponse.CHALLENGE -> RelationshipImpact(-4, 4, 2, HighSchoolTrainingFocus.VELOCITY)
                "승부형" to HighSchoolRelationshipResponse.LISTEN -> RelationshipImpact(2, 0, 0, null)
                "승부형" to HighSchoolRelationshipResponse.EXPLAIN -> RelationshipImpact(4, 0, 1, HighSchoolTrainingFocus.COMMAND)
                "승부형" to HighSchoolRelationshipResponse.CHALLENGE -> RelationshipImpact(8, 6, 4, HighSchoolTrainingFocus.VELOCITY)
                "육성형" to HighSchoolRelationshipResponse.LISTEN -> RelationshipImpact(6, -2, 0, HighSchoolTrainingFocus.BREAKING_BALL)
                "육성형" to HighSchoolRelationshipResponse.EXPLAIN -> RelationshipImpact(7, 0, 0, HighSchoolTrainingFocus.COMMAND)
                "육성형" to HighSchoolRelationshipResponse.CHALLENGE -> RelationshipImpact(1, 4, 2, HighSchoolTrainingFocus.VELOCITY)
                else -> RelationshipImpact(2, 0, 0, null)
            }
            "catcher" -> when (archetype to response) {
                "안정형" to HighSchoolRelationshipResponse.LISTEN -> RelationshipImpact(8, 0, 0, HighSchoolTrainingFocus.GAME_PLANNING)
                "안정형" to HighSchoolRelationshipResponse.EXPLAIN -> RelationshipImpact(4, 0, 0, HighSchoolTrainingFocus.COMMAND)
                "안정형" to HighSchoolRelationshipResponse.CHALLENGE -> RelationshipImpact(-4, 2, 1, null)
                "분석형" to HighSchoolRelationshipResponse.LISTEN -> RelationshipImpact(4, 0, 0, null)
                "분석형" to HighSchoolRelationshipResponse.EXPLAIN -> RelationshipImpact(8, 0, 0, HighSchoolTrainingFocus.GAME_PLANNING)
                "분석형" to HighSchoolRelationshipResponse.CHALLENGE -> RelationshipImpact(2, 2, 2, HighSchoolTrainingFocus.BREAKING_BALL)
                "공격형" to HighSchoolRelationshipResponse.LISTEN -> RelationshipImpact(2, 0, 0, null)
                "공격형" to HighSchoolRelationshipResponse.EXPLAIN -> RelationshipImpact(4, 0, 1, HighSchoolTrainingFocus.COMMAND)
                "공격형" to HighSchoolRelationshipResponse.CHALLENGE -> RelationshipImpact(8, 3, 4, HighSchoolTrainingFocus.VELOCITY)
                "공감형" to HighSchoolRelationshipResponse.LISTEN -> RelationshipImpact(7, -2, 0, HighSchoolTrainingFocus.BREAKING_BALL)
                "공감형" to HighSchoolRelationshipResponse.EXPLAIN -> RelationshipImpact(7, 0, 0, HighSchoolTrainingFocus.COMMAND)
                "공감형" to HighSchoolRelationshipResponse.CHALLENGE -> RelationshipImpact(-2, 3, 2, HighSchoolTrainingFocus.BREAKING_BALL)
                else -> RelationshipImpact(2, 0, 0, null)
            }
            else -> extendedRelationshipImpact(category, response)
        }
    }

    /** Current Swift extendedRelationshipImpact table, kept data-shaped for parity audits. */
    private fun extendedRelationshipImpact(category: String, response: HighSchoolRelationshipResponse): RelationshipImpact = when (category to response) {
        "growth" to HighSchoolRelationshipResponse.LISTEN -> RelationshipImpact(6, 0, 0, HighSchoolTrainingFocus.BREAKING_BALL)
        "growth" to HighSchoolRelationshipResponse.EXPLAIN -> RelationshipImpact(4, 0, 0, HighSchoolTrainingFocus.COMMAND)
        "growth" to HighSchoolRelationshipResponse.CHALLENGE -> RelationshipImpact(1, 4, 2, HighSchoolTrainingFocus.BREAKING_BALL)
        "health" to HighSchoolRelationshipResponse.LISTEN -> RelationshipImpact(5, -6, 0, null)
        "health" to HighSchoolRelationshipResponse.EXPLAIN -> RelationshipImpact(3, -2, 0, HighSchoolTrainingFocus.STAMINA)
        "health" to HighSchoolRelationshipResponse.CHALLENGE -> RelationshipImpact(-3, 6, 1, null)
        "team" to HighSchoolRelationshipResponse.LISTEN -> RelationshipImpact(5, 0, 0, null)
        "team" to HighSchoolRelationshipResponse.EXPLAIN -> RelationshipImpact(4, 0, 1, HighSchoolTrainingFocus.GAME_PLANNING)
        "team" to HighSchoolRelationshipResponse.CHALLENGE -> RelationshipImpact(2, 4, 2, HighSchoolTrainingFocus.STAMINA)
        "draft" to HighSchoolRelationshipResponse.LISTEN -> RelationshipImpact(3, 0, 2, null)
        "draft" to HighSchoolRelationshipResponse.EXPLAIN -> RelationshipImpact(4, 0, 3, HighSchoolTrainingFocus.COMMAND)
        "draft" to HighSchoolRelationshipResponse.CHALLENGE -> RelationshipImpact(1, 4, 4, HighSchoolTrainingFocus.VELOCITY)
        "media" to HighSchoolRelationshipResponse.LISTEN -> RelationshipImpact(2, 0, 3, null)
        "media" to HighSchoolRelationshipResponse.EXPLAIN -> RelationshipImpact(3, 0, 4, HighSchoolTrainingFocus.GAME_PLANNING)
        "media" to HighSchoolRelationshipResponse.CHALLENGE -> RelationshipImpact(0, 2, 6, null)
        "fan" to HighSchoolRelationshipResponse.LISTEN -> RelationshipImpact(2, 0, 4, null)
        "fan" to HighSchoolRelationshipResponse.EXPLAIN -> RelationshipImpact(3, 0, 5, HighSchoolTrainingFocus.COMMAND)
        "fan" to HighSchoolRelationshipResponse.CHALLENGE -> RelationshipImpact(1, 2, 6, HighSchoolTrainingFocus.VELOCITY)
        "game" to HighSchoolRelationshipResponse.LISTEN -> RelationshipImpact(5, 0, 1, HighSchoolTrainingFocus.GAME_PLANNING)
        "game" to HighSchoolRelationshipResponse.EXPLAIN -> RelationshipImpact(4, 0, 1, HighSchoolTrainingFocus.COMMAND)
        "game" to HighSchoolRelationshipResponse.CHALLENGE -> RelationshipImpact(2, 3, 2, HighSchoolTrainingFocus.BREAKING_BALL)
        "awakening" to HighSchoolRelationshipResponse.LISTEN -> RelationshipImpact(4, 0, 1, HighSchoolTrainingFocus.BREAKING_BALL)
        "awakening" to HighSchoolRelationshipResponse.EXPLAIN -> RelationshipImpact(4, 0, 1, HighSchoolTrainingFocus.COMMAND)
        "awakening" to HighSchoolRelationshipResponse.CHALLENGE -> RelationshipImpact(2, 3, 2, HighSchoolTrainingFocus.VELOCITY)
        "life" to HighSchoolRelationshipResponse.LISTEN -> RelationshipImpact(4, -3, 0, null)
        "life" to HighSchoolRelationshipResponse.EXPLAIN -> RelationshipImpact(3, 0, 0, null)
        "life" to HighSchoolRelationshipResponse.CHALLENGE -> RelationshipImpact(1, 4, 1, null)
        "legacy" to HighSchoolRelationshipResponse.LISTEN -> RelationshipImpact(3, 0, 1, null)
        "legacy" to HighSchoolRelationshipResponse.EXPLAIN -> RelationshipImpact(3, 0, 2, HighSchoolTrainingFocus.GAME_PLANNING)
        "legacy" to HighSchoolRelationshipResponse.CHALLENGE -> RelationshipImpact(2, 2, 2, HighSchoolTrainingFocus.COMMAND)
        "rebirth" to HighSchoolRelationshipResponse.LISTEN -> RelationshipImpact(4, -4, 0, null)
        "rebirth" to HighSchoolRelationshipResponse.EXPLAIN -> RelationshipImpact(3, 0, 0, HighSchoolTrainingFocus.GAME_PLANNING)
        "rebirth" to HighSchoolRelationshipResponse.CHALLENGE -> RelationshipImpact(1, 3, 2, HighSchoolTrainingFocus.VELOCITY)
        else -> RelationshipImpact(2, 0, 1, null)
    }

    private fun makeSchedule(careerId: String): HighSchoolSchedule {
        val generator = SplitMix64(hashValue("run_skeleton|$careerId"))
        val trainingTotal = 12 + generator.nextInt(5)
        val relationshipTotal = 4 + generator.nextInt(3)
        val gameTotal = 4 + generator.nextInt(3)
        val trainings = MutableList(8) { 1 }
        repeat(trainingTotal - 8) {
            val candidates = trainings.indices.filter { trainings[it] < 3 }
            trainings[candidates[generator.nextInt(candidates.size)]]++
        }
        val queues = mutableListOf(
            HighSchoolPhase.RELATIONSHIP to relationshipTotal,
            HighSchoolPhase.IMPORTANT_GAME to gameTotal - 1,
            HighSchoolPhase.AWAKENING to 2,
        )
        for (index in queues.lastIndex downTo 1) {
            val swap = generator.nextInt(index + 1)
            val value = queues[index]
            queues[index] = queues[swap]
            queues[swap] = value
        }
        val sequence = mutableListOf<HighSchoolPhase>()
        while (queues.any { it.second > 0 }) {
            queues.indices.filter { queues[it].second > 0 }.forEach { index ->
                sequence += queues[index].first
                queues[index] = queues[index].first to queues[index].second - 1
            }
        }
        val milestones = MutableList(8) { mutableListOf<HighSchoolPhase>() }
        val counts = MutableList(7) { sequence.size / 7 }
        val offset = generator.nextInt(7)
        repeat(sequence.size % 7) { counts[(offset + it) % 7]++ }
        var cursor = 0
        for (chapter in 0..6) repeat(counts[chapter]) {
            if (cursor < sequence.size) milestones[chapter] += sequence[cursor++]
        }
        milestones[7] += listOf(HighSchoolPhase.AWAKENING, HighSchoolPhase.IMPORTANT_GAME)
        return HighSchoolSchedule(trainings, milestones)
    }

    private fun makeRival(seed: ULong, difficulty: String, karmas: List<HighSchoolKarma>, windBonus: Int): HighSchoolRival {
        val generator = SplitMix64(seed xor 0x524956414C00UL)
        val base = HighSchoolContentCatalog.rivals[generator.nextInt(HighSchoolContentCatalog.rivals.size)]
        val difficultyBonus = when (difficulty) {
            "relaxed" -> -3
            "challenging" -> 4
            else -> 0
        }
        val generationBonus = if (HighSchoolKarma.GENIUS_GENERATION in karmas) 4 else 0
        val bonus = difficultyBonus + generationBonus + windBonus
        return base.copy(
            contact = clamp(base.contact + bonus),
            discipline = clamp(base.discipline + bonus),
            power = clamp(base.power + bonus),
        )
    }

    private fun memoryOptions(state: HighSchoolState, seed: ULong, drafted: Boolean = false): List<String> {
        val values = HighSchoolContentCatalog.memoryCards.toMutableList()
        // Swift uses a separate salt for drafted and undrafted endings; this is part of the
        // source contract because the two endings intentionally surface different memories.
        val outcomeSalt = if (drafted) 0x4452414654454400UL else 0UL
        val generator = SplitMix64(seed xor state.performance.pitches.toULong() xor 0x4D454D4F5259UL xor outcomeSalt)
        for (index in values.lastIndex downTo 1) {
            val swap = generator.nextInt(index + 1)
            val value = values[index]
            values[index] = values[swap]
            values[swap] = value
        }
        return values.take(5)
    }

    private fun draftEvaluationBreakdown(state: HighSchoolState): List<String> {
        val ratings = state.pitcher.stuff + state.pitcher.command + state.pitcher.movement + state.pitcher.stamina
        val performance = state.performance.strikeouts * 4 - state.performance.walks * 2 - state.performance.runsAllowed * 2
        val process = clamp((state.performance.expectedDamage - state.performance.actualDamage) / 350, -8, 10)
        val season = if (state.automaticOuts == 0) 0 else {
            val firstLifeBaseline = when (state.pitcher.id) {
                "pitcher-command" -> 1_900
                "pitcher-artist" -> 2_700
                "pitcher-stamina" -> 2_900
                else -> 4_930
            }
            fun meanScale(life: Int): Int = (1..8).sumOf { chapter -> difficultyScale(chapter, life) } * 100 / 8
            val baseline = firstLifeBaseline + 432 * (meanScale(state.lifeNumber) - meanScale(1)) / 100
            clamp((baseline - state.automaticRunsAllowed * 27_000 / state.automaticOuts) / 1_000, -2, 2)
        }
        val relationship = (state.relationshipTrust - 50) / 10
        val karma = (if (HighSchoolKarma.UNKNOWN_LAND in state.karmas) 3 else 0) +
            if (HighSchoolKarma.NO_LAST_CHANCE in state.karmas) 2 else 0
        val overuse = when {
            state.armRisk >= HighSchoolContentCatalog.ARM_WARNING_THRESHOLD -> 4
            state.armRisk >= 45 -> 2
            else -> 0
        }
        val fan = clamp((state.fanInterest - 40) / 15, -3, 3)
        return listOf(
            "능력 ${ratings / 4 + 15}",
            "고교 공식 경기 ${if (performance >= 0) "+" else ""}${performance / 6}",
            "시즌 기록 ${if (season >= 0) "+" else ""}$season",
            "각성 +${state.selectedAwakenings.size}",
            "관계 ${if (relationship >= 0) "+" else ""}$relationship",
        ) + (if (karma > 0) listOf("핸디캡 -$karma") else emptyList()) +
            (if (overuse > 0) listOf("팔 상태 -$overuse") else emptyList())
    }

    private fun draftScore(state: HighSchoolState): Int {
        val ratings = state.pitcher.stuff + state.pitcher.command + state.pitcher.movement + state.pitcher.stamina
        val quality = state.performance.strikeouts * 4 - state.performance.walks * 2 - state.performance.runsAllowed * 2
        val process = clamp((state.performance.expectedDamage - state.performance.actualDamage) / 350, -8, 10)
        val season = if (state.automaticOuts == 0) 0 else {
            val firstLifeBaseline = when (state.pitcher.id) {
                "pitcher-command" -> 1_900
                "pitcher-artist" -> 2_700
                "pitcher-stamina" -> 2_900
                else -> 4_930
            }
            fun meanScale(life: Int): Int = (1..8).sumOf { chapter -> difficultyScale(chapter, life) } * 100 / 8
            val baseline = firstLifeBaseline + 432 * (meanScale(state.lifeNumber) - meanScale(1)) / 100
            clamp((baseline - state.automaticRunsAllowed * 27_000 / state.automaticOuts) / 1_000, -2, 2)
        }
        val karmaPenalty = (if (HighSchoolKarma.UNKNOWN_LAND in state.karmas) 3 else 0) +
            if (HighSchoolKarma.NO_LAST_CHANCE in state.karmas) 2 else 0
        val overusePenalty = when {
            state.armRisk >= HighSchoolContentCatalog.ARM_WARNING_THRESHOLD -> 4
            state.armRisk >= 45 -> 2
            else -> 0
        }
        val fanTerm = clamp((state.fanInterest - 40) / 15, -3, 3)
        return clamp(
            ratings / 4 + 15 + quality / 6 + process + state.selectedAwakenings.size +
                (state.relationshipTrust - 50) / 10 + season + fanTerm + windFor(state.careerId).draftEvaluationDelta -
                karmaPenalty - overusePenalty,
            20,
            95,
        )
    }

    private fun draftThreshold(state: HighSchoolState): Int {
        val base = when (state.difficulty.careerHarshness) {
            "relaxed" -> 57
            "challenging" -> 65
            else -> 61
        }
        return base + 5
    }

    private fun trainingGrowth(signal: Int): Int = when {
        signal >= 430 -> 2
        signal >= 260 -> 1
        else -> 0
    }

    private fun trainingVariance(focus: HighSchoolTrainingFocus): Int = when (focus) {
        HighSchoolTrainingFocus.VELOCITY -> 70
        HighSchoolTrainingFocus.BREAKING_BALL -> 50
        HighSchoolTrainingFocus.STAMINA -> 35
        HighSchoolTrainingFocus.GAME_PLANNING -> 30
        HighSchoolTrainingFocus.COMMAND -> 25
        HighSchoolTrainingFocus.RECOVERY -> 20
    }

    private fun jackpotModifier(focus: HighSchoolTrainingFocus): Int = when (focus) {
        HighSchoolTrainingFocus.VELOCITY -> 6
        HighSchoolTrainingFocus.BREAKING_BALL -> 2
        HighSchoolTrainingFocus.STAMINA -> 0
        HighSchoolTrainingFocus.GAME_PLANNING -> -2
        HighSchoolTrainingFocus.COMMAND -> -6
        HighSchoolTrainingFocus.RECOVERY -> -100
    }

    private fun trainingFatigueModifier(focus: HighSchoolTrainingFocus): Int = when (focus) {
        HighSchoolTrainingFocus.VELOCITY -> 1
        HighSchoolTrainingFocus.COMMAND -> -2
        HighSchoolTrainingFocus.GAME_PLANNING -> -1
        else -> 0
    }

    private fun trainingArmRisk(focus: HighSchoolTrainingFocus, intensity: HighSchoolTrainingIntensity): Int {
        if (intensity != HighSchoolTrainingIntensity.INTENSIVE) return 0
        return when (focus) {
            HighSchoolTrainingFocus.VELOCITY -> 3
            HighSchoolTrainingFocus.BREAKING_BALL -> 2
            HighSchoolTrainingFocus.STAMINA -> 1
            else -> 0
        }
    }

    private fun rating(focus: HighSchoolTrainingFocus, pitcher: HighSchoolPitcher): Int = when (focus) {
        HighSchoolTrainingFocus.VELOCITY -> pitcher.stuff
        HighSchoolTrainingFocus.BREAKING_BALL -> pitcher.movement
        HighSchoolTrainingFocus.STAMINA, HighSchoolTrainingFocus.RECOVERY -> pitcher.stamina
        HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingFocus.GAME_PLANNING -> pitcher.command
    }

    private fun grow(
        pitcher: HighSchoolPitcher,
        focus: HighSchoolTrainingFocus,
        points: Int,
        targetPitch: PitchKind? = null,
    ): HighSchoolPitcher {
        if (points <= 0) return pitcher
        val normalizedTarget = targetPitch?.takeIf {
            focus == HighSchoolTrainingFocus.BREAKING_BALL &&
                it != PitchKind.FOUR_SEAM &&
                pitcher.pitchProfiles.any { profile -> profile.pitchType == it }
        }
        val profiles = pitcher.pitchProfiles.map { profile ->
            val breakingTarget = focus == HighSchoolTrainingFocus.BREAKING_BALL &&
                profile.pitchType != PitchKind.FOUR_SEAM &&
                (normalizedTarget == null || profile.pitchType == normalizedTarget)
            val nextCommand = (profile.command + if (focus == HighSchoolTrainingFocus.COMMAND || focus == HighSchoolTrainingFocus.GAME_PLANNING) points else 0).coerceIn(20, 80)
            val nextWhiff = (profile.whiff +
                (if (focus == HighSchoolTrainingFocus.VELOCITY && profile.pitchType == PitchKind.FOUR_SEAM) points else 0) +
                (if (breakingTarget) points else 0)).coerceIn(20, 80)
            profile.copy(
                role = if (profile.role == PitchUsageRole.DEVELOPMENT &&
                    nextCommand + nextWhiff + profile.weakContact >= 150
                ) PitchUsageRole.SECONDARY else profile.role,
                velocityTenthsKph = (profile.velocityTenthsKph + if (focus == HighSchoolTrainingFocus.VELOCITY) points * 5 else 0)
                    .coerceIn(1_000, PitchAbilityRules.maximumProfileVelocity(profile.pitchType)),
                control = (profile.control + if (focus == HighSchoolTrainingFocus.COMMAND) points else 0).coerceIn(20, 80),
                command = nextCommand,
                movement = (profile.movement + if (breakingTarget) points * 2 else 0).coerceIn(20, 80),
                whiff = nextWhiff,
                fatigueCost = if (focus == HighSchoolTrainingFocus.STAMINA) {
                    reducedFatigueCost(profile.fatigueCost, points / 2)
                } else profile.fatigueCost,
            )
        }
        return pitcher.copy(
            stuff = clamp(pitcher.stuff + if (focus == HighSchoolTrainingFocus.VELOCITY) points else 0),
            command = clamp(pitcher.command + if (focus == HighSchoolTrainingFocus.COMMAND || focus == HighSchoolTrainingFocus.GAME_PLANNING) points else 0),
            movement = clamp(pitcher.movement + if (focus == HighSchoolTrainingFocus.BREAKING_BALL) points else 0),
            stamina = clamp(pitcher.stamina + if (focus == HighSchoolTrainingFocus.STAMINA || focus == HighSchoolTrainingFocus.RECOVERY) points else 0),
            pitchProfiles = profiles,
        )
    }

    private fun tune(
        pitcher: HighSchoolPitcher,
        stuff: Int = 0,
        command: Int = 0,
        movement: Int = 0,
        stamina: Int = 0,
        pitch: PitchKind? = null,
        pitchSet: Set<PitchKind>? = null,
        nonFastball: Boolean = false,
        velocity: Int = 0,
        control: Int = 0,
        profileCommand: Int = 0,
        profileMovement: Int = 0,
        whiff: Int = 0,
        weakContact: Int = 0,
        fatigueCost: Int = 0,
    ): HighSchoolPitcher {
        val profiles = pitcher.pitchProfiles.map { profile ->
            val matches = when {
                pitch != null -> profile.pitchType == pitch
                pitchSet != null -> profile.pitchType in pitchSet
                nonFastball -> profile.pitchType != PitchKind.FOUR_SEAM
                else -> true
            }
            profile.copy(
                velocityTenthsKph = (profile.velocityTenthsKph + if (matches) velocity else 0)
                    .coerceIn(1_000, PitchAbilityRules.maximumProfileVelocity(profile.pitchType)),
                control = (profile.control + if (matches) control else 0).coerceIn(20, 80),
                command = (profile.command + if (matches) profileCommand else 0).coerceIn(20, 80),
                movement = (profile.movement + if (matches) profileMovement else 0).coerceIn(20, 80),
                whiff = (profile.whiff + if (matches) whiff else 0).coerceIn(20, 80),
                weakContact = (profile.weakContact + if (matches) weakContact else 0).coerceIn(20, 80),
                fatigueCost = (profile.fatigueCost + if (matches) fatigueCost else 0).coerceIn(0, 20),
            )
        }
        return pitcher.copy(
            stuff = clamp(pitcher.stuff + stuff),
            command = clamp(pitcher.command + command),
            movement = clamp(pitcher.movement + movement),
            stamina = clamp(pitcher.stamina + stamina),
            pitchProfiles = profiles,
        )
    }

    private fun reducedFatigueCost(current: Int, reduction: Int): Int =
        if (current <= 0) 0 else max(1, current - max(0, reduction))

    private fun difficultyScale(chapter: Int, lifeNumber: Int): Int {
        val byChapter = min(3, max(0, chapter - 1) * 3 / 7)
        val byLife = min(4, max(0, lifeNumber - 1) * 2)
        return byChapter + byLife
    }

    private fun windFor(careerId: String): Wind {
        val bucket = HighSchoolWindRules.bucketFor(careerId)
        return when (bucket) {
            in 0..29 -> Wind("calm")
            in 30..37 -> Wind("monster_generation", "괴물 세대", "강한 숙적과 맞서는 만큼 좋은 경기에는 더 많은 시선이 모입니다.", rivalBonus = 5, rewardBonusPermille = 150, fanInterestGainBonus = 3)
            in 38..45 -> Wind("scout_frenzy", "스카우트 풍년", "일찍 모인 시선이 시즌 내내 따라붙습니다.", startingFanInterest = 10)
            in 46..53 -> Wind("quiet_season", "무명의 해", "관심 없이 시작하지만 숙적도 평소보다 덜 완성된 해입니다.", rivalBonus = -3, startingFanInterest = 0, rewardBonusPermille = 80)
            in 54..61 -> Wind("heatwave", "긴 여름", "훈련의 피로가 더 쌓이는 대신 몸을 돌보는 회복도 더 깊습니다.", rewardBonusPermille = 120, trainingFatigueDelta = 2, recoveryBonus = 4)
            in 62..69 -> Wind("command_year", "코스의 해", "제구 감각이 잘 붙지만 강한 공을 만드는 날에는 피로가 더 듭니다.", rewardBonusPermille = 50, favoredTraining = HighSchoolTrainingFocus.COMMAND, favoredTrainingBonus = 1, extraFatigueFocus = HighSchoolTrainingFocus.VELOCITY, extraFatigueDelta = 1)
            in 70..77 -> Wind("power_year", "강한 공의 해", "구위는 빠르게 자라지만 숙적도 강한 승부에 맞춰 올라옵니다.", rivalBonus = 3, rewardBonusPermille = 100, favoredTraining = HighSchoolTrainingFocus.VELOCITY, favoredTrainingBonus = 1)
            in 78..85 -> Wind("battery_year", "배터리의 해", "조용한 출발 대신 포수와 쌓는 믿음이 더 빠르게 깊어집니다.", startingFanInterest = 2, rewardBonusPermille = 50, favoredRelationship = HighSchoolRelationshipTarget.CATCHER, favoredRelationshipBonus = 2)
            in 86..92 -> Wind("spotlight_year", "조명의 해", "좋은 장면은 더 큰 관심을 부르지만 관계에서의 실패도 더 선명하게 남습니다.", rewardBonusPermille = 80, fanInterestGainBonus = 2, relationshipLossPenalty = 2)
            else -> Wind("underdog_year", "언더독의 해", "관심 없이 강한 숙적을 만나지만 끝까지 증명하면 평가가 따라옵니다.", startingFanInterest = 0, rivalBonus = 2, rewardBonusPermille = 120, draftEvaluationDelta = 1)
        }
    }

    private fun prologueNews(
        identity: HighSchoolIdentity,
        lifeNumber: Int,
        inheritedMemoryCount: Int,
        windNews: String?,
    ): List<String> {
        val base = if (lifeNumber <= 1) {
            listOf("${identity.region} 중학교 마지막 대회에서 보여준 공이 같은 지역 네 고교의 관심을 끌었습니다.")
        } else {
            val openers = listOf(
                "${identity.region} 중학교 마지막 대회. 처음 서는 마운드인데 흙의 감촉이 낯설지 않았습니다. 같은 지역 네 고교가 다시 지켜보고 있습니다.",
                "${identity.region} 중학교 마지막 대회에서 던진 마지막 공. 포수 미트에 꽂히는 소리가 어딘가 익숙했습니다. 네 고교의 시선이 모입니다.",
                "${identity.region} 중학교 마지막 대회를 마친 뒤, 어깨보다 먼저 마음이 다음 이닝을 준비하고 있었습니다. 네 고교에서 제안이 도착했습니다.",
            )
            buildList {
                add(openers[(lifeNumber - 2) % openers.size])
                if (inheritedMemoryCount > 0) {
                    add("처음 잡는 그립인데 손끝이 먼저 기억합니다 · 설명하기 어려운 감각 ${inheritedMemoryCount}가지")
                }
            }
        }
        return (windNews?.let(::listOf).orEmpty() + base)
    }

    private fun signed(state: HighSchoolState): HighSchoolState = state.copy(stateCommitment = commitment(state))

    private fun commitment(state: HighSchoolState): String {
        val ratings = "${state.pitcher.stuff}:${state.pitcher.command}:${state.pitcher.movement}:${state.pitcher.stamina}"
        val performance = listOf(
            state.performance.importantGamesCompleted, state.performance.pitches, state.performance.strikeouts,
            state.performance.walks, state.performance.runsAllowed, state.performance.expectedDamage,
            state.performance.actualDamage, state.performance.outs, state.performance.hits,
        ).joinToString(":")
        val draft = state.draftResult?.toString() ?: "none"
        val talent = listOf(
            state.talent.stuff.name, state.talent.command.name, state.talent.movement.name, state.talent.stamina.name,
            state.talent.stuffPressure, state.talent.commandPressure, state.talent.movementPressure, state.talent.staminaPressure,
        ).joinToString(":")
        val schools = state.schoolOptions.joinToString(";") { school ->
            listOf(school.id.wire, school.name, school.philosophy, school.coachName, school.coachArchetype,
                school.catcherName, school.catcherArchetype, school.strength.wire, school.tradeoff,
                school.coachPersonality ?: "none", school.coachRecord ?: "none",
                school.catcherPersonality ?: "none", school.catcherRecord ?: "none").joinToString(":")
        }
        val selectedSchool = state.school?.let { school ->
            listOf(school.id.wire, school.name, school.philosophy, school.coachName, school.coachArchetype,
                school.catcherName, school.catcherArchetype, school.strength.wire, school.tradeoff,
                school.coachPersonality ?: "none", school.coachRecord ?: "none",
                school.catcherPersonality ?: "none", school.catcherRecord ?: "none").joinToString(":")
        } ?: "none"
        val rival = listOf(state.rival.id, state.rival.name, state.rival.archetype, state.rival.contact, state.rival.discipline, state.rival.power,
            state.rival.personality ?: "none", state.rival.signatureRecord ?: "none").joinToString(":")
        val chapter = listOf(state.chapter.number, state.chapter.title, state.chapter.schoolYear, state.chapter.season, state.chapter.theme).joinToString(":")
        val pitcherProfiles = if (state.pitcher.pitchProfiles.isNotEmpty() || state.pitcher.throwingHand != ThrowingHand.RIGHT) {
            "${state.pitcher.throwingHand.name.lowercase()}:" + state.pitcher.pitchProfiles.joinToString(";") { profile ->
                listOf(
                    profile.pitchType.wire, profile.role.wire, profile.velocityTenthsKph, profile.control,
                    profile.command, profile.movement, profile.whiff, profile.weakContact, profile.fatigueCost,
                ).joinToString(":")
            }
        } else {
            "legacy"
        }
        val opportunity = state.trainingOpportunity?.let { "${it.focus.wire}:${it.reason}" } ?: "none"
        val training = state.lastTraining?.let {
            listOf(it.number, it.focus.wire, it.intensity.wire, it.growth, it.fatigueChange, it.opportunityHit, it.bloomed).joinToString(":")
        } ?: "none"
        val relationship = state.lastRelationship?.let {
            listOf(it.number, it.target.wire, it.response.wire, it.trustBefore, it.trustAfter, it.fatigueBefore,
                it.fatigueAfter, it.fanInterestBefore, it.fanInterestAfter, it.growthFocus?.wire ?: "none").joinToString(":")
        } ?: "none"
        val scenario = state.currentGameScenario?.let {
            listOf(it.id, it.title, it.inning, it.outs, it.firstOccupied, it.secondOccupied, it.thirdOccupied,
                it.leadRunnerSpeed, it.leverage, it.narrative, it.scoreDifferential ?: "none", it.minChapter).joinToString(":")
        }
        val currentEvent = state.currentRelationshipEvent?.let {
            listOf(it.id, it.title, it.category, it.summary).joinToString(":")
        } ?: "none"
        val echo = state.rebirthEcho?.let {
            listOf(
                it.previousLifeNumber, it.previousPlayerName, it.previousSchoolName ?: "none", it.previousCareerId,
                it.inheritedMemoryCount, it.inheritedSignatureLegacyId ?: "none", it.previousArmWarning, it.previousUndrafted,
                it.recentEventIds.joinToString(","), it.previousNickname ?: "none", it.previousCoachName ?: "none",
                it.previousRivalName ?: "none", it.inheritedLegacyId ?: "none", it.automaticInheritanceTotal ?: "none",
                it.hadRunsAllowed ?: "none", it.hadCollapseGame,
            ).joinToString(":")
        } ?: "none"
        return StableHash.fnv1a64(
            listOf(
                state.careerId, state.revision.toString(), state.phase.wire, state.identity.name,
                state.identity.throwingHand, state.identity.bodyType, state.identity.region,
                state.school?.id?.wire ?: "none", state.difficulty.careerHarshness,
                state.difficulty.informationClarity, state.difficulty.simulationDifficulty,
                state.difficulty.interventionAssist, state.karmas.joinToString(",") { it.wire },
                state.soulBoosts.joinToString(",") { it.wire }, talent, schools, selectedSchool, rival, chapter,
                state.legacyRewardPermille.toString(), state.memorySlots.toString(), state.chapter.number.toString(),
                state.chapterTrainingCount.toString(), state.totalTrainingsCompleted.toString(), state.milestoneIndex.toString(),
                state.relationshipsCompleted.toString(), state.relationshipTrust.toString(),
                state.selectedAwakenings.joinToString(",") { it.wire }, state.awakeningOptions.joinToString(",") { it.wire },
                state.awakeningSparks.toString(), state.fatigue.toString(), ratings, performance,
                state.currentGameScenarioId ?: "none", state.currentRelationshipTarget?.wire ?: "none",
                state.currentRelationshipCategory ?: "none",
                opportunity, training, relationship, state.fanInterest.toString(), state.armRisk.toString(),
                state.injuryRecovery.toString(), state.automaticGames.toString(), state.automaticOuts.toString(),
                state.automaticRunsAllowed.toString(), draft,
                state.legacyOptions.joinToString(","), state.selectedMemories.joinToString(","),
                "relationships:${state.managerTrust}:${state.catcherTrust}:${state.rivalTrust}",
                "arm:${state.armRisk}:${state.injuryRecovery}", "auto:${state.automaticGames}:${state.automaticOuts}:${state.automaticRunsAllowed}",
                "pitcherProfiles:$pitcherProfiles",
                "schedule:${state.schedule.trainingsByChapter.joinToString(",")}|${state.schedule.milestonesByChapter.joinToString(";") { phases -> phases.joinToString(",") { it.wire } }}",
            ).toMutableList().apply {
                if (scenario != null) add("gameScenario:$scenario")
                if (currentEvent != "none") add("relationshipEvent:$currentEvent")
                if (state.news.isNotEmpty()) add("news:${state.news.joinToString("\u001f")}")
                if (state.balanceVersion != HighSchoolContentCatalog.BALANCE_VERSION || state.worldRulesVersion != HighSchoolContentCatalog.WORLD_RULES_VERSION) {
                    add("versions:${state.balanceVersion}:${state.worldRulesVersion}")
                }
                if (state.recentRelationshipEventIds.isNotEmpty()) add("recentRelationships:${state.recentRelationshipEventIds.joinToString(",")}")
                if (echo != "none") add("rebirthEcho:$echo")
            }.joinToString("|"),
        )
    }

    private fun validate(seedText: String, state: HighSchoolState, phase: HighSchoolPhase): ULong {
        val seed = parseSeed(seedText)
        require(state.phase == phase) { "state.phase" }
        require(state.stateCommitment.isNotBlank() && state.stateCommitment == commitment(state)) { "state.commitment" }
        return seed
    }

    private fun result(
        seed: ULong,
        state: HighSchoolState,
        event: String,
        reasons: List<String> = emptyList(),
    ): HighSchoolResult {
        val generator = SplitMix64(seed xor state.revision xor 0x4556454E5400UL)
        val nextSeed = generator.next().toString()
        val eventHash = StableHash.fnv1a64("${state.careerId}|${state.revision}|$event|$nextSeed|${state.stateCommitment}")
        return HighSchoolResult(state.revision, nextSeed, listOf(HighSchoolEvent(event, 0, reasons)), state, eventHash)
    }

    private fun parseSeed(value: String): ULong = value.toULongOrNull() ?: error("seed.invalid")
    private fun hashValue(value: String): ULong = StableHash.fnv1a64(value).toULong(16)
    private fun clamp(value: Int, lower: Int = 20, upper: Int = 80): Int = value.coerceIn(lower, upper)

    private data class InheritanceApplication(
        val pitcher: HighSchoolPitcher,
        val talent: HighSchoolTalent,
    )
    private data class TalentApplication(val allowed: Int, val talent: HighSchoolTalent, val bloomed: Boolean)
    private data class GameGrowthApplication(
        val pitcher: HighSchoolPitcher,
        val talent: HighSchoolTalent,
        val bloomed: Boolean,
    )
    private data class RelationshipImpact(
        val trust: Int,
        val fatigue: Int,
        val fanInterest: Int,
        val growthFocus: HighSchoolTrainingFocus?,
    )
    private data class Wind(
        val id: String,
        val title: String = "바람 없는 해",
        val detail: String = "특별할 것 없는 평범한 해입니다. 실력만이 말합니다.",
        val rivalBonus: Int = 0,
        val startingFanInterest: Int = 5,
        val rewardBonusPermille: Int = 0,
        val favoredTraining: HighSchoolTrainingFocus? = null,
        val favoredTrainingBonus: Int = 0,
        val trainingFatigueDelta: Int = 0,
        val extraFatigueFocus: HighSchoolTrainingFocus? = null,
        val extraFatigueDelta: Int = 0,
        val recoveryBonus: Int = 0,
        val favoredRelationship: HighSchoolRelationshipTarget? = null,
        val favoredRelationshipBonus: Int = 0,
        val relationshipLossPenalty: Int = 0,
        val fanInterestGainBonus: Int = 0,
        val draftEvaluationDelta: Int = 0,
    ) {
        val newsLine: String? get() = if (id == "calm") null else "이번 3년의 바람 — $title. $detail"
        fun trainingGrowthBonus(focus: HighSchoolTrainingFocus): Int = if (focus == favoredTraining) favoredTrainingBonus else 0
        fun trainingFatigueModifier(focus: HighSchoolTrainingFocus): Int =
            trainingFatigueDelta + if (focus == extraFatigueFocus) extraFatigueDelta else 0
    }

    private companion object {
        val CORE_RELATIONSHIP_CATEGORIES = listOf("coach", "catcher", "rival")
        // First occurrence order copied from HighSchoolContentCatalog.events after removing
        // the three core relationship categories in the current Swift source.
        val EXTENDED_RELATIONSHIP_CATEGORIES = listOf(
            "growth", "health", "team", "draft", "media", "fan", "game", "awakening", "life", "legacy",
        )
        val OPPORTUNITY_REASONS: Map<HighSchoolTrainingFocus, List<String>> = mapOf(
            HighSchoolTrainingFocus.VELOCITY to listOf("어제 불펜에서 팔 스윙이 가벼웠다. 오늘 직구를 밀어붙이자.", "하체 힘이 붙었다. 구속을 끌어올릴 타이밍이다.", "공 끝이 살아 있다. 오늘은 세게 던져 보자."),
            HighSchoolTrainingFocus.COMMAND to listOf("포수가 미트를 거의 안 움직였다. 코스 훈련이 먹힐 날이다.", "던지는 리듬이 잡혔다. 오늘 존 구석을 노리자.", "밸런스가 좋다. 원하는 곳에 꽂는 연습을 늘리자."),
            HighSchoolTrainingFocus.BREAKING_BALL to listOf("어제 변화구 회전이 좋았다. 오늘 확실히 내 것으로 만들자.", "손끝 감각이 살아 있다. 변화구를 다듬을 기회다.", "타자들이 변화구에 늦게 반응했다. 오늘 더 벼리자."),
            HighSchoolTrainingFocus.STAMINA to listOf("긴 이닝을 버틸 몸을 만들 적기다.", "회복이 빨라졌다. 오늘 체력 훈련이 잘 붙는다.", "다음 등판까지 여유가 있다. 체력을 쌓자."),
            HighSchoolTrainingFocus.RECOVERY to listOf("팔이 무겁다는 신호다. 오늘은 회복이 최고의 훈련이다.", "쉬는 것도 실력이다. 몸을 만들 날이다.", "피로가 쌓였다. 오늘 회복하면 내일이 달라진다."),
            HighSchoolTrainingFocus.GAME_PLANNING to listOf("상대 타선 기록이 도착했다. 오늘 파고들자.", "포수와 사인을 맞출 시간이 났다. 수 싸움을 늘리자.", "경기 감각이 올라 있다. 상대 분석이 잘 먹힌다."),
        )
    }
}
