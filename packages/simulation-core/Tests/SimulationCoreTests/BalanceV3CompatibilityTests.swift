import Foundation
import XCTest
@testable import SimulationCore

final class BalanceV3CompatibilityTests: XCTestCase {
    func testProV3NormalizationIsIdentityAndKeepsTheNextStepExact() throws {
        let engine = ProCareerEngine()
        let weekly = try weeklyPlanState(engine: engine, seed: "731001")
        let v3 = try rewriting(weekly.snapshot, engine: engine) { object in
            object["balanceVersion"] = 3
        }

        let normalized = try engine.normalizeBalance(.init(seed: weekly.nextSeed, state: v3))
        XCTAssertEqual(normalized.snapshot, v3)
        XCTAssertEqual(normalized.nextSeed, weekly.nextSeed)

        let direct = try engine.planWeek(.init(
            seed: weekly.nextSeed, state: v3, plan: .recover
        ))
        let afterLoad = try engine.planWeek(.init(
            seed: normalized.nextSeed, state: normalized.snapshot, plan: .recover
        ))
        XCTAssertEqual(afterLoad, direct)
    }

    func testProV3DoesNotGenerateNewSeasonDecisionButPersistedChoiceStillApplies() throws {
        let engine = ProCareerEngine()
        let weekly = try weeklyPlanState(engine: engine, seed: "731002")
        var opened: (state: ProCareerSnapshot, seed: String, result: ProCareerResult)?
        search: for decisionWeek in ProCareerEngine.seasonDecisionWeeks {
            let candidate = try rewriting(weekly.snapshot, engine: engine) { object in
                object["week"] = decisionWeek - 1
            }
            for seedValue in 731_102..<731_132 {
                let seed = String(seedValue)
                let result = try engine.planWeek(.init(
                    seed: seed, state: candidate, plan: .recover
                ))
                if result.snapshot.phase == .seasonDecision {
                    opened = (candidate, seed, result)
                    break search
                }
            }
        }
        let current = try XCTUnwrap(opened)
        let decisionWeekV3 = try rewriting(current.state, engine: engine) { object in
            object["balanceVersion"] = 3
        }

        let legacyProgress = try engine.planWeek(.init(
            seed: current.seed, state: decisionWeekV3, plan: .recover
        ))
        XCTAssertNotEqual(legacyProgress.snapshot.phase, .seasonDecision)
        XCTAssertNil(legacyProgress.snapshot.pendingDecision)

        let pending = try XCTUnwrap(current.result.snapshot.pendingDecision)
        let persistedV3 = try rewriting(current.result.snapshot, engine: engine) { object in
            object["balanceVersion"] = 3
        }
        let choice = try XCTUnwrap(pending.choices.first)
        let applied = try engine.applySeasonDecision(.init(
            seed: current.result.nextSeed,
            state: persistedV3,
            decisionID: pending.id,
            choiceID: choice.id
        ))
        XCTAssertEqual(applied.snapshot.phase, .weeklyPlan)
        XCTAssertNil(applied.snapshot.pendingDecision)
        XCTAssertEqual(applied.snapshot.decisionHistory?.last?.decisionID, pending.id)
        XCTAssertEqual(applied.snapshot.decisionHistory?.last?.choiceID, choice.id)
        XCTAssertEqual(applied.snapshot.balanceVersion, 3)
    }

    func testProV3SequenceMasteryDoesNotAddTrust() throws {
        let engine = ProCareerEngine()
        let weekly = try weeklyPlanState(engine: engine, seed: "731003")
        let importantV4 = try rewriting(weekly.snapshot, engine: engine) { object in
            object["phase"] = ProCareerPhase.importantGame.rawValue
        }
        let importantV3 = try rewriting(importantV4, engine: engine) { object in
            object["balanceVersion"] = 3
        }
        let report = ImportantInningReport(
            scenarioNumber: 1,
            pitches: 12,
            strikeouts: 2,
            walks: 0,
            runsAllowed: 1,
            expectedDamage: 500,
            actualDamage: 300,
            recommendationAccepted: 9,
            outs: 3,
            sequenceMasteryCount: 3
        )
        let legacy = try engine.resolveImportantGame(.init(
            seed: "731203", state: importantV3, report: report
        ))
        let current = try engine.resolveImportantGame(.init(
            seed: "731203", state: importantV4, report: report
        ))

        XCTAssertEqual(current.snapshot.managerTrust - legacy.snapshot.managerTrust, 3)
        XCTAssertEqual(current.snapshot.catcherTrust - legacy.snapshot.catcherTrust, 3)
        XCTAssertFalse(legacy.snapshot.news.first?.contains("수싸움 적중") ?? false)
        XCTAssertTrue(current.snapshot.news.first?.contains("수싸움 적중") ?? false)
    }

    private func weeklyPlanState(
        engine: ProCareerEngine,
        seed: String
    ) throws -> ProCareerResult {
        let team = try XCTUnwrap(HighSchoolCareerEngine.teams.first)
        let draft = DraftResultSnapshot(
            outcome: .drafted,
            evaluationScore: 70,
            projectedRange: "2~3라운드",
            team: team,
            round: 2,
            overallPick: 15,
            signingBonus: 150_000_000,
            firstSeasonGoal: "프로 첫 시즌",
            summary: "지명"
        )
        let started = try engine.start(.init(
            seed: seed,
            identity: .defaultPitcher,
            pitcher: PitcherPresetCatalog.all[0].pitcher,
            draftResult: draft,
            entitlement: .init(
                status: .active,
                source: .development,
                verifiedAt: "2026-08-09T00:00:00Z"
            )
        ))
        return try engine.signContract(.init(seed: started.nextSeed, state: started.snapshot))
    }

    private func rewriting(
        _ state: ProCareerSnapshot,
        engine: ProCareerEngine,
        mutate: (inout [String: Any]) -> Void
    ) throws -> ProCareerSnapshot {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(state)) as? [String: Any]
        )
        mutate(&object)
        object["commitment"] = ""
        let unsigned = try decoder.decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        object["commitment"] = engine.commitment(unsigned)
        return try decoder.decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }
}
