import Foundation

/// Typed values supplied to a localized copy template.
public enum LocalizedCopyArgument: Equatable, Sendable {
    case userText(String)
    case contentID(String)
    case integer(Int)
    case decimal(Double)

    var cVarArgument: CVarArg {
        switch self {
        case .userText(let value), .contentID(let value): value
        case .integer(let value): value
        case .decimal(let value): value
        }
    }

    var placeholderKind: String {
        switch self {
        case .userText, .contentID: "string"
        case .integer: "integer"
        case .decimal: "decimal"
        }
    }
}

/// An app-local copy reference after a semantic key has been mapped to a String Catalog.
///
/// This name is intentionally distinct from `SimulationCore.CopyToken`. Core owns the
/// language-neutral reference; iOS owns only the localized catalog key and formatter values.
public struct LocalizedCopyToken: Equatable, Sendable {
    public let key: GameCopyKey
    public let arguments: [LocalizedCopyArgument]

    public init(key: GameCopyKey, arguments: [LocalizedCopyArgument] = []) {
        self.key = key
        self.arguments = arguments
    }
}

public typealias GameCopyToken = LocalizedCopyToken
public typealias GameCopyArgument = LocalizedCopyArgument
