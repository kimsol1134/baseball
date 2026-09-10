import XCTest
@testable import SimulationCore

/// **안드로이드 커널과 같은 숫자를 낸다.**
///
/// 두 커널은 같은 등급·같은 타순·같은 스카우팅 표를 쓰면서도 일관되게 어긋나 있었다
/// (Swift 기준 K/9 −0.55 · WHIP +0.15). 원인은 포수의 코스 선택이었다 — Swift 자동 등판은
/// 한 타석 내내 같은 칸을 요구했고, 안드로이드는 최근 네 공이 갔던 칸을 깎아 코스를 옮겼다.
///
/// 아래 값은 안드로이드 `ProfessionalBalanceTest.calibratedPitcherDistribution`이 같은
/// 파라미터로 출력한 실측이다. 여기가 깨지면 두 커널이 다시 갈라진 것이므로, 밴드를 넓히지
/// 말고 어디서 갈라졌는지 찾아야 한다(이식 계획 §2.4의 추적 방법).
final class ProfessionalOutingParityTests: XCTestCase {
    /// 안드로이드 실측: 등급별 K/9 · RA/9 · WHIP · BB/9.
    private let android: [Int: (k9: Double, ra9: Double, whip: Double, bb9: Double)] = [
        45: (5.215, 4.962, 1.691, 3.570),
        50: (6.056, 4.625, 1.613, 3.535),
        55: (7.302, 4.191, 1.503, 3.353),
        60: (7.745, 4.409, 1.506, 3.121),
        70: (9.361, 2.743, 1.153, 2.063),
        80: (10.373, 2.273, 1.081, 1.808),
    ]

    func testAutomaticOutingsMatchTheAndroidKernel() {
        let simulator = AutoOutingSimulator(balance: .professionalWorkload)
        for (rating, expected) in android.sorted(by: { $0.key < $1.key }) {
            let pitcher = PitcherSnapshot(
                id: "audit", name: "검증 투수",
                stuff: rating, command: rating, movement: rating, stamina: rating
            )
            // 안드로이드와 같은 파라미터: 시작 피로 10 · 18아웃 · 투구 상한 100 · 시드 i×918221.
            let lines = (1...120).map { index in
                simulator.simulate(
                    pitcher: pitcher, startingFatigue: 10, outsTarget: 18, pitchCap: 100,
                    baseSeed: UInt64(index) &* 918_221, diverseScouting: true
                )
            }
            let outs = Double(lines.reduce(0) { $0 + $1.outs })
            XCTAssertGreaterThan(outs, 0, "등급 \(rating)")
            func per9(_ total: Int) -> Double { Double(total) * 27 / outs }

            assertClose(per9(lines.reduce(0) { $0 + $1.strikeouts }), expected.k9, "등급 \(rating) K/9")
            assertClose(per9(lines.reduce(0) { $0 + $1.runsAllowed }), expected.ra9, "등급 \(rating) RA/9")
            assertClose(per9(lines.reduce(0) { $0 + $1.walks }), expected.bb9, "등급 \(rating) BB/9")
            assertClose(
                Double(lines.reduce(0) { $0 + $1.hits + $1.walks }) * 3 / outs,
                expected.whip,
                "등급 \(rating) WHIP"
            )
        }
    }

    /// 소수 셋째 자리까지 같아야 한다. 두 커널이 같은 공을 던지면 반올림 말고는 다를 것이 없다.
    private func assertClose(_ actual: Double, _ expected: Double, _ label: String) {
        XCTAssertEqual(
            actual, expected, accuracy: 0.01,
            "\(label): Swift \(String(format: "%.3f", actual)) · 안드로이드 \(String(format: "%.3f", expected))"
        )
    }
}
