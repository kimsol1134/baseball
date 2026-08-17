import Foundation
import SimulationCore

/// 프로 세이브의 순수 코덱. 스토어 관찰 상태를 만지지 않는다.
enum ProCareerPersistence {
    static let legacySchemaVersion = 2
    static let journeySchemaVersion = 3

    static func schemaVersion(for result: ProCareerResult) -> Int {
        result.snapshot.journeyState == nil ? legacySchemaVersion : journeySchemaVersion
    }

    static func decode(_ data: Data) -> ProCareerSaveRecord? {
        let decoder = JSONDecoder()
        if let record = try? decoder.decode(ProCareerSaveRecord.self, from: data) {
            let version = record.schemaVersion ?? 1
            if (1...journeySchemaVersion).contains(version),
               record.result != nil || record.deletedRevision != nil,
               !(version < journeySchemaVersion && record.result?.snapshot.journeyState != nil) {
                return record
            }
        }
        guard let legacy = try? decoder.decode(ProCareerResult.self, from: data) else { return nil }
        return ProCareerSaveRecord(
            result: legacy,
            schemaVersion: 1,
            syncRevision: legacy.snapshot.revision
        )
    }

    static func encode(_ record: ProCareerSaveRecord) -> Data? {
        try? JSONEncoder().encode(record)
    }

    static func nextRevision(after current: UInt64, atLeast minimum: UInt64) -> UInt64 {
        let incremented = current == UInt64.max ? UInt64.max : current + 1
        return max(incremented, minimum)
    }

    static func revision(_ data: Data) -> UInt64? {
        decode(data)?.effectiveRevision
    }

    /// ProSaveRecord의 명시적 삭제 묘비만 live보다 높은 동률 우선순위를 갖는다.
    /// wrapper 도입 전 raw ProCareerResult는 기존 live 저장으로 그대로 취급한다.
    static func conflictPriority(_ data: Data) -> Int {
        guard let record = decode(data),
              record.result == nil,
              record.deletedRevision != nil || record.syncRevision != nil else { return 0 }
        return 1
    }

    /// Read only the outer schema marker for the write downgrade gate. This deliberately works for
    /// future records that the full decoder cannot understand: a legacy writer must not replace a
    /// newer journey save or deletion tombstone merely because it cannot decode it.
    static func rawSchemaVersion(_ data: Data) -> UInt64? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let version = object["schemaVersion"] as? Int {
            return version >= 0 ? UInt64(version) : nil
        }
        return object["snapshot"] != nil ? 1 : nil
    }

    static func record(
        from state: ProCareerPersistedState,
        deletedRevision: UInt64? = nil,
        schemaVersion: Int,
        syncRevision: UInt64
    ) -> ProCareerSaveRecord {
        ProCareerSaveRecord(
            result: state.result,
            gameResume: state.gameResume,
            deletedRevision: deletedRevision,
            sourceHighSchoolCareerID: state.sourceHighSchoolCareerID,
            origin: state.careerOrigin,
            schemaVersion: schemaVersion,
            syncRevision: syncRevision
        )
    }

    static func record(
        result: ProCareerResult?,
        gameResume: PitchSession.ResumeState? = nil,
        deletedRevision: UInt64? = nil,
        sourceHighSchoolCareerID: String? = nil,
        origin: MobileCareerStore.ProCareerOrigin? = nil,
        schemaVersion: Int,
        syncRevision: UInt64
    ) -> ProCareerSaveRecord {
        record(
            from: ProCareerPersistedState(
                result: result,
                gameResume: gameResume,
                sourceHighSchoolCareerID: sourceHighSchoolCareerID,
                careerOrigin: origin,
                syncedRevision: syncRevision
            ),
            deletedRevision: deletedRevision,
            schemaVersion: schemaVersion,
            syncRevision: syncRevision
        )
    }

    static func materialize(_ record: ProCareerSaveRecord) -> ProCareerPersistedState {
        ProCareerPersistedState(
            result: record.result,
            gameResume: record.gameResume,
            sourceHighSchoolCareerID: record.sourceHighSchoolCareerID,
            careerOrigin: record.origin,
            syncedRevision: record.effectiveRevision
        )
    }
}
