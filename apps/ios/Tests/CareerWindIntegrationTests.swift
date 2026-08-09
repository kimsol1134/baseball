import Foundation
import SimulationCore
import XCTest
@testable import BaseballIOS

@MainActor
final class CareerWindIntegrationTests: XCTestCase {
    func testNewLifeCardPersistsTheV2WindShownBySimulation() throws {
        let state = try HighSchoolCareerEngine().start(.init(
            seed: "2026080901", presetID: "power_prospect"
        )).snapshot
        let record = HighSchoolCareerStore.lifeRecord(
            from: state, memories: [], previous: .firstLife
        )

        XCTAssertEqual(state.effectiveWorldRulesVersion, .v2)
        XCTAssertEqual(record.windID, state.careerWind.id)
        XCTAssertEqual(record.windTitle, state.careerWind.title)
    }

    func testSnapshotWithoutRulesVersionUsesFrozenV1WindForArchive() throws {
        let created = try HighSchoolCareerEngine().start(.init(
            seed: "2026080902", presetID: "precision_commander"
        )).snapshot
        let legacy = try removingField("worldRulesVersion", from: created)
        let record = HighSchoolCareerStore.lifeRecord(
            from: legacy, memories: [], previous: .firstLife
        )
        let expected = CareerWind.wind(careerID: legacy.careerID)

        XCTAssertNil(legacy.worldRulesVersion)
        XCTAssertEqual(legacy.effectiveWorldRulesVersion, .v1)
        XCTAssertEqual(record.windID, expected.id)
        XCTAssertEqual(record.windTitle, expected.title)
    }

    func testLifeRecordWithoutWindFieldsStillDecodes() throws {
        let state = try HighSchoolCareerEngine().start(.init(
            seed: "2026080903", presetID: "power_prospect"
        )).snapshot
        let record = HighSchoolCareerStore.lifeRecord(
            from: state, memories: [], previous: .firstLife
        )
        let legacy: HighSchoolCareerStore.LifeRecord = try removingFields(
            ["windID", "windTitle"], from: record
        )

        XCTAssertNil(legacy.windID)
        XCTAssertNil(legacy.windTitle)
    }

    private func removingField(
        _ field: String,
        from snapshot: HighSchoolCareerSnapshot
    ) throws -> HighSchoolCareerSnapshot {
        try removingFields([field], from: snapshot)
    }

    private func removingFields<T: Codable>(_ fields: [String], from value: T) throws -> T {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any]
        )
        fields.forEach { object.removeValue(forKey: $0) }
        return try JSONDecoder().decode(
            T.self, from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        )
    }
}
