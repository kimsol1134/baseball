import SwiftUI
import SimulationCore

struct ProSeasonSettlementView: View {
    let career: MobileCareerStore
    let state: ProCareerSnapshot
    @Environment(\.gameCopyResolver) private var copyResolver

    private var settlement: ProSeasonSettlement? { state.journeyState?.lastSettlement }

    var body: some View {
        if let settlement {
            VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                KeyArtHeader(
                    art: .stadiumNight,
                    eyebrow: copyResolver.resolve(.journeySettlementEyebrow),
                    title: copyResolver.resolve(.journeySettlementTitle, arguments: [.integer(settlement.season)]),
                    accent: BaseballTheme.milestone
                )

                BaseballCard(title: ProCareerPresentation.teamName(state.team, resolver: copyResolver), tone: .positive) {
                    Text(copyResolver.resolve(
                        .journeySettlementStats,
                        arguments: [
                            .integer(settlement.stats.games),
                            .userText(GameFormatters.innings(outs: settlement.stats.inningsOuts, language: copyResolver.language)),
                            .integer(settlement.stats.strikeouts),
                        ]
                    ))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textSecondary)
                }

                BaseballCard(title: copyResolver.resolve(.directionTitle)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(copyResolver.resolve(
                            .journeySettlementLegacy,
                            arguments: [.integer(settlement.teamLegacyBefore), .integer(settlement.teamLegacyAfter)]
                        ))
                        if let goalProgress = settlement.goalProgressAfter {
                            Text(ProCareerPresentation.goalTitle(goalProgress.ambition, resolver: copyResolver))
                                .font(.subheadline.weight(.semibold))
                            ProCareerGoalMetricsView(
                                progress: goalProgress,
                                identifierPrefix: "pro.settlement.goal"
                            )
                        }
                        Text(copyResolver.resolve(
                            .journeySettlementHOF,
                            arguments: [.integer(settlement.hallOfFameBefore), .integer(settlement.hallOfFameAfter)]
                        ))
                        Text(copyResolver.resolve(
                            .journeySettlementContract,
                            arguments: [.integer(settlement.contractYearsBefore), .integer(settlement.contractYearsAfter)]
                        ))
                        if settlement.goalCompleted {
                            Label(copyResolver.resolve(.journeySettlementGoalCompleted), systemImage: "checkmark.seal.fill")
                                .foregroundStyle(BaseballTheme.milestone)
                        }
                        Text(copyResolver.resolve(
                            .journeySettlementNext,
                            arguments: [.userText(nextRouteText(settlement.nextRoute))]
                        ))
                        .foregroundStyle(BaseballTheme.textSecondary)
                    }
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                }

                BaseballCard(title: copyResolver.resolve(.journeySettlementSalaryTitle), tone: .raised) {
                    Text(GameFormatters.krw(safeInt(settlement.salaryIncome), language: copyResolver.language))
                        .font(BaseballType.statNumeral)
                        .foregroundStyle(BaseballTheme.textPrimary)
                        .monospacedDigit()
                        .accessibilityLabel(copyResolver.resolve(
                            .journeySettlementSalary,
                            arguments: [.userText(GameFormatters.krw(safeInt(settlement.salaryIncome), language: copyResolver.language))]
                        ))
                }

                BaseballCard(title: copyResolver.resolve(.journeySettlementFanReasons), tone: .raised) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(copyResolver.resolve(
                            .journeySettlementFan,
                            arguments: [.integer(settlement.fanBefore), .integer(settlement.fanAfter)]
                        ))
                        Text(copyResolver.resolve(
                            .journeySettlementFanDelta,
                            arguments: [.userText(signed(settlement.fanDelta))]
                        ))
                        ForEach(settlement.fanReasons) { reason in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(copyResolver.resolve(.gameContent("content.pro-fan-reason.\(reason.kind.rawValue)")))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                // localization-safe: numeric
                                Text(signed(reason.delta))
                                    .monospacedDigit()
                                    .foregroundStyle(reason.delta >= 0 ? BaseballTheme.positive : BaseballTheme.warning)
                            }
                            .font(.caption)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("pro.settlement.fanReasons")

                BaseballCard(title: copyResolver.resolve(.journeySettlementMerchandiseTitle), tone: .raised) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(GameFormatters.krw(safeInt(settlement.merchandiseIncome), language: copyResolver.language))
                            .font(BaseballType.statNumeral)
                            .monospacedDigit()
                            .accessibilityLabel(copyResolver.resolve(
                                .journeySettlementMerchandise,
                                arguments: [.userText(GameFormatters.krw(safeInt(settlement.merchandiseIncome), language: copyResolver.language))]
                            ))
                        if let tier = settlement.merchandiseTier {
                            Text(copyResolver.resolve(
                                .journeySettlementMerchandiseTier,
                                arguments: [.userText(copyResolver.resolve(.gameContent("content.pro-merchandise-tier.\(tier.rawValue)")))]
                            ))
                            .font(.subheadline)
                            .foregroundStyle(BaseballTheme.textSecondary)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("pro.settlement.merchandise")

                if state.journeyState?.migration.financeNoticePending == true {
                    Text(copyResolver.resolve(.journeySettlementMigrationNotice))
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PrimaryPill(
                    title: copyResolver.resolve(.journeySettlementAcknowledge),
                    identifier: "pro.settlement.acknowledge",
                    action: career.acknowledgeSettlement
                )
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("pro.seasonSettlement")
        } else {
            ContentUnavailableView(copyResolver.resolve(.scheduleComplete), systemImage: "exclamationmark.triangle")
        }
    }

    private func safeInt(_ value: Int64) -> Int {
        Int(clamping: value)
    }

    private func signed(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : String(value)
    }

    private func nextRouteText(_ route: ProSettlementNextRoute) -> String {
        switch route {
        case .underContract: copyResolver.resolve(.journeySettlementNextUnderContract)
        case .renewalMarket: copyResolver.resolve(.journeySettlementNextRenewal)
        case .freeAgencyEligible: copyResolver.resolve(.journeySettlementNextFreeAgency)
        case .forcedRetirement: copyResolver.resolve(.journeySettlementNextRetirement)
        }
    }
}

/// Persisted offers are rendered from the stored market in canonical order. A rookie market is a
