import SwiftUI

/// 능력이 올랐을 때만 나타나는 성장 카드. 올라간 값과 "다음 단계까지 얼마"를 함께 보여 줘서
/// 숫자 증가가 무슨 뜻인지 사다리 위에서 읽히게 한다.
struct GrowthCelebrationView: View {
    let gains: [MobileCareerStore.AbilityGain]
    /// 대성공 훈련 — 성장이 두 배로 붙은 날. 조용한 축하 대신 잭팟 연출을 쓴다.
    var jackpot: Bool = false
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.gameCopyResolver) private var copyResolver
    @State private var appeared = false

    private var accent: Color { jackpot ? BaseballTheme.milestone : BaseballTheme.action }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            HStack(spacing: 8) {
                Image(systemName: jackpot ? "sparkles" : "arrow.up.right.circle.fill")
                    .foregroundStyle(accent)
                Text(verbatim: copyResolver.resolve(jackpot ? .growthJackpotTitle : .growthTitle))
                    .font(BaseballType.sectionTitle)
                    .foregroundStyle(jackpot ? BaseballTheme.milestone : BaseballTheme.textPrimary)
                Spacer()
                Button(action: onDismiss) {
                    Text(verbatim: copyResolver.resolve(.growthClose))
                }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
            }

            // 데스크톱 훈련 결과 화면처럼 오른 값을 큰 숫자로 먼저 보여 주고,
            // 게이지는 그 아래에서 사다리 위 위치를 보충한다.
            // 같은 값을 큰 숫자와 게이지로 두 번 적으면 축하가 아니라 오류로 보인다
            // (QA P2-1). 큰 숫자 + "다음 단계까지"만 남긴다.
            ForEach(gains) { gain in
                StatTile(
                    label: copyResolver.resolve(gain.ability.displayCopyToken),
                    value: "\(gain.after)",
                    previousValue: "\(gain.before)",
                    caption: RatingScale.nextStep(gain.after).map { step in
                        copyResolver.resolve(
                            .growthNextStep,
                            arguments: [
                                .integer(step.minimum - gain.after),
                                .userText(MetaPresentation.ratingMeaning(step, resolver: copyResolver)),
                            ]
                        )
                    },
                    tone: accent
                )
            }
            if jackpot {
                Text(verbatim: copyResolver.resolve(.growthJackpotBody))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BaseballTheme.milestone)
            }
        }
        .padding(BaseballMetrics.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(jackpot ? BaseballTheme.milestone.opacity(0.14) : BaseballTheme.actionSoft, in: RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius)
                .stroke(accent, lineWidth: jackpot ? 2 : 1)
        }
        .scaleEffect(appeared || reduceMotion ? 1 : (jackpot ? 0.85 : 0.96))
        .opacity(appeared || reduceMotion ? 1 : 0)
        .onAppear {
            // 잭팟은 더 크게 튀어나온다 — 같은 스프링이면 대성공이 대성공으로 안 읽힌다.
            withAnimation(reduceMotion ? nil : .spring(response: jackpot ? 0.5 : 0.4, dampingFraction: jackpot ? 0.55 : 0.8)) { appeared = true }
            if jackpot { GameAudio.shared.play(.milestone) }
        }
        .accessibilityElement(children: .contain)
    }
}
