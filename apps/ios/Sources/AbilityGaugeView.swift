import SwiftUI

/// 20-80 능력 사다리의 단일 출처. 데스크톱 `apps/windows/src/ratingScale.ts`와 같은 눈금을 쓴다.
enum RatingScale {
    struct Step {
        let minimum: Int
        let label: String
    }

    static let steps: [Step] = [
        Step(minimum: 75, label: "세대 최고 수준"),
        Step(minimum: 65, label: "프로 최상급"),
        Step(minimum: 55, label: "프로 평균 이상"),
        Step(minimum: 50, label: "프로 평균"),
        Step(minimum: 47, label: "지역에서 손꼽는 재능"),
        Step(minimum: 43, label: "고교 상위권 도전"),
        Step(minimum: 38, label: "고교 주전 경쟁"),
        Step(minimum: 33, label: "성장 중인 기본기")
    ]

    static func clamp(_ value: Int) -> Int { min(80, max(20, value)) }

    static func meaning(_ value: Int) -> String {
        for step in steps where value >= step.minimum { return step.label }
        return "기본기 다지는 단계"
    }

    /// 현재 값 바로 위 단계. 최고 단계면 nil.
    static func nextStep(_ value: Int) -> Step? {
        steps.reversed().first { $0.minimum > value }
    }

    static func position(_ value: Int) -> Double {
        Double(clamp(value) - 20) / 60
    }

    static func tone(_ value: Int) -> Color {
        let rating = clamp(value)
        if rating >= 65 { return BaseballTheme.action }
        if rating >= 50 { return BaseballTheme.positive }
        if rating >= 40 { return BaseballTheme.information }
        return BaseballTheme.textSecondary
    }
}

struct AbilityGaugeView: View {
    let label: String
    let value: Int
    /// 값이 오른 경우의 이전 값. 지정하면 이전 위치에 표식을 남기고 채움이 애니메이션된다.
    var beforeValue: Int?
    var showsMeaning = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedValue: Int?

    private var displayed: Int { animatedValue ?? value }
    private var gained: Bool { beforeValue.map { value > $0 } ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).eyebrowStyle(BaseballTheme.textTertiary)
                Spacer()
                if gained, let beforeValue {
                    Text("\(beforeValue) → \(value)")
                        .font(BaseballType.scoreboard)
                        .foregroundStyle(BaseballTheme.action)
                } else {
                    Text("\(value)")
                        .font(BaseballType.scoreboard)
                        .foregroundStyle(BaseballTheme.textPrimary)
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(BaseballTheme.surfaceRaised)
                    Capsule()
                        .fill(RatingScale.tone(value))
                        .frame(width: max(4, proxy.size.width * RatingScale.position(displayed)))
                    if let beforeValue, gained {
                        Rectangle()
                            .fill(BaseballTheme.border)
                            .frame(width: 2)
                            .offset(x: proxy.size.width * RatingScale.position(beforeValue))
                    }
                }
            }
            .frame(height: 8)
            if showsMeaning {
                Text(RatingScale.meaning(value))
                    .font(.caption)
                    .foregroundStyle(BaseballTheme.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .onAppear {
            guard gained, let beforeValue else { return }
            animatedValue = beforeValue
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.7)) { animatedValue = value }
        }
    }

    private var accessibilityText: String {
        if gained, let beforeValue {
            return "\(label) \(beforeValue)에서 \(value). \(RatingScale.meaning(value))"
        }
        return "\(label) \(value). \(RatingScale.meaning(value))"
    }
}
