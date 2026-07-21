import Foundation

public struct SaveContentPack: Codable, Equatable, Sendable {
    public let id: String
    public let version: String

    public init(id: String, version: String) {
        self.id = id
        self.version = version
    }
}

public struct SaveManifest: Codable, Equatable, Sendable {
    public static let currentFormat = "DiamondSoulSave"

    public let format: String
    public let schemaVersion: Int
    public let engineVersion: String
    public let contentVersion: String
    public let worldID: String
    public let careerID: String?
    public let revision: UInt64
    public let createdAt: Date
    public let lastSavedAt: Date
    public let activeContentPacks: [SaveContentPack]

    public init(
        schemaVersion: Int,
        engineVersion: String,
        contentVersion: String,
        worldID: String,
        careerID: String?,
        revision: UInt64,
        createdAt: Date,
        lastSavedAt: Date,
        activeContentPacks: [SaveContentPack]
    ) {
        self.format = Self.currentFormat
        self.schemaVersion = schemaVersion
        self.engineVersion = engineVersion
        self.contentVersion = contentVersion
        self.worldID = worldID
        self.careerID = careerID
        self.revision = revision
        self.createdAt = createdAt
        self.lastSavedAt = lastSavedAt
        self.activeContentPacks = activeContentPacks
    }
}

public struct PortableSaveContents: Equatable, Sendable {
    public let manifest: SaveManifest
    public let worldSnapshot: Data
    public let careerSnapshot: Data
    public let metaSnapshot: Data
    public let rngState: Data
    public let eventsNDJSON: Data
    public let contentLock: Data
    public let thumbnailPNG: Data?

    public init(
        manifest: SaveManifest,
        worldSnapshot: Data,
        careerSnapshot: Data,
        metaSnapshot: Data,
        rngState: Data,
        eventsNDJSON: Data,
        contentLock: Data,
        thumbnailPNG: Data? = nil
    ) {
        self.manifest = manifest
        self.worldSnapshot = worldSnapshot
        self.careerSnapshot = careerSnapshot
        self.metaSnapshot = metaSnapshot
        self.rngState = rngState
        self.eventsNDJSON = eventsNDJSON
        self.contentLock = contentLock
        self.thumbnailPNG = thumbnailPNG
    }
}

public enum SaveLoadSource: Equatable, Sendable {
    case primary
    case backup(index: Int)
}

public struct SaveCandidateFailure: Equatable, Sendable {
    public let url: URL
    public let message: String

    public init(url: URL, message: String) {
        self.url = url
        self.message = message
    }
}

public struct SaveLoadResult: Equatable, Sendable {
    public let contents: PortableSaveContents
    public let source: SaveLoadSource
    public let failedCandidates: [SaveCandidateFailure]

    public var recoveredFromBackup: Bool {
        if case .backup = source { return true }
        return false
    }

    public init(
        contents: PortableSaveContents,
        source: SaveLoadSource,
        failedCandidates: [SaveCandidateFailure]
    ) {
        self.contents = contents
        self.source = source
        self.failedCandidates = failedCandidates
    }
}

public enum SaveArchiveError: Error, Equatable, LocalizedError, Sendable {
    case invalidManifest(String)
    case invalidArchive(String)
    case missingEntry(String)
    case unexpectedEntry(String)
    case checksumMismatch(String)
    case unsupportedChecksumAlgorithm(String)
    case noValidSave([SaveCandidateFailure])

    public var errorDescription: String? {
        switch self {
        case .invalidManifest(let detail):
            return "Invalid save manifest: \(detail)"
        case .invalidArchive(let detail):
            return "Invalid save archive: \(detail)"
        case .missingEntry(let name):
            return "Save archive is missing \(name)"
        case .unexpectedEntry(let name):
            return "Save archive contains an unexpected entry: \(name)"
        case .checksumMismatch(let name):
            return "Save checksum mismatch: \(name)"
        case .unsupportedChecksumAlgorithm(let algorithm):
            return "Unsupported checksum algorithm: \(algorithm)"
        case .noValidSave:
            return "No valid primary save or backup is available"
        }
    }
}
