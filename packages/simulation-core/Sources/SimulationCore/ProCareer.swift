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
    public init(proCareerID: String, revision: UInt64, phase: ProCareerPhase, identity: PlayerIdentitySnapshot, pitcher: PitcherSnapshot, team: DraftTeamSnapshot, entitlement: ProEntitlementSnapshot, age: Int, season: Int, week: Int, level: ProLevel, role: ProRole, managerTrust: Int, catcherTrust: Int, fatigue: Int, injuryWeeks: Int, serviceYears: Int, militaryCompleted: Bool, contract: ProContractSnapshot?, currentStats: ProSeasonStats, careerStats: [ProSeasonStats], awards: [String], milestones: [String], news: [String], hallOfFameScore: Int?, commitment: String) {
        self.proCareerID = proCareerID; self.revision = revision; self.phase = phase; self.identity = identity; self.pitcher = pitcher; self.team = team; self.entitlement = entitlement; self.age = age; self.season = season; self.week = week; self.level = level; self.role = role; self.managerTrust = managerTrust; self.catcherTrust = catcherTrust; self.fatigue = fatigue; self.injuryWeeks = injuryWeeks; self.serviceYears = serviceYears; self.militaryCompleted = militaryCompleted; self.contract = contract; self.currentStats = currentStats; self.careerStats = careerStats; self.awards = awards; self.milestones = milestones; self.news = news; self.hallOfFameScore = hallOfFameScore; self.commitment = commitment
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
        let base = ProCareerSnapshot(proCareerID: id, revision: 0, phase: .contractOffer, identity: params.identity, pitcher: params.pitcher, team: team, entitlement: params.entitlement, age: 19, season: 1, week: 0, level: .minor, role: .starter, managerTrust: 42, catcherTrust: 45, fatigue: 0, injuryWeeks: 0, serviceYears: 0, militaryCompleted: false, contract: nil, currentStats: stats, careerStats: [], awards: [], milestones: ["프로 지명"], news: ["신인 계약 제안 · \(team.name) · \(params.identity.name)"], hallOfFameScore: nil, commitment: "")
        let state = signed(base)
        return result(state, nextSeed: String(rng.next()), events: ["pro_career_started"])
    }

    public func signContract(_ params: ProStateParams) throws -> ProCareerResult {
        try validate(params.state, phase: .contractOffer)
        var rng = try generator(params.seed)
        let bonus = max(30_000_000, params.state.pitcher.stuff * 1_000_000)
        let contract = ProContractSnapshot(yearsRemaining: 3, annualSalary: bonus, rolePromise: .starter)
        let state = replacing(params.state, revision: params.state.revision + 1, phase: .weeklyPlan, contract: contract,
            milestones: addingUnique("신인 계약", to: params.state.milestones),
            news: ["신인 계약에 서명했습니다. 2군 선발 경쟁이 시작됩니다."] + params.state.news)
        return result(state, nextSeed: String(rng.next()), events: ["rookie_contract_signed"])
    }

    public func planWeek(_ params: PlanProWeekParams) throws -> ProCareerResult {
        try validate(params.state, phase: .weeklyPlan)
        var rng = try generator(params.seed)
        let state = params.state
        let nextWeek = state.week + 1
        let recovering = state.injuryWeeks > 0
        let scheduledGames = state.level == .major ? 4 : 5
        let games = recovering ? 0 : params.plan == .recover ? min(2, scheduledGames) : scheduledGames
        let starts = recovering ? 0 : (state.role == .starter ? 1 : 0)
        let skill = (state.pitcher.stuff + state.pitcher.command + state.pitcher.movement + state.pitcher.stamina) / 4
        let variance = rng.nextInt(upperBound: 9) - 4
        let innings = recovering ? 0 : max(3, games * (state.role == .starter ? 5 : 2))
        let strikeouts = max(0, innings * max(25, skill + variance) / 45)
        let walks = max(0, innings * max(8, 70 - state.pitcher.command) / 70)
        let runs = max(0, innings * max(8, 67 - skill - variance) / 80)
        let fatigueDelta = recovering || params.plan == .recover ? -20
            : params.plan == .buildStamina ? 13 : params.plan == .developWeapon ? 15 : 10
        let fatigue = clamp(state.fatigue + fatigueDelta, 0, 100)
        let injuryRoll = rng.nextInt(upperBound: 100)
        let newInjury = !recovering && injuryRoll < max(2, fatigue - 72) ? 2 + rng.nextInt(upperBound: 4) : max(0, state.injuryWeeks - 1)
        let trustGain = recovering ? -1 : params.plan == .earnTrust ? 5 : params.plan == .recover ? 0 : (runs <= 2 ? 3 : 0)
        let trust = clamp(state.managerTrust + trustGain, 0, 100)
        let stats = ProSeasonStats(season: state.season, teamID: state.team.id, games: state.currentStats.games + games, starts: state.currentStats.starts + starts, inningsOuts: state.currentStats.inningsOuts + innings * 3, strikeouts: state.currentStats.strikeouts + strikeouts, walks: state.currentStats.walks + walks, runsAllowed: state.currentStats.runsAllowed + runs, wins: state.currentStats.wins + (runs <= 2 && starts > 0 ? 1 : 0), saves: state.currentStats.saves + (runs == 0 && state.role == .closer ? 1 : 0))
        let earnedCallUp = trust >= 60 && (state.season > 1 || stats.games >= 35 || stats.strikeouts >= 45)
        let level: ProLevel = state.level == .major || earnedCallUp ? .major : .minor
        let role: ProRole = level == .major
            ? trust >= 74 ? .starter : trust >= 62 ? .longRelief : .setup
            : trust >= 52 ? .starter : .longRelief
        let growth = params.plan == .recover || recovering || params.plan == .earnTrust ? 0 : nextWeek % 2 == 1 ? 1 : 0
        let pitcher = grow(state.pitcher, plan: params.plan, amount: growth)
        let importantWeeks: Set<Int> = [3, 7, 12, 18, 23]
        let callUpGame = state.level != level && level == .major
        let phase: ProCareerPhase = nextWeek >= 24 ? .seasonReview
            : importantWeeks.contains(nextWeek) || callUpGame ? .importantGame : .weeklyPlan
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
        if phase == .importantGame {
            news.insert(importantMomentHeadline(week: nextWeek, level: level, trust: trust), at: 0)
        }
        let updated = replacing(state, revision: state.revision + 1, phase: phase, pitcher: pitcher, week: nextWeek, level: level, role: role, managerTrust: trust, fatigue: fatigue, injuryWeeks: newInjury, currentStats: stats, milestones: milestones, news: Array(news.prefix(30)))
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
        let news = ["중요 경기 · \(report.strikeouts)탈삼진 · \(report.walks)볼넷 · \(report.runsAllowed)실점 · 감독의 믿음 \(trustDelta >= 0 ? "+" : "")\(trustDelta). \(evaluation)"] + params.state.news
        var milestones = params.state.milestones
        if params.state.level == .major { milestones = addingUnique("1군 첫 중요 승부", to: milestones) }
        let updated = replacing(params.state, revision: params.state.revision + 1, phase: .weeklyPlan, managerTrust: trust, catcherTrust: clamp(params.state.catcherTrust + (soundProcess ? 2 : -1), 0, 100), currentStats: stats, milestones: milestones, news: Array(news.prefix(30)))
        return result(updated, nextSeed: String(rng.next()), events: ["pro_important_game_resolved"])
    }

    public func reviewSeason(_ params: ProStateParams) throws -> ProCareerResult {
        try validate(params.state, phase: .seasonReview)
        var rng = try generator(params.seed)
        let state = params.state
        let eraPermille = state.currentStats.inningsOuts == 0 ? 9_990 : state.currentStats.runsAllowed * 27_000 / state.currentStats.inningsOuts
        var awards = state.awards
        var milestones = state.milestones
        if state.currentStats.strikeouts >= 120 { awards = addingUnique("시즌 \(state.season) 탈삼진상", to: awards) }
        if eraPermille < 3_000 && state.currentStats.games >= 20 { awards = addingUnique("시즌 \(state.season) 평균자책 우수상", to: awards) }
        milestones = addingUnique("\(state.season)시즌 완주", to: milestones)
        let phase: ProCareerPhase = state.season >= 12 || state.age >= 37 ? .retirementDecision : .offseasonDecision
        let news = ["시즌 \(state.season) 종료 · \(state.currentStats.games)경기 · \(state.currentStats.strikeouts)K · ERA \(String(format: "%.2f", Double(eraPermille) / 1000))"] + state.news
        let updated = replacing(state, revision: state.revision + 1, phase: phase, careerStats: state.careerStats + [state.currentStats], awards: awards, milestones: milestones, news: Array(news.prefix(30)))
        return result(updated, nextSeed: String(rng.next()), events: ["pro_season_reviewed"])
    }

    public func chooseOffseason(_ params: ProOffseasonParams) throws -> ProCareerResult {
        guard [.offseasonDecision, .retirementDecision].contains(params.state.phase) else { throw SimulationError.invalidProCareer("지금은 오프시즌 선택을 할 수 없습니다.") }
        var rng = try generator(params.seed)
        let state = params.state
        if params.decision == .retire || state.phase == .retirementDecision {
            let score = hallOfFameScore(state)
            let news = [score >= 70 ? "명예의 전당 헌액이 확정됐습니다." : "은퇴식에서 선수 생활의 마지막 공을 돌아봤습니다."] + state.news
            let retired = replacing(state, revision: state.revision + 1, phase: .completed, news: news, hallOfFameScore: score)
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
        let pitcher = decline == 0 ? state.pitcher : PitcherSnapshot(id: state.pitcher.id, name: state.pitcher.name, stuff: clamp(state.pitcher.stuff - decline, 20, 80), command: state.pitcher.command, movement: clamp(state.pitcher.movement - decline, 20, 80), stamina: clamp(state.pitcher.stamina - decline, 20, 80), pitchProfiles: state.pitcher.pitchProfiles)
        let contract = ProContractSnapshot(yearsRemaining: max(1, (state.contract?.yearsRemaining ?? 1) - 1), annualSalary: max(state.contract?.annualSalary ?? 40_000_000, 40_000_000 + service * 50_000_000), rolePromise: state.role)
        let updated = replacing(state, revision: state.revision + 1, phase: .weeklyPlan, pitcher: pitcher, team: team, age: age, season: season, week: 0, fatigue: 0, injuryWeeks: 0, serviceYears: service, militaryCompleted: military, contract: contract, currentStats: ProSeasonStats(season: season, teamID: team.id), news: Array(news.prefix(30)))
        return result(updated, nextSeed: String(rng.next()), events: ["pro_offseason_resolved"])
    }

    public static let proTeams: [DraftTeamSnapshot] = HighSchoolCareerEngine.teams

    private func validate(_ state: ProCareerSnapshot, phase: ProCareerPhase) throws {
        guard state.phase == phase else { throw SimulationError.invalidProCareer("expected \(phase.rawValue), got \(state.phase.rawValue)") }
        guard state.commitment == commitment(state) else { throw SimulationError.invalidProCareer("state commitment mismatch") }
    }
    private func generator(_ seed: String) throws -> SplitMix64 { guard let value = UInt64(seed) else { throw SimulationError.invalidSeed(seed) }; return SplitMix64(seed: value) }
    private func signed(_ state: ProCareerSnapshot) -> ProCareerSnapshot { replacing(state, commitment: commitment(state)) }
    private func result(_ state: ProCareerSnapshot, nextSeed: String, events: [String]) -> ProCareerResult { let value = signed(state); return ProCareerResult(snapshot: value, nextSeed: nextSeed, events: events) }
    private func commitment(_ s: ProCareerSnapshot) -> String { StableHash.fnv1a64([s.proCareerID, String(s.revision), s.phase.rawValue, s.team.id, String(s.age), String(s.season), String(s.week), s.level.rawValue, s.role.rawValue, String(s.managerTrust), String(s.fatigue), String(s.currentStats.games), String(s.currentStats.strikeouts), String(s.careerStats.count)].joined(separator: "|")) }
    private func hallOfFameScore(_ state: ProCareerSnapshot) -> Int { clamp(state.careerStats.reduce(0) { $0 + $1.strikeouts } / 75 + state.awards.count * 8 + state.serviceYears * 3, 0, 100) }
    private func addingUnique(_ value: String, to values: [String]) -> [String] { values.contains(value) ? values : values + [value] }
    private func careerGames(_ state: ProCareerSnapshot) -> Int { state.careerStats.reduce(0) { $0 + $1.games } + state.currentStats.games }
    private func careerStrikeouts(_ state: ProCareerSnapshot) -> Int { state.careerStats.reduce(0) { $0 + $1.strikeouts } + state.currentStats.strikeouts }
    private func importantMomentHeadline(week: Int, level: ProLevel, trust: Int) -> String {
        if level == .major && week <= 12 { return "1군에 남을 기회를 잡아야 하는 경기가 잡혔습니다." }
        if week == 23 { return "포스트시즌 출전 명단을 결정할 마지막 경기가 잡혔습니다." }
        if trust < 55 { return "다음 등판 기회를 따내야 하는 경기가 잡혔습니다." }
        return "감독이 선발·불펜 역할을 결정할 경기에서 직접 공을 맡겼습니다."
    }
    private func grow(_ pitcher: PitcherSnapshot, plan: ProWeekPlan, amount: Int) -> PitcherSnapshot {
        PitcherSnapshot(id: pitcher.id, name: pitcher.name,
            stuff: clamp(pitcher.stuff + (plan == .developWeapon ? amount : 0), 20, 80),
            command: clamp(pitcher.command + (plan == .refineCommand || plan == .earnTrust ? amount : 0), 20, 80),
            movement: clamp(pitcher.movement + (plan == .developWeapon ? amount : 0), 20, 80),
            stamina: clamp(pitcher.stamina + (plan == .buildStamina ? amount : 0), 20, 80), pitchProfiles: pitcher.pitchProfiles)
    }
    private func clamp(_ value: Int, _ low: Int, _ high: Int) -> Int { min(high, max(low, value)) }

    private func replacing(_ s: ProCareerSnapshot, revision: UInt64? = nil, phase: ProCareerPhase? = nil, pitcher: PitcherSnapshot? = nil, team: DraftTeamSnapshot? = nil, age: Int? = nil, season: Int? = nil, week: Int? = nil, level: ProLevel? = nil, role: ProRole? = nil, managerTrust: Int? = nil, catcherTrust: Int? = nil, fatigue: Int? = nil, injuryWeeks: Int? = nil, serviceYears: Int? = nil, militaryCompleted: Bool? = nil, contract: ProContractSnapshot?? = nil, currentStats: ProSeasonStats? = nil, careerStats: [ProSeasonStats]? = nil, awards: [String]? = nil, milestones: [String]? = nil, news: [String]? = nil, hallOfFameScore: Int?? = nil, commitment: String? = nil) -> ProCareerSnapshot {
        ProCareerSnapshot(proCareerID: s.proCareerID, revision: revision ?? s.revision, phase: phase ?? s.phase, identity: s.identity, pitcher: pitcher ?? s.pitcher, team: team ?? s.team, entitlement: s.entitlement, age: age ?? s.age, season: season ?? s.season, week: week ?? s.week, level: level ?? s.level, role: role ?? s.role, managerTrust: managerTrust ?? s.managerTrust, catcherTrust: catcherTrust ?? s.catcherTrust, fatigue: fatigue ?? s.fatigue, injuryWeeks: injuryWeeks ?? s.injuryWeeks, serviceYears: serviceYears ?? s.serviceYears, militaryCompleted: militaryCompleted ?? s.militaryCompleted, contract: contract ?? s.contract, currentStats: currentStats ?? s.currentStats, careerStats: careerStats ?? s.careerStats, awards: awards ?? s.awards, milestones: milestones ?? s.milestones, news: news ?? s.news, hallOfFameScore: hallOfFameScore ?? s.hallOfFameScore, commitment: commitment ?? "")
    }
}
