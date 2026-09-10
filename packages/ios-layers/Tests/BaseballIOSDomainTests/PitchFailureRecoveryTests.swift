import XCTest
@testable import BaseballIOSDomain

/// 7-B·7-C. 실패한 투구에서 나가는 길은 **저장이 어떻게 됐는지**가 정한다.
final class PitchFailureRecoveryTests: XCTestCase {
    /// 디스크가 기대한 리비전에 닿았으면 결과는 남아 있다.
    func testRecoveryReadsTheSavedRevisionNotTheHopedOne() {
        XCTAssertEqual(
            PitchFailureRecoveryRules.recovery(savedRevision: 12, expectedRevision: 12),
            .saved
        )
        // 저장이 앞서 있어도 기대분은 들어간 것이다.
        XCTAssertEqual(
            PitchFailureRecoveryRules.recovery(savedRevision: 13, expectedRevision: 12),
            .saved
        )
        XCTAssertEqual(
            PitchFailureRecoveryRules.recovery(savedRevision: 11, expectedRevision: 12),
            .uncertain
        )
    }

    /// **결과가 커밋된 투구는 포기로 보내지 않는다.** 포기시키면 이미 기록된 이닝을
    /// 사용자가 스스로 버리게 된다.
    func testACommittedResultGoesToConfirmationNotAbandon() {
        let diagnosis = PitchFailureDiagnosis(
            step: .commit,
            correlationID: "c1",
            sessionID: "s1",
            pitchID: "p9",
            commandID: "cmd-1",
            expectedRevision: 12,
            currentRevision: 12,
            failure: .init(kind: .io, code: "NSCocoaErrorDomain.512"),
            recovery: .saved
        )
        XCTAssertEqual(
            PitchSessionTransitionRules.exit(for: diagnosis, hasSavedResume: false, pitchesThrown: 18),
            .confirmResult
        )
    }

    /// 미확정이면 되돌아가 확인한다 — 남은 이닝이 있으면 이어하기다.
    func testAnUncertainCommitOffersResumeWhenPitchesExist() {
        let diagnosis = PitchFailureDiagnosis(
            step: .commit,
            correlationID: "c2",
            sessionID: "s1",
            pitchID: "p9",
            expectedRevision: 12,
            currentRevision: 11,
            failure: .init(kind: .storageFull, code: "ENOSPC"),
            recovery: .uncertain
        )
        XCTAssertEqual(
            PitchSessionTransitionRules.exit(for: diagnosis, hasSavedResume: true, pitchesThrown: 18),
            .resume
        )
    }

    /// 준비 단계에서 무너진 첫 공은 버릴 것이 없다.
    func testNothingThrownYetCanSimplyBeAbandoned() {
        let diagnosis = PitchFailureDiagnosis(
            step: .prepare,
            correlationID: "c3",
            sessionID: "s1",
            pitchID: "p1",
            expectedRevision: 4,
            currentRevision: 4,
            failure: .init(kind: .rule, code: "rule.pitch"),
            recovery: .uncertain
        )
        XCTAssertEqual(
            PitchSessionTransitionRules.exit(for: diagnosis, hasSavedResume: false, pitchesThrown: 0),
            .abandon
        )
    }

    /// 저장이 확인돼도 **커밋 단계가 아니면** 결과 확인이 아니다 — 준비 중 실패는
    /// 아직 반영할 결과 자체가 없다.
    func testASavedRevisionOutsideTheCommitStepIsNotAResult() {
        let diagnosis = PitchFailureDiagnosis(
            step: .prepare,
            correlationID: "c4",
            sessionID: "s1",
            pitchID: "p3",
            expectedRevision: 4,
            currentRevision: 4,
            failure: .init(kind: .rule, code: "rule.pitch"),
            recovery: .saved
        )
        XCTAssertEqual(
            PitchSessionTransitionRules.exit(for: diagnosis, hasSavedResume: true, pitchesThrown: 6),
            .resume
        )
    }

    /// 진단은 로그에서 이어 붙일 수 있어야 한다 — 단계·끈·ID·리비전이 전부 실린다.
    func testDiagnosisCarriesEverythingALogNeeds() {
        let diagnosis = PitchFailureDiagnosis(
            step: .submit,
            correlationID: "corr-7",
            sessionID: "sess-3",
            pitchID: "pitch-11",
            commandID: "cmd-2",
            expectedRevision: 30,
            currentRevision: 29,
            failure: .init(kind: .io, code: "x"),
            recovery: .uncertain
        )
        let properties = diagnosis.analyticsProperties
        for key in [
            "step", "correlation_id", "session_id", "pitch_id", "command_id",
            "expected_revision", "current_revision", "failure_kind", "failure_code", "recovery",
        ] {
            XCTAssertNotNil(properties[key], key)
        }
        XCTAssertEqual(properties["expected_revision"] as? Int, 30)
    }
}
