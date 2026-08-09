import SwiftUI

/// 고교 3년 돌아보기 — 한 선수가 학교를 떠나는 순간의 폭발.
///
/// 예전에는 기억 카드를 확정하면 조용히 다음 화면이었다. 로그라이트에서 "이번 판이
/// 남긴 것"의 정산은 다음 판을 시작하는 이유 그 자체다: 위업이 도장처럼 하나씩
/// 찍히고, 야구혼이 큰 숫자로 차오른 뒤에야 다음 회차 버튼이 나온다.
struct RunRecapView: View {
    /// 접근성 글자 크기에서 고정 64pt는 주변 본문만 커져 위계가 뒤집힌다.
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 64

    /// 정산할 회차와 부속 결과. 스토어가 confirmLegacy에서 만들어 준다.
    struct Recap: Identifiable, Equatable {
        var id: Int { record.lifeNumber }
        let record: HighSchoolCareerStore.LifeRecord
        /// 걸었던 약속과 이행 여부. 약속 없는 회차는 nil.
        var pledgeID: String? = nil
        let pledgeTitle: String?
        let pledgeAchieved: Bool
        var pledgeProgress: RunPledgeProgress? = nil
        var pledgeRewardPermille: Int = 0
        /// 정산에서 사용자가 직접 저장할 수 있는 다음 회차 추천. 자동 선택하지 않는다.
        var suggestedIntent: NextRunIntent? = nil
        /// 숙적 상대 전적 한 줄(타석이 있을 때만).
        let rivalLine: String?
        /// 정산 후 야구혼 잔액. 상점에서 쓸 수 있는 돈이다.
        var soulBalance: Int = 0
        /// 그 잔액이 다음 회차에 자동으로 스며드는 양(상한 적용 후 실제값).
        /// 화면이 이 값을 말하지 않으면 게임이 거짓 영수증을 발행하는 셈이다.
        var soulAutoApplied: Int = 0
    }

    let recap: Recap
    let onDismiss: () -> Void
    /// 지난 회차와 같은 설정으로 곧장 다음 회차를 여는 길. 없으면 nil이고, 그때는
    /// 예전처럼 완료 화면을 거친다.
    var onQuickRebirth: (() -> Void)?
    var onSaveIntent: ((NextRunIntent) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = 0
    @State private var shownSoul = 0
    @State private var soulDone = false
    @State private var intentSaved = false
    @State private var legacyExposureLogged = false
    @State private var continueTapped = false

    static func legacyIsVisible(revealed: Int, stampCount: Int) -> Bool {
        revealed >= stampCount
    }

    static func shouldLogLegacy(
        alreadyLogged: Bool,
        revealed: Int,
        stampCount: Int
    ) -> Bool {
        !alreadyLogged && legacyIsVisible(revealed: revealed, stampCount: stampCount)
    }

    static func continueAnalyticsProperties(
        lifeNumber: Int,
        drafted: Bool,
        entryPath: String,
        hasSuggestedIntent: Bool,
        intentSaved: Bool
    ) -> [String: Any] {
        [
            "life_number": lifeNumber,
            "drafted": drafted,
            "entry_path": entryPath,
            "has_suggested_intent": hasSuggestedIntent,
            "intent_saved": intentSaved,
        ]
    }

    /// 도장들. 순서대로 찍힌다 — 결말이 먼저, 기록이 다음, 이야기가 마지막.
    private var stamps: [(text: String, tone: Color)] {
        var items: [(String, Color)] = []
        items.append((recap.record.drafted
                      ? "\(recap.record.teamName ?? "프로 구단") 지명"
                      : "미지명 · 평가 \(recap.record.evaluationScore)점",
                      recap.record.drafted ? BaseballTheme.action : BaseballTheme.textSecondary))
        items.append(("\(recap.record.games)등판 · 탈삼진 \(recap.record.strikeouts)", BaseballTheme.positive))
        if let nickname = recap.record.nicknames?.last {
            items.append(("세상이 부른 이름 — '\(nickname)'", BaseballTheme.milestone))
        }
        if let pledgeTitle = recap.pledgeTitle {
            let progress = recap.pledgeProgress
            let progressLine = progress.map { " · \($0.line)" } ?? ""
            let status: String
            if recap.pledgeAchieved {
                status = "목표 달성 — \(pledgeTitle) · 야구혼 +\(recap.pledgeRewardPermille / 10)%"
            } else if (progress?.ratioPermille ?? 0) >= 800 {
                status = "목표까지 아슬아슬 — \(pledgeTitle)\(progressLine)"
            } else {
                status = "목표 미완 — \(pledgeTitle)\(progressLine)"
            }
            items.append((status,
                          recap.pledgeAchieved ? BaseballTheme.milestone : BaseballTheme.textTertiary))
        }
        if let rivalLine = recap.rivalLine {
            items.append((rivalLine, BaseballTheme.information))
        }
        return items
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                    Text("\(recap.record.lifeNumber)번째 선수 · 3년 돌아보기")
                        .eyebrowStyle(BaseballTheme.milestone)
                    Text(recap.record.playerName)
                        .font(BaseballType.display)
                        .foregroundStyle(BaseballTheme.textPrimary)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(stamps.enumerated()), id: \.offset) { index, stamp in
                            Text(stamp.text)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(stamp.tone)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(BaseballTheme.surface.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(stamp.tone.opacity(0.5), lineWidth: 1))
                                .rotationEffect(.degrees(index < revealed ? 0 : -6))
                                .scaleEffect(index < revealed ? 1 : 1.6)
                                .opacity(index < revealed ? 1 : 0)
                        }
                    }

                    let legacy = recap.record.playerLegacy ?? PlayerBondStory.legacy(for: recap.record)
                    PlayerLegacyQuote(legacy: legacy)
                        .opacity(revealed >= stamps.count ? 1 : 0)
                        .accessibilityHidden(!Self.legacyIsVisible(
                            revealed: revealed,
                            stampCount: stamps.count
                        ))
                        .accessibilityIdentifier("hs.recap.playerLegacy")

                    if let signature = recap.record.signatureLegacy {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("새 선수에게 직접 이어진 대표 유산")
                                .eyebrowStyle(BaseballTheme.milestone)
                            Text(signature.title)
                                .font(.headline.weight(.heavy))
                                .foregroundStyle(BaseballTheme.textPrimary)
                            Text(signature.evidence.summary)
                                .font(.footnote)
                                .foregroundStyle(BaseballTheme.information)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(HighSchoolSetupView.signatureLegacyEffectLine(signature.effect))
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(BaseballTheme.milestone)
                            Text("함께 발견한 세 후보는 모두 발견 목록에 남았습니다.")
                                .font(.caption)
                                .foregroundStyle(BaseballTheme.textSecondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            BaseballTheme.milestone.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                                .stroke(BaseballTheme.milestone.opacity(0.45), lineWidth: 1)
                        }
                        .opacity(revealed >= stamps.count ? 1 : 0)
                        .accessibilityHidden(revealed < stamps.count)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("hs.recap.signatureLegacy")
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("야구혼").eyebrowStyle(BaseballTheme.milestone)
                        Text("+\(shownSoul)")
                            .font(.system(size: heroSize, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(BaseballTheme.milestone)
                            .contentTransition(.numericText(value: Double(shownSoul)))
                        // 정직한 영수증 — 적립·잔액·자동 스며듦을 전부 말한다.
                        // 큰 숫자만 보여 주고 상한을 숨기면, 유저가 계산하는 순간 신뢰가 무너진다.
                        Text("잔액 \(recap.soulBalance)혼 · 새 선수 시작 보너스 +\(recap.soulAutoApplied)")
                            .font(.footnote.weight(.semibold).monospacedDigit())
                            .foregroundStyle(BaseballTheme.textPrimary)
                            .opacity(soulDone ? 1 : 0)
                        // 조건부 문구 — 최저가(90혼)에 못 미치는 잔액에 상점을 약속하면
                        // 다음 화면에서 살 수 없는 상점이 열린다(2차 패널 P1).
                        Text(recap.soulBalance >= 90
                             ? "잔액은 환생할 때 영혼 상점에서 씁니다 — 재능 돌파·기억 확장·성장 리듬."
                             : "야구혼이 더 쌓이면 영혼 상점이 열립니다 — 새 선수에게 잔액이 이어집니다.")
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .opacity(soulDone ? 1 : 0)
                    }
                    .padding(.top, 6)
                    .opacity(revealed >= stamps.count ? 1 : 0)

                    if let intent = recap.suggestedIntent,
                       let pledge = RunPledge.pledge(id: intent.pledgeID) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("새 선수로 다시 도전")
                                .font(.subheadline.weight(.heavy))
                                .foregroundStyle(BaseballTheme.milestone)
                            Text(pledge.title)
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(BaseballTheme.textPrimary)
                            Text(intent.reason)
                                .font(.caption)
                                .foregroundStyle(BaseballTheme.textSecondary)
                            Button(intentSaved ? "새 선수 목표로 저장됨" : "새 선수 목표로 저장") {
                                onSaveIntent?(intent)
                                intentSaved = true
                            }
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(BaseballTheme.milestone)
                            .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                            .background(BaseballTheme.milestone.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                            .disabled(intentSaved || onSaveIntent == nil)
                            .accessibilityIdentifier("hs.recap.intent.save")
                            .accessibilityLabel("\(pledge.tier.title) 목표, \(pledge.title), 보상 야구혼 \(pledge.rewardPermille / 10)퍼센트 추가, 새 선수 목표로 저장")
                        }
                        .padding(12)
                        .background(BaseballTheme.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(BaseballTheme.milestone.opacity(0.45), lineWidth: 1)
                        }
                        .opacity(soulDone ? 1 : 0)
                    }
                }
                .padding(.horizontal, BaseballMetrics.gutter)
                .padding(.top, BaseballMetrics.gutter)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)

            // 본문이 길거나 글자를 크게 해도 다음 회차 행동은 화면 아래에 남는다.
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    // 감정이 가장 높은 순간에 공유가 있어야 한다 — 아카이브 탭은 감정이 식은 뒤다.
                    LifeCardShareButton(record: recap.record)
                        .opacity(soulDone ? 1 : 0.25)
                        .disabled(!soulDone)
                    // 야구혼이 다 차오른 **바로 그 순간**이 다음 판을 시작하는 자리다.
                    // 예전에는 여기서 완료 화면으로 나가 "다시 태어나기"를 한 번 더 누르고,
                    // 스탬프를 지나, 설정 4단계를 다시 통과해야 했다. 로그라이트의 "한 판 더"가
                    // 다섯 걸음이면 그건 루프가 아니라 출구다.
                    PrimaryButton(
                        title: onQuickRebirth != nil
                            ? "\(recap.record.lifeNumber + 1)번째 선수 바로 시작" : "유산을 안고 새 선수로",
                        identifier: "hs.recap.continue"
                    ) {
                        continueFromRecap(
                            entryPath: onQuickRebirth == nil ? "completion_flow" : "quick_rebirth"
                        ) {
                            if let onQuickRebirth { onQuickRebirth() } else { onDismiss() }
                        }
                    }
                    .opacity(soulDone ? 1 : 0.25)
                    .disabled(!soulDone)
                }
                // 설정을 바꿔서 시작하는 길은 그대로 둔다 — 영혼 상점·핸디캡·지역은
                // 회차마다 바꾸는 것이 이 게임의 메타다.
                if onQuickRebirth != nil {
                    Button("설정을 바꿔서 시작") {
                        continueFromRecap(entryPath: "customize", action: onDismiss)
                    }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                        .opacity(soulDone ? 1 : 0.25)
                        .disabled(!soulDone)
                        .accessibilityIdentifier("hs.recap.customize")
                }
            }
            .padding(.horizontal, BaseballMetrics.gutter)
            .padding(.top, 10)
            .padding(.bottom, BaseballMetrics.gutter)
            .background(BaseballTheme.fieldNight.opacity(0.96))
            .overlay(alignment: .top) {
                Rectangle().fill(BaseballTheme.border.opacity(0.45)).frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            if UIImage(named: "LifeCardBackdrop") != nil {
                Image("LifeCardBackdrop")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(BaseballTheme.fieldNight.opacity(0.82))
                    .ignoresSafeArea()
            } else {
                BaseballTheme.fieldNight.ignoresSafeArea()
            }
        }
        .onAppear(perform: run)
        .accessibilityElement(children: .contain)
    }

    private func run() {
        guard !reduceMotion else {
            revealed = stamps.count
            logLegacyIfVisible(revealed: stamps.count)
            shownSoul = recap.record.soulPoints
            soulDone = true
            return
        }
        // 도장 → 야구혼 카운트업 → 계속 버튼. 손맛의 박자는 슬롯 정산과 같다.
        for index in 0..<stamps.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + 0.5 * Double(index)) {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.5)) { revealed = index + 1 }
                logLegacyIfVisible(revealed: index + 1)
                Haptics.shared.outcome(success: true)
            }
        }
        let start = 0.7 + 0.5 * Double(stamps.count)
        let total = max(1, recap.record.soulPoints)
        let steps = min(28, total)
        for step in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + start + 1.1 * Double(step) / Double(steps)) {
                withAnimation(.linear(duration: 0.05)) { shownSoul = total * step / steps }
                if step == steps {
                    GameAudio.shared.play(.milestone)
                    Haptics.shared.outcome(success: true)
                    withAnimation(.easeOut(duration: 0.3)) { soulDone = true }
                }
            }
        }
    }

    private func logLegacyIfVisible(revealed: Int) {
        guard Self.shouldLogLegacy(
            alreadyLogged: legacyExposureLogged,
            revealed: revealed,
            stampCount: stamps.count
        ) else { return }
        legacyExposureLogged = true
        GameAnalytics.logOnce(
            .playerLegacySeen,
            scope: "recap:\(recap.record.careerID ?? "life-\(recap.record.lifeNumber)")",
            properties: [
                "source": "recap",
                "life_number": recap.record.lifeNumber,
                "drafted": recap.record.drafted,
                "has_frozen_legacy": recap.record.playerLegacy != nil,
            ]
        )
    }

    private func continueFromRecap(entryPath: String, action: () -> Void) {
        guard !continueTapped else { return }
        continueTapped = true
        GameAnalytics.log(
            .recapContinueTapped,
            Self.continueAnalyticsProperties(
                lifeNumber: recap.record.lifeNumber,
                drafted: recap.record.drafted,
                entryPath: entryPath,
                hasSuggestedIntent: recap.suggestedIntent != nil,
                intentSaved: intentSaved
            )
        )
        action()
    }
}
