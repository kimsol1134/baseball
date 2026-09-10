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

public struct ProSeasonMetricChange: Equatable, Sendable, Identifiable {
    public let kind: ProSeasonMetricKind
    /// 지난 시즌 값. 잴 수 없으면 nil이고 화면은 `—`를 보여 준다.
    public let previous: Double?
    public let current: Double?
    /// 낮을수록 좋은 지표인가(평균자책·WHIP).
    public let lowerIsBetter: Bool

    public init(kind: ProSeasonMetricKind, previous: Double?, current: Double?, lowerIsBetter: Bool) {
        self.kind = kind
        self.previous = previous
        self.current = current
        self.lowerIsBetter = lowerIsBetter
    }

    public var id: String { kind.rawValue }

    /// 올해 − 작년. 어느 한쪽이라도 없으면 nil이다 — **모르는 것을 0으로 세지 않는다.**
    public var delta: Double? {
        guard let previous, let current else { return nil }
        return current - previous
    }

    /// 나아졌는가. 방향은 지표마다 다르다.
    ///
    /// **nil은 '모른다'이고 false는 '나아지지 않았다'이다.** 잴 수 없는 지표(자책점 없는
    /// 시즌)와 그대로인 지표는 다른 말이라 섞지 않는다.
    public var improved: Bool? {
        guard let delta else { return nil }
        if delta == 0 { return false }
        return lowerIsBetter ? delta < 0 : delta > 0
    }
}

public struct ProSeasonComparison: Equatable, Sendable {
    public let previousSeason: Int
    public let currentSeason: Int
    public let metrics: [ProSeasonMetricChange]

    public init(previousSeason: Int, currentSeason: Int, metrics: [ProSeasonMetricChange]) {
        self.previousSeason = previousSeason
        self.currentSeason = currentSeason
        self.metrics = metrics
    }

    /// 가장 크게 나아진 지표. 결산 화면이 한 줄로 말할 것 — 표를 읽게 하지 않는다.
    /// 나아진 것이 하나도 없으면 nil이고, 그때는 비교표만 남는다.
    public var headline: ProSeasonMetricChange? {
        metrics
            .filter { $0.improved == true }
            .max { lhs, rhs in relativeGain(lhs) < relativeGain(rhs) }
    }

    /// 지표마다 단위가 달라 절대 변화량으로는 못 겨룬다. 작년 값 대비 비율로 견준다.
    private func relativeGain(_ change: ProSeasonMetricChange) -> Double {
        guard let delta = change.delta, let previous = change.previous, previous != 0 else { return 0 }
        return abs(delta / previous)
    }
}

public enum ProSeasonComparisonRules {
    /// 방금 끝난 시즌과 그 전 시즌을 견준다. 첫 시즌이거나 앞 시즌이 없으면 nil이다 —
    /// 견줄 대상이 없을 때 억지로 표를 만들지 않는다.
    public static func compare(state: ProCareerSnapshot) -> ProSeasonComparison? {
        guard ProGameplayRules.usesProfessionalBalance(state.proRulesVersion) else { return nil }
        let seasons = state.careerStats.sorted { $0.season < $1.season }
        guard seasons.count >= 2 else { return nil }
        let current = seasons[seasons.count - 1]
        let previous = seasons[seasons.count - 2]
        // 한 이닝도 던지지 않은 시즌은 비교의 한쪽이 될 수 없다(부상·군 복무).
        guard current.inningsOuts > 0, previous.inningsOuts > 0 else { return nil }
        return ProSeasonComparison(
            previousSeason: previous.season,
            currentSeason: current.season,
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
                change(.innings, previous, current, lowerIsBetter: false) {
                    PitchingMetrics.innings(outs: $0.inningsOuts)
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
    ) -> ProSeasonMetricChange {
        ProSeasonMetricChange(
            kind: kind,
            previous: value(previous),
            current: value(current),
            lowerIsBetter: lowerIsBetter
        )
    }

    public static let contentKeys: [String] = ProSeasonMetricKind.allCases.map(label)

    public static func label(_ kind: ProSeasonMetricKind) -> String {
        "content.season-comparison.\(kind.rawValue.replacingOccurrences(of: "_", with: "-"))"
    }
}
