import SwiftUI
import SimulationCore

struct CareerFlowView: View {
    let career: MobileCareerStore
    /// 은퇴 뒤 새 선수로 시작한다. 프로 저장본을 지우고 고교 탭으로 돌려보낸다.
    var onStartNewPlayer: () -> Void = {}
    var retiresIntoSignatureLegacy = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView { CareerSummary(career: career) } detail: { decision }
            } else {
                decision
            }
        }
        .navigationTitle(copyResolver.resolve(.navigationThisWeek))
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(trigger: career.feedbackTrigger) { _, _ in
            switch career.feedbackCue {
            case .growth: .impact(weight: .heavy)
            case .success: .success
            case .setback: .warning
            case .neutral: .selection
            }
        }
    }

    @ViewBuilder private var decision: some View {
        if let state = career.state {
            if state.phase == .importantGame, let session = career.pitchSession {
                PitchView(session: session, onFinish: career.finishImportantGame,
                          onAbort: { _ = career.abandonImportantGame() })
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                        if !career.pendingGains.isEmpty {
                            GrowthCelebrationView(gains: career.pendingGains, onDismiss: career.acknowledgeGains)
                                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                        }
                        if let summary = career.lastSummary, career.pendingGains.isEmpty {
                            ResultBanner(
                                summary: ProCareerPresentation.storeSummary(
                                    summary,
                                    state: state,
                                    resolver: copyResolver
                                ),
                                cue: career.feedbackCue
                            )
                                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        }

                        if state.phase == .seasonSettlement, state.journeyState != nil {
                            ProSeasonSettlementView(career: career, state: state)
                        } else {
                            switch state.phase {
                            case .contractOffer:
                                ProContractOfferView(career: career, state: state)
                            case .offseasonInvestment:
                                ProOffseasonInvestmentView(career: career, state: state)
                            case .weeklyPlan:
                                WeeklyPlanView(career: career, state: state)
                            case .seasonDecision:
                                if let pending = state.pendingDecision {
                                    ProSeasonDecisionView(career: career, decision: pending)
                                } else {
                                    ContentUnavailableView(
                                        copyResolver.resolve(.seasonDecisionUnavailable),
                                        systemImage: "exclamationmark.triangle"
                                    )
                                }
                            case .importantGame:
                                ImportantGameIntro(state: state, onStart: career.beginImportantGame)
                            case .seasonReview:
                                ActionCard(
                                    title: copyResolver.resolve(.seasonReviewTitle),
                                    copy: copyResolver.resolve(.seasonReviewBody),
                                    button: copyResolver.resolve(.seasonReviewAction),
                                    action: career.reviewSeason
                                )
                            case .offseasonDecision:
                                OffseasonView(career: career, state: state)
                            case .retirementDecision:
                                RetirementDecisionView(career: career, state: state)
                            case .completed:
                                RetiredView(
                                    state: state,
                                    retiresIntoSignatureLegacy: retiresIntoSignatureLegacy,
                                    onStartNewPlayer: onStartNewPlayer
                                )
                            default:
                                ContentUnavailableView(
                                    copyResolver.resolve(.scheduleComplete),
                                    systemImage: "checkmark.circle"
                                )
                            }
                        }
                    }
                    .padding(BaseballMetrics.gutter)
                    // 고교 화면과 같은 이유 — 떠 있는 탭 바가 마지막 행동을 덮는다.
                    .safeAreaPadding(.bottom, BaseballMetrics.floatingTabBarClearance)
                }
                .background(BaseballTheme.canvas)
                .animation(reduceMotion ? nil : .snappy, value: career.feedbackTrigger)
            }
        } else {
            ProgressView()
        }
    }
}

private struct ProOffseasonInvestmentView: View {
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
                    Text(copyResolver.resolve(
                        .offseasonInvestmentDetail,
                        arguments: [.integer(state.season + 1)]
                    ))
                    Text(copyResolver.resolve(
                        .offseasonInvestmentFunds,
                        arguments: [.userText(GameFormatters.krw(Int(clamping: availableFunds), language: copyResolver.language))]
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
                Text(copyResolver.resolve(
                    .offseasonInvestmentConfirmMessage,
                    arguments: [
                        .userText(choiceTitle(selectedInvestment)),
                        .userText(benefitText(selectedInvestment)),
                    ]
                ))
            }
        }
    }

    @ViewBuilder
    private func investmentCard(_ investment: ProOffseasonInvestment) -> some View {
        let cost = ProFinanceRules.investmentCost(for: investment)
        let affordable = availableFunds >= cost
        Button {
            selectedInvestment = investment
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    // localization-safe: resolved-copy
                    Text(choiceTitle(investment))
                        .font(.headline)
                    Spacer(minLength: 8)
                    Text(GameFormatters.krw(Int(clamping: cost), language: copyResolver.language))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(affordable ? BaseballTheme.information : BaseballTheme.textTertiary)
                }
                Text(copyResolver.resolve(
                    .offseasonInvestmentCost,
                    arguments: [.userText(GameFormatters.krw(Int(clamping: cost), language: copyResolver.language))]
                ))
                .font(.footnote)
                .foregroundStyle(BaseballTheme.textSecondary)
                Text(copyResolver.resolve(
                    .offseasonInvestmentBenefit,
                    arguments: [.userText(benefitText(investment))]
                ))
                .font(.footnote)
                .foregroundStyle(BaseballTheme.textSecondary)
                Text(copyResolver.resolve(
                    .offseasonInvestmentDuration,
                    arguments: [.userText(durationText(investment))]
                ))
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
            return copyResolver.resolve(
                .offseasonInvestmentPitchLabBenefit,
                arguments: [.userText(focusTitle(selectedFocus))]
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

                BaseballCard(title: copyResolver.resolve(.journeySettlementSalary), tone: .raised) {
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

                BaseballCard(title: copyResolver.resolve(.journeySettlementMerchandise), tone: .raised) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(GameFormatters.krw(safeInt(settlement.merchandiseIncome), language: copyResolver.language))
                            .font(BaseballType.statNumeral)
                            .monospacedDigit()
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
/// single sheet; renewal and open-market decisions remain comparable cards with no default offer.
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
            .accessibilityIdentifier("pro.contractOffer")
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
        .accessibilityIdentifier("\(prefix).team")

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
        guard let offer else { return copyResolver.resolve(.contractOfferConfirmMessage) }
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

private struct ResultBanner: View {
    let summary: String
    let cue: MobileCareerStore.FeedbackCue

    private var tone: BaseballCardTone {
        switch cue {
        case .setback: .negative
        case .growth: .milestone
        default: .positive
        }
    }

    private var symbol: String {
        switch cue {
        case .setback: "exclamationmark.triangle.fill"
        case .growth: "arrow.up.right.circle.fill"
        default: "checkmark.seal.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(tone.accent).font(.footnote)
            // localization-safe: resolved-copy
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

private struct CareerSummary: View {
    let career: MobileCareerStore
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        List {
            if let state = career.state {
                Section(copyResolver.resolve(.summaryPlayer)) {
                    LabeledContent(copyResolver.resolve(.summaryName), value: state.identity.name)
                    LabeledContent(
                        copyResolver.resolve(.summaryTeam),
                        value: ProCareerPresentation.teamName(state.team, resolver: copyResolver)
                    )
                    LabeledContent(copyResolver.resolve(.summaryLevel), value: copyResolver.resolve(state.level.displayCopyToken))
                    LabeledContent(copyResolver.resolve(.summaryRole), value: copyResolver.resolve(state.role.displayCopyToken))
                }
                Section(copyResolver.resolve(.summaryAbility)) {
                    AbilityGaugeView(label: copyResolver.resolve(.summaryStuff), value: state.pitcher.stuff)
                    AbilityGaugeView(label: copyResolver.resolve(.summaryCommand), value: state.pitcher.command)
                    AbilityGaugeView(label: copyResolver.resolve(.summaryMovement), value: state.pitcher.movement)
                    AbilityGaugeView(label: copyResolver.resolve(.summaryStamina), value: state.pitcher.stamina)
                }
                Section(copyResolver.resolve(.summaryMilestones)) {
                    ForEach(Array(state.milestones.suffix(6).reversed()), id: \.self) { milestone in
                        Label(
                            ProCareerPresentation.milestone(milestone, resolver: copyResolver),
                            systemImage: milestone == state.milestones.last ? "star.fill" : "circle.fill"
                        )
                            .foregroundStyle(milestone == state.milestones.last ? BaseballTheme.milestone : BaseballTheme.textSecondary)
                    }
                }
                if let decisions = state.decisionHistory, !decisions.isEmpty {
                    Section(copyResolver.resolve(.summaryDecisions)) {
                        ForEach(Array(decisions.suffix(7).reversed())) { decision in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ProCareerPresentation.decisionRecordTitle(decision, resolver: copyResolver))
                                    .font(.subheadline.weight(.semibold))
                                Text(copyResolver.resolve(
                                    .summaryDecisionLine,
                                    arguments: [
                                        .integer(decision.season),
                                        .integer(decision.week),
                                        .userText(ProCareerPresentation.combinedEffect(
                                            decision.effect,
                                            journeyEffect: decision.journeyEffect,
                                            resolver: copyResolver
                                        )),
                                    ]
                                ))
                                    .font(.caption)
                                    .foregroundStyle(BaseballTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BaseballTheme.canvas)
        .navigationTitle(copyResolver.resolve(.summaryNavigation))
    }
}

/// 시즌의 초반·중반·막바지에 멈추는 갈림길. 선택지는 효과와 비용을 코어가 계산한 숫자 그대로
/// 공개하며, 확인 전에는 어떤 상태도 바꾸지 않는다.
struct ProSeasonDecisionView: View {
    let career: MobileCareerStore
    let decision: ProSeasonDecision
    @State private var pendingChoice: ProSeasonDecisionChoice?
    @Environment(\.gameCopyResolver) private var copyResolver

    private var decisionTitle: String {
        ProCareerPresentation.decisionTitle(decision, resolver: copyResolver)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(
                art: .stadiumNight,
                eyebrow: copyResolver.resolve(
                    .decisionEyebrow,
                    arguments: [.integer(decision.season), .integer(decision.week)]
                ),
                title: decisionTitle,
                accent: BaseballTheme.milestone
            )

            Text(ProCareerPresentation.decisionDetail(decision, resolver: copyResolver))
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(decision.choices) { choice in
                Button { pendingChoice = choice } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(ProCareerPresentation.choiceTitle(choice, resolver: copyResolver))
                                .font(.headline)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right.circle.fill")
                                .foregroundStyle(BaseballTheme.selection)
                        }
                        Text(ProCareerPresentation.choiceDetail(choice, resolver: copyResolver))
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Label(ProCareerPresentation.combinedEffect(
                            choice.effect,
                            journeyEffect: choice.journeyEffect,
                            resolver: copyResolver
                        ), systemImage: "plusminus.circle")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(BaseballTheme.information)
                            .fixedSize(horizontal: false, vertical: true)
                        Label(
                            ProCareerPresentation.decisionTiming(for: decision, resolver: copyResolver),
                            systemImage: decision.type == .mediaOpportunity ? "bolt.fill" : "arrow.turn.down.right"
                        )
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                    .background(BaseballTheme.surface, in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                            .stroke(BaseballTheme.border, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Self.accessibilityLabel(for: choice, resolver: copyResolver))
                .accessibilityHint(copyResolver.resolve(.decisionHint))
                .accessibilityIdentifier("pro.seasonDecision.choice.\(choice.id)")
            }

            Label(copyResolver.resolve(.decisionWarning), systemImage: "exclamationmark.circle")
                .font(.caption)
                .foregroundStyle(BaseballTheme.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("pro.seasonDecision")
        .confirmationDialog(
            pendingChoice.map { ProCareerPresentation.choiceTitle($0, resolver: copyResolver) }
                ?? copyResolver.resolve(.decisionConfirmTitle),
            isPresented: Binding(
                get: { pendingChoice != nil },
                set: { if !$0 { pendingChoice = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(copyResolver.resolve(.decisionConfirmAction)) {
                guard let pendingChoice else { return }
                career.applySeasonDecision(decisionID: decision.id, choiceID: pendingChoice.id)
                self.pendingChoice = nil
            }
            .accessibilityIdentifier("pro.seasonDecision.confirm")
            Button(copyResolver.resolve(.decisionConfirmCancel), role: .cancel) { pendingChoice = nil }
        } message: {
            if let pendingChoice {
                Text(copyResolver.resolve(
                    .decisionConfirmMessage,
                    arguments: [
                        .userText(ProCareerPresentation.choiceDetail(pendingChoice, resolver: copyResolver)),
                        .userText(ProCareerPresentation.combinedEffect(
                            pendingChoice.effect,
                            journeyEffect: pendingChoice.journeyEffect,
                            resolver: copyResolver
                        )),
                        .userText(ProCareerPresentation.decisionTiming(for: decision, resolver: copyResolver)),
                    ]
                ))
            }
        }
    }

    static func accessibilityLabel(
        for choice: ProSeasonDecisionChoice,
        resolver: GameCopyResolver = GameCopyResolver(language: .korean, policy: .releaseSafe)
    ) -> String {
        resolver.resolve(
            ProUICopyKey.decisionAccessibility,
            arguments: [
                .userText(ProCareerPresentation.choiceTitle(choice, resolver: resolver)),
                .userText(ProCareerPresentation.choiceDetail(choice, resolver: resolver)),
                .userText(ProCareerPresentation.combinedEffect(
                    choice.effect,
                    journeyEffect: choice.journeyEffect,
                    resolver: resolver
                )),
                .userText(ProCareerPresentation.decisionTiming(for: choice, resolver: resolver)),
            ]
        )
    }
}

/// 주간 계획. Picker 대신 효과와 비용이 보이는 카드로 고른다(계획 문서 §2.3 B5).
private struct WeeklyPlanView: View {
    let career: MobileCareerStore
    let state: ProCareerSnapshot
    @Environment(\.gameCopyResolver) private var copyResolver

    private struct PlanCopy {
        let plan: ProWeekPlan
        let title: String
        let effect: String
        let cost: String
        let symbol: String
    }

    static func segmentName(_ segment: ProSeasonSegment?) -> String {
        switch segment {
        case .springCamp: "스프링캠프"
        case .opening: "개막"
        case .firstHalf: "전반기"
        case .allStarBreak: "올스타 브레이크"
        case .pennantRace: "페넌트레이스"
        case .seasonFinale, .none: "시즌 막바지"
        }
    }

    static func localizedSegmentName(
        _ segment: ProSeasonSegment?,
        resolver: GameCopyResolver
    ) -> String {
        if resolver.language == .korean {
            return segmentName(segment)
        }
        return resolver.resolve((segment ?? .seasonFinale).displayCopyToken)
    }

    private static func careerArcName(_ season: Int, resolver: GameCopyResolver) -> String {
        switch season {
        case ...3: resolver.resolve(.weeklyArcRookie)
        case ...8: resolver.resolve(.weeklyArcPrime)
        default: resolver.resolve(.weeklyArcVeteran)
        }
    }

    private static func standingLabel(
        _ standing: ProCareerStanding,
        resolver: GameCopyResolver
    ) -> String {
        switch standing {
        case .prospect: resolver.resolve(.weeklyStandingProspect)
        case .roster: resolver.resolve(.weeklyStandingRoster)
        case .established: resolver.resolve(.weeklyStandingEstablished)
        case .ace: resolver.resolve(.weeklyStandingAce)
        case .clubSymbol: resolver.resolve(.weeklyStandingClubSymbol)
        }
    }

    private static func progressText(
        _ plan: ProWeekPlan,
        state: ProCareerSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        let current = state.developmentProgress?.value(for: plan) ?? 0
        return resolver.resolve(.weeklyProgress, arguments: [.integer(current)])
    }

    /// 구위와 변화구를 분리해 이번 선수가 어떤 무기를 완성하는지 선택하게 한다.
    /// 20시즌 내내 같은 카드 제목을 읽는 대신 지금 선수의 과제가 먼저 보인다.
    private static func plans(for state: ProCareerSnapshot, resolver: GameCopyResolver) -> [PlanCopy] {
        let reliefRole = state.role != .starter
        let veteran = state.season >= 9
        return [
            PlanCopy(
                plan: .developStuff,
                title: resolver.resolve(reliefRole ? .weeklyDevelopStuffRelief : veteran ? .weeklyDevelopStuffVeteran : .weeklyDevelopStuffStarter),
                effect: resolver.resolve(.weeklyDevelopStuffEffect, arguments: [
                    .userText(progressText(.developStuff, state: state, resolver: resolver)),
                ]),
                cost: resolver.resolve(.weeklyDevelopStuffCost),
                symbol: "flame"
            ),
            PlanCopy(
                plan: .developMovement,
                title: resolver.resolve(.weeklyDevelopMovementTitle),
                effect: resolver.resolve(.weeklyDevelopMovementEffect, arguments: [
                    .userText(progressText(.developMovement, state: state, resolver: resolver)),
                ]),
                cost: resolver.resolve(.weeklyDevelopMovementCost),
                symbol: "hurricane"
            ),
            PlanCopy(
                plan: .refineCommand,
                title: resolver.resolve(.weeklyCommandTitle),
                effect: resolver.resolve(.weeklyCommandEffect, arguments: [
                    .userText(progressText(.refineCommand, state: state, resolver: resolver)),
                ]),
                cost: resolver.resolve(.weeklyCommandCost),
                symbol: "scope"
            ),
            PlanCopy(
                plan: .buildStamina,
                title: resolver.resolve(reliefRole ? .weeklyStaminaReliefTitle : .weeklyStaminaStarterTitle),
                effect: resolver.resolve(.weeklyStaminaEffect, arguments: [
                    .userText(progressText(.buildStamina, state: state, resolver: resolver)),
                ]),
                cost: resolver.resolve(.weeklyStaminaCost),
                symbol: "figure.run"
            ),
            PlanCopy(
                plan: .recover,
                title: resolver.resolve(veteran ? .weeklyRecoveryVeteranTitle : .weeklyRecoveryTitle),
                effect: resolver.resolve(
                    (state.proRulesVersion ?? 1) >= ProCareerEngine.currentRulesVersion
                        ? .weeklyRecoveryAgencyEffect
                        : .weeklyRecoveryEffect
                ),
                cost: resolver.resolve(
                    (state.proRulesVersion ?? 1) >= ProCareerEngine.currentRulesVersion
                        ? .weeklyRecoveryAgencyCost
                        : .weeklyRecoveryCost
                ),
                symbol: "bed.double"
            ),
            PlanCopy(
                plan: .earnTrust,
                title: resolver.resolve(state.level == .minor ? .weeklyTrustMinorTitle : reliefRole ? .weeklyTrustReliefTitle : .weeklyTrustStarterTitle),
                effect: resolver.resolve(.weeklyTrustEffect),
                cost: resolver.resolve(.weeklyTrustCost),
                symbol: "person.2"
            ),
        ]
    }

    private static func recommendation(
        for state: ProCareerSnapshot,
        resolver: GameCopyResolver
    ) -> (plan: ProWeekPlan, reason: String) {
        if state.fatigue >= 68 { return (.recover, resolver.resolve(.weeklyRecommendInjury)) }
        if state.level == .minor, state.managerTrust < 60 {
            return (.earnTrust, resolver.resolve(.weeklyRecommendCallUp))
        }
        let identity = PitcherBuildRules.identity(for: state.pitcher)
        return switch identity {
        case .power: (.developStuff, resolver.resolve(.weeklyRecommendPower))
        case .command: (.refineCommand, resolver.resolve(.weeklyRecommendCommand))
        case .movement: (.developMovement, resolver.resolve(.weeklyRecommendMovement))
        case .stamina: (.buildStamina, resolver.resolve(.weeklyRecommendStamina))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            HStack(spacing: 10) {
                Metric(title: copyResolver.resolve(.weeklyFatigue), value: "\(state.fatigue)", tone: state.fatigue >= 70 ? .warning : .standard)
                Metric(title: copyResolver.resolve(.weeklyManagerTrust), value: "\(state.managerTrust)", tone: state.managerTrust >= 60 ? .positive : .standard)
                Metric(title: copyResolver.resolve(.weeklyRole), value: copyResolver.resolve(state.role.displayCopyToken))
            }

            let identity = PitcherBuildRules.identity(for: state.pitcher)
            BaseballCard(title: copyResolver.resolve(
                .weeklyBlueprint,
                arguments: [.userText(ProCareerPresentation.buildLabel(identity, resolver: copyResolver))]
            ), tone: .raised) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ProCareerPresentation.buildStrength(identity, resolver: copyResolver)).font(.footnote)
                    Text(ProCareerPresentation.buildTradeoff(identity, resolver: copyResolver))
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.warning)
                    if let rolePreference = state.rolePreference {
                        Label(
                            copyResolver.resolve(
                                .weeklyRolePromise,
                                arguments: [.userText(copyResolver.resolve(rolePreference.displayCopyToken))]
                            ),
                            systemImage: "checkmark.seal.fill"
                        )
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BaseballTheme.positive)
                    }
                }
            }

            let standing = ProCareerEngine.careerStanding(for: state)
            BaseballCard(title: copyResolver.resolve(.weeklyStandingTitle), tone: .milestone) {
                VStack(alignment: .leading, spacing: 5) {
                    Label(
                        Self.standingLabel(standing, resolver: copyResolver),
                        systemImage: standing == .clubSymbol ? "star.circle.fill" : "shield.lefthalf.filled"
                    )
                    .font(.headline)
                    .foregroundStyle(BaseballTheme.milestone)
                    Text(copyResolver.resolve(.weeklyStandingSchedule, arguments: [
                        .userText(copyResolver.resolve(state.role.displayCopyToken)),
                        .integer(ProCareerEngine.expectedRemainingOutings(for: state)),
                    ]))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textSecondary)
                    if state.age >= 33 {
                        Text(copyResolver.resolve(.weeklyStandingVeteran))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(BaseballTheme.positive)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(copyResolver.resolve(.weeklyTitle)).font(.headline)
                Text(copyResolver.resolve(
                    .weeklyRoutine,
                    arguments: [
                        .userText(Self.careerArcName(state.season, resolver: copyResolver)),
                        .userText(copyResolver.resolve(state.role.displayCopyToken)),
                    ]
                ))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textSecondary)
            }

            let recommendation = Self.recommendation(for: state, resolver: copyResolver)

            if career.selectedPlan == nil {
                Label(copyResolver.resolve(.weeklyChoosePlan), systemImage: "hand.tap")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BaseballTheme.information)
                    .accessibilityIdentifier("pro.plan.required")
            }

            ForEach(Self.plans(for: state, resolver: copyResolver), id: \.plan) { copy in
                PlanCard(
                    copy: copy,
                    selected: career.selectedPlan == copy.plan,
                    recommendation: copy.plan == recommendation.plan ? recommendation.reason : nil
                ) {
                    career.selectedPlan = copy.plan
                }
            }

            if career.selectedPlan == .developMovement {
                let breakingBalls = (state.pitcher.pitchProfiles ?? [])
                    .map(\.pitchType)
                    .filter { $0 != .fourSeam }
                if !breakingBalls.isEmpty {
                    Picker(copyResolver.resolve(.weeklyDevelopmentPitch), selection: Binding(
                        get: { career.selectedDevelopmentPitch },
                        set: { career.selectedDevelopmentPitch = $0 }
                    )) {
                        ForEach(breakingBalls, id: \.self) { pitch in
                            Text(PitchCopy.localized(pitch, resolver: copyResolver)).tag(pitch)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("pro.developmentPitch")
                }
            }

            PrimaryPill(title: copyResolver.resolve(.weeklyAdvance), identifier: "pro.advanceWeek", action: career.advanceWeek)
                .disabled(career.selectedPlan == nil)

            Button(action: career.advanceSegment) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(copyResolver.resolve(
                        AppCopyKey.proWeeklyPlanUntil,
                        arguments: [
                            .userText(Self.localizedSegmentName(state.seasonSegment, resolver: copyResolver)),
                        ]
                    ))
                        .font(.subheadline.weight(.semibold))
                    Text(copyResolver.resolve(
                        career.selectedPlan == .recover && (state.proRulesVersion ?? 1) < ProCareerEngine.currentRulesVersion
                            ? .weeklyRecoverySingleWeek
                            : .weeklyAdvanceStop
                    ))
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .disabled(
                career.selectedPlan == nil
                    || (career.selectedPlan == .recover
                        && (state.proRulesVersion ?? 1) < ProCareerEngine.currentRulesVersion)
            )
            .frame(minHeight: BaseballMetrics.minimumTapTarget)
            .accessibilityIdentifier("pro.advanceSegment")
        }
    }

    private struct PlanCard: View {
        let copy: PlanCopy
        let selected: Bool
        let recommendation: String?
        let onSelect: () -> Void

        var body: some View {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: copy.symbol)
                        .font(.title3)
                        .foregroundStyle(selected ? BaseballTheme.selection : BaseballTheme.textSecondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            // localization-safe: resolved-copy
                            Text(copy.title).font(.subheadline.weight(.bold))
                            if let recommendation {
                                // localization-safe: resolved-copy
                                Text(recommendation)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(BaseballTheme.actionInk)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(BaseballTheme.action, in: Capsule())
                            }
                        }
                        // localization-safe: resolved-copy
                        Text(copy.effect).font(.footnote).foregroundStyle(BaseballTheme.positive)
                        // localization-safe: resolved-copy
                        Text(copy.cost).font(.footnote).foregroundStyle(BaseballTheme.warning)
                    }
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? BaseballTheme.selection : BaseballTheme.border)
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .background(
                    selected ? BaseballTheme.selection.opacity(0.12) : BaseballTheme.surface,
                    in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                        .stroke(selected ? BaseballTheme.selection : BaseballTheme.border, lineWidth: selected ? 2 : 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("pro.plan.\(copy.plan.rawValue)")
        }
    }
}

/// 승부 시작 전 장면. 상대와 상황을 먼저 보여 주고 나서 투구 화면으로 들어간다.
private struct ImportantGameIntro: View {
    let state: ProCareerSnapshot
    let onStart: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(
                art: state.level == .major ? .proStadiumTunnel : .stadiumNight,
                eyebrow: copyResolver.resolve(
                    .importantEyebrow,
                    arguments: [.integer(state.season), .integer(state.week)]
                ),
                title: state.level == .major
                    ? copyResolver.resolve(.importantMajorTitle)
                    : state.managerTrust < 55
                        ? copyResolver.resolve(.importantMinorOpportunityTitle)
                        : copyResolver.resolve(.importantMinorRoleTitle),
                accent: BaseballTheme.milestone
            )

            if let rival = state.currentRival {
                let rivalCopy = ProCareerPresentation.rival(rival, resolver: copyResolver)
                BaseballCard(title: copyResolver.resolve(.importantOpponent), tone: .milestone) {
                    HStack(alignment: .top, spacing: 10) {
                        // 고교 라이벌 카드와 같은 문법 — 상대에게 얼굴이 있어야 승부다.
                        PortraitView(seed: rival.name, role: .rival, size: 46)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(rivalCopy.name) · \(rivalCopy.teamName)").font(.headline)
                            // localization-safe: resolved-copy
                            Text(rivalCopy.archetype).font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                            // localization-safe: resolved-copy
                            Text(rivalCopy.profile).font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            // localization-safe: resolved-copy
                            Text(rivalCopy.record).font(.footnote.monospacedDigit()).foregroundStyle(BaseballTheme.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            BaseballCard(title: copyResolver.resolve(.importantMyStatus)) {
                HStack(spacing: 10) {
                    Metric(title: copyResolver.resolve(.importantFatigue), value: "\(state.fatigue)", tone: state.fatigue >= 70 ? .warning : .standard)
                    Metric(title: copyResolver.resolve(.importantManagerTrust), value: "\(state.managerTrust)")
                    Metric(title: copyResolver.resolve(.importantCatcherTrust), value: "\(state.catcherTrust)")
                }
            }

            Text(copyResolver.resolve(.importantBody))
                .font(.footnote)
                .foregroundStyle(BaseballTheme.textSecondary)

            PrimaryPill(title: copyResolver.resolve(.importantAction), identifier: "pro.game.start", action: onStart)
        }
    }
}

/// 오프시즌 네 갈래.
///
/// 예전에는 "현재 구단에 남기" 하나였다. 코어는 잔류·군 복무·FA·은퇴를 전부 받는데
/// 화면이 하나만 냈으니, 한국 야구 커리어의 큰 갈림길 두 개(군 복무·FA)가 게임에
/// 존재하지 않았던 셈이다.
///
/// 자격은 화면이 먼저 계산해 잠근다. 못 누를 버튼을 내고 코어의 오류 문자열로 규칙을
/// 알려 주는 것은 규칙을 가르치는 방식이 아니다.
private struct OffseasonView: View {
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

private struct OffseasonChoice: View {
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
/// 떨어졌다. 오래 플레이한 사람의 커리어가 바로 그 자리에서 막혔다.
private struct RetirementDecisionView: View {
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

private struct RetirementPreviewCard: View {
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
        .accessibilityIdentifier("pro.retirement.preview")
    }
}

/// 은퇴한 뒤. 커리어의 마지막 화면이라 회고와 통산 기록만 남는다.
private struct RetiredView: View {
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

private struct RetirementHonorsCard: View {
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

private struct CareerTotals: View {
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

private struct ActionCard: View {
    let title: String
    let copy: String
    let button: String
    let action: () -> Void

    var body: some View {
        BaseballCard(title: title, tone: .raised) {
            VStack(alignment: .leading, spacing: 12) {
                // localization-safe: resolved-copy
                Text(copy).font(.subheadline)
                PrimaryPill(title: button, action: action)
            }
        }
    }
}
