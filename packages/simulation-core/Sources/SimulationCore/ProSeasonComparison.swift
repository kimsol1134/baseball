import Foundation

/// 작년의 나 vs 올해의 나.
///
/// 성장은 비교로만 느껴진다. 숫자가 올랐다는 말은 무엇에 견주어 올랐는지를 말하지 않으면
/// 아무 뜻이 없고, 리그가 나를 따라오면 견줄 대상 자체가 사라진다. 상대 타순이 팀 키만의
/// 함수로 고정된 뒤에야(`ProfessionalLineup`, 성장 곡선 계획 G-2) 두 시즌의 성적이 같은
/// 상대에 대한 성적이 되고, 그제야 이 비교가 성립한다.
///
/// 저장하는 값이 아니다. 전부 `careerStats`에서 파생한다.
public enum ProSeasonMetricKind: String, Codable, Sendable, CaseIterable {
    case strikeoutsPer9 = "strikeouts_per9"
    case earnedRunAverage = "earned_run_average"
    case whip
    case innings
    case wins
}

public enum ProSeasonComparisonRules {
    /// 방금 끝난 시즌과 그 전 시즌을 견준다. 첫 시즌이거나 앞 시즌이 없으면 nil이다 —
    /// 견줄 대상이 없을 때 억지로 표를 만들지 않는다.
    public static func compare(state: ProCareerSnapshot) -> CareerComparison? {
        guard ProGameplayRules.usesProfessionalBalance(state.proRulesVersion) else { return nil }
        let seasons = state.careerStats.sorted { $0.season < $1.season }
        guard seasons.count >= 2 else { return nil }
        let current = seasons[seasons.count - 1]
        let previous = seasons[seasons.count - 2]
        // 한 이닝도 던지지 않은 시즌은 비교의 한쪽이 될 수 없다(부상·군 복무).
        guard current.inningsOuts > 0, previous.inningsOuts > 0 else { return nil }
        return CareerComparison(
            previousLabel: previous.season,
            currentLabel: current.season,
            metrics: [
                change(.strikeoutsPer9, previous, current, lowerIsBetter: false) {
                    PitchingMetrics.per9($0.strikeouts, outs: $0.inningsOuts)
                },
                change(.earnedRunAverage, previous, current, lowerIsBetter: true) { season in
                    // 자책점이 없는 시즌은 평균자책을 만들지 않는다. 실점으로 대신하면
                    // 두 시즌이 서로 다른 것을 재고 있으면서 같은 이름을 달게 된다.
                    season.earnedRuns.flatMap {
                        PitchingMetrics.runsPer9(runs: $0, outs: season.inningsOuts)
                    }
                },
                change(.whip, previous, current, lowerIsBetter: true) {
                    PitchingMetrics.whip(hits: $0.hits, walks: $0.walks, outs: $0.inningsOuts)
                },
                // 아웃 수를 그대로 넘긴다. 이닝 표기는 3분의 1 단위라 소수로 반올림해
                // 넘기면 95⅔이 95.70으로 찍힌다.
                change(.innings, previous, current, lowerIsBetter: false) {
                    Double($0.inningsOuts)
                },
                change(.wins, previous, current, lowerIsBetter: false) {
                    Double($0.wins)
                },
            ]
        )
    }

    private static func change(
        _ kind: ProSeasonMetricKind,
        _ previous: ProSeasonStats,
        _ current: ProSeasonStats,
        lowerIsBetter: Bool,
        _ value: (ProSeasonStats) -> Double?
    ) -> CareerMetricChange {
        CareerMetricChange(
            id: kind.rawValue,
            labelKey: label(kind),
            previous: value(previous),
            current: value(current),
            lowerIsBetter: lowerIsBetter,
            format: format(for: kind)
        )
    }

    private static func format(for kind: ProSeasonMetricKind) -> CareerMetricChange.Format {
        switch kind {
        case .wins: .whole
        case .innings: .innings
        default: .decimal
        }
    }

    public static let contentKeys: [String] = ProSeasonMetricKind.allCases.map(label)

    public static func label(_ kind: ProSeasonMetricKind) -> String {
        "content.season-comparison.\(kind.rawValue.replacingOccurrences(of: "_", with: "-"))"
    }
}
