import Foundation
import UserNotifications

/// 오늘의 이닝 복귀 알림.
///
/// 왜 이 파일이 따로 생겼는가: 예전에는 이 로직이 `DailyInningView` 안에 있었고, 켜는
/// 스위치도 **오늘의 이닝 화면 안에만** 있었다. 2026-08 데이터에서 그 화면을 연 사람은
/// DAU의 7%였다. 즉 리텐션 장치가 자신이 살려야 할 화면 안에 갇혀 있었고, 실제로 D2
/// 리텐션은 0%였다. 스위치는 사람이 지나가는 길목(첫 경기 직후·3년 돌아보기·설정)에 있어야 한다.
///
/// 설계 규칙 셋:
/// - **반복 트리거를 쓰지 않는다.** `repeats: true`는 떠난 사람에게 영원히 울린다.
///   앞으로 며칠치만 개별 예약하고 앱을 열 때마다 다시 채운다 — 안 오면 저절로 끝난다.
/// - **오늘 이미 던졌으면 오늘 알림은 없다.** 이미 한 일을 하라고 부르면 신뢰가 깎인다.
/// - **딥 링크를 싣는다.** 알림을 눌러 홈 화면이 뜨면 그 알림은 절반만 일한 것이다.
enum DailyReminder {
    static let enabledKey = "baseball.daily.reminder"
    /// 이미 한 번 물어봤는가. 거절한 사람에게 다시 묻지 않는다.
    static let promptedKey = "baseball.daily.reminder.prompted"
    static let requestPrefix = "baseball.daily.reminder."
    /// 앞으로 며칠치를 예약해 둘 것인가. 안 열면 이 일수 뒤에 저절로 조용해진다.
    static let horizonDays = 3
    static let hour = 19
    static let minute = 30
    /// `AppShell.isDailyInningDeepLink`가 받는 그 링크.
    static let deepLink = "com.solkim.baseball.ios://daily-inning"
    static let linkUserInfoKey = "link"

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// 아직 켜지도, 물어보지도 않았는가. 넛지 카드를 띄울지의 유일한 조건이다.
    static func shouldOfferOptIn(defaults: UserDefaults = .standard) -> Bool {
        // UI 테스트에서 권한 시트가 뜨면 다음 탭을 삼켜 스모크가 간헐 실패한다.
        guard !ProcessInfo.processInfo.arguments.contains("-uiTestResetCareer") else { return false }
        return !defaults.bool(forKey: enabledKey) && !defaults.bool(forKey: promptedKey)
    }

    /// 앞으로 예약할 알림들의 (식별자, 날짜) 목록. 순수 함수라 테스트할 수 있다.
    ///
    /// - Parameter playedKeys: 이미 던진 날짜 키들. 오늘이 여기 있으면 오늘은 건너뛴다.
    static func schedule(
        from now: Date,
        horizon: Int = horizonDays,
        playedKeys: Set<String> = []
    ) -> [(id: String, date: Date)] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        var result: [(String, Date)] = []
        for offset in 0..<max(0, horizon) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let fire = calendar.date(
                    bySettingHour: hour, minute: minute, second: 0, of: day) else { continue }
            // 이미 지난 시각은 예약하지 않는다 — iOS가 즉시 발사한다.
            guard fire > now else { continue }
            let key = DailyStreak.key(for: day)
            // 오늘 몫을 이미 던진 날은 부르지 않는다.
            guard !playedKeys.contains(key) else { continue }
            result.append((requestPrefix + key, fire))
        }
        return result
    }

    /// 켠다. 권한이 없으면 물어보고, 거절당하면 켜지지 않는다.
    ///
    /// - Parameter source: 어느 입구에서 켰는가. 어떤 자리가 실제로 작동하는지 본다.
    @MainActor static func enable(source: String, completion: @escaping @MainActor (Bool) -> Void = { _ in }) {
        Task { @MainActor in
            UserDefaults.standard.set(true, forKey: promptedKey)
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            UserDefaults.standard.set(granted, forKey: enabledKey)
            GameAnalytics.log(.reminderChanged, ["enabled": granted, "source": source])
            guard granted else { completion(false); return }
            await reschedule()
            completion(true)
        }
    }

    @MainActor static func disable(source: String = "settings") {
        UserDefaults.standard.set(false, forKey: enabledKey)
        GameAnalytics.log(.reminderChanged, ["enabled": false, "source": source])
        clearPending()
    }

    /// 물어보긴 했으나 켜지 않기로 한 경우. 다시 묻지 않는다.
    @MainActor static func declineOptIn() {
        UserDefaults.standard.set(true, forKey: promptedKey)
        GameAnalytics.log(.reminderChanged, ["enabled": false, "source": "declined"])
    }

    /// 앱을 열 때마다 앞으로 며칠치를 다시 채운다. 꺼져 있으면 전부 지운다.
    @MainActor static func refresh() {
        Task { await reschedule() }
    }

    @MainActor private static func reschedule() async {
        let center = UNUserNotificationCenter.current()
        clearPending()
        guard UserDefaults.standard.bool(forKey: enabledKey) else { return }
        let now = Date()
        let played = Set(
            (0..<horizonDays).compactMap { offset -> String? in
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
                guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
                let key = DailyStreak.key(for: day)
                return UserDefaults.standard.bool(forKey: DailyStreak.playedKeyPrefix + key) ? key : nil
            }
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        for entry in schedule(from: now, playedKeys: played) {
            let content = UNMutableNotificationContent()
            content.title = "오늘의 이닝이 열려 있습니다"
            let streak = DailyStreak.current()
            content.body = streak > 0
                ? "\(streak)일 연속 — 자정 전에 한 이닝이면 이어집니다."
                : "전국이 같은 타순을 상대합니다 — 자정 전에 한 이닝."
            content.sound = .default
            content.userInfo = [linkUserInfoKey: deepLink]
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: entry.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(
                UNNotificationRequest(identifier: entry.id, content: content, trigger: trigger))
        }
    }

    @MainActor private static func clearPending() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ours = requests.map(\.identifier).filter { $0.hasPrefix(requestPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ours)
        }
        // 예전 버전이 심어 둔 반복 알림. 지우지 않으면 영원히 울린다.
        center.removePendingNotificationRequests(withIdentifiers: ["baseball.daily.reminder"])
    }
}

/// 알림을 눌렀을 때 오늘의 이닝을 연다.
///
/// `onOpenURL`만 있으면 알림 탭은 홈 화면만 띄운다 — D1 훅의 마지막 한 걸음이 없는 셈이다.
@MainActor
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()
    /// 알림에서 들어왔다는 신호. AppShell이 이 값을 보고 화면을 연다.
    var pendingDeepLink: URL?
    var onDeepLink: ((URL) -> Void)?

    func register() {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let raw = info[DailyReminder.linkUserInfoKey] as? String,
              let url = URL(string: raw) else { return }
        await MainActor.run {
            GameAnalytics.log(.reminderOpened)
            if let handler = self.onDeepLink { handler(url) } else { self.pendingDeepLink = url }
        }
    }

    /// 앱이 떠 있을 때도 배너를 보여 준다 — 안 보여 주면 켜 둔 알림이 조용히 사라진다.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
