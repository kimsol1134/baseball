import Foundation
import FirebaseCore
import FirebaseAnalytics
import AmplitudeSwift

/// 게임 분석 — activation 퍼널(설치 → 온보딩 → 첫 경기 → 반복)을 눈으로 보기 위한 최소 계측.
///
/// 원칙:
/// - **설정이 없으면 전부 무동작.** GoogleService-Info.plist가 번들에 없으면 Firebase를
///   켜지 않고, Info.plist의 AMPLITUDE_API_KEY가 비어 있으면 Amplitude를 켜지 않는다.
///   키를 넣기 전까지 이 파일은 앱 동작·심사·개인정보 라벨에 아무 영향이 없다.
/// - **이벤트는 적게, 신호만.** 화면 조회를 다 찍으면 대시보드가 소음이 된다. 여기 있는
///   이벤트는 전부 "퍼널의 계단"이거나 "리텐션의 증거"다.
/// - **activation은 1인 1회.** 광고 전환으로 집계되는 이벤트는 기기당 한 번만 보낸다.
/// - IDFA·ATT는 쓰지 않는다. 어트리뷰션은 SKAdNetwork가 프롬프트 없이 처리한다.
@MainActor
enum GameAnalytics {
    /// 퍼널의 계단들. 이름은 한 번 정하면 바꾸지 않는다 — 바꾸면 대시보드 역사가 끊긴다.
    enum Event: String {
        /// 선수 만들기 진입(설치 후 첫 의미 행동).
        case onboardingStarted = "onboarding_started"
        /// 커리어 생성 완료(이름·스타일·학교까지 통과).
        case onboardingCompleted = "onboarding_completed"
        /// 첫 불펜 투구 — 손맛을 처음 본 순간.
        case firstPitch = "first_pitch"
        /// **activation: 첫 중요 경기 완료.** 사인→투구→판정→기록의 코어 루프를
        /// 한 바퀴 다 돈 순간이다. 광고 캠페인의 전환 목표가 이 이벤트다.
        case activationFirstGame = "activation_first_game"
        /// 경기 완료(반복 사용 신호).
        case gameFinished = "game_finished"
        /// 챕터 전진(진행 깊이).
        case chapterAdvanced = "chapter_advanced"
        /// 드래프트 결과(성공 여부 포함).
        case draftResolved = "draft_resolved"
        /// 환생 시작 — 이 게임의 코어 리텐션 신호. 회차를 다시 시작하는 사람이 남는 사람이다.
        case rebirthStarted = "rebirth_started"
        /// 회차 카드 공유(바이럴 신호).
        case lifeCardShared = "life_card_shared"
    }

    private static var amplitude: Amplitude?
    private static var enabled = false
    private static let onceKeyPrefix = "baseball.analytics.once."

    /// 앱 시작 시 한 번. 설정이 없으면 조용히 꺼진 채 남는다.
    static func configure() {
        // Firebase: 콘솔에서 받은 plist가 있어야만 켠다. 없는데 configure()를 부르면 크래시다.
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
            enabled = true
        }
        if let key = Bundle.main.object(forInfoDictionaryKey: "AMPLITUDE_API_KEY") as? String,
           !key.isEmpty {
            amplitude = Amplitude(configuration: Configuration(apiKey: key))
            enabled = true
        }
    }

    static func log(_ event: Event, _ properties: [String: Any] = [:]) {
        guard enabled else { return }
        Analytics.logEvent(event.rawValue, parameters: properties.isEmpty ? nil : properties)
        amplitude?.track(eventType: event.rawValue, eventProperties: properties)
    }

    /// 1인 1회 이벤트. 전환으로 집계되는 계단(activation 등)은 두 번 세면 데이터가 거짓이 된다.
    /// 반환값: 실제로 이번에 처음 기록했는가.
    @discardableResult
    static func logOnce(_ event: Event, _ properties: [String: Any] = [:]) -> Bool {
        let key = onceKeyPrefix + event.rawValue
        guard !UserDefaults.standard.bool(forKey: key) else { return false }
        UserDefaults.standard.set(true, forKey: key)
        log(event, properties)
        return true
    }

    /// 테스트용 — once 상태를 되돌린다.
    static func resetOnceFlags() {
        for event in [Event.onboardingStarted, .onboardingCompleted, .firstPitch, .activationFirstGame] {
            UserDefaults.standard.removeObject(forKey: onceKeyPrefix + event.rawValue)
        }
    }
}
