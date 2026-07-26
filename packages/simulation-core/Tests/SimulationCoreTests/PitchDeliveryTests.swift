import XCTest
@testable import SimulationCore

/// `PitchDelivery` is an additive execution input. These tests pin the two properties the rest of
/// the system depends on: absent/neutral deliveries change nothing at all, and a real delivery
/// changes execution without touching the judgment path.
final class PitchDeliveryTests: XCTestCase {
    private let engine = PitchKernelEngine()

    private let pitcher = PitcherSnapshot(
        id: "p-delivery", name: "테스트", stuff: 48, command: 44, movement: 46, stamina: 45
    )
    private let batter = BatterSnapshot(
        id: "b-delivery", name: "상대", contact: 50, discipline: 50, power: 50
    )
    private let scouting = BatterScoutingSnapshot(
        hotZone: PitchZone(row: 1, column: 1),
        coldZone: PitchZone(row: 2, column: 0),
        pitchStrength: .fourSeam,
        pitchWeakness: .slider,
        chaseTendency: 48
    )

    private func context(pitchNumber: Int = 1) -> PlateAppearanceContext {
        PlateAppearanceContext(
            plateAppearanceID: "pa-delivery",
            revision: 0,
            inning: 5,
            outs: 1,
            balls: 0,
            strikes: 0,
            pitchNumber: pitchNumber,
            scoreDifferential: 0,
            leverage: 500,
            fatigue: 20
        )
    }

    private let call = PitchCall(
        pitchType: .fourSeam,
        zone: PitchZone(row: 1, column: 1),
        zoneIntent: .strike,
        intensity: .normal
    )

    private func submit(seed: String, delivery: PitchDelivery?) throws -> PitchKernelResult {
        let preparation = try engine.preparePitch(
            .init(seed: seed, pitcher: pitcher, batter: batter, scouting: scouting, context: context())
        )
        return try engine.submitPitch(
            .init(
                seed: seed,
                pitcher: pitcher,
                batter: batter,
                scouting: scouting,
                context: context(),
                preparationToken: preparation.preparationToken,
                call: call
            ),
            delivery: delivery
        )
    }

    /// The contract every pre-delivery caller relies on: passing nothing must be bit-identical to
    /// the behaviour before this field existed.
    func testNeutralDeliveryIsIdenticalToNoDelivery() throws {
        for seed in ["1", "20260725", "987654321"] {
            let without = try submit(seed: seed, delivery: nil)
            let neutral = try submit(seed: seed, delivery: .neutral)
            XCTAssertEqual(without.snapshot.execution, neutral.snapshot.execution, "seed \(seed)")
            XCTAssertEqual(without.snapshot.outcome, neutral.snapshot.outcome, "seed \(seed)")
            XCTAssertEqual(without.snapshot, neutral.snapshot, "seed \(seed)")
        }
    }

    /// The hash may only diverge because a delivery was supplied, never because of a neutral one's
    /// arithmetic. A neutral delivery *is* recorded (it was an input), but the result must not be.
    func testAbsentDeliveryKeepsTheOriginalEventHash() throws {
        let without = try submit(seed: "20260725", delivery: nil)
        let neutral = try submit(seed: "20260725", delivery: .neutral)
        XCTAssertNotEqual(without.eventHash, neutral.eventHash, "입력 유무는 이벤트에 남아야 합니다.")
        XCTAssertEqual(without.snapshot.execution, neutral.snapshot.execution)
    }

    /// A clean release must be measurably better than a botched one.
    func testReleaseAccuracyMovesExecutionQuality() throws {
        let sloppy = try submit(seed: "20260725", delivery: PitchDelivery(releaseAccuracy: 0, aimAccuracy: 500))
        let clean = try submit(seed: "20260725", delivery: PitchDelivery(releaseAccuracy: 1_000, aimAccuracy: 500))
        XCTAssertGreaterThan(clean.snapshot.execution.executionQuality, sloppy.snapshot.execution.executionQuality)
        XCTAssertGreaterThan(clean.snapshot.execution.velocityTenthsKPH, sloppy.snapshot.execution.velocityTenthsKPH)
    }

    /// Steady aim must land the ball closer to where it was aimed.
    func testAimAccuracyPullsTheBallTowardTheTarget() throws {
        let shaky = try submit(seed: "31337", delivery: PitchDelivery(releaseAccuracy: 500, aimAccuracy: 0))
        let steady = try submit(seed: "31337", delivery: PitchDelivery(releaseAccuracy: 500, aimAccuracy: 1_000))
        func miss(_ result: PitchKernelResult) -> Int {
            let execution = result.snapshot.execution
            return abs(execution.actualX - execution.targetX) + abs(execution.actualY - execution.targetY)
        }
        XCTAssertLessThan(miss(steady), miss(shaky))
    }

    /// The delivery is an execution input only. It must never widen the accepted value range.
    func testOutOfRangeDeliveryIsRejected() throws {
        let preparation = try engine.preparePitch(
            .init(seed: "1", pitcher: pitcher, batter: batter, scouting: scouting, context: context())
        )
        for delivery in [
            PitchDelivery(releaseAccuracy: -1, aimAccuracy: 500),
            PitchDelivery(releaseAccuracy: 500, aimAccuracy: 1_001)
        ] {
            XCTAssertThrowsError(
                try engine.submitPitch(
                    .init(
                        seed: "1", pitcher: pitcher, batter: batter, scouting: scouting,
                        context: context(), preparationToken: preparation.preparationToken,
                        call: call
                    ),
                    delivery: delivery
                )
            )
        }
    }

    /// The preparation token is computed before any delivery exists, so a delivery must not
    /// invalidate it. Otherwise the UI could never collect the input after preparing.
    func testDeliveryDoesNotInvalidateThePreparationToken() throws {
        XCTAssertNoThrow(
            try submit(seed: "42", delivery: PitchDelivery(releaseAccuracy: 900, aimAccuracy: 850))
        )
    }

    /// The delivery lives outside `SubmitPitchParams`, so the RPC payload shape is unchanged and
    /// every stored/serialised request keeps decoding exactly as before.
    func testSubmitParamsPayloadShapeIsUnchanged() throws {
        let json = """
        {"seed":"1","pitcher":{"id":"p","name":"n","stuff":50,"command":50,"movement":50,"stamina":50},
         "batter":{"id":"b","name":"m","contact":50,"discipline":50,"power":50},
         "scouting":{"hotZone":{"row":1,"column":1},"coldZone":{"row":2,"column":0},
         "pitchStrength":"four_seam","pitchWeakness":"slider","chaseTendency":48},
         "context":{"plateAppearanceID":"pa","revision":0,"inning":1,"outs":0,"balls":0,"strikes":0,
         "pitchNumber":1,"scoreDifferential":0,"leverage":500,"fatigue":0},
         "preparationToken":"t","call":{"pitchType":"four_seam","zone":{"row":1,"column":1},
         "zoneIntent":"strike","intensity":"normal"}}
        """
        let decoded = try JSONDecoder().decode(SubmitPitchParams.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.call.pitchType, .fourSeam)
        let encoded = try JSONEncoder().encode(decoded)
        let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        XCTAssertNil(object?["delivery"], "delivery는 파라미터 구조체에 들어가지 않습니다.")
    }
}
