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
    enum LoadState: Equatable {
        case loading
        case needsSetup
        case ready
        case failed(String)
    }

    /// 다음 생으로 넘기는 것. 환생 루프의 저장 단위다.
    struct Inheritance: Codable, Equatable {
        var lifeNumber: Int
        var memories: [MemoryCardID]
        var soulPoints: Int
        var karmas: [KarmaID]

        static let firstLife = Inheritance(lifeNumber: 1, memories: [], soulPoints: 0, karmas: [])
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
    private(set) var inheritance: Inheritance = .firstLife

    private let engine = HighSchoolCareerEngine()
    private let sync = SaveSync(key: "baseball-mobile-highschool-v1.json")

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
        loadState = restore() ? .ready : .needsSetup
    }

    func startCareer(
        preset: PitcherPresetSnapshot,
        playerName: String,
        difficulty: CareerDifficultySnapshot = .standard,
        karmas: [KarmaID] = []
    ) {
        let trimmed = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? preset.pitcher.name : trimmed
        let identity = PlayerIdentitySnapshot(
            name: name,
            throwingHand: preset.pitcher.throwingHand,
            bodyType: .balanced,
            region: "서울"
        )
        var carried = inheritance
        carried.karmas = karmas
        do {
            let created = try engine.start(
                .init(
                    seed: String(UInt64.random(in: 1...UInt64.max)),
                    presetID: preset.id,
                    lifeNumber: carried.lifeNumber,
                    inheritedSoulPoints: carried.soulPoints,
                    inheritedMemories: carried.memories,
                    identity: identity,
                    difficulty: difficulty,
                    karmas: karmas
                )
            )
            inheritance = carried
            AchievementStore.shared.record(AchievementRules.fromLifeNumber(carried.lifeNumber))
            AchievementStore.shared.submit(LeaderboardRules.scores(lifeNumber: carried.lifeNumber))
            result = created
            lastSummary = carried.lifeNumber > 1
                ? "\(carried.lifeNumber)회차. 기억 \(carried.memories.count)장을 안고 다시 시작합니다."
                : "고교 첫 해가 시작됩니다."
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
        selectedMemories = []
        inheritance = .firstLife
        loadState = .needsSetup
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

    /// 연습을 마치고 프롤로그를 끝낸다. 업적·기록에는 남기지 않는다.
    func finishTutorialPitch() {
        completePrologue()
    }

    func chooseSchool(_ schoolID: SchoolID) {
        perform { try engine.chooseSchool(.init(seed: $0.nextSeed, state: $0.snapshot, schoolID: schoolID)) }
    }

    func commitTraining(focus: TrainingFocus, intensity: TrainingIntensity) {
        perform { try engine.commitTraining(.init(seed: $0.nextSeed, state: $0.snapshot, focus: focus, intensity: intensity)) }
    }

    func resolveRelationship(_ response: RelationshipResponse) {
        perform { try engine.resolveRelationship(.init(seed: $0.nextSeed, state: $0.snapshot, response: response)) }
    }

    func chooseAwakening(_ awakening: AwakeningID) {
        perform(cue: .growth) { try engine.chooseAwakening(.init(seed: $0.nextSeed, state: $0.snapshot, awakening: awakening)) }
    }

    func advanceChapter() {
        perform { try engine.advanceChapter(.init(seed: $0.nextSeed, state: $0.snapshot)) }
    }

    /// 지명된 회차를 접고 기억 선택으로 들어간다. 미지명은 이미 그 단계에 있다.
    func openLegacy() {
        perform { try engine.openLegacy(.init(seed: $0.nextSeed, state: $0.snapshot)) }
    }

    func resolveDraft() {
        perform(cue: .success) { try engine.resolveDraft(.init(seed: $0.nextSeed, state: $0.snapshot)) }
    }

    // MARK: - 중요 경기

    func beginImportantGame() {
        guard let result, result.snapshot.phase == .importantGame, pitchSession == nil else { return }
        let session = PitchSession(highSchool: result.snapshot, seed: result.nextSeed)
        session.start()
        pitchSession = session
    }

    func finishImportantGame() {
        guard let result, let session = pitchSession else { return }
        let report = session.report(scenarioNumber: result.snapshot.performance.importantGamesCompleted + 1)
        let summary = "\(report.pitches)구 · \(report.strikeouts)탈삼진 · \(report.walks)볼넷 · \(report.runsAllowed)실점"
        AchievementStore.shared.record(AchievementRules.fromInning(report: report) + session.bestDeliveryAchievements)
        pitchSession = nil
        perform(summary: summary, cue: report.runsAllowed == 0 ? .success : .setback) {
            try engine.recordImportantGame(.init(seed: $0.nextSeed, state: $0.snapshot, report: report))
        }
    }

    func abandonImportantGame() {
        pitchSession = nil
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

    /// 기억 카드를 확정하고 다음 생으로 넘길 계승분을 만든다.
    func confirmLegacy() {
        guard let current = result else { return }
        // 코어는 정확히 memorySlots장을 요구한다. 모자라면 조용히 아무것도 하지 않는다.
        guard selectedMemories.count == current.snapshot.memorySlots else { return }
        let chosen = selectedMemories
        perform(summary: "기억 \(chosen.count)장을 다음 생으로 가져갑니다.", cue: .growth) {
            try engine.selectLegacy(.init(seed: $0.nextSeed, state: $0.snapshot, memoryCards: chosen))
        }
        inheritance = Self.nextInheritance(from: current.snapshot, memories: chosen, previous: inheritance)
        selectedMemories = []
        save()
    }

    /// 다음 생을 시작한다. 계승분은 유지하고 진행만 비운다.
    func beginNextLife() {
        sync.clear()
        result = nil
        pitchSession = nil
        pendingGains = []
        loadState = .needsSetup
    }

    /// 회차 보상 계산. 순수 함수라 테스트할 수 있다.
    nonisolated static func nextInheritance(
        from state: HighSchoolCareerSnapshot,
        memories: [MemoryCardID],
        previous: Inheritance
    ) -> Inheritance {
        // 영혼 포인트는 능력 총합과 경기 기록, 카르마 보상 배율에서 나온다. 실패한 회차도
        // 0이 되지는 않는다 — 환생물의 재접속 장치는 "다음엔 조금 더 강하다"이다.
        let ratings = state.pitcher.stuff + state.pitcher.command + state.pitcher.movement + state.pitcher.stamina
        let record = state.performance.strikeouts * 2 - state.performance.walks - state.performance.runsAllowed * 2
        let base = max(4, ratings / 8 + max(0, record) / 4)
        let rewarded = base * (1_000 + state.legacyRewardPermille) / 1_000
        return Inheritance(
            lifeNumber: previous.lifeNumber + 1,
            memories: memories,
            soulPoints: previous.soulPoints + rewarded,
            karmas: previous.karmas
        )
    }

    func acknowledgeGains() {
        pendingGains = []
    }

    // MARK: - 저장

    func save() {
        guard let result else { return }
        let record = SaveRecord(result: result, inheritance: inheritance)
        guard let data = try? JSONEncoder().encode(record) else { return }
        sync.write(data)
    }

    /// 다른 기기에서 진행이 올라왔을 때 다시 읽는다.
    func reloadFromSync() {
        guard pitchSession == nil, tutorialSession == nil else { return }
        let current = result?.snapshot.revision ?? 0
        guard restore(), let loaded = result?.snapshot.revision, loaded > current else { return }
        lastSummary = "다른 기기의 진행을 불러왔습니다."
        feedbackTrigger += 1
    }

    private struct SaveRecord: Codable {
        let result: HighSchoolCareerResult
        let inheritance: Inheritance
    }

    private func restore() -> Bool {
        guard let data = sync.read(revision: { data in
            try? JSONDecoder().decode(SaveRecord.self, from: data).result.snapshot.revision
        }) else { return false }
        guard let record = try? JSONDecoder().decode(SaveRecord.self, from: data) else { return false }
        result = record.result
        inheritance = record.inheritance
        return true
    }

    private func perform(
        summary: String? = nil,
        cue: MobileCareerStore.FeedbackCue? = nil,
        _ action: (HighSchoolCareerResult) throws -> HighSchoolCareerResult
    ) {
        guard let current = result else { return }
        do {
            let before = current.snapshot
            let updated = try action(current)
            result = updated
            pendingGains = MobileCareerStore.gains(before: before.pitcher, after: updated.snapshot.pitcher)
            lastSummary = summary ?? Self.progressSummary(before: before, after: updated.snapshot)
            feedbackCue = cue ?? (pendingGains.isEmpty ? .neutral : .growth)
            feedbackTrigger += 1
            loadState = .ready
            AchievementStore.shared.record(AchievementRules.fromHighSchool(updated.snapshot))
            save()
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    nonisolated static func progressSummary(before: HighSchoolCareerSnapshot, after: HighSchoolCareerSnapshot) -> String {
        if let training = after.lastTraining, training.number != before.lastTraining?.number {
            return training.feedback
        }
        if let relationship = after.lastRelationship, relationship.number != before.lastRelationship?.number {
            return relationship.feedback
        }
        if after.chapter.number != before.chapter.number {
            return "\(after.chapter.title) · \(after.chapter.season)"
        }
        return after.news.first ?? "다음 일정이 준비됐습니다."
    }

}
