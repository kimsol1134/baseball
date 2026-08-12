import SwiftUI
import SimulationCore

struct CareerFlowView: View {
    let career: MobileCareerStore
    /// 은퇴 뒤 새 선수로 시작한다. 프로 저장본을 지우고 고교 탭으로 돌려보낸다.
    var onStartNewPlayer: () -> Void = {}
    var retiresIntoSignatureLegacy = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView { CareerSummary(career: career) } detail: { decision }
            } else {
                decision
            }
        }
        .navigationTitle("이번 주")
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
                            ResultBanner(summary: summary, cue: career.feedbackCue)
                                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        }

                        switch state.phase {
                        case .weeklyPlan:
                            WeeklyPlanView(career: career, state: state)
                        case .seasonDecision:
                            if let pending = state.pendingDecision {
                                ProSeasonDecisionView(career: career, decision: pending)
                            } else {
                                ContentUnavailableView("시즌 결정을 불러올 수 없습니다", systemImage: "exclamationmark.triangle")
                            }
                        case .importantGame:
                            ImportantGameIntro(state: state, onStart: career.beginImportantGame)
                        case .seasonReview:
                            ActionCard(
                                title: "시즌 종료",
                                copy: "올해 경기 기록과 수상을 통산 기록에 더합니다.",
                                button: "시즌 기록 확인",
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
                            ContentUnavailableView("이번 일정은 끝났습니다", systemImage: "checkmark.circle")
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

    var body: some View {
        List {
            if let state = career.state {
                Section("선수") {
                    LabeledContent("이름", value: state.identity.name)
                    LabeledContent("구단", value: state.team.name)
                    LabeledContent("레벨", value: state.level == .major ? "1군" : "2군")
                    LabeledContent("역할", value: MobileCareerStore.roleName(state.role))
                }
                Section("능력") {
                    AbilityGaugeView(label: "구위", value: state.pitcher.stuff)
                    AbilityGaugeView(label: "제구", value: state.pitcher.command)
                    AbilityGaugeView(label: "변화구", value: state.pitcher.movement)
                    AbilityGaugeView(label: "체력", value: state.pitcher.stamina)
                }
                Section("최근 주요 기록") {
                    ForEach(Array(state.milestones.suffix(6).reversed()), id: \.self) { milestone in
                        Label(milestone, systemImage: milestone == state.milestones.last ? "star.fill" : "circle.fill")
                            .foregroundStyle(milestone == state.milestones.last ? BaseballTheme.milestone : BaseballTheme.textSecondary)
                    }
                }
                if let decisions = state.decisionHistory, !decisions.isEmpty {
                    Section("시즌 선택 기록") {
                        ForEach(Array(decisions.suffix(7).reversed())) { decision in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(decision.choiceTitle)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(decision.season)시즌 \(decision.week)주차 · \(decision.effect.summary)")
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
        .navigationTitle("커리어")
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
                eyebrow: "\(decision.season)시즌 · \(decision.week)주차 결정",
                title: decisionTitle,
                accent: BaseballTheme.milestone
            )

            Text(decision.detail)
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(decision.choices) { choice in
                Button { pendingChoice = choice } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(choice.title)
                                .font(.headline)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right.circle.fill")
                                .foregroundStyle(BaseballTheme.selection)
                        }
                        Text(choice.detail)
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Label(choice.effect.summary, systemImage: "plusminus.circle")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(BaseballTheme.information)
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
                .accessibilityLabel(Self.accessibilityLabel(for: choice))
                .accessibilityHint("두 번 탭하면 되돌릴 수 없는 선택을 확인합니다.")
                .accessibilityIdentifier("pro.seasonDecision.choice.\(choice.id)")
            }

            Label("확인한 뒤에는 되돌릴 수 없습니다. 자동 진행도 이 결정을 건너뛰지 않습니다.", systemImage: "exclamationmark.circle")
                .font(.caption)
                .foregroundStyle(BaseballTheme.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("pro.seasonDecision")
        .confirmationDialog(
            pendingChoice?.title ?? "선택 확인",
            isPresented: Binding(
                get: { pendingChoice != nil },
                set: { if !$0 { pendingChoice = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("이 선택으로 결정") {
                guard let pendingChoice else { return }
                career.applySeasonDecision(decisionID: decision.id, choiceID: pendingChoice.id)
                self.pendingChoice = nil
            }
            .accessibilityIdentifier("pro.seasonDecision.confirm")
            Button("취소", role: .cancel) { pendingChoice = nil }
        } message: {
            if let pendingChoice {
                Text("\(pendingChoice.detail) 효과: \(pendingChoice.effect.summary). 이 선택은 되돌릴 수 없습니다.")
            }
        }
    }

    static func accessibilityLabel(for choice: ProSeasonDecisionChoice) -> String {
        "\(choice.title). \(choice.detail). 효과: \(choice.effect.summary)"
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

    private static func careerArcName(_ season: Int) -> String {
        switch season {
        case ...3: "루키 경쟁기"
        case ...8: "전성기"
        default: "베테랑 승부"
        }
    }

    private static func progressText(_ plan: ProWeekPlan, state: ProCareerSnapshot) -> String {
        let current = state.developmentProgress?.value(for: plan) ?? 0
        return "현재 \(current)/2 · 두 번 채우면 능력 +1"
    }

    /// 구위와 변화구를 분리해 이번 선수가 어떤 무기를 완성하는지 선택하게 한다.
    /// 20시즌 내내 같은 카드 제목을 읽는 대신 지금 선수의 과제가 먼저 보인다.
    private static func plans(for state: ProCareerSnapshot) -> [PlanCopy] {
        let reliefRole = state.role != .starter
        let veteran = state.season >= 9
        return [
            PlanCopy(
                plan: .developStuff,
                title: reliefRole ? "한 타자 강속구" : (veteran ? "포심 위력 다듬기" : "강속구 불펜"),
                effect: "구위·포심 구속·헛스윙 성장 · \(progressText(.developStuff, state: state))",
                cost: "폭발력이 큰 대신 피로가 가장 크게 쌓입니다",
                symbol: "flame"
            ),
            PlanCopy(
                plan: .developMovement,
                title: "결정구 완성",
                effect: "고른 변화구의 움직임·헛스윙 성장 · \(progressText(.developMovement, state: state))",
                cost: "집중할 구종을 직접 골라야 합니다",
                symbol: "hurricane"
            ),
            PlanCopy(plan: .refineCommand, title: "코스 제구 훈련", effect: "제구·전 구종 코스 성장 · \(progressText(.refineCommand, state: state))", cost: "성장은 안정적이고 피로 부담은 작습니다", symbol: "scope"),
            PlanCopy(
                plan: .buildStamina,
                title: reliefRole ? "연투 버티기" : "긴 이닝 루틴",
                effect: "후반 체감 피로가 줄어듭니다 · \(progressText(.buildStamina, state: state))",
                cost: "초반 투구 위력은 바로 오르지 않습니다",
                symbol: "figure.run"
            ),
            PlanCopy(
                plan: .recover,
                title: veteran ? "베테랑 회복 루틴" : "회복",
                effect: "피로가 줄고 부상 위험이 낮아집니다",
                cost: "능력이 오르지 않습니다",
                symbol: "bed.double"
            ),
            PlanCopy(
                plan: .earnTrust,
                title: state.level == .minor ? "콜업 경쟁 집중" : (reliefRole ? "필승조 신뢰 쌓기" : "로테이션 신뢰 쌓기"),
                effect: "감독의 믿음이 오릅니다",
                cost: "능력이 오르지 않습니다",
                symbol: "person.2"
            ),
        ]
    }

    private static func recommendation(for state: ProCareerSnapshot) -> (plan: ProWeekPlan, reason: String) {
        if state.fatigue >= 68 { return (.recover, "부상 예방") }
        if state.level == .minor, state.managerTrust < 60 { return (.earnTrust, "콜업 우선") }
        let identity = PitcherBuildRules.identity(for: state.pitcher)
        return switch identity {
        case .power: (.developStuff, "강속구형 강화")
        case .command: (.refineCommand, "제구형 강화")
        case .movement: (.developMovement, "변화구형 강화")
        case .stamina: (.buildStamina, "이닝형 강화")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            HStack(spacing: 10) {
                Metric(title: "피로", value: "\(state.fatigue)", tone: state.fatigue >= 70 ? .warning : .standard)
                Metric(title: "감독의 믿음", value: "\(state.managerTrust)", tone: state.managerTrust >= 60 ? .positive : .standard)
                Metric(title: "역할", value: MobileCareerStore.roleName(state.role))
            }

            let identity = PitcherBuildRules.identity(for: state.pitcher)
            BaseballCard(title: "투구 청사진 · \(identity.label)", tone: .raised) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(identity.strength).font(.footnote)
                    Text(identity.tradeoff)
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.warning)
                    if let rolePreference = state.rolePreference {
                        Label(
                            "남은 시즌 역할 약속 · \(MobileCareerStore.roleName(rolePreference))",
                            systemImage: "checkmark.seal.fill"
                        )
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BaseballTheme.positive)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("이번 주에 할 일").font(.headline)
                Text("\(Self.careerArcName(state.season)) · \(MobileCareerStore.roleName(state.role)) 루틴")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textSecondary)
            }

            let recommendation = Self.recommendation(for: state)

            ForEach(Self.plans(for: state), id: \.plan) { copy in
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
                    Picker("집중할 결정구", selection: Binding(
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

            PrimaryPill(title: "1주 진행", identifier: "pro.advanceWeek", action: career.advanceWeek)

            Button(action: career.advanceSegment) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(copyResolver.resolve(
                        AppCopyKey.proWeeklyPlanUntil,
                        arguments: [
                            .userText(Self.localizedSegmentName(state.seasonSegment, resolver: copyResolver)),
                        ]
                    ))
                        .font(.subheadline.weight(.semibold))
                    Text("승부처 경기·역할 변화·부상이 생기면 그 자리에서 멈춥니다.")
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
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
                            Text(copy.title).font(.subheadline.weight(.bold))
                            if let recommendation {
                                Text(recommendation)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(BaseballTheme.actionInk)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(BaseballTheme.action, in: Capsule())
                            }
                        }
                        Text(copy.effect).font(.footnote).foregroundStyle(BaseballTheme.positive)
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
        }
    }
}

/// 승부 시작 전 장면. 상대와 상황을 먼저 보여 주고 나서 투구 화면으로 들어간다.
private struct ImportantGameIntro: View {
    let state: ProCareerSnapshot
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(
                art: state.level == .major ? .proStadiumTunnel : .stadiumNight,
                eyebrow: "IMPORTANT MOMENT · \(state.season)시즌 \(state.week)주차",
                title: state.level == .major
                    ? "1군에서 자리를 정할 승부"
                    : state.managerTrust < 55 ? "다음 등판 기회를 따낼 경기" : "선발·불펜 역할을 결정할 경기",
                accent: BaseballTheme.milestone
            )

            if let rival = state.currentRival {
                BaseballCard(title: "상대", tone: .milestone) {
                    HStack(alignment: .top, spacing: 10) {
                        // 고교 라이벌 카드와 같은 문법 — 상대에게 얼굴이 있어야 승부다.
                        PortraitView(seed: rival.name, role: .rival, size: 46)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(rival.name) · \(rival.teamName)").font(.headline)
                            Text(rival.archetype).font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                            Text(rival.profile).font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(rival.record).font(.footnote.monospacedDigit()).foregroundStyle(BaseballTheme.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            BaseballCard(title: "내 상태") {
                HStack(spacing: 10) {
                    Metric(title: "피로", value: "\(state.fatigue)", tone: state.fatigue >= 70 ? .warning : .standard)
                    Metric(title: "감독의 믿음", value: "\(state.managerTrust)")
                    Metric(title: "포수와의 호흡", value: "\(state.catcherTrust)")
                }
            }

            Text("한 구씩 직접 던집니다. 구종·코스·노림·힘 배분을 고르면 결과가 그때그때 갈립니다.")
                .font(.footnote)
                .foregroundStyle(BaseballTheme.textSecondary)

            PrimaryPill(title: "마운드에 오르기", identifier: "pro.game.start", action: onStart)
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
                eyebrow: "\(state.season)시즌 종료 · \(state.age)세",
                title: "다음 시즌을 어떻게 맞을지 정하세요"
            )

            HStack(spacing: 10) {
                Metric(title: "1군 등록", value: "\(service)년", tone: freeAgencyReady ? .positive : .standard)
                Metric(title: "군 복무", value: state.militaryCompleted ? "마침" : "미필")
                Metric(title: "통산", value: "\(state.careerStats.count)시즌")
            }

            OffseasonChoice(
                title: decisionLabel(.continueCareer),
                detail: "\(state.team.name)에서 선발·불펜 자리 경쟁을 이어 갑니다.",
                symbol: "arrow.forward.circle",
                enabled: true,
                note: nil
            ) { pending = .continueCareer }

            OffseasonChoice(
                title: decisionLabel(.militaryService),
                detail: "두 시즌을 비우고 돌아옵니다. 나이가 두 살 늘지만 이후 시즌이 온전해집니다.",
                symbol: "shield",
                enabled: !state.militaryCompleted,
                note: state.militaryCompleted ? "이미 마쳤습니다." : nil
            ) { pending = .militaryService }

            OffseasonChoice(
                title: decisionLabel(.freeAgency),
                detail: "다른 구단과 계약해 새 팀에서 다시 시작합니다.",
                symbol: "arrow.triangle.branch",
                enabled: freeAgencyReady,
                note: freeAgencyReady ? nil : "1군 등록 6년이 필요합니다. 지금 \(service)년."
            ) { pending = .freeAgency }

            OffseasonChoice(
                title: decisionLabel(.retire),
                detail: "여기서 커리어를 마칩니다. 통산 기록과 명예의 전당 점수가 확정됩니다.",
                symbol: "flag.checkered",
                enabled: true,
                note: "되돌릴 수 없습니다."
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
            Button("취소") { pending = nil }
        } message: {
            Text(confirmMessage)
        }
    }

    private var confirmTitle: String {
        switch pending {
        case .retire: "정말 은퇴하시겠습니까?"
        case .militaryService: "군 복무를 다녀오시겠습니까?"
        case .freeAgency: "FA를 신청하시겠습니까?"
        default: "다음 시즌을 시작하시겠습니까?"
        }
    }

    private var confirmAction: String {
        switch pending {
        case .retire: "은퇴한다"
        case .militaryService: "다녀온다"
        case .freeAgency: "신청한다"
        default: "시작한다"
        }
    }

    private var confirmMessage: String {
        switch pending {
        case .retire: "통산 \(state.careerStats.count)시즌으로 커리어가 끝납니다. 되돌릴 수 없습니다."
        case .militaryService: "두 시즌을 비웁니다. 돌아오면 \(state.age + 2)세입니다."
        case .freeAgency: "구단이 바뀝니다. 지금 팀에서 쌓은 감독의 믿음은 새 팀에서 다시 쌓아야 합니다."
        default: "\(state.team.name)에서 \(state.season + 1)시즌을 시작합니다."
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
                    Text(title).font(.subheadline.weight(.bold))
                    Text(detail).font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let note {
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

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(
                art: .retirement,
                eyebrow: "\(state.age)세 · 통산 \(state.careerStats.count)시즌",
                title: "마지막 시즌이 끝났습니다",
                accent: BaseballTheme.milestone
            )

            BaseballCard(title: "여기까지", tone: .milestone) {
                Text("더 이상 다음 시즌은 없습니다. 통산 기록을 확정하고 유니폼을 벗습니다.")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            CareerTotals(state: state)

            PrimaryPill(title: "은퇴하기", identifier: "pro.retire") { confirming = true }
        }
        .confirmationDialog("은퇴하시겠습니까?", isPresented: $confirming, titleVisibility: .visible) {
            Button("은퇴한다", role: .destructive) { career.chooseOffseason(.retire) }
                .accessibilityIdentifier("pro.retire.confirm")
            Button("취소") {}
        } message: {
            Text("통산 \(state.careerStats.count)시즌으로 커리어가 끝납니다.")
        }
    }
}

/// 은퇴한 뒤. 커리어의 마지막 화면이라 회고와 통산 기록만 남는다.
private struct RetiredView: View {
    let state: ProCareerSnapshot
    let retiresIntoSignatureLegacy: Bool
    let onStartNewPlayer: () -> Void

    @State private var confirming = false

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(
                art: .retirement,
                eyebrow: "은퇴",
                title: "\(state.identity.name)의 커리어가 끝났습니다",
                accent: BaseballTheme.milestone
            )

            // 커리어를 끝낸 그 얼굴. 세 결말(미지명·지명·은퇴) 중 여기만 얼굴이 없었다.
            HStack(spacing: 12) {
                PortraitView(seed: state.identity.name, role: .player, size: 56, playerStage: .pro)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.identity.name).font(.headline)
                    Text("\(state.team.name) · \(MobileCareerStore.retirementDurationText(state))")
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
                Spacer(minLength: 0)
            }

            if let score = state.hallOfFameScore {
                BaseballCard(title: "명예의 전당 점수", tone: .milestone) {
                    Text("\(score)").font(BaseballType.heroNumeral).foregroundStyle(BaseballTheme.milestone)
                }
            }

            CareerTotals(state: state)

            // 이 커리어가 다음 회차에 남기는 것. 프로의 시간이 환생 루프와 무관하면
            // 은퇴가 끝이 되지만, 야구혼으로 이어지면 은퇴가 다음 회차의 시작이 된다.
            BaseballCard(
                title: retiresIntoSignatureLegacy
                    ? "프로 기록을 대표 유산으로 남기기" : "프로 기록을 계승 포인트로 남기기",
                tone: .milestone
            ) {
                Text(retiresIntoSignatureLegacy
                     ? "고교 시절부터 은퇴까지 직접 키운 능력과 통산 기록으로 대표 유산 세 가지를 찾습니다. 그중 하나를 다음 선수에게 직접 남길 수 있습니다."
                     : "고교를 건너뛰고 시작한 프로 기록은 계승 포인트로 남습니다. 진행 중인 고교 선수나 다음 고교 선수의 계승 상점에서 사용할 수 있습니다.")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("계승 포인트 +\(HighSchoolCareerStore.proSoulBonus(for: state))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BaseballTheme.milestone)
            }

            if !state.awards.isEmpty {
                BaseballCard(title: "수상", tone: .milestone) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(state.awards, id: \.self) { award in
                            Label(award, systemImage: "trophy.fill").foregroundStyle(BaseballTheme.milestone)
                        }
                    }
                }
            }

            BaseballCard(title: "회고") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(state.news.prefix(6).enumerated()), id: \.offset) { _, line in
                        Text(line).font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            PrimaryPill(
                title: retiresIntoSignatureLegacy
                    ? "유산을 남기고 다음 선수 준비" : "계승 포인트를 남기고 고교로 돌아가기",
                identifier: "pro.newPlayer"
            ) { confirming = true }
            Text(retiresIntoSignatureLegacy
                 ? "프로 기록을 안전하게 저장한 뒤, 다음 선수에게 남길 대표 유산 하나를 고릅니다."
                 : "프로 기록을 안전하게 저장한 뒤 기존 고교 진행으로 돌아갑니다.")
                .font(.caption)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .confirmationDialog(
            retiresIntoSignatureLegacy ? "이 선수의 유산을 남길까요?" : "프로 기록을 계승 포인트로 남길까요?",
            isPresented: $confirming,
            titleVisibility: .visible
        ) {
            Button(
                retiresIntoSignatureLegacy ? "프로 기록을 유산으로 남기기" : "계승 포인트를 남기고 돌아가기",
                action: onStartNewPlayer
            )
                .accessibilityIdentifier("pro.newPlayer.confirm")
            Button("취소") {}
        } message: {
            Text(retiresIntoSignatureLegacy
                 ? "\(state.identity.name)의 프로 커리어를 닫고, 대표 유산을 고르는 화면으로 이동합니다."
                 : "\(state.identity.name)의 프로 커리어를 닫고 고교 화면으로 돌아갑니다.")
        }
    }
}

private struct CareerTotals: View {
    let state: ProCareerSnapshot

    private var totals: (games: Int, outs: Int, strikeouts: Int, wins: Int, losses: Int, saves: Int, runs: Int) {
        state.careerStats.reduce((0, 0, 0, 0, 0, 0, 0)) {
            ($0.0 + $1.games, $0.1 + $1.inningsOuts, $0.2 + $1.strikeouts,
             $0.3 + $1.wins, $0.4 + $1.losses, $0.5 + $1.saves, $0.6 + $1.runsAllowed)
        }
    }

    var body: some View {
        BaseballCard(title: "통산") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Metric(title: "경기", value: "\(totals.games)")
                    Metric(title: "이닝", value: "\(totals.outs / 3)\(totals.outs % 3 == 0 ? "" : ".\(totals.outs % 3)")")
                    Metric(title: "탈삼진", value: "\(totals.strikeouts)", tone: .positive)
                }
                HStack(spacing: 10) {
                    Metric(title: "승-패-세이브", value: GameLineFormat.record(wins: totals.wins, losses: totals.losses, saves: totals.saves))
                    Metric(title: "9이닝당 실점", value: GameLineFormat.runsPerNine(outs: totals.outs, runs: totals.runs))
                    Metric(title: "시즌", value: "\(state.careerStats.count)")
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
                Text(copy).font(.subheadline)
                PrimaryPill(title: button, action: action)
            }
        }
    }
}
