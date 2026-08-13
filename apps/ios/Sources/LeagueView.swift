import SwiftUI
import SimulationCore

/// 요즘 야구 팬이 실제로 보는 숫자들.
///
/// 이닝·탈삼진 같은 원시 기록만으로는 "이 시즌이 좋았는가"를 판단할 수 없다. 그 판단을
/// 못 하면 3년을 쌓는 게임이 숫자 나열이 된다.
///
/// 계산은 전부 코어(`PitchingMetrics`)가 한다. 화면은 이름과 배치만 정한다.
struct AdvancedStatsCard: View {
    let title: String
    let outs: Int
    let hits: Int
    let walks: Int
    let strikeouts: Int
    let homeRuns: Int
    let runsAllowed: Int
    /// 등판 목록이 있으면 퀄리티스타트를 센다.
    var lines: [ProGameLine] = []
    @Environment(\.gameCopyResolver) private var copyResolver

    private var faced: Int { PitchingMetrics.battersFaced(outs: outs, hits: hits, walks: walks) }

    var body: some View {
        BaseballCard(title: title) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Metric(
                        title: copyResolver.resolve(.leagueInnings),
                        value: GameFormatters.innings(outs: outs, language: copyResolver.language)
                    )
                    Metric(
                        title: copyResolver.resolve(.leagueRA9),
                        value: decimal(PitchingMetrics.runsPer9(runs: runsAllowed, outs: outs))
                    )
                    Metric(title: "WHIP", value: decimal(PitchingMetrics.whip(hits: hits, walks: walks, outs: outs)))
                }
                HStack(spacing: 10) {
                    Metric(title: "K/9", value: decimal(PitchingMetrics.per9(strikeouts, outs: outs)), tone: .positive)
                    Metric(title: "BB/9", value: decimal(PitchingMetrics.per9(walks, outs: outs)), tone: .warning)
                    Metric(title: "K/BB", value: decimal(PitchingMetrics.strikeoutToWalk(strikeouts: strikeouts, walks: walks)))
                }
                HStack(spacing: 10) {
                    Metric(title: "H/9", value: decimal(PitchingMetrics.per9(hits, outs: outs)))
                    Metric(title: "HR/9", value: decimal(PitchingMetrics.per9(homeRuns, outs: outs)))
                    Metric(
                        title: "FIP",
                        value: decimal(PitchingMetrics.fip(
                            homeRuns: homeRuns, walks: walks, strikeouts: strikeouts, outs: outs
                        ))
                    )
                }
                HStack(spacing: 10) {
                    Metric(title: copyResolver.resolve(.leagueStrikeoutRate), value: PitchingMetrics.rateText(
                        PitchingMetrics.strikeoutRate(strikeouts: strikeouts, battersFaced: faced)
                    ))
                    Metric(title: "BABIP", value: PitchingMetrics.rateText(
                        PitchingMetrics.babip(
                            hits: hits, homeRuns: homeRuns, strikeouts: strikeouts, outs: outs, walks: walks
                        )
                    ))
                    Metric(
                        title: copyResolver.resolve(.leagueQualityStarts),
                        value: "\(PitchingMetrics.qualityStarts(lines))"
                    )
                }

                // 숫자만 있으면 읽는 사람이 기준을 모른다. 두 줄로 기준을 준다.
                // localization-safe: resolved-copy
                Text(interpretation)
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(copyResolver.resolve(.leagueMethodNote))
                    .font(.caption)
                    .foregroundStyle(BaseballTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// FIP와 실점을 견줘 "수비와 운이 어느 쪽으로 작용했는지"를 한 줄로 말한다.
    private var interpretation: String {
        guard outs >= 30,
              let ra9 = PitchingMetrics.runsPer9(runs: runsAllowed, outs: outs),
              let fip = PitchingMetrics.fip(homeRuns: homeRuns, walks: walks, strikeouts: strikeouts, outs: outs)
        else { return copyResolver.resolve(.leagueSmallSample) }
        let gap = ra9 - fip
        if gap > 0.6 {
            return copyResolver.resolve(.leagueFIPHigher)
        }
        if gap < -0.6 {
            return copyResolver.resolve(.leagueFIPLower)
        }
        return copyResolver.resolve(.leagueFIPAligned)
    }

    private func decimal(_ value: Double?) -> String {
        guard let value else { return "-" }
        return String(format: "%.2f", value)
    }
}

/// 리그 순위표. 승-패-무, 승률, 승차.
struct StandingsCard: View {
    let season: Int
    let seed: String
    let week: Int
    /// 내 팀. 목록에서 강조하고, 내 경기의 실제 결과가 이 팀 기록에 들어간다.
    let myTeamID: String
    /// 내가 등판한 경기들. 이게 없으면 내가 아무리 잘 던져도 우리 팀 순위가 안 움직인다.
    var myGames: [ProGameLine] = []
    @Environment(\.gameCopyResolver) private var copyResolver

    private var rows: [LeagueTable.StandingRow] {
        LeagueTable.standings(
            season: season, seed: seed,
            gamesPlayed: LeagueTable.gamesPlayed(week: week),
            playerTeamID: myTeamID,
            playerResults: myGames.map {
                LeagueTable.PlayerGameResult(teamRuns: $0.teamRuns, opponentRuns: $0.opponentRuns)
            }
        )
    }

    var body: some View {
        BaseballCard(title: copyResolver.resolve(.leagueStandingsTitle, arguments: [.integer(season)])) {
            VStack(spacing: 0) {
                HStack {
                    Text(copyResolver.resolve(.leagueTeam))
                        .font(.caption2.weight(.bold)).foregroundStyle(BaseballTheme.textTertiary)
                    Spacer()
                    Text(copyResolver.resolve(.leagueHeader))
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(BaseballTheme.textTertiary)
                }
                .padding(.bottom, 6)

                let all = rows
                ForEach(Array(all.enumerated()), id: \.element.id) { index, row in
                    let mine = row.teamID == myTeamID
                    let localizedTeam = ProCareerPresentation.leagueTeamName(
                        row.teamName,
                        resolver: copyResolver
                    )
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textTertiary)
                            .frame(width: 18, alignment: .trailing)
                        // localization-safe: resolved-copy
                        Text(localizedTeam)
                            .font(.footnote.weight(mine ? .bold : .regular))
                            .foregroundStyle(mine ? BaseballTheme.action : BaseballTheme.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(row.wins)-\(row.losses)-\(row.draws)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textSecondary)
                        // localization-safe: numeric
                        Text(PitchingMetrics.rateText(row.winRate))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textPrimary)
                            .frame(width: 40, alignment: .trailing)
                        // localization-safe: numeric
                        Text(index == 0 ? "-" : String(format: "%.1f", LeagueTable.gamesBehind(row, leader: all[0])))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textTertiary)
                            .frame(width: 34, alignment: .trailing)
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(copyResolver.resolve(
                        .leagueStandingAccessibility,
                        arguments: [
                            .integer(index + 1),
                            .userText(localizedTeam),
                            .integer(row.wins),
                            .integer(row.losses),
                            .integer(row.draws),
                            .userText(PitchingMetrics.rateText(row.winRate)),
                        ]
                    ))
                    if row.id != all.last?.id {
                        Rectangle().fill(BaseballTheme.border.opacity(0.3)).frame(height: 1)
                    }
                }
            }
            .accessibilityIdentifier("record.standings")
        }
    }
}

/// 리그 투수 순위. 내 선수가 목록 안에 함께 들어간다.
struct PitcherLeaderboardCard: View {
    let season: Int
    let seed: String
    let week: Int
    let player: LeagueTable.PitcherRow?

    @State private var sort: LeagueTable.PitcherSort = .runsPer9
    @Environment(\.gameCopyResolver) private var copyResolver

    private var rows: [LeagueTable.PitcherRow] {
        LeagueTable.pitchers(
            season: season, seed: seed,
            gamesPlayed: LeagueTable.gamesPlayed(week: week),
            player: player, sort: sort
        )
    }

    var body: some View {
        BaseballCard(title: copyResolver.resolve(.leaguePitchersTitle)) {
            VStack(alignment: .leading, spacing: 10) {
                Picker(copyResolver.resolve(.leagueSort), selection: $sort) {
                    ForEach(LeagueTable.PitcherSort.allCases, id: \.self) { option in
                        // localization-safe: resolved-copy
                        Text(sortTitle(option)).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                let all = rows
                // 상위 10명과 내 선수. 전부 보여 주면 목록이 화면을 잡아먹는다.
                let visible = Array(all.prefix(10)) + (all.prefix(10).contains { $0.isPlayer } ? [] : all.filter(\.isPlayer))
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, row in
                    let rank = (all.firstIndex { $0.id == row.id } ?? index) + 1
                    let localizedName = ProCareerPresentation.leaguePitcherName(
                        row.name,
                        isPlayer: row.isPlayer,
                        resolver: copyResolver
                    )
                    let localizedTeam = ProCareerPresentation.leagueTeamName(
                        row.teamName,
                        resolver: copyResolver
                    )
                    HStack(spacing: 8) {
                        Text("\(rank)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textTertiary)
                            .frame(width: 20, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 0) {
                            // localization-safe: resolved-copy
                            Text(localizedName)
                                .font(.footnote.weight(row.isPlayer ? .bold : .regular))
                                .foregroundStyle(row.isPlayer ? BaseballTheme.action : BaseballTheme.textPrimary)
                            // localization-safe: resolved-copy
                            Text(localizedTeam)
                                .font(.caption2)
                                .foregroundStyle(BaseballTheme.textTertiary)
                        }
                        Spacer(minLength: 4)
                        // localization-safe: numeric
                        Text(value(for: row))
                            .font(.footnote.weight(.semibold).monospacedDigit())
                            .foregroundStyle(BaseballTheme.textPrimary)
                        Text(copyResolver.resolve(
                            .leagueInningsValue,
                            arguments: [.userText(PitchingMetrics.inningsText(outs: row.inningsOuts))]
                        ))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textTertiary)
                            .frame(width: 58, alignment: .trailing)
                    }
                    .padding(.vertical, 5)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(copyResolver.resolve(
                        .leaguePitcherAccessibility,
                        arguments: [
                            .integer(rank),
                            .userText(localizedName),
                            .userText(localizedTeam),
                            .userText(sortTitle(sort)),
                            .userText(value(for: row)),
                        ]
                    ))
                }
            }
            .accessibilityIdentifier("record.pitcherLeaders")
        }
    }

    private func value(for row: LeagueTable.PitcherRow) -> String {
        switch sort {
        case .runsPer9: row.runsPer9.map { String(format: "%.2f", $0) } ?? "-"
        case .whip: row.whip.map { String(format: "%.2f", $0) } ?? "-"
        case .strikeouts: "\(row.strikeouts)"
        case .wins:
            copyResolver.resolve(
                .leagueWinLoss,
                arguments: [.integer(row.wins), .integer(row.losses)]
            )
        }
    }

    private func sortTitle(_ value: LeagueTable.PitcherSort) -> String {
        switch value {
        case .runsPer9: copyResolver.resolve(.leagueSortRA9)
        case .whip: copyResolver.resolve(.leagueSortWHIP)
        case .strikeouts: copyResolver.resolve(.leagueSortStrikeouts)
        case .wins: copyResolver.resolve(.leagueSortWins)
        }
    }
}
