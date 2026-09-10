import Foundation
import CryptoKit
import SimulationCore

private let sourceCommit: String = {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = ["rev-parse", "HEAD"]
    let pipe = Pipe()
    process.standardOutput = pipe
    try! process.run()
    process.waitUntilExit()
    precondition(process.terminationStatus == 0, "fixture export requires source revision")
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!
        .trimmingCharacters(in: .whitespacesAndNewlines)
}()
// Commit alone cannot identify a dirty worktree. Pin the exact Swift core bytes as well.
private let sourceTreeSha256: String = {
    let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("SimulationCore")
    let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)!
        .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }.sorted { $0.path < $1.path }
    var hash = SHA256()
    for file in files {
        hash.update(data: Data((String(file.path.dropFirst(directory.path.count + 1)) + "\n").utf8))
        hash.update(data: try! Data(contentsOf: file))
    }
    return hash.finalize().map { String(format: "%02x", $0) }.joined()
}()

func values(_ s: ProCareerSnapshot) -> [String] {
    let r = s.currentStats
    return [s.phase == .completed && s.hallOfFameScore != nil ? "retired" : s.phase.rawValue, String(s.season), String(s.week), s.level.rawValue, s.role.rawValue,
        "\(s.pitcher.stuff),\(s.pitcher.command),\(s.pitcher.movement),\(s.pitcher.stamina)",
        "\(s.fatigue),\(s.managerTrust),\(s.catcherTrust),\(s.injuryWeeks)",
        "\(r.games),\(r.starts),\(r.inningsOuts),\(r.strikeouts),\(r.walks),\(r.runsAllowed),\(r.hits),\(r.pitches)",
        String(s.journeyState?.finances.availableFunds ?? 0), String(s.careerStats.count),
        String(s.contract?.yearsRemaining ?? 0), "\(r.wins),\(r.losses),\(r.saves)", String(s.contract?.annualSalary ?? 0), String(s.journeyState?.reputation.fanSupport ?? 0), String(s.hallOfFameScore ?? -1), "\(s.pitcher.mastery?.stuff ?? 0),\(s.pitcher.mastery?.command ?? 0),\(s.pitcher.mastery?.movement ?? 0),\(s.pitcher.mastery?.stamina ?? 0)",
        "\(s.journeyState?.activeGoal?.ambition.rawValue ?? "none"):\(s.journeyState?.activeGoal?.completedSeason ?? 0):\(s.journeyState?.goalHistory.filter { $0.outcome == .completed }.count ?? 0)",
        (s.journeyState?.pendingContractMarket?.offers ?? []).map { "\($0.teamID):\($0.years):\($0.annualSalary):\($0.signingBonus ?? 0):\($0.contractKind.rawValue):\($0.rolePromise.rawValue):\($0.expectation.kind.rawValue):\($0.expectation.target):\($0.expectation.difficulty.rawValue)" }.joined(separator: ";")]
}
var highSchoolRows: [[String: Any]] = []
func hsValues(_ s: HighSchoolCareerSnapshot) -> [String] {
    let d = s.draftResult
    return trainingValues(s) + ["\(s.managerTrust ?? s.relationshipTrust),\(s.catcherTrust ?? s.relationshipTrust),\(s.rivalTrust ?? s.relationshipTrust),\(s.fanInterest)",
        "\(s.performance.importantGamesCompleted),\(s.performance.pitches),\(s.performance.strikeouts),\(s.performance.walks),\(s.performance.runsAllowed)",
        "\(d?.outcome.rawValue ?? "none"):\(d?.evaluationScore ?? 0):\(d?.team?.id ?? "none"):\(d?.round ?? 0):\(d?.signingBonus ?? 0)", s.selectedAwakenings.map(\.rawValue).joined(separator: ",")]
}
@MainActor func runHighSchool() throws -> HighSchoolCareerResult {
    let engine = HighSchoolCareerEngine(gameplayRulesVersion: HighSchoolGameplayRules.reference)
    var r = try engine.start(.init(seed: "918220", presetID: "power_prospect", signatureLegacyID: nil, inheritanceRulesVersion: nil,
        startingRepertoire: PitchLearningRules.recommendedSelection(presetID: "power_prospect")))
    highSchoolRows.append(["action": "start", "seed": "918220", "args": [], "nextSeed": r.nextSeed, "values": hsValues(r.snapshot)])
    for _ in 0..<500 {
        let s = r.snapshot; if s.phase == .completed { break }
        let seed = r.nextSeed; var action = ""; var args: [String] = []
        switch s.phase {
        case .prologue: action = "prologue"; r = try engine.completePrologue(.init(seed: seed, state: s))
        case .schoolSelection: action = "school"; r = try engine.chooseSchool(.init(seed: seed, state: s, schoolID: .haedongPower))
        case .training:
            let focus: TrainingFocus = s.pitchLearningProject?.isCompleted == false ? .breakingBall : .command
            action = "training"; args = [focus.rawValue]
            r = try engine.commitTraining(.init(seed: seed, state: s, focus: focus, intensity: .standard, targetPitch: focus == .breakingBall ? .curveball : nil))
        case .relationship: action = "relationship"; r = try engine.resolveRelationship(.init(seed: seed, state: s, response: .listen))
        case .importantGame:
            action = "game"
            r = try engine.recordImportantGame(.init(seed: seed, state: s, report: .init(scenarioNumber: s.performance.importantGamesCompleted + 1,
                pitches: 18, strikeouts: 2, walks: 0, runsAllowed: 0, expectedDamage: 400, actualDamage: 250, recommendationAccepted: 12, outs: 3, sequenceMasteryCount: 4, hits: 0)))
        case .awakening:
            let awakening = s.awakeningOptions.first!; action = "awakening"; args = [awakening.rawValue]
            r = try engine.chooseAwakening(.init(seed: seed, state: s, awakening: awakening))
        case .chapterReview: action = "chapter"; r = try engine.advanceChapter(.init(seed: seed, state: s))
        case .draft: action = "draft"; r = try engine.resolveDraft(.init(seed: seed, state: s))
        case .legacy:
            let cards = Array(s.legacyOptions.prefix(s.memorySlots)); action = "legacy"; args = cards.map(\.rawValue)
            r = try engine.selectLegacy(.init(seed: seed, state: s, memoryCards: cards))
        case .completed: break
        }
        highSchoolRows.append(["action": action, "seed": seed, "args": args, "nextSeed": r.nextSeed, "values": hsValues(r.snapshot)])
    }
    precondition(r.snapshot.phase == .completed && r.snapshot.draftResult?.outcome == .drafted)
    return r
}
let highSchool = try runHighSchool()
func runPro(seed: String, freeAgency: Bool, linked: Bool = false) throws -> [[String: Any]] {
// 이 픽스처는 **v10 경로를 붙들어 두기 위해** 있다. 살아 있는 버전을 따라가면 기준점이
// 같이 움직여서 아무것도 고정하지 못한다. 그래서 엔진을 참조 버전에 못박는다.
let engine = ProCareerEngine(journeyEnabled: true, rulesVersion: ProGameplayRules.reference)
let team = ProCareerEngine.proTeams[0]
let preset = PitcherPresetCatalog.all.first { $0.id == "power_prospect" }!
let pitcher = linked ? highSchool.snapshot.pitcher : preset.pitcher
let draft: DraftResultSnapshot = linked ? highSchool.snapshot.draftResult! : .init(outcome: .drafted, evaluationScore: 72, projectedRange: "2~3라운드", team: team, round: 2, overallPick: 18, signingBonus: 120_000_000, firstSeasonGoal: "2군 선발", summary: "지명")
var result = try engine.start(.init(seed: seed, identity: .defaultPitcher, pitcher: pitcher, draftResult: draft,
    entitlement: .init(status: .active, source: .development, verifiedAt: "2026-09-05"),
    sourceFanInterest: linked ? highSchool.snapshot.fanInterest : nil, startingRepertoire: nil,
    repertoireRulesVersion: linked ? highSchool.snapshot.repertoireRulesVersion : nil, pitchLearningProject: linked ? highSchool.snapshot.pitchLearningProject : nil))
var rows: [[String: Any]] = [["action": "start", "args": [seed], "seed": seed, "nextSeed": result.nextSeed, "values": values(result.snapshot)]]
for _ in 0..<2400 {
    if result.snapshot.phase == .completed { break }
    let s = result.snapshot
    let inputSeed = result.nextSeed
    var action = ""
    var args: [String] = []
    switch s.phase {
    case .contractOffer:
        let market = s.journeyState!.pendingContractMarket!
        let completed = Set(s.journeyState!.goalHistory.filter { $0.outcome == .completed }.map(\.ambition) + (s.journeyState!.activeGoal?.completedSeason != nil ? [s.journeyState!.activeGoal!.ambition] : []))
        let ambition = [ProCareerAmbition.franchiseIcon, .enduringPro, .recordBook].first { !completed.contains($0) }
        action = "contract"; args = [ambition?.rawValue ?? "none"]
        result = try engine.acceptContract(.init(seed: inputSeed, state: s, expectedRevision: s.revision, marketID: market.id, offerID: market.offers[0].id, ambition: ambition))
    case .weeklyPlan:
        let plan: ProWeekPlan = s.injuryWeeks > 0 || s.fatigue > 72 ? .recover : s.managerTrust < 68 ? .earnTrust : .refineCommand
        action = "week"; args = [plan.rawValue]
        result = try engine.planWeek(.init(seed: inputSeed, state: s, plan: plan))
    case .seasonDecision:
        let decision = s.pendingDecision!
        let choice = decision.choices.sorted { $0.effect.fatigueDelta == $1.effect.fatigueDelta ? $0.id < $1.id : $0.effect.fatigueDelta < $1.effect.fatigueDelta }.first!
        action = "decision"; args = [choice.id]
        result = try engine.applySeasonDecision(.init(seed: inputSeed, state: s, decisionID: decision.id, choiceID: choice.id))
    case .importantGame:
        action = "game"
        let report = ImportantInningReport(scenarioNumber: s.week, pitches: 24, strikeouts: 4, walks: 0, runsAllowed: 0,
            expectedDamage: 420, actualDamage: 160, recommendationAccepted: 16, outs: 3,
            scoreDifferentialAtEntry: 2, outsAtEntry: 1, sequenceMasteryCount: 1, hits: 0, homeRuns: 0)
        result = try engine.resolveImportantGame(.init(seed: inputSeed, state: s, report: report))
    case .seasonReview:
        action = "review"; result = try engine.reviewSeason(.init(seed: inputSeed, state: s))
    case .seasonSettlement:
        action = "settlement"
        result = try engine.acknowledgeSettlement(.init(seed: inputSeed, state: s, expectedRevision: s.revision, settlementID: s.journeyState!.lastSettlement!.id))
    case .offseasonDecision, .retirementDecision:
        let retire = s.phase == .retirementDecision
        let fa = freeAgency && !retire && (s.contract?.yearsRemaining ?? 0) == 0 && s.serviceYears >= 6
        action = retire ? "retire" : fa ? "fa" : "continue"
        result = try engine.chooseOffseason(.init(seed: inputSeed, state: s, decision: retire ? .retire : fa ? .freeAgency : .continueCareer, expectedRevision: s.revision))
    case .offseasonInvestment:
        action = "investment"
        result = try engine.chooseInvestment(.init(seed: inputSeed, state: s, expectedRevision: s.revision, investment: .none))
    case .nationalTeamCall:
        action = "national_decline"
        result = try engine.respondToNationalTeamCall(.init(seed: inputSeed, state: s, accepted: false))
    case .nationalTournament:
        action = "national_ack"
        result = try engine.acknowledgeNationalTeamResult(.init(seed: inputSeed, state: s))
    case .completed: break
    }
    rows.append(["action": action, "args": args, "seed": inputSeed, "nextSeed": result.nextSeed, "values": values(result.snapshot)])
}
precondition(result.snapshot.phase == .completed && result.snapshot.careerStats.count == 20)
return rows
}
let rows = try runPro(seed: "620050", freeAgency: false)
let faRows = try runPro(seed: "620050", freeAgency: true)
let linkedRows = try runPro(seed: highSchool.nextSeed, freeAgency: true, linked: true)
func trainingValues(_ s: HighSchoolCareerSnapshot) -> [String] {
    let p = s.pitcher
    let project = s.pitchLearningProject
    return [s.phase.rawValue, "\(p.stuff),\(p.command),\(p.movement),\(p.stamina)",
        "\(s.fatigue),\(s.armRisk ?? 0)", "\(project?.practiceCredits ?? -1),\(project?.qualityUses ?? -1),\(project?.stage.rawValue ?? "legacy")",
        (p.pitchProfiles ?? []).sorted { $0.pitchType.rawValue < $1.pitchType.rawValue }.map { "\($0.pitchType.rawValue):\($0.role.rawValue):\($0.velocityTenthsKPH):\($0.control):\($0.command):\($0.movement):\($0.whiff):\($0.weakContact):\($0.fatigueCost)" }.joined(separator: ";")]
}
var trainingRows: [[String: Any]] = []
for preset in ["power_prospect", "precision_commander", "breaking_ball_artist", "innings_eater"] {
    for learning in [PitchType.slider, .curveball, .changeup] {
        let selection = StartingRepertoireSelection(readyBreakingPitches: [PitchType.slider, .curveball, .changeup].filter { $0 != learning }, primaryPitch: .fourSeam, learningPitch: learning)
        let engine = HighSchoolCareerEngine(gameplayRulesVersion: HighSchoolGameplayRules.reference)
        var initial = try engine.start(.init(seed: "918220", presetID: preset, signatureLegacyID: nil, inheritanceRulesVersion: nil, startingRepertoire: selection))
        initial = try engine.completePrologue(.init(seed: initial.nextSeed, state: initial.snapshot))
        initial = try engine.chooseSchool(.init(seed: initial.nextSeed, state: initial.snapshot, schoolID: .haedongPower))
        for focus in [TrainingFocus.velocity, .command, .breakingBall, .stamina, .recovery, .gamePlanning] {
            for intensity in [TrainingIntensity.light, .standard, .intensive] {
                let trained = try engine.commitTraining(.init(seed: initial.nextSeed, state: initial.snapshot, focus: focus, intensity: intensity, targetPitch: focus == .breakingBall ? learning : nil))
                trainingRows.append(["preset": preset, "learning": learning.rawValue, "focus": focus.rawValue, "intensity": intensity.rawValue,
                    "seed": initial.nextSeed, "before": trainingValues(initial.snapshot), "after": trainingValues(trained.snapshot), "nextSeed": trained.nextSeed])
            }
        }
    }
}
let output: [String: Any] = ["schema": "baseball-release-parity-v1", "rulesVersion": ProGameplayRules.reference, "journeyRulesVersion": ProCareerEngine.currentJourneyRulesVersion, "balanceVersion": PitcherPresetCatalog.balanceVersion, "sourceCommit": sourceCommit, "sourceTreeSha256": sourceTreeSha256,
    "scope": "current rules v10; public career commands; identical fixed important-game report; national calls declined", "pro": rows, "proFa": faRows, "proLinked": linkedRows, "highSchool": highSchoolRows, "training": trainingRows]
let data = try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys, .prettyPrinted])
let path = "artifacts/android-compose/release-gate/swift-release-parity.json"
try FileManager.default.createDirectory(atPath: "artifacts/android-compose/release-gate", withIntermediateDirectories: true)
try data.write(to: URL(fileURLWithPath: path), options: .atomic)
print("Exported \(highSchoolRows.count) high-school and \(rows.count + faRows.count + linkedRows.count) pro transitions through three 20-season policies: \(path)")
