import Foundation

/// What the player has earned the right to do.
///
/// Growth is not a number going up — it is a door opening. The kernel already holds every one of
/// these thresholds, but each lived inside the rule that enforced it, so the player met them by
/// accident and never knew what a call-up, a rotation spot, or a complete game actually asked for.
/// This board says it out loud, and says how far is left.
///
/// Nothing here is persisted and nothing here decides anything. Every value is projected from
/// `ProCareerSnapshot` through the rules that already own it — `ProCallUpRules`,
/// `ProRoleRequestRules`, `ProOutingUsageRules`, `ProNationalTeamRules` — so the board cannot
/// drift away from what the game will actually do.
public enum ProAdvancementKind: String, Codable, Sendable, CaseIterable {
    case majorCallUp = "major_call_up"
    case starterRole = "starter_role"
    case starterWin = "starter_win"
    case closerRole = "closer_role"
    case completeGame = "complete_game"
    case nationalTeam = "national_team"
}

/// One condition of one threshold. `current` and `target` are always in the same unit so the
/// screen can render "체력 51 / 55" without knowing what the row means.
public struct ProAdvancementRequirement: Equatable, Sendable, Identifiable {
    public let id: String
    public let labelKey: String
    public let current: Int
    public let target: Int

    public init(id: String, labelKey: String, current: Int, target: Int) {
        self.id = id
        self.labelKey = labelKey
        self.current = current
        self.target = target
    }

    public var met: Bool { current >= target }
    /// How far is left. Zero once met — never negative, so the screen never says "−4 남음".
    public var remaining: Int { max(0, target - current) }
}

public struct ProAdvancement: Equatable, Sendable, Identifiable {
    public let id: String
    public let kind: ProAdvancementKind
    public let titleKey: String
    public let hintKey: String
    public let requirements: [ProAdvancementRequirement]
    /// Already held. A pitcher in the rotation does not need to be told what a rotation spot costs.
    public let held: Bool

    public init(
        id: String,
        kind: ProAdvancementKind,
        titleKey: String,
        hintKey: String,
        requirements: [ProAdvancementRequirement],
        held: Bool
    ) {
        self.id = id
        self.kind = kind
        self.titleKey = titleKey
        self.hintKey = hintKey
        self.requirements = requirements
        self.held = held
    }

    public var unlocked: Bool { held || requirements.allSatisfy(\.met) }

    /// The single condition still standing between the player and the door — the nearest one, so
    /// the hint is the one they can act on this week rather than the hardest one.
    public var nearestGap: ProAdvancementRequirement? {
        requirements.filter { !$0.met }.min { $0.remaining < $1.remaining }
    }

    /// Progress across every condition, so a row half-blocked by two conditions does not read as
    /// finished because one of them is met.
    public var permille: Int {
        if unlocked { return 1_000 }
        guard !requirements.isEmpty else { return 0 }
        let total = requirements.reduce(0) {
            $0 + ProCareerGoalBoardRules.permille(current: $1.current, target: $1.target, completed: $1.met)
        }
        return total / requirements.count
    }
}

public struct ProAdvancementBoard: Equatable, Sendable {
    public let rows: [ProAdvancement]
    /// The next door. Closest to opening among the ones still shut.
    public let next: ProAdvancement?

    public init(rows: [ProAdvancement], next: ProAdvancement?) {
        self.rows = rows
        self.next = next
    }
}

public enum ProAdvancementRules {
    public static func board(state: ProCareerSnapshot) -> ProAdvancementBoard {
        let rows = ProAdvancementKind.allCases.compactMap { row(kind: $0, state: state) }
        return ProAdvancementBoard(
            rows: rows,
            next: rows.filter { !$0.unlocked }.max { $0.permille < $1.permille }
        )
    }

    public static let contentKeys: [String] = ProAdvancementKind.allCases.flatMap {
        [Copy.title($0), Copy.hint($0)]
    } + Copy.requirementLabels

    /// The doors that opened between two weeks.
    ///
    /// A threshold crossed in silence is not a reward. The weekly result says it once, by name,
    /// on the week it happens — after that the board carries it. Only real openings count: a row
    /// that was already unlocked, or one that is still shut, says nothing.
    public static func newlyUnlocked(
        from previous: ProCareerSnapshot,
        to next: ProCareerSnapshot
    ) -> [ProAdvancementKind] {
        let before = Set(board(state: previous).rows.filter(\.unlocked).map(\.kind))
        return board(state: next).rows
            .filter { $0.unlocked && !before.contains($0.kind) }
            .map(\.kind)
    }

    /// The news line for a door that just opened. Resolved by key, so it reads in every language.
    public static func unlockedNewsKey(_ kind: ProAdvancementKind) -> String {
        "content.pro-news.advancement.\(kind.rawValue.replacingOccurrences(of: "_", with: "-"))"
    }

    public static let newsKeys: [String] = ProAdvancementKind.allCases.map(unlockedNewsKey)

    // MARK: - Rows

    private static func row(kind: ProAdvancementKind, state: ProCareerSnapshot) -> ProAdvancement? {
        let pitcher = state.pitcher
        switch kind {
        case .majorCallUp:
            return make(kind, held: state.level == .major, [
                requirement("trust", Copy.managerTrust, state.managerTrust, ProCallUpRules.trustRequired),
                requirement("skill", Copy.skill, ProCallUpRules.skill(pitcher), ProCallUpRules.skillRequired),
            ])
        case .starterRole:
            return make(kind, held: state.role == .starter, [
                requirement("stamina", Copy.stamina, pitcher.stamina, ProRoleRequestRules.starterAcceptStamina),
                requirement("trust", Copy.managerTrust, state.managerTrust, ProRoleRequestRules.starterAcceptTrust),
            ])
        case .starterWin:
            // 이 문턱만은 능력 규칙이 아니라 **측정값**이다. 승리는 15아웃을 채워야 붙는데,
            // 등판 길이는 규칙 13에서 감독이 정하므로 "몇이면 5이닝을 던지는가"는 재야 안다.
            return make(kind, held: false, [
                requirement("stamina", Copy.stamina, pitcher.stamina, ProOutingUsageRules.staminaForFiveInnings),
            ])
        case .closerRole:
            return make(kind, held: state.role == .closer, [
                requirement("stuff", Copy.stuff, pitcher.stuff, ProRoleRequestRules.closerAcceptStuff),
                requirement("catcherTrust", Copy.catcherTrust, state.catcherTrust, ProRoleRequestRules.closerAcceptCatcherTrust),
            ])
        case .completeGame:
            return make(kind, held: false, [
                requirement("stamina", Copy.stamina, pitcher.stamina, ProOutingUsageRules.staminaForCompleteGameChase),
            ])
        case .nationalTeam:
            // 대표팀은 능력이 아니라 **평판**이 연다. 세 갈래 중 하나만 넘으면 되므로
            // 가장 가까운 갈래 하나만 조건으로 세운다 — 셋을 모두 세우면 "셋 다 필요하다"로 읽힌다.
            guard ProCareerEngine.usesNationalTeamRules(state), state.age <= ProNationalTeamRules.maximumAge else {
                return nil
            }
            let market = requirement(
                "market", Copy.marketScore,
                ProNationalTeamRules.marketScore(for: state), ProNationalTeamRules.marketScoreThreshold
            )
            let fan = requirement(
                "fan", Copy.fanSupport,
                state.journeyState?.reputation.fanSupport ?? 0, ProNationalTeamRules.fanSupportThreshold
            )
            let closest = [market, fan].min { $0.remaining < $1.remaining } ?? market
            return make(kind, held: ProNationalTeamRules.qualifies(state), [closest])
        }
    }

    private static func make(
        _ kind: ProAdvancementKind,
        held: Bool,
        _ requirements: [ProAdvancementRequirement]
    ) -> ProAdvancement {
        ProAdvancement(
            id: kind.rawValue,
            kind: kind,
            titleKey: Copy.title(kind),
            hintKey: Copy.hint(kind),
            requirements: requirements,
            held: held
        )
    }

    private static func requirement(
        _ id: String,
        _ labelKey: String,
        _ current: Int,
        _ target: Int
    ) -> ProAdvancementRequirement {
        ProAdvancementRequirement(id: id, labelKey: labelKey, current: current, target: target)
    }

    // MARK: - Copy

    enum Copy {
        static let prefix = "content.advancement"

        static func title(_ kind: ProAdvancementKind) -> String {
            "\(prefix).\(slug(kind)).title"
        }

        static func hint(_ kind: ProAdvancementKind) -> String {
            "\(prefix).\(slug(kind)).hint"
        }

        static let stamina = "\(prefix).requirement.stamina"
        static let stuff = "\(prefix).requirement.stuff"
        static let skill = "\(prefix).requirement.skill"
        static let managerTrust = "\(prefix).requirement.manager-trust"
        static let catcherTrust = "\(prefix).requirement.catcher-trust"
        static let marketScore = "\(prefix).requirement.market-score"
        static let fanSupport = "\(prefix).requirement.fan-support"

        static let requirementLabels = [
            stamina, stuff, skill, managerTrust, catcherTrust, marketScore, fanSupport,
        ]

        private static func slug(_ kind: ProAdvancementKind) -> String {
            kind.rawValue.replacingOccurrences(of: "_", with: "-")
        }
    }
}
