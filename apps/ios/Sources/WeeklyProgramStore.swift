import Foundation
import Observation

struct WeeklyProgramMoment: Equatable, Sendable {
    let weekKey: String
    let weekStart: Date

    static func resolve(date: Date, calendar source: Calendar) -> WeeklyProgramMoment? {
        // ISO week numbering stays stable while the injected calendar supplies the user's
        // current time zone, including daylight-saving transitions.
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = source.timeZone
        calendar.locale = source.locale
        guard let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return nil }
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        guard let year = components.yearForWeekOfYear, let week = components.weekOfYear else { return nil }
        return WeeklyProgramMoment(
            weekKey: String(format: "%04d-W%02d", year, week), weekStart: start
        )
    }

    func isRollback(comparedWith lastObservedWeekStart: Date?) -> Bool {
        lastObservedWeekStart.map { weekStart < $0 } ?? false
    }
}

@MainActor
@Observable
final class WeeklyProgramStore {
    static let shared = WeeklyProgramStore()

    private(set) var program: WeeklyProgram?
    private(set) var stamps: [WeeklyProgramStamp] = []
    private(set) var lastObservedWeekStart: Date?
    private(set) var currentEligibility: WeeklyProgramEligibility?

    @ObservationIgnored private let sync: SaveSync
    @ObservationIgnored private let outboxSync: SaveSync
    @ObservationIgnored private let stableUserID: String
    @ObservationIgnored private let saveWriter: ((Data) -> Bool)?
    @ObservationIgnored private let outboxWriter: ((Data) -> Bool)?
    @ObservationIgnored private var revision: UInt64 = 0
    @ObservationIgnored private var outboxRevision: UInt64 = 0
    @ObservationIgnored private var pendingReceipts: [ProgressReceipt] = []
    @ObservationIgnored private var processedReceiptIDs: Set<String> = []

    init(
        sync: SaveSync = SaveSync(key: "baseball-weekly-program.json"),
        stableUserID: String = GameAnalytics.stableID(),
        saveWriter: ((Data) -> Bool)? = nil,
        outboxSync: SaveSync? = nil,
        outboxWriter: ((Data) -> Bool)? = nil
    ) {
        self.sync = sync
        self.outboxSync = outboxSync ?? SaveSync(key: "\(sync.key).progress-outbox")
        self.stableUserID = stableUserID
        self.saveWriter = saveWriter
        self.outboxWriter = outboxWriter
        restore()
        restoreOutbox()
    }

    var claimableReward: WeeklyProgramReward? {
        guard let program, program.isRewardReady, !program.claimed else { return nil }
        return .reward(for: program.weekKey)
    }

    var summaryLine: String {
        guard let program else { return "이번 주 야구 노트 · 준비 중" }
        return "이번 주 야구 노트 · \(program.completedCount)/\(program.tasks.count)"
    }

    @discardableResult
    func configure(
        eligibility: WeeklyProgramEligibility,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        return refresh(eligibility: eligibility, now: now, calendar: calendar)
    }

    @discardableResult
    func refresh(
        eligibility: WeeklyProgramEligibility,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let moment = WeeklyProgramMoment.resolve(date: now, calendar: calendar) else { return false }

        // Clock/time-zone rollback: never replace a later observed week with an earlier one.
        if moment.isRollback(comparedWith: lastObservedWeekStart) {
            return true
        }

        var candidateProgram = program
        var candidateStamps = stamps
        var candidateWeekStart = lastObservedWeekStart
        var candidateProcessed = processedReceiptIDs
        var handledReceiptIDs: Set<String> = []

        if program?.weekKey == moment.weekKey {
            applyPendingReceipts(
                for: moment,
                program: &candidateProgram,
                stamps: &candidateStamps,
                processedReceiptIDs: &candidateProcessed,
                handledReceiptIDs: &handledReceiptIDs
            )
            if let existing = candidateProgram {
                let reconciled = WeeklyProgramRules.reconciling(
                    existing, stableUserID: stableUserID, eligibility: eligibility
                )
                candidateProgram = reconciled
            }
            if lastObservedWeekStart.map({ moment.weekStart > $0 }) ?? true {
                candidateWeekStart = moment.weekStart
            }
        } else {
            // A prior incomplete week expires without penalty. When fewer than three tasks are
            // possible, keep the week empty and try again after eligibility changes.
            candidateProgram = WeeklyProgramRules.make(
                weekKey: moment.weekKey, stableUserID: stableUserID, eligibility: eligibility
            )
            candidateWeekStart = moment.weekStart
            // 처리 원장은 현재 주 영수증에만 필요하다. 이전 주 영수증은 새 주에 섞지 않는다.
            candidateProcessed = []
            applyPendingReceipts(
                for: moment,
                program: &candidateProgram,
                stamps: &candidateStamps,
                processedReceiptIDs: &candidateProcessed,
                handledReceiptIDs: &handledReceiptIDs
            )
        }

        let changed = candidateProgram != program
            || candidateStamps != stamps
            || candidateWeekStart != lastObservedWeekStart
            || candidateProcessed != processedReceiptIDs
        if changed {
            guard persist(
                program: candidateProgram,
                stamps: candidateStamps,
                lastObservedWeekStart: candidateWeekStart,
                processedReceiptIDs: candidateProcessed,
                pendingReceipts: pendingReceipts
            ) else { return false }
            program = candidateProgram
            stamps = candidateStamps
            lastObservedWeekStart = candidateWeekStart
            processedReceiptIDs = candidateProcessed
        }
        removeHandledReceipts(handledReceiptIDs)
        currentEligibility = eligibility
        return true
    }

    @discardableResult
    func record(
        _ kind: WeeklyTaskKind,
        amount: Int = 1,
        receiptID: String? = nil,
        eligibility: WeeklyProgramEligibility,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard amount > 0,
              let moment = WeeklyProgramMoment.resolve(date: now, calendar: calendar),
              !moment.isRollback(comparedWith: lastObservedWeekStart) else { return false }
        let receipt = ProgressReceipt(
            id: receiptID ?? UUID().uuidString,
            weekKey: moment.weekKey,
            weekStart: moment.weekStart,
            kind: kind,
            amount: amount
        )
        if processedReceiptIDs.contains(receipt.id) { return true }
        // 원본 행동은 이미 다른 SaveRecord에 durable하게 저장됐다. 주간 저장 실패가 그 행동을
        // 지우지 않도록 영수증을 먼저 별도 outbox에 내리고, configure가 재적용하게 한다.
        if !pendingReceipts.contains(where: { $0.id == receipt.id }), !enqueue(receipt) {
            // The dedicated outbox can fail independently (for example while its local file is
            // being repaired). Mirror the receipt into the main record so a source action that
            // has already committed is still recoverable after restart. If both files are
            // unavailable there is no durable medium, and the caller correctly receives false.
            let fallbackReceipts = pendingReceipts + [receipt]
            guard persist(
                program: program,
                stamps: stamps,
                lastObservedWeekStart: lastObservedWeekStart,
                processedReceiptIDs: processedReceiptIDs,
                pendingReceipts: fallbackReceipts
            ) else { return false }
            pendingReceipts = fallbackReceipts
        }
        return refresh(eligibility: eligibility, now: now, calendar: calendar)
    }

    /// 앱의 행동 훅에서 쓰는 경로. AppShell이 최신 자격을 구성한 뒤에는 각 스토어가
    /// 서로를 참조하지 않고도 같은 주간 프로그램에 진행을 남길 수 있다.
    @discardableResult
    func record(
        _ kind: WeeklyTaskKind,
        amount: Int = 1,
        receiptID: String? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let currentEligibility else { return false }
        return record(
            kind, amount: amount, receiptID: receiptID,
            eligibility: currentEligibility, now: now, calendar: calendar
        )
    }

    /// Call only after `HighSchoolCareerStore` has idempotently accepted the reward ID.
    @discardableResult
    func markClaimed(now: Date = Date()) -> Bool {
        guard var updated = program, let stamp = updated.claimStamp(now: now) else { return false }
        var updatedStamps = stamps.filter { $0.weekKey != stamp.weekKey }
        updatedStamps.insert(stamp, at: 0)
        guard persist(
            program: updated,
            stamps: updatedStamps,
            lastObservedWeekStart: lastObservedWeekStart,
            processedReceiptIDs: processedReceiptIDs,
            pendingReceipts: pendingReceipts
        ) else { return false }
        program = updated
        stamps = updatedStamps
        GameAnalytics.log(.weeklyProgramCompleted, [
            "week_key": updated.weekKey,
            "completed_tasks": updated.completedCount,
            "perfect": updated.isPerfect,
        ])
        return true
    }

    func reloadFromSync() {
        _ = restore()
        _ = restoreOutbox()
    }

    struct SaveRecord: Codable, Equatable {
        var program: WeeklyProgram?
        var stamps: [WeeklyProgramStamp]
        var lastObservedWeekStart: Date?
        var revision: UInt64
        /// outbox 정리가 저장 성공 직후 끊겨도 같은 행동을 다시 더하지 않는 원장.
        var processedReceiptIDs: Set<String>? = nil
        /// 별도 outbox 파일 쓰기가 실패했을 때의 동일 파일 fallback. 처리 원장과 함께
        /// 저장되어 앱 재시작 뒤에도 정확히 한 번 적용된다.
        var pendingReceipts: [ProgressReceipt]? = nil
    }

    struct ProgressReceipt: Codable, Equatable, Identifiable {
        let id: String
        let weekKey: String
        let weekStart: Date
        let kind: WeeklyTaskKind
        let amount: Int
    }

    private struct OutboxRecord: Codable {
        var receipts: [ProgressReceipt]
        var revision: UInt64
    }

    @discardableResult
    private func restore() -> Bool {
        guard let data = sync.read(revision: { data in
            (try? JSONDecoder().decode(SaveRecord.self, from: data))?.revision
        }), let saved = try? JSONDecoder().decode(SaveRecord.self, from: data) else { return false }
        guard saved.revision >= revision else { return false }
        program = saved.program
        stamps = saved.stamps
        lastObservedWeekStart = saved.lastObservedWeekStart
        processedReceiptIDs = saved.processedReceiptIDs ?? []
        pendingReceipts = saved.pendingReceipts ?? []
        revision = saved.revision
        return true
    }

    @discardableResult
    private func persist(
        program: WeeklyProgram?,
        stamps: [WeeklyProgramStamp],
        lastObservedWeekStart: Date?,
        processedReceiptIDs: Set<String>,
        pendingReceipts: [ProgressReceipt]
    ) -> Bool {
        let candidateRevision = revision + 1
        let record = SaveRecord(
            program: program, stamps: stamps,
            lastObservedWeekStart: lastObservedWeekStart,
            revision: candidateRevision,
            processedReceiptIDs: processedReceiptIDs.isEmpty ? nil : processedReceiptIDs,
            pendingReceipts: pendingReceipts.isEmpty ? nil : pendingReceipts
        )
        guard let data = try? JSONEncoder().encode(record),
              saveWriter?(data) ?? sync.write(data) else {
            return false
        }
        revision = candidateRevision
        return true
    }

    @discardableResult
    private func restoreOutbox() -> Bool {
        guard let data = outboxSync.read(revision: { data in
            (try? JSONDecoder().decode(OutboxRecord.self, from: data))?.revision
        }), let saved = try? JSONDecoder().decode(OutboxRecord.self, from: data),
              saved.revision >= outboxRevision else { return false }
        let merged = Dictionary(
            (pendingReceipts + saved.receipts).map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )
        pendingReceipts = merged.values.sorted { $0.id < $1.id }
        outboxRevision = saved.revision
        return true
    }

    private func persistOutbox(_ receipts: [ProgressReceipt]) -> Bool {
        let candidateRevision = outboxRevision + 1
        let record = OutboxRecord(receipts: receipts, revision: candidateRevision)
        guard let data = try? JSONEncoder().encode(record),
              outboxWriter?(data) ?? outboxSync.write(data) else { return false }
        pendingReceipts = receipts
        outboxRevision = candidateRevision
        return true
    }

    private func enqueue(_ receipt: ProgressReceipt) -> Bool {
        persistOutbox(pendingReceipts + [receipt])
    }

    private func applyPendingReceipts(
        for moment: WeeklyProgramMoment,
        program: inout WeeklyProgram?,
        stamps: inout [WeeklyProgramStamp],
        processedReceiptIDs: inout Set<String>,
        handledReceiptIDs: inout Set<String>
    ) {
        for receipt in pendingReceipts {
            if receipt.weekKey == moment.weekKey {
                // 후보가 아직 세 개 미만이라 board가 nil이면 영수증을 소비하지 않는다.
                // 같은 주에 자격이 열려 보드가 생긴 뒤 원본 행동을 정확히 한 번 반영한다.
                guard var updated = program else { continue }
                handledReceiptIDs.insert(receipt.id)
                guard processedReceiptIDs.insert(receipt.id).inserted else { continue }
                updated.record(receipt.kind, amount: receipt.amount)
                if updated.claimed, updated.isPerfect,
                   let index = stamps.firstIndex(where: { $0.weekKey == updated.weekKey }),
                   !stamps[index].perfect {
                    stamps[index] = WeeklyProgramStamp(
                        weekKey: updated.weekKey,
                        completedTaskCount: updated.completedCount,
                        perfect: true,
                        earnedAt: stamps[index].earnedAt
                    )
                }
                program = updated
            } else if receipt.weekStart < moment.weekStart {
                // 지난 주 행동은 새 주 목표에 이월하지 않는다.
                handledReceiptIDs.insert(receipt.id)
            }
        }
    }

    private func removeHandledReceipts(_ ids: Set<String>) {
        guard !ids.isEmpty else { return }
        let remaining = pendingReceipts.filter { !ids.contains($0.id) }
        _ = persistOutbox(remaining)
    }
}
