import Foundation

/// 기록표 한 칸.
public struct CareerRecordEntry: Equatable, Sendable, Identifiable {
    public let id: String
    /// 야구 기록지의 약어(G·IP·ERA…). 언어를 타지 않는 표기라 그대로 쓴다.
    public let abbreviation: String
    /// 잴 수 없으면 nil이고 화면은 `—`를 보여 준다.
    public let value: String?

    public init(id: String, abbreviation: String, value: String?) {
        self.id = id
        self.abbreviation = abbreviation
        self.value = value
    }
}

/// 투수 기록표.
///
/// 카드가 지표를 넷씩 골라 보여 주면 "잘한 것만 고른 표"가 된다. 기록지는 고른 것이 아니라
/// **정해진 칸이 전부 있는 표**이고, 그래야 다른 선수·다른 시즌과 나란히 놓을 수 있다.
///
/// 두 가지가 규칙이다. **분모는 언제나 아웃 수를 3으로 나눈 이닝**이고(경기 수가 아니다),
/// **모르는 값은 `—`이지 0이 아니다** — 자책점 원장이 없는 시즌의 평균자책이 0.00으로 찍히면
/// 그 시즌이 완봉 시즌으로 읽힌다.
public enum CareerRecordTableRules {
    /// 세는 지표 열둘. 순서는 기록지 관례를 따른다.
    public static func counting(_ stats: ProSeasonStats) -> [CareerRecordEntry] {
        [
            entry("games", "G", stats.games),
            entry("starts", "GS", stats.starts),
            entry("wins", "W", stats.wins),
            entry("losses", "L", stats.losses),
            entry("saves", "SV", stats.saves),
            CareerRecordEntry(
                id: "innings",
                abbreviation: "IP",
                value: stats.inningsOuts > 0 ? PitchingMetrics.inningsText(outs: stats.inningsOuts) : nil
            ),
            entry("hits", "H", stats.hits),
            entry("homeRuns", "HR", stats.homeRuns),
            entry("walks", "BB", stats.walks),
            entry("strikeouts", "SO", stats.strikeouts),
            entry("runs", "R", stats.runsAllowed),
            entry("pitches", "NP", stats.pitches),
        ]
    }

    /// 비율 지표.
    ///
    /// **한 이닝도 던지지 않았으면 전부 `—`다.** K/BB는 볼넷으로 나누므로 이닝과 무관하게
    /// 값이 나오지만, 던진 적이 없는 시즌에 삼진/볼넷 비율만 덩그러니 찍히면 그 줄은
    /// 있지도 않은 등판을 말하는 셈이 된다. 표는 한 줄이 한 시즌이고, 없는 시즌은 통째로
    /// 모르는 것이다.
    public static func rates(_ stats: ProSeasonStats) -> [CareerRecordEntry] {
        let outs = stats.inningsOuts
        guard outs > 0 else {
            return ["ERA", "RA/9", "WHIP", "K/9", "BB/9", "H/9", "K/BB"].map {
                CareerRecordEntry(id: $0.lowercased(), abbreviation: $0, value: nil)
            }
        }
        return [
            // 평균자책은 원장이 있는 시즌만 성립한다(규칙 12 이상). 실점으로 대신하지 않는다.
            rate("era", "ERA", stats.earnedRuns.flatMap { PitchingMetrics.runsPer9(runs: $0, outs: outs) }),
            rate("ra9", "RA/9", PitchingMetrics.runsPer9(runs: stats.runsAllowed, outs: outs)),
            rate("whip", "WHIP", PitchingMetrics.whip(hits: stats.hits, walks: stats.walks, outs: outs)),
            rate("k9", "K/9", PitchingMetrics.per9(stats.strikeouts, outs: outs)),
            rate("bb9", "BB/9", PitchingMetrics.per9(stats.walks, outs: outs)),
            rate("h9", "H/9", PitchingMetrics.per9(stats.hits, outs: outs)),
            rate("kbb", "K/BB", PitchingMetrics.strikeoutToWalk(strikeouts: stats.strikeouts, walks: stats.walks)),
        ]
    }

    /// 여러 시즌을 한 줄로 합친다. **자책점은 모든 시즌에 원장이 있을 때만 합쳐진다** —
    /// 한 시즌이라도 모르면 통산 평균자책도 모른다.
    public static func total(_ seasons: [ProSeasonStats]) -> ProSeasonStats {
        let earned: Int? = seasons.allSatisfy { $0.earnedRuns != nil }
            ? seasons.reduce(0) { $0 + ($1.earnedRuns ?? 0) }
            : nil
        return ProSeasonStats(
            season: seasons.last?.season ?? 0,
            teamID: seasons.last?.teamID ?? "",
            games: seasons.reduce(0) { $0 + $1.games },
            starts: seasons.reduce(0) { $0 + $1.starts },
            inningsOuts: seasons.reduce(0) { $0 + $1.inningsOuts },
            strikeouts: seasons.reduce(0) { $0 + $1.strikeouts },
            walks: seasons.reduce(0) { $0 + $1.walks },
            runsAllowed: seasons.reduce(0) { $0 + $1.runsAllowed },
            hits: seasons.reduce(0) { $0 + $1.hits },
            homeRuns: seasons.reduce(0) { $0 + $1.homeRuns },
            pitches: seasons.reduce(0) { $0 + $1.pitches },
            wins: seasons.reduce(0) { $0 + $1.wins },
            losses: seasons.reduce(0) { $0 + $1.losses },
            saves: seasons.reduce(0) { $0 + $1.saves },
            earnedRuns: earned
        )
    }

    private static func entry(_ id: String, _ abbreviation: String, _ value: Int) -> CareerRecordEntry {
        CareerRecordEntry(id: id, abbreviation: abbreviation, value: String(value))
    }

    private static func rate(_ id: String, _ abbreviation: String, _ value: Double?) -> CareerRecordEntry {
        CareerRecordEntry(
            id: id,
            abbreviation: abbreviation,
            value: value.map { String(format: "%.2f", $0) }
        )
    }
}
