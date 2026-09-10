import Foundation

/// Version gate for catcher sign policy.
///
/// Version 1 is the fixture-safe path: cold-zone shift, staircase adaptation, no extra
/// sequencing. Pitch kernel exporters, CLI, automatic tests, and default `PitchKernelEngine()`
/// stay on 1. Version 2 is live play only — `PitchSession` is the caller that opts in.
public struct CatcherSignRules: Equatable, Sendable {
    public var version: Int

    public static let fixtureSafeVersion = 1
    public static let livePlayVersion = 2
    /// Version 3 is the Android-parity targeting used by professional automatic outings: the zone
    /// is ranked from the scouting read and the last four pitches instead of shifted off the cold
    /// zone. It is a different algorithm from version 2, not a superset, so the two never overlap.
    public static let scoutingTargetVersion = 3

    public init(version: Int = 1) {
        self.version = version
    }

    /// Version 2 only. Version 3 replaces this with `usesScoutingTargets`.
    public var usesVariety: Bool { version == Self.livePlayVersion }

    /// Version 3: rank every legal zone and shy away from the ones just thrown.
    public var usesScoutingTargets: Bool { version >= Self.scoutingTargetVersion }
}
