package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolContentCatalog
import com.solkim.baseball.core.highschool.HighSchoolReturnPlanRules
import com.solkim.baseball.core.highschool.HighSchoolWindRules

typealias AvatarRole = com.solkim.baseball.core.portrait.AvatarRole
typealias AvatarParts = com.solkim.baseball.core.portrait.AvatarParts
typealias HighSchoolPreset = com.solkim.baseball.core.highschool.HighSchoolPreset
typealias HighSchoolReturnPlan = com.solkim.baseball.core.highschool.HighSchoolReturnPlan
typealias HighSchoolReturnDestination = com.solkim.baseball.core.highschool.HighSchoolReturnDestination
typealias HighSchoolDraftOutcome = com.solkim.baseball.core.highschool.HighSchoolDraftOutcome
typealias PitchDelivery = com.solkim.baseball.core.pitch.PitchDelivery
typealias PitchReleaseWindow = com.solkim.baseball.core.pitch.PitchReleaseWindow
typealias PitchReleaseMeter = com.solkim.baseball.core.pitch.PitchReleaseMeter
typealias PitchKind = com.solkim.baseball.core.pitch.PitchKind
typealias PitchIntensity = com.solkim.baseball.core.pitch.PitchIntensity
typealias ZoneIntent = com.solkim.baseball.core.pitch.ZoneIntent
typealias PitchOutcome = com.solkim.baseball.core.pitch.PitchOutcome
typealias PitchZone = com.solkim.baseball.core.pitch.PitchZone
typealias PitchCall = com.solkim.baseball.core.pitch.PitchCall
typealias PitchRecommendation = com.solkim.baseball.core.pitch.PitchRecommendation
typealias BaserunnerStateSnapshot = com.solkim.baseball.core.pitch.BaserunnerStateSnapshot
typealias MoundComposureInput = com.solkim.baseball.core.pitch.MoundComposureInput
typealias MoundTensionInput = com.solkim.baseball.core.pitch.MoundTensionInput
typealias MoundTensionModel = com.solkim.baseball.core.pitch.MoundTensionModel
typealias MoundHeartbeatAudio = com.solkim.baseball.core.pitch.MoundHeartbeatAudio
typealias MoundHeartbeatCadence = com.solkim.baseball.core.pitch.MoundHeartbeatCadence
typealias MoundHeartbeatPattern = com.solkim.baseball.core.pitch.MoundHeartbeatPattern
typealias MoundHeartbeatSettings = com.solkim.baseball.core.pitch.MoundHeartbeatSettings
typealias MoundMeterDisturbance = com.solkim.baseball.core.pitch.MoundMeterDisturbance
typealias BatSide = com.solkim.baseball.core.pitch.BatSide
typealias BattedBall = com.solkim.baseball.core.pitch.BattedBall
typealias FieldingResolutionSnapshot = com.solkim.baseball.core.pitch.FieldingResolutionSnapshot

/** 화면이 game-core 규칙 객체를 직접 부르지 않게 하는 조회 창구. */
public object HighSchoolDisplayRules {
    public fun presetTitle(id: String): String = when (id) {
        "power_prospect" -> "힘으로 승부하는 투수"
        "precision_commander" -> "정교하게 읽는 투수"
        "breaking_ball_artist" -> "변화구를 그리는 투수"
        "innings_eater" -> "긴 이닝을 버티는 투수"
        else -> "나만의 성장 방식"
    }

    public fun awakeningTitle(wire: String): String {
        val value = com.solkim.baseball.core.highschool.HighSchoolAwakening.entries.firstOrNull { it.wire == wire } ?: return "이전 각성"
        return when (value) {
        com.solkim.baseball.core.highschool.HighSchoolAwakening.EXPLOSIVE_FASTBALL -> "폭발적인 직구"
        com.solkim.baseball.core.highschool.HighSchoolAwakening.RISING_FOUR_SEAM -> "떠오르는 포심"
        com.solkim.baseball.core.highschool.HighSchoolAwakening.IRON_ARM -> "강철 어깨"
        com.solkim.baseball.core.highschool.HighSchoolAwakening.LATE_INNING_RESERVE -> "후반의 여유"
        com.solkim.baseball.core.highschool.HighSchoolAwakening.PINPOINT_EDGE -> "한 점의 끝"
        com.solkim.baseball.core.highschool.HighSchoolAwakening.REPEATABLE_RELEASE -> "흔들리지 않는 릴리스"
        com.solkim.baseball.core.highschool.HighSchoolAwakening.FIRST_PITCH_STRIKE -> "첫 공 스트라이크"
        com.solkim.baseball.core.highschool.HighSchoolAwakening.CALM_UNDER_PRESSURE -> "위기 속 평정"
        com.solkim.baseball.core.highschool.HighSchoolAwakening.SCOUT_COMPOSURE -> "스카우트 앞의 침착함"
        com.solkim.baseball.core.highschool.HighSchoolAwakening.DISAPPEARING_BREAKER -> "사라지는 변화구"
        com.solkim.baseball.core.highschool.HighSchoolAwakening.SWEEPING_SLIDER -> "넓게 휘는 슬라이더"
        com.solkim.baseball.core.highschool.HighSchoolAwakening.CURVEBALL_CLOCK -> "커브의 시계"
        com.solkim.baseball.core.highschool.HighSchoolAwakening.FROZEN_CHANGEUP -> "멈춘 체인지업"
        com.solkim.baseball.core.highschool.HighSchoolAwakening.SINKER_TUNNEL -> "싱커 터널"
        com.solkim.baseball.core.highschool.HighSchoolAwakening.BATTERY_SYNC -> "배터리 호흡"
        com.solkim.baseball.core.highschool.HighSchoolAwakening.TWO_STRIKE_PLAN -> "투 스트라이크 설계"
        com.solkim.baseball.core.highschool.HighSchoolAwakening.PICKOFF_RHYTHM -> "견제 리듬"
        com.solkim.baseball.core.highschool.HighSchoolAwakening.TRAFFIC_CONTROLLER -> "주자 흐름 읽기"
    }
    }

    public val regions: List<String> get() = HighSchoolContentCatalog.regions
    public val presets: List<HighSchoolPreset> get() = HighSchoolContentCatalog.presets
    public val windRulesVersion: Int get() = HighSchoolWindRules.RULES_VERSION

    public fun windIdFor(careerId: String): String = HighSchoolWindRules.idFor(careerId)

    public fun returnPlanDayGap(savedDayKey: String?, returnDayKey: String): Int? =
        HighSchoolReturnPlanRules.dayGap(savedDayKey, returnDayKey)

    public fun returnDestinationProductLabel(destination: HighSchoolReturnDestination): String =
        when (destination) {
            HighSchoolReturnDestination.HIGH_SCHOOL -> "고교 커리어"
            HighSchoolReturnDestination.PRO -> "프로 커리어"
            HighSchoolReturnDestination.DAILY_INNING -> "현재 커리어"
        }
}
