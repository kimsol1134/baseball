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

    @MainActor
    func testPermanentGrowthAndCurrentFatigueAreLabeledSeparatelyInAllLanguages() {
        for language in [AppLanguage.korean, .english, .japanese] {
            let resolver = GameCopyResolver(language: language, policy: .strict)
            let cost = GrowthConditionCopy.line(fatigue: 11, change: 6, resolver: resolver)
            XCTAssertTrue(cost.contains("11") && cost.contains("+6"))
            let recovery = GrowthConditionCopy.line(fatigue: 5, change: -6, resolver: resolver)
            XCTAssertTrue(recovery.contains("5") && recovery.contains("-6"))
            XCTAssertNotEqual(cost, recovery)
        }
        let before = PitchReleaseWindow.width(command: 35) * DeliveryControl.sweepSeconds(velocityTenthsKPH: 1350, fatigue: 5)
        let after = PitchReleaseWindow.width(command: 36) * DeliveryControl.sweepSeconds(velocityTenthsKPH: 1350, fatigue: 11)
        XCTAssertGreaterThanOrEqual(after, before)
    }
}
