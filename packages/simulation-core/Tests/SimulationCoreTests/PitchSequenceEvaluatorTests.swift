import XCTest
@testable import SimulationCore

final class PitchSequenceEvaluatorTests: XCTestCase {
    func testSpeedLadderRecognizesTwelveKPHOrGreaterTimingChange() {
        let moment = evaluate(
            recent: [pitch(type: .fourSeam, velocity: 150)],
            current: pitch(type: .changeup, velocity: 136, outcome: .swingingStrike)
        )

        XCTAssertEqual(moment?.tag, .speedLadder)
        XCTAssertEqual(moment?.headline, "속도차 적중 · 14km/h")
        XCTAssertEqual(moment?.pitchNumber, 2)
    }

    func testSpeedLadderRejectsSmallDifferenceAndDamagingOutcome() {
        XCTAssertNil(evaluate(
            recent: [pitch(type: .fourSeam, velocity: 150)],
            current: pitch(type: .changeup, velocity: 139, outcome: .swingingStrike)
        ))
        XCTAssertNil(evaluate(
            recent: [pitch(type: .fourSeam, velocity: 150)],
            current: pitch(type: .changeup, velocity: 136, outcome: .single)
        ))
    }

    func testEyeLevelChangeRecognizesConsecutiveHighAndLowPitch() {
        let moment = evaluate(
            recent: [pitch(row: 0, column: 1, velocity: 140)],
            current: pitch(row: 2, column: 1, velocity: 140, outcome: .inPlayOut)
        )

        XCTAssertEqual(moment?.tag, .eyeLevelChange)
        XCTAssertEqual(moment?.headline, "눈높이를 바꿨다")
    }

    func testEyeLevelChangeRejectsAdjacentHeightAndBadResult() {
        XCTAssertNil(evaluate(
            recent: [pitch(row: 0, column: 1, velocity: 140)],
            current: pitch(row: 1, column: 1, velocity: 140, outcome: .swingingStrike)
        ))
        XCTAssertNil(evaluate(
            recent: [pitch(row: 0, column: 1, velocity: 140)],
            current: pitch(row: 2, column: 1, velocity: 140, outcome: .double)
        ))
    }

    func testInsideOutsideRecognizesConsecutiveHorizontalExtremes() {
        let moment = evaluate(
            recent: [pitch(row: 1, column: 0, velocity: 140)],
            current: pitch(row: 1, column: 2, velocity: 140, outcome: .calledStrike)
        )

        XCTAssertEqual(moment?.tag, .insideOutside)
        XCTAssertEqual(moment?.headline, "가로 폭을 썼다")
    }

    func testInsideOutsideRejectsSameCourseAndDamagingOutcome() {
        let repeated = pitch(row: 1, column: 0, velocity: 140, outcome: .calledStrike)
        XCTAssertNil(evaluate(
            recent: [repeated],
            current: pitch(row: 1, column: 0, velocity: 140, outcome: .swingingStrike)
        ))
        XCTAssertNil(evaluate(
            recent: [pitch(row: 1, column: 0, velocity: 140)],
            current: pitch(row: 1, column: 2, velocity: 140, outcome: .homeRun)
        ))
    }

    func testExpandAfterTwoStrikesRecognizesChaseWhiff() {
        let moment = evaluate(
            context: context(strikes: 2),
            current: pitch(intent: .chase, outcome: .swingingStrike)
        )

        XCTAssertEqual(moment?.tag, .expandAfterTwoStrikes)
        XCTAssertEqual(moment?.headline, "결정구 유인 성공")
    }

    func testExpandAfterTwoStrikesRequiresCountIntentAndWhiff() {
        XCTAssertNil(evaluate(
            context: context(strikes: 1),
            current: pitch(intent: .chase, outcome: .swingingStrike)
        ))
        XCTAssertNil(evaluate(
            context: context(strikes: 2),
            current: pitch(intent: .edge, outcome: .swingingStrike)
        ))
        XCTAssertNil(evaluate(
            context: context(strikes: 2),
            current: pitch(intent: .chase, outcome: .calledStrike)
        ))
    }

    func testStealStrikeRecognizesStrikeIntentInHittersCount() {
        let moment = evaluate(
            context: context(balls: 2, strikes: 0),
            current: pitch(intent: .strike, outcome: .calledStrike)
        )

        XCTAssertEqual(moment?.tag, .stealStrike)
        XCTAssertEqual(moment?.headline, "카운트를 되찾았다")
    }

    func testStealStrikeRequiresHittersCountStrikeIntentAndStrikeResult() {
        XCTAssertNil(evaluate(
            context: context(balls: 0, strikes: 1),
            current: pitch(intent: .strike, outcome: .calledStrike)
        ))
        XCTAssertNil(evaluate(
            context: context(balls: 2, strikes: 0),
            current: pitch(intent: .chase, outcome: .calledStrike)
        ))
        XCTAssertNil(evaluate(
            context: context(balls: 2, strikes: 0),
            current: pitch(intent: .strike, outcome: .ball)
        ))
    }

    func testCounterReadRecognizesChangeAwayFromEstablishedWarning() {
        let moment = evaluate(
            context: context(balls: 1, strikes: 1),
            current: pitch(
                type: .slider,
                row: 1,
                column: 1,
                velocity: 140,
                outcome: .calledStrike
            ),
            rivalMemory: establishedRepeatedMemory()
        )

        XCTAssertEqual(moment?.tag, .counterRead)
        XCTAssertEqual(moment?.headline, "읽힘을 역이용했다")
    }

    func testCounterReadRequiresEstablishedWarningPatternChangeAndGoodResult() {
        XCTAssertNil(evaluate(
            context: context(balls: 1, strikes: 1),
            current: pitch(type: .slider, outcome: .calledStrike),
            rivalMemory: watchingMemory()
        ))
        XCTAssertNil(evaluate(
            context: context(balls: 1, strikes: 1),
            current: pitch(type: .fourSeam, row: 0, column: 0, outcome: .calledStrike),
            rivalMemory: establishedRepeatedMemory()
        ))
        XCTAssertNil(evaluate(
            context: context(balls: 1, strikes: 1),
            current: pitch(type: .slider, outcome: .single),
            rivalMemory: establishedRepeatedMemory()
        ))
    }

    func testSpecificCounterReadWinsWhenPitchMatchesMultipleTags() {
        let moment = evaluate(
            recent: [pitch(type: .fourSeam, row: 0, column: 0, velocity: 154)],
            context: context(strikes: 2),
            current: pitch(
                type: .changeup,
                row: 2,
                column: 2,
                intent: .chase,
                velocity: 136,
                outcome: .swingingStrike
            ),
            rivalMemory: establishedRepeatedMemory()
        )

        XCTAssertEqual(moment?.tag, .counterRead)
    }

    func testSameInputsAlwaysProduceSameMoment() throws {
        let recent = [
            pitch(type: .slider, row: 1, column: 1, velocity: 136, outcome: .calledStrike),
            pitch(type: .fourSeam, row: 0, column: 1, velocity: 151, outcome: .foul)
        ]
        let current = pitch(
            type: .changeup,
            row: 2,
            column: 1,
            velocity: 132,
            outcome: .swingingStrike
        )
        let plateContext = context(balls: 1, strikes: 1, pitchNumber: 7)

        let first = PitchSequenceEvaluator.evaluate(
            recent: recent,
            context: plateContext,
            current: current,
            rivalMemory: nil
        )
        for _ in 0..<100 {
            XCTAssertEqual(
                PitchSequenceEvaluator.evaluate(
                    recent: recent,
                    context: plateContext,
                    current: current,
                    rivalMemory: nil
                ),
                first
            )
        }

        let encoded = try JSONEncoder().encode(first)
        XCTAssertEqual(try JSONDecoder().decode(PitchSequenceMoment?.self, from: encoded), first)
    }

    func testSequenceRecognitionDoesNotChangePitchResolution() throws {
        let engine = SimulationEngine()
        let params = SimulatePitchParams(
            seed: "20260721",
            pitcher: PitcherSnapshot(
                id: "pitcher-sequence",
                name: "테스트투수",
                stuff: 62,
                command: 54,
                movement: 58,
                stamina: 60
            ),
            batter: BatterSnapshot(
                id: "batter-sequence",
                name: "테스트타자",
                contact: 56,
                discipline: 52,
                power: 58
            ),
            count: CountState(balls: 1, strikes: 1),
            fatigue: 12,
            selection: PitchSelection(
                pitchType: .changeup,
                zone: PitchZone(row: 2, column: 1),
                intensity: .normal
            )
        )

        let before = try engine.simulatePitch(params)
        _ = evaluate(
            recent: [pitch(type: .fourSeam, row: 0, column: 1, velocity: 150)],
            current: pitch(
                type: .changeup,
                row: 2,
                column: 1,
                velocity: 136,
                outcome: before.snapshot.outcome
            )
        )
        let after = try engine.simulatePitch(params)

        XCTAssertEqual(after, before)
        XCTAssertEqual(after.events.first?.eventHash, before.events.first?.eventHash)
    }

    func testImportantInningReportDecodesLegacyPayloadAndRoundTripsMasteryCount() throws {
        let legacy = Data(#"""
        {
            "scenarioNumber": 1,
            "pitches": 18,
            "strikeouts": 3,
            "walks": 1,
            "runsAllowed": 0,
            "expectedDamage": 420,
            "actualDamage": 210,
            "recommendationAccepted": 9
        }
        """#.utf8)
        let decodedLegacy = try JSONDecoder().decode(ImportantInningReport.self, from: legacy)
        XCTAssertNil(decodedLegacy.sequenceMasteryCount)

        let current = ImportantInningReport(
            scenarioNumber: 2,
            pitches: 21,
            strikeouts: 4,
            walks: 0,
            runsAllowed: 1,
            expectedDamage: 500,
            actualDamage: 430,
            recommendationAccepted: 11,
            outs: 6,
            sequenceMasteryCount: 4
        )
        XCTAssertEqual(
            try JSONDecoder().decode(
                ImportantInningReport.self,
                from: JSONEncoder().encode(current)
            ),
            current
        )
    }

    func testTrustRewardIsOnePerMomentAndCappedAtThree() {
        XCTAssertEqual(PitchSequenceMasteryRules.trustReward(for: nil), 0)
        XCTAssertEqual(PitchSequenceMasteryRules.trustReward(for: -1), 0)
        XCTAssertEqual(PitchSequenceMasteryRules.trustReward(for: 0), 0)
        XCTAssertEqual(PitchSequenceMasteryRules.trustReward(for: 2), 2)
        XCTAssertEqual(PitchSequenceMasteryRules.trustReward(for: 3), 3)
        XCTAssertEqual(PitchSequenceMasteryRules.trustReward(for: 99), 3)
    }

    private func evaluate(
        recent: [PitchSequencePitch] = [],
        context: PlateAppearanceContext? = nil,
        current: PitchSequencePitch,
        rivalMemory: RivalMemorySnapshot? = nil
    ) -> PitchSequenceMoment? {
        PitchSequenceEvaluator.evaluate(
            recent: recent,
            context: context ?? self.context(),
            current: current,
            rivalMemory: rivalMemory
        )
    }

    private func context(
        balls: Int = 0,
        strikes: Int = 0,
        pitchNumber: Int = 2
    ) -> PlateAppearanceContext {
        PlateAppearanceContext(
            plateAppearanceID: "pa-sequence",
            revision: UInt64(max(0, pitchNumber - 1)),
            inning: 7,
            outs: 1,
            balls: balls,
            strikes: strikes,
            pitchNumber: pitchNumber,
            scoreDifferential: 0,
            leverage: 700,
            fatigue: 20
        )
    }

    private func pitch(
        type: PitchType = .fourSeam,
        row: Int = 1,
        column: Int = 1,
        intent: ZoneIntent = .strike,
        velocity: Int = 140,
        outcome: PitchOutcome = .calledStrike
    ) -> PitchSequencePitch {
        PitchSequencePitch(
            pitchType: type,
            zone: PitchZone(row: row, column: column),
            intent: intent,
            expectedVelocityKPH: velocity,
            outcome: outcome
        )
    }

    private func establishedRepeatedMemory() -> RivalMemorySnapshot {
        let observations = (0..<6).map { _ in
            RivalPitchObservation(
                pitchType: .fourSeam,
                zone: PitchZone(row: 0, column: 0),
                zoneIntent: .edge,
                balls: 1,
                strikes: 1,
                outcome: .single
            )
        }
        return RivalMemorySnapshot(
            matchupID: "pitcher:bench:sequence",
            revision: 6,
            plateAppearancesSeen: 1,
            totalPitchesSeen: observations.count,
            recentObservations: observations
        )
    }

    private func watchingMemory() -> RivalMemorySnapshot {
        RivalMemorySnapshot(
            matchupID: "pitcher:bench:sequence",
            revision: 1,
            plateAppearancesSeen: 0,
            totalPitchesSeen: 1,
            recentObservations: [
                RivalPitchObservation(
                    pitchType: .fourSeam,
                    zone: PitchZone(row: 0, column: 0),
                    zoneIntent: .edge,
                    balls: 1,
                    strikes: 1,
                    outcome: .single
                )
            ]
        )
    }
}
