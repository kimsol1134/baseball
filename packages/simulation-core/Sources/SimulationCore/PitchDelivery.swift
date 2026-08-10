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
    /// 950은 미터 반폭의 5% — 스위트 스폿(22%)의 4분의 1이라, 노려야 나오고 운으로는 안 나온다.
    public static let perfectReleaseThreshold = 950

    /// 정중앙 릴리스인가. 중립(500)은 절대 여기 닿지 않으므로, 이 값을 보는 규칙은
    /// 델리버리를 넘기지 않던 모든 호출자에게 항등이다.
    public var isPerfectRelease: Bool { releaseAccuracy >= Self.perfectReleaseThreshold }
}
