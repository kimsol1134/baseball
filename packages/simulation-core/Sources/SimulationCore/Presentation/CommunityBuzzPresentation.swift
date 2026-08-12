import Foundation

/// Stable IDs for every authored community-reaction template.
///
/// These IDs are presentation metadata only. The Korean renderer and the iOS resolver both use
/// the same selected ID, so adding a language cannot create a second selection path.
public enum CommunityBuzzReactionTemplateID: String, CaseIterable, Sendable {
    case nicknameQuestion = "nickname-question"
    case nicknameCalling = "nickname-calling"
    case nicknameHighSchoolReal = "nickname-high-school-real"

    case dominantShutoutNeverSawIt = "dominant-shutout-never-saw-it"
    case dominantShutoutLevel = "dominant-shutout-level"
    case dominantShutoutAge = "dominant-shutout-age"
    case dominantShutoutScouts = "dominant-shutout-scouts"

    case shutoutQuiet = "shutout-quiet"
    case shutoutConsistent = "shutout-consistent"
    case shutoutStands = "shutout-stands"

    case wildnessWalks = "wildness-walks"
    case wildnessFrustrated = "wildness-frustrated"
    case wildnessStuff = "wildness-stuff"

    case roughOutingMisses = "rough-outing-misses"
    case roughOutingNextTest = "rough-outing-next-test"
    case roughOutingWatch = "rough-outing-watch"

    case strikeoutShow = "strikeout-show"
    case strikeoutPitch = "strikeout-pitch"
    case strikeoutRhythm = "strikeout-rhythm"

    case generalGrade = "general-grade"
    case generalNextGame = "general-next-game"
    case generalTraining = "general-training"
    case generalPro = "general-pro"
    case generalOffField = "general-off-field"
    case generalHealth = "general-health"
    case generalLastYear = "general-last-year"
    case generalSchool = "general-school"

    public var copyKey: String {
        "content.community-buzz.reaction.\(rawValue)"
    }

    public var isNickname: Bool {
        switch self {
        case .nicknameQuestion, .nicknameCalling, .nicknameHighSchoolReal: true
        default: false
        }
    }
}

/// Stable IDs for the five authored world-news templates.
public enum CommunityBuzzRivalNewsTemplateID: String, CaseIterable, Sendable {
    case regionalFinalShutout = "regional-final-shutout"
    case elbowPain = "elbow-pain"
    case strikeoutRecord = "strikeout-record"
    case velocityGain = "velocity-gain"
    case rotationReset = "rotation-reset"

    public var copyKey: String {
        "content.community-buzz.rival-news.\(rawValue)"
    }
}

public struct CommunityBuzzReactionTemplateDescriptor: Equatable, Sendable {
    public let id: CommunityBuzzReactionTemplateID
    public let token: CopyToken

    public init(id: CommunityBuzzReactionTemplateID) {
        self.id = id
        token = CopyToken(key: id.copyKey)
    }
}

public struct CommunityBuzzRivalNewsTemplateDescriptor: Equatable, Sendable {
    public let id: CommunityBuzzRivalNewsTemplateID
    public let token: CopyToken

    public init(id: CommunityBuzzRivalNewsTemplateID) {
        self.id = id
        token = CopyToken(key: id.copyKey)
    }
}

/// The complete authored CommunityBuzz inventory. This is intentionally explicit and has no
/// language lookup; clients use the IDs to select their own catalog values.
public enum CommunityBuzzPresentationCatalog {
    public static let reactionDescriptors: [CommunityBuzzReactionTemplateDescriptor] =
        CommunityBuzzReactionTemplateID.allCases.map(CommunityBuzzReactionTemplateDescriptor.init)

    public static let rivalNewsDescriptors: [CommunityBuzzRivalNewsTemplateDescriptor] =
        CommunityBuzzRivalNewsTemplateID.allCases.map(CommunityBuzzRivalNewsTemplateDescriptor.init)

    public static let semanticKeys: [String] =
        reactionDescriptors.map(\.token.key) + rivalNewsDescriptors.map(\.token.key)
}

/// Presentation-only identity for the nickname catalog. The title is frozen in Core only so the
/// legacy Korean API can remain byte-for-byte compatible; iOS resolves the title by `id`.
public struct NicknamePresentationDescriptor: Equatable, Sendable {
    public let id: String
    public let koreanTitle: String
    public let titleToken: CopyToken

    public init(id: String, koreanTitle: String) {
        self.id = id
        self.koreanTitle = koreanTitle
        titleToken = .nicknameTitle(nicknameID: id)
    }
}

public enum NicknamePresentationCatalog {
    public static let descriptors: [NicknamePresentationDescriptor] = [
        .init(id: "k-monster", koreanTitle: "삼진 지옥"),
        .init(id: "k-machine", koreanTitle: "탈삼진 머신"),
        .init(id: "k-hunter", koreanTitle: "삼진 사냥꾼"),
        .init(id: "iron-wall", koreanTitle: "철벽"),
        .init(id: "zero", koreanTitle: "제로"),
        .init(id: "flawless", koreanTitle: "무결점"),
        .init(id: "pinpoint", koreanTitle: "핀포인트"),
        .init(id: "untouchable", koreanTitle: "언터처블"),
        .init(id: "nine-k", koreanTitle: "닥터 나인"),
        .init(id: "workhorse", koreanTitle: "철완"),
        .init(id: "wild-thing", koreanTitle: "노 컨트롤"),
        .init(id: "batting-practice", koreanTitle: "배팅볼"),
        .init(id: "rough-diamond", koreanTitle: "미완의 대기"),
    ]

    public static func descriptor(for id: String) -> NicknamePresentationDescriptor? {
        descriptors.first { $0.id == id }
    }
}

/// One selected community reaction. It carries only a stable template ID and typed arguments;
/// it is not Codable and is never part of a save, commitment, event hash, or RNG state.
public struct CommunityBuzzReactionLine: Equatable, Sendable {
    public let templateID: CommunityBuzzReactionTemplateID
    public let nicknameID: String?
    public let numericArgument: Int?

    public init(
        templateID: CommunityBuzzReactionTemplateID,
        nicknameID: String? = nil,
        numericArgument: Int? = nil
    ) {
        self.templateID = templateID
        self.nicknameID = nicknameID
        self.numericArgument = numericArgument
    }

    /// The Core token contains stable IDs and numbers only. The iOS layer may replace those IDs
    /// with localized catalog values before formatting the final sentence.
    public var copyToken: CopyToken {
        var arguments: [CopyArgument] = []
        if let nicknameID { arguments.append(.contentID(nicknameID)) }
        if let numericArgument { arguments.append(.integer(numericArgument)) }
        return CopyToken(key: templateID.copyKey, arguments: arguments)
    }

    /// The frozen Korean renderer used by the old public API and by parity tests.
    public func koreanText(nicknameTitle: String? = nil) -> String {
        let nickname = nicknameTitle
            ?? nicknameID.flatMap { NicknamePresentationCatalog.descriptor(for: $0)?.koreanTitle }
            ?? ""
        let number = numericArgument ?? 0
        switch templateID {
        case .nicknameQuestion:
            return "'\(nickname)' 별명 붙은 거 봤음? 인정할 수밖에 없긴 함"
        case .nicknameCalling:
            return "요즘 다들 '\(nickname)' 하고 부르던데 찰떡이긴 하다"
        case .nicknameHighSchoolReal:
            return "별명이 '\(nickname)'... 고교야구에서 별명 생기면 진짜라는 뜻임"
        case .dominantShutoutNeverSawIt:
            return "오늘 경기 직관했는데 상대 타자들이 공을 아예 못 봄"
        case .dominantShutoutLevel:
            return "무실점에 탈삼진 \(number)개면 고교 레벨이 아닌 듯"
        case .dominantShutoutAge:
            return "저 나이에 저런 공을 던진다고? 더 크면 어떻게 되는 거임?"
        case .dominantShutoutScouts:
            return "스카우트들 오늘 수첩에 뭐라고 적었을지 궁금하다"
        case .shutoutQuiet:
            return "화려하진 않은데 점수를 안 줌. 이런 투수가 무서운 거임"
        case .shutoutConsistent:
            return "오늘도 무실점. 조용히 꾸준한 게 제일 어려운 건데"
        case .shutoutStands:
            return "상대 팀 응원석이 조용해지는 게 보이더라"
        case .wildnessWalks:
            return "공은 좋은데 볼넷 \(number)개는 좀... 제구 잡히는 게 관건일 듯"
        case .wildnessFrustrated:
            return "오늘 볼넷이 너무 많았음. 본인이 제일 답답했을 듯"
        case .wildnessStuff:
            return "구위는 진짜인데 어디로 갈지 모르는 게 함정"
        case .roughOutingMisses:
            return "오늘은 공이 다 몰리더라. 이런 날도 있는 거지"
        case .roughOutingNextTest:
            return "\(number)실점... 다음 경기에서 어떻게 나오는지가 진짜 시험임"
        case .roughOutingWatch:
            return "무너진 날 다음이 진짜라고 생각함. 지켜본다"
        case .strikeoutShow:
            return "탈삼진 \(number)개 ㅎㄷㄷ 2스트라이크 잡히면 끝나는 분위기였음"
        case .strikeoutPitch:
            return "헛스윙 나오는 각도가 다르던데 저거 무슨 공임?"
        case .strikeoutRhythm:
            return "삼진 잡는 리듬이 좋아졌음. 작년이랑 완전 다른 선수 같음"
        case .generalGrade:
            return "저 선수 몇 학년임? 체격 좋아 보이던데"
        case .generalNextGame:
            return "다음 경기 언제임? 직관 가고 싶은데"
        case .generalTraining:
            return "훈련을 어떻게 하길래 저렇게 던짐?"
        case .generalPro:
            return "프로 갈 생각 있는 선수임? 벌써 궁금하네"
        case .generalOffField:
            return "경기 밖에서는 어떤 스타일인지 궁금함"
        case .generalHealth:
            return "부상 없이 쭉 갔으면 좋겠다. 관리 잘 받고 있겠지?"
        case .generalLastYear:
            return "작년에도 이 정도였음? 갑자기 좋아진 것 같은데"
        case .generalSchool:
            return "저 학교 갑자기 왜 이렇게 강해짐?"
        }
    }
}

/// One selected world-news line. The prospect identity is stable and composable; no generated
/// Korean name or school is passed as a user-text argument to the English resolver.
public struct CommunityBuzzRivalNewsLine: Equatable, Sendable {
    public let templateID: CommunityBuzzRivalNewsTemplateID
    public let prospect: ProspectRanking.PresentationIdentity
    public let numericArgument: Int?

    public init(
        templateID: CommunityBuzzRivalNewsTemplateID,
        prospect: ProspectRanking.PresentationIdentity,
        numericArgument: Int? = nil
    ) {
        self.templateID = templateID
        self.prospect = prospect
        self.numericArgument = numericArgument
    }

    public var copyToken: CopyToken {
        var arguments: [CopyArgument] = [
            .contentID(prospect.stableID),
            .contentID(prospect.rivalSchoolID?.rawValue ?? ""),
        ]
        if let numericArgument { arguments.append(.integer(numericArgument)) }
        return CopyToken(key: templateID.copyKey, arguments: arguments)
    }

    /// Exact legacy Korean rendering. Name and school are reconstructed from the same stable
    /// components selected by `ProspectRanking`; no second random draw is involved.
    public func koreanText() -> String {
        let name = prospect.koreanFullName ?? ""
        let school = prospect.rivalSchoolID?.rawSchoolName ?? ""
        let identity = "\(name)(\(school))"
        switch templateID {
        case .regionalFinalShutout:
            return "\(identity)이 지역 대회 결승에서 완봉승. 스카우트석이 가득 찼다는 후문."
        case .elbowPain:
            return "\(identity), 팔꿈치 통증으로 등판을 걸렀다. 관리 실패라는 말과 신중하다는 말이 갈린다."
        case .strikeoutRecord:
            return "\(identity)이 한 경기 탈삼진 \(numericArgument ?? 0)개 — 또래 최고 기록에 다가섰다."
        case .velocityGain:
            return "\(identity)의 구속이 봄보다 \(numericArgument ?? 0)km/h 올랐다. 겨울에 무엇을 했는지 다들 궁금해한다."
        case .rotationReset:
            return "\(identity), 부진 끝에 선발에서 밀렸다. 재조정이 필요해 보인다."
        }
    }
}

public extension PresentationCopyKey {
    static func communityBuzzReaction(templateID: CommunityBuzzReactionTemplateID) -> String {
        templateID.copyKey
    }

    static func communityBuzzRivalNews(templateID: CommunityBuzzRivalNewsTemplateID) -> String {
        templateID.copyKey
    }
}
