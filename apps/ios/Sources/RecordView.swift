import SwiftUI
import SimulationCore

/// 기록 탭.
///
/// 예전에는 프로 커리어만 읽었다. 그래서 고교에서 몇 경기를 던지고 기록 탭에 들어가도
/// **"기록 없음"**만 나왔다 — 게임의 첫 3년 내내 이 탭이 비어 있었다는 뜻이다. 프로가
/// 아직 없으면 고교 성적을 보여 준다.
struct RecordView: View {
    let highSchool: HighSchoolCareerStore
    let career: MobileCareerStore

    var body: some View {
        Group {
            if let state = career.state {
                RecordBoard(state: state, archive: highSchool.archive)
            } else if let hs = highSchool.state {
                HighSchoolRecordBoard(state: hs, archive: highSchool.archive, highSchoolPersonality: highSchool.personality)
            } else if !highSchool.archive.isEmpty {
                // 회차를 끝내고 아직 새로 시작하지 않은 상태 — 로그라이트의 재시작 동력은
                // "내가 남긴 것"을 보는 순간에 생긴다. 방금 끝낸 회차의 카드가 먼저 서고,
                // 그 아래 통산 보드(다음 이정표·별명 도감)가 다음 회차의 이유를 만든다.
                ScrollView {
                    VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                        if let last = highSchool.archive.first {
                            BaseballCard(title: "\(last.lifeNumber)회차가 남긴 것", tone: .milestone) {
                                VStack(alignment: .leading, spacing: 10) {
                                    LifeCardView(record: last)
                                        .scaleEffect(0.72, anchor: .top)
                                        .frame(height: LifeCardView.size.height * 0.72)
                                        .frame(maxWidth: .infinity)
                                    LifeCardShareButton(record: last)
                                }
                            }
                        }
                        LifeArchiveSection(records: highSchool.archive)
                    }
                    .padding(BaseballMetrics.gutter)
                }
                .background(BaseballTheme.canvas)
            } else {
                ContentUnavailableView("기록 없음", systemImage: "chart.bar")
            }
        }
        .navigationTitle("기록")
        .navigationBarTitleDisplayMode(.inline)
        .background(BaseballTheme.canvas)
    }
}

/// 고교 3년의 성적표.
///
/// 프로와 같은 구조로 읽히게 맞춘다 — 요약 숫자 → 능력 → 경기 목록. 다른 점은 직접 던진
/// 이닝과 팀이 자동으로 치른 경기가 섞여 있다는 것이고, 그건 `played` 눈썹이 구분한다.
private struct HighSchoolRecordBoard: View {
    let state: HighSchoolCareerSnapshot
    let archive: [HighSchoolCareerStore.LifeRecord]
    var highSchoolPersonality: Personality?

    private var lines: [ProGameLine] { state.seasonLog ?? [] }

    /// 직접 던진 이닝만 따로 센다. 자동 경기까지 합치면 "내가 만든 기록"이 묻힌다.
    private var pitchedOuts: Int { lines.filter(\.played).reduce(0) { $0 + $1.outs } }

    private static func innings(_ outs: Int) -> String {
        "\(outs / 3)\(outs % 3 == 0 ? "" : ".\(outs % 3)")"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                Text("\(state.chapter.title) · \(state.school?.name ?? "학교 미정")")
                    .eyebrowStyle(BaseballTheme.action)

                HStack(spacing: 10) {
                    Metric(title: "등판", value: "\(state.performance.importantGamesCompleted)")
                    Metric(title: "던진 이닝", value: Self.innings(pitchedOuts))
                    Metric(title: "투구 수", value: "\(state.performance.pitches)")
                }
                HStack(spacing: 10) {
                    Metric(title: "탈삼진", value: "\(state.performance.strikeouts)", tone: .positive)
                    Metric(title: "볼넷", value: "\(state.performance.walks)", tone: .warning)
                    Metric(title: "실점", value: "\(state.performance.runsAllowed)")
                }

                ProspectRankingCard(state: state)

                if let personality = highSchoolPersonality {
                    BaseballCard(title: "스카우트 노트 — 기질") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("'\(personality.title)'")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(BaseballTheme.milestone)
                            Text(personality.scoutLine)
                                .font(.footnote)
                                .foregroundStyle(BaseballTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("기질 특성 『\(personality.trait.title)』 — \(personality.trait.activationLine). 발동하면 승부 화면에 표시됩니다.")
                                .font(.caption)
                                .foregroundStyle(BaseballTheme.textSecondary)
                            Text("성격은 선택이 만듭니다. 경기 성적은 성격을 바꾸지 못합니다.")
                                .font(.caption2)
                                .foregroundStyle(BaseballTheme.textTertiary)
                        }
                    }
                }

                BaseballCard(title: "현재 능력") {
                    VStack(alignment: .leading, spacing: 10) {
                        AbilityGaugeView(label: "구위", value: state.pitcher.stuff)
                        AbilityGaugeView(label: "제구", value: state.pitcher.command)
                        AbilityGaugeView(label: "변화구", value: state.pitcher.movement)
                        AbilityGaugeView(label: "체력", value: state.pitcher.stamina)
                    }
                }

                if lines.isEmpty, state.performance.importantGamesCompleted == 0 {
                    // 0과 대시 12칸의 벽은 "내가 이해 못 하는 빈 표"다(QA P1-13).
                    BaseballCard(title: "기록") {
                        Text("첫 등판을 던지면 여기에 쌓입니다. 탈삼진·볼넷·실점부터 WHIP·FIP 같은 세부 지표까지, 던진 만큼 정확해집니다.")
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                AdvancedStatsCard(
                    // 회차 카드·아카이브의 "탈삼진"은 직접 등판 기준이라, 기준을 안 적으면
                    // 같은 회차에 두 개의 탈삼진이 존재하게 된다(QA P1-5).
                    title: "고교 통산 지표 · 팀 경기 포함",
                    outs: lines.reduce(0) { $0 + $1.outs },
                    hits: lines.reduce(0) { $0 + ($1.hits ?? 0) },
                    walks: lines.reduce(0) { $0 + $1.walks },
                    strikeouts: lines.reduce(0) { $0 + $1.strikeouts },
                    homeRuns: lines.reduce(0) { $0 + ($1.homeRuns ?? 0) },
                    runsAllowed: lines.reduce(0) { $0 + $1.runsAllowed },
                    lines: lines
                )
                }

                if lines.isEmpty {
                    BaseballCard(title: "경기 기록") {
                        Text("아직 치른 경기가 없습니다. 첫 중요 경기를 던지면 여기에 쌓입니다.")
                            .font(.subheadline)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    GameLogSection(title: "고교 경기", lines: lines)
                }

                if !state.selectedAwakenings.isEmpty {
                    BaseballCard(title: "각성", tone: .milestone) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(state.selectedAwakenings, id: \.self) { awakening in
                                Label(HighSchoolPresentation.awakening(awakening).title, systemImage: "sparkles")
                                    .font(.subheadline)
                                    .foregroundStyle(BaseballTheme.milestone)
                            }
                        }
                    }
                }

                if !archive.isEmpty { LifeArchiveSection(records: archive) }

                BaseballCard(title: "최근 소식") {
                    if state.news.isEmpty {
                        Text("아직 소식이 없습니다.").font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(state.news.prefix(8).enumerated()), id: \.offset) { _, item in
                                Label(item, systemImage: "star.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(BaseballTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .padding(BaseballMetrics.gutter)
        }
        .background(BaseballTheme.canvas)
    }
}

private struct RecordBoard: View {
    let state: ProCareerSnapshot
    let archive: [HighSchoolCareerStore.LifeRecord]

    /// 아웃 카운트를 "이닝.아웃" 표기로 바꾼다. 야구 기록지와 같은 읽기 방식이다.
    private static func innings(_ outs: Int) -> String {
        "\(outs / 3)\(outs % 3 == 0 ? "" : ".\(outs % 3)")"
    }

    /// 시즌 피안타·피홈런. 시즌 합계에는 없고 등판 목록에만 있다.
    private var seasonHits: Int {
        (state.gameLines ?? []).reduce(0) { $0 + ($1.hits ?? 0) }
    }

    private var seasonHomeRuns: Int {
        (state.gameLines ?? []).reduce(0) { $0 + ($1.homeRuns ?? 0) }
    }

    /// 투수 순위에 끼워 넣을 내 성적.
    private var playerRow: LeagueTable.PitcherRow {
        LeagueTable.PitcherRow(
            name: state.identity.name,
            teamName: state.team.name,
            inningsOuts: state.currentStats.inningsOuts,
            wins: state.currentStats.wins,
            losses: state.currentStats.losses,
            saves: state.currentStats.saves,
            strikeouts: state.currentStats.strikeouts,
            walks: state.currentStats.walks,
            hits: seasonHits,
            homeRuns: seasonHomeRuns,
            runsAllowed: state.currentStats.runsAllowed,
            isPlayer: true
        )
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

                AdvancedStatsCard(
                    title: "\(state.season)시즌 지표",
                    outs: state.currentStats.inningsOuts,
                    hits: seasonHits,
                    walks: state.currentStats.walks,
                    strikeouts: state.currentStats.strikeouts,
                    homeRuns: seasonHomeRuns,
                    runsAllowed: state.currentStats.runsAllowed,
                    lines: state.gameLines ?? []
                )

                StandingsCard(
                    season: state.season, seed: state.proCareerID,
                    week: state.week, myTeamID: state.team.id,
                    myGames: state.gameLines ?? []
                )

                PitcherLeaderboardCard(
                    season: state.season, seed: state.proCareerID,
                    week: state.week, player: playerRow
                )

                if let lines = state.gameLines, !lines.isEmpty {
                    GameLogSection(title: "이번 시즌 등판", lines: lines)
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

                if !archive.isEmpty { LifeArchiveSection(records: archive) }

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
    let title: String
    let lines: [ProGameLine]

    /// 구원이면 한 시즌에 70등판이 넘는다. 처음부터 다 펼치면 화면이 목록에 잡아먹힌다.
    @State private var showsAll = false
    private static let collapsedCount = 20

    private var visible: [ProGameLine] {
        let recent = lines.reversed()
        return showsAll ? Array(recent) : Array(recent.prefix(Self.collapsedCount))
    }

    var body: some View {
        BaseballCard(title: title) {
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


/// 전국 유망주 랭킹 — 드래프트 전에 세상이 매기는 중간 점수.
///
/// "전국에서 내가 몇 번째인가"가 매 경기 갱신되면 드래프트 기대감이 매주의
/// 감정이 된다. 20위 밖이면 몇 계단 남았는지를 보여 준다 — 진입 자체가 사건이다.
private struct ProspectRankingCard: View {
    let state: HighSchoolCareerSnapshot

    var body: some View {
        BaseballCard(title: "전국 유망주 랭킹", tone: .milestone) {
            if let rank = ProspectRanking.playerRank(performance: state.performance) {
                VStack(alignment: .leading, spacing: 8) {
                    // 가상 지명 명단 — 실제 드래프트와 같은 공식(분산만 제외)이라
                    // 예측이 결과를 배신하지 않는다. 경계 구간은 경계라고 말한다.
                    let forecast = HighSchoolCareerEngine.draftForecast(state: state)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("가상 지명 명단: \(forecast.band)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(forecast.score >= forecast.threshold ? BaseballTheme.action : BaseballTheme.textPrimary)
                        Text("평가 \(forecast.score)점 · 당락선 \(forecast.threshold)점 · \(forecast.interestedTeam)이(가) 주목")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textTertiary)
                    }
                    .accessibilityIdentifier("record.draftForecast")
                    Rectangle().fill(BaseballTheme.border.opacity(0.3)).frame(height: 1)
                    if rank <= ProspectRanking.boardSize {
                        let board = ProspectRanking.board(
                            careerID: state.careerID,
                            playerName: state.identity.name,
                            playerSchool: state.school?.name ?? "학교 미정",
                            performance: state.performance
                        )
                        // 내 순위 주변만 보여 준다 — 위로 두 칸(목표), 아래로 한 칸(추격자).
                        let window = board.filter { abs($0.rank - rank) <= 2 || $0.rank <= 3 }
                        ForEach(window) { entry in
                            HStack(spacing: 8) {
                                Text("\(entry.rank)")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(entry.isPlayer ? BaseballTheme.action : BaseballTheme.textTertiary)
                                    .frame(width: 22, alignment: .trailing)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("\(entry.name) · \(entry.school)")
                                        .font(.footnote.weight(entry.isPlayer ? .bold : .regular))
                                        .foregroundStyle(entry.isPlayer ? BaseballTheme.action : BaseballTheme.textPrimary)
                                    Text(entry.tag)
                                        .font(.caption2)
                                        .foregroundStyle(BaseballTheme.textTertiary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    } else {
                        Text("현재 \(rank)위권 — 랭킹 발표는 20위까지입니다.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BaseballTheme.textPrimary)
                        Text("스카우트들은 이미 지켜보고 있습니다. \(rank - ProspectRanking.boardSize)계단을 오르면 전국에 이름이 실립니다.")
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityIdentifier("record.prospectRanking")
            } else {
                Text("아직 세상이 이 이름을 모릅니다. 첫 등판이 시작입니다.")
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
            }
        }
    }
}
