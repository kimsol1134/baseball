package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.pitch.PitchLearningProject
import com.solkim.baseball.core.pitch.PitchLearningRules
import com.solkim.baseball.core.StableHash
import com.solkim.baseball.core.pitch.BatSide
import com.solkim.baseball.core.pitch.BatterScoutingSnapshot
import com.solkim.baseball.core.pitch.BatterSnapshot
import com.solkim.baseball.core.pitch.GameLogSnapshot
import com.solkim.baseball.core.pitch.PitchCall
import com.solkim.baseball.core.pitch.PitchDelivery
import com.solkim.baseball.core.pitch.PitchAbilityRules
import com.solkim.baseball.core.pitch.PitchKernel
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchOutcome
import com.solkim.baseball.core.pitch.PitchPreparation
import com.solkim.baseball.core.pitch.PitchSequenceEvaluator
import com.solkim.baseball.core.pitch.PitchSequencePitch
import com.solkim.baseball.core.pitch.PitchSnapshot
import com.solkim.baseball.core.pitch.PitchZone
import com.solkim.baseball.core.pitch.PlateAppearanceContext
import com.solkim.baseball.core.pitch.RivalMemorySnapshot
import com.solkim.baseball.core.pitch.ZoneIntent
import com.solkim.baseball.model.Hashing
import kotlin.math.max

/**
 * Pure Kotlin Phase 4 shadow authority.  It owns every durable HighSchool/Core Meta transition
 * and calls [PitchKernel] only for a presentation-ready pitch snapshot. Unity is intentionally
 * absent from this module and cannot produce an outcome, score, archive, or save mutation.
 */
public class HighSchoolPhase4Kernel(
    private val highSchool: HighSchoolKernel = HighSchoolKernel(),
    private val pitch: PitchKernel = PitchKernel(),
) {
    public fun start(request: HighSchoolPhase4StartRequest): HighSchoolPhase4Result {
        require(request.stableUserId.isNotBlank()) { "stableUserId.invalid" }
        require(request.weekKey.isNotBlank()) { "weekKey.invalid" }
        request.lineageLoadout?.let { loadout ->
            require(loadout.legacyId == request.inheritedSignatureLegacyId) { "lineage.signature_mismatch" }
            require(loadout.sourceLifeNumber == null || loadout.sourceLifeNumber < request.lifeNumber) {
                "lineage.source_life"
            }
            require(loadout.rulesVersion in 1..HighSchoolLineageRules.RULES_VERSION) { "lineage.rules_version" }
        }
        request.inheritedLineageMasteries.forEach { mastery ->
            require(mastery.family in setOf("power", "command", "breaking", "endurance", "gamecraft", "battery")) {
                "lineage.family"
            }
            require(mastery.contributions >= 0 && mastery.rank == HighSchoolLineageRules.masteryRank(mastery.contributions)) {
                "lineage.mastery"
            }
            require(mastery.nextThreshold == HighSchoolLineageRules.nextThreshold(mastery.contributions)) {
                "lineage.threshold"
            }
        }
        require(request.inheritedLineageMasteries.distinctBy { it.family }.size == request.inheritedLineageMasteries.size) {
            "lineage.mastery_duplicate"
        }
        request.inheritedNextRunIntent?.let { intent ->
            require(intent.sourceLifeNumber > 0 && intent.sourceLifeNumber < request.lifeNumber) {
                "next_intent.source_life"
            }
            HighSchoolPledgeRules.definition(intent.pledgeId)
            require(intent.reason.isNotBlank()) { "next_intent.reason" }
        }
        val baseRun = highSchool.start(
            HighSchoolKernel.StartRequest(
                seed = request.seed,
                presetId = request.presetId,
                lifeNumber = request.lifeNumber,
                creationAllocation = request.creationAllocation,
                inheritedSoulPoints = request.inheritedSoulPoints,
                inheritedSoulTotal = request.inheritedSoulTotal,
                inheritedSoulDomain = request.inheritedSoulDomain,
                inheritedMemories = request.inheritedMemories,
                identity = request.identity,
                difficulty = request.difficulty,
                karmas = request.karmas,
                soulBoosts = request.soulBoosts,
                inheritanceRulesVersion = request.inheritanceRulesVersion,
                signatureLegacyId = request.inheritedSignatureLegacyId,
                rebirthEcho = request.inheritedRebirthEcho,
            ),
        ).snapshot
        val lineage = HighSchoolLineageRules.apply(request.lineageLoadout, baseRun.pitcher, baseRun.talent)
        val run = highSchool.resignShadowState(
            baseRun.copy(
                pitcher = if (baseRun.balanceVersion >= 7) HighSchoolRebirthGrowthRules.apply(lineage.pitcher, request.inheritedLineageMasteries.sumOf { it.contributions.toLong() }.coerceAtMost((request.lifeNumber - 1).toLong()).toInt()) else lineage.pitcher,
                talent = lineage.talent,
                catcherTrust = lineage.catcherTrust,
            ),
        )
        val weekly = HighSchoolWeeklyRules.make(request.stableUserId, request.weekKey, run.careerId)
        val inheritedTotal = maxOf(request.inheritedSoulPoints, request.inheritedSoulTotal ?: request.inheritedSoulPoints)
        val inheritance = HighSchoolInheritanceState(
            nextLifeNumber = request.lifeNumber,
            soulPoints = request.inheritedSoulPoints.coerceAtLeast(0),
            soulTotalEarned = inheritedTotal.coerceAtLeast(0),
            automaticSoulEarned = (request.inheritedSoulTotal ?: request.inheritedSoulPoints).coerceAtLeast(0),
            inheritedMemories = request.inheritedMemories,
            selectedSignatureLegacyId = request.inheritedSignatureLegacyId,
            unlockedSignatureLegacyIds = request.inheritedSignatureLegacyId?.let(::listOf) ?: emptyList(),
            inheritanceRulesVersion = request.inheritanceRulesVersion,
            lineageMasteries = request.inheritedLineageMasteries,
            lineageLoadout = request.lineageLoadout,
        )
        val initialAchievements = HighSchoolAchievementRules.unlock(
            emptyList(),
            emptyList(),
            HighSchoolAchievementRules.updateHighSchool(emptySet(), run, emptyList()),
        )
        val state = sign(
            HighSchoolPhase4State(
                run = run,
                startingPitcher = run.pitcher,
                inheritance = inheritance,
                weekly = weekly,
                achievements = initialAchievements.unlocked,
                unacknowledgedAchievements = initialAchievements.unacknowledged,
                nextRunIntent = request.inheritedNextRunIntent,
                selectedDayKey = request.dayKey,
                tutorial = HighSchoolTutorialState(),
            ),
        )
        return result(state, "phase4_started", listOf("life.${request.lifeNumber}"))
    }

    public fun startConfigured(request: HighSchoolPhase4StartRequest, primaryPitch: PitchKind, learningPitch: PitchKind): HighSchoolPhase4Result {
        val base = start(request).state
        return result(configureStartingRepertoire(base, primaryPitch, learningPitch), "phase4_started", listOf("life.${request.lifeNumber}"))
    }

    private fun configureStartingRepertoire(state: HighSchoolPhase4State, primary: PitchKind, learning: PitchKind): HighSchoolPhase4State {
        require(primary != learning && learning != PitchKind.FOUR_SEAM) { "rebirth.repertoire" }
        val pitcher = state.run.pitcher.copy(pitchProfiles = PitchLearningRules.configure(state.run.pitcher.pitchProfiles, primary, learning))
        return sign(state.copy(run = highSchool.resignShadowState(state.run.copy(pitcher = pitcher, pitchLearningProject = PitchLearningProject(learning))), startingPitcher = pitcher))
    }

    public fun beginTutorial(state: HighSchoolPhase4State): HighSchoolPhase4Result {
        require(state.run.phase == HighSchoolPhase.PROLOGUE) { "tutorial.phase" }
        require(!state.tutorial.completed) { "tutorial.completed" }
        return result(sign(state.copy(tutorial = state.tutorial.copy(started = true))), "tutorial_started")
    }

    public fun completeTutorial(seed: String, state: HighSchoolPhase4State): HighSchoolPhase4Result {
        require(state.tutorial.started && !state.tutorial.completed) { "tutorial.not_started" }
        val next = highSchool.completePrologue(HighSchoolKernel.AdvanceRequest(seed, state.run)).snapshot
        return result(sign(state.copy(run = next, tutorial = HighSchoolTutorialState(true, true))), "tutorial_completed")
    }

    public fun completePrologue(seed: String, state: HighSchoolPhase4State): HighSchoolPhase4Result =
        completeTutorial(seed, if (state.tutorial.started) state else beginTutorial(state).state)

    public fun chooseSchool(seed: String, state: HighSchoolPhase4State, schoolId: HighSchoolSchoolId): HighSchoolPhase4Result {
        val next = highSchool.chooseSchool(HighSchoolKernel.ChooseSchoolRequest(seed, state.run, schoolId)).snapshot
        return result(sign(state.copy(run = next, returnPlan = null)), "school_selected", listOf("school.${schoolId.wire}"))
    }

    public fun selectPledge(state: HighSchoolPhase4State, pledgeId: String): HighSchoolPhase4Result {
        require(!state.challenge.active) { "challenge.pledge_locked" }
        val definition = HighSchoolPledgeRules.definition(pledgeId)
        val options = HighSchoolPledgeRules.options(
            state.weekly.stableUserId, state.weekly.weekKey, state.run.careerId, state.run, state.nextRunIntent?.pledgeId,
        )
        require(options.any { it.id == pledgeId }) { "pledge.not_offered" }
        val next = sign(
            state.copy(
                pledge = HighSchoolPledgeState(definition),
                nextRunIntent = null,
                weekly = HighSchoolWeeklyRules.record(
                    state.weekly,
                    "pledge_selected",
                    receiptId = "${state.run.careerId}:pledge",
                    dayKey = state.selectedDayKey,
                ),
            ),
        )
        return result(next, "pledge_selected", listOf("pledge.$pledgeId"))
    }

    public fun commitTraining(
        seed: String,
        state: HighSchoolPhase4State,
        focus: HighSchoolTrainingFocus,
        intensity: HighSchoolTrainingIntensity,
        targetPitch: PitchKind? = null,
    ): HighSchoolPhase4Result {
        val next = highSchool.commitTraining(HighSchoolKernel.TrainingRequest(seed, state.run, focus, intensity, targetPitch)).snapshot
        val training = next.lastTraining ?: error("training.evidence_missing")
        return result(
            sign(updateProgress(state.copy(
                run = next,
                trainingEvidence = state.trainingEvidence + trainingEvidence(state.run, training, targetPitch),
            ))),
            "training_committed",
            listOf("training.$focus"),
        )
    }

    public fun commitTrainingBlock(
        seed: String,
        state: HighSchoolPhase4State,
        requests: List<Pair<HighSchoolTrainingFocus, HighSchoolTrainingIntensity>>,
        targetPitch: PitchKind? = null,
        stopForSafety: Boolean = false,
    ): HighSchoolPhase4Result {
        require(requests.isNotEmpty() && requests.size <= 16) { "training.block_size" }
        require(targetPitch == null || (targetPitch != PitchKind.FOUR_SEAM && requests.all { it.first == HighSchoolTrainingFocus.BREAKING_BALL } && state.run.pitcher.pitchProfiles.any { it.pitchType == targetPitch })) { "training.block_target" }
        var run = state.run
        val evidence = state.trainingEvidence.toMutableList()
        var nextSeed = seed
        for ((focus, intensity) in requests) {
            val committed = highSchool.commitTraining(HighSchoolKernel.TrainingRequest(nextSeed, run, focus, intensity, targetPitch))
            val training = committed.snapshot.lastTraining ?: error("training.evidence_missing")
            evidence += trainingEvidence(run, training, targetPitch)
            run = committed.snapshot
            nextSeed = committed.nextSeed
            if (run.phase != HighSchoolPhase.TRAINING) break
            if (stopForSafety && (training.bloomed || (focus != HighSchoolTrainingFocus.RECOVERY &&
                    (run.fatigue >= 75 || run.armRisk >= 55 || run.injuryRecovery > 0)))) break
        }
        return result(sign(updateProgress(state.copy(run = run, trainingEvidence = evidence))), "training_block_committed")
    }

    public fun resolveRelationship(
        seed: String,
        state: HighSchoolPhase4State,
        response: HighSchoolRelationshipResponse,
    ): HighSchoolPhase4Result {
        val next = highSchool.resolveRelationship(HighSchoolKernel.RelationshipRequest(seed, state.run, response)).snapshot
        return result(sign(updateProgress(state.copy(run = next))), "relationship_resolved")
    }

    /** Reserves a game before a pitch is emitted; this is the durable authority boundary. */
    public fun reserveImportantGame(seed: String, state: HighSchoolPhase4State): HighSchoolPhase4Result {
        require(state.run.phase == HighSchoolPhase.IMPORTANT_GAME) { "importantGame.phase" }
        require(state.activePitch == null) { "importantGame.already_reserved" }
        val gameNumber = state.run.performance.importantGamesCompleted + 1
        val originalScenario = state.run.currentGameScenario
            ?: (HighSchoolContentCatalog.scenarios + HighSchoolContentCatalog.regularScenarios).firstOrNull { it.id == state.run.currentGameScenarioId }
            ?: error("importantGame.scenario_missing")
        val trial = state.run.development?.starterTrialPending == true
        val earnedStart = state.run.development?.trialOutcome == "achieved" && originalScenario.leverage < 850
        val scenario = if (trial || earnedStart) originalScenario.copy(
            id = if (trial) "coach-starter-trial" else "earned-starter-appearance", title = if (trial) "선발 테스트" else "선발 등판",
            inning = 1, outs = 0, firstOccupied = false, secondOccupied = false, thirdOccupied = false, scoreDifferential = 0,
            narrative = if (trial) "감독과 약속한 선발 테스트. 직접 두 이닝을 2실점 이하로 막아 보세요." else "지난 등판에서 얻은 선발 기회예요.") else originalScenario
        val role = if (trial || earnedStart || state.run.chapterGameClaimed) com.solkim.baseball.core.pitch.OutingRole.STARTER
            else if (scenario.inning >= 9 && (scenario.scoreDifferential ?: 0) > 0) com.solkim.baseball.core.pitch.OutingRole.CLOSER else com.solkim.baseball.core.pitch.OutingRole.RELIEF
        val pitcher = state.run.toPitcherSnapshot()
        val batter = state.currentBatter()
        val scouting = state.currentScouting()
        val context = HighSchoolPitchContext(
            plateAppearanceId = "${state.run.careerId}:game:$gameNumber:pa:1:outing-v2",
            revision = 0UL,
            inning = if (state.run.chapterGameClaimed) 1 else scenario.inning,
            outs = if (state.run.chapterGameClaimed) 0 else scenario.outs,
            balls = 0,
            strikes = 0,
            pitchNumber = 1,
            scoreDifferential = if (state.run.chapterGameClaimed) 0 else scenario.scoreDifferential ?: 0,
            leverage = scenario.leverage,
            fatigue = state.run.fatigue.coerceIn(0, 100),
        )
        val initialMemory = HighSchoolPitchMemory()
        val initialGame = HighSchoolPitchGame(
            inning = if (state.run.chapterGameClaimed) 1 else scenario.inning,
            outs = if (state.run.chapterGameClaimed) 0 else scenario.outs,
            firstOccupied = !state.run.chapterGameClaimed && scenario.firstOccupied,
            secondOccupied = !state.run.chapterGameClaimed && scenario.secondOccupied,
            thirdOccupied = !state.run.chapterGameClaimed && scenario.thirdOccupied,
        )
        val initialLog = HighSchoolPitchLog("${state.run.careerId}:game:$gameNumber")
        val preparation = pitch.prepare(
            PitchKernel.PrepareRequest(
                seed = seed,
                pitcher = pitcher,
                batter = batter,
                scouting = scouting,
                context = context.toPitchContext(),
                rivalMemory = initialMemory.toRivalMemory(pitcher.id, batter.id),
                gameState = initialGame.toGameState(),
                gameLog = initialLog.toGameLog(),
            ),
        )
        val session = HighSchoolPitchSession(
            sessionId = "${state.run.careerId}:important:$gameNumber:outing-v2",
            gameNumber = gameNumber,
            seed = seed,
            pitchIndex = 0,
            preparationToken = preparation.preparationToken,
            context = context,
            memory = initialMemory,
            game = initialGame,
            log = initialLog,
            assignment = com.solkim.baseball.core.pitch.OutingAssignment(role,
                if (trial) com.solkim.baseball.core.pitch.OutingGoal.STARTER_TEST else if (role == com.solkim.baseball.core.pitch.OutingRole.CLOSER) com.solkim.baseball.core.pitch.OutingGoal.HOLD_LEAD else com.solkim.baseball.core.pitch.OutingGoal.CLEAN_FRAME,
                if (trial) 6 else 3 - context.outs,
                if (trial) 2 else if (role == com.solkim.baseball.core.pitch.OutingRole.CLOSER) maxOf(0, context.scoreDifferential - 1) else 0,
                context.inning, context.outs, context.scoreDifferential,
                listOf(initialGame.firstOccupied, initialGame.secondOccupied, initialGame.thirdOccupied).count { it }),
        )
        return result(
            sign(state.copy(run = highSchool.resignShadowState(state.run.copy(currentGameScenario = scenario, currentGameScenarioId = scenario.id,
                development = state.run.development?.copy(starterTrialPending = false))), activePitch = session, lastPresentation = null)),
            "important_game_reserved",
            listOf("game.$gameNumber"),
            preparation,
        )
    }

    /**
     * Submits one player call to the Kotlin PitchKernel. The returned trajectory is the only
     * data suitable for Unity presentation; this method never delegates result generation.
     *
     * Tutorial pitches use the same call+delivery path but do not open an important-game session
     * and do not count toward official records.
     */
    public fun submitPitch(
        state: HighSchoolPhase4State,
        sessionId: String,
        call: PitchCall,
        delivery: PitchDelivery = PitchDelivery.NEUTRAL,
    ): HighSchoolPhase4Result {
        if (state.activePitch == null) return submitTutorialPitch(state, sessionId, call, delivery)
        val pitch = if (state.run.balanceVersion >= 7) PitchKernel(schoolBalance = true) else this.pitch
        val session = state.activePitch
        require(session.sessionId == sessionId) { "pitch.session_stale" }
        require(!session.ended) { "pitch.ended" }
        val pitcher = state.run.toPitcherSnapshot()
        val batter = state.currentBatter()
        val scouting = scoutingForSession(state)
        val submitParameters = PitchKernel.SubmitRequest(
            seed = session.seed,
            pitcher = pitcher,
            batter = batter,
            scouting = scouting,
            context = session.context.toPitchContext(),
            preparationToken = session.preparationToken,
            call = call,
            rivalMemory = session.memory.toRivalMemory(pitcher.id, batter.id),
            gameState = session.game.toGameState(),
            gameLog = session.log.toGameLog(),
        )
        // The preparation read is also the source evaluator's pre-pitch rival view. It is
        // validated against the durable token by the authoritative submit.
        val preparation = pitch.prepare(
            PitchKernel.PrepareRequest(
                seed = session.seed,
                pitcher = pitcher,
                batter = batter,
                scouting = scouting,
                context = session.context.toPitchContext(),
                rivalMemory = session.memory.toRivalMemory(pitcher.id, batter.id),
                gameState = session.game.toGameState(),
                gameLog = session.log.toGameLog(),
            ),
        )
        // Authoritative submit validates current or exact legacy preparation against this state.
        val result = pitch.submit(
            submitParameters,
            delivery,
        )
        val entry = result.gameLog.entries.lastOrNull()
        val snapshot = result.snapshot
        val sequencePitch = PitchSequencePitch(
            pitchType = call.pitchType,
            zone = call.zone,
            intent = call.zoneIntent,
            expectedVelocityKph = PitchAbilityRules.expectedVelocity(pitcher, call, session.context.fatigue, session.sessionId.endsWith(":outing-v2")) / 10,
            outcome = snapshot.outcome,
        )
        val sequenceMoment = PitchSequenceEvaluator.evaluate(
            recent = session.sequencePitches,
            context = session.context.toPitchContext(),
            current = sequencePitch,
            rivalAdaptation = preparation.rivalAdaptation,
        )
        val nextSequencePitches = if (snapshot.ended) emptyList() else (session.sequencePitches + sequencePitch).takeLast(3)
        val wholeInning = session.sessionId.endsWith(":outing-v2")
        val outingEnded = if (wholeInning) snapshot.inningTransition.inningEnded ||
            (snapshot.ended && session.pitches + 1 >= 60) else snapshot.ended
        val nextContext = snapshot.toNextContext(session.context, result.gameState).let {
            if (wholeInning) it.copy(
                plateAppearanceId = if (snapshot.ended) "${session.sessionId}:batter:${(session.context.plateAppearanceId.substringAfterLast(":batter:").toIntOrNull() ?: 1) + 1}" else it.plateAppearanceId,
                scoreDifferential = session.context.scoreDifferential - snapshot.runsScored,
            ) else it
        }
        val nextMemory = result.rivalMemory.toPhase4Memory()
        val nextGame = result.gameState.toPhase4Game()
        val nextLog = result.gameLog.toPhase4Log()
        var nextSession = session.copy(
            seed = result.nextSeed,
            pitchIndex = session.pitchIndex + 1,
            preparationToken = result.nextPreparation?.preparationToken ?: "",
            context = nextContext,
            memory = nextMemory,
            game = nextGame,
            log = nextLog,
            pitches = session.pitches + 1,
            strikeouts = session.strikeouts + if (snapshot.result == com.solkim.baseball.core.pitch.PlateAppearanceResult.STRIKEOUT) 1 else 0,
            walks = session.walks + if (snapshot.result == com.solkim.baseball.core.pitch.PlateAppearanceResult.WALK) 1 else 0,
            runsAllowed = session.runsAllowed + snapshot.runsScored,
            expectedDamage = session.expectedDamage + (entry?.expectedDamage ?: 0),
            actualDamage = session.actualDamage + (entry?.actualDamage ?: 0),
            recommendationAccepted = session.recommendationAccepted + if (snapshot.recommendationAccepted) 1 else 0,
            outs = session.outs + snapshot.inningTransition.outsRecorded,
            hits = session.hits + if (snapshot.outcome in setOf(PitchOutcome.SINGLE, PitchOutcome.DOUBLE, PitchOutcome.TRIPLE, PitchOutcome.HOME_RUN)) 1 else 0,
            abilityMoments = result.abilityMoment?.wire?.let { session.abilityMoments + it } ?: session.abilityMoments,
            ended = outingEnded,
            assignment = session.assignment?.advance(session.outs + snapshot.inningTransition.outsRecorded, session.runsAllowed + snapshot.runsScored),
            sequenceMasteryCount = session.sequenceMasteryCount + if (sequenceMoment != null) 1 else 0,
            sequencePitches = nextSequencePitches,
            perfectReleases = session.perfectReleases + if (delivery.isPerfectRelease) 1 else 0,
        )
        val following = if (!outingEnded && snapshot.ended) {
            val pending = state.copy(activePitch = nextSession)
            val nextBatter = pending.currentBatter()
            pitch.prepare(PitchKernel.PrepareRequest(nextSession.seed, pitcher, nextBatter,
                pending.currentScouting(), nextSession.context.toPitchContext(),
                nextSession.memory.toRivalMemory(pitcher.id, nextBatter.id), nextSession.game.toGameState(), nextSession.log.toGameLog()))
        } else result.nextPreparation
        nextSession = nextSession.copy(preparationToken = following?.preparationToken ?: "")
        val completedGoal = nextSession.assignment?.status == com.solkim.baseball.core.pitch.OutingGoalStatus.ACHIEVED &&
            session.assignment?.status != com.solkim.baseball.core.pitch.OutingGoalStatus.ACHIEVED
        if (completedGoal) nextSession = nextSession.copy(assignment = nextSession.assignment!!.withTrustReward(state.run.managerTrust))
        val goalReward = if (completedGoal) nextSession.assignment!!.trustReward else 0
        val passedTrial = completedGoal && nextSession.assignment?.goal == com.solkim.baseball.core.pitch.OutingGoal.STARTER_TEST
        val deliveryAchievements = HighSchoolAchievementRules.updateDelivery(
            state.achievements.toSet(), delivery.releaseAccuracy, delivery.aimAccuracy,
        )
        val achievementProgress = HighSchoolAchievementRules.unlock(
            state.achievements,
            state.unacknowledgedAchievements,
            deliveryAchievements,
        )
        val next = sign(
            state.copy(
                run = highSchool.resignShadowState(state.run.copy(
                    pitchLearningProject = state.run.pitchLearningProject?.use(call.pitchType, session.context.plateAppearanceId, delivery, entry?.executionQuality ?: 0),
                    managerTrust = (state.run.managerTrust + goalReward).coerceAtMost(100),
                    relationshipTrust = if (goalReward > 0) ((state.run.managerTrust + goalReward).coerceAtMost(100) + state.run.catcherTrust + state.run.rivalTrust) / 3 else state.run.relationshipTrust,
                    development = if (passedTrial) (state.run.development ?: HighSchoolDevelopment()).copy(trialOutcome = "achieved") else state.run.development)),
                activePitch = nextSession,
                achievements = achievementProgress.unlocked,
                unacknowledgedAchievements = achievementProgress.unacknowledged,
                lastPresentation = presentationFrom(snapshot),
            ),
        )
        return result(next, "pitch_submitted", snapshot.reasonCodes, following, next.lastPresentation)
    }

    /**
     * One practice pitch during the prologue. Slider timing and the chosen zone go through
     * [PitchKernel.submit] exactly like an official pitch. The outcome is stored on
     * [HighSchoolPhase4State.lastPresentation] so the mound screen can show strike/ball.
     * Career totals, important-game receipts, and [activePitch] stay untouched.
     */
    public fun submitTutorialPitch(
        state: HighSchoolPhase4State,
        sessionId: String,
        call: PitchCall,
        delivery: PitchDelivery = PitchDelivery.NEUTRAL,
    ): HighSchoolPhase4Result {
        require(sessionId.isNotBlank() && sessionId.length <= 128) { "tutorial.session" }
        require(state.run.phase == HighSchoolPhase.PROLOGUE) { "tutorial.phase" }
        require(state.tutorial.started && !state.tutorial.completed) { "tutorial.lifecycle" }
        require(state.activePitch == null) { "tutorial.active_pitch" }
        val pitcher = state.run.toPitcherSnapshot()
        val preparation = prepareTutorial(state, sessionId)
        val pitchNumber = (state.lastPresentation?.pitchNumber ?: 0) + 1
        val seed = StableHash.fnv1a64Value("tutorial|${state.run.careerId}|$sessionId|$pitchNumber").toString()
        val context = PlateAppearanceContext(
            plateAppearanceId = "$sessionId:pa:$pitchNumber",
            revision = 0UL,
            inning = 1,
            outs = 0,
            balls = 0,
            strikes = 0,
            pitchNumber = 1,
            scoreDifferential = 0,
            leverage = 200,
            fatigue = 0,
        )
        val kernelResult = pitch.submit(
            PitchKernel.SubmitRequest(
                seed = seed,
                pitcher = pitcher,
                batter = HighSchoolTutorialMound.BATTER,
                scouting = HighSchoolTutorialMound.SCOUTING,
                context = context,
                preparationToken = preparation.preparationToken,
                call = call,
            ),
            delivery,
        )
        val snapshot = kernelResult.snapshot
        val next = sign(
            state.copy(
                lastPresentation = presentationFrom(snapshot).copy(pitchNumber = pitchNumber),
            ),
        )
        return result(next, "tutorial_pitch_submitted", snapshot.reasonCodes, kernelResult.nextPreparation, next.lastPresentation)
    }

    public fun prepareTutorial(state: HighSchoolPhase4State, sessionId: String): PitchPreparation {
        require(sessionId.isNotBlank() && sessionId.length <= 128) { "tutorial.session" }
        require(state.run.phase == HighSchoolPhase.PROLOGUE) { "tutorial.phase" }
        require(state.tutorial.started && !state.tutorial.completed) { "tutorial.lifecycle" }
        val pitcher = state.run.toPitcherSnapshot()
        val pitchNumber = (state.lastPresentation?.pitchNumber ?: 0) + 1
        val seed = StableHash.fnv1a64Value("tutorial|${state.run.careerId}|$sessionId|$pitchNumber").toString()
        val context = PlateAppearanceContext(
            plateAppearanceId = "$sessionId:pa:$pitchNumber",
            revision = 0UL,
            inning = 1,
            outs = 0,
            balls = 0,
            strikes = 0,
            pitchNumber = 1,
            scoreDifferential = 0,
            leverage = 200,
            fatigue = 0,
        )
        return pitch.prepare(
            PitchKernel.PrepareRequest(
                seed,
                pitcher,
                HighSchoolTutorialMound.BATTER,
                HighSchoolTutorialMound.SCOUTING,
                context,
            ),
        )
    }

    private fun scoutingForSession(state: HighSchoolPhase4State): com.solkim.baseball.core.pitch.BatterScoutingSnapshot {
        val session = state.activePitch ?: return state.run.toScoutingSnapshot()
        val pitcher = state.run.toPitcherSnapshot()
        val batter = state.currentBatter()
        val current = state.currentScouting()
        fun matches(scouting: com.solkim.baseball.core.pitch.BatterScoutingSnapshot): Boolean = pitch.matchesPreparation(
            PitchKernel.PrepareRequest(session.seed, pitcher, batter, scouting, session.context.toPitchContext(),
                session.memory.toRivalMemory(pitcher.id, batter.id), session.game.toGameState(), session.log.toGameLog()),
            session.preparationToken,
        )
        if (matches(current)) return current
        val legacy = state.run.legacyScoutingSnapshot()
        require(matches(legacy)) { "pitch.preparation_stale" }
        return legacy
    }

    public fun prepareActivePitch(state: HighSchoolPhase4State): PitchPreparation {
        val session = state.activePitch ?: error("pitch.no_session")
        val pitcher = state.run.toPitcherSnapshot()
        val batter = state.currentBatter()
        val scouting = scoutingForSession(state)
        return pitch.prepare(
            PitchKernel.PrepareRequest(
                seed = session.seed,
                pitcher = pitcher,
                batter = batter,
                scouting = scouting,
                context = session.context.toPitchContext(),
                rivalMemory = session.memory.toRivalMemory(pitcher.id, batter.id),
                gameState = session.game.toGameState(),
                gameLog = session.log.toGameLog(),
            ),
        )
    }

    public fun continueOuting(state: HighSchoolPhase4State): HighSchoolPhase4Result {
        val session = requireNotNull(state.activePitch)
        require(session.sessionId.endsWith(":outing-v2") && session.ended && (state.run.chapterGameClaimed || session.assignment?.role == com.solkim.baseball.core.pitch.OutingRole.STARTER) &&
            session.game.outs == 0 && session.outs < 18 && session.pitches < 80 && session.context.inning < 9 && session.context.fatigue < 90) { "outing.continue_unavailable" }
        val resumed = session.copy(ended = false,
            context = session.context.copy(inning = session.context.inning + 1, outs = 0, balls = 0, strikes = 0, pitchNumber = 1),
            game = session.game.copy(inning = session.context.inning + 1, outs = 0, firstOccupied = false, secondOccupied = false, thirdOccupied = false))
        val pending = state.copy(activePitch = resumed)
        val pitcher = state.run.toPitcherSnapshot()
        val batter = pending.currentBatter()
        val preparation = pitch.prepare(PitchKernel.PrepareRequest(resumed.seed, pitcher, batter, pending.currentScouting(),
            resumed.context.toPitchContext(), resumed.memory.toRivalMemory(pitcher.id, batter.id), resumed.game.toGameState(), resumed.log.toGameLog()))
        return result(sign(pending.copy(activePitch = resumed.copy(preparationToken = preparation.preparationToken))), "outing_continued", preparation = preparation)
    }

    public fun finishImportantGame(state: HighSchoolPhase4State): HighSchoolPhase4Result {
        val session = state.activePitch ?: error("importantGame.no_session")
        require(session.ended) { "importantGame.pitch_in_progress" }
        val report = HighSchoolGameReport(
            scenarioNumber = session.gameNumber,
            pitches = session.pitches,
            strikeouts = session.strikeouts,
            walks = session.walks,
            runsAllowed = session.runsAllowed,
            expectedDamage = session.expectedDamage,
            actualDamage = session.actualDamage,
            recommendationAccepted = session.recommendationAccepted,
            outs = session.outs,
            hits = session.hits,
            sequenceMasteryCount = session.sequenceMasteryCount,
            scoreDifferentialAtEntry = if (state.run.chapterGameClaimed) 0 else state.run.currentGameScenario?.scoreDifferential ?: 0,
            homeRuns = session.log.entries.count { it.outcome == PitchOutcome.HOME_RUN },
            perfectReleases = session.perfectReleases,
        )
        var nextRun = highSchool.recordImportantGame(
            HighSchoolKernel.GameRequest(session.seed, highSchool.resignShadowState(state.run.copy(pitcher = state.run.pitchLearningProject?.let { state.run.pitcher.copy(pitchProfiles = PitchLearningRules.advance(state.run.pitcher.pitchProfiles, it, it)) } ?: state.run.pitcher)), report),
        ).snapshot
        val objective = session.assignment?.finish()
        if (objective != null) {
            val trial = objective.goal == com.solkim.baseball.core.pitch.OutingGoal.STARTER_TEST
            val achieved = objective.status == com.solkim.baseball.core.pitch.OutingGoalStatus.ACHIEVED
            val development = nextRun.development ?: HighSchoolDevelopment()
            nextRun = highSchool.resignShadowState(nextRun.copy(
                development = if (trial) development.copy(trialOutcome = if (achieved || development.trialOutcome == "achieved") "achieved" else "unfinished") else development,
                news = (listOf(if (trial && achieved) "선발 테스트 통과. 다음 등판부터 선발 기회가 열렸어요." else if (achieved && objective.trustReward > 0) "등판 목표를 달성했어요. 감독의 신뢰가 올랐어요." else if (achieved) "목표 달성" else "이번 등판을 마쳤어요. 다음 기회를 준비해요.") + nextRun.news).take(30)))
        }
        var line = HighSchoolSeasonLineRules.line(
            session.seed,
            state.run,
            report,
            outingNumber = state.seasonLog.size + 1,
        ).copy(abilityMoments = session.abilityMoments, regular = state.run.chapterGameClaimed, perfectReleases = session.perfectReleases)
        val remainder = if (state.run.chapterGameClaimed && session.sessionId.endsWith(":outing-v2") && !state.challenge.active)
            HighSchoolAutomaticOutingSimulator(schoolBalance = state.run.balanceVersion >= 7).simulateRemainder(state.run, session) else null
        if (remainder != null) nextRun = highSchool.resignShadowState(nextRun.copy(
            automaticOuts = nextRun.automaticOuts + remainder.outs,
            automaticRunsAllowed = nextRun.automaticRunsAllowed + remainder.runsAllowed))
        if (remainder != null) {
            val whole = HighSchoolSeasonLineRules.line(session.seed, state.run,
                report.copy(outs = session.outs + remainder.outs, runsAllowed = session.runsAllowed + remainder.runsAllowed,
                    scoreDifferentialAtEntry = null), line.outingNumber)
            line = line.copy(started = true, teamRuns = whole.teamRuns, opponentRuns = whole.opponentRuns,
                decision = when {
                    whole.teamRuns > whole.opponentRuns && whole.outs >= 15 -> HighSchoolPitchingDecision.WIN
                    whole.teamRuns < whole.opponentRuns && whole.runsAllowed > 0 -> HighSchoolPitchingDecision.LOSS
                    else -> HighSchoolPitchingDecision.NO_DECISION
                })
        }
        val remainderLine = remainder?.let {
            line.copy(pitches = it.pitches, strikeouts = it.strikeouts, walks = it.walks, runsAllowed = it.runsAllowed,
                expectedDamage = 0, actualDamage = 0, abilityMoments = emptyList(), rivalStrikeouts = 0,
                outs = it.outs, played = false, hits = it.hits, homeRuns = it.homeRuns, perfectReleases = 0,
                decision = HighSchoolPitchingDecision.NO_DECISION)
        }
        val nextCounter = if (state.challenge.active) state.completedGameCounter else
            HighSchoolCompletedGameCounterRules.record(state.completedGameCounter)
        val nextReceipts = if (state.challenge.active) state.completedGameReceipts else {
            require(session.sessionId !in state.completedGameReceipts) { "completedGameReceipt.duplicate" }
            state.completedGameReceipts + session.sessionId
        }
        var weekly = state.weekly
        if (!state.challenge.active) {
            weekly = HighSchoolWeeklyRules.record(
                weekly, "important_games_completed", receiptId = "${session.sessionId}:weekly-game", dayKey = state.selectedDayKey,
            )
            weekly = HighSchoolWeeklyRules.record(
                weekly, "played_on_two_days", receiptId = "played-day:${state.selectedDayKey}", dayKey = state.selectedDayKey,
            )
            if (session.sequenceMasteryCount > 0) {
                weekly = HighSchoolWeeklyRules.record(
                    weekly, "sequence_mastery_triggered", session.sequenceMasteryCount,
                    receiptId = "${session.sessionId}:weekly-sequence", dayKey = state.selectedDayKey,
                )
            }
        }
        val nextSeasonLog = if (state.challenge.active) state.seasonLog else state.seasonLog + listOfNotNull(remainderLine) + line
        val reportAchievements = if (state.challenge.active) state.achievements else HighSchoolAchievementRules.updateReport(
            state.achievements.toSet(), report,
        )
        val reportProgress = if (state.challenge.active) {
            HighSchoolAchievementRules.Progress(state.achievements, state.unacknowledgedAchievements)
        } else {
            HighSchoolAchievementRules.unlock(
                state.achievements,
                state.unacknowledgedAchievements,
                reportAchievements,
            )
        }
        val pledge = if (state.challenge.active) state.pledge else pledgeUpdate(state.copy(run = nextRun, seasonLog = nextSeasonLog))
        val tournaments = if (state.challenge.active) state.tournaments else state.tournaments.updateForChapter(nextRun.chapter.number, nextRun.careerId, state.archive.isEmpty())
        val board = if (state.challenge.active) state.prospectBoard else HighSchoolProspectRankingRules.board(nextRun)
        val returnPlan = if (state.challenge.active) state.returnPlan else HighSchoolReturnPlan(
            destination = HighSchoolReturnDestination.HIGH_SCHOOL,
            reason = "important_game_completed",
            createdDayKey = state.selectedDayKey,
            receiptId = Hashing.fnv1a64Hex("return|${state.run.careerId}|game|${session.gameNumber}"),
            route = HighSchoolReturnPlanRules.route(HighSchoolReturnDestination.HIGH_SCHOOL),
            title = HighSchoolReturnPlanRules.continueTitle(HighSchoolReturnDestination.HIGH_SCHOOL),
            body = "다음 경기를 이어서 준비하세요.",
        )
        val progressed = state.copy(
            run = nextRun,
            weekly = weekly,
            pledge = pledge,
            seasonLog = nextSeasonLog,
            activePitch = null,
            completedGameCounter = nextCounter,
            completedGameReceipts = nextReceipts,
            achievements = reportProgress.unlocked,
            unacknowledgedAchievements = reportProgress.unacknowledged,
            prospectBoard = board,
            tournaments = tournaments,
            returnPlan = returnPlan,
        )
        val next = sign(
            if (state.challenge.active) progressed else updateProgress(progressed),
        )
        return result(next, "important_game_completed", listOf("game.${session.gameNumber}"))
    }

    public fun chooseAwakening(seed: String, state: HighSchoolPhase4State, awakening: HighSchoolAwakening): HighSchoolPhase4Result {
        val next = highSchool.chooseAwakening(HighSchoolKernel.AwakeningRequest(seed, state.run, awakening)).snapshot
        return result(sign(updateProgress(state.copy(run = next))), "awakening_selected", listOf("awakening.${awakening.wire}"))
    }

    public fun claimChapterGame(seed: String, state: HighSchoolPhase4State): HighSchoolPhase4Result {
        require(state.activePitch == null) { "chapterGame.pitch_in_progress" }
        val next = highSchool.claimChapterGame(HighSchoolKernel.AdvanceRequest(seed, state.run)).snapshot
        return result(sign(updateProgress(state.copy(run = next))), "chapter_game_claimed")
    }

    private fun automaticChapterLog(seed: String, state: HighSchoolPhase4State): List<HighSchoolSeasonLine> {
        // Store the exact automatic lines used by the aggregate, with explicit provenance.
        // Old saves retain their known aggregate without inventing missing hit/strikeout data.
        val simulated = HighSchoolAutomaticOutingSimulator(schoolBalance = highSchool.gameplayRulesVersion >= 7).simulate(state.run, state.run.chapter, seed.toULong())
            .let { if (state.run.chapterGameClaimed) it.drop(1) else it }
        return simulated.mapIndexed { index, line ->
            HighSchoolSeasonLine(state.run.careerId, state.run.lifeNumber, state.run.chapter.number,
                10_000 + state.run.chapter.number * 10 + index, line.pitches, line.strikeouts, line.walks,
                line.runsAllowed, 0, 0, emptyList(), season = state.run.chapter.schoolYear,
                week = state.run.chapter.number, outingNumber = state.seasonLog.size + index + 1,
                started = true, outs = line.outs, teamRuns = line.teamRuns, opponentRuns = line.opponentRuns,
                decision = when {
                    line.teamRuns > line.opponentRuns && line.outs >= 15 -> HighSchoolPitchingDecision.WIN
                    line.teamRuns < line.opponentRuns && line.runsAllowed > 0 -> HighSchoolPitchingDecision.LOSS
                    else -> HighSchoolPitchingDecision.NO_DECISION
                }, played = false, hits = line.hits, homeRuns = line.homeRuns, regular = true)
        }
    }

    public fun advanceChapter(seed: String, state: HighSchoolPhase4State): HighSchoolPhase4Result {
        val next = highSchool.advanceChapter(HighSchoolKernel.AdvanceRequest(seed, state.run)).snapshot
        val automaticLog = automaticChapterLog(seed, state)
        val weekly = if (state.challenge.active) state.weekly else HighSchoolWeeklyRules.record(
            state.weekly,
            "chapters_advanced",
            receiptId = "${state.run.careerId}:chapter:${next.chapter.number}",
            dayKey = state.selectedDayKey,
        )
        val tournament = HighSchoolTournamentRules.snapshot(
            next.careerId,
            next.chapter.number,
            next.school?.name ?: next.identity.region,
        )
        val tournaments = if (state.challenge.active || tournament == null) state.tournaments else state.tournaments + tournament
        return result(sign(updateProgress(state.copy(run = next, weekly = weekly, tournaments = tournaments,
            seasonLog = if (state.challenge.active) state.seasonLog else state.seasonLog + automaticLog))), "chapter_advanced", listOf("chapter.${next.chapter.number}"))
    }

    public fun resolveDraft(seed: String, state: HighSchoolPhase4State): HighSchoolPhase4Result {
        val automaticLog = if (state.challenge.active) emptyList() else automaticChapterLog(seed, state)
        val next = highSchool.resolveDraft(HighSchoolKernel.AdvanceRequest(seed, state.run)).snapshot
        val pledge = if (state.challenge.active) state.pledge else pledgeUpdate(state.copy(run = next))
        val unlocked = if (state.challenge.active) state.achievements else HighSchoolAchievementRules.updateHighSchool(state.achievements.toSet(), next, state.archive)
        val achievementProgress = if (state.challenge.active) {
            HighSchoolAchievementRules.Progress(state.achievements, state.unacknowledgedAchievements)
        } else {
            HighSchoolAchievementRules.unlock(state.achievements, state.unacknowledgedAchievements, unlocked)
        }
        return result(sign(updateProgress(state.copy(
            run = next,
            seasonLog = state.seasonLog + automaticLog,
            pledge = pledge,
            achievements = achievementProgress.unlocked,
            unacknowledgedAchievements = achievementProgress.unacknowledged,
        ))), "draft_resolved")
    }

    public fun prepareLegacy(state: HighSchoolPhase4State): HighSchoolPhase4Result {
        var run = state.run
        if (run.phase == HighSchoolPhase.COMPLETED) {
            require(run.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED) { "legacy.drafted_required" }
            run = highSchool.openLegacy(HighSchoolKernel.AdvanceRequest("0", run)).snapshot
        }
        require(run.phase == HighSchoolPhase.LEGACY) { "legacy.phase" }
        // The current Swift/C# application caller uses CareerSignatureLegacy.candidates' v1
        // default (three candidates). `memorySlots` belongs to the separate additive memory-card
        // selection and must not silently change the signature-legacy contract.
        val candidateCount = 3
        val candidateIds = HighSchoolSignatureLegacyRules.candidates(state.startingPitcher, run, candidateCount).map { it.definition.id }
        run = highSchool.resignShadowState(run.copy(legacyOptions = candidateIds))
        return result(sign(state.copy(run = run)), "legacy_candidates_prepared", candidateIds.map { "signature.$it" })
    }

    public fun selectLegacy(state: HighSchoolPhase4State, legacyId: String): HighSchoolPhase4Result {
        require(legacyId in state.run.legacyOptions) { "legacy.signature_unknown" }
        val selected = highSchool.selectLegacy(
            HighSchoolKernel.LegacyRequest("0", state.run, signatureLegacyId = legacyId),
        ).snapshot
        return result(sign(state.copy(run = selected, selectedSignatureLegacyId = legacyId)), "legacy_selected", listOf("signature.$legacyId"))
    }

    public fun finalizeArchive(state: HighSchoolPhase4State): HighSchoolPhase4Result {
        require(!state.challenge.active) { "archive.challenge_locked" }
        require(state.run.phase == HighSchoolPhase.COMPLETED) { "archive.phase" }
        require(state.selectedSignatureLegacyId != null) { "archive.legacy_required" }
        require(state.archive.none { it.careerId == state.run.careerId }) { "archive.already_finalized" }
        val draft = state.run.draftResult ?: error("archive.draft_required")
        val pledge = pledgeUpdate(state)
        val reward = state.run.legacyRewardPermille + (if (pledge?.achieved == true) pledge.definition.tier.rewardPermille else 0)
        val earned = inheritanceReward(state.run, reward)
        val archive = HighSchoolArchiveRecord(
            careerId = state.run.careerId,
            lifeNumber = state.run.lifeNumber,
            playerName = state.run.identity.name,
            schoolId = state.run.school?.id?.wire,
            schoolName = state.run.school?.name,
            drafted = draft.outcome == HighSchoolDraftOutcome.DRAFTED,
            draftEvaluation = draft.evaluationScore,
            teamId = draft.teamId,
            ratings = listOf(state.run.pitcher.stuff, state.run.pitcher.command, state.run.pitcher.movement, state.run.pitcher.stamina),
            importantGames = state.run.performance.importantGamesCompleted,
            pitches = state.run.performance.pitches,
            strikeouts = state.run.performance.strikeouts,
            walks = state.run.performance.walks,
            runsAllowed = state.run.performance.runsAllowed,
            perfectReleases = state.run.performance.perfectReleases,
            selectedAwakenings = state.run.selectedAwakenings.map { it.wire },
            selectedSignatureLegacyId = state.selectedSignatureLegacyId,
            pledgeId = pledge?.definition?.id,
            pledgeAchieved = pledge?.achieved == true,
            soulEarned = earned,
            completedGameCounterAtArchive = state.completedGameCounter,
        )
        val nextInheritance = HighSchoolInheritanceState(
            nextLifeNumber = state.run.lifeNumber + 1,
            soulPoints = (state.inheritance.soulPoints + earned).coerceAtLeast(state.inheritance.soulPoints),
            soulTotalEarned = state.inheritance.soulTotalEarned + earned,
            automaticSoulEarned = state.inheritance.automaticSoulEarned + earned,
            inheritedMemories = state.run.selectedMemories,
            selectedSignatureLegacyId = state.selectedSignatureLegacyId,
            unlockedSignatureLegacyIds = (state.inheritance.unlockedSignatureLegacyIds + state.selectedSignatureLegacyId).distinct(),
            lineageMasteries = HighSchoolLineageRules.masteries(
                (state.archive.mapNotNull { it.selectedSignatureLegacyId } + state.selectedSignatureLegacyId),
            ),
            lineageLoadout = HighSchoolLineageRules.loadout(
                legacyId = state.selectedSignatureLegacyId,
                selectedLegacyIds = (state.archive.mapNotNull { it.selectedSignatureLegacyId } + state.selectedSignatureLegacyId),
                sourceLifeNumber = state.run.lifeNumber,
            ),
        )
        val nextRunIntent = nextRunIntentFor(state, pledge)
        val achievementProgress = HighSchoolAchievementRules.unlock(
            state.achievements,
            state.unacknowledgedAchievements,
            HighSchoolAchievementRules.updateHighSchool(state.achievements.toSet(), state.run, state.archive + archive),
        )
        val returnPlan = HighSchoolReturnPlan(
            destination = HighSchoolReturnDestination.HIGH_SCHOOL,
            reason = "archive_finalized",
            createdDayKey = state.selectedDayKey,
            receiptId = Hashing.fnv1a64Hex("return|${state.run.careerId}|archive"),
            route = HighSchoolReturnPlanRules.route(HighSchoolReturnDestination.HIGH_SCHOOL),
            title = "이 선수의 기록이 남았습니다",
            body = "지난 선수의 유산을 다음 도전에 이어 보세요.",
        )
        val next = sign(
            state.copy(
                archive = state.archive + archive,
                inheritance = nextInheritance,
                pledge = pledge,
                nextRunIntent = nextRunIntent,
                achievements = achievementProgress.unlocked,
                unacknowledgedAchievements = achievementProgress.unacknowledged,
                returnPlan = returnPlan,
            ),
        )
        return result(next, "archive_finalized", listOf("life.${state.run.lifeNumber}"))
    }

    public fun beginRebirth(state: HighSchoolPhase4State, seed: String, dayKey: String = state.selectedDayKey, setup: HighSchoolRebirthSetup? = null): HighSchoolPhase4Result {
        require(state.run.phase == HighSchoolPhase.COMPLETED) { "rebirth.phase" }
        require(state.archive.any { it.careerId == state.run.careerId }) { "rebirth.archive_required" }
        val inheritance = HighSchoolLineageRules.recovered(state.inheritance, state.archive)
        val boosts = setup?.soulBoosts.orEmpty()
        require(boosts.distinct().size == boosts.size) { "rebirth.boost_duplicate" }
        val cost = boosts.sumOf { it.cost }
        require(cost <= inheritance.soulPoints) { "rebirth.insufficient_soul" }
        setup?.let {
            require(it.primaryPitch != it.learningPitch && it.learningPitch != PitchKind.FOUR_SEAM) { "rebirth.repertoire" }
        }
        val echo = HighSchoolRebirthEcho(
            previousLifeNumber = state.run.lifeNumber,
            previousPlayerName = state.run.identity.name,
            previousSchoolName = state.run.school?.name,
            previousCareerId = state.run.careerId,
            inheritedMemoryCount = inheritance.inheritedMemories.size,
            inheritedSignatureLegacyId = inheritance.selectedSignatureLegacyId,
            previousArmWarning = state.run.armRisk >= HighSchoolContentCatalog.ARM_WARNING_THRESHOLD,
            previousUndrafted = state.run.draftResult?.outcome == HighSchoolDraftOutcome.UNDRAFTED,
            recentEventIds = state.run.recentRelationshipEventIds.takeLast(3),
            previousCoachName = state.run.school?.coachName,
            previousRivalName = state.run.rival.name,
            inheritedLegacyId = inheritance.selectedSignatureLegacyId,
            automaticInheritanceTotal = inheritance.automaticSoulEarned,
            hadRunsAllowed = state.run.performance.runsAllowed > 0,
            hadCollapseGame = state.run.performance.runsAllowed > 0,
        )
        val request = HighSchoolPhase4StartRequest(
            seed = seed,
            presetId = setup?.presetId ?: state.run.presetId,
            stableUserId = state.weekly.stableUserId,
            weekKey = state.weekly.weekKey,
            dayKey = dayKey,
            lifeNumber = inheritance.nextLifeNumber,
            creationAllocation = HighSchoolAllocation(),
            inheritedSoulPoints = inheritance.soulPoints - cost,
            inheritedSoulDomain = setup?.soulDomain,
            inheritedSoulTotal = inheritance.automaticSoulEarned,
            inheritedMemories = inheritance.inheritedMemories,
            inheritedSignatureLegacyId = inheritance.selectedSignatureLegacyId,
            inheritedLineageMasteries = inheritance.lineageMasteries,
            lineageLoadout = inheritance.lineageLoadout,
            inheritanceRulesVersion = inheritance.inheritanceRulesVersion,
            inheritedNextRunIntent = state.nextRunIntent,
            identity = setup?.identity ?: state.run.identity,
            difficulty = setup?.difficulty ?: state.run.difficulty,
            karmas = setup?.karmas ?: state.run.karmas,
            soulBoosts = boosts,
            inheritedRebirthEcho = echo,
        )
        val initial = start(request).state
        val fresh = if (setup != null) configureStartingRepertoire(initial, setup.primaryPitch, setup.learningPitch)
            else state.run.pitchLearningProject?.let { project -> configureStartingRepertoire(initial,
                state.startingPitcher.pitchProfiles.firstOrNull { it.role == com.solkim.baseball.core.pitch.PitchUsageRole.PRIMARY }?.pitchType ?: PitchKind.FOUR_SEAM, project.pitchType) } ?: initial
        val weekly = HighSchoolWeeklyRules.record(
            state.weekly,
            "next_run_started",
            receiptId = "${state.run.careerId}:next-run:${fresh.run.careerId}",
            dayKey = dayKey,
        )
        val next = sign(
            fresh.copy(
                archive = state.archive,
                achievements = state.achievements,
                unacknowledgedAchievements = state.unacknowledgedAchievements,
                weekly = weekly,
                inheritance = inheritance.copy(soulPoints = inheritance.soulPoints - cost),
                nextRunIntent = state.nextRunIntent,
            rebirthEcho = echo,
                seasonLog = state.seasonLog,
                tournaments = state.tournaments,
                prospectBoard = emptyList(),
                completedGameCounter = state.completedGameCounter,
                completedGameReceipts = state.completedGameReceipts,
                selectedDayKey = dayKey,
                returnPlan = null,
                revision = state.revision,
            ),
        )
        return result(next, "rebirth_started", listOf("life.${next.run.lifeNumber}"))
    }

    public fun startChallenge(state: HighSchoolPhase4State, seed: String? = null, life: Int = state.run.lifeNumber, presetId: String = state.run.presetId): HighSchoolPhase4Result {
        require(!state.challenge.active) { "challenge.already_active" }
        if (seed == null) require(state.run.phase == HighSchoolPhase.COMPLETED) { "challenge.phase" }
        else require(seed.toULongOrNull() != null && life in 1..999 && state.activePitch == null) { "challenge.seed_or_boundary" }
            val backup = HighSchoolChallengeBackup(
            run = state.run,
            startingPitcher = state.startingPitcher,
            inheritance = state.inheritance,
            archive = state.archive,
            achievements = state.achievements,
            weekly = state.weekly,
            pledge = state.pledge,
            nextRunIntent = state.nextRunIntent,
            selectedSignatureLegacyId = state.selectedSignatureLegacyId,
            returnPlan = state.returnPlan,
            rebirthEcho = state.rebirthEcho,
            seasonLog = state.seasonLog,
            tournaments = state.tournaments,
            prospectBoard = state.prospectBoard,
            completedGameCounter = state.completedGameCounter,
            completedGameReceipts = state.completedGameReceipts,
            selectedDayKey = state.selectedDayKey,
            tutorial = state.tutorial,
            commandReceipts = state.commandReceipts,
            revision = state.revision,
                lastPresentation = state.lastPresentation,
                unacknowledgedAchievements = state.unacknowledgedAchievements,
                trainingEvidence = state.trainingEvidence,
        )
        // Challenge is a fresh, un-inherited board. It may read the archived run as its seed
        // source, but it never shares the run object or any mutable projection with the durable
        // career. That is the same isolation boundary as Swift's challengeLifeNumber path.
        val challengeSeed = seed?.toULong()?.toString() ?: Hashing.fnv1a64Hex("challenge|${state.run.careerId}").toULong(16).toString()
        var fresh = start(
            HighSchoolPhase4StartRequest(
                seed = challengeSeed,
                presetId = presetId,
                stableUserId = if (seed == null) state.weekly.stableUserId else "challenge:$challengeSeed-$life",
                weekKey = if (seed == null) state.weekly.weekKey else "1970-W01",
                dayKey = if (seed == null) state.selectedDayKey else "1970-01-01",
                lifeNumber = life,
                identity = if (seed == null) state.run.identity else HighSchoolIdentity(),
                difficulty = if (seed == null) state.run.difficulty else HighSchoolDifficulty(),
                karmas = emptyList(),
                soulBoosts = emptyList(),
                inheritedSoulPoints = 0,
                inheritedMemories = emptyList(),
                inheritedSignatureLegacyId = null,
                inheritanceRulesVersion = null,
                inheritedNextRunIntent = null,
            ),
        ).state
        if (seed != null) fresh = completePrologue(challengeSeed, fresh).state
        return result(
            sign(
                fresh.copy(
                    completedGameCounter = state.completedGameCounter,
                    completedGameReceipts = state.completedGameReceipts,
                    unacknowledgedAchievements = emptyList(),
                    commandReceipts = state.commandReceipts,
                    revision = state.revision,
                    challenge = HighSchoolChallengeState(true, backup),
                ),
            ),
            "challenge_started",
        )
    }

    public fun endChallenge(state: HighSchoolPhase4State): HighSchoolPhase4Result {
        val backup = state.challenge.backup ?: error("challenge.not_active")
        // Challenge commands still need idempotent receipts and a monotonic command revision,
        // even though their gameplay projections are discarded. Keep that command journal from
        // the active envelope store while restoring every gameplay/meta projection from backup.
        val commandReceipts = state.commandReceipts
        val revision = maxOf(state.revision, backup.revision)
        val restored = state.copy(
            run = backup.run,
            startingPitcher = backup.startingPitcher,
            inheritance = backup.inheritance,
            archive = backup.archive,
            achievements = backup.achievements,
            unacknowledgedAchievements = backup.unacknowledgedAchievements,
            weekly = backup.weekly,
            pledge = backup.pledge,
            nextRunIntent = backup.nextRunIntent,
            selectedSignatureLegacyId = backup.selectedSignatureLegacyId,
            returnPlan = backup.returnPlan,
            rebirthEcho = backup.rebirthEcho,
            seasonLog = backup.seasonLog,
            tournaments = backup.tournaments,
            prospectBoard = backup.prospectBoard,
            activePitch = null,
            challenge = HighSchoolChallengeState(),
            completedGameCounter = backup.completedGameCounter,
            completedGameReceipts = backup.completedGameReceipts,
            trainingEvidence = backup.trainingEvidence,
            selectedDayKey = backup.selectedDayKey,
            tutorial = backup.tutorial,
            commandReceipts = commandReceipts,
            revision = revision,
            lastPresentation = backup.lastPresentation,
        )
        return result(sign(restored), "challenge_ended")
    }

    public fun claimWeeklyReward(state: HighSchoolPhase4State): HighSchoolPhase4Result {
        HighSchoolWeeklyRules.rewardRejection(state.weekly, state.challenge.active)?.let { error ->
            throw IllegalArgumentException(error)
        }
        val nextInheritance = state.inheritance.copy(
            soulPoints = state.inheritance.soulPoints + HighSchoolWeeklyRules.REWARD_SOUL_POINTS,
            soulTotalEarned = state.inheritance.soulTotalEarned + HighSchoolWeeklyRules.REWARD_SOUL_POINTS,
            automaticSoulEarned = state.inheritance.automaticSoulEarned + HighSchoolWeeklyRules.REWARD_SOUL_POINTS,
        )
        val next = sign(state.copy(
            inheritance = nextInheritance,
            weekly = HighSchoolWeeklyRules.claim(state.weekly, earnedAtUnixSeconds = 0L),
        ))
        return result(next, "weekly_reward_claimed", listOf("soul.${HighSchoolWeeklyRules.REWARD_SOUL_POINTS}"))
    }

    public fun saveReturnPlan(state: HighSchoolPhase4State, plan: HighSchoolReturnPlan): HighSchoolPhase4Result {
        require(!state.challenge.active) { "return.challenge_locked" }
        require(!HighSchoolReturnPlanRules.isRetiredDailyPlan(plan)) { "daily.retired" }
        require(HighSchoolReturnPlanRules.isValid(plan)) { "return.invalid" }
        return result(sign(state.copy(returnPlan = HighSchoolReturnPlanRules.carryingReceipt(plan, state.returnPlan))), "return_plan_saved")
    }

    /** Freezes the current promise, Seoul day, experiment variant, and durable receipt. */
    public fun prepareReturnPlan(
        state: HighSchoolPhase4State,
        dayKey: String,
        developmentRulesVersion: Int,
    ): HighSchoolPhase4Result {
        require(!state.challenge.active) { "return.challenge_locked" }
        require(HighSchoolReturnPlanRules.isEligible(state.completedGameCounter)) { "return.not_eligible" }
        val current = state.returnPlan ?: error("return_plan.missing")
        val prepared = HighSchoolReturnPlanRules.prepareForNextReturn(
            current,
            state.weekly.stableUserId,
            developmentRulesVersion,
            dayKey,
        )
        return result(sign(state.copy(returnPlan = prepared)), "return_plan_prepared")
    }

    /** Explicitly persists the recap-selected next-life pledge intent. */
    public fun saveNextRunIntent(state: HighSchoolPhase4State, intent: HighSchoolNextRunIntent): HighSchoolPhase4Result {
        require(!state.challenge.active) { "next_intent.challenge_locked" }
        require(state.run.phase == HighSchoolPhase.COMPLETED || state.run.phase == HighSchoolPhase.LEGACY) {
            "next_intent.phase"
        }
        require(intent.sourceLifeNumber == state.run.lifeNumber) { "next_intent.source_life" }
        require(intent.reason.isNotBlank()) { "next_intent.reason" }
        HighSchoolPledgeRules.definition(intent.pledgeId)
        val offered = HighSchoolPledgeRules.options(
            state.weekly.stableUserId,
            state.weekly.weekKey,
            state.run.careerId,
            state.run,
        )
        require(offered.any { it.id == intent.pledgeId }) { "next_intent.not_offered" }
        return result(sign(state.copy(nextRunIntent = intent)), "next_run_intent_saved", listOf("pledge.${intent.pledgeId}"))
    }

    public fun clearNextRunIntent(state: HighSchoolPhase4State): HighSchoolPhase4Result =
        result(sign(state.copy(nextRunIntent = null)), "next_run_intent_cleared")

    public fun dismissReturnPlan(state: HighSchoolPhase4State): HighSchoolPhase4Result {
        require(state.returnPlan != null) { "return_plan.missing" }
        return result(sign(state.copy(returnPlan = state.returnPlan.copy(dismissed = true))), "return_plan_dismissed")
    }

    public fun acknowledgeAchievement(state: HighSchoolPhase4State, achievementId: String): HighSchoolPhase4Result {
        val progress = HighSchoolAchievementRules.acknowledge(
            state.achievements,
            state.unacknowledgedAchievements,
            achievementId,
        )
        return result(
            sign(state.copy(achievements = progress.unlocked, unacknowledgedAchievements = progress.unacknowledged)),
            "achievement_acknowledged",
            listOf("achievement.$achievementId"),
        )
    }

    public fun validateSavedState(state: HighSchoolPhase4State) {
        require(
            state.stateCommitment.isNotBlank() &&
                (state.stateCommitment == commitment(state) ||
                    (state.trainingEvidence.isEmpty() && state.stateCommitment == legacyCommitment(state))),
        ) { "phase4.state_commitment" }
        highSchool.validateSavedState(state.run)
        // The outer revision is the command-journal revision, while the nested run revision
        // advances once per committed gameplay session.  TrainingBlock may commit several
        // sessions under one command, so the two counters are intentionally independent.
        require(state.completedGameReceipts.distinct().size == state.completedGameReceipts.size) { "phase4.game_receipts" }
        require(state.completedGameReceipts.size.toULong() == state.completedGameCounter) { "phase4.game_counter_receipts" }
        require(state.trainingEvidence.map { it.trainingNumber }.distinct().size == state.trainingEvidence.size) { "phase4.training_evidence_duplicate" }
        require(state.trainingEvidence.zipWithNext().all { (before, after) -> before.trainingNumber < after.trainingNumber }) { "phase4.training_evidence_order" }
        state.trainingEvidence.forEach { evidence ->
            require(evidence.codecVersion == 1) { "phase4.training_evidence_version" }
            require(evidence.careerId == state.run.careerId) { "phase4.training_evidence_career" }
            require(evidence.lifeNumber == state.run.lifeNumber && evidence.lifeNumber > 0) { "phase4.training_evidence_life" }
            require(evidence.chapterNumber > 0) { "phase4.training_evidence_chapter" }
            require(evidence.trainingNumber > 0 && evidence.trainingNumber <= state.run.totalTrainingsCompleted) { "phase4.training_evidence_number" }
            require(evidence.growthPoints >= 0) { "phase4.training_evidence_growth" }
            require(evidence.fatigueDelta in -100..100) { "phase4.training_evidence_fatigue" }
        }
        require(state.achievements == HighSchoolAchievementRules.normalize(state.achievements)) { "phase4.achievements" }
        require(state.unacknowledgedAchievements == HighSchoolAchievementRules.normalize(state.unacknowledgedAchievements)) { "phase4.achievement_pending_order" }
        require(state.unacknowledgedAchievements.all { it in state.achievements }) { "phase4.achievement_pending_unknown" }
        require(state.commandReceipts.distinctBy { it.commandId }.size == state.commandReceipts.size) { "phase4.command_receipts" }
        val commandSessions = state.commandReceipts.map { it.sessionId }.distinct()
        require(commandSessions.all(String::isNotBlank) && commandSessions.size <= 1) { "phase4.command_sessions" }
        state.commandReceipts.zipWithNext().forEach { (before, after) ->
            require(before.revision < ULong.MAX_VALUE && after.revision == before.revision + 1UL) { "phase4.command_revision_order" }
        }
        state.commandReceipts.lastOrNull()?.let { require(it.revision == state.revision) { "phase4.command_revision_tail" } }
        require(state.archive.map { it.careerId }.distinct().size == state.archive.size) { "phase4.archive_ids" }
        require(state.archive.zipWithNext().all { (before, after) -> before.completedGameCounterAtArchive <= after.completedGameCounterAtArchive }) { "phase4.archive_counter_order" }
        require(state.archive.all { it.completedGameCounterAtArchive <= state.completedGameCounter }) { "phase4.archive_counter" }
        require(state.tournaments.map { it.chapter to it.bracketSeed }.distinct().size == state.tournaments.size) { "phase4.tournament_duplicate" }
        state.tournaments.forEach { tournament ->
            require(tournament.chapter in setOf(2, 4, 6, 8)) { "phase4.tournament_chapter" }
            require(tournament.playerRound == when {
                tournament.chapter >= 8 -> "결승"
                tournament.chapter >= 6 -> "준결승"
                else -> "8강"
            }) { "phase4.tournament_round" }
            if (tournament.schools.isNotEmpty()) {
                require(tournament.schools.size == HighSchoolTournamentRules.BOARD_SIZE) { "phase4.tournament_field_size" }
                require(tournament.schools.distinct().size == tournament.schools.size) { "phase4.tournament_field_unique" }
                require(tournament.schools.all(String::isNotBlank)) { "phase4.tournament_field_name" }
            }
        }
        if (state.prospectBoard.isNotEmpty()) {
            require(state.prospectBoard.size == HighSchoolProspectRankingRules.BOARD_SIZE) { "phase4.prospect_board_size" }
            require(state.prospectBoard.map { it.rank } == (1..HighSchoolProspectRankingRules.BOARD_SIZE).toList()) { "phase4.prospect_rank_order" }
            require(state.prospectBoard.map { it.name }.distinct().size == state.prospectBoard.size) { "phase4.prospect_names" }
            require(state.prospectBoard.all { it.tag.isNotBlank() && it.score == 0 }) { "phase4.prospect_source_fields" }
            require(state.prospectBoard.count { it.isCurrentPlayer } <= 1) { "phase4.prospect_player_rows" }
        }
        require(state.inheritance.inheritanceRulesVersion == null || state.inheritance.inheritanceRulesVersion in 1..2) { "phase4.inheritance_rules" }
        require(state.run.balanceVersion in 1..HighSchoolGameplayRules.CURRENT) { "phase4.balance_version" }
        require(state.run.worldRulesVersion in 1..HighSchoolContentCatalog.WORLD_RULES_VERSION) { "phase4.world_rules_version" }
        // This is the chronological last-eight history; a returning event can legitimately recur.
        require(state.run.recentRelationshipEventIds.size <= 8 && state.run.recentRelationshipEventIds.all(String::isNotBlank)) { "phase4.relationship_recent" }
        state.run.currentGameScenario?.let { scenario ->
            require(state.run.currentGameScenarioId == scenario.id) { "phase4.scenario_id" }
            require(scenario.inning in 1..20 && scenario.outs in 0..2 && scenario.leverage in 0..1_000) { "phase4.scenario_bounds" }
        }
        state.run.currentRelationshipEvent?.let { event ->
            require(state.run.currentRelationshipCategory == event.category) { "phase4.relationship_event_category" }
            require(event.id in HighSchoolContentCatalog.relationshipEvents.map { it.id }) { "phase4.relationship_event_unknown" }
        }
        require(state.inheritance.lineageMasteries.distinctBy { it.family }.size == state.inheritance.lineageMasteries.size) { "phase4.lineage_masteries" }
        state.nextRunIntent?.let { intent ->
            require(intent.sourceLifeNumber > 0 && intent.sourceLifeNumber <= state.run.lifeNumber) { "phase4.next_intent_life" }
            HighSchoolPledgeRules.definition(intent.pledgeId)
            require(intent.reason.isNotBlank()) { "phase4.next_intent_reason" }
        }
        state.inheritance.lineageMasteries.forEach {
            require(it.family in setOf("power", "command", "breaking", "endurance", "gamecraft", "battery")) { "phase4.lineage_family" }
            require(it.contributions >= 0 && it.rank == HighSchoolLineageRules.masteryRank(it.contributions)) { "phase4.lineage_rank" }
            require(it.nextThreshold == HighSchoolLineageRules.nextThreshold(it.contributions)) { "phase4.lineage_threshold" }
        }
        state.inheritance.lineageLoadout?.let { HighSchoolLineageRules.apply(it, state.startingPitcher, state.run.talent) }
        require(state.weekly.tasks.map { it.id }.distinct().size == state.weekly.tasks.size) { "phase4.weekly_tasks" }
        require(state.weekly.tasks.all { it.target > 0 && it.progress in 0..it.target && it.completed == (it.progress >= it.target) }) { "phase4.weekly_progress" }
        require(state.weekly.processedReceiptIds.distinct().size == state.weekly.processedReceiptIds.size) { "phase4.weekly_receipts" }
        require(state.weekly.playedDayKeys.distinct().size == state.weekly.playedDayKeys.size) { "phase4.weekly_days" }
        require(state.weekly.stamps.map { it.weekKey }.distinct().size == state.weekly.stamps.size) { "phase4.weekly_stamps" }
        require(state.weekly.stamps.all { it.completedTaskCount >= 0 }) { "phase4.weekly_stamp_count" }
        state.returnPlan?.let { plan -> require(HighSchoolReturnPlanRules.isValid(plan)) { "phase4.return_plan" } }
        state.activePitch?.let { session ->
            require(state.run.phase == HighSchoolPhase.IMPORTANT_GAME) { "phase4.pitch_phase" }
            require(session.gameNumber == state.run.performance.importantGamesCompleted + 1) { "phase4.pitch_game_order" }
            require(session.pitchIndex == session.pitches) { "phase4.pitch_index" }
            require(session.log.totalPitches == session.pitches) { "phase4.pitch_log_count" }
            require(session.log.entries.size == session.log.totalPitches) { "phase4.pitch_log_entries" }
            require(session.sequenceMasteryCount in 0..session.pitches) { "phase4.sequence_mastery_count" }
            require(session.sequencePitches.size <= 3) { "phase4.sequence_history_size" }
            require(session.sequencePitches.all { it.zone.row in 0..2 && it.zone.column in 0..2 && it.expectedVelocityKph > 0 }) {
                "phase4.sequence_history"
            }
            if (!session.ended) require(session.preparationToken.isNotBlank()) { "phase4.pitch_preparation" }
        }
        if (state.challenge.active) require(state.challenge.backup != null) { "phase4.challenge_backup" }
        else require(state.challenge.backup == null) { "phase4.challenge_inactive_backup" }
    }

    private fun updateProgress(state: HighSchoolPhase4State): HighSchoolPhase4State {
        if (state.challenge.active) return state
        val pledge = pledgeUpdate(state)
        val achievements = HighSchoolAchievementRules.updateHighSchool(state.achievements.toSet(), state.run, state.archive)
        val progress = HighSchoolAchievementRules.unlock(
            state.achievements,
            state.unacknowledgedAchievements,
            achievements,
        )
        return state.copy(
            pledge = pledge,
            achievements = progress.unlocked,
            unacknowledgedAchievements = progress.unacknowledged,
        )
    }

    private fun pledgeUpdate(state: HighSchoolPhase4State): HighSchoolPledgeState? = HighSchoolPledgeRules.update(
        state.pledge,
        state.run,
        cleanGameCount = state.seasonLog.count { it.played && it.runsAllowed == 0 && it.pitches > 0 },
        rivalStrikeouts = state.seasonLog.sumOf { it.rivalStrikeouts },
    )

    private fun nextRunIntentFor(
        state: HighSchoolPhase4State,
        settled: HighSchoolPledgeState?,
    ): HighSchoolNextRunIntent? {
        if (settled != null && !settled.achieved) {
            return HighSchoolNextRunIntent(
                pledgeId = settled.definition.id,
                sourceLifeNumber = state.run.lifeNumber,
                reason = "지난 고교 3년에서 아쉽게 놓친 목표입니다.",
            )
        }
        val cleanGames = state.seasonLog.count { it.played && it.runsAllowed == 0 && it.pitches > 0 }
        val rivalStrikeouts = state.seasonLog.sumOf { it.rivalStrikeouts }
        val candidate = HighSchoolPledgeRules.options(
            state.weekly.stableUserId,
            state.weekly.weekKey,
            state.run.careerId,
            state.run,
        ).firstOrNull { option ->
            option.id != settled?.definition?.id &&
                !HighSchoolPledgeRules.isAchieved(
                    option,
                    state.run,
                    cleanGameCount = cleanGames,
                    rivalStrikeouts = rivalStrikeouts,
                )
        } ?: return null
        return HighSchoolNextRunIntent(
            pledgeId = candidate.id,
            sourceLifeNumber = state.run.lifeNumber,
            reason = "아카이브에 아직 완주하지 않은 목표입니다.",
        )
    }

    private fun inheritanceReward(state: HighSchoolState, rewardPermille: Int): Int {
        val ratings = state.pitcher.stuff + state.pitcher.command + state.pitcher.movement + state.pitcher.stamina
        val record = state.performance.strikeouts * 2 - state.performance.walks - state.performance.runsAllowed * 2
        val base = maxOf(4, ratings / 8 + maxOf(0, record) / 4)
        return base * maxOf(1_000, rewardPermille) / 1_000
    }

    private fun sign(state: HighSchoolPhase4State): HighSchoolPhase4State = state.copy(stateCommitment = commitment(state))

    private fun commitment(state: HighSchoolPhase4State): String = commitment(state, includeTrainingEvidence = true)

    /** v6 snapshots did not include the evidence ledger; accept their old commitment once. */
    private fun legacyCommitment(state: HighSchoolPhase4State): String = commitment(state, includeTrainingEvidence = false)

    private fun commitment(state: HighSchoolPhase4State, includeTrainingEvidence: Boolean): String {
        val runHash = Hashing.sha256Hex(HighSchoolStateCodec.encode(state.run))
        val archive = state.archive.joinToString(";") { it.careerId + ":" + it.lifeNumber + ":" + it.draftEvaluation + ":" + it.selectedSignatureLegacyId }
        val parts = mutableListOf<Any?>(
            state.revision.toString(), runHash, state.startingPitcher,
            state.inheritance, archive, state.achievements.sorted().joinToString(","), state.unacknowledgedAchievements.sorted().joinToString(","), state.weekly,
            state.pledge, state.selectedSignatureLegacyId ?: "none", state.returnPlan ?: "none", state.rebirthEcho ?: "none",
            state.seasonLog, state.tournaments, state.prospectBoard, state.activePitch ?: "none", state.lastPresentation ?: "none",
            state.tutorial, state.challenge, state.nextRunIntent ?: "none", state.completedGameCounter.toString(), state.completedGameReceipts.joinToString(","),
        )
        if (includeTrainingEvidence) parts += state.trainingEvidence.joinToString(";") { it.toString() }
        parts += state.commandReceipts.joinToString(";") { "${it.commandId}:${it.revision}:${it.resultHash}:${it.commandHash}:${it.sessionId}" }
        parts += state.selectedDayKey
        return StableHash.fnv1a64(
            com.solkim.baseball.core.SaveCommitmentCompatibility.stable(parts.joinToString("|")),
        )
    }

    /** Commits an envelope-store transition without exposing the production persistence layer. */
    public fun commitShadowState(state: HighSchoolPhase4State): HighSchoolPhase4State = sign(state)

    private fun trainingEvidence(
        before: HighSchoolState,
        training: HighSchoolTrainingResult,
        targetPitch: PitchKind?,
    ): HighSchoolTrainingEvidence = HighSchoolTrainingEvidence(
        careerId = before.careerId,
        lifeNumber = before.lifeNumber,
        chapterNumber = before.chapter.number,
        trainingNumber = training.number,
        focus = training.focus,
        intensity = training.intensity,
        targetPitch = targetPitch,
        growthPoints = training.growth,
        fatigueDelta = training.fatigueChange,
    )

    private fun result(
        state: HighSchoolPhase4State,
        event: String,
        reasons: List<String> = emptyList(),
        preparation: PitchPreparation? = null,
        presentation: HighSchoolPresentationState? = null,
    ): HighSchoolPhase4Result {
        val normalized = state.copy(revision = maxOf(state.revision, state.run.revision))
        val committed = sign(normalized)
        val eventHash = StableHash.fnv1a64("${committed.run.careerId}|${committed.revision}|$event|${committed.stateCommitment}")
        return HighSchoolPhase4Result(committed, listOf(HighSchoolEvent(event, 0, reasons)), eventHash, preparation, presentation)
    }

    private fun presentationFrom(snapshot: PitchSnapshot): HighSchoolPresentationState = HighSchoolPresentationState(
        snapshot = snapshot.trajectoryPresentation,
        pitchNumber = snapshot.pitchNumber,
        outcome = snapshot.outcome.wire,
        terminal = snapshot.ended,
        battedBall = snapshot.battedBall,
        fielding = snapshot.fieldingResolution,
    )

    private fun List<HighSchoolTournamentSnapshot>.updateForChapter(chapter: Int, careerId: String, firstLife: Boolean): List<HighSchoolTournamentSnapshot> =
        map { if (it.chapter == chapter && (firstLife || HighSchoolTournamentRules.belongsTo(it, careerId))) it.copy(completed = true) else it }

}

public object HighSchoolTutorialMound {
    public val BATTER: BatterSnapshot = BatterSnapshot("bullpen-batter", "연습 타자", 42, 40, 40, BatSide.RIGHT)
    public val SCOUTING: BatterScoutingSnapshot = BatterScoutingSnapshot(
        hotZone = PitchZone(1, 1),
        coldZone = PitchZone(2, 0),
        pitchStrength = PitchKind.FOUR_SEAM,
        pitchWeakness = PitchKind.CURVEBALL,
        chaseTendency = 45,
        reliability = 100,
    )
}

private fun HighSchoolPitchMemory.toRivalMemory(pitcherId: String, batterId: String): RivalMemorySnapshot =
    toRivalMemory().copy(matchupId = "$pitcherId:$batterId")

private fun HighSchoolPresentationState.snapshotOutcome(): String = outcome

private fun com.solkim.baseball.core.pitch.PitchSnapshot.toNextContext(
    previous: HighSchoolPitchContext,
    game: com.solkim.baseball.core.pitch.GameStateSnapshot,
): HighSchoolPitchContext {
    val inning = game.inningState?.inning ?: previous.inning
    val outs = game.inningState?.outs ?: previous.outs
    return HighSchoolPitchContext(
        plateAppearanceId = previous.plateAppearanceId,
        revision = revision,
        inning = inning.coerceIn(1, 20),
        outs = outs.coerceIn(0, 2),
        balls = if (ended) 0 else balls,
        strikes = if (ended) 0 else strikes,
        pitchNumber = if (ended) 1 else pitchNumber + 1,
        scoreDifferential = previous.scoreDifferential,
        leverage = previous.leverage,
        fatigue = fatigueAfterPitch,
    )
}
