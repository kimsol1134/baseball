package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.core.pro.*
import com.solkim.baseball.core.pitch.*
import com.solkim.baseball.model.Hashing
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardOpenOption
import kotlin.test.*

/** Current rules only. Descriptive balance samples, not fabricated perfect game reports. */
class LongHorizonBalanceAuditTest {
    private val directory = Path.of("../../../artifacts/android-compose/long-horizon")
    private val seeds = listOf("918220", "401123", "772019")
    private val presets = listOf("power_prospect", "precision_commander")
    private fun file(name: String, header: String): Path {
        Files.createDirectories(directory)
        return directory.resolve(name).also { Files.writeString(it, header + "\n") }
    }
    private fun row(path: Path, values: List<Any?>) { Files.writeString(path, values.joinToString(",") + "\n", StandardOpenOption.APPEND) }
    private fun seed(base: String, key: String): String = Hashing.fnv1a64Hex("$base|$key").toULong(16).toString()
    private fun ratings(p: PitcherSnapshot) = listOf(p.stuff, p.command, p.movement, p.stamina)
    private fun ratings(p: HighSchoolPitcher) = listOf(p.stuff, p.command, p.movement, p.stamina)
    private fun mastery(m: AbilityMasterySnapshot) = m.stuff + m.command + m.movement + m.stamina

    @Test fun eighteenCurrentRuleProCareersRunUntilRetirementWithSeasonCheckpoints() {
        val output = file("pro-seasons.csv", "seed,preset,policy,season,age,level,role,stuff,command,movement,stamina,mastery,games,outs,k,h,bb,r,w,l,sv,injured_weeks,injury_events,max_fatigue,rating_flat_training_weeks,manual_pitches")
        val summaries = file("pro-careers.csv", "seed,preset,policy,seasons,hall_of_fame_score,awards,stuff,command,movement,stamina,mastery")
        for (initialSeed in seeds) for (preset in presets) for (policy in listOf("power", "balanced", "recovery")) {
            val k = ProKernel()
            val pitcher = PitchKernel()
            var state = k.startDirect(ProStartDirectRequest(initialSeed, preset, "장기검증투수")).state
            var steps = 0; var injuredWeeks = 0; var injuries = 0; var maxFatigue = 0; var flatWeeks = 0; var manual = 0
            val recorded = mutableSetOf<Int>()
            while (state.phase != ProCareerPhase.COMPLETED) {
                check(steps++ < 15000) { "Unfinished $initialSeed/$policy ${state.season}/${state.week}/${state.phase}" }
                val before = state
                val rng = seed(initialSeed, "${state.season}:${state.week}:${state.phase}:${state.revision}")
                val result = when (state.phase) {
                    ProCareerPhase.CONTRACT_OFFER -> state.journeyState?.pendingContractMarket?.offers?.firstOrNull()?.let {
                        k.acceptContractOffer(state, rng, it.id, ProCareerAmbition.entries.firstOrNull { goal -> state.journeyState!!.goalHistory.none { history -> history.ambition == goal && history.outcome == ProCareerGoalOutcome.COMPLETED } })
                    } ?: k.signContract(state, rng)
                    ProCareerPhase.WEEKLY_PLAN -> {
                        val plan = when {
                            policy == "power" -> ProWeekPlan.DEVELOP_STUFF
                            state.injuryWeeks > 0 || state.fatigue >= if (policy == "recovery") 45 else 65 -> ProWeekPlan.RECOVER
                            else -> listOf(ProWeekPlan.DEVELOP_STUFF, ProWeekPlan.REFINE_COMMAND, ProWeekPlan.DEVELOP_MOVEMENT, ProWeekPlan.BUILD_STAMINA, ProWeekPlan.EARN_TRUST)[state.week % 5]
                        }
                        k.planWeek(state, rng, plan).also {
                            if (plan !in setOf(ProWeekPlan.RECOVER, ProWeekPlan.EARN_TRUST) && ratings(state.pitcher) == ratings(it.state.pitcher)) flatWeeks++
                        }
                    }
                    ProCareerPhase.SEASON_DECISION -> k.applySeasonDecision(state, rng, state.pendingDecision!!.id, state.pendingDecision!!.choices.first().id)
                    ProCareerPhase.IMPORTANT_GAME -> {
                        val active = state.activePitch
                        if (active == null) k.reserveImportantGame(state, rng)
                        else if (active.ended) k.finishImportantGame(state)
                        else {
                            val prep = pitcher.prepare(PitchKernel.PrepareRequest(active.seed,
                                PitchLearningRules.playable(state.pitcher, state.pitchLearningProject), active.batter, active.scouting, active.context, active.memory, active.game, active.log))
                            val delivery = PitchDelivery(780 + (manual % 4)*45, 740 + (manual % 3)*60)
                            manual++
                            k.submitPitch(state, active.sessionId, prep.primaryRecommendation.call, delivery)
                        }
                    }
                    ProCareerPhase.SEASON_REVIEW -> k.reviewSeason(state, rng)
                    ProCareerPhase.SEASON_SETTLEMENT -> k.acknowledgeSeasonSettlement(state, rng, state.journeyState!!.lastSettlement!!.id)
                    ProCareerPhase.NATIONAL_TEAM_CALL -> k.respondToNationalTeamCall(state, rng, false)
                    ProCareerPhase.NATIONAL_TOURNAMENT -> k.acknowledgeNationalTeamResult(state, rng)
                    ProCareerPhase.OFFSEASON_DECISION -> k.chooseOffseason(state, rng, OffseasonDecision.CONTINUE)
                    ProCareerPhase.OFFSEASON_INVESTMENT -> k.chooseInvestment(state, rng, ProOffseasonInvestment.NONE, null)
                    ProCareerPhase.RETIREMENT_DECISION -> k.chooseOffseason(state, rng, OffseasonDecision.RETIRE)
                    ProCareerPhase.LEGACY_SELECTION -> k.selectLegacy(state, state.legacyCandidates.first().id)
                    ProCareerPhase.COMPLETED -> error("unreachable")
                }
                state = result.state
                assertEquals(ProCatalog.RULES_VERSION, state.proRulesVersion)
                assertTrue(ratings(state.pitcher).all { it in 20..80 })
                if (before.season == state.season && state.week > before.week && state.injuryWeeks > 0) injuredWeeks++
                if (result.injuryEvent != null) injuries++
                maxFatigue = maxOf(maxFatigue, state.fatigue)
                for (stats in state.careerStats) if (recorded.add(stats.season)) {
                    assertTrue(stats.starts <= stats.games)
                    assertTrue(stats.wins + stats.losses + stats.saves <= stats.games)
                    assertTrue(stats.strikeouts <= stats.inningsOuts)
                    assertTrue(stats.homeRuns <= stats.hits)
                    row(output, listOf(initialSeed, preset, policy, stats.season, state.age, state.level.wire, state.role.wire) + ratings(state.pitcher) +
                        listOf(mastery(state.pitcher.effectiveMastery), stats.games, stats.inningsOuts, stats.strikeouts, stats.hits, stats.walks, stats.runsAllowed, stats.wins, stats.losses, stats.saves, injuredWeeks, injuries, maxFatigue, flatWeeks, manual))
                    val checkpoint = directory.resolve("pro-$initialSeed-$preset-$policy.checkpoint")
                    Files.write(checkpoint, ProStateCodec.encode(state))
                    val restored = ProStateCodec.decode(Files.readAllBytes(checkpoint))
                    k.validateSavedState(restored)
                    assertEquals(state, restored)
                    state = restored
                    injuredWeeks = 0; injuries = 0; maxFatigue = state.fatigue; flatWeeks = 0; manual = 0
                }
            }
            assertTrue(recorded.isNotEmpty() && recorded.size <= 20)
            assertEquals(state.careerStats.size, state.careerStats.map { it.season }.distinct().size)
            row(summaries, listOf(initialSeed, preset, policy, state.careerStats.size, state.hallOfFameScore, state.seasonLedgers.sumOf { it.awards.size }) + ratings(state.pitcher) + mastery(state.pitcher.effectiveMastery))
            println("PRO_AUDIT seed=$initialSeed preset=$preset policy=$policy seasons=${recorded.size} phase=${state.phase}")
        }
    }

    @Test fun sevenLivesAcrossSeedsPresetsAndIntensitiesPreserveHistoryAndMeasureGrowth() {
        val output = file("school-lives.csv", "seed,preset,intensity,life,start_stuff,start_command,start_movement,start_stamina,end_stuff,end_command,end_movement,end_stamina,trainings,recovery_trainings,rating_flat_trainings,mastery_trainings,start_skills,end_skills,games,outs,k,h,bb,r,drafted,evaluation,soul_earned,soul_balance,first_skill_chapter,injury_training_steps,applied_lineage_rank,applied_lineage_contributions,selected_legacy,preferred_legacy_available,start_stuff_pressure,start_command_pressure,start_movement_pressure,start_stamina_pressure")
        for (initialSeed in seeds) for (preset in presets) for (intensity in HighSchoolTrainingIntensity.entries) {
            val k = HighSchoolPhase4Kernel()
            var state = k.start(HighSchoolPhase4StartRequest(initialSeed, preset, "long-$initialSeed", "2026-W37", "2026-09-08")).state
            for (life in 1..7) {
                val start = ratings(state.run.pitcher)
                val startSkills = state.run.selectedAwakenings.size
                val rank = state.inheritance.lineageLoadout?.masteryRank ?: 0
                val contributions = state.inheritance.lineageLoadout?.contributions ?: 0
                val pressure = state.run.talent.let { listOf(it.stuffPressure, it.commandPressure, it.movementPressure, it.staminaPressure) }
                val previousArchive = state.archive.toList()
                val previousTournaments = state.tournaments.toList()
                var steps = 0; var recovery = 0; var flat = 0; var masteryGrowth = 0; var firstSkill = 0; var injurySteps = 0
                while (state.run.phase !in setOf(HighSchoolPhase.LEGACY, HighSchoolPhase.COMPLETED)) {
                    check(steps++ < 2500) { "Unfinished school $initialSeed/$intensity/$life ${state.run.phase}" }
                    val run = state.run
                    val rng = seed(initialSeed, "$life:${run.chapter.number}:${run.totalTrainingsCompleted}:${run.phase}")
                    state = when (run.phase) {
                        HighSchoolPhase.PROLOGUE -> k.completeTutorial(rng, if (state.tutorial.started) state else k.beginTutorial(state).state).state
                        HighSchoolPhase.SCHOOL_SELECTION -> k.chooseSchool(rng, state, run.schoolOptions.first().id).state
                        HighSchoolPhase.TRAINING -> {
                            val focus = if (run.fatigue > 65 || run.injuryRecovery > 0) HighSchoolTrainingFocus.RECOVERY
                                else listOf(HighSchoolTrainingFocus.VELOCITY, HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingFocus.BREAKING_BALL, HighSchoolTrainingFocus.STAMINA)[run.totalTrainingsCompleted % 4]
                            if (focus == HighSchoolTrainingFocus.RECOVERY) recovery++
                            if (run.injuryRecovery > 0) injurySteps++
                            val next = k.commitTraining(rng, state, focus, intensity).state
                            if (focus != HighSchoolTrainingFocus.RECOVERY && ratings(run.pitcher) == ratings(next.run.pitcher)) flat++
                            if (mastery(next.run.pitcher.effectiveMastery) > mastery(run.pitcher.effectiveMastery)) masteryGrowth++
                            next
                        }
                        HighSchoolPhase.RELATIONSHIP -> k.resolveRelationship(rng, state, HighSchoolRelationshipResponse.LISTEN).state
                        HighSchoolPhase.IMPORTANT_GAME -> {
                            val active = state.activePitch
                            if (active == null) k.reserveImportantGame(rng, state).state
                            else if (active.ended) k.finishImportantGame(state).state
                            else k.submitPitch(state, active.sessionId, k.prepareActivePitch(state).primaryRecommendation.call,
                                PitchDelivery(780 + (active.pitches % 4)*45, 740 + (active.pitches % 3)*60)).state
                        }
                        HighSchoolPhase.AWAKENING -> {
                            if (firstSkill == 0) firstSkill = run.chapter.number
                            k.chooseAwakening(rng, state, run.awakeningOptions.first()).state
                        }
                        HighSchoolPhase.CHAPTER_REVIEW -> k.advanceChapter(rng, state).state
                        HighSchoolPhase.DRAFT -> k.resolveDraft(rng, state).state
                        else -> error("unexpected ${run.phase}")
                    }
                }
                state = k.prepareLegacy(state).state
                val preferred = if (preset == "precision_commander") "command_map" else "power_imprint"
                val preferredAvailable = preferred in state.run.legacyOptions
                val selectedLegacy = if (preferredAvailable) preferred else state.run.legacyOptions.first()
                state = k.selectLegacy(state, selectedLegacy).state
                state = k.finalizeArchive(state).state
                assertEquals(previousArchive, state.archive.take(previousArchive.size))
                assertEquals(previousTournaments, state.tournaments.take(previousTournaments.size))
                val run = state.run
                val lines = state.seasonLog.filter { it.careerId == run.careerId }
                val record = state.archive.last()
                row(output, listOf(initialSeed, preset, intensity.wire, life) + start + ratings(run.pitcher) + listOf(run.totalTrainingsCompleted, recovery, flat, masteryGrowth, startSkills, run.selectedAwakenings.size,
                    lines.map { it.gameNumber }.distinct().size, lines.sumOf { it.outs }, lines.sumOf { it.strikeouts }, lines.sumOf { it.hits }, lines.sumOf { it.walks }, lines.sumOf { it.runsAllowed },
                    record.drafted, record.draftEvaluation, record.soulEarned, state.inheritance.soulPoints, firstSkill, injurySteps, rank, contributions, selectedLegacy, preferredAvailable) + pressure)
                val checkpoint = directory.resolve("school-$initialSeed-$preset-${intensity.wire}.checkpoint")
                Files.write(checkpoint, HighSchoolPhase4StateCodec.encode(state))
                val restored = HighSchoolPhase4StateCodec.decode(Files.readAllBytes(checkpoint))
                k.validateSavedState(restored); assertEquals(state, restored); state = restored
                if (life < 7) state = k.beginRebirth(state, seed(initialSeed, "rebirth:$life"), "2026-09-08").state
                assertTrue(ratings(state.run.pitcher).all { it in 20..80 })
            }
            assertEquals(7, state.archive.size)
            println("SCHOOL_AUDIT seed=$initialSeed preset=$preset intensity=$intensity lives=${state.archive.size}")
        }
    }
}
