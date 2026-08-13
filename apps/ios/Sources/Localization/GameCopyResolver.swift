import Foundation
import SimulationCore
import SwiftUI

/// Resolves semantic copy references from the app's localized String Catalogs.
///
/// Missing English copy is intentionally never read from Korean. In a Release-safe resolver the
/// neutral sentence `Text unavailable` is returned and the missing key can be logged by the caller.
/// Debug/Test callers use `.strict`, which asserts before returning the same neutral value.
public struct GameCopyResolver: @unchecked Sendable {
    public enum FallbackPolicy: Sendable {
        case strict
        case releaseSafe

        public static var automatic: FallbackPolicy {
#if DEBUG
            .strict
#else
            .releaseSafe
#endif
        }
    }

    public static let unavailableText = "Text unavailable"

    public let language: AppLanguage

    private let bundle: Bundle?
    private let catalog: [AppLanguage: [String: String]]?
    private let policy: FallbackPolicy

    /// Production initializer. `bundle` is injectable so tests can point at an app/test bundle.
    public init(
        language: AppLanguage? = nil,
        bundle: Bundle = .main,
        policy: FallbackPolicy = .automatic
    ) {
        self.language = language ?? AppLanguage.current(bundle: bundle)
        self.bundle = bundle
        self.catalog = nil
        self.policy = policy
    }

    /// In-memory initializer for deterministic unit tests and catalog contract tests.
    public init(
        language: AppLanguage,
        catalog: [AppLanguage: [String: String]],
        policy: FallbackPolicy = .releaseSafe
    ) {
        self.language = language
        self.bundle = nil
        self.catalog = catalog
        self.policy = policy
    }

    public func resolve(_ key: GameCopyKey, arguments: [LocalizedCopyArgument] = []) -> String {
        resolve(LocalizedCopyToken(key: key, arguments: arguments))
    }

    public func resolve(_ token: LocalizedCopyToken) -> String {
        guard let template = lookup(token.key) else {
            return unavailable(token.key, reason: "missing localized value")
        }

        let expected = Self.placeholderKinds(in: template)
        let actual = token.arguments.map(\.placeholderKind)
        guard expected == actual else {
            return unavailable(token.key, reason: "placeholder mismatch")
        }

        guard !token.arguments.isEmpty else { return template }
        let values = token.arguments.map(\.cVarArgument)
        return String(
            format: template,
            locale: Locale(identifier: language == .english ? "en_US_POSIX" : "ko_KR"),
            arguments: values
        )
    }

    /// Resolves a SimulationCore token only after mapping its semantic ID and typed arguments.
    /// Core never supplies a localized sentence, so there is no Korean-string lookup or
    /// transliteration path here.
    public func resolve(_ token: SimulationCore.CopyToken) -> String {
        guard let key = GameCopyKey(coreToken: token) else {
            return unavailable(rawKey: token.key, reason: "invalid semantic key")
        }
        let arguments = token.arguments.map { argument -> LocalizedCopyArgument in
            switch argument {
            case .userText(let value): .userText(value)
            case .contentID(let value): .contentID(value)
            case .integer(let value): .integer(value)
            case .decimal(let value): .decimal(value)
            }
        }
        return resolve(LocalizedCopyToken(key: key, arguments: arguments))
    }

    /// Prologue opener tokens carry a stable `SchoolRegionID` as a content ID. The iOS layer
    /// resolves that ID through the existing setup-region catalog before formatting the sentence;
    /// the raw persisted Korean region never reaches the String Catalog template.
    public func resolve(_ descriptor: PrologueCopyDescriptor, regionName: String? = nil) -> String {
        guard let key = GameCopyKey(coreToken: descriptor.openerToken) else {
            return unavailable(rawKey: descriptor.openerToken.key, reason: "invalid prologue key")
        }

        let arguments: [LocalizedCopyArgument]
        if descriptor.variant == .fallback {
            arguments = []
        } else {
            guard let regionName else {
                return unavailable(rawKey: descriptor.openerToken.key, reason: "missing prologue region name")
            }
            arguments = descriptor.openerToken.arguments.map { argument -> LocalizedCopyArgument in
                switch argument {
                case .contentID: .userText(regionName)
                case .userText(let value): .userText(value)
                case .integer(let value): .integer(value)
                case .decimal(let value): .decimal(value)
                }
            }
        }
        return resolve(LocalizedCopyToken(key: key, arguments: arguments))
    }

    /// Exposed for focused tests and the Node-side schema checker. It deliberately describes
    /// format placeholders, not interpolation syntax or Korean source text.
    public static func placeholderKinds(in template: String) -> [String] {
        var placeholders: [(position: Int?, kind: String)] = []
        let characters = Array(template)
        var index = 0
        while index < characters.count {
            guard characters[index] == "%" else {
                index += 1
                continue
            }
            if index + 1 < characters.count, characters[index + 1] == "%" {
                index += 2
                continue
            }

            var cursor = index + 1
            let positionStart = cursor
            while cursor < characters.count, characters[cursor].isNumber { cursor += 1 }
            let position: Int?
            if cursor < characters.count, characters[cursor] == "$",
               let parsed = Int(String(characters[positionStart..<cursor])) {
                position = parsed
                cursor += 1
            } else {
                position = nil
                cursor = positionStart
            }
            while cursor < characters.count, "-+ #0".contains(characters[cursor]) { cursor += 1 }
            while cursor < characters.count, characters[cursor].isNumber { cursor += 1 }
            if cursor < characters.count, characters[cursor] == "." {
                cursor += 1
                while cursor < characters.count, characters[cursor].isNumber { cursor += 1 }
            }
            if cursor + 1 < characters.count,
               characters[cursor] == "l", characters[cursor + 1] == "l" {
                cursor += 2
            } else if cursor < characters.count, characters[cursor] == "l" {
                cursor += 1
            }
            guard cursor < characters.count else { break }
            let kind: String?
            switch characters[cursor] {
            case "@": kind = "string"
            case "d", "i", "u": kind = "integer"
            case "f", "F", "e", "E", "g", "G": kind = "decimal"
            default: kind = nil
            }
            if let kind {
                placeholders.append((position: position, kind: kind))
            }
            index = cursor + 1
        }
        if placeholders.allSatisfy({ $0.position != nil }) {
            return placeholders.sorted { $0.position! < $1.position! }.map(\.kind)
        }
        return placeholders.map(\.kind)
    }

    private func lookup(_ key: GameCopyKey) -> String? {
        if let catalog {
            let value = catalog[language]?[key.rawValue]
            return value.flatMap { $0.isEmpty ? nil : $0 }
        }

        guard let bundle, let path = bundle.path(forResource: language.rawValue, ofType: "lproj"),
              let localizedBundle = Bundle(path: path) else { return nil }
        let value = localizedBundle.localizedString(forKey: key.rawValue, value: nil, table: key.table.rawValue)
        guard value != key.rawValue, !value.isEmpty else { return nil }
        return value
    }

    private func unavailable(_ key: GameCopyKey, reason: String) -> String {
        unavailable(rawKey: key.rawValue, reason: reason)
    }

    private func unavailable(rawKey: String, reason: String) -> String {
        switch policy {
        case .strict:
            assertionFailure("Missing iOS localization: \(rawKey) (\(reason))")
        case .releaseSafe:
            break
        }
        return Self.unavailableText
    }
}

private struct GameCopyResolverEnvironmentKey: EnvironmentKey {
    static let defaultValue = GameCopyResolver()
}

extension EnvironmentValues {
    var gameCopyResolver: GameCopyResolver {
        get { self[GameCopyResolverEnvironmentKey.self] }
        set { self[GameCopyResolverEnvironmentKey.self] = newValue }
    }
}

extension GameCopyResolver {
    /// Resolves the versioned reference used by pending notification and return-card plans.
    /// The reference carries only a semantic ID and typed arguments; legacy title/body fields are
    /// intentionally not consulted here.
    func resolve(_ reference: DailyReminder.SemanticCopyReference) -> String {
        resolve(reference.coreToken)
    }
}

/// A small SwiftUI boundary for semantic copy. Views never need to use a Korean source sentence
/// as a String Catalog key, and the same token can be resolved by notifications or tests.
struct GameCopyText: View {
    private let token: LocalizedCopyToken?
    private let verbatimValue: String?
    @Environment(\.gameCopyResolver) private var copyResolver

    init(_ key: GameCopyKey, arguments: [LocalizedCopyArgument] = []) {
        self.token = LocalizedCopyToken(key: key, arguments: arguments)
        self.verbatimValue = nil
    }

    init(token: LocalizedCopyToken) {
        self.token = token
        self.verbatimValue = nil
    }

    init(coreToken: SimulationCore.CopyToken) {
        self.token = GameCopyKey(coreToken: coreToken).map {
            LocalizedCopyToken(
                key: $0,
                arguments: coreToken.arguments.map { argument in
                    switch argument {
                    case .userText(let value): .userText(value)
                    case .contentID(let value): .contentID(value)
                    case .integer(let value): .integer(value)
                    case .decimal(let value): .decimal(value)
                    }
                }
            )
        }
        self.verbatimValue = nil
    }

    /// Used only for user-entered values and legacy dynamic payloads that do not yet have a
    /// stable presentation ID. It does not participate in String Catalog lookup.
    init(verbatim value: String) {
        self.token = nil
        self.verbatimValue = value
    }

    var body: some View {
        if let token {
            Text(verbatim: copyResolver.resolve(token))
        } else {
            Text(verbatim: verbatimValue ?? GameCopyResolver.unavailableText)
        }
    }
}
