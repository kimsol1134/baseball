import Foundation
import SimulationPersistence

let arguments = Array(CommandLine.arguments.dropFirst())
let outputURL: URL = {
    if let outputIndex = arguments.firstIndex(of: "--output") {
        let valueIndex = arguments.index(after: outputIndex)
        if arguments.indices.contains(valueIndex) {
            return URL(fileURLWithPath: arguments[valueIndex]).standardizedFileURL
        }
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("prototype.dscareer")
}()

let now = Date()
let contents = PortableSaveContents(
    manifest: SaveManifest(
        schemaVersion: 1,
        engineVersion: "0.1.0",
        contentVersion: "base-0.1.0",
        worldID: "prototype-world",
        careerID: "prototype-career",
        revision: 1,
        createdAt: now,
        lastSavedAt: now,
        activeContentPacks: [SaveContentPack(id: "base", version: "0.1.0")]
    ),
    worldSnapshot: Data("{\"revision\":1,\"worldID\":\"prototype-world\"}\n".utf8),
    careerSnapshot: Data("{\"careerID\":\"prototype-career\",\"phase\":\"high_school\"}\n".utf8),
    metaSnapshot: Data("{\"baseballSoul\":0}\n".utf8),
    rngState: Data("{\"algorithm\":\"splitmix64\",\"state\":\"20260721\"}\n".utf8),
    eventsNDJSON: Data("{\"eventType\":\"save_created\",\"revision\":1}\n".utf8),
    contentLock: Data("{\"packs\":[{\"id\":\"base\",\"version\":\"0.1.0\"}]}\n".utf8)
)

let store = SaveStore()
try store.save(contents, to: outputURL)
let loaded = try store.load(from: outputURL)
let report: [String: Any] = [
    "path": outputURL.path,
    "revision": loaded.contents.manifest.revision,
    "schemaVersion": loaded.contents.manifest.schemaVersion,
    "source": loaded.recoveredFromBackup ? "backup" : "primary"
]
let reportData = try JSONSerialization.data(
    withJSONObject: report,
    options: [.prettyPrinted, .sortedKeys]
)
FileHandle.standardOutput.write(reportData)
FileHandle.standardOutput.write(Data("\n".utf8))
