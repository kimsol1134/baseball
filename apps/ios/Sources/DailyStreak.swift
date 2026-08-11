import Foundation

/// 제거된 일일 모드가 남긴 로컬 키. 새 플레이는 쓰지 않으며 업데이트·전체 삭제 호환에만 쓴다.
enum LegacyDailyInningData {
    static let playedKeyPrefix = "baseball.daily.played."
    static let bestKeyPrefix = "baseball.daily.best."
    static let attemptsKeyPrefix = "baseball.daily.attempts."
    static let bestEverKey = "baseball.daily.bestEver"
    static let allKeyPrefixes = [playedKeyPrefix, bestKeyPrefix, attemptsKeyPrefix]

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: bestEverKey)
        for key in defaults.dictionaryRepresentation().keys
        where allKeyPrefixes.contains(where: key.hasPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}

/// 모드를 가리지 않는 연속 플레이 기록. 옛 일일 키도 읽어 기존 연속 기록은 보존한다.
enum DailyStreak {
    static let playedKeyPrefix = LegacyDailyInningData.playedKeyPrefix

    /// 모드를 가리지 않는 "오늘 야구를 했다" 플래그.
    ///
    /// 현재 고교·프로 경기가 쓰는 "오늘 야구를 했다" 플래그.
    static let playKeyPrefix = "baseball.play.day."

    /// 지울 때 함께 지워야 하는 진행 흔적들.
    static let allPlayKeyPrefixes = [playedKeyPrefix, playKeyPrefix]

    /// 오늘 야구를 했다고 표시한다. 어느 모드든 한 경기를 마치면 부른다.
    static func recordPlay(now: Date = Date(), defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: playKeyPrefix + key(for: now))
    }

    /// 날짜 키(`yyyyMMdd`, 서울 기준).
    static func key(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.string(from: date)
    }

    /// 하루 앞선 날짜. 서울 자정을 기준으로 센다 — 판이 서울 자정에 바뀌므로
    /// 연속 판정도 같은 경계를 써야 "어제 23시 50분에 했는데 끊겼다"가 없다.
    private static func previousDay(_ date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar.date(byAdding: .day, value: -1, to: date) ?? date
    }

    /// 오늘 야구를 했는가 — 모드를 가리지 않는다. 연속 일수는 이쪽을 센다.
    ///
    /// 옛 일일 모드 키도 함께 본다. 새 키만 보면 업데이트 전 연속 기록이 0일부터 다시
    /// 시작한다.
    static func playedToday(now: Date = Date(), defaults: UserDefaults = .standard) -> Bool {
        playedAny(on: now, defaults: defaults)
    }

    private static func playedAny(on date: Date, defaults: UserDefaults) -> Bool {
        let day = key(for: date)
        return defaults.bool(forKey: playKeyPrefix + day)
            || defaults.bool(forKey: playedKeyPrefix + day)
    }

    /// 지금 몇 일 연속인가.
    ///
    /// **오늘을 아직 안 했어도 어제까지의 연속은 살아 있다.** 그래야 "오늘 하면 N+1일째"를
    /// 말할 수 있고, 그 문장이 오늘 켜는 이유가 된다. 오늘 자정을 넘겨 어제도 비면 0이다.
    static func current(now: Date = Date(), defaults: UserDefaults = .standard) -> Int {
        var count = 0
        var cursor = playedToday(now: now, defaults: defaults) ? now : previousDay(now)
        // 상한을 둔다 — 저장이 깨져도 루프가 끝난다. 366일이면 어떤 표시에도 충분하다.
        while count < 366, playedAny(on: cursor, defaults: defaults) {
            count += 1
            cursor = previousDay(cursor)
        }
        return count
    }

    /// 화면에 붙일 한 줄. 연속이 없으면 nil — 0일째를 자랑하지 않는다.
    static func caption(now: Date = Date(), defaults: UserDefaults = .standard) -> String? {
        let streak = current(now: now, defaults: defaults)
        guard streak > 0 else { return nil }
        if playedToday(now: now, defaults: defaults) {
            return "\(streak)일 연속"
        }
        // 끊기기 직전이라는 사실이 오늘 켜는 이유다.
        return "\(streak)일 연속 — 오늘 던지면 \(streak + 1)일째"
    }
}
