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


internal fun contractKindLabel(kind: com.solkim.baseball.core.pro.ProContractKind): String = when (kind) {
    com.solkim.baseball.core.pro.ProContractKind.ROOKIE -> "신인 계약"
    com.solkim.baseball.core.pro.ProContractKind.RENEWAL_LONG -> "장기 재계약"
    com.solkim.baseball.core.pro.ProContractKind.PROVE_IT -> "증명 계약"
    com.solkim.baseball.core.pro.ProContractKind.FREE_AGENT -> "FA 계약"
    com.solkim.baseball.core.pro.ProContractKind.LONG_TERM -> "장기 계약"
}

internal fun outlookLabel(outlook: com.solkim.baseball.core.pro.ProTeamOutlook): String = when (outlook) {
    com.solkim.baseball.core.pro.ProTeamOutlook.OPPORTUNITY -> "기회"
    com.solkim.baseball.core.pro.ProTeamOutlook.BALANCED -> "균형"
    com.solkim.baseball.core.pro.ProTeamOutlook.CONTENDER -> "우승 경쟁"
}

internal val ProWeekPlan.label: String get() = iosTitle(null)

internal fun ProWeekPlan.iosTitle(pro: com.solkim.baseball.core.pro.ProState?): String {
    val relief = pro?.role != null && pro.role != ProRole.STARTER
    val veteran = (pro?.season ?: 1) >= 9
    val minor = pro?.level == ProLevel.MINOR
    return when (this) {
        ProWeekPlan.DEVELOP_STUFF -> when {
            relief -> "한 타자 강속구"
            veteran -> "포심 위력 다듬기"
            else -> "강속구 불펜"
        }
        ProWeekPlan.DEVELOP_MOVEMENT -> "결정구 완성"
        ProWeekPlan.REFINE_COMMAND -> "코스 제구 훈련"
        ProWeekPlan.BUILD_STAMINA -> if (relief) "연투 버티기" else "긴 이닝 루틴"
        ProWeekPlan.RECOVER -> if (veteran) "베테랑 회복 루틴" else "회복"
        ProWeekPlan.EARN_TRUST -> when {
            minor -> "콜업 경쟁 집중"
            relief -> "필승조 신뢰 쌓기"
            else -> "로테이션 신뢰 쌓기"
        }
        ProWeekPlan.DEVELOP_WEAPON -> "주무기 다듬기"
    }
}

internal fun ProWeekPlan.iosDescription(pro: com.solkim.baseball.core.pro.ProState?): String {
    val fatigue = pro?.fatigue ?: 0
    val risk = when {
        this == ProWeekPlan.RECOVER -> "부상 위험 낮음"
        fatigue >= 90 -> "부상 위험 높음"
        fatigue >= 70 -> "부상 위험 주의"
        else -> "부상 위험 낮음"
    }
    val effect = when (this) {
        ProWeekPlan.DEVELOP_STUFF -> "이번 주는 구속만 본다"
        ProWeekPlan.DEVELOP_MOVEMENT -> "결정구 하나를 더 벼린다"
        ProWeekPlan.REFINE_COMMAND -> "존 구석을 손에 붙인다"
        ProWeekPlan.BUILD_STAMINA -> "후반까지 같은 공을 던질 몸"
        ProWeekPlan.RECOVER -> "쉰다. 피로 20이 빠진다"
        ProWeekPlan.EARN_TRUST -> "감독 눈에 들어 둔다"
        ProWeekPlan.DEVELOP_WEAPON -> "주무기를 갈고닦는다"
    }
    return "$effect · $risk"
}

internal val OffseasonDecision.label: String get() = when (this) {
    OffseasonDecision.CONTINUE -> "계속하기"
    OffseasonDecision.MILITARY_SERVICE -> "복무 선택"
    OffseasonDecision.FREE_AGENCY -> "새 팀 찾기"
    OffseasonDecision.RETIRE -> "은퇴하기"
}

internal val ProLevel.label: String get() = when (this) {
    ProLevel.MINOR -> "육성 리그"
    ProLevel.MAJOR -> "주전 리그"
}

internal val ProRole.label: String get() = when (this) {
    ProRole.STARTER -> "선발"
    ProRole.LONG_RELIEF -> "롱릴리프"
    ProRole.SETUP -> "셋업"
    ProRole.CLOSER -> "마무리"
}

internal val ProSeasonSegment.label: String get() = ProCatalog.segmentLabel(this)
internal val ProCareerPhase.label: String get() = when (this) {
    ProCareerPhase.CONTRACT_OFFER -> "계약 제안"
    ProCareerPhase.WEEKLY_PLAN -> "주간 계획"
    ProCareerPhase.SEASON_DECISION -> "시즌 결정"
    ProCareerPhase.IMPORTANT_GAME -> "중요 경기"
    ProCareerPhase.SEASON_REVIEW -> "시즌 결산"
    ProCareerPhase.SEASON_SETTLEMENT -> "시즌 리뷰"
    ProCareerPhase.NATIONAL_TEAM_CALL -> "대표팀 소집"
    ProCareerPhase.NATIONAL_TOURNAMENT -> "대표팀 대회"
    ProCareerPhase.OFFSEASON_DECISION -> "비시즌 선택"
    ProCareerPhase.OFFSEASON_INVESTMENT -> "비시즌 투자"
    ProCareerPhase.RETIREMENT_DECISION -> "은퇴 결정"
    ProCareerPhase.LEGACY_SELECTION -> "유산 선택"
    ProCareerPhase.COMPLETED -> "커리어 완료"
}

internal fun settlementNextRouteLabel(route: ProSettlementNextRoute): String = when (route) {
    ProSettlementNextRoute.UNDER_CONTRACT -> "계약이 남았다. 같은 유니폼으로 봄을 맞는다."
    ProSettlementNextRoute.RENEWAL_MARKET -> "재계약 테이블이 열린다."
    ProSettlementNextRoute.FREE_AGENCY_ELIGIBLE -> "FA. 어느 유니폼이든 고를 수 있다."
    ProSettlementNextRoute.FORCED_RETIREMENT -> "현역의 마지막 결산."
}

internal fun proScenarioTitle(trigger: com.solkim.baseball.core.pro.ProSeasonTrigger?): String = when (trigger) {
    com.solkim.baseball.core.pro.ProSeasonTrigger.MAJOR_DEBUT -> "1군 데뷔"
    com.solkim.baseball.core.pro.ProSeasonTrigger.CALL_UP_AUDITION -> "콜업 오디션"
    com.solkim.baseball.core.pro.ProSeasonTrigger.OPENING_STATEMENT -> "개막 선언"
    com.solkim.baseball.core.pro.ProSeasonTrigger.STANDINGS_RACE -> "순위 경쟁"
    com.solkim.baseball.core.pro.ProSeasonTrigger.NATIONAL_FINAL -> "대표팀 결승"
    com.solkim.baseball.core.pro.ProSeasonTrigger.RECORD_CHASE -> "기록이 걸린 등판"
    com.solkim.baseball.core.pro.ProSeasonTrigger.ROLE_SHOWDOWN -> "보직이 걸린 등판"
    com.solkim.baseball.core.pro.ProSeasonTrigger.AUTUMN_WILD_CARD -> "와일드카드"
    com.solkim.baseball.core.pro.ProSeasonTrigger.AUTUMN_SEMIFINAL -> "준플레이오프"
    com.solkim.baseball.core.pro.ProSeasonTrigger.AUTUMN_PLAYOFF -> "플레이오프"
    com.solkim.baseball.core.pro.ProSeasonTrigger.AUTUMN_FINAL -> "우승 결정전"
    null -> "프로 승부처"
}

internal fun seasonArcTitle(arc: com.solkim.baseball.core.pro.ProSeasonArcTitle): String = when (arc) {
    com.solkim.baseball.core.pro.ProSeasonArcTitle.FIRST_HALF_ACE -> "전반기의 에이스"
    com.solkim.baseball.core.pro.ProSeasonArcTitle.DOMINANT -> "압도한 한 해"
    com.solkim.baseball.core.pro.ProSeasonArcTitle.LONG_TUNNEL -> "긴 터널"
    com.solkim.baseball.core.pro.ProSeasonArcTitle.LATE_RECOVERY -> "뒤늦은 반등"
    com.solkim.baseball.core.pro.ProSeasonArcTitle.AUTUMN_DOOR_CLOSED -> "닫힌 가을 문"
    com.solkim.baseball.core.pro.ProSeasonArcTitle.AUTUMN_CHAMPION -> "가을의 챔피언"
    com.solkim.baseball.core.pro.ProSeasonArcTitle.AUTUMN_RUNNER_UP -> "한 계단 아래"
    com.solkim.baseball.core.pro.ProSeasonArcTitle.AUTUMN_ELIMINATED -> "짧았던 가을"
    com.solkim.baseball.core.pro.ProSeasonArcTitle.AUTUMN_UNAVAILABLE -> "가을 없는 해"
    com.solkim.baseball.core.pro.ProSeasonArcTitle.QUIET -> "조용한 한 해"
}

internal fun teamLegacyTierLabel(score: Int): String = when {
    score >= 90 -> "영구결번 후보"
    score >= 75 -> "구단의 상징"
    score >= 60 -> "팀의 에이스"
    score >= 40 -> "핵심 선수"
    score >= 20 -> "든든한 기둥"
    else -> "새 얼굴"
}

internal fun ambitionTitle(ambition: com.solkim.baseball.core.pro.ProCareerAmbition): String = when (ambition) {
    com.solkim.baseball.core.pro.ProCareerAmbition.FRANCHISE_ICON -> "한 팀의 전설"
    com.solkim.baseball.core.pro.ProCareerAmbition.RECORD_BOOK -> "기록으로 남는 투수"
    com.solkim.baseball.core.pro.ProCareerAmbition.ENDURING_PRO -> "오래 뛰는 선수"
}

internal fun goalMetricStory(metric: com.solkim.baseball.core.pro.ProCareerGoalMetric): String {
    val left = (metric.target - metric.current).coerceAtLeast(0)
    return when (metric.kind) {
        com.solkim.baseball.core.pro.ProCareerGoalMetricKind.ANCHOR_TEAM_SEASONS -> "이 팀에서 ${left}시즌만 더."
        com.solkim.baseball.core.pro.ProCareerGoalMetricKind.ANCHOR_TEAM_LEGACY -> "이 팀에서의 자리를 더 굳혀야 한다."
        com.solkim.baseball.core.pro.ProCareerGoalMetricKind.HALL_OF_FAME_PROJECTION -> "명예의 전당까지 ${left}점."
        com.solkim.baseball.core.pro.ProCareerGoalMetricKind.AWARDS -> "수상 ${left}번이 더 필요하다."
        com.solkim.baseball.core.pro.ProCareerGoalMetricKind.PRO_SEASONS -> "${left}시즌만 더 버티면 된다."
        com.solkim.baseball.core.pro.ProCareerGoalMetricKind.MAJOR_SERVICE_YEARS -> "1군 ${left}년이 남았다."
    }
}

internal fun fanReasonStory(contentId: String): String = when (contentId) {
    "pro.fan.important-game.scoreless" -> "승부처를 무실점으로 막았다."
    "pro.fan.important-game.runs-allowed" -> "승부처에서 점수를 줬다."
    "pro.fan.same-team-season" -> "한 해 더 같은 유니폼을 입었다."
    "pro.autumn.champion" -> "가을의 마지막에 서 있었다."
    com.solkim.baseball.core.pro.ProCareerRecognitionRules.STRIKEOUTS -> "탈삼진상. 리그가 내 공을 헛쳤다."
    com.solkim.baseball.core.pro.ProCareerRecognitionRules.RUN_PREVENTION -> "실점 억제상. 점수를 안 줬다."
    com.solkim.baseball.core.pro.ProCareerRecognitionRules.COMMAND -> "정밀 제구상. 볼넷이 없었다."
    com.solkim.baseball.core.pro.ProCareerRecognitionRules.HITS -> "피안타 억제상. 맞지 않았다."
    com.solkim.baseball.core.pro.ProCareerRecognitionRules.INNINGS -> "이닝 책임상. 마운드를 오래 지켰다."
    else -> ""
}

internal fun retirementHonorTitle(kind: com.solkim.baseball.core.pro.ProRetirementHonorKind, teamId: String?): String {
    val team = teamId?.let { id -> ProCatalog.teams.firstOrNull { it.id == id }?.name }
    return when (kind) {
        com.solkim.baseball.core.pro.ProRetirementHonorKind.HALL_OF_FAME -> "명예의 전당"
        com.solkim.baseball.core.pro.ProRetirementHonorKind.RETIRED_NUMBER -> "${team ?: "구단"} 영구결번"
        com.solkim.baseball.core.pro.ProRetirementHonorKind.CLUB_HALL -> "${team ?: "구단"} 명예 선수"
        com.solkim.baseball.core.pro.ProRetirementHonorKind.AMBITION_COMPLETED -> "약속을 지킨 커리어"
        com.solkim.baseball.core.pro.ProRetirementHonorKind.CAREER_EARNINGS -> "통산 수입"
        com.solkim.baseball.core.pro.ProRetirementHonorKind.NATIONAL_GOLD -> "대표팀 금메달"
    }
}

internal fun retirementHonorStory(kind: com.solkim.baseball.core.pro.ProRetirementHonorKind): String = when (kind) {
    com.solkim.baseball.core.pro.ProRetirementHonorKind.HALL_OF_FAME -> "이 리그가 내 이름을 기억한다."
    com.solkim.baseball.core.pro.ProRetirementHonorKind.RETIRED_NUMBER -> "내 등번호를 이제 아무도 못 단다."
    com.solkim.baseball.core.pro.ProRetirementHonorKind.CLUB_HALL -> "구단 역사에 남았다."
    com.solkim.baseball.core.pro.ProRetirementHonorKind.AMBITION_COMPLETED -> "계약할 때 걸었던 목표를 이뤘다."
    com.solkim.baseball.core.pro.ProRetirementHonorKind.CAREER_EARNINGS -> "던져서 번 돈."
    com.solkim.baseball.core.pro.ProRetirementHonorKind.NATIONAL_GOLD -> "국기를 달고 이겼다."
}

internal fun proLegacyFarewell(family: String): String = when (family) {
    "power" -> "마지막까지 공은 무거웠다. 그 무게를 다음 생의 어깨에 얹는다."
    "command" -> "구석에 꽂던 감각은 손끝에 남는다. 다음 생의 첫 공부터."
    "breaking" -> "타자를 얼리던 그 공. 다음 생의 손에도 같은 그립이 잡힌다."
    "endurance" -> "긴 이닝을 버틴 몸. 다음 생은 지치기 전에 더 멀리 간다."
    "gamecraft" -> "타자를 읽던 눈은 늙지 않는다. 다음 생이 먼저 본다."
    else -> "포수와 맞춘 호흡. 다음 생의 배터리는 처음부터 한 호흡이다."
}

internal fun proLegacyChoice(family: String): String = when (family) {
    "power" -> "힘을 가져간다."
    "command" -> "제구를 가져간다."
    "breaking" -> "결정구를 가져간다."
    "endurance" -> "체력을 가져간다."
    "gamecraft" -> "경기 운영을 가져간다."
    else -> "호흡을 가져간다."
}

/** The kernel summary carries raw 20–80 ratings; show them on the same 1–100 scale as every other screen. */
internal fun legacyEvidence(summary: String, pro: com.solkim.baseball.core.pro.ProState?): String {
    if (pro == null) return summary
    val ratings = "구위 ${AbilityDisplayScale.rating(pro.pitcher.stuff)} · 제구 ${AbilityDisplayScale.rating(pro.pitcher.command)} · 변화구 ${AbilityDisplayScale.rating(pro.pitcher.movement)} · 체력 ${AbilityDisplayScale.rating(pro.pitcher.stamina)}"
    return "프로 통산 ${pro.careerGames()}경기 · ${pro.careerStrikeouts()}탈삼진 · $ratings · ${if (pro.awards.isEmpty()) "수상 없음" else "수상 ${pro.awards.size}회"}"
}


internal fun merchandiseTierLabel(tier: ProMerchandiseTier): String = when (tier) {
    ProMerchandiseTier.LOCAL -> "지역 상품"
    ProMerchandiseTier.RISING -> "상승 상품"
    ProMerchandiseTier.STAR -> "스타 상품"
    ProMerchandiseTier.ICON -> "아이콘 상품"
}

internal fun fanReasonLabel(kind: ProFanReasonKind): String = when (kind) {
    ProFanReasonKind.IMPORTANT_GAME_SCORELESS -> "무실점 등판"
    ProFanReasonKind.IMPORTANT_GAME_RUNS_ALLOWED -> "실점 등판"
    ProFanReasonKind.SEASON_AWARD -> "시즌 수상"
    ProFanReasonKind.CAREER_MILESTONE -> "커리어 이정표"
    ProFanReasonKind.SAME_TEAM_SEASON -> "같은 구단에서 한 해"
    ProFanReasonKind.CONTRACT_EXPECTATION_MET -> "계약 목표 달성"
    ProFanReasonKind.CONTRACT_EXPECTATION_MISSED -> "계약 목표 미달"
    ProFanReasonKind.CAREER_AMBITION_COMPLETED -> "커리어 목표 달성"
}

internal fun ProWeekPlan.targetPitchOrNull(pro: com.solkim.baseball.core.pro.ProState?): PitchKind? = when (this) {
    ProWeekPlan.DEVELOP_MOVEMENT, ProWeekPlan.DEVELOP_WEAPON -> pro?.pitchLearningProject?.takeIf { !it.completed }?.pitchType ?: pro?.pitcher?.pitchProfiles?.firstOrNull { it.pitchType != PitchKind.FOUR_SEAM }?.pitchType
    else -> null
}
