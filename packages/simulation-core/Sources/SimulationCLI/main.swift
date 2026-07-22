import Foundation
import SimulationCore

struct BatchReport: Codable {
    let plateAppearances: Int
    let pitches: Int
    let averagePitchesPerPlateAppearance: Double
    let plateAppearanceResults: [String: Int]
    let pitchOutcomes: [String: Int]
    let strategy: String
    let pitcherPreset: String
    let rivalMemoryMode: String
    let finalRivalAdaptationLevel: Int
    let defenseRating: Int
    let parkFactor: Int
    let runsAllowed: Int
    let expectedDamage: Int
    let actualDamage: Int
    let analysisConfidence: String
    let stealAttempts: Int
    let stolenBases: Int
    let doublePlays: Int
    let halfInningsCompleted: Int
}

enum BatchStrategy: String {
    case primary
    case alternative
    case fixed
}

enum RivalMemoryMode: String {
    case reset
    case persistent
}

let arguments = Array(CommandLine.arguments.dropFirst())
let iterations: Int = {
    guard let index = arguments.firstIndex(of: "--iterations") else { return 10_000 }
    let valueIndex = arguments.index(after: index)
    guard arguments.indices.contains(valueIndex), let value = Int(arguments[valueIndex]) else {
        return 10_000
    }
    return max(1, value)
}()
let strategy: BatchStrategy = {
    guard let index = arguments.firstIndex(of: "--strategy") else { return .primary }
    let valueIndex = arguments.index(after: index)
    guard arguments.indices.contains(valueIndex) else { return .primary }
    return BatchStrategy(rawValue: arguments[valueIndex]) ?? .primary
}()
let presetID: String = {
    guard let index = arguments.firstIndex(of: "--preset") else { return "power_prospect" }
    let valueIndex = arguments.index(after: index)
    guard arguments.indices.contains(valueIndex) else { return "power_prospect" }
    return arguments[valueIndex]
}()
let rivalMemoryMode: RivalMemoryMode = {
    guard let index = arguments.firstIndex(of: "--memory") else { return .reset }
    let valueIndex = arguments.index(after: index)
    guard arguments.indices.contains(valueIndex) else { return .reset }
    return RivalMemoryMode(rawValue: arguments[valueIndex]) ?? .reset
}()
let defenseRating: Int = {
    guard let index = arguments.firstIndex(of: "--defense") else { return 50 }
    let valueIndex = arguments.index(after: index)
    guard arguments.indices.contains(valueIndex), let value = Int(arguments[valueIndex]) else {
        return 50
    }
    return min(max(value, 20), 80)
}()
let parkFactor: Int = {
    guard let index = arguments.firstIndex(of: "--park") else { return 1_000 }
    let valueIndex = arguments.index(after: index)
    guard arguments.indices.contains(valueIndex), let value = Int(arguments[valueIndex]) else {
        return 1_000
    }
    return min(max(value, 700), 1_300)
}()

guard let preset = PitcherPresetCatalog.all.first(where: { $0.id == presetID }) else {
    let available = PitcherPresetCatalog.all.map(\.id).joined(separator: ", ")
    FileHandle.standardError.write(Data("Unknown preset '\(presetID)'. Available: \(available)\n".utf8))
    exit(2)
}
let pitcher = preset.pitcher
let batter = BatterSnapshot(
    id: "batter-1",
    name: "이준호",
    contact: 56,
    discipline: 52,
    power: 58
)
let scouting = BatterScoutingSnapshot(
    hotZone: PitchZone(row: 1, column: 1),
    coldZone: PitchZone(row: 2, column: 0),
    pitchStrength: .fourSeam,
    pitchWeakness: .slider,
    chaseTendency: 48
)
let fixedPitch = pitcher.pitchProfiles?.first(where: { $0.role == .primary })?.pitchType ?? .slider
let fixedCall = PitchCall(
    pitchType: fixedPitch,
    zone: PitchZone(row: 2, column: 0),
    zoneIntent: .edge,
    intensity: .normal
)
let batchFielders = FielderPosition.allCases.map {
    FielderSnapshot(
        id: "batch-\($0.rawValue)",
        name: $0.rawValue,
        position: $0,
        range: defenseRating,
        glove: defenseRating,
        arm: defenseRating
    )
}
let engine = PitchKernelEngine()
var plateAppearanceResults: [String: Int] = [:]
var pitchOutcomes: [String: Int] = [:]
var totalPitches = 0
var persistentMemory: RivalMemorySnapshot?
var persistentGameLog: GameLogSnapshot?
var finalAdaptationLevel = 0
var totalRunsAllowed = 0
var persistentRunsAllowed = 0
var finalAnalysis: PostgameAnalysisSnapshot?
var persistentInningState = InningStateSnapshot(inning: 7, half: .bottom, outs: 0)
var persistentRunners = BaserunnerStateSnapshot(
    firstOccupied: true,
    secondOccupied: false,
    thirdOccupied: false,
    leadRunnerSpeed: 55
)
var stealAttempts = 0
var stolenBases = 0
var doublePlays = 0
var halfInningsCompleted = 0

for index in 1...iterations {
    var plateMemory = rivalMemoryMode == .persistent ? persistentMemory : nil
    var gameState = GameStateSnapshot(
        defense: DefenseSnapshot(
            infield: defenseRating,
            outfield: defenseRating,
            arm: defenseRating,
            fielders: batchFielders
        ),
        park: ParkSnapshot(
            id: "batch-park",
            name: "배치 테스트 구장",
            hitFactor: parkFactor,
            homeRunFactor: parkFactor
        ),
        runners: persistentRunners,
        runsAllowed: persistentRunsAllowed,
        inningState: persistentInningState
    )
    var gameLog = persistentGameLog ?? GameLogSnapshot(
        gameID: "batch-game",
        revision: 0,
        totalPitches: 0,
        entries: []
    )
    var seed = String(index)
    var context = PlateAppearanceContext(
        plateAppearanceID: "batch-pa-\(index)",
        revision: 0,
        inning: persistentInningState.inning,
        outs: persistentInningState.outs,
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
            rivalMemory: plateMemory,
            gameState: gameState,
            gameLog: gameLog
        )
    )

    while true {
        let call: PitchCall
        switch strategy {
        case .primary:
            call = preparation.primaryRecommendation.call
        case .alternative:
            call = preparation.alternativeRecommendation.call
        case .fixed:
            call = fixedCall
        }
        let result = try engine.submitPitch(
            SubmitPitchParams(
                seed: seed,
                pitcher: pitcher,
                batter: batter,
                scouting: scouting,
                context: context,
                preparationToken: preparation.preparationToken,
                call: call,
                rivalMemory: plateMemory,
                gameState: gameState,
                gameLog: gameLog
            )
        )
        plateMemory = result.rivalMemory
        gameState = result.gameState
        gameLog = result.gameLog
        finalAnalysis = result.postgameAnalysis
        if let stealAttempt = result.snapshot.stealAttempt {
            stealAttempts += 1
            if stealAttempt.succeeded { stolenBases += 1 }
        }
        if result.snapshot.inningTransition?.doublePlayCompleted == true {
            doublePlays += 1
        }
        if result.snapshot.inningTransition?.inningEnded == true {
            halfInningsCompleted += 1
        }
        finalAdaptationLevel = result.rivalAdaptation.level
        totalPitches += 1
        pitchOutcomes[result.snapshot.outcome.rawValue, default: 0] += 1
        if let finalResult = result.snapshot.result {
            plateAppearanceResults[finalResult.rawValue, default: 0] += 1
        } else if result.snapshot.ended {
            plateAppearanceResults["inning_ended", default: 0] += 1
        }
        if result.snapshot.ended {
            totalRunsAllowed += result.snapshot.runsScored
            persistentRunsAllowed = result.gameState.runsAllowed
            persistentGameLog = result.gameLog
            persistentInningState = result.gameState.inningState ?? persistentInningState
            persistentRunners = result.gameState.runners
            if persistentInningState.inning > 9 {
                persistentInningState = InningStateSnapshot(inning: 7, half: .bottom, outs: 0)
                persistentRunners = BaserunnerStateSnapshot(
                    firstOccupied: true,
                    secondOccupied: false,
                    thirdOccupied: false,
                    leadRunnerSpeed: 55
                )
                persistentRunsAllowed = 0
            }
            if rivalMemoryMode == .persistent {
                persistentMemory = result.rivalMemory
            }
            break
        }

        seed = result.nextSeed
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
        guard let nextPreparation = result.nextPreparation else {
            fatalError("Active plate appearance did not provide the next preparation")
        }
        preparation = nextPreparation
    }
}

let report = BatchReport(
    plateAppearances: iterations,
    pitches: totalPitches,
    averagePitchesPerPlateAppearance: Double(totalPitches) / Double(iterations),
    plateAppearanceResults: plateAppearanceResults,
    pitchOutcomes: pitchOutcomes,
    strategy: strategy.rawValue,
    pitcherPreset: preset.id,
    rivalMemoryMode: rivalMemoryMode.rawValue,
    finalRivalAdaptationLevel: finalAdaptationLevel,
    defenseRating: defenseRating,
    parkFactor: parkFactor,
    runsAllowed: totalRunsAllowed,
    expectedDamage: finalAnalysis?.expectedDamage ?? 0,
    actualDamage: finalAnalysis?.actualDamage ?? 0,
    analysisConfidence: finalAnalysis?.confidence.rawValue ?? AnalysisConfidenceBand.low.rawValue,
    stealAttempts: stealAttempts,
    stolenBases: stolenBases,
    doublePlays: doublePlays,
    halfInningsCompleted: halfInningsCompleted
)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let data = try encoder.encode(report)
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data("\n".utf8))
