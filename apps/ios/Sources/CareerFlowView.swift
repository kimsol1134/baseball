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

                        switch state.phase {
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
                                        .userText(ProCareerPresentation.effect(decision.effect, resolver: copyResolver)),
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
        if copyResolver.language == .korean {
            return decision.title
        }
        return copyResolver.resolve(decision.type.displayCopyToken)
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
                        Label(ProCareerPresentation.effect(choice.effect, resolver: copyResolver), systemImage: "plusminus.circle")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(BaseballTheme.information)
                            .fixedSize(horizontal: false, vertical: true)
                        Label(copyResolver.resolve(.decisionFollowUp), systemImage: "arrow.turn.down.right")
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
                        .userText(ProCareerPresentation.effect(pendingChoice.effect, resolver: copyResolver)),
                        .userText(copyResolver.resolve(.decisionFollowUp)),
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
                .userText(ProCareerPresentation.effect(choice.effect, resolver: resolver)),
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
    private var freeAgencyReady: Bool { service >= 6 }

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

            OffseasonChoice(
                title: decisionLabel(.continueCareer),
                detail: copyResolver.resolve(
                    .offseasonContinueDetail,
                    arguments: [.userText(ProCareerPresentation.teamName(state.team, resolver: copyResolver))]
                ),
                symbol: "arrow.forward.circle",
                enabled: true,
                note: nil
            ) { pending = .continueCareer }

            OffseasonChoice(
                title: decisionLabel(.militaryService),
                detail: copyResolver.resolve(.offseasonMilitaryDetail),
                symbol: "shield",
                enabled: !state.militaryCompleted,
                note: state.militaryCompleted ? copyResolver.resolve(.offseasonMilitaryDone) : nil
            ) { pending = .militaryService }

            OffseasonChoice(
                title: decisionLabel(.freeAgency),
                detail: copyResolver.resolve(.offseasonFreeAgencyDetail),
                symbol: "arrow.triangle.branch",
                enabled: freeAgencyReady,
                note: freeAgencyReady ? nil : copyResolver.resolve(
                    .offseasonFreeAgencyLocked,
                    arguments: [.integer(service)]
                )
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
                PortraitView(seed: state.identity.name, role: .player, size: 56, playerStage: .pro)
                VStack(alignment: .leading, spacing: 2) {
                    // localization-safe: user-input
                    Text(state.identity.name).font(.headline)
                    Text(copyResolver.resolve(
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
                    Text("\(score)").font(BaseballType.heroNumeral).foregroundStyle(BaseballTheme.milestone)
                }
            }

            CareerTotals(state: state)

            // 이 커리어가 다음 회차에 남기는 것. 프로의 시간이 환생 루프와 무관하면
            // 은퇴가 끝이 되지만, 야구혼으로 이어지면 은퇴가 다음 회차의 시작이 된다.
            BaseballCard(
                title: retiresIntoSignatureLegacy
                    ? copyResolver.resolve(.retiredLegacyTitle) : copyResolver.resolve(.retiredSoulTitle),
                tone: .milestone
            ) {
                Text(copyResolver.resolve(
                    retiresIntoSignatureLegacy ? .retiredLegacyBody : .retiredSoulBody
                ))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(copyResolver.resolve(
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
                        Text(ProCareerPresentation.news(line, state: state, resolver: copyResolver))
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
            Text(copyResolver.resolve(
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
            Text(copyResolver.resolve(
                retiresIntoSignatureLegacy ? .retiredLegacyConfirmMessage : .retiredSoulConfirmMessage,
                arguments: [.userText(state.identity.name)]
            ))
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
