import SwiftUI
import SimulationCore

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
        let current = state.developmentProgress?.value(for: plan) ?? 0
        let required = ProCareerEngine.developmentTicksRequired(
            for: plan,
            pitcher: state.pitcher,
            proRulesVersion: state.proRulesVersion
        ) ?? 2
        return resolver.resolve(
            .weeklyProgress,
            arguments: [.integer(current), .integer(required)]
        )
    }

    /// 구위와 변화구를 분리해 이번 선수가 어떤 무기를 완성하는지 선택하게 한다.
    /// 20시즌 내내 같은 카드 제목을 읽는 대신 지금 선수의 과제가 먼저 보인다.
    private static func plans(for state: ProCareerSnapshot, resolver: GameCopyResolver) -> [PlanCopy] {
        let reliefRole = state.role != .starter
        let veteran = state.season >= 9
        func risk(_ plan: ProWeekPlan) -> String {
            let forecast = ProWeekHealthForecast.forecast(state: state, plan: plan)
            let bandKey: ProUICopyKey = switch forecast.band {
            case .low: .weeklyInjuryRiskLow
            case .caution: .weeklyInjuryRiskCaution
            case .high: .weeklyInjuryRiskHigh
            }
            return resolver.resolve(.weeklyInjuryRisk, arguments: [
                .userText(resolver.resolve(bandKey)),
                .integer(forecast.expectedEffectiveFatigue),
            ])
        }
        return [
            PlanCopy(
                plan: .developStuff,
                title: resolver.resolve(reliefRole ? .weeklyDevelopStuffRelief : veteran ? .weeklyDevelopStuffVeteran : .weeklyDevelopStuffStarter),
                effect: resolver.resolve(.weeklyDevelopStuffEffect, arguments: [
                    .userText(progressText(.developStuff, state: state, resolver: resolver)),
                ]),
                cost: resolver.resolve(.weeklyDevelopStuffCost),
                risk: risk(.developStuff),
                symbol: "flame"
            ),
            PlanCopy(
                plan: .developMovement,
                title: resolver.resolve(.weeklyDevelopMovementTitle),
                effect: resolver.resolve(.weeklyDevelopMovementEffect, arguments: [
                    .userText(progressText(.developMovement, state: state, resolver: resolver)),
                ]),
                cost: resolver.resolve(.weeklyDevelopMovementCost),
                risk: risk(.developMovement),
                symbol: "hurricane"
            ),
            PlanCopy(
                plan: .refineCommand,
                title: resolver.resolve(.weeklyCommandTitle),
                effect: resolver.resolve(.weeklyCommandEffect, arguments: [
                    .userText(progressText(.refineCommand, state: state, resolver: resolver)),
                ]),
                cost: resolver.resolve(.weeklyCommandCost),
                risk: risk(.refineCommand),
                symbol: "scope"
            ),
            PlanCopy(
                plan: .buildStamina,
                title: resolver.resolve(reliefRole ? .weeklyStaminaReliefTitle : .weeklyStaminaStarterTitle),
                effect: resolver.resolve(.weeklyStaminaEffect, arguments: [
                    .userText(progressText(.buildStamina, state: state, resolver: resolver)),
                ]),
                cost: resolver.resolve(.weeklyStaminaCost),
                risk: risk(.buildStamina),
                symbol: "figure.run"
            ),
            PlanCopy(
                plan: .recover,
                title: resolver.resolve(veteran ? .weeklyRecoveryVeteranTitle : .weeklyRecoveryTitle),
                effect: resolver.resolve(
                    ProCareerEngine.usesAgencyRules(state)
                        ? .weeklyRecoveryAgencyEffect
                        : .weeklyRecoveryEffect
                ),
                cost: resolver.resolve(
                    ProCareerEngine.usesAgencyRules(state)
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

            let identity = PitcherBuildRules.identity(for: state.pitcher)
            BaseballCard(title: copyResolver.resolve(
                .weeklyBlueprint,
                arguments: [.userText(ProCareerPresentation.buildLabel(identity, resolver: copyResolver))]
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
            }

            let standing = ProCareerEngine.careerStanding(for: state)
            BaseballCard(title: copyResolver.resolve(.weeklyStandingTitle), tone: .milestone) {
                ProgressiveDisclosure(
                    contentID: "pro.weekly.standing.v1",
                    title: Self.standingLabel(standing, resolver: copyResolver),
                    summary: copyResolver.resolve(.weeklyStandingSchedule, arguments: [
                        .userText(copyResolver.resolve(state.role.displayCopyToken)),
                        .integer(ProCareerEngine.expectedRemainingOutings(for: state)),
                    ])
                ) {
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
                    if let project = state.pitchLearningProject {
                        BaseballCard(
                            title: copyResolver.resolve(
                                AppCopyKey.trainingPitchLearningTitle,
                                arguments: [.userText(PitchCopy.localized(project.pitchType, resolver: copyResolver))]
                            ),
                            tone: project.isCompleted ? .positive : .milestone
                        ) {
                            GameCopyText(
                                AppCopyKey.trainingPitchLearningProgress,
                                arguments: [
                                    .integer(project.practiceCredits),
                                    .integer(PitchLearningRules.maximumPracticeCredits),
                                    .integer(project.qualityUses),
                                    .integer(PitchLearningRules.requiredQualityUses),
                                ]
                            )
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textSecondary)
                        }
                    }
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
                        career.selectedPlan == .recover && !ProCareerEngine.usesAgencyRules(state)
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
                        && !ProCareerEngine.usesAgencyRules(state))
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
                        Text(copy.risk)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(copy.risk.contains("높음") || copy.risk.contains("High") || copy.risk.contains("高") ? BaseballTheme.warning : BaseballTheme.textSecondary)
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
