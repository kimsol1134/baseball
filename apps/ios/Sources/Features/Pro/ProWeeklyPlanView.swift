import SwiftUI
import SimulationCore
import BaseballIOSDomain

private extension TalentAbility {
    var masteryPlan: ProWeekPlan {
        switch self {
        case .stuff: .developStuff
        case .command: .refineCommand
        case .movement: .developMovement
        case .stamina: .buildStamina
        }
    }
}

struct WeeklyPlanView: View {
    let career: MobileCareerStore
    let state: ProCareerSnapshot
    @Environment(\.gameCopyResolver) private var copyResolver
    @Environment(\.appTabSelection) private var appTabSelection
    @AppStorage(CopyDensity.storageKey) private var densityRaw = CopyDensity.automatic.rawValue

    private var copyDensity: CopyDensity { CopyDensity(rawValue: densityRaw) ?? .automatic }
    private var hidesGoalHint: Bool { copyDensity == .compact }

    private struct PlanCopy {
        let plan: ProWeekPlan
        let title: String
        let effect: String
        let cost: String
        let risk: String
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

    static func progressText(
        _ plan: ProWeekPlan,
        state: ProCareerSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        // 노장 하락으로 능력 밴드가 내려가면 저장된 게이지가 새 임계값보다 클 수 있다.
        // 엔진은 다음 해당 주에 정확히 +1을 주므로 "가득 참"이 사실이다 — 3/2처럼
        // 분모를 넘는 표시는 사용자에게 계산이 꼬였다는 신호로만 읽힌다.
        ProWeeklyCopy.progress(plan, state: state, resolver: resolver)
    }

    /// 구위와 변화구를 분리해 이번 선수가 어떤 무기를 완성하는지 선택하게 한다.
    /// 20시즌 내내 같은 카드 제목을 읽는 대신 지금 선수의 과제가 먼저 보인다.
    private static func plans(for state: ProCareerSnapshot, resolver: GameCopyResolver) -> [PlanCopy] {
        let reliefRole = state.role != .starter
        let veteran = state.season >= 9
        func risk(_ plan: ProWeekPlan) -> String {
            ProWeeklyCopy.injuryRisk(
                forecast: ProWeekHealthForecast.forecast(state: state, plan: plan),
                resolver: resolver
            )
        }
        return [
            PlanCopy(
                plan: .developStuff,
                title: resolver.resolve(reliefRole ? .weeklyDevelopStuffRelief : veteran ? .weeklyDevelopStuffVeteran : .weeklyDevelopStuffStarter),
                effect: ProWeeklyCopy.developStuffEffect(
                    progress: progressText(.developStuff, state: state, resolver: resolver),
                    resolver: resolver
                ),
                cost: resolver.resolve(.weeklyDevelopStuffCost),
                risk: risk(.developStuff),
                symbol: "flame"
            ),
            PlanCopy(
                plan: .developMovement,
                title: resolver.resolve(.weeklyDevelopMovementTitle),
                effect: ProWeeklyCopy.developMovementEffect(
                    progress: progressText(.developMovement, state: state, resolver: resolver),
                    resolver: resolver
                ),
                cost: resolver.resolve(.weeklyDevelopMovementCost),
                risk: risk(.developMovement),
                symbol: "hurricane"
            ),
            PlanCopy(
                plan: .refineCommand,
                title: resolver.resolve(.weeklyCommandTitle),
                effect: ProWeeklyCopy.commandEffect(
                    progress: progressText(.refineCommand, state: state, resolver: resolver),
                    resolver: resolver
                ),
                cost: resolver.resolve(.weeklyCommandCost),
                risk: risk(.refineCommand),
                symbol: "scope"
            ),
            PlanCopy(
                plan: .buildStamina,
                title: resolver.resolve(reliefRole ? .weeklyStaminaReliefTitle : .weeklyStaminaStarterTitle),
                effect: ProWeeklyCopy.staminaEffect(
                    progress: progressText(.buildStamina, state: state, resolver: resolver),
                    resolver: resolver
                ),
                cost: resolver.resolve(.weeklyStaminaCost),
                risk: risk(.buildStamina),
                symbol: "figure.run"
            ),
            PlanCopy(
                plan: .recover,
                title: resolver.resolve(veteran ? .weeklyRecoveryVeteranTitle : .weeklyRecoveryTitle),
                effect: resolver.resolve(
                    MobileCareerStore.usesAgencyRules(state)
                        ? .weeklyRecoveryAgencyEffect
                        : .weeklyRecoveryEffect
                ),
                cost: resolver.resolve(
                    MobileCareerStore.usesAgencyRules(state)
                        ? .weeklyRecoveryAgencyCost
                        : .weeklyRecoveryCost
                ),
                risk: risk(.recover),
                symbol: "bed.double"
            ),
            PlanCopy(
                plan: .earnTrust,
                title: resolver.resolve(state.level == .minor ? .weeklyTrustMinorTitle : reliefRole ? .weeklyTrustReliefTitle : .weeklyTrustStarterTitle),
                effect: resolver.resolve(.weeklyTrustEffect),
                cost: resolver.resolve(.weeklyTrustCost),
                risk: risk(.earnTrust),
                symbol: "person.2"
            ),
        ]
    }

    private static func followUpSymbol(_ type: ProSeasonDecisionType) -> String {
        switch type {
        case .rotationPush: "clock.arrow.circlepath"
        case .newPitchTrial: "baseball"
        case .farmReset: "arrow.down.circle"
        case .veteranMentor: "person.2"
        default: "checkmark.seal"
        }
    }

    private static func recommendation(
        for state: ProCareerSnapshot,
        resolver: GameCopyResolver
    ) -> (plan: ProWeekPlan, reason: String) {
        if state.fatigue >= 68 { return (.recover, resolver.resolve(.weeklyRecommendInjury)) }
        if state.level == .minor, state.managerTrust < 60 {
            return (.earnTrust, resolver.resolve(.weeklyRecommendCallUp))
        }
        let identity = CareerDisplayRules.pitcherIdentity(for: state.pitcher)
        return switch identity {
        case .power: (.developStuff, resolver.resolve(.weeklyRecommendPower))
        case .command: (.refineCommand, resolver.resolve(.weeklyRecommendCommand))
        case .movement: (.developMovement, resolver.resolve(.weeklyRecommendMovement))
        case .stamina: (.buildStamina, resolver.resolve(.weeklyRecommendStamina))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            Group {
                if CareerDisplayRules.shouldOfferRoleRequest(state) {
                    ProRoleRequestCard(career: career, state: state)
                        .transition(.identity)
                }
            }
            .animation(nil, value: state.roleRequest != nil)

            ProWeeklyGoalBoardCard(
                state: state,
                hidesHint: hidesGoalHint,
                onOpenRecords: { appTabSelection?.wrappedValue = .records }
            )

            ForEach(state.resolvedFollowUps ?? []) { followUp in
                let seenID = "pro.decision.followup.\(followUp.type.rawValue).v1"
                BaseballCard(
                    title: copyResolver.resolve(.decisionFollowUpCardTitle),
                    tone: .milestone
                ) {
                    ProgressiveDisclosure(
                        contentID: seenID,
                        title: copyResolver.resolve(followUp.type.displayCopyToken),
                        summary: ProCareerPresentation.followUpSummary(followUp, resolver: copyResolver)
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(
                                copyResolver.resolve(followUp.type.displayCopyToken),
                                systemImage: Self.followUpSymbol(followUp.type)
                            )
                            .font(.headline)
                            Text(ProCareerPresentation.followUpSummary(followUp, resolver: copyResolver))
                                .font(.footnote)
                                .foregroundStyle(BaseballTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .accessibilityIdentifier("pro.weekly.decisionFollowUp.\(followUp.type.rawValue)")
                .onAppear {
                    CareerTelemetry.logOnce(
                        .proWeeklyDecisionFollowUpShown,
                        [
                            "decision_type": followUp.type.rawValue,
                            "season": followUp.season,
                            "week": followUp.week,
                        ]
                    )
                }
            }

            HStack(spacing: 10) {
                Metric(title: copyResolver.resolve(.weeklyFatigue), value: "\(state.fatigue)", tone: state.fatigue >= 70 ? .warning : .standard)
                Metric(title: copyResolver.resolve(.weeklyManagerTrust), value: "\(state.managerTrust)", tone: state.managerTrust >= 60 ? .positive : .standard)
                Metric(title: copyResolver.resolve(.weeklyRole), value: copyResolver.resolve(state.role.displayCopyToken))
            }

            if let climate = CareerDisplayRules.liveClimate(for: state) {
                let key: ProUICopyKey = switch climate {
                case .hot: .weeklyClimateHot
                case .even: .weeklyClimateEven
                case .slump: .weeklyClimateSlump
                case .adapted: .weeklyClimateAdapted
                }
                Text(copyResolver.resolve(key))
                    .font(.footnote.weight(climate == .slump || climate == .adapted ? .semibold : .regular))
                    .foregroundStyle(climate == .slump ? BaseballTheme.warning : BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pro.weekly.climate")
            }

            let mastery = state.pitcher.effectiveMastery
            ForEach(TalentAbility.allCases, id: \.rawValue) { ability in
                let level = mastery.value(for: ability)
                let baseInternalRating: Int = {
                    switch ability {
                    case .stuff: state.pitcher.stuff
                    case .command: state.pitcher.command
                    case .movement: state.pitcher.movement
                    case .stamina: state.pitcher.stamina
                    }
                }()
                MasteryGaugeView(
                    ability: ability,
                    baseInternalRating: baseInternalRating,
                    level: level,
                    progress: state.developmentProgress?.value(for: ability.masteryPlan) ?? 0,
                    required: 6
                )
            }

            let identity = CareerDisplayRules.pitcherIdentity(for: state.pitcher)
            BaseballCard(title: ProWeeklyCopy.blueprint(
                ProCareerPresentation.buildLabel(identity, resolver: copyResolver),
                resolver: copyResolver
            ), tone: .raised) {
                ProgressiveDisclosure(
                    contentID: "pro.weekly.blueprint.v1",
                    title: ProCareerPresentation.buildLabel(identity, resolver: copyResolver),
                    summary: ProCareerPresentation.buildStrength(identity, resolver: copyResolver)
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ProCareerPresentation.buildStrength(identity, resolver: copyResolver)).font(.footnote)
                        Text(ProCareerPresentation.buildTradeoff(identity, resolver: copyResolver))
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.warning)
                        if let rolePreference = state.rolePreference {
                            Label(
                                ProWeeklyCopy.rolePromise(
                                    copyResolver.resolve(rolePreference.displayCopyToken),
                                    resolver: copyResolver
                                ),
                                systemImage: "checkmark.seal.fill"
                            )
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(BaseballTheme.positive)
                        }
                    }
                }
            }

            let standing = MobileCareerStore.careerStanding(for: state)
            BaseballCard(title: copyResolver.resolve(.weeklyStandingTitle), tone: .milestone) {
                ProgressiveDisclosure(
                    contentID: "pro.weekly.standing.v1",
                    title: Self.standingLabel(standing, resolver: copyResolver),
                    summary: ProWeeklyCopy.standingSchedule(
                        roleName: copyResolver.resolve(state.role.displayCopyToken),
                        remainingOutings: MobileCareerStore.expectedRemainingOutings(for: state),
                        resolver: copyResolver
                    )
                ) {
                    VStack(alignment: .leading, spacing: 5) {
                        Label(
                            Self.standingLabel(standing, resolver: copyResolver),
                            systemImage: standing == .clubSymbol ? "star.circle.fill" : "shield.lefthalf.filled"
                        )
                        .font(.headline)
                        .foregroundStyle(BaseballTheme.milestone)
                        Text(ProWeeklyCopy.standingSchedule(
                            roleName: copyResolver.resolve(state.role.displayCopyToken),
                            remainingOutings: MobileCareerStore.expectedRemainingOutings(for: state),
                            resolver: copyResolver
                        ))
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
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(copyResolver.resolve(.weeklyTitle)).font(.headline)
                Text(ProWeeklyCopy.routine(
                    arcName: Self.careerArcName(state.season, resolver: copyResolver),
                    roleName: copyResolver.resolve(state.role.displayCopyToken),
                    resolver: copyResolver
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
                    if let project = state.pitchLearningProject {
                        BaseballCard(
                            title: ProWeeklyCopy.pitchLearningTitle(
                                PitchCopy.localized(project.pitchType, resolver: copyResolver),
                                resolver: copyResolver
                            ),
                            tone: project.isCompleted ? .positive : .milestone
                        ) {
                            Text(verbatim: ProWeeklyCopy.pitchLearningProgress(
                                practiceCredits: project.practiceCredits,
                                qualityUses: project.qualityUses,
                                resolver: copyResolver
                            ))
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textSecondary)
                        }
                    }
                    Picker(copyResolver.resolve(.weeklyDevelopmentPitch), selection: Binding(
                        get: { career.selectedDevelopmentPitch },
                        set: { career.selectedDevelopmentPitch = $0 }
                    )) {
                        ForEach(breakingBalls, id: \.self) { pitch in
                            Text(verbatim: PitchCopy.localized(pitch, resolver: copyResolver)).tag(pitch)
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
                    Text(verbatim: ProWeeklyCopy.planUntil(
                        Self.localizedSegmentName(state.seasonSegment, resolver: copyResolver),
                        resolver: copyResolver
                    ))
                        .font(.subheadline.weight(.semibold))
                    Text(copyResolver.resolve(
                        career.selectedPlan == .recover && !MobileCareerStore.usesAgencyRules(state)
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
                        && !MobileCareerStore.usesAgencyRules(state))
            )
            .frame(minHeight: BaseballMetrics.minimumTapTarget)
            .accessibilityIdentifier("pro.advanceSegment")
        }
        .padding(.bottom, BaseballMetrics.gutter)
    }

    private struct PlanCard: View {
        let copy: PlanCopy
        let selected: Bool
        let recommendation: String?
        let onSelect: () -> Void

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: copy.symbol)
                    .font(.title3)
                    .foregroundStyle(selected ? BaseballTheme.selection : BaseballTheme.textSecondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Button(action: onSelect) {
                        HStack(spacing: 6) {
                            // localization-safe: resolved-copy
                            Text(verbatim: copy.title).font(.subheadline.weight(.bold))
                            if let recommendation {
                                // localization-safe: resolved-copy
                                Text(verbatim: recommendation)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(BaseballTheme.actionInk)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(BaseballTheme.action, in: Capsule())
                            }
                            Spacer()
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected ? BaseballTheme.selection : BaseballTheme.border)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("pro.plan.\(copy.plan.rawValue)")
                    GlossaryText(
                        text: copy.effect,
                        font: .footnote,
                        color: BaseballTheme.positive
                    )
                    // localization-safe: resolved-copy
                    Text(verbatim: copy.cost)
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: copy.risk)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(copy.risk.contains("높음") || copy.risk.contains("High") || copy.risk.contains("高") ? BaseballTheme.warning : BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
    }
}

private struct ProRoleRequestCard: View {
    let career: MobileCareerStore
    let state: ProCareerSnapshot
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        BaseballCard(title: copyResolver.resolve(.roleRequestTitle), tone: .milestone) {
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: copyResolver.resolve(.roleRequestBody))
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(CareerDisplayRules.roleRequestRoles, id: \.rawValue) { role in
                    let evaluation = CareerDisplayRules.roleRequestEvaluation(state: state, requested: role)
                    VStack(alignment: .leading, spacing: 4) {
                        Button {
                            career.requestRole(role)
                        } label: {
                            HStack {
                                Text(verbatim: copyResolver.resolve(role.displayCopyToken))
                                    .font(.subheadline.weight(.bold))
                                Spacer()
                                Text(verbatim: ProRoleRequestCopy.outlook(evaluation.outlook, resolver: copyResolver))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(outlookColor(evaluation.outlook))
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        GlossaryText(
                            text: ProRoleRequestCopy.condition(
                                role: role,
                                evaluation: evaluation,
                                state: state,
                                resolver: copyResolver
                            ),
                            font: .footnote,
                            color: BaseballTheme.textSecondary
                        )
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .background(BaseballTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                            .stroke(BaseballTheme.border, lineWidth: 1)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(ProRoleRequestCopy.accessibilityID(for: role))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pro.roleRequest")
    }

    private func outlookColor(_ outlook: ProRoleRequestOutlook) -> Color {
        switch outlook {
        case .likely: BaseballTheme.positive
        case .conditional: BaseballTheme.warning
        case .difficult: BaseballTheme.negative
        }
    }
}

private struct ProWeeklyGoalBoardCard: View {
    let state: ProCareerSnapshot
    let hidesHint: Bool
    let onOpenRecords: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    private var board: ProCareerGoalBoard {
        MobileCareerStore.goalBoard(state: state)
    }

    var body: some View {
        BaseballCard(title: copyResolver.resolve(.weeklyGoalBoardTitle), tone: .raised) {
            Button(action: onOpenRecords) {
                VStack(alignment: .leading, spacing: 6) {
                    if let nearest = board.nearest {
                        Text(verbatim: ProWeeklyCopy.goalBoardLine(nearest, resolver: copyResolver))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BaseballTheme.textPrimary)
                        if !hidesHint {
                            Text(verbatim: copyResolver.resolve(.weeklyGoalBoardHint))
                                .font(.caption)
                                .foregroundStyle(BaseballTheme.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text(verbatim: copyResolver.resolve(.weeklyGoalBoardComplete))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BaseballTheme.milestone)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(copyResolver.resolve(.weeklyGoalBoardHint))
        }
        .accessibilityIdentifier("pro.weekly.goalBoard")
    }
}
