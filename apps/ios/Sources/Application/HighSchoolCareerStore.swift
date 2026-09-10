import Foundation
import Observation
import SimulationCore
import BaseballIOSDomain
import BaseballIOSPersistence

/// 고교 커리어 진행 상태. 프로 커리어와 같은 방식으로 공유 코어를 직접 호출한다.
///
/// 디스크 스키마는 `HighSchoolCareerSaveRecord`, 코덱은 `HighSchoolCareerPersistence`.
/// 저장본을 메모리에 올릴 때는 `applyPersistedRecord` / `clearLiveSession`만 쓴다.
@MainActor
@Observable
final class HighSchoolCareerStore {
    static var currentSaveSchemaVersion: Int { HighSchoolCareerPersistence.currentSchemaVersion }
    static let unreadableSaveMessage = "환생 기록은 남아 있지만 현재 버전에서 읽을 수 없습니다. 앱을 삭제하거나 새 선수를 만들지 말고 다시 불러오기를 눌러 주세요."

    typealias Inheritance = BaseballIOSDomain.Inheritance
    typealias LifeRecord = BaseballIOSDomain.LifeRecord
    typealias PlayerBondMemory = BaseballIOSDomain.PlayerBondMemory
    typealias ResponseTally = BaseballIOSDomain.ResponseTally
    typealias ChronicleEntry = BaseballIOSDomain.ChronicleEntry
    typealias PendingGameCompletion = BaseballIOSDomain.PendingGameCompletion
    typealias CurrentCareerRetention = BaseballIOSDomain.CurrentCareerRetention
    typealias RivalLedger = BaseballIOSDomain.RivalLedger
    typealias TrainingReceipt = BaseballIOSDomain.TrainingReceipt
    typealias Bloom = TalentBloom
    typealias AbilityGain = BaseballIOSDomain.AbilityGain
    typealias FeedbackCue = BaseballIOSDomain.FeedbackCue

    typealias LoadState = CareerLoadState
    typealias InheritedStartComparison = BaseballIOSDomain.InheritedStartComparison

    nonisolated static func normalizedBondMemories(
        _ memories: [PlayerBondMemory]
    ) -> [PlayerBondMemory] {
        PlayerBondMemory.normalized(memories)
    }

    nonisolated static func appendingBondMemory(
        _ memory: PlayerBondMemory,
        to memories: [PlayerBondMemory]
    ) -> [PlayerBondMemory] {
        PlayerBondMemory.appending(memory, to: memories)
    }

    var loadState: LoadState = .loading
    /// 내구 필드는 하나씩 둔다. 한 가방에 넣으면 `chapterGains`만 바뀌어도 `result`를
    /// 보는 화면이 같이 갱신된다. 디스크 왕복만 `HighSchoolCareerPersistedState`로 모은다.
    private var durableResult: HighSchoolCareerResult?
    private var durableInheritance: Inheritance = .firstLife
    private var durableArchive: [LifeRecord] = []
    private var durableEnteredProCareerID: String?
    private var durableNicknames: [Nickname] = []
    private var durableChronicle: [ChronicleEntry] = []
    private var durableChapterStartStrikeouts = 0
    private var durableGoalCelebratedChapter: Int?
    private var durableResponseTally = ResponseTally()
    private var durableBondMemories: [PlayerBondMemory] = []
    private var durableRebirthEventIDs: [String] = []
    private var durableChapterGains: [String: Int] = [:]
    private var durableChapterTrainingCount = 0
    private var durableCareerStartingPitcher: PitcherSnapshot?
    private var durableSignatureLegacyRulesVersion: Int?
    private var durableFrozenSignatureLegacyCandidates: [CareerSignatureLegacy]?
    private var durableSelectedSignatureLegacyID: CareerSignatureLegacyID?
    private var durableGameResume: PitchResumeState?
    private var durableChallengeCareerID: String?
    private var durableNextRunIntent: NextRunIntent?
    private var durableCreditedExternalRewardIDs: Set<String> = []
    private var durablePendingGameCompletion: PendingGameCompletion?
    private var durableSavedRevision: UInt64 = 0

    func capturePersisted() -> HighSchoolCareerPersistedState {
        HighSchoolCareerPersistedState(
            result: durableResult,
            inheritance: durableInheritance,
            archive: durableArchive,
            enteredProCareerID: durableEnteredProCareerID,
            nicknames: durableNicknames,
            chronicle: durableChronicle,
            chapterStartStrikeouts: durableChapterStartStrikeouts,
            goalCelebratedChapter: durableGoalCelebratedChapter,
            responseTally: durableResponseTally,
            bondMemories: durableBondMemories,
            rebirthEventIDs: durableRebirthEventIDs,
            chapterGains: durableChapterGains,
            chapterTrainingCount: durableChapterTrainingCount,
            careerStartingPitcher: durableCareerStartingPitcher,
            signatureLegacyRulesVersion: durableSignatureLegacyRulesVersion,
            frozenSignatureLegacyCandidates: durableFrozenSignatureLegacyCandidates,
            selectedSignatureLegacyID: durableSelectedSignatureLegacyID,
            gameResume: durableGameResume,
            challengeCareerID: durableChallengeCareerID,
            nextRunIntent: durableNextRunIntent,
            creditedExternalRewardIDs: durableCreditedExternalRewardIDs,
            pendingGameCompletion: durablePendingGameCompletion,
            savedRevision: durableSavedRevision
        )
    }

    func updatePersisted(_ body: (inout HighSchoolCareerPersistedState) -> Void) {
        var next = capturePersisted()
        body(&next)
        replacePersisted(next)
    }

    func replacePersisted(_ next: HighSchoolCareerPersistedState) {
        assign(&durableResult, next.result)
        assign(&durableInheritance, next.inheritance)
        assign(&durableArchive, next.archive)
        assign(&durableEnteredProCareerID, next.enteredProCareerID)
        assign(&durableNicknames, next.nicknames)
        assign(&durableChronicle, next.chronicle)
        assign(&durableChapterStartStrikeouts, next.chapterStartStrikeouts)
        assign(&durableGoalCelebratedChapter, next.goalCelebratedChapter)
        assign(&durableResponseTally, next.responseTally)
        assign(&durableBondMemories, next.bondMemories)
        assign(&durableRebirthEventIDs, next.rebirthEventIDs)
        assign(&durableChapterGains, next.chapterGains)
        assign(&durableChapterTrainingCount, next.chapterTrainingCount)
        assign(&durableCareerStartingPitcher, next.careerStartingPitcher)
        assign(&durableSignatureLegacyRulesVersion, next.signatureLegacyRulesVersion)
        assign(&durableFrozenSignatureLegacyCandidates, next.frozenSignatureLegacyCandidates)
        assign(&durableSelectedSignatureLegacyID, next.selectedSignatureLegacyID)
        assign(&durableGameResume, next.gameResume)
        assign(&durableChallengeCareerID, next.challengeCareerID)
        assign(&durableNextRunIntent, next.nextRunIntent)
        assign(&durableCreditedExternalRewardIDs, next.creditedExternalRewardIDs)
        assign(&durablePendingGameCompletion, next.pendingGameCompletion)
        assign(&durableSavedRevision, next.savedRevision)
    }

    private func assign<T: Equatable>(_ storage: inout T, _ next: T) {
        if storage != next { storage = next }
    }

    var result: HighSchoolCareerResult? { durableResult }
    var lastSummary: String?
    /// 마지막 명령이 실패한 **이유**(7-A). 화면은 여기서 문장을 고른다 — 근거 없이
    /// "저장 공간을 확보하라"고 말하지 않기 위해서다.
    var lastActionFailure: CareerActionFailure?
    @ObservationIgnored var failureRepetition = CareerActionFailureRepetition()
    var lastFailureRepeated = false
    var feedbackTrigger = 0
    var feedbackCue: FeedbackCue = .neutral
    var pendingGains: [AbilityGain] = []
    var pitchSession: PitchSession?
    /// 프롤로그의 첫 불펜. 커리어 상태를 바꾸지 않는 연습이라 별도로 들고 있는다.
    var tutorialSession: PitchSession?
    /// 첫 회차 오프닝에서 연습 투구를 마쳤는가. 저장하지 않는다.
    var finishedOnboardingBullpen = false
    /// legacy 단계에서 고른 기억 카드.
    var selectedMemories: [MemoryCardID] = []
    /// 플레이 기록으로 생성된 대표 유산 세 후보 중 사용자가 고른 하나.
    var selectedSignatureLegacyID: CareerSignatureLegacyID? { durableSelectedSignatureLegacyID }
    /// 방금 만개한 재능. 화면이 축하하고 나서 비운다.
    var pendingBloom: Bloom?
    /// 방금 끝난 훈련의 영수증.
    ///
    /// 왜 따로 두는가: `pendingGains`는 **오른 것이 있을 때만** 채워진다. 그래서 성장 0으로
    /// 지나간 훈련은 화면에 아무 결과도 남기지 않았고, 사용자는 "눌렀는데 아무 일도 안
    /// 일어났다"로 읽었다. 훈련은 눌렀으면 언제나 결과가 있다 — 안 오른 것도 결과다.
    /// 이 값이 있는 동안 화면 아래에 결과 패널이 붙어, 스크롤 없이 그 자리에서 읽힌다.
    var trainingReceipt: TrainingReceipt?

    /// 결과 패널을 닫는다. 같은 자리에서 축하(성장·만개)까지 함께 소비한다 —
    /// 패널이 이미 그 둘을 보여 줬으므로, 남겨 두면 스크롤 위쪽에 같은 축하가 또 뜬다.
    func acknowledgeTrainingReceipt() {
        trainingReceipt = nil
        pendingGains = []
        pendingBloom = nil
    }
    /// 방금 닫힌 회차의 정산. 화면이 보여 주고 나서 비운다.
    var pendingRecap: CareerRecap?
    /// 지난 회차에서 사용자가 직접 저장한 재도전 목표. 선택하거나 버릴 때까지 유지한다.
    var nextRunIntent: NextRunIntent? { durableNextRunIntent }
    /// 진행 중인 등판의 타석 경계 스냅샷. 앱이 죽어도 이닝이 증발하지 않는다.
    var gameResume: PitchResumeState? { durableGameResume }
    /// 코어 경기 결과와 함께 먼저 저장되는 외부 후속 작업 영수증. 주간·분석·업적 저장
    /// 도중 앱이 종료돼도 다음 실행에서 stable ID로 정확히 한 번 마저 적용한다.
    var pendingGameCompletion: PendingGameCompletion? { durablePendingGameCompletion }
    /// 별점 요청 신호. 첫 무실점 이닝처럼 감정이 양(+)인 조기 지점에서 켜진다 —
    /// 뷰가 requestReview 환경을 갖고 있으므로 스토어는 신호만 올린다.
    var reviewMoment = 0
    /// 이미 프로로 보낸 회차의 careerID.
    ///
    /// 프로 저장본의 유무로 판단하면 안 된다 — 은퇴하고 "새 선수로 다시 시작"을 누르면 프로
    /// 저장본이 지워지므로, 같은 지명으로 프로 커리어를 무한히 새로 만들 수 있다(은퇴 계승
    /// 야구혼이 그때마다 다시 적립될 여지도 있다). 고교 쪽에 사실을 남긴다.
    var enteredProCareerID: String? { durableEnteredProCareerID }

    /// 지금 회차가 이미 프로에 다녀왔는가.
    var hasEnteredPro: Bool {
        guard let state, let entered = enteredProCareerID else { return false }
        return entered == state.careerID
    }

    /// 프로로 넘어간 사실을 기록한다. 프로 생성과 이 영수증이 모두 저장돼야 진입 성공이다.
    @discardableResult
    func markEnteredPro() -> Bool {
        guard let state,
              state.phase == .completed,
              state.draftResult?.outcome == .drafted else { return false }
        if enteredProCareerID == state.careerID { return true }
        let previous = capturePersisted()
        updatePersisted {
            $0.enteredProCareerID = state.careerID
            $0.chronicle.append(ChronicleEntry(
                stage: "\(state.chapter.schoolYear)학년 \(state.chapter.season)",
                text: "프로 유니폼을 입었습니다."
            ))
        }
        guard save() else {
            replacePersisted(previous)
            loadState = .failed("프로 진입 기록을 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.")
            return false
        }
        return true
    }

    var inheritance: Inheritance { durableInheritance }
    /// 주간 노트처럼 커리어 밖에서 들어온 보상 영수증. optional 저장 필드로 남겨
    /// 구버전 저장본은 빈 집합으로 열고, 같은 ID는 앱 재시작·기기 동기화 뒤에도 한 번만 준다.
    var creditedExternalRewardIDs: Set<String> { durableCreditedExternalRewardIDs }
    /// 끝난 회차들. 최근이 앞이다.
    var archive: [LifeRecord] { durableArchive }
    /// 이번 회차에 세상이 붙여 준 별명들. 한 번 얻으면 회차가 끝날 때까지 남는다 —
    /// 세상은 별명을 회수하지 않는다. 조건 판정은 커널(NicknameRules)이 한다.
    var nicknames: [Nickname] { durableNicknames }
    /// 이번 회차의 연대기 — 이 선수가 살아온 순간들. 능력치 그래프는 결과만 남기지만
    /// 연대기는 과정을 남긴다. 애착은 과정에서 생긴다.
    var chronicle: [ChronicleEntry] { durableChronicle }
    /// Meaningful relationship decisions for the current player. Unlike the full chronicle this
    /// stays structured, so farewell, archive, and the next player's letter can recall it.
    var bondMemories: [PlayerBondMemory] { durableBondMemories }
    /// 환생 장면도 회차의 경험이다. 다음 삶이 직전 장면을 반복하지 않도록 저장한다.
    var rebirthEventIDs: [String] { durableRebirthEventIDs }
    /// 방금 경기에 대한 커뮤니티 반응. 저장하지 않는다 — careerID·경기 번호로
    /// 결정론이라 필요하면 언제든 다시 만들 수 있고, 반응은 "방금"의 것일 때만 살아 있다.
    /// Ephemeral presentation values. These stable IDs are intentionally outside every save
    /// record and are rebuilt from the same post-game selection path.
    var buzz: [CommunityBuzzReactionLine] = []
    /// 챕터가 넘어갈 때 세계가 만든 사건들. 저장하지 않는다 — 결정론 재파생 가능.
    var worldNews: [CommunityBuzzRivalNewsLine] = []
    /// 이번 챕터의 훈련 누적(능력별 증가·횟수). 저장하지 않는 표시용 —
    /// 100번의 +1이 낱장으로 흩어지면 훈련 구간 전체가 "같은 화면의 반복"으로
    /// 기억된다(QA P1-15). 누적 한 줄이 "한 단위"의 체감을 만든다.
    var chapterGains: [String: Int] { durableChapterGains }
    var chapterTrainingCount: Int { durableChapterTrainingCount }
    /// 이번 챕터가 시작될 때의 통산 탈삼진. 챕터 목표의 진행은 이 값과의 차이다.
    var chapterStartStrikeouts: Int { durableChapterStartStrikeouts }
    /// 목표 축하를 이미 한 챕터 번호. 같은 챕터에서 두 번 축하하면 축하가 값싸진다.
    var goalCelebratedChapter: Int? { durableGoalCelebratedChapter }
    /// 관계 응답 누적 — 성격은 선택이 만든다. 경기 성적은 여기 한 획도 못 긋는다.
    var responseTally: ResponseTally { durableResponseTally }
    /// 이번 회차에 계승·프리셋 적용을 모두 마친 직후의 선수. 마지막 능력과 비교하면
    /// 유저가 이번 3년 동안 한 땀씩 키운 양만 남는다. optional 저장으로 구버전과 호환한다.
    var careerStartingPitcher: PitcherSnapshot? { durableCareerStartingPitcher }
    /// 회차 시작 시 고정한 대표 유산 후보 규칙과, 결말에 처음 생성된 세 후보 원본.
    /// 후보를 한 번 보여 준 뒤 앱이 업데이트돼도 선택지가 바뀌거나 선택이 사라지지 않는다.
    var signatureLegacyRulesVersion: Int? { durableSignatureLegacyRulesVersion }
    var frozenSignatureLegacyCandidates: [CareerSignatureLegacy]? { durableFrozenSignatureLegacyCandidates }

    static let currentSignatureLegacyRulesVersion = CareerSignatureLegacyRulesVersion.current.rawValue

    var personality: Personality? { responseTally.personality }

    @ObservationIgnored let engine = HighSchoolCareerEngine()
    @ObservationIgnored let sync: SaveSync
    @ObservationIgnored let weekly: WeeklyProgramStore
    @ObservationIgnored let saveWriter: ((Data) -> Bool)?

    init(
        sync: SaveSync = SaveSync(key: "baseball-mobile-highschool-v1.json"),
        weekly: WeeklyProgramStore = .shared,
        saveWriter: ((Data) -> Bool)? = nil
    ) {
        self.sync = sync
        self.weekly = weekly
        self.saveWriter = saveWriter
    }

    var state: HighSchoolCareerSnapshot? { result?.snapshot }

    var armHealth: ArmHealthState {
        guard let state else { return .normal }
        if (state.injuryRecovery ?? 0) > 0 { return .recovering }
        let risk = state.armRisk ?? 0
        // 코어의 armHealthState는 internal이라 같은 경계를 여기에 둔다. 값이 갈리면 화면이
        // 코어와 다른 이야기를 하게 되므로 테스트로 묶어 둔다.
        if risk >= 55 { return .warning }
        if risk >= 35 { return .caution }
        return .normal
    }


    /// 연습 불펜을 다시 연 횟수. 시드만 바꾸고 커리어에는 반영하지 않는다.
    var bullpenRetries = 0
    /// 회차를 넘어 단조 증가하는 저장 리비전. 진행(result)이 없는 계승-전용 레코드도
    /// 이 값으로 충돌 판정을 이겨야, 오래된 iCloud 사본이 방금 끝난 회차를 되살리지 않는다.
    var savedRevision: UInt64 { durableSavedRevision }
    /// 진행 중 challenge 모드의 careerID. nil이면 도전이 아니다.
    ///
    /// 처음에는 "스냅숏 회차 != 계승 회차"로 파생 판별했다 — confirmLegacy가 계승
    /// 회차를 +1 올리는 순간 **모든 정상 회차**가 challenge로 오판돼 마지막 화면
    /// (환생 스탬프·프로 진입)이 사라졌고, 회차가 우연히 같은 도전은 반대로 실계승을
    /// 오염시켰다(5차 패널 P0 ×2). 명시 플래그는 옵셔널이라 옛 저장본은 nil = 비도전.
    var challengeCareerID: String? { durableChallengeCareerID }
}
