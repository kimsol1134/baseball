import XCTest
import SwiftUI
import SimulationCore
@testable import BaseballIOS

/// 홍보 영상용 프레임 시퀀스 내보내기.
///
/// 화면 녹화로는 승부 장면을 담을 수 없다. XCUITest가 대상 앱의 애니메이션을 꺼 버려서
/// 1.6초짜리 재생이 최종 프레임으로 튄다. 대신 `PitchDramaView`의 진행도를 직접 넣어
/// 60fps 프레임을 뽑는다. 결정적 렌더라 매번 같은 그림이 나오고, 배율도 원하는 대로 준다.
///
/// 결과는 앱 컨테이너의 Documents/promo-frames 아래에 쌓인다. 호스트에서 꺼내려면:
///   xcrun simctl get_app_container booted com.solkim.baseball.ios data
///
/// CI에서는 시간만 먹으므로 `-skip-testing`으로 제외한다(.github/workflows/ci.yml).
@MainActor
final class PromoFrameExportTests: XCTestCase {

    /// 세로 영상에 그대로 얹을 수 있는 크기. 3배로 렌더해 1170×1380이 된다.
    private let size = CGSize(width: 390, height: 460)
    private let fps = 60
    private let duration = 2.0

    private var root: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("promo-frames", isDirectory: true)
    }

    /// 코어가 내보내는 형식과 같은 릴리스→홈플레이트 3D 시리즈.
    private func execution(actualX: Int, actualY: Int, velocity: Int) -> PitchExecution {
        var series: [Int] = []
        for step in 0...24 {
            let t = Double(step) / 24
            series.append(Int(Double(actualX) * t))
            series.append(Int(-40 + Double(actualY + 40) * t * t))
            series.append(Int(18_440 * (1 - t)))
            series.append(Int(1_850 - 780 * t * t))
        }
        return PitchExecution(
            targetX: 0, targetY: 0, actualX: actualX, actualY: actualY,
            velocityTenthsKPH: velocity, horizontalBreakTenthsCM: 60,
            verticalBreakTenthsCM: 150, executionQuality: 820,
            flightTimeMilliseconds: 470, trajectoryControlX: 0, trajectoryControlY: 0,
            trajectorySeries: series
        )
    }

    private func write(_ view: some View, to directory: URL, index: Int) throws {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw XCTSkip("렌더 실패")
        }
        let name = String(format: "%04d.png", index)
        try data.write(to: directory.appendingPathComponent(name))
    }

    /// 한 장면을 통째로 뽑는다. 이름이 곧 Remotion에서 쓰는 폴더 이름이 된다.
    private func export(
        name: String,
        outcome: PitchOutcome,
        execution: PitchExecution,
        battedBall: BattedBall?,
        fielding: FieldingResolutionSnapshot?
    ) throws {
        let directory = root.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let total = Int(duration * Double(fps))
        for frame in 0..<total {
            // 재생은 1.6초. 뒤 0.4초는 판정이 남아 있는 상태를 그대로 유지한다.
            let progress = min(1.0, Double(frame) / (1.6 * Double(fps)))
            let view = PitchDramaView(
                execution: execution,
                outcome: outcome,
                battedBall: battedBall,
                fielding: fielding,
                progress: progress
            )
            try write(view, to: directory, index: frame)
        }
        print("PROMO_FRAMES \(name) \(total) \(directory.path)")
    }

    /// 루킹 스트라이크. 존 안으로 정확히 들어가 라임이 번지는 장면.
    func testExportCalledStrike() throws {
        try export(
            name: "called-strike",
            outcome: .calledStrike,
            execution: execution(actualX: -30, actualY: 20, velocity: 1_412),
            battedBall: nil,
            fielding: nil
        )
    }

    /// 헛스윙. 배트가 지나가고 흰 섬광이 뜬다.
    func testExportSwingingStrike() throws {
        try export(
            name: "swinging-strike",
            outcome: .swingingStrike,
            execution: execution(actualX: 60, actualY: -80, velocity: 1_386),
            battedBall: nil,
            fielding: nil
        )
    }

    /// 홈런. 2컷 카메라가 필드로 넘어가 타구가 담장을 넘는다. 영상의 절정.
    func testExportHomeRun() throws {
        let batted = BattedBall(
            exitVelocityTenthsKPH: 1_742,
            launchAngleTenthsDegrees: 285,
            directionTenthsDegrees: -170,
            contactQuality: 950
        )
        let fielding = FieldingResolutionSnapshot(
            neutralOutcome: .homeRun, finalOutcome: .homeRun, sector: .fence,
            difficulty: 940, defenseRating: 55, defenseAdjustment: 0, parkAdjustment: 0,
            impact: .neutral, fielderPosition: .leftField, fielderName: "하민규",
            landingDistanceTenthsMeters: 1_215, hangTimeMilliseconds: 4_300,
            apexHeightTenthsMeters: 330, ballFlightSeries: nil,
            shortExplanation: "좌측 담장을 넘겼습니다."
        )
        try export(
            name: "home-run",
            outcome: .homeRun,
            execution: execution(actualX: 20, actualY: 40, velocity: 1_425),
            battedBall: batted,
            fielding: fielding
        )
    }

    /// 잡아낸 타구. 수비수가 붙는 2컷을 보여 준다.
    func testExportInPlayOut() throws {
        let batted = BattedBall(
            exitVelocityTenthsKPH: 1_390,
            launchAngleTenthsDegrees: 240,
            directionTenthsDegrees: 120,
            contactQuality: 610
        )
        let fielding = FieldingResolutionSnapshot(
            neutralOutcome: .inPlayOut, finalOutcome: .inPlayOut, sector: .outfield,
            difficulty: 480, defenseRating: 62, defenseAdjustment: 0, parkAdjustment: 0,
            impact: .neutral, fielderPosition: .rightField, fielderName: "정도현",
            landingDistanceTenthsMeters: 830, hangTimeMilliseconds: 3_600,
            apexHeightTenthsMeters: 210, ballFlightSeries: nil,
            shortExplanation: "우익수가 잡아냈습니다."
        )
        try export(
            name: "in-play-out",
            outcome: .inPlayOut,
            execution: execution(actualX: -10, actualY: -20, velocity: 1_398),
            battedBall: batted,
            fielding: fielding
        )
    }

    /// 파울. 페어 지역 필드 카메라로 넘어가면 안 된다 — 파울은 페어에 떨어지지 않는다.
    func testExportFoul() throws {
        let batted = BattedBall(
            exitVelocityTenthsKPH: 1_120,
            launchAngleTenthsDegrees: 520,
            directionTenthsDegrees: 620,
            contactQuality: 380
        )
        try export(
            name: "foul",
            outcome: .foul,
            execution: execution(actualX: 35, actualY: -25, velocity: 1_366),
            battedBall: batted,
            fielding: nil
        )
    }
}
