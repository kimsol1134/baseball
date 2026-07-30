import SwiftUI
import SimulationCore

enum AppTab: Hashable, CaseIterable, Identifiable {
    case highSchool, pro, records, settings
    var id: Self { self }
    var title: String {
        switch self {
        case .highSchool: "고교"
        case .pro: "프로"
        case .records: "기록"
        case .settings: "설정"
        }
    }
    var icon: String {
        switch self {
        case .highSchool: "graduationcap"
        case .pro: "figure.baseball"
        case .records: "chart.bar"
        case .settings: "gearshape"
        }
    }
}

struct AppShell: View {
    let highSchool: HighSchoolCareerStore
    let pro: MobileCareerStore
    @State private var selection: AppTab = .highSchool

    /// 프로에 입단하면 고교 탭을 숨긴다.
    ///
    /// 이미 프로 선수인데 탭 바에 "고교"가 남아 있으면, 그 탭이 무엇인지 알 수 없다.
    /// 고교 3년은 끝난 이야기다. 다시 고교로 돌아가는 길은 은퇴 화면의 "새 선수로 다시
    /// 시작"뿐이고, 그건 되돌릴 수 없는 선택이라 확인을 거쳐 간다.
    private var showsHighSchool: Bool { pro.loadState != .ready }

    /// 첫 회차의 도입부(오프닝·선수 만들기·프롤로그)에는 탭 바를 감춘다.
    ///
    /// 게임을 시작하기도 전에 빈 탭 3개가 보이면 "게임"이 아니라 "앱 설정"으로 읽히고,
    /// 프로 탭의 건너뛰기를 호기심에 눌러 본편(3년 육성·환생)을 통째로 우회할 수 있다
    /// (QA P1-12). 첫 등판을 던질 즈음이면 기록 탭에도 보여 줄 것이 생긴다.
    private var hidesTabBarForOnboarding: Bool {
        highSchool.archive.isEmpty && pro.loadState != .ready
            && (highSchool.state == nil || highSchool.state?.phase == .prologue)
    }

    var body: some View {
        TabView(selection: $selection) {
            if showsHighSchool {
                NavigationStack {
                    HighSchoolCareerView(
                        career: highSchool,
                        onEnterPro: { draft, pitcher, identity in
                            pro.startProCareer(draft: draft, pitcher: pitcher, identity: identity)
                            selection = .pro
                        },
                        // 프로 저장본이 남아 있으면(은퇴 포함) 이 회차는 이미 프로에 다녀왔다.
                        hasEnteredPro: pro.loadState == .ready
                    )
                    // 키아트가 제목을 맡는다. 내비게이션 바를 두면 제목이 두 번 나오고 눈썹 라벨을 가린다.
                    .toolbar(hidesTabBarForOnboarding ? .hidden : .visible, for: .tabBar)
                    .toolbar(.hidden, for: .navigationBar)
                }
                .tabItem { Label(AppTab.highSchool.title, systemImage: AppTab.highSchool.icon) }
                .tag(AppTab.highSchool)
            }

            NavigationStack { proTab }
                .tabItem { Label(AppTab.pro.title, systemImage: AppTab.pro.icon) }
                .tag(AppTab.pro)

            NavigationStack { RecordView(highSchool: highSchool, career: pro) }
                .tabItem { Label(AppTab.records.title, systemImage: AppTab.records.icon) }
                .tag(AppTab.records)

            NavigationStack { SettingsView(highSchool: highSchool, pro: pro) }
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.icon) }
                .tag(AppTab.settings)
        }
        .tint(BaseballTheme.action)
        .foregroundStyle(BaseballTheme.textPrimary)
        .background(BaseballTheme.canvas.ignoresSafeArea())
        // 고교 탭이 사라지는 순간 그 탭을 보고 있으면 빈 화면이 남는다.
        .onChange(of: showsHighSchool) { _, shows in
            if !shows, selection == .highSchool { selection = .pro }
        }
    }

    /// 프로 탭. 고교 드래프트를 통과하기 전에는 잠겨 있고, 건너뛰기 경로를 함께 안내한다.
    @ViewBuilder private var proTab: some View {
        switch pro.loadState {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(BaseballTheme.canvas)
        case .needsSetup:
            ProLockedView(
                pro: pro,
                hasFinishedALife: !highSchool.archive.isEmpty,
                forecast: highSchool.state.map { HighSchoolCareerEngine.draftForecast(state: $0) },
                remainingChapters: highSchool.state.map { max(0, 8 - $0.chapter.number) }
            )
        case .failed(let message):
            CareerFailureView(message: message, career: pro)
        case .ready:
            ProCareerTabs(career: pro) {
                // 은퇴한 선수의 커리어를 접고 고교로 돌아간다. 프로에서의 시간을 야구혼으로
                // 계승분에 먼저 얹은 뒤 프로 저장본만 지운다 — 고교 회차는 그대로 있으므로,
                // 완료 화면에서 기억을 고르고 다시 시작한다.
                highSchool.recordProLegacy(pro.state)
                pro.deleteCareer()
                selection = .highSchool
            }
        }
    }
}

/// 고교를 거치지 않고 바로 프로부터 하고 싶은 사용자를 위한 우회로. 정규 경로는 고교 드래프트다.
private struct ProLockedView: View {
    let pro: MobileCareerStore
    let hasFinishedALife: Bool
    var forecast: HighSchoolCareerEngine.DraftForecastSnapshot?
    var remainingChapters: Int?
    @State private var showsSetup = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                KeyArtHeader(
                    art: .proStadiumTunnel,
                    eyebrow: "프로 커리어",
                    title: "고교 드래프트에서 지명을 받으면 열립니다"
                )
                BaseballCard(title: "정규 경로", tone: .raised) {
                    Text("고교 탭에서 3년을 보내고 드래프트를 통과하면, 그때의 능력을 그대로 안고 프로에 들어갑니다.")
                        .font(.subheadline)
                }
                // 잠긴 문 아래가 빈 검정이면 잠금이 벌처럼 느껴진다. 같은 공간이
                // "지금 평가가 당락선에서 몇 점 모자란가"를 말하면 목표판이 된다(QA P1-12 부분).
                if let forecast {
                    BaseballCard(title: "이 문까지의 거리", tone: .milestone) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(forecast.band)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(forecast.score >= forecast.threshold ? BaseballTheme.action : BaseballTheme.textPrimary)
                            Text("현재 평가 \(forecast.score)점 · 당락선 \(forecast.threshold)점"
                                 + (remainingChapters.map { $0 > 0 ? " · 남은 챕터 \($0)" : " · 드래프트 임박" } ?? ""))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(BaseballTheme.textSecondary)
                            Text("\(forecast.interestedTeam)\(KoreanCopy.particle(forecast.interestedTeam, final: "이", open: "가")) 지금 성적을 지켜보고 있습니다.")
                                .font(.caption)
                                .foregroundStyle(BaseballTheme.textTertiary)
                        }
                    }
                }
                // 건너뛰기는 본편을 한 번 완주한 사람의 문이다. 처음 켠 사람이 이 문으로
                // 들어가면 이 게임에서 가장 좋은 것(3년 육성·환생)을 못 본 채 평가한다.
                if hasFinishedALife {
                    Button("고교를 건너뛰고 바로 프로 시작") { showsSetup = true }
                        .buttonStyle(.bordered)
                        .frame(minHeight: BaseballMetrics.minimumTapTarget)
                    Text("건너뛰면 지명 결과가 시드에서 만들어집니다. 고교 3년의 성장과 기억은 없습니다.")
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textSecondary)
                } else {
                    Text("한 회차를 끝내면 고교를 건너뛰는 길도 열립니다.")
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textTertiary)
                }
            }
            .padding(BaseballMetrics.gutter)
        }
        .background(BaseballTheme.canvas)
        .navigationTitle("프로")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsSetup) {
            NavigationStack {
                CareerSetupView(career: pro)
                    .navigationTitle("프로부터 시작")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("취소") { showsSetup = false }
                        }
                    }
            }
        }
        .onChange(of: pro.loadState) { _, state in
            if state == .ready { showsSetup = false }
        }
    }
}

/// 프로 커리어 안의 오늘/이번 주 두 화면.
private struct ProCareerTabs: View {
    let career: MobileCareerStore
    let onStartNewPlayer: () -> Void
    @State private var showsToday = true

    var body: some View {
        VStack(spacing: 0) {
            Picker("프로 화면", selection: $showsToday) {
                Text("오늘").tag(true)
                Text("이번 주").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, BaseballMetrics.gutter)
            .padding(.vertical, 8)

            if showsToday {
                TodayView(career: career)
            } else {
                CareerFlowView(career: career, onStartNewPlayer: onStartNewPlayer)
            }
        }
        .background(BaseballTheme.canvas)
        .onChange(of: career.state?.phase) { _, phase in
            if phase == .importantGame { showsToday = false }
        }
    }
}

private struct CareerFailureView: View {
    let message: String
    let career: MobileCareerStore

    var body: some View {
        ContentUnavailableView {
            Label("커리어를 열 수 없습니다", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            PrimaryPill(title: "새 커리어 시작", identifier: "pro.restart") { career.deleteCareer() }
        }
        .background(BaseballTheme.canvas)
    }
}

struct TodayView: View {
    let career: MobileCareerStore

    var body: some View {
        Group {
            if let state = career.state {
                TodayDashboard(state: state)
            } else {
                ContentUnavailableView("커리어 없음", systemImage: "baseball")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(BaseballTheme.canvas)
    }
}

private struct TodayDashboard: View {
    let state: ProCareerSnapshot

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                KeyArtHeader(
                    // 1군 데뷔와 은퇴는 커리어에 한 번뿐이라 전용 그림을 준다.
                    art: state.phase == .completed ? .retirement
                        : state.level == .major ? .majorDebut : .stadiumNight,
                    eyebrow: "\(state.season)시즌 \(state.week)주차 · \(Self.segmentLabel(state.seasonSegment))",
                    title: "\(state.team.name) · \(state.level == .major ? "1군" : "2군") \(MobileCareerStore.roleName(state.role))",
                    accent: BaseballTheme.teamDecoration(state.team.id)
                )

                SeasonArcBar(segment: state.seasonSegment, week: state.week)

                HStack(spacing: 10) {
                    Metric(title: "피로", value: "\(state.fatigue)", tone: state.fatigue >= 70 ? .warning : .standard)
                    Metric(title: "감독의 믿음", value: "\(state.managerTrust)", tone: state.managerTrust >= 60 ? .positive : .standard)
                    Metric(title: "부상", value: state.injuryWeeks > 0 ? "\(state.injuryWeeks)주" : "정상", tone: state.injuryWeeks > 0 ? .negative : .standard)
                }

                BaseballCard(title: "다음 행동", tone: .raised) {
                    Text(Self.actionText(state.phase)).font(.body.weight(.semibold))
                }

                if let tensions = state.seasonTensions, !tensions.isEmpty {
                    BaseballCard(title: "올해의 세 가지 승부처") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(tensions.enumerated()), id: \.offset) { _, tension in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tension.title).font(.subheadline.weight(.semibold))
                                    Text(tension.detail).font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }

                if let rival = state.currentRival {
                    BaseballCard(title: "이번 승부 상대", tone: .warning) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(rival.name) · \(rival.teamName)").font(.headline)
                            Text(rival.archetype).font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                            Text(rival.record).font(.footnote.monospacedDigit()).foregroundStyle(BaseballTheme.textSecondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                if let milestone = state.milestones.last {
                    BaseballCard(title: "최근 주요 기록", tone: .milestone) {
                        Label(milestone, systemImage: "star.fill").foregroundStyle(BaseballTheme.milestone)
                    }
                }

                // 3주를 한 번에 건너뛰어도(`advanceBlock`) 그 사이의 등판이 여기 남는다.
                // 예전에는 뉴스 한 줄로 증발해서 시즌이 통째로 기억에 남지 않았다.
                if let line = state.gameLines?.last {
                    BaseballCard(title: "최근 등판") {
                        VStack(alignment: .leading, spacing: 8) {
                            if line.played {
                                Text("직접 등판").eyebrowStyle(BaseballTheme.action)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(GameLineFormat.score(line))
                                    .font(BaseballType.scoreboard)
                                    .foregroundStyle(BaseballTheme.textPrimary)
                                if let decision = GameLineFormat.decisionLabel(line.decision) {
                                    Text(decision)
                                        .font(.headline.weight(.heavy))
                                        .foregroundStyle(GameLineFormat.decisionTone(line.decision))
                                }
                                Spacer()
                                Text("\(line.week)주차")
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(BaseballTheme.textTertiary)
                            }
                            Text("\(GameLineFormat.role(line)) · \(GameLineFormat.pitchingLine(line))")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(BaseballTheme.textSecondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(GameLineFormat.accessibilityLabel(line))
                        .accessibilityIdentifier("today.lastOuting")
                    }
                }

                BaseballCard(title: "최근 소식") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(state.news.prefix(3).enumerated()), id: \.offset) { _, item in
                            Text(item).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(BaseballMetrics.gutter)
        }
        .background(BaseballTheme.canvas)
    }

    static func segmentLabel(_ segment: ProSeasonSegment?) -> String {
        switch segment {
        case .springCamp: "스프링캠프"
        case .opening: "개막"
        case .firstHalf: "전반기"
        case .allStarBreak: "올스타 휴식기"
        case .pennantRace: "순위 싸움"
        case .seasonFinale: "시즌 막바지"
        case .none: "시즌 준비"
        }
    }

    static func actionText(_ phase: ProCareerPhase) -> String {
        // "커리어 탭"은 존재하지 않는다 — 탭 바에는 고교/프로/기록/설정뿐이고, 실제로는
        // 프로 화면 위의 "이번 주" 세그먼트다. 없는 곳을 가리키면 처음 온 사람이 길을 잃는다.
        switch phase {
        case .weeklyPlan: "이번 주에 가장 신경 쓸 훈련을 고르세요."
        case .importantGame: "등판이 잡혔습니다. 위의 '이번 주'에서 승부를 시작하세요."
        case .seasonReview: "올해 경기 기록과 수상 결과를 확인하세요."
        case .offseasonDecision: "현재 구단에 남을지 결정하세요."
        default: "위의 '이번 주'에서 다음 일정을 확인하세요."
        }
    }
}

/// 24주 시즌 안에서 지금 어디쯤인지 보여 준다. 주 단위 진행 게임의 위치 감각을 만든다.
private struct SeasonArcBar: View {
    let segment: ProSeasonSegment?
    let week: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("시즌 진행").font(.caption.weight(.semibold)).foregroundStyle(BaseballTheme.textSecondary)
                Spacer()
                Text("\(min(week, 24)) / 24주").font(.caption.monospacedDigit()).foregroundStyle(BaseballTheme.textSecondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(BaseballTheme.surfaceRaised)
                    Capsule()
                        .fill(BaseballTheme.action)
                        .frame(width: max(4, proxy.size.width * CGFloat(min(week, 24)) / 24))
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("시즌 진행 \(min(week, 24))주차, 24주 중")
    }
}

/// 상태 한 칸. 큰 숫자가 주인공이라 `StatTile`을 그대로 쓴다.
struct Metric: View {
    let title: String
    let value: String
    var tone: BaseballCardTone = .standard

    var body: some View {
        StatTile(
            label: title,
            value: value,
            tone: tone == .standard ? BaseballTheme.textPrimary : tone.accent
        )
    }
}
