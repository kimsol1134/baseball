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
        XCTAssertEqual(normal.nominalVelocityTenthsKPH, 1_450)
        XCTAssertEqual(normal.fatigueCost, 1)
        XCTAssertEqual(normal.movementRating, 54)
        XCTAssertEqual(normal.whiffRating, 61)

        let maxEffort = PitchAbilityRules.readout(
            pitcher: pitcher,
            call: call(.fourSeam, intensity: .maxEffort),
            context: context()
        )
        XCTAssertEqual(maxEffort.nominalVelocityTenthsKPH, 1_545)
        XCTAssertEqual(maxEffort.fatigueCost, 2)
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
