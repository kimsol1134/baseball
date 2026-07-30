import XCTest
@testable import SimulationCore

final class ProspectRankingTests: XCTestCase {
    private func performance(games: Int, strikeouts: Int, walks: Int = 0, runsAllowed: Int = 0) -> CareerPerformanceSnapshot {
        CareerPerformanceSnapshot(importantGamesCompleted: games, pitches: games * 30,
                                  strikeouts: strikeouts, walks: walks, runsAllowed: runsAllowed,
                                  expectedDamage: 0, actualDamage: 0)
    }

    /// 등판 전에는 순위가 없다 — 세상은 던지지 않은 투수를 모른다.
    func testNoRankBeforeFirstGame() {
        XCTAssertNil(ProspectRanking.playerRank(performance: performance(games: 0, strikeouts: 0)))
    }

    /// 성적이 좋아질수록 순위가 오르고, 괴물 성적은 1위에 닿는다.
    func testRankClimbsWithPerformance() {
        let rookie = ProspectRanking.playerRank(performance: performance(games: 1, strikeouts: 2, runsAllowed: 3))!
        let solid = ProspectRanking.playerRank(performance: performance(games: 3, strikeouts: 15, walks: 3, runsAllowed: 4))!
        let monster = ProspectRanking.playerRank(performance: performance(games: 5, strikeouts: 30, walks: 2))!
        XCTAssertGreaterThan(rookie, solid)
        XCTAssertGreaterThan(solid, monster)
        XCTAssertEqual(monster, 1, "5경기 30탈삼진 무실점이면 전국 1위여야 합니다.")
    }

    /// 명단은 회차 안에서 고정이고(라이벌은 얼굴이 있어야 한다), 내가 순위 안이면 실린다.
    func testBoardIsDeterministicAndContainsThePlayer() {
        let strong = performance(games: 4, strikeouts: 24, walks: 2, runsAllowed: 2)
        let a = ProspectRanking.board(careerID: "c", playerName: "김솔", playerSchool: "서울고", performance: strong)
        let b = ProspectRanking.board(careerID: "c", playerName: "김솔", playerSchool: "서울고", performance: strong)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, ProspectRanking.boardSize)
        XCTAssertEqual(a.filter(\.isPlayer).count, 1)
        XCTAssertEqual(a.first { $0.isPlayer }?.rank, ProspectRanking.playerRank(performance: strong))
        // 이름 중복 없음 — 같은 이름이 두 순위에 있으면 명단이 아니라 버그다.
        XCTAssertEqual(Set(a.map(\.name)).count, a.count)
    }
}

/// 가상 지명 명단 — 예측은 실제 드래프트와 같은 공식이라 배신하지 않는다.
final class DraftForecastTests: XCTestCase {
    func testForecastBandsFollowTheRealBoundaries() throws {
        let engine = HighSchoolCareerEngine()
        let created = try engine.start(.init(seed: "20260730", presetID: "power_prospect"))
        let forecast = HighSchoolCareerEngine.draftForecast(state: created.snapshot)
        // 갓 시작한 회차는 미지명권 또는 경계 — 시작하자마자 1라운드 예측이 나오면 공식이 죽은 것.
        XCTAssertLessThan(forecast.score, 78)
        XCTAssertFalse(forecast.band.isEmpty)
        XCTAssertFalse(forecast.interestedTeam.isEmpty)
        // 결정론.
        XCTAssertEqual(forecast, HighSchoolCareerEngine.draftForecast(state: created.snapshot))
    }
}
