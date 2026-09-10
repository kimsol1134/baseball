import Foundation

public enum PitchAbilityAxis: String, Codable, Sendable, CaseIterable {
    case stuff
    case command
    case movement
    case stamina
}

/// 한 시즌이 끝났을 때의 네 능력.
public struct AbilityHistoryPoint: Equatable, Sendable, Identifiable {
    public let season: Int
    public let stuff: Int
    public let command: Int
    public let movement: Int
    public let stamina: Int

    public init(season: Int, stuff: Int, command: Int, movement: Int, stamina: Int) {
        self.season = season
        self.stuff = stuff
        self.command = command
        self.movement = movement
        self.stamina = stamina
    }

    public var id: Int { season }

    public func value(_ axis: PitchAbilityAxis) -> Int {
        switch axis {
        case .stuff: stuff
        case .command: command
        case .movement: movement
        case .stamina: stamina
        }
    }
}

/// 능력이 시즌을 지나며 어떻게 움직였는가.
///
/// **가로축은 저장된 변화의 순서이지 시간이 아니다.** 부상이나 군 복무로 통째로 비는 시즌이
/// 있고, 능력을 새기기 전에 흘러간 옛 시즌도 있다. 그 지점을 이어 그리면 화면이 없는 값을
/// 지어내게 되므로, **기록이 있는 시즌만** 점으로 남긴다.
public enum AbilityGrowthHistoryRules {
    public static func history(state: ProCareerSnapshot) -> [AbilityHistoryPoint] {
        points(seasons: state.careerStats, current: state.currentStats, pitcher: state.pitcher)
    }

    static func points(
        seasons: [ProSeasonStats],
        current: ProSeasonStats?,
        pitcher: PitcherSnapshot?
    ) -> [AbilityHistoryPoint] {
        var points = seasons
            .sorted { $0.season < $1.season }
            .compactMap { season -> AbilityHistoryPoint? in
                guard let abilities = season.abilities, abilities.count == 4 else { return nil }
                return AbilityHistoryPoint(
                    season: season.season,
                    stuff: abilities[0],
                    command: abilities[1],
                    movement: abilities[2],
                    stamina: abilities[3]
                )
            }
        // 진행 중인 시즌은 아직 기록으로 넘어가지 않았다. 지금 능력을 끝점으로 얹어야
        // 그래프가 "여기까지 왔다"로 끝난다 — 지난 시즌에서 끊기면 이번 성장이 안 보인다.
        if let current, let pitcher, !points.contains(where: { $0.season == current.season }) {
            points.append(
                AbilityHistoryPoint(
                    season: current.season,
                    stuff: pitcher.stuff,
                    command: pitcher.command,
                    movement: pitcher.movement,
                    stamina: pitcher.stamina
                )
            )
        }
        return points
    }

    /// 축 하나의 전 구간 변화. 점이 둘 미만이면 nil — 한 점으로는 성장을 말할 수 없다.
    public static func change(_ points: [AbilityHistoryPoint], axis: PitchAbilityAxis) -> Int? {
        guard let first = points.first, let last = points.last, points.count >= 2 else { return nil }
        return last.value(axis) - first.value(axis)
    }

    /// 막대와 그래프가 쓰는 상한. 능력은 0–100 축에 그린다.
    public static let axisMaximum = 100
}
