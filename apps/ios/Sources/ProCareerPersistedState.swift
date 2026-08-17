import Foundation
import SimulationCore

/// 프로 세이브의 전송 단위. 스토어는 필드별로 들고, 디스크 왕복만 이 값으로 모은다.
struct ProCareerPersistedState: Equatable {
    var result: ProCareerResult? = nil
    var gameResume: PitchSession.ResumeState? = nil
    var sourceHighSchoolCareerID: String? = nil
    var careerOrigin: MobileCareerStore.ProCareerOrigin? = nil
    var syncedRevision: UInt64 = 0

    static let empty = ProCareerPersistedState()

    func drafting(
        result: ProCareerResult?,
        gameResume: PitchSession.ResumeState?
    ) -> ProCareerPersistedState {
        var draft = self
        draft.result = result
        draft.gameResume = gameResume
        return draft
    }
}
