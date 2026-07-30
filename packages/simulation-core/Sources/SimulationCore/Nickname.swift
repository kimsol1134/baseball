import Foundation

/// 세상이 선수를 부르기 시작하는 이름.
///
/// 능력치는 선수의 스펙이고, 별명은 세상이 이 선수를 알아봤다는 증거다. 애착은
/// 두 번째에서 생긴다. 별명은 흔하면 안 되고(희소해야 자랑이 된다), 한 번 얻으면
/// 사라지지 않는다(획득·유지는 스토어가 맡는다 — 여기는 판정만).
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
    /// 구조는 **계열 × 티어**다. 같은 계열 안에서는 가장 높은 티어 하나만 나온다 —
    /// "삼진 사냥꾼"이던 아이가 "탈삼진 머신"이 되는 것이 성장 서사이지,
    /// 두 별명을 동시에 다는 것이 아니다. 부정 별명도 있다 — 세상은 냉정하고,
    /// 그 냉정함이 반등을 서사로 만든다.
    ///
    /// 문턱은 짠 편이다. 회차마다 아무 별명이나 붙으면 별명이 배경이 된다.
    public static func earned(performance: CareerPerformanceSnapshot) -> [Nickname] {
        let games = performance.importantGamesCompleted
        let strikeouts = performance.strikeouts
        let walks = performance.walks
        let runs = performance.runsAllowed
        var earned: [Nickname] = []

        // ── 탈삼진 계열: 쌓을수록 이름이 자란다 ──
        if strikeouts >= 45 {
            earned.append(.init(id: "k-monster", title: "삼진 지옥",
                reason: "통산 탈삼진 \(strikeouts)개 — 상대 타선이 그 이름만으로 흔들립니다."))
        } else if strikeouts >= 25 {
            earned.append(.init(id: "k-machine", title: "탈삼진 머신",
                reason: "통산 탈삼진 \(strikeouts)개 — 배트가 닿지 않습니다."))
        } else if strikeouts >= 15 {
            earned.append(.init(id: "k-hunter", title: "삼진 사냥꾼",
                reason: "통산 탈삼진 \(strikeouts)개 — 2스트라이크가 되면 관중이 일어섭니다."))
        }

        // ── 무실점 계열 ──
        if games >= 5, runs == 0 {
            earned.append(.init(id: "iron-wall", title: "철벽",
                reason: "\(games)경기째 무실점 — 홈플레이트가 잠겨 있습니다."))
        } else if games >= 3, runs == 0 {
            earned.append(.init(id: "zero", title: "제로",
                reason: "\(games)경기째 무실점 — 아직 한 점도 내주지 않았습니다."))
        }

        // ── 제구 계열 ──
        if games >= 4, walks == 0 {
            earned.append(.init(id: "flawless", title: "무결점",
                reason: "\(games)경기 볼넷 0 — 존 밖으로 나가는 공이 없습니다."))
        } else if games >= 3, walks <= games {
            earned.append(.init(id: "pinpoint", title: "핀포인트",
                reason: "경기당 볼넷 1개 이하 — 공이 손끝의 말을 듣습니다."))
        }

        // ── 서사 계열: 조합이 만드는 이름 ──
        if strikeouts >= 30, runs <= games {
            earned.append(.init(id: "untouchable", title: "언터처블",
                reason: "삼진은 쌓이고 실점은 없다 — 고교 레벨을 벗어난 투구라는 평가입니다."))
        }
        if games >= 4, strikeouts >= games * 6 {
            earned.append(.init(id: "nine-k", title: "닥터 나인",
                reason: "경기당 탈삼진 6개 이상 — 아웃 카운트 대부분을 혼자 책임집니다."))
        }
        if games >= 5 {
            earned.append(.init(id: "workhorse", title: "철완",
                reason: "\(games)번의 중요 경기를 전부 소화 — 마운드에서 내려가지 않는 어깨입니다."))
        }

        // ── 부정 계열: 세상은 냉정하다. 이 이름들을 지우는 것이 다음 서사가 된다 ──
        if games >= 3, walks >= games * 3 {
            earned.append(.init(id: "wild-thing", title: "노 컨트롤",
                reason: "경기당 볼넷 3개 — 공이 어디로 갈지 본인도 모른다는 놀림입니다."))
        }
        if games >= 3, runs >= games * 4 {
            earned.append(.init(id: "batting-practice", title: "배팅볼",
                reason: "경기당 실점 4점 — 상대 타자들이 타격 훈련하러 온다는 조롱입니다."))
        }
        if games >= 3, strikeouts >= 15, runs >= games * 3 {
            earned.append(.init(id: "rough-diamond", title: "미완의 대기",
                reason: "삼진을 잡는 재능은 진짜인데 실점이 그만큼 따라옵니다 — 다듬으면 무엇이 될지 모른다는 기대 반 걱정 반."))
        }
        return earned
    }
}
