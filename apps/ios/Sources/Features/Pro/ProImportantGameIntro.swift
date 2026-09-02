import SwiftUI
import SimulationCore
import BaseballIOSDomain

struct ImportantGameIntro: View {
    let state: ProCareerSnapshot
    let onStart: () -> Void
    let onAvailabilityDecision: (ProPostseasonAvailabilityChoice) -> Void
    @State private var pendingAvailabilityChoice: ProPostseasonAvailabilityChoice?
    @Environment(\.gameCopyResolver) private var copyResolver

    init(
        state: ProCareerSnapshot,
        onStart: @escaping () -> Void,
        onAvailabilityDecision: @escaping (ProPostseasonAvailabilityChoice) -> Void = { _ in }
    ) {
        self.state = state
        self.onStart = onStart
        self.onAvailabilityDecision = onAvailabilityDecision
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(
                art: state.level == .major ? .proStadiumTunnel : .stadiumNight,
                eyebrow: ProImportantGameCopy.eyebrow(
                    season: state.season,
                    week: state.week,
                    resolver: copyResolver
                ),
                title: introTitle,
                accent: BaseballTheme.milestone
            )

            if let postseason = postseasonSeriesState {
                postseasonSeriesCard(postseason)
                if !(postseason.gameHistory ?? []).isEmpty {
                    ProPostseasonHistoryCard(postseason: postseason, limit: 4)
                }
            }

            if let rival = state.currentRival {
                let rivalCopy = ProCareerPresentation.rival(rival, resolver: copyResolver)
                BaseballCard(title: copyResolver.resolve(.importantOpponent), tone: .milestone) {
                    HStack(alignment: .top, spacing: 10) {
                        // 고교 라이벌 카드와 같은 문법 — 상대에게 얼굴이 있어야 승부다.
                        PortraitView(seed: rival.name, role: .rival, size: 46)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(rivalCopy.name) · \(rivalCopy.teamName)").font(.headline)
                            // localization-safe: resolved-copy
                            Text(rivalCopy.archetype).font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                            // localization-safe: resolved-copy
                            Text(rivalCopy.profile).detailStyle()
                            // localization-safe: resolved-copy
                            Text(rivalCopy.record).font(BaseballType.annotation.monospacedDigit()).foregroundStyle(BaseballTheme.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            BaseballCard(title: copyResolver.resolve(.importantMyStatus)) {
                HStack(spacing: 10) {
                    Metric(title: copyResolver.resolve(.importantFatigue), value: "\(state.fatigue)", tone: state.fatigue >= 70 ? .warning : .standard)
                    Metric(title: copyResolver.resolve(.importantManagerTrust), value: "\(state.managerTrust)")
                    Metric(title: copyResolver.resolve(.importantCatcherTrust), value: "\(state.catcherTrust)")
                }
            }

            if let postseason = postseasonSeriesState,
               ProPostseasonRules.requiresAvailabilityDecision(postseason, role: state.role) {
                availabilityChoiceCard(postseason)
            } else {
                if postseasonSeriesState?.series?.availabilityDecision == .pitchAgain {
                    Label(
                        copyResolver.resolve(.postseasonAvailabilityCommitted),
                        systemImage: "flame.fill"
                    )
                    .font(BaseballType.detail.weight(.semibold))
                    .foregroundStyle(BaseballTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(copyResolver.resolve(
                        state.seasonTrigger == .nationalFinal
                            ? .importantNationalFinalBody
                            : .importantBody
                    ))
                        .detailStyle()
                }

                PrimaryPill(
                    title: copyResolver.resolve(.importantAction),
                    identifier: "pro.game.start",
                    action: onStart
                )
            }
        }
        .alert(
            pendingAvailabilityChoice.map(availabilityTitle)
                ?? copyResolver.resolve(.decisionConfirmTitle),
            isPresented: Binding(
                get: { pendingAvailabilityChoice != nil },
                set: { if !$0 { pendingAvailabilityChoice = nil } }
            )
        ) {
            Button(copyResolver.resolve(.decisionConfirmAction)) {
                guard let pendingAvailabilityChoice else { return }
                onAvailabilityDecision(pendingAvailabilityChoice)
                self.pendingAvailabilityChoice = nil
            }
            .accessibilityIdentifier("pro.postseason.availability.confirm")
            Button(copyResolver.resolve(.decisionConfirmCancel), role: .cancel) {
                pendingAvailabilityChoice = nil
            }
        } message: {
            if let pendingAvailabilityChoice {
                Text(verbatim: availabilityDetail(pendingAvailabilityChoice))
            }
        }
    }

    private var introTitle: String {
        if state.seasonTrigger == .nationalFinal {
            return copyResolver.resolve(.importantNationalFinalTitle)
        }
        return state.level == .major
            ? copyResolver.resolve(.importantMajorTitle)
            : state.managerTrust < 55
                ? copyResolver.resolve(.importantMinorOpportunityTitle)
                : copyResolver.resolve(.importantMinorRoleTitle)
    }

    private var postseasonSeriesState: ProPostseasonState? {
        if state.seasonTrigger == .nationalFinal { return nil }
        guard CareerDisplayRules.usesFinalSeriesRules(state),
              let postseason = state.postseason,
              postseason.currentRound != nil else { return nil }
        return postseason
    }

    @ViewBuilder
    private func postseasonSeriesCard(_ postseason: ProPostseasonState) -> some View {
        let round = postseason.currentRound ?? .final
        let series = postseason.series
            ?? ProPostseasonRules.openingSeries(
                round: round,
                seed: postseason.seed,
                opponentTeamID: nil,
                previousDirectAppearances: postseason.gamesPlayed
            )
        let strengthEdge = ProPostseasonRules.teamStrengthEdgePermille(state)
        BaseballCard(title: postseasonSeriesTitle(round), tone: .milestone) {
            HStack(spacing: 10) {
                Metric(
                    title: copyResolver.resolve(.postseasonSeriesScore),
                    value: "\(series.playerWins)-\(series.opponentWins)",
                    tone: series.playerWins >= series.opponentWins ? .positive : .warning
                )
                Metric(
                    title: copyResolver.resolve(.postseasonSeriesNextGame),
                    value: "\(series.nextGameNumber)"
                )
                Metric(
                    title: copyResolver.resolve(.postseasonSeriesAppearances),
                    value: "\(series.totalDirectAppearances)/\(ProPostseasonRules.maximumDirectAppearances)"
                )
            }
            Label(
                copyResolver.resolve(
                    strengthEdge > 25
                        ? .postseasonSeriesStrengthAdvantage
                        : strengthEdge < -25
                            ? .postseasonSeriesStrengthDisadvantage
                            : .postseasonSeriesStrengthEven
                ),
                systemImage: strengthEdge > 25
                    ? "chart.line.uptrend.xyaxis"
                    : strengthEdge < -25
                        ? "chart.line.downtrend.xyaxis"
                        : "equal.circle"
            )
            .font(.caption)
            .foregroundStyle(BaseballTheme.textSecondary)
            if let lastGame = series.gameLines?.last {
                Label(
                    ProImportantGameCopy.seriesLastGame(
                        lastGame,
                        resolver: copyResolver
                    ),
                    systemImage: lastGame.won ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(lastGame.won ? BaseballTheme.positive : BaseballTheme.warning)
                if lastGame.directlyPlayed,
                   let pitches = lastGame.playerPitches,
                   let runs = lastGame.playerRunsAllowed {
                    Text(verbatim: ProImportantGameCopy.seriesLastAppearance(
                        pitches: pitches,
                        runs: runs,
                        resolver: copyResolver
                    ))
                    .font(.caption)
                    .foregroundStyle(BaseballTheme.textSecondary)
                }
            } else if let pitches = series.lastAppearancePitches {
                Label(
                    ProImportantGameCopy.seriesLastPitches(pitches, resolver: copyResolver),
                    systemImage: "baseball.fill"
                )
                .font(.caption)
                .foregroundStyle(BaseballTheme.textSecondary)
            }
        }
        .accessibilityIdentifier("pro.postseason.series")
    }

    @ViewBuilder
    private func availabilityChoiceCard(_ postseason: ProPostseasonState) -> some View {
        let pitches = postseason.series?.lastAppearancePitches ?? 0
        let penalty = ProPostseasonRules.consecutiveAppearanceFatiguePenalty(
            role: state.role,
            lastAppearancePitches: pitches
        )
        let projectedFatigue = min(100, state.fatigue + penalty)
        let armRisk = ProPostseasonRules.armRisk(projectedFatigue: projectedFatigue)
        BaseballCard(title: copyResolver.resolve(.postseasonAvailabilityTitle), tone: .raised) {
            Text(verbatim: ProImportantGameCopy.availabilityBody(
                key: availabilityBodyKey(postseason),
                pitches: pitches,
                resolver: copyResolver
            ))
            .detailStyle()

            availabilityButton(
                choice: .pitchAgain,
                title: copyResolver.resolve(.postseasonAvailabilityPitchTitle),
                detail: ProImportantGameCopy.availabilityPitchDetail(
                    penalty: penalty,
                    resolver: copyResolver
                ),
                symbol: "flame.fill"
            )
            Label(
                ProImportantGameCopy.availabilityRisk(
                    key: armRiskKey(armRisk),
                    projectedFatigue: projectedFatigue,
                    resolver: copyResolver
                ),
                systemImage: armRisk == .severe ? "exclamationmark.triangle.fill" : "heart.text.square"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(armRisk == .manageable ? BaseballTheme.textSecondary : BaseballTheme.warning)
            availabilityButton(
                choice: .restForDecider,
                title: copyResolver.resolve(.postseasonAvailabilityRestTitle),
                detail: copyResolver.resolve(availabilityRestDetailKey(postseason)),
                symbol: "bed.double.fill"
            )
        }
    }

    private func availabilityButton(
        choice: ProPostseasonAvailabilityChoice,
        title: String,
        detail: String,
        symbol: String
    ) -> some View {
        Button { pendingAvailabilityChoice = choice } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(choice == .pitchAgain ? BaseballTheme.warning : BaseballTheme.information)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: title).font(.headline)
                    Text(verbatim: detail)
                        .detailStyle()
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .foregroundStyle(BaseballTheme.textSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BaseballTheme.surface, in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                    .stroke(BaseballTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pro.postseason.availability.\(choice.rawValue)")
    }

    private func availabilityTitle(_ choice: ProPostseasonAvailabilityChoice) -> String {
        copyResolver.resolve(
            choice == .pitchAgain
                ? .postseasonAvailabilityPitchTitle
                : .postseasonAvailabilityRestTitle
        )
    }

    private func availabilityDetail(_ choice: ProPostseasonAvailabilityChoice) -> String {
        if choice == .restForDecider {
            guard let postseason = postseasonSeriesState else {
                return copyResolver.resolve(.postseasonAvailabilityRestDetail)
            }
            return copyResolver.resolve(availabilityRestDetailKey(postseason))
        }
        let pitches = postseasonSeriesState?.series?.lastAppearancePitches ?? 0
        let penalty = ProPostseasonRules.consecutiveAppearanceFatiguePenalty(
            role: state.role,
            lastAppearancePitches: pitches
        )
        return ProImportantGameCopy.availabilityPitchDetail(
            penalty: penalty,
            resolver: copyResolver
        )
    }

    private func postseasonSeriesTitle(_ round: ProAutumnRound) -> String {
        let key: ProUICopyKey = switch round {
        case .wildCard: .postseasonSeriesWildCardTitle
        case .semifinal: .postseasonSeriesSemifinalTitle
        case .playoff: .postseasonSeriesPlayoffTitle
        case .final: .postseasonSeriesTitle
        }
        return copyResolver.resolve(key)
    }

    private func availabilityBodyKey(_ postseason: ProPostseasonState) -> ProUICopyKey {
        switch ProPostseasonRules.stakes(postseason) {
        case .standard: .postseasonAvailabilityBody
        case .clinch: .postseasonAvailabilityBodyClinch
        case .elimination: .postseasonAvailabilityBodyElimination
        case .winnerTakeAll: .postseasonAvailabilityBodyWinnerTakeAll
        }
    }

    private func availabilityRestDetailKey(_ postseason: ProPostseasonState) -> ProUICopyKey {
        switch ProPostseasonRules.stakes(postseason) {
        case .elimination, .winnerTakeAll: .postseasonAvailabilityRestDetailElimination
        case .clinch: .postseasonAvailabilityRestDetailClinch
        case .standard: .postseasonAvailabilityRestDetail
        }
    }

    private func armRiskKey(_ risk: ProPostseasonArmRisk) -> ProUICopyKey {
        switch risk {
        case .manageable: .postseasonAvailabilityRiskManageable
        case .elevated: .postseasonAvailabilityRiskElevated
        case .severe: .postseasonAvailabilityRiskSevere
        }
    }
}

struct ProPostseasonHistoryCard: View {
    let postseason: ProPostseasonState
    var limit: Int? = nil
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        let history = Array((postseason.gameHistory ?? []).suffix(limit ?? Int.max))
        BaseballCard(title: copyResolver.resolve(.postseasonHistoryTitle), tone: .raised) {
            ForEach(history) { line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "\(roundName(line.round)) \(line.gameNumber)")
                        .font(.caption.weight(.semibold))
                    Spacer(minLength: 8)
                    Text(verbatim: "\(line.teamRuns)-\(line.opponentRuns)")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(line.won ? BaseballTheme.positive : BaseballTheme.warning)
                    Text(verbatim: copyResolver.resolve(
                        line.directlyPlayed
                            ? .postseasonHistoryDirect
                            : .postseasonHistoryAutomatic
                    ))
                    .font(.caption2)
                    .foregroundStyle(BaseballTheme.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .accessibilityIdentifier("pro.postseason.history")
    }

    private func roundName(_ round: ProAutumnRound?) -> String {
        let key: ProUICopyKey = switch round {
        case .wildCard: .postseasonRoundWildCard
        case .semifinal: .postseasonRoundSemifinal
        case .playoff: .postseasonRoundPlayoff
        case .final: .postseasonRoundFinal
        case nil: .postseasonRoundUnknown
        }
        return copyResolver.resolve(key)
    }
}

struct ProPostseasonFinaleView: View {
    let state: ProCareerSnapshot
    let onReview: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(
                art: .proStadiumTunnel,
                eyebrow: copyResolver.resolve(.postseasonFinaleEyebrow),
                title: copyResolver.resolve(finaleTitleKey),
                accent: state.postseason?.result == .champion
                    ? BaseballTheme.milestone
                    : BaseballTheme.warning
            )
            Text(verbatim: copyResolver.resolve(finaleBodyKey))
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let postseason = state.postseason,
               !(postseason.gameHistory ?? []).isEmpty {
                ProPostseasonHistoryCard(postseason: postseason)
            }
            PrimaryPill(
                title: copyResolver.resolve(.seasonReviewAction),
                identifier: "pro.seasonReview.confirm",
                action: onReview
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pro.postseason.finale")
    }

    private var finaleTitleKey: ProUICopyKey {
        switch state.postseason?.result {
        case .champion: .postseasonFinaleChampionTitle
        case .runnerUp: .postseasonFinaleRunnerUpTitle
        default: .postseasonFinaleEliminatedTitle
        }
    }

    private var finaleBodyKey: ProUICopyKey {
        switch state.postseason?.result {
        case .champion: .postseasonFinaleChampionBody
        case .runnerUp: .postseasonFinaleRunnerUpBody
        default: .postseasonFinaleEliminatedBody
        }
    }
}

/// 오프시즌 네 갈래.
///
/// 예전에는 "현재 구단에 남기" 하나였다. 코어는 잔류·군 복무·FA·은퇴를 전부 받는데
/// 화면이 하나만 냈으니, 한국 야구 커리어의 큰 갈림길 두 개(군 복무·FA)가 게임에
/// 존재하지 않았던 셈이다.
///
/// 자격은 화면이 먼저 계산해 잠근다. 못 누를 버튼을 내고 코어의 오류 문자열로 규칙을
