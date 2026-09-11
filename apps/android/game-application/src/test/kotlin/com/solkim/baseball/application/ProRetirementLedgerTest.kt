package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.core.pro.*
import kotlin.test.*

class ProRetirementLedgerTest {
    private val kernel = ProKernel()
    private fun retired(): ProState {
        val started = kernel.startDirect(ProStartDirectRequest("817711", "power_prospect", "민서준")).state
        val review = started.copy(phase = ProCareerPhase.SEASON_REVIEW, week = 24,
            seasonSegment = ProCatalog.segment(24), commitment = "")
        val signed = review.copy(commitment = kernel.commitment(review))
        var season = kernel.reviewSeason(signed, signed.seed)
        if (season.state.phase == ProCareerPhase.SEASON_SETTLEMENT) season = kernel.acknowledgeSeasonSettlement(
            season.state, season.nextSeed, season.state.journeyState!!.lastSettlement!!.id)
        val store = ProCommandStore(initialState = season.state)
        val ending = store.dispatch(ProCommandEnvelope(commandId = "retire", sessionId = "ledger-test",
            expectedRevision = season.state.revision, command = ProCommand.ChooseOffseason(season.nextSeed, OffseasonDecision.RETIRE))).state
        if (ending.phase == ProCareerPhase.COMPLETED) return ending
        return store.dispatch(ProCommandEnvelope(commandId = "choose-legacy", sessionId = "ledger-test",
            expectedRevision = ending.revision, command = ProCommand.SelectLegacy(ending.legacyCandidates.first().id))).state
    }
    private fun signed(state: GameAggregateState): GameAggregateState = state.copy(commitment = state.recomputeCommitment())

    @Test fun retirementIsCreditedOnceAndItsPlayerRecordSurvivesTheCodec() {
        val pro = retired()
        val original = signed(GameAggregateState.initial("retirement").copy(stage = GameStage.BETWEEN_LIVES, pro = pro))
        val settled = signed(ProRetirementLedger.settle(original))
        assertEquals(ProRetirementLedger.soulBonus(pro), settled.meta.standaloneSoulBalance)
        assertNull(settled.highSchool, "Standalone Pro must not fabricate a high-school archive")
        val record = settled.meta.retiredProCareers.single()
        assertEquals(pro, record.copy(commandReceipts = pro.commandReceipts, commitment = pro.commitment))
        assertTrue(record.commandReceipts.isEmpty())
        val restored = GameAggregateCodec.decodePayload(GameAggregateCodec.encodePayload(settled))
        assertEquals(settled, restored)
        assertEquals(restored, ProRetirementLedger.settle(restored))
        assertTrue(restored.canEnterPlayerSetup())
    }

    @Test fun standaloneRewardDoesNotAlterAnActiveHighSchoolPlayer() {
        val highSchool = HighSchoolPhase4Kernel().start(HighSchoolPhase4StartRequest("817712", "power_prospect", "retirement-hs", "2026-W36", "2026-09-05")).state
        val original = GameAggregateState.initial("retirement-hs").copy(pro = retired(), highSchool = highSchool, stage = GameStage.BETWEEN_LIVES)
        val settled = ProRetirementLedger.settle(original)
        assertEquals(highSchool.run, settled.highSchool!!.run)
        assertEquals(highSchool.archive, settled.highSchool!!.archive)
        assertEquals(highSchool.inheritance.automaticSoulEarned, settled.highSchool!!.inheritance.automaticSoulEarned)
        assertTrue(settled.highSchool!!.inheritance.soulPoints > highSchool.inheritance.soulPoints)
        assertEquals(GameStage.HIGH_SCHOOL, settled.stage)
        assertEquals(ScreenId.P003_PROLOGUE, ScreenProjection.preferredScreen(settled))
    }

    @Test fun walletOnlyInheritanceCannotTurnUnspentCurrencyIntoFreeRatings() {
        val request = HighSchoolPhase4StartRequest("817713", "power_prospect", "wallet-only", "2026-W36", "2026-09-05")
        val base = HighSchoolPhase4Kernel().start(request).state
        val rewarded = HighSchoolPhase4Kernel().start(request.copy(inheritedSoulPoints = 240, inheritedSoulTotal = 0)).state
        assertEquals(base.run.pitcher, rewarded.run.pitcher)
        assertEquals(240, rewarded.inheritance.soulPoints)
        assertEquals(0, rewarded.inheritance.automaticSoulEarned)
    }

    @Test fun sourceRewardFormulaAlsoRecognizesInningsAndDecisions() {
        val base = retired()
        val line = base.currentStats.copy(strikeouts = 30, inningsOuts = 300, wins = 20, saves = 10)
        val pro = base.copy(careerStats = listOf(line), awards = listOf("award-a", "award-b"), hallOfFameScore = 40)
        // max(30 K, 100 innings, 30 decisions * 4) = 120 equivalent achievements.
        assertEquals(63, ProRetirementLedger.soulBonus(pro))
    }
}
