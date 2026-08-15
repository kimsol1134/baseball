import Foundation

/// Rollout gates are injected at the app boundary so Wave 1 can be exercised without changing
/// the production product path. The public-build default stays off until the later release gate.
struct AppFeatureConfiguration: Equatable, Sendable {
    let proCareerJourneyV1: Bool

    init(proCareerJourneyV1: Bool = false) {
        self.proCareerJourneyV1 = proCareerJourneyV1
    }

    static let production = AppFeatureConfiguration(proCareerJourneyV1: false)
    static let journeyV1Tests = AppFeatureConfiguration(proCareerJourneyV1: true)
}
