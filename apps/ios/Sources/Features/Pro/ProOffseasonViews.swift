import SwiftUI
import SimulationCore
import BaseballIOSDomain

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
        return ProOffseasonCopy.openMarketServiceLocked(service: service, resolver: copyResolver)
    }

    private func decisionLabel(_ decision: OffseasonDecision) -> String {
        copyResolver.resolve(decision.displayCopyToken)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(
                art: .stadiumNight,
                eyebrow: ProOffseasonCopy.eyebrow(
                    season: state.season,
                    age: state.age,
                    resolver: copyResolver
                ),
                title: copyResolver.resolve(.offseasonTitle)
            )

            HStack(spacing: 10) {
                Metric(
                    title: copyResolver.resolve(.offseasonService),
                    value: ProOffseasonCopy.years(service, resolver: copyResolver),
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
                    value: ProOffseasonCopy.seasons(state.careerStats.count, resolver: copyResolver)
                )
            }

            if let journeyContractYears {
                if journeyContractExpired {
                    // 계약 만료는 상태가 바뀐 순간이라 경고 면을 갖는다.
                    BaseballCard(title: copyResolver.resolve(.contractOfferExpired), tone: .warning) {
                        Text(copyResolver.resolve(.offseasonContractExpired))
                            .detailStyle(BaseballTheme.textPrimary)
                    }
                } else {
                    // 남은 보장 시즌은 한 줄이면 충분하다 — 눈썹 카드를 두르지 않는다.
                    Label(
                        ProContractCopy.remaining(years: journeyContractYears, resolver: copyResolver),
                        systemImage: "doc.text"
                    )
                    .proseLeadStyle()
                }
            }

            RetirementPreviewCard(state: state)

            OffseasonChoice(
                title: journeyContractExpired
                    ? copyResolver.resolve(.offseasonRenewalChoice)
                    : decisionLabel(.continueCareer),
                detail: journeyContractExpired
                    ? ProOffseasonCopy.renewalDetail(
                        teamName: ProCareerPresentation.teamName(state.team, resolver: copyResolver),
                        resolver: copyResolver
                    )
                    : journeyContractActive
                        ? ProOffseasonCopy.activeContractDetail(
                            teamName: ProCareerPresentation.teamName(state.team, resolver: copyResolver),
                            years: journeyContractYears ?? 0,
                            resolver: copyResolver
                        )
                        : ProOffseasonCopy.continueDetail(
                            teamName: ProCareerPresentation.teamName(state.team, resolver: copyResolver),
                            resolver: copyResolver
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
        .alert(
            confirmTitle,
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })
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
            ProOffseasonCopy.confirmRetireMessage(seasons: state.careerStats.count, resolver: copyResolver)
        case .militaryService:
            ProOffseasonCopy.confirmMilitaryMessage(ageAfter: state.age + 2, resolver: copyResolver)
        case .freeAgency:
            copyResolver.resolve(.offseasonConfirmFreeAgencyMessage)
        default:
            ProOffseasonCopy.confirmContinueMessage(
                teamName: ProCareerPresentation.teamName(state.team, resolver: copyResolver),
                nextSeason: state.season + 1,
                resolver: copyResolver
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
                VStack(alignment: .leading, spacing: 4) {
                    // localization-safe: resolved-copy
                    Text(title).font(.subheadline.weight(.bold))
                    // localization-safe: resolved-copy
                    Text(detail).detailStyle()
                    if let note {
                        // 잠금·비가역 안내. 아이콘만 경고색, 문장은 읽는 글 색.
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "exclamationmark.circle")
                                .font(BaseballType.detail)
                                .foregroundStyle(BaseballTheme.warning)
                            // localization-safe: resolved-copy
                            Text(note).detailStyle()
                        }
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
