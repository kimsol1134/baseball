import Foundation

/// 네 육성 축 중 현재 투수의 가장 뚜렷한 정체성.
///
/// 동률일 때는 구위 → 제구 → 변화 → 체력 순으로 고정한다. 같은 저장본이 화면·목표·포수
/// 사인에서 항상 같은 정체성을 읽어야 하므로 난수나 배열 정렬 안정성에 기대지 않는다.
public enum PitcherBuildIdentity: String, Codable, CaseIterable, Sendable {
    case power
    case command
    case movement
    case stamina

    public var label: String {
        switch self {
        case .power: "강속구형"
        case .command: "정밀 제구형"
        case .movement: "변화구형"
        case .stamina: "이닝 소화형"
        }
    }

    public var strength: String {
        switch self {
        case .power: "빠른 공으로 헛스윙과 삼진을 만듭니다."
        case .command: "볼넷을 줄이고 노린 코스에 승부합니다."
        case .movement: "변화와 약한 타구로 안타를 억제합니다."
        case .stamina: "피로가 늦게 와 긴 이닝에도 구위를 지킵니다."
        }
    }

    public var tradeoff: String {
        switch self {
        case .power: "전력투구를 남발하면 제구와 체력 부담이 커집니다."
        case .command: "정교하지만 결정구가 약하면 긴 승부가 늘어납니다."
        case .movement: "행잉 변화구는 강한 타구로 이어질 수 있습니다."
        case .stamina: "초반 압도력보다 후반 안정성에 보상이 몰립니다."
        }
    }

    public var trainingFocus: TrainingFocus {
        switch self {
        case .power: .velocity
        case .command: .command
        case .movement: .breakingBall
        case .stamina: .stamina
        }
    }
}

public enum PitcherBuildRules {
    public static func identity(for pitcher: PitcherSnapshot) -> PitcherBuildIdentity {
        let values: [(PitcherBuildIdentity, Int)] = [
            (.power, pitcher.stuff),
            (.command, pitcher.command),
            (.movement, pitcher.movement),
            (.stamina, pitcher.stamina),
        ]
        var winner = values[0]
        for candidate in values.dropFirst() where candidate.1 > winner.1 {
            winner = candidate
        }
        return winner.0
    }
}

/// 고교 훈련·프로 주간 성장·중요 경기 성장이 함께 사용하는 단일 성장 규칙.
public enum PitcherGrowthRules {
    /// 변화구 훈련에서 지정할 수 있는 실제 보유 변화구. nil이면 예전 저장·호출과 같이 모든
    /// 변화구를 고르게 키운다.
    public static func normalizedBreakingBallTarget(
        _ target: PitchType?,
        pitcher: PitcherSnapshot
    ) -> PitchType? {
        guard let target, target != .fourSeam,
              pitcher.pitchProfiles?.contains(where: { $0.pitchType == target }) == true else {
            return nil
        }
        return target
    }

    public static func grow(
        _ pitcher: PitcherSnapshot,
        focus: TrainingFocus,
        points: Int,
        targetPitch: PitchType? = nil,
        promoteDevelopmentPitch: Bool = true
    ) -> PitcherSnapshot {
        guard points > 0 else { return pitcher }
        let breakingTarget = normalizedBreakingBallTarget(targetPitch, pitcher: pitcher)
        let profiles = pitcher.pitchProfiles?.map { profile in
            let isBreakingTarget = focus == .breakingBall
                && profile.pitchType != .fourSeam
                && (breakingTarget == nil || profile.pitchType == breakingTarget)
            let velocity = bounded(
                profile.velocityTenthsKPH + (focus == .velocity ? points * 5 : 0),
                1_000, 1_700
            )
            let control = bounded(
                profile.control + (focus == .command ? points : 0),
                20, 80
            )
            let command = bounded(
                profile.command + (focus == .command || focus == .gamePlanning ? points : 0),
                20, 80
            )
            // 선택한 결정구는 프로필 수치에서도 즉시 보인다. 구위 훈련은 포심 헛스윙,
            // 변화구 훈련은 선택 구종의 변화·헛스윙을 키워 서로 다른 공을 만든다.
            let movement = bounded(profile.movement + (isBreakingTarget ? points * 2 : 0), 20, 80)
            let whiff = bounded(
                profile.whiff
                    + (focus == .velocity && profile.pitchType == .fourSeam ? points : 0)
                    + (isBreakingTarget ? points : 0),
                20, 80
            )
            let fatigueCost = focus == .stamina
                ? PitchAbilityRules.reducedFatigueCost(profile.fatigueCost, by: points / 2)
                : profile.fatigueCost
            let role: PitchUsageRole = promoteDevelopmentPitch
                && profile.role == .development
                && command + whiff + profile.weakContact >= 150
                ? .secondary
                : profile.role
            return PitchProfileSnapshot(
                pitchType: profile.pitchType,
                role: role,
                velocityTenthsKPH: velocity,
                control: control,
                command: command,
                movement: movement,
                whiff: whiff,
                weakContact: profile.weakContact,
                fatigueCost: fatigueCost
            )
        }
        return PitcherSnapshot(
            id: pitcher.id,
            name: pitcher.name,
            stuff: bounded(pitcher.stuff + (focus == .velocity ? points : 0), 20, 80),
            command: bounded(
                pitcher.command + (focus == .command || focus == .gamePlanning ? points : 0),
                20, 80
            ),
            movement: bounded(pitcher.movement + (focus == .breakingBall ? points : 0), 20, 80),
            stamina: bounded(
                pitcher.stamina + (focus == .stamina || focus == .recovery ? points : 0),
                20, 80
            ),
            pitchProfiles: profiles,
            throwingHand: pitcher.throwingHand
        )
    }

    public static func grow(
        _ pitcher: PitcherSnapshot,
        ability: TalentAbility,
        points: Int,
        targetPitch: PitchType? = nil
    ) -> PitcherSnapshot {
        let focus: TrainingFocus = switch ability {
        case .stuff: .velocity
        case .command: .command
        case .movement: .breakingBall
        case .stamina: .stamina
        }
        return grow(pitcher, focus: focus, points: points, targetPitch: targetPitch)
    }

    private static func bounded(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        min(upper, max(lower, value))
    }
}
