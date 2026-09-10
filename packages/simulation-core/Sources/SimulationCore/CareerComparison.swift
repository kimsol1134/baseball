import Foundation

/// 두 시점을 견주는 한 지표.
///
/// 시즌과 시즌(`ProSeasonComparisonRules`), 회차와 회차(`CareerLineageComparisonRules`)가
/// 같은 모양을 쓴다. **성장은 비교로만 느껴지고**, 무엇을 견주든 규칙은 같다 — 방향이 지표마다
/// 다르고, 모르는 것과 그대로인 것이 다른 말이라는 것.
public struct CareerMetricChange: Equatable, Sendable, Identifiable {
    public let id: String
    /// 화면이 이 지표를 무엇이라 부를지. `content.…` 시맨틱 키다.
    public let labelKey: String
    /// 잴 수 없으면 nil이고 화면은 `—`를 보여 준다.
    public let previous: Double?
    public let current: Double?
    /// 낮을수록 좋은 지표인가(평균자책·WHIP·볼넷).
    public let lowerIsBetter: Bool
    /// 어떻게 적을 값인가.
    public let format: Format

    public enum Format: String, Codable, Sendable {
        /// 소수 둘째 자리.
        case decimal
        /// 정수(승리·평가점수).
        case whole
        /// **야구 기록지 이닝.** 소수점 뒤는 십진수가 아니라 아웃 개수다 — 95⅔이닝은
        /// 95.70이 아니라 95.2로 적는다.
        case innings
    }

    public init(
        id: String,
        labelKey: String,
        previous: Double?,
        current: Double?,
        lowerIsBetter: Bool,
        format: Format = .decimal
    ) {
        self.id = id
        self.labelKey = labelKey
        self.previous = previous
        self.current = current
        self.lowerIsBetter = lowerIsBetter
        self.format = format
    }

    /// 나중 − 이전. 어느 한쪽이라도 없으면 nil이다 — **모르는 것을 0으로 세지 않는다.**
    public var delta: Double? {
        guard let previous, let current else { return nil }
        return current - previous
    }

    /// 나아졌는가.
    ///
    /// **nil은 '모른다'이고 false는 '나아지지 않았다'이다.** 잴 수 없는 지표와 그대로인
    /// 지표는 다른 말이라 섞지 않는다.
    public var improved: Bool? {
        guard let delta else { return nil }
        if delta == 0 { return false }
        return lowerIsBetter ? delta < 0 : delta > 0
    }
}

public struct CareerComparison: Equatable, Sendable {
    /// 무엇과 무엇을 견주는지. 화면이 "3시즌 → 4시즌" / "1회차 → 5회차"로 읽는다.
    public let previousLabel: Int
    public let currentLabel: Int
    public let metrics: [CareerMetricChange]

    public init(previousLabel: Int, currentLabel: Int, metrics: [CareerMetricChange]) {
        self.previousLabel = previousLabel
        self.currentLabel = currentLabel
        self.metrics = metrics
    }

    /// 가장 크게 나아진 지표. 화면이 한 줄로 말할 것 — 표를 읽게 하지 않는다.
    /// 나아진 것이 하나도 없으면 nil이고, 그때는 비교표만 남는다.
    public var headline: CareerMetricChange? {
        metrics
            .filter { $0.improved == true }
            .max { relativeGain($0) < relativeGain($1) }
    }

    /// 지표마다 단위가 달라 절대 변화량으로는 못 겨룬다. 이전 값 대비 비율로 견준다.
    private func relativeGain(_ change: CareerMetricChange) -> Double {
        guard let delta = change.delta, let previous = change.previous, previous != 0 else { return 0 }
        return abs(delta / previous)
    }
}
