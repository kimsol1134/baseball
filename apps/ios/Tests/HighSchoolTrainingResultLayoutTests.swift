import SwiftUI
import XCTest
import SimulationCore
@testable import BaseballIOS

/// 훈련 결과가 다음 국면 선택을 덮지 않는지. 소스에 문자열을 찾으면 리팩터에만 깨진다.
final class HighSchoolTrainingResultLayoutTests: XCTestCase {
    func testNewTrainingResultStaysFullOnFirstDestinationAndCompactsAfterNextAction() {
        XCTAssertFalse(HighSchoolCareerView.trainingResultIsCompact(receiptID: "training-2", spotlightID: "training-1", currentRevision: 5, spotlightRevision: 3))
        XCTAssertFalse(HighSchoolCareerView.trainingResultIsCompact(receiptID: "training-2", spotlightID: "training-2", currentRevision: 5, spotlightRevision: 5))
        XCTAssertTrue(HighSchoolCareerView.trainingResultIsCompact(receiptID: "training-2", spotlightID: "training-2", currentRevision: 6, spotlightRevision: 5))
    }

    @MainActor
    func testNextAppearanceCountdownMatchesPlayedSchedule() throws {
        let engine = HighSchoolCareerEngine()
        for seed in ["918220", "918221", "120212"] {
            var result = try engine.start(.init(seed: seed, presetID: "power_prospect"))
            XCTAssertNil(NextAppearanceCue.resolve(result.snapshot))
            result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
            result = try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: .haedongPower))
            XCTAssertEqual(TrainingSelection.initial(state: result.snapshot).intensity, .standard)
            let initial = try XCTUnwrap(NextAppearanceCue.resolve(result.snapshot))
            var trainings = 0
            var choices = 0
            for _ in 0..<60 {
                if result.snapshot.phase == .importantGame { break }
                let cue = try XCTUnwrap(NextAppearanceCue.resolve(result.snapshot))
                XCTAssertEqual(cue.trainings, initial.trainings - trainings)
                XCTAssertEqual(cue.choices, initial.choices - choices)
                switch result.snapshot.phase {
                case .training:
                    trainings += 1
                    result = try engine.commitTraining(.init(seed: result.nextSeed, state: result.snapshot, focus: .command, intensity: .standard))
                case .relationship:
                    choices += 1
                    result = try engine.resolveRelationship(.init(seed: result.nextSeed, state: result.snapshot, response: .listen))
                case .awakening:
                    choices += 1
                    result = try engine.chooseAwakening(.init(seed: result.nextSeed, state: result.snapshot, awakening: XCTUnwrap(result.snapshot.awakeningOptions.first)))
                case .chapterReview:
                    choices += 1
                    result = try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
                default: XCTFail("Unexpected preparation phase"); return
                }
            }
            XCTAssertEqual(result.snapshot.phase, .importantGame)
            XCTAssertEqual(NextAppearanceCue.resolve(result.snapshot), .init(trainings: 0, choices: 0))
            XCTAssertEqual(initial, .init(trainings: trainings, choices: choices))
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
