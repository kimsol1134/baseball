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

    /// 세계 뉴스 — 결정론이고, 랭킹 명단의 같은 인물들이 움직인다.
    func testRivalNewsIsDeterministicAndNamesRankedRivals() {
        let a = CommunityBuzz.rivalNews(careerID: "w", chapterNumber: 3)
        XCTAssertEqual(a, CommunityBuzz.rivalNews(careerID: "w", chapterNumber: 3))
        XCTAssertEqual(a.count, 2)
        XCTAssertNotEqual(a, CommunityBuzz.rivalNews(careerID: "w", chapterNumber: 4))
        let board = ProspectRanking.board(careerID: "w", playerName: "", playerSchool: "",
                                          performance: CareerPerformanceSnapshot())
        XCTAssertTrue(a.allSatisfy { line in board.contains { line.contains($0.name) } },
                      "뉴스의 주인공은 랭킹 명단의 인물이어야 합니다.")
    }

    /// 같은 챕터의 두 소식이 같은 템플릿이면 세계가 아니라 문자열 치환이 보인다.
    func testRivalNewsNeverRepeatsATemplateWithinAChapter() {
        for chapter in 1...8 {
            let lines = CommunityBuzz.rivalNews(careerID: "dup", chapterNumber: chapter)
            // 템플릿 구별자: 문장의 꼬리(고정부). 같은 꼬리가 두 번이면 실패.
            let tails = lines.map { String($0.suffix(12)) }
            XCTAssertEqual(Set(tails).count, lines.count, "\(chapter)챕터 소식이 같은 틀입니다: \(lines)")
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
