import XCTest
@testable import SimulationCore

/// 투수 기록 지표. 야구 기록은 표기 규칙이 곧 신뢰라, 반올림 하나가 틀리면 아는 사람은 바로 알아본다.
final class PitchingMetricsTests: XCTestCase {
    func testInningsTextUsesOutsNotDecimals() {
        XCTAssertEqual(PitchingMetrics.inningsText(outs: 0), "0")
        XCTAssertEqual(PitchingMetrics.inningsText(outs: 18), "6")
        XCTAssertEqual(PitchingMetrics.inningsText(outs: 19), "6.1")
        XCTAssertEqual(PitchingMetrics.inningsText(outs: 20), "6.2")
        XCTAssertEqual(PitchingMetrics.inningsText(outs: 21), "7")
    }

    func testPer9NeedsInnings() {
        XCTAssertNil(PitchingMetrics.per9(5, outs: 0))
        // 27아웃(9이닝)에 9탈삼진이면 K/9는 정확히 9다.
        XCTAssertEqual(PitchingMetrics.per9(9, outs: 27)!, 9, accuracy: 0.001)
        XCTAssertEqual(PitchingMetrics.per9(6, outs: 54)!, 3, accuracy: 0.001)
    }

    func testWhipCountsHitsAndWalksPerInning() {
        // 9이닝에 안타 6 볼넷 3 → WHIP 1.00
        XCTAssertEqual(PitchingMetrics.whip(hits: 6, walks: 3, outs: 27)!, 1.0, accuracy: 0.001)
        XCTAssertNil(PitchingMetrics.whip(hits: 1, walks: 1, outs: 0))
    }

    /// 볼넷 0에 무한대를 숫자인 척 돌려주면 화면이 "∞" 대신 이상한 값을 그린다.
    func testStrikeoutToWalkIsNilWithoutWalks() {
        XCTAssertNil(PitchingMetrics.strikeoutToWalk(strikeouts: 10, walks: 0))
        XCTAssertEqual(PitchingMetrics.strikeoutToWalk(strikeouts: 10, walks: 4)!, 2.5, accuracy: 0.001)
    }

    func testQualityStartNeedsSixInningsAndThreeRuns() {
        XCTAssertTrue(PitchingMetrics.isQualityStart(started: true, outs: 18, runsAllowed: 3))
        XCTAssertFalse(PitchingMetrics.isQualityStart(started: true, outs: 17, runsAllowed: 0), "6이닝 미만")
        XCTAssertFalse(PitchingMetrics.isQualityStart(started: true, outs: 21, runsAllowed: 4), "4실점")
        XCTAssertFalse(PitchingMetrics.isQualityStart(started: false, outs: 18, runsAllowed: 0), "구원 등판")
    }

    /// 리그 평균 성적의 FIP는 리그 RA9와 거의 같아야 한다. 상수가 어긋나면 모든 선수의
    /// FIP가 통째로 밀려서, 화면이 "수비가 도왔다"를 반대로 말하게 된다.
    func testFipConstantIsAnchoredToLeagueAverage() {
        // 실측 리그 평균(600등판): 200이닝 환산으로 HR 20 · BB 52 · K 222.
        let fip = PitchingMetrics.fip(homeRuns: 20, walks: 52, strikeouts: 222, outs: 600)!
        XCTAssertEqual(fip, PitchingMetrics.leagueRunsPer9, accuracy: 0.25)
    }

    /// 삼진이 많고 볼넷·홈런이 적은 투수는 FIP가 낮아야 한다.
    func testFipRewardsStrikeoutsAndPunishesWalks() {
        let good = PitchingMetrics.fip(homeRuns: 10, walks: 30, strikeouts: 260, outs: 600)!
        let bad = PitchingMetrics.fip(homeRuns: 30, walks: 90, strikeouts: 120, outs: 600)!
        XCTAssertLessThan(good, bad)
    }

    func testRateTextDropsLeadingZero() {
        XCTAssertEqual(PitchingMetrics.rateText(0.532), ".532")
        XCTAssertEqual(PitchingMetrics.rateText(1.0), "1.000")
        XCTAssertEqual(PitchingMetrics.rateText(nil), "-")
    }

    func testBabipExcludesHomeRunsAndStrikeouts() {
        // 27아웃 · 안타 9(홈런 1) · 삼진 9 · 볼넷 3
        // 상대 타자 39, 인플레이 = 39 - 3 - 9 - 1 = 26, 인플레이 안타 8 → .3077
        let babip = PitchingMetrics.babip(hits: 9, homeRuns: 1, strikeouts: 9, outs: 27, walks: 3)!
        XCTAssertEqual(babip, 8.0 / 26.0, accuracy: 0.001)
    }
}

/// 리그 순위표와 투수 순위. 배경이지만 **틀리면 곧바로 들킨다** — 순위표를 아는 사람이
/// 이 게임의 구매층이다.
final class LeagueTableTests: XCTestCase {
    func testStandingsAreDeterministic() {
        let first = LeagueTable.standings(season: 3, seed: "abc", gamesPlayed: 144)
        let second = LeagueTable.standings(season: 3, seed: "abc", gamesPlayed: 144)
        XCTAssertEqual(first, second)
    }

    func testDifferentSeasonsDiffer() {
        let first = LeagueTable.standings(season: 3, seed: "abc", gamesPlayed: 144)
        let second = LeagueTable.standings(season: 4, seed: "abc", gamesPlayed: 144)
        XCTAssertNotEqual(first, second)
    }

    /// 리그에서 누군가 이기면 누군가는 진다. 승수 합과 패수 합이 어긋나면 순위표가 거짓말이다.
    func testWinsEqualLossesAcrossTheLeague() {
        for season in 1...12 {
            let rows = LeagueTable.standings(season: season, seed: "balance", gamesPlayed: 144)
            let wins = rows.reduce(0) { $0 + $1.wins }
            let losses = rows.reduce(0) { $0 + $1.losses }
            XCTAssertEqual(wins, losses, "\(season)시즌: 승 \(wins) 패 \(losses)")
        }
    }

    /// 무승부를 뺀 경기 수는 모든 팀이 같아야 한다(같은 날짜까지 치렀으므로).
    func testEveryTeamPlaysTheSameNumberOfGames() {
        let rows = LeagueTable.standings(season: 2, seed: "games", gamesPlayed: 144)
        for row in rows {
            XCTAssertEqual(row.games, 144, "\(row.teamName)이 \(row.games)경기를 치렀습니다")
        }
    }

    func testStandingsAreSortedByWinRate() {
        let rows = LeagueTable.standings(season: 5, seed: "sorted", gamesPlayed: 144)
        for (left, right) in zip(rows, rows.dropFirst()) {
            XCTAssertGreaterThanOrEqual(left.winRate ?? 0, right.winRate ?? 0)
        }
    }

    /// 시즌 승률이 야구 범위 안에 있어야 한다. .200이나 .800짜리 팀이 나오면 리그가 아니다.
    func testWinRatesStayInBaseballRange() {
        for season in 1...12 {
            for row in LeagueTable.standings(season: season, seed: "range", gamesPlayed: 144) {
                let rate = row.winRate ?? 0
                XCTAssertGreaterThan(rate, 0.30, "\(row.teamName) 승률 \(rate)")
                XCTAssertLessThan(rate, 0.70, "\(row.teamName) 승률 \(rate)")
            }
        }
    }

    func testGamesBehindIsZeroForTheLeader() {
        let rows = LeagueTable.standings(season: 7, seed: "gb", gamesPlayed: 144)
        XCTAssertEqual(LeagueTable.gamesBehind(rows[0], leader: rows[0]), 0)
        XCTAssertGreaterThan(LeagueTable.gamesBehind(rows[rows.count - 1], leader: rows[0]), 0)
    }

    func testSeasonStartHasNoGames() {
        let rows = LeagueTable.standings(season: 1, seed: "opening", gamesPlayed: 0)
        XCTAssertEqual(rows.count, HighSchoolCareerEngine.teams.count)
        XCTAssertTrue(rows.allSatisfy { $0.games == 0 })
    }

    // MARK: - 투수 순위

    func testPitcherLeadersAreDeterministicAndSorted() {
        let first = LeagueTable.pitchers(season: 2, seed: "lead", gamesPlayed: 144)
        let second = LeagueTable.pitchers(season: 2, seed: "lead", gamesPlayed: 144)
        XCTAssertEqual(first, second)
        for (left, right) in zip(first, first.dropFirst()) {
            XCTAssertLessThanOrEqual(left.runsPer9 ?? 99, right.runsPer9 ?? 99)
        }
    }

    /// 리그 투수들의 성적이 이 게임의 커널이 만드는 성적과 같은 세계여야 한다.
    /// 순위표만 다른 규칙으로 만들어지면 내 3.4가 리그에서 몇 등인지가 거짓이 된다.
    func testLeaderStatsMatchTheMeasuredLeague() {
        let rows = LeagueTable.pitchers(season: 4, seed: "world", gamesPlayed: 144)
        XCTAssertGreaterThanOrEqual(rows.count, 10)
        let totalOuts = rows.reduce(0) { $0 + $1.inningsOuts }
        let totalRuns = rows.reduce(0) { $0 + $1.runsAllowed }
        let totalK = rows.reduce(0) { $0 + $1.strikeouts }
        let ra9 = PitchingMetrics.runsPer9(runs: totalRuns, outs: totalOuts)!
        let k9 = PitchingMetrics.per9(totalK, outs: totalOuts)!
        XCTAssertEqual(ra9, 3.5, accuracy: 1.0, "리그 평균 실점이 커널 실측(3.5)에서 멀어졌습니다")
        XCTAssertEqual(k9, 9.5, accuracy: 2.0, "리그 평균 탈삼진이 커널 실측(10.0)에서 멀어졌습니다")
    }

    func testPlayerRowIsInsertedAndFindable() {
        let mine = LeagueTable.PitcherRow(
            name: "나선수", teamName: "서울 코메츠", inningsOuts: 480,
            wins: 12, losses: 5, saves: 0, strikeouts: 180, walks: 40,
            hits: 130, homeRuns: 12, runsAllowed: 50, isPlayer: true
        )
        let rows = LeagueTable.pitchers(season: 6, seed: "me", gamesPlayed: 144, player: mine)
        XCTAssertTrue(rows.contains { $0.isPlayer })
        // 9이닝당 실점 2.81이면 상위권이어야 한다.
        let rank = rows.firstIndex { $0.isPlayer }!
        XCTAssertLessThan(rank, rows.count / 2)
    }

    func testSortingSwitchesTheOrder() {
        let rows = LeagueTable.pitchers(season: 8, seed: "sort", gamesPlayed: 144)
        let byStrikeouts = LeagueTable.sorted(rows, by: .strikeouts)
        for (left, right) in zip(byStrikeouts, byStrikeouts.dropFirst()) {
            XCTAssertGreaterThanOrEqual(left.strikeouts, right.strikeouts)
        }
    }

    func testWeeksMapToGames() {
        XCTAssertEqual(LeagueTable.gamesPlayed(week: 0), 0)
        XCTAssertEqual(LeagueTable.gamesPlayed(week: 24), 144)
        XCTAssertEqual(LeagueTable.gamesPlayed(week: 12), 72)
    }

    // MARK: - 내 성적 연동

    /// 내가 등판한 경기의 실제 결과가 우리 팀 기록에 들어간다. 예전에는 열 팀 전부가
    /// 시드에서 생성돼 내가 아무리 잘 던져도 우리 팀 순위가 움직이지 않았다.
    func testPlayerResultsMoveTheirTeam() {
        let team = HighSchoolCareerEngine.teams[0].id
        let allWins = (0..<30).map { _ in LeagueTable.PlayerGameResult(teamRuns: 5, opponentRuns: 1) }
        let allLosses = (0..<30).map { _ in LeagueTable.PlayerGameResult(teamRuns: 1, opponentRuns: 5) }
        let winning = LeagueTable.standings(season: 3, seed: "link", gamesPlayed: 72,
                                            playerTeamID: team, playerResults: allWins)
        let losing = LeagueTable.standings(season: 3, seed: "link", gamesPlayed: 72,
                                           playerTeamID: team, playerResults: allLosses)
        let winRow = winning.first { $0.teamID == team }!
        let loseRow = losing.first { $0.teamID == team }!
        XCTAssertGreaterThan(winRow.wins, loseRow.wins + 20, "30연승과 30연패의 차이가 팀 기록에 보이지 않습니다")
        let winRank = winning.firstIndex { $0.teamID == team }!
        let loseRank = losing.firstIndex { $0.teamID == team }!
        XCTAssertLessThan(winRank, loseRank, "이기는 팀이 순위에서 더 아래에 있습니다")
    }

    /// 내 결과를 넣어도 리그의 승수 합 == 패수 합은 유지된다.
    func testPlayerResultsKeepTheLeagueBalanced() {
        let team = HighSchoolCareerEngine.teams[2].id
        let mixed = (0..<20).map {
            LeagueTable.PlayerGameResult(teamRuns: $0 % 3 == 0 ? 2 : 6, opponentRuns: 4)
        }
        let rows = LeagueTable.standings(season: 5, seed: "bal", gamesPlayed: 96,
                                         playerTeamID: team, playerResults: mixed)
        XCTAssertEqual(rows.reduce(0) { $0 + $1.wins }, rows.reduce(0) { $0 + $1.losses })
        for row in rows { XCTAssertEqual(row.games, 96, "\(row.teamName)") }
    }

    /// 균형 맞추기가 내 팀을 건드리면 안 된다. 실제 결과가 들어간 기록을 고치면 다시 거짓말이 된다.
    func testBalancingNeverTouchesThePlayerTeam() {
        let team = HighSchoolCareerEngine.teams[4].id
        let results = (0..<24).map { _ in LeagueTable.PlayerGameResult(teamRuns: 7, opponentRuns: 0) }
        let rows = LeagueTable.standings(season: 2, seed: "pin", gamesPlayed: 48,
                                         playerTeamID: team, playerResults: results)
        let mine = rows.first { $0.teamID == team }!
        // 24경기 전승 + 나머지 24경기 생성분. 전승 부분은 그대로 남아야 한다.
        XCTAssertGreaterThanOrEqual(mine.wins, 24, "실제 전승 기록이 균형 맞추기에 깎였습니다")
    }
}
