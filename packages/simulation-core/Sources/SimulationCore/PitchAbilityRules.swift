import Foundation

/// 한땀한땀 키운 능력이 지금 고른 공에 어떻게 들어가는지 보여 주는 공용 판정표.
/// 화면이 엔진 식을 흉내 내지 않고, 실제 투구 계산과 같은 값을 읽도록 한 곳에 둔다.
public enum PitchAbilityKind: String, Codable, CaseIterable, Hashable, Sendable {
    case power
    case command
    case movement
}

public struct PitchAbilityReadout: Equatable, Sendable {
    public let pitchType: PitchType
    public let stuffRating: Int
    public let commandRating: Int
    public let movementRating: Int
    public let staminaRating: Int
    public let whiffRating: Int
    public let weakContactRating: Int
    /// 난수와 손 릴리스 보정을 넣기 전의 현재 구속. 실제 공은 여기서 최대 약 ±2km/h 흔들린다.
    public let nominalVelocityTenthsKPH: Int
    /// 이 공 하나가 더하는 피로. 힘 배분까지 반영한 실제 엔진 값이다.
    public let fatigueCost: Int

    public init(
        pitchType: PitchType,
        stuffRating: Int,
        commandRating: Int,
        movementRating: Int,
        staminaRating: Int,
        whiffRating: Int,
        weakContactRating: Int,
        nominalVelocityTenthsKPH: Int,
        fatigueCost: Int
    ) {
        self.pitchType = pitchType
        self.stuffRating = stuffRating
        self.commandRating = commandRating
        self.movementRating = movementRating
        self.staminaRating = staminaRating
        self.whiffRating = whiffRating
        self.weakContactRating = weakContactRating
        self.nominalVelocityTenthsKPH = nominalVelocityTenthsKPH
        self.fatigueCost = fatigueCost
    }
}

public enum PitchAbilityRules {
    /// 선택한 구종·힘 배분·현재 피로가 실제 커널에 넣는 값을 그대로 편다.
    public static func readout(
        pitcher: PitcherSnapshot,
        call: PitchCall,
        context: PlateAppearanceContext
    ) -> PitchAbilityReadout {
        let profile = pitcher.profile(for: call.pitchType)
        return PitchAbilityReadout(
            pitchType: call.pitchType,
            stuffRating: pitcher.stuff,
            commandRating: commandRating(pitcher: pitcher, profile: profile),
            movementRating: profile?.movement ?? pitcher.movement,
            staminaRating: pitcher.stamina,
            whiffRating: profile?.whiff ?? pitcher.stuff,
            weakContactRating: profile?.weakContact ?? 50,
            nominalVelocityTenthsKPH: nominalVelocity(
                pitcher: pitcher,
                pitchType: call.pitchType,
                intensity: call.intensity,
                fatigue: context.fatigue
            ),
            fatigueCost: fatigueCost(call.intensity, profile: profile)
        )
    }

    /// 결과가 아니라 **능력이 실제 식에서 의미 있게 작동한 공**만 골라낸다.
    /// 안타·볼·파울에는 억지 칭찬을 붙이지 않고, 성공 결과도 해당 능력 경계가 있어야 한다.
    public static func moment(
        outcome: PitchOutcome,
        execution: PitchExecution,
        readout: PitchAbilityReadout
    ) -> PitchAbilityKind? {
        let resolved: Bool = switch outcome {
        case .calledStrike, .swingingStrike, .inPlayOut: true
        default: false
        }
        guard resolved else { return nil }

        if outcome == .calledStrike,
           readout.commandRating >= 55,
           execution.executionQuality >= 650 {
            return .command
        }
        if outcome == .swingingStrike {
            if readout.pitchType != .fourSeam,
               max(readout.movementRating, readout.whiffRating) >= 55 {
                return .movement
            }
            if max(readout.stuffRating, readout.whiffRating) >= 55 {
                return .power
            }
        }
        if outcome == .inPlayOut,
           max(readout.movementRating, readout.weakContactRating) >= 55 {
            return .movement
        }
        return nil
    }

    struct IntensityEffect {
        let commandPenalty: Int
        let velocityBonusTenthsKPH: Int
    }

    static func intensityEffect(_ intensity: PitchIntensity) -> IntensityEffect {
        switch intensity {
        // 셋 중 하나가 네 축(삼진·볼넷·피안타·실점) 전부에서 이기면 그건 선택지가 아니라
        // 정답이다. 실측에서 `controlled`가 정확히 그랬다 — 삼진 26.8/볼넷 8.5/피안타 16.4로
        // 전부 우월했고 피로까지 덜 든다. 힘 배분 줄은 몇 판 만에 학습되어 마찰만 남았다.
        //
        // 전역 구속 기울기를 건드리면 리그 전체 난이도가 함께 움직여 방금 잡은 지명률
        // 보정이 무너진다. 그래서 **강도 축 안에서만** 거래를 세운다: 힘을 빼면 제구 이득이
        // 줄고 구속을 더 잃는다(맞혀 잡는 쪽), 전력이면 제구를 덜 잃고 구속을 더 얻는다
        // (헛스윙 쪽). 어느 쪽도 공짜가 아니게 만드는 것이 목적이다.
        //
        // 구속 폭(±10.5·13.0km/h)은 실제 투수의 완급보다 크다. −90/+115까지 낮춰 봤더니
        // 전력투구의 삼진 우위가 사라져(26.1 = 힘 빼기와 동률) 거래가 다시 무너졌다.
        // 야구적 사실성보다 **선택이 성립하는 것**을 택했다. 20,000타석 실측:
        //   힘 빼기 삼진 26.1 / 볼넷 9.4 / 피안타 16.4 / 실점 0.064
        //   보통     삼진 25.2 / 볼넷 10.4 / 피안타 17.2 / 실점 0.070
        //   전력     삼진 26.5 / 볼넷 12.5 / 피안타 17.1 / 실점 0.075
        // 전력이 삼진을 사고 볼넷을 판다. 힘 빼기는 실점을 막지만 삼진은 못 산다.
        case .controlled: IntensityEffect(commandPenalty: -18, velocityBonusTenthsKPH: -105)
        case .normal: IntensityEffect(commandPenalty: 0, velocityBonusTenthsKPH: 0)
        case .maxEffort: IntensityEffect(commandPenalty: 34, velocityBonusTenthsKPH: 130)
        }
    }

    static func commandRating(
        pitcher: PitcherSnapshot,
        profile: PitchProfileSnapshot?
    ) -> Int {
        profile.map {
            (pitcher.command * 4 + $0.control * 4 + $0.command * 2) / 10
        } ?? pitcher.command
    }

    static func nominalVelocity(
        pitcher: PitcherSnapshot,
        pitchType: PitchType,
        intensity: PitchIntensity,
        fatigue: Int
    ) -> Int {
        let profile = pitcher.profile(for: pitchType)
        let base = profile?.velocityTenthsKPH
            ?? (baseVelocityTenthsKPH(pitchType) + (pitcher.stuff - 50) * 4)
        return base + intensityEffect(intensity).velocityBonusTenthsKPH - fatigue
    }

    static func baseVelocityTenthsKPH(_ pitchType: PitchType) -> Int {
        switch pitchType {
        case .fourSeam: 1_420
        case .slider: 1_275
        case .curveball: 1_165
        case .changeup: 1_285
        }
    }

    static func fatigueCost(
        _ intensity: PitchIntensity,
        profile: PitchProfileSnapshot?
    ) -> Int {
        if let profile {
            let modifier: Int = switch intensity {
            case .controlled: -1
            case .normal: 0
            case .maxEffort: 1
            }
            return max(0, profile.fatigueCost + modifier)
        }
        return switch intensity {
        case .controlled: 0
        case .normal: 1
        case .maxEffort: 2
        }
    }

    /// 피로 비용 0은 이미 가장 효율적인 구종이다. 체력 성장이 오히려 1로 올리면
    /// 성장 전보다 나빠지므로 0은 보존하고, 양수 비용만 게임의 최소값 1까지 줄인다.
    static func reducedFatigueCost(_ current: Int, by reduction: Int) -> Int {
        guard current > 0 else { return 0 }
        return max(1, current - max(0, reduction))
    }
}
