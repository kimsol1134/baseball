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
}
