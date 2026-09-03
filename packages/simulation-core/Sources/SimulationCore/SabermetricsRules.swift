import Foundation

/// Comparison of a derived rate against frozen league constants.
public enum SaberMetricsTone: Equatable, Sendable {
    case better
    case worse
    case even
}

/// Frozen league environment for FIP/WAR. v1 is measured from 400 starter outings
/// against a league-average batter (`simulation-cli --outings 400`, seed 20260726).
public struct SaberLeagueConstants: Equatable, Sendable {
    public let ra9Centi: Int
    public let k9Centi: Int
    public let bb9Centi: Int
    public let hr9Centi: Int
    public let h9Centi: Int
    public let whipCenti: Int
    public let kPermille: Int
    public let bbPermille: Int
    public let fipConstantCenti: Int

    public var fipCenti: Int { ra9Centi }

    public init(
        ra9Centi: Int,
        k9Centi: Int,
        bb9Centi: Int,
        hr9Centi: Int,
        h9Centi: Int,
        whipCenti: Int,
        kPermille: Int,
        bbPermille: Int,
        fipConstantCenti: Int
    ) {
        self.ra9Centi = ra9Centi
        self.k9Centi = k9Centi
        self.bb9Centi = bb9Centi
        self.hr9Centi = hr9Centi
        self.h9Centi = h9Centi
        self.whipCenti = whipCenti
        self.kPermille = kPermille
        self.bbPermille = bbPermille
        self.fipConstantCenti = fipConstantCenti
    }
}

/// One season or career total of derived pitching rates. All optional rates are nil at 0 innings.
public struct SaberMetricsLine: Equatable, Sendable, Identifiable {
    public let season: Int?
    public let inningsOuts: Int
    public let plateAppearances: Int
    public let k9Centi: Int?
    public let bb9Centi: Int?
    public let hr9Centi: Int?
    public let kPermille: Int?
    public let bbPermille: Int?
    public let kMinusBBPermille: Int?
    public let whipCenti: Int?
    public let ra9Centi: Int?
    public let fipCenti: Int?
    public let ra9Plus: Int?
    public let fipMinus: Int?
    public let warCenti: Int
    public let qualityStarts: Int
    public let qualityStartPermille: Int?
    public let inningsOutsPerStart: Int?
    public let pitchesPerInningCenti: Int?
    public let completeGames: Int
    public let shutouts: Int
    public let ra9Tone: SaberMetricsTone
    public let fipTone: SaberMetricsTone
    public let kPercentTone: SaberMetricsTone
    public let bbPercentTone: SaberMetricsTone
    public let whipTone: SaberMetricsTone
    public let warTone: SaberMetricsTone

    public var id: String { season.map(String.init) ?? "career" }
    public var isCareer: Bool { season == nil }

    public var inningsText: String { PitchingMetrics.inningsText(outs: inningsOuts) }
    public var ra9Text: String { Self.dashOrCenti(ra9Centi) }
    public var fipText: String { Self.dashOrCenti(fipCenti) }
    public var whipText: String { Self.dashOrCenti(whipCenti) }
    public var kPercentText: String { Self.dashOrPermille(kPermille) }
    public var bbPercentText: String { Self.dashOrPermille(bbPermille) }
    public var warText: String { Self.formatTenths(SabermetricsRules.divRound(warCenti, 10)) }

    public init(
        season: Int?,
        inningsOuts: Int,
        plateAppearances: Int,
        k9Centi: Int?,
        bb9Centi: Int?,
        hr9Centi: Int?,
        kPermille: Int?,
        bbPermille: Int?,
        kMinusBBPermille: Int?,
        whipCenti: Int?,
        ra9Centi: Int?,
        fipCenti: Int?,
        ra9Plus: Int?,
        fipMinus: Int?,
        warCenti: Int,
        qualityStarts: Int,
        qualityStartPermille: Int?,
        inningsOutsPerStart: Int?,
        pitchesPerInningCenti: Int?,
        completeGames: Int,
        shutouts: Int,
        ra9Tone: SaberMetricsTone,
        fipTone: SaberMetricsTone,
        kPercentTone: SaberMetricsTone,
        bbPercentTone: SaberMetricsTone,
        whipTone: SaberMetricsTone,
        warTone: SaberMetricsTone
    ) {
        self.season = season
        self.inningsOuts = inningsOuts
        self.plateAppearances = plateAppearances
        self.k9Centi = k9Centi
        self.bb9Centi = bb9Centi
        self.hr9Centi = hr9Centi
        self.kPermille = kPermille
        self.bbPermille = bbPermille
        self.kMinusBBPermille = kMinusBBPermille
        self.whipCenti = whipCenti
        self.ra9Centi = ra9Centi
        self.fipCenti = fipCenti
        self.ra9Plus = ra9Plus
        self.fipMinus = fipMinus
        self.warCenti = warCenti
        self.qualityStarts = qualityStarts
        self.qualityStartPermille = qualityStartPermille
        self.inningsOutsPerStart = inningsOutsPerStart
        self.pitchesPerInningCenti = pitchesPerInningCenti
        self.completeGames = completeGames
        self.shutouts = shutouts
        self.ra9Tone = ra9Tone
        self.fipTone = fipTone
        self.kPercentTone = kPercentTone
        self.bbPercentTone = bbPercentTone
        self.whipTone = whipTone
        self.warTone = warTone
    }

    public static func dashOrCenti(_ value: Int?) -> String {
        guard let value else { return "—" }
        return formatCenti(value)
    }

    public static func dashOrPermille(_ value: Int?) -> String {
        guard let value else { return "—" }
        return formatPermillePercent(value)
    }

    /// `312` → `"3.12"`.
    public static func formatCenti(_ value: Int) -> String {
        formatScaled(value, scale: 100, fractionDigits: 2)
    }

    /// `37` tenths → `"3.7"`.
    public static func formatTenths(_ value: Int) -> String {
        formatScaled(value, scale: 10, fractionDigits: 1)
    }

    /// `224` → `"22.4%"`.
    public static func formatPermillePercent(_ value: Int) -> String {
        formatScaled(value, scale: 10, fractionDigits: 1) + "%"
    }

    private static func formatScaled(_ value: Int, scale: Int, fractionDigits: Int) -> String {
        let negative = value < 0
        let absValue = abs(value)
        let whole = absValue / scale
        let fraction = absValue % scale
        let fractionText = String(format: "%0\(fractionDigits)d", fraction)
        return "\(negative ? "-" : "")\(whole).\(fractionText)"
    }
}

/// Season rows plus a career total. Career WAR is the sum of season WAR, not a recompute.
public struct SaberMetricsBoard: Equatable, Sendable {
    public let rows: [SaberMetricsLine]
    public let career: SaberMetricsLine

    public init(rows: [SaberMetricsLine], career: SaberMetricsLine) {
        self.rows = rows
        self.career = career
    }
}

/// Derived sabermetrics and a simplified FIP-based WAR. Display only — never persisted,
/// never fed into Hall of Fame, contracts, or goal-board completion.
///
/// Integer arithmetic only. Rates are centi (×100) or permille (×1000). WAR is ×100.
/// FIP uses the standard `(13HR+3BB−2K)/IP + constant` form; the spec table's `×27`
/// is the K/9 pattern and contradicts the FIP-constant formula, which divides by 9.
public enum SabermetricsRules {
    public enum LeagueConstants {
        /// 400 starter outings, 7073 outs: RA9 3.45, K/9 7.72, BB/9 2.26, HR/9 0.75,
        /// H/9 9.05, WHIP 1.26, K% 20.1, BB% 5.9. FIP constant 3.33 so league FIP = league RA9.
        public static let v1 = SaberLeagueConstants(
            ra9Centi: 345,
            k9Centi: 772,
            bb9Centi: 226,
            hr9Centi: 75,
            h9Centi: 905,
            whipCenti: 126,
            kPermille: 201,
            bbPermille: 59,
            fipConstantCenti: 333
        )
    }

    public static func season(
        _ stats: ProSeasonStats,
        lines: [ProGameLine] = [],
        constants: SaberLeagueConstants = LeagueConstants.v1
    ) -> SaberMetricsLine {
        line(stats: stats, lines: lines, season: stats.season, constants: constants)
    }

    public static func board(
        completed: [ProSeasonStats],
        current: ProSeasonStats?,
        currentLines: [ProGameLine] = [],
        constants: SaberLeagueConstants = LeagueConstants.v1
    ) -> SaberMetricsBoard {
        let completedSeasons = Set(completed.map(\.season))
        var statsRows = completed.sorted { $0.season < $1.season }
        var linesBySeason: [Int: [ProGameLine]] = [:]
        if let current, !completedSeasons.contains(current.season),
           current.games > 0 || current.inningsOuts > 0 {
            statsRows.append(current)
            linesBySeason[current.season] = currentLines
        }
        let rows = statsRows.map { season($0, lines: linesBySeason[$0.season] ?? [], constants: constants) }
        let careerLine = replacingWAR(
            line(stats: summing(statsRows), lines: [], season: nil, constants: constants),
            warCenti: rows.reduce(0) { $0 + $1.warCenti }
        )
        return SaberMetricsBoard(rows: rows, career: careerLine)
    }

    public static func plateAppearances(outs: Int, hits: Int, walks: Int) -> Int {
        max(0, outs) + max(0, hits) + max(0, walks)
    }

    public static func divRound(_ numerator: Int, _ denominator: Int) -> Int {
        guard denominator != 0 else { return 0 }
        if numerator >= 0 {
            return (numerator + denominator / 2) / denominator
        }
        return -(((-numerator) + denominator / 2) / denominator)
    }
}

private extension SabermetricsRules {
    static func line(
        stats: ProSeasonStats,
        lines: [ProGameLine],
        season: Int?,
        constants: SaberLeagueConstants
    ) -> SaberMetricsLine {
        let outs = max(0, stats.inningsOuts)
        let pa = plateAppearances(outs: outs, hits: stats.hits, walks: stats.walks)
        let k9 = per9Centi(stats.strikeouts, outs: outs)
        let bb9 = per9Centi(stats.walks, outs: outs)
        let hr9 = per9Centi(stats.homeRuns, outs: outs)
        let kPermille = ratePermille(stats.strikeouts, denominator: pa)
        let bbPermille = ratePermille(stats.walks, denominator: pa)
        let kMinusBB: Int?
        if let kPermille, let bbPermille {
            kMinusBB = kPermille - bbPermille
        } else {
            kMinusBB = nil
        }
        let whip = outs > 0 ? divRound((stats.hits + stats.walks) * 300, outs) : nil
        let ra9 = per9Centi(stats.runsAllowed, outs: outs)
        let fip = fipCenti(
            homeRuns: stats.homeRuns,
            walks: stats.walks,
            strikeouts: stats.strikeouts,
            outs: outs,
            constants: constants
        )
        let ra9Plus: Int?
        if let ra9, ra9 > 0 {
            ra9Plus = divRound(constants.ra9Centi * 100, ra9)
        } else {
            ra9Plus = nil
        }
        let fipMinus: Int?
        if let fip, constants.fipCenti > 0 {
            fipMinus = divRound(fip * 100, constants.fipCenti)
        } else {
            fipMinus = nil
        }
        let war = warCenti(stats: stats, fipCenti: fip, constants: constants)
        let qualityStarts = PitchingMetrics.qualityStarts(lines)
        let qsPermille = stats.starts > 0 ? divRound(qualityStarts * 1000, stats.starts) : nil
        let ipPerStart = stats.starts > 0 ? divRound(outs, stats.starts) : nil
        let pPerIP = outs > 0 ? divRound(stats.pitches * 300, outs) : nil
        let completeGames = lines.filter { $0.started && $0.outs >= 27 }.count
        let shutouts = lines.filter { $0.started && $0.outs >= 27 && $0.runsAllowed == 0 }.count
        return SaberMetricsLine(
            season: season,
            inningsOuts: outs,
            plateAppearances: pa,
            k9Centi: k9,
            bb9Centi: bb9,
            hr9Centi: hr9,
            kPermille: kPermille,
            bbPermille: bbPermille,
            kMinusBBPermille: kMinusBB,
            whipCenti: whip,
            ra9Centi: ra9,
            fipCenti: fip,
            ra9Plus: ra9Plus,
            fipMinus: fipMinus,
            warCenti: war,
            qualityStarts: qualityStarts,
            qualityStartPermille: qsPermille,
            inningsOutsPerStart: ipPerStart,
            pitchesPerInningCenti: pPerIP,
            completeGames: completeGames,
            shutouts: shutouts,
            ra9Tone: lowerBetter(ra9, league: constants.ra9Centi),
            fipTone: lowerBetter(fip, league: constants.fipCenti),
            kPercentTone: higherBetter(kPermille, league: constants.kPermille),
            bbPercentTone: lowerBetter(bbPermille, league: constants.bbPermille),
            whipTone: lowerBetter(whip, league: constants.whipCenti),
            warTone: war == 0 ? .even : (war > 0 ? .better : .worse)
        )
    }

    static func replacingWAR(
        _ line: SaberMetricsLine,
        warCenti: Int
    ) -> SaberMetricsLine {
        SaberMetricsLine(
            season: line.season,
            inningsOuts: line.inningsOuts,
            plateAppearances: line.plateAppearances,
            k9Centi: line.k9Centi,
            bb9Centi: line.bb9Centi,
            hr9Centi: line.hr9Centi,
            kPermille: line.kPermille,
            bbPermille: line.bbPermille,
            kMinusBBPermille: line.kMinusBBPermille,
            whipCenti: line.whipCenti,
            ra9Centi: line.ra9Centi,
            fipCenti: line.fipCenti,
            ra9Plus: line.ra9Plus,
            fipMinus: line.fipMinus,
            warCenti: warCenti,
            qualityStarts: line.qualityStarts,
            qualityStartPermille: line.qualityStartPermille,
            inningsOutsPerStart: line.inningsOutsPerStart,
            pitchesPerInningCenti: line.pitchesPerInningCenti,
            completeGames: line.completeGames,
            shutouts: line.shutouts,
            ra9Tone: line.ra9Tone,
            fipTone: line.fipTone,
            kPercentTone: line.kPercentTone,
            bbPercentTone: line.bbPercentTone,
            whipTone: line.whipTone,
            warTone: warCenti == 0 ? .even : (warCenti > 0 ? .better : .worse)
        )
    }

    static func per9Centi(_ count: Int, outs: Int) -> Int? {
        guard outs > 0 else { return nil }
        return divRound(count * 2700, outs)
    }

    static func ratePermille(_ count: Int, denominator: Int) -> Int? {
        guard denominator > 0 else { return nil }
        return divRound(count * 1000, denominator)
    }

    static func fipCenti(
        homeRuns: Int,
        walks: Int,
        strikeouts: Int,
        outs: Int,
        constants: SaberLeagueConstants
    ) -> Int? {
        guard outs > 0 else { return nil }
        let component = divRound((13 * homeRuns + 3 * walks - 2 * strikeouts) * 300, outs)
        return component + constants.fipConstantCenti
    }

    /// Replacement is 0.12 (starter) / 0.03 (relief) wins per 9 innings.
    /// With runsPerWin = 9 that is 1.08 / 0.27 RA9, so average 180 IP starter ≈ 2.40 WAR.
    static func warCenti(
        stats: ProSeasonStats,
        fipCenti: Int?,
        constants: SaberLeagueConstants
    ) -> Int {
        guard let fipCenti, stats.inningsOuts > 0, stats.games > 0 else { return 0 }
        let raap9 = constants.fipCenti - fipCenti
        let replacement = 27 + divRound(81 * max(0, stats.starts), stats.games)
        let leveragePermille = isCloser(stats) ? 1300 : 1000
        return divRound(
            (raap9 + replacement) * stats.inningsOuts * leveragePermille,
            243_000
        )
    }

    static func isCloser(_ stats: ProSeasonStats) -> Bool {
        stats.saves >= 10 && stats.starts == 0
    }

    static func lowerBetter(_ value: Int?, league: Int) -> SaberMetricsTone {
        guard let value else { return .even }
        if value < league { return .better }
        if value > league { return .worse }
        return .even
    }

    static func higherBetter(_ value: Int?, league: Int) -> SaberMetricsTone {
        guard let value else { return .even }
        if value > league { return .better }
        if value < league { return .worse }
        return .even
    }

    static func summing(_ seasons: [ProSeasonStats]) -> ProSeasonStats {
        seasons.reduce(ProSeasonStats(season: 0, teamID: "")) { total, season in
            ProSeasonStats(
                season: 0,
                teamID: "",
                games: total.games + season.games,
                starts: total.starts + season.starts,
                inningsOuts: total.inningsOuts + season.inningsOuts,
                strikeouts: total.strikeouts + season.strikeouts,
                walks: total.walks + season.walks,
                runsAllowed: total.runsAllowed + season.runsAllowed,
                hits: total.hits + season.hits,
                homeRuns: total.homeRuns + season.homeRuns,
                pitches: total.pitches + season.pitches,
                wins: total.wins + season.wins,
                losses: total.losses + season.losses,
                saves: total.saves + season.saves
            )
        }
    }
}
