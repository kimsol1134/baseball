import Foundation
import XCTest
import SimulationCore
@testable import BaseballIOSPersistence

private final class GenerationRemoteStore: SaveSyncRemoteStoring {
    var values: [String: Data] = [:]
    func data(forKey key: String) -> Data? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value as? Data }
    func removeObject(forKey key: String) { values[key] = nil }
    func synchronize() -> Bool { true }
}

final class SaveSyncGenerationTests: XCTestCase {
    private var root: URL!
    private var cloud: GenerationRemoteStore!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("save-generation-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        cloud = GenerationRemoteStore()
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    private func device(_ name: String) -> URL { root.appendingPathComponent(name) }
    private func sync(_ key: String = "v2", old: String? = "v1", device name: String = "a") -> SaveSync {
        SaveSync(key: key, migratingFrom: old, directory: device(name), store: cloud)
    }
    private func data(_ revision: Int, deleted: Bool = false) -> Data {
        try! JSONSerialization.data(withJSONObject: ["revision": revision, "deleted": deleted], options: [.sortedKeys])
    }
    private func revision(_ data: Data) -> UInt64? {
        ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["revision"] as? UInt64
    }
    private func priority(_ data: Data) -> Int {
        (((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["deleted"] as? Bool) == true ? 1 : 0
    }
    func testImportsTheNewestOldCopyWithoutChangingOldLocalOrCloud() throws {
        let old = sync("v1", old: nil)
        XCTAssertTrue(old.write(data(2)))
        cloud.values["v1"] = data(3)
        let imported = sync().read(revision: revision)
        XCTAssertEqual(imported, data(3))
        XCTAssertEqual(try Data(contentsOf: device("a").appendingPathComponent("v1")), data(2))
        XCTAssertEqual(cloud.values["v1"], data(3))
        XCTAssertEqual(cloud.values["v2"], data(3))
    }
    func testNewGenerationWinsOnAnotherDeviceEvenIfOldAppWritesAHigherRevision() {
        cloud.values["v1"] = data(2)
        XCTAssertEqual(sync().read(revision: revision), data(2))
        XCTAssertTrue(sync().write(data(3)))
        XCTAssertTrue(sync("v1", old: nil, device: "old-phone").write(data(900)))
        XCTAssertEqual(sync(device: "new-phone").read(revision: revision), data(3))
        XCTAssertEqual(cloud.values["v1"], data(900))
    }
    func testNewTombstoneDoesNotReimportAnOldLiveCareer() {
        cloud.values["v1"] = data(500)
        cloud.values["v2"] = data(3, deleted: true)
        XCTAssertEqual(sync().read(revision: revision, conflictPriority: priority), data(3, deleted: true))
        XCTAssertEqual(cloud.values["v1"], data(500))
    }
    func testOldTombstoneWinsEqualRevisionDuringFirstImport() {
        XCTAssertTrue(sync("v1", old: nil).write(data(3)))
        cloud.values["v1"] = data(3, deleted: true)
        XCTAssertEqual(sync().read(revision: revision, conflictPriority: priority), data(3, deleted: true))
    }
    func testUnreadableNewGenerationNeverFallsBackToOldProgress() {
        cloud.values["v1"] = data(100)
        cloud.values["v2"] = Data("unreadable".utf8)
        XCTAssertEqual(sync().readRecovering(revision: revision), .unreadable)
        XCTAssertEqual(cloud.values["v2"], Data("unreadable".utf8))
    }
    func testOldBackupCanBeImportedWithoutHealingTheOldGeneration() throws {
        let old = sync("v1", old: nil)
        XCTAssertTrue(old.write(data(2)))
        XCTAssertTrue(old.write(Data("broken".utf8)))
        XCTAssertEqual(sync().readRecovering(revision: revision), .value(data(2), source: .backup))
        XCTAssertEqual(cloud.values["v1"], Data("broken".utf8))
        XCTAssertEqual(try Data(contentsOf: device("a").appendingPathComponent("v1")), Data("broken".utf8))
    }
    func testFailedImportPreservesOldBytesAndDoesNotPublishNewCloudState() throws {
        cloud.values["v1"] = data(2)
        try FileManager.default.createDirectory(at: device("a").appendingPathComponent("v2"), withIntermediateDirectories: true)
        XCTAssertEqual(sync().readRecovering(revision: revision), .unreadable)
        XCTAssertNil(cloud.values["v2"])
        XCTAssertEqual(cloud.values["v1"], data(2))
    }
    func testRealCareerSurvivesOldModelFieldLossOnAnotherDevice() throws {
        let engine = HighSchoolCareerEngine()
        var result = try engine.start(.init(seed: "918220", presetID: "power_prospect"))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: result.snapshot.schoolOptions[0].id))
        for _ in 0..<6 where result.snapshot.phase == .training {
            result = try engine.commitTraining(.init(seed: result.nextSeed, state: result.snapshot, focus: .stamina, intensity: .light))
            if result.snapshot.trainingProgress?.isEmpty == false { break }
        }
        XCTAssertFalse(try XCTUnwrap(result.snapshot.trainingProgress).isEmpty)
        let record = HighSchoolCareerSaveRecord(result: result, inheritance: .firstLife, revision: 10,
                                                schemaVersion: HighSchoolCareerPersistence.currentSchemaVersion)
        let good = try XCTUnwrap(HighSchoolCareerPersistence.encode(record))
        XCTAssertTrue(sync().write(good))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: good) as? [String: Any])
        var oldResult = object["result"] as! [String: Any]
        var oldSnapshot = oldResult["snapshot"] as! [String: Any]
        oldSnapshot.removeValue(forKey: "trainingProgress")
        oldResult["snapshot"] = oldSnapshot
        object["result"] = oldResult
        object["revision"] = 900
        XCTAssertTrue(sync("v1", old: nil, device: "old-phone").write(try JSONSerialization.data(withJSONObject: object)))
        let restoredBytes = try XCTUnwrap(sync(device: "new-phone").read(revision: HighSchoolCareerPersistence.revision))
        XCTAssertEqual(restoredBytes, good)
        let restored = try XCTUnwrap(HighSchoolCareerPersistence.decode(restoredBytes)?.result)
        XCTAssertEqual(restored.snapshot.trainingProgress, result.snapshot.trainingProgress)
        XCTAssertNoThrow(try engine.normalizeRegionalSchools(.init(seed: restored.nextSeed, state: restored.snapshot)))
    }
}
