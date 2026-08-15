import Foundation
@preconcurrency import UserNotifications
import SimulationCore

/// 현재 커리어의 다음 행동을 이어 주는 복귀 알림.
///
/// 2026-08 정식 코호트는 첫날 평균 11.6경기를 자발적으로 소화했지만, 첫 경기 뒤 D1 의미
/// 세션은 5/36이었다. 따라서 플레이를 막는 대신 사람이 지나가는 길목에서 지금 남긴 목표를
/// 다음날 정확한 화면으로 이어 준다.
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
    /// 제거 전 배포가 예약한 알림과 외부 링크를 해석하기 위한 호환 주소.
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
    static let copySchemaVersion = GameCopySchema.currentVersion

    /// A Codable, versioned storage form for a semantic presentation token. This is intentionally
    /// separate from `SimulationCore.CopyToken`, which remains ephemeral and non-Codable.
    struct SemanticCopyReference: Codable, Equatable, Sendable {
        enum Argument: Codable, Equatable, Sendable {
            case userText(String)
            case contentID(String)
            case integer(Int)
            case decimal(Double)

            private enum CodingKeys: String, CodingKey {
                case kind
                case stringValue
                case integerValue
                case decimalValue
            }

            private enum Kind: String, Codable {
                case userText
                case contentID
                case integer
                case decimal
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let kind = try container.decode(Kind.self, forKey: .kind)
                switch kind {
                case .userText:
                    self = .userText(try container.decode(String.self, forKey: .stringValue))
                case .contentID:
                    self = .contentID(try container.decode(String.self, forKey: .stringValue))
                case .integer:
                    self = .integer(try container.decode(Int.self, forKey: .integerValue))
                case .decimal:
                    self = .decimal(try container.decode(Double.self, forKey: .decimalValue))
                }
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                switch self {
                case .userText(let value):
                    try container.encode(Kind.userText, forKey: .kind)
                    try container.encode(value, forKey: .stringValue)
                case .contentID(let value):
                    try container.encode(Kind.contentID, forKey: .kind)
                    try container.encode(value, forKey: .stringValue)
                case .integer(let value):
                    try container.encode(Kind.integer, forKey: .kind)
                    try container.encode(value, forKey: .integerValue)
                case .decimal(let value):
                    try container.encode(Kind.decimal, forKey: .kind)
                    try container.encode(value, forKey: .decimalValue)
                }
            }

            var coreArgument: SimulationCore.CopyArgument {
                switch self {
                case .userText(let value): .userText(value)
                case .contentID(let value): .contentID(value)
                case .integer(let value): .integer(value)
                case .decimal(let value): .decimal(value)
                }
            }

            init(coreArgument: SimulationCore.CopyArgument) {
                switch coreArgument {
                case .userText(let value): self = .userText(value)
                case .contentID(let value): self = .contentID(value)
                case .integer(let value): self = .integer(value)
                case .decimal(let value): self = .decimal(value)
                }
            }
        }

        let schemaVersion: Int
        let key: String
        let arguments: [Argument]

        init(
            schemaVersion: Int = DailyReminder.copySchemaVersion,
            key: String,
            arguments: [Argument] = []
        ) {
            self.schemaVersion = schemaVersion
            self.key = key
            self.arguments = arguments
        }

        init(token: SimulationCore.CopyToken, schemaVersion: Int = DailyReminder.copySchemaVersion) {
            self.init(
                schemaVersion: schemaVersion,
                key: token.key,
                arguments: token.arguments.map(Argument.init(coreArgument:))
            )
        }

        var coreToken: SimulationCore.CopyToken {
            SimulationCore.CopyToken(
                key: key,
                arguments: arguments.map(\.coreArgument)
            )
        }
    }

    /// Title and body references are optional so a legacy plan can continue to decode. When the
    /// app runs in English, missing or stale references resolve to reviewed generic English copy
    /// instead of exposing the legacy Korean payload.
    struct NotificationCopyReferences: Codable, Equatable, Sendable {
        let title: SemanticCopyReference?
        let body: SemanticCopyReference?

        init(
            title: SemanticCopyReference? = nil,
            body: SemanticCopyReference? = nil
        ) {
            self.title = title
            self.body = body
        }
    }

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
            case .dailyInning: "게임으로 돌아가기"
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
        /// The experiment assignment is frozen with the plan. A missing value is a v1 plan
        /// written before experiment IDs were persisted.
        var experimentID: String? = nil
        /// 세션 종료 적격 시점과 다음 실행을 잇는 익명 영수증. 자유 문구·선수 ID는 넣지 않는다.
        var receiptID: String? = nil
        var savedDayKey: String? = nil
        var experimentVariant: String? = nil
        var developmentRulesVersion: Int? = nil
        /// Optional semantic references are added without replacing legacy title/body fields.
        var copyReferences: NotificationCopyReferences? = nil
        /// The language used when pending requests were last scheduled. This is metadata, not
        /// a language-specific save namespace.
        var scheduledLanguage: AppLanguage? = nil
        var scheduledCopySchemaVersion: Int? = nil

        /// Convenience for a title-only migration step. Full notification migration uses
        /// `copyReferences` so title and body can be resolved independently.
        var copyReference: SemanticCopyReference? {
            get { copyReferences?.title }
            set {
                copyReferences = newValue.map {
                    NotificationCopyReferences(title: $0, body: copyReferences?.body)
                }
            }
        }

        init(
            title: String,
            body: String,
            destination: Destination,
            reason: String,
            experimentID: String? = nil,
            receiptID: String? = nil,
            savedDayKey: String? = nil,
            experimentVariant: String? = nil,
            developmentRulesVersion: Int? = nil,
            copyReferences: NotificationCopyReferences? = nil,
            copyReference: SemanticCopyReference? = nil,
            scheduledLanguage: AppLanguage? = nil,
            scheduledCopySchemaVersion: Int? = nil
        ) {
            self.title = title
            self.body = body
            self.destination = destination
            self.reason = reason
            self.experimentID = experimentID
            self.receiptID = receiptID
            self.savedDayKey = savedDayKey
            self.experimentVariant = experimentVariant
            self.developmentRulesVersion = developmentRulesVersion
            self.copyReferences = copyReferences ?? copyReference.map {
                NotificationCopyReferences(title: $0)
            }
            self.scheduledLanguage = scheduledLanguage
            self.scheduledCopySchemaVersion = scheduledCopySchemaVersion
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
                experimentID: experimentID ?? previous.experimentID,
                receiptID: receiptID ?? previous.receiptID,
                savedDayKey: savedDayKey ?? previous.savedDayKey,
                experimentVariant: experimentVariant ?? previous.experimentVariant,
                developmentRulesVersion: developmentRulesVersion ?? previous.developmentRulesVersion,
                copyReferences: copyReferences ?? previous.copyReferences,
                scheduledLanguage: scheduledLanguage ?? previous.scheduledLanguage,
                scheduledCopySchemaVersion: scheduledCopySchemaVersion ?? previous.scheduledCopySchemaVersion
            )
        }

        /// 복귀 시점의 현재 문구가 iCloud 진행으로 달라져도, 떠날 때 고정한 실험군과
        /// 영수증은 그대로 이어야 한다. 카드 문구는 현재 상태를 쓰고 분모는 이전 적격
        /// 시점을 써야 생존자 편향 없이 한 번의 이탈과 복귀를 연결할 수 있다.
        func carryingExperiment(from previous: Plan?) -> Plan {
            guard let previous else { return self }
            return Plan(
                title: title, body: body, destination: destination, reason: reason,
                experimentID: experimentID ?? previous.experimentID,
                receiptID: receiptID ?? previous.receiptID,
                savedDayKey: savedDayKey ?? previous.savedDayKey,
                experimentVariant: experimentVariant ?? previous.experimentVariant,
                developmentRulesVersion: developmentRulesVersion ?? previous.developmentRulesVersion,
                copyReferences: copyReferences ?? previous.copyReferences,
                scheduledLanguage: scheduledLanguage ?? previous.scheduledLanguage,
                scheduledCopySchemaVersion: scheduledCopySchemaVersion ?? previous.scheduledCopySchemaVersion
            )
        }
    }

    enum ReturnExperimentVariant: String, Codable, Equatable, CaseIterable {
        case holdout
        case guided
    }

    /// New eligible plans use v2. Plans from before this field existed remain v1.
    static let legacyReturnExperimentID = "next_action_v1"
    static let returnExperimentID = "next_action_v2"

    enum ReturnPlanEligibility {
        static func isEligible(completedGameCount: Int) -> Bool {
            completedGameCount > 0
        }
    }

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

    /// A pending request is stale when it was scheduled for another app language or copy
    /// schema. Missing metadata is treated as stale so a legacy plan is refreshed once and then
    /// receives the new metadata without changing its destination, receipt, or experiment.
    static func needsPresentationReschedule(
        plan: Plan?,
        language: AppLanguage,
        copySchemaVersion: Int = GameCopySchema.currentVersion
    ) -> Bool {
        guard let plan else { return false }
        return plan.scheduledLanguage != language
            || plan.scheduledCopySchemaVersion != copySchemaVersion
    }

    static func planScheduledForPresentation(
        _ plan: Plan,
        language: AppLanguage,
        copySchemaVersion: Int = GameCopySchema.currentVersion
    ) -> Plan {
        Plan(
            title: plan.title,
            body: plan.body,
            destination: plan.destination,
            reason: plan.reason,
            experimentID: plan.experimentID,
            receiptID: plan.receiptID,
            savedDayKey: plan.savedDayKey,
            experimentVariant: plan.experimentVariant,
            developmentRulesVersion: plan.developmentRulesVersion,
            copyReferences: plan.copyReferences,
            scheduledLanguage: language,
            scheduledCopySchemaVersion: copySchemaVersion
        )
    }

    static func experimentID(for plan: Plan) -> String {
        plan.experimentID ?? legacyReturnExperimentID
    }

    static func experimentVariant(stableID: String) -> ReturnExperimentVariant {
        experimentVariant(experimentID: returnExperimentID, stableID: stableID)
    }

    static func experimentVariant(experimentID: String, stableID: String) -> ReturnExperimentVariant {
        stableHash("\(experimentID)|\(stableID)").isMultiple(of: 2)
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
            experimentID: returnExperimentID,
            receiptID: String(stableHash(scope), radix: 16),
            savedDayKey: dayKey,
            experimentVariant: experimentVariant(
                experimentID: returnExperimentID, stableID: stableID
            ).rawValue,
            developmentRulesVersion: rulesVersion,
            copyReferences: plan.copyReferences,
            scheduledLanguage: nil,
            scheduledCopySchemaVersion: nil
        )
    }

    static func analyticsProperties(_ plan: Plan, now: Date = Date()) -> [String: Any] {
        [
            "destination": plan.destination.rawValue,
            "reason": plan.reason,
            "plan_receipt": plan.receiptID ?? "legacy",
            "experiment_id": experimentID(for: plan),
            "variant": plan.experimentVariant ?? "legacy",
            "saved_day_key": plan.savedDayKey ?? "legacy",
            "return_day_key": DailyStreak.key(for: now),
            "day_gap": dayGap(from: plan.savedDayKey, to: now) ?? -1,
            "development_rules_version": plan.developmentRulesVersion ?? 0,
        ]
    }

    static func sessionEndReturnProperties(
        plan: Plan?,
        completedGameCount: Int
    ) -> [String: Any] {
        guard ReturnPlanEligibility.isEligible(completedGameCount: completedGameCount),
              let plan else {
            return [
                "return_eligible": false,
                "return_destination": "none",
                "return_reason": "ineligible",
                "plan_receipt": "none",
                "experiment_id": "none",
                "variant": "ineligible",
                "development_rules_version": 0,
            ]
        }
        return [
            "return_eligible": true,
            "return_destination": plan.destination.rawValue,
            "return_reason": plan.reason,
            "plan_receipt": plan.receiptID ?? "legacy",
            "experiment_id": experimentID(for: plan),
            "variant": plan.experimentVariant ?? "legacy",
            "development_rules_version": plan.developmentRulesVersion ?? 0,
        ]
    }

    static func nextDayOpenProperties(
        _ plan: Plan?,
        launchType: String,
        now: Date = Date()
    ) -> [String: Any]? {
        guard launchType == "cold" || launchType == "warm" else { return nil }
        guard let plan,
              plan.receiptID?.isEmpty == false,
              (plan.experimentVariant == ReturnExperimentVariant.holdout.rawValue
                  || plan.experimentVariant == ReturnExperimentVariant.guided.rawValue),
              let gap = dayGap(from: plan.savedDayKey, to: now), gap >= 1 else {
            return nil
        }
        var properties = analyticsProperties(plan, now: now)
        properties["launch_type"] = launchType
        return properties
    }

    /// Compatibility wrapper for the old cold-start event.
    static func coldStartProperties(_ plan: Plan?, now: Date = Date()) -> [String: Any]? {
        nextDayOpenProperties(plan, launchType: "cold", now: now)
    }

    /// The idempotency key is deliberately not sent as an additional analytics property.
    /// `GameAnalytics.logOnce` hashes this scope locally before storing it.
    static func nextDayOpenScope(properties: [String: Any]) -> String? {
        guard let experimentID = properties["experiment_id"] as? String,
              let receipt = properties["plan_receipt"] as? String,
              let returnDay = properties["return_day_key"] as? String else {
            return nil
        }
        return "\(experimentID)|\(receipt)|\(returnDay)"
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

    /// UI 테스트는 이전 실행이 남긴 복귀 목적지와 닫기 영수증까지 없는 상태에서 시작한다.
    /// 둘 중 하나라도 남으면 커리어 파일을 지운 뒤에도 복귀 카드가 첫 조작을 가릴 수 있다.
    static func resetForUITesting(defaults: UserDefaults = .standard) {
        savePlan(nil, defaults: defaults)
        defaults.removeObject(forKey: welcomeHandledKey)
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

    /// 실제 이어 갈 커리어가 있는 guided 사용자에게만 알림을 만든다. 제거된 목적지나
    /// 계획 없는 상태는 알림을 만들지 않아 과거 fallback이 되살아나지 않게 한다.
    static func notificationCopy(
        plan: Plan?,
        resolver: GameCopyResolver? = nil,
        copySchemaVersion: Int = GameCopySchema.currentVersion
    ) -> NotificationCopy? {
        guard let plan,
              plan.destination != .dailyInning,
              plan.experimentVariant == ReturnExperimentVariant.guided.rawValue else { return nil }

        let title = resolvedNotificationValue(
            reference: plan.copyReferences?.title,
            genericKey: .notificationReturnTitle,
            legacyValue: plan.title,
            resolver: resolver,
            copySchemaVersion: copySchemaVersion
        )
        let body = resolvedNotificationValue(
            reference: plan.copyReferences?.body,
            genericKey: .notificationReturnBody,
            legacyValue: plan.body,
            resolver: resolver,
            copySchemaVersion: copySchemaVersion
        )
        return NotificationCopy(
            title: title,
            body: body,
            link: plan.destination.deepLink,
            destination: plan.destination.rawValue,
            reason: plan.reason
        )
    }

    private static func resolvedNotificationValue(
        reference: SemanticCopyReference?,
        genericKey: GameCopyKey,
        legacyValue: String,
        resolver: GameCopyResolver?,
        copySchemaVersion: Int
    ) -> String {
        guard let resolver else { return legacyValue }

        if let reference, reference.schemaVersion == copySchemaVersion {
            let resolved = resolver.resolve(reference.coreToken)
            if resolved != GameCopyResolver.unavailableText {
                return resolved
            }
        }

        // Korean remains the development language, so old personalized payloads are valid there.
        // Other languages must never fall back to a Korean sentence stored by an older build.
        guard resolver.language != .korean else { return legacyValue }
        return resolver.resolve(genericKey)
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

    /// UserNotifications의 Objective-C payload는 `Any` 사전이라 actor 사이로 그대로
    /// 넘길 수 없다. delegate callback 안에서 이 값 타입으로 먼저 정규화한 뒤 메인
    /// actor에는 Sendable 값만 전달한다.
    struct OpenedContext: Sendable {
        let deepLink: URL?
        let destination: String
        let reason: String
        let receipt: String
        let experimentID: String
        let variant: String
        let savedDayKey: String
        let developmentRulesVersion: Int

        var analyticsProperties: [String: Any] {
            [
                "destination": destination,
                "reason": reason,
                "plan_receipt": receipt,
                "experiment_id": experimentID,
                "variant": variant,
                "saved_day_key": savedDayKey,
                "development_rules_version": developmentRulesVersion,
            ]
        }
    }

    /// 예전 알림에는 destination/reason이 없다. 링크에서 목적지를 복원하고 이유는
    /// legacy로 고정해 새 실험 코호트와 섞이지 않게 한다.
    static func openedContext(userInfo: [AnyHashable: Any]) -> OpenedContext {
        let rawLink = userInfo[linkUserInfoKey] as? String
        let deepLink = rawLink.flatMap(URL.init(string:))
        let inferred = deepLink.flatMap(Destination.resolve)
        let destination = (userInfo[destinationUserInfoKey] as? String)
            ?? inferred?.rawValue ?? "unknown"
        return OpenedContext(
            deepLink: deepLink,
            destination: destination,
            reason: (userInfo[reasonUserInfoKey] as? String) ?? "legacy",
            receipt: (userInfo[receiptUserInfoKey] as? String) ?? "legacy",
            experimentID: (userInfo[experimentUserInfoKey] as? String) ?? "legacy",
            variant: (userInfo[variantUserInfoKey] as? String) ?? "legacy",
            savedDayKey: (userInfo[savedDayUserInfoKey] as? String) ?? "legacy",
            developmentRulesVersion: (userInfo[rulesVersionUserInfoKey] as? Int) ?? 0
        )
    }

    static func openedProperties(userInfo: [AnyHashable: Any]) -> [String: Any] {
        openedContext(userInfo: userInfo).analyticsProperties
    }

    @MainActor private static func reschedule(
        language: AppLanguage = AppLanguage.current(),
        copySchemaVersion: Int = GameCopySchema.currentVersion
    ) async {
        let center = UNUserNotificationCenter.current()
        clearPending()
        guard UserDefaults.standard.bool(forKey: enabledKey) else { return }
        let now = Date()
        let plan = storedPlan()
        let resolver = plan.map { _ in
            GameCopyResolver(language: language, policy: .automatic)
        }
        guard let copy = notificationCopy(
            plan: plan,
            resolver: resolver,
            copySchemaVersion: copySchemaVersion
        ) else { return }
        if let plan, needsPresentationReschedule(
            plan: plan, language: language, copySchemaVersion: copySchemaVersion
        ) {
            savePlan(
                planScheduledForPresentation(
                    plan, language: language, copySchemaVersion: copySchemaVersion
                )
            )
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        for entry in schedule(from: now) {
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = .default
            content.userInfo = [
                linkUserInfoKey: copy.link,
                destinationUserInfoKey: copy.destination,
                reasonUserInfoKey: copy.reason,
                receiptUserInfoKey: plan?.receiptID ?? "legacy",
                experimentUserInfoKey: plan.map { Self.experimentID(for: $0) } ?? "legacy",
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

/// UserNotifications가 건네는 Objective-C completion block에는 Sendable 표기가 없다.
/// 콜백 자체만 좁게 감싸고 실제 실행은 반드시 MainActor에서 한 번만 수행한다.
private final class NotificationDelegateCompletion: @unchecked Sendable {
    private let callback: () -> Void

    init(_ callback: @escaping () -> Void) {
        self.callback = callback
    }

    @MainActor
    func call() {
        callback()
    }
}

/// 알림을 눌렀을 때 약속한 커리어 화면을 연다.
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
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // AnyHashable/Any payload는 이 동기 callback 안에서 끝내고 Sendable 값만 hop한다.
        let context = DailyReminder.openedContext(
            userInfo: response.notification.request.content.userInfo
        )
        let completion = NotificationDelegateCompletion(completionHandler)

        Task { @MainActor [weak self] in
            // UIKit의 snapshot/state-restoration 정리도 메인 actor에서 끝나야 한다.
            defer { completion.call() }
            guard let url = context.deepLink else { return }
            GameAnalytics.log(.reminderOpened, context.analyticsProperties)
            if let handler = self?.onDeepLink {
                handler(url)
            } else {
                self?.pendingDeepLink = url
            }
        }
    }

    /// 앱이 떠 있을 때도 배너를 보여 준다 — 안 보여 주면 켜 둔 알림이 조용히 사라진다.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
