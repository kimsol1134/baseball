import XCTest
@testable import SimulationCore

final class SimulationEngineTests: XCTestCase {
    private let engine = SimulationEngine()

    private struct GoldenFixture: Decodable {
        struct Expected: Decodable {
            let outcome: PitchOutcome
            let nextSeed: String
            let executionScore: Int
            let eventHash: String
        }

        let params: SimulatePitchParams
        let expected: Expected
    }

    func testCommittedGoldenFixtureMatchesStableEvent() throws {
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(forResource: "simulate_pitch_golden", withExtension: "json")
        )
        let fixture = try JSONDecoder().decode(
            GoldenFixture.self,
            from: Data(contentsOf: fixtureURL)
        )

        let result = try engine.simulatePitch(fixture.params)
        let event = try XCTUnwrap(result.events.first)

        XCTAssertEqual(event.outcome, fixture.expected.outcome)
        XCTAssertEqual(event.nextSeed, fixture.expected.nextSeed)
        XCTAssertEqual(event.executionScore, fixture.expected.executionScore)
        XCTAssertEqual(event.eventHash, fixture.expected.eventHash)
    }

    func testSameSeedAndCommandProduceSameEvent() throws {
        let params = makeParams(seed: "20260721", command: 54)

        let first = try engine.simulatePitch(params)
        let second = try engine.simulatePitch(params)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.events.first?.eventHash, second.events.first?.eventHash)
    }

    func testDifferentSeedsProduceDifferentEventHashes() throws {
        let first = try engine.simulatePitch(makeParams(seed: "1", command: 54))
        let second = try engine.simulatePitch(makeParams(seed: "2", command: 54))

        XCTAssertNotEqual(first.events.first?.eventHash, second.events.first?.eventHash)
    }

    func testHigherCommandProducesFewerBallsAcrossFixedSeeds() throws {
        var lowCommandBalls = 0
        var highCommandBalls = 0

        for seed in 1...2_000 {
            let low = try engine.simulatePitch(makeParams(seed: String(seed), command: 30))
            let high = try engine.simulatePitch(makeParams(seed: String(seed), command: 75))
            if low.snapshot.outcome == .ball { lowCommandBalls += 1 }
            if high.snapshot.outcome == .ball { highCommandBalls += 1 }
        }

        XCTAssertLessThan(highCommandBalls, lowCommandBalls)
    }

    func testRejectsRatingsOutsideTheTwentyToEightyScale() {
        XCTAssertThrowsError(try engine.simulatePitch(makeParams(seed: "1", command: 81))) { error in
            XCTAssertEqual(
                error as? SimulationError,
                .invalidRating(field: "pitcher.command", value: 81)
            )
        }
    }

    private func makeParams(seed: String, command: Int) -> SimulatePitchParams {
        SimulatePitchParams(
            seed: seed,
            pitcher: PitcherSnapshot(
                id: "pitcher-1",
                name: "김도윤",
                stuff: 62,
                command: command,
                movement: 58,
                stamina: 60
            ),
            batter: BatterSnapshot(
                id: "batter-1",
                name: "이준호",
                contact: 56,
                discipline: 52,
                power: 58
            ),
            count: CountState(balls: 1, strikes: 1),
            fatigue: 12,
            selection: PitchSelection(
                pitchType: .slider,
                zone: PitchZone(row: 2, column: 0),
                intensity: .normal
            )
        )
    }
}
