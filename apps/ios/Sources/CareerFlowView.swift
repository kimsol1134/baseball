import SwiftUI
import SimulationCore

struct CareerFlowView: View {
    let career: MobileCareerStore
    /// 은퇴 뒤 새 선수로 시작한다. 프로 저장본을 지우고 고교 탭으로 돌려보낸다.
    var onStartNewPlayer: () -> Void = {}
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
                            OffseasonView(career: career, state: state)
                        case .retirementDecision:
                            RetirementDecisionView(career: career, state: state)
                        case .completed:
                            RetiredView(state: state, onStartNewPlayer: onStartNewPlayer)
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

            Button(action: career.advanceSegment) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Self.segmentName(state.seasonSegment)) 끝까지 진행")
                        .font(.subheadline.weight(.semibold))
                    Text("중요 경기·역할 변화·부상이 생기면 그 자리에서 멈춥니다.")
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

    @State private var pending: OffseasonDecision?

    private var service: Int { MobileCareerStore.freeAgencyService(state) }
    private var freeAgencyReady: Bool { service >= 6 }

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
                title: "현재 구단에 남는다",
                detail: "\(state.team.name)에서 선발·불펜 자리 경쟁을 이어 갑니다.",
                symbol: "arrow.forward.circle",
                enabled: true,
                note: nil
            ) { pending = .continueCareer }

            OffseasonChoice(
                title: "군 복무를 다녀온다",
                detail: "두 시즌을 비우고 돌아옵니다. 나이가 두 살 늘지만 이후 시즌이 온전해집니다.",
                symbol: "shield",
                enabled: !state.militaryCompleted,
                note: state.militaryCompleted ? "이미 마쳤습니다." : nil
            ) { pending = .militaryService }

            OffseasonChoice(
                title: "FA를 신청한다",
                detail: "다른 구단과 계약해 새 팀에서 다시 시작합니다.",
                symbol: "arrow.triangle.branch",
                enabled: freeAgencyReady,
                note: freeAgencyReady ? nil : "1군 등록 6년이 필요합니다. 지금 \(service)년."
            ) { pending = .freeAgency }

            OffseasonChoice(
                title: "은퇴한다",
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
            Button("취소", role: .cancel) { pending = nil }
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

/// 12시즌 또는 37세. 여기서는 계속할 수 없다 — 코어가 어떤 선택을 받아도 은퇴로 보낸다.
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
            Button("취소", role: .cancel) {}
        } message: {
            Text("통산 \(state.careerStats.count)시즌으로 커리어가 끝납니다.")
        }
    }
}

/// 은퇴한 뒤. 커리어의 마지막 화면이라 회고와 통산 기록만 남는다.
private struct RetiredView: View {
    let state: ProCareerSnapshot
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

            if let score = state.hallOfFameScore {
                BaseballCard(title: "명예의 전당 점수", tone: .milestone) {
                    Text("\(score)").font(BaseballType.heroNumeral).foregroundStyle(BaseballTheme.milestone)
                }
            }

            CareerTotals(state: state)

            // 이 커리어가 다음 회차에 남기는 것. 프로의 시간이 환생 루프와 무관하면
            // 은퇴가 끝이 되지만, 야구혼으로 이어지면 은퇴가 다음 회차의 시작이 된다.
            BaseballCard(title: "다음 회차로", tone: .milestone) {
                Text("이 커리어가 야구혼 \(HighSchoolCareerStore.proSoulBonus(for: state))을 남깁니다. 다시 태어날 때 시작 능력에 스며듭니다.")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
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

            PrimaryPill(title: "새 선수로 다시 시작", identifier: "pro.newPlayer") { confirming = true }
            Text("이 커리어를 접고 고교 1학년부터 다시 시작합니다. 지금까지의 기록은 남습니다.")
                .font(.caption)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .confirmationDialog("새 선수로 시작하시겠습니까?", isPresented: $confirming, titleVisibility: .visible) {
            Button("새 선수로 시작", role: .destructive, action: onStartNewPlayer)
                .accessibilityIdentifier("pro.newPlayer.confirm")
            Button("취소", role: .cancel) {}
        } message: {
            Text("\(state.identity.name)의 프로 커리어가 닫히고 고교 화면으로 돌아갑니다.")
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
