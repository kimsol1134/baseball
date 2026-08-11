import XCTest
import SimulationCore
@testable import BaseballIOS

/// 제스처 → 투구 품질 변환. 이 앱의 최고 자산인데 자동 테스트가 하나도 없었다.
///
/// `delivery(meter:aim:aimRadius:)`는 순수 함수다 — 미터 값과 조준 이탈만 받아 릴리스·조준
/// 점수를 만든다. 여기서 계약이 깨지면 손맛 전체가 조용히 무너지는데, UI 테스트는 전부
/// `-uiTestAutoRelease`로 이 경로를 우회하므로 아무도 알아채지 못한다.
final class DeliveryControlTests: XCTestCase {
    private let radius: CGFloat = 46

    // MARK: - 릴리스

    func testMeterCenterIsPerfectRelease() {
        let delivery = DeliveryControl.delivery(meter: 0.5, aim: .zero, aimRadius: radius)
        XCTAssertEqual(delivery.releaseAccuracy, 1_000)
    }

    func testMeterEndsAreWorstRelease() {
        XCTAssertEqual(DeliveryControl.delivery(meter: 0, aim: .zero, aimRadius: radius).releaseAccuracy, 0)
        XCTAssertEqual(DeliveryControl.delivery(meter: 1, aim: .zero, aimRadius: radius).releaseAccuracy, 0)
    }

    /// 중심에서 멀어질수록 단조 감소해야 한다. 어느 구간에서 되레 올라가면 "가운데에서 뗀다"는
    /// 규칙 자체가 거짓이 된다.
    func testReleaseFallsMonotonicallyFromCenter() {
        var previous = 1_001
        for step in 0...10 {
            let meter = 0.5 + Double(step) * 0.05
            let score = DeliveryControl.delivery(meter: meter, aim: .zero, aimRadius: radius).releaseAccuracy
            XCTAssertLessThanOrEqual(score, previous, "미터 \(meter)에서 릴리스가 다시 올라갔습니다.")
            previous = score
        }
    }

    /// 중심을 기준으로 좌우 대칭이다. 한쪽이 유리하면 미터를 외워서 한 방향으로만 노린다.
    func testReleaseIsSymmetricAroundCenter() {
        for step in 1...9 {
            let offset = Double(step) * 0.05
            XCTAssertEqual(
                DeliveryControl.delivery(meter: 0.5 - offset, aim: .zero, aimRadius: radius).releaseAccuracy,
                DeliveryControl.delivery(meter: 0.5 + offset, aim: .zero, aimRadius: radius).releaseAccuracy
            )
        }
    }

    func testFasterPitchHasFasterReleaseMeter() {
        let fourSeam = DeliveryControl.sweepSeconds(
            velocityTenthsKPH: 1_470, fatigue: 20
        )
        let curveball = DeliveryControl.sweepSeconds(
            velocityTenthsKPH: 1_180, fatigue: 20
        )
        XCTAssertLessThan(fourSeam, curveball)
    }

    func testFatigueSpeedsUpReleaseMeter() {
        let fresh = DeliveryControl.sweepSeconds(
            velocityTenthsKPH: 1_350, fatigue: 0
        )
        let tired = DeliveryControl.sweepSeconds(
            velocityTenthsKPH: 1_350, fatigue: 100
        )
        XCTAssertLessThan(tired, fresh)
    }

    // MARK: - 조준

    func testAimOnTargetIsPerfect() {
        XCTAssertEqual(DeliveryControl.delivery(meter: 0.5, aim: .zero, aimRadius: radius).aimAccuracy, 1_000)
    }

    func testAimAtRadiusIsZero() {
        let delivery = DeliveryControl.delivery(meter: 0.5, aim: CGSize(width: radius, height: 0), aimRadius: radius)
        XCTAssertEqual(delivery.aimAccuracy, 0)
    }

    /// 반경 밖으로 더 끌어도 0 아래로 내려가지 않는다(그리고 음수 점수가 커널에 새지 않는다).
    func testAimBeyondRadiusClampsToZero() {
        let delivery = DeliveryControl.delivery(meter: 0.5, aim: CGSize(width: radius * 4, height: radius * 4), aimRadius: radius)
        XCTAssertEqual(delivery.aimAccuracy, 0)
    }

    /// 이탈은 방향이 아니라 거리로만 잰다. 대각선 이탈이 같은 거리의 수평 이탈과 같아야 한다.
    func testAimUsesDistanceNotAxis() {
        let diagonal = radius / CGFloat(2.0.squareRoot())
        XCTAssertEqual(
            DeliveryControl.delivery(meter: 0.5, aim: CGSize(width: diagonal, height: diagonal), aimRadius: radius).aimAccuracy,
            DeliveryControl.delivery(meter: 0.5, aim: CGSize(width: radius, height: 0), aimRadius: radius).aimAccuracy,
            accuracy: 1
        )
    }

    // MARK: - 판정 문구

    func testVerdictBandsMatchScores() {
        XCTAssertEqual(DeliveryControl.verdict(PitchDelivery(releaseAccuracy: 900, aimAccuracy: 900))?.text, "완벽한 릴리스")
        XCTAssertEqual(DeliveryControl.verdict(PitchDelivery(releaseAccuracy: 700, aimAccuracy: 700))?.text, "좋은 릴리스")
        // 정확히 500/500은 자동 릴리스의 중립값이라 판정이 없다(아래 테스트). 손으로 만든
        // 무난한 공을 보려면 그 값을 피해야 한다.
        XCTAssertEqual(DeliveryControl.verdict(PitchDelivery(releaseAccuracy: 520, aimAccuracy: 480))?.text, "무난한 릴리스")
        XCTAssertEqual(DeliveryControl.verdict(PitchDelivery(releaseAccuracy: 100, aimAccuracy: 100))?.text, "손에서 빠졌습니다")
    }

    /// 자동 릴리스(접근성 경로)로 던진 공은 판정을 내지 않는다. 손으로 만든 결과가 아니다.
    func testNeutralDeliveryHasNoVerdict() {
        XCTAssertNil(DeliveryControl.verdict(.neutral))
    }
}

/// 코스 이름은 타자 기준이다. 좌타자에게는 몸쪽·바깥쪽이 뒤집힌다.
final class PitchCopyZoneTests: XCTestCase {
    func testRightHandedLabelsAreUnchanged() {
        XCTAssertEqual(PitchCopy.zone(PitchZone(row: 0, column: 0), batSide: .right), "높은 몸쪽")
        XCTAssertEqual(PitchCopy.zone(PitchZone(row: 2, column: 2), batSide: .right), "낮은 바깥쪽")
    }

    func testLeftHandedLabelsMirrorColumns() {
        XCTAssertEqual(PitchCopy.zone(PitchZone(row: 0, column: 0), batSide: .left), "높은 바깥쪽")
        XCTAssertEqual(PitchCopy.zone(PitchZone(row: 2, column: 2), batSide: .left), "낮은 몸쪽")
    }

    /// 가운데 열은 어느 쪽 타자에게도 가운데다.
    func testMiddleColumnIsSideIndependent() {
        for row in 0..<3 {
            XCTAssertEqual(
                PitchCopy.zone(PitchZone(row: row, column: 1), batSide: .left),
                PitchCopy.zone(PitchZone(row: row, column: 1), batSide: .right)
            )
        }
    }

    /// 아무것도 결정하지 않은 공에는 진동을 주지 않는다.
    func testNeutralOutcomesDoNotBuzz() {
        XCTAssertNil(PitchCopy.hapticSuccess(.ball))
        XCTAssertNil(PitchCopy.hapticSuccess(.foul))
        XCTAssertEqual(PitchCopy.hapticSuccess(.swingingStrike), true)
        XCTAssertEqual(PitchCopy.hapticSuccess(.homeRun), false)
    }
}
