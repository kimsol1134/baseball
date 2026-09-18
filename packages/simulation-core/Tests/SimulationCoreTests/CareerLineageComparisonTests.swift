import XCTest
@testable import SimulationCore

final class CareerLineageComparisonTests: XCTestCase {
    /// **환생의 값은 더 일찍 가는 것이다.** 1회차와 이번 회차를 같은 지점에서 견준다.
    func testItComparesTheFirstLifeWithTheLatest() throws {
        let comparison = try XCTUnwrap(CareerLineageComparisonRules.compare(lives: [
            life(1, games: 20, strikeouts: 80, walks: 60, runs: 50, evaluation: 40),
            life(2, games: 20, strikeouts: 100, walks: 50, runs: 45, evaluation: 55),
            life(5, games: 20, strikeouts: 160, walks: 30, runs: 30, evaluation: 72),
        ]))
        XCTAssertEqual(comparison.previousLabel, 1)
        XCTAssertEqual(comparison.currentLabel, 5, "가운데 회차가 아니라 가장 최근 회차와 견줘야 합니다")
        // 탈삼진이 경기당 4.0 → 8.0으로 두 배다. 다른 지표는 그만큼 못 움직였다.
        XCTAssertEqual(comparison.headline?.id, CareerLifeMetricKind.strikeoutsPerGame.rawValue)
    }

    /// 볼넷과 실점은 **내려가야** 나아진 것이다.
    func testFewerWalksAndRunsCountAsImprovement() throws {
        let comparison = try XCTUnwrap(CareerLineageComparisonRules.compare(lives: [
            life(1, games: 10, strikeouts: 50, walks: 40, runs: 30, evaluation: 50),
            life(3, games: 10, strikeouts: 50, walks: 20, runs: 15, evaluation: 50),
        ]))
        let walks = try XCTUnwrap(comparison.metrics.first { $0.id == CareerLifeMetricKind.walksPerGame.rawValue })
        XCTAssertTrue(walks.lowerIsBetter)
        XCTAssertEqual(walks.improved, true)
        let runs = try XCTUnwrap(comparison.metrics.first { $0.id == CareerLifeMetricKind.runsPerGame.rawValue })
        XCTAssertEqual(runs.improved, true)
        // 그대로인 지표는 '나아지지 않았다'이지 '모른다'가 아니다.
        let evaluation = try XCTUnwrap(comparison.metrics.first { $0.id == CareerLifeMetricKind.evaluation.rawValue })
        XCTAssertEqual(evaluation.improved, false)
    }

    /// 등판 수가 다른 회차를 합계로 견주면 더 많이 던진 쪽이 무조건 이긴다.
    func testRatesAreComparedPerGameNotAsTotals() throws {
        let comparison = try XCTUnwrap(CareerLineageComparisonRules.compare(lives: [
            life(1, games: 10, strikeouts: 60, walks: 20, runs: 20, evaluation: 50),
            life(2, games: 30, strikeouts: 120, walks: 60, runs: 60, evaluation: 50),
        ]))
        // 합계는 60 → 120으로 늘었지만 경기당은 6.0 → 4.0으로 줄었다.
        let strikeouts = try XCTUnwrap(comparison.metrics.first { $0.id == CareerLifeMetricKind.strikeoutsPerGame.rawValue })
        XCTAssertEqual(strikeouts.previous, 6.0)
        XCTAssertEqual(strikeouts.current, 4.0)
        XCTAssertEqual(strikeouts.improved, false, "합계가 늘었다고 나아진 것으로 세어집니다")
    }

    /// 견줄 대상이 없으면 표를 만들지 않는다.
    func testThereIsNoComparisonWithASingleLife() {
        XCTAssertNil(CareerLineageComparisonRules.compare(lives: [
            life(1, games: 10, strikeouts: 50, walks: 20, runs: 20, evaluation: 50)
        ]))
        XCTAssertNil(CareerLineageComparisonRules.compare(lives: []))
        // 한 경기도 던지지 않은 회차는 비교의 한쪽이 될 수 없다.
        XCTAssertNil(CareerLineageComparisonRules.compare(lives: [
            life(1, games: 0, strikeouts: 0, walks: 0, runs: 0, evaluation: 0),
            life(2, games: 10, strikeouts: 50, walks: 20, runs: 20, evaluation: 50),
        ]))
    }

    func testContentKeysAreStableSemanticIDs() {
        for key in CareerLineageComparisonRules.contentKeys {
            XCTAssertTrue(key.hasPrefix("content.lineage-comparison."), key)
            XCTAssertFalse(key.contains("_"), key)
            XCTAssertEqual(key, key.lowercased(), key)
        }
    }

    private func life(
        _ number: Int, games: Int, strikeouts: Int, walks: Int, runs: Int, evaluation: Int
    ) -> CareerLifeSummary {
        CareerLifeSummary(
            lifeNumber: number, games: games, strikeouts: strikeouts,
            walks: walks, runsAllowed: runs, evaluationScore: evaluation
        )
    }
}
