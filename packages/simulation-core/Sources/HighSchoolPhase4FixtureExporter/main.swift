import CryptoKit
import Foundation
import SimulationCore

private let fixtureSchema = "baseball-high-school-phase4-fixture-v3"
private let sourceCommit = "792d72859dc5dcfdc8cefa8b69ab50bc072c212f"
private let defaultOutput = "artifacts/android-compose/fixtures/swift-high-school-phase4-oracle-v3.json"

private struct Row {
    let seed: String
    let phaseTrace: String
    let trainingTotal: Int
    let relationshipTotal: Int
    let importantGameTotal: Int
    let completedGames: Int
    let chapter: Int
    let selectedAwakenings: Int
    let draftOutcome: String
    let draftEvaluation: Int
    /// The core engine's additive memory-card option count.
    let memoryOptionCount: Int
    /// The separate CareerSignatureLegacy candidate contract used by the current application.
    let signatureLegacyCandidateIDs: [String]
    let finalRatings: [Int]
    let performance: [Int]
    let trust: [Int]
    let relationshipCategories: [String]
    let relationshipGrowth: [String]
    let automaticSummary: [Int]
    let automaticLines: [[Int]]
    let fanInterest: Int
}

private func sha256(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
}

private func json(_ value: String) -> String {
    "\"" + value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n") + "\""
}

private func json(_ values: [String]) -> String {
    "[" + values.map(json).joined(separator: ",") + "]"
}

private func json(_ values: [Int]) -> String {
    "[" + values.map(String.init).joined(separator: ",") + "]"
}

private func json(_ values: [[Int]]) -> String {
    "[" + values.map(json).joined(separator: ",") + "]"
}

private func canonicalRow(_ row: Row) -> String {
    let values: [String] = [
        row.seed, row.phaseTrace, String(row.trainingTotal), String(row.relationshipTotal),
        String(row.importantGameTotal), String(row.completedGames), String(row.chapter),
        String(row.selectedAwakenings), row.draftOutcome, String(row.draftEvaluation),
        String(row.memoryOptionCount), String(row.signatureLegacyCandidateIDs.count),
        row.signatureLegacyCandidateIDs.joined(separator: ","), row.finalRatings.map(String.init).joined(separator: ","),
        row.performance.map(String.init).joined(separator: ","), row.trust.map(String.init).joined(separator: ","),
        row.relationshipCategories.joined(separator: ","), row.relationshipGrowth.joined(separator: ","),
        row.automaticSummary.map(String.init).joined(separator: ","),
        row.automaticLines.map { $0.map(String.init).joined(separator: ":") }.joined(separator: ","),
        String(row.fanInterest),
    ]
    return values.joined(separator: "|") + "\n"
}

private func run(seed: String) throws -> Row {
    let engine = HighSchoolCareerEngine()
    var result = try engine.start(.init(seed: seed, presetID: "power_prospect"))
    let startingPitcher = result.snapshot.pitcher
    var phases = [result.snapshot.phase.rawValue]
    var relationshipCategories: [String] = []
    var relationshipGrowth: [String] = []
    result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
    phases.append(result.snapshot.phase.rawValue)
    result = try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: .haedongPower))
    phases.append(result.snapshot.phase.rawValue)

    for _ in 0..<500 {
        switch result.snapshot.phase {
        case .training:
            result = try engine.commitTraining(.init(seed: result.nextSeed, state: result.snapshot, focus: .command, intensity: .standard))
        case .relationship:
            relationshipCategories.append(result.snapshot.currentRelationshipEvent?.category ?? "missing")
            result = try engine.resolveRelationship(.init(seed: result.nextSeed, state: result.snapshot, response: .listen))
            relationshipGrowth.append(result.snapshot.lastRelationship?.growthFocus?.rawValue ?? "none")
        case .importantGame:
            let report = ImportantInningReport(
                scenarioNumber: result.snapshot.performance.importantGamesCompleted + 1,
                pitches: 18, strikeouts: 2, walks: 0, runsAllowed: 0,
                expectedDamage: 400, actualDamage: 250, recommendationAccepted: 12,
                outs: 3, sequenceMasteryCount: 4, hits: 0
            )
            result = try engine.recordImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report))
        case .awakening:
            guard let awakening = result.snapshot.awakeningOptions.first else { throw NSError(domain: "Phase4Fixture", code: 2) }
            result = try engine.chooseAwakening(.init(seed: result.nextSeed, state: result.snapshot, awakening: awakening))
        case .chapterReview:
            result = try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
        case .draft:
            result = try engine.resolveDraft(.init(seed: result.nextSeed, state: result.snapshot))
        case .legacy:
            let memory = Array(result.snapshot.legacyOptions.prefix(result.snapshot.memorySlots))
            result = try engine.selectLegacy(.init(seed: result.nextSeed, state: result.snapshot, memoryCards: memory))
        case .prologue, .schoolSelection, .completed:
            break
        }
        phases.append(result.snapshot.phase.rawValue)
        if result.snapshot.phase == .completed { break }
    }
    guard result.snapshot.phase == .completed else { throw NSError(domain: "Phase4Fixture", code: 3) }
    let schedule = result.snapshot.schedule ?? .fixedDefault
    let draft = result.snapshot.draftResult
    let signatureCandidates = CareerSignatureLegacy.candidates(
        startingPitcher: startingPitcher,
        finalState: result.snapshot
    ).map { $0.id.rawValue }
    let automatic = result.snapshot.seasonLog?.filter { !$0.played } ?? []
    return Row(
        seed: seed,
        phaseTrace: phases.joined(separator: ">"),
        trainingTotal: schedule.trainingTotal,
        relationshipTotal: schedule.relationshipTotal,
        importantGameTotal: schedule.importantGameTotal,
        completedGames: result.snapshot.performance.importantGamesCompleted,
        chapter: result.snapshot.chapter.number,
        selectedAwakenings: result.snapshot.selectedAwakenings.count,
        draftOutcome: draft?.outcome.rawValue ?? "none",
        draftEvaluation: draft?.evaluationScore ?? 0,
        memoryOptionCount: result.snapshot.legacyOptions.count,
        signatureLegacyCandidateIDs: signatureCandidates,
        finalRatings: [result.snapshot.pitcher.stuff, result.snapshot.pitcher.command, result.snapshot.pitcher.movement, result.snapshot.pitcher.stamina],
        performance: [
            result.snapshot.performance.importantGamesCompleted,
            result.snapshot.performance.pitches,
            result.snapshot.performance.strikeouts,
            result.snapshot.performance.walks,
            result.snapshot.performance.runsAllowed,
            result.snapshot.performance.expectedDamage,
            result.snapshot.performance.actualDamage,
        ],
        trust: [
            result.snapshot.managerTrust ?? result.snapshot.relationshipTrust,
            result.snapshot.catcherTrust ?? result.snapshot.relationshipTrust,
            result.snapshot.rivalTrust ?? result.snapshot.relationshipTrust,
        ],
        relationshipCategories: relationshipCategories,
        relationshipGrowth: relationshipGrowth,
        automaticSummary: [
            automatic.reduce(0) { $0 + $1.outs },
            automatic.reduce(0) { $0 + $1.runsAllowed },
            automatic.reduce(0) { $0 + $1.pitches },
            automatic.reduce(0) { $0 + $1.strikeouts },
            automatic.reduce(0) { $0 + $1.walks },
        ],
        automaticLines: automatic.map { [$0.outs, $0.runsAllowed, $0.pitches, $0.strikeouts, $0.walks, $0.hits ?? 0] },
        fanInterest: result.snapshot.fanInterest,
    )
}

let outputPath = ProcessInfo.processInfo.environment["BASEBALL_HIGH_SCHOOL_PHASE4_ORACLE_OUTPUT"] ?? defaultOutput
let seeds = (0..<20).map { String(918220 + $0 * 17) }
private let rows = try seeds.map(run)
let inputCanonical = [
    "HighSchoolCareerEngine.Phase4Vertical",
    "preset:power_prospect", "school:haedong_power", "focus:command", "intensity:standard", "relationship:listen",
    "game:pitches18|strikeouts2|walks0|runs0|expected400|actual250|accepted12|outs3|sequence4|hits0",
    "awakening:first_available", "locale:ko-KR", "timezone:Asia/Seoul", "seeds:918220+17*n,n=0..19"
].joined(separator: "|")
let outputCanonical = rows.map(canonicalRow).joined()

var output = """
{
  "fixtureSchema": \(json(fixtureSchema)),
  "sourceRuntime": "swift",
  "sourceCommit": \(json(sourceCommit)),
  "inputSha256": \(json(sha256(inputCanonical))),
  "outputSha256": \(json(sha256(outputCanonical))),
  "authorityScope": "current-swift-high-school-phase4-core-meta-vertical",
  "input": {
    "fixture": "HighSchoolCareerEngine.Phase4Vertical",
    "seedFormula": "918220 + 17*n, n=0..19",
    "preset": "power_prospect",
    "school": "haedong_power",
    "locale": "ko-KR",
    "timezone": "Asia/Seoul"
  },
  "expected": {
    "exactRuns": 20,
    "canonicalRow": "seed|phaseTrace|trainingTotal|relationshipTotal|importantGameTotal|completedGames|chapter|selectedAwakenings|draftOutcome|draftEvaluation|memoryOptionCount|signatureLegacyCandidateCount|signatureLegacyCandidateIDs|finalRatings|performance|trust|relationshipCategories|relationshipGrowth|automaticSummary|automaticLines|fanInterest\\n",
    "rows": [
"""
for (index, row) in rows.enumerated() {
    output += "      {\"seed\":\(json(row.seed)),\"phaseTrace\":\(json(row.phaseTrace)),\"trainingTotal\":\(row.trainingTotal),\"relationshipTotal\":\(row.relationshipTotal),\"importantGameTotal\":\(row.importantGameTotal),\"completedGames\":\(row.completedGames),\"chapter\":\(row.chapter),\"selectedAwakenings\":\(row.selectedAwakenings),\"draftOutcome\":\(json(row.draftOutcome)),\"draftEvaluation\":\(row.draftEvaluation),\"memoryOptionCount\":\(row.memoryOptionCount),\"signatureLegacyCandidateCount\":\(row.signatureLegacyCandidateIDs.count),\"signatureLegacyCandidateIDs\":\(json(row.signatureLegacyCandidateIDs)),\"finalRatings\":\(json(row.finalRatings)),\"performance\":\(json(row.performance)),\"trust\":\(json(row.trust)),\"relationshipCategories\":\(json(row.relationshipCategories)),\"relationshipGrowth\":\(json(row.relationshipGrowth)),\"automaticSummary\":\(json(row.automaticSummary)),\"automaticLines\":\(json(row.automaticLines)),\"fanInterest\":\(row.fanInterest)}"
    output += index == rows.count - 1 ? "\n" : ",\n"
}
output += """
    ]
  }
}
"""

let url = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
try output.write(to: url, atomically: true, encoding: .utf8)
print("Swift high-school Phase 4 fixture exported: \(outputPath) inputSha256=\(sha256(inputCanonical)) outputSha256=\(sha256(outputCanonical))")
