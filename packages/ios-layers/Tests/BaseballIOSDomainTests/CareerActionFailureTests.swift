import XCTest
import SimulationCore
@testable import BaseballIOSDomain

/// 7-A. **규칙 거절을 저장 실패로 부르지 않는다.** 공간 부족은 근거가 있을 때만이다.
///
/// 1.2.x "저장공간" 리뷰가 이 검사의 이유다 — 규칙이 막은 일에도, 쓰기가 금지된 저장본에도
/// 화면은 "저장 공간을 확보해 주세요"라고 말했다.
final class CareerActionFailureTests: XCTestCase {
    func testKernelRejectionIsNeverAStorageFailure() {
        let rejections: [SimulationError] = [
            .invalidProCareer("적용할 시즌 결정이 없습니다."),
            .invalidPitcherLab("starting repertoire requires a complete pitch profile catalog"),
            .invalidProCareer("이미 적용한 시즌 결정입니다."),
        ]
        for error in rejections {
            let failure = CareerActionFailureRules.classify(error)
            XCTAssertFalse(failure.kind.isStorageFailure, "\(error)")
            XCTAssertNotEqual(failure.kind, .storageFull, "\(error)")
            XCTAssertNotEqual(failure.kind, .io, "\(error)")
        }
    }

    /// 커널 문장을 코드로 그대로 싣지 않는다 — 한국어 문장은 카디널리티가 무한하다.
    func testRuleCodesStayLowCardinality() {
        let codes = Set(
            [
                SimulationError.invalidProCareer("가"),
                .invalidProCareer("나"),
                .invalidPitcherLab("다"),
            ].map { CareerActionFailureRules.classify($0).code }
        )
        XCTAssertEqual(codes, ["rule.pro", "rule.high_school"])
    }

    /// 공간 부족은 Cocoa/POSIX가 그렇게 말했을 때만.
    func testOutOfSpaceNeedsExplicitEvidence() {
        let enospc = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)
        XCTAssertEqual(SaveWriteFailure.from(enospc), .outOfSpace)
        XCTAssertEqual(
            SaveWriteFailure.from(NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))),
            .outOfSpace
        )
        // 하위 오류에 진짜 이유가 들어 있어도 찾는다.
        let wrapped = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileWriteUnknownError,
            userInfo: [NSUnderlyingErrorKey: enospc]
        )
        XCTAssertEqual(SaveWriteFailure.from(wrapped), .outOfSpace)

        // 권한 오류는 공간 부족이 아니다.
        let denied = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)
        XCTAssertNotEqual(SaveWriteFailure.from(denied), .outOfSpace)
        XCTAssertEqual(
            CareerActionFailureRules.classify(write: SaveWriteFailure.from(denied)).kind,
            .io
        )
    }

    /// 쓰기가 막힌 저장본은 디스크 문제가 아니다. 공간을 비워도 풀리지 않는다.
    func testWriteDisabledIsNotAStorageProblem() {
        let failure = CareerActionFailureRules.classify(writeDisabled: true)
        XCTAssertEqual(failure.kind, .writeDisabled)
        XCTAssertFalse(failure.kind.isStorageFailure)
    }

    func testEncodeFailureIsValidationNotDisk() {
        let failure = CareerActionFailureRules.classify(encodeFailed: true)
        XCTAssertEqual(failure.kind, .saveValidation)
        XCTAssertFalse(failure.kind.isStorageFailure)
    }

    /// 커널 오류가 있으면 그것이 진실이다 — 저장에 닿기 전에 멈춘 일이다.
    func testKernelErrorWinsOverALaterWriteGuess() {
        let failure = CareerActionFailureRules.classify(
            error: SimulationError.invalidProCareer("한 시즌에는 일곱 번까지만 결정할 수 있습니다."),
            write: .outOfSpace,
            writeDisabled: true
        )
        XCTAssertEqual(failure.kind, .rule)
    }

    /// 저장 계열 실패만 반복으로 센다. 규칙 거절은 되풀이돼도 정상이다.
    func testRepetitionOnlyCountsStorageFailures() {
        var repetition = CareerActionFailureRepetition()
        let io = CareerActionFailure(kind: .io, code: "NSCocoaErrorDomain.512")
        XCTAssertFalse(repetition.record(operation: "planWeek", failure: io, revision: 7))
        XCTAssertTrue(repetition.record(operation: "planWeek", failure: io, revision: 7))
        // 리비전이 움직였으면 다른 실패다.
        XCTAssertFalse(repetition.record(operation: "planWeek", failure: io, revision: 8))

        let rule = CareerActionFailure(kind: .rule, code: "rule.pro")
        XCTAssertFalse(repetition.record(operation: "planWeek", failure: rule, revision: 8))
        XCTAssertFalse(repetition.record(operation: "planWeek", failure: rule, revision: 8))
    }

    /// 규칙 실패가 끼면 반복 기억이 끊긴다 — 연속된 저장 실패만 이어서 센다.
    func testARuleFailureResetsTheStorageStreak() {
        var repetition = CareerActionFailureRepetition()
        let io = CareerActionFailure(kind: .io, code: "x")
        _ = repetition.record(operation: "a", failure: io, revision: 1)
        _ = repetition.record(operation: "a", failure: .init(kind: .rule, code: "rule.pro"), revision: 1)
        XCTAssertFalse(repetition.record(operation: "a", failure: io, revision: 1))
    }
}
