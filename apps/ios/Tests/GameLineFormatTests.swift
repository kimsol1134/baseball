import XCTest
import SimulationCore
@testable import BaseballIOS

/// 등판 기록 행의 문구. 한 번 틀리면 시즌 내내 틀린 채로 남는 자리라 표로 못 박는다.
final class GameLineFormatTests: XCTestCase {

    private func line(
        started: Bool = true,
        outs: Int = 19,
        strikeouts: Int = 7,
        walks: Int = 2,
        runs: Int = 2,
        teamRuns: Int = 4,
        opponentRuns: Int = 2,
        decision: PitchingDecision = .win,
        played: Bool = false,
        hits: Int? = nil
    ) -> ProGameLine {
        ProGameLine(
            season: 1, week: 12, outingNumber: 3, started: started, outs: outs,
            strikeouts: strikeouts, walks: walks, runsAllowed: runs, pitches: 94,
            teamRuns: teamRuns, opponentRuns: opponentRuns, decision: decision,
            played: played, hits: hits
        )
    }

    /// 대부분의 등판이 노디시전이다. 매 행에 "노디시전"이 붙으면 목록이 그 글자로 뒤덮인다.
    func testNoDecisionShowsNothing() {
        XCTAssertNil(GameLineFormat.decisionLabel(.noDecision))
        XCTAssertEqual(GameLineFormat.decisionLabel(.win), "승")
        XCTAssertEqual(GameLineFormat.decisionLabel(.loss), "패")
        XCTAssertEqual(GameLineFormat.decisionLabel(.save), "세이브")
    }

    func testRoleAndInningsReadLikeBaseball() {
        XCTAssertEqual(GameLineFormat.role(line(started: true, outs: 19)), "선발 6.1이닝")
        XCTAssertEqual(GameLineFormat.role(line(started: false, outs: 3)), "구원 1이닝")
    }

    /// 피안타를 셀 수 없는 경기(직접 던진 승부)도 행이 성립해야 한다.
    func testPitchingLineWorksWithAndWithoutHits() {
        XCTAssertEqual(GameLineFormat.pitchingLine(line(hits: nil)), "7K 2BB 2실점")
        XCTAssertEqual(GameLineFormat.pitchingLine(line(hits: 5)), "5피안타 7K 2BB 2실점")
    }

    func testScorePutsOurTeamFirst() {
        XCTAssertEqual(GameLineFormat.score(line(teamRuns: 4, opponentRuns: 2)), "4:2")
    }

    func testRecordAndRunsPerNine() {
        XCTAssertEqual(GameLineFormat.record(wins: 9, losses: 4, saves: 0), "9-4-0")
        // 90이닝 40실점 = 4.00
        XCTAssertEqual(GameLineFormat.runsPerNine(outs: 270, runs: 40), "4.00")
        XCTAssertEqual(GameLineFormat.runsPerNine(outs: 0, runs: 0), "—")
    }

    /// 낭독은 한 문장이어야 한다. 칩과 숫자를 따로 읽으면 무슨 경기였는지 알 수 없다.
    func testAccessibilityLabelReadsAsOneSentence() {
        let label = GameLineFormat.accessibilityLabel(line(played: true))
        XCTAssertTrue(label.contains("12주차"))
        XCTAssertTrue(label.contains("선발 6.1이닝"))
        XCTAssertTrue(label.contains("4 대 2"))
        XCTAssertTrue(label.contains("승"))
        XCTAssertTrue(label.contains("직접 등판"))
    }
}
