import Foundation
import SimulationCore
import BaseballIOSDomain

/// 지금까지 달성한 업적. 로컬이 원본이고 Game Center는 여기서 파생된다.
struct AchievementProgress: Codable, Equatable {
    private(set) var unlocked: Set<Achievement> = []

    var isEmpty: Bool { unlocked.isEmpty }

    func has(_ achievement: Achievement) -> Bool { unlocked.contains(achievement) }

    /// 새로 달성한 것만 돌려준다. 화면은 이 목록으로 축하 배너를 띄우고, Game Center에는
    /// 이것만 보낸다.
    mutating func unlock(_ achievements: [Achievement]) -> [Achievement] {
        let fresh = achievements.filter { !unlocked.contains($0) }
        unlocked.formUnion(fresh)
        return fresh
    }
}

/// 상태에서 달성 조건을 읽는 순수 판정기.
enum AchievementRules {
    static func fromHighSchool(_ state: HighSchoolCareerSnapshot) -> [Achievement] {
        var earned: [Achievement] = []
        if state.draftResult?.outcome == .drafted { earned.append(.firstDraft) }
        if state.performance.strikeouts >= 1 { earned.append(.firstStrikeout) }
        if state.selectedAwakenings.count >= 3 { earned.append(.awakenedThrice) }
        if !state.karmas.isEmpty, state.draftResult != nil { earned.append(.karmaRun) }
        if state.karmas.count >= 2, state.draftResult != nil { earned.append(.doubleKarma) }
        return earned
    }

    /// 회차 아카이브를 가로지르는 수집형. 콘텐츠 풀(학교·지명)을 업적이 가리켜야
    /// "다른 학교로 가 볼까"라는 반복 이유가 생긴다.
    static func fromArchive(_ records: [LifeRecord]) -> [Achievement] {
        var earned: [Achievement] = []
        if Set(records.compactMap(\.schoolName)).count >= 4 { earned.append(.fourSchools) }
        if records.filter(\.drafted).count >= 5 { earned.append(.fiveDrafts) }
        return earned
    }

    static func fromPro(_ state: ProCareerSnapshot) -> [Achievement] {
        var earned: [Achievement] = []
        if state.level == .major { earned.append(.majorDebut) }
        if state.currentStats.strikeouts >= 100 { earned.append(.hundredStrikeouts) }
        if state.careerStats.contains(where: { $0.strikeouts >= 100 }) { earned.append(.hundredStrikeouts) }
        if let score = state.hallOfFameScore, score >= 70 { earned.append(.hallOfFame) }
        return earned
    }

    static func fromInning(report: ImportantInningReport) -> [Achievement] {
        var earned: [Achievement] = []
        if report.strikeouts >= 1 { earned.append(.firstStrikeout) }
        if report.runsAllowed == 0, report.pitches > 0 { earned.append(.cleanInning) }
        return earned
    }

    static func fromDelivery(_ delivery: PitchDelivery?) -> [Achievement] {
        guard let delivery, delivery.releaseAccuracy >= 900, delivery.aimAccuracy >= 900 else { return [] }
        return [.perfectDelivery]
    }

    static func fromLifeNumber(_ lifeNumber: Int) -> [Achievement] {
        var earned: [Achievement] = []
        if lifeNumber >= 3 { earned.append(.thirdLife) }
        if lifeNumber >= 5 { earned.append(.fifthLife) }
        if lifeNumber >= 10 { earned.append(.tenthLife) }
        return earned
    }
}

/// 리더보드. 점수는 이미 코어가 계산하고 있었는데 아무 데도 쓰이지 않았다.
enum Leaderboard: String, CaseIterable {
    case hallOfFame = "hall_of_fame_score"
    case careerStrikeouts = "career_strikeouts"
    case highestLife = "highest_life"

    var gameCenterID: String { "com.solkim.baseball.leaderboard.\(rawValue)" }

    var title: String {
        switch self {
        case .hallOfFame: "명예의 전당 점수"
        case .careerStrikeouts: "통산 탈삼진"
        case .highestLife: "키운 선수 수"
        }
    }
}

enum LeaderboardRules {
    /// 프로 스냅숏에서 제출할 점수를 뽑는다. 값이 없으면 제출하지 않는다.
    static func scores(for state: ProCareerSnapshot) -> [Leaderboard: Int] {
        var scores: [Leaderboard: Int] = [:]
        if let hallOfFame = state.hallOfFameScore { scores[.hallOfFame] = hallOfFame }
        let career = state.careerStats.reduce(0) { $0 + $1.strikeouts } + state.currentStats.strikeouts
        if career > 0 { scores[.careerStrikeouts] = career }
        return scores
    }

    static func scores(lifeNumber: Int) -> [Leaderboard: Int] {
        lifeNumber > 0 ? [.highestLife: lifeNumber] : [:]
    }
}
