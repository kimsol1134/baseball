import SwiftUI
import SimulationCore
import BaseballIOSDomain

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
                    title: ProSeasonSettlementCopy.title(
                        arcTitleID: settlement.arcTitleID,
                        season: settlement.season,
                        resolver: copyResolver
                    ),
                    accent: BaseballTheme.milestone
                )

                BaseballCard(title: ProCareerPresentation.teamName(state.team, resolver: copyResolver), tone: .positive) {
                    Text(verbatim: ProSeasonSettlementCopy.stats(settlement, resolver: copyResolver))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textSecondary)
                }

                BaseballCard(title: copyResolver.resolve(.directionTitle)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: ProSeasonSettlementCopy.legacy(
                            before: settlement.teamLegacyBefore,
                            after: settlement.teamLegacyAfter,
                            resolver: copyResolver
                        ))
                        if let goalProgress = settlement.goalProgressAfter {
                            Text(verbatim: ProCareerPresentation.goalTitle(goalProgress.ambition, resolver: copyResolver))
                                .font(.subheadline.weight(.semibold))
                            ProCareerGoalMetricsView(
                                progress: goalProgress,
                                identifierPrefix: "pro.settlement.goal"
                            )
                        }
                        Text(verbatim: ProSeasonSettlementCopy.hallOfFame(settlement, resolver: copyResolver))
                        Text(verbatim: ProSeasonSettlementCopy.contract(settlement, resolver: copyResolver))
                        if settlement.goalCompleted {
                            Label(copyResolver.resolve(.journeySettlementGoalCompleted), systemImage: "checkmark.seal.fill")
                                .foregroundStyle(BaseballTheme.milestone)
                        }
                        Text(verbatim: ProSeasonSettlementCopy.nextRoute(settlement.nextRoute, resolver: copyResolver))
                        .foregroundStyle(BaseballTheme.textSecondary)
                    }
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                }

                BaseballCard(title: copyResolver.resolve(.journeySettlementSalaryTitle), tone: .raised) {
                    Text(verbatim: GameFormatters.krw(safeInt(settlement.salaryIncome), language: copyResolver.language))
                        .font(BaseballType.statNumeral)
                        .foregroundStyle(BaseballTheme.textPrimary)
                        .monospacedDigit()
                        .accessibilityLabel(ProSeasonSettlementCopy.salary(
                            amount: settlement.salaryIncome,
                            resolver: copyResolver
                        ))
                }

                BaseballCard(title: copyResolver.resolve(.journeySettlementFanReasons), tone: .raised) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: ProSeasonSettlementCopy.fan(settlement, resolver: copyResolver))
                        Text(verbatim: ProSeasonSettlementCopy.fanDelta(settlement.fanDelta, resolver: copyResolver))
                        ForEach(settlement.fanReasons) { reason in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(verbatim: copyResolver.resolve(.gameContent("content.pro-fan-reason.\(reason.kind.rawValue)")))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                // localization-safe: numeric
                                Text(verbatim: signed(reason.delta))
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
                            .accessibilityLabel(ProSeasonSettlementCopy.merchandise(
                                amount: settlement.merchandiseIncome,
                                resolver: copyResolver
                            ))
                        if let tier = settlement.merchandiseTier {
                            Text(ProSeasonSettlementCopy.merchandiseTier(
                                copyResolver.resolve(.gameContent("content.pro-merchandise-tier.\(tier.rawValue)")),
                                resolver: copyResolver
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
}
