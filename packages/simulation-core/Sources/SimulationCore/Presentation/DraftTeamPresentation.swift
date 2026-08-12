import Foundation

/// Presentation descriptors for the ten fictional draft teams. The raw team snapshots remain
/// the simulation source; this catalog only supplies stable IDs and localized-copy tokens.
public struct DraftTeamPresentationDescriptor: Equatable, Sendable {
    public let teamID: String
    public let rawTeamName: String
    public let token: CopyToken

    public init(teamID: String, rawTeamName: String, token: CopyToken) {
        self.teamID = teamID
        self.rawTeamName = rawTeamName
        self.token = token
    }
}

public enum DraftTeamPresentationCatalog {
    public static let descriptors: [DraftTeamPresentationDescriptor] =
        HighSchoolCareerEngine.teams.map {
            DraftTeamPresentationDescriptor(
                teamID: $0.id,
                rawTeamName: $0.name,
                token: $0.nameCopyToken
            )
        }

    public static func descriptor(for teamID: String) -> DraftTeamPresentationDescriptor? {
        descriptors.first { $0.teamID == teamID }
    }
}

/// The five authored forecast bands. The Korean value is frozen here only to let the legacy
/// `DraftForecastSnapshot.band` field remain byte-for-byte unchanged.
public enum DraftForecastBandID: String, CaseIterable, Sendable {
    case firstRound = "first-round"
    case roundsTwoToThree = "rounds-two-to-three"
    case roundsFourToSix = "rounds-four-to-six"
    case borderline = "borderline"
    case outside = "outside"
}

public struct DraftForecastBandPresentationDescriptor: Equatable, Sendable {
    public let id: DraftForecastBandID
    public let koreanValue: String
    public let token: CopyToken

    public init(id: DraftForecastBandID, koreanValue: String, token: CopyToken) {
        self.id = id
        self.koreanValue = koreanValue
        self.token = token
    }
}

public struct DraftForecastPresentationIdentity: Equatable, Sendable {
    public let bandID: DraftForecastBandID
    public let interestedTeamID: String

    public init(bandID: DraftForecastBandID, interestedTeamID: String) {
        self.bandID = bandID
        self.interestedTeamID = interestedTeamID
    }
}

public enum DraftForecastPresentationCatalog {
    public static let bandDescriptors: [DraftForecastBandPresentationDescriptor] = [
        .init(id: .firstRound, koreanValue: "1라운드 예상", token: .draftForecastBand(id: .firstRound)),
        .init(id: .roundsTwoToThree, koreanValue: "2~3라운드 예상", token: .draftForecastBand(id: .roundsTwoToThree)),
        .init(id: .roundsFourToSix, koreanValue: "4~6라운드 예상", token: .draftForecastBand(id: .roundsFourToSix)),
        .init(id: .borderline, koreanValue: "당락 경계 — 남은 경기가 정한다", token: .draftForecastBand(id: .borderline)),
        .init(id: .outside, koreanValue: "미지명권 — 아직 명단 밖", token: .draftForecastBand(id: .outside)),
    ]

    public static func descriptor(for id: DraftForecastBandID) -> DraftForecastBandPresentationDescriptor {
        bandDescriptors[id.ordinal]
    }

    public static func bandID(score: Int, threshold: Int) -> DraftForecastBandID {
        score >= 78 ? .firstRound
            : score >= 70 ? .roundsTwoToThree
            : score >= threshold + 5 ? .roundsFourToSix
            : score >= threshold - 5 ? .borderline
            : .outside
    }
}

public extension DraftForecastBandID {
    var ordinal: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

public extension PresentationCopyKey {
    static func draftForecastBand(id: DraftForecastBandID) -> String {
        "content.draft-forecast.band.\(id.rawValue)"
    }
}

public extension CopyToken {
    static func draftForecastBand(id: DraftForecastBandID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.draftForecastBand(id: id))
    }
}
