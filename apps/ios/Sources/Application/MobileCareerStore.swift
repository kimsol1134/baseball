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

    typealias LoadState = CareerLoadState

    var loadState: LoadState = .loading
    /// 내구 필드는 하나씩 둔다. 한 가방에 넣으면 리비전만 바뀌어도 `result`를 보는
    /// 화면이 같이 갱신된다. 디스크 왕복만 `ProCareerPersistedState`로 모은다.
    private var durableResult: ProCareerResult?
    private var durableGameResume: PitchResumeState?
    /// 앨범에 남은 재생. 커리어 진행과 무관한 증거라 스냅샷 밖에 산다.
    private var durableReplays: [AlbumReplay]?
    /// 이번 등판이 남긴 재생. 저장이 성공할 때 앨범으로 접히고 비워진다 — 저장이
    /// 실패하면 앨범도 움직이지 않아야 화면과 디스크가 어긋나지 않는다.
    var stagedReplays: [AlbumReplay] = []
    /// 이미 적용한 명령의 영수증.
    private var durableCommandReceipts: [String]?
    /// 이번 저장에 태울 명령. 저장이 성공할 때 영수증으로 남고 비워진다.
    var stagedCommandOperation: String?
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
            acknowledgedInjuryEventID: durableAcknowledgedInjuryEventID,
            replays: durableReplays,
            commandReceipts: durableCommandReceipts
        )
    }

    /// 이 명령을 지금 적용해도 되는가. 두 번 눌린 버튼과 옛 화면에서 온 명령을 막는다.
    func acceptsCommand(_ operation: String) -> Bool {
        guard let revision = result?.snapshot.revision else { return true }
        return CommandReceiptRetention.accepts(
            CommandReceiptRetention.id(revision: revision, operation: operation),
            at: revision,
            seen: durableCommandReceipts ?? []
        )
    }

    /// 저장에 태울 영수증을 만든다. 실제 보관은 저장이 성공한 뒤다.
    func receipt(for operation: String, at revision: UInt64) -> String {
        CommandReceiptRetention.id(revision: revision, operation: operation)
    }

    /// 앨범 예산을 적용해 접는다. 담기지 않은 공은 조용히 버려진다 — 기존 재생은 지우지 않는다.
    func foldingStagedReplays(into state: ProCareerPersistedState) -> ProCareerPersistedState {
        guard !stagedReplays.isEmpty else { return state }
        var next = state
        var album = state.replays ?? []
        for replay in stagedReplays {
            album = AlbumReplayRules.appending(replay, to: album)
        }
        next.replays = album
        return next
    }

    var replays: [AlbumReplay] { durableReplays ?? [] }

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
        assign(&durableReplays, next.replays)
        assign(&durableCommandReceipts, next.commandReceipts)
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
    /// 방금 확정한 시즌 결정이 남긴 것. 화면에 결과를 **같은 자리에** 남기기 위한 값이라
    /// 저장에 들어가지 않는다. 플레이어가 "계속"을 누르면 사라진다.
    var lastSeasonDecisionReceipt: ProSeasonDecisionReceipt?

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
