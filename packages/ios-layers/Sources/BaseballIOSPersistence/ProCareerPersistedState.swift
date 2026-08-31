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

    public init(
        result: ProCareerResult? = nil,
        gameResume: PitchResumeState? = nil,
        sourceHighSchoolCareerID: String? = nil,
        careerOrigin: ProCareerOrigin? = nil,
        syncedRevision: UInt64 = 0,
        pendingInjuryEvent: ProInjuryEventSnapshot? = nil,
        acknowledgedInjuryEventID: String? = nil
    ) {
        self.result = result
        self.gameResume = gameResume
        self.sourceHighSchoolCareerID = sourceHighSchoolCareerID
        self.careerOrigin = careerOrigin
        self.syncedRevision = syncedRevision
        self.pendingInjuryEvent = pendingInjuryEvent
        self.acknowledgedInjuryEventID = acknowledgedInjuryEventID
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
