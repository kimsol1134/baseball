import CryptoKit
import Foundation
import SimulationCore

private let fixtureSchema = "baseball-pro-career-fixture-v1"
private let sourceCommit = "792d72859dc5dcfdc8cefa8b69ab50bc072c212f"
private let defaultOutput = "artifacts/android-compose/fixtures/swift-pro-career-oracle-v1.json"

private struct Row {
    let seed: String
    let careerID: String
    let startNextSeed: String
    let teamID: String
    let signedRevision: Int
    let signedNextSeed: String
    let firstWeekNextSeed: String
    let firstWeek: [Int]
    let phase: String
    let level: String
    let role: String
    let segment: String
    let decisionWeeks: [Int]
    let maximumCareerSeasons: Int
    let maximumSeasonDecisions: Int
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

private func json(_ values: [Int]) -> String {
    "[" + values.map(String.init).joined(separator: ",") + "]"
}

private func canonicalRow(_ row: Row) -> String {
    [
        row.seed, row.careerID, row.startNextSeed, row.teamID,
        String(row.signedRevision), row.signedNextSeed, row.firstWeekNextSeed,
        row.firstWeek.map(String.init).joined(separator: ","), row.phase, row.level,
        row.role, row.segment, row.decisionWeeks.map(String.init).joined(separator: ","),
        String(row.maximumCareerSeasons), String(row.maximumSeasonDecisions)
    ].joined(separator: "|") + "\n"
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

private func run(seed: String) throws -> Row {
    let engine = ProCareerEngine()
    guard let preset = PitcherPresetCatalog.all.first(where: { $0.id == "power_prospect" }) else {
        throw NSError(domain: "ProFixture", code: 1)
    }
    let pitcher = preset.pitcher
    let team = ProCareerEngine.proTeams[0]
    var result = try engine.start(.init(
        seed: seed,
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
    let firstWeek = result.snapshot.currentStats
    return Row(
        seed: seed,
        careerID: start.proCareerID,
        startNextSeed: startNextSeed,
        teamID: start.team.id,
        signedRevision: Int(signed.revision),
        signedNextSeed: signedNextSeed,
        firstWeekNextSeed: String(result.nextSeed),
        firstWeek: [
            firstWeek.games, firstWeek.starts, firstWeek.inningsOuts, firstWeek.strikeouts,
            firstWeek.walks, firstWeek.runsAllowed, firstWeek.hits, firstWeek.pitches
        ],
        phase: result.snapshot.phase.rawValue,
        level: result.snapshot.level.rawValue,
        role: result.snapshot.role.rawValue,
        segment: result.snapshot.seasonSegment?.rawValue ?? "none",
        decisionWeeks: ProCareerEngine.seasonDecisionWeeks,
        maximumCareerSeasons: ProCareerEngine.maximumCareerSeasons,
        maximumSeasonDecisions: ProCareerEngine.maximumSeasonDecisions
    )
}

private struct Wave3MarketRow {
    let seed: String
    let kind: ProContractMarketKind
    let careerID: String
    let forSeason: Int
    let generatedAtRevision: UInt64
    let currentTeamID: String
    let currentRole: ProRole
    let level: ProLevel
    let marketScore: Int
    let serviceYears: Int
    let age: Int
    let maximumCareerSeasons: Int
    let market: ProContractMarket
}

private func wave3OfferCanonical(_ offer: ProContractOffer) -> String {
    [
        offer.id, offer.teamID, String(offer.years), String(offer.annualSalary),
        offer.contractKind.rawValue, offer.rolePromise.rawValue, offer.outlook.rawValue,
        offer.expectation.kind.rawValue, String(offer.expectation.target), offer.expectation.difficulty.rawValue,
        String(offer.preservesTeamLegacy)
    ].joined(separator: ":")
}

private func wave3RowCanonical(_ row: Wave3MarketRow) -> String {
    [
        row.seed, row.kind.rawValue, row.careerID, String(row.forSeason), String(row.generatedAtRevision),
        row.currentTeamID, row.currentRole.rawValue, row.level.rawValue, String(row.marketScore),
        String(row.serviceYears), String(row.age), String(row.maximumCareerSeasons), row.market.id,
        row.market.offers.map(wave3OfferCanonical).joined(separator: ";")
    ].joined(separator: "|") + "\n"
}

private func wave3OfferJSON(_ offer: ProContractOffer) -> String {
    let expectation = "{\"kind\":\(json(offer.expectation.kind.rawValue)),\"target\":\(offer.expectation.target),\"difficulty\":\(json(offer.expectation.difficulty.rawValue))}"
    let signingBonus = offer.signingBonus.map(String.init) ?? "null"
    return "{\"id\":\(json(offer.id)),\"teamID\":\(json(offer.teamID)),\"years\":\(offer.years),\"annualSalary\":\(offer.annualSalary),\"signingBonus\":\(signingBonus),\"contractKind\":\(json(offer.contractKind.rawValue)),\"rolePromise\":\(json(offer.rolePromise.rawValue)),\"outlook\":\(json(offer.outlook.rawValue)),\"expectation\":\(expectation),\"preservesTeamLegacy\":\(offer.preservesTeamLegacy) }"
}

private func writeWave3MarketFixture(to path: String) throws {
    let pitcher = PitcherSnapshot(
        id: "wave3-fixture-pitcher",
        name: "Wave 3 Fixture",
        stuff: 64,
        command: 59,
        movement: 61,
        stamina: 63
    )
    let cases: [(kind: ProContractMarketKind, seed: String, teamIndex: Int, score: Int, season: Int, revision: UInt64, role: ProRole, level: ProLevel, service: Int, age: Int)] = [
        (.renewal, "3001", 0, 0, 4, 12, .starter, .minor, 3, 22),
        (.renewal, "3002", 3, 35, 8, 18, .longRelief, .major, 7, 26),
        (.renewal, "3003", 6, 65, 15, 24, .setup, .major, 14, 33),
        (.renewal, "3004", 9, 100, 19, 30, .closer, .major, 18, 37),
        (.freeAgency, "3005", 1, 20, 5, 14, .starter, .minor, 5, 23),
        (.freeAgency, "3006", 4, 50, 10, 20, .longRelief, .major, 10, 28),
        (.freeAgency, "3007", 7, 80, 16, 26, .setup, .major, 16, 34),
        (.freeAgency, "3008", 2, 100, 19, 31, .closer, .major, 19, 38),
    ]
    let maximumCareerSeasons = ProCareerEngine.maximumCareerSeasons
    let rows = try cases.map { item -> Wave3MarketRow in
        let team = ProCareerEngine.proTeams[item.teamIndex]
        let previousStats = ProSeasonStats(
            season: max(1, item.season - 1),
            teamID: team.id,
            games: 28,
            starts: item.role == .starter ? 22 : 4,
            inningsOuts: item.role == .starter ? 420 : 135,
            strikeouts: 150,
            walks: 36,
            runsAllowed: 58,
            saves: item.role == .closer ? 21 : 0
        )
        let market: ProContractMarket?
        switch item.kind {
        case .renewal:
            market = ProContractMarketRules.makeRenewalMarket(
                careerID: "fixture-wave3-\(item.seed)",
                team: team,
                pitcher: pitcher,
                level: item.level,
                role: item.role,
                previousStats: previousStats,
                marketScore: item.score,
                forSeason: item.season,
                generatedAtRevision: item.revision,
                maximumCareerSeasons: maximumCareerSeasons
            )
        case .freeAgency:
            market = ProContractMarketRules.makeFreeAgencyMarket(
                careerID: "fixture-wave3-\(item.seed)",
                currentTeam: team,
                pitcher: pitcher,
                level: item.level,
                role: item.role,
                previousStats: previousStats,
                marketScore: item.score,
                fanSupport: min(100, 20 + item.score / 2),
                forSeason: item.season,
                generatedAtRevision: item.revision,
                maximumCareerSeasons: maximumCareerSeasons
            )
        case .rookie:
            market = nil
        }
        guard let market else { throw NSError(domain: "ProContractWave3Fixture", code: 2) }
        return Wave3MarketRow(
            seed: item.seed,
            kind: item.kind,
            careerID: "fixture-wave3-\(item.seed)",
            forSeason: item.season,
            generatedAtRevision: item.revision,
            currentTeamID: team.id,
            currentRole: item.role,
            level: item.level,
            marketScore: item.score,
            serviceYears: item.service,
            age: item.age,
            maximumCareerSeasons: maximumCareerSeasons,
            market: market
        )
    }
    let inputCanonical = [
        "ProContractMarketRules.Wave3", "kinds:renewal,free_agency", "seeds:3001..3008",
        "teams:proTeams[0,3,6,9,1,4,7,2]", "scores:0,35,65,100,20,50,80,100",
        "forSeasons:4,8,15,19,5,10,16,19", "maximumCareerSeasons:20", "locale:ko-KR", "timezone:Asia/Seoul"
    ].joined(separator: "|")
    let outputCanonical = rows.map(wave3RowCanonical).joined()
    var output = """
    {
      "fixtureSchema": "baseball-pro-career-contract-wave3-fixture-v1",
      "sourceRuntime": "swift",
      "sourceCommit": \(json(sourceCommit)),
      "inputSha256": \(json(sha256(inputCanonical))),
      "outputSha256": \(json(sha256(outputCanonical))),
      "authorityScope": "swift-wave3-market-rules-only",
      "input": {
        "fixture": "ProContractMarketRules.Wave3",
        "kinds": ["renewal", "free_agency"],
        "seedRange": "3001..3008",
        "maximumCareerSeasons": 20,
        "locale": "ko-KR",
        "timezone": "Asia/Seoul"
      },
      "expected": {
        "exactRuns": 8,
        "canonicalRow": "seed|kind|careerID|forSeason|generatedAtRevision|currentTeamID|currentRole|level|marketScore|serviceYears|age|maximumCareerSeasons|marketID|offers\\n",
        "rows": [
    """
    for (index, row) in rows.enumerated() {
        let offers = row.market.offers.map(wave3OfferJSON).joined(separator: ",")
        output += "        {\"seed\":\(json(row.seed)),\"kind\":\(json(row.kind.rawValue)),\"careerID\":\(json(row.careerID)),\"forSeason\":\(row.forSeason),\"generatedAtRevision\":\(row.generatedAtRevision),\"currentTeamID\":\(json(row.currentTeamID)),\"currentRole\":\(json(row.currentRole.rawValue)),\"level\":\(json(row.level.rawValue)),\"marketScore\":\(row.marketScore),\"serviceYears\":\(row.serviceYears),\"age\":\(row.age),\"maximumCareerSeasons\":\(row.maximumCareerSeasons),\"marketID\":\(json(row.market.id)),\"offers\":[\(offers)]}"
        output += index == rows.count - 1 ? "\n" : ",\n"
    }
    output += """
        ]
      }
    }
    """
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try output.write(to: url, atomically: true, encoding: .utf8)
}

let outputPath = ProcessInfo.processInfo.environment["BASEBALL_PRO_ORACLE_OUTPUT"] ?? defaultOutput
let seeds = (100..<120).map(String.init)
private let rows = try seeds.map(run)
let inputCanonical = [
    "ProCareerEngine.Phase5Vertical",
    "start:linked", "preset:power_prospect", "team:proTeams[0]", "draftEvaluation:72",
    "entitlement:active", "postStart:signContract", "week1:earnTrust",
    "decisionWeeks:6,13,20", "maximumCareerSeasons:20", "maximumSeasonDecisions:3",
    "seeds:100..119", "locale:ko-KR", "timezone:Asia/Seoul"
].joined(separator: "|")
let outputCanonical = rows.map(canonicalRow).joined()

var output = """
{
  "fixtureSchema": \(json(fixtureSchema)),
  "sourceRuntime": "swift",
  "sourceCommit": \(json(sourceCommit)),
  "inputSha256": \(json(sha256(inputCanonical))),
  "outputSha256": \(json(sha256(outputCanonical))),
  "authorityScope": "current-swift-pro-core-vertical",
  "input": {
    "fixture": "ProCareerEngine.Phase5Vertical",
    "start": "linked",
    "preset": "power_prospect",
    "team": "proTeams[0]",
    "postStart": ["signContract", "planWeek:earnTrust"],
    "decisionWeeks": [6, 13, 20],
    "maximumCareerSeasons": 20,
    "maximumSeasonDecisions": 3,
    "seedRange": "100..119",
    "locale": "ko-KR",
    "timezone": "Asia/Seoul"
  },
  "expected": {
    "exactRuns": 20,
    "canonicalRow": "seed|careerID|startNextSeed|teamID|signedRevision|signedNextSeed|firstWeekNextSeed|firstWeekStats|phase|level|role|segment|decisionWeeks|maximumCareerSeasons|maximumSeasonDecisions\\n",
    "rows": [
"""
for (index, row) in rows.enumerated() {
    output += "      {\"seed\":\(json(row.seed)),\"careerID\":\(json(row.careerID)),\"startNextSeed\":\(json(row.startNextSeed)),\"teamID\":\(json(row.teamID)),\"signedRevision\":\(row.signedRevision),\"signedNextSeed\":\(json(row.signedNextSeed)),\"firstWeekNextSeed\":\(json(row.firstWeekNextSeed)),\"firstWeekStats\":\(json(row.firstWeek)),\"phase\":\(json(row.phase)),\"level\":\(json(row.level)),\"role\":\(json(row.role)),\"segment\":\(json(row.segment)),\"decisionWeeks\":\(json(row.decisionWeeks)),\"maximumCareerSeasons\":\(row.maximumCareerSeasons),\"maximumSeasonDecisions\":\(row.maximumSeasonDecisions)}"
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

if let wave3Output = ProcessInfo.processInfo.environment["BASEBALL_PRO_CONTRACT_WAVE3_OUTPUT"] {
    try writeWave3MarketFixture(to: wave3Output)
}
