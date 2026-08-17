import Foundation
import SimulationCore

extension HighSchoolCareerStore {
    // MARK: - 저장

    @discardableResult
    func save() -> Bool {
        persist(
            result: result,
            gameResume: gameResume,
            chronicle: chronicle,
            responseTally: responseTally,
            bondMemories: bondMemories,
            nextRunIntent: nextRunIntent
        )
    }

    struct PersistenceOverrides {
        let nicknames: [Nickname]
        let goalCelebratedChapter: Int?
        let currentCareerRetention: CurrentCareerRetention?
        let pendingGameCompletion: PendingGameCompletion?
    }

    /// 후보 SaveRecord를 먼저 쓴다. 호출자는 true 뒤에만 관찰 상태/UserDefaults를 바꾼다.
    func persist(
        result candidateResult: HighSchoolCareerResult?,
        gameResume candidateGameResume: PitchSession.ResumeState?,
        chronicle candidateChronicle: [ChronicleEntry],
        responseTally candidateResponseTally: ResponseTally,
        bondMemories candidateBondMemories: [PlayerBondMemory]? = nil,
        rebirthEventIDs candidateRebirthEventIDs: [String]? = nil,
        nextRunIntent candidateNextRunIntent: NextRunIntent?,
        currentCareerRetention retentionOverride: CurrentCareerRetention? = nil,
        overrides: PersistenceOverrides? = nil
    ) -> Bool {
        // 진행이 없어도 계승분과 아카이브는 쓴다. 이게 없으면 회차 사이(기억 확정 후 ~
        // 새 선수 생성 전)에 앱이 내려갈 때 환생 진행 전체가 사라진다.
        let candidateRevision = Self.nextSavedRevision(
            after: savedRevision,
            atLeast: candidateResult?.snapshot.revision ?? 0
        )
        let currentCareerRetention = overrides?.currentCareerRetention
            ?? retentionOverride ?? candidateResult.map { current in
            retentionEnvelope(for: current.snapshot, rivalLedger: rivalLedger)
        }
        let persistedNicknames = overrides?.nicknames ?? nicknames
        let persistedGoalCelebratedChapter = overrides.map(\.goalCelebratedChapter)
            ?? goalCelebratedChapter
        let persistedPendingGameCompletion = overrides.map(\.pendingGameCompletion)
            ?? pendingGameCompletion
        let record = SaveRecord(
            result: candidateResult,
            inheritance: inheritance,
            archive: archive,
            enteredProCareerID: enteredProCareerID,
            nicknames: persistedNicknames.isEmpty ? nil : persistedNicknames,
            chronicle: candidateChronicle.isEmpty ? nil : candidateChronicle,
            chapterStartStrikeouts: chapterStartStrikeouts,
            goalCelebratedChapter: persistedGoalCelebratedChapter,
            responseTally: candidateResponseTally,
            bondMemories: Self.normalizedBondMemories(candidateBondMemories ?? bondMemories).isEmpty
                ? nil : Self.normalizedBondMemories(candidateBondMemories ?? bondMemories),
            rebirthEventIDs: (candidateRebirthEventIDs ?? rebirthEventIDs).isEmpty
                ? nil : Array((candidateRebirthEventIDs ?? rebirthEventIDs).suffix(6)),
            chapterGains: chapterGains.isEmpty ? nil : chapterGains,
            chapterTrainingCount: chapterTrainingCount == 0 ? nil : chapterTrainingCount,
            careerStartingPitcher: careerStartingPitcher,
            signatureLegacyRulesVersion: signatureLegacyRulesVersion,
            frozenSignatureLegacyCandidates: frozenSignatureLegacyCandidates,
            selectedSignatureLegacyID: selectedSignatureLegacyID,
            gameResume: candidateGameResume,
            challengeCareerID: challengeCareerID,
            nextRunIntent: candidateNextRunIntent,
            creditedExternalRewardIDs: creditedExternalRewardIDs.isEmpty ? nil : creditedExternalRewardIDs,
            currentCareerRetention: currentCareerRetention,
            pendingGameCompletion: persistedPendingGameCompletion,
            revision: candidateRevision,
            schemaVersion: Self.currentSaveSchemaVersion
        )
        guard let data = try? JSONEncoder().encode(record),
              saveWriter?(data) ?? sync.write(data) else {
            return false
        }
        savedRevision = candidateRevision
        return true
    }

    /// 다른 기기에서 진행이 올라왔을 때 다시 읽는다.
    func reloadFromSync() {
        if pitchSession != nil || tutorialSession != nil {
            _ = applyHigherResultlessRecordDuringSession()
            return
        }
        let currentRevision = savedRevision
        let outcome = restore()
        switch outcome {
        case .live(let recoveredFromBackup):
            guard savedRevision > currentRevision || recoveredFromBackup else { return }
            loadState = .ready
            _ = retryPendingGameCompletion()
            lastSummary = recoveredFromBackup
                ? "iCloud 환생 기록을 읽지 못해 직전 정상 백업으로 복구했습니다."
                : "다른 기기의 진행을 불러왔습니다."
            feedbackTrigger += 1
        case .needsSetup:
            // A higher result-less record is either a remote deletion tombstone or the durable
            // between-lives state. In both cases the old live player must disappear immediately.
            loadState = .needsSetup
            lastSummary = nil
        case .unavailable:
            if result == nil {
                loadState = .failed(Self.unreadableSaveMessage)
            } else {
                lastSummary = "iCloud 환생 기록을 읽지 못해 이 기기의 진행을 유지합니다."
                feedbackCue = .setback
                feedbackTrigger += 1
            }
        }
    }

    /// 다른 기기의 더 높은 삭제/회차-사이 레코드는 진행 중 이닝보다 우선한다.
    /// live 진행은 이닝을 보존하기 위해 갈아끼우지 않지만, result가 없는 권위 레코드를
    /// 무시하면 이닝 종료 저장이 삭제된 선수를 다시 iCloud에 올릴 수 있다.
    @discardableResult
    private func applyHigherResultlessRecordDuringSession() -> Bool {
        guard let data = sync.read(
            revision: Self.saveRevision,
            conflictPriority: Self.saveConflictPriority
        ),
        let record = Self.decodeSaveRecord(data),
        record.result == nil,
        record.effectiveRevision >= savedRevision else { return false }

        let removedCareerID = result?.snapshot.careerID
        inheritance = record.inheritance
        if inheritance.soulTotalEarned == nil { inheritance.soulTotalEarned = inheritance.soulPoints }
        if inheritance.automaticSoulEarned == nil {
            inheritance.automaticSoulEarned = inheritance.soulTotal
        }
        archive = record.archive ?? []
        enteredProCareerID = record.enteredProCareerID
        nicknames = record.nicknames ?? []
        chronicle = record.chronicle ?? []
        chapterStartStrikeouts = record.chapterStartStrikeouts ?? 0
        goalCelebratedChapter = record.goalCelebratedChapter
        responseTally = record.responseTally ?? ResponseTally()
        bondMemories = Self.normalizedBondMemories(record.bondMemories ?? [])
        rebirthEventIDs = record.rebirthEventIDs ?? []
        chapterGains = record.chapterGains ?? [:]
        chapterTrainingCount = record.chapterTrainingCount ?? 0
        careerStartingPitcher = record.careerStartingPitcher
        signatureLegacyRulesVersion = record.signatureLegacyRulesVersion
        frozenSignatureLegacyCandidates = record.frozenSignatureLegacyCandidates
        selectedSignatureLegacyID = record.selectedSignatureLegacyID
        challengeCareerID = record.challengeCareerID
        nextRunIntent = record.nextRunIntent
        creditedExternalRewardIDs = record.creditedExternalRewardIDs ?? []
        pendingGameCompletion = record.pendingGameCompletion
        savedRevision = record.effectiveRevision
        result = nil
        pitchSession = nil
        tutorialSession = nil
        gameResume = nil
        pendingGains = []
        trainingReceipt = nil
        pendingBloom = nil
        pendingRecap = nil
        selectedMemories = []
        loadState = .needsSetup
        lastSummary = nil
        if let removedCareerID {
            UserDefaults.standard.removeObject(forKey: pledgeKey(removedCareerID))
            UserDefaults.standard.removeObject(forKey: pledgeRulesVersionKey(removedCareerID))
            UserDefaults.standard.removeObject(forKey: rivalLedgerKey(removedCareerID))
        }
        return true
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
        /// Structured relationship memories. Missing old saves continue with an empty list.
        var bondMemories: [PlayerBondMemory]? = nil
        /// Stable IDs of rebirth scenes already consumed in the live run.
        var rebirthEventIDs: [String]? = nil
        /// 이번 챕터의 훈련 성장 정산. 없으면 챕터 리뷰가 "훈련 없이 지나간 챕터"라고
        /// 방금 한 플레이를 부정한다(3차 패널 P1) — 옛 저장본은 빈 값으로 시작한다.
        var chapterGains: [String: Int]? = nil
        var chapterTrainingCount: Int? = nil
        /// 이번 회차의 직접 성장량 기준과 아직 확정하지 않은 대표 유산 선택.
        /// 모두 optional이라 기능 도입 전 저장본은 그대로 열린다.
        var careerStartingPitcher: PitcherSnapshot? = nil
        var signatureLegacyRulesVersion: Int? = nil
        var frozenSignatureLegacyCandidates: [CareerSignatureLegacy]? = nil
        var selectedSignatureLegacyID: CareerSignatureLegacyID? = nil
        /// 진행 중 등판의 타석 경계 스냅샷. 없는 옛 저장본은 nil이다.
        var gameResume: PitchSession.ResumeState? = nil
        /// 진행 중 challenge 모드의 careerID. 없는 옛 저장본은 nil = 비도전이다.
        var challengeCareerID: String? = nil
        /// 지난 회차에서 직접 저장한 재도전 목표. 없는 옛 저장본은 추천 없음이다.
        var nextRunIntent: NextRunIntent? = nil
        /// 외부 보상 중복 지급 방지 영수증. 없는 옛 저장본은 빈 집합이다.
        var creditedExternalRewardIDs: Set<String>? = nil
        /// 현재 회차의 약속 결정·숙적 원장. 없는 옛 저장본은 기존 UserDefaults를 migration
        /// source로 사용하고, 다음 저장부터 이 필드에 함께 싣는다.
        var currentCareerRetention: CurrentCareerRetention? = nil
        /// 경기 코어 결과는 저장됐지만 주간·분석·업적 후속 작업이 남은 영수증.
        /// 없는 옛 저장본은 미처리 작업이 없는 것으로 읽는다.
        var pendingGameCompletion: PendingGameCompletion? = nil
        /// 계승-전용 레코드의 충돌 판정용. 없는 옛 저장본은 진행의 리비전으로 판정한다.
        var revision: UInt64?
        /// nil은 버전 필드 도입 전 저장이다. 미래 버전은 덮지 않고 업데이트를 기다린다.
        var schemaVersion: Int? = nil

        var effectiveRevision: UInt64 {
            max(revision ?? 0, result?.snapshot.revision ?? 0)
        }
    }

    /// 같은 리비전에서 다른 기기의 live 진행과 삭제/회차-사이 레코드가 충돌하면
    /// result-less 쪽이 이긴다. stable ID나 문구가 아니라 저장 의미만 본다.
    private static func saveConflictPriority(_ data: Data) -> Int {
        guard let record = decodeSaveRecord(data) else {
            return 0
        }
        return record.result == nil ? 1 : 0
    }

    enum RestoreOutcome: Equatable {
        case live(recoveredFromBackup: Bool)
        case needsSetup
        case unavailable
    }

    static func nextSavedRevision(after current: UInt64, atLeast minimum: UInt64) -> UInt64 {
        let incremented = current == UInt64.max ? UInt64.max : current + 1
        return max(incremented, minimum)
    }

    private static func decodeSaveRecord(_ data: Data) -> SaveRecord? {
        guard let record = try? JSONDecoder().decode(SaveRecord.self, from: data) else {
            return nil
        }
        let version = record.schemaVersion ?? 1
        guard (1...currentSaveSchemaVersion).contains(version) else { return nil }
        return record
    }

    private static func saveRevision(_ data: Data) -> UInt64? {
        decodeSaveRecord(data)?.effectiveRevision
    }

    func restore() -> RestoreOutcome {
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
        inheritance = record.inheritance
        // 분리 회계 마이그레이션 — 총량 필드가 없는 옛 저장본은 잔액을 총량으로 승계한다.
        // 이 한 줄이 없으면 첫 구매 순간 평생 총량이 잔액으로 붕괴한다(3차 패널 P0).
        if inheritance.soulTotalEarned == nil { inheritance.soulTotalEarned = inheritance.soulPoints }
        if inheritance.automaticSoulEarned == nil {
            inheritance.automaticSoulEarned = inheritance.soulTotal
        }
        archive = record.archive ?? []
        enteredProCareerID = record.enteredProCareerID
        nicknames = record.nicknames ?? []
        chronicle = record.chronicle ?? []
        chapterStartStrikeouts = record.chapterStartStrikeouts
            ?? record.result?.snapshot.performance.strikeouts ?? 0
        goalCelebratedChapter = record.goalCelebratedChapter
        responseTally = record.responseTally ?? ResponseTally()
        bondMemories = Self.normalizedBondMemories(record.bondMemories ?? [])
        rebirthEventIDs = record.rebirthEventIDs ?? []
        chapterGains = record.chapterGains ?? [:]
        chapterTrainingCount = record.chapterTrainingCount ?? 0
        careerStartingPitcher = record.careerStartingPitcher
        signatureLegacyRulesVersion = record.signatureLegacyRulesVersion
        frozenSignatureLegacyCandidates = record.frozenSignatureLegacyCandidates
        selectedSignatureLegacyID = record.selectedSignatureLegacyID
        challengeCareerID = record.challengeCareerID
        nextRunIntent = record.nextRunIntent
        creditedExternalRewardIDs = record.creditedExternalRewardIDs ?? []
        pendingGameCompletion = record.pendingGameCompletion
        savedRevision = record.effectiveRevision
        // Clear every live-only observation before branching on result. Without this, a higher
        // remote tombstone updates the revision but leaves the old player/session in memory and a
        // later save can publish that deleted player again.
        result = nil
        pitchSession = nil
        tutorialSession = nil
        gameResume = nil
        pendingGains = []
        trainingReceipt = nil
        pendingBloom = nil
        pendingRecap = nil
        selectedMemories = []
        buzz = []
        worldNews = []
        // 진행이 없는 레코드는 "회차 사이"다 — 계승분만 안고 새 선수 만들기로 간다.
        guard let saved = record.result else { return .needsSetup }
        result = saved
        if let retention = record.currentCareerRetention,
           retention.careerID == saved.snapshot.careerID {
            mirrorRetention(retention)
        }
        // 등판 도중에 내려간 앱 — 타석 경계에서 이어 던진다. 시나리오가 지금 스냅샷에서
        // 같은 id로 재구성될 때만 복원한다(스냅샷이 달라졌으면 그 이닝은 이미 다른 세계다).
        if saved.snapshot.phase == .importantGame,
           let resume = record.gameResume,
           PitchScenario.highSchool(state: saved.snapshot).id == resume.scenarioID {
            // 이 필드가 없던 버전은 모든 고교 승부가 최대 4타자였다. 새 2/5/6타자
            // 규칙으로 재계산하면 저장 뒤 재접속만으로 같은 경기의 길이가 달라진다.
            let savedMaximumBatters = max(1, min(6, resume.maximumBatters ?? 4))
            let scenario = PitchScenario.highSchool(
                state: saved.snapshot,
                maximumBattersOverride: savedMaximumBatters
            )
            let session = PitchSession(scenario: scenario, seed: resume.seed)
            session.start()
            session.restore(from: resume)
            session.trait = personality?.trait
            attachCheckpoint(session)
            gameResume = resume
            pitchSession = session
        }
        return .live(recoveredFromBackup: recovered)
    }

    /// 세션의 타석 경계마다 진행을 디스크로. 등판이 통째로 날아가는 일은 유료 게임의
    /// 환불 사유다 — 체크포인트는 타석 단위라 리트라이 스커밍도 열리지 않는다.
    func attachCheckpoint(_ session: PitchSession) {
        session.onCheckpoint = { [weak self] session in
            guard let self, let result = self.result else { return }
            let resume = session.resumeState()
            guard self.persist(
                result: result,
                gameResume: resume,
                chronicle: self.chronicle,
                responseTally: self.responseTally,
                nextRunIntent: self.nextRunIntent
            ) else { return }
            self.gameResume = resume
        }
    }

    /// 등판 중단 — 지금까지의 이닝을 버린다. 시드는 이미 넘어가 있어 같은 이닝의
    /// 리트라이는 아니다(안티치트 설계 그대로).
    @discardableResult
    func abandonImportantGame() -> Bool {
        guard let result, pitchSession != nil else { return false }
        guard persist(
            result: result,
            gameResume: nil,
            chronicle: chronicle,
            responseTally: responseTally,
            nextRunIntent: nextRunIntent
        ) else { return false }
        // 손맛 구간에서 나간 사람. 국면 계측이 "중요 경기에 들어갔다"까지만 알려 주므로,
        // 들어가서 던지다 나간 것과 화면만 보고 나간 것을 여기서 가른다.
        if countsTowardWeeklyProgram {
            GameAnalytics.log(.gameAbandoned, [
                "pitches": pitchSession?.pitches ?? 0,
                "chapter": result.snapshot.chapter.number,
                "life_number": result.snapshot.lifeNumber,
                "act_number": HighSchoolPresentation.actNumber(
                    chapter: result.snapshot.chapter.number
                ),
                "phase": result.snapshot.phase.rawValue,
                "development_rules_version": result.snapshot.balanceVersion ?? 1,
                "games_completed": result.snapshot.performance.importantGamesCompleted,
            ])
        }
        pitchSession = nil
        gameResume = nil
        lastSummary = "등판을 중단했습니다. 다음 마운드는 새 이닝입니다."
        feedbackCue = .setback
        feedbackTrigger += 1
        return true
    }

    @discardableResult
    func perform(
        summary: String? = nil,
        cue: MobileCareerStore.FeedbackCue? = nil,
        clearGameResumeOnSuccess: Bool = false,
        responseTally candidateResponseTally: ResponseTally? = nil,
        appendingChronicle additionalChronicle: [ChronicleEntry] = [],
        bondMemory memoryFactory: ((HighSchoolCareerSnapshot, HighSchoolCareerSnapshot) -> PlayerBondMemory?)? = nil,
        _ action: (HighSchoolCareerResult) throws -> HighSchoolCareerResult
    ) -> Bool {
        guard let current = result else { return false }
        do {
            let before = current.snapshot
            let updated = try action(current)
            let gains = MobileCareerStore.gains(
                before: before.pitcher, after: updated.snapshot.pitcher
            )
            var bloom = pendingBloom
            var candidateChronicle = chronicle + additionalChronicle
            // 이번 동작에서 새로 만개했는가. 훈련 번호가 바뀐 것만 센다 — 안 그러면 같은
            // 훈련 결과를 들고 있는 동안 화면을 넘길 때마다 축하가 다시 뜬다.
            if let training = updated.snapshot.lastTraining,
               training.number != before.lastTraining?.number,
               let ability = training.bloomedAbility, let grade = training.bloomedGrade {
                bloom = Bloom(ability: ability, grade: grade)
                candidateChronicle.append(ChronicleEntry(
                    stage: "\(updated.snapshot.chapter.schoolYear)학년 \(updated.snapshot.chapter.season)",
                    text: "만개 — 막혀 있던 \(ability.label) 재능이 \(grade.label)까지 열렸습니다."
                ))
            }
            let nextSummary = summary ?? Self.progressSummary(before: before, after: updated.snapshot)
            let nextCue = cue ?? (gains.isEmpty ? .neutral : .growth)
            let nextResponseTally = candidateResponseTally ?? responseTally
            let previousBondMemories = Self.normalizedBondMemories(bondMemories)
            var nextBondMemories = previousBondMemories
            var createdBondMemory: PlayerBondMemory?
            if let memory = memoryFactory?(before, updated.snapshot) {
                nextBondMemories = Self.appendingBondMemory(memory, to: previousBondMemories)
                if !previousBondMemories.contains(where: { $0.id == memory.id }),
                   nextBondMemories.contains(where: { $0.id == memory.id }) {
                    createdBondMemory = memory
                }
            }
            var nextRebirthEventIDs = rebirthEventIDs
            if let event = before.currentRelationshipEvent,
               event.category == "rebirth",
               updated.snapshot.lastRelationship?.number != before.lastRelationship?.number,
               !nextRebirthEventIDs.contains(event.id) {
                nextRebirthEventIDs.append(event.id)
                nextRebirthEventIDs = Array(nextRebirthEventIDs.suffix(6))
            }
            let nextResume = clearGameResumeOnSuccess ? nil : gameResume
            guard persist(
                result: updated,
                gameResume: nextResume,
                chronicle: candidateChronicle,
                responseTally: nextResponseTally,
                bondMemories: nextBondMemories,
                rebirthEventIDs: nextRebirthEventIDs,
                nextRunIntent: nextRunIntent
            ) else { return false }

            result = updated
            gameResume = nextResume
            responseTally = nextResponseTally
            bondMemories = nextBondMemories
            rebirthEventIDs = nextRebirthEventIDs
            pendingGains = gains
            pendingBloom = bloom
            chronicle = candidateChronicle
            lastSummary = nextSummary
            feedbackCue = nextCue
            feedbackTrigger += 1
            loadState = .ready
            if let createdBondMemory {
                let relationshipTarget = switch createdBondMemory.eventCategory {
                case "coach", "catcher", "rival": createdBondMemory.eventCategory
                default: "none"
                }
                GameAnalytics.log(.bondMemoryCreated, [
                    "kind": createdBondMemory.kind.rawValue,
                    "event_id": createdBondMemory.eventID,
                    "response_id": createdBondMemory.response.rawValue,
                    "relationship_target": relationshipTarget,
                    "life_number": updated.snapshot.lifeNumber,
                ])
            }
            // 국면 진입과 업적은 durable save가 성공한 뒤에만 외부로 보낸다.
            if updated.snapshot.phase != before.phase, !isChallengeRun {
                GameAnalytics.log(.phaseEntered, [
                    "phase": updated.snapshot.phase.rawValue,
                    "chapter": updated.snapshot.chapter.number,
                    "act_number": HighSchoolPresentation.actNumber(
                        chapter: updated.snapshot.chapter.number
                    ),
                    "life_number": updated.snapshot.lifeNumber,
                ])
            }
            // challenge 모드는 업적도 쌓지 않는다 — "기록에 남지 않습니다"는 업적 포함이다.
            if !isChallengeRun {
                AchievementStore.shared.record(AchievementRules.fromHighSchool(updated.snapshot))
            }
            return true
        } catch {
            loadState = .failed(error.localizedDescription)
            return false
        }
    }

    nonisolated static func progressSummary(before: HighSchoolCareerSnapshot, after: HighSchoolCareerSnapshot) -> String {
        if let training = after.lastTraining, training.number != before.lastTraining?.number {
            return training.feedback
        }
        if let relationship = after.lastRelationship, relationship.number != before.lastRelationship?.number {
            // relationship.category는 신뢰 회계용 채널이라 집·취재·팬 장면도 coach/catcher로
            // 접힌다 — 그대로 화자를 만들면 없는 자리의 감독이 "웃었다"(4차 패널 P1).
            // 원본 장면의 카테고리(방금 소비된 이벤트)가 핵심 3인일 때만 반응을 붙인다.
            // 화자·이름은 **원본 카테고리**에서 뽑는다. relationship.category는 신뢰
            // 회계 채널이라 rival 장면이 coach로 접히기도 한다(5차 패널 P2).
            // 원본을 모르는 경로(nil)에는 반응을 붙이지 않는다 — 지어낸 화자보다 침묵.
            guard let event = before.currentRelationshipEvent,
                  let scene = RelationshipVoiceCatalog.scene(
                    eventID: event.id,
                    category: event.category
                  ) else {
                return relationship.feedback
            }
            // 코어의 결과 문구 앞에 "그 사람이 어떻게 반응했는지"를 한 줄 붙인다.
            //
            // 예전에는 응답을 누르면 결과 요약 한 줄로 끝났다. 포수가 어떻게 반응했는지가
            // 없으니 관계가 숫자(팀의 믿음 60)로만 존재했다(품질 평가 §4.3).
            let speaker = scene.speaker
            let speakerName: String? = switch speaker {
            case .coach: after.school?.coachName
            case .catcher: after.school?.catcherName
            case .rival: after.rival.name
            case .named: nil
            }
            let aftermath = RelationshipVoiceCatalog.aftermath(
                eventID: event.id,
                speaker: speaker,
                name: speakerName,
                response: relationship.response,
                trustChange: relationship.trustAfter - relationship.trustBefore
            )
            return aftermath
        }
        if after.chapter.number != before.chapter.number {
            return "\(after.chapter.title) · \(after.chapter.season)"
        }
        return after.news.first ?? "다음 일정이 준비됐습니다."
    }

}
