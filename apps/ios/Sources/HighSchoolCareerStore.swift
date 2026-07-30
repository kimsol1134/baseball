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

    /// 다음 회차로 넘기는 것. 환생 루프의 저장 단위다.
    struct Inheritance: Codable, Equatable {
        var lifeNumber: Int
        var memories: [MemoryCardID]
        var soulPoints: Int
        var karmas: [KarmaID]
        /// 야구혼으로 이미 접은 프로 커리어. 같은 커리어를 두 번 계산하지 않기 위한 표식이다.
        /// 옵셔널이라 이 필드가 없는 옛 저장본도 그대로 열린다.
        var creditedProCareerID: String?

        static let firstLife = Inheritance(lifeNumber: 1, memories: [], soulPoints: 0, karmas: [])
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
        /// 이 회차가 어떤 사람이었는가. 없는 옛 기록은 nil이다.
        var personality: String? = nil

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
    /// 방금 만개한 재능. 화면이 축하하고 나서 비운다.
    private(set) var pendingBloom: Bloom?
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

    /// 프로로 넘어간 사실을 기록한다. 화면이 프로 진입 직후에 부른다.
    func markEnteredPro() {
        enteredProCareerID = state?.careerID
        note("프로 유니폼을 입었습니다.")
        save()
    }

    struct Bloom: Equatable {
        let ability: TalentAbility
        let grade: TalentGrade
    }
    private(set) var inheritance: Inheritance = .firstLife
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
    /// 이번 챕터가 시작될 때의 통산 탈삼진. 챕터 목표의 진행은 이 값과의 차이다.
    private(set) var chapterStartStrikeouts: Int = 0
    /// 목표 축하를 이미 한 챕터 번호. 같은 챕터에서 두 번 축하하면 축하가 값싸진다.
    private(set) var goalCelebratedChapter: Int?
    /// 관계 응답 누적 — 성격은 선택이 만든다. 경기 성적은 여기 한 획도 못 긋는다.
    private(set) var responseTally = ResponseTally()

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
        region: String = "서울",
        difficulty: CareerDifficultySnapshot = .standard,
        karmas: [KarmaID] = [],
        soulDomain: SoulDomain? = nil
    ) {
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
        carried.karmas = karmas
        do {
            let created = try engine.start(
                .init(
                    seed: String(UInt64.random(in: 1...UInt64.max)),
                    presetID: preset.id,
                    lifeNumber: carried.lifeNumber,
                    inheritedSoulPoints: carried.soulPoints,
                    inheritedSoulDomain: soulDomain,
                    inheritedMemories: carried.memories,
                    identity: identity,
                    difficulty: difficulty,
                    karmas: karmas
                )
            )
            inheritance = carried
            // 별명과 연대기는 이번 회차의 것이다. 환생하면 새로 쓴다.
            nicknames = []
            chronicle = []
            chapterStartStrikeouts = 0
            goalCelebratedChapter = nil
            responseTally = ResponseTally()
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
        defer { if let school = result?.snapshot.school { note("\(school.name) 입학. 3년이 시작됩니다.") } }
        perform { try engine.chooseSchool(.init(seed: $0.nextSeed, state: $0.snapshot, schoolID: schoolID)) }
    }

    func commitTraining(focus: TrainingFocus, intensity: TrainingIntensity) {
        perform { try engine.commitTraining(.init(seed: $0.nextSeed, state: $0.snapshot, focus: focus, intensity: intensity)) }
    }

    func resolveRelationship(_ response: RelationshipResponse) {
        let before = responseTally.personality
        perform { try engine.resolveRelationship(.init(seed: $0.nextSeed, state: $0.snapshot, response: response)) }
        switch response {
        case .listen: responseTally.listen += 1
        case .explain: responseTally.explain += 1
        case .challenge: responseTally.challenge += 1
        }
        // 성격이 처음 굳거나 서서히 바뀐 순간은 연대기에 남긴다 — 능력치가 아니라
        // 사람됨의 사건이다.
        if let after = responseTally.personality, after != before {
            note(before == nil
                 ? "성격이 자리 잡았습니다 — '\(after.title)'. \(after.scoutLine)"
                 : "성격이 달라졌습니다 — '\(after.title)'. 사람은 고정된 값이 아닙니다.")
        }
        save()
    }

    func chooseAwakening(_ awakening: AwakeningID) {
        perform(cue: .growth) { try engine.chooseAwakening(.init(seed: $0.nextSeed, state: $0.snapshot, awakening: awakening)) }
        // 엔진이 만든 각성 문장("'○○'을 익혔습니다…")을 그대로 적는다.
        if let line = result?.snapshot.news.first { note(line) }
    }

    func advanceChapter() {
        perform { try engine.advanceChapter(.init(seed: $0.nextSeed, state: $0.snapshot)) }
        chapterStartStrikeouts = result?.snapshot.performance.strikeouts ?? chapterStartStrikeouts
        if let snapshot = result?.snapshot {
            worldNews = CommunityBuzz.rivalNews(careerID: snapshot.careerID, chapterNumber: snapshot.chapter.number)
        }
        buzz = []
        save()
    }

    /// 지명된 회차를 접고 기억 선택으로 들어간다. 미지명은 이미 그 단계에 있다.
    func openLegacy() {
        perform { try engine.openLegacy(.init(seed: $0.nextSeed, state: $0.snapshot)) }
    }

    func resolveDraft() {
        perform(cue: .success) { try engine.resolveDraft(.init(seed: $0.nextSeed, state: $0.snapshot)) }
        if let draft = result?.snapshot.draftResult {
            if draft.outcome == .drafted, let team = draft.team {
                note("드래프트 \(draft.round.map { "\($0)라운드 " } ?? "")\(team.name) 지명. 3년이 응답받았습니다.")
            } else {
                note("드래프트 미지명. 하지만 이 3년은 다음 회차의 밑천이 됩니다.")
            }
        }
    }

    // MARK: - 중요 경기

    func beginImportantGame() {
        guard let result, result.snapshot.phase == .importantGame, pitchSession == nil else { return }
        // 프로와 같은 이유로 시드를 넘기고 저장한다. 결과 반영 전에 앱을 껐다 켜면 같은
        // 이닝을 같은 난수로 다시 던질 수 있었다(무제한 리트라이).
        let sessionSeed = MobileCareerStore.advanced(result.nextSeed)
        self.result = HighSchoolCareerResult(
            revision: result.revision, nextSeed: sessionSeed, events: result.events,
            snapshot: result.snapshot, eventHash: result.eventHash
        )
        save()
        let session = PitchSession(highSchool: result.snapshot, seed: sessionSeed)
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
        let before = Set(nicknames.map(\.id))
        earnNicknames()
        noteGame(report: report, summary: summary)
        celebrateChapterGoalIfCrossed()
        buzz = CommunityBuzz.reactions(
            careerID: self.result?.snapshot.careerID ?? "",
            gameNumber: self.result?.snapshot.performance.importantGamesCompleted ?? 0,
            strikeouts: report.strikeouts,
            walks: report.walks,
            runsAllowed: report.runsAllowed,
            newNickname: nicknames.first { !before.contains($0.id) }?.title
        )
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
        note("\(goal.title) 완수 — 챕터 탈삼진 \(progress)개.")
        lastSummary = "\(goal.title) 완수. 삼진 \(progress)개 — 숙제는 끝났고, 다음은 욕심의 영역입니다."
        feedbackCue = .success
        feedbackTrigger += 1
        save()
    }

    /// 경기 전부를 적지 않는다 — 처음, 완벽, 압도, 붕괴. 이야기가 되는 경기만.
    private func noteGame(report: ImportantInningReport, summary: String) {
        let games = result?.snapshot.performance.importantGamesCompleted ?? 0
        if games == 1 { return note("첫 공식 등판 — \(summary)") }
        if report.runsAllowed == 0 { return note("무실점 호투 — \(summary)") }
        if report.strikeouts >= 6 { return note("탈삼진 \(report.strikeouts)개로 압도 — \(summary)") }
        if report.runsAllowed >= 5 { return note("무너진 날 — \(summary). 이 경기를 기억해야 합니다.") }
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
        for earned in fresh { note("'\(earned.title)'(이)라는 별명을 얻었습니다. \(earned.reason)") }
        if let first = fresh.first {
            lastSummary = "이제 사람들이 '\(first.title)'(이)라고 부릅니다. \(first.reason)"
            feedbackCue = .success
            feedbackTrigger += 1
        }
        save()
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

    /// 기억 카드를 확정하고 다음 회차로 넘길 계승분을 만든다.
    func confirmLegacy() {
        guard let current = result else { return }
        // 코어는 정확히 memorySlots장을 요구한다. 모자라면 조용히 아무것도 하지 않는다.
        guard selectedMemories.count == current.snapshot.memorySlots else { return }
        let chosen = selectedMemories
        perform(summary: "기억 \(chosen.count)장을 다음 회차로 가져갑니다.", cue: .growth) {
            try engine.selectLegacy(.init(seed: $0.nextSeed, state: $0.snapshot, memoryCards: chosen))
        }
        let closed = Self.lifeRecord(from: current.snapshot, memories: chosen, previous: inheritance, nicknames: nicknames, chronicle: chronicle, personality: personality)
        inheritance = Self.nextInheritance(from: current.snapshot, memories: chosen, previous: inheritance)
        // 같은 회차를 두 번 적지 않는다. 저장본을 되돌려 다시 확정하는 경로가 있다.
        archive.removeAll { $0.lifeNumber == closed.lifeNumber }
        archive.insert(closed, at: 0)
        AchievementStore.shared.record(AchievementRules.fromArchive(archive))
        selectedMemories = []
        save()
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
        loadState = .needsSetup
        save()
    }

    /// 끝난 회차를 한 장으로 접는다. 순수 함수라 테스트할 수 있다.
    nonisolated static func lifeRecord(
        from state: HighSchoolCareerSnapshot,
        memories: [MemoryCardID],
        previous: Inheritance,
        nicknames: [Nickname] = [],
        chronicle: [ChronicleEntry] = [],
        personality: Personality? = nil
    ) -> LifeRecord {
        LifeRecord(
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
            soulPoints: nextInheritance(from: state, memories: memories, previous: previous).soulPoints
                - previous.soulPoints,
            talent: state.talent,
            awakenings: state.selectedAwakenings,
            karmas: state.karmas,
            harshness: state.difficulty.careerHarshness.rawValue,
            schoolStrength: state.school.map { HighSchoolPresentation.focus($0.strength) },
            nicknames: nicknames.isEmpty ? nil : nicknames.map(\.title),
            chronicle: chronicle.isEmpty ? nil : chronicle.map { "\($0.stage) — \($0.text)" },
            personality: personality?.title
        )
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
        // 코어의 legacyRewardPermille는 이미 1000(×1.0)을 포함한 배율이다. 여기서 1000을
        // 또 더하면 카르마 없이 ×2.0이 되고, 화면의 "+35%"가 실제로는 절반만 전달된다.
        let rewarded = base * max(1_000, state.legacyRewardPermille) / 1_000
        return Inheritance(
            lifeNumber: previous.lifeNumber + 1,
            memories: memories,
            soulPoints: previous.soulPoints + rewarded,
            karmas: previous.karmas
        )
    }

    // MARK: - 프로 커리어의 계승

    /// 은퇴한 프로 커리어를 다음 회차의 야구혼으로 접는다.
    ///
    /// 예전에는 15년 명예의 전당 커리어도 계승에 0을 남겼다 — 환생 루프가 고교 스냅숏만
    /// 읽어서, 드래프트 직후 바로 접은 회차와 전설로 은퇴한 회차가 다음 회차에서 완전히
    /// 같았다. 프로에서의 시간이 환생과 아무 관계가 없으면, 게임의 후반 전체가 루프
    /// 바깥에 있게 된다.
    func recordProLegacy(_ state: ProCareerSnapshot?) {
        guard let state, inheritance.creditedProCareerID != state.proCareerID else { return }
        inheritance.creditedProCareerID = state.proCareerID
        inheritance.soulPoints += Self.proSoulBonus(for: state)
        save()
    }

    /// 프로 커리어가 남기는 야구혼. 스펙(메타 계승)의 프로 스케일을 따른다:
    /// 짧은 2군 커리어 ~30, 평범한 1군 커리어 ~80~120, 전설(12시즌·수상 다수·명전) ~220+.
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

    func acknowledgeBloom() {
        pendingBloom = nil
    }

    // MARK: - 저장

    /// 회차를 넘어 단조 증가하는 저장 리비전. 진행(result)이 없는 계승-전용 레코드도
    /// 이 값으로 충돌 판정을 이겨야, 오래된 iCloud 사본이 방금 끝난 회차를 되살리지 않는다.
    private var savedRevision: UInt64 = 0

    func save() {
        // 진행이 없어도 계승분과 아카이브는 쓴다. 이게 없으면 회차 사이(기억 확정 후 ~
        // 새 선수 생성 전)에 앱이 내려갈 때 환생 진행 전체가 사라진다.
        savedRevision = max(savedRevision + 1, result?.snapshot.revision ?? 0)
        let record = SaveRecord(result: result, inheritance: inheritance, archive: archive, enteredProCareerID: enteredProCareerID, nicknames: nicknames.isEmpty ? nil : nicknames, chronicle: chronicle.isEmpty ? nil : chronicle, chapterStartStrikeouts: chapterStartStrikeouts, goalCelebratedChapter: goalCelebratedChapter, responseTally: responseTally, revision: savedRevision)
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
        /// 계승-전용 레코드의 충돌 판정용. 없는 옛 저장본은 진행의 리비전으로 판정한다.
        var revision: UInt64?

        var effectiveRevision: UInt64 {
            max(revision ?? 0, result?.snapshot.revision ?? 0)
        }
    }

    private func restore() -> Bool {
        guard let data = sync.read(revision: { data in
            (try? JSONDecoder().decode(SaveRecord.self, from: data))?.effectiveRevision
        }) else { return false }
        guard let record = try? JSONDecoder().decode(SaveRecord.self, from: data) else { return false }
        inheritance = record.inheritance
        archive = record.archive ?? []
        enteredProCareerID = record.enteredProCareerID
        nicknames = record.nicknames ?? []
        chronicle = record.chronicle ?? []
        chapterStartStrikeouts = record.chapterStartStrikeouts
            ?? record.result?.snapshot.performance.strikeouts ?? 0
        goalCelebratedChapter = record.goalCelebratedChapter
        responseTally = record.responseTally ?? ResponseTally()
        savedRevision = record.effectiveRevision
        // 진행이 없는 레코드는 "회차 사이"다 — 계승분만 안고 새 선수 만들기로 간다.
        guard let saved = record.result else { return false }
        result = saved
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
            // 이번 동작에서 새로 만개했는가. 훈련 번호가 바뀐 것만 센다 — 안 그러면 같은
            // 훈련 결과를 들고 있는 동안 화면을 넘길 때마다 축하가 다시 뜬다.
            if let training = updated.snapshot.lastTraining,
               training.number != before.lastTraining?.number,
               let ability = training.bloomedAbility, let grade = training.bloomedGrade {
                pendingBloom = Bloom(ability: ability, grade: grade)
                chronicle.append(ChronicleEntry(
                    stage: "\(updated.snapshot.chapter.schoolYear)학년 \(updated.snapshot.chapter.season)",
                    text: "만개 — 막혀 있던 \(ability.label) 재능이 \(grade.label)까지 열렸습니다."
                ))
            }
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
            // 코어의 결과 문구 앞에 "그 사람이 어떻게 반응했는지"를 한 줄 붙인다.
            //
            // 예전에는 응답을 누르면 결과 요약 한 줄로 끝났다. 포수가 어떻게 반응했는지가
            // 없으니 관계가 숫자(팀의 믿음 60)로만 존재했다(품질 평가 §4.3).
            let speaker: RelationshipVoiceCatalog.Speaker
            switch relationship.category {
            case "coach": speaker = .coach
            case "catcher": speaker = .catcher
            case "rival": speaker = .rival
            default: speaker = .named("상대")
            }
            let aftermath = RelationshipVoiceCatalog.aftermath(
                speaker: speaker,
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
