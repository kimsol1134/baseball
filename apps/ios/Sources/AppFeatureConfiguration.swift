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
    /// 구버전 공개 빌드(≤1.1.x)의 legacy 스키마-2 라이터 동작을 회귀 테스트하기 위한 고정 설정.
    /// production 기본값이 바뀌어도 구빌드와의 저장 세대 규약은 이 설정으로 검증한다.
    static let legacyTests = AppFeatureConfiguration(proCareerJourneyV1: false)
}
