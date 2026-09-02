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
                VStack(alignment: .leading, spacing: 8) {
                    // 소집·병역 면제 같은 용어는 사전 링크로 잇는다.
                    GlossaryText(
                        text: copyResolver.resolve(.nationalTeamCallBody),
                        font: BaseballType.prose,
                        color: BaseballTheme.textPrimary
                    )
                    Text(
                        verbatim: ProNationalTeamCopy.callSummary(
                            marketScore: CareerDisplayRules.nationalTeamMarketScore(state),
                            fanSupport: CareerDisplayRules.nationalTeamFanSupport(state),
                            resolver: copyResolver
                        )
                    )
                    .detailStyle()
                    .monospacedDigit()
                    // 대가는 비용이라 접지 않는다. 아이콘만 경고색.
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.circle")
                            .font(BaseballType.detail)
                            .foregroundStyle(BaseballTheme.warning)
                        GlossaryText(
                            text: copyResolver.resolve(.nationalTeamCallCost),
                            font: BaseballType.detail
                        )
                    }
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
                // 조별 경기 표. 눈썹 카드 대신 섹션 제목 하나.
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: copyResolver.resolve(.nationalTournamentGroupTitle))
                        .font(.headline)
                    ForEach(tournament.groupGames) { line in
                        HStack {
                            Text(copyResolver.resolve(.gameContent(CareerDisplayRules.nationalOpponentNameKey(line.opponentID))))
                                .font(BaseballType.detail)
                            Spacer()
                            // localization-safe: numeric
                            Text(verbatim: "\(line.teamRuns)-\(line.opponentRuns)")
                                .font(.body.monospacedDigit().weight(.semibold))
                            Text(copyResolver.resolve(line.won ? .nationalTournamentWin : .nationalTournamentLoss))
                                .font(BaseballType.annotation.weight(.bold))
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
                    .detailStyle()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if tournament.stage == .awaitingFinal {
                    Text(copyResolver.resolve(.nationalTournamentFinalReady))
                        .detailStyle()
                    PrimaryPill(
                        title: copyResolver.resolve(.nationalTournamentStartFinal),
                        identifier: "pro.nationalTeam.final.start"
                    ) {
                        career.startNationalFinal()
                    }
                } else if tournament.result != nil {
                    ProNationalTeamResultCard(
                        state: state,
                        tournament: tournament,
                        challengeStamp: career.challengeStamp()
                    ) {
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
    var challengeStamp: CareerDisplayRules.ChallengeStamp? = nil
    var onContinue: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        BaseballCard(title: copyResolver.resolve(.nationalTeamResultTitle), tone: .milestone) {
            VStack(alignment: .leading, spacing: 8) {
                // 결과 한 줄 → 세부.
                Text(verbatim: ProNationalTeamCopy.resultTitle(tournament.result, resolver: copyResolver))
                    .proseLeadStyle()
                if tournament.exempted {
                    Label(copyResolver.resolve(.nationalTeamResultExempted), systemImage: "checkmark.seal.fill")
                        .detailStyle(BaseballTheme.positive)
                }
                Text(
                    verbatim: ProNationalTeamCopy.resultFan(
                        delta: tournament.fanDelta,
                        resolver: copyResolver
                    )
                )
                .detailStyle()
            }
        }
        .accessibilityIdentifier("pro.nationalTeam.result")

        CareerShareButton(
            model: CareerSharePresentation.national(
                state: state,
                tournament: tournament,
                stamp: challengeStamp,
                resolver: copyResolver
            )
        )

        PrimaryPill(
            title: copyResolver.resolve(.nationalTeamResultContinue),
            identifier: "pro.nationalTeam.result.continue",
            action: onContinue
        )
    }
}
