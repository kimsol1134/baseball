import Foundation
import Observation
import SimulationCore

@MainActor
@Observable
final class MobileCareerStore {
    static let currentSaveSchemaVersion = 2
    static let unreadableSaveMessage = "저장 데이터는 남아 있지만 현재 버전에서 읽을 수 없습니다. 앱을 삭제하거나 새 커리어를 시작하지 말고 다시 불러오기를 눌러 주세요."

    enum ProCareerOrigin: String, Codable, Equatable {
        case highSchool = "high_school"
        case direct
    }

    enum LoadState: Equatable {
        case loading
        /// 저장된 커리어가 없다. 선수 유형을 고르는 화면으로 간다.
        case needsSetup
        case ready
        case failed(String)
    }

    /// 결과에 맞춘 햅틱/연출 신호. 화면은 이 값만 보고 반응한다.
    enum FeedbackCue: Equatable {
        case neutral
        case success
        case growth
        case setback
    }

    /// 능력이 오른 항목. 성장 연출이 이 목록을 그대로 보여 준다.
    struct AbilityGain: Identifiable, Equatable {
        var id: String { label }
        let label: String
        let before: Int
        let after: Int
    }

    var loadState: LoadState = .loading
    var result: ProCareerResult?
    var selectedPlan: ProWeekPlan = .earnTrust
    /// 변화구 성장 계획에서 실제로 완성할 결정구.
    var selectedDevelopmentPitch: PitchType = .slider
    var lastSummary: String?
    var feedbackTrigger = 0
    var feedbackCue: FeedbackCue = .neutral
    var pendingGains: [AbilityGain] = []
    /// 정규 고교 드래프트에서 이어진 프로라면 원래 고교 careerID를 저장한다.
    /// nil은 고교를 건너뛰었거나 이 필드가 없던 구저장본이다. `careerOrigin`이 둘을 가른다.
    private(set) var sourceHighSchoolCareerID: String?
    /// nil은 이 필드가 없던 구버전 저장뿐이다. 새 direct/highSchool 시작은 반드시 명시한다.
    private(set) var careerOrigin: ProCareerOrigin?
    /// 진행 중인 중요 경기. `importantGame` 단계에서만 존재한다.
    var pitchSession: PitchSession?

    @ObservationIgnored private let engine = ProCareerEngine()
    @ObservationIgnored private let sync: SaveSync
    @ObservationIgnored private let weekly: WeeklyProgramStore
    /// 테스트는 이 경계에서만 저장 실패를 주입한다. nil이면 실제 SaveSync를 쓴다.
    @ObservationIgnored private let saveWriter: ((Data) -> Bool)?

    var state: ProCareerSnapshot? { result?.snapshot }

    init(
        sync: SaveSync = SaveSync(key: "baseball-mobile-pro-v1.json"),
        weekly: WeeklyProgramStore = .shared,
        saveWriter: ((Data) -> Bool)? = nil
    ) {
        self.sync = sync
        self.weekly = weekly
        self.saveWriter = saveWriter
    }

    // MARK: - 수명 주기

    func restoreOrCreateCareer() {
        guard result == nil else { return }
        applyRestoreOutcome(restore())
    }

    /// 진행 중 오류라면 기존 상태로 돌아가고, 시작 복원 오류라면 원본을 보존한 채 다시 읽는다.
    func retryRestoreOrReturn() {
        if result != nil {
            loadState = .ready
            return
        }
        loadState = .loading
        applyRestoreOutcome(restore())
    }

    private func applyRestoreOutcome(_ outcome: RestoreOutcome) {
        switch outcome {
        case .live(let recoveredFromBackup):
            loadState = .ready
            if recoveredFromBackup {
                lastSummary = "현재 저장본을 읽지 못해 직전 정상 백업으로 복구했습니다."
                feedbackCue = .success
                feedbackTrigger += 1
            }
        case .needsSetup:
            loadState = .needsSetup
        case .unavailable:
            loadState = .failed(Self.unreadableSaveMessage)
        }
    }

    /// 유료앱에서는 앱 구매가 곧 이용 권한이므로 디버그/릴리스가 같은 경로를 탄다.
    @discardableResult
    func startNewCareer(preset: PitcherPresetSnapshot, playerName: String) -> Bool {
        let previousResult = result
        let previousSource = sourceHighSchoolCareerID
        let previousOrigin = careerOrigin
        let previousSummary = lastSummary
        let previousFeedbackCue = feedbackCue
        let previousFeedbackTrigger = feedbackTrigger
        let previousLoadState = loadState
        do {
            let seed = UInt64.random(in: 1...UInt64.max)
            let created = try CareerBootstrap.startCareer(preset: preset, playerName: playerName, seed: seed)
            result = created
            sourceHighSchoolCareerID = nil
            careerOrigin = .direct
            lastSummary = "\(created.snapshot.team.name) 입단. 2군에서 첫 시즌을 시작합니다."
            feedbackCue = .success
            feedbackTrigger += 1
            loadState = .ready
            guard save() else {
                result = previousResult
                sourceHighSchoolCareerID = previousSource
                careerOrigin = previousOrigin
                lastSummary = previousSummary
                feedbackCue = previousFeedbackCue
                feedbackTrigger = previousFeedbackTrigger
                loadState = .failed("프로 커리어 시작을 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.")
                return false
            }
            return true
        } catch {
            result = previousResult
            sourceHighSchoolCareerID = previousSource
            careerOrigin = previousOrigin
            lastSummary = previousSummary
            feedbackCue = previousFeedbackCue
            feedbackTrigger = previousFeedbackTrigger
            loadState = .failed(error.localizedDescription)
            if previousResult != nil { loadState = previousLoadState }
            return false
        }
    }

    /// 고교 커리어의 지명 결과로 프로를 연다. 정규 경로다.
    @discardableResult
    func startProCareer(
        draft: DraftResultSnapshot,
        pitcher: PitcherSnapshot,
        identity: PlayerIdentitySnapshot,
        sourceHighSchoolCareerID: String
    ) -> Bool {
        let previousResult = result
        let previousSource = self.sourceHighSchoolCareerID
        let previousOrigin = careerOrigin
        let previousSummary = lastSummary
        let previousFeedbackCue = feedbackCue
        let previousFeedbackTrigger = feedbackTrigger
        let previousLoadState = loadState
        do {
            let created = try CareerBootstrap.startCareer(
                draft: draft,
                pitcher: pitcher,
                identity: identity,
                seed: UInt64.random(in: 1...UInt64.max)
            )
            result = created
            self.sourceHighSchoolCareerID = sourceHighSchoolCareerID
            careerOrigin = .highSchool
            lastSummary = "\(created.snapshot.team.name) 입단. 고교 3년의 능력을 그대로 안고 시작합니다."
            feedbackCue = .success
            feedbackTrigger += 1
            loadState = .ready
            guard save() else {
                result = previousResult
                self.sourceHighSchoolCareerID = previousSource
                careerOrigin = previousOrigin
                lastSummary = previousSummary
                feedbackCue = previousFeedbackCue
                feedbackTrigger = previousFeedbackTrigger
                loadState = .failed("프로 진입을 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.")
                return false
            }
            return true
        } catch {
            result = previousResult
            self.sourceHighSchoolCareerID = previousSource
            careerOrigin = previousOrigin
            lastSummary = previousSummary
            feedbackCue = previousFeedbackCue
            feedbackTrigger = previousFeedbackTrigger
            loadState = .failed(error.localizedDescription)
            if previousResult != nil { loadState = previousLoadState }
            return false
        }
    }

    @discardableResult
    func deleteCareer() -> Bool {
        // clear() 대신 묘비 — 고교 쪽과 같은 이유(iCloud 부활 방지).
        let tombstone = Self.nextSyncRevision(
            after: syncedRevision,
            atLeast: result?.snapshot.revision ?? 0
        )
        guard let data = try? JSONEncoder().encode(
            ProSaveRecord(
                result: nil,
                deletedRevision: tombstone,
                schemaVersion: Self.currentSaveSchemaVersion,
                syncRevision: tombstone
            )
        ), sync.write(data) else {
            // 은퇴 저장은 이미 고교 쪽 유산에 접혔지만 tombstone만 실패한 상태다. `.failed`로
            // 바꾸면 AppShell이 고교 탭을 다시 열어 사용자가 다음 선수까지 진행할 수 있고,
            // 남은 프로 저장은 이후 현재 고교와 연결할 길을 잃는다. 완료 화면을 그대로
            // 유지해 같은 CTA가 삭제만 재시도하게 한다.
            let message = "프로 기록 정리를 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 눌러 주세요."
            lastSummary = message
            feedbackCue = .setback
            feedbackTrigger += 1
            // 유효한 프로 스냅숏이 있을 때만 완료 화면을 유지할 수 있다. 커리어 시작 저장도
            // 실패해 result가 nil인 상태를 `.ready`로 만들면 프로/고교 양쪽이 가려진다.
            loadState = result == nil ? .failed(message) : .ready
            return false
        }
        sync.discardRecoveryCopies()
        syncedRevision = tombstone
        result = nil
        sourceHighSchoolCareerID = nil
        careerOrigin = nil
        pitchSession = nil
        gameResume = nil
        pendingGains = []
        lastSummary = nil
        loadState = .needsSetup
        return true
    }

    // MARK: - 주간 진행

    func advanceWeek() {
        guard let result else { return }
        let beforeRevision = result.snapshot.revision
        perform { try engine.planWeek(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            plan: selectedPlan,
            targetPitch: developmentTarget
        )) }
        if self.result?.snapshot.revision != beforeRevision {
            weekly.record(.proWeeksAdvanced)
        }
    }

    /// 다음 구간 어귀까지 자동으로 진행한다.
    ///
    /// 24주를 한 주씩 넘기는 것이 프로 후반의 실제 경험이었다. 같은 카드 다섯 장에서 하나를
    /// 고르는 일이 시즌마다 24번, 20시즌이면 480번이다. 구간(스프링캠프·개막·전반기·올스타
    /// 브레이크·페넌트레이스·시즌 막바지)은 이미 코어가 알고 있으니, **결정이 필요한 자리에서만
    /// 멈추게** 한다 — 구간이 바뀌거나, 중요 경기가 잡히거나, 역할·소속이 움직이거나, 다치거나.
    func advanceSegment() {
        guard let result else { return }
        let beforeRevision = result.snapshot.revision
        var advancedWeeks = 0
        perform {
            var current = result
            let startSegment = current.snapshot.seasonSegment
            for _ in 0..<24 where current.snapshot.phase == .weeklyPlan {
                let before = current.snapshot
                current = try engine.planWeek(
                    .init(seed: current.nextSeed, state: current.snapshot, plan: selectedPlan, targetPitch: developmentTarget)
                )
                advancedWeeks += 1
                let after = current.snapshot
                // 여기서 멈춘다: 화면이 약속한 것들이다.
                if after.seasonSegment != startSegment { break }
                if after.role != before.role || after.level != before.level { break }
                if after.injuryWeeks > before.injuryWeeks { break }
            }
            return current
        }
        if self.result?.snapshot.revision != beforeRevision {
            weekly.record(.proWeeksAdvanced, amount: advancedWeeks)
        }
    }

    func advanceBlock() {
        guard let result else { return }
        let beforeRevision = result.snapshot.revision
        var advancedWeeks = 0
        perform {
            var current = result
            for _ in 0..<3 where current.snapshot.phase == .weeklyPlan {
                let before = current.snapshot
                current = try engine.planWeek(.init(seed: current.nextSeed, state: current.snapshot, plan: selectedPlan, targetPitch: developmentTarget))
                advancedWeeks += 1
                // 화면이 "선발·불펜 역할 변화가 생기면 멈춥니다"라고 약속한다. 역할·소속이
                // 바뀌었는데 남은 주를 그대로 흘려보내면 그 약속이 거짓이 된다.
                if current.snapshot.role != before.role || current.snapshot.level != before.level { break }
            }
            return current
        }
        if self.result?.snapshot.revision != beforeRevision {
            weekly.record(.proWeeksAdvanced, amount: advancedWeeks)
        }
    }

    private var developmentTarget: PitchType? {
        selectedPlan == .developMovement || selectedPlan == .developWeapon
            ? selectedDevelopmentPitch
            : nil
    }

    // MARK: - 중요 경기

    /// 실제 투구 세션을 연다. 이전 구현처럼 미리 정해진 성적을 돌려주지 않는다.
    func beginImportantGame() {
        guard let result, result.snapshot.phase == .importantGame else { return }
        guard pitchSession == nil else { return }
        // **등판을 시작하는 순간 시드를 넘기고 저장한다.**
        //
        // 예전에는 여기서 저장하지 않았다. 그래서 결과를 반영하기 전에 앱을 강제 종료하면
        // 저장본에 같은 시드가 그대로 남아, **같은 이닝을 똑같은 난수로 다시 던질 수 있었다.**
        // 한 번 겪어 타자의 노림수와 결과를 알아낸 뒤 되돌리는 것이라, 이 게임이 파는
        // "한 번뿐인 승부"가 성립하지 않는다.
        //
        // 시드를 넘기면 다시 시도해도 다른 이닝이 된다. 배운 정보가 남지 않는다.
        let sessionSeed = Self.advanced(result.nextSeed)
        let checkpointed = ProCareerResult(
            snapshot: result.snapshot,
            nextSeed: sessionSeed,
            events: result.events
        )
        // 저장이 끝나기 전에는 시드나 화면을 바꾸지 않는다. 실패 뒤 같은 버튼을 누르면
        // 아직 소비되지 않은 원래 시드로 정확히 한 번 다시 시도할 수 있다.
        guard persist(result: checkpointed, gameResume: nil) else { return }
        self.result = checkpointed
        gameResume = nil
        let session = PitchSession(state: result.snapshot, seed: sessionSeed)
        session.start()
        attachCheckpoint(session)
        pitchSession = session
    }

    /// 시드를 한 칸 굴린다. 코어와 같은 SplitMix64를 쓴다.
    nonisolated static func advanced(_ seed: String) -> String {
        var generator = SplitMix64(seed: UInt64(seed) ?? 0x9E37_79B9_7F4A_7C15)
        return String(max(1, generator.next() >> 1))
    }

    /// 세션에서 실제로 누적된 리포트를 프로 커리어에 반영한다.
    func finishImportantGame() {
        guard let result, let session = pitchSession else { return }
        let report = session.report(scenarioNumber: result.snapshot.week)
        let sequenceMasteryCount = session.sequenceMasteryCount
        let beforeRevision = result.snapshot.revision
        let summary = Self.importantGameSummary(report)
        let didSettle = perform(
            summary: summary,
            cue: report.runsAllowed == 0 ? .success : .setback,
            clearGameResumeOnSuccess: true
        ) {
            try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report))
        }
        guard didSettle else { return }
        // 코어 결과와 resume 제거가 한 레코드로 저장된 뒤에만 세션을 화면에서 내린다.
        pitchSession = nil
        guard self.result?.snapshot.revision != beforeRevision else { return }
        AchievementStore.shared.record(AchievementRules.fromInning(report: report) + session.bestDeliveryAchievements)
        weekly.record(.sequenceMasteryTriggered, amount: sequenceMasteryCount)
        weekly.record(.playedOnTwoDays, receiptID: "played-day:\(DailyStreak.key(for: Date()))")
        let gameFinishedProperties = session.gameFinishedAnalyticsMetrics.merging([
            "mode": "pro",
            "result": report.runsAllowed == 0 ? "scoreless" : "runs_allowed",
            "strikeouts": report.strikeouts,
            "walks": report.walks,
            "runs": report.runsAllowed,
        ]) { _, modeSpecific in modeSpecific }
        GameAnalytics.log(.gameFinished, gameFinishedProperties)
        GameAnalytics.recordCompletedGame()
        // 연속 일수는 모드를 가리지 않는다 — 프로 등판도 오늘 던진 것이다.
        DailyStreak.recordPlay()
    }

    nonisolated static func importantGameSummary(_ report: ImportantInningReport) -> String {
        "\(report.pitches)구 · \(report.strikeouts)탈삼진 · \(report.walks)볼넷 · \(report.runsAllowed)실점"
    }

    nonisolated static func retirementDurationText(_ state: ProCareerSnapshot) -> String {
        retirementDurationText(completedSeasons: state.careerStats.count)
    }

    nonisolated static func retirementDurationText(completedSeasons: Int) -> String {
        return completedSeasons > 0 ? "\(completedSeasons)시즌" : "프로 첫 시즌"
    }

    @discardableResult
    func abandonImportantGame() -> Bool {
        guard let result, pitchSession != nil else { return false }
        // 완료 정산과 같은 원칙이다. resume 제거가 디스크에 내려가기 전에 화면 세션을
        // 지우면 저장 실패 뒤에도 사용자가 던진 이닝을 다시 열 수 없다.
        guard persist(result: result, gameResume: nil) else { return false }
        pitchSession = nil
        gameResume = nil
        lastSummary = "등판을 중단했습니다. 다음 마운드는 새 이닝입니다."
        feedbackCue = .setback
        feedbackTrigger += 1
        return true
    }

    // MARK: - 시즌

    /// 세 주 단위 선택은 확인 화면이 본 결정 ID와 선택지 ID를 함께 적용한다. 코어가
    /// stale 입력을 거부하고 RNG를 소비하지 않으며, 성공한 경우에만 선택 이벤트를 남긴다.
    func applySeasonDecision(decisionID: String, choiceID: String) {
        guard let result,
              let decision = result.snapshot.pendingDecision,
              decision.id == decisionID,
              let choice = decision.choices.first(where: { $0.id == choiceID }) else { return }
        let beforeRevision = result.snapshot.revision
        perform(
            summary: "\(decision.title) · \(choice.title) — \(choice.effect.summary)",
            cue: .success
        ) {
            try engine.applySeasonDecision(.init(
                seed: result.nextSeed,
                state: result.snapshot,
                decisionID: decision.id,
                choiceID: choice.id
            ))
        }
        guard self.result?.snapshot.revision != beforeRevision,
              self.result?.snapshot.decisionHistory?.last?.decisionID == decision.id else { return }
        GameAnalytics.log(.proSeasonDecisionSelected, Self.decisionAnalyticsProperties(
            decision: decision,
            choice: choice
        ))
    }

    static func decisionAnalyticsProperties(
        decision: ProSeasonDecision,
        choice: ProSeasonDecisionChoice
    ) -> [String: Any] {
        [
            "decision_id": decision.id,
            "choice_id": choice.id,
            "season": decision.season,
            "week": decision.week,
        ]
    }

    func reviewSeason() {
        guard let result else { return }
        perform(summary: "시즌 기록을 통산 기록에 확정했습니다.", cue: .success) {
            try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
        }
    }

    func continueCareer() { chooseOffseason(.continueCareer) }

    /// 오프시즌 네 갈래. 코어는 네 가지를 전부 받는데 화면이 잔류 하나만 냈다.
    ///
    /// 그래서 군 복무와 FA 서사가 게임에 존재하지 않았고, 커리어 상한에 도달해
    /// `retirementDecision`으로 넘어가면 화면이 아예 없어 **커리어가 그 자리에서 막혔다.**
    func chooseOffseason(_ decision: OffseasonDecision) {
        guard let result else { return }
        let summary: String
        switch decision {
        case .continueCareer: summary = "현재 구단에서 다음 시즌을 준비합니다."
        case .militaryService: summary = "두 시즌의 군 복무를 마치고 돌아옵니다."
        case .freeAgency: summary = "FA를 신청했습니다."
        case .retire: summary = "은퇴를 선택했습니다."
        }
        perform(summary: summary, cue: decision == .retire ? .neutral : .success) {
            try engine.chooseOffseason(.init(seed: result.nextSeed, state: result.snapshot, decision: decision))
        }
    }

    /// FA 신청 자격. 코어와 같은 식(1군 등록 6년)을 쓴다 — 화면이 못 누를 버튼을 내면
    /// 사용자는 오류 메시지로 규칙을 배우게 된다.
    static func freeAgencyService(_ state: ProCareerSnapshot) -> Int {
        state.serviceYears + (state.level == .major ? 1 : 0)
    }

    func acknowledgeGains() {
        pendingGains = []
    }

    /// 진행 중 등판의 타석 경계 스냅샷. 고교와 같은 문법 — 프로 20시즌의
    /// 몰입 최고점에서 전화 한 통에 이닝을 잃으면 안 된다.
    private var gameResume: PitchSession.ResumeState?

    /// 저장 래퍼. 예전에는 ProCareerResult를 그대로 썼다 — 복구 스냅샷을 실으려고
    /// 감쌌고, 읽을 때는 레거시(맨 result)도 그대로 받는다.
    struct ProSaveRecord: Codable {
        /// nil이면 삭제 묘비다. 예전엔 필수였지만 옛 레코드는 항상 값이 있어 호환된다.
        let result: ProCareerResult?
        var gameResume: PitchSession.ResumeState? = nil
        /// 묘비의 리비전. iCloud의 옛 사본을 이기기 위해 존재한다.
        var deletedRevision: UInt64? = nil
        /// 직접 프로는 이 값이 nil이고 origin이 `.direct`다. 둘 다 nil이면 필드 도입 전 저장이다.
        var sourceHighSchoolCareerID: String? = nil
        /// nil은 필드 도입 전 저장이다. 새 직접 시작은 `.direct`를 명시해 legacy nil과 구분한다.
        var origin: ProCareerOrigin? = nil
        /// nil은 래퍼 도입기 저장이다. 더 높은 버전은 원본을 보존하고 업데이트를 기다린다.
        var schemaVersion: Int? = nil
        /// 커리어가 바뀌어 스냅숏 리비전이 0부터 다시 시작해도 iCloud에서는 계속 증가한다.
        var syncRevision: UInt64? = nil

        var effectiveRevision: UInt64 {
            max(syncRevision ?? 0, max(deletedRevision ?? 0, result?.snapshot.revision ?? 0))
        }
    }

    /// 마지막으로 알게 된 저장 리비전 — 묘비가 이 값보다 커야 부활을 막는다.
    private var syncedRevision: UInt64 = 0

    // MARK: - 저장

    @discardableResult
    func save() -> Bool {
        guard let result else { return false }
        return persist(result: result, gameResume: gameResume)
    }

    /// 후보 상태 전체를 하나의 저장 레코드로 먼저 내린다. 관찰 상태는 호출자가 성공 뒤에만
    /// 교체하므로 write 실패가 result/seed/resume/UI에 부분적으로 보이지 않는다.
    private func persist(
        result: ProCareerResult,
        gameResume: PitchSession.ResumeState?
    ) -> Bool {
        let candidateRevision = Self.nextSyncRevision(
            after: syncedRevision,
            atLeast: result.snapshot.revision
        )
        let record = ProSaveRecord(
            result: result,
            gameResume: gameResume,
            sourceHighSchoolCareerID: sourceHighSchoolCareerID,
            origin: careerOrigin,
            schemaVersion: Self.currentSaveSchemaVersion,
            syncRevision: candidateRevision
        )
        guard let data = try? JSONEncoder().encode(record) else { return false }
        let didWrite = saveWriter?(data) ?? sync.write(data)
        guard didWrite else { return false }
        syncedRevision = candidateRevision
        return true
    }

    /// 다른 기기에서 진행이 올라왔을 때 다시 읽는다.
    func reloadFromSync() {
        // 승부 중에는 상태를 갈아끼우지 않는다. 진행 중인 이닝이 사라지면 더 나쁘다.
        if pitchSession != nil {
            _ = applyHigherTombstoneDuringSession()
            return
        }
        let currentRevision = syncedRevision
        let outcome = restore()
        switch outcome {
        case .live(let recoveredFromBackup):
            guard syncedRevision > currentRevision || recoveredFromBackup else { return }
            loadState = .ready
            lastSummary = recoveredFromBackup
                ? "iCloud 저장을 읽지 못해 직전 정상 백업으로 복구했습니다."
                : "다른 기기의 진행을 불러왔습니다."
            feedbackTrigger += 1
        case .needsSetup:
            // A higher remote tombstone is authoritative. Keeping the old in-memory result here
            // lets the next background save resurrect a career another device deleted.
            loadState = .needsSetup
            lastSummary = nil
        case .unavailable:
            if result == nil {
                loadState = .failed(Self.unreadableSaveMessage)
            } else {
                lastSummary = "iCloud 저장을 읽지 못해 이 기기의 진행을 유지합니다."
                feedbackCue = .setback
                feedbackTrigger += 1
            }
        }
    }

    /// 진행 중 이닝보다 다른 기기의 더 높은 삭제 묘비가 우선한다. live 진행은 이닝이
    /// 끝날 때까지 보존하지만, 묘비를 무시하면 로컬 결과 저장이 삭제된 커리어를 부활시킨다.
    @discardableResult
    private func applyHigherTombstoneDuringSession() -> Bool {
        guard let data = sync.read(
            revision: Self.saveRevision,
            conflictPriority: Self.saveConflictPriority
        ),
        let record = Self.decodeSaveRecord(data),
        record.result == nil,
        let tombstone = record.deletedRevision ?? record.syncRevision,
        tombstone >= syncedRevision else { return false }

        syncedRevision = tombstone
        result = nil
        sourceHighSchoolCareerID = nil
        careerOrigin = nil
        pitchSession = nil
        gameResume = nil
        pendingGains = []
        lastSummary = nil
        loadState = .needsSetup
        return true
    }

    private enum RestoreOutcome: Equatable {
        case live(recoveredFromBackup: Bool)
        case needsSetup
        case unavailable
    }

    private static func nextSyncRevision(after current: UInt64, atLeast minimum: UInt64) -> UInt64 {
        let incremented = current == UInt64.max ? UInt64.max : current + 1
        return max(incremented, minimum)
    }

    private static func decodeSaveRecord(_ data: Data) -> ProSaveRecord? {
        let decoder = JSONDecoder()
        if let record = try? decoder.decode(ProSaveRecord.self, from: data) {
            let version = record.schemaVersion ?? 1
            if (1...currentSaveSchemaVersion).contains(version),
               record.result != nil || record.deletedRevision != nil {
                return record
            }
        }
        guard let legacy = try? decoder.decode(ProCareerResult.self, from: data) else { return nil }
        return ProSaveRecord(
            result: legacy,
            schemaVersion: 1,
            syncRevision: legacy.snapshot.revision
        )
    }

    private static func saveRevision(_ data: Data) -> UInt64? {
        decodeSaveRecord(data)?.effectiveRevision
    }

    /// ProSaveRecord의 명시적 삭제 묘비만 live보다 높은 동률 우선순위를 갖는다.
    /// wrapper 도입 전 raw ProCareerResult는 기존 live 저장으로 그대로 취급한다.
    private static func saveConflictPriority(_ data: Data) -> Int {
        guard let record = decodeSaveRecord(data),
              record.result == nil,
              record.deletedRevision != nil || record.syncRevision != nil else { return 0 }
        return 1
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
        if record.result == nil,
           let tombstone = record.deletedRevision ?? record.syncRevision {
            // 삭제 묘비 — 옛 사본이 아니라 삭제가 최신이다.
            syncedRevision = tombstone
            result = nil
            sourceHighSchoolCareerID = nil
            careerOrigin = nil
            pitchSession = nil
            gameResume = nil
            pendingGains = []
            return .needsSetup
        }
        let decoded = record.result
        guard let decoded else { return .unavailable }
        syncedRevision = max(syncedRevision, record.effectiveRevision)
        // 유료앱에서는 앱 자체가 구매 증거다. 저장된 스냅숏의 권한 출처(개발 빌드 포함)를 이유로
        // 진행을 버리면 TestFlight 사용자의 커리어만 사라진다.
        result = decoded
        sourceHighSchoolCareerID = record.sourceHighSchoolCareerID
        careerOrigin = record.origin
        pitchSession = nil
        gameResume = nil
        pendingGains = []
        // 등판 도중 내려간 앱 — 타석 경계에서 이어 던진다(고교와 같은 검사).
        if decoded.snapshot.phase == .importantGame,
           let resume = record.gameResume,
           PitchScenario.pro(state: decoded.snapshot).id == resume.scenarioID {
            let session = PitchSession(state: decoded.snapshot, seed: resume.seed)
            session.start()
            session.restore(from: resume)
            attachCheckpoint(session)
            gameResume = resume
            pitchSession = session
        }
        return .live(recoveredFromBackup: recovered)
    }

    private func attachCheckpoint(_ session: PitchSession) {
        session.onCheckpoint = { [weak self] session in
            guard let self, let result = self.result else { return }
            let resume = session.resumeState()
            guard self.persist(result: result, gameResume: resume) else { return }
            self.gameResume = resume
        }
    }

    @discardableResult
    private func perform(
        summary: String? = nil,
        cue: FeedbackCue? = nil,
        clearGameResumeOnSuccess: Bool = false,
        _ action: () throws -> ProCareerResult
    ) -> Bool {
        do {
            let before = result?.snapshot
            let updated = try action()
            let gains = Self.gains(before: before?.pitcher, after: updated.snapshot.pitcher)
            let nextSummary = summary ?? progressSummary(before: before, after: updated.snapshot)
            let nextCue = cue ?? (gains.isEmpty ? .neutral : .growth)
            let nextResume = clearGameResumeOnSuccess ? nil : gameResume
            guard persist(result: updated, gameResume: nextResume) else { return false }

            // 디스크가 후보 상태를 받아들인 뒤에만 관찰 상태와 외부 부수효과를 커밋한다.
            result = updated
            gameResume = nextResume
            pendingGains = gains
            lastSummary = nextSummary
            feedbackCue = nextCue
            feedbackTrigger += 1
            loadState = .ready
            AchievementStore.shared.record(AchievementRules.fromPro(updated.snapshot))
            AchievementStore.shared.submit(LeaderboardRules.scores(for: updated.snapshot))
            return true
        } catch {
            loadState = .failed(error.localizedDescription)
            return false
        }
    }

    nonisolated static func gains(before: PitcherSnapshot?, after: PitcherSnapshot) -> [AbilityGain] {
        guard let before else { return [] }
        let pairs = [
            ("구위", before.stuff, after.stuff),
            ("제구", before.command, after.command),
            ("변화구", before.movement, after.movement),
            ("체력", before.stamina, after.stamina)
        ]
        return pairs.compactMap { label, from, to in
            to > from ? AbilityGain(label: label, before: from, after: to) : nil
        }
    }

    private func progressSummary(before: ProCareerSnapshot?, after: ProCareerSnapshot) -> String {
        guard let before else { return "다음 일정이 준비됐습니다." }
        if before.level != after.level { return "1군 출전 명단에 합류했습니다. 다음 주목받는 등판이 바로 이어집니다." }
        if before.role != after.role { return "감독 면담 뒤 역할이 \(Self.roleName(after.role))으로 바뀌었습니다." }
        if after.milestones.count > before.milestones.count { return "새 주요 기록 · \(after.milestones.last ?? "선수 기록")" }
        let fatigue = after.fatigue - before.fatigue
        let trust = after.managerTrust - before.managerTrust
        return "\(before.week + 1)주차 완료 · 감독의 믿음 \(trust >= 0 ? "+" : "")\(trust) · 피로 \(fatigue >= 0 ? "+" : "")\(fatigue)"
    }

    nonisolated static func roleName(_ role: ProRole) -> String {
        switch role {
        case .starter: "선발"
        case .longRelief: "긴 이닝 구원"
        case .setup: "필승조"
        case .closer: "마무리"
        }
    }

}
