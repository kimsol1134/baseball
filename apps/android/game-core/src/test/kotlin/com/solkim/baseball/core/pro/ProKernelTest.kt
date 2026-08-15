package com.solkim.baseball.core.pro

import com.solkim.baseball.core.highschool.HighSchoolDraftOutcome
import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel
import com.solkim.baseball.core.highschool.HighSchoolPhase4StartRequest
import com.solkim.baseball.core.highschool.HighSchoolPhase4StateCodec
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchCall
import com.solkim.baseball.core.pitch.PitchDelivery
import com.solkim.baseball.core.pitch.PitchIntensity
import com.solkim.baseball.core.pitch.PitchZone
import com.solkim.baseball.core.pitch.ZoneIntent
import com.solkim.baseball.core.highschool.HighSchoolPerformance
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

class ProKernelTest {
    private val kernel = ProKernel()

    private fun direct(seed: String = "7"): ProState = kernel.startDirect(
        ProStartDirectRequest(seed, "power_prospect", "민서준"),
    ).state

    @Test
    fun stateCodecIsCanonicalSignedAndRoundTripsDurableState() {
        val state = direct()
        val encoded = ProStateCodec.encode(state)
        assertTrue(encoded.contentEquals(ProStateCodec.encode(state)))
        assertEquals(state, ProStateCodec.decode(encoded))
        val changedLast = if (state.commitment.last() == '0') '1' else '0'
        val tampered = String(encoded).replace(state.commitment, state.commitment.dropLast(1) + changedLast)
        assertFailsWith<ProStateCodecException> { ProStateCodec.decode(tampered.toByteArray()) }
        val future = String(encoded).replace("\"schemaVersion\":1", "\"schemaVersion\":2")
        assertFailsWith<ProStateCodecException> { ProStateCodec.decode(future.toByteArray()) }
        val linkedRequest = ProStartLinkedRequest(
            seed = "9", highSchoolCareerId = "hs-9", identityName = "연계투수", pitcher = ProCatalog.pitcherForPreset("power_prospect", "연계투수"),
            teamId = ProCatalog.teams.first().id, draftEvaluation = 88,
            highSchoolLegacyContext = ProHighSchoolLegacyContext(
                startingPitcher = ProCatalog.pitcherForPreset("power_prospect", "고교시작"),
                highSchoolPitcher = ProCatalog.pitcherForPreset("power_prospect", "고교최종"),
                performance = HighSchoolPerformance(5, 120, 20, 4, 7, 300, 210, 45, 12),
                selectedAwakenings = listOf("explosive_fastball", "battery_sync"), managerTrust = 61, catcherTrust = 58, rivalTrust = 55,
            ),
        )
        val linked = kernel.startLinked(linkedRequest).state
        assertEquals(linked, ProStateCodec.decode(ProStateCodec.encode(linked)))
    }

    @Test
    fun commandCodecAndStoreRejectDuplicateStaleTamperedUnknownAndFutureWire() {
        val request = ProStartDirectRequest("31", "precision_commander", "고태윤")
        val start = ProCommandEnvelope(commandId = "start-1", sessionId = "pro-session", expectedRevision = 0UL, command = ProCommand.StartDirect(request))
        assertEquals(start, ProCommandCodec.decode(ProCommandCodec.encode(start)))
        val store = ProCommandStore()
        val first = store.dispatch(start)
        val duplicate = store.dispatch(start)
        assertTrue(duplicate.duplicate)
        assertEquals(first.state, duplicate.state)
        val next = ProCommandEnvelope(commandId = "plan-1", sessionId = "pro-session", expectedRevision = first.state.revision, command = ProCommand.PlanWeek("31", ProWeekPlan.DEVELOP_STUFF))
        val applied = store.dispatch(next)
        assertNotEquals(first.state.revision, applied.state.revision)
        assertFailsWith<ProCommandException> { store.dispatch(next.copy(commandId = "plan-stale")) }
        val tampered = next.copy(command = ProCommand.PlanWeek("32", ProWeekPlan.DEVELOP_STUFF))
        assertFailsWith<ProCommandException> { store.dispatch(tampered) }
        val future = String(ProCommandCodec.encode(start)).replace("\"schemaVersion\":1", "\"schemaVersion\":2")
        assertFailsWith<ProCommandException> { ProCommandCodec.decode(future.toByteArray()) }
        val unknown = String(ProCommandCodec.encode(start)).replace("\"kind\":\"startDirect\"", "\"kind\":\"unknown\"")
        assertFailsWith<ProCommandException> { ProCommandCodec.decode(unknown.toByteArray()) }
        val linkedEnvelope = ProCommandEnvelope(commandId = "linked", sessionId = "linked-session", expectedRevision = 0UL, command = ProCommand.StartLinked(request = ProStartLinkedRequest(
            seed = "10", highSchoolCareerId = "hs-10", identityName = "연계투수", pitcher = ProCatalog.pitcherForPreset("precision_commander", "연계투수"), teamId = ProCatalog.teams[1].id, draftEvaluation = 79,
        )))
        assertEquals(linkedEnvelope, ProCommandCodec.decode(ProCommandCodec.encode(linkedEnvelope)))
    }

    @Test
    fun everyProCommandWireRoundTripsThroughTheStrictCanonicalCodec() {
        val call = PitchCall(PitchKind.FOUR_SEAM, PitchZone(1, 1), ZoneIntent.EDGE, PitchIntensity.CONTROLLED)
        val commands = listOf(
            ProCommand.StartLinked(ProStartLinkedRequest("1", "hs-1", "투수", ProCatalog.pitcherForPreset("power_prospect", "투수"), ProCatalog.teams.first().id, 72)),
            ProCommand.StartDirect(ProStartDirectRequest("2", "power_prospect", "투수", "hs-active")),
            ProCommand.SignContract,
            ProCommand.PlanWeek("3", ProWeekPlan.DEVELOP_STUFF, PitchKind.FOUR_SEAM),
            ProCommand.AdvanceSegment("4", ProWeekPlan.DEVELOP_MOVEMENT, PitchKind.SLIDER, 12),
            ProCommand.ApplySeasonDecision("5", "decision-1", "choice-1"),
            ProCommand.ReserveImportantGame("6"),
            ProCommand.SubmitPitch("pitch-1", call, PitchDelivery(700, 650)),
            ProCommand.FinishImportantGame,
            ProCommand.ReviewSeason("7"),
            ProCommand.ChooseOffseason("8", OffseasonDecision.FREE_AGENCY),
            ProCommand.SelectLegacy("power_imprint"),
            ProCommand.NormalizeBalance,
        )
        commands.forEachIndexed { index, command ->
            val envelope = ProCommandEnvelope(commandId = "wire-$index", sessionId = "wire-session", expectedRevision = 0UL, command = command)
            assertEquals(envelope, ProCommandCodec.decode(ProCommandCodec.encode(envelope)), "command=$index")
        }
    }

    @Test
    fun weeklyDevelopmentTargetsMovementAndSegmentBoundariesAreFrozen() {
        assertEquals(ProSeasonSegment.SPRING_CAMP, ProCatalog.segment(0))
        assertEquals(ProSeasonSegment.OPENING, ProCatalog.segment(4))
        assertEquals(ProSeasonSegment.FIRST_HALF, ProCatalog.segment(5))
        assertEquals(ProSeasonSegment.ALL_STAR_BREAK, ProCatalog.segment(11))
        assertEquals(ProSeasonSegment.PENNANT_RACE, ProCatalog.segment(14))
        assertEquals(ProSeasonSegment.SEASON_FINALE, ProCatalog.segment(21))
        var state = direct("77")
        val before = state.pitcher.movement
        state = kernel.planWeek(state, "77", ProWeekPlan.DEVELOP_MOVEMENT, PitchKind.SLIDER).state
        assertEquals(1, state.developmentProgress.movement)
        state = kernel.planWeek(state, "78", ProWeekPlan.DEVELOP_MOVEMENT, PitchKind.SLIDER).state
        assertTrue(state.pitcher.movement >= before + 1)
        assertEquals(ProSeasonSegment.OPENING, state.seasonSegment)
    }

    @Test
    fun importantGameUsesPitchKernelBoundaryAndSurvivesRestart() {
        val base = direct("100")
        val forced = base.copy(
            phase = ProCareerPhase.IMPORTANT_GAME,
            seasonTrigger = ProSeasonTrigger.OPENING_STATEMENT,
            currentRival = ProCatalog.rivalFor(base.team.id, base.season, base.week, ProSeasonTrigger.OPENING_STATEMENT),
            commitment = "",
        ).let { it.copy(commitment = kernel.commitment(it)) }
        var state = kernel.reserveImportantGame(forced, "100").state
        state = ProStateCodec.decode(ProStateCodec.encode(state))
        var guard = 0
        while (state.activePitch?.ended != true && guard < 80) {
            val session = state.activePitch ?: error("missing pitch session")
            // A restart at an already-reserved boundary reuses the deterministic preparation.
            val prep = com.solkim.baseball.core.pitch.PitchKernel().prepare(
                com.solkim.baseball.core.pitch.PitchKernel.PrepareRequest(session.seed, state.pitcher, session.batter, session.scouting, session.context, session.memory, session.game, session.log),
            )
            state = kernel.submitPitch(state, session.sessionId, prep.primaryRecommendation.call).state
            state = ProStateCodec.decode(ProStateCodec.encode(state))
            guard += 1
        }
        assertTrue(guard < 80)
        state = kernel.finishImportantGame(state).state
        assertEquals(ProCareerPhase.WEEKLY_PLAN, state.phase)
        assertTrue(state.currentGameLines.any { it.played && it.week == state.week })
    }

    @Test
    fun fullTwentySeasonDirectCareerClosesLedgerAndNeverCreatesHsArchive() {
        var state = ProStateCodec.decode(ProStateCodec.encode(direct("101")))
        var seed = kernel.startDirect(ProStartDirectRequest("101", "power_prospect", "민서준")).nextSeed
        var guard = 0
        while (state.phase != ProCareerPhase.COMPLETED && guard < 2_000) {
            when (state.phase) {
                ProCareerPhase.WEEKLY_PLAN -> {
                    val result = kernel.planWeek(state, seed, ProWeekPlan.EARN_TRUST)
                    state = ProStateCodec.decode(ProStateCodec.encode(result.state)); seed = result.nextSeed
                }
                ProCareerPhase.SEASON_DECISION -> {
                    val pending = state.pendingDecision ?: error("missing pending decision")
                    state = ProStateCodec.decode(ProStateCodec.encode(kernel.applySeasonDecision(state, seed, pending.id, pending.choices.first().id).state))
                }
                ProCareerPhase.IMPORTANT_GAME -> {
                    var result = kernel.reserveImportantGame(state, seed)
                    state = ProStateCodec.decode(ProStateCodec.encode(result.state))
                    while (state.activePitch?.ended != true) {
                        val session = state.activePitch ?: error("missing active pitch")
                        val preparation = com.solkim.baseball.core.pitch.PitchKernel().prepare(
                            com.solkim.baseball.core.pitch.PitchKernel.PrepareRequest(session.seed, state.pitcher, session.batter, session.scouting, session.context, session.memory, session.game, session.log),
                        )
                        result = kernel.submitPitch(state, session.sessionId, preparation.primaryRecommendation.call)
                        state = result.state; seed = result.nextSeed
                    }
                    result = kernel.finishImportantGame(state)
                    state = ProStateCodec.decode(ProStateCodec.encode(result.state)); seed = result.nextSeed
                }
                ProCareerPhase.SEASON_REVIEW -> {
                    val result = kernel.reviewSeason(state, seed)
                    state = ProStateCodec.decode(ProStateCodec.encode(result.state)); seed = result.nextSeed
                }
                ProCareerPhase.OFFSEASON_DECISION -> {
                    val result = kernel.chooseOffseason(state, seed, if (state.season >= ProCatalog.MAXIMUM_CAREER_SEASONS) OffseasonDecision.RETIRE else OffseasonDecision.CONTINUE)
                    state = ProStateCodec.decode(ProStateCodec.encode(result.state)); seed = result.nextSeed
                }
                ProCareerPhase.RETIREMENT_DECISION -> {
                    val result = kernel.chooseOffseason(state, seed, OffseasonDecision.RETIRE)
                    state = ProStateCodec.decode(ProStateCodec.encode(result.state)); seed = result.nextSeed
                }
                ProCareerPhase.LEGACY_SELECTION -> error("direct career must not open legacy selection")
                ProCareerPhase.CONTRACT_OFFER -> error("direct career auto-signs")
                ProCareerPhase.COMPLETED -> Unit
            }
            guard += 1
        }
        assertTrue(guard < 2_000)
        assertEquals(ProCareerPhase.COMPLETED, state.phase)
        assertEquals(ProCatalog.MAXIMUM_CAREER_SEASONS, state.seasonLedgers.size)
        assertEquals(ProCatalog.MAXIMUM_CAREER_SEASONS, state.careerStats.size)
        assertEquals(state.careerStats, state.seasonLedgers.map { it.record })
        assertTrue(state.seasonLedgers.all { ledger ->
            ledger.standings.size == ProCatalog.teams.size &&
                ledger.standings.map { it.rank } == (1..ProCatalog.teams.size).toList() &&
                ledger.leaderboards.isNotEmpty() && ledger.milestones.isNotEmpty()
        })
        assertEquals(state.awards, state.seasonLedgers.flatMap { it.awards }.distinct())
        assertTrue(state.milestones.any { it.contains("은퇴") })
        assertTrue(state.decisionHistory.all { record -> state.decisionHistory.count { it.season == record.season } <= 3 })
        assertEquals(state.currentStats.teamId, state.team.id)
        assertTrue(state.currentGameLines.isEmpty() || state.currentStats.games == state.currentGameLines.size)
        assertEquals(null, state.highSchoolArchiveSettlement)
        assertEquals(null, state.selectedLegacyId)
        kernel.validateSavedState(state)
    }

    @Test
    fun linkedRetirementFreezesThreeCombinedCandidatesAndSettlesOnlyHsArchive() {
        val hsKernel = HighSchoolPhase4Kernel()
        val seed = "918220"
        var hs = hsKernel.start(
            HighSchoolPhase4StartRequest(
                seed, "power_prospect", "linked-user", "2026-W33", "2026-08-14",
                difficulty = com.solkim.baseball.core.highschool.HighSchoolDifficulty(careerHarshness = "relaxed"),
            ),
        ).state
        hs = hsKernel.completePrologue(seed, hsKernel.beginTutorial(hs).state).state
        hs = hsKernel.chooseSchool(seed, hs, com.solkim.baseball.core.highschool.HighSchoolSchoolId.HAEDONG_POWER).state
        var guard = 0
        while (hs.run.phase != HighSchoolPhase.COMPLETED && guard++ < 500) {
            hs = when (hs.run.phase) {
                HighSchoolPhase.TRAINING -> hsKernel.commitTraining(seed, hs, com.solkim.baseball.core.highschool.HighSchoolTrainingFocus.COMMAND, com.solkim.baseball.core.highschool.HighSchoolTrainingIntensity.STANDARD).state
                HighSchoolPhase.RELATIONSHIP -> hsKernel.resolveRelationship(seed, hs, com.solkim.baseball.core.highschool.HighSchoolRelationshipResponse.LISTEN).state
                HighSchoolPhase.IMPORTANT_GAME -> finishHighSchoolGame(hsKernel, hs, seed)
                HighSchoolPhase.AWAKENING -> hsKernel.chooseAwakening(seed, hs, hs.run.awakeningOptions.first()).state
                HighSchoolPhase.CHAPTER_REVIEW -> hsKernel.advanceChapter(seed, hs).state
                HighSchoolPhase.DRAFT -> hsKernel.resolveDraft(seed, hs).state
                HighSchoolPhase.LEGACY -> {
                    require(hs.run.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED)
                    val prepared = hsKernel.prepareLegacy(hs).state
                    hsKernel.selectLegacy(prepared, prepared.run.legacyOptions.first()).state
                }
                HighSchoolPhase.PROLOGUE, HighSchoolPhase.SCHOOL_SELECTION -> error("unexpected HS phase ${hs.run.phase}")
                HighSchoolPhase.COMPLETED -> hs
            }
            hs = HighSchoolPhase4StateCodec.decode(HighSchoolPhase4StateCodec.encode(hs))
        }
        assertTrue(guard < 500)
        if (hs.run.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED && hs.selectedSignatureLegacyId == null) {
            val prepared = hsKernel.prepareLegacy(hs).state
            hs = hsKernel.selectLegacy(prepared, prepared.run.legacyOptions.first()).state
        }
        assertEquals(HighSchoolDraftOutcome.DRAFTED, hs.run.draftResult?.outcome)
        assertEquals(HighSchoolPhase.COMPLETED, hs.run.phase)
        assertTrue(hs.selectedSignatureLegacyId != null)
        assertEquals(0, hs.archive.size)
        val linkedRequest = ProStartLinkedRequest.fromHighSchool("555", hs)
        var state = kernel.startLinked(linkedRequest).state
        state = kernel.signContract(state, "555").state
        val syntheticStats = (1..20).map { season -> ProSeasonStats(season, state.team.id, games = 24, starts = 24, inningsOuts = 360, strikeouts = 120, walks = 24, runsAllowed = 48, hits = 90, pitches = 2_400) }
        val forcedRetirement = state.copy(
            phase = ProCareerPhase.RETIREMENT_DECISION,
            season = 20,
            week = 24,
            currentStats = ProSeasonStats(20, state.team.id),
            currentGameLines = emptyList(),
            careerStats = syntheticStats,
            seasonLedgers = syntheticStats.map {
                ProSeasonLedger(it.season, state.team.id, it, state.standings, state.leaderboards, emptyList(), listOf("${it.season}시즌 완주"), 0)
            },
            seasonSegment = ProSeasonSegment.SEASON_FINALE,
            commitment = "",
        ).let { it.copy(commitment = kernel.commitment(it)) }
        state = kernel.chooseOffseason(forcedRetirement, "555", OffseasonDecision.RETIRE).state
        assertEquals(ProCareerPhase.LEGACY_SELECTION, state.phase)
        assertEquals(3, state.legacyCandidates.size)
        assertEquals(3, state.legacyCandidates.map { it.id }.distinct().size)
        val frozen = state.legacyCandidates
        state = kernel.selectLegacy(state, frozen.first().id).state
        assertEquals(ProCareerPhase.COMPLETED, state.phase)
        assertEquals(frozen.first().id, state.selectedLegacyId)
        val activeBeforeSettlement = hs
        val settled = kernel.settleLinkedHighSchoolArchive(state, hs)
        assertEquals(activeBeforeSettlement, hs)
        assertEquals(1, settled.archive.size)
        assertEquals(hs.run.careerId, settled.archive.single().careerId)
        assertEquals(state.selectedLegacyId, settled.selectedSignatureLegacyId)
        assertTrue(state.activeHighSchoolPreserved)
        val directWithActiveHs = kernel.startDirect(ProStartDirectRequest("556", "power_prospect", "직접투수", hs.run.careerId)).state
        assertEquals(hs.run.careerId, directWithActiveHs.sourceHighSchoolCareerId)
        assertEquals(null, directWithActiveHs.highSchoolArchiveSettlement)
    }

    private fun finishHighSchoolGame(kernel: HighSchoolPhase4Kernel, initial: com.solkim.baseball.core.highschool.HighSchoolPhase4State, seed: String): com.solkim.baseball.core.highschool.HighSchoolPhase4State {
        var result = kernel.reserveImportantGame(seed, initial)
        var state = result.state
        var preparation = result.preparation ?: error("HS preparation missing after reserve")
        while (state.activePitch?.ended != true) {
            val session = state.activePitch ?: error("HS pitch session missing")
            result = kernel.submitPitch(state, session.sessionId, preparation.primaryRecommendation.call)
            state = result.state
            if (state.activePitch?.ended != true) {
                preparation = result.preparation ?: error("HS preparation missing after pitch")
            }
        }
        return kernel.finishImportantGame(state).state
    }
}
