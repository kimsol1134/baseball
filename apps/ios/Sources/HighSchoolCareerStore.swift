import Foundation
import Observation
import SimulationCore

/// 고교 커리어 진행 상태. 프로 커리어와 같은 방식으로 공유 코어를 직접 호출한다.
///
/// 코어(`HighSchoolCareer.swift` 2,042줄)는 이미 완성돼 데스크톱에서 돌아간다. iOS에는 화면만
/// 없었다(DOC-IOS-TOP §4).
@MainActor
@Observable
final class HighSchoolCareerStore {
    static let currentSaveSchemaVersion = 2
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
        /// 3년을 함께한 사람들. 회차가 끝나면 감독·포수·숙적이 통째로 증발하던 것을
        /// 여기 남긴다(3차 패널 P2 — 애착 축). 없는 옛 기록은 nil이다.
        var coachName: String? = nil
        var catcherName: String? = nil
        var rivalName: String? = nil
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

        /// 3년 동안 실제로 던진 공의 수. 성적을 "몇 경기"보다 구체적으로 말한다.
        var pitches: Int? = nil
        /// 이닝(아웃 수)과 피안타. 방어율·WHIP은 이 둘이 있어야 만들어진다.
        var outs: Int? = nil
        var hits: Int? = nil
        /// 시작과 끝의 네 능력. 이 회차가 **무엇을 얼마나 키웠는지**가 카드의 자랑거리다.
        /// 없는 옛 기록은 nil이라 카드가 그 줄을 통째로 접는다.
        var abilityStart: AbilityLine? = nil
        var abilityFinal: AbilityLine? = nil

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
    }

    var loadState: LoadState = .loading
    var result: HighSchoolCareerResult?
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
    var selectedSignatureLegacyID: CareerSignatureLegacyID?
    /// 방금 만개한 재능. 화면이 축하하고 나서 비운다.
    private(set) var pendingBloom: Bloom?
    /// 방금 끝난 훈련의 영수증.
    ///
    /// 왜 따로 두는가: `pendingGains`는 **오른 것이 있을 때만** 채워진다. 그래서 성장 0으로
    /// 지나간 훈련은 화면에 아무 결과도 남기지 않았고, 사용자는 "눌렀는데 아무 일도 안
    /// 일어났다"로 읽었다. 훈련은 눌렀으면 언제나 결과가 있다 — 안 오른 것도 결과다.
    /// 이 값이 있는 동안 화면 아래에 결과 패널이 붙어, 스크롤 없이 그 자리에서 읽힌다.
    private(set) var trainingReceipt: TrainingReceipt?

    struct TrainingReceipt: Equatable {
        var focus: TrainingFocus
        /// "구위 +2" 같은 한 줄. 성장이 없으면 "능력 변화 없음".
        var headline: String
        /// 코어가 만든 설명 문장.
        var detail: String
        var gains: [MobileCareerStore.AbilityGain]
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
    private(set) var nextRunIntent: NextRunIntent? = nil
    /// 진행 중인 등판의 타석 경계 스냅샷. 앱이 죽어도 이닝이 증발하지 않는다.
    private var gameResume: PitchSession.ResumeState?
    /// 코어 경기 결과와 함께 먼저 저장되는 외부 후속 작업 영수증. 주간·분석·업적 저장
    /// 도중 앱이 종료돼도 다음 실행에서 stable ID로 정확히 한 번 마저 적용한다.
    private(set) var pendingGameCompletion: PendingGameCompletion?
    /// 별점 요청 신호. 첫 무실점 이닝처럼 감정이 양(+)인 조기 지점에서 켜진다 —
    /// 뷰가 requestReview 환경을 갖고 있으므로 스토어는 신호만 올린다.
    var reviewMoment = 0
    /// 이미 프로로 보낸 회차의 careerID.
    ///
    /// 프로 저장본의 유무로 판단하면 안 된다 — 은퇴하고 "새 선수로 다시 시작"을 누르면 프로
    /// 저장본이 지워지므로, 같은 지명으로 프로 커리어를 무한히 새로 만들 수 있다(은퇴 계승
    /// 야구혼이 그때마다 다시 적립될 여지도 있다). 고교 쪽에 사실을 남긴다.
    private(set) var enteredProCareerID: String?

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
        let previousEntered = enteredProCareerID
        let previousChronicle = chronicle
        enteredProCareerID = state.careerID
        chronicle.append(ChronicleEntry(
            stage: "\(state.chapter.schoolYear)학년 \(state.chapter.season)",
            text: "프로 유니폼을 입었습니다."
        ))
        guard save() else {
            enteredProCareerID = previousEntered
            chronicle = previousChronicle
            loadState = .failed("프로 진입 기록을 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.")
            return false
        }
        return true
    }

    struct Bloom: Equatable {
        let ability: TalentAbility
        let grade: TalentGrade
    }
    private(set) var inheritance: Inheritance = .firstLife
    /// 주간 노트처럼 커리어 밖에서 들어온 보상 영수증. optional 저장 필드로 남겨
    /// 구버전 저장본은 빈 집합으로 열고, 같은 ID는 앱 재시작·기기 동기화 뒤에도 한 번만 준다.
    private(set) var creditedExternalRewardIDs: Set<String> = []
    /// 끝난 회차들. 최근이 앞이다.
    private(set) var archive: [LifeRecord] = []
    /// 이번 회차에 세상이 붙여 준 별명들. 한 번 얻으면 회차가 끝날 때까지 남는다 —
    /// 세상은 별명을 회수하지 않는다. 조건 판정은 커널(NicknameRules)이 한다.
    private(set) var nicknames: [Nickname] = []
    /// 이번 회차의 연대기 — 이 선수가 살아온 순간들. 능력치 그래프는 결과만 남기지만
    /// 연대기는 과정을 남긴다. 애착은 과정에서 생긴다.
    private(set) var chronicle: [ChronicleEntry] = []
    /// 방금 경기에 대한 커뮤니티 반응. 저장하지 않는다 — careerID·경기 번호로
    /// 결정론이라 필요하면 언제든 다시 만들 수 있고, 반응은 "방금"의 것일 때만 살아 있다.
    private(set) var buzz: [String] = []
    /// 챕터가 넘어갈 때 세계가 만든 사건들. 저장하지 않는다 — 결정론 재파생 가능.
    private(set) var worldNews: [String] = []
    /// 이번 챕터의 훈련 누적(능력별 증가·횟수). 저장하지 않는 표시용 —
    /// 100번의 +1이 낱장으로 흩어지면 훈련 구간 전체가 "같은 화면의 반복"으로
    /// 기억된다(QA P1-15). 누적 한 줄이 "한 단위"의 체감을 만든다.
    private(set) var chapterGains: [String: Int] = [:]
    private(set) var chapterTrainingCount = 0
    /// 이번 챕터가 시작될 때의 통산 탈삼진. 챕터 목표의 진행은 이 값과의 차이다.
    private(set) var chapterStartStrikeouts: Int = 0
    /// 목표 축하를 이미 한 챕터 번호. 같은 챕터에서 두 번 축하하면 축하가 값싸진다.
    private(set) var goalCelebratedChapter: Int?
    /// 관계 응답 누적 — 성격은 선택이 만든다. 경기 성적은 여기 한 획도 못 긋는다.
    private(set) var responseTally = ResponseTally()
    /// 이번 회차에 계승·프리셋 적용을 모두 마친 직후의 선수. 마지막 능력과 비교하면
    /// 유저가 이번 3년 동안 한 땀씩 키운 양만 남는다. optional 저장으로 구버전과 호환한다.
    private(set) var careerStartingPitcher: PitcherSnapshot?
    /// 회차 시작 시 고정한 대표 유산 후보 규칙과, 결말에 처음 생성된 세 후보 원본.
    /// 후보를 한 번 보여 준 뒤 앱이 업데이트돼도 선택지가 바뀌거나 선택이 사라지지 않는다.
    private(set) var signatureLegacyRulesVersion: Int?
    private(set) var frozenSignatureLegacyCandidates: [CareerSignatureLegacy]?

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

    @ObservationIgnored private let engine = HighSchoolCareerEngine()
    @ObservationIgnored private let sync: SaveSync
    @ObservationIgnored private let weekly: WeeklyProgramStore
    @ObservationIgnored private let saveWriter: ((Data) -> Bool)?

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

    // MARK: - 수명 주기

    func restoreOrCreate() {
        guard result == nil else { return }
        applyRestoreOutcome(restore())
    }

    private func applyRestoreOutcome(_ outcome: RestoreOutcome) {
        switch outcome {
        case .live(let recoveredFromBackup):
            loadState = .ready
            _ = retryPendingGameCompletion()
            if recoveredFromBackup {
                lastSummary = "현재 환생 기록을 읽지 못해 직전 정상 백업으로 복구했습니다."
                feedbackCue = .success
                feedbackTrigger += 1
            }
        case .needsSetup:
            loadState = .needsSetup
        case .unavailable:
            loadState = .failed(Self.unreadableSaveMessage)
        }
    }

    /// 지난 회차의 설정. 원버튼 환생("같은 설정으로 다시")의 재료다.
    struct LastSetup: Codable, Equatable {
        var presetID: String
        var playerName: String
        var region: String
        var harshness: String
        var karmas: [KarmaID]
        var soulDomain: SoulDomain?
    }

    var lastSetup: LastSetup? {
        get {
            UserDefaults.standard.data(forKey: "baseball.lastSetup")
                .flatMap { try? JSONDecoder().decode(LastSetup.self, from: $0) }
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                UserDefaults.standard.removeObject(forKey: "baseball.lastSetup")
                return
            }
            UserDefaults.standard.set(data, forKey: "baseball.lastSetup")
        }
    }

    func startCareer(
        preset: PitcherPresetSnapshot,
        playerName: String,
        region: String = "서울",
        difficulty: CareerDifficultySnapshot = .standard,
        karmas: [KarmaID] = [],
        soulDomain: SoulDomain? = nil,
        soulBoosts: [SoulBoostID] = [],
        signatureLegacyID: CareerSignatureLegacyID? = nil,
        seedOverride: String? = nil,
        challengeLifeNumber: Int? = nil,
        /// 어느 입구로 회차를 시작했는가(`setup_flow` / `quick_rebirth` / `recap`).
        /// 환생 전환율을 입구별로 갈라 봐야 어느 마찰을 없앤 것이 실제로 들었는지 안다.
        entryPoint: String = "setup_flow"
    ) {
        // 시드 가드 — 오타 하나가 커널 오류 화면(그리고 예전에는 저장 삭제)으로
        // 이어지면 안 된다. 여기서 정중히 되돌린다(4차 패널 P0).
        let trimmedSeed = seedOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedSeed, !trimmedSeed.isEmpty, UInt64(trimmedSeed) == nil {
            lastSummary = "시드는 카드에 적힌 숫자만 입력할 수 있습니다. 다시 확인해 주세요."
            feedbackCue = .setback
            feedbackTrigger += 1
            return
        }
        let isChallenge = challengeLifeNumber != nil
        let previousInheritance = inheritance
        let previousLastSetup = lastSetup
        if isChallenge {} else {
        lastSetup = LastSetup(
            presetID: preset.id, playerName: playerName, region: region,
            harshness: difficulty.careerHarshness.rawValue, karmas: karmas, soulDomain: soulDomain
        )
        }
        let trimmed = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? preset.pitcher.name : trimmed
        let identity = PlayerIdentitySnapshot(
            name: name,
            throwingHand: preset.pitcher.throwingHand,
            bodyType: .balanced,
            // 코어가 모르는 지역이 오면 서울로 받는다 — 학교 이름이 조용히 서울로 바뀌는
            // 것보다, 여기서 한 번 거르는 쪽이 원인을 찾기 쉽다.
            region: HighSchoolCareerEngine.regions.contains(region) ? region : "서울"
        )
        var carried = inheritance
        // 직전 프로 커리어 영수증은 그 선수의 결말을 프로 tombstone 삭제까지 멱등하게
        // 지키는 임시 표식이다. 새 고교 선수가 durable하게 시작되는 순간에는 더 이상
        // 같은 프로 저장을 현재 선수와 결합할 수 없으므로 비워 다음 프로 기록을 받을 수 있다.
        if !isChallenge {
            carried.creditedProCareerID = nil
        }
        carried.karmas = karmas
        let requestedSignatureLegacyID = signatureLegacyID ?? carried.equippedSignatureLegacyID
        let availableLegacyIDs = Set((carried.unlockedSignatureLegacies ?? []).map(\.id))
        let equippedSignatureLegacyID: CareerSignatureLegacyID? = if isChallenge {
            nil
        } else if let requestedSignatureLegacyID,
                  availableLegacyIDs.contains(requestedSignatureLegacyID) {
            requestedSignatureLegacyID
        } else {
            carried.equippedSignatureLegacyID.flatMap {
                availableLegacyIDs.contains($0) ? $0 : nil
            }
        }
        carried.equippedSignatureLegacyID = equippedSignatureLegacyID
        // 영혼 상점 정산 — 부스트 비용은 지갑 잔액에서만 차감한다. 자동 성장 누적은
        // 별도 원장이라 구매나 프로 보너스로 조용히 움직이지 않는다.
        let boostCost = soulBoosts.reduce(0) { $0 + $1.cost }
        let purchased = boostCost <= carried.soulPoints ? soulBoosts : []
        // 차감 전에 두 누적 원장을 고정한다. nil인 옛 저장은 기존 단일 총량 의미를
        // 승계하고, 이후부터 자동 성장과 지갑 경제를 분리한다.
        let automaticSoulTotal = carried.automaticSoulTotal
        carried.soulTotalEarned = carried.soulTotal
        carried.automaticSoulEarned = automaticSoulTotal
        carried.soulPoints -= purchased.reduce(0) { $0 + $1.cost }
        do {
            let created = try engine.start(
                .init(
                    // 시드 입력은 커뮤니티 도전("이 시드로 지명 가능?")의 입구다.
                    seed: trimmedSeed?.isEmpty == false ? trimmedSeed! : String(UInt64.random(in: 1...UInt64.max)),
                    presetID: preset.id,
                    // challenge 모드는 카드의 회차를 그대로 쓴다 — 판(재능·바람·일정)은
                    // careerID("시드-회차")의 함수라 회차가 달라지면 다른 판이다.
                    lifeNumber: challengeLifeNumber ?? carried.lifeNumber,
                    // challenge 모드는 맨몸이다: 계승·기억·카르마·상점이 실리면 같은 판의
                    // 비교가 성립하지 않는다.
                    inheritedSoulPoints: isChallenge ? 0 : carried.automaticSoulTotal,
                    inheritedSoulDomain: isChallenge || carried.automaticSoulTotal == 0
                        ? nil : soulDomain,
                    inheritedMemories: isChallenge ? [] : carried.memories,
                    identity: identity,
                    difficulty: difficulty,
                    karmas: isChallenge ? [] : karmas,
                    soulBoosts: isChallenge || purchased.isEmpty ? nil : purchased,
                    inheritedSoulTotal: isChallenge ? 0 : carried.automaticSoulTotal,
                    signatureLegacyID: equippedSignatureLegacyID,
                    inheritanceRulesVersion: isChallenge ? nil : carried.inheritanceRulesVersion
                )
            )
            if !isChallenge { inheritance = carried }
            // 별명과 연대기는 이번 회차의 것이다. 환생하면 새로 쓴다.
            nicknames = []
            chronicle = []
            chapterStartStrikeouts = 0
            goalCelebratedChapter = nil
            chapterGains = [:]
            chapterTrainingCount = 0
            responseTally = ResponseTally()
            careerStartingPitcher = created.snapshot.pitcher
            signatureLegacyRulesVersion = isChallenge ? nil : Self.currentSignatureLegacyRulesVersion
            frozenSignatureLegacyCandidates = nil
            selectedSignatureLegacyID = nil
            result = created
            challengeCareerID = isChallenge ? created.snapshot.careerID : nil
            let carriedLegacyCopy: String
            if equippedSignatureLegacyID != nil, carried.memories.isEmpty {
                carriedLegacyCopy = "대표 유산 하나"
            } else if equippedSignatureLegacyID != nil {
                carriedLegacyCopy = "기억 \(carried.memories.count)장과 대표 유산 하나"
            } else {
                carriedLegacyCopy = "기억 \(carried.memories.count)장"
            }
            lastSummary = isChallenge
                ? "기록 없는 도전 — 이 판의 결과는 선수 기록과 계승에 남지 않습니다."
                : carried.lifeNumber > 1
                ? "\(carried.lifeNumber)번째 선수. \(carriedLegacyCopy)로 다시 시작합니다."
                : "고교 첫 해가 시작됩니다."
            feedbackCue = .success
            feedbackTrigger += 1
            loadState = .ready
            guard save() else {
                result = nil
                inheritance = previousInheritance
                lastSetup = previousLastSetup
                careerStartingPitcher = nil
                signatureLegacyRulesVersion = nil
                frozenSignatureLegacyCandidates = nil
                selectedSignatureLegacyID = nil
                challengeCareerID = nil
                loadState = .failed("새 선수의 시작을 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.")
                return
            }
            // 같은 결정론 시드를 다시 시작해도 지난 로컬 보조 상태가 새 회차에 붙지
            // 않는다. durable save 뒤에만 로컬 보조 상태와 외부 퍼널을 갱신한다.
            UserDefaults.standard.removeObject(forKey: pledgeKey(created.snapshot.careerID))
            UserDefaults.standard.removeObject(forKey: pledgeRulesVersionKey(created.snapshot.careerID))
            UserDefaults.standard.removeObject(forKey: rivalLedgerKey(created.snapshot.careerID))
            if !isChallenge {
                GameAnalytics.logOnce(.onboardingCompleted)
                if let equippedSignatureLegacyID {
                    let definition = CareerSignatureLegacy.definition(for: equippedSignatureLegacyID)
                    GameAnalytics.log(.signatureLegacyEquipped, [
                        "legacy_id": equippedSignatureLegacyID.rawValue,
                        "family": definition.family.rawValue,
                        "life_number": carried.lifeNumber,
                        "total_rating_bonus": definition.effect.totalRatingBonus,
                        "inheritance_rules_version": carried.inheritanceRulesVersion ?? 0,
                        "soul_total": carried.automaticSoulTotal,
                        "soul_wallet": carried.soulPoints,
                        "soul_lifetime_earned": carried.soulTotal,
                        "soul_applied": HighSchoolCareerEngine.appliedInheritance(
                            for: carried.automaticSoulTotal,
                            storedRulesVersion: carried.inheritanceRulesVersion
                        ),
                    ])
                }
                if carried.lifeNumber > 1 {
                    GameAnalytics.log(.rebirthStarted, [
                        "life_number": carried.lifeNumber,
                        "entry_point": entryPoint,
                        "selected_legacy_id": equippedSignatureLegacyID?.rawValue ?? "pre_feature_memory_bridge",
                        "inheritance_rules_version": carried.inheritanceRulesVersion ?? 0,
                        "soul_total": carried.automaticSoulTotal,
                        "soul_wallet": carried.soulPoints,
                        "soul_lifetime_earned": carried.soulTotal,
                        "soul_applied": HighSchoolCareerEngine.appliedInheritance(
                            for: carried.automaticSoulTotal,
                            storedRulesVersion: carried.inheritanceRulesVersion
                        ),
                    ])
                    weekly.record(.nextRunStarted)
                }
                // 3회차를 시작한다 = 환생 루프를 스스로 두 번 돌았다.
                if carried.lifeNumber >= 3, ReviewPrompt.shouldAsk(.thirdLife) {
                    reviewMoment += 1
                }
                AchievementStore.shared.record(AchievementRules.fromLifeNumber(carried.lifeNumber))
                AchievementStore.shared.submit(LeaderboardRules.scores(lifeNumber: carried.lifeNumber))
            }
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    /// 실패 화면의 비파괴 출구. 메모리에 진행이 있으면 돌아가고, 시작 실패면 다시 복원한다.
    func returnToSetup() {
        if result != nil {
            loadState = .ready
            return
        }
        loadState = .loading
        applyRestoreOutcome(restore())
    }

    /// 진행 중 challenge 모드의 careerID. nil이면 도전이 아니다.
    ///
    /// 처음에는 "스냅숏 회차 != 계승 회차"로 파생 판별했다 — confirmLegacy가 계승
    /// 회차를 +1 올리는 순간 **모든 정상 회차**가 challenge로 오판돼 마지막 화면
    /// (환생 스탬프·프로 진입)이 사라졌고, 회차가 우연히 같은 도전은 반대로 실계승을
    /// 오염시켰다(5차 패널 P0 ×2). 명시 플래그는 옵셔널이라 옛 저장본은 nil = 비도전.
    private(set) var challengeCareerID: String?

    var isChallengeRun: Bool {
        guard let result, let challengeCareerID else { return false }
        return result.snapshot.careerID == challengeCareerID
    }

    /// nil은 대표 유산 기능 도입 전에 시작한 진행이다. 그 회차는 당시 기억 규칙으로 끝내고,
    /// 다음 새 회차부터 현재 규칙을 저장해 사용한다.
    var usesSignatureLegacyRules: Bool {
        !isChallengeRun && Self.usesSignatureLegacyRules(storedRulesVersion: signatureLegacyRulesVersion)
    }

    nonisolated static func usesSignatureLegacyRules(storedRulesVersion: Int?) -> Bool {
        storedRulesVersion != nil
    }

    /// 기록·계승이 남지 않는 판은 주간 야구혼으로도 환산하지 않는다.
    var countsTowardWeeklyProgram: Bool { !isChallengeRun }

    /// challenge 모드를 닫는다. 아카이브·계승·야구혼 어디에도 반영하지 않는다.
    func endChallengeRun() {
        result = nil
        pitchSession = nil
        tutorialSession = nil
        pendingGameCompletion = nil
        pendingGains = []
        trainingReceipt = nil
        selectedSignatureLegacyID = nil
        careerStartingPitcher = nil
        signatureLegacyRulesVersion = nil
        frozenSignatureLegacyCandidates = nil
        challengeCareerID = nil
        loadState = .needsSetup
        save()
    }

    @discardableResult
    func deleteCareer() -> Bool {
        let deletedCareerID = result?.snapshot.careerID
        // 메모리와 보조 UserDefaults를 지우기 전에 더 높은 리비전의 묘비를 먼저 내린다.
        // 실패하면 현재 화면·진행·빠른 시작 재료가 모두 그대로여야 같은 버튼으로 재시도할 수 있다.
        let tombstoneRevision = Self.nextSavedRevision(
            after: savedRevision,
            atLeast: result?.snapshot.revision ?? 0
        )
        let tombstone = SaveRecord(
            result: nil,
            inheritance: .firstLife,
            archive: [],
            enteredProCareerID: nil,
            nicknames: nil,
            chronicle: nil,
            chapterStartStrikeouts: 0,
            goalCelebratedChapter: nil,
            responseTally: ResponseTally(),
            chapterGains: nil,
            chapterTrainingCount: nil,
            careerStartingPitcher: nil,
            signatureLegacyRulesVersion: nil,
            frozenSignatureLegacyCandidates: nil,
            selectedSignatureLegacyID: nil,
            gameResume: nil,
            challengeCareerID: nil,
            nextRunIntent: nil,
            creditedExternalRewardIDs: nil,
            currentCareerRetention: nil,
            revision: tombstoneRevision,
            schemaVersion: Self.currentSaveSchemaVersion
        )
        guard let data = try? JSONEncoder().encode(tombstone),
              saveWriter?(data) ?? sync.write(data) else { return false }
        sync.discardRecoveryCopies()
        savedRevision = tombstoneRevision

        challengeCareerID = nil
        result = nil
        pitchSession = nil
        tutorialSession = nil
        pendingGains = []
        trainingReceipt = nil
        selectedMemories = []
        selectedSignatureLegacyID = nil
        careerStartingPitcher = nil
        signatureLegacyRulesVersion = nil
        frozenSignatureLegacyCandidates = nil
        inheritance = .firstLife
        creditedExternalRewardIDs = []
        archive = []
        nicknames = []
        chronicle = []
        chapterStartStrikeouts = 0
        goalCelebratedChapter = nil
        responseTally = ResponseTally()
        chapterGains = [:]
        chapterTrainingCount = 0
        gameResume = nil
        pendingGameCompletion = nil
        nextRunIntent = nil
        lastSetup = nil
        if let deletedCareerID {
            UserDefaults.standard.removeObject(forKey: pledgeKey(deletedCareerID))
            UserDefaults.standard.removeObject(forKey: pledgeRulesVersionKey(deletedCareerID))
            UserDefaults.standard.removeObject(forKey: rivalLedgerKey(deletedCareerID))
        }
        // clear() 대신 **묘비를 쓴다.** iCloud 키-값 저장은 결국적 일관성이라 지운
        // 자리에 업로드 지연분·다른 기기의 옛 저장본이 되살아난다 — "모든 진행 삭제가
        // 가끔 안 먹힌다"의 원인. 리비전 +1의 빈 레코드는 어떤 옛 사본과 만나도 이긴다.
        loadState = .needsSetup
        return true
    }

    // MARK: - 단계 진행

    func completePrologue() {
        tutorialSession = nil
        perform { try engine.completePrologue(.init(seed: $0.nextSeed, state: $0.snapshot)) }
    }

    /// 첫 불펜을 연다. 결과는 커리어에 반영되지 않는다.
    func beginTutorialPitch() {
        guard let result, result.snapshot.phase == .prologue, tutorialSession == nil else { return }
        let session = PitchSession(scenario: .tutorial(state: result.snapshot), seed: result.nextSeed)
        session.start()
        tutorialSession = session
    }

    /// 불펜을 다시 연다. 시드를 바꿔 같은 타석의 반복 암기가 안 되게 한다.
    private var bullpenRetries = 0
    func retryTutorialPitch() {
        guard let result, result.snapshot.phase == .prologue else { return }
        bullpenRetries += 1
        // 시드는 반드시 숫자 문자열 — 커널 validate가 UInt64(seed) 파싱을 요구하므로
        // "-bullpen-N" 같은 접미사는 즉시 invalidSeed로 죽는다(3차 패널 P0).
        // 파생이 아니라 랜덤인 이유: 카운터 파생은 앱 재실행마다 같은 순서로 되돌아가
        // 연습 판을 외울 수 있다(4차 패널 P2). 연습은 픽스처가 아니다.
        let session = PitchSession(
            scenario: .tutorial(state: result.snapshot),
            seed: String(UInt64.random(in: 1...UInt64.max))
        )
        session.start()
        tutorialSession = session
    }

    /// 연습을 마치고 프롤로그를 끝낸다. 업적·기록에는 남기지 않는다.
    func finishTutorialPitch() {
        if countsTowardWeeklyProgram {
            GameAnalytics.logOnce(.firstPitch)
        }
        completePrologue()
    }

    func chooseSchool(_ schoolID: SchoolID) {
        let beforeRevision = result?.snapshot.revision
        perform { try engine.chooseSchool(.init(seed: $0.nextSeed, state: $0.snapshot, schoolID: schoolID)) }
        guard result?.snapshot.revision != beforeRevision else { return }
        if let school = result?.snapshot.school { note("\(school.name) 입학. 3년이 시작됩니다.") }
        if let selectedName = result?.snapshot.school?.name,
           let previousName = archive.first?.schoolName,
           selectedName != previousName,
           countsTowardWeeklyProgram {
            weekly.record(.differentSchoolSelected)
        }
    }

    func commitTraining(focus: TrainingFocus, intensity: TrainingIntensity) {
        guard let before = result?.snapshot else { return }
        perform { try engine.commitTraining(.init(seed: $0.nextSeed, state: $0.snapshot, focus: focus, intensity: intensity)) }
        guard let after = result?.snapshot, after.revision != before.revision else { return }
        chapterTrainingCount += 1
        for gain in pendingGains where gain.after > gain.before {
            chapterGains[gain.label, default: 0] += gain.after - gain.before
        }
        trainingReceipt = Self.receipt(training: after.lastTraining, gains: pendingGains,
                                       bloom: pendingBloom, fatigueAfter: after.fatigue, focus: focus)
        if countsTowardWeeklyProgram {
            GameAnalytics.log(.careerTrainingCompleted, [
                "life_number": after.lifeNumber,
                "act_number": HighSchoolPresentation.actNumber(chapter: after.chapter.number),
                "focus_id": focus.rawValue,
                "intensity_id": intensity.rawValue,
                "growth_points": pendingGains.reduce(0) { $0 + max(0, $1.after - $1.before) },
                "fatigue_delta": after.fatigue - before.fatigue,
            ])
        }
        // perform 안의 save()는 이 두 값이 오르기 **전**이다 — 여기서 한 번 더.
        save()
    }

    /// 같은 훈련을 최대 세 번 묶어 진행한다. 관계·각성·공식 경기 같은 선택 국면은
    /// 건너뛰지 않고 즉시 멈추며, 팔 상태가 나빠지거나 피로가 높아져도 멈춘다.
    func commitTrainingBlock(
        focus: TrainingFocus,
        intensity: TrainingIntensity,
        maximumSessions: Int = 3
    ) {
        guard maximumSessions > 1,
              let startingPitcher = result?.snapshot.pitcher else { return }
        // 묶음 전체의 피로 변화를 재려면 묶음이 시작될 때의 값이 필요하다. 마지막 한 번의
        // `fatigueBefore`를 쓰면 3회를 돌고도 마지막 1회분만 오른 것처럼 적힌다.
        let startingFatigue = result?.snapshot.fatigue ?? 0
        var completed = 0

        while completed < maximumSessions,
              result?.snapshot.phase == .training {
            let beforeRevision = result?.snapshot.revision
            commitTraining(focus: focus, intensity: intensity)
            guard result?.snapshot.revision != beforeRevision else { break }
            completed += 1

            guard result?.snapshot.phase == .training else { break }
            if pendingBloom != nil { break }
            if focus != .recovery,
               ((result?.snapshot.fatigue ?? 0) >= 75 || armHealth != .normal) {
                break
            }
        }

        guard completed > 1, let finalPitcher = result?.snapshot.pitcher else { return }
        pendingGains = MobileCareerStore.gains(before: startingPitcher, after: finalPitcher)
        let growth = pendingGains.reduce(0) { $0 + max(0, $1.after - $1.before) }
        lastSummary = "같은 훈련 \(completed)회 완료 · 능력 성장 +\(growth)"
        feedbackCue = growth > 0 ? .growth : .neutral
        feedbackTrigger += 1
        // 묶음 훈련은 마지막 한 번이 아니라 묶음 전체가 결과다.
        trainingReceipt = TrainingReceipt(
            focus: focus,
            headline: Self.gainHeadline(pendingGains),
            detail: "\(HighSchoolPresentation.focus(focus)) 훈련 \(completed)회를 이어서 마쳤습니다.",
            gains: pendingGains,
            jackpot: result?.snapshot.lastTraining?.jackpot ?? false,
            bloom: pendingBloom,
            fatigueAfter: result?.snapshot.fatigue ?? 0,
            fatigueChange: (result?.snapshot.fatigue ?? 0) - startingFatigue,
            opportunityHit: false
        )
    }

    /// 훈련 하나의 영수증. 코어가 준 값만 옮긴다 — 화면이 결과를 다시 해석하지 않는다.
    static func receipt(
        training: CareerTrainingSnapshot?,
        gains: [MobileCareerStore.AbilityGain],
        bloom: Bloom?,
        fatigueAfter: Int,
        focus: TrainingFocus
    ) -> TrainingReceipt {
        TrainingReceipt(
            focus: training?.focus ?? focus,
            headline: gainHeadline(gains),
            detail: training?.feedback ?? "훈련을 마쳤습니다.",
            gains: gains,
            jackpot: training?.jackpot ?? false,
            bloom: bloom,
            fatigueAfter: fatigueAfter,
            fatigueChange: training?.fatigueChange ?? 0,
            opportunityHit: training?.opportunityHit ?? false
        )
    }

    /// "구위 +2 · 체력 +1" 또는 "능력 변화 없음".
    static func gainHeadline(_ gains: [MobileCareerStore.AbilityGain]) -> String {
        let risen = gains.filter { $0.after > $0.before }
        guard !risen.isEmpty else { return "능력 변화 없음" }
        return risen.map { "\($0.label) +\($0.after - $0.before)" }.joined(separator: " · ")
    }

    func resolveRelationship(_ response: RelationshipResponse) {
        guard let current = result else { return }
        let before = responseTally.personality
        var candidateTally = responseTally
        switch response {
        case .listen: candidateTally.listen += 1
        case .explain: candidateTally.explain += 1
        case .challenge: candidateTally.challenge += 1
        }
        var addedChronicle: [ChronicleEntry] = []
        // 성격이 처음 굳거나 서서히 바뀐 순간은 연대기에 남긴다 — 능력치가 아니라
        // 사람됨의 사건이다.
        if let after = candidateTally.personality, after != before {
            addedChronicle.append(ChronicleEntry(
                stage: "\(current.snapshot.chapter.schoolYear)학년 \(current.snapshot.chapter.season)",
                text: before == nil
                    ? "성격이 자리 잡았습니다 — '\(after.title)'. \(after.scoutLine)"
                    : "성격이 달라졌습니다 — '\(after.title)'. 사람은 고정된 값이 아닙니다."
            ))
        }
        _ = perform(
            responseTally: candidateTally,
            appendingChronicle: addedChronicle
        ) {
            try engine.resolveRelationship(.init(
                seed: $0.nextSeed, state: $0.snapshot, response: response
            ))
        }
    }

    func chooseAwakening(_ awakening: AwakeningID) {
        guard perform(cue: .growth, {
            try engine.chooseAwakening(.init(
                seed: $0.nextSeed, state: $0.snapshot, awakening: awakening
            ))
        }) else { return }
        // 엔진이 만든 각성 문장("'○○'을 익혔습니다…")을 그대로 적는다.
        if let line = result?.snapshot.news.first { note(line) }
    }

    func advanceChapter() {
        let beforeRevision = result?.snapshot.revision
        perform { try engine.advanceChapter(.init(seed: $0.nextSeed, state: $0.snapshot)) }
        guard result?.snapshot.revision != beforeRevision else { return }
        if countsTowardWeeklyProgram {
            weekly.record(.chaptersAdvanced)
        }
        chapterStartStrikeouts = result?.snapshot.performance.strikeouts ?? chapterStartStrikeouts
        if countsTowardWeeklyProgram {
            let chapter = result?.snapshot.chapter.number ?? 0
            GameAnalytics.log(.chapterAdvanced, [
                "chapter": chapter,
                "act_number": HighSchoolPresentation.actNumber(chapter: chapter),
            ])
        }
        chapterGains = [:]
        chapterTrainingCount = 0
        if let snapshot = result?.snapshot {
            worldNews = CommunityBuzz.rivalNews(careerID: snapshot.careerID, chapterNumber: snapshot.chapter.number)
        }
        buzz = []
        save()
    }

    /// 지명된 회차를 접고 기억 선택으로 들어간다. 미지명은 이미 그 단계에 있다.
    func openLegacy() {
        // 프로에 진입한 선수는 은퇴 기록까지 한 사람의 성장으로 묶는다. 프로 진행 중 고교
        // 탭으로 돌아와 먼저 결말을 확정하면, 이후의 통산 기록이 대표 유산에서 영영 빠진다.
        guard !hasEnteredPro else {
            lastSummary = "프로 커리어를 마치면 고교 시절과 통산 기록을 함께 돌아봅니다."
            return
        }
        guard perform({
            try engine.openLegacy(.init(seed: $0.nextSeed, state: $0.snapshot))
        }) else { return }
        freezeSignatureLegacyCandidatesIfNeeded()
    }

    func resolveDraft() {
        guard perform(cue: .success, {
            try engine.resolveDraft(.init(seed: $0.nextSeed, state: $0.snapshot))
        }) else { return }
        freezeSignatureLegacyCandidatesIfNeeded()
        if let draft = result?.snapshot.draftResult {
            if countsTowardWeeklyProgram {
                GameAnalytics.log(.draftResolved, [
                    "drafted": draft.outcome == .drafted,
                    "score": draft.evaluationScore,
                    "life_number": result?.snapshot.lifeNumber ?? 0,
                    "act_number": HighSchoolPresentation.actNumber(
                        chapter: result?.snapshot.chapter.number ?? 8
                    ),
                ])
            }
            if draft.outcome == .drafted, let team = draft.team {
                note("드래프트 \(draft.round.map { "\($0)라운드 " } ?? "")\(team.name) 지명. 3년이 응답받았습니다.")
            } else {
                note("드래프트 미지명. 하지만 이 3년은 새 선수의 밑천이 됩니다.")
            }
        }
    }

    // MARK: - 중요 경기

    func beginImportantGame() {
        guard let result, result.snapshot.phase == .importantGame, pitchSession == nil else { return }
        // 프로와 같은 이유로 시드를 넘기고 저장한다. 결과 반영 전에 앱을 껐다 켜면 같은
        // 이닝을 같은 난수로 다시 던질 수 있었다(무제한 리트라이).
        let sessionSeed = MobileCareerStore.advanced(result.nextSeed)
        let checkpointed = HighSchoolCareerResult(
            revision: result.revision, nextSeed: sessionSeed, events: result.events,
            snapshot: result.snapshot, eventHash: result.eventHash
        )
        guard persist(
            result: checkpointed,
            gameResume: nil,
            chronicle: chronicle,
            responseTally: responseTally,
            nextRunIntent: nextRunIntent
        ) else { return }
        self.result = checkpointed
        gameResume = nil
        let session = PitchSession(highSchool: result.snapshot, seed: sessionSeed)
        session.start()
        session.trait = personality?.trait
        attachCheckpoint(session)
        pitchSession = session
    }

    func finishImportantGame() {
        // 앞 경기의 durable 후속 영수증을 덮어쓰지 않는다. 보통 AppShell configure에서
        // 이미 비워지지만, 주간 저장소가 계속 실패한 상태라면 현재 이닝을 그대로 보존한다.
        if pendingGameCompletion != nil, !retryPendingGameCompletion() { return }
        guard let current = result, let session = pitchSession else { return }
        let report = session.report(
            scenarioNumber: current.snapshot.performance.importantGamesCompleted + 1
        )
        let gameGrowth = CareerGameGrowth.evaluating(state: current.snapshot, report: report)
        let resultLine = "\(report.pitches)구 · \(report.strikeouts)탈삼진 · \(report.walks)볼넷 · \(report.runsAllowed)실점"
        // 직접 던진 결과가 왜 능력치로 남았는지 경기 직후 한 문장으로 잇는다.
        // 숫자 +1만 띄우면 훈련과 경기의 인과가 다시 끊어진다.
        let summary = gameGrowth.map { "\(resultLine) · \($0.title). \($0.detail)" } ?? resultLine
        do {
            let updated = try engine.recordImportantGame(.init(
                seed: current.nextSeed, state: current.snapshot, report: report
            ))
            let gains = MobileCareerStore.gains(
                before: current.snapshot.pitcher, after: updated.snapshot.pitcher
            )
            let stage = "\(updated.snapshot.chapter.schoolYear)학년 \(updated.snapshot.chapter.season)"

            // Rival, nickname, chronicle, and chapter-goal state are part of the same first
            // durable record as the core result. They cannot be reconstructed by retry after the
            // phase advances, so staging them later would create an unrecoverable crash window.
            var candidateLedger = rivalLedger
            if countsTowardWeeklyProgram {
                candidateLedger = Self.accumulating(
                    candidateLedger, outcomes: session.rivalOutcomes
                )
            }
            let retention = retentionEnvelope(
                for: updated.snapshot, rivalLedger: candidateLedger
            )
            let existingNicknameIDs = Set(nicknames.map(\.id))
            let freshNicknames = NicknameRules.earned(
                performance: updated.snapshot.performance
            ).filter { !existingNicknameIDs.contains($0.id) }
            let candidateNicknames = nicknames + freshNicknames
            var candidateChronicle = chronicle
            for earned in freshNicknames {
                candidateChronicle.append(ChronicleEntry(
                    stage: stage,
                    text: "'\(earned.title)'\(KoreanCopy.particle(earned.title, final: "이라는", open: "라는")) 별명을 얻었습니다. \(earned.reason)"
                ))
            }
            if let line = Self.gameChronicleLine(
                games: updated.snapshot.performance.importantGamesCompleted,
                report: report,
                summary: summary
            ) {
                candidateChronicle.append(ChronicleEntry(stage: stage, text: line))
            }
            var candidateGoal = goalCelebratedChapter
            var completedGoal: (title: String, progress: Int)?
            let goal = ChapterGoal.goal(
                careerID: updated.snapshot.careerID,
                chapterNumber: updated.snapshot.chapter.number
            )
            let goalProgress = updated.snapshot.performance.strikeouts - chapterStartStrikeouts
            if candidateGoal != updated.snapshot.chapter.number,
               goalProgress >= goal.targetStrikeouts {
                candidateGoal = updated.snapshot.chapter.number
                completedGoal = (goal.title, goalProgress)
                candidateChronicle.append(ChronicleEntry(
                    stage: stage,
                    text: "\(goal.title) 완수 — 이번 이야기 탈삼진 \(goalProgress)개."
                ))
            }

            let completion: PendingGameCompletion? = countsTowardWeeklyProgram
                ? PendingGameCompletion(
                    id: "hs-game:\(updated.snapshot.careerID):\(report.scenarioNumber):\(updated.snapshot.revision)",
                    report: report,
                    achievements: AchievementRules.fromInning(report: report)
                        + session.bestDeliveryAchievements
                        + AchievementRules.fromHighSchool(updated.snapshot),
                    sequenceTags: session.sequenceTagIDs,
                    recommendationAcceptanceRate: session.recommendationAcceptanceRate,
                    developmentRulesVersion: current.snapshot.balanceVersion ?? 1,
                    abilityMomentCount: session.abilityMomentCount,
                    abilityMomentTypes: session.abilityMomentIDs,
                    targetBatters: session.scenario.maximumBatters,
                    batters: session.batterIndex + 1,
                    lifeNumber: updated.snapshot.lifeNumber,
                    actNumber: HighSchoolPresentation.actNumber(
                        chapter: updated.snapshot.chapter.number
                    ),
                    chapterNumber: updated.snapshot.chapter.number,
                    enteredPhase: updated.snapshot.phase != current.snapshot.phase
                        ? updated.snapshot.phase.rawValue : nil,
                    gameGrowth: gameGrowth,
                    shouldRequestCleanReview: report.runsAllowed == 0,
                    completedAt: Date()
                ) : nil
            let overrides = PersistenceOverrides(
                nicknames: candidateNicknames,
                goalCelebratedChapter: candidateGoal,
                currentCareerRetention: retention,
                pendingGameCompletion: completion
            )
            guard persist(
                result: updated,
                gameResume: nil,
                chronicle: candidateChronicle,
                responseTally: responseTally,
                nextRunIntent: nextRunIntent,
                overrides: overrides
            ) else { return }

            result = updated
            gameResume = nil
            pitchSession = nil
            nicknames = candidateNicknames
            chronicle = candidateChronicle
            goalCelebratedChapter = candidateGoal
            pendingGameCompletion = completion
            pendingGains = gains
            if countsTowardWeeklyProgram { mirrorRetention(retention) }
            if let completedGoal {
                lastSummary = "\(completedGoal.title) 완수. 삼진 \(completedGoal.progress)개 — 숙제는 끝났고, 다음은 욕심의 영역입니다."
                feedbackCue = .success
            } else if let nickname = freshNicknames.first {
                lastSummary = "이제 사람들이 '\(nickname.title)'\(KoreanCopy.particle(nickname.title, final: "이라고", open: "라고")) 부릅니다. \(nickname.reason)"
                feedbackCue = .success
            } else {
                lastSummary = summary
                feedbackCue = report.runsAllowed == 0 ? .success : .setback
            }
            feedbackTrigger += 1
            loadState = .ready

            _ = retryPendingGameCompletion()
            buzz = CommunityBuzz.reactions(
                careerID: updated.snapshot.careerID,
                gameNumber: updated.snapshot.performance.importantGamesCompleted,
                strikeouts: report.strikeouts,
                walks: report.walks,
                runsAllowed: report.runsAllowed,
                newNickname: freshNicknames.first?.title
            )
        } catch {
            loadState = .failed(error.localizedDescription)
            // A stale/corrupt core state cannot settle this local inning. Clear it durably before
            // removing the UI; a storage failure keeps the exact session for another retry.
            if persist(
                result: current,
                gameResume: nil,
                chronicle: chronicle,
                responseTally: responseTally,
                nextRunIntent: nextRunIntent
            ) {
                gameResume = nil
                pitchSession = nil
            }
        }
    }

    /// 코어 경기 결과와 함께 저장된 후속 작업을 stable receipt로 마저 적용한다.
    ///
    /// 주간 진행을 먼저 durable하게 만든 뒤, 자체 원장을 가진 업적·리뷰·analytics를 적용하고
    /// 마지막으로 receipt를 지운다. 어느 줄 뒤에서 앱이 종료돼도 재호출은 같은 ID를 보고
    /// 중복 없이 이어진다. 주가 넘어간 영수증은 새 주로 이월하지 않고 외부 후속 작업만 닫는다.
    @discardableResult
    func retryPendingGameCompletion(
        calendar: Calendar = .current
    ) -> Bool {
        guard let completion = pendingGameCompletion else { return true }
        guard let completionMoment = WeeklyProgramMoment.resolve(
            date: completion.completedAt, calendar: calendar
        ) else { return false }

        let expired = weekly.lastObservedWeekStart.map {
            completionMoment.weekStart < $0
        } ?? false
        if !expired {
            guard weekly.record(
                .importantGamesCompleted,
                receiptID: "\(completion.id):weekly-game",
                now: completion.completedAt,
                calendar: calendar
            ) else { return false }
            let masteryCount = completion.report.sequenceMasteryCount ?? 0
            if masteryCount > 0 {
                guard weekly.record(
                    .sequenceMasteryTriggered,
                    amount: masteryCount,
                    receiptID: "\(completion.id):weekly-sequence",
                    now: completion.completedAt,
                    calendar: calendar
                ) else { return false }
            }
            // 하루에 몇 경기를 던지든 이 목표는 하루치만 오른다. 영수증 ID에 날짜를
            // 박아 같은 날의 두 번째 경기가 중복으로 세지 않게 한다.
            guard weekly.record(
                .playedOnTwoDays,
                receiptID: "played-day:\(DailyStreak.key(for: completion.completedAt))",
                now: completion.completedAt,
                calendar: calendar
            ) else { return false }
        }

        AchievementStore.shared.record(completion.achievements)
        // 첫 공식 경기 직후 시스템 리뷰 시트가 결과·성장 축하를 가로막았다.
        // 옛 영수증의 필드는 저장 호환을 위해 남기되, 요청은 3년 정산/지명/3회차처럼
        // 플레이 흐름이 이미 멈춘 긍정적 결절에서만 한다.

        let report = completion.report
        let analytics = [
            "mode": "high_school",
            "life_number": completion.lifeNumber,
            "act_number": completion.actNumber,
            "result": report.runsAllowed == 0 ? "scoreless" : "runs_allowed",
            "strikeouts": report.strikeouts,
            "walks": report.walks,
            "runs": report.runsAllowed,
            "sequence_mastery_count": report.sequenceMasteryCount ?? 0,
            "sequence_tags": completion.sequenceTags.joined(separator: ","),
            "recommendation_acceptance_rate": completion.recommendationAcceptanceRate,
            "development_rules_version": completion.developmentRulesVersion ?? 1,
            "ability_moment_count": completion.abilityMomentCount ?? 0,
            "ability_moment_types": (completion.abilityMomentTypes ?? []).joined(separator: ","),
            "target_batters": completion.targetBatters,
            "batters": completion.batters,
        ] as [String: Any]
        if GameAnalytics.logOnce(
            .gameFinished, scope: completion.id, properties: analytics
        ) {
            GameAnalytics.recordCompletedGame()
            // 연속 일수는 모드를 가리지 않는다 — 마운드에 올랐으면 야구를 한 것이다.
            // 날짜는 **영수증의 완료 시각**을 쓴다. 재시도 경로가 자정을 넘겨 불리면
            // 같은 경기가 주간 노트에는 어제로, 연속 일수에는 오늘로 들어간다.
            DailyStreak.recordPlay(now: completion.completedAt)
        }
        GameAnalytics.logOnce(.activationFirstGame)
        if let enteredPhase = completion.enteredPhase {
            GameAnalytics.logOnce(
                .phaseEntered,
                scope: "\(completion.id):phase",
                properties: [
                    "phase": enteredPhase,
                    "chapter": completion.chapterNumber,
                    "act_number": completion.actNumber,
                    "life_number": completion.lifeNumber,
                ]
            )
        }
        if let growth = completion.gameGrowth {
            GameAnalytics.logOnce(
                .gameGrowthApplied,
                scope: completion.id,
                properties: [
                    "life_number": completion.lifeNumber,
                    "act_number": completion.actNumber,
                    "reason_id": growth.reason.rawValue,
                    "growth_focus": growth.ability.rawValue,
                    "growth_points": growth.points,
                ]
            )
        }

        guard let current = result else { return false }
        let retention = retentionEnvelope(
            for: current.snapshot, rivalLedger: rivalLedger
        )
        let overrides = PersistenceOverrides(
            nicknames: nicknames,
            goalCelebratedChapter: goalCelebratedChapter,
            currentCareerRetention: retention,
            pendingGameCompletion: nil
        )
        guard persist(
            result: current,
            gameResume: gameResume,
            chronicle: chronicle,
            responseTally: responseTally,
            nextRunIntent: nextRunIntent,
            overrides: overrides
        ) else { return false }
        pendingGameCompletion = nil
        return true
    }

    /// 챕터 목표를 방금 넘었으면 한 번만 축하한다. 보상은 능력치가 아니라
    /// 축하와 기록이다 — 숫자 보상을 걸면 목표가 밸런스 뒷문이 된다.
    private func celebrateChapterGoalIfCrossed() {
        guard let snapshot = result?.snapshot else { return }
        let chapter = snapshot.chapter.number
        guard goalCelebratedChapter != chapter else { return }
        let goal = ChapterGoal.goal(careerID: snapshot.careerID, chapterNumber: chapter)
        let progress = snapshot.performance.strikeouts - chapterStartStrikeouts
        guard progress >= goal.targetStrikeouts else { return }
        goalCelebratedChapter = chapter
        note("\(goal.title) 완수 — 이번 이야기 탈삼진 \(progress)개.")
        lastSummary = "\(goal.title) 완수. 삼진 \(progress)개 — 숙제는 끝났고, 다음은 욕심의 영역입니다."
        feedbackCue = .success
        feedbackTrigger += 1
        save()
    }

    /// 경기 전부를 적지 않는다 — 처음, 완벽, 압도, 붕괴. 이야기가 되는 경기만.
    private func noteGame(report: ImportantInningReport, summary: String) {
        let games = result?.snapshot.performance.importantGamesCompleted ?? 0
        if let line = Self.gameChronicleLine(games: games, report: report, summary: summary) {
            note(line)
        }
    }

    /// 경기 결과와 같은 첫 SaveRecord에 넣을 수 있도록 순수 문구 판정으로 분리한다.
    private static func gameChronicleLine(
        games: Int,
        report: ImportantInningReport,
        summary: String
    ) -> String? {
        if games == 1 { return "첫 공식 등판 — \(summary)" }
        if report.runsAllowed == 0 { return "무실점 호투 — \(summary)" }
        if report.strikeouts >= 6 {
            return "탈삼진 \(report.strikeouts)개로 압도 — \(summary)"
        }
        if report.runsAllowed >= 5 {
            return "무너진 날 — \(summary). 이 경기를 기억해야 합니다."
        }
        return nil
    }

    /// 연대기에 한 줄을 적는다. 드물게 불러야 한다 — 매주 적으면 일기가 아니라 로그다.
    private func note(_ text: String) {
        guard let chapter = result?.snapshot.chapter else { return }
        chronicle.append(ChronicleEntry(stage: "\(chapter.schoolYear)학년 \(chapter.season)", text: text))
        save()
    }

    /// 별명이 있으면 이름 앞에 붙인다 — '제로' 김솔. 호명·프로필이 같은 규칙을 쓴다.
    func displayName(_ name: String) -> String {
        guard let latest = nicknames.last else { return name }
        return "'\(latest.title)' \(name)"
    }

    /// 경기 뒤 별명 획득 판정. 새로 얻은 별명은 그 주의 소식이 된다 —
    /// 능력치 숫자보다 "세상이 내 아이를 알아봤다"는 문장이 오래 남는다.
    private func earnNicknames() {
        guard let performance = result?.snapshot.performance else { return }
        let fresh = NicknameRules.earned(performance: performance)
            .filter { earned in !nicknames.contains { $0.id == earned.id } }
        guard !fresh.isEmpty else { return }
        nicknames.append(contentsOf: fresh)
        for earned in fresh { note("'\(earned.title)'\(KoreanCopy.particle(earned.title, final: "이라는", open: "라는")) 별명을 얻었습니다. \(earned.reason)") }
        if let first = fresh.first {
            lastSummary = "이제 사람들이 '\(first.title)'\(KoreanCopy.particle(first.title, final: "이라고", open: "라고")) 부릅니다. \(first.reason)"
            feedbackCue = .success
            feedbackTrigger += 1
        }
        save()
    }

    // MARK: - 환생

    func toggleMemory(_ id: MemoryCardID) {
        guard let state else { return }
        if let index = selectedMemories.firstIndex(of: id) {
            selectedMemories.remove(at: index)
        } else if selectedMemories.count < state.memorySlots {
            selectedMemories.append(id)
        }
    }

    /// 이번 3년의 실제 성장과 경기 기록으로 만든 대표 유산 후보. 시작 스냅숏이 없는
    /// 구저장본은 최종 선수를 기준점으로 삼아 경기·각성·관계 근거만으로 후보를 만든다.
    /// 로컬 UserDefaults의 마지막 프리셋을 추측에 쓰면 새 기기 SaveSync 복원에서 같은
    /// 커리어가 다른 세 후보를 만들 수 있으므로, 저장본 자체만 입력으로 사용한다.
    func signatureLegacyCandidates(for state: HighSchoolCareerSnapshot) -> [CareerSignatureLegacy] {
        if let frozenSignatureLegacyCandidates,
           frozenSignatureLegacyCandidates.count == 3,
           Set(frozenSignatureLegacyCandidates.map(\.id)).count == 3 {
            return frozenSignatureLegacyCandidates
        }
        return CareerSignatureLegacy.candidates(
            startingPitcher: careerStartingPitcher ?? state.pitcher,
            finalState: state,
            rulesVersion: signatureLegacyRulesVersion
        )
    }

    @discardableResult
    private func freezeSignatureLegacyCandidatesIfNeeded() -> Bool {
        guard !isChallengeRun,
              signatureLegacyRulesVersion != nil,
              frozenSignatureLegacyCandidates == nil,
              let state,
              state.phase == .legacy else { return frozenSignatureLegacyCandidates != nil || !usesSignatureLegacyRules }
        let generated = CareerSignatureLegacy.candidates(
            startingPitcher: careerStartingPitcher ?? state.pitcher,
            finalState: state,
            rulesVersion: signatureLegacyRulesVersion
        )
        guard generated.count == 3, Set(generated.map(\.id)).count == 3 else { return false }
        frozenSignatureLegacyCandidates = generated
        guard save() else {
            frozenSignatureLegacyCandidates = nil
            loadState = .failed("대표 유산 후보를 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.")
            return false
        }
        return true
    }

    /// 대표 유산 카드가 실제로 보일 때 후보 payload를 저장한다. 이후 앱 버전에서 점수식이나
    /// 문구가 바뀌어도 이미 본 세 후보와 선택은 그 회차가 끝날 때까지 그대로다.
    @discardableResult
    func prepareSignatureLegacyCandidates() -> Bool {
        freezeSignatureLegacyCandidatesIfNeeded()
    }

    func selectSignatureLegacy(_ id: CareerSignatureLegacyID) {
        guard freezeSignatureLegacyCandidatesIfNeeded() else { return }
        guard let state, signatureLegacyCandidates(for: state).contains(where: { $0.id == id }) else {
            return
        }
        let previous = selectedSignatureLegacyID
        selectedSignatureLegacyID = id
        guard save() else {
            selectedSignatureLegacyID = previous
            loadState = .failed("대표 유산 선택을 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.")
            return
        }
    }

    /// 기억 카드를 확정하고 다음 회차로 넘길 계승분을 만든다.
    func confirmLegacy() {
        // challenge 모드는 여기로 오면 안 되지만(화면이 분기한다), 방어선을 겹친다 —
        // 이 함수가 실계승·아카이브를 덮는 유일한 문이다(5차 패널 P0).
        guard !isChallengeRun else {
            endChallengeRun()
            return
        }
        guard let current = result else { return }
        let activeRulesVersion = signatureLegacyRulesVersion
        // 기능 도입 전 회차만 당시 memorySlots장을 고른다. 새 규칙은 대표 유산 하나가
        // 유일한 직접 계승이며, 옛 기억 효과를 추가로 쌓지 않는다.
        let chosen: [MemoryCardID]
        if activeRulesVersion == nil {
            guard selectedMemories.count == current.snapshot.memorySlots else { return }
            chosen = selectedMemories
        } else {
            chosen = []
        }
        let signatureCandidates: [CareerSignatureLegacy]
        let signatureLegacy: CareerSignatureLegacy?
        if activeRulesVersion == nil {
            // 기능 도입 전에 시작한 회차는 당시의 기억 선택만으로 끝낸다. nil을 v1 신규
            // 규칙으로 승격해 결말에서 갑자기 추가 선택을 강제하지 않는다.
            signatureCandidates = []
            signatureLegacy = nil
        } else {
            signatureCandidates = signatureLegacyCandidates(for: current.snapshot)
            guard let selectedSignatureLegacyID,
                  let selected = signatureCandidates.first(where: {
                      $0.id == selectedSignatureLegacyID
                  }) else { return }
            signatureLegacy = selected
        }
        // 약속 정산 — 등급별 보상을 기록과 계승이 같은 배율로 쓴다.
        let settledPledge = pledge
        let settledContext = RunPledgeContext(state: current.snapshot, rivalLedger: rivalLedger)
        let pledgeProgress = settledPledge?.progress(in: settledContext)
        let pledgeAchieved = pledgeProgress?.achieved ?? false
        let pledgeBonus = pledgeAchieved ? (settledPledge?.rewardPermille ?? 0) : 0
        do {
            let completed = try engine.selectLegacy(
                .init(
                    seed: current.nextSeed,
                    state: current.snapshot,
                    memoryCards: chosen,
                    signatureLegacyID: signatureLegacy?.id
                )
            )
            let previousInheritance = inheritance
            let previousArchive = archive
            let previousRecap = pendingRecap
            let previousStartingPitcher = careerStartingPitcher
            let previousCandidates = frozenSignatureLegacyCandidates
            let previousSelectedSignature = selectedSignatureLegacyID
            let previousSelectedMemories = selectedMemories

            let closed = Self.lifeRecord(
                from: current.snapshot, memories: chosen, previous: previousInheritance,
                nicknames: nicknames, chronicle: chronicle, personality: personality,
                pledgeBonusPermille: pledgeBonus, pledge: settledPledge, pledgeProgress: pledgeProgress,
                signatureLegacy: signatureLegacy,
                signatureLegacyCandidates: signatureCandidates.isEmpty ? nil : signatureCandidates,
                startingPitcher: careerStartingPitcher
            )
            let nextInheritance = Self.nextInheritance(
                from: current.snapshot,
                memories: chosen,
                previous: previousInheritance,
                pledgeBonusPermille: pledgeBonus,
                signatureLegacy: signatureLegacy,
                discoveredSignatureLegacies: signatureCandidates
            )
            let suggestedIntent = nextIntentSuggestion(
                settled: settledPledge, progress: pledgeProgress, state: current.snapshot
            )
            var nextArchive = archive.filter { $0.lifeNumber != closed.lifeNumber }
            nextArchive.insert(closed, at: 0)
            let recap = RunRecapView.Recap(
                record: closed,
                pledgeID: settledPledge?.id,
                pledgeTitle: settledPledge?.title,
                pledgeAchieved: pledgeAchieved,
                pledgeProgress: pledgeProgress,
                pledgeRewardPermille: settledPledge?.rewardPermille ?? 0,
                suggestedIntent: suggestedIntent,
                rivalLine: rivalLedger.summaryLine.map { "숙적 \(current.snapshot.rival.name) — \($0)" },
                soulBalance: nextInheritance.soulPoints,
                soulAutoApplied: HighSchoolCareerEngine.appliedInheritance(
                    for: nextInheritance.automaticSoulTotal,
                    storedRulesVersion: nextInheritance.inheritanceRulesVersion
                )
            )
            let deservesReview = Self.recapDeservesReview(
                closed,
                pledgeAchieved: pledgeAchieved,
                previousBestEvaluation: archive.filter { $0.lifeNumber != closed.lifeNumber }
                    .map(\.evaluationScore).max() ?? 0
            )

            result = completed
            inheritance = nextInheritance
            archive = nextArchive
            pendingRecap = recap
            selectedMemories = []
            selectedSignatureLegacyID = nil
            careerStartingPitcher = nil
            signatureLegacyRulesVersion = nil
            frozenSignatureLegacyCandidates = nil
            guard save() else {
                result = current
                inheritance = previousInheritance
                archive = previousArchive
                pendingRecap = previousRecap
                selectedMemories = previousSelectedMemories
                selectedSignatureLegacyID = previousSelectedSignature
                careerStartingPitcher = previousStartingPitcher
                signatureLegacyRulesVersion = activeRulesVersion
                frozenSignatureLegacyCandidates = previousCandidates
                loadState = .failed("이 선수의 결말을 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.")
                return
            }

            lastSummary = signatureLegacy.map {
                "\($0.title)\(KoreanCopy.particle($0.title, final: "을", open: "를")) 새 선수에게 남깁니다."
            } ?? "기억 \(chosen.count)장을 새 선수에게 남깁니다."
            feedbackCue = .growth
            feedbackTrigger += 1
            loadState = .ready

            // 외부 퍼널·주간·업적·리뷰는 위 durable save 뒤에만 발생한다.
            GameAnalytics.log(.phaseEntered, [
                "phase": completed.snapshot.phase.rawValue,
                "chapter": completed.snapshot.chapter.number,
                "act_number": HighSchoolPresentation.actNumber(chapter: completed.snapshot.chapter.number),
                "life_number": completed.snapshot.lifeNumber,
            ])
            if let settledPledge, let pledgeProgress {
                GameAnalytics.log(.runPledgeResolved, [
                    "pledge_id": settledPledge.id,
                    "achieved": pledgeProgress.achieved,
                    "progress_ratio": pledgeProgress.ratio,
                    "reward_permille": pledgeBonus,
                ])
            }
            if let signatureLegacy {
                GameAnalytics.log(.signatureLegacySelected, [
                    "legacy_id": signatureLegacy.id.rawValue,
                    "family": signatureLegacy.family.rawValue,
                    "life_number": current.snapshot.lifeNumber,
                    "drafted": current.snapshot.draftResult?.outcome == .drafted,
                    "rating_growth": signatureLegacy.evidence.ratingGrowth ?? 0,
                    "includes_pro_career": signatureLegacy.evidence.proPerformance != nil,
                    "pro_seasons": signatureLegacy.evidence.proPerformance?.seasons ?? 0,
                ])
            }
            GameAnalytics.log(.lifeCompleted, [
                "life_number": current.snapshot.lifeNumber,
                "act_number": HighSchoolPresentation.actNumber(chapter: current.snapshot.chapter.number),
                "drafted": current.snapshot.draftResult?.outcome == .drafted,
                "evaluation": current.snapshot.draftResult?.evaluationScore ?? 0,
                "trainings": current.snapshot.totalTrainingsCompleted,
                "important_games": current.snapshot.performance.importantGamesCompleted,
                "pitches": current.snapshot.performance.pitches,
                "legacy_id": signatureLegacy?.id.rawValue ?? "pre_feature_memory_bridge",
                "legacy_rules_version": activeRulesVersion ?? 0,
                "unlocked_legacy_count": nextInheritance.unlockedSignatureLegacies?.count ?? 0,
                "inheritance_rules_version": nextInheritance.inheritanceRulesVersion ?? 0,
                "soul_total": nextInheritance.automaticSoulTotal,
                "soul_wallet": nextInheritance.soulPoints,
                "soul_lifetime_earned": nextInheritance.soulTotal,
                "soul_applied": HighSchoolCareerEngine.appliedInheritance(
                    for: nextInheritance.automaticSoulTotal,
                    storedRulesVersion: nextInheritance.inheritanceRulesVersion
                ),
            ])
            AchievementStore.shared.record(AchievementRules.fromHighSchool(completed.snapshot))
            AchievementStore.shared.record(AchievementRules.fromArchive(nextArchive))
            if deservesReview, ReviewPrompt.shouldAsk(.goodRecap) {
                reviewMoment += 1
            }
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    /// 다음 회차를 시작한다. 계승분은 유지하고 진행만 비운다.
    ///
    /// 진행을 비운 직후에도 **즉시 저장한다.** 예전에는 여기서 저장을 지우기만 했고
    /// `save()`가 진행 없이는 아무것도 쓰지 않아서, "다시 태어나기"를 누른 순간부터
    /// 새 선수 생성 완료까지 계승분(야구혼·기억·아카이브)이 메모리에만 있었다 —
    /// 그 사이가 하필 이름을 고민하는 화면이라, 앱이 내려가면 회차 전체가 1회차로 리셋됐다.
    func beginNextLife() {
        result = nil
        pitchSession = nil
        pendingGains = []
        trainingReceipt = nil
        selectedSignatureLegacyID = nil
        careerStartingPitcher = nil
        signatureLegacyRulesVersion = nil
        frozenSignatureLegacyCandidates = nil
        loadState = .needsSetup
        save()
    }

    /// 지난 회차와 같은 설정으로 곧장 다음 회차를 연다. 설정을 다시 물을 것이 없으면 nil.
    ///
    /// 왜: 회차가 끝난 뒤 다음 회차까지의 길이 정산 → 완료 화면 → 다시 태어나기 → 스탬프
    /// → 설정 4단계였다. 2026-08 데이터에서 드래프트를 본 42명 중 27명만 다음 회차를
    /// 시작했다. 로그라이트에서 "다시 한 판"은 마찰이 0에 가까워야 하는 행동이다.
    /// 영혼 상점을 쓰려면 여전히 단계대로 갈 수 있다 — 그 길을 없애지는 않는다.
    var quickRebirthPreset: PitcherPresetSnapshot? {
        guard !isChallengeRun, let last = lastSetup else { return nil }
        return PitcherPresetCatalog.all.first { $0.id == last.presetID }
    }

    /// 위 프리셋으로 즉시 시작한다. 부스트는 회차마다 다시 고르는 소비라 싣지 않는다.
    func startQuickRebirth(entryPoint: String) {
        guard let preset = quickRebirthPreset, let last = lastSetup else { return }
        startCareer(
            preset: preset,
            playerName: last.playerName,
            region: last.region,
            difficulty: CareerDifficultySnapshot(
                careerHarshness: DifficultyLevel(rawValue: last.harshness) ?? .standard),
            karmas: last.karmas,
            soulDomain: last.soulDomain,
            entryPoint: entryPoint
        )
    }

    /// 이 정산이 별점을 물어도 좋은 회차인가. 순수 함수라 테스트할 수 있다.
    ///
    /// "잘 끝났다"는 지명 여부가 아니다 — 세상이 이름을 붙여 줬거나, 걸었던 약속을
    /// 지켰거나, 지난 회차들보다 나은 평가를 받았으면 플레이어는 만족한 상태로
    /// 이 화면을 본다. 아무것도 해당하지 않는 회차(첫 판을 망친 경우)에서는 묻지 않는다.
    nonisolated static func recapDeservesReview(
        _ record: LifeRecord,
        pledgeAchieved: Bool,
        previousBestEvaluation: Int
    ) -> Bool {
        if record.drafted { return true }
        if pledgeAchieved { return true }
        if record.nicknames?.isEmpty == false { return true }
        return record.evaluationScore > previousBestEvaluation
    }

    /// 끝난 회차를 한 장으로 접는다. 순수 함수라 테스트할 수 있다.
    nonisolated static func lifeRecord(
        from state: HighSchoolCareerSnapshot,
        memories: [MemoryCardID],
        previous: Inheritance,
        nicknames: [Nickname] = [],
        chronicle: [ChronicleEntry] = [],
        personality: Personality? = nil,
        pledgeBonusPermille: Int = 0,
        pledge: RunPledge? = nil,
        pledgeProgress: RunPledgeProgress? = nil,
        signatureLegacy: CareerSignatureLegacy? = nil,
        signatureLegacyCandidates: [CareerSignatureLegacy]? = nil,
        /// 이 회차를 시작할 때의 능력. 카드가 "얼마나 키웠는지"를 말하려면 시작점이 있어야 한다.
        startingPitcher: PitcherSnapshot? = nil
    ) -> LifeRecord {
        var record = LifeRecord(
            lifeNumber: state.lifeNumber,
            playerName: state.identity.name,
            schoolName: state.school?.name,
            drafted: state.draftResult?.outcome == .drafted,
            evaluationScore: state.draftResult?.evaluationScore ?? 0,
            teamName: state.draftResult?.team?.name,
            memories: memories,
            games: state.performance.importantGamesCompleted,
            strikeouts: state.performance.strikeouts,
            walks: state.performance.walks,
            runsAllowed: state.performance.runsAllowed,
            soulPoints: nextInheritance(from: state, memories: memories, previous: previous, pledgeBonusPermille: pledgeBonusPermille).soulPoints
                - previous.soulPoints,
            talent: state.talent,
            awakenings: state.selectedAwakenings,
            karmas: state.karmas,
            harshness: state.difficulty.careerHarshness.rawValue,
            schoolStrength: state.school.map { HighSchoolPresentation.focus($0.strength) },
            nicknames: nicknames.isEmpty ? nil : nicknames.map(\.title),
            chronicle: chronicle.isEmpty ? nil : chronicle.map { "\($0.stage) — \($0.text)" },
            coachName: state.school?.coachName,
            catcherName: state.school?.catcherName,
            rivalName: state.rival.name,
            personality: personality?.title,
            careerID: state.careerID,
            pledgeID: pledge?.id,
            pledgeTitle: pledge?.title,
            pledgeTier: pledge?.tier.rawValue,
            pledgeRewardPermille: pledge?.rewardPermille,
            pledgeAchieved: pledgeProgress?.achieved,
            pledgeProgressCurrent: pledgeProgress?.current,
            pledgeProgressTarget: pledgeProgress?.target,
            pledgeProgressLine: pledgeProgress?.line,
            pledgeProgressRatioPermille: pledgeProgress?.ratioPermille,
            windID: state.careerWind.id,
            windTitle: state.careerWind.title,
            signatureLegacy: signatureLegacy,
            signatureLegacyCandidates: signatureLegacyCandidates
        )
        record.pitches = state.performance.pitches
        record.outs = state.performance.outs
        record.hits = state.performance.hits
        record.abilityFinal = LifeRecord.AbilityLine(state.pitcher)
        // 시작 능력을 모르는 경로(옛 저장에서 이어 온 회차)에서는 성장 줄을 접는다 —
        // 최종만 있는데 "얼마나 키웠나"를 말하면 거짓이 된다.
        record.abilityStart = startingPitcher.map(LifeRecord.AbilityLine.init)
        record.playerLegacy = PlayerBondStory.legacy(for: record)
        return record
    }

    /// 회차 보상 계산. 순수 함수라 테스트할 수 있다.
    nonisolated static func nextInheritance(
        from state: HighSchoolCareerSnapshot,
        memories: [MemoryCardID],
        previous: Inheritance,
        pledgeBonusPermille: Int = 0,
        signatureLegacy: CareerSignatureLegacy? = nil,
        discoveredSignatureLegacies: [CareerSignatureLegacy] = []
    ) -> Inheritance {
        // 영혼 포인트는 능력 총합과 경기 기록, 카르마 보상 배율에서 나온다. 실패한 회차도
        // 0이 되지는 않는다 — 환생물의 재접속 장치는 "다음엔 조금 더 강하다"이다.
        let ratings = state.pitcher.stuff + state.pitcher.command + state.pitcher.movement + state.pitcher.stamina
        let record = state.performance.strikeouts * 2 - state.performance.walks - state.performance.runsAllowed * 2
        let base = max(4, ratings / 8 + max(0, record) / 4)
        // 코어의 legacyRewardPermille는 이미 1000(×1.0)을 포함한 배율이다. 여기서 1000을
        // 또 더하면 카르마 없이 ×2.0이 되고, 화면의 "+35%"가 실제로는 절반만 전달된다.
        // 약속 이행 보너스는 배율에 가산한다(‰). 이중 가산 금지 원칙은 그대로 —
        // 1000(×1.0)은 legacyRewardPermille가 이미 품고 있다.
        let rewarded = base * (max(1_000, state.legacyRewardPermille) + pledgeBonusPermille) / 1_000
        var next = Inheritance(
            lifeNumber: previous.lifeNumber + 1,
            memories: memories,
            soulPoints: previous.soulPoints + rewarded,
            karmas: previous.karmas
        )
        next.soulTotalEarned = previous.soulTotal + rewarded
        next.automaticSoulEarned = previous.automaticSoulTotal + rewarded
        next.inheritanceRulesVersion = SoulInheritanceRulesVersion.current.rawValue
        // 프로 기록 저장은 성공했지만 프로 tombstone 쓰기가 실패한 사이에도 사용자는 고교
        // 유산 정산을 끝낼 수 있다. 새 선수를 실제로 시작하기 전까지 동일 프로 영수증을
        // 보존해야 남아 있는 은퇴 저장이 야구혼과 후보를 다시 지급하지 못한다.
        next.creditedProCareerID = previous.creditedProCareerID
        var unlocked = previous.unlockedSignatureLegacies ?? []
        for discovered in discoveredSignatureLegacies where !unlocked.contains(where: { $0.id == discovered.id }) {
            unlocked.append(discovered)
        }
        unlocked.sort { $0.id.rawValue < $1.id.rawValue }
        next.unlockedSignatureLegacies = unlocked.isEmpty ? nil : unlocked
        next.equippedSignatureLegacyID = signatureLegacy?.id ?? previous.equippedSignatureLegacyID
        return next
    }

    // MARK: - 프로 커리어의 계승

    /// 프로 저장에 적힌 원본 고교와 현재 고교 회차가 같은지 확인한다. 필드가 없던 구버전
    /// 프로 저장은 고교 쪽 진입 영수증과 동일한 선수 신원까지 맞을 때만 안전하게 연결한다.
    func canAttachProLegacy(
        _ proState: ProCareerSnapshot?,
        sourceHighSchoolCareerID: String?,
        allowsLegacySourceMigration: Bool = false
    ) -> Bool {
        guard let proState,
              let current = result?.snapshot,
              current.draftResult?.outcome == .drafted,
              current.identity == proState.identity else { return false }
        // 명시 source가 있으면 그것이 권위다. 구버전처럼 source가 없으면 현재 지명 선수와
        // 신원이 일치하고, 영수증이 없거나 현재 회차를 가리킬 때만 정규 경로로 복원한다.
        if let sourceHighSchoolCareerID {
            return sourceHighSchoolCareerID == current.careerID
                && (enteredProCareerID == nil || enteredProCareerID == current.careerID)
        }
        guard allowsLegacySourceMigration else { return false }
        // origin/source가 모두 없던 시대에는 direct Pro도 같은 모양이었다. 정규 진입은
        // 투수 ID와 최초 프로 구단이 고교 지명 결과와 같아야 하므로 이 두 불변값까지 맞춘다.
        let entryTeamID = proState.careerStats.first?.teamID ?? proState.currentStats.teamID
        guard current.pitcher.id == proState.pitcher.id,
              current.draftResult?.team?.id == entryTeamID else { return false }
        return enteredProCareerID == nil || enteredProCareerID == current.careerID
    }

    /// 은퇴한 프로 커리어를 다음 회차의 야구혼과 대표 유산 후보로 접는다.
    ///
    /// 예전에는 15년 명예의 전당 커리어도 계승에 0을 남겼다 — 환생 루프가 고교 스냅숏만
    /// 읽어서, 드래프트 직후 바로 접은 회차와 전설로 은퇴한 회차가 다음 회차에서 완전히
    /// 같았다. 프로에서의 시간이 환생과 아무 관계가 없으면, 게임의 후반 전체가 루프
    /// 바깥에 있게 된다.
    @discardableResult
    func recordProLegacy(
        _ proState: ProCareerSnapshot?,
        sourceHighSchoolCareerID: String? = nil,
        allowsLegacySourceMigration: Bool = false
    ) -> Bool {
        guard let proState,
              proState.phase == .completed,
              let current = result,
              canAttachProLegacy(
                  proState,
                  sourceHighSchoolCareerID: sourceHighSchoolCareerID,
                  allowsLegacySourceMigration: allowsLegacySourceMigration
              ),
              [.completed, .legacy].contains(current.snapshot.phase) else { return false }

        // 다른 프로 커리어의 영수증이 같은 고교 회차에 붙는 것은 저장 연결이 깨진 상태다.
        // 조용히 덮으면 야구혼과 유산 근거가 서로 다른 선수가 된다.
        if let credited = inheritance.creditedProCareerID, credited != proState.proCareerID {
            return false
        }
        // 첫 저장은 이미 성공했고 프로 tombstone 삭제만 재시도하는 경우다. 사용자가 그 사이
        // 후보를 고르거나 유산 정산까지 끝냈어도 완료 상태를 다시 `.legacy`로 열지 않는다.
        // credited 영수증은 후보/야구혼/고교 상태를 한 번에 durable save한 뒤에만 생긴다.
        if inheritance.creditedProCareerID == proState.proCareerID {
            return true
        }

        let opened: HighSchoolCareerResult
        do {
            opened = current.snapshot.phase == .legacy
                ? current
                : try engine.openLegacy(.init(seed: current.nextSeed, state: current.snapshot))
        } catch {
            loadState = .failed(error.localizedDescription)
            return false
        }

        let combinedCandidates: [CareerSignatureLegacy]?
        if signatureLegacyRulesVersion != nil {
            let generated = CareerSignatureLegacy.candidates(
                startingPitcher: careerStartingPitcher ?? current.snapshot.pitcher,
                highSchoolState: current.snapshot,
                proCareer: proState,
                rulesVersion: signatureLegacyRulesVersion
            )
            guard generated.count == 3, Set(generated.map(\.id)).count == 3 else { return false }
            combinedCandidates = generated
        } else {
            // 기능 도입 전에 시작한 선수는 당시 기억 카드 규칙으로 마무리한다.
            combinedCandidates = nil
        }

        let previousResult = result
        let previousInheritance = inheritance
        let previousCandidates = frozenSignatureLegacyCandidates
        let previousSelection = selectedSignatureLegacyID
        let previousEnteredProCareerID = enteredProCareerID
        let creditsNewProCareer = inheritance.creditedProCareerID == nil

        result = opened
        // source/entered 필드가 없던 정상 고교→프로 저장도 이번 원자 저장에서 연결 영수증을
        // 보강한다. 그래야 프로 삭제 뒤 같은 지명으로 다시 들어가 중복 보상을 만들지 못한다.
        enteredProCareerID = current.snapshot.careerID
        if creditsNewProCareer {
            let bonus = Self.proSoulBonus(for: proState)
            inheritance.creditedProCareerID = proState.proCareerID
            // Legacy saves had a single total. Freeze that historical automatic amount before
            // adding the Pro wallet credit so a long career does not silently alter the next
            // high-school pitcher's ratings.
            inheritance.automaticSoulEarned = inheritance.automaticSoulTotal
            inheritance.soulTotalEarned = inheritance.soulTotal + bonus
            inheritance.soulPoints += bonus
        }
        // 고교 기록만으로 미리 생성된 후보가 있더라도 프로 은퇴 시점에는 통산 기록을 포함한
        // 세 후보로 교체하고 다시 고르게 한다. 선택과 실제 근거가 어긋나지 않게 한다.
        frozenSignatureLegacyCandidates = combinedCandidates
        selectedSignatureLegacyID = nil

        guard save() else {
            result = previousResult
            inheritance = previousInheritance
            frozenSignatureLegacyCandidates = previousCandidates
            selectedSignatureLegacyID = previousSelection
            enteredProCareerID = previousEnteredProCareerID
            loadState = .failed("프로 기록을 유산으로 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.")
            return false
        }

        loadState = .ready
        lastSummary = combinedCandidates == nil
            ? "프로 커리어를 마쳤습니다. 이제 당시 규칙대로 남길 기억을 고릅니다."
            : "고교 시절과 프로 통산 기록에서 대표 유산 세 가지를 찾았습니다."
        feedbackCue = .growth
        feedbackTrigger += 1
        if creditsNewProCareer {
            GameAnalytics.log(.proLegacyRecorded, [
                "life_number": current.snapshot.lifeNumber,
                "pro_seasons": proState.careerStats.count,
                "soul_bonus": Self.proSoulBonus(for: proState),
                "has_signature_candidates": combinedCandidates != nil,
            ])
        }
        return true
    }

    /// 오늘의 이닝 하루 몫을 야구혼으로 얹는다.
    ///
    /// 이 모드는 완료해도 야구혼이 0이라, 커리어를 키우는 사람에게 3분을 쓸 이유가
    /// 순위표뿐이었다 — DAU의 7%만 열었고, 입구는 이미 거의 모든 국면에 있으니
    /// **입구 문제가 아니라 보상 문제였다.** 하루 한 번만 지급하고(영수증에 날짜를
    /// 박는다) 액수는 작게 둔다: 스며듦 곡선에서 +1점 남짓이라 계승 상한 구조를
    /// 흔들지 않는다.
    @discardableResult
    func creditDailyInning(dayKey: String, soulPoints: Int = 5) -> Bool {
        guard soulPoints > 0 else { return false }
        let receipt = "daily-inning:\(dayKey)"
        if creditedExternalRewardIDs.contains(receipt) { return true }

        let previousInheritance = inheritance
        let previousReceipts = creditedExternalRewardIDs
        creditedExternalRewardIDs.insert(receipt)
        inheritance.soulTotalEarned = inheritance.soulTotal + soulPoints
        inheritance.soulPoints += soulPoints
        guard save() else {
            inheritance = previousInheritance
            creditedExternalRewardIDs = previousReceipts
            return false
        }
        GameAnalytics.log(.dailyInningRewarded, [
            "soul_points": soulPoints,
            "life_number": inheritance.lifeNumber,
        ])
        return true
    }

    /// 고교를 건너뛰고 시작한 프로 커리어는 특정 고교 선수의 대표 유산으로 꾸미지 않는다.
    /// 대신 통산 무게만 야구혼으로 안전하게 남기고 현재 고교 진행은 그대로 보존한다.
    @discardableResult
    func recordStandaloneProLegacy(_ proState: ProCareerSnapshot?) -> Bool {
        guard let proState, proState.phase == .completed else { return false }
        let receipt = "standalone-pro:\(proState.proCareerID)"
        if creditedExternalRewardIDs.contains(receipt) { return true }

        let previousInheritance = inheritance
        let previousReceipts = creditedExternalRewardIDs
        let bonus = Self.proSoulBonus(for: proState)
        creditedExternalRewardIDs.insert(receipt)
        inheritance.automaticSoulEarned = inheritance.automaticSoulTotal
        inheritance.soulTotalEarned = inheritance.soulTotal + bonus
        inheritance.soulPoints += bonus
        guard save() else {
            inheritance = previousInheritance
            creditedExternalRewardIDs = previousReceipts
            loadState = .failed("프로 기록을 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.")
            return false
        }

        loadState = result == nil ? .needsSetup : .ready
        GameAnalytics.log(.proLegacyRecorded, [
            "life_number": inheritance.lifeNumber,
            "pro_seasons": proState.careerStats.count,
            "soul_bonus": bonus,
            "has_signature_candidates": false,
        ])
        return true
    }

    /// 외부 야구혼 보상을 영수증과 함께 원자적으로 받아들인다.
    ///
    /// 이미 받은 ID도 `true`를 돌려준다. 보상 저장 뒤 주간 저장이 끊긴 경우 호출자가
    /// 안전하게 `claimed`를 마저 기록할 수 있고, 잔액은 두 번 오르지 않는다.
    @discardableResult
    func acceptExternalSoulReward(id: String, soulPoints: Int) -> Bool {
        guard !id.isEmpty, soulPoints > 0 else { return false }
        if creditedExternalRewardIDs.contains(id) { return true }
        let previousInheritance = inheritance
        let previousRewardIDs = creditedExternalRewardIDs
        let previousAutomaticSoul = inheritance.automaticSoulTotal
        let previousSoulTotal = inheritance.soulTotal
        creditedExternalRewardIDs.insert(id)
        inheritance.soulTotalEarned = previousSoulTotal + soulPoints
        inheritance.automaticSoulEarned = previousAutomaticSoul + soulPoints
        inheritance.soulPoints += soulPoints
        guard save() else {
            inheritance = previousInheritance
            creditedExternalRewardIDs = previousRewardIDs
            return false
        }
        return true
    }

    /// 프로 커리어가 남기는 야구혼. 스펙(메타 계승)의 프로 스케일을 따른다:
    /// 짧은 2군 커리어 ~30, 평범한 1군 커리어 ~80~120, 20시즌 전설은 300+까지 오른다.
    nonisolated static func proSoulBonus(for state: ProCareerSnapshot) -> Int {
        proSoulBonus(
            seasons: state.careerStats.count,
            strikeouts: state.careerStats.reduce(0) { $0 + $1.strikeouts },
            awards: state.awards.count,
            hallOfFameScore: state.hallOfFameScore ?? 0
        )
    }

    nonisolated static func proSoulBonus(seasons: Int, strikeouts: Int, awards: Int, hallOfFameScore: Int) -> Int {
        // 20은 지명받아 프로 유니폼을 입었다는 것 자체의 무게다.
        20 + seasons * 3 + strikeouts / 25 + awards * 8 + hallOfFameScore / 2
    }

    func acknowledgeGains() {
        pendingGains = []
    }

    // MARK: - 숙적 전적 · 고교 3년 목표

    /// 라이벌 상대 통산(회차 내) 전적. 타석·삼진·안타만 있으면 서사는 화면이 만든다.
    struct RivalLedger: Codable, Equatable {
        var plateAppearances = 0
        var strikeouts = 0
        var walks = 0
        var hits = 0
        var summaryLine: String? {
            guard plateAppearances > 0 else { return nil }
            return "\(plateAppearances)타석 \(strikeouts)삼진 \(hits)피안타"
        }
    }

    /// UserDefaults-only state did not follow SaveSync/iCloud to a new device. This optional
    /// envelope distinguishes a legacy save with no field from a new save whose player explicitly
    /// has not chosen (nil) or skipped (empty string) the current pledge.
    struct CurrentCareerRetention: Codable, Equatable {
        var careerID: String
        var pledgeID: String?
        /// nil is a save from before versioning. If it contains a selected/skipped value, v1 is
        /// the only safe interpretation; new decisions always persist v2 explicitly.
        var pledgeRulesVersion: Int? = nil
        var rivalLedger: RivalLedger
    }

    private func rivalLedgerKey(_ careerID: String) -> String { "baseball.rivalLedger.\(careerID)" }

    var rivalLedger: RivalLedger {
        guard let careerID = result?.snapshot.careerID,
              let data = UserDefaults.standard.data(forKey: rivalLedgerKey(careerID)),
              let ledger = try? JSONDecoder().decode(RivalLedger.self, from: data) else { return RivalLedger() }
        return ledger
    }

    private func accumulateRivalLedger(_ outcomes: [PlateAppearanceResult]) {
        guard let careerID = result?.snapshot.careerID, !outcomes.isEmpty else { return }
        let ledger = Self.accumulating(rivalLedger, outcomes: outcomes)
        if let data = try? JSONEncoder().encode(ledger) {
            UserDefaults.standard.set(data, forKey: rivalLedgerKey(careerID))
            // Mirror the updated ledger into the authoritative SaveSync record as well.
            save()
        }
    }

    private static func accumulating(
        _ current: RivalLedger,
        outcomes: [PlateAppearanceResult]
    ) -> RivalLedger {
        var ledger = current
        for outcome in outcomes {
            ledger.plateAppearances += 1
            switch outcome {
            case .strikeout: ledger.strikeouts += 1
            case .walk: ledger.walks += 1
            case .hit: ledger.hits += 1
            case .inPlayOut: break
            }
        }
        return ledger
    }

    private func retentionEnvelope(
        for state: HighSchoolCareerSnapshot,
        rivalLedger: RivalLedger
    ) -> CurrentCareerRetention {
        let careerID = state.careerID
        let pledgeID = UserDefaults.standard.string(forKey: pledgeKey(careerID))
        return CurrentCareerRetention(
            careerID: careerID,
            pledgeID: pledgeID,
            pledgeRulesVersion: UserDefaults.standard.object(forKey: pledgeKey(careerID)) == nil
                ? nil : pledgeRulesVersion,
            rivalLedger: rivalLedger
        )
    }

    private func mirrorRetention(_ retention: CurrentCareerRetention) {
        let pledgeStorageKey = pledgeKey(retention.careerID)
        if let pledgeID = retention.pledgeID {
            UserDefaults.standard.set(pledgeID, forKey: pledgeStorageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: pledgeStorageKey)
        }
        let versionStorageKey = pledgeRulesVersionKey(retention.careerID)
        if let version = retention.pledgeRulesVersion {
            UserDefaults.standard.set(version, forKey: versionStorageKey)
        } else if retention.pledgeID != nil {
            UserDefaults.standard.set(RunPledge.legacyRulesVersion, forKey: versionStorageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: versionStorageKey)
        }
        if let data = try? JSONEncoder().encode(retention.rivalLedger) {
            UserDefaults.standard.set(data, forKey: rivalLedgerKey(retention.careerID))
        }
    }

    private func pledgeKey(_ careerID: String) -> String { "baseball.pledge.\(careerID)" }
    private func pledgeRulesVersionKey(_ careerID: String) -> String {
        "baseball.pledgeRulesVersion.\(careerID)"
    }

    private var pledgeRulesVersion: Int {
        guard let careerID = result?.snapshot.careerID else { return RunPledge.currentRulesVersion }
        if let number = UserDefaults.standard.object(
            forKey: pledgeRulesVersionKey(careerID)
        ) as? NSNumber {
            return number.intValue
        }
        // A selected value with no version was written by the shipped v1 implementation.
        if UserDefaults.standard.object(forKey: pledgeKey(careerID)) != nil {
            return RunPledge.legacyRulesVersion
        }
        return RunPledge.currentRulesVersion
    }

    /// 이번 회차에 걸어 둔 약속. 프롤로그에서 한 번 고르면 회차가 끝날 때 정산된다.
    var pledge: RunPledge? {
        guard let careerID = result?.snapshot.careerID,
              let id = UserDefaults.standard.string(forKey: pledgeKey(careerID)) else { return nil }
        return RunPledge.pledge(id: id, rulesVersion: pledgeRulesVersion)
    }

    /// 약속을 걸었는가(넘긴 것도 결정이다) — 프롤로그 카드가 다시 묻지 않기 위한 표식.
    var pledgeDecided: Bool {
        guard let careerID = result?.snapshot.careerID else { return true }
        return UserDefaults.standard.object(forKey: pledgeKey(careerID)) != nil
    }

    @discardableResult
    func choosePledge(_ id: String?) -> Bool {
        guard let current = result else { return false }
        let state = current.snapshot
        // 기록 없는 도전은 정산·보상·주간 기록을 남기지 않는다. 목표 선택도 받지 않아
        // canonical 재도전 의도와 analytics를 소비하지 않는 것이 화면의 약속과 같다.
        guard countsTowardWeeklyProgram else { return false }
        let careerID = state.careerID
        let recommended = id != nil && nextRunIntent?.pledgeID == id
        let storedID = id ?? ""
        let chosen = id.flatMap {
            RunPledge.pledge(id: $0, rulesVersion: RunPledge.currentRulesVersion)
        }
        var candidateChronicle = chronicle
        if let chosen {
            candidateChronicle.append(ChronicleEntry(
                stage: "\(state.chapter.schoolYear)학년 \(state.chapter.season)",
                text: "고교 3년 목표 — \(chosen.title)."
            ))
        }
        let retention = CurrentCareerRetention(
            careerID: careerID,
            pledgeID: storedID,
            pledgeRulesVersion: RunPledge.currentRulesVersion,
            rivalLedger: rivalLedger
        )
        guard persist(
            result: current,
            gameResume: gameResume,
            chronicle: candidateChronicle,
            responseTally: responseTally,
            nextRunIntent: nil,
            currentCareerRetention: retention
        ) else { return false }

        chronicle = candidateChronicle
        nextRunIntent = nil
        UserDefaults.standard.set(storedID, forKey: pledgeKey(careerID))
        UserDefaults.standard.set(
            RunPledge.currentRulesVersion, forKey: pledgeRulesVersionKey(careerID)
        )
        if let chosen {
            lastSummary = "목표를 정했습니다: \(chosen.title). 이루면 계승 포인트 +\(chosen.rewardPermille / 10)%."
            feedbackCue = .growth
            feedbackTrigger += 1
            GameAnalytics.log(.runPledgeSelected, [
                "pledge_id": chosen.id,
                "tier": chosen.tier.rawValue,
                "life_number": state.lifeNumber,
                "recommended": recommended,
            ])
            if recommended {
                GameAnalytics.log(.nextRunIntentApplied, [
                    "pledge_id": chosen.id, "life_number": state.lifeNumber,
                ])
            }
            weekly.record(.pledgeSelected)
        } else {
            GameAnalytics.log(.runPledgeSelected, [
                "pledge_id": "none", "tier": "none",
                "life_number": state.lifeNumber, "recommended": false,
            ])
        }
        // Any explicit decision consumes the carry-over: matching applies it, every other choice discards it.
        return true
    }

    @discardableResult
    func saveNextRunIntent(_ intent: NextRunIntent) -> Bool {
        guard RunPledge.pledge(id: intent.pledgeID) != nil else { return false }
        guard persist(
            result: result,
            gameResume: gameResume,
            chronicle: chronicle,
            responseTally: responseTally,
            nextRunIntent: intent
        ) else { return false }
        nextRunIntent = intent
        GameAnalytics.log(.nextRunIntentSaved, [
            "pledge_id": intent.pledgeID,
            "source_life_number": intent.sourceLifeNumber,
        ])
        return true
    }

    private func nextIntentSuggestion(
        settled: RunPledge?,
        progress: RunPledgeProgress?,
        state: HighSchoolCareerSnapshot
    ) -> NextRunIntent? {
        if let settled, progress?.achieved != true {
            return NextRunIntent(
                pledgeID: settled.id,
                sourceLifeNumber: state.lifeNumber,
                reason: RunPledge.retryIntentReason
            )
        }
        let context = RunPledgeContext(state: state, rivalLedger: rivalLedger)
        guard let candidate = RunPledge.options(careerID: state.careerID, state: state)
            .first(where: { $0.id != settled?.id && !$0.progress(in: context).achieved }) else { return nil }
        return NextRunIntent(
            pledgeID: candidate.id,
            sourceLifeNumber: state.lifeNumber,
            reason: "아카이브에 아직 완주하지 않은 목표입니다."
        )
    }

    func acknowledgeBloom() {
        pendingBloom = nil
    }

    // MARK: - 저장

    /// 회차를 넘어 단조 증가하는 저장 리비전. 진행(result)이 없는 계승-전용 레코드도
    /// 이 값으로 충돌 판정을 이겨야, 오래된 iCloud 사본이 방금 끝난 회차를 되살리지 않는다.
    private var savedRevision: UInt64 = 0

    @discardableResult
    func save() -> Bool {
        persist(
            result: result,
            gameResume: gameResume,
            chronicle: chronicle,
            responseTally: responseTally,
            nextRunIntent: nextRunIntent
        )
    }

    private struct PersistenceOverrides {
        let nicknames: [Nickname]
        let goalCelebratedChapter: Int?
        let currentCareerRetention: CurrentCareerRetention?
        let pendingGameCompletion: PendingGameCompletion?
    }

    /// 후보 SaveRecord를 먼저 쓴다. 호출자는 true 뒤에만 관찰 상태/UserDefaults를 바꾼다.
    private func persist(
        result candidateResult: HighSchoolCareerResult?,
        gameResume candidateGameResume: PitchSession.ResumeState?,
        chronicle candidateChronicle: [ChronicleEntry],
        responseTally candidateResponseTally: ResponseTally,
        nextRunIntent candidateNextRunIntent: NextRunIntent?,
        currentCareerRetention retentionOverride: CurrentCareerRetention? = nil,
        overrides: PersistenceOverrides? = nil
    ) -> Bool {
        // 진행이 없어도 계승분과 아카이브는 쓴다. 이게 없으면 회차 사이(기억 확정 후 ~
        // 새 선수 생성 전)에 앱이 내려갈 때 환생 진행 전체가 사라진다.
        let candidateRevision = Self.nextSavedRevision(
            after: savedRevision,
            atLeast: candidateResult?.snapshot.revision ?? 0
        )
        let currentCareerRetention = overrides?.currentCareerRetention
            ?? retentionOverride ?? candidateResult.map { current in
            retentionEnvelope(for: current.snapshot, rivalLedger: rivalLedger)
        }
        let persistedNicknames = overrides?.nicknames ?? nicknames
        let persistedGoalCelebratedChapter = overrides.map(\.goalCelebratedChapter)
            ?? goalCelebratedChapter
        let persistedPendingGameCompletion = overrides.map(\.pendingGameCompletion)
            ?? pendingGameCompletion
        let record = SaveRecord(
            result: candidateResult,
            inheritance: inheritance,
            archive: archive,
            enteredProCareerID: enteredProCareerID,
            nicknames: persistedNicknames.isEmpty ? nil : persistedNicknames,
            chronicle: candidateChronicle.isEmpty ? nil : candidateChronicle,
            chapterStartStrikeouts: chapterStartStrikeouts,
            goalCelebratedChapter: persistedGoalCelebratedChapter,
            responseTally: candidateResponseTally,
            chapterGains: chapterGains.isEmpty ? nil : chapterGains,
            chapterTrainingCount: chapterTrainingCount == 0 ? nil : chapterTrainingCount,
            careerStartingPitcher: careerStartingPitcher,
            signatureLegacyRulesVersion: signatureLegacyRulesVersion,
            frozenSignatureLegacyCandidates: frozenSignatureLegacyCandidates,
            selectedSignatureLegacyID: selectedSignatureLegacyID,
            gameResume: candidateGameResume,
            challengeCareerID: challengeCareerID,
            nextRunIntent: candidateNextRunIntent,
            creditedExternalRewardIDs: creditedExternalRewardIDs.isEmpty ? nil : creditedExternalRewardIDs,
            currentCareerRetention: currentCareerRetention,
            pendingGameCompletion: persistedPendingGameCompletion,
            revision: candidateRevision,
            schemaVersion: Self.currentSaveSchemaVersion
        )
        guard let data = try? JSONEncoder().encode(record),
              saveWriter?(data) ?? sync.write(data) else {
            return false
        }
        savedRevision = candidateRevision
        return true
    }

    /// 다른 기기에서 진행이 올라왔을 때 다시 읽는다.
    func reloadFromSync() {
        if pitchSession != nil || tutorialSession != nil {
            _ = applyHigherResultlessRecordDuringSession()
            return
        }
        let currentRevision = savedRevision
        let outcome = restore()
        switch outcome {
        case .live(let recoveredFromBackup):
            guard savedRevision > currentRevision || recoveredFromBackup else { return }
            loadState = .ready
            _ = retryPendingGameCompletion()
            lastSummary = recoveredFromBackup
                ? "iCloud 환생 기록을 읽지 못해 직전 정상 백업으로 복구했습니다."
                : "다른 기기의 진행을 불러왔습니다."
            feedbackTrigger += 1
        case .needsSetup:
            // A higher result-less record is either a remote deletion tombstone or the durable
            // between-lives state. In both cases the old live player must disappear immediately.
            loadState = .needsSetup
            lastSummary = nil
        case .unavailable:
            if result == nil {
                loadState = .failed(Self.unreadableSaveMessage)
            } else {
                lastSummary = "iCloud 환생 기록을 읽지 못해 이 기기의 진행을 유지합니다."
                feedbackCue = .setback
                feedbackTrigger += 1
            }
        }
    }

    /// 다른 기기의 더 높은 삭제/회차-사이 레코드는 진행 중 이닝보다 우선한다.
    /// live 진행은 이닝을 보존하기 위해 갈아끼우지 않지만, result가 없는 권위 레코드를
    /// 무시하면 이닝 종료 저장이 삭제된 선수를 다시 iCloud에 올릴 수 있다.
    @discardableResult
    private func applyHigherResultlessRecordDuringSession() -> Bool {
        guard let data = sync.read(
            revision: Self.saveRevision,
            conflictPriority: Self.saveConflictPriority
        ),
        let record = Self.decodeSaveRecord(data),
        record.result == nil,
        record.effectiveRevision >= savedRevision else { return false }

        let removedCareerID = result?.snapshot.careerID
        inheritance = record.inheritance
        if inheritance.soulTotalEarned == nil { inheritance.soulTotalEarned = inheritance.soulPoints }
        if inheritance.automaticSoulEarned == nil {
            inheritance.automaticSoulEarned = inheritance.soulTotal
        }
        archive = record.archive ?? []
        enteredProCareerID = record.enteredProCareerID
        nicknames = record.nicknames ?? []
        chronicle = record.chronicle ?? []
        chapterStartStrikeouts = record.chapterStartStrikeouts ?? 0
        goalCelebratedChapter = record.goalCelebratedChapter
        responseTally = record.responseTally ?? ResponseTally()
        chapterGains = record.chapterGains ?? [:]
        chapterTrainingCount = record.chapterTrainingCount ?? 0
        careerStartingPitcher = record.careerStartingPitcher
        signatureLegacyRulesVersion = record.signatureLegacyRulesVersion
        frozenSignatureLegacyCandidates = record.frozenSignatureLegacyCandidates
        selectedSignatureLegacyID = record.selectedSignatureLegacyID
        challengeCareerID = record.challengeCareerID
        nextRunIntent = record.nextRunIntent
        creditedExternalRewardIDs = record.creditedExternalRewardIDs ?? []
        pendingGameCompletion = record.pendingGameCompletion
        savedRevision = record.effectiveRevision
        result = nil
        pitchSession = nil
        tutorialSession = nil
        gameResume = nil
        pendingGains = []
        trainingReceipt = nil
        pendingBloom = nil
        pendingRecap = nil
        selectedMemories = []
        loadState = .needsSetup
        lastSummary = nil
        if let removedCareerID {
            UserDefaults.standard.removeObject(forKey: pledgeKey(removedCareerID))
            UserDefaults.standard.removeObject(forKey: pledgeRulesVersionKey(removedCareerID))
            UserDefaults.standard.removeObject(forKey: rivalLedgerKey(removedCareerID))
        }
        return true
    }

    /// 진행이 없어도(회차 사이) 계승분을 담을 수 있게 `result`가 옵셔널이다.
    /// 테스트에서 인코딩 호환을 검증하므로 private이 아니다.
    struct SaveRecord: Codable {
        let result: HighSchoolCareerResult?
        let inheritance: Inheritance
        /// 옵셔널이라 이 필드가 없는 옛 저장본도 그대로 열린다.
        var archive: [LifeRecord]?
        /// 이미 프로로 보낸 회차. 없는 옛 저장본은 nil이다.
        var enteredProCareerID: String?
        /// 이번 회차의 별명. 없는 옛 저장본은 빈 목록으로 시작한다.
        var nicknames: [Nickname]? = nil
        /// 이번 회차의 연대기. 없는 옛 저장본은 빈 목록으로 시작한다.
        var chronicle: [ChronicleEntry]? = nil
        /// 챕터 목표 진행 기준점·축하 여부. 없는 옛 저장본은 현재 값으로 초기화된다.
        var chapterStartStrikeouts: Int? = nil
        var goalCelebratedChapter: Int? = nil
        /// 성격을 만든 선택들. 없는 옛 저장본은 0에서 시작한다.
        var responseTally: ResponseTally? = nil
        /// 이번 챕터의 훈련 성장 정산. 없으면 챕터 리뷰가 "훈련 없이 지나간 챕터"라고
        /// 방금 한 플레이를 부정한다(3차 패널 P1) — 옛 저장본은 빈 값으로 시작한다.
        var chapterGains: [String: Int]? = nil
        var chapterTrainingCount: Int? = nil
        /// 이번 회차의 직접 성장량 기준과 아직 확정하지 않은 대표 유산 선택.
        /// 모두 optional이라 기능 도입 전 저장본은 그대로 열린다.
        var careerStartingPitcher: PitcherSnapshot? = nil
        var signatureLegacyRulesVersion: Int? = nil
        var frozenSignatureLegacyCandidates: [CareerSignatureLegacy]? = nil
        var selectedSignatureLegacyID: CareerSignatureLegacyID? = nil
        /// 진행 중 등판의 타석 경계 스냅샷. 없는 옛 저장본은 nil이다.
        var gameResume: PitchSession.ResumeState? = nil
        /// 진행 중 challenge 모드의 careerID. 없는 옛 저장본은 nil = 비도전이다.
        var challengeCareerID: String? = nil
        /// 지난 회차에서 직접 저장한 재도전 목표. 없는 옛 저장본은 추천 없음이다.
        var nextRunIntent: NextRunIntent? = nil
        /// 외부 보상 중복 지급 방지 영수증. 없는 옛 저장본은 빈 집합이다.
        var creditedExternalRewardIDs: Set<String>? = nil
        /// 현재 회차의 약속 결정·숙적 원장. 없는 옛 저장본은 기존 UserDefaults를 migration
        /// source로 사용하고, 다음 저장부터 이 필드에 함께 싣는다.
        var currentCareerRetention: CurrentCareerRetention? = nil
        /// 경기 코어 결과는 저장됐지만 주간·분석·업적 후속 작업이 남은 영수증.
        /// 없는 옛 저장본은 미처리 작업이 없는 것으로 읽는다.
        var pendingGameCompletion: PendingGameCompletion? = nil
        /// 계승-전용 레코드의 충돌 판정용. 없는 옛 저장본은 진행의 리비전으로 판정한다.
        var revision: UInt64?
        /// nil은 버전 필드 도입 전 저장이다. 미래 버전은 덮지 않고 업데이트를 기다린다.
        var schemaVersion: Int? = nil

        var effectiveRevision: UInt64 {
            max(revision ?? 0, result?.snapshot.revision ?? 0)
        }
    }

    /// 같은 리비전에서 다른 기기의 live 진행과 삭제/회차-사이 레코드가 충돌하면
    /// result-less 쪽이 이긴다. stable ID나 문구가 아니라 저장 의미만 본다.
    private static func saveConflictPriority(_ data: Data) -> Int {
        guard let record = decodeSaveRecord(data) else {
            return 0
        }
        return record.result == nil ? 1 : 0
    }

    private enum RestoreOutcome: Equatable {
        case live(recoveredFromBackup: Bool)
        case needsSetup
        case unavailable
    }

    private static func nextSavedRevision(after current: UInt64, atLeast minimum: UInt64) -> UInt64 {
        let incremented = current == UInt64.max ? UInt64.max : current + 1
        return max(incremented, minimum)
    }

    private static func decodeSaveRecord(_ data: Data) -> SaveRecord? {
        guard let record = try? JSONDecoder().decode(SaveRecord.self, from: data) else {
            return nil
        }
        let version = record.schemaVersion ?? 1
        guard (1...currentSaveSchemaVersion).contains(version) else { return nil }
        return record
    }

    private static func saveRevision(_ data: Data) -> UInt64? {
        decodeSaveRecord(data)?.effectiveRevision
    }

    private func restore() -> RestoreOutcome {
        let recovered: Bool
        let data: Data
        switch sync.readRecovering(
            revision: Self.saveRevision,
            conflictPriority: Self.saveConflictPriority
        ) {
        case .missing:
            return .needsSetup
        case .unreadable:
            return .unavailable
        case .value(let candidate, let source):
            data = candidate
            recovered = source == .backup
        }
        guard let record = Self.decodeSaveRecord(data) else { return .unavailable }
        inheritance = record.inheritance
        // 분리 회계 마이그레이션 — 총량 필드가 없는 옛 저장본은 잔액을 총량으로 승계한다.
        // 이 한 줄이 없으면 첫 구매 순간 평생 총량이 잔액으로 붕괴한다(3차 패널 P0).
        if inheritance.soulTotalEarned == nil { inheritance.soulTotalEarned = inheritance.soulPoints }
        if inheritance.automaticSoulEarned == nil {
            inheritance.automaticSoulEarned = inheritance.soulTotal
        }
        archive = record.archive ?? []
        enteredProCareerID = record.enteredProCareerID
        nicknames = record.nicknames ?? []
        chronicle = record.chronicle ?? []
        chapterStartStrikeouts = record.chapterStartStrikeouts
            ?? record.result?.snapshot.performance.strikeouts ?? 0
        goalCelebratedChapter = record.goalCelebratedChapter
        responseTally = record.responseTally ?? ResponseTally()
        chapterGains = record.chapterGains ?? [:]
        chapterTrainingCount = record.chapterTrainingCount ?? 0
        careerStartingPitcher = record.careerStartingPitcher
        signatureLegacyRulesVersion = record.signatureLegacyRulesVersion
        frozenSignatureLegacyCandidates = record.frozenSignatureLegacyCandidates
        selectedSignatureLegacyID = record.selectedSignatureLegacyID
        challengeCareerID = record.challengeCareerID
        nextRunIntent = record.nextRunIntent
        creditedExternalRewardIDs = record.creditedExternalRewardIDs ?? []
        pendingGameCompletion = record.pendingGameCompletion
        savedRevision = record.effectiveRevision
        // Clear every live-only observation before branching on result. Without this, a higher
        // remote tombstone updates the revision but leaves the old player/session in memory and a
        // later save can publish that deleted player again.
        result = nil
        pitchSession = nil
        tutorialSession = nil
        gameResume = nil
        pendingGains = []
        trainingReceipt = nil
        pendingBloom = nil
        pendingRecap = nil
        selectedMemories = []
        buzz = []
        worldNews = []
        // 진행이 없는 레코드는 "회차 사이"다 — 계승분만 안고 새 선수 만들기로 간다.
        guard let saved = record.result else { return .needsSetup }
        result = saved
        if let retention = record.currentCareerRetention,
           retention.careerID == saved.snapshot.careerID {
            mirrorRetention(retention)
        }
        // 등판 도중에 내려간 앱 — 타석 경계에서 이어 던진다. 시나리오가 지금 스냅샷에서
        // 같은 id로 재구성될 때만 복원한다(스냅샷이 달라졌으면 그 이닝은 이미 다른 세계다).
        if saved.snapshot.phase == .importantGame,
           let resume = record.gameResume,
           PitchScenario.highSchool(state: saved.snapshot).id == resume.scenarioID {
            // 이 필드가 없던 버전은 모든 고교 승부가 최대 4타자였다. 새 2/5/6타자
            // 규칙으로 재계산하면 저장 뒤 재접속만으로 같은 경기의 길이가 달라진다.
            let savedMaximumBatters = max(1, min(6, resume.maximumBatters ?? 4))
            let scenario = PitchScenario.highSchool(
                state: saved.snapshot,
                maximumBattersOverride: savedMaximumBatters
            )
            let session = PitchSession(scenario: scenario, seed: resume.seed)
            session.start()
            session.restore(from: resume)
            session.trait = personality?.trait
            attachCheckpoint(session)
            gameResume = resume
            pitchSession = session
        }
        return .live(recoveredFromBackup: recovered)
    }

    /// 세션의 타석 경계마다 진행을 디스크로. 등판이 통째로 날아가는 일은 유료 게임의
    /// 환불 사유다 — 체크포인트는 타석 단위라 리트라이 스커밍도 열리지 않는다.
    private func attachCheckpoint(_ session: PitchSession) {
        session.onCheckpoint = { [weak self] session in
            guard let self, let result = self.result else { return }
            let resume = session.resumeState()
            guard self.persist(
                result: result,
                gameResume: resume,
                chronicle: self.chronicle,
                responseTally: self.responseTally,
                nextRunIntent: self.nextRunIntent
            ) else { return }
            self.gameResume = resume
        }
    }

    /// 등판 중단 — 지금까지의 이닝을 버린다. 시드는 이미 넘어가 있어 같은 이닝의
    /// 리트라이는 아니다(안티치트 설계 그대로).
    @discardableResult
    func abandonImportantGame() -> Bool {
        guard let result, pitchSession != nil else { return false }
        guard persist(
            result: result,
            gameResume: nil,
            chronicle: chronicle,
            responseTally: responseTally,
            nextRunIntent: nextRunIntent
        ) else { return false }
        // 손맛 구간에서 나간 사람. 국면 계측이 "중요 경기에 들어갔다"까지만 알려 주므로,
        // 들어가서 던지다 나간 것과 화면만 보고 나간 것을 여기서 가른다.
        if countsTowardWeeklyProgram {
            GameAnalytics.log(.gameAbandoned, [
                "pitches": pitchSession?.pitches ?? 0,
                "chapter": result.snapshot.chapter.number,
                "life_number": result.snapshot.lifeNumber,
                "act_number": HighSchoolPresentation.actNumber(
                    chapter: result.snapshot.chapter.number
                ),
                "phase": result.snapshot.phase.rawValue,
                "development_rules_version": result.snapshot.balanceVersion ?? 1,
                "games_completed": result.snapshot.performance.importantGamesCompleted,
            ])
        }
        pitchSession = nil
        gameResume = nil
        lastSummary = "등판을 중단했습니다. 다음 마운드는 새 이닝입니다."
        feedbackCue = .setback
        feedbackTrigger += 1
        return true
    }

    @discardableResult
    private func perform(
        summary: String? = nil,
        cue: MobileCareerStore.FeedbackCue? = nil,
        clearGameResumeOnSuccess: Bool = false,
        responseTally candidateResponseTally: ResponseTally? = nil,
        appendingChronicle additionalChronicle: [ChronicleEntry] = [],
        _ action: (HighSchoolCareerResult) throws -> HighSchoolCareerResult
    ) -> Bool {
        guard let current = result else { return false }
        do {
            let before = current.snapshot
            let updated = try action(current)
            let gains = MobileCareerStore.gains(
                before: before.pitcher, after: updated.snapshot.pitcher
            )
            var bloom = pendingBloom
            var candidateChronicle = chronicle + additionalChronicle
            // 이번 동작에서 새로 만개했는가. 훈련 번호가 바뀐 것만 센다 — 안 그러면 같은
            // 훈련 결과를 들고 있는 동안 화면을 넘길 때마다 축하가 다시 뜬다.
            if let training = updated.snapshot.lastTraining,
               training.number != before.lastTraining?.number,
               let ability = training.bloomedAbility, let grade = training.bloomedGrade {
                bloom = Bloom(ability: ability, grade: grade)
                candidateChronicle.append(ChronicleEntry(
                    stage: "\(updated.snapshot.chapter.schoolYear)학년 \(updated.snapshot.chapter.season)",
                    text: "만개 — 막혀 있던 \(ability.label) 재능이 \(grade.label)까지 열렸습니다."
                ))
            }
            let nextSummary = summary ?? Self.progressSummary(before: before, after: updated.snapshot)
            let nextCue = cue ?? (gains.isEmpty ? .neutral : .growth)
            let nextResponseTally = candidateResponseTally ?? responseTally
            let nextResume = clearGameResumeOnSuccess ? nil : gameResume
            guard persist(
                result: updated,
                gameResume: nextResume,
                chronicle: candidateChronicle,
                responseTally: nextResponseTally,
                nextRunIntent: nextRunIntent
            ) else { return false }

            result = updated
            gameResume = nextResume
            responseTally = nextResponseTally
            pendingGains = gains
            pendingBloom = bloom
            chronicle = candidateChronicle
            lastSummary = nextSummary
            feedbackCue = nextCue
            feedbackTrigger += 1
            loadState = .ready
            // 국면 진입과 업적은 durable save가 성공한 뒤에만 외부로 보낸다.
            if updated.snapshot.phase != before.phase, !isChallengeRun {
                GameAnalytics.log(.phaseEntered, [
                    "phase": updated.snapshot.phase.rawValue,
                    "chapter": updated.snapshot.chapter.number,
                    "act_number": HighSchoolPresentation.actNumber(
                        chapter: updated.snapshot.chapter.number
                    ),
                    "life_number": updated.snapshot.lifeNumber,
                ])
            }
            // challenge 모드는 업적도 쌓지 않는다 — "기록에 남지 않습니다"는 업적 포함이다.
            if !isChallengeRun {
                AchievementStore.shared.record(AchievementRules.fromHighSchool(updated.snapshot))
            }
            return true
        } catch {
            loadState = .failed(error.localizedDescription)
            return false
        }
    }

    nonisolated static func progressSummary(before: HighSchoolCareerSnapshot, after: HighSchoolCareerSnapshot) -> String {
        if let training = after.lastTraining, training.number != before.lastTraining?.number {
            return training.feedback
        }
        if let relationship = after.lastRelationship, relationship.number != before.lastRelationship?.number {
            // relationship.category는 신뢰 회계용 채널이라 집·취재·팬 장면도 coach/catcher로
            // 접힌다 — 그대로 화자를 만들면 없는 자리의 감독이 "웃었다"(4차 패널 P1).
            // 원본 장면의 카테고리(방금 소비된 이벤트)가 핵심 3인일 때만 반응을 붙인다.
            // 화자·이름은 **원본 카테고리**에서 뽑는다. relationship.category는 신뢰
            // 회계 채널이라 rival 장면이 coach로 접히기도 한다(5차 패널 P2).
            // 원본을 모르는 경로(nil)에는 반응을 붙이지 않는다 — 지어낸 화자보다 침묵.
            guard let originalCategory = before.currentRelationshipEvent?.category,
                  ["coach", "catcher", "rival"].contains(originalCategory) else {
                return relationship.feedback
            }
            // 코어의 결과 문구 앞에 "그 사람이 어떻게 반응했는지"를 한 줄 붙인다.
            //
            // 예전에는 응답을 누르면 결과 요약 한 줄로 끝났다. 포수가 어떻게 반응했는지가
            // 없으니 관계가 숫자(팀의 믿음 60)로만 존재했다(품질 평가 §4.3).
            let speaker: RelationshipVoiceCatalog.Speaker
            switch originalCategory {
            case "coach": speaker = .coach
            case "catcher": speaker = .catcher
            default: speaker = .rival
            }
            let speakerName: String? = switch originalCategory {
            case "coach": after.school?.coachName
            case "catcher": after.school?.catcherName
            default: after.rival.name
            }
            let aftermath = RelationshipVoiceCatalog.aftermath(
                speaker: speaker,
                name: speakerName,
                response: relationship.response,
                trustChange: relationship.trustAfter - relationship.trustBefore
            )
            return "\(aftermath) \(relationship.feedback)"
        }
        if after.chapter.number != before.chapter.number {
            return "\(after.chapter.title) · \(after.chapter.season)"
        }
        return after.news.first ?? "다음 일정이 준비됐습니다."
    }

}
