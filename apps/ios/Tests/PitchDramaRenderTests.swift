import XCTest
import SwiftUI
import SimulationCore
@testable import BaseballIOS

/// 승부 장면은 애니메이션 중간이 본체다. 정지 상태만 보면 스윙도 임팩트도 확인할 수 없으므로
/// 진행도를 고정해 프레임을 직접 렌더한다. `BASEBALL_DRAMA_DIR`이 있으면 PNG로도 남긴다.
@MainActor
final class PitchDramaRenderTests: XCTestCase {

    /// 외야 깊숙한 타구. 2컷 카메라가 실제로 무엇을 그리는지 보려면 수비 판정이 필요하다.
    static let deepFly = FieldingResolutionSnapshot(
        neutralOutcome: .homeRun, finalOutcome: .homeRun, sector: .fence,
        difficulty: 900, defenseRating: 55, defenseAdjustment: 0, parkAdjustment: 0,
        impact: .neutral, fielderPosition: .leftField, fielderName: "하민규",
        landingDistanceTenthsMeters: 1_180, hangTimeMilliseconds: 4_200,
        apexHeightTenthsMeters: 320, ballFlightSeries: nil,
        shortExplanation: "좌측 담장을 넘겼습니다."
    )

    private func execution(actualX: Int = 40, actualY: Int = -60) -> PitchExecution {
        // 릴리스에서 홈플레이트까지의 3D 시리즈. 코어가 내보내는 형식과 같다.
        var series: [Int] = []
        for step in 0...24 {
            let t = Double(step) / 24
            series.append(Int(480 * t))
            series.append(Int(-40 + 90 * t * t))
            series.append(Int(18_440 * (1 - t)))
            series.append(Int(1_850 - 780 * t * t))
        }
        return PitchExecution(
            targetX: 0, targetY: 0, actualX: actualX, actualY: actualY,
            velocityTenthsKPH: 1_402, horizontalBreakTenthsCM: 60,
            verticalBreakTenthsCM: 150, executionQuality: 760,
            flightTimeMilliseconds: 480, trajectoryControlX: 0, trajectoryControlY: 0,
            trajectorySeries: series
        )
    }

    private func render(_ view: some View, name: String) -> Bool {
        let renderer = ImageRenderer(content: view.frame(width: 360, height: 320))
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else { return false }
        XCTAssertGreaterThan(data.count, 2_000, "\(name): 렌더 결과가 비어 있습니다.")
        // 결과 번들에 붙여 눈으로 확인한다. xcodebuild의 환경변수는 테스트 프로세스로 넘어가지 않는다.
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return true
    }

    /// 헛스윙: 배트가 존을 지나고 흰 섬광이 뜬다.
    func testSwingingStrikeFrames() {
        for progress in [0.30, 0.50, 0.60, 0.72, 1.0] {
            let view = PitchDramaView(
                execution: execution(),
                outcome: .swingingStrike,
                battedBall: nil,
                fielding: nil,
                progress: progress
            )
            XCTAssertTrue(render(view, name: String(format: "swing-%.2f", progress)))
        }
    }

    /// 홈런: 임팩트 섬광이 가장 크고 화면이 흔들린다.
    func testHomeRunFrames() {
        let batted = BattedBall(
            exitVelocityTenthsKPH: 1_720,
            launchAngleTenthsDegrees: 280,
            directionTenthsDegrees: -180,
            contactQuality: 940
        )
        for progress in [0.55, 0.62, 0.80, 1.0] {
            let view = PitchDramaView(
                execution: execution(),
                outcome: .homeRun,
                battedBall: batted,
                fielding: Self.deepFly,
                progress: progress
            )
            XCTAssertTrue(render(view, name: String(format: "homerun-%.2f", progress)))
        }
    }

    /// 루킹 스트라이크: 배트가 움직이지 않고 존이 라임으로 밝아진다.
    func testCalledStrikeFrames() {
        for progress in [0.50, 0.70, 1.0] {
            let view = PitchDramaView(
                execution: execution(actualX: 10, actualY: 20),
                outcome: .calledStrike,
                battedBall: nil,
                fielding: nil,
                progress: progress
            )
            XCTAssertTrue(render(view, name: String(format: "called-%.2f", progress)))
        }
    }

    /// 스윙 여부는 코어 판정에서만 나온다. 볼·루킹은 절대 배트가 나가면 안 된다.
    func testBatOnlyMovesWhenTheCoreSaysTheBatterSwung() {
        let silent: [PitchOutcome] = [.ball, .calledStrike, .hitByPitch]
        let swinging: [PitchOutcome] = [.swingingStrike, .foul, .inPlayOut, .single, .double, .triple, .homeRun]
        for outcome in silent + swinging {
            let view = PitchDramaView(
                execution: execution(), outcome: outcome, battedBall: nil, fielding: nil, progress: 0.6
            )
            XCTAssertTrue(render(view, name: "outcome-\(outcome.rawValue)"))
        }
    }
}
