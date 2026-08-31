import Foundation

public enum ProWeekInjuryRiskBand: String, Codable, CaseIterable, Sendable {
    case low
    case caution
    case high

    public var label: String {
        switch self {
        case .low: "낮음"
        case .caution: "주의"
        case .high: "높음"
        }
    }
}

public struct ProWeekHealthForecast: Codable, Equatable, Sendable {
    public let plan: ProWeekPlan
    public let role: ProRole
    public let expectedPitches: Int
    public let currentFatigue: Int
    public let expectedRawFatigue: Int
    public let expectedEffectiveFatigue: Int
    public let band: ProWeekInjuryRiskBand
    public let reason: String

    public init(
        plan: ProWeekPlan,
        role: ProRole,
        expectedPitches: Int,
        currentFatigue: Int,
        expectedRawFatigue: Int,
        expectedEffectiveFatigue: Int,
        band: ProWeekInjuryRiskBand,
        reason: String
    ) {
        self.plan = plan
        self.role = role
        self.expectedPitches = expectedPitches
        self.currentFatigue = currentFatigue
        self.expectedRawFatigue = expectedRawFatigue
        self.expectedEffectiveFatigue = expectedEffectiveFatigue
        self.band = band
        self.reason = reason
    }

    public static func forecast(
        state: ProCareerSnapshot,
        plan: ProWeekPlan
    ) -> ProWeekHealthForecast {
        let expectedPitches: Int = {
            switch state.role {
            case .starter: 96
            case .longRelief: 84
            case .setup, .closer: 72
            }
        }()
        let trainingLoad: Int = switch plan {
        case .developStuff: 10
        case .developMovement: 8
        case .developWeapon: 9
        case .refineCommand: 6
        case .buildStamina: 7
        case .earnTrust: 5
        case .recover: -16
        }
        let outingLoad = plan == .recover || state.injuryWeeks > 0
            ? 0
            : (expectedPitches + 14) / 15
        let staminaRelief = max(0, (state.pitcher.stamina - 50) / 15)
        let expectedRaw = min(100, max(0, state.fatigue + trainingLoad + outingLoad - staminaRelief))
        let expectedEffective = PitchAbilityRules.effectiveFatigue(
            rawFatigue: expectedRaw,
            stamina: state.pitcher.stamina,
            mastery: state.pitcher.effectiveMastery.stamina
        )
        let band: ProWeekInjuryRiskBand = switch expectedEffective {
        case ...72: .low
        case 73...82: .caution
        default: .high
        }
        let reason: String
        switch band {
        case .low:
            reason = "현재 피로와 선택한 계획을 반영해 과부하 기준 아래입니다."
        case .caution:
            reason = "현재 피로에 훈련 부하와 예정 등판이 더해질 수 있습니다."
        case .high:
            reason = "훈련 부하와 예정 등판 뒤 유효 피로가 과부하 기준을 넘을 수 있습니다."
        }
        return ProWeekHealthForecast(
            plan: plan,
            role: state.role,
            expectedPitches: expectedPitches,
            currentFatigue: state.fatigue,
            expectedRawFatigue: expectedRaw,
            expectedEffectiveFatigue: expectedEffective,
            band: band,
            reason: reason
        )
    }
}
