import Foundation

enum IOSSourceScan {
    enum ScanError: Error, LocalizedError {
        case typeNotFound(String)
        case unbalancedBraces(String)

        var errorDescription: String? {
            switch self {
            case .typeNotFound(let name):
                return "소스에서 \(name) 타입을 찾지 못했습니다."
            case .unbalancedBraces(let name):
                return "\(name) 타입의 중괄호가 맞지 않습니다."
            }
        }
    }

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

    /// 주석 마커가 아니라 타입 선언의 중괄호로 본문을 자른다. 화면을 파일로 나눠도
    /// 카드 단위 계약을 같은 방식으로 검사할 수 있다.
    static func typeBody(
        _ typeName: String,
        in relativePath: String,
        from filePath: StaticString = #filePath
    ) throws -> String {
        try typeBody(typeName, source: try read(relativePath, from: filePath))
    }

    static func typeBody(_ typeName: String, source: String) throws -> String {
        let pattern = try NSRegularExpression(
            pattern: #"(?:struct|enum|class|actor)\s+\#(NSRegularExpression.escapedPattern(for: typeName))\b"#
        )
        let fullRange = NSRange(source.startIndex..<source.endIndex, in: source)
        guard let match = pattern.firstMatch(in: source, range: fullRange),
              let start = Range(match.range, in: source) else {
            throw ScanError.typeNotFound(typeName)
        }
        guard let braceStart = source[start.lowerBound...].firstIndex(of: "{") else {
            throw ScanError.unbalancedBraces(typeName)
        }

        var depth = 0
        var inString = false
        var escape = false
        var index = braceStart
        while index < source.endIndex {
            let character = source[index]
            if inString {
                if escape {
                    escape = false
                } else if character == "\\" {
                    escape = true
                } else if character == "\"" {
                    inString = false
                }
            } else if character == "\"" {
                inString = true
            } else if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(source[start.lowerBound..<source.index(after: index)])
                }
            }
            index = source.index(after: index)
        }
        throw ScanError.unbalancedBraces(typeName)
    }
}
