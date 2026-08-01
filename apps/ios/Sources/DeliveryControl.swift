import SwiftUI
import UIKit
import SimulationCore

/// 누르고 → 조준하고 → 떼는 투구 제스처.
///
/// 이전에는 드롭다운 네 개를 고르고 버튼을 눌렀다. 결정은 있는데 신체적 표현이 없어서
/// 코어 루프가 설문 제출처럼 느껴졌다(DOC-IOS-TOP §3.1). 이 컨트롤이 그 층을 만든다.
///
/// - 누르면 와인드업 미터가 좌우로 왕복한다. 가운데 초록 구간에서 뗄수록 릴리스가 좋다.
/// - **조준점은 저절로 흔들린다.** 끌어서 중심으로 되돌리고, 겹친 순간에 뗀다.
/// - 떼면 `PitchDelivery`가 만들어지고 투구가 실행된다.
///
/// 조준이 흔들리는 이유: 예전에는 손가락을 끈 거리를 그대로 이탈로 썼다. 그러면 **아무것도
/// 안 하는 것이 최적 전략**이 된다 — 누르고 가만히 있으면 이탈 0, 조준 1000점이다. 실력이
/// 개입할 자리가 없고 중앙에 맞히는 것이 너무 쉬웠다. 지금은 조준점이 스스로 떠다니고
/// 플레이어가 그것을 붙잡는다. 피로할수록 크게 흔들린다.
///
/// 접근성: `autoRelease`가 켜져 있으면 제스처 없이 한 번 탭으로 중립(500/500) 투구를 한다.
/// 타이밍 제스처는 VoiceOver·스위치 컨트롤·손 떨림이 있는 사용자에게 게임 자체를 잠근다.
struct DeliveryControl: View {
    /// 피로 0~100. 높을수록 미터가 빨라져 릴리스가 어려워진다.
    let fatigue: Int
    let autoRelease: Bool
    let onDeliver: (PitchDelivery) -> Void
    /// 미터가 방향을 바꿀 때(끝에 닿을 때) 알린다. 화면이 가벼운 햅틱을 준다.
    var onMeterEdge: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressing = false
    @State private var meter: Double = 0
    /// 손가락이 끈 거리. 흔들림을 상쇄하는 데 쓴다.
    @State private var drag: CGSize = .zero
    /// 저절로 생기는 이탈. 미터와 같은 디스플레이 링크가 굴린다.
    @State private var sway: CGSize = .zero
    @State private var wasInSweetSpot = false
    @State private var driver = MeterDriver()

    /// 미터가 한 번 왕복하는 데 걸리는 시간(초). 피로하면 짧아져 조준 창이 좁아진다.
    private var sweepSeconds: Double {
        let base = 1.35 - Double(min(100, max(0, fatigue))) / 100 * 0.55
        return reduceMotion ? base * 1.6 : base
    }

    /// 조준을 최대로 흔들 수 있는 반경(pt). 이 거리에서 aimAccuracy가 0이 된다.
    private static let aimRadius: CGFloat = 46

    /// 저절로 흔들리는 폭(pt). 피로하면 커진다. 반경 46에 대해 이 정도면 가만히 두었을 때
    /// 조준이 500점 근처에서 오르내려, 끌어서 붙잡아야 800점을 넘긴다.
    private var swayAmplitude: CGFloat {
        let base: CGFloat = 26
        let tired = CGFloat(min(100, max(0, fatigue))) / 100 * 16
        return reduceMotion ? (base + tired) * 0.55 : base + tired
    }

    /// 조준점이 목표에 겹쳤는가. 이때 떼야 좋은 공이 간다.
    private var onTarget: Bool {
        let aim = clampedAim
        return sqrt(aim.width * aim.width + aim.height * aim.height) <= 14
    }

    /// 미터가 스위트 스폿 안에 있는가. 촉감으로 경계를 알려 줄 때 쓴다.
    private var inSweetSpot: Bool { abs(meter - 0.5) <= 0.11 }

    /// 스위트 스폿 중심에 얼마나 가까운가(0~1). 진동 세기가 이 값을 따른다.
    private var meterCloseness: Double { 1 - min(1, abs(meter - 0.5) * 2) }

    var body: some View {
        if autoRelease {
            PrimaryPill(title: "던지기", identifier: "pitch.throw") { onDeliver(.neutral) }
                .accessibilityHint("자동 릴리스가 켜져 있어 타이밍 없이 던집니다.")
        } else {
            manual
        }
    }

    private var manual: some View {
        VStack(spacing: 10) {
            meterBar
            gesturePad
        }
        .onAppear { Haptics.shared.prepare() }
        .onDisappear {
            isPressing = false
            driver.stop()
            Haptics.shared.stopWindUp()
        }
    }

    private var meterBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(BaseballTheme.surfaceRaised)
                // 스위트 스폿. 가운데 22%.
                Capsule()
                    .fill(BaseballTheme.action.opacity(0.42))
                    .frame(width: proxy.size.width * 0.22)
                    .offset(x: proxy.size.width * 0.39)
                Capsule()
                    .fill(isPressing ? BaseballTheme.action : BaseballTheme.border)
                    .frame(width: 6)
                    .offset(x: (proxy.size.width - 6) * meter)
            }
            .overlay { Capsule().stroke(BaseballTheme.border.opacity(0.6), lineWidth: 1) }
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }

    private var gesturePad: some View {
        ZStack {
            RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                .fill(isPressing ? BaseballTheme.action.opacity(0.18) : BaseballTheme.action.opacity(0.9))
            if isPressing {
                // 목표. 여기에 조준점을 겹쳐야 한다.
                Circle()
                    .stroke(BaseballTheme.fieldChalk.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .frame(width: 30, height: 30)
                Circle()
                    .fill(BaseballTheme.fieldChalk.opacity(0.5))
                    .frame(width: 5, height: 5)
                // 조준점. 저절로 떠다니고 손가락을 끈 만큼 상쇄된다. 겹칠수록 라임으로 물든다.
                Circle()
                    .stroke(onTarget ? BaseballTheme.action : BaseballTheme.fieldChalk, lineWidth: 2.5)
                    .frame(width: 26, height: 26)
                    .offset(x: clampedAim.width, y: clampedAim.height)
                // "지금"은 조준과 미터가 **둘 다** 맞는 순간에만 — 조준만 보고 외치면
                // 유저가 그 말을 믿고 미터 끝단에서 떼는 잘못된 타이밍을 학습한다(3차 패널 P0).
                Text(onTarget && inSweetSpot ? "지금" : onTarget ? "타이밍을 기다리세요" : "끌어서 맞추세요")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(onTarget && inSweetSpot ? BaseballTheme.action : BaseballTheme.textSecondary)
                    .offset(y: 36)
            } else {
                Text("길게 눌러 와인드업")
                    .font(.headline)
                    .foregroundStyle(BaseballTheme.actionInk)
            }
        }
        .frame(height: 92)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isPressing { beginWindUp() }
                    drag = value.translation
                }
                .onEnded { _ in release() }
        )
        .accessibilityLabel("와인드업")
        .accessibilityHint("길게 눌러 와인드업하고, 끌어서 조준한 뒤 떼면 던집니다. 설정에서 자동 릴리스를 켜면 탭 한 번으로 던집니다.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onDeliver(.neutral) }
    }

    /// 실제 조준 이탈. 저절로 생긴 흔들림에 손가락이 끈 만큼을 더한다.
    private var effectiveAim: CGSize {
        CGSize(width: sway.width + drag.width, height: sway.height + drag.height)
    }

    private var clampedAim: CGSize {
        let aim = effectiveAim
        let length = sqrt(aim.width * aim.width + aim.height * aim.height)
        guard length > Self.aimRadius else { return aim }
        let scale = Self.aimRadius / length
        return CGSize(width: aim.width * scale, height: aim.height * scale)
    }

    private func beginWindUp() {
        isPressing = true
        meter = 0
        drag = .zero
        sway = .zero
        wasInSweetSpot = false
        Haptics.shared.windUpBegan()
        driver.start(
            sweepSeconds: sweepSeconds,
            swayAmplitude: swayAmplitude,
            onTick: { value, offset in
                meter = value
                sway = offset
                Haptics.shared.windUpUpdate(closeness: meterCloseness)
                // 경계를 넘는 순간에만 한 번 친다. 연속 진동만으로는 어디가 시작인지 흐리다.
                if inSweetSpot != wasInSweetSpot {
                    wasInSweetSpot = inSweetSpot
                    if inSweetSpot { Haptics.shared.enteredSweetSpot() }
                }
            },
            onEdge: {
                Haptics.shared.meterEdge()
                onMeterEdge()
            }
        )
    }

    private func release() {
        guard isPressing else { return }
        isPressing = false
        driver.stop()
        let delivery = Self.delivery(meter: meter, aim: clampedAim, aimRadius: Self.aimRadius)
        Haptics.shared.released(
            quality: Double(delivery.releaseAccuracy + delivery.aimAccuracy) / 2_000
        )
        drag = .zero
        sway = .zero
        onDeliver(delivery)
    }

    /// 미터 위치와 조준 이탈을 0~1000 정확도로 옮긴다. 순수 함수라 테스트할 수 있다.
    static func delivery(meter: Double, aim: CGSize, aimRadius: CGFloat) -> PitchDelivery {
        // 미터 0.5가 완벽. 멀어질수록 선형으로 떨어진다.
        let releaseError = min(1, abs(meter - 0.5) * 2)
        let release = Int(((1 - releaseError) * 1_000).rounded())
        let distance = min(Double(aimRadius), sqrt(Double(aim.width * aim.width + aim.height * aim.height)))
        let aimScore = Int(((1 - distance / Double(aimRadius)) * 1_000).rounded())
        return PitchDelivery(
            releaseAccuracy: min(1_000, max(0, release)),
            aimAccuracy: min(1_000, max(0, aimScore))
        )
    }

    /// 방금 던진 투구의 품질을 한 줄로 알려 준다. 손맛에는 즉시 읽히는 판정이 필요하다.
    static func verdict(_ delivery: PitchDelivery) -> (text: String, tone: BaseballCardTone)? {
        guard !delivery.isNeutral else { return nil }
        let score = (delivery.releaseAccuracy + delivery.aimAccuracy) / 2
        switch score {
        case 850...: return ("완벽한 릴리스", .positive)
        case 650..<850: return ("좋은 릴리스", .positive)
        case 400..<650: return ("무난한 릴리스", .standard)
        default: return ("손에서 빠졌습니다", .warning)
        }
    }
}


/// 와인드업 미터를 화면 주사율에 맞춰 굴린다.
///
/// 이전에는 `DispatchQueue.main.asyncAfter`로 60fps를 흉내 냈다. 디스플레이와 동기화되지 않아
/// 120Hz 기기나 프레임이 밀리는 순간에 미터가 튀고, 그러면 손 떼는 타이밍이 곧 결과인 이 조작의
/// 신뢰가 통째로 무너진다. `CADisplayLink`는 실제 프레임에 맞춰 불리고 경과 시간을 직접 주므로
/// 주사율과 무관하게 같은 속도로 왕복한다.
@MainActor
final class MeterDriver {
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var elapsed: Double = 0
    private var value: Double = 0
    private var rising = true
    private var sweepSeconds: Double = 1
    private var swayAmplitude: CGFloat = 0
    private var phases: [Double] = [0, 0, 0, 0]
    private var onTick: ((Double, CGSize) -> Void)?
    private var onEdge: (() -> Void)?

    /// 조준 흔들림의 주기(Hz). 서로 나누어떨어지지 않아야 같은 자리로 돌아오지 않는다.
    /// 규칙적으로 돌면 몇 번 던져 보고 외워 버려서 다시 쉬워진다.
    private static let swayRates: [Double] = [0.83, 1.31, 0.67, 1.13]

    func start(
        sweepSeconds: Double,
        swayAmplitude: CGFloat,
        onTick: @escaping (Double, CGSize) -> Void,
        onEdge: @escaping () -> Void
    ) {
        stop()
        self.sweepSeconds = max(0.2, sweepSeconds)
        self.swayAmplitude = swayAmplitude
        self.onTick = onTick
        self.onEdge = onEdge
        // 매 투구마다 위상을 새로 뽑는다. 고정하면 항상 같은 궤적이라 외울 수 있다.
        phases = (0..<4).map { _ in Double.random(in: 0..<(2 * .pi)) }
        value = 0
        elapsed = 0
        rising = true
        lastTimestamp = 0
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
        onTick = nil
        onEdge = nil
    }

    /// 지금 시각의 흔들림. 사인 두 개를 겹쳐 사람 손의 떨림처럼 불규칙하게 만든다.
    private var sway: CGSize {
        guard swayAmplitude > 0 else { return .zero }
        let rates = Self.swayRates
        let x = 0.62 * sin(2 * .pi * rates[0] * elapsed + phases[0])
            + 0.38 * sin(2 * .pi * rates[1] * elapsed + phases[1])
        let y = 0.58 * sin(2 * .pi * rates[2] * elapsed + phases[2])
            + 0.42 * sin(2 * .pi * rates[3] * elapsed + phases[3])
        return CGSize(width: swayAmplitude * CGFloat(x), height: swayAmplitude * CGFloat(y))
    }

    @objc private func step(_ link: CADisplayLink) {
        // 첫 프레임은 간격을 알 수 없으므로 기준만 잡고 넘어간다.
        guard lastTimestamp > 0 else {
            lastTimestamp = link.timestamp
            return
        }
        let delta = link.timestamp - lastTimestamp
        lastTimestamp = link.timestamp
        // 한 프레임이 크게 밀려도(백그라운드 복귀 등) 미터가 순간이동하지 않게 묶는다.
        let step = min(0.1, delta)
        elapsed += step
        let progress = step / sweepSeconds

        if rising {
            value += progress
            if value >= 1 { value = 1; rising = false; onEdge?() }
        } else {
            value -= progress
            if value <= 0 { value = 0; rising = true; onEdge?() }
        }
        onTick?(value, sway)
    }
}
