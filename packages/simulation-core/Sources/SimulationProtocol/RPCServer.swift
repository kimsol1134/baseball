import Foundation
import SimulationCore

public struct RPCServer: Sendable {
    private let engine: SimulationEngine
    private let pitchKernel: PitchKernelEngine
    private let pitcherLab: PitcherLabEngine
    private let highSchoolCareer: HighSchoolCareerEngine
    private let proCareer: ProCareerEngine

    public init(
        engine: SimulationEngine = SimulationEngine(),
        pitchKernel: PitchKernelEngine = PitchKernelEngine(),
        pitcherLab: PitcherLabEngine = PitcherLabEngine(),
        highSchoolCareer: HighSchoolCareerEngine = HighSchoolCareerEngine(),
        proCareer: ProCareerEngine = ProCareerEngine()
    ) {
        self.engine = engine
        self.pitchKernel = pitchKernel
        self.pitcherLab = pitcherLab
        self.highSchoolCareer = highSchoolCareer
        self.proCareer = proCareer
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
                    protocolVersion: "3.0",
                    coreVersion: "1.0.0"
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
            case "startPitcherLab":
                let params = try decode(StartPitcherLabParams.self, from: request)
                let result = try pitcherLab.start(params)
                response = RPCResponse(id: request.id, result: try JSONValue.from(result))
            case "commitTraining":
                let params = try decode(CommitTrainingParams.self, from: request)
                let result = try pitcherLab.commitTraining(params)
                response = RPCResponse(id: request.id, result: try JSONValue.from(result))
            case "recordImportantInning":
                let params = try decode(RecordImportantInningParams.self, from: request)
                let result = try pitcherLab.recordImportantInning(params)
                response = RPCResponse(id: request.id, result: try JSONValue.from(result))
            case "chooseRelationship":
                let params = try decode(ChooseRelationshipParams.self, from: request)
                let result = try pitcherLab.chooseRelationship(params)
                response = RPCResponse(id: request.id, result: try JSONValue.from(result))
            case "chooseAwakening":
                let params = try decode(ChooseAwakeningParams.self, from: request)
                let result = try pitcherLab.chooseAwakening(params)
                response = RPCResponse(id: request.id, result: try JSONValue.from(result))
            case "finalizeScouting":
                let params = try decode(FinalizeScoutingParams.self, from: request)
                let result = try pitcherLab.finalizeScouting(params)
                response = RPCResponse(id: request.id, result: try JSONValue.from(result))
            case "selectLegacy":
                let params = try decode(SelectLegacyParams.self, from: request)
                let result = try pitcherLab.selectLegacy(params)
                response = RPCResponse(id: request.id, result: try JSONValue.from(result))
            case "startHighSchoolCareer":
                let params = try decode(StartHighSchoolCareerParams.self, from: request)
                response = RPCResponse(id: request.id, result: try JSONValue.from(try highSchoolCareer.start(params)))
            case "completeMiddleSchoolPrologue":
                let params = try decode(AdvanceCareerChapterParams.self, from: request)
                response = RPCResponse(id: request.id, result: try JSONValue.from(try highSchoolCareer.completePrologue(params)))
            case "normalizeRegionalSchools":
                let params = try decode(AdvanceCareerChapterParams.self, from: request)
                response = RPCResponse(id: request.id, result: try JSONValue.from(try highSchoolCareer.normalizeRegionalSchools(params)))
            case "chooseSchool":
                let params = try decode(ChooseSchoolParams.self, from: request)
                response = RPCResponse(id: request.id, result: try JSONValue.from(try highSchoolCareer.chooseSchool(params)))
            case "commitCareerTraining":
                let params = try decode(CommitCareerTrainingParams.self, from: request)
                response = RPCResponse(id: request.id, result: try JSONValue.from(try highSchoolCareer.commitTraining(params)))
            case "resolveCareerRelationship":
                let params = try decode(ResolveCareerRelationshipParams.self, from: request)
                response = RPCResponse(id: request.id, result: try JSONValue.from(try highSchoolCareer.resolveRelationship(params)))
            case "recordCareerGame":
                let params = try decode(RecordCareerGameParams.self, from: request)
                response = RPCResponse(id: request.id, result: try JSONValue.from(try highSchoolCareer.recordImportantGame(params)))
            case "chooseCareerAwakening":
                let params = try decode(ChooseCareerAwakeningParams.self, from: request)
                response = RPCResponse(id: request.id, result: try JSONValue.from(try highSchoolCareer.chooseAwakening(params)))
            case "advanceCareerChapter":
                let params = try decode(AdvanceCareerChapterParams.self, from: request)
                response = RPCResponse(id: request.id, result: try JSONValue.from(try highSchoolCareer.advanceChapter(params)))
            case "resolveDraft":
                let params = try decode(ResolveDraftParams.self, from: request)
                response = RPCResponse(id: request.id, result: try JSONValue.from(try highSchoolCareer.resolveDraft(params)))
            case "selectCareerLegacy":
                let params = try decode(SelectCareerLegacyParams.self, from: request)
                response = RPCResponse(id: request.id, result: try JSONValue.from(try highSchoolCareer.selectLegacy(params)))
            case "startProCareer":
                let params = try decode(StartProCareerParams.self, from: request)
                response = RPCResponse(id: request.id, result: try JSONValue.from(try proCareer.start(params)))
            case "signProContract":
                let params = try decode(ProStateParams.self, from: request)
                response = RPCResponse(id: request.id, result: try JSONValue.from(try proCareer.signContract(params)))
            case "planProWeek":
                let params = try decode(PlanProWeekParams.self, from: request)
                response = RPCResponse(id: request.id, result: try JSONValue.from(try proCareer.planWeek(params)))
            case "resolveProImportantGame":
                let params = try decode(ResolveProGameParams.self, from: request)
                response = RPCResponse(id: request.id, result: try JSONValue.from(try proCareer.resolveImportantGame(params)))
            case "reviewProSeason":
                let params = try decode(ProStateParams.self, from: request)
                response = RPCResponse(id: request.id, result: try JSONValue.from(try proCareer.reviewSeason(params)))
            case "chooseProOffseason":
                let params = try decode(ProOffseasonParams.self, from: request)
                response = RPCResponse(id: request.id, result: try JSONValue.from(try proCareer.chooseOffseason(params)))
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

    private func decode<T: Decodable>(_ type: T.Type, from request: RPCRequest) throws -> T {
        guard let rawParams = request.params else {
            throw SimulationError.invalidPitcherLab("missing RPC params")
        }
        return try rawParams.decode(type)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
