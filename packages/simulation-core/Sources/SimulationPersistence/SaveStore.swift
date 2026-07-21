import Foundation

public struct SaveStore: Sendable {
    public let backupCount: Int

    public init(backupCount: Int = 3) {
        self.backupCount = max(1, backupCount)
    }

    public func save(_ contents: PortableSaveContents, to saveURL: URL) throws {
        let fileManager = FileManager.default
        let directory = saveURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let temporaryURL = directory.appendingPathComponent(
            ".\(saveURL.lastPathComponent).\(UUID().uuidString).tmp"
        )
        defer { try? fileManager.removeItem(at: temporaryURL) }

        let archive = try PortableSaveArchive.encode(contents)
        try archive.write(to: temporaryURL, options: .atomic)
        _ = try PortableSaveArchive.decode(Data(contentsOf: temporaryURL))

        if fileManager.fileExists(atPath: saveURL.path) {
            if isValidArchive(at: saveURL) {
                try rotateBackups(for: saveURL, using: fileManager)
                let firstBackup = backupURL(for: saveURL, index: 1)
                try fileManager.copyItem(at: saveURL, to: firstBackup)
                do {
                    _ = try fileManager.replaceItemAt(saveURL, withItemAt: temporaryURL)
                } catch {
                    if !fileManager.fileExists(atPath: saveURL.path),
                       fileManager.fileExists(atPath: firstBackup.path) {
                        try? fileManager.copyItem(at: firstBackup, to: saveURL)
                    }
                    throw error
                }
            } else {
                let preservedURL = uniqueCorruptURL(for: saveURL, using: fileManager)
                try fileManager.moveItem(at: saveURL, to: preservedURL)
                do {
                    try fileManager.moveItem(at: temporaryURL, to: saveURL)
                } catch {
                    if !fileManager.fileExists(atPath: saveURL.path) {
                        try? fileManager.moveItem(at: preservedURL, to: saveURL)
                    }
                    throw error
                }
            }
        } else {
            try fileManager.moveItem(at: temporaryURL, to: saveURL)
        }

        _ = try PortableSaveArchive.decode(Data(contentsOf: saveURL))
    }

    public func load(from saveURL: URL) throws -> SaveLoadResult {
        let fileManager = FileManager.default
        var failures: [SaveCandidateFailure] = []
        let candidates: [(URL, SaveLoadSource)] = [(saveURL, .primary)]
            + (1...backupCount).map { (backupURL(for: saveURL, index: $0), .backup(index: $0)) }

        for (url, source) in candidates where fileManager.fileExists(atPath: url.path) {
            do {
                let contents = try PortableSaveArchive.decode(Data(contentsOf: url))
                return SaveLoadResult(
                    contents: contents,
                    source: source,
                    failedCandidates: failures
                )
            } catch {
                failures.append(
                    SaveCandidateFailure(
                        url: url,
                        message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    )
                )
            }
        }
        throw SaveArchiveError.noValidSave(failures)
    }

    public func backupURL(for saveURL: URL, index: Int) -> URL {
        precondition(index >= 1)
        return saveURL.appendingPathExtension("bak\(index)")
    }

    private func rotateBackups(for saveURL: URL, using fileManager: FileManager) throws {
        if backupCount > 1 {
            for index in stride(from: backupCount, through: 2, by: -1) {
                let destination = backupURL(for: saveURL, index: index)
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                let source = backupURL(for: saveURL, index: index - 1)
                if fileManager.fileExists(atPath: source.path) {
                    try fileManager.moveItem(at: source, to: destination)
                }
            }
        }
        let firstBackup = backupURL(for: saveURL, index: 1)
        if fileManager.fileExists(atPath: firstBackup.path) {
            try fileManager.removeItem(at: firstBackup)
        }
    }

    private func uniqueCorruptURL(for saveURL: URL, using fileManager: FileManager) -> URL {
        let directory = saveURL.deletingLastPathComponent()
        let baseName = saveURL.lastPathComponent
        var candidate = directory.appendingPathComponent("\(baseName).corrupt-\(UUID().uuidString)")
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName).corrupt-\(UUID().uuidString)")
        }
        return candidate
    }

    private func isValidArchive(at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        return (try? PortableSaveArchive.decode(data)) != nil
    }
}
