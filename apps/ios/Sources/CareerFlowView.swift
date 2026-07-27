import SwiftUI
import SimulationCore

struct CareerFlowView: View {
    let career: MobileCareerStore
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
                PitchView(session: session, onFinish: career.finishImportantGame)
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
                            ActionCard(
                                title: "오프시즌",
                                copy: "현재 구단에 남아 선발·불펜 자리 경쟁을 계속합니다.",
                                button: "현재 구단에 남기",
                                action: career.continueCareer
                            )
                        default:
                            ContentUnavailableView("이번 일정은 끝났습니다", systemImage: "checkmark.circle")
                        }
                    }
                    .padding(BaseballMetrics.gutter)
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
            }
        }
        .scrollContentBackground(.hidden)
        .background(BaseballTheme.canvas)
        .navigationTitle("커리어")
    }
}

/// 주간 계획. Picker 대신 효과와 비용이 보이는 카드로 고른다(계획 문서 §2.3 B5).
private struct WeeklyPlanView: View {
    let career: MobileCareerStore
    let state: ProCareerSnapshot

    private struct PlanCopy {
        let plan: ProWeekPlan
        let title: String
        let effect: String
        let cost: String
        let symbol: String
    }

    private static let plans: [PlanCopy] = [
        PlanCopy(plan: .developWeapon, title: "결정구 불펜", effect: "구위와 변화구가 오릅니다", cost: "피로가 크게 쌓입니다", symbol: "flame"),
        PlanCopy(plan: .refineCommand, title: "코스 제구 훈련", effect: "제구가 오릅니다", cost: "피로가 쌓입니다", symbol: "scope"),
        PlanCopy(plan: .buildStamina, title: "긴 이닝 훈련", effect: "체력이 오릅니다", cost: "피로가 쌓입니다", symbol: "figure.run"),
        PlanCopy(plan: .recover, title: "회복", effect: "피로가 줄고 부상 위험이 낮아집니다", cost: "능력이 오르지 않습니다", symbol: "bed.double"),
        PlanCopy(plan: .earnTrust, title: "이번 주 경기 집중", effect: "감독의 믿음이 오릅니다", cost: "능력이 오르지 않습니다", symbol: "person.2")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            HStack(spacing: 10) {
                Metric(title: "피로", value: "\(state.fatigue)", tone: state.fatigue >= 70 ? .warning : .standard)
                Metric(title: "감독의 믿음", value: "\(state.managerTrust)", tone: state.managerTrust >= 60 ? .positive : .standard)
                Metric(title: "역할", value: MobileCareerStore.roleName(state.role))
            }

            Text("이번 주에 할 일").font(.headline)

            ForEach(Self.plans, id: \.plan) { copy in
                PlanCard(copy: copy, selected: career.selectedPlan == copy.plan) {
                    career.selectedPlan = copy.plan
                }
            }

            PrimaryPill(title: "1주 진행", identifier: "pro.advanceWeek", action: career.advanceWeek)

            Button(action: career.advanceBlock) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("같은 계획으로 3주 진행").font(.subheadline.weight(.semibold))
                    Text("중요 경기나 선발·불펜 역할 변화가 생기면 멈춥니다.")
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .frame(minHeight: BaseballMetrics.minimumTapTarget)
        }
    }

    private struct PlanCard: View {
        let copy: PlanCopy
        let selected: Bool
        let onSelect: () -> Void

        var body: some View {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: copy.symbol)
                        .font(.title3)
                        .foregroundStyle(selected ? BaseballTheme.selection : BaseballTheme.textSecondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(copy.title).font(.subheadline.weight(.bold))
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(rival.name) · \(rival.teamName)").font(.headline)
                        Text(rival.archetype).font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                        Text(rival.profile).font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(rival.record).font(.footnote.monospacedDigit()).foregroundStyle(BaseballTheme.textSecondary)
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
