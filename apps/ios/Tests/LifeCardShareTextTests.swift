import XCTest
@testable import BaseballIOS

/// The share button sends `LifeCardShareText.body` as a text item. That body is the
/// only path from a shared card back to the App Store, so the URL must not pin Korea.
@MainActor
final class LifeCardShareTextTests: XCTestCase {
    func testSharedBodyUsesStorefrontNeutralAppStoreURL() {
        let record = HighSchoolCareerStore.LifeRecord(
            lifeNumber: 1,
            playerName: "Alex Han",
            schoolName: "Seoul Chungrim High",
            drafted: false,
            evaluationScore: 61,
            teamName: nil,
            memories: [],
            games: 4,
            strikeouts: 5,
            walks: 1,
            runsAllowed: 0,
            soulPoints: 30,
            careerID: "career-17796881230217421145-life-1"
        )

        let body = LifeCardShareText.body(for: record)

        XCTAssertTrue(body.contains("apps.apple.com"), "share text must include an App Store host")
        XCTAssertTrue(body.contains("6794754217"), "share text must include this app's Apple ID")
        XCTAssertTrue(
            body.contains(LifeCardShareText.storeURL),
            "share text must use the same store URL the share button appends"
        )
        XCTAssertFalse(
            body.contains("apps.apple.com/kr/"),
            "a Korea-pinned storefront sends English viewers to the wrong listing"
        )
        XCTAssertEqual(LifeCardShareText.storeURL, "https://apps.apple.com/app/id6794754217")
    }
}
