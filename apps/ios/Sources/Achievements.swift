import Foundation
import SimulationCore

/// 업적 정의와 판정. **순수 함수라 Game Center 없이 테스트할 수 있고, 인증이 안 돼도 앱 안에서
/// 목록이 보인다.** 실제 재접속을 만드는 것은 앱 안의 목록이고, Game Center는 자랑 채널이다
/// (DOC-IOS-TOP §5.2).
enum Achievement: String, CaseIterable, Identifiable, Codable {
    case firstDraft = "first_draft"
    case firstStrikeout = "first_strikeout"
    case cleanInning = "clean_inning"
    case perfectDelivery = "perfect_delivery"
    case majorDebut = "major_debut"
    case hundredStrikeouts = "hundred_strikeouts"
    case thirdLife = "third_life"
    case fifthLife = "fifth_life"
    case tenthLife = "tenth_life"
    case karmaRun = "karma_run"
    case doubleKarma = "double_karma"
    case awakenedThrice = "awakened_thrice"
    case fourSchools = "four_schools"
    case fiveDrafts = "five_drafts"
    case hallOfFame = "hall_of_fame"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstDraft: "이름이 불렸다"
        case .firstStrikeout: "첫 삼진"
        case .cleanInning: "무실점 이닝"
        case .perfectDelivery: "완벽한 릴리스"
        case .majorDebut: "1군 데뷔"
        case .hundredStrikeouts: "한 시즌 100탈삼진"
        case .thirdLife: "세 번째 도전"
        case .fifthLife: "다섯 번째 인생"
        case .tenthLife: "열 번째 인생"
        case .karmaRun: "짐을 지고"
        case .doubleKarma: "두 짐을 지고"
        case .awakenedThrice: "세 번 각성"
        case .fourSchools: "네 갈래 길"
        case .fiveDrafts: "다섯 번의 호명"
        case .hallOfFame: "명예의 전당"
        }
    }

    var detail: String {
        switch self {
        case .firstDraft: "고교 드래프트에서 지명을 받습니다."
        case .firstStrikeout: "중요 경기에서 삼진을 하나 잡습니다."
        case .cleanInning: "중요 경기를 실점 없이 끝냅니다."
        case .perfectDelivery: "릴리스와 조준이 모두 900 이상인 공을 던집니다."
        case .majorDebut: "프로 1군에 올라갑니다."
        case .hundredStrikeouts: "한 시즌에 100개의 삼진을 잡습니다."
        case .thirdLife: "3회차를 시작합니다."
        case .fifthLife: "5회차를 시작합니다."
        case .tenthLife: "10회차를 시작합니다."
        case .karmaRun: "핸디캡을 안고 시작한 회차로 드래프트까지 갑니다."
        case .doubleKarma: "핸디캡 두 개를 안고 시작한 회차로 드래프트까지 갑니다."
        case .awakenedThrice: "한 회차에서 각성을 세 번 고릅니다."
        case .fourSchools: "서로 다른 학교 네 곳에서 회차를 마칩니다."
        case .fiveDrafts: "통산 다섯 번 지명을 받습니다."
        case .hallOfFame: "명예의 전당 점수 70을 넘깁니다."
        }
    }

    /// Game Center에 등록할 식별자. App Store Connect에서 같은 값으로 만든다.
    var gameCenterID: String { "com.solkim.baseball.achievement.\(rawValue)" }
}

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
    static func fromArchive(_ records: [HighSchoolCareerStore.LifeRecord]) -> [Achievement] {
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
        case .highestLife: "최고 회차"
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
