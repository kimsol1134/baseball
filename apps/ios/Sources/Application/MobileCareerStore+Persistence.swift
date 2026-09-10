import Foundation
import Observation
import SimulationCore
import BaseballIOSDomain
import BaseballIOSPersistence

extension MobileCareerStore {
    @discardableResult
    func save() -> Bool {
        guard let result else { return false }
        return persist(result: result, gameResume: gameResume)
    }

    /// 후보 상태 전체를 하나의 저장 레코드로 먼저 내린다. 관찰 상태는 호출자가 성공 뒤에만
    /// 교체하므로 write 실패가 result/seed/resume/UI에 부분적으로 보이지 않는다.
    func persist(
        result: ProCareerResult,
        gameResume: PitchResumeState?,
        pendingInjuryEvent: ProInjuryEventSnapshot? = nil,
        preservePendingInjuryEvent: Bool = true,
        acknowledgedInjuryEventID: String? = nil
    ) -> Bool {
        guard featureConfiguration.proCareerJourneyV1 || result.snapshot.journeyState == nil else {
            return false
        }
        let existing = capturePersisted()
        let candidateState = existing.drafting(result: result, gameResume: gameResume).withInjury(
            pending: preservePendingInjuryEvent
                ? (pendingInjuryEvent ?? existing.pendingInjuryEvent)
                : pendingInjuryEvent,
            acknowledgedID: acknowledgedInjuryEventID ?? existing.acknowledgedInjuryEventID
        )
        var candidateWithAlbum = foldingStagedReplays(into: candidateState)
        // 이 명령의 영수증을 같은 트랜잭션에 태운다. 저장이 성공해야 영수증도 남는다.
        if let operation = stagedCommandOperation {
            candidateWithAlbum.commandReceipts = CommandReceiptRetention.retaining(
                (candidateWithAlbum.commandReceipts ?? [])
                    + [receipt(for: operation, at: existing.result?.snapshot.revision ?? 0)]
            )
        }
        let schemaVersion = ProCareerPersistence.schemaVersion(for: candidateWithAlbum)
        guard canWrite() else { return false }
        let candidateRevision = ProCareerPersistence.nextRevision(
            after: syncedRevision,
            atLeast: result.snapshot.revision
        )
        let record = ProCareerPersistence.record(
            from: candidateWithAlbum,
            schemaVersion: schemaVersion,
            syncRevision: candidateRevision
        )
        guard let data = ProCareerPersistence.encode(record) else { return false }
        let didWrite = saveWriter?(data) ?? sync.write(data)
        guard didWrite else { return false }
        // 디스크가 받아들인 뒤에만 앨범을 커밋하고 대기열을 비운다. 실패하면 다음 저장에서
        // 다시 시도되므로 이번 등판의 공이 조용히 사라지지 않는다.
        var committed = candidateWithAlbum
        committed.syncedRevision = candidateRevision
        replacePersisted(committed)
        stagedReplays = []
        stagedCommandOperation = nil
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
    func applyHigherTombstoneDuringSession() -> Bool {
        guard let data = sync.read(
            revision: ProCareerPersistence.revision,
            conflictPriority: ProCareerPersistence.conflictPriority
        ),
        let record = ProCareerPersistence.decode(data),
        record.result == nil,
        let tombstone = record.deletedRevision ?? record.syncRevision,
        tombstone >= syncedRevision else { return false }

        applyTombstone(revision: tombstone)
        lastSummary = nil
        loadState = .needsSetup
        return true
    }

    func applyTombstone(revision: UInt64) {
        replacePersisted(ProCareerPersistedState(
            result: nil,
            gameResume: nil,
            sourceHighSchoolCareerID: nil,
            careerOrigin: nil,
            syncedRevision: revision
        ))
        clearLiveSession()
    }

    func clearLiveSession() {
        updatePersisted { $0.gameResume = nil }
        pitchSession = nil
        pendingGains = []
    }

    private static func shouldAutoMigrateJourney(on state: ProCareerSnapshot) -> Bool {
        switch state.phase {
        case .offseasonDecision, .retirementDecision:
            return true
        default:
            return false
        }
    }

    /// 이 빌드가 해석하지 못하는 더 새로운 세대의 저장만 보호한다. 후보 레코드의 스탬프는
    /// 하위 호환용 "최소 필요 버전"이라 기존 저장보다 낮을 수 있다 — 스탬프끼리 비교하면
    /// 부상 확인이 durable로 남은 v5 라이브 저장을 v4 묘비가 못 덮고(은퇴 정리 불가),
    /// v5 묘비를 mastery 없는 새 커리어(v4)가 못 덮는다(다음 프로 진입 불가). 두 교착 모두
    /// "저장 공간을 확인" 문구로 표면화되어 실제 여유 공간과 무관하게 진행이 막힌다.
    func canWrite() -> Bool {
        // An injected writer is a fully isolated persistence boundary used by unit tests and
        // failure injection. Consulting the real default SaveSync beside it leaks unrelated
        // device state into the test and can reject a perfectly valid candidate schema.
        if saveWriter != nil { return true }
        guard let existingData = sync.read(
            revision: ProCareerPersistence.rawSchemaVersion,
            conflictPriority: { _ in 0 }
        ),
        let existingVersion = ProCareerPersistence.rawSchemaVersion(existingData) else {
            return true
        }
        return existingVersion <= UInt64(ProCareerPersistence.currentSchemaVersion)
    }

    func restore() -> RestoreOutcome {
        let recovered: Bool
        let data: Data
        switch sync.readRecovering(
            revision: ProCareerPersistence.revision,
            conflictPriority: ProCareerPersistence.conflictPriority
        ) {
        case .missing:
            return .needsSetup
        case .unreadable:
            return .unavailable
        case .value(let candidate, let source):
            data = candidate
            recovered = source == .backup
        }
        guard let record = ProCareerPersistence.decode(data) else { return .unavailable }
        if record.result == nil,
           let tombstone = record.deletedRevision ?? record.syncRevision {
            applyTombstone(revision: tombstone)
            return .needsSetup
        }
        guard let decoded = record.result else { return .unavailable }
        var next = ProCareerPersistence.materialize(record)
        next.syncedRevision = max(syncedRevision, next.syncedRevision)
        if next.pendingInjuryEvent == nil,
           let event = decoded.injuryEvent,
           next.acknowledgedInjuryEventID != event.stableID {
            next.pendingInjuryEvent = event
        }
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
                    let migrationRevision = ProCareerPersistence.nextRevision(
                        after: next.syncedRevision,
                        atLeast: migrated.snapshot.revision
                    )
                    next.result = migrated
                    next.syncedRevision = migrationRevision
                    let migratedRecord = ProCareerPersistence.record(
                        from: next,
                        schemaVersion: ProCareerPersistence.journeySchemaVersion,
                        syncRevision: migrationRevision
                    )
                    guard let migrationData = ProCareerPersistence.encode(migratedRecord),
                          sync.write(migrationData) else {
                        return .unavailable
                    }
                    restored = migrated
                }
            } catch {
                return .unavailable
            }
        }
        // 유료앱에서는 앱 자체가 구매 증거다. 저장된 스냅숏의 권한 출처(개발 빌드 포함)를 이유로
        // 진행을 버리면 TestFlight 사용자의 커리어만 사라진다.
        next.result = restored
        replacePersisted(next)
        clearLiveSession()
        // 등판 도중 내려간 앱 — 타석 경계에서 이어 던진다(고교와 같은 검사).
        if restored.snapshot.phase == .importantGame,
           let resume = record.gameResume,
           PitchScenario.pro(state: restored.snapshot).id == resume.scenarioID {
            let session = PitchSession(state: restored.snapshot, seed: resume.seed)
            session.replaySeason = restored.snapshot.season
            session.replayWeek = restored.snapshot.week
            session.replayOutingNumber = (restored.snapshot.gameLines?.count ?? 0) + 1
            session.start()
            session.restore(from: resume)
            attachCheckpoint(session)
            updatePersisted { $0.gameResume = resume }
            pitchSession = session
        }
        return .live(recoveredFromBackup: recovered)
    }

    func attachCheckpoint(_ session: PitchSession) {
        session.onCheckpoint = { [weak self] session in
            guard let self, let result = self.result else { return }
            let resume = session.resumeState()
            guard self.persist(result: result, gameResume: resume) else { return }
            self.updatePersisted { $0.gameResume = resume }
        }
    }

    /// - Parameter operation: 이 명령을 뭐라고 부르는가. 주면 **같은 명령이 두 번 적용되지
    ///   않는다** — 버튼이 두 번 눌리거나 저장이 재시도돼도 한 번만 간다(7-D).
    @discardableResult
    func perform(
        summary: String? = nil,
        cue: FeedbackCue? = nil,
        clearGameResumeOnSuccess: Bool = false,
        operation: String? = nil,
        _ action: () throws -> ProCareerResult
    ) -> Bool {
        // 영수증은 상태를 바꾸기 전에 본다. 명령을 실행한 뒤에 거절하면 이미 늦었다.
        if let operation, !acceptsCommand(operation) { return false }
        stagedCommandOperation = operation
        // 저장이 실패했거나 규칙이 거절했으면 이 명령의 영수증을 다음 저장에 얹지 않는다.
        defer { stagedCommandOperation = nil }
        do {
            let before = result?.snapshot
            guard featureConfiguration.proCareerJourneyV1 || before?.journeyState == nil else {
                return false
            }
            let updated = try action()
            let gains = Self.gains(before: before?.pitcher, after: updated.snapshot.pitcher)
            let nextSummary = summary ?? progressSummary(before: before, after: updated.snapshot)
            let nextCue = cue ?? (updated.injuryEvent != nil
                ? .setback
                : gains.isEmpty ? .neutral : .growth)
            let nextResume = clearGameResumeOnSuccess ? nil : gameResume
            let pendingForWrite = updated.injuryEvent ?? pendingInjuryEvent
            guard persist(
                result: updated,
                gameResume: nextResume,
                pendingInjuryEvent: pendingForWrite
            ) else { return false }

            // 디스크가 후보 상태를 받아들인 뒤에만 관찰 상태와 외부 부수효과를 커밋한다.
            updatePersisted {
                $0.result = updated
                $0.gameResume = nextResume
                $0.pendingInjuryEvent = pendingForWrite
            }
            if let injury = updated.injuryEvent {
                let forecast = ProWeekHealthForecast.forecast(state: before ?? updated.snapshot, plan: injury.plan)
                CareerTelemetry.log(.injuryStarted, [
                    "mode": "pro",
                    "cause": injury.cause.rawValue,
                    "recovery_weeks": injury.recoveryWeeks,
                    "risk_band": forecast.band.rawValue,
                    "plan": injury.plan.rawValue,
                ])
            }
            Self.logMasteryChanges(before: before?.pitcher, after: updated.snapshot.pitcher, mode: "pro")
            // 직접 경기처럼 이번 행동 자체에는 성장이 없어도, 직전 주간 훈련에서 아직
            // 확인하지 않은 성장을 지우면 실제 능력 상승까지 사라진 것처럼 보인다.
            // 사용자가 확인할 때까지 기존 영수증을 보존하고 같은 능력의 연속 성장은 합친다.
            pendingGains = Self.mergingGains(pendingGains, gains)
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
}
