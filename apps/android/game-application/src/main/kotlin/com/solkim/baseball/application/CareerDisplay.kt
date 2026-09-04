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
typealias PitchReleaseMeter = com.solkim.baseball.core.pitch.PitchReleaseMeter
typealias PitchKind = com.solkim.baseball.core.pitch.PitchKind
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
