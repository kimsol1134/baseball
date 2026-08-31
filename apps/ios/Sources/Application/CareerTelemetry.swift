import Foundation

/// Application이 Platform 분석·연속 기록 구현을 직접 부르지 않게 하는 창구.
/// 이벤트 이름과 전송은 GameAnalytics가 맡고, 스토어는 여기만 본다.
@MainActor
enum CareerTelemetry {
    typealias Event = GameAnalytics.Event

    static func log(_ event: Event, _ properties: [String: Any] = [:]) {
        GameAnalytics.log(event, properties)
    }

    @discardableResult
    static func logOnce(_ event: Event, _ properties: [String: Any] = [:]) -> Bool {
        GameAnalytics.logOnce(event, properties)
    }

    @discardableResult
    static func logOnce(
        _ event: Event,
        scope: String,
        properties: [String: Any] = [:]
    ) -> Bool {
        GameAnalytics.logOnce(event, scope: scope, properties: properties)
    }

    static func recordCompletedGame() {
        GameAnalytics.recordCompletedGame()
    }

    static func stableID() -> String {
        GameAnalytics.stableID()
    }

    static func configure() {
        GameAnalytics.configure()
    }

    static func completedGameCount(defaults: UserDefaults = .standard) -> Int {
        GameAnalytics.completedGameCount(defaults: defaults)
    }

    static func resetCompletedGameCountForUITesting(defaults: UserDefaults = .standard) {
        GameAnalytics.resetCompletedGameCountForUITesting(defaults: defaults)
    }

    static func logShareFinish(_ finish: ShareFinish, _ properties: [String: Any] = [:]) {
        GameAnalytics.logShareFinish(finish, properties)
    }
}

@MainActor
enum CareerReviewPrompt {
    typealias Reason = ReviewPrompt.Reason

    static func shouldAsk(
        _ reason: Reason,
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> Bool {
        ReviewPrompt.shouldAsk(reason, now: now, defaults: defaults)
    }

    static func reset(defaults: UserDefaults = .standard) {
        ReviewPrompt.reset(defaults: defaults)
    }
}

enum CareerPlayClock {
    static func recordPlay(now: Date = Date()) {
        DailyStreak.recordPlay(now: now)
    }

    static func dayKey(for date: Date) -> String {
        DailyStreak.key(for: date)
    }
}
