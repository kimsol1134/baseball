import Foundation
import SimulationCore

struct BatchReport: Codable {
    let iterations: Int
    let outcomes: [String: Int]
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

let engine = SimulationEngine()
var outcomes: [String: Int] = [:]

for index in 1...iterations {
    let params = SimulatePitchParams(
        seed: String(index),
        pitcher: PitcherSnapshot(
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
        count: CountState(balls: 1, strikes: 1),
        fatigue: 12,
        selection: PitchSelection(
            pitchType: .slider,
            zone: PitchZone(row: 2, column: 0),
            intensity: .normal
        )
    )
    let result = try engine.simulatePitch(params)
    outcomes[result.snapshot.outcome.rawValue, default: 0] += 1
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let report = BatchReport(iterations: iterations, outcomes: outcomes)
let data = try encoder.encode(report)
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data("\n".utf8))
