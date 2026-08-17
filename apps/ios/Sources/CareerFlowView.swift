import SwiftUI
import SimulationCore


struct CareerFlowView: View {
    let career: MobileCareerStore
    /// 은퇴 뒤 새 선수로 시작한다. 프로 저장본을 지우고 고교 탭으로 돌려보낸다.
    var onStartNewPlayer: () -> Void = {}
    var retiresIntoSignatureLegacy = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView { CareerSummary(career: career) } detail: { decision }
            } else {
                decision
            }
        }
        .navigationTitle(copyResolver.resolve(.navigationThisWeek))
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
                            ResultBanner(
                                summary: ProCareerPresentation.storeSummary(
                                    summary,
                                    state: state,
                                    resolver: copyResolver
                                ),
                                cue: career.feedbackCue
                            )
                                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        }

                        if state.phase == .seasonSettlement, state.journeyState != nil {
                            ProSeasonSettlementView(career: career, state: state)
                        } else {
                            switch state.phase {
                            case .contractOffer:
                                ProContractOfferView(career: career, state: state)
                            case .offseasonInvestment:
                                ProOffseasonInvestmentView(career: career, state: state)
                            case .weeklyPlan:
                                WeeklyPlanView(career: career, state: state)
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
                                ImportantGameIntro(state: state, onStart: career.beginImportantGame)
                            case .seasonReview:
                                ActionCard(
                                    title: copyResolver.resolve(.seasonReviewTitle),
                                    copy: copyResolver.resolve(.seasonReviewBody),
                                    button: copyResolver.resolve(.seasonReviewAction),
                                    identifier: "pro.seasonReview.confirm",
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
                                ContentUnavailableView(
                                    copyResolver.resolve(.scheduleComplete),
                                    systemImage: "checkmark.circle"
                                )
                            }
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

