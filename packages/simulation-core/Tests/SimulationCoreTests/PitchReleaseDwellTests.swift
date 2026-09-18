import XCTest
@testable import SimulationCore

/// 릴리스 미터의 감속 곡선. 주기와 초록 창은 그대로 두고 금색 창만 겨눌 수 있게 만든다.
final class PitchReleaseDwellTests: XCTestCase {

    /// 한 주기 동안 조건을 만족한 시간(초). 1ms 간격으로 센다.
    private func dwellSeconds(
        sweep: Double, command: Int, condition: (Double) -> Bool
    ) -> Double {
        let stepSeconds = 0.001
        var seconds = 0.0
        var elapsed = 0.0
        while elapsed < sweep * 2 {
            let meter = PitchReleaseWindow.meterPosition(
                elapsed: elapsed, sweepSeconds: sweep, command: command)
            if condition(meter) { seconds += stepSeconds }
            elapsed += stepSeconds
        }
        return seconds / 2
    }

    private func isPerfect(_ meter: Double, command: Int) -> Bool {
        PitchReleaseWindow.calibratedAccuracy(
            raw: PitchReleaseWindow.rawAccuracy(meter: meter), command: command
        ) >= PitchDelivery.perfectReleaseThreshold
    }

    func testTheGoldWindowBecomesAimableAndGrowsWithCommand() {
        // 135km/h 기준 왕복.
        let sweep = DeliveryTempo.sweepSeconds(velocityTenthsKPH: 1_350, fatigue: 0)
        let baseline = dwellSeconds(sweep: sweep, command: 35) { isPerfect($0, command: 35) }
        let grown = dwellSeconds(sweep: sweep, command: 80) { isPerfect($0, command: 80) }
        // 선형 왕복에서는 25ms 안팎이었다. 사람이 노려서 맞힐 수 있는 폭이 아니다.
        XCTAssertGreaterThan(baseline, 0.035)
        XCTAssertLessThan(baseline, 0.055)
        XCTAssertGreaterThan(grown, baseline, "제구가 오를수록 정중앙에 더 오래 머문다")
        XCTAssertLessThan(grown, 0.065)
    }

    func testTheGreenWindowKeepsItsTiming() {
        let sweep = DeliveryTempo.sweepSeconds(velocityTenthsKPH: 1_350, fatigue: 0)
        for command in [35, 50, 80] {
            let curved = dwellSeconds(sweep: sweep, command: command) {
                PitchReleaseWindow.contains(meter: $0, command: command)
            }
            let linear = linearGreenSeconds(sweep: sweep, command: command)
            // 초록 창의 시간은 감속 전후로 10% 안에서 유지된다 — 기존 손맛을 바꾸지 않는다.
            XCTAssertEqual(curved, linear, accuracy: linear * 0.1)
        }
    }

    /// 감속이 없던 시절의 초록 창 체류 시간.
    private func linearGreenSeconds(sweep: Double, command: Int) -> Double {
        let stepSeconds = 0.001
        var seconds = 0.0
        var elapsed = 0.0
        while elapsed < sweep * 2 {
            let cycle = elapsed / sweep
            let whole = cycle.rounded(.down)
            let fraction = cycle - whole
            let meter = Int(whole) % 2 == 0 ? fraction : 1 - fraction
            if PitchReleaseWindow.contains(meter: meter, command: command) { seconds += stepSeconds }
            elapsed += stepSeconds
        }
        return seconds / 2
    }

    func testTheNeedleReachesTheMiddleAtTheSameTimeAsAPlainSweep() {
        let sweep = 1.18
        for command in [35, 60, 80] {
            for leg in 0..<4 {
                let expected = (Double(leg) + 0.5) * sweep
                let elapsed = expected - 0.2
                XCTAssertEqual(
                    PitchReleaseWindow.secondsToRelease(elapsed: elapsed, sweepSeconds: sweep),
                    0.2, accuracy: 0.000_1)
                XCTAssertEqual(
                    PitchReleaseWindow.meterPosition(
                        elapsed: expected, sweepSeconds: sweep, command: command),
                    0.5, accuracy: 0.000_1,
                    "감속은 가운데를 가운데에 그대로 둔다")
            }
        }
    }

    func testTheCurveStaysInsideTheMeterAndIsMonotoneWithinALeg() {
        let sweep = 1.0
        var previous = PitchReleaseWindow.meterPosition(elapsed: 0, sweepSeconds: sweep, command: 50)
        var elapsed = 0.002
        while elapsed < sweep {
            let value = PitchReleaseWindow.meterPosition(
                elapsed: elapsed, sweepSeconds: sweep, command: 50)
            XCTAssertGreaterThanOrEqual(value, 0)
            XCTAssertLessThanOrEqual(value, 1)
            XCTAssertGreaterThanOrEqual(value, previous - 0.000_001, "한 다리 안에서는 되돌아가지 않는다")
            previous = value
            elapsed += 0.002
        }
    }
}

/// 테스트가 쓰는 템포. 앱의 `DeliveryControl.sweepSeconds`와 같은 식이다.
enum DeliveryTempo {
    static func sweepSeconds(velocityTenthsKPH: Int, fatigue: Int) -> Double {
        let velocity = Double(min(1_500, max(1_100, velocityTenthsKPH)) - 1_100) / 400
        let fatigueRatio = Double(min(100, max(0, fatigue))) / 100
        return 1.18 - velocity * 0.38 - fatigueRatio * 0.24
    }
}
