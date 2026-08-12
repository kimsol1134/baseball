/// Stable presentation IDs for the first-run school-selection surface.
///
/// The raw Korean region is a persisted simulation value, not a localization key. These IDs
/// are ephemeral metadata used to select the current language's display copy. They never enter a
/// SchoolSnapshot, save payload, RNG seed, event hash, or analytics event.
public enum SchoolRegionID: String, CaseIterable, Sendable {
    case seoul
    case incheon
    case suwon
    case daejeon
    case gwangju
    case daegu
    case busan
    case changwon
    case ulsan
    case sejong
    case gyeonggi
    case gangwon
    case chungbuk
    case chungnam
    case jeonbuk
    case jeonnam
    case gyeongbuk
    case gyeongnam
    case jeju

    public var ordinal: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    /// The cast pools intentionally rotate through five explicit slots in the existing region
    /// order. The pool index is display metadata only; it is not derived from a person's name.
    public var castPoolIndex: Int {
        ordinal % SchoolSelectionCopyCatalog.castPoolCount
    }

    /// Converts the raw region persisted by the current simulation into a stable semantic ID.
    /// Unknown legacy input follows the engine's existing Seoul fallback without changing the
    /// raw identity stored in the career snapshot.
    public static func from(rawRegion: String) -> Self {
        switch rawRegion {
        case "서울": .seoul
        case "인천": .incheon
        case "수원": .suwon
        case "대전": .daejeon
        case "광주": .gwangju
        case "대구": .daegu
        case "부산": .busan
        case "창원": .changwon
        case "울산": .ulsan
        case "세종": .sejong
        case "경기": .gyeonggi
        case "강원": .gangwon
        case "충북": .chungbuk
        case "충남": .chungnam
        case "전북": .jeonbuk
        case "전남": .jeonnam
        case "경북": .gyeongbuk
        case "경남": .gyeongnam
        case "제주": .jeju
        default: .seoul
        }
    }

    /// Resolves only known persisted region values for presentation paths that must not
    /// reinterpret unknown legacy input as Seoul.
    public static func strictLookup(rawRegion: String) -> Self? {
        switch rawRegion {
        case "서울": .seoul
        case "인천": .incheon
        case "수원": .suwon
        case "대전": .daejeon
        case "광주": .gwangju
        case "대구": .daegu
        case "부산": .busan
        case "창원": .changwon
        case "울산": .ulsan
        case "세종": .sejong
        case "경기": .gyeonggi
        case "강원": .gangwon
        case "충북": .chungbuk
        case "충남": .chungnam
        case "전북": .jeonbuk
        case "전남": .jeonnam
        case "경북": .gyeongbuk
        case "경남": .gyeongnam
        case "제주": .jeju
        default: nil
        }
    }
}

public enum SchoolCastRole: String, CaseIterable, Sendable {
    case coach
    case catcher
}

public enum SchoolAttributeCopySlot: String, CaseIterable, Sendable {
    case philosophy
    case tradeoff
    case coachArchetype = "coach-archetype"
    case catcherArchetype = "catcher-archetype"
}

public struct SchoolRegionalNameCopyDescriptor: Equatable, Sendable {
    public let region: SchoolRegionID
    public let schoolID: SchoolID
    public let token: CopyToken

    public init(region: SchoolRegionID, schoolID: SchoolID, token: CopyToken) {
        self.region = region
        self.schoolID = schoolID
        self.token = token
    }
}

public struct SchoolCastNameCopyDescriptor: Equatable, Sendable {
    public let schoolID: SchoolID
    public let role: SchoolCastRole
    public let poolIndex: Int
    public let token: CopyToken

    public init(schoolID: SchoolID, role: SchoolCastRole, poolIndex: Int, token: CopyToken) {
        self.schoolID = schoolID
        self.role = role
        self.poolIndex = poolIndex
        self.token = token
    }
}

/// A non-regional semantic fallback for legacy snapshots whose raw region is no longer known.
/// The fallback is intentionally separate from the Seoul-specific `schoolName` catalog keys.
public struct SchoolFallbackCopyDescriptor: Equatable, Sendable {
    public let schoolID: SchoolID
    public let role: SchoolCastRole?
    public let token: CopyToken

    public init(schoolID: SchoolID, role: SchoolCastRole? = nil, token: CopyToken) {
        self.schoolID = schoolID
        self.role = role
        self.token = token
    }
}

public struct SchoolAttributeCopyDescriptor: Equatable, Sendable {
    public let schoolID: SchoolID
    public let slot: SchoolAttributeCopySlot
    public let token: CopyToken

    public init(schoolID: SchoolID, slot: SchoolAttributeCopySlot, token: CopyToken) {
        self.schoolID = schoolID
        self.slot = slot
        self.token = token
    }
}

/// All values needed to render one school card. This descriptor contains only ephemeral tokens
/// and stable IDs; the raw `SchoolSnapshot` remains the sole source for game-state callbacks.
public struct SchoolSelectionCopyDescriptor: Equatable, Sendable {
    public let region: SchoolRegionID
    public let schoolID: SchoolID
    public let castPoolIndex: Int
    public let schoolNameToken: CopyToken
    public let philosophyToken: CopyToken
    public let tradeoffToken: CopyToken
    public let coachNameToken: CopyToken
    public let coachArchetypeToken: CopyToken
    public let catcherNameToken: CopyToken
    public let catcherArchetypeToken: CopyToken

    public init(
        region: SchoolRegionID,
        schoolID: SchoolID,
        castPoolIndex: Int,
        schoolNameToken: CopyToken,
        philosophyToken: CopyToken,
        tradeoffToken: CopyToken,
        coachNameToken: CopyToken,
        coachArchetypeToken: CopyToken,
        catcherNameToken: CopyToken,
        catcherArchetypeToken: CopyToken
    ) {
        self.region = region
        self.schoolID = schoolID
        self.castPoolIndex = castPoolIndex
        self.schoolNameToken = schoolNameToken
        self.philosophyToken = philosophyToken
        self.tradeoffToken = tradeoffToken
        self.coachNameToken = coachNameToken
        self.coachArchetypeToken = coachArchetypeToken
        self.catcherNameToken = catcherNameToken
        self.catcherArchetypeToken = catcherArchetypeToken
    }
}

public enum SchoolSelectionCopyCatalog {
    public static let castPoolCount = 5
}

public extension PresentationCopyKey {
    static func schoolFallbackName(schoolID: SchoolID) -> String {
        stableID(
            family: .school,
            id: "fallback.\(schoolID.rawValue)",
            slot: "name"
        )
    }

    static func schoolFallbackCastName(schoolID: SchoolID, role: SchoolCastRole) -> String {
        stableID(
            family: .school,
            id: "fallback.\(schoolID.rawValue).\(role.rawValue)",
            slot: "name"
        )
    }

    static func regionalSchoolName(region: SchoolRegionID, schoolID: SchoolID) -> String {
        stableID(
            family: .school,
            id: "region.\(region.rawValue).\(schoolID.rawValue)",
            slot: "name"
        )
    }

    static func schoolCastName(schoolID: SchoolID, role: SchoolCastRole, poolIndex: Int) -> String {
        precondition((0..<SchoolSelectionCopyCatalog.castPoolCount).contains(poolIndex))
        return stableID(
            family: .school,
            id: "cast.\(schoolID.rawValue).\(role.rawValue).\(poolIndex)",
            slot: "name"
        )
    }

    static func schoolArchetype(schoolID: SchoolID, role: SchoolCastRole) -> String {
        stableID(
            family: .school,
            id: schoolID.rawValue,
            slot: "\(role.rawValue).archetype"
        )
    }
}

public extension CopyToken {
    static func schoolFallbackName(schoolID: SchoolID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.schoolFallbackName(schoolID: schoolID))
    }

    static func schoolFallbackCastName(schoolID: SchoolID, role: SchoolCastRole) -> CopyToken {
        CopyToken(key: PresentationCopyKey.schoolFallbackCastName(schoolID: schoolID, role: role))
    }

    static func regionalSchoolName(region: SchoolRegionID, schoolID: SchoolID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.regionalSchoolName(region: region, schoolID: schoolID))
    }

    static func schoolCastName(schoolID: SchoolID, role: SchoolCastRole, poolIndex: Int) -> CopyToken {
        CopyToken(key: PresentationCopyKey.schoolCastName(schoolID: schoolID, role: role, poolIndex: poolIndex))
    }

    static func schoolArchetype(schoolID: SchoolID, role: SchoolCastRole) -> CopyToken {
        CopyToken(key: PresentationCopyKey.schoolArchetype(schoolID: schoolID, role: role))
    }

    static func schoolSelectionDescriptor(
        rawRegion: String,
        schoolID: SchoolID
    ) -> SchoolSelectionCopyDescriptor {
        schoolSelectionDescriptor(region: SchoolRegionID.from(rawRegion: rawRegion), schoolID: schoolID)
    }

    static func schoolSelectionDescriptor(
        region: SchoolRegionID,
        schoolID: SchoolID
    ) -> SchoolSelectionCopyDescriptor {
        let poolIndex = region.castPoolIndex
        return SchoolSelectionCopyDescriptor(
            region: region,
            schoolID: schoolID,
            castPoolIndex: poolIndex,
            schoolNameToken: .regionalSchoolName(region: region, schoolID: schoolID),
            philosophyToken: .schoolPhilosophy(schoolID: schoolID),
            tradeoffToken: .schoolTradeoff(schoolID: schoolID),
            coachNameToken: .schoolCastName(schoolID: schoolID, role: .coach, poolIndex: poolIndex),
            coachArchetypeToken: .schoolArchetype(schoolID: schoolID, role: .coach),
            catcherNameToken: .schoolCastName(schoolID: schoolID, role: .catcher, poolIndex: poolIndex),
            catcherArchetypeToken: .schoolArchetype(schoolID: schoolID, role: .catcher)
        )
    }

    /// Alias for call sites that want the factory to read like a presentation lookup.
    static func schoolSelection(
        rawRegion: String,
        schoolID: SchoolID
    ) -> SchoolSelectionCopyDescriptor {
        schoolSelectionDescriptor(rawRegion: rawRegion, schoolID: schoolID)
    }

    static let schoolRegionalNameDescriptors: [SchoolRegionalNameCopyDescriptor] =
        SchoolRegionID.allCases.flatMap { region in
            SchoolID.allCases.map { schoolID in
                SchoolRegionalNameCopyDescriptor(
                    region: region,
                    schoolID: schoolID,
                    token: .regionalSchoolName(region: region, schoolID: schoolID)
                )
            }
        }

    static let schoolCastNameDescriptors: [SchoolCastNameCopyDescriptor] =
        SchoolID.allCases.flatMap { schoolID in
            SchoolCastRole.allCases.flatMap { role in
                (0..<SchoolSelectionCopyCatalog.castPoolCount).map { poolIndex in
                    SchoolCastNameCopyDescriptor(
                        schoolID: schoolID,
                        role: role,
                        poolIndex: poolIndex,
                        token: .schoolCastName(schoolID: schoolID, role: role, poolIndex: poolIndex)
                    )
                }
            }
        }

    static let schoolFallbackDescriptors: [SchoolFallbackCopyDescriptor] =
        SchoolID.allCases.flatMap { schoolID in
            [
                SchoolFallbackCopyDescriptor(
                    schoolID: schoolID,
                    token: .schoolFallbackName(schoolID: schoolID)
                ),
                SchoolFallbackCopyDescriptor(
                    schoolID: schoolID,
                    role: .coach,
                    token: .schoolFallbackCastName(schoolID: schoolID, role: .coach)
                ),
                SchoolFallbackCopyDescriptor(
                    schoolID: schoolID,
                    role: .catcher,
                    token: .schoolFallbackCastName(schoolID: schoolID, role: .catcher)
                ),
            ]
        }

    static let schoolPhilosophyDescriptors: [SchoolAttributeCopyDescriptor] =
        SchoolID.allCases.map { schoolID in
            SchoolAttributeCopyDescriptor(
                schoolID: schoolID,
                slot: .philosophy,
                token: .schoolPhilosophy(schoolID: schoolID)
            )
        }

    static let schoolTradeoffDescriptors: [SchoolAttributeCopyDescriptor] =
        SchoolID.allCases.map { schoolID in
            SchoolAttributeCopyDescriptor(
                schoolID: schoolID,
                slot: .tradeoff,
                token: .schoolTradeoff(schoolID: schoolID)
            )
        }

    static let schoolArchetypeDescriptors: [SchoolAttributeCopyDescriptor] =
        SchoolID.allCases.flatMap { schoolID in
            SchoolCastRole.allCases.map { role in
                SchoolAttributeCopyDescriptor(
                    schoolID: schoolID,
                    slot: role == .coach ? .coachArchetype : .catcherArchetype,
                    token: .schoolArchetype(schoolID: schoolID, role: role)
                )
            }
        }

    static let schoolSelectionDescriptors: [SchoolSelectionCopyDescriptor] =
        SchoolRegionID.allCases.flatMap { region in
            SchoolID.allCases.map { schoolID in
                schoolSelectionDescriptor(region: region, schoolID: schoolID)
            }
        }
}
