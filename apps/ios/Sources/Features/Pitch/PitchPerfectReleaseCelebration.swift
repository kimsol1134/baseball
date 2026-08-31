import SwiftUI
import SimulationCore
import BaseballIOSDomain

// MARK: - 부품

/// 퍼펙트 릴리스가 방금 공의 결과 위에서 터지는 짧은 축하 레이어.
///
/// 입력 패드 안에 두면 SwiftUI가 같은 위치의 다음 DeliveryControl에 상태를 재사용한다. 화면
/// 오버레이로 분리하면 타석 종료로 footer가 사라져도 수명이 유지되고, 패드 문구와 겹치지 않는다.
struct PerfectReleaseCelebration: View {
    let title: String
    let reduceMotion: Bool

    @State private var progress: CGFloat = 0

    private var fadingOpacity: Double {
        let value = Double(progress)
        guard value > 0.82 else { return 1 }
        return max(0, (1 - value) / 0.18)
    }

    private var remainingOpacity: Double {
        max(0, 1 - Double(progress))
    }

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(
                x: geometry.size.width / 2,
                y: min(max(geometry.size.height * 0.55, 220), geometry.size.height - 190)
            )

            ZStack {
                RadialGradient(
                    colors: [
                        BaseballTheme.milestone.opacity(reduceMotion ? 0.34 : 0.52 * remainingOpacity),
                        BaseballTheme.milestone.opacity(reduceMotion ? 0.1 : 0.14 * remainingOpacity),
                        .clear,
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 150
                )
                .frame(width: 300, height: 300)
                .position(center)

                if !reduceMotion {
                    Circle()
                        .stroke(BaseballTheme.milestone.opacity(0.9 * remainingOpacity), lineWidth: 4)
                        .frame(width: 82 + 190 * progress, height: 82 + 190 * progress)
                        .position(center)

                    Circle()
                        .stroke(
                            BaseballTheme.fieldChalk.opacity(0.62 * remainingOpacity),
                            style: StrokeStyle(lineWidth: 2, dash: [5, 7])
                        )
                        .frame(width: 52 + 122 * progress, height: 52 + 122 * progress)
                        .rotationEffect(.degrees(70 * Double(progress)))
                        .position(center)

                    ForEach(0..<8, id: \.self) { index in
                        Capsule()
                            .fill(BaseballTheme.milestone.opacity(0.86 * remainingOpacity))
                            .frame(width: 4, height: 20)
                            .offset(y: -58 - 42 * progress)
                            .rotationEffect(.degrees(Double(index) * 45))
                            .position(center)
                    }
                }

                Label {
                    Text(verbatim: title)
                } icon: {
                    Image(systemName: "target")
                }
                    .font(.title2.weight(.black))
                    .foregroundStyle(BaseballTheme.canvas)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(BaseballTheme.milestone, in: Capsule())
                    .overlay(Capsule().stroke(BaseballTheme.fieldChalk.opacity(0.7), lineWidth: 1))
                    .shadow(color: BaseballTheme.milestone.opacity(0.52), radius: 16)
                    .scaleEffect(reduceMotion ? 1 : 0.78 + 0.28 * progress)
                    .offset(y: reduceMotion ? 0 : -24 * progress)
                    .opacity(reduceMotion ? 1 : fadingOpacity)
                    .position(center)
                    .accessibilityLabel(Text(verbatim: title))
                    .accessibilityIdentifier("pitch.perfectEffect")
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            // 삽입 프레임을 먼저 그린 뒤 1로 보낸다. 0→1을 같은 트랜잭션에서 처리하면
            // SwiftUI가 시작 상태를 합쳐 버려 섬광이 아예 보이지 않을 수 있다.
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: PerfectReleaseFeedback.animationDuration)) {
                    progress = 1
                }
            }
        }
    }
}
