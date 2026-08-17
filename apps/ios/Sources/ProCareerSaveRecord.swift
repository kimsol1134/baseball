import Foundation
import SimulationCore

/// 프로 커리어 디스크 스키마. 예전에는 ProCareerResult를 그대로 썼고, 읽을 때는
/// 래퍼 도입 전 맨 result도 그대로 받는다. nil result는 삭제 묘비다.
struct ProCareerSaveRecord: Codable {
    let result: ProCareerResult?
    var gameResume: PitchSession.ResumeState? = nil
    /// 묘비의 리비전. iCloud의 옛 사본을 이기기 위해 존재한다.
    var deletedRevision: UInt64? = nil
    /// 직접 프로는 이 값이 nil이고 origin이 `.direct`다. 둘 다 nil이면 필드 도입 전 저장이다.
    var sourceHighSchoolCareerID: String? = nil
    /// nil은 필드 도입 전 저장이다. 새 직접 시작은 `.direct`를 명시해 legacy nil과 구분한다.
    var origin: MobileCareerStore.ProCareerOrigin? = nil
    /// nil은 래퍼 도입기 저장이다. 더 높은 버전은 원본을 보존하고 업데이트를 기다린다.
    var schemaVersion: Int? = nil
    /// 커리어가 바뀌어 스냅숏 리비전이 0부터 다시 시작해도 iCloud에서는 계속 증가한다.
    var syncRevision: UInt64? = nil

    var effectiveRevision: UInt64 {
        max(syncRevision ?? 0, max(deletedRevision ?? 0, result?.snapshot.revision ?? 0))
    }
}

enum ProCareerRestoreOutcome: Equatable {
    case live(recoveredFromBackup: Bool)
    case needsSetup
    case unavailable
}

extension MobileCareerStore {
    typealias ProSaveRecord = ProCareerSaveRecord
    typealias RestoreOutcome = ProCareerRestoreOutcome
}
