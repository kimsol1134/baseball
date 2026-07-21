import Foundation
import SimulationCore

struct BatchReport: Codable {
    let plateAppearances: Int
    let pitches: Int
    let averagePitchesPerPlateAppearance: Double
    let plateAppearanceResults: [String: Int]
    let pitchOutcomes: [String: Int]
    let strategy: String
}

enum BatchStrategy: String {
    case primary
    case alternative
    case fixed
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

let pitcher = PitcherSnapshot(
    id: "pitcher-1",
    name: "김도윤",
    stuff: 62,
    command: 54,
    movement: 58,
    stamina: 60
)
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
let fixedCall = PitchCall(
    pitchType: .slider,
    zone: PitchZone(row: 2, column: 0),
    zoneIntent: .edge,
    intensity: .normal
)
let engine = PitchKernelEngine()
var plateAppearanceResults: [String: Int] = [:]
var pitchOutcomes: [String: Int] = [:]
var totalPitches = 0

for index in 1...iterations {
    var seed = String(index)
    var context = PlateAppearanceContext(
        plateAppearanceID: "batch-pa-\(index)",
        revision: 0,
        inning: 7,
        outs: 0,
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
            context: context
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
                call: call
            )
        )
        totalPitches += 1
        pitchOutcomes[result.snapshot.outcome.rawValue, default: 0] += 1
        if let finalResult = result.snapshot.result {
            plateAppearanceResults[finalResult.rawValue, default: 0] += 1
            break
        }

        seed = result.nextSeed
        context = PlateAppearanceContext(
            plateAppearanceID: context.plateAppearanceID,
            revision: result.revision,
            inning: context.inning,
            outs: context.outs,
            balls: result.snapshot.balls,
            strikes: result.snapshot.strikes,
            pitchNumber: context.pitchNumber + 1,
            scoreDifferential: context.scoreDifferential,
            leverage: context.leverage,
            fatigue: min(100, context.fatigue + 1)
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
    strategy: strategy.rawValue
)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let data = try encoder.encode(report)
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data("\n".utf8))
