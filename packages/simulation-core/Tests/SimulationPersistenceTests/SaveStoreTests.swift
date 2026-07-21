import Foundation
import XCTest
@testable import SimulationPersistence

final class SaveStoreTests: XCTestCase {
    private var temporaryDirectory: URL!
    private let store = SaveStore(backupCount: 3)

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("diamond-soul-save-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testSaveAndLoadPrimaryArchive() throws {
        let url = saveURL()
        try store.save(makeContents(revision: 1), to: url)

        let loaded = try store.load(from: url)

        XCTAssertEqual(loaded.source, .primary)
        XCTAssertEqual(loaded.contents.manifest.revision, 1)
        XCTAssertFalse(loaded.recoveredFromBackup)
    }

    func testKeepsThreeRotatingBackups() throws {
        let url = saveURL()
        for revision in 1...5 {
            try store.save(makeContents(revision: UInt64(revision)), to: url)
        }

        XCTAssertEqual(try revision(at: url), 5)
        XCTAssertEqual(try revision(at: store.backupURL(for: url, index: 1)), 4)
        XCTAssertEqual(try revision(at: store.backupURL(for: url, index: 2)), 3)
        XCTAssertEqual(try revision(at: store.backupURL(for: url, index: 3)), 2)
    }

    func testCorruptPrimaryLoadsLastValidBackupWithoutOverwritingOriginal() throws {
        let url = saveURL()
        try store.save(makeContents(revision: 1), to: url)
        try store.save(makeContents(revision: 2), to: url)
        let corruptBytes = Data("truncated-save".utf8)
        try corruptBytes.write(to: url)

        let loaded = try store.load(from: url)

        XCTAssertEqual(loaded.source, .backup(index: 1))
        XCTAssertEqual(loaded.contents.manifest.revision, 1)
        XCTAssertEqual(loaded.failedCandidates.map(\.url), [url])
        XCTAssertEqual(try Data(contentsOf: url), corruptBytes)
    }

    func testMissingPrimaryAfterInterruptedReplacementLoadsBackup() throws {
        let url = saveURL()
        try store.save(makeContents(revision: 1), to: url)
        try store.save(makeContents(revision: 2), to: url)
        try FileManager.default.removeItem(at: url)
        try Data("partial-new-save".utf8).write(
            to: temporaryDirectory.appendingPathComponent(".career.dscareer.interrupted.tmp")
        )

        let loaded = try store.load(from: url)

        XCTAssertEqual(loaded.source, .backup(index: 1))
        XCTAssertEqual(loaded.contents.manifest.revision, 1)
    }

    func testSavingAfterCorruptionPreservesCorruptFileAndExistingBackup() throws {
        let url = saveURL()
        try store.save(makeContents(revision: 1), to: url)
        try store.save(makeContents(revision: 2), to: url)
        let corruptBytes = Data("broken-current-save".utf8)
        try corruptBytes.write(to: url)

        try store.save(makeContents(revision: 3), to: url)

        XCTAssertEqual(try revision(at: url), 3)
        XCTAssertEqual(try revision(at: store.backupURL(for: url, index: 1)), 1)
        let files = try FileManager.default.contentsOfDirectory(
            at: temporaryDirectory,
            includingPropertiesForKeys: nil
        )
        let corruptURL = try XCTUnwrap(files.first { $0.lastPathComponent.contains(".corrupt-") })
        XCTAssertEqual(try Data(contentsOf: corruptURL), corruptBytes)
    }

    func testNoValidCandidateReportsEveryCorruptFile() throws {
        let url = saveURL()
        try Data("bad-primary".utf8).write(to: url)
        try Data("bad-backup".utf8).write(to: store.backupURL(for: url, index: 1))

        XCTAssertThrowsError(try store.load(from: url)) { error in
            guard case .noValidSave(let failures) = error as? SaveArchiveError else {
                return XCTFail("Expected noValidSave, received \(error)")
            }
            XCTAssertEqual(failures.count, 2)
        }
    }

    private func saveURL() -> URL {
        temporaryDirectory.appendingPathComponent("career.dscareer")
    }

    private func revision(at url: URL) throws -> UInt64 {
        try PortableSaveArchive.decode(Data(contentsOf: url)).manifest.revision
    }

    private func makeContents(revision: UInt64) -> PortableSaveContents {
        let createdAt = Date(timeIntervalSince1970: 1_753_056_000)
        let lastSavedAt = createdAt.addingTimeInterval(TimeInterval(revision))
        return PortableSaveContents(
            manifest: SaveManifest(
                schemaVersion: 1,
                engineVersion: "0.1.0",
                contentVersion: "base-0.1.0",
                worldID: "world-1",
                careerID: "career-1",
                revision: revision,
                createdAt: createdAt,
                lastSavedAt: lastSavedAt,
                activeContentPacks: [SaveContentPack(id: "base", version: "0.1.0")]
            ),
            worldSnapshot: Data("{\"revision\":\(revision)}".utf8),
            careerSnapshot: Data("{\"revision\":\(revision)}".utf8),
            metaSnapshot: Data("{\"baseballSoul\":0}".utf8),
            rngState: Data("{\"state\":\"\(revision)\"}".utf8),
            eventsNDJSON: Data("{\"revision\":\(revision)}\n".utf8),
            contentLock: Data("{\"packs\":[]}".utf8)
        )
    }
}
