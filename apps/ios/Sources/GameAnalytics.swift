import Foundation
import FirebaseCore
import FirebaseAnalytics
import AmplitudeSwift

/// Every analytics event carries the same low-cardinality build context.
///
/// Distribution detection is kept pure so a Release build using a sandbox receipt is never
/// mistaken for production traffic. UI tests are filtered before either SDK is configured.
struct AnalyticsContext: Equatable {
    enum Distribution: String, Equatable {
        case debug
        case testflight
        case appStore = "app_store"
        /// Ad-hoc/enterprise Release builds can have no App Store receipt. They must never
        /// masquerade as the production cohort merely because `DEBUG` is absent.
        case unknown
    }

    enum Environment: String, Equatable {
        case development
        case production
    }

    let appVersion: String
    let build: String
    let distribution: Distribution
    let environment: Environment

    var properties: [String: Any] {
        [
            "app_version": appVersion,
            "build": build,
            "distribution": distribution.rawValue,
            "environment": environment.rawValue,
            "platform": "ios",
        ]
    }

    static func resolve(
        appVersion: String,
        build: String,
        isDebug: Bool,
        receiptURL: URL?
    ) -> AnalyticsContext {
        let distribution: Distribution
        if isDebug {
            distribution = .debug
        } else if receiptURL?.lastPathComponent == "sandboxReceipt" {
            distribution = .testflight
        } else if receiptURL != nil {
            distribution = .appStore
        } else {
            distribution = .unknown
        }
        return AnalyticsContext(
            appVersion: appVersion,
            build: build,
            distribution: distribution,
            environment: distribution == .appStore ? .production : .development
        )
    }

    static func current(bundle: Bundle = .main) -> AnalyticsContext {
        #if DEBUG
        let isDebug = true
        #else
        let isDebug = false
        #endif
        return resolve(
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            isDebug: isDebug,
            receiptURL: bundle.appStoreReceiptURL
        )
    }
}

/// The two SDK destinations intentionally receive different payloads. Firebase keeps the
/// existing shared context, while Amplitude direct events carry an origin marker for source
/// auditing.
struct AnalyticsPayloads {
    let firebase: [String: Any]
    let amplitude: [String: Any]
}

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
        /// 시스템 공유 UI를 연 시점. 완료와 구분한다.
        case lifeCardShareTapped = "life_card_share_tapped"
        /// 시스템 공유 콜백이 성공으로 끝난 시점.
        case lifeCardShareCompleted = "life_card_share_completed"
        /// 회차 시작에서 약속을 고른 시점.
        case runPledgeSelected = "run_pledge_selected"
        /// 회차 끝에서 약속 결과가 확정된 시점.
        case runPledgeResolved = "run_pledge_resolved"
        /// 회차의 바람 카드가 실제로 처음 노출된 시점.
        case careerWindSeen = "career_wind_seen"
        /// 다음 회차에서 다시 시도할 약속을 저장한 시점.
        case nextRunIntentSaved = "next_run_intent_saved"
        /// 저장한 약속을 다음 회차에서 실제로 선택한 시점.
        case nextRunIntentApplied = "next_run_intent_applied"
        /// 주간 야구 노트 상세를 연 시점.
        case weeklyProgramOpened = "weekly_program_opened"
        /// 주간 야구 노트의 2/3 보상을 확정한 시점.
        case weeklyProgramCompleted = "weekly_program_completed"
        /// 프로 시즌 중 3주 단위 결정을 확정한 시점.
        case proSeasonDecisionSelected = "pro_season_decision_selected"
        /// 프로 은퇴 기록·야구혼·대표 유산 후보가 고교 저장에 원자적으로 접힌 시점.
        case proLegacyRecorded = "pro_legacy_recorded"
        /// 결산·기록·다음 회차에서 전 선수가 남긴 말을 실제로 본 시점.
        case playerLegacySeen = "player_legacy_seen"
        /// 선수가 실제 중요한 순간에 건넨 속마음 카드가 보인 시점.
        case playerHeartlineSeen = "player_heartline_seen"
        /// 3년 돌아보기에서 다음 선수로 넘어가는 주 행동을 누른 시점.
        case recapContinueTapped = "recap_continue_tapped"
        /// 한 선수의 성장·경기 기록으로 합성된 대표 유산 세 후보가 실제로 보인 시점.
        case signatureLegacyOptionsSeen = "signature_legacy_options_seen"
        /// 대표 유산 세 후보 중 하나를 직접 고른 시점.
        case signatureLegacySelected = "signature_legacy_selected"
        /// 발견 목록의 대표 유산 하나가 새 선수의 시작 능력에 실제 적용된 시점.
        case signatureLegacyEquipped = "signature_legacy_equipped"
        /// 기억·대표 유산·야구혼까지 원자적으로 정산돼 한 선수의 인생이 닫힌 시점.
        case lifeCompleted = "life_completed"
        /// 사용자가 고른 훈련이 상태에 실제 반영된 시점.
        case careerTrainingCompleted = "career_training_completed"
        /// 직접 던진 과정이 능력치 성장으로 실제 반영된 시점.
        case gameGrowthApplied = "game_growth_applied"

        // MARK: - 이탈 지점을 보기 위한 계측 (2026-08 Amplitude 분석)
        //
        // 위 9개만으로는 **화면 단위 이탈이 안 보인다.** 실제 데이터에서 first_pitch(53명)
        // → activation_first_game(43명) 사이에서 19%가 사라졌는데, 그 사이에 있는 네
        // 국면(학교 선택·훈련·관계·중요 경기) 중 어디서 끊겼는지 알 방법이 없었다.

        /// 고교 커리어 국면 진입. `phase` 속성으로 어느 계단에서 끊기는지 본다.
        case phaseEntered = "phase_entered"
        /// 중요 경기를 던지다 중단. 손맛 구간의 이탈이다.
        case gameAbandoned = "game_abandoned"
        /// 제거된 일일 모드의 과거 화면 진입 이벤트. 새 호출 경로는 없다.
        case dailyInningOpened = "daily_inning_opened"
        /// 제거된 일일 모드의 과거 보상 이벤트. 분석 스키마 호환을 위해 이름만 보존한다.
        case dailyInningRewarded = "daily_inning_rewarded"
        /// 프로 커리어 진입. draft_resolved 이후의 **정상 분기**라, 이게 없으면
        /// "드래프트 후 환생하지 않은 사람 = 이탈"이라는 잘못된 결론이 나온다.
        case proCareerStarted = "pro_career_started"
        /// 복귀 알림 상태 변화. `enabled`가 켜짐/꺼짐, `source`가 어디서 결정됐는지다.
        case reminderChanged = "reminder_changed"
        /// 복귀 알림 권유 카드가 실제 화면 계층에 나타난 시점. 허용률의 분모다.
        case reminderOfferShown = "reminder_offer_shown"
        /// 복귀 알림을 눌러 앱으로 돌아옴. D1 훅이 실제로 작동하는지의 증거다.
        case reminderOpened = "reminder_opened"
        /// 이전 세션에서 남긴 한 가지를 앱 안의 복귀 카드로 실제 보여 준 시점.
        case returnPlanShown = "return_plan_shown"
        /// 복귀 카드에서 약속한 화면으로 바로 이어 간 시점.
        case returnPlanTapped = "return_plan_tapped"
        /// 복귀 카드를 닫고 다른 행동을 택한 시점. 반복 노출이 성가신지 보는 가드레일이다.
        case returnPlanDismissed = "return_plan_dismissed"
        /// 사용자가 떠날 때 다음 행동이 있었고 대조군·실험군이 고정된 시점.
        case returnPlanEligible = "return_plan_eligible"
        /// 저장된 계획 다음 서울 날짜에 앱 프로세스가 새로 시작된 시점.
        case returnPlanColdStart = "return_plan_cold_start"
        /// 저장된 계획 다음 서울 날짜에 cold 또는 warm으로 앱이 활성화된 시점.
        case returnPlanNextDayOpen = "return_plan_next_day_open"
        /// 세션 종료(백그라운드 전환). `games`로 세션 깊이를 잰다.
        case sessionEnded = "session_ended"
    }

    private static var amplitude: Amplitude?
    private static var enabled = false
    private static var context = AnalyticsContext.current()
    /// Unit-test observation point. Analytics SDK configuration remains unnecessary in tests.
    static var eventSinkForTesting: ((Event, [String: Any]) -> Void)?
    private static let onceKeyPrefix = "baseball.analytics.once."
    private static let amplitudeOnlyProperties: [String: Any] = [
        "ingestion_origin": "ios_sdk_direct",
        "event_schema_version": 2,
    ]
    /// 기기를 가로지르는 안정 식별자 키. iCloud 키-값 저장소에도 거울을 둔다.
    private static let stableIDKey = "baseball.analytics.stableID"
    private static let completedGameCountKey = "baseball.analytics.completedGameCount"

    /// 앱 시작 시 한 번. 설정이 없으면 조용히 꺼진 채 남는다.
    static func configure() {
        // UI 테스트의 기계 플레이가 대시보드에 섞이면 퍼널이 거짓말이 된다.
        guard !isUITest(arguments: ProcessInfo.processInfo.arguments) else {
            amplitude = nil
            enabled = false
            return
        }
        context = .current()
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
        guard enabled else { return }
        let id = stableID()
        amplitude?.setUserId(userId: id)
        Analytics.setUserID(id)
    }

    /// 앱을 지웠다 다시 깔아도 같은 사람으로 이어지는 익명 ID.
    ///
    /// 기본 식별자는 기기별 설치 ID라, 재설치하면 같은 사람이 새 유저로 잡힌다. 회차를
    /// 수십 시간 쌓는 게임에서 그건 리텐션 통계를 낙관적으로 왜곡한다(이탈로 세지 않고
    /// 신규로 센다). 세이브와 같은 iCloud 키-값 저장소에 거울을 두어 기기·재설치를
    /// 가로지른다. IDFA·IDFV·전화번호 같은 기기 식별자는 쓰지 않는다 — 이 값은 앱이
    /// 스스로 만든 난수이고, 진행을 지우면 함께 사라진다.
    static func stableID(defaults: UserDefaults = .standard) -> String {
        if let local = defaults.string(forKey: stableIDKey), !local.isEmpty { return local }
        let cloud = NSUbiquitousKeyValueStore.default
        if let remote = cloud.string(forKey: stableIDKey), !remote.isEmpty {
            defaults.set(remote, forKey: stableIDKey)
            return remote
        }
        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: stableIDKey)
        cloud.set(fresh, forKey: stableIDKey)
        return fresh
    }

    /// 세션의 실제 경기 완료 수. 고교 누적 경기 수를 세션 값으로 잘못 보내던 계측을
    /// 대체한다. UI 테스트의 기계 플레이는 이 카운터에도 섞지 않는다.
    static func completedGameCount(defaults: UserDefaults = .standard) -> Int {
        defaults.integer(forKey: completedGameCountKey)
    }

    /// UI 테스트의 `커리어 초기화`는 화면을 바꾸는 완료 경기 수도 함께 지워야 한다.
    /// 커리어 파일만 지우고 이 값을 남기면 복귀 안내가 새 테스트 위를 덮어, 같은 실행
    /// 인자에서도 직전 테스트 순서에 따라 첫 화면이 달라진다.
    static func resetCompletedGameCountForUITesting(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: completedGameCountKey)
    }

    static func recordCompletedGame(defaults: UserDefaults = .standard) {
        guard !isUITest(arguments: ProcessInfo.processInfo.arguments) else { return }
        defaults.set(completedGameCount(defaults: defaults) + 1, forKey: completedGameCountKey)
    }

    /// Builds the destination-specific payloads without configuring either SDK.
    ///
    /// Keeping this pure makes the ingestion contract testable and prevents the source marker
    /// from leaking into Firebase, whose existing payload must remain unchanged.
    static func payloads(
        for properties: [String: Any],
        context: AnalyticsContext
    ) -> AnalyticsPayloads {
        let firebase = properties.merging(context.properties) { _, common in common }
        let amplitude = firebase.merging(amplitudeOnlyProperties) { _, direct in direct }
        return AnalyticsPayloads(firebase: firebase, amplitude: amplitude)
    }

    static func log(_ event: Event, _ properties: [String: Any] = [:]) {
        eventSinkForTesting?(event, properties)
        guard enabled else { return }
        let reserved = Set(context.properties.keys).union(amplitudeOnlyProperties.keys)
        let collisions = reserved.intersection(properties.keys)
        assert(collisions.isEmpty, "Analytics context keys are reserved: \(collisions.sorted())")
        let payloads = Self.payloads(for: properties, context: context)
        Analytics.logEvent(event.rawValue, parameters: payloads.firebase)
        amplitude?.track(eventType: event.rawValue, eventProperties: payloads.amplitude)
    }

    nonisolated static func isUITest(arguments: [String]) -> Bool {
        arguments.contains("-uiTestResetCareer") || arguments.contains("-uiTestPromoCapture")
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

    /// One event per local scope (for example one wind impression per career) without sending
    /// the high-cardinality scope itself to analytics.
    @discardableResult
    static func logOnce(
        _ event: Event,
        scope: String,
        properties: [String: Any] = [:],
        defaults: UserDefaults = .standard
    ) -> Bool {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in scope.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        let key = "\(onceKeyPrefix)\(event.rawValue).\(String(hash, radix: 16))"
        guard !defaults.bool(forKey: key) else { return false }
        defaults.set(true, forKey: key)
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
