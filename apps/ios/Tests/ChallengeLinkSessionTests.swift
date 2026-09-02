import XCTest
@testable import BaseballIOS
import BaseballIOSDomain

/// 앱 진입 → pendingChallenge → 시작 화면 반영, 진행 중 배너, 잘못된 링크 무시.
final class ChallengeLinkSessionTests: XCTestCase {
    func testValidSchemeAppliesPendingWhenSetupIsOpen() {
        let url = URL(string: "yagurebirth://challenge/424242-7")!
        let opened = ChallengeLinkSession.handleOpen(
            url: url,
            highSchoolNeedsSetup: true,
            highSchoolTabVisible: true,
            existing: nil
        )
        XCTAssertTrue(opened.valid)
        XCTAssertEqual(opened.source, .scheme)
        XCTAssertEqual(opened.pending?.token, "424242-7")
        XCTAssertFalse(opened.invalid)
        XCTAssertEqual(ChallengeLinkSession.seedInput(from: opened.pending!), "424242-7")
        XCTAssertEqual(ChallengeLink.parseToken("424242-7")?.life, 7)
        XCTAssertFalse(
            ChallengeLink.shouldShowDeferredBanner(
                hasPending: opened.pending != nil,
                setupScreenOpen: true,
                loadSettled: true
            )
        )
    }

    func testValidUniversalLinkDefersWhenCareerIsInProgress() {
        let url = URL(string: "https://example.com/challenge/9-2")!
        let opened = ChallengeLinkSession.handleOpen(
            url: url,
            highSchoolNeedsSetup: false,
            highSchoolTabVisible: true,
            existing: nil
        )
        XCTAssertTrue(opened.valid)
        XCTAssertEqual(opened.source, .universal)
        XCTAssertEqual(opened.pending?.seed, "9")
        XCTAssertTrue(
            ChallengeLink.shouldShowDeferredBanner(
                hasPending: true,
                setupScreenOpen: false,
                loadSettled: true
            )
        )
        XCTAssertFalse(
            ChallengeLink.setupScreenOpen(highSchoolNeedsSetup: true, highSchoolTabVisible: false),
            "프로 진행 중이면 고교 시작 화면이 열려 있지 않다"
        )
    }

    func testInvalidLinkIsIgnoredAndDoesNotReplacePending() {
        let existing = ChallengeLink.Pending(seed: "111", life: 3)
        let opened = ChallengeLinkSession.handleOpen(
            url: URL(string: "yagurebirth://challenge/not-a-token")!,
            highSchoolNeedsSetup: true,
            highSchoolTabVisible: true,
            existing: existing
        )
        XCTAssertFalse(opened.valid)
        XCTAssertTrue(opened.invalid)
        XCTAssertEqual(opened.pending, existing)

        let reminder = ChallengeLinkSession.handleOpen(
            url: URL(string: "com.solkim.baseball.ios://high-school")!,
            highSchoolNeedsSetup: true,
            highSchoolTabVisible: true,
            existing: existing
        )
        XCTAssertFalse(reminder.invalid)
        XCTAssertEqual(reminder.pending, existing)
    }

    func testCareerStartConsumesPendingWithoutTouchingTheCurrentSave() {
        let pending = ChallengeLink.Pending(seed: "5", life: 1)
        XCTAssertNil(ChallengeLinkSession.consumePendingOnCareerStart(pending: pending))
    }

    func testShareItemsUseSchemeWhenHostIsEmpty() {
        let items = ChallengeLinkSession.shareItems(
            seed: "8",
            life: 2,
            host: nil,
            resolvedText: "같은 시드로 나보다 잘 키워 봐 · 코드 8-2"
        )
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first as? String, "같은 시드로 나보다 잘 키워 봐 · 코드 8-2")
        XCTAssertEqual((items.last as? URL)?.absoluteString, "yagurebirth://challenge/8-2")
        XCTAssertNil(ChallengeLink.host(from: ["CHALLENGE_LINK_HOST": ""]))
    }

    @MainActor
    func testOpenedAndSharedEventsExistForTelemetryContract() {
        XCTAssertEqual(GameAnalytics.Event.challengeLinkOpened.rawValue, "challenge_link_opened")
        XCTAssertEqual(GameAnalytics.Event.challengeLinkShared.rawValue, "challenge_link_shared")
    }
}
