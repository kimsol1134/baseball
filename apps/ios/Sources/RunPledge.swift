import Foundation
import SimulationCore

/// 회차 약속(베팅) — 환생의 시작에서 하나를 걸고, 회차의 끝에서 정산한다.
///
/// 목표가 없는 회차는 숙제고, 걸어 둔 목표가 있는 회차는 내기다. 약속은 밸런스
/// 뒷문이 되지 않게 시작 능력에는 아무 영향이 없고, **이행했을 때 야구혼 +15%**만
/// 붙는다 — 회차의 끝을 향해 걸어 둔 도파민이다.
struct RunPledge: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String

    /// 이행 시 야구혼 가산(‰). 코어의 legacyRewardPermille와 같은 단위(1000 = ×1.0).
    static let bonusPermille = 150

    static let all: [RunPledge] = [
        .init(id: "strikeout_master", title: "시즌 40탈삼진",
              detail: "3년 동안 직접 잡는 탈삼진 40개."),
        .init(id: "clean_games", title: "무실점 등판 2회",
              detail: "직접 던진 경기에서 무실점을 두 번 만든다."),
        .init(id: "get_drafted", title: "지명받는다",
              detail: "드래프트에서 이름이 불린다."),
        .init(id: "iron_control", title: "볼넷 8개 이하",
              detail: "시즌을 볼넷 8개 이하로 완주한다(4경기 이상)."),
    ]

    /// 이 회차가 걸 수 있는 세 가지. careerID가 정한다 — 회차마다 다른 내기판이다.
    static func options(careerID: String) -> [RunPledge] {
        var generator = SplitMix64(seed: seedValue("\(careerID)|pledge"))
        var pool = all
        for index in pool.indices.reversed() where index > 0 {
            pool.swapAt(index, generator.nextInt(upperBound: index + 1))
        }
        return Array(pool.prefix(3))
    }

    static func pledge(id: String) -> RunPledge? { all.first { $0.id == id } }

    /// 이행 여부 — 끝난 회차의 스냅샷으로 정산한다. 화면과 정산이 같은 식을 쓴다.
    func achieved(state: HighSchoolCareerSnapshot) -> Bool {
        switch id {
        case "strikeout_master": return state.performance.strikeouts >= 40
        case "clean_games":
            return (state.seasonLog ?? []).filter { $0.played && $0.runsAllowed == 0 }.count >= 2
        case "get_drafted": return state.draftResult?.outcome == .drafted
        case "iron_control":
            return state.performance.importantGamesCompleted >= 4 && state.performance.walks <= 8
        default: return false
        }
    }

    /// 진행 중 한 줄. 대시보드가 "지금 어디까지 왔는지"를 말해 준다.
    func progressLine(state: HighSchoolCareerSnapshot) -> String {
        switch id {
        case "strikeout_master": return "탈삼진 \(state.performance.strikeouts)/40"
        case "clean_games":
            let count = (state.seasonLog ?? []).filter { $0.played && $0.runsAllowed == 0 }.count
            return "무실점 등판 \(count)/2"
        case "get_drafted": return "드래프트에서 결판난다"
        case "iron_control": return "볼넷 \(state.performance.walks)/8 이하 유지"
        default: return ""
        }
    }

    /// 결정론 시드. 커널의 StableHash는 내부 전용이라 같은 FNV-1a를 앱에 둔다.
    private static func seedValue(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return hash
    }
}
