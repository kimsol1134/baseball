import SwiftUI
import SimulationCore

enum AppTab: Hashable, CaseIterable, Identifiable {
    case highSchool, pro, records, settings
    var id: Self { self }
    var titleKey: GameCopyKey {
        switch self {
        case .highSchool: AppCopyKey.tabHighSchool
        case .pro: AppCopyKey.tabPro
        case .records: AppCopyKey.tabRecords
        case .settings: AppCopyKey.tabSettings
        }
    }
    /// Compatibility accessor for non-view callers; the rendered tab uses the injected resolver.
    var title: String {
        GameCopyResolver(language: .korean, policy: .releaseSafe).resolve(titleKey)
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
    var weekly: WeeklyProgramStore = .shared
    var returnWelcomePlan: DailyReminder.Plan?
    var onDismissReturnWelcome: () -> Void = {}
    @State private var selection: AppTab = .highSchool
    @State private var returnPlanHighSchoolRevision: UInt64?
    @State private var returnPlanProRevision: UInt64?
    @Environment(\.gameCopyResolver) private var copyResolver

    /// 제거 전 배포가 남긴 링크도 빈 화면으로 보내지 않는다.
    static func retiredDailyInningFallbackTab(
        hasActiveProCareer: Bool,
        showsHighSchool: Bool
    ) -> AppTab {
        if hasActiveProCareer { return .pro }
        return showsHighSchool ? .highSchool : .pro
    }

    private func openReminderLink(_ url: URL) {
        guard let destination = DailyReminder.Destination.resolve(url) else { return }
        onDismissReturnWelcome()
        switch destination {
        case .dailyInning:
            selection = Self.retiredDailyInningFallbackTab(
                hasActiveProCareer: pro.loadState == .ready && pro.state?.phase != .completed,
                showsHighSchool: showsHighSchool
            )
        case .highSchool:
            selection = showsHighSchool ? .highSchool : .pro
        case .pro:
            selection = .pro
        }
    }

    /// 프로 생성 호출이 실제 새 저장 상태로 끝났는지 판정하는 순수 경계.
    static func proCareerCreationSucceeded(
        previousCareerID: String?,
        currentCareerID: String?,
        isReady: Bool
    ) -> Bool {
        guard isReady, let currentCareerID else { return false }
        return currentCareerID != previousCareerID
    }

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

    /// 투구 화면은 화면 아래의 릴리스 패드가 주 조작이다. 부모가 탭 바를 `.visible`로
    /// 강제하면 `PitchView`의 숨김 요청보다 우선해 패드와 프로 탭이 같은 자리를 차지한다.
    /// 실제 완주에서 화면 밖 투구 버튼을 누르려다 프로 탭이 눌린 원인이었다.
    static func shouldHideHighSchoolTabBar(
        isOnboarding: Bool,
        hasPitchSession: Bool,
        hasTutorialSession: Bool
    ) -> Bool {
        isOnboarding || hasPitchSession || hasTutorialSession
    }

    private var hidesHighSchoolTabBar: Bool {
        Self.shouldHideHighSchoolTabBar(
            isOnboarding: hidesTabBarForOnboarding,
            hasPitchSession: highSchool.pitchSession != nil,
            hasTutorialSession: highSchool.tutorialSession != nil
        )
    }

    /// 주간 목표는 지금 실제로 열려 있거나 이번 회차 안에서 도달 가능한 행동만 뽑는다.
    private var weeklyEligibility: WeeklyProgramEligibility {
        let highSchoolState = highSchool.state
        let remainingImportantGames = highSchoolState.map {
            max(0, ($0.schedule ?? .fixedDefault).importantGameTotal
                - $0.performance.importantGamesCompleted)
        } ?? 0
        let remainingChapterAdvances = highSchoolState.map { max(0, 8 - $0.chapter.number) } ?? 0
        return Self.weeklyEligibility(
            highSchoolPhase: highSchoolState?.phase,
            importantGamesCompleted: highSchoolState?.performance.importantGamesCompleted ?? 0,
            remainingImportantGames: remainingImportantGames,
            remainingChapterAdvances: remainingChapterAdvances,
            isChallengeRun: highSchool.isChallengeRun,
            hasArchive: !highSchool.archive.isEmpty,
            hasPreviousSchool: highSchool.archive.first?.schoolName != nil,
            pledgeDecided: highSchool.pledgeDecided,
            proPhase: pro.state?.phase
        )
    }

    /// 화면 상태에서 주간 목표 자격으로 가는 순수 경계. 프롤로그뿐 아니라 학교 선택
    /// 화면에서도 약속 카드가 보이므로, 두 국면 모두 약속 목표를 실제로 수행할 수 있다.
    static func weeklyEligibility(
        highSchoolPhase: HighSchoolCareerPhase?,
        importantGamesCompleted: Int,
        remainingImportantGames: Int,
        remainingChapterAdvances: Int,
        isChallengeRun: Bool,
        hasArchive: Bool,
        hasPreviousSchool: Bool,
        pledgeDecided: Bool,
        proPhase: ProCareerPhase?
    ) -> WeeklyProgramEligibility {
        let hasPlayableProWeeks = proPhase.map {
            $0 != .completed && $0 != .retirementDecision
        } ?? false
        if hasPlayableProWeeks {
            // 프로가 고교 탭을 숨긴 동안에는 고교 경기·챕터·환생 목표를 내지 않는다.
            return WeeklyProgramEligibility(
                hasHighSchoolCareer: false,
                remainingImportantGames: 0,
                remainingChapterAdvances: 0,
                canStartNextRun: false,
                canSelectPledge: false,
                canChooseDifferentSchool: false,
                hasProCareer: true
            )
        }

        let beforeSchoolChoice = highSchoolPhase.map {
            $0 == .prologue || $0 == .schoolSelection
        } ?? false
        let highSchoolIsPlayable = highSchoolPhase.map {
            switch $0 {
            case .prologue, .schoolSelection, .training, .relationship,
                 .importantGame, .awakening, .chapterReview:
                true
            case .draft, .legacy, .completed:
                false
            }
        } ?? false
        let highSchoolIsActive = highSchoolIsPlayable && proPhase == nil && !isChallengeRun
        // 완료된 프로 화면에서는 "새 선수로 다시 시작"이 즉시 가능하지만, 아직 시작하지
        // 않은 고교 경기·챕터를 목표로 내서는 안 된다.
        let canStartNextRun = !isChallengeRun && hasArchive
            && (proPhase == nil || proPhase == .completed)
        return WeeklyProgramEligibility(
            hasHighSchoolCareer: highSchoolIsActive,
            remainingImportantGames: highSchoolIsActive ? max(0, remainingImportantGames) : 0,
            remainingChapterAdvances: highSchoolIsActive ? max(0, remainingChapterAdvances) : 0,
            canStartNextRun: canStartNextRun,
            canSelectPledge: highSchoolIsActive && beforeSchoolChoice && !pledgeDecided,
            canChooseDifferentSchool: highSchoolIsActive && beforeSchoolChoice && hasPreviousSchool,
            hasProCareer: false
        )
    }

    /// "모든 진행 삭제" 직후의 화면 복원. 저장은 스토어가 이미 지웠고, 여기서는
    /// **보고 있는 자리**를 첫 실행과 같게 되돌린다: 열려 있는 전면 화면을 닫고,
    /// 탭을 고교로 옮기고, 오프닝을 다시 보여 준다.
    private func resetToFirstLaunch() {
        onDismissReturnWelcome()
        selection = .highSchool
        // 고교 뷰의 오프닝 표시 상태는 그 뷰의 @State다. 정체성을 갈아 끼워 새로 만든다.
        firstLaunchToken &+= 1
    }

    /// 오프닝을 포함한 고교 화면 전체를 새로 만들기 위한 정체성. 값이 바뀌면 SwiftUI가
    /// 뷰를 버리고 다시 만들어 `openingDismissed` 같은 화면 상태가 초기값으로 돌아간다.
    @State private var firstLaunchToken: UInt64 = 0

    var body: some View {
        TabView(selection: $selection) {
            if showsHighSchool {
                NavigationStack {
                    HighSchoolCareerView(
                        career: highSchool,
                        onEnterPro: { draft, pitcher, identity in
                            let previousCareerID = pro.state?.proCareerID
                            guard let sourceHighSchoolCareerID = highSchool.state?.careerID else { return }
                            // 선택된 탭을 먼저 옮긴다. 프로 저장 성공으로 고교 탭이 사라진
                            // 다음에 selection을 바꾸면 SwiftUI TabView가 선택 대상을 잃어
                            // 하단 탭만 남은 빈 화면에 머물 수 있다.
                            selection = .pro
                            guard pro.startProCareer(
                                draft: draft,
                                pitcher: pitcher,
                                identity: identity,
                                sourceHighSchoolCareerID: sourceHighSchoolCareerID
                            ) else {
                                selection = .highSchool
                                return
                            }
                            guard Self.proCareerCreationSucceeded(
                                previousCareerID: previousCareerID,
                                currentCareerID: pro.state?.proCareerID,
                                isReady: pro.loadState == .ready
                            ) else {
                                selection = .highSchool
                                return
                            }
                            guard highSchool.markEnteredPro() else {
                                // 양쪽 저장 중 하나만 성공한 반쪽 진입을 남기지 않는다.
                                _ = pro.deleteCareer()
                                selection = .highSchool
                                return
                            }
                            // 드래프트 이후의 **정상 분기**다. 이 계측이 없으면 대시보드에서
                            // "드래프트를 봤는데 환생하지 않은 사람"이 전부 이탈로 잡힌다 —
                            // 실제로는 프로로 넘어간 사람이 섞여 있다(2026-08 분석의 맹점).
                            GameAnalytics.log(.proCareerStarted, [
                                "round": draft.round ?? 0,
                                "evaluation": draft.evaluationScore,
                                "life_number": highSchool.state?.lifeNumber ?? 0,
                                "source": "high_school_draft",
                            ])
                        },
                        // 프로 저장본이 남아 있으면(은퇴 포함) 이 회차는 이미 프로에 다녀왔다.
                        hasEnteredPro: pro.loadState == .ready || highSchool.hasEnteredPro,
                        weekly: weekly
                    )
                    // 키아트가 제목을 맡는다. 내비게이션 바를 두면 제목이 두 번 나오고 눈썹 라벨을 가린다.
                    .toolbar(hidesHighSchoolTabBar ? .hidden : .visible, for: .tabBar)
                    .toolbar(.hidden, for: .navigationBar)
                    .id(firstLaunchToken)
                }
                .tabItem {
                    Label(copyResolver.resolve(AppTab.highSchool.titleKey), systemImage: AppTab.highSchool.icon)
                }
                .tag(AppTab.highSchool)
            }

            NavigationStack { proTab }
                .tabItem {
                    Label(copyResolver.resolve(AppTab.pro.titleKey), systemImage: AppTab.pro.icon)
                }
                .tag(AppTab.pro)

            NavigationStack {
                RecordView(
                    highSchool: highSchool,
                    career: pro,
                    weekly: weekly
                )
            }
                .tabItem {
                    Label(copyResolver.resolve(AppTab.records.titleKey), systemImage: AppTab.records.icon)
                }
                .tag(AppTab.records)

            NavigationStack {
                SettingsView(highSchool: highSchool, pro: pro, onResetAll: resetToFirstLaunch)
            }
                .tabItem {
                    Label(copyResolver.resolve(AppTab.settings.titleKey), systemImage: AppTab.settings.icon)
                }
                .tag(AppTab.settings)
        }
        .tint(BaseballTheme.action)
        .foregroundStyle(BaseballTheme.textPrimary)
        .background(BaseballTheme.canvas.ignoresSafeArea())
        .modifier(ReturnWelcomeInset(
            plan: returnWelcomePlan,
            onShown: {
                returnPlanHighSchoolRevision = highSchool.result?.revision
                returnPlanProRevision = pro.state?.revision
            },
            onContinue: { plan in
                guard let url = URL(string: plan.destination.deepLink) else {
                    onDismissReturnWelcome()
                    return
                }
                openReminderLink(url)
            },
            onDismiss: onDismissReturnWelcome
        ))
        // 고교 탭이 사라지는 순간 그 탭을 보고 있으면 빈 화면이 남는다.
        .onChange(of: showsHighSchool) { _, shows in
            if !shows, selection == .highSchool { selection = .pro }
        }
        // 카드를 무시하고도 실제 행동을 했다면 오래된 한 가지를 계속 붙잡지 않는다.
        .onChange(of: highSchool.result?.revision) { _, revision in
            if returnWelcomePlan != nil,
               let baseline = returnPlanHighSchoolRevision,
               revision != baseline {
                onDismissReturnWelcome()
            }
        }
        .onChange(of: pro.state?.revision) { _, revision in
            if returnWelcomePlan != nil,
               let baseline = returnPlanProRevision,
               revision != baseline {
                onDismissReturnWelcome()
            }
        }
        .onOpenURL { url in
            openReminderLink(url)
        }
        // 복귀 알림을 눌러 들어온 경로. `onOpenURL`은 알림 탭에서 불리지 않으므로
        // 이 다리가 없으면 알림이 홈 화면만 띄운다 — D1 훅의 마지막 한 걸음이 없는 셈이다.
        .task {
            if weekly.configure(eligibility: weeklyEligibility) {
                _ = highSchool.retryPendingGameCompletion()
            }
            NotificationRouter.shared.onDeepLink = { url in
                openReminderLink(url)
            }
            if let pending = NotificationRouter.shared.pendingDeepLink {
                NotificationRouter.shared.pendingDeepLink = nil
                openReminderLink(pending)
            }
        }
        .onChange(of: weeklyEligibility) { _, eligibility in
            if weekly.configure(eligibility: eligibility) {
                _ = highSchool.retryPendingGameCompletion()
            }
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
            let allowsLegacySourceMigration = pro.careerOrigin == nil
            let linksToCurrentHighSchool = pro.careerOrigin != .direct
                && highSchool.canAttachProLegacy(
                    pro.state,
                    sourceHighSchoolCareerID: pro.sourceHighSchoolCareerID,
                    allowsLegacySourceMigration: allowsLegacySourceMigration
                )
            ProCareerTabs(career: pro, retiresIntoSignatureLegacy: linksToCurrentHighSchool) {
                // 고교부터 프로 은퇴까지의 기록과 야구혼을 한 번에 저장한 뒤에만 프로
                // 저장본을 지운다. 저장 실패 때 원본 프로 커리어를 남겨 재시도할 수 있다.
                let recorded: Bool
                if linksToCurrentHighSchool {
                    recorded = highSchool.recordProLegacy(
                        pro.state,
                        sourceHighSchoolCareerID: pro.sourceHighSchoolCareerID,
                        allowsLegacySourceMigration: allowsLegacySourceMigration
                    )
                } else if pro.careerOrigin == .direct
                            || (pro.careerOrigin == nil && pro.sourceHighSchoolCareerID == nil) {
                    // 고교를 건너뛴 프로는 엉뚱한 진행에 후보를 붙이지 않고 야구혼만 계정에 남긴다.
                    recorded = highSchool.recordStandaloneProLegacy(pro.state)
                } else {
                    // 명시된 원본 고교와 현재 저장이 다르면 어느 쪽도 지우지 않는다.
                    recorded = false
                }
                guard recorded else { return }
                guard pro.deleteCareer() else { return }
                selection = .highSchool
            }
        }
    }
}

/// 앱을 다시 열었을 때 가장 먼저 보이는 한 가지. 출석 보상이 아니라 지난 플레이의
/// 미완성 장면을 그대로 이어 주며, 탭하면 문구와 일치하는 실제 화면으로 이동한다.
private struct ReturnWelcomeInset: ViewModifier {
    let plan: DailyReminder.Plan?
    let onShown: () -> Void
    let onContinue: (DailyReminder.Plan) -> Void
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            if let plan {
                ReturnWelcomeCard(
                    plan: plan,
                    onShown: onShown,
                    onContinue: { onContinue(plan) },
                    onDismiss: onDismiss
                )
                .id("\(plan.destination.rawValue):\(plan.reason)")
                .padding(.horizontal, BaseballMetrics.gutter)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilitySortPriority(10)
            }
        }
        .animation(.easeOut(duration: 0.22), value: plan)
    }
}

private struct ReturnWelcomeCard: View {
    let plan: DailyReminder.Plan
    let onShown: () -> Void
    let onContinue: () -> Void
    let onDismiss: () -> Void
    @State private var exposureLogged = false
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        BaseballCard(title: copyResolver.resolve(AppCopyKey.returnPlanCardTitle), tone: .milestone) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    GameCopyText(verbatim: resolvedPlanValue(
                        reference: plan.copyReferences?.title,
                        legacyValue: plan.title,
                        englishFallback: .notificationReturnTitle
                    ))
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(BaseballTheme.textPrimary)
                    Spacer(minLength: 0)
                    Button(action: dismissTapped) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .frame(width: BaseballMetrics.minimumTapTarget,
                                   height: BaseballMetrics.minimumTapTarget)
                    }
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .accessibilityLabel(copyResolver.resolve(AppCopyKey.returnPlanDismissAccessibility))
                    .accessibilityIdentifier("return.plan.dismiss")
                }
                GameCopyText(verbatim: resolvedPlanValue(
                    reference: plan.copyReferences?.body,
                    legacyValue: plan.body,
                    englishFallback: .notificationReturnBody
                ))
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                PrimaryPill(
                    title: copyResolver.resolve(continueTitleKey(for: plan.destination)),
                    identifier: "return.plan.continue",
                    action: continueTapped
                )
            }
        }
        .onAppear {
            guard !exposureLogged else { return }
            exposureLogged = true
            onShown()
            GameAnalytics.log(.returnPlanShown, DailyReminder.analyticsProperties(plan))
        }
        .accessibilityElement(children: .contain)
    }

    private func continueTapped() {
        GameAnalytics.log(.returnPlanTapped, DailyReminder.analyticsProperties(plan))
        DailyReminder.markWelcomeHandled(plan)
        onContinue()
    }

    private func dismissTapped() {
        GameAnalytics.log(.returnPlanDismissed, DailyReminder.analyticsProperties(plan))
        DailyReminder.markWelcomeHandled(plan)
        onDismiss()
    }

    private func resolvedPlanValue(
        reference: DailyReminder.SemanticCopyReference?,
        legacyValue: String,
        englishFallback: GameCopyKey
    ) -> String {
        if let reference, reference.schemaVersion == GameCopySchema.currentVersion {
            let resolved = copyResolver.resolve(reference)
            if resolved != GameCopyResolver.unavailableText { return resolved }
        }
        return copyResolver.language == .english
            ? copyResolver.resolve(englishFallback)
            : legacyValue
    }

    private func continueTitleKey(for destination: DailyReminder.Destination) -> GameCopyKey {
        switch destination {
        case .dailyInning: AppCopyKey.returnPlanContinueGame
        case .highSchool: AppCopyKey.returnPlanContinueHighSchool
        case .pro: AppCopyKey.returnPlanContinuePro
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
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                KeyArtHeader(
                    art: .proStadiumTunnel,
                    eyebrow: copyResolver.resolve(AppCopyKey.proLockedEyebrow),
                    title: copyResolver.resolve(AppCopyKey.proLockedTitle)
                )
                BaseballCard(title: copyResolver.resolve(AppCopyKey.proLockedPathTitle), tone: .raised) {
                    GameCopyText(AppCopyKey.proLockedPathBody)
                        .font(.subheadline)
                }
                // 잠긴 문 아래가 빈 검정이면 잠금이 벌처럼 느껴진다. 같은 공간이
                // "지금 평가가 당락선에서 몇 점 모자란가"를 말하면 목표판이 된다(QA P1-12 부분).
                if let forecast {
                    BaseballCard(title: copyResolver.resolve(AppCopyKey.proLockedDistanceTitle), tone: .milestone) {
                        VStack(alignment: .leading, spacing: 6) {
                            GameCopyText(verbatim: ProspectRankingPresentation.localizedForecastBand(
                                forecast,
                                resolver: copyResolver
                            ))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(forecast.score >= forecast.threshold ? BaseballTheme.action : BaseballTheme.textPrimary)
                            GameCopyText(
                                forecastCopyKey(for: remainingChapters),
                                arguments: forecastArguments(forecast: forecast, remainingChapters: remainingChapters)
                            )
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(BaseballTheme.textSecondary)
                            GameCopyText(
                                AppCopyKey.proLockedInterested,
                                arguments: [
                                    .userText(ProspectRankingPresentation.localizedForecastTeam(
                                        forecast,
                                        resolver: copyResolver
                                    )),
                                ]
                            )
                                .font(.caption)
                                .foregroundStyle(BaseballTheme.textTertiary)
                        }
                    }
                }
                // 건너뛰기는 본편을 한 번 완주한 사람의 문이다. 처음 켠 사람이 이 문으로
                // 들어가면 이 게임에서 가장 좋은 것(3년 육성·환생)을 못 본 채 평가한다.
                if hasFinishedALife {
                    Button(copyResolver.resolve(AppCopyKey.proLockedSkipButton)) { showsSetup = true }
                        .buttonStyle(.bordered)
                        .frame(minHeight: BaseballMetrics.minimumTapTarget)
                    GameCopyText(AppCopyKey.proLockedSkipDescription)
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textSecondary)
                } else {
                    GameCopyText(AppCopyKey.proLockedSkipLocked)
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textTertiary)
                }
            }
            .padding(BaseballMetrics.gutter)
        }
        .background(BaseballTheme.canvas)
        .navigationTitle(copyResolver.resolve(AppCopyKey.proNavigationTitle))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsSetup) {
            NavigationStack {
                CareerSetupView(career: pro)
                    .navigationTitle(copyResolver.resolve(AppCopyKey.proStartSheetTitle))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(copyResolver.resolve(AppCopyKey.actionCancel)) { showsSetup = false }
                        }
                    }
            }
        }
        .onChange(of: pro.loadState) { _, state in
            if state == .ready { showsSetup = false }
        }
    }

    private func forecastCopyKey(for remainingChapters: Int?) -> GameCopyKey {
        guard let remainingChapters else { return AppCopyKey.proLockedForecastBase }
        return remainingChapters > 0
            ? AppCopyKey.proLockedForecastChapters
            : AppCopyKey.proLockedForecastImminent
    }

    private func forecastArguments(
        forecast: HighSchoolCareerEngine.DraftForecastSnapshot,
        remainingChapters: Int?
    ) -> [LocalizedCopyArgument] {
        var arguments: [LocalizedCopyArgument] = [
            .integer(forecast.score),
            .integer(forecast.threshold),
        ]
        if let remainingChapters, remainingChapters > 0 {
            arguments.append(.integer(remainingChapters))
        }
        return arguments
    }
}

/// 프로 커리어 안의 오늘/이번 주 두 화면.
private struct ProCareerTabs: View {
    let career: MobileCareerStore
    let retiresIntoSignatureLegacy: Bool
    let onStartNewPlayer: () -> Void
    @State private var showsToday = true
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(spacing: 0) {
            Picker(copyResolver.resolve(AppCopyKey.proViewPicker), selection: $showsToday) {
                GameCopyText(AppCopyKey.proToday).tag(true)
                GameCopyText(AppCopyKey.proThisWeek).tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, BaseballMetrics.gutter)
            .padding(.vertical, 8)

            if showsToday {
                TodayView(career: career)
            } else {
                CareerFlowView(
                    career: career,
                    onStartNewPlayer: onStartNewPlayer,
                    retiresIntoSignatureLegacy: retiresIntoSignatureLegacy
                )
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
    @State private var confirmingReset = false
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        ContentUnavailableView {
            Label {
                GameCopyText(AppCopyKey.errorCareerOpenTitle)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
            }
        } description: {
            GameCopyText(verbatim: message)
        } actions: {
            PrimaryPill(title: copyResolver.resolve(AppCopyKey.errorRetry), identifier: "pro.retry") {
                career.retryRestoreOrReturn()
            }
            Button(copyResolver.resolve(AppCopyKey.errorReset), role: .destructive) {
                confirmingReset = true
            }
            .font(.footnote.weight(.semibold))
            .accessibilityIdentifier("pro.restart")
            .confirmationDialog(
                copyResolver.resolve(AppCopyKey.errorDeleteTitle),
                isPresented: $confirmingReset,
                titleVisibility: .visible
            ) {
                Button(copyResolver.resolve(AppCopyKey.errorDeleteAction), role: .destructive) {
                    _ = career.deleteCareer()
                }
                Button(copyResolver.resolve(AppCopyKey.errorCancel)) { confirmingReset = false }
            } message: {
                GameCopyText(AppCopyKey.errorDeleteMessage)
            }
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
                ContentUnavailableView {
                    Label {
                        GameCopyText(AppCopyKey.careerUnavailable)
                    } icon: {
                        Image(systemName: "baseball")
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(BaseballTheme.canvas)
    }
}

private struct TodayDashboard: View {
    let state: ProCareerSnapshot
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                KeyArtHeader(
                    // 1군 데뷔와 은퇴는 커리어에 한 번뿐이라 전용 그림을 준다.
                    art: state.phase == .completed ? .retirement
                        : state.level == .major ? .majorDebut : .stadiumNight,
                    eyebrow: copyResolver.resolve(
                        AppCopyKey.proSeasonHeader,
                        arguments: [
                            .integer(state.season),
                            .integer(state.week),
                            .userText(Self.segmentText(state.seasonSegment, resolver: copyResolver)),
                        ]
                    ),
                    title: copyResolver.resolve(
                        AppCopyKey.proDashboardTitle,
                        arguments: [
                            .userText(state.team.name),
                            .userText(copyResolver.resolve(state.level.displayCopyToken)),
                            .userText(copyResolver.resolve(state.role.displayCopyToken)),
                        ]
                    ),
                    accent: BaseballTheme.teamDecoration(state.team.id)
                )

                SeasonArcBar(segment: state.seasonSegment, week: state.week)

                HStack(spacing: 10) {
                    // 프로가 된 그 얼굴 — 고교 대시보드와 같은 자리, 자란 모습이다.
                    PortraitView(seed: state.identity.name, role: .player, size: 46, playerStage: .pro)
                    Metric(
                        title: copyResolver.resolve(AppCopyKey.proFatigueLabel),
                        value: "\(state.fatigue)",
                        tone: state.fatigue >= 70 ? .warning : .standard
                    )
                    Metric(
                        title: copyResolver.resolve(AppCopyKey.proManagerTrustLabel),
                        value: "\(state.managerTrust)",
                        tone: state.managerTrust >= 60 ? .positive : .standard
                    )
                    Metric(
                        title: copyResolver.resolve(AppCopyKey.proInjuryLabel),
                        value: state.injuryWeeks > 0
                            ? copyResolver.resolve(AppCopyKey.proInjuryWeeks, arguments: [.integer(state.injuryWeeks)])
                            : copyResolver.resolve(AppCopyKey.proInjuryNormal),
                        tone: state.injuryWeeks > 0 ? .negative : .standard
                    )
                }

                BaseballCard(title: copyResolver.resolve(AppCopyKey.proNextActionTitle), tone: .raised) {
                    GameCopyText(Self.actionKey(state.phase)).font(.body.weight(.semibold))
                }

                if let tensions = state.seasonTensions, !tensions.isEmpty {
                    BaseballCard(title: copyResolver.resolve(AppCopyKey.proTensionsTitle)) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(tensions.enumerated()), id: \.offset) { _, tension in
                                VStack(alignment: .leading, spacing: 2) {
                                    GameCopyText(verbatim: tension.title).font(.subheadline.weight(.semibold))
                                    GameCopyText(verbatim: tension.detail)
                                        .font(.footnote)
                                        .foregroundStyle(BaseballTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }

                if let rival = state.currentRival {
                    BaseballCard(title: copyResolver.resolve(AppCopyKey.proRivalTitle), tone: .warning) {
                        HStack(spacing: 10) {
                            // 고교 라이벌 카드와 같은 문법 — 상대에게 얼굴이 있어야 승부다.
                            PortraitView(seed: rival.name, role: .rival, size: 46)
                            VStack(alignment: .leading, spacing: 4) {
                                GameCopyText(verbatim: "\(rival.name) · \(rival.teamName)").font(.headline)
                                GameCopyText(verbatim: rival.archetype)
                                    .font(.subheadline)
                                    .foregroundStyle(BaseballTheme.textSecondary)
                                GameCopyText(verbatim: rival.record)
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(BaseballTheme.textSecondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                if let milestone = state.milestones.last {
                    BaseballCard(title: copyResolver.resolve(AppCopyKey.proMilestoneTitle), tone: .milestone) {
                        Label {
                            GameCopyText(verbatim: milestone)
                        } icon: {
                            Image(systemName: "star.fill")
                        }
                        .foregroundStyle(BaseballTheme.milestone)
                    }
                }

                // 3주를 한 번에 건너뛰어도(`advanceBlock`) 그 사이의 등판이 여기 남는다.
                // 예전에는 뉴스 한 줄로 증발해서 시즌이 통째로 기억에 남지 않았다.
                if let line = state.gameLines?.last {
                    BaseballCard(title: copyResolver.resolve(AppCopyKey.proLatestOutingTitle)) {
                        VStack(alignment: .leading, spacing: 8) {
                            if line.played {
                                GameCopyText(AppCopyKey.proDirectOuting).eyebrowStyle(BaseballTheme.action)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(GameLineFormat.score(line))
                                    .font(BaseballType.scoreboard)
                                    .foregroundStyle(BaseballTheme.textPrimary)
                                if let decisionKey = Self.decisionKey(line.decision) {
                                    GameCopyText(decisionKey)
                                        .font(.headline.weight(.heavy))
                                        .foregroundStyle(GameLineFormat.decisionTone(line.decision))
                                }
                                Spacer()
                                GameCopyText(
                                    AppCopyKey.proOutingWeek,
                                    arguments: [.integer(line.week)]
                                )
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(BaseballTheme.textTertiary)
                            }
                            GameCopyText(
                                Self.outingSummaryKey(line),
                                arguments: Self.outingSummaryArguments(line, language: copyResolver.language)
                            )
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(BaseballTheme.textSecondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Self.outingAccessibility(
                            line,
                            resolver: copyResolver
                        ))
                        .accessibilityIdentifier("today.lastOuting")
                    }
                }

                BaseballCard(title: copyResolver.resolve(AppCopyKey.proLatestNewsTitle)) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(state.news.prefix(3).enumerated()), id: \.offset) { _, item in
                            GameCopyText(verbatim: item)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(BaseballMetrics.gutter)
        }
        .background(BaseballTheme.canvas)
        // 고교 화면과 같은 이유 — 내비게이션 바가 없어 스크롤한 본문이 시계와 겹친다.
        .topStatusScrim()
    }

    private static func segmentText(
        _ segment: ProSeasonSegment?,
        resolver: GameCopyResolver
    ) -> String {
        guard let segment else {
            return resolver.resolve(AppCopyKey.proSegmentPreparation)
        }
        return resolver.resolve(segment.displayCopyToken)
    }

    static func segmentLabel(_ segment: ProSeasonSegment?) -> String {
        segmentText(
            segment,
            resolver: GameCopyResolver(language: .korean, policy: .releaseSafe)
        )
    }

    private static func actionKey(_ phase: ProCareerPhase) -> GameCopyKey {
        // "커리어 탭"은 존재하지 않는다 — 탭 바에는 고교/프로/기록/설정뿐이고, 실제로는
        // 프로 화면 위의 "이번 주" 세그먼트다. 없는 곳을 가리키면 처음 온 사람이 길을 잃는다.
        switch phase {
        case .weeklyPlan: AppCopyKey.proActionWeeklyPlan
        case .importantGame: AppCopyKey.proActionImportantGame
        case .seasonReview: AppCopyKey.proActionSeasonReview
        case .offseasonDecision: AppCopyKey.proActionOffseasonDecision
        default: AppCopyKey.proActionDefault
        }
    }

    static func actionText(_ phase: ProCareerPhase) -> String {
        GameCopyResolver(language: .korean, policy: .releaseSafe).resolve(actionKey(phase))
    }

    private static func outingRoleKey(_ line: ProGameLine) -> GameCopyKey {
        line.started ? AppCopyKey.proRoleStarter : AppCopyKey.proRoleReliever
    }

    private static func outingSummaryKey(_ line: ProGameLine) -> GameCopyKey {
        line.hits == nil ? AppCopyKey.proOutingSummary : AppCopyKey.proOutingSummaryHits
    }

    private static func outingSummaryArguments(
        _ line: ProGameLine,
        language: AppLanguage
    ) -> [LocalizedCopyArgument] {
        let role = GameCopyResolver(language: language, policy: .releaseSafe)
            .resolve(outingRoleKey(line))
        let innings = GameFormatters.innings(outs: line.outs, language: language)
        var arguments: [LocalizedCopyArgument] = [
            .userText(role),
            .userText(innings),
        ]
        if let hits = line.hits {
            arguments.append(.integer(hits))
        }
        arguments.append(contentsOf: [
            .integer(line.strikeouts),
            .integer(line.walks),
            .integer(line.runsAllowed),
        ])
        return arguments
    }

    private static func decisionKey(_ decision: PitchingDecision) -> GameCopyKey? {
        switch decision {
        case .win: AppCopyKey.proDecisionWin
        case .loss: AppCopyKey.proDecisionLoss
        case .save: AppCopyKey.proDecisionSave
        case .noDecision: nil
        }
    }

    private static func outingAccessibility(
        _ line: ProGameLine,
        resolver: GameCopyResolver
    ) -> String {
        let role = resolver.resolve(outingRoleKey(line))
        let innings = GameFormatters.innings(outs: line.outs, language: resolver.language)
        var arguments: [LocalizedCopyArgument] = [
            .integer(line.week),
            .userText(role),
            .userText(innings),
            .userText(resolver.resolve(
                outingSummaryKey(line),
                arguments: outingSummaryArguments(line, language: resolver.language)
            )),
            .integer(line.teamRuns),
            .integer(line.opponentRuns),
        ]
        if let decisionKey = decisionKey(line.decision) {
            arguments.append(.userText(resolver.resolve(decisionKey)))
        }
        let key: GameCopyKey
        switch (decisionKey(line.decision), line.played) {
        case (nil, false): key = AppCopyKey.proOutingAccessibility
        case (nil, true): key = AppCopyKey.proOutingAccessibilityPlayed
        case (.some, false): key = AppCopyKey.proOutingAccessibilityDecision
        case (.some, true): key = AppCopyKey.proOutingAccessibilityDecisionPlayed
        }
        return resolver.resolve(key, arguments: arguments)
    }
}

/// 24주 시즌 안에서 지금 어디쯤인지 보여 준다. 주 단위 진행 게임의 위치 감각을 만든다.
private struct SeasonArcBar: View {
    let segment: ProSeasonSegment?
    let week: Int
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                GameCopyText(AppCopyKey.proSeasonProgressTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textSecondary)
                Spacer()
                GameCopyText(
                    AppCopyKey.proSeasonProgressValue,
                    arguments: [.integer(min(week, 24))]
                )
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textSecondary)
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
        .accessibilityLabel(copyResolver.resolve(
            AppCopyKey.proSeasonProgressAccessibility,
            arguments: [.integer(min(week, 24))]
        ))
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
