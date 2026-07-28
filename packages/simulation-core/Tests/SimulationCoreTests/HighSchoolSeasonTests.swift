import XCTest
@testable import SimulationCore

/// 고교 자동 경기와 드래프트 시즌 항.
///
/// 시즌 항은 조용히 망가지기 쉽다 — 영점을 잘못 두면 전원 +4나 전원 -4가 되고, 그러면
/// 항이 있으나 없으나 순위가 같아져 시즌 기록이 화면 장식이 된다. 실제로 처음 구현했을 때
/// 프로 기준(RA9 5.5)을 영점으로 써서 드래프트 통과율이 0.65에서 0.80으로 튀었다.
final class HighSchoolSeasonTests: XCTestCase {

    /// 고교 자동 경기가 야구처럼 나오는지.
    func testChapterGamesProduceRealisticLines() {
        let simulator = AutoOutingSimulator()
        var rng = SplitMix64(seed: 4_242)
        var outs = 0, runs = 0, strikeouts = 0, walks = 0
        let games = 120
        for index in 0..<games {
            let line = simulator.simulate(
                pitcher: PitcherPresetCatalog.all[0].pitcher,
                startingFatigue: 20 + (index % 3) * 6,
                outsTarget: 18, pitchCap: 90, batterOffset: -6,
                baseSeed: rng.next()
            )
            outs += line.outs; runs += line.runsAllowed
            strikeouts += line.strikeouts; walks += line.walks
        }
        let inningsPerStart = Double(outs) / 3 / Double(games)
        XCTAssertGreaterThan(inningsPerStart, 4.0, "고교 선발이 너무 일찍 내려옵니다")
        XCTAssertLessThan(inningsPerStart, 6.1, "6이닝 목표를 넘겼습니다")
        XCTAssertLessThan(Double(walks) * 27 / Double(outs), 6.0, "볼넷이 야구가 아닙니다")
        XCTAssertGreaterThan(strikeouts, 0)
    }

    /// **영점 감시.** 시뮬레이터나 난이도 보정을 바꾸면 여기서 먼저 실패해야 한다.
    ///
    /// **실제 일정으로 잰다.** 예전에는 오프셋 −6 고정으로 쟀는데, 실제 일정은 대회 챕터가
    /// 프로 수준(오프셋 0)이라 그 측정이 처음부터 실제보다 낮았다. 그 격차가 난이도 보정과
    /// 겹치면서 드래프트 통과율이 30%에서 10%로 떨어진 적이 있다.
    func testHighSchoolBaselineMatchesTheSimulator() {
        let simulator = AutoOutingSimulator()
        var rng = SplitMix64(seed: 99)
        var outs = 0, runs = 0
        for chapter in 1...8 {
            // 대회 챕터(4·8)는 프로 수준, 나머지는 고교 수준. `simulateChapterGames`와 같은 규칙이다.
            let base = (chapter == 4 || chapter == 8) ? 0 : -6
            let offset = base + DifficultyScale.highSchool(chapter: chapter, lifeNumber: 1)
            for index in 0..<15 {
                let line = simulator.simulate(
                    pitcher: PitcherPresetCatalog.all[0].pitcher,
                    startingFatigue: 20 + (index % 3) * 6,
                    outsTarget: 18, pitchCap: 90, batterOffset: offset,
                    baseSeed: rng.next()
                )
                outs += line.outs; runs += line.runsAllowed
            }
        }
        let measured = runs * 27_000 / outs
        let baseline = HighSchoolCareerEngine.highSchoolBaseline(lifeNumber: 1)
        XCTAssertEqual(
            Double(measured), Double(baseline), accuracy: 900,
            "고교 평균 실점이 \(measured)‰인데 영점은 \(baseline)‰입니다. 영점을 다시 재세요."
        )
    }

    func testNoSeasonLogMeansNoTerm() {
        XCTAssertEqual(seasonTerm(outs: 0, runs: 0), 0)
    }

    /// 잘 던진 시즌은 +, 못 던진 시즌은 -. 양쪽 다 캡에 걸린다.
    ///
    /// 기준값은 영점(`highSchoolBaseline`)에서 계산한다. 난이도 보정이 들어오면서 영점이
    /// 회차에 따라 움직이므로, 고정 실점 수를 적어 두면 밸런스를 만질 때마다 테스트가 깨진다.
    func testSeasonTermIsSignedAndCapped() {
        let zero = HighSchoolCareerEngine.highSchoolBaseline(lifeNumber: 1)
        // 84이닝 기준으로 영점에 해당하는 실점 수.
        let outs = 252
        func runs(forRA9Permille value: Int) -> Int { value * outs / 27_000 }

        XCTAssertEqual(seasonTerm(outs: outs, runs: 0), 4, "무실점은 상한이어야 한다")
        // 영점보다 9이닝당 1.0점 이상 나쁘면 하한.
        XCTAssertEqual(seasonTerm(outs: outs, runs: runs(forRA9Permille: zero + 1_200)), -4)
        // 잘 던졌지만 캡까지는 아닌 구간이 실제로 존재해야 한다 —
        // 전부 캡에 붙으면 항이 순위를 바꾸지 못한다.
        let good = seasonTerm(outs: outs, runs: runs(forRA9Permille: zero - 600))
        XCTAssertGreaterThan(good, 0)
        XCTAssertLessThan(good, 4, "잘 던진 시즌이 전부 상한에 붙습니다")
        // 영점 부근은 0에 가깝다
        XCTAssertLessThanOrEqual(abs(seasonTerm(outs: outs, runs: runs(forRA9Permille: zero))), 1)
    }

    /// 영점이 회차를 따라 올라간다. 안 그러면 회차가 쌓일수록 모든 시즌이 평균 이하로 찍힌다.
    func testBaselineRisesWithTheLifeNumber() {
        let first = HighSchoolCareerEngine.highSchoolBaseline(lifeNumber: 1)
        let third = HighSchoolCareerEngine.highSchoolBaseline(lifeNumber: 3)
        XCTAssertGreaterThan(third, first)
    }

    /// 실제로 돌린 시즌들이 ±4 전 구간에 흩어지는가.
    ///
    /// 산술적으로 캡에 닿는다는 것(위 테스트)과, **시뮬레이터가 실제로 그 구간을 만들어
    /// 내는 것**은 다른 이야기다. 예전에 영점이 프로 기준이던 시절에는 모든 회차가 +4를
    /// 받아 항이 항목이 아니라 전원 가산점이었다. 그 사고는 산술 테스트로는 안 잡힌다.
    func testSeasonTermSpreadsAcrossTheWholeRange() {
        let simulator = AutoOutingSimulator()
        var rng = SplitMix64(seed: 4_242)
        var terms: [Int] = []
        for season in 0..<40 {
            var outs = 0, runs = 0
            // 한 회차분(챕터 8개 × 2경기)을 모아 하나의 시즌 항으로 만든다.
            for game in 0..<16 {
                let line = simulator.simulate(
                    pitcher: PitcherPresetCatalog.all[season % PitcherPresetCatalog.all.count].pitcher,
                    startingFatigue: 20 + (game % 3) * 6,
                    outsTarget: 18, pitchCap: 90, batterOffset: game % 4 == 0 ? 0 : -6,
                    baseSeed: rng.next()
                )
                outs += line.outs; runs += line.runsAllowed
            }
            terms.append(seasonTerm(outs: outs, runs: runs))
        }
        XCTAssertGreaterThan(terms.max() ?? 0, 0, "잘 던진 시즌이 하나도 없습니다: \(terms)")
        XCTAssertLessThan(terms.min() ?? 0, 0, "못 던진 시즌이 하나도 없습니다: \(terms)")
        XCTAssertGreaterThanOrEqual(Set(terms).count, 4, "시즌 항이 몇 개 값에만 몰렸습니다: \(terms)")
    }

    private func seasonTerm(outs: Int, runs: Int, lifeNumber: Int = 1) -> Int {
        guard outs > 0 else { return 0 }
        let raw = (HighSchoolCareerEngine.highSchoolBaseline(lifeNumber: lifeNumber) - runs * 27_000 / outs) * 4 / 1_000
        return min(4, max(-4, raw))
    }
}
