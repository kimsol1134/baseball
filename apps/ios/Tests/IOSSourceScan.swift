import Foundation

enum IOSSourceScan {
    static func repositoryRoot(from filePath: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(filePath)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func read(_ relativePath: String, from filePath: StaticString = #filePath) throws -> String {
        try String(
            contentsOf: repositoryRoot(from: filePath).appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    static func readAll(_ relativePaths: [String], from filePath: StaticString = #filePath) throws -> String {
        try relativePaths.map { try read($0, from: filePath) }.joined(separator: "\n")
    }
}
