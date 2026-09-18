import XCTest
@testable import SimulationCore

final class CareerRecordTableTests: XCTestCase {
    /// 기록지는 고른 것이 아니라 **정해진 칸이 전부 있는 표**다.
    func testTheCountingTableAlwaysHasTwelveColumnsInScorecardOrder() {
        let entries = CareerRecordTableRules.counting(season())
        XCTAssertEqual(
            entries.map(\.abbreviation),
            ["G", "GS", "W", "L", "SV", "IP", "H", "HR", "BB", "SO", "R", "NP"]
        )
    }

    /// 이닝은 야구 기록지 표기다 — 소수점 뒤는 십진수가 아니라 아웃 개수다.
    func testInningsUseScorecardThirds() {
        let entries = CareerRecordTableRules.counting(season(outs: 190))
        XCTAssertEqual(entries.first { $0.abbreviation == "IP" }?.value, "63.1")
    }

    /// **모르는 값은 `—`이지 0이 아니다.** 원장 없는 시즌의 평균자책이 0.00으로 찍히면
    /// 그 시즌이 완봉 시즌으로 읽힌다.
    func testEarnedRunAverageIsUnknownWithoutALedger() {
        let withoutLedger = CareerRecordTableRules.rates(season(earned: nil))
        XCTAssertNil(withoutLedger.first { $0.abbreviation == "ERA" }?.value)
        // 실점은 원장과 무관하므로 여전히 나온다.
        XCTAssertNotNil(withoutLedger.first { $0.abbreviation == "RA/9" }?.value)

        let withLedger = CareerRecordTableRules.rates(season(outs: 270, earned: 30))
        XCTAssertEqual(withLedger.first { $0.abbreviation == "ERA" }?.value, "3.00")
    }

    /// 0이닝을 분모로 쓰지 않는다.
    func testEveryRateIsUnknownWithoutInnings() {
        for entry in CareerRecordTableRules.rates(season(outs: 0, earned: 0)) {
            XCTAssertNil(entry.value, "\(entry.abbreviation)가 0이닝에서 값을 냈습니다")
        }
        XCTAssertNil(CareerRecordTableRules.counting(season(outs: 0)).first { $0.abbreviation == "IP" }?.value)
    }

    /// 볼넷이 0이면 K/BB는 나눌 수 없다. 무한대를 숫자인 척 돌려주지 않는다.
    func testStrikeoutToWalkIsUnknownWithoutWalks() {
        let rates = CareerRecordTableRules.rates(season(outs: 270, walks: 0))
        XCTAssertNil(rates.first { $0.abbreviation == "K/BB" }?.value)
    }

    /// **한 시즌이라도 원장이 없으면 통산 평균자책도 모른다.**
    func testCareerEarnedRunsNeedEverySeasonToKnowThem() {
        let known = CareerRecordTableRules.total([season(outs: 270, earned: 30), season(outs: 270, earned: 20)])
        XCTAssertEqual(known.earnedRuns, 50)
        let partial = CareerRecordTableRules.total([season(outs: 270, earned: 30), season(outs: 270, earned: nil)])
        XCTAssertNil(partial.earnedRuns, "모르는 시즌이 0으로 합쳐졌습니다")
        // 나머지 합계는 그대로 성립한다.
        XCTAssertEqual(partial.inningsOuts, 540)
    }

    private func season(
        outs: Int = 270, earned: Int? = 30, walks: Int = 30
    ) -> ProSeasonStats {
        ProSeasonStats(
            season: 1, teamID: "t", games: 28, starts: 28, inningsOuts: outs,
            strikeouts: 90, walks: walks, runsAllowed: 35, hits: 80, homeRuns: 9,
            pitches: 1_500, wins: 10, losses: 8, saves: 0, earnedRuns: earned
        )
    }
}
