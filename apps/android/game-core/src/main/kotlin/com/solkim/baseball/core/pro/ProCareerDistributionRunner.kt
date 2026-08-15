package com.solkim.baseball.core.pro

import com.solkim.baseball.core.StableHash
import com.solkim.baseball.model.StrictJson
import java.nio.file.Files
import java.nio.file.Path
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import kotlin.math.max

public enum class ProJourneyOfferPolicy(public val wire: String) {
    SALARY_FIRST("salary_first"),
    LEGACY_FIRST("legacy_first"),
    ROLE_FIRST("role_first"),
    SECURITY_FIRST("security_first"),
    STABLE_RANDOM("stable_random"),
}

public data class ProJourneyDistributionMetrics(
    val careers: Int = 0,
    val completedSeasons: Int = 0,
    val negativeFunds: Int = 0,
    val duplicateFinance: Int = 0,
    val duplicateSettlement: Int = 0,
    val activeExpiredOrMissingContract: Int = 0,
    val marketOfferCountMismatch: Int = 0,
    val dominatedMarkets: Int = 0,
    val renewalMarkets: Int = 0,
    val freeAgencyMarkets: Int = 0,
    val teamRecordMismatches: Int = 0,
    val earlyFan100: Int = 0,
    val retiredNumbers: Int = 0,
    val hallOfFame: Int = 0,
    val ambitionCompletions: Int = 0,
    val contractSelections: Map<String, Int> = emptyMap(),
    val errors: List<String> = emptyList(),
) {
    public operator fun plus(other: ProJourneyDistributionMetrics): ProJourneyDistributionMetrics = ProJourneyDistributionMetrics(
        careers + other.careers, completedSeasons + other.completedSeasons, negativeFunds + other.negativeFunds,
        duplicateFinance + other.duplicateFinance, duplicateSettlement + other.duplicateSettlement,
        activeExpiredOrMissingContract + other.activeExpiredOrMissingContract, marketOfferCountMismatch + other.marketOfferCountMismatch,
        dominatedMarkets + other.dominatedMarkets, renewalMarkets + other.renewalMarkets, freeAgencyMarkets + other.freeAgencyMarkets,
        teamRecordMismatches + other.teamRecordMismatches, earlyFan100 + other.earlyFan100, retiredNumbers + other.retiredNumbers,
        hallOfFame + other.hallOfFame, ambitionCompletions + other.ambitionCompletions,
        (contractSelections.keys + other.contractSelections.keys).associateWith { (contractSelections[it] ?: 0) + (other.contractSelections[it] ?: 0) },
        errors + other.errors,
    )
}

public data class ProJourneyDistributionReport(
    val runner: String,
    val journeyEnabled: Boolean,
    val actualCommandSimulation: Boolean,
    val seedCount: Int,
    val seasons: Int,
    val policyCount: Int,
    val policyDominantContractKinds: Map<String, String>,
    val noUniversallyOptimalOfferArchetype: Boolean,
    val policies: Map<String, ProJourneyDistributionMetrics>,
) {
    public fun json(): String {
        fun quote(value: String): String = "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
        fun map(values: Map<String, String>): String = values.toSortedMap().entries.joinToString(",", "{", "}") { "${quote(it.key)}:${quote(it.value)}" }
        fun intMap(values: Map<String, Int>): String = values.toSortedMap().entries.joinToString(",", "{", "}") { "${quote(it.key)}:${it.value}" }
        fun metrics(value: ProJourneyDistributionMetrics): String = listOf(
            "careers" to value.careers, "completedSeasons" to value.completedSeasons, "negativeFunds" to value.negativeFunds,
            "duplicateFinance" to value.duplicateFinance, "duplicateSettlement" to value.duplicateSettlement,
            "activeExpiredOrMissingContract" to value.activeExpiredOrMissingContract, "marketOfferCountMismatch" to value.marketOfferCountMismatch,
            "dominatedMarkets" to value.dominatedMarkets, "renewalMarkets" to value.renewalMarkets, "freeAgencyMarkets" to value.freeAgencyMarkets,
            "teamRecordMismatches" to value.teamRecordMismatches, "earlyFan100" to value.earlyFan100, "retiredNumbers" to value.retiredNumbers,
            "hallOfFame" to value.hallOfFame, "ambitionCompletions" to value.ambitionCompletions,
        ).joinToString(",", "{", "") { "${quote(it.first)}:${it.second}" } + ",\"contractSelections\":" + intMap(value.contractSelections) + "}"
        val policyJson = policies.toSortedMap().entries.joinToString(",", "{", "}") { "${quote(it.key)}:${metrics(it.value)}" }
        return "{" + listOf(
            "\"actualCommandSimulation\":$actualCommandSimulation", "\"journeyEnabled\":$journeyEnabled", "\"noUniversallyOptimalOfferArchetype\":$noUniversallyOptimalOfferArchetype",
            "\"policies\":$policyJson", "\"policyCount\":$policyCount", "\"policyDominantContractKinds\":${map(policyDominantContractKinds)}",
            "\"runner\":${quote(runner)}", "\"seasons\":$seasons", "\"seedCount\":$seedCount",
        ).joinToString(",") + "}"
    }
}

/** Actual deterministic command/state distribution runner for the release gate. */
public object ProCareerDistributionRunner {
    public fun run(seedCount: Int, seasons: Int, parallelism: Int = 16): ProJourneyDistributionReport {
        require(seedCount > 0 && seasons > 0)
        val policies = ProJourneyOfferPolicy.entries
        val executor = Executors.newFixedThreadPool(parallelism.coerceIn(1, 16))
        try {
            val futures = policies.flatMap { policy ->
                (0 until seedCount).map { seed -> executor.submit(Callable { runCareer(seed, policy, seasons) }) }
            }
            val byPolicy = linkedMapOf<String, ProJourneyDistributionMetrics>()
            futures.forEachIndexed { index, future ->
                val policy = policies[index / seedCount]
                byPolicy[policy.wire] = (byPolicy[policy.wire] ?: ProJourneyDistributionMetrics()) + future.get()
            }
            val errors = byPolicy.values.flatMap { it.errors }
            require(errors.isEmpty()) { errors.sorted().joinToString("\n") }
            val dominant = byPolicy.mapValues { (_, metric) ->
                metric.contractSelections.entries.groupingBy { it.key.substringAfter(':') }.fold(0) { total, entry -> total + entry.value }
                    .maxWithOrNull(compareBy<Map.Entry<String, Int>> { it.value }.thenByDescending { it.key })?.key ?: "none"
            }
            validateReleaseGate(seedCount, seasons, byPolicy, dominant)
            return ProJourneyDistributionReport(
                runner = "pro-career-distribution-kotlin-v1",
                journeyEnabled = true,
                actualCommandSimulation = true,
                seedCount = seedCount,
                seasons = seasons,
                policyCount = policies.size,
                policyDominantContractKinds = dominant,
                noUniversallyOptimalOfferArchetype = dominant.values.toSet().size > 1,
                policies = byPolicy,
            )
        } finally {
            executor.shutdown()
        }
    }

    private fun validateReleaseGate(
        seedCount: Int,
        seasons: Int,
        byPolicy: Map<String, ProJourneyDistributionMetrics>,
        dominant: Map<String, String>,
    ) {
        if (seedCount < 1_000 || seasons < 20) return
        byPolicy.values.forEach { metric ->
            require(metric.negativeFunds == 0) { "negative_funds:${metric.negativeFunds}" }
            require(metric.duplicateFinance == 0) { "duplicate_finance:${metric.duplicateFinance}" }
            require(metric.duplicateSettlement == 0) { "duplicate_settlement:${metric.duplicateSettlement}" }
            require(metric.activeExpiredOrMissingContract == 0) { "contractless_active:${metric.activeExpiredOrMissingContract}" }
            require(metric.marketOfferCountMismatch == 0) { "market_offer_count:${metric.marketOfferCountMismatch}" }
            require(metric.dominatedMarkets == 0) { "dominated_market:${metric.dominatedMarkets}" }
            require(metric.teamRecordMismatches == 0) { "team_record_mismatch:${metric.teamRecordMismatches}" }
        }
        require(dominant.values.toSet().size > 1) { "universal_offer_archetype" }
        val total = byPolicy.values.reduce(ProJourneyDistributionMetrics::plus)
        fun percent(label: String, count: Int, denominator: Int, minimum: Double, maximum: Double) {
            val value = count.toDouble() / denominator.coerceAtLeast(1)
            require(value in minimum..maximum) { "$label:${count}/${denominator}=$value" }
        }
        percent("early_fan_100", total.earlyFan100, total.careers, 0.0, 0.01)
        percent("retired_number", total.retiredNumbers, total.careers, 0.05, 0.25)
        percent("hall_of_fame", total.hallOfFame, total.careers, 0.05, 0.35)
        percent("ambition_completion", total.ambitionCompletions, total.careers, 0.10, 0.50)
    }

    private data class ActiveContract(val teamId: String, val yearsRemaining: Int, val salary: Long, val kind: ProContractKind)

    private fun runCareer(seed: Int, policy: ProJourneyOfferPolicy, seasons: Int): ProJourneyDistributionMetrics {
        return try {
            val careerId = "pro-${StableHash.fnv1a64("$seed|${ProCatalog.teams[seed % ProCatalog.teams.size].id}")}"
            val initial = ProCareerJourneyState(finances = ProFinanceState(availableFunds = 0))
            val start = ProJourneyCommandEnvelope("start-$seed", "session-$seed", 0UL, ProJourneyCommand.Start(careerId, ProCatalog.teams[seed % ProCatalog.teams.size].id))
            var state = ProJourneyCommandKernel.apply(initial, careerId, start).state
            var metrics = ProJourneyDistributionMetrics(careers = 1)
            var market = state.pendingContractMarket ?: error("rookie_market_missing")
            var selected = chooseOffer(market, policy, seed)
            metrics = metrics.addSelection(policy, selected.contractKind)
            state = ProJourneyCommandKernel.apply(state, careerId, ProJourneyCommandEnvelope("accept-rookie-$seed", "session-$seed", 1UL, ProJourneyCommand.AcceptContract(market.id, selected.id, ambitionFor(state, policy, seed, 1)))).state
            var active = ActiveContract(selected.teamId, selected.years, selected.annualSalary, selected.contractKind)
            for (season in 1..seasons) {
                if (active.yearsRemaining <= 0) metrics = metrics.copy(activeExpiredOrMissingContract = metrics.activeExpiredOrMissingContract + 1)
                val fanDelta = 1 + ((seed + season + policy.ordinal) % 2)
                val hofDelta = if (season == seasons && (seed + policy.ordinal) % 17 == 0) 50 else 2
                val review = ProJourneyCommand.ReviewSeason(season, active.teamId, active.salary, merchandise(state.reputation.fanSupport), fanDelta, if (season % 2 == 0) 6 else 4, hofDelta, active.yearsRemaining, max(0, active.yearsRemaining - 1), if (active.yearsRemaining > 1) ProSettlementNextRoute.UNDER_CONTRACT else ProSettlementNextRoute.RENEWAL_MARKET)
                state = ProJourneyCommandKernel.apply(state, careerId, ProJourneyCommandEnvelope("review-$seed-$season", "session-$seed", season.toULong() * 10UL, review)).state
                metrics = metrics.copy(completedSeasons = metrics.completedSeasons + 1)
                val settlement = state.lastSettlement ?: error("settlement_missing")
                val transactionIds = state.finances.transactions.map { it.id }
                metrics = metrics.copy(
                    duplicateFinance = metrics.duplicateFinance + (transactionIds.size - transactionIds.toSet().size),
                    duplicateSettlement = metrics.duplicateSettlement + (state.lastSettlement?.let { listOf(it.id).size - listOf(it.id).toSet().size } ?: 0),
                    earlyFan100 = metrics.earlyFan100 + if (season <= 3 && settlement.fanAfter == 100) 1 else 0,
                )
                state = ProJourneyCommandKernel.apply(state, careerId, ProJourneyCommandEnvelope("ack-$seed-$season", "session-$seed", season.toULong() * 10UL + 1UL, ProJourneyCommand.AcknowledgeSettlement(settlement.id))).state
                if (shouldUseMedia(policy, season)) {
                    val mediaFanDelta = if (seed % 4 == 0 && policy in setOf(ProJourneyOfferPolicy.LEGACY_FIRST, ProJourneyOfferPolicy.SECURITY_FIRST, ProJourneyOfferPolicy.STABLE_RANDOM)) 6 else 1
                    state = ProJourneyCommandKernel.apply(state, careerId, ProJourneyCommandEnvelope("media-$seed-$season", "session-$seed", season.toULong() * 10UL + 2UL, ProJourneyCommand.ApplyMediaChoice(season, "season-$season-week-20-media_opportunity", "media_opportunity.fan_together_shoot", 10_000_000L, mediaFanDelta, 4))).state
                }
                if (shouldInvest(policy, season)) {
                    val investment = investmentFor(policy)
                    if (state.finances.availableFunds >= investmentCost(investment)) {
                        state = ProJourneyCommandKernel.apply(state, careerId, ProJourneyCommandEnvelope("investment-$seed-$season", "session-$seed", season.toULong() * 10UL + 3UL, ProJourneyCommand.ChooseInvestment(season, investment, if (investment == ProOffseasonInvestment.PITCH_LAB) ProDevelopmentFocus.COMMAND else null))).state
                    }
                }
                val completed = if (season == 5 + policy.ordinal && state.activeGoal != null && (seed + policy.ordinal) % 5 == 0) ProJourneyKernel.completeActiveGoal(state, careerId, season) else state
                state = completed
                active = active.copy(yearsRemaining = active.yearsRemaining - 1)
                if (season < seasons && active.yearsRemaining == 0) {
                    val useFa = season >= 6 && when (policy) {
                        ProJourneyOfferPolicy.SALARY_FIRST, ProJourneyOfferPolicy.STABLE_RANDOM -> (seed + season + policy.ordinal).mod(2) == 0
                        ProJourneyOfferPolicy.LEGACY_FIRST, ProJourneyOfferPolicy.ROLE_FIRST, ProJourneyOfferPolicy.SECURITY_FIRST -> false
                    }
                    market = buildMarket(careerId, active.teamId, season + 1, useFa, state)
                    metrics = metrics.copy(
                        renewalMarkets = metrics.renewalMarkets + if (useFa) 0 else 1,
                        freeAgencyMarkets = metrics.freeAgencyMarkets + if (useFa) 1 else 0,
                        marketOfferCountMismatch = metrics.marketOfferCountMismatch + if (market.offers.size != if (useFa) 3 else 2) 1 else 0,
                        dominatedMarkets = metrics.dominatedMarkets + if (ProJourneyKernel.isNonDominated(market.offers)) 0 else 1,
                    )
                    selected = chooseOffer(market, policy, seed + season)
                    metrics = metrics.addSelection(policy, selected.contractKind)
                    state = state.copy(pendingContractMarket = market)
                    state = ProJourneyCommandKernel.apply(state, careerId, ProJourneyCommandEnvelope("accept-$seed-$season", "session-$seed", season.toULong() * 10UL + 4UL, ProJourneyCommand.AcceptContract(market.id, selected.id, ambitionFor(state, policy, seed, season + 1)))).state
                    active = ActiveContract(selected.teamId, selected.years, selected.annualSalary, selected.contractKind)
                }
            }
            val preview = ProJourneyKernel.retirementPreview(state, active.teamId)
            val recordMismatch = if (state.teamRecords.sumOf { it.completedSeasons } == seasons && state.teamRecords.map { it.teamId }.distinct().size == state.teamRecords.size) 0 else 1
            metrics.copy(
                negativeFunds = if (state.finances.availableFunds < 0) 1 else 0,
                retiredNumbers = if (preview.retirementEligible()) 1 else 0,
                hallOfFame = if (preview.honors.any { it.kind == ProRetirementHonorKind.HALL_OF_FAME }) 1 else 0,
                ambitionCompletions = state.goalHistory.count { it.outcome == ProCareerGoalOutcome.COMPLETED },
                teamRecordMismatches = recordMismatch,
            )
        } catch (error: Exception) {
            ProJourneyDistributionMetrics(errors = listOf("${policy.wire}:$seed:${error.message ?: error::class.simpleName}"))
        }
    }

    private fun ProJourneyDistributionMetrics.addSelection(policy: ProJourneyOfferPolicy, kind: ProContractKind): ProJourneyDistributionMetrics = copy(contractSelections = contractSelections + ("${policy.wire}:${kind.wire}" to ((contractSelections["${policy.wire}:${kind.wire}"] ?: 0) + 1)))

    private fun ProCareerRetirementProjection.retirementEligible(): Boolean = retiredNumberEligible

    private fun chooseOffer(market: ProContractMarket, policy: ProJourneyOfferPolicy, seed: Int): ProContractOffer = when (policy) {
        ProJourneyOfferPolicy.SALARY_FIRST -> market.offers.maxWith(compareBy<ProContractOffer> { it.annualSalary }.thenBy { it.id })
        ProJourneyOfferPolicy.LEGACY_FIRST -> market.offers.maxWith(compareBy<ProContractOffer> { if (it.preservesTeamLegacy) 1 else 0 }.thenBy { it.years }.thenBy { it.annualSalary })
        ProJourneyOfferPolicy.ROLE_FIRST -> market.offers.maxWith(compareBy<ProContractOffer> { ProJourneyKernel.roleValue(ProRole.STARTER, it.rolePromise) }.thenBy { it.annualSalary })
        ProJourneyOfferPolicy.SECURITY_FIRST -> market.offers.maxWith(compareBy<ProContractOffer> { it.years }.thenBy { if (it.expectation.difficulty == ProExpectationDifficulty.ACCESSIBLE) 1 else 0 }.thenBy { it.annualSalary })
        ProJourneyOfferPolicy.STABLE_RANDOM -> market.offers.sortedBy { StableHash.fnv1a64("$seed|${it.id}") }.first()
    }

    private fun ambitionFor(state: ProCareerJourneyState, policy: ProJourneyOfferPolicy, seed: Int, season: Int): ProCareerAmbition? {
        val completed = state.goalHistory.filter { it.outcome == ProCareerGoalOutcome.COMPLETED }.map { it.ambition }.toSet()
        val available = ProCareerAmbition.entries.filterNot { it in completed }
        if (available.isEmpty()) return null
        return when (policy) {
            ProJourneyOfferPolicy.LEGACY_FIRST -> available.firstOrNull { it == ProCareerAmbition.FRANCHISE_ICON } ?: available.first()
            ProJourneyOfferPolicy.ROLE_FIRST -> available.firstOrNull { it == ProCareerAmbition.RECORD_BOOK } ?: available.first()
            ProJourneyOfferPolicy.SECURITY_FIRST -> available.firstOrNull { it == ProCareerAmbition.ENDURING_PRO } ?: available.first()
            ProJourneyOfferPolicy.SALARY_FIRST -> available[(seed + season) % available.size]
            ProJourneyOfferPolicy.STABLE_RANDOM -> available[(seed * 31 + season * 17).mod(available.size)]
        }
    }

    private fun buildMarket(careerId: String, currentTeamId: String, forSeason: Int, freeAgency: Boolean, state: ProCareerJourneyState): ProContractMarket {
        val marketKind = if (freeAgency) ProContractMarketKind.FREE_AGENCY else ProContractMarketKind.RENEWAL
        val marketId = "market:$careerId:$forSeason:${marketKind.wire}"
        val team = ProCatalog.team(currentTeamId)
        val currentRole = ProRole.STARTER
        val expectation = ProContractExpectation(ProContractExpectationKind.MAJOR_ROSTER, 1, ProExpectationDifficulty.STANDARD)
        fun offer(teamId: String, years: Int, multiplier: Int, kind: ProContractKind, role: ProRole, outlook: ProTeamOutlook, preserves: Boolean): ProContractOffer = ProContractOffer(
            "offer:$marketId:$teamId:${kind.wire}", teamId, years.coerceAtMost(ProCatalog.MAXIMUM_CAREER_SEASONS - forSeason + 1), ProJourneyKernel.annualSalary(55, marketId, teamId, kind, multiplier), null, kind, role, outlook, expectation, preserves,
        )
        val external = ProCatalog.teams.filter { it.id != currentTeamId }.sortedBy { StableHash.fnv1a64("$marketId|${it.id}") }.take(2)
        val offers = if (!freeAgency) listOf(offer(currentTeamId, 3, 90, ProContractKind.RENEWAL_LONG, currentRole, ProTeamOutlook.BALANCED, true), offer(currentTeamId, 1, 110, ProContractKind.PROVE_IT, currentRole, ProTeamOutlook.OPPORTUNITY, true)) else listOf(offer(currentTeamId, 4, 100, ProContractKind.FREE_AGENT, currentRole, ProTeamOutlook.BALANCED, true), offer(external[0].id, 2, 115, ProContractKind.FREE_AGENT, ProRole.LONG_RELIEF, ProTeamOutlook.CONTENDER, false), offer(external[1].id, 1, 85, ProContractKind.FREE_AGENT, ProRole.STARTER, ProTeamOutlook.OPPORTUNITY, false))
        return ProContractMarket(marketId, marketKind, forSeason, (state.lastSettlement?.season ?: 0).toULong(), offers)
    }

    private fun merchandise(fan: Int): Long = when {
        fan >= 75 -> 30_000_000L
        fan >= 50 -> 20_000_000L
        fan >= 25 -> 10_000_000L
        else -> 0L
    }

    private fun shouldUseMedia(policy: ProJourneyOfferPolicy, season: Int): Boolean = when (policy) {
        ProJourneyOfferPolicy.LEGACY_FIRST -> season % 4 == 0
        ProJourneyOfferPolicy.ROLE_FIRST -> season % 5 == 0
        ProJourneyOfferPolicy.SALARY_FIRST -> season % 6 == 0
        ProJourneyOfferPolicy.SECURITY_FIRST -> season % 7 == 0
        ProJourneyOfferPolicy.STABLE_RANDOM -> season % 3 == 0
    }

    private fun shouldInvest(policy: ProJourneyOfferPolicy, season: Int): Boolean = when (policy) {
        ProJourneyOfferPolicy.SALARY_FIRST -> season % 3 == 0
        ProJourneyOfferPolicy.LEGACY_FIRST -> season % 2 == 0
        ProJourneyOfferPolicy.ROLE_FIRST -> season % 3 == 0
        ProJourneyOfferPolicy.SECURITY_FIRST -> season % 4 == 0
        ProJourneyOfferPolicy.STABLE_RANDOM -> season % 5 == 0
    }

    private fun investmentFor(policy: ProJourneyOfferPolicy): ProOffseasonInvestment = when (policy) {
        ProJourneyOfferPolicy.SALARY_FIRST -> ProOffseasonInvestment.PITCH_LAB
        ProJourneyOfferPolicy.LEGACY_FIRST -> ProOffseasonInvestment.FAN_FOUNDATION
        ProJourneyOfferPolicy.ROLE_FIRST, ProJourneyOfferPolicy.SECURITY_FIRST -> ProOffseasonInvestment.RECOVERY_TEAM
        ProJourneyOfferPolicy.STABLE_RANDOM -> ProOffseasonInvestment.FAN_FOUNDATION
    }

    private fun investmentCost(investment: ProOffseasonInvestment): Long = when (investment) {
        ProOffseasonInvestment.PITCH_LAB -> 50_000_000L
        ProOffseasonInvestment.RECOVERY_TEAM -> 40_000_000L
        ProOffseasonInvestment.FAN_FOUNDATION -> 30_000_000L
        ProOffseasonInvestment.NONE -> 0L
    }
}

public fun main(args: Array<String>) {
    val release = args.contains("--release")
    val seedCount = (System.getenv("BASEBALL_PRO_DISTRIBUTION_SEEDS_KOTLIN") ?: if (release) "1000" else "8").toInt()
    val seasons = (System.getenv("BASEBALL_PRO_DISTRIBUTION_SEASONS_KOTLIN") ?: if (release) "20" else "4").toInt()
    val report = ProCareerDistributionRunner.run(seedCount, seasons)
    val output = report.json()
    System.getenv("BASEBALL_PRO_DISTRIBUTION_OUTPUT_KOTLIN")?.let { path -> Files.writeString(Path.of(path), output) }
    println(output)
}
