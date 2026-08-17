import Foundation
import SimulationCore

/// 고교 세이브의 전송 단위. 스토어는 필드별로 들고, 디스크 왕복만 이 값으로 모은다.
struct HighSchoolCareerPersistedState: Equatable {
    var result: HighSchoolCareerResult? = nil
    var inheritance: HighSchoolCareerStore.Inheritance = .firstLife
    var archive: [HighSchoolCareerStore.LifeRecord] = []
    var enteredProCareerID: String? = nil
    var nicknames: [Nickname] = []
    var chronicle: [HighSchoolCareerStore.ChronicleEntry] = []
    var chapterStartStrikeouts: Int = 0
    var goalCelebratedChapter: Int? = nil
    var responseTally: HighSchoolCareerStore.ResponseTally = .init()
    var bondMemories: [HighSchoolCareerStore.PlayerBondMemory] = []
    var rebirthEventIDs: [String] = []
    var chapterGains: [String: Int] = [:]
    var chapterTrainingCount: Int = 0
    var careerStartingPitcher: PitcherSnapshot? = nil
    var signatureLegacyRulesVersion: Int? = nil
    var frozenSignatureLegacyCandidates: [CareerSignatureLegacy]? = nil
    var selectedSignatureLegacyID: CareerSignatureLegacyID? = nil
    var gameResume: PitchSession.ResumeState? = nil
    var challengeCareerID: String? = nil
    var nextRunIntent: NextRunIntent? = nil
    var creditedExternalRewardIDs: Set<String> = []
    var pendingGameCompletion: HighSchoolCareerStore.PendingGameCompletion? = nil
    var savedRevision: UInt64 = 0

    static let empty = HighSchoolCareerPersistedState()

    func drafting(
        result: HighSchoolCareerResult?,
        gameResume: PitchSession.ResumeState?,
        chronicle: [HighSchoolCareerStore.ChronicleEntry],
        responseTally: HighSchoolCareerStore.ResponseTally,
        bondMemories: [HighSchoolCareerStore.PlayerBondMemory]?,
        rebirthEventIDs: [String]?,
        nextRunIntent: NextRunIntent?,
        overrides: HighSchoolCareerStore.PersistenceOverrides?
    ) -> HighSchoolCareerPersistedState {
        var draft = self
        draft.result = result
        draft.gameResume = gameResume
        draft.chronicle = chronicle
        draft.responseTally = responseTally
        if let bondMemories {
            draft.bondMemories = HighSchoolCareerStore.normalizedBondMemories(bondMemories)
        }
        if let rebirthEventIDs {
            draft.rebirthEventIDs = Array(rebirthEventIDs.suffix(6))
        }
        draft.nextRunIntent = nextRunIntent
        if let overrides {
            draft.nicknames = overrides.nicknames
            draft.goalCelebratedChapter = overrides.goalCelebratedChapter
            draft.pendingGameCompletion = overrides.pendingGameCompletion
        }
        return draft
    }
}
