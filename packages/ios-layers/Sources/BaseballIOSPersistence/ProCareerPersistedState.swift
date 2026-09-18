import Foundation
import SimulationCore
import BaseballIOSDomain

/// 프로 세이브의 전송 단위. 스토어는 필드별로 들고, 디스크 왕복만 이 값으로 모은다.
public struct ProCareerPersistedState: Equatable {
    public var result: ProCareerResult? = nil
    public var gameResume: PitchResumeState? = nil
    public var sourceHighSchoolCareerID: String? = nil
    public var careerOrigin: ProCareerOrigin? = nil
    public var syncedRevision: UInt64 = 0
    public var pendingInjuryEvent: ProInjuryEventSnapshot? = nil
    public var acknowledgedInjuryEventID: String? = nil
    /// 다시 볼 만했던 공들. **커리어 진행에 아무 영향이 없는 증거**라서 서명된 스냅샷 밖에
    /// 둔다 — 시뮬레이션은 이 값을 읽지 않고, 재생도 커널을 부르지 않는다. 없는 옛 저장은
    /// nil이며 앨범이 비어 있을 뿐이다.
    public var replays: [AlbumReplay]? = nil
    /// 이미 적용한 명령의 영수증. 같은 명령이 두 번 적용되는 것을 막는다.
    /// 없는 옛 저장은 nil이며 그때는 아무 명령도 본 적 없는 것으로 읽는다.
    public var commandReceipts: [String]? = nil

    public init(
        result: ProCareerResult? = nil,
        gameResume: PitchResumeState? = nil,
        sourceHighSchoolCareerID: String? = nil,
        careerOrigin: ProCareerOrigin? = nil,
        syncedRevision: UInt64 = 0,
        pendingInjuryEvent: ProInjuryEventSnapshot? = nil,
        acknowledgedInjuryEventID: String? = nil,
        replays: [AlbumReplay]? = nil,
        commandReceipts: [String]? = nil
    ) {
        self.result = result
        self.gameResume = gameResume
        self.sourceHighSchoolCareerID = sourceHighSchoolCareerID
        self.careerOrigin = careerOrigin
        self.syncedRevision = syncedRevision
        self.pendingInjuryEvent = pendingInjuryEvent
        self.acknowledgedInjuryEventID = acknowledgedInjuryEventID
        self.replays = replays
        self.commandReceipts = commandReceipts
    }

    public static var empty: ProCareerPersistedState { ProCareerPersistedState() }

    public func drafting(
        result: ProCareerResult?,
        gameResume: PitchResumeState?
    ) -> ProCareerPersistedState {
        var draft = self
        draft.result = result
        draft.gameResume = gameResume
        return draft
    }

    public func withInjury(
        pending: ProInjuryEventSnapshot?,
        acknowledgedID: String?
    ) -> ProCareerPersistedState {
        var next = self
        next.pendingInjuryEvent = pending
        next.acknowledgedInjuryEventID = acknowledgedID
        return next
    }
}
