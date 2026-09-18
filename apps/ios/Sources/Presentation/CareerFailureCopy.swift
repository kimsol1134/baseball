import Foundation
import BaseballIOSDomain

/// 실패 갈래 하나를 사람이 읽는 한 문장으로.
///
/// 문장을 고르는 일이 여기 한 곳에 모여 있어야 "규칙이 거절했는데 저장 공간을 확보하라"는
/// 말이 다시 생기지 않는다(7-A). 각 문장은 **무엇을 하면 되는지**로 끝난다.
enum CareerFailureCopy {
    static func message(
        for failure: CareerActionFailure,
        repeated: Bool = false,
        resolver: GameCopyResolver
    ) -> String {
        switch failure.kind {
        case .rule:
            return resolver.resolve(AppCopyKey.failureRule)
        case .staleState:
            return resolver.resolve(AppCopyKey.failureStaleState)
        case .pitchState:
            return resolver.resolve(AppCopyKey.failurePitchState)
        case .storageFull:
            return resolver.resolve(AppCopyKey.failureStorageFull)
        case .io:
            return resolver.resolve(repeated ? AppCopyKey.failureIORepeated : AppCopyKey.failureIO)
        case .saveValidation:
            return resolver.resolve(AppCopyKey.failureSaveValidation)
        case .writeDisabled:
            return resolver.resolve(AppCopyKey.failureWriteDisabled)
        case .unknown:
            return resolver.resolve(AppCopyKey.failureUnknown)
        }
    }
}
