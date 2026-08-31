import XCTest
import SimulationCore
@testable import BaseballIOS

private final class ProPersistenceMemoryRemoteStore: SaveSyncRemoteStoring {
    private(set) var values: [String: Data] = [:]

    func data(forKey key: String) -> Data? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value as? Data }
    func removeObject(forKey key: String) { values.removeValue(forKey: key) }
    @discardableResult func synchronize() -> Bool { true }
}

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

    func testRepertoireCareerUsesSchemaFourAndRoundTrips() throws {
        let preset = PitcherPresetCatalog.all[0]
        let selection = PitchLearningRules.recommendedSelection(presetID: preset.id)
        let result = try CareerBootstrap.startCareer(
            preset: preset,
            playerName: "저장구종",
            seed: 88_823,
            startingRepertoire: selection
        )
        XCTAssertEqual(
            ProCareerPersistence.schemaVersion(for: result),
            ProCareerPersistence.repertoireSchemaVersion
        )
        let data = try XCTUnwrap(ProCareerPersistence.encode(.init(
            result: result,
            schemaVersion: ProCareerPersistence.repertoireSchemaVersion,
            syncRevision: result.snapshot.revision
        )))
        let restored = try XCTUnwrap(ProCareerPersistence.decode(data))
        XCTAssertEqual(restored.result?.snapshot.pitchLearningProject, result.snapshot.pitchLearningProject)
        XCTAssertEqual(restored.result?.snapshot.pitcher, result.snapshot.pitcher)
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

    func testInjuryWrapperKeepsSchemaFiveAfterEngineEventClears() throws {
        let legacy = try resultWithoutMastery(fixtureResult())
        let event = ProInjuryEventSnapshot(
            season: 1,
            week: 4,
            plan: .developStuff,
            rawFatigue: 82,
            effectiveFatigue: 86,
            pitches: 91,
            recoveryWeeks: 3,
            careerID: legacy.snapshot.proCareerID,
            revision: legacy.snapshot.revision
        )

        var pending = ProCareerPersistedState(result: legacy)
        pending.pendingInjuryEvent = event
        XCTAssertEqual(
            ProCareerPersistence.schemaVersion(for: pending),
            ProCareerPersistence.masterySchemaVersion
        )

        pending.pendingInjuryEvent = nil
        pending.acknowledgedInjuryEventID = event.stableID
        XCTAssertEqual(
            ProCareerPersistence.schemaVersion(for: pending),
            ProCareerPersistence.masterySchemaVersion
        )

        let record = ProCareerPersistence.record(
            from: pending,
            schemaVersion: ProCareerPersistence.schemaVersion(for: pending),
            syncRevision: 7
        )
        let encoded = try XCTUnwrap(ProCareerPersistence.encode(record))
        let restored = try XCTUnwrap(ProCareerPersistence.decode(encoded))
        XCTAssertEqual(restored.acknowledgedInjuryEventID, event.stableID)
        XCTAssertEqual(restored.schemaVersion, ProCareerPersistence.masterySchemaVersion)
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

    /// 2026-08-30 "저장공간" 리뷰의 교착 A. 부상 확인은 durable이라 라이브 저장이 v5인데,
    /// 묘비 후보는 부상 wrapper 필드를 못 보고 v4로 계산됐다. 스탬프끼리 비교하던 예전
    /// 게이트는 이 묘비 쓰기를 영구 거절해 은퇴 정리(다음 선수 진행)가 막혔다.
    @MainActor
    func testDeleteCareerSucceedsAfterDurableInjuryAcknowledgement() throws {
        let cloud = ProPersistenceMemoryRemoteStore()
        let sync = SaveSync(key: "pro-injury-ack-delete-\(UUID().uuidString).json", store: cloud)
        sync.clear()
        defer { sync.clear() }

        let store = MobileCareerStore(sync: sync)
        let legacy = try resultWithoutMastery(fixtureResult())
        let event = ProInjuryEventSnapshot(
            season: 1,
            week: 4,
            plan: .developStuff,
            rawFatigue: 82,
            effectiveFatigue: 86,
            pitches: 91,
            recoveryWeeks: 3,
            careerID: legacy.snapshot.proCareerID,
            revision: legacy.snapshot.revision
        )
        store.updatePersisted {
            $0.result = legacy
            $0.acknowledgedInjuryEventID = event.stableID
        }
        store.loadState = .ready
        XCTAssertTrue(store.save())
        let live = try XCTUnwrap(ProCareerPersistence.decode(try XCTUnwrap(cloud.data(forKey: sync.key))))
        XCTAssertEqual(live.schemaVersion, ProCareerPersistence.masterySchemaVersion)

        XCTAssertTrue(store.deleteCareer())
        XCTAssertEqual(store.loadState, .needsSetup)
        let tombstone = try XCTUnwrap(ProCareerPersistence.decode(try XCTUnwrap(cloud.data(forKey: sync.key))))
        XCTAssertNil(tombstone.result)
        XCTAssertNotNil(tombstone.deletedRevision)
    }

    /// 2026-08-30 "저장공간" 리뷰의 교착 B. 마스터리·부상 세대 커리어를 지운 v5 묘비가
    /// 남으면, mastery 없이 시작하는 다음 커리어(v4)의 진입 저장이 예전 게이트에서 영구
    /// 실패했다. 묘비는 iCloud에도 남아 앱 재설치로도 풀리지 않았다.
    @MainActor
    func testStartNewCareerSucceedsOverMasteryGenerationTombstone() throws {
        let cloud = ProPersistenceMemoryRemoteStore()
        let sync = SaveSync(key: "pro-mastery-tombstone-entry-\(UUID().uuidString).json", store: cloud)
        sync.clear()
        defer { sync.clear() }

        var empty = ProCareerPersistedState.empty
        empty.syncedRevision = 12
        let tombstoneData = try XCTUnwrap(ProCareerPersistence.encode(
            ProCareerPersistence.record(
                from: empty,
                deletedRevision: 12,
                schemaVersion: ProCareerPersistence.masterySchemaVersion,
                syncRevision: 12
            )
        ))
        XCTAssertTrue(sync.write(tombstoneData))

        let store = MobileCareerStore(sync: sync)
        store.restoreOrCreateCareer()
        XCTAssertEqual(store.loadState, .needsSetup)
        XCTAssertTrue(store.startNewCareer(preset: PitcherPresetCatalog.all[0], playerName: "다음 회차"))
        let saved = try XCTUnwrap(ProCareerPersistence.decode(try XCTUnwrap(cloud.data(forKey: sync.key))))
        XCTAssertNotNil(saved.result)
        XCTAssertGreaterThan(saved.effectiveRevision, 12)
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

    private func resultWithoutMastery(_ result: ProCareerResult) throws -> ProCareerResult {
        let data = try JSONEncoder().encode(result)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var snapshot = try XCTUnwrap(object["snapshot"] as? [String: Any])
        var pitcher = try XCTUnwrap(snapshot["pitcher"] as? [String: Any])
        pitcher.removeValue(forKey: "mastery")
        snapshot["pitcher"] = pitcher
        object["snapshot"] = snapshot
        return try JSONDecoder().decode(
            ProCareerResult.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }
}
