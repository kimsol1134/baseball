import Foundation
import SimulationCore

/// 저장 쓰기가 실패한 **증거**.
///
/// 예전에는 `write`가 `Bool`만 돌려줘서, 화면은 실패의 이유를 하나도 알지 못한 채
/// "저장 공간을 확인해 주세요"라고 말했다. 규칙이 거절했을 때도, 쓰기가 막혔을 때도,
/// 인코딩이 실패했을 때도 같은 문장이었다(1.2.x "저장공간" 리뷰).
public enum SaveWriteFailure: Equatable, Sendable {
    /// 디스크가 가득 찼다는 **명시적 근거**가 있을 때만.
    case outOfSpace
    /// 그 밖의 파일 오류. 원인 코드를 그대로 싣는다.
    case io(code: String)

    /// `NSError`에서 근거를 읽는다. 공간 부족은 Cocoa/POSIX가 그렇게 말했을 때만이다.
    public static func from(_ error: Error) -> SaveWriteFailure {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileWriteOutOfSpaceError {
            return .outOfSpace
        }
        if nsError.domain == NSPOSIXErrorDomain, nsError.code == Int(ENOSPC) {
            return .outOfSpace
        }
        // 하위 오류에 진짜 이유가 들어 있는 경우가 많다.
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            let inner = from(underlying)
            if inner == .outOfSpace { return .outOfSpace }
        }
        return .io(code: "\(nsError.domain).\(nsError.code)")
    }
}

/// 실패 하나를 여덟 갈래로 나눈다.
///
/// 규칙이 거절한 일을 저장 실패로 부르지 않는 것이 이 타입의 존재 이유다. 플레이어에게
/// "저장 공간을 확보하라"고 말하려면 **공간이 부족하다는 근거**가 있어야 한다.
public enum CareerActionFailureKind: String, Sendable, CaseIterable {
    /// 규칙이 거절했다. 저장과 무관하다.
    case rule
    /// 다른 곳에서 진행이 바뀌었다.
    case staleState
    /// 투구가 끝나지 않은 상태다.
    case pitchState
    /// 디스크가 가득 찼다 — 명시적 근거가 있을 때만.
    case storageFull
    /// 그 밖의 파일 오류.
    case io
    /// 저장 레코드를 만들거나 검증하지 못했다.
    case saveValidation
    /// 이 실행 환경/저장본에서는 쓰기가 막혀 있다.
    case writeDisabled
    /// 원인을 특정하지 못했다.
    case unknown

    /// 저장 공간·파일 문제로 셈해도 되는가. 규칙 거절과 쓰기 금지는 여기 들어가지 않는다.
    public var isStorageFailure: Bool { self == .io || self == .storageFull }
}

public struct CareerActionFailure: Equatable, Sendable {
    public let kind: CareerActionFailureKind
    /// 로그와 텔레메트리에 남길 저카디널리티 코드. 사람이 읽는 문장이 아니다.
    public let code: String

    public init(kind: CareerActionFailureKind, code: String) {
        self.kind = kind
        self.code = code
    }
}

public enum CareerActionFailureRules {
    /// 커널 오류·쓰기 실패·게이트를 하나의 갈래로 모은다.
    ///
    /// 우선순위가 중요하다. **커널이 거절했으면 그것이 진실이다** — 뒤이어 저장을 시도하지
    /// 않았으므로 저장 실패로 부를 근거가 없다.
    public static func classify(
        error: Error? = nil,
        write: SaveWriteFailure? = nil,
        writeDisabled: Bool = false,
        encodeFailed: Bool = false,
        staleRevision: Bool = false
    ) -> CareerActionFailure {
        if let error {
            return classify(error)
        }
        if writeDisabled {
            return CareerActionFailure(kind: .writeDisabled, code: "write_disabled")
        }
        if encodeFailed {
            return CareerActionFailure(kind: .saveValidation, code: "encode_failed")
        }
        if staleRevision {
            return CareerActionFailure(kind: .staleState, code: "stale_revision")
        }
        switch write {
        case .outOfSpace:
            return CareerActionFailure(kind: .storageFull, code: "ENOSPC")
        case .io(let code):
            return CareerActionFailure(kind: .io, code: code)
        case nil:
            return CareerActionFailure(kind: .unknown, code: "unknown")
        }
    }

    /// 커널이 던진 오류의 갈래. 시뮬레이션 오류는 **전부 규칙 쪽**이다 — 저장에 닿기 전에
    /// 멈춘 일이라 디스크를 의심할 이유가 없다.
    public static func classify(_ error: Error) -> CareerActionFailure {
        guard let simulation = error as? SimulationError else {
            let nsError = error as NSError
            let write = SaveWriteFailure.from(error)
            if write == .outOfSpace {
                return CareerActionFailure(kind: .storageFull, code: "ENOSPC")
            }
            if nsError.domain == NSCocoaErrorDomain || nsError.domain == NSPOSIXErrorDomain {
                return CareerActionFailure(kind: .io, code: "\(nsError.domain).\(nsError.code)")
            }
            return CareerActionFailure(kind: .unknown, code: "unknown")
        }
        let reason = reasonText(simulation)
        if reason.hasPrefix("pitch.") || reason.contains("투구") {
            return CareerActionFailure(kind: .pitchState, code: "pitch.state")
        }
        if reason.contains("stale") || reason.contains("revision") {
            return CareerActionFailure(kind: .staleState, code: "stale_revision")
        }
        return CareerActionFailure(kind: .rule, code: ruleCode(simulation))
    }

    private static func reasonText(_ error: SimulationError) -> String {
        switch error {
        case .invalidProCareer(let value), .invalidPitcherLab(let value),
             .invalidPlateAppearance(let value), .invalidScouting(let value),
             .invalidPitchProfile(let value), .invalidPitchDelivery(let value),
             .invalidRivalMemory(let value), .invalidGameState(let value),
             .invalidGameLog(let value), .invalidSeed(let value):
            return value
        default:
            return error.errorDescription ?? "unknown"
        }
    }

    /// 텔레메트리에 실을 저카디널리티 코드. 커널 문장을 그대로 싣지 않는다 —
    /// 사람이 쓴 한국어 문장은 카디널리티가 무한하고 번역도 되지 않는다.
    private static func ruleCode(_ error: SimulationError) -> String {
        switch error {
        case .invalidSeed: return "rule.seed"
        case .invalidProCareer: return "rule.pro"
        case .invalidPitcherLab: return "rule.high_school"
        case .invalidPitchDelivery, .invalidPitchProfile, .invalidPreparationToken:
            return "rule.pitch"
        case .invalidGameState, .invalidGameLog, .invalidPlateAppearance:
            return "rule.game"
        default:
            return "rule.other"
        }
    }
}

/// 같은 실패가 같은 자리에서 되풀이되는지 기억한다.
///
/// 두 번째부터는 다른 말을 해야 한다 — 같은 문장을 반복하면 플레이어는 앱이 멈췄다고
/// 읽는다. **저장 계열 실패만** 센다. 규칙 거절은 반복돼도 정상이다.
public struct CareerActionFailureRepetition {
    private struct Key: Equatable {
        let operation: String
        let failure: CareerActionFailure
        let revision: UInt64
    }

    private var previous: Key?

    public init() {}

    public mutating func clear() { previous = nil }

    /// 방금 실패가 직전과 같은 자리·같은 원인·같은 리비전이면 true.
    public mutating func record(
        operation: String,
        failure: CareerActionFailure,
        revision: UInt64
    ) -> Bool {
        guard failure.kind.isStorageFailure else {
            previous = nil
            return false
        }
        let key = Key(operation: operation, failure: failure, revision: revision)
        let repeated = key == previous
        previous = key
        return repeated
    }
}
