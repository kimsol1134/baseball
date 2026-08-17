import XCTest
@testable import BaseballIOS

final class ShareCompletionTests: XCTestCase {
    private struct TestError: Error {}

    func testOnlySuccessfulCompletionCounts() {
        XCTAssertTrue(ShareCompletion.countsAsCompleted(completed: true, error: nil))
        XCTAssertFalse(ShareCompletion.countsAsCompleted(completed: false, error: nil))
        XCTAssertFalse(ShareCompletion.countsAsCompleted(completed: true, error: TestError()))
    }

    // 완료만 세던 계측으로는 tapped(84)→completed(15)의 82%가 어디로 갔는지 알 수 없었다.
    // outcome 라벨이 취소·오류·완료를 셋으로 갈라야 공유 퍼널을 고칠 근거가 생긴다.
    func testOutcomeSeparatesCompletionDismissalAndFailure() {
        XCTAssertEqual(ShareCompletion.outcome(completed: true, error: nil), "completed")
        XCTAssertEqual(ShareCompletion.outcome(completed: false, error: nil), "dismissed")
        XCTAssertEqual(ShareCompletion.outcome(completed: false, error: TestError()), "failed")
        XCTAssertEqual(ShareCompletion.outcome(completed: true, error: TestError()), "failed")
    }

    // 완료는 기존 이벤트 이름을 그대로 쓰고, 이탈만 새 이벤트로 나뉜다 — 기존 대시보드
    // 퍼널(completed 기준)이 조용히 깨지지 않아야 한다.
    @MainActor
    func testLogShareFinishRoutesToCompletedOrDismissedWithOutcomeProperties() {
        var recorded: [(GameAnalytics.Event, [String: Any])] = []
        GameAnalytics.eventSinkForTesting = { event, properties in recorded.append((event, properties)) }
        defer { GameAnalytics.eventSinkForTesting = nil }

        GameAnalytics.logShareFinish(
            ShareFinish(countsAsCompleted: true, activityType: "com.apple.UIKit.activity.Message", outcome: "completed"),
            ["life_number": 3]
        )
        GameAnalytics.logShareFinish(
            ShareFinish(countsAsCompleted: false, activityType: nil, outcome: "dismissed"),
            ["life_number": 3]
        )

        XCTAssertEqual(recorded.count, 2)
        XCTAssertEqual(recorded[0].0, .lifeCardShareCompleted)
        XCTAssertEqual(recorded[0].1["outcome"] as? String, "completed")
        XCTAssertEqual(recorded[0].1["activity_type"] as? String, "com.apple.UIKit.activity.Message")
        XCTAssertEqual(recorded[1].0, .lifeCardShareDismissed)
        XCTAssertEqual(recorded[1].1["outcome"] as? String, "dismissed")
        XCTAssertNil(recorded[1].1["activity_type"])
        XCTAssertEqual(recorded[1].1["life_number"] as? Int, 3)
    }
}
