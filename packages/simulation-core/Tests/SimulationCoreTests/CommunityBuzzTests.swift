import XCTest
@testable import SimulationCore

/// 반응은 결정론이어야 한다 — 같은 회차의 같은 경기를 언제 봐도 같은 목소리.
final class CommunityBuzzTests: XCTestCase {
    func testDeterministicPerCareerAndGame() {
        let a = CommunityBuzz.reactions(careerID: "c1", gameNumber: 2, strikeouts: 6, walks: 1, runsAllowed: 0)
        let b = CommunityBuzz.reactions(careerID: "c1", gameNumber: 2, strikeouts: 6, walks: 1, runsAllowed: 0)
        XCTAssertEqual(a, b)
        let other = CommunityBuzz.reactions(careerID: "c2", gameNumber: 2, strikeouts: 6, walks: 1, runsAllowed: 0)
        XCTAssertNotEqual(a, other, "careerID가 달라도 같은 반응이면 시드가 죽은 것이다.")
    }

    func testAlwaysThreeLinesAndNoDuplicates() {
        for game in 1...8 {
            let lines = CommunityBuzz.reactions(careerID: "sweep", gameNumber: game, strikeouts: game, walks: game % 4, runsAllowed: game % 5)
            XCTAssertEqual(lines.count, 3)
            XCTAssertEqual(Set(lines).count, 3, "\(game)경기 반응에 중복이 있습니다.")
        }
    }

    func testContextShapesTheVoice() {
        let shutout = CommunityBuzz.reactions(careerID: "ctx", gameNumber: 1, strikeouts: 7, walks: 0, runsAllowed: 0)
        XCTAssertTrue(shutout.contains { $0.contains("무실점") || $0.contains("못 봄") || $0.contains("수첩") || $0.contains("어떻게 되는 거임") })
        let wild = CommunityBuzz.reactions(careerID: "ctx", gameNumber: 2, strikeouts: 1, walks: 4, runsAllowed: 2)
        XCTAssertTrue(wild.contains { $0.contains("볼넷") || $0.contains("제구") || $0.contains("어디로 갈지") })
        let named = CommunityBuzz.reactions(careerID: "ctx", gameNumber: 3, strikeouts: 2, walks: 0, runsAllowed: 1, newNickname: "제로")
        XCTAssertTrue(named.contains { $0.contains("제로") }, "별명이 붙은 날은 그 얘기가 나와야 합니다.")
    }
}
