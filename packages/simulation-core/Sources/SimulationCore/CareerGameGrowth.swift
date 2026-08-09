import Foundation

/// 중요 경기에서 어떤 실전 감각이 능력치로 이어졌는지 나타내는 안정적인 분류.
///
/// 판정은 RNG를 쓰지 않으며 `CareerGameGrowth.evaluating(state:report:)` 한 곳에만 있다.
/// 화면은 경기 확정 전에 이 순수 함수를 호출해 코어가 적용할 결과와 같은 설명을 보여 줄 수 있다.
public enum CareerGameGrowthReason: String, Codable, Hashable, Sendable {
    case sequenceCommand = "sequence_command"
    case cleanCommand = "clean_command"
    case strikeoutStuff = "strikeout_stuff"
    case strikeoutMovement = "strikeout_movement"
    case longOuting = "long_outing"
}

/// 훈련장에서 고른 방향과 마운드에서 증명한 결과를 잇는 경기 기반 성장.
///
/// 한 경기에서 후보는 하나만 선택되고, 실제 능력치 증가는 최대 1이다. 재능 한계에 닿은
/// 경우에는 증가가 0이어도 압박이나 만개가 `resultingTalent`에 남는다.
public struct CareerGameGrowth: Codable, Equatable, Sendable {
    public let ability: TalentAbility
    public let points: Int
    public let reason: CareerGameGrowthReason
    public let title: String
    public let detail: String
    public let resultingTalent: TalentSnapshot
    public let bloomedAbility: TalentAbility?

    public var reasonCode: String { "game_growth.\(reason.rawValue)" }

    public init(
        ability: TalentAbility,
        points: Int,
        reason: CareerGameGrowthReason,
        title: String,
        detail: String,
        resultingTalent: TalentSnapshot,
        bloomedAbility: TalentAbility? = nil
    ) {
        self.ability = ability
        self.points = points
        self.reason = reason
        self.title = title
        self.detail = detail
        self.resultingTalent = resultingTalent
        self.bloomedAbility = bloomedAbility
    }

    /// 경기 결과를 성장 하나로 바꾸는 유일한 판정 함수.
    ///
    /// 우선순위는 삼진 호투 → 긴 이닝 → 수싸움 적중이다.
    /// 따라서 한 경기에서 여러 조건을 만족해도 +1 하나만 얻는다. `talent == nil`인 구저장본은
    /// 이 기능 이전 규칙을 그대로 유지한다.
    public static func evaluating(
        state: HighSchoolCareerSnapshot,
        report: ImportantInningReport
    ) -> CareerGameGrowth? {
        guard let talent = state.talent,
              (state.balanceVersion ?? 1) >= 4,
              report.scenarioNumber == state.performance.importantGamesCompleted + 1,
              report.pitches > 0,
              (0...report.pitches).contains(report.recommendationAccepted) else {
            return nil
        }

        let selected: (ability: TalentAbility, reason: CareerGameGrowthReason, evidence: String)?
        if report.strikeouts >= 2,
           report.runsAllowed <= 1,
           report.actualDamage <= report.expectedDamage {
            if state.pitcher.stuff >= state.pitcher.movement {
                selected = (
                    .stuff,
                    .strikeoutStuff,
                    "\(report.strikeouts)탈삼진 · \(report.runsAllowed)실점 호투가 가장 강한 구위를 더 날카롭게 만들었습니다."
                )
            } else {
                selected = (
                    .movement,
                    .strikeoutMovement,
                    "\(report.strikeouts)탈삼진 · \(report.runsAllowed)실점 호투가 가장 강한 변화구 감각을 더 날카롭게 만들었습니다."
                )
            }
        } else if report.outs == 3,
                  report.pitches >= 9,
                  report.runsAllowed <= 1,
                  report.actualDamage <= report.expectedDamage {
            selected = (
                .stamina,
                .longOuting,
                "한 이닝의 아웃카운트 3개를 \(report.pitches)구 · \(report.runsAllowed)실점으로 책임진 호흡이 체력으로 남았습니다."
            )
        } else if (report.sequenceMasteryCount ?? 0) >= 4,
                  report.walks == 0,
                  report.actualDamage <= report.expectedDamage {
            selected = (
                .command,
                .sequenceCommand,
                "수싸움 적중 \(report.sequenceMasteryCount ?? 0)회와 무볼넷 투구가 원하는 곳에 던지는 감각으로 이어졌습니다."
            )
        } else {
            selected = nil
        }

        guard let selected else { return nil }
        let applied = TalentRules.apply(
            talent: talent,
            ability: selected.ability,
            current: rating(selected.ability, of: state.pitcher),
            points: 1
        )
        let bloomSentence = applied.bloomed.map {
            " \($0.label) 재능이 \(applied.talent.grade($0).label)로 만개했습니다."
        } ?? ""
        let limitSentence = applied.allowed == 0 && applied.bloomed == nil
            ? " 재능 한계에 닿아 능력치는 오르지 않았지만 압박이 남았습니다."
            : ""
        let title = applied.allowed > 0
            ? "경기 기반 성장 · \(selected.ability.label) +\(applied.allowed)"
            : "경기 기반 성장 · \(selected.ability.label) 한계 압박"
        return CareerGameGrowth(
            ability: selected.ability,
            points: applied.allowed,
            reason: selected.reason,
            title: title,
            detail: selected.evidence + bloomSentence + limitSentence,
            resultingTalent: applied.talent,
            bloomedAbility: applied.bloomed
        )
    }

    /// `evaluating`이 산출한 실제 증가분을 투수에게 적용한다.
    public func applying(to pitcher: PitcherSnapshot) -> PitcherSnapshot {
        guard points > 0 else { return pitcher }
        let profiles = pitcher.pitchProfiles?.map { profile in
            PitchProfileSnapshot(
                pitchType: profile.pitchType,
                role: profile.role,
                velocityTenthsKPH: Self.bounded(
                    profile.velocityTenthsKPH + (ability == .stuff ? points * 5 : 0), 1_000, 1_700
                ),
                control: Self.bounded(profile.control + (ability == .command ? points : 0), 20, 80),
                command: Self.bounded(profile.command + (ability == .command ? points : 0), 20, 80),
                movement: Self.bounded(
                    profile.movement + (ability == .movement && profile.pitchType != .fourSeam ? points : 0), 20, 80
                ),
                whiff: Self.bounded(
                    profile.whiff + (ability == .movement && profile.pitchType != .fourSeam ? points : 0), 20, 80
                ),
                weakContact: profile.weakContact,
                fatigueCost: ability == .stamina ? max(1, profile.fatigueCost - points / 2) : profile.fatigueCost
            )
        }
        return PitcherSnapshot(
            id: pitcher.id,
            name: pitcher.name,
            stuff: Self.bounded(pitcher.stuff + (ability == .stuff ? points : 0), 20, 80),
            command: Self.bounded(pitcher.command + (ability == .command ? points : 0), 20, 80),
            movement: Self.bounded(pitcher.movement + (ability == .movement ? points : 0), 20, 80),
            stamina: Self.bounded(pitcher.stamina + (ability == .stamina ? points : 0), 20, 80),
            pitchProfiles: profiles,
            throwingHand: pitcher.throwingHand
        )
    }

    private static func rating(_ ability: TalentAbility, of pitcher: PitcherSnapshot) -> Int {
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
