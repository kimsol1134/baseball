import SwiftUI
import SimulationCore

struct OffseasonView: View {
    let career: MobileCareerStore
    let state: ProCareerSnapshot
    @Environment(\.gameCopyResolver) private var copyResolver

    @State private var pending: OffseasonDecision?

    private var service: Int { MobileCareerStore.freeAgencyService(state) }
    private var journeyContractYears: Int? { state.journeyState == nil ? nil : state.contract?.yearsRemaining ?? 0 }
    private var journeyContractExpired: Bool { journeyContractYears == 0 && state.journeyState != nil }
    private var journeyContractActive: Bool { journeyContractYears.map { $0 >= 1 } ?? false }
    private var freeAgencyReady: Bool {
        guard service >= 6 else { return false }
        return state.journeyState == nil || journeyContractExpired
    }
    private var freeAgencyLock: String? {
        if freeAgencyReady { return nil }
        if state.journeyState != nil && journeyContractActive {
            return copyResolver.resolve(.offseasonActiveContractOpenMarketLocked)
        }
        return copyResolver.resolve(.offseasonOpenMarketServiceLocked, arguments: [.integer(service)])
    }

    private func decisionLabel(_ decision: OffseasonDecision) -> String {
        copyResolver.resolve(decision.displayCopyToken)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(
                art: .stadiumNight,
                eyebrow: copyResolver.resolve(
                    .offseasonEyebrow,
                    arguments: [.integer(state.season), .integer(state.age)]
                ),
                title: copyResolver.resolve(.offseasonTitle)
            )

            HStack(spacing: 10) {
                Metric(
                    title: copyResolver.resolve(.offseasonService),
                    value: copyResolver.resolve(.offseasonYears, arguments: [.integer(service)]),
                    tone: freeAgencyReady ? .positive : .standard
                )
                Metric(
                    title: copyResolver.resolve(.offseasonMilitary),
                    value: copyResolver.resolve(
                        state.militaryCompleted ? .offseasonMilitaryComplete : .offseasonMilitaryIncomplete
                    )
                )
                Metric(
                    title: copyResolver.resolve(.offseasonCareer),
                    value: copyResolver.resolve(.offseasonSeasons, arguments: [.integer(state.careerStats.count)])
                )
            }

            if let journeyContractYears {
                BaseballCard(
                    title: journeyContractExpired
                        ? copyResolver.resolve(.contractOfferExpired)
                        : copyResolver.resolve(.contractOfferRemainingTitle),
                    tone: journeyContractExpired ? .warning : .raised
                ) {
                    Text(
                        journeyContractExpired
                            ? copyResolver.resolve(.offseasonContractExpired)
                            : copyResolver.resolve(.contractOfferRemaining, arguments: [.integer(journeyContractYears)])
                    )
                        .font(.subheadline)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            RetirementPreviewCard(state: state)

            OffseasonChoice(
                title: journeyContractExpired
                    ? copyResolver.resolve(.offseasonRenewalChoice)
                    : decisionLabel(.continueCareer),
                detail: journeyContractExpired
                    ? copyResolver.resolve(
                        .offseasonRenewalDetail,
                        arguments: [.userText(ProCareerPresentation.teamName(state.team, resolver: copyResolver))]
                    )
                    : journeyContractActive
                        ? copyResolver.resolve(
                            .offseasonActiveContractDetail,
                            arguments: [
                                .userText(ProCareerPresentation.teamName(state.team, resolver: copyResolver)),
                                .integer(journeyContractYears ?? 0),
                            ]
                        )
                        : copyResolver.resolve(
                            .offseasonContinueDetail,
                            arguments: [.userText(ProCareerPresentation.teamName(state.team, resolver: copyResolver))]
                        ),
                symbol: "arrow.forward.circle",
                enabled: true,
                note: nil
            ) { pending = .continueCareer }

            OffseasonChoice(
                title: decisionLabel(.militaryService),
                detail: state.journeyState == nil
                    ? copyResolver.resolve(.offseasonMilitaryDetail)
                    : copyResolver.resolve(.offseasonMilitaryJourneyDetail),
                symbol: "shield",
                enabled: !state.militaryCompleted,
                note: state.militaryCompleted
                    ? copyResolver.resolve(.offseasonMilitaryDone)
                    : nil
            ) { pending = .militaryService }

            OffseasonChoice(
                title: state.journeyState != nil
                    ? copyResolver.resolve(.offseasonOpenMarketChoice)
                    : decisionLabel(.freeAgency),
                detail: copyResolver.resolve(.offseasonOpenMarketDetail),
                symbol: "arrow.triangle.branch",
                enabled: freeAgencyReady,
                note: freeAgencyLock
            ) { pending = .freeAgency }

            OffseasonChoice(
                title: decisionLabel(.retire),
                detail: copyResolver.resolve(.offseasonRetireDetail),
                symbol: "flag.checkered",
                enabled: true,
                note: copyResolver.resolve(.offseasonIrreversible)
            ) { pending = .retire }
        }
        .confirmationDialog(
            confirmTitle,
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible
        ) {
            Button(confirmAction, role: pending == .retire ? .destructive : nil) {
                if let pending { career.chooseOffseason(pending) }
                pending = nil
            }
            .accessibilityIdentifier("pro.offseason.confirm")
            Button(copyResolver.resolve(.offseasonConfirmCancel)) { pending = nil }
        } message: {
            // localization-safe: resolved-copy
            Text(confirmMessage)
        }
    }

    private var confirmTitle: String {
        switch pending {
        case .retire: copyResolver.resolve(.offseasonConfirmRetireTitle)
        case .militaryService: copyResolver.resolve(.offseasonConfirmMilitaryTitle)
        case .freeAgency: copyResolver.resolve(.offseasonConfirmFreeAgencyTitle)
        default: copyResolver.resolve(.offseasonConfirmContinueTitle)
        }
    }

    private var confirmAction: String {
        switch pending {
        case .retire: copyResolver.resolve(.offseasonConfirmRetireAction)
        case .militaryService: copyResolver.resolve(.offseasonConfirmMilitaryAction)
        case .freeAgency: copyResolver.resolve(.offseasonConfirmFreeAgencyAction)
        default: copyResolver.resolve(.offseasonConfirmContinueAction)
        }
    }

    private var confirmMessage: String {
        switch pending {
        case .retire:
            copyResolver.resolve(.offseasonConfirmRetireMessage, arguments: [.integer(state.careerStats.count)])
        case .militaryService:
            copyResolver.resolve(.offseasonConfirmMilitaryMessage, arguments: [.integer(state.age + 2)])
        case .freeAgency:
            copyResolver.resolve(.offseasonConfirmFreeAgencyMessage)
        default:
            copyResolver.resolve(
                .offseasonConfirmContinueMessage,
                arguments: [
                    .userText(ProCareerPresentation.teamName(state.team, resolver: copyResolver)),
                    .integer(state.season + 1),
                ]
            )
        }
    }
}

struct OffseasonChoice: View {
    let title: String
    let detail: String
    let symbol: String
    let enabled: Bool
    let note: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(enabled ? BaseballTheme.selection : BaseballTheme.textTertiary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    // localization-safe: resolved-copy
                    Text(title).font(.subheadline.weight(.bold))
                    // localization-safe: resolved-copy
                    Text(detail).font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let note {
                        // localization-safe: resolved-copy
                        Text(note).font(.caption).foregroundStyle(BaseballTheme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(BaseballTheme.surface, in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                    .stroke(BaseballTheme.border, lineWidth: 1)
            }
            .opacity(enabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier("pro.offseason.\(symbol)")
    }
}

/// 20시즌 완주. 여기서는 계속할 수 없다 — 코어가 어떤 선택을 받아도 은퇴로 보낸다.
///
/// 예전에는 이 국면에 화면이 없어서 `default:`의 "이번 일정은 끝났습니다" 빈 화면으로
