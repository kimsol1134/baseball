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
                ),
                rivalMemory: result.rivalMemory
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
        for seed in 1...50_000 {
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

    func testRivalMemoryLearnsRepeatedPatternMoreThanMixedSequence() throws {
        let params = makePrepareParams(seed: "1", balls: 0, strikes: 0)
        let repeated = makeRivalMemory(params: params, repeated: true)
        let mixed = makeRivalMemory(params: params, repeated: false)
        let memoryEngine = RivalMemoryEngine()

        let repeatedAdaptation = memoryEngine.analyze(repeated, context: params.context)
        let mixedAdaptation = memoryEngine.analyze(mixed, context: params.context)

        XCTAssertEqual(repeated.recentObservations.count, RivalMemoryEngine.maximumObservations)
        XCTAssertEqual(repeatedAdaptation.detectedPitch, .slider)
        XCTAssertEqual(repeatedAdaptation.detectedZone, PitchZone(row: 2, column: 0))
        XCTAssertGreaterThan(repeatedAdaptation.level, mixedAdaptation.level)
        XCTAssertEqual(repeatedAdaptation.band, .lockedOn)
    }

    func testChangingMemoryAfterPreparationInvalidatesToken() throws {
        let base = makePrepareParams(seed: "701", balls: 0, strikes: 0)
        let firstMemory = makeRivalMemory(params: base, repeated: true, observations: 8)
        let preparedParams = makePrepareParams(
            seed: "701",
            balls: 0,
            strikes: 0,
            rivalMemory: firstMemory
        )
        let preparation = try engine.preparePitch(preparedParams)
        let changedMemory = RivalMemoryEngine().record(
            firstMemory,
            pitcher: preparedParams.pitcher,
            batter: preparedParams.batter,
            context: preparedParams.context,
            call: preparation.primaryRecommendation.call,
            outcome: .calledStrike,
            plateAppearanceEnded: false
        )

        XCTAssertThrowsError(
            try engine.submitPitch(
                SubmitPitchParams(
                    seed: preparedParams.seed,
                    pitcher: preparedParams.pitcher,
                    batter: preparedParams.batter,
                    scouting: preparedParams.scouting,
                    context: preparedParams.context,
                    preparationToken: preparation.preparationToken,
                    call: preparation.primaryRecommendation.call,
                    rivalMemory: changedMemory
                )
            )
        ) { error in
            XCTAssertEqual(error as? SimulationError, .invalidPreparationToken)
        }
    }

    func testRepeatingReadPatternAllowsMoreDamageThanMixedHistory() throws {
        let base = makePrepareParams(seed: "1", balls: 0, strikes: 0)
        let repeatedMemory = makeRivalMemory(params: base, repeated: true)
        let mixedMemory = makeRivalMemory(params: base, repeated: false)
        let call = PitchCall(
            pitchType: .slider,
            zone: PitchZone(row: 2, column: 0),
            zoneIntent: .edge,
            intensity: .normal
        )
        var repeatedDamage = 0
        var mixedDamage = 0

        for seed in 1...8_000 {
            let repeatedParams = makePrepareParams(
                seed: String(seed),
                balls: 0,
                strikes: 0,
                rivalMemory: repeatedMemory
            )
            let mixedParams = makePrepareParams(
                seed: String(seed),
                balls: 0,
                strikes: 0,
                rivalMemory: mixedMemory
            )
            let repeatedPreparation = try engine.preparePitch(repeatedParams)
            let mixedPreparation = try engine.preparePitch(mixedParams)
            let repeated = try engine.submitPitch(
                SubmitPitchParams(
                    seed: repeatedParams.seed,
                    pitcher: repeatedParams.pitcher,
                    batter: repeatedParams.batter,
                    scouting: repeatedParams.scouting,
                    context: repeatedParams.context,
                    preparationToken: repeatedPreparation.preparationToken,
                    call: call,
                    rivalMemory: repeatedMemory
                )
            )
            let mixed = try engine.submitPitch(
                SubmitPitchParams(
                    seed: mixedParams.seed,
                    pitcher: mixedParams.pitcher,
                    batter: mixedParams.batter,
                    scouting: mixedParams.scouting,
                    context: mixedParams.context,
                    preparationToken: mixedPreparation.preparationToken,
                    call: call,
                    rivalMemory: mixedMemory
                )
            )
            if repeated.snapshot.battedBall != nil { repeatedDamage += 1 }
            if mixed.snapshot.battedBall != nil { mixedDamage += 1 }
        }

        XCTAssertGreaterThan(repeatedDamage, mixedDamage)
    }

    func testStrongDefenseTurnsMoreBorderlineContactIntoOuts() {
        let resolver = BallInPlayEngine()
        let battedBall = BattedBall(
            exitVelocityTenthsKPH: 1_330,
            launchAngleTenthsDegrees: 140,
            directionTenthsDegrees: 120,
            contactQuality: 610
        )
        let strong = gameState(defense: 80, hitFactor: 1_000, homeRunFactor: 1_000)
        let weak = gameState(defense: 20, hitFactor: 1_000, homeRunFactor: 1_000)
        var strongOuts = 0
        var weakOuts = 0

        for seed in 1...2_000 {
            if resolver.resolve(battedBall, gameState: strong, seed: UInt64(seed), ordinal: 1).finalOutcome == .inPlayOut {
                strongOuts += 1
            }
            if resolver.resolve(battedBall, gameState: weak, seed: UInt64(seed), ordinal: 1).finalOutcome == .inPlayOut {
                weakOuts += 1
            }
        }

        XCTAssertGreaterThan(strongOuts, weakOuts)
    }

    func testTrajectoryDataReachesResolvedPitchAndLandingPoints() throws {
        let result = try submitPresetPitch(
            seed: 77,
            pitcher: try XCTUnwrap(PitcherPresetCatalog.all.first).pitcher,
            call: PitchCall(
                pitchType: .slider,
                zone: PitchZone(row: 2, column: 0),
                zoneIntent: .edge,
                intensity: .normal
            )
        )
        XCTAssertNotNil(result.snapshot.execution.flightTimeMilliseconds)
        XCTAssertNotNil(result.snapshot.execution.trajectoryControlX)
        XCTAssertNotNil(result.snapshot.execution.trajectoryControlY)
        let pitchSeries = try XCTUnwrap(result.snapshot.execution.trajectorySeries)
        let pitchSamples = stride(from: 0, to: pitchSeries.count, by: 4).map {
            Array(pitchSeries[$0..<min($0 + 4, pitchSeries.count)])
        }
        XCTAssertEqual(pitchSamples.count, 17)
        XCTAssertEqual(pitchSamples.first?[0], 0)
        XCTAssertEqual(pitchSamples.first?[2], 18_440)
        XCTAssertEqual(
            pitchSamples.last?[0],
            result.snapshot.execution.flightTimeMilliseconds
        )
        XCTAssertEqual(pitchSamples.last?[2], 0)
        XCTAssertTrue(zip(pitchSamples, pitchSamples.dropFirst()).allSatisfy {
            $0[0] < $1[0]
        })

        let fielding = BallInPlayEngine().resolve(
            BattedBall(
                exitVelocityTenthsKPH: 1_380,
                launchAngleTenthsDegrees: 240,
                directionTenthsDegrees: 180,
                contactQuality: 650
            ),
            gameState: gameState(defense: 55, hitFactor: 1_000, homeRunFactor: 1_000),
            seed: 77,
            ordinal: 1
        )
        XCTAssertGreaterThan(try XCTUnwrap(fielding.landingDistanceTenthsMeters), 0)
        XCTAssertGreaterThan(try XCTUnwrap(fielding.hangTimeMilliseconds), 0)
        XCTAssertGreaterThan(try XCTUnwrap(fielding.apexHeightTenthsMeters), 0)
        let ballSeries = try XCTUnwrap(fielding.ballFlightSeries)
        let ballSamples = stride(from: 0, to: ballSeries.count, by: 4).map {
            Array(ballSeries[$0..<min($0 + 4, ballSeries.count)])
        }
        XCTAssertEqual(ballSamples.count, 21)
        XCTAssertEqual(ballSamples.first?[3], 0)
        XCTAssertEqual(ballSamples.last?[3], 0)
        XCTAssertEqual(ballSamples.last?[0], fielding.hangTimeMilliseconds)
        let sampledApex = try XCTUnwrap(ballSamples.map { $0[3] }.max())
        let reportedApex = try XCTUnwrap(fielding.apexHeightTenthsMeters)
        XCTAssertLessThanOrEqual(
            abs(sampledApex - reportedApex * 100),
            50
        )
    }

    func testHitterFriendlyParkCreatesMoreHomeRunsFromFenceContact() {
        let resolver = BallInPlayEngine()
        let battedBall = BattedBall(
            exitVelocityTenthsKPH: 1_450,
            launchAngleTenthsDegrees: 270,
            directionTenthsDegrees: -80,
            contactQuality: 760
        )
        let hitterPark = gameState(defense: 50, hitFactor: 1_100, homeRunFactor: 1_300)
        let pitcherPark = gameState(defense: 50, hitFactor: 900, homeRunFactor: 700)
        var hitterParkHomeRuns = 0
        var pitcherParkHomeRuns = 0

        for seed in 1...1_000 {
            if resolver.resolve(battedBall, gameState: hitterPark, seed: UInt64(seed), ordinal: 1).finalOutcome == .homeRun {
                hitterParkHomeRuns += 1
            }
            if resolver.resolve(battedBall, gameState: pitcherPark, seed: UInt64(seed), ordinal: 1).finalOutcome == .homeRun {
                pitcherParkHomeRuns += 1
            }
        }

        XCTAssertGreaterThan(hitterParkHomeRuns, pitcherParkHomeRuns)
    }

    func testBaserunnerEngineForcesLoadedWalkAndClearsHomeRun() {
        let engine = BaserunnerEngine()
        let loaded = BaserunnerStateSnapshot(
            firstOccupied: true,
            secondOccupied: true,
            thirdOccupied: true,
            leadRunnerSpeed: 55
        )
        let walk = engine.advance(
            loaded,
            outcome: .ball,
            plateAppearanceResult: .walk,
            defense: DefenseSnapshot(infield: 50, outfield: 50, arm: 50),
            seed: 1
        )
        let homeRun = engine.advance(
            loaded,
            outcome: .homeRun,
            plateAppearanceResult: .hit,
            defense: DefenseSnapshot(infield: 50, outfield: 50, arm: 50),
            seed: 1
        )

        XCTAssertEqual(walk.runsScored, 1)
        XCTAssertEqual(walk.after.occupiedCount, 3)
        XCTAssertEqual(homeRun.runsScored, 4)
        XCTAssertEqual(homeRun.after, .empty)

        let firstAndSecond = BaserunnerStateSnapshot(
            firstOccupied: true,
            secondOccupied: true,
            thirdOccupied: false,
            leadRunnerSpeed: 40
        )
        for seed in 1...100 {
            let single = engine.advance(
                firstAndSecond,
                outcome: .single,
                plateAppearanceResult: .hit,
                defense: DefenseSnapshot(infield: 50, outfield: 50, arm: 70),
                seed: UInt64(seed)
            )
            XCTAssertEqual(single.after.occupiedCount + single.runsScored, 3)
        }
    }

    func testInfieldContactCannotBecomeExtraBaseHit() {
        let result = BallInPlayEngine().resolve(
            BattedBall(
                exitVelocityTenthsKPH: 1_550,
                launchAngleTenthsDegrees: 20,
                directionTenthsDegrees: 0,
                contactQuality: 900
            ),
            gameState: gameState(defense: 20, hitFactor: 1_300, homeRunFactor: 1_300),
            seed: 1,
            ordinal: 1
        )

        XCTAssertEqual(result.sector, .infield)
        XCTAssertTrue(result.finalOutcome == .single || result.finalOutcome == .inPlayOut)
    }

    func testFieldingResolutionNamesThePositionSpecificFielder() {
        let fielders = makeFielders(rating: 50).map {
            $0.position == .shortstop
                ? FielderSnapshot(
                    id: $0.id,
                    name: "박현우",
                    position: .shortstop,
                    range: 78,
                    glove: 76,
                    arm: 72
                )
                : $0
        }
        let state = gameState(
            defense: 40,
            hitFactor: 1_000,
            homeRunFactor: 1_000,
            fielders: fielders
        )
        let result = BallInPlayEngine().resolve(
            BattedBall(
                exitVelocityTenthsKPH: 1_280,
                launchAngleTenthsDegrees: 40,
                directionTenthsDegrees: -90,
                contactQuality: 520
            ),
            gameState: state,
            seed: 7,
            ordinal: 1
        )

        XCTAssertEqual(result.fielderPosition, .shortstop)
        XCTAssertEqual(result.fielderName, "박현우")
        XCTAssertEqual(result.defenseRating, 77)
    }

    func testFastRunnerStealsMoreOftenAgainstWeakCatcherArm() {
        let engine = BaserunnerEngine()
        let context = PlateAppearanceContext(
            plateAppearanceID: "steal-pa",
            revision: 0,
            inning: 7,
            outs: 0,
            balls: 0,
            strikes: 0,
            pitchNumber: 1,
            scoreDifferential: 0,
            leverage: 1_000,
            fatigue: 10
        )
        let fastRunner = BaserunnerStateSnapshot(
            firstOccupied: true,
            secondOccupied: false,
            thirdOccupied: false,
            leadRunnerSpeed: 80
        )
        let slowRunner = BaserunnerStateSnapshot(
            firstOccupied: true,
            secondOccupied: false,
            thirdOccupied: false,
            leadRunnerSpeed: 20
        )
        var fastSuccesses = 0
        var slowSuccesses = 0
        let weakCatcher = DefenseSnapshot(
            infield: 50,
            outfield: 50,
            arm: 50,
            fielders: makeFielders(rating: 20)
        )
        let strongCatcher = DefenseSnapshot(
            infield: 50,
            outfield: 50,
            arm: 50,
            fielders: makeFielders(rating: 80)
        )

        for seed in 1...4_000 {
            if engine.resolveSteal(
                fastRunner,
                defense: weakCatcher,
                context: context,
                seed: UInt64(seed)
            ).attempt?.succeeded == true {
                fastSuccesses += 1
            }
            if engine.resolveSteal(
                slowRunner,
                defense: strongCatcher,
                context: context,
                seed: UInt64(seed)
            ).attempt?.succeeded == true {
                slowSuccesses += 1
            }
        }

        XCTAssertGreaterThan(fastSuccesses, slowSuccesses)
        XCTAssertGreaterThan(fastSuccesses, 0)
    }

    func testStrongMiddleInfieldCompletesMoreDoublePlays() {
        let engine = InningStateEngine()
        let context = PlateAppearanceContext(
            plateAppearanceID: "double-play-pa",
            revision: 0,
            inning: 7,
            outs: 0,
            balls: 0,
            strikes: 0,
            pitchNumber: 1,
            scoreDifferential: 0,
            leverage: 700,
            fatigue: 10
        )
        let runners = BaserunnerStateSnapshot(
            firstOccupied: true,
            secondOccupied: false,
            thirdOccupied: false,
            leadRunnerSpeed: 50
        )
        let battedBall = BattedBall(
            exitVelocityTenthsKPH: 1_260,
            launchAngleTenthsDegrees: 20,
            directionTenthsDegrees: -80,
            contactQuality: 480
        )
        let strong = gameState(
            defense: 80,
            hitFactor: 1_000,
            homeRunFactor: 1_000,
            fielders: makeFielders(rating: 80),
            inningState: InningStateSnapshot(inning: 7, half: .bottom, outs: 0)
        )
        let weak = gameState(
            defense: 20,
            hitFactor: 1_000,
            homeRunFactor: 1_000,
            fielders: makeFielders(rating: 20),
            inningState: InningStateSnapshot(inning: 7, half: .bottom, outs: 0)
        )
        var strongDoublePlays = 0
        var weakDoublePlays = 0

        for seed in 1...2_000 {
            if engine.resolve(
                context: context,
                gameState: strong,
                plateAppearanceResult: .inPlayOut,
                battedBall: battedBall,
                fielding: nil,
                runners: runners,
                stealOuts: 0,
                seed: UInt64(seed)
            ).doublePlayCompleted {
                strongDoublePlays += 1
            }
            if engine.resolve(
                context: context,
                gameState: weak,
                plateAppearanceResult: .inPlayOut,
                battedBall: battedBall,
                fielding: nil,
                runners: runners,
                stealOuts: 0,
                seed: UInt64(seed)
            ).doublePlayCompleted {
                weakDoublePlays += 1
            }
        }

        XCTAssertGreaterThan(strongDoublePlays, weakDoublePlays)
    }

    func testThirdOutAdvancesBottomHalfToNextInningTop() {
        let context = PlateAppearanceContext(
            plateAppearanceID: "inning-pa",
            revision: 0,
            inning: 7,
            outs: 2,
            balls: 0,
            strikes: 2,
            pitchNumber: 3,
            scoreDifferential: 0,
            leverage: 800,
            fatigue: 20
        )
        let state = gameState(
            defense: 50,
            hitFactor: 1_000,
            homeRunFactor: 1_000,
            inningState: InningStateSnapshot(inning: 7, half: .bottom, outs: 2)
        )
        let transition = InningStateEngine().resolve(
            context: context,
            gameState: state,
            plateAppearanceResult: .strikeout,
            battedBall: nil,
            fielding: nil,
            runners: .empty,
            stealOuts: 0,
            seed: 1
        )

        XCTAssertTrue(transition.inningEnded)
        XCTAssertEqual(transition.outsRecorded, 1)
        XCTAssertEqual(transition.after, InningStateSnapshot(inning: 8, half: .top, outs: 0))
    }

    func testGameAnalysisSeparatesExpectedAndActualDamage() {
        let analysisEngine = GameAnalysisEngine()
        var log: GameLogSnapshot?
        let fielding = FieldingResolutionSnapshot(
            neutralOutcome: .double,
            finalOutcome: .inPlayOut,
            sector: .outfield,
            difficulty: 500,
            defenseRating: 70,
            defenseAdjustment: -80,
            parkAdjustment: 0,
            impact: .helpedPitcher,
            shortExplanation: "수비가 결과를 낮췄습니다."
        )
        for index in 0..<8 {
            log = analysisEngine.record(
                log,
                gameID: "analysis-game",
                pitchType: index < 5 ? .slider : .fourSeam,
                wasInZone: index.isMultiple(of: 2),
                batterSwung: true,
                outcome: index == 0 ? .inPlayOut : .swingingStrike,
                plateAppearanceResult: index == 0 ? .inPlayOut : nil,
                selectionQuality: .good,
                executionQuality: 700,
                battedBall: index == 0
                    ? BattedBall(
                        exitVelocityTenthsKPH: 1_420,
                        launchAngleTenthsDegrees: 180,
                        directionTenthsDegrees: 0,
                        contactQuality: 720
                    )
                    : nil,
                fielding: index == 0 ? fielding : nil,
                recommendationAccepted: true
            )
        }
        let analysis = analysisEngine.analyze(log!)

        XCTAssertEqual(analysis.sampleSize, 8)
        XCTAssertEqual(analysis.confidence, .developing)
        XCTAssertGreaterThan(analysis.expectedDamage, analysis.actualDamage)
        XCTAssertTrue(analysis.patternWarning.contains("슬라이더"), analysis.patternWarning)
    }

    func testChangingGameStateAfterPreparationInvalidatesToken() throws {
        let preparedState = gameState(defense: 60, hitFactor: 1_000, homeRunFactor: 1_000)
        let changedState = gameState(defense: 20, hitFactor: 1_300, homeRunFactor: 1_300)
        let params = makePrepareParams(seed: "818", gameState: preparedState)
        let preparation = try engine.preparePitch(params)

        XCTAssertThrowsError(
            try engine.submitPitch(
                SubmitPitchParams(
                    seed: params.seed,
                    pitcher: params.pitcher,
                    batter: params.batter,
                    scouting: params.scouting,
                    context: params.context,
                    preparationToken: preparation.preparationToken,
                    call: preparation.primaryRecommendation.call,
                    rivalMemory: params.rivalMemory,
                    gameState: changedState,
                    gameLog: params.gameLog
                )
            )
        ) { error in
            XCTAssertEqual(error as? SimulationError, .invalidPreparationToken)
        }
    }

    private func makeRivalMemory(
        params: PreparePitchParams,
        repeated: Bool,
        observations: Int = 30
    ) -> RivalMemorySnapshot {
        let memoryEngine = RivalMemoryEngine()
        var memory: RivalMemorySnapshot?
        for index in 0..<observations {
            let pitchType = repeated ? PitchType.slider : PitchType.allCases[index % PitchType.allCases.count]
            let zone = repeated
                ? PitchZone(row: 2, column: 0)
                : PitchZone(row: (index / 3) % 3, column: index % 3)
            memory = memoryEngine.record(
                memory,
                pitcher: params.pitcher,
                batter: params.batter,
                context: params.context,
                call: PitchCall(
                    pitchType: pitchType,
                    zone: zone,
                    zoneIntent: .edge,
                    intensity: .normal
                ),
                outcome: .calledStrike,
                plateAppearanceEnded: index % 5 == 4
            )
        }
        return memory!
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
        pitcher: PitcherSnapshot? = nil,
        rivalMemory: RivalMemorySnapshot? = nil,
        gameState: GameStateSnapshot? = nil,
        gameLog: GameLogSnapshot? = nil
    ) -> PreparePitchParams {
        PreparePitchParams(
            seed: seed,
            pitcher: pitcher ?? PitcherSnapshot(
                id: "pitcher-1",
                name: "테스트투수",
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
            ),
            rivalMemory: rivalMemory,
            gameState: gameState,
            gameLog: gameLog
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
            call: preparation.primaryRecommendation.call,
            rivalMemory: prepareParams.rivalMemory,
            gameState: prepareParams.gameState,
            gameLog: prepareParams.gameLog
        )
    }

    private func gameState(
        defense: Int,
        hitFactor: Int,
        homeRunFactor: Int,
        fielders: [FielderSnapshot]? = nil,
        inningState: InningStateSnapshot? = nil
    ) -> GameStateSnapshot {
        GameStateSnapshot(
            defense: DefenseSnapshot(
                infield: defense,
                outfield: defense,
                arm: defense,
                fielders: fielders
            ),
            park: ParkSnapshot(
                id: "test-park",
                name: "테스트 구장",
                hitFactor: hitFactor,
                homeRunFactor: homeRunFactor
            ),
            runners: .empty,
            runsAllowed: 0,
            inningState: inningState
        )
    }

    private func makeFielders(rating: Int) -> [FielderSnapshot] {
        FielderPosition.allCases.map {
            FielderSnapshot(
                id: "fielder-\($0.rawValue)",
                name: $0.rawValue,
                position: $0,
                range: rating,
                glove: rating,
                arm: rating
            )
        }
    }
}
