import SimulationCore
import SwiftUI
import XCTest
@testable import BaseballIOS

private final class ProMemoryRemoteStore: SaveSyncRemoteStoring {
    private(set) var values: [String: Data] = [:]

    func data(forKey key: String) -> Data? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value as? Data }
    func removeObject(forKey key: String) { values.removeValue(forKey: key) }
    @discardableResult func synchronize() -> Bool { true }
}

@MainActor
final class ProSeasonDecisionTests: XCTestCase {
    private let engine = ProCareerEngine()

    func testDecisionScreenRendersAllThreeFullyDisclosedAccessibleChoices() throws {
        let pendingResult = try firstDecision(seed: 8_401)
        let decision = try XCTUnwrap(pendingResult.snapshot.pendingDecision)
        let sync = isolatedSync("decision-render")
        sync.clear()
        defer { sync.clear() }
        let store = MobileCareerStore(sync: sync)
        store.result = pendingResult
        store.loadState = .ready

        XCTAssertEqual(decision.choices.count, 3)
        for choice in decision.choices {
            let label = ProSeasonDecisionView.accessibilityLabel(for: choice)
            XCTAssertTrue(label.contains(choice.title))
            XCTAssertTrue(label.contains(choice.detail))
            XCTAssertTrue(label.contains(choice.effect.summary))
        }

        let renderer = ImageRenderer(content:
            ScrollView {
                ProSeasonDecisionView(career: store, decision: decision)
                    .padding()
            }
            .frame(width: 390, height: 920)
        )
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage)
        let data = try XCTUnwrap(image.pngData())
        XCTAssertGreaterThan(data.count, 4_000)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = "pro-season-decision"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testConfirmedChoiceAppliesOncePreservesSeedAndBuildsAnalyticsContract() throws {
        let pendingResult = try firstDecision(seed: 8_402)
        let decision = try XCTUnwrap(pendingResult.snapshot.pendingDecision)
        let choice = decision.choices[1]
        let sync = isolatedSync("decision-confirm")
        sync.clear()
        defer { sync.clear() }
        let store = MobileCareerStore(sync: sync)
        store.result = pendingResult
        store.loadState = .ready

        store.applySeasonDecision(decisionID: decision.id, choiceID: choice.id)

        XCTAssertEqual(store.state?.phase, .weeklyPlan)
        XCTAssertNil(store.state?.pendingDecision)
        XCTAssertEqual(store.result?.nextSeed, pendingResult.nextSeed, "시즌 선택은 RNG를 소비하지 않습니다.")
        XCTAssertEqual(store.state?.decisionHistory?.last?.choiceID, choice.id)
        XCTAssertEqual(store.state?.decisionHistory?.last?.effect, choice.effect)
        let record = try XCTUnwrap(store.state?.decisionHistory?.last)
        let recordLabel = ProDecisionHistoryCard.accessibilityLabel(for: record)
        XCTAssertTrue(recordLabel.contains(choice.title))
        XCTAssertTrue(recordLabel.contains(choice.effect.summary))

        let properties = MobileCareerStore.decisionAnalyticsProperties(decision: decision, choice: choice)
        XCTAssertEqual(properties["decision_id"] as? String, decision.id)
        XCTAssertEqual(properties["choice_id"] as? String, choice.id)
        XCTAssertEqual(properties["season"] as? Int, decision.season)
        XCTAssertEqual(properties["week"] as? Int, decision.week)
        XCTAssertEqual(GameAnalytics.Event.proSeasonDecisionSelected.rawValue, "pro_season_decision_selected")

        let revision = store.state?.revision
        store.applySeasonDecision(decisionID: decision.id, choiceID: choice.id)
        XCTAssertEqual(store.state?.revision, revision, "확인 콜백이 반복돼도 같은 결정을 다시 적용하면 안 됩니다.")
    }

    func testPendingDecisionSaveResumeReturnsToIdenticalDecisionScreen() throws {
        let pendingResult = try firstDecision(seed: 8_403)
        let sync = isolatedSync("decision-resume")
        sync.clear()
        defer { sync.clear() }
        let store = MobileCareerStore(sync: sync)
        store.result = pendingResult
        store.loadState = .ready
        store.save()

        let resumed = MobileCareerStore(sync: sync)
        resumed.restoreOrCreateCareer()

        XCTAssertEqual(resumed.loadState, .ready)
        XCTAssertEqual(resumed.state?.phase, .seasonDecision)
        XCTAssertEqual(resumed.state?.pendingDecision, pendingResult.snapshot.pendingDecision)
        XCTAssertEqual(resumed.state?.decisionHistory, pendingResult.snapshot.decisionHistory)
        XCTAssertEqual(resumed.result?.nextSeed, pendingResult.nextSeed)
    }

    func testAdvanceSegmentStopsAtDecisionInsteadOfSkippingIt() throws {
        let beforeDecision = try stateImmediatelyBeforeDecision(seed: 8_404)
        let weeklySync = isolatedSync("decision-weekly")
        weeklySync.clear()
        defer { weeklySync.clear() }
        let weekly = WeeklyProgramStore(sync: weeklySync, stableUserID: "decision-test")
        weekly.configure(eligibility: .init(
            hasHighSchoolCareer: false,
            remainingImportantGames: 0,
            remainingChapterAdvances: 0,
            canStartNextRun: false,
            canSelectPledge: false,
            canChooseDifferentSchool: false,
            hasProCareer: true
        ))
        let careerSync = isolatedSync("decision-stop")
        careerSync.clear()
        defer { careerSync.clear() }
        let store = MobileCareerStore(sync: careerSync, weekly: weekly)
        store.result = beforeDecision
        store.loadState = .ready

        store.advanceSegment()

        XCTAssertEqual(store.state?.phase, .seasonDecision)
        XCTAssertNotNil(store.state?.pendingDecision)
        XCTAssertEqual(store.state?.decisionHistory?.count ?? 0, beforeDecision.snapshot.decisionHistory?.count ?? 0)
        XCTAssertTrue(ProCareerEngine.seasonDecisionWeeks.contains(store.state?.week ?? -1))
    }

    func testFailedProGameSettlementDoesNotEmitCompletionOrAdvanceWeeklyProgress() throws {
        let careerSync = isolatedSync("failed-pro-game")
        let weeklySync = isolatedSync("failed-pro-game-weekly")
        careerSync.clear()
        weeklySync.clear()
        defer {
            careerSync.clear()
            weeklySync.clear()
            GameAnalytics.eventSinkForTesting = nil
        }
        let eligibility = WeeklyProgramEligibility(
            hasHighSchoolCareer: false,
            remainingImportantGames: 0,
            remainingChapterAdvances: 0,
            canStartNextRun: false,
            canSelectPledge: false,
            canChooseDifferentSchool: false,
            hasProCareer: true
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let now = ISO8601DateFormatter().date(from: "2026-08-05T12:00:00Z")!
        let weekly = WeeklyProgramStore(sync: weeklySync, stableUserID: "failed-pro-game")
        weekly.configure(eligibility: eligibility, now: now, calendar: calendar)
        let sequenceBefore = weekly.program?.tasks.first {
            $0.kind == .sequenceMasteryTriggered
        }?.progress

        let store = MobileCareerStore(sync: careerSync, weekly: weekly)
        store.startNewCareer(preset: PitcherPresetCatalog.all[0], playerName: "실패 경계")
        let result = try XCTUnwrap(store.result)
        XCTAssertEqual(result.snapshot.phase, .weeklyPlan)
        let session = PitchSession(state: result.snapshot, seed: "99001")
        session.start()
        store.pitchSession = session
        var events: [GameAnalytics.Event] = []
        GameAnalytics.eventSinkForTesting = { event, _ in events.append(event) }

        store.finishImportantGame()

        XCTAssertEqual(store.state?.revision, result.snapshot.revision)
        XCTAssertTrue(try XCTUnwrap(store.pitchSession) === session, "저장되지 않은 이닝은 재시도할 수 있어야 합니다.")
        XCTAssertFalse(events.contains(.gameFinished))
        XCTAssertEqual(
            weekly.program?.tasks.first { $0.kind == .sequenceMasteryTriggered }?.progress,
            sequenceBefore
        )
        if case .failed = store.loadState {} else {
            XCTFail("잘못된 프로 국면의 경기 정산은 실패 상태여야 합니다.")
        }
    }

    func testAdvanceSaveFailureRollsBackStateUIWeeklyAndAchievementsThenRetryCommitsOnce() throws {
        let careerSync = isolatedSync("atomic-advance")
        let weeklySync = isolatedSync("atomic-advance-weekly")
        careerSync.clear()
        weeklySync.clear()
        defer {
            careerSync.clear()
            weeklySync.clear()
        }
        let weekly = configuredProWeekly(sync: weeklySync, stableUserID: "atomic-advance")
        let initial = try CareerBootstrap.startCareer(
            preset: PitcherPresetCatalog.all[0], playerName: "저장 재시도", seed: 91_001, engine: engine
        )
        var shouldFail = true
        var writeAttempts = 0
        let store = MobileCareerStore(sync: careerSync, weekly: weekly, saveWriter: { data in
            writeAttempts += 1
            return shouldFail ? false : careerSync.write(data)
        })
        store.result = initial
        store.selectedPlan = .recover
        store.lastSummary = "저장 전 화면"
        store.feedbackCue = .neutral
        store.loadState = .ready

        let weeklyBefore = weekly.program
        let gainsBefore = store.pendingGains
        let summaryBefore = store.lastSummary
        let cueBefore = store.feedbackCue
        let triggerBefore = store.feedbackTrigger
        let loadBefore = store.loadState
        let achievementsBefore = AchievementStore.shared.progress
        let freshAchievementsBefore = AchievementStore.shared.freshlyUnlocked

        store.advanceWeek()

        XCTAssertEqual(writeAttempts, 1)
        XCTAssertEqual(store.result, initial)
        XCTAssertEqual(store.pendingGains, gainsBefore)
        XCTAssertEqual(store.lastSummary, summaryBefore)
        XCTAssertEqual(store.feedbackCue, cueBefore)
        XCTAssertEqual(store.feedbackTrigger, triggerBefore)
        XCTAssertEqual(store.loadState, loadBefore)
        XCTAssertEqual(weekly.program, weeklyBefore)
        XCTAssertEqual(AchievementStore.shared.progress, achievementsBefore)
        XCTAssertEqual(AchievementStore.shared.freshlyUnlocked, freshAchievementsBefore)

        shouldFail = false
        store.advanceWeek()

        XCTAssertEqual(writeAttempts, 2)
        XCTAssertGreaterThan(store.state?.revision ?? 0, initial.snapshot.revision)
        let taskBefore = try XCTUnwrap(weeklyBefore?.tasks.first { $0.kind == .proWeeksAdvanced })
        let taskAfter = try XCTUnwrap(weekly.program?.tasks.first { $0.kind == .proWeeksAdvanced })
        XCTAssertEqual(taskAfter.progress, min(taskBefore.target, taskBefore.progress + 1))
        let reloaded = MobileCareerStore(sync: careerSync)
        reloaded.restoreOrCreateCareer()
        XCTAssertEqual(reloaded.result, store.result)
    }

    func testSeasonDecisionSaveFailureKeepsPendingChoiceAndEmitsNoEventThenRetryCommitsOnce() throws {
        let pendingResult = try firstDecision(seed: 91_002)
        let decision = try XCTUnwrap(pendingResult.snapshot.pendingDecision)
        let choice = decision.choices[0]
        let sync = isolatedSync("atomic-decision")
        sync.clear()
        defer {
            sync.clear()
            GameAnalytics.eventSinkForTesting = nil
        }
        var shouldFail = true
        var writeAttempts = 0
        let store = MobileCareerStore(sync: sync, saveWriter: { data in
            writeAttempts += 1
            return shouldFail ? false : sync.write(data)
        })
        store.result = pendingResult
        store.lastSummary = "결정 전 화면"
        store.loadState = .ready
        let achievementsBefore = AchievementStore.shared.progress
        let freshAchievementsBefore = AchievementStore.shared.freshlyUnlocked
        var events: [GameAnalytics.Event] = []
        GameAnalytics.eventSinkForTesting = { event, _ in events.append(event) }

        store.applySeasonDecision(decisionID: decision.id, choiceID: choice.id)

        XCTAssertEqual(writeAttempts, 1)
        XCTAssertEqual(store.result, pendingResult)
        XCTAssertEqual(store.lastSummary, "결정 전 화면")
        XCTAssertEqual(store.loadState, .ready)
        XCTAssertEqual(AchievementStore.shared.progress, achievementsBefore)
        XCTAssertEqual(AchievementStore.shared.freshlyUnlocked, freshAchievementsBefore)
        XCTAssertEqual(events.filter { $0 == .proSeasonDecisionSelected }.count, 0)

        shouldFail = false
        store.applySeasonDecision(decisionID: decision.id, choiceID: choice.id)

        XCTAssertEqual(writeAttempts, 2)
        XCTAssertEqual(store.state?.phase, .weeklyPlan)
        XCTAssertEqual(store.state?.decisionHistory?.last?.choiceID, choice.id)
        XCTAssertEqual(events.filter { $0 == .proSeasonDecisionSelected }.count, 1)
        store.applySeasonDecision(decisionID: decision.id, choiceID: choice.id)
        XCTAssertEqual(writeAttempts, 2)
        XCTAssertEqual(events.filter { $0 == .proSeasonDecisionSelected }.count, 1)
    }

    func testImportantGameCheckpointAndSettlementCommitOnlyAfterDurableSave() throws {
        let careerSync = isolatedSync("atomic-important-game")
        let weeklySync = isolatedSync("atomic-important-game-weekly")
        careerSync.clear()
        weeklySync.clear()
        defer {
            careerSync.clear()
            weeklySync.clear()
            GameAnalytics.eventSinkForTesting = nil
        }
        let weekly = configuredProWeekly(sync: weeklySync, stableUserID: "atomic-important-game")
        let important = try firstImportantGame(seed: 91_003)
        var shouldFail = true
        var writeAttempts = 0
        let store = MobileCareerStore(sync: careerSync, weekly: weekly, saveWriter: { data in
            writeAttempts += 1
            return shouldFail ? false : careerSync.write(data)
        })
        store.result = important
        store.lastSummary = "등판 전 화면"
        store.loadState = .ready

        store.beginImportantGame()

        XCTAssertEqual(writeAttempts, 1)
        XCTAssertEqual(store.result, important)
        XCTAssertNil(store.pitchSession)
        XCTAssertEqual(store.lastSummary, "등판 전 화면")
        XCTAssertEqual(store.loadState, .ready)

        shouldFail = false
        store.beginImportantGame()
        let session = try XCTUnwrap(store.pitchSession)
        let checkpointed = try XCTUnwrap(store.result)
        XCTAssertEqual(checkpointed.nextSeed, MobileCareerStore.advanced(important.nextSeed))
        XCTAssertNotEqual(checkpointed.nextSeed, important.nextSeed)

        for _ in 0..<40 {
            guard case .ready = session.stage else { break }
            session.throwPitch()
        }
        XCTAssertNotNil(session.resumeState(), "타석 경계 체크포인트가 있어야 resume 원자성을 검증할 수 있습니다.")

        let persistedCheckpoint = MobileCareerStore(sync: careerSync)
        persistedCheckpoint.restoreOrCreateCareer()
        XCTAssertEqual(persistedCheckpoint.result, checkpointed)
        XCTAssertNotNil(persistedCheckpoint.pitchSession)

        let weeklyBefore = weekly.program
        let achievementsBefore = AchievementStore.shared.progress
        let freshAchievementsBefore = AchievementStore.shared.freshlyUnlocked
        let summaryBefore = store.lastSummary
        let cueBefore = store.feedbackCue
        let triggerBefore = store.feedbackTrigger
        var events: [GameAnalytics.Event] = []
        GameAnalytics.eventSinkForTesting = { event, _ in events.append(event) }
        shouldFail = true

        store.finishImportantGame()

        XCTAssertEqual(store.result, checkpointed)
        XCTAssertTrue(try XCTUnwrap(store.pitchSession) === session)
        XCTAssertEqual(store.lastSummary, summaryBefore)
        XCTAssertEqual(store.feedbackCue, cueBefore)
        XCTAssertEqual(store.feedbackTrigger, triggerBefore)
        XCTAssertEqual(store.loadState, .ready)
        XCTAssertEqual(weekly.program, weeklyBefore)
        XCTAssertEqual(AchievementStore.shared.progress, achievementsBefore)
        XCTAssertEqual(AchievementStore.shared.freshlyUnlocked, freshAchievementsBefore)
        XCTAssertEqual(events.filter { $0 == .gameFinished }.count, 0)
        let reloadedAfterFailure = MobileCareerStore(sync: careerSync)
        reloadedAfterFailure.restoreOrCreateCareer()
        XCTAssertEqual(reloadedAfterFailure.result, checkpointed)
        XCTAssertNotNil(reloadedAfterFailure.pitchSession, "실패 전에 저장된 resume가 지워지면 안 됩니다.")

        shouldFail = false
        store.finishImportantGame()

        XCTAssertNil(store.pitchSession)
        XCTAssertGreaterThan(store.state?.revision ?? 0, checkpointed.snapshot.revision)
        XCTAssertEqual(events.filter { $0 == .gameFinished }.count, 1)
        let settled = store.result
        store.finishImportantGame()
        XCTAssertEqual(store.result, settled)
        XCTAssertEqual(events.filter { $0 == .gameFinished }.count, 1)
        let reloadedAfterSuccess = MobileCareerStore(sync: careerSync)
        reloadedAfterSuccess.restoreOrCreateCareer()
        XCTAssertEqual(reloadedAfterSuccess.result, settled)
        XCTAssertNil(reloadedAfterSuccess.pitchSession)
    }

    func testProReloadAppliesHigherRemoteTombstoneWithoutResurrection() throws {
        let sync = isolatedSync("pro-remote-tombstone")
        sync.clear()
        defer { sync.clear() }
        let live = try firstImportantGame(seed: 91_004)
        XCTAssertTrue(sync.write(try JSONEncoder().encode(
            MobileCareerStore.ProSaveRecord(
                result: live,
                sourceHighSchoolCareerID: "hs-source-for-tombstone",
                origin: .highSchool
            )
        )))
        let store = MobileCareerStore(sync: sync)
        store.restoreOrCreateCareer()
        XCTAssertEqual(store.result, live)
        XCTAssertEqual(store.sourceHighSchoolCareerID, "hs-source-for-tombstone")
        XCTAssertEqual(store.careerOrigin, .highSchool)
        XCTAssertEqual(store.loadState, .ready)
        store.beginImportantGame()
        XCTAssertNotNil(store.pitchSession)

        // beginImportantGame()이 만든 체크포인트보다 더 최신인 원격 삭제만 적용되어야 한다.
        let tombstoneRevision = live.snapshot.revision + 2
        XCTAssertTrue(sync.write(try JSONEncoder().encode(
            MobileCareerStore.ProSaveRecord(
                result: nil,
                deletedRevision: tombstoneRevision,
                schemaVersion: MobileCareerStore.currentSaveSchemaVersion,
                syncRevision: tombstoneRevision
            )
        )))

        store.reloadFromSync()

        XCTAssertNil(store.result)
        XCTAssertNil(store.pitchSession)
        XCTAssertNil(store.sourceHighSchoolCareerID)
        XCTAssertNil(store.careerOrigin)
        XCTAssertEqual(store.loadState, .needsSetup)
        // UI callbacks already queued before the remote reload must be harmless.
        store.finishImportantGame()
        store.abandonImportantGame()
        XCTAssertNil(store.result)
        XCTAssertEqual(store.loadState, .needsSetup)
        XCTAssertFalse(store.save(), "result가 없는 tombstone 상태를 옛 live로 저장하면 안 됩니다.")
        let reloaded = MobileCareerStore(sync: sync)
        reloaded.restoreOrCreateCareer()
        XCTAssertNil(reloaded.result)
        XCTAssertNil(reloaded.sourceHighSchoolCareerID)
        XCTAssertNil(reloaded.careerOrigin)
        XCTAssertEqual(reloaded.loadState, .needsSetup)
    }

    func testUnreadableProSaveFailsClosedWithoutPretendingCareerIsMissing() {
        let cloud = ProMemoryRemoteStore()
        let sync = SaveSync(
            key: "pro-unreadable-\(UUID().uuidString).json",
            store: cloud
        )
        sync.clear()
        defer { sync.clear() }
        let broken = Data("{not-a-save".utf8)
        XCTAssertTrue(sync.write(broken))

        let store = MobileCareerStore(sync: sync)
        store.restoreOrCreateCareer()

        guard case .failed(let message) = store.loadState else {
            return XCTFail("읽을 수 없는 저장을 신규 커리어로 보내면 안 됩니다.")
        }
        XCTAssertEqual(message, MobileCareerStore.unreadableSaveMessage)
        XCTAssertNil(store.result)
        XCTAssertEqual(cloud.data(forKey: sync.key), broken)
        XCTAssertEqual(
            sync.readRecovering(revision: { _ in nil }),
            .unreadable,
            "복원 실패 뒤에도 원본 바이트가 남아야 합니다."
        )
    }

    func testProSaveAutomaticallyRecoversLatestValidBackupAndHealsCloud() throws {
        let cloud = ProMemoryRemoteStore()
        let sync = SaveSync(
            key: "pro-backup-recovery-\(UUID().uuidString).json",
            store: cloud
        )
        sync.clear()
        defer { sync.clear() }
        let result = try firstDecision(seed: 91_101)
        let writer = MobileCareerStore(sync: sync)
        writer.result = result
        writer.loadState = .ready
        XCTAssertTrue(writer.save())
        XCTAssertTrue(writer.save(), "같은 스냅숏 체크포인트도 동기화 리비전은 전진해야 합니다.")
        let latestValid = try XCTUnwrap(cloud.data(forKey: sync.key))

        XCTAssertTrue(sync.write(Data("corrupted-current-generation".utf8)))
        let restored = MobileCareerStore(sync: sync)
        restored.restoreOrCreateCareer()

        XCTAssertEqual(restored.loadState, .ready)
        XCTAssertEqual(restored.result, result)
        XCTAssertTrue(restored.lastSummary?.contains("백업으로 복구") == true)
        XCTAssertEqual(cloud.data(forKey: sync.key), latestValid, "복구한 세이브가 iCloud도 치유해야 합니다.")
    }

    func testLegacyRawProSaveLoadsAndMigratesToCurrentSchema() throws {
        let cloud = ProMemoryRemoteStore()
        let sync = SaveSync(
            key: "pro-legacy-migration-\(UUID().uuidString).json",
            store: cloud
        )
        sync.clear()
        defer { sync.clear() }
        let legacy = try firstDecision(seed: 91_102)
        XCTAssertTrue(sync.write(try JSONEncoder().encode(legacy)))

        let store = MobileCareerStore(sync: sync)
        store.restoreOrCreateCareer()
        XCTAssertEqual(store.loadState, .ready)
        XCTAssertEqual(store.result, legacy)
        XCTAssertTrue(store.save())

        let migratedData = try XCTUnwrap(cloud.data(forKey: sync.key))
        let migrated = try JSONDecoder().decode(
            MobileCareerStore.ProSaveRecord.self,
            from: migratedData
        )
        XCTAssertEqual(migrated.schemaVersion, MobileCareerStore.currentSaveSchemaVersion)
        XCTAssertNotNil(migrated.syncRevision)
        XCTAssertEqual(migrated.result, legacy)
    }

    func testFutureProSchemaIsPreservedUntilACompatibleUpdateArrives() throws {
        let cloud = ProMemoryRemoteStore()
        let sync = SaveSync(
            key: "pro-future-schema-\(UUID().uuidString).json",
            store: cloud
        )
        sync.clear()
        defer { sync.clear() }
        let futureData = try JSONEncoder().encode(
            MobileCareerStore.ProSaveRecord(
                result: try firstDecision(seed: 91_104),
                schemaVersion: MobileCareerStore.currentSaveSchemaVersion + 1,
                syncRevision: 10_000
            )
        )
        XCTAssertTrue(sync.write(futureData))

        let store = MobileCareerStore(sync: sync)
        store.restoreOrCreateCareer()

        XCTAssertEqual(
            store.loadState,
            .failed(MobileCareerStore.unreadableSaveMessage)
        )
        XCTAssertEqual(cloud.data(forKey: sync.key), futureData)
        XCTAssertEqual(sync.readRecovering(revision: { _ in nil }), .unreadable)
    }

    func testNewCareerSyncRevisionStaysAbovePriorTombstone() throws {
        let cloud = ProMemoryRemoteStore()
        let sync = SaveSync(
            key: "pro-new-generation-\(UUID().uuidString).json",
            store: cloud
        )
        sync.clear()
        defer { sync.clear() }
        let store = MobileCareerStore(sync: sync)
        store.result = try firstDecision(seed: 91_103)
        store.loadState = .ready
        XCTAssertTrue(store.save())
        XCTAssertTrue(store.deleteCareer())
        let tombstoneData = try XCTUnwrap(cloud.data(forKey: sync.key))
        let tombstone = try JSONDecoder().decode(
            MobileCareerStore.ProSaveRecord.self,
            from: tombstoneData
        )

        XCTAssertTrue(store.startNewCareer(
            preset: PitcherPresetCatalog.all[0],
            playerName: "새 세대"
        ))
        let newCareerID = try XCTUnwrap(store.state?.proCareerID)
        let liveData = try XCTUnwrap(cloud.data(forKey: sync.key))
        let live = try JSONDecoder().decode(
            MobileCareerStore.ProSaveRecord.self,
            from: liveData
        )
        XCTAssertGreaterThan(live.effectiveRevision, tombstone.effectiveRevision)

        // 다른 기기가 늦게 올린 옛 묘비가 와도 새 세대가 이기고 cloud를 다시 치유한다.
        cloud.set(tombstoneData, forKey: sync.key)
        store.reloadFromSync()
        XCTAssertEqual(store.state?.proCareerID, newCareerID)
        XCTAssertEqual(cloud.data(forKey: sync.key), liveData)
    }

    func testTwentySeasonCareerPersistsAtEveryYearBoundary() throws {
        let cloud = ProMemoryRemoteStore()
        let sync = SaveSync(
            key: "pro-twenty-season-round-trip-\(UUID().uuidString).json",
            store: cloud
        )
        sync.clear()
        defer { sync.clear() }
        var result = try CareerBootstrap.startCareer(
            preset: PitcherPresetCatalog.all[0],
            playerName: "이십 시즌",
            seed: 20_020,
            engine: engine
        )
        var completedSeasons: [Int] = []

        for _ in 0..<1_200 {
            switch result.snapshot.phase {
            case .weeklyPlan:
                result = try engine.planWeek(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    plan: result.snapshot.fatigue > 70 ? .recover : .earnTrust
                ))
            case .seasonDecision:
                let decision = try XCTUnwrap(result.snapshot.pendingDecision)
                result = try engine.applySeasonDecision(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    decisionID: decision.id,
                    choiceID: decision.choices[0].id
                ))
            case .importantGame:
                result = try resolveImportantGame(result)
            case .seasonReview:
                let season = result.snapshot.season
                result = try engine.reviewSeason(.init(
                    seed: result.nextSeed,
                    state: result.snapshot
                ))
                result = try persistAndReload(result, sync: sync)
                completedSeasons.append(season)
                XCTAssertEqual(result.snapshot.careerStats.count, season)
                if season < ProCareerEngine.maximumCareerSeasons {
                    XCTAssertEqual(result.snapshot.phase, .offseasonDecision)
                } else {
                    XCTAssertEqual(result.snapshot.phase, .retirementDecision)
                }
            case .offseasonDecision:
                result = try engine.chooseOffseason(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    decision: .continueCareer
                ))
                result = try persistAndReload(result, sync: sync)
            case .retirementDecision:
                result = try engine.chooseOffseason(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    decision: .retire
                ))
                result = try persistAndReload(result, sync: sync)
            case .completed:
                XCTAssertEqual(
                    completedSeasons,
                    Array(1...ProCareerEngine.maximumCareerSeasons)
                )
                XCTAssertEqual(
                    result.snapshot.careerStats.count,
                    ProCareerEngine.maximumCareerSeasons
                )
                let encoded = try JSONEncoder().encode(
                    MobileCareerStore.ProSaveRecord(
                        result: result,
                        schemaVersion: MobileCareerStore.currentSaveSchemaVersion,
                        syncRevision: result.snapshot.revision
                    )
                )
                XCTAssertLessThan(encoded.count, 1_000_000)
                return
            default:
                XCTFail("예상하지 못한 프로 국면: \(result.snapshot.phase.rawValue)")
                return
            }
        }
        XCTFail("20시즌 저장 왕복 검사 한도를 넘었습니다.")
    }

    func testImportantGameAndRetirementCopyMatchesRecordedResults() {
        let report = ImportantInningReport(
            scenarioNumber: 3,
            pitches: 17,
            strikeouts: 2,
            walks: 1,
            runsAllowed: 2,
            expectedDamage: 500,
            actualDamage: 610,
            recommendationAccepted: 8
        )
        XCTAssertEqual(
            MobileCareerStore.importantGameSummary(report),
            "17구 · 2탈삼진 · 1볼넷 · 2실점"
        )
        XCTAssertEqual(MobileCareerStore.retirementDurationText(completedSeasons: 3), "3시즌")
        XCTAssertEqual(MobileCareerStore.retirementDurationText(completedSeasons: 0), "프로 첫 시즌")
    }

    func testAbandonImportantGameKeepsSessionUntilResumeRemovalIsDurable() throws {
        let sync = isolatedSync("atomic-abandon-important-game")
        sync.clear()
        defer { sync.clear() }
        let important = try firstImportantGame(seed: 91_005)
        var shouldFail = false
        let store = MobileCareerStore(sync: sync, saveWriter: { data in
            shouldFail ? false : sync.write(data)
        })
        store.result = important
        store.loadState = .ready
        store.beginImportantGame()
        let session = try XCTUnwrap(store.pitchSession)
        session.throwPitch()
        let summaryBefore = store.lastSummary
        let triggerBefore = store.feedbackTrigger

        shouldFail = true
        XCTAssertFalse(store.abandonImportantGame())
        XCTAssertTrue(try XCTUnwrap(store.pitchSession) === session)
        XCTAssertEqual(store.lastSummary, summaryBefore)
        XCTAssertEqual(store.feedbackTrigger, triggerBefore)

        shouldFail = false
        XCTAssertTrue(store.abandonImportantGame())
        XCTAssertNil(store.pitchSession)
        XCTAssertEqual(store.lastSummary, "등판을 중단했습니다. 다음 마운드는 새 이닝입니다.")
        XCTAssertFalse(store.abandonImportantGame())

        let reloaded = MobileCareerStore(sync: sync)
        reloaded.restoreOrCreateCareer()
        XCTAssertEqual(reloaded.result, store.result)
        XCTAssertNil(reloaded.pitchSession)
    }

    private func firstDecision(seed: UInt64) throws -> ProCareerResult {
        var result = try CareerBootstrap.startCareer(
            preset: PitcherPresetCatalog.all[0], playerName: "시즌 선택", seed: seed, engine: engine
        )
        for _ in 0..<120 {
            switch result.snapshot.phase {
            case .seasonDecision:
                return result
            case .weeklyPlan:
                result = try engine.planWeek(.init(
                    seed: result.nextSeed, state: result.snapshot, plan: .recover
                ))
            case .importantGame:
                result = try resolveImportantGame(result)
            case .seasonReview:
                result = try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
            case .offseasonDecision:
                result = try engine.chooseOffseason(.init(
                    seed: result.nextSeed, state: result.snapshot, decision: .continueCareer
                ))
            default:
                XCTFail("시즌 결정에 도달하기 전에 예상하지 못한 국면 \(result.snapshot.phase.rawValue)을 만났습니다.")
                return result
            }
        }
        throw SimulationError.invalidProCareer("시즌 결정 탐색 한도를 넘었습니다.")
    }

    private func stateImmediatelyBeforeDecision(seed: UInt64) throws -> ProCareerResult {
        var result = try CareerBootstrap.startCareer(
            preset: PitcherPresetCatalog.all[0], playerName: "자동 진행", seed: seed, engine: engine
        )
        for _ in 0..<120 {
            switch result.snapshot.phase {
            case .weeklyPlan:
                let advanced = try engine.planWeek(.init(
                    seed: result.nextSeed, state: result.snapshot, plan: .recover
                ))
                if advanced.snapshot.phase == .seasonDecision { return result }
                result = advanced
            case .importantGame:
                result = try resolveImportantGame(result)
            case .seasonReview:
                result = try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
            case .offseasonDecision:
                result = try engine.chooseOffseason(.init(
                    seed: result.nextSeed, state: result.snapshot, decision: .continueCareer
                ))
            default:
                XCTFail("결정 직전 상태를 찾는 동안 예상하지 못한 국면을 만났습니다.")
                return result
            }
        }
        throw SimulationError.invalidProCareer("결정 직전 상태 탐색 한도를 넘었습니다.")
    }

    private func firstImportantGame(seed: UInt64) throws -> ProCareerResult {
        var result = try CareerBootstrap.startCareer(
            preset: PitcherPresetCatalog.all[0], playerName: "원자적 등판", seed: seed, engine: engine
        )
        for _ in 0..<160 {
            switch result.snapshot.phase {
            case .importantGame:
                return result
            case .weeklyPlan:
                result = try engine.planWeek(.init(
                    seed: result.nextSeed, state: result.snapshot, plan: .recover
                ))
            case .seasonDecision:
                let decision = try XCTUnwrap(result.snapshot.pendingDecision)
                result = try engine.applySeasonDecision(.init(
                    seed: result.nextSeed, state: result.snapshot,
                    decisionID: decision.id, choiceID: decision.choices[0].id
                ))
            case .seasonReview:
                result = try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
            case .offseasonDecision:
                result = try engine.chooseOffseason(.init(
                    seed: result.nextSeed, state: result.snapshot, decision: .continueCareer
                ))
            default:
                XCTFail("중요 경기를 찾는 동안 예상하지 못한 국면을 만났습니다.")
                return result
            }
        }
        throw SimulationError.invalidProCareer("중요 경기 탐색 한도를 넘었습니다.")
    }

    private func configuredProWeekly(sync: SaveSync, stableUserID: String) -> WeeklyProgramStore {
        let weekly = WeeklyProgramStore(sync: sync, stableUserID: stableUserID)
        weekly.configure(eligibility: .init(
            hasHighSchoolCareer: false,
            remainingImportantGames: 0,
            remainingChapterAdvances: 0,
            canStartNextRun: false,
            canSelectPledge: false,
            canChooseDifferentSchool: false,
            hasProCareer: true
        ))
        return weekly
    }

    private func resolveImportantGame(_ result: ProCareerResult) throws -> ProCareerResult {
        try engine.resolveImportantGame(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            report: .init(
                scenarioNumber: result.snapshot.week,
                pitches: 18,
                strikeouts: 2,
                walks: 0,
                runsAllowed: 0,
                expectedDamage: 400,
                actualDamage: 240,
                recommendationAccepted: 12
            )
        ))
    }

    private func persistAndReload(
        _ result: ProCareerResult,
        sync: SaveSync
    ) throws -> ProCareerResult {
        let writer = MobileCareerStore(sync: sync)
        writer.restoreOrCreateCareer()
        writer.result = result
        writer.loadState = .ready
        XCTAssertTrue(writer.save())

        let reader = MobileCareerStore(sync: sync)
        reader.restoreOrCreateCareer()
        XCTAssertEqual(reader.loadState, .ready)
        XCTAssertEqual(reader.result, result)
        return try XCTUnwrap(reader.result)
    }

    private func isolatedSync(_ prefix: String) -> SaveSync {
        SaveSync(key: "\(prefix)-\(UUID().uuidString).json")
    }
}
