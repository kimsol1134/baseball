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

    private var faced: Int { PitchingMetrics.battersFaced(outs: outs, hits: hits, walks: walks) }

    var body: some View {
        BaseballCard(title: title) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Metric(title: "이닝", value: PitchingMetrics.inningsText(outs: outs))
                    Metric(title: "9이닝당 실점", value: decimal(PitchingMetrics.runsPer9(runs: runsAllowed, outs: outs)))
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
                    Metric(title: "탈삼진율", value: PitchingMetrics.rateText(
                        PitchingMetrics.strikeoutRate(strikeouts: strikeouts, battersFaced: faced)
                    ))
                    Metric(title: "BABIP", value: PitchingMetrics.rateText(
                        PitchingMetrics.babip(
                            hits: hits, homeRuns: homeRuns, strikeouts: strikeouts, outs: outs, walks: walks
                        )
                    ))
                    Metric(title: "퀄리티스타트", value: "\(PitchingMetrics.qualityStarts(lines))")
                }

                // 숫자만 있으면 읽는 사람이 기준을 모른다. 두 줄로 기준을 준다.
                Text(interpretation)
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("자책점을 따로 세지 않아 평균자책점 대신 9이닝당 실점을 씁니다. 퀄리티스타트도 6이닝 3실점 이하 기준입니다.")
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
        else { return "표본이 아직 적습니다. 10이닝을 넘기면 지표가 의미를 갖기 시작합니다." }
        let gap = ra9 - fip
        if gap > 0.6 {
            return "실점이 FIP보다 높습니다. 수비와 운이 불리하게 작용했다는 뜻이라, 같은 내용이면 성적이 좋아질 여지가 있습니다."
        }
        if gap < -0.6 {
            return "실점이 FIP보다 낮습니다. 수비와 운이 도왔다는 뜻이라, 내용이 그대로면 성적은 나빠질 수 있습니다."
        }
        return "실점과 FIP가 비슷합니다. 지금 성적이 내용 그대로라는 뜻입니다."
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
    /// 내 팀. 목록에서 강조한다.
    let myTeamID: String

    private var rows: [LeagueTable.StandingRow] {
        LeagueTable.standings(season: season, seed: seed, gamesPlayed: LeagueTable.gamesPlayed(week: week))
    }

    var body: some View {
        BaseballCard(title: "\(season)시즌 순위") {
            VStack(spacing: 0) {
                HStack {
                    Text("팀").font(.caption2.weight(.bold)).foregroundStyle(BaseballTheme.textTertiary)
                    Spacer()
                    Text("승-패-무  승률   승차")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(BaseballTheme.textTertiary)
                }
                .padding(.bottom, 6)

                let all = rows
                ForEach(Array(all.enumerated()), id: \.element.id) { index, row in
                    let mine = row.teamID == myTeamID
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textTertiary)
                            .frame(width: 18, alignment: .trailing)
                        Text(row.teamName)
                            .font(.footnote.weight(mine ? .bold : .regular))
                            .foregroundStyle(mine ? BaseballTheme.action : BaseballTheme.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(row.wins)-\(row.losses)-\(row.draws)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textSecondary)
                        Text(PitchingMetrics.rateText(row.winRate))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textPrimary)
                            .frame(width: 40, alignment: .trailing)
                        Text(index == 0 ? "-" : String(format: "%.1f", LeagueTable.gamesBehind(row, leader: all[0])))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textTertiary)
                            .frame(width: 34, alignment: .trailing)
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(index + 1)위 \(row.teamName), \(row.wins)승 \(row.losses)패 \(row.draws)무, 승률 \(PitchingMetrics.rateText(row.winRate))"
                    )
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

    private var rows: [LeagueTable.PitcherRow] {
        LeagueTable.pitchers(
            season: season, seed: seed,
            gamesPlayed: LeagueTable.gamesPlayed(week: week),
            player: player, sort: sort
        )
    }

    var body: some View {
        BaseballCard(title: "투수 순위") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("정렬", selection: $sort) {
                    ForEach(LeagueTable.PitcherSort.allCases, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                let all = rows
                // 상위 10명과 내 선수. 전부 보여 주면 목록이 화면을 잡아먹는다.
                let visible = Array(all.prefix(10)) + (all.prefix(10).contains { $0.isPlayer } ? [] : all.filter(\.isPlayer))
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, row in
                    let rank = (all.firstIndex { $0.id == row.id } ?? index) + 1
                    HStack(spacing: 8) {
                        Text("\(rank)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textTertiary)
                            .frame(width: 20, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(row.name)
                                .font(.footnote.weight(row.isPlayer ? .bold : .regular))
                                .foregroundStyle(row.isPlayer ? BaseballTheme.action : BaseballTheme.textPrimary)
                            Text(row.teamName)
                                .font(.caption2)
                                .foregroundStyle(BaseballTheme.textTertiary)
                        }
                        Spacer(minLength: 4)
                        Text(value(for: row))
                            .font(.footnote.weight(.semibold).monospacedDigit())
                            .foregroundStyle(BaseballTheme.textPrimary)
                        Text("\(PitchingMetrics.inningsText(outs: row.inningsOuts))이닝")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textTertiary)
                            .frame(width: 58, alignment: .trailing)
                    }
                    .padding(.vertical, 5)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(rank)위 \(row.name), \(row.teamName), \(sort.title) \(value(for: row))")
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
        case .wins: "\(row.wins)승 \(row.losses)패"
        }
    }
}
