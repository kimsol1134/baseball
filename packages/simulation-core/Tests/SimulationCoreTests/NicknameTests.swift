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

    /// 같은 계열 안에서는 가장 높은 티어 하나만 나온다 — "사냥꾼"이던 선수가
    /// "머신"이 되는 것이 성장 서사이지, 두 별명을 동시에 다는 것이 아니다.
    func testTiersReplaceWithinAFamily() {
        let monster = NicknameRules.earned(performance: performance(games: 5, strikeouts: 45, walks: 20, runsAllowed: 30))
        XCTAssertTrue(monster.contains { $0.id == "k-monster" })
        XCTAssertFalse(monster.contains { $0.id == "k-machine" })
        XCTAssertFalse(monster.contains { $0.id == "k-hunter" })
        let wall = NicknameRules.earned(performance: performance(games: 5, strikeouts: 5, walks: 20, runsAllowed: 0))
        XCTAssertTrue(wall.contains { $0.id == "iron-wall" })
        XCTAssertFalse(wall.contains { $0.id == "zero" })
    }

    /// 부정 별명 — 세상은 냉정하고, 그 냉정함이 반등을 서사로 만든다.
    func testNegativeNicknamesExist() {
        XCTAssertTrue(NicknameRules.earned(performance: performance(games: 3, strikeouts: 5, walks: 9, runsAllowed: 4))
            .contains { $0.id == "wild-thing" })
        XCTAssertTrue(NicknameRules.earned(performance: performance(games: 3, strikeouts: 5, walks: 2, runsAllowed: 12))
            .contains { $0.id == "batting-practice" })
        XCTAssertTrue(NicknameRules.earned(performance: performance(games: 3, strikeouts: 16, walks: 2, runsAllowed: 10))
            .contains { $0.id == "rough-diamond" })
    }

    /// 도감 크기 상수가 실제 도감과 같은지 — 별명을 추가하고 상수를 잊으면
    /// 아카이브의 "별명 도감 N/13"이 거짓말이 된다.
    func testCatalogCountMatchesReachableNicknames() {
        let probes: [CareerPerformanceSnapshot] = [
            performance(games: 2, strikeouts: 15, walks: 9, runsAllowed: 9),   // k-hunter
            performance(games: 2, strikeouts: 25, walks: 9, runsAllowed: 9),   // k-machine
            performance(games: 2, strikeouts: 45, walks: 9, runsAllowed: 9),   // k-monster
            performance(games: 3, strikeouts: 0, walks: 8, runsAllowed: 0),    // zero
            performance(games: 5, strikeouts: 0, walks: 20, runsAllowed: 0),   // iron-wall
            performance(games: 3, strikeouts: 0, walks: 3, runsAllowed: 2),    // pinpoint
            performance(games: 4, strikeouts: 0, walks: 0, runsAllowed: 2),    // flawless
            performance(games: 2, strikeouts: 30, walks: 9, runsAllowed: 2),   // untouchable
            performance(games: 4, strikeouts: 24, walks: 9, runsAllowed: 20),  // nine-k
            performance(games: 5, strikeouts: 1, walks: 8, runsAllowed: 9),    // workhorse
            performance(games: 3, strikeouts: 1, walks: 9, runsAllowed: 2),    // wild-thing
            performance(games: 3, strikeouts: 1, walks: 2, runsAllowed: 12),   // batting-practice
            performance(games: 3, strikeouts: 16, walks: 2, runsAllowed: 10),  // rough-diamond
        ]
        var ids = Set<String>()
        for probe in probes {
            for nickname in NicknameRules.earned(performance: probe) { ids.insert(nickname.id) }
        }
        XCTAssertEqual(ids.count, NicknameRules.catalogCount)
    }

    /// 같은 입력 → 같은 결과. 별명 판정에는 난수가 없다.
    func testDeterministic() {
        let sample = performance(games: 4, strikeouts: 30, walks: 2, runsAllowed: 0)
        XCTAssertEqual(NicknameRules.earned(performance: sample), NicknameRules.earned(performance: sample))
    }
}
