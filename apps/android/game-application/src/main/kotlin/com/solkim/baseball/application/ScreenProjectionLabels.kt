package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolTournamentRules

import com.solkim.baseball.core.highschool.HighSchoolContentCatalog
import com.solkim.baseball.core.highschool.HighSchoolDifficulty
import com.solkim.baseball.core.highschool.HighSchoolPledgeRules
import com.solkim.baseball.core.highschool.HighSchoolAwakening
import com.solkim.baseball.core.highschool.HighSchoolAchievementRules
import com.solkim.baseball.core.highschool.HighSchoolDraftOutcome
import com.solkim.baseball.core.highschool.HighSchoolIdentity
import com.solkim.baseball.core.highschool.HighSchoolKarma
import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.highschool.HighSchoolState
import com.solkim.baseball.core.highschool.HighSchoolPhase4Command
import com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel
import com.solkim.baseball.core.highschool.HighSchoolPhase4StartRequest
import com.solkim.baseball.core.highschool.HighSchoolRebirthEntryPath
import com.solkim.baseball.core.highschool.HighSchoolRelationshipTarget
import com.solkim.baseball.core.highschool.HighSchoolRelationshipResponse
import com.solkim.baseball.core.highschool.HighSchoolReturnDestination
import com.solkim.baseball.core.highschool.HighSchoolSeasonLine
import com.solkim.baseball.core.highschool.HighSchoolSchoolId
import com.solkim.baseball.core.highschool.HighSchoolSignatureLegacyRules
import com.solkim.baseball.core.highschool.HighSchoolTrainingFocus
import com.solkim.baseball.core.highschool.HighSchoolTrainingIntensity
import com.solkim.baseball.core.pro.OffseasonDecision
import com.solkim.baseball.core.pro.ProCatalog
import com.solkim.baseball.core.pro.ProCareerPhase
import com.solkim.baseball.core.pro.ProCommand
import com.solkim.baseball.core.pro.ProDevelopmentFocus
import com.solkim.baseball.core.pro.ProEntitlement
import com.solkim.baseball.core.pro.ProFanReasonKind
import com.solkim.baseball.core.pro.ProGameLine
import com.solkim.baseball.core.pro.ProState
import com.solkim.baseball.core.pro.ProMerchandiseTier
import com.solkim.baseball.core.pro.ProSettlementNextRoute
import com.solkim.baseball.core.pro.ProOffseasonInvestment
import com.solkim.baseball.core.pro.ProHighSchoolLegacyContext
import com.solkim.baseball.core.pro.ProKernel
import com.solkim.baseball.core.pro.ProLevel
import com.solkim.baseball.core.pro.ProNationalTeamRules
import com.solkim.baseball.core.pro.ProNationalTournamentStage
import com.solkim.baseball.core.pro.ProRole
import com.solkim.baseball.core.pro.ProSeasonSegment
import com.solkim.baseball.core.pro.ProStartDirectRequest
import com.solkim.baseball.core.pro.ProStartLinkedRequest
import com.solkim.baseball.core.pro.ProWeekPlan
import com.solkim.baseball.core.pro.careerGames
import com.solkim.baseball.core.pro.careerStrikeouts
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchProfileSnapshot
import com.solkim.baseball.core.pitch.PitchUsageRole
import com.solkim.baseball.core.pitch.PitcherSnapshot
import com.solkim.baseball.model.Hashing
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.WeekFields


internal fun subtitle(id: ScreenId): String = when (id) {
    ScreenId.P001_OPENING -> "한 구씩, 한 생씩."
    ScreenId.P002_SETUP -> "이번 생의 이름과 출발점"
    ScreenId.P003_PROLOGUE -> "편지 한 통, 그리고 첫 공"
    ScreenId.P004_PITCH_TUTORIAL -> "기록에 안 남는 첫 공"
    ScreenId.P005_SCHOOL_SELECTION -> "3년을 보낼 학교"
    ScreenId.P006_TRAINING -> "오늘 몸에 남길 것"
    ScreenId.P007_RELATIONSHIP -> "짧은 대화, 달라지는 관계"
    ScreenId.P008_IMPORTANT_GAME -> "승부처, 내가 던진다"
    ScreenId.P009_AWAKENING -> "새로 깨어나는 감각"
    ScreenId.P010_CHAPTER -> "한 장을 덮고 다음 장으로"
    ScreenId.P011_HIGH_SCHOOL_CAREER -> "고교 3년의 기록"
    ScreenId.P012_TOURNAMENT_LEAGUE -> "대회와 라이벌"
    ScreenId.P013_DRAFT -> "이름이 불리는 날"
    ScreenId.P014_RUN_RECAP -> "이 생이 남긴 것"
    ScreenId.P015_REBIRTH -> "같은 나, 다시 1학년"
    ScreenId.P016_PRO_CONTRACT -> "어느 유니폼을 입을까"
    ScreenId.P017_PRO_WEEK -> "이번 주를 어떻게 보낼까"
    ScreenId.P018_PRO_IMPORTANT_GAME -> "프로의 승부처"
    ScreenId.P019_PRO_SEASON -> "시즌이 남긴 것"
    ScreenId.P020_OFFSEASON -> "겨울의 선택"
    ScreenId.P021_PRO_RETIREMENT -> "글러브를 벗을 때"
    ScreenId.P022_PRO_LEGACY -> "프로에서 가져갈 하나"
    ScreenId.P024_WEEKLY -> "이번 주의 작은 목표"
    ScreenId.P025_RECORDS_LEAGUE -> "고교와 프로, 모든 숫자"
    ScreenId.P026_ACHIEVEMENTS -> "쌓아 온 업적"
    ScreenId.P027_SETTINGS -> "내게 편한 방식으로"
    ScreenId.P028_LIFECARD -> "내 투수의 기록과 기억"
    ScreenId.P029_RETURN_PLAN -> "돌아올 자리"
    ScreenId.P030_REVIEW -> "한 줄 리뷰"
}

internal fun achievementTitle(id: String): String = when (id) {
    HighSchoolAchievementRules.FIRST_DRAFT -> "첫 지명"
    HighSchoolAchievementRules.FIRST_STRIKEOUT -> "첫 탈삼진"
    HighSchoolAchievementRules.CLEAN_INNING -> "무실점 등판"
    HighSchoolAchievementRules.PERFECT_DELIVERY -> "정확한 투구"
    HighSchoolAchievementRules.MAJOR_DEBUT -> "첫 큰 무대"
    HighSchoolAchievementRules.HUNDRED_STRIKEOUTS -> "백 탈삼진"
    HighSchoolAchievementRules.THIRD_LIFE -> "세 번째 생"
    HighSchoolAchievementRules.FIFTH_LIFE -> "다섯 번째 생"
    HighSchoolAchievementRules.TENTH_LIFE -> "열 번째 생"
    HighSchoolAchievementRules.KARMA_RUN -> "이어진 마음"
    HighSchoolAchievementRules.DOUBLE_KARMA -> "두 겹의 마음"
    HighSchoolAchievementRules.AWAKENED_THRICE -> "세 번의 각성"
    HighSchoolAchievementRules.FOUR_SCHOOLS -> "네 학교의 기록"
    HighSchoolAchievementRules.FIVE_DRAFTS -> "다섯 번의 평가"
    HighSchoolAchievementRules.HALL_OF_FAME -> "명예의 기록"
    else -> "새로운 업적"
}

internal fun achievementDescription(id: String): String = when (id) {
    HighSchoolAchievementRules.FIRST_DRAFT -> "처음으로 이름이 불린다."
    HighSchoolAchievementRules.FIRST_STRIKEOUT -> "삼진 하나를 잡는다."
    HighSchoolAchievementRules.CLEAN_INNING -> "직접 던진 등판을 무실점으로 막는다."
    HighSchoolAchievementRules.PERFECT_DELIVERY -> "조준도 타이밍도 완벽에 가까운 한 구를 던진다."
    HighSchoolAchievementRules.THIRD_LIFE -> "세 번째 생을 시작한다."
    HighSchoolAchievementRules.FIFTH_LIFE -> "다섯 번째 생을 시작한다."
    HighSchoolAchievementRules.TENTH_LIFE -> "열 번째 생을 시작한다."
    HighSchoolAchievementRules.KARMA_RUN -> "핸디캡을 하나 걸고 고교 3년을 마친다."
    HighSchoolAchievementRules.DOUBLE_KARMA -> "핸디캡을 둘 걸고 고교 3년을 마친다."
    HighSchoolAchievementRules.AWAKENED_THRICE -> "한 생에서 각성 셋을 익힌다."
    HighSchoolAchievementRules.FOUR_SCHOOLS -> "서로 다른 학교 네 곳에서 3년을 마친다."
    HighSchoolAchievementRules.FIVE_DRAFTS -> "지명받은 생을 다섯 번 남긴다."
    HighSchoolAchievementRules.MAJOR_DEBUT -> "1군 마운드에 처음 오른다."
    HighSchoolAchievementRules.HUNDRED_STRIKEOUTS -> "프로에서 탈삼진 100개를 넘긴다."
    HighSchoolAchievementRules.HALL_OF_FAME -> "명예의 전당에 이름을 올린다."
    else -> ""
}

internal fun legacyEffect(id: String): String = runCatching {
    val effect = HighSchoolSignatureLegacyRules.definition(id)
    listOf("구위" to effect.stuff, "제구" to effect.command, "무브먼트" to effect.movement, "체력" to effect.stamina)
        .filter { it.second > 0 }.sortedByDescending { it.second }.joinToString(" · ") { (label, amount) -> "$label ${if (amount >= 3) "중심" else if (amount == 2) "강화" else "보조"}" }
}.getOrDefault("")

internal fun legacyTitle(id: String): String = runCatching {
    HighSchoolSignatureLegacyRules.definition(id).title
}.getOrDefault("남겨진 유산")

internal fun boolLabel(value: Boolean): String = if (value) "켜짐" else "꺼짐"
/** Relationship numbers stay internal; the player reads a feeling, not a score. */
internal fun trustWord(value: Int): String = when {
    value >= 75 -> "깊은 믿음"
    value >= 55 -> "믿는 편"
    value >= 35 -> "지켜보는 중"
    else -> "아직 멀다"
}
internal fun reviewReason(state: GameAggregateState): String? = when (ScreenProjection.reviewTrigger(state)) {
    "third-life" -> "세 번째 생의 결산"
    "good-recap" -> "좋은 결산"
    "drafted-reveal-confirmed" -> "드래프트 결과 공개"
    else -> null
}

internal fun pitchBoundaryLabel(boundary: PitchBoundary): String = when (boundary) {
    PitchBoundary.RESERVED -> "투구 준비 완료"
    PitchBoundary.PLAYING -> "투구 진행 중"
    PitchBoundary.COMMITTED, PitchBoundary.CONSUMED, PitchBoundary.TERMINAL -> "투구 결과"
    PitchBoundary.COMPLETED -> "투구 완료"
    PitchBoundary.SUSPENDED -> "잠시 멈춤"
    PitchBoundary.ABANDONED -> "이번 투구를 포기함"
}

internal val HighSchoolTrainingFocus.label: String get() = when (this) {
    HighSchoolTrainingFocus.VELOCITY -> "구위"
    HighSchoolTrainingFocus.COMMAND -> "제구"
    HighSchoolTrainingFocus.BREAKING_BALL -> "무브먼트"
    HighSchoolTrainingFocus.STAMINA -> "체력"
    HighSchoolTrainingFocus.RECOVERY -> "회복"
    HighSchoolTrainingFocus.GAME_PLANNING -> "경기 계획"
}

internal val HighSchoolAwakening.label: String get() = HighSchoolDisplayRules.awakeningTitle(wire)

internal val HighSchoolRelationshipTarget.label: String get() = when (this) {
    HighSchoolRelationshipTarget.COACH -> "코치"
    HighSchoolRelationshipTarget.CATCHER -> "포수"
    HighSchoolRelationshipTarget.RIVAL -> "라이벌"
}

internal val HighSchoolRelationshipResponse.label: String get() = when (this) {
    HighSchoolRelationshipResponse.LISTEN -> "끝까지 듣기"
    HighSchoolRelationshipResponse.EXPLAIN -> "내 뜻 설명하기"
    HighSchoolRelationshipResponse.CHALLENGE -> "정면으로 부딪치기"
}

internal fun relationshipSpeakerLabel(category: String?): String = when (category) {
    "coach" -> "감독"
    "catcher" -> "포수"
    "rival" -> "라이벌"
    "growth" -> "훈련"
    "health" -> "몸 상태"
    "team" -> "팀"
    "draft" -> "스카우트"
    "media" -> "취재"
    "fan" -> "팬"
    "game" -> "경기"
    "life" -> "일상"
    "awakening" -> "각성"
    "legacy" -> "기록"
    else -> "이야기"
}

internal fun relationshipChoiceTitle(category: String?, response: HighSchoolRelationshipResponse): String = when (category) {
    "coach" -> when (response) {
        HighSchoolRelationshipResponse.LISTEN -> "감독의 말을 듣는다"
        HighSchoolRelationshipResponse.EXPLAIN -> "내 등판을 설명한다"
        HighSchoolRelationshipResponse.CHALLENGE -> "내 자리를 주장한다"
    }
    "catcher" -> when (response) {
        HighSchoolRelationshipResponse.LISTEN -> "포수의 사인을 듣는다"
        HighSchoolRelationshipResponse.EXPLAIN -> "내가 던지고 싶은 공을 말한다"
        HighSchoolRelationshipResponse.CHALLENGE -> "내 감각을 밀어붙인다"
    }
    "rival" -> when (response) {
        HighSchoolRelationshipResponse.LISTEN -> "라이벌의 말을 새긴다"
        HighSchoolRelationshipResponse.EXPLAIN -> "내 승부 방식을 말한다"
        HighSchoolRelationshipResponse.CHALLENGE -> "같은 코스로 답한다"
    }
    else -> response.label
}

internal fun relationshipChoiceDetail(category: String?, response: HighSchoolRelationshipResponse): String = when (response) {
    HighSchoolRelationshipResponse.LISTEN -> when (category) {
        "coach" -> "감독의 기준을 끝까지 듣고 다음 준비를 맞춥니다."
        "catcher" -> "포수가 왜 그 사인을 냈는지부터 확인합니다."
        "rival" -> "상대의 말을 기억하고 다음 승부에 남깁니다."
        "health" -> "몸의 신호를 먼저 듣고 오늘은 참습니다."
        else -> "상대의 말을 끝까지 듣고 다음 기준을 함께 확인합니다."
    }
    HighSchoolRelationshipResponse.EXPLAIN -> when (category) {
        "coach" -> "왜 선발 또는 긴 이닝을 원하는지 기록으로 남깁니다."
        "catcher" -> "지금 던지고 싶은 공과 코스를 말로 맞춥니다."
        "draft" -> "무너진 경기 뒤 무엇을 바꿨는지 설명합니다."
        else -> "선택의 이유를 짧게 설명하고 다음 장면을 엽니다."
    }
    HighSchoolRelationshipResponse.CHALLENGE -> when (category) {
        "coach" -> "말로 설득하기보다 다음 등판의 결과로 답합니다."
        "rival" -> "같은 초구, 같은 코스로 승부를 받습니다."
        "health" -> "통증 소문보다 오늘 던질 공을 고릅니다."
        else -> "결과로 답하기로 하고 승부처로 갑니다."
    }
}

internal fun importantGameSituation(scenario: com.solkim.baseball.core.highschool.HighSchoolGameScenario?): String {
    if (scenario == null) return "마운드에 오르기 전"
    val occupied = listOfNotNull(
        if (scenario.firstOccupied) "1루" else null,
        if (scenario.secondOccupied) "2루" else null,
        if (scenario.thirdOccupied) "3루" else null,
    )
    val bases = if (occupied.isEmpty()) "주자 없음" else occupied.joinToString(" · ")
    val score = scenario.scoreDifferential?.let { diff ->
        when {
            diff > 0 -> "${diff}점 앞"
            diff < 0 -> "${-diff}점 뒤"
            else -> "동점"
        }
    } ?: "점수 대기"
    return "${scenario.inning}회 · ${scenario.outs}아웃 · $bases · $score"
}

internal fun readableWeek(weekKey: String): String {
    val match = Regex("(\\d{4})-W(\\d{2})").matchEntire(weekKey) ?: return weekKey
    val monday = runCatching {
        LocalDate.of(match.groupValues[1].toInt(), 1, 4).with(WeekFields.ISO.weekOfWeekBasedYear(), match.groupValues[2].toLong()).with(java.time.DayOfWeek.MONDAY)
    }.getOrNull() ?: return weekKey
    val ordinal = listOf("첫째", "둘째", "셋째", "넷째", "다섯째")[((monday.dayOfMonth - 1) / 7).coerceIn(0, 4)]
    return "${monday.monthValue}월 $ordinal 주"
}

internal fun weeklyTaskTitle(kind: String): String = when (kind) {
    "daily_inning_completed", "daily-inning" -> "이닝을 마치기"
    "training_block", "train" -> "훈련 한 번"
    "relationship" -> "관계를 고르기"
    "important_game", "important-game", "important_games_completed" -> "승부처에 오르기"
    "played_on_two_days" -> "이틀 이상 던지기"
    "chapters_advanced" -> "다음 장으로 넘어가기"
    "different_school_selected" -> "다른 학교에서 시작하기"
    "next_run_started" -> "다음 생 시작하기"
    "pro_weeks_advanced" -> "프로 주간 보내기"
    "sequence_mastery_triggered" -> "배합 성공하기"
    "pledge_selected" -> "이번 생의 약속 정하기"
    else -> "이번 주 과제"
}

internal val HighSchoolPhase.label: String get() = when (this) {
    HighSchoolPhase.PROLOGUE -> "프롤로그"
    HighSchoolPhase.SCHOOL_SELECTION -> "학교 선택"
    HighSchoolPhase.TRAINING -> "훈련"
    HighSchoolPhase.RELATIONSHIP -> "관계"
    HighSchoolPhase.IMPORTANT_GAME -> "중요 경기"
    HighSchoolPhase.AWAKENING -> "각성"
    HighSchoolPhase.CHAPTER_REVIEW -> "장 결산"
    HighSchoolPhase.DRAFT -> "드래프트"
    HighSchoolPhase.LEGACY -> "유산"
    HighSchoolPhase.COMPLETED -> "완료"
}
internal val HighSchoolReturnDestination.label: String get() = when (this) {
    HighSchoolReturnDestination.HIGH_SCHOOL -> "고교 커리어"
    HighSchoolReturnDestination.PRO -> "프로 커리어"
    // Daily is retired in the Compose product. Old saved return-plan values are rendered as
    // the current career destination; callers are normalized before they reach this shell.
    HighSchoolReturnDestination.DAILY_INNING -> "현재 커리어"
}

internal val HighSchoolDraftOutcome.label: String get() = when (this) {
    HighSchoolDraftOutcome.DRAFTED -> "지명됨"
    HighSchoolDraftOutcome.UNDRAFTED -> "지명되지 않음"
}
