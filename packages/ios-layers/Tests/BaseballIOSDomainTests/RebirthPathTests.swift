import XCTest
import SimulationCore
@testable import BaseballIOSDomain

/// 세 갈래는 **커널이 받아 주는 조합**이어야 한다. 화면에만 있는 표를 따로 만들면
/// 시작 순간에 거부당하고, 플레이어는 회차를 잃는다.
final class RebirthPathTests: XCTestCase {
    func testEveryPathNamesARealPresetAndAValidRepertoire() throws {
        for path in RebirthPath.allCases {
            let preset = try XCTUnwrap(path.preset, path.rawValue)
            XCTAssertEqual(preset.id, path.presetID)
            // 커널이 그대로 삼킬 수 있어야 한다.
            XCTAssertNoThrow(try PitchLearningRules.validate(path.repertoire), path.rawValue)
            XCTAssertNoThrow(
                try PitchLearningRules.apply(selection: path.repertoire, to: preset.pitcher),
                path.rawValue
            )
        }
    }

    /// 세 길은 서로 다른 투수여야 한다 — 유형도, 주력 구종도 겹치지 않는다.
    func testThePathsActuallyDiverge() {
        let presets = Set(RebirthPath.allCases.map(\.presetID))
        XCTAssertEqual(presets.count, RebirthPath.allCases.count)
        let pitches = Set(RebirthPath.allCases.map(\.primaryPitch))
        XCTAssertEqual(pitches.count, RebirthPath.allCases.count)
        let builds = Set(RebirthPath.allCases.compactMap(\.buildIdentity))
        XCTAssertEqual(builds.count, RebirthPath.allCases.count)
    }

    /// 고교의 선택이 프로 목표까지 이어진다.
    func testOnlyTheCloserPathAimsAtTheBackEnd() {
        XCTAssertEqual(RebirthPath.closer.proRole, .closer)
        XCTAssertEqual(RebirthPath.endurance.proRole, .starter)
        XCTAssertEqual(RebirthPath.command.proRole, .starter)
    }

    /// 안드로이드가 정한 세 조합과 같은 프리셋·주력 구종을 쓴다.
    func testMatchesTheAndroidPathTable() {
        XCTAssertEqual(RebirthPath.endurance.presetID, "innings_eater")
        XCTAssertEqual(RebirthPath.endurance.primaryPitch, .fourSeam)
        XCTAssertEqual(RebirthPath.closer.presetID, "breaking_ball_artist")
        XCTAssertEqual(RebirthPath.closer.primaryPitch, .slider)
        XCTAssertEqual(RebirthPath.command.presetID, "precision_commander")
        XCTAssertEqual(RebirthPath.command.primaryPitch, .changeup)
    }
}
