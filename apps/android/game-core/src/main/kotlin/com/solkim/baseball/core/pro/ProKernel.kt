package com.solkim.baseball.core.pro

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
        return result(state, seed.nextSeed(), listOf("pro_career_started", "pro_linked_start"))
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
        val seed = seed(seedText)
        return result(signContractInternal(state), seed.nextSeed(), listOf("rookie_contract_signed"))
    }

    public fun normalizeBalance(state: ProState): ProResult {
        validateSavedState(state)
        val normalized = signed(state.copy(commitment = ""))
        return ProResult(normalized, state.seed, emptyList())
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
        val lines = mutableListOf<ProGameLine>()
        var outs = 0
        var strikeouts = 0
        var walks = 0
        var runsAllowed = 0
        var hits = 0
        var homeRuns = 0
        var pitches = 0
        var rng = SplitMix64(seed.value)
        if (!recovering) {
            repeat(roles.first) { outingIndex ->
                val weekSalt = nextWeek.toULong() * 0x9E37UL
                val baseSeed = (rng.next() xor weekSalt) + outingIndex.toULong()
                val line = automaticOuting.simulate(
                    pitcher = state.pitcher,
                    startingFatigue = state.fatigue + outingIndex * 5,
                    outsTarget = roles.second,
                    pitchCap = roles.third,
                    baseSeed = baseSeed,
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
        val games = if (recovering) 0 else roles.first
        val starts = if (recovering || state.role != ProRole.STARTER) 0 else 1
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
        val fatiguePressure = PitchAbilityRules.effectiveFatigue(fatigue, state.pitcher.stamina)
        val injuryWeeks = if (!recovering && injuryRoll < max(2, fatiguePressure - 72)) {
            2 + rng.nextInt(4)
        } else {
            max(0, state.injuryWeeks - 1)
        }
        val performanceTrust = when {
            runsAllowed <= 2 -> 3
            runsAllowed == 3 -> 0
            runsAllowed <= 5 -> -3
            else -> -6
        }
        val trustGain = when {
            recovering -> -1
            plan == ProWeekPlan.EARN_TRUST -> 5
            plan == ProWeekPlan.RECOVER -> 0
            else -> performanceTrust
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
        val development = resolveDevelopment(state.pitcher, state.developmentProgress, plan, targetPitch, recovering)
        val priorImportantGames = state.importantGames
        val trigger = if (nextWeek >= ProCatalog.WEEKS_PER_SEASON || lines.isEmpty()) null else importantGameTrigger(
            state, nextWeek, level, managerTrust, currentStats, skill, priorImportantGames,
        )
        val decisionsThisSeason = state.decisionHistory.count { it.season == state.season }
        val openDecision = nextWeek < ProCatalog.WEEKS_PER_SEASON &&
            ProCatalog.SEASON_DECISION_WEEKS.contains(nextWeek) && trigger == null &&
            !recovering && injuryWeeks == 0 && decisionsThisSeason < 3
        val pending = if (openDecision) seasonDecision(state, nextWeek) else null
        val phase = when {
            nextWeek >= ProCatalog.WEEKS_PER_SEASON -> ProCareerPhase.SEASON_REVIEW
            trigger != null -> ProCareerPhase.IMPORTANT_GAME
            pending != null -> ProCareerPhase.SEASON_DECISION
            else -> ProCareerPhase.WEEKLY_PLAN
        }
        val rival = trigger?.let { ProCatalog.rivalFor(state.team.id, state.season, nextWeek, it) }
        val segment = ProCatalog.segment(nextWeek)
        val news = state.news.toMutableList()
        val milestones = state.milestones.toMutableList()
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
        if (phase == ProCareerPhase.IMPORTANT_GAME && trigger != null) news.add(0, importantHeadline(trigger, rival, level))
        val updated = state.copy(
            revision = state.revision + 1UL,
            pitcher = development.pitcher,
            week = nextWeek,
            phase = phase,
            level = level,
            role = role,
            managerTrust = managerTrust,
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
            importantGames = priorImportantGames + if (phase == ProCareerPhase.IMPORTANT_GAME) 1 else 0,
            pendingDecision = pending,
            standings = deriveStandings(state.copy(week = nextWeek, currentGameLines = state.currentGameLines + lines, currentStats = currentStats)),
            leaderboards = deriveLeaderboards(state.copy(week = nextWeek, currentStats = currentStats, currentGameLines = state.currentGameLines + lines)),
            activePitch = null,
            lastPresentation = null,
            commitment = "",
        )
        val events = buildList {
            add("pro_week_resolved")
            add(if (state.level != level && level == ProLevel.MAJOR) "major_call_up" else "weekly_progress")
            if (phase == ProCareerPhase.SEASON_DECISION) add("pro_season_decision_opened")
            if (phase == ProCareerPhase.IMPORTANT_GAME) add("pro_important_game_opened")
            if (phase == ProCareerPhase.SEASON_REVIEW) add("pro_season_review_opened")
        }
        return result(updated, seed.nextSeed(rng.next()), events)
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
        validate(state, ProCareerPhase.SEASON_DECISION)
        seed(seedText)
        val pending = state.pendingDecision ?: throw ProKernelException("pro.decision_missing")
        require(pending.id == decisionId) { "pro.decision_stale" }
        require(state.decisionHistory.none { it.decisionId == pending.id }) { "pro.decision_duplicate" }
        val choice = pending.choices.firstOrNull { it.id == choiceId } ?: throw ProKernelException("pro.choice_unknown")
        val effect = choice.effect
        val history = state.decisionHistory + ProDecisionRecord(
            pending.id, pending.type, pending.season, pending.week, choice.id, choice.title, effect,
        )
        val rolePreference = if (pending.type == ProSeasonDecisionType.ROLE_MEETING) effect.roleTarget ?: state.role else state.rolePreference
        val next = state.copy(
            revision = state.revision + 1UL,
            phase = ProCareerPhase.WEEKLY_PLAN,
            pitcher = applyEffect(state.pitcher, effect),
            role = effect.roleTarget ?: state.role,
            rolePreference = rolePreference,
            managerTrust = clamp(state.managerTrust + effect.managerTrustDelta, 0, 100),
            catcherTrust = clamp(state.catcherTrust + effect.catcherTrustDelta, 0, 100),
            fatigue = clamp(state.fatigue + effect.fatigueDelta, 0, 100),
            pendingDecision = null,
            decisionHistory = history,
            news = (listOf("${pending.title} · ${choice.title} — ${effect.summary()}") + state.news).take(30),
            commitment = "",
        )
        return result(next, seedText, listOf("pro_season_decision_resolved"))
    }

    public fun reserveImportantGame(state: ProState, seedText: String): ProResult {
        validate(state, ProCareerPhase.IMPORTANT_GAME)
        require(state.activePitch == null) { "pro.pitch_already_reserved" }
        val seed = seed(seedText)
        val rival = state.currentRival ?: ProCatalog.rivalFor(state.team.id, state.season, state.week, state.seasonTrigger ?: ProSeasonTrigger.STANDINGS_RACE)
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
        val context = PlateAppearanceContext(
            plateAppearanceId = "${state.careerId}:season:${state.season}:week:${state.week}:important",
            revision = 0UL,
            inning = 7,
            outs = 1,
            balls = 0,
            strikes = 0,
            pitchNumber = 1,
            scoreDifferential = -1,
            leverage = 850,
            fatigue = state.fatigue,
        )
        val memory = RivalMemorySnapshot("${state.pitcher.id}:${batter.id}", 0UL, 0, 0, emptyList())
        val game = GameStateSnapshot(
            defense = DefenseSnapshot(50, 50, 50, listOf("pitcher", "catcher", "first_base", "second_base", "third_base", "shortstop", "left_field", "center_field", "right_field").map { FielderSnapshot("$it", it, it, 50, 50, 50) }),
            park = ParkSnapshot("pro-important-park", "중립 구장", 1_000, 1_000),
            runners = BaserunnerStateSnapshot(false, true, false, 52),
            runsAllowed = 0,
            inningState = InningStateSnapshot(7, HalfInning.TOP, 1),
        )
        val log = GameLogSnapshot("${state.careerId}:important:${state.importantGames}", 0UL, 0, emptyList())
        val preparation = pitch.prepare(PitchKernel.PrepareRequest(seedText, state.pitcher, batter, scouting, context, memory, game, log))
        val session = ProPitchSession(
            sessionId = "${state.careerId}:important:${state.importantGames}",
            week = state.week,
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
        val next = state.copy(revision = state.revision + 1UL, activePitch = session, lastPresentation = null, commitment = "")
        return result(next, seedText, listOf("pro_pitch_reserved"), preparation)
    }

    public fun submitPitch(state: ProState, sessionId: String, call: PitchCall, delivery: PitchDelivery = PitchDelivery.NEUTRAL): ProResult {
        validate(state, ProCareerPhase.IMPORTANT_GAME)
        val session = state.activePitch ?: throw ProKernelException("pro.pitch_missing")
        require(session.sessionId == sessionId) { "pro.pitch_session_stale" }
        require(!session.ended) { "pro.pitch_ended" }
        require(session.boundary != ProPitchBoundary.COMPLETED) { "pro.pitch_boundary_completed" }
        val preparation = pitch.prepare(PitchKernel.PrepareRequest(session.seed, state.pitcher, session.batter, session.scouting, session.context, session.memory, session.game, session.log))
        require(preparation.preparationToken == session.preparationToken) { "pro.pitch_preparation_stale" }
        val submitted = pitch.submit(
            PitchKernel.SubmitRequest(session.seed, state.pitcher, session.batter, session.scouting, session.context, session.preparationToken, call, session.memory, session.game, session.log),
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
            lastPresentation = snapshot.trajectoryPresentation,
            commitment = "",
        )
        return result(next, submitted.nextSeed, listOf("pro_pitch_submitted"), submitted.nextPreparation, snapshot.trajectoryPresentation)
    }

    public fun finishImportantGame(state: ProState): ProResult {
        validate(state, ProCareerPhase.IMPORTANT_GAME)
        val session = state.activePitch ?: throw ProKernelException("pro.pitch_missing")
        require(session.ended) { "pro.pitch_in_progress" }
        val scheduledIndex = state.currentGameLines.indexOfLast { it.week == state.week && !it.played }
        val scheduled = scheduledIndex.takeIf { it >= 0 }?.let { state.currentGameLines[it] }
        val started = scheduled?.started ?: (state.role == ProRole.STARTER)
        val rng = SplitMix64(seed(session.seed).value)
        val directOuts = session.outs
        val scheduledOuts = scheduled?.outs ?: 0
        val complementOuts = max(0, scheduledOuts - directOuts)
        fun retained(value: Int): Int = if (scheduledOuts > 0) value * complementOuts / scheduledOuts else 0
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
            lastPresentation = null,
            decisionHistory = history,
            milestones = if (state.level == ProLevel.MAJOR) state.milestones.addUnique("1군 첫 중요 승부") else state.milestones,
            news = (listOf("승부처 등판 · ${session.strikeouts}탈삼진 · ${session.walks}볼넷 · ${session.runsAllowed}실점 · 감독의 믿음 ${if (trustDelta >= 0) "+" else ""}$trustDelta") + state.news).take(30),
            standings = deriveStandings(state.copy(currentGameLines = lines, currentStats = stats)),
            leaderboards = deriveLeaderboards(state.copy(currentGameLines = lines, currentStats = stats)),
            commitment = "",
        )
        return result(next, rng.next().toString(), listOf("pro_important_game_resolved"))
    }

    public fun reviewSeason(state: ProState, seedText: String): ProResult {
        validate(state, ProCareerPhase.SEASON_REVIEW)
        val seed = seed(seedText)
        val stats = state.currentStats
        var awards = state.awards
        if (stats.strikeouts >= 120) awards = awards.addUnique("시즌 ${state.season} 탈삼진상")
        if (stats.runPerNinePermille < 3_000 && stats.games >= 20) awards = awards.addUnique("시즌 ${state.season} 최소 실점상")
        val bb9 = if (stats.inningsOuts == 0) 9_990 else stats.walks * 27_000 / stats.inningsOuts
        if (bb9 < 2_500 && stats.inningsOuts >= 180) awards = awards.addUnique("시즌 ${state.season} 정밀 제구상")
        val h9 = if (stats.inningsOuts == 0) 9_990 else stats.hits * 27_000 / stats.inningsOuts
        if (h9 < 8_500 && stats.inningsOuts >= 180) awards = awards.addUnique("시즌 ${state.season} 피안타 억제상")
        if (stats.inningsOuts >= 360) awards = awards.addUnique("시즌 ${state.season} 이닝 책임상")
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
        val phase = if (state.season >= ProCatalog.MAXIMUM_CAREER_SEASONS) ProCareerPhase.RETIREMENT_DECISION else ProCareerPhase.OFFSEASON_DECISION
        val next = state.copy(
            revision = state.revision + 1UL,
            phase = phase,
            awards = awards,
            milestones = milestones,
            careerStats = state.careerStats + stats,
            seasonLedgers = state.seasonLedgers + ledger,
            news = (listOf("시즌 ${state.season} 종료 · ${stats.games}경기 · ${stats.strikeouts}K · 9이닝당 실점 ${"%.2f".format(java.util.Locale.ROOT, stats.runPerNinePermille / 1_000.0)}") + state.news).take(30),
            commitment = "",
        )
        return result(next, seed.nextSeed(), listOf("pro_season_reviewed"))
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
                hallOfFameScore = score,
                milestones = state.milestones.addUnique("은퇴 · 통산 ${state.careerStats.size}시즌"),
                news = (retirementNews(state, score) + state.news).take(30),
                commitment = "",
            )
            return result(next, seed.nextSeed(), listOf(if (candidates.isEmpty()) "pro_career_retired" else "pro_legacy_candidates_frozen"))
        }
        var age = state.age + 1
        var military = state.militaryCompleted
        val service = state.serviceYears + if (state.level == ProLevel.MAJOR) 1 else 0
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
                val index = ProCatalog.teams.indexOfFirst { it.id == state.team.id }.coerceAtLeast(0)
                team = ProCatalog.teams[(index + 3) % ProCatalog.teams.size]
                news.add(0, "FA 계약: ${team.name}과 새 도전을 시작합니다.")
            }
            OffseasonDecision.CONTINUE -> Unit
            OffseasonDecision.RETIRE -> error("unreachable")
        }
        val season = state.season + 1
        val decline = if (age >= 33) 1 else 0
        val pitcher = if (decline == 0) state.pitcher else state.pitcher.copy(
            stuff = clamp(state.pitcher.stuff - decline, 20, 80),
            movement = clamp(state.pitcher.movement - decline, 20, 80),
            stamina = clamp(state.pitcher.stamina - decline, 20, 80),
        )
        val contract = ProContract(
            yearsRemaining = max(1, (state.contract?.yearsRemaining ?: 1) - 1),
            annualSalary = max(state.contract?.annualSalary ?: 40_000_000, 40_000_000 + service * 50_000_000),
            rolePromise = state.role,
        )
        val base = state.copy(
            revision = state.revision + 1UL,
            phase = ProCareerPhase.WEEKLY_PLAN,
            pitcher = pitcher,
            team = team,
            age = age,
            season = season,
            week = 0,
            rolePreference = null,
            fatigue = 0,
            injuryWeeks = 0,
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
            lastPresentation = null,
            news = news.take(30),
            commitment = "",
        )
        val next = base.copy(
            seasonTensions = seasonTensions(base),
            news = (listOf(tensionHeadline(seasonTensions(base))) + base.news).take(30),
            standings = deriveStandings(base),
            leaderboards = deriveLeaderboards(base),
            commitment = "",
        )
        return result(next, seed.nextSeed(), listOf("pro_offseason_resolved"))
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
        requireStatsShape(state.currentStats, state.season, state.team.id, "pro.stats")
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
            require(ledger.decisionCount in 0..3) { "pro.ledger_decisions" }
            require(ledger.milestones.isNotEmpty()) { "pro.ledger_milestones" }
            requireStandingSnapshot(ledger.standings, "pro.ledger_standings")
            requireLeaderboardSnapshot(ledger.leaderboards, "pro.ledger_leaderboards")
        }
        require((state.phase == ProCareerPhase.SEASON_DECISION) == (state.pendingDecision != null)) { "pro.decision_phase" }
        state.pendingDecision?.let { validateDecision(it, state.season, state.week) }
        require(state.decisionHistory.map { it.decisionId }.distinct().size == state.decisionHistory.size) { "pro.decision_unique" }
        require(state.decisionHistory.all {
            it.season in 1..state.season && it.week in ProCatalog.SEASON_DECISION_WEEKS && it.choiceId.isNotBlank()
        }) { "pro.decision_record" }
        require(state.decisionHistory.groupingBy { it.season }.eachCount().values.all { it <= 3 }) { "pro.decision_limit" }
        require(state.commandReceipts.map { it.commandId }.distinct().size == state.commandReceipts.size) { "pro.command_receipts_unique" }
        require(state.commandReceipts.zipWithNext().all { (a, b) -> a.revision < b.revision }) { "pro.command_receipts_order" }
        require(state.commandReceipts.all { it.commandId.isNotBlank() && it.sessionId.isNotBlank() && it.revision <= state.revision }) { "pro.command_receipt_shape" }
        if (state.phase != ProCareerPhase.CONTRACT_OFFER) {
            require(state.contract != null) { "pro.contract_missing" }
            requireStandingSnapshot(state.standings, "pro.standings")
            requireLeaderboardSnapshot(state.leaderboards, "pro.leaderboards")
        } else {
            require(state.contract == null) { "pro.contract_unexpected" }
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
            add(state.sourceHighSchoolCareerId ?: "-"); add(state.highSchoolLegacyContext?.toString() ?: "-"); add(state.activeHighSchoolPreserved.toString()); add(state.seed)
            add(state.identityName); add(state.pitcher.toString()); add(state.team.toString()); add(state.entitlement.toString())
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
            state.journeyState?.let { add("journey:v1:${ProJourneyStateCodec.canonicalToken(it)}") }
        }
        return StableHash.fnv1a64(values.joinToString("|"))
    }

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
            lastPresentation = null,
            lastSegmentProgress = null,
            hallOfFameScore = null,
            news = listOf("신인 계약 제안 · ${team.name} · $identityName${if (draftEvaluation > 0) " · 평가 $draftEvaluation" else ""}"),
        )
        return signed(state)
    }

    private fun signContractInternal(state: ProState): ProState {
        val tensions = seasonTensions(state)
        val contract = ProContract(3, max(30_000_000, state.pitcher.stuff * 1_000_000), ProRole.STARTER)
        return signed(state.copy(
            revision = state.revision + 1UL,
            phase = ProCareerPhase.WEEKLY_PLAN,
            contract = contract,
            milestones = state.milestones.addUnique("신인 계약"),
            news = (listOf("신인 계약에 서명했습니다. 2군 선발 경쟁이 시작됩니다.", tensionHeadline(tensions)) + state.news).take(30),
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

    private fun result(state: ProState, nextSeed: String, events: List<String>, preparation: PitchPreparation? = null, presentation: com.solkim.baseball.core.pitch.TrajectoryPresentationSnapshot? = null): ProResult =
        ProResult(signed(state), nextSeed, events, preparation, presentation)

    private fun validate(state: ProState, phase: ProCareerPhase) {
        require(state.phase == phase) { "pro.expected_phase:${phase.wire}:${state.phase.wire}" }
        validateSavedState(state)
    }

    private fun signed(state: ProState): ProState = state.copy(commitment = commitment(state.copy(commitment = "")))

    private fun seasonDecision(state: ProState, week: Int): ProSeasonDecision {
        val slot = ProCatalog.SEASON_DECISION_WEEKS.indexOf(week)
        require(slot >= 0) { "pro.decision_week" }
        val types = ProSeasonDecisionType.entries
        val type = types[(proHash("${state.careerId}|season${state.season}|season-decisions") % types.size.toULong()).toInt().plus(slot).mod(types.size)]
        val choices = when (type) {
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
        }
        val title = type.title
        return ProSeasonDecision("season-${state.season}-week-$week-${type.wire}", type, state.season, week, title, type.detail, choices)
    }

    private fun choice(type: ProSeasonDecisionType, suffix: String, title: String, detail: String, effect: ProDecisionEffect) =
        ProDecisionChoice("${type.wire}.$suffix", title, detail, effect)

    private val ProSeasonDecisionType.title: String
        get() = when (this) {
            ProSeasonDecisionType.EXTRA_BULLPEN -> "추가 불펜"
            ProSeasonDecisionType.CATCHER_GAME_PLAN -> "포수와 경기 계획"
            ProSeasonDecisionType.ROLE_MEETING -> "역할 면담"
            ProSeasonDecisionType.RECORD_CHASE -> "기록 추격"
            ProSeasonDecisionType.RIVAL_ANALYSIS -> "라이벌 분석"
            ProSeasonDecisionType.SEASON_FINALE -> "시즌 막바지"
        }

    private val ProSeasonDecisionType.detail: String
        get() = when (this) {
            ProSeasonDecisionType.EXTRA_BULLPEN -> "정규 훈련이 끝난 뒤 마운드 사용 시간이 남았습니다."
            ProSeasonDecisionType.CATCHER_GAME_PLAN -> "다음 등판의 구종 순서와 승부 방식을 정합니다."
            ProSeasonDecisionType.ROLE_MEETING -> "코칭스태프가 남은 시즌의 등판 역할을 묻습니다."
            ProSeasonDecisionType.RECORD_CHASE -> "개인 기록과 팀에 필요한 투구 사이에서 훈련 방향을 고릅니다."
            ProSeasonDecisionType.RIVAL_ANALYSIS -> "다음 맞대결을 앞두고 분석 시간을 어디에 쓸지 정합니다."
            ProSeasonDecisionType.SEASON_FINALE -> "순위 경쟁과 회복, 동료 지원 사이에서 마지막 힘을 배분합니다."
        }

    private fun validateDecision(value: ProSeasonDecision, season: Int, week: Int) {
        require(value.id == "season-$season-week-$week-${value.type.wire}") { "pro.decision_id" }
        require(value.season == season && value.week == week && value.choices.size == 3) { "pro.decision_shape" }
        require(value.choices.map { it.id }.distinct().size == 3) { "pro.decision_choices" }
        require(value.choices.all { it.id.startsWith("${value.type.wire}.") && it.title.isNotBlank() && it.detail.isNotBlank() }) { "pro.decision_copy" }
        require(value.choices.all { effectReasonable(it.effect) }) { "pro.decision_effect" }
    }

    private fun effectReasonable(effect: ProDecisionEffect): Boolean =
        listOf(effect.stuffDelta, effect.commandDelta, effect.movementDelta, effect.staminaDelta).all { it in -4..4 } &&
            listOf(effect.managerTrustDelta, effect.catcherTrustDelta).all { it in -20..20 } && effect.fatigueDelta in -30..30

    private fun importantGameTrigger(state: ProState, nextWeek: Int, level: ProLevel, trust: Int, stats: ProSeasonStats, skill: Int, prior: Int): ProSeasonTrigger? {
        if (prior >= 3) return null
        val segment = ProCatalog.segment(nextWeek)
        if (state.level == ProLevel.MINOR && level == ProLevel.MAJOR && (segment == ProSeasonSegment.SEASON_FINALE || prior < 2)) return ProSeasonTrigger.MAJOR_DEBUT
        if (segment == ProSeasonSegment.OPENING && nextWeek == anchorWeek(state, "opening", 2, 4)) return ProSeasonTrigger.OPENING_STATEMENT
        if (segment == ProSeasonSegment.SEASON_FINALE && nextWeek == anchorWeek(state, "finale", 21, 23)) return ProSeasonTrigger.STANDINGS_RACE
        if (prior >= 2) return null
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
        }
    }

    private data class DevelopmentResolution(val pitcher: PitcherSnapshot, val progress: ProDevelopmentProgress, val labels: List<String>)

    private fun resolveDevelopment(pitcher: PitcherSnapshot, progress: ProDevelopmentProgress, plan: ProWeekPlan, target: PitchKind?, paused: Boolean): DevelopmentResolution {
        if (paused || plan == ProWeekPlan.RECOVER || plan == ProWeekPlan.EARN_TRUST) return DevelopmentResolution(pitcher, progress, emptyList())
        var value = pitcher
        var stuff = progress.stuff
        var command = progress.command
        var movement = progress.movement
        var stamina = progress.stamina
        val labels = mutableListOf<String>()
        fun advance(current: Int, setter: (Int) -> Unit, focus: ProGrowthFocus, label: String, pitch: PitchKind? = null) {
            if (current == 0) setter(1) else {
                setter(0)
                value = grow(value, focus, 1, pitch)
                labels += "$label +1"
            }
        }
        when (plan) {
            ProWeekPlan.DEVELOP_STUFF -> advance(stuff, { stuff = it }, ProGrowthFocus.STUFF, "구위")
            ProWeekPlan.REFINE_COMMAND -> advance(command, { command = it }, ProGrowthFocus.COMMAND, "제구")
            ProWeekPlan.DEVELOP_MOVEMENT -> advance(movement, { movement = it }, ProGrowthFocus.MOVEMENT, "변화구", target)
            ProWeekPlan.BUILD_STAMINA -> advance(stamina, { stamina = it }, ProGrowthFocus.STAMINA, "체력")
            ProWeekPlan.DEVELOP_WEAPON -> {
                advance(stuff, { stuff = it }, ProGrowthFocus.STUFF, "구위")
                advance(movement, { movement = it }, ProGrowthFocus.MOVEMENT, "변화구", target)
            }
            else -> Unit
        }
        return DevelopmentResolution(value, ProDevelopmentProgress(stuff, command, movement, stamina), labels)
    }

    private enum class ProGrowthFocus { STUFF, COMMAND, MOVEMENT, STAMINA }

    private fun grow(pitcher: PitcherSnapshot, focus: ProGrowthFocus, points: Int, target: PitchKind?): PitcherSnapshot {
        if (points <= 0) return pitcher
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

    private fun deriveStandings(state: ProState): List<ProStanding> {
        val gamesPlayed = (state.week * 144 / ProCatalog.WEEKS_PER_SEASON).coerceIn(0, 144)
        if (gamesPlayed == 0) return ProCatalog.teams.mapIndexed { index, team -> ProStanding(index + 1, team.id, team.name, 0, 0, 0, 0, team.id == state.team.id) }
        val rng = SplitMix64(proHash("league|${state.seed}|${state.season}") xor state.season.toULong())
        val rows = ProCatalog.teams.mapIndexed { index, team ->
            val draws = (2 + rng.nextInt(4)) * gamesPlayed / 144
            val expected = (gamesPlayed - draws) * (380 + rng.nextInt(241)) / 1_000
            val wins = (expected + rng.nextInt(7) - 3).coerceIn(0, gamesPlayed - draws)
            ProStanding(0, team.id, team.name, wins, gamesPlayed - draws - wins, draws, 0, team.id == state.team.id)
        }.toMutableList()
        val playerLines = state.currentGameLines
        val playerIndex = rows.indexOfFirst { it.teamId == state.team.id }
        if (playerIndex >= 0 && playerLines.isNotEmpty()) {
            val generated = rows[playerIndex]
            val mine = playerLines.take(gamesPlayed)
            val wins = mine.count { it.teamRuns > it.opponentRuns }
            val losses = mine.count { it.teamRuns < it.opponentRuns }
            val draws = mine.size - wins - losses
            val remaining = max(0, gamesPlayed - mine.size)
            val scaledWins = generated.wins * remaining / max(1, gamesPlayed)
            val scaledDraws = min(remaining - min(remaining, scaledWins), generated.draws * remaining / max(1, gamesPlayed))
            rows[playerIndex] = generated.copy(wins = wins + scaledWins, losses = losses + max(0, remaining - scaledWins - scaledDraws), draws = draws + scaledDraws)
        }
        val leaderWins = rows.maxOf { it.wins }
        val leaderLosses = rows.minOf { it.losses }
        return rows.map { it.copy(gamesBehindPermille = ((leaderWins - it.wins) + (it.losses - leaderLosses)) * 500) }
            .sortedWith(compareByDescending<ProStanding> { it.wins * 1_000 / max(1, it.wins + it.losses) }.thenByDescending { it.wins })
            .mapIndexed { index, row -> row.copy(rank = index + 1) }
    }

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

    private fun hallOfFameScore(state: ProState): Int {
        val strikeouts = state.careerStats.sumOf { it.strikeouts }
        val outs = state.careerStats.sumOf { it.inningsOuts }
        val decisions = state.careerStats.sumOf { it.wins + it.saves }
        val quality = state.careerStats.count { it.inningsOuts >= 180 && it.runPerNinePermille < 4_000 }
        return (strikeouts / 150 + outs / 300 + decisions / 12 + quality * 2 + state.awards.size * 8 + state.serviceYears * 3).coerceIn(0, 100)
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
