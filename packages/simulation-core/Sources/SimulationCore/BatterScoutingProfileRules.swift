import Foundation

/// Deterministic scouting identity derived from a batter archetype and a seed token.
///
/// The live game used to collapse every opponent into two weaknesses (changeup or curveball)
/// and two zone pairs. This table keeps baseball-plausible tendencies per archetype while the
/// hash pick makes two rivals of the same type differ.
public struct BatterScoutingProfile: Equatable, Sendable {
    public let pitchWeakness: PitchType
    public let pitchStrength: PitchType
    public let hotZone: PitchZone
    public let coldZone: PitchZone
    public let reliability: Int
}

/// Nine live archetypes. Matching order follows `ProRivalBatterStats` so the same Korean
/// keywords resolve to the same bucket on every platform that calls this table.
public enum BatterScoutingArchetype: String, CaseIterable, Sendable {
    case slugger
    case homeRun
    case power
    case contact
    case spray
    case patient
    case gap
    case speed
    case clutch
}

public enum BatterScoutingProfileRules {
    public static func archetype(from text: String) -> BatterScoutingArchetype {
        let pairs: [(BatterScoutingArchetype, [String])] = [
            (.slugger, ["거포"]),
            (.homeRun, ["홈런"]),
            (.power, ["파워"]),
            (.contact, ["컨택", "무결점"]),
            (.spray, ["교타", "정확"]),
            (.patient, ["선구안", "출루"]),
            (.gap, ["갭"]),
            (.speed, ["빠른 발", "빠른발", "도루"]),
            (.clutch, ["득점권", "해결사", "중심"])
        ]
        for (archetype, keywords) in pairs where keywords.contains(where: { text.contains($0) }) {
            return archetype
        }
        return .clutch
    }

    public static func profile(
        archetype: BatterScoutingArchetype,
        seedToken: String
    ) -> BatterScoutingProfile {
        let weakness = pick(weaknessCandidates(for: archetype), token: seedToken + "|weakness")
        let strength = pick(
            strengthCandidates(for: archetype, excluding: weakness),
            token: seedToken + "|strength"
        )
        let hot = pick(hotZoneCandidates(for: archetype), token: seedToken + "|hot")
        var cold = pick(
            coldZoneCandidates(for: archetype).filter { $0 != hot },
            token: seedToken + "|cold"
        )
        if cold == hot {
            cold = firstDistinct(from: Self.allZones, besides: hot) ?? PitchZone(row: 2, column: 0)
        }
        let reliability = 42 + Int(StableHash.fnv1a64Value(seedToken + "|reliability") % 17)
        return BatterScoutingProfile(
            pitchWeakness: weakness,
            pitchStrength: strength,
            hotZone: hot,
            coldZone: cold,
            reliability: reliability
        )
    }

    /// Weighted tables. Weights are relative; each archetype keeps 2–3 weakness pitches so
    /// thirty rivals of one type cannot collapse to a single answer.
    static func weaknessCandidates(
        for archetype: BatterScoutingArchetype
    ) -> [(PitchType, Int)] {
        switch archetype {
        case .slugger:
            return [(.changeup, 50), (.curveball, 35), (.slider, 15)]
        case .homeRun:
            return [(.changeup, 45), (.curveball, 40), (.slider, 15)]
        case .power:
            return [(.changeup, 40), (.curveball, 35), (.slider, 25)]
        case .contact:
            return [(.fourSeam, 55), (.slider, 45)]
        case .spray:
            return [(.fourSeam, 50), (.slider, 35), (.changeup, 15)]
        case .patient:
            return [(.curveball, 50), (.changeup, 50)]
        case .gap:
            return [(.slider, 40), (.changeup, 35), (.fourSeam, 25)]
        case .speed:
            return [(.curveball, 40), (.changeup, 35), (.fourSeam, 25)]
        case .clutch:
            return [(.slider, 35), (.curveball, 35), (.changeup, 30)]
        }
    }

    static func strengthCandidates(
        for archetype: BatterScoutingArchetype,
        excluding weakness: PitchType
    ) -> [(PitchType, Int)] {
        let raw: [(PitchType, Int)] = switch archetype {
        case .slugger, .homeRun, .power:
            [(.fourSeam, 55), (.slider, 30), (.curveball, 15)]
        case .contact, .spray:
            [(.slider, 20), (.changeup, 35), (.curveball, 25), (.fourSeam, 20)]
        case .patient:
            [(.fourSeam, 50), (.slider, 35), (.curveball, 15)]
        case .gap:
            [(.fourSeam, 40), (.curveball, 30), (.slider, 20), (.changeup, 10)]
        case .speed:
            [(.fourSeam, 45), (.slider, 35), (.changeup, 20)]
        case .clutch:
            [(.fourSeam, 45), (.slider, 25), (.changeup, 20), (.curveball, 10)]
        }
        let filtered = raw.filter { $0.0 != weakness }
        return filtered.isEmpty ? [(.fourSeam, 1)].filter { $0.0 != weakness } + [(.slider, 1)] : filtered
    }

    static func hotZoneCandidates(for archetype: BatterScoutingArchetype) -> [PitchZone] {
        switch archetype {
        case .slugger, .homeRun, .power:
            return zones([(0, 0), (0, 1), (1, 0), (1, 1)])
        case .contact, .spray:
            return zones([(1, 2), (1, 1), (2, 2), (1, 0)])
        case .patient:
            return zones([(1, 1), (0, 1), (1, 0)])
        case .gap:
            return zones([(1, 2), (2, 2), (1, 0), (0, 2)])
        case .speed:
            return zones([(1, 2), (2, 2), (1, 1)])
        case .clutch:
            return zones([(1, 1), (1, 0), (0, 1), (1, 2)])
        }
    }

    static func coldZoneCandidates(for archetype: BatterScoutingArchetype) -> [PitchZone] {
        switch archetype {
        case .slugger, .homeRun, .power:
            return zones([(2, 2), (2, 1), (0, 2), (2, 0)])
        case .contact, .spray:
            return zones([(0, 0), (0, 1), (2, 0)])
        case .patient:
            return zones([(2, 2), (0, 2), (2, 0), (2, 1)])
        case .gap:
            return zones([(1, 1), (0, 0), (2, 1)])
        case .speed:
            return zones([(0, 0), (0, 1), (2, 0), (0, 2)])
        case .clutch:
            return zones([(2, 2), (2, 0), (0, 2)])
        }
    }

    static let allZones: [PitchZone] = (0..<3).flatMap { row in
        (0..<3).map { PitchZone(row: row, column: $0) }
    }

    private static func zones(_ pairs: [(Int, Int)]) -> [PitchZone] {
        pairs.map { PitchZone(row: $0.0, column: $0.1) }
    }

    private static func pick(_ items: [PitchZone], token: String) -> PitchZone {
        pick(items.map { ($0, 1) }, token: token)
    }

    private static func pick<T>(_ items: [(T, Int)], token: String) -> T {
        let total = items.reduce(0) { $0 + max(0, $1.1) }
        precondition(!items.isEmpty && total > 0, "scouting pick requires a weighted candidate")
        var slot = Int(StableHash.fnv1a64Value(token) % UInt64(total))
        for (item, weight) in items {
            slot -= max(0, weight)
            if slot < 0 { return item }
        }
        return items[0].0
    }

    private static func firstDistinct(from zones: [PitchZone], besides forbidden: PitchZone) -> PitchZone? {
        zones.first { $0 != forbidden }
    }
}
