import SwiftUI

/// 능력이 올랐을 때만 나타나는 성장 카드. 올라간 값과 "다음 단계까지 얼마"를 함께 보여 줘서
/// 숫자 증가가 무슨 뜻인지 사다리 위에서 읽히게 한다.
struct GrowthCelebrationView: View {
    let gains: [MobileCareerStore.AbilityGain]
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .foregroundStyle(BaseballTheme.action)
                Text("능력이 올랐습니다")
                    .font(BaseballType.sectionTitle)
                Spacer()
                Button("닫기", action: onDismiss)
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
            }

            // 데스크톱 훈련 결과 화면처럼 오른 값을 큰 숫자로 먼저 보여 주고,
            // 게이지는 그 아래에서 사다리 위 위치를 보충한다.
            ForEach(gains) { gain in
                VStack(alignment: .leading, spacing: 8) {
                    StatTile(
                        label: gain.label,
                        value: "\(gain.after)",
                        previousValue: "\(gain.before)",
                        caption: RatingScale.nextStep(gain.after).map {
                            "다음 단계 \($0.label)까지 \($0.minimum - gain.after)"
                        },
                        tone: BaseballTheme.action
                    )
                    AbilityGaugeView(label: gain.label, value: gain.after, beforeValue: gain.before, showsMeaning: false)
                }
            }
        }
        .padding(BaseballMetrics.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BaseballTheme.actionSoft, in: RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius)
                .stroke(BaseballTheme.action, lineWidth: 1)
        }
        .scaleEffect(appeared || reduceMotion ? 1 : 0.96)
        .opacity(appeared || reduceMotion ? 1 : 0)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)) { appeared = true }
        }
        .accessibilityElement(children: .contain)
    }
}
