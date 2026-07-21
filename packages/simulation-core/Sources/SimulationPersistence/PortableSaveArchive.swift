import Foundation

public enum PortableSaveArchive {
    public static let fileExtension = "dscareer"

    private static let manifestName = "manifest.json"
    private static let worldName = "world.snapshot.json"
    private static let careerName = "career.snapshot.json"
    private static let metaName = "meta.snapshot.json"
    private static let rngName = "rng.json"
    private static let eventsName = "events.ndjson"
    private static let contentLockName = "content-lock.json"
    private static let checksumsName = "checksums.json"
    private static let thumbnailName = "optional/thumbnail.png"

    private struct ChecksumFile: Codable {
        let algorithm: String
        let files: [String: String]
    }

    public static func encode(_ contents: PortableSaveContents) throws -> Data {
        try validateManifest(contents.manifest)

        var entries: [String: Data] = [
            manifestName: try encodeJSON(contents.manifest),
            worldName: contents.worldSnapshot,
            careerName: contents.careerSnapshot,
            metaName: contents.metaSnapshot,
            rngName: contents.rngState,
            eventsName: contents.eventsNDJSON,
            contentLockName: contents.contentLock
        ]
        if let thumbnail = contents.thumbnailPNG {
            entries[thumbnailName] = thumbnail
        }
        let checksums = Dictionary(uniqueKeysWithValues: entries.map { name, data in
            (name, SHA256.hexDigest(data))
        })
        entries[checksumsName] = try encodeJSON(
            ChecksumFile(algorithm: "sha256", files: checksums)
        )
        return try ZIPArchive.encode(entries: entries)
    }

    public static func decode(_ archive: Data) throws -> PortableSaveContents {
        let entries = try ZIPArchive.decode(archive)
        let requiredNames = [
            manifestName,
            worldName,
            careerName,
            metaName,
            rngName,
            eventsName,
            contentLockName,
            checksumsName
        ]
        for name in requiredNames where entries[name] == nil {
            throw SaveArchiveError.missingEntry(name)
        }
        let allowedNames = Set(requiredNames + [thumbnailName])
        if let unexpected = entries.keys.first(where: { !allowedNames.contains($0) }) {
            throw SaveArchiveError.unexpectedEntry(unexpected)
        }

        let checksumsData = try requiredEntry(checksumsName, in: entries)
        let checksums = try decodeJSON(ChecksumFile.self, from: checksumsData)
        guard checksums.algorithm.lowercased() == "sha256" else {
            throw SaveArchiveError.unsupportedChecksumAlgorithm(checksums.algorithm)
        }
        let payloadEntries = entries.filter { $0.key != checksumsName }
        guard Set(checksums.files.keys) == Set(payloadEntries.keys) else {
            throw SaveArchiveError.invalidArchive("checksum index does not match archive entries")
        }
        for (name, data) in payloadEntries {
            guard checksums.files[name] == SHA256.hexDigest(data) else {
                throw SaveArchiveError.checksumMismatch(name)
            }
        }

        let manifestData = try requiredEntry(manifestName, in: entries)
        let manifest = try decodeJSON(SaveManifest.self, from: manifestData)
        try validateManifest(manifest)
        return PortableSaveContents(
            manifest: manifest,
            worldSnapshot: try requiredEntry(worldName, in: entries),
            careerSnapshot: try requiredEntry(careerName, in: entries),
            metaSnapshot: try requiredEntry(metaName, in: entries),
            rngState: try requiredEntry(rngName, in: entries),
            eventsNDJSON: try requiredEntry(eventsName, in: entries),
            contentLock: try requiredEntry(contentLockName, in: entries),
            thumbnailPNG: entries[thumbnailName]
        )
    }

    private static func validateManifest(_ manifest: SaveManifest) throws {
        guard manifest.format == SaveManifest.currentFormat else {
            throw SaveArchiveError.invalidManifest("unsupported format \(manifest.format)")
        }
        guard manifest.schemaVersion >= 1 else {
            throw SaveArchiveError.invalidManifest("schemaVersion must be at least 1")
        }
        let requiredStrings = [
            ("engineVersion", manifest.engineVersion),
            ("contentVersion", manifest.contentVersion),
            ("worldID", manifest.worldID)
        ]
        if let empty = requiredStrings.first(where: { $0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            throw SaveArchiveError.invalidManifest("\(empty.0) cannot be empty")
        }
        if manifest.lastSavedAt < manifest.createdAt {
            throw SaveArchiveError.invalidManifest("lastSavedAt precedes createdAt")
        }
        if let invalidPack = manifest.activeContentPacks.first(where: {
            $0.id.isEmpty || $0.version.isEmpty
        }) {
            throw SaveArchiveError.invalidManifest("invalid content pack \(invalidPack.id)")
        }
    }

    private static func requiredEntry(
        _ name: String,
        in entries: [String: Data]
    ) throws -> Data {
        guard let data = entries[name] else {
            throw SaveArchiveError.missingEntry(name)
        }
        return data
    }

    private static func encodeJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private static func decodeJSON<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw SaveArchiveError.invalidArchive("invalid JSON: \(error.localizedDescription)")
        }
    }
}
