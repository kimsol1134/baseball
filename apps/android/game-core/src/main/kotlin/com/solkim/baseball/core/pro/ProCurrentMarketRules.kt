package com.solkim.baseball.core.pro

import com.solkim.baseball.core.StableHash

/** Current Swift contract market inputs. No random generator is consumed by an offer. */
public object ProCurrentMarketRules {
    public fun goalProgress(state: ProState, goal: ProCareerGoalState): ProCareerGoalProgress {
        val row = records(state).firstOrNull { it.teamId == goal.anchorTeamId }
        val currentSeason = if ((state.currentStats.games > 0 || state.currentStats.inningsOuts > 0) && state.careerStats.none { it.season == state.currentStats.season && it.teamId == state.currentStats.teamId }) 1 else 0
        val metrics = when (goal.ambition) {
            ProCareerAmbition.FRANCHISE_ICON -> listOf(
                ProCareerGoalMetric(ProCareerGoalMetricKind.ANCHOR_TEAM_SEASONS, row?.completedSeasons ?: 0, 8),
                ProCareerGoalMetric(ProCareerGoalMetricKind.ANCHOR_TEAM_LEGACY, row?.let { ProTeamLegacyRules.score(it, state.journeyState?.rulesVersion ?: 1) } ?: 0, 80))
            ProCareerAmbition.RECORD_BOOK -> listOf(
                ProCareerGoalMetric(ProCareerGoalMetricKind.HALL_OF_FAME_PROJECTION, ProKernel().hallOfFameProjection(state), 70),
                ProCareerGoalMetric(ProCareerGoalMetricKind.AWARDS, awardCount(state), 3))
            ProCareerAmbition.ENDURING_PRO -> listOf(
                ProCareerGoalMetric(ProCareerGoalMetricKind.PRO_SEASONS, state.careerStats.size + currentSeason, 12),
                ProCareerGoalMetric(ProCareerGoalMetricKind.MAJOR_SERVICE_YEARS, state.serviceYears + if (state.level == ProLevel.MAJOR) currentSeason else 0, 8))
        }
        return ProCareerGoalProgress(goal.ambition, metrics, goal.completedSeason != null || metrics.all { it.current >= it.target })
    }
    public fun awardCount(state: ProState): Int {
        val typed = state.journeyState?.recognitions.orEmpty().filter { it.kind == ProCareerRecognitionKind.AWARD && it.contentId in ProCareerRecognitionRules.recognizedTeamAwards }
        return typed.size + state.awards.count { raw -> typed.none { raw == it.id || raw == ProCareerRecognitionRules.awardLabel(it.contentId, it.season) } }
    }
    public fun records(state: ProState, seasons: List<ProSeasonStats> = state.careerStats): List<ProTeamCareerRecord> {
        val previous = state.journeyState?.teamRecords.orEmpty().associateBy { it.teamId }
        val groups = seasons.groupBy { it.teamId }
        return (previous.keys + groups.keys).sorted().map { team ->
            val rows = groups[team].orEmpty().sortedBy { it.season }.distinctBy { it.season }
            if (rows.isEmpty()) previous.getValue(team) else {
                var consecutive = 0; var last = -2
                rows.forEach { consecutive = if (it.season == last + 1) consecutive + 1 else 1; last = it.season }
                ProTeamCareerRecord(team, rows.size, consecutive, rows.sumOf { it.games }, rows.sumOf { it.starts }, rows.sumOf { it.inningsOuts },
                    rows.sumOf { it.strikeouts }, rows.sumOf { it.wins }, rows.sumOf { it.saves },
                    rows.sumOf { season -> (ProCareerRecognitionRules.awardContentIDs(season, state.journeyState?.rulesVersion ?: 1) + state.journeyState?.recognitions.orEmpty().filter { it.season == season.season && it.teamId == team && it.kind == ProCareerRecognitionKind.AWARD && it.contentId in ProCareerRecognitionRules.recognizedTeamAwards }.map { it.contentId }).distinct().size }, previous[team]?.communityPoints ?: 0, rows.last().season)
            }
        }
    }
    public fun marketScore(state: ProState): Int {
        val journey = requireNotNull(state.journeyState)
        val age = state.age + (journey.offseasonTransition?.ageAdvanceYears ?: 0)
        val p = state.pitcher
        val firstDecline = if (age >= 31) 1 else 0
        val secondDecline = if (age >= 34) 1 else 0
        val rating = ((p.stuff - firstDecline).coerceAtLeast(20) * 3 + (p.command - secondDecline).coerceAtLeast(20) * 3 +
            (p.movement - firstDecline).coerceAtLeast(20) * 2 + (p.stamina - secondDecline).coerceAtLeast(20) * 2) / 10
        val stats = state.careerStats.filter { it.teamId == state.team.id }.maxByOrNull { it.season } ?: state.currentStats
        val ra9 = if (stats.inningsOuts < 60) 50 else ((6000 - stats.runPerNinePermille) / 40).coerceIn(0, 100)
        val workload = (stats.inningsOuts * 100 / 360).coerceIn(0, 100)
        val command = ((stats.strikeouts - stats.walks).coerceAtLeast(0) * 100 / stats.strikeouts.coerceAtLeast(1)).coerceIn(0, 100)
        val performance = (ra9 * 45 + workload * 30 + command * 25) / 100
        val standing = records(state).firstOrNull { it.teamId == state.team.id }?.let {
            when(ProTeamLegacyRules.tier(it, journey.rulesVersion)) {
                ProTeamLegacyTier.NEW_FACE -> 20; ProTeamLegacyTier.SUPPORTING_PILLAR -> 40; ProTeamLegacyTier.CORE_PLAYER -> 60
                ProTeamLegacyTier.CLUB_ACE -> 80; else -> 90
            }
        } ?: 20
        val expired = journey.contractHistory.filter { it.endReason == ProContractEndReason.EXPIRED }.maxByOrNull { it.endedSeason ?: it.signedSeason }
        val adjustment = if (expired?.expectation != null && expired.coveredSeasons.isNotEmpty()) {
            val rate = expired.fulfilledExpectationSeasons.distinct().size * 100 / expired.coveredSeasons.distinct().size
            if (rate >= 75) 5 else if (rate >= 50) 0 else -3
        } else 0
        return (((rating - 35) * 2).coerceIn(0, 100) * 35 + performance * 30 + standing * 15 +
            (if (age <= 30) 100 else (100 - (age - 30) * 8).coerceAtLeast(40)) * 10 + journey.reputation.fanSupport.coerceIn(0, 100) * 10).div(100).plus(adjustment).coerceIn(0, 100)
    }
    public fun expectation(state: ProState, kind: ProContractKind, role: ProRole, outlook: ProTeamOutlook): ProContractExpectation {
        val stats = state.currentStats
        var type = ProContractExpectationKind.MAJOR_ROSTER
        var target = 1
        var minimum = 1; var maximum = 1
        if (state.level == ProLevel.MAJOR) when(role) {
            ProRole.STARTER -> { type = ProContractExpectationKind.INNINGS; minimum = 240; maximum = 420; target = stats.inningsOuts * 90 / 100 }
            ProRole.LONG_RELIEF -> { type = ProContractExpectationKind.INNINGS; minimum = 120; maximum = 240; target = stats.inningsOuts * 90 / 100 }
            ProRole.SETUP -> { type = ProContractExpectationKind.STRIKEOUTS; minimum = 35; maximum = 80; target = stats.strikeouts * 90 / 100 }
            ProRole.CLOSER -> { type = ProContractExpectationKind.SAVES; minimum = 12; maximum = 30; target = stats.saves * 90 / 100 }
        }
        target = target.coerceIn(minimum, maximum)
        if (outlook == ProTeamOutlook.CONTENDER && stats.inningsOuts >= 60) {
            type = ProContractExpectationKind.RUN_PREVENTION; minimum = 3500; maximum = 5000; target = stats.runPerNinePermille.coerceIn(minimum, maximum)
        }
        val difficulty = if (kind == ProContractKind.PROVE_IT || outlook == ProTeamOutlook.CONTENDER) ProExpectationDifficulty.STRETCH
            else if (kind == ProContractKind.RENEWAL_LONG || outlook == ProTeamOutlook.OPPORTUNITY) ProExpectationDifficulty.ACCESSIBLE else ProExpectationDifficulty.STANDARD
        val multiplier = if (difficulty == ProExpectationDifficulty.STANDARD) 100 else if ((difficulty == ProExpectationDifficulty.STRETCH) == (type == ProContractExpectationKind.RUN_PREVENTION)) 90 else 110
        return ProContractExpectation(type, (target * multiplier / 100).coerceIn(minimum, maximum), difficulty)
    }
    private fun nonDominated(offers: List<ProContractOffer>, role: ProRole): Boolean {
        fun axes(o: ProContractOffer) = listOf(o.annualSalary, o.years.toLong(), ProJourneyKernel.roleValue(role, o.rolePromise).toLong(),
            if (o.preservesTeamLegacy) 2L else if (o.outlook == ProTeamOutlook.OPPORTUNITY) 1L else 0L,
            when(o.expectation.difficulty) { ProExpectationDifficulty.ACCESSIBLE -> 2L; ProExpectationDifficulty.STANDARD -> 1L; else -> 0L }, o.signingBonus ?: 0)
        return offers.indices.none { a -> offers.indices.any { b -> a != b && axes(offers[a]).zip(axes(offers[b])).let { pairs -> pairs.all { it.first >= it.second } && pairs.any { it.first > it.second } } } }
    }
    public fun freeAgency(state: ProState): ProContractMarket {
        val marketId = "market:${state.careerId}:${state.season + 1}:free_agency"
        fun hash(text: String) = StableHash.fnv1a64(text).toULong(16)
        fun choose(values: List<Int>, key: String, team: String, attempt: Int) = values[(hash("$marketId|$team|$key|attempt:$attempt") % values.size.toULong()).toInt()]
        val ranked = ProCatalog.teams.filter { it.id != state.team.id }.sortedWith(compareByDescending<ProTeam> {
            it.demand.toLong() * 1000 + (hash("$marketId|${it.id}|candidate") % 1000UL).toLong()
        }.thenBy { it.id })
        val slots = ranked.take(3).sortedWith(compareByDescending<ProTeam> {
            it.demand.coerceIn(0, 100) * 2 + (hash("${it.id}|${state.season + 1}|${it.demand.coerceIn(0, 100)}") % 101UL).toInt()
        }.thenBy { it.id })
        val teams = listOf(state.team, slots[0], slots[2], slots[1])
        val legacy = records(state).firstOrNull { it.teamId == state.team.id }?.let { ProTeamLegacyRules.score(it, state.journeyState!!.rulesVersion) } ?: 0
        val yearPools = listOf(if (legacy >= 65) listOf(3, 4, 5) else listOf(3, 4), listOf(2, 3), listOf(1, 2), listOf(4, 5))
        val multiplierPools = listOf(listOf(90, 95, 100), listOf(105, 110, 115), listOf(80, 85, 90, 95), listOf(85, 90, 95))
        val keys = listOf("stay", "challenge", "opportunity", "long-term")
        val score = marketScore(state)
        val projected = ProKernel.projectedPitcher(state.pitcher, state.age + (state.journeyState?.offseasonTransition?.ageAdvanceYears ?: 0), state.proRulesVersion)
        val lower = when(state.role) { ProRole.CLOSER -> ProRole.SETUP; else -> ProRole.LONG_RELIEF }
        val higher = when(state.role) {
            ProRole.STARTER -> ProRole.STARTER; ProRole.LONG_RELIEF -> if (projected.stamina >= 55 && (projected.stuff + projected.movement) / 2 >= 55) ProRole.STARTER else ProRole.SETUP
            else -> ProRole.CLOSER
        }
        val roles = listOf(state.role, lower, higher, state.role)
        val outlooks = listOf(ProTeamOutlook.BALANCED, ProTeamOutlook.CONTENDER, ProTeamOutlook.OPPORTUNITY, ProTeamOutlook.BALANCED)
        fun build(attempt: Int, years: List<Int>? = null, multipliers: List<Int>? = null, fallback: Boolean = false): ProContractMarket {
            val offers = teams.mapIndexed { index, team ->
                val kind = if (index == 3) ProContractKind.LONG_TERM else ProContractKind.FREE_AGENT
                val count = (years?.get(index) ?: if (fallback) listOf(yearPools[0].last(), 2, 1, 5)[index] else choose(yearPools[index], "free-agent-${keys[index]}-years", team.id, attempt)).coerceAtMost(20 - state.season)
                val multiplier = multipliers?.get(index) ?: if (fallback) listOf(100, 115, 85, 90)[index] else choose(multiplierPools[index], "free-agent-${keys[index]}-multiplier", team.id, attempt)
                val salary = if (fallback) ProJourneyKernel.roundToTenMillion(ProJourneyKernel.salaryBand(score).last * multiplier / 100).coerceIn(30_000_000, 1_500_000_000)
                    else ProJourneyKernel.annualSalary(score, marketId, team.id, kind, multiplier)
                val bonusPools = if (fallback) listOf(listOf(100), listOf(70), listOf(80), listOf(130)) else listOf(listOf(80, 90, 100, 110, 120), listOf(60, 70, 80, 90), listOf(70, 80, 90, 100, 110), listOf(110, 120, 130, 140))
                val bonus = ProJourneyKernel.roundToTenMillion(salary * choose(bonusPools[index], "free-agent-signing-bonus", team.id, 0) / 100)
                val interestScore = team.demand + (hash("$marketId|${team.id}|interest") % 101UL).toInt() - (ranked.indexOfFirst { it.id == team.id }.takeIf { it >= 0 } ?: 9) * 4 +
                    (if (outlooks[index] == ProTeamOutlook.CONTENDER) 28 else if (outlooks[index] == ProTeamOutlook.OPPORTUNITY) -18 else 0) + if (index == 0) (state.journeyState?.reputation?.fanSupport ?: 0) / 2 else 0
                val interest = if (interestScore >= 150) ProClubInterest("hot", if (outlooks[index] == ProTeamOutlook.CONTENDER) "contention" else "demand")
                    else if (interestScore < 90) ProClubInterest("cool", if (outlooks[index] == ProTeamOutlook.OPPORTUNITY) "opportunity" else "depth") else ProClubInterest("warm", if (index == 0) "loyalty" else "demand")
                ProContractOffer("offer:$marketId:${team.id}:${kind.wire}", team.id, count, salary, bonus, kind, roles[index], outlooks[index],
                    expectation(state, kind, roles[index], if (index == 3) ProTeamOutlook.OPPORTUNITY else outlooks[index]), index == 0, interest)
            }
            return ProContractMarket(marketId, ProContractMarketKind.FREE_AGENCY, state.season + 1, state.revision + 1UL, offers)
        }
        for (attempt in 0..7) build(attempt).let { if (nonDominated(it.offers, state.role)) return it }
        fun products(pools: List<List<Int>>): List<List<Int>> = pools.fold(listOf(emptyList())) { acc, pool -> acc.flatMap { prefix -> pool.map { prefix + it } } }
        for (years in products(yearPools.map { pool -> pool.map { it.coerceAtMost(20 - state.season) }.distinct().sorted() }))
            for (multipliers in products(multiplierPools)) build(0, years, multipliers).let { if (nonDominated(it.offers, state.role)) return it }
        return build(0, fallback = true).also { require(nonDominated(it.offers, state.role)) { "pro.market.no_valid_offer_set" } }
    }
    public fun renewal(state: ProState): ProContractMarket {
        val marketId = "market:${state.careerId}:${state.season + 1}:renewal"
        val score = marketScore(state)
        val legacy = records(state).firstOrNull { it.teamId == state.team.id }?.let { ProTeamLegacyRules.score(it, state.journeyState!!.rulesVersion) } ?: 0
        val years = if (state.proRulesVersion >= 10 && legacy >= 65) listOf(3, 4, 5) else listOf(3, 4)
        fun offer(kind: ProContractKind, count: Int, multiplier: Int, fallback: Boolean): ProContractOffer {
            val outlook = if (kind == ProContractKind.PROVE_IT) ProTeamOutlook.OPPORTUNITY else ProTeamOutlook.BALANCED
            val salary = if (!fallback) ProJourneyKernel.annualSalary(score, marketId, state.team.id, kind, multiplier)
                else ProJourneyKernel.roundToTenMillion(ProJourneyKernel.salaryBand(score).last * multiplier / 100).coerceIn(30_000_000L, 1_500_000_000L)
            return ProContractOffer("offer:$marketId:${state.team.id}:${kind.wire}", state.team.id,
                count.coerceAtMost(20 - state.season), salary, null, kind, state.role, outlook, expectation(state, kind, state.role, outlook), true)
        }
        for (attempt in 0..7) {
            val index = StableHash.fnv1a64("$marketId|${state.team.id}|renewal-long-years|attempt:$attempt").toULong(16).rem(years.size.toULong()).toInt()
            val offers = listOf(offer(ProContractKind.RENEWAL_LONG, years[index], 90, false), offer(ProContractKind.PROVE_IT, 1, 110, false))
            if (nonDominated(offers, state.role)) return ProContractMarket(marketId, ProContractMarketKind.RENEWAL, state.season + 1, state.revision + 1UL, offers)
        }
        return ProContractMarket(marketId, ProContractMarketKind.RENEWAL, state.season + 1, state.revision + 1UL,
            listOf(offer(ProContractKind.RENEWAL_LONG, years.last(), 90, true), offer(ProContractKind.PROVE_IT, 1, 110, true)))
    }
}
