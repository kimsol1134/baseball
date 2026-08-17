import SwiftUI
import SimulationCore

struct ProContractOfferView: View {
    let career: MobileCareerStore
    let state: ProCareerSnapshot

    @Environment(\.gameCopyResolver) private var copyResolver
    @State private var selectedAmbition: ProCareerAmbition?
    @State private var pendingOfferID: String?

    private static let ambitions: [ProCareerAmbition] = [
        .franchiseIcon,
        .recordBook,
        .enduringPro,
    ]

    private var market: ProContractMarket? { state.journeyState?.pendingContractMarket }
    private var offer: ProContractOffer? { market?.offers.first }
    private var pendingOffer: ProContractOffer? {
        guard let pendingOfferID else { return nil }
        return market?.offers.first(where: { $0.id == pendingOfferID })
    }
    private var allAmbitionsCompleted: Bool {
        guard let journey = state.journeyState else { return false }
        let completed = Set(
            journey.goalHistory.filter { $0.outcome == .completed }.map(\.ambition)
                + (journey.activeGoal?.completedSeason != nil ? [journey.activeGoal!.ambition] : [])
        )
        return completed.count == Self.ambitions.count
    }
    private var goalSelectionComplete: Bool {
        guard let market else { return false }
        return selectedAmbition != nil || (market.kind != .rookie && allAmbitionsCompleted)
    }

    var body: some View {
        if let market, !market.offers.isEmpty {
            VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                KeyArtHeader(
                    art: .stadiumNight,
                    eyebrow: market.kind == .rookie
                        ? copyResolver.resolve(.contractOfferEyebrow)
                        : copyResolver.resolve(.contractOfferMarketOpen),
                    title: marketTitle(market),
                    accent: BaseballTheme.information
                )

                if market.kind != .rookie {
                    Text(copyResolver.resolve(.contractOfferMarketCompare))
                        .font(.subheadline)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("pro.contractOffer.market.compare")
                }

                if market.kind == .rookie {
                    BaseballCard(
                        title: copyResolver.resolve(
                            .contractOfferTeam,
                            arguments: [.userText(ProCareerPresentation.teamName(state.team, resolver: copyResolver))]
                        ),
                        tone: .raised
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            if let round = market.draftRound {
                                Text(copyResolver.resolve(.contractOfferDraftRound, arguments: [.integer(round)]))
                            }
                            if let pick = market.overallPick {
                                Text(copyResolver.resolve(.contractOfferDraftPick, arguments: [.integer(pick)]))
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                ForEach(Array(market.offers.enumerated()), id: \.offset) { index, offer in
                    offerCard(offer, index: index, selectable: market.kind != .rookie)
                }

                BaseballCard(title: copyResolver.resolve(.contractOfferGoalTitle), tone: .milestone) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(copyResolver.resolve(.contractOfferGoalInstruction))
                            .font(.subheadline)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if market.kind != .rookie && allAmbitionsCompleted {
                            Text(copyResolver.resolve(.contractOfferAllAmbitionsComplete))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BaseballTheme.milestone)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("pro.contractOffer.ambition.all-complete")
                        } else {
                            ForEach(Self.ambitions, id: \.rawValue) { ambition in
                                ambitionChoice(ambition, marketKind: market.kind)
                            }
                        }
                    }
                }

                if !goalSelectionComplete {
                    Label(copyResolver.resolve(.contractOfferAmbitionRequired), systemImage: "hand.tap")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BaseballTheme.information)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("pro.contractOffer.ambition.required")
                }

                if market.kind == .rookie, let offer {
                    PrimaryPill(
                        title: copyResolver.resolve(.contractOfferSign),
                        identifier: "pro.contractOffer.sign",
                        enabled: goalSelectionComplete
                    ) {
                        pendingOfferID = offer.id
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("pro.contractOffer")
            .task(id: market.id) {
                guard market.kind != .rookie,
                      selectedAmbition == nil,
                      let activeGoal = state.journeyState?.activeGoal,
                      activeGoal.completedSeason == nil else {
                    return
                }
                selectedAmbition = activeGoal.ambition
            }
            .confirmationDialog(
                copyResolver.resolve(.contractOfferConfirmTitle),
                isPresented: Binding(
                    get: { pendingOffer != nil },
                    set: { if !$0 { pendingOfferID = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let pendingOffer {
                    Button(copyResolver.resolve(.contractOfferConfirmAction)) {
                        career.acceptContract(
                            marketID: market.id,
                            offerID: pendingOffer.id,
                            ambition: selectedAmbition
                        )
                        pendingOfferID = nil
                    }
                    .disabled(!goalSelectionComplete)
                    .accessibilityIdentifier("pro.contractOffer.confirm.accept")
                }
                Button(copyResolver.resolve(.contractOfferConfirmCancel)) {
                    pendingOfferID = nil
                }
                .accessibilityIdentifier("pro.contractOffer.confirm.cancel")
            } message: {
                Text(verbatim: confirmationMessage(for: pendingOffer))
            }
        } else {
            ContentUnavailableView(copyResolver.resolve(.scheduleComplete), systemImage: "exclamationmark.triangle")
                .accessibilityIdentifier("pro.contractOffer.invalid")
        }
    }

    @ViewBuilder
    private func offerCard(_ offer: ProContractOffer, index: Int, selectable: Bool) -> some View {
        let prefix = "pro.contractOffer.offer.\(index)"
        let card = BaseballCard(
            title: teamName(for: offer),
            tone: offer.teamID == state.team.id ? .positive : .raised
        ) {
            VStack(alignment: .leading, spacing: 10) {
                contractValue(
                    title: copyResolver.resolve(.contractOfferDurationTitle),
                    value: copyResolver.resolve(.contractOfferDuration, arguments: [.integer(offer.years)]),
                    identifier: "\(prefix).duration"
                )
                contractValue(
                    title: copyResolver.resolve(.contractOfferAnnualSalary),
                    value: GameFormatters.krw(offer.annualSalary, language: copyResolver.language),
                    identifier: "\(prefix).annualSalary"
                )
                Text(copyResolver.resolve(
                    .contractOfferRolePromise,
                    arguments: [.userText(copyResolver.resolve(offer.rolePromise.displayCopyToken))]
                ))
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("\(prefix).role")
                contractValue(
                    title: copyResolver.resolve(.contractOfferGuaranteedSalary),
                    value: GameFormatters.krw(totalGuaranteedSalary(for: offer), language: copyResolver.language),
                    identifier: "\(prefix).guarantee"
                )
                if let signingBonus = offer.signingBonus {
                    contractValue(
                        title: copyResolver.resolve(.contractOfferSigningBonus),
                        value: GameFormatters.krw(signingBonus, language: copyResolver.language),
                        identifier: "\(prefix).signingBonus"
                    )
                }
                Text(copyResolver.resolve(
                    .contractOfferExpectation,
                    arguments: [
                        .userText(expectationName(offer.expectation.kind)),
                        .integer(offer.expectation.target),
                        .userText(difficultyName(offer.expectation.difficulty)),
                    ]
                ))
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("\(prefix).expectation")
                Text(copyResolver.resolve(
                    .contractOfferOutlookLine,
                    arguments: [.userText(outlookName(offer.outlook))]
                ))
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(copyResolver.resolve(.contractOfferOutlook))
                Text(copyResolver.resolve(
                    .contractOfferLegacyImpact,
                    arguments: [.userText(
                        copyResolver.resolve(offer.preservesTeamLegacy ? .contractOfferLegacyPreserved : .contractOfferLegacyReset)
                    )]
                ))
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("\(prefix).legacy")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Do not put an accessibility identifier on the card container. SwiftUI propagates
        // that identifier to the contained semantic fields on this screen and masks their
        // stable duration/salary/role/expectation/legacy identifiers.

        if selectable {
            Button {
                pendingOfferID = offer.id
            } label: {
                card
            }
            .buttonStyle(.plain)
            .accessibilityHint(copyResolver.resolve(.contractOfferReview))
            .accessibilityIdentifier(prefix)
        } else {
            card
        }
    }

    @ViewBuilder
    private func contractValue(title: String, value: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BaseballTheme.textSecondary)
            Text(verbatim: value)
                .font(BaseballType.statNumeral)
                .foregroundStyle(BaseballTheme.textPrimary)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private func ambitionChoice(_ ambition: ProCareerAmbition, marketKind: ProContractMarketKind) -> some View {
        let selected = selectedAmbition == ambition
        let completed = state.journeyState?.goalHistory.contains { $0.outcome == .completed && $0.ambition == ambition } == true
        let isCurrentActive = state.journeyState?.activeGoal?.ambition == ambition
            && state.journeyState?.activeGoal?.completedSeason == nil
        let disabled = marketKind != .rookie && completed && !isCurrentActive
        Button {
            selectedAmbition = ambition
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? BaseballTheme.selection : BaseballTheme.textTertiary)
                Text(verbatim: ambitionName(ambition))
                    .font(.headline)
                    .foregroundStyle(BaseballTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BaseballTheme.surface, in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                    .stroke(selected ? BaseballTheme.selection : BaseballTheme.border, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(disabled ? copyResolver.resolve(.contractOfferAllAmbitionsComplete) : "")
        .accessibilityIdentifier("pro.contractOffer.ambition.\(ambition.rawValue)")
    }

    private func marketTitle(_ market: ProContractMarket) -> String {
        switch market.kind {
        case .rookie: copyResolver.resolve(.contractOfferTitle)
        case .renewal: copyResolver.resolve(.contractOfferMarketRenewalTitle)
        case .freeAgency: copyResolver.resolve(.contractOfferMarketFreeAgencyTitle)
        }
    }

    private func teamName(for offer: ProContractOffer) -> String {
        let team = ProCareerEngine.proTeams.first(where: { $0.id == offer.teamID }) ?? state.team
        return ProCareerPresentation.teamName(team, resolver: copyResolver)
    }

    private func confirmationMessage(for offer: ProContractOffer?) -> String {
        // SwiftUI may evaluate the dialog message once while its presentation binding is
        // transitioning. The localized template requires two arguments, so do not resolve it
        // until the selected persisted offer is available.
        guard let offer else { return "" }
        let arguments: [GameCopyArgument] = [
            .userText(teamName(for: offer)),
            .integer(offer.years),
        ]
        if offer.teamID != state.team.id {
            return copyResolver.resolve(.contractOfferConfirmTransferMessage, arguments: arguments)
        }
        return copyResolver.resolve(.contractOfferConfirmMessage, arguments: arguments)
    }

    private func totalGuaranteedSalary(for offer: ProContractOffer) -> Int {
        Int(clamping: Int64(offer.annualSalary) * Int64(offer.years))
    }

    private func ambitionName(_ ambition: ProCareerAmbition) -> String {
        switch ambition {
        case .franchiseIcon: copyResolver.resolve(.ambitionFranchiseIcon)
        case .recordBook: copyResolver.resolve(.ambitionRecordBook)
        case .enduringPro: copyResolver.resolve(.ambitionEnduringPro)
        }
    }

    private func outlookName(_ outlook: ProTeamOutlook) -> String {
        switch outlook {
        case .opportunity: copyResolver.resolve(.teamOutlookOpportunity)
        case .balanced: copyResolver.resolve(.teamOutlookBalanced)
        case .contender: copyResolver.resolve(.teamOutlookContender)
        }
    }

    private func expectationName(_ kind: ProContractExpectationKind) -> String {
        switch kind {
        case .majorRoster: copyResolver.resolve(.contractExpectationMajorRoster)
        case .innings: copyResolver.resolve(.contractExpectationInnings)
        case .strikeouts: copyResolver.resolve(.contractExpectationStrikeouts)
        case .saves: copyResolver.resolve(.contractExpectationSaves)
        case .runPrevention: copyResolver.resolve(.contractExpectationRunPrevention)
        }
    }

    private func difficultyName(_ difficulty: ProExpectationDifficulty) -> String {
        switch difficulty {
        case .accessible: copyResolver.resolve(.contractOfferDifficultyAccessible)
        case .standard: copyResolver.resolve(.contractOfferDifficultyStandard)
        case .stretch: copyResolver.resolve(.contractOfferDifficultyStretch)
        }
    }
}
