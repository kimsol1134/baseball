import Foundation
import SimulationCore

enum RunPledgeTier: String, Codable, CaseIterable {
    case safe
    case bold
    case legendary

    var rewardPermille: Int {
        switch self {
        case .safe: 100
        case .bold: 200
        case .legendary: 350
        }
    }

    var title: String {
        switch self {
        case .safe: "안전"
        case .bold: "도전"
        case .legendary: "전설"
        }
    }
}

struct RunPledgeProgress: Equatable {
    let current: Int
    let target: Int
    let achieved: Bool
    let line: String
    /// Compound predicates can supply the least-complete condition explicitly. Without this,
    /// a four-game goal with badly missed control/health would incorrectly look 99.9% complete.
    let unachievedRatioPermille: Int?

    init(
        current: Int,
        target: Int,
        achieved: Bool,
        line: String,
        unachievedRatioPermille: Int? = nil
    ) {
        self.current = current
        self.target = target
        self.achieved = achieved
        self.line = line
        self.unachievedRatioPermille = unachievedRatioPermille
    }

    var ratioPermille: Int {
        guard target > 0 else { return achieved ? 1_000 : 0 }
        // Some pledges have a second condition that is not represented by the
        // numeric numerator (for example, four games *and* a walk limit). Keep
        // an unmet compound pledge distinct from a completed one in UI and
        // analytics even when its count target is full.
        if achieved { return 1_000 }
        if let unachievedRatioPermille {
            return min(999, max(0, unachievedRatioPermille))
        }
        return min(999, max(0, current) * 1_000 / target)
    }

    /// Event properties named `ratio` use the analytics-standard normalized 0...1 range.
    var ratio: Double { Double(ratioPermille) / 1_000 }
}

struct RunPledgeContext {
    let state: HighSchoolCareerSnapshot
    let rivalLedger: HighSchoolCareerStore.RivalLedger
}

struct NextRunIntent: Codable, Equatable {
    let pledgeID: String
    let sourceLifeNumber: Int
    let reason: String
}

/// Player-facing strategy families used by the awakening pledge. Every awakening belongs to
/// exactly one family, so choosing across families is a visible, steerable goal rather than a
/// duplicate of an outing-stat pledge.
enum RunPledgeAwakeningFamily: String, CaseIterable {
    case body
    case command
    case breaking
    case game

    var title: String {
        switch self {
        case .body: "힘·체력"
        case .command: "제구"
        case .breaking: "변화구"
        case .game: "경기 운영"
        }
    }
}

/// A run pledge is behavior plus presentation. Only its stable `id` is persisted.
struct RunPledge: Identifiable, Equatable {
    let id: String
    let tier: RunPledgeTier
    let title: String
    let detail: String
    let rewardPermille: Int
    let eligibility: (HighSchoolCareerSnapshot) -> Bool
    let progress: (RunPledgeContext) -> RunPledgeProgress

    static func == (lhs: RunPledge, rhs: RunPledge) -> Bool { lhs.id == rhs.id }

    /// Computed to avoid sharing closure-bearing values across concurrency domains.
    /// IDs and rules are constants, so each evaluation is still deterministic.
    static let legacyRulesVersion = 1
    static let currentRulesVersion = 2
    /// An intent stores a stable ID but the next player always chooses from the newest catalog.
    /// Keep its reason version-neutral so an old 40-K contract never sits under a new 5-K title.
    static let retryIntentReason = "지난 고교 3년에서 아쉽게 놓친 목표입니다."

    /// The selectable v2 catalog. Older in-progress saves are resolved through `legacyV1` below;
    /// stable IDs alone must never silently rewrite a promise already made to the player.
    static var all: [RunPledge] { [
        make("get_drafted", .safe, "이름이 불린다", "드래프트에서 이름이 불린다.") { context in
            let achieved = context.state.draftResult?.outcome == .drafted
            return .init(current: achieved ? 1 : 0, target: 1, achieved: achieved,
                         line: achieved ? "지명 1/1" : "지명 0/1")
        },
        make("strikeout_master", .bold, "시즌 5탈삼진", "직접 등판 통산 5탈삼진을 만든다.") { context in
            let value = context.state.performance.strikeouts
            return .init(current: value, target: 5, achieved: value >= 5, line: "탈삼진 \(value)/5")
        },
        make("clean_games", .bold, "무실점 등판 4회", "직접 던진 경기에서 무실점을 네 번 만든다.") { context in
            let value = cleanGameCount(context.state)
            return .init(current: value, target: 4, achieved: value >= 4, line: "무실점 등판 \(value)/4")
        },
        make("iron_control", .bold, "무볼넷 4탈삼진", "직접 등판 4경기 이상, 볼넷 없이 통산 4탈삼진을 만든다.") { context in
            controlProgress(context, strikeoutTarget: 4)
        },
        make("healthy_finish", .safe, "팔을 지켜 완주", "고교 공식 경기 네 번을 치르고 피로를 78 이하로 남긴 채 팔 경고 없이 완주한다.") { context in
            let games = context.state.performance.importantGamesCompleted
            let armRisk = context.state.armRisk ?? 0
            let recovery = context.state.injuryRecovery ?? 0
            let fatigue = context.state.fatigue
            let healthy = armRisk < 55 && recovery == 0 && fatigue <= 78
            let armRatio = armRisk < 55 ? 1_000 : max(0, (100 - armRisk) * 1_000 / 46)
            let recoveryRatio = recovery == 0 ? 1_000 : 1_000 / (recovery + 1)
            let fatigueRatio = fatigue <= 78 ? 1_000 : max(0, (100 - fatigue) * 1_000 / 22)
            return .init(
                current: games, target: 4, achieved: games >= 4 && healthy,
                line: "고교 공식 경기 \(games)/4 · 피로 \(fatigue)/78 이하 · \(armRisk < 55 && recovery == 0 ? "팔 상태 안정" : recovery > 0 ? "재활 중" : "팔 상태 경고")",
                unachievedRatioPermille: min(
                    countRatio(games, target: 4), armRatio, recoveryRatio, fatigueRatio
                )
            )
        },
        make("awakening_three", .bold, "세 번의 각성", "각성 세 번을 고르고 서로 다른 전략 계열 세 가지를 모은다.") { context in
            let awakenings = context.state.selectedAwakenings.count
            let families = Set(context.state.selectedAwakenings.map(awakeningFamily(for:))).count
            return .init(
                current: families, target: 3,
                achieved: awakenings >= 3 && families >= 3,
                line: "각성 \(awakenings)/3 · 전략 계열 \(families)/3",
                unachievedRatioPermille: min(
                    countRatio(awakenings, target: 3), countRatio(families, target: 3)
                )
            )
        },
        make("fan_sixty", .bold, "관중의 이름이 된다", "팬 관심을 25 이상으로 올린다.") { context in
            let value = context.state.fanInterest
            return .init(current: value, target: 25, achieved: value >= 25, line: "팬 관심 \(value)/25")
        },
        make("evaluation_sixty_five", .bold, "평가 64점", "드래프트 평가 64점 이상을 받는다.") { context in
            evaluationProgress(context, target: 64)
        },
        make("evaluation_seventy_five", .legendary, "평가 67점", "드래프트 평가 67점 이상을 받는다.") { context in
            evaluationProgress(context, target: 67)
        },
        make("iron_control_five", .legendary, "무볼넷 6탈삼진", "직접 등판 4경기 이상, 볼넷 없이 통산 6탈삼진을 만든다.") { context in
            controlProgress(context, strikeoutTarget: 6)
        },
        make("rival_three_strikeouts", .bold, "숙적에게 세 번 앞선다", "고교 3년 동안 숙적을 세 번 삼진으로 잡는다.") { context in
            let value = context.rivalLedger.strikeouts
            return .init(current: value, target: 3, achieved: value >= 3, line: "숙적 상대 삼진 \(value)/3")
        },
        make("relationship_sixty_five", .safe, "한 사람의 전적인 믿음", "감독·포수·숙적 중 한 관계를 69 이상으로 만든다.") { context in
            let value = max(
                context.state.managerTrust ?? context.state.relationshipTrust,
                max(context.state.catcherTrust ?? context.state.relationshipTrust,
                    context.state.rivalTrust ?? context.state.relationshipTrust)
            )
            return .init(current: value, target: 69, achieved: value >= 69, line: "가장 높은 믿음 \(value)/69")
        },
    ] }

    /// Frozen launch contracts. These four IDs shipped before tiers and calibration existed;
    /// their 150‰ reward and predicates remain authoritative for an already active v1 save.
    static var legacyV1: [RunPledge] { [
        make("strikeout_master", .bold, "시즌 40탈삼진", "3년 동안 직접 잡는 탈삼진 40개.", rewardPermille: 150) { context in
            let value = context.state.performance.strikeouts
            return .init(current: value, target: 40, achieved: value >= 40, line: "탈삼진 \(value)/40")
        },
        make("clean_games", .safe, "무실점 등판 2회", "직접 던진 경기에서 무실점을 두 번 만든다.", rewardPermille: 150) { context in
            let value = cleanGameCount(context.state)
            return .init(current: value, target: 2, achieved: value >= 2, line: "무실점 등판 \(value)/2")
        },
        make("get_drafted", .safe, "지명받는다", "드래프트에서 이름이 불린다.", rewardPermille: 150) { context in
            let achieved = context.state.draftResult?.outcome == .drafted
            return .init(current: achieved ? 1 : 0, target: 1, achieved: achieved,
                         line: achieved ? "지명 1/1" : "지명 0/1")
        },
        make("iron_control", .safe, "볼넷 8개 이하", "시즌을 볼넷 8개 이하로 완주한다(4경기 이상).", rewardPermille: 150) { context in
            let games = context.state.performance.importantGamesCompleted
            let walks = context.state.performance.walks
            let achieved = games >= 4 && walks <= 8
            let walkRatio = walks <= 8 ? 1_000 : max(0, 8_000 / max(1, walks))
            return .init(
                current: games, target: 4, achieved: achieved,
                line: "직접 등판 \(games)/4 · 볼넷 \(walks)/8 이하",
                unachievedRatioPermille: min(countRatio(games, target: 4), walkRatio)
            )
        },
    ] }

    static func pledge(id: String, rulesVersion: Int = currentRulesVersion) -> RunPledge? {
        let catalog = rulesVersion <= legacyRulesVersion ? legacyV1 : all
        return catalog.first { $0.id == id }
    }

    /// Exactly three stable options: prior intent first, then safe/build-aligned/stretch coverage.
    static func options(
        careerID: String,
        state: HighSchoolCareerSnapshot,
        intent: NextRunIntent? = nil
    ) -> [RunPledge] {
        let candidates = all.filter {
            $0.eligibility(state) && (state.lifeNumber > 1 || $0.tier != .legendary)
        }
        let ordered = candidates.sorted {
            optionRank(careerID: careerID, pledgeID: $0.id) < optionRank(careerID: careerID, pledgeID: $1.id)
        }
        var selected: [RunPledge] = []
        if let intent, let carried = ordered.first(where: { $0.id == intent.pledgeID }) {
            selected.append(carried)
        }

        func ensureCoverage(_ predicate: (RunPledge) -> Bool) {
            guard !selected.contains(where: predicate), selected.count < 3,
                  let choice = ordered.first(where: { predicate($0) && !selected.contains($0) }) else { return }
            selected.append(choice)
        }

        let aligned = buildAlignedIDs(state: state)
        ensureCoverage { $0.tier == .safe }
        ensureCoverage { aligned.contains($0.id) }
        ensureCoverage { $0.tier == .legendary || $0.tier == .bold }
        for candidate in ordered where selected.count < 3 && !selected.contains(candidate) {
            selected.append(candidate)
        }
        return Array(selected.prefix(3))
    }

    /// Compatibility overload for older call sites; new UI should supply the state.
    static func options(careerID: String) -> [RunPledge] {
        var generator = SplitMix64(seed: seedValue("\(careerID)|pledge-legacy-options"))
        var pool = Array(all.prefix(4))
        for index in pool.indices.reversed() where index > 0 {
            pool.swapAt(index, generator.nextInt(upperBound: index + 1))
        }
        return Array(pool.prefix(3))
    }

    func progress(in context: RunPledgeContext) -> RunPledgeProgress { progress(context) }

    func achieved(state: HighSchoolCareerSnapshot, rivalLedger: HighSchoolCareerStore.RivalLedger = .init()) -> Bool {
        progress(.init(state: state, rivalLedger: rivalLedger)).achieved
    }

    func progressLine(state: HighSchoolCareerSnapshot, rivalLedger: HighSchoolCareerStore.RivalLedger = .init()) -> String {
        progress(.init(state: state, rivalLedger: rivalLedger)).line
    }

    func alignmentReason(state: HighSchoolCareerSnapshot) -> String {
        if Self.buildAlignedIDs(state: state).contains(id) {
            switch id {
            case "iron_control", "iron_control_five":
                return "제구가 가장 높은 능력이라 볼넷 억제에 잘 맞습니다."
            case "evaluation_sixty_five":
                return "제구 강점을 전체 평가로 이어 가는 목표입니다."
            case "strikeout_master", "clean_games", "evaluation_seventy_five":
                return "구위와 변화구 강점을 경기 결과로 바꾸는 목표입니다."
            case "relationship_sixty_five", "rival_three_strikeouts":
                return "지금 가장 두터운 관계를 승부의 힘으로 잇는 목표입니다."
            case "healthy_finish":
                return "현재 팔 부담을 관리하며 완주하는 데 맞춘 목표입니다."
            case "fan_sixty":
                return "이미 모인 팬 관심을 더 큰 이야기로 잇는 목표입니다."
            default:
                return "지금 키운 강점을 끝까지 증명하는 목표입니다."
            }
        }

        switch tier {
        case .safe:
            return "현재 능력 구성과 무관하게 완주를 노리는 안전 목표입니다."
        case .bold:
            return "현재 강점과 다른 방향까지 넓혀 보는 도전 목표입니다."
        case .legendary:
            return "현재 강점을 넘어 한계를 시험하는 전설 목표입니다."
        }
    }

    func accessibilityLabel(
        progressLine: String,
        carried: Bool = false,
        status: String? = nil
    ) -> String {
        let prefix = carried ? "지난 고교 3년에서 이어진 " : ""
        let statusText = status.map { ", \($0)" } ?? ""
        return "\(prefix)\(tier.title) 목표, \(title), \(progressLine)\(statusText), 보상 계승 포인트 \(rewardPermille / 10)퍼센트 추가"
    }

    func accessibilityLabel(
        progress: RunPledgeProgress,
        carried: Bool = false,
        status: String? = nil
    ) -> String {
        accessibilityLabel(progressLine: progress.line, carried: carried, status: status)
    }

    private static func make(
        _ id: String,
        _ tier: RunPledgeTier,
        _ title: String,
        _ detail: String,
        rewardPermille: Int? = nil,
        eligibility: @escaping (HighSchoolCareerSnapshot) -> Bool = { _ in true },
        progress: @escaping (RunPledgeContext) -> RunPledgeProgress
    ) -> RunPledge {
        RunPledge(id: id, tier: tier, title: title, detail: detail,
                  rewardPermille: rewardPermille ?? tier.rewardPermille,
                  eligibility: eligibility, progress: progress)
    }

    private static func evaluationProgress(_ context: RunPledgeContext, target: Int) -> RunPledgeProgress {
        let value = context.state.draftResult?.evaluationScore
            ?? HighSchoolCareerEngine.draftForecast(state: context.state).score
        return .init(current: value, target: target, achieved: value >= target,
                     line: "평가 \(value)/\(target)")
    }

    private static func controlProgress(
        _ context: RunPledgeContext,
        strikeoutTarget: Int
    ) -> RunPledgeProgress {
        let games = context.state.performance.importantGamesCompleted
        let walks = context.state.performance.walks
        let strikeouts = context.state.performance.strikeouts
        let achieved = games >= 4 && walks == 0 && strikeouts >= strikeoutTarget
        let walkRatio = walks == 0 ? 1_000 : 1_000 / (walks + 1)
        return .init(
            current: strikeouts, target: strikeoutTarget, achieved: achieved,
            line: "직접 등판 \(games)/4 · 볼넷 \(walks)/0 · 탈삼진 \(strikeouts)/\(strikeoutTarget)",
            unachievedRatioPermille: min(
                countRatio(games, target: 4), walkRatio,
                countRatio(strikeouts, target: strikeoutTarget)
            )
        )
    }

    private static func cleanGameCount(_ state: HighSchoolCareerSnapshot) -> Int {
        (state.seasonLog ?? []).filter { $0.played && $0.runsAllowed == 0 }.count
    }

    static func awakeningFamily(for awakening: AwakeningID) -> RunPledgeAwakeningFamily {
        switch awakening {
        case .explosiveFastball, .risingFourSeam, .ironArm, .lateInningReserve:
            .body
        case .pinpointEdge, .repeatableRelease, .firstPitchStrike, .calmUnderPressure, .scoutComposure:
            .command
        case .disappearingBreaker, .sinkerTunnel, .frozenChangeup, .sweepingSlider, .curveballClock:
            .breaking
        case .batterySync, .pickoffRhythm, .twoStrikePlan, .trafficController:
            .game
        }
    }

    private static func countRatio(_ current: Int, target: Int) -> Int {
        guard target > 0 else { return 0 }
        return min(1_000, max(0, current) * 1_000 / target)
    }

    static func buildAlignedIDs(state: HighSchoolCareerSnapshot) -> Set<String> {
        let ratings: [(Int, Set<String>)] = [
            (state.pitcher.command, ["iron_control", "iron_control_five", "evaluation_sixty_five"]),
            (max(state.pitcher.stuff, state.pitcher.movement), ["strikeout_master", "clean_games", "evaluation_seventy_five"]),
            (max(state.managerTrust ?? 0, max(state.catcherTrust ?? 0, state.rivalTrust ?? 0)), ["relationship_sixty_five", "rival_three_strikeouts"]),
        ]
        var ids = ratings.max { $0.0 < $1.0 }?.1 ?? []
        if (state.armRisk ?? 0) >= 35 { ids.insert("healthy_finish") }
        if state.fanInterest >= 35 { ids.insert("fan_sixty") }
        return ids
    }

    private static func optionRank(careerID: String, pledgeID: String) -> UInt64 {
        seedValue("\(careerID)|pledge-v2|\(pledgeID)")
    }

    private static func seedValue(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return hash
    }
}
