package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.SplitMix64
import com.solkim.baseball.core.StableHash
import com.solkim.baseball.model.Hashing
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.time.temporal.WeekFields

public object HighSchoolPledgeRules {
    public const val RULES_VERSION: Int = 2

    public val definitions: List<HighSchoolPledgeDefinition> = listOf(
        HighSchoolPledgeDefinition("get_drafted", HighSchoolPledgeTier.SAFE, 1, "지명받기", "이번 생에 드래프트 지명을 받습니다."),
        HighSchoolPledgeDefinition("strikeout_master", HighSchoolPledgeTier.BOLD, 5, "삼진 다섯 개", "중요 경기에서 삼진 5개를 기록합니다."),
        HighSchoolPledgeDefinition("clean_games", HighSchoolPledgeTier.BOLD, 4, "깨끗한 경기", "무실점 중요 경기를 4회 기록합니다."),
        HighSchoolPledgeDefinition("iron_control", HighSchoolPledgeTier.BOLD, 4, "철벽 제구", "중요 경기 4회 동안 볼넷을 허용하지 않습니다."),
        HighSchoolPledgeDefinition("healthy_finish", HighSchoolPledgeTier.SAFE, 1, "건강한 완주", "팔 경고 없이 고교 생활을 마칩니다."),
        HighSchoolPledgeDefinition("awakening_three", HighSchoolPledgeTier.BOLD, 3, "세 번의 각성", "각성 3회를 선택합니다."),
        HighSchoolPledgeDefinition("fan_sixty", HighSchoolPledgeTier.BOLD, 25, "관중의 시선", "팬 관심 25점을 쌓습니다."),
        HighSchoolPledgeDefinition("evaluation_sixty_five", HighSchoolPledgeTier.BOLD, 64, "평가 65", "드래프트 평가 64점 이상을 받습니다."),
        HighSchoolPledgeDefinition("evaluation_seventy_five", HighSchoolPledgeTier.LEGENDARY, 67, "평가 75", "드래프트 평가 67점 이상을 받습니다."),
        HighSchoolPledgeDefinition("iron_control_five", HighSchoolPledgeTier.LEGENDARY, 6, "완벽한 철벽", "삼진과 무볼넷의 기준을 넘깁니다."),
        HighSchoolPledgeDefinition("rival_three_strikeouts", HighSchoolPledgeTier.BOLD, 3, "라이벌을 넘어서", "라이벌과의 경기에서 삼진 3개를 쌓습니다."),
        HighSchoolPledgeDefinition("relationship_sixty_five", HighSchoolPledgeTier.SAFE, 69, "믿음의 배터리", "관계 신뢰를 69점 이상으로 만듭니다."),
    )

    public fun definition(id: String): HighSchoolPledgeDefinition = definitions.firstOrNull { it.id == id }
        ?: throw IllegalArgumentException("pledge.unknown:$id")

    public fun options(
        stableUserId: String,
        weekKey: String,
        careerId: String,
        state: HighSchoolState? = null,
        intentPledgeId: String? = null,
    ): List<HighSchoolPledgeDefinition> {
        // Swift ranks by careerID|pledge-v2|id. The user/week arguments are retained at this
        // boundary for the app's stable selection API but do not alter the source rule.
        val eligible = definitions.filter { state == null || state.lifeNumber > 1 || it.tier != HighSchoolPledgeTier.LEGENDARY }
        val ranked = eligible.sortedBy { Hashing.fnv1a64Hex("$careerId|pledge-v2|${it.id}") }
        if (ranked.isEmpty()) return emptyList()
        val aligned = state?.let(::alignedIds).orEmpty()
        val selected = mutableListOf<HighSchoolPledgeDefinition>()
        if (intentPledgeId != null) ranked.firstOrNull { it.id == intentPledgeId }?.let(selected::add)
        fun ensure(predicate: (HighSchoolPledgeDefinition) -> Boolean) {
            if (selected.size >= 3 || selected.any(predicate)) return
            ranked.firstOrNull { predicate(it) && it !in selected }?.let(selected::add)
        }
        ensure { it.tier == HighSchoolPledgeTier.SAFE }
        ensure { it.id in aligned }
        ensure { it.tier == HighSchoolPledgeTier.BOLD || it.tier == HighSchoolPledgeTier.LEGENDARY }
        ranked.filterNot { it in selected }.take(3 - selected.size).forEach(selected::add)
        return selected.take(3)
    }

    public fun evaluate(
        definition: HighSchoolPledgeDefinition,
        state: HighSchoolState,
        cleanGameCount: Int = 0,
        rivalStrikeouts: Int = 0,
    ): Int {
        val performance = state.performance
        return when (definition.id) {
            "get_drafted" -> if (state.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED) 1 else 0
            "strikeout_master" -> performance.strikeouts
            "clean_games" -> if (cleanGameCount > 0) cleanGameCount else if (performance.importantGamesCompleted > 0 && performance.runsAllowed == 0) performance.importantGamesCompleted else 0
            "iron_control" -> performance.strikeouts
            "healthy_finish" -> performance.importantGamesCompleted
            "awakening_three" -> awakeningFamilies(state.selectedAwakenings).size
            "fan_sixty" -> state.fanInterest
            "evaluation_sixty_five", "evaluation_seventy_five" -> state.draftResult?.evaluationScore ?: 0
            "iron_control_five" -> performance.strikeouts
            "rival_three_strikeouts" -> rivalStrikeouts
            "relationship_sixty_five" -> maxOf(state.managerTrust, state.catcherTrust, state.rivalTrust)
            else -> 0
        }.coerceAtLeast(0)
    }

    public fun isAchieved(
        definition: HighSchoolPledgeDefinition,
        state: HighSchoolState,
        cleanGameCount: Int = 0,
        rivalStrikeouts: Int = 0,
    ): Boolean {
        val performance = state.performance
        return when (definition.id) {
            "get_drafted" -> state.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED
            "strikeout_master" -> performance.strikeouts >= definition.target
            "clean_games" -> (if (cleanGameCount > 0) cleanGameCount else evaluate(definition, state)) >= definition.target
            "iron_control" -> performance.importantGamesCompleted >= 4 && performance.walks == 0 && performance.strikeouts >= 4
            "healthy_finish" -> performance.importantGamesCompleted >= 4 && state.armRisk < 55 && state.injuryRecovery == 0 && state.fatigue <= 78
            "awakening_three" -> state.selectedAwakenings.size >= 3 && awakeningFamilies(state.selectedAwakenings).size >= 3
            "fan_sixty" -> state.fanInterest >= definition.target
            "evaluation_sixty_five", "evaluation_seventy_five" -> (state.draftResult?.evaluationScore ?: 0) >= definition.target
            "iron_control_five" -> performance.importantGamesCompleted >= 4 && performance.walks == 0 && performance.strikeouts >= definition.target
            "rival_three_strikeouts" -> rivalStrikeouts >= definition.target
            "relationship_sixty_five" -> maxOf(state.managerTrust, state.catcherTrust, state.rivalTrust) >= definition.target
            else -> false
        }
    }

    public fun update(
        pledge: HighSchoolPledgeState?,
        state: HighSchoolState,
        cleanGameCount: Int = 0,
        rivalStrikeouts: Int = 0,
    ): HighSchoolPledgeState? {
        if (pledge == null) return null
        val progress = evaluate(pledge.definition, state, cleanGameCount, rivalStrikeouts)
        return pledge.copy(
            progress = progress,
            achieved = isAchieved(pledge.definition, state, cleanGameCount, rivalStrikeouts),
        )
    }

    private fun alignedIds(state: HighSchoolState): Set<String> {
        val groups = listOf(
            state.pitcher.command to setOf("iron_control", "iron_control_five", "evaluation_sixty_five"),
            maxOf(state.pitcher.stuff, state.pitcher.movement) to setOf("strikeout_master", "clean_games", "evaluation_seventy_five"),
            maxOf(state.managerTrust, state.catcherTrust, state.rivalTrust) to setOf("relationship_sixty_five", "rival_three_strikeouts"),
        )
        val best = groups.maxByOrNull { it.first }?.second.orEmpty().toMutableSet()
        if (state.armRisk >= 35) best += "healthy_finish"
        if (state.fanInterest >= 35) best += "fan_sixty"
        return best
    }

    private fun awakeningFamilies(awakenings: List<HighSchoolAwakening>): Set<String> = awakenings.mapNotNull {
        when (it) {
            HighSchoolAwakening.EXPLOSIVE_FASTBALL, HighSchoolAwakening.RISING_FOUR_SEAM,
            HighSchoolAwakening.IRON_ARM, HighSchoolAwakening.LATE_INNING_RESERVE -> "body"
            HighSchoolAwakening.PINPOINT_EDGE, HighSchoolAwakening.REPEATABLE_RELEASE,
            HighSchoolAwakening.FIRST_PITCH_STRIKE, HighSchoolAwakening.CALM_UNDER_PRESSURE,
            HighSchoolAwakening.SCOUT_COMPOSURE -> "command"
            HighSchoolAwakening.DISAPPEARING_BREAKER, HighSchoolAwakening.SINKER_TUNNEL,
            HighSchoolAwakening.FROZEN_CHANGEUP, HighSchoolAwakening.SWEEPING_SLIDER,
            HighSchoolAwakening.CURVEBALL_CLOCK -> "breaking"
            HighSchoolAwakening.BATTERY_SYNC, HighSchoolAwakening.PICKOFF_RHYTHM,
            HighSchoolAwakening.TWO_STRIKE_PLAN, HighSchoolAwakening.TRAFFIC_CONTROLLER -> "game"
        }
    }.toSet()
}

public object HighSchoolWeeklyRules {
    public const val RULES_VERSION: Int = 1
    public const val REWARD_SOUL_POINTS: Int = 15

    public data class Eligibility(
        val hasHighSchoolCareer: Boolean,
        val remainingImportantGames: Int,
        val remainingChapterAdvances: Int,
        val dailyInningUnlocked: Boolean = false,
        val canStartNextRun: Boolean = false,
        val canSelectPledge: Boolean = false,
        val canChooseDifferentSchool: Boolean = false,
        val hasProCareer: Boolean = false,
    )

    private val definitions = listOf(
        "played_on_two_days" to 2,
        // Stored for compatibility with the shared weekly catalog, never selected for a
        // HighSchool-only board until DailyInning owns this projection.
        "daily_inning_completed" to 1,
        "important_games_completed" to 2,
        "chapters_advanced" to 2,
        "next_run_started" to 1,
        "pledge_selected" to 1,
        "different_school_selected" to 1,
        "sequence_mastery_triggered" to 3,
        "pro_weeks_advanced" to 3,
    )

    public fun make(stableUserId: String, weekKey: String, careerId: String): HighSchoolWeeklyState {
        val eligible = definitions.filter { it.first != "daily_inning_completed" && it.first != "pro_weeks_advanced" && it.first != "different_school_selected" && it.first != "next_run_started" }
        val ordered = eligible.sortedBy { Hashing.fnv1a64Hex("$stableUserId|$weekKey|${it.first}|weekly-v1") }
        val played = eligible.first { it.first == "played_on_two_days" }
        val selected = (listOf(played) + ordered).distinctBy { it.first }.take(3)
        return HighSchoolWeeklyState(stableUserId, weekKey, selected.map { HighSchoolWeeklyTask(it.first, it.second, kind = it.first) })
    }

    /** C# Meta-compatible board construction. The legacy three-string overload above remains
     * stable for the current HighSchool fixture and intentionally keeps its compact task IDs. */
    public fun make(weekKey: String, stableUserId: String, eligibility: Eligibility): HighSchoolWeeklyState? {
        val eligible = eligibleKinds(eligibility)
            .sortedWith(compareBy<String> { Hashing.fnv1a64Hex("$stableUserId|$weekKey|$it|weekly-v1") }.thenBy { it })
            .toMutableList()
        if (eligible.size < 3) return null
        if (eligible.remove("played_on_two_days")) eligible.add(0, "played_on_two_days")
        val tasks = eligible.take(3).map { kind ->
            HighSchoolWeeklyTask(
                id = "$weekKey-$kind",
                target = target(kind),
                kind = kind,
            )
        }
        return HighSchoolWeeklyState(stableUserId, weekKey, tasks)
    }

    /** Applies Seoul-week observation and keeps a clock rollback from replacing newer state. */
    public fun configure(
        current: HighSchoolWeeklyState,
        stableUserId: String,
        weekKey: String,
        weekStartDayKey: String,
        eligibility: Eligibility,
    ): HighSchoolWeeklyState {
        require(stableUserId.isNotBlank() && weekKey.isNotBlank() && weekStartDayKey.isNotBlank()) {
            "weekly.identity_invalid"
        }
        current.lastObservedWeekStartDayKey?.let { previous ->
            if (weekStartDayKey < previous) return current
        }
        val program = if (current.weekKey == weekKey) {
            reconcile(current, eligibility, stableUserId)
        } else {
            make(weekKey, stableUserId, eligibility) ?: return current
        }
        return program.copy(
            stamps = current.stamps,
            lastObservedWeekStartDayKey = weekStartDayKey,
            processedReceiptIds = if (current.weekKey == weekKey) current.processedReceiptIds else emptyList(),
            playedDayKeys = if (current.weekKey == weekKey) current.playedDayKeys else emptyList(),
        )
    }

    public fun record(
        state: HighSchoolWeeklyState,
        id: String,
        amount: Int = 1,
        receiptId: String? = null,
        dayKey: String? = null,
    ): HighSchoolWeeklyState {
        if (amount <= 0 || receiptId.isNullOrBlank()) return state
        if (receiptId in state.processedReceiptIds) return state
        val eventDayKey = dayKey?.takeIf(String::isNotBlank)
        if (eventDayKey != null) {
            val eventDate = parseDay(eventDayKey) ?: return state
            val lastObserved = state.lastObservedWeekStartDayKey?.let(::parseDay)
            if (lastObserved != null && eventDate.isBefore(lastObserved)) return state
            if (weekKey(eventDate) != state.weekKey) return state
        }
        val playedDays = if (id == "played_on_two_days" && !dayKey.isNullOrBlank() && dayKey !in state.playedDayKeys) {
            (state.playedDayKeys + dayKey).distinct().sorted().takeLast(32)
        } else state.playedDayKeys
        val effectiveAmount = if (id == "played_on_two_days" && dayKey != null) {
            playedDays.size
        } else amount
        val tasks = state.tasks.map { task ->
            if (task.id != id && task.kind != id) task else {
                val progress = (task.progress + effectiveAmount).coerceAtMost(task.target)
                task.copy(progress = progress, completed = progress >= task.target, kind = task.kind.ifBlank { id })
            }
        }
        val receipts = (state.processedReceiptIds + receiptId).distinct().takeLast(2_000)
        val updated = state.copy(tasks = tasks, processedReceiptIds = receipts, playedDayKeys = playedDays)
        return upgradePerfectStamp(updated)
    }

    public fun completeCount(state: HighSchoolWeeklyState): Int = state.tasks.count { it.completed }

    public fun claim(state: HighSchoolWeeklyState, earnedAtUnixSeconds: Long): HighSchoolWeeklyState {
        if (state.rewardClaimed || completeCount(state) < 2) return state
        val stamp = HighSchoolWeeklyStamp(
            weekKey = state.weekKey,
            completedTaskCount = completeCount(state),
            perfect = state.tasks.isNotEmpty() && completeCount(state) == state.tasks.size,
            earnedAtUnixSeconds = earnedAtUnixSeconds,
        )
        return state.copy(
            rewardClaimed = true,
            stamps = (listOf(stamp) + state.stamps.filterNot { it.weekKey == state.weekKey }).take(64),
        )
    }

    public fun eligibleKinds(value: Eligibility): List<String> = buildList {
        if (value.hasHighSchoolCareer) {
            if (value.remainingImportantGames >= target("important_games_completed")) add("important_games_completed")
            if (value.remainingChapterAdvances >= target("chapters_advanced")) add("chapters_advanced")
        }
        if (value.dailyInningUnlocked) add("daily_inning_completed")
        if (value.canStartNextRun) add("next_run_started")
        if (value.canSelectPledge) add("pledge_selected")
        if (value.canChooseDifferentSchool) add("different_school_selected")
        if (value.hasHighSchoolCareer || value.hasProCareer) {
            add("sequence_mastery_triggered")
            add("played_on_two_days")
        }
        if (value.hasProCareer) add("pro_weeks_advanced")
    }

    private fun target(kind: String): Int = definitions.firstOrNull { it.first == kind }?.second ?: 1

    private fun reconcile(
        current: HighSchoolWeeklyState,
        eligibility: Eligibility,
        stableUserId: String,
    ): HighSchoolWeeklyState {
        val eligible = eligibleKinds(eligibility)
            .sortedWith(compareBy<String> { Hashing.fnv1a64Hex("$stableUserId|${current.weekKey}|$it|weekly-v1") }.thenBy { it })
        val eligibleSet = eligible.toSet()
        val replace = current.tasks.withIndex().filter { (_, task) ->
            !task.completed &&
                !stillFeasible(task, eligibleSet, eligibility)
        }.map { it.index }
        if (replace.isEmpty()) return current

        val retained = current.tasks.withIndex()
            .filterNot { it.index in replace }
            .map { it.value.kind.ifBlank { it.value.id } }
            .toSet()
        val replacements = eligible.filter { it !in retained }.toMutableList()
        val tasks = current.tasks.toMutableList()
        replace.forEach { index ->
            val old = tasks[index]
            val replacement = replacements.firstOrNull()
            if (replacement != null) {
                replacements.removeAt(0)
                tasks[index] = HighSchoolWeeklyTask("${current.weekKey}-$replacement", target(replacement), kind = replacement)
            } else if (old.kind == "daily_inning_completed" || old.id.endsWith("-daily_inning_completed")) {
                tasks[index] = old.copy(progress = old.target, completed = true, kind = old.kind.ifBlank { "daily_inning_completed" })
            }
        }
        return current.copy(tasks = tasks, rewardClaimed = current.rewardClaimed)
    }

    private fun stillFeasible(task: HighSchoolWeeklyTask, eligible: Set<String>, eligibility: Eligibility): Boolean {
        val kind = task.kind.ifBlank { task.id.substringAfterLast('-') }
        return when (kind) {
            "important_games_completed" -> eligibility.hasHighSchoolCareer &&
                minOf(task.target, task.progress.coerceAtLeast(0)) + eligibility.remainingImportantGames.coerceAtLeast(0) >= task.target
            "chapters_advanced" -> eligibility.hasHighSchoolCareer &&
                minOf(task.target, task.progress.coerceAtLeast(0)) + eligibility.remainingChapterAdvances.coerceAtLeast(0) >= task.target
            else -> kind in eligible
        }
    }

    private fun upgradePerfectStamp(state: HighSchoolWeeklyState): HighSchoolWeeklyState {
        if (!state.rewardClaimed || state.tasks.isEmpty() || completeCount(state) != state.tasks.size) return state
        return state.copy(stamps = state.stamps.map { stamp ->
            if (stamp.weekKey == state.weekKey && !stamp.perfect) stamp.copy(
                completedTaskCount = completeCount(state), perfect = true,
            ) else stamp
        })
    }

    private fun parseDay(value: String): LocalDate? {
        val formatters = listOf(DateTimeFormatter.ISO_LOCAL_DATE, DateTimeFormatter.BASIC_ISO_DATE)
        return formatters.firstNotNullOfOrNull { formatter ->
            try { LocalDate.parse(value, formatter) } catch (_: DateTimeParseException) { null }
        }
    }

    private fun weekKey(value: LocalDate): String {
        val weekFields = WeekFields.ISO
        return "%04d-W%02d".format(
            java.util.Locale.ROOT,
            value.get(weekFields.weekBasedYear()),
            value.get(weekFields.weekOfWeekBasedYear()),
        )
    }
}

public object HighSchoolAchievementRules {
    public const val FIRST_DRAFT: String = "first_draft"
    public const val FIRST_STRIKEOUT: String = "first_strikeout"
    public const val CLEAN_INNING: String = "clean_inning"
    public const val PERFECT_DELIVERY: String = "perfect_delivery"
    public const val MAJOR_DEBUT: String = "major_debut"
    public const val HUNDRED_STRIKEOUTS: String = "hundred_strikeouts"
    public const val THIRD_LIFE: String = "third_life"
    public const val FIFTH_LIFE: String = "fifth_life"
    public const val TENTH_LIFE: String = "tenth_life"
    public const val KARMA_RUN: String = "karma_run"
    public const val DOUBLE_KARMA: String = "double_karma"
    public const val AWAKENED_THRICE: String = "awakened_thrice"
    public const val FOUR_SCHOOLS: String = "four_schools"
    public const val FIVE_DRAFTS: String = "five_drafts"
    public const val HALL_OF_FAME: String = "hall_of_fame"

    public val all: List<String> = listOf(
        FIRST_DRAFT, FIRST_STRIKEOUT, CLEAN_INNING, PERFECT_DELIVERY, MAJOR_DEBUT,
        HUNDRED_STRIKEOUTS, THIRD_LIFE, FIFTH_LIFE, TENTH_LIFE, KARMA_RUN, DOUBLE_KARMA,
        AWAKENED_THRICE, FOUR_SCHOOLS, FIVE_DRAFTS, HALL_OF_FAME,
    )

    public data class Progress(
        val unlocked: List<String>,
        val unacknowledged: List<String>,
    )

    public fun normalize(values: Iterable<String>): List<String> = values
        .filter(String::isNotBlank)
        .distinct()
        .sorted()

    /** C# Meta semantics: unknown future IDs are retained and only fresh IDs become pending. */
    public fun unlock(
        unlocked: Iterable<String>,
        unacknowledged: Iterable<String>,
        earned: Iterable<String>,
    ): Progress {
        val current = normalize(unlocked)
        val fresh = normalize(earned).filterNot { it in current }
        return Progress(
            unlocked = normalize(current + fresh),
            unacknowledged = normalize(unacknowledged + fresh),
        )
    }

    public fun acknowledge(
        unlocked: Iterable<String>,
        unacknowledged: Iterable<String>,
        achievementId: String,
    ): Progress {
        require(achievementId.isNotBlank()) { "achievement.id_invalid" }
        return Progress(normalize(unlocked), normalize(unacknowledged).filterNot { it == achievementId })
    }

    public fun updateHighSchool(current: Set<String>, state: HighSchoolState, archive: List<HighSchoolArchiveRecord>): Set<String> {
        val next = current.toMutableSet()
        if (state.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED) next += FIRST_DRAFT
        if (state.performance.strikeouts >= 1) next += FIRST_STRIKEOUT
        if (state.selectedAwakenings.size >= 3) next += AWAKENED_THRICE
        if (state.karmas.isNotEmpty() && state.draftResult != null) next += KARMA_RUN
        if (state.karmas.size >= 2 && state.draftResult != null) next += DOUBLE_KARMA
        if (state.lifeNumber >= 3) next += THIRD_LIFE
        if (state.lifeNumber >= 5) next += FIFTH_LIFE
        if (state.lifeNumber >= 10) next += TENTH_LIFE
        if (archive.mapNotNull { it.schoolId }.toSet().size >= 4) next += FOUR_SCHOOLS
        if (archive.count { it.drafted } >= 5) next += FIVE_DRAFTS
        return next
    }

    public fun updateDelivery(current: Set<String>, releaseAccuracy: Int, aimAccuracy: Int): Set<String> =
        if (releaseAccuracy >= 900 && aimAccuracy >= 900) current + PERFECT_DELIVERY else current

    public fun updateReport(current: Set<String>, report: HighSchoolGameReport): Set<String> = buildSet {
        addAll(current)
        if (report.strikeouts >= 1) add(FIRST_STRIKEOUT)
        if (report.runsAllowed == 0 && report.pitches > 0) add(CLEAN_INNING)
    }
}

public object HighSchoolTournamentRules {
    public const val BOARD_SIZE: Int = 8

    private val names = mapOf(
        2 to "청룡곡 여름 초청전",
        4 to "전국 화랑기",
        6 to "가을 왕중왕전",
        8 to "최후의 여름 — 전국 선수권",
    )
    private val schoolPool = listOf(
        "북부상고", "남해정보고", "동성공고", "서령고", "중앙체고", "한서고",
        "대양고", "청암고", "금강고", "삼도고", "백파고", "운암공고",
    )

    public fun snapshot(careerId: String, chapter: Int, playerSchool: String = ""): HighSchoolTournamentSnapshot? {
        val name = names[chapter] ?: return null
        val round = when {
            chapter >= 8 -> "결승"
            chapter >= 6 -> "준결승"
            else -> "8강"
        }
        val generator = SplitMix64(StableHash.fnv1a64("bracket|$careerId|$chapter").toULong(16))
        val used = mutableSetOf(playerSchool)
        val field = mutableListOf<String>()
        while (field.size < BOARD_SIZE - 1) {
            val school = schoolPool[generator.nextInt(schoolPool.size)]
            if (used.add(school)) field += school
        }
        field.add(generator.nextInt(BOARD_SIZE), playerSchool)
        return HighSchoolTournamentSnapshot(
            chapter = chapter,
            name = name,
            playerRound = round,
            bracketSeed = Hashing.fnv1a64Hex("bracket|$careerId|$chapter"),
            completed = false,
            schools = field,
        )
    }
}

/** Exact Swift LeagueBaseline/DecisionRules projection for a directly played high-school line. */
public object HighSchoolSeasonLineRules {
    private val RUN_WEIGHTS_PERMILLE = intArrayOf(70, 92, 112, 124, 126, 116, 100, 80, 62, 45, 32, 21, 13, 7, 0)

    public fun highSchoolTeamRuns(rng: SplitMix64): Int {
        val roll = rng.nextInt(1_000)
        var cumulative = 0
        RUN_WEIGHTS_PERMILLE.forEachIndexed { runs, weight ->
            cumulative += weight
            if (roll < cumulative) return runs
        }
        return RUN_WEIGHTS_PERMILLE.lastIndex
    }

    public fun restOfHighSchoolTeamRuns(outsCovered: Int, rng: SplitMix64): Int =
        highSchoolTeamRuns(rng) * maxOf(0, outsCovered) / 27

    public fun line(
        seed: String,
        state: HighSchoolState,
        report: HighSchoolGameReport,
        outingNumber: Int,
    ): HighSchoolSeasonLine {
        val seedValue = seed.toULongOrNull() ?: throw IllegalArgumentException("seasonLine.seed")
        val rng = SplitMix64(seedValue xor 0x4853504C4159UL)
        val outs = report.outs ?: 0
        val support: Int
        val opponentRuns: Int
        if (report.scoreDifferentialAtEntry != null) {
            val opponentEarlier = rng.nextInt(3)
            opponentRuns = opponentEarlier + report.runsAllowed
            support = maxOf(0, opponentEarlier + report.scoreDifferentialAtEntry + rng.nextInt(2))
        } else {
            support = highSchoolTeamRuns(rng)
            opponentRuns = report.runsAllowed + restOfHighSchoolTeamRuns(maxOf(0, 27 - outs), rng)
        }
        val decision = when {
            support < opponentRuns && report.runsAllowed > 0 -> HighSchoolPitchingDecision.LOSS
            else -> HighSchoolPitchingDecision.NO_DECISION
        }
        return HighSchoolSeasonLine(
            careerId = state.careerId,
            lifeNumber = state.lifeNumber,
            chapter = state.chapter.number,
            gameNumber = report.scenarioNumber,
            pitches = report.pitches,
            strikeouts = report.strikeouts,
            walks = report.walks,
            runsAllowed = report.runsAllowed,
            expectedDamage = report.expectedDamage,
            actualDamage = report.actualDamage,
            abilityMoments = emptyList(),
            rivalStrikeouts = 0,
            season = state.chapter.schoolYear,
            week = state.chapter.number,
            outingNumber = outingNumber,
            started = false,
            outs = outs,
            teamRuns = support,
            opponentRuns = opponentRuns,
            decision = decision,
            played = true,
            hits = report.hits ?: 0,
            homeRuns = report.homeRuns ?: 0,
        )
    }
}

public object HighSchoolProspectRankingRules {
    public const val BOARD_SIZE: Int = 20

    private val surnames = listOf("강", "고", "권", "김", "도", "문", "박", "배", "서", "신", "안", "유", "이", "임", "정", "조", "차", "최", "한", "황")
    private val givenNames = listOf("도현", "민재", "서준", "예준", "시우", "하준", "지호", "은찬", "준서", "건우", "현빈", "태윤", "재민", "성민", "규현", "동주", "찬영", "우진", "석현", "영웅")
    private val schools = listOf("북부상고", "남해정보고", "동성공고", "서령고", "중앙체고", "한서고", "대양고", "청암고", "금강고", "삼도고")
    private val tags = listOf(
        "최고 구속으로 스카우트 보고서 첫 줄을 차지한 파이어볼러",
        "존 네 귀퉁이를 마음대로 쓰는 완성형 제구",
        "각이 다른 종변화구 — 헛스윙 유도 1위",
        "3학년 여름에 만개한 늦깎이 에이스",
        "이닝을 먹는 체력 — 완투가 기본",
        "위기에서만 구속이 오르는 승부사",
        "중학 시절부터 이름난 엘리트 코스",
        "무명 학교에서 혼자 팀을 끌어올린 화제의 투수",
        "타자들이 타이밍을 못 잡는 디셉션",
        "부상 복귀 후 더 강해져 돌아온 재활의 표본",
    )

    public fun playerRank(state: HighSchoolState): Int? {
        val games = state.performance.importantGamesCompleted
        if (games <= 0) return null
        val score = state.performance.strikeouts * 3 - state.performance.walks * 2 - state.performance.runsAllowed * 3 + games * 4
        return maxOf(1, 60 - score * 59 / 90)
    }

    public fun board(state: HighSchoolState): List<HighSchoolProspectEntry> {
        // Swift/C# do not expose an extra numeric score on this read model. The retained Kotlin
        // field is therefore a non-authoritative zero sentinel; rank/name/school/tag/isPlayer are
        // the exact source-backed fields and are never synthesized from a second score formula.
        val generator = SplitMix64(StableHash.fnv1a64("prospect|${state.careerId}").toULong(16))
        val used = mutableSetOf(state.identity.name)
        val rivals = mutableListOf<Triple<String, String, String>>()
        while (rivals.size < BOARD_SIZE) {
            val name = surnames[generator.nextInt(surnames.size)] + givenNames[generator.nextInt(givenNames.size)]
            if (!used.add(name)) continue
            rivals += Triple(
                name,
                schools[generator.nextInt(schools.size)],
                tags[generator.nextInt(tags.size)],
            )
        }

        val mine = playerRank(state)
        val playerSchool = state.school?.name ?: state.identity.region
        val result = mutableListOf<HighSchoolProspectEntry>()
        var rivalIndex = 0
        for (rank in 1..BOARD_SIZE) {
            if (mine == rank) {
                result += HighSchoolProspectEntry(
                    playerId = "player-${state.careerId}",
                    name = state.identity.name,
                    schoolName = playerSchool,
                    rank = rank,
                    score = 0,
                    isCurrentPlayer = true,
                    tag = "이 명단에서 유일하게 당신이 키우는 선수",
                )
            } else {
                val rival = rivals[rivalIndex++]
                result += HighSchoolProspectEntry(
                    playerId = "prospect-$rivalIndex",
                    name = rival.first,
                    schoolName = rival.second,
                    rank = rank,
                    score = 0,
                    isCurrentPlayer = false,
                    tag = rival.third,
                )
            }
        }
        return result
    }
}

/** Exact current Swift `HighSchoolCareerEngine.teams` draft read model. */
public object HighSchoolDraftTeamRules {
    public val teams: List<HighSchoolDraftTeam> = listOf(
        HighSchoolDraftTeam("seoul_comets", "서울 코메츠", HighSchoolTrainingFocus.COMMAND, 72, "2군 선발로 뛰며 원하는 코스에 던지는 능력 향상", "차윤호", "문재석", "느린 커브와 타이밍 싸움으로 살아남은 베테랑 선발", "최근 시즌 9승 · ERA 3.91", "선수와 대화부터 시작하는 수비 중심 지도자", "3년 연속 포스트시즌 진출"),
        HighSchoolDraftTeam("busan_marines", "부산 블루웨일스", HighSchoolTrainingFocus.STAMINA, 66, "긴 이닝을 맡는 선발로 훈련", "도현우", "강태림", "높은 포심과 낙차 큰 포크볼을 앞세운 우완 에이스", "최근 시즌 11승 · 142탈삼진", "큰 경기일수록 선발에게 한 이닝을 더 맡기는 승부사", "챔피언십 시리즈 진출 2회"),
        HighSchoolDraftTeam("incheon_waves", "인천 크레스트핀스", HighSchoolTrainingFocus.BREAKING_BALL, 70, "결정구 한 종을 프로 수준으로 강화", "백승찬", "윤도환", "슬라이더와 템포 변화로 버티는 왼손 선발", "최근 시즌 8승 · 126탈삼진", "베테랑 자율과 강한 수비를 함께 요구하는 감독", "정규시즌 상위 3위 2회"),
        HighSchoolDraftTeam("daegu_forge", "대구 포지", HighSchoolTrainingFocus.VELOCITY, 75, "빠른 직구를 유지하며 불펜으로 빠른 1군 데뷔", "신재원", "권민철", "낮은 코스와 완급을 반복하는 젊은 우완 에이스", "최근 시즌 12승 · ERA 3.44", "기본 수비와 세대교체를 함께 밀어붙이는 내야 출신 지도자", "신인 투수 4명 1군 데뷔"),
        HighSchoolDraftTeam("daejeon_rockets", "대전 로켓츠", HighSchoolTrainingFocus.GAME_PLANNING, 68, "포수와 구종 순서를 맞추는 선발 훈련", "장하준", "배성우", "빠른 포심으로 타자의 배트를 늦추는 파이어볼러", "최고 158.2km/h · 134탈삼진", "한번 고른 선발은 충분한 기회를 주는 장기 운영형 감독", "3년 연속 승률 5할 이상"),
        HighSchoolDraftTeam("gwangju_phoenix", "광주 피닉스", HighSchoolTrainingFocus.BREAKING_BALL, 64, "직구와 같은 궤도에서 갈라지는 변화구 훈련", "서이준", "남기석", "큰 각도의 커브로 삼진을 쌓는 왼손 정통파", "최근 시즌 10승 · 151탈삼진", "선수를 믿고 공격적으로 뛰게 하는 젊은 감독", "최근 2년 승률 .561"),
        HighSchoolDraftTeam("suwon_guardians", "수원 가디언즈", HighSchoolTrainingFocus.COMMAND, 61, "볼넷을 줄인 뒤 1군 긴 이닝 구원으로 데뷔", "주성민", "오태건", "낮은 팔 각도와 체인지업으로 볼넷을 줄이는 선발", "최근 시즌 BB/9 1.8 · 퀄리티스타트 17회", "투수의 팔이 나오는 타이밍을 직접 잡는 잠수함 출신 지도자", "4년 연속 포스트시즌 진출"),
        HighSchoolDraftTeam("changwon_meteors", "창원 미티어스", HighSchoolTrainingFocus.VELOCITY, 69, "직구의 움직임과 최고 구속을 함께 향상", "류한결", "차경호", "회전이 좋은 왼손 직구로 뜬공을 만드는 선발", "최근 시즌 ERA 2.48 · 9승", "타격 이론과 편안한 소통을 함께 쓰는 감독", "주전 3명 개인 최고 기록 달성"),
        HighSchoolDraftTeam("jeonju_hanok", "전주 한울스", HighSchoolTrainingFocus.STAMINA, 58, "체력을 키워 선발 한 자리에 도전", "문시온", "신도영", "빠른 포심과 짧은 슬라이더로 삼진을 모으는 우완 선발", "최근 시즌 178탈삼진 · ERA 2.71", "젊은 선수에게 먼저 기회를 주는 장기 육성형 감독", "신인 6명 1군 출전 명단 등록"),
        HighSchoolDraftTeam("jeju_storm", "제주 스톰", HighSchoolTrainingFocus.GAME_PLANNING, 63, "기록을 활용해 선발과 구원을 오가는 투수로 훈련", "한유찬", "조민규", "묵직한 포심과 컷패스트볼로 긴 이닝을 버티는 우완 선발", "최근 시즌 13승 · 147탈삼진", "큰 경기 경험을 바탕으로 한 번의 강한 승부를 강조하는 감독", "포스트시즌 진출 3회"),
    )

    public fun bestTeam(pitcher: HighSchoolPitcher): HighSchoolDraftTeam {
        fun value(focus: HighSchoolTrainingFocus): Int = when (focus) {
            HighSchoolTrainingFocus.VELOCITY -> pitcher.stuff
            HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingFocus.GAME_PLANNING -> pitcher.command
            HighSchoolTrainingFocus.BREAKING_BALL -> pitcher.movement
            HighSchoolTrainingFocus.STAMINA, HighSchoolTrainingFocus.RECOVERY -> pitcher.stamina
        }
        return teams.maxBy { value(it.need) * 10 + it.demand }
    }

    public fun bestTeamId(pitcher: HighSchoolPitcher): String = bestTeam(pitcher).id
}
