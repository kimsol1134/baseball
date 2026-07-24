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
    public let saves: Int
    public init(season: Int, teamID: String, games: Int = 0, starts: Int = 0, inningsOuts: Int = 0, strikeouts: Int = 0, walks: Int = 0, runsAllowed: Int = 0, wins: Int = 0, saves: Int = 0) {
        self.season = season; self.teamID = teamID; self.games = games; self.starts = starts; self.inningsOuts = inningsOuts; self.strikeouts = strikeouts; self.walks = walks; self.runsAllowed = runsAllowed; self.wins = wins; self.saves = saves
    }
}

public struct ProContractSnapshot: Codable, Equatable, Sendable {
    public let yearsRemaining: Int
    public let annualSalary: Int
    public let rolePromise: ProRole
    public init(yearsRemaining: Int, annualSalary: Int, rolePromise: ProRole) { self.yearsRemaining = yearsRemaining; self.annualSalary = annualSalary; self.rolePromise = rolePromise }
}

public struct ProCareerSnapshot: Codable, Equatable, Sendable {
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
    public init(proCareerID: String, revision: UInt64, phase: ProCareerPhase, identity: PlayerIdentitySnapshot, pitcher: PitcherSnapshot, team: DraftTeamSnapshot, entitlement: ProEntitlementSnapshot, age: Int, season: Int, week: Int, level: ProLevel, role: ProRole, managerTrust: Int, catcherTrust: Int, fatigue: Int, injuryWeeks: Int, serviceYears: Int, militaryCompleted: Bool, contract: ProContractSnapshot?, currentStats: ProSeasonStats, careerStats: [ProSeasonStats], awards: [String], milestones: [String], news: [String], hallOfFameScore: Int?, commitment: String, balanceVersion: Int? = nil, seasonSegment: ProSeasonSegment? = nil, seasonTrigger: ProSeasonTrigger? = nil, currentRival: ProRivalBatter? = nil, seasonTensions: [ProSeasonTension]? = nil, seasonImportantGames: Int? = nil) {
        self.proCareerID = proCareerID; self.revision = revision; self.phase = phase; self.identity = identity; self.pitcher = pitcher; self.team = team; self.entitlement = entitlement; self.age = age; self.season = season; self.week = week; self.level = level; self.role = role; self.managerTrust = managerTrust; self.catcherTrust = catcherTrust; self.fatigue = fatigue; self.injuryWeeks = injuryWeeks; self.serviceYears = serviceYears; self.militaryCompleted = militaryCompleted; self.contract = contract; self.currentStats = currentStats; self.careerStats = careerStats; self.awards = awards; self.milestones = milestones; self.news = news; self.hallOfFameScore = hallOfFameScore; self.commitment = commitment; self.balanceVersion = balanceVersion; self.seasonSegment = seasonSegment; self.seasonTrigger = seasonTrigger; self.currentRival = currentRival; self.seasonTensions = seasonTensions; self.seasonImportantGames = seasonImportantGames
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
        let base = ProCareerSnapshot(proCareerID: id, revision: 0, phase: .contractOffer, identity: params.identity, pitcher: params.pitcher, team: team, entitlement: params.entitlement, age: 19, season: 1, week: 0, level: .minor, role: .starter, managerTrust: 42, catcherTrust: 45, fatigue: 0, injuryWeeks: 0, serviceYears: 0, militaryCompleted: false, contract: nil, currentStats: stats, careerStats: [], awards: [], milestones: ["프로 지명"], news: ["신인 계약 제안 · \(team.name) · \(params.identity.name)"], hallOfFameScore: nil, commitment: "", balanceVersion: PitcherPresetCatalog.balanceVersion, seasonSegment: .springCamp, seasonImportantGames: 0)
        let state = signed(base)
        return result(state, nextSeed: String(rng.next()), events: ["pro_career_started"])
    }

    public func normalizeBalance(_ params: ProStateParams) throws -> ProCareerResult {
        _ = try generator(params.seed)
        try validateState(params.state)
        let sourceVersion = params.state.balanceVersion
            ?? PitcherPresetCatalog.inferredLegacyVersion(for: params.state.pitcher)
        let pitcher = PitcherPresetCatalog.migrate(params.state.pitcher, fromVersion: sourceVersion)?.pitcher
            ?? params.state.pitcher
        let normalized = signed(replacing(params.state, pitcher: pitcher,
            balanceVersion: PitcherPresetCatalog.balanceVersion))
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
            }
        }
        let games = restingWeek ? 0 : outings
        let starts = restingWeek ? 0 : (state.role == .starter ? 1 : 0)
        let innings = weekLine.outs / 3
        let strikeouts = weekLine.strikeouts
        let walks = weekLine.walks
        let runs = weekLine.runsAllowed
        let fatigueDelta = recovering || params.plan == .recover ? -20
            : params.plan == .buildStamina ? 13 : params.plan == .developWeapon ? 15 : 10
        let fatigue = clamp(state.fatigue + fatigueDelta, 0, 100)
        let injuryRoll = rng.nextInt(upperBound: 100)
        let newInjury = !recovering && injuryRoll < max(2, fatigue - 72) ? 2 + rng.nextInt(upperBound: 4) : max(0, state.injuryWeeks - 1)
        let trustGain = recovering ? -1 : params.plan == .earnTrust ? 5 : params.plan == .recover ? 0 : (runs <= 2 ? 3 : 0)
        let trust = clamp(state.managerTrust + trustGain, 0, 100)
        let stats = ProSeasonStats(season: state.season, teamID: state.team.id, games: state.currentStats.games + games, starts: state.currentStats.starts + starts, inningsOuts: state.currentStats.inningsOuts + weekLine.outs, strikeouts: state.currentStats.strikeouts + strikeouts, walks: state.currentStats.walks + walks, runsAllowed: state.currentStats.runsAllowed + runs, wins: state.currentStats.wins + (runs <= 2 && starts > 0 ? 1 : 0), saves: state.currentStats.saves + (runs == 0 && state.role == .closer ? 1 : 0))
        let earnedCallUp = trust >= 60 && skill >= 46
            && (state.season > 1 || stats.games >= 12 || stats.strikeouts >= 40)
        let level: ProLevel = state.level == .major || earnedCallUp ? .major : .minor
        let role: ProRole = level == .major
            ? trust >= 74 ? .starter : trust >= 62 ? .longRelief : .setup
            : trust >= 52 ? .starter : .longRelief
        let growth = params.plan == .recover || recovering || params.plan == .earnTrust ? 0 : nextWeek % 2 == 1 ? 1 : 0
        let pitcher = grow(state.pitcher, plan: params.plan, amount: growth)
        let callUpGame = state.level != level && level == .major
        let priorImportantGames = state.seasonImportantGames ?? 0
        let trigger: ProSeasonTrigger? = nextWeek >= 24 ? nil
            : importantGameTrigger(state: state, nextWeek: nextWeek, newLevel: level, newTrust: trust, seasonStrikeouts: stats.strikeouts, skill: skill, priorImportantGames: priorImportantGames)
        let phase: ProCareerPhase = nextWeek >= 24 ? .seasonReview
            : trigger != nil ? .importantGame : .weeklyPlan
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
            milestones = addingUnique("1군 콜업", to: milestones)
            news.insert("2군 기록과 감독의 믿음을 쌓아 1군 출전 명단에 합류했습니다.", at: 0)
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
        let updated = replacing(state, revision: state.revision + 1, phase: phase, pitcher: pitcher, week: nextWeek, level: level, role: role, managerTrust: trust, fatigue: fatigue, injuryWeeks: newInjury, currentStats: stats, milestones: milestones, news: Array(news.prefix(30)), seasonSegment: nextSegment, seasonTrigger: trigger, currentRival: rival, seasonTensions: seasonTensionsValue, seasonImportantGames: importantGames)
        return result(updated, nextSeed: String(rng.next()), events: ["pro_week_resolved", callUpGame ? "major_call_up" : "weekly_progress"])
    }

    public func resolveImportantGame(_ params: ResolveProGameParams) throws -> ProCareerResult {
        try validate(params.state, phase: .importantGame)
        var rng = try generator(params.seed)
        let report = params.report
        let soundProcess = report.actualDamage <= report.expectedDamage + 150 || report.recommendationAccepted * 2 >= report.pitches
        let trust = clamp(params.state.managerTrust + report.strikeouts * 2 - report.walks * 2 - report.runsAllowed * 3 + (soundProcess ? 2 : 0), 0, 100)
        let stats = ProSeasonStats(season: params.state.season, teamID: params.state.team.id, games: params.state.currentStats.games + 1, starts: params.state.currentStats.starts + (params.state.role == .starter ? 1 : 0), inningsOuts: params.state.currentStats.inningsOuts + max(3, report.pitches / 5), strikeouts: params.state.currentStats.strikeouts + report.strikeouts, walks: params.state.currentStats.walks + report.walks, runsAllowed: params.state.currentStats.runsAllowed + report.runsAllowed, wins: params.state.currentStats.wins + (report.runsAllowed == 0 && params.state.role == .starter ? 1 : 0), saves: params.state.currentStats.saves + (report.runsAllowed == 0 && params.state.role == .closer ? 1 : 0))
        let trustDelta = trust - params.state.managerTrust
        let evaluation = soundProcess ? "고른 구종과 코스도 좋았다는 평가를 받았습니다." : "경기 결과와 별개로 구종 순서를 다시 맞춥니다."
        let foe = params.state.currentRival.map { "\($0.name)(\($0.teamName)) 상대 · " } ?? ""
        let news = ["중요 경기 · \(foe)\(report.strikeouts)탈삼진 · \(report.walks)볼넷 · \(report.runsAllowed)실점 · 감독의 믿음 \(trustDelta >= 0 ? "+" : "")\(trustDelta). \(evaluation)"] + params.state.news
        var milestones = params.state.milestones
        if params.state.level == .major { milestones = addingUnique("1군 첫 중요 승부", to: milestones) }
        let clearedRival: ProRivalBatter? = nil
        let clearedTrigger: ProSeasonTrigger? = nil
        let updated = replacing(params.state, revision: params.state.revision + 1, phase: .weeklyPlan, managerTrust: trust, catcherTrust: clamp(params.state.catcherTrust + (soundProcess ? 2 : -1), 0, 100), currentStats: stats, milestones: milestones, news: Array(news.prefix(30)), seasonTrigger: clearedTrigger, currentRival: clearedRival)
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
        let baseAdvanced = replacing(state, revision: state.revision + 1, phase: .weeklyPlan, pitcher: pitcher, team: team, age: age, season: season, week: 0, fatigue: 0, injuryWeeks: 0, serviceYears: service, militaryCompleted: military, contract: contract, currentStats: ProSeasonStats(season: season, teamID: team.id), news: Array(news.prefix(30)))
        let tensions = seasonTensions(for: baseAdvanced)
        let clearedRival: ProRivalBatter? = nil
        let clearedTrigger: ProSeasonTrigger? = nil
        let updated = replacing(baseAdvanced, news: Array(([tensionHeadline(tensions)] + baseAdvanced.news).prefix(30)), seasonSegment: .springCamp, seasonTrigger: clearedTrigger, currentRival: clearedRival, seasonTensions: tensions, seasonImportantGames: 0)
        return result(updated, nextSeed: String(rng.next()), events: ["pro_offseason_resolved"])
    }

    public static let proTeams: [DraftTeamSnapshot] = HighSchoolCareerEngine.teams

    private func validate(_ state: ProCareerSnapshot, phase: ProCareerPhase) throws {
        guard state.phase == phase else { throw SimulationError.invalidProCareer("expected \(phase.rawValue), got \(state.phase.rawValue)") }
        try validateState(state)
    }
    private func validateState(_ state: ProCareerSnapshot) throws {
        guard state.commitment == commitment(state) else { throw SimulationError.invalidProCareer("state commitment mismatch") }
    }
    private func generator(_ seed: String) throws -> SplitMix64 { guard let value = UInt64(seed) else { throw SimulationError.invalidSeed(seed) }; return SplitMix64(seed: value) }

    /// 주간 자동 등판 집계. 수동 중요 경기와 같은 커널이 만든 결과라 통계 분포가 연속적이다.
    struct WeeklyOutingLine {
        var outs = 0
        var strikeouts = 0
        var walks = 0
        var runsAllowed = 0
        var pitches = 0
    }

    /// 주간 자동 등판을 PitchKernelEngine 실제 타석 루프로 실행한다(투구 UI 없이 결과만 집계).
    /// 상대는 리그 평균(50) 기준 시드 변주 타자이고 좌우 타석도 섞인다. 투수의 피로는
    /// 커널의 구속·제구 저하로 그대로 반영되므로 "지친 주의 등판"은 자연히 나빠진다.
    func simulateWeeklyOuting(
        pitcher: PitcherSnapshot,
        startingFatigue: Int,
        outsTarget: Int,
        pitchCap: Int,
        baseSeed: UInt64
    ) -> WeeklyOutingLine {
        let engine = PitchKernelEngine()
        var rng = SplitMix64(seed: baseSeed)
        var line = WeeklyOutingLine()
        let fielders = FielderPosition.allCases.map {
            FielderSnapshot(id: "week-\($0.rawValue)", name: $0.rawValue, position: $0, range: 50, glove: 50, arm: 50)
        }
        var inningState = InningStateSnapshot(inning: 1, half: .top, outs: 0)
        var runners = BaserunnerStateSnapshot(firstOccupied: false, secondOccupied: false, thirdOccupied: false, leadRunnerSpeed: 52)
        var runsOnBoard = 0
        var carriedGameLog = GameLogSnapshot(gameID: "week-outing", revision: 0, totalPitches: 0, entries: [])
        var currentFatigue = clamp(startingFatigue, 0, 95)
        var paIndex = 0
        while line.outs < outsTarget && line.pitches < pitchCap && paIndex < 60 {
            paIndex += 1
            let batter = BatterSnapshot(
                id: "week-batter-\(paIndex)", name: "상대 타선",
                contact: clamp(50 + rng.nextInt(upperBound: 9) - 4, 20, 80),
                discipline: clamp(50 + rng.nextInt(upperBound: 7) - 3, 20, 80),
                power: clamp(50 + rng.nextInt(upperBound: 9) - 4, 20, 80),
                batSide: rng.nextInt(upperBound: 100) < 32 ? .left : .right
            )
            let scouting = BatterScoutingSnapshot(
                hotZone: PitchZone(row: rng.nextInt(upperBound: 3), column: rng.nextInt(upperBound: 3)),
                coldZone: PitchZone(row: rng.nextInt(upperBound: 3), column: rng.nextInt(upperBound: 3)),
                pitchStrength: .fourSeam,
                pitchWeakness: rng.nextInt(upperBound: 2) == 0 ? .slider : .changeup,
                chaseTendency: clamp(48 + rng.nextInt(upperBound: 9) - 4, 20, 80)
            )
            var gameState = GameStateSnapshot(
                defense: DefenseSnapshot(infield: 50, outfield: 50, arm: 50, fielders: fielders),
                park: ParkSnapshot(id: "league-week-park", name: "리그 구장", hitFactor: 1_000, homeRunFactor: 1_000),
                runners: runners, runsAllowed: runsOnBoard, inningState: inningState
            )
            var gameLog = carriedGameLog
            var context = PlateAppearanceContext(
                plateAppearanceID: "week-pa-\(paIndex)", revision: 0,
                inning: inningState.inning, outs: inningState.outs,
                balls: 0, strikes: 0, pitchNumber: 1,
                scoreDifferential: 0, leverage: 500, fatigue: currentFatigue
            )
            var seed = String(max(1, rng.next() >> 1))
            var paMemory: RivalMemorySnapshot?
            guard var preparation = try? engine.preparePitch(PreparePitchParams(
                seed: seed, pitcher: pitcher, batter: batter, scouting: scouting,
                context: context, rivalMemory: paMemory, gameState: gameState, gameLog: gameLog
            )) else { break }
            let outsBefore = (inningState.inning - 1) * 3 + inningState.outs
            while true {
                guard let result = try? engine.submitPitch(SubmitPitchParams(
                    seed: seed, pitcher: pitcher, batter: batter, scouting: scouting,
                    context: context, preparationToken: preparation.preparationToken,
                    call: preparation.primaryRecommendation.call,
                    rivalMemory: paMemory, gameState: gameState, gameLog: gameLog
                )) else { return line }
                paMemory = result.rivalMemory
                gameState = result.gameState
                gameLog = result.gameLog
                line.pitches += 1
                currentFatigue = clamp(result.snapshot.fatigueAfterPitch, 0, 95)
                if let paResult = result.snapshot.result {
                    if paResult == .strikeout { line.strikeouts += 1 }
                    if paResult == .walk { line.walks += 1 }
                }
                if result.snapshot.ended {
                    line.runsAllowed += result.snapshot.runsScored
                    runsOnBoard = result.gameState.runsAllowed
                    carriedGameLog = result.gameLog
                    inningState = result.gameState.inningState ?? inningState
                    runners = result.gameState.runners
                    let outsAfter = (inningState.inning - 1) * 3 + inningState.outs
                    line.outs += max(0, outsAfter - outsBefore)
                    break
                }
                seed = result.nextSeed
                context = PlateAppearanceContext(
                    plateAppearanceID: context.plateAppearanceID,
                    revision: result.revision,
                    inning: result.gameState.inningState?.inning ?? context.inning,
                    outs: result.gameState.inningState?.outs ?? context.outs,
                    balls: result.snapshot.balls,
                    strikes: result.snapshot.strikes,
                    pitchNumber: context.pitchNumber + 1,
                    scoreDifferential: context.scoreDifferential,
                    leverage: context.leverage,
                    fatigue: currentFatigue
                )
                guard let nextPreparation = result.nextPreparation else { return line }
                preparation = nextPreparation
            }
        }
        return line
    }
    private func signed(_ state: ProCareerSnapshot) -> ProCareerSnapshot { replacing(state, commitment: commitment(state)) }
    private func result(_ state: ProCareerSnapshot, nextSeed: String, events: [String]) -> ProCareerResult { let value = signed(state); return ProCareerResult(snapshot: value, nextSeed: nextSeed, events: events) }
    private func commitment(_ s: ProCareerSnapshot) -> String {
        var values = [s.proCareerID, String(s.revision), s.phase.rawValue, s.team.id, String(s.age), String(s.season), String(s.week), s.level.rawValue, s.role.rawValue, String(s.managerTrust), String(s.fatigue), String(s.currentStats.games), String(s.currentStats.strikeouts), String(s.careerStats.count)]
        if let balanceVersion = s.balanceVersion { values.append("balance_version:\(balanceVersion)") }
        return StableHash.fnv1a64(values.joined(separator: "|"))
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

    private func replacing(_ s: ProCareerSnapshot, revision: UInt64? = nil, phase: ProCareerPhase? = nil, pitcher: PitcherSnapshot? = nil, team: DraftTeamSnapshot? = nil, age: Int? = nil, season: Int? = nil, week: Int? = nil, level: ProLevel? = nil, role: ProRole? = nil, managerTrust: Int? = nil, catcherTrust: Int? = nil, fatigue: Int? = nil, injuryWeeks: Int? = nil, serviceYears: Int? = nil, militaryCompleted: Bool? = nil, contract: ProContractSnapshot?? = nil, currentStats: ProSeasonStats? = nil, careerStats: [ProSeasonStats]? = nil, awards: [String]? = nil, milestones: [String]? = nil, news: [String]? = nil, hallOfFameScore: Int?? = nil, balanceVersion: Int? = nil, commitment: String? = nil, seasonSegment: ProSeasonSegment? = nil, seasonTrigger: ProSeasonTrigger?? = nil, currentRival: ProRivalBatter?? = nil, seasonTensions: [ProSeasonTension]?? = nil, seasonImportantGames: Int? = nil) -> ProCareerSnapshot {
        ProCareerSnapshot(proCareerID: s.proCareerID, revision: revision ?? s.revision, phase: phase ?? s.phase, identity: s.identity, pitcher: pitcher ?? s.pitcher, team: team ?? s.team, entitlement: s.entitlement, age: age ?? s.age, season: season ?? s.season, week: week ?? s.week, level: level ?? s.level, role: role ?? s.role, managerTrust: managerTrust ?? s.managerTrust, catcherTrust: catcherTrust ?? s.catcherTrust, fatigue: fatigue ?? s.fatigue, injuryWeeks: injuryWeeks ?? s.injuryWeeks, serviceYears: serviceYears ?? s.serviceYears, militaryCompleted: militaryCompleted ?? s.militaryCompleted, contract: contract ?? s.contract, currentStats: currentStats ?? s.currentStats, careerStats: careerStats ?? s.careerStats, awards: awards ?? s.awards, milestones: milestones ?? s.milestones, news: news ?? s.news, hallOfFameScore: hallOfFameScore ?? s.hallOfFameScore, commitment: commitment ?? "", balanceVersion: balanceVersion ?? s.balanceVersion, seasonSegment: seasonSegment ?? s.seasonSegment, seasonTrigger: seasonTrigger ?? s.seasonTrigger, currentRival: currentRival ?? s.currentRival, seasonTensions: seasonTensions ?? s.seasonTensions, seasonImportantGames: seasonImportantGames ?? s.seasonImportantGames)
    }
}
