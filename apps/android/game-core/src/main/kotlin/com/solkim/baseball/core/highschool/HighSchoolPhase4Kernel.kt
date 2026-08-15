package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.StableHash
import com.solkim.baseball.core.pitch.BatterScoutingSnapshot
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
            require(loadout.rulesVersion == HighSchoolLineageRules.RULES_VERSION) { "lineage.rules_version" }
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
                pitcher = lineage.pitcher,
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
            automaticSoulEarned = inheritedTotal.coerceAtLeast(0),
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
    ): HighSchoolPhase4Result {
        require(requests.isNotEmpty() && requests.size <= 16) { "training.block_size" }
        var run = state.run
        val evidence = state.trainingEvidence.toMutableList()
        var nextSeed = seed
        for ((focus, intensity) in requests) {
            val committed = highSchool.commitTraining(HighSchoolKernel.TrainingRequest(nextSeed, run, focus, intensity))
            val training = committed.snapshot.lastTraining ?: error("training.evidence_missing")
            evidence += trainingEvidence(run, training, targetPitch = null)
            run = committed.snapshot
            nextSeed = committed.nextSeed
            if (run.phase != HighSchoolPhase.TRAINING) break
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
        val scenario = state.run.currentGameScenario
            ?: HighSchoolContentCatalog.scenarios.firstOrNull { it.id == state.run.currentGameScenarioId }
            ?: error("importantGame.scenario_missing")
        val pitcher = state.run.toPitcherSnapshot()
        val batter = state.run.toBatterSnapshot()
        val scouting = state.run.toScoutingSnapshot()
        val context = HighSchoolPitchContext(
            plateAppearanceId = "${state.run.careerId}:game:$gameNumber:pa:1",
            revision = 0UL,
            inning = scenario.inning,
            outs = scenario.outs,
            balls = 0,
            strikes = 0,
            pitchNumber = 1,
            scoreDifferential = scenario.scoreDifferential ?: 0,
            leverage = scenario.leverage,
            fatigue = state.run.fatigue.coerceIn(0, 100),
        )
        val initialMemory = HighSchoolPitchMemory()
        val initialGame = HighSchoolPitchGame(
            inning = scenario.inning,
            outs = scenario.outs,
            firstOccupied = scenario.firstOccupied,
            secondOccupied = scenario.secondOccupied,
            thirdOccupied = scenario.thirdOccupied,
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
            sessionId = "${state.run.careerId}:important:$gameNumber",
            gameNumber = gameNumber,
            seed = seed,
            pitchIndex = 0,
            preparationToken = preparation.preparationToken,
            context = context,
            memory = initialMemory,
            game = initialGame,
            log = initialLog,
        )
        return result(sign(state.copy(activePitch = session)), "important_game_reserved", listOf("game.$gameNumber"), preparation)
    }

    /**
     * Submits one player call to the Kotlin PitchKernel. The returned trajectory is the only
     * data suitable for Unity presentation; this method never delegates result generation.
     */
    public fun submitPitch(
        state: HighSchoolPhase4State,
        sessionId: String,
        call: PitchCall,
        delivery: PitchDelivery = PitchDelivery.NEUTRAL,
    ): HighSchoolPhase4Result {
        val session = state.activePitch ?: error("pitch.no_session")
        require(session.sessionId == sessionId) { "pitch.session_stale" }
        require(!session.ended) { "pitch.ended" }
        val pitcher = state.run.toPitcherSnapshot()
        val batter = state.run.toBatterSnapshot()
        val scouting = state.run.toScoutingSnapshot()
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
        // deliberately checked against the durable token before the authoritative submit.
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
        require(preparation.preparationToken == session.preparationToken) { "pitch.preparation_stale" }
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
            expectedVelocityKph = PitchAbilityRules.nominalVelocity(pitcher, call.pitchType, call.intensity, session.context.fatigue) / 10,
            outcome = snapshot.outcome,
        )
        val sequenceMoment = PitchSequenceEvaluator.evaluate(
            recent = session.sequencePitches,
            context = session.context.toPitchContext(),
            current = sequencePitch,
            rivalAdaptation = preparation.rivalAdaptation,
        )
        val nextSequencePitches = if (snapshot.ended) emptyList() else (session.sequencePitches + sequencePitch).takeLast(3)
        val nextContext = snapshot.toNextContext(session.context, result.gameState)
        val nextMemory = result.rivalMemory.toPhase4Memory()
        val nextGame = result.gameState.toPhase4Game()
        val nextLog = result.gameLog.toPhase4Log()
        val nextSession = session.copy(
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
            ended = snapshot.ended,
            sequenceMasteryCount = session.sequenceMasteryCount + if (sequenceMoment != null) 1 else 0,
            sequencePitches = nextSequencePitches,
        )
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
                activePitch = nextSession,
                achievements = achievementProgress.unlocked,
                unacknowledgedAchievements = achievementProgress.unacknowledged,
                lastPresentation = HighSchoolPresentationState(
                    snapshot.trajectoryPresentation,
                    snapshot.pitchNumber,
                    snapshot.outcome.wire,
                    snapshot.ended,
                ),
            ),
        )
        return result(next, "pitch_submitted", snapshot.reasonCodes, result.nextPreparation, next.lastPresentation)
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
            scoreDifferentialAtEntry = session.context.scoreDifferential,
            homeRuns = session.log.entries.count { it.outcome == PitchOutcome.HOME_RUN },
        )
        val nextRun = highSchool.recordImportantGame(
            HighSchoolKernel.GameRequest(session.seed, state.run, report),
        ).snapshot
        val line = HighSchoolSeasonLineRules.line(
            session.seed,
            state.run,
            report,
            outingNumber = state.seasonLog.size + 1,
        ).copy(abilityMoments = session.abilityMoments)
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
        val nextSeasonLog = if (state.challenge.active) state.seasonLog else state.seasonLog + line
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
        val tournaments = if (state.challenge.active) state.tournaments else state.tournaments.updateForChapter(nextRun.chapter.number)
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

    public fun advanceChapter(seed: String, state: HighSchoolPhase4State): HighSchoolPhase4Result {
        val next = highSchool.advanceChapter(HighSchoolKernel.AdvanceRequest(seed, state.run)).snapshot
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
        return result(sign(updateProgress(state.copy(run = next, weekly = weekly, tournaments = tournaments))), "chapter_advanced", listOf("chapter.${next.chapter.number}"))
    }

    public fun resolveDraft(seed: String, state: HighSchoolPhase4State): HighSchoolPhase4Result {
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
                (state.archive.mapNotNull { it.selectedSignatureLegacyId } + state.selectedSignatureLegacyId).distinct(),
            ),
            lineageLoadout = HighSchoolLineageRules.loadout(
                legacyId = state.selectedSignatureLegacyId,
                selectedLegacyIds = (state.archive.mapNotNull { it.selectedSignatureLegacyId } + state.selectedSignatureLegacyId).distinct(),
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

    public fun beginRebirth(state: HighSchoolPhase4State, seed: String, dayKey: String = state.selectedDayKey): HighSchoolPhase4Result {
        require(state.run.phase == HighSchoolPhase.COMPLETED) { "rebirth.phase" }
        require(state.archive.any { it.careerId == state.run.careerId }) { "rebirth.archive_required" }
        val echo = HighSchoolRebirthEcho(
            previousLifeNumber = state.run.lifeNumber,
            previousPlayerName = state.run.identity.name,
            previousSchoolName = state.run.school?.name,
            previousCareerId = state.run.careerId,
            inheritedMemoryCount = state.inheritance.inheritedMemories.size,
            inheritedSignatureLegacyId = state.inheritance.selectedSignatureLegacyId,
            previousArmWarning = state.run.armRisk >= HighSchoolContentCatalog.ARM_WARNING_THRESHOLD,
            previousUndrafted = state.run.draftResult?.outcome == HighSchoolDraftOutcome.UNDRAFTED,
            recentEventIds = state.run.recentRelationshipEventIds.takeLast(3),
            previousCoachName = state.run.school?.coachName,
            previousRivalName = state.run.rival.name,
            inheritedLegacyId = state.inheritance.selectedSignatureLegacyId,
            automaticInheritanceTotal = state.inheritance.soulTotalEarned,
            hadRunsAllowed = state.run.performance.runsAllowed > 0,
            hadCollapseGame = state.run.performance.runsAllowed > 0,
        )
        val request = HighSchoolPhase4StartRequest(
            seed = seed,
            presetId = state.run.presetId,
            stableUserId = state.weekly.stableUserId,
            weekKey = state.weekly.weekKey,
            dayKey = dayKey,
            lifeNumber = state.inheritance.nextLifeNumber,
            creationAllocation = HighSchoolAllocation(),
            inheritedSoulPoints = state.inheritance.soulPoints,
            inheritedSoulTotal = state.inheritance.soulTotalEarned,
            inheritedMemories = state.inheritance.inheritedMemories,
            inheritedSignatureLegacyId = state.inheritance.selectedSignatureLegacyId,
            inheritedLineageMasteries = state.inheritance.lineageMasteries,
            lineageLoadout = state.inheritance.lineageLoadout,
            inheritanceRulesVersion = state.inheritance.inheritanceRulesVersion,
            inheritedNextRunIntent = state.nextRunIntent,
            identity = state.run.identity,
            difficulty = state.run.difficulty,
            karmas = state.run.karmas,
            soulBoosts = state.run.soulBoosts,
            inheritedRebirthEcho = echo,
        )
        val fresh = start(request).state
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
                inheritance = state.inheritance,
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

    public fun startChallenge(state: HighSchoolPhase4State): HighSchoolPhase4Result {
        require(!state.challenge.active) { "challenge.already_active" }
        require(state.run.phase == HighSchoolPhase.COMPLETED) { "challenge.phase" }
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
        val challengeSeed = Hashing.fnv1a64Hex("challenge|${state.run.careerId}").toULong(16).toString()
        val fresh = start(
            HighSchoolPhase4StartRequest(
                seed = challengeSeed,
                presetId = state.run.presetId,
                stableUserId = state.weekly.stableUserId,
                weekKey = state.weekly.weekKey,
                dayKey = state.selectedDayKey,
                lifeNumber = state.run.lifeNumber,
                identity = state.run.identity,
                difficulty = state.run.difficulty,
                karmas = emptyList(),
                soulBoosts = emptyList(),
                inheritedSoulPoints = 0,
                inheritedMemories = emptyList(),
                inheritedSignatureLegacyId = null,
                inheritanceRulesVersion = null,
                inheritedNextRunIntent = null,
            ),
        ).state
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
        require(!state.challenge.active) { "weekly.challenge_locked" }
        require(!state.weekly.rewardClaimed) { "weekly.already_claimed" }
        require(HighSchoolWeeklyRules.completeCount(state.weekly) >= 2) { "weekly.incomplete" }
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
        require(state.tournaments.map { it.chapter }.distinct().size == state.tournaments.size) { "phase4.tournament_duplicate" }
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
        require(state.run.balanceVersion in 1..HighSchoolContentCatalog.BALANCE_VERSION) { "phase4.balance_version" }
        require(state.run.worldRulesVersion in 1..HighSchoolContentCatalog.WORLD_RULES_VERSION) { "phase4.world_rules_version" }
        require(state.run.recentRelationshipEventIds.distinct().size == state.run.recentRelationshipEventIds.size) { "phase4.relationship_recent" }
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
        cleanGameCount = state.seasonLog.count { it.runsAllowed == 0 && it.pitches > 0 },
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
        val cleanGames = state.seasonLog.count { it.runsAllowed == 0 && it.pitches > 0 }
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
            parts.joinToString("|"),
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

    private fun List<HighSchoolTournamentSnapshot>.updateForChapter(chapter: Int): List<HighSchoolTournamentSnapshot> =
        map { if (it.chapter == chapter) it.copy(completed = true) else it }
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
