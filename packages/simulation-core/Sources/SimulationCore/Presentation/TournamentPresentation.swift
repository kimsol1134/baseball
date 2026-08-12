/// Stable presentation identity for the tournament card.
///
/// `TournamentBracket.Field` remains the raw deterministic source. This catalog deliberately
/// repeats only the authored display identities so clients can localize them without changing
/// field generation, school order, insertion position, or the bracket RNG stream.
public enum TournamentRoundID: String, CaseIterable, Sendable {
    case quarterfinal
    case semifinal
    case final

    public init?(rawRound: String) {
        switch rawRound {
        case "8강": self = .quarterfinal
        case "준결승": self = .semifinal
        case "결승": self = .final
        default: return nil
        }
    }
}

public enum TournamentOpponentSchoolID: String, CaseIterable, Sendable {
    case northernCommerce = "northern-commerce"
    case namhaeInformation = "namhae-information"
    case dongsungTechnical = "dongsung-technical"
    case seoryeong = "seoryeong"
    case centralAthletic = "central-athletic"
    case hanseo = "hanseo"
    case daeyang = "daeyang"
    case cheongam = "cheongam"
    case geumgang = "geumgang"
    case samdo = "samdo"
    case baekpa = "baekpa"
    case unamTechnical = "unam-technical"

    public var rawSchoolName: String {
        switch self {
        case .northernCommerce: "북부상고"
        case .namhaeInformation: "남해정보고"
        case .dongsungTechnical: "동성공고"
        case .seoryeong: "서령고"
        case .centralAthletic: "중앙체고"
        case .hanseo: "한서고"
        case .daeyang: "대양고"
        case .cheongam: "청암고"
        case .geumgang: "금강고"
        case .samdo: "삼도고"
        case .baekpa: "백파고"
        case .unamTechnical: "운암공고"
        }
    }
}

public struct TournamentNameCopyDescriptor: Equatable, Sendable {
    public let chapterNumber: Int
    public let token: CopyToken

    public init(chapterNumber: Int, token: CopyToken) {
        self.chapterNumber = chapterNumber
        self.token = token
    }
}

public struct TournamentRoundCopyDescriptor: Equatable, Sendable {
    public let id: TournamentRoundID
    public let rawValue: String
    public let token: CopyToken

    public init(id: TournamentRoundID, rawValue: String, token: CopyToken) {
        self.id = id
        self.rawValue = rawValue
        self.token = token
    }
}

public struct TournamentOpponentSchoolCopyDescriptor: Equatable, Sendable {
    public let id: TournamentOpponentSchoolID
    public let rawSchoolName: String
    public let token: CopyToken

    public init(
        id: TournamentOpponentSchoolID,
        rawSchoolName: String,
        token: CopyToken
    ) {
        self.id = id
        self.rawSchoolName = rawSchoolName
        self.token = token
    }
}

public enum TournamentPresentationCatalog {
    /// The four existing tournament chapters, in the same chapter order as the raw card.
    public static let tournamentNameDescriptors: [TournamentNameCopyDescriptor] = [2, 4, 6, 8].map {
        TournamentNameCopyDescriptor(chapterNumber: $0, token: .tournamentName(chapterNumber: $0))
    }

    /// Only the three round labels emitted by `TournamentBracket.Field` are covered.
    public static let roundDescriptors: [TournamentRoundCopyDescriptor] = [
        TournamentRoundCopyDescriptor(id: .quarterfinal, rawValue: "8강", token: .tournamentRoundName(.quarterfinal)),
        TournamentRoundCopyDescriptor(id: .semifinal, rawValue: "준결승", token: .tournamentRoundName(.semifinal)),
        TournamentRoundCopyDescriptor(id: .final, rawValue: "결승", token: .tournamentRoundName(.final)),
    ]

    /// Exactly the twelve raw fictional schools in `TournamentBracket`'s existing pool.
    public static let opponentSchoolDescriptors: [TournamentOpponentSchoolCopyDescriptor] =
        TournamentOpponentSchoolID.allCases.map {
            TournamentOpponentSchoolCopyDescriptor(
                id: $0,
                rawSchoolName: $0.rawSchoolName,
                token: .tournamentOpponentSchoolName($0)
            )
        }

    public static func tournamentNameDescriptor(for chapterNumber: Int) -> TournamentNameCopyDescriptor? {
        tournamentNameDescriptors.first { $0.chapterNumber == chapterNumber }
    }

    public static func roundDescriptor(for rawRound: String) -> TournamentRoundCopyDescriptor? {
        roundDescriptors.first { $0.rawValue == rawRound }
    }

    public static func opponentSchoolDescriptor(for rawSchoolName: String) -> TournamentOpponentSchoolCopyDescriptor? {
        opponentSchoolDescriptors.first { $0.rawSchoolName == rawSchoolName }
    }
}

public extension PresentationCopyKey {
    static func tournamentName(chapterNumber: Int) -> String {
        stableID(family: .tournament, id: "chapter-\(chapterNumber)", slot: "name")
    }

    static func tournamentRoundName(_ round: TournamentRoundID) -> String {
        stableID(family: .tournament, id: "round.\(round.rawValue)", slot: "name")
    }

    static func tournamentOpponentSchoolName(_ school: TournamentOpponentSchoolID) -> String {
        stableID(family: .tournament, id: "school.\(school.rawValue)", slot: "name")
    }
}

public extension CopyToken {
    static func tournamentName(chapterNumber: Int) -> CopyToken {
        CopyToken(key: PresentationCopyKey.tournamentName(chapterNumber: chapterNumber))
    }

    static func tournamentRoundName(_ round: TournamentRoundID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.tournamentRoundName(round))
    }

    static func tournamentOpponentSchoolName(_ school: TournamentOpponentSchoolID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.tournamentOpponentSchoolName(school))
    }
}
