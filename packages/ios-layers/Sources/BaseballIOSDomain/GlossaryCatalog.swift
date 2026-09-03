import Foundation

public struct GlossaryTerm: Equatable, Sendable, Identifiable {
    public let id: String

    public init(id: String) {
        self.id = id
    }

    public var nameKey: String { "content.glossary.\(id).name" }
    public var definitionKey: String { "content.glossary.\(id).definition" }
}

public struct GlossaryMatch: Equatable, Sendable {
    public let id: String
    public let location: Int
    public let length: Int
}

/// Player-facing baseball terms. Display names live in GameContent so ko/en/ja stay in one catalog.
public enum GlossaryCatalog {
    public static let terms: [GlossaryTerm] = [
        .init(id: "stuff"),
        .init(id: "command"),
        .init(id: "movement"),
        .init(id: "stamina"),
        .init(id: "fatigue"),
        .init(id: "manager-faith"),
        .init(id: "catcher-chemistry"),
        .init(id: "mastery"),
        .init(id: "talent-wall"),
        .init(id: "baseball-spirit"),
        .init(id: "awakening"),
        .init(id: "lineage"),
        .init(id: "role"),
        .init(id: "qs"),
        .init(id: "era"),
        .init(id: "whip"),
        .init(id: "k9"),
        .init(id: "fip"),
        .init(id: "war"),
        .init(id: "k-percent"),
        .init(id: "bb-percent"),
        .init(id: "replacement-level"),
        .init(id: "platoon"),
        .init(id: "pitcher-lab"),
        .init(id: "season-decision"),
        .init(id: "signing-bonus"),
        .init(id: "club-interest"),
        .init(id: "national-team-call"),
        .init(id: "military-exemption"),
    ]

    public static func term(id: String) -> GlossaryTerm? {
        terms.first { $0.id == id }
    }

    /// First occurrence of each display name. Longer names win overlaps. Latin tokens stay whole words.
    public static func matches(in text: String, names: [String: String]) -> [GlossaryMatch] {
        var candidates: [(id: String, range: Range<String.Index>)] = []
        for term in terms {
            guard let name = names[term.id], !name.isEmpty,
                  let range = firstBoundedMatch(of: name, in: text) else { continue }
            candidates.append((term.id, range))
        }
        candidates.sort { lhs, rhs in
            if lhs.range.lowerBound != rhs.range.lowerBound {
                return lhs.range.lowerBound < rhs.range.lowerBound
            }
            return text.distance(from: lhs.range.lowerBound, to: lhs.range.upperBound)
                > text.distance(from: rhs.range.lowerBound, to: rhs.range.upperBound)
        }
        var accepted: [(id: String, range: Range<String.Index>)] = []
        for candidate in candidates {
            if accepted.contains(where: { overlaps($0.range, candidate.range) }) { continue }
            accepted.append(candidate)
        }
        accepted.sort { $0.range.lowerBound < $1.range.lowerBound }
        return accepted.map { candidate in
            GlossaryMatch(
                id: candidate.id,
                location: text.distance(from: text.startIndex, to: candidate.range.lowerBound),
                length: text.distance(from: candidate.range.lowerBound, to: candidate.range.upperBound)
            )
        }
    }

    public static func range(in text: String, match: GlossaryMatch) -> Range<String.Index>? {
        guard match.location >= 0, match.length > 0 else { return nil }
        let start = text.index(text.startIndex, offsetBy: match.location, limitedBy: text.endIndex)
        let end = start.flatMap { text.index($0, offsetBy: match.length, limitedBy: text.endIndex) }
        guard let start, let end else { return nil }
        return start..<end
    }

    private static func firstBoundedMatch(of name: String, in text: String) -> Range<String.Index>? {
        var search = text.startIndex
        while search < text.endIndex {
            guard let range = text.range(
                of: name,
                options: [.caseInsensitive],
                range: search..<text.endIndex
            ) else { return nil }
            if isBounded(range, in: text) { return range }
            search = range.upperBound
        }
        return nil
    }

    private static func isBounded(_ range: Range<String.Index>, in text: String) -> Bool {
        let token = String(text[range])
        let latin = token.unicodeScalars.contains { scalar in
            CharacterSet.letters.contains(scalar) && scalar.value < 0x80
        }
        guard latin else { return true }
        if range.lowerBound > text.startIndex {
            let previous = text[text.index(before: range.lowerBound)]
            if isASCIILetterOrNumber(previous) { return false }
        }
        if range.upperBound < text.endIndex {
            let next = text[range.upperBound]
            if isASCIILetterOrNumber(next) { return false }
        }
        return true
    }

    private static func isASCIILetterOrNumber(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            (0x30...0x39).contains(scalar.value)
                || (0x41...0x5A).contains(scalar.value)
                || (0x61...0x7A).contains(scalar.value)
        }
    }

    private static func overlaps(_ lhs: Range<String.Index>, _ rhs: Range<String.Index>) -> Bool {
        lhs.overlaps(rhs)
    }
}
