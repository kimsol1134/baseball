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
    var weekly: WeeklyProgramStore = .shared
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        Group {
            if let state = career.state {
                RecordBoard(
                    state: state,
                    archive: highSchool.archive,
                    weekly: weekly,
                    highSchool: highSchool
                )
            } else if let hs = highSchool.state {
                HighSchoolRecordBoard(
                    state: hs,
                    archive: highSchool.archive,
                    highSchoolPersonality: highSchool.personality,
                    weekly: weekly,
                    highSchool: highSchool
                )
            } else if !highSchool.archive.isEmpty {
                // 회차를 끝내고 아직 새로 시작하지 않은 상태 — 로그라이트의 재시작 동력은
                // "내가 남긴 것"을 보는 순간에 생긴다. 방금 끝낸 회차의 카드가 먼저 서고,
                // 그 아래 통산 보드(다음 이정표·별명 도감)가 다음 회차의 이유를 만든다.
                ScrollView {
                    VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                        WeeklyProgramView(
                            store: weekly,
                            highSchool: highSchool
                        )
                        if let last = highSchool.archive.first {
                            BaseballCard(
                                title: copyResolver.resolve(
                                    .archivedPlayer,
                                    arguments: [.integer(last.lifeNumber)]
                                ),
                                tone: .milestone
                            ) {
                                VStack(alignment: .leading, spacing: 10) {
                                    LifeCardPreview(record: last)
                                    LifeCardShareButton(record: last)
                                }
                            }
                        }
                        LifeArchiveSection(records: highSchool.archive)
                        AchievementsLinkCard()
                    }
                    .padding(BaseballMetrics.gutter)
                }
                .background(BaseballTheme.canvas)
            } else if weekly.program != nil || !weekly.stamps.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                        WeeklyProgramView(
                            store: weekly,
                            highSchool: highSchool
                        )
                    }
                    .padding(BaseballMetrics.gutter)
                }
            } else {
                ContentUnavailableView(copyResolver.resolve(.empty), systemImage: "chart.bar")
            }
        }
        .navigationTitle(copyResolver.resolve(.navigation))
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
    let weekly: WeeklyProgramStore
    let highSchool: HighSchoolCareerStore
    @Environment(\.gameCopyResolver) private var copyResolver

    private var lines: [ProGameLine] { state.seasonLog ?? [] }

    /// 직접 던진 이닝만 따로 센다. 자동 경기까지 합치면 "내가 만든 기록"이 묻힌다.
    private var pitchedOuts: Int { lines.filter(\.played).reduce(0) { $0 + $1.outs } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                WeeklyProgramView(
                    store: weekly,
                    highSchool: highSchool
                )
                Text(copyResolver.resolve(
                    .highSchoolHeader,
                    arguments: [
                        .userText(HighSchoolPresentation.localizedChapterTitle(
                            state.chapter,
                            resolver: copyResolver
                        )),
                        .userText(localizedSchoolName),
                    ]
                ))
                    .eyebrowStyle(BaseballTheme.action)

                HStack(spacing: 10) {
                    Metric(title: copyResolver.resolve(.appearances), value: "\(state.performance.importantGamesCompleted)")
                    Metric(
                        title: copyResolver.resolve(.pitchedInnings),
                        value: GameFormatters.innings(outs: pitchedOuts, language: copyResolver.language)
                    )
                    Metric(title: copyResolver.resolve(.pitches), value: "\(state.performance.pitches)")
                }
                HStack(spacing: 10) {
                    Metric(title: copyResolver.resolve(.strikeouts), value: "\(state.performance.strikeouts)", tone: .positive)
                    Metric(title: copyResolver.resolve(.walks), value: "\(state.performance.walks)", tone: .warning)
                    Metric(title: copyResolver.resolve(.runs), value: "\(state.performance.runsAllowed)")
                    // 팬 관심 — 호투가 쌓아 온 시선. 어디에도 안 보이면 죽은 숫자다.
                    Metric(title: copyResolver.resolve(.fanInterest), value: "\(state.fanInterest)")
                }

                ProspectRankingCard(state: state)

                if let personality = highSchoolPersonality {
                    BaseballCard(title: copyResolver.resolve(.scoutTemperament)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(copyResolver.resolve(
                                .personalityTitle,
                                arguments: [.userText(HighSchoolConclusionPresentation.localizedPersonalityTitle(
                                    personality,
                                    resolver: copyResolver
                                ))]
                            ))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(BaseballTheme.milestone)
                            Text(HighSchoolConclusionPresentation.localizedPersonalityScoutLine(
                                personality,
                                resolver: copyResolver
                            ))
                                .font(.footnote)
                                .foregroundStyle(BaseballTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(copyResolver.resolve(
                                .personalityTrait,
                                arguments: [
                                    .userText(HighSchoolPresentation.localizedPersonalityTraitTitle(
                                        personality.trait,
                                        resolver: copyResolver
                                    )),
                                    .userText(HighSchoolPresentation.localizedPersonalityTraitActivation(
                                        personality.trait,
                                        resolver: copyResolver
                                    )),
                                ]
                            ))
                                .font(.caption)
                                .foregroundStyle(BaseballTheme.textSecondary)
                            Text(copyResolver.resolve(.personalityRule))
                                .font(.caption2)
                                .foregroundStyle(BaseballTheme.textTertiary)
                        }
                    }
                }

                BaseballCard(title: copyResolver.resolve(.currentAbility)) {
                    VStack(alignment: .leading, spacing: 10) {
                        AbilityGaugeView(label: copyResolver.resolve(.stuff), value: state.pitcher.stuff)
                        AbilityGaugeView(label: copyResolver.resolve(.command), value: state.pitcher.command)
                        AbilityGaugeView(label: copyResolver.resolve(.movement), value: state.pitcher.movement)
                        AbilityGaugeView(label: copyResolver.resolve(.stamina), value: state.pitcher.stamina)
                    }
                }

                if lines.isEmpty, state.performance.importantGamesCompleted == 0 {
                    // 0과 대시 12칸의 벽은 "내가 이해 못 하는 빈 표"다(QA P1-13).
                    BaseballCard(title: copyResolver.resolve(.statsEmptyTitle)) {
                        Text(copyResolver.resolve(.statsEmptyBody))
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                AdvancedStatsCard(
                    // 회차 카드·아카이브의 "탈삼진"은 직접 등판 기준이라, 기준을 안 적으면
                    // 같은 회차에 두 개의 탈삼진이 존재하게 된다(QA P1-5).
                    title: copyResolver.resolve(.highSchoolMetrics),
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
                    BaseballCard(title: copyResolver.resolve(.gameRecord)) {
                        Text(copyResolver.resolve(.gameRecordEmpty))
                            .font(.subheadline)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    GameLogSection(title: copyResolver.resolve(.highSchoolGames), lines: lines)
                }

                if !state.selectedAwakenings.isEmpty {
                    BaseballCard(title: copyResolver.resolve(.awakenings), tone: .milestone) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(state.selectedAwakenings, id: \.self) { awakening in
                                Label(
                                    HighSchoolPresentation.localizedAwakeningTitle(
                                        awakening,
                                        resolver: copyResolver
                                    ),
                                    systemImage: "sparkles"
                                )
                                    .font(.subheadline)
                                    .foregroundStyle(BaseballTheme.milestone)
                            }
                        }
                    }
                }

                if !archive.isEmpty { LifeArchiveSection(records: archive) }

                BaseballCard(title: copyResolver.resolve(.latestNews)) {
                    if state.news.isEmpty {
                        Text(copyResolver.resolve(.noNews)).font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(state.news.prefix(8).enumerated()), id: \.offset) { _, item in
                                Label(
                                    localizedNews(item),
                                    systemImage: "star.circle"
                                )
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

    private var localizedSchoolName: String {
        guard let school = state.school else { return GameCopyResolver.unavailableText }
        return HighSchoolPresentation.localizedSchoolName(
            school,
            rawRegion: state.identity.region,
            resolver: copyResolver
        )
    }

    private func localizedNews(_ raw: String) -> String {
        guard copyResolver.language == .english else { return raw }
        return HighSchoolConclusionPresentation.localizedChronicleText(raw, resolver: copyResolver)
    }
}

private struct RecordBoard: View {
    let state: ProCareerSnapshot
    let archive: [HighSchoolCareerStore.LifeRecord]
    let weekly: WeeklyProgramStore
    let highSchool: HighSchoolCareerStore
    @Environment(\.gameCopyResolver) private var copyResolver

    /// 아웃 카운트를 "이닝.아웃" 표기로 바꾼다. 야구 기록지와 같은 읽기 방식이다.
    /// 새 저장은 시즌 합계를 쓰고, 도입 전 저장은 등판 목록으로 복구한다.
    private var seasonHits: Int {
        max(state.currentStats.hits, (state.gameLines ?? []).reduce(0) { $0 + ($1.hits ?? 0) })
    }

    private var seasonHomeRuns: Int {
        max(state.currentStats.homeRuns, (state.gameLines ?? []).reduce(0) { $0 + ($1.homeRuns ?? 0) })
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
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                WeeklyProgramView(
                    store: weekly,
                    highSchool: highSchool
                )
                if let decisions = state.decisionHistory, !decisions.isEmpty {
                    ProDecisionHistoryCard(decisions: decisions)
                }
                HStack(spacing: 10) {
                    Metric(title: copyResolver.resolve(.totalsGames), value: "\(state.currentStats.games)")
                    Metric(
                        title: copyResolver.resolve(.totalsInnings),
                        value: GameFormatters.innings(outs: state.currentStats.inningsOuts, language: copyResolver.language)
                    )
                    Metric(
                        title: copyResolver.resolve(.totalsRA9),
                        value: GameFormatters.ra9(
                            runsAllowed: state.currentStats.runsAllowed,
                            outs: state.currentStats.inningsOuts,
                            language: copyResolver.language
                        )
                    )
                }
                HStack(spacing: 10) {
                    Metric(title: copyResolver.resolve(.totalsStrikeouts), value: "\(state.currentStats.strikeouts)", tone: .positive)
                    Metric(title: copyResolver.resolve(.walks), value: "\(state.currentStats.walks)", tone: .warning)
                    Metric(
                        title: copyResolver.resolve(.totalsRecord),
                        value: GameLineFormat.record(
                            wins: state.currentStats.wins,
                            losses: state.currentStats.losses,
                            saves: state.currentStats.saves
                        )
                    )
                }

                let identity = PitcherBuildRules.identity(for: state.pitcher)
                BaseballCard(title: copyResolver.resolve(
                    .currentAbilityBuild,
                    arguments: [.userText(ProCareerPresentation.buildLabel(identity, resolver: copyResolver))]
                )) {
                    VStack(alignment: .leading, spacing: 10) {
                        AbilityGaugeView(label: copyResolver.resolve(.stuff), value: state.pitcher.stuff)
                        AbilityGaugeView(label: copyResolver.resolve(.command), value: state.pitcher.command)
                        AbilityGaugeView(label: copyResolver.resolve(.movement), value: state.pitcher.movement)
                        AbilityGaugeView(label: copyResolver.resolve(.stamina), value: state.pitcher.stamina)
                        Text(ProCareerPresentation.buildStrength(identity, resolver: copyResolver))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(BaseballTheme.positive)
                    }
                }

                AdvancedStatsCard(
                    title: copyResolver.resolve(.seasonMetrics, arguments: [.integer(state.season)]),
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
                    GameLogSection(title: copyResolver.resolve(.seasonOutings), lines: lines)
                }

                if !state.careerStats.isEmpty {
                    BaseballCard(title: copyResolver.resolve(.careerSeasons)) {
                        VStack(spacing: 6) {
                            ForEach(state.careerStats, id: \.season) { season in
                                HStack {
                                    Text(copyResolver.resolve(.seasonLabel, arguments: [.integer(season.season)]))
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(copyResolver.resolve(
                                        .seasonLine,
                                        arguments: [
                                            .integer(season.games),
                                            .userText(GameFormatters.innings(
                                                outs: season.inningsOuts,
                                                language: copyResolver.language
                                            )),
                                            .userText(GameLineFormat.record(
                                                wins: season.wins,
                                                losses: season.losses,
                                                saves: season.saves
                                            )),
                                            .userText(GameLineFormat.runsPerNine(
                                                outs: season.inningsOuts,
                                                runs: season.runsAllowed
                                            )),
                                        ]
                                    ))
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(BaseballTheme.textSecondary)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }

                BaseballCard(title: copyResolver.resolve(.awards), tone: state.awards.isEmpty ? .standard : .milestone) {
                    if state.awards.isEmpty {
                        Text(copyResolver.resolve(.noAwards)).font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(state.awards, id: \.self) { award in
                                Label(
                                    ProCareerPresentation.award(award, resolver: copyResolver),
                                    systemImage: "trophy.fill"
                                )
                                .foregroundStyle(BaseballTheme.milestone)
                            }
                        }
                    }
                }

                BaseballCard(title: copyResolver.resolve(.milestones)) {
                    if state.milestones.isEmpty {
                        Text(copyResolver.resolve(.noMilestones)).font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(state.milestones.reversed().enumerated()), id: \.offset) { _, milestone in
                                Label(
                                    ProCareerPresentation.milestone(milestone, resolver: copyResolver),
                                    systemImage: "star.circle"
                                )
                                    .font(.subheadline)
                                    .foregroundStyle(BaseballTheme.textSecondary)
                            }
                        }
                    }
                }

                if !archive.isEmpty { LifeArchiveSection(records: archive) }

                if let score = state.hallOfFameScore {
                    BaseballCard(title: copyResolver.resolve(.hallOfFame), tone: .milestone) {
                        Text("\(score)").font(.title2.bold().monospacedDigit())
                    }
                }
            }
            .padding(BaseballMetrics.gutter)
        }
        .background(BaseballTheme.canvas)
    }
}

/// iPhone에서도 시즌 선택이 한 번 쓰고 사라지지 않도록 기록 탭에 남기는 압축 기록.
struct ProDecisionHistoryCard: View {
    let decisions: [ProDecisionRecord]
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        BaseballCard(title: copyResolver.resolve(.decisionHistory), tone: .milestone) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(decisions.suffix(7).reversed())) { decision in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(copyResolver.resolve(
                            .decisionDate,
                            arguments: [.integer(decision.season), .integer(decision.week)]
                        ))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textTertiary)
                        Text(ProCareerPresentation.decisionRecordTitle(decision, resolver: copyResolver))
                            .font(.subheadline.weight(.bold))
                        Text(ProCareerPresentation.effect(decision.effect, resolver: copyResolver))
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Self.accessibilityLabel(for: decision, resolver: copyResolver))
                }
            }
        }
        .accessibilityIdentifier("record.proDecisionHistory")
    }

    static func accessibilityLabel(
        for decision: ProDecisionRecord,
        resolver: GameCopyResolver = GameCopyResolver(language: .korean, policy: .releaseSafe)
    ) -> String {
        resolver.resolve(
            RecordUICopyKey.decisionAccessibility,
            arguments: [
                .integer(decision.season),
                .integer(decision.week),
                .userText(ProCareerPresentation.decisionRecordTitle(decision, resolver: resolver)),
                .userText(ProCareerPresentation.effect(decision.effect, resolver: resolver)),
            ]
        )
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
    @Environment(\.gameCopyResolver) private var copyResolver
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
                    Button(copyResolver.resolve(
                        showsAll ? .showRecent : .showAll,
                        arguments: [.integer(showsAll ? Self.collapsedCount : lines.count)]
                    )) {
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
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 직접 던진 경기는 이 화면에서 유일한 강조다. 자동으로 지나간 경기와 섞이면
            // "내가 만든 성적"이라는 감각이 사라진다.
            if line.played {
                Text(copyResolver.resolve(.directOuting)).eyebrowStyle(BaseballTheme.action)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(copyResolver.resolve(.week, arguments: [.integer(line.week)]))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textTertiary)
                Text(ProCareerPresentation.gameRole(line, resolver: copyResolver))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(BaseballTheme.textPrimary)
                Spacer()
                // localization-safe: numeric
                Text(GameLineFormat.score(line))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(BaseballTheme.textSecondary)
                if let decision = ProCareerPresentation.gameDecision(line.decision, resolver: copyResolver) {
                    // localization-safe: resolved-copy
                    Text(decision)
                        .font(.footnote.weight(.heavy))
                        .foregroundStyle(GameLineFormat.decisionTone(line.decision))
                }
            }
            Text(ProCareerPresentation.gameSummary(line, resolver: copyResolver))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(BaseballTheme.textSecondary)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ProCareerPresentation.gameAccessibility(line, resolver: copyResolver))
    }
}


/// 전국 유망주 랭킹 — 드래프트 전에 세상이 매기는 중간 점수.
///
/// "전국에서 내가 몇 번째인가"가 매 경기 갱신되면 드래프트 기대감이 매주의
/// 감정이 된다. 20위 밖이면 몇 계단 남았는지를 보여 준다 — 진입 자체가 사건이다.
private struct ProspectRankingCard: View {
    let state: HighSchoolCareerSnapshot
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        BaseballCard(title: copyResolver.resolve(AppCopyKey.prospectRankingTitle), tone: .milestone) {
            if let rank = ProspectRanking.playerRank(performance: state.performance) {
                VStack(alignment: .leading, spacing: 8) {
                    // 가상 지명 명단 — 실제 드래프트와 같은 공식(분산만 제외)이라
                    // 예측이 결과를 배신하지 않는다. 경계 구간은 경계라고 말한다.
                    let forecast = HighSchoolCareerEngine.draftForecast(state: state)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: copyResolver.resolve(
                            AppCopyKey.prospectRankingForecastLabel,
                            arguments: [
                                .userText(ProspectRankingPresentation.localizedForecastBand(
                                    forecast,
                                    resolver: copyResolver
                                )),
                            ]
                        ))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(forecast.score >= forecast.threshold ? BaseballTheme.action : BaseballTheme.textPrimary)
                        Text(verbatim: copyResolver.resolve(
                            AppCopyKey.prospectRankingForecastDetail,
                            arguments: ProspectRankingPresentation.forecastDetailArguments(
                                forecast,
                                resolver: copyResolver
                            )
                        ))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textTertiary)
                    }
                    .accessibilityIdentifier("record.draftForecast")
                    Rectangle().fill(BaseballTheme.border.opacity(0.3)).frame(height: 1)
                    if rank <= ProspectRanking.boardSize {
                        let board = ProspectRankingPresentation.board(state: state, resolver: copyResolver)
                        // 내 순위 주변만 보여 준다 — 위로 두 칸(목표), 아래로 한 칸(추격자).
                        let window = board.filter { abs($0.rank - rank) <= 2 || $0.rank <= 3 }
                        ForEach(window) { entry in
                            HStack(spacing: 8) {
                                Text("\(entry.rank)")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(entry.isPlayer ? BaseballTheme.action : BaseballTheme.textTertiary)
                                    .frame(width: 22, alignment: .trailing)
                                // 명단에서 내 줄만 얼굴이 있다 — 스카우트가 명단 옆에
                                // 붙여 둔 한 장의 사진처럼, 이 줄이 내 이야기라는 표식이다.
                                if entry.isPlayer {
                                    PortraitView(seed: state.identity.portraitSeed, role: .player, size: 24,
                                                 playerStage: state.chapter.schoolYear <= 1 ? .freshman : .ace)
                                }
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(verbatim: entry.identityLine)
                                        .font(.footnote.weight(entry.isPlayer ? .bold : .regular))
                                        .foregroundStyle(entry.isPlayer ? BaseballTheme.action : BaseballTheme.textPrimary)
                                    Text(verbatim: entry.tag)
                                        .font(.caption2)
                                        .foregroundStyle(BaseballTheme.textTertiary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    } else {
                        Text(verbatim: copyResolver.resolve(
                            AppCopyKey.prospectRankingOutsideTitle,
                            arguments: [.integer(rank)]
                        ))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BaseballTheme.textPrimary)
                        Text(verbatim: copyResolver.resolve(
                            AppCopyKey.prospectRankingOutsideDetail,
                            arguments: [.integer(rank - ProspectRanking.boardSize)]
                        ))
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityIdentifier("record.prospectRanking")
            } else {
                Text(verbatim: copyResolver.resolve(AppCopyKey.prospectRankingNoGames))
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
            }
        }
    }
}

/// 업적으로 가는 문. 도감·수집은 환생 게임의 리텐션 장치인데 설정 탭의 토글
/// 아래 묻혀 있었다(QA P2-10) — 기록을 보는 자리가 곧 수집을 확인하는 자리다.
struct AchievementsLinkCard: View {
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        NavigationLink {
            AchievementsView(store: .shared)
        } label: {
            BaseballCard(title: copyResolver.resolve(.achievements)) {
                HStack {
                    Text(copyResolver.resolve(.achievementsBody))
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("record.achievements")
    }
}
