package com.solkim.baseball.feature.career

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.ProCareerJourneyApplicationSnapshot
import com.solkim.baseball.application.ProCareerJourneyProjector
import java.text.NumberFormat
import java.util.Locale

/**
 * Fixture-complete Compose boundary. The production flag is intentionally visible in the
 * contract and this surface never presents an unfinished aggregate as a production feature.
 */
@Composable
public fun ProCareerJourneySurface(
    snapshot: ProCareerJourneyApplicationSnapshot,
    lastTeamId: String?,
    onRetirementPreview: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val market = ProCareerJourneyProjector.contractMarket(snapshot.state)
    val settlement = ProCareerJourneyProjector.settlement(snapshot.state)
    val investment = ProCareerJourneyProjector.investment(snapshot.state)
    val retirement = ProCareerJourneyProjector.retirement(snapshot.state, lastTeamId)
    Column(modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (!snapshot.productionSurfaceEnabled && snapshot.fixtureCompleteBoundary) {
            Text(stringResource(R.string.pro_career_fixture_boundary), style = MaterialTheme.typography.labelSmall)
        }
        if (market.visible) ProContractMarketScreen(market, Modifier.fillMaxWidth())
        if (settlement.visible) ProSettlementScreen(settlement, Modifier.fillMaxWidth())
        ProInvestmentScreen(investment, Modifier.fillMaxWidth())
        ProRetirementScreen(retirement, onRetirementPreview, Modifier.fillMaxWidth())
    }
}

@Composable
public fun ProContractMarketScreen(
    market: com.solkim.baseball.application.ProContractMarketProjection,
    modifier: Modifier = Modifier,
) {
    Card(modifier.semantics { contentDescription = "pro.career.contract.market" }) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(stringResource(R.string.pro_career_contract), style = MaterialTheme.typography.titleMedium)
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(market.offers, key = { it.offerId }) { offer ->
                    Column(Modifier.semantics { contentDescription = "pro.career.offer.${offer.offerId}" }) {
                        Text("${stringResource(R.string.pro_career_team)} ${offer.teamId}")
                        Text(stringResource(R.string.pro_career_years, offer.years))
                        Text(stringResource(R.string.pro_career_salary, money(offer.annualSalary)))
                        offer.signingBonus?.let { Text(stringResource(R.string.pro_career_signing_bonus, money(it))) }
                        Text("${offer.roleWire} · ${offer.expectationKindWire} ${offer.expectationTarget} · ${offer.expectationDifficultyWire}")
                    }
                }
            }
        }
    }
}

@Composable
public fun ProSettlementScreen(
    settlement: com.solkim.baseball.application.ProSettlementProjection,
    modifier: Modifier = Modifier,
) {
    Card(modifier.semantics { contentDescription = "pro.career.settlement" }) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(stringResource(R.string.pro_career_settlement), style = MaterialTheme.typography.titleMedium)
            Text(stringResource(R.string.pro_career_salary, money(settlement.salaryIncome)))
            Text(stringResource(R.string.pro_career_fan, settlement.fanBefore, settlement.fanAfter))
            Text(stringResource(R.string.pro_career_legacy, settlement.teamLegacyBefore, settlement.teamLegacyAfter))
            Text(stringResource(R.string.pro_career_hof, settlement.hallOfFameBefore, settlement.hallOfFameAfter))
        }
    }
}

@Composable
public fun ProInvestmentScreen(
    investment: com.solkim.baseball.application.ProInvestmentProjection,
    modifier: Modifier = Modifier,
) {
    Card(modifier.semantics { contentDescription = "pro.career.investment" }) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(stringResource(R.string.pro_career_investment), style = MaterialTheme.typography.titleMedium)
            Text(stringResource(R.string.pro_career_funds, money(investment.availableFunds)))
            investment.activeBenefitWire?.let { Text(it) }
        }
    }
}

@Composable
public fun ProRetirementScreen(
    retirement: com.solkim.baseball.application.ProRetirementProjection,
    onPreview: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Card(modifier.semantics { contentDescription = "pro.career.retirement" }) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(stringResource(R.string.pro_career_retirement), style = MaterialTheme.typography.titleMedium)
            Text("${retirement.lastTeamId.orEmpty()} · ${retirement.lastTeamSeasons} · ${retirement.lastTeamLegacy}")
            Text("${retirement.fanSupport} · ${retirement.finalScore}")
            Text(retirement.honorWires.joinToString(","))
            Button(onClick = onPreview, modifier = Modifier.semantics { contentDescription = "pro.career.retirement.preview" }) {
                Text(stringResource(R.string.pro_career_retire_action))
            }
        }
    }
}

private fun money(value: Long): String = NumberFormat.getIntegerInstance(Locale.getDefault()).format(value)
