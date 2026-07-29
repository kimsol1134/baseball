import XCTest
@testable import SimulationCore

/// 별명은 희소해야 자랑이 된다 — 문턱이 실제로 짠지, 판정이 결정론적인지 본다.
final class NicknameTests: XCTestCase {
    private func performance(
        games: Int = 0, pitches: Int = 0, strikeouts: Int = 0, walks: Int = 0, runsAllowed: Int = 0
    ) -> CareerPerformanceSnapshot {
        CareerPerformanceSnapshot(
            importantGamesCompleted: games, pitches: pitches, strikeouts: strikeouts,
            walks: walks, runsAllowed: runsAllowed, expectedDamage: 0, actualDamage: 0
        )
    }

    /// 커리어 초반에는 아무 별명도 없다. 첫 경기에 별명이 붙으면 별명이 배경이 된다.
    func testEarlyCareerEarnsNothing() {
        XCTAssertTrue(NicknameRules.earned(performance: performance(games: 1, strikeouts: 8)).isEmpty)
        XCTAssertTrue(NicknameRules.earned(performance: performance(games: 2, runsAllowed: 0)).isEmpty)
    }

    func testStrikeoutMachineNeedsTwentyFive() {
        XCTAssertFalse(NicknameRules.earned(performance: performance(games: 4, strikeouts: 24, walks: 20))
            .contains { $0.id == "k-machine" })
        let earned = NicknameRules.earned(performance: performance(games: 4, strikeouts: 25, walks: 20))
        XCTAssertTrue(earned.contains { $0.id == "k-machine" })
        // 이유 문장에 실제 숫자가 들어간다 — "왜"가 없는 별명은 붙지 않은 것과 같다.
        XCTAssertTrue(earned.first { $0.id == "k-machine" }!.reason.contains("25"))
    }

    func testZeroNeedsThreeGamesWithoutARun() {
        XCTAssertTrue(NicknameRules.earned(performance: performance(games: 3, walks: 10, runsAllowed: 0))
            .contains { $0.id == "zero" })
        XCTAssertFalse(NicknameRules.earned(performance: performance(games: 3, walks: 10, runsAllowed: 1))
            .contains { $0.id == "zero" })
    }

    func testPinpointNeedsOneWalkPerGameOrFewer()  {
        XCTAssertTrue(NicknameRules.earned(performance: performance(games: 3, walks: 3, runsAllowed: 5))
            .contains { $0.id == "pinpoint" })
        XCTAssertFalse(NicknameRules.earned(performance: performance(games: 3, walks: 4, runsAllowed: 5))
            .contains { $0.id == "pinpoint" })
    }

    /// 같은 입력 → 같은 결과. 별명 판정에는 난수가 없다.
    func testDeterministic() {
        let sample = performance(games: 4, strikeouts: 30, walks: 2, runsAllowed: 0)
        XCTAssertEqual(NicknameRules.earned(performance: sample), NicknameRules.earned(performance: sample))
    }
}
