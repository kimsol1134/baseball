package com.solkim.baseball.core.pro

import com.solkim.baseball.core.pitch.PitchLearningProject
import com.solkim.baseball.core.pitch.PitchLearningRules
import com.solkim.baseball.core.SplitMix64
import com.solkim.baseball.core.StableHash
import com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel
import com.solkim.baseball.core.highschool.HighSchoolPhase4State
import com.solkim.baseball.core.highschool.HighSchoolAwakening
import com.solkim.baseball.core.highschool.HighSchoolKernel
import com.solkim.baseball.core.highschool.HighSchoolSignatureLegacyRules
import com.solkim.baseball.core.pitch.BatSide
import com.solkim.baseball.core.pitch.BatterScoutingSnapshot
import com.solkim.baseball.core.pitch.BatterSnapshot
import com.solkim.baseball.core.pitch.BaserunnerStateSnapshot
import com.solkim.baseball.core.pitch.DefenseSnapshot
import com.solkim.baseball.core.pitch.FielderSnapshot
import com.solkim.baseball.core.pitch.GameLogSnapshot
import com.solkim.baseball.core.pitch.GameStateSnapshot
import com.solkim.baseball.core.pitch.HalfInning
import com.solkim.baseball.core.pitch.InningStateSnapshot
import com.solkim.baseball.core.pitch.ParkSnapshot
import com.solkim.baseball.core.pitch.PitchAbilityRules
import com.solkim.baseball.core.pitch.PitchCall
import com.solkim.baseball.core.pitch.PitchDelivery
import com.solkim.baseball.core.pitch.PitchIntensity
import com.solkim.baseball.core.pitch.PitchKernel
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchOutcome
import com.solkim.baseball.core.pitch.PitchPreparation
import com.solkim.baseball.core.pitch.PitchSequenceEvaluator
import com.solkim.baseball.core.pitch.PitchSequencePitch
import com.solkim.baseball.core.pitch.PitcherSnapshot
import com.solkim.baseball.core.pitch.PitchProfileSnapshot
import com.solkim.baseball.core.pitch.PitchUsageRole
import com.solkim.baseball.core.pitch.PlateAppearanceContext
import com.solkim.baseball.core.pitch.PlateAppearanceResult
import com.solkim.baseball.core.pitch.RivalMemorySnapshot
import com.solkim.baseball.core.pitch.ThrowingHand
import kotlin.math.max
import kotlin.math.min

public class ProKernelException(public val code: String) : IllegalArgumentException(code)

/** Pure Kotlin Pro authority. It is intentionally not connected to production persistence. */
public class ProKernel(
    private val pitch: PitchKernel = PitchKernel(),
) {
    public companion object {
        public const val CURRENT_RULES_VERSION: Int = ProCatalog.RULES_VERSION
        public const val AGENCY_RULES_VERSION: Int = 3
        public const val CAREER_ARC_RULES_VERSION: Int = 5
        public const val AUTUMN_RULES_VERSION: Int = 6
        public const val FINAL_SERIES_RULES_VERSION: Int = 7
        public const val CAREER_CHALLENGE_RULES_VERSION: Int = 8
        public const val WEEKLY_DECISION_RULES_VERSION: Int = 9
        public const val CONTRACT_DEPTH_RULES_VERSION: Int = 10
        public const val NATIONAL_TEAM_RULES_VERSION: Int = 10
        public const val HALL_OF_FAME_FORMULA_VERSION: Int = 3

        public fun developmentTicksRequired(ability: Int): Int = when {
            ability < 55 -> 2
            ability < 65 -> 3
            ability < 73 -> 4
            else -> 6
        }

        public fun liveOutingOffset(season: Int): Int = DifficultyScale.pro(season)

        public fun usesAgencyRules(state: ProState): Boolean = state.proRulesVersion >= AGENCY_RULES_VERSION
        public fun usesRetiredNumberLiveRules(state: ProState): Boolean = state.proRulesVersion >= 4
        public fun usesLiveOutingRules(state: ProState): Boolean = usesRetiredNumberLiveRules(state)
        public fun usesCareerArcRules(state: ProState): Boolean = state.proRulesVersion >= CAREER_ARC_RULES_VERSION
        public fun usesAutumnRules(state: ProState): Boolean = state.proRulesVersion >= AUTUMN_RULES_VERSION
        public fun usesFinalSeriesRules(state: ProState): Boolean = state.proRulesVersion >= FINAL_SERIES_RULES_VERSION
        public fun usesChallengeRules(state: ProState): Boolean = state.proRulesVersion >= CAREER_CHALLENGE_RULES_VERSION
        public fun usesWeeklyDecisionRules(state: ProState): Boolean = state.proRulesVersion >= WEEKLY_DECISION_RULES_VERSION
        public fun usesContractDepthRules(state: ProState): Boolean = state.proRulesVersion >= CONTRACT_DEPTH_RULES_VERSION
        public fun usesNationalTeamRules(state: ProState): Boolean = state.proRulesVersion >= NATIONAL_TEAM_RULES_VERSION

        public fun initialJourneyFanSupport(draftEvaluation: Int): Int =
            (20 + (draftEvaluation.coerceIn(0, 100) / 4)).coerceIn(10, 55)

        public fun shouldOfferNationalTeam(state: ProState): Boolean {
            if (!usesNationalTeamRules(state)) return false
            if (state.season < ProNationalTeamRules.MINIMUM_SEASON || state.season % ProNationalTeamRules.CALL_INTERVAL != 0) return false
            if (state.age > ProNationalTeamRules.MAXIMUM_AGE) return false
            if (state.phase == ProCareerPhase.RETIREMENT_DECISION) return false
            if (state.nationalTeamHistory.any { it.season == state.season }) return false
            val fan = state.journeyState?.reputation?.fanSupport ?: 0
            val marketScore = if (state.journeyState != null) ProCurrentMarketRules.marketScore(state) else 0
            val currentAwards = state.journeyState?.recognitions.orEmpty().count { it.kind == ProCareerRecognitionKind.AWARD && it.season == state.season }
            return fan >= ProNationalTeamRules.FAN_SUPPORT_THRESHOLD || currentAwards > 0 || marketScore >= ProNationalTeamRules.MARKET_SCORE_THRESHOLD
        }

        /** An already-issued, signed call remains valid when eligibility calculations change. */
        private fun recordedNationalCallValid(state: ProState): Boolean = usesNationalTeamRules(state) &&
            state.phase == ProCareerPhase.NATIONAL_TEAM_CALL && state.season >= ProNationalTeamRules.MINIMUM_SEASON &&
            state.season % ProNationalTeamRules.CALL_INTERVAL == 0 && state.age <= ProNationalTeamRules.MAXIMUM_AGE &&
            state.nationalTeamHistory.none { it.season == state.season }

        public fun injuryPressure(rawFatigue: Int, stamina: Int, mastery: Int, challengeRules: Boolean): Int {
            val effective = PitchAbilityRules.effectiveFatigue(rawFatigue, stamina, mastery)
            if (!challengeRules) return effective
            return max(effective, min(100, max(0, rawFatigue)) * 800 / 1_000)
        }

        public fun liveClimate(state: ProState, week: Int? = null): ProSeasonClimate? {
            if (!usesCareerArcRules(state)) return null
            val stabilize = if (state.journeyState?.activeSeasonBenefit?.kind == ProSeasonBenefitKind.CLIMATE_STABILIZATION) {
                state.journeyState.activeSeasonBenefit?.remainingCharges ?: 0
            } else 0
            return ProSeasonClimateRules.climate(
                careerId = state.careerId,
                season = state.season,
                week = week ?: max(1, state.week),
                strikeouts = state.currentStats.strikeouts,
                inningsOuts = state.currentStats.inningsOuts,
                stabilizeCharges = stabilize,
            )
        }

        public fun liveBatterOffset(state: ProState, week: Int? = null): Int {
            val skill = (state.pitcher.stuff + state.pitcher.command + state.pitcher.movement + state.pitcher.stamina) / 4
            if (usesCareerArcRules(state)) {
                val climate = liveClimate(state, week) ?: return DifficultyScale.pro(state.season)
                return DifficultyScale.proArc(
                    season = state.season,
                    level = state.level,
                    skill = skill,
                    climate = climate,
                    challenge = usesChallengeRules(state),
                )
            }
            return if (usesRetiredNumberLiveRules(state)) DifficultyScale.pro(state.season) else 0
        }

        public fun projectedPitcher(
            pitcher: PitcherSnapshot,
            effectiveAge: Int,
            proRulesVersion: Int = CURRENT_RULES_VERSION,
            recoveryYear: Boolean = false,
        ): PitcherSnapshot {
            val usesArc = proRulesVersion >= CAREER_ARC_RULES_VERSION
            val usesChallenge = proRulesVersion >= CAREER_CHALLENGE_RULES_VERSION
            if (usesChallenge) {
                val primary = if (effectiveAge < 31) 0 else if (effectiveAge < 34) 1 else 2
                val secondary = if (effectiveAge < 34) 0 else 1
                val primaryDecline = if (recoveryYear) max(0, primary - 1) else primary
                val secondaryDecline = if (recoveryYear) 0 else secondary
                if (primaryDecline <= 0 && secondaryDecline <= 0) return pitcher
                return pitcher.copy(
                    stuff = (pitcher.stuff - primaryDecline).coerceIn(20, 80),
                    command = (pitcher.command - secondaryDecline).coerceIn(20, 80),
                    movement = (pitcher.movement - primaryDecline).coerceIn(20, 80),
                    stamina = (pitcher.stamina - secondaryDecline).coerceIn(20, 80),
                )
            }
            val decline = when {
                effectiveAge < 33 -> 0
                usesArc && effectiveAge >= 35 -> if (recoveryYear) 1 else 2
                else -> 1
            }
            if (decline <= 0) return pitcher
            return pitcher.copy(
                stuff = (pitcher.stuff - decline).coerceIn(20, 80),
                movement = (pitcher.movement - decline).coerceIn(20, 80),
            )
        }
    }

    private val automaticOuting = ProAutomaticOutingSimulator(pitch)

    public fun startLinked(request: ProStartLinkedRequest): ProResult {
        val seed = seed(request.seed)
        require(request.entitlement.active) { "pro.entitlement_inactive" }
        require(request.highSchoolCareerId.isNotBlank()) { "pro.linked.career_id" }
        require(request.identityName.isNotBlank() && request.identityName.length <= 12) { "pro.player_name" }
        require(request.draftEvaluation in 0..100) { "pro.draft_evaluation" }
        val team = ProCatalog.team(request.teamId)
        val state = initialState(
            seedText = request.seed,
            mode = ProStartMode.LINKED,
            sourceHighSchoolCareerId = request.highSchoolCareerId,
            highSchoolLegacyContext = request.highSchoolLegacyContext,
            activeHighSchoolPreserved = request.activeHighSchoolPreserved,
            identityName = request.identityName,
            pitcher = request.pitcher.copy(name = request.identityName),
            team = team,
            entitlement = request.entitlement,
            draftEvaluation = request.draftEvaluation,
        )
        val journey = state.journeyState!!.let { base ->
            if (request.draftRound == null) base else {
                require(request.draftRound >= 1 && (request.signingBonus ?: 0) > 0 && (request.overallPick ?: 0) > 0) { "pro.invalid_draft" }
                base.copy(reputation = base.reputation.copy(fanSupport = request.sourceFanInterest?.let { (5 + it.coerceAtLeast(0) / 2).coerceIn(5, 30) } ?: (5 + (request.draftEvaluation - 50).coerceAtLeast(0) / 2).coerceIn(5, 25)), pendingContractMarket = ProJourneyKernel.rookieMarket(state.careerId, team.id, state.revision,
                    draftRound = request.draftRound, signingBonus = request.signingBonus!!, overallPick = request.overallPick!!))
            }
        }
        return result(state.copy(pitchLearningProject = request.pitchLearningProject, journeyState = journey), seed.nextSeed(), listOf("pro_career_started", "pro_linked_start"))
    }

    public fun startDirect(request: ProStartDirectRequest): ProResult {
        val seed = seed(request.seed)
        require(request.playerName.isNotBlank() && request.playerName.length <= 12) { "pro.player_name" }
        val pitcher = ProCatalog.pitcherForPreset(request.presetId, request.playerName)
        val team = ProCatalog.teamForSeed(seed.value)
        val initial = initialState(
            seedText = request.seed,
            mode = ProStartMode.DIRECT,
            sourceHighSchoolCareerId = request.activeHighSchoolCareerId,
            highSchoolLegacyContext = null,
            activeHighSchoolPreserved = request.activeHighSchoolCareerId != null,
            identityName = request.playerName,
            pitcher = pitcher,
            team = team,
            entitlement = ProEntitlement(),
            draftEvaluation = 72,
        )
        val signed = signContractInternal(initial)
        val startNext = seed.nextValue()
        val contractNext = SplitMix64(startNext).next()
        return result(signed, contractNext.toString(), listOf("pro_career_started", "pro_direct_start", "rookie_contract_signed"))
    }

    public fun signContract(state: ProState, seedText: String): ProResult {
        validate(state, ProCareerPhase.CONTRACT_OFFER)
        val market = state.journeyState?.pendingContractMarket
        if (market != null) {
            val offer = market.offers.firstOrNull() ?: throw ProKernelException("pro.contract_offer_missing")
            return acceptContractOffer(state, seedText, offer.id, null)
        }
        val seed = seed(seedText)
        return result(signContractInternal(state), seed.nextSeed(), listOf("rookie_contract_signed"))
    }

    public fun acceptContractOffer(
        state: ProState,
        seedText: String,
        offerId: String,
        ambition: ProCareerAmbition?,
    ): ProResult {
        validate(state, ProCareerPhase.CONTRACT_OFFER)
        val journey = state.journeyState ?: throw ProKernelException("pro.contract_market_missing")
        val market = journey.pendingContractMarket ?: throw ProKernelException("pro.contract_market_missing")
        val offer = market.offers.firstOrNull { it.id == offerId } ?: throw ProKernelException("pro.contract_offer_missing")
        val completedGoals = journey.goalHistory.filter { it.outcome == ProCareerGoalOutcome.COMPLETED }.map { it.ambition }.toSet()
        require(ambition != null || completedGoals.size == ProCareerAmbition.entries.size) { "pro.ambition_required" }
        require(ambition == null || ambition !in completedGoals) { "pro.ambition_already_completed" }
        val accepted = ProJourneyCommandKernel.apply(
            journey,
            state.careerId,
            ProJourneyCommandEnvelope(
                commandId = "accept-$offerId-${state.revision}",
                sessionId = state.careerId,
                expectedRevision = 0UL,
                command = ProJourneyCommand.AcceptContract(market.id, offer.id, ambition),
            ),
        ).state
        val team = ProCatalog.team(offer.teamId)
        val contract = ProContract(offer.years, offer.annualSalary.toInt().coerceAtLeast(1), offer.rolePromise)
        val isRookie = market.kind == ProContractMarketKind.ROOKIE
        val phase = if (isRookie) ProCareerPhase.WEEKLY_PLAN else ProCareerPhase.OFFSEASON_INVESTMENT
        val projected = state.copy(team = team, role = offer.rolePromise, contract = contract)
        val tensions = seasonTensions(projected)
        val signedTransition = journey.offseasonTransition?.copy(route = ProOffseasonTransitionRoute.UNDER_CONTRACT)
        val next = signed(
            state.copy(
                revision = state.revision + 1UL,
                phase = phase,
                team = team,
                role = offer.rolePromise,
                rolePreference = offer.rolePromise,
                contract = contract,
                journeyState = accepted.copy(offseasonTransition = signedTransition),
                milestones = state.milestones.addUnique(if (isRookie) "신인 계약" else "새 계약"),
                news = (listOf("${team.name}과 ${offer.years}년 계약 · 연봉 ${offer.annualSalary}원") + state.news).take(30),
                seasonTensions = if (isRookie) tensions else state.seasonTensions,
                standings = deriveStandings(projected),
                leaderboards = deriveLeaderboards(projected),
                commitment = "",
            ),
        )
        val seed = seed(seedText)
        return result(next, seedText, listOf(if (isRookie) "rookie_contract_signed" else "pro_contract_accepted"))
    }

    public fun normalizeBalance(state: ProState): ProResult {
        validateSavedState(state)
        val normalized = signed(state.copy(commitment = ""))
        return ProResult(normalized, state.seed, emptyList())
    }

    public fun requestRole(state: ProState, seedText: String, requested: ProRole): ProResult {
        validate(state, ProCareerPhase.WEEKLY_PLAN)
        seed(seedText)
        require(ProRoleRequestRules.shouldOffer(state)) { "pro.role_request.unavailable" }
        val outcome = ProRoleRequestRules.evaluate(state, requested)
        val rejected = outcome == ProRoleRequestOutcome.REJECTED
        val request = ProRoleRequestState(requested, outcome, if (outcome == ProRoleRequestOutcome.CONDITIONAL) ProRoleRequestRules.REVIEW_WEEK else 0, state.season)
        val news = when (outcome) {
            ProRoleRequestOutcome.ACCEPTED -> "${requested.label} 지원을 받아들였습니다. 다음 등판부터 준비합니다."
            ProRoleRequestOutcome.CONDITIONAL -> "${requested.label} 지원을 접수했습니다. 6주차에 역할을 다시 면담합니다."
            ProRoleRequestOutcome.REJECTED -> "${requested.label} 준비가 더 필요합니다. 현재 보직을 유지합니다."
        }
        return result(state.copy(revision = state.revision + 1UL,
            rolePreference = if (rejected) state.rolePreference else requested,
            managerTrust = (state.managerTrust - if (rejected) 1 else 0).coerceAtLeast(0),
            roleRequest = request, news = (listOf(news) + state.news).take(30), commitment = ""), seedText, listOf("pro_role_requested"))
    }

    public fun planWeek(state: ProState, seedText: String, plan: ProWeekPlan, targetPitch: PitchKind? = null): ProResult {
        validate(state, ProCareerPhase.WEEKLY_PLAN)
        val seed = seed(seedText)
        val nextWeek = state.week + 1
        require(nextWeek <= ProCatalog.WEEKS_PER_SEASON) { "pro.week_limit" }
        val recovering = state.injuryWeeks > 0
        val skill = (state.pitcher.stuff + state.pitcher.command + state.pitcher.movement + state.pitcher.stamina) / 4
        val roles = when (state.role) {
            ProRole.STARTER -> Triple(1, 18, 96)
            ProRole.LONG_RELIEF -> Triple(2, 6, 42)
            ProRole.SETUP, ProRole.CLOSER -> Triple(3, 3, 24)
        }
        var activeModifiers = state.activeDecisionModifiers.orEmpty().filter { it.expiresWeek >= nextWeek }
        var outings = roles.first
        if (activeModifiers.any { it.suppressOutings }) outings = 0
        else if (!recovering) {
            activeModifiers = activeModifiers.map { modifier ->
                val remaining = max(0, modifier.extraOutingChance - (modifier.extraOutingsGranted ?: 0))
                outings += remaining
                if (remaining == 0) modifier else modifier.copy(extraOutingsGranted = (modifier.extraOutingsGranted ?: 0) + remaining)
            }
        }
        val lines = mutableListOf<ProGameLine>()
        var outs = 0
        var strikeouts = 0
        var walks = 0
        var runsAllowed = 0
        var hits = 0
        var homeRuns = 0
        var pitches = 0
        var rng = SplitMix64(seed.value)
        val weekClimate = liveClimate(state, nextWeek)
        val weekOffset = liveBatterOffset(state, nextWeek)
        val weekCallPolicy = if (usesCareerArcRules(state)) {
            ProSeasonClimateRules.callPolicy(weekClimate ?: ProSeasonClimate.EVEN)
        } else {
            AutoCallPolicy.PERFECT
        }
        if (!recovering) {
            repeat(outings) { outingIndex ->
                val weekSalt = nextWeek.toULong() * 0x9E37UL
                val baseSeed = (rng.next() xor weekSalt) + outingIndex.toULong()
                val line = automaticOuting.simulate(
                    pitcher = PitchLearningRules.playable(state.pitcher, state.pitchLearningProject),
                    startingFatigue = state.fatigue + outingIndex * 5,
                    outsTarget = roles.second,
                    pitchCap = roles.third,
                    baseSeed = baseSeed,
                    batterOffset = weekOffset,
                    callPolicy = weekCallPolicy,
                    diverseScouting = usesWeeklyDecisionRules(state),
                )
                outs += line.outs
                strikeouts += line.strikeouts
                walks += line.walks
                runsAllowed += line.runsAllowed
                pitches += line.pitches
                hits += line.hits
                homeRuns += line.homeRuns
                val support = ProLeagueBaseline.teamRuns(rng)
                val opponentRuns = line.runsAllowed + ProLeagueBaseline.restOfTeamRuns(max(0, 27 - line.outs), rng)
                val started = state.role == ProRole.STARTER
                lines += ProGameLine(
                    season = state.season,
                    week = nextWeek,
                    outingNumber = state.currentGameLines.size + lines.size + 1,
                    started = started,
                    outs = line.outs,
                    strikeouts = line.strikeouts,
                    walks = line.walks,
                    runsAllowed = line.runsAllowed,
                    pitches = line.pitches,
                    teamRuns = support,
                    opponentRuns = opponentRuns,
                    decision = proDecision(started, state.role == ProRole.CLOSER, line.outs, line.runsAllowed, support, opponentRuns),
                    played = false,
                    hits = line.hits,
                    homeRuns = line.homeRuns,
                )
            }
        }
        val games = if (recovering) 0 else outings
        val starts = lines.count { it.started }
        val trainingLoad = when (plan) {
            ProWeekPlan.DEVELOP_STUFF -> 10
            ProWeekPlan.DEVELOP_MOVEMENT -> 8
            ProWeekPlan.DEVELOP_WEAPON -> 9
            ProWeekPlan.REFINE_COMMAND -> 6
            ProWeekPlan.BUILD_STAMINA -> 7
            ProWeekPlan.RECOVER -> -16
            ProWeekPlan.EARN_TRUST -> 5
        }
        val outingLoad = (pitches + 14) / 15
        val staminaRelief = max(0, (state.pitcher.stamina - 50) / 15)
        val fatigueDelta = if (recovering) -20 else trainingLoad + outingLoad - staminaRelief
        val fatigue = clamp(state.fatigue + fatigueDelta, 0, 100)
        val injuryRoll = rng.nextInt(100)
        val fatiguePressure = max(activeModifiers.mapNotNull { it.injuryPressureFloor }.maxOrNull() ?: 0, injuryPressure(
            rawFatigue = fatigue,
            stamina = state.pitcher.stamina,
            mastery = state.pitcher.effectiveMastery.stamina,
            challengeRules = usesChallengeRules(state),
        ))
        // A healthy, low-fatigue week is safe. The former minimum-percent floor left a hidden
        // two-percent roll even when the player managed workload well. An overload
        // event also requires a real outing so recovery is an actionable answer.
        val injuryChancePercent = max(0, fatiguePressure - 72)
        val generatedInjury = if (!recovering && pitches > 0 && injuryRoll < injuryChancePercent) {
            2 + rng.nextInt(4)
        } else {
            max(0, state.injuryWeeks - 1)
        }
        val injuryMitigationConsumed = state.injuryWeeks == 0
            && generatedInjury > 0
            && state.journeyState?.activeSeasonBenefit?.kind == ProSeasonBenefitKind.INJURY_MITIGATION
            && state.journeyState?.activeSeasonBenefit?.remainingCharges == 1
        val injuryWeeks = if (injuryMitigationConsumed) max(0, generatedInjury - 1) else generatedInjury
        val performanceTrust = when {
            runsAllowed <= 2 -> 3
            runsAllowed == 3 -> 0
            runsAllowed <= 5 -> -3
            else -> -6
        }
        val rawTrustGain = when {
            recovering -> -1
            plan == ProWeekPlan.EARN_TRUST -> 5
            plan == ProWeekPlan.RECOVER -> 0
            else -> performanceTrust
        }
        val trustGain = if (usesChallengeRules(state) && state.managerTrust >= 85 && rawTrustGain > 0) {
            rawTrustGain / 2
        } else {
            rawTrustGain
        }
        val managerTrust = clamp(state.managerTrust + trustGain, 0, 100)
        val currentStats = state.currentStats.copy(
            games = state.currentStats.games + games,
            starts = state.currentStats.starts + starts,
            inningsOuts = state.currentStats.inningsOuts + outs,
            strikeouts = state.currentStats.strikeouts + strikeouts,
            walks = state.currentStats.walks + walks,
            runsAllowed = state.currentStats.runsAllowed + runsAllowed,
            hits = state.currentStats.hits + hits,
            homeRuns = state.currentStats.homeRuns + homeRuns,
            pitches = state.currentStats.pitches + pitches,
            wins = state.currentStats.wins + lines.count { it.decision == ProPitchingDecision.WIN },
            losses = state.currentStats.losses + lines.count { it.decision == ProPitchingDecision.LOSS },
            saves = state.currentStats.saves + lines.count { it.decision == ProPitchingDecision.SAVE },
        )
        val earnedCallUp = managerTrust >= 60 && skill >= 46 &&
            (state.season > 1 || currentStats.games >= 12 || currentStats.strikeouts >= 40)
        val demoted = state.level == ProLevel.MAJOR && managerTrust < ProCatalog.DEMOTION_TRUST && !recovering
        val level = if (demoted) ProLevel.MINOR else if (state.level == ProLevel.MAJOR || earnedCallUp) ProLevel.MAJOR else ProLevel.MINOR
        val assignedRole = if (level == ProLevel.MAJOR) {
            when {
                managerTrust >= 74 -> ProRole.STARTER
                managerTrust >= 62 -> ProRole.LONG_RELIEF
                else -> ProRole.SETUP
            }
        } else if (managerTrust >= 52) ProRole.STARTER else ProRole.LONG_RELIEF
        val role = state.rolePreference ?: assignedRole
        val development = resolveDevelopment(state.pitcher, state.developmentProgress, plan, targetPitch, recovering || state.journeyState?.recoveryYearPending == true, usesLiveOutingRules(state),
            activeModifiers.mapNotNull { it.trainingEfficiencyPermille }.minOrNull() ?: 1_000)
        val priorImportantGames = state.importantGames
        val regularTrigger = if (nextWeek >= ProCatalog.WEEKS_PER_SEASON || lines.isEmpty() || injuryWeeks > 0) {
            null
        } else {
            importantGameTrigger(state, nextWeek, level, managerTrust, currentStats, skill, priorImportantGames)
        }
        val postseasonEvaluation = state.copy(week = nextWeek, currentStats = currentStats, currentGameLines = state.currentGameLines + lines)
        val endOfSeasonPostseason = if (nextWeek >= ProCatalog.WEEKS_PER_SEASON && usesAutumnRules(state)) {
            val evaluated = ProPostseasonRules.playerPath(
                ProPostseasonRules.evaluateEndOfSeason(postseasonEvaluation),
                level,
                injuryWeeks,
            )
            if (usesFinalSeriesRules(state)) ProPostseasonRules.preparingSeries(evaluated, postseasonEvaluation) else evaluated
        } else null
        val autumnTrigger = endOfSeasonPostseason
            ?.takeIf { it.result == ProPostseasonResult.IN_PROGRESS }
            ?.currentRound
            ?.let { ProPostseasonRules.trigger(it) }
        val trigger = autumnTrigger ?: regularTrigger
        val decisionsThisSeason = state.decisionHistory.count { it.season == state.season }
        val openDecision = nextWeek < ProCatalog.WEEKS_PER_SEASON &&
            ProCatalog.decisionWeeks(state.proRulesVersion).contains(nextWeek) && trigger == null &&
            !recovering && injuryWeeks == 0 && decisionsThisSeason < ProCatalog.maximumDecisions(state.proRulesVersion)
        val decisionSource = if (usesWeeklyDecisionRules(state)) state.copy(pitcher = development.pitcher, role = role, managerTrust = managerTrust, fatigue = fatigue, currentStats = currentStats, currentGameLines = state.currentGameLines + lines) else state
        val pending = if (openDecision) seasonDecision(decisionSource, nextWeek, weekClimate, managerTrust) else null
        val phase = when {
            nextWeek >= ProCatalog.WEEKS_PER_SEASON ->
                if (autumnTrigger != null) ProCareerPhase.IMPORTANT_GAME else ProCareerPhase.SEASON_REVIEW
            trigger != null -> ProCareerPhase.IMPORTANT_GAME
            pending != null -> ProCareerPhase.SEASON_DECISION
            else -> ProCareerPhase.WEEKLY_PLAN
        }
        val rival = trigger?.let {
            ProCatalog.rivalFor(state.team.id, state.season, nextWeek, it, endOfSeasonPostseason?.series?.opponentTeamId)
        }
        val segment = ProCatalog.segment(nextWeek)
        val news = state.news.toMutableList()
        val milestones = state.milestones.toMutableList()
        val injuryEvent = if (injuryWeeks > 0 && state.injuryWeeks == 0) {
            ProInjuryEventSnapshot(
                season = state.season,
                week = nextWeek,
                plan = plan,
                rawFatigue = fatigue,
                effectiveFatigue = fatiguePressure,
                pitches = pitches,
                recoveryWeeks = injuryWeeks,
                careerId = state.careerId,
                revision = state.revision + 1UL,
            )
        } else null
        if (state.week == 0) milestones.addUnique("프로 첫 공식 등판")
        news.add(0, if (state.week == 0) "프로 첫 공식 등판을 마쳤습니다. ${games}경기에서 ${strikeouts}개의 삼진을 잡았습니다." else "${nextWeek}주차 · ${games}경기 · ${strikeouts}K · ${walks}볼넷 · ${runsAllowed}실점")
        if (state.level != level) {
            if (level == ProLevel.MAJOR) {
                milestones.addUnique("1군 콜업")
                news.add(0, "2군 기록과 감독의 믿음을 쌓아 1군 출전 명단에 합류했습니다.")
            } else news.add(0, "최근 등판이 이어지지 않아 2군으로 내려갑니다. 기록을 다시 쌓아야 합니다.")
        }
        if (state.role != role) {
            milestones.addUnique("${state.season}시즌 ${role.label} 역할")
            news.add(0, "감독 면담 뒤 다음 등판부터 ${role.label} 역할을 맡습니다.")
        }
        addCareerMilestones(state, games, strikeouts, milestones)
        if (injuryWeeks > 0 && state.injuryWeeks == 0) news.add(0, "과부하로 ${injuryWeeks}주 부상자 명단에 올랐습니다.")
        if (development.labels.isNotEmpty()) news.add(0, "주간 성장 완성 · ${development.labels.joinToString(" · ")}")
        if (segment != state.seasonSegment) news.add(0, ProCatalog.segmentEntryNews(segment))
        if (usesCareerArcRules(state) && weekClimate != null && weekClimate != ProSeasonClimate.EVEN) {
            news.add(0, ProSeasonClimateRules.newsLine(weekClimate, nextWeek))
        }
        if (endOfSeasonPostseason != null) {
            when (endOfSeasonPostseason.result) {
                ProPostseasonResult.DID_NOT_QUALIFY ->
                    news.add(0, "정규시즌이 끝났습니다. 올해는 플레이오프에 들지 못했습니다.")
                ProPostseasonResult.IN_PROGRESS ->
                    news.add(0, ProPostseasonRules.qualificationNews(endOfSeasonPostseason.seed))
                ProPostseasonResult.UNAVAILABLE ->
                    news.add(0, ProPostseasonRules.unavailableNews(level))
                else -> Unit
            }
        }
        if (phase == ProCareerPhase.IMPORTANT_GAME && trigger != null) news.add(0, importantHeadline(trigger, rival, level))
        var nextJourney = state.journeyState
        if (injuryMitigationConsumed) {
            nextJourney = nextJourney?.copy(activeSeasonBenefit = null)
        } else if (
            usesCareerArcRules(state) &&
            nextJourney?.activeSeasonBenefit?.kind == ProSeasonBenefitKind.CLIMATE_STABILIZATION
        ) {
            val charges = nextJourney.activeSeasonBenefit?.remainingCharges ?: 0
            if (charges > 0) {
                val remaining = charges - 1
                nextJourney = nextJourney.copy(
                    activeSeasonBenefit = if (remaining > 0) {
                        ProSeasonBenefit(ProSeasonBenefitKind.CLIMATE_STABILIZATION, null, remaining)
                    } else null,
                )
            }
        }
        val project = state.pitchLearningProject
        val learning = if (!recovering && plan == ProWeekPlan.DEVELOP_MOVEMENT && project != null && !project.completed && targetPitch == project.pitchType) project.practice(2) else project
        var finalPitcher = if (project != null && learning != null) development.pitcher.copy(pitchProfiles = PitchLearningRules.advance(development.pitcher.pitchProfiles.orEmpty(), project, learning)) else development.pitcher
        var finalTrust = managerTrust
        val followUps = state.resolvedFollowUps.orEmpty().toMutableList()
        val qualityStarts = lines.count { it.started && it.outs >= 18 && it.runsAllowed <= 3 }
        val tracked = activeModifiers.map { it.copy(qualityStarts = it.qualityStarts + qualityStarts, runsAllowed = it.runsAllowed + runsAllowed) }
        val expired = tracked.filter { it.expiresWeek <= nextWeek }
        for (modifier in expired) {
            val beforeCommand = finalPitcher.command
            if (modifier.commandDelta != 0) finalPitcher = applyEffect(finalPitcher, ProDecisionEffect(commandDelta = -modifier.commandDelta))
            if (modifier.suppressOutings) finalTrust = (finalTrust + 4).coerceAtMost(100)
            val followUp = ProWeeklyDecisionRules.followUp(modifier, finalPitcher, state.season, nextWeek,
                (finalPitcher.command - beforeCommand).takeIf { modifier.commandDelta != 0 })
            followUps += followUp
            news.add(0, "결정 결과 · ${ProWeeklyDecisionRules.title(modifier.type)} · ${ProWeeklyDecisionRules.summary(followUp)}")
        }
        val updated = state.copy(
            revision = state.revision + 1UL,
            pitcher = finalPitcher,
            pitchLearningProject = learning,
            week = nextWeek,
            phase = phase,
            level = level,
            role = role,
            managerTrust = finalTrust,
            fatigue = fatigue,
            injuryWeeks = injuryWeeks,
            currentStats = currentStats,
            currentGameLines = state.currentGameLines + lines,
            milestones = milestones,
            news = news.take(30),
            developmentProgress = development.progress,
            seasonSegment = segment,
            seasonTrigger = trigger,
            currentRival = rival,
            seasonTensions = if (state.seasonTensions.isEmpty()) seasonTensions(state) else state.seasonTensions,
            importantGames = priorImportantGames + if (phase == ProCareerPhase.IMPORTANT_GAME && autumnTrigger == null) 1 else 0,
            pendingDecision = pending,
            activeDecisionModifiers = tracked.filter { it.expiresWeek > nextWeek }.takeIf { it.isNotEmpty() },
            resolvedFollowUps = followUps.takeIf { it.isNotEmpty() },
            journeyState = nextJourney,
            postseason = endOfSeasonPostseason,
            standings = deriveStandings(state.copy(week = nextWeek, currentGameLines = state.currentGameLines + lines, currentStats = currentStats)),
            leaderboards = deriveLeaderboards(state.copy(week = nextWeek, currentStats = currentStats, currentGameLines = state.currentGameLines + lines)),
            activePitch = null,
            lastPresentation = null, lastBattedBall = null, lastFielding = null,
            commitment = "",
        )
        val events = buildList {
            add("pro_week_resolved")
            if (expired.isNotEmpty()) add("pro_weekly_decision_followup_resolved")
            add(if (state.level != level && level == ProLevel.MAJOR) "major_call_up" else "weekly_progress")
            if (injuryEvent != null) add("pro_injury_started")
            if (phase == ProCareerPhase.SEASON_DECISION) add("pro_season_decision_opened")
            if (phase == ProCareerPhase.IMPORTANT_GAME) add("pro_important_game_opened")
            if (phase == ProCareerPhase.SEASON_REVIEW) add("pro_season_review_opened")
        }
        return result(updated, seed.nextSeed(rng.next()), events, injuryEvent = injuryEvent)
    }

    public fun advanceSegment(
        state: ProState,
        seedText: String,
        plan: ProWeekPlan,
        targetPitch: PitchKind? = null,
        maximumWeeks: Int = ProCatalog.WEEKS_PER_SEASON,
    ): ProResult {
        require(maximumWeeks in 1..ProCatalog.WEEKS_PER_SEASON) { "pro.segment.maximum_weeks" }
        validate(state, ProCareerPhase.WEEKLY_PLAN)
        val start = state.seasonSegment
        var current = state
        var seed = seedText
        var advanced = 0
        var stop = "maximum_weeks"
        var final: ProResult? = null
        while (advanced < maximumWeeks && current.phase == ProCareerPhase.WEEKLY_PLAN) {
            val before = current
            final = planWeek(current, seed, plan, targetPitch)
            current = final.state
            seed = final.nextSeed
            advanced += 1
            stop = when {
                current.seasonSegment != start -> "segment_changed"
                current.role != before.role -> "role_changed"
                current.level != before.level -> "level_changed"
                current.injuryWeeks > before.injuryWeeks -> "injury"
                current.phase != ProCareerPhase.WEEKLY_PLAN -> "phase_changed"
                else -> "maximum_weeks"
            }
            if (stop != "maximum_weeks") break
        }
        val completed = final ?: throw ProKernelException("pro.segment.no_progress")
        val progress = ProSegmentProgress(advanced, start, current.seasonSegment, stop, plan, targetPitchFor(plan, targetPitch, state.pitcher))
        return completed.copy(
            events = completed.events + "pro_segment_advanced",
            segmentProgress = progress,
            state = signed(current.copy(lastSegmentProgress = progress, commitment = "")),
        )
    }

    public fun applySeasonDecision(state: ProState, seedText: String, decisionId: String, choiceId: String): ProResult {
        require(state.phase == ProCareerPhase.SEASON_DECISION) {
            "pro.expected_phase:${ProCareerPhase.SEASON_DECISION.wire}:${state.phase.wire}"
        }
        validateSavedState(state)
        seed(seedText)
        val pending = state.pendingDecision ?: throw ProKernelException("pro.decision_missing")
        require(pending.id == decisionId) { "pro.decision_stale" }
        require(state.decisionHistory.none { it.decisionId == pending.id }) { "pro.decision_duplicate" }
        val choice = pending.choices.firstOrNull { it.id == choiceId } ?: throw ProKernelException("pro.choice_unknown")
        val effect = choice.effect
        var appliedPitcher = applyEffect(state.pitcher, effect)
        if (pending.type == ProSeasonDecisionType.NEW_PITCH_TRIAL) appliedPitcher = ProWeeklyDecisionRules.applyingPitchTrial(appliedPitcher, choice.id)
        val modifier = if (pending.type.isWeeklyBinary) ProWeeklyDecisionRules.modifier(pending, choice, appliedPitcher) else null
        val history = state.decisionHistory + ProDecisionRecord(pending.id, pending.type, pending.season, pending.week, choice.id, choice.title, effect, modifier?.expiresWeek)
        val rolePreference = if (pending.type == ProSeasonDecisionType.ROLE_MEETING || pending.type == ProSeasonDecisionType.FORM_CRISIS || pending.type == ProSeasonDecisionType.AGING_CROSSROADS) {
            effect.roleTarget ?: state.role
        } else {
            state.rolePreference
        }
        val mediaEffect = if (pending.type == ProSeasonDecisionType.MEDIA_OPPORTUNITY) mediaJourneyEffect(choice.id) else null
        var nextJourney = if (mediaEffect != null && state.journeyState != null) {
            ProJourneyKernel.applyMediaChoice(
                state.journeyState,
                state.careerId,
                state.season,
                pending.id,
                choice.id,
                mediaEffect.income,
                mediaEffect.fanDelta,
                mediaEffect.communityDelta,
                state.team.id,
            )
        } else {
            state.journeyState
        }
        if (pending.type == ProSeasonDecisionType.AGING_CROSSROADS && choice.id.endsWith(".recovery_year")) nextJourney = nextJourney?.copy(recoveryYearPending = true)
        if (pending.type == ProSeasonDecisionType.FORM_CRISIS && choice.id.endsWith(".recover")) nextJourney = nextJourney?.copy(activeSeasonBenefit = ProSeasonBenefit(ProSeasonBenefitKind.CLIMATE_STABILIZATION, null, 2))
        val next = state.copy(
            revision = state.revision + 1UL,
            phase = ProCareerPhase.WEEKLY_PLAN,
            pitcher = appliedPitcher,
            activeDecisionModifiers = (state.activeDecisionModifiers.orEmpty() + listOfNotNull(modifier)).takeIf { it.isNotEmpty() },
            role = effect.roleTarget ?: state.role,
            rolePreference = rolePreference,
            managerTrust = clamp(state.managerTrust + effect.managerTrustDelta, 0, 100),
            catcherTrust = clamp(state.catcherTrust + effect.catcherTrustDelta, 0, 100),
            fatigue = clamp(state.fatigue + effect.fatigueDelta, 0, 100),
            pendingDecision = null,
            decisionHistory = history,
            news = (listOf("${pending.title} · ${choice.title} — ${effect.summary()}") + state.news).take(30),
            journeyState = nextJourney,
            commitment = "",
        )
        return result(next, seedText, listOf("pro_season_decision_resolved"))
    }

    public fun reserveImportantGame(state: ProState, seedText: String): ProResult {
        validate(state, ProCareerPhase.IMPORTANT_GAME)
        require(state.activePitch == null) { "pro.pitch_already_reserved" }
        var availabilityState = state
        if (
            usesFinalSeriesRules(state) &&
            ProPostseasonRules.isAutumn(state.seasonTrigger) &&
            state.postseason != null &&
            ProPostseasonRules.requiresAvailabilityDecision(state.postseason, state.role)
        ) {
            availabilityState = choosePostseasonAvailability(state, seedText, ProPostseasonAvailabilityChoice.PITCH_AGAIN).state
        }
        val seed = seed(seedText)
        val rival = availabilityState.currentRival ?: ProCatalog.rivalFor(availabilityState.team.id, availabilityState.season, availabilityState.week, availabilityState.seasonTrigger ?: ProSeasonTrigger.STANDINGS_RACE)
        val batter = BatterSnapshot(
            id = rival.id,
            name = rival.name,
            contact = 48 + (proHash(rival.id) % 13UL).toInt(),
            discipline = 45 + (proHash("discipline|${rival.id}") % 18UL).toInt(),
            power = 45 + (proHash("power|${rival.id}") % 20UL).toInt(),
            batSide = if (proHash("side|${rival.id}") % 2UL == 0UL) BatSide.RIGHT else BatSide.LEFT,
        )
        val scouting = BatterScoutingSnapshot(
            hotZone = com.solkim.baseball.core.pitch.PitchZone(1, 1),
            coldZone = com.solkim.baseball.core.pitch.PitchZone(0, 2),
            pitchStrength = PitchKind.FOUR_SEAM,
            pitchWeakness = PitchKind.CURVEBALL,
            chaseTendency = batter.discipline.coerceIn(20, 80),
        )
        val entryInning = postseasonEntryInning(availabilityState)
        val context = PlateAppearanceContext(
            plateAppearanceId = "${availabilityState.careerId}:season:${availabilityState.season}:week:${availabilityState.week}:important",
            revision = 0UL,
            inning = entryInning,
            outs = 1,
            balls = 0,
            strikes = 0,
            pitchNumber = 1,
            scoreDifferential = -1,
            leverage = 850,
            fatigue = availabilityState.fatigue,
        )
        val memory = RivalMemorySnapshot("${availabilityState.pitcher.id}:${batter.id}", 0UL, 0, 0, emptyList())
        val game = GameStateSnapshot(
            defense = DefenseSnapshot(50, 50, 50, listOf("pitcher", "catcher", "first_base", "second_base", "third_base", "shortstop", "left_field", "center_field", "right_field").map { FielderSnapshot("$it", it, it, 50, 50, 50) }),
            park = ParkSnapshot("pro-important-park", "중립 구장", 1_000, 1_000),
            runners = BaserunnerStateSnapshot(false, true, false, 52),
            runsAllowed = 0,
            inningState = InningStateSnapshot(entryInning, HalfInning.TOP, 1),
        )
        val log = GameLogSnapshot("${availabilityState.careerId}:important:${availabilityState.importantGames}", 0UL, 0, emptyList())
        val preparation = pitch.prepare(PitchKernel.PrepareRequest(seedText, PitchLearningRules.playable(availabilityState.pitcher, availabilityState.pitchLearningProject), batter, scouting, context, memory, game, log))
        val session = ProPitchSession(
            sessionId = "${availabilityState.careerId}:important:${availabilityState.importantGames}",
            week = availabilityState.week,
            seed = seedText,
            pitchIndex = 0,
            preparationToken = preparation.preparationToken,
            context = context,
            memory = memory,
            game = game,
            log = log,
            batter = batter,
            scouting = scouting,
            boundary = ProPitchBoundary.RESERVED,
        )
        val next = availabilityState.copy(revision = availabilityState.revision + 1UL, activePitch = session, lastPresentation = null, lastBattedBall = null, lastFielding = null, commitment = "")
        return result(next, seedText, listOf("pro_pitch_reserved"), preparation)
    }

    private fun postseasonEntryInning(state: ProState): Int = when (state.seasonTrigger) {
        ProSeasonTrigger.AUTUMN_WILD_CARD -> 9
        ProSeasonTrigger.AUTUMN_SEMIFINAL, ProSeasonTrigger.AUTUMN_PLAYOFF -> 8
        ProSeasonTrigger.AUTUMN_FINAL -> when (state.role) {
            ProRole.STARTER -> 6
            ProRole.LONG_RELIEF -> 5
            ProRole.SETUP -> 8
            ProRole.CLOSER -> 9
        }
        else -> 7
    }

    public fun submitPitch(state: ProState, sessionId: String, call: PitchCall, delivery: PitchDelivery = PitchDelivery.NEUTRAL): ProResult {
        validate(state, ProCareerPhase.IMPORTANT_GAME)
        val session = state.activePitch ?: throw ProKernelException("pro.pitch_missing")
        require(session.sessionId == sessionId) { "pro.pitch_session_stale" }
        require(!session.ended) { "pro.pitch_ended" }
        require(session.boundary != ProPitchBoundary.COMPLETED) { "pro.pitch_boundary_completed" }
        val preparation = pitch.prepare(PitchKernel.PrepareRequest(session.seed, PitchLearningRules.playable(state.pitcher, state.pitchLearningProject), session.batter, session.scouting, session.context, session.memory, session.game, session.log))
        require(preparation.preparationToken == session.preparationToken) { "pro.pitch_preparation_stale" }
        val submitted = pitch.submit(
            PitchKernel.SubmitRequest(session.seed, PitchLearningRules.playable(state.pitcher, state.pitchLearningProject), session.batter, session.scouting, session.context, session.preparationToken, call, session.memory, session.game, session.log),
            delivery,
        )
        val snapshot = submitted.snapshot
        val entry = submitted.gameLog.entries.lastOrNull()
        val sequencePitch = PitchSequencePitch(
            call.pitchType,
            call.zone,
            call.zoneIntent,
            PitchAbilityRules.nominalVelocity(state.pitcher, call.pitchType, call.intensity, session.context.fatigue) / 10,
            snapshot.outcome,
        )
        val sequenceMoment = PitchSequenceEvaluator.evaluate(
            session.sequencePitches,
            session.context,
            sequencePitch,
            preparation.rivalAdaptation,
        )
        val nextContext = snapshot.toProContext(session.context, submitted.gameState)
        val nextSession = session.copy(
            seed = submitted.nextSeed,
            pitchIndex = session.pitchIndex + 1,
            preparationToken = submitted.nextPreparation?.preparationToken ?: "",
            context = nextContext,
            memory = submitted.rivalMemory,
            game = submitted.gameState,
            log = submitted.gameLog,
            pitches = session.pitches + 1,
            strikeouts = session.strikeouts + if (snapshot.result == PlateAppearanceResult.STRIKEOUT) 1 else 0,
            walks = session.walks + if (snapshot.result == PlateAppearanceResult.WALK) 1 else 0,
            runsAllowed = session.runsAllowed + snapshot.runsScored,
            expectedDamage = session.expectedDamage + (entry?.expectedDamage ?: 0),
            actualDamage = session.actualDamage + (entry?.actualDamage ?: 0),
            recommendationAccepted = session.recommendationAccepted + if (snapshot.recommendationAccepted) 1 else 0,
            outs = session.outs + snapshot.inningTransition.outsRecorded,
            hits = session.hits + if (snapshot.outcome in setOf(PitchOutcome.SINGLE, PitchOutcome.DOUBLE, PitchOutcome.TRIPLE, PitchOutcome.HOME_RUN)) 1 else 0,
            homeRuns = session.homeRuns + if (snapshot.outcome == PitchOutcome.HOME_RUN) 1 else 0,
            abilityMoments = submitted.abilityMoment?.wire?.let { session.abilityMoments + it } ?: session.abilityMoments,
            sequenceMasteryCount = session.sequenceMasteryCount + if (sequenceMoment != null) 1 else 0,
            sequencePitches = if (snapshot.ended) emptyList() else (session.sequencePitches + sequencePitch).takeLast(3),
            ended = snapshot.ended,
            boundary = if (snapshot.ended) ProPitchBoundary.COMPLETED else ProPitchBoundary.PLAYING,
        )
        val next = state.copy(
            revision = state.revision + 1UL,
            activePitch = nextSession,
            pitchLearningProject = state.pitchLearningProject?.use(call.pitchType, session.context.plateAppearanceId, delivery, entry?.executionQuality ?: 0),
            lastPresentation = snapshot.trajectoryPresentation,
            lastBattedBall = snapshot.battedBall,
            lastFielding = snapshot.fieldingResolution,
            commitment = "",
        )
        return result(next, submitted.nextSeed, listOf("pro_pitch_submitted"), submitted.nextPreparation, snapshot.trajectoryPresentation)
    }

    public fun finishImportantGame(state: ProState): ProResult {
        validate(state, ProCareerPhase.IMPORTANT_GAME)
        val session = state.activePitch ?: throw ProKernelException("pro.pitch_missing")
        require(session.ended) { "pro.pitch_in_progress" }
        if (ProPostseasonRules.isAutumn(state.seasonTrigger)) {
            return finishAutumnGame(state, session)
        }
        if (state.seasonTrigger == ProSeasonTrigger.NATIONAL_FINAL) {
            return resolveNationalFinalFromSession(state, session)
        }
        val scheduledIndex = state.currentGameLines.indexOfLast { it.week == state.week && !it.played }
        val scheduled = scheduledIndex.takeIf { it >= 0 }?.let { state.currentGameLines[it] }
        val started = scheduled?.started ?: (state.role == ProRole.STARTER)
        val rng = SplitMix64(seed(session.seed).value)
        val directOuts = session.outs
        val scheduledOuts = scheduled?.outs ?: 0
        val complementOuts = max(0, scheduledOuts - directOuts)
        fun retained(value: Int): Int =
            if (scheduledOuts > 0) (value * complementOuts + scheduledOuts / 2) / scheduledOuts else 0
        val outs = if (scheduled == null) directOuts else complementOuts + directOuts
        val strikeouts = retained(scheduled?.strikeouts ?: 0) + session.strikeouts
        val walks = retained(scheduled?.walks ?: 0) + session.walks
        val runsAllowed = retained(scheduled?.runsAllowed ?: 0) + session.runsAllowed
        val pitches = retained(scheduled?.pitches ?: 0) + session.pitches
        val hits = retained(scheduled?.hits ?: 0) + session.hits
        val homeRuns = retained(scheduled?.homeRuns ?: 0) + session.homeRuns
        val opponentEarlier = rng.nextInt(4)
        val lateTeam = rng.nextInt(3)
        val lateBullpen = if (started) rng.nextInt(3) else 0
        val opponentRuns = opponentEarlier + runsAllowed + lateBullpen
        val teamRuns = max(0, opponentEarlier + session.context.scoreDifferential + lateTeam)
        val decision = proDecision(started, state.role == ProRole.CLOSER, outs, runsAllowed, teamRuns, opponentRuns)
        val line = ProGameLine(
            season = state.season,
            week = state.week,
            outingNumber = scheduled?.outingNumber ?: state.currentGameLines.size + 1,
            started = started,
            outs = outs,
            strikeouts = strikeouts,
            walks = walks,
            runsAllowed = runsAllowed,
            pitches = pitches,
            teamRuns = teamRuns,
            opponentRuns = opponentRuns,
            decision = decision,
            played = true,
            hits = hits,
            homeRuns = homeRuns,
        )
        val lines = state.currentGameLines.toMutableList()
        if (scheduledIndex >= 0) lines[scheduledIndex] = line else lines += line
        val priorGames = if (scheduled == null) 1 else 0
        val stats = state.currentStats.copy(
            games = state.currentStats.games + priorGames,
            starts = state.currentStats.starts + (if (scheduled == null && started) 1 else 0),
            inningsOuts = state.currentStats.inningsOuts - (scheduled?.outs ?: 0) + line.outs,
            strikeouts = state.currentStats.strikeouts - (scheduled?.strikeouts ?: 0) + line.strikeouts,
            walks = state.currentStats.walks - (scheduled?.walks ?: 0) + line.walks,
            runsAllowed = state.currentStats.runsAllowed - (scheduled?.runsAllowed ?: 0) + line.runsAllowed,
            hits = state.currentStats.hits - (scheduled?.hits ?: 0) + line.hits,
            homeRuns = state.currentStats.homeRuns - (scheduled?.homeRuns ?: 0) + line.homeRuns,
            pitches = state.currentStats.pitches - (scheduled?.pitches ?: 0) + line.pitches,
            wins = state.currentStats.wins - (if (scheduled?.decision == ProPitchingDecision.WIN) 1 else 0) + (if (decision == ProPitchingDecision.WIN) 1 else 0),
            losses = state.currentStats.losses - (if (scheduled?.decision == ProPitchingDecision.LOSS) 1 else 0) + (if (decision == ProPitchingDecision.LOSS) 1 else 0),
            saves = state.currentStats.saves - (if (scheduled?.decision == ProPitchingDecision.SAVE) 1 else 0) + (if (decision == ProPitchingDecision.SAVE) 1 else 0),
        )
        val sound = session.actualDamage <= session.expectedDamage + 150 || session.recommendationAccepted * 2 >= session.pitches
        val sequenceReward = session.sequenceMasteryCount.coerceIn(0, 3)
        val unresolved = state.decisionHistory.indices.filter { state.decisionHistory[it].season == state.season && state.decisionHistory[it].followUpResolvedWeek == null }
        val followUpReward = unresolved.size * if (sound) 2 else -1
        val trustDelta = session.strikeouts * 2 - session.walks * 2 - session.runsAllowed * 3 + (if (sound) 2 else 0) + sequenceReward + followUpReward
        val history = state.decisionHistory.toMutableList()
        unresolved.forEach { index -> history[index] = history[index].copy(followUpResolvedWeek = state.week) }
        val next = state.copy(
            revision = state.revision + 1UL,
            phase = ProCareerPhase.WEEKLY_PLAN,
            managerTrust = clamp(state.managerTrust + trustDelta, 0, 100),
            catcherTrust = clamp(state.catcherTrust + (if (sound) 2 else -1) + sequenceReward, 0, 100),
            currentStats = stats,
            currentGameLines = lines,
            seasonTrigger = null,
            currentRival = null,
            activePitch = null,
            lastPresentation = null, lastBattedBall = null, lastFielding = null,
            decisionHistory = history,
            milestones = if (state.level == ProLevel.MAJOR) state.milestones.addUnique("1군 첫 중요 승부") else state.milestones,
            news = (listOf("승부처 등판 · ${session.strikeouts}탈삼진 · ${session.walks}볼넷 · ${session.runsAllowed}실점 · 감독의 믿음 ${if (trustDelta >= 0) "+" else ""}$trustDelta") + state.news).take(30),
            standings = deriveStandings(state.copy(currentGameLines = lines, currentStats = stats)),
            leaderboards = deriveLeaderboards(state.copy(currentGameLines = lines, currentStats = stats)),
            commitment = "",
        )
        return result(next, rng.next().toString(), listOf("pro_important_game_resolved"))
    }

    private fun finishAutumnGame(state: ProState, session: ProPitchSession): ProResult {
        var rng = SplitMix64(seed(session.seed).value)
        val rawPostseason = state.postseason ?: ProPostseasonRules.evaluateEndOfSeason(state)
        val usesSeriesRules = usesFinalSeriesRules(state)
        val current = if (usesSeriesRules) ProPostseasonRules.preparingSeries(rawPostseason, state) else rawPostseason
        val support = max(0, session.context.scoreDifferential + session.runsAllowed + 1)
        val opponent = session.runsAllowed + max(0, -session.context.scoreDifferential)
        val legacyWon = support > opponent || (support == opponent && session.runsAllowed <= 1)
        val strengthEdge = ProPostseasonRules.teamStrengthEdgePermille(state)
        val resolvedGame = if (usesSeriesRules) {
            resolvePostseasonGame(state, session, strengthEdge, rng)
        } else null
        val won = resolvedGame?.won ?: legacyWon
        var automaticSummaries = emptyList<String>()
        var automaticGames = 0
        val nextPostseason: ProPostseasonState
        if (usesSeriesRules) {
            val game = resolvedGame ?: throw ProKernelException("pro.postseason_remainder_missing")
            val gameNumber = current.series?.nextGameNumber ?: 1
            val played = ProPostseasonRules.resolvingSeriesGame(
                current,
                won = game.won,
                directlyPlayed = true,
                pitches = session.pitches,
                outs = session.outs,
                runsAllowed = session.runsAllowed,
                teamRuns = game.teamRuns,
                opponentRuns = game.opponentRuns,
                rivalMemory = session.memory,
                strikeouts = session.strikeouts,
                walks = session.walks,
                hits = session.hits,
                started = state.role == ProRole.STARTER,
            )
            val prepared = if (played.result == ProPostseasonResult.IN_PROGRESS) {
                ProPostseasonRules.preparingSeries(played, state)
            } else played
            val simulated = simulatePostseasonTeamGames(prepared, state, state.role, strengthEdge, forceCurrentGame = false, rng)
            nextPostseason = simulated.state
            val directSummary = if (current.currentRound == ProAutumnRound.FINAL) {
                "우승 결정전 ${gameNumber}차전 잔여 경기 진행 · ${game.teamRuns}-${game.opponentRuns} ${if (game.won) "승" else "패"}"
            } else {
                "가을 직접 등판 뒤 잔여 경기 진행 · ${game.teamRuns}-${game.opponentRuns} ${if (game.won) "승" else "패"}"
            }
            automaticSummaries = listOf(directSummary) + simulated.summaries
            automaticGames = simulated.count
        } else {
            nextPostseason = ProPostseasonRules.resolving(current, won)
        }
        val nextRound = nextPostseason.currentRound
        val continues = nextPostseason.result == ProPostseasonResult.IN_PROGRESS && nextRound != null
        val nextTrigger = nextRound?.let { ProPostseasonRules.trigger(it) }
        val rival = nextTrigger?.let {
            ProCatalog.rivalFor(state.team.id, state.season, state.week, it, nextPostseason.series?.opponentTeamId)
        }
        val sound = session.actualDamage <= session.expectedDamage + 150 || session.recommendationAccepted * 2 >= session.pitches
        val sequenceReward = session.sequenceMasteryCount.coerceIn(0, 3)
        val unresolved = state.decisionHistory.indices.filter {
            state.decisionHistory[it].season == state.season && state.decisionHistory[it].followUpResolvedWeek == null
        }
        val followUpReward = unresolved.size * if (sound) 2 else -1
        val trust = clamp(
            state.managerTrust + session.strikeouts * 2 - session.walks * 2 - session.runsAllowed * 3 +
                (if (sound) 2 else 0) + sequenceReward + followUpReward,
            0, 100,
        )
        val history = state.decisionHistory.toMutableList()
        unresolved.forEach { index -> history[index] = history[index].copy(followUpResolvedWeek = state.week) }
        val trustDelta = trust - state.managerTrust
        val headline = when (nextPostseason.result) {
            ProPostseasonResult.CHAMPION -> "플레이오프 우승. 올해의 마지막 공이 남았습니다."
            ProPostseasonResult.RUNNER_UP -> "결승에서 멈췄습니다. 가을은 여기까지입니다."
            ProPostseasonResult.ELIMINATED -> ProPostseasonRules.eliminationNews(nextPostseason.currentRound)
            ProPostseasonResult.IN_PROGRESS -> {
                val series = nextPostseason.series
                if (usesSeriesRules && series != null) {
                    val roundTitle = when (nextPostseason.currentRound) {
                        ProAutumnRound.WILD_CARD -> "와일드카드"
                        ProAutumnRound.SEMIFINAL -> "준플레이오프"
                        ProAutumnRound.PLAYOFF -> "플레이오프"
                        ProAutumnRound.FINAL -> "우승 결정전"
                        null -> "가을 시리즈"
                    }
                    "$roundTitle ${series.nextGameNumber}차전이 남았습니다. 시리즈 ${series.playerWins}-${series.opponentWins}."
                } else if (nextTrigger == ProSeasonTrigger.AUTUMN_WILD_CARD) {
                    "와일드카드 2차전이 남았습니다."
                } else if (won) {
                    "다음 라운드가 열립니다."
                } else {
                    "가을이 이어집니다."
                }
            }
            ProPostseasonResult.DID_NOT_QUALIFY, ProPostseasonResult.UNAVAILABLE -> "가을이 닫혔습니다."
        }
        val trustLine = "가을 승부 · ${session.strikeouts}탈삼진 · ${session.walks}볼넷 · ${session.runsAllowed}실점 · 감독의 믿음 ${if (trustDelta >= 0) "+" else ""}$trustDelta."
        val phase = if (continues) ProCareerPhase.IMPORTANT_GAME else ProCareerPhase.SEASON_REVIEW
        val appearanceLoad = if (usesSeriesRules) max(1, (session.pitches + 14) / 15) else 0
        val postseasonFatigue = clamp(state.fatigue + appearanceLoad - automaticGames * 4, 0, 100)
        rng.next()
        val next = state.copy(
            revision = state.revision + 1UL,
            phase = phase,
            managerTrust = trust,
            catcherTrust = clamp(state.catcherTrust + (if (sound) 2 else -1) + sequenceReward, 0, 100),
            fatigue = postseasonFatigue,
            news = (listOf(headline) + automaticSummaries + listOf(trustLine) + state.news).take(30),
            seasonTrigger = if (continues) nextTrigger else null,
            currentRival = if (continues) rival else null,
            decisionHistory = history,
            postseason = nextPostseason,
            activePitch = null,
            lastPresentation = null, lastBattedBall = null, lastFielding = null,
            commitment = "",
        )
        return result(
            next,
            rng.next().toString(),
            listOf("pro_autumn_game_resolved") +
                (if (automaticGames > 0) listOf("pro_autumn_team_game_simulated") else emptyList()) +
                listOf(if (continues) "pro_autumn_advanced" else "pro_autumn_finished"),
        )
    }

    public fun choosePostseasonAvailability(
        state: ProState,
        seedText: String,
        choice: ProPostseasonAvailabilityChoice,
    ): ProResult {
        validate(state, ProCareerPhase.IMPORTANT_GAME)
        val postseason = state.postseason
        require(usesFinalSeriesRules(state) && postseason != null && postseason.currentRound != null && postseason.result == ProPostseasonResult.IN_PROGRESS) {
            "pro.postseason_availability_not_pending"
        }
        require(ProPostseasonRules.requiresAvailabilityDecision(postseason, state.role)) { "pro.postseason_availability_not_pending" }
        val rng = SplitMix64(seed(seedText).value)
        return when (choice) {
            ProPostseasonAvailabilityChoice.PITCH_AGAIN -> {
                val selected = ProPostseasonRules.choosingAvailability(postseason, ProPostseasonAvailabilityChoice.PITCH_AGAIN)
                val pitches = postseason.series?.lastAppearancePitches ?: 0
                val penalty = ProPostseasonRules.consecutiveAppearanceFatiguePenalty(state.role, pitches)
                result(
                    state.copy(
                        revision = state.revision + 1UL,
                        fatigue = clamp(state.fatigue + penalty, 0, 100),
                        news = (listOf("연투를 택했습니다. 다음 경기에도 마운드에 오릅니다.") + state.news).take(30),
                        postseason = selected,
                        commitment = "",
                    ),
                    rng.next().toString(),
                    listOf("pro_autumn_availability_pitch_again"),
                )
            }
            ProPostseasonAvailabilityChoice.REST_FOR_DECIDER -> {
                val simulated = simulatePostseasonTeamGames(
                    postseason, state, state.role,
                    ProPostseasonRules.teamStrengthEdgePermille(state),
                    forceCurrentGame = true,
                    rng,
                )
                val continues = simulated.state.result == ProPostseasonResult.IN_PROGRESS
                val trigger = if (continues) simulated.state.currentRound?.let { ProPostseasonRules.trigger(it) } else null
                val rival = if (continues && trigger != null) {
                    ProCatalog.rivalFor(state.team.id, state.season, state.week, trigger, simulated.state.series?.opponentTeamId)
                } else null
                val headline = when (simulated.state.result) {
                    ProPostseasonResult.CHAMPION -> "플레이오프 우승. 올해의 마지막 공이 남았습니다."
                    ProPostseasonResult.RUNNER_UP -> "결승에서 멈췄습니다. 가을은 여기까지입니다."
                    ProPostseasonResult.IN_PROGRESS -> {
                        val series = simulated.state.series
                        val roundTitle = when (simulated.state.currentRound) {
                            ProAutumnRound.WILD_CARD -> "와일드카드"
                            ProAutumnRound.SEMIFINAL -> "준플레이오프"
                            ProAutumnRound.PLAYOFF -> "플레이오프"
                            ProAutumnRound.FINAL -> "우승 결정전"
                            null -> "가을 시리즈"
                        }
                        "한 경기를 쉬었습니다. $roundTitle ${series?.nextGameNumber ?: 1}차전을 준비합니다."
                    }
                    else -> "가을이 닫혔습니다."
                }
                result(
                    state.copy(
                        revision = state.revision + 1UL,
                        phase = if (continues) ProCareerPhase.IMPORTANT_GAME else ProCareerPhase.SEASON_REVIEW,
                        fatigue = clamp(state.fatigue - 12, 0, 100),
                        news = (listOf(headline) + simulated.summaries + state.news).take(30),
                        seasonTrigger = trigger,
                        currentRival = rival,
                        postseason = simulated.state,
                        commitment = "",
                    ),
                    rng.next().toString(),
                    listOf("pro_autumn_availability_rest") +
                        (if (simulated.count > 0) listOf("pro_autumn_team_game_simulated") else emptyList()) +
                        listOf(if (continues) "pro_autumn_advanced" else "pro_autumn_finished"),
                )
            }
        }
    }

    private data class PostseasonGameScore(val teamRuns: Int, val opponentRuns: Int, val won: Boolean)
    private data class PostseasonSimulation(val state: ProPostseasonState, val summaries: List<String>, val count: Int)

    private fun simulatePostseasonTeamGames(
        initial: ProPostseasonState,
        careerState: ProState,
        role: ProRole,
        strengthEdgePermille: Int,
        forceCurrentGame: Boolean,
        rng: SplitMix64,
    ): PostseasonSimulation {
        var state = initial
        val summaries = mutableListOf<String>()
        var force = forceCurrentGame
        while (state.result == ProPostseasonResult.IN_PROGRESS && (force || !ProPostseasonRules.shouldDirectlyPlayNextGame(state, role))) {
            force = false
            var teamRuns = ProLeagueBaseline.teamRuns(rng)
            var opponentRuns = ProLeagueBaseline.teamRuns(rng)
            val liveStrengthEdge = ProPostseasonRules.teamStrengthEdgePermille(careerState, state.series?.opponentTeamId)
            val applied = applyPostseasonStrength(
                if (state.series?.opponentTeamId == null) strengthEdgePermille else liveStrengthEdge,
                teamRuns,
                opponentRuns,
                rng,
            )
            teamRuns = applied.first
            opponentRuns = applied.second
            if (teamRuns == opponentRuns) {
                if (rng.nextInt(2) == 0) teamRuns += 1 else opponentRuns += 1
            }
            val won = teamRuns > opponentRuns
            val gameNumber = state.series?.nextGameNumber ?: 1
            state = ProPostseasonRules.resolvingSeriesGame(state, won, directlyPlayed = false, teamRuns = teamRuns, opponentRuns = opponentRuns)
            if (state.result == ProPostseasonResult.IN_PROGRESS) {
                state = ProPostseasonRules.preparingSeries(state, careerState)
            }
            summaries += "우승 결정전 ${gameNumber}차전 자동 진행 · $teamRuns-$opponentRuns ${if (won) "승" else "패"}"
        }
        return PostseasonSimulation(state, summaries, summaries.size)
    }

    private fun resolvePostseasonGame(
        state: ProState,
        session: ProPitchSession,
        strengthEdgePermille: Int,
        rng: SplitMix64,
    ): PostseasonGameScore {
        val inning = min(9, max(1, session.context.inning))
        val entryOuts = min(2, max(0, session.context.outs))
        val directOuts = min(27, max(0, session.outs))
        val differential = session.context.scoreDifferential
        var opponentAtEntry = ProLeagueBaseline.teamRuns(rng) * max(0, inning - 1) / 9
        var teamAtEntry = opponentAtEntry + differential
        if (teamAtEntry < 0) {
            opponentAtEntry += -teamAtEntry
            teamAtEntry = 0
        }
        var teamRuns = max(0, teamAtEntry)
        var opponentRuns = max(0, opponentAtEntry) + session.runsAllowed
        val opponentOutsRemaining = max(0, (10 - inning) * 3 - entryOuts - directOuts)
        if (opponentOutsRemaining > 0) {
            opponentRuns += ProLeagueBaseline.restOfTeamRuns(opponentOutsRemaining, rng)
        }
        val teamOutsRemaining = max(0, (10 - inning) * 3)
        val gameAlreadyEnded = inning == 9 && opponentOutsRemaining == 0 && teamRuns > opponentRuns
        if (teamOutsRemaining > 0 && !gameAlreadyEnded) {
            teamRuns += ProLeagueBaseline.restOfTeamRuns(teamOutsRemaining, rng)
        }
        val applied = applyPostseasonStrength(strengthEdgePermille, teamRuns, opponentRuns, rng)
        teamRuns = applied.first
        opponentRuns = applied.second
        repeat(3) {
            if (teamRuns == opponentRuns) {
                teamRuns += ProLeagueBaseline.restOfTeamRuns(3, rng)
                opponentRuns += ProLeagueBaseline.restOfTeamRuns(3, rng)
            }
        }
        if (teamRuns == opponentRuns) {
            if (rng.nextInt(2) == 0) teamRuns += 1 else opponentRuns += 1
        }
        return PostseasonGameScore(teamRuns, opponentRuns, teamRuns > opponentRuns)
    }

    private fun applyPostseasonStrength(
        edgePermille: Int,
        teamRuns: Int,
        opponentRuns: Int,
        rng: SplitMix64,
    ): Pair<Int, Int> {
        val edge = min(180, max(-180, edgePermille))
        if (edge == 0) return teamRuns to opponentRuns
        val roll = rng.nextInt(1_000)
        return when {
            edge > 0 && roll < edge -> (teamRuns + 1) to opponentRuns
            edge < 0 && roll < -edge -> teamRuns to (opponentRuns + 1)
            else -> teamRuns to opponentRuns
        }
    }

    public fun reviewSeason(state: ProState, seedText: String): ProResult {
        validate(state, ProCareerPhase.SEASON_REVIEW)
        val seed = seed(seedText)
        val stats = state.currentStats.archivingPostseason(state.postseason?.gameHistory)
        var awards = state.awards
        val honorVersion = state.journeyState?.rulesVersion ?: if (usesLiveOutingRules(state)) 2 else 1
        ProCareerRecognitionRules.awardContentIDs(stats, honorVersion).forEach { contentId ->
            awards = awards.addUnique(ProCareerRecognitionRules.awardLabel(contentId, state.season))
        }
        val milestones = state.milestones.addUnique("${state.season}시즌 완주")
        val ledger = ProSeasonLedger(
            season = state.season,
            teamId = state.team.id,
            record = stats,
            standings = state.standings,
            leaderboards = state.leaderboards,
            awards = awards.drop(state.awards.size),
            milestones = listOf("${state.season}시즌 완주"),
            decisionCount = state.decisionHistory.count { it.season == state.season },
        )
        val offerNational = state.season < ProCatalog.MAXIMUM_CAREER_SEASONS && shouldOfferNationalTeam(state)
        val journey = state.journeyState
        val openSettlement = journey != null
        val yearsBefore = max(1, state.contract?.yearsRemaining ?: 1)
        val yearsAfter = max(0, yearsBefore - 1)
        val serviceAfter = state.serviceYears + if (state.level == ProLevel.MAJOR) 1 else 0
        val nextRoute = when {
            state.season >= ProCatalog.MAXIMUM_CAREER_SEASONS -> ProSettlementNextRoute.FORCED_RETIREMENT
            yearsAfter > 0 -> ProSettlementNextRoute.UNDER_CONTRACT
            serviceAfter >= 6 -> ProSettlementNextRoute.FREE_AGENCY_ELIGIBLE
            else -> ProSettlementNextRoute.RENEWAL_MARKET
        }
        val goalBefore = journey?.activeGoal?.let { ProCurrentMarketRules.goalProgress(state.copy(currentStats = ProSeasonStats(state.season, state.team.id)), it) }
        val goalAfter = journey?.activeGoal?.let { ProCurrentMarketRules.goalProgress(state.copy(careerStats = state.careerStats + stats, serviceYears = serviceAfter, awards = awards), it) }
        val goalCompleted = goalBefore?.completed == false && goalAfter?.completed == true
        val fanReasons = (if (openSettlement) ProJourneyKernel.settlementFanReasons(state.copy(awards = awards)) else emptyList()) + if (goalCompleted) listOf(ProFanReason("fan-reason:${state.careerId}:${state.season}:career_ambition_completed:pro.fan.career-ambition-completed:0", ProFanReasonKind.CAREER_AMBITION_COMPLETED, "pro.fan.career-ambition-completed", 10)) else emptyList()
        val fanDelta = fanReasons.sumOf { it.delta }
        val contractMet = ProJourneyKernel.contractExpectationMet(state)
        val merchandise = ProJourneyKernel.merchandiseIncome(journey?.reputation?.fanSupport ?: 0)
        val newAwards = awards.size - state.awards.size
        val hallOfFameDelta = newAwards * 4 + if (stats.strikeouts >= 150) 2 else 0
        val nextJourney = if (journey != null) {
            ProJourneyKernel.settle(
                state = journey,
                careerId = state.careerId,
                season = state.season,
                teamId = state.team.id,
                salary = max(1L, (state.contract?.annualSalary ?: 0).toLong()),
                merchandise = merchandise,
                fanDelta = fanDelta,
                legacyDelta = 1 + newAwards,
                hallOfFameDelta = hallOfFameDelta,
                yearsBefore = yearsBefore,
                yearsAfter = yearsAfter,
                nextRoute = nextRoute,
                fanReasons = fanReasons,
            ).let { settled ->
                val expectation = ProJourneyKernel.contractExpectation(state)
                val history = journey.contractHistory.map { record ->
                    if (record.teamId != state.team.id || record.endedSeason != null) record else record.copy(
                        coveredSeasons = (record.coveredSeasons + state.season).distinct().sorted(),
                        fulfilledExpectationSeasons = if (contractMet == true) (record.fulfilledExpectationSeasons + state.season).distinct().sorted() else record.fulfilledExpectationSeasons,
                        endedSeason = state.season.takeIf { yearsAfter == 0 }, endReason = ProContractEndReason.EXPIRED.takeIf { yearsAfter == 0 })
                }
                val newRecognitions = (ProCareerRecognitionRules.awardContentIDs(state.currentStats, journey.rulesVersion) + listOfNotNull("pro.autumn.champion".takeIf { state.postseason?.result == ProPostseasonResult.CHAMPION })).map { content ->
                    ProCareerRecognition("recognition:${state.careerId}:${state.season}:award:$content", ProCareerRecognitionKind.AWARD, content, state.season, state.team.id, null)
                }
                val recognitions = (journey.recognitions + newRecognitions).distinctBy { it.id }
                val records = ProCurrentMarketRules.records(state.copy(journeyState = journey.copy(recognitions = recognitions)), state.careerStats + stats)
                val awarded = if (goalCompleted) ProJourneyKernel.completeActiveGoal(settled, state.careerId, state.season) else settled
                awarded.copy(contractHistory = history, teamRecords = records, recognitions = (recognitions + awarded.recognitions).distinctBy { it.id },
                    lastSettlement = settled.lastSettlement?.copy(goalProgressBefore = goalBefore, goalProgressAfter = goalAfter, goalCompleted = goalCompleted,
                        hallOfFameBefore = hallOfFameScore(state), hallOfFameAfter = hallOfFameScore(state.copy(careerStats = state.careerStats + stats, serviceYears = serviceAfter, awards = awards)), contractExpectation = expectation,
                        contractExpectationActual = ProJourneyKernel.contractExpectationActual(state), contractExpectationMet = contractMet,
                        teamLegacyAfter = records.firstOrNull { it.teamId == state.team.id }?.let { ProTeamLegacyRules.score(it, journey.rulesVersion) } ?: 0))
            }
        } else {
            journey
        }
        val phase = when {
            openSettlement -> ProCareerPhase.SEASON_SETTLEMENT
            state.season >= ProCatalog.MAXIMUM_CAREER_SEASONS -> ProCareerPhase.RETIREMENT_DECISION
            offerNational -> ProCareerPhase.NATIONAL_TEAM_CALL
            else -> ProCareerPhase.OFFSEASON_DECISION
        }
        val next = state.copy(
            revision = state.revision + 1UL,
            phase = phase,
            managerTrust = if (contractMet == true) (state.managerTrust + 3).coerceAtMost(100) else state.managerTrust,
            serviceYears = if (openSettlement) serviceAfter else state.serviceYears,
            awards = awards,
            milestones = milestones,
            careerStats = state.careerStats + stats,
            seasonLedgers = state.seasonLedgers + ledger,
            pendingDecision = null,
            news = (listOf("시즌 ${state.season} 종료 · ${stats.games}경기 · ${stats.strikeouts}K · 9이닝당 실점 ${"%.2f".format(java.util.Locale.ROOT, stats.runPerNinePermille / 1_000.0)}") + state.news).take(30),
            journeyState = nextJourney,
            contract = state.contract?.copy(yearsRemaining = yearsAfter),
            commitment = "",
        )
        return result(next, if (openSettlement) seedText else seed.nextSeed(), listOf("pro_season_reviewed"))
    }

    public fun acknowledgeSeasonSettlement(state: ProState, seedText: String, settlementId: String): ProResult {
        validate(state, ProCareerPhase.SEASON_SETTLEMENT)
        seed(seedText)
        val journey = state.journeyState ?: throw ProKernelException("pro.settlement_missing")
        val settlement = journey.lastSettlement ?: throw ProKernelException("pro.settlement_missing")
        require(settlement.id == settlementId) { "pro.settlement_stale" }
        if (journey.settlementAcknowledged) {
            return result(state, seedText, listOf("pro_settlement_acknowledged_idempotent"))
        }
        val acknowledged = ProJourneyKernel.acknowledgeSettlement(journey, settlementId)
        val offerNational = state.season < ProCatalog.MAXIMUM_CAREER_SEASONS && shouldOfferNationalTeam(state.copy(journeyState = acknowledged))
        val phase = when {
            state.season >= ProCatalog.MAXIMUM_CAREER_SEASONS || settlement.nextRoute == ProSettlementNextRoute.FORCED_RETIREMENT ->
                ProCareerPhase.RETIREMENT_DECISION
            offerNational -> ProCareerPhase.NATIONAL_TEAM_CALL
            else -> ProCareerPhase.OFFSEASON_DECISION
        }
        return result(
            state.copy(
                revision = state.revision + 1UL,
                phase = phase,
                journeyState = acknowledged,
                commitment = "",
            ),
            seedText,
            listOf("pro_settlement_acknowledged"),
        )
    }

    public fun respondToNationalTeamCall(state: ProState, seedText: String, accepted: Boolean): ProResult {
        validate(state, ProCareerPhase.NATIONAL_TEAM_CALL)
        require(recordedNationalCallValid(state)) { "국가대표 소집 대상이 아닙니다." }
        val seed = seed(seedText)
        if (!accepted) {
            val journey = state.journeyState
            val fan = (journey?.reputation?.fanSupport ?: 0) + ProNationalTeamRules.DECLINE_FAN_DELTA
            val nextJourney = journey?.copy(reputation = journey.reputation.copy(fanSupport = clamp(fan, 0, 100)))
            return result(
                state.copy(
                    revision = state.revision + 1UL,
                    phase = ProCareerPhase.OFFSEASON_DECISION,
                    journeyState = nextJourney,
                    news = (listOf("국가대표 소집을 정중히 거절했습니다.") + state.news).take(30),
                    commitment = "",
                ),
                seedText,
                listOf("pro_national_team_called"),
            )
        }
        val tournament = simulateNationalGroupStage(state, seedText)
        val next = state.copy(
            revision = state.revision + 1UL,
            phase = ProCareerPhase.NATIONAL_TOURNAMENT,
            nationalTournament = tournament,
            pendingDecision = null,
            commitment = "",
        )
        return if (tournament.result != null) {
            finishNationalTournament(next, seedText, listOf("pro_national_team_called"))
        } else {
            result(next, seedText, listOf("pro_national_team_called"))
        }
    }

    public fun startNationalFinal(state: ProState, seedText: String): ProResult {
        validate(state, ProCareerPhase.NATIONAL_TOURNAMENT)
        seed(seedText)
        val tournament = state.nationalTournament ?: throw ProKernelException("결승에 오를 수 없습니다.")
        require(tournament.stage == ProNationalTournamentStage.AWAITING_FINAL && tournament.result == null) { "결승에 오를 수 없습니다." }
        return result(
            state.copy(
                revision = state.revision + 1UL,
                phase = ProCareerPhase.IMPORTANT_GAME,
                seasonTrigger = ProSeasonTrigger.NATIONAL_FINAL,
                commitment = "",
            ),
            seedText,
            listOf("pro_national_final_ready"),
        )
    }

    public fun resolveNationalFinalAutomatically(state: ProState, seedText: String): ProResult {
        validate(state, ProCareerPhase.NATIONAL_TOURNAMENT)
        val tournament = state.nationalTournament ?: throw ProKernelException("결승에 오를 수 없습니다.")
        require(tournament.stage == ProNationalTournamentStage.AWAITING_FINAL && tournament.result == null) { "결승에 오를 수 없습니다." }
        var rng = SplitMix64(ProNationalTeamRules.derivedFinalSeed(tournament.resumeSeed))
        val opponent = ProNationalTeamRules.opponent(tournament.finalOpponentId) ?: ProNationalTeamRules.finalOpponent()
        val line = simulateNationalGameLine(state, opponent, 4, false, rng)
        val resolved = tournament.copy(
            stage = ProNationalTournamentStage.RESULT,
            finalLine = line,
            result = if (line.won) ProNationalTournamentResult.GOLD else ProNationalTournamentResult.SILVER,
            fatigueCarry = ProNationalTeamRules.fatigueCarry(line.playerPitches),
        )
        val next = state.copy(
            revision = state.revision + 1UL,
            phase = ProCareerPhase.NATIONAL_TOURNAMENT,
            seasonTrigger = null,
            nationalTournament = resolved,
            commitment = "",
        )
        return finishNationalTournament(next, seedText, listOf("pro_national_final_simulated"))
    }

    public fun acknowledgeNationalTeamResult(state: ProState, seedText: String): ProResult {
        validate(state, ProCareerPhase.NATIONAL_TOURNAMENT)
        val tournament = state.nationalTournament ?: throw ProKernelException("대회 결과가 없습니다.")
        require(tournament.result != null) { "대회 결과가 없습니다." }
        return result(
            state.copy(
                revision = state.revision + 1UL,
                phase = ProCareerPhase.OFFSEASON_DECISION,
                seasonTrigger = null,
                nationalTournament = null,
                commitment = "",
            ),
            tournament.resumeSeed,
            listOf("pro_national_team_result_acknowledged"),
        )
    }

    private fun simulateNationalGameLine(
        state: ProState,
        opponent: ProNationalOpponent,
        gameNumber: Int,
        directlyPlayed: Boolean,
        rng: SplitMix64,
    ): ProNationalTournamentGameLine {
        val outing = automaticOuting.simulate(
            pitcher = PitchLearningRules.playable(state.pitcher, state.pitchLearningProject),
            startingFatigue = state.fatigue,
            outsTarget = ProNationalTeamRules.GROUP_OUTS_TARGET,
            pitchCap = ProNationalTeamRules.GROUP_PITCH_CAP,
            baseSeed = rng.next(),
            batterOffset = opponent.batterOffset,
            callPolicy = AutoCallPolicy.PERFECT,
            diverseScouting = false,
        )
        val support = ProLeagueBaseline.teamRuns(rng)
        val opponentRuns = outing.runsAllowed + ProLeagueBaseline.restOfTeamRuns(max(0, 27 - outing.outs), rng)
        var teamRuns = support
        if (teamRuns == opponentRuns) teamRuns += 1
        return ProNationalTournamentGameLine(
            opponentId = opponent.id,
            gameNumber = gameNumber,
            teamRuns = teamRuns,
            opponentRuns = opponentRuns,
            directlyPlayed = directlyPlayed,
            playerPitches = outing.pitches,
            playerOuts = outing.outs,
            playerRunsAllowed = outing.runsAllowed,
            playerStrikeouts = outing.strikeouts,
            playerWalks = outing.walks,
            playerHits = outing.hits,
        )
    }

    private fun simulateNationalGroupStage(state: ProState, resumeSeed: String): ProNationalTournamentState {
        val rng = SplitMix64(ProNationalTeamRules.derivedSeed(resumeSeed))
        val groupOpponents = ProNationalTeamRules.groupOpponents()
        val games = groupOpponents.mapIndexed { index, opponent ->
            simulateNationalGameLine(state, opponent, index + 1, false, rng)
        }
        val injuryChance = max(0, injuryPressure(state.fatigue, state.pitcher.stamina, state.pitcher.effectiveMastery.stamina, usesChallengeRules(state)) - 72)
        val injuryWeeks = if (rng.nextInt(100) < injuryChance) {
            ProNationalTeamRules.INJURY_RECOVERY_MIN + rng.nextInt(ProNationalTeamRules.INJURY_RECOVERY_SPAN)
        } else 0
        val qualified = games.count { it.won } >= ProNationalTeamRules.WINS_TO_FINAL
        val finalOpponent = ProNationalTeamRules.finalOpponent()
        if (qualified) {
            return ProNationalTournamentState(
                seed = ProNationalTeamRules.derivedSeed(resumeSeed),
                resumeSeed = resumeSeed,
                startingFatigue = state.fatigue,
                groupGames = games,
                stage = ProNationalTournamentStage.AWAITING_FINAL,
                finalOpponentId = finalOpponent.id,
                fatigueCarry = ProNationalTeamRules.FATIGUE_CARRY,
                injuryWeeks = injuryWeeks,
            )
        }
        val bronzeOpponent = groupOpponents.lastOrNull() ?: finalOpponent
        val bronze = simulateNationalGameLine(state, bronzeOpponent, 4, false, rng)
        return ProNationalTournamentState(
            seed = ProNationalTeamRules.derivedSeed(resumeSeed),
            resumeSeed = resumeSeed,
            startingFatigue = state.fatigue,
            groupGames = games,
            stage = ProNationalTournamentStage.RESULT,
            finalOpponentId = finalOpponent.id,
            finalLine = bronze,
            result = if (bronze.won) ProNationalTournamentResult.BRONZE else ProNationalTournamentResult.GROUP_EXIT,
            fatigueCarry = ProNationalTeamRules.FATIGUE_CARRY,
            injuryWeeks = injuryWeeks,
        )
    }

    private fun resolveNationalFinalFromSession(state: ProState, session: ProPitchSession): ProResult {
        val tournament = state.nationalTournament ?: throw ProKernelException("결승 상태가 아닙니다.")
        require(tournament.stage == ProNationalTournamentStage.AWAITING_FINAL) { "결승 상태가 아닙니다." }
        var teamRuns = session.context.scoreDifferential + 3
        val opponentRuns = session.runsAllowed
        if (teamRuns == opponentRuns) teamRuns += 1
        if (teamRuns < 0) teamRuns = opponentRuns + 1
        val line = ProNationalTournamentGameLine(
            opponentId = tournament.finalOpponentId,
            gameNumber = 4,
            teamRuns = teamRuns,
            opponentRuns = opponentRuns,
            directlyPlayed = true,
            playerPitches = session.pitches,
            playerOuts = session.outs,
            playerRunsAllowed = session.runsAllowed,
            playerStrikeouts = session.strikeouts,
            playerWalks = session.walks,
            playerHits = session.hits,
        )
        val resolved = tournament.copy(
            stage = ProNationalTournamentStage.RESULT,
            finalLine = line,
            result = if (line.won) ProNationalTournamentResult.GOLD else ProNationalTournamentResult.SILVER,
            fatigueCarry = ProNationalTeamRules.fatigueCarry(session.pitches),
        )
        val next = state.copy(
            revision = state.revision + 1UL,
            phase = ProCareerPhase.NATIONAL_TOURNAMENT,
            seasonTrigger = null,
            activePitch = null,
            lastPresentation = null, lastBattedBall = null, lastFielding = null,
            nationalTournament = resolved,
            commitment = "",
        )
        return finishNationalTournament(next, state.seed, listOf("pro_important_game_resolved"))
    }

    private fun finishNationalTournament(state: ProState, seedText: String, events: List<String>): ProResult {
        val tournament = state.nationalTournament
        val outcome = tournament?.result
        if (tournament == null || outcome == null) return result(state, seedText, events)
        val journey = state.journeyState
        val alreadyCompleted = state.militaryCompleted
        val exempted = outcome == ProNationalTournamentResult.GOLD && !alreadyCompleted
        val fanDelta = ProNationalTeamRules.fanDelta(outcome, alreadyCompleted)
        val fan = clamp((journey?.reputation?.fanSupport ?: 0) + fanDelta, 0, 100)
        var recognitions = journey?.recognitions.orEmpty()
        var milestones = state.milestones
        val news = state.news.toMutableList()
        news.add(0, ProNationalTeamRules.news(outcome))
        if (outcome == ProNationalTournamentResult.GOLD) {
            recognitions = recognitions + ProCareerRecognition(
                "${state.careerId}:pro.award.national-gold:${state.season}",
                ProCareerRecognitionKind.AWARD,
                "pro.award.national-gold",
                state.season,
                null,
                null,
            ) + ProCareerRecognition(
                "${state.careerId}:pro.milestone.national.gold:${state.season}",
                ProCareerRecognitionKind.MILESTONE,
                "pro.milestone.national.gold",
                state.season,
                null,
                null,
            )
            milestones = milestones.addUnique("대표팀 금메달")
            news.add(0, "해외 스카우트 문의가 들어왔습니다.")
        } else if (outcome == ProNationalTournamentResult.SILVER) {
            recognitions = recognitions + ProCareerRecognition(
                "${state.careerId}:pro.award.national-silver:${state.season}",
                ProCareerRecognitionKind.AWARD,
                "pro.award.national-silver",
                state.season,
                null,
                null,
            )
            news.add(0, "해외 스카우트 문의가 들어왔습니다.")
        }
        val overseas = if (outcome == ProNationalTournamentResult.GOLD || outcome == ProNationalTournamentResult.SILVER) {
            true
        } else {
            journey?.reputation?.overseasInterest
        }
        val nextJourney = journey?.copy(
            recognitions = recognitions.distinctBy { it.id },
            reputation = journey.reputation.copy(fanSupport = fan, overseasInterest = overseas),
        )
        val history = state.nationalTeamHistory + ProNationalTeamRecord(
            season = state.season,
            result = outcome,
            directGameLine = tournament.finalLine?.takeIf { it.directlyPlayed },
        )
        val recorded = tournament.copy(fanDelta = fanDelta, exempted = exempted)
        val next = state.copy(
            militaryCompleted = if (exempted) true else state.militaryCompleted,
            milestones = milestones,
            news = news.take(30),
            journeyState = nextJourney,
            nationalTournament = recorded,
            nationalTeamHistory = history,
            nationalTeamCarry = ProNationalTeamCarryState(state.season, tournament.fatigueCarry, tournament.injuryWeeks),
            commitment = "",
        )
        return result(next, seedText, events + "pro_national_team_result")
    }

    public fun chooseOffseason(state: ProState, seedText: String, decision: OffseasonDecision): ProResult {
        require(state.phase == ProCareerPhase.OFFSEASON_DECISION || state.phase == ProCareerPhase.RETIREMENT_DECISION) { "pro.offseason_phase" }
        validateSavedState(state)
        val seed = seed(seedText)
        if (decision == OffseasonDecision.RETIRE || state.phase == ProCareerPhase.RETIREMENT_DECISION) {
            val score = hallOfFameScore(state)
            val candidates = if (state.startMode == ProStartMode.LINKED) legacyCandidates(state) else emptyList()
            val phase = if (candidates.isEmpty()) ProCareerPhase.COMPLETED else ProCareerPhase.LEGACY_SELECTION
            val next = state.copy(
                revision = state.revision + 1UL,
                phase = phase,
                legacyCandidates = candidates,
                contract = if (state.journeyState != null) null else state.contract,
                journeyState = state.journeyState?.let { journey ->
                    val active = journey.activeGoal
                    val goals = if (active == null || journey.goalHistory.any { it.id == active.id }) journey.goalHistory else journey.goalHistory +
                        ProCareerGoalRecord(active.id, active.ambition, active.selectedSeason, active.anchorTeamId, active.completedSeason, state.season,
                            if (active.completedSeason != null) ProCareerGoalOutcome.COMPLETED else ProCareerGoalOutcome.RETIRED_INCOMPLETE)
                    val closed = journey.copy(activeGoal = null, goalHistory = goals, pendingContractMarket = null, offseasonTransition = null,
                        contractHistory = journey.contractHistory.map { if (it.endReason == null) it.copy(endedSeason = state.season, endReason = ProContractEndReason.RETIRED) else it },
                        lastSettlement = journey.lastSettlement?.copy(hallOfFameAfter = score))
                    closed.copy(retirementHonors = ProJourneyKernel.retirementPreview(closed, state.team.id).honors +
                        listOfNotNull(state.nationalTeamHistory.count { it.result == ProNationalTournamentResult.GOLD }.takeIf { it > 0 }?.let { ProRetirementHonor("honor:${state.careerId}:national_gold:none", ProRetirementHonorKind.NATIONAL_GOLD, null, null, it.toLong()) }))
                },
                hallOfFameScore = score,
                milestones = state.milestones.addUnique("은퇴 · 통산 ${state.careerStats.size}시즌"),
                news = (retirementNews(state, score) + state.news).take(30),
                commitment = "",
            )
            return result(next, if (state.journeyState != null) seedText else seed.nextSeed(), listOf(if (candidates.isEmpty()) "pro_career_retired" else "pro_legacy_candidates_frozen"))
        }
        val remainingYears = state.contract?.yearsRemaining ?: 0
        if (decision == OffseasonDecision.FREE_AGENCY && remainingYears > 0) {
            throw ProKernelException("pro.free_agency_ineligible")
        }
        if (
            state.journeyState != null &&
            decision in setOf(OffseasonDecision.CONTINUE, OffseasonDecision.MILITARY_SERVICE) &&
            remainingYears >= 1
        ) {
            if (decision == OffseasonDecision.MILITARY_SERVICE) {
                require(!state.militaryCompleted) { "pro.military_already_completed" }
            }
            val military = decision == OffseasonDecision.MILITARY_SERVICE
            val transition = ProOffseasonTransition(
                afterSeason = state.season,
                nextSeason = state.season + 1,
                ageAdvanceYears = if (military) 2 else 1,
                includesMilitaryService = military,
                route = ProOffseasonTransitionRoute.UNDER_CONTRACT,
            )
            val journey = state.journeyState.copy(offseasonTransition = transition)
            return result(
                state.copy(
                    revision = state.revision + 1UL,
                    phase = ProCareerPhase.OFFSEASON_INVESTMENT,
                    journeyState = journey,
                    commitment = "",
                ),
                seedText,
                listOf("pro_offseason_transition_saved"),
            )
        }
        if (state.journeyState != null && remainingYears == 0) {
            if (decision == OffseasonDecision.MILITARY_SERVICE) {
                require(!state.militaryCompleted) { "pro.military_already_completed" }
            }
            val service = state.serviceYears + if (state.journeyState == null && state.level == ProLevel.MAJOR) 1 else 0
            val freeAgency = decision == OffseasonDecision.FREE_AGENCY || (decision == OffseasonDecision.MILITARY_SERVICE && service >= 6)
            if (decision == OffseasonDecision.FREE_AGENCY) {
                require(service >= 6) { "pro.free_agency_service" }
            }
            val military = decision == OffseasonDecision.MILITARY_SERVICE
            val route = if (freeAgency) ProOffseasonTransitionRoute.FREE_AGENCY_MARKET else ProOffseasonTransitionRoute.RENEWAL_MARKET
            val transition = ProOffseasonTransition(
                afterSeason = state.season,
                nextSeason = state.season + 1,
                ageAdvanceYears = if (military) 2 else 1,
                includesMilitaryService = military,
                route = route,
            )
            val marketState = state.copy(journeyState = state.journeyState.copy(offseasonTransition = transition))
            val market = if (!freeAgency) ProCurrentMarketRules.renewal(marketState) else ProCurrentMarketRules.freeAgency(marketState)
            val journey = state.journeyState.copy(
                pendingContractMarket = market,
                offseasonTransition = transition,
            )
            return result(
                state.copy(
                    revision = state.revision + 1UL,
                    phase = ProCareerPhase.CONTRACT_OFFER,
                    contract = state.contract,
                    standings = emptyList(),
                    leaderboards = emptyList(),
                    journeyState = journey,
                    commitment = "",
                ),
                seedText,
                listOf("pro_contract_market_opened"),
            )
        }
        return chooseOffseasonAdvance(state, seedText, decision)
    }

    public fun chooseInvestment(
        state: ProState,
        seedText: String,
        investment: ProOffseasonInvestment,
        focus: ProDevelopmentFocus?,
    ): ProResult {
        validate(state, ProCareerPhase.OFFSEASON_INVESTMENT)
        val journey = state.journeyState ?: throw ProKernelException("pro.investment_missing_journey")
        val transition = journey.offseasonTransition ?: throw ProKernelException("pro.investment_missing_transition")
        require(transition.route == ProOffseasonTransitionRoute.UNDER_CONTRACT) { "pro.investment_route" }
        if (investment == ProOffseasonInvestment.PITCH_LAB) {
            require(focus != null) { "pro.investment_focus" }
        }
        val invested = ProJourneyKernel.applyInvestment(
            journey,
            state.careerId,
            transition.nextSeason,
            investment,
            focus,
        )
        val waiting = state.copy(
            journeyState = invested.copy(offseasonTransition = journey.offseasonTransition),
            commitment = "",
        )
        val decision = if (transition.includesMilitaryService) OffseasonDecision.MILITARY_SERVICE else OffseasonDecision.CONTINUE
        return chooseOffseasonAdvance(waiting, seedText, decision)
    }

    private fun chooseOffseasonAdvance(state: ProState, seedText: String, decision: OffseasonDecision): ProResult {
        val seed = seed(seedText)
        var age = state.age + 1
        var military = state.militaryCompleted
        val service = state.serviceYears + if (state.journeyState == null && state.level == ProLevel.MAJOR) 1 else 0
        var team = state.team
        val news = state.news.toMutableList()
        when (decision) {
            OffseasonDecision.MILITARY_SERVICE -> {
                require(!military) { "pro.military_already_completed" }
                age += 1
                military = true
                news.add(0, "두 시즌의 군 복무를 마치고 복귀했습니다.")
            }
            OffseasonDecision.FREE_AGENCY -> {
                require(service >= 6) { "pro.free_agency_service" }
                news.add(0, "FA 시장이 열렸습니다.")
            }
            OffseasonDecision.CONTINUE -> Unit
            OffseasonDecision.RETIRE -> error("unreachable")
        }
        val season = state.season + 1
        val pitcher = projectedPitcher(state.pitcher, age, CURRENT_RULES_VERSION, recoveryYear = state.journeyState?.recoveryYearPending == true)
        val contract = if (state.journeyState != null && state.contract != null) state.contract else state.contract?.copy(
            annualSalary = max(state.contract.annualSalary, 40_000_000 + service * 50_000_000),
            rolePromise = state.role,
        ) ?: ProContract(
            yearsRemaining = 1,
            annualSalary = 40_000_000 + service * 50_000_000,
            rolePromise = state.role,
        )
        val opening = nextSeasonOpeningLoad(state)
        val clearedJourney = state.journeyState?.copy(offseasonTransition = null, recoveryYearPending = null)
        val base = state.copy(
            revision = state.revision + 1UL,
            phase = ProCareerPhase.WEEKLY_PLAN,
            pitcher = pitcher,
            team = team,
            age = age,
            season = season,
            week = 0,
            role = if (state.journeyState != null) contract.rolePromise else state.role,
            rolePreference = if (state.journeyState != null) contract.rolePromise else state.role,
            fatigue = opening.fatigue,
            injuryWeeks = opening.injuryWeeks,
            serviceYears = service,
            militaryCompleted = military,
            contract = contract,
            currentStats = ProSeasonStats(season, team.id),
            currentGameLines = emptyList(),
            seasonSegment = ProSeasonSegment.SPRING_CAMP,
            seasonTrigger = null,
            currentRival = null,
            seasonTensions = emptyList(),
            importantGames = 0,
            pendingDecision = null,
            activePitch = null,
            lastPresentation = null, lastBattedBall = null, lastFielding = null,
            news = news.take(30),
            commitment = "",
            proRulesVersion = max(state.proRulesVersion, CURRENT_RULES_VERSION),
            postseason = null,
            activeDecisionModifiers = null,
            resolvedFollowUps = null,
            roleRequest = null,
            nationalTeamCarry = null,
            journeyState = clearedJourney,
        )
        val declineNews = if (age >= 31) listOf("${age}세 · 전성기가 기울며 구위가 한 단계 떨어졌습니다.") else emptyList()
        val next = base.copy(
            seasonTensions = seasonTensions(base),
            news = (declineNews + listOf(tensionHeadline(seasonTensions(base))) + base.news).take(30),
            standings = deriveStandings(base),
            leaderboards = deriveLeaderboards(base),
            commitment = "",
        )
        return result(next, if (state.journeyState != null) seedText else seed.nextSeed(), listOf("pro_offseason_resolved"))
    }

    public fun selectLegacy(state: ProState, legacyId: String): ProResult {
        validate(state, ProCareerPhase.LEGACY_SELECTION)
        require(state.legacyCandidates.map { it.id }.contains(legacyId)) { "pro.legacy_unknown" }
        val candidate = state.legacyCandidates.first { it.id == legacyId }
        val settlement = if (state.startMode == ProStartMode.LINKED) {
            ProHighSchoolArchiveSettlement(
                highSchoolCareerId = state.sourceHighSchoolCareerId ?: error("pro.linked.source_missing"),
                proCareerId = state.careerId,
                selectedLegacyId = legacyId,
                playerName = state.identityName,
                teamId = state.team.id,
                careerSeasons = state.careerStats.size,
                careerGames = state.careerGames(),
                careerStrikeouts = state.careerStrikeouts(),
                archiveReceipt = StableHash.fnv1a64("pro-archive|${state.careerId}|$legacyId"),
            )
        } else null
        val next = state.copy(
            revision = state.revision + 1UL,
            phase = ProCareerPhase.COMPLETED,
            selectedLegacyId = candidate.id,
            highSchoolArchiveSettlement = settlement,
            news = (listOf("${candidate.title}을 이번 삶의 유산으로 남겼습니다.") + state.news).take(30),
            commitment = "",
        )
        return result(next, state.seed, listOf("pro_legacy_selected", if (settlement != null) "linked_hs_archive_settlement" else "direct_pro_no_archive"))
    }

    /** Applies the linked settlement to the already-completed HS shadow state only. */
    public fun settleLinkedHighSchoolArchive(
        state: ProState,
        highSchool: HighSchoolPhase4State,
    ): HighSchoolPhase4State {
        require(state.startMode == ProStartMode.LINKED && state.phase == ProCareerPhase.COMPLETED) { "pro.linked_settlement_phase" }
        val settlement = state.highSchoolArchiveSettlement ?: throw ProKernelException("pro.linked_settlement_missing")
        require(highSchool.run.careerId == settlement.highSchoolCareerId) { "pro.linked_settlement_career_mismatch" }
        if (highSchool.archive.any { it.careerId == highSchool.run.careerId }) return highSchool
        var current = highSchool
        val highSchoolKernel = HighSchoolPhase4Kernel()
        if (current.run.phase == com.solkim.baseball.core.highschool.HighSchoolPhase.COMPLETED && current.selectedSignatureLegacyId != settlement.selectedLegacyId) {
            current = highSchoolKernel.prepareLegacy(current).state.copy(selectedSignatureLegacyId = null).let {
                highSchoolKernel.commitShadowState(it)
            }
        }
        if (settlement.selectedLegacyId !in current.run.legacyOptions) {
            current = current.copy(
                run = HighSchoolKernel().resignShadowState(
                    current.run.copy(legacyOptions = (current.run.legacyOptions + settlement.selectedLegacyId).distinct()),
                ),
            )
        }
        if (current.selectedSignatureLegacyId == null) {
            require(settlement.selectedLegacyId in current.run.legacyOptions) { "pro.linked_settlement_legacy_mismatch" }
            current = highSchoolKernel.selectLegacy(current, settlement.selectedLegacyId).state
        }
        return highSchoolKernel.finalizeArchive(current).state
    }

    public fun validateSavedState(state: ProState) {
        require(state.careerId.isNotBlank()) { "pro.career_id" }
        require(state.identityName.isNotBlank() && state.identityName.length <= 12) { "pro.player_name" }
        require(state.seed.matches(Regex("[0-9]+"))) { "pro.seed" }
        seed(state.seed)
        require(state.revision < ULong.MAX_VALUE) { "pro.revision" }
        require(state.age in 1..100 && state.season in 1..ProCatalog.MAXIMUM_CAREER_SEASONS && state.week in 0..ProCatalog.WEEKS_PER_SEASON) { "pro.time" }
        require(state.seasonSegment == ProCatalog.segment(state.week)) { "pro.segment_mismatch" }
        require(state.importantGames in 0..3) { "pro.important_games" }
        if (state.startMode == ProStartMode.LINKED) {
            require(!state.sourceHighSchoolCareerId.isNullOrBlank()) { "pro.linked.source_missing" }
        }
        if (state.startMode == ProStartMode.DIRECT) {
            require(state.highSchoolLegacyContext == null) { "pro.direct_hs_context" }
            require(state.highSchoolArchiveSettlement == null) { "pro.direct_fake_archive" }
            require(state.legacyCandidates.isEmpty() && state.selectedLegacyId == null) { "pro.direct_fake_legacy" }
        }
        state.highSchoolLegacyContext?.let {
            require(it.managerTrust in 0..100 && it.catcherTrust in 0..100 && it.rivalTrust in 0..100) { "pro.hs_context_trust" }
        }
        require(state.managerTrust in 0..100 && state.catcherTrust in 0..100 && state.fatigue in 0..100 && state.injuryWeeks >= 0) { "pro.bounded" }
        val previousTeamStats = state.phase == ProCareerPhase.OFFSEASON_INVESTMENT && state.careerStats.lastOrNull()?.let {
            it.season == state.season && it.teamId == state.currentStats.teamId && it.games == state.currentStats.games && it.inningsOuts == state.currentStats.inningsOuts
        } == true
        requireStatsShape(state.currentStats, state.season, if (previousTeamStats) state.currentStats.teamId else state.team.id, "pro.stats")
        require(state.currentStats.games == state.currentGameLines.size) { "pro.ledger_games" }
        require(state.currentGameLines.all {
            it.season == state.season && it.week in 1..ProCatalog.WEEKS_PER_SEASON &&
                it.outs >= 0 && it.strikeouts >= 0 && it.walks >= 0 && it.runsAllowed >= 0 &&
                it.pitches >= 0 && it.teamRuns >= 0 && it.opponentRuns >= 0 && it.hits >= 0 && it.homeRuns >= 0
        }) { "pro.game_lines" }
        require(state.currentStats.games == state.currentGameLines.count { it.season == state.season }) { "pro.ledger_lines" }
        requireCurrentStatsMatchLines(state.currentStats, state.currentGameLines)
        state.careerStats.forEach { requireStatsShape(it, it.season, it.teamId, "pro.career_stats") }
        require(state.careerStats.zipWithNext().all { (a, b) -> a.season < b.season }) { "pro.career_order" }
        require(state.seasonLedgers.map { it.season }.distinct().size == state.seasonLedgers.size) { "pro.ledger_unique" }
        require(state.seasonLedgers.all { it.season <= state.season }) { "pro.ledger_phase" }
        require(state.careerStats.size == state.seasonLedgers.size) { "pro.ledger_count" }
        state.seasonLedgers.forEachIndexed { index, ledger ->
            require(index < state.careerStats.size && ledger.record == state.careerStats[index]) { "pro.ledger_record" }
            require(ledger.season == ledger.record.season && ledger.teamId == ledger.record.teamId) { "pro.ledger_identity" }
            require(ledger.decisionCount in 0..ProCatalog.maximumDecisions(state.proRulesVersion)) { "pro.ledger_decisions" }
            require(ledger.milestones.isNotEmpty()) { "pro.ledger_milestones" }
            requireStandingSnapshot(ledger.standings, "pro.ledger_standings")
            requireLeaderboardSnapshot(ledger.leaderboards, "pro.ledger_leaderboards")
        }
        require((state.phase == ProCareerPhase.SEASON_DECISION) == (state.pendingDecision != null)) { "pro.decision_phase" }
        if (state.phase == ProCareerPhase.NATIONAL_TEAM_CALL && state.journeyState != null) {
            require(recordedNationalCallValid(state)) { "pro.national_team_call" }
        }
        if (state.phase == ProCareerPhase.SEASON_SETTLEMENT && state.journeyState != null) {
            val settlement = state.journeyState.lastSettlement
            require(settlement != null && !state.journeyState.settlementAcknowledged) { "pro.settlement_phase" }
            require(settlement.season == state.season && settlement.teamId == state.team.id) { "pro.settlement_identity" }
        }
        if (state.phase == ProCareerPhase.OFFSEASON_INVESTMENT && state.journeyState != null) {
            require(state.journeyState.offseasonTransition != null) { "pro.investment_phase" }
        }
        val tournamentExpected = state.phase == ProCareerPhase.NATIONAL_TOURNAMENT ||
            (state.phase == ProCareerPhase.IMPORTANT_GAME && state.seasonTrigger == ProSeasonTrigger.NATIONAL_FINAL)
        require((state.nationalTournament != null) == tournamentExpected) { "pro.national_tournament_phase" }
        state.pendingDecision?.let { validateDecision(it, state.season, state.week) }
        require(state.decisionHistory.map { it.decisionId }.distinct().size == state.decisionHistory.size) { "pro.decision_unique" }
        require(state.decisionHistory.all {
            it.season in 1..state.season && it.choiceId.isNotBlank() &&
                (it.week in ProCatalog.COMPATIBLE_DECISION_WEEKS ||
                    (it.type == ProSeasonDecisionType.NATIONAL_TEAM && it.week == ProCatalog.WEEKS_PER_SEASON))
        }) { "pro.decision_record" }
        require(state.decisionHistory.groupingBy { it.season }.eachCount().values.all { it <= ProCatalog.maximumDecisions(state.proRulesVersion) }) { "pro.decision_limit" }
        require(state.commandReceipts.map { it.commandId }.distinct().size == state.commandReceipts.size) { "pro.command_receipts_unique" }
        require(state.commandReceipts.zipWithNext().all { (a, b) -> a.revision < b.revision }) { "pro.command_receipts_order" }
        require(state.commandReceipts.all { it.commandId.isNotBlank() && it.sessionId.isNotBlank() && it.revision <= state.revision }) { "pro.command_receipt_shape" }
        if (state.phase != ProCareerPhase.CONTRACT_OFFER) {
            require(state.contract != null || state.phase in setOf(ProCareerPhase.LEGACY_SELECTION, ProCareerPhase.COMPLETED)) { "pro.contract_missing" }
            requireStandingSnapshot(state.standings, "pro.standings")
            requireLeaderboardSnapshot(state.leaderboards, "pro.leaderboards")
        } else {
            require(state.contract == null || state.contract.yearsRemaining == 0 && (state.journeyState == null || state.journeyState.pendingContractMarket?.kind in setOf(ProContractMarketKind.RENEWAL, ProContractMarketKind.FREE_AGENCY))) { "pro.contract_unexpected" }
            require(state.standings.isEmpty() && state.leaderboards.isEmpty()) { "pro.contract_projection" }
        }
        require(state.activePitch == null || state.phase == ProCareerPhase.IMPORTANT_GAME) { "pro.pitch_phase" }
        state.activePitch?.let {
            require(it.week == state.week) { "pro.pitch_week" }
            validatePitch(it)
        }
        require(state.legacyCandidates.map { it.id }.distinct().size == state.legacyCandidates.size) { "pro.legacy_unique" }
        require(state.selectedLegacyId == null || state.phase == ProCareerPhase.COMPLETED) { "pro.legacy_phase" }
        require(state.selectedLegacyId == null || state.legacyCandidates.any { it.id == state.selectedLegacyId }) { "pro.legacy_selected" }
        if (state.phase == ProCareerPhase.LEGACY_SELECTION) {
            require(state.startMode == ProStartMode.LINKED && state.legacyCandidates.size == 3) { "pro.legacy_candidates" }
        }
        state.highSchoolArchiveSettlement?.let {
            require(state.startMode == ProStartMode.LINKED && state.phase == ProCareerPhase.COMPLETED) { "pro.linked_settlement_phase" }
            require(it.highSchoolCareerId == state.sourceHighSchoolCareerId && it.proCareerId == state.careerId) { "pro.linked_settlement_identity" }
            require(it.selectedLegacyId == state.selectedLegacyId && it.selectedLegacyId in state.legacyCandidates.map { candidate -> candidate.id }) { "pro.linked_settlement_legacy" }
            require(it.careerSeasons == state.careerStats.size && it.careerGames == state.careerGames() && it.careerStrikeouts == state.careerStrikeouts()) { "pro.linked_settlement_stats" }
        }
        require(state.commitment == commitment(state)) { "pro.commitment_mismatch" }
    }

    private fun requireStatsShape(value: ProSeasonStats, season: Int, teamId: String, code: String) {
        require(value.season == season && value.teamId == teamId) { "${code}_identity" }
        require(value.games >= 0 && value.starts in 0..value.games && value.inningsOuts >= 0 && value.strikeouts >= 0 && value.walks >= 0 && value.runsAllowed >= 0 && value.hits >= 0 && value.homeRuns >= 0 && value.pitches >= 0 && value.wins >= 0 && value.losses >= 0 && value.saves >= 0) { "${code}_values" }
        require(value.wins + value.losses <= value.games) { "${code}_decisions" }
    }

    private fun requireCurrentStatsMatchLines(stats: ProSeasonStats, lines: List<ProGameLine>) {
        require(stats.starts == lines.count { it.started }) { "pro.stats_starts" }
        require(stats.inningsOuts == lines.sumOf { it.outs }) { "pro.stats_outs" }
        require(stats.strikeouts == lines.sumOf { it.strikeouts }) { "pro.stats_strikeouts" }
        require(stats.walks == lines.sumOf { it.walks }) { "pro.stats_walks" }
        require(stats.runsAllowed == lines.sumOf { it.runsAllowed }) { "pro.stats_runs" }
        require(stats.hits == lines.sumOf { it.hits }) { "pro.stats_hits" }
        require(stats.homeRuns == lines.sumOf { it.homeRuns }) { "pro.stats_homers" }
        require(stats.pitches == lines.sumOf { it.pitches }) { "pro.stats_pitches" }
        require(stats.wins == lines.count { it.decision == ProPitchingDecision.WIN }) { "pro.stats_wins" }
        require(stats.losses == lines.count { it.decision == ProPitchingDecision.LOSS }) { "pro.stats_losses" }
        require(stats.saves == lines.count { it.decision == ProPitchingDecision.SAVE }) { "pro.stats_saves" }
    }

    private fun requireStandingSnapshot(values: List<ProStanding>, code: String) {
        require(values.size == ProCatalog.teams.size) { "${code}_count" }
        require(values.map { it.rank } == (1..values.size).toList()) { "${code}_rank" }
        require(values.map { it.teamId }.toSet() == ProCatalog.teams.map { it.id }.toSet()) { "${code}_teams" }
        val games = values.firstOrNull()?.let { it.wins + it.losses + it.draws } ?: 0
        require(values.all {
            it.teamName == ProCatalog.team(it.teamId).name && it.wins >= 0 && it.losses >= 0 && it.draws >= 0 &&
                it.wins + it.losses + it.draws == games && it.gamesBehindPermille >= 0
        }) { "${code}_values" }
        require(values.count { it.isPlayerTeam } == 1) { "${code}_player" }
    }

    private fun requireLeaderboardSnapshot(values: List<ProLeaderboardRow>, code: String) {
        require(values.isNotEmpty()) { "${code}_empty" }
        require(values.map { it.rank } == (1..values.size).toList()) { "${code}_rank" }
        require(values.map { it.playerId }.distinct().size == values.size) { "${code}_players" }
        require(values.all { it.category.isNotBlank() && it.playerName.isNotBlank() && it.teamId in ProCatalog.teams.map { team -> team.id } && it.value >= 0 }) { "${code}_values" }
        require(values.count { it.isCurrentPlayer } == 1) { "${code}_player" }
    }

    public fun commitment(state: ProState): String {
        val values = buildList {
            add(state.careerId); add(state.revision.toString()); add(state.startMode.wire)
            add(state.sourceHighSchoolCareerId ?: "-"); add(state.highSchoolLegacyContext?.let(::legacyContextCommitment) ?: "-"); add(state.activeHighSchoolPreserved.toString()); add(state.seed)
            add(state.identityName); add(pitcherCommitment(state.pitcher)); add(state.team.toString()); add(state.entitlement.toString())
            addAll(listOf(state.pitcher.stuff, state.pitcher.command, state.pitcher.movement, state.pitcher.stamina).map(Int::toString))
            add(state.team.id); add(state.age.toString()); add(state.season.toString()); add(state.week.toString()); add(state.phase.wire)
            add(state.level.wire); add(state.role.wire); add(state.rolePreference?.wire ?: "-")
            addAll(listOf(state.managerTrust, state.catcherTrust, state.fatigue, state.injuryWeeks, state.serviceYears).map(Int::toString))
            add(state.militaryCompleted.toString()); add(state.contract?.toString() ?: "-"); add(state.currentStats.toString())
            add(state.currentGameLines.joinToString(";") { it.toString() }); add(state.careerStats.joinToString(";") { it.toString() })
            add(state.seasonLedgers.joinToString(";") { it.toString() }); add(state.awards.joinToString(",")); add(state.milestones.joinToString(","))
            add(state.decisionHistory.joinToString(";") { it.toString() }); add(state.pendingDecision?.toString() ?: "-")
            add(state.developmentProgress.toString()); add(state.seasonSegment.wire); add(state.seasonTrigger?.wire ?: "-")
            add(state.currentRival?.toString() ?: "-"); add(state.seasonTensions.joinToString(";") { it.toString() }); add(state.importantGames.toString())
            add(state.standings.joinToString(";") { it.toString() }); add(state.leaderboards.joinToString(";") { it.toString() }); add(state.lastPresentation?.toString() ?: "-"); add(state.lastSegmentProgress?.toString() ?: "-")
            add(state.legacyCandidates.joinToString(";") { it.toString() }); add(state.selectedLegacyId ?: "-")
            add(state.highSchoolArchiveSettlement?.toString() ?: "-"); add(state.activePitch?.toString() ?: "-")
            add(state.hallOfFameScore?.toString() ?: "-"); add(state.news.joinToString("\u001f"))
            add(state.commandReceipts.joinToString(";") { it.toString() })
            add("proRules:${state.proRulesVersion}")
            state.journeyState?.let { add("journey:v1:${ProJourneyStateCodec.canonicalToken(it)}") }
            state.postseason?.let { postseason ->
                add("postseason:${postseason.seed}:${postseason.currentRound?.wire ?: "none"}:${postseason.result.wire}:${postseason.gamesPlayed}")
                postseason.series?.let { series ->
                    add(
                        "postseason_series:${series.round?.wire ?: "none"}:${series.opponentTeamId ?: "none"}:${series.playerWinsRequired ?: "none"}:${series.opponentWinsRequired ?: "none"}:${series.playerWins}:${series.opponentWins}:${series.nextGameNumber}:${series.totalDirectAppearances}:${series.lastAppearancePitches ?: "none"}:${series.lastAppearanceGameNumber ?: "none"}:${series.availabilityDecision?.wire ?: "none"}",
                    )
                }
            }
            state.activeDecisionModifiers?.takeIf { it.isNotEmpty() }?.let { add("decision_modifiers:${it.size}") }
            state.resolvedFollowUps?.takeIf { it.isNotEmpty() }?.let { add("resolved_followups:${it.size}") }
            state.roleRequest?.let { add("role_request:${it.season}:${it.reviewWeek}:${it.requested.wire}:${it.outcome.wire}") }
            state.nationalTournament?.let { add("national_tournament:$it") }
            if (state.nationalTeamHistory.isNotEmpty()) {
                add("national_history:${state.nationalTeamHistory.joinToString(";") { it.toString() }}")
            }
            state.nationalTeamCarry?.let { add("national_carry:$it") }
            state.pitchLearningProject?.let { add("learning:${it.token()}") }
        }
        return StableHash.fnv1a64(values.joinToString("|"))
    }

    /** Keep the hash of pre-mastery saves stable while committing new mastery-bearing pitchers. */
    private fun pitcherCommitment(value: PitcherSnapshot): String = value.mastery?.let { value.toString() }
        ?: "PitcherSnapshot(id=${value.id}, name=${value.name}, stuff=${value.stuff}, command=${value.command}, movement=${value.movement}, stamina=${value.stamina}, pitchProfiles=${value.pitchProfiles}, throwingHand=${value.throwingHand})"

    private fun legacyContextCommitment(value: ProHighSchoolLegacyContext): String =
        "ProHighSchoolLegacyContext(startingPitcher=${pitcherCommitment(value.startingPitcher)}, highSchoolPitcher=${pitcherCommitment(value.highSchoolPitcher)}, performance=${value.performance}, selectedAwakenings=${value.selectedAwakenings}, managerTrust=${value.managerTrust}, catcherTrust=${value.catcherTrust}, rivalTrust=${value.rivalTrust})"

    private fun initialState(
        seedText: String,
        mode: ProStartMode,
        sourceHighSchoolCareerId: String?,
        highSchoolLegacyContext: ProHighSchoolLegacyContext?,
        activeHighSchoolPreserved: Boolean,
        identityName: String,
        pitcher: PitcherSnapshot,
        team: ProTeam,
        entitlement: ProEntitlement,
        draftEvaluation: Int,
    ): ProState {
        val careerId = "pro-${StableHash.fnv1a64("$seedText|${pitcher.id}|${team.id}")}"
        val state = ProState(
            careerId = careerId,
            revision = 0UL,
            startMode = mode,
            sourceHighSchoolCareerId = sourceHighSchoolCareerId,
            highSchoolLegacyContext = highSchoolLegacyContext,
            activeHighSchoolPreserved = activeHighSchoolPreserved,
            seed = seedText,
            identityName = identityName,
            pitcher = pitcher,
            team = team,
            entitlement = entitlement,
            age = 19,
            season = 1,
            week = 0,
            phase = ProCareerPhase.CONTRACT_OFFER,
            level = ProLevel.MINOR,
            role = ProRole.STARTER,
            rolePreference = null,
            managerTrust = 42,
            catcherTrust = 45,
            fatigue = 0,
            injuryWeeks = 0,
            serviceYears = 0,
            militaryCompleted = false,
            contract = null,
            currentStats = ProSeasonStats(1, team.id),
            currentGameLines = emptyList(),
            careerStats = emptyList(),
            seasonLedgers = emptyList(),
            awards = emptyList(),
            milestones = listOf("프로 지명", if (mode == ProStartMode.DIRECT) "직접 프로 시작" else "고교 연계 지명"),
            decisionHistory = emptyList(),
            pendingDecision = null,
            developmentProgress = ProDevelopmentProgress(),
            seasonSegment = ProSeasonSegment.SPRING_CAMP,
            seasonTrigger = null,
            currentRival = null,
            seasonTensions = emptyList(),
            importantGames = 0,
            standings = emptyList(),
            leaderboards = emptyList(),
            legacyCandidates = emptyList(),
            selectedLegacyId = null,
            highSchoolArchiveSettlement = null,
            activePitch = null,
            lastPresentation = null, lastBattedBall = null, lastFielding = null,
            lastSegmentProgress = null,
            hallOfFameScore = null,
            news = listOf("신인 계약 제안 · ${team.name} · $identityName${if (draftEvaluation > 0) " · 평가 $draftEvaluation" else ""}"),
            proRulesVersion = CURRENT_RULES_VERSION,
            journeyState = ProCareerJourneyState(
                rulesVersion = ProJourneyKernel.CURRENT_JOURNEY_RULES_VERSION,
                reputation = ProReputationState(fanSupport = initialJourneyFanSupport(draftEvaluation)),
                migration = ProJourneyMigration(ProJourneyMigrationSource.NEW_CAREER, 1, 1, 0, false),
            ),
        )
        return signed(state)
    }

    private fun signContractInternal(state: ProState): ProState {
        val tensions = seasonTensions(state)
        val years = 3
        val salary = max(30_000_000, state.pitcher.stuff * 1_000_000)
        val contract = ProContract(years, salary, ProRole.STARTER)
        return signed(state.copy(
            revision = state.revision + 1UL,
            phase = ProCareerPhase.WEEKLY_PLAN,
            contract = contract,
            milestones = state.milestones.addUnique("신인 계약"),
            news = (listOf(
                if (usesContractDepthRules(state)) {
                    "신인 계약에 서명했습니다. ${years}년 · 연봉 ${salary}원 · 보직 선발."
                } else {
                    "신인 계약에 서명했습니다. 2군 선발 경쟁이 시작됩니다."
                },
                tensionHeadline(tensions),
            ) + state.news).take(30),
            seasonTensions = tensions,
            standings = deriveStandings(state),
            leaderboards = deriveLeaderboards(state),
            commitment = "",
        ))
    }

    private data class SeedValue(val value: ULong) {
        fun nextValue(): ULong = SplitMix64(value).next()
        fun nextSeed(): String = nextValue().toString()
        fun nextSeed(next: ULong): String = next.toString()
    }

    private fun seed(value: String): SeedValue {
        require(value.matches(Regex("[0-9]+"))) { "pro.seed_invalid" }
        return SeedValue(value.toULongOrNull() ?: throw ProKernelException("pro.seed_overflow"))
    }

    private fun result(
        state: ProState,
        nextSeed: String,
        events: List<String>,
        preparation: PitchPreparation? = null,
        presentation: com.solkim.baseball.core.pitch.TrajectoryPresentationSnapshot? = null,
        injuryEvent: ProInjuryEventSnapshot? = null,
    ): ProResult {
        val project = state.pitchLearningProject
        val normalized = if (project != null && state.activePitch == null) state.copy(pitcher = state.pitcher.copy(pitchProfiles = PitchLearningRules.advance(state.pitcher.pitchProfiles.orEmpty(), project, project))) else state
        return ProResult(signed(normalized), nextSeed, events, preparation, presentation, injuryEvent = injuryEvent)
    }

    private fun validate(state: ProState, phase: ProCareerPhase) {
        require(state.phase == phase) { "pro.expected_phase:${phase.wire}:${state.phase.wire}" }
        validateSavedState(state)
    }

    private fun signed(state: ProState): ProState = state.copy(commitment = commitment(state.copy(commitment = "")))

    private fun seasonDecision(
        state: ProState,
        week: Int,
        climate: ProSeasonClimate? = null,
        trust: Int? = null,
    ): ProSeasonDecision {
        val weeks = ProCatalog.decisionWeeks(state.proRulesVersion)
        val slot = weeks.indexOf(week)
        require(slot >= 0) { "pro.decision_week" }
        val reviewDue = ProRoleRequestRules.pendingReview(state, week)
        val used = state.decisionHistory.filter { it.season == state.season }.map { it.type }.toSet()
        if (!reviewDue && usesCareerArcRules(state)) {
            val history = state.decisionHistory
            val hadFormCrisis = history.any { it.season == state.season && it.type == ProSeasonDecisionType.FORM_CRISIS }
            if (!hadFormCrisis && climate == ProSeasonClimate.SLUMP && (trust ?: state.managerTrust) < 55) {
                return makeArcDecision(ProSeasonDecisionType.FORM_CRISIS, state, week)
            }
            val hadAging = history.any { it.season == state.season && it.type == ProSeasonDecisionType.AGING_CROSSROADS }
            if (!hadAging && week == weeks.last() && state.age >= 32) {
                return makeArcDecision(ProSeasonDecisionType.AGING_CROSSROADS, state, week)
            }
        }
        if (!reviewDue && usesWeeklyDecisionRules(state) && week == ProCatalog.mediaOpportunityWeek(state.careerId, state.season, state.proRulesVersion) && ProSeasonDecisionType.MEDIA_OPPORTUNITY !in used &&
            state.journeyState != null && (state.journeyState.reputation.fanSupport >= 35)
        ) {
            return mediaDecision(state, week)
        }
        val types = listOf(
            ProSeasonDecisionType.EXTRA_BULLPEN,
            ProSeasonDecisionType.CATCHER_GAME_PLAN,
            ProSeasonDecisionType.ROLE_MEETING,
            ProSeasonDecisionType.RECORD_CHASE,
            ProSeasonDecisionType.RIVAL_ANALYSIS,
            ProSeasonDecisionType.SEASON_FINALE,
        )
        val eligible = if (usesWeeklyDecisionRules(state)) ProWeeklyDecisionRules.candidates(state, week, trust ?: state.managerTrust) else types
        val pool = eligible.ifEmpty { types }
        val salt = if (usesWeeklyDecisionRules(state)) "weekly-decisions" else "season-decisions"
        val type = if (ProRoleRequestRules.pendingReview(state, week)) ProSeasonDecisionType.ROLE_MEETING else
            pool[(proHash("${state.careerId}|season${state.season}|$salt") % pool.size.toULong()).toInt().plus(slot).mod(pool.size)]
        val choices = when (type) {
            ProSeasonDecisionType.ROTATION_PUSH, ProSeasonDecisionType.NEW_PITCH_TRIAL,
            ProSeasonDecisionType.FARM_RESET, ProSeasonDecisionType.VETERAN_MENTOR -> ProWeeklyDecisionRules.choices(type, state)
            ProSeasonDecisionType.EXTRA_BULLPEN -> listOf(
                choice(type, "high_intensity", "강하게 더 던진다", "구위와 변화구를 함께 끌어올립니다.", ProDecisionEffect(stuffDelta = 1, movementDelta = 1, fatigueDelta = 14)),
                choice(type, "shape_work", "변화구만 다듬는다", "부담을 줄이고 변화구 감각에 집중합니다.", ProDecisionEffect(movementDelta = 1, fatigueDelta = 7)),
                choice(type, "rest", "오늘은 멈춘다", "성장 대신 몸을 회복합니다.", ProDecisionEffect(fatigueDelta = -16)),
            )
            ProSeasonDecisionType.CATCHER_GAME_PLAN -> listOf(
                choice(type, "battery_plan", "포수와 함께 짠다", "배터리 호흡과 코스 실행을 우선합니다.", ProDecisionEffect(commandDelta = 1, catcherTrustDelta = 8, fatigueDelta = 4)),
                choice(type, "staff_report", "감독 보고서를 따른다", "벤치가 원하는 경기 운영에 맞춥니다.", ProDecisionEffect(managerTrustDelta = 7, catcherTrustDelta = 1, fatigueDelta = 3)),
                choice(type, "own_sequence", "내 공을 밀어붙인다", "변화구 감각을 얻는 대신 두 사람의 믿음을 겁니다.", ProDecisionEffect(movementDelta = 1, managerTrustDelta = -2, catcherTrustDelta = -3, fatigueDelta = 5)),
            )
            ProSeasonDecisionType.ROLE_MEETING -> listOf(
                choice(type, "challenge_starter", "선발에 도전한다", "긴 이닝 준비와 경쟁 부담을 받아들입니다.", ProDecisionEffect(staminaDelta = 1, managerTrustDelta = -3, fatigueDelta = 10, roleTarget = ProRole.STARTER)),
                choice(type, "focus_relief", "구원에 집중한다", "짧은 등판의 구위와 포수 호흡을 택합니다.", ProDecisionEffect(stuffDelta = 1, catcherTrustDelta = 3, fatigueDelta = 6, roleTarget = ProRole.LONG_RELIEF)),
                choice(type, "close_games", "마무리를 맡는다", "9회의 압박을 받아들이고 한 점 차 승부를 책임집니다.", ProDecisionEffect(commandDelta = 1, managerTrustDelta = -4, catcherTrustDelta = 4, fatigueDelta = 8, roleTarget = ProRole.CLOSER)),
            )
            ProSeasonDecisionType.RECORD_CHASE -> listOf(
                choice(type, "strikeouts", "탈삼진을 노린다", "결정구 두 가지를 강하게 연마합니다.", ProDecisionEffect(stuffDelta = 1, movementDelta = 1, fatigueDelta = 12)),
                choice(type, "run_prevention", "실점 억제를 택한다", "제구와 배터리 운영을 다듬습니다.", ProDecisionEffect(commandDelta = 1, catcherTrustDelta = 4, fatigueDelta = 7)),
                choice(type, "body_management", "몸을 관리한다", "긴 시즌을 버틸 체력과 회복을 택합니다.", ProDecisionEffect(staminaDelta = 1, fatigueDelta = -12)),
            )
            ProSeasonDecisionType.RIVAL_ANALYSIS -> listOf(
                choice(type, "attack_weakness", "약점을 깊게 판다", "포수와 코스를 정교하게 맞춥니다.", ProDecisionEffect(commandDelta = 1, catcherTrustDelta = 5, fatigueDelta = 6)),
                choice(type, "keep_strength", "내 장점을 유지한다", "구위와 변화구 완성도를 높입니다.", ProDecisionEffect(stuffDelta = 1, movementDelta = 1, fatigueDelta = 8)),
                choice(type, "defer", "맞대결까지 보류한다", "추가 훈련 없이 몸을 가볍게 만듭니다.", ProDecisionEffect(fatigueDelta = -8)),
            )
            ProSeasonDecisionType.SEASON_FINALE -> listOf(
                choice(type, "push_race", "순위 경쟁에 건다", "감독의 믿음을 얻는 대신 피로를 감수합니다.", ProDecisionEffect(managerTrustDelta = 8, fatigueDelta = 14)),
                choice(type, "recover_first", "회복을 우선한다", "출전 의지를 의심받더라도 몸을 회복합니다.", ProDecisionEffect(managerTrustDelta = -2, fatigueDelta = -18)),
                choice(type, "support_youth", "젊은 선수를 돕는다", "벤치와 배터리의 신뢰를 함께 쌓습니다.", ProDecisionEffect(managerTrustDelta = 4, catcherTrustDelta = 6, fatigueDelta = 3)),
            )
            ProSeasonDecisionType.FORM_CRISIS, ProSeasonDecisionType.AGING_CROSSROADS ->
                error("arc decisions are built by makeArcDecision")
            ProSeasonDecisionType.MEDIA_OPPORTUNITY -> error("media is built by mediaDecision")
            ProSeasonDecisionType.NATIONAL_TEAM -> error("national team is built by nationalTeamDecision")
        }
        val title = type.title
        return ProSeasonDecision("season-${state.season}-week-$week-${type.wire}", type, state.season, week, title, type.detail, choices)
    }

    private fun mediaDecision(state: ProState, week: Int): ProSeasonDecision {
        val type = ProSeasonDecisionType.MEDIA_OPPORTUNITY
        return ProSeasonDecision(
            "season-${state.season}-week-$week-${type.wire}",
            type,
            state.season,
            week,
            type.title,
            type.detail,
            listOf(
                choice(type, "advertising_shoot", "광고 촬영에 참여한다", "출연료 3천만 원 · 팬 지지 +5 · 피로 +6", ProDecisionEffect(fatigueDelta = 6)),
                choice(type, "fan_together_shoot", "팬과 함께 촬영한다", "출연료 1천만 원 · 팬 지지 +10 · 지역 활동 +2 · 피로 +4", ProDecisionEffect(fatigueDelta = 4)),
                choice(type, "focus_on_season", "시즌에 집중한다", "촬영을 쉬고 피로를 4 줄입니다.", ProDecisionEffect(fatigueDelta = -4)),
            ),
        )
    }

    private fun nationalTeamDecision(state: ProState, week: Int): ProSeasonDecision {
        val type = ProSeasonDecisionType.NATIONAL_TEAM
        return ProSeasonDecision(
            "season-${state.season}-week-$week-${type.wire}",
            type,
            state.season,
            week,
            type.title,
            type.detail,
            listOf(
                choice(type, "accept", "소집을 받는다", "명예를 얻고 피로와 등판 부담을 받아들입니다.", ProDecisionEffect(managerTrustDelta = 6, fatigueDelta = 10)),
                choice(type, "short_stint", "짧은 합류만 한다", "한 경기만 보태고 구단으로 돌아갑니다.", ProDecisionEffect(managerTrustDelta = 3, fatigueDelta = 4)),
                choice(type, "decline", "구단에 남는다", "대표 대신 시즌 막판 로테이션을 지킵니다.", ProDecisionEffect(managerTrustDelta = -2, fatigueDelta = -6)),
            ),
        )
    }

    private data class MediaJourneyEffect(val income: Long, val fanDelta: Int, val communityDelta: Int)

    private fun mediaJourneyEffect(choiceId: String): MediaJourneyEffect? = when (choiceId.substringAfterLast('.')) {
        "advertising_shoot", "appear" -> MediaJourneyEffect(30_000_000L, 5, 0)
        "fan_together_shoot", "short" -> MediaJourneyEffect(10_000_000L, 10, 2)
        "focus_on_season", "decline" -> MediaJourneyEffect(0L, 0, 0)
        else -> null
    }

    private fun choice(type: ProSeasonDecisionType, suffix: String, title: String, detail: String, effect: ProDecisionEffect) =
        ProDecisionChoice("${type.wire}.$suffix", title, detail, effect)

    private fun makeArcDecision(type: ProSeasonDecisionType, state: ProState, week: Int): ProSeasonDecision {
        val (title, detail, choices) = when (type) {
            ProSeasonDecisionType.FORM_CRISIS -> Triple(
                "슬럼프 갈림길",
                "최근 등판이 흔들리고 감독의 믿음도 얇아졌습니다. 남은 주를 어떻게 버티겠습니까.",
                listOf(
                    choice(type, "recover", "회복 주를 택한다", "다음 이틀을 평온하게 만들고 몸을 낮춥니다.", ProDecisionEffect(managerTrustDelta = -2, fatigueDelta = -16)),
                    choice(type, "push_through", "밀어붙인다", "피로를 감수하고 선발 자리를 지킵니다.", ProDecisionEffect(managerTrustDelta = 3, fatigueDelta = 12)),
                    choice(type, "move_bullpen", "구원으로 몸을 낮춘다", "짧은 이닝으로 슬럼프 피해를 줄입니다.", ProDecisionEffect(managerTrustDelta = 1, fatigueDelta = -8, roleTarget = ProRole.LONG_RELIEF)),
                ),
            )
            ProSeasonDecisionType.AGING_CROSSROADS -> Triple(
                "전성기가 기울고 있다",
                "몸이 예전 같지 않습니다. 다음 시즌을 어떤 자세로 맞겠습니까.",
                listOf(
                    choice(type, "keep_starter", "선발을 지킨다", "하락을 감수하고 로테이션에 남습니다.", ProDecisionEffect(staminaDelta = 1, managerTrustDelta = 2, fatigueDelta = 6, roleTarget = ProRole.STARTER)),
                    choice(type, "move_bullpen", "불펜으로 옮긴다", "짧은 승부로 몸을 아끼며 남습니다.", ProDecisionEffect(commandDelta = 1, fatigueDelta = -8, roleTarget = ProRole.LONG_RELIEF)),
                    choice(type, "recovery_year", "회복 연도를 택한다", "성장을 멈추고 하락을 한 단계 줄입니다.", ProDecisionEffect(managerTrustDelta = -2, fatigueDelta = -16)),
                ),
            )
            else -> error("not an arc decision")
        }
        return ProSeasonDecision("season-${state.season}-week-$week-${type.wire}", type, state.season, week, title, detail, choices)
    }

    private val ProSeasonDecisionType.title: String
        get() = when (this) {
            ProSeasonDecisionType.ROTATION_PUSH, ProSeasonDecisionType.NEW_PITCH_TRIAL,
            ProSeasonDecisionType.FARM_RESET, ProSeasonDecisionType.VETERAN_MENTOR -> ProWeeklyDecisionRules.title(this)
            ProSeasonDecisionType.EXTRA_BULLPEN -> "추가 불펜"
            ProSeasonDecisionType.CATCHER_GAME_PLAN -> "포수와 경기 계획"
            ProSeasonDecisionType.ROLE_MEETING -> "역할 면담"
            ProSeasonDecisionType.RECORD_CHASE -> "기록 추격"
            ProSeasonDecisionType.RIVAL_ANALYSIS -> "라이벌 분석"
            ProSeasonDecisionType.SEASON_FINALE -> "시즌 막바지"
            ProSeasonDecisionType.FORM_CRISIS -> "슬럼프 갈림길"
            ProSeasonDecisionType.AGING_CROSSROADS -> "전성기가 기울고 있다"
            ProSeasonDecisionType.MEDIA_OPPORTUNITY -> "미디어 촬영"
            ProSeasonDecisionType.NATIONAL_TEAM -> "대표팀 발탁"
        }

    private val ProSeasonDecisionType.detail: String
        get() = when (this) {
            ProSeasonDecisionType.ROTATION_PUSH, ProSeasonDecisionType.NEW_PITCH_TRIAL,
            ProSeasonDecisionType.FARM_RESET, ProSeasonDecisionType.VETERAN_MENTOR -> ProWeeklyDecisionRules.detail(this)
            ProSeasonDecisionType.EXTRA_BULLPEN -> "정규 훈련이 끝난 뒤 마운드 사용 시간이 남았습니다."
            ProSeasonDecisionType.CATCHER_GAME_PLAN -> "다음 등판의 구종 순서와 승부 방식을 정합니다."
            ProSeasonDecisionType.ROLE_MEETING -> "코칭스태프가 남은 시즌의 등판 역할을 묻습니다."
            ProSeasonDecisionType.RECORD_CHASE -> "개인 기록과 팀에 필요한 투구 사이에서 훈련 방향을 고릅니다."
            ProSeasonDecisionType.RIVAL_ANALYSIS -> "다음 맞대결을 앞두고 분석 시간을 어디에 쓸지 정합니다."
            ProSeasonDecisionType.SEASON_FINALE -> "순위 경쟁과 회복, 동료 지원 사이에서 마지막 힘을 배분합니다."
            ProSeasonDecisionType.FORM_CRISIS -> "최근 등판이 흔들리고 감독의 믿음도 얇아졌습니다. 남은 주를 어떻게 버티겠습니까."
            ProSeasonDecisionType.AGING_CROSSROADS -> "몸이 예전 같지 않습니다. 다음 시즌을 어떤 자세로 맞겠습니까."
            ProSeasonDecisionType.MEDIA_OPPORTUNITY -> "팬과 구단이 함께 찍을 한 컷을 제안합니다. 출연하면 인지도가 오르고 몸을 조금 씁니다."
            ProSeasonDecisionType.NATIONAL_TEAM -> "국가대표 소집이 왔습니다. 출전하면 명예와 부담이 함께 남습니다."
        }

    private fun validateDecision(value: ProSeasonDecision, season: Int, week: Int) {
        require(value.id == "season-$season-week-${value.week}-${value.type.wire}") { "pro.decision_id" }
        require(value.season == season && value.choices.size == (if (value.type.isWeeklyBinary) 2 else 3)) { "pro.decision_shape" }
        require(
            value.week == week ||
                (value.type == ProSeasonDecisionType.NATIONAL_TEAM && value.week == week),
        ) { "pro.decision_week_mismatch" }
        require(value.choices.map { it.id }.distinct().size == value.choices.size) { "pro.decision_choices" }
        require(value.choices.all { it.id.startsWith("${value.type.wire}.") && it.title.isNotBlank() && it.detail.isNotBlank() }) { "pro.decision_copy" }
        require(value.choices.all { effectReasonable(it.effect) }) { "pro.decision_effect" }
    }

    private fun effectReasonable(effect: ProDecisionEffect): Boolean =
        listOf(effect.stuffDelta, effect.commandDelta, effect.movementDelta, effect.staminaDelta).all { it in -4..4 } &&
            listOf(effect.managerTrustDelta, effect.catcherTrustDelta).all { it in -20..20 } && effect.fatigueDelta in -30..30

    private fun importantGameTrigger(state: ProState, nextWeek: Int, level: ProLevel, trust: Int, stats: ProSeasonStats, skill: Int, prior: Int): ProSeasonTrigger? {
        val maximum = if (usesAutumnRules(state)) 2 else 3
        if (prior >= maximum) return null
        val segment = ProCatalog.segment(nextWeek)
        if (state.level == ProLevel.MINOR && level == ProLevel.MAJOR && (segment == ProSeasonSegment.SEASON_FINALE || prior < maximum - 1)) return ProSeasonTrigger.MAJOR_DEBUT
        if (segment == ProSeasonSegment.OPENING && nextWeek == anchorWeek(state, "opening", 2, 4)) return ProSeasonTrigger.OPENING_STATEMENT
        if (segment == ProSeasonSegment.SEASON_FINALE && nextWeek == anchorWeek(state, "finale", 21, 23)) return ProSeasonTrigger.STANDINGS_RACE
        if (prior >= maximum - 1) return null
        if (level == ProLevel.MINOR && skill >= 44 && state.managerTrust < 57 && trust >= 57) return ProSeasonTrigger.CALL_UP_AUDITION
        if (state.pitcher.stuff >= maxOf(state.pitcher.command, state.pitcher.movement, state.pitcher.stamina)) {
            listOf(45, 85, 125).firstOrNull { state.currentStats.strikeouts < it && stats.strikeouts >= it }?.let { return ProSeasonTrigger.RECORD_CHASE }
        } else if (stats.inningsOuts >= 120 && state.currentStats.inningsOuts < 120) return ProSeasonTrigger.RECORD_CHASE
        if (level == ProLevel.MAJOR && listOf(63, 75).firstOrNull { state.managerTrust < it && trust >= it } != null) return ProSeasonTrigger.ROLE_SHOWDOWN
        return null
    }

    private fun anchorWeek(state: ProState, salt: String, lower: Int, upper: Int): Int {
        val value = proHash("${state.careerId}|season${state.season}|$salt")
        return lower + (value % (upper - lower + 1).toULong()).toInt()
    }

    private fun importantHeadline(trigger: ProSeasonTrigger, rival: ProRivalBatter?, level: ProLevel): String {
        val foe = rival?.let { "${it.teamName} ${it.name}" } ?: "상대 팀 중심타자"
        return when (trigger) {
            ProSeasonTrigger.MAJOR_DEBUT -> "처음으로 1군 마운드에 오릅니다. ${foe}와의 승부가 기다립니다."
            ProSeasonTrigger.OPENING_STATEMENT -> "개막 시리즈 선발 맞대결. ${foe} 앞에서 올 시즌 첫인상을 만듭니다."
            ProSeasonTrigger.CALL_UP_AUDITION -> "콜업이 눈앞입니다. ${foe}를 막으면 1군 문이 열립니다."
            ProSeasonTrigger.RECORD_CHASE -> "기록에 다가서는 등판. ${foe}를 상대로 자신의 투구를 증명합니다."
            ProSeasonTrigger.ROLE_SHOWDOWN -> "${foe}와의 승부로 다음 역할이 갈립니다."
            ProSeasonTrigger.STANDINGS_RACE -> "순위가 걸린 한 경기. ${foe}를 넘어야 가을이 보입니다."
            ProSeasonTrigger.AUTUMN_WILD_CARD -> "와일드카드 한 판. ${foe}를 막아야 가을이 이어집니다."
            ProSeasonTrigger.AUTUMN_SEMIFINAL -> "준플레이오프. ${foe}와의 승부가 다음 라운드를 엽니다."
            ProSeasonTrigger.AUTUMN_PLAYOFF -> "플레이오프. ${foe}를 넘어야 우승 결정전이 열립니다."
            ProSeasonTrigger.AUTUMN_FINAL -> "우승 결정전. ${foe} 앞에서 올해의 마지막 공을 던집니다."
            ProSeasonTrigger.NATIONAL_FINAL -> "대표팀 결승. ${foe} 앞에서 이번 대회를 가릅니다."
        }
    }

    private fun nextSeasonOpeningLoad(state: ProState): ProNationalTeamCarryState {
        val carry = state.nationalTeamCarry?.takeIf { it.season == state.season }
        return ProNationalTeamCarryState(
            season = state.season,
            fatigue = clamp(carry?.fatigue ?: 0, 0, 100),
            injuryWeeks = max(0, carry?.injuryWeeks ?: 0),
        )
    }

    private data class DevelopmentResolution(val pitcher: PitcherSnapshot, val progress: ProDevelopmentProgress, val labels: List<String>)

    private fun resolveDevelopment(
        pitcher: PitcherSnapshot,
        progress: ProDevelopmentProgress,
        plan: ProWeekPlan,
        target: PitchKind?,
        paused: Boolean,
        liveTicks: Boolean,
        efficiencyPermille: Int = 1_000,
    ): DevelopmentResolution {
        if (paused || plan == ProWeekPlan.RECOVER || plan == ProWeekPlan.EARN_TRUST) return DevelopmentResolution(pitcher, progress, emptyList())
        var value = pitcher
        var stuff = progress.stuff
        var command = progress.command
        var movement = progress.movement
        var stamina = progress.stamina
        val labels = mutableListOf<String>()
        fun advance(current: Int, setter: (Int) -> Unit, ability: Int, focus: ProGrowthFocus, label: String, pitch: PitchKind? = null) {
            val needed = if (liveTicks) developmentTicksRequired(ability) else 2
            val scaledNeeded = if (efficiencyPermille >= 1_000) max(1, needed * 1_000 / efficiencyPermille) else max(needed, (needed * 1_000 + efficiencyPermille - 1) / efficiencyPermille)
            val nextTick = current + 1
            if (nextTick >= scaledNeeded) {
                setter(0)
                value = grow(value, focus, 1, pitch)
                labels += "$label +1"
            } else {
                setter(nextTick)
            }
        }
        when (plan) {
            ProWeekPlan.DEVELOP_STUFF -> advance(stuff, { stuff = it }, pitcher.stuff, ProGrowthFocus.STUFF, "구위")
            ProWeekPlan.REFINE_COMMAND -> advance(command, { command = it }, pitcher.command, ProGrowthFocus.COMMAND, "제구")
            ProWeekPlan.DEVELOP_MOVEMENT -> advance(movement, { movement = it }, pitcher.movement, ProGrowthFocus.MOVEMENT, "변화구", target)
            ProWeekPlan.BUILD_STAMINA -> advance(stamina, { stamina = it }, pitcher.stamina, ProGrowthFocus.STAMINA, "체력")
            ProWeekPlan.DEVELOP_WEAPON -> {
                advance(stuff, { stuff = it }, pitcher.stuff, ProGrowthFocus.STUFF, "구위")
                advance(movement, { movement = it }, pitcher.movement, ProGrowthFocus.MOVEMENT, "변화구", target)
            }
            else -> Unit
        }
        return DevelopmentResolution(value, ProDevelopmentProgress(stuff, command, movement, stamina), labels)
    }

    private enum class ProGrowthFocus { STUFF, COMMAND, MOVEMENT, STAMINA }

    private fun grow(pitcher: PitcherSnapshot, focus: ProGrowthFocus, points: Int, target: PitchKind?): PitcherSnapshot {
        if (points <= 0) return pitcher
        val ability = when (focus) {
            ProGrowthFocus.STUFF -> com.solkim.baseball.core.pitch.PitchAbilityKind.POWER
            ProGrowthFocus.COMMAND -> com.solkim.baseball.core.pitch.PitchAbilityKind.COMMAND
            ProGrowthFocus.MOVEMENT -> com.solkim.baseball.core.pitch.PitchAbilityKind.MOVEMENT
            ProGrowthFocus.STAMINA -> com.solkim.baseball.core.pitch.PitchAbilityKind.STAMINA
        }
        val before = when (focus) {
            ProGrowthFocus.STUFF -> pitcher.stuff
            ProGrowthFocus.COMMAND -> pitcher.command
            ProGrowthFocus.MOVEMENT -> pitcher.movement
            ProGrowthFocus.STAMINA -> pitcher.stamina
        }
        val after = (before.toLong() + points.toLong()).coerceIn(20L, 80L).toInt()
        val overflow = max(0, points - max(0, after - before))
        val mastery = if (pitcher.mastery != null || overflow > 0) {
            (pitcher.mastery ?: com.solkim.baseball.core.pitch.AbilityMasterySnapshot.ZERO).add(ability, overflow)
        } else null
        val profiles = pitcher.pitchProfiles?.map { profile ->
            val targetMovement = focus == ProGrowthFocus.MOVEMENT && profile.pitchType != PitchKind.FOUR_SEAM && (target == null || target == profile.pitchType)
            profile.copy(
                velocityTenthsKph = (profile.velocityTenthsKph + if (focus == ProGrowthFocus.STUFF) points * 5 else 0).coerceAtMost(PitchAbilityRules.maximumProfileVelocity(profile.pitchType)),
                control = (profile.control + if (focus == ProGrowthFocus.COMMAND) points else 0).coerceIn(20, 80),
                command = (profile.command + if (focus == ProGrowthFocus.COMMAND) points else 0).coerceIn(20, 80),
                movement = (profile.movement + if (targetMovement) points * 2 else 0).coerceIn(20, 80),
                whiff = (profile.whiff + (if (focus == ProGrowthFocus.STUFF && profile.pitchType == PitchKind.FOUR_SEAM) points else 0) + (if (targetMovement) points else 0)).coerceIn(20, 80),
                fatigueCost = if (focus == ProGrowthFocus.STAMINA) max(0, profile.fatigueCost - points / 2) else profile.fatigueCost,
            )
        }
        return pitcher.copy(
            stuff = (pitcher.stuff + if (focus == ProGrowthFocus.STUFF) points else 0).coerceIn(20, 80),
            command = (pitcher.command + if (focus == ProGrowthFocus.COMMAND) points else 0).coerceIn(20, 80),
            movement = (pitcher.movement + if (focus == ProGrowthFocus.MOVEMENT) points else 0).coerceIn(20, 80),
            stamina = (pitcher.stamina + if (focus == ProGrowthFocus.STAMINA) points else 0).coerceIn(20, 80),
            pitchProfiles = profiles,
            mastery = mastery,
        )
    }

    private fun applyEffect(pitcher: PitcherSnapshot, effect: ProDecisionEffect): PitcherSnapshot {
        var value = pitcher
        if (effect.stuffDelta > 0) value = grow(value, ProGrowthFocus.STUFF, effect.stuffDelta, null)
        if (effect.commandDelta > 0) value = grow(value, ProGrowthFocus.COMMAND, effect.commandDelta, null)
        if (effect.movementDelta > 0) value = grow(value, ProGrowthFocus.MOVEMENT, effect.movementDelta, null)
        if (effect.staminaDelta > 0) value = grow(value, ProGrowthFocus.STAMINA, effect.staminaDelta, null)
        if (effect.stuffDelta < 0 || effect.commandDelta < 0 || effect.movementDelta < 0 || effect.staminaDelta < 0) {
            value = value.copy(
                stuff = clamp(value.stuff + min(0, effect.stuffDelta), 20, 80),
                command = clamp(value.command + min(0, effect.commandDelta), 20, 80),
                movement = clamp(value.movement + min(0, effect.movementDelta), 20, 80),
                stamina = clamp(value.stamina + min(0, effect.staminaDelta), 20, 80),
            )
        }
        return value
    }

    private fun seasonTensions(state: ProState): List<ProSeasonTension> {
        val skill = (state.pitcher.stuff + state.pitcher.command + state.pitcher.movement + state.pitcher.stamina) / 4
        val identity = when {
            state.pitcher.stuff >= maxOf(state.pitcher.command, state.pitcher.movement, state.pitcher.stamina) -> "power"
            state.pitcher.command >= maxOf(state.pitcher.movement, state.pitcher.stamina) -> "command"
            state.pitcher.movement >= state.pitcher.stamina -> "movement"
            else -> "stamina"
        }
        val record = when (identity) {
            "power" -> ProSeasonTension("record", "시즌 ${max(120, skill * 2)}탈삼진", "빠른 공으로 타자를 압도해 한 시즌 탈삼진 기록에 도전합니다.")
            "command" -> ProSeasonTension("record", "9이닝당 볼넷 2.5 이하", "정교한 코스 승부로 불필요한 주자를 내보내지 않습니다.")
            "movement" -> ProSeasonTension("record", "9이닝당 피안타 8.5 이하", "결정구의 변화와 약한 타구로 안타를 억제합니다.")
            else -> ProSeasonTension("record", "시즌 ${max(120, skill * 2)}이닝", "후반에도 구위를 지키며 맡은 아웃카운트를 끝까지 책임집니다.")
        }
        val rival = ProCatalog.rivalFor(state.team.id, state.season, 0, ProSeasonTrigger.STANDINGS_RACE)
        return listOf(
            ProSeasonTension("role", "${state.team.positionCompetitor}와의 자리 싸움", "${state.role.label} 한 자리를 두고 시즌 내내 성적을 견줍니다."),
            record,
            ProSeasonTension("rival", "${rival.name} 맞대결", "${rival.teamName}의 ${rival.archetype}. 올 시즌 몇 번이고 마운드에서 마주칩니다."),
        )
    }

    private fun tensionHeadline(values: List<ProSeasonTension>): String = "올해의 세 가지 긴장 · ${values.joinToString(" · ") { it.title }}"

    private fun deriveStandings(state: ProState): List<ProStanding> =
        deriveStandingsForPostseason(state, (state.week * 144 / ProCatalog.WEEKS_PER_SEASON).coerceIn(0, 144))

    private fun deriveLeaderboards(state: ProState): List<ProLeaderboardRow> {
        val rng = SplitMix64(proHash("leaders|${state.seed}|${state.season}") xor (state.season * 31).toULong())
        val rows = mutableListOf<ProLeaderboardRow>()
        ProCatalog.teams.forEachIndexed { teamIndex, team ->
            repeat(2) { slot ->
                val value = (state.week * (80 + rng.nextInt(80)) / 24).coerceAtLeast(0)
                rows += ProLeaderboardRow("strikeouts", 0, "${team.id}-pitcher-$slot", "${team.name} ${if (slot == 0) "선발" else "불펜"}", team.id, value, false)
            }
        }
        rows += ProLeaderboardRow("strikeouts", 0, state.pitcher.id, state.identityName, state.team.id, state.currentStats.strikeouts, true)
        return rows.sortedWith(compareByDescending<ProLeaderboardRow> { it.value }.thenBy { it.playerId }).mapIndexed { index, row -> row.copy(rank = index + 1) }
    }

    private fun legacyCandidates(state: ProState): List<ProLegacyCandidate> {
        val context = state.highSchoolLegacyContext
        val finalStats = if (state.careerStats.lastOrNull()?.season == state.currentStats.season) state.careerStats else state.careerStats + state.currentStats
        val games = finalStats.sumOf { it.games.coerceAtLeast(0) }
        val starts = finalStats.sumOf { it.starts.coerceAtLeast(0) }
        val outs = finalStats.sumOf { it.inningsOuts.coerceAtLeast(0) }
        val strikeouts = finalStats.sumOf { it.strikeouts.coerceAtLeast(0) }
        val walks = finalStats.sumOf { it.walks.coerceAtLeast(0) }
        val hsPitcher = context?.highSchoolPitcher ?: state.pitcher
        val starting = context?.startingPitcher ?: hsPitcher
        val hsGrowth = intArrayOf(
            (hsPitcher.stuff - starting.stuff).coerceAtLeast(0),
            (hsPitcher.command - starting.command).coerceAtLeast(0),
            (hsPitcher.movement - starting.movement).coerceAtLeast(0),
            (hsPitcher.stamina - starting.stamina).coerceAtLeast(0),
        )
        val proGrowth = intArrayOf(
            (state.pitcher.stuff - hsPitcher.stuff).coerceAtLeast(0),
            (state.pitcher.command - hsPitcher.command).coerceAtLeast(0),
            (state.pitcher.movement - hsPitcher.movement).coerceAtLeast(0),
            (state.pitcher.stamina - hsPitcher.stamina).coerceAtLeast(0),
        )
        val performance = context?.performance
        val hsGames = performance?.importantGamesCompleted ?: 0
        val hsStrikeouts = performance?.strikeouts ?: 0
        val hsWalks = performance?.walks ?: 0
        val hsPitches = performance?.pitches ?: 0
        val hsExpected = performance?.expectedDamage ?: 0
        val hsActual = performance?.actualDamage ?: 0
        val hsCoach = context?.managerTrust ?: state.managerTrust
        val hsCatcher = context?.catcherTrust ?: state.catcherTrust
        val hsRival = context?.rivalTrust ?: state.managerTrust
        val selected = context?.selectedAwakenings.orEmpty().toSet()
        fun matched(family: String): Int = when (family) {
            "power" -> setOf("explosive_fastball", "rising_four_seam")
            "command" -> setOf("pinpoint_edge", "repeatable_release", "first_pitch_strike", "scout_composure")
            "breaking" -> setOf("disappearing_breaker", "sinker_tunnel", "frozen_changeup", "sweeping_slider", "curveball_clock")
            "endurance" -> setOf("iron_arm", "late_inning_reserve")
            "gamecraft" -> setOf("calm_under_pressure", "pickoff_rhythm", "two_strike_plan", "traffic_controller", "scout_composure")
            else -> setOf("battery_sync", "pickoff_rhythm", "traffic_controller")
        }.count(selected::contains)
        fun awardScore(family: String): Int {
            val keywords = if (family == "power" || family == "breaking") listOf("탈삼진") else if (family == "endurance") listOf("이닝", "완투") else listOf("최소 실점", "무실점")
            return state.awards.size * 30 + state.awards.count { award -> keywords.any { it in award } } * 120
        }
        val scores = HighSchoolSignatureLegacyRules.definitions.map { definition ->
            val family = definition.family
            val highSchoolScore = when (family) {
                "power" -> hsGrowth[0] * 120 + hsStrikeouts * 12 + matched(family) * 80 + hsRival
                "command" -> hsGrowth[1] * 120 + (hsGames * 3 - hsWalks).coerceAtLeast(0) * 18 + matched(family) * 80 + hsCoach
                "breaking" -> hsGrowth[2] * 120 + hsStrikeouts * 9 + matched(family) * 80 + hsCatcher
                "endurance" -> hsGrowth[3] * 120 + hsPitches / 2 + matched(family) * 80 + hsCoach
                "gamecraft" -> (hsGrowth[1] + hsGrowth[2]) * 60 + (hsExpected - hsActual).coerceAtLeast(0) / 20 + matched(family) * 80 + maxOf(hsCoach, hsCatcher, hsRival)
                else -> hsGrowth[1] * 60 + (hsGames * 3 - hsWalks).coerceAtLeast(0) * 12 + matched(family) * 100 + hsCatcher * 2
            }
            val proScore = when (family) {
                "power" -> proGrowth[0] * 140 + state.pitcher.stuff * 8 + strikeouts * 2 + awardScore(family)
                "command" -> proGrowth[1] * 140 + state.pitcher.command * 8 + (games * 2 - walks).coerceAtLeast(0) * 2 + state.managerTrust * 2 + awardScore(family)
                "breaking" -> proGrowth[2] * 140 + state.pitcher.movement * 8 + strikeouts * 3 / 2 + awardScore(family)
                "endurance" -> proGrowth[3] * 140 + state.pitcher.stamina * 8 + outs / 2 + starts + awardScore(family)
                "gamecraft" -> (proGrowth[1] + proGrowth[2]) * 70 + (state.pitcher.command + state.pitcher.movement) * 4 + (strikeouts - walks).coerceAtLeast(0) + games + maxOf(state.managerTrust, state.catcherTrust) * 2 + awardScore(family)
                else -> (proGrowth[1] + proGrowth[3]) * 70 + (state.pitcher.command + state.pitcher.stamina) * 4 + (games * 2 - walks).coerceAtLeast(0) + games + state.catcherTrust * 3 + awardScore(family)
            }
            definition to highSchoolScore + proScore
        }.sortedWith(compareByDescending<Pair<HighSchoolSignatureLegacyRules.Definition, Int>> { it.second }.thenBy { it.first.id }).take(3)
        return scores.map { (definition, score) ->
            ProLegacyCandidate(
                id = definition.id,
                title = definition.title,
                evidenceSummary = "프로 통산 ${games}경기 · ${strikeouts}탈삼진 · ${walks}볼넷 · 최종 ${ratingSummary(definition.family, state.pitcher)} · ${if (state.awards.isEmpty()) "수상 없음" else "수상 ${state.awards.size}회"}",
                farewell = "마지막 공의 의미를 다음 선수에게 전합니다.",
                score = score,
            )
        }
    }

    private fun ratingSummary(family: String, pitcher: PitcherSnapshot): String = when (family) {
        "power" -> "구위 ${pitcher.stuff}"
        "command" -> "제구 ${pitcher.command}"
        "breaking" -> "변화구 ${pitcher.movement}"
        "endurance" -> "체력 ${pitcher.stamina}"
        "gamecraft" -> "제구 ${pitcher.command}·변화구 ${pitcher.movement}"
        else -> "제구 ${pitcher.command}·체력 ${pitcher.stamina}"
    }

    public fun hallOfFameProjection(state: ProState): Int {
        val includes = state.careerStats.any { it.season == state.currentStats.season && it.teamId == state.currentStats.teamId }
        return hallOfFameScore(if (includes) state else state.copy(careerStats = state.careerStats + state.currentStats,
            serviceYears = state.serviceYears + if (state.level == ProLevel.MAJOR && state.currentStats.games > 0) 1 else 0))
    }

    private fun hallOfFameScore(state: ProState): Int {
        val awardCount = ProCurrentMarketRules.awardCount(state)
        val strikeouts = state.careerStats.sumOf { it.strikeouts }
        val outs = state.careerStats.sumOf { it.inningsOuts }
        val decisions = state.careerStats.sumOf { it.wins + it.saves }
        val quality = state.careerStats.count { it.inningsOuts >= 180 && it.runPerNinePermille < 4_000 }
        val autumnBonus = if (usesAutumnRules(state)) {
            ProPostseasonRules.hofBonus(state.postseason?.result ?: ProPostseasonResult.DID_NOT_QUALIFY)
        } else 0
        if (state.proRulesVersion < HALL_OF_FAME_FORMULA_VERSION) {
            return (strikeouts / 150 + outs / 300 + decisions / 12 + quality * 2 + awardCount * 8 + state.serviceYears * 3).coerceIn(0, 100)
        }
        val longevity = min(15, max(0, state.serviceYears))
        val strikeoutContribution = min(22, max(0, strikeouts) / 200)
        val workloadContribution = min(15, max(0, outs) / 600)
        val decisionContribution = min(9, max(0, decisions) / 25)
        val qualityContribution = min(10, max(0, quality) / 2)
        val awardContribution = if (awardCount >= 3) min(12, 2 + (awardCount - 3) / 8) else 0
        return (longevity + strikeoutContribution + workloadContribution + decisionContribution + qualityContribution + awardContribution + autumnBonus + if (usesNationalTeamRules(state)) state.nationalTeamHistory.count { it.result == ProNationalTournamentResult.GOLD } * ProNationalTeamRules.HOF_GOLD_BONUS else 0).coerceIn(0, 100)
    }

    private fun retirementNews(state: ProState, score: Int): List<String> = buildList {
        add(if (score >= 70) "명예의 전당 헌액이 확정됐습니다." else "은퇴식에서 선수 생활의 마지막 공을 돌아봤습니다.")
        if (state.careerStats.isNotEmpty()) add("통산 ${state.careerStats.size}시즌 · ${state.careerGames()}경기 · ${state.careerStrikeouts()}탈삼진")
        add("마지막 공은 ${state.team.name}의 유니폼으로 던졌습니다.")
    }

    private fun addCareerMilestones(state: ProState, games: Int, strikeouts: Int, values: MutableList<String>) {
        val priorGames = state.careerGames()
        val priorStrikeouts = state.careerStrikeouts()
        val nextGames = priorGames + games
        val nextStrikeouts = priorStrikeouts + strikeouts
        listOf(50, 100, 300).filter { priorGames < it && nextGames >= it }.forEach { values.addUnique("프로 통산 ${it}경기") }
        listOf(50, 100, 200, 500).filter { priorStrikeouts < it && nextStrikeouts >= it }.forEach { values.addUnique("프로 통산 ${it}탈삼진") }
    }

    private fun validatePitch(value: ProPitchSession) {
        require(value.pitchIndex == value.pitches) { "pro.pitch_index" }
        require(value.log.totalPitches == value.pitches && value.log.entries.size == value.pitches) { "pro.pitch_log" }
        require(value.sequenceMasteryCount in 0..value.pitches && value.sequencePitches.size <= 3) { "pro.pitch_sequence" }
        require(value.ended == (value.boundary == ProPitchBoundary.COMPLETED)) { "pro.pitch_boundary" }
        if (value.boundary == ProPitchBoundary.RESERVED) {
            require(value.pitchIndex == 0 && value.pitches == 0 && value.preparationToken.isNotBlank()) { "pro.pitch_reserved_shape" }
        }
        if (value.boundary == ProPitchBoundary.PLAYING) {
            require(value.pitchIndex > 0 && value.preparationToken.isNotBlank()) { "pro.pitch_playing_shape" }
        }
        if (value.boundary == ProPitchBoundary.COMPLETED) {
            require(value.preparationToken.isEmpty()) { "pro.pitch_completed_shape" }
        }
        if (!value.ended) require(value.preparationToken.isNotBlank()) { "pro.pitch_preparation" }
    }

    private fun targetPitchFor(plan: ProWeekPlan, target: PitchKind?, pitcher: PitcherSnapshot): PitchKind? =
        if (plan == ProWeekPlan.DEVELOP_MOVEMENT || plan == ProWeekPlan.DEVELOP_WEAPON) target?.takeIf { it != PitchKind.FOUR_SEAM && pitcher.pitchProfiles?.any { profile -> profile.pitchType == target } == true } else null

    private fun clamp(value: Int, low: Int, high: Int): Int = value.coerceIn(low, high)

    private fun MutableList<String>.addUnique(value: String) { if (!contains(value)) add(value) }
    private fun List<String>.addUnique(value: String): List<String> = if (contains(value)) this else this + value
}

private fun com.solkim.baseball.core.pitch.PitchSnapshot.toProContext(
    previous: PlateAppearanceContext,
    game: GameStateSnapshot,
): PlateAppearanceContext = PlateAppearanceContext(
    plateAppearanceId = previous.plateAppearanceId,
    revision = revision,
    inning = game.inningState?.inning ?: previous.inning,
    outs = game.inningState?.outs ?: previous.outs,
    balls = balls,
    strikes = strikes,
    pitchNumber = if (result == null) previous.pitchNumber + 1 else 1,
    scoreDifferential = previous.scoreDifferential,
    leverage = previous.leverage,
    fatigue = fatigueAfterPitch,
)
