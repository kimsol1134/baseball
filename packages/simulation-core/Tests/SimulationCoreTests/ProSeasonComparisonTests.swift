import XCTest
@testable import SimulationCore

final class ProSeasonComparisonTests: XCTestCase {
    /// **성장은 비교로만 느껴진다.** 작년보다 나아진 지표가 한 줄로 먼저 선다.
    func testTheHeadlineIsTheMetricThatImprovedMost() throws {
        let comparison = try XCTUnwrap(ProSeasonComparisonRules.compare(state: snapshot(seasons: [
            season(1, outs: 300, strikeouts: 60, earned: 50, hits: 120, walks: 40, wins: 4),
            season(2, outs: 300, strikeouts: 100, earned: 40, hits: 100, walks: 30, wins: 6),
        ])))
        XCTAssertEqual(comparison.previousLabel, 1)
        XCTAssertEqual(comparison.currentLabel, 2)
        // K/9는 5.4 → 9.0으로 67% 올랐고, 다른 지표는 그만큼 못 움직였다.
        XCTAssertEqual(comparison.headline?.id, ProSeasonMetricKind.strikeoutsPer9.rawValue)
        XCTAssertEqual(comparison.headline?.improved, true)
    }

    /// 낮을수록 좋은 지표는 내려가야 나아진 것이다.
    func testLowerIsBetterMetricsReadTheRightDirection() throws {
        let comparison = try XCTUnwrap(ProSeasonComparisonRules.compare(state: snapshot(seasons: [
            season(1, outs: 300, strikeouts: 80, earned: 60, hits: 130, walks: 50, wins: 5),
            season(2, outs: 300, strikeouts: 80, earned: 30, hits: 90, walks: 30, wins: 5),
        ])))
        let era = try XCTUnwrap(comparison.metrics.first { $0.id == ProSeasonMetricKind.earnedRunAverage.rawValue })
        XCTAssertTrue(era.lowerIsBetter)
        XCTAssertEqual(era.improved, true, "평균자책이 내려갔는데 나빠진 것으로 읽힙니다")
        let whip = try XCTUnwrap(comparison.metrics.first { $0.id == ProSeasonMetricKind.whip.rawValue })
        XCTAssertEqual(whip.improved, true)
        // 그대로인 지표는 '나아지지 않았다'(false)이지 '모른다'(nil)가 아니다.
        let wins = try XCTUnwrap(comparison.metrics.first { $0.id == ProSeasonMetricKind.wins.rawValue })
        XCTAssertEqual(wins.delta, 0)
        XCTAssertEqual(wins.improved, false, "그대로인 지표가 나아진 것으로 세어집니다")
    }

    /// **자책점이 없는 시즌은 평균자책을 만들지 않는다.** 실점으로 대신하면 두 시즌이 서로
    /// 다른 것을 재면서 같은 이름을 달게 된다.
    func testASeasonWithoutEarnedRunsHasNoEarnedRunAverageToCompare() throws {
        let comparison = try XCTUnwrap(ProSeasonComparisonRules.compare(state: snapshot(seasons: [
            season(1, outs: 300, strikeouts: 80, earned: nil, hits: 130, walks: 50, wins: 5),
            season(2, outs: 300, strikeouts: 80, earned: 30, hits: 90, walks: 30, wins: 5),
        ])))
        let era = try XCTUnwrap(comparison.metrics.first { $0.id == ProSeasonMetricKind.earnedRunAverage.rawValue })
        XCTAssertNil(era.previous)
        XCTAssertNil(era.delta, "모르는 값이 0으로 세어졌습니다")
        XCTAssertNil(era.improved)
        // 나머지 지표는 정상적으로 비교된다.
        XCTAssertNotNil(comparison.metrics.first { $0.id == ProSeasonMetricKind.whip.rawValue }?.delta)
    }

    /// 견줄 대상이 없으면 표를 만들지 않는다.
    func testThereIsNoComparisonWithoutTwoPitchedSeasons() {
        XCTAssertNil(ProSeasonComparisonRules.compare(state: snapshot(seasons: [
            season(1, outs: 300, strikeouts: 80, earned: 40, hits: 100, walks: 30, wins: 5)
        ])))
        // 한 이닝도 던지지 않은 시즌(부상·군 복무)은 비교의 한쪽이 될 수 없다.
        XCTAssertNil(ProSeasonComparisonRules.compare(state: snapshot(seasons: [
            season(1, outs: 0, strikeouts: 0, earned: 0, hits: 0, walks: 0, wins: 0),
            season(2, outs: 300, strikeouts: 80, earned: 40, hits: 100, walks: 30, wins: 5),
        ])))
    }

    func testContentKeysAreStableSemanticIDs() {
        for key in ProSeasonComparisonRules.contentKeys {
            XCTAssertTrue(key.hasPrefix("content.season-comparison."), key)
            XCTAssertFalse(key.contains("_"), key)
            XCTAssertEqual(key, key.lowercased(), key)
        }
    }

    // MARK: -

    private func season(
        _ number: Int, outs: Int, strikeouts: Int, earned: Int?,
        hits: Int, walks: Int, wins: Int
    ) -> ProSeasonStats {
        ProSeasonStats(
            season: number, teamID: ProCareerEngine.proTeams[0].id, games: 28, starts: 28,
            inningsOuts: outs, strikeouts: strikeouts, walks: walks,
            runsAllowed: (earned ?? 40) + 5, hits: hits, homeRuns: 10, pitches: outs * 5,
            wins: wins, losses: 8, saves: 0, earnedRuns: earned
        )
    }

    private func snapshot(seasons: [ProSeasonStats]) -> ProCareerSnapshot {
        ProCareerSnapshot(
            proCareerID: "pro-cmp", revision: 1, phase: .seasonReview, identity: .defaultPitcher,
            pitcher: .init(id: "p", name: "t", stuff: 60, command: 60, movement: 60, stamina: 60),
            team: ProCareerEngine.proTeams[0],
            entitlement: .init(status: .active, source: .development, verifiedAt: "2026-07-22", offlineValidUntil: "2026-08-22"),
            age: 25, season: seasons.count, week: 24, level: .major, role: .starter,
            managerTrust: 80, catcherTrust: 70, fatigue: 40, injuryWeeks: 0,
            serviceYears: seasons.count, militaryCompleted: false, contract: nil,
            currentStats: seasons.last!, careerStats: seasons, awards: [], milestones: [],
            news: [], hallOfFameScore: nil, commitment: "",
            balanceVersion: PitcherPresetCatalog.balanceVersion,
            proRulesVersion: ProGameplayRules.current
        )
    }
}
