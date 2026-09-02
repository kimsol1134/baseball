import XCTest
import SimulationCore
import BaseballIOSDomain
import BaseballIOSPersistence

final class ProCareerCodecTests: XCTestCase {
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

    func testNationalTeamStateStampsSchemaSixAndPlainV10StaysFive() throws {
        let live = try fixtureResult()
        XCTAssertFalse(ProCareerPersistence.hasNationalTeamState(live.snapshot))
        let withoutTournament = ProCareerPersistedState(result: live)
        XCTAssertLessThan(
            ProCareerPersistence.schemaVersion(for: withoutTournament),
            ProCareerPersistence.nationalTeamSchemaVersion
        )

        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(live.snapshot)) as? [String: Any]
        )
        object["nationalTournament"] = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(
                ProNationalTournamentState(
                    seed: 1,
                    resumeSeed: "1",
                    startingFatigue: 10,
                    groupGames: [],
                    stage: .awaitingFinal,
                    finalOpponentID: "east-coast",
                    fatigueCarry: 15,
                    injuryWeeks: 0
                )
            )
        )
        object["commitment"] = ""
        let unsigned = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        let stamped = ProCareerResult(snapshot: unsigned, nextSeed: live.nextSeed, events: [])
        XCTAssertTrue(ProCareerPersistence.hasNationalTeamState(stamped.snapshot))
        XCTAssertEqual(
            ProCareerPersistence.schemaVersion(for: ProCareerPersistedState(result: stamped)),
            ProCareerPersistence.nationalTeamSchemaVersion
        )
        XCTAssertEqual(ProCareerPersistence.currentSchemaVersion, 6)
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
