import CoreHaptics
import UIKit

/// 투구 제스처의 촉감.
///
/// 이 게임에서 손으로 하는 일은 하나뿐이다 — 누르고, 끌고, 뗀다. 그 하나에 촉감이 없으면
/// 화면을 문지르는 것과 다르지 않다. 특히 **와인드업 중 스위트 스폿에 가까워질수록 진동이
/// 세지는** 것이 중요하다. 그러면 미터를 눈으로 좇지 않고도 타이밍을 익힐 수 있고, 익히고
/// 나면 화면을 보지 않고 던지게 된다. 그 순간 조작이 몸에 붙는다.
///
/// Core Haptics는 iPhone 8 이상에서만 되고 시뮬레이터에는 없다. 안 되는 기기에서는
/// `UIImpactFeedbackGenerator`로 떨어진다 — 세기 조절은 못 하지만 아무것도 없는 것보다 낫다.
@MainActor
final class Haptics {
    static let shared = Haptics()

    private var engine: CHHapticEngine?
    private var windUpPlayer: CHHapticAdvancedPatternPlayer?
    private var supportsHaptics: Bool { CHHapticEngine.capabilitiesForHardware().supportsHaptics }

    /// 폴백용. 준비해 두지 않으면 첫 진동이 눈에 띄게 늦다.
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notice = UINotificationFeedbackGenerator()

    private var isEnabled: Bool { GameAudio.shared.hapticsEnabled }

    private init() {}

    /// 화면에 들어올 때 부른다. 엔진을 미리 켜 두지 않으면 첫 와인드업이 밋밋하다.
    func prepare() {
        light.prepare()
        medium.prepare()
        rigid.prepare()
        guard supportsHaptics, engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            // 전화가 오거나 앱이 백그라운드에 다녀오면 엔진이 멈춘다. 알아서 살아나게 둔다.
            engine.isAutoShutdownEnabled = true
            engine.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            engine.stoppedHandler = { _ in }
            try engine.start()
            self.engine = engine
        } catch {
            // 촉감은 게임 진행의 전제 조건이 아니다. 실패하면 조용히 폴백으로 간다.
            engine = nil
        }
    }

    func teardown() {
        stopWindUp()
        engine?.stop()
        engine = nil
    }

    // MARK: - 와인드업

    /// 누르기 시작. 공을 쥐는 느낌으로 짧고 무르게.
    func windUpBegan() {
        guard isEnabled else { return }
        guard supportsHaptics, let engine else { return medium.impactOccurred(intensity: 0.7) }
        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.6),
                    .init(parameterID: .hapticSharpness, value: 0.25),
                ],
                relativeTime: 0
            )
            try engine.makePlayer(with: CHHapticPattern(events: [event], parameters: [])).start(atTime: 0)

            // 뗄 때까지 계속 울리는 진동. 세기는 아래 update에서 실시간으로 바꾼다.
            let sustained = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.2),
                    .init(parameterID: .hapticSharpness, value: 0.2),
                ],
                relativeTime: 0,
                duration: 30
            )
            let player = try engine.makeAdvancedPlayer(with: CHHapticPattern(events: [sustained], parameters: []))
            try player.start(atTime: 0)
            windUpPlayer = player
        } catch {
            medium.impactOccurred(intensity: 0.7)
        }
    }

    /// 미터가 움직일 때마다 부른다. `closeness`가 1이면 스위트 스폿 한가운데다.
    ///
    /// 세기를 제곱으로 올린다. 선형으로 하면 어디가 가운데인지 손에 잡히지 않는다 —
    /// 가까울 때만 확 세져야 "여기다" 하고 뗄 수 있다.
    func windUpUpdate(closeness: Double) {
        guard isEnabled, let player = windUpPlayer else { return }
        let clamped = min(1, max(0, closeness))
        let intensity = Float(0.12 + 0.62 * clamped * clamped)
        let sharpness = Float(0.15 + 0.6 * clamped)
        try? player.sendParameters(
            [
                .init(parameterID: .hapticIntensityControl, value: intensity, relativeTime: 0),
                .init(parameterID: .hapticSharpnessControl, value: sharpness, relativeTime: 0),
            ],
            atTime: CHHapticTimeImmediate
        )
    }

    /// 스위트 스폿에 막 들어섰을 때 한 번. 연속 진동만으로는 경계가 흐려서 놓친다.
    func enteredSweetSpot() {
        guard isEnabled else { return }
        guard supportsHaptics, let engine else { return light.impactOccurred(intensity: 0.5) }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 0.45),
                .init(parameterID: .hapticSharpness, value: 0.9),
            ],
            relativeTime: 0
        )
        try? engine.makePlayer(with: CHHapticPattern(events: [event], parameters: [])).start(atTime: 0)
    }

    /// 미터가 끝에 닿아 방향을 바꿀 때. 벽에 부딪히는 느낌으로 무디게.
    func meterEdge() {
        guard isEnabled else { return }
        guard supportsHaptics, let engine else { return light.impactOccurred(intensity: 0.35) }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 0.3),
                .init(parameterID: .hapticSharpness, value: 0.15),
            ],
            relativeTime: 0
        )
        try? engine.makePlayer(with: CHHapticPattern(events: [event], parameters: [])).start(atTime: 0)
    }

    /// 손을 뗀 순간. 잘 던졌으면 날카롭게 한 번, 놓쳤으면 무디게 두 번.
    func released(quality: Double) {
        stopWindUp()
        guard isEnabled else { return }
        let clamped = min(1, max(0, quality))
        guard supportsHaptics, let engine else {
            return clamped > 0.6 ? rigid.impactOccurred(intensity: 0.9) : medium.impactOccurred(intensity: 0.5)
        }
        var events: [CHHapticEvent] = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: Float(0.5 + 0.5 * clamped)),
                    .init(parameterID: .hapticSharpness, value: Float(0.3 + 0.65 * clamped)),
                ],
                relativeTime: 0
            )
        ]
        if clamped < 0.45 {
            // 손에서 빠진 공. 두 번째 둔탁한 진동이 "어긋났다"를 몸으로 알려 준다.
            events.append(
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.35),
                        .init(parameterID: .hapticSharpness, value: 0.1),
                    ],
                    relativeTime: 0.09
                )
            )
        }
        try? engine.makePlayer(with: CHHapticPattern(events: events, parameters: [])).start(atTime: 0)
    }

    func stopWindUp() {
        try? windUpPlayer?.stop(atTime: CHHapticTimeImmediate)
        windUpPlayer = nil
    }

    // MARK: - 결과

    /// 승부 결과. 성공·실패를 손으로 구분할 수 있어야 화면을 안 봐도 흐름이 읽힌다.
    func outcome(success: Bool) {
        guard isEnabled else { return }
        notice.notificationOccurred(success ? .success : .warning)
    }
}
