import XCTest
@testable import SimulationCore

/// **선발과 마무리가 각자의 길로 전당에 닿는다**(규칙 12, 이식 계획 2-F).
///
/// 안드로이드 `ProfessionalBalanceTest.realisticEliteStarterAndCloserCanReachTheHall…`과
/// 같은 커리어·같은 문턱(70)이다. 이닝으로만 일한 양을 세던 규칙에서는 한 시즌 60이닝을
/// 던지는 마무리가 영원히 닿지 못했다.
final class ProHallOfFameParityTests: XCTestCase {
    func testAnEliteStarterReachesTheHall() {
        XCTAssertGreaterThanOrEqual(score(seasons: eliteStarterSeasons), 70)
    }

    func testAnEliteCloserReachesTheHallOnSaves() {
        XCTAssertGreaterThanOrEqual(
            score(seasons: eliteCloserSeasons), 70,
            "이닝이 짧다는 이유로 마무리가 전당에서 밀려납니다"
        )
    }

    /// 오래 던지기만 한 커리어는 닿지 못한다. 문턱이 시간의 함수가 되면 안 된다.
    func testASolidButUnexceptionalStarterDoesNotReachTheHall() {
        XCTAssertLessThan(score(seasons: ordinaryStarterSeasons), 70)
    }

    /// 자책점이 없는 옛 시즌은 실점으로 판단한다. **없는 것을 좋은 시즌으로 세지 않는다.**
    func testSeasonsWithoutEarnedRunsFallBackToRunsAllowed() {
        let withoutLedger = eliteStarterSeasons.map { season in
            ProSeasonStats(
                season: season.season, teamID: season.teamID, games: season.games,
                starts: season.starts, inningsOuts: season.inningsOuts,
                strikeouts: season.strikeouts, walks: season.walks,
                runsAllowed: season.runsAllowed, hits: season.hits, homeRuns: season.homeRuns,
                pitches: season.pitches, wins: season.wins, losses: season.losses,
                saves: season.saves, earnedRuns: nil
            )
        }
        // 실점 52 / 162이닝 = 2.89로 여전히 좋은 시즌이다 — 값이 있으면 그대로 읽는다.
        XCTAssertGreaterThanOrEqual(score(seasons: withoutLedger), 70)
    }

    // MARK: -

    private var eliteStarterSeasons: [ProSeasonStats] {
        (1...20).map { season(number: $0, games: 28, starts: 28, outs: 486, strikeouts: 185, runs: 52, earned: 45, wins: 14, saves: 0) }
    }

    private var eliteCloserSeasons: [ProSeasonStats] {
        (1...20).map { season(number: $0, games: 60, starts: 0, outs: 180, strikeouts: 75, runs: 19, earned: 17, wins: 0, saves: 25) }
    }

    private var ordinaryStarterSeasons: [ProSeasonStats] {
        (1...20).map { season(number: $0, games: 28, starts: 28, outs: 486, strikeouts: 140, runs: 90, earned: 81, wins: 10, saves: 0) }
    }

    private func season(
        number: Int, games: Int, starts: Int, outs: Int,
        strikeouts: Int, runs: Int, earned: Int, wins: Int, saves: Int
    ) -> ProSeasonStats {
        ProSeasonStats(
            season: number, teamID: ProCareerEngine.proTeams[0].id, games: games, starts: starts,
            inningsOuts: outs, strikeouts: strikeouts, walks: 40, runsAllowed: runs,
            hits: outs / 3, homeRuns: 12, pitches: outs * 5, wins: wins, losses: 8, saves: saves,
            earnedRuns: earned
        )
    }

    private func score(seasons: [ProSeasonStats]) -> Int {
        ProCareerEngine.hallOfFameFinalScore(for: snapshot(seasons: seasons))
    }

    private func snapshot(seasons: [ProSeasonStats]) -> ProCareerSnapshot {
        ProCareerSnapshot(
            proCareerID: "pro-hof", revision: 1, phase: .completed, identity: .defaultPitcher,
            pitcher: .init(id: "p", name: "t", stuff: 60, command: 60, movement: 60, stamina: 60),
            team: ProCareerEngine.proTeams[0],
            entitlement: .init(status: .active, source: .development, verifiedAt: "2026-07-22", offlineValidUntil: "2026-08-22"),
            age: 39, season: 20, week: 24, level: .major, role: .starter,
            managerTrust: 80, catcherTrust: 80, fatigue: 20, injuryWeeks: 0,
            serviceYears: 20, militaryCompleted: true, contract: nil,
            currentStats: seasons.last!, careerStats: seasons, awards: [], milestones: [],
            news: [], hallOfFameScore: nil, commitment: "",
            balanceVersion: PitcherPresetCatalog.balanceVersion,
            proRulesVersion: ProGameplayRules.current
        )
    }
}
