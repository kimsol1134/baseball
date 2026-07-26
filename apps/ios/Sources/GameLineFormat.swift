import SwiftUI
import SimulationCore

/// 등판 기록을 화면 문구로 옮긴다.
///
/// 뷰에서 문자열을 조립하면 눈으로만 확인하게 되고, 이닝 표기나 승패 칩 같은 것은
/// 한 번 틀리면 시즌 내내 틀린 채로 남는다. 순수 함수로 빼서 테스트가 지킨다.
enum GameLineFormat {

    /// 승패 칩. 노디시전은 **아무것도 쓰지 않는다** — 대부분의 등판이 노디시전이라
    /// 매 행에 "노디시전"이 붙으면 목록이 그 글자로 뒤덮인다.
    static func decisionLabel(_ decision: PitchingDecision) -> String? {
        switch decision {
        case .win: "승"
        case .loss: "패"
        case .save: "세이브"
        case .noDecision: nil
        }
    }

    static func decisionTone(_ decision: PitchingDecision) -> Color {
        switch decision {
        case .win, .save: BaseballTheme.positive
        case .loss: BaseballTheme.negative
        case .noDecision: BaseballTheme.textTertiary
        }
    }

    /// "선발 6.1이닝" / "구원 1이닝".
    static func role(_ line: ProGameLine) -> String {
        "\(line.started ? "선발" : "구원") \(line.inningsText)이닝"
    }

    /// "7K 2BB 2실점". 피안타를 셀 수 있으면 앞에 붙인다.
    static func pitchingLine(_ line: ProGameLine) -> String {
        var parts: [String] = []
        if let hits = line.hits { parts.append("\(hits)피안타") }
        parts.append("\(line.strikeouts)K")
        parts.append("\(line.walks)BB")
        parts.append("\(line.runsAllowed)실점")
        return parts.joined(separator: " ")
    }

    /// "4:2". 우리 팀이 앞에 온다.
    static func score(_ line: ProGameLine) -> String {
        "\(line.teamRuns):\(line.opponentRuns)"
    }

    /// 9이닝당 실점. 이닝이 0이면 계산할 수 없다.
    static func runsPerNine(outs: Int, runs: Int) -> String {
        guard outs > 0 else { return "—" }
        let value = Double(runs) * 27 / Double(outs)
        return String(format: "%.2f", value)
    }

    /// "9-4-0" 형태의 승-패-세이브.
    static func record(wins: Int, losses: Int, saves: Int) -> String {
        "\(wins)-\(losses)-\(saves)"
    }

    /// 화면 낭독용 한 줄. 칩과 숫자를 따로 읽으면 무슨 경기였는지 알 수 없다.
    static func accessibilityLabel(_ line: ProGameLine) -> String {
        var text = "\(line.week)주차 \(role(line)), \(pitchingLine(line)), \(line.teamRuns) 대 \(line.opponentRuns)"
        if let decision = decisionLabel(line.decision) { text += " \(decision)" }
        if line.played { text += ", 직접 등판" }
        return text
    }
}
