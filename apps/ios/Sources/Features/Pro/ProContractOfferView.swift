import SwiftUI
import SimulationCore
import BaseballIOSDomain

struct ProContractOfferView: View {
    let career: MobileCareerStore
    let state: ProCareerSnapshot
    /// 부상·성장 카드처럼 국면 위에 얹는 알림. 이 화면은 스크롤을 직접 가지므로 흐름 화면이
    /// 알림을 넘겨 준다.
    var notices: CareerFlowNotices? = nil

    @Environment(\.gameCopyResolver) private var copyResolver
    @State private var selectedAmbition: ProCareerAmbition?
    @State private var pendingOfferID: String?
    @State private var showingCounterSheet = false

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
            marketScreen(market)
        } else {
            ContentUnavailableView(copyResolver.resolve(.scheduleComplete), systemImage: "exclamationmark.triangle")
                .accessibilityIdentifier("pro.contractOffer.invalid")
        }
    }

    /// 스크롤 + 하단 고정 서명 바. 목표 선택·제안 카드 순서는 시장 종류가 정한다.
    private func marketScreen(_ market: ProContractMarket) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                if let notices {
                    notices
                }
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
                        .detailStyle()
                        .accessibilityIdentifier("pro.contractOffer.market.compare")
                }

                if market.kind == .rookie {
                    // 지명 정보는 눈썹 카드 없이 리드 한 줄 + 보조 줄로.
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: ProContractCopy.team(
                            ProCareerPresentation.teamName(state.team, resolver: copyResolver),
                            resolver: copyResolver
                        ))
                        .proseLeadStyle()
                        if let round = market.draftRound {
                            Text(verbatim: ProContractCopy.draftRound(round, resolver: copyResolver))
                                .detailStyle()
                        }
                        if let pick = market.overallPick {
                            Text(verbatim: ProContractCopy.draftPick(pick, resolver: copyResolver))
                                .detailStyle()
                        }
                    }
                    .accessibilityElement(children: .combine)
                }

                if market.kind != .rookie {
                    goalSelectionSection(market)
                }

                ForEach(Array(market.offers.enumerated()), id: \.offset) { index, offer in
                    offerCard(
                        offer,
                        index: index,
                        selectable: market.kind != .rookie,
                        enabled: goalSelectionComplete
                    )
                    if offer.preservesTeamLegacy,
                       offer.teamID == state.team.id,
                       CareerDisplayRules.canRequestContractCounter(state) {
                        stayCounterControls
                    }
                    if let counter = market.counterOffer,
                       offer.preservesTeamLegacy,
                       offer.teamID == state.team.id {
                        Label(
                            copyResolver.resolve(
                                counter.accepted ? .contractOfferCounterAccepted : .contractOfferCounterRejected
                            ),
                            systemImage: counter.accepted ? "checkmark.circle" : "xmark.circle"
                        )
                        .detailStyle(BaseballTheme.textPrimary)
                        .accessibilityIdentifier("pro.contractOffer.counter.result")
                    }
                }

                // 신인은 제안 숫자 → 장기 목표 → (하단 고정) 서명 순서로 위에서 아래로 읽힌다.
                if market.kind == .rookie {
                    goalSelectionSection(market)
                }
            }
            .padding(.bottom, 28)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("pro.contractOffer")
            .padding(BaseballMetrics.gutter)
            // 서명 바가 없는 재계약·FA 시장에서는 떠 있는 탭 바가 마지막 카드를 덮는다.
            .safeAreaPadding(.bottom, market.kind == .rookie ? 0 : BaseballMetrics.floatingTabBarClearance)
            .task(id: market.id) {
                // A contract screen normally disappears between markets, but resetting here
                // keeps a reused SwiftUI identity from carrying an old ambition or dialog into
                // the next negotiation.
                pendingOfferID = nil
                selectedAmbition = nil
                showingCounterSheet = false
                guard market.kind != .rookie,
                      let activeGoal = state.journeyState?.activeGoal,
                      activeGoal.completedSeason == nil else {
                    return
                }
                selectedAmbition = activeGoal.ambition
            }
            .alert(
                copyResolver.resolve(.contractOfferConfirmTitle),
                isPresented: Binding(
                    get: { pendingOffer != nil },
                    set: { if !$0 { pendingOfferID = nil } }
                )
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
        }
        .background(BaseballTheme.canvas)
        // 주 행동은 항상 손 닿는 곳에 — 서명 버튼과 비활성 이유를 탭 바 위에 고정한다.
        // 서명이 스크롤 맨 아래 탭 바 뒤에 있어 "목표 하나를 고르세요"가 접힌 아래에
        // 있었다(페르소나 보고서 §2-1, §3 P2/P3).
        .safeAreaInset(edge: .bottom) {
            if market.kind == .rookie, let offer {
                rookieSignBar(offer)
            }
        }
    }

    /// 탭 바 위에 고정되는 서명 바. 비활성일 때는 이유가 버튼 바로 위에 붙는다.
    @ViewBuilder
    private func rookieSignBar(_ offer: ProContractOffer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !goalSelectionComplete {
                Label(copyResolver.resolve(.contractOfferAmbitionRequired), systemImage: "hand.tap")
                    .detailStyle()
                    .accessibilityIdentifier("pro.contractOffer.ambition.required")
            }
            PrimaryPill(
                title: copyResolver.resolve(.contractOfferSign),
                identifier: "pro.contractOffer.sign",
                enabled: goalSelectionComplete
            ) {
                pendingOfferID = offer.id
            }
            // 확인 알럿이 떠 있는 동안 뒤의 서명 버튼을 접근성 트리에서 빼, 알럿 버튼과
            // 같은 이름이 두 번 잡히지 않게 한다(페르소나 보고서 §2-4).
            .accessibilityHidden(pendingOffer != nil)
        }
        .padding(.horizontal, BaseballMetrics.gutter)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(BaseballTheme.canvas)
        .overlay(alignment: .top) {
            Rectangle().fill(BaseballTheme.border.opacity(0.45)).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pro.contractOffer.signBar")
    }

    private var extraYearAvailability: ProCounterAvailability {
        MobileCareerStore.counterAvailability(for: state, kind: .extraYear)
    }

    private var raiseSalaryAvailability: ProCounterAvailability {
        MobileCareerStore.counterAvailability(for: state, kind: .raiseSalary)
    }

    private var extraYearAvailable: Bool { extraYearAvailability.isAvailable }
    private var raiseSalaryAvailable: Bool { raiseSalaryAvailability.isAvailable }

    @ViewBuilder
    private var stayCounterControls: some View {
        if extraYearAvailable || raiseSalaryAvailable {
            PrimaryPill(
                title: copyResolver.resolve(.contractOfferCounterAction),
                identifier: "pro.contractOffer.counter.open"
            ) {
                showingCounterSheet = true
            }
            if showingCounterSheet {
                stayCounterChoice(
                    kind: .extraYear,
                    title: copyResolver.resolve(.contractOfferCounterExtraYear),
                    availability: extraYearAvailability,
                    identifier: "pro.contractOffer.counter.extra_year",
                    isAvailable: extraYearAvailable
                )
                stayCounterChoice(
                    kind: .raiseSalary,
                    title: copyResolver.resolve(.contractOfferCounterRaiseSalary),
                    availability: raiseSalaryAvailability,
                    identifier: "pro.contractOffer.counter.raise_salary",
                    isAvailable: raiseSalaryAvailable
                )
            }
        } else {
            stayCounterUnavailableReasons
        }
    }

    @ViewBuilder
    private func stayCounterChoice(
        kind: ProContractCounterKind,
        title: String,
        availability: ProCounterAvailability,
        identifier: String,
        isAvailable: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(title) {
                _ = career.requestContractCounter(kind: kind)
                showingCounterSheet = false
            }
            .disabled(!isAvailable)
            .accessibilityIdentifier(identifier)
            if case .unavailable(let reason) = availability {
                Text(verbatim: ProContractCopy.counterUnavailable(reason, resolver: copyResolver))
                    .detailStyle()
                    .accessibilityIdentifier("pro.contractOffer.counter.unavailable.\(kind.rawValue)")
            }
        }
    }

    @ViewBuilder
    private var stayCounterUnavailableReasons: some View {
        let reasons = [extraYearAvailability.reason, raiseSalaryAvailability.reason]
            .compactMap { $0 }
        let unique = reasons.reduce(into: [ProCounterUnavailableReason]()) { values, reason in
            if !values.contains(reason) { values.append(reason) }
        }
        VStack(alignment: .leading, spacing: 4) {
            ForEach(unique, id: \.rawValue) { reason in
                Text(verbatim: ProContractCopy.counterUnavailable(reason, resolver: copyResolver))
                    .detailStyle()
            }
        }
        .accessibilityIdentifier("pro.contractOffer.counter.unavailable")
    }

    @ViewBuilder
    private func offerCard(
        _ offer: ProContractOffer,
        index: Int,
        selectable: Bool,
        enabled: Bool
    ) -> some View {
        let prefix = "pro.contractOffer.offer.\(index)"
        let card = BaseballCard(
            title: teamName(for: offer),
            tone: offer.teamID == state.team.id ? .positive : .raised
        ) {
            VStack(alignment: .leading, spacing: 10) {
                contractValue(
                    title: copyResolver.resolve(.contractOfferDurationTitle),
                    value: ProContractCopy.duration(years: offer.years, resolver: copyResolver),
                    identifier: "\(prefix).duration"
                )
                contractValue(
                    title: copyResolver.resolve(.contractOfferAnnualSalary),
                    value: GameFormatters.krw(offer.annualSalary, language: copyResolver.language),
                    identifier: "\(prefix).annualSalary"
                )
                GlossaryText(
                    text: ProContractCopy.rolePromise(
                        copyResolver.resolve(offer.rolePromise.displayCopyToken),
                        resolver: copyResolver
                    ),
                    font: BaseballType.detail
                )
                .accessibilityIdentifier("\(prefix).role")
                contractValue(
                    title: copyResolver.resolve(.contractOfferGuaranteedSalary),
                    value: GameFormatters.krw(CareerDisplayRules.totalGuaranteedSalary(for: offer), language: copyResolver.language),
                    identifier: "\(prefix).guarantee"
                )
                if let signingBonus = offer.signingBonus {
                    contractValue(
                        title: copyResolver.resolve(.contractOfferSigningBonus),
                        value: GameFormatters.krw(signingBonus, language: copyResolver.language),
                        identifier: "\(prefix).signingBonus"
                    )
                }
                if let interest = offer.interest {
                    // 구단 관심은 칩 하나로, 이유는 용어 링크가 붙은 보조 문장으로.
                    EffectChip(
                        text: ProContractCopy.interestLevel(interest.level, resolver: copyResolver),
                        tone: interest.level == .hot ? .gain : .neutral,
                        systemImage: "building.2"
                    )
                    .accessibilityIdentifier("pro.contractOffer.interest.\(interest.level.rawValue)")
                    GlossaryText(
                        text: ProContractCopy.interestReason(interest, resolver: copyResolver),
                        font: BaseballType.detail
                    )
                    .accessibilityIdentifier("\(prefix).interest.reason")
                }
                GlossaryText(
                    text: ProContractCopy.expectation(
                        kindName: expectationName(offer.expectation.kind),
                        target: offer.expectation.target,
                        difficultyName: difficultyName(offer.expectation.difficulty),
                        resolver: copyResolver
                    ),
                    font: BaseballType.detail
                )
                .accessibilityIdentifier("\(prefix).expectation")
                Text(verbatim: ProContractCopy.outlook(outlookName(offer.outlook), resolver: copyResolver))
                    .detailStyle()
                    .accessibilityLabel(copyResolver.resolve(.contractOfferOutlook))
                Text(ProContractCopy.legacyImpact(
                    copyResolver.resolve(offer.preservesTeamLegacy ? .contractOfferLegacyPreserved : .contractOfferLegacyReset),
                    resolver: copyResolver
                ))
                .detailStyle()
                .accessibilityIdentifier("\(prefix).legacy")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Do not put an accessibility identifier on the card container. SwiftUI propagates
        // that identifier to the contained semantic fields on this screen and masks their
        // stable duration/salary/role/expectation/legacy identifiers.

        if selectable {
            Button {
                guard enabled else { return }
                pendingOfferID = offer.id
            } label: {
                card
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .accessibilityHint(copyResolver.resolve(
                enabled ? .contractOfferReview : .contractOfferAmbitionRequired
            ))
            .accessibilityIdentifier(prefix)
        } else {
            card
        }
    }

    @ViewBuilder
    private func goalSelectionSection(_ market: ProContractMarket) -> some View {
        // 눈썹 카드 대신 섹션 제목 하나. 제안 카드의 구단 이름이 이 화면의 눈썹을 차지한다.
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: copyResolver.resolve(.contractOfferGoalTitle))
                .font(.headline)
            Text(copyResolver.resolve(.contractOfferGoalInstruction))
                .detailStyle()

            if market.kind != .rookie && allAmbitionsCompleted {
                Text(copyResolver.resolve(.contractOfferAllAmbitionsComplete))
                    .proseLeadStyle(BaseballTheme.milestone)
                    .accessibilityIdentifier("pro.contractOffer.ambition.all-complete")
            } else {
                ForEach(Self.ambitions, id: \.rawValue) { ambition in
                    ambitionChoice(ambition, marketKind: market.kind)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        // 신인 시장의 같은 안내는 하단 서명 바가 버튼 바로 위에 붙인다.
        if !goalSelectionComplete, market.kind != .rookie {
            Label(copyResolver.resolve(.contractOfferAmbitionRequired), systemImage: "hand.tap")
                .detailStyle()
                .accessibilityIdentifier("pro.contractOffer.ambition.required")
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
        let team = MobileCareerStore.team(id: offer.teamID) ?? state.team
        return ProCareerPresentation.teamName(team, resolver: copyResolver)
    }

    private func confirmationMessage(for offer: ProContractOffer?) -> String {
        // SwiftUI may evaluate the dialog message once while its presentation binding is
        // transitioning. The localized template requires two arguments, so do not resolve it
        // until the selected persisted offer is available.
        guard let offer else { return "" }
        return ProContractCopy.confirmation(
            teamName: teamName(for: offer),
            years: offer.years,
            isTransfer: offer.teamID != state.team.id,
            resolver: copyResolver
        )
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
