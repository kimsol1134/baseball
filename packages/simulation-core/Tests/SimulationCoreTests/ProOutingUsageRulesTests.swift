import XCTest
@testable import SimulationCore

/// 화면이 말하는 문턱과 커널이 실제로 하는 일을 붙들어 둔다. 여기가 깨지면 보드가
/// 거짓말을 하고 있는 것이므로, 밴드를 넓히지 말고 문턱 값을 다시 재야 한다.
final class ProOutingUsageRulesTests: XCTestCase {
    private let engine = ProCareerEngine()

    /// **체력 60이 5이닝을 연다.**
    ///
    /// 보드가 말하는 것은 "여기가 계단이다"이지 "여기서 몇 퍼센트다"가 아니다. 그래서 절대
    /// 비율이 아니라 **계단 자체**를 붙든다 — 커널을 다시 손봐도 계단이 이 자리에 남아
    /// 있으면 통과하고, 계단이 옮겨 가거나 사라지면 실패한다.
    func testStaminaThresholdForFiveInningsIsWhereTheBoardSaysItIs() {
        let below = qualifyingStartRate(stamina: ProOutingUsageRules.staminaForFiveInnings - 5, outs: 15)
        let at = qualifyingStartRate(stamina: ProOutingUsageRules.staminaForFiveInnings, outs: 15)
        XCTAssertGreaterThan(at, 60, "문턱에서 15아웃 도달률이 \(at)%뿐입니다 — 문턱이 높아졌습니다")
        XCTAssertGreaterThanOrEqual(
            at - below, 20,
            "체력 \(ProOutingUsageRules.staminaForFiveInnings - 5)→\(ProOutingUsageRules.staminaForFiveInnings)에서 \(below)%→\(at)%뿐입니다 — 계단이 사라졌습니다"
        )
    }

    /// **체력 78이 완투 도전을 연다.** 그 아래에서 7회는 사실상 오지 않는다.
    func testStaminaThresholdForTheCompleteGameChaseIsWhereTheBoardSaysItIs() {
        let below = qualifyingStartRate(stamina: ProOutingUsageRules.staminaForCompleteGameChase - 3, outs: 21)
        let at = qualifyingStartRate(stamina: ProOutingUsageRules.staminaForCompleteGameChase, outs: 21)
        XCTAssertGreaterThan(at, 20, "문턱에서 21아웃 도달률이 \(at)%뿐입니다 — 문턱이 높아졌습니다")
        XCTAssertGreaterThanOrEqual(
            at - below, 15,
            "체력 \(ProOutingUsageRules.staminaForCompleteGameChase - 3)→\(ProOutingUsageRules.staminaForCompleteGameChase)에서 \(below)%→\(at)%뿐입니다 — 계단이 사라졌습니다"
        )
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
