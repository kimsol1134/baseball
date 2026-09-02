import XCTest
import SimulationCore
@testable import BaseballIOS
import BaseballIOSDomain
import BaseballIOSPersistence

/// 스토어가 코덱을 어떻게 쓰는지. 순수 코덱 회귀는 `packages/ios-layers`에 있다.
final class HighSchoolCareerPersistenceTests: XCTestCase {
    @MainActor
    func testApplyPersistedRecordAndClearLiveSessionUseOneFieldMap() {
        let store = HighSchoolCareerStore(
            sync: SaveSync(key: "hs-persist-apply-\(UUID().uuidString).json")
        )
        defer { store.sync.clear() }
        store.updatePersisted {
            $0.chapterStartStrikeouts = 99
            $0.enteredProCareerID = "old-career"
            $0.rebirthEventIDs = ["evt-old"]
        }
        store.selectedMemories = [.coachLetter]
        store.lastSummary = "남아 있으면 안 되는 요약"

        var inheritance = HighSchoolCareerStore.Inheritance.firstLife
        inheritance.lifeNumber = 3
        inheritance.soulPoints = 12
        let record = HighSchoolCareerSaveRecord(
            result: nil,
            inheritance: inheritance,
            archive: [],
            enteredProCareerID: nil,
            rebirthEventIDs: ["evt-new"],
            revision: 8,
            schemaVersion: HighSchoolCareerPersistence.currentSchemaVersion
        )

        store.applyPersistedRecord(record, chapterStartFallback: .zero)
        store.clearLiveSession()

        XCTAssertEqual(store.inheritance.lifeNumber, 3)
        XCTAssertEqual(store.inheritance.soulTotalEarned, 12)
        XCTAssertEqual(store.inheritance.automaticSoulEarned, 12)
        XCTAssertEqual(store.chapterStartStrikeouts, 0)
        XCTAssertEqual(store.rebirthEventIDs, ["evt-new"])
        XCTAssertNil(store.enteredProCareerID)
        XCTAssertEqual(store.savedRevision, 8)
        XCTAssertNil(store.result)
        XCTAssertTrue(store.selectedMemories.isEmpty)
        XCTAssertTrue(store.buzz.isEmpty)
        XCTAssertTrue(store.worldNews.isEmpty)
    }

    @MainActor
    func testRestoreReadsThroughPersistenceCodec() throws {
        let sync = SaveSync(key: "hs-persist-restore-\(UUID().uuidString).json")
        defer { sync.clear() }
        var inheritance = HighSchoolCareerStore.Inheritance.firstLife
        inheritance.lifeNumber = 4
        inheritance.soulPoints = 25
        let record = HighSchoolCareerSaveRecord(
            result: nil,
            inheritance: inheritance,
            archive: [],
            chapterStartStrikeouts: 7,
            revision: 5,
            schemaVersion: HighSchoolCareerPersistence.currentSchemaVersion
        )
        XCTAssertTrue(sync.write(try XCTUnwrap(HighSchoolCareerPersistence.encode(record))))

        let store = HighSchoolCareerStore(sync: sync)
        store.updatePersisted { $0.chapterStartStrikeouts = 99 }
        XCTAssertEqual(store.restore(), .needsSetup)
        XCTAssertEqual(store.inheritance.lifeNumber, 4)
        XCTAssertEqual(store.inheritance.soulTotalEarned, 25)
        XCTAssertEqual(store.chapterStartStrikeouts, 7)
        XCTAssertEqual(store.savedRevision, 5)
        XCTAssertNil(store.result)
    }

    @MainActor
    func testCaptureAndReplacePersistedRoundTripFieldByField() {
        let store = HighSchoolCareerStore(
            sync: SaveSync(key: "hs-persist-capture-\(UUID().uuidString).json")
        )
        defer { store.sync.clear() }
        store.updatePersisted {
            $0.chapterStartStrikeouts = 4
            $0.enteredProCareerID = "career-a"
            $0.rebirthEventIDs = ["evt-a"]
        }
        let captured = store.capturePersisted()
        store.replacePersisted(.empty)
        XCTAssertEqual(store.chapterStartStrikeouts, 0)
        XCTAssertNil(store.enteredProCareerID)
        XCTAssertTrue(store.rebirthEventIDs.isEmpty)

        store.replacePersisted(captured)
        XCTAssertEqual(store.chapterStartStrikeouts, 4)
        XCTAssertEqual(store.enteredProCareerID, "career-a")
        XCTAssertEqual(store.rebirthEventIDs, ["evt-a"])
        XCTAssertEqual(store.capturePersisted(), captured)
    }

    func testTypeBodyCutsOnBracesInsteadOfCommentMarkers() throws {
        let important = try IOSSourceScan.typeBody(
            "ImportantGameCard",
            in: "apps/ios/Sources/HighSchoolRelationshipViews.swift"
        )
        XCTAssertTrue(important.contains("struct ImportantGameCard"))
        XCTAssertFalse(important.contains("각성 스킬트리"))
        XCTAssertTrue(important.contains("localizedImportantGameScenarioTitle"))
    }
}
