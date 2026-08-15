package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.StableHash
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException

/** Monotonic counter rules shared by the Phase 4 shadow and the future application adapter. */
public object HighSchoolCompletedGameCounterRules {
    public fun record(current: ULong, amount: Int = 1): ULong {
        require(amount >= 0) { "completed_game_count.amount_invalid" }
        if (amount == 0) return current
        val increment = amount.toULong()
        require(current <= ULong.MAX_VALUE - increment) { "completed_game_count.exhausted" }
        return current + increment
    }

    public fun isEligible(current: ULong): Boolean = current > 0UL
}

/**
 * C# Meta-compatible return-plan projection. It is deliberately a pure value-rule object: no
 * notification, analytics, package, or save side effect belongs in game-core.
 */
public object HighSchoolReturnPlanRules {
    public const val LEGACY_EXPERIMENT_ID: String = "next_action_v1"
    public const val EXPERIMENT_ID: String = "next_action_v2"
    public const val CURRENT_DEVELOPMENT_RULES_VERSION: Int = HighSchoolContentCatalog.BALANCE_VERSION

    public fun isEligible(completedGameCounter: ULong): Boolean = completedGameCounter > 0UL

    public fun experimentVariant(stableUserId: String): String {
        require(stableUserId.isNotBlank()) { "return_plan.stable_id_invalid" }
        return if (parity(StableHash.fnv1a64("$EXPERIMENT_ID|$stableUserId")) == 0) "holdout" else "guided"
    }

    public fun prepareForNextReturn(
        plan: HighSchoolReturnPlan,
        stableUserId: String,
        developmentRulesVersion: Int,
        dayKey: String,
    ): HighSchoolReturnPlan {
        require(isValidPromise(plan)) { "return_plan.invalid" }
        require(!isRetiredDailyPlan(plan)) { "daily.retired" }
        require(developmentRulesVersion > 0) { "return_plan.rules_version_invalid" }
        require(isDayKey(dayKey)) { "return_plan.day_invalid" }
        val scope = "$EXPERIMENT_ID|$stableUserId|$dayKey|${plan.destination.wire}|${plan.reason}|v$developmentRulesVersion"
        return plan.copy(
            route = route(plan.destination),
            title = plan.title,
            body = plan.body,
            createdDayKey = dayKey,
            receiptId = StableHash.fnv1a64(scope).trimStart('0').ifEmpty { "0" },
            experimentId = EXPERIMENT_ID,
            savedDayKey = dayKey,
            experimentVariant = experimentVariant(stableUserId),
            developmentRulesVersion = developmentRulesVersion,
            dismissed = false,
        )
    }

    /** Carries one prepared receipt across a refreshed copy of the same promise. */
    public fun carryingReceipt(
        current: HighSchoolReturnPlan,
        previous: HighSchoolReturnPlan?,
    ): HighSchoolReturnPlan {
        if (previous == null || !samePromise(current, previous)) return current
        return current.copy(
            experimentId = current.experimentId ?: previous.experimentId,
            receiptId = if (current.receiptId.isBlank()) previous.receiptId else current.receiptId,
            savedDayKey = current.savedDayKey ?: previous.savedDayKey,
            experimentVariant = current.experimentVariant ?: previous.experimentVariant,
            developmentRulesVersion = current.developmentRulesVersion ?: previous.developmentRulesVersion,
        )
    }

    public fun isRetiredDailyPlan(plan: HighSchoolReturnPlan?): Boolean = plan != null && (
        plan.destination == HighSchoolReturnDestination.DAILY_INNING ||
            plan.route.equals("daily-inning", ignoreCase = true) ||
            plan.route.equals("daily_inning", ignoreCase = true)
        )

    public fun isValid(plan: HighSchoolReturnPlan?): Boolean {
        if (!isValidPromise(plan)) return false
        plan ?: return false
        if (!isDayKey(plan.createdDayKey)) return false
        if (plan.receiptId.isNotBlank() &&
            (plan.receiptId.length > 32 || !isHex(plan.receiptId))) return false
        if (plan.experimentId != null && !isToken(plan.experimentId, 48)) return false
        if (plan.savedDayKey != null && !isDayKey(plan.savedDayKey)) return false
        if (plan.experimentVariant != null && plan.experimentVariant !in setOf("holdout", "guided")) return false
        if (plan.developmentRulesVersion != null && plan.developmentRulesVersion <= 0) return false
        return plan.route.isNotBlank() && plan.route.length <= 64
    }

    public fun route(destination: HighSchoolReturnDestination): String = when (destination) {
        HighSchoolReturnDestination.DAILY_INNING -> "daily-inning"
        HighSchoolReturnDestination.HIGH_SCHOOL -> "high-school"
        HighSchoolReturnDestination.PRO -> "pro"
    }

    public fun continueTitle(destination: HighSchoolReturnDestination): String = when (destination) {
        HighSchoolReturnDestination.DAILY_INNING -> "게임으로 돌아가기"
        HighSchoolReturnDestination.HIGH_SCHOOL -> "이 선수 이어서 키우기"
        HighSchoolReturnDestination.PRO -> "프로 시즌 이어가기"
    }

    public fun dayGap(savedDayKey: String?, returnDayKey: String): Int? {
        val saved = savedDayKey?.let(::parseDay) ?: return null
        val returned = parseDay(returnDayKey) ?: return null
        return returned.toEpochDay().minus(saved.toEpochDay()).toInt()
    }

    private fun isValidPromise(plan: HighSchoolReturnPlan?): Boolean = plan != null &&
        plan.title.isNotBlank() && plan.title.length <= 100 &&
        plan.body.isNotBlank() && plan.body.length <= 240 &&
        plan.reason.isNotBlank() && plan.reason.length <= 48 &&
        plan.destination in HighSchoolReturnDestination.entries

    private fun samePromise(left: HighSchoolReturnPlan, right: HighSchoolReturnPlan): Boolean =
        left.title == right.title && left.body == right.body &&
            left.destination == right.destination && left.reason == right.reason

    private fun isToken(value: String, maximum: Int): Boolean = value.isNotBlank() && value.length <= maximum &&
        value.all { it in 'a'..'z' || it in '0'..'9' || it == '_' || it == '-' }

    private fun isHex(value: String): Boolean = value.all { it in '0'..'9' || it in 'a'..'f' }

    private fun isDayKey(value: String): Boolean = parseDay(value) != null

    private fun parseDay(value: String): LocalDate? {
        val formatters = listOf(DateTimeFormatter.ISO_LOCAL_DATE, DateTimeFormatter.BASIC_ISO_DATE)
        return formatters.firstNotNullOfOrNull { formatter ->
            try { LocalDate.parse(value, formatter) } catch (_: DateTimeParseException) { null }
        }
    }

    private fun parity(hex: String): Int = hex.lastOrNull()?.digitToIntOrNull(16)?.and(1) ?: 0
}
