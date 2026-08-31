import Foundation

/// 시즌을 한 문장으로 남기는 닫힌 제목 집합.
public enum ProSeasonArcTitle: String, Codable, Sendable {
    case firstHalfAce = "first_half_ace"
    case dominant = "dominant"
    case longTunnel = "long_tunnel"
    case lateRecovery = "late_recovery"
    case autumnDoorClosed = "autumn_door_closed"
    case autumnChampion = "autumn_champion"
    case autumnRunnerUp = "autumn_runner_up"
    case autumnEliminated = "autumn_eliminated"
    case autumnUnavailable = "autumn_unavailable"
    case quiet = "quiet"
}

public enum ProSeasonArcRules {
    public static func title(
        gameLines: [ProGameLine],
        postseason: ProPostseasonState?
    ) -> ProSeasonArcTitle {
        if let postseason {
            switch postseason.result {
            case .champion: return .autumnChampion
            case .runnerUp: return .autumnRunnerUp
            case .eliminated: return .autumnEliminated
            case .didNotQualify: return .autumnDoorClosed
            case .unavailable: return .autumnUnavailable
            case .inProgress: break
            }
        }

        let first = split(gameLines, in: 1...12)
        let second = split(gameLines, in: 13...24)
        let firstQuality = quality(first)
        let secondQuality = quality(second)
        switch (firstQuality, secondQuality) {
        case (.good, .poor): return .firstHalfAce
        case (.good, .good): return .dominant
        case (.poor, .poor): return .longTunnel
        case (.poor, .good): return .lateRecovery
        default: return .quiet
        }
    }

    public static func contentID(for title: ProSeasonArcTitle) -> String {
        "pro.arc.\(title.rawValue)"
    }

    private enum SplitQuality { case good, even, poor }

    private static func split(_ lines: [ProGameLine], in weeks: ClosedRange<Int>) -> (runs: Int, outs: Int) {
        lines.filter { weeks.contains($0.week) }.reduce((0, 0)) { partial, line in
            (partial.0 + line.runsAllowed, partial.1 + line.outs)
        }
    }

    private static func quality(_ split: (runs: Int, outs: Int)) -> SplitQuality {
        guard split.outs >= 27 else { return .even }
        let ra9 = split.runs * 27_000 / split.outs
        if ra9 < 3_500 { return .good }
        if ra9 >= 4_500 { return .poor }
        return .even
    }
}
