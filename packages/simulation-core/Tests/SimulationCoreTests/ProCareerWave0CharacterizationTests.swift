import CryptoKit
import Foundation
import XCTest
@testable import SimulationCore

/// Wave 0 freezes the current contract/tenure behavior before any product state changes.
/// These tests intentionally describe the legacy path; they are not a new product contract.
final class ProCareerWave0CharacterizationTests: XCTestCase {
    private let engine = ProCareerEngine()

    func testWave0ContractNeverFallsBelowOneAcrossFiveSeasons() throws {
        var result = try signedStart(seed: "700001")
        var yearsAtSeasonStart: [Int] = []

        for season in 1...5 {
            XCTAssertEqual(result.snapshot.season, season)
            yearsAtSeasonStart.append(try XCTUnwrap(result.snapshot.contract).yearsRemaining)
            result = try playAndReview(result)
            if season < 5 {
                result = try engine.chooseOffseason(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    decision: .continueCareer
                ))
            }
        }

        XCTAssertEqual(yearsAtSeasonStart, [3, 2, 1, 1, 1])
        XCTAssertTrue(yearsAtSeasonStart.allSatisfy { $0 >= 1 })
        XCTAssertEqual(result.snapshot.phase, .offseasonDecision)
    }

    func testWave0FreeAgencyAlwaysMovesToCatalogOffsetThree() throws {
        for index in ProCareerEngine.proTeams.indices {
            let currentTeam = ProCareerEngine.proTeams[index]
            let signed = try signedStart(seed: String(700100 + index), team: currentTeam)
            var object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: JSONEncoder().encode(signed.snapshot)) as? [String: Any]
            )
            object["phase"] = ProCareerPhase.offseasonDecision.rawValue
            object["serviceYears"] = 6
            object["commitment"] = ""
            let unsigned = try JSONDecoder().decode(
                ProCareerSnapshot.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
            object["commitment"] = engine.commitment(unsigned)
            let eligible = try JSONDecoder().decode(
                ProCareerSnapshot.self,
                from: JSONSerialization.data(withJSONObject: object)
            )

            let moved = try engine.chooseOffseason(.init(
                seed: String(701100 + index),
                state: eligible,
                decision: .freeAgency
            ))
            let expectedIndex = (index + 3) % ProCareerEngine.proTeams.count
            XCTAssertEqual(
                moved.snapshot.team.id,
                ProCareerEngine.proTeams[expectedIndex].id,
                "current team index " + String(index) + " must use the legacy catalog +3 transition"
            )
        }
    }

    func testWave0TransferCanImmediatelyUseGlobalServiceYearsForClubSymbol() throws {
        let oldTeam = ProCareerEngine.proTeams[0]
        let signed = try signedStart(seed: "700300", team: oldTeam)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(signed.snapshot)) as? [String: Any]
        )
        let dominantSeason = ProSeasonStats(
            season: 1,
            teamID: oldTeam.id,
            inningsOuts: 2_400,
            strikeouts: 240
        )
        object["phase"] = ProCareerPhase.offseasonDecision.rawValue
        object["serviceYears"] = 8
        object["careerStats"] = [
            try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(dominantSeason)) as? [String: Any])
        ]
        object["commitment"] = ""
        let unsigned = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        object["commitment"] = engine.commitment(unsigned)
        let eligible = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        let moved = try engine.chooseOffseason(.init(
            seed: "702300",
            state: eligible,
            decision: .freeAgency
        ))

        XCTAssertNotEqual(moved.snapshot.team.id, oldTeam.id)
        XCTAssertEqual(moved.snapshot.careerStats.first?.teamID, oldTeam.id)
        XCTAssertEqual(moved.snapshot.currentStats.teamID, moved.snapshot.team.id)
        XCTAssertEqual(
            ProCareerEngine.careerStanding(for: moved.snapshot),
            .clubSymbol,
            "global serviceYears and career totals currently survive the transfer as clubSymbol"
        )
    }

    func testWave0SeasonReviewHasNoSalaryFanOrTeamLegacySettlement() throws {
        let signed = try signedStart(seed: "700200")
        let contractBeforeReview = signed.snapshot.contract
        let reviewed = try playAndReview(signed)

        XCTAssertEqual(reviewed.events, ["pro_season_reviewed"])
        XCTAssertEqual(reviewed.snapshot.careerStats.count, 1)
        XCTAssertNil(reviewed.snapshot.hallOfFameScore)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(reviewed.snapshot)) as? [String: Any]
        )
        for key in ["salarySettlement", "fanSupport", "teamLegacy", "teamRecords", "settlement"] {
            XCTAssertNil(object[key], "current season-review state unexpectedly contains " + key)
        }
        XCTAssertEqual(reviewed.snapshot.contract?.annualSalary, contractBeforeReview?.annualSalary)
    }

    func testWave0CurrentSwiftNextSeedsMatchTheV1GoldenFixture() throws {
        let root = Wave0BaselineGenerator.repositoryRoot()
        let evidence = try Wave0BaselineGenerator.v1NextSeedEvidence(
            repositoryRoot: root,
            sourceRevision: Wave0BaselineGenerator.gitHead(at: root)
        )
        XCTAssertEqual(evidence["nextSeedMatches"] as? Bool, true)
        XCTAssertEqual(evidence["rowsCompared"] as? Int, 20)
        XCTAssertEqual(evidence["currentOutputSha256"] as? String, evidence["goldenOutputSha256"] as? String)
    }

    /// The generator is opt-in so an ordinary Swift test run never rewrites evidence.
    /// Run it with `BASEBALL_WAVE0_GENERATE=1` using the command recorded in README.md.
    func testGenerateWave0BaselineEvidence() async throws {
        guard ProcessInfo.processInfo.environment["BASEBALL_WAVE0_GENERATE"] == "1" else {
            throw XCTSkip("Wave 0 evidence generation is opt-in")
        }
        try await Wave0BaselineGenerator.generate()
    }

    private func signedStart(seed: String, team: DraftTeamSnapshot? = nil) throws -> ProCareerResult {
        let selectedTeam = team ?? ProCareerEngine.proTeams[0]
        let started = try engine.start(.init(
            seed: seed,
            identity: .defaultPitcher,
            pitcher: PitcherPresetCatalog.all.first { $0.id == "power_prospect" }!.pitcher,
            draftResult: drafted(team: selectedTeam),
            entitlement: activeEntitlement()
        ))
        return try engine.signContract(.init(seed: started.nextSeed, state: started.snapshot))
    }

    private func playAndReview(_ initial: ProCareerResult) throws -> ProCareerResult {
        var result = initial
        var steps = 0
        while result.snapshot.phase != .seasonReview {
            steps += 1
            guard steps <= 160 else {
                throw SimulationError.invalidProCareer("Wave 0 characterization season exceeded its step bound")
            }
            switch result.snapshot.phase {
            case .weeklyPlan:
                let plan: ProWeekPlan = result.snapshot.fatigue > 72
                    ? .recover
                    : result.snapshot.managerTrust < 62 ? .earnTrust : .refineCommand
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: plan))
            case .importantGame:
                result = try engine.resolveImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: positiveReport(week: result.snapshot.week)
                ))
            case .seasonDecision:
                guard let decision = result.snapshot.pendingDecision,
                      let choice = decision.choices.min(by: stableChoiceOrder) else {
                    throw SimulationError.invalidProCareer("Wave 0 characterization decision is incomplete")
                }
                result = try engine.applySeasonDecision(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    decisionID: decision.id,
                    choiceID: choice.id
                ))
            default:
                throw SimulationError.invalidProCareer("Wave 0 characterization entered " + result.snapshot.phase.rawValue)
            }
        }
        return try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
    }

    private func stableChoiceOrder(_ lhs: ProSeasonDecisionChoice, _ rhs: ProSeasonDecisionChoice) -> Bool {
        if lhs.effect.fatigueDelta != rhs.effect.fatigueDelta {
            return lhs.effect.fatigueDelta < rhs.effect.fatigueDelta
        }
        return lhs.id < rhs.id
    }

    private func activeEntitlement() -> ProEntitlementSnapshot {
        .init(status: .active, source: .development, verifiedAt: "2026-07-22", offlineValidUntil: "2026-08-22")
    }

    private func drafted(team: DraftTeamSnapshot) -> DraftResultSnapshot {
        .init(
            outcome: .drafted,
            evaluationScore: 72,
            projectedRange: "2~3라운드",
            team: team,
            round: 2,
            overallPick: 18,
            signingBonus: 120_000_000,
            firstSeasonGoal: "2군 선발",
            summary: "지명"
        )
    }

    private func positiveReport(week: Int) -> ImportantInningReport {
        .init(
            scenarioNumber: week,
            pitches: 18,
            strikeouts: 2,
            walks: 0,
            runsAllowed: 0,
            expectedDamage: 380,
            actualDamage: 240,
            recommendationAccepted: 12
        )
    }
}

private struct Wave0BaselineError: Error, CustomStringConvertible {
    let description: String
}

private struct Wave0BaselineRun: Sendable {
    let seed: Int
    let startNextSeed: String?
    let signedNextSeed: String?
    let firstWeekNextSeed: String?
    let finalNextSeed: String?
    let teamSequence: [String]
    let contractYears: [Int]
    let hallOfFameScore: Int?
    let finalPhase: String
    let completedSeasons: Int
    let error: String?

    static func failed(seed: Int, phase: String, seasons: Int, error: Error) -> Wave0BaselineRun {
        Wave0BaselineRun(
            seed: seed,
            startNextSeed: nil,
            signedNextSeed: nil,
            firstWeekNextSeed: nil,
            finalNextSeed: nil,
            teamSequence: [],
            contractYears: [],
            hallOfFameScore: nil,
            finalPhase: phase,
            completedSeasons: seasons,
            error: String(describing: error)
        )
    }
}

private struct Wave0V1Boundary: Sendable {
    let seed: String
    let careerID: String
    let startNextSeed: String
    let teamID: String
    let signedRevision: Int
    let signedNextSeed: String
    let firstWeekNextSeed: String
    let firstWeekStats: [Int]
    let phase: String
    let level: String
    let role: String
    let segment: String

    func canonicalRow() -> String {
        [
            seed,
            careerID,
            startNextSeed,
            teamID,
            String(signedRevision),
            signedNextSeed,
            firstWeekNextSeed,
            firstWeekStats.map(String.init).joined(separator: ","),
            phase,
            level,
            role,
            segment,
            [6, 13, 20].map(String.init).joined(separator: ","),
            "20",
            "3"
        ].joined(separator: "|") + "\n"
    }

    func nextSeedFields() -> [String: Any] {
        [
            "startNextSeed": startNextSeed,
            "signedNextSeed": signedNextSeed,
            "firstWeekNextSeed": firstWeekNextSeed
        ]
    }
}

private enum Wave0BaselineGenerator {
    static let baselineID = "pro-career-depth-baseline-2026-08-14"
    static let seedCount = 1_000
    static let seasonsPerCareer = 20
    static let generationCommand = "BASEBALL_WAVE0_GENERATE=1 swift test -c release --package-path packages/simulation-core --filter ProCareerWave0CharacterizationTests/testGenerateWave0BaselineEvidence"
    static let baselineDate = "2026-08-14"
    static let committedV1Fixture = "apps/android/game-core/src/test/resources/fixtures/swift-pro-career-oracle-v1.json"

    static func generate() async throws {
        let root = repositoryRoot()
        let sourceRevision = gitHead(at: root)
        let dirty = !gitOutput(["status", "--porcelain"], at: root).isEmpty
        let startedAt = Date()
        let runs = await runAllSeeds()
        let v1 = try v1NextSeedEvidence(repositoryRoot: root, sourceRevision: sourceRevision)
        try writeEvidence(
            repositoryRoot: root,
            sourceRevision: sourceRevision,
            dirtyWorktree: dirty,
            runs: runs,
            v1Evidence: v1,
            elapsedSeconds: Date().timeIntervalSince(startedAt)
        )
    }

    static func repositoryRoot() -> URL {
        var current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).standardizedFileURL
        while current.path != "/" {
            if FileManager.default.fileExists(atPath: current.appendingPathComponent("AGENTS.md").path) {
                return current
            }
            current.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).standardizedFileURL
    }

    static func gitHead(at root: URL) -> String {
        gitOutput(["rev-parse", "HEAD"], at: root)
    }

    private static func gitOutput(_ arguments: [String], at root: URL) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = root
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            // Drain stdout while the process is running. Waiting first deadlocks once a very
            // dirty worktree fills the pipe buffer (Wave 0 began with >1,000 tracked changes).
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return "unknown" }
            return String(data: output, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
        } catch {
            return "unknown"
        }
    }

    private static func runAllSeeds() async -> [Wave0BaselineRun] {
        let workerCount = min(max(1, ProcessInfo.processInfo.activeProcessorCount), 16)
        return await withTaskGroup(of: Wave0BaselineRun.self, returning: [Wave0BaselineRun].self) { group in
            var nextSeed = 0
            for _ in 0..<min(workerCount, seedCount) {
                let seed = nextSeed
                group.addTask { run(seed: seed) }
                nextSeed += 1
            }

            var runs: [Wave0BaselineRun] = []
            while let completedRun = await group.next() {
                runs.append(completedRun)
                if nextSeed < seedCount {
                    let seed = nextSeed
                    nextSeed += 1
                    group.addTask { run(seed: seed) }
                }
            }
            return runs.sorted { $0.seed < $1.seed }
        }
    }

    private static func run(seed: Int) -> Wave0BaselineRun {
        do {
            let engine = ProCareerEngine()
            let team = ProCareerEngine.proTeams[0]
            let pitcher = PitcherPresetCatalog.all.first { $0.id == "power_prospect" }!.pitcher
            let started = try engine.start(.init(
                seed: String(seed),
                identity: .defaultPitcher,
                pitcher: pitcher,
                draftResult: drafted(team: team),
                entitlement: activeEntitlement()
            ))
            let startNextSeed = started.nextSeed
            let signed = try engine.signContract(.init(seed: started.nextSeed, state: started.snapshot))
            let signedNextSeed = signed.nextSeed
            var result = signed
            var firstWeekNextSeed: String?
            var teamSequence: [String] = []
            var contractYears: [Int] = []

            for season in 1...seasonsPerCareer {
                teamSequence.append(result.snapshot.team.id)
                contractYears.append(result.snapshot.contract?.yearsRemaining ?? -1)
                let advanced = try advanceSeason(result, engine: engine, captureFirstWeek: firstWeekNextSeed == nil)
                result = advanced.result
                if firstWeekNextSeed == nil { firstWeekNextSeed = advanced.firstWeekNextSeed }

                if season < seasonsPerCareer {
                    let service = result.snapshot.serviceYears + (result.snapshot.level == .major ? 1 : 0)
                    let decision: OffseasonDecision = service >= 6 ? .freeAgency : .continueCareer
                    result = try engine.chooseOffseason(.init(
                        seed: result.nextSeed,
                        state: result.snapshot,
                        decision: decision
                    ))
                } else {
                    result = try engine.chooseOffseason(.init(
                        seed: result.nextSeed,
                        state: result.snapshot,
                        decision: .retire
                    ))
                }
            }

            return Wave0BaselineRun(
                seed: seed,
                startNextSeed: startNextSeed,
                signedNextSeed: signedNextSeed,
                firstWeekNextSeed: firstWeekNextSeed,
                finalNextSeed: result.nextSeed,
                teamSequence: teamSequence,
                contractYears: contractYears,
                hallOfFameScore: result.snapshot.hallOfFameScore,
                finalPhase: result.snapshot.phase.rawValue,
                completedSeasons: result.snapshot.careerStats.count,
                error: nil
            )
        } catch {
            return Wave0BaselineRun.failed(seed: seed, phase: "failed", seasons: 0, error: error)
        }
    }

    private static func advanceSeason(
        _ initial: ProCareerResult,
        engine: ProCareerEngine,
        captureFirstWeek: Bool
    ) throws -> (result: ProCareerResult, firstWeekNextSeed: String?) {
        var result = initial
        var firstWeekNextSeed: String?
        var steps = 0
        while result.snapshot.phase != .seasonReview {
            steps += 1
            guard steps <= 160 else {
                throw Wave0BaselineError(description: "season step bound exceeded")
            }
            switch result.snapshot.phase {
            case .weeklyPlan:
                let plan: ProWeekPlan = result.snapshot.fatigue > 72
                    ? .recover
                    : result.snapshot.managerTrust < 62 ? .earnTrust : .refineCommand
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: plan))
                if captureFirstWeek && firstWeekNextSeed == nil { firstWeekNextSeed = result.nextSeed }
            case .importantGame:
                result = try engine.resolveImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: positiveReport(week: result.snapshot.week)
                ))
            case .seasonDecision:
                guard let decision = result.snapshot.pendingDecision,
                      let choice = decision.choices.min(by: stableChoiceOrder) else {
                    throw Wave0BaselineError(description: "decision choice missing")
                }
                result = try engine.applySeasonDecision(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    decisionID: decision.id,
                    choiceID: choice.id
                ))
            default:
                throw Wave0BaselineError(description: "unexpected phase " + result.snapshot.phase.rawValue)
            }
        }
        return (
            try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot)),
            firstWeekNextSeed
        )
    }

    static func v1NextSeedEvidence(repositoryRoot root: URL, sourceRevision: String) throws -> [String: Any] {
        let fixtureURL = root.appendingPathComponent(committedV1Fixture)
        let fixtureData = try Data(contentsOf: fixtureURL)
        let fixture = try XCTJSON.object(from: fixtureData)
        let expected = try XCTJSON.object(value: fixture["expected"])
        let goldenRows = try XCTJSON.arrayOfObjects(value: expected["rows"])
        guard goldenRows.count == 20 else {
            throw Wave0BaselineError(description: "v1 golden fixture row count is " + String(goldenRows.count) + ", expected 20")
        }

        let currentRows = try (100..<120).map(currentV1Boundary(seed:))
        let nextSeedFields = ["startNextSeed", "signedNextSeed", "firstWeekNextSeed"]
        var nextSeedMatches = true
        var currentCanonical = ""
        for (index, current) in currentRows.enumerated() {
            let golden = goldenRows[index]
            for field in nextSeedFields {
                let goldenValue = golden[field] as? String
                let currentValue = current.nextSeedFields()[field] as? String
                if goldenValue != currentValue { nextSeedMatches = false }
            }
            currentCanonical += current.canonicalRow()
        }
        guard nextSeedMatches else {
            throw Wave0BaselineError(description: "current Swift nextSeed values differ from the committed v1 golden fixture")
        }

        let first = currentRows[0]
        let last = currentRows[currentRows.count - 1]
        return [
            "fixturePath": committedV1Fixture,
            "goldenSourceCommit": fixture["sourceCommit"] as? String ?? "unknown",
            "currentSourceRevision": sourceRevision,
            "goldenInputSha256": fixture["inputSha256"] as? String ?? "unknown",
            "goldenOutputSha256": fixture["outputSha256"] as? String ?? "unknown",
            "currentOutputSha256": sha256Hex(Data(currentCanonical.utf8)),
            "rowsCompared": currentRows.count,
            "nextSeedFields": nextSeedFields,
            "nextSeedMatches": nextSeedMatches,
            "samples": [
                "100": ["golden": goldenRows[0].filtered(keys: nextSeedFields), "current": first.nextSeedFields()],
                "119": ["golden": goldenRows[19].filtered(keys: nextSeedFields), "current": last.nextSeedFields()]
            ]
        ]
    }

    private static func currentV1Boundary(seed: Int) throws -> Wave0V1Boundary {
        let engine = ProCareerEngine()
        let team = ProCareerEngine.proTeams[0]
        let pitcher = PitcherPresetCatalog.all.first { $0.id == "power_prospect" }!.pitcher
        var result = try engine.start(.init(
            seed: String(seed),
            identity: .defaultPitcher,
            pitcher: pitcher,
            draftResult: drafted(team: team),
            entitlement: activeEntitlement()
        ))
        let start = result.snapshot
        let startNextSeed = result.nextSeed
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        let signed = result.snapshot
        let signedNextSeed = result.nextSeed
        result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .earnTrust))
        let stats = result.snapshot.currentStats
        return Wave0V1Boundary(
            seed: String(seed),
            careerID: start.proCareerID,
            startNextSeed: startNextSeed,
            teamID: start.team.id,
            signedRevision: Int(signed.revision),
            signedNextSeed: signedNextSeed,
            firstWeekNextSeed: result.nextSeed,
            firstWeekStats: [stats.games, stats.starts, stats.inningsOuts, stats.strikeouts, stats.walks, stats.runsAllowed, stats.hits, stats.pitches],
            phase: result.snapshot.phase.rawValue,
            level: result.snapshot.level.rawValue,
            role: result.snapshot.role.rawValue,
            segment: result.snapshot.seasonSegment?.rawValue ?? "none"
        )
    }

    private static func writeEvidence(
        repositoryRoot root: URL,
        sourceRevision: String,
        dirtyWorktree: Bool,
        runs: [Wave0BaselineRun],
        v1Evidence: [String: Any],
        elapsedSeconds: TimeInterval
    ) throws {
        guard runs.count == seedCount else {
            throw Wave0BaselineError(description: "baseline returned " + String(runs.count) + " runs, expected " + String(seedCount))
        }
        let outputDirectory = root.appendingPathComponent("artifacts/analysis/" + baselineID)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let expectedFiles = Set(["README.md", "contract-lifecycle.json", "team-tenure.json", "hall-of-fame.json", "career-completion.json"])
        let unexpected = try FileManager.default.contentsOfDirectory(atPath: outputDirectory.path)
            .filter { !expectedFiles.contains($0) }
        guard unexpected.isEmpty else {
            throw Wave0BaselineError(description: "baseline output contains unexpected files: " + unexpected.joined(separator: ", "))
        }

        let sortedRuns = runs.sorted { $0.seed < $1.seed }
        let metadata: [String: Any] = [
            "baselineID": baselineID,
            "generatedOn": baselineDate,
            "sourceRevision": sourceRevision,
            "dirtyWorktreeAtGeneration": dirtyWorktree,
            "preExistingDirtyWorktreeAtWaveStart": true,
            "seedRange": "0..999",
            "seedCount": seedCount,
            "seasonsPerCareer": seasonsPerCareer,
            "scenario": "ProCareerEngine current Swift core",
            "presetID": "power_prospect",
            "initialTeam": "proTeams[0]",
            "weeklyPolicy": "fatigue>72 recover; managerTrust<62 earnTrust; otherwise refineCommand; resolve current important games with the stable positive fixture report",
            "offseasonPolicy": "freeAgency whenever serviceYears + major-level registration >= 6; otherwise continue; retire after season 20",
            "generationCommand": generationCommand
        ]
        let runDigest = digestRuns(sortedRuns)
        let aggregate = summarize(sortedRuns)
        let baseChecks: [String: Any] = [
            "expectedRunCount": seedCount,
            "actualRunCount": sortedRuns.count,
            "runDigestSha256": runDigest,
            "elapsedSecondsRounded": Int(elapsedSeconds.rounded()),
            "noRawRunsPersisted": true
        ]

        let contractSummary: [String: Any] = [
            "observations": aggregate.contractObservations,
            "yearsRemainingAtSeasonStart": aggregate.contractBySeason,
            "minimumObservedYearsRemaining": aggregate.minimumContractYears,
            "maximumObservedYearsRemaining": aggregate.maximumContractYears,
            "careersWithZeroYearsRemaining": aggregate.careersWithZeroContract,
            "careersAtContractFloorAtFinalSeason": aggregate.careersAtContractFloorAtFinalSeason,
            "representativeSeed100": sample(sortedRuns[100])
        ]
        let teamSummary: [String: Any] = [
            "seasonObservations": aggregate.teamSeasonObservations,
            "teamSeasonCounts": aggregate.teamSeasonCounts,
            "distinctTeamsPerCareer": aggregate.distinctTeamsPerCareer,
            "teamSwitchesPerCareer": aggregate.teamSwitchesPerCareer,
            "maximumSingleTeamTenure": aggregate.maximumSingleTeamTenure,
            "freeAgencyTeamTransitions": aggregate.freeAgencyTeamTransitions,
            "unexpectedTeamTransitions": aggregate.unexpectedTeamTransitions,
            "finalTeamDistribution": aggregate.finalTeamDistribution,
            "representativeSeed100": sample(sortedRuns[100])
        ]
        let hallSummary: [String: Any] = [
            "completedCareerScores": aggregate.hallScores.count,
            "scoreHistogram": aggregate.hallScoreHistogram,
            "minimumScore": aggregate.minimumHallScore,
            "maximumScore": aggregate.maximumHallScore,
            "meanScorePermille": aggregate.meanHallScorePermille,
            "hallOfFameThreshold": 70,
            "hallOfFameCount": aggregate.hallOfFameCount,
            "hallOfFameRatePermille": aggregate.hallOfFameRatePermille,
            "representativeSeed100": sample(sortedRuns[100])
        ]
        let completionSummary: [String: Any] = [
            "completedCount": aggregate.completedCount,
            "incompleteCount": aggregate.incompleteCount,
            "completionRatePermille": aggregate.completionRatePermille,
            "finalPhaseDistribution": aggregate.finalPhaseDistribution,
            "completedSeasonsDistribution": aggregate.completedSeasonsDistribution,
            "failureReasons": aggregate.failureReasons,
            "representativeSeed100": sample(sortedRuns[100]),
            "v1GoldenCurrentNextSeed": v1Evidence
        ]

        let documents: [(String, [String: Any])] = [
            ("contract-lifecycle.json", document(metric: "contract_lifecycle", metadata: metadata, summary: contractSummary, checks: baseChecks)),
            ("team-tenure.json", document(metric: "team_tenure", metadata: metadata, summary: teamSummary, checks: baseChecks)),
            ("hall-of-fame.json", document(metric: "hall_of_fame", metadata: metadata, summary: hallSummary, checks: baseChecks)),
            ("career-completion.json", document(metric: "career_completion", metadata: metadata, summary: completionSummary, checks: baseChecks))
        ]

        var fileHashes: [String: String] = [:]
        for (filename, value) in documents {
            let data = try prettyJSON(value)
            try data.write(to: outputDirectory.appendingPathComponent(filename), options: .atomic)
            fileHashes[filename] = sha256Hex(data)
        }
        let manifest = fileHashes.keys.sorted().map { $0 + " " + (fileHashes[$0] ?? "") }.joined(separator: "\n") + "\n"
        let manifestHash = sha256Hex(Data(manifest.utf8))
        let readme = makeReadme(
            sourceRevision: sourceRevision,
            dirtyWorktree: dirtyWorktree,
            elapsedSeconds: elapsedSeconds,
            runDigest: runDigest,
            manifestHash: manifestHash,
            fileHashes: fileHashes,
            v1Evidence: v1Evidence
        )
        try Data(readme.utf8).write(to: outputDirectory.appendingPathComponent("README.md"), options: .atomic)
    }

    private struct Aggregate {
        var contractObservations = 0
        var contractBySeason = [[String: Int]](repeating: [:], count: seasonsPerCareer)
        var minimumContractYears = Int.max
        var maximumContractYears = Int.min
        var careersWithZeroContract = 0
        var careersAtContractFloorAtFinalSeason = 0
        var teamSeasonObservations = 0
        var teamSeasonCounts: [String: Int] = [:]
        var distinctTeamsPerCareer: [String: Int] = [:]
        var teamSwitchesPerCareer: [String: Int] = [:]
        var maximumSingleTeamTenure: [String: Int] = [:]
        var freeAgencyTeamTransitions = 0
        var unexpectedTeamTransitions = 0
        var finalTeamDistribution: [String: Int] = [:]
        var hallScores: [Int] = []
        var hallScoreHistogram: [String: Int] = [:]
        var minimumHallScore = 0
        var maximumHallScore = 0
        var meanHallScorePermille = 0
        var hallOfFameCount = 0
        var hallOfFameRatePermille = 0
        var completedCount = 0
        var incompleteCount = 0
        var completionRatePermille = 0
        var finalPhaseDistribution: [String: Int] = [:]
        var completedSeasonsDistribution: [String: Int] = [:]
        var failureReasons: [String: Int] = [:]
    }

    private static func summarize(_ runs: [Wave0BaselineRun]) -> Aggregate {
        var aggregate = Aggregate()
        for run in runs {
            increment(&aggregate.finalPhaseDistribution, run.finalPhase)
            increment(&aggregate.completedSeasonsDistribution, String(run.completedSeasons))
            if let error = run.error {
                aggregate.incompleteCount += 1
                increment(&aggregate.failureReasons, error)
            } else if run.finalPhase == ProCareerPhase.completed.rawValue,
                      run.completedSeasons == seasonsPerCareer {
                aggregate.completedCount += 1
            } else {
                aggregate.incompleteCount += 1
            }

            for (seasonIndex, years) in run.contractYears.enumerated() where seasonIndex < seasonsPerCareer {
                aggregate.contractObservations += 1
                increment(&aggregate.contractBySeason[seasonIndex], String(years))
                aggregate.minimumContractYears = min(aggregate.minimumContractYears, years)
                aggregate.maximumContractYears = max(aggregate.maximumContractYears, years)
            }
            if run.contractYears.contains(where: { $0 <= 0 }) { aggregate.careersWithZeroContract += 1 }
            if run.contractYears.last == 1 { aggregate.careersAtContractFloorAtFinalSeason += 1 }

            aggregate.teamSeasonObservations += run.teamSequence.count
            for teamID in run.teamSequence { increment(&aggregate.teamSeasonCounts, teamID) }
            increment(&aggregate.distinctTeamsPerCareer, String(Set(run.teamSequence).count))
            let switches = zip(run.teamSequence, run.teamSequence.dropFirst()).enumerated().filter { $0.element.0 != $0.element.1 }.count
            increment(&aggregate.teamSwitchesPerCareer, String(switches))
            increment(&aggregate.maximumSingleTeamTenure, String(maximumConsecutiveTeamSeasons(run.teamSequence)))
            if let finalTeam = run.teamSequence.last { increment(&aggregate.finalTeamDistribution, finalTeam) }
            for (previous, next) in zip(run.teamSequence, run.teamSequence.dropFirst()) where previous != next {
                aggregate.freeAgencyTeamTransitions += 1
                let previousIndex = ProCareerEngine.proTeams.firstIndex { $0.id == previous } ?? -100
                let expectedIndex = (previousIndex + 3) % ProCareerEngine.proTeams.count
                if ProCareerEngine.proTeams[expectedIndex].id != next {
                    aggregate.unexpectedTeamTransitions += 1
                }
            }

            if let score = run.hallOfFameScore {
                aggregate.hallScores.append(score)
                increment(&aggregate.hallScoreHistogram, String(score))
                if score >= 70 { aggregate.hallOfFameCount += 1 }
            }
        }
        if aggregate.minimumContractYears == Int.max { aggregate.minimumContractYears = 0 }
        if aggregate.maximumContractYears == Int.min { aggregate.maximumContractYears = 0 }
        if let minScore = aggregate.hallScores.min(), let maxScore = aggregate.hallScores.max() {
            aggregate.minimumHallScore = minScore
            aggregate.maximumHallScore = maxScore
            aggregate.meanHallScorePermille = aggregate.hallScores.reduce(0, +) * 1_000 / max(1, aggregate.hallScores.count)
            aggregate.hallOfFameRatePermille = aggregate.hallOfFameCount * 1_000 / max(1, aggregate.hallScores.count)
        }
        aggregate.completionRatePermille = aggregate.completedCount * 1_000 / max(1, runs.count)
        return aggregate
    }

    private static func maximumConsecutiveTeamSeasons(_ sequence: [String]) -> Int {
        var best = 0
        var current = ""
        var count = 0
        for team in sequence {
            if team == current {
                count += 1
            } else {
                current = team
                count = 1
            }
            best = max(best, count)
        }
        return best
    }

    private static func sample(_ run: Wave0BaselineRun) -> [String: Any] {
        [
            "seed": run.seed,
            "startNextSeed": run.startNextSeed ?? "unavailable",
            "signedNextSeed": run.signedNextSeed ?? "unavailable",
            "firstWeekNextSeed": run.firstWeekNextSeed ?? "unavailable",
            "finalNextSeed": run.finalNextSeed ?? "unavailable",
            "teamSequence": run.teamSequence,
            "contractYearsAtSeasonStart": run.contractYears,
            "hallOfFameScore": run.hallOfFameScore.map { $0 } ?? NSNull(),
            "finalPhase": run.finalPhase,
            "completedSeasons": run.completedSeasons,
            "error": run.error ?? "none"
        ]
    }

    private static func digestRuns(_ runs: [Wave0BaselineRun]) -> String {
        var hasher = SHA256()
        for run in runs {
            let row = [
                String(run.seed),
                run.error == nil ? "ok" : "failed",
                run.startNextSeed ?? "-",
                run.signedNextSeed ?? "-",
                run.firstWeekNextSeed ?? "-",
                run.finalNextSeed ?? "-",
                run.teamSequence.joined(separator: ","),
                run.contractYears.map(String.init).joined(separator: ","),
                run.hallOfFameScore.map(String.init) ?? "-",
                run.finalPhase,
                String(run.completedSeasons)
            ].joined(separator: "|") + "\n"
            hasher.update(data: Data(row.utf8))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func document(
        metric: String,
        metadata: [String: Any],
        summary: [String: Any],
        checks: [String: Any]
    ) -> [String: Any] {
        [
            "schema": "pro-career-depth-baseline-v0",
            "metric": metric,
            "metadata": metadata,
            "summary": summary,
            "checks": checks.merging(["summarySha256": sha256JSON(summary)]) { current, _ in current }
        ]
    }

    private static func sha256JSON(_ value: [String: Any]) -> String {
        guard let data = try? compactJSON(value) else { return "unavailable" }
        return sha256Hex(data)
    }

    private static func prettyJSON(_ value: [String: Any]) throws -> Data {
        var data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        data.append(0x0A)
        return data
    }

    private static func compactJSON(_ value: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .withoutEscapingSlashes])
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func makeReadme(
        sourceRevision: String,
        dirtyWorktree: Bool,
        elapsedSeconds: TimeInterval,
        runDigest: String,
        manifestHash: String,
        fileHashes: [String: String],
        v1Evidence: [String: Any]
    ) -> String {
        let fileLines = fileHashes.keys.sorted().map {
            "- `" + $0 + "` — SHA-256 `" + (fileHashes[$0] ?? "") + "`"
        }.joined(separator: "\n")
        let nextSeedMatches = (v1Evidence["nextSeedMatches"] as? Bool) == true
        let nextSeedStatus = nextSeedMatches ? "MATCH" : "MISMATCH"
        let lines = [
            "# Pro career depth Wave 0 baseline",
            "",
            "This directory is the compact current-behavior evidence required by Wave 0 of `DOC-PRO-CAREER-CONTRACT-LEGACY-DEPTH-2026-08-14`.",
            "",
            "## Scope",
            "",
            "- Scenario: current Swift `ProCareerEngine`, preset `power_prospect`, initial catalog entry `proTeams[0]`.",
            "- Seeds: `0...999` (`1000` deterministic runs), `20` seasons per run.",
            "- Weekly policy: `fatigue > 72` → recover; `managerTrust < 62` → earn trust; otherwise refine command; current important games and decisions use the stable positive fixture policy.",
            "- Offseason policy: request the current free-agency path whenever `serviceYears + major-level registration >= 6`; otherwise continue; retire after season 20.",
            "- Only aggregate summaries and deterministic digests are retained. Raw runs are not stored.",
            "",
            "## Provenance and dirty-worktree caveat",
            "",
            "- Source revision: `" + sourceRevision + "`.",
            "- Worktree dirty at generation: `" + String(dirtyWorktree) + "`; it was already dirty before Wave 0.",
            "- Pre-existing changes include the independent Android Phase 10 work, iOS localization/presentation work, generated archive deletions, and shared scripts. Wave 0 did not reset, clean, stash, revert, or edit those paths. The baseline's production engine sources were read-only during generation.",
            "- Pre-change full `swift test --package-path packages/simulation-core` baseline was bounded and terminated after approximately 334 seconds (exit 143) while still progressing. It emitted no test failure before termination; focused Wave 0 core tests were therefore recorded separately. Concurrent, user-owned Android Phase 10 test processes were not stopped or modified.",
            "- Generation elapsed time: approximately `" + String(Int(elapsedSeconds.rounded())) + "` seconds on the local optimized/concurrent runner; this is timing metadata, not a distribution input.",
            "",
            "## Generation command",
            "",
            "```sh",
            generationCommand,
            "```",
            "",
            "The command reuses `packages/simulation-core/.build`; it does not create a retry-specific build directory.",
            "",
            "## v1 golden/current nextSeed evidence",
            "",
            "The committed Swift→Kotlin pro fixture `" + committedV1Fixture + "` was read without modification. Twenty rows (`100...119`) were regenerated from the current Swift core and compared on `startNextSeed`, `signedNextSeed`, and `firstWeekNextSeed`: `" + nextSeedStatus + "`. The JSON summary records the golden/current output hashes and boundary samples.",
            "",
            "- Run digest: `" + runDigest + "`.",
            "- Evidence manifest SHA-256 (the four JSON files): `" + manifestHash + "`.",
            "",
            "## Evidence files",
            "",
            fileLines,
            "",
            "## Checks",
            "",
            "- Expected runs: `1000`; expected seasons per run: `20`.",
            "- Contract floor observations at or below zero: recorded in `contract-lifecycle.json` and expected to remain `0` for this current path.",
            "- Team transitions are checked against the current catalog `+3` rule in `team-tenure.json`.",
            "- Career completion, failure phases, HOF score distribution, and all integrity hashes are in the JSON files."
        ]
        return lines.joined(separator: "\n") + "\n"
    }

    private static func increment(_ dictionary: inout [String: Int], _ key: String, by amount: Int = 1) {
        dictionary[key, default: 0] += amount
    }

    private static func activeEntitlement() -> ProEntitlementSnapshot {
        .init(status: .active, source: .development, verifiedAt: "2026-07-22", offlineValidUntil: "2026-08-22")
    }

    private static func drafted(team: DraftTeamSnapshot) -> DraftResultSnapshot {
        .init(
            outcome: .drafted,
            evaluationScore: 72,
            projectedRange: "2~3라운드",
            team: team,
            round: 2,
            overallPick: 18,
            signingBonus: 120_000_000,
            firstSeasonGoal: "2군 선발",
            summary: "지명"
        )
    }

    private static func positiveReport(week: Int) -> ImportantInningReport {
        .init(scenarioNumber: week, pitches: 18, strikeouts: 2, walks: 0, runsAllowed: 0, expectedDamage: 380, actualDamage: 240, recommendationAccepted: 12)
    }

    private static func stableChoiceOrder(_ lhs: ProSeasonDecisionChoice, _ rhs: ProSeasonDecisionChoice) -> Bool {
        if lhs.effect.fatigueDelta != rhs.effect.fatigueDelta {
            return lhs.effect.fatigueDelta < rhs.effect.fatigueDelta
        }
        return lhs.id < rhs.id
    }
}

private enum XCTJSON {
    static func object(from data: Data) throws -> [String: Any] {
        try object(value: JSONSerialization.jsonObject(with: data))
    }

    static func object(value: Any?) throws -> [String: Any] {
        guard let value = value as? [String: Any] else {
            throw Wave0BaselineError(description: "expected JSON object")
        }
        return value
    }

    static func arrayOfObjects(value: Any?) throws -> [[String: Any]] {
        guard let values = value as? [[String: Any]] else {
            throw Wave0BaselineError(description: "expected JSON object array")
        }
        return values
    }
}

private extension Dictionary where Key == String, Value == Any {
    func filtered(keys: [String]) -> [String: Any] {
        keys.reduce(into: [String: Any]()) { result, key in
            if let value = self[key] { result[key] = value }
        }
    }
}
