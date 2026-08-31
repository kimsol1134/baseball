import Foundation
import SimulationCore
import BaseballIOSDomain

/// persist 한 번의 덮어쓰기. 코덱이 스토어 중첩 타입을 모르게 여기 둔다.
public struct HighSchoolCareerPersistenceOverrides: Equatable {
    public let nicknames: [Nickname]
    public let goalCelebratedChapter: Int?
    public let currentCareerRetention: CurrentCareerRetention?
    public let pendingGameCompletion: PendingGameCompletion?

    public init(
        nicknames: [Nickname],
        goalCelebratedChapter: Int?,
        currentCareerRetention: CurrentCareerRetention?,
        pendingGameCompletion: PendingGameCompletion?
    ) {
        self.nicknames = nicknames
        self.goalCelebratedChapter = goalCelebratedChapter
        self.currentCareerRetention = currentCareerRetention
        self.pendingGameCompletion = pendingGameCompletion
    }
}

/// 고교 세이브의 전송 단위. 스토어는 필드별로 들고, 디스크 왕복만 이 값으로 모은다.
public struct HighSchoolCareerPersistedState: Equatable {
    public var result: HighSchoolCareerResult? = nil
    public var inheritance: Inheritance = .firstLife
    public var archive: [LifeRecord] = []
    public var enteredProCareerID: String? = nil
    public var nicknames: [Nickname] = []
    public var chronicle: [ChronicleEntry] = []
    public var chapterStartStrikeouts: Int = 0
    public var goalCelebratedChapter: Int? = nil
    public var responseTally: ResponseTally = .init()
    public var bondMemories: [PlayerBondMemory] = []
    public var rebirthEventIDs: [String] = []
    public var chapterGains: [String: Int] = [:]
    public var chapterTrainingCount: Int = 0
    public var careerStartingPitcher: PitcherSnapshot? = nil
    public var signatureLegacyRulesVersion: Int? = nil
    public var frozenSignatureLegacyCandidates: [CareerSignatureLegacy]? = nil
    public var selectedSignatureLegacyID: CareerSignatureLegacyID? = nil
    public var gameResume: PitchResumeState? = nil
    public var challengeCareerID: String? = nil
    public var nextRunIntent: NextRunIntent? = nil
    public var creditedExternalRewardIDs: Set<String> = []
    public var pendingGameCompletion: PendingGameCompletion? = nil
    public var savedRevision: UInt64 = 0

    public init(
        result: HighSchoolCareerResult? = nil,
        inheritance: Inheritance = .firstLife,
        archive: [LifeRecord] = [],
        enteredProCareerID: String? = nil,
        nicknames: [Nickname] = [],
        chronicle: [ChronicleEntry] = [],
        chapterStartStrikeouts: Int = 0,
        goalCelebratedChapter: Int? = nil,
        responseTally: ResponseTally = .init(),
        bondMemories: [PlayerBondMemory] = [],
        rebirthEventIDs: [String] = [],
        chapterGains: [String: Int] = [:],
        chapterTrainingCount: Int = 0,
        careerStartingPitcher: PitcherSnapshot? = nil,
        signatureLegacyRulesVersion: Int? = nil,
        frozenSignatureLegacyCandidates: [CareerSignatureLegacy]? = nil,
        selectedSignatureLegacyID: CareerSignatureLegacyID? = nil,
        gameResume: PitchResumeState? = nil,
        challengeCareerID: String? = nil,
        nextRunIntent: NextRunIntent? = nil,
        creditedExternalRewardIDs: Set<String> = [],
        pendingGameCompletion: PendingGameCompletion? = nil,
        savedRevision: UInt64 = 0
    ) {
        self.result = result
        self.inheritance = inheritance
        self.archive = archive
        self.enteredProCareerID = enteredProCareerID
        self.nicknames = nicknames
        self.chronicle = chronicle
        self.chapterStartStrikeouts = chapterStartStrikeouts
        self.goalCelebratedChapter = goalCelebratedChapter
        self.responseTally = responseTally
        self.bondMemories = bondMemories
        self.rebirthEventIDs = rebirthEventIDs
        self.chapterGains = chapterGains
        self.chapterTrainingCount = chapterTrainingCount
        self.careerStartingPitcher = careerStartingPitcher
        self.signatureLegacyRulesVersion = signatureLegacyRulesVersion
        self.frozenSignatureLegacyCandidates = frozenSignatureLegacyCandidates
        self.selectedSignatureLegacyID = selectedSignatureLegacyID
        self.gameResume = gameResume
        self.challengeCareerID = challengeCareerID
        self.nextRunIntent = nextRunIntent
        self.creditedExternalRewardIDs = creditedExternalRewardIDs
        self.pendingGameCompletion = pendingGameCompletion
        self.savedRevision = savedRevision
    }

    public static var empty: HighSchoolCareerPersistedState { HighSchoolCareerPersistedState() }

    public func drafting(
        result: HighSchoolCareerResult?,
        gameResume: PitchResumeState?,
        chronicle: [ChronicleEntry],
        responseTally: ResponseTally,
        bondMemories: [PlayerBondMemory]?,
        rebirthEventIDs: [String]?,
        nextRunIntent: NextRunIntent?,
        overrides: HighSchoolCareerPersistenceOverrides?
    ) -> HighSchoolCareerPersistedState {
        var draft = self
        draft.result = result
        draft.gameResume = gameResume
        draft.chronicle = chronicle
        draft.responseTally = responseTally
        if let bondMemories {
            draft.bondMemories = PlayerBondMemory.normalized(bondMemories)
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
