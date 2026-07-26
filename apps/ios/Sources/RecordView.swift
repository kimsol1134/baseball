import SwiftUI
import SimulationCore

struct RecordView: View {
    let career: MobileCareerStore

    var body: some View {
        Group {
            if let state = career.state {
                RecordBoard(state: state)
            } else {
                ContentUnavailableView("기록 없음", systemImage: "chart.bar")
            }
        }
        .navigationTitle("기록")
        .navigationBarTitleDisplayMode(.inline)
        .background(BaseballTheme.canvas)
    }
}

private struct RecordBoard: View {
    let state: ProCareerSnapshot

    /// 아웃 카운트를 "이닝.아웃" 표기로 바꾼다. 야구 기록지와 같은 읽기 방식이다.
    private static func innings(_ outs: Int) -> String {
        "\(outs / 3)\(outs % 3 == 0 ? "" : ".\(outs % 3)")"
    }

    /// 9이닝당 실점. 코어가 자책점을 따로 세지 않으므로 평균자책이 아니라 실점으로 적는다.
    private static func runsPerNine(_ stats: ProSeasonStats) -> String {
        guard stats.inningsOuts > 0 else { return "-" }
        return String(format: "%.2f", Double(stats.runsAllowed) * 27 / Double(stats.inningsOuts))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                HStack(spacing: 10) {
                    Metric(title: "경기", value: "\(state.currentStats.games)")
                    Metric(title: "이닝", value: Self.innings(state.currentStats.inningsOuts))
                    Metric(title: "9이닝당 실점", value: Self.runsPerNine(state.currentStats))
                }
                HStack(spacing: 10) {
                    Metric(title: "탈삼진", value: "\(state.currentStats.strikeouts)", tone: .positive)
                    Metric(title: "볼넷", value: "\(state.currentStats.walks)", tone: .warning)
                    Metric(
                        title: "승-패-세이브",
                        value: GameLineFormat.record(
                            wins: state.currentStats.wins,
                            losses: state.currentStats.losses,
                            saves: state.currentStats.saves
                        )
                    )
                }

                BaseballCard(title: "현재 능력") {
                    VStack(alignment: .leading, spacing: 10) {
                        AbilityGaugeView(label: "구위", value: state.pitcher.stuff)
                        AbilityGaugeView(label: "제구", value: state.pitcher.command)
                        AbilityGaugeView(label: "변화구", value: state.pitcher.movement)
                        AbilityGaugeView(label: "체력", value: state.pitcher.stamina)
                    }
                }

                if let lines = state.gameLines, !lines.isEmpty {
                    GameLogSection(lines: lines)
                }

                if !state.careerStats.isEmpty {
                    BaseballCard(title: "통산 시즌") {
                        VStack(spacing: 6) {
                            ForEach(state.careerStats, id: \.season) { season in
                                HStack {
                                    Text("\(season.season)시즌").font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(
                                        "\(season.games)G · \(Self.innings(season.inningsOuts))이닝 · "
                                            + GameLineFormat.record(wins: season.wins, losses: season.losses, saves: season.saves)
                                            + " · " + GameLineFormat.runsPerNine(outs: season.inningsOuts, runs: season.runsAllowed)
                                    )
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(BaseballTheme.textSecondary)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }

                BaseballCard(title: "수상", tone: state.awards.isEmpty ? .standard : .milestone) {
                    if state.awards.isEmpty {
                        Text("아직 수상 기록이 없습니다.").font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(state.awards, id: \.self) { award in
                                Label(award, systemImage: "trophy.fill").foregroundStyle(BaseballTheme.milestone)
                            }
                        }
                    }
                }

                BaseballCard(title: "주요 기록") {
                    if state.milestones.isEmpty {
                        Text("아직 주요 기록이 없습니다.").font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(state.milestones.reversed().enumerated()), id: \.offset) { _, milestone in
                                Label(milestone, systemImage: "star.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(BaseballTheme.textSecondary)
                            }
                        }
                    }
                }

                if let score = state.hallOfFameScore {
                    BaseballCard(title: "명예의 전당 점수", tone: .milestone) {
                        Text("\(score)").font(.title2.bold().monospacedDigit())
                    }
                }
            }
            .padding(BaseballMetrics.gutter)
        }
        .background(BaseballTheme.canvas)
    }
}

/// 이번 시즌에 던진 경기들.
///
/// 이 목록이 이 화면의 존재 이유다. 예전에는 `advanceBlock()`으로 3주를 건너뛰면 그 3주의
/// 등판이 뉴스 한 줄로 증발했다. 시즌 합계만 남으니 "내가 이 시즌을 어떻게 보냈는지"가
/// 기억에 남지 않았고, 그건 이 게임이 파는 것 자체를 깎아먹는 일이다.
private struct GameLogSection: View {
    let lines: [ProGameLine]

    /// 구원이면 한 시즌에 70등판이 넘는다. 처음부터 다 펼치면 화면이 목록에 잡아먹힌다.
    @State private var showsAll = false
    private static let collapsedCount = 20

    private var visible: [ProGameLine] {
        let recent = lines.reversed()
        return showsAll ? Array(recent) : Array(recent.prefix(Self.collapsedCount))
    }

    var body: some View {
        BaseballCard(title: "이번 시즌 등판") {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(visible) { line in
                    GameLogRow(line: line)
                    if line.id != visible.last?.id {
                        Rectangle()
                            .fill(BaseballTheme.border.opacity(0.35))
                            .frame(height: 1)
                    }
                }
                if lines.count > Self.collapsedCount {
                    Button(showsAll ? "최근 \(Self.collapsedCount)경기만 보기" : "\(lines.count)경기 전체 보기") {
                        showsAll.toggle()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BaseballTheme.information)
                    .padding(.top, 12)
                }
            }
            .accessibilityIdentifier("record.gameLog")
        }
    }
}

private struct GameLogRow: View {
    let line: ProGameLine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 직접 던진 경기는 이 화면에서 유일한 강조다. 자동으로 지나간 경기와 섞이면
            // "내가 만든 성적"이라는 감각이 사라진다.
            if line.played {
                Text("직접 등판").eyebrowStyle(BaseballTheme.action)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(line.week)주차")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textTertiary)
                Text(GameLineFormat.role(line))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(BaseballTheme.textPrimary)
                Spacer()
                Text(GameLineFormat.score(line))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(BaseballTheme.textSecondary)
                if let decision = GameLineFormat.decisionLabel(line.decision) {
                    Text(decision)
                        .font(.footnote.weight(.heavy))
                        .foregroundStyle(GameLineFormat.decisionTone(line.decision))
                }
            }
            Text(GameLineFormat.pitchingLine(line))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(BaseballTheme.textSecondary)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(GameLineFormat.accessibilityLabel(line))
    }
}
