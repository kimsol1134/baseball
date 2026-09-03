import XCTest
@testable import BaseballIOS

final class SeenContentStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "SeenContentStoreTests.\(UUID().uuidString)")
    }

    override func tearDown() {
        if let defaults {
            SeenContentStore.reset(defaults: defaults)
        }
        defaults = nil
        super.tearDown()
    }

    func testMigratesLegacyArrayAndKeepsIDsSeen() {
        defaults.set(["hs.training.option.velocity", "pitch.coach.first"], forKey: SeenContentStore.storageKey)
        XCTAssertTrue(SeenContentStore.contains("hs.training.option.velocity", defaults: defaults))
        XCTAssertTrue(SeenContentStore.contains("pitch.coach.first", defaults: defaults))
        XCTAssertNotNil(defaults.dictionary(forKey: SeenContentStore.timestampsKey))
        XCTAssertEqual(
            Set(defaults.stringArray(forKey: SeenContentStore.storageKey) ?? []),
            ["hs.training.option.velocity", "pitch.coach.first"]
        )
    }

    func testReexpandsAfterFourteenDays() {
        let now = Date()
        SeenContentStore.markSeen(
            "pro.weekly.blueprint.v1",
            defaults: defaults,
            at: now.addingTimeInterval(-(SeenContentStore.freshnessInterval + 60))
        )
        XCTAssertFalse(
            SeenContentStore.contains("pro.weekly.blueprint.v1", defaults: defaults, now: now),
            "14일이 지난 설명은 다시 펼쳐야 한다"
        )
        SeenContentStore.markSeen("pro.weekly.blueprint.v1", defaults: defaults, at: now)
        XCTAssertTrue(SeenContentStore.contains("pro.weekly.blueprint.v1", defaults: defaults, now: now))
    }
}
