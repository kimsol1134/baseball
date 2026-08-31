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

/// A changed pitch-profile pair in a growth receipt.  Keeping the before/after values here lets
/// presentation code distinguish a real profile change from a base-ability cap.
public struct PitchProfileAdvancement: Codable, Equatable, Sendable {
    public let pitchType: PitchType
    public let before: PitchProfileSnapshot
    public let after: PitchProfileSnapshot

    public init(pitchType: PitchType, before: PitchProfileSnapshot, after: PitchProfileSnapshot) {
        self.pitchType = pitchType
        self.before = before
        self.after = after
    }
}

/// The complete result of one positive growth event.  `baseAfter` is capped at the internal
/// 20–80 storage contract; overflow is converted to the matching mastery track instead of being
/// silently discarded.
public struct PitcherAdvancementReceipt: Codable, Equatable, Sendable {
    public let pitcher: PitcherSnapshot
    public let ability: TalentAbility
    public let baseBefore: Int
    public let baseAfter: Int
    public let masteryBefore: Int
    public let masteryAfter: Int
    public let profileChanges: [PitchProfileAdvancement]

    public init(
        pitcher: PitcherSnapshot,
        ability: TalentAbility,
        baseBefore: Int,
        baseAfter: Int,
        masteryBefore: Int,
        masteryAfter: Int,
        profileChanges: [PitchProfileAdvancement] = []
    ) {
        self.pitcher = pitcher
        self.ability = ability
        self.baseBefore = baseBefore
        self.baseAfter = baseAfter
        self.masteryBefore = masteryBefore
        self.masteryAfter = masteryAfter
        self.profileChanges = profileChanges
    }

    public var baseDelta: Int { baseAfter - baseBefore }
    public var masteryDelta: Int { masteryAfter - masteryBefore }
    public var gainedMastery: Bool { masteryAfter > masteryBefore }
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

    private static func applyStoredGrowth(
        _ pitcher: PitcherSnapshot,
        focus: TrainingFocus,
        points: Int,
        targetPitch: PitchType? = nil,
        promoteDevelopmentPitch: Bool = true
    ) -> PitcherSnapshot {
        guard points > 0 else { return pitcher }
        let points = min(points, Int(AbilityMasterySnapshot.technicalMaximum))
        let breakingTarget = normalizedBreakingBallTarget(targetPitch, pitcher: pitcher)
        let profiles = pitcher.pitchProfiles?.map { profile in
            let isBreakingTarget = focus == .breakingBall
                && profile.pitchType != .fourSeam
                && (breakingTarget == nil || profile.pitchType == breakingTarget)
            let velocity = bounded(
                profile.velocityTenthsKPH + (focus == .velocity ? points * 5 : 0),
                1_000,
                PitchAbilityRules.maximumProfileVelocityTenthsKPH(for: profile.pitchType)
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
            // New repertoire saves use an explicit learning project. Only legacy profiles (whose
            // availability key is absent) keep the old implicit stat-threshold promotion.
            let role: PitchUsageRole = promoteDevelopmentPitch
                && profile.availability == nil
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
                fatigueCost: fatigueCost,
                availability: profile.availability
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
            throwingHand: pitcher.throwingHand,
            mastery: pitcher.mastery
        )
    }

    /// Applies positive growth while preserving every point after the 80 base-ability ceiling as
    /// mastery.  The returned receipt is the only source presentation code should use for a
    /// before/after label.
    public static func advance(
        _ pitcher: PitcherSnapshot,
        focus: TrainingFocus,
        points: Int,
        targetPitch: PitchType? = nil,
        promoteDevelopmentPitch: Bool = true
    ) -> PitcherAdvancementReceipt {
        let ability = TalentAbility.from(focus)
        let baseBefore = value(for: ability, pitcher: pitcher)
        let masteryBefore = pitcher.effectiveMastery.value(for: ability)
        guard points > 0 else {
            return PitcherAdvancementReceipt(
                pitcher: pitcher,
                ability: ability,
                baseBefore: baseBefore,
                baseAfter: baseBefore,
                masteryBefore: masteryBefore,
                masteryAfter: masteryBefore
            )
        }

        let stored = applyStoredGrowth(
            pitcher,
            focus: focus,
            points: points,
            targetPitch: targetPitch,
            promoteDevelopmentPitch: promoteDevelopmentPitch
        )
        let baseAfter = value(for: ability, pitcher: stored)
        let appliedToBase = max(0, baseAfter - baseBefore)
        let overflow = max(0, points - appliedToBase)
        let masteryAfter = pitcher.effectiveMastery.adding(overflow, to: ability).value(for: ability)
        let persistedMastery: AbilityMasterySnapshot? = (pitcher.mastery != nil || overflow > 0)
            ? pitcher.effectiveMastery.replacing(ability, with: masteryAfter)
            : nil
        let updated = PitcherSnapshot(
            id: stored.id,
            name: stored.name,
            stuff: stored.stuff,
            command: stored.command,
            movement: stored.movement,
            stamina: stored.stamina,
            pitchProfiles: stored.pitchProfiles,
            throwingHand: stored.throwingHand,
            mastery: persistedMastery
        )
        let profileChanges: [PitchProfileAdvancement] = zip(
            pitcher.pitchProfiles ?? [],
            updated.pitchProfiles ?? []
        ).compactMap { pair in
            let before = pair.0
            let after = pair.1
            guard before != after else { return nil }
            return PitchProfileAdvancement(pitchType: after.pitchType, before: before, after: after)
        }
        return PitcherAdvancementReceipt(
            pitcher: updated,
            ability: ability,
            baseBefore: baseBefore,
            baseAfter: baseAfter,
            masteryBefore: masteryBefore,
            masteryAfter: masteryAfter,
            profileChanges: profileChanges
        )
    }

    public static func advance(
        pitcher: PitcherSnapshot,
        focus: TrainingFocus,
        points: Int,
        targetPitch: PitchType? = nil,
        promoteDevelopmentPitch: Bool = true
    ) -> PitcherAdvancementReceipt {
        advance(
            pitcher,
            focus: focus,
            points: points,
            targetPitch: targetPitch,
            promoteDevelopmentPitch: promoteDevelopmentPitch
        )
    }

    public static func advance(
        pitcher: PitcherSnapshot,
        ability: TalentAbility,
        points: Int,
        targetPitch: PitchType? = nil,
        promoteDevelopmentPitch: Bool = true
    ) -> PitcherAdvancementReceipt {
        advance(
            pitcher,
            ability: ability,
            points: points,
            targetPitch: targetPitch,
            promoteDevelopmentPitch: promoteDevelopmentPitch
        )
    }

    public static func advance(
        _ pitcher: PitcherSnapshot,
        ability: TalentAbility,
        points: Int,
        targetPitch: PitchType? = nil,
        promoteDevelopmentPitch: Bool = true
    ) -> PitcherAdvancementReceipt {
        let focus: TrainingFocus = switch ability {
        case .stuff: .velocity
        case .command: .command
        case .movement: .breakingBall
        case .stamina: .stamina
        }
        return advance(
            pitcher,
            focus: focus,
            points: points,
            targetPitch: targetPitch,
            promoteDevelopmentPitch: promoteDevelopmentPitch
        )
    }

    /// Compatibility wrapper retained for existing callers.  New result/presentation code should
    /// call `advance` and inspect the receipt instead of inferring whether a cap was hit.
    public static func grow(
        _ pitcher: PitcherSnapshot,
        focus: TrainingFocus,
        points: Int,
        targetPitch: PitchType? = nil,
        promoteDevelopmentPitch: Bool = true
    ) -> PitcherSnapshot {
        advance(
            pitcher,
            focus: focus,
            points: points,
            targetPitch: targetPitch,
            promoteDevelopmentPitch: promoteDevelopmentPitch
        ).pitcher
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

    private static func value(for ability: TalentAbility, pitcher: PitcherSnapshot) -> Int {
        switch ability {
        case .stuff: pitcher.stuff
        case .command: pitcher.command
        case .movement: pitcher.movement
        case .stamina: pitcher.stamina
        }
    }

    private static func bounded(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        min(upper, max(lower, value))
    }
}
