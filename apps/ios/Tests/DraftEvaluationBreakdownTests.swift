import XCTest
import SimulationCore
@testable import BaseballIOS

final class DraftEvaluationBreakdownTests: XCTestCase {
    func testUndraftedFixtureComponentsSumToEvaluationScore() throws {
        let result = try playToResolvedDraft(
            seed: "17",
            presetID: "precision_commander",
            schoolID: .miraeAnalytics,
            intensity: .light,
            strikeouts: 0,
            walks: 5,
            runsAllowed: 7,
            expectedDamage: 1_200,
            actualDamage: 4_500
        )
        let draft = try XCTUnwrap(result.snapshot.draftResult)
        XCTAssertEqual(draft.outcome, .undrafted)
        let breakdown = HighSchoolCareerEngine.draftEvaluationBreakdown(state: result.snapshot)
        XCTAssertEqual(
            breakdown.items.reduce(0) { $0 + $1.points },
            breakdown.total,
            "chip points must sum to the breakdown total"
        )
        XCTAssertEqual(breakdown.total, draft.evaluationScore)
        XCTAssertGreaterThan(breakdown.threshold, draft.evaluationScore)
        XCTAssertFalse(breakdown.items.filter { $0.id == "rating" }.isEmpty)
    }

    func testDraftedFixtureComponentsSumToEvaluationScore() throws {
        let result = try playToResolvedDraft(
            seed: "20260723",
            presetID: "power_prospect",
            schoolID: .haedongPower,
            intensity: .intensive,
            strikeouts: 4,
            walks: 0,
            runsAllowed: 0,
            expectedDamage: 380,
            actualDamage: 120,
            focus: .velocity
        )
        let draft = try XCTUnwrap(result.snapshot.draftResult)
        XCTAssertEqual(draft.outcome, .drafted)
        let breakdown = HighSchoolCareerEngine.draftEvaluationBreakdown(state: result.snapshot)
        XCTAssertEqual(
            breakdown.items.reduce(0) { $0 + $1.points },
            breakdown.total
        )
        XCTAssertEqual(breakdown.total, draft.evaluationScore)
        XCTAssertGreaterThanOrEqual(draft.evaluationScore, breakdown.threshold)
    }

    private func playToResolvedDraft(
        seed: String,
        presetID: String,
        schoolID: SchoolID,
        intensity: TrainingIntensity,
        strikeouts: Int,
        walks: Int,
        runsAllowed: Int,
        expectedDamage: Int,
        actualDamage: Int,
        focus: TrainingFocus? = nil
    ) throws -> HighSchoolCareerResult {
        let engine = HighSchoolCareerEngine()
        var fixture = try engine.start(.init(
            seed: seed,
            presetID: presetID,
            identity: PlayerIdentitySnapshot(
                name: "테스트", throwingHand: .right, bodyType: .balanced, region: "서울"
            )
        ))
        fixture = try engine.completePrologue(.init(seed: fixture.nextSeed, state: fixture.snapshot))
        fixture = try engine.chooseSchool(.init(
            seed: fixture.nextSeed, state: fixture.snapshot, schoolID: schoolID
        ))
        for _ in 0..<100 {
            switch fixture.snapshot.phase {
            case .training:
                fixture = try engine.commitTraining(.init(
                    seed: fixture.nextSeed,
                    state: fixture.snapshot,
                    focus: focus ?? fixture.snapshot.school?.strength ?? .command,
                    intensity: intensity
                ))
            case .relationship:
                fixture = try engine.resolveRelationship(.init(
                    seed: fixture.nextSeed, state: fixture.snapshot, response: .listen
                ))
            case .importantGame:
                let number = fixture.snapshot.performance.importantGamesCompleted + 1
                fixture = try engine.recordImportantGame(.init(
                    seed: fixture.nextSeed,
                    state: fixture.snapshot,
                    report: .init(
                        scenarioNumber: number,
                        pitches: 18,
                        strikeouts: strikeouts,
                        walks: walks,
                        runsAllowed: runsAllowed,
                        expectedDamage: expectedDamage,
                        actualDamage: actualDamage,
                        recommendationAccepted: strikeouts > 0 ? 10 : 0,
                        outs: 3
                    )
                ))
            case .awakening:
                let awakening = try XCTUnwrap(fixture.snapshot.awakeningOptions.first)
                fixture = try engine.chooseAwakening(.init(
                    seed: fixture.nextSeed, state: fixture.snapshot, awakening: awakening
                ))
            case .chapterReview:
                fixture = try engine.advanceChapter(.init(
                    seed: fixture.nextSeed, state: fixture.snapshot
                ))
            case .draft:
                return try engine.resolveDraft(.init(
                    seed: fixture.nextSeed, state: fixture.snapshot
                ))
            case .legacy, .completed, .prologue, .schoolSelection:
                XCTFail("unexpected phase \(fixture.snapshot.phase)")
                return fixture
            }
        }
        XCTFail("did not reach draft")
        return fixture
    }
}
