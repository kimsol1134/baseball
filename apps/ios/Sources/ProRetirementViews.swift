import SwiftUI
import SimulationCore

struct RetirementDecisionView: View {
    let career: MobileCareerStore
    let state: ProCareerSnapshot

    @State private var confirming = false
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(
                art: .retirement,
                eyebrow: copyResolver.resolve(
                    .retirementEyebrow,
                    arguments: [.integer(state.age), .integer(state.careerStats.count)]
                ),
                title: copyResolver.resolve(.retirementDecisionTitle),
                accent: BaseballTheme.milestone
            )

            BaseballCard(title: copyResolver.resolve(.retirementHere), tone: .milestone) {
                Text(copyResolver.resolve(.retirementDecisionBody))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            CareerTotals(state: state)
            RetirementPreviewCard(state: state)

            PrimaryPill(title: copyResolver.resolve(.retirementAction), identifier: "pro.retire") { confirming = true }
        }
        .confirmationDialog(copyResolver.resolve(.retirementConfirmTitle), isPresented: $confirming, titleVisibility: .visible) {
            Button(copyResolver.resolve(.retirementConfirmAction), role: .destructive) { career.chooseOffseason(.retire) }
                .accessibilityIdentifier("pro.retire.confirm")
            Button(copyResolver.resolve(.retirementConfirmCancel)) {}
        } message: {
            Text(copyResolver.resolve(.retirementConfirmMessage, arguments: [.integer(state.careerStats.count)]))
        }
    }
}

struct RetirementPreviewCard: View {
    let state: ProCareerSnapshot
    @Environment(\.gameCopyResolver) private var copyResolver

    private var preview: ProRetirementPreview {
        ProCareerEngine.retirementPreview(for: state)
    }

    var body: some View {
        BaseballCard(title: copyResolver.resolve(.retirementPreviewTitle), tone: .raised) {
            VStack(alignment: .leading, spacing: 8) {
                Text(copyResolver.resolve(.retirementPreviewScore, arguments: [.integer(preview.finalScore)]))
                    .font(.headline.monospacedDigit())
                    .accessibilityIdentifier("pro.retirement.preview.score")
                Text(copyResolver.resolve(
                    .retirementPreviewRetiredNumber,
                    arguments: [.integer(preview.lastTeamSeasons), .integer(preview.lastTeamLegacy), .integer(preview.fanSupport)]
                ))
                .accessibilityIdentifier("pro.retirement.preview.retired-number")
                if preview.retiredNumberEligible {
                    Label(copyResolver.resolve(.retirementPreviewRetiredNumberEligible), systemImage: "number.circle.fill")
                        .foregroundStyle(BaseballTheme.milestone)
                        .accessibilityIdentifier("pro.retirement.preview.retired-number.eligible")
                }
                if !preview.clubHallTeamIDs.isEmpty {
                    Text(copyResolver.resolve(.retirementPreviewClubHall))
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("pro.retirement.preview.club-hall")
                    ForEach(preview.clubHallTeamIDs, id: \.self) { teamID in
                        Label(
                            ProCareerPresentation.teamName(teamID, resolver: copyResolver),
                            systemImage: "building.columns"
                        )
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .accessibilityIdentifier("pro.retirement.preview.club-hall.\(teamID)")
                    }
                }
            }
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pro.retirement.preview")
    }
}

/// 은퇴한 뒤. 커리어의 마지막 화면이라 회고와 통산 기록만 남는다.
struct RetiredView: View {
    let state: ProCareerSnapshot
    let retiresIntoSignatureLegacy: Bool
    let onStartNewPlayer: () -> Void

    @State private var confirming = false
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(
                art: .retirement,
                eyebrow: copyResolver.resolve(.retiredEyebrow),
                title: copyResolver.resolve(.retiredTitle, arguments: [.userText(state.identity.name)]),
                accent: BaseballTheme.milestone
            )

            // 커리어를 끝낸 그 얼굴. 세 결말(미지명·지명·은퇴) 중 여기만 얼굴이 없었다.
            HStack(spacing: 12) {
                PortraitView(seed: state.identity.portraitSeed, role: .player, size: 56, playerStage: .pro)
                VStack(alignment: .leading, spacing: 2) {
                    // localization-safe: user-input
                    Text(verbatim: state.identity.name).font(.headline)
                    Text(verbatim: copyResolver.resolve(
                        .retiredIdentityLine,
                        arguments: [
                            .userText(ProCareerPresentation.teamName(state.team, resolver: copyResolver)),
                            .userText(copyResolver.resolve(
                                .offseasonSeasons,
                                arguments: [.integer(state.careerStats.count)]
                            )),
                        ]
                    ))
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
                Spacer(minLength: 0)
            }

            if let score = state.hallOfFameScore {
                BaseballCard(title: copyResolver.resolve(.retiredHallOfFame), tone: .milestone) {
                    Text(verbatim: copyResolver.resolve(.retirementFinalScore, arguments: [.integer(score)]))
                        .font(BaseballType.heroNumeral)
                        .foregroundStyle(BaseballTheme.milestone)
                        .accessibilityIdentifier("pro.retirement.final.score")
                }
            }

            CareerTotals(state: state)

            if state.journeyState != nil {
                ProTeamCareerRecordsCard(state: state, accessibilityPrefix: "pro.retirement")
            }

            if let journey = state.journeyState, !journey.retirementHonors.isEmpty {
                RetirementHonorsCard(honors: journey.retirementHonors)
            }

            // 이 커리어가 다음 회차에 남기는 것. 프로의 시간이 환생 루프와 무관하면
            // 은퇴가 끝이 되지만, 야구혼으로 이어지면 은퇴가 다음 회차의 시작이 된다.
            BaseballCard(
                title: retiresIntoSignatureLegacy
                    ? copyResolver.resolve(.retiredLegacyTitle) : copyResolver.resolve(.retiredSoulTitle),
                tone: .milestone
            ) {
                Text(verbatim: copyResolver.resolve(
                    retiresIntoSignatureLegacy ? .retiredLegacyBody : .retiredSoulBody
                ))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: copyResolver.resolve(
                    .retiredSoulPoints,
                    arguments: [.integer(HighSchoolCareerStore.proSoulBonus(for: state))]
                ))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BaseballTheme.milestone)
            }

            if !state.awards.isEmpty {
                BaseballCard(title: copyResolver.resolve(.retiredAwards), tone: .milestone) {
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

            BaseballCard(title: copyResolver.resolve(.retiredRetrospective)) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(state.news.prefix(6).enumerated()), id: \.offset) { _, line in
                        Text(verbatim: ProCareerPresentation.news(line, state: state, resolver: copyResolver))
                            .font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            PrimaryPill(
                title: retiresIntoSignatureLegacy
                    ? copyResolver.resolve(.retiredLegacyAction) : copyResolver.resolve(.retiredSoulAction),
                identifier: "pro.newPlayer"
            ) { confirming = true }
            Text(verbatim: copyResolver.resolve(
                retiresIntoSignatureLegacy ? .retiredLegacyFootnote : .retiredSoulFootnote
            ))
                .font(.caption)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .confirmationDialog(
            copyResolver.resolve(
                retiresIntoSignatureLegacy ? .retiredLegacyConfirmTitle : .retiredSoulConfirmTitle
            ),
            isPresented: $confirming,
            titleVisibility: .visible
        ) {
            Button(
                copyResolver.resolve(
                    retiresIntoSignatureLegacy ? .retiredLegacyConfirmAction : .retiredSoulConfirmAction
                ),
                action: onStartNewPlayer
            )
                .accessibilityIdentifier("pro.newPlayer.confirm")
            Button(copyResolver.resolve(.retiredConfirmCancel)) {}
        } message: {
            Text(verbatim: copyResolver.resolve(
                retiresIntoSignatureLegacy ? .retiredLegacyConfirmMessage : .retiredSoulConfirmMessage,
                arguments: [.userText(state.identity.name)]
            ))
        }
    }
}

struct RetirementHonorsCard: View {
    let honors: [ProRetirementHonor]
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        BaseballCard(title: copyResolver.resolve(.retirementHonorsTitle), tone: .milestone) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(honors) { honor in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: ProCareerPresentation.honorTitle(honor.kind, resolver: copyResolver))
                            .font(.subheadline.weight(.semibold))
                        Text(verbatim: value(for: honor))
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("pro.retirement.honor.\(honor.id)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pro.retirement.honors")
    }

    private func value(for honor: ProRetirementHonor) -> String {
        switch honor.kind {
        case .hallOfFame:
            return copyResolver.resolve(.retirementHonorScore, arguments: [.integer(Int(clamping: honor.value ?? 0))])
        case .retiredNumber, .clubHall:
            return copyResolver.resolve(.retirementHonorTeam, arguments: [.userText(ProCareerPresentation.teamName(honor.teamID ?? "", resolver: copyResolver))])
        case .ambitionCompleted:
            let ambition = honor.referenceID.flatMap(ProCareerAmbition.init(rawValue:))
            return copyResolver.resolve(.retirementHonorValue, arguments: [.userText(ambition.map { ProCareerPresentation.goalTitle($0, resolver: copyResolver) } ?? GameCopyResolver.unavailableText)])
        case .careerEarnings:
            return copyResolver.resolve(.retirementHonorValue, arguments: [.userText(GameFormatters.krw(Int(clamping: honor.value ?? 0), language: copyResolver.language))])
        }
    }
}

struct CareerTotals: View {
    let state: ProCareerSnapshot
    @Environment(\.gameCopyResolver) private var copyResolver

    private var totals: (games: Int, outs: Int, strikeouts: Int, wins: Int, losses: Int, saves: Int, runs: Int) {
        state.careerStats.reduce((0, 0, 0, 0, 0, 0, 0)) {
            ($0.0 + $1.games, $0.1 + $1.inningsOuts, $0.2 + $1.strikeouts,
             $0.3 + $1.wins, $0.4 + $1.losses, $0.5 + $1.saves, $0.6 + $1.runsAllowed)
        }
    }

    var body: some View {
        BaseballCard(title: copyResolver.resolve(.totalsTitle)) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Metric(title: copyResolver.resolve(.totalsGames), value: "\(totals.games)")
                    Metric(
                        title: copyResolver.resolve(.totalsInnings),
                        value: GameFormatters.innings(outs: totals.outs, language: copyResolver.language)
                    )
                    Metric(title: copyResolver.resolve(.totalsStrikeouts), value: "\(totals.strikeouts)", tone: .positive)
                }
                HStack(spacing: 10) {
                    Metric(title: copyResolver.resolve(.totalsRecord), value: GameLineFormat.record(wins: totals.wins, losses: totals.losses, saves: totals.saves))
                    Metric(
                        title: copyResolver.resolve(.totalsRA9),
                        value: GameFormatters.ra9(runsAllowed: totals.runs, outs: totals.outs, language: copyResolver.language)
                    )
                    Metric(title: copyResolver.resolve(.totalsSeasons), value: "\(state.careerStats.count)")
                }
            }
        }
    }
}
