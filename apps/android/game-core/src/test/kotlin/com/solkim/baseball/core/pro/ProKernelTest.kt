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
import com.solkim.baseball.core.pitch.AbilityMasterySnapshot
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
        val encodedText = String(encoded)
        val schemaVersion = if (encodedText.contains(ProStateCodecV2.SCHEMA)) ProStateCodecV2.SCHEMA_VERSION else ProStateCodec.SCHEMA_VERSION
        val future = encodedText.replace(
            "\"schemaVersion\":$schemaVersion",
            "\"schemaVersion\":${schemaVersion + 1}",
        )
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

        val masteredUnsigned = state.copy(
            pitcher = state.pitcher.copy(
                mastery = AbilityMasterySnapshot(stuff = 14, command = 2, movement = 9, stamina = 31),
            ),
            commitment = "",
        )
        val mastered = masteredUnsigned.copy(commitment = ProKernel().commitment(masteredUnsigned))
        assertEquals(mastered, ProStateCodec.decode(ProStateCodec.encode(mastered)))
    }

    @Test
    fun seasonReviewArchivesPostseasonGamesThroughStateCodec() {
        val signed = kernel.startDirect(ProStartDirectRequest("404", "power_prospect", "결산투수")).state
        val postseasonGames = listOf(
            ProPostseasonGameLine(
                round = ProAutumnRound.WILD_CARD,
                gameNumber = 1,
                teamRuns = 4,
                opponentRuns = 2,
                directlyPlayed = true,
                playerPitches = 88,
                playerOuts = 15,
                playerRunsAllowed = 1,
                playerStrikeouts = 5,
                playerWalks = 1,
                playerHits = 4,
                playerStarted = true,
            ),
        )
        val record = ProSeasonStats(
            season = 1,
            teamId = signed.team.id,
            games = 24,
            starts = 24,
            inningsOuts = 360,
            strikeouts = 120,
            walks = 24,
            runsAllowed = 48,
            hits = 90,
            pitches = 2_400,
            wins = 12,
            losses = 8,
            postseasonGames = postseasonGames,
        )
        val archived = signed.copy(
            phase = ProCareerPhase.OFFSEASON_DECISION,
            week = ProCatalog.WEEKS_PER_SEASON,
            seasonSegment = ProSeasonSegment.SEASON_FINALE,
            currentStats = ProSeasonStats(1, signed.team.id),
            currentGameLines = emptyList(),
            careerStats = listOf(record),
            seasonLedgers = listOf(
                ProSeasonLedger(1, signed.team.id, record, signed.standings, signed.leaderboards, emptyList(), listOf("1시즌 완주"), 0),
            ),
            commitment = "",
        ).let { it.copy(commitment = kernel.commitment(it)) }
        kernel.validateSavedState(archived)
        val roundTripped = ProStateCodec.decode(ProStateCodec.encode(archived))
        assertEquals(postseasonGames, roundTripped.careerStats.single().postseasonGames)
        assertEquals(postseasonGames, roundTripped.seasonLedgers.single().record.postseasonGames)
        assertEquals(archived, roundTripped)
    }

    @Test
    fun newDirectCareerUsesCurrentRulesAndMediaDecisionOpensOnHashedWeek() {
        val started = kernel.startDirect(ProStartDirectRequest("404", "power_prospect", "미디어투수"))
        var state = started.state
        assertEquals(ProCatalog.RULES_VERSION, state.proRulesVersion)
        val mediaWeek = ProCatalog.mediaOpportunityWeek(state.careerId, state.season, state.proRulesVersion)
        assertTrue(mediaWeek in ProCatalog.WEEKLY_SEASON_DECISION_WEEKS)
        val prepared = state.copy(
            week = mediaWeek - 1,
            seasonSegment = ProCatalog.segment(mediaWeek - 1),
            importantGames = 2,
            commitment = "",
        ).let { it.copy(commitment = kernel.commitment(it)) }
        kernel.validateSavedState(prepared)
        val opened = kernel.planWeek(prepared, prepared.seed, ProWeekPlan.EARN_TRUST)
        assertEquals(ProCareerPhase.SEASON_DECISION, opened.state.phase)
        assertEquals(ProSeasonDecisionType.MEDIA_OPPORTUNITY, opened.state.pendingDecision?.type)
        assertEquals(mediaWeek, opened.state.week)
        val applied = kernel.applySeasonDecision(
            opened.state,
            opened.nextSeed,
            requireNotNull(opened.state.pendingDecision).id,
            requireNotNull(opened.state.pendingDecision).choices.first().id,
        )
        val reviewed = applied.state.copy(
            phase = ProCareerPhase.SEASON_REVIEW,
            pendingDecision = null,
            week = ProCatalog.WEEKS_PER_SEASON,
            seasonSegment = ProCatalog.segment(ProCatalog.WEEKS_PER_SEASON),
            commitment = "",
        ).let { it.copy(commitment = kernel.commitment(it)) }
        kernel.validateSavedState(reviewed)
        val afterReview = kernel.reviewSeason(reviewed, applied.nextSeed)
        assertEquals(ProCareerPhase.SEASON_SETTLEMENT, afterReview.state.phase)
        val settlement = requireNotNull(afterReview.state.journeyState?.lastSettlement)
        assertEquals(
            ProJourneyKernel.merchandiseIncome(requireNotNull(reviewed.journeyState).reputation.fanSupport),
            settlement.merchandiseIncome,
        )
        assertEquals(settlement.fanAfter - settlement.fanBefore, settlement.fanDelta)
        assertEquals(settlement.contractYearsBefore - 1, settlement.contractYearsAfter)
        assertTrue(settlement.fanReasons.isNotEmpty())
        val settled = kernel.acknowledgeSeasonSettlement(
            afterReview.state,
            afterReview.nextSeed,
            requireNotNull(afterReview.state.journeyState?.lastSettlement).id,
        )
        val roundTripped = ProStateCodec.decode(ProStateCodec.encode(settled.state))
        assertEquals(settled.state, roundTripped)
        assertEquals(ProCareerPhase.OFFSEASON_DECISION, roundTripped.phase)
        assertTrue(roundTripped.decisionHistory.any { it.type == ProSeasonDecisionType.MEDIA_OPPORTUNITY })
        val continued = kernel.chooseOffseason(roundTripped, settled.nextSeed, OffseasonDecision.CONTINUE)
        assertEquals(ProCareerPhase.OFFSEASON_INVESTMENT, continued.state.phase)
        val invested = kernel.chooseInvestment(continued.state, continued.nextSeed, ProOffseasonInvestment.NONE, null)
        assertEquals(ProCareerPhase.WEEKLY_PLAN, invested.state.phase)
        assertEquals(roundTripped.season + 1, invested.state.season)
    }

    @Test
    fun nationalTeamCallOpensAfterEvenSeasonWithFanSupport() {
        val started = kernel.startDirect(ProStartDirectRequest("808", "power_prospect", "대표투수"))
        val journey = requireNotNull(started.state.journeyState)
        val reviewed = started.state.copy(
            phase = ProCareerPhase.SEASON_REVIEW,
            season = 2,
            age = 20,
            week = ProCatalog.WEEKS_PER_SEASON,
            seasonSegment = ProCatalog.segment(ProCatalog.WEEKS_PER_SEASON),
            currentStats = started.state.currentStats.copy(season = 2),
            journeyState = journey.copy(reputation = journey.reputation.copy(fanSupport = 70)),
            commitment = "",
        ).let { it.copy(commitment = kernel.commitment(it)) }
        kernel.validateSavedState(reviewed)
        val afterReview = kernel.reviewSeason(reviewed, started.nextSeed)
        assertEquals(ProCareerPhase.SEASON_SETTLEMENT, afterReview.state.phase)
        val settlementId = requireNotNull(afterReview.state.journeyState?.lastSettlement).id
        val after = kernel.acknowledgeSeasonSettlement(afterReview.state, afterReview.nextSeed, settlementId)
        assertEquals(ProCareerPhase.NATIONAL_TEAM_CALL, after.state.phase)
        assertEquals(null, after.state.pendingDecision)
        val declined = kernel.respondToNationalTeamCall(after.state, after.nextSeed, accepted = false)
        assertEquals(ProCareerPhase.OFFSEASON_DECISION, declined.state.phase)
        val fanAtCall = requireNotNull(after.state.journeyState).reputation.fanSupport
        assertEquals(
            (fanAtCall + ProNationalTeamRules.DECLINE_FAN_DELTA).coerceIn(0, 100),
            declined.state.journeyState?.reputation?.fanSupport,
        )
        val roundTripped = ProStateCodec.decode(ProStateCodec.encode(declined.state))
        assertEquals(declined.state, roundTripped)
    }

    @Test
    fun freeAgencyOnRulesVersion10KeepsTheChosenDurationAndSigningBonus() {
        val started = kernel.startDirect(ProStartDirectRequest("909", "power_prospect", "자유투수"))
        val reviewed = started.state.copy(
            phase = ProCareerPhase.SEASON_REVIEW,
            week = ProCatalog.WEEKS_PER_SEASON,
            seasonSegment = ProCatalog.segment(ProCatalog.WEEKS_PER_SEASON),
            commitment = "",
        ).let { it.copy(commitment = kernel.commitment(it)) }
        kernel.validateSavedState(reviewed)
        val afterReview = kernel.reviewSeason(reviewed, started.nextSeed)
        val offseason = kernel.acknowledgeSeasonSettlement(
            afterReview.state,
            afterReview.nextSeed,
            requireNotNull(afterReview.state.journeyState?.lastSettlement).id,
        ).state
        val eligible = offseason.copy(
            serviceYears = 6,
            contract = offseason.contract?.copy(yearsRemaining = 0),
            commitment = "",
        ).let { it.copy(commitment = kernel.commitment(it)) }
        kernel.validateSavedState(eligible)
        val opened = kernel.chooseOffseason(eligible, started.nextSeed, OffseasonDecision.FREE_AGENCY)
        assertEquals(ProCareerPhase.CONTRACT_OFFER, opened.state.phase)
        assertEquals(0, opened.state.contract?.yearsRemaining)
        val market = requireNotNull(opened.state.journeyState?.pendingContractMarket)
        assertEquals(ProContractMarketKind.FREE_AGENCY, market.kind)
        assertEquals(4, market.offers.size)
        val maxOffer = market.offers.maxBy { it.years }
        assertTrue(maxOffer.years in 4..ProCatalog.maximumContractYears(eligible.proRulesVersion))
        assertEquals(4, market.offers.map { it.teamId }.distinct().size)
        assertTrue(market.offers.all { (it.signingBonus ?: 0) > 0 })
        val signed = kernel.acceptContractOffer(opened.state, opened.nextSeed, maxOffer.id, ProCareerAmbition.RECORD_BOOK)
        assertEquals(maxOffer.years, signed.state.contract?.yearsRemaining)
        assertEquals(opened.state.journeyState!!.finances.availableFunds + maxOffer.signingBonus!!, signed.state.journeyState!!.finances.availableFunds)
        assertEquals(ProCareerPhase.OFFSEASON_INVESTMENT, signed.state.phase)
        val invested = kernel.chooseInvestment(signed.state, signed.nextSeed, ProOffseasonInvestment.NONE, null)
        assertEquals(ProCareerPhase.WEEKLY_PLAN, invested.state.phase)
        assertEquals(maxOffer.years, invested.state.contract?.yearsRemaining)
        assertTrue(market.offers.any { it.teamId != eligible.team.id })
    }

    @Test
    fun expiredContractOpensRenewalMarketThenInvestment() {
        val started = kernel.startDirect(ProStartDirectRequest("911", "power_prospect", "재계약투수"))
        val reviewed = started.state.copy(
            phase = ProCareerPhase.SEASON_REVIEW,
            week = ProCatalog.WEEKS_PER_SEASON,
            seasonSegment = ProCatalog.segment(ProCatalog.WEEKS_PER_SEASON),
            commitment = "",
        ).let { it.copy(commitment = kernel.commitment(it)) }
        kernel.validateSavedState(reviewed)
        val afterReview = kernel.reviewSeason(reviewed, started.nextSeed)
        val offseason = kernel.acknowledgeSeasonSettlement(
            afterReview.state,
            afterReview.nextSeed,
            requireNotNull(afterReview.state.journeyState?.lastSettlement).id,
        ).state
        val expired = offseason.copy(
            contract = offseason.contract?.copy(yearsRemaining = 0),
            commitment = "",
        ).let { it.copy(commitment = kernel.commitment(it)) }
        kernel.validateSavedState(expired)
        val opened = kernel.chooseOffseason(expired, started.nextSeed, OffseasonDecision.CONTINUE)
        assertEquals(ProCareerPhase.CONTRACT_OFFER, opened.state.phase)
        val market = requireNotNull(opened.state.journeyState?.pendingContractMarket)
        assertEquals(ProContractMarketKind.RENEWAL, market.kind)
        assertEquals(2, market.offers.size)
        val accepted = kernel.acceptContractOffer(opened.state, opened.nextSeed, market.offers.first().id, ProCareerAmbition.RECORD_BOOK)
        assertEquals(ProCareerPhase.OFFSEASON_INVESTMENT, accepted.state.phase)
        assertEquals(ProOffseasonTransitionRoute.UNDER_CONTRACT, accepted.state.journeyState?.offseasonTransition?.route)
        assertTrue(accepted.state.standings.isNotEmpty())
        val next = kernel.chooseInvestment(accepted.state, accepted.nextSeed, ProOffseasonInvestment.NONE, null)
        assertEquals(ProCareerPhase.WEEKLY_PLAN, next.state.phase)
        assertTrue((next.state.contract?.yearsRemaining ?: 0) >= 1)
        val roundTripped = ProStateCodec.decode(ProStateCodec.encode(next.state))
        assertEquals(next.state, roundTripped)
    }

    @Test
    fun freeAgencyWhileUnderContractIsRejected() {
        val started = kernel.startDirect(ProStartDirectRequest("912", "power_prospect", "잔류투수"))
        val reviewed = started.state.copy(
            phase = ProCareerPhase.SEASON_REVIEW,
            week = ProCatalog.WEEKS_PER_SEASON,
            seasonSegment = ProCatalog.segment(ProCatalog.WEEKS_PER_SEASON),
            commitment = "",
        ).let { it.copy(commitment = kernel.commitment(it)) }
        kernel.validateSavedState(reviewed)
        val afterReview = kernel.reviewSeason(reviewed, started.nextSeed)
        val offseason = kernel.acknowledgeSeasonSettlement(
            afterReview.state,
            afterReview.nextSeed,
            requireNotNull(afterReview.state.journeyState?.lastSettlement).id,
        ).state
        assertTrue((offseason.contract?.yearsRemaining ?: 0) > 0)
        val error = assertFailsWith<ProKernelException> {
            kernel.chooseOffseason(offseason, started.nextSeed, OffseasonDecision.FREE_AGENCY)
        }
        assertEquals("pro.free_agency_ineligible", error.code)
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
        val masteredPitcher = ProCatalog.pitcherForPreset("power_prospect", "숙련투수").copy(
            mastery = AbilityMasterySnapshot(stuff = 5, command = 6, movement = 7, stamina = 8),
        )
        val masteredEnvelope = ProCommandEnvelope(
            commandId = "mastered", sessionId = "linked-session", expectedRevision = 0UL,
            command = ProCommand.StartLinked(
                ProStartLinkedRequest("12", "hs-12", "숙련투수", masteredPitcher, ProCatalog.teams.first().id, 79),
            ),
        )
        assertEquals(masteredEnvelope, ProCommandCodec.decode(ProCommandCodec.encode(masteredEnvelope)))
    }

    @Test
    fun everyProCommandWireRoundTripsThroughTheStrictCanonicalCodec() {
        val call = PitchCall(PitchKind.FOUR_SEAM, PitchZone(1, 1), ZoneIntent.EDGE, PitchIntensity.CONTROLLED)
        val commands = listOf(
            ProCommand.StartLinked(ProStartLinkedRequest("1", "hs-1", "투수", ProCatalog.pitcherForPreset("power_prospect", "투수"), ProCatalog.teams.first().id, 72)),
            ProCommand.StartDirect(ProStartDirectRequest("2", "power_prospect", "투수", "hs-active")),
            ProCommand.SignContract,
            ProCommand.AcceptContractOffer("13", "offer:1", ProCareerAmbition.RECORD_BOOK),
            ProCommand.PlanWeek("3", ProWeekPlan.DEVELOP_STUFF, PitchKind.FOUR_SEAM),
            ProCommand.AdvanceSegment("4", ProWeekPlan.DEVELOP_MOVEMENT, PitchKind.SLIDER, 12),
            ProCommand.ApplySeasonDecision("5", "decision-1", "choice-1"),
            ProCommand.ReserveImportantGame("6"),
            ProCommand.SubmitPitch("pitch-1", call, PitchDelivery(700, 650)),
            ProCommand.FinishImportantGame,
            ProCommand.ReviewSeason("7"),
            ProCommand.AcknowledgeSeasonSettlement("7b", "settlement:1"),
            ProCommand.ChooseOffseason("8", OffseasonDecision.FREE_AGENCY),
            ProCommand.ChooseInvestment("14", ProOffseasonInvestment.PITCH_LAB, ProDevelopmentFocus.COMMAND),
            ProCommand.SelectLegacy("power_imprint"),
            ProCommand.NormalizeBalance,
            ProCommand.RespondNationalTeamCall("9", true),
            ProCommand.StartNationalFinal("10"),
            ProCommand.ResolveNationalFinalAutomatically("11"),
            ProCommand.AcknowledgeNationalTeamResult("12"),
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
    fun perfectReleasesAreRecordedThroughTheProOutingAndSurviveTheCodec() {
        val base = direct("140")
        val forced = base.copy(
            phase = ProCareerPhase.IMPORTANT_GAME,
            week = 1,
            seasonSegment = ProCatalog.segment(1),
            seasonTrigger = ProSeasonTrigger.OPENING_STATEMENT,
            currentRival = ProCatalog.rivalFor(base.team.id, base.season, 1, ProSeasonTrigger.OPENING_STATEMENT),
            commitment = "",
        ).let { it.copy(commitment = kernel.commitment(it)) }
        var state = kernel.reserveImportantGame(forced, "140").state
        var guard = 0
        while (state.activePitch?.ended != true && guard < 80) {
            val session = state.activePitch ?: error("missing pitch session")
            val prep = com.solkim.baseball.core.pitch.PitchKernel().prepare(
                com.solkim.baseball.core.pitch.PitchKernel.PrepareRequest(session.seed, state.pitcher, session.batter, session.scouting, session.context, session.memory, session.game, session.log),
            )
            state = kernel.submitPitch(state, session.sessionId, prep.primaryRecommendation.call, PitchDelivery(1_000, 900)).state
            state = ProStateCodec.decode(ProStateCodec.encode(state))
            guard += 1
        }
        assertTrue(guard < 80)
        val thrown = requireNotNull(state.activePitch).pitches
        assertEquals(thrown, requireNotNull(state.activePitch).perfectReleases, "every 1000 release is perfect")
        state = kernel.finishImportantGame(state).state
        state = ProStateCodec.decode(ProStateCodec.encode(state))
        val line = state.currentGameLines.last { it.played }
        assertEquals(thrown, line.perfectReleases)
        assertEquals(thrown, state.currentStats.perfectReleases)
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
                ProCareerPhase.NATIONAL_TEAM_CALL -> {
                    val result = kernel.respondToNationalTeamCall(state, seed, accepted = true)
                    state = ProStateCodec.decode(ProStateCodec.encode(result.state)); seed = result.nextSeed
                }
                ProCareerPhase.NATIONAL_TOURNAMENT -> {
                    val tournament = state.nationalTournament ?: error("missing national tournament")
                    val result = if (tournament.result != null) {
                        kernel.acknowledgeNationalTeamResult(state, seed)
                    } else {
                        kernel.resolveNationalFinalAutomatically(state, seed)
                    }
                    state = ProStateCodec.decode(ProStateCodec.encode(result.state)); seed = result.nextSeed
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
                ProCareerPhase.SEASON_SETTLEMENT -> {
                    val settlementId = state.journeyState?.lastSettlement?.id ?: error("missing settlement")
                    val result = kernel.acknowledgeSeasonSettlement(state, seed, settlementId)
                    state = ProStateCodec.decode(ProStateCodec.encode(result.state)); seed = result.nextSeed
                }
                ProCareerPhase.OFFSEASON_DECISION -> {
                    val result = kernel.chooseOffseason(state, seed, if (state.season >= ProCatalog.MAXIMUM_CAREER_SEASONS) OffseasonDecision.RETIRE else OffseasonDecision.CONTINUE)
                    state = ProStateCodec.decode(ProStateCodec.encode(result.state)); seed = result.nextSeed
                }
                ProCareerPhase.OFFSEASON_INVESTMENT -> {
                    val result = kernel.chooseInvestment(state, seed, ProOffseasonInvestment.NONE, null)
                    state = ProStateCodec.decode(ProStateCodec.encode(result.state)); seed = result.nextSeed
                }
                ProCareerPhase.RETIREMENT_DECISION -> {
                    val result = kernel.chooseOffseason(state, seed, OffseasonDecision.RETIRE)
                    state = ProStateCodec.decode(ProStateCodec.encode(result.state)); seed = result.nextSeed
                }
                ProCareerPhase.LEGACY_SELECTION -> error("direct career must not open legacy selection")
                ProCareerPhase.CONTRACT_OFFER -> {
                    val offerId = state.journeyState?.pendingContractMarket?.offers?.firstOrNull()?.id
                    val result = if (offerId != null) {
                        kernel.acceptContractOffer(state, seed, offerId, ProCareerAmbition.RECORD_BOOK)
                    } else {
                        kernel.signContract(state, seed)
                    }
                    state = ProStateCodec.decode(ProStateCodec.encode(result.state)); seed = result.nextSeed
                }
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
        assertTrue(state.decisionHistory.all { record ->
            state.decisionHistory.count { it.season == record.season } <= ProCatalog.maximumDecisions(state.proRulesVersion)
        })
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
