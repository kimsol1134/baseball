import Foundation
@preconcurrency import UserNotifications

/// 오늘의 이닝 복귀 알림.
///
/// 왜 이 파일이 따로 생겼는가: 예전에는 이 로직이 `DailyInningView` 안에 있었고, 켜는
/// 스위치도 **오늘의 이닝 화면 안에만** 있었다. 2026-08 정식 코호트는 첫날 평균 11.6경기를
/// 자발적으로 소화했지만, 첫 경기 뒤 D1 의미 세션은 5/36이었다. 따라서 플레이를 막는 대신
/// 사람이 지나가는 길목에서 지금 남긴 목표를 다음날 정확한 화면으로 이어 준다.
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
    static let destinationUserInfoKey = "destination"
    static let reasonUserInfoKey = "reason"
    static let receiptUserInfoKey = "plan_receipt"
    static let experimentUserInfoKey = "experiment_id"
    static let variantUserInfoKey = "variant"
    static let savedDayUserInfoKey = "saved_day_key"
    static let rulesVersionUserInfoKey = "development_rules_version"
    static let planKey = "baseball.daily.reminder.plan"
    static let welcomeHandledKey = "baseball.daily.reminder.welcome-handled"

    /// 알림을 누른 뒤 도착할 실제 화면. 알림 문구와 목적지가 다르면 한 번의 복귀도
    /// 배신으로 느껴지므로 둘을 같은 값에서 만든다.
    enum Destination: String, Codable, Equatable {
        case dailyInning = "daily_inning"
        case highSchool = "high_school"
        case pro

        var deepLink: String {
            switch self {
            case .dailyInning: DailyReminder.deepLink
            case .highSchool: "com.solkim.baseball.ios://high-school"
            case .pro: "com.solkim.baseball.ios://pro"
            }
        }

        static func resolve(_ url: URL) -> Destination? {
            guard url.scheme == "com.solkim.baseball.ios" else { return nil }
            return switch url.host {
            case "daily-inning": .dailyInning
            case "high-school": .highSchool
            case "pro": .pro
            default: nil
            }
        }

        /// 알림과 앱 안의 복귀 카드가 같은 화면을 약속하도록 목적지에서 버튼 문구도 만든다.
        var continueTitle: String {
            switch self {
            case .dailyInning: "오늘의 이닝 열기"
            case .highSchool: "이 선수 이어서 키우기"
            case .pro: "프로 시즌 이어가기"
            }
        }
    }

    /// 앱 밖에서도 기억할 '이어 할 한 가지'. 사용자가 직접 키우던 진행에서만 만들고,
    /// 분석에는 고유 선수명·목표명이 아니라 낮은 카디널리티 reason만 보낸다.
    struct Plan: Codable, Equatable {
        let title: String
        let body: String
        let destination: Destination
        let reason: String
        /// 세션 종료 적격 시점과 다음 실행을 잇는 익명 영수증. 자유 문구·선수 ID는 넣지 않는다.
        var receiptID: String? = nil
        var savedDayKey: String? = nil
        var experimentVariant: String? = nil
        var developmentRulesVersion: Int? = nil

        init(
            title: String,
            body: String,
            destination: Destination,
            reason: String,
            receiptID: String? = nil,
            savedDayKey: String? = nil,
            experimentVariant: String? = nil,
            developmentRulesVersion: Int? = nil
        ) {
            self.title = title
            self.body = body
            self.destination = destination
            self.reason = reason
            self.receiptID = receiptID
            self.savedDayKey = savedDayKey
            self.experimentVariant = experimentVariant
            self.developmentRulesVersion = developmentRulesVersion
        }

        /// 영수증 시각이 달라도 같은 사용자 약속이면 같은 카드다. 이 비교가 달라지면
        /// 같은 목표를 닫았는데 앱 전환마다 다시 뜬다.
        static func == (lhs: Plan, rhs: Plan) -> Bool {
            lhs.title == rhs.title
                && lhs.body == rhs.body
                && lhs.destination == rhs.destination
                && lhs.reason == rhs.reason
        }

        func carryingReceipt(from previous: Plan?) -> Plan {
            guard let previous, previous == self else { return self }
            return Plan(
                title: title, body: body, destination: destination, reason: reason,
                receiptID: receiptID ?? previous.receiptID,
                savedDayKey: savedDayKey ?? previous.savedDayKey,
                experimentVariant: experimentVariant ?? previous.experimentVariant,
                developmentRulesVersion: developmentRulesVersion ?? previous.developmentRulesVersion
            )
        }

        /// 복귀 시점의 현재 문구가 iCloud 진행으로 달라져도, 떠날 때 고정한 실험군과
        /// 영수증은 그대로 이어야 한다. 카드 문구는 현재 상태를 쓰고 분모는 이전 적격
        /// 시점을 써야 생존자 편향 없이 한 번의 이탈과 복귀를 연결할 수 있다.
        func carryingExperiment(from previous: Plan?) -> Plan {
            guard let previous else { return self }
            return Plan(
                title: title, body: body, destination: destination, reason: reason,
                receiptID: receiptID ?? previous.receiptID,
                savedDayKey: savedDayKey ?? previous.savedDayKey,
                experimentVariant: experimentVariant ?? previous.experimentVariant,
                developmentRulesVersion: developmentRulesVersion ?? previous.developmentRulesVersion
            )
        }
    }

    enum ReturnExperimentVariant: String, Codable, Equatable, CaseIterable {
        case holdout
        case guided
    }

    static let returnExperimentID = "next_action_v1"

    /// 같은 목표를 닫거나 눌렀는데 앱 전환 때마다 다시 띄우면 복귀 훅이 방해물이 된다.
    /// 목표와 서울 날짜를 함께 저장해 같은 날 같은 제안만 조용히 숨긴다.
    struct WelcomeHandled: Codable, Equatable {
        let plan: Plan
        let dayKey: String
    }

    struct NotificationCopy: Equatable {
        let title: String
        let body: String
        let link: String
        let destination: String
        let reason: String
    }

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

    /// 현재 진행에서 새 계획을 만들었을 때만 사용한다. nil은 오래된 선수 문구를 지운다.
    @MainActor static func refresh(plan: Plan?) {
        savePlan(plan)
        Task { await reschedule() }
    }

    static func savePlan(_ plan: Plan?, defaults: UserDefaults = .standard) {
        let merged = plan?.carryingReceipt(from: storedPlan(defaults: defaults))
        guard let merged, let data = try? JSONEncoder().encode(merged) else {
            defaults.removeObject(forKey: planKey)
            return
        }
        defaults.set(data, forKey: planKey)
    }

    static func storedPlan(defaults: UserDefaults = .standard) -> Plan? {
        guard let data = defaults.data(forKey: planKey) else { return nil }
        return try? JSONDecoder().decode(Plan.self, from: data)
    }

    static func experimentVariant(stableID: String) -> ReturnExperimentVariant {
        stableHash("\(returnExperimentID)|\(stableID)").isMultiple(of: 2)
            ? .holdout : .guided
    }

    /// 사용자가 떠난 순간에만 새 영수증을 만든다. 앱 시작 중 refresh가 매번 새 ID를
    /// 만들면 한 번의 이탈과 한 번의 복귀를 이어 볼 수 없다.
    @MainActor static func preparedForNextReturn(
        _ plan: Plan,
        stableID: String = GameAnalytics.stableID(),
        rulesVersion: Int,
        now: Date = Date()
    ) -> Plan {
        let dayKey = DailyStreak.key(for: now)
        // 첫날 여러 회차를 끝내는 사용자는 같은 날짜·목적지·이유에서도 보존된 v3와
        // 새 v4 사이를 오갈 수 있다. 버전을 영수증에 넣지 않으면 먼저 기록된 eligibility와
        // 다음날 cold start/game_finished가 서로 다른 규칙 코호트로 갈라진다.
        let scope = "\(returnExperimentID)|\(stableID)|\(dayKey)|\(plan.destination.rawValue)|\(plan.reason)|v\(rulesVersion)"
        return Plan(
            title: plan.title,
            body: plan.body,
            destination: plan.destination,
            reason: plan.reason,
            receiptID: String(stableHash(scope), radix: 16),
            savedDayKey: dayKey,
            experimentVariant: experimentVariant(stableID: stableID).rawValue,
            developmentRulesVersion: rulesVersion
        )
    }

    static func analyticsProperties(_ plan: Plan, now: Date = Date()) -> [String: Any] {
        [
            "destination": plan.destination.rawValue,
            "reason": plan.reason,
            "plan_receipt": plan.receiptID ?? "legacy",
            "experiment_id": returnExperimentID,
            "variant": plan.experimentVariant ?? "legacy",
            "saved_day_key": plan.savedDayKey ?? "legacy",
            "return_day_key": DailyStreak.key(for: now),
            "day_gap": dayGap(from: plan.savedDayKey, to: now) ?? -1,
            "development_rules_version": plan.developmentRulesVersion ?? 0,
        ]
    }

    static func coldStartProperties(_ plan: Plan?, now: Date = Date()) -> [String: Any]? {
        guard let plan, let gap = dayGap(from: plan.savedDayKey, to: now), gap >= 1 else {
            return nil
        }
        return analyticsProperties(plan, now: now)
    }

    static func markWelcomeHandled(
        _ plan: Plan,
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) {
        let handled = WelcomeHandled(plan: plan, dayKey: DailyStreak.key(for: now))
        guard let data = try? JSONEncoder().encode(handled) else { return }
        defaults.set(data, forKey: welcomeHandledKey)
    }

    static func storedWelcomeHandled(defaults: UserDefaults = .standard) -> WelcomeHandled? {
        guard let data = defaults.data(forKey: welcomeHandledKey) else { return nil }
        return try? JSONDecoder().decode(WelcomeHandled.self, from: data)
    }

    /// 첫 설치에는 복귀 카드가 없어야 하고, 이전 세션이 있었을 때만 현재 진행을 보여 준다.
    ///
    /// 두 계획이 다를 때도 `current`를 반환한다. 다른 기기에서 한 단계 전진했거나 저장을
    /// 복원했다면 오래된 문구보다 지금 실제로 이어지는 장면을 말하는 편이 정직하다.
    static func welcomePlan(
        previous: Plan?,
        current: Plan?,
        handled: WelcomeHandled? = nil,
        now: Date = Date()
    ) -> Plan? {
        guard let previous, let current else { return nil }
        let candidate = current.carryingExperiment(from: previous)
        // 대조군은 같은 진행을 저장하지만 카드와 개인화 알림은 받지 않는다. 이미 돌아온
        // 사람만 보는 카드 탭률을 D1 원인으로 오인하지 않도록 적격 시점부터 코호트를 고정한다.
        guard candidate.experimentVariant == ReturnExperimentVariant.guided.rawValue else { return nil }
        if handled?.plan == candidate, handled?.dayKey == DailyStreak.key(for: now) {
            return nil
        }
        return candidate
    }

    /// 계획이 없으면 기존 오늘의 이닝 알림으로 돌아간다. 구버전 알림도 같은 fallback을 쓴다.
    static func notificationCopy(plan: Plan?, streak: Int) -> NotificationCopy {
        if let plan,
           plan.experimentVariant == ReturnExperimentVariant.guided.rawValue {
            return NotificationCopy(
                title: plan.title,
                body: plan.body,
                link: plan.destination.deepLink,
                destination: plan.destination.rawValue,
                reason: plan.reason
            )
        }
        return NotificationCopy(
            title: "오늘의 이닝이 열려 있습니다",
            body: streak > 0
                ? "\(streak)일 연속 — 자정 전에 한 이닝이면 이어집니다."
                : "전국이 같은 타순을 상대합니다 — 자정 전에 한 이닝.",
            link: deepLink,
            destination: Destination.dailyInning.rawValue,
            reason: "daily_inning"
        )
    }

    static func playedKeysToSkip(plan: Plan?, playedDailyKeys: Set<String>) -> Set<String> {
        let guided = plan?.experimentVariant == ReturnExperimentVariant.guided.rawValue
        return !guided || plan?.destination == .dailyInning ? playedDailyKeys : []
    }

    private static func stableHash(_ value: String) -> UInt64 {
        value.utf8.reduce(UInt64(0xCBF2_9CE4_8422_2325)) { partial, byte in
            (partial ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
        }
    }

    private static func dayGap(from key: String?, to now: Date) -> Int? {
        guard let key else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        guard let saved = formatter.date(from: key) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: saved), to: calendar.startOfDay(for: now)
        ).day
    }

    /// 예전 알림에는 destination/reason이 없다. 링크에서 목적지를 복원하고 이유는
    /// legacy로 고정해 새 실험 코호트와 섞이지 않게 한다.
    static func openedProperties(userInfo: [AnyHashable: Any]) -> [String: Any] {
        let rawLink = userInfo[linkUserInfoKey] as? String
        let inferred = rawLink.flatMap(URL.init(string:)).flatMap(Destination.resolve)
        let destination = (userInfo[destinationUserInfoKey] as? String)
            ?? inferred?.rawValue ?? "unknown"
        return [
            "destination": destination,
            "reason": (userInfo[reasonUserInfoKey] as? String) ?? "legacy",
            "plan_receipt": (userInfo[receiptUserInfoKey] as? String) ?? "legacy",
            "experiment_id": (userInfo[experimentUserInfoKey] as? String) ?? "legacy",
            "variant": (userInfo[variantUserInfoKey] as? String) ?? "legacy",
            "saved_day_key": (userInfo[savedDayUserInfoKey] as? String) ?? "legacy",
            "development_rules_version": (userInfo[rulesVersionUserInfoKey] as? Int) ?? 0,
        ]
    }

    @MainActor private static func reschedule() async {
        let center = UNUserNotificationCenter.current()
        clearPending()
        guard UserDefaults.standard.bool(forKey: enabledKey) else { return }
        let now = Date()
        let plan = storedPlan()
        let playedDailyKeys = Set(
            (0..<horizonDays).compactMap { offset -> String? in
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
                guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
                let key = DailyStreak.key(for: day)
                return UserDefaults.standard.bool(forKey: DailyStreak.playedKeyPrefix + key) ? key : nil
            }
        )
        // 커리어를 이어 하라는 알림은 오늘의 이닝을 이미 던졌다고 사라지면 안 된다.
        let skippedKeys = playedKeysToSkip(plan: plan, playedDailyKeys: playedDailyKeys)
        let copy = notificationCopy(plan: plan, streak: DailyStreak.current())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        for entry in schedule(from: now, playedKeys: skippedKeys) {
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = .default
            content.userInfo = [
                linkUserInfoKey: copy.link,
                destinationUserInfoKey: copy.destination,
                reasonUserInfoKey: copy.reason,
                receiptUserInfoKey: plan?.receiptID ?? "legacy",
                experimentUserInfoKey: returnExperimentID,
                variantUserInfoKey: plan?.experimentVariant ?? "legacy",
                savedDayUserInfoKey: plan?.savedDayKey ?? "legacy",
                rulesVersionUserInfoKey: plan?.developmentRulesVersion ?? 0,
            ]
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
            GameAnalytics.log(.reminderOpened, DailyReminder.openedProperties(userInfo: info))
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
