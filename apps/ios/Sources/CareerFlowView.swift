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
            } else { decision }
        }
        .navigationTitle("이번 주")
        .sensoryFeedback(.success, trigger: career.feedbackTrigger)
    }

    @ViewBuilder private var decision: some View {
        if let state = career.state {
            VStack(spacing: 0) {
                if let summary = career.lastSummary {
                    ResultBanner(summary: summary)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
                switch state.phase {
                case .weeklyPlan: WeeklyPlanView(career: career, state: state)
                case .importantGame: ImportantMomentView(career: career, state: state)
                case .seasonReview: ActionCard(title: "시즌 종료", copy: "올해 경기 기록과 수상을 통산 기록에 더합니다.", button: "시즌 기록 확인", action: career.reviewSeason)
                case .offseasonDecision: ActionCard(title: "오프시즌", copy: "현재 구단에 남아 보직 경쟁을 계속합니다.", button: "현재 구단에 남기", action: career.continueCareer)
                default: ContentUnavailableView("이번 일정은 끝났습니다", systemImage: "checkmark.circle")
                }
            }
            .animation(reduceMotion ? nil : .snappy, value: career.feedbackTrigger)
        } else { ProgressView() }
    }
}

private struct ResultBanner: View {
    let summary: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill").foregroundStyle(DiamondSoulTheme.positive)
            Text(summary).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding().background(DiamondSoulTheme.positive.opacity(0.1)).accessibilityElement(children: .combine)
    }
}

private struct CareerSummary: View {
    let career: MobileCareerStore
    var body: some View {
        List {
            if let state = career.state {
                Section("선수") {
                    LabeledContent("구단", value: state.team.name)
                    LabeledContent("레벨", value: state.level == .major ? "1군" : "2군")
                    LabeledContent("보직", value: roleLabel(state.role))
                }
                Section("능력") {
                    LabeledContent("구위", value: "\(state.pitcher.stuff)")
                    LabeledContent("커맨드", value: "\(state.pitcher.command)")
                    LabeledContent("체력", value: "\(state.pitcher.stamina)")
                }
                Section("최근 이정표") {
                    ForEach(Array(state.milestones.suffix(6).reversed()), id: \.self) { milestone in
                        Label(milestone, systemImage: milestone == state.milestones.last ? "star.fill" : "circle.fill")
                            .foregroundStyle(milestone == state.milestones.last ? .primary : .secondary)
                    }
                }
            }
        }
        .navigationTitle("커리어")
    }

    private func roleLabel(_ role: ProRole) -> String {
        switch role { case .starter: "선발"; case .longRelief: "롱릴리프"; case .setup: "셋업맨"; case .closer: "마무리" }
    }
}

private struct WeeklyPlanView: View {
    let career: MobileCareerStore
    let state: ProCareerSnapshot

    var body: some View {
        Form {
            Section("오늘의 상태") {
                LabeledContent("피로", value: "\(state.fatigue)")
                LabeledContent("감독 신뢰", value: "\(state.managerTrust)")
                LabeledContent("현재 보직", value: roleLabel(state.role))
            }
            Section("이번 구간의 우선순위") {
                Picker("계획", selection: Bindable(career).selectedPlan) {
                    Text("결정구 불펜 · 성장 / 피로↑").tag(ProWeekPlan.developWeapon)
                    Text("코너워크 · 커맨드 / 피로↑").tag(ProWeekPlan.refineCommand)
                    Text("긴 이닝 훈련 · 체력 / 피로↑").tag(ProWeekPlan.buildStamina)
                    Text("회복 · 등판 감소 / 피로↓").tag(ProWeekPlan.recover)
                    Text("맡은 보직 · 신뢰 / 성장 없음").tag(ProWeekPlan.earnTrust)
                }
                Button("1주 진행", action: career.advanceWeek).frame(minHeight: 44)
                Button(action: career.advanceBlock) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("같은 계획으로 3주 진행")
                        Text("중요 경기나 보직 변화가 생기면 멈춥니다.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: 44)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func roleLabel(_ role: ProRole) -> String {
        switch role { case .starter: "선발"; case .longRelief: "롱릴리프"; case .setup: "셋업맨"; case .closer: "마무리" }
    }
}

private struct ImportantMomentView: View {
    let career: MobileCareerStore
    let state: ProCareerSnapshot

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Text("IMPORTANT MOMENT · WEEK \(state.week)").font(.caption.weight(.bold)).foregroundStyle(DiamondSoulTheme.milestone)
                Text(state.level == .major ? "1군에서 자리를 정할 승부" : state.managerTrust < 55 ? "보직 경쟁 평가전" : "다음 보직을 결정할 경기")
                    .font(.largeTitle.bold())
                Text("한 점 차 · 1사 2루 · 최정우 타석\n현재 피로 \(state.fatigue), 감독 신뢰 \(state.managerTrust)")
                    .foregroundStyle(.secondary)
                VStack(spacing: 10) {
                    ForEach(MobileCareerStore.ImportantApproach.allCases) { approach in
                        Button { career.selectedApproach = approach } label: {
                            HStack(spacing: 12) {
                                Image(systemName: career.selectedApproach == approach ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(career.selectedApproach == approach ? DiamondSoulTheme.selection : .secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(approach.title).font(.headline)
                                    Text(approach.detail).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding().frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                            .background(career.selectedApproach == approach ? DiamondSoulTheme.selection.opacity(0.12) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain).accessibilityAddTraits(career.selectedApproach == approach ? .isSelected : [])
                    }
                }
                Button("이 승부로 투구", action: career.resolveImportantMoment)
                    .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity, minHeight: 50)
            }
            .padding()
        }
    }
}

private struct ActionCard: View {
    let title: String
    let copy: String
    let button: String
    let action: () -> Void
    var body: some View {
        ContentUnavailableView { Label(title, systemImage: "baseball.fill") } description: { Text(copy) } actions: {
            Button(button, action: action).buttonStyle(.borderedProminent).frame(minHeight: 44)
        }
    }
}
