import Foundation

enum WeeklyTaskKind: String, Codable, CaseIterable, Sendable {
    /// 유일하게 **하루 안에 끝낼 수 없는** 목표.
    ///
    /// 예전 후보 8종은 전부 한 세션에 채워졌다 — 실제로 첫 회차 드래프트가 끝나는 시점에
    /// 이미 3/3이 떴다. 그러면 주간 노트는 복귀 장치가 아니라 첫 세션 체크리스트다.
    /// 서로 다른 두 날에 한 경기씩이면 되고, 어느 모드로 던지든 인정한다.
    case playedOnTwoDays = "played_on_two_days"
    case dailyInningCompleted = "daily_inning_completed"
    case importantGamesCompleted = "important_games_completed"
    case chaptersAdvanced = "chapters_advanced"
    case nextRunStarted = "next_run_started"
    case pledgeSelected = "pledge_selected"
    case differentSchoolSelected = "different_school_selected"
    case sequenceMasteryTriggered = "sequence_mastery_triggered"
    case proWeeksAdvanced = "pro_weeks_advanced"

    var title: String {
        switch self {
        case .playedOnTwoDays: "서로 다른 두 날에 던지기"
        case .dailyInningCompleted: "오늘의 이닝 1회 완료"
        case .importantGamesCompleted: "고교 공식 경기 2번 마치기"
        case .chaptersAdvanced: "고교 이야기 2장 마치기"
        case .nextRunStarted: "새 선수로 다시 시작하기"
        case .pledgeSelected: "고교 3년 목표 정하기"
        case .differentSchoolSelected: "지난 선수와 다른 학교 고르기"
        case .sequenceMasteryTriggered: "수싸움 3회 성공하기"
        case .proWeeksAdvanced: "프로에서 3주 보내기"
        }
    }

    var nextAction: String {
        switch self {
        case .playedOnTwoDays: "오늘 한 경기, 다른 날 한 경기. 고교·프로·오늘의 이닝 어느 쪽이든 됩니다."
        case .dailyInningCompleted: "오늘의 이닝을 한 번 마치면 됩니다."
        case .importantGamesCompleted: "고교 공식 경기를 마치면 됩니다."
        case .chaptersAdvanced: "지금 이야기를 마치고 다음 장으로 가면 됩니다."
        case .nextRunStarted: "고교 3년을 마치고 새 선수로 다시 시작하면 됩니다."
        case .pledgeSelected: "학교를 고르기 전에 고교 3년의 목표를 정하면 됩니다."
        case .differentSchoolSelected: "지난 선수와 다른 학교를 고르면 됩니다."
        case .sequenceMasteryTriggered: "구속 차와 코스 변화를 읽어 수싸움을 맞히면 됩니다."
        case .proWeeksAdvanced: "프로에서 한 주를 보내면 됩니다."
        }
    }

    var defaultTarget: Int {
        switch self {
        case .dailyInningCompleted, .nextRunStarted, .pledgeSelected, .differentSchoolSelected: 1
        case .playedOnTwoDays: 2
        case .importantGamesCompleted, .chaptersAdvanced: 2
        case .sequenceMasteryTriggered, .proWeeksAdvanced: 3
        }
    }
}

struct WeeklyTask: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let kind: WeeklyTaskKind
    let target: Int
    var progress: Int

    var isCompleted: Bool { progress >= target }
    var boundedProgress: Int { min(target, max(0, progress)) }
}

struct WeeklyProgram: Codable, Equatable, Sendable {
    let weekKey: String
    var tasks: [WeeklyTask]
    var completedTaskIDs: Set<String>
    var claimed: Bool

    var completedCount: Int { tasks.filter { completedTaskIDs.contains($0.id) }.count }
    var isRewardReady: Bool { completedCount >= 2 }
    var isPerfect: Bool { completedCount == tasks.count && !tasks.isEmpty }

    var soleRemainingTask: WeeklyTask? {
        let remaining = tasks.filter { !completedTaskIDs.contains($0.id) }
        return remaining.count == 1 ? remaining[0] : nil
    }

    /// 보상까지 하나만 더 필요한 순간에 직접 안내할 행동.
    var nextRewardTask: WeeklyTask? {
        guard completedCount == 1 else { return nil }
        return tasks.first { !completedTaskIDs.contains($0.id) }
    }

    @discardableResult
    mutating func record(_ kind: WeeklyTaskKind, amount: Int = 1) -> Bool {
        guard amount > 0, let index = tasks.firstIndex(where: { $0.kind == kind }) else { return false }
        let wasCompleted = tasks[index].isCompleted
        tasks[index].progress = min(tasks[index].target, tasks[index].progress + amount)
        if tasks[index].isCompleted { completedTaskIDs.insert(tasks[index].id) }
        return !wasCompleted && tasks[index].isCompleted
    }

    mutating func claimStamp(now: Date) -> WeeklyProgramStamp? {
        guard isRewardReady, !claimed else { return nil }
        claimed = true
        return WeeklyProgramStamp(
            weekKey: weekKey, completedTaskCount: completedCount,
            perfect: isPerfect, earnedAt: now
        )
    }
}

struct WeeklyProgramEligibility: Codable, Equatable, Sendable {
    let hasHighSchoolCareer: Bool
    /// 지금 보드가 요구하는 두 경기를 실제 남은 일정에서 치를 수 있는가.
    let remainingImportantGames: Int
    /// 8장 완결 전까지 실제로 넘길 수 있는 이야기 장 수.
    let remainingChapterAdvances: Int
    let dailyInningUnlocked: Bool
    let canStartNextRun: Bool
    let canSelectPledge: Bool
    let canChooseDifferentSchool: Bool
    let hasProCareer: Bool

    var signature: String {
        let flags = [hasHighSchoolCareer, dailyInningUnlocked, canStartNextRun, canSelectPledge,
                     canChooseDifferentSchool, hasProCareer]
            .map { $0 ? "1" : "0" }.joined()
        return "\(flags)|g\(max(0, remainingImportantGames))|c\(max(0, remainingChapterAdvances))"
    }
}

struct WeeklyProgramStamp: Codable, Equatable, Identifiable, Sendable {
    var id: String { "weekly-\(weekKey)" }
    let weekKey: String
    let completedTaskCount: Int
    let perfect: Bool
    let earnedAt: Date
}

struct WeeklyProgramReward: Equatable, Sendable {
    let id: String
    let weekKey: String
    let soulPoints: Int

    static func reward(for weekKey: String) -> WeeklyProgramReward {
        WeeklyProgramReward(id: "weekly-\(weekKey)", weekKey: weekKey, soulPoints: 15)
    }
}

/// 주간 보상이 4주 획득 경제에서 차지하는 몫을 정수로 재현한다. 대표 회차의 실제
/// `nextInheritance` 보상과 함께 테스트해 최초 25점이 가드레일을 넘는지 판단한다.
struct WeeklyEconomyProjection: Equatable {
    let weeks: Int
    let ordinaryRunSoulPerWeek: Int
    let weeklyReward: Int

    var ordinarySoul: Int { max(0, weeks) * max(0, ordinaryRunSoulPerWeek) }
    var weeklySoul: Int { max(0, weeks) * max(0, weeklyReward) }
    var totalSoul: Int { ordinarySoul + weeklySoul }
    var weeklySharePermille: Int {
        guard totalSoul > 0 else { return 0 }
        return weeklySoul * 1_000 / totalSoul
    }
}

enum WeeklyProgramRules {
    static func make(
        weekKey: String,
        stableUserID: String,
        eligibility: WeeklyProgramEligibility
    ) -> WeeklyProgram? {
        let candidates = rankedEligibleKinds(
            weekKey: weekKey, stableUserID: stableUserID, eligibility: eligibility
        )
        guard candidates.count >= 3 else { return nil }
        // 세 칸 중 한 칸은 반드시 이틀에 걸치는 목표로 고정한다. 나머지는 안정 해시
        // 순서를 따른다 — 보상 경제(주간 15혼)는 건드리지 않고, 주간 노트가 한 세션에
        // 통째로 닫히는 것만 막는다.
        //
        // 고정은 한 칸까지다. 두 칸을 고정하면 남는 자리가 하나뿐이라 모든 사람의 보드가
        // 거의 같아지고, 주마다 다른 숙제를 낸다는 성질이 사라진다.
        let ordered = candidates.contains(.playedOnTwoDays)
            ? [.playedOnTwoDays] + candidates.filter { $0 != .playedOnTwoDays }
            : candidates
        let tasks = ordered.prefix(3).map { kind in
            task(weekKey: weekKey, kind: kind)
        }
        return WeeklyProgram(weekKey: weekKey, tasks: tasks, completedTaskIDs: [], claimed: false)
    }

    /// Reconcile a board when the player changes modes during the same week. A completed goal is
    /// a historical fact, so it stays even if that mode is no longer open. Only unfinished goals
    /// that became impossible are replaced, using the same stable ranking as initial generation.
    /// If the new mode cannot supply enough distinct goals, keep the board untouched rather than
    /// silently shrinking a three-goal contract or discarding progress.
    static func reconciling(
        _ existing: WeeklyProgram,
        stableUserID: String,
        eligibility: WeeklyProgramEligibility
    ) -> WeeklyProgram {
        let eligible = rankedEligibleKinds(
            weekKey: existing.weekKey, stableUserID: stableUserID, eligibility: eligibility
        )
        let eligibleSet = Set(eligible)
        let replacementIndices = existing.tasks.indices.filter { index in
            let task = existing.tasks[index]
            let completed = task.isCompleted || existing.completedTaskIDs.contains(task.id)
            return !completed && !isStillFeasible(
                task, eligibleSet: eligibleSet, eligibility: eligibility
            )
        }
        guard !replacementIndices.isEmpty else { return existing }

        let replacementIndexSet = Set(replacementIndices)
        let retainedKinds = Set(existing.tasks.indices.compactMap { index in
            replacementIndexSet.contains(index) ? nil : existing.tasks[index].kind
        })
        let replacements = eligible.filter { !retainedKinds.contains($0) }
        guard replacements.count >= replacementIndices.count else { return existing }

        var updated = existing
        for (index, kind) in zip(replacementIndices, replacements) {
            updated.tasks[index] = task(weekKey: existing.weekKey, kind: kind)
        }
        return updated
    }

    /// A new two-step goal needs two future opportunities. An existing 1/2 goal only needs one:
    /// reconciling those through the same candidate predicate would throw away valid progress.
    private static func isStillFeasible(
        _ task: WeeklyTask,
        eligibleSet: Set<WeeklyTaskKind>,
        eligibility: WeeklyProgramEligibility
    ) -> Bool {
        switch task.kind {
        case .importantGamesCompleted:
            return eligibility.hasHighSchoolCareer
                && task.boundedProgress + max(0, eligibility.remainingImportantGames) >= task.target
        case .chaptersAdvanced:
            return eligibility.hasHighSchoolCareer
                && task.boundedProgress + max(0, eligibility.remainingChapterAdvances) >= task.target
        default:
            return eligibleSet.contains(task.kind)
        }
    }

    static func eligibleKinds(_ eligibility: WeeklyProgramEligibility) -> [WeeklyTaskKind] {
        var result: [WeeklyTaskKind] = []
        if eligibility.dailyInningUnlocked { result.append(.dailyInningCompleted) }
        if eligibility.hasHighSchoolCareer {
            if eligibility.remainingImportantGames >= WeeklyTaskKind.importantGamesCompleted.defaultTarget {
                result.append(.importantGamesCompleted)
            }
            if eligibility.remainingChapterAdvances >= WeeklyTaskKind.chaptersAdvanced.defaultTarget {
                result.append(.chaptersAdvanced)
            }
        }
        if eligibility.canStartNextRun { result.append(.nextRunStarted) }
        if eligibility.canSelectPledge { result.append(.pledgeSelected) }
        if eligibility.canChooseDifferentSchool { result.append(.differentSchoolSelected) }
        if eligibility.hasHighSchoolCareer || eligibility.dailyInningUnlocked || eligibility.hasProCareer {
            result.append(.sequenceMasteryTriggered)
            result.append(.playedOnTwoDays)
        }
        if eligibility.hasProCareer { result.append(.proWeeksAdvanced) }
        return result
    }

    private static func rankedEligibleKinds(
        weekKey: String,
        stableUserID: String,
        eligibility: WeeklyProgramEligibility
    ) -> [WeeklyTaskKind] {
        eligibleKinds(eligibility).sorted {
            let left = rank(stableUserID: stableUserID, weekKey: weekKey, kind: $0)
            let right = rank(stableUserID: stableUserID, weekKey: weekKey, kind: $1)
            return left == right ? $0.rawValue < $1.rawValue : left < right
        }
    }

    private static func task(weekKey: String, kind: WeeklyTaskKind) -> WeeklyTask {
        WeeklyTask(
            id: "\(weekKey)-\(kind.rawValue)", kind: kind,
            target: kind.defaultTarget, progress: 0
        )
    }

    private static func rank(
        stableUserID: String,
        weekKey: String,
        kind: WeeklyTaskKind
    ) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in "\(stableUserID)|\(weekKey)|\(kind.rawValue)|weekly-v1".utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return hash
    }
}
