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
    let sacrificeFlies: Int
    let halfInningsCompleted: Int
    let batSide: String
    /// 존 통과율·존 안 스윙률·존 밖 스윙률(추격률). 실제 야구는 대략 0.48 / 0.68 / 0.31이다.
    let zoneRate: Double
    let swingRateInZone: Double
    let chaseRate: Double
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

// MARK: - 등판 모드
//
// `--outings N`이 있으면 타석 단위 배치 대신 **등판 N경기**를 돌려 집계한다.
// 시즌 성적이 야구처럼 나오는지는 타석 분포만으로 알 수 없다 — 6이닝 선발이 몇 이닝을
// 버티는지, 승패가 어떻게 갈리는지는 경기 단위로만 보인다. `check-balance`가 이 출력을 쓴다.
if let outingIndex = arguments.firstIndex(of: "--outings"),
   arguments.indices.contains(arguments.index(after: outingIndex)),
   let outingCount = Int(arguments[arguments.index(after: outingIndex)]) {
    let outsTarget: Int = {
        guard let index = arguments.firstIndex(of: "--outs-target") else { return 18 }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex), let value = Int(arguments[valueIndex]) else { return 18 }
        return value
    }()
    let role: String = {
        guard let index = arguments.firstIndex(of: "--role") else { return "starter" }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else { return "starter" }
        return arguments[valueIndex]
    }()
    let offset: Int = {
        guard let index = arguments.firstIndex(of: "--batter-offset") else { return 0 }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex), let value = Int(arguments[valueIndex]) else { return 0 }
        return value
    }()
    let presetForOutings: String = {
        guard let index = arguments.firstIndex(of: "--preset") else { return "power_prospect" }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else { return "power_prospect" }
        return arguments[valueIndex]
    }()
    guard let outingPreset = PitcherPresetCatalog.all.first(where: { $0.id == presetForOutings })
        ?? PitcherPresetCatalog.all.first else {
        FileHandle.standardError.write(Data("no preset\n".utf8))
        exit(1)
    }
    func outingRating(_ flag: String, fallback: Int) -> Int {
        guard let index = arguments.firstIndex(of: flag) else { return fallback }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex), let value = Int(arguments[valueIndex]) else {
            return fallback
        }
        return min(80, max(20, value))
    }
    let outingBase = outingPreset.pitcher
    let outingPitcher = PitcherSnapshot(
        id: outingBase.id,
        name: outingBase.name,
        stuff: outingRating("--stuff", fallback: outingBase.stuff),
        command: outingRating("--command", fallback: outingBase.command),
        movement: outingRating("--movement", fallback: outingBase.movement),
        stamina: outingRating("--stamina", fallback: outingBase.stamina),
        pitchProfiles: outingBase.pitchProfiles,
        throwingHand: outingBase.throwingHand
    )

    let started = role == "starter"
    let simulator = AutoOutingSimulator()
    var rng = SplitMix64(seed: 20_260_726)
    var outs = 0, strikeouts = 0, walks = 0, runsAllowed = 0, pitches = 0, hits = 0, homeRuns = 0
    var doubles = 0, triples = 0
    var wins = 0, losses = 0, saves = 0, noDecisions = 0

    for index in 0..<max(1, outingCount) {
        let line = simulator.simulate(
            pitcher: outingPitcher,
            startingFatigue: 18 + (index % 4) * 6,
            outsTarget: outsTarget,
            pitchCap: started ? 96 : 28,
            batterOffset: offset,
            baseSeed: rng.next()
        )
        outs += line.outs; strikeouts += line.strikeouts; walks += line.walks
        runsAllowed += line.runsAllowed; pitches += line.pitches
        hits += line.hits; homeRuns += line.homeRuns
        doubles += line.doubles; triples += line.triples

        let support = LeagueBaseline.teamRuns(using: &rng)
        let othersOuts = max(0, 27 - line.outs)
        let opponentRuns = line.runsAllowed
            + LeagueBaseline.restOfTeamRuns(outsCovered: othersOuts, using: &rng)
        switch DecisionRules.decide(
            started: started, isCloser: role == "closer", outs: line.outs,
            runsAllowed: line.runsAllowed, teamRuns: support, opponentRuns: opponentRuns
        ) {
        case .win: wins += 1
        case .loss: losses += 1
        case .save: saves += 1
        case .noDecision: noDecisions += 1
        }
    }

    struct OutingReport: Encodable {
        let games: Int, outs: Int, strikeouts: Int, walks: Int, runsAllowed: Int
        let pitches: Int, hits: Int, homeRuns: Int, doubles: Int, triples: Int
        let wins: Int, losses: Int, saves: Int, noDecisions: Int
    }
    let outingReport = OutingReport(
        games: outingCount, outs: outs, strikeouts: strikeouts, walks: walks,
        runsAllowed: runsAllowed, pitches: pitches, hits: hits, homeRuns: homeRuns,
        doubles: doubles, triples: triples,
        wins: wins, losses: losses, saves: saves, noDecisions: noDecisions
    )
    let outingEncoder = JSONEncoder()
    outingEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(try outingEncoder.encode(outingReport))
    FileHandle.standardOutput.write(Data("\n".utf8))
    exit(0)
}
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
func batterRating(_ flag: String, default fallback: Int) -> Int {
    guard let index = arguments.firstIndex(of: flag) else { return fallback }
    let valueIndex = arguments.index(after: index)
    guard arguments.indices.contains(valueIndex), let value = Int(arguments[valueIndex]) else {
        return fallback
    }
    return min(max(value, 20), 80)
}
let batterContact = batterRating("--contact", default: 56)
let batterDiscipline = batterRating("--discipline", default: 52)
let batterPower = batterRating("--power", default: 58)
let batSide: BatSide = {
    guard let index = arguments.firstIndex(of: "--bat-side") else { return .right }
    let valueIndex = arguments.index(after: index)
    guard arguments.indices.contains(valueIndex) else { return .right }
    return BatSide(rawValue: arguments[valueIndex]) ?? .right
}()

guard let preset = PitcherPresetCatalog.all.first(where: { $0.id == presetID }) else {
    let available = PitcherPresetCatalog.all.map(\.id).joined(separator: ", ")
    FileHandle.standardError.write(Data("Unknown preset '\(presetID)'. Available: \(available)\n".utf8))
    exit(2)
}
// 투수 스탯 덮어쓰기. 타자 쪽에는 있는데 투수 쪽에 없어서 "구위를 올리면 실제로
// 결과가 달라지는가"를 하네스로 답할 수 없었다. 밸런스 작업의 기본 질문이라 열어 둔다.
let pitcher: PitcherSnapshot = {
    let base = preset.pitcher
    let stuff = batterRating("--stuff", default: base.stuff)
    let command = batterRating("--command", default: base.command)
    let movement = batterRating("--movement", default: base.movement)
    let stamina = batterRating("--stamina", default: base.stamina)
    guard stuff != base.stuff || command != base.command
        || movement != base.movement || stamina != base.stamina else { return base }
    return PitcherSnapshot(
        id: base.id, name: base.name, stuff: stuff, command: command,
        movement: movement, stamina: stamina, pitchProfiles: base.pitchProfiles,
        throwingHand: base.throwingHand
    )
}()
let batter = BatterSnapshot(
    id: "batter-1",
    name: "이준호",
    contact: batterContact,
    discipline: batterDiscipline,
    power: batterPower,
    batSide: batSide
)
let scouting = BatterScoutingSnapshot(
    hotZone: PitchZone(row: 1, column: 1),
    coldZone: PitchZone(row: 2, column: 0),
    pitchStrength: .fourSeam,
    pitchWeakness: .slider,
    chaseTendency: 48
)
// 축 하나만 바꿔 가며 재려면 고정 콜의 각 축을 밖에서 지정할 수 있어야 한다.
// 이게 없으면 "구종을 바꿔도 결과가 같다" 같은 주장을 측정으로 확인할 수 없다.
let fixedPitch: PitchType = {
    guard let index = arguments.firstIndex(of: "--pitch") else {
        return pitcher.pitchProfiles?.first(where: { $0.role == .primary })?.pitchType ?? .slider
    }
    let valueIndex = arguments.index(after: index)
    guard arguments.indices.contains(valueIndex) else { return .slider }
    return PitchType(rawValue: arguments[valueIndex]) ?? .slider
}()
let fixedIntensity: PitchIntensity = {
    guard let index = arguments.firstIndex(of: "--intensity") else { return .normal }
    let valueIndex = arguments.index(after: index)
    guard arguments.indices.contains(valueIndex) else { return .normal }
    return PitchIntensity(rawValue: arguments[valueIndex]) ?? .normal
}()
let fixedZone: PitchZone = {
    guard let index = arguments.firstIndex(of: "--zone") else { return PitchZone(row: 2, column: 0) }
    let valueIndex = arguments.index(after: index)
    guard arguments.indices.contains(valueIndex) else { return PitchZone(row: 2, column: 0) }
    let parts = arguments[valueIndex].split(separator: ",").compactMap { Int($0) }
    guard parts.count == 2 else { return PitchZone(row: 2, column: 0) }
    return PitchZone(row: min(2, max(0, parts[0])), column: min(2, max(0, parts[1])))
}()
let fixedCall = PitchCall(
    pitchType: fixedPitch,
    zone: fixedZone,
    zoneIntent: .edge,
    intensity: fixedIntensity
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
var pitchesInZone = 0
var swingsInZone = 0
var swingsOutOfZone = 0
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
var sacrificeFlies = 0
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
        // An out that still plates a run is a sacrifice fly (the only run-scoring out in the model).
        if result.snapshot.result == .inPlayOut, result.snapshot.runsScored > 0 {
            sacrificeFlies += 1
        }
        if result.snapshot.inningTransition?.inningEnded == true {
            halfInningsCompleted += 1
        }
        finalAdaptationLevel = result.rivalAdaptation.level
        totalPitches += 1
        pitchOutcomes[result.snapshot.outcome.rawValue, default: 0] += 1
        // 존 통과율과 존 밖 스윙률. 삼진이 많고 볼넷이 적은 원인이 "존에 많이 넣어서"인지
        // "타자가 쫓아서"인지는 이 둘 없이는 구분할 수 없다.
        if let entry = result.gameLog.entries.last {
            if entry.wasInZone {
                pitchesInZone += 1
                if entry.batterSwung { swingsInZone += 1 }
            } else {
                if entry.batterSwung { swingsOutOfZone += 1 }
            }
        }
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
    sacrificeFlies: sacrificeFlies,
    halfInningsCompleted: halfInningsCompleted,
    batSide: batSide.rawValue,
    zoneRate: Double(pitchesInZone) / Double(max(1, totalPitches)),
    swingRateInZone: Double(swingsInZone) / Double(max(1, pitchesInZone)),
    chaseRate: Double(swingsOutOfZone) / Double(max(1, totalPitches - pitchesInZone))
)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let data = try encoder.encode(report)
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data("\n".utf8))
