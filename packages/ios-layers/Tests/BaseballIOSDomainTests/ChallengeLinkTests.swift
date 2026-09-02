import XCTest
import BaseballIOSDomain

final class ChallengeLinkTests: XCTestCase {
    func testParsesCustomSchemeIgnoringCaseTrailingSlashAndQuery() {
        let urls = [
            "yagurebirth://challenge/12345-4",
            "YAGUREBIRTH://CHALLENGE/12345-4/",
            "yagurebirth://challenge/12345-4?utm=share",
            "yagurebirth://challenge/12345-4/?ref=card",
        ]
        for raw in urls {
            let parsed = ChallengeLink.parse(url: URL(string: raw)!)
            XCTAssertEqual(parsed?.seed, "12345", raw)
            XCTAssertEqual(parsed?.life, 4, raw)
        }
    }

    func testParsesHTTPSUniversalLinkIgnoringCaseTrailingSlashAndQuery() {
        let urls = [
            "https://example.com/challenge/99-1",
            "https://example.com/Challenge/99-1/",
            "https://example.com/challenge/99-1?utm_source=og",
            "http://localhost:3000/challenge/99-1",
        ]
        for raw in urls {
            let parsed = ChallengeLink.parse(url: URL(string: raw)!)
            XCTAssertEqual(parsed?.seed, "99", raw)
            XCTAssertEqual(parsed?.life, 1, raw)
        }
    }

    func testRejectsInvalidTokensAndOutOfRangeLife() {
        let urls = [
            "yagurebirth://other/12345-4",
            "https://example.com/share/12345-4",
            "https://example.com/foo/challenge/12345-4",
            "yagurebirth://challenge/abc-4",
            "yagurebirth://challenge/12345",
            "yagurebirth://challenge/12345-0",
            "yagurebirth://challenge/12345-1000",
            "yagurebirth://challenge/12345-4-5",
            "yagurebirth://challenge/-4",
            "com.solkim.baseball.ios://high-school",
        ]
        for raw in urls {
            XCTAssertNil(ChallengeLink.parse(url: URL(string: raw)!), raw)
        }
    }

    func testParseTokenMatchesSetupChallengeRules() {
        XCTAssertEqual(ChallengeLink.parseToken("12345-4")?.seed, "12345")
        XCTAssertEqual(ChallengeLink.parseToken("도전 12345-4")?.life, 4)
        XCTAssertEqual(ChallengeLink.parseToken("012-1")?.seed, "012")
        XCTAssertNil(ChallengeLink.parseToken("12345"))
        XCTAssertNil(ChallengeLink.parseToken("12345-0"))
        XCTAssertNil(ChallengeLink.parseToken("12345-1000"))
        XCTAssertNil(ChallengeLink.parseToken(""))
    }

    func testShareURLUsesSchemeWhenHostIsEmptyAndHTTPSWhenHostIsSet() {
        XCTAssertEqual(
            ChallengeLink.shareURL(seed: "8", life: 2, host: nil)?.absoluteString,
            "yagurebirth://challenge/8-2"
        )
        XCTAssertEqual(
            ChallengeLink.shareURL(seed: "8", life: 2, host: "")?.absoluteString,
            "yagurebirth://challenge/8-2"
        )
        XCTAssertEqual(
            ChallengeLink.shareURL(seed: "8", life: 2, host: "https://play.example.com/")?.absoluteString,
            "https://play.example.com/challenge/8-2"
        )
        XCTAssertNil(ChallengeLink.shareURL(seed: "8", life: 0, host: nil))
    }

    func testShareTextReturnsCatalogKeyOnly() {
        let share = ChallengeLink.shareText(seed: "8", life: 2)
        XCTAssertEqual(share?.key, "app.challenge-link.share-text")
        XCTAssertEqual(share?.token, "8-2")
        XCTAssertNil(ChallengeLink.shareText(seed: "8", life: 1000))
    }

    func testHostFromInfoDictionaryIsEmptyByDefault() {
        XCTAssertNil(ChallengeLink.host(from: [:]))
        XCTAssertNil(ChallengeLink.host(from: ["CHALLENGE_LINK_HOST": ""]))
        XCTAssertNil(ChallengeLink.host(from: ["CHALLENGE_LINK_HOST": "   "]))
        XCTAssertEqual(
            ChallengeLink.host(from: ["CHALLENGE_LINK_HOST": "play.example.com"]),
            "play.example.com"
        )
    }

    func testOpenAppliesToSetupAndDefersDuringAnActiveCareer() {
        let url = URL(string: "yagurebirth://challenge/5-3")!
        let applied = ChallengeLink.open(url: url, setupScreenOpen: true)
        XCTAssertEqual(applied.source, .scheme)
        XCTAssertTrue(applied.valid)
        XCTAssertEqual(applied.pending?.token, "5-3")
        XCTAssertFalse(applied.showsDeferredBanner)
        XCTAssertFalse(applied.showsInvalidNotice)

        let deferred = ChallengeLink.open(url: url, setupScreenOpen: false)
        XCTAssertTrue(deferred.showsDeferredBanner)
        XCTAssertEqual(deferred.pending?.seed, "5")
    }

    func testOpenIgnoresInvalidLinksAndUniversalSource() {
        let invalid = ChallengeLink.open(
            url: URL(string: "https://example.com/challenge/nope")!,
            setupScreenOpen: true
        )
        XCTAssertEqual(invalid.source, .universal)
        XCTAssertFalse(invalid.valid)
        XCTAssertNil(invalid.pending)
        XCTAssertTrue(invalid.showsInvalidNotice)

        let reminder = ChallengeLink.open(
            url: URL(string: "com.solkim.baseball.ios://high-school")!,
            setupScreenOpen: true
        )
        XCTAssertNil(reminder.source)
        XCTAssertFalse(reminder.valid)
        XCTAssertFalse(reminder.showsInvalidNotice)
    }

    func testDeferredBannerWaitsForSettledLoadAndClosedSetup() {
        XCTAssertTrue(
            ChallengeLink.shouldShowDeferredBanner(
                hasPending: true, setupScreenOpen: false, loadSettled: true
            )
        )
        XCTAssertFalse(
            ChallengeLink.shouldShowDeferredBanner(
                hasPending: true, setupScreenOpen: true, loadSettled: true
            )
        )
        XCTAssertFalse(
            ChallengeLink.shouldShowDeferredBanner(
                hasPending: true, setupScreenOpen: false, loadSettled: false
            )
        )
        XCTAssertTrue(
            ChallengeLink.setupScreenOpen(highSchoolNeedsSetup: true, highSchoolTabVisible: true)
        )
        XCTAssertFalse(
            ChallengeLink.setupScreenOpen(highSchoolNeedsSetup: true, highSchoolTabVisible: false)
        )
    }
}
