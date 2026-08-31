import Foundation
import XCTest
@testable import SimulationCore

final class CompactMasteryHealthParityTests: XCTestCase {
    func testMasteryCustomDecodeDefaultsLegacyPitcherAndSaturatesGrowth() throws {
        let legacy = Data(#"{"id":"legacy","name":"구저장","stuff":80,"command":50,"movement":50,"stamina":50}"#.utf8)
        let pitcher = try JSONDecoder().decode(PitcherSnapshot.self, from: legacy)
        XCTAssertNil(pitcher.mastery)
        XCTAssertEqual(pitcher.effectiveMastery, .zero)

        let saturated = AbilityMasterySnapshot(stuff: Int.max, command: -10, movement: 3, stamina: 4)
        XCTAssertEqual(saturated.stuff, Int(AbilityMasterySnapshot.technicalMaximum))
        XCTAssertEqual(saturated.command, 0)
        XCTAssertEqual(
            saturated.adding(10, to: .stuff).stuff,
            Int(AbilityMasterySnapshot.technicalMaximum)
        )
        XCTAssertEqual(
            try JSONDecoder().decode(
                AbilityMasterySnapshot.self,
                from: JSONEncoder().encode(saturated)
            ),
            saturated
        )
    }

    func testHighSchoolTrainingRelationshipAndGameGrowthAtEightyBecomeMastery() throws {
        let pitcher = PitcherSnapshot(
            id: "eighty", name: "80 투수", stuff: 80, command: 80, movement: 80, stamina: 80
        )

        // Training, relationship rewards, and game rewards all use the same advancement rule.
        let training = PitcherGrowthRules.advance(pitcher, focus: .velocity, points: 2)
        XCTAssertEqual(training.baseBefore, 80)
        XCTAssertEqual(training.baseAfter, 80)
        XCTAssertEqual(training.masteryAfter, 2)
        let relationship = PitcherGrowthRules.advance(pitcher, focus: .command, points: 1)
        XCTAssertEqual(relationship.baseAfter, 80)
        XCTAssertEqual(relationship.masteryAfter, 1)

        let started = try HighSchoolCareerEngine().start(.init(seed: "880801", presetID: "power_prospect"))
        let state = try replacePitcherAndTalent(
            started.snapshot,
            pitcher: pitcher,
            talent: TalentSnapshot(stuff: .s, command: .s, movement: .s, stamina: .s)
        )
        let growth = CareerGameGrowth.evaluating(
            state: state,
            report: ImportantInningReport(
                scenarioNumber: 1,
                pitches: 12,
                strikeouts: 3,
                walks: 0,
                runsAllowed: 0,
                expectedDamage: 300,
                actualDamage: 200,
                recommendationAccepted: 8,
                outs: 3
            )
        )
        let game = try XCTUnwrap(growth)
        XCTAssertEqual(game.points, 1)
        let gamePitcher = game.applying(to: pitcher)
        XCTAssertEqual(gamePitcher.stuff, 80)
        XCTAssertEqual(gamePitcher.effectiveMastery.stuff, 1)
    }

    func testInjuryEventPersistsThroughResultEncodingAndSafeDistributionIsZero() throws {
        let engine = ProCareerEngine()
        var signed = try engine.start(startParams(seed: "880802"))
        signed = try engine.signContract(.init(seed: signed.nextSeed, state: signed.snapshot))
        let event = ProInjuryEventSnapshot(
            season: signed.snapshot.season,
            week: signed.snapshot.week + 1,
            plan: .developStuff,
            rawFatigue: 88,
            effectiveFatigue: 86,
            pitches: 91,
            recoveryWeeks: 3,
            careerID: signed.snapshot.proCareerID,
            revision: signed.snapshot.revision + 1
        )
        let result = ProCareerResult(snapshot: signed.snapshot, nextSeed: signed.nextSeed, events: ["pro_injury_started"], injuryEvent: event)
        let restored = try JSONDecoder().decode(ProCareerResult.self, from: JSONEncoder().encode(result))
        XCTAssertEqual(restored, result)
        XCTAssertEqual(restored.injuryEvent?.cause, .overload)
        XCTAssertEqual(restored.injuryEvent?.stableID, event.stableID)

        var accidentalInjuries = 0
        for seed in 1...256 {
            var career = try engine.start(startParams(seed: String(seed)))
            career = try engine.signContract(.init(seed: career.nextSeed, state: career.snapshot))
            let week = try engine.planWeek(.init(seed: career.nextSeed, state: career.snapshot, plan: .recover))
            if week.injuryEvent != nil || week.snapshot.injuryWeeks > 0 { accidentalInjuries += 1 }
        }
        XCTAssertEqual(accidentalInjuries, 0, "유효 피로 72 이하의 안전 정책은 과부하 부상이 없어야 합니다")
    }

    func testHighLoadDistributionEmitsOneStructuredEventOnlyWhenThresholdIsCrossed() throws {
        let engine = ProCareerEngine()
        var injuryStarts = 0
        for seed in 1...24 {
            var career = try engine.start(startParams(seed: "881" + String(seed)))
            career = try engine.signContract(.init(seed: career.nextSeed, state: career.snapshot))
            for _ in 0..<80 {
                switch career.snapshot.phase {
                case .weeklyPlan:
                    career = try engine.planWeek(.init(
                        seed: career.nextSeed,
                        state: career.snapshot,
                        plan: .developStuff
                    ))
                case .importantGame:
                    career = try engine.resolveImportantGame(.init(
                        seed: career.nextSeed,
                        state: career.snapshot,
                        report: .init(
                            scenarioNumber: career.snapshot.week,
                            pitches: 18,
                            strikeouts: 0,
                            walks: 3,
                            runsAllowed: 5,
                            expectedDamage: 1_200,
                            actualDamage: 3_000,
                            recommendationAccepted: 0
                        )
                    ))
                case .seasonDecision:
                    let pending = try XCTUnwrap(career.snapshot.pendingDecision)
                    career = try engine.applySeasonDecision(.init(
                        seed: career.nextSeed,
                        state: career.snapshot,
                        decisionID: pending.id,
                        choiceID: try XCTUnwrap(pending.choices.first?.id)
                    ))
                case .seasonReview:
                    career = try engine.reviewSeason(.init(seed: career.nextSeed, state: career.snapshot))
                case .offseasonDecision:
                    career = try engine.chooseOffseason(.init(seed: career.nextSeed, state: career.snapshot, decision: .continueCareer))
                default:
                    break
                }
                if let event = career.injuryEvent {
                    injuryStarts += 1
                    XCTAssertEqual(event.cause, .overload)
                    XCTAssertGreaterThan(event.effectiveFatigue, 72)
                    XCTAssertGreaterThan(event.pitches, 0)
                    XCTAssertTrue(career.events.contains("pro_injury_started"))
                    break
                }
            }
        }
        XCTAssertGreaterThan(injuryStarts, 0, "고부하 정책에서 과부하 부상 이벤트가 한 번은 관측되어야 합니다")
    }

    private func startParams(seed: String) -> StartProCareerParams {
        let team = HighSchoolCareerEngine.teams[0]
        return StartProCareerParams(
            seed: seed,
            identity: .defaultPitcher,
            pitcher: PitcherSnapshot(id: "p-" + seed, name: "테스트투수", stuff: 58, command: 55, movement: 56, stamina: 57),
            draftResult: DraftResultSnapshot(
                outcome: .drafted,
                evaluationScore: 72,
                projectedRange: "2~3라운드",
                team: team,
                round: 2,
                overallPick: 18,
                signingBonus: 120_000_000,
                firstSeasonGoal: "2군 선발",
                summary: "지명"
            ),
            entitlement: ProEntitlementSnapshot(status: .active, source: .development, verifiedAt: "test")
        )
    }

    private func replacePitcherAndTalent(
        _ source: HighSchoolCareerSnapshot,
        pitcher: PitcherSnapshot,
        talent: TalentSnapshot
    ) throws -> HighSchoolCareerSnapshot {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(source)) as? [String: Any]
        )
        object["pitcher"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(pitcher))
        object["talent"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(talent))
        return try JSONDecoder().decode(
            HighSchoolCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }
}
