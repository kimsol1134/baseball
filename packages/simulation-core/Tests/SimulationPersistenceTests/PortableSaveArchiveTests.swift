import Foundation
import XCTest
@testable import SimulationPersistence

final class PortableSaveArchiveTests: XCTestCase {
    func testSHA256KnownVector() {
        XCTAssertEqual(
            SHA256.hexDigest(Data("abc".utf8)),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    func testCRC32KnownVector() {
        XCTAssertEqual(CRC32.checksum(Data("123456789".utf8)), 0xcbf43926)
    }

    func testPortableArchiveRoundTrip() throws {
        let original = makeContents(revision: 7)

        let archive = try PortableSaveArchive.encode(original)
        let decoded = try PortableSaveArchive.decode(archive)

        XCTAssertEqual(Array(archive.prefix(2)), [0x50, 0x4b])
        XCTAssertEqual(decoded, original)
    }

    func testPayloadTamperingFailsChecksumValidation() throws {
        let archive = try PortableSaveArchive.encode(makeContents(revision: 7))
        var entries = try ZIPArchive.decode(archive)
        entries["world.snapshot.json"] = Data("{\"revision\":999}".utf8)
        let tamperedArchive = try ZIPArchive.encode(entries: entries)

        XCTAssertThrowsError(try PortableSaveArchive.decode(tamperedArchive)) { error in
            XCTAssertEqual(error as? SaveArchiveError, .checksumMismatch("world.snapshot.json"))
        }
    }

    func testUnsafeZIPEntryNameIsRejected() {
        XCTAssertThrowsError(try ZIPArchive.encode(entries: ["../secret": Data()]))
    }

    private func makeContents(revision: UInt64) -> PortableSaveContents {
        let timestamp = Date(timeIntervalSince1970: 1_753_056_000)
        return PortableSaveContents(
            manifest: SaveManifest(
                schemaVersion: 1,
                engineVersion: "0.1.0",
                contentVersion: "base-0.1.0",
                worldID: "world-1",
                careerID: "career-1",
                revision: revision,
                createdAt: timestamp,
                lastSavedAt: timestamp,
                activeContentPacks: [SaveContentPack(id: "base", version: "0.1.0")]
            ),
            worldSnapshot: Data("{\"revision\":\(revision)}".utf8),
            careerSnapshot: Data("{\"careerID\":\"career-1\"}".utf8),
            metaSnapshot: Data("{\"baseballSoul\":2}".utf8),
            rngState: Data("{\"state\":\"42\"}".utf8),
            eventsNDJSON: Data("{\"eventType\":\"test\"}\n".utf8),
            contentLock: Data("{\"packs\":[]}".utf8),
            thumbnailPNG: Data([0x89, 0x50, 0x4e, 0x47])
        )
    }
}
