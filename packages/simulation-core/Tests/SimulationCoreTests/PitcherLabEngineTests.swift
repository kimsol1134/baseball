import Foundation
import XCTest
@testable import SimulationCore

final class PitcherLabEngineTests: XCTestCase {
    func testSameSeedAndTrainingChoiceProduceSameState() throws {
        let engine = PitcherLabEngine()
        let firstStart = try engine.start(
            StartPitcherLabParams(seed: "42", presetID: "power_prospect")
        )
        let secondStart = try engine.start(
            StartPitcherLabParams(seed: "42", presetID: "power_prospect")
        )

        XCTAssertEqual(firstStart, secondStart)

        let firstTraining = try engine.commitTraining(
            CommitTrainingParams(
                seed: firstStart.nextSeed,
                state: firstStart.snapshot,
                focus: .velocity,
                intensity: .standard
            )
        )
        let secondTraining = try engine.commitTraining(
            CommitTrainingParams(
                seed: secondStart.nextSeed,
                state: secondStart.snapshot,
                focus: .velocity,
                intensity: .standard
            )
        )

        XCTAssertEqual(firstTraining, secondTraining)
        XCTAssertEqual(firstTraining.snapshot.trainingSessionsCompleted, 1)
        XCTAssertEqual(firstTraining.snapshot.phase, .training)
        XCTAssertFalse(firstTraining.snapshot.stateCommitment.isEmpty)
    }

    func testPitcherLabCompletesSixTrainingsThreeInningsAndLegacy() throws {
        let engine = PitcherLabEngine()
        var result = try engine.start(
            StartPitcherLabParams(seed: "20260722", presetID: "breaking_ball_artist")
        )

        result = try train(engine, result, .breakingBall, .intensive)
        result = try train(engine, result, .command, .standard)
        XCTAssertEqual(result.snapshot.phase, .importantInning)

        result = try inning(engine, result, number: 1, runs: 0)
        result = try train(engine, result, .recovery, .light)
        XCTAssertEqual(result.snapshot.phase, .relationship)

        result = try engine.chooseRelationship(
            ChooseRelationshipParams(
                seed: result.nextSeed,
                state: result.snapshot,
                choice: .trustCatcher
            )
        )
        XCTAssertGreaterThan(result.snapshot.catcherTrust, 50)

        result = try train(engine, result, .command, .standard)
        result = try inning(engine, result, number: 2, runs: 1)
        result = try train(engine, result, .breakingBall, .intensive)
        XCTAssertEqual(result.snapshot.phase, .awakening)
        XCTAssertEqual(result.snapshot.awakeningOptions.count, 2)

        result = try engine.chooseAwakening(
            ChooseAwakeningParams(
                seed: result.nextSeed,
                state: result.snapshot,
                awakening: try XCTUnwrap(result.snapshot.awakeningOptions.first)
            )
        )
        XCTAssertEqual(result.snapshot.phase, .relationship)

        result = try engine.chooseRelationship(
            ChooseRelationshipParams(
                seed: result.nextSeed,
                state: result.snapshot,
                choice: .assertOwnPlan
            )
        )
        result = try train(engine, result, .stamina, .standard)
        result = try engine.chooseAwakening(
            ChooseAwakeningParams(
                seed: result.nextSeed,
                state: result.snapshot,
                awakening: try XCTUnwrap(result.snapshot.awakeningOptions.first)
            )
        )
        XCTAssertEqual(result.snapshot.selectedAwakenings.count, 2)
        XCTAssertEqual(result.snapshot.phase, .importantInning)

        result = try inning(engine, result, number: 3, runs: 1)
        XCTAssertEqual(result.snapshot.phase, .scouting)
        XCTAssertEqual(result.snapshot.performance.importantInningsCompleted, 3)

        result = try engine.finalizeScouting(
            FinalizeScoutingParams(seed: result.nextSeed, state: result.snapshot)
        )
        XCTAssertEqual(result.snapshot.phase, .reflection)
        XCTAssertNotNil(result.snapshot.scoutingEvaluation)
        XCTAssertEqual(result.snapshot.legacyOptions.count, 2)

        result = try engine.selectLegacy(
            SelectLegacyParams(
                seed: result.nextSeed,
                state: result.snapshot,
                soulDomain: .technique,
                memoryCard: try XCTUnwrap(result.snapshot.legacyOptions.first)
            )
        )

        XCTAssertEqual(result.snapshot.phase, .completed)
        XCTAssertEqual(result.snapshot.trainingSessionsCompleted, 6)
        XCTAssertEqual(result.snapshot.relationshipEventsCompleted, 2)
        XCTAssertEqual(result.snapshot.legacySelection?.soulPointsGranted, 2)
        XCTAssertEqual(result.events.last?.eventType, "life_completed")
    }

    func testChangedPublicStateFailsCommitmentValidation() throws {
        let engine = PitcherLabEngine()
        let start = try engine.start(
            StartPitcherLabParams(seed: "77", presetID: "precision_commander")
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(start.snapshot)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object["readiness"] = 99
        let altered = try JSONDecoder().decode(
            PitcherLabSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertThrowsError(
            try engine.commitTraining(
                CommitTrainingParams(
                    seed: start.nextSeed,
                    state: altered,
                    focus: .command,
                    intensity: .standard
                )
            )
        ) { error in
            guard case SimulationError.invalidPitcherLab = error else {
                return XCTFail("Expected invalid Pitcher Lab state, got \(error)")
            }
        }
    }

    func testInheritedMemoryChangesSecondLifeStartingBuild() throws {
        let engine = PitcherLabEngine()
        let firstLife = try engine.start(
            StartPitcherLabParams(seed: "88", presetID: "power_prospect")
        )
        let secondLife = try engine.start(
            StartPitcherLabParams(
                seed: "89",
                presetID: "power_prospect",
                lifeNumber: 2,
                inheritedSoulPoints: 2,
                inheritedSoulDomain: .body,
                inheritedMemory: .velocityBlueprint
            )
        )

        XCTAssertEqual(secondLife.snapshot.lifeNumber, 2)
        XCTAssertGreaterThan(secondLife.snapshot.pitcher.stuff, firstLife.snapshot.pitcher.stuff)
        XCTAssertGreaterThan(
            try XCTUnwrap(secondLife.snapshot.pitcher.profile(for: .fourSeam)?.velocityTenthsKPH),
            try XCTUnwrap(firstLife.snapshot.pitcher.profile(for: .fourSeam)?.velocityTenthsKPH)
        )
    }

    func testCreationAllocationMustSpendExactlyFivePoints() {
        let engine = PitcherLabEngine()

        XCTAssertThrowsError(
            try engine.start(
                StartPitcherLabParams(
                    seed: "90",
                    presetID: "power_prospect",
                    creationAllocation: CreationAllocationSnapshot(
                        stuff: 2,
                        command: 1,
                        movement: 1,
                        stamina: 0
                    )
                )
            )
        ) { error in
            guard case SimulationError.invalidPitcherLab = error else {
                return XCTFail("Expected invalid creation allocation, got \(error)")
            }
        }
    }

    private func train(
        _ engine: PitcherLabEngine,
        _ result: PitcherLabResult,
        _ focus: TrainingFocus,
        _ intensity: TrainingIntensity
    ) throws -> PitcherLabResult {
        try engine.commitTraining(
            CommitTrainingParams(
                seed: result.nextSeed,
                state: result.snapshot,
                focus: focus,
                intensity: intensity
            )
        )
    }

    private func inning(
        _ engine: PitcherLabEngine,
        _ result: PitcherLabResult,
        number: Int,
        runs: Int
    ) throws -> PitcherLabResult {
        try engine.recordImportantInning(
            RecordImportantInningParams(
                seed: result.nextSeed,
                state: result.snapshot,
                report: ImportantInningReport(
                    scenarioNumber: number,
                    pitches: 18 + number,
                    strikeouts: 2,
                    walks: number == 2 ? 1 : 0,
                    runsAllowed: runs,
                    expectedDamage: 420 + number * 30,
                    actualDamage: runs * 650,
                    recommendationAccepted: 10
                )
            )
        )
    }
}
