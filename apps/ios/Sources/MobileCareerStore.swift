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
        sync.clear()
        result = nil
        pitchSession = nil
        pendingGains = []
        lastSummary = nil
        loadState = .needsSetup
    }

    // MARK: - 주간 진행

    func advanceWeek() {
        guard let result else { return }
        perform { try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: selectedPlan)) }
    }

    func advanceBlock() {
        guard let result else { return }
        perform {
            var current = result
            for _ in 0..<3 where current.snapshot.phase == .weeklyPlan {
                current = try engine.planWeek(.init(seed: current.nextSeed, state: current.snapshot, plan: selectedPlan))
            }
            return current
        }
    }

    // MARK: - 중요 경기

    /// 실제 투구 세션을 연다. 이전 구현처럼 미리 정해진 성적을 돌려주지 않는다.
    func beginImportantGame() {
        guard let result, result.snapshot.phase == .importantGame else { return }
        guard pitchSession == nil else { return }
        let session = PitchSession(state: result.snapshot, seed: result.nextSeed)
        session.start()
        pitchSession = session
    }

    /// 세션에서 실제로 누적된 리포트를 프로 커리어에 반영한다.
    func finishImportantGame() {
        guard let result, let session = pitchSession else { return }
        let report = session.report(scenarioNumber: result.snapshot.week)
        let summary = "\(report.pitches)구 · \(report.strikeouts)탈삼진 · \(report.walks)볼넷 · \(report.runsAllowed)실점"
        AchievementStore.shared.record(AchievementRules.fromInning(report: report) + session.bestDeliveryAchievements)
        pitchSession = nil
        perform(summary: summary, cue: report.runsAllowed == 0 ? .success : .setback) {
            try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report))
        }
    }

    func abandonImportantGame() {
        pitchSession = nil
    }

    // MARK: - 시즌

    func reviewSeason() {
        guard let result else { return }
        perform(summary: "시즌 기록을 통산 기록에 확정했습니다.", cue: .success) {
            try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
        }
    }

    func continueCareer() {
        guard let result else { return }
        perform { try engine.chooseOffseason(.init(seed: result.nextSeed, state: result.snapshot, decision: .continueCareer)) }
    }

    func acknowledgeGains() {
        pendingGains = []
    }

    // MARK: - 저장

    func save() {
        guard let result, let data = try? JSONEncoder().encode(result) else { return }
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
            try? JSONDecoder().decode(ProCareerResult.self, from: data).snapshot.revision
        }) else { return false }
        guard let decoded = try? JSONDecoder().decode(ProCareerResult.self, from: data) else { return false }
        // 유료앱에서는 앱 자체가 구매 증거다. 저장된 스냅숏의 권한 출처(개발 빌드 포함)를 이유로
        // 진행을 버리면 TestFlight 사용자의 커리어만 사라진다.
        result = decoded
        return true
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
