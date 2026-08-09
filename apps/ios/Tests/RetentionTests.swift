import XCTest
import SimulationCore
@testable import BaseballIOS

/// 손맛·소리·업적·환생 계승의 순수 판정을 지킨다. 모두 엔진/Game Center 없이 돈다.
final class RetentionTests: XCTestCase {

    // MARK: - 투구 제스처

    /// 미터 한가운데 + 중심 조준이 만점이어야 한다.
    /// 재시도 시드는 반드시 숫자 문자열이어야 한다 — 커널 validate가 UInt64 파싱을
    /// 요구하므로 접미사가 붙는 순간 튜토리얼이 100% 빨간 오류 카드가 된다(3차 패널 P0).
    @MainActor
    func testBullpenRetryProducesAPlayableSession() throws {
        let store = HighSchoolCareerStore()
        store.startCareer(preset: PitcherPresetCatalog.all[0], playerName: "회귀 테스트")
        guard store.result != nil else { throw XCTSkip("커리어 시작 실패 — 환경 문제") }
        store.beginTutorialPitch()
        for _ in 0..<3 {
            store.retryTutorialPitch()
            guard let session = store.tutorialSession else {
                return XCTFail("재시도 후 세션이 없습니다")
            }
            if case .failed(let message) = session.stage {
                XCTFail("재시도 세션이 죽었습니다: \(message)")
            }
            XCTAssertNotNil(UInt64(session.seed), "재시도 시드가 숫자가 아닙니다: \(session.seed)")
        }
    }

    /// 삭제는 묘비를 남겨야 한다 — clear()만 하면 iCloud 결국적 일관성이
    /// 옛 사본을 되살린다("모든 진행 삭제가 가끔 안 먹힘"의 원인).
    @MainActor
    func testDeleteCareerWritesTombstoneThatSurvivesReload() throws {
        let store = HighSchoolCareerStore()
        store.startCareer(preset: PitcherPresetCatalog.all[0], playerName: "삭제 테스트")
        guard store.result != nil else { throw XCTSkip("커리어 시작 실패 — 환경 문제") }
        store.deleteCareer()
        XCTAssertNil(store.lastSetup, "삭제 후에도 빠른 환생 카드 재료가 남아 있습니다")
        let reloaded = HighSchoolCareerStore()
        reloaded.restoreOrCreate()
        XCTAssertNil(reloaded.result, "삭제 후 재실행에서 진행이 되살아났습니다")
        // 로드 마이그레이션이 soulTotalEarned를 0으로 채우므로 필드 단위로 비교한다.
        XCTAssertEqual(reloaded.inheritance.lifeNumber, 1, "회차가 초기화되지 않았습니다")
        XCTAssertEqual(reloaded.inheritance.soulPoints, 0, "야구혼이 초기화되지 않았습니다")
        XCTAssertTrue(reloaded.inheritance.memories.isEmpty, "기억이 초기화되지 않았습니다")
        XCTAssertTrue(reloaded.archive.isEmpty, "아카이브가 초기화되지 않았습니다")
    }

    /// 도전 런 격리 — 회차가 **같아도** 도전으로 판별되고(1회차 카드→1회차 유저가
    /// 최빈 공유 경로), confirmLegacy가 계승·아카이브를 건드리지 못한다(5차 패널 P0).
    @MainActor
    func testChallengeRunIsIsolatedFromLegacyAndArchive() throws {
        let store = HighSchoolCareerStore()
        store.deleteCareer()
        store.startCareer(preset: PitcherPresetCatalog.all[0], playerName: "도전자",
                          seedOverride: "424242", challengeLifeNumber: 1)
        guard store.result != nil else { throw XCTSkip("커리어 시작 실패 — 환경 문제") }
        XCTAssertTrue(store.isChallengeRun, "회차가 같아도 도전 런으로 판별돼야 합니다")
        let inheritanceBefore = store.inheritance
        let archiveBefore = store.archive
        store.confirmLegacy()
        XCTAssertNil(store.result, "도전 런의 confirmLegacy는 즉시 닫혀야 합니다")
        XCTAssertEqual(store.inheritance, inheritanceBefore, "도전 런이 계승을 덮었습니다")
        XCTAssertEqual(store.archive, archiveBefore, "도전 런이 아카이브를 덮었습니다")
        XCTAssertFalse(store.isChallengeRun, "닫힌 뒤에도 플래그가 남아 있습니다")
    }

    /// 이미 대표 유산을 해금한 계정도 기록 없는 도전에서는 같은 맨몸 조건으로 시작한다.
    @MainActor
    func testChallengeRunIgnoresEquippedSignatureLegacyAndItsAnalytics() throws {
        let sync = SaveSync(key: "challenge-signature-\(UUID().uuidString).json")
        defer {
            sync.clear()
            GameAnalytics.eventSinkForTesting = nil
        }
        let legacy = CareerSignatureLegacy.definition(for: .powerImprint)
        var inheritance = HighSchoolCareerStore.Inheritance.firstLife
        inheritance.lifeNumber = 2
        inheritance.equippedSignatureLegacyID = legacy.id
        inheritance.unlockedSignatureLegacies = [legacy]
        let saveRecord = HighSchoolCareerStore.SaveRecord(
            result: nil,
            inheritance: inheritance,
            archive: [],
            revision: 1
        )
        XCTAssertTrue(sync.write(try JSONEncoder().encode(saveRecord)))

        let store = HighSchoolCareerStore(sync: sync)
        store.restoreOrCreate()
        XCTAssertEqual(store.inheritance.equippedSignatureLegacyID, legacy.id)
        var events: [GameAnalytics.Event] = []
        GameAnalytics.eventSinkForTesting = { event, _ in events.append(event) }

        let preset = PitcherPresetCatalog.all[0]
        store.startCareer(
            preset: preset,
            playerName: "도전자",
            signatureLegacyID: legacy.id,
            seedOverride: "424242",
            challengeLifeNumber: 2
        )
        let identity = PlayerIdentitySnapshot(
            name: "도전자",
            throwingHand: preset.pitcher.throwingHand,
            bodyType: .balanced,
            region: "서울"
        )
        let bare = try HighSchoolCareerEngine().start(
            .init(seed: "424242", presetID: preset.id, lifeNumber: 2, identity: identity)
        )

        XCTAssertTrue(store.isChallengeRun)
        XCTAssertEqual(store.state?.pitcher, bare.snapshot.pitcher)
        XCTAssertNil(store.signatureLegacyRulesVersion)
        XCTAssertFalse(store.usesSignatureLegacyRules)
        XCTAssertFalse(events.contains(.signatureLegacyEquipped))
    }

    /// 로컬 원본을 쓰지 못한 시작은 활성화·환생 이벤트를 성공처럼 내보내지 않는다.
    @MainActor
    func testFailedStartSaveDoesNotEmitDurableSuccessEvents() {
        let sync = SaveSync(key: "missing-\(UUID().uuidString)/career.json")
        let store = HighSchoolCareerStore(sync: sync)
        var events: [GameAnalytics.Event] = []
        GameAnalytics.eventSinkForTesting = { event, _ in events.append(event) }
        defer { GameAnalytics.eventSinkForTesting = nil }

        store.startCareer(
            preset: PitcherPresetCatalog.all[0],
            playerName: "저장 경계",
            seedOverride: "808080"
        )

        XCTAssertNil(store.result)
        if case .failed = store.loadState {} else {
            XCTFail("저장 실패가 성공 화면으로 진행되면 안 됩니다.")
        }
        XCTAssertFalse(events.contains(.onboardingCompleted))
        XCTAssertFalse(events.contains(.rebirthStarted))
        XCTAssertFalse(events.contains(.signatureLegacyEquipped))
    }

    /// 결말 계산이 성공해도 로컬 원본 저장이 실패하면 계승·아카이브·완료 이벤트를 확정하지 않는다.
    @MainActor
    func testFailedLegacySaveRollsBackSettlementAndSuccessEvents() throws {
        let directoryName = "legacy-save-failure-\(UUID().uuidString)"
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = root.appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
            GameAnalytics.eventSinkForTesting = nil
        }
        let sync = SaveSync(key: "\(directoryName)/career.json")
        let legacyResult = try Self.completedCareerAtLegacy(seed: "606060")
        let record = HighSchoolCareerStore.SaveRecord(
            result: legacyResult,
            inheritance: .firstLife,
            archive: [],
            careerStartingPitcher: legacyResult.snapshot.pitcher,
            signatureLegacyRulesVersion: CareerSignatureLegacyRulesVersion.current.rawValue,
            revision: legacyResult.snapshot.revision
        )
        XCTAssertTrue(sync.write(try JSONEncoder().encode(record)))
        let store = HighSchoolCareerStore(sync: sync)
        store.restoreOrCreate()
        XCTAssertEqual(store.state?.phase, .legacy)
        store.selectedMemories = Array(legacyResult.snapshot.legacyOptions.prefix(
            legacyResult.snapshot.memorySlots
        ))
        store.prepareSignatureLegacyCandidates()
        let candidate = try XCTUnwrap(store.signatureLegacyCandidates(for: legacyResult.snapshot).first)
        store.selectSignatureLegacy(candidate.id)

        let inheritanceBefore = store.inheritance
        let archiveBefore = store.archive
        let revisionBefore = store.state?.revision
        let memoriesBefore = store.selectedMemories
        var events: [GameAnalytics.Event] = []
        GameAnalytics.eventSinkForTesting = { event, _ in events.append(event) }
        try FileManager.default.removeItem(at: directory)

        store.confirmLegacy()

        XCTAssertEqual(store.state?.phase, .legacy)
        XCTAssertEqual(store.state?.revision, revisionBefore)
        XCTAssertEqual(store.inheritance, inheritanceBefore)
        XCTAssertEqual(store.archive, archiveBefore)
        XCTAssertEqual(store.selectedMemories, memoriesBefore)
        XCTAssertEqual(store.selectedSignatureLegacyID, candidate.id)
        XCTAssertNil(store.pendingRecap)
        XCTAssertFalse(events.contains(.runPledgeResolved))
        XCTAssertFalse(events.contains(.signatureLegacySelected))
        XCTAssertFalse(events.contains(.lifeCompleted))
    }

    /// 기능 도입 전에 시작한 진행은 결말에서 새 대표 유산 선택을 강제하지 않는다.
    @MainActor
    func testPreFeatureCareerFinishesWithOriginalMemoryRules() throws {
        let sync = SaveSync(key: "pre-signature-bridge-\(UUID().uuidString).json")
        defer {
            sync.clear()
            GameAnalytics.eventSinkForTesting = nil
        }
        let legacyResult = try Self.completedCareerAtLegacy(seed: "606061")
        let record = HighSchoolCareerStore.SaveRecord(
            result: legacyResult,
            inheritance: .firstLife,
            archive: [],
            careerStartingPitcher: nil,
            signatureLegacyRulesVersion: nil,
            revision: legacyResult.snapshot.revision
        )
        XCTAssertTrue(sync.write(try JSONEncoder().encode(record)))
        let store = HighSchoolCareerStore(sync: sync)
        store.restoreOrCreate()
        XCTAssertFalse(store.usesSignatureLegacyRules)
        store.selectedMemories = Array(legacyResult.snapshot.legacyOptions.prefix(
            legacyResult.snapshot.memorySlots
        ))
        var events: [GameAnalytics.Event] = []
        GameAnalytics.eventSinkForTesting = { event, _ in events.append(event) }

        store.confirmLegacy()

        XCTAssertEqual(store.state?.phase, .completed)
        XCTAssertNil(store.pendingRecap?.record.signatureLegacy)
        XCTAssertNil(store.archive.first?.signatureLegacy)
        XCTAssertFalse(events.contains(.signatureLegacySelected))
        XCTAssertTrue(events.contains(.lifeCompleted))
    }

    /// 새 규칙에서는 세 후보를 발견하되 직접 계승은 대표 유산 하나뿐이다.
    /// 과거 기억 카드가 활성 저장에 남아 있어도 새 정산에 겹쳐 적용하지 않는다.
    @MainActor
    func testCurrentCareerFinishesWithOneSignatureLegacyAndNoMemoryStack() throws {
        let sync = SaveSync(key: "single-signature-\(UUID().uuidString).json")
        defer {
            sync.clear()
            GameAnalytics.eventSinkForTesting = nil
        }
        let legacyResult = try Self.completedCareerAtLegacy(seed: "606062")
        let record = HighSchoolCareerStore.SaveRecord(
            result: legacyResult,
            inheritance: .firstLife,
            archive: [],
            careerStartingPitcher: legacyResult.snapshot.pitcher,
            signatureLegacyRulesVersion: CareerSignatureLegacyRulesVersion.current.rawValue,
            revision: legacyResult.snapshot.revision
        )
        XCTAssertTrue(sync.write(try JSONEncoder().encode(record)))
        let store = HighSchoolCareerStore(sync: sync)
        store.restoreOrCreate()
        store.selectedMemories = Array(legacyResult.snapshot.legacyOptions.prefix(
            legacyResult.snapshot.memorySlots
        ))
        store.prepareSignatureLegacyCandidates()
        let candidates = store.signatureLegacyCandidates(for: legacyResult.snapshot)
        XCTAssertEqual(candidates.count, 3)
        let selected = try XCTUnwrap(candidates.first)
        store.selectSignatureLegacy(selected.id)
        var events: [GameAnalytics.Event] = []
        GameAnalytics.eventSinkForTesting = { event, _ in events.append(event) }

        store.confirmLegacy()

        XCTAssertEqual(store.state?.phase, .completed)
        XCTAssertEqual(store.state?.selectedMemories, [])
        XCTAssertTrue(store.inheritance.memories.isEmpty)
        XCTAssertEqual(store.inheritance.equippedSignatureLegacyID, selected.id)
        XCTAssertEqual(
            Set((store.inheritance.unlockedSignatureLegacies ?? []).map(\.id)),
            Set(candidates.map(\.id))
        )
        XCTAssertEqual(store.archive.first?.signatureLegacy?.id, selected.id)
        XCTAssertEqual(store.archive.first?.signatureLegacyCandidates?.map(\.id), candidates.map(\.id))
        XCTAssertTrue(events.contains(.signatureLegacySelected))
        XCTAssertTrue(events.contains(.lifeCompleted))
    }

    /// 정상 회차는 어떤 시점에도 도전 런으로 오판되면 안 된다 — 파생 판별의 재발 방지.
    @MainActor
    func testNormalRunNeverBecomesChallengeRun() throws {
        let store = HighSchoolCareerStore()
        store.deleteCareer()
        store.startCareer(preset: PitcherPresetCatalog.all[0], playerName: "일반 회차")
        guard store.result != nil else { throw XCTSkip("커리어 시작 실패 — 환경 문제") }
        XCTAssertFalse(store.isChallengeRun)
    }

    /// 프로 생성에 성공한 고교 선수의 영수증은 프로 저장본을 지운 뒤에도 남는다.
    @MainActor
    func testEnteredProReceiptPersistsOnTheHighSchoolCareer() throws {
        let sync = SaveSync(key: "entered-pro-\(UUID().uuidString).json")
        defer { sync.clear() }
        let snapshot = Self.highSchoolSnapshot(
            strikeouts: 8,
            walks: 1,
            runsAllowed: 2,
            rewardPermille: 1_000,
            phase: .completed,
            drafted: true
        )
        let result = HighSchoolCareerResult(
            revision: snapshot.revision,
            nextSeed: "99020",
            events: [],
            snapshot: snapshot,
            eventHash: "entered-pro-fixture"
        )
        XCTAssertTrue(sync.write(try JSONEncoder().encode(
            HighSchoolCareerStore.SaveRecord(
                result: result,
                inheritance: .firstLife,
                archive: [],
                revision: snapshot.revision
            )
        )))
        let store = HighSchoolCareerStore(sync: sync)
        store.restoreOrCreate()

        XCTAssertTrue(store.markEnteredPro())
        XCTAssertTrue(store.hasEnteredPro)

        let reloaded = HighSchoolCareerStore(sync: sync)
        reloaded.restoreOrCreate()
        XCTAssertTrue(reloaded.hasEnteredPro)
        XCTAssertEqual(reloaded.enteredProCareerID, snapshot.careerID)
    }

    /// 엔진이 stale/invalid legacy 입력을 거부하면 앱 정산도 원자적으로 멈춰야 한다.
    /// 예전에는 실패 뒤에도 약속 이벤트·야구혼·아카이브가 확정됐다.
    @MainActor
    func testFailedLegacySelectionDoesNotResolvePledgeOrMutateInheritanceAndArchive() throws {
        let sync = SaveSync(key: "failed-legacy-\(UUID().uuidString).json")
        sync.clear()
        let pledgeKey = "baseball.pledge.hs-test"
        UserDefaults.standard.removeObject(forKey: pledgeKey)
        defer {
            sync.clear()
            UserDefaults.standard.removeObject(forKey: pledgeKey)
            GameAnalytics.eventSinkForTesting = nil
        }
        let store = HighSchoolCareerStore(sync: sync)
        let snapshot = Self.highSchoolSnapshot(
            strikeouts: 5, walks: 0, runsAllowed: 0, rewardPermille: 1_000
        )
        store.result = HighSchoolCareerResult(
            revision: snapshot.revision,
            nextSeed: "99002",
            events: [],
            snapshot: snapshot,
            eventHash: "stale-legacy-fixture"
        )
        store.loadState = .ready
        store.choosePledge("get_drafted")
        store.selectedSignatureLegacyID = store.signatureLegacyCandidates(for: snapshot).first?.id
        // Count is valid, but neither card is in this stale snapshot's empty offered list.
        store.selectedMemories = [.coachLetter, .recoveryRoutine]
        let inheritanceBefore = store.inheritance
        let archiveBefore = store.archive
        let revisionBefore = store.state?.revision
        var events: [GameAnalytics.Event] = []
        GameAnalytics.eventSinkForTesting = { event, _ in events.append(event) }

        store.confirmLegacy()

        XCTAssertEqual(store.state?.revision, revisionBefore)
        XCTAssertEqual(store.inheritance, inheritanceBefore)
        XCTAssertEqual(store.archive, archiveBefore)
        XCTAssertNil(store.pendingRecap)
        XCTAssertFalse(events.contains(.runPledgeResolved))
        XCTAssertFalse(events.contains(.signatureLegacySelected))
        XCTAssertFalse(events.contains(.lifeCompleted))
        if case .failed = store.loadState {} else {
            XCTFail("stale legacy 선택은 실패 상태여야 합니다.")
        }
    }

    /// A stale/invalid high-school game must not consume a positive review moment or emit a
    /// completion event merely because a local PitchSession produced a report.
    @MainActor
    func testFailedHighSchoolGameSettlementHasNoCompletionSideEffects() throws {
        let sync = SaveSync(key: "failed-high-school-game-\(UUID().uuidString).json")
        let weeklySync = SaveSync(key: "failed-high-school-game-weekly-\(UUID().uuidString).json")
        let rivalKey = "baseball.rivalLedger.hs-test"
        sync.clear()
        weeklySync.clear()
        UserDefaults.standard.removeObject(forKey: rivalKey)
        ReviewPrompt.reset()
        defer {
            sync.clear()
            weeklySync.clear()
            UserDefaults.standard.removeObject(forKey: rivalKey)
            ReviewPrompt.reset()
            GameAnalytics.eventSinkForTesting = nil
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let weekly = WeeklyProgramStore(sync: weeklySync, stableUserID: "failed-high-school-game")
        weekly.configure(
            eligibility: .init(
                hasHighSchoolCareer: true,
                remainingImportantGames: 5,
                remainingChapterAdvances: 7,
                dailyInningUnlocked: true,
                canStartNextRun: false,
                canSelectPledge: false,
                canChooseDifferentSchool: false,
                hasProCareer: false
            ),
            now: ISO8601DateFormatter().date(from: "2026-08-05T12:00:00Z")!,
            calendar: calendar
        )
        let weeklyBefore = weekly.program
        let store = HighSchoolCareerStore(sync: sync, weekly: weekly)
        let snapshot = Self.highSchoolSnapshot(
            strikeouts: 0, walks: 0, runsAllowed: 0, rewardPermille: 1_000
        )
        store.result = HighSchoolCareerResult(
            revision: snapshot.revision,
            nextSeed: "99003",
            events: [],
            snapshot: snapshot,
            eventHash: "stale-game-fixture"
        )
        store.loadState = .ready
        let session = PitchSession(highSchool: snapshot, seed: "99004")
        session.start()
        for _ in 0..<20 where session.rivalOutcomes.isEmpty {
            guard case .ready = session.stage else { break }
            session.throwPitch()
        }
        XCTAssertFalse(session.rivalOutcomes.isEmpty, "숙적 원장 불변을 검증할 타석 결과가 필요합니다.")
        store.pitchSession = session
        let revisionBefore = store.state?.revision
        let reviewBefore = store.reviewMoment
        let achievementBefore = AchievementStore.shared.progress
        let freshAchievementsBefore = AchievementStore.shared.freshlyUnlocked
        let rivalBefore = store.rivalLedger
        var events: [GameAnalytics.Event] = []
        GameAnalytics.eventSinkForTesting = { event, _ in events.append(event) }

        store.finishImportantGame()

        XCTAssertEqual(store.state?.revision, revisionBefore)
        XCTAssertNil(store.pitchSession, "실패한 이닝의 기존 폐기 정책은 유지합니다.")
        XCTAssertEqual(store.reviewMoment, reviewBefore)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: ReviewPrompt.Reason.cleanInning.key))
        XCTAssertEqual(AchievementStore.shared.progress, achievementBefore)
        XCTAssertEqual(AchievementStore.shared.freshlyUnlocked, freshAchievementsBefore)
        XCTAssertEqual(store.rivalLedger, rivalBefore)
        XCTAssertEqual(weekly.program, weeklyBefore)
        XCTAssertFalse(events.contains(.gameFinished))
        if case .failed = store.loadState {} else {
            XCTFail("잘못된 고교 국면의 경기 정산은 실패 상태여야 합니다.")
        }
    }

    @MainActor
    func testHighSchoolImportantGameSaveFailuresRollbackAndRetryExactlyOnce() throws {
        let sync = SaveSync(key: "hs-game-atomic-\(UUID().uuidString).json")
        let weeklySync = SaveSync(key: "hs-game-atomic-weekly-\(UUID().uuidString).json")
        sync.clear()
        weeklySync.clear()
        defer {
            sync.clear()
            weeklySync.clear()
            GameAnalytics.eventSinkForTesting = nil
        }
        // game_finished uses a per-game durable once key; isolate the career ID so rerunning this
        // test in the same simulator cannot inherit a prior invocation's analytics receipt.
        let initial = try Self.careerResult(
            seed: String(UInt64.random(in: 1...UInt64.max)), at: .importantGame
        )
        XCTAssertTrue(sync.write(try JSONEncoder().encode(
            HighSchoolCareerStore.SaveRecord(
                result: initial,
                inheritance: .firstLife,
                archive: [],
                revision: initial.snapshot.revision
            )
        )))
        let eligibility = WeeklyProgramEligibility(
            hasHighSchoolCareer: true,
            remainingImportantGames: 6,
            remainingChapterAdvances: 7,
            dailyInningUnlocked: true,
            canStartNextRun: false,
            canSelectPledge: false,
            canChooseDifferentSchool: false,
            hasProCareer: false
        )
        let now = Date()
        let moment = try XCTUnwrap(WeeklyProgramMoment.resolve(date: now, calendar: .current))
        let weeklyUser = try XCTUnwrap((0..<200).lazy.map { "hs-game-atomic-\($0)" }.first { id in
            WeeklyProgramRules.make(
                weekKey: moment.weekKey, stableUserID: id, eligibility: eligibility
            )?.tasks.contains(where: { $0.kind == .importantGamesCompleted }) == true
        })
        let weekly = WeeklyProgramStore(sync: weeklySync, stableUserID: weeklyUser)
        XCTAssertTrue(weekly.configure(eligibility: eligibility, now: now, calendar: .current))
        let weeklyBefore = weekly.program
        var writeFails = false
        let store = HighSchoolCareerStore(
            sync: sync,
            weekly: weekly,
            saveWriter: { data in writeFails ? false : sync.write(data) }
        )
        store.restoreOrCreate()
        let originalSeed = try XCTUnwrap(store.result?.nextSeed)

        writeFails = true
        store.beginImportantGame()
        XCTAssertEqual(store.result?.nextSeed, originalSeed)
        XCTAssertNil(store.pitchSession)

        writeFails = false
        store.beginImportantGame()
        let session = try XCTUnwrap(store.pitchSession)
        XCTAssertNotEqual(store.result?.nextSeed, originalSeed)

        // The first plate-appearance checkpoint fails: memory and the durable record must still
        // point at the previously committed start until the exact same checkpoint is retried.
        writeFails = true
        try Self.throwUntilCheckpoint(session)
        let checkpoint = try XCTUnwrap(session.resumeState())
        let beforeCheckpointRetry = HighSchoolCareerStore(sync: sync)
        beforeCheckpointRetry.restoreOrCreate()
        XCTAssertNil(beforeCheckpointRetry.pitchSession)

        writeFails = false
        session.onCheckpoint?(session)
        let afterCheckpointRetry = HighSchoolCareerStore(sync: sync)
        afterCheckpointRetry.restoreOrCreate()
        XCTAssertEqual(afterCheckpointRetry.pitchSession?.resumeState(), checkpoint)

        try Self.finish(session)
        let resultBeforeFinish = store.result
        let sessionBeforeFinish = session.resumeState()
        let rivalBeforeFinish = store.rivalLedger
        let achievementsBefore = AchievementStore.shared.progress
        var events: [GameAnalytics.Event] = []
        GameAnalytics.eventSinkForTesting = { event, _ in events.append(event) }

        writeFails = true
        store.finishImportantGame()
        XCTAssertEqual(store.result?.snapshot.revision, resultBeforeFinish?.snapshot.revision)
        XCTAssertEqual(store.result?.nextSeed, resultBeforeFinish?.nextSeed)
        XCTAssertTrue(store.pitchSession === session)
        XCTAssertEqual(store.pitchSession?.resumeState(), sessionBeforeFinish)
        XCTAssertEqual(weekly.program, weeklyBefore)
        XCTAssertEqual(AchievementStore.shared.progress, achievementsBefore)
        XCTAssertEqual(events.filter { $0 == .gameFinished }.count, 0)

        writeFails = false
        store.finishImportantGame()
        XCTAssertNil(store.pitchSession)
        XCTAssertGreaterThan(
            try XCTUnwrap(store.result?.snapshot.revision),
            try XCTUnwrap(resultBeforeFinish?.snapshot.revision)
        )
        XCTAssertEqual(events.filter { $0 == .gameFinished }.count, 1)
        XCTAssertEqual(
            weekly.program?.tasks.first(where: { $0.kind == .importantGamesCompleted })?.progress,
            1
        )
        XCTAssertEqual(
            store.rivalLedger.plateAppearances,
            rivalBeforeFinish.plateAppearances + session.rivalOutcomes.count
        )
        XCTAssertEqual(
            store.rivalLedger.strikeouts,
            rivalBeforeFinish.strikeouts + session.rivalOutcomes.filter { $0 == .strikeout }.count
        )
        let rivalAfterFinish = store.rivalLedger
        store.finishImportantGame()
        XCTAssertEqual(events.filter { $0 == .gameFinished }.count, 1)
        XCTAssertEqual(store.rivalLedger, rivalAfterFinish)
    }

    /// 코어 결과를 먼저 저장한 직후 앱이 종료돼도 숙적·연대기 같은 로컬 정산과
    /// 주간/분석/업적 후속 작업이 사라지거나 두 번 적용되면 안 된다.
    @MainActor
    func testHighSchoolGameCompletionReceiptDrainsOnceAfterRestart() throws {
        let token = UUID().uuidString
        let sync = SaveSync(key: "hs-game-receipt-\(token).json")
        let weeklySync = SaveSync(key: "hs-game-receipt-weekly-\(token).json")
        let outboxSync = SaveSync(key: "hs-game-receipt-outbox-\(token).json")
        sync.clear()
        weeklySync.clear()
        outboxSync.clear()
        ReviewPrompt.reset()
        defer {
            sync.clear()
            weeklySync.clear()
            outboxSync.clear()
            ReviewPrompt.reset()
            GameAnalytics.eventSinkForTesting = nil
        }

        let seed = String(UInt64.random(in: 1...UInt64.max))
        let initial = try Self.careerResult(seed: seed, at: .importantGame)
        XCTAssertTrue(sync.write(try JSONEncoder().encode(
            HighSchoolCareerStore.SaveRecord(
                result: initial,
                inheritance: .firstLife,
                archive: [],
                revision: initial.snapshot.revision
            )
        )))
        let eligibility = WeeklyProgramEligibility(
            hasHighSchoolCareer: true,
            remainingImportantGames: 6,
            remainingChapterAdvances: 7,
            dailyInningUnlocked: true,
            canStartNextRun: false,
            canSelectPledge: false,
            canChooseDifferentSchool: false,
            hasProCareer: false
        )
        let now = Date()
        let moment = try XCTUnwrap(WeeklyProgramMoment.resolve(date: now, calendar: .current))
        let weeklyUser = try XCTUnwrap((0..<500).lazy.map { "hs-receipt-\($0)" }.first { id in
            let kinds = Set(WeeklyProgramRules.make(
                weekKey: moment.weekKey, stableUserID: id, eligibility: eligibility
            )?.tasks.map(\.kind) ?? [])
            return kinds.contains(.importantGamesCompleted)
                && kinds.contains(.sequenceMasteryTriggered)
        })
        var weeklyWriteFails = false
        var outboxWriteFails = false
        let weekly = WeeklyProgramStore(
            sync: weeklySync,
            stableUserID: weeklyUser,
            saveWriter: { data in weeklyWriteFails ? false : weeklySync.write(data) },
            outboxSync: outboxSync,
            outboxWriter: { data in outboxWriteFails ? false : outboxSync.write(data) }
        )
        XCTAssertTrue(weekly.configure(eligibility: eligibility, now: now, calendar: .current))
        let weeklyBefore = weekly.program
        let store = HighSchoolCareerStore(sync: sync, weekly: weekly)
        store.restoreOrCreate()
        store.beginImportantGame()
        let session = try XCTUnwrap(store.pitchSession)
        try Self.finish(session)
        let rivalOutcomes = session.rivalOutcomes
        let chronicleCountBefore = store.chronicle.count
        var events: [GameAnalytics.Event] = []
        GameAnalytics.eventSinkForTesting = { event, _ in events.append(event) }

        // The core/local candidate write succeeds, while both weekly durable media fail.
        // This models termination immediately after the first SaveRecord commit.
        weeklyWriteFails = true
        outboxWriteFails = true
        store.finishImportantGame()

        XCTAssertNil(store.pitchSession)
        XCTAssertNotNil(store.pendingGameCompletion)
        XCTAssertGreaterThan(store.chronicle.count, chronicleCountBefore)
        XCTAssertEqual(store.rivalLedger.plateAppearances, rivalOutcomes.count)
        XCTAssertEqual(weekly.program, weeklyBefore)
        XCTAssertEqual(events.filter { $0 == .gameFinished }.count, 0)

        // A process restart while storage is still unavailable retains the receipt and every
        // local candidate from the first commit.
        let interrupted = HighSchoolCareerStore(sync: sync, weekly: weekly)
        interrupted.restoreOrCreate()
        XCTAssertNotNil(interrupted.pendingGameCompletion)
        XCTAssertEqual(interrupted.chronicle, store.chronicle)
        XCTAssertEqual(interrupted.rivalLedger, store.rivalLedger)

        weeklyWriteFails = false
        outboxWriteFails = false
        let recoveredWeekly = WeeklyProgramStore(
            sync: weeklySync, stableUserID: weeklyUser, outboxSync: outboxSync
        )
        XCTAssertTrue(recoveredWeekly.configure(
            eligibility: eligibility, now: now, calendar: .current
        ))
        var receiptClearFails = true
        let recovered = HighSchoolCareerStore(
            sync: sync,
            weekly: recoveredWeekly,
            saveWriter: { data in
                guard let record = try? JSONDecoder().decode(
                    HighSchoolCareerStore.SaveRecord.self, from: data
                ) else { return false }
                if receiptClearFails, record.pendingGameCompletion == nil { return false }
                return sync.write(data)
            }
        )
        recovered.restoreOrCreate()

        XCTAssertNotNil(
            recovered.pendingGameCompletion,
            "후속 작업은 적용됐어도 receipt clear 저장 실패는 재시도 재료를 남겨야 합니다."
        )
        XCTAssertEqual(events.filter { $0 == .gameFinished }.count, 1)
        XCTAssertEqual(
            recoveredWeekly.program?.tasks.first(where: {
                $0.kind == .importantGamesCompleted
            })?.progress,
            1
        )
        let mastery = recovered.pendingGameCompletion?.report.sequenceMasteryCount
            ?? session.sequenceMasteryCount
        let recoveredSequenceTask = recoveredWeekly.program?.tasks.first(where: {
            $0.kind == .sequenceMasteryTriggered
        })
        XCTAssertEqual(
            recoveredSequenceTask?.progress,
            min(recoveredSequenceTask?.target ?? 0, mastery)
        )

        receiptClearFails = false
        XCTAssertTrue(recovered.retryPendingGameCompletion())
        XCTAssertNil(recovered.pendingGameCompletion)
        XCTAssertEqual(events.filter { $0 == .gameFinished }.count, 1)

        let weeklyAfterDrain = recoveredWeekly.program
        let achievementsAfterDrain = AchievementStore.shared.progress
        let secondRestart = HighSchoolCareerStore(sync: sync, weekly: recoveredWeekly)
        secondRestart.restoreOrCreate()
        XCTAssertNil(secondRestart.pendingGameCompletion)
        XCTAssertEqual(recoveredWeekly.program, weeklyAfterDrain)
        XCTAssertEqual(AchievementStore.shared.progress, achievementsAfterDrain)
        XCTAssertEqual(events.filter { $0 == .gameFinished }.count, 1)
    }

    @MainActor
    func testExpiredHighSchoolGameReceiptDoesNotLeakProgressIntoNewWeek() throws {
        let token = UUID().uuidString
        let sync = SaveSync(key: "hs-expired-game-receipt-\(token).json")
        let weeklySync = SaveSync(key: "hs-expired-game-weekly-\(token).json")
        sync.clear()
        weeklySync.clear()
        defer {
            sync.clear()
            weeklySync.clear()
            GameAnalytics.eventSinkForTesting = nil
        }
        let previousWeek = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-08-05T12:00:00Z")
        )
        let currentWeek = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-08-12T12:00:00Z")
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let eligibility = WeeklyProgramEligibility(
            hasHighSchoolCareer: true,
            remainingImportantGames: 6,
            remainingChapterAdvances: 7,
            dailyInningUnlocked: true,
            canStartNextRun: false,
            canSelectPledge: false,
            canChooseDifferentSchool: false,
            hasProCareer: false
        )
        let weekly = WeeklyProgramStore(
            sync: weeklySync, stableUserID: "hs-expired-receipt"
        )
        XCTAssertTrue(weekly.configure(
            eligibility: eligibility, now: currentWeek, calendar: calendar
        ))
        let weeklyBefore = weekly.program

        let before = try Self.careerResult(
            seed: String(UInt64.random(in: 1...UInt64.max)), at: .importantGame
        )
        let report = ImportantInningReport(
            scenarioNumber: before.snapshot.performance.importantGamesCompleted + 1,
            pitches: 12,
            strikeouts: 2,
            walks: 1,
            runsAllowed: 1,
            expectedDamage: 500,
            actualDamage: 400,
            recommendationAccepted: 4,
            outs: 2,
            sequenceMasteryCount: 2
        )
        let settled = try HighSchoolCareerEngine().recordImportantGame(.init(
            seed: before.nextSeed, state: before.snapshot, report: report
        ))
        let completion = HighSchoolCareerStore.PendingGameCompletion(
            id: "hs-game:\(settled.snapshot.careerID):expired:\(settled.snapshot.revision)",
            report: report,
            achievements: [],
            sequenceTags: ["speed_ladder"],
            recommendationAcceptanceRate: Double(report.recommendationAccepted)
                / Double(report.pitches),
            targetBatters: 4,
            batters: 4,
            lifeNumber: settled.snapshot.lifeNumber,
            actNumber: HighSchoolPresentation.actNumber(
                chapter: settled.snapshot.chapter.number
            ),
            chapterNumber: settled.snapshot.chapter.number,
            enteredPhase: settled.snapshot.phase != before.snapshot.phase
                ? settled.snapshot.phase.rawValue : nil,
            gameGrowth: CareerGameGrowth.evaluating(state: before.snapshot, report: report),
            shouldRequestCleanReview: false,
            completedAt: previousWeek
        )
        XCTAssertTrue(sync.write(try JSONEncoder().encode(
            HighSchoolCareerStore.SaveRecord(
                result: settled,
                inheritance: .firstLife,
                archive: [],
                pendingGameCompletion: completion,
                revision: settled.snapshot.revision
            )
        )))
        var events: [(GameAnalytics.Event, [String: Any])] = []
        GameAnalytics.eventSinkForTesting = { event, properties in
            events.append((event, properties))
        }

        let store = HighSchoolCareerStore(sync: sync, weekly: weekly)
        store.restoreOrCreate()

        XCTAssertNil(store.pendingGameCompletion)
        XCTAssertEqual(weekly.program, weeklyBefore)
        XCTAssertEqual(events.filter { $0.0 == .gameFinished }.count, 1)
        if let growth = completion.gameGrowth {
            XCTAssertEqual(
                events.first(where: { $0.0 == .gameGrowthApplied })?.1["reason_id"] as? String,
                growth.reason.rawValue
            )
        }
        if completion.enteredPhase != nil {
            XCTAssertEqual(
                events.first(where: { $0.0 == .phaseEntered })?.1["chapter"] as? Int,
                completion.chapterNumber
            )
        }
        let secondRestart = HighSchoolCareerStore(sync: sync, weekly: weekly)
        secondRestart.restoreOrCreate()
        XCTAssertEqual(weekly.program, weeklyBefore)
        XCTAssertEqual(events.filter { $0.0 == .gameFinished }.count, 1)
    }

    @MainActor
    func testHighSchoolAbandonSaveFailureKeepsSessionUntilRetry() throws {
        let sync = SaveSync(key: "hs-abandon-atomic-\(UUID().uuidString).json")
        sync.clear()
        defer {
            sync.clear()
            GameAnalytics.eventSinkForTesting = nil
        }
        let initial = try Self.careerResult(seed: "74002", at: .importantGame)
        XCTAssertTrue(sync.write(try JSONEncoder().encode(
            HighSchoolCareerStore.SaveRecord(
                result: initial, inheritance: .firstLife, archive: [],
                revision: initial.snapshot.revision
            )
        )))
        var writeFails = false
        let store = HighSchoolCareerStore(
            sync: sync,
            saveWriter: { data in writeFails ? false : sync.write(data) }
        )
        store.restoreOrCreate()
        store.beginImportantGame()
        let session = try XCTUnwrap(store.pitchSession)
        let resultBefore = store.result
        var events: [GameAnalytics.Event] = []
        GameAnalytics.eventSinkForTesting = { event, _ in events.append(event) }

        writeFails = true
        XCTAssertFalse(store.abandonImportantGame())
        XCTAssertTrue(store.pitchSession === session)
        XCTAssertEqual(store.result?.nextSeed, resultBefore?.nextSeed)
        XCTAssertEqual(events.filter { $0 == .gameAbandoned }.count, 0)

        writeFails = false
        XCTAssertTrue(store.abandonImportantGame())
        XCTAssertNil(store.pitchSession)
        XCTAssertEqual(events.filter { $0 == .gameAbandoned }.count, 1)
        XCTAssertFalse(store.abandonImportantGame())
        XCTAssertEqual(events.filter { $0 == .gameAbandoned }.count, 1)
    }

    @MainActor
    func testRelationshipTallyAndPersonalityCommitWithCoreResult() throws {
        let sync = SaveSync(key: "hs-relationship-atomic-\(UUID().uuidString).json")
        sync.clear()
        defer {
            sync.clear()
            GameAnalytics.eventSinkForTesting = nil
        }
        let initial = try Self.careerResult(seed: "74003", at: .relationship)
        XCTAssertTrue(sync.write(try JSONEncoder().encode(
            HighSchoolCareerStore.SaveRecord(
                result: initial, inheritance: .firstLife, archive: [],
                revision: initial.snapshot.revision
            )
        )))
        var writeFails = false
        let store = HighSchoolCareerStore(
            sync: sync,
            saveWriter: { data in writeFails ? false : sync.write(data) }
        )
        store.restoreOrCreate()
        let resultBefore = store.result
        let tallyBefore = store.responseTally
        let chronicleBefore = store.chronicle
        var events: [GameAnalytics.Event] = []
        GameAnalytics.eventSinkForTesting = { event, _ in events.append(event) }

        writeFails = true
        store.resolveRelationship(.listen)
        XCTAssertEqual(store.result?.snapshot.revision, resultBefore?.snapshot.revision)
        XCTAssertEqual(store.responseTally, tallyBefore)
        XCTAssertEqual(store.personality, tallyBefore.personality)
        XCTAssertEqual(store.chronicle, chronicleBefore)
        XCTAssertTrue(events.isEmpty)

        writeFails = false
        store.resolveRelationship(.listen)
        XCTAssertGreaterThan(store.result?.snapshot.revision ?? 0, resultBefore?.snapshot.revision ?? 0)
        XCTAssertEqual(store.responseTally.listen, tallyBefore.listen + 1)
        let reloaded = HighSchoolCareerStore(sync: sync)
        reloaded.restoreOrCreate()
        XCTAssertEqual(reloaded.responseTally, store.responseTally)
        XCTAssertEqual(reloaded.personality, store.personality)
        XCTAssertEqual(reloaded.chronicle, store.chronicle)
    }

    @MainActor
    func testDeleteCareerSaveFailurePreservesCareerAndAuxiliaryStateUntilRetry() throws {
        let sync = SaveSync(key: "hs-delete-atomic-\(UUID().uuidString).json")
        sync.clear()
        let defaults = UserDefaults.standard
        let previousLastSetup = defaults.data(forKey: "baseball.lastSetup")
        defer {
            sync.clear()
            if let previousLastSetup {
                defaults.set(previousLastSetup, forKey: "baseball.lastSetup")
            } else {
                defaults.removeObject(forKey: "baseball.lastSetup")
            }
        }
        var writeFails = false
        let store = HighSchoolCareerStore(
            sync: sync,
            saveWriter: { data in writeFails ? false : sync.write(data) }
        )
        store.startCareer(
            preset: PitcherPresetCatalog.all[0], playerName: "저장 경계",
            seedOverride: "74004"
        )
        let careerID = try XCTUnwrap(store.state?.careerID)
        let pledgeKey = "baseball.pledge.\(careerID)"
        let versionKey = "baseball.pledgeRulesVersion.\(careerID)"
        defaults.set("get_drafted", forKey: pledgeKey)
        defaults.set(RunPledge.currentRulesVersion, forKey: versionKey)
        defer {
            defaults.removeObject(forKey: pledgeKey)
            defaults.removeObject(forKey: versionKey)
        }
        let resultBefore = store.result
        let setupBefore = store.lastSetup

        writeFails = true
        XCTAssertFalse(store.deleteCareer())
        XCTAssertEqual(store.result?.snapshot.revision, resultBefore?.snapshot.revision)
        XCTAssertEqual(store.lastSetup, setupBefore)
        XCTAssertEqual(defaults.string(forKey: pledgeKey), "get_drafted")
        let stillDurable = HighSchoolCareerStore(sync: sync)
        stillDurable.restoreOrCreate()
        XCTAssertEqual(stillDurable.state?.careerID, careerID)

        writeFails = false
        XCTAssertTrue(store.deleteCareer())
        XCTAssertNil(store.result)
        XCTAssertNil(store.lastSetup)
        XCTAssertNil(defaults.object(forKey: pledgeKey))
        let deleted = HighSchoolCareerStore(sync: sync)
        deleted.restoreOrCreate()
        XCTAssertNil(deleted.result)
        XCTAssertEqual(deleted.loadState, .needsSetup)
    }

    @MainActor
    func testHighSchoolReloadAppliesHigherRemoteTombstoneWithoutResurrection() throws {
        let sync = SaveSync(key: "hs-remote-tombstone-\(UUID().uuidString).json")
        sync.clear()
        defer { sync.clear() }
        let live = try Self.careerResult(seed: "74005", at: .training)
        XCTAssertTrue(sync.write(try JSONEncoder().encode(
            HighSchoolCareerStore.SaveRecord(
                result: live,
                inheritance: .firstLife,
                archive: [],
                revision: live.snapshot.revision
            )
        )))
        let store = HighSchoolCareerStore(sync: sync)
        store.restoreOrCreate()
        XCTAssertEqual(store.state?.careerID, live.snapshot.careerID)
        XCTAssertEqual(store.loadState, .ready)
        let activeSession = PitchSession(highSchool: live.snapshot, seed: "74005-session")
        activeSession.start()
        store.pitchSession = activeSession
        XCTAssertNotNil(store.pitchSession)

        let tombstoneRevision = live.snapshot.revision + 1_000
        XCTAssertTrue(sync.write(try JSONEncoder().encode(
            HighSchoolCareerStore.SaveRecord(
                result: nil,
                inheritance: .firstLife,
                archive: [],
                revision: tombstoneRevision
            )
        )))

        store.reloadFromSync()

        XCTAssertNil(store.result)
        XCTAssertNil(store.pitchSession)
        XCTAssertNil(store.tutorialSession)
        XCTAssertNil(store.pendingGameCompletion)
        XCTAssertEqual(store.loadState, .needsSetup)
        // A later background/meta save must extend the tombstone, never republish `live`.
        XCTAssertTrue(store.save())
        let reloaded = HighSchoolCareerStore(sync: sync)
        reloaded.restoreOrCreate()
        XCTAssertNil(reloaded.result)
        XCTAssertEqual(reloaded.loadState, .needsSetup)
    }

    @MainActor
    func testTrainingBlockUsesNormalTransitionsAndStopsWithinThreeSessions() throws {
        let sync = SaveSync(key: "hs-training-block-\(UUID().uuidString).json")
        sync.clear()
        defer { sync.clear() }
        let live = try Self.careerResult(seed: "74006", at: .training)
        XCTAssertTrue(sync.write(try JSONEncoder().encode(
            HighSchoolCareerStore.SaveRecord(
                result: live,
                inheritance: .firstLife,
                archive: [],
                revision: live.snapshot.revision
            )
        )))
        let store = HighSchoolCareerStore(sync: sync)
        store.restoreOrCreate()
        let beforeRevision = try XCTUnwrap(store.state?.revision)
        let beforeTrainings = try XCTUnwrap(store.state?.totalTrainingsCompleted)

        store.commitTrainingBlock(focus: .command, intensity: .standard)

        let completed = try XCTUnwrap(store.state?.totalTrainingsCompleted) - beforeTrainings
        XCTAssertTrue((1...3).contains(completed))
        XCTAssertGreaterThan(try XCTUnwrap(store.state?.revision), beforeRevision)
        XCTAssertEqual(store.chapterTrainingCount, completed)
        XCTAssertTrue(store.lastSummary?.contains("훈련") == true)
    }

    @MainActor
    func testPledgeAndIntentSaveFailuresDoNotConsumeIntentOrEmitHooks() throws {
        let sync = SaveSync(key: "hs-pledge-atomic-\(UUID().uuidString).json")
        let weeklySync = SaveSync(key: "hs-pledge-atomic-weekly-\(UUID().uuidString).json")
        sync.clear()
        weeklySync.clear()
        let defaults = UserDefaults.standard
        let previousLastSetup = defaults.data(forKey: "baseball.lastSetup")
        defer {
            sync.clear()
            weeklySync.clear()
            GameAnalytics.eventSinkForTesting = nil
            if let previousLastSetup {
                defaults.set(previousLastSetup, forKey: "baseball.lastSetup")
            } else {
                defaults.removeObject(forKey: "baseball.lastSetup")
            }
        }
        let eligibility = WeeklyProgramEligibility(
            hasHighSchoolCareer: true,
            remainingImportantGames: 6,
            remainingChapterAdvances: 7,
            dailyInningUnlocked: true,
            canStartNextRun: false,
            canSelectPledge: true,
            canChooseDifferentSchool: false,
            hasProCareer: false
        )
        let now = Date()
        let moment = try XCTUnwrap(WeeklyProgramMoment.resolve(date: now, calendar: .current))
        let weeklyUser = try XCTUnwrap((0..<200).lazy.map { "hs-pledge-atomic-\($0)" }.first { id in
            WeeklyProgramRules.make(
                weekKey: moment.weekKey, stableUserID: id, eligibility: eligibility
            )?.tasks.contains(where: { $0.kind == .pledgeSelected }) == true
        })
        let weekly = WeeklyProgramStore(sync: weeklySync, stableUserID: weeklyUser)
        XCTAssertTrue(weekly.configure(eligibility: eligibility, now: now, calendar: .current))
        var writeFails = false
        let store = HighSchoolCareerStore(
            sync: sync,
            weekly: weekly,
            saveWriter: { data in writeFails ? false : sync.write(data) }
        )
        store.startCareer(
            preset: PitcherPresetCatalog.all[0], playerName: "목표 저장",
            seedOverride: "74005"
        )
        let careerID = try XCTUnwrap(store.state?.careerID)
        let pledgeKey = "baseball.pledge.\(careerID)"
        let versionKey = "baseball.pledgeRulesVersion.\(careerID)"
        defer {
            defaults.removeObject(forKey: pledgeKey)
            defaults.removeObject(forKey: versionKey)
        }
        let intent = NextRunIntent(
            pledgeID: "get_drafted",
            sourceLifeNumber: 1,
            reason: "지난 고교 3년에서 아쉽게 놓친 목표입니다."
        )
        var events: [GameAnalytics.Event] = []
        GameAnalytics.eventSinkForTesting = { event, _ in events.append(event) }

        writeFails = true
        XCTAssertFalse(store.saveNextRunIntent(intent))
        XCTAssertNil(store.nextRunIntent)
        XCTAssertEqual(events.filter { $0 == .nextRunIntentSaved }.count, 0)

        writeFails = false
        XCTAssertTrue(store.saveNextRunIntent(intent))
        XCTAssertEqual(store.nextRunIntent, intent)
        XCTAssertEqual(events.filter { $0 == .nextRunIntentSaved }.count, 1)
        let chronicleBefore = store.chronicle
        let weeklyBefore = weekly.program

        writeFails = true
        XCTAssertFalse(store.choosePledge(intent.pledgeID))
        XCTAssertEqual(store.nextRunIntent, intent)
        XCTAssertEqual(store.chronicle, chronicleBefore)
        XCTAssertNil(defaults.object(forKey: pledgeKey))
        XCTAssertNil(defaults.object(forKey: versionKey))
        XCTAssertEqual(weekly.program, weeklyBefore)
        XCTAssertEqual(events.filter { $0 == .runPledgeSelected }.count, 0)
        XCTAssertEqual(events.filter { $0 == .nextRunIntentApplied }.count, 0)

        writeFails = false
        XCTAssertTrue(store.choosePledge(intent.pledgeID))
        XCTAssertNil(store.nextRunIntent)
        XCTAssertEqual(defaults.string(forKey: pledgeKey), intent.pledgeID)
        XCTAssertEqual(defaults.integer(forKey: versionKey), RunPledge.currentRulesVersion)
        XCTAssertEqual(events.filter { $0 == .runPledgeSelected }.count, 1)
        XCTAssertEqual(events.filter { $0 == .nextRunIntentApplied }.count, 1)
        XCTAssertEqual(
            weekly.program?.tasks.first(where: { $0.kind == .pledgeSelected })?.progress,
            1
        )

        let reloaded = HighSchoolCareerStore(sync: sync)
        reloaded.restoreOrCreate()
        XCTAssertTrue(reloaded.pledgeDecided)
        XCTAssertEqual(reloaded.pledge?.id, intent.pledgeID)
        XCTAssertNil(reloaded.nextRunIntent)
    }

    /// 분리 회계: 구매 차감이 자동 성장 누적을 깎으면 상점이 벌금이 된다.
    func testSoulTotalSurvivesSpendingFromLegacyBalance() {
        // 옛 저장본(두 총량 nil) — 기존 단일 잔액을 자동 누적으로 승계한다.
        var legacy = HighSchoolCareerStore.Inheritance(
            lifeNumber: 3, memories: [], soulPoints: 300, karmas: []
        )
        XCTAssertEqual(legacy.soulTotal, 300)
        XCTAssertEqual(legacy.automaticSoulTotal, 300)
        // 구매 흐름과 같은 순서: 차감 전에 두 원장을 고정한다.
        legacy.automaticSoulEarned = legacy.automaticSoulTotal
        legacy.soulTotalEarned = legacy.soulTotal
        legacy.soulPoints -= 240
        XCTAssertEqual(legacy.soulPoints, 60)
        XCTAssertEqual(legacy.soulTotal, 300)
        XCTAssertEqual(legacy.automaticSoulTotal, 300, "구매가 자동 성장 누적을 깎았습니다")
    }

    @MainActor
    func testCareerStartUsesAutomaticSoulRatherThanLargerProWallet() throws {
        let sync = SaveSync(key: "automatic-soul-start-\(UUID().uuidString).json")
        sync.clear()
        defer {
            sync.clear()
            GameAnalytics.eventSinkForTesting = nil
        }
        var inheritance = HighSchoolCareerStore.Inheritance(
            lifeNumber: 2, memories: [], soulPoints: 360, karmas: []
        )
        inheritance.soulTotalEarned = 500
        inheritance.automaticSoulEarned = 40
        inheritance.inheritanceRulesVersion = SoulInheritanceRulesVersion.current.rawValue
        XCTAssertTrue(sync.write(try JSONEncoder().encode(
            HighSchoolCareerStore.SaveRecord(
                result: nil, inheritance: inheritance, archive: [], revision: 1
            )
        )))
        let store = HighSchoolCareerStore(sync: sync)
        store.restoreOrCreate()
        let preset = PitcherPresetCatalog.all[0]
        let identity = PlayerIdentitySnapshot(
            name: "자동 성장 확인",
            throwingHand: preset.pitcher.throwingHand,
            bodyType: .balanced,
            region: "서울"
        )
        let expected = try HighSchoolCareerEngine().start(.init(
            seed: "74006",
            presetID: preset.id,
            lifeNumber: 2,
            inheritedSoulPoints: 40,
            inheritedSoulDomain: .technique,
            inheritedMemories: [],
            identity: identity,
            difficulty: .standard,
            karmas: [],
            soulBoosts: nil,
            inheritedSoulTotal: 40,
            signatureLegacyID: nil,
            inheritanceRulesVersion: SoulInheritanceRulesVersion.current.rawValue
        ))
        var rebirthProperties: [String: Any]?
        GameAnalytics.eventSinkForTesting = { event, properties in
            if event == .rebirthStarted { rebirthProperties = properties }
        }

        store.startCareer(
            preset: preset,
            playerName: identity.name,
            soulDomain: .technique,
            seedOverride: "74006"
        )

        XCTAssertEqual(store.state?.pitcher, expected.snapshot.pitcher)
        XCTAssertEqual(store.inheritance.soulPoints, 360, "프로 지갑은 상점 구매 전 그대로여야 합니다.")
        XCTAssertEqual(store.inheritance.automaticSoulTotal, 40)
        XCTAssertEqual(store.inheritance.soulTotal, 500)
        XCTAssertEqual(rebirthProperties?["soul_total"] as? Int, 40)
        XCTAssertEqual(rebirthProperties?["soul_wallet"] as? Int, 360)
        XCTAssertEqual(rebirthProperties?["soul_lifetime_earned"] as? Int, 500)
    }

    func testHeadStartCopyMatchesFivePointCoreBonus() {
        let copy = HighSchoolSetupView.boostCopy(.headStart)
        XCTAssertTrue(copy.detail.contains("+5"))
        XCTAssertFalse(copy.detail.contains("+6"))
        XCTAssertTrue(HighSchoolSetupView.showsSoulDomain(
            automaticSoulTotal: 40, isChallenge: false
        ))
        XCTAssertFalse(HighSchoolSetupView.showsSoulDomain(
            automaticSoulTotal: 0, isChallenge: false
        ), "프로 지갑만 있고 자동 누적이 없으면 성장 분야를 묻지 않습니다.")
        XCTAssertFalse(HighSchoolSetupView.showsSoulDomain(
            automaticSoulTotal: 40, isChallenge: true
        ))
    }

    func testPerfectGestureScoresFull() {
        let delivery = DeliveryControl.delivery(meter: 0.5, aim: .zero, aimRadius: 46)
        XCTAssertEqual(delivery.releaseAccuracy, 1_000)
        XCTAssertEqual(delivery.aimAccuracy, 1_000)
    }

    /// 끝에서 떼면 0. 값은 항상 코어가 받는 0~1000 범위 안이어야 한다.
    func testGestureStaysInRange() {
        for meter in stride(from: 0.0, through: 1.0, by: 0.05) {
            for offset in stride(from: -80.0, through: 80.0, by: 20) {
                let delivery = DeliveryControl.delivery(
                    meter: meter,
                    aim: CGSize(width: offset, height: offset / 2),
                    aimRadius: 46
                )
                XCTAssertTrue((0...1_000).contains(delivery.releaseAccuracy))
                XCTAssertTrue((0...1_000).contains(delivery.aimAccuracy))
            }
        }
        XCTAssertEqual(DeliveryControl.delivery(meter: 0, aim: .zero, aimRadius: 46).releaseAccuracy, 0)
        XCTAssertEqual(DeliveryControl.delivery(meter: 1, aim: .zero, aimRadius: 46).releaseAccuracy, 0)
    }

    /// 조준이 멀어질수록 점수가 단조 감소해야 한다.
    func testAimScoreDecreasesWithDistance() {
        let near = DeliveryControl.delivery(meter: 0.5, aim: CGSize(width: 10, height: 0), aimRadius: 46)
        let far = DeliveryControl.delivery(meter: 0.5, aim: CGSize(width: 40, height: 0), aimRadius: 46)
        XCTAssertGreaterThan(near.aimAccuracy, far.aimAccuracy)
    }

    /// 자동 릴리스가 쓰는 중립값은 판정 문구를 만들지 않는다. 손맛 판정이 없을 때는 조용해야 한다.
    func testNeutralDeliveryHasNoVerdict() {
        XCTAssertNil(DeliveryControl.verdict(.neutral))
        XCTAssertNotNil(DeliveryControl.verdict(PitchDelivery(releaseAccuracy: 950, aimAccuracy: 950)))
    }

    // MARK: - 분석

    /// 전환으로 집계되는 이벤트는 1인 1회여야 한다 — 두 번 세면 광고 데이터가 거짓이 된다.
    @MainActor
    func testActivationEventLogsExactlyOnce() {
        GameAnalytics.resetOnceFlags()
        XCTAssertTrue(GameAnalytics.logOnce(.activationFirstGame), "첫 호출은 기록돼야 합니다.")
        XCTAssertFalse(GameAnalytics.logOnce(.activationFirstGame), "두 번째 호출은 무시돼야 합니다.")
        GameAnalytics.resetOnceFlags()
        XCTAssertTrue(GameAnalytics.logOnce(.activationFirstGame), "리셋 후에는 다시 기록됩니다.")
        GameAnalytics.resetOnceFlags()
    }

    // MARK: - 소리

    /// 소리 매핑은 결과마다 반드시 무언가를 낸다. 조용한 투구는 없다.
    func testEveryOutcomeMakesSound() {
        for outcome in PitchOutcome.allCases {
            let snapshot = Self.snapshot(outcome: outcome)
            let cues = GameAudioMapping.cues(for: snapshot)
            XCTAssertFalse(cues.isEmpty, "\(outcome)에 소리가 없습니다.")
            XCTAssertEqual(cues.first, .pitchRelease, "모든 투구는 릴리스 소리로 시작해야 합니다.")
        }
    }

    /// 삼진은 낱개 스트라이크 콜 대신 풀콜("스트라이크 쓰리, 유어 아웃") 하나로 나간다.
    /// 둘 다 나가면 "스트라이크"를 두 번 외치는 심판이 된다.
    func testStrikeoutUsesTheFullCallInsteadOfTheStrikeCall() {
        for outcome in [PitchOutcome.calledStrike, .swingingStrike] {
            let cues = GameAudioMapping.cues(for: Self.snapshot(outcome: outcome, result: .strikeout))
            XCTAssertTrue(cues.contains(.umpireStrikeout), "\(outcome) 삼진에 풀콜이 없습니다.")
            XCTAssertFalse(cues.contains(.umpireStrike), "\(outcome) 삼진에 낱개 콜이 겹칩니다.")
            XCTAssertTrue(cues.contains(.crowdCheer))
        }
        // 삼진이 아닌 스트라이크는 여전히 낱개 콜이다.
        let ordinary = GameAudioMapping.cues(for: Self.snapshot(outcome: .calledStrike))
        XCTAssertTrue(ordinary.contains(.umpireStrike))
        XCTAssertFalse(ordinary.contains(.umpireStrikeout))
    }

    /// 잘 맞은 타구는 더 두꺼운 소리를 낸다.
    func testContactPowerFollowsContactQuality() {
        XCTAssertEqual(GameAudioMapping.contactPower(nil), 0.5)
        let weak = GameAudioMapping.contactPower(BattedBall(exitVelocityTenthsKPH: 900, launchAngleTenthsDegrees: 100, directionTenthsDegrees: 0, contactQuality: 200))
        let hard = GameAudioMapping.contactPower(BattedBall(exitVelocityTenthsKPH: 1_600, launchAngleTenthsDegrees: 250, directionTenthsDegrees: 0, contactQuality: 900))
        XCTAssertLessThan(weak, hard)
        XCTAssertTrue((0...1).contains(hard))
    }

    /// 레버리지가 높을수록 관중이 두꺼워지고, 값은 항상 0~1이다.
    func testCrowdIntensityRange() {
        XCTAssertLessThan(
            GameAudioMapping.crowdIntensity(leverage: 100),
            GameAudioMapping.crowdIntensity(leverage: 1_000)
        )
        for leverage in stride(from: 0, through: 1_000, by: 50) {
            let value = GameAudioMapping.crowdIntensity(leverage: leverage)
            XCTAssertTrue((0...1).contains(value))
        }
    }

    /// 모든 큐가 실제로 소리 낼 보이스를 만들어야 한다. 정의만 있고 소리가 없는 큐는 버그다.
    func testEveryCueProducesVoices() {
        // umpireBall은 **의도적 무음**이라 여기서 빠진다. 실제 심판은 볼을 외치지 않고,
        // 미트 소리가 이미 공 하나를 표시한다(UmpireVoiceTests.testBallCallIsSilent가 지킨다).
        let cues: [GameAudioCue] = [
            .pitchRelease, .gloveCatch, .swingMiss, .batContact(power: 0.8), .batFoul,
            .umpireStrike, .umpireStrikeout, .crowdCheer, .crowdGroan, .growth, .milestone, .uiSelect
        ]
        for cue in cues {
            let voices = GameAudio.voices(for: cue)
            XCTAssertFalse(voices.isEmpty, "\(cue)에 보이스가 없습니다.")
            for voice in voices {
                XCTAssertGreaterThan(voice.duration, 0)
                XCTAssertGreaterThan(voice.gain, 0)
                XCTAssertGreaterThanOrEqual(voice.delay, 0)
            }
        }
    }

    // MARK: - 업적

    func testInningAchievements() {
        let clean = ImportantInningReport(scenarioNumber: 1, pitches: 12, strikeouts: 2, walks: 0, runsAllowed: 0, expectedDamage: 300, actualDamage: 200, recommendationAccepted: 8)
        XCTAssertTrue(AchievementRules.fromInning(report: clean).contains(.cleanInning))
        XCTAssertTrue(AchievementRules.fromInning(report: clean).contains(.firstStrikeout))

        let messy = ImportantInningReport(scenarioNumber: 1, pitches: 20, strikeouts: 0, walks: 3, runsAllowed: 2, expectedDamage: 600, actualDamage: 800, recommendationAccepted: 2)
        XCTAssertFalse(AchievementRules.fromInning(report: messy).contains(.cleanInning))
        XCTAssertFalse(AchievementRules.fromInning(report: messy).contains(.firstStrikeout))

        // 던지지 않은 이닝은 무실점이 아니다.
        let empty = ImportantInningReport(scenarioNumber: 1, pitches: 0, strikeouts: 0, walks: 0, runsAllowed: 0, expectedDamage: 0, actualDamage: 0, recommendationAccepted: 0)
        XCTAssertFalse(AchievementRules.fromInning(report: empty).contains(.cleanInning))
    }

    func testDeliveryAchievementNeedsBothAxes() {
        XCTAssertTrue(AchievementRules.fromDelivery(PitchDelivery(releaseAccuracy: 950, aimAccuracy: 920)).contains(.perfectDelivery))
        XCTAssertTrue(AchievementRules.fromDelivery(PitchDelivery(releaseAccuracy: 950, aimAccuracy: 800)).isEmpty)
        XCTAssertTrue(AchievementRules.fromDelivery(nil).isEmpty)
        XCTAssertTrue(AchievementRules.fromDelivery(.neutral).isEmpty)
    }

    func testLifeNumberAchievement() {
        XCTAssertTrue(AchievementRules.fromLifeNumber(1).isEmpty)
        XCTAssertTrue(AchievementRules.fromLifeNumber(3).contains(.thirdLife))
        XCTAssertTrue(AchievementRules.fromLifeNumber(7).contains(.thirdLife))
        // 회차 사다리: 3회차 하나로 끝나면 3회차 시작 순간 회차 목표가 소진된다.
        XCTAssertFalse(AchievementRules.fromLifeNumber(4).contains(.fifthLife))
        XCTAssertTrue(AchievementRules.fromLifeNumber(5).contains(.fifthLife))
        XCTAssertTrue(AchievementRules.fromLifeNumber(10).contains(.tenthLife))
    }

    /// 수집형 업적: 아카이브가 콘텐츠 풀(학교·지명)을 가리켜야 반복 이유가 생긴다.
    func testArchiveAchievements() {
        func life(_ number: Int, school: String, drafted: Bool) -> HighSchoolCareerStore.LifeRecord {
            HighSchoolCareerStore.LifeRecord(
                lifeNumber: number, playerName: "테스트", schoolName: school, drafted: drafted,
                evaluationScore: 60, teamName: drafted ? "구단" : nil, memories: [], games: 5,
                strikeouts: 30, walks: 8, runsAllowed: 10, soulPoints: 40
            )
        }
        let threeSchools = [life(1, school: "가", drafted: true), life(2, school: "나", drafted: true), life(3, school: "다", drafted: false)]
        XCTAssertFalse(AchievementRules.fromArchive(threeSchools).contains(.fourSchools))
        let fourSchools = threeSchools + [life(4, school: "라", drafted: true)]
        XCTAssertTrue(AchievementRules.fromArchive(fourSchools).contains(.fourSchools))
        XCTAssertFalse(AchievementRules.fromArchive(fourSchools).contains(.fiveDrafts))
        let fiveDrafts = fourSchools + [life(5, school: "가", drafted: true), life(6, school: "나", drafted: true)]
        XCTAssertTrue(AchievementRules.fromArchive(fiveDrafts).contains(.fiveDrafts))
    }

    /// 같은 업적을 두 번 기록해도 새로 달성한 것으로 치지 않는다.
    func testProgressOnlyReportsFreshUnlocks() {
        var progress = AchievementProgress()
        XCTAssertEqual(progress.unlock([.firstDraft, .cleanInning]).count, 2)
        XCTAssertEqual(progress.unlock([.firstDraft]).count, 0)
        XCTAssertEqual(progress.unlock([.firstDraft, .thirdLife]), [.thirdLife])
        XCTAssertTrue(progress.has(.firstDraft))
        XCTAssertFalse(progress.has(.hallOfFame))
    }

    /// 업적은 저장/복원돼야 한다. 앱을 껐다 켜면 사라지는 업적은 리텐션 장치가 아니다.
    func testProgressRoundTrips() throws {
        var progress = AchievementProgress()
        _ = progress.unlock([.majorDebut, .karmaRun])
        let data = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(AchievementProgress.self, from: data)
        XCTAssertEqual(decoded, progress)
        XCTAssertTrue(decoded.has(.majorDebut))
    }

    /// 모든 업적과 리더보드는 고유한 Game Center 식별자를 가져야 한다.
    func testGameCenterIdentifiersAreUnique() {
        let achievementIDs = Achievement.allCases.map(\.gameCenterID)
        XCTAssertEqual(Set(achievementIDs).count, achievementIDs.count)
        let boardIDs = Leaderboard.allCases.map(\.gameCenterID)
        XCTAssertEqual(Set(boardIDs).count, boardIDs.count)
    }

    // MARK: - 환생 계승

    /// 실패한 회차도 다음 생에 무언가를 남긴다. 0이 되면 다시 켤 이유가 사라진다.
    /// 코어의 legacyRewardPermille는 1000이 ×1.0이다(카르마 없음).
    func testFailedRunStillCarriesSomethingForward() {
        let state = Self.highSchoolSnapshot(strikeouts: 0, walks: 12, runsAllowed: 9, rewardPermille: 1_000)
        let next = HighSchoolCareerStore.nextInheritance(from: state, memories: [], previous: .firstLife)
        XCTAssertEqual(next.lifeNumber, 2)
        XCTAssertGreaterThan(next.soulPoints, 0)
    }

    /// 카르마 보상 배율이 계승분을 정확히 표기만큼 키운다. 예전에는 스토어가 1000을 한 번
    /// 더 더해서 기본이 ×2.0이 됐고, 화면의 "+35%"가 실제로는 +17.5%만 전달됐다.
    func testKarmaRewardIncreasesInheritanceExactly() {
        let plain = Self.highSchoolSnapshot(strikeouts: 20, walks: 4, runsAllowed: 3, rewardPermille: 1_000)
        let burdened = Self.highSchoolSnapshot(strikeouts: 20, walks: 4, runsAllowed: 3, rewardPermille: 1_350)
        let a = HighSchoolCareerStore.nextInheritance(from: plain, memories: [], previous: .firstLife)
        let b = HighSchoolCareerStore.nextInheritance(from: burdened, memories: [], previous: .firstLife)
        XCTAssertGreaterThan(b.soulPoints, a.soulPoints)
        // 정수 나눗셈 오차 1 이내에서 정확히 ×1.35여야 한다.
        XCTAssertLessThanOrEqual(abs(b.soulPoints - a.soulPoints * 1_350 / 1_000), 1)
    }

    /// 배율 필드가 없거나 0인 저장본(구버전 데스크톱 등)도 ×1.0 밑으로 떨어지지 않는다.
    func testDegenerateRewardPermilleStillPaysFull() {
        let zero = Self.highSchoolSnapshot(strikeouts: 20, walks: 4, runsAllowed: 3, rewardPermille: 0)
        let full = Self.highSchoolSnapshot(strikeouts: 20, walks: 4, runsAllowed: 3, rewardPermille: 1_000)
        XCTAssertEqual(
            HighSchoolCareerStore.nextInheritance(from: zero, memories: [], previous: .firstLife).soulPoints,
            HighSchoolCareerStore.nextInheritance(from: full, memories: [], previous: .firstLife).soulPoints
        )
    }

    /// 회차가 쌓이면 영혼도 쌓인다.
    func testInheritanceAccumulatesAcrossLives() {
        let state = Self.highSchoolSnapshot(strikeouts: 15, walks: 5, runsAllowed: 4, rewardPermille: 150)
        var carried = HighSchoolCareerStore.Inheritance.firstLife
        var previousPoints = 0
        for expectedLife in 2...5 {
            carried = HighSchoolCareerStore.nextInheritance(from: state, memories: [.coachLetter], previous: carried)
            XCTAssertEqual(carried.lifeNumber, expectedLife)
            XCTAssertGreaterThan(carried.soulPoints, previousPoints)
            XCTAssertEqual(carried.memories, [.coachLetter])
            previousPoints = carried.soulPoints
        }
    }

    /// 프로 커리어가 길고 빛날수록 다음 회차에 남기는 야구혼이 커야 한다.
    /// 예전에는 15년 명예의 전당 커리어도 계승에 0을 남겼다.
    func testProCareerLeavesSoulProportionalToItsWeight() {
        let short = HighSchoolCareerStore.proSoulBonus(seasons: 2, strikeouts: 90, awards: 0, hallOfFameScore: 0)
        let steady = HighSchoolCareerStore.proSoulBonus(seasons: 8, strikeouts: 700, awards: 1, hallOfFameScore: 30)
        let legend = HighSchoolCareerStore.proSoulBonus(seasons: 12, strikeouts: 1_800, awards: 6, hallOfFameScore: 90)
        XCTAssertGreaterThan(short, 0)
        XCTAssertGreaterThan(steady, short)
        XCTAssertGreaterThan(legend, steady)
        // 전설 커리어는 스펙의 프로 계승 스케일(~220+)에 닿아야 한다.
        XCTAssertGreaterThanOrEqual(legend, 200)
    }

    /// 회차 사이(진행 없음)에도 계승분이 저장 레코드로 남아야 한다. 이게 깨지면
    /// "다시 태어나기" 직후 앱이 내려갈 때 야구혼·기억·아카이브가 통째로 사라진다.
    /// 별명·연대기가 없는 옛 저장본이 그대로 열리고, 있는 것은 온전히 돌아온다.
    func testNicknamesAndChronicleSurviveTheRoundTripAndOldSavesStillOpen() throws {
        let life = HighSchoolCareerStore.LifeRecord(
            lifeNumber: 4, playerName: "테스트", schoolName: nil, drafted: true,
            evaluationScore: 70, teamName: "부산 돌핀스", memories: [], games: 4,
            strikeouts: 30, walks: 3, runsAllowed: 0, soulPoints: 50,
            nicknames: ["제로", "핀포인트"],
            chronicle: ["1학년 봄 — 입학.", "3학년 여름 — 드래프트 1라운드 지명."]
        )
        let record = HighSchoolCareerStore.SaveRecord(
            result: nil,
            inheritance: .init(lifeNumber: 4, memories: [], soulPoints: 10, karmas: []),
            archive: [life],
            nicknames: [Nickname(id: "zero", title: "제로", reason: "무실점")],
            chronicle: [.init(stage: "3학년 여름", text: "드래프트 지명.")],
            revision: 9
        )
        let decoded = try JSONDecoder().decode(
            HighSchoolCareerStore.SaveRecord.self, from: JSONEncoder().encode(record)
        )
        XCTAssertEqual(decoded.archive?.first?.nicknames, ["제로", "핀포인트"])
        XCTAssertEqual(decoded.archive?.first?.chronicle?.count, 2)
        XCTAssertEqual(decoded.nicknames?.first?.title, "제로")
        XCTAssertEqual(decoded.chronicle?.first?.text, "드래프트 지명.")

        // 새 키가 하나도 없는 옛 저장본 — 필드 추가가 복원을 깨면 안 된다.
        let old = """
        {"inheritance":{"lifeNumber":1,"memories":[],"soulPoints":0,"karmas":[]},"revision":1}
        """
        let legacy = try JSONDecoder().decode(
            HighSchoolCareerStore.SaveRecord.self, from: Data(old.utf8)
        )
        XCTAssertNil(legacy.nicknames)
        XCTAssertNil(legacy.chronicle)
    }

    func testLegacyOnlyRecordRoundTrips() throws {
        let inheritance = HighSchoolCareerStore.Inheritance(
            lifeNumber: 3, memories: [.coachLetter, .recoveryRoutine], soulPoints: 87, karmas: [.noLastChance]
        )
        let life = HighSchoolCareerStore.LifeRecord(
            lifeNumber: 2, playerName: "테스트", schoolName: "서울덕성고", drafted: false,
            evaluationScore: 55, teamName: nil, memories: [.coachLetter], games: 5,
            strikeouts: 40, walks: 9, runsAllowed: 12, soulPoints: 41
        )
        let record = HighSchoolCareerStore.SaveRecord(
            result: nil, inheritance: inheritance, archive: [life], revision: 42
        )
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(HighSchoolCareerStore.SaveRecord.self, from: data)
        XCTAssertNil(decoded.result)
        XCTAssertEqual(decoded.inheritance, inheritance)
        XCTAssertEqual(decoded.archive, [life])
        XCTAssertEqual(decoded.effectiveRevision, 42)
    }

    /// 계승 확정 때 선수의 편지를 함께 동결한다. 화면에서 매번 새로 만들기만 하면
    /// 카피 업데이트 뒤 이미 끝난 선수가 다른 말을 하게 된다.
    func testLifeRecordFreezesPlayerLegacyFromActualCareerStory() throws {
        let state = Self.highSchoolSnapshot(
            strikeouts: 18, walks: 4, runsAllowed: 3, rewardPermille: 1_000
        )
        let record = HighSchoolCareerStore.lifeRecord(
            from: state,
            memories: [.coachLetter],
            previous: .firstLife,
            chronicle: [
                .init(stage: "1학년 봄", text: "첫 등교."),
                .init(stage: "2학년 여름", text: "제구 재능이 만개했습니다."),
            ],
            personality: PersonalityRules.personality(listen: 5, explain: 0, challenge: 0)
        )
        let legacy = try XCTUnwrap(record.playerLegacy)
        XCTAssertEqual(legacy.definingMoment, "2학년 여름 — 제구 재능이 만개했습니다.")
        XCTAssertTrue(legacy.farewell.contains("말없이 오래"))

        let decoded = try JSONDecoder().decode(
            HighSchoolCareerStore.LifeRecord.self,
            from: JSONEncoder().encode(record)
        )
        XCTAssertEqual(decoded.playerLegacy, legacy)
    }

    // MARK: - 고정물

    private static func snapshot(
        outcome: PitchOutcome, result: PlateAppearanceResult? = nil
    ) -> PlateAppearanceSnapshot {
        PlateAppearanceSnapshot(
            revision: 1,
            balls: 0,
            strikes: 1,
            pitchNumber: 1,
            ended: result != nil,
            result: result,
            outcome: outcome,
            selectionQuality: .good,
            recommendationAccepted: true,
            fatigueAfterPitch: 20,
            execution: PitchExecution(
                targetX: 0, targetY: 0, actualX: 10, actualY: -20,
                velocityTenthsKPH: 1_400, horizontalBreakTenthsCM: 40,
                verticalBreakTenthsCM: 120, executionQuality: 700
            ),
            battedBall: BattedBall(
                exitVelocityTenthsKPH: 1_400,
                launchAngleTenthsDegrees: 200,
                directionTenthsDegrees: 50,
                contactQuality: 600
            ),
            reasonCodes: [],
            shortFeedback: "테스트",
            detailFeedback: "테스트",
            accessibilitySummary: "테스트"
        )
    }

    private static func highSchoolSnapshot(
        strikeouts: Int,
        walks: Int,
        runsAllowed: Int,
        rewardPermille: Int,
        phase: HighSchoolCareerPhase = .legacy,
        drafted: Bool? = nil
    ) -> HighSchoolCareerSnapshot {
        HighSchoolCareerSnapshot(
            careerID: "hs-test",
            revision: 1,
            lifeNumber: 1,
            phase: phase,
            identity: .defaultPitcher,
            difficulty: .standard,
            karmas: [],
            legacyRewardPermille: rewardPermille,
            memorySlots: 2,
            pitcher: PitcherSnapshot(id: "p", name: "테스트", stuff: 45, command: 44, movement: 43, stamina: 46),
            schoolOptions: [],
            school: nil,
            rival: RivalSnapshot(id: "r", name: "라이벌", archetype: "거포", contact: 50, discipline: 48, power: 60),
            chapter: CareerChapterSnapshot(number: 8, title: "마지막", schoolYear: 3, season: "가을", theme: "끝"),
            chapterTrainingCount: 2,
            totalTrainingsCompleted: 16,
            milestoneIndex: 0,
            relationshipsCompleted: 5,
            relationshipTrust: 55,
            selectedAwakenings: [],
            awakeningOptions: [],
            fatigue: 30,
            performance: CareerPerformanceSnapshot(
                importantGamesCompleted: 5,
                pitches: 90,
                strikeouts: strikeouts,
                walks: walks,
                runsAllowed: runsAllowed,
                expectedDamage: 1_000,
                actualDamage: 900
            ),
            currentGameScenario: nil,
            currentRelationshipEvent: nil,
            lastTraining: nil,
            news: [],
            fanInterest: 40,
            draftResult: drafted.map { drafted in
                DraftResultSnapshot(
                    outcome: drafted ? .drafted : .undrafted,
                    evaluationScore: drafted ? 70 : 55,
                    projectedRange: drafted ? "지명권" : "미지명권",
                    team: nil,
                    round: drafted ? 3 : nil,
                    overallPick: nil,
                    signingBonus: nil,
                    firstSeasonGoal: nil,
                    summary: drafted ? "지명" : "미지명"
                )
            },
            legacyOptions: [],
            selectedMemories: [],
            stateCommitment: ""
        )
    }

    @MainActor
    private static func throwUntilCheckpoint(_ session: PitchSession) throws {
        for _ in 0..<160 {
            if session.resumeState() != nil { return }
            switch session.stage {
            case .ready:
                session.throwPitch()
            case .betweenBatters, .finished:
                return
            case .failed(let message):
                XCTFail("체크포인트 전 투구 실패: \(message)")
                return
            }
        }
        XCTFail("160구 안에 타석 경계에 도달하지 못했습니다.")
    }

    @MainActor
    private static func finish(_ session: PitchSession) throws {
        for _ in 0..<400 {
            switch session.stage {
            case .ready:
                session.throwPitch()
            case .betweenBatters:
                session.advanceToNextBatter()
            case .finished:
                return
            case .failed(let message):
                XCTFail("이닝 완료 전 투구 실패: \(message)")
                return
            }
        }
        XCTFail("400구 안에 이닝을 마치지 못했습니다.")
    }

    private static func careerResult(
        seed: String,
        at target: HighSchoolCareerPhase
    ) throws -> HighSchoolCareerResult {
        let engine = HighSchoolCareerEngine()
        var result = try engine.start(.init(seed: seed, presetID: "precision_commander"))
        for _ in 0..<180 {
            if result.snapshot.phase == target { return result }
            switch result.snapshot.phase {
            case .prologue:
                result = try engine.completePrologue(.init(
                    seed: result.nextSeed, state: result.snapshot
                ))
            case .schoolSelection:
                result = try engine.chooseSchool(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    schoolID: .miraeAnalytics
                ))
            case .training:
                result = try engine.commitTraining(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    focus: .gamePlanning,
                    intensity: .light
                ))
            case .relationship:
                result = try engine.resolveRelationship(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    response: .listen
                ))
            case .importantGame:
                let number = result.snapshot.performance.importantGamesCompleted + 1
                result = try engine.recordImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: .init(
                        scenarioNumber: number,
                        pitches: 12,
                        strikeouts: 1,
                        walks: 1,
                        runsAllowed: 2,
                        expectedDamage: 500,
                        actualDamage: 700,
                        recommendationAccepted: 4,
                        outs: 2
                    )
                ))
            case .awakening:
                result = try engine.chooseAwakening(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    awakening: try XCTUnwrap(result.snapshot.awakeningOptions.first)
                ))
            case .chapterReview:
                result = try engine.advanceChapter(.init(
                    seed: result.nextSeed, state: result.snapshot
                ))
            case .draft:
                result = try engine.resolveDraft(.init(
                    seed: result.nextSeed, state: result.snapshot
                ))
            case .legacy, .completed:
                XCTFail("목표 국면 \(target.rawValue) 전에 커리어가 끝났습니다.")
                return result
            }
        }
        XCTFail("목표 국면 \(target.rawValue)에 180번 안에 도달하지 못했습니다.")
        return result
    }

    private static func completedCareerAtLegacy(seed: String) throws -> HighSchoolCareerResult {
        let engine = HighSchoolCareerEngine()
        var result = try engine.start(.init(seed: seed, presetID: "precision_commander"))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            schoolID: .miraeAnalytics
        ))
        for _ in 0..<180 {
            switch result.snapshot.phase {
            case .training:
                result = try engine.commitTraining(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    focus: .gamePlanning,
                    intensity: .light
                ))
            case .relationship:
                result = try engine.resolveRelationship(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    response: .listen
                ))
            case .importantGame:
                let number = result.snapshot.performance.importantGamesCompleted + 1
                result = try engine.recordImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: .init(
                        scenarioNumber: number,
                        pitches: 12,
                        strikeouts: 1,
                        walks: 1,
                        runsAllowed: 2,
                        expectedDamage: 500,
                        actualDamage: 700,
                        recommendationAccepted: 4,
                        outs: 2
                    )
                ))
            case .awakening:
                result = try engine.chooseAwakening(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    awakening: try XCTUnwrap(result.snapshot.awakeningOptions.first)
                ))
            case .chapterReview:
                result = try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
            case .draft:
                result = try engine.resolveDraft(.init(seed: result.nextSeed, state: result.snapshot))
                if result.snapshot.phase == .completed {
                    result = try engine.openLegacy(.init(seed: result.nextSeed, state: result.snapshot))
                }
            case .legacy:
                return result
            case .completed:
                result = try engine.openLegacy(.init(seed: result.nextSeed, state: result.snapshot))
            case .prologue, .schoolSelection:
                XCTFail("학교 선택 뒤 이전 국면으로 돌아가면 안 됩니다.")
                return result
            }
        }
        XCTFail("결말 선택까지 180번 안에 도달하지 못했습니다.")
        return result
    }
}
