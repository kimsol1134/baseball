import XCTest
@testable import SimulationCore

/// 승패 판정과 득점 분포.
///
/// 이 둘이 어긋나면 성적표 전체가 거짓말이 된다 — 7이닝 무실점에 패전이 붙거나, 완봉패가
/// 한 번도 안 나오거나 한다. 둘 다 사람이 바로 알아채는 종류의 오류다.
final class LeagueBaselineTests: XCTestCase {

    // MARK: - 득점 분포

    func testRunDistributionSumsToOneThousand() {
        XCTAssertEqual(LeagueBaseline.teamRunsPerGamePermille.reduce(0, +), 1_000)
        XCTAssertEqual(LeagueBaseline.highSchoolRunsPerGamePermille.reduce(0, +), 1_000)
    }

    /// 실제 야구의 팀 득점 평균은 4점대다. 여기서 벗어나면 시즌 성적이 통째로 이상해진다.
    func testAverageRunsMatchRealBaseball() {
        let total = LeagueBaseline.teamRunsPerGamePermille.enumerated()
            .reduce(0) { $0 + $1.offset * $1.element }
        let average = Double(total) / 1_000
        XCTAssertGreaterThan(average, 3.9, "평균 득점이 너무 낮습니다: \(average)")
        XCTAssertLessThan(average, 5.2, "평균 득점이 너무 높습니다: \(average)")
    }

    /// 완봉패도, 난타전도 있어야 한다. 어느 한쪽이 사라지면 시즌이 밋밋해진다.
    func testDistributionKeepsBothTails() {
        XCTAssertGreaterThan(LeagueBaseline.teamRunsPerGamePermille[0], 30, "0점 경기가 너무 드뭅니다")
        let bigInnings = LeagueBaseline.teamRunsPerGamePermille[10...].reduce(0, +)
        XCTAssertGreaterThan(bigInnings, 20, "두 자리 득점이 사실상 없습니다")
    }

    /// 뽑기가 실제로 분포를 따르는지. 같은 시드는 같은 결과를 내야 한다.
    func testSamplingFollowsDistributionAndIsDeterministic() {
        var rng = SplitMix64(seed: 42)
        var counts = [Int](repeating: 0, count: 24)
        var total = 0
        for _ in 0..<20_000 {
            let runs = LeagueBaseline.teamRuns(using: &rng)
            counts[min(runs, 23)] += 1
            total += runs
        }
        let average = Double(total) / 20_000
        XCTAssertGreaterThan(average, 3.7)
        XCTAssertLessThan(average, 5.4)
        XCTAssertGreaterThan(counts[0], 0, "0점 경기가 한 번도 안 나왔습니다")

        var replay = SplitMix64(seed: 42)
        var first: [Int] = []
        for _ in 0..<20 { first.append(LeagueBaseline.teamRuns(using: &replay)) }
        var again = SplitMix64(seed: 42)
        var second: [Int] = []
        for _ in 0..<20 { second.append(LeagueBaseline.teamRuns(using: &again)) }
        XCTAssertEqual(first, second, "같은 시드가 다른 결과를 냅니다")
    }

    // MARK: - 승패 판정

    /// 선발은 5이닝을 채워야 승리 투수가 된다. 야구 규칙 그대로다.
    func testStarterNeedsFiveInningsForTheWin() {
        let short = DecisionRules.decide(
            started: true, isCloser: false, outs: 12, runsAllowed: 1, teamRuns: 5, opponentRuns: 2
        )
        XCTAssertEqual(short, .noDecision, "4이닝만 던지고 승리가 붙었습니다")

        let full = DecisionRules.decide(
            started: true, isCloser: false, outs: 15, runsAllowed: 1, teamRuns: 5, opponentRuns: 2
        )
        XCTAssertEqual(full, .win)
    }

    /// **이 게임에서 가장 중요한 판정.** 잘 던지고도 타선이 못 치면 노디시전이다.
    /// 이것이 없으면 성적이 그냥 내가 잘했는지의 요약표가 된다.
    func testShutoutWithNoRunSupportIsNotAWin() {
        let decision = DecisionRules.decide(
            started: true, isCloser: false, outs: 21, runsAllowed: 0, teamRuns: 0, opponentRuns: 0
        )
        XCTAssertEqual(decision, .noDecision)
    }

    /// 한 점도 안 줬는데 팀이 졌으면 그 패전은 내 것이 아니다. 불펜이 준 점수다.
    func testShutoutStarterDoesNotTakeTheLoss() {
        let decision = DecisionRules.decide(
            started: true, isCloser: false, outs: 21, runsAllowed: 0, teamRuns: 1, opponentRuns: 2
        )
        XCTAssertEqual(decision, .noDecision)
    }

    func testStarterTakesTheLossWhenTheyGaveUpRuns() {
        let decision = DecisionRules.decide(
            started: true, isCloser: false, outs: 18, runsAllowed: 4, teamRuns: 2, opponentRuns: 4
        )
        XCTAssertEqual(decision, .loss)
    }

    /// 세이브는 3점 차 이내를 무실점으로 지켰을 때만.
    func testSaveRequiresACloseLead() {
        let save = DecisionRules.decide(
            started: false, isCloser: true, outs: 3, runsAllowed: 0, teamRuns: 4, opponentRuns: 2
        )
        XCTAssertEqual(save, .save)

        let blowout = DecisionRules.decide(
            started: false, isCloser: true, outs: 3, runsAllowed: 0, teamRuns: 9, opponentRuns: 2
        )
        XCTAssertEqual(blowout, .noDecision, "8점 차에 세이브가 붙었습니다")

        let blown = DecisionRules.decide(
            started: false, isCloser: true, outs: 3, runsAllowed: 2, teamRuns: 4, opponentRuns: 3
        )
        XCTAssertNotEqual(blown, .save, "실점하고도 세이브가 붙었습니다")
    }

    /// 이닝 표기는 야구식 3분의 1 단위여야 한다.
    func testInningsAreWrittenInThirds() {
        func line(outs: Int) -> ProGameLine {
            ProGameLine(
                season: 1, week: 1, outingNumber: 1, started: true, outs: outs,
                strikeouts: 0, walks: 0, runsAllowed: 0, pitches: 0,
                teamRuns: 0, opponentRuns: 0, decision: .noDecision, played: false
            )
        }
        XCTAssertEqual(line(outs: 18).inningsText, "6")
        XCTAssertEqual(line(outs: 19).inningsText, "6.1")
        XCTAssertEqual(line(outs: 20).inningsText, "6.2")
        XCTAssertEqual(line(outs: 21).inningsText, "7")
    }

    /// 예전 저장본에는 `losses`가 없다. 없이도 열려야 한다.
    func testOldSavesWithoutLossesStillDecode() throws {
        let json = """
        {"season":3,"teamID":"team","games":20,"starts":18,"inningsOuts":330,
         "strikeouts":110,"walks":34,"runsAllowed":45,"wins":9,"saves":0}
        """
        let stats = try JSONDecoder().decode(ProSeasonStats.self, from: Data(json.utf8))
        XCTAssertEqual(stats.wins, 9)
        XCTAssertEqual(stats.losses, 0)
        XCTAssertEqual(stats.strikeouts, 110)
    }

    // MARK: - 등판 시점 점수 차 정합

    /// **화면과 결과가 어긋나면 안 된다.** 1점 리드로 올라가 무실점으로 막았는데
    /// 패배를 통보받으면 플레이어는 게임이 고장 났다고 판단한다.
    func testHoldingALeadScorelessDoesNotProduceALoss() {
        // 등판 전 상대 득점 e, 리드 1점이면 우리 e+1점. 내가 0실점이면 상대는 e + 불펜.
        // 불펜이 무너지지 않는 한 승리이고, 무너져도 패전은 불펜 몫이다.
        for opponentEarlier in 0..<4 {
            let teamRuns = opponentEarlier + 1
            let opponentRuns = opponentEarlier  // 무실점 + 불펜 무실점
            let decision = DecisionRules.decide(
                started: false, isCloser: true, outs: 3, runsAllowed: 0,
                teamRuns: teamRuns, opponentRuns: opponentRuns
            )
            XCTAssertNotEqual(decision, .loss, "리드를 무실점으로 지켰는데 패전입니다")
        }
    }

    /// 내가 던지지 않은 이닝의 실점이 존재해야 한다. 마무리가 나온 날 상대 점수가
    /// 0~2점에 못 박히면 야구를 아는 사람이 바로 알아챈다.
    func testRestOfTeamRunsScalesWithUncoveredInnings() {
        var rng = SplitMix64(seed: 7)
        var oneInningTotal = 0
        var eightInningTotal = 0
        for _ in 0..<3_000 {
            oneInningTotal += LeagueBaseline.restOfTeamRuns(outsCovered: 3, using: &rng)
            eightInningTotal += LeagueBaseline.restOfTeamRuns(outsCovered: 24, using: &rng)
        }
        XCTAssertGreaterThan(
            eightInningTotal, oneInningTotal * 3,
            "여덟 이닝을 남에게 맡긴 날과 한 이닝만 맡긴 날의 실점이 비슷합니다"
        )
        XCTAssertGreaterThan(eightInningTotal, 0, "마무리 등판 날 상대 점수가 항상 내 실점뿐입니다")
    }

    /// 등판 기록도 예전 저장본에서 열려야 한다.
    func testGameLineDecodesWithoutOptionalFields() throws {
        let json = """
        {"season":2,"week":9,"outingNumber":4,"started":true,"outs":18,"strikeouts":7,
         "walks":2,"runsAllowed":2,"pitches":94,"teamRuns":3,"opponentRuns":2,
         "decision":"win","played":false}
        """
        let line = try JSONDecoder().decode(ProGameLine.self, from: Data(json.utf8))
        XCTAssertEqual(line.decision, .win)
        XCTAssertEqual(line.inningsText, "6")
        XCTAssertNil(line.hits)
    }
}
