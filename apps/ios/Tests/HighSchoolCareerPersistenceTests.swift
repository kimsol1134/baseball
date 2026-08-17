import XCTest
import SimulationCore
@testable import BaseballIOS

final class HighSchoolCareerPersistenceTests: XCTestCase {
    func testDecodeRejectsFutureSchemaButRawCodableStillReadsIt() throws {
        let record = HighSchoolCareerSaveRecord(
            result: nil,
            inheritance: .firstLife,
            revision: 1,
            schemaVersion: HighSchoolCareerPersistence.currentSchemaVersion + 1
        )
        let data = try XCTUnwrap(HighSchoolCareerPersistence.encode(record))
        XCTAssertNil(HighSchoolCareerPersistence.decode(data))
        XCTAssertEqual(
            try JSONDecoder().decode(HighSchoolCareerSaveRecord.self, from: data).schemaVersion,
            HighSchoolCareerPersistence.currentSchemaVersion + 1
        )
    }

    func testDecodeAcceptsLegacyRecordWithoutSchemaVersion() throws {
        let legacy = """
        {"inheritance":{"lifeNumber":1,"memories":[],"soulPoints":0,"karmas":[]},"revision":1}
        """
        let record = try XCTUnwrap(HighSchoolCareerPersistence.decode(Data(legacy.utf8)))
        XCTAssertEqual(record.effectiveRevision, 1)
        XCTAssertNil(record.schemaVersion)
        XCTAssertNil(record.nextRunIntent)
    }

    func testNextRevisionIsMonotonicAndHonorsMinimum() {
        XCTAssertEqual(HighSchoolCareerPersistence.nextRevision(after: 3, atLeast: 0), 4)
        XCTAssertEqual(HighSchoolCareerPersistence.nextRevision(after: 3, atLeast: 10), 10)
        XCTAssertEqual(HighSchoolCareerPersistence.nextRevision(after: .max, atLeast: 0), .max)
    }

    func testConflictPriorityPrefersResultlessRecords() throws {
        let liveResult = try HighSchoolCareerEngine().start(
            .init(seed: "101", presetID: PitcherPresetCatalog.all[0].id)
        )
        let live = HighSchoolCareerSaveRecord(
            result: liveResult,
            inheritance: .firstLife,
            revision: 1,
            schemaVersion: HighSchoolCareerPersistence.currentSchemaVersion
        )
        let tombstone = HighSchoolCareerSaveRecord(
            result: nil,
            inheritance: .firstLife,
            revision: 1,
            schemaVersion: HighSchoolCareerPersistence.currentSchemaVersion
        )
        let liveData = try XCTUnwrap(HighSchoolCareerPersistence.encode(live))
        let tombstoneData = try XCTUnwrap(HighSchoolCareerPersistence.encode(tombstone))
        XCTAssertEqual(HighSchoolCareerPersistence.conflictPriority(liveData), 0)
        XCTAssertEqual(HighSchoolCareerPersistence.conflictPriority(tombstoneData), 1)
        XCTAssertEqual(HighSchoolCareerPersistence.conflictPriority(Data("not-json".utf8)), 0)
        XCTAssertEqual(HighSchoolCareerPersistence.revision(tombstoneData), 1)
    }

    func testMigratedInheritancePromotesBalanceToLifetimeTotals() {
        var inheritance = HighSchoolCareerStore.Inheritance.firstLife
        inheritance.soulPoints = 40
        XCTAssertNil(inheritance.soulTotalEarned)
        XCTAssertNil(inheritance.automaticSoulEarned)

        let migrated = HighSchoolCareerPersistence.migratedInheritance(inheritance)
        XCTAssertEqual(migrated.soulTotalEarned, 40)
        XCTAssertEqual(migrated.automaticSoulEarned, 40)
        XCTAssertEqual(migrated.soulPoints, 40)
    }

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

    func testRecordAndMaterializeRoundTripDurableFields() {
        var state = HighSchoolCareerPersistedState.empty
        state.inheritance.lifeNumber = 4
        state.inheritance.soulPoints = 18
        state.chapterStartStrikeouts = 7
        state.rebirthEventIDs = ["evt-a"]
        state.savedRevision = 5
        let record = HighSchoolCareerPersistence.record(
            from: state,
            currentCareerRetention: nil,
            revision: 5
        )
        let restored = HighSchoolCareerPersistence.materialize(
            record,
            chapterStartFallback: .zero
        )
        XCTAssertEqual(restored.inheritance.lifeNumber, 4)
        XCTAssertEqual(restored.inheritance.soulTotalEarned, 18)
        XCTAssertEqual(restored.chapterStartStrikeouts, 7)
        XCTAssertEqual(restored.rebirthEventIDs, ["evt-a"])
        XCTAssertEqual(restored.savedRevision, 5)
        XCTAssertNil(record.nicknames)
        XCTAssertNil(record.chapterGains)
    }

    func testTombstoneUsesTheSameEmptyMappingAsDelete() {
        var empty = HighSchoolCareerPersistedState.empty
        empty.savedRevision = 9
        let tombstone = HighSchoolCareerPersistence.record(
            from: empty,
            currentCareerRetention: nil,
            revision: 9
        )
        XCTAssertNil(tombstone.result)
        XCTAssertEqual(tombstone.inheritance, .firstLife)
        XCTAssertEqual(tombstone.revision, 9)
        let restored = HighSchoolCareerPersistence.materialize(
            tombstone,
            chapterStartFallback: .zero
        )
        XCTAssertNil(restored.result)
        XCTAssertEqual(restored.savedRevision, 9)
        XCTAssertTrue(restored.archive.isEmpty)
        XCTAssertTrue(restored.rebirthEventIDs.isEmpty)
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
