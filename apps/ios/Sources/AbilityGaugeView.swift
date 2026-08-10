import SwiftUI
import SimulationCore

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
    /// 이 능력의 재능 등급. 주면 등급 칩과 한계선을 함께 그린다.
    ///
    /// 한계선이 보여야 "왜 안 오르지"가 "아, 여기가 벽이구나"가 된다. 벽이 안 보이면
    /// 플레이어는 훈련이 실패한 줄 알고 그 능력을 포기한다 — 만개는 계속 두드려야 오는데.
    var talent: TalentGrade?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedValue: Int?

    private var displayed: Int { animatedValue ?? value }
    private var gained: Bool { beforeValue.map { value > $0 } ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).eyebrowStyle(BaseballTheme.textTertiary)
                // **"재능"을 붙여 읽는다.**
                //
                // 알파벳만 있으면 그 글자를 현재 실력의 등급으로 읽는다. 그래서 구위 45(S)와
                // 제구 50(C)가 나란히 서면 "낮은데 등급이 더 높다"는 모순으로 보인다. 이 글자는
                // 실력이 아니라 **성장 한계**다 — S는 80까지 열려 있다는 뜻이고, 지금 45라는
                // 사실과 아무 충돌이 없다. 한 단어와 한계 숫자가 그 오해를 통째로 없앤다.
                if let talent {
                    Text("재능 \(talent.label)")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(BaseballTheme.actionInk)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(RatingScale.tone(talent.ceiling), in: Capsule())
                    Text(talent == .s ? "한계 없음" : "\(talent.ceiling)까지")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BaseballTheme.textTertiary)
                }
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
                    // 재능의 한계선. S는 끝까지 열려 있어 선을 그리지 않는다.
                    if let talent, talent != .s {
                        Rectangle()
                            .fill(BaseballTheme.borderStrong)
                            .frame(width: 2)
                            .offset(x: proxy.size.width * RatingScale.position(talent.ceiling))
                    }
                }
            }
            .frame(height: 8)
            if showsMeaning {
                Text(RatingScale.meaning(value))
                    .font(.caption)
                    .foregroundStyle(BaseballTheme.textSecondary)
                if let talent, value >= talent.ceiling, talent != .s {
                    Text("재능의 한계에 닿았습니다. 계속 훈련하면 열립니다.")
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
        let talentText = talent.map { " 재능 \($0.label), 한계 \($0.ceiling)." } ?? ""
        if gained, let beforeValue {
            return "\(label) \(beforeValue)에서 \(value).\(talentText) \(RatingScale.meaning(value))"
        }
        return "\(label) \(value).\(talentText) \(RatingScale.meaning(value))"
    }
}
