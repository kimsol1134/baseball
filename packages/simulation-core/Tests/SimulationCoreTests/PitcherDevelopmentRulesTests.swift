import XCTest
@testable import SimulationCore

final class PitcherDevelopmentRulesTests: XCTestCase {
    private var pitcher: PitcherSnapshot {
        PitcherSnapshot(
            id: "development", name: "성장 투수",
            stuff: 50, command: 50, movement: 50, stamina: 50,
            pitchProfiles: [
                .init(pitchType: .fourSeam, role: .primary, velocityTenthsKPH: 1_420,
                      control: 50, command: 50, movement: 50, whiff: 50,
                      weakContact: 50, fatigueCost: 2),
                .init(pitchType: .slider, role: .secondary, velocityTenthsKPH: 1_280,
                      control: 50, command: 50, movement: 50, whiff: 50,
                      weakContact: 50, fatigueCost: 2),
                .init(pitchType: .curveball, role: .secondary, velocityTenthsKPH: 1_160,
                      control: 50, command: 50, movement: 50, whiff: 50,
                      weakContact: 50, fatigueCost: 2),
            ]
        )
    }

    func testTargetedBreakingBallGrowthChangesOnlyTheChosenProfile() throws {
        let grown = PitcherGrowthRules.grow(
            pitcher, focus: .breakingBall, points: 2, targetPitch: .slider
        )
        XCTAssertEqual(grown.movement, 52)
        let slider = try XCTUnwrap(grown.profile(for: .slider))
        XCTAssertEqual(slider.movement, 54)
        XCTAssertEqual(slider.whiff, 52)
        XCTAssertEqual(grown.profile(for: .curveball)?.movement, 50)
        XCTAssertEqual(grown.profile(for: .fourSeam)?.movement, 50)
    }

    func testEachGrowthAxisOwnsADifferentVisibleProfileEffect() throws {
        let power = PitcherGrowthRules.grow(pitcher, focus: .velocity, points: 2)
        XCTAssertEqual(power.stuff, 52)
        XCTAssertEqual(power.profile(for: .fourSeam)?.velocityTenthsKPH, 1_430)
        XCTAssertEqual(power.profile(for: .fourSeam)?.whiff, 52)

        let command = PitcherGrowthRules.grow(pitcher, focus: .command, points: 2)
        XCTAssertEqual(command.command, 52)
        XCTAssertEqual(command.profile(for: .slider)?.control, 52)
        XCTAssertEqual(command.profile(for: .slider)?.command, 52)

        let stamina = PitcherGrowthRules.grow(pitcher, focus: .stamina, points: 2)
        XCTAssertEqual(stamina.stamina, 52)
        XCTAssertEqual(stamina.profile(for: .slider)?.fatigueCost, 1)
    }

    func testBuildIdentityUsesStableTieBreakAndChangesWithSpecialization() {
        XCTAssertEqual(PitcherBuildRules.identity(for: pitcher), .power)
        let movement = PitcherGrowthRules.grow(pitcher, focus: .breakingBall, points: 2)
        XCTAssertEqual(PitcherBuildRules.identity(for: movement), .movement)
    }

    func testVelocityGrowthStopsAtGroundedProfileCeiling() throws {
        let nearCeiling = PitcherSnapshot(
            id: pitcher.id,
            name: pitcher.name,
            stuff: 79,
            command: pitcher.command,
            movement: pitcher.movement,
            stamina: pitcher.stamina,
            pitchProfiles: pitcher.pitchProfiles?.map { profile in
                PitchProfileSnapshot(
                    pitchType: profile.pitchType,
                    role: profile.role,
                    velocityTenthsKPH: 1_598,
                    control: profile.control,
                    command: profile.command,
                    movement: profile.movement,
                    whiff: profile.whiff,
                    weakContact: profile.weakContact,
                    fatigueCost: profile.fatigueCost
                )
            }
        )

        let grown = PitcherGrowthRules.grow(nearCeiling, focus: .velocity, points: 4)
        XCTAssertEqual(grown.stuff, 80)
        XCTAssertTrue(try XCTUnwrap(grown.pitchProfiles).allSatisfy {
            $0.velocityTenthsKPH
                == PitchAbilityRules.maximumProfileVelocityTenthsKPH(for: $0.pitchType)
        })
    }

    func testHighStaminaProducesDifferentAndBetterLateOutingAggregate() {
        let low = PitcherSnapshot(
            id: pitcher.id, name: pitcher.name, stuff: 50, command: 50,
            movement: 50, stamina: 35, pitchProfiles: pitcher.pitchProfiles
        )
        let high = PitcherSnapshot(
            id: pitcher.id, name: pitcher.name, stuff: 50, command: 50,
            movement: 50, stamina: 80, pitchProfiles: pitcher.pitchProfiles
        )
        let simulator = AutoOutingSimulator()
        var lowRuns = 0, highRuns = 0, lowWalks = 0, highWalks = 0
        for seed in 1...120 {
            let baseSeed = UInt64(seed) * 7_919
            let lowLine = simulator.simulate(
                pitcher: low, startingFatigue: 42, outsTarget: 18,
                pitchCap: 96, baseSeed: baseSeed
            )
            let highLine = simulator.simulate(
                pitcher: high, startingFatigue: 42, outsTarget: 18,
                pitchCap: 96, baseSeed: baseSeed
            )
            lowRuns += lowLine.runsAllowed
            highRuns += highLine.runsAllowed
            lowWalks += lowLine.walks
            highWalks += highLine.walks
        }
        XCTAssertLessThan(highRuns, lowRuns)
        XCTAssertLessThan(highWalks, lowWalks)
    }
}
