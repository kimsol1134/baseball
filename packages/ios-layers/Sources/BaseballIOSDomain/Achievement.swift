import Foundation

public enum Achievement: String, CaseIterable, Identifiable, Codable, Sendable {
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

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .firstDraft: "이름이 불렸다"
        case .firstStrikeout: "첫 삼진"
        case .cleanInning: "무실점 이닝"
        case .perfectDelivery: "완벽한 릴리스"
        case .majorDebut: "1군 데뷔"
        case .hundredStrikeouts: "한 시즌 100탈삼진"
        case .thirdLife: "세 번째 도전"
        case .fifthLife: "다섯 번째 도전"
        case .tenthLife: "열 번째 도전"
        case .karmaRun: "짐을 지고"
        case .doubleKarma: "두 짐을 지고"
        case .awakenedThrice: "세 번 각성"
        case .fourSchools: "네 갈래 길"
        case .fiveDrafts: "다섯 번의 호명"
        case .hallOfFame: "명예의 전당"
        }
    }

    public var detail: String {
        switch self {
        case .firstDraft: "고교 드래프트에서 지명을 받습니다."
        case .firstStrikeout: "고교 공식 경기에서 삼진을 하나 잡습니다."
        case .cleanInning: "고교 공식 경기를 실점 없이 끝냅니다."
        case .perfectDelivery: "거의 완벽한 릴리스와 조준으로 한 공을 던집니다."
        case .majorDebut: "프로 1군에 올라갑니다."
        case .hundredStrikeouts: "한 시즌에 100개의 삼진을 잡습니다."
        case .thirdLife: "세 번째 선수를 시작합니다."
        case .fifthLife: "다섯 번째 선수를 시작합니다."
        case .tenthLife: "열 번째 선수를 시작합니다."
        case .karmaRun: "핸디캡을 안고 키운 선수로 드래프트까지 갑니다."
        case .doubleKarma: "핸디캡 두 개를 안고 키운 선수로 드래프트까지 갑니다."
        case .awakenedThrice: "한 선수에게서 각성을 세 번 고릅니다."
        case .fourSchools: "서로 다른 학교 네 곳에서 선수를 키웁니다."
        case .fiveDrafts: "통산 다섯 번 지명을 받습니다."
        case .hallOfFame: "명예의 전당 점수 70을 넘깁니다."
        }
    }

    public var gameCenterID: String { "com.solkim.baseball.achievement.\(rawValue)" }
}
