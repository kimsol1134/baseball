import XCTest
@testable import BaseballIOSDomain

/// Phase 4. 회전은 커널 결과에서만 나온다 — 같은 공은 언제나 같은 회전이다.
final class PitchSpinPresentationTests: XCTestCase {
    func testTheSamePitchAlwaysSpinsTheSameWay() {
        let first = PitchSpinPresentation.seamAngle(
            horizontalBreakTenthsCM: 120, verticalBreakTenthsCM: -80,
            velocityTenthsKPH: 1_380, flightProgress: 0.5
        )
        let second = PitchSpinPresentation.seamAngle(
            horizontalBreakTenthsCM: 120, verticalBreakTenthsCM: -80,
            velocityTenthsKPH: 1_380, flightProgress: 0.5
        )
        XCTAssertEqual(first, second)
    }

    /// 빠른 공이 더 돈다. 순서가 뒤집히면 눈이 속도를 거꾸로 읽는다.
    func testFasterPitchesTurnMore() {
        XCTAssertGreaterThan(
            PitchSpinPresentation.revolutions(velocityTenthsKPH: 1_550),
            PitchSpinPresentation.revolutions(velocityTenthsKPH: 1_150)
        )
    }

    /// 60fps에서 깜빡임이 되지 않도록 눌러 담는다.
    func testRevolutionsStayInsideAReadableRange() {
        for velocity in [0, 800, 1_200, 1_450, 1_700, 9_999] {
            let turns = PitchSpinPresentation.revolutions(velocityTenthsKPH: velocity)
            XCTAssertGreaterThanOrEqual(turns, 0.8, "\(velocity)")
            XCTAssertLessThanOrEqual(turns, 3.4, "\(velocity)")
        }
    }

    /// 떠오르는 공과 떨어지는 공은 **반대로** 돈다 — 커브와 포심이 눈으로 갈린다.
    func testRiseAndDropSpinInOppositeDirections() {
        let rising = PitchSpinPresentation.seamAngle(
            horizontalBreakTenthsCM: 0, verticalBreakTenthsCM: 60,
            velocityTenthsKPH: 1_450, flightProgress: 1
        )
        let dropping = PitchSpinPresentation.seamAngle(
            horizontalBreakTenthsCM: 0, verticalBreakTenthsCM: -60,
            velocityTenthsKPH: 1_450, flightProgress: 1
        )
        XCTAssertGreaterThan(rising, 0)
        XCTAssertLessThan(dropping, 0)
    }

    /// 축은 눕되 뒤집히지 않는다.
    func testTiltIsBounded() {
        XCTAssertEqual(PitchSpinPresentation.axisTilt(horizontalBreakTenthsCM: 0), 0)
        XCTAssertEqual(PitchSpinPresentation.axisTilt(horizontalBreakTenthsCM: 10_000), 0.6, accuracy: 0.0001)
        XCTAssertEqual(PitchSpinPresentation.axisTilt(horizontalBreakTenthsCM: -10_000), -0.6, accuracy: 0.0001)
    }

    /// 릴리스 순간에는 아직 돌지 않았다.
    func testNoRotationBeforeTheBallLeavesTheHand() {
        XCTAssertEqual(
            PitchSpinPresentation.seamAngle(
                horizontalBreakTenthsCM: 0, verticalBreakTenthsCM: 40,
                velocityTenthsKPH: 1_400, flightProgress: 0
            ),
            0
        )
    }
}
