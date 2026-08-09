import XCTest
@testable import BaseballIOS

final class ShareCompletionTests: XCTestCase {
    private struct TestError: Error {}

    func testOnlySuccessfulCompletionCounts() {
        XCTAssertTrue(ShareCompletion.countsAsCompleted(completed: true, error: nil))
        XCTAssertFalse(ShareCompletion.countsAsCompleted(completed: false, error: nil))
        XCTAssertFalse(ShareCompletion.countsAsCompleted(completed: true, error: TestError()))
    }
}
