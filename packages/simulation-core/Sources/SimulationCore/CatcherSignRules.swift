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

    public init(version: Int = 1) {
        self.version = version
    }

    public var usesVariety: Bool { version >= Self.livePlayVersion }
}
