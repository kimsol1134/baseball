import Foundation
import SimulationCore
import BaseballIOSDomain

/// 프로 커리어 디스크 스키마. 예전에는 ProCareerResult를 그대로 썼고, 읽을 때는
/// 래퍼 도입 전 맨 result도 그대로 받는다. nil result는 삭제 묘비다.
public struct ProCareerSaveRecord: Codable {
    public let result: ProCareerResult?
    public var gameResume: PitchResumeState? = nil
    /// 묘비의 리비전. iCloud의 옛 사본을 이기기 위해 존재한다.
    public var deletedRevision: UInt64? = nil
    /// 직접 프로는 이 값이 nil이고 origin이 `.direct`다. 둘 다 nil이면 필드 도입 전 저장이다.
    public var sourceHighSchoolCareerID: String? = nil
    /// nil은 필드 도입 전 저장이다. 새 직접 시작은 `.direct`를 명시해 legacy nil과 구분한다.
    public var origin: ProCareerOrigin? = nil
    /// nil은 래퍼 도입기 저장이다. 더 높은 버전은 원본을 보존하고 업데이트를 기다린다.
    public var schemaVersion: Int? = nil
    /// 커리어가 바뀌어 스냅숏 리비전이 0부터 다시 시작해도 iCloud에서는 계속 증가한다.
    public var syncRevision: UInt64? = nil
    /// A structured injury remains visible until the player acknowledges it, even after the next
    /// recovery action replaces the transient `ProCareerResult`.
    public var pendingInjuryEvent: ProInjuryEventSnapshot? = nil
    public var acknowledgedInjuryEventID: String? = nil

    public var effectiveRevision: UInt64 {
        max(syncRevision ?? 0, max(deletedRevision ?? 0, result?.snapshot.revision ?? 0))
    }

    public init(
        result: ProCareerResult?,
        gameResume: PitchResumeState? = nil,
        deletedRevision: UInt64? = nil,
        sourceHighSchoolCareerID: String? = nil,
        origin: ProCareerOrigin? = nil,
        schemaVersion: Int? = nil,
        syncRevision: UInt64? = nil,
        pendingInjuryEvent: ProInjuryEventSnapshot? = nil,
        acknowledgedInjuryEventID: String? = nil
    ) {
        self.result = result
        self.gameResume = gameResume
        self.deletedRevision = deletedRevision
        self.sourceHighSchoolCareerID = sourceHighSchoolCareerID
        self.origin = origin
        self.schemaVersion = schemaVersion
        self.syncRevision = syncRevision
        self.pendingInjuryEvent = pendingInjuryEvent
        self.acknowledgedInjuryEventID = acknowledgedInjuryEventID
    }
}

public enum ProCareerRestoreOutcome: Equatable {
    case live(recoveredFromBackup: Bool)
    case needsSetup
    case unavailable
}

