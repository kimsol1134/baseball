import XCTest
@testable import SimulationCore

final class PitchLearningRulesTests: XCTestCase {
    private var preset: PitcherSnapshot { PitcherPresetCatalog.all[0].pitcher }

    func testLegacyProfilesRemainGameReady() throws {
        let profiles = try XCTUnwrap(preset.pitchProfiles)
        XCTAssertTrue(profiles.allSatisfy(\.isGameReady))
        XCTAssertEqual(Set(preset.gameReadyPitchTypes), Set(PitchType.allCases))
    }

    func testStartingRepertoireCreatesThreeReadyAndOneLockedPitch() throws {
        let selection = StartingRepertoireSelection(
            readyBreakingPitches: [.slider, .changeup],
            primaryPitch: .fourSeam,
            learningPitch: .curveball
        )
        let result = try PitchLearningRules.apply(selection: selection, to: preset)
        XCTAssertEqual(Set(result.pitcher.gameReadyPitchTypes), [.fourSeam, .slider, .changeup])
        XCTAssertEqual(result.pitcher.profile(for: .curveball)?.availability, .locked)
        XCTAssertEqual(result.pitcher.profile(for: .curveball)?.role, .development)
        XCTAssertEqual(result.project.stage, .grip)
    }

    func testInvalidDuplicateStartingPitchesAreRejected() {
        let selection = StartingRepertoireSelection(
            readyBreakingPitches: [.slider, .slider],
            primaryPitch: .fourSeam,
            learningPitch: .curveball
        )
        XCTAssertThrowsError(try PitchLearningRules.apply(selection: selection, to: preset))
    }

    func testVersionedTrainingRejectsMissingFastballAndUnknownTargets() throws {
        let selection = StartingRepertoireSelection(
            readyBreakingPitches: [.slider, .changeup],
            primaryPitch: .fourSeam,
            learningPitch: .curveball
        )
        let started = try PitchLearningRules.apply(selection: selection, to: preset)
        XCTAssertThrowsError(try PitchLearningRules.validateTrainingTarget(
            nil,
            pitcher: started.pitcher,
            rulesVersion: 1,
            project: started.project
        ))
        XCTAssertThrowsError(try PitchLearningRules.validateTrainingTarget(
            .fourSeam,
            pitcher: started.pitcher,
            rulesVersion: 1,
            project: started.project
        ))
        XCTAssertNoThrow(try PitchLearningRules.validateTrainingTarget(
            .curveball,
            pitcher: started.pitcher,
            rulesVersion: 1,
            project: started.project
        ))
        XCTAssertNoThrow(try PitchLearningRules.validateTrainingTarget(
            nil,
            pitcher: preset,
            rulesVersion: nil,
            project: nil
        ))
    }

    func testPracticeMilestonesUnlockAndCompleteWithoutOutcomeRNG() throws {
        let selection = StartingRepertoireSelection(
            readyBreakingPitches: [.slider, .changeup],
            primaryPitch: .slider,
            learningPitch: .curveball
        )
        let started = try PitchLearningRules.apply(selection: selection, to: preset)
        let unlocked = try PitchLearningRules.advancing(
            pitcher: started.pitcher,
            project: started.project,
            practiceCredits: 5,
            chapter: 2
        )
        XCTAssertTrue(unlocked.receipt.justUnlockedForGames)
        XCTAssertEqual(unlocked.project.stage, .liveTrial)
        XCTAssertTrue(try XCTUnwrap(unlocked.pitcher.profile(for: .curveball)).isGameReady)

        let completed = try PitchLearningRules.advancing(
            pitcher: unlocked.pitcher,
            project: unlocked.project,
            practiceCredits: 2,
            qualityUses: 2,
            chapter: 3
        )
        XCTAssertTrue(completed.receipt.justCompleted)
        XCTAssertEqual(completed.project.stage, .completed)
        XCTAssertEqual(completed.pitcher.profile(for: .curveball)?.role, .secondary)
    }

    func testTrainingOnlyRouteCompletesAtNineCredits() throws {
        let selection = StartingRepertoireSelection(
            readyBreakingPitches: [.slider, .curveball],
            primaryPitch: .curveball,
            learningPitch: .changeup
        )
        let started = try PitchLearningRules.apply(selection: selection, to: preset)
        let completed = try PitchLearningRules.advancing(
            pitcher: started.pitcher,
            project: started.project,
            practiceCredits: 9
        )
        XCTAssertEqual(completed.project.stage, .completed)
        XCTAssertEqual(completed.pitcher.profile(for: .changeup)?.role, .secondary)
    }

    func testTemporaryThreePitchCompensationIsRemovedAtGameReadyUnlock() throws {
        let selection = StartingRepertoireSelection(
            readyBreakingPitches: [.curveball, .changeup],
            primaryPitch: .fourSeam,
            learningPitch: .slider
        )
        let started = try PitchLearningRules.apply(selection: selection, to: preset)
        XCTAssertGreaterThan(
            try XCTUnwrap(started.pitcher.profile(for: .curveball)?.command),
            try XCTUnwrap(preset.profile(for: .curveball)?.command)
        )
        let unlocked = try PitchLearningRules.advancing(
            pitcher: started.pitcher,
            project: started.project,
            practiceCredits: 5
        )
        for pitch in [PitchType.curveball, .changeup] {
            XCTAssertEqual(
                unlocked.pitcher.profile(for: pitch)?.command,
                preset.profile(for: pitch)?.command
            )
            XCTAssertEqual(
                unlocked.pitcher.profile(for: pitch)?.whiff,
                preset.profile(for: pitch)?.whiff
            )
            XCTAssertEqual(
                unlocked.pitcher.profile(for: pitch)?.weakContact,
                preset.profile(for: pitch)?.weakContact
            )
        }
    }

    func testPracticeCreditIsDeterministicByIntensity() {
        XCTAssertEqual(PitchLearningRules.practiceCredit(for: .light), 1)
        XCTAssertEqual(PitchLearningRules.practiceCredit(for: .standard), 2)
        XCTAssertEqual(PitchLearningRules.practiceCredit(for: .intensive), 3)
    }

    func testHighSchoolCareerPersistsSelectionAndTrainingReceipt() throws {
        let engine = HighSchoolCareerEngine()
        let selection = StartingRepertoireSelection(
            readyBreakingPitches: [.slider, .changeup],
            primaryPitch: .fourSeam,
            learningPitch: .curveball
        )
        var result = try engine.start(.init(
            seed: "4101",
            presetID: "power_prospect",
            signatureLegacyID: nil,
            inheritanceRulesVersion: nil,
            startingRepertoire: selection
        ))
        XCTAssertEqual(result.snapshot.repertoireRulesVersion, 1)
        XCTAssertEqual(result.snapshot.pitchLearningProject?.pitchType, .curveball)
        XCTAssertEqual(Set(result.snapshot.pitcher.gameReadyPitchTypes), [.fourSeam, .slider, .changeup])

        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        let school = try XCTUnwrap(result.snapshot.schoolOptions.first)
        result = try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: school.id))
        result = try engine.commitTraining(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            focus: .breakingBall,
            intensity: .standard,
            targetPitch: .curveball
        ))
        XCTAssertEqual(result.snapshot.pitchLearningProject?.practiceCredits, 2)
        XCTAssertEqual(result.snapshot.pitchLearningProject?.stage, .bullpen)
        XCTAssertEqual(result.snapshot.lastTraining?.pitchLearning?.practiceCreditsAfter, 2)
        XCTAssertEqual(result.snapshot.pitcher.profile(for: .curveball)?.availability, .locked)
    }

    func testVersionedPitchProfileTamperingFailsCareerCommitment() throws {
        let engine = HighSchoolCareerEngine()
        let started = try engine.start(.init(
            seed: "5151",
            presetID: "power_prospect",
            signatureLegacyID: nil,
            inheritanceRulesVersion: nil,
            startingRepertoire: PitchLearningRules.recommendedSelection(presetID: "power_prospect")
        ))
        let data = try JSONEncoder().encode(started)
        var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var snapshot = try XCTUnwrap(object["snapshot"] as? [String: Any])
        var pitcher = try XCTUnwrap(snapshot["pitcher"] as? [String: Any])
        var profiles = try XCTUnwrap(pitcher["pitchProfiles"] as? [[String: Any]])
        profiles[0]["command"] = (profiles[0]["command"] as? Int ?? 20) + 1
        pitcher["pitchProfiles"] = profiles
        snapshot["pitcher"] = pitcher
        object["snapshot"] = snapshot
        let tamperedData = try JSONSerialization.data(withJSONObject: object)
        let tampered = try JSONDecoder().decode(HighSchoolCareerResult.self, from: tamperedData)
        XCTAssertThrowsError(try engine.completePrologue(.init(
            seed: tampered.nextSeed,
            state: tampered.snapshot
        )))
    }

    func testDirectProCareerCanStartAndAdvanceTheSameLearningProject() throws {
        let engine = ProCareerEngine(journeyEnabled: false)
        let team = ProCareerEngine.proTeams[0]
        let draft = DraftResultSnapshot(
            outcome: .drafted,
            evaluationScore: 70,
            projectedRange: "2라운드",
            team: team,
            round: 2,
            overallPick: 16,
            signingBonus: 100_000_000,
            firstSeasonGoal: "2군 선발",
            summary: "지명"
        )
        let selection = StartingRepertoireSelection(
            readyBreakingPitches: [.slider, .curveball],
            primaryPitch: .slider,
            learningPitch: .changeup
        )
        var result = try engine.start(.init(
            seed: "9911",
            identity: .defaultPitcher,
            pitcher: preset,
            draftResult: draft,
            entitlement: .init(status: .active, source: .development, verifiedAt: "2026-08-23"),
            sourceFanInterest: nil,
            startingRepertoire: selection,
            repertoireRulesVersion: nil,
            pitchLearningProject: nil
        ))
        XCTAssertEqual(result.snapshot.pitchLearningProject?.pitchType, .changeup)
        XCTAssertEqual(Set(result.snapshot.pitcher.gameReadyPitchTypes), [.fourSeam, .slider, .curveball])

        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.planWeek(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            plan: .developMovement,
            targetPitch: .changeup
        ))
        XCTAssertEqual(result.snapshot.pitchLearningProject?.practiceCredits, 2)
        XCTAssertEqual(result.snapshot.pitchLearningProject?.stage, .bullpen)
    }

    func testStartingLearningPitchChoicesStayInsideEarlyRunPreventionGuardrail() throws {
        var totals: [PitchType: Int] = [:]
        for learningPitch in [PitchType.slider, .curveball, .changeup] {
            let ready = [PitchType.slider, .curveball, .changeup].filter { $0 != learningPitch }
            let repertoire = try PitchLearningRules.apply(
                selection: .init(
                    readyBreakingPitches: ready,
                    primaryPitch: .fourSeam,
                    learningPitch: learningPitch
                ),
                to: preset
            )
            totals[learningPitch] = (1...40).reduce(0) { total, seed in
                total + AutoOutingSimulator().simulate(
                    pitcher: repertoire.pitcher,
                    startingFatigue: 15,
                    outsTarget: 18,
                    pitchCap: 96,
                    baseSeed: UInt64(seed) * 8_123
                ).runsAllowed
            }
        }
        let values = totals.values
        let low = try XCTUnwrap(values.min())
        let high = try XCTUnwrap(values.max())
        XCTAssertLessThanOrEqual(
            high - low,
            max(4, low / 5),
            "starting repertoire run spread is too large: \(totals)"
        )
    }
}
