import Foundation

/// 별점 요청 관문 — "지금 물어도 되는가"를 한 곳에서만 판단한다.
///
/// 시스템(`requestReview`)은 앱당 365일 3회만 실제로 시트를 띄우고, 나머지는 조용히
/// 버린다. 그래서 요청 지점이 몇 개든 **어느 순간에 쓰느냐**가 전부다. 출시 초 이 게임은
/// 지명 확정(1~2시간 뒤, 그것도 지명에 성공해야) 하나만 열어 뒀는데, 컨셉상 첫 회차는
/// 대개 미지명이라 대다수 플레이어는 리뷰 시트를 한 번도 못 봤다.
///
/// 규칙은 둘뿐이다:
/// - 이유(Reason) 하나는 평생 한 번만 쓴다. 같은 사건이 두 번째로는 감흥이 없다.
/// - 요청 사이에 최소 24시간을 둔다. 한 세션에 두 번 부르면 두 번째는 버려지므로,
///   이유 하나를 통째로 낭비하는 셈이다.
@MainActor
enum ReviewPrompt {
    /// 물어도 되는 순간들. 전부 감정이 양(+)인 지점이어야 한다 —
    /// 화난 순간에 뜬 카드는 별점을 깎는 쪽으로 작동한다.
    enum Reason: String, CaseIterable {
        /// 첫 무실점 이닝. 설치 후 가장 이른 성취.
        case cleanInning
        /// 고교 3년이 잘 끝났을 때. **미지명이어도 연다** — 위업 도장이 찍히고
        /// 야구혼이 차오르는 화면이라, 이 게임에서 감정이 가장 높은 지점 중 하나다.
        case goodRecap
        /// 3회차 진입. 반복이 확정된 순간 = 이 게임을 좋아한다는 가장 강한 신호.
        case thirdLife
        /// 오늘의 이닝 개인 최고 기록 경신.
        case dailyBest
        /// 드래프트 지명 확정. 감정 최고점이지만 도달자가 적다.
        case drafted

        /// 저장 키. `cleanInning`은 예전 키를 그대로 이어받는다 —
        /// 이미 물어본 플레이어에게 두 번 묻지 않기 위해서다.
        var key: String { "baseball.review.\(rawValue)" }
    }

    /// 요청 사이 최소 간격. 하루.
    static let minimumInterval: TimeInterval = 24 * 60 * 60
    private static let lastAskedKey = "baseball.review.lastAskedAt"

    /// 지금 이 이유로 별점을 물어도 되는가. `true`를 돌려주는 순간 소비된 것으로
    /// 기록하므로, 호출한 쪽은 반드시 `requestReview()`까지 이어서 해야 한다.
    static func shouldAsk(
        _ reason: Reason,
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> Bool {
        // UI 테스트에서는 절대 열지 않는다 — 시뮬레이터에서 시트가 실제로 떠서
        // 다음 탭을 삼키면 스모크가 간헐 실패한다.
        guard !ProcessInfo.processInfo.arguments.contains("-uiTestResetCareer") else { return false }
        guard !defaults.bool(forKey: reason.key) else { return false }
        let last = defaults.double(forKey: lastAskedKey)
        if last > 0, now.timeIntervalSince1970 - last < minimumInterval { return false }
        defaults.set(true, forKey: reason.key)
        defaults.set(now.timeIntervalSince1970, forKey: lastAskedKey)
        return true
    }

    /// "모든 진행 삭제"가 부른다. 흔적을 남기면 새 회차의 첫 순간이 이미 소모돼 있다.
    static func reset(defaults: UserDefaults = .standard) {
        for reason in Reason.allCases { defaults.removeObject(forKey: reason.key) }
        defaults.removeObject(forKey: lastAskedKey)
    }
}
