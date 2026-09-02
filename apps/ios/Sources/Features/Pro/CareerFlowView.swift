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
                        if let injury = career.pendingInjuryEvent {
                            ProInjuryResultCard(event: injury, onAcknowledge: career.acknowledgeInjuryEvent)
                                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        }
                        // 시즌 결산은 리뷰 제목이 먼저 서고 성장 타일이 그 아래에 온다(Peak-End).
                        // 그 국면에서는 결산 화면이 성장 카드를 직접 그린다.
                        let settlementOwnsGrowth = state.phase == .seasonSettlement && state.journeyState != nil
                        if !career.pendingGains.isEmpty, !settlementOwnsGrowth {
                            GrowthCelebrationView(
                                gains: career.pendingGains,
                                stageContext: .pro,
                                onDismiss: career.acknowledgeGains
                            )
                                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                        }
                        // 주간 진행 요약("N주차 · 감독의 믿음 -1 · 피로 +0")은 아래 상태 타일과 같은 값이라
                        // 배너로 다시 찍지 않는다 — 타일 캡션으로 한 번만 보여 준다. 승격·역할 변경·
                        // 주요 기록처럼 타일에 없는 항목만 배너에 남긴다. 결정 국면에서는 키아트 눈썹이
                        // 같은 주차를 이미 말하므로 배너를 숨긴다.
                        let weekProgress = career.lastSummary.flatMap(ProCareerPresentation.weekProgress)
                        if let summary = career.lastSummary,
                           career.pendingGains.isEmpty,
                           state.phase != .seasonDecision,
                           let bannerText = Self.bannerText(
                               summary,
                               weekProgress: weekProgress,
                               state: state,
                               resolver: copyResolver
                           ) {
                            ResultBanner(summary: bannerText, cue: career.feedbackCue)
                                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        }

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
                            case .contractOffer:
                                ProContractOfferView(career: career, state: state)
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
                                        weekProgress: weekProgress
                                    )
                                }
#else
                                WeeklyPlanView(
                                    career: career,
                                    state: state,
                                    weekProgress: weekProgress
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

    /// 배너에 실을 문장. 주간 진행 요약이면 타일에 없는 나머지 항목만 남기고, 없으면 nil.
    /// 한국어 저장본의 나머지 항목은 한국어 문장이라 다른 언어에서는 기존 번역 경로를 탄다.
    private static func bannerText(
        _ summary: String,
        weekProgress: ProCareerPresentation.WeekProgressSummary?,
        state: ProCareerSnapshot,
        resolver: GameCopyResolver
    ) -> String? {
        guard let weekProgress else {
            return ProCareerPresentation.storeSummary(summary, state: state, resolver: resolver)
        }
        if weekProgress.extras.isEmpty { return nil }
        if resolver.language == .korean {
            return weekProgress.extras.joined(separator: " · ")
        }
        return ProCareerPresentation.storeSummary(summary, state: state, resolver: resolver)
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
