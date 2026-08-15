package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.pitch.PitchCall
import com.solkim.baseball.core.pitch.PitchDelivery
import com.solkim.baseball.core.pitch.PitchIntensity
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchSequenceEvaluator
import com.solkim.baseball.core.pitch.PitchSequencePitch
import com.solkim.baseball.core.pitch.PitchZone
import com.solkim.baseball.core.pitch.PlateAppearanceContext
import com.solkim.baseball.core.pitch.RivalAdaptationBand
import com.solkim.baseball.core.pitch.RivalAdaptationSnapshot
import com.solkim.baseball.core.pitch.ZoneIntent
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

class HighSchoolPhase4KernelTest {
    private val kernel = HighSchoolPhase4Kernel()

    @Test
    fun eightChapterVerticalsCompleteAcrossSeedsAndRestartAtDurableBoundaries() {
        repeat(8) { offset ->
            val seed = (918220 + offset * 17).toString()
            var result = kernel.start(
                HighSchoolPhase4StartRequest(
                    seed = seed,
                    presetId = HighSchoolContentCatalog.presets[offset % HighSchoolContentCatalog.presets.size].id,
                    stableUserId = "phase4-user-$offset",
                    weekKey = "2026-W33",
                    dayKey = "2026-08-${14 + offset}",
                ),
            )
            result = restart(result)
            result = kernel.beginTutorial(result.state)
            result = restart(result)
            result = kernel.completeTutorial(seed, result.state)
            result = restart(result)
            result = kernel.chooseSchool(seed, result.state, HighSchoolSchoolId.entries[offset % HighSchoolSchoolId.entries.size])
            result = restart(result)
            var guard = 0
            while (result.state.run.phase != HighSchoolPhase.COMPLETED && guard++ < 500) {
                result = when (result.state.run.phase) {
                    HighSchoolPhase.TRAINING -> kernel.commitTraining(
                        seed,
                        result.state,
                        HighSchoolTrainingFocus.COMMAND,
                        HighSchoolTrainingIntensity.STANDARD,
                    )
                    HighSchoolPhase.RELATIONSHIP -> kernel.resolveRelationship(
                        seed,
                        result.state,
                        HighSchoolRelationshipResponse.LISTEN,
                    )
                    HighSchoolPhase.IMPORTANT_GAME -> finishReservedGame(result, seed)
                    HighSchoolPhase.AWAKENING -> kernel.chooseAwakening(
                        seed,
                        result.state,
                        result.state.run.awakeningOptions.first(),
                    )
                    HighSchoolPhase.CHAPTER_REVIEW -> kernel.advanceChapter(seed, result.state)
                    HighSchoolPhase.DRAFT -> kernel.resolveDraft(seed, result.state)
                    HighSchoolPhase.LEGACY -> {
                        val prepared = kernel.prepareLegacy(result.state)
                        kernel.selectLegacy(prepared.state, prepared.state.run.legacyOptions.first())
                    }
                    HighSchoolPhase.PROLOGUE,
                    HighSchoolPhase.SCHOOL_SELECTION,
                    HighSchoolPhase.COMPLETED,
                    -> error("unexpected phase ${result.state.run.phase}")
                }
                result = restart(result)
            }
            assertTrue(guard < 500, "seed=$seed did not complete")
            assertEquals(8, result.state.run.chapter.number, "seed=$seed")
            assertTrue(result.state.run.performance.importantGamesCompleted in 4..6, "seed=$seed")
            assertTrue(result.state.completedGameCounter == result.state.run.performance.importantGamesCompleted.toULong())
            if (result.state.run.phase == HighSchoolPhase.COMPLETED && result.state.run.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED) {
                result = kernel.prepareLegacy(result.state)
                result = restart(result)
                result = kernel.selectLegacy(result.state, result.state.run.legacyOptions.first())
            }
            result = kernel.finalizeArchive(result.state)
            result = restart(result)
            assertEquals(1, result.state.archive.size)
            assertEquals(result.state.run.careerId, result.state.archive.single().careerId)
            assertTrue(result.state.inheritance.nextLifeNumber == 2)
            val durableBeforeChallenge = result.state
            val challenge = kernel.startChallenge(durableBeforeChallenge).state
            assertTrue(challenge.challenge.active)
            assertNotEquals(durableBeforeChallenge.run.careerId, challenge.run.careerId)
            assertEquals(HighSchoolPhase.PROLOGUE, challenge.run.phase)
            assertTrue(challenge.archive.isEmpty())
            assertEquals(durableBeforeChallenge.completedGameCounter, challenge.completedGameCounter)
            val challengeRestarted = HighSchoolPhase4StateCodec.decode(HighSchoolPhase4StateCodec.encode(challenge))
            val afterChallenge = kernel.endChallenge(challengeRestarted).state
            assertEquals(durableBeforeChallenge, afterChallenge)
            result = kernel.beginRebirth(result.state, (seed.toULong() + 77UL).toString())
            result = restart(result)
            assertEquals(2, result.state.run.lifeNumber)
            assertEquals(1, result.state.archive.size)
            assertTrue(result.state.rebirthEcho != null)
        }
    }

    @Test
    fun pitchBoundaryProducesFourDistinctPresentationTrajectoriesAndSurvivesRestart() {
        val state = setupImportantGame()
        val reserved = kernel.reserveImportantGame("918220", state)
        val preparation = reserved.preparation ?: error("missing preparation")
        val firstCall = preparation.primaryRecommendation.call
        val submitted = kernel.submitPitch(
            HighSchoolPhase4StateCodec.decode(HighSchoolPhase4StateCodec.encode(reserved.state)),
            reserved.state.activePitch!!.sessionId,
            firstCall,
            PitchDelivery(990, 990),
        )
        assertTrue(submitted.presentation != null)
        assertTrue(submitted.state.lastPresentation!!.snapshot.trajectorySeries.isNotEmpty())
        assertEquals(submitted.state, HighSchoolPhase4StateCodec.decode(HighSchoolPhase4StateCodec.encode(submitted.state)))

        val types = PitchKind.entries.map { it }
        val trajectories = types.map { type ->
            val call = PitchCall(type, PitchZone(0, 1), ZoneIntent.EDGE, PitchIntensity.CONTROLLED)
            val reservedForType = kernel.reserveImportantGame("918220", setupImportantGame())
            val single = kernel.submitPitch(
                reservedForType.state,
                reservedForType.state.activePitch!!.sessionId,
                call,
            )
            single.presentation!!.snapshot.trajectorySeries
        }
        assertEquals(4, trajectories.distinct().size)
    }

    @Test
    fun archiveRebirthWeeklyAchievementAndCounterBoundariesAreMonotonic() {
        var result = kernel.start(
            HighSchoolPhase4StartRequest("918220", "power_prospect", "user", "2026-W33", "2026-08-14"),
        )
        result = kernel.completePrologue("918220", kernel.beginTutorial(result.state).state)
        result = kernel.chooseSchool("918220", result.state, HighSchoolSchoolId.HAEDONG_POWER)
        result = kernel.selectPledge(result.state, HighSchoolPledgeRules.options("user", "2026-W33", result.state.run.careerId).first().id)
        var previous = 0UL
        repeat(3) {
            while (result.state.run.phase == HighSchoolPhase.TRAINING) {
                result = kernel.commitTraining("918220", result.state, HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.LIGHT)
            }
            if (result.state.run.phase == HighSchoolPhase.IMPORTANT_GAME) {
                result = finishReservedGame(result, "918220")
                assertTrue(result.state.completedGameCounter >= previous)
                previous = result.state.completedGameCounter
            }
            if (result.state.run.phase == HighSchoolPhase.RELATIONSHIP) result = kernel.resolveRelationship("918220", result.state, HighSchoolRelationshipResponse.LISTEN)
            if (result.state.run.phase == HighSchoolPhase.AWAKENING) result = kernel.chooseAwakening("918220", result.state, result.state.run.awakeningOptions.first())
            if (result.state.run.phase == HighSchoolPhase.CHAPTER_REVIEW) result = kernel.advanceChapter("918220", result.state)
        }
        assertEquals(result.state.run.performance.importantGamesCompleted.toULong(), result.state.completedGameCounter)
        val challenge = if (result.state.run.phase == HighSchoolPhase.COMPLETED) kernel.startChallenge(result.state).state else result.state
        if (challenge.challenge.active) {
            val before = challenge.completedGameCounter
            val ended = challenge.copy(completedGameCounter = before + 9UL)
            val restored = kernel.endChallenge(ended).state
            assertEquals(before, restored.completedGameCounter)
            assertEquals(challenge.archive, restored.archive)
        }
    }

    @Test
    fun commandStoreRejectsStaleDuplicateTamperedAndFutureWire() {
        val store = HighSchoolPhase4CommandStore()
        val start = HighSchoolPhase4CommandEnvelope(
            commandId = "start-1",
            sessionId = "session-1",
            expectedRevision = 0UL,
            command = HighSchoolPhase4Command.Start(
                HighSchoolPhase4StartRequest("918220", "power_prospect", "user", "2026-W33", "2026-08-14"),
            ),
        )
        val accepted = store.dispatch(start)
        val duplicate = store.dispatch(start)
        assertTrue(duplicate.duplicate)
        assertEquals(accepted.state, duplicate.state)
        assertFailsWith<HighSchoolPhase4CommandException> {
            val request = (start.command as HighSchoolPhase4Command.Start).request
            store.dispatch(start.copy(command = HighSchoolPhase4Command.Start(request.copy(identity = HighSchoolIdentity("다른이름")))))
        }
        assertFailsWith<HighSchoolPhase4CommandException> {
            store.dispatch(start.copy(sessionId = "different-session"))
        }
        assertFailsWith<HighSchoolPhase4CommandException> {
            store.dispatch(start.copy(expectedRevision = 1UL))
        }
        assertFailsWith<HighSchoolPhase4CommandException> {
            store.dispatch(HighSchoolPhase4CommandEnvelope("bad", 1, "stale", "session-1", 0UL, HighSchoolPhase4Command.BeginTutorial))
        }
        val wire = HighSchoolPhase4CommandCodec.encode(HighSchoolPhase4CommandEnvelope(commandId = "begin", sessionId = "session-1", expectedRevision = accepted.state.revision, command = HighSchoolPhase4Command.BeginTutorial))
        assertEquals("beginTutorial", HighSchoolPhase4CommandCodec.decode(wire).let { (it.command as HighSchoolPhase4Command.BeginTutorial); "beginTutorial" })
        val future = String(wire).replace("\"schemaVersion\":1", "\"schemaVersion\":2").toByteArray()
        assertFailsWith<HighSchoolPhase4CommandException> { HighSchoolPhase4CommandCodec.decode(future) }
        val unknown = String(wire).replace("\"payload\":\"beginTutorial\"", "\"payload\":\"beginTutorial\",\"future\":true")
        assertFailsWith<HighSchoolPhase4CommandException> { HighSchoolPhase4CommandCodec.decode(unknown.toByteArray()) }
    }

    @Test
    fun typedCommandCodecRoundTripsEveryPhase4CommandAndRejectsNonCanonicalPayload() {
        val request = HighSchoolPhase4StartRequest(
            seed = "918220",
            presetId = "power_prospect",
            stableUserId = "wire-user",
            weekKey = "2026-W33",
            dayKey = "2026-08-14",
            inheritedSoulPoints = 7,
            inheritedSoulDomain = HighSchoolSoulDomain.TECHNIQUE,
            inheritedMemories = listOf("velocity_blueprint", "fingertip_memory"),
            inheritedSignatureLegacyId = "command_map",
            inheritedLineageMasteries = listOf(HighSchoolLineageMastery("command", 3, 2, 6)),
            lineageLoadout = HighSchoolLineageLoadout(1, "command_map", 2, 3, 1),
            inheritanceRulesVersion = 1,
            inheritedNextRunIntent = HighSchoolNextRunIntent("strikeout_master", 1, "지난 고교 3년에서 아쉽게 놓친 목표입니다."),
            identity = HighSchoolIdentity("한글 투수", "left", "compact", "부산"),
            karmas = listOf(HighSchoolKarma.UNKNOWN_LAND),
            soulBoosts = listOf(HighSchoolSoulBoost.EXTRA_MEMORY),
        )
        val call = PitchCall(PitchKind.CURVEBALL, PitchZone(2, 0), ZoneIntent.CHASE, PitchIntensity.CONTROLLED)
        val plan = HighSchoolReturnPlan(HighSchoolReturnDestination.HIGH_SCHOOL, "resume", "2026-08-14", "return-1")
        val commands: List<HighSchoolPhase4Command> = listOf(
            HighSchoolPhase4Command.Start(request),
            HighSchoolPhase4Command.BeginTutorial,
            HighSchoolPhase4Command.CompleteTutorial("tutorial-seed"),
            HighSchoolPhase4Command.ChooseSchool("school-seed", HighSchoolSchoolId.HAEDONG_POWER),
            HighSchoolPhase4Command.SelectPledge("get_drafted"),
            HighSchoolPhase4Command.Training("training-seed", HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.INTENSIVE),
            HighSchoolPhase4Command.TrainingBlock("block-seed", listOf(HighSchoolTrainingFocus.COMMAND to HighSchoolTrainingIntensity.LIGHT, HighSchoolTrainingFocus.STAMINA to HighSchoolTrainingIntensity.STANDARD)),
            HighSchoolPhase4Command.Relationship("relationship-seed", HighSchoolRelationshipResponse.EXPLAIN),
            HighSchoolPhase4Command.ReserveImportantGame("game-seed"),
            HighSchoolPhase4Command.SubmitPitch("pitch-session", call, PitchDelivery(901, 902)),
            HighSchoolPhase4Command.FinishImportantGame,
            HighSchoolPhase4Command.ChooseAwakening("awakening-seed", HighSchoolAwakening.PINPOINT_EDGE),
            HighSchoolPhase4Command.AdvanceChapter("chapter-seed"),
            HighSchoolPhase4Command.ResolveDraft("draft-seed"),
            HighSchoolPhase4Command.PrepareLegacy,
            HighSchoolPhase4Command.SelectLegacy("command_map"),
            HighSchoolPhase4Command.FinalizeArchive,
            HighSchoolPhase4Command.BeginRebirth("rebirth-seed", "2026-08-15"),
            HighSchoolPhase4Command.StartChallenge,
            HighSchoolPhase4Command.EndChallenge,
            HighSchoolPhase4Command.ClaimWeeklyReward,
            HighSchoolPhase4Command.SaveReturnPlan(plan),
            HighSchoolPhase4Command.PrepareReturnPlan("2026-08-14", 4),
            HighSchoolPhase4Command.SaveNextRunIntent(
                HighSchoolNextRunIntent("get_drafted", 1, "다음 인생에서 다시 도전합니다."),
            ),
            HighSchoolPhase4Command.ClearNextRunIntent,
            HighSchoolPhase4Command.DismissReturnPlan,
            HighSchoolPhase4Command.AcknowledgeAchievement("future_achievement"),
        )
        commands.forEachIndexed { index, command ->
            val envelope = HighSchoolPhase4CommandEnvelope(
                commandId = "typed-$index",
                sessionId = "session-typed",
                expectedRevision = index.toULong(),
                command = command,
            )
            assertEquals(envelope, HighSchoolPhase4CommandCodec.decode(HighSchoolPhase4CommandCodec.encode(envelope)))
        }

        val tutorial = HighSchoolPhase4CommandCodec.encode(
            HighSchoolPhase4CommandEnvelope(commandId = "noncanonical", sessionId = "session", expectedRevision = 0UL, command = HighSchoolPhase4Command.CompleteTutorial("seed")),
        )
        val padded = String(tutorial).replace("c2VlZA\"", "c2VlZA==\"")
        assertFailsWith<HighSchoolPhase4CommandException> { HighSchoolPhase4CommandCodec.decode(padded.toByteArray()) }
        assertFailsWith<HighSchoolPhase4CommandException> { HighSchoolPhase4CommandCodec.decode((" " + String(tutorial)).toByteArray()) }

        val invalidEnvelope = String(tutorial).replace("\"commandId\":\"noncanonical\"", "\"commandId\":\"\"")
        assertFailsWith<HighSchoolPhase4CommandException> {
            HighSchoolPhase4CommandCodec.decode(invalidEnvelope.toByteArray())
        }
    }

    @Test
    fun twentySeedVerticalsAreDeterministicAndLocaleIndependent() {
        val first = (0 until 20).map { offset -> verticalDigest((918220 + offset * 17).toString(), offset) }
        val second = (0 until 20).map { offset -> verticalDigest((918220 + offset * 17).toString(), offset) }
        assertEquals(first, second)
        assertTrue(first.all { it.chapter == 8 && it.importantGames in 4..6 && it.achievements.sorted() == it.achievements })
    }

    @Test
    fun snapshotCodecRejectsTamperedUnknownFutureAndCorruptPayload() {
        val state = kernel.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "user", "2026-W33", "2026-08-14")).state
        val bytes = HighSchoolPhase4StateCodec.encode(state)
        assertEquals(state, HighSchoolPhase4StateCodec.decode(bytes))
        val rankedRun = HighSchoolKernel().resignShadowState(
            state.run.copy(performance = state.run.performance.copy(importantGamesCompleted = 1)),
        )
        val withProspects = kernel.commitShadowState(
            state.copy(
                run = rankedRun,
                prospectBoard = HighSchoolProspectRankingRules.board(rankedRun),
            ),
        )
        assertEquals(withProspects, HighSchoolPhase4StateCodec.decode(HighSchoolPhase4StateCodec.encode(withProspects)))
        val unknown = String(bytes).replace("\"stateCommitment\":\"", "\"unknown\":true,\"stateCommitment\":\"")
        assertFailsWith<HighSchoolPhase4StateCodecException> { HighSchoolPhase4StateCodec.decode(unknown.toByteArray()) }
        val future = String(bytes).replace(
            "\"schemaVersion\":${HighSchoolPhase4StateCodec.SCHEMA_VERSION}",
            "\"schemaVersion\":${HighSchoolPhase4StateCodec.SCHEMA_VERSION + 1}",
        )
        assertFailsWith<HighSchoolPhase4StateCodecException> { HighSchoolPhase4StateCodec.decode(future.toByteArray()) }
        val corrupt = String(bytes).replace("\"payload\":\"", "\"payload\":\"!")
        assertFailsWith<HighSchoolPhase4StateCodecException> { HighSchoolPhase4StateCodec.decode(corrupt.toByteArray()) }
        assertFailsWith<IllegalArgumentException> {
            kernel.validateSavedState(state.copy(prospectBoard = withProspects.prospectBoard))
        }
        assertFailsWith<HighSchoolPhase4StateCodecException> {
            HighSchoolPhase4StateCodec.decode((" " + String(bytes)).toByteArray())
        }
    }

    @Test
    fun lineagePledgeAndWeeklyRulesMatchSourceBackedThresholds() {
        val masteries = HighSchoolLineageRules.masteries(
            listOf("power_imprint", "power_imprint", "power_imprint", "command_map", "command_map", "command_map"),
        )
        assertEquals(2, masteries.first { it.family == "power" }.rank)
        assertEquals(2, masteries.first { it.family == "command" }.rank)
        assertEquals(3, masteries.first { it.family == "command" }.contributions)
        assertEquals(6, masteries.first { it.family == "command" }.nextThreshold)

        var weekly = HighSchoolWeeklyRules.make("user", "2026-W33", "career-1")
        weekly = HighSchoolWeeklyRules.record(weekly, "played_on_two_days", receiptId = "day-1", dayKey = "2026-08-14")
        weekly = HighSchoolWeeklyRules.record(weekly, "played_on_two_days", receiptId = "day-1", dayKey = "2026-08-14")
        assertEquals(1, weekly.tasks.first { it.id == "played_on_two_days" }.progress)
        weekly = HighSchoolWeeklyRules.record(weekly, "played_on_two_days", receiptId = "day-2", dayKey = "2026-08-15")
        assertEquals(2, weekly.tasks.first { it.id == "played_on_two_days" }.progress)
        assertEquals(weekly, HighSchoolWeeklyRules.record(weekly, "played_on_two_days", receiptId = "day-2", dayKey = "2026-08-15"))

        val start = kernel.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "user", "2026-W33", "2026-08-14")).state
        val pledged = HighSchoolPledgeRules.definition("healthy_finish")
        assertTrue(!HighSchoolPledgeRules.isAchieved(pledged, start.run))
        val clean = start.run.copy(
            performance = start.run.performance.copy(importantGamesCompleted = 4),
            armRisk = 54,
            injuryRecovery = 0,
            fatigue = 78,
        )
        assertTrue(HighSchoolPledgeRules.isAchieved(pledged, clean))

        val intentStart = kernel.start(
            HighSchoolPhase4StartRequest(
                "918220", "power_prospect", "user", "2026-W33", "2026-08-14",
                lifeNumber = 2,
                inheritedNextRunIntent = HighSchoolNextRunIntent(
                    "strikeout_master", 1, "지난 고교 3년에서 아쉽게 놓친 목표입니다.",
                ),
            ),
        ).state
        assertEquals(
            "strikeout_master",
            HighSchoolPledgeRules.options(
                "user", "2026-W33", intentStart.run.careerId, intentStart.run, intentStart.nextRunIntent?.pledgeId,
            ).first().id,
        )
        assertEquals(null, kernel.selectPledge(intentStart, "strikeout_master").state.nextRunIntent)
    }

    @Test
    fun pitchSequenceRulesAreSourceShapedAndSessionHistoryIsDurable() {
        val context = PlateAppearanceContext("sequence-pa", 0UL, 1, 0, 0, 0, 2, 0, 500, 0)
        val previous = PitchSequencePitch(PitchKind.FOUR_SEAM, PitchZone(0, 1), ZoneIntent.STRIKE, 145, com.solkim.baseball.core.pitch.PitchOutcome.CALLED_STRIKE)
        val current = PitchSequencePitch(PitchKind.CHANGEUP, PitchZone(2, 1), ZoneIntent.EDGE, 128, com.solkim.baseball.core.pitch.PitchOutcome.SWINGING_STRIKE)
        val moment = PitchSequenceEvaluator.evaluate(listOf(previous), context, current)
        assertEquals("speed_ladder", moment?.tag?.wire)
        val chase = PitchSequenceEvaluator.evaluate(
            emptyList(), context.copy(balls = 0, strikes = 2, pitchNumber = 1),
            current.copy(intent = ZoneIntent.CHASE),
        )
        assertEquals("expand_after_two_strikes", chase?.tag?.wire)
        val counter = PitchSequenceEvaluator.evaluate(
            emptyList(), context.copy(pitchNumber = 1), current.copy(outcome = com.solkim.baseball.core.pitch.PitchOutcome.CALLED_STRIKE),
            RivalAdaptationSnapshot(700, RivalAdaptationBand.LOCKED_ON, 4, PitchKind.FOUR_SEAM, PitchZone(1, 1), PitchKind.FOUR_SEAM, PitchZone(1, 1), 200, 200, 700, "read"),
        )
        assertEquals("counter_read", counter?.tag?.wire)

        val reserved = kernel.reserveImportantGame("918220", setupImportantGame())
        val first = reserved.state
        val afterSave = HighSchoolPhase4StateCodec.decode(HighSchoolPhase4StateCodec.encode(first))
        assertEquals(first.activePitch, afterSave.activePitch)
        assertEquals(0, afterSave.activePitch?.sequenceMasteryCount)
        assertTrue(afterSave.activePitch?.sequencePitches?.isEmpty() == true)
    }

    @Test
    fun tournamentAndProspectReadModelsMatchCurrentSourceProjection() {
        val careerId = "career-918220-life-1"
        val tournament = HighSchoolTournamentRules.snapshot(careerId, 4, "해동고")!!
        assertEquals("전국 화랑기", tournament.name)
        assertEquals("8강", tournament.playerRound)
        assertEquals("d5ba5f9daa18c30f", tournament.bracketSeed)
        assertEquals(
            listOf("대양고", "운암공고", "동성공고", "해동고", "서령고", "청암고", "삼도고", "금강고"),
            tournament.schools,
        )

        val sourceRun = HighSchoolKernel().resignShadowState(
            kernel.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "user", "2026-W33", "2026-08-14"))
                .state.run.copy(
                    performance = HighSchoolPerformance(importantGamesCompleted = 1, strikeouts = 20),
                ),
        )
        val board = HighSchoolProspectRankingRules.board(sourceRun)
        assertEquals(20, board.size)
        assertEquals((1..20).toList(), board.map { it.rank })
        assertEquals(19, HighSchoolProspectRankingRules.playerRank(sourceRun))
        assertEquals(true, board.single { it.isCurrentPlayer }.rank == 19)
        assertEquals(
            listOf(
                "배예준|삼도고|무명 학교에서 혼자 팀을 끌어올린 화제의 투수",
                "김민재|서령고|위기에서만 구속이 오르는 승부사",
                "서동주|북부상고|중학 시절부터 이름난 엘리트 코스",
                "신하준|북부상고|타자들이 타이밍을 못 잡는 디셉션",
                "유서준|중앙체고|중학 시절부터 이름난 엘리트 코스",
            ),
            board.take(5).map { "${it.name}|${it.schoolName}|${it.tag}" },
        )
        assertTrue(board.all { it.score == 0 && it.tag.isNotBlank() })
    }

    @Test
    fun additiveSourceFieldsAndPhase4ReadModelsSurviveStrictCodecs() {
        val started = kernel.start(
            HighSchoolPhase4StartRequest("918220", "power_prospect", "user", "2026-W33", "2026-08-14"),
        ).state
        assertTrue(started.run.schoolOptions.all { it.coachPersonality != null && it.catcherRecord != null })
        assertTrue(started.run.rival.personality != null && started.run.rival.signatureRecord != null)

        val run = HighSchoolKernel().resignShadowState(
            started.run.copy(
                performance = HighSchoolPerformance(importantGamesCompleted = 1, strikeouts = 20),
                draftResult = HighSchoolDraftResult(
                    outcome = HighSchoolDraftOutcome.DRAFTED,
                    evaluationScore = 72,
                    projectedRange = "2~3라운드",
                    teamId = HighSchoolDraftTeamRules.teams.first().id,
                    team = HighSchoolDraftTeamRules.teams.first(),
                    round = 2,
                    overallPick = 14,
                    signingBonus = 210_000_000,
                    firstSeasonGoal = "퓨처스 선발 10경기와 볼넷률 8% 이하",
                    evaluationBreakdown = listOf("능력 45", "관계 +2"),
                    summary = "지명 구단 · 서울 코메츠. 구위와 고교 경기 기록에서 높은 평가를 받았습니다.",
                ),
            ),
        )
        val board = HighSchoolProspectRankingRules.board(run)
        val full = kernel.commitShadowState(
            started.copy(
                run = run,
                tournaments = listOf(HighSchoolTournamentRules.snapshot(run.careerId, 4, "해동고")!!),
                prospectBoard = board,
            ),
        )
        assertEquals(full, HighSchoolPhase4StateCodec.decode(HighSchoolPhase4StateCodec.encode(full)))

        val stateJson = String(HighSchoolStateCodec.encode(run))
        val unknownSchoolField = stateJson.replaceFirst("\"coachRecord\":", "\"futureField\":true,\"coachRecord\":")
        assertFailsWith<HighSchoolStateCodecException> {
            HighSchoolStateCodec.decode(unknownSchoolField.toByteArray())
        }
    }

    @Test
    fun trainingEvidenceRecordsOneTwoThreeEarlyStopSingleSaveFailureAndRestart() {
        (1..3).forEach { requested ->
            val starting = setupTraining()
            val required = starting.run.schedule.trainingsByChapter[starting.run.chapter.number - 1]
            val committed = kernel.commitTrainingBlock(
                "918220",
                starting,
                List(requested) { index ->
                    if (index % 2 == 0) {
                        HighSchoolTrainingFocus.COMMAND to HighSchoolTrainingIntensity.LIGHT
                    } else {
                        HighSchoolTrainingFocus.STAMINA to HighSchoolTrainingIntensity.STANDARD
                    }
                },
            )
            val expected = minOf(requested, required)
            assertEquals(expected, committed.state.trainingEvidence.size)
            assertEquals((1..expected).toList(), committed.state.trainingEvidence.map { it.trainingNumber })
            assertEquals(expected, committed.state.run.totalTrainingsCompleted)
        }

        val single = kernel.commitTraining(
            "918220",
            setupTraining(),
            HighSchoolTrainingFocus.COMMAND,
            HighSchoolTrainingIntensity.STANDARD,
            PitchKind.SLIDER,
        )
        assertEquals(1, single.state.trainingEvidence.size)
        assertEquals(PitchKind.SLIDER, single.state.trainingEvidence.single().targetPitch)
        assertEquals(single.state, HighSchoolPhase4StateCodec.decode(HighSchoolPhase4StateCodec.encode(single.state)))

        val earlyStop = kernel.commitTrainingBlock(
            "918220",
            setupTraining(),
            List(16) { HighSchoolTrainingFocus.COMMAND to HighSchoolTrainingIntensity.STANDARD },
        )
        assertTrue(earlyStop.state.run.phase != HighSchoolPhase.TRAINING)
        assertEquals(
            earlyStop.state.run.schedule.trainingsByChapter[0],
            earlyStop.state.trainingEvidence.size,
        )

        val tampered = single.state.copy(
            trainingEvidence = single.state.trainingEvidence.map { it.copy(growthPoints = -1) },
        )
        assertFailsWith<IllegalArgumentException> { HighSchoolPhase4StateCodec.encode(tampered) }
        assertFailsWith<IllegalArgumentException> { kernel.validateSavedState(tampered) }
    }

    private fun restart(result: HighSchoolPhase4Result): HighSchoolPhase4Result =
        result.copy(state = HighSchoolPhase4StateCodec.decode(HighSchoolPhase4StateCodec.encode(result.state)))

    private fun setupTraining(): HighSchoolPhase4State {
        var result = kernel.start(
            HighSchoolPhase4StartRequest("918220", "power_prospect", "user", "2026-W33", "2026-08-14"),
        )
        result = kernel.completePrologue("918220", kernel.beginTutorial(result.state).state)
        return kernel.chooseSchool("918220", result.state, HighSchoolSchoolId.HAEDONG_POWER).state
    }

    private fun setupImportantGame(): HighSchoolPhase4State {
        var result = kernel.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "user", "2026-W33", "2026-08-14"))
        result = kernel.completePrologue("918220", kernel.beginTutorial(result.state).state)
        result = kernel.chooseSchool("918220", result.state, HighSchoolSchoolId.HAEDONG_POWER)
        while (result.state.run.phase == HighSchoolPhase.TRAINING) {
            result = kernel.commitTraining("918220", result.state, HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.STANDARD)
        }
        while (result.state.run.phase != HighSchoolPhase.IMPORTANT_GAME) {
            result = when (result.state.run.phase) {
                HighSchoolPhase.RELATIONSHIP -> kernel.resolveRelationship("918220", result.state, HighSchoolRelationshipResponse.LISTEN)
                HighSchoolPhase.AWAKENING -> kernel.chooseAwakening("918220", result.state, result.state.run.awakeningOptions.first())
                HighSchoolPhase.CHAPTER_REVIEW -> kernel.advanceChapter("918220", result.state)
                HighSchoolPhase.TRAINING -> kernel.commitTraining("918220", result.state, HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.STANDARD)
                else -> error("phase=${result.state.run.phase}")
            }
        }
        return result.state
    }

    private data class VerticalDigest(
        val chapter: Int,
        val importantGames: Int,
        val draft: HighSchoolDraftOutcome?,
        val evaluation: Int?,
        val achievements: List<String>,
    )

    private fun verticalDigest(seed: String, offset: Int): VerticalDigest {
        var result = kernel.start(
            HighSchoolPhase4StartRequest(
                seed = seed,
                presetId = HighSchoolContentCatalog.presets[offset % HighSchoolContentCatalog.presets.size].id,
                stableUserId = "locale-independent-$offset",
                weekKey = "2026-W33",
                dayKey = "2026-08-14",
            ),
        )
        result = kernel.completePrologue(seed, kernel.beginTutorial(result.state).state)
        result = kernel.chooseSchool(seed, result.state, HighSchoolSchoolId.entries[offset % HighSchoolSchoolId.entries.size])
        var guard = 0
        while (result.state.run.phase != HighSchoolPhase.COMPLETED && guard++ < 700) {
            result = when (result.state.run.phase) {
                HighSchoolPhase.TRAINING -> kernel.commitTraining(seed, result.state, HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.STANDARD)
                HighSchoolPhase.RELATIONSHIP -> kernel.resolveRelationship(seed, result.state, HighSchoolRelationshipResponse.LISTEN)
                HighSchoolPhase.IMPORTANT_GAME -> finishReservedGame(result, seed)
                HighSchoolPhase.AWAKENING -> kernel.chooseAwakening(seed, result.state, result.state.run.awakeningOptions.first())
                HighSchoolPhase.CHAPTER_REVIEW -> kernel.advanceChapter(seed, result.state)
                HighSchoolPhase.DRAFT -> kernel.resolveDraft(seed, result.state)
                HighSchoolPhase.LEGACY -> {
                    val prepared = kernel.prepareLegacy(result.state)
                    kernel.selectLegacy(prepared.state, prepared.state.run.legacyOptions.first())
                }
                else -> error("vertical phase=${result.state.run.phase}")
            }
        }
        assertTrue(guard < 700, "seed=$seed did not finish")
        return VerticalDigest(
            result.state.run.chapter.number,
            result.state.run.performance.importantGamesCompleted,
            result.state.run.draftResult?.outcome,
            result.state.run.draftResult?.evaluationScore,
            result.state.achievements,
        )
    }

    private fun finishReservedGame(result: HighSchoolPhase4Result, seed: String): HighSchoolPhase4Result {
        var current = if (result.state.activePitch == null) kernel.reserveImportantGame(seed, result.state) else result
        var preparation = current.preparation ?: error("preparation missing")
        var guard = 0
        while (current.state.activePitch?.ended != true && guard++ < 80) {
            current = kernel.submitPitch(current.state, current.state.activePitch!!.sessionId, preparation.primaryRecommendation.call, PitchDelivery(700, 700))
            current = restart(current)
            preparation = current.preparation ?: break
        }
        assertTrue(guard < 80, "pitch did not terminate")
        return kernel.finishImportantGame(current.state)
    }
}
