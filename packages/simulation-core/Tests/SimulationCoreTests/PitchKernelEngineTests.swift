import XCTest
@testable import SimulationCore

final class PitchKernelEngineTests: XCTestCase {
    /// 타구 방향의 부호는 야구와 같아야 한다 — 음수가 좌익이다.
    ///
    /// 코스 축을 넣으면서 부호를 뒤집어, 대다수인 우타를 상대로 몸쪽 공이 우익으로
    /// 굴러간 적이 있다. 수비 위치·병살·장타 코스가 통째로 반대로 돌았는데 이걸 잡는
    /// 테스트가 한 줄도 없었다.
    func testInsidePitchPullsToTheCorrectFieldForEachBatSide() {
        // 우타 몸쪽 → 좌익(음수), 우타 바깥쪽 → 우익(양수)
        XCTAssertLessThan(PitchKernelEngine.pullShift(batSide: .right, column: 0), 0)
        XCTAssertGreaterThan(PitchKernelEngine.pullShift(batSide: .right, column: 2), 0)
        // 좌타는 같은 칸에서 정확히 반대
        XCTAssertGreaterThan(PitchKernelEngine.pullShift(batSide: .left, column: 0), 0)
        XCTAssertLessThan(PitchKernelEngine.pullShift(batSide: .left, column: 2), 0)
        // 가운데는 어느 쪽으로도 밀지 않는다
        XCTAssertEqual(PitchKernelEngine.pullShift(batSide: .right, column: 1), 0)
        XCTAssertEqual(PitchKernelEngine.pullShift(batSide: .left, column: 1), 0)
    }

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

    func testLowReliabilityScoutingReadIsAHypothesisThatCanMissTheTruth() throws {
        // With almost no confidence the report is an estimate, not an answer sheet: the shown
        // weakness and cold zone are decoyed away from the truth and the chase read carries a
        // non-zero uncertainty band. (Below the minimum reveal threshold both facts always miss.)
        let params = makePrepareParams(seed: "5", reliability: 8)
        let report = try XCTUnwrap(try engine.preparePitch(params).scoutingReport)

        XCTAssertEqual(report.band, "low")
        XCTAssertLessThan(report.reliability, ScoutingEstimate.trustedReliability)
        XCTAssertNotEqual(report.estimatedWeakness, params.scouting.pitchWeakness)
        XCTAssertNotEqual(report.estimatedColdZone, params.scouting.coldZone)
        XCTAssertGreaterThan(report.chaseTendencyMargin, 0)
    }

    func testScoutingReadConvergesToTruthAsObservationsAccumulate() throws {
        // The same low-confidence baseline sharpens to the truth once the pitcher has seen enough
        // of this batter: the report becomes trusted, its uncertainty closes to zero, and the
        // catcher's primary pitch swings from the decoy weakness onto the real one.
        let seen = RivalMemorySnapshot(
            matchupID: "pitcher-1:batter-1",
            revision: 12,
            plateAppearancesSeen: 2,
            totalPitchesSeen: 14,
            recentObservations: [
                RivalPitchObservation(pitchType: .fourSeam, zone: PitchZone(row: 1, column: 1), zoneIntent: .edge, balls: 0, strikes: 0, outcome: .foul),
                RivalPitchObservation(pitchType: .slider, zone: PitchZone(row: 2, column: 0), zoneIntent: .edge, balls: 1, strikes: 0, outcome: .ball),
                RivalPitchObservation(pitchType: .changeup, zone: PitchZone(row: 0, column: 2), zoneIntent: .chase, balls: 1, strikes: 1, outcome: .swingingStrike)
            ]
        )
        let blind = makePrepareParams(seed: "5", reliability: 8)
        let studied = makePrepareParams(seed: "5", reliability: 8, rivalMemory: seen)

        let blindPreparation = try engine.preparePitch(blind)
        let studiedPreparation = try engine.preparePitch(studied)
        let blindReport = try XCTUnwrap(blindPreparation.scoutingReport)
        let studiedReport = try XCTUnwrap(studiedPreparation.scoutingReport)

        XCTAssertEqual(blindReport.band, "low")
        XCTAssertEqual(studiedReport.band, "trusted")
        XCTAssertGreaterThan(studiedReport.observationCount, blindReport.observationCount)
        XCTAssertEqual(studiedReport.estimatedWeakness, studied.scouting.pitchWeakness)
        XCTAssertEqual(studiedReport.estimatedColdZone, studied.scouting.coldZone)
        XCTAssertEqual(studiedReport.chaseTendencyMargin, 0)
        XCTAssertNotEqual(
            blindPreparation.primaryRecommendation.call.pitchType,
            studiedPreparation.primaryRecommendation.call.pitchType
        )
        XCTAssertEqual(
            studiedPreparation.primaryRecommendation.call.pitchType,
            studied.scouting.pitchWeakness
        )
        let expectedDirection = switch studiedPreparation.primaryRecommendation.call.zoneIntent {
        case .strike: "존 안으로"
        case .edge: "존 끝으로"
        case .chase: "존 밖 유인으로"
        }
        XCTAssertTrue(studiedPreparation.primaryRecommendation.shortReason.contains(expectedDirection))
        XCTAssertFalse(studiedPreparation.primaryRecommendation.shortReason.contains("존 끝로"))
    }

    func testScoutingReliabilityDoesNotChangeExecutionOrResolution() throws {
        // ADR-005 for the fog: reliability only changes what is recommended/shown. A fixed,
        // manually chosen pitch resolves byte-for-byte identically whether the read is a wild
        // guess or near-certain, because the physics, the batter plan and the selection grade all
        // consume the *true* scouting report regardless of confidence.
        let call = PitchCall(
            pitchType: .changeup,
            zone: PitchZone(row: 0, column: 2),
            zoneIntent: .edge,
            intensity: .normal
        )
        func resolve(reliability: Int) throws -> PlateAppearanceSnapshot {
            let params = makePrepareParams(seed: "777", reliability: reliability)
            let preparation = try engine.preparePitch(params)
            return try engine.submitPitch(
                SubmitPitchParams(
                    seed: params.seed,
                    pitcher: params.pitcher,
                    batter: params.batter,
                    scouting: params.scouting,
                    context: params.context,
                    preparationToken: preparation.preparationToken,
                    call: call,
                    rivalMemory: params.rivalMemory,
                    gameState: params.gameState,
                    gameLog: params.gameLog
                )
            ).snapshot
        }

        let guess = try resolve(reliability: 8)
        let studied = try resolve(reliability: 96)
        XCTAssertEqual(guess.execution, studied.execution)
        XCTAssertEqual(guess.outcome, studied.outcome)
        XCTAssertEqual(guess.battedBall, studied.battedBall)
        XCTAssertEqual(guess.selectionQuality, studied.selectionQuality)
        XCTAssertEqual(guess.fatigueAfterPitch, studied.fatigueAfterPitch)
    }

    func testLowReliabilityLowersRecommendationConfidence() throws {
        // A shaky read is stated as a hedge: identical everything else, the confidence a low
        // reliability carries is strictly lower than a trusted one's.
        let confident = try engine.preparePitch(makePrepareParams(seed: "9", reliability: 95))
        let shaky = try engine.preparePitch(makePrepareParams(seed: "9", reliability: 12))
        XCTAssertLessThan(
            shaky.primaryRecommendation.confidence,
            confident.primaryRecommendation.confidence
        )
    }

    func testLeverageChangesTheBatterPlanButNotExecutionOrResolution() throws {
        // ADR-005 (non-calibration), restated for situational awareness: leverage may change
        // what the batter *intends*, but never the physics or the resolution of a given plan.
        // A league-average-discipline hitter (50) with the bases loaded sits in a base/out
        // branch that does not vary with leverage, and whose leverage-amplification term is
        // exactly zero — so the committed plan is identical across a huge leverage swing, and
        // therefore the executed pitch and its resolved outcome must be identical too.
        let loaded = BaserunnerStateSnapshot(
            firstOccupied: true,
            secondOccupied: true,
            thirdOccupied: true,
            leadRunnerSpeed: 50
        )
        let state = gameState(defense: 50, hitFactor: 1_000, homeRunFactor: 1_000, runners: loaded)
        let lowParams = makePrepareParams(seed: "400", leverage: 0, discipline: 50, gameState: state)
        let highParams = makePrepareParams(seed: "400", leverage: 1_000, discipline: 50, gameState: state)
        let lowPreparation = try engine.preparePitch(lowParams)
        let highPreparation = try engine.preparePitch(highParams)

        // Same sealed plan in a blowout and in a nail-biter...
        XCTAssertEqual(lowPreparation.planCommitment, highPreparation.planCommitment)

        let low = try engine.submitPitch(
            makeSubmitParams(preparation: lowPreparation, prepareParams: lowParams)
        )
        let high = try engine.submitPitch(
            makeSubmitParams(preparation: highPreparation, prepareParams: highParams)
        )

        // ...so leverage moves neither the physical pitch nor its resolution.
        XCTAssertEqual(low.snapshot.execution, high.snapshot.execution)
        XCTAssertEqual(low.snapshot.outcome, high.snapshot.outcome)
        XCTAssertEqual(low.snapshot.battedBall, high.snapshot.battedBall)
    }

    func testBatterPlanRespondsToBaseStateDeterministicallyAcrossSeeds() throws {
        // The counterpart to the invariance above: with everything else fixed, the base/out
        // picture must change the batter's plan. Runners in scoring position with an out to give
        // commit a more aggressive, contact-first plan than empty bases in a low-stakes spot —
        // a deterministic property, so it holds for every seed, not merely on average.
        let scoringPosition = BaserunnerStateSnapshot(
            firstOccupied: false,
            secondOccupied: true,
            thirdOccupied: true,
            leadRunnerSpeed: 50
        )
        let rispState = gameState(
            defense: 50,
            hitFactor: 1_000,
            homeRunFactor: 1_000,
            runners: scoringPosition
        )
        let outOfZoneCall = PitchCall(
            pitchType: .fourSeam,
            zone: PitchZone(row: 0, column: 0),
            zoneIntent: .chase,
            intensity: .normal
        )
        var plansDiffer = 0
        var rispSwings = 0
        var emptySwings = 0

        for seed in 1...400 {
            let rispParams = makePrepareParams(
                seed: String(seed),
                leverage: 300,
                balls: 0,
                strikes: 0,
                gameState: rispState
            )
            let emptyParams = makePrepareParams(
                seed: String(seed),
                leverage: 300,
                balls: 0,
                strikes: 0
            )
            let rispPreparation = try engine.preparePitch(rispParams)
            let emptyPreparation = try engine.preparePitch(emptyParams)
            if rispPreparation.planCommitment != emptyPreparation.planCommitment {
                plansDiffer += 1
            }

            let risp = try engine.submitPitch(
                SubmitPitchParams(
                    seed: rispParams.seed,
                    pitcher: rispParams.pitcher,
                    batter: rispParams.batter,
                    scouting: rispParams.scouting,
                    context: rispParams.context,
                    preparationToken: rispPreparation.preparationToken,
                    call: outOfZoneCall,
                    rivalMemory: nil,
                    gameState: rispState
                )
            )
            let empty = try engine.submitPitch(
                SubmitPitchParams(
                    seed: emptyParams.seed,
                    pitcher: emptyParams.pitcher,
                    batter: emptyParams.batter,
                    scouting: emptyParams.scouting,
                    context: emptyParams.context,
                    preparationToken: emptyPreparation.preparationToken,
                    call: outOfZoneCall,
                    rivalMemory: nil,
                    gameState: nil
                )
            )
            if didSwing(risp.snapshot.outcome) { rispSwings += 1 }
            if didSwing(empty.snapshot.outcome) { emptySwings += 1 }
        }

        // The plan encodes the situation, so its commitment differs on every single seed...
        XCTAssertEqual(plansDiffer, 400)
        // ...and the scoring-position batter offers at the pitch materially more often.
        XCTAssertGreaterThan(rispSwings, emptySwings)
    }

    private func didSwing(_ outcome: PitchOutcome) -> Bool {
        outcome != .ball && outcome != .calledStrike
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
        XCTAssertTrue(repeatedAdaptation.warning.contains("슬라이더와"))
        XCTAssertFalse(repeatedAdaptation.warning.contains("슬라이더과"))
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

    func testRepeatedPatternReadStrengthIsBoundedByTheCap() throws {
        let params = makePrepareParams(seed: "1", balls: 0, strikes: 0)
        // Hammer the same call far past the observation window: the read must saturate,
        // not run away — this is the ceiling that turns the old cliff into a plateau.
        let hammered = makeRivalMemory(params: params, repeated: true, observations: 120)
        let adaptation = RivalMemoryEngine().analyze(hammered, context: params.context)

        XCTAssertLessThanOrEqual(adaptation.pitchReadStrength, RivalMemoryEngine.pitchReadCap)
        XCTAssertLessThanOrEqual(adaptation.zoneReadStrength, RivalMemoryEngine.zoneReadCap)
        // An unbroken pattern is the worst case, so it should reach — but never exceed — the cap.
        XCTAssertEqual(adaptation.pitchReadStrength, RivalMemoryEngine.pitchReadCap)
        XCTAssertEqual(adaptation.zoneReadStrength, RivalMemoryEngine.zoneReadCap)
    }

    func testMixedSequenceStillProducesASmallNonZeroRead() throws {
        let params = makePrepareParams(seed: "1", balls: 0, strikes: 0)
        let mixed = makeRivalMemory(params: params, repeated: false)
        let adaptation = RivalMemoryEngine().analyze(mixed, context: params.context)

        // A perfectly even mix used to be permanently invisible (the exemption that made
        // "just mix four pitches" a total counter). It now leaves a small familiarity read...
        XCTAssertGreaterThan(adaptation.pitchReadStrength, 0)
        XCTAssertGreaterThan(adaptation.zoneReadStrength, 0)
        // ...that stays well under the cap a locked pattern would earn.
        XCTAssertLessThan(adaptation.pitchReadStrength, RivalMemoryEngine.pitchReadCap)
        XCTAssertLessThan(adaptation.zoneReadStrength, RivalMemoryEngine.zoneReadCap)
    }

    func testRepeatedReadOutweighsMixedReadAcrossTheContinuousCurve() throws {
        let params = makePrepareParams(seed: "1", balls: 0, strikes: 0)
        let repeated = makeRivalMemory(params: params, repeated: true)
        let mixed = makeRivalMemory(params: params, repeated: false)
        let memoryEngine = RivalMemoryEngine()

        let repeatedAdaptation = memoryEngine.analyze(repeated, context: params.context)
        let mixedAdaptation = memoryEngine.analyze(mixed, context: params.context)

        // The "diverse call > repeated call" hierarchy must survive the switch from a
        // threshold to a continuous curve: repetition still earns a strictly stronger read.
        XCTAssertGreaterThan(repeatedAdaptation.pitchReadStrength, mixedAdaptation.pitchReadStrength)
        XCTAssertGreaterThan(repeatedAdaptation.zoneReadStrength, mixedAdaptation.zoneReadStrength)
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
        XCTAssertEqual(pitchSamples.count, 25)
        XCTAssertEqual(pitchSamples.first?[0], 0)
        XCTAssertEqual(pitchSamples.first?[2], 18_440)
        XCTAssertEqual(
            pitchSamples.last?[0],
            result.snapshot.execution.flightTimeMilliseconds
        )
        XCTAssertLessThanOrEqual(abs(pitchSamples.last?[2] ?? 100), 10)
        XCTAssertTrue(zip(pitchSamples, pitchSamples.dropFirst()).allSatisfy {
            $0[0] < $1[0]
        })
        let chordMidpoint = (try XCTUnwrap(pitchSamples.first?[1])
            + (try XCTUnwrap(pitchSamples.last?[1]))) / 2
        let lateralDeviation = pitchSamples[12][1] - chordMidpoint
        XCTAssertGreaterThan(abs(lateralDeviation), 20)
        XCTAssertLessThan(
            lateralDeviation * result.snapshot.execution.horizontalBreakTenthsCM,
            0,
            "slider movement must visibly separate from its release tangent"
        )

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
        XCTAssertEqual(ballSamples.count, 31)
        XCTAssertEqual(ballSamples.first?[3], 1_000)
        XCTAssertEqual(ballSamples.last?[3], 0)
        XCTAssertEqual(ballSamples.last?[0], fielding.hangTimeMilliseconds)
        let sampledApex = try XCTUnwrap(ballSamples.map { $0[3] }.max())
        let reportedApex = try XCTUnwrap(fielding.apexHeightTenthsMeters)
        XCTAssertLessThanOrEqual(
            abs(sampledApex - reportedApex * 100),
            50
        )
        let planarDistances = ballSamples.map { sample in
            hypot(Double(sample[1]), Double(sample[2]))
        }
        XCTAssertGreaterThan(
            planarDistances[1] - planarDistances[0],
            planarDistances[30] - planarDistances[29]
        )
        XCTAssertGreaterThan(sampledApex, try XCTUnwrap(ballSamples.first?[3]))
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

    // MARK: - Phase 3-4 rule primitives

    func testDeepFlyBallScoresRunnerFromThirdAsSacrificeFly() {
        let engine = BaserunnerEngine()
        let thirdOnly = BaserunnerStateSnapshot(
            firstOccupied: false,
            secondOccupied: false,
            thirdOccupied: true,
            leadRunnerSpeed: 55
        )
        let deepFly = BattedBall(
            exitVelocityTenthsKPH: 1_360,
            launchAngleTenthsDegrees: 300,
            directionTenthsDegrees: 60,
            contactQuality: 520
        )
        let advance = engine.advance(
            thirdOnly,
            outcome: .inPlayOut,
            plateAppearanceResult: .inPlayOut,
            defense: DefenseSnapshot(infield: 50, outfield: 50, arm: 50),
            seed: 1,
            battedBall: deepFly,
            fielding: makeFielding(sector: .outfield, distance: 950),
            inningEnded: false
        )

        // The runner tags from third on the catch and scores; the out itself is recorded elsewhere.
        XCTAssertEqual(advance.runsScored, 1)
        XCTAssertFalse(advance.after.thirdOccupied)

        // With two out, the catch is the third out and the run cannot count — no sacrifice fly.
        let inningEndingAdvance = engine.advance(
            thirdOnly,
            outcome: .inPlayOut,
            plateAppearanceResult: .inPlayOut,
            defense: DefenseSnapshot(infield: 50, outfield: 50, arm: 50),
            seed: 1,
            battedBall: deepFly,
            fielding: makeFielding(sector: .outfield, distance: 950),
            inningEnded: true
        )
        XCTAssertEqual(inningEndingAdvance.runsScored, 0)
        XCTAssertTrue(inningEndingAdvance.after.thirdOccupied)
    }

    func testShallowFlyBallStrandsTheRunnerOnThird() {
        let engine = BaserunnerEngine()
        let thirdOnly = BaserunnerStateSnapshot(
            firstOccupied: false,
            secondOccupied: false,
            thirdOccupied: true,
            leadRunnerSpeed: 55
        )
        let shallowFly = BattedBall(
            exitVelocityTenthsKPH: 1_180,
            launchAngleTenthsDegrees: 300,
            directionTenthsDegrees: 40,
            contactQuality: 430
        )
        let advance = engine.advance(
            thirdOnly,
            outcome: .inPlayOut,
            plateAppearanceResult: .inPlayOut,
            defense: DefenseSnapshot(infield: 50, outfield: 50, arm: 50),
            seed: 1,
            battedBall: shallowFly,
            fielding: makeFielding(sector: .outfield, distance: 520),
            inningEnded: false
        )

        // A can-of-corn too shallow to tag on: no run, the runner holds third.
        XCTAssertEqual(advance.runsScored, 0)
        XCTAssertTrue(advance.after.thirdOccupied)
    }

    func testTripleClearsTheBasesAndIsReachableFromAGapLineDrive() {
        let engine = BaserunnerEngine()
        let loaded = BaserunnerStateSnapshot(
            firstOccupied: true,
            secondOccupied: true,
            thirdOccupied: true,
            leadRunnerSpeed: 55
        )
        let advance = engine.advance(
            loaded,
            outcome: .triple,
            plateAppearanceResult: .hit,
            defense: DefenseSnapshot(infield: 50, outfield: 50, arm: 50),
            seed: 1
        )

        // Every runner scores and the batter pulls into third.
        XCTAssertEqual(advance.runsScored, 3)
        XCTAssertEqual(
            advance.after,
            BaserunnerStateSnapshot(
                firstOccupied: false,
                secondOccupied: false,
                thirdOccupied: true,
                leadRunnerSpeed: 50
            )
        )

        // A gap/corner line drive of extra-base quality can be stretched into a triple.
        let gapLineDrive = BattedBall(
            exitVelocityTenthsKPH: 1_520,
            launchAngleTenthsDegrees: 210,
            directionTenthsDegrees: 400,
            contactQuality: 700
        )
        var sawTriple = false
        for seed in 1...6_000 {
            if BallInPlayEngine().resolve(
                gapLineDrive,
                gameState: gameState(defense: 50, hitFactor: 1_000, homeRunFactor: 1_000),
                seed: UInt64(seed),
                ordinal: 1
            ).finalOutcome == .triple {
                sawTriple = true
                break
            }
        }
        XCTAssertTrue(sawTriple)
    }

    func testHitByPitchAdvancesRunnersExactlyLikeAWalk() {
        let engine = BaserunnerEngine()
        let defense = DefenseSnapshot(infield: 50, outfield: 50, arm: 50)
        let states = [
            BaserunnerStateSnapshot.empty,
            BaserunnerStateSnapshot(firstOccupied: true, secondOccupied: false, thirdOccupied: false, leadRunnerSpeed: 50),
            BaserunnerStateSnapshot(firstOccupied: true, secondOccupied: true, thirdOccupied: false, leadRunnerSpeed: 50),
            BaserunnerStateSnapshot(firstOccupied: true, secondOccupied: true, thirdOccupied: true, leadRunnerSpeed: 50),
            BaserunnerStateSnapshot(firstOccupied: false, secondOccupied: true, thirdOccupied: true, leadRunnerSpeed: 50)
        ]
        for runners in states {
            // Both share the coarse `.walk` result, so the free base and any forced run must match.
            let walk = engine.advance(runners, outcome: .ball, plateAppearanceResult: .walk, defense: defense, seed: 7)
            let hitByPitch = engine.advance(runners, outcome: .hitByPitch, plateAppearanceResult: .walk, defense: defense, seed: 7)
            XCTAssertEqual(walk.after, hitByPitch.after)
            XCTAssertEqual(walk.runsScored, hitByPitch.runsScored)
        }
    }

    func testHitByPitchOutcomeEndsThePlateAppearanceAsAWalk() throws {
        // Chasing the batter inside off the plate: over enough seeds a wild inside pitch plunks the
        // hitter, and when it does the plate appearance ends in the walk bucket (a free base).
        let insideChase = PitchCall(
            pitchType: .fourSeam,
            zone: PitchZone(row: 1, column: 0),
            zoneIntent: .chase,
            intensity: .maxEffort
        )
        var found = false
        for seed in 1...20_000 where !found {
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
                    call: insideChase
                )
            )
            if result.snapshot.outcome == .hitByPitch {
                found = true
                XCTAssertEqual(result.snapshot.result, .walk)
                XCTAssertTrue(result.snapshot.ended)
                XCTAssertNil(result.snapshot.battedBall)
            }
        }
        XCTAssertTrue(found, "a hit-by-pitch should be reachable on inside pitches")
    }

    func testSameHandMatchupProducesMoreWhiffsThanOppositeHand() throws {
        // Platoon: a same-hand hitter (RHB vs RHP) whiffs on the breaking ball more than the
        // opposite-hand hitter (LHB vs RHP), whose contact edge is the mirror of the pitcher's
        // same-hand advantage. Same seeds and slider on both, so the gap is the handedness alone.
        let slider = PitchCall(
            pitchType: .slider,
            zone: PitchZone(row: 2, column: 0),
            zoneIntent: .edge,
            intensity: .normal
        )
        func whiffs(batSide: BatSide) throws -> Int {
            var count = 0
            for seed in 1...6_000 {
                let base = makePrepareParams(seed: String(seed))
                let batter = BatterSnapshot(
                    id: base.batter.id,
                    name: base.batter.name,
                    contact: base.batter.contact,
                    discipline: base.batter.discipline,
                    power: base.batter.power,
                    batSide: batSide
                )
                let preparation = try engine.preparePitch(base)
                let result = try engine.submitPitch(
                    SubmitPitchParams(
                        seed: base.seed,
                        pitcher: base.pitcher,
                        batter: batter,
                        scouting: base.scouting,
                        context: base.context,
                        preparationToken: preparation.preparationToken,
                        call: slider
                    )
                )
                if result.snapshot.outcome == .swingingStrike { count += 1 }
            }
            return count
        }

        let sameHand = try whiffs(batSide: .right)
        let oppositeHand = try whiffs(batSide: .left)
        XCTAssertGreaterThan(sameHand, oppositeHand)
    }

    func testLegacySnapshotsWithoutHandednessDecodeToRightHandedDefaults() throws {
        // Saves and RPC payloads written before platoon carry no batSide/throwingHand; they must
        // load as right-handed so old games resolve unchanged, while a fresh encode round-trips.
        let batterJSON = Data(#"{"id":"b","name":"타자","contact":50,"discipline":50,"power":50}"#.utf8)
        let batter = try JSONDecoder().decode(BatterSnapshot.self, from: batterJSON)
        XCTAssertEqual(batter.batSide, .right)

        let pitcherJSON = Data(#"{"id":"p","name":"투수","stuff":50,"command":50,"movement":50,"stamina":50}"#.utf8)
        let pitcher = try JSONDecoder().decode(PitcherSnapshot.self, from: pitcherJSON)
        XCTAssertEqual(pitcher.throwingHand, .right)
        XCTAssertNil(pitcher.pitchProfiles)

        let encodedLefty = try JSONEncoder().encode(
            BatterSnapshot(id: "b", name: "타자", contact: 50, discipline: 50, power: 50, batSide: .left)
        )
        let roundTripped = try JSONDecoder().decode(BatterSnapshot.self, from: encodedLefty)
        XCTAssertEqual(roundTripped.batSide, .left)

        let encodedLeftyPitcher = try JSONEncoder().encode(
            PitcherSnapshot(id: "p", name: "투수", stuff: 50, command: 50, movement: 50, stamina: 50, throwingHand: .left)
        )
        XCTAssertEqual(
            try JSONDecoder().decode(PitcherSnapshot.self, from: encodedLeftyPitcher).throwingHand,
            .left
        )
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

    func testHighSchoolPresetRatingsAndFastballsLeaveRoomToDevelop() throws {
        let presets = PitcherPresetCatalog.all
        let fastballs = try presets.map { preset in
            try XCTUnwrap(preset.pitcher.profile(for: .fourSeam))
        }

        XCTAssertTrue(presets.allSatisfy { preset in
            [preset.pitcher.stuff, preset.pitcher.command, preset.pitcher.movement, preset.pitcher.stamina]
                .allSatisfy { (20...44).contains($0) }
        })
        XCTAssertTrue(fastballs.allSatisfy { (1_340...1_410).contains($0.velocityTenthsKPH) })

        let power = try XCTUnwrap(presets.first { $0.id == "power_prospect" })
        let powerFastball = try XCTUnwrap(power.pitcher.profile(for: .fourSeam))
        XCTAssertEqual(powerFastball.velocityTenthsKPH, fastballs.map(\.velocityTenthsKPH).max())
        let maximumCreationVelocityGain = 5 * 5
        let fullEffortVelocityBonus = 32
        let maximumDailyVariation = 10
        XCTAssertLessThan(
            powerFastball.velocityTenthsKPH + maximumCreationVelocityGain
                + fullEffortVelocityBonus + maximumDailyVariation,
            1_500
        )
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
        discipline: Int = 52,
        reliability: Int = ScoutingEstimate.trustedReliability,
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
                discipline: discipline,
                power: 58
            ),
            scouting: BatterScoutingSnapshot(
                hotZone: PitchZone(row: 1, column: 1),
                coldZone: PitchZone(row: 2, column: 0),
                pitchStrength: .fourSeam,
                pitchWeakness: .slider,
                chaseTendency: 48,
                reliability: reliability
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
        inningState: InningStateSnapshot? = nil,
        runners: BaserunnerStateSnapshot = .empty
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
            runners: runners,
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

    private func makeFielding(sector: FieldingSector, distance: Int) -> FieldingResolutionSnapshot {
        FieldingResolutionSnapshot(
            neutralOutcome: .inPlayOut,
            finalOutcome: .inPlayOut,
            sector: sector,
            difficulty: 500,
            defenseRating: 50,
            defenseAdjustment: 0,
            parkAdjustment: 0,
            impact: .neutral,
            landingDistanceTenthsMeters: distance,
            shortExplanation: "테스트 수비 결과"
        )
    }
}
