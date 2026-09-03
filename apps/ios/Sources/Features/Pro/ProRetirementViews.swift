import SwiftUI
import SimulationCore
import BaseballIOSDomain

struct RetirementDecisionView: View {
    let career: MobileCareerStore
    let state: ProCareerSnapshot

    @State private var confirming = false
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(
                art: .retirement,
                eyebrow: ProRetirementCopy.eyebrow(
                    age: state.age,
                    seasons: state.careerStats.count,
                    resolver: copyResolver
                ),
                title: copyResolver.resolve(.retirementDecisionTitle),
                accent: BaseballTheme.milestone
            )

            // 마지막 한 문단은 눈썹 없이 본문으로 선다.
            Text(copyResolver.resolve(.retirementDecisionBody))
                .proseStyle()

            CareerTotals(state: state)
            RetirementPreviewCard(state: state)

            PrimaryPill(title: copyResolver.resolve(.retirementAction), identifier: "pro.retire") { confirming = true }
        }
        .alert(copyResolver.resolve(.retirementConfirmTitle), isPresented: $confirming) {
            Button(copyResolver.resolve(.retirementConfirmAction), role: .destructive) { career.chooseOffseason(.retire) }
                .accessibilityIdentifier("pro.retire.confirm")
            Button(copyResolver.resolve(.retirementConfirmCancel)) {}
        } message: {
            Text(verbatim: ProRetirementCopy.confirmMessage(seasons: state.careerStats.count, resolver: copyResolver))
        }
    }
}

struct RetirementPreviewCard: View {
    let state: ProCareerSnapshot
    @Environment(\.gameCopyResolver) private var copyResolver

    private var preview: ProRetirementPreview {
        MobileCareerStore.retirementPreview(for: state)
    }

    var body: some View {
        BaseballCard(title: copyResolver.resolve(.retirementPreviewTitle), tone: .raised) {
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: ProRetirementCopy.previewScore(preview.finalScore, resolver: copyResolver))
                    .proseLeadStyle()
                    .monospacedDigit()
                    .accessibilityIdentifier("pro.retirement.preview.score")
                Text(verbatim: ProRetirementCopy.previewRetiredNumber(
                    lastTeamSeasons: preview.lastTeamSeasons,
                    lastTeamLegacy: preview.lastTeamLegacy,
                    fanSupport: preview.fanSupport,
                    resolver: copyResolver
                ))
                .detailStyle()
                .monospacedDigit()
                .accessibilityIdentifier("pro.retirement.preview.retired-number")
                if preview.retiredNumberEligible {
                    Label(copyResolver.resolve(.retirementPreviewRetiredNumberEligible), systemImage: "number.circle.fill")
                        .detailStyle(BaseballTheme.milestone)
                        .accessibilityIdentifier("pro.retirement.preview.retired-number.eligible")
                } else {
                    Text(copyResolver.resolve(.retirementPreviewRetiredNumberHint))
                        .detailStyle()
                        .accessibilityIdentifier("pro.retirement.preview.retired-number.hint")
                }
                if !preview.clubHallTeamIDs.isEmpty {
                    Text(copyResolver.resolve(.retirementPreviewClubHall))
                        .proseLeadStyle()
                        .accessibilityIdentifier("pro.retirement.preview.club-hall")
                    ForEach(preview.clubHallTeamIDs, id: \.self) { teamID in
                        Label(
                            ProCareerPresentation.teamName(teamID, resolver: copyResolver),
                            systemImage: "building.columns"
                        )
                        .detailStyle()
                        .accessibilityIdentifier("pro.retirement.preview.club-hall.\(teamID)")
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pro.retirement.preview")
    }
}

/// 은퇴한 뒤. 커리어의 마지막 화면이라 회고와 통산 기록만 남는다.
struct RetiredView: View {
    let state: ProCareerSnapshot
    let retiresIntoSignatureLegacy: Bool
    var challengeStamp: CareerDisplayRules.ChallengeStamp? = nil
    let onStartNewPlayer: () -> Void

    @State private var confirming = false
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(
                art: .retirement,
                eyebrow: copyResolver.resolve(.retiredEyebrow),
                title: ProRetirementCopy.retiredTitle(name: state.identity.name, resolver: copyResolver),
                accent: BaseballTheme.milestone
            )

            // 커리어를 끝낸 그 얼굴. 세 결말(미지명·지명·은퇴) 중 여기만 얼굴이 없었다.
            HStack(spacing: 12) {
                PortraitView(seed: state.identity.portraitSeed, role: .player, size: 56, playerStage: .pro)
                VStack(alignment: .leading, spacing: 2) {
                    // localization-safe: user-input
                    Text(verbatim: state.identity.name).font(.headline)
                    Text(verbatim: ProRetirementCopy.identityLine(
                        teamName: ProCareerPresentation.teamName(state.team, resolver: copyResolver),
                        seasons: state.careerStats.count,
                        resolver: copyResolver
                    ))
                        .detailStyle()
                }
                Spacer(minLength: 0)
            }

            if let score = state.hallOfFameScore {
                // 큰 숫자 하나면 타일이 맞다 — 눈썹 카드를 두르지 않는다.
                StatTile(
                    label: copyResolver.resolve(.retiredHallOfFame),
                    value: "\(score)",
                    tone: BaseballTheme.milestone
                )
                .accessibilityLabel(ProRetirementCopy.finalScore(score, resolver: copyResolver))
                .accessibilityIdentifier("pro.retirement.final.score")
            }

            CareerTotals(state: state)

            CareerShareButton(
                model: CareerSharePresentation.retirement(
                    state: state,
                    stamp: challengeStamp,
                    resolver: copyResolver
                )
            )

            if state.journeyState != nil {
                ProTeamCareerRecordsCard(state: state, accessibilityPrefix: "pro.retirement")
            }

            if let journey = state.journeyState, !journey.retirementHonors.isEmpty {
                RetirementHonorsCard(honors: journey.retirementHonors)
            }

            // 이 커리어가 다음 회차에 남기는 것. 프로의 시간이 환생 루프와 무관하면
            // 은퇴가 끝이 되지만, 야구혼으로 이어지면 은퇴가 다음 회차의 시작이 된다.
            // 결과 한 줄(제목 + 계승 포인트) → 긴 설명은 접기. 눈썹 카드는 두르지 않는다.
            ProgressiveDisclosure(
                contentID: retiresIntoSignatureLegacy ? "pro.retired.legacy.v1" : "pro.retired.soul.v1",
                title: retiresIntoSignatureLegacy
                    ? copyResolver.resolve(.retiredLegacyTitle) : copyResolver.resolve(.retiredSoulTitle),
                summary: ProRetirementCopy.soulPoints(
                    HighSchoolCareerStore.proSoulBonus(for: state),
                    resolver: copyResolver
                )
            ) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: ProRetirementCopy.soulPoints(
                        HighSchoolCareerStore.proSoulBonus(for: state),
                        resolver: copyResolver
                    ))
                    .proseLeadStyle(BaseballTheme.milestone)
                    Text(verbatim: copyResolver.resolve(
                        retiresIntoSignatureLegacy ? .retiredLegacyBody : .retiredSoulBody
                    ))
                    .proseStyle(BaseballTheme.textSecondary)
                }
            }

            if !state.awards.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: copyResolver.resolve(.retiredAwards))
                        .font(.headline)
                    ForEach(state.awards, id: \.self) { award in
                        Label(
                            ProCareerPresentation.award(award, resolver: copyResolver),
                            systemImage: "trophy.fill"
                        )
                        .detailStyle(BaseballTheme.milestone)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: copyResolver.resolve(.retiredRetrospective))
                    .font(.headline)
                ForEach(Array(state.news.prefix(6).enumerated()), id: \.offset) { _, line in
                    Text(verbatim: ProCareerPresentation.news(line, state: state, resolver: copyResolver))
                        .detailStyle()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PrimaryPill(
                title: retiresIntoSignatureLegacy
                    ? copyResolver.resolve(.retiredLegacyAction) : copyResolver.resolve(.retiredSoulAction),
                identifier: "pro.newPlayer"
            ) { confirming = true }
            Text(verbatim: copyResolver.resolve(
                retiresIntoSignatureLegacy ? .retiredLegacyFootnote : .retiredSoulFootnote
            ))
                .detailStyle(BaseballTheme.textTertiary)
        }
        .alert(
            copyResolver.resolve(
                retiresIntoSignatureLegacy ? .retiredLegacyConfirmTitle : .retiredSoulConfirmTitle
            ),
            isPresented: $confirming
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
            Text(verbatim: ProRetirementCopy.confirmNewPlayer(
                name: state.identity.name,
                isLegacy: retiresIntoSignatureLegacy,
                resolver: copyResolver
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
                            .proseLeadStyle()
                        Text(verbatim: value(for: honor))
                            .detailStyle()
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
            return ProRetirementCopy.honorScore(Int(clamping: honor.value ?? 0), resolver: copyResolver)
        case .retiredNumber, .clubHall:
            return ProRetirementCopy.honorTeam(
                ProCareerPresentation.teamName(honor.teamID ?? "", resolver: copyResolver),
                resolver: copyResolver
            )
        case .ambitionCompleted:
            let ambition = honor.referenceID.flatMap(ProCareerAmbition.init(rawValue:))
            return ProRetirementCopy.honorValue(
                ambition.map { ProCareerPresentation.goalTitle($0, resolver: copyResolver) } ?? GameCopyResolver.unavailableText,
                resolver: copyResolver
            )
        case .careerEarnings:
            return ProRetirementCopy.honorValue(
                GameFormatters.krw(Int(clamping: honor.value ?? 0), language: copyResolver.language),
                resolver: copyResolver
            )
        case .nationalGold:
            return ProRetirementCopy.honorValue(
                copyResolver.resolve(.retirementHonorNationalGold),
                resolver: copyResolver
            )
        }
    }
}

struct CareerTotals: View {
    let state: ProCareerSnapshot
    @Environment(\.gameCopyResolver) private var copyResolver

    private var totals: (games: Int, outs: Int, strikeouts: Int, wins: Int, losses: Int, saves: Int, runs: Int, hits: Int, walks: Int) {
        state.careerStats.reduce((0, 0, 0, 0, 0, 0, 0, 0, 0)) {
            ($0.0 + $1.games, $0.1 + $1.inningsOuts, $0.2 + $1.strikeouts,
             $0.3 + $1.wins, $0.4 + $1.losses, $0.5 + $1.saves, $0.6 + $1.runsAllowed,
             $0.7 + $1.hits, $0.8 + $1.walks)
        }
    }

    private var careerWAR: SaberMetricsLine {
        MobileCareerStore.saberBoard(state: state).career
    }

    var body: some View {
        // 통산 기록은 섹션 제목 하나 아래 숫자 타일 아홉 개. 눈썹은 타일 라벨이 맡는다.
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: copyResolver.resolve(.totalsTitle))
                .font(.headline)
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
                // 피안타·볼넷·WHIP. "13년차인데 통산 피안타가 없다"는 리뷰 — 기록 자체는
                // 쌓이고 있었지만 보여 주는 화면이 없었다. 피안타는 2026-08 중순부터
                // 기록되므로 그 전 시즌 몫은 빠질 수 있다.
                HStack(spacing: 10) {
                    Metric(title: copyResolver.resolve(.totalsHits), value: "\(totals.hits)")
                    Metric(title: copyResolver.resolve(.totalsWalks), value: "\(totals.walks)")
                    Metric(
                        title: copyResolver.resolve(.totalsWHIP),
                        value: GameFormatters.whip(hits: totals.hits, walks: totals.walks, outs: totals.outs, language: copyResolver.language)
                    )
                }
                HStack(spacing: 10) {
                    Metric(
                        title: copyResolver.resolve(.totalsWAR),
                        value: careerWAR.warText,
                        tone: careerWAR.warTone == .better ? .raised
                            : careerWAR.warTone == .worse ? .negative
                            : .standard
                    )
                }
                .accessibilityIdentifier("pro.retirement.career.war")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
