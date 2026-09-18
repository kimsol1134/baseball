package com.solkim.baseball.core.pro

import com.solkim.baseball.core.StableHash
import com.solkim.baseball.core.SplitMix64
import com.solkim.baseball.core.highschool.HighSchoolDraftTeamRules
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchProfileSnapshot
import com.solkim.baseball.core.pitch.PitchUsageRole
import com.solkim.baseball.core.pitch.PitcherSnapshot
import kotlin.math.max

/** Frozen fictional pro catalog copied from the current Swift/C# source set. */
public object ProCatalog {
    /** Pro schedule, fatigue, and overload-injury rules currently used by new careers. */
    public const val RULES_VERSION: Int = 13
    public const val BALANCE_VERSION: Int = 4
    public const val MAXIMUM_CAREER_SEASONS: Int = 20
    public const val WEEKS_PER_SEASON: Int = 24

    public fun expectedRemainingOutings(week: Int, injuryWeeks: Int, role: ProRole, rulesVersion: Int = RULES_VERSION): Int {
        return ((week + max(0, injuryWeeks) + 1)..WEEKS_PER_SEASON).sumOf {
            weeklyOutingBudget(role, it, rulesVersion).first
        }
    }
    public const val DEMOTION_TRUST: Int = 34
    /** "320000000" → "3억 2,000만원". Player-facing money in news and cards. */
    public fun money(value: Long): String {
        val eok = value / 100_000_000L
        val man = (value % 100_000_000L) / 10_000L
        val rest = value % 10_000L
        return buildString {
            if (eok > 0) append("${eok}억")
            if (man > 0) { if (isNotEmpty()) append(' '); append(String.format(java.util.Locale.KOREA, "%,d만", man)) }
            if (isEmpty() || rest > 0) { if (isNotEmpty()) append(' '); append(String.format(java.util.Locale.KOREA, "%,d", rest)) }
            append("원")
        }
    }
    public val SEASON_DECISION_WEEKS: List<Int> = listOf(6, 13, 20)
    public val WEEKLY_SEASON_DECISION_WEEKS: List<Int> = listOf(3, 6, 9, 12, 15, 18, 21)
    public val COMPATIBLE_DECISION_WEEKS: List<Int> = (SEASON_DECISION_WEEKS + WEEKLY_SEASON_DECISION_WEEKS).distinct().sorted()

    public fun decisionWeeks(rulesVersion: Int): List<Int> =
        if (rulesVersion >= 9) WEEKLY_SEASON_DECISION_WEEKS else SEASON_DECISION_WEEKS

    public fun maximumDecisions(rulesVersion: Int): Int = if (rulesVersion >= 9) 7 else 3

    public fun maximumContractYears(rulesVersion: Int): Int = if (rulesVersion >= 10) 5 else 4

    public fun mediaOpportunityWeek(careerId: String, season: Int, rulesVersion: Int): Int {
        val weeks = decisionWeeks(rulesVersion)
        return weeks[(proHash("$careerId|$season|media") % weeks.size.toULong()).toInt()]
    }

    public val teams: List<ProTeam> = HighSchoolDraftTeamRules.teams.map {
        ProTeam(it.id, it.name, it.positionCompetitor, it.developmentPlan, it.demand)
    }

    public fun team(id: String): ProTeam = teams.firstOrNull { it.id == id }
        ?: error("pro.team_unknown:$id")

    public fun teamForSeed(seed: ULong): ProTeam {
        val rng = SplitMix64(seed)
        return teams[rng.nextInt(teams.size)]
    }

    public fun segment(week: Int): ProSeasonSegment = when (week) {
        0 -> ProSeasonSegment.SPRING_CAMP
        in 1..4 -> ProSeasonSegment.OPENING
        in 5..10 -> ProSeasonSegment.FIRST_HALF
        in 11..13 -> ProSeasonSegment.ALL_STAR_BREAK
        in 14..20 -> ProSeasonSegment.PENNANT_RACE
        else -> ProSeasonSegment.SEASON_FINALE
    }

    public fun segmentLabel(segment: ProSeasonSegment): String = when (segment) {
        ProSeasonSegment.SPRING_CAMP -> "스프링캠프"
        ProSeasonSegment.OPENING -> "개막"
        ProSeasonSegment.FIRST_HALF -> "전반기"
        ProSeasonSegment.ALL_STAR_BREAK -> "올스타 브레이크"
        ProSeasonSegment.PENNANT_RACE -> "페넌트레이스"
        ProSeasonSegment.SEASON_FINALE -> "시즌 막바지"
    }

    public fun segmentEntryNews(segment: ProSeasonSegment): String = when (segment) {
        ProSeasonSegment.SPRING_CAMP -> "스프링캠프. 새 시즌이 몸에서부터 시작된다."
        ProSeasonSegment.OPENING -> "개막 시리즈. 첫인상을 남길 시간이다."
        ProSeasonSegment.FIRST_HALF -> "전반기 레이스. 긴 시즌의 리듬을 잡는다."
        ProSeasonSegment.ALL_STAR_BREAK -> "올스타 휴식기. 몸을 추스르고 후반기를 준비한다."
        ProSeasonSegment.PENNANT_RACE -> "순위 경쟁이 뜨거워집니다. 한 경기의 무게가 커집니다."
        ProSeasonSegment.SEASON_FINALE -> "시즌 막바지. 마지막 순위 싸움이 남았다."
    }

    public val presetPitchers: Map<String, PitcherSnapshot> = mapOf(
        "power_prospect" to PitcherSnapshot(
            "pitcher-power", "민서준", 42, 34, 36, 38,
            profiles(
                profile(PitchKind.FOUR_SEAM, PitchUsageRole.PRIMARY, 1410, 35, 32, 37, 45, 41, 2),
                profile(PitchKind.SLIDER, PitchUsageRole.SECONDARY, 1240, 31, 29, 40, 41, 38, 2),
                profile(PitchKind.CURVEBALL, PitchUsageRole.SECONDARY, 1090, 27, 26, 38, 33, 35, 2),
                profile(PitchKind.CHANGEUP, PitchUsageRole.DEVELOPMENT, 1210, 23, 22, 31, 28, 31, 2),
            ),
        ),
        "precision_commander" to PitcherSnapshot(
            "pitcher-command", "고태윤", 34, 43, 35, 38,
            profiles(
                profile(PitchKind.FOUR_SEAM, PitchUsageRole.PRIMARY, 1340, 45, 44, 34, 33, 39, 1),
                profile(PitchKind.SLIDER, PitchUsageRole.SECONDARY, 1190, 41, 42, 39, 37, 40, 1),
                profile(PitchKind.CURVEBALL, PitchUsageRole.DEVELOPMENT, 1060, 31, 33, 37, 29, 34, 2),
                profile(PitchKind.CHANGEUP, PitchUsageRole.SECONDARY, 1210, 43, 44, 39, 36, 42, 1),
            ),
        ),
        "breaking_ball_artist" to PitcherSnapshot(
            "pitcher-artist", "진서율", 37, 34, 44, 35,
            profiles(
                profile(PitchKind.FOUR_SEAM, PitchUsageRole.SECONDARY, 1360, 38, 35, 34, 33, 37, 1),
                profile(PitchKind.SLIDER, PitchUsageRole.PRIMARY, 1220, 39, 40, 46, 44, 45, 2),
                profile(PitchKind.CURVEBALL, PitchUsageRole.SECONDARY, 1080, 37, 39, 45, 41, 46, 2),
                profile(PitchKind.CHANGEUP, PitchUsageRole.DEVELOPMENT, 1200, 31, 33, 41, 38, 41, 2),
            ),
        ),
        "innings_eater" to PitcherSnapshot(
            "pitcher-stamina", "도하람", 37, 32, 37, 44,
            profiles(
                profile(PitchKind.FOUR_SEAM, PitchUsageRole.PRIMARY, 1370, 37, 36, 34, 32, 39, 0),
                profile(PitchKind.SLIDER, PitchUsageRole.SECONDARY, 1200, 34, 36, 37, 33, 39, 1),
                profile(PitchKind.CURVEBALL, PitchUsageRole.DEVELOPMENT, 1060, 29, 28, 35, 28, 34, 1),
                profile(PitchKind.CHANGEUP, PitchUsageRole.SECONDARY, 1210, 36, 37, 39, 34, 43, 0),
            ),
        ),
    )

    public fun pitcherForPreset(presetId: String, playerName: String): PitcherSnapshot {
        val source = presetPitchers[presetId] ?: error("pro.preset_unknown:$presetId")
        return source.copy(name = playerName)
    }

    public val rivals: List<ProRivalBatter> = listOf(
        rival("pro-rival-seoul", "강도훈", "중심 타선 해결사형", "seoul_comets", "서울 코메츠", "최근 3시즌 82홈런 · OPS .901", "카운트가 몰려도 스윙이 짧아지지 않는다. 바깥쪽을 기다렸다 밀어친다."),
        rival("pro-rival-busan", "마태오", "우측 담장 거포형", "busan_marines", "부산 블루웨일스", "최근 3시즌 96홈런 · 장타율 .571", "낮게 깔린 공을 퍼올려 우측 담장을 넘긴다. 몸쪽 실투 하나를 놓치지 않는다."),
        rival("pro-rival-incheon", "백건우", "교타 정확형", "incheon_waves", "인천 크레스트핀스", "통산 타율 .318 · 3년 연속 150안타", "파울로 승부를 늘리다 결정구를 받아친다. 삼진보다 인플레이 타구가 많다."),
        rival("pro-rival-daegu", "노진성", "당겨치는 홈런형", "daegu_forge", "대구 포지", "지난 시즌 34홈런 · 최다 장타", "빠른 배트로 안쪽 공을 끌어당긴다. 초구부터 노림수를 숨기지 않는다."),
        rival("pro-rival-daejeon", "천우재", "선구안 출루형", "daejeon_rockets", "대전 로켓츠", "출루율 .420 · 볼넷 최다", "존을 벗어난 공에는 손이 안 나간다. 풀카운트를 두려워하지 않는다."),
        rival("pro-rival-gwangju", "서강윤", "중장거리 갭 히터형", "gwangju_phoenix", "광주 피닉스", "2루타 최다 · OPS .880", "좌중간 갭을 노려 장타를 만든다. 변화구 타이밍에 강하다."),
        rival("pro-rival-suwon", "구본혁", "컨택 무결점형", "suwon_guardians", "수원 가디언즈", "5년 연속 3할·두 자릿수 홈런", "약점 코스가 뚜렷하지 않다. 어떤 구종이든 중심에 맞힌다."),
        rival("pro-rival-changwon", "류성권", "장신 파워형", "changwon_meteors", "창원 미티어스", "지난 시즌 40홈런 · 장타율 .612", "긴 리치로 바깥쪽까지 커버한다. 높은 공을 그대로 받아넘긴다."),
        rival("pro-rival-jeonju", "문태경", "빠른 발 갭 타자형", "jeonju_hanok", "전주 한울스", "3년 연속 3할·30도루", "짧게 끊어치고 곧바로 다음 베이스를 노린다. 실투가 곧 실점이다."),
        rival("pro-rival-jeju", "한도결", "득점권 해결사형", "jeju_storm", "제주 스톰", "득점권 타율 .352 · 끝내기 다수", "주자가 있으면 스윙이 더 단단해진다. 넓은 존을 커버하는 배드볼 히터."),
    )

    public fun rivalFor(
        teamId: String,
        season: Int,
        week: Int,
        trigger: ProSeasonTrigger,
        opponentTeamId: String? = null,
    ): ProRivalBatter {
        val matched = opponentTeamId?.let { id -> rivals.filter { it.teamId == id } } ?: emptyList()
        val pool = if (matched.isEmpty()) rivals else matched
        val value = StableHash.fnv1a64("$teamId|season$season|week$week|${trigger.wire}").toULong(16)
        var index = (value % pool.size.toULong()).toInt()
        if (pool[index].teamId == teamId) index = (index + 1) % pool.size
        return pool[index]
    }

    public fun profile(
        type: PitchKind,
        role: PitchUsageRole,
        velocity: Int,
        control: Int,
        command: Int,
        movement: Int,
        whiff: Int,
        weakContact: Int,
        fatigueCost: Int,
    ): PitchProfileSnapshot = PitchProfileSnapshot(type, role, velocity, control, command, movement, whiff, weakContact, fatigueCost)

    private fun profiles(vararg values: PitchProfileSnapshot): List<PitchProfileSnapshot> = values.toList()

    private fun rival(id: String, name: String, archetype: String, teamId: String, teamName: String, record: String, profile: String) =
        ProRivalBatter(id, name, archetype, teamId, teamName, record, profile)
}

public object ProLeagueBaseline {
    public val teamRunsPerGamePermille: List<Int> = listOf(62, 104, 131, 138, 135, 119, 95, 70, 50, 34, 22, 14, 9, 6, 4, 3, 2, 1, 1)
    public const val minimumOutsForStarterWin: Int = 15
    public const val saveLeadCeiling: Int = 3

    public fun teamRuns(rng: SplitMix64): Int = weighted(rng.nextInt(1_000), teamRunsPerGamePermille)

    public fun inningRuns(rng: SplitMix64): Int = when (rng.nextInt(1000)) {
        in 0..699 -> 0; in 700..849 -> 1; in 850..939 -> 2; in 940..979 -> 3; else -> 4
    }

    public fun restOfTeamRuns(outsCovered: Int, rng: SplitMix64): Int =
        teamRuns(rng) * max(0, outsCovered) / 27

    private fun weighted(roll: Int, weights: List<Int>): Int {
        var cumulative = 0
        weights.forEachIndexed { index, weight ->
            cumulative += weight
            if (roll < cumulative) return index
        }
        return weights.lastIndex
    }
}

public fun proDecision(
    started: Boolean,
    closer: Boolean,
    outs: Int,
    runsAllowed: Int,
    teamRuns: Int,
    opponentRuns: Int,
): ProPitchingDecision {
    val won = teamRuns > opponentRuns
    val lost = teamRuns < opponentRuns
    if (started) {
        if (won) return if (outs >= ProLeagueBaseline.minimumOutsForStarterWin) ProPitchingDecision.WIN else ProPitchingDecision.NO_DECISION
        return if (lost && runsAllowed > 0) ProPitchingDecision.LOSS else ProPitchingDecision.NO_DECISION
    }
    if (closer && won && runsAllowed == 0 && teamRuns - opponentRuns <= ProLeagueBaseline.saveLeadCeiling) return ProPitchingDecision.SAVE
    if (lost && runsAllowed > 0) return ProPitchingDecision.LOSS
    return ProPitchingDecision.NO_DECISION
}

public fun proHash(value: String): ULong = StableHash.fnv1a64(value).toULong(16)

private fun ProState.completedCareerStats(): List<ProSeasonStats> =
    if (careerStats.lastOrNull()?.season == currentStats.season) careerStats else careerStats + currentStats

public fun ProState.careerGames(): Int = completedCareerStats().sumOf { it.games }
public fun ProState.careerStrikeouts(): Int = completedCareerStats().sumOf { it.strikeouts }
public fun ProState.careerHits(): Int = completedCareerStats().sumOf { it.hits }
public fun ProState.careerWalks(): Int = completedCareerStats().sumOf { it.walks }
public fun ProState.careerWhipPermille(): Int {
    val outs = completedCareerStats().sumOf { it.inningsOuts }
    if (outs == 0) return 9_990
    return (careerHits() + careerWalks()) * 3_000 / outs
}
