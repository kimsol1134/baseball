import Foundation

public enum PitchType: String, Codable, CaseIterable, Sendable {
    case fourSeam = "four_seam"
    case slider
    case curveball
    case changeup
}

public enum PitchIntensity: String, Codable, CaseIterable, Sendable {
    case controlled
    case normal
    case maxEffort = "max_effort"
}

public enum PitchUsageRole: String, Codable, CaseIterable, Sendable {
    case primary
    case secondary
    case development
}

/// Which side of the plate the batter hits from. `switchHitter` always takes the platoon-favored
/// box (bats opposite the pitcher's hand). Defaults to `.right` on decode so pre-platoon saves and
/// RPC payloads — which carry no `batSide` — load as a right-handed hitter unchanged.
public enum BatSide: String, Codable, CaseIterable, Sendable {
    case right
    case left
    case switchHitter = "switch"
}

public struct PitchProfileSnapshot: Codable, Equatable, Sendable {
    public let pitchType: PitchType
    public let role: PitchUsageRole
    public let velocityTenthsKPH: Int
    public let control: Int
    public let command: Int
    public let movement: Int
    public let whiff: Int
    public let weakContact: Int
    public let fatigueCost: Int

    public init(
        pitchType: PitchType,
        role: PitchUsageRole,
        velocityTenthsKPH: Int,
        control: Int,
        command: Int,
        movement: Int,
        whiff: Int,
        weakContact: Int,
        fatigueCost: Int
    ) {
        self.pitchType = pitchType
        self.role = role
        self.velocityTenthsKPH = velocityTenthsKPH
        self.control = control
        self.command = command
        self.movement = movement
        self.whiff = whiff
        self.weakContact = weakContact
        self.fatigueCost = fatigueCost
    }
}

public struct PitchZone: Codable, Equatable, Sendable {
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
}

public struct PitcherSnapshot: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let stuff: Int
    public let command: Int
    public let movement: Int
    public let stamina: Int
    public let pitchProfiles: [PitchProfileSnapshot]?
    /// The arm the pitcher throws with. Drives only the left/right platoon read in `resolvePitch`
    /// and never the recommendation, plan, or preparation token. Defaults to `.right` on decode so
    /// saves/RPC payloads written before platoon existed keep resolving identically.
    public let throwingHand: ThrowingHand

    public init(
        id: String,
        name: String,
        stuff: Int,
        command: Int,
        movement: Int,
        stamina: Int,
        throwingHand: ThrowingHand = .right
    ) {
        self.init(
            id: id,
            name: name,
            stuff: stuff,
            command: command,
            movement: movement,
            stamina: stamina,
            pitchProfiles: nil,
            throwingHand: throwingHand
        )
    }

    public init(
        id: String,
        name: String,
        stuff: Int,
        command: Int,
        movement: Int,
        stamina: Int,
        pitchProfiles: [PitchProfileSnapshot]?,
        throwingHand: ThrowingHand = .right
    ) {
        self.id = id
        self.name = name
        self.stuff = stuff
        self.command = command
        self.movement = movement
        self.stamina = stamina
        self.pitchProfiles = pitchProfiles
        self.throwingHand = throwingHand
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, stuff, command, movement, stamina, pitchProfiles, throwingHand
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        stuff = try container.decode(Int.self, forKey: .stuff)
        command = try container.decode(Int.self, forKey: .command)
        movement = try container.decode(Int.self, forKey: .movement)
        stamina = try container.decode(Int.self, forKey: .stamina)
        pitchProfiles = try container.decodeIfPresent([PitchProfileSnapshot].self, forKey: .pitchProfiles)
        throwingHand = try container.decodeIfPresent(ThrowingHand.self, forKey: .throwingHand) ?? .right
    }

    public func profile(for pitchType: PitchType) -> PitchProfileSnapshot? {
        pitchProfiles?.first { $0.pitchType == pitchType }
    }
}

public struct BatterSnapshot: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let contact: Int
    public let discipline: Int
    public let power: Int
    /// Which box the batter stands in, for the left/right platoon read. Defaults to `.right` on
    /// decode so saves/RPC payloads written before platoon existed load as a right-handed hitter.
    public let batSide: BatSide

    public init(
        id: String,
        name: String,
        contact: Int,
        discipline: Int,
        power: Int,
        batSide: BatSide = .right
    ) {
        self.id = id
        self.name = name
        self.contact = contact
        self.discipline = discipline
        self.power = power
        self.batSide = batSide
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, contact, discipline, power, batSide
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        contact = try container.decode(Int.self, forKey: .contact)
        discipline = try container.decode(Int.self, forKey: .discipline)
        power = try container.decode(Int.self, forKey: .power)
        batSide = try container.decodeIfPresent(BatSide.self, forKey: .batSide) ?? .right
    }
}

public struct CountState: Codable, Equatable, Sendable {
    public let balls: Int
    public let strikes: Int

    public init(balls: Int, strikes: Int) {
        self.balls = balls
        self.strikes = strikes
    }
}

public struct PitchSelection: Codable, Equatable, Sendable {
    public let pitchType: PitchType
    public let zone: PitchZone
    public let intensity: PitchIntensity

    public init(pitchType: PitchType, zone: PitchZone, intensity: PitchIntensity) {
        self.pitchType = pitchType
        self.zone = zone
        self.intensity = intensity
    }
}

public struct SimulatePitchParams: Codable, Equatable, Sendable {
    public let seed: String
    public let pitcher: PitcherSnapshot
    public let batter: BatterSnapshot
    public let count: CountState
    public let fatigue: Int
    public let selection: PitchSelection

    public init(
        seed: String,
        pitcher: PitcherSnapshot,
        batter: BatterSnapshot,
        count: CountState,
        fatigue: Int,
        selection: PitchSelection
    ) {
        self.seed = seed
        self.pitcher = pitcher
        self.batter = batter
        self.count = count
        self.fatigue = fatigue
        self.selection = selection
    }
}

public enum PitchOutcome: String, Codable, CaseIterable, Sendable {
    case ball
    case calledStrike = "called_strike"
    case swingingStrike = "swinging_strike"
    case foul
    case inPlayOut = "in_play_out"
    case single
    case double
    case triple
    case homeRun = "home_run"
    case hitByPitch = "hit_by_pitch"
}

public struct PitchResolvedEvent: Codable, Equatable, Sendable {
    public let eventType: String
    public let seed: String
    public let nextSeed: String
    public let outcome: PitchOutcome
    public let wasInZone: Bool
    public let batterSwung: Bool
    public let executionScore: Int
    public let contactQuality: Int?
    public let reasonCodes: [String]
    public let eventHash: String

    public init(
        seed: String,
        nextSeed: String,
        outcome: PitchOutcome,
        wasInZone: Bool,
        batterSwung: Bool,
        executionScore: Int,
        contactQuality: Int?,
        reasonCodes: [String],
        eventHash: String
    ) {
        self.eventType = "pitch_resolved"
        self.seed = seed
        self.nextSeed = nextSeed
        self.outcome = outcome
        self.wasInZone = wasInZone
        self.batterSwung = batterSwung
        self.executionScore = executionScore
        self.contactQuality = contactQuality
        self.reasonCodes = reasonCodes
        self.eventHash = eventHash
    }
}

public struct PitchDecisionSnapshot: Codable, Equatable, Sendable {
    public let outcome: PitchOutcome
    public let wasInZone: Bool
    public let batterSwung: Bool
    public let executionScore: Int
    public let contactQuality: Int?
    public let shortFeedback: String
    public let detailFeedback: String
    public let accessibilitySummary: String

    public init(
        outcome: PitchOutcome,
        wasInZone: Bool,
        batterSwung: Bool,
        executionScore: Int,
        contactQuality: Int?,
        shortFeedback: String,
        detailFeedback: String,
        accessibilitySummary: String
    ) {
        self.outcome = outcome
        self.wasInZone = wasInZone
        self.batterSwung = batterSwung
        self.executionScore = executionScore
        self.contactQuality = contactQuality
        self.shortFeedback = shortFeedback
        self.detailFeedback = detailFeedback
        self.accessibilitySummary = accessibilitySummary
    }
}

public struct SimulatePitchResult: Codable, Equatable, Sendable {
    public let revision: UInt64
    public let events: [PitchResolvedEvent]
    public let snapshot: PitchDecisionSnapshot

    public init(
        revision: UInt64,
        events: [PitchResolvedEvent],
        snapshot: PitchDecisionSnapshot
    ) {
        self.revision = revision
        self.events = events
        self.snapshot = snapshot
    }
}

public enum SimulationError: Error, Equatable, LocalizedError, Sendable {
    case invalidSeed(String)
    case invalidRating(field: String, value: Int)
    case invalidZone(row: Int, column: Int)
    case invalidCount(balls: Int, strikes: Int)
    case invalidFatigue(Int)
    case invalidPlateAppearance(String)
    case invalidScouting(String)
    case invalidPreparationToken
    case invalidPitchProfile(String)
    case invalidRivalMemory(String)
    case invalidGameState(String)
    case invalidGameLog(String)
    case invalidPitcherLab(String)
    case invalidProCareer(String)

    public var errorDescription: String? {
        switch self {
        case .invalidSeed(let seed):
            return "Seed must be an unsigned 64-bit integer: \(seed)"
        case .invalidRating(let field, let value):
            return "\(field) must be between 20 and 80: \(value)"
        case .invalidZone(let row, let column):
            return "Zone row and column must be between 0 and 2: \(row), \(column)"
        case .invalidCount(let balls, let strikes):
            return "Count is invalid: \(balls)-\(strikes)"
        case .invalidFatigue(let fatigue):
            return "Fatigue must be between 0 and 100: \(fatigue)"
        case .invalidPlateAppearance(let detail):
            return "Plate appearance context is invalid: \(detail)"
        case .invalidScouting(let detail):
            return "Batter scouting is invalid: \(detail)"
        case .invalidPreparationToken:
            return "Pitch preparation token is invalid or stale"
        case .invalidPitchProfile(let detail):
            return "Pitch profile is invalid: \(detail)"
        case .invalidRivalMemory(let detail):
            return "Rival memory is invalid: \(detail)"
        case .invalidGameState(let detail):
            return "Game state is invalid: \(detail)"
        case .invalidGameLog(let detail):
            return "Game log is invalid: \(detail)"
        case .invalidPitcherLab(let detail):
            return "Pitcher Lab state is invalid: \(detail)"
        case .invalidProCareer(let detail):
            return "Pro career state is invalid: \(detail)"
        }
    }
}
