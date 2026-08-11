import XCTest
import SwiftUI
import SimulationCore
@testable import BaseballIOS

/// 승부 장면을 PNG로 떨어뜨려 눈으로 확인하기 위한 내보내기.
///
/// `BASEBALL_SNAPSHOT_DIR`이 있을 때만 파일을 쓴다. 없으면 아무 일도 하지 않으므로
/// 평소 테스트 실행을 느리게 하거나 디스크를 더럽히지 않는다.
@MainActor
final class DramaSnapshotExportTests: XCTestCase {
    private func execution(actualX: Int, actualY: Int) -> PitchExecution {
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
            velocityTenthsKPH: 1_438, horizontalBreakTenthsCM: 60,
            verticalBreakTenthsCM: 150, executionQuality: 880,
            flightTimeMilliseconds: 470, trajectoryControlX: 0, trajectoryControlY: 0,
            trajectorySeries: series
        )
    }

    func testExportPitchDramaFrames() throws {
        // 시뮬레이터의 경로는 호스트에서도 실제 경로다(디바이스 data 컨테이너 아래).
        // 그래서 임시 디렉터리에 쓰고 그 자리를 찍어 주면 밖에서 바로 열 수 있다.
        // xcodebuild의 환경변수는 이 테스트 프로세스로 넘어오지 않으므로 경로를 받지 않는다.
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("baseball-drama-snapshots", isDirectory: true)
        try? FileManager.default.removeItem(at: base)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        let frames: [(name: String, view: AnyView)] = [
            ("drama-right-catch", AnyView(PitchDramaView(
                execution: execution(actualX: 120, actualY: -180), outcome: .calledStrike,
                battedBall: nil, fielding: nil, batSide: .right, progress: 0.62
            ))),
            ("drama-left-catch", AnyView(PitchDramaView(
                execution: execution(actualX: -240, actualY: 60), outcome: .swingingStrike,
                battedBall: nil, fielding: nil, batSide: .left, progress: 0.62
            ))),
            ("drama-incoming", AnyView(PitchDramaView(
                execution: execution(actualX: 60, actualY: -60), outcome: .calledStrike,
                battedBall: nil, fielding: nil, batSide: .right, progress: 0.30
            ))),
        ]

        for frame in frames {
            let renderer = ImageRenderer(
                content: frame.view
                    .frame(width: 360, height: 320)
                    .background(BaseballTheme.fieldNight)
                    .environment(\.colorScheme, .dark)
            )
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage, "\(frame.name): 렌더 실패")
            let data = try XCTUnwrap(image.pngData())
            try data.write(to: base.appendingPathComponent("\(frame.name).png"))
        }
        print("[drama-snapshot] \(base.path)")
    }
}
