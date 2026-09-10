import XCTest
@testable import SimulationCore

/// 화면이 말하는 문턱과 커널이 실제로 하는 일을 붙들어 둔다. 여기가 깨지면 보드가
/// 거짓말을 하고 있는 것이므로, 밴드를 넓히지 말고 문턱 값을 다시 재야 한다.
final class ProOutingUsageRulesTests: XCTestCase {
    private let engine = ProCareerEngine()

    /// **체력 60이 5이닝을 연다.** 이 아래에서는 선발이 승리 자격에 거의 닿지 못한다.
    func testStaminaThresholdForFiveInningsIsWhereTheBoardSaysItIs() {
        let below = qualifyingStartRate(stamina: ProOutingUsageRules.staminaForFiveInnings - 5, outs: 15)
        let at = qualifyingStartRate(stamina: ProOutingUsageRules.staminaForFiveInnings, outs: 15)
        XCTAssertLessThan(below, 35, "문턱 아래에서 15아웃 도달률이 \(below)%입니다 — 문턱이 낮아졌습니다")
        XCTAssertGreaterThan(at, 60, "문턱에서 15아웃 도달률이 \(at)%뿐입니다 — 문턱이 높아졌습니다")
    }

    /// **체력 78이 완투 도전을 연다.** 그 아래에서 7회는 사실상 오지 않는다.
    func testStaminaThresholdForTheCompleteGameChaseIsWhereTheBoardSaysItIs() {
        let below = qualifyingStartRate(stamina: ProOutingUsageRules.staminaForCompleteGameChase - 3, outs: 21)
        let at = qualifyingStartRate(stamina: ProOutingUsageRules.staminaForCompleteGameChase, outs: 21)
        XCTAssertLessThan(below, 10, "문턱 아래에서 21아웃 도달률이 \(below)%입니다 — 문턱이 낮아졌습니다")
        XCTAssertGreaterThan(at, 20, "문턱에서 21아웃 도달률이 \(at)%뿐입니다 — 문턱이 높아졌습니다")
    }

    /// 커리어 조건(감독 배합 mixed, 피로 50)에서 `outs`아웃 이상 던진 등판의 비율(%).
    private func qualifyingStartRate(stamina: Int, outs target: Int) -> Int {
        let pitcher = PitcherSnapshot(id: "p", name: "t", stuff: 50, command: 60, movement: 40, stamina: stamina)
        let samples = 200
        var reached = 0
        for index in 0..<samples {
            let line = engine.simulateWeeklyOuting(
                pitcher: pitcher, startingFatigue: 50, outsTarget: 18, pitchCap: 96,
                callPolicy: .mixed, baseSeed: UInt64(index) &* 0x9E37_79B9_7F4A_7C15,
                diverseScouting: true, proRulesVersion: 13, fullStart: true
            )
            if line.outs >= target { reached += 1 }
        }
        return reached * 100 / samples
    }
}
