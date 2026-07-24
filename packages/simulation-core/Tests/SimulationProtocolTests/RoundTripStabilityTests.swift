import XCTest
@testable import SimulationCore
@testable import SimulationProtocol

// 회귀 가드: 거대 스냅숏의 JSONValue 왕복과 전체 RPC 시퀀스가 힙 손상 없이 완료돼야 한다.
// (2026-07-24 CareerScheduleSnapshot 인라인 배열의 outlined destroy 크래시 회귀 방지)
final class RoundTripStabilityTests: XCTestCase {
    func testSnapshotJSONValueRoundTripDoesNotCrash() throws {
        let engine = HighSchoolCareerEngine()
        let result = try engine.start(StartHighSchoolCareerParams(seed: "20260723", presetID: "precision_commander"))
        let encoded = try JSONValue.from(result)
        let decoded = try encoded.decode(HighSchoolCareerResult.self)
        print("REPRO phase=\(decoded.snapshot.phase) schools=\(decoded.snapshot.schoolOptions.count)")
        let same = decoded.snapshot == result.snapshot
        print("REPRO equal=\(same)")
    }

    func testFullRPCSequenceStepByStep() throws {
        let server = RPCServer()
        func call(_ method: String, _ params: JSONValue) throws -> HighSchoolCareerResult {
            let req = RPCRequest(id: .string(method), method: method, params: params)
            let data = try JSONEncoder().encode(req)
            let line = String(data: data, encoding: .utf8)!
            let out = server.handle(line: line)
            let resp = try JSONDecoder().decode(RPCResponse.self, from: out.data(using: .utf8)!)
            return try resp.result!.decode(HighSchoolCareerResult.self)
        }
        print("STEP start")
        let start = try call("startHighSchoolCareer", try JSONValue.from(StartHighSchoolCareerParams(seed: "20260723", presetID: "precision_commander")))
        print("STEP start ok phase=\(start.snapshot.phase)")
        let prologue = try call("completeMiddleSchoolPrologue", try JSONValue.from(AdvanceCareerChapterParams(seed: start.nextSeed, state: start.snapshot)))
        print("STEP prologue ok phase=\(prologue.snapshot.phase)")
        let schoolID = prologue.snapshot.schoolOptions[0].id
        let school = try call("chooseSchool", try JSONValue.from(ChooseSchoolParams(seed: prologue.nextSeed, state: prologue.snapshot, schoolID: schoolID)))
        print("STEP school ok phase=\(school.snapshot.phase) school=\(school.snapshot.school?.name ?? "-")")
        print("STEP compare start")
        let equal = school.snapshot == school.snapshot
        print("STEP compare ok \(equal)")
    }
}
