import Foundation
import SimulationCore
import BaseballIOSDomain

/// 프로 세이브의 순수 코덱. 스토어 관찰 상태를 만지지 않는다.
public enum ProCareerPersistence {
    public static let legacySchemaVersion = 2
    public static let journeySchemaVersion = 3
    public static let repertoireSchemaVersion = 4
    public static let masterySchemaVersion = 5
    public static let nationalTeamSchemaVersion = 6
    public static let currentSchemaVersion = nationalTeamSchemaVersion

    public static func schemaVersion(for result: ProCareerResult) -> Int {
        schemaVersion(for: ProCareerPersistedState(result: result))
    }

    /// The wrapper owns durable injury acknowledgement state, so schema selection must inspect
    /// the whole record rather than only the latest engine result. Otherwise the first recovery
    /// week would try to downgrade a v5 injury save after `result.injuryEvent` becomes nil.
    public static func schemaVersion(for state: ProCareerPersistedState) -> Int {
        guard let result = state.result else { return currentSchemaVersion }
        if hasNationalTeamState(result.snapshot) {
            return nationalTeamSchemaVersion
        }
        if result.snapshot.pitcher.mastery != nil
            || result.injuryEvent != nil
            || state.pendingInjuryEvent != nil
            || state.acknowledgedInjuryEventID != nil {
            return masterySchemaVersion
        }
        if result.snapshot.repertoireRulesVersion != nil { return repertoireSchemaVersion }
        return result.snapshot.journeyState == nil ? legacySchemaVersion : journeySchemaVersion
    }

    /// Schema 6 is stamped only when a national-team phase or leftover tournament record exists.
    /// A v10 career that never entered the tournament stays on schema 5.
    public static func hasNationalTeamState(_ snapshot: ProCareerSnapshot) -> Bool {
        snapshot.nationalTournament != nil
            || (snapshot.nationalTeamHistory?.isEmpty == false)
            || snapshot.nationalTeamCarry != nil
            || snapshot.phase == .nationalTeamCall
            || snapshot.phase == .nationalTournament
            || snapshot.seasonTrigger == .nationalFinal
    }

    public static func decode(_ data: Data) -> ProCareerSaveRecord? {
        let decoder = JSONDecoder()
        if let record = try? decoder.decode(ProCareerSaveRecord.self, from: data) {
            let version = record.schemaVersion ?? 1
            let hasMastery = record.result?.snapshot.pitcher.mastery != nil
            let hasInjury = record.result?.injuryEvent != nil
                || record.pendingInjuryEvent != nil
                || record.acknowledgedInjuryEventID != nil
            let hasNationalTeam = record.result.map { hasNationalTeamState($0.snapshot) } ?? false
            if (1...currentSchemaVersion).contains(version),
               record.result != nil || record.deletedRevision != nil,
               !(version < journeySchemaVersion && record.result?.snapshot.journeyState != nil),
               !(version < repertoireSchemaVersion && record.result?.snapshot.repertoireRulesVersion != nil),
               !(version < masterySchemaVersion && (hasMastery || hasInjury)),
               !(version < nationalTeamSchemaVersion && hasNationalTeam) {
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

    public static func encode(_ record: ProCareerSaveRecord) -> Data? {
        try? JSONEncoder().encode(record)
    }

    public static func nextRevision(after current: UInt64, atLeast minimum: UInt64) -> UInt64 {
        let incremented = current == UInt64.max ? UInt64.max : current + 1
        return max(incremented, minimum)
    }

    public static func revision(_ data: Data) -> UInt64? {
        decode(data)?.effectiveRevision
    }

    /// ProSaveRecord의 명시적 삭제 묘비만 live보다 높은 동률 우선순위를 갖는다.
    /// wrapper 도입 전 raw ProCareerResult는 기존 live 저장으로 그대로 취급한다.
    public static func conflictPriority(_ data: Data) -> Int {
        guard let record = decode(data),
              record.result == nil,
              record.deletedRevision != nil || record.syncRevision != nil else { return 0 }
        return 1
    }

    /// Read only the outer schema marker for the write downgrade gate. This deliberately works for
    /// future records that the full decoder cannot understand: a legacy writer must not replace a
    /// newer journey save or deletion tombstone merely because it cannot decode it.
    public static func rawSchemaVersion(_ data: Data) -> UInt64? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let version = object["schemaVersion"] as? Int {
            return version >= 0 ? UInt64(version) : nil
        }
        return object["snapshot"] != nil ? 1 : nil
    }

    public static func record(
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
            syncRevision: syncRevision,
            pendingInjuryEvent: state.pendingInjuryEvent,
            acknowledgedInjuryEventID: state.acknowledgedInjuryEventID,
            replays: state.replays,
            commandReceipts: state.commandReceipts
        )
    }

    public static func record(
        result: ProCareerResult?,
        gameResume: PitchResumeState? = nil,
        deletedRevision: UInt64? = nil,
        sourceHighSchoolCareerID: String? = nil,
        origin: ProCareerOrigin? = nil,
        pendingInjuryEvent: ProInjuryEventSnapshot? = nil,
        acknowledgedInjuryEventID: String? = nil,
        schemaVersion: Int,
        syncRevision: UInt64
    ) -> ProCareerSaveRecord {
        record(
            from: ProCareerPersistedState(
                result: result,
                gameResume: gameResume,
                sourceHighSchoolCareerID: sourceHighSchoolCareerID,
                careerOrigin: origin,
                syncedRevision: syncRevision,
                pendingInjuryEvent: pendingInjuryEvent,
                acknowledgedInjuryEventID: acknowledgedInjuryEventID
            ),
            deletedRevision: deletedRevision,
            schemaVersion: schemaVersion,
            syncRevision: syncRevision
        )
    }

    public static func materialize(_ record: ProCareerSaveRecord) -> ProCareerPersistedState {
        ProCareerPersistedState(
            result: record.result,
            gameResume: record.gameResume,
            sourceHighSchoolCareerID: record.sourceHighSchoolCareerID,
            careerOrigin: record.origin,
            syncedRevision: record.effectiveRevision,
            pendingInjuryEvent: record.pendingInjuryEvent,
            acknowledgedInjuryEventID: record.acknowledgedInjuryEventID,
            replays: record.replays,
            commandReceipts: record.commandReceipts
        )
    }
}
