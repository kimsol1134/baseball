import XCTest
@testable import SimulationCore

/// 프로 재조정 경로(v12·v13)가 실제 리그의 폭 안에 있는가.
///
/// 이 검사는 안드로이드 `ProfessionalBalanceTest`의 쌍이다. 두 커널이 같은 규칙을 돌리므로
/// 같은 질문을 같은 방식으로 물어야 한 쪽이 밀렸을 때 드러난다. 기준은
/// `docs/android-compose/benchmarks/pro-pitching-2023-2025.json`의 KBO 3시즌 합계다.
final class ProfessionalBalanceTests: XCTestCase {

    private func lines(rating: Int, seeds: Int = 120) -> [AutoOutingSimulator.Line] {
        let simulator = AutoOutingSimulator(balance: .professionalWorkload)
        let pitcher = PitcherSnapshot(
            id: "audit", name: "검증 투수",
            stuff: rating, command: rating, movement: rating, stamina: rating
        )
        return (1...seeds).map {
            simulator.simulate(
                pitcher: pitcher, startingFatigue: 10, outsTarget: 18, pitchCap: 100,
                baseSeed: UInt64($0) &* 918_221, diverseScouting: true
            )
        }
    }

    /// 등급별 성적이 야구가 되는 범위 안에 있는가. 리그 평균(55)은 실제 KBO 근처여야 하고,
    /// 최고 등급(80)이라도 주자를 아예 못 내보내는 일은 없어야 한다.
    func testCalibratedPitcherDistribution() {
        for rating in [45, 50, 55, 60, 70, 80] {
            let sample = lines(rating: rating)
            let outs = Double(sample.reduce(0) { $0 + $1.outs })
            XCTAssertGreaterThan(outs, 0, "등급 \(rating)에서 아웃이 하나도 없다")
            let kPer9 = Double(sample.reduce(0) { $0 + $1.strikeouts }) * 27 / outs
            let runsPer9 = Double(sample.reduce(0) { $0 + $1.runsAllowed }) * 27 / outs
            let whip = Double(sample.reduce(0) { $0 + $1.hits + $1.walks }) * 3 / outs
            let earnedPer9 = Double(sample.reduce(0) { $0 + ($1.earnedRuns ?? 0) }) * 27 / outs
            let walksPer9 = Double(sample.reduce(0) { $0 + $1.walks }) * 27 / outs
            let homeRunsPer9 = Double(sample.reduce(0) { $0 + $1.homeRuns }) * 27 / outs
            print(
                "PROBE rating=\(rating) K9=\(kPer9) RA9=\(runsPer9) ERA=\(earnedPer9)"
                    + " WHIP=\(whip) BB9=\(walksPer9) HR9=\(homeRunsPer9)"
            )
            XCTAssertTrue(
                sample.allSatisfy { line in
                    guard let earned = line.earnedRuns else { return false }
                    return line.strikeouts <= line.outs && (0...line.runsAllowed).contains(earned)
                },
                "등급 \(rating): 자책점이 없거나 실점을 넘는다"
            )
            XCTAssertTrue(
                sample.contains { ($0.earnedRuns ?? 0) < $0.runsAllowed },
                "등급 \(rating): 실책이 비자책 실점을 만들지 않는다"
            )
            XCTAssertTrue((3.0...13.0).contains(kPer9), "등급 \(rating)의 삼진이 밴드를 벗어남: \(kPer9)")
            if rating == 55 {
                XCTAssertTrue((6.0...9.0).contains(kPer9), "리그 평균 K/9: \(kPer9)")
                XCTAssertTrue((1.25...1.65).contains(whip), "리그 평균 WHIP: \(whip)")
                XCTAssertTrue((3.5...6.0).contains(runsPer9), "리그 평균 RA/9: \(runsPer9)")
            }
            if rating == 80 {
                XCTAssertTrue((0.85...1.35).contains(whip), "최고 등급 WHIP: \(whip)")
            }
        }
    }

    /// 규칙 버전이 밸런스 경로를 고른다. 고정 참조(10)는 원장을 만들지 않고, 12부터 만든다.
    func testRulesVersionSelectsTheBalancePass() {
        let engine = ProCareerEngine()
        let pitcher = PitcherPresetCatalog.all[0].pitcher
        let reference = engine.simulateWeeklyOuting(
            pitcher: pitcher, startingFatigue: 10, outsTarget: 18, pitchCap: 96,
            baseSeed: 918_221, proRulesVersion: ProGameplayRules.reference
        )
        let rebalanced = engine.simulateWeeklyOuting(
            pitcher: pitcher, startingFatigue: 10, outsTarget: 18, pitchCap: 96,
            baseSeed: 918_221, proRulesVersion: 12
        )
        XCTAssertNil(reference.earnedRuns, "고정 참조 경로는 자책점을 만들지 않는다 — 추정하면 거짓말이 된다")
        XCTAssertNotNil(rebalanced.earnedRuns, "v12 등판은 원장을 남겨야 한다")
        XCTAssertLessThanOrEqual(rebalanced.earnedRuns ?? .max, rebalanced.runsAllowed)
    }

    /// 감독은 맞고 있는 투수를 내린다. 그리고 완봉 중인 에이스는 조금 더 끌고 간다.
    func testWorkloadRulesDecideTheChange() {
        let ace = PitcherSnapshot(id: "ace", name: "에이스", stuff: 70, command: 70, movement: 70, stamina: 70)
        XCTAssertTrue(
            ProOutingUsageRules.canContinue(
                pitcher: ace, outs: 15, pitches: 70, fatigue: 40, runs: 1, starter: true
            ),
            "5이닝 1실점에서 내려가면 완투는 영원히 못 한다"
        )
        XCTAssertFalse(
            ProOutingUsageRules.canContinue(
                pitcher: ace, outs: 15, pitches: 70, fatigue: 40, runs: 6, starter: true
            ),
            "6실점이면 경기를 내려놓는다"
        )
        XCTAssertFalse(
            ProOutingUsageRules.canContinue(
                pitcher: ace, outs: 21, pitches: 70, fatigue: 40, runs: 4, starter: true
            ),
            "7회에 4실점이면 불펜이 나온다"
        )
        // 7회 무실점은 투구 수 예산을 조금 넘겨서라도 이어 던진다.
        let budget = ProOutingUsageRules.pitchBudget(ace)
        XCTAssertTrue(
            ProOutingUsageRules.canContinue(
                pitcher: ace, outs: 21, pitches: budget + 4, fatigue: 30, runs: 0, starter: true
            ),
            "무실점으로 8회에 들어가는 투수를 투구 수만으로 내리지 않는다"
        )
        XCTAssertFalse(
            ProOutingUsageRules.canContinue(
                pitcher: ace, outs: 12, pitches: 30, fatigue: 40, runs: 0, starter: false
            ),
            "불펜은 4이닝이 상한이다"
        )
    }

    /// 완투가 실제로 가능한가. 18아웃 상한이 남아 있으면 이 검사는 통과할 수 없다.
    func testAnAceCanFinishAGame() {
        let simulator = AutoOutingSimulator(balance: .professionalWorkload)
        let ace = PitcherSnapshot(id: "ace", name: "에이스", stuff: 75, command: 75, movement: 75, stamina: 78)
        let sample = (1...200).map {
            simulator.simulate(
                pitcher: ace, startingFatigue: 5, outsTarget: 18, pitchCap: 96,
                baseSeed: UInt64($0) &* 918_221, diverseScouting: true, fullStart: true
            )
        }
        XCTAssertTrue(sample.contains { $0.outs == 27 }, "에이스가 200번 던져 한 번도 완투하지 못했다")
        XCTAssertTrue(sample.allSatisfy { $0.outs <= 27 }, "한 경기에서 27아웃을 넘겼다")
        XCTAssertTrue(sample.allSatisfy { $0.pitches <= 125 }, "투구 수 상한을 넘겼다")
    }

    /// 퍼펙트 릴리스와 만렙 숙련이 삼진 자판기가 되지 않는가.
    func testPerfectDeliveryAndHighMasteryStillAllowHitsAndRuns() {
        let simulator = AutoOutingSimulator(balance: .professionalWorkload)
        let pitcher = PitcherSnapshot(
            id: "elite", name: "완성형 투수", stuff: 80, command: 80, movement: 80, stamina: 80,
            mastery: AbilityMasterySnapshot(stuff: 100, command: 100, movement: 100, stamina: 100)
        )
        let sample = (1...120).map {
            simulator.simulate(
                pitcher: pitcher, startingFatigue: 10, outsTarget: 18, pitchCap: 100,
                baseSeed: UInt64($0) &* 772_019, diverseScouting: true,
                delivery: PitchDelivery(releaseAccuracy: 1_000, aimAccuracy: 1_000)
            )
        }
        let outs = Double(sample.reduce(0) { $0 + $1.outs })
        let kPer9 = Double(sample.reduce(0) { $0 + $1.strikeouts }) * 27 / outs
        print("PERFECT_MASTERY K9=\(kPer9) H=\(sample.reduce(0) { $0 + $1.hits }) R=\(sample.reduce(0) { $0 + $1.runsAllowed })")
        XCTAssertLessThan(kPer9, 15.0, "퍼펙트 릴리스가 자동 삼진이 됐다: \(kPer9)")
        XCTAssertGreaterThan(sample.reduce(0) { $0 + $1.hits }, 100)
        XCTAssertGreaterThan(sample.reduce(0) { $0 + $1.runsAllowed }, 20)
    }
}
