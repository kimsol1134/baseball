import XCTest
@testable import SimulationCore

final class ProCareerArcTests: XCTestCase {
    func testSeasonOneMajorSkillDoesNotTrack() {
        XCTAssertEqual(
            DifficultyScale.trackingBonus(season: 1, level: .major, skill: 70),
            0
        )
        let offset = DifficultyScale.proArc(season: 1, level: .major, skill: 70, climate: .even)
        XCTAssertEqual(offset, DifficultyScale.pro(season: 1))
    }

    func testSeasonEightMajorSkillTracksAboveSeasonStair() {
        let stair = DifficultyScale.pro(season: 8)
        let tracked = DifficultyScale.proArc(season: 8, level: .major, skill: 70, climate: .even)
        XCTAssertGreaterThan(tracked, stair)
        XCTAssertEqual(tracked, stair + min(6, (70 - 58) / 3))
    }

    func testMinorLeagueNeverTracks() {
        XCTAssertEqual(
            DifficultyScale.trackingBonus(season: 8, level: .minor, skill: 72),
            0
        )
    }

    func testClimateIsDeterministic() {
        let first = ProSeasonClimateRules.climate(careerID: "arc-1", season: 6, week: 9)
        let second = ProSeasonClimateRules.climate(careerID: "arc-1", season: 6, week: 9)
        XCTAssertEqual(first, second)
        let block = ProSeasonClimateRules.slumpBlock(careerID: "arc-1", season: 6)
        XCTAssertGreaterThanOrEqual(block.count, 2)
        XCTAssertLessThanOrEqual(block.count, 4)
        XCTAssertEqual(
            ProSeasonClimateRules.climate(careerID: "arc-1", season: 6, week: block.lowerBound),
            .slump
        )
    }

    func testStabilizedClimateIsEven() {
        let block = ProSeasonClimateRules.slumpBlock(careerID: "arc-2", season: 7)
        XCTAssertEqual(
            ProSeasonClimateRules.climate(
                careerID: "arc-2",
                season: 7,
                week: block.lowerBound,
                stabilizeCharges: 2
            ),
            .even
        )
    }

    func testPerfectCallPolicyMatchesLegacyLine() {
        let pitcher = PitcherPresetCatalog.all[0].pitcher
        let seed: UInt64 = 9_913_377
        let perfect = AutoOutingSimulator().simulate(
            pitcher: pitcher,
            startingFatigue: 8,
            outsTarget: 18,
            pitchCap: 96,
            batterOffset: 3,
            callPolicy: .perfect,
            baseSeed: seed
        )
        let defaulted = AutoOutingSimulator().simulate(
            pitcher: pitcher,
            startingFatigue: 8,
            outsTarget: 18,
            pitchCap: 96,
            batterOffset: 3,
            baseSeed: seed
        )
        XCTAssertEqual(perfect, defaulted)
    }

    func testNewCareerUsesArcAndAutumnRules() throws {
        let engine = ProCareerEngine(journeyEnabled: true)
        let started = try engine.start(startParams(seed: "991001"))
        XCTAssertEqual(started.snapshot.proRulesVersion, 9)
        XCTAssertTrue(ProCareerEngine.usesCareerArcRules(started.snapshot))
        XCTAssertTrue(ProCareerEngine.usesAutumnRules(started.snapshot))
        XCTAssertTrue(ProCareerEngine.usesChallengeRules(started.snapshot))
    }

    func testFormCrisisReplacesDecisionDuringSlump() throws {
        let engine = ProCareerEngine(journeyEnabled: true)
        let started = try engine.start(startParams(seed: "991003"))
        let slumpReady = try unsignedSnapshot(engine, started.snapshot) { object in
            object["season"] = 6
            object["managerTrust"] = 40
            object["level"] = ProLevel.major.rawValue
            object["proRulesVersion"] = 6
        }
        let decision = engine.seasonDecision(for: slumpReady, week: 13, climate: .slump, trust: 40)
        XCTAssertEqual(decision?.type, .formCrisis)
    }

    func testV4RulesStayOnSeasonStair() throws {
        let engine = ProCareerEngine(journeyEnabled: true)
        let started = try engine.start(startParams(seed: "991002"))
        let v4 = try unsignedSnapshot(engine, started.snapshot) { object in
            object["proRulesVersion"] = 4
        }
        XCTAssertFalse(ProCareerEngine.usesCareerArcRules(v4))
        XCTAssertFalse(ProCareerEngine.usesAutumnRules(v4))
        XCTAssertEqual(ProCareerEngine.liveBatterOffset(for: v4, week: 8), DifficultyScale.pro(season: v4.season))
    }

    private func startParams(seed: String) -> StartProCareerParams {
        .init(
            seed: seed,
            identity: .defaultPitcher,
            pitcher: .init(id: "arc-pitcher", name: "Arc", stuff: 70, command: 68, movement: 67, stamina: 66),
            draftResult: .init(
                outcome: .drafted,
                evaluationScore: 72,
                projectedRange: "2~3라운드",
                team: ProCareerEngine.proTeams[0],
                round: 2,
                overallPick: 18,
                signingBonus: 120_000_000,
                firstSeasonGoal: "2군 선발",
                summary: "지명"
            ),
            entitlement: .init(status: .active, source: .development, verifiedAt: "2026-08-20")
        )
    }

    private func unsignedSnapshot(
        _ engine: ProCareerEngine,
        _ snapshot: ProCareerSnapshot,
        mutate: (inout [String: Any]) throws -> Void
    ) throws -> ProCareerSnapshot {
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as! [String: Any]
        try mutate(&object)
        let decoded = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: try JSONSerialization.data(withJSONObject: object)
        )
        return engine.replacing(decoded, commitment: engine.commitment(decoded))
    }
}
