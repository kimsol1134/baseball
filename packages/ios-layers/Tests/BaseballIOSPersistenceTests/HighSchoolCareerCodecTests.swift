import XCTest
import SimulationCore
import BaseballIOSDomain
import BaseballIOSPersistence

final class HighSchoolCareerCodecTests: XCTestCase {
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
        var inheritance = Inheritance.firstLife
        inheritance.soulPoints = 40
        XCTAssertNil(inheritance.soulTotalEarned)
        XCTAssertNil(inheritance.automaticSoulEarned)

        let migrated = HighSchoolCareerPersistence.migratedInheritance(inheritance)
        XCTAssertEqual(migrated.soulTotalEarned, 40)
        XCTAssertEqual(migrated.automaticSoulEarned, 40)
        XCTAssertEqual(migrated.soulPoints, 40)
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
}
