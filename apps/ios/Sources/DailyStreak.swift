import Foundation

/// 오늘의 이닝 연속 기록.
///
/// 왜 필요한가: 2026-08 Amplitude에서 하루 DAU 43명 중 오늘의 이닝을 연 사람은 3명(7%)
/// 이었고, D2 리텐션은 0%였다. 사람들은 첫 세션에 1회차를 통째로 끝내고(1인당 10.6경기)
/// **"다 봤다"는 상태로 떠난다.** 오늘의 이닝은 "내일 3분"의 이유로 만들어졌지만,
/// 쌓이는 것이 없으면 하루 건너뛰어도 잃는 것이 없다. 연속 일수는 그 손실을 만든다.
///
/// 저장은 이미 있는 `baseball.daily.played.<yyyyMMdd>` 플래그를 그대로 읽는다 —
/// 새 저장 형식을 만들면 어제까지 플레이한 사람의 기록이 0일부터 다시 시작한다.
enum DailyStreak {
    /// 오늘의 이닝 전용 플래그. 복귀 알림이 "오늘 이미 던졌으니 건너뛴다"를 판단할 때도
    /// 이 키를 본다 — 그래서 커리어 경기를 여기 섞으면 오늘의 이닝 알림이 잘못 사라진다.
    static let playedKeyPrefix = "baseball.daily.played."

    /// 모드를 가리지 않는 "오늘 야구를 했다" 플래그.
    ///
    /// 예전에는 연속 일수가 오늘의 이닝만 셌다. 그런데 그 화면을 여는 사람은 DAU의 7%다 —
    /// 고교 공식 경기를 열한 번 던지고 2회차를 돌아도 연속은 0일이었고, 캡션조차 뜨지
    /// 않았다. **연속 기록 장치가 유저의 93%에게 존재하지 않았다는 뜻이다.**
    /// 알림 판단용 키와 분리해 두면 "오늘 커리어를 했다"와 "오늘의 이닝을 던졌다"를
    /// 각각 물을 수 있다.
    static let playKeyPrefix = "baseball.play.day."

    /// 지울 때 함께 지워야 하는 진행 흔적들.
    static let allPlayKeyPrefixes = [playedKeyPrefix, playKeyPrefix]

    /// 오늘 야구를 했다고 표시한다. 어느 모드든 한 경기를 마치면 부른다.
    static func recordPlay(now: Date = Date(), defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: playKeyPrefix + key(for: now))
    }

    /// 날짜 키(`yyyyMMdd`, 서울 기준). `PitchScenario.todayKey()`와 같은 규칙이다.
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

    /// 오늘의 이닝을 던졌는가. 그 화면의 "오늘 아직" 표시와 알림 건너뛰기가 쓴다.
    static func playedDailyInningToday(now: Date = Date(), defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: playedKeyPrefix + key(for: now))
    }

    /// 오늘 야구를 했는가 — 모드를 가리지 않는다. 연속 일수는 이쪽을 센다.
    ///
    /// 옛 키(오늘의 이닝 전용)도 함께 본다. 새 키만 보면 어제까지 오늘의 이닝으로
    /// 쌓아 온 사람의 연속이 0일부터 다시 시작한다.
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
