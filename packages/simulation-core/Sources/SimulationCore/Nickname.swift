import Foundation

/// 세상이 선수를 부르기 시작하는 이름.
///
/// 능력치는 내 아이의 스펙이고, 별명은 세상이 내 아이를 알아봤다는 증거다. 애착은
/// 두 번째에서 생긴다. 그래서 별명은 흔하면 안 되고(희소해야 자랑이 된다), 한 번
/// 얻으면 사라지지 않는다(획득·유지는 스토어가 맡는다 — 여기는 판정만).
public struct Nickname: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    /// 사람들이 부르는 말. 따옴표에 넣어 이름 앞에 붙는다 — '제로' 김솔.
    public let title: String
    /// 왜 그렇게 부르기 시작했는가.
    public let reason: String

    public init(id: String, title: String, reason: String) {
        self.id = id
        self.title = title
        self.reason = reason
    }
}

public enum NicknameRules {
    /// 지금까지의 커리어 누적으로 얻을 자격이 있는 별명 전부. 결정론적 순수 함수.
    ///
    /// 문턱은 짠 편이다 — 회차마다 아무 별명이나 붙으면 별명이 배경이 된다.
    /// "제로"처럼 나중에 조건이 깨질 수 있는 별명도 있는데, 한 번 얻은 별명을
    /// 지우지 않는 것은 호출자의 규칙이다(세상은 별명을 회수하지 않는다).
    public static func earned(performance: CareerPerformanceSnapshot) -> [Nickname] {
        var earned: [Nickname] = []
        if performance.strikeouts >= 25 {
            earned.append(Nickname(
                id: "k-machine", title: "탈삼진 머신",
                reason: "통산 탈삼진 \(performance.strikeouts)개 — 배트가 닿지 않습니다."
            ))
        }
        if performance.importantGamesCompleted >= 3, performance.runsAllowed == 0 {
            earned.append(Nickname(
                id: "zero", title: "제로",
                reason: "\(performance.importantGamesCompleted)경기째 무실점 — 아직 한 점도 내주지 않았습니다."
            ))
        }
        if performance.importantGamesCompleted >= 3, performance.walks <= performance.importantGamesCompleted {
            earned.append(Nickname(
                id: "pinpoint", title: "핀포인트",
                reason: "경기당 볼넷 1개 이하 — 공이 손끝의 말을 듣습니다."
            ))
        }
        return earned
    }
}
