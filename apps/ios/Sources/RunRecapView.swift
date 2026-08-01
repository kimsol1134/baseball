import SwiftUI

/// 회차 정산 — 한 회차가 끝나는 순간의 폭발.
///
/// 예전에는 기억 카드를 확정하면 조용히 다음 화면이었다. 로그라이트에서 "이번 판이
/// 남긴 것"의 정산은 다음 판을 시작하는 이유 그 자체다: 위업이 도장처럼 하나씩
/// 찍히고, 야구혼이 큰 숫자로 차오른 뒤에야 다음 회차 버튼이 나온다.
struct RunRecapView: View {
    /// 정산할 회차와 부속 결과. 스토어가 confirmLegacy에서 만들어 준다.
    struct Recap: Identifiable, Equatable {
        var id: Int { record.lifeNumber }
        let record: HighSchoolCareerStore.LifeRecord
        /// 걸었던 약속과 이행 여부. 약속 없는 회차는 nil.
        let pledgeTitle: String?
        let pledgeAchieved: Bool
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = 0
    @State private var shownSoul = 0
    @State private var soulDone = false

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
            items.append((recap.pledgeAchieved
                          ? "약속 이행 — \(pledgeTitle) · 야구혼 +15%"
                          : "약속 미완 — \(pledgeTitle)",
                          recap.pledgeAchieved ? BaseballTheme.milestone : BaseballTheme.textTertiary))
        }
        if let rivalLine = recap.rivalLine {
            items.append((rivalLine, BaseballTheme.information))
        }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            Spacer(minLength: 0)

            Text("\(recap.record.lifeNumber)회차 정산")
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

            VStack(alignment: .leading, spacing: 2) {
                Text("야구혼").eyebrowStyle(BaseballTheme.milestone)
                Text("+\(shownSoul)")
                    .font(.system(size: 64, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(BaseballTheme.milestone)
                    .contentTransition(.numericText(value: Double(shownSoul)))
                // 정직한 영수증 — 적립·잔액·자동 스며듦을 전부 말한다.
                // 큰 숫자만 보여 주고 상한을 숨기면, 유저가 계산하는 순간 신뢰가 무너진다.
                Text("잔액 \(recap.soulBalance)혼 · 다음 회차 자동 스며듦 +\(recap.soulAutoApplied)")
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundStyle(BaseballTheme.textPrimary)
                    .opacity(soulDone ? 1 : 0)
                // 조건부 문구 — 최저가(90혼)에 못 미치는 잔액에 상점을 약속하면
                // 다음 화면에서 살 수 없는 상점이 열린다(2차 패널 P1).
                Text(recap.soulBalance >= 90
                     ? "잔액은 환생할 때 영혼 상점에서 씁니다 — 재능 돌파·기억 확장·성장 리듬."
                     : "야구혼이 더 쌓이면 영혼 상점이 열립니다 — 다음 회차의 잔액으로 이어집니다.")
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .opacity(soulDone ? 1 : 0)
            }
            .padding(.top, 6)
            .opacity(revealed >= stamps.count ? 1 : 0)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                // 감정이 가장 높은 순간에 공유가 있어야 한다 — 아카이브 탭은 감정이 식은 뒤다.
                LifeCardShareButton(record: recap.record)
                    .opacity(soulDone ? 1 : 0.25)
                    .disabled(!soulDone)
                PrimaryButton(title: "기억을 안고 다음 회차로", identifier: "hs.recap.continue") { onDismiss() }
                    .opacity(soulDone ? 1 : 0.25)
                    .disabled(!soulDone)
            }
        }
        .padding(BaseballMetrics.gutter)
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
            shownSoul = recap.record.soulPoints
            soulDone = true
            return
        }
        // 도장 → 야구혼 카운트업 → 계속 버튼. 손맛의 박자는 슬롯 정산과 같다.
        for index in 0..<stamps.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + 0.5 * Double(index)) {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.5)) { revealed = index + 1 }
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
}
