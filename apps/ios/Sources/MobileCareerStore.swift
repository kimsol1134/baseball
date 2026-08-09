import Foundation
import Observation
import SimulationCore

@MainActor
@Observable
final class MobileCareerStore {
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
    var lastSummary: String?
    var feedbackTrigger = 0
    var feedbackCue: FeedbackCue = .neutral
    var pendingGains: [AbilityGain] = []
    /// 진행 중인 중요 경기. `importantGame` 단계에서만 존재한다.
    var pitchSession: PitchSession?

    private let engine = ProCareerEngine()
    private let sync = SaveSync(key: "baseball-mobile-pro-v1.json")

    var state: ProCareerSnapshot? { result?.snapshot }

    // MARK: - 수명 주기

    func restoreOrCreateCareer() {
        guard result == nil else { return }
        loadState = restore() ? .ready : .needsSetup
    }

    /// 유료앱에서는 앱 구매가 곧 이용 권한이므로 디버그/릴리스가 같은 경로를 탄다.
    func startNewCareer(preset: PitcherPresetSnapshot, playerName: String) {
        do {
            let seed = UInt64.random(in: 1...UInt64.max)
            let created = try CareerBootstrap.startCareer(preset: preset, playerName: playerName, seed: seed)
            result = created
            lastSummary = "\(created.snapshot.team.name) 입단. 2군에서 첫 시즌을 시작합니다."
            feedbackCue = .success
            feedbackTrigger += 1
            loadState = .ready
            save()
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    /// 고교 커리어의 지명 결과로 프로를 연다. 정규 경로다.
    func startProCareer(
        draft: DraftResultSnapshot,
        pitcher: PitcherSnapshot,
        identity: PlayerIdentitySnapshot
    ) {
        do {
            let created = try CareerBootstrap.startCareer(
                draft: draft,
                pitcher: pitcher,
                identity: identity,
                seed: UInt64.random(in: 1...UInt64.max)
            )
            result = created
            lastSummary = "\(created.snapshot.team.name) 입단. 고교 3년의 능력을 그대로 안고 시작합니다."
            feedbackCue = .success
            feedbackTrigger += 1
            loadState = .ready
            save()
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func deleteCareer() {
        // clear() 대신 묘비 — 고교 쪽과 같은 이유(iCloud 부활 방지).
        let tombstone = max(syncedRevision, result?.snapshot.revision ?? 0) + 1
        syncedRevision = tombstone
        result = nil
        pitchSession = nil
        gameResume = nil
        pendingGains = []
        lastSummary = nil
        if let data = try? JSONEncoder().encode(ProSaveRecord(result: nil, deletedRevision: tombstone)) {
            sync.write(data)
        }
        loadState = .needsSetup
    }

    // MARK: - 주간 진행

    func advanceWeek() {
        guard let result else { return }
        perform { try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: selectedPlan)) }
    }

    /// 다음 구간 어귀까지 자동으로 진행한다.
    ///
    /// 24주를 한 주씩 넘기는 것이 프로 후반의 실제 경험이었다. 같은 카드 다섯 장에서 하나를
    /// 고르는 일이 시즌마다 24번, 12시즌이면 288번이다. 구간(스프링캠프·개막·전반기·올스타
    /// 브레이크·페넌트레이스·시즌 막바지)은 이미 코어가 알고 있으니, **결정이 필요한 자리에서만
    /// 멈추게** 한다 — 구간이 바뀌거나, 중요 경기가 잡히거나, 역할·소속이 움직이거나, 다치거나.
    func advanceSegment() {
        guard let result else { return }
        perform {
            var current = result
            let startSegment = current.snapshot.seasonSegment
            for _ in 0..<24 where current.snapshot.phase == .weeklyPlan {
                let before = current.snapshot
                current = try engine.planWeek(
                    .init(seed: current.nextSeed, state: current.snapshot, plan: selectedPlan)
                )
                let after = current.snapshot
                // 여기서 멈춘다: 화면이 약속한 것들이다.
                if after.seasonSegment != startSegment { break }
                if after.role != before.role || after.level != before.level { break }
                if after.injuryWeeks > before.injuryWeeks { break }
            }
            return current
        }
    }

    func advanceBlock() {
        guard let result else { return }
        perform {
            var current = result
            for _ in 0..<3 where current.snapshot.phase == .weeklyPlan {
                let before = current.snapshot
                current = try engine.planWeek(.init(seed: current.nextSeed, state: current.snapshot, plan: selectedPlan))
                // 화면이 "선발·불펜 역할 변화가 생기면 멈춥니다"라고 약속한다. 역할·소속이
                // 바뀌었는데 남은 주를 그대로 흘려보내면 그 약속이 거짓이 된다.
                if current.snapshot.role != before.role || current.snapshot.level != before.level { break }
            }
            return current
        }
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
        self.result = ProCareerResult(snapshot: result.snapshot, nextSeed: sessionSeed, events: result.events)
        save()
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
        let summary = "\(report.pitches)구 · \(report.strikeouts)탈삼진 · \(report.walks)볼넷 · \(report.runsAllowed)실점"
        AchievementStore.shared.record(AchievementRules.fromInning(report: report) + session.bestDeliveryAchievements)
        pitchSession = nil
        gameResume = nil
        perform(summary: summary, cue: report.runsAllowed == 0 ? .success : .setback) {
            try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report))
        }
        GameAnalytics.log(.gameFinished, [
            "mode": "pro",
            "result": report.runsAllowed == 0 ? "scoreless" : "runs_allowed",
            "strikeouts": report.strikeouts,
            "walks": report.walks,
            "runs": report.runsAllowed,
        ])
    }

    func abandonImportantGame() {
        pitchSession = nil
        gameResume = nil
        save()
        lastSummary = "등판을 중단했습니다. 다음 마운드는 새 이닝입니다."
        feedbackCue = .setback
        feedbackTrigger += 1
    }

    // MARK: - 시즌

    func reviewSeason() {
        guard let result else { return }
        perform(summary: "시즌 기록을 통산 기록에 확정했습니다.", cue: .success) {
            try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
        }
    }

    func continueCareer() { chooseOffseason(.continueCareer) }

    /// 오프시즌 네 갈래. 코어는 네 가지를 전부 받는데 화면이 잔류 하나만 냈다.
    ///
    /// 그래서 군 복무와 FA 서사가 게임에 존재하지 않았고, 12시즌·37세에 도달해
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

    /// 진행 중 등판의 타석 경계 스냅샷. 고교와 같은 문법 — 프로 12시즌의
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
    }

    /// 마지막으로 알게 된 저장 리비전 — 묘비가 이 값보다 커야 부활을 막는다.
    private var syncedRevision: UInt64 = 0

    // MARK: - 저장

    func save() {
        guard let result else { return }
        syncedRevision = max(syncedRevision, result.snapshot.revision)
        let record = ProSaveRecord(result: result, gameResume: gameResume)
        guard let data = try? JSONEncoder().encode(record) else { return }
        sync.write(data)
    }

    /// 다른 기기에서 진행이 올라왔을 때 다시 읽는다.
    func reloadFromSync() {
        // 승부 중에는 상태를 갈아끼우지 않는다. 진행 중인 이닝이 사라지면 더 나쁘다.
        guard pitchSession == nil else { return }
        let current = result?.snapshot.revision ?? 0
        guard restore(), let loaded = result?.snapshot.revision, loaded > current else { return }
        lastSummary = "다른 기기의 진행을 불러왔습니다."
        feedbackTrigger += 1
    }

    private func restore() -> Bool {
        guard let data = sync.read(revision: { data in
            (try? JSONDecoder().decode(ProSaveRecord.self, from: data)).flatMap { $0.result?.snapshot.revision ?? $0.deletedRevision }
                ?? (try? JSONDecoder().decode(ProCareerResult.self, from: data))?.snapshot.revision
        }) else { return false }
        let record = try? JSONDecoder().decode(ProSaveRecord.self, from: data)
        if let tombstone = record?.deletedRevision, record?.result == nil {
            // 삭제 묘비 — 옛 사본이 아니라 삭제가 최신이다.
            syncedRevision = tombstone
            return false
        }
        let decoded = record?.result ?? (try? JSONDecoder().decode(ProCareerResult.self, from: data))
        guard let decoded else { return false }
        syncedRevision = max(syncedRevision, decoded.snapshot.revision)
        // 유료앱에서는 앱 자체가 구매 증거다. 저장된 스냅숏의 권한 출처(개발 빌드 포함)를 이유로
        // 진행을 버리면 TestFlight 사용자의 커리어만 사라진다.
        result = decoded
        // 등판 도중 내려간 앱 — 타석 경계에서 이어 던진다(고교와 같은 검사).
        if decoded.snapshot.phase == .importantGame,
           let resume = record?.gameResume,
           PitchScenario.pro(state: decoded.snapshot).id == resume.scenarioID {
            let session = PitchSession(state: decoded.snapshot, seed: resume.seed)
            session.start()
            session.restore(from: resume)
            attachCheckpoint(session)
            gameResume = resume
            pitchSession = session
        }
        return true
    }

    private func attachCheckpoint(_ session: PitchSession) {
        session.onCheckpoint = { [weak self] session in
            guard let self else { return }
            self.gameResume = session.resumeState()
            self.save()
        }
    }

    private func perform(
        summary: String? = nil,
        cue: FeedbackCue? = nil,
        _ action: () throws -> ProCareerResult
    ) {
        do {
            let before = result?.snapshot
            let updated = try action()
            result = updated
            pendingGains = Self.gains(before: before?.pitcher, after: updated.snapshot.pitcher)
            lastSummary = summary ?? progressSummary(before: before, after: updated.snapshot)
            feedbackCue = cue ?? (pendingGains.isEmpty ? .neutral : .growth)
            feedbackTrigger += 1
            loadState = .ready
            AchievementStore.shared.record(AchievementRules.fromPro(updated.snapshot))
            AchievementStore.shared.submit(LeaderboardRules.scores(for: updated.snapshot))
            save()
        } catch {
            loadState = .failed(error.localizedDescription)
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
        if before.level != after.level { return "1군 출전 명단에 합류했습니다. 다음 중요 경기가 바로 이어집니다." }
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
