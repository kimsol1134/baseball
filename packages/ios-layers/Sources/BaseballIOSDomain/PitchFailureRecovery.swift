import Foundation

/// 투구가 실패한 자리와 그때 알고 있던 것 전부.
///
/// 예전에는 `stage = .failed(error.localizedDescription)`가 전부였다. 화면에는 커널의 영어
/// 설명 한 줄만 남고, **던진 공이 저장됐는지 아닌지**를 아무도 알 수 없었다. 그래서 유일한
/// 출구가 "포기"였고, 이미 커밋된 이닝을 포기로 버리는 일이 생겼다(7-B).
public struct PitchFailureDiagnosis: Equatable, Sendable {
    /// 어느 단계에서 무너졌는가.
    public enum Step: String, Sendable, CaseIterable {
        /// 다음 공을 준비하는 중.
        case prepare
        /// 던진 공을 판정하는 중.
        case submit
        /// 결과를 커리어에 반영하는 중.
        case commit
        /// 저장된 이닝을 다시 여는 중.
        case resume
    }

    /// 저장 파일을 **다시 읽어** 확인한 결과.
    public enum Recovery: String, Sendable {
        /// 디스크가 기대한 리비전에 도달했다 — 결과를 확인하면 된다.
        case saved
        /// 도달하지 못했다 — 무엇이 남았는지 모른다. 되돌아가 확인한다.
        case uncertain
    }

    public let step: Step
    /// 이 실패 한 건을 로그에서 이어 붙이는 끈.
    public let correlationID: String
    public let sessionID: String
    public let pitchID: String
    /// 저장 트랜잭션에 실린 명령 ID. 준비 단계 실패에는 없다.
    public let commandID: String?
    public let expectedRevision: UInt64
    public let currentRevision: UInt64
    public let failure: CareerActionFailure
    public let recovery: Recovery

    public init(
        step: Step,
        correlationID: String,
        sessionID: String,
        pitchID: String,
        commandID: String? = nil,
        expectedRevision: UInt64,
        currentRevision: UInt64,
        failure: CareerActionFailure,
        recovery: Recovery
    ) {
        self.step = step
        self.correlationID = correlationID
        self.sessionID = sessionID
        self.pitchID = pitchID
        self.commandID = commandID
        self.expectedRevision = expectedRevision
        self.currentRevision = currentRevision
        self.failure = failure
        self.recovery = recovery
    }

    /// 텔레메트리에 실을 저카디널리티 속성. 사람이 쓴 문장은 싣지 않는다.
    public var analyticsProperties: [String: Any] {
        var properties: [String: Any] = [
            "step": step.rawValue,
            "correlation_id": correlationID,
            "session_id": sessionID,
            "pitch_id": pitchID,
            "expected_revision": Int(clamping: expectedRevision),
            "current_revision": Int(clamping: currentRevision),
            "failure_kind": failure.kind.rawValue,
            "failure_code": failure.code,
            "recovery": recovery.rawValue,
        ]
        if let commandID { properties["command_id"] = commandID }
        return properties
    }
}

public enum PitchFailureRecoveryRules {
    /// 저장이 기대한 리비전에 닿았는가.
    ///
    /// 실패 **뒤에 다시 읽은** 값으로만 판단한다. 실패 직전에 들고 있던 값은 이 질문에
    /// 답하지 못한다 — 쓰기가 성공한 뒤 그 다음 단계에서 무너졌을 수 있다.
    public static func recovery(
        savedRevision: UInt64,
        expectedRevision: UInt64
    ) -> PitchFailureDiagnosis.Recovery {
        savedRevision >= expectedRevision ? .saved : .uncertain
    }
}

/// 투구를 떠나는 세 가지 방법. 중단·재개·포기 규칙을 여기 한 곳에서 정한다(7-C).
public enum PitchSessionExit: String, Sendable, CaseIterable {
    /// 결과가 이미 저장에 커밋됐다. **포기가 아니라 결과 확인으로 보낸다** — 포기시키면
    /// 이미 기록된 이닝을 사용자가 스스로 버리는 셈이 된다.
    case confirmResult
    /// 저장된 이닝이 남아 있고 이어서 던질 수 있다.
    case resume
    /// 커밋된 것이 없다. 중단해도 잃을 기록이 없다.
    case abandon
}

public enum PitchSessionTransitionRules {
    /// 지금 이 세션에서 열어 줘야 하는 출구.
    ///
    /// - Parameters:
    ///   - resultCommitted: 이 등판의 결과가 저장에 반영됐는가.
    ///   - hasSavedResume: 디스크에 이어할 이닝이 남아 있는가.
    ///   - pitchesThrown: 이 세션에서 던진 공.
    public static func exit(
        resultCommitted: Bool,
        hasSavedResume: Bool,
        pitchesThrown: Int
    ) -> PitchSessionExit {
        if resultCommitted { return .confirmResult }
        if hasSavedResume || pitchesThrown > 0 { return .resume }
        return .abandon
    }

    /// 실패 진단에서 곧장 출구를 고른다. 저장이 확인되면 결과 확인이다.
    public static func exit(
        for diagnosis: PitchFailureDiagnosis,
        hasSavedResume: Bool,
        pitchesThrown: Int
    ) -> PitchSessionExit {
        exit(
            resultCommitted: diagnosis.recovery == .saved && diagnosis.step == .commit,
            hasSavedResume: hasSavedResume,
            pitchesThrown: pitchesThrown
        )
    }
}
