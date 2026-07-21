import XCTest
@testable import SimulationCore

final class PitchKernelEngineTests: XCTestCase {
    private let engine = PitchKernelEngine()

    func testBatterPlanIsCommittedBeforePlayerCall() throws {
        let params = makePrepareParams(seed: "20260721")
        let preparation = try engine.preparePitch(params)
        let result = try engine.submitPitch(
            makeSubmitParams(preparation: preparation, prepareParams: params)
        )

        XCTAssertEqual(
            result.events.map(\.eventType).prefix(5),
            [
                "batter_plan_committed",
                "catcher_recommendations_generated",
                "pitch_call_committed",
                "pitch_executed",
                "pitch_resolved"
            ]
        )
        XCTAssertEqual(result.events.first?.planCommitment, preparation.planCommitment)
    }

    func testCatcherRecommendationCannotReadHiddenPlan() throws {
        let first = try engine.preparePitch(makePrepareParams(seed: "1"))
        let second = try engine.preparePitch(makePrepareParams(seed: "2"))

        XCTAssertNotEqual(first.planCommitment, second.planCommitment)
        XCTAssertEqual(first.primaryRecommendation, second.primaryRecommendation)
        XCTAssertEqual(first.alternativeRecommendation, second.alternativeRecommendation)
    }

    func testLeverageDoesNotChangePitchResolution() throws {
        let lowLeverageParams = makePrepareParams(seed: "400", leverage: 0)
        let highLeverageParams = makePrepareParams(seed: "400", leverage: 1_000)
        let lowPreparation = try engine.preparePitch(lowLeverageParams)
        let highPreparation = try engine.preparePitch(highLeverageParams)

        let low = try engine.submitPitch(
            makeSubmitParams(preparation: lowPreparation, prepareParams: lowLeverageParams)
        )
        let high = try engine.submitPitch(
            makeSubmitParams(preparation: highPreparation, prepareParams: highLeverageParams)
        )

        XCTAssertEqual(low.snapshot.outcome, high.snapshot.outcome)
        XCTAssertEqual(low.snapshot.execution, high.snapshot.execution)
        XCTAssertEqual(low.snapshot.battedBall, high.snapshot.battedBall)
    }

    func testSameSeedContextAndCallProduceSameEventStream() throws {
        let params = makePrepareParams(seed: "88")
        let preparation = try engine.preparePitch(params)
        let command = makeSubmitParams(preparation: preparation, prepareParams: params)

        let first = try engine.submitPitch(command)
        let second = try engine.submitPitch(command)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.eventHash, second.eventHash)
    }

    func testRejectsCallWithStalePreparationToken() throws {
        let params = makePrepareParams(seed: "12")
        let preparation = try engine.preparePitch(params)
        let command = SubmitPitchParams(
            seed: params.seed,
            pitcher: params.pitcher,
            batter: params.batter,
            scouting: params.scouting,
            context: params.context,
            preparationToken: "stale-token",
            call: preparation.primaryRecommendation.call
        )

        XCTAssertThrowsError(try engine.submitPitch(command)) { error in
            XCTAssertEqual(error as? SimulationError, .invalidPreparationToken)
        }
    }

    func testPlateAppearanceEventuallyEndsAndCountNeverExceedsRules() throws {
        var params = makePrepareParams(seed: "9001", balls: 0, strikes: 0)
        var preparation = try engine.preparePitch(params)
        var finalResult: PlateAppearanceResult?

        for _ in 0..<30 {
            let result = try engine.submitPitch(
                makeSubmitParams(preparation: preparation, prepareParams: params)
            )
            XCTAssertTrue((0...3).contains(result.snapshot.balls))
            XCTAssertTrue((0...2).contains(result.snapshot.strikes))
            if result.snapshot.ended {
                finalResult = result.snapshot.result
                break
            }
            let next = try XCTUnwrap(result.nextPreparation)
            params = PreparePitchParams(
                seed: result.nextSeed,
                pitcher: params.pitcher,
                batter: params.batter,
                scouting: params.scouting,
                context: PlateAppearanceContext(
                    plateAppearanceID: params.context.plateAppearanceID,
                    revision: result.snapshot.revision,
                    inning: params.context.inning,
                    outs: params.context.outs,
                    balls: result.snapshot.balls,
                    strikes: result.snapshot.strikes,
                    pitchNumber: params.context.pitchNumber + 1,
                    scoreDifferential: params.context.scoreDifferential,
                    leverage: params.context.leverage,
                    fatigue: min(100, params.context.fatigue + 1)
                )
            )
            preparation = next
        }

        XCTAssertNotNil(finalResult)
    }

    func testFullCountRecommendationDoesNotCallAChasePitch() throws {
        let params = makePrepareParams(seed: "17", balls: 3, strikes: 2)

        let preparation = try engine.preparePitch(params)

        XCTAssertEqual(preparation.primaryRecommendation.call.zoneIntent, .strike)
    }

    func testControlledStrikeIntentCanStillMissTheABSZone() throws {
        var misses = 0
        for seed in 1...1_000 {
            let params = makePrepareParams(seed: String(seed), balls: 3, strikes: 0)
            let preparation = try engine.preparePitch(params)
            let command = SubmitPitchParams(
                seed: params.seed,
                pitcher: params.pitcher,
                batter: params.batter,
                scouting: params.scouting,
                context: params.context,
                preparationToken: preparation.preparationToken,
                call: PitchCall(
                    pitchType: .fourSeam,
                    zone: PitchZone(row: 1, column: 1),
                    zoneIntent: .strike,
                    intensity: .controlled
                )
            )
            let result = try engine.submitPitch(command)
            let execution = result.snapshot.execution
            if abs(execution.actualX) > 500 || abs(execution.actualY) > 500 {
                misses += 1
            }
        }

        XCTAssertGreaterThan(misses, 0)
    }

    func testEveryBattedBallOutcomeIsReachableAcrossFixedSeeds() throws {
        var outcomes = Set<PitchOutcome>()
        for seed in 1...20_000 {
            let params = makePrepareParams(seed: String(seed), balls: 0, strikes: 0)
            let preparation = try engine.preparePitch(params)
            let result = try engine.submitPitch(
                SubmitPitchParams(
                    seed: params.seed,
                    pitcher: params.pitcher,
                    batter: params.batter,
                    scouting: params.scouting,
                    context: params.context,
                    preparationToken: preparation.preparationToken,
                    call: PitchCall(
                        pitchType: .fourSeam,
                        zone: PitchZone(row: 1, column: 1),
                        zoneIntent: .strike,
                        intensity: .normal
                    )
                )
            )
            if result.snapshot.battedBall != nil {
                outcomes.insert(result.snapshot.outcome)
            }
        }

        XCTAssertTrue(outcomes.contains(.inPlayOut))
        XCTAssertTrue(outcomes.contains(.single))
        XCTAssertTrue(outcomes.contains(.double))
        XCTAssertTrue(outcomes.contains(.homeRun))
    }

    func testPitcherPresetCatalogHasFourDistinctCompleteBuilds() throws {
        let presets = PitcherPresetCatalog.all

        XCTAssertEqual(presets.count, 4)
        XCTAssertEqual(Set(presets.map(\.id)).count, 4)
        for preset in presets {
            let profiles = try XCTUnwrap(preset.pitcher.pitchProfiles)
            XCTAssertEqual(Set(profiles.map { $0.pitchType.rawValue }), Set(PitchType.allCases.map(\.rawValue)))
            XCTAssertEqual(profiles.filter { $0.role == .development }.count, 1)
        }
    }

    func testPresetProfilesChangeVelocityCommandAndFatigueInExpectedDirections() throws {
        let power = try XCTUnwrap(PitcherPresetCatalog.all.first { $0.id == "power_prospect" })
        let commander = try XCTUnwrap(PitcherPresetCatalog.all.first { $0.id == "precision_commander" })
        let inningsEater = try XCTUnwrap(PitcherPresetCatalog.all.first { $0.id == "innings_eater" })
        let call = PitchCall(
            pitchType: .fourSeam,
            zone: PitchZone(row: 0, column: 2),
            zoneIntent: .edge,
            intensity: .normal
        )
        var powerMiss = 0
        var commanderMiss = 0
        var powerVelocity = 0
        var commanderVelocity = 0

        for seed in 1...2_000 {
            let powerResult = try submitPresetPitch(
                seed: seed,
                pitcher: power.pitcher,
                call: call
            )
            let commanderResult = try submitPresetPitch(
                seed: seed,
                pitcher: commander.pitcher,
                call: call
            )
            powerMiss += targetMiss(powerResult.snapshot.execution)
            commanderMiss += targetMiss(commanderResult.snapshot.execution)
            powerVelocity += powerResult.snapshot.execution.velocityTenthsKPH
            commanderVelocity += commanderResult.snapshot.execution.velocityTenthsKPH
        }

        XCTAssertGreaterThan(powerVelocity, commanderVelocity)
        XCTAssertLessThan(commanderMiss, powerMiss)

        let powerFatigue = try submitPresetPitch(seed: 99, pitcher: power.pitcher, call: call)
        let staminaFatigue = try submitPresetPitch(seed: 99, pitcher: inningsEater.pitcher, call: call)
        XCTAssertGreaterThan(
            powerFatigue.snapshot.fatigueAfterPitch,
            staminaFatigue.snapshot.fatigueAfterPitch
        )
    }

    func testBreakingBallArtistSliderCreatesMoreWhiffsThanInningsEater() throws {
        let artist = try XCTUnwrap(PitcherPresetCatalog.all.first { $0.id == "breaking_ball_artist" })
        let inningsEater = try XCTUnwrap(PitcherPresetCatalog.all.first { $0.id == "innings_eater" })
        let call = PitchCall(
            pitchType: .slider,
            zone: PitchZone(row: 2, column: 0),
            zoneIntent: .edge,
            intensity: .normal
        )
        var artistWhiffs = 0
        var inningsEaterWhiffs = 0

        for seed in 1...5_000 {
            if try submitPresetPitch(seed: seed, pitcher: artist.pitcher, call: call).snapshot.outcome == .swingingStrike {
                artistWhiffs += 1
            }
            if try submitPresetPitch(seed: seed, pitcher: inningsEater.pitcher, call: call).snapshot.outcome == .swingingStrike {
                inningsEaterWhiffs += 1
            }
        }

        XCTAssertGreaterThan(artistWhiffs, inningsEaterWhiffs)
    }

    private func submitPresetPitch(
        seed: Int,
        pitcher: PitcherSnapshot,
        call: PitchCall
    ) throws -> PitchKernelResult {
        let params = makePrepareParams(seed: String(seed), pitcher: pitcher)
        let preparation = try engine.preparePitch(params)
        return try engine.submitPitch(
            SubmitPitchParams(
                seed: params.seed,
                pitcher: params.pitcher,
                batter: params.batter,
                scouting: params.scouting,
                context: params.context,
                preparationToken: preparation.preparationToken,
                call: call
            )
        )
    }

    private func targetMiss(_ execution: PitchExecution) -> Int {
        abs(execution.actualX - execution.targetX) + abs(execution.actualY - execution.targetY)
    }

    private func makePrepareParams(
        seed: String,
        leverage: Int = 600,
        balls: Int = 1,
        strikes: Int = 1,
        pitcher: PitcherSnapshot? = nil
    ) -> PreparePitchParams {
        PreparePitchParams(
            seed: seed,
            pitcher: pitcher ?? PitcherSnapshot(
                id: "pitcher-1",
                name: "김도윤",
                stuff: 62,
                command: 54,
                movement: 58,
                stamina: 60
            ),
            batter: BatterSnapshot(
                id: "batter-1",
                name: "이준호",
                contact: 56,
                discipline: 52,
                power: 58
            ),
            scouting: BatterScoutingSnapshot(
                hotZone: PitchZone(row: 1, column: 1),
                coldZone: PitchZone(row: 2, column: 0),
                pitchStrength: .fourSeam,
                pitchWeakness: .slider,
                chaseTendency: 48
            ),
            context: PlateAppearanceContext(
                plateAppearanceID: "pa-1",
                revision: 0,
                inning: 7,
                outs: 0,
                balls: balls,
                strikes: strikes,
                pitchNumber: 1,
                scoreDifferential: 0,
                leverage: leverage,
                fatigue: 12
            )
        )
    }

    private func makeSubmitParams(
        preparation: PitchPreparation,
        prepareParams: PreparePitchParams
    ) -> SubmitPitchParams {
        SubmitPitchParams(
            seed: prepareParams.seed,
            pitcher: prepareParams.pitcher,
            batter: prepareParams.batter,
            scouting: prepareParams.scouting,
            context: prepareParams.context,
            preparationToken: preparation.preparationToken,
            call: preparation.primaryRecommendation.call
        )
    }
}
