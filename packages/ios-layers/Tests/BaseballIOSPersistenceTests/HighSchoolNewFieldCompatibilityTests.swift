import XCTest
import SimulationCore
import BaseballIOSDomain
import BaseballIOSPersistence

/// 규칙 5~7이 더한 값들이 저장을 오가는지, 그리고 그 값이 없던 저장이 그대로 열리는지.
final class HighSchoolNewFieldCompatibilityTests: XCTestCase {

    private func startedCareer() throws -> HighSchoolCareerResult {
        let engine = HighSchoolCareerEngine()
        var result = try engine.start(.init(
            seed: "918220", presetID: "power_prospect",
            signatureLegacyID: nil, inheritanceRulesVersion: nil))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(
            seed: result.nextSeed, state: result.snapshot,
            schoolID: try XCTUnwrap(result.snapshot.schoolOptions.first?.id)))
        return try engine.commitTraining(.init(
            seed: result.nextSeed, state: result.snapshot, focus: .velocity, intensity: .standard))
    }

    func testTrainingProgressAndRulesVersionSurviveASaveRoundTrip() throws {
        let trained = try startedCareer()
        XCTAssertEqual(trained.snapshot.balanceVersion, HighSchoolGameplayRules.current)
        let progress = try XCTUnwrap(trained.snapshot.trainingProgress)

        let record = HighSchoolCareerSaveRecord(
            result: trained, inheritance: .firstLife, revision: 1,
            schemaVersion: HighSchoolCareerPersistence.currentSchemaVersion)
        let data = try XCTUnwrap(HighSchoolCareerPersistence.encode(record))
        let restored = try XCTUnwrap(HighSchoolCareerPersistence.decode(data))
        let snapshot = try XCTUnwrap(restored.result?.snapshot)

        XCTAssertEqual(snapshot.trainingProgress, progress)
        XCTAssertEqual(snapshot.balanceVersion, HighSchoolGameplayRules.current)
        // 서명이 그대로여야 다시 연 커리어가 다음 명령을 받는다.
        XCTAssertEqual(snapshot.stateCommitment, trained.snapshot.stateCommitment)
        XCTAssertNoThrow(try HighSchoolCareerEngine().commitTraining(.init(
            seed: restored.result?.nextSeed ?? "1", state: snapshot,
            focus: .velocity, intensity: .light)))
    }

    func testASaveWrittenBeforeTheseFieldsStillOpens() throws {
        let trained = try startedCareer()
        let record = HighSchoolCareerSaveRecord(
            result: trained, inheritance: .firstLife, revision: 1,
            schemaVersion: HighSchoolCareerPersistence.currentSchemaVersion)
        let data = try XCTUnwrap(HighSchoolCareerPersistence.encode(record))

        // 새 필드를 지운 저장은 그 필드가 없던 빌드가 쓴 파일과 같은 모양이다.
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var result = try XCTUnwrap(object["result"] as? [String: Any])
        var snapshot = try XCTUnwrap(result["snapshot"] as? [String: Any])
        snapshot.removeValue(forKey: "trainingProgress")
        var performance = try XCTUnwrap(snapshot["performance"] as? [String: Any])
        performance.removeValue(forKey: "perfectReleases")
        snapshot["performance"] = performance
        result["snapshot"] = snapshot
        object["result"] = result

        let stripped = try JSONSerialization.data(withJSONObject: object)
        let restored = try XCTUnwrap(HighSchoolCareerPersistence.decode(stripped))
        let restoredSnapshot = try XCTUnwrap(restored.result?.snapshot)
        XCTAssertNil(restoredSnapshot.trainingProgress)
        XCTAssertNil(restoredSnapshot.performance.perfectReleases)
    }
}
