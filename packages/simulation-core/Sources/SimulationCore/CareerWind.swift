import Foundation

/// 이번 회차의 바람 — 회차마다 세계의 조건이 조금 다르다.
///
/// 로그라이트의 회차는 "같은 3년의 반복"이 아니라 "매번 조금 다른 판"이어야 한다.
/// 카르마(자기 선택)와 달리 바람은 세계가 정한다: 라이벌 세대가 유난히 센 해,
/// 스카우트의 시선이 처음부터 따라붙는 해, 아무도 주목하지 않는 조용한 해.
///
/// **careerID의 순수 함수다.** 상태에 저장하지 않는다 — 시작할 때 효과(라이벌 보정·
/// 시작 팬 관심·야구혼 회수율)를 스냅샷의 기존 필드에 새겨 넣고, 표시가 필요한 화면은
/// 언제든 careerID로 다시 계산한다. 저장 호환 문제가 원천적으로 없다.
public struct CareerWind: Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    /// 라이벌 능력 보정. 센 해는 +, 조용한 해는 −.
    public let rivalBonus: Int
    /// 시작 팬 관심(기본 5 대신 쓰는 값).
    public let startingFanInterest: Int
    /// 야구혼 회수율 가산(‰). 어려운 바람일수록 회차의 끝이 진하다.
    public let rewardBonusPermille: Int

    /// 바람의 절반은 "바람 없는 해"다. 매 회차가 특별하면 어떤 회차도 특별하지 않다.
    static let all: [CareerWind] = [
        CareerWind(id: "calm", title: "바람 없는 해",
            detail: "특별할 것 없는 평범한 해입니다. 실력만이 말합니다.",
            rivalBonus: 0, startingFanInterest: 5, rewardBonusPermille: 0),
        CareerWind(id: "calm", title: "바람 없는 해",
            detail: "특별할 것 없는 평범한 해입니다. 실력만이 말합니다.",
            rivalBonus: 0, startingFanInterest: 5, rewardBonusPermille: 0),
        CareerWind(id: "monster_generation", title: "괴물 세대",
            detail: "전국에 물건들이 쏟아진 해입니다. 라이벌은 세지만, 이런 해를 버틴 야구혼은 진합니다.",
            rivalBonus: 5, startingFanInterest: 5, rewardBonusPermille: 150),
        CareerWind(id: "scout_frenzy", title: "스카우트 풍년",
            detail: "구단들이 일찍부터 움직이는 해입니다. 시선이 처음부터 따라붙습니다.",
            rivalBonus: 0, startingFanInterest: 20, rewardBonusPermille: 0),
        CareerWind(id: "quiet_season", title: "무명의 해",
            detail: "아무도 이 지역을 주목하지 않는 해입니다. 조용히 강해질 시간입니다.",
            rivalBonus: -3, startingFanInterest: 0, rewardBonusPermille: 80),
    ]

    public static func wind(careerID: String) -> CareerWind {
        var generator = SplitMix64(seed: StableHash.fnv1a64Value("\(careerID)|career_wind"))
        return all[generator.nextInt(upperBound: all.count)]
    }

    /// 뉴스 한 줄. 회차 시작에서 바람을 알린다 — 판이 다르다는 것을 모르면 변주가 아니다.
    public var newsLine: String? {
        id == "calm" ? nil : "이번 회차의 바람 — \(title). \(detail)"
    }
}
