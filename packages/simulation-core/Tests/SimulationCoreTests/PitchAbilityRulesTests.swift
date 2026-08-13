import XCTest
@testable import SimulationCore

final class PitchAbilityRulesTests: XCTestCase {
    private let pitcher = PitcherSnapshot(
        id: "build-pitcher",
        name: "테스트 투수",
        stuff: 62,
        command: 64,
        movement: 60,
        stamina: 58,
        pitchProfiles: [
            PitchProfileSnapshot(
                pitchType: .fourSeam, role: .primary,
                velocityTenthsKPH: 1_470, control: 66, command: 63,
                movement: 54, whiff: 61, weakContact: 56, fatigueCost: 1
            ),
            PitchProfileSnapshot(
                pitchType: .slider, role: .secondary,
                velocityTenthsKPH: 1_320, control: 58, command: 60,
                movement: 64, whiff: 66, weakContact: 60, fatigueCost: 2
            )
        ]
    )

    private func context(fatigue: Int = 20) -> PlateAppearanceContext {
        PlateAppearanceContext(
            plateAppearanceID: "pa", revision: 0, inning: 7, outs: 0,
            balls: 0, strikes: 0, pitchNumber: 1,
            scoreDifferential: 0, leverage: 800, fatigue: fatigue
        )
    }

    private func call(
        _ pitch: PitchType,
        intensity: PitchIntensity = .normal
    ) -> PitchCall {
        PitchCall(
            pitchType: pitch,
            zone: PitchZone(row: 2, column: 0),
            zoneIntent: .edge,
            intensity: intensity
        )
    }

    private func execution(quality: Int) -> PitchExecution {
        PitchExecution(
            targetX: -420, targetY: -420, actualX: -400, actualY: -390,
            velocityTenthsKPH: 1_465,
            horizontalBreakTenthsCM: 80, verticalBreakTenthsCM: 170,
            executionQuality: quality
        )
    }

    func testReadoutUsesTheSameCommandVelocityAndFatigueInputsAsPitchExecution() {
        let normal = PitchAbilityRules.readout(
            pitcher: pitcher, call: call(.fourSeam), context: context()
        )
        XCTAssertEqual(normal.commandRating, 64)
        XCTAssertEqual(
            normal.nominalVelocityTenthsKPH,
            1_470 - normal.effectiveFatigue
        )
        XCTAssertEqual(normal.fatigueCost, 1)
        XCTAssertEqual(normal.movementRating, 57)
        XCTAssertEqual(normal.rawFatigue, 20)
        XCTAssertEqual(normal.whiffRating, 61)

        let maxEffort = PitchAbilityRules.readout(
            pitcher: pitcher,
            call: call(.fourSeam, intensity: .maxEffort),
            context: context()
        )
        // 화면 표기는 판정에 쓰는 값과 같아야 한다 — 강도 상수를 바꾸면 여기도 함께 움직인다.
        XCTAssertEqual(
            maxEffort.nominalVelocityTenthsKPH,
            normal.nominalVelocityTenthsKPH
                + PitchAbilityRules.intensityEffect(.maxEffort).velocityBonusTenthsKPH
        )
        XCTAssertEqual(maxEffort.fatigueCost, 2)
        // 힘 배분 세 축이 서로 다른 것을 사고판다: 전력은 구속을 얻고 제구를 잃는다.
        let controlled = PitchAbilityRules.readout(
            pitcher: pitcher,
            call: call(.fourSeam, intensity: .controlled),
            context: context()
        )
        XCTAssertGreaterThan(maxEffort.nominalVelocityTenthsKPH, normal.nominalVelocityTenthsKPH)
        XCTAssertLessThan(controlled.nominalVelocityTenthsKPH, normal.nominalVelocityTenthsKPH)
        // commandRating은 구종 자체의 제구값이라 강도와 무관하다 — 강도가 사고파는 것은
        // 규칙 상수 쪽에서 확인한다.
        XCTAssertGreaterThan(
            PitchAbilityRules.intensityEffect(.maxEffort).commandPenalty,
            PitchAbilityRules.intensityEffect(.controlled).commandPenalty
        )
    }

    func testLegacyEliteProfileIsGroundedByPitchIntensity() {
        let legacyElite = PitcherSnapshot(
            id: "legacy-elite",
            name: "구속 상한 투수",
            stuff: 80,
            command: 60,
            movement: 60,
            stamina: 80,
            pitchProfiles: [
                PitchProfileSnapshot(
                    pitchType: .fourSeam,
                    role: .primary,
                    velocityTenthsKPH: 1_700,
                    control: 60,
                    command: 60,
                    movement: 60,
                    whiff: 80,
                    weakContact: 60,
                    fatigueCost: 2
                )
            ]
        )

        let controlled = PitchAbilityRules.nominalVelocity(
            pitcher: legacyElite, pitchType: .fourSeam, intensity: .controlled, fatigue: 0
        )
        let normal = PitchAbilityRules.nominalVelocity(
            pitcher: legacyElite, pitchType: .fourSeam, intensity: .normal, fatigue: 0
        )
        let maxEffort = PitchAbilityRules.nominalVelocity(
            pitcher: legacyElite, pitchType: .fourSeam, intensity: .maxEffort, fatigue: 0
        )

        XCTAssertEqual(controlled, 1_580)
        XCTAssertEqual(normal, 1_600)
        XCTAssertEqual(maxEffort, 1_640)
        XCTAssertLessThan(controlled, normal)
        XCTAssertLessThan(normal, maxEffort)
    }

    func testAbilityMomentOnlyCelebratesARelevantResolvedStrength() {
        let fastball = PitchAbilityRules.readout(
            pitcher: pitcher, call: call(.fourSeam), context: context()
        )
        XCTAssertEqual(PitchAbilityRules.moment(
            outcome: .swingingStrike,
            execution: execution(quality: 700),
            readout: fastball
        ), .power)
        XCTAssertEqual(PitchAbilityRules.moment(
            outcome: .calledStrike,
            execution: execution(quality: 700),
            readout: fastball
        ), .command)

        let slider = PitchAbilityRules.readout(
            pitcher: pitcher, call: call(.slider), context: context()
        )
        XCTAssertEqual(PitchAbilityRules.moment(
            outcome: .inPlayOut,
            execution: execution(quality: 620),
            readout: slider
        ), .movement)
        XCTAssertNil(PitchAbilityRules.moment(
            outcome: .single,
            execution: execution(quality: 800),
            readout: slider
        ))
    }

    func testFatigueGrowthPreservesAnAlreadyEfficientZeroCostPitch() {
        XCTAssertEqual(PitchAbilityRules.reducedFatigueCost(0, by: 1), 0)
        XCTAssertEqual(PitchAbilityRules.reducedFatigueCost(2, by: 1), 1)
        XCTAssertEqual(PitchAbilityRules.reducedFatigueCost(1, by: 3), 1)
    }

    func testStaminaChangesLatePitchPressureButNeverTheFreshFirstPitch() {
        XCTAssertEqual(PitchAbilityRules.effectiveFatigue(rawFatigue: 0, stamina: 20), 0)
        XCTAssertEqual(PitchAbilityRules.effectiveFatigue(rawFatigue: 0, stamina: 80), 0)
        XCTAssertEqual(PitchAbilityRules.effectiveFatigue(rawFatigue: 40, stamina: 50), 40)
        XCTAssertLessThan(
            PitchAbilityRules.effectiveFatigue(rawFatigue: 40, stamina: 80),
            PitchAbilityRules.effectiveFatigue(rawFatigue: 40, stamina: 50)
        )
        XCTAssertGreaterThan(
            PitchAbilityRules.effectiveFatigue(rawFatigue: 40, stamina: 20),
            PitchAbilityRules.effectiveFatigue(rawFatigue: 40, stamina: 50)
        )
    }

    func testBreakingBallWhiffBadgeFollowsTheLargerActualAbilityContribution() {
        let base = PitchAbilityReadout(
            pitchType: .slider,
            stuffRating: 72,
            commandRating: 50,
            movementRating: 55,
            staminaRating: 50,
            whiffRating: 65,
            weakContactRating: 55,
            nominalVelocityTenthsKPH: 1_300,
            fatigueCost: 2
        )
        XCTAssertEqual(PitchAbilityRules.moment(
            outcome: .swingingStrike,
            execution: execution(quality: 700),
            readout: base
        ), .power)

        let movementLed = PitchAbilityReadout(
            pitchType: .slider,
            stuffRating: 55,
            commandRating: 50,
            movementRating: 70,
            staminaRating: 50,
            whiffRating: 65,
            weakContactRating: 60,
            nominalVelocityTenthsKPH: 1_300,
            fatigueCost: 2
        )
        XCTAssertEqual(PitchAbilityRules.moment(
            outcome: .swingingStrike,
            execution: execution(quality: 700),
            readout: movementLed
        ), .movement)
    }

    func testStaminaGetsLateSuccessFeedbackAndStarterExtensionOnlyWhenSpecialized() {
        let late = PitchAbilityReadout(
            pitchType: .fourSeam,
            stuffRating: 50,
            commandRating: 50,
            movementRating: 50,
            staminaRating: 70,
            whiffRating: 50,
            weakContactRating: 50,
            nominalVelocityTenthsKPH: 1_400,
            fatigueCost: 1,
            effectiveFatigue: 35,
            rawFatigue: 50
        )
        XCTAssertEqual(PitchAbilityRules.moment(
            outcome: .inPlayOut,
            execution: execution(quality: 600),
            readout: late
        ), .stamina)

        let staminaBuild = PitcherSnapshot(
            id: "stamina", name: "체력형", stuff: 50, command: 50,
            movement: 50, stamina: 56
        )
        let balanced = PitcherSnapshot(
            id: "balanced", name: "균형형", stuff: 50, command: 50,
            movement: 50, stamina: 50
        )
        XCTAssertEqual(PitchAbilityRules.starterExtensionOuts(pitcher: staminaBuild), 2)
        XCTAssertEqual(PitchAbilityRules.starterExtensionOuts(pitcher: balanced), 0)
    }

    func testCareerGameStaminaGrowthAlsoPreservesZeroCostPitch() throws {
        let zeroCost = PitcherSnapshot(
            id: pitcher.id,
            name: pitcher.name,
            stuff: pitcher.stuff,
            command: pitcher.command,
            movement: pitcher.movement,
            stamina: pitcher.stamina,
            pitchProfiles: [
                PitchProfileSnapshot(
                    pitchType: .fourSeam, role: .primary,
                    velocityTenthsKPH: 1_470, control: 66, command: 63,
                    movement: 54, whiff: 61, weakContact: 56, fatigueCost: 0
                )
            ]
        )
        let growth = CareerGameGrowth(
            ability: .stamina,
            points: 1,
            reason: .longOuting,
            title: "체력 +1",
            detail: "한 이닝을 책임졌습니다.",
            resultingTalent: .unlimited
        )

        let applied = growth.applying(to: zeroCost)
        XCTAssertEqual(applied.stamina, zeroCost.stamina + 1)
        XCTAssertEqual(applied.pitchProfiles?.first?.fatigueCost, 0)
    }
}
