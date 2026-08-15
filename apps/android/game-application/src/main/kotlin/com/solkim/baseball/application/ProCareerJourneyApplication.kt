package com.solkim.baseball.application

import com.solkim.baseball.core.StableHash
import com.solkim.baseball.core.pro.ProCareerAmbition
import com.solkim.baseball.core.pro.ProCareerJourneyState
import com.solkim.baseball.core.pro.ProContractMarket
import com.solkim.baseball.core.pro.ProJourneyCommandCodec
import com.solkim.baseball.core.pro.ProJourneyCommandEnvelope
import com.solkim.baseball.core.pro.ProJourneyCommandKernel
import com.solkim.baseball.core.pro.ProJourneyCommandResult
import com.solkim.baseball.core.pro.ProJourneyKernel
import com.solkim.baseball.core.pro.ProRetirementHonorKind
import com.solkim.baseball.core.pro.ProSettlementNextRoute

/** Production cutover remains disabled until the native shell owns this aggregate. */
public object ProCareerJourneyFeatureGate {
    public const val PRODUCTION_ENABLED: Boolean = false
    public const val FIXTURE_COMPLETE_BOUNDARY: Boolean = true
}

public data class ProCareerJourneyAnalyticsEvent(
    val eventId: String,
    val name: String,
    val scope: String,
    val properties: Map<String, String>,
)

public data class ProCareerJourneyApplicationSnapshot(
    val revision: ULong,
    val state: ProCareerJourneyState,
    val analytics: List<ProCareerJourneyAnalyticsEvent>,
    val productionSurfaceEnabled: Boolean = ProCareerJourneyFeatureGate.PRODUCTION_ENABLED,
    val fixtureCompleteBoundary: Boolean = ProCareerJourneyFeatureGate.FIXTURE_COMPLETE_BOUNDARY,
)

public class ProCareerJourneyOrchestrator(
    private val careerId: String,
    initialState: ProCareerJourneyState,
    initialRevision: ULong = 0UL,
) {
    private var snapshot: ProCareerJourneyApplicationSnapshot = ProCareerJourneyApplicationSnapshot(initialRevision, initialState, emptyList())
    private val commandReceipts = LinkedHashMap<String, ProCareerJourneyApplicationSnapshot>()

    public fun snapshot(): ProCareerJourneyApplicationSnapshot = snapshot

    /** CAS + pure kernel + analytics receipt are committed as one in-memory transition. */
    public fun dispatch(envelope: ProJourneyCommandEnvelope): ProCareerJourneyApplicationSnapshot {
        commandReceipts[envelope.commandId]?.let { return it }
        require(envelope.expectedRevision == snapshot.revision) { "pro.journey.stale_revision" }
        val result: ProJourneyCommandResult = ProJourneyCommandKernel.apply(snapshot.state, careerId, envelope)
        val nextRevision = snapshot.revision + 1UL
        val events = snapshot.analytics + ProCareerJourneyAnalyticsProjector.project(
            careerId = careerId,
            revision = nextRevision,
            command = envelope,
            result = result,
        )
        val next = snapshot.copy(revision = nextRevision, state = result.state, analytics = events)
        snapshot = next
        commandReceipts[envelope.commandId] = next
        return next
    }
}

public object ProCareerJourneyAnalyticsProjector {
    public fun project(
        careerId: String,
        revision: ULong,
        command: ProJourneyCommandEnvelope,
        result: ProJourneyCommandResult,
    ): List<ProCareerJourneyAnalyticsEvent> {
        val scope = "pro:$careerId"
        val base = mapOf("revision" to revision.toString(), "command_id" to command.commandId, "command_hash" to result.commandHash)
        val currentCommand = command.command
        val event = when (currentCommand) {
            is com.solkim.baseball.core.pro.ProJourneyCommand.Start -> event(scope, "pro_contract_market_seen", base + ("market_kind" to "rookie"))
            is com.solkim.baseball.core.pro.ProJourneyCommand.AcceptContract -> event(scope, "pro_contract_accepted", base + ("offer_id" to currentCommand.offerId))
            is com.solkim.baseball.core.pro.ProJourneyCommand.ReviewSeason -> event(scope, "pro_season_settlement_created", base + mapOf("season" to currentCommand.season.toString(), "route" to currentCommand.nextRoute.wire))
            is com.solkim.baseball.core.pro.ProJourneyCommand.AcknowledgeSettlement -> event(scope, "pro_settlement_acknowledged", base + ("settlement_id" to currentCommand.settlementId))
            is com.solkim.baseball.core.pro.ProJourneyCommand.ChooseInvestment -> event(scope, "pro_investment_selected", base + ("investment" to currentCommand.investment.wire))
            is com.solkim.baseball.core.pro.ProJourneyCommand.ApplyMediaChoice -> event(scope, "pro_media_choice_applied", base + mapOf("season" to currentCommand.season.toString(), "choice_id" to currentCommand.choiceId))
            is com.solkim.baseball.core.pro.ProJourneyCommand.Retire -> event(scope, "pro_retirement_recorded", base + ("honor_count" to result.state.retirementHonors.size.toString()))
        }
        return listOf(event)
    }

    private fun event(scope: String, name: String, properties: Map<String, String>): ProCareerJourneyAnalyticsEvent {
        val eventId = StableHash.fnv1a64("$scope|$name|${properties.toSortedMap().entries.joinToString(";")}")
        return ProCareerJourneyAnalyticsEvent(eventId, name, scope, properties)
    }
}

public data class ProContractOfferProjection(
    val offerId: String,
    val teamId: String,
    val years: Int,
    val annualSalary: Long,
    val signingBonus: Long?,
    val roleWire: String,
    val expectationKindWire: String,
    val expectationTarget: Int,
    val expectationDifficultyWire: String,
    val preservesTeamLegacy: Boolean,
)

public data class ProContractMarketProjection(
    val visible: Boolean,
    val marketId: String?,
    val kindWire: String?,
    val forSeason: Int?,
    val offers: List<ProContractOfferProjection>,
    val fixtureCompleteBoundary: Boolean = ProCareerJourneyFeatureGate.FIXTURE_COMPLETE_BOUNDARY,
)

public data class ProSettlementProjection(
    val visible: Boolean,
    val settlementId: String?,
    val season: Int?,
    val salaryIncome: Long,
    val merchandiseIncome: Long,
    val fanBefore: Int,
    val fanAfter: Int,
    val teamLegacyBefore: Int,
    val teamLegacyAfter: Int,
    val hallOfFameBefore: Int,
    val hallOfFameAfter: Int,
    val contractYearsBefore: Int,
    val contractYearsAfter: Int,
    val nextRouteWire: String?,
)

public data class ProInvestmentProjection(
    val availableFunds: Long,
    val selectedSeason: Int?,
    val activeBenefitWire: String?,
    val investmentTransactionIds: List<String>,
)

public data class ProRetirementProjection(
    val finalScore: Int,
    val lastTeamId: String?,
    val lastTeamSeasons: Int,
    val lastTeamLegacy: Int,
    val fanSupport: Int,
    val retiredNumberEligible: Boolean,
    val clubHallTeamIds: List<String>,
    val completedAmbitionWires: List<String>,
    val honorWires: List<String>,
)

/** Read-only application projections. All calculations remain in ProJourneyKernel. */
public object ProCareerJourneyProjector {
    public fun contractMarket(state: ProCareerJourneyState): ProContractMarketProjection {
        val market: ProContractMarket = state.pendingContractMarket ?: return ProContractMarketProjection(false, null, null, null, emptyList())
        return ProContractMarketProjection(
            visible = true,
            marketId = market.id,
            kindWire = market.kind.wire,
            forSeason = market.forSeason,
            offers = market.offers.map { offer ->
                ProContractOfferProjection(offer.id, offer.teamId, offer.years, offer.annualSalary, offer.signingBonus, offer.rolePromise.wire, offer.expectation.kind.wire, offer.expectation.target, offer.expectation.difficulty.wire, offer.preservesTeamLegacy)
            },
        )
    }

    public fun settlement(state: ProCareerJourneyState): ProSettlementProjection {
        val value = state.lastSettlement ?: return ProSettlementProjection(false, null, null, 0, 0, state.reputation.fanSupport, state.reputation.fanSupport, 0, 0, 0, 0, 0, 0, null)
        return ProSettlementProjection(true, value.id, value.season, value.salaryIncome, value.merchandiseIncome, value.fanBefore, value.fanAfter, value.teamLegacyBefore, value.teamLegacyAfter, value.hallOfFameBefore, value.hallOfFameAfter, value.contractYearsBefore, value.contractYearsAfter, value.nextRoute.wire)
    }

    public fun investment(state: ProCareerJourneyState): ProInvestmentProjection = ProInvestmentProjection(
        availableFunds = state.finances.availableFunds,
        selectedSeason = state.finances.investmentSeason,
        activeBenefitWire = state.activeSeasonBenefit?.kind?.wire,
        investmentTransactionIds = state.finances.transactions.filter { it.kind == com.solkim.baseball.core.pro.ProFinanceTransactionKind.INVESTMENT }.map { it.id },
    )

    public fun retirement(state: ProCareerJourneyState, lastTeamId: String?): ProRetirementProjection {
        val value = ProJourneyKernel.retirementPreview(state, lastTeamId)
        return ProRetirementProjection(value.finalScore, value.lastTeamId, value.lastTeamSeasons, value.lastTeamLegacy, value.fanSupport, value.retiredNumberEligible, value.clubHallTeamIds, value.completedAmbitions.map(ProCareerAmbition::wire), value.honors.map { it.kind.wire })
    }
}
