import SwiftUI
import XCTest
import SimulationCore
@testable import BaseballIOS

/// 훈련 결과가 다음 국면 선택을 덮지 않는지. 소스에 문자열을 찾으면 리팩터에만 깨진다.
final class HighSchoolTrainingResultLayoutTests: XCTestCase {
    func testTrainingResultIsCompactOutsideTrainingPhase() {
        XCTAssertFalse(HighSchoolCareerView.trainingResultIsCompact(phase: .training))
        for phase in HighSchoolCareerPhase.allCases where phase != .training {
            XCTAssertTrue(
                HighSchoolCareerView.trainingResultIsCompact(phase: phase),
                "\(phase.rawValue)에서는 결과 카드를 접어야 관계·토너먼트를 가리지 않는다."
            )
        }
    }

    func testPitchLearningReceiptStaysVisibleWhenResultIsCompact() throws {
        let source = try IOSSourceScan.typeBody(
            "TrainingResultPanel",
            in: "apps/ios/Sources/Features/HighSchool/HighSchoolTrainingResultViews.swift"
        )
        XCTAssertTrue(source.contains("hs.training.result.pitchLearning"))
        let compactLine = try XCTUnwrap(source.split(separator: "\n").first { $0.contains("if !compact {") })
        let learningLine = try XCTUnwrap(
            source.split(separator: "\n").first { $0.contains("if let learning = receipt.pitchLearning") }
        )
        let compactIndent = compactLine.prefix { $0 == " " }.count
        let learningIndent = learningLine.prefix { $0 == " " }.count
        XCTAssertEqual(
            compactIndent,
            learningIndent,
            "구종 학습 영수증이 compact 분기에 가려지면 안 됩니다."
        )
    }
}
