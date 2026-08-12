import Foundation

/// Stable IDs for the twenty surname components used by the generated prospect board.
public enum ProspectSurnameComponentID: String, CaseIterable, Sendable {
    case gang
    case go
    case gwon
    case gim
    case doSurname = "do"
    case mun
    case bak
    case bae
    case seo
    case sin
    case an
    case yu
    case i
    case im
    case jeong
    case jo
    case cha
    case choe
    case han
    case hwang
}

/// Stable IDs for the twenty given-name components used by the generated prospect board.
public enum ProspectGivenNameComponentID: String, CaseIterable, Sendable {
    case dohyeon
    case minjae
    case seojun
    case yejun
    case siu
    case hajun
    case jiho
    case eunchan
    case junseo
    case geonwoo
    case hyeonbin
    case taeyun
    case jaemin
    case seongmin
    case gyuhyeon
    case dongju
    case chanyeong
    case ujin
    case seokhyeon
    case yeongung
}

/// Stable IDs for the ten scout-tag variants used by generated prospects.
public enum ProspectScoutTagID: String, CaseIterable, Sendable {
    case velocityScout = "velocity-scout"
    case zonePainter = "zone-painter"
    case breakingBallArtist = "breaking-ball-artist"
    case lateBloomingAce = "late-blooming-ace"
    case inningsEater = "innings-eater"
    case pressurePitcher = "pressure-pitcher"
    case knownQuantity = "known-quantity"
    case oneManCarry = "one-man-carry"
    case deception = "deception"
    case comeback = "comeback"
}

public struct ProspectNameComponentCopyDescriptor: Equatable, Sendable {
    public let id: String
    public let koreanValue: String
    public let token: CopyToken

    public init(id: String, koreanValue: String, token: CopyToken) {
        self.id = id
        self.koreanValue = koreanValue
        self.token = token
    }
}

public struct ProspectScoutTagCopyDescriptor: Equatable, Sendable {
    public let id: ProspectScoutTagID
    public let koreanValue: String
    public let token: CopyToken

    public init(id: ProspectScoutTagID, koreanValue: String, token: CopyToken) {
        self.id = id
        self.koreanValue = koreanValue
        self.token = token
    }
}

/// Presentation inventory for the generated board. The ten school descriptors deliberately
/// reuse `TournamentPresentationCatalog` tokens so a fictional school has one English spelling.
public enum ProspectRankingPresentationCatalog {
    public static let surnameDescriptors: [ProspectNameComponentCopyDescriptor] = [
        .init(id: ProspectSurnameComponentID.gang.rawValue, koreanValue: "강", token: .prospectSurnameName(componentID: ProspectSurnameComponentID.gang.rawValue)),
        .init(id: ProspectSurnameComponentID.go.rawValue, koreanValue: "고", token: .prospectSurnameName(componentID: ProspectSurnameComponentID.go.rawValue)),
        .init(id: ProspectSurnameComponentID.gwon.rawValue, koreanValue: "권", token: .prospectSurnameName(componentID: ProspectSurnameComponentID.gwon.rawValue)),
        .init(id: ProspectSurnameComponentID.gim.rawValue, koreanValue: "김", token: .prospectSurnameName(componentID: ProspectSurnameComponentID.gim.rawValue)),
        .init(id: ProspectSurnameComponentID.doSurname.rawValue, koreanValue: "도", token: .prospectSurnameName(componentID: ProspectSurnameComponentID.doSurname.rawValue)),
        .init(id: ProspectSurnameComponentID.mun.rawValue, koreanValue: "문", token: .prospectSurnameName(componentID: ProspectSurnameComponentID.mun.rawValue)),
        .init(id: ProspectSurnameComponentID.bak.rawValue, koreanValue: "박", token: .prospectSurnameName(componentID: ProspectSurnameComponentID.bak.rawValue)),
        .init(id: ProspectSurnameComponentID.bae.rawValue, koreanValue: "배", token: .prospectSurnameName(componentID: ProspectSurnameComponentID.bae.rawValue)),
        .init(id: ProspectSurnameComponentID.seo.rawValue, koreanValue: "서", token: .prospectSurnameName(componentID: ProspectSurnameComponentID.seo.rawValue)),
        .init(id: ProspectSurnameComponentID.sin.rawValue, koreanValue: "신", token: .prospectSurnameName(componentID: ProspectSurnameComponentID.sin.rawValue)),
        .init(id: ProspectSurnameComponentID.an.rawValue, koreanValue: "안", token: .prospectSurnameName(componentID: ProspectSurnameComponentID.an.rawValue)),
        .init(id: ProspectSurnameComponentID.yu.rawValue, koreanValue: "유", token: .prospectSurnameName(componentID: ProspectSurnameComponentID.yu.rawValue)),
        .init(id: ProspectSurnameComponentID.i.rawValue, koreanValue: "이", token: .prospectSurnameName(componentID: ProspectSurnameComponentID.i.rawValue)),
        .init(id: ProspectSurnameComponentID.im.rawValue, koreanValue: "임", token: .prospectSurnameName(componentID: ProspectSurnameComponentID.im.rawValue)),
        .init(id: ProspectSurnameComponentID.jeong.rawValue, koreanValue: "정", token: .prospectSurnameName(componentID: ProspectSurnameComponentID.jeong.rawValue)),
        .init(id: ProspectSurnameComponentID.jo.rawValue, koreanValue: "조", token: .prospectSurnameName(componentID: ProspectSurnameComponentID.jo.rawValue)),
        .init(id: ProspectSurnameComponentID.cha.rawValue, koreanValue: "차", token: .prospectSurnameName(componentID: ProspectSurnameComponentID.cha.rawValue)),
        .init(id: ProspectSurnameComponentID.choe.rawValue, koreanValue: "최", token: .prospectSurnameName(componentID: ProspectSurnameComponentID.choe.rawValue)),
        .init(id: ProspectSurnameComponentID.han.rawValue, koreanValue: "한", token: .prospectSurnameName(componentID: ProspectSurnameComponentID.han.rawValue)),
        .init(id: ProspectSurnameComponentID.hwang.rawValue, koreanValue: "황", token: .prospectSurnameName(componentID: ProspectSurnameComponentID.hwang.rawValue)),
    ]

    public static let givenNameDescriptors: [ProspectNameComponentCopyDescriptor] = [
        .init(id: ProspectGivenNameComponentID.dohyeon.rawValue, koreanValue: "도현", token: .prospectGivenName(componentID: ProspectGivenNameComponentID.dohyeon.rawValue)),
        .init(id: ProspectGivenNameComponentID.minjae.rawValue, koreanValue: "민재", token: .prospectGivenName(componentID: ProspectGivenNameComponentID.minjae.rawValue)),
        .init(id: ProspectGivenNameComponentID.seojun.rawValue, koreanValue: "서준", token: .prospectGivenName(componentID: ProspectGivenNameComponentID.seojun.rawValue)),
        .init(id: ProspectGivenNameComponentID.yejun.rawValue, koreanValue: "예준", token: .prospectGivenName(componentID: ProspectGivenNameComponentID.yejun.rawValue)),
        .init(id: ProspectGivenNameComponentID.siu.rawValue, koreanValue: "시우", token: .prospectGivenName(componentID: ProspectGivenNameComponentID.siu.rawValue)),
        .init(id: ProspectGivenNameComponentID.hajun.rawValue, koreanValue: "하준", token: .prospectGivenName(componentID: ProspectGivenNameComponentID.hajun.rawValue)),
        .init(id: ProspectGivenNameComponentID.jiho.rawValue, koreanValue: "지호", token: .prospectGivenName(componentID: ProspectGivenNameComponentID.jiho.rawValue)),
        .init(id: ProspectGivenNameComponentID.eunchan.rawValue, koreanValue: "은찬", token: .prospectGivenName(componentID: ProspectGivenNameComponentID.eunchan.rawValue)),
        .init(id: ProspectGivenNameComponentID.junseo.rawValue, koreanValue: "준서", token: .prospectGivenName(componentID: ProspectGivenNameComponentID.junseo.rawValue)),
        .init(id: ProspectGivenNameComponentID.geonwoo.rawValue, koreanValue: "건우", token: .prospectGivenName(componentID: ProspectGivenNameComponentID.geonwoo.rawValue)),
        .init(id: ProspectGivenNameComponentID.hyeonbin.rawValue, koreanValue: "현빈", token: .prospectGivenName(componentID: ProspectGivenNameComponentID.hyeonbin.rawValue)),
        .init(id: ProspectGivenNameComponentID.taeyun.rawValue, koreanValue: "태윤", token: .prospectGivenName(componentID: ProspectGivenNameComponentID.taeyun.rawValue)),
        .init(id: ProspectGivenNameComponentID.jaemin.rawValue, koreanValue: "재민", token: .prospectGivenName(componentID: ProspectGivenNameComponentID.jaemin.rawValue)),
        .init(id: ProspectGivenNameComponentID.seongmin.rawValue, koreanValue: "성민", token: .prospectGivenName(componentID: ProspectGivenNameComponentID.seongmin.rawValue)),
        .init(id: ProspectGivenNameComponentID.gyuhyeon.rawValue, koreanValue: "규현", token: .prospectGivenName(componentID: ProspectGivenNameComponentID.gyuhyeon.rawValue)),
        .init(id: ProspectGivenNameComponentID.dongju.rawValue, koreanValue: "동주", token: .prospectGivenName(componentID: ProspectGivenNameComponentID.dongju.rawValue)),
        .init(id: ProspectGivenNameComponentID.chanyeong.rawValue, koreanValue: "찬영", token: .prospectGivenName(componentID: ProspectGivenNameComponentID.chanyeong.rawValue)),
        .init(id: ProspectGivenNameComponentID.ujin.rawValue, koreanValue: "우진", token: .prospectGivenName(componentID: ProspectGivenNameComponentID.ujin.rawValue)),
        .init(id: ProspectGivenNameComponentID.seokhyeon.rawValue, koreanValue: "석현", token: .prospectGivenName(componentID: ProspectGivenNameComponentID.seokhyeon.rawValue)),
        .init(id: ProspectGivenNameComponentID.yeongung.rawValue, koreanValue: "영웅", token: .prospectGivenName(componentID: ProspectGivenNameComponentID.yeongung.rawValue)),
    ]

    public static let prospectSchoolIDs: [TournamentOpponentSchoolID] = [
        .northernCommerce, .namhaeInformation, .dongsungTechnical, .seoryeong,
        .centralAthletic, .hanseo, .daeyang, .cheongam, .geumgang, .samdo,
    ]

    public static let schoolDescriptors: [TournamentOpponentSchoolCopyDescriptor] =
        prospectSchoolIDs.compactMap { schoolID in
            TournamentPresentationCatalog.opponentSchoolDescriptor(for: schoolID.rawSchoolName)
        }

    public static let scoutTagDescriptors: [ProspectScoutTagCopyDescriptor] = [
        .init(id: .velocityScout, koreanValue: "최고 구속으로 스카우트 보고서 첫 줄을 차지한 파이어볼러", token: .prospectScoutTag(id: .velocityScout)),
        .init(id: .zonePainter, koreanValue: "존 네 귀퉁이를 마음대로 쓰는 완성형 제구", token: .prospectScoutTag(id: .zonePainter)),
        .init(id: .breakingBallArtist, koreanValue: "각이 다른 종변화구 — 헛스윙 유도 1위", token: .prospectScoutTag(id: .breakingBallArtist)),
        .init(id: .lateBloomingAce, koreanValue: "3학년 여름에 만개한 늦깎이 에이스", token: .prospectScoutTag(id: .lateBloomingAce)),
        .init(id: .inningsEater, koreanValue: "이닝을 먹는 체력 — 완투가 기본", token: .prospectScoutTag(id: .inningsEater)),
        .init(id: .pressurePitcher, koreanValue: "위기에서만 구속이 오르는 승부사", token: .prospectScoutTag(id: .pressurePitcher)),
        .init(id: .knownQuantity, koreanValue: "중학 시절부터 이름난 엘리트 코스", token: .prospectScoutTag(id: .knownQuantity)),
        .init(id: .oneManCarry, koreanValue: "무명 학교에서 혼자 팀을 끌어올린 화제의 투수", token: .prospectScoutTag(id: .oneManCarry)),
        .init(id: .deception, koreanValue: "타자들이 타이밍을 못 잡는 디셉션", token: .prospectScoutTag(id: .deception)),
        .init(id: .comeback, koreanValue: "부상 복귀 후 더 강해져 돌아온 재활의 표본", token: .prospectScoutTag(id: .comeback)),
    ]

    public static func surnameDescriptor(for id: ProspectSurnameComponentID) -> ProspectNameComponentCopyDescriptor {
        surnameDescriptors[id.ordinal]
    }

    public static func givenNameDescriptor(for id: ProspectGivenNameComponentID) -> ProspectNameComponentCopyDescriptor {
        givenNameDescriptors[id.ordinal]
    }

    public static func schoolDescriptor(for id: TournamentOpponentSchoolID) -> TournamentOpponentSchoolCopyDescriptor? {
        schoolDescriptors.first { $0.id == id }
    }

    public static func scoutTagDescriptor(for id: ProspectScoutTagID) -> ProspectScoutTagCopyDescriptor {
        scoutTagDescriptors[id.ordinal]
    }
}

public extension ProspectSurnameComponentID {
    var ordinal: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

public extension ProspectGivenNameComponentID {
    var ordinal: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

public extension ProspectScoutTagID {
    var ordinal: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

public extension ProspectRanking {
    enum PresentationRole: String, Sendable {
        case player
        case rival
    }

    /// Stable, composable identity for one board entry. `player` carries only the selected school
    /// identity; the user's name remains the raw user-authored value in `Entry.name`.
    struct PresentationIdentity: Equatable, Sendable {
        public let role: PresentationRole
        public let surnameID: ProspectSurnameComponentID?
        public let givenNameID: ProspectGivenNameComponentID?
        public let rivalSchoolID: TournamentOpponentSchoolID?
        public let scoutTagID: ProspectScoutTagID?
        public let selectedSchoolID: SchoolID?
        public let selectedRegion: SchoolRegionID?

        public init(
            role: PresentationRole,
            surnameID: ProspectSurnameComponentID? = nil,
            givenNameID: ProspectGivenNameComponentID? = nil,
            rivalSchoolID: TournamentOpponentSchoolID? = nil,
            scoutTagID: ProspectScoutTagID? = nil,
            selectedSchoolID: SchoolID? = nil,
            selectedRegion: SchoolRegionID? = nil
        ) {
            self.role = role
            self.surnameID = surnameID
            self.givenNameID = givenNameID
            self.rivalSchoolID = rivalSchoolID
            self.scoutTagID = scoutTagID
            self.selectedSchoolID = selectedSchoolID
            self.selectedRegion = selectedRegion
        }

        public static func player(
            schoolID: SchoolID? = nil,
            region: SchoolRegionID? = nil
        ) -> Self {
            .init(role: .player, selectedSchoolID: schoolID, selectedRegion: region)
        }

        public static func rival(
            surnameID: ProspectSurnameComponentID,
            givenNameID: ProspectGivenNameComponentID,
            schoolID: TournamentOpponentSchoolID,
            scoutTagID: ProspectScoutTagID
        ) -> Self {
            .init(
                role: .rival,
                surnameID: surnameID,
                givenNameID: givenNameID,
                rivalSchoolID: schoolID,
                scoutTagID: scoutTagID
            )
        }

        public var isPlayer: Bool { role == .player }

        /// Used only as an ephemeral content argument for the typed news token.
        public var stableID: String {
            switch role {
            case .player:
                "prospect.player"
            case .rival:
                "prospect.rival.\(surnameID?.rawValue ?? "unknown").\(givenNameID?.rawValue ?? "unknown").\(rivalSchoolID?.rawValue ?? "unknown").\(scoutTagID?.rawValue ?? "unknown")"
            }
        }

        public var koreanFullName: String? {
            guard let surnameID, let givenNameID else { return nil }
            return ProspectRankingPresentationCatalog.surnameDescriptor(for: surnameID).koreanValue
                + ProspectRankingPresentationCatalog.givenNameDescriptor(for: givenNameID).koreanValue
        }
    }
}

public extension PresentationCopyKey {
    static func prospectSurnameName(componentID: String) -> String {
        "content.prospect-name.surname.\(componentID)"
    }

    static func prospectGivenName(componentID: String) -> String {
        "content.prospect-name.given.\(componentID)"
    }

    static func prospectScoutTag(id: ProspectScoutTagID) -> String {
        "content.prospect-tag.\(id.rawValue)"
    }
}

public extension CopyToken {
    static func prospectSurnameName(componentID: String) -> CopyToken {
        CopyToken(key: PresentationCopyKey.prospectSurnameName(componentID: componentID))
    }

    static func prospectGivenName(componentID: String) -> CopyToken {
        CopyToken(key: PresentationCopyKey.prospectGivenName(componentID: componentID))
    }

    static func prospectScoutTag(id: ProspectScoutTagID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.prospectScoutTag(id: id))
    }
}
