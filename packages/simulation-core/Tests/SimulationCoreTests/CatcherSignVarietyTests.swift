import XCTest
@testable import SimulationCore

final class CatcherSignVarietyTests: XCTestCase {
    func testCatcherSignRulesDefaultStaysOnFixtureSafeVersion() {
        XCTAssertEqual(CatcherSignRules().version, CatcherSignRules.fixtureSafeVersion)
        XCTAssertFalse(CatcherSignRules().usesVariety)
        XCTAssertTrue(CatcherSignRules(version: 2).usesVariety)
    }

    func testVersion2PrepareIsDeterministicForTheSameInputs() throws {
        let engine = liveEngine()
        let params = makePrepareParams(seed: "20260902")
        let first = try engine.preparePitch(params)
        let second = try engine.preparePitch(params)
        XCTAssertEqual(first.primaryRecommendation.call, second.primaryRecommendation.call)
        XCTAssertEqual(first.alternativeRecommendation.call, second.alternativeRecommendation.call)
        XCTAssertEqual(first.preparationToken, second.preparationToken)
        let submitted = try engine.submitPitch(makeSubmitParams(preparation: first, params: params))
        XCTAssertFalse(submitted.events.isEmpty)
    }

    func testPreparationTokenRejectsVersionMix() throws {
        let v2 = liveEngine()
        let v1 = PitchKernelEngine()
        let params = makePrepareParams(seed: "20260903")
        let prepared = try v2.preparePitch(params)
        XCTAssertThrowsError(
            try v1.submitPitch(makeSubmitParams(preparation: prepared, params: params))
        ) { error in
            XCTAssertEqual(error as? SimulationError, .invalidPreparationToken)
        }
        let v1Prepared = try v1.preparePitch(params)
        XCTAssertNotEqual(v1Prepared.preparationToken, prepared.preparationToken)
    }

    func testThirtyPitchSequenceV2UsesAtLeastFourZonesAndThreePitchesWhileV1StaysOnTwoZones() throws {
        let pitcher = try XCTUnwrap(PitcherPresetCatalog.all.first { $0.id == "precision_commander" }?.pitcher)
        let v1 = try throwSequence(engine: PitchKernelEngine(), pitcher: pitcher, pitches: 30)
        let v2 = try throwSequence(engine: liveEngine(), pitcher: pitcher, pitches: 30)
        XCTAssertLessThanOrEqual(v1.zones.count, 2, "v1 zones: \(v1.zones)")
        XCTAssertGreaterThanOrEqual(v2.zones.count, 4, "v2 zones: \(v2.zones)")
        XCTAssertGreaterThanOrEqual(v2.pitches.count, 3, "v2 pitches: \(v2.pitches)")
    }

    func testVersion2LockedOnRecommendationStillEmitsReadWarning() throws {
        let v2 = liveEngine()
        let v1 = PitchKernelEngine()
        let locked = lockedOnParams(seed: "20260904")
        let v2Prepared = try v2.preparePitch(locked)
        XCTAssertEqual(v2Prepared.rivalAdaptation.band, .lockedOn)
        XCTAssertNotNil(v2Prepared.rivalAdaptation.detectedPitch)
        let v2Codes = v2Prepared.primaryRecommendation.reasonCodes
        XCTAssertTrue(
            v2Codes.contains("rival.pattern_detected") || v2Codes.contains("rival.read_pressure"),
            "v2 locked-on codes: \(v2Codes)"
        )
        let submitted = try v2.submitPitch(makeSubmitParams(preparation: v2Prepared, params: locked))
        XCTAssertFalse(submitted.events.isEmpty)

        let v1Prepared = try v1.preparePitch(locked)
        XCTAssertEqual(v1Prepared.rivalAdaptation.band, .lockedOn)
    }

    func testDiverseScoutingDefaultMatchesOmittingTheFlag() {
        let pitcher = PitcherPresetCatalog.all[0].pitcher
        let seed: UInt64 = 4_204_204
        let omitted = AutoOutingSimulator().simulate(
            pitcher: pitcher,
            startingFatigue: 8,
            outsTarget: 18,
            pitchCap: 96,
            batterOffset: 2,
            baseSeed: seed
        )
        let explicitFalse = AutoOutingSimulator().simulate(
            pitcher: pitcher,
            startingFatigue: 8,
            outsTarget: 18,
            pitchCap: 96,
            batterOffset: 2,
            baseSeed: seed,
            diverseScouting: false
        )
        XCTAssertEqual(omitted, explicitFalse)
    }

    func testDiverseScoutingIsDeterministicAndCanChangeTheLine() {
        let pitcher = PitcherPresetCatalog.all[0].pitcher
        let seed: UInt64 = 7_777_013
        let first = AutoOutingSimulator().simulate(
            pitcher: pitcher,
            startingFatigue: 10,
            outsTarget: 18,
            pitchCap: 96,
            baseSeed: seed,
            diverseScouting: true
        )
        let second = AutoOutingSimulator().simulate(
            pitcher: pitcher,
            startingFatigue: 10,
            outsTarget: 18,
            pitchCap: 96,
            baseSeed: seed,
            diverseScouting: true
        )
        XCTAssertEqual(first, second)

        var differed = false
        for offset in UInt64(0)..<40 {
            let legacy = AutoOutingSimulator().simulate(
                pitcher: pitcher,
                startingFatigue: 10,
                outsTarget: 18,
                pitchCap: 96,
                baseSeed: seed &+ offset,
                diverseScouting: false
            )
            let diverse = AutoOutingSimulator().simulate(
                pitcher: pitcher,
                startingFatigue: 10,
                outsTarget: 18,
                pitchCap: 96,
                baseSeed: seed &+ offset,
                diverseScouting: true
            )
            if legacy != diverse {
                differed = true
                break
            }
        }
        XCTAssertTrue(differed, "diverse scouting never changed an outing line across 40 seeds")
    }

    private func liveEngine() -> PitchKernelEngine {
        PitchKernelEngine(
            recommendationEngine: CatcherRecommendationEngine(
                rules: CatcherSignRules(version: CatcherSignRules.livePlayVersion)
            )
        )
    }

    private func makePrepareParams(seed: String) -> PreparePitchParams {
        PreparePitchParams(
            seed: seed,
            pitcher: PitcherPresetCatalog.all.first { $0.id == "precision_commander" }!.pitcher,
            batter: BatterSnapshot(id: "batter-1", name: "이준호", contact: 56, discipline: 52, power: 58),
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
                balls: 1,
                strikes: 1,
                pitchNumber: 1,
                scoreDifferential: 0,
                leverage: 600,
                fatigue: 12
            )
        )
    }

    private func lockedOnParams(seed: String) -> PreparePitchParams {
        let base = makePrepareParams(seed: seed)
        let memoryEngine = RivalMemoryEngine()
        var memory: RivalMemorySnapshot? = memoryEngine.benchMemory(
            pitcher: base.pitcher,
            benchID: "catcher-variety-lock"
        )
        for index in 0..<24 {
            memory = memoryEngine.record(
                memory,
                pitcher: base.pitcher,
                batter: base.batter,
                context: base.context,
                call: PitchCall(
                    pitchType: .fourSeam,
                    zone: PitchZone(row: 1, column: 0),
                    zoneIntent: .strike,
                    intensity: .normal
                ),
                outcome: .calledStrike,
                plateAppearanceEnded: index % 5 == 4
            )
        }
        return PreparePitchParams(
            seed: base.seed,
            pitcher: base.pitcher,
            batter: base.batter,
            scouting: base.scouting,
            context: base.context,
            rivalMemory: memory,
            gameState: base.gameState,
            gameLog: base.gameLog
        )
    }

    private func makeSubmitParams(
        preparation: PitchPreparation,
        params: PreparePitchParams
    ) -> SubmitPitchParams {
        SubmitPitchParams(
            seed: params.seed,
            pitcher: params.pitcher,
            batter: params.batter,
            scouting: params.scouting,
            context: params.context,
            preparationToken: preparation.preparationToken,
            call: preparation.primaryRecommendation.call,
            rivalMemory: params.rivalMemory,
            gameState: params.gameState,
            gameLog: params.gameLog
        )
    }

    private struct SequenceStats {
        var zones = Set<PitchZone>()
        var pitches = Set<PitchType>()
    }

    private func throwSequence(
        engine: PitchKernelEngine,
        pitcher: PitcherSnapshot,
        pitches target: Int
    ) throws -> SequenceStats {
        let batter = BatterSnapshot(id: "batter-seq", name: "이준호", contact: 56, discipline: 52, power: 58)
        let scouting = BatterScoutingSnapshot(
            hotZone: PitchZone(row: 1, column: 1),
            coldZone: PitchZone(row: 2, column: 0),
            pitchStrength: .fourSeam,
            pitchWeakness: .slider,
            chaseTendency: 48
        )
        var stats = SequenceStats()
        var seed = "300001"
        var rivalMemory: RivalMemorySnapshot?
        var gameLog = GameLogSnapshot(gameID: "seq", revision: 0, totalPitches: 0, entries: [])
        var gameState = GameStateSnapshot(
            defense: DefenseSnapshot(infield: 50, outfield: 50, arm: 50),
            park: ParkSnapshot(id: "park", name: "구장", hitFactor: 1_000, homeRunFactor: 1_000),
            runners: .empty,
            runsAllowed: 0,
            inningState: InningStateSnapshot(inning: 1, half: .top, outs: 0)
        )
        var paIndex = 0
        var thrown = 0
        while thrown < target {
            paIndex += 1
            var context = PlateAppearanceContext(
                plateAppearanceID: "pa-\(paIndex)",
                revision: 0,
                inning: gameState.inningState?.inning ?? 1,
                outs: gameState.inningState?.outs ?? 0,
                balls: 0,
                strikes: 0,
                pitchNumber: 1,
                scoreDifferential: 0,
                leverage: 500,
                fatigue: 12
            )
            var preparation = try engine.preparePitch(
                PreparePitchParams(
                    seed: seed,
                    pitcher: pitcher,
                    batter: batter,
                    scouting: scouting,
                    context: context,
                    rivalMemory: rivalMemory,
                    gameState: gameState,
                    gameLog: gameLog
                )
            )
            while thrown < target {
                stats.zones.insert(preparation.primaryRecommendation.call.zone)
                stats.pitches.insert(preparation.primaryRecommendation.call.pitchType)
                let result = try engine.submitPitch(
                    SubmitPitchParams(
                        seed: seed,
                        pitcher: pitcher,
                        batter: batter,
                        scouting: scouting,
                        context: context,
                        preparationToken: preparation.preparationToken,
                        call: preparation.primaryRecommendation.call,
                        rivalMemory: rivalMemory,
                        gameState: gameState,
                        gameLog: gameLog
                    )
                )
                thrown += 1
                rivalMemory = result.rivalMemory
                gameLog = result.gameLog
                gameState = result.gameState
                seed = result.nextSeed
                if result.snapshot.ended { break }
                context = PlateAppearanceContext(
                    plateAppearanceID: context.plateAppearanceID,
                    revision: result.revision,
                    inning: result.gameState.inningState?.inning ?? context.inning,
                    outs: result.gameState.inningState?.outs ?? context.outs,
                    balls: result.snapshot.balls,
                    strikes: result.snapshot.strikes,
                    pitchNumber: context.pitchNumber + 1,
                    scoreDifferential: context.scoreDifferential,
                    leverage: context.leverage,
                    fatigue: result.snapshot.fatigueAfterPitch
                )
                guard let next = result.nextPreparation else { break }
                preparation = next
            }
            if UInt64(seed) == nil {
                seed = String(300000 + thrown + paIndex)
            }
        }
        return stats
    }
}
