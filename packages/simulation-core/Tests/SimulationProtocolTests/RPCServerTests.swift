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
        XCTAssertEqual(health.protocolVersion, "1.0")
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

    private func decodeResponse(_ value: String) throws -> RPCResponse {
        try JSONDecoder().decode(RPCResponse.self, from: Data(value.utf8))
    }
}
