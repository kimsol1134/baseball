import Foundation
import Observation
import SimulationCore
import BaseballIOSDomain
import BaseballIOSPersistence

@MainActor
@Observable
final class MobileCareerStore {
    /// Schema 2 is the last journey-nil format that production builds may continue to write.
    /// Schema 3 is the first format that is allowed to carry the Wave 1 journey aggregate or a
    /// journey-generation tombstone. Keeping the two write versions explicit prevents a legacy
    /// path from silently downgrading a journey save.
    static var legacySaveSchemaVersion: Int { ProCareerPersistence.legacySchemaVersion }
    static var journeySaveSchemaVersion: Int { ProCareerPersistence.journeySchemaVersion }
    static var currentSaveSchemaVersion: Int { ProCareerPersistence.currentSchemaVersion }
    static let unreadableSaveMessage = "저장 데이터는 남아 있지만 현재 버전에서 읽을 수 없습니다. 앱을 삭제하거나 새 커리어를 시작하지 말고 다시 불러오기를 눌러 주세요."

    typealias ProCareerOrigin = BaseballIOSDomain.ProCareerOrigin
    typealias FeedbackCue = BaseballIOSDomain.FeedbackCue
    typealias AbilityGain = BaseballIOSDomain.AbilityGain
    typealias ProSaveRecord = ProCareerSaveRecord
    typealias RestoreOutcome = ProCareerRestoreOutcome

    enum LoadState: Equatable {
        case loading
        /// 저장된 커리어가 없다. 선수 유형을 고르는 화면으로 간다.
        case needsSetup
        case ready
        case failed(String)
    }

    var loadState: LoadState = .loading
    /// 내구 필드는 하나씩 둔다. 한 가방에 넣으면 리비전만 바뀌어도 `result`를 보는
    /// 화면이 같이 갱신된다. 디스크 왕복만 `ProCareerPersistedState`로 모은다.
    private var durableResult: ProCareerResult?
    private var durableGameResume: PitchResumeState?
    private var durableSourceHighSchoolCareerID: String?
    private var durableCareerOrigin: ProCareerOrigin?
    private var durableSyncedRevision: UInt64 = 0
    private var durablePendingInjuryEvent: ProInjuryEventSnapshot?
    private var durableAcknowledgedInjuryEventID: String?

    func capturePersisted() -> ProCareerPersistedState {
        ProCareerPersistedState(
            result: durableResult,
            gameResume: durableGameResume,
            sourceHighSchoolCareerID: durableSourceHighSchoolCareerID,
            careerOrigin: durableCareerOrigin,
            syncedRevision: durableSyncedRevision,
            pendingInjuryEvent: durablePendingInjuryEvent,
            acknowledgedInjuryEventID: durableAcknowledgedInjuryEventID
        )
    }

    func updatePersisted(_ body: (inout ProCareerPersistedState) -> Void) {
        var next = capturePersisted()
        body(&next)
        replacePersisted(next)
    }

    func replacePersisted(_ next: ProCareerPersistedState) {
        assign(&durableResult, next.result)
        assign(&durableGameResume, next.gameResume)
        assign(&durableSourceHighSchoolCareerID, next.sourceHighSchoolCareerID)
        assign(&durableCareerOrigin, next.careerOrigin)
        assign(&durableSyncedRevision, next.syncedRevision)
        assign(&durablePendingInjuryEvent, next.pendingInjuryEvent)
        assign(&durableAcknowledgedInjuryEventID, next.acknowledgedInjuryEventID)
    }

    private func assign<T: Equatable>(_ storage: inout T, _ next: T) {
        if storage != next { storage = next }
    }

    var result: ProCareerResult? { durableResult }
    var pendingInjuryEvent: ProInjuryEventSnapshot? { durablePendingInjuryEvent }
    /// 주간 계획은 플레이어가 직접 고른다. 기본값을 두면 버튼을 누른 사실만으로
    /// "내 선택"처럼 보이고, 회복 뒤에도 같은 계획이 여러 주 반복될 수 있다.
    var selectedPlan: ProWeekPlan?
    /// 변화구 성장 계획에서 실제로 완성할 결정구.
    var selectedDevelopmentPitch: PitchType = .slider
    var lastSummary: String?
    var feedbackTrigger = 0
    var feedbackCue: FeedbackCue = .neutral
    var pendingGains: [AbilityGain] = []
    /// 정규 고교 드래프트에서 이어진 프로라면 원래 고교 careerID를 저장한다.
    /// nil은 고교를 건너뛰었거나 이 필드가 없던 구저장본이다. `careerOrigin`이 둘을 가른다.
    var sourceHighSchoolCareerID: String? { durableSourceHighSchoolCareerID }
    /// nil은 이 필드가 없던 구버전 저장뿐이다. 새 direct/highSchool 시작은 반드시 명시한다.
    var careerOrigin: ProCareerOrigin? { durableCareerOrigin }
    /// 진행 중인 중요 경기. `importantGame` 단계에서만 존재한다.
    var pitchSession: PitchSession?

    @ObservationIgnored let engine: ProCareerEngine
    @ObservationIgnored let featureConfiguration: AppFeatureConfiguration
    @ObservationIgnored let sync: SaveSync
    @ObservationIgnored let weekly: WeeklyProgramStore
    /// 테스트는 이 경계에서만 저장 실패를 주입한다. nil이면 실제 SaveSync를 쓴다.
    @ObservationIgnored let saveWriter: ((Data) -> Bool)?

    var state: ProCareerSnapshot? { result?.snapshot }

    var isBlockedByUnreadableSave: Bool {
        if case .failed(Self.unreadableSaveMessage) = loadState { return true }
        return false
    }

    init(
        sync: SaveSync = SaveSync(key: "baseball-mobile-pro-v1.json"),
        weekly: WeeklyProgramStore = .shared,
        saveWriter: ((Data) -> Bool)? = nil,
        configuration: AppFeatureConfiguration = .production
    ) {
        self.engine = ProCareerEngine(journeyEnabled: configuration.proCareerJourneyV1)
        self.featureConfiguration = configuration
        self.sync = sync
        self.weekly = weekly
        self.saveWriter = saveWriter
    }


    var gameResume: PitchResumeState? { durableGameResume }
    var syncedRevision: UInt64 { durableSyncedRevision }
}
