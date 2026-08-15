package com.solkim.baseball.application

import com.solkim.baseball.core.pro.ProCareerAmbition
import com.solkim.baseball.core.pro.ProCareerJourneyState
import com.solkim.baseball.core.pro.ProFinanceTransactionKind
import com.solkim.baseball.core.pro.ProJourneyCommand
import com.solkim.baseball.core.pro.ProJourneyCommandEnvelope
import com.solkim.baseball.core.pro.ProOffseasonInvestment
import com.solkim.baseball.core.pro.ProDevelopmentFocus
import com.solkim.baseball.core.pro.ProSettlementNextRoute
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ProCareerJourneyApplicationTest {
    @Test
    fun orchestratorCommitsCommandAnalyticsAndExactOnceReceiptsAtomically() {
        val orchestrator = ProCareerJourneyOrchestrator("career-app", ProCareerJourneyState())
        val start = ProJourneyCommandEnvelope("start", "session", 0UL, ProJourneyCommand.Start("career-app", "busan_marines"))
        val started = orchestrator.dispatch(start)
        assertEquals(started, orchestrator.dispatch(start))
        assertEquals(1UL, started.revision)
        assertEquals("pro_contract_market_seen", started.analytics.single().name)

        val market = started.state.pendingContractMarket!!
        val accepted = orchestrator.dispatch(ProJourneyCommandEnvelope("accept", "session", started.revision, ProJourneyCommand.AcceptContract(market.id, market.offers.single().id, ProCareerAmbition.RECORD_BOOK)))
        val settled = orchestrator.dispatch(ProJourneyCommandEnvelope("review", "session", accepted.revision, ProJourneyCommand.ReviewSeason(1, "busan_marines", 60_000_000L, 10_000_000L, 9, 14, 11, 3, 2, ProSettlementNextRoute.UNDER_CONTRACT)))
        val ack = orchestrator.dispatch(ProJourneyCommandEnvelope("ack", "session", settled.revision, ProJourneyCommand.AcknowledgeSettlement(settled.state.lastSettlement!!.id)))
        val invested = orchestrator.dispatch(ProJourneyCommandEnvelope("investment", "session", ack.revision, ProJourneyCommand.ChooseInvestment(2, ProOffseasonInvestment.PITCH_LAB, ProDevelopmentFocus.COMMAND)))
        assertEquals(140_000_000L, invested.state.finances.availableFunds)
        assertEquals(1, invested.state.finances.transactions.count { it.kind == ProFinanceTransactionKind.SALARY })
        assertEquals(1, invested.state.finances.transactions.count { it.kind == ProFinanceTransactionKind.INVESTMENT })
        assertEquals(5, invested.analytics.size)
        assertTrue(invested.analytics.map { it.name }.contains("pro_investment_selected"))
        assertFalse(invested.productionSurfaceEnabled)
        assertTrue(invested.fixtureCompleteBoundary)
    }

    @Test
    fun staleRevisionCannotPartiallyCommit() {
        val orchestrator = ProCareerJourneyOrchestrator("career-app", ProCareerJourneyState())
        val start = ProJourneyCommandEnvelope("start", "session", 0UL, ProJourneyCommand.Start("career-app", "busan_marines"))
        orchestrator.dispatch(start)
        val before = orchestrator.snapshot()
        assertFailsWith<IllegalArgumentException> {
            orchestrator.dispatch(ProJourneyCommandEnvelope("stale", "session", 0UL, ProJourneyCommand.Start("career-app", "busan_marines")))
        }
        assertEquals(before, orchestrator.snapshot())
    }
}
