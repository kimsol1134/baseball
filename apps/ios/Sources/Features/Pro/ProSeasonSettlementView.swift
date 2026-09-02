import SwiftUI
import SimulationCore
import BaseballIOSDomain

struct ProSeasonSettlementView: View {
    let career: MobileCareerStore
    let state: ProCareerSnapshot
    /// 시즌 리뷰 제목이 먼저 서고(Peak-End), 오른 능력은 그 아래에 온다.
    /// CareerFlowView가 결산 국면에서는 성장 카드를 여기로 넘긴다.
    var pendingGains: [AbilityGain] = []
    var onAcknowledgeGains: () -> Void = {}
    @Environment(\.gameCopyResolver) private var copyResolver
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

                if !pendingGains.isEmpty {
                    GrowthCelebrationView(
                        gains: pendingGains,
                        stageContext: .pro,
                        onDismiss: onAcknowledgeGains
                    )
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                }

                // 구단과 시즌 성적. 눈썹은 구단 이름 하나, 본문은 성적 한 줄.
                BaseballCard(title: ProCareerPresentation.teamName(state.team, resolver: copyResolver)) {
                    Text(verbatim: ProSeasonSettlementCopy.stats(settlement, resolver: copyResolver))
                        .detailStyle(BaseballTheme.textPrimary)
                        .monospacedDigit()
                }

                BaseballCard(title: copyResolver.resolve(.directionTitle)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: ProSeasonSettlementCopy.legacy(
                            before: settlement.teamLegacyBefore,
                            after: settlement.teamLegacyAfter,
                            resolver: copyResolver
                        ))
                        .detailStyle(BaseballTheme.textPrimary)
                        if let goalProgress = settlement.goalProgressAfter {
                            Text(verbatim: ProCareerPresentation.goalTitle(goalProgress.ambition, resolver: copyResolver))
                                .proseLeadStyle()
                            ProCareerGoalMetricsView(
                                progress: goalProgress,
                                identifierPrefix: "pro.settlement.goal"
                            )
                        }
                        Text(verbatim: ProSeasonSettlementCopy.hallOfFame(settlement, resolver: copyResolver))
                            .detailStyle(BaseballTheme.textPrimary)
                        Text(verbatim: ProSeasonSettlementCopy.contract(settlement, resolver: copyResolver))
                            .detailStyle(BaseballTheme.textPrimary)
                        if settlement.goalCompleted {
                            Label(copyResolver.resolve(.journeySettlementGoalCompleted), systemImage: "checkmark.seal.fill")
                                .proseLeadStyle(BaseballTheme.milestone)
                        }
                        Text(verbatim: ProSeasonSettlementCopy.nextRoute(settlement.nextRoute, resolver: copyResolver))
                            .detailStyle()
                    }
                    .monospacedDigit()
                }

                // 팬 지지 변화: 결과 한 줄(제목·요약) → 이유는 접기.
                ProgressiveDisclosure(
                    contentID: "pro.settlement.fanReasons.v1",
                    title: copyResolver.resolve(.journeySettlementFanReasons),
                    summary: ProSeasonSettlementCopy.fan(settlement, resolver: copyResolver)
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: ProSeasonSettlementCopy.fan(settlement, resolver: copyResolver))
                            .detailStyle(BaseballTheme.textPrimary)
                        Text(verbatim: ProSeasonSettlementCopy.fanDelta(settlement.fanDelta, resolver: copyResolver))
                            .detailStyle()
                        ForEach(settlement.fanReasons) { reason in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(verbatim: copyResolver.resolve(.gameContent("content.pro-fan-reason.\(reason.kind.rawValue)")))
                                    .detailStyle()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                // localization-safe: numeric
                                Text(verbatim: signed(reason.delta))
                                    .font(BaseballType.detail.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(reason.delta >= 0 ? BaseballTheme.positive : BaseballTheme.warning)
                            }
                        }
                    }
                    .monospacedDigit()
                }
                .accessibilityIdentifier("pro.settlement.fanReasons")

                // 연봉·응원 상품 수익. 큰 숫자 하나에 보조 한 줄.
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

                BaseballCard(title: copyResolver.resolve(.journeySettlementMerchandiseTitle), tone: .raised) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: GameFormatters.krw(safeInt(settlement.merchandiseIncome), language: copyResolver.language))
                            .font(BaseballType.statNumeral)
                            .foregroundStyle(BaseballTheme.textPrimary)
                            .monospacedDigit()
                            .accessibilityLabel(ProSeasonSettlementCopy.merchandise(
                                amount: settlement.merchandiseIncome,
                                resolver: copyResolver
                            ))
                        if let tier = settlement.merchandiseTier {
                            Text(verbatim: ProSeasonSettlementCopy.merchandiseTier(
                                copyResolver.resolve(.gameContent("content.pro-merchandise-tier.\(tier.rawValue)")),
                                resolver: copyResolver
                            ))
                            .detailStyle()
                        }
                    }
                }
                .accessibilityIdentifier("pro.settlement.merchandise")

                if state.journeyState?.migration.financeNoticePending == true {
                    Text(copyResolver.resolve(.journeySettlementMigrationNotice))
                        .detailStyle(BaseballTheme.textTertiary)
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
