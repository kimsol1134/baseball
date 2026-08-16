import SwiftUI
import UIKit
import SimulationCore

@main
struct BaseballApp: App {
    init() {
        // 새 설치의 기본 투구는 수동 슬라이더다. 등록 기본값은 이미 저장된 접근성 선택을
        // 덮어쓰지 않으므로 자동 릴리스를 직접 켠 사용자는 그대로 유지된다.
        PitchControlPreferences.registerDefaults()
        // 분석은 설정이 있을 때만 켜진다 — 없으면 이 호출은 무동작이다.
        GameAnalytics.configure()

#if DEBUG
        let proConfiguration = ProcessInfo.processInfo.arguments.contains(
            Self.proCareerJourneyLaunchArgument
        ) ? AppFeatureConfiguration.journeyV1Tests : .production
#else
        let proConfiguration = AppFeatureConfiguration.production
#endif
        _pro = State(initialValue: MobileCareerStore(configuration: proConfiguration))
    }

    /// UI 스모크 테스트가 저장된 커리어를 지우고 첫 실행 상태에서 시작하도록 하는 인자.
    nonisolated static let resetLaunchArgument = "-uiTestResetCareer"
    /// UI 테스트가 타이밍 제스처 없이 흐름을 통과하도록 자동 릴리스를 켠다.
    nonisolated static let autoReleaseLaunchArgument = "-uiTestAutoRelease"
    /// 다음 행동 복귀 실험과 투구 피드백 실험을 한 배포에 섞지 않는다.
    /// 투구 피드백은 별도 QA에서만 켜고, 제품 노출은 다음 실험 빌드에서 결정한다.
    nonisolated static let pitchAbilityFeedbackLaunchArgument = "-uiTestPitchAbilityFeedback"
    /// 홍보 영상 촬영용. XCUITest는 자동화를 빠르게 하려고 대상 앱의 애니메이션을 꺼 버리는데,
    /// 그러면 승부 장면이 최종 프레임으로 튀어 녹화에 아무것도 남지 않는다. 촬영할 때만 되돌린다.
    nonisolated static let promoLaunchArgument = "-uiTestPromoCapture"
    /// App Store 원본 촬영에서는 제품 UI만 남기고 상태 막대·홈 인디케이터를 숨긴다.
    /// 이 인자는 UI 테스트가 명시적으로 전달할 때만 작동하며 제품 상태나 저장에는 관여하지 않는다.
    nonisolated static let storeCaptureLaunchArgument = "-uiTestStoreCapture"
#if DEBUG
    /// iOS UI acceptance only. Release builds do not compile an argument path that enables the
    /// journey rollout gate.
    nonisolated static let proCareerJourneyLaunchArgument = "-uiTestProCareerJourneyV1"
    /// 지명 완료 화면 → 프로 진입을 밸런스 시드와 분리해 검증하는 Debug 전용 픽스처.
    nonisolated static let draftedCareerFixtureLaunchArgument = "-uiTestDraftedCareerFixture"
    /// 미지명 직전 → 유산 → 환생을 실제 엔진 결과로 촬영하는 Debug 전용 픽스처.
    nonisolated static let undraftedCareerFixtureLaunchArgument = "-uiTestUndraftedCareerFixture"
#endif

    @Environment(\.scenePhase) private var scenePhase
    @State private var highSchool = HighSchoolCareerStore()
    @State private var pro: MobileCareerStore
    @State private var remoteChangeObserver: NSObjectProtocol?
    /// 앱이 뜨기 전 저장돼 있던 계획. 초기 `.active` 전환이 알림을 새로 짜도 이 값은
    /// 보존되어 첫 설치와 실제 복귀를 구분한다.
    @State private var previousReturnPlan = DailyReminder.storedPlan()
    /// 지난 세션이 있었을 때만 앱 안에 보여 줄 현재의 이어하기 한 가지.
    @State private var returnWelcomePlan: DailyReminder.Plan?
    /// 시스템 Launch Screen 뒤에서도 현재 앱 언어의 제목을 최소 한 박자 보장한다.
    /// 저장 복원이 아주 빨라도 이 화면이 사라지지 않아 오래된 시스템 스냅샷이 보이는 문제를
    /// 앱이 직접 덮어쓴다.
    @State private var isPresentingLocalizedLaunch = true
    /// 이번 세션이 언제 시작됐는가. 세션 깊이(분·진행)를 재는 데만 쓴다.
    @State private var sessionStartedAt = Date()
    @State private var sessionStartedGames = 0

    /// 세션이 끝날 때 깊이를 남긴다.
    ///
    /// 왜 필요한가: 2026-08 데이터에서 1인당 34.6이벤트·10.6경기였는데, 그게 **한 세션**의
    /// 값인지 여러 번 나눠 온 값인지 구분할 수 없었다. "첫 세션에 1회차를 통째로 끝내고
    /// 떠난다"는 진단은 개별 유저 프로필을 눈으로 읽어서 세운 가설이었다. 이 이벤트가
    /// 그 가설을 집계로 바꾼다.
    private func logSessionEnd() {
        let minutes = Int(Date().timeIntervalSince(sessionStartedAt) / 60)
        let currentGames = GameAnalytics.completedGameCount()
        let isReturnEligible = DailyReminder.ReturnPlanEligibility.isEligible(
            completedGameCount: currentGames
        )
        let returnPlan: DailyReminder.Plan?
        if isReturnEligible, let returnContext = resolvedReturnContext() {
            let prepared = DailyReminder.preparedForNextReturn(
                returnContext.plan,
                rulesVersion: returnContext.developmentRulesVersion
            )
            returnPlan = prepared
            let returnProperties = DailyReminder.analyticsProperties(prepared)
            GameAnalytics.logOnce(
                .returnPlanEligible,
                scope: prepared.receiptID ?? "legacy",
                properties: returnProperties
            )
        } else {
            returnPlan = nil
        }
        var sessionProperties: [String: Any] = [
            "minutes": minutes,
            "life_number": highSchool.state?.lifeNumber ?? highSchool.inheritance.lifeNumber,
            "games": max(0, currentGames - sessionStartedGames),
            "important_games_total": highSchool.state?.performance.importantGamesCompleted ?? 0,
            "phase": highSchool.state?.phase.rawValue ?? "none",
            "act_number": highSchool.state.map {
                HighSchoolPresentation.actNumber(chapter: $0.chapter.number)
            } ?? 0,
            "lives_finished": highSchool.archive.count,
        ]
        sessionProperties.merge(
            DailyReminder.sessionEndReturnProperties(
                plan: returnPlan, completedGameCount: currentGames
            )
        ) { _, current in current }
        GameAnalytics.log(.sessionEnded, sessionProperties)
        // 사용자가 떠나는 바로 그 상태가 내일의 문장이어야 한다. 앱을 다시 열 때까지
        // 바뀌지 않는 로컬 계획이라 서버·개인정보 없이도 구체적인 이어하기가 된다.
        DailyReminder.refresh(plan: returnPlan)
    }

    private func resolvedReturnContext() -> (plan: DailyReminder.Plan, developmentRulesVersion: Int)? {
        guard let plan = currentReturnPlan() else { return nil }
        return (
            plan,
            Self.developmentRulesVersion(
                for: plan.destination,
                proRulesVersion: pro.state?.balanceVersion,
                highSchoolRulesVersion: highSchool.state?.balanceVersion
            )
        )
    }

    private func resolvedReturnPlan() -> DailyReminder.Plan? {
        resolvedReturnContext()?.plan
    }

    /// 복귀 목적지와 같은 커리어의 규칙 버전을 써야 eligibility → cold start →
    /// game_finished가 한 코호트로 이어진다. 남아 있는 고교 저장보다 활성 프로가 우선인
    /// 사용자도 있으므로 목적지를 먼저 확정한다. 제거 전 목적지는 호환용 현재 규칙을 쓴다.
    static func developmentRulesVersion(
        for destination: DailyReminder.Destination,
        proRulesVersion: Int?,
        highSchoolRulesVersion: Int?
    ) -> Int {
        switch destination {
        case .pro:
            proRulesVersion ?? PitcherPresetCatalog.balanceVersion
        case .highSchool:
            highSchoolRulesVersion ?? PitcherPresetCatalog.balanceVersion
        case .dailyInning:
            PitcherPresetCatalog.balanceVersion
        }
    }

    /// 첫날 11.6경기·2.2회차를 자발적으로 소화한 신규 유저에게 필요한 것은 플레이 제한이
    /// 아니라 다음날 이어 할 구체적인 한 가지였다. 현재 약속을 최우선으로, 그다음 진행
    /// 국면과 프로 시즌을 사용한다.
    private func currentReturnPlan() -> DailyReminder.Plan? {
        if pro.loadState == .ready, let state = pro.state, state.phase != .completed {
            let bodyKey: GameCopyKey
            switch state.phase {
            case .seasonDecision: bodyKey = AppCopyKey.returnPlanBodyProSeasonDecision
            case .importantGame: bodyKey = AppCopyKey.returnPlanBodyProImportantGame
            case .retirementDecision: bodyKey = AppCopyKey.returnPlanBodyProRetirement
            default: bodyKey = AppCopyKey.returnPlanBodyProDefault
            }
            return Self.makeReturnPlan(
                titleKey: AppCopyKey.returnPlanTitlePro,
                bodyKey: bodyKey,
                destination: .pro,
                reason: "pro_phase"
            )
        }

        // 기록에 남지 않는 도전은 재실행 때 보존되지 않는다. 다음날 이어진다고 약속하면
        // 알림 문구와 실제 도착 상태가 달라지므로 복귀 계획을 만들지 않는다.
        if highSchool.isChallengeRun { return nil }

        if let state = highSchool.state {
            if state.draftResult == nil, let pledge = highSchool.pledge {
                let progress = pledge.progress(in: .init(
                    state: state, rivalLedger: highSchool.rivalLedger
                ))
                return Self.makeReturnPlan(
                    titleKey: AppCopyKey.returnPlanTitlePledge,
                    bodyKey: AppCopyKey.returnPlanBodyPledge,
                    bodyArguments: [.userText(pledge.title), .userText(progress.line)],
                    destination: .highSchool,
                    reason: "run_pledge"
                )
            }

            if (state.phase == .legacy || state.phase == .completed),
               let intent = highSchool.nextRunIntent,
               let pledge = RunPledge.pledge(id: intent.pledgeID) {
                return Self.makeReturnPlan(
                    titleKey: AppCopyKey.returnPlanTitleNextPlayer,
                    bodyKey: AppCopyKey.returnPlanBodyNextPlayer,
                    bodyArguments: [.userText(pledge.title)],
                    destination: .highSchool,
                    reason: "next_run_intent"
                )
            }

            return Self.makeReturnPlan(
                titleKey: AppCopyKey.returnPlanTitleHighSchoolPhase,
                bodyKey: Self.returnPlanBodyKey(for: state.phase),
                destination: .highSchool,
                reason: "high_school_phase"
            )
        }

        if let intent = highSchool.nextRunIntent,
           let pledge = RunPledge.pledge(id: intent.pledgeID) {
            return Self.makeReturnPlan(
                titleKey: AppCopyKey.returnPlanTitleNextPlayer,
                bodyKey: AppCopyKey.returnPlanBodyNextPlayer,
                bodyArguments: [.userText(pledge.title)],
                destination: .highSchool,
                reason: "next_run_intent"
            )
        }
        return nil
    }

    /// 복귀 카드가 약속하는 문장은 현재 화면의 실제 주 행동과 같아야 한다.
    static func highSchoolReturnDetail(for phase: HighSchoolCareerPhase) -> String {
        GameCopyResolver(language: .korean, policy: .releaseSafe)
            .resolve(returnPlanBodyKey(for: phase))
    }

    private static func returnPlanBodyKey(for phase: HighSchoolCareerPhase) -> GameCopyKey {
        switch phase {
        case .prologue: AppCopyKey.returnPlanBodyPrologue
        case .schoolSelection: AppCopyKey.returnPlanBodySchoolSelection
        case .training: AppCopyKey.returnPlanBodyTraining
        case .relationship: AppCopyKey.returnPlanBodyRelationship
        case .importantGame: AppCopyKey.returnPlanBodyImportantGame
        case .awakening: AppCopyKey.returnPlanBodyAwakening
        case .chapterReview: AppCopyKey.returnPlanBodyChapterReview
        case .draft: AppCopyKey.returnPlanBodyDraft
        case .legacy: AppCopyKey.returnPlanBodyLegacy
        case .completed: AppCopyKey.returnPlanBodyCompleted
        }
    }

    private static func makeReturnPlan(
        titleKey: GameCopyKey,
        titleArguments: [LocalizedCopyArgument] = [],
        bodyKey: GameCopyKey,
        bodyArguments: [LocalizedCopyArgument] = [],
        destination: DailyReminder.Destination,
        reason: String
    ) -> DailyReminder.Plan {
        let titleToken = LocalizedCopyToken(key: titleKey, arguments: titleArguments)
        let bodyToken = LocalizedCopyToken(key: bodyKey, arguments: bodyArguments)
        let koreanResolver = GameCopyResolver(language: .korean, policy: .releaseSafe)
        return DailyReminder.Plan(
            title: koreanResolver.resolve(titleToken),
            body: koreanResolver.resolve(bodyToken),
            destination: destination,
            reason: reason,
            copyReferences: DailyReminder.NotificationCopyReferences(
                title: semanticReference(for: titleToken),
                body: semanticReference(for: bodyToken)
            )
        )
    }

    private static func semanticReference(
        for token: LocalizedCopyToken
    ) -> DailyReminder.SemanticCopyReference {
        DailyReminder.SemanticCopyReference(
            key: token.key.rawValue,
            arguments: token.arguments.map { argument in
                switch argument {
                case .userText(let value): .userText(value)
                case .contentID(let value): .contentID(value)
                case .integer(let value): .integer(value)
                case .decimal(let value): .decimal(value)
                }
            }
        )
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                AppShell(
                    highSchool: highSchool,
                    pro: pro,
                    returnWelcomePlan: returnWelcomePlan,
                    onDismissReturnWelcome: { returnWelcomePlan = nil }
                )

                if isPresentingLocalizedLaunch {
                    AppLoadingView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
                // 디자인 시스템은 다크 전용이다(design-system.css의 `color-scheme: dark`).
                // 기기 설정을 따라가면 라이트 모드에서 "Midnight Dugout" 방향이 통째로 사라진다.
                .preferredColorScheme(.dark)
                .statusBarHidden(
                    ProcessInfo.processInfo.arguments.contains(Self.storeCaptureLaunchArgument)
                )
                .persistentSystemOverlays(
                    ProcessInfo.processInfo.arguments.contains(Self.storeCaptureLaunchArgument)
                        ? .hidden : .automatic
                )
                .environment(\.gameCopyResolver, GameCopyResolver())
                .task {
                    let minimumLaunchPresentation = Task {
                        try? await Task.sleep(for: .milliseconds(700))
                    }
                    let arguments = ProcessInfo.processInfo.arguments
                    if arguments.contains(Self.promoLaunchArgument) {
                        UIView.setAnimationsEnabled(true)
                    }
                    if arguments.contains(Self.resetLaunchArgument) {
                        // The stores restore lazily. Load the existing records before asking the
                        // normal delete paths to write their tombstones; otherwise a reset can
                        // leave an old Pro record in place when `result` is still nil.
                        highSchool.restoreOrCreate()
                        pro.restoreOrCreateCareer()
                        _ = highSchool.deleteCareer()
                        _ = pro.deleteCareer()
                        GameAnalytics.resetCompletedGameCountForUITesting()
                        DailyReminder.resetForUITesting()
                        // `previousReturnPlan`은 App 초기화 때 이미 읽힌 값이라 defaults만 지워서는
                        // 이번 화면에 남는다. 메모리 사본도 같은 원자적 초기화에 포함한다.
                        previousReturnPlan = nil
                        returnWelcomePlan = nil
                        // 설정도 함께 되돌린다. 앞선 실행이 남긴 자동 릴리스가 다음 테스트로
                        // 새면 조작 경로가 통째로 달라진다.
                        UserDefaults.standard.set(
                            arguments.contains(Self.autoReleaseLaunchArgument),
                            forKey: PitchControlPreferences.autoReleaseKey
                        )
#if DEBUG
                        if arguments.contains(Self.draftedCareerFixtureLaunchArgument) {
                            _ = highSchool.installDraftedCareerFixtureForUITesting()
                        } else if arguments.contains(Self.undraftedCareerFixtureLaunchArgument) {
                            _ = highSchool.installUndraftedDraftFixtureForUITesting()
                        }
#endif
                    } else if arguments.contains(Self.autoReleaseLaunchArgument) {
                        UserDefaults.standard.set(true, forKey: PitchControlPreferences.autoReleaseKey)
                    }
                    highSchool.restoreOrCreate()
                    pro.restoreOrCreateCareer()
                    sessionStartedGames = GameAnalytics.completedGameCount()
                    GameAudio.shared.start()
                    AchievementStore.shared.authenticate()
                    SaveSync.prime()
                    // 알림 응답을 받으려면 첫 화면이 뜨기 전에 델리게이트가 붙어 있어야
                    // 한다 — 늦게 붙으면 앱을 깨운 그 알림의 응답이 사라진다.
                    NotificationRouter.shared.register()
                    let hasCompletedGame = DailyReminder.ReturnPlanEligibility.isEligible(
                        completedGameCount: GameAnalytics.completedGameCount()
                    )
                    if hasCompletedGame, let coldStart = DailyReminder.nextDayOpenProperties(
                        previousReturnPlan, launchType: "cold"
                    ), let scope = DailyReminder.nextDayOpenScope(properties: coldStart) {
                        GameAnalytics.logOnce(
                            .returnPlanNextDayOpen, scope: scope, properties: coldStart
                        )
                        GameAnalytics.logOnce(
                            .returnPlanColdStart, scope: scope, properties: coldStart
                        )
                    }
                    if hasCompletedGame {
                        let currentPlan = resolvedReturnPlan()
                        returnWelcomePlan = DailyReminder.welcomePlan(
                            previous: previousReturnPlan,
                            current: currentPlan,
                            handled: DailyReminder.storedWelcomeHandled()
                        )
                        previousReturnPlan = currentPlan?.carryingReceipt(from: previousReturnPlan)
                        DailyReminder.refresh(plan: currentPlan)
                    } else {
                        // A first launch must not manufacture a return plan or show a stale one
                        // left by an older install whose local completion counter is empty.
                        returnWelcomePlan = nil
                        previousReturnPlan = nil
                        DailyReminder.refresh(plan: nil)
                    }
                    _ = await minimumLaunchPresentation.value
                    withAnimation(.easeOut(duration: 0.2)) {
                        isPresentingLocalizedLaunch = false
                    }
                }
                .task {
                    // 다른 기기에서 올라온 진행을 받아 화면을 갱신한다.
                    remoteChangeObserver = SaveSync.observeRemoteChanges {
                        highSchool.reloadFromSync()
                        pro.reloadFromSync()
                    }
                }
                .onChange(of: scenePhase) { previous, phase in
                    if phase == .active {
                        GameAudio.shared.start()
                        SaveSync.prime()
                        // 백그라운드에서 **돌아온** 때만 세션 시계를 다시 건다. 배너 하나에
                        // 시계가 초기화되면 긴 세션이 짧게 잡힌다.
                        if previous == .background {
                            let storedPlan = DailyReminder.storedPlan()
                            let hasCompletedGame = DailyReminder.ReturnPlanEligibility.isEligible(
                                completedGameCount: GameAnalytics.completedGameCount()
                            )
                            if hasCompletedGame, let warmOpen = DailyReminder.nextDayOpenProperties(
                                storedPlan, launchType: "warm"
                            ), let scope = DailyReminder.nextDayOpenScope(properties: warmOpen) {
                                GameAnalytics.logOnce(
                                    .returnPlanNextDayOpen, scope: scope, properties: warmOpen
                                )
                            }
                            if hasCompletedGame {
                                let currentPlan = resolvedReturnPlan()
                                returnWelcomePlan = DailyReminder.welcomePlan(
                                    previous: storedPlan,
                                    current: currentPlan,
                                    handled: DailyReminder.storedWelcomeHandled()
                                )
                                previousReturnPlan = currentPlan?.carryingReceipt(from: storedPlan)
                                DailyReminder.refresh(plan: currentPlan)
                            } else {
                                returnWelcomePlan = nil
                                previousReturnPlan = nil
                                DailyReminder.refresh(plan: nil)
                            }
                            sessionStartedAt = Date()
                            sessionStartedGames = GameAnalytics.completedGameCount()
                        }
                    } else {
                        highSchool.save()
                        pro.save()
                        GameAudio.shared.stop()
                        // **`.background`에서만** 센다. `.inactive`는 알림 배너·앱 전환기·
                        // 시스템 시트에서도 스쳐 지나가므로, 거기서 세면 한 세션이 여러
                        // 개의 짧은 세션으로 쪼개져 세션 깊이가 통째로 거짓이 된다.
                        if phase == .background {
                            logSessionEnd()
                            // 다시 돌아올 때 카드를 새 세션 노출로 재평가한다. 사용자가 이미
                            // 처리한 같은 목표는 서울 날짜 기준 억제 기록이 막아 준다.
                            returnWelcomePlan = nil
                        }
                    }
                }
        }
    }
}
