import Foundation
import Observation
import SimulationCore

@MainActor
@Observable
final class MobileCareerStore {
    enum ImportantApproach: String, CaseIterable, Identifiable {
        case trustBattery, attackZone, expandZone
        var id: Self { self }
        var title: String { switch self { case .trustBattery: "포수의 시퀀스를 따른다"; case .attackZone: "존 안에서 먼저 승부한다"; case .expandZone: "변화구로 존을 넓힌다" } }
        var detail: String { switch self { case .trustBattery: "볼배합 안정 · 배터리 신뢰 상승"; case .attackZone: "삼진 기회 상승 · 장타 위험 상승"; case .expandZone: "헛스윙 기회 상승 · 볼넷 위험 상승" } }
    }
    enum LoadState: Equatable { case loading, ready, failed(String) }
    var loadState: LoadState = .loading
    var result: ProCareerResult?
    var selectedPlan: ProWeekPlan = .earnTrust
    var selectedApproach: ImportantApproach = .trustBattery
    var lastSummary: String?
    var feedbackTrigger = 0
    private let engine = ProCareerEngine()

    var state: ProCareerSnapshot? { result?.snapshot }

    func restoreOrCreateCareer() {
        guard result == nil else { return }
        if restore() { loadState = .ready; return }
#if DEBUG
        do {
            let team = ProCareerEngine.proTeams[0]
            let draft = DraftResultSnapshot(outcome: .drafted, evaluationScore: 72, projectedRange: "2~3라운드", team: team, round: 2, overallPick: 18, signingBonus: 120_000_000, firstSeasonGoal: "2군 선발", summary: "\(team.name) 지명")
            let pitcher = PitcherSnapshot(id: "mobile-pitcher", name: "민서준", stuff: 58, command: 56, movement: 55, stamina: 57)
            let entitlement = ProEntitlementSnapshot(status: .active, source: .development, verifiedAt: ISO8601DateFormatter().string(from: .now))
            var created = try engine.start(.init(seed: "20260722", identity: .defaultPitcher, pitcher: pitcher, draftResult: draft, entitlement: entitlement))
            created = try engine.signContract(.init(seed: created.nextSeed, state: created.snapshot))
            result = created
            loadState = .ready
            save()
        } catch { loadState = .failed(error.localizedDescription) }
#else
        loadState = .failed("검증된 프로 커리어 구매 또는 복원 권한을 찾지 못했습니다. 이 빌드는 개발용 커리어를 자동으로 만들지 않습니다.")
#endif
    }

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

    func resolveImportantMoment() {
        guard let result else { return }
        let report: ImportantInningReport
        switch selectedApproach {
        case .trustBattery:
            report = .init(scenarioNumber: result.snapshot.week, pitches: 18, strikeouts: 2, walks: 1, runsAllowed: 0, expectedDamage: 420, actualDamage: 310, recommendationAccepted: 15)
        case .attackZone:
            report = .init(scenarioNumber: result.snapshot.week, pitches: 15, strikeouts: 3, walks: 0, runsAllowed: 1, expectedDamage: 560, actualDamage: 720, recommendationAccepted: 7)
        case .expandZone:
            report = .init(scenarioNumber: result.snapshot.week, pitches: 21, strikeouts: 3, walks: 2, runsAllowed: 0, expectedDamage: 390, actualDamage: 260, recommendationAccepted: 8)
        }
        perform(summary: "\(report.pitches)구 · \(report.strikeouts)탈삼진 · \(report.walks)볼넷 · \(report.runsAllowed)실점. 선택한 승부 방식이 감독과 포수의 평가에 반영됐습니다.") {
            try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report))
        }
    }

    func reviewSeason() {
        guard let result else { return }
        perform(summary: "시즌 기록을 통산 기록에 확정했습니다.") { try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot)) }
    }

    func continueCareer() {
        guard let result else { return }
        perform { try engine.chooseOffseason(.init(seed: result.nextSeed, state: result.snapshot, decision: .continueCareer)) }
    }

    func save() {
        guard let result, let data = try? JSONEncoder().encode(result) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }

    private func restore() -> Bool {
        guard let data = try? Data(contentsOf: saveURL), let decoded = try? JSONDecoder().decode(ProCareerResult.self, from: data) else { return false }
#if !DEBUG
        guard decoded.snapshot.entitlement.status == .active, decoded.snapshot.entitlement.source != .development else { return false }
#endif
        result = decoded; return true
    }

    private func perform(summary: String? = nil, _ action: () throws -> ProCareerResult) {
        do {
            let before = result?.snapshot
            let updated = try action()
            result = updated
            lastSummary = summary ?? progressSummary(before: before, after: updated.snapshot)
            feedbackTrigger += 1
            loadState = .ready
            save()
        }
        catch { loadState = .failed(error.localizedDescription) }
    }

    private func progressSummary(before: ProCareerSnapshot?, after: ProCareerSnapshot) -> String {
        guard let before else { return "다음 일정이 준비됐습니다." }
        if before.level != after.level { return "1군 엔트리에 합류했습니다. 다음 중요 승부가 바로 이어집니다." }
        if before.role != after.role { return "감독 면담 뒤 보직이 \(roleName(after.role))로 바뀌었습니다." }
        if after.milestones.count > before.milestones.count { return "새 이정표 · \(after.milestones.last ?? "커리어 기록")" }
        let fatigue = after.fatigue - before.fatigue
        let trust = after.managerTrust - before.managerTrust
        return "\(before.week + 1)주차 완료 · 감독 신뢰 \(trust >= 0 ? "+" : "")\(trust) · 피로 \(fatigue >= 0 ? "+" : "")\(fatigue)"
    }

    private func roleName(_ role: ProRole) -> String {
        switch role { case .starter: "선발"; case .longRelief: "롱릴리프"; case .setup: "셋업맨"; case .closer: "마무리" }
    }

    private var saveURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("baseball-mobile-pro-v1.json")
    }
}
