import Foundation

/// Rollout gates are injected at the app boundary so Wave 1 can be exercised without changing
/// the production product path.
///
/// 2026-08-17: 사용자 결정으로 pro career journey를 iOS 단독 선행 출시한다. production 기본값을
/// 켠다 — Kotlin/Android 패리티는 후속 웨이브로 유지하고, Android가 Swift oracle을 소비할 때까지
/// 이 플래그는 iOS에서만 의미를 가진다. 근거와 잔여 게이트는
/// `docs/PRO_CAREER_CONTRACT_LEGACY_DEPTH_IMPLEMENTATION_PLAN_2026-08-14.md` §21.7.
struct AppFeatureConfiguration: Equatable, Sendable {
    let proCareerJourneyV1: Bool

    init(proCareerJourneyV1: Bool = false) {
        self.proCareerJourneyV1 = proCareerJourneyV1
    }

    static let production = AppFeatureConfiguration(proCareerJourneyV1: true)
    static let journeyV1Tests = AppFeatureConfiguration(proCareerJourneyV1: true)
    /// 구버전 공개 빌드(≤1.1.x)의 legacy 스키마-2 라이터 동작을 회귀 테스트하기 위한 고정 설정.
    /// production이 journey로 넘어간 뒤에도 구빌드와의 저장 세대 규약은 계속 검증해야 한다.
    static let legacyTests = AppFeatureConfiguration(proCareerJourneyV1: false)
}
