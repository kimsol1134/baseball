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
    /// 직전 주의 변화. 요약 줄 대신 상태 타일 캡션으로 보여 준다(1.2.9 가독성 교정).
    var weekProgress: ProCareerPresentation.WeekProgressSummary? = nil
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
        /// 이득 칩에 들어갈 능력 이름들.
        let gains: [String]
        let forecast: ProWeekHealthForecast
        let gauge: (current: Int, required: Int)?
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
        func forecast(_ plan: ProWeekPlan) -> ProWeekHealthForecast {
            ProWeekHealthForecast.forecast(state: state, plan: plan)
        }
        func risk(_ plan: ProWeekPlan) -> String {
            ProWeeklyCopy.injuryRisk(forecast: forecast(plan), resolver: resolver)
        }
        func gains(_ plan: ProWeekPlan) -> [String] {
            ProWeeklyCopy.gainNames(plan, resolver: resolver)
        }
        func gauge(_ plan: ProWeekPlan) -> (current: Int, required: Int)? {
            ProWeeklyCopy.progressValues(plan, state: state)
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
                symbol: "flame",
                gains: gains(.developStuff),
                forecast: forecast(.developStuff),
                gauge: gauge(.developStuff)
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
                symbol: "hurricane",
                gains: gains(.developMovement),
                forecast: forecast(.developMovement),
                gauge: gauge(.developMovement)
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
                symbol: "scope",
                gains: gains(.refineCommand),
                forecast: forecast(.refineCommand),
                gauge: gauge(.refineCommand)
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
                symbol: "figure.run",
                gains: gains(.buildStamina),
                forecast: forecast(.buildStamina),
                gauge: gauge(.buildStamina)
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
                symbol: "bed.double",
                gains: gains(.recover),
                forecast: forecast(.recover),
                gauge: gauge(.recover)
            ),
            PlanCopy(
                plan: .earnTrust,
                title: resolver.resolve(state.level == .minor ? .weeklyTrustMinorTitle : reliefRole ? .weeklyTrustReliefTitle : .weeklyTrustStarterTitle),
                effect: resolver.resolve(.weeklyTrustEffect),
                cost: resolver.resolve(.weeklyTrustCost),
                risk: risk(.earnTrust),
                symbol: "person.2",
                gains: gains(.earnTrust),
                forecast: forecast(.earnTrust),
                gauge: gauge(.earnTrust)
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

            if let milestoneShare = CareerSharePresentation.recordMilestone(
                state: state,
                stamp: career.challengeStamp(),
                resolver: copyResolver
            ) {
                BaseballCard(
                    title: copyResolver.resolve(ShareUICopyKey.headlineRecord),
                    tone: .milestone
                ) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(verbatim: milestoneShare.detail)
                            .detailStyle()
                        Spacer(minLength: 0)
                        CareerShareButton(model: milestoneShare, style: .icon)
                    }
                }
                .accessibilityIdentifier("pro.weekly.recordShare")
            }

            ForEach(state.resolvedFollowUps ?? []) { followUp in
                let seenID = "pro.decision.followup.\(followUp.type.rawValue).v1"
                BaseballCard(
                    title: copyResolver.resolve(.decisionFollowUpCardTitle),
                    tone: .milestone
                ) {
                    HStack(alignment: .top, spacing: 8) {
                        // 결과 한 줄(제목) → 세부(접기). 제목을 세부 안에 다시 쓰지 않는다.
                        ProgressiveDisclosure(
                            contentID: seenID,
                            title: copyResolver.resolve(followUp.type.displayCopyToken),
                            summary: ProCareerPresentation.followUpSummary(followUp, resolver: copyResolver),
                            important: true
                        ) {
                            Label(
                                ProCareerPresentation.followUpSummary(followUp, resolver: copyResolver),
                                systemImage: Self.followUpSymbol(followUp.type)
                            )
                            .detailStyle()
                        }
                        if let qsShare = CareerSharePresentation.recordQS(
                            followUp: followUp,
                            state: state,
                            stamp: career.challengeStamp(),
                            resolver: copyResolver
                        ) {
                            CareerShareButton(model: qsShare, style: .icon)
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

            // 직전 주의 변화는 요약 줄 대신 타일 캡션으로 한 번만 보여 준다.
            HStack(alignment: .top, spacing: 10) {
                StatTile(
                    label: copyResolver.resolve(.weeklyFatigue),
                    value: "\(state.fatigue)",
                    caption: weekProgress.map { ProWeeklyCopy.deltaCaption($0.fatigueDelta, resolver: copyResolver) },
                    tone: state.fatigue >= 70 ? BaseballTheme.warning : BaseballTheme.textPrimary
                )
                StatTile(
                    label: copyResolver.resolve(.weeklyManagerTrust),
                    value: "\(state.managerTrust)",
                    caption: weekProgress.map { ProWeeklyCopy.deltaCaption($0.managerTrustDelta, resolver: copyResolver) },
                    tone: state.managerTrust >= 60 ? BaseballTheme.positive : BaseballTheme.textPrimary
                )
                StatTile(
                    label: copyResolver.resolve(.weeklyRole),
                    value: copyResolver.resolve(state.role.displayCopyToken)
                )
            }

            if let climate = CareerDisplayRules.liveClimate(for: state) {
                let key: ProUICopyKey = switch climate {
                case .hot: .weeklyClimateHot
                case .even: .weeklyClimateEven
                case .slump: .weeklyClimateSlump
                case .adapted: .weeklyClimateAdapted
                }
                Text(copyResolver.resolve(key))
                    .detailStyle()
                    .fontWeight(climate == .slump || climate == .adapted ? .semibold : .regular)
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

            // 청사진: 눈썹 카드 없이 접기 하나로. 제목이 눈썹과 접기에 두 번 찍히던 것을 지웠다.
            let identity = CareerDisplayRules.pitcherIdentity(for: state.pitcher)
            ProgressiveDisclosure(
                contentID: "pro.weekly.blueprint.v1",
                title: ProWeeklyCopy.blueprint(
                    ProCareerPresentation.buildLabel(identity, resolver: copyResolver),
                    resolver: copyResolver
                ),
                summary: ProCareerPresentation.buildStrength(identity, resolver: copyResolver)
            ) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(ProCareerPresentation.buildStrength(identity, resolver: copyResolver))
                        .detailStyle()
                    Text(ProCareerPresentation.buildTradeoff(identity, resolver: copyResolver))
                        .detailStyle()
                    if let rolePreference = state.rolePreference {
                        Label(
                            ProWeeklyCopy.rolePromise(
                                copyResolver.resolve(rolePreference.displayCopyToken),
                                resolver: copyResolver
                            ),
                            systemImage: "checkmark.seal.fill"
                        )
                        .detailStyle()
                    }
                }
            }

            let standing = MobileCareerStore.careerStanding(for: state)
            BaseballCard(title: copyResolver.resolve(.weeklyStandingTitle), tone: .milestone) {
                // 접기 제목이 곧 자리 이름이다. 예전에는 세부 안에 방패 아이콘과 같은 이름을
                // 한 번 더 그려서 작은 화면에서 제목이 두 번 보였다.
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
                        GlossaryText(
                            text: ProWeeklyCopy.standingSchedule(
                                roleName: copyResolver.resolve(state.role.displayCopyToken),
                                remainingOutings: MobileCareerStore.expectedRemainingOutings(for: state),
                                resolver: copyResolver
                            ),
                            font: BaseballType.detail
                        )
                        if state.age >= 33 {
                            Text(copyResolver.resolve(.weeklyStandingVeteran))
                                .detailStyle()
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
                    .font(BaseballType.annotation.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textSecondary)
            }

            let recommendation = Self.recommendation(for: state, resolver: copyResolver)

            if career.selectedPlan == nil {
                Label(copyResolver.resolve(.weeklyChoosePlan), systemImage: "hand.tap")
                    .detailStyle()
                    .accessibilityIdentifier("pro.plan.required")
            }

            ForEach(Self.plans(for: state, resolver: copyResolver), id: \.plan) { copy in
                PlanCard(
                    copy: copy,
                    selected: career.selectedPlan == copy.plan,
                    currentFatigue: state.fatigue,
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
                        VStack(alignment: .leading, spacing: 4) {
                            Label(
                                ProWeeklyCopy.pitchLearningTitle(
                                    PitchCopy.localized(project.pitchType, resolver: copyResolver),
                                    resolver: copyResolver
                                ),
                                systemImage: project.isCompleted ? "checkmark.seal.fill" : "baseball"
                            )
                            .proseLeadStyle(project.isCompleted ? BaseballTheme.positive : BaseballTheme.textPrimary)
                            Text(verbatim: ProWeeklyCopy.pitchLearningProgress(
                                practiceCredits: project.practiceCredits,
                                qualityUses: project.qualityUses,
                                resolver: copyResolver
                            ))
                            .detailStyle()
                            .monospacedDigit()
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
                        .detailStyle()
                        .multilineTextAlignment(.leading)
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
        let currentFatigue: Int
        let recommendation: String?
        let onSelect: () -> Void
        @Environment(\.gameCopyResolver) private var copyResolver

        private var riskTone: EffectChip.Tone {
            switch copy.forecast.band {
            case .low: .neutral
            case .caution: .cost
            case .high: .risk
            }
        }

        /// 훈련·등판이 올리는 원피로. 다음 주 피로 타일에 찍히는 값과 같은 기준이다.
        private var fatigueDelta: Int {
            copy.forecast.expectedRawFatigue - currentFatigue
        }

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: copy.symbol)
                    .font(.title3)
                    .foregroundStyle(selected ? BaseballTheme.selection : BaseballTheme.textSecondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 8) {
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

                    // 효과 문장 대신 칩: 이득(능력 ▲) · 비용(피로 ±N) · 위험(부상 낮음/주의/높음).
                    EffectChipFlow {
                        ForEach(copy.gains, id: \.self) { name in
                            EffectChip(
                                text: ProWeeklyCopy.gainChip(name, resolver: copyResolver),
                                tone: .gain
                            )
                        }
                        EffectChip(
                            text: ProWeeklyCopy.fatigueChip(delta: fatigueDelta, resolver: copyResolver),
                            tone: fatigueDelta > 0 ? .cost : (fatigueDelta < 0 ? .gain : .neutral)
                        )
                        // 체력이 덜어 주는 몫은 중립 칩으로 따로 — 비용과 섞이면 강훈련이 초록으로 보인다.
                        if let offset = ProWeeklyCopy.staminaOffsetChip(
                            rawFatigue: copy.forecast.expectedRawFatigue,
                            effectiveFatigue: copy.forecast.expectedEffectiveFatigue,
                            resolver: copyResolver
                        ) {
                            EffectChip(text: offset, tone: .neutral)
                        }
                        EffectChip(
                            text: ProWeeklyCopy.injuryChip(copy.forecast.band, resolver: copyResolver),
                            tone: riskTone,
                            systemImage: copy.forecast.band == .high ? "exclamationmark.triangle.fill" : nil
                        )
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text(verbatim: "\(copy.effect) \(copy.risk)"))

                    if let gauge = copy.gauge {
                        HStack(spacing: 8) {
                            ProgressView(value: Double(gauge.current), total: Double(gauge.required))
                                .tint(BaseballTheme.positive)
                            // localization-safe: numeric
                            Text(verbatim: "\(gauge.current)/\(gauge.required)")
                                .font(BaseballType.annotation.monospacedDigit())
                                .foregroundStyle(BaseballTheme.textSecondary)
                        }
                    }

                    // 긴 설명·주의 문장은 접는다. 선택지·칩·게이지는 접지 않는다.
                    ProgressiveDisclosure(
                        contentID: "pro.week.option.\(copy.plan.rawValue)",
                        title: copyResolver.resolve(.weeklyOptionDetailTitle),
                        summary: copy.cost
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            GlossaryText(text: copy.effect, font: BaseballType.detail)
                            Text(verbatim: copy.cost)
                                .detailStyle()
                            Text(verbatim: copy.risk)
                                .detailStyle()
                                .monospacedDigit()
                        }
                    }
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
                GlossaryText(
                    text: copyResolver.resolve(.roleRequestBody),
                    font: BaseballType.detail
                )
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
                            font: BaseballType.detail
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

/// 다음 목표 한 줄. 눈썹 카드 대신 과녁 아이콘 + 결과 한 줄로 선다(눈썹 수 줄이기).
private struct ProWeeklyGoalBoardCard: View {
    let state: ProCareerSnapshot
    let hidesHint: Bool
    let onOpenRecords: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    private var board: ProCareerGoalBoard {
        MobileCareerStore.goalBoard(state: state)
    }

    var body: some View {
        Button(action: onOpenRecords) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "target")
                    .font(.title3)
                    .foregroundStyle(BaseballTheme.milestone)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    if let nearest = board.nearest {
                        Text(verbatim: ProWeeklyCopy.goalBoardLine(nearest, resolver: copyResolver))
                            .proseLeadStyle()
                        if !hidesHint {
                            Text(verbatim: copyResolver.resolve(.weeklyGoalBoardHint))
                                .detailStyle(BaseballTheme.textTertiary)
                        }
                    } else {
                        Text(verbatim: copyResolver.resolve(.weeklyGoalBoardComplete))
                            .proseLeadStyle(BaseballTheme.milestone)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(copyResolver.resolve(.weeklyGoalBoardHint))
        .accessibilityIdentifier("pro.weekly.goalBoard")
    }
}
