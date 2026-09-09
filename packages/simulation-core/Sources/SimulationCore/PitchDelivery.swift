import Foundation

/// How well the player physically executed the delivery — the release timing and the steadiness of
/// the aim. Both are 0–1000 with **500 as the neutral value that means "no input"**.
///
/// This is an *execution* input, not a judgment input. It nudges how close the ball lands to the
/// intended target and nothing else: the batter's plan, the scouting read and the resolution path
/// never see it, so the ADR-005 boundary (situation may change intent; execution and resolution
/// stay blind) is unchanged.
///
/// It is passed as a separate argument to `submitPitch(_:delivery:)` rather than as a field on
/// `SubmitPitchParams`. Growing that struct by one more optional trips the Swift 6.3 outlined-destroy
/// codegen defect this package already works around elsewhere (see `CareerScheduleSnapshot`): the
/// full test suite segfaults even though every test passes in isolation. Keeping the parameter out
/// of the struct leaves its layout — and the RPC payload shape — untouched.
///
/// Omitting it reproduces the pre-delivery behaviour bit for bit, and so does `.neutral`.
/// See `docs/IOS_TOP_TIER_PLAN.md` §3.2.
public struct PitchDelivery: Codable, Equatable, Sendable {
    /// Release-timing accuracy, 0–1000. 500 is neutral.
    public let releaseAccuracy: Int
    /// Aim steadiness, 0–1000. 500 is neutral.
    public let aimAccuracy: Int

    /// The value that reproduces the behaviour of passing no delivery at all.
    public static let neutral = PitchDelivery(releaseAccuracy: 500, aimAccuracy: 500)

    public init(releaseAccuracy: Int, aimAccuracy: Int) {
        self.releaseAccuracy = releaseAccuracy
        self.aimAccuracy = aimAccuracy
    }

    /// True when this delivery leaves every derived value untouched.
    public var isNeutral: Bool { releaseAccuracy == 500 && aimAccuracy == 500 }

    /// 미터 정중앙에서 손을 뗀 공의 경계.
    ///
    /// 이 게임에서 손으로 하는 일은 하나뿐인데, 그 하나를 **완벽하게** 해낸 순간에 아무
    /// 일도 일어나지 않았다. 선형 곡선은 995와 940을 거의 같게 취급하니, 정확히 가운데를
    /// 맞히려는 이유가 없었다 — "적당히 초록 구간"이 최적 전략이었다. 이 문턱 위에서만
    /// 붙는 별도의 가산이 그 한 뼘을 노릴 이유를 만든다.
    ///
    /// 975는 미터 전체 폭의 2.5%만 허용한다. 빠른 포심 기준으로는 한두 프레임 안에
    /// 손을 떼야 하므로, 초록 구간에 들어온 것과 완벽히 가운데를 맞힌 것이 분명히 갈린다.
    public static let perfectReleaseThreshold = 975

    /// 정중앙 릴리스인가. 중립(500)은 절대 여기 닿지 않으므로, 이 값을 보는 규칙은
    /// 델리버리를 넘기지 않던 모든 호출자에게 항등이다.
    public var isPerfectRelease: Bool { releaseAccuracy >= Self.perfectReleaseThreshold }
}

/// Manual-input calibration only. Persist the calibrated delivery once; replays must never apply
/// this a second time. Low command, neutral inputs and the raw perfect threshold remain unchanged.
public enum PitchReleaseWindow {
    public static let baseWidthPermille = 180
    public static let maximumWidthPermille = 240
    public static let stableReleaseThreshold = 820
    public static let baselineCommand = 35

    /// More of the bounded margin arrives early; all anchors remain within the original 18–24% cap.
    public static let milestones = [40, 50, 65, 80]
    public static func nextMilestone(command: Int) -> Int? { milestones.first { $0 > command } }
    public static func crossesMilestone(before: Int, after: Int) -> Bool {
        after > before && milestones.contains { before < $0 && after >= $0 }
    }
    private static let anchors = [(35, 180), (40, 195), (50, 210), (65, 225), (80, 240)]
    public static func widthPermille(command: Int) -> Int {
        let value = min(80, max(baselineCommand, command))
        for index in 1..<anchors.count {
            let (upper, end) = anchors[index]
            let (lower, start) = anchors[index - 1]
            if value <= upper { return start + (value - lower) * (end - start) / (upper - lower) }
        }
        return maximumWidthPermille
    }

    public static func width(command: Int) -> Double { Double(widthPermille(command: command)) / 1_000 }

    public static func calibratedAccuracy(raw: Int, command: Int) -> Int {
        let raw = min(1_000, max(0, raw))
        let perfect = PitchDelivery.perfectReleaseThreshold
        guard raw > 500, raw < perfect else { return raw }
        let edge = 1_000 - widthPermille(command: command)
        if raw <= edge {
            return 500 + (raw - 500) * (stableReleaseThreshold - 500) / (edge - 500)
        }
        return min(perfect - 1, stableReleaseThreshold + (raw - edge) * (perfect - stableReleaseThreshold) / (perfect - edge))
    }

    public static func rawAccuracy(meter: Double) -> Int {
        guard meter.isFinite else { return 0 }
        return min(1_000, max(0, Int(((1 - min(1, abs(meter - 0.5) * 2)) * 1_000).rounded())))
    }

    public static func contains(meter: Double, command: Int) -> Bool {
        calibratedAccuracy(raw: rawAccuracy(meter: meter), command: command) >= stableReleaseThreshold
    }

    /// 바늘이 릴리스 지점 부근에서 느려지는 폭(미터 단위). 금색 창을 덮을 만큼 넓고,
    /// 초록 창의 타이밍은 그대로 둘 만큼 좁다.
    public static let releaseDwellSpan = 0.09

    /// 정중앙에 머무는 정도. 제구가 오를수록 더 오래 머문다 — 가장 맞히기 어려운 것이
    /// 성장으로 실제로 쉬워지는 자리다.
    public static func releaseDwell(command: Int) -> Double {
        let value = min(80, max(baselineCommand, command))
        return 0.60 + Double(value - baselineCommand) / 45.0 * 0.18
    }

    /// 지금부터 바늘이 다음번 정중앙에 앉기까지 남은 시간(초).
    ///
    /// 감속은 가운데를 가운데에 그대로 두므로 통과 시각은 선형 왕복과 같다. 예고 신호를
    /// 정확한 시각에 놓을 수 있는 이유다.
    public static func secondsToRelease(elapsed: Double, sweepSeconds: Double) -> Double {
        guard elapsed.isFinite, elapsed >= 0, sweepSeconds.isFinite, sweepSeconds > 0 else { return 0 }
        let legs = elapsed / sweepSeconds
        let next = (legs - 0.5).rounded(.down) + 1.5
        return max(0, next * sweepSeconds - elapsed)
    }

    /// 경과 시간의 바늘 위치(0~1).
    ///
    /// 금색 창은 미터의 2.5%라 선형 왕복으로는 25ms 만에 지나갔다 — 가장 보상이 큰 조작이
    /// 사실상 운이었다. 주기와 초록 창의 시간은 그대로 두고, 릴리스 지점 부근에서만
    /// 바늘을 늦춘다.
    public static func meterPosition(elapsed: Double, sweepSeconds: Double, command: Int) -> Double {
        guard elapsed.isFinite, elapsed >= 0, sweepSeconds.isFinite, sweepSeconds > 0 else { return 0 }
        let sweep = elapsed / sweepSeconds
        let whole = sweep.rounded(.down)
        let fraction = sweep - whole
        let linear = Int(whole) % 2 == 0 ? fraction : 1 - fraction
        let offset = 2 * linear - 1
        let ratio = offset / releaseDwellSpan
        let eased = offset * (1 - releaseDwell(command: command) * exp(-ratio * ratio))
        return (eased + 1) / 2
    }
}
