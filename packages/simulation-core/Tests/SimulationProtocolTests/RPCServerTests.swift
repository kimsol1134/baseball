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
        XCTAssertEqual(health.protocolVersion, "3.0")
        XCTAssertEqual(health.coreVersion, "1.0.0")
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
        XCTAssertEqual(result.rivalMemory.totalPitchesSeen, 1)
        XCTAssertTrue(result.events.contains { $0.eventType == "rival_memory_updated" })
        XCTAssertEqual(result.gameLog.totalPitches, 1)
        XCTAssertEqual(result.postgameAnalysis.sampleSize, 1)
        XCTAssertTrue(result.events.contains { $0.eventType == "game_analysis_updated" })
        XCTAssertNotNil(result.snapshot.inningTransition)
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

    func testPitcherLabStartAndTrainingRoundTrip() throws {
        let startRequest = RPCRequest(
            id: .string("lab-start"),
            method: "startPitcherLab",
            params: try JSONValue.from(
                StartPitcherLabParams(
                    seed: "20260722",
                    presetID: "power_prospect",
                    inheritedSoulDomain: nil
                )
            )
        )
        let startResponse = try decodeResponse(
            server.handle(line: try encodeRequest(startRequest))
        )
        let start = try XCTUnwrap(startResponse.result).decode(PitcherLabResult.self)

        XCTAssertEqual(start.snapshot.phase, .training)
        XCTAssertEqual(start.snapshot.trainingSessionsCompleted, 0)

        let trainingRequest = RPCRequest(
            id: .string("lab-training"),
            method: "commitTraining",
            params: try JSONValue.from(
                CommitTrainingParams(
                    seed: start.nextSeed,
                    state: start.snapshot,
                    focus: .velocity,
                    intensity: .standard
                )
            )
        )
        let trainingResponse = try decodeResponse(
            server.handle(line: try encodeRequest(trainingRequest))
        )
        let training = try XCTUnwrap(trainingResponse.result).decode(PitcherLabResult.self)

        XCTAssertEqual(training.snapshot.trainingSessionsCompleted, 1)
        XCTAssertEqual(training.events.first?.eventType, "training_session_resolved")
        XCTAssertFalse(training.snapshot.stateCommitment.isEmpty)
    }

    func testHighSchoolCareerStartAndSchoolSelectionRoundTrip() throws {
        let startRequest = RPCRequest(
            id: .string("career-start"),
            method: "startHighSchoolCareer",
            params: try JSONValue.from(
                StartHighSchoolCareerParams(seed: "20260723", presetID: "precision_commander")
            )
        )
        let startResponse = try decodeResponse(server.handle(line: try encodeRequest(startRequest)))
        let start = try XCTUnwrap(startResponse.result).decode(HighSchoolCareerResult.self)
        XCTAssertEqual(start.snapshot.phase, .prologue)
        XCTAssertEqual(start.snapshot.schoolOptions.count, 4)

        let prologueRequest = RPCRequest(
            id: .string("career-prologue"),
            method: "completeMiddleSchoolPrologue",
            params: try JSONValue.from(
                AdvanceCareerChapterParams(seed: start.nextSeed, state: start.snapshot)
            )
        )
        let prologueResponse = try decodeResponse(server.handle(line: try encodeRequest(prologueRequest)))
        let prologue = try XCTUnwrap(prologueResponse.result).decode(HighSchoolCareerResult.self)
        XCTAssertEqual(prologue.snapshot.phase, .schoolSelection)

        let schoolRequest = RPCRequest(
            id: .string("career-school"),
            method: "chooseSchool",
            params: try JSONValue.from(
                ChooseSchoolParams(
                    seed: prologue.nextSeed,
                    state: prologue.snapshot,
                    schoolID: .miraeAnalytics
                )
            )
        )
        let schoolResponse = try decodeResponse(server.handle(line: try encodeRequest(schoolRequest)))
        let school = try XCTUnwrap(schoolResponse.result).decode(HighSchoolCareerResult.self)
        XCTAssertEqual(school.snapshot.phase, .training)
        XCTAssertEqual(school.snapshot.school?.id, .miraeAnalytics)
    }

    func testProCareerStartAndContractRoundTrip() throws {
        let draft = DraftResultSnapshot(outcome: .drafted, evaluationScore: 72, projectedRange: "2~3라운드", team: ProCareerEngine.proTeams[0], round: 2, overallPick: 18, signingBonus: 120_000_000, firstSeasonGoal: "2군 선발", summary: "지명")
        let params = StartProCareerParams(seed: "77", identity: .defaultPitcher, pitcher: PitcherSnapshot(id: "p", name: "김도윤", stuff: 58, command: 56, movement: 55, stamina: 57), draftResult: draft, entitlement: ProEntitlementSnapshot(status: .active, source: .development, verifiedAt: "2026-07-22"))
        let start = try decodeResponse(server.handle(line: try encodeRequest(RPCRequest(id: .string("pro-start"), method: "startProCareer", params: try JSONValue.from(params)))))
        let result = try XCTUnwrap(start.result).decode(ProCareerResult.self)
        XCTAssertEqual(result.snapshot.phase, .contractOffer)
        let signed = try decodeResponse(server.handle(line: try encodeRequest(RPCRequest(id: .string("pro-sign"), method: "signProContract", params: try JSONValue.from(ProStateParams(seed: result.nextSeed, state: result.snapshot))))))
        XCTAssertEqual(try XCTUnwrap(signed.result).decode(ProCareerResult.self).snapshot.phase, .weeklyPlan)
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
