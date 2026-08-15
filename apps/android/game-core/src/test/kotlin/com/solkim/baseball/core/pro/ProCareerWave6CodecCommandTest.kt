package com.solkim.baseball.core.pro

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

class ProCareerWave6CodecCommandTest {
    @Test
    fun journeyStateV2RoundTripsAndRejectsFutureOrMalformedWire() {
        val market = ProJourneyKernel.rookieMarket("career-1", "busan_marines", 0UL)
        val state = ProCareerJourneyState(
            pendingContractMarket = market,
            finances = ProFinanceState(availableFunds = 120_000_000L),
            reputation = ProReputationState(fanSupport = 20),
        )
        val encoded = ProJourneyStateCodec.encode(state)
        assertTrue(encoded.contentEquals(ProJourneyStateCodec.encode(state)))
        assertEquals(state, ProJourneyStateCodec.decode(encoded))
        val future = String(encoded).replace("\"schemaVersion\":2", "\"schemaVersion\":3")
        assertFailsWith<IllegalArgumentException> { ProJourneyStateCodec.decode(future.toByteArray()) }
        val unknown = String(encoded).replace("\"schema\":\"baseball-pro-career-journey-state-v2\"", "\"unknown\":true,\"schema\":\"baseball-pro-career-journey-state-v2\"")
        assertFailsWith<IllegalArgumentException> { ProJourneyStateCodec.decode(unknown.toByteArray()) }
    }

    @Test
    fun v1LegacySaveUpgradesAtStableBoundaryAndDurablyReloads() {
        val legacy = ProKernel().startDirect(ProStartDirectRequest("620007", "power_prospect", "legacy" )).state
        assertEquals(ProCareerPhase.WEEKLY_PLAN, legacy.phase)
        val v1 = ProStateCodec.encode(legacy)
        val upgraded = ProStateCodecV2.decodeAndMigrate(v1)
        assertNotEquals(null, upgraded.journeyState)
        assertEquals(ProJourneyMigrationSource.LEGACY_SAFE_BOUNDARY, upgraded.journeyState!!.migration.source)
        assertTrue(upgraded.journeyState!!.migration.financeNoticePending)
        val v2 = ProStateCodecV2.encode(upgraded)
        assertEquals(upgraded, ProStateCodecV2.decode(v2))
        assertEquals(upgraded, ProStateCodecV2.decodeAndMigrate(v2))
    }

    @Test
    fun commandsHaveStableWireAndPureKernelUsesExactTransactionIds() {
        val state = ProCareerJourneyState(finances = ProFinanceState(availableFunds = 0L))
        val start = ProJourneyCommandEnvelope("start", "session", 0UL, ProJourneyCommand.Start("career-2", "busan_marines"))
        val started = ProJourneyCommandKernel.apply(state, "career-2", start).state
        val market = started.pendingContractMarket!!
        val accept = ProJourneyCommandEnvelope("accept", "session", 1UL, ProJourneyCommand.AcceptContract(market.id, market.offers.single().id, ProCareerAmbition.RECORD_BOOK))
        val accepted = ProJourneyCommandKernel.apply(started, "career-2", accept).state
        val review = ProJourneyCommandEnvelope("review", "session", 2UL, ProJourneyCommand.ReviewSeason(1, "busan_marines", 60_000_000L, 10_000_000L, 9, 14, 11, 3, 2, ProSettlementNextRoute.UNDER_CONTRACT))
        val settled = ProJourneyCommandKernel.apply(accepted, "career-2", review).state
        assertEquals(190_000_000L, settled.finances.availableFunds)
        assertEquals(1, settled.finances.transactions.count { it.kind == ProFinanceTransactionKind.SALARY })
        val investment = ProJourneyCommandEnvelope("investment", "session", 3UL, ProJourneyCommand.ChooseInvestment(2, ProOffseasonInvestment.PITCH_LAB, ProDevelopmentFocus.COMMAND))
        val invested = ProJourneyCommandKernel.apply(settled, "career-2", investment).state
        assertEquals(140_000_000L, invested.finances.availableFunds)
        assertEquals(1, invested.finances.transactions.count { it.kind == ProFinanceTransactionKind.INVESTMENT })
        val media = ProJourneyCommandEnvelope("media", "session", 4UL, ProJourneyCommand.ApplyMediaChoice(1, "season-1-week-20-media_opportunity", "media_opportunity.fan_together_shoot", 10_000_000L, 4, 6))
        val endorsed = ProJourneyCommandKernel.apply(invested, "career-2", media).state
        assertEquals(150_000_000L, endorsed.finances.availableFunds)
        assertEquals(1, endorsed.finances.transactions.count { it.kind == ProFinanceTransactionKind.ENDORSEMENT })
        assertFailsWith<IllegalArgumentException> { ProJourneyCommandKernel.apply(endorsed, "career-2", media) }

        val command = ProJourneyCommandEnvelope("wire", "session", 0UL, ProJourneyCommand.Retire(null))
        assertEquals(command, ProJourneyCommandCodec.decode(ProJourneyCommandCodec.encode(command)))
        val future = String(ProJourneyCommandCodec.encode(command)).replace("\"schemaVersion\":2", "\"schemaVersion\":3")
        assertFailsWith<ProJourneyCommandException> { ProJourneyCommandCodec.decode(future.toByteArray()) }
    }
}
