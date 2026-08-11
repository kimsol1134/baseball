import Foundation

/// A career's world rules are versioned independently from balance/content revisions.
///
/// Version 1 is the shipped five-entry index selection. Version 2 uses fixed hash buckets,
/// so adding or reordering content cannot silently change an in-progress career's wind.
public enum CareerRulesVersion: Int, Codable, CaseIterable, Sendable {
    case v1 = 1
    case v2 = 2

    /// Missing fields are pre-version saves and therefore v1. Unknown future values also fail
    /// closed to v1 for display; engine state validation rejects an unsupported stored value.
    public static func resolve(storedValue: Int?) -> CareerRulesVersion {
        storedValue.flatMap(CareerRulesVersion.init(rawValue:)) ?? .v1
    }
}

/// Typed, composable effects for one career wind.
///
/// The engine consumes these transformations instead of switching on wind IDs. Keeping the
/// arithmetic here makes the numbers shown by `CareerWind.effectDescriptions` the same numbers
/// used by simulation.
public struct CareerWindRules: Codable, Equatable, Sendable {
    public let favoredTraining: TrainingFocus?
    public let favoredTrainingBonus: Int
    public let trainingFatigueDelta: Int
    public let extraFatigueFocus: TrainingFocus?
    public let extraFatigueDelta: Int
    public let recoveryBonus: Int
    public let favoredRelationship: RelationshipTarget?
    public let favoredRelationshipBonus: Int
    public let relationshipLossPenalty: Int
    public let fanInterestGainBonus: Int
    public let draftEvaluationDelta: Int

    public init(
        favoredTraining: TrainingFocus? = nil,
        favoredTrainingBonus: Int = 0,
        trainingFatigueDelta: Int = 0,
        extraFatigueFocus: TrainingFocus? = nil,
        extraFatigueDelta: Int = 0,
        recoveryBonus: Int = 0,
        favoredRelationship: RelationshipTarget? = nil,
        favoredRelationshipBonus: Int = 0,
        relationshipLossPenalty: Int = 0,
        fanInterestGainBonus: Int = 0,
        draftEvaluationDelta: Int = 0
    ) {
        self.favoredTraining = favoredTraining
        self.favoredTrainingBonus = favoredTrainingBonus
        self.trainingFatigueDelta = trainingFatigueDelta
        self.extraFatigueFocus = extraFatigueFocus
        self.extraFatigueDelta = extraFatigueDelta
        self.recoveryBonus = recoveryBonus
        self.favoredRelationship = favoredRelationship
        self.favoredRelationshipBonus = favoredRelationshipBonus
        self.relationshipLossPenalty = relationshipLossPenalty
        self.fanInterestGainBonus = fanInterestGainBonus
        self.draftEvaluationDelta = draftEvaluationDelta
    }

    public static let neutral = CareerWindRules()

    public func trainingGrowthBonus(for focus: TrainingFocus) -> Int {
        focus == favoredTraining ? favoredTrainingBonus : 0
    }

    public func trainingFatigueModifier(for focus: TrainingFocus) -> Int {
        trainingFatigueDelta + (focus == extraFatigueFocus ? extraFatigueDelta : 0)
    }

    public func adjustedRecovery(_ base: Int) -> Int {
        base + recoveryBonus
    }

    /// A favored relationship shifts its trust change by the published bonus (including softening
    /// a loss); a loss penalty makes any failed choice more costly. Callers clamp the final state.
    public func adjustedRelationshipTrustChange(_ base: Int, target: RelationshipTarget) -> Int {
        var result = base
        if target == favoredRelationship { result += favoredRelationshipBonus }
        if base < 0 {
            result -= relationshipLossPenalty
        }
        return result
    }

    /// Wind bonuses apply to gains only; they never turn a loss into a gain.
    public func adjustedFanInterestChange(_ base: Int) -> Int {
        base > 0 ? base + fanInterestGainBonus : base
    }

    public func adjustedDraftEvaluation(_ base: Int) -> Int {
        base + draftEvaluationDelta
    }
}

/// 이번 회차의 바람 — 회차마다 세계의 조건이 조금 다르다.
///
/// `wind(careerID:)` is deliberately frozen as the v1 selector. New careers explicitly request
/// v2 and persist that version; old snapshots with no version continue to use v1 forever.
public struct CareerWind: Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let rulesVersion: CareerRulesVersion
    /// 라이벌 능력 보정. 센 해는 +, 조용한 해는 −.
    public let rivalBonus: Int
    /// 시작 팬 관심(기본 5 대신 쓰는 값).
    public let startingFanInterest: Int
    /// 야구혼 회수율 가산(‰). 어려운 바람일수록 회차의 끝이 진하다.
    public let rewardBonusPermille: Int
    public let rules: CareerWindRules

    /// Numeric, display-ready effects generated from the same fields simulation consumes.
    /// This is the preferred UI source when an exact explanation is required.
    public var effectDescriptions: [String] {
        var result: [String] = []
        if let focus = rules.favoredTraining, rules.favoredTrainingBonus != 0 {
            result.append("\(focus.windLabel) 훈련 성장 \(signed(rules.favoredTrainingBonus))")
        }
        if rules.recoveryBonus != 0 {
            result.append("회복 효과 \(signed(rules.recoveryBonus))")
        }
        if let target = rules.favoredRelationship, rules.favoredRelationshipBonus != 0 {
            result.append("\(target.windLabel) 믿음 변화 \(signed(rules.favoredRelationshipBonus))")
        }
        if rules.fanInterestGainBonus != 0 {
            result.append("팬 관심 획득 \(signed(rules.fanInterestGainBonus))")
        }
        if rules.draftEvaluationDelta != 0 {
            result.append("드래프트 평가 \(signed(rules.draftEvaluationDelta))")
        }
        if startingFanInterest != Self.defaultStartingFanInterest {
            result.append("시작 팬 관심 \(startingFanInterest)")
        }
        if rivalBonus != 0 {
            result.append("숙적 능력 \(signed(rivalBonus))")
        }
        if rules.trainingFatigueDelta != 0 {
            result.append("모든 훈련 피로 \(signed(rules.trainingFatigueDelta))")
        }
        if let focus = rules.extraFatigueFocus, rules.extraFatigueDelta != 0 {
            result.append("\(focus.windLabel) 훈련 피로 \(signed(rules.extraFatigueDelta))")
        }
        if rules.relationshipLossPenalty != 0 {
            result.append("대화 실패 때 믿음 손실 +\(rules.relationshipLossPenalty)")
        }
        if rewardBonusPermille != 0 {
            result.append("계승 포인트 보정 \(signed(rewardBonusPermille / 10))%")
        }
        return result
    }

    /// 뉴스 한 줄. 회차 시작에서 바람을 알린다 — 판이 다르다는 것을 모르면 변주가 아니다.
    public var newsLine: String? {
        id == "calm" ? nil : "이번 3년의 바람 — \(title). \(detail)"
    }

    private static let defaultStartingFanInterest = 5

    /// Frozen v1 pool. Its duplicate calm entry and order are compatibility data.
    static let all: [CareerWind] = [
        CareerWind(id: "calm", title: "바람 없는 해",
            detail: "특별할 것 없는 평범한 해입니다. 실력만이 말합니다.",
            rulesVersion: .v1, rivalBonus: 0, startingFanInterest: 5,
            rewardBonusPermille: 0, rules: .neutral),
        CareerWind(id: "calm", title: "바람 없는 해",
            detail: "특별할 것 없는 평범한 해입니다. 실력만이 말합니다.",
            rulesVersion: .v1, rivalBonus: 0, startingFanInterest: 5,
            rewardBonusPermille: 0, rules: .neutral),
        CareerWind(id: "monster_generation", title: "괴물 세대",
            detail: "전국에 물건들이 쏟아진 해입니다. 라이벌은 세지만, 이런 해를 버틴 계승 포인트 보상은 큽니다.",
            rulesVersion: .v1, rivalBonus: 5, startingFanInterest: 5,
            rewardBonusPermille: 150, rules: .neutral),
        CareerWind(id: "scout_frenzy", title: "스카우트 풍년",
            detail: "구단들이 일찍부터 움직이는 해입니다. 시선이 처음부터 따라붙습니다.",
            rulesVersion: .v1, rivalBonus: 0, startingFanInterest: 20,
            rewardBonusPermille: 0, rules: .neutral),
        CareerWind(id: "quiet_season", title: "무명의 해",
            detail: "아무도 이 지역을 주목하지 않는 해입니다. 조용히 강해질 시간입니다.",
            rulesVersion: .v1, rivalBonus: -3, startingFanInterest: 0,
            rewardBonusPermille: 80, rules: .neutral),
    ]

    private static let v2Calm = CareerWind(
        id: "calm", title: "바람 없는 해",
        detail: "특별할 것 없는 평범한 해입니다. 실력만이 말합니다.",
        rulesVersion: .v2, rivalBonus: 0, startingFanInterest: 5,
        rewardBonusPermille: 0, rules: .neutral
    )
    private static let v2MonsterGeneration = CareerWind(
        id: "monster_generation", title: "괴물 세대",
        detail: "강한 숙적과 맞서는 만큼 좋은 경기에는 더 많은 시선이 모입니다.",
        rulesVersion: .v2, rivalBonus: 5, startingFanInterest: 5, rewardBonusPermille: 150,
        rules: CareerWindRules(fanInterestGainBonus: 3)
    )
    private static let v2ScoutFrenzy = CareerWind(
        id: "scout_frenzy", title: "스카우트 풍년",
        detail: "일찍 모인 시선이 시즌 내내 따라붙습니다.",
        rulesVersion: .v2, rivalBonus: 0, startingFanInterest: 10, rewardBonusPermille: 0,
        // 시작 관심은 평온한 해보다 +5만 둔다. 좁아진 드래프트 분산에서 fanTerm 한 점이
        // 자연 지명률을 12%p 넘게 흔들지 않도록 직접 평가 보정은 두지 않는다.
        rules: .neutral
    )
    private static let v2QuietSeason = CareerWind(
        id: "quiet_season", title: "무명의 해",
        detail: "관심 없이 시작하지만 숙적도 평소보다 덜 완성된 해입니다.",
        rulesVersion: .v2, rivalBonus: -3, startingFanInterest: 0, rewardBonusPermille: 80,
        rules: .neutral
    )
    private static let v2Heatwave = CareerWind(
        id: "heatwave", title: "긴 여름",
        detail: "훈련의 피로가 더 쌓이는 대신 몸을 돌보는 회복도 더 깊습니다.",
        rulesVersion: .v2, rivalBonus: 0, startingFanInterest: 5, rewardBonusPermille: 120,
        rules: CareerWindRules(trainingFatigueDelta: 2, recoveryBonus: 4)
    )
    private static let v2CommandYear = CareerWind(
        id: "command_year", title: "코스의 해",
        detail: "제구 감각이 잘 붙지만 강한 공을 만드는 날에는 피로가 더 듭니다.",
        rulesVersion: .v2, rivalBonus: 0, startingFanInterest: 5, rewardBonusPermille: 50,
        rules: CareerWindRules(
            favoredTraining: .command, favoredTrainingBonus: 1,
            extraFatigueFocus: .velocity, extraFatigueDelta: 1
        )
    )
    private static let v2PowerYear = CareerWind(
        id: "power_year", title: "강한 공의 해",
        detail: "구위는 빠르게 자라지만 숙적도 강한 승부에 맞춰 올라옵니다.",
        rulesVersion: .v2, rivalBonus: 3, startingFanInterest: 5, rewardBonusPermille: 100,
        rules: CareerWindRules(favoredTraining: .velocity, favoredTrainingBonus: 1)
    )
    private static let v2BatteryYear = CareerWind(
        id: "battery_year", title: "배터리의 해",
        detail: "조용한 출발 대신 포수와 쌓는 믿음이 더 빠르게 깊어집니다.",
        rulesVersion: .v2, rivalBonus: 0, startingFanInterest: 2, rewardBonusPermille: 50,
        rules: CareerWindRules(favoredRelationship: .catcher, favoredRelationshipBonus: 2)
    )
    private static let v2SpotlightYear = CareerWind(
        id: "spotlight_year", title: "조명의 해",
        detail: "좋은 장면은 더 큰 관심을 부르지만 관계에서의 실패도 더 선명하게 남습니다.",
        rulesVersion: .v2, rivalBonus: 0, startingFanInterest: 5, rewardBonusPermille: 80,
        // 최종 분산 육성 1,000회차에서 +2는 전체 지명률보다 +10.01%p였다.
        // ±12%p 계약 안에서 관심 증폭 테마를 남기고, 실패 손실과 함께 양면성을 유지한다.
        rules: CareerWindRules(relationshipLossPenalty: 2, fanInterestGainBonus: 2)
    )
    private static let v2UnderdogYear = CareerWind(
        id: "underdog_year", title: "언더독의 해",
        detail: "관심 없이 강한 숙적을 만나지만 끝까지 증명하면 평가가 따라옵니다.",
        rulesVersion: .v2, rivalBonus: 2, startingFanInterest: 0, rewardBonusPermille: 120,
        // +2는 실측 +11.9%p로 허용선에 0.2%p밖에 남지 않았다. 보상 정체성은 +1로 유지한다.
        rules: CareerWindRules(draftEvaluationDelta: 1)
    )

    /// Test/catalog view only. Selection below does not depend on this array's order.
    static let v2All: [CareerWind] = [
        v2Calm, v2MonsterGeneration, v2ScoutFrenzy, v2QuietSeason, v2Heatwave,
        v2CommandYear, v2PowerYear, v2BatteryYear, v2SpotlightYear, v2UnderdogYear,
    ]

    /// Legacy entry point. Do not change its salt, generator, pool, or order.
    public static func wind(careerID: String) -> CareerWind {
        var generator = SplitMix64(seed: StableHash.fnv1a64Value("\(careerID)|career_wind"))
        return all[generator.nextInt(upperBound: all.count)]
    }

    public static func wind(careerID: String, rulesVersion: CareerRulesVersion) -> CareerWind {
        switch rulesVersion {
        case .v1:
            return wind(careerID: careerID)
        case .v2:
            return v2Wind(careerID: careerID)
        }
    }

    /// Convenience for persisted snapshots. A missing value has v1 semantics.
    public static func wind(careerID: String, worldRulesVersion: Int?) -> CareerWind {
        wind(careerID: careerID, rulesVersion: .resolve(storedValue: worldRulesVersion))
    }

    /// Fixed 100-bucket allocation: calm 30%; seven winds 8% each; two winds 7% each.
    /// The switch resolves named constants directly, so `v2All` may be reordered safely.
    private static func v2Wind(careerID: String) -> CareerWind {
        let bucket = Int(StableHash.fnv1a64Value("\(careerID)|career_wind_v2") % 100)
        switch bucket {
        case 0..<30: return v2Calm
        case 30..<38: return v2MonsterGeneration
        case 38..<46: return v2ScoutFrenzy
        case 46..<54: return v2QuietSeason
        case 54..<62: return v2Heatwave
        case 62..<70: return v2CommandYear
        case 70..<78: return v2PowerYear
        case 78..<86: return v2BatteryYear
        case 86..<93: return v2SpotlightYear
        default: return v2UnderdogYear
        }
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : String(value)
    }
}

private extension TrainingFocus {
    var windLabel: String {
        switch self {
        case .velocity: return "구위"
        case .command: return "제구"
        case .breakingBall: return "변화구"
        case .stamina: return "체력"
        case .recovery: return "회복"
        case .gamePlanning: return "경기 계획"
        }
    }
}

private extension RelationshipTarget {
    var windLabel: String {
        switch self {
        case .coach: return "감독"
        case .catcher: return "포수"
        case .rival: return "숙적"
        }
    }
}
