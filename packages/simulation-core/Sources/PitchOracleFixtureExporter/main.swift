import CryptoKit
import Foundation
import SimulationCore

private let fixtureSchema = "baseball-cross-runtime-fixture-v1"
private let sourceCommit = "792d72859dc5dcfdc8cefa8b69ab50bc072c212f"
private let defaultOutput = "artifacts/android-compose/fixtures/swift-pitch-kernel-oracle-v1.json"

struct OracleRow {
    let seed: String
    let outcome: String
    let actualX: Int
    let actualY: Int
    let velocityTenthsKph: Int
    let eventHash: String
}

func sha256(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
}

func fnv1a64(_ value: String) -> String {
    var hash: UInt64 = 0xCBF2_9CE4_8422_2325
    for byte in value.utf8 {
        hash ^= UInt64(byte)
        hash &*= 0x0000_0100_0000_01B3
    }
    return String(format: "%016llx", hash)
}

func json(_ value: String) -> String {
    "\"" + value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n") + "\""
}

func input(seed: String) -> PreparePitchParams {
    PreparePitchParams(
        seed: seed,
        pitcher: PitcherSnapshot(
            id: "pitcher-1", name: "테스트투수", stuff: 62, command: 54, movement: 58, stamina: 60
        ),
        batter: BatterSnapshot(
            id: "batter-1", name: "이준호", contact: 56, discipline: 52, power: 58
        ),
        scouting: BatterScoutingSnapshot(
            hotZone: PitchZone(row: 1, column: 1),
            coldZone: PitchZone(row: 2, column: 0),
            pitchStrength: .fourSeam,
            pitchWeakness: .slider,
            chaseTendency: 48
        ),
        context: PlateAppearanceContext(
            plateAppearanceID: "pa-1", revision: 0, inning: 7, outs: 0, balls: 1, strikes: 1,
            pitchNumber: 1, scoreDifferential: 0, leverage: 600, fatigue: 12
        )
    )
}

let outputPath = ProcessInfo.processInfo.environment["BASEBALL_PITCH_ORACLE_OUTPUT"] ?? defaultOutput
let engine = PitchKernelEngine()
var rows: [OracleRow] = []
var outcomes: [String: Int] = [:]
var canonicalRows = ""

for seed in 1...10_000 {
    let seedString = String(seed)
    let parameters = input(seed: seedString)
    let preparation = try engine.preparePitch(parameters)
    let result = try engine.submitPitch(
        SubmitPitchParams(
            seed: seedString,
            pitcher: parameters.pitcher,
            batter: parameters.batter,
            scouting: parameters.scouting,
            context: parameters.context,
            preparationToken: preparation.preparationToken,
            call: preparation.primaryRecommendation.call
        )
    )
    let row = OracleRow(
        seed: seedString,
        outcome: result.snapshot.outcome.rawValue,
        actualX: result.snapshot.execution.actualX,
        actualY: result.snapshot.execution.actualY,
        velocityTenthsKph: result.snapshot.execution.velocityTenthsKPH,
        eventHash: result.eventHash
    )
    outcomes[row.outcome, default: 0] += 1
    if seed <= 128 {
        rows.append(row)
        canonicalRows += "\(row.seed)|\(row.outcome)|\(row.actualX)|\(row.actualY)|\(row.velocityTenthsKph)|\(row.eventHash)\n"
    }
}

let inputCanonical = [
    "PitchKernelTranslationTests.FixtureInput",
    "pitcher-1", "62", "54", "58", "60",
    "batter-1", "56", "52", "58",
    "hot:1:1", "cold:2:0", "strength:four_seam", "weakness:slider", "chase:48",
    "pa-1", "revision:0", "inning:7", "outs:0", "balls:1", "strikes:1",
    "pitchNumber:1", "scoreDifferential:0", "leverage:600", "fatigue:12", "seed:1..10000"
].joined(separator: "|")
let outputCanonical = canonicalRows + "distribution|" + outcomes.keys.sorted().map { "\($0):\(outcomes[$0]!)" }.joined(separator: ",")
let sortedOutcomes = outcomes.keys.sorted()

var output = """
{
  "fixtureSchema": \(json(fixtureSchema)),
  "sourceRuntime": "swift",
  "sourceCommit": \(json(sourceCommit)),
  "inputSha256": \(json(sha256(inputCanonical))),
  "outputSha256": \(json(sha256(outputCanonical))),
  "input": {
    "fixture": "PitchKernelTranslationTests.FixtureInput",
    "seedRange": "1..10000",
    "pitcher": {"id": "pitcher-1", "stuff": 62, "command": 54, "movement": 58, "stamina": 60},
    "batter": {"id": "batter-1", "contact": 56, "discipline": 52, "power": 58},
    "scouting": {"hotZone": [1, 1], "coldZone": [2, 0], "pitchStrength": "four_seam", "pitchWeakness": "slider", "chaseTendency": 48},
    "context": {"plateAppearanceId": "pa-1", "revision": "0", "inning": 7, "outs": 0, "balls": 1, "strikes": 1, "pitchNumber": 1, "scoreDifferential": 0, "leverage": 600, "fatigue": 12}
  },
  "expected": {
    "exactRuns": 128,
    "canonicalRow": "seed|outcomeWire|actualX|actualY|velocityTenthsKph|eventHash\\n",
    "canonicalRowsFnv1a64": \(json(fnv1a64(canonicalRows))),
    "rows": [
"""
for (index, row) in rows.enumerated() {
    output += "      {\"seed\":\(json(row.seed)),\"outcome\":\(json(row.outcome)),\"actualX\":\(row.actualX),\"actualY\":\(row.actualY),\"velocityTenthsKph\":\(row.velocityTenthsKph),\"eventHash\":\(json(row.eventHash))}"
    output += index == rows.count - 1 ? "\n" : ",\n"
}
output += "    ],\n    \"distribution\": {\n"
for (index, outcome) in sortedOutcomes.enumerated() {
    output += "      \(json(outcome)): \(outcomes[outcome]!)"
    output += index == sortedOutcomes.count - 1 ? "\n" : ",\n"
}
output += "    }\n  }\n}\n"

let url = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
try output.write(to: url, atomically: true, encoding: .utf8)
print("Swift pitch oracle fixture exported: \(outputPath) inputSha256=\(sha256(inputCanonical)) outputSha256=\(sha256(outputCanonical))")
