import SwiftUI
import SimulationCore
import BaseballIOSDomain

struct CareerDirectionCard: View {
    let state: ProCareerSnapshot
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        if let journey = state.journeyState {
            let records = MobileCareerStore.teamCareerRecords(for: state)
            let legacy = MobileCareerStore.teamLegacyProjection(
                teamID: state.team.id,
                records: records,
                rulesVersion: journey.rulesVersion
            )
            BaseballCard(title: copyResolver.resolve(.directionTitle), tone: .raised) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: copyResolver.resolve(.directionContract, arguments: contractText(for: state, resolver: copyResolver)))
                    if let goal = journey.activeGoal {
                        Text(verbatim: ProCareerPresentation.goalTitle(goal.ambition, resolver: copyResolver))
                            .font(.subheadline.weight(.semibold))
                        ProCareerGoalMetricsView(
                            progress: MobileCareerStore.goalProgress(state: state, goal: goal),
                            identifierPrefix: "pro.careerDirection.goal"
                        )
                    } else {
                        Text(verbatim: copyResolver.resolve(.directionNoGoal))
                    }
                    if let tier = legacy.tier {
                        if let record = legacy.record, legacy.next {
                            Text(verbatim: legacyProgressText(
                                record: record,
                                score: legacy.score,
                                tier: tier,
                                nextMinimumScore: legacy.nextMinimumScore ?? 0,
                                nextTier: legacy.nextTier ?? tier,
                                nextMinimumCompletedSeasons: legacy.nextMinimumCompletedSeasons,
                                resolver: copyResolver
                            ))
                        } else {
                            Text(verbatim: copyResolver.resolve(
                                .directionLegacy,
                                arguments: [.userText(copyResolver.resolve(tierKey(tier))), .integer(legacy.score)]
                            ))
                        }
                        Text(verbatim: copyResolver.resolve(.directionLegacyHint))
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("pro.careerDirection.legacy.hint")
                    }
                    Text(verbatim: copyResolver.resolve(
                        .directionHOF,
                        arguments: [.integer(MobileCareerStore.hallOfFameProjection(for: state))]
                    ))
                    Text(verbatim: copyResolver.resolve(
                        .directionFan,
                        arguments: [.integer(journey.reputation.fanSupport)]
                    ))
                    Text(verbatim: copyResolver.resolve(
                        .directionFinance,
                        arguments: [
                            .userText(GameFormatters.krw(Int(clamping: journey.finances.careerEarnings), language: copyResolver.language)),
                            .userText(GameFormatters.krw(Int(clamping: journey.finances.availableFunds), language: copyResolver.language)),
                        ]
                    ))
                    Button {
                        withAnimation(reduceMotion ? nil : .snappy) { isExpanded.toggle() }
                    } label: {
                        Label(
                            copyResolver.resolve(isExpanded ? .directionCollapse : .directionExpand),
                            systemImage: isExpanded ? "chevron.up" : "chevron.down"
                        )
                        .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(BaseballTheme.action)
                    .accessibilityIdentifier("pro.careerDirection.toggle")
                    if isExpanded {
                        BaseballCard(title: copyResolver.resolve(.directionRecords), tone: .standard) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(records, id: \.teamID) { teamRecord in
                                    CareerDirectionTeamRecordRow(record: teamRecord)
                                }
                            }
                        }
                        .accessibilityIdentifier("pro.careerDirection.records")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("pro.careerDirection")
        }
    }

    private func contractText(
        for state: ProCareerSnapshot,
        resolver: GameCopyResolver
    ) -> [LocalizedCopyArgument] {
        guard let contract = state.contract else {
            return [.userText(resolver.resolve(.directionNoGoal)), .integer(0), .userText("—")]
        }
        return [
            .userText(resolver.resolve(contract.rolePromise.displayCopyToken)),
            .integer(max(0, contract.yearsRemaining)),
            .userText(GameFormatters.krw(contract.annualSalary, language: resolver.language)),
        ]
    }

    private func legacyProgressText(
        record: ProTeamCareerRecord,
        score: Int,
        tier: ProTeamLegacyTier,
        nextMinimumScore: Int,
        nextTier: ProTeamLegacyTier,
        nextMinimumCompletedSeasons: Int?,
        resolver: GameCopyResolver
    ) -> String {
        let scoreRemaining = max(0, nextMinimumScore - score)
        let currentTier = resolver.resolve(tierKey(tier))
        let upcomingTier = resolver.resolve(tierKey(nextTier))
        guard let minimumSeasons = nextMinimumCompletedSeasons else {
            return resolver.resolve(
                .directionLegacyNext,
                arguments: [
                    .userText(currentTier),
                    .integer(score),
                    .userText(upcomingTier),
                    .integer(scoreRemaining),
                ]
            )
        }

        let seasonsRemaining = max(0, minimumSeasons - record.completedSeasons)
        switch (scoreRemaining > 0, seasonsRemaining > 0) {
        case (true, true):
            return resolver.resolve(
                .directionLegacyNextBoth,
                arguments: [
                    .userText(currentTier),
                    .integer(score),
                    .userText(upcomingTier),
                    .integer(scoreRemaining),
                    .integer(seasonsRemaining),
                ]
            )
        case (true, false):
            return resolver.resolve(
                .directionLegacyNext,
                arguments: [
                    .userText(currentTier),
                    .integer(score),
                    .userText(upcomingTier),
                    .integer(scoreRemaining),
                ]
            )
        case (false, true):
            return resolver.resolve(
                .directionLegacyNextSeasons,
                arguments: [
                    .userText(currentTier),
                    .integer(score),
                    .userText(upcomingTier),
                    .integer(seasonsRemaining),
                ]
            )
        case (false, false):
            return resolver.resolve(
                .directionLegacyNext,
                arguments: [
                    .userText(currentTier),
                    .integer(score),
                    .userText(upcomingTier),
                    .integer(0),
                ]
            )
        }
    }

    private func tierKey(_ tier: ProTeamLegacyTier) -> ProUICopyKey {
        switch tier {
        case .newFace: .directionTierNewFace
        case .supportingPillar: .directionTierSupportingPillar
        case .corePlayer: .directionTierCorePlayer
        case .clubAce: .directionTierClubAce
        case .clubSymbol: .directionTierClubSymbol
        case .retiredNumberCandidate: .directionTierRetiredNumber
        }
    }
}

private struct CareerDirectionTeamRecordRow: View {
    let record: ProTeamCareerRecord
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        let teamName = ProCareerPresentation.teamName(record.teamID, resolver: copyResolver)
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: teamName)
                .font(.subheadline.weight(.semibold))
            Text(verbatim: copyResolver.resolve(
                .directionRecordLine,
                arguments: [.userText(teamName), .integer(record.completedSeasons), .integer(record.consecutiveSeasons)]
            ))
            Text(verbatim: copyResolver.resolve(
                .directionRecordStats,
                arguments: [
                    .integer(record.games),
                    .userText(GameFormatters.innings(outs: record.inningsOuts, language: copyResolver.language)),
                    .integer(record.strikeouts),
                    .integer(record.awardCount),
                ]
            ))
            Text(verbatim: copyResolver.resolve(.directionRecordCommunity, arguments: [.integer(record.communityPoints)]))
                .font(.caption)
                .foregroundStyle(BaseballTheme.textTertiary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pro.careerDirection.record.\(record.teamID)")
    }
}

/// 24주 시즌 안에서 지금 어디쯤인지 보여 준다. 주 단위 진행 게임의 위치 감각을 만든다.
struct SeasonArcBar: View {
    let segment: ProSeasonSegment?
    let week: Int
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                GameCopyText(AppCopyKey.proSeasonProgressTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textSecondary)
                Spacer()
                GameCopyText(
                    AppCopyKey.proSeasonProgressValue,
                    arguments: [.integer(min(week, 24))]
                )
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textSecondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(BaseballTheme.surfaceRaised)
                    Capsule()
                        .fill(BaseballTheme.action)
                        .frame(width: max(4, proxy.size.width * CGFloat(min(week, 24)) / 24))
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(copyResolver.resolve(
            AppCopyKey.proSeasonProgressAccessibility,
            arguments: [.integer(min(week, 24))]
        ))
    }
}

/// 상태 한 칸. 큰 숫자가 주인공이라 `StatTile`을 그대로 쓴다.
struct Metric: View {
    let title: String
    let value: String
    var tone: BaseballCardTone = .standard

    var body: some View {
        StatTile(
            label: title,
            value: value,
            tone: tone == .standard ? BaseballTheme.textPrimary : tone.accent
        )
    }
}
