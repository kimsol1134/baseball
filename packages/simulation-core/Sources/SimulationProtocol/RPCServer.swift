import Foundation
import SimulationCore

public struct RPCServer: Sendable {
    private let engine: SimulationEngine
    private let pitchKernel: PitchKernelEngine

    public init(
        engine: SimulationEngine = SimulationEngine(),
        pitchKernel: PitchKernelEngine = PitchKernelEngine()
    ) {
        self.engine = engine
        self.pitchKernel = pitchKernel
    }

    public func handle(line: String) -> String {
        let encoder = Self.makeEncoder()
        let request: RPCRequest

        do {
            request = try JSONDecoder().decode(RPCRequest.self, from: Data(line.utf8))
        } catch {
            return encode(
                RPCResponse(
                    id: .null,
                    error: RPCError(code: -32700, message: "Parse error")
                ),
                with: encoder
            )
        }

        guard request.jsonrpc == "2.0" else {
            return encode(
                RPCResponse(
                    id: request.id,
                    error: RPCError(code: -32600, message: "Invalid Request")
                ),
                with: encoder
            )
        }

        do {
            let response: RPCResponse
            switch request.method {
            case "health":
                let health = HealthResult(
                    status: "ok",
                    protocolVersion: "1.4",
                    coreVersion: "0.5.0"
                )
                response = RPCResponse(id: request.id, result: try JSONValue.from(health))
            case "listPitcherPresets":
                response = RPCResponse(
                    id: request.id,
                    result: try JSONValue.from(PitcherPresetCatalog.all)
                )
            case "simulatePitch":
                guard let rawParams = request.params else {
                    return encode(
                        RPCResponse(
                            id: request.id,
                            error: RPCError(code: -32602, message: "Invalid params")
                        ),
                        with: encoder
                    )
                }
                let params = try rawParams.decode(SimulatePitchParams.self)
                let result = try engine.simulatePitch(params)
                response = RPCResponse(id: request.id, result: try JSONValue.from(result))
            case "preparePitch":
                guard let rawParams = request.params else {
                    return encode(
                        RPCResponse(
                            id: request.id,
                            error: RPCError(code: -32602, message: "Invalid params")
                        ),
                        with: encoder
                    )
                }
                let params = try rawParams.decode(PreparePitchParams.self)
                let result = try pitchKernel.preparePitch(params)
                response = RPCResponse(id: request.id, result: try JSONValue.from(result))
            case "submitPitch":
                guard let rawParams = request.params else {
                    return encode(
                        RPCResponse(
                            id: request.id,
                            error: RPCError(code: -32602, message: "Invalid params")
                        ),
                        with: encoder
                    )
                }
                let params = try rawParams.decode(SubmitPitchParams.self)
                let result = try pitchKernel.submitPitch(params)
                response = RPCResponse(id: request.id, result: try JSONValue.from(result))
            default:
                response = RPCResponse(
                    id: request.id,
                    error: RPCError(code: -32601, message: "Method not found")
                )
            }
            return encode(response, with: encoder)
        } catch SimulationError.invalidPreparationToken {
            return encode(
                RPCResponse(
                    id: request.id,
                    error: RPCError(
                        code: -32010,
                        message: "Invalid preparation token",
                        data: .string("Prepare the pitch again before submitting a call")
                    )
                ),
                with: encoder
            )
        } catch let error as SimulationError {
            return encode(
                RPCResponse(
                    id: request.id,
                    error: RPCError(
                        code: -32602,
                        message: "Invalid params",
                        data: .string(error.localizedDescription)
                    )
                ),
                with: encoder
            )
        } catch {
            return encode(
                RPCResponse(
                    id: request.id,
                    error: RPCError(code: -32603, message: "Internal error")
                ),
                with: encoder
            )
        }
    }

    private func encode(_ response: RPCResponse, with encoder: JSONEncoder) -> String {
        guard let data = try? encoder.encode(response),
              let value = String(data: data, encoding: .utf8) else {
            return #"{"error":{"code":-32603,"message":"Internal error"},"id":null,"jsonrpc":"2.0"}"#
        }
        return value
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
