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

    /// **영점 감시.** 시뮬레이터나 타자 오프셋을 바꾸면 여기서 먼저 실패해야 한다.
    func testHighSchoolBaselineMatchesTheSimulator() {
        let simulator = AutoOutingSimulator()
        var rng = SplitMix64(seed: 99)
        var outs = 0, runs = 0
        for index in 0..<120 {
            let line = simulator.simulate(
                pitcher: PitcherPresetCatalog.all[0].pitcher,
                startingFatigue: 20 + (index % 3) * 6,
                outsTarget: 18, pitchCap: 90, batterOffset: -6,
                baseSeed: rng.next()
            )
            outs += line.outs; runs += line.runsAllowed
        }
        let measured = runs * 27_000 / outs
        let baseline = HighSchoolCareerEngine.highSchoolBaselineRA9Permille
        XCTAssertEqual(
            Double(measured), Double(baseline), accuracy: 700,
            "고교 평균 실점이 \(measured)‰인데 영점은 \(baseline)‰입니다. "
                + "highSchoolBaselineRA9Permille을 다시 재세요."
        )
    }

    func testNoSeasonLogMeansNoTerm() {
        XCTAssertEqual(seasonTerm(outs: 0, runs: 0), 0)
    }

    /// 잘 던진 시즌은 +, 못 던진 시즌은 -. 양쪽 다 캡에 걸린다.
    func testSeasonTermIsSignedAndCapped() {
        // 84이닝 무실점 → 상한
        XCTAssertEqual(seasonTerm(outs: 252, runs: 0), 4)
        // 84이닝 28실점(RA9 3.0) → 하한
        XCTAssertEqual(seasonTerm(outs: 252, runs: 28), -4)
        // 잘 던졌지만 캡까지는 아닌 구간이 실제로 존재해야 한다 —
        // 전부 캡에 붙으면 항이 순위를 바꾸지 못한다.
        let good = seasonTerm(outs: 252, runs: 7)
        XCTAssertGreaterThan(good, 0)
        XCTAssertLessThan(good, 4, "잘 던진 시즌이 전부 상한에 붙습니다")
        // 영점 부근은 0에 가깝다
        XCTAssertLessThanOrEqual(abs(seasonTerm(outs: 252, runs: 16)), 1)
    }

    private func seasonTerm(outs: Int, runs: Int) -> Int {
        guard outs > 0 else { return 0 }
        let raw = (HighSchoolCareerEngine.highSchoolBaselineRA9Permille - runs * 27_000 / outs) * 4 / 1_000
        return min(4, max(-4, raw))
    }
}
