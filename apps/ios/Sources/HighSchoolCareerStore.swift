import Foundation
import Observation
import SimulationCore

/// 고교 커리어 진행 상태. 프로 커리어와 같은 방식으로 공유 코어를 직접 호출한다.
///
/// 디스크 스키마는 `HighSchoolCareerSaveRecord`, 코덱은 `HighSchoolCareerPersistence`.
/// 저장본을 메모리에 올릴 때는 `applyPersistedRecord` / `clearLiveSession`만 쓴다.
@MainActor
@Observable
final class HighSchoolCareerStore {
    static var currentSaveSchemaVersion: Int { HighSchoolCareerPersistence.currentSchemaVersion }
    static let unreadableSaveMessage = "환생 기록은 남아 있지만 현재 버전에서 읽을 수 없습니다. 앱을 삭제하거나 새 선수를 만들지 말고 다시 불러오기를 눌러 주세요."

    enum LoadState: Equatable {
        case loading
        case needsSetup
        case ready
        case failed(String)
    }

    /// 다음 회차로 넘기는 것. 환생 루프의 저장 단위다.
    struct Inheritance: Codable, Equatable {
        var lifeNumber: Int
        var memories: [MemoryCardID]
        var soulPoints: Int
        var karmas: [KarmaID]
        /// 지난 선수의 플레이 기록에서 만들어진 대표 유산 한 자리. 효과는 stable ID를
        /// 코어가 다시 해석하므로 저장된 설명 문구가 바뀌어도 밸런스는 움직이지 않는다.
        /// optional이라 이 기능 이전 저장본은 유산 없이 그대로 시작한다.
        var equippedSignatureLegacyID: CareerSignatureLegacyID? = nil
        /// 지금까지 발견한 대표 유산. 선택하지 않은 두 후보도 도감에 남겨, 실패한 회차가
        /// 다음 회차의 빌드 선택지를 실제로 넓힌다. 같은 ID는 최초 발견 기록만 보존한다.
        var unlockedSignatureLegacies: [CareerSignatureLegacy]? = nil
        /// 야구혼으로 이미 접은 프로 커리어. 같은 커리어를 두 번 계산하지 않기 위한 표식이다.
        /// 옵셔널이라 이 필드가 없는 옛 저장본도 그대로 열린다.
        var creditedProCareerID: String?
        /// 평생 획득한 야구혼 총량. soulPoints는 현재 상점에서 쓸 수 있는 지갑 잔액이다.
        /// 옵셔널: 없는 옛 저장본은 잔액을 총량으로 본다(쓴 만큼은 복구 불가, 최선의 근사).
        var soulTotalEarned: Int?
        /// 다음 선수에게 자동으로 스며드는 누적분. 고교 정산·주간 보상은 여기에 쌓이고,
        /// 프로 보너스는 지갑에만 들어가 사용자가 상점에서 쓰도록 분리한다. 없는 옛 저장은
        /// 당시 단일 총량 전체가 자동 적용되던 의미를 보존하기 위해 soulTotal로 읽는다.
        var automaticSoulEarned: Int? = nil
        /// 야구혼이 시작 능력으로 스며드는 곡선의 저장 버전. 없는 옛 저장본은 코어에서
        /// v1로 해석하고, 새로 정산한 선수부터 current를 기록해 업데이트 뒤에도 같은
        /// 시작 능력을 재현한다.
        var inheritanceRulesVersion: Int? = nil

        /// 평생 획득 총량. 구매로 잔액이 줄어도 줄지 않는다.
        var soulTotal: Int { max(soulTotalEarned ?? soulPoints, soulPoints) }
        /// 자동 성장 계산에만 쓰는 총량. 프로 보너스나 구매 잔액과 독립적이다.
        var automaticSoulTotal: Int { max(0, automaticSoulEarned ?? soulTotal) }

        static let firstLife = Inheritance(lifeNumber: 1, memories: [], soulPoints: 0, karmas: [])

        var equippedSignatureLegacy: CareerSignatureLegacy? {
            guard let equippedSignatureLegacyID else { return nil }
            let definition = CareerSignatureLegacy.definition(for: equippedSignatureLegacyID)
            guard let discovered = unlockedSignatureLegacies?.first(where: {
                $0.id == equippedSignatureLegacyID
            }) else { return definition }
            // 발견 당시 근거는 보존하되, 다음 회차에 적용할 문구·효과는 코어의 현재 stable
            // ID 정의를 쓴다. 화면은 옛 payload를, 실제 시작은 새 정의를 쓰는 불일치를 막는다.
            return CareerSignatureLegacy(
                id: definition.id,
                family: definition.family,
                title: definition.title,
                detail: definition.detail,
                effect: definition.effect,
                evidence: discovered.evidence
            )
        }
    }

    /// 끝난 회차 한 장. 환생 게임인데 **지난 회차를 볼 방법이 아예 없었다**(품질 평가 §4.3).
    ///
    /// "N회차의 나"들이 쌓이는 게임인데 그 역사가 어디에도 남지 않으면, 회차를 반복할 이유가
    /// 다음 회차의 능력치뿐이 된다. 여기 있는 값은 전부 계승을 확정하는 순간 이미 손에 있다.
    struct LifeRecord: Codable, Equatable, Identifiable {
        var id: Int { lifeNumber }
        let lifeNumber: Int
        let playerName: String
        /// One-life portrait identity. Missing old records intentionally fall back to playerName.
        var appearanceSeed: String? = nil
        let schoolName: String?
        let drafted: Bool
        let evaluationScore: Int
        let teamName: String?
        let memories: [MemoryCardID]
        let games: Int
        let strikeouts: Int
        let walks: Int
        let runsAllowed: Int
        let soulPoints: Int
        /// **왜 그 회차가 그렇게 끝났는지**를 아카이브가 답할 수 있게 하는 값들.
        /// 전부 옵셔널이라 이 필드가 없는 옛 기록도 그대로 읽힌다.
        var talent: TalentSnapshot?
        var awakenings: [AwakeningID]?
        var karmas: [KarmaID]?
        var harshness: String?
        var schoolStrength: String?
        /// 이번 회차에 얻은 별명. 없는 옛 기록은 nil이다.
        var nicknames: [String]? = nil
        /// 이번 회차의 연대기("2학년 여름 — …"). 없는 옛 기록은 nil이다.
        var chronicle: [String]? = nil
        /// 이 삶에서 팔 경고나 재활을 실제로 겪었는지. 다음 삶의 통증 회상이 이 값에 기대며,
        /// 없는 옛 기록은 당시 연대기와 관계 기억으로 보수적으로 복원한다.
        var hadArmWarning: Bool? = nil
        /// 3년을 함께한 사람들. 회차가 끝나면 감독·포수·숙적이 통째로 증발하던 것을
        /// 여기 남긴다(3차 패널 P2 — 애착 축). 없는 옛 기록은 nil이다.
        var coachName: String? = nil
        var catcherName: String? = nil
        var rivalName: String? = nil
        var coachTrust: Int? = nil
        var catcherTrust: Int? = nil
        var rivalTrust: Int? = nil
        /// 이 회차가 어떤 사람이었는가. 없는 옛 기록은 nil이다.
        var personality: String? = nil
        /// 이 회차의 careerID("career-시드-life-N"). 카드에 시드를 각인해
        /// "같은 시드로 도전"이 가능하게 한다. 없는 옛 기록은 nil이다.
        var careerID: String? = nil
        /// 웨이브 1 이전 기록에는 없는 약속 결과. 모두 optional이라 그대로 디코드된다.
        var pledgeID: String? = nil
        /// 카탈로그의 문구·등급·보상이 바뀌어도 지난 선택은 완료 당시 그대로 읽힌다.
        var pledgeTitle: String? = nil
        var pledgeTier: String? = nil
        var pledgeRewardPermille: Int? = nil
        var pledgeAchieved: Bool? = nil
        var pledgeProgressCurrent: Int? = nil
        var pledgeProgressTarget: Int? = nil
        /// Compound conditions must survive in human and normalized form for archive accessibility.
        var pledgeProgressLine: String? = nil
        var pledgeProgressRatioPermille: Int? = nil
        /// 회차 규칙이 이후 버전에서 달라져도 지난 카드의 이름은 그대로 남긴다.
        var windID: String? = nil
        var windTitle: String? = nil
        /// 이 선수가 떠나며 남긴 한마디와 실제 3년의 대표 순간. 새 카피가 배포돼도
        /// 끝난 사람의 말이 바뀌지 않도록 완료 시점에 동결한다. 없는 옛 기록은 화면에서
        /// 당시 기록으로 결정론적으로 복원한다.
        var playerLegacy: PlayerLegacy? = nil
        /// 이 선수가 직접 키운 능력과 실제 경기 기록이 다음 세대에 남긴 대표 유산.
        /// 완료 시점의 근거까지 동결해 이후 밸런스·카피 변경이 과거 기록을 바꾸지 않는다.
        var signatureLegacy: CareerSignatureLegacy? = nil
        /// 함께 발견한 세 후보도 회차에 귀속해 둔다. 선택하지 않은 두 후보가 발견 목록에는
        /// 남으면서 정작 어느 선수가 만든 유산인지 아카이브에서 사라지면 수집의 의미가 약해진다.
        var signatureLegacyCandidates: [CareerSignatureLegacy]? = nil
        /// 이 선수가 시작할 때 실제로 장착한 유산과 당시 숙련. 이후 승급해도 과거는 바뀌지 않는다.
        var inheritedLineageLoadout: CareerLineageLoadout? = nil

        /// 3년 동안 실제로 던진 공의 수. 성적을 "몇 경기"보다 구체적으로 말한다.
        var pitches: Int? = nil
        /// 이닝(아웃 수)과 피안타. 방어율·WHIP은 이 둘이 있어야 만들어진다.
        var outs: Int? = nil
        var hits: Int? = nil
        /// 시작과 끝의 네 능력. 이 회차가 **무엇을 얼마나 키웠는지**가 카드의 자랑거리다.
        /// 없는 옛 기록은 nil이라 카드가 그 줄을 통째로 접는다.
        var abilityStart: AbilityLine? = nil
        var abilityFinal: AbilityLine? = nil
        /// The few relationship choices that defined this player. Optional keeps old archives
        /// readable; a run records at most one meaningful moment per chapter.
        var bondMemories: [PlayerBondMemory]? = nil
        /// Stable IDs of the rebirth scenes this player actually encountered.
        var rebirthEventIDs: [String]? = nil

        /// 구위·제구·변화·체력 네 값. 카드와 아카이브가 함께 쓴다.
        struct AbilityLine: Codable, Equatable {
            let stuff: Int
            let command: Int
            let movement: Int
            let stamina: Int

            init(_ pitcher: PitcherSnapshot) {
                stuff = pitcher.stuff
                command = pitcher.command
                movement = pitcher.movement
                stamina = pitcher.stamina
            }

            var total: Int { stuff + command + movement + stamina }
        }

        /// "미지명 · 평가 57점" / "3라운드 서울 …". 목록 한 줄에 결말이 들어가야 한다.
        var outcomeLine: String {
            drafted ? "지명 · \(teamName ?? "구단 미정")" : "미지명 · 평가 \(evaluationScore)점"
        }

        var portraitSeed: String {
            guard let appearanceSeed, !appearanceSeed.isEmpty else { return playerName }
            return appearanceSeed
        }
    }

    struct PlayerBondMemory: Codable, Equatable, Identifiable {
        enum Kind: String, Codable, Hashable {
            case personality
            case healthChoice = "health_choice"
            case trustMilestone = "trust_milestone"
        }

        var id: String { "\(chapterNumber):\(eventID):\(kind.rawValue)" }
        let kind: Kind
        let eventID: String
        let eventCategory: String
        let eventTitle: String
        let response: RelationshipResponse
        let subjectName: String?
        let chapterNumber: Int
        let trustBefore: Int
        let trustAfter: Int
    }

    /// 유대 기억은 회차 로그가 아니라 이 선수를 설명하는 세 장면이다. 구버전 저장에
    /// 중복이 들어 있어도 최초 한 종류만 남기고, 이후 저장부터 같은 계약으로 고정한다.
    nonisolated static func normalizedBondMemories(
        _ memories: [PlayerBondMemory]
    ) -> [PlayerBondMemory] {
        var kinds = Set<PlayerBondMemory.Kind>()
        var normalized: [PlayerBondMemory] = []
        for memory in memories where kinds.insert(memory.kind).inserted {
            normalized.append(memory)
            if normalized.count == 3 { break }
        }
        return normalized
    }

    nonisolated static func appendingBondMemory(
        _ memory: PlayerBondMemory,
        to memories: [PlayerBondMemory]
    ) -> [PlayerBondMemory] {
        let normalized = normalizedBondMemories(memories)
        guard normalized.count < 3,
              !normalized.contains(where: { $0.kind == memory.kind })
        else { return normalized }
        return normalized + [memory]
    }

    struct InheritedStartComparison: Equatable {
        struct Source: Equatable, Identifiable {
            let id: String
            let ratingDelta: Int
            let signatureLegacyID: CareerSignatureLegacyID?
        }

        let previousName: String
        let careerID: String
        let previous: LifeRecord.AbilityLine
        let current: LifeRecord.AbilityLine
        let sources: [Source]

        var totalDelta: Int { current.total - previous.total }
        var inheritedRatingDelta: Int { sources.reduce(0) { $0 + $1.ratingDelta } }
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
    private var durableGameResume: PitchSession.ResumeState?
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
    var feedbackTrigger = 0
    var feedbackCue: MobileCareerStore.FeedbackCue = .neutral
    var pendingGains: [MobileCareerStore.AbilityGain] = []
    var pitchSession: PitchSession?
    /// 프롤로그의 첫 불펜. 커리어 상태를 바꾸지 않는 연습이라 별도로 들고 있는다.
    var tutorialSession: PitchSession?
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

    struct TrainingReceipt: Equatable {
        var focus: TrainingFocus
        /// "구위 +2" 같은 한 줄. 성장이 없으면 "능력 변화 없음".
        var headline: String
        /// 코어가 만든 설명 문장.
        var detail: String
        var gains: [MobileCareerStore.AbilityGain]
        /// Transient structured result data used to re-author the receipt in the active language.
        /// It is not persisted and does not participate in the simulation commitment.
        var growth: Int = 0
        var repeatCount: Int? = nil
        var jackpot: Bool
        var bloom: Bloom?
        var fatigueAfter: Int
        var fatigueChange: Int
        /// 오늘의 기회를 맞춰 던진 훈련인가.
        var opportunityHit: Bool
    }

    /// 결과 패널을 닫는다. 같은 자리에서 축하(성장·만개)까지 함께 소비한다 —
    /// 패널이 이미 그 둘을 보여 줬으므로, 남겨 두면 스크롤 위쪽에 같은 축하가 또 뜬다.
    func acknowledgeTrainingReceipt() {
        trainingReceipt = nil
        pendingGains = []
        pendingBloom = nil
    }
    /// 방금 닫힌 회차의 정산. 화면이 보여 주고 나서 비운다.
    var pendingRecap: RunRecapView.Recap?
    /// 지난 회차에서 사용자가 직접 저장한 재도전 목표. 선택하거나 버릴 때까지 유지한다.
    var nextRunIntent: NextRunIntent? { durableNextRunIntent }
    /// 진행 중인 등판의 타석 경계 스냅샷. 앱이 죽어도 이닝이 증발하지 않는다.
    var gameResume: PitchSession.ResumeState? { durableGameResume }
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

    struct Bloom: Equatable {
        let ability: TalentAbility
        let grade: TalentGrade
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

    struct ResponseTally: Codable, Equatable {
        var listen = 0
        var explain = 0
        var challenge = 0

        var personality: Personality? {
            PersonalityRules.personality(listen: listen, explain: explain, challenge: challenge)
        }
    }

    var personality: Personality? { responseTally.personality }

    struct ChronicleEntry: Codable, Equatable {
        /// 언제였는가 — "2학년 여름".
        let stage: String
        let text: String
    }

    struct PendingGameCompletion: Codable, Equatable {
        let id: String
        let report: ImportantInningReport
        let achievements: [Achievement]
        let sequenceTags: [String]
        let recommendationAcceptanceRate: Double
        var developmentRulesVersion: Int? = nil
        /// 직접 키운 능력이 실제 결과에서 살아난 공. 옛 영수증은 nil이다.
        var abilityMomentCount: Int? = nil
        var abilityMomentTypes: [String]? = nil
        let targetBatters: Int
        let batters: Int
        let lifeNumber: Int
        let actNumber: Int
        let chapterNumber: Int
        /// `recordImportantGame`가 다음 국면으로 넘긴 경우의 퍼널 계단. nil이면 국면 불변.
        let enteredPhase: String?
        let gameGrowth: CareerGameGrowth?
        let shouldRequestCleanReview: Bool
        let completedAt: Date
    }

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
