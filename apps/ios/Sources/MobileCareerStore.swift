import Foundation
import Observation
import SimulationCore

@MainActor
@Observable
final class MobileCareerStore {
    /// Schema 2 is the last journey-nil format that production builds may continue to write.
    /// Schema 3 is the first format that is allowed to carry the Wave 1 journey aggregate or a
    /// journey-generation tombstone. Keeping the two write versions explicit prevents a legacy
    /// path from silently downgrading a journey save.
    static let legacySaveSchemaVersion = 2
    static let journeySaveSchemaVersion = 3
    static let currentSaveSchemaVersion = journeySaveSchemaVersion
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
        var id: String { ability.rawValue }
        /// Stable semantic identity. `label` remains as a Korean compatibility view for existing
        /// Korean-only surfaces; localized UI must resolve `ability.displayCopyToken` instead.
        let ability: TalentAbility
        let before: Int
        let after: Int

        init(ability: TalentAbility, before: Int, after: Int) {
            self.ability = ability
            self.before = before
            self.after = after
        }

        /// Source compatibility for the existing Korean-only test/helpers. New UI code must
        /// construct gains from the closed enum identity above, never from rendered text.
        init(label: String, before: Int, after: Int) {
            self.ability = switch label {
            case "구위": .stuff
            case "제구": .command
            case "변화구": .movement
            case "체력": .stamina
            default: .command
            }
            self.before = before
            self.after = after
        }

        var label: String { ability.label }
    }

    var loadState: LoadState = .loading
    var result: ProCareerResult?
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
    private(set) var sourceHighSchoolCareerID: String?
    /// nil은 이 필드가 없던 구버전 저장뿐이다. 새 direct/highSchool 시작은 반드시 명시한다.
    private(set) var careerOrigin: ProCareerOrigin?
    /// 진행 중인 중요 경기. `importantGame` 단계에서만 존재한다.
    var pitchSession: PitchSession?

    @ObservationIgnored private let engine: ProCareerEngine
    @ObservationIgnored private let featureConfiguration: AppFeatureConfiguration
    @ObservationIgnored private let sync: SaveSync
    @ObservationIgnored private let weekly: WeeklyProgramStore
    /// 테스트는 이 경계에서만 저장 실패를 주입한다. nil이면 실제 SaveSync를 쓴다.
    @ObservationIgnored private let saveWriter: ((Data) -> Bool)?

    var state: ProCareerSnapshot? { result?.snapshot }

    private var isBlockedByUnreadableSave: Bool {
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
        guard !isBlockedByUnreadableSave else { return false }
        let previousResult = result
        let previousSource = sourceHighSchoolCareerID
        let previousOrigin = careerOrigin
        let previousSummary = lastSummary
        let previousFeedbackCue = feedbackCue
        let previousFeedbackTrigger = feedbackTrigger
        let previousLoadState = loadState
        do {
            let seed = UInt64.random(in: 1...UInt64.max)
            let created = try CareerBootstrap.startCareer(
                preset: preset,
                playerName: playerName,
                seed: seed,
                engine: engine
            )
            result = created
            sourceHighSchoolCareerID = nil
            careerOrigin = .direct
            lastSummary = created.snapshot.phase == .contractOffer
                ? "\(created.snapshot.team.name) 지명. 신인 계약 제안을 확인해 주세요."
                : "\(created.snapshot.team.name) 입단. 2군에서 첫 시즌을 시작합니다."
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
        sourceHighSchoolCareerID: String,
        sourceFanInterest: Int? = nil
    ) -> Bool {
        guard !isBlockedByUnreadableSave else { return false }
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
                seed: UInt64.random(in: 1...UInt64.max),
                sourceFanInterest: sourceFanInterest,
                engine: engine
            )
            result = created
            self.sourceHighSchoolCareerID = sourceHighSchoolCareerID
            careerOrigin = .highSchool
            lastSummary = created.snapshot.phase == .contractOffer
                ? "\(created.snapshot.team.name) 지명. 신인 계약 제안을 확인해 주세요."
                : "\(created.snapshot.team.name) 입단. 고교 3년의 능력을 그대로 안고 시작합니다."
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
        // 삭제 API의 성공은 "무언가를 실제로 지웠는가"가 아니라 "호출 뒤 진행이 없는가"다.
        // 복원이 끝나 빈 저장소임이 확정된 경우는 성공한 no-op으로 돌려, 전체 초기화 같은
        // 호출자가 `false`를 저장 오류로 오인해 화면 복귀를 건너뛰지 않게 한다.
        // loading/failed의 nil은 미확인·손상 저장일 수 있으므로 여전히 실패다.
        guard let deletedResult = result else { return loadState == .needsSetup }
        // The tombstone must stay in the same generation as the career it deletes. A legacy
        // production build may replace a schema-2 tombstone with its next legacy career, while a
        // schema-2 writer must never replace a schema-3 journey tombstone. Capture this before the
        // in-memory result is cleared below.
        let tombstoneSchemaVersion = Self.schemaVersion(for: deletedResult)
        let tombstone = Self.nextSyncRevision(
            after: syncedRevision,
            atLeast: deletedResult.snapshot.revision
        )
        guard canWrite(schemaVersion: tombstoneSchemaVersion),
              let data = try? JSONEncoder().encode(
            ProSaveRecord(
                result: nil,
                deletedRevision: tombstone,
                schemaVersion: tombstoneSchemaVersion,
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
        guard let result, let selectedPlan else { return }
        let beforeRevision = result.snapshot.revision
        perform { try engine.planWeek(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            plan: selectedPlan,
            targetPitch: developmentTarget
        )) }
        if self.result?.snapshot.revision != beforeRevision {
            weekly.record(.proWeeksAdvanced)
            // 회복은 한 주짜리 명령이다. 성공한 저장 이후에만 선택을 비워 다음 주의
            // 무음 미등판을 막는다. 저장 실패면 기존 선택도 그대로 남아 재시도할 수 있다.
            if selectedPlan == .recover { self.selectedPlan = nil }
        }
    }

    /// 다음 구간 어귀까지 자동으로 진행한다.
    ///
    /// 24주를 한 주씩 넘기는 것이 프로 후반의 실제 경험이었다. 같은 카드 다섯 장에서 하나를
    /// 고르는 일이 시즌마다 24번, 20시즌이면 480번이다. 구간(스프링캠프·개막·전반기·올스타
    /// 브레이크·페넌트레이스·시즌 막바지)은 이미 코어가 알고 있으니, **결정이 필요한 자리에서만
    /// 멈추게** 한다 — 구간이 바뀌거나, 중요 경기가 잡히거나, 역할·소속이 움직이거나, 다치거나.
    func advanceSegment() {
        guard let result, let selectedPlan,
              selectedPlan != .recover || (result.snapshot.proRulesVersion ?? 1) >= ProCareerEngine.currentRulesVersion else { return }
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
        guard let result, let selectedPlan,
              selectedPlan != .recover || (result.snapshot.proRulesVersion ?? 1) >= ProCareerEngine.currentRulesVersion else { return }
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
        let fanBefore = result.snapshot.journeyState?.reputation.fanSupport ?? 0
        perform(
            summary: decision.type == .mediaOpportunity ? nil : "\(decision.title) · \(choice.title) — \(choice.effect.summary)",
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
        if decision.type == .mediaOpportunity {
            GameAnalytics.log(.proEndorsementSelected, Self.endorsementAnalyticsProperties(
                decision: decision,
                choice: choice,
                fanBefore: fanBefore
            ))
        }
    }

    /// 시즌 결정 국면인데 pending 결정이 없는 손상 저장을 사용자가 직접 푼다.
    ///
    /// 이 상태는 엔진의 모든 호출이 거부되는 함정이라, 화면의 복구 버튼이 유일한 출구다.
    /// 성공하면 주간 계획(마지막 주면 시즌 리뷰)으로 되돌아간다.
    @discardableResult
    func recoverStalledSeasonDecision() -> Bool {
        guard let result,
              result.snapshot.phase == .seasonDecision,
              result.snapshot.pendingDecision == nil else { return false }
        let recovered = perform(summary: "시즌 결정을 불러오지 못해 주간 일정으로 되돌렸습니다.", cue: .neutral) {
            try engine.recoverMissingSeasonDecision(.init(seed: result.nextSeed, state: result.snapshot))
        }
        if recovered {
            GameAnalytics.log(.screenStallRecovered, ["context": "pro_season_decision_missing"])
        }
        return recovered
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

    static func endorsementAnalyticsProperties(
        decision: ProSeasonDecision,
        choice: ProSeasonDecisionChoice,
        fanBefore: Int
    ) -> [String: Any] {
        let category = String(choice.id.split(separator: ".").last ?? "unknown")
        let income = choice.journeyEffect?.income ?? 0
        return [
            "season": decision.season,
            "choice": category,
            "fan_band": fanBand(fanBefore),
            "income_band": incomeBand(income),
        ]
    }

    static func fanBand(_ value: Int) -> String {
        switch value {
        case 0..<35: "0_34"
        case 35..<60: "35_59"
        case 60..<80: "60_79"
        default: "80_100"
        }
    }

    static func incomeBand(_ value: Int64) -> String {
        switch value {
        case 0: "none"
        case 1..<10_000_000: "under_10m"
        case 10_000_000..<30_000_000: "10m_29m"
        default: "30m_plus"
        }
    }

    static func fundsBand(_ value: Int64) -> String {
        switch value {
        case 0..<20_000_000: "0_19m"
        case 20_000_000..<40_000_000: "20m_39m"
        case 40_000_000..<50_000_000: "40m_49m"
        default: "50m_plus"
        }
    }

    func reviewSeason() {
        guard let result else { return }
        guard featureConfiguration.proCareerJourneyV1 || result.snapshot.journeyState == nil else { return }
        perform(summary: "시즌 기록을 통산 기록에 확정했습니다.", cue: .success) {
            try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
        }
    }

    func acknowledgeSettlement() {
        guard featureConfiguration.proCareerJourneyV1,
              let result,
              let settlement = result.snapshot.journeyState?.lastSettlement else { return }
        perform(summary: nil, cue: .success) {
            try engine.acknowledgeSettlement(.init(
                seed: result.nextSeed,
                state: result.snapshot,
                expectedRevision: result.snapshot.revision,
                settlementID: settlement.id
            ))
        }
    }

    /// Seedless, revision-bound rookie signing. The candidate result is persisted by `perform`
    /// before this store publishes the new contract, finance, goal, or achievement state.
    @discardableResult
    func acceptContract(ambition: ProCareerAmbition?) -> Bool {
        guard let market = result?.snapshot.journeyState?.pendingContractMarket,
              market.kind == .rookie,
              let offer = market.offers.first else { return false }
        return acceptContract(
            marketID: market.id,
            offerID: offer.id,
            ambition: ambition
        )
    }

    @discardableResult
    func acceptContract(
        marketID: String,
        offerID: String,
        ambition: ProCareerAmbition?
    ) -> Bool {
        guard featureConfiguration.proCareerJourneyV1, let current = result else { return false }
        let market = current.snapshot.journeyState?.pendingContractMarket
        let offer = market?.offers.first(where: { $0.id == offerID })
        let accepted = perform(summary: "계약을 확정했습니다.", cue: .success) {
            try engine.acceptContract(.init(
                seed: current.nextSeed,
                state: current.snapshot,
                expectedRevision: current.snapshot.revision,
                marketID: marketID,
                offerID: offerID,
                ambition: ambition
            ))
        }
        guard accepted,
              let updated = result?.snapshot,
              updated.revision == current.snapshot.revision + 1 else { return accepted }
        GameAnalytics.log(.proContractSigned, [
            "market_kind": market?.kind.rawValue ?? "rookie",
            "offer_kind": offer?.contractKind.rawValue ?? "unknown",
            "outlook": offer?.outlook.rawValue ?? "unknown",
            "role": offer?.rolePromise.rawValue ?? updated.role.rawValue,
            "transfer": offer?.teamID != current.snapshot.team.id,
            "ambition_selected": ambition != nil,
        ])
        return accepted
    }

    /// Investment selection is persisted before the store publishes the new season. The event
    /// contains only stable categories and a coarse funds band, never raw money or player text.
    @discardableResult
    func chooseInvestment(
        investment: ProOffseasonInvestment,
        focus: ProDevelopmentFocus? = nil
    ) -> Bool {
        guard let current = result,
              let journey = current.snapshot.journeyState else { return false }
        let cost = ProFinanceRules.investmentCost(for: investment)
        let affordable = journey.finances.availableFunds >= cost
        let selected = perform(summary: nil, cue: .success) {
            try engine.chooseInvestment(.init(
                seed: current.nextSeed,
                state: current.snapshot,
                expectedRevision: current.snapshot.revision,
                investment: investment,
                focus: focus
            ))
        }
        guard selected else { return false }
        GameAnalytics.log(.proOffseasonInvestmentSelected, [
            "season": current.snapshot.season + 1,
            "investment": investment.rawValue,
            "affordable": affordable,
            "funds_band": Self.fundsBand(journey.finances.availableFunds),
        ])
        return true
    }

    /// Compatibility entry point for the pre-Wave 5 store surface. It remains an equal
    /// no-investment choice, while the product UI calls the full parameterized boundary above.
    func chooseInvestment() {
        _ = chooseInvestment(investment: .none)
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
            try engine.chooseOffseason(.init(
                seed: result.nextSeed,
                state: result.snapshot,
                decision: decision,
                expectedRevision: result.snapshot.journeyState == nil ? nil : result.snapshot.revision
            ))
        }
    }

    /// FA 신청 자격. 코어와 같은 식(1군 등록 6년)을 쓴다 — 화면이 못 누를 버튼을 내면
    /// 사용자는 오류 메시지로 규칙을 배우게 된다.
    static func freeAgencyService(_ state: ProCareerSnapshot) -> Int {
        if state.journeyState != nil {
            return state.serviceYears
        }
        return state.serviceYears + (state.level == .major ? 1 : 0)
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
        guard featureConfiguration.proCareerJourneyV1 || result.snapshot.journeyState == nil else {
            return false
        }
        let schemaVersion = Self.schemaVersion(for: result)
        guard canWrite(schemaVersion: schemaVersion) else { return false }
        let candidateRevision = Self.nextSyncRevision(
            after: syncedRevision,
            atLeast: result.snapshot.revision
        )
        let record = ProSaveRecord(
            result: result,
            gameResume: gameResume,
            sourceHighSchoolCareerID: sourceHighSchoolCareerID,
            origin: careerOrigin,
            schemaVersion: schemaVersion,
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
            if (1...journeySaveSchemaVersion).contains(version),
               record.result != nil || record.deletedRevision != nil,
               !(version < journeySaveSchemaVersion && record.result?.snapshot.journeyState != nil) {
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

    private static func schemaVersion(for result: ProCareerResult) -> Int {
        result.snapshot.journeyState == nil ? legacySaveSchemaVersion : journeySaveSchemaVersion
    }

    private static func shouldAutoMigrateJourney(on state: ProCareerSnapshot) -> Bool {
        switch state.phase {
        case .offseasonDecision, .retirementDecision:
            return true
        default:
            return false
        }
    }

    /// Read only the outer schema marker for the write downgrade gate. This deliberately works for
    /// future records that the full decoder cannot understand: a legacy writer must not replace a
    /// newer journey save or deletion tombstone merely because it cannot decode it.
    private static func rawSchemaVersion(_ data: Data) -> UInt64? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let version = object["schemaVersion"] as? Int {
            return version >= 0 ? UInt64(version) : nil
        }
        // A pre-wrapper ProCareerResult is schema 1.
        return object["snapshot"] != nil ? 1 : nil
    }

    private func canWrite(schemaVersion: Int) -> Bool {
        guard let existingData = sync.read(
            revision: Self.rawSchemaVersion,
            conflictPriority: { _ in 0 }
        ),
        let existingVersion = Self.rawSchemaVersion(existingData) else {
            return true
        }
        return existingVersion <= UInt64(schemaVersion)
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
        guard let decoded = record.result else { return .unavailable }
        syncedRevision = max(syncedRevision, record.effectiveRevision)
        var restored = decoded
        if featureConfiguration.proCareerJourneyV1,
           decoded.snapshot.journeyState == nil,
           Self.shouldAutoMigrateJourney(on: decoded.snapshot) {
            do {
                let migrated = try engine.migrateJourneyIfSafe(.init(
                    seed: decoded.nextSeed,
                    state: decoded.snapshot
                ))
                if migrated.snapshot.journeyState != nil {
                    let migrationRevision = Self.nextSyncRevision(
                        after: syncedRevision,
                        atLeast: migrated.snapshot.revision
                    )
                    let migratedRecord = ProSaveRecord(
                        result: migrated,
                        gameResume: record.gameResume,
                        sourceHighSchoolCareerID: record.sourceHighSchoolCareerID,
                        origin: record.origin,
                        schemaVersion: Self.journeySaveSchemaVersion,
                        syncRevision: migrationRevision
                    )
                    guard let migrationData = try? JSONEncoder().encode(migratedRecord),
                          sync.write(migrationData) else {
                        return .unavailable
                    }
                    syncedRevision = migrationRevision
                    restored = migrated
                }
            } catch {
                return .unavailable
            }
        }
        // 유료앱에서는 앱 자체가 구매 증거다. 저장된 스냅숏의 권한 출처(개발 빌드 포함)를 이유로
        // 진행을 버리면 TestFlight 사용자의 커리어만 사라진다.
        result = restored
        sourceHighSchoolCareerID = record.sourceHighSchoolCareerID
        careerOrigin = record.origin
        pitchSession = nil
        gameResume = nil
        pendingGains = []
        // 등판 도중 내려간 앱 — 타석 경계에서 이어 던진다(고교와 같은 검사).
        if restored.snapshot.phase == .importantGame,
           let resume = record.gameResume,
           PitchScenario.pro(state: restored.snapshot).id == resume.scenarioID {
            let session = PitchSession(state: restored.snapshot, seed: resume.seed)
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
            guard featureConfiguration.proCareerJourneyV1 || before?.journeyState == nil else {
                return false
            }
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
            (TalentAbility.stuff, before.stuff, after.stuff),
            (TalentAbility.command, before.command, after.command),
            (TalentAbility.movement, before.movement, after.movement),
            (TalentAbility.stamina, before.stamina, after.stamina)
        ]
        return pairs.compactMap { ability, from, to in
            to > from ? AbilityGain(ability: ability, before: from, after: to) : nil
        }
    }

    private func progressSummary(before: ProCareerSnapshot?, after: ProCareerSnapshot) -> String {
        guard let before else { return "다음 일정이 준비됐습니다." }
        let weeks = max(1, after.week - before.week)
        let games = max(0, after.currentStats.games - before.currentStats.games)
        let starts = max(0, after.currentStats.starts - before.currentStats.starts)
        let outs = max(0, after.currentStats.inningsOuts - before.currentStats.inningsOuts)
        let fatigue = after.fatigue - before.fatigue
        let trust = after.managerTrust - before.managerTrust
        var values = [
            "\(before.week + 1)~\(after.week)주차",
            "\(weeks)주",
            "\(games)경기(선발 \(starts))",
            Self.inningsText(outs),
            "감독의 믿음 \(trust >= 0 ? "+" : "")\(trust)",
            "피로 \(fatigue >= 0 ? "+" : "")\(fatigue)",
        ]
        if before.level != after.level {
            values.append(after.level == .major ? "1군 합류" : "2군 이동")
        }
        if before.role != after.role { values.append("역할 변경: \(Self.roleName(after.role))") }
        if after.milestones.count > before.milestones.count {
            values.append("주요 기록: \(after.milestones.last ?? "선수 기록")")
        }
        return values.joined(separator: " · ")
    }

    nonisolated static func inningsText(_ outs: Int) -> String {
        let safeOuts = max(0, outs)
        let innings = safeOuts / 3
        switch safeOuts % 3 {
        case 1: return "\(innings)⅓이닝"
        case 2: return "\(innings)⅔이닝"
        default: return "\(innings)이닝"
        }
    }

    nonisolated static func roleName(_ role: ProRole) -> String {
        GameCopyResolver(language: .korean, policy: .releaseSafe).resolve(role.displayCopyToken)
    }

}
