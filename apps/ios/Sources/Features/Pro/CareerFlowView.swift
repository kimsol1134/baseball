import SwiftUI
import SimulationCore
import BaseballIOSDomain


struct CareerFlowView: View {
    let career: MobileCareerStore
    /// 은퇴 뒤 새 선수로 시작한다. 프로 저장본을 지우고 고교 탭으로 돌려보낸다.
    var onStartNewPlayer: () -> Void = {}
    var retiresIntoSignatureLegacy = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.gameCopyResolver) private var copyResolver
    @State private var dismissedFollowUpIDs: Set<String> = []
    @State private var dismissedBanner = false

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView { CareerSummary(career: career) } detail: { decision }
            } else {
                decision
            }
        }
        .toolbar(.hidden, for: .navigationBar)
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
                switch state.phase {
                case .contractOffer:
                    // 서명 버튼을 탭 바 위에 고정하려면 `safeAreaInset`이 ScrollView 밖에
                    // 붙어야 한다. 계약 화면은 스크롤과 하단 바를 직접 가진다(페르소나 §2-1).
                    ProContractOfferView(
                        career: career,
                        state: state,
                        notices: CareerFlowNotices(
                            career: career,
                            state: state,
                            notice: CareerNoticeQueue.current(
                                hasInjury: career.pendingInjuryEvent != nil,
                                hasGrowth: !career.pendingGains.isEmpty
                                    && !CareerFlowNotices.settlementOwnsGrowth(state),
                                followUps: [],
                                hasBanner: false
                            ),
                            bannerText: nil,
                            onDismissFollowUp: { _ in },
                            onDismissBanner: {}
                        )
                    )
                    .background(BaseballTheme.canvas)
                    .animation(reduceMotion ? nil : .snappy, value: career.feedbackTrigger)
                default:
                    phaseScroll(state)
                }
            }
        } else {
            ProgressView()
        }
    }

    @ViewBuilder private func phaseScroll(_ state: ProCareerSnapshot) -> some View {
        let weekProgress = career.lastSummary.flatMap(ProCareerPresentation.weekProgress)
        let bannerText = CareerFlowNotices.bannerText(
            career.lastSummary,
            weekProgress: weekProgress,
            state: state,
            resolver: copyResolver
        )
        let notice = CareerNoticeQueue.current(
            hasInjury: career.pendingInjuryEvent != nil,
            hasGrowth: !career.pendingGains.isEmpty && !CareerFlowNotices.settlementOwnsGrowth(state),
            followUps: (state.resolvedFollowUps ?? []).filter { !dismissedFollowUpIDs.contains($0.id) },
            hasBanner: bannerText != nil && !dismissedBanner
        )
        ScrollView {
            VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                if state.phase == .weeklyPlan {
                    ProCareerStatusHeader(state: state)
                }
                CareerFlowNotices(
                    career: career,
                    state: state,
                    notice: notice,
                    bannerText: bannerText,
                    onDismissFollowUp: { dismissedFollowUpIDs.insert($0) },
                    onDismissBanner: { dismissedBanner = true }
                )
                let settlementOwnsGrowth = CareerFlowNotices.settlementOwnsGrowth(state)

                // 국면 화면은 하나만 그린다. `.animation(value: feedbackTrigger)`가 걸린 컨테이너 안에서
                // 국면이 바뀌면 SwiftUI가 옛 화면과 새 화면을 같은 자리에 겹쳐 크로스페이드했고,
                // 그 반투명 겹침이 "화면이 어긋나서 글자가 깨진다"(1.0.x 리뷰)로 보였다.
                // 국면을 identity로 못 박고 전환을 끄면 겹치는 프레임 자체가 없다.
                Group {
                if settlementOwnsGrowth {
                    ProSeasonSettlementView(
                        career: career,
                        state: state,
                        pendingGains: career.pendingGains,
                        onAcknowledgeGains: career.acknowledgeGains
                    )
                        .background(BaseballTheme.canvas)
                } else {
                    switch state.phase {
                    case .offseasonInvestment:
                        ProOffseasonInvestmentView(career: career, state: state)
                    case .weeklyPlan:
#if DEBUG
                        if ProcessInfo.processInfo.environment["BASEBALL_UI_RECORD_SHARE"] == "1" {
                            recordShareCaptureCards(state: state)
                        } else {
                            WeeklyPlanView(
                                career: career,
                                state: state,
                                weekProgress: weekProgress,
                                hidesFollowUps: true,
                                pendingNotice: notice != nil,
                                onAcknowledgeNotice: {
                                    acknowledge(notice, state: state)
                                }
                            )
                        }
#else
                        WeeklyPlanView(
                            career: career,
                            state: state,
                            weekProgress: weekProgress,
                            hidesFollowUps: true,
                            pendingNotice: notice != nil,
                            onAcknowledgeNotice: {
                                acknowledge(notice, state: state)
                            }
                        )
#endif
                    case .seasonDecision:
                        if let pending = state.pendingDecision {
                            ProSeasonDecisionView(career: career, decision: pending)
                        } else {
                            // 이 상태는 엔진의 모든 호출이 거부되는 손상 저장이다.
                            // 안내문만 띄우면 여기서 커리어가 영구히 멈춘다(1.0.x
                            // "진행이 안 됩니다" 리뷰). 복구 버튼이 유일한 출구다.
                            ContentUnavailableView {
                                Label(
                                    copyResolver.resolve(.seasonDecisionUnavailable),
                                    systemImage: "exclamationmark.triangle"
                                )
                            } description: {
                                Text(verbatim: copyResolver.resolve(.seasonDecisionRecoverDetail))
                            } actions: {
                                PrimaryPill(
                                    title: copyResolver.resolve(.seasonDecisionRecoverAction),
                                    identifier: "pro.seasonDecision.recover"
                                ) {
                                    career.recoverStalledSeasonDecision()
                                }
                            }
                            .stallWatchdog("pro_season_decision_missing", threshold: 1)
                        }
                    case .importantGame:
                        ImportantGameIntro(
                            state: state,
                            onStart: career.beginImportantGame,
                            onAvailabilityDecision: career.choosePostseasonAvailability
                        )
                    case .seasonReview:
                        if let postseason = state.postseason,
                           postseason.result != .inProgress,
                           postseason.result != .didNotQualify,
                           postseason.result != .unavailable {
                            ProPostseasonFinaleView(state: state, onReview: career.reviewSeason)
                        } else {
                            ActionCard(
                                title: copyResolver.resolve(.seasonReviewTitle),
                                copy: copyResolver.resolve(.seasonReviewBody),
                                button: copyResolver.resolve(.seasonReviewAction),
                                identifier: "pro.seasonReview.confirm",
                                action: career.reviewSeason
                            )
                        }
                    case .offseasonDecision:
                        OffseasonView(career: career, state: state)
                            .background(BaseballTheme.canvas)
                    case .retirementDecision:
                        RetirementDecisionView(career: career, state: state)
                    case .completed:
                        RetiredView(
                            state: state,
                            retiresIntoSignatureLegacy: retiresIntoSignatureLegacy,
                            challengeStamp: career.challengeStamp(),
                            onStartNewPlayer: onStartNewPlayer
                        )
                    case .nationalTeamCall:
                        ProNationalTeamCallView(career: career, state: state)
                    case .nationalTournament:
                        ProNationalTournamentView(career: career, state: state)
                    default:
                        ContentUnavailableView(
                            copyResolver.resolve(.scheduleComplete),
                            systemImage: "checkmark.circle"
                        )
                    }
                }
                }
                .id(state.phase)
                .transition(.identity)
                .background(BaseballTheme.canvas)
                if state.phase == .weeklyPlan {
                    ProCareerNewsSection(state: state)
                }
            }
            .padding(BaseballMetrics.gutter)
            // 고교 화면과 같은 이유 — 떠 있는 탭 바가 마지막 행동을 덮는다.
            .safeAreaPadding(.bottom, BaseballMetrics.floatingTabBarClearance)
        }
        // 국면이 바뀌면 스크롤을 맨 위로. 결산에서 내린 위치가 오프시즌 투자 화면에 남아
        // 제목이 시계 뒤에 있었다(4차 검수).
        .id("pro-phase-\(state.phase.rawValue)")
        .background(BaseballTheme.canvas)
        .animation(reduceMotion ? nil : .snappy, value: career.feedbackTrigger)
        .onChange(of: career.lastSummary) { _, _ in dismissedBanner = false }
    }

    private func acknowledge(_ notice: CareerNoticeQueue.Item?, state: ProCareerSnapshot) {
        switch notice {
        case .injury:
            career.acknowledgeInjuryEvent()
        case .growth:
            career.acknowledgeGains()
        case .followUp(let followUp):
            dismissedFollowUpIDs.insert(followUp.id)
        case .banner:
            dismissedBanner = true
        case nil:
            break
        }
    }

#if DEBUG
    @ViewBuilder
    private func recordShareCaptureCards(state: ProCareerSnapshot) -> some View {
        if let milestoneShare = CareerSharePresentation.recordMilestone(
            state: state,
            stamp: career.challengeStamp(),
            resolver: copyResolver
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: milestoneShare.detail)
                    .font(.subheadline)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .accessibilityIdentifier("pro.weekly.recordShare")
                CareerShareButton(model: milestoneShare)
            }
        }
        ForEach(state.resolvedFollowUps ?? []) { followUp in
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: ProCareerPresentation.followUpSummary(followUp, resolver: copyResolver))
                    .font(.subheadline)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .accessibilityIdentifier("pro.weekly.decisionFollowUp.\(followUp.type.rawValue)")
                if let qsShare = CareerSharePresentation.recordQS(
                    followUp: followUp,
                    state: state,
                    stamp: career.challengeStamp(),
                    resolver: copyResolver
                ) {
                    CareerShareButton(model: qsShare)
                }
            }
        }
    }
#endif
}

enum CareerNoticeQueue {
    enum Item: Equatable {
        case injury
        case growth
        case followUp(ProDecisionFollowUp)
        case banner
    }

    static func current(
        hasInjury: Bool,
        hasGrowth: Bool,
        followUps: [ProDecisionFollowUp],
        hasBanner: Bool
    ) -> Item? {
        if hasInjury { return .injury }
        if hasGrowth { return .growth }
        if let followUp = followUps.first { return .followUp(followUp) }
        if hasBanner { return .banner }
        return nil
    }
}

/// 국면 화면 위에 얹는 알림 — 부상 → 성장 → 결정 후속 → 주간 배너. 한 번에 한 장.
struct CareerFlowNotices: View {
    let career: MobileCareerStore
    let state: ProCareerSnapshot
    var notice: CareerNoticeQueue.Item?
    var bannerText: String?
    var onDismissFollowUp: (String) -> Void = { _ in }
    var onDismissBanner: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.gameCopyResolver) private var copyResolver

    /// 시즌 결산은 리뷰 제목이 먼저 서고 성장 타일이 그 아래에 온다(Peak-End).
    /// 그 국면에서는 결산 화면이 성장 카드를 직접 그린다.
    static func settlementOwnsGrowth(_ state: ProCareerSnapshot) -> Bool {
        state.phase == .seasonSettlement && state.journeyState != nil
    }

    var body: some View {
        Group {
            switch notice {
            case .injury:
                if let injury = career.pendingInjuryEvent {
                    ProInjuryResultCard(event: injury, onAcknowledge: career.acknowledgeInjuryEvent)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            case .growth:
                if !career.pendingGains.isEmpty, !Self.settlementOwnsGrowth(state) {
                    GrowthCelebrationView(
                        gains: career.pendingGains,
                        stageContext: .pro,
                        onDismiss: career.acknowledgeGains
                    )
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                }
            case .followUp(let followUp):
                followUpCard(followUp)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            case .banner:
                if let bannerText {
                    ResultBanner(summary: bannerText, cue: career.feedbackCue, onDismiss: onDismissBanner)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            case nil:
                EmptyView()
            }
        }
        .accessibilitySortPriority(8)
    }

    @ViewBuilder private func followUpCard(_ followUp: ProDecisionFollowUp) -> some View {
        BaseballCard(
            title: copyResolver.resolve(.decisionFollowUpCardTitle),
            tone: .milestone
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: ProCareerPresentation.followUpSummary(followUp, resolver: copyResolver))
                    .detailStyle()
                Button(copyResolver.resolve(AppCopyKey.noticeDismiss)) {
                    onDismissFollowUp(followUp.id)
                }
                .font(BaseballType.detail.weight(.semibold))
                .frame(minHeight: BaseballMetrics.minimumTapTarget)
                .accessibilityLabel(copyResolver.resolve(AppCopyKey.noticeDismiss))
            }
        }
        .accessibilityIdentifier("pro.weekly.decisionFollowUp.\(followUp.type.rawValue)")
    }

    /// 배너에 실을 문장. 주간 진행 요약이면 타일에 없는 나머지 항목만 남기고, 없으면 nil.
    static func bannerText(
        _ summary: String?,
        weekProgress: ProCareerPresentation.WeekProgressSummary?,
        state: ProCareerSnapshot,
        resolver: GameCopyResolver
    ) -> String? {
        guard let summary else { return nil }
        guard state.phase != .seasonDecision else { return nil }
        guard let weekProgress else {
            return ProCareerPresentation.storeSummary(summary, state: state, resolver: resolver)
        }
        if weekProgress.extras.isEmpty { return nil }
        if resolver.language == .korean {
            return weekProgress.extras.joined(separator: " · ")
        }
        return ProCareerPresentation.storeSummary(summary, state: state, resolver: resolver)
    }
}
