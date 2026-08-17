import Foundation

/// 고교 세이브의 순수 코덱. 스토어 관찰 상태를 만지지 않는다.
enum HighSchoolCareerPersistence {
    static let currentSchemaVersion = 2

    static func decode(_ data: Data) -> HighSchoolCareerSaveRecord? {
        guard let record = try? JSONDecoder().decode(HighSchoolCareerSaveRecord.self, from: data) else {
            return nil
        }
        let version = record.schemaVersion ?? 1
        guard (1...currentSchemaVersion).contains(version) else { return nil }
        return record
    }

    static func encode(_ record: HighSchoolCareerSaveRecord) -> Data? {
        try? JSONEncoder().encode(record)
    }

    static func nextRevision(after current: UInt64, atLeast minimum: UInt64) -> UInt64 {
        let incremented = current == UInt64.max ? UInt64.max : current + 1
        return max(incremented, minimum)
    }

    /// 같은 리비전에서 다른 기기의 live 진행과 삭제/회차-사이 레코드가 충돌하면
    /// result-less 쪽이 이긴다. stable ID나 문구가 아니라 저장 의미만 본다.
    static func conflictPriority(_ data: Data) -> Int {
        guard let record = decode(data) else { return 0 }
        return record.result == nil ? 1 : 0
    }

    static func revision(_ data: Data) -> UInt64? {
        decode(data)?.effectiveRevision
    }

    /// 분리 회계 마이그레이션 — 총량 필드가 없는 옛 저장본은 잔액을 총량으로 승계한다.
    /// 이 한 줄이 없으면 첫 구매 순간 평생 총량이 잔액으로 붕괴한다(3차 패널 P0).
    static func migratedInheritance(
        _ inheritance: HighSchoolCareerStore.Inheritance
    ) -> HighSchoolCareerStore.Inheritance {
        var next = inheritance
        if next.soulTotalEarned == nil { next.soulTotalEarned = next.soulPoints }
        if next.automaticSoulEarned == nil {
            next.automaticSoulEarned = next.soulTotal
        }
        return next
    }

    enum ChapterStartFallback {
        case zero
        case savedResultStrikeouts
    }

    /// persist / 묘비가 같은 생략 규칙을 쓰게 한다. 빈 컬렉션은 nil로 내려 옛 저장본과
    /// 구분하고, archive처럼 회차 사이에도 의미가 있는 값은 빈 배열로 남긴다.
    static func record(
        from state: HighSchoolCareerPersistedState,
        currentCareerRetention: HighSchoolCareerStore.CurrentCareerRetention?,
        revision: UInt64
    ) -> HighSchoolCareerSaveRecord {
        HighSchoolCareerSaveRecord(
            result: state.result,
            inheritance: state.inheritance,
            archive: state.archive,
            enteredProCareerID: state.enteredProCareerID,
            nicknames: state.nicknames.isEmpty ? nil : state.nicknames,
            chronicle: state.chronicle.isEmpty ? nil : state.chronicle,
            chapterStartStrikeouts: state.chapterStartStrikeouts,
            goalCelebratedChapter: state.goalCelebratedChapter,
            responseTally: state.responseTally,
            bondMemories: HighSchoolCareerStore.normalizedBondMemories(state.bondMemories).isEmpty
                ? nil : HighSchoolCareerStore.normalizedBondMemories(state.bondMemories),
            rebirthEventIDs: state.rebirthEventIDs.isEmpty
                ? nil : Array(state.rebirthEventIDs.suffix(6)),
            chapterGains: state.chapterGains.isEmpty ? nil : state.chapterGains,
            chapterTrainingCount: state.chapterTrainingCount == 0 ? nil : state.chapterTrainingCount,
            careerStartingPitcher: state.careerStartingPitcher,
            signatureLegacyRulesVersion: state.signatureLegacyRulesVersion,
            frozenSignatureLegacyCandidates: state.frozenSignatureLegacyCandidates,
            selectedSignatureLegacyID: state.selectedSignatureLegacyID,
            gameResume: state.gameResume,
            challengeCareerID: state.challengeCareerID,
            nextRunIntent: state.nextRunIntent,
            creditedExternalRewardIDs: state.creditedExternalRewardIDs.isEmpty
                ? nil : state.creditedExternalRewardIDs,
            currentCareerRetention: currentCareerRetention,
            pendingGameCompletion: state.pendingGameCompletion,
            revision: revision,
            schemaVersion: currentSchemaVersion
        )
    }

    static func materialize(
        _ record: HighSchoolCareerSaveRecord,
        chapterStartFallback: ChapterStartFallback
    ) -> HighSchoolCareerPersistedState {
        let chapterStart: Int
        switch chapterStartFallback {
        case .zero:
            chapterStart = record.chapterStartStrikeouts ?? 0
        case .savedResultStrikeouts:
            chapterStart = record.chapterStartStrikeouts
                ?? record.result?.snapshot.performance.strikeouts ?? 0
        }
        return HighSchoolCareerPersistedState(
            result: record.result,
            inheritance: migratedInheritance(record.inheritance),
            archive: record.archive ?? [],
            enteredProCareerID: record.enteredProCareerID,
            nicknames: record.nicknames ?? [],
            chronicle: record.chronicle ?? [],
            chapterStartStrikeouts: chapterStart,
            goalCelebratedChapter: record.goalCelebratedChapter,
            responseTally: record.responseTally ?? HighSchoolCareerStore.ResponseTally(),
            bondMemories: HighSchoolCareerStore.normalizedBondMemories(record.bondMemories ?? []),
            rebirthEventIDs: record.rebirthEventIDs ?? [],
            chapterGains: record.chapterGains ?? [:],
            chapterTrainingCount: record.chapterTrainingCount ?? 0,
            careerStartingPitcher: record.careerStartingPitcher,
            signatureLegacyRulesVersion: record.signatureLegacyRulesVersion,
            frozenSignatureLegacyCandidates: record.frozenSignatureLegacyCandidates,
            selectedSignatureLegacyID: record.selectedSignatureLegacyID,
            gameResume: record.gameResume,
            challengeCareerID: record.challengeCareerID,
            nextRunIntent: record.nextRunIntent,
            creditedExternalRewardIDs: record.creditedExternalRewardIDs ?? [],
            pendingGameCompletion: record.pendingGameCompletion,
            savedRevision: record.effectiveRevision
        )
    }
}
