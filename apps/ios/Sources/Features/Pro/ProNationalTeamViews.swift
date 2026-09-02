import SwiftUI
import SimulationCore
import BaseballIOSDomain

struct ProNationalTeamCallView: View {
    let career: MobileCareerStore
    let state: ProCareerSnapshot
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(
                art: .stadiumNight,
                eyebrow: copyResolver.resolve(.nationalTeamCallEyebrow),
                title: copyResolver.resolve(.nationalTeamCallTitle),
                accent: BaseballTheme.milestone
            )

            BaseballCard(title: copyResolver.resolve(.nationalTeamCallConditionsTitle), tone: .milestone) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(copyResolver.resolve(.nationalTeamCallBody))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(copyResolver.resolve(.nationalTeamCallCost))
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(
                        verbatim: ProNationalTeamCopy.callSummary(
                            marketScore: CareerDisplayRules.nationalTeamMarketScore(state),
                            fanSupport: CareerDisplayRules.nationalTeamFanSupport(state),
                            resolver: copyResolver
                        )
                    )
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textSecondary)
                }
            }

            PrimaryPill(
                title: copyResolver.resolve(.nationalTeamCallAccept),
                identifier: "pro.nationalTeam.call.accept"
            ) {
                career.respondToNationalTeamCall(accepted: true)
            }
            Button {
                career.respondToNationalTeamCall(accepted: false)
            } label: {
                Text(copyResolver.resolve(.nationalTeamCallDecline))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("pro.nationalTeam.call.decline")
        }
    }
}

struct ProNationalTournamentView: View {
    let career: MobileCareerStore
    let state: ProCareerSnapshot
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(
                art: .proStadiumTunnel,
                eyebrow: copyResolver.resolve(.nationalTournamentEyebrow),
                title: copyResolver.resolve(.gameContent(ProNationalTeamRules.tournamentNameKey)),
                accent: BaseballTheme.milestone
            )

            if let tournament = state.nationalTournament {
                BaseballCard(title: copyResolver.resolve(.nationalTournamentGroupTitle)) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(tournament.groupGames) { line in
                            HStack {
                                Text(copyResolver.resolve(.gameContent(CareerDisplayRules.nationalOpponentNameKey(line.opponentID))))
                                Spacer()
                                Text("\(line.teamRuns)-\(line.opponentRuns)")
                                    .font(.body.monospacedDigit().weight(.semibold))
                                Text(copyResolver.resolve(line.won ? .nationalTournamentWin : .nationalTournamentLoss))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(line.won ? BaseballTheme.positive : BaseballTheme.warning)
                            }
                            .accessibilityElement(children: .combine)
                        }
                        Text(
                            verbatim: ProNationalTeamCopy.groupRecord(
                                wins: tournament.groupWins,
                                games: tournament.groupGames.count,
                                resolver: copyResolver
                            )
                        )
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                    }
                }

                if tournament.stage == .awaitingFinal {
                    Text(copyResolver.resolve(.nationalTournamentFinalReady))
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                    PrimaryPill(
                        title: copyResolver.resolve(.nationalTournamentStartFinal),
                        identifier: "pro.nationalTeam.final.start"
                    ) {
                        career.startNationalFinal()
                    }
                } else if tournament.result != nil {
                    ProNationalTeamResultCard(state: state, tournament: tournament) {
                        career.acknowledgeNationalTeamResult()
                    }
                }
            }
        }
    }
}

struct ProNationalTeamResultCard: View {
    let state: ProCareerSnapshot
    let tournament: ProNationalTournamentState
    var onContinue: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        BaseballCard(title: copyResolver.resolve(.nationalTeamResultTitle), tone: .milestone) {
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: ProNationalTeamCopy.resultTitle(tournament.result, resolver: copyResolver))
                    .font(.headline)
                if tournament.exempted {
                    Text(copyResolver.resolve(.nationalTeamResultExempted))
                        .font(.subheadline)
                        .foregroundStyle(BaseballTheme.positive)
                }
                Text(
                    verbatim: ProNationalTeamCopy.resultFan(
                        delta: tournament.fanDelta,
                        resolver: copyResolver
                    )
                )
                .font(.footnote)
                .foregroundStyle(BaseballTheme.textSecondary)
            }
        }
        .accessibilityIdentifier("pro.nationalTeam.result")

        PrimaryPill(
            title: copyResolver.resolve(.nationalTeamResultContinue),
            identifier: "pro.nationalTeam.result.continue",
            action: onContinue
        )
    }
}
