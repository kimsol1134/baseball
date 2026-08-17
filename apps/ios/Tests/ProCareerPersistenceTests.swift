import XCTest
import SimulationCore
@testable import BaseballIOS

final class ProCareerPersistenceTests: XCTestCase {
    func testDecodeAcceptsLegacyRawResult() throws {
        let result = try fixtureResult()
        let data = try JSONEncoder().encode(result)
        let record = try XCTUnwrap(ProCareerPersistence.decode(data))
        XCTAssertEqual(record.result, result)
        XCTAssertEqual(record.schemaVersion, 1)
        XCTAssertEqual(record.syncRevision, result.snapshot.revision)
    }

    func testNextRevisionIsMonotonicAndHonorsMinimum() {
        XCTAssertEqual(ProCareerPersistence.nextRevision(after: 3, atLeast: 0), 4)
        XCTAssertEqual(ProCareerPersistence.nextRevision(after: 3, atLeast: 10), 10)
        XCTAssertEqual(ProCareerPersistence.nextRevision(after: .max, atLeast: 0), .max)
    }

    func testConflictPriorityPrefersExplicitTombstones() throws {
        let live = try fixtureResult()
        let liveData = try XCTUnwrap(ProCareerPersistence.encode(
            ProCareerPersistence.record(
                from: ProCareerPersistedState(result: live, syncedRevision: 1),
                schemaVersion: ProCareerPersistence.legacySchemaVersion,
                syncRevision: 1
            )
        ))
        let tombstoneData = try XCTUnwrap(ProCareerPersistence.encode(
            ProCareerPersistence.record(
                from: ProCareerPersistedState(syncedRevision: 1),
                deletedRevision: 1,
                schemaVersion: ProCareerPersistence.legacySchemaVersion,
                syncRevision: 1
            )
        ))
        XCTAssertEqual(ProCareerPersistence.conflictPriority(liveData), 0)
        XCTAssertEqual(ProCareerPersistence.conflictPriority(tombstoneData), 1)
        XCTAssertEqual(ProCareerPersistence.conflictPriority(Data("not-json".utf8)), 0)
        XCTAssertEqual(ProCareerPersistence.revision(tombstoneData), 1)
    }

    func testRecordAndMaterializeRoundTripDurableFields() throws {
        let result = try fixtureResult()
        var state = ProCareerPersistedState.empty
        state.result = result
        state.sourceHighSchoolCareerID = "hs-1"
        state.careerOrigin = .highSchool
        state.syncedRevision = 4
        let record = ProCareerPersistence.record(
            from: state,
            schemaVersion: ProCareerPersistence.legacySchemaVersion,
            syncRevision: 4
        )
        let restored = ProCareerPersistence.materialize(record)
        XCTAssertEqual(restored.result, result)
        XCTAssertEqual(restored.sourceHighSchoolCareerID, "hs-1")
        XCTAssertEqual(restored.careerOrigin, .highSchool)
        XCTAssertEqual(restored.syncedRevision, 4)
        XCTAssertNil(record.gameResume)
        XCTAssertNil(record.deletedRevision)
    }

    func testTombstoneUsesTheSameEmptyMappingAsDelete() {
        var empty = ProCareerPersistedState.empty
        empty.syncedRevision = 9
        let tombstone = ProCareerPersistence.record(
            from: empty,
            deletedRevision: 9,
            schemaVersion: ProCareerPersistence.journeySchemaVersion,
            syncRevision: 9
        )
        XCTAssertNil(tombstone.result)
        XCTAssertNil(tombstone.sourceHighSchoolCareerID)
        XCTAssertNil(tombstone.origin)
        XCTAssertEqual(tombstone.deletedRevision, 9)
        XCTAssertEqual(tombstone.syncRevision, 9)
        let restored = ProCareerPersistence.materialize(tombstone)
        XCTAssertNil(restored.result)
        XCTAssertEqual(restored.syncedRevision, 9)
        XCTAssertNil(restored.careerOrigin)
    }

    @MainActor
    func testCaptureAndReplacePersistedRoundTripFieldByField() throws {
        let sync = SaveSync(key: "pro-persist-capture-\(UUID().uuidString).json")
        defer { sync.clear() }
        let store = MobileCareerStore(sync: sync)
        let result = try fixtureResult()
        store.updatePersisted {
            $0.result = result
            $0.sourceHighSchoolCareerID = "hs-source"
            $0.careerOrigin = .highSchool
            $0.syncedRevision = 6
        }
        let captured = store.capturePersisted()
        store.replacePersisted(.empty)
        XCTAssertNil(store.result)
        XCTAssertNil(store.sourceHighSchoolCareerID)
        XCTAssertNil(store.careerOrigin)

        store.replacePersisted(captured)
        XCTAssertEqual(store.result, result)
        XCTAssertEqual(store.sourceHighSchoolCareerID, "hs-source")
        XCTAssertEqual(store.careerOrigin, .highSchool)
        XCTAssertEqual(store.capturePersisted(), captured)
    }

    private func fixtureResult() throws -> ProCareerResult {
        try ProCareerEngine().start(.init(
            seed: "20260817",
            identity: .defaultPitcher,
            pitcher: .init(
                id: "pro-persist-fixture",
                name: "저장 픽스처",
                stuff: 58,
                command: 55,
                movement: 56,
                stamina: 57
            ),
            draftResult: .init(
                outcome: .drafted,
                evaluationScore: 72,
                projectedRange: "2~3",
                team: ProCareerEngine.proTeams[0],
                round: 2,
                overallPick: 18,
                signingBonus: 120_000_000,
                firstSeasonGoal: nil,
                summary: "fixture"
            ),
            entitlement: .init(status: .active, source: .development, verifiedAt: "2026-08-15")
        ))
    }
}
