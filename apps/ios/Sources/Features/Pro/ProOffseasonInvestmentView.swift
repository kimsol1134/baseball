import SwiftUI
import SimulationCore
import BaseballIOSDomain

struct ProOffseasonInvestmentView: View {
    let career: MobileCareerStore
    let state: ProCareerSnapshot
    @State private var selectedInvestment: ProOffseasonInvestment?
    @State private var selectedFocus: ProDevelopmentFocus = .stuff
    @State private var showingConfirmation = false
    @Environment(\.gameCopyResolver) private var copyResolver

    private static let options: [ProOffseasonInvestment] = [
        .pitchLab, .recoveryTeam, .fanFoundation, .none,
    ]

    private var availableFunds: Int64 {
        state.journeyState?.finances.availableFunds ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(
                art: .stadiumNight,
                eyebrow: copyResolver.resolve(.offseasonInvestmentEyebrow),
                title: copyResolver.resolve(.offseasonInvestmentTitle),
                accent: BaseballTheme.milestone
            )

            BaseballCard(title: copyResolver.resolve(.offseasonInvestmentBody), tone: .raised) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: ProOffseasonCopy.investmentDetail(
                        nextSeason: state.season + 1,
                        resolver: copyResolver
                    ))
                    Text(verbatim: ProOffseasonCopy.investmentFunds(
                        available: availableFunds,
                        resolver: copyResolver
                    ))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(BaseballTheme.information)
                }
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Self.options, id: \.rawValue) { investment in
                investmentCard(investment)
            }

            if selectedInvestment == .pitchLab {
                BaseballCard(title: copyResolver.resolve(.offseasonInvestmentFocus), tone: .raised) {
                    Picker(copyResolver.resolve(.offseasonInvestmentFocus), selection: $selectedFocus) {
                        ForEach(ProDevelopmentFocus.allCases, id: \.rawValue) { focus in
                            // localization-safe: resolved-copy
                            Text(focusTitle(focus)).tag(focus)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("pro.offseasonInvestment.focus")
                }
            }

            if let selectedInvestment {
                PrimaryPill(
                    title: copyResolver.resolve(.offseasonInvestmentConfirmAction),
                    identifier: "pro.offseasonInvestment.continue",
                    action: { showingConfirmation = true }
                )
                .accessibilityIdentifier("pro.offseasonInvestment.confirm")
                .accessibilityHint(copyResolver.resolve(.offseasonInvestmentConfirmTitle))
                .accessibilityValue(choiceTitle(selectedInvestment))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pro.offseasonInvestment")
        .confirmationDialog(
            copyResolver.resolve(.offseasonInvestmentConfirmTitle),
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button(copyResolver.resolve(.offseasonInvestmentConfirmAction)) {
                guard let selectedInvestment else { return }
                _ = career.chooseInvestment(
                    investment: selectedInvestment,
                    focus: selectedInvestment == .pitchLab ? selectedFocus : nil
                )
                self.selectedInvestment = nil
            }
            .accessibilityIdentifier("pro.offseasonInvestment.confirm.action")
            Button(copyResolver.resolve(.offseasonInvestmentConfirmCancel), role: .cancel) { }
        } message: {
            if let selectedInvestment {
                Text(verbatim: ProOffseasonCopy.investmentConfirmMessage(
                    choice: choiceTitle(selectedInvestment),
                    benefit: benefitText(selectedInvestment),
                    resolver: copyResolver
                ))
            }
        }
    }

    @ViewBuilder
    private func investmentCard(_ investment: ProOffseasonInvestment) -> some View {
        let cost = CareerDisplayRules.investmentCost(for: investment)
        let affordable = availableFunds >= cost
        Button {
            selectedInvestment = investment
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    // localization-safe: resolved-copy
                    Text(verbatim: choiceTitle(investment))
                        .font(.headline)
                    Spacer(minLength: 8)
                    Text(verbatim: GameFormatters.krw(Int(clamping: cost), language: copyResolver.language))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(affordable ? BaseballTheme.information : BaseballTheme.textTertiary)
                }
                Text(verbatim: ProOffseasonCopy.investmentCost(amount: cost, resolver: copyResolver))
                .font(.footnote)
                .foregroundStyle(BaseballTheme.textSecondary)
                Text(verbatim: ProOffseasonCopy.investmentBenefit(benefitText(investment), resolver: copyResolver))
                .font(.footnote)
                .foregroundStyle(BaseballTheme.textSecondary)
                Text(verbatim: ProOffseasonCopy.investmentDuration(durationText(investment), resolver: copyResolver))
                .font(.caption)
                .foregroundStyle(BaseballTheme.textTertiary)
                if !affordable {
                    Label(copyResolver.resolve(.offseasonInvestmentInsufficient), systemImage: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BaseballTheme.warning)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(BaseballTheme.surface, in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                    .stroke(selectedInvestment == investment ? BaseballTheme.selection : BaseballTheme.border, lineWidth: selectedInvestment == investment ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!affordable)
        .accessibilityIdentifier("pro.offseasonInvestment.choice.\(investment.rawValue)")
        .accessibilityLabel(choiceTitle(investment))
        .accessibilityValue(benefitText(investment))
    }

    private func choiceTitle(_ investment: ProOffseasonInvestment) -> String {
        copyResolver.resolve(copyKey(for: investment))
    }

    private func focusTitle(_ focus: ProDevelopmentFocus) -> String {
        let key: ProUICopyKey
        switch focus {
        case .stuff: key = .offseasonInvestmentFocusStuff
        case .command: key = .offseasonInvestmentFocusCommand
        case .movement: key = .offseasonInvestmentFocusMovement
        case .stamina: key = .offseasonInvestmentFocusStamina
        }
        return copyResolver.resolve(key)
    }

    private func copyKey(for investment: ProOffseasonInvestment) -> ProUICopyKey {
        switch investment {
        case .pitchLab: .offseasonInvestmentChoicePitchLab
        case .recoveryTeam: .offseasonInvestmentChoiceRecoveryTeam
        case .fanFoundation: .offseasonInvestmentChoiceFanFoundation
        case .none: .offseasonInvestmentChoiceNone
        }
    }

    private func benefitText(_ investment: ProOffseasonInvestment) -> String {
        switch investment {
        case .pitchLab:
            return ProOffseasonCopy.pitchLabBenefit(
                focusTitle: focusTitle(selectedFocus),
                resolver: copyResolver
            )
        case .recoveryTeam:
            return copyResolver.resolve(.offseasonInvestmentRecoveryTeamBenefit)
        case .fanFoundation:
            return copyResolver.resolve(.offseasonInvestmentFoundationBenefit)
        case .none:
            return copyResolver.resolve(.journeyEffectNone)
        }
    }

    private func durationText(_ investment: ProOffseasonInvestment) -> String {
        switch investment {
        case .pitchLab: copyResolver.resolve(.offseasonInvestmentDurationSeason)
        case .recoveryTeam: copyResolver.resolve(.offseasonInvestmentDurationCharge)
        case .fanFoundation, .none: copyResolver.resolve(.offseasonInvestmentDurationImmediate)
        }
    }
}
