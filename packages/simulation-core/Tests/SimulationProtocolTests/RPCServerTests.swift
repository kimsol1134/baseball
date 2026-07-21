import XCTest
import SimulationCore
@testable import SimulationProtocol

final class RPCServerTests: XCTestCase {
    private let server = RPCServer()

    func testHealthRequest() throws {
        let response = try decodeResponse(
            server.handle(line: #"{"jsonrpc":"2.0","id":"health-1","method":"health"}"#)
        )

        XCTAssertNil(response.error)
        let health = try XCTUnwrap(response.result).decode(HealthResult.self)
        XCTAssertEqual(health.status, "ok")
        XCTAssertEqual(health.protocolVersion, "1.2")
        XCTAssertEqual(health.coreVersion, "0.3.0")
    }

    func testListsFourPitcherPresetsWithCompleteRepertoires() throws {
        let response = try decodeResponse(
            server.handle(
                line: #"{"jsonrpc":"2.0","id":"presets-1","method":"listPitcherPresets"}"#
            )
        )

        let presets = try XCTUnwrap(response.result).decode([PitcherPresetSnapshot].self)
        XCTAssertEqual(presets.count, 4)
        XCTAssertTrue(presets.allSatisfy { $0.pitcher.pitchProfiles?.count == 4 })
    }

    func testUnknownMethodReturnsStandardError() throws {
        let response = try decodeResponse(
            server.handle(line: #"{"jsonrpc":"2.0","id":1,"method":"unknown"}"#)
        )

        XCTAssertEqual(response.error?.code, -32601)
        XCTAssertNil(response.result)
    }

    func testMalformedJSONReturnsParseError() throws {
        let response = try decodeResponse(server.handle(line: "not-json"))

        XCTAssertEqual(response.error?.code, -32700)
        XCTAssertEqual(response.id, .null)
    }

    func testSimulatePitchRequestReturnsEvent() throws {
        let params = SimulatePitchParams(
            seed: "20260721",
            pitcher: PitcherSnapshot(
                id: "pitcher-1",
                name: "김도윤",
                stuff: 62,
                command: 54,
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
        let request = RPCRequest(
            id: .string("pitch-1"),
            method: "simulatePitch",
            params: try JSONValue.from(params)
        )
        let encoder = JSONEncoder()
        let requestLine = String(data: try encoder.encode(request), encoding: .utf8)!

        let response = try decodeResponse(server.handle(line: requestLine))
        let result = try XCTUnwrap(response.result).decode(SimulatePitchResult.self)
        let event = try XCTUnwrap(result.events.first)

        XCTAssertEqual(event.eventType, "pitch_resolved")
        XCTAssertFalse(event.eventHash.isEmpty)
        XCTAssertFalse(result.snapshot.shortFeedback.isEmpty)
    }

    func testPrepareAndSubmitPitchRoundTrip() throws {
        let params = makePrepareParams()
        let prepareRequest = RPCRequest(
            id: .string("prepare-1"),
            method: "preparePitch",
            params: try JSONValue.from(params)
        )
        let prepareResponse = try decodeResponse(
            server.handle(line: try encodeRequest(prepareRequest))
        )
        let preparation = try XCTUnwrap(prepareResponse.result).decode(PitchPreparation.self)

        let submit = SubmitPitchParams(
            seed: params.seed,
            pitcher: params.pitcher,
            batter: params.batter,
            scouting: params.scouting,
            context: params.context,
            preparationToken: preparation.preparationToken,
            call: preparation.primaryRecommendation.call
        )
        let submitRequest = RPCRequest(
            id: .string("submit-1"),
            method: "submitPitch",
            params: try JSONValue.from(submit)
        )
        let submitResponse = try decodeResponse(
            server.handle(line: try encodeRequest(submitRequest))
        )
        let result = try XCTUnwrap(submitResponse.result).decode(PitchKernelResult.self)

        XCTAssertEqual(result.revision, 1)
        XCTAssertEqual(result.events.first?.eventType, "batter_plan_committed")
        XCTAssertEqual(result.events[2].eventType, "pitch_call_committed")
        XCTAssertFalse(result.eventHash.isEmpty)
    }

    func testSubmitPitchRejectsInvalidPreparationToken() throws {
        let params = makePrepareParams()
        let submit = SubmitPitchParams(
            seed: params.seed,
            pitcher: params.pitcher,
            batter: params.batter,
            scouting: params.scouting,
            context: params.context,
            preparationToken: "invalid",
            call: PitchCall(
                pitchType: .slider,
                zone: PitchZone(row: 2, column: 0),
                zoneIntent: .edge,
                intensity: .normal
            )
        )
        let request = RPCRequest(
            id: .string("submit-invalid"),
            method: "submitPitch",
            params: try JSONValue.from(submit)
        )

        let response = try decodeResponse(server.handle(line: try encodeRequest(request)))

        XCTAssertEqual(response.error?.code, -32010)
    }

    private func makePrepareParams() -> PreparePitchParams {
        PreparePitchParams(
            seed: "20260721",
            pitcher: PitcherSnapshot(
                id: "pitcher-1",
                name: "김도윤",
                stuff: 62,
                command: 54,
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
            scouting: BatterScoutingSnapshot(
                hotZone: PitchZone(row: 1, column: 1),
                coldZone: PitchZone(row: 2, column: 0),
                pitchStrength: .fourSeam,
                pitchWeakness: .slider,
                chaseTendency: 48
            ),
            context: PlateAppearanceContext(
                plateAppearanceID: "pa-1",
                revision: 0,
                inning: 7,
                outs: 0,
                balls: 1,
                strikes: 1,
                pitchNumber: 1,
                scoreDifferential: 0,
                leverage: 600,
                fatigue: 12
            )
        )
    }

    private func encodeRequest(_ request: RPCRequest) throws -> String {
        let data = try JSONEncoder().encode(request)
        return try XCTUnwrap(String(data: data, encoding: .utf8))
    }

    private func decodeResponse(_ value: String) throws -> RPCResponse {
        try JSONDecoder().decode(RPCResponse.self, from: Data(value.utf8))
    }
}
