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
    public const val RULES_VERSION: Int = 2
    public const val BALANCE_VERSION: Int = 4
    public const val MAXIMUM_CAREER_SEASONS: Int = 20
    public const val WEEKS_PER_SEASON: Int = 24
    public const val DEMOTION_TRUST: Int = 34
    public val SEASON_DECISION_WEEKS: List<Int> = listOf(6, 13, 20)

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
        ProSeasonSegment.ALL_STAR_BREAK -> "올스타 휴식기"
        ProSeasonSegment.PENNANT_RACE -> "순위 경쟁"
        ProSeasonSegment.SEASON_FINALE -> "시즌 결말"
    }

    public fun segmentEntryNews(segment: ProSeasonSegment): String = when (segment) {
        ProSeasonSegment.SPRING_CAMP -> "스프링캠프가 열렸습니다. 새 시즌 준비를 시작합니다."
        ProSeasonSegment.OPENING -> "개막 시리즈가 시작됐습니다. 첫인상을 남길 시간입니다."
        ProSeasonSegment.FIRST_HALF -> "전반기 레이스에 들어섰습니다. 긴 시즌의 리듬을 잡습니다."
        ProSeasonSegment.ALL_STAR_BREAK -> "올스타 휴식기입니다. 몸을 추스르고 후반기를 준비합니다."
        ProSeasonSegment.PENNANT_RACE -> "순위 경쟁이 뜨거워집니다. 한 경기의 무게가 커집니다."
        ProSeasonSegment.SEASON_FINALE -> "시즌 막바지, 마지막 순위 싸움이 남았습니다."
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
        rival("pro-rival-seoul", "강도훈", "중심 타선 해결사형", "seoul_comets", "서울 코메츠", "최근 3시즌 82홈런 · OPS .901", "카운트가 몰려도 스윙이 짧아지지 않습니다. 바깥쪽 승부를 기다렸다 밀어칩니다."),
        rival("pro-rival-busan", "마태오", "우측 담장 거포형", "busan_marines", "부산 블루웨일스", "최근 3시즌 96홈런 · 장타율 .571", "낮게 깔린 공을 퍼올려 우측 담장을 넘깁니다. 몸쪽 실투 한 개를 놓치지 않습니다."),
        rival("pro-rival-incheon", "백건우", "교타 정확형", "incheon_waves", "인천 크레스트핀스", "통산 타율 .318 · 3년 연속 150안타", "파울로 승부를 늘리다 결정구를 받아칩니다. 삼진보다 인플레이 타구가 많습니다."),
        rival("pro-rival-daegu", "노진성", "당겨치는 홈런형", "daegu_forge", "대구 포지", "지난 시즌 34홈런 · 최다 장타", "빠른 배트로 안쪽 공을 끌어당깁니다. 초구부터 노림수를 숨기지 않습니다."),
        rival("pro-rival-daejeon", "천우재", "선구안 출루형", "daejeon_rockets", "대전 로켓츠", "출루율 .420 · 볼넷 최다", "존을 벗어난 공에는 손이 나가지 않습니다. 풀카운트 승부를 두려워하지 않습니다."),
        rival("pro-rival-gwangju", "서강윤", "중장거리 갭 히터형", "gwangju_phoenix", "광주 피닉스", "2루타 최다 · OPS .880", "좌중간 갭을 노려 장타를 만듭니다. 변화구 타이밍에 강합니다."),
        rival("pro-rival-suwon", "구본혁", "컨택 무결점형", "suwon_guardians", "수원 가디언즈", "5년 연속 3할·두 자릿수 홈런", "약점 코스가 뚜렷하지 않습니다. 어떤 구종이든 중심에 맞힙니다."),
        rival("pro-rival-changwon", "류성권", "장신 파워형", "changwon_meteors", "창원 미티어스", "지난 시즌 40홈런 · 장타율 .612", "긴 리치로 바깥쪽까지 커버합니다. 높은 공을 그대로 받아넘깁니다."),
        rival("pro-rival-jeonju", "문태경", "빠른 발 갭 타자형", "jeonju_hanok", "전주 한울스", "3년 연속 3할·30도루", "짧게 끊어치고 곧바로 다음 베이스를 노립니다. 실투가 곧 실점입니다."),
        rival("pro-rival-jeju", "한도결", "득점권 해결사형", "jeju_storm", "제주 스톰", "득점권 타율 .352 · 끝내기 다수", "주자가 있을 때 스윙이 더 단단해집니다. 넓은 존을 커버하는 배드볼 히터입니다."),
    )

    public fun rivalFor(teamId: String, season: Int, week: Int, trigger: ProSeasonTrigger): ProRivalBatter {
        val value = StableHash.fnv1a64("$teamId|season$season|week$week|${trigger.wire}").toULong(16)
        var index = (value % rivals.size.toULong()).toInt()
        if (rivals[index].teamId == teamId) index = (index + 1) % rivals.size
        return rivals[index]
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
