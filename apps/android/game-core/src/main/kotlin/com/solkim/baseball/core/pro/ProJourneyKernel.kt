package com.solkim.baseball.core.pro

import com.solkim.baseball.core.StableHash
import com.solkim.baseball.model.Hashing
import com.solkim.baseball.model.StrictJson
import kotlin.math.max
import kotlin.math.min

/** Pure Wave 6 rules. No UI-facing localized strings or implicit RNG are used here. */
public object ProJourneyKernel {
    public const val JOURNEY_RULES_VERSION: Int = 1
    public const val CURRENT_JOURNEY_RULES_VERSION: Int = 3
    public const val RETIRED_NUMBER_SEASONS: Int = 8
    public const val RETIRED_NUMBER_LEGACY: Int = 80
    public const val RETIRED_NUMBER_FAN: Int = 60

    public fun canonicalOffer(offer: ProContractOffer): String = listOf(
        offer.id,
        offer.teamId,
        offer.years,
        offer.annualSalary,
        offer.signingBonus ?: "-",
        offer.contractKind.wire,
        offer.rolePromise.wire,
        offer.outlook.wire,
        offer.expectation.kind.wire,
        offer.expectation.target,
        offer.expectation.difficulty.wire,
        if (offer.preservesTeamLegacy) "1" else "0",
    ).joinToString(":")

    public fun canonicalMarket(market: ProContractMarket): String = listOf(
        market.id,
        market.kind.wire,
        market.forSeason,
        market.generatedAtRevision,
        market.offers.joinToString(";", transform = ::canonicalOffer),
    ).joinToString("|")

    public fun canonicalSha256(value: String): String = Hashing.sha256Hex(value)

    public fun rookieAnnualSalary(draftRound: Int): Long = when (draftRound) {
        1 -> 80_000_000L
        2 -> 60_000_000L
        3 -> 50_000_000L
        else -> 40_000_000L
    }

    public fun playerMarket(
        careerId: String,
        currentTeamId: String,
        forSeason: Int,
        freeAgency: Boolean,
        state: ProCareerJourneyState,
        currentRole: ProRole,
        rulesVersion: Int = ProCatalog.RULES_VERSION,
    ): ProContractMarket {
        val marketKind = if (freeAgency) ProContractMarketKind.FREE_AGENCY else ProContractMarketKind.RENEWAL
        val marketId = "market:$careerId:$forSeason:${marketKind.wire}"
        val expectation = ProContractExpectation(ProContractExpectationKind.MAJOR_ROSTER, 1, ProExpectationDifficulty.STANDARD)
        fun offer(
            teamId: String,
            years: Int,
            multiplier: Int,
            kind: ProContractKind,
            role: ProRole,
            outlook: ProTeamOutlook,
            preserves: Boolean,
        ): ProContractOffer = ProContractOffer(
            id = "offer:$marketId:$teamId:${kind.wire}",
            teamId = teamId,
            years = years.coerceAtMost(ProCatalog.MAXIMUM_CAREER_SEASONS - forSeason + 1).coerceAtLeast(1),
            annualSalary = annualSalary(55, marketId, teamId, kind, multiplier),
            signingBonus = null,
            contractKind = kind,
            rolePromise = role,
            outlook = outlook,
            expectation = expectation,
            preservesTeamLegacy = preserves,
        )
        val external = ProCatalog.teams.filter { it.id != currentTeamId }.sortedBy { StableHash.fnv1a64("$marketId|${it.id}") }.take(2)
        val faYears = ProCatalog.maximumContractYears(rulesVersion)
        val offers = if (!freeAgency) {
            listOf(
                offer(currentTeamId, 3, 90, ProContractKind.RENEWAL_LONG, currentRole, ProTeamOutlook.BALANCED, true),
                offer(currentTeamId, 1, 110, ProContractKind.PROVE_IT, currentRole, ProTeamOutlook.OPPORTUNITY, true),
            )
        } else {
            listOf(
                offer(currentTeamId, faYears, 100, ProContractKind.FREE_AGENT, currentRole, ProTeamOutlook.BALANCED, true),
                offer(external[0].id, 2, 115, ProContractKind.FREE_AGENT, ProRole.LONG_RELIEF, ProTeamOutlook.CONTENDER, false),
                offer(external[1].id, 1, 85, ProContractKind.FREE_AGENT, ProRole.STARTER, ProTeamOutlook.OPPORTUNITY, false),
            )
        }
        return ProContractMarket(marketId, marketKind, forSeason, (state.lastSettlement?.season ?: 0).toULong(), offers)
    }

    public fun rookieMarket(
        careerId: String,
        teamId: String,
        revision: ULong,
        forSeason: Int = 1,
        draftRound: Int = 2,
        overallPick: Int = 18,
        signingBonus: Long = 120_000_000L,
        role: ProRole = ProRole.STARTER,
    ): ProContractMarket {
        val marketId = "market:$careerId:$forSeason:rookie"
        val offerId = "offer:$marketId:$teamId:rookie"
        val expectation = ProContractExpectation(
            kind = ProContractExpectationKind.MAJOR_ROSTER,
            target = 1,
            difficulty = ProExpectationDifficulty.ACCESSIBLE,
        )
        return ProContractMarket(
            id = marketId,
            kind = ProContractMarketKind.ROOKIE,
            forSeason = forSeason,
            generatedAtRevision = revision,
            offers = listOf(
                ProContractOffer(
                    id = offerId,
                    teamId = teamId,
                    years = 3,
                    annualSalary = rookieAnnualSalary(draftRound),
                    signingBonus = signingBonus,
                    contractKind = ProContractKind.ROOKIE,
                    rolePromise = role,
                    outlook = ProTeamOutlook.OPPORTUNITY,
                    expectation = expectation,
                    preservesTeamLegacy = true,
                ),
            ),
            draftRound = draftRound,
            overallPick = overallPick,
        )
    }

    public fun salaryBand(marketScore: Int): LongRange {
        return when (marketScore.coerceIn(0, 100)) {
            in 0..39 -> 40_000_000L..90_000_000L
            in 40..54 -> 100_000_000L..240_000_000L
            in 55..69 -> 250_000_000L..500_000_000L
            in 70..84 -> 550_000_000L..900_000_000L
            else -> 950_000_000L..1_400_000_000L
        }
    }

    public fun roundToTenMillion(value: Long): Long = if (value <= 0) 0 else ((value + 5_000_000L) / 10_000_000L) * 10_000_000L

    public fun annualSalary(
        marketScore: Int,
        marketId: String,
        teamId: String,
        contractKind: ProContractKind,
        multiplierPercent: Int,
    ): Long {
        val band = salaryBand(marketScore)
        val steps = ((band.last - band.first) / 10_000_000L).coerceAtLeast(0)
        val hash = StableHash.fnv1a64("$marketId|$teamId|${contractKind.wire}").toULong(16)
        val base = band.first + (hash % (steps + 1).toULong()).toLong() * 10_000_000L
        val scaled = base * multiplierPercent.coerceAtLeast(0).toLong() / 100L
        return roundToTenMillion(scaled).coerceIn(30_000_000L, 1_500_000_000L)
    }

    public fun roleValue(current: ProRole, promised: ProRole): Int = when {
        current == promised -> 1
        current == ProRole.LONG_RELIEF && (promised == ProRole.STARTER || promised == ProRole.SETUP) -> 2
        current == ProRole.SETUP && promised == ProRole.CLOSER -> 2
        else -> 0
    }

    /** Stable dominance relation used by both fixture QA and the offer chooser. */
    public fun isNonDominated(offers: List<ProContractOffer>): Boolean = offers.none { candidate ->
        offers.any { other ->
            candidate !== other &&
                candidate.outlook == other.outlook &&
                candidate.preservesTeamLegacy == other.preservesTeamLegacy &&
                other.annualSalary >= candidate.annualSalary &&
                other.years >= candidate.years &&
                roleValue(candidate.rolePromise, other.rolePromise) >= 1 &&
                (other.annualSalary > candidate.annualSalary || other.years > candidate.years || other.rolePromise != candidate.rolePromise)
        }
    }

    public fun applyInvestment(
        state: ProCareerJourneyState,
        careerId: String,
        season: Int,
        investment: ProOffseasonInvestment,
        focus: ProDevelopmentFocus?,
    ): ProCareerJourneyState {
        require(state.finances.investmentSeason != season) { "pro.journey.investment_duplicate" }
        val cost = when (investment) {
            ProOffseasonInvestment.PITCH_LAB -> 50_000_000L
            ProOffseasonInvestment.RECOVERY_TEAM -> 40_000_000L
            ProOffseasonInvestment.FAN_FOUNDATION -> 30_000_000L
            ProOffseasonInvestment.NONE -> 0L
        }
        require(state.finances.availableFunds >= cost) { "pro.journey.insufficient_funds" }
        val transaction = ProFinanceTransaction(
            id = "investment:$careerId:$season:${investment.wire}",
            season = season,
            kind = ProFinanceTransactionKind.INVESTMENT,
            amount = -cost,
        )
        require(state.finances.transactions.none { it.id == transaction.id }) { "pro.journey.investment_duplicate" }
        val finances = state.finances.copy(
            availableFunds = state.finances.availableFunds - cost,
            transactions = state.finances.transactions + transaction,
            investmentSeason = season,
        )
        val benefit = when (investment) {
            ProOffseasonInvestment.PITCH_LAB -> ProSeasonBenefit(ProSeasonBenefitKind.DEVELOPMENT_HEAD_START, focus, 1)
            ProOffseasonInvestment.RECOVERY_TEAM -> ProSeasonBenefit(ProSeasonBenefitKind.INJURY_MITIGATION, null, 1)
            ProOffseasonInvestment.FAN_FOUNDATION, ProOffseasonInvestment.NONE -> null
        }
        return state.copy(finances = finances, activeSeasonBenefit = benefit)
    }

    public fun settle(
        state: ProCareerJourneyState,
        careerId: String,
        season: Int,
        teamId: String,
        salary: Long,
        merchandise: Long,
        fanDelta: Int,
        legacyDelta: Int,
        hallOfFameDelta: Int,
        yearsBefore: Int,
        yearsAfter: Int,
        nextRoute: ProSettlementNextRoute,
        fanReasons: List<ProFanReason> = emptyList(),
    ): ProCareerJourneyState {
        val id = "settlement:$careerId:$season"
        if (state.lastSettlement?.id == id) return state
        require(state.lastSettlement == null || state.lastSettlement.season < season) { "pro.journey.settlement_order" }
        require(state.finances.transactions.none { it.id == "salary:$careerId:$season" }) { "pro.journey.salary_duplicate" }
        val salaryTransaction = ProFinanceTransaction("salary:$careerId:$season", season, ProFinanceTransactionKind.SALARY, salary)
        val merchandiseTransaction = if (merchandise == 0L) null else ProFinanceTransaction("merchandise:$careerId:$season", season, ProFinanceTransactionKind.MERCHANDISE, merchandise)
        val transactions = state.finances.transactions + salaryTransaction + listOfNotNull(merchandiseTransaction)
        val finances = state.finances.copy(
            careerEarnings = state.finances.careerEarnings + salary + merchandise,
            availableFunds = state.finances.availableFunds + salary + merchandise,
            salaryCreditedThroughSeason = max(state.finances.salaryCreditedThroughSeason, season),
            transactions = transactions,
        )
        val fanBefore = state.reputation.fanSupport
        val fanAfter = (fanBefore + fanDelta.coerceIn(-12, 20)).coerceIn(0, 100)
        val previousRecord = state.teamRecords.firstOrNull { it.teamId == teamId }
        val record = (previousRecord ?: ProTeamCareerRecord(teamId, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, null)).copy(
            completedSeasons = (previousRecord?.completedSeasons ?: 0) + 1,
            consecutiveSeasons = (previousRecord?.consecutiveSeasons ?: 0) + 1,
            lastSeason = season,
        )
        val settlement = ProSeasonSettlement(
            id = id,
            season = season,
            teamId = teamId,
            salaryIncome = salary,
            merchandiseIncome = merchandise,
            fanBefore = fanBefore,
            fanAfter = fanAfter,
            fanDelta = fanAfter - fanBefore,
            fanReasons = fanReasons,
            merchandiseTier = merchandiseTier(fanBefore),
            teamLegacyBefore = previousRecord?.let(::teamLegacy) ?: 0,
            teamLegacyAfter = (previousRecord?.let(::teamLegacy) ?: 0) + legacyDelta,
            hallOfFameBefore = state.lastSettlement?.hallOfFameAfter ?: 0,
            hallOfFameAfter = (state.lastSettlement?.hallOfFameAfter ?: 0) + hallOfFameDelta,
            contractYearsBefore = yearsBefore,
            contractYearsAfter = yearsAfter,
            contractExpectation = null,
            contractExpectationActual = null,
            contractExpectationMet = null,
            goalProgressBefore = null,
            goalProgressAfter = null,
            goalCompleted = false,
            nextRoute = nextRoute,
        )
        return state.copy(
            teamRecords = state.teamRecords.filterNot { it.teamId == teamId } + record,
            reputation = state.reputation.copy(
                fanSupport = fanAfter,
                lastMerchandiseTier = merchandiseTier(fanBefore),
            ),
            finances = finances,
            lastSettlement = settlement,
            settlementAcknowledged = false,
        )
    }

    public fun acknowledgeSettlement(state: ProCareerJourneyState, settlementId: String): ProCareerJourneyState {
        require(state.lastSettlement?.id == settlementId) { "pro.journey.settlement_id" }
        return state.copy(settlementAcknowledged = true)
    }

    public fun applyMediaChoice(
        state: ProCareerJourneyState,
        careerId: String,
        season: Int,
        decisionId: String,
        choiceId: String,
        endorsementAmount: Long,
        fanDelta: Int,
        communityDelta: Int,
        teamId: String? = null,
    ): ProCareerJourneyState {
        val transactionId = "endorsement:$careerId:$season:$decisionId"
        val transaction = if (endorsementAmount == 0L) {
            null
        } else {
            require(state.finances.transactions.none { it.id == transactionId }) { "pro.journey.endorsement_duplicate" }
            ProFinanceTransaction(transactionId, season, ProFinanceTransactionKind.ENDORSEMENT, endorsementAmount)
        }
        val resolvedTeamId = teamId ?: state.lastSettlement?.teamId
        val record = resolvedTeamId?.let { id -> state.teamRecords.firstOrNull { row -> row.teamId == id } }
        val updatedRecord = if (record == null || communityDelta == 0) null else record.copy(communityPoints = record.communityPoints + communityDelta)
        return state.copy(
            finances = state.finances.copy(
                careerEarnings = state.finances.careerEarnings + endorsementAmount,
                availableFunds = state.finances.availableFunds + endorsementAmount,
                transactions = state.finances.transactions + listOfNotNull(transaction),
            ),
            reputation = state.reputation.copy(
                fanSupport = (state.reputation.fanSupport + fanDelta).coerceIn(0, 100),
                endorsementSeasons = if (endorsementAmount == 0L) {
                    state.reputation.endorsementSeasons
                } else {
                    (state.reputation.endorsementSeasons + season).distinct().sorted()
                },
            ),
            teamRecords = if (updatedRecord == null) state.teamRecords else state.teamRecords.filterNot { it.teamId == updatedRecord.teamId } + updatedRecord,
        )
    }

    public fun merchandiseIncome(fanSupport: Int): Long =
        (fanSupport.coerceIn(0, 100).toLong() * 500_000L).coerceAtMost(50_000_000L)

    public fun settlementFanReasons(state: ProState): List<ProFanReason> {
        val reasons = mutableListOf<ProFanReason>()
        val careerId = state.careerId
        val season = state.season
        state.currentGameLines.filter { it.season == season && it.played }.sortedWith(compareBy({ it.week }, { it.outingNumber })).forEach { line ->
            when {
                line.runsAllowed == 0 -> reasons += ProFanReason(
                    id = "fan-reason:$careerId:$season:${ProFanReasonKind.IMPORTANT_GAME_SCORELESS.wire}:pro.fan.important-game.scoreless:${line.outingNumber}",
                    kind = ProFanReasonKind.IMPORTANT_GAME_SCORELESS,
                    contentId = "pro.fan.important-game.scoreless",
                    delta = 2,
                )
                line.runsAllowed >= 3 -> reasons += ProFanReason(
                    id = "fan-reason:$careerId:$season:${ProFanReasonKind.IMPORTANT_GAME_RUNS_ALLOWED.wire}:pro.fan.important-game.runs-allowed:${line.outingNumber}",
                    kind = ProFanReasonKind.IMPORTANT_GAME_RUNS_ALLOWED,
                    contentId = "pro.fan.important-game.runs-allowed",
                    delta = -1,
                )
            }
        }
        (ProCareerRecognitionRules.awardContentIDs(state.currentStats, state.journeyState?.rulesVersion ?: 1) + listOfNotNull("pro.autumn.champion".takeIf { state.postseason?.result == ProPostseasonResult.CHAMPION })).sorted().take(2).forEachIndexed { index, award ->
            reasons += ProFanReason(
                id = "fan-reason:$careerId:$season:${ProFanReasonKind.SEASON_AWARD.wire}:$award:$index",
                kind = ProFanReasonKind.SEASON_AWARD,
                contentId = award,
                delta = 4,
            )
        }
        if (state.currentStats.teamId == state.team.id) {
            reasons += ProFanReason(
                id = "fan-reason:$careerId:$season:${ProFanReasonKind.SAME_TEAM_SEASON.wire}:pro.fan.same-team-season:0",
                kind = ProFanReasonKind.SAME_TEAM_SEASON,
                contentId = "pro.fan.same-team-season",
                delta = 1,
            )
        }
        fun milestone(kind: String, prior: Int, current: Int, marks: List<Int>) {
            marks.filter { prior < it && current >= it }.forEach { mark ->
                val content = "pro.milestone.career.$kind.$mark"
                reasons += ProFanReason("fan-reason:$careerId:$season:career_milestone:$content:0", ProFanReasonKind.CAREER_MILESTONE, content, 2)
            }
        }
        milestone("games", state.careerStats.sumOf { it.games }, state.careerStats.sumOf { it.games } + state.currentStats.games, listOf(50, 100, 300))
        milestone("strikeouts", state.careerStats.sumOf { it.strikeouts }, state.careerStats.sumOf { it.strikeouts } + state.currentStats.strikeouts, listOf(50, 100, 200, 500))
        contractExpectationMet(state)?.let { met ->
            val kind = if (met) ProFanReasonKind.CONTRACT_EXPECTATION_MET else ProFanReasonKind.CONTRACT_EXPECTATION_MISSED
            val content = "pro.fan.contract-expectation.${if (met) "met" else "missed"}"
            reasons += ProFanReason("fan-reason:$careerId:$season:${kind.wire}:$content:0", kind, content, if (met) 3 else -1)
        }
        return reasons.sortedBy { it.id }
    }

    public fun contractExpectation(state: ProState): ProContractExpectation? = state.journeyState?.contractHistory?.lastOrNull { it.teamId == state.team.id && it.endedSeason == null }?.expectation
    public fun contractExpectationActual(state: ProState): Int? = contractExpectation(state)?.let { e -> when (e.kind) {
        ProContractExpectationKind.MAJOR_ROSTER -> if (state.level == ProLevel.MAJOR) 1 else 0
        ProContractExpectationKind.INNINGS -> state.currentStats.inningsOuts
        ProContractExpectationKind.STRIKEOUTS -> state.currentStats.strikeouts
        ProContractExpectationKind.SAVES -> state.currentStats.saves
        ProContractExpectationKind.RUN_PREVENTION -> state.currentStats.runPerNinePermille.takeIf { state.currentStats.inningsOuts >= 60 }
    } }
    public fun contractExpectationMet(state: ProState): Boolean? = contractExpectation(state)?.let { e ->
        val actual = contractExpectationActual(state)
        actual != null && if (e.kind == ProContractExpectationKind.RUN_PREVENTION) actual <= e.target else actual >= e.target
    }

    public fun completeActiveGoal(state: ProCareerJourneyState, careerId: String, season: Int): ProCareerJourneyState {
        val goal = state.activeGoal ?: return state
        if (goal.completedSeason != null || state.goalHistory.any { it.id == goal.id && it.outcome == ProCareerGoalOutcome.COMPLETED }) return state
        val record = ProCareerGoalRecord(goal.id, goal.ambition, goal.selectedSeason, goal.anchorTeamId, season, season, ProCareerGoalOutcome.COMPLETED)
        return state.copy(
            activeGoal = goal.copy(completedSeason = season),
            goalHistory = state.goalHistory + record,
            recognitions = state.recognitions + ProCareerRecognition("recognition:$careerId:$season:milestone:ambition_${goal.ambition.wire}", ProCareerRecognitionKind.MILESTONE, "pro.ambition.${goal.ambition.wire}", season, goal.anchorTeamId, null),
        )
    }

    public fun teamLegacy(record: ProTeamCareerRecord): Int = teamLegacy(record, 1)

    public fun teamLegacy(record: ProTeamCareerRecord, rulesVersion: Int): Int =
        ProTeamLegacyRules.score(record, rulesVersion)

    public fun merchandiseTier(fanSupport: Int): ProMerchandiseTier = when (fanSupport.coerceIn(0, 100)) {
        in 75..100 -> ProMerchandiseTier.ICON
        in 50..74 -> ProMerchandiseTier.STAR
        in 25..49 -> ProMerchandiseTier.RISING
        else -> ProMerchandiseTier.LOCAL
    }

    public fun retirementPreview(state: ProCareerJourneyState, lastTeamId: String?): ProCareerRetirementProjection {
        val last = lastTeamId?.let { id -> state.teamRecords.firstOrNull { it.teamId == id } }
        val completed = state.goalHistory.filter { it.outcome == ProCareerGoalOutcome.COMPLETED }.map { it.ambition }.distinct()
        val rules = state.rulesVersion
        val lastLegacy = last?.let { teamLegacy(it, rules) } ?: 0
        val retiredNumber = last != null && last.completedSeasons >= RETIRED_NUMBER_SEASONS && lastLegacy >= RETIRED_NUMBER_LEGACY && state.reputation.fanSupport >= RETIRED_NUMBER_FAN
        val clubHalls = state.teamRecords.filter { it.completedSeasons >= 6 && teamLegacy(it, rules) >= 65 && (!retiredNumber || it.teamId != lastTeamId) }.map { it.teamId }.sorted()
        val honors = buildList {
            if (retiredNumber) add(ProRetirementHonor("retired-number:$lastTeamId", ProRetirementHonorKind.RETIRED_NUMBER, lastTeamId, null, null))
            if ((state.lastSettlement?.hallOfFameAfter ?: 0) >= 70) add(ProRetirementHonor("hof:$lastTeamId", ProRetirementHonorKind.HALL_OF_FAME, null, null, state.lastSettlement?.hallOfFameAfter?.toLong()))
            clubHalls.forEach { add(ProRetirementHonor("club-hall:$it", ProRetirementHonorKind.CLUB_HALL, it, null, null)) }
            completed.forEach { add(ProRetirementHonor("ambition:${it.wire}", ProRetirementHonorKind.AMBITION_COMPLETED, lastTeamId, it.wire, null)) }
            add(ProRetirementHonor("earnings", ProRetirementHonorKind.CAREER_EARNINGS, null, null, state.finances.careerEarnings))
        }
        return ProCareerRetirementProjection(
            finalScore = state.lastSettlement?.hallOfFameAfter ?: 0,
            lastTeamId = lastTeamId,
            lastTeamSeasons = last?.completedSeasons ?: 0,
            lastTeamLegacy = lastLegacy,
            fanSupport = state.reputation.fanSupport,
            retiredNumberEligible = retiredNumber,
            clubHallTeamIds = clubHalls,
            completedAmbitions = completed,
            careerEarnings = state.finances.careerEarnings,
            honors = honors,
        )
    }

    public fun migrateLegacy(state: ProState): ProCareerJourneyState {
        require(state.journeyState == null) { "pro.journey.already_migrated" }
        val fan = (10 + state.awards.size * 5 + state.milestones.size * 2 + state.serviceYears * 2).coerceIn(10, 60)
        val records = state.careerStats.groupBy { it.teamId }.map { (teamId, stats) ->
            val orderedSeasons = stats.sortedBy { it.season }.map { it.season }
            val consecutive = orderedSeasons.fold(0 to Int.MIN_VALUE) { (run, previous), seasonValue ->
                if (seasonValue == previous + 1) (run + 1) to seasonValue else 1 to seasonValue
            }.first.coerceAtLeast(if (orderedSeasons.isEmpty()) 0 else 1)
            ProTeamCareerRecord(
                teamId = teamId,
                completedSeasons = stats.size,
                consecutiveSeasons = consecutive,
                games = stats.sumOf { it.games },
                starts = stats.sumOf { it.starts },
                inningsOuts = stats.sumOf { it.inningsOuts },
                strikeouts = stats.sumOf { it.strikeouts },
                wins = stats.sumOf { it.wins },
                saves = stats.sumOf { it.saves },
                awardCount = 0,
                communityPoints = 0,
                lastSeason = stats.maxOfOrNull { it.season },
            )
        }.sortedBy { it.teamId }
        val contract = state.contract?.let {
            ProContractRecord(
                contractId = "contract:${state.careerId}:legacy:${state.season}",
                teamId = state.team.id,
                kind = null,
                signedSeason = state.season,
                totalYears = max(1, it.yearsRemaining),
                annualSalary = it.annualSalary.toLong(),
                signingBonus = null,
                rolePromise = it.rolePromise,
                expectation = null,
                coveredSeasons = emptyList(),
                fulfilledExpectationSeasons = emptyList(),
                endedSeason = null,
                endReason = null,
            )
        }
        return ProCareerJourneyState(
            rulesVersion = JOURNEY_RULES_VERSION,
            teamRecords = records,
            contractHistory = listOfNotNull(contract),
            reputation = ProReputationState(fanSupport = fan),
            migration = ProJourneyMigration(ProJourneyMigrationSource.LEGACY_SAFE_BOUNDARY, state.season, state.season, state.awards.size, true),
        )
    }

    public fun stateCommitment(state: ProCareerJourneyState): String = StableHash.fnv1a64(
        ProJourneyStateCodec.canonicalToken(state),
    )

    private fun <T> List<T>.joinStable(): String = joinToString(";")
}
