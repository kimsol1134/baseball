import SwiftUI
import SimulationCore

struct TopStatusScrim: ViewModifier {
    @State private var inset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { inset = proxy.safeAreaInsets.top }
                        .onChange(of: proxy.safeAreaInsets.top) { _, value in inset = value }
                }
            }
            .overlay(alignment: .top) {
                LinearGradient(
                    stops: [
                        .init(color: BaseballTheme.canvas, location: 0),
                        .init(color: BaseballTheme.canvas, location: opaqueStop),
                        .init(color: BaseballTheme.canvas.opacity(0), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: inset + Self.fade)
                // 이 한 줄이 띠를 화면 맨 위로 올린다. 순서를 바꾸면 안 된다.
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }

    /// 상태바 아래로 풀어 주는 길이. 경계가 선처럼 보이지 않을 만큼만.
    private static let fade: CGFloat = 20
    private var opaqueStop: CGFloat { inset <= 0 ? 0 : inset / (inset + Self.fade) }
}

extension View {
    /// 내비게이션 바를 숨긴 화면에서 상태바와 본문이 겹치지 않게 한다.
    func topStatusScrim() -> some View { modifier(TopStatusScrim()) }
}

/// 화면의 주 행동. 디자인 시스템의 라임 알약 CTA를 쓴다.
struct PrimaryButton: View {
    let title: String
    /// UI 테스트가 문구 변경에 흔들리지 않도록 붙이는 안정적인 식별자.
    var identifier: String?
    let action: () -> Void

    init(title: String, identifier: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.identifier = identifier
        self.action = action
    }

    var body: some View {
        PrimaryPill(title: title, identifier: identifier, action: action)
    }
}

/// 고교 3년의 경기 기록.
///
/// 직접 던진 경기와 자동으로 흘러간 팀 경기를 나눠서 보여 준다. 섞어 놓으면 "내가 만든
/// 성적"이라는 감각이 사라지고, 그러면 자동 경기를 넣은 의미가 없다.
struct SeasonRecordCard: View {
    let log: [ProGameLine]
    @Environment(\.gameCopyResolver) private var copyResolver

    private var played: [ProGameLine] { log.filter(\.played) }
    private var auto: [ProGameLine] { log.filter { !$0.played } }

    var body: some View {
        BaseballCard(title: copyResolver.resolve(AppCopyKey.conclusionSeasonRecordTitle)) {
            VStack(alignment: .leading, spacing: 12) {
                if !played.isEmpty {
                    summary(
                        title: copyResolver.resolve(AppCopyKey.conclusionDirectOutings),
                        lines: played, accent: BaseballTheme.action
                    )
                }
                if !auto.isEmpty {
                    summary(
                        title: copyResolver.resolve(AppCopyKey.conclusionTeamGames),
                        lines: auto, accent: BaseballTheme.textTertiary
                    )
                }
                Text(copyResolver.resolve(AppCopyKey.conclusionRecentGames))
                    .eyebrowStyle(BaseballTheme.textTertiary)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(log.suffix(5).reversed()) { line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(copyResolver.resolve(
                                AppCopyKey.conclusionSeasonLabel,
                                arguments: [.integer(line.season)]
                            ))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(BaseballTheme.textTertiary)
                            Text(HighSchoolConclusionPresentation.localizedSeasonRole(
                                line, resolver: copyResolver
                            ))
                                .font(.footnote.weight(.semibold).monospacedDigit())
                            Spacer()
                            // localization-safe: numeric
                            Text(GameLineFormat.score(line))
                                .font(.footnote.weight(.bold).monospacedDigit())
                                .foregroundStyle(BaseballTheme.textSecondary)
                            if let decision = HighSchoolConclusionPresentation.localizedSeasonDecision(
                                line.decision, resolver: copyResolver
                            ) {
                                // localization-safe: resolved-copy
                                Text(decision)
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(GameLineFormat.decisionTone(line.decision))
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(HighSchoolConclusionPresentation.localizedSeasonLineAccessibility(
                            line, resolver: copyResolver
                        ))
                    }
                }
            }
            .accessibilityIdentifier("hs.seasonRecord")
        }
    }

    private func summary(title: String, lines: [ProGameLine], accent: Color) -> some View {
        return VStack(alignment: .leading, spacing: 3) {
            // localization-safe: resolved-copy
            Text(title).eyebrowStyle(accent)
            Text(HighSchoolConclusionPresentation.localizedSeasonSummary(
                lines: lines, resolver: copyResolver
            ))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(BaseballTheme.textSecondary)
            Text(HighSchoolConclusionPresentation.localizedSeasonRA9(
                lines: lines, resolver: copyResolver
            ))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(BaseballTheme.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 평가 항목을 줄바꿈하며 늘어놓는다. 항목 수가 회차마다 달라서 고정 열 배치가 맞지 않는다.
struct FlowRow: View {
    let items: [String]
    let resolver: GameCopyResolver

    var body: some View {
        // 두 개씩 짝지어 놓는다. iOS 16의 Layout 프로토콜까지 갈 만큼 복잡한 배치가 아니다.
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { index in
                HStack(spacing: 14) {
                    ForEach(items[index..<min(index + 2, items.count)], id: \.self) { item in
                        // localization-safe: resolved-copy
                        Text(item)
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(
                                item.contains("-") ? BaseballTheme.negative : BaseballTheme.textSecondary
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(resolver.resolve(
            AppCopyKey.conclusionEvaluationBreakdownAccessibility,
            arguments: [.userText(items.joined(separator: ", "))]
        ))
    }
}

/// 드래프트 점수와 야구혼은 서로 다른 회계다. 회차 바람이 둘 중 어디에 손댔는지
/// 정산에서 따로 보여 줘야 최종 점수와 다음 회차 보상을 역산할 수 있다.
struct WindSettlementCard: View {
    let wind: CareerWind
    @Environment(\.gameCopyResolver) private var copyResolver

    @ViewBuilder var body: some View {
        if wind.rules.draftEvaluationDelta != 0 || wind.rewardBonusPermille != 0 {
            let localizedWind = HighSchoolConclusionPresentation.localizedWind(
                wind, resolver: copyResolver
            )
            BaseballCard(title: copyResolver.resolve(
                AppCopyKey.conclusionWindReview,
                arguments: [.userText(localizedWind.title)]
            ), tone: .raised) {
                VStack(alignment: .leading, spacing: 5) {
                    if wind.rules.draftEvaluationDelta != 0 {
                        let delta = wind.rules.draftEvaluationDelta
                        Text(copyResolver.resolve(
                            AppCopyKey.conclusionDraftAdjustment,
                            arguments: [.integer(delta)]
                        ))
                    }
                    if wind.rewardBonusPermille != 0 {
                        let percent = wind.rewardBonusPermille / 10
                        Text(copyResolver.resolve(
                            AppCopyKey.conclusionInheritanceAdjustment,
                            arguments: [.integer(percent)]
                        ))
                    }
                    // localization-safe: resolved-copy
                    Text(localizedWind.detail)
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
                .font(.footnote.monospacedDigit().weight(.semibold))
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// 고교 3년 목표 — 시작에서 하나를 고른다.
///
/// 학교를 고르는 자리(선택의 국면)에 함께 둔다. 강요하지 않는다 — "약속 없이 간다"도
/// 당당한 선택지다. 건 약속은 대시보드에 상시 노출되고, 등급에 따라 야구혼 +10~35%.
struct PledgeCard: View {
    let state: HighSchoolCareerSnapshot
    let intent: NextRunIntent?
    let rivalLedger: HighSchoolCareerStore.RivalLedger
    /// 1회차에는 '야구혼'이라는 아직 등장 전인 화폐 대신 결과 언어로 말한다.
    var isFirstLife: Bool = false
    let onChoose: (String?) -> Void

    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        BaseballCard(title: copyResolver.resolve(.pledgeCardTitle), tone: .milestone) {
            VStack(alignment: .leading, spacing: 10) {
                Text(
                    verbatim: copyResolver.resolve(
                        isFirstLife ? .pledgeIntroFirst : .pledgeIntroRepeat
                    )
                )
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                // **누르라고 말한다.**
                //
                // 목표 카드들은 색 있는 면에 테두리까지 둘러 "정보 패널"로 읽혔다 —
                // 실제로 사용자가 이 화면에서 무엇을 눌러야 하는지 몰랐다. 카드가
                // 버튼처럼 안 보이면 지시문 한 줄이 그 일을 대신해야 한다.
                Label {
                    Text(verbatim: copyResolver.resolve(.pledgeHint))
                } icon: {
                    Image(systemName: "hand.tap.fill")
                }
                    .font(.footnote.weight(.heavy))
                    .foregroundStyle(BaseballTheme.milestone)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("hs.pledge.hint")
                ForEach(RunPledge.options(careerID: state.careerID, state: state, intent: intent)) { pledge in
                    let progress = pledge.progress(in: .init(state: state, rivalLedger: rivalLedger))
                    let carried = intent?.pledgeID == pledge.id
                    Button { onChoose(pledge.id) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                if carried {
                                    Text(verbatim: copyResolver.resolve(.pledgeCarried))
                                        .font(.caption2.weight(.heavy))
                                        .foregroundStyle(BaseballTheme.milestone)
                                }
                                Text(
                                    verbatim: LegacyPresentation.pledgeTier(
                                        pledge.tier, resolver: copyResolver
                                    )
                                )
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(pledge.tier == .legendary
                                                     ? BaseballTheme.warning : BaseballTheme.textSecondary)
                                Spacer(minLength: 0)
                                Text(
                                    verbatim: copyResolver.resolve(
                                        .pledgeReward,
                                        arguments: [.integer(pledge.rewardPermille / 10)]
                                    )
                                )
                                    .font(.caption.monospacedDigit().weight(.bold))
                                    .foregroundStyle(BaseballTheme.milestone)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(
                                    verbatim: LegacyPresentation.pledgeTitle(
                                        pledge, resolver: copyResolver
                                    )
                                )
                                .font(.subheadline.weight(.bold))
                                Spacer(minLength: 0)
                                // 화살표 하나가 "이 줄은 눌린다"를 말한다. 목록 UI의
                                // 가장 값싸고 가장 확실한 신호다.
                                Text(verbatim: copyResolver.resolve(.pledgeChoose))
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(BaseballTheme.milestone)
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(BaseballTheme.milestone)
                            }
                            Text(
                                verbatim: LegacyPresentation.pledgeDetail(
                                    pledge, resolver: copyResolver
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            Text(
                                verbatim: LegacyPresentation.pledgeAlignment(
                                    pledge, state: state, resolver: copyResolver
                                )
                            )
                                .font(.caption2)
                                .foregroundStyle(BaseballTheme.textTertiary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget, alignment: .leading)
                        .contentShape(Rectangle())
                        .background(BaseballTheme.milestone.opacity(0.1), in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
                        .overlay {
                            RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                                .stroke(BaseballTheme.milestone.opacity(0.6), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("hs.pledge.\(pledge.id)")
                    .accessibilityLabel(
                        LegacyPresentation.pledgeAccessibility(
                            pledge: pledge, progress: progress, carried: carried,
                            resolver: copyResolver
                        )
                    )
                }
                Button { onChoose(nil) } label: {
                    Text(verbatim: copyResolver.resolve(.pledgeSkip))
                }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textTertiary)
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
                    .accessibilityIdentifier("hs.pledge.skip")
            }
        }
    }
}

/// `onAppear`는 긴 `ScrollView`의 아직 보이지 않는 자식에도 호출될 수 있다. 분석 퍼널의
/// 노출은 카드가 실제 화면에 들어온 순간 한 번만 기록한다.
struct ViewportExposureModifier: ViewModifier {
    @State private var hasReported = false
    let action: () -> Void

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .global)
                Color.clear
                    .onAppear { reportIfVisible(frame) }
                    .onChange(of: frame) { _, newFrame in reportIfVisible(newFrame) }
            }
        }
    }

    private func reportIfVisible(_ frame: CGRect) {
        guard !hasReported, frame.width > 0, frame.height > 0 else { return }
        let visible = frame.intersection(UIScreen.main.bounds)
        guard !visible.isNull, visible.height >= min(44, frame.height * 0.25) else { return }
        hasReported = true
        action()
    }
}

extension View {
    func onViewportExposure(perform action: @escaping () -> Void) -> some View {
        modifier(ViewportExposureModifier(action: action))
    }
}
