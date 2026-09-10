import Foundation

public enum ProCareerPhase: String, Codable, Sendable {
    case contractOffer = "contract_offer"
    case weeklyPlan = "weekly_plan"
    case seasonDecision = "season_decision"
    case importantGame = "important_game"
    case seasonReview = "season_review"
    case seasonSettlement = "season_settlement"
    case offseasonDecision = "offseason_decision"
    case offseasonInvestment = "offseason_investment"
    case retirementDecision = "retirement_decision"
    case nationalTeamCall = "national_team_call"
    case nationalTournament = "national_tournament"
    case completed
}

public enum ProLevel: String, Codable, Sendable { case minor, major }
public enum ProRole: String, Codable, Sendable { case starter, longRelief = "long_relief", setup, closer }

/// Spring-camp role request result. Stored only on v9 careers that actually requested.
public enum ProRoleRequestOutcome: String, Codable, Sendable {
    case accepted
    case conditional
    case rejected
}

public enum ProRoleRequestOutlook: String, Codable, Sendable {
    case likely
    case conditional
    case difficult
}

public struct ProRoleRequestState: Codable, Equatable, Sendable {
    public let requested: ProRole
    public let outcome: ProRoleRequestOutcome
    public let reviewWeek: Int
    public let season: Int

    public init(requested: ProRole, outcome: ProRoleRequestOutcome, reviewWeek: Int, season: Int) {
        self.requested = requested
        self.outcome = outcome
        self.reviewWeek = reviewWeek
        self.season = season
    }
}

public struct ProRoleRequestEvaluation: Equatable, Sendable {
    public let requested: ProRole
    public let outcome: ProRoleRequestOutcome
    public let outlook: ProRoleRequestOutlook
    public let reviewWeek: Int
    public let rejectionNewsKey: String?

    public init(
        requested: ProRole,
        outcome: ProRoleRequestOutcome,
        outlook: ProRoleRequestOutlook,
        reviewWeek: Int,
        rejectionNewsKey: String? = nil
    ) {
        self.requested = requested
        self.outcome = outcome
        self.outlook = outlook
        self.reviewWeek = reviewWeek
        self.rejectionNewsKey = rejectionNewsKey
    }
}

public enum ProInjuryCause: String, Codable, Sendable {
    case overload
}

/// Structured explanation for the week in which a pro injury starts.  The event is attached to
/// the result, not inferred from the news feed, so clients can render it before any other weekly
/// summary and restore it after an interrupted save.
public struct ProInjuryEventSnapshot: Codable, Equatable, Sendable {
    public let cause: ProInjuryCause
    public let season: Int
    public let week: Int
    public let plan: ProWeekPlan
    public let rawFatigue: Int
    public let effectiveFatigue: Int
    public let pitches: Int
    public let recoveryWeeks: Int
    public let careerID: String?
    public let revision: UInt64?

    public init(
        cause: ProInjuryCause = .overload,
        season: Int,
        week: Int,
        plan: ProWeekPlan,
        rawFatigue: Int,
        effectiveFatigue: Int,
        pitches: Int,
        recoveryWeeks: Int,
        careerID: String? = nil,
        revision: UInt64? = nil
    ) {
        self.cause = cause
        self.season = season
        self.week = week
        self.plan = plan
        self.rawFatigue = rawFatigue
        self.effectiveFatigue = effectiveFatigue
        self.pitches = pitches
        self.recoveryWeeks = recoveryWeeks
        self.careerID = careerID
        self.revision = revision
    }

    public var stableID: String {
        "pro-injury-\(careerID ?? "unknown")-s\(season)-w\(week)-r\(revision ?? 0)-\(plan.rawValue)"
    }
}

public enum ProCareerStanding: String, Codable, Sendable {
    case prospect
    case roster
    case established
    case ace
    case clubSymbol = "club_symbol"
}
public enum ProWeekPlan: String, Codable, CaseIterable, Sendable {
    case developStuff = "develop_stuff"
    case developMovement = "develop_movement"
    /// v4 이전 저장·RPC 호환용. 새 UI에는 노출하지 않고 두 성장 게이지를 함께 전진시킨다.
    case developWeapon = "develop_weapon"
    case refineCommand = "refine_command"
    case buildStamina = "build_stamina"
    case recover
    case earnTrust = "earn_trust"
}
public enum OffseasonDecision: String, Codable, Sendable { case continueCareer = "continue", militaryService = "military_service", freeAgency = "free_agency", retire }

/// 프로 주간 훈련은 플레이어가 고른 분야별로 누적된다. 필요한 반복 횟수는 규칙 버전과
/// 현재 능력에 따라 정해지므로 달력의 홀짝이나 직접 경기 여부에 영향을 받지 않는다.
public struct ProDevelopmentProgress: Codable, Equatable, Sendable {
    public let stuff: Int
    public let command: Int
    public let movement: Int
    public let stamina: Int

    public init(stuff: Int = 0, command: Int = 0, movement: Int = 0, stamina: Int = 0) {
        self.stuff = min(8, max(0, stuff))
        self.command = min(8, max(0, command))
        self.movement = min(8, max(0, movement))
        self.stamina = min(8, max(0, stamina))
    }

    public func value(for plan: ProWeekPlan) -> Int {
        switch plan {
        case .developStuff: stuff
        case .refineCommand: command
        case .developMovement: movement
        case .buildStamina: stamina
        case .developWeapon: min(stuff, movement)
        case .recover, .earnTrust: 0
        }
    }
}

/// 시즌의 초반·중반·막바지에 제안되는 프로 시즌 갈림길.
/// 저장에는 안정적인 raw value만 남긴다.
public enum ProSeasonDecisionType: String, Codable, CaseIterable, Sendable {
    case extraBullpen = "extra_bullpen"
    case catcherGamePlan = "catcher_game_plan"
    case roleMeeting = "role_meeting"
    case recordChase = "record_chase"
    case rivalAnalysis = "rival_analysis"
    case seasonFinale = "season_finale"
    case mediaOpportunity = "media_opportunity"
    case formCrisis = "form_crisis"
    case agingCrossroads = "aging_crossroads"
    case rotationPush = "rotation_push"
    case newPitchTrial = "new_pitch_trial"
    case farmReset = "farm_reset"
    case veteranMentor = "veteran_mentor"

    /// The complete decision type catalog. Media is selected by its fixed-slot rule rather than
    /// by the legacy six-type rotation, but remains part of the closed enum for Codable and copy
    /// coverage.
    public static let allCases: [ProSeasonDecisionType] = [
        .extraBullpen, .catcherGamePlan, .roleMeeting,
        .recordChase, .rivalAnalysis, .seasonFinale, .mediaOpportunity,
        .formCrisis, .agingCrossroads,
        .rotationPush, .newPitchTrial, .farmReset, .veteranMentor,
    ]

    /// v9 weekly decisions present two tradeoff choices instead of the legacy three-choice sheet.
    public var isWeeklyBinaryDecision: Bool {
        switch self {
        case .rotationPush, .newPitchTrial, .farmReset, .veteranMentor: true
        default: false
        }
    }
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
    /// Optional journey-side income, fan, and community effect. Missing in legacy saves.
    public let journeyEffect: ProJourneyEffect?

    public init(
        id: String,
        title: String,
        detail: String,
        effect: ProDecisionEffect,
        journeyEffect: ProJourneyEffect? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.effect = effect
        self.journeyEffect = journeyEffect
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
    /// Optional journey-side income, fan, and community effect. Missing in legacy saves.
    public let journeyEffect: ProJourneyEffect?
    /// 선택이 다음 직접 승부에서 실제 반응으로 돌아온 주차. nil이면 아직 회수 전이다.
    public let followUpResolvedWeek: Int?

    public init(
        decisionID: String,
        type: ProSeasonDecisionType,
        season: Int,
        week: Int,
        choiceID: String,
        choiceTitle: String,
        effect: ProDecisionEffect,
        journeyEffect: ProJourneyEffect? = nil,
        followUpResolvedWeek: Int? = nil
    ) {
        self.decisionID = decisionID
        self.type = type
        self.season = season
        self.week = week
        self.choiceID = choiceID
        self.choiceTitle = choiceTitle
        self.effect = effect
        self.journeyEffect = journeyEffect
        self.followUpResolvedWeek = followUpResolvedWeek
    }
}

/// Temporary effects from a weekly decision. Missing on legacy saves.
public struct ProDecisionModifier: Codable, Equatable, Sendable {
    public let decisionID: String
    public let type: ProSeasonDecisionType
    public let expiresWeek: Int
    public let commandDelta: Int
    public let trainingEfficiencyPermille: Int?
    public let extraOutingChance: Int
    /// Extra outings already consumed from `extraOutingChance` during this window.
    /// Missing on early v9 saves; treat as 0.
    public let extraOutingsGranted: Int?
    public let suppressOutings: Bool
    public let injuryPressureFloor: Int?
    public let targetPitch: PitchType?
    public let qualityStarts: Int
    public let runsAllowed: Int
    public let baselineStuff: Int
    public let baselineCommand: Int
    public let baselineMovement: Int
    public let baselineStamina: Int
    public let choiceID: String

    public init(
        decisionID: String,
        type: ProSeasonDecisionType,
        expiresWeek: Int,
        commandDelta: Int = 0,
        trainingEfficiencyPermille: Int? = nil,
        extraOutingChance: Int = 0,
        extraOutingsGranted: Int? = nil,
        suppressOutings: Bool = false,
        injuryPressureFloor: Int? = nil,
        targetPitch: PitchType? = nil,
        qualityStarts: Int = 0,
        runsAllowed: Int = 0,
        baselineStuff: Int = 0,
        baselineCommand: Int = 0,
        baselineMovement: Int = 0,
        baselineStamina: Int = 0,
        choiceID: String = ""
    ) {
        self.decisionID = decisionID
        self.type = type
        self.expiresWeek = expiresWeek
        self.commandDelta = commandDelta
        self.trainingEfficiencyPermille = trainingEfficiencyPermille
        self.extraOutingChance = extraOutingChance
        self.extraOutingsGranted = extraOutingsGranted
        self.suppressOutings = suppressOutings
        self.injuryPressureFloor = injuryPressureFloor
        self.targetPitch = targetPitch
        self.qualityStarts = qualityStarts
        self.runsAllowed = runsAllowed
        self.baselineStuff = baselineStuff
        self.baselineCommand = baselineCommand
        self.baselineMovement = baselineMovement
        self.baselineStamina = baselineStamina
        self.choiceID = choiceID
    }

    public func tracking(
        qualityStarts: Int,
        runsAllowed: Int,
        extraOutingsGranted: Int? = nil
    ) -> ProDecisionModifier {
        ProDecisionModifier(
            decisionID: decisionID,
            type: type,
            expiresWeek: expiresWeek,
            commandDelta: commandDelta,
            trainingEfficiencyPermille: trainingEfficiencyPermille,
            extraOutingChance: extraOutingChance,
            extraOutingsGranted: extraOutingsGranted ?? self.extraOutingsGranted,
            suppressOutings: suppressOutings,
            injuryPressureFloor: injuryPressureFloor,
            targetPitch: targetPitch,
            qualityStarts: qualityStarts,
            runsAllowed: runsAllowed,
            baselineStuff: baselineStuff,
            baselineCommand: baselineCommand,
            baselineMovement: baselineMovement,
            baselineStamina: baselineStamina,
            choiceID: choiceID
        )
    }

    public func granting(extraOutings count: Int) -> ProDecisionModifier {
        tracking(
            qualityStarts: qualityStarts,
            runsAllowed: runsAllowed,
            extraOutingsGranted: (extraOutingsGranted ?? 0) + count
        )
    }
}

/// A weekly decision whose temporary effect has expired. Missing on legacy saves.
public struct ProDecisionFollowUp: Codable, Equatable, Identifiable, Sendable {
    public var id: String { "\(decisionID):\(week)" }
    public let decisionID: String
    public let type: ProSeasonDecisionType
    public let season: Int
    public let week: Int
    public let summaryKey: String
    public let qualityStarts: Int?
    public let runsAllowed: Int?
    public let commandRestored: Int?
    public let managerTrustDelta: Int?
    public let stuffDelta: Int?
    public let commandDelta: Int?
    public let movementDelta: Int?
    public let staminaDelta: Int?
    public let choiceID: String?

    public init(
        decisionID: String,
        type: ProSeasonDecisionType,
        season: Int,
        week: Int,
        summaryKey: String,
        qualityStarts: Int? = nil,
        runsAllowed: Int? = nil,
        commandRestored: Int? = nil,
        managerTrustDelta: Int? = nil,
        stuffDelta: Int? = nil,
        commandDelta: Int? = nil,
        movementDelta: Int? = nil,
        staminaDelta: Int? = nil,
        choiceID: String? = nil
    ) {
        self.decisionID = decisionID
        self.type = type
        self.season = season
        self.week = week
        self.summaryKey = summaryKey
        self.qualityStarts = qualityStarts
        self.runsAllowed = runsAllowed
        self.commandRestored = commandRestored
        self.managerTrustDelta = managerTrustDelta
        self.stuffDelta = stuffDelta
        self.commandDelta = commandDelta
        self.movementDelta = movementDelta
        self.staminaDelta = staminaDelta
        self.choiceID = choiceID
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
    case autumnWildCard = "autumn_wild_card"
    case autumnSemifinal = "autumn_semifinal"
    case autumnPlayoff = "autumn_playoff"
    case autumnFinal = "autumn_final"
    case nationalFinal = "national_final"
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
    public let hits: Int
    public let homeRuns: Int
    public let pitches: Int
    public let wins: Int
    /// 패전. 예전에는 승만 세고 패는 아예 없었다 — 승률이 없으니 성적표가 반쪽이었다.
    /// 기존 저장본에는 이 값이 없으므로 기본값 0으로 디코드된다.
    public let losses: Int
    public let saves: Int
    /// 해당 시즌의 포스트시즌 경기 원장. 구저장본과 진출 실패 시즌은 nil이다.
    public let postseasonGames: [ProPostseasonGameLine]?
    /// 이 시즌을 끝냈을 때의 네 능력(구위·제구·무브먼트·체력).
    ///
    /// **성장 그래프를 그릴 데이터가 어디에도 없었다.** 시즌 기록은 성적만 남기고 능력은
    /// 지금 값 하나뿐이라, "3년 전의 나"를 그릴 방법이 없었다(안드로이드도 같다). 시즌 행에
    /// 함께 남기면 별도 이력 필드도, 별도 수집 훅도 필요 없다 — 이 행은 이미 시즌 결산에서
    /// 한 번씩 쌓이고 서명된 상태 안에 있다.
    ///
    /// 없는 옛 시즌은 nil이며 그래프는 그 지점을 건너뛴다. 추정하지 않는다.
    public let abilities: [Int]?

    /// 자책점. **nil은 0이 아니라 '모른다'이다.**
    ///
    /// 자책점은 실책과 승계 주자를 가려내는 원장이 있어야만 나오고, 그 원장은 프로 규칙 12
    /// 이후의 등판만 남긴다. 원장 없이 흘러간 시즌의 자책점을 실점에서 되짚어 추정하면
    /// 화면에 나오는 방어율이 그 시즌에 실제로 있었던 일과 무관해진다. 그래서 한 경기라도
    /// 원장이 없는 시즌은 통째로 nil로 남고, 화면은 `—`를 보여 준다.
    public let earnedRuns: Int?
    public init(season: Int, teamID: String, games: Int = 0, starts: Int = 0, inningsOuts: Int = 0, strikeouts: Int = 0, walks: Int = 0, runsAllowed: Int = 0, hits: Int = 0, homeRuns: Int = 0, pitches: Int = 0, wins: Int = 0, losses: Int = 0, saves: Int = 0, postseasonGames: [ProPostseasonGameLine]? = nil, earnedRuns: Int? = nil, abilities: [Int]? = nil) {
        self.season = season; self.teamID = teamID; self.games = games; self.starts = starts; self.inningsOuts = inningsOuts; self.strikeouts = strikeouts; self.walks = walks; self.runsAllowed = runsAllowed; self.hits = hits; self.homeRuns = homeRuns; self.pitches = pitches; self.wins = wins; self.losses = losses; self.saves = saves; self.postseasonGames = postseasonGames; self.earnedRuns = earnedRuns; self.abilities = abilities
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
        hits = try container.decodeIfPresent(Int.self, forKey: .hits) ?? 0
        homeRuns = try container.decodeIfPresent(Int.self, forKey: .homeRuns) ?? 0
        pitches = try container.decodeIfPresent(Int.self, forKey: .pitches) ?? 0
        wins = try container.decodeIfPresent(Int.self, forKey: .wins) ?? 0
        losses = try container.decodeIfPresent(Int.self, forKey: .losses) ?? 0
        saves = try container.decodeIfPresent(Int.self, forKey: .saves) ?? 0
        postseasonGames = try container.decodeIfPresent([ProPostseasonGameLine].self, forKey: .postseasonGames)
        earnedRuns = try container.decodeIfPresent(Int.self, forKey: .earnedRuns)
        abilities = try container.decodeIfPresent([Int].self, forKey: .abilities)
    }

    /// 시즌을 기록으로 넘긴다. 그 시점의 능력을 함께 새겨야 나중에 성장 그래프가 그려진다.
    public func archivingPostseason(
        _ games: [ProPostseasonGameLine]?,
        abilities pitcher: PitcherSnapshot? = nil
    ) -> ProSeasonStats {
        ProSeasonStats(
            season: season,
            teamID: teamID,
            games: self.games,
            starts: starts,
            inningsOuts: inningsOuts,
            strikeouts: strikeouts,
            walks: walks,
            runsAllowed: runsAllowed,
            hits: hits,
            homeRuns: homeRuns,
            pitches: pitches,
            wins: wins,
            losses: losses,
            saves: saves,
            postseasonGames: games?.isEmpty == false ? games : nil,
            earnedRuns: earnedRuns,
            abilities: pitcher.map { [$0.stuff, $0.command, $0.movement, $0.stamina] } ?? abilities
        )
    }
}

public struct ProContractSnapshot: Codable, Equatable, Sendable {
    public let yearsRemaining: Int
    public let annualSalary: Int
    public let rolePromise: ProRole
    public let id: String?
    public let teamID: String?
    public let totalYears: Int?
    public let signedSeason: Int?
    public let kind: ProContractKind?
    public let expectation: ProContractExpectation?

    public init(
        yearsRemaining: Int,
        annualSalary: Int,
        rolePromise: ProRole,
        id: String? = nil,
        teamID: String? = nil,
        totalYears: Int? = nil,
        signedSeason: Int? = nil,
        kind: ProContractKind? = nil,
        expectation: ProContractExpectation? = nil
    ) {
        self.yearsRemaining = yearsRemaining
        self.annualSalary = annualSalary
        self.rolePromise = rolePromise
        self.id = id
        self.teamID = teamID
        self.totalYears = totalYears
        self.signedSeason = signedSeason
        self.kind = kind
        self.expectation = expectation
    }
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
    /// 역할 면담에서 정한 남은 시즌의 보직. nil인 예전 저장은 신뢰도 기반 자동 배치를 쓴다.
    public let rolePreference: ProRole?
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
    /// 투구 물리(`balanceVersion`)와 독립된 프로 일정·피로 규칙. nil 구저장은 v1이다.
    public let proRulesVersion: Int?
    // Phase 3-2 시즌 아크. 모두 옵셔널이라 이 필드가 없는 구세이브도 기본값 nil로 디코드된다.
    public let seasonSegment: ProSeasonSegment?
    public let seasonTrigger: ProSeasonTrigger?
    public let currentRival: ProRivalBatter?
    public let seasonTensions: [ProSeasonTension]?
    public let seasonImportantGames: Int?
    /// Wave 5 결정 필드는 옵셔널이다. 키가 없는 기존 저장본은 둘 다 nil로 디코드된다.
    public let pendingDecision: ProSeasonDecision?
    public let decisionHistory: [ProDecisionRecord]?
    /// nil이면 성장 게이지 도입 전 저장본이다.
    public let developmentProgress: ProDevelopmentProgress?
    /// Nil is the legacy path where every stored profile remains available.
    public let repertoireRulesVersion: Int?
    public let pitchLearningProject: PitchLearningProjectSnapshot?
    /// The journey feature is one optional aggregate. A nil value is the frozen v1 save path.
    public let journeyState: ProCareerJourneyState?
    /// v6 가을야구. 키가 없는 구세이브는 nil.
    public let postseason: ProPostseasonState?
    /// v9 weekly decision temporary effects. Missing on legacy saves.
    public let activeDecisionModifiers: [ProDecisionModifier]?
    /// v9 weekly decision follow-up cards resolved this season. Missing on legacy saves.
    public let resolvedFollowUps: [ProDecisionFollowUp]?
    /// v9 spring-camp role request. Missing on legacy saves; decodeIfPresent keeps v8 bytes.
    public let roleRequest: ProRoleRequestState?
    /// v10 national-team tournament in progress. Missing on saves that never entered a call.
    public let nationalTournament: ProNationalTournamentState?
    /// v10 finished national-team appearances. Missing on saves that never played one.
    public let nationalTeamHistory: [ProNationalTeamRecord]?
    /// v10 spring-camp load left by a finished tournament. Cleared when the next season starts.
    public let nationalTeamCarry: ProNationalTeamCarryState?
    public init(proCareerID: String, revision: UInt64, phase: ProCareerPhase, identity: PlayerIdentitySnapshot, pitcher: PitcherSnapshot, team: DraftTeamSnapshot, entitlement: ProEntitlementSnapshot, age: Int, season: Int, week: Int, level: ProLevel, role: ProRole, rolePreference: ProRole? = nil, managerTrust: Int, catcherTrust: Int, fatigue: Int, injuryWeeks: Int, serviceYears: Int, militaryCompleted: Bool, contract: ProContractSnapshot?, currentStats: ProSeasonStats, gameLines: [ProGameLine]? = nil, careerStats: [ProSeasonStats], awards: [String], milestones: [String], news: [String], hallOfFameScore: Int?, commitment: String, balanceVersion: Int? = nil, proRulesVersion: Int? = nil, seasonSegment: ProSeasonSegment? = nil, seasonTrigger: ProSeasonTrigger? = nil, currentRival: ProRivalBatter? = nil, seasonTensions: [ProSeasonTension]? = nil, seasonImportantGames: Int? = nil, pendingDecision: ProSeasonDecision? = nil, decisionHistory: [ProDecisionRecord]? = nil, developmentProgress: ProDevelopmentProgress? = nil, repertoireRulesVersion: Int? = nil, pitchLearningProject: PitchLearningProjectSnapshot? = nil, journeyState: ProCareerJourneyState? = nil, postseason: ProPostseasonState? = nil, activeDecisionModifiers: [ProDecisionModifier]? = nil, resolvedFollowUps: [ProDecisionFollowUp]? = nil, roleRequest: ProRoleRequestState? = nil, nationalTournament: ProNationalTournamentState? = nil, nationalTeamHistory: [ProNationalTeamRecord]? = nil, nationalTeamCarry: ProNationalTeamCarryState? = nil) {
        self.proCareerID = proCareerID; self.revision = revision; self.phase = phase; self.identity = identity; self.pitcher = pitcher; self.team = team; self.entitlement = entitlement; self.age = age; self.season = season; self.week = week; self.level = level; self.role = role; self.rolePreference = rolePreference; self.managerTrust = managerTrust; self.catcherTrust = catcherTrust; self.fatigue = fatigue; self.injuryWeeks = injuryWeeks; self.serviceYears = serviceYears; self.militaryCompleted = militaryCompleted; self.contract = contract; self.currentStats = currentStats; self.gameLines = gameLines; self.careerStats = careerStats; self.awards = awards; self.milestones = milestones; self.news = news; self.hallOfFameScore = hallOfFameScore; self.commitment = commitment; self.balanceVersion = balanceVersion; self.proRulesVersion = proRulesVersion; self.seasonSegment = seasonSegment; self.seasonTrigger = seasonTrigger; self.currentRival = currentRival; self.seasonTensions = seasonTensions; self.seasonImportantGames = seasonImportantGames; self.pendingDecision = pendingDecision; self.decisionHistory = decisionHistory; self.developmentProgress = developmentProgress; self.repertoireRulesVersion = repertoireRulesVersion; self.pitchLearningProject = pitchLearningProject; self.journeyState = journeyState; self.postseason = postseason; self.activeDecisionModifiers = activeDecisionModifiers; self.resolvedFollowUps = resolvedFollowUps; self.roleRequest = roleRequest; self.nationalTournament = nationalTournament; self.nationalTeamHistory = nationalTeamHistory; self.nationalTeamCarry = nationalTeamCarry
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
            && lhs.rolePreference == rhs.rolePreference
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
            && lhs.proRulesVersion == rhs.proRulesVersion
            && lhs.seasonSegment == rhs.seasonSegment
            && lhs.seasonTrigger == rhs.seasonTrigger
            && lhs.currentRival == rhs.currentRival
            && lhs.seasonTensions == rhs.seasonTensions
            && lhs.seasonImportantGames == rhs.seasonImportantGames
            && lhs.pendingDecision == rhs.pendingDecision
            && lhs.decisionHistory == rhs.decisionHistory
            && lhs.developmentProgress == rhs.developmentProgress
            && lhs.repertoireRulesVersion == rhs.repertoireRulesVersion
            && lhs.pitchLearningProject == rhs.pitchLearningProject
            && lhs.journeyState == rhs.journeyState
            && lhs.postseason == rhs.postseason
            && lhs.activeDecisionModifiers == rhs.activeDecisionModifiers
            && lhs.resolvedFollowUps == rhs.resolvedFollowUps
            && lhs.roleRequest == rhs.roleRequest
            && lhs.nationalTournament == rhs.nationalTournament
            && lhs.nationalTeamHistory == rhs.nationalTeamHistory
            && lhs.nationalTeamCarry == rhs.nationalTeamCarry
    }
}

public struct ProCareerResult: Codable, Equatable, Sendable {
    public let snapshot: ProCareerSnapshot
    public let nextSeed: String
    public let events: [String]
    public let injuryEvent: ProInjuryEventSnapshot?

    public init(snapshot: ProCareerSnapshot, nextSeed: String, events: [String]) {
        self.init(snapshot: snapshot, nextSeed: nextSeed, events: events, injuryEvent: nil)
    }

    public init(
        snapshot: ProCareerSnapshot,
        nextSeed: String,
        events: [String],
        injuryEvent: ProInjuryEventSnapshot?
    ) {
        self.snapshot = snapshot
        self.nextSeed = nextSeed
        self.events = events
        self.injuryEvent = injuryEvent
    }
}

public struct StartProCareerParams: Codable, Equatable, Sendable {
    public let seed: String
    public let identity: PlayerIdentitySnapshot
    public let pitcher: PitcherSnapshot
    public let draftResult: DraftResultSnapshot
    public let entitlement: ProEntitlementSnapshot
    public let sourceFanInterest: Int?
    public let startingRepertoire: StartingRepertoireSelection?
    public let repertoireRulesVersion: Int?
    public let pitchLearningProject: PitchLearningProjectSnapshot?
    /// When set, stamps this rules version instead of `ProCareerEngine.currentRulesVersion`.
    /// Golden fixture exporters pin v8 so regenerating oracles does not absorb weekly-decision rules.
    public let proRulesVersion: Int?
    public init(seed: String, identity: PlayerIdentitySnapshot, pitcher: PitcherSnapshot, draftResult: DraftResultSnapshot, entitlement: ProEntitlementSnapshot, sourceFanInterest: Int? = nil) {
        self.init(
            seed: seed,
            identity: identity,
            pitcher: pitcher,
            draftResult: draftResult,
            entitlement: entitlement,
            sourceFanInterest: sourceFanInterest,
            startingRepertoire: nil,
            repertoireRulesVersion: nil,
            pitchLearningProject: nil,
            proRulesVersion: nil
        )
    }

    public init(seed: String, identity: PlayerIdentitySnapshot, pitcher: PitcherSnapshot, draftResult: DraftResultSnapshot, entitlement: ProEntitlementSnapshot, sourceFanInterest: Int?, startingRepertoire: StartingRepertoireSelection?, repertoireRulesVersion: Int?, pitchLearningProject: PitchLearningProjectSnapshot?) {
        self.init(
            seed: seed,
            identity: identity,
            pitcher: pitcher,
            draftResult: draftResult,
            entitlement: entitlement,
            sourceFanInterest: sourceFanInterest,
            startingRepertoire: startingRepertoire,
            repertoireRulesVersion: repertoireRulesVersion,
            pitchLearningProject: pitchLearningProject,
            proRulesVersion: nil
        )
    }

    public init(seed: String, identity: PlayerIdentitySnapshot, pitcher: PitcherSnapshot, draftResult: DraftResultSnapshot, entitlement: ProEntitlementSnapshot, sourceFanInterest: Int?, startingRepertoire: StartingRepertoireSelection?, repertoireRulesVersion: Int?, pitchLearningProject: PitchLearningProjectSnapshot?, proRulesVersion: Int?) {
        self.seed = seed; self.identity = identity; self.pitcher = pitcher; self.draftResult = draftResult; self.entitlement = entitlement; self.sourceFanInterest = sourceFanInterest; self.startingRepertoire = startingRepertoire; self.repertoireRulesVersion = repertoireRulesVersion; self.pitchLearningProject = pitchLearningProject; self.proRulesVersion = proRulesVersion
    }
}

public struct ProStateParams: Codable, Equatable, Sendable {
    public let seed: String; public let state: ProCareerSnapshot
    public init(seed: String, state: ProCareerSnapshot) { self.seed = seed; self.state = state }
}
public struct PlanProWeekParams: Codable, Equatable, Sendable {
    public let seed: String; public let state: ProCareerSnapshot; public let plan: ProWeekPlan
    public let targetPitch: PitchType?
    public init(seed: String, state: ProCareerSnapshot, plan: ProWeekPlan, targetPitch: PitchType? = nil) {
        self.seed = seed; self.state = state; self.plan = plan; self.targetPitch = targetPitch
    }
}
public struct ResolveProGameParams: Codable, Equatable, Sendable {
    public let seed: String; public let state: ProCareerSnapshot; public let report: ImportantInningReport
    public init(seed: String, state: ProCareerSnapshot, report: ImportantInningReport) { self.seed = seed; self.state = state; self.report = report }
}
public struct ChooseProPostseasonAvailabilityParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: ProCareerSnapshot
    public let choice: ProPostseasonAvailabilityChoice

    public init(
        seed: String,
        state: ProCareerSnapshot,
        choice: ProPostseasonAvailabilityChoice
    ) {
        self.seed = seed
        self.state = state
        self.choice = choice
    }
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
public struct RequestProRoleParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: ProCareerSnapshot
    public let requested: ProRole

    public init(seed: String, state: ProCareerSnapshot, requested: ProRole) {
        self.seed = seed
        self.state = state
        self.requested = requested
    }
}
public struct RespondNationalTeamCallParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: ProCareerSnapshot
    public let accepted: Bool

    public init(seed: String, state: ProCareerSnapshot, accepted: Bool) {
        self.seed = seed
        self.state = state
        self.accepted = accepted
    }
}
public struct StartNationalFinalParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: ProCareerSnapshot

    public init(seed: String, state: ProCareerSnapshot) {
        self.seed = seed
        self.state = state
    }
}
public struct AcknowledgeNationalTeamResultParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: ProCareerSnapshot

    public init(seed: String, state: ProCareerSnapshot) {
        self.seed = seed
        self.state = state
    }
}
/// Headless substitute for the direct-play national final. Uses the tournament-derived
/// SplitMix64 stream, not the career `nextSeed`.
public struct ResolveNationalFinalAutomaticallyParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: ProCareerSnapshot

    public init(seed: String, state: ProCareerSnapshot) {
        self.seed = seed
        self.state = state
    }
}
public struct AcceptProContractParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: ProCareerSnapshot
    public let expectedRevision: UInt64
    public let marketID: String
    public let offerID: String
    public let ambition: ProCareerAmbition?

    public init(seed: String, state: ProCareerSnapshot, expectedRevision: UInt64, marketID: String, offerID: String, ambition: ProCareerAmbition?) {
        self.seed = seed
        self.state = state
        self.expectedRevision = expectedRevision
        self.marketID = marketID
        self.offerID = offerID
        self.ambition = ambition
    }
}

public struct RequestProContractCounterParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: ProCareerSnapshot
    public let expectedRevision: UInt64
    public let kind: ProContractCounterKind

    public init(seed: String, state: ProCareerSnapshot, expectedRevision: UInt64, kind: ProContractCounterKind) {
        self.seed = seed
        self.state = state
        self.expectedRevision = expectedRevision
        self.kind = kind
    }
}

public struct AcknowledgeProSettlementParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: ProCareerSnapshot
    public let expectedRevision: UInt64
    public let settlementID: String

    public init(seed: String, state: ProCareerSnapshot, expectedRevision: UInt64, settlementID: String) {
        self.seed = seed
        self.state = state
        self.expectedRevision = expectedRevision
        self.settlementID = settlementID
    }
}

public struct ChooseProInvestmentParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: ProCareerSnapshot
    public let expectedRevision: UInt64
    public let investment: ProOffseasonInvestment
    public let focus: ProDevelopmentFocus?

    public init(seed: String, state: ProCareerSnapshot, expectedRevision: UInt64, investment: ProOffseasonInvestment, focus: ProDevelopmentFocus? = nil) {
        self.seed = seed
        self.state = state
        self.expectedRevision = expectedRevision
        self.investment = investment
        self.focus = focus
    }
}
public struct ProOffseasonParams: Codable, Equatable, Sendable {
    public let seed: String; public let state: ProCareerSnapshot; public let decision: OffseasonDecision; public let expectedRevision: UInt64?
    public init(seed: String, state: ProCareerSnapshot, decision: OffseasonDecision, expectedRevision: UInt64? = nil) { self.seed = seed; self.state = state; self.decision = decision; self.expectedRevision = expectedRevision }
}
