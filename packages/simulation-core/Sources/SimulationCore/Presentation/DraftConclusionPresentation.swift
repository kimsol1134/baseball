import Foundation

/// Stable presentation slots used by the high-school conclusion screens.
///
/// These descriptors deliberately contain no rendered English and are not Codable. They let an
/// app localize the conclusion without adding presentation fields to DraftResultSnapshot,
/// DraftTeamSnapshot, ChronicleEntry, or any other simulation payload.
public enum DraftConclusionFieldID: String, CaseIterable, Sendable {
    case projectedRange = "projected-range"
    case summary
    case firstSeasonGoal = "first-season-goal"
    case evaluationBreakdown = "evaluation-breakdown"
}

public enum DraftTeamConclusionFieldID: String, CaseIterable, Sendable {
    case name
    case developmentPlan = "development-plan"
    case positionCompetitor = "position-competitor"
    case proCoach = "pro-coach"
    case competitorProfile = "competitor-profile"
    case competitorRecord = "competitor-record"
    case coachProfile = "coach-profile"
    case coachRecord = "coach-record"
}

/// Chronicle stages are stored as Korean strings for save compatibility. This is the semantic
/// inventory used when a known producer is projected at the display boundary.
public enum ChronicleProducerID: String, CaseIterable, Sendable {
    case schoolAdmission = "school-admission"
    case personalityCrystallized = "personality-crystallized"
    case personalityChanged = "personality-changed"
    case awakening
    case nickname
    case importantGame = "important-game"
    case gameGrowth = "game-growth"
    case chapterGoal = "chapter-goal"
    case draft
    case pledge
    case bloom
    case proStart = "pro-start"
}

public struct DraftConclusionFieldDescriptor: Equatable, Sendable {
    public let id: DraftConclusionFieldID
    public let token: CopyToken

    public init(id: DraftConclusionFieldID) {
        self.id = id
        token = .draftConclusionField(id: id)
    }
}

public struct DraftTeamConclusionFieldDescriptor: Equatable, Sendable {
    public let teamID: String
    public let field: DraftTeamConclusionFieldID
    public let rawValue: String
    public let token: CopyToken

    public init(teamID: String, field: DraftTeamConclusionFieldID, rawValue: String) {
        self.teamID = teamID
        self.field = field
        self.rawValue = rawValue
        token = .draftTeamConclusionField(teamID: teamID, field: field)
    }
}

public struct PersonalityPresentationDescriptor: Equatable, Sendable {
    public let trait: PersonalityTrait
    public let rawTitle: String
    public let rawScoutLine: String
    public let titleToken: CopyToken
    public let scoutLineToken: CopyToken

    public init(
        trait: PersonalityTrait,
        rawTitle: String,
        rawScoutLine: String
    ) {
        self.trait = trait
        self.rawTitle = rawTitle
        self.rawScoutLine = rawScoutLine
        titleToken = .personalityTitle(trait)
        scoutLineToken = .personalityScoutLine(trait)
    }
}

public struct MemoryPresentationDescriptor: Equatable, Sendable {
    public let id: MemoryCardID
    public let titleToken: CopyToken
    public let detailToken: CopyToken

    public init(id: MemoryCardID) {
        self.id = id
        titleToken = .memoryTitle(memoryID: id)
        detailToken = .memoryDetail(memoryID: id)
    }
}

public struct SignatureLegacyPresentationDescriptor: Equatable, Sendable {
    public let id: CareerSignatureLegacyID
    public let titleToken: CopyToken
    public let detailToken: CopyToken
    public let evidenceToken: CopyToken

    public init(id: CareerSignatureLegacyID) {
        self.id = id
        titleToken = .signatureLegacyTitle(id: id)
        detailToken = .signatureLegacyDetail(id: id)
        evidenceToken = .signatureLegacyEvidence(id: id)
    }
}

public struct ChronicleProducerPresentationDescriptor: Equatable, Sendable {
    public let id: ChronicleProducerID
    public let token: CopyToken

    public init(id: ChronicleProducerID) {
        self.id = id
        token = .chronicleProducer(id: id)
    }
}

public enum DraftConclusionPresentationCatalog {
    public static let fieldDescriptors: [DraftConclusionFieldDescriptor] =
        DraftConclusionFieldID.allCases.map(DraftConclusionFieldDescriptor.init)

    public static let teamFieldDescriptors: [DraftTeamConclusionFieldDescriptor] =
        HighSchoolCareerEngine.teams.flatMap { team in
            DraftTeamConclusionFieldID.allCases.compactMap { field in
                guard let rawValue = rawValue(for: team, field: field) else { return nil }
                return DraftTeamConclusionFieldDescriptor(
                    teamID: team.id,
                    field: field,
                    rawValue: rawValue
                )
            }
        }

    public static let personalityDescriptors: [PersonalityPresentationDescriptor] =
        PersonalityTrait.allCases.compactMap { trait in
            guard let personality = personality(for: trait) else { return nil }
            return PersonalityPresentationDescriptor(
                trait: trait,
                rawTitle: personality.title,
                rawScoutLine: personality.scoutLine
            )
        }

    public static let memoryDescriptors: [MemoryPresentationDescriptor] =
        MemoryCardID.allCases.map(MemoryPresentationDescriptor.init)

    public static let signatureLegacyDescriptors: [SignatureLegacyPresentationDescriptor] =
        CareerSignatureLegacyID.allCases.map(SignatureLegacyPresentationDescriptor.init)

    public static let chronicleProducerDescriptors: [ChronicleProducerPresentationDescriptor] =
        ChronicleProducerID.allCases.map(ChronicleProducerPresentationDescriptor.init)

    /// All conclusion keys are explicit inventory metadata. The order has no simulation meaning.
    public static let semanticKeys: [String] =
        fieldDescriptors.map(\.token.key)
            + teamFieldDescriptors.map(\.token.key)
            + personalityDescriptors.flatMap { [$0.titleToken.key, $0.scoutLineToken.key] }
            + memoryDescriptors.flatMap { [$0.titleToken.key, $0.detailToken.key] }
            + signatureLegacyDescriptors.flatMap {
                [$0.titleToken.key, $0.detailToken.key, $0.evidenceToken.key]
            }
            + chronicleProducerDescriptors.map(\.token.key)

    public static func teamFieldDescriptor(
        teamID: String,
        field: DraftTeamConclusionFieldID
    ) -> DraftTeamConclusionFieldDescriptor? {
        teamFieldDescriptors.first { $0.teamID == teamID && $0.field == field }
    }

    public static func personalityDescriptor(
        for trait: PersonalityTrait
    ) -> PersonalityPresentationDescriptor? {
        personalityDescriptors.first { $0.trait == trait }
    }

    private static func rawValue(
        for team: DraftTeamSnapshot,
        field: DraftTeamConclusionFieldID
    ) -> String? {
        switch field {
        case .name: team.name
        case .developmentPlan: team.developmentPlan
        case .positionCompetitor: team.positionCompetitor
        case .proCoach: team.proCoach
        case .competitorProfile: team.competitorProfile
        case .competitorRecord: team.competitorRecord
        case .coachProfile: team.coachProfile
        case .coachRecord: team.coachRecord
        }
    }

    private static func personality(for trait: PersonalityTrait) -> Personality? {
        switch trait {
        case .closer: PersonalityRules.personality(listen: 0, explain: 0, challenge: 5)
        case .anchor: PersonalityRules.personality(listen: 5, explain: 0, challenge: 0)
        case .tactician: PersonalityRules.personality(listen: 0, explain: 5, challenge: 0)
        case .opener: PersonalityRules.personality(listen: 2, explain: 2, challenge: 1)
        }
    }
}

public extension PresentationCopyKey {
    static func draftConclusionField(id: DraftConclusionFieldID) -> String {
        stableID(family: .draftResult, id: id.rawValue, slot: "value")
    }

    static func draftTeamConclusionField(
        teamID: String,
        field: DraftTeamConclusionFieldID
    ) -> String {
        stableID(family: .draftTeam, id: teamID, slot: field.rawValue)
    }

    static func personalityTitle(_ trait: PersonalityTrait) -> String {
        stableID(family: .personality, id: trait.rawValue, slot: "title")
    }

    static func personalityScoutLine(_ trait: PersonalityTrait) -> String {
        stableID(family: .personality, id: trait.rawValue, slot: "scout-line")
    }

    static func memoryDetail(memoryID: MemoryCardID) -> String {
        stableID(family: .memory, id: memoryID.rawValue, slot: "detail")
    }

    static func signatureLegacyDetail(id: CareerSignatureLegacyID) -> String {
        stableID(family: .signatureLegacy, id: id.rawValue, slot: "detail")
    }

    static func signatureLegacyEvidence(id: CareerSignatureLegacyID) -> String {
        stableID(family: .signatureLegacy, id: id.rawValue, slot: "evidence")
    }

    static func chronicleProducer(id: ChronicleProducerID) -> String {
        stableID(family: .chronicle, id: id.rawValue, slot: "template")
    }
}

public extension CopyToken {
    static func draftConclusionField(id: DraftConclusionFieldID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.draftConclusionField(id: id))
    }

    static func draftTeamConclusionField(
        teamID: String,
        field: DraftTeamConclusionFieldID
    ) -> CopyToken {
        CopyToken(key: PresentationCopyKey.draftTeamConclusionField(teamID: teamID, field: field))
    }

    static func personalityTitle(_ trait: PersonalityTrait) -> CopyToken {
        CopyToken(key: PresentationCopyKey.personalityTitle(trait))
    }

    static func personalityScoutLine(_ trait: PersonalityTrait) -> CopyToken {
        CopyToken(key: PresentationCopyKey.personalityScoutLine(trait))
    }

    static func memoryDetail(memoryID: MemoryCardID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.memoryDetail(memoryID: memoryID))
    }

    static func signatureLegacyDetail(id: CareerSignatureLegacyID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.signatureLegacyDetail(id: id))
    }

    static func signatureLegacyEvidence(id: CareerSignatureLegacyID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.signatureLegacyEvidence(id: id))
    }

    static func chronicleProducer(id: ChronicleProducerID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.chronicleProducer(id: id))
    }
}
