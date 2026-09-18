import Foundation

/// 한 회차의 결과. 계보 비교가 필요한 것만 담는다.
///
/// 앱의 `LifeRecord`에서 옮겨 담는다 — 규칙을 코어에 두어 시즌 비교와 같은 자리에서
/// 같은 방식으로 검사받게 한다.
public struct CareerLifeSummary: Equatable, Sendable {
    public let lifeNumber: Int
    public let games: Int
    public let strikeouts: Int
    public let walks: Int
    public let runsAllowed: Int
    public let evaluationScore: Int

    public init(
        lifeNumber: Int,
        games: Int,
        strikeouts: Int,
        walks: Int,
        runsAllowed: Int,
        evaluationScore: Int
    ) {
        self.lifeNumber = lifeNumber
        self.games = games
        self.strikeouts = strikeouts
        self.walks = walks
        self.runsAllowed = runsAllowed
        self.evaluationScore = evaluationScore
    }
}

public enum CareerLifeMetricKind: String, Codable, Sendable, CaseIterable {
    case evaluation
    case strikeoutsPerGame = "strikeouts_per_game"
    case walksPerGame = "walks_per_game"
    case runsPerGame = "runs_per_game"
}

/// 1회차의 나 vs 이번 회차의 나.
///
/// **환생의 값은 더 높이 가는 것이 아니라 더 일찍 가는 것이다**(성장 곡선 계획 §3). 계승
/// 상한이 +16에서 멈추므로 끝점은 회차와 무관하고, 달라지는 것은 **출발점**이다. 그래서
/// 계보 화면이 견줄 것은 통산 합계가 아니라 **첫 회차와 이번 회차의 같은 지점**이다 —
/// 고교를 마치고 프로 문 앞에 섰을 때 무엇이 달라져 있는가.
///
/// 저장하는 값이 없다. 전부 회차 기록에서 파생한다.
public enum CareerLineageComparisonRules {
    /// 첫 회차와 가장 최근 회차를 견준다. 회차가 하나뿐이면 nil이다 — 견줄 대상이 없을 때
    /// 억지로 표를 만들지 않는다.
    public static func compare(lives: [CareerLifeSummary]) -> CareerComparison? {
        let ordered = lives.sorted { $0.lifeNumber < $1.lifeNumber }
        guard let first = ordered.first, let latest = ordered.last, first.lifeNumber != latest.lifeNumber else {
            return nil
        }
        // 한 경기도 던지지 않은 회차는 비교의 한쪽이 될 수 없다.
        guard first.games > 0, latest.games > 0 else { return nil }
        return CareerComparison(
            previousLabel: first.lifeNumber,
            currentLabel: latest.lifeNumber,
            metrics: [
                change(.evaluation, first, latest, lowerIsBetter: false, format: .whole) {
                    Double($0.evaluationScore)
                },
                // 회차마다 등판 수가 다를 수 있으므로 경기당으로 견준다. 합계로 견주면
                // 더 많이 던진 회차가 무조건 이긴다.
                change(.strikeoutsPerGame, first, latest, lowerIsBetter: false) {
                    Double($0.strikeouts) / Double($0.games)
                },
                change(.walksPerGame, first, latest, lowerIsBetter: true) {
                    Double($0.walks) / Double($0.games)
                },
                change(.runsPerGame, first, latest, lowerIsBetter: true) {
                    Double($0.runsAllowed) / Double($0.games)
                },
            ]
        )
    }

    private static func change(
        _ kind: CareerLifeMetricKind,
        _ first: CareerLifeSummary,
        _ latest: CareerLifeSummary,
        lowerIsBetter: Bool,
        format: CareerMetricChange.Format = .decimal,
        _ value: (CareerLifeSummary) -> Double
    ) -> CareerMetricChange {
        CareerMetricChange(
            id: kind.rawValue,
            labelKey: label(kind),
            previous: value(first),
            current: value(latest),
            lowerIsBetter: lowerIsBetter,
            format: format
        )
    }

    public static let contentKeys: [String] = CareerLifeMetricKind.allCases.map(label)

    public static func label(_ kind: CareerLifeMetricKind) -> String {
        "content.lineage-comparison.\(kind.rawValue.replacingOccurrences(of: "_", with: "-"))"
    }
}
