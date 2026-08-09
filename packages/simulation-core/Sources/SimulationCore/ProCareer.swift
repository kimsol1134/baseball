import Foundation

public enum EntitlementStatus: String, Codable, Sendable { case locked, active }
public enum EntitlementSource: String, Codable, Sendable { case purchase, restore, offlineCache = "offline_cache", development }

public struct ProEntitlementSnapshot: Codable, Equatable, Sendable {
    public let productID: String
    public let status: EntitlementStatus
    public let source: EntitlementSource
    public let verifiedAt: String
    public let offlineValidUntil: String?
    public init(productID: String = "baseball_pro_career", status: EntitlementStatus, source: EntitlementSource, verifiedAt: String, offlineValidUntil: String? = nil) {
        self.productID = productID; self.status = status; self.source = source; self.verifiedAt = verifiedAt; self.offlineValidUntil = offlineValidUntil
    }
}

public enum ProCareerPhase: String, Codable, Sendable {
    case contractOffer = "contract_offer"
    case weeklyPlan = "weekly_plan"
    case seasonDecision = "season_decision"
    case importantGame = "important_game"
    case seasonReview = "season_review"
    case offseasonDecision = "offseason_decision"
    case retirementDecision = "retirement_decision"
    case completed
}

public enum ProLevel: String, Codable, Sendable { case minor, major }
public enum ProRole: String, Codable, Sendable { case starter, longRelief = "long_relief", setup, closer }
public enum ProWeekPlan: String, Codable, CaseIterable, Sendable { case developWeapon = "develop_weapon", refineCommand = "refine_command", buildStamina = "build_stamina", recover, earnTrust = "earn_trust" }
public enum OffseasonDecision: String, Codable, Sendable { case continueCareer = "continue", militaryService = "military_service", freeAgency = "free_agency", retire }

/// 세 주마다 제안되는 프로 시즌 갈림길. 저장에는 안정적인 raw value만 남긴다.
public enum ProSeasonDecisionType: String, Codable, CaseIterable, Sendable {
    case extraBullpen = "extra_bullpen"
    case catcherGamePlan = "catcher_game_plan"
    case roleMeeting = "role_meeting"
    case recordChase = "record_chase"
    case rivalAnalysis = "rival_analysis"
    case seasonFinale = "season_finale"
}

/// 선택을 누르기 전에 그대로 공개할 수 있는 수치 변화다.
///
/// 모든 숫자는 현재 스냅숏에 더해지며 능력·신뢰·피로 범위에서 clamp된다.
/// `roleTarget`만 nil이면 현재 역할을 유지한다.
public struct ProDecisionEffect: Codable, Equatable, Sendable {
    public let stuffDelta: Int
    public let commandDelta: Int
    public let movementDelta: Int
    public let staminaDelta: Int
    public let managerTrustDelta: Int
    public let catcherTrustDelta: Int
    public let fatigueDelta: Int
    public let roleTarget: ProRole?

    public init(
        stuffDelta: Int = 0,
        commandDelta: Int = 0,
        movementDelta: Int = 0,
        staminaDelta: Int = 0,
        managerTrustDelta: Int = 0,
        catcherTrustDelta: Int = 0,
        fatigueDelta: Int = 0,
        roleTarget: ProRole? = nil
    ) {
        self.stuffDelta = stuffDelta
        self.commandDelta = commandDelta
        self.movementDelta = movementDelta
        self.staminaDelta = staminaDelta
        self.managerTrustDelta = managerTrustDelta
        self.catcherTrustDelta = catcherTrustDelta
        self.fatigueDelta = fatigueDelta
        self.roleTarget = roleTarget
    }

    /// UI가 별도 규칙을 다시 만들지 않고 보여 줄 수 있는, 빠짐없는 효과 문장.
    public var summary: String {
        var values: [String] = []
        append(stuffDelta, label: "구위", to: &values)
        append(commandDelta, label: "제구", to: &values)
        append(movementDelta, label: "변화구", to: &values)
        append(staminaDelta, label: "체력", to: &values)
        append(managerTrustDelta, label: "감독의 믿음", to: &values)
        append(catcherTrustDelta, label: "포수와의 호흡", to: &values)
        append(fatigueDelta, label: "피로", to: &values)
        if let roleTarget {
            let role = switch roleTarget {
            case .starter: "선발"
            case .longRelief: "긴 이닝 구원"
            case .setup: "필승조"
            case .closer: "마무리"
            }
            values.append("역할 → \(role)")
        }
        return values.joined(separator: " · ")
    }

    private func append(_ value: Int, label: String, to values: inout [String]) {
        guard value != 0 else { return }
        values.append("\(label) \(value > 0 ? "+" : "")\(value)")
    }
}

public struct ProSeasonDecisionChoice: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let effect: ProDecisionEffect

    public init(id: String, title: String, detail: String, effect: ProDecisionEffect) {
        self.id = id
        self.title = title
        self.detail = detail
        self.effect = effect
    }
}

/// 현재 화면에 열린 시즌 결정. 세 선택지는 생성 시점에 완성되어 그대로 저장된다.
public struct ProSeasonDecision: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let type: ProSeasonDecisionType
    public let season: Int
    public let week: Int
    public let title: String
    public let detail: String
    public let choices: [ProSeasonDecisionChoice]

    public init(id: String, type: ProSeasonDecisionType, season: Int, week: Int, title: String, detail: String, choices: [ProSeasonDecisionChoice]) {
        self.id = id
        self.type = type
        self.season = season
        self.week = week
        self.title = title
        self.detail = detail
        self.choices = choices
    }
}

/// 적용이 끝난 결정을 통산으로 보존한다. 실제 적용한 효과도 함께 남아 과거 선택을 설명한다.
public struct ProDecisionRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String { decisionID }
    public let decisionID: String
    public let type: ProSeasonDecisionType
    public let season: Int
    public let week: Int
    public let choiceID: String
    public let choiceTitle: String
    public let effect: ProDecisionEffect

    public init(decisionID: String, type: ProSeasonDecisionType, season: Int, week: Int, choiceID: String, choiceTitle: String, effect: ProDecisionEffect) {
        self.decisionID = decisionID
        self.type = type
        self.season = season
        self.week = week
        self.choiceID = choiceID
        self.choiceTitle = choiceTitle
        self.effect = effect
    }
}

/// 24주 시즌을 여섯 구간의 서사 아크로 나눈다. 주차에서 파생되며 스냅숏에 노출된다.
public enum ProSeasonSegment: String, Codable, CaseIterable, Sendable {
    case springCamp = "spring_camp"
    case opening
    case firstHalf = "first_half"
    case allStarBreak = "all_star_break"
    case pennantRace = "pennant_race"
    case seasonFinale = "season_finale"
}

/// 중요 경기를 발동시킨 상황. 고정 주차 대신 상태 트리거로 결정된다.
public enum ProSeasonTrigger: String, Codable, Sendable {
    case openingStatement = "opening_statement"
    case callUpAudition = "call_up_audition"
    case majorDebut = "major_debut"
    case recordChase = "record_chase"
    case roleShowdown = "role_showdown"
    case standingsRace = "standings_race"
}

/// 중요 경기에서 상대하는 라이벌 타자. 구단·시즌·트리거로 풀에서 결정론적으로 선택된다.
public struct ProRivalBatter: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let archetype: String
    public let teamID: String
    public let teamName: String
    public let record: String
    public let profile: String
    public init(id: String, name: String, archetype: String, teamID: String, teamName: String, record: String, profile: String) {
        self.id = id; self.name = name; self.archetype = archetype; self.teamID = teamID; self.teamName = teamName; self.record = record; self.profile = profile
    }
}

/// "올해의 세 가지 긴장" — 시즌 시작 때 결정론적으로 생성되는 보직·기록·라이벌 목표.
public struct ProSeasonTension: Codable, Equatable, Sendable {
    public let kind: String   // "role" | "record" | "rival"
    public let title: String
    public let detail: String
    public init(kind: String, title: String, detail: String) { self.kind = kind; self.title = title; self.detail = detail }
}

/// 한 시즌의 성적.
///
/// `losses`는 나중에 붙였다. 기존 저장본에는 없으므로 `Decodable`을 손으로 써서 없으면 0으로
/// 읽는다 — 이걸 빼먹으면 이미 배포된 빌드로 플레이하던 사람의 커리어가 열리지 않는다.
public struct ProSeasonStats: Codable, Equatable, Sendable {
    public let season: Int
    public let teamID: String
    public let games: Int
    public let starts: Int
    public let inningsOuts: Int
    public let strikeouts: Int
    public let walks: Int
    public let runsAllowed: Int
    public let wins: Int
    /// 패전. 예전에는 승만 세고 패는 아예 없었다 — 승률이 없으니 성적표가 반쪽이었다.
    /// 기존 저장본에는 이 값이 없으므로 기본값 0으로 디코드된다.
    public let losses: Int
    public let saves: Int
    public init(season: Int, teamID: String, games: Int = 0, starts: Int = 0, inningsOuts: Int = 0, strikeouts: Int = 0, walks: Int = 0, runsAllowed: Int = 0, wins: Int = 0, losses: Int = 0, saves: Int = 0) {
        self.season = season; self.teamID = teamID; self.games = games; self.starts = starts; self.inningsOuts = inningsOuts; self.strikeouts = strikeouts; self.walks = walks; self.runsAllowed = runsAllowed; self.wins = wins; self.losses = losses; self.saves = saves
    }

    /// 없는 키는 0으로 읽는다.
    ///
    /// `losses`는 나중에 붙인 항목이라 이미 배포된 빌드가 저장한 커리어에는 들어 있지 않다.
    /// 합성 디코더는 키가 없으면 그 자리에서 실패하므로, 그대로 두면 TestFlight로 플레이하던
    /// 사람의 커리어가 통째로 열리지 않는다. 새 항목을 붙일 때마다 여기에 한 줄씩 는다.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        season = try container.decode(Int.self, forKey: .season)
        teamID = try container.decode(String.self, forKey: .teamID)
        games = try container.decodeIfPresent(Int.self, forKey: .games) ?? 0
        starts = try container.decodeIfPresent(Int.self, forKey: .starts) ?? 0
        inningsOuts = try container.decodeIfPresent(Int.self, forKey: .inningsOuts) ?? 0
        strikeouts = try container.decodeIfPresent(Int.self, forKey: .strikeouts) ?? 0
        walks = try container.decodeIfPresent(Int.self, forKey: .walks) ?? 0
        runsAllowed = try container.decodeIfPresent(Int.self, forKey: .runsAllowed) ?? 0
        wins = try container.decodeIfPresent(Int.self, forKey: .wins) ?? 0
        losses = try container.decodeIfPresent(Int.self, forKey: .losses) ?? 0
        saves = try container.decodeIfPresent(Int.self, forKey: .saves) ?? 0
    }
}

public struct ProContractSnapshot: Codable, Equatable, Sendable {
    public let yearsRemaining: Int
    public let annualSalary: Int
    public let rolePromise: ProRole
    public init(yearsRemaining: Int, annualSalary: Int, rolePromise: ProRole) { self.yearsRemaining = yearsRemaining; self.annualSalary = annualSalary; self.rolePromise = rolePromise }
}

/// 프로 커리어 한 시점.
///
/// **`class`인 이유**: Swift 6.3이 저장 프로퍼티가 많은 값 타입에 만들어 내는
/// `outlined destroy`가 과다 해제를 일으켜, 전체 테스트를 한 바이너리에서 돌릴 때만
/// SIGSEGV로 죽는다(`--filter`로 하나씩 돌리면 전부 통과해서 더 헷갈린다).
/// `HighSchoolCareerSnapshot`에서 이미 같은 일을 겪었고 처방도 같다 — 클래스로 감싼다.
/// JSON 모양은 그대로이고, 엔진이 언제나 `replacing(...)`으로 새 인스턴스를 만들 뿐
/// 변경하지 않으므로 값 의미론도 유지된다. 대신 `==`가 합성되지 않아 손으로 써야 한다.
public final class ProCareerSnapshot: Codable, Equatable, Sendable {
    public let proCareerID: String
    public let revision: UInt64
    public let phase: ProCareerPhase
    public let identity: PlayerIdentitySnapshot
    public let pitcher: PitcherSnapshot
    public let team: DraftTeamSnapshot
    public let entitlement: ProEntitlementSnapshot
    public let age: Int
    public let season: Int
    public let week: Int
    public let level: ProLevel
    public let role: ProRole
    public let managerTrust: Int
    public let catcherTrust: Int
    public let fatigue: Int
    public let injuryWeeks: Int
    public let serviceYears: Int
    public let militaryCompleted: Bool
    public let contract: ProContractSnapshot?
    public let currentStats: ProSeasonStats
    /// 이번 시즌의 등판 기록. 기존 저장본에는 없으므로 optional이다 —
    /// 필수로 만들면 TestFlight 사용자의 저장이 통째로 깨진다.
    public let gameLines: [ProGameLine]?
    public let careerStats: [ProSeasonStats]
    public let awards: [String]
    public let milestones: [String]
    public let news: [String]
    public let hallOfFameScore: Int?
    public let commitment: String
    public let balanceVersion: Int?
    // Phase 3-2 시즌 아크. 모두 옵셔널이라 이 필드가 없는 구세이브도 기본값 nil로 디코드된다.
    public let seasonSegment: ProSeasonSegment?
    public let seasonTrigger: ProSeasonTrigger?
    public let currentRival: ProRivalBatter?
    public let seasonTensions: [ProSeasonTension]?
    public let seasonImportantGames: Int?
    /// Wave 5 결정 필드는 옵셔널이다. 키가 없는 기존 저장본은 둘 다 nil로 디코드된다.
    public let pendingDecision: ProSeasonDecision?
    public let decisionHistory: [ProDecisionRecord]?
    public init(proCareerID: String, revision: UInt64, phase: ProCareerPhase, identity: PlayerIdentitySnapshot, pitcher: PitcherSnapshot, team: DraftTeamSnapshot, entitlement: ProEntitlementSnapshot, age: Int, season: Int, week: Int, level: ProLevel, role: ProRole, managerTrust: Int, catcherTrust: Int, fatigue: Int, injuryWeeks: Int, serviceYears: Int, militaryCompleted: Bool, contract: ProContractSnapshot?, currentStats: ProSeasonStats, gameLines: [ProGameLine]? = nil, careerStats: [ProSeasonStats], awards: [String], milestones: [String], news: [String], hallOfFameScore: Int?, commitment: String, balanceVersion: Int? = nil, seasonSegment: ProSeasonSegment? = nil, seasonTrigger: ProSeasonTrigger? = nil, currentRival: ProRivalBatter? = nil, seasonTensions: [ProSeasonTension]? = nil, seasonImportantGames: Int? = nil, pendingDecision: ProSeasonDecision? = nil, decisionHistory: [ProDecisionRecord]? = nil) {
        self.proCareerID = proCareerID; self.revision = revision; self.phase = phase; self.identity = identity; self.pitcher = pitcher; self.team = team; self.entitlement = entitlement; self.age = age; self.season = season; self.week = week; self.level = level; self.role = role; self.managerTrust = managerTrust; self.catcherTrust = catcherTrust; self.fatigue = fatigue; self.injuryWeeks = injuryWeeks; self.serviceYears = serviceYears; self.militaryCompleted = militaryCompleted; self.contract = contract; self.currentStats = currentStats; self.gameLines = gameLines; self.careerStats = careerStats; self.awards = awards; self.milestones = milestones; self.news = news; self.hallOfFameScore = hallOfFameScore; self.commitment = commitment; self.balanceVersion = balanceVersion; self.seasonSegment = seasonSegment; self.seasonTrigger = seasonTrigger; self.currentRival = currentRival; self.seasonTensions = seasonTensions; self.seasonImportantGames = seasonImportantGames; self.pendingDecision = pendingDecision; self.decisionHistory = decisionHistory
    }

    public static func == (lhs: ProCareerSnapshot, rhs: ProCareerSnapshot) -> Bool {
        // 프로퍼티가 늘면 여기도 늘어야 한다. 빠뜨리면 서로 다른 상태를 같다고 판단한다.
        lhs.proCareerID == rhs.proCareerID
            && lhs.revision == rhs.revision
            && lhs.phase == rhs.phase
            && lhs.identity == rhs.identity
            && lhs.pitcher == rhs.pitcher
            && lhs.team == rhs.team
            && lhs.entitlement == rhs.entitlement
            && lhs.age == rhs.age
            && lhs.season == rhs.season
            && lhs.week == rhs.week
            && lhs.level == rhs.level
            && lhs.role == rhs.role
            && lhs.managerTrust == rhs.managerTrust
            && lhs.catcherTrust == rhs.catcherTrust
            && lhs.fatigue == rhs.fatigue
            && lhs.injuryWeeks == rhs.injuryWeeks
            && lhs.serviceYears == rhs.serviceYears
            && lhs.militaryCompleted == rhs.militaryCompleted
            && lhs.contract == rhs.contract
            && lhs.currentStats == rhs.currentStats
            && lhs.gameLines == rhs.gameLines
            && lhs.careerStats == rhs.careerStats
            && lhs.awards == rhs.awards
            && lhs.milestones == rhs.milestones
            && lhs.news == rhs.news
            && lhs.hallOfFameScore == rhs.hallOfFameScore
            && lhs.commitment == rhs.commitment
            && lhs.balanceVersion == rhs.balanceVersion
            && lhs.seasonSegment == rhs.seasonSegment
            && lhs.seasonTrigger == rhs.seasonTrigger
            && lhs.currentRival == rhs.currentRival
            && lhs.seasonTensions == rhs.seasonTensions
            && lhs.seasonImportantGames == rhs.seasonImportantGames
            && lhs.pendingDecision == rhs.pendingDecision
            && lhs.decisionHistory == rhs.decisionHistory
    }
}

public struct ProCareerResult: Codable, Equatable, Sendable {
    public let snapshot: ProCareerSnapshot
    public let nextSeed: String
    public let events: [String]
    public init(snapshot: ProCareerSnapshot, nextSeed: String, events: [String]) { self.snapshot = snapshot; self.nextSeed = nextSeed; self.events = events }
}

public struct StartProCareerParams: Codable, Equatable, Sendable {
    public let seed: String
    public let identity: PlayerIdentitySnapshot
    public let pitcher: PitcherSnapshot
    public let draftResult: DraftResultSnapshot
    public let entitlement: ProEntitlementSnapshot
    public init(seed: String, identity: PlayerIdentitySnapshot, pitcher: PitcherSnapshot, draftResult: DraftResultSnapshot, entitlement: ProEntitlementSnapshot) {
        self.seed = seed; self.identity = identity; self.pitcher = pitcher; self.draftResult = draftResult; self.entitlement = entitlement
    }
}

public struct ProStateParams: Codable, Equatable, Sendable {
    public let seed: String; public let state: ProCareerSnapshot
    public init(seed: String, state: ProCareerSnapshot) { self.seed = seed; self.state = state }
}
public struct PlanProWeekParams: Codable, Equatable, Sendable {
    public let seed: String; public let state: ProCareerSnapshot; public let plan: ProWeekPlan
    public init(seed: String, state: ProCareerSnapshot, plan: ProWeekPlan) { self.seed = seed; self.state = state; self.plan = plan }
}
public struct ResolveProGameParams: Codable, Equatable, Sendable {
    public let seed: String; public let state: ProCareerSnapshot; public let report: ImportantInningReport
    public init(seed: String, state: ProCareerSnapshot, report: ImportantInningReport) { self.seed = seed; self.state = state; self.report = report }
}
/// 확인 화면이 보고 있던 결정과 선택지를 함께 보내 stale 적용을 막는다.
public struct ApplyProSeasonDecisionParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: ProCareerSnapshot
    public let decisionID: String
    public let choiceID: String

    public init(seed: String, state: ProCareerSnapshot, decisionID: String, choiceID: String) {
        self.seed = seed
        self.state = state
        self.decisionID = decisionID
        self.choiceID = choiceID
    }
}
public struct ProOffseasonParams: Codable, Equatable, Sendable {
    public let seed: String; public let state: ProCareerSnapshot; public let decision: OffseasonDecision
    public init(seed: String, state: ProCareerSnapshot, decision: OffseasonDecision) { self.seed = seed; self.state = state; self.decision = decision }
}

public struct ProCareerEngine: Sendable {
    public init() {}

    public func start(_ params: StartProCareerParams) throws -> ProCareerResult {
        guard let seed = UInt64(params.seed) else { throw SimulationError.invalidSeed(params.seed) }
        guard params.entitlement.status == .active else { throw SimulationError.invalidProCareer("프로 커리어 이용 권한을 확인할 수 없습니다.") }
        guard params.draftResult.outcome == .drafted, let draftedTeam = params.draftResult.team else { throw SimulationError.invalidProCareer("고교 드래프트 지명 기록이 필요합니다.") }
        let team = HighSchoolCareerEngine.teams.first(where: { $0.id == draftedTeam.id }) ?? draftedTeam
        var rng = SplitMix64(seed: seed)
        let id = "pro-\(StableHash.fnv1a64("\(seed)|\(params.pitcher.id)|\(team.id)"))"
        let stats = ProSeasonStats(season: 1, teamID: team.id)
        let base = ProCareerSnapshot(proCareerID: id, revision: 0, phase: .contractOffer, identity: params.identity, pitcher: params.pitcher, team: team, entitlement: params.entitlement, age: 19, season: 1, week: 0, level: .minor, role: .starter, managerTrust: 42, catcherTrust: 45, fatigue: 0, injuryWeeks: 0, serviceYears: 0, militaryCompleted: false, contract: nil, currentStats: stats, careerStats: [], awards: [], milestones: ["프로 지명"], news: ["신인 계약 제안 · \(team.name) · \(params.identity.name)"], hallOfFameScore: nil, commitment: "", balanceVersion: PitcherPresetCatalog.balanceVersion, seasonSegment: .springCamp, seasonImportantGames: 0, decisionHistory: [])
        let state = signed(base)
        return result(state, nextSeed: String(rng.next()), events: ["pro_career_started"])
    }

    public func normalizeBalance(_ params: ProStateParams) throws -> ProCareerResult {
        _ = try generator(params.seed)
        try validateState(params.state)
        let sourceVersion = params.state.balanceVersion
            ?? PitcherPresetCatalog.inferredLegacyVersion(for: params.state.pitcher)
        let normalizationTargetVersion = 3
        let pitcher = PitcherPresetCatalog.migrate(
            params.state.pitcher,
            fromVersion: sourceVersion,
            targetVersion: normalizationTargetVersion
        )?.pitcher
            ?? params.state.pitcher
        let normalized = signed(replacing(params.state, pitcher: pitcher,
            balanceVersion: max(sourceVersion, normalizationTargetVersion)))
        return ProCareerResult(snapshot: normalized, nextSeed: params.seed, events: [])
    }

    public func signContract(_ params: ProStateParams) throws -> ProCareerResult {
        try validate(params.state, phase: .contractOffer)
        var rng = try generator(params.seed)
        let bonus = max(30_000_000, params.state.pitcher.stuff * 1_000_000)
        let contract = ProContractSnapshot(yearsRemaining: 3, annualSalary: bonus, rolePromise: .starter)
        let tensions = seasonTensions(for: params.state)
        let state = replacing(params.state, revision: params.state.revision + 1, phase: .weeklyPlan, contract: contract,
            milestones: addingUnique("신인 계약", to: params.state.milestones),
            news: ["신인 계약에 서명했습니다. 2군 선발 경쟁이 시작됩니다.", tensionHeadline(tensions)] + params.state.news,
            seasonSegment: segment(forWeek: params.state.week), seasonTensions: tensions, seasonImportantGames: 0)
        return result(state, nextSeed: String(rng.next()), events: ["rookie_contract_signed"])
    }

    public func planWeek(_ params: PlanProWeekParams) throws -> ProCareerResult {
        try validate(params.state, phase: .weeklyPlan)
        var rng = try generator(params.seed)
        let state = params.state
        let nextWeek = state.week + 1
        let recovering = state.injuryWeeks > 0
        let skill = (state.pitcher.stuff + state.pitcher.command + state.pitcher.movement + state.pitcher.stamina) / 4
        // 주간 자동 등판을 수동 중요 경기와 같은 커널로 실행한다(3줄 산식 폐기).
        let restingWeek = recovering || params.plan == .recover
        let outings: Int
        let outsTargetPerOuting: Int
        let pitchCapPerOuting: Int
        switch state.role {
        case .starter: outings = 1; outsTargetPerOuting = 18; pitchCapPerOuting = 96
        case .longRelief: outings = 2; outsTargetPerOuting = 6; pitchCapPerOuting = 42
        case .setup, .closer: outings = 3; outsTargetPerOuting = 3; pitchCapPerOuting = 24
        }
        var weekLine = WeeklyOutingLine()
        var newGameLines: [ProGameLine] = []
        if !restingWeek {
            for outingIndex in 0..<outings {
                let outingLine = simulateWeeklyOuting(
                    pitcher: state.pitcher,
                    startingFatigue: state.fatigue + outingIndex * 5,
                    outsTarget: outsTargetPerOuting,
                    pitchCap: pitchCapPerOuting,
                    baseSeed: rng.next() ^ UInt64(bitPattern: Int64(nextWeek &* 0x9E37)) &+ UInt64(outingIndex)
                )
                weekLine.outs += outingLine.outs
                weekLine.strikeouts += outingLine.strikeouts
                weekLine.walks += outingLine.walks
                weekLine.runsAllowed += outingLine.runsAllowed
                weekLine.pitches += outingLine.pitches
                weekLine.hits += outingLine.hits
                weekLine.homeRuns += outingLine.homeRuns

                // 우리 타선이 몇 점을 냈는지를 실제 득점 분포에서 뽑는다. 이 값이 있어야
                // 승패가 규칙대로 붙고, 무엇보다 "잘 던지고도 못 이긴 날"이 생긴다.
                let support = LeagueBaseline.teamRuns(using: &rng)
                // 내가 던지지 않은 이닝의 실점. 선발이면 불펜 3~4이닝, 구원이면 나머지
                // 여덟 이닝 몫이다. 역할에 따라 따로 두면 마무리 등판 날만 상대 점수가
                // 비현실적으로 낮아진다.
                let othersOuts = max(0, 27 - outingLine.outs)
                let othersRuns = LeagueBaseline.restOfTeamRuns(outsCovered: othersOuts, using: &rng)
                let opponentRuns = outingLine.runsAllowed + othersRuns
                let started = state.role == .starter
                newGameLines.append(
                    ProGameLine(
                        season: state.season,
                        week: nextWeek,
                        outingNumber: (state.gameLines?.count ?? 0) + newGameLines.count + 1,
                        started: started,
                        outs: outingLine.outs,
                        strikeouts: outingLine.strikeouts,
                        walks: outingLine.walks,
                        runsAllowed: outingLine.runsAllowed,
                        pitches: outingLine.pitches,
                        teamRuns: support,
                        opponentRuns: opponentRuns,
                        decision: DecisionRules.decide(
                            started: started,
                            isCloser: state.role == .closer,
                            outs: outingLine.outs,
                            runsAllowed: outingLine.runsAllowed,
                            teamRuns: support,
                            opponentRuns: opponentRuns
                        ),
                        played: false,
                        hits: outingLine.hits,
                        homeRuns: outingLine.homeRuns
                    )
                )
            }
        }
        let games = restingWeek ? 0 : outings
        let starts = restingWeek ? 0 : (state.role == .starter ? 1 : 0)
        let strikeouts = weekLine.strikeouts
        let walks = weekLine.walks
        let runs = weekLine.runsAllowed
        let fatigueDelta = recovering || params.plan == .recover ? -20
            : params.plan == .buildStamina ? 13 : params.plan == .developWeapon ? 15 : 10
        let fatigue = clamp(state.fatigue + fatigueDelta, 0, 100)
        let injuryRoll = rng.nextInt(upperBound: 100)
        let newInjury = !recovering && injuryRoll < max(2, fatigue - 72) ? 2 + rng.nextInt(upperBound: 4) : max(0, state.injuryWeeks - 1)
        // 감독의 믿음은 **내려가기도 해야 한다.**
        //
        // 예전에는 잘 던지면 오르고 아니면 그대로였다(0). 한 방향으로만 움직이는 값은
        // 스테이크가 아니라 시간의 함수다 — 주차를 넘기기만 하면 언젠가 선발이 된다.
        // 실측상 프로 등판이 감독의 믿음을 평균 +1.9밖에 못 움직였던 이유가 이것이다.
        let performanceTrust: Int
        switch runs {
        case ...2: performanceTrust = 3
        case 3: performanceTrust = 0
        case 4...5: performanceTrust = -3
        default: performanceTrust = -6
        }
        let trustGain = recovering ? -1
            : params.plan == .earnTrust ? 5
            : params.plan == .recover ? 0
            : performanceTrust
        let trust = clamp(state.managerTrust + trustGain, 0, 100)
        let stats = ProSeasonStats(season: state.season, teamID: state.team.id, games: state.currentStats.games + games, starts: state.currentStats.starts + starts, inningsOuts: state.currentStats.inningsOuts + weekLine.outs, strikeouts: state.currentStats.strikeouts + strikeouts, walks: state.currentStats.walks + walks, runsAllowed: state.currentStats.runsAllowed + runs, wins: state.currentStats.wins + newGameLines.count { $0.decision == .win }, losses: state.currentStats.losses + newGameLines.count { $0.decision == .loss }, saves: state.currentStats.saves + newGameLines.count { $0.decision == .save })
        let earnedCallUp = trust >= 60 && skill >= 46
            && (state.season > 1 || stats.games >= 12 || stats.strikeouts >= 40)
        // **2군행이 있다.** 예전에는 한번 올라가면 내려오지 않았다 — 1군이 승급이 아니라
        // 통과 지점이었다는 뜻이고, 그러면 남은 시즌에 걸린 것이 없어진다.
        //
        // 되돌릴 수 있는 세트백이다. 다시 던져서 믿음을 쌓으면 올라온다.
        let demoted = state.level == .major && trust < Self.demotionTrust && !recovering
        let level: ProLevel = demoted ? .minor : (state.level == .major || earnedCallUp ? .major : .minor)
        let role: ProRole = level == .major
            ? trust >= 74 ? .starter : trust >= 62 ? .longRelief : .setup
            : trust >= 52 ? .starter : .longRelief
        let growth = params.plan == .recover || recovering || params.plan == .earnTrust ? 0 : nextWeek % 2 == 1 ? 1 : 0
        let pitcher = grow(state.pitcher, plan: params.plan, amount: growth)
        let callUpGame = state.level != level && level == .major
        let priorImportantGames = state.seasonImportantGames ?? 0
        let trigger: ProSeasonTrigger? = nextWeek >= 24 ? nil
            : importantGameTrigger(state: state, nextWeek: nextWeek, newLevel: level, newTrust: trust, seasonStrikeouts: stats.strikeouts, skill: skill, priorImportantGames: priorImportantGames)
        let decisionsThisSeason = (state.decisionHistory ?? []).count { $0.season == state.season }
        // 중요 경기와 부상은 화면상 더 급한 사건이다. 해당 주의 갈림길은 뒤로 미루거나
        // 중복 노출하지 않고 건너뛴다. 고정 후보가 일곱뿐이라 시즌 최대치도 자연히 7회다.
        let shouldOpenDecision = nextWeek < 24
            && (state.balanceVersion ?? 1) >= 4
            && Self.seasonDecisionWeeks.contains(nextWeek)
            && trigger == nil
            && !recovering
            && newInjury == 0
            && decisionsThisSeason < Self.maximumSeasonDecisions
        let pendingDecision: ProSeasonDecision? = shouldOpenDecision
            ? seasonDecision(for: state, week: nextWeek)
            : nil
        let phase: ProCareerPhase = nextWeek >= 24 ? .seasonReview
            : trigger != nil ? .importantGame
            : pendingDecision != nil ? .seasonDecision
            : .weeklyPlan
        let rival: ProRivalBatter? = trigger.map { rivalForGame(state, week: nextWeek, trigger: $0) }
        let importantGames = priorImportantGames + (phase == .importantGame ? 1 : 0)
        let seasonTensionsValue = state.seasonTensions ?? seasonTensions(for: state)
        let priorSegment = state.seasonSegment ?? segment(forWeek: state.week)
        let nextSegment = segment(forWeek: nextWeek)
        var news = state.news
        var milestones = state.milestones
        if state.week == 0 {
            milestones = addingUnique("프로 첫 공식 등판", to: milestones)
            news.insert("프로 첫 공식 등판을 마쳤습니다. \(games)경기에서 \(strikeouts)개의 삼진을 잡았습니다.", at: 0)
        } else {
            news.insert("\(nextWeek)주차 · \(games)경기 · \(strikeouts)K · \(walks)볼넷 · \(runs)실점", at: 0)
        }
        if state.level != level {
            if level == .major {
                milestones = addingUnique("1군 콜업", to: milestones)
                news.insert("2군 기록과 감독의 믿음을 쌓아 1군 출전 명단에 합류했습니다.", at: 0)
            } else {
                news.insert("최근 등판이 이어지지 않아 2군으로 내려갑니다. 기록을 다시 쌓아야 합니다.", at: 0)
            }
        }
        if state.role != role {
            let roleName = role == .starter ? "선발" : role == .longRelief ? "긴 이닝 구원" : role == .setup ? "필승조" : "마무리"
            milestones = addingUnique("\(state.season)시즌 \(roleName) 역할", to: milestones)
            news.insert("감독 면담 뒤 다음 등판부터 \(roleName) 역할을 맡습니다.", at: 0)
        }
        let priorGames = careerGames(state)
        let nextGames = priorGames + games
        let priorStrikeouts = careerStrikeouts(state)
        let nextStrikeouts = priorStrikeouts + strikeouts
        for mark in [50, 100, 300] where priorGames < mark && nextGames >= mark {
            milestones = addingUnique("프로 통산 \(mark)경기", to: milestones)
        }
        for mark in [50, 100, 200, 500] where priorStrikeouts < mark && nextStrikeouts >= mark {
            milestones = addingUnique("프로 통산 \(mark)탈삼진", to: milestones)
        }
        if newInjury > 0 && state.injuryWeeks == 0 { news.insert("과부하로 \(newInjury)주 부상자 명단에 올랐습니다.", at: 0) }
        if nextSegment != priorSegment { news.insert(segmentEntryNews(nextSegment), at: 0) }
        if phase == .importantGame, let trigger {
            news.insert(importantMomentHeadline(trigger: trigger, rival: rival, level: level, trust: trust), at: 0)
        }
        let updated = replacing(state, revision: state.revision + 1, phase: phase, pitcher: pitcher, week: nextWeek, level: level, role: role, managerTrust: trust, fatigue: fatigue, injuryWeeks: newInjury, currentStats: stats, gameLines: (state.gameLines ?? []) + newGameLines, milestones: milestones, news: Array(news.prefix(30)), seasonSegment: nextSegment, seasonTrigger: trigger, currentRival: rival, seasonTensions: seasonTensionsValue, seasonImportantGames: importantGames, pendingDecision: pendingDecision)
        var events = ["pro_week_resolved", callUpGame ? "major_call_up" : "weekly_progress"]
        if phase == .seasonDecision { events.append("pro_season_decision_opened") }
        return result(updated, nextSeed: String(rng.next()), events: events)
    }

    /// 확인한 시즌 선택을 한 번만 적용한다.
    ///
    /// 결정 ID까지 다시 받는 이유는 확인 시트가 떠 있는 동안 상태가 바뀌었을 때 예전 선택을
    /// 새 pending 결정에 잘못 적용하지 않기 위해서다. 이 동작에는 무작위가 없으므로 시드도
    /// 소비하지 않는다. 저장 후 재개해 같은 입력을 보내면 같은 결과가 나온다.
    public func applySeasonDecision(_ params: ApplyProSeasonDecisionParams) throws -> ProCareerResult {
        try validate(params.state, phase: .seasonDecision)
        _ = try generator(params.seed)
        let state = params.state
        guard let pending = state.pendingDecision else {
            throw SimulationError.invalidProCareer("적용할 시즌 결정이 없습니다.")
        }
        guard pending.id == params.decisionID else {
            throw SimulationError.invalidProCareer("확인한 시즌 결정이 현재 결정과 다릅니다.")
        }
        guard !(state.decisionHistory ?? []).contains(where: { $0.decisionID == pending.id }) else {
            throw SimulationError.invalidProCareer("이미 적용한 시즌 결정입니다.")
        }
        guard (state.decisionHistory ?? []).count(where: { $0.season == state.season }) < Self.maximumSeasonDecisions else {
            throw SimulationError.invalidProCareer("한 시즌에는 일곱 번까지만 결정할 수 있습니다.")
        }
        guard let choice = pending.choices.first(where: { $0.id == params.choiceID }) else {
            throw SimulationError.invalidProCareer("현재 결정에 없는 선택지입니다.")
        }

        let effect = choice.effect
        let pitcher = applying(effect, to: state.pitcher)
        let managerTrust = clamp(state.managerTrust + effect.managerTrustDelta, 0, 100)
        let catcherTrust = clamp(state.catcherTrust + effect.catcherTrustDelta, 0, 100)
        let fatigue = clamp(state.fatigue + effect.fatigueDelta, 0, 100)
        let role = effect.roleTarget ?? state.role
        let record = ProDecisionRecord(
            decisionID: pending.id,
            type: pending.type,
            season: pending.season,
            week: pending.week,
            choiceID: choice.id,
            choiceTitle: choice.title,
            effect: effect
        )
        let summary = "\(pending.title) · \(choice.title) — \(effect.summary)"
        let clearedDecision: ProSeasonDecision? = nil
        let updated = replacing(
            state,
            revision: state.revision + 1,
            phase: .weeklyPlan,
            pitcher: pitcher,
            role: role,
            managerTrust: managerTrust,
            catcherTrust: catcherTrust,
            fatigue: fatigue,
            news: Array(([summary] + state.news).prefix(30)),
            pendingDecision: clearedDecision,
            decisionHistory: (state.decisionHistory ?? []) + [record]
        )
        return result(updated, nextSeed: params.seed, events: ["pro_season_decision_resolved"])
    }

    public func resolveImportantGame(_ params: ResolveProGameParams) throws -> ProCareerResult {
        try validate(params.state, phase: .importantGame)
        var rng = try generator(params.seed)
        let report = params.report
        let soundProcess = report.actualDamage <= report.expectedDamage + 150 || report.recommendationAccepted * 2 >= report.pitches
        // 수싸움 적중은 이미 끝난 투구 결과 위에 붙는 관계 보상이다. 확률이나 RNG에는 손대지
        // 않으며 nil/0이면 이전 산식과 바이트 단위로 같은 결과를 만든다.
        let sequenceTrustReward = (params.state.balanceVersion ?? 1) >= 4
            ? PitchSequenceMasteryRules.trustReward(for: report.sequenceMasteryCount)
            : 0
        let trust = clamp(params.state.managerTrust + report.strikeouts * 2 - report.walks * 2 - report.runsAllowed * 3 + (soundProcess ? 2 : 0) + sequenceTrustReward, 0, 100)
        // 실제로 잡은 아웃을 쓴다. 없으면 예전처럼 어림하되, 그건 옛 저장본 호환용 경로다.
        let outs = report.outs ?? max(3, report.pitches / 5)
        let started = params.state.role == .starter
        // 최종 스코어를 등판 시점의 점수 차에서 파생시킨다. 그래야 "1점 리드로 올라가
        // 무실점으로 막았는데 패배" 같은 모순이 생기지 않는다. 지는 경기는 반드시
        // 내 실점이나 불펜 실점으로 설명된다.
        let support: Int
        let opponentRuns: Int
        if let entryDifferential = report.scoreDifferentialAtEntry {
            let opponentEarlier = rng.nextInt(upperBound: 4)
            let lateTeam = rng.nextInt(upperBound: 3)
            let lateBullpen = started ? rng.nextInt(upperBound: 3) : 0
            opponentRuns = opponentEarlier + report.runsAllowed + lateBullpen
            support = max(0, opponentEarlier + entryDifferential + lateTeam)
        } else {
            // 옛 저장본과 데스크톱 경로. 등판 시점 정보가 없으면 분포에서 뽑는다.
            support = report.teamRuns ?? LeagueBaseline.teamRuns(using: &rng)
            let othersOuts = max(0, 27 - outs)
            opponentRuns = report.runsAllowed
                + LeagueBaseline.restOfTeamRuns(outsCovered: othersOuts, using: &rng)
        }
        let decision = DecisionRules.decide(
            started: started,
            isCloser: params.state.role == .closer,
            outs: outs,
            runsAllowed: report.runsAllowed,
            teamRuns: support,
            opponentRuns: opponentRuns
        )
        let stats = ProSeasonStats(season: params.state.season, teamID: params.state.team.id, games: params.state.currentStats.games + 1, starts: params.state.currentStats.starts + (started ? 1 : 0), inningsOuts: params.state.currentStats.inningsOuts + outs, strikeouts: params.state.currentStats.strikeouts + report.strikeouts, walks: params.state.currentStats.walks + report.walks, runsAllowed: params.state.currentStats.runsAllowed + report.runsAllowed, wins: params.state.currentStats.wins + (decision == .win ? 1 : 0), losses: params.state.currentStats.losses + (decision == .loss ? 1 : 0), saves: params.state.currentStats.saves + (decision == .save ? 1 : 0))
        // 직접 던진 경기는 기록에 그렇게 표시된다. 자동으로 지나간 경기와 섞이면
        // "내가 만든 성적"이라는 감각이 사라진다.
        let playedLine = ProGameLine(
            season: params.state.season,
            week: params.state.week,
            outingNumber: (params.state.gameLines?.count ?? 0) + 1,
            started: started,
            outs: outs,
            strikeouts: report.strikeouts,
            walks: report.walks,
            runsAllowed: report.runsAllowed,
            pitches: report.pitches,
            teamRuns: support,
            opponentRuns: opponentRuns,
            decision: decision,
            played: true
        )
        let trustDelta = trust - params.state.managerTrust
        let evaluation = soundProcess ? "고른 구종과 코스도 좋았다는 평가를 받았습니다." : "경기 결과와 별개로 구종 순서를 다시 맞춥니다."
        let masteryEvaluation = sequenceTrustReward > 0 ? " 수싸움 적중으로 감독과 포수의 믿음 +\(sequenceTrustReward)." : ""
        let foe = params.state.currentRival.map { "\($0.name)(\($0.teamName)) 상대 · " } ?? ""
        let news = ["승부처 등판 · \(foe)\(report.strikeouts)탈삼진 · \(report.walks)볼넷 · \(report.runsAllowed)실점 · 감독의 믿음 \(trustDelta >= 0 ? "+" : "")\(trustDelta). \(evaluation)\(masteryEvaluation)"] + params.state.news
        var milestones = params.state.milestones
        if params.state.level == .major { milestones = addingUnique("1군 첫 중요 승부", to: milestones) }
        let clearedRival: ProRivalBatter? = nil
        let clearedTrigger: ProSeasonTrigger? = nil
        let updated = replacing(params.state, revision: params.state.revision + 1, phase: .weeklyPlan, managerTrust: trust, catcherTrust: clamp(params.state.catcherTrust + (soundProcess ? 2 : -1) + sequenceTrustReward, 0, 100), currentStats: stats, gameLines: (params.state.gameLines ?? []) + [playedLine], milestones: milestones, news: Array(news.prefix(30)), seasonTrigger: clearedTrigger, currentRival: clearedRival)
        return result(updated, nextSeed: String(rng.next()), events: ["pro_important_game_resolved"])
    }

    public func reviewSeason(_ params: ProStateParams) throws -> ProCareerResult {
        try validate(params.state, phase: .seasonReview)
        var rng = try generator(params.seed)
        let state = params.state
        // Runs allowed per nine innings (RA/9). The sim never separates earned runs,
        // so the copy reads "9이닝당 실점" rather than the incorrect "평균자책(ERA)".
        let runsPer9Permille = state.currentStats.inningsOuts == 0 ? 9_990 : state.currentStats.runsAllowed * 27_000 / state.currentStats.inningsOuts
        var awards = state.awards
        var milestones = state.milestones
        if state.currentStats.strikeouts >= 120 { awards = addingUnique("시즌 \(state.season) 탈삼진상", to: awards) }
        if runsPer9Permille < 3_000 && state.currentStats.games >= 20 { awards = addingUnique("시즌 \(state.season) 최소 실점상", to: awards) }
        milestones = addingUnique("\(state.season)시즌 완주", to: milestones)
        let phase: ProCareerPhase = state.season >= 12 || state.age >= 37 ? .retirementDecision : .offseasonDecision
        let news = ["시즌 \(state.season) 종료 · \(state.currentStats.games)경기 · \(state.currentStats.strikeouts)K · 9이닝당 실점 \(String(format: "%.2f", Double(runsPer9Permille) / 1000))"] + state.news
        let updated = replacing(state, revision: state.revision + 1, phase: phase, careerStats: state.careerStats + [state.currentStats], awards: awards, milestones: milestones, news: Array(news.prefix(30)))
        return result(updated, nextSeed: String(rng.next()), events: ["pro_season_reviewed"])
    }

    public func chooseOffseason(_ params: ProOffseasonParams) throws -> ProCareerResult {
        guard [.offseasonDecision, .retirementDecision].contains(params.state.phase) else { throw SimulationError.invalidProCareer("지금은 오프시즌 선택을 할 수 없습니다.") }
        try validateState(params.state)
        var rng = try generator(params.seed)
        let state = params.state
        if params.decision == .retire || state.phase == .retirementDecision {
            let score = hallOfFameScore(state)
            let news = retirementRetrospective(state: state, hallOfFameScore: score) + state.news
            let retired = replacing(state, revision: state.revision + 1, phase: .completed,
                milestones: addingUnique("은퇴 · 통산 \(state.careerStats.count)시즌", to: state.milestones),
                news: news, hallOfFameScore: score)
            return result(retired, nextSeed: String(rng.next()), events: ["pro_career_retired"])
        }
        var age = state.age + 1
        var military = state.militaryCompleted
        let service = state.serviceYears + (state.level == .major ? 1 : 0)
        var team = state.team
        var news = state.news
        if params.decision == .militaryService {
            guard !military else { throw SimulationError.invalidProCareer("이미 군 복무를 마쳤습니다.") }
            age += 1; military = true; news.insert("두 시즌의 군 복무를 마치고 복귀했습니다.", at: 0)
        } else if params.decision == .freeAgency {
            guard service >= 6 else { throw SimulationError.invalidProCareer("FA 신청에는 1군 등록 6년이 필요합니다.") }
            team = Self.proTeams[((Self.proTeams.firstIndex { $0.id == state.team.id } ?? 0) + 3) % Self.proTeams.count]
            news.insert("FA 계약: \(team.name)과 새 도전을 시작합니다.", at: 0)
        }
        let season = state.season + 1
        let decline = age >= 33 ? 1 : 0
        let pitcher = decline == 0 ? state.pitcher : PitcherSnapshot(id: state.pitcher.id, name: state.pitcher.name, stuff: clamp(state.pitcher.stuff - decline, 20, 80), command: state.pitcher.command, movement: clamp(state.pitcher.movement - decline, 20, 80), stamina: clamp(state.pitcher.stamina - decline, 20, 80), pitchProfiles: state.pitcher.pitchProfiles, throwingHand: state.pitcher.throwingHand)
        let contract = ProContractSnapshot(yearsRemaining: max(1, (state.contract?.yearsRemaining ?? 1) - 1), annualSalary: max(state.contract?.annualSalary ?? 40_000_000, 40_000_000 + service * 50_000_000), rolePromise: state.role)
        let clearedDecision: ProSeasonDecision? = nil
        let baseAdvanced = replacing(state, revision: state.revision + 1, phase: .weeklyPlan, pitcher: pitcher, team: team, age: age, season: season, week: 0, fatigue: 0, injuryWeeks: 0, serviceYears: service, militaryCompleted: military, contract: contract, currentStats: ProSeasonStats(season: season, teamID: team.id),
            // 새 시즌은 빈 기록으로 시작한다. 안 비우면 12시즌 구원 투수가 800행을 들고
            // 다니고 등판 번호도 시즌을 넘어 계속 늘어난다. 지난 시즌은 careerStats가 맡는다.
            gameLines: [],
            news: Array(news.prefix(30)), pendingDecision: clearedDecision)
        let tensions = seasonTensions(for: baseAdvanced)
        let clearedRival: ProRivalBatter? = nil
        let clearedTrigger: ProSeasonTrigger? = nil
        let updated = replacing(baseAdvanced, news: Array(([tensionHeadline(tensions)] + baseAdvanced.news).prefix(30)), seasonSegment: .springCamp, seasonTrigger: clearedTrigger, currentRival: clearedRival, seasonTensions: tensions, seasonImportantGames: 0)
        return result(updated, nextSeed: String(rng.next()), events: ["pro_offseason_resolved"])
    }

    /// 결정 후보 주차와 시즌 상한은 UI·테스트에서도 같은 원본을 쓸 수 있게 공개한다.
    public static let seasonDecisionWeeks = [3, 6, 9, 12, 15, 18, 21]
    public static let maximumSeasonDecisions = 7

    /// 같은 커리어·시즌·주차에는 상태나 진행 시드와 무관하게 같은 세 선택지를 만든다.
    /// 일곱 슬롯을 여섯 종류 위에서 회전시켜, 충돌이 없다면 매 시즌 여섯 종류를 모두 본다.
    func seasonDecision(for state: ProCareerSnapshot, week: Int) -> ProSeasonDecision? {
        guard let slot = Self.seasonDecisionWeeks.firstIndex(of: week) else { return nil }
        let types = ProSeasonDecisionType.allCases
        let offset = Int(hashInt("\(state.proCareerID)|season\(state.season)|season-decisions") % UInt64(types.count))
        let type = types[(offset + slot) % types.count]
        let content = decisionContent(type)
        return ProSeasonDecision(
            id: "season-\(state.season)-week-\(week)-\(type.rawValue)",
            type: type,
            season: state.season,
            week: week,
            title: content.title,
            detail: content.detail,
            choices: content.choices
        )
    }

    private func decisionContent(_ type: ProSeasonDecisionType) -> (title: String, detail: String, choices: [ProSeasonDecisionChoice]) {
        switch type {
        case .extraBullpen:
            return (
                "추가 불펜",
                "정규 훈련이 끝난 뒤 마운드 사용 시간이 남았습니다.",
                [
                    choice(type, "high_intensity", "강하게 더 던진다", "구위와 변화구를 함께 끌어올립니다.", .init(stuffDelta: 1, movementDelta: 1, fatigueDelta: 14)),
                    choice(type, "shape_work", "변화구만 다듬는다", "부담을 줄이고 변화구 감각에 집중합니다.", .init(movementDelta: 1, fatigueDelta: 7)),
                    choice(type, "rest", "오늘은 멈춘다", "성장 대신 몸을 회복합니다.", .init(fatigueDelta: -16)),
                ]
            )
        case .catcherGamePlan:
            return (
                "포수와 경기 계획",
                "다음 등판의 구종 순서와 승부 방식을 정합니다.",
                [
                    choice(type, "battery_plan", "포수와 함께 짠다", "배터리 호흡과 코스 실행을 우선합니다.", .init(commandDelta: 1, catcherTrustDelta: 8, fatigueDelta: 4)),
                    choice(type, "staff_report", "감독 보고서를 따른다", "벤치가 원하는 경기 운영에 맞춥니다.", .init(managerTrustDelta: 7, catcherTrustDelta: 1, fatigueDelta: 3)),
                    choice(type, "own_sequence", "내 공을 밀어붙인다", "변화구 감각을 얻는 대신 두 사람의 믿음을 겁니다.", .init(movementDelta: 1, managerTrustDelta: -2, catcherTrustDelta: -3, fatigueDelta: 5)),
                ]
            )
        case .roleMeeting:
            return (
                "역할 면담",
                "코칭스태프가 남은 시즌의 등판 역할을 묻습니다.",
                [
                    choice(type, "hold_role", "현재 역할을 지킨다", "익숙한 준비 리듬을 유지합니다.", .init(managerTrustDelta: 3, fatigueDelta: -4)),
                    choice(type, "challenge_starter", "선발에 도전한다", "긴 이닝 준비와 경쟁 부담을 받아들입니다.", .init(staminaDelta: 1, managerTrustDelta: -3, fatigueDelta: 10, roleTarget: .starter)),
                    choice(type, "focus_relief", "구원에 집중한다", "짧은 등판의 구위와 포수 호흡을 택합니다.", .init(stuffDelta: 1, catcherTrustDelta: 3, fatigueDelta: 6, roleTarget: .longRelief)),
                ]
            )
        case .recordChase:
            return (
                "기록 추격",
                "개인 기록과 팀에 필요한 투구 사이에서 훈련 방향을 고릅니다.",
                [
                    choice(type, "strikeouts", "탈삼진을 노린다", "결정구 두 가지를 강하게 연마합니다.", .init(stuffDelta: 1, movementDelta: 1, fatigueDelta: 12)),
                    choice(type, "run_prevention", "실점 억제를 택한다", "제구와 배터리 운영을 다듬습니다.", .init(commandDelta: 1, catcherTrustDelta: 4, fatigueDelta: 7)),
                    choice(type, "body_management", "몸을 관리한다", "긴 시즌을 버틸 체력과 회복을 택합니다.", .init(staminaDelta: 1, fatigueDelta: -12)),
                ]
            )
        case .rivalAnalysis:
            return (
                "라이벌 분석",
                "다음 맞대결을 앞두고 분석 시간을 어디에 쓸지 정합니다.",
                [
                    choice(type, "attack_weakness", "약점을 깊게 판다", "포수와 코스를 정교하게 맞춥니다.", .init(commandDelta: 1, catcherTrustDelta: 5, fatigueDelta: 6)),
                    choice(type, "keep_strength", "내 장점을 유지한다", "구위와 변화구 완성도를 높입니다.", .init(stuffDelta: 1, movementDelta: 1, fatigueDelta: 8)),
                    choice(type, "defer", "맞대결까지 보류한다", "추가 훈련 없이 몸을 가볍게 만듭니다.", .init(fatigueDelta: -8)),
                ]
            )
        case .seasonFinale:
            return (
                "시즌 막바지",
                "순위 경쟁과 회복, 동료 지원 사이에서 마지막 힘을 배분합니다.",
                [
                    choice(type, "push_race", "순위 경쟁에 건다", "감독의 믿음을 얻는 대신 피로를 감수합니다.", .init(managerTrustDelta: 8, fatigueDelta: 14)),
                    choice(type, "recover_first", "회복을 우선한다", "출전 의지를 의심받더라도 몸을 회복합니다.", .init(managerTrustDelta: -2, fatigueDelta: -18)),
                    choice(type, "support_youth", "젊은 선수를 돕는다", "벤치와 배터리의 신뢰를 함께 쌓습니다.", .init(managerTrustDelta: 4, catcherTrustDelta: 6, fatigueDelta: 3)),
                ]
            )
        }
    }

    private func choice(_ type: ProSeasonDecisionType, _ suffix: String, _ title: String, _ detail: String, _ effect: ProDecisionEffect) -> ProSeasonDecisionChoice {
        ProSeasonDecisionChoice(id: "\(type.rawValue).\(suffix)", title: title, detail: detail, effect: effect)
    }

    private func applying(_ effect: ProDecisionEffect, to pitcher: PitcherSnapshot) -> PitcherSnapshot {
        PitcherSnapshot(
            id: pitcher.id,
            name: pitcher.name,
            stuff: clamp(pitcher.stuff + effect.stuffDelta, 20, 80),
            command: clamp(pitcher.command + effect.commandDelta, 20, 80),
            movement: clamp(pitcher.movement + effect.movementDelta, 20, 80),
            stamina: clamp(pitcher.stamina + effect.staminaDelta, 20, 80),
            pitchProfiles: pitcher.pitchProfiles,
            throwingHand: pitcher.throwingHand
        )
    }

    /// 이 아래로 내려가면 1군에서 빠진다. 콜업 기준(60)보다 한참 낮게 둔다 —
    /// 한 주 못 던졌다고 내려가면 세트백이 아니라 변덕이다.
    static let demotionTrust = 34

    public static let proTeams: [DraftTeamSnapshot] = HighSchoolCareerEngine.teams

    private func validate(_ state: ProCareerSnapshot, phase: ProCareerPhase) throws {
        guard state.phase == phase else { throw SimulationError.invalidProCareer("expected \(phase.rawValue), got \(state.phase.rawValue)") }
        try validateState(state)
    }
    private func validateState(_ state: ProCareerSnapshot) throws {
        let expectsPending = state.phase == .seasonDecision
        guard expectsPending == (state.pendingDecision != nil) else {
            throw SimulationError.invalidProCareer("season decision phase and pending decision must match")
        }
        if let pending = state.pendingDecision {
            guard pending.season == state.season, pending.week == state.week else {
                throw SimulationError.invalidProCareer("pending decision season or week mismatch")
            }
            guard pending.choices.count == 3,
                  Set(pending.choices.map(\.id)).count == 3 else {
                throw SimulationError.invalidProCareer("pending decision requires three unique choices")
            }
            try validatePendingDecisionStructure(pending)
        }
        if let history = state.decisionHistory, !history.isEmpty {
            guard Set(history.map(\.decisionID)).count == history.count else {
                throw SimulationError.invalidProCareer("decision history contains duplicate decisions")
            }
            guard history.allSatisfy({ Self.seasonDecisionWeeks.contains($0.week) && !$0.choiceID.isEmpty }) else {
                throw SimulationError.invalidProCareer("decision history contains an invalid record")
            }
            let counts = Dictionary(grouping: history, by: \.season).mapValues(\.count)
            guard counts.values.allSatisfy({ $0 <= Self.maximumSeasonDecisions }) else {
                throw SimulationError.invalidProCareer("decision history exceeds the season limit")
            }
        }
        guard state.commitment == commitment(state) else { throw SimulationError.invalidProCareer("state commitment mismatch") }
    }

    /// Persisted decision content is the contract the player saw. Catalog copy and tuning may
    /// evolve after a save was written, so validation checks its stable shape and signed payload
    /// rather than regenerating today's catalog and requiring byte-for-byte equality.
    private func validatePendingDecisionStructure(_ pending: ProSeasonDecision) throws {
        guard Self.seasonDecisionWeeks.contains(pending.week) else {
            throw SimulationError.invalidProCareer("pending decision week is not scheduled")
        }
        let expectedID = "season-\(pending.season)-week-\(pending.week)-\(pending.type.rawValue)"
        guard pending.id == expectedID else {
            throw SimulationError.invalidProCareer("pending decision id mismatch")
        }
        guard !pending.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !pending.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SimulationError.invalidProCareer("pending decision copy is empty")
        }
        let prefix = "\(pending.type.rawValue)."
        for choice in pending.choices {
            let suffix = String(choice.id.dropFirst(prefix.count))
            guard choice.id.hasPrefix(prefix), isStableDecisionIdentifier(suffix) else {
                throw SimulationError.invalidProCareer("pending decision choice id mismatch")
            }
            guard !choice.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !choice.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SimulationError.invalidProCareer("pending decision choice copy is empty")
            }
            guard isReasonable(choice.effect) else {
                throw SimulationError.invalidProCareer("pending decision effect is out of range")
            }
        }
    }

    private func isStableDecisionIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { byte in
            (97...122).contains(byte) || (48...57).contains(byte) || byte == 95
        }
    }

    private func isReasonable(_ effect: ProDecisionEffect) -> Bool {
        let abilities = [
            effect.stuffDelta, effect.commandDelta, effect.movementDelta, effect.staminaDelta,
        ]
        let trust = [effect.managerTrustDelta, effect.catcherTrustDelta]
        return abilities.allSatisfy { (-4...4).contains($0) }
            && trust.allSatisfy { (-20...20).contains($0) }
            && (-30...30).contains(effect.fatigueDelta)
    }
    private func generator(_ seed: String) throws -> SplitMix64 { guard let value = UInt64(seed) else { throw SimulationError.invalidSeed(seed) }; return SplitMix64(seed: value) }

    /// 주간 자동 등판 집계. 수동 중요 경기와 같은 커널이 만든 결과라 통계 분포가 연속적이다.
    struct WeeklyOutingLine {
        var outs = 0
        var strikeouts = 0
        var walks = 0
        var runsAllowed = 0
        var pitches = 0
        /// 피안타·피홈런. 삼진과 볼넷만 세면 "6이닝 2실점"이 어떻게 만들어졌는지 알 수 없다.
        var hits = 0
        var homeRuns = 0
    }

    /// 주간 자동 등판을 PitchKernelEngine 실제 타석 루프로 실행한다(투구 UI 없이 결과만 집계).
    /// 상대는 리그 평균(50) 기준 시드 변주 타자이고 좌우 타석도 섞인다. 투수의 피로는
    /// 커널의 구속·제구 저하로 그대로 반영되므로 "지친 주의 등판"은 자연히 나빠진다.
    /// 주간 자동 등판. 실제 구현은 `AutoOutingSimulator`에 있다 — 고교 자동 경기와
    /// 밸런스 CLI가 같은 것을 쓴다.
    func simulateWeeklyOuting(
        pitcher: PitcherSnapshot,
        startingFatigue: Int,
        outsTarget: Int,
        pitchCap: Int,
        baseSeed: UInt64
    ) -> WeeklyOutingLine {
        let line = AutoOutingSimulator().simulate(
            pitcher: pitcher,
            startingFatigue: startingFatigue,
            outsTarget: outsTarget,
            pitchCap: pitchCap,
            baseSeed: baseSeed
        )
        var weekly = WeeklyOutingLine()
        weekly.outs = line.outs
        weekly.strikeouts = line.strikeouts
        weekly.walks = line.walks
        weekly.runsAllowed = line.runsAllowed
        weekly.pitches = line.pitches
        weekly.hits = line.hits
        weekly.homeRuns = line.homeRuns
        return weekly
    }
    private func signed(_ state: ProCareerSnapshot) -> ProCareerSnapshot { replacing(state, commitment: commitment(state)) }
    private func result(_ state: ProCareerSnapshot, nextSeed: String, events: [String]) -> ProCareerResult { let value = signed(state); return ProCareerResult(snapshot: value, nextSeed: nextSeed, events: events) }
    /// Internal so compatibility tests can emulate a snapshot legitimately signed by an older
    /// catalog. Production callers outside SimulationCore still cannot forge it.
    func commitment(_ s: ProCareerSnapshot) -> String {
        var values = [s.proCareerID, String(s.revision), s.phase.rawValue, s.team.id, String(s.age), String(s.season), String(s.week), s.level.rawValue, s.role.rawValue, String(s.managerTrust), String(s.fatigue), String(s.currentStats.games), String(s.currentStats.strikeouts), String(s.careerStats.count)]
        if let balanceVersion = s.balanceVersion { values.append("balance_version:\(balanceVersion)") }
        // 구저장본과 아직 결정을 만나지 않은 저장본은 기존 해시를 그대로 쓴다. 결정이 실제로
        // 존재할 때만 중첩 해시를 붙여 pending/history 변조를 감지한다.
        if let pending = s.pendingDecision {
            values.append("pending_decision:\(decisionCommitment(pending))")
        }
        if let history = s.decisionHistory, !history.isEmpty {
            let records = history.map(recordCommitment).joined(separator: ",")
            values.append("decision_history:\(history.count):\(StableHash.fnv1a64(records))")
        }
        return StableHash.fnv1a64(values.joined(separator: "|"))
    }

    private func decisionCommitment(_ decision: ProSeasonDecision) -> String {
        var values = [
            decision.id,
            decision.type.rawValue,
            String(decision.season),
            String(decision.week),
            decision.title,
            decision.detail,
            String(decision.choices.count),
        ]
        values.append(contentsOf: decision.choices.map(choiceCommitment))
        return StableHash.fnv1a64(values.joined(separator: "|"))
    }

    private func choiceCommitment(_ choice: ProSeasonDecisionChoice) -> String {
        StableHash.fnv1a64([
            choice.id,
            choice.title,
            choice.detail,
            effectCommitment(choice.effect),
        ].joined(separator: "|"))
    }

    private func recordCommitment(_ record: ProDecisionRecord) -> String {
        StableHash.fnv1a64([
            record.decisionID,
            record.type.rawValue,
            String(record.season),
            String(record.week),
            record.choiceID,
            record.choiceTitle,
            effectCommitment(record.effect),
        ].joined(separator: "|"))
    }

    private func effectCommitment(_ effect: ProDecisionEffect) -> String {
        [
            effect.stuffDelta,
            effect.commandDelta,
            effect.movementDelta,
            effect.staminaDelta,
            effect.managerTrustDelta,
            effect.catcherTrustDelta,
            effect.fatigueDelta,
        ].map(String.init).joined(separator: ",") + "," + (effect.roleTarget?.rawValue ?? "-")
    }
    private func hallOfFameScore(_ state: ProCareerSnapshot) -> Int { clamp(state.careerStats.reduce(0) { $0 + $1.strikeouts } / 75 + state.awards.count * 8 + state.serviceYears * 3, 0, 100) }

    /// 은퇴를 한 줄 뉴스가 아니라 통산 회고 시퀀스로 만든다.
    /// 통산 합계 → 가장 빛난 시즌 → 첫 기록과 마지막 수상 → 마지막 유니폼 순서로 쌓는다.
    private func retirementRetrospective(state: ProCareerSnapshot, hallOfFameScore score: Int) -> [String] {
        var lines = [score >= 70 ? "명예의 전당 헌액이 확정됐습니다." : "은퇴식에서 선수 생활의 마지막 공을 돌아봤습니다."]
        let seasons = state.careerStats
        if !seasons.isEmpty {
            let games = seasons.reduce(0) { $0 + $1.games }
            let strikeouts = seasons.reduce(0) { $0 + $1.strikeouts }
            let outs = seasons.reduce(0) { $0 + $1.inningsOuts }
            let runs = seasons.reduce(0) { $0 + $1.runsAllowed }
            let runsPer9 = outs == 0 ? 0 : runs * 27_000 / outs
            lines.append("통산 \(seasons.count)시즌 · \(games)경기 · \(strikeouts)탈삼진 · 9이닝당 실점 \(String(format: "%.2f", Double(runsPer9) / 1_000))")
            if let best = seasons.max(by: { $0.strikeouts < $1.strikeouts }), best.strikeouts > 0 {
                lines.append("가장 빛난 해는 \(best.season)시즌 — \(best.games)경기에서 \(best.strikeouts)개의 탈삼진을 잡았습니다.")
            }
        }
        if let firstMilestone = state.milestones.first {
            let lastAward = state.awards.last.map { " · 마지막 수상: \($0)" } ?? ""
            lines.append("첫 기록: \(firstMilestone)\(lastAward)")
        }
        lines.append("마지막 공은 \(state.team.name)의 유니폼으로 던졌습니다.")
        return lines
    }
    private func addingUnique(_ value: String, to values: [String]) -> [String] { values.contains(value) ? values : values + [value] }
    private func careerGames(_ state: ProCareerSnapshot) -> Int { state.careerStats.reduce(0) { $0 + $1.games } + state.currentStats.games }
    private func careerStrikeouts(_ state: ProCareerSnapshot) -> Int { state.careerStats.reduce(0) { $0 + $1.strikeouts } + state.currentStats.strikeouts }
    // MARK: - 시즌 아크 (Phase 3-2)

    /// 24주를 6구간으로 나눈다. 순수하게 주차에서 파생된다.
    private func segment(forWeek week: Int) -> ProSeasonSegment {
        switch week {
        case ..<1: return .springCamp
        case 1...4: return .opening
        case 5...10: return .firstHalf
        case 11...13: return .allStarBreak
        case 14...20: return .pennantRace
        default: return .seasonFinale
        }
    }

    func segmentLabel(_ segment: ProSeasonSegment) -> String {
        switch segment {
        case .springCamp: return "스프링캠프"
        case .opening: return "개막"
        case .firstHalf: return "전반기"
        case .allStarBreak: return "올스타 휴식기"
        case .pennantRace: return "순위 경쟁"
        case .seasonFinale: return "시즌 결말"
        }
    }

    private func segmentEntryNews(_ segment: ProSeasonSegment) -> String {
        switch segment {
        case .springCamp: return "스프링캠프가 열렸습니다. 새 시즌 준비를 시작합니다."
        case .opening: return "개막 시리즈가 시작됐습니다. 첫인상을 남길 시간입니다."
        case .firstHalf: return "전반기 레이스에 들어섰습니다. 긴 시즌의 리듬을 잡습니다."
        case .allStarBreak: return "올스타 휴식기입니다. 몸을 추스르고 후반기를 준비합니다."
        case .pennantRace: return "순위 경쟁이 뜨거워집니다. 한 경기의 무게가 커집니다."
        case .seasonFinale: return "시즌 막바지, 마지막 순위 싸움이 남았습니다."
        }
    }

    /// 상황 트리거로 중요 경기를 판정한다. 고정 주차 대신 상태(콜업·기록·보직·순위)로 발동하며
    /// 시즌당 최대 6회로 제한된다. 앵커(개막·시즌 결말)와 상황 트리거를 섞어 4~6회가 자연 발생한다.
    private func importantGameTrigger(state: ProCareerSnapshot, nextWeek: Int, newLevel: ProLevel, newTrust: Int, seasonStrikeouts: Int, skill: Int, priorImportantGames: Int) -> ProSeasonTrigger? {
        guard priorImportantGames < 6 else { return nil }
        // 1군 데뷔전: 콜업이 확정되는 주는 항상 중요 경기.
        if state.level == .minor && newLevel == .major { return .majorDebut }
        let seg = segment(forWeek: nextWeek)
        // 앵커 ① 개막 무대 — 개막 구간의 시즌별 흔들리는 한 주.
        if seg == .opening && nextWeek == anchorWeek(state, salt: "opening", range: 2...4) { return .openingStatement }
        // 앵커 ② 시즌 종반 순위 승부 — 시즌 결말 구간의 시즌별 흔들리는 한 주.
        if seg == .seasonFinale && nextWeek == anchorWeek(state, salt: "finale", range: 21...23) { return .standingsRace }
        // 상황 ③ 콜업 직전 증명 — 2군에서 콜업 임계에 접근할 때(기록 추격보다 먼저 판정해 실제로 노출되게 한다).
        if newLevel == .minor && skill >= 44 && state.managerTrust < 57 && newTrust >= 57 { return .callUpAudition }
        // 상황 ④ 기록 추격 — 시즌 탈삼진이 마일스톤을 넘어서는 주.
        let priorSeasonK = state.currentStats.strikeouts
        for mark in Self.seasonStrikeoutMarks where priorSeasonK < mark && seasonStrikeouts >= mark { return .recordChase }
        // 상황 ⑤ 보직 경쟁 — 1군에서 감독의 믿음이 역할 경계를 넘어설 때.
        if newLevel == .major {
            for band in [63, 75] where state.managerTrust < band && newTrust >= band { return .roleShowdown }
        }
        return nil
    }

    private func importantMomentHeadline(trigger: ProSeasonTrigger, rival: ProRivalBatter?, level: ProLevel, trust: Int) -> String {
        let foe = rival.map { "\($0.teamName) \($0.name)" } ?? "상대 팀 중심타자"
        switch trigger {
        case .majorDebut: return "처음으로 1군 마운드에 오릅니다. \(foe)와의 승부가 기다립니다."
        case .openingStatement: return "개막 시리즈 선발 맞대결. \(foe) 앞에서 올 시즌 첫인상을 만듭니다."
        case .callUpAudition: return "콜업이 눈앞입니다. \(foe)를 막으면 1군 문이 열립니다."
        case .recordChase: return "기록에 다가서는 등판. \(foe)를 상대로 탈삼진을 쌓습니다."
        case .roleShowdown: return "\(foe)와의 승부로 다음 역할이 갈립니다."
        case .standingsRace: return "순위가 걸린 한 경기. \(foe)를 넘어야 가을이 보입니다."
        }
    }

    /// 시즌·salt별로 흔들리는 앵커 주차. 같은 시드는 같은 주차를, 시즌이 바뀌면 다른 주차를 준다.
    private func anchorWeek(_ state: ProCareerSnapshot, salt: String, range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        let value = hashInt("\(state.proCareerID)|season\(state.season)|\(salt)")
        return range.lowerBound + Int(value % span)
    }

    /// 중요 경기 상대 라이벌 타자를 구단·시즌·주차·트리거로 결정론 선택한다. 자기 구단 소속은 건너뛴다.
    private func rivalForGame(_ state: ProCareerSnapshot, week: Int, trigger: ProSeasonTrigger) -> ProRivalBatter {
        let pool = Self.rivalBatters
        let value = hashInt("\(state.team.id)|season\(state.season)|week\(week)|\(trigger.rawValue)")
        var index = Int(value % UInt64(pool.count))
        if pool[index].teamID == state.team.id { index = (index + 1) % pool.count }
        return pool[index]
    }

    /// "올해의 세 가지 긴장" — 보직 경쟁·기록 목표·라이벌 맞대결을 결정론 생성한다.
    private func seasonTensions(for state: ProCareerSnapshot) -> [ProSeasonTension] {
        let skill = (state.pitcher.stuff + state.pitcher.command + state.pitcher.movement + state.pitcher.stamina) / 4
        let role = ProSeasonTension(kind: "role",
            title: "\(state.team.positionCompetitor)와의 자리 싸움",
            detail: "\(roleLabel(state.role)) 한 자리를 두고 시즌 내내 성적을 견줍니다.")
        let goalK = state.level == .major ? max(120, skill * 2) : max(80, skill * 3 / 2)
        let record = ProSeasonTension(kind: "record",
            title: "시즌 \(goalK)탈삼진",
            detail: "한 시즌 개인 기록을 새로 쓰는 것이 목표입니다.")
        let rival = rivalForGame(state, week: 0, trigger: .standingsRace)
        let rivalTension = ProSeasonTension(kind: "rival",
            title: "\(rival.name) 맞대결",
            detail: "\(rival.teamName)의 \(rival.archetype). 올 시즌 몇 번이고 마운드에서 마주칩니다.")
        return [role, record, rivalTension]
    }

    private func tensionHeadline(_ tensions: [ProSeasonTension]) -> String {
        "올해의 세 가지 긴장 · " + tensions.map(\.title).joined(separator: " · ")
    }

    private func roleLabel(_ role: ProRole) -> String {
        role == .starter ? "선발" : role == .longRelief ? "긴 이닝 구원" : role == .setup ? "필승조" : "마무리"
    }

    private func hashInt(_ value: String) -> UInt64 { UInt64(StableHash.fnv1a64(value), radix: 16) ?? 0 }

    private static let seasonStrikeoutMarks = [45, 85, 125]

    /// 구단별 라이벌 타자 풀. 각 라이벌은 한 프로 구단의 간판 타자이며, 중요 경기마다
    /// 상대 구단의 중심타자로 등장한다. 이름·아키타입·기록은 모두 가상이다.
    static let rivalBatters: [ProRivalBatter] = [
        .init(id: "pro-rival-seoul", name: "강도훈", archetype: "중심 타선 해결사형", teamID: "seoul_comets", teamName: "서울 코메츠",
            record: "최근 3시즌 82홈런 · OPS .901", profile: "카운트가 몰려도 스윙이 짧아지지 않습니다. 바깥쪽 승부를 기다렸다 밀어칩니다."),
        .init(id: "pro-rival-busan", name: "마태오", archetype: "우측 담장 거포형", teamID: "busan_marines", teamName: "부산 블루웨일스",
            record: "최근 3시즌 96홈런 · 장타율 .571", profile: "낮게 깔린 공을 퍼올려 우측 담장을 넘깁니다. 몸쪽 실투 한 개를 놓치지 않습니다."),
        .init(id: "pro-rival-incheon", name: "백건우", archetype: "교타 정확형", teamID: "incheon_waves", teamName: "인천 크레스트핀스",
            record: "통산 타율 .318 · 3년 연속 150안타", profile: "파울로 승부를 늘리다 결정구를 받아칩니다. 삼진보다 인플레이 타구가 많습니다."),
        .init(id: "pro-rival-daegu", name: "노진성", archetype: "당겨치는 홈런형", teamID: "daegu_forge", teamName: "대구 포지",
            record: "지난 시즌 34홈런 · 최다 장타", profile: "빠른 배트로 안쪽 공을 끌어당깁니다. 초구부터 노림수를 숨기지 않습니다."),
        .init(id: "pro-rival-daejeon", name: "천우재", archetype: "선구안 출루형", teamID: "daejeon_rockets", teamName: "대전 로켓츠",
            record: "출루율 .420 · 볼넷 최다", profile: "존을 벗어난 공에는 손이 나가지 않습니다. 풀카운트 승부를 두려워하지 않습니다."),
        .init(id: "pro-rival-gwangju", name: "서강윤", archetype: "중장거리 갭 히터형", teamID: "gwangju_phoenix", teamName: "광주 피닉스",
            record: "2루타 최다 · OPS .880", profile: "좌중간 갭을 노려 장타를 만듭니다. 변화구 타이밍에 강합니다."),
        .init(id: "pro-rival-suwon", name: "구본혁", archetype: "컨택 무결점형", teamID: "suwon_guardians", teamName: "수원 가디언즈",
            record: "5년 연속 3할·두 자릿수 홈런", profile: "약점 코스가 뚜렷하지 않습니다. 어떤 구종이든 중심에 맞힙니다."),
        .init(id: "pro-rival-changwon", name: "류성권", archetype: "장신 파워형", teamID: "changwon_meteors", teamName: "창원 미티어스",
            record: "지난 시즌 40홈런 · 장타율 .612", profile: "긴 리치로 바깥쪽까지 커버합니다. 높은 공을 그대로 받아넘깁니다."),
        .init(id: "pro-rival-jeonju", name: "문태경", archetype: "빠른 발 갭 타자형", teamID: "jeonju_hanok", teamName: "전주 한울스",
            record: "3년 연속 3할·30도루", profile: "짧게 끊어치고 곧바로 다음 베이스를 노립니다. 실투가 곧 실점입니다."),
        .init(id: "pro-rival-jeju", name: "한도결", archetype: "득점권 해결사형", teamID: "jeju_storm", teamName: "제주 스톰",
            record: "득점권 타율 .352 · 끝내기 다수", profile: "주자가 있을 때 스윙이 더 단단해집니다. 넓은 존을 커버하는 배드볼 히터입니다."),
    ]
    private func grow(_ pitcher: PitcherSnapshot, plan: ProWeekPlan, amount: Int) -> PitcherSnapshot {
        PitcherSnapshot(id: pitcher.id, name: pitcher.name,
            stuff: clamp(pitcher.stuff + (plan == .developWeapon ? amount : 0), 20, 80),
            command: clamp(pitcher.command + (plan == .refineCommand || plan == .earnTrust ? amount : 0), 20, 80),
            movement: clamp(pitcher.movement + (plan == .developWeapon ? amount : 0), 20, 80),
            stamina: clamp(pitcher.stamina + (plan == .buildStamina ? amount : 0), 20, 80), pitchProfiles: pitcher.pitchProfiles, throwingHand: pitcher.throwingHand)
    }
    private func clamp(_ value: Int, _ low: Int, _ high: Int) -> Int { min(high, max(low, value)) }

    private func replacing(_ s: ProCareerSnapshot, revision: UInt64? = nil, phase: ProCareerPhase? = nil, pitcher: PitcherSnapshot? = nil, team: DraftTeamSnapshot? = nil, age: Int? = nil, season: Int? = nil, week: Int? = nil, level: ProLevel? = nil, role: ProRole? = nil, managerTrust: Int? = nil, catcherTrust: Int? = nil, fatigue: Int? = nil, injuryWeeks: Int? = nil, serviceYears: Int? = nil, militaryCompleted: Bool? = nil, contract: ProContractSnapshot?? = nil, currentStats: ProSeasonStats? = nil, gameLines: [ProGameLine]? = nil, careerStats: [ProSeasonStats]? = nil, awards: [String]? = nil, milestones: [String]? = nil, news: [String]? = nil, hallOfFameScore: Int?? = nil, balanceVersion: Int? = nil, commitment: String? = nil, seasonSegment: ProSeasonSegment? = nil, seasonTrigger: ProSeasonTrigger?? = nil, currentRival: ProRivalBatter?? = nil, seasonTensions: [ProSeasonTension]?? = nil, seasonImportantGames: Int? = nil, pendingDecision: ProSeasonDecision?? = nil, decisionHistory: [ProDecisionRecord]?? = nil) -> ProCareerSnapshot {
        ProCareerSnapshot(proCareerID: s.proCareerID, revision: revision ?? s.revision, phase: phase ?? s.phase, identity: s.identity, pitcher: pitcher ?? s.pitcher, team: team ?? s.team, entitlement: s.entitlement, age: age ?? s.age, season: season ?? s.season, week: week ?? s.week, level: level ?? s.level, role: role ?? s.role, managerTrust: managerTrust ?? s.managerTrust, catcherTrust: catcherTrust ?? s.catcherTrust, fatigue: fatigue ?? s.fatigue, injuryWeeks: injuryWeeks ?? s.injuryWeeks, serviceYears: serviceYears ?? s.serviceYears, militaryCompleted: militaryCompleted ?? s.militaryCompleted, contract: contract ?? s.contract, currentStats: currentStats ?? s.currentStats, gameLines: gameLines ?? s.gameLines, careerStats: careerStats ?? s.careerStats, awards: awards ?? s.awards, milestones: milestones ?? s.milestones, news: news ?? s.news, hallOfFameScore: hallOfFameScore ?? s.hallOfFameScore, commitment: commitment ?? "", balanceVersion: balanceVersion ?? s.balanceVersion, seasonSegment: seasonSegment ?? s.seasonSegment, seasonTrigger: seasonTrigger ?? s.seasonTrigger, currentRival: currentRival ?? s.currentRival, seasonTensions: seasonTensions ?? s.seasonTensions, seasonImportantGames: seasonImportantGames ?? s.seasonImportantGames, pendingDecision: pendingDecision ?? s.pendingDecision, decisionHistory: decisionHistory ?? s.decisionHistory)
    }
}
