public enum ProGoalBoardRowKind: String, Codable, Sendable {
    case ambitionMetric = "ambition_metric"
    case retiredNumber = "retired_number"
    case clubHall = "club_hall"
    case hallOfFame = "hall_of_fame"
    case milestoneGames = "milestone_games"
    case milestoneStrikeouts = "milestone_strikeouts"
    case teamLegacyTier = "team_legacy_tier"
}

public struct ProGoalBoardRow: Equatable, Identifiable, Sendable {
    public let id: String
    public let kind: ProGoalBoardRowKind
    public let titleKey: String
    public let current: Int
    public let target: Int
    public let permille: Int
    public let completed: Bool
    public let hintKey: String
    public let subRows: [ProGoalBoardRow]

    public init(
        id: String,
        kind: ProGoalBoardRowKind,
        titleKey: String,
        current: Int,
        target: Int,
        permille: Int,
        completed: Bool,
        hintKey: String,
        subRows: [ProGoalBoardRow] = []
    ) {
        self.id = id
        self.kind = kind
        self.titleKey = titleKey
        self.current = current
        self.target = target
        self.permille = permille
        self.completed = completed
        self.hintKey = hintKey
        self.subRows = subRows
    }
}

public struct ProCareerGoalBoard: Equatable, Sendable {
    public let rows: [ProGoalBoardRow]
    public let nearest: ProGoalBoardRow?

    public init(rows: [ProGoalBoardRow], nearest: ProGoalBoardRow?) {
        self.rows = rows
        self.nearest = nearest
    }
}

/// Derived career goal board. No persisted fields; every value is projected from
/// `ProCareerSnapshot` through existing goal, retirement, milestone, and legacy rules.
public enum ProCareerGoalBoardRules {
    public static func permille(current: Int, target: Int, completed: Bool = false) -> Int {
        if completed { return 1000 }
        let safeTarget = max(target, 1)
        if current <= 0 { return 0 }
        if current >= safeTarget { return 1000 }
        return min(1000, current * 1000 / safeTarget)
    }

    public static func permilleBand(_ permille: Int) -> String {
        switch min(1000, max(0, permille)) {
        case 1000: "1000"
        case 750...: "750_999"
        case 500...: "500_749"
        case 250...: "250_499"
        default: "0_249"
        }
    }

    public static func board(state: ProCareerSnapshot) -> ProCareerGoalBoard {
        var rows: [ProGoalBoardRow] = []
        rows.append(contentsOf: ambitionRows(state: state))
        rows.append(retiredNumberRow(state: state))
        rows.append(clubHallRow(state: state))
        rows.append(hallOfFameRow(state: state))
        rows.append(milestoneRow(
            id: "milestoneGames",
            kind: .milestoneGames,
            titleKey: Copy.milestoneGamesTitle,
            hintKey: Copy.milestoneGamesHint,
            current: careerGames(state),
            marks: ProCareerMilestoneRules.gameMarks
        ))
        rows.append(milestoneRow(
            id: "milestoneStrikeouts",
            kind: .milestoneStrikeouts,
            titleKey: Copy.milestoneStrikeoutsTitle,
            hintKey: Copy.milestoneStrikeoutsHint,
            current: careerStrikeouts(state),
            marks: ProCareerMilestoneRules.strikeoutMarks
        ))
        rows.append(teamLegacyRow(state: state))

        let sorted = rows.sorted(by: rowOrder)
        return ProCareerGoalBoard(
            rows: sorted,
            nearest: sorted.first { !$0.completed }
        )
    }

    public static let contentKeys: [String] = Copy.allKeys

    private enum Copy {
        static let ambitionPrefix = "content.goal-board.ambition-metric"
        static let retiredNumberTitle = "content.goal-board.retired-number.title"
        static let retiredNumberHint = "content.goal-board.retired-number.hint"
        static let retiredNumberSeasons = "content.goal-board.retired-number.seasons.title"
        static let retiredNumberLegacy = "content.goal-board.retired-number.legacy.title"
        static let retiredNumberFan = "content.goal-board.retired-number.fan.title"
        static let clubHallTitle = "content.goal-board.club-hall.title"
        static let clubHallHint = "content.goal-board.club-hall.hint"
        static let clubHallSeasons = "content.goal-board.club-hall.seasons.title"
        static let clubHallLegacy = "content.goal-board.club-hall.legacy.title"
        static let hallOfFameTitle = "content.goal-board.hall-of-fame.title"
        static let hallOfFameHint = "content.goal-board.hall-of-fame.hint"
        static let milestoneGamesTitle = "content.goal-board.milestone-games.title"
        static let milestoneGamesHint = "content.goal-board.milestone-games.hint"
        static let milestoneStrikeoutsTitle = "content.goal-board.milestone-strikeouts.title"
        static let milestoneStrikeoutsHint = "content.goal-board.milestone-strikeouts.hint"
        static let teamLegacyTitle = "content.goal-board.team-legacy-tier.title"
        static let teamLegacyHint = "content.goal-board.team-legacy-tier.hint"

        static func ambitionTitle(_ kind: ProCareerGoalMetricKind) -> String {
            "\(ambitionPrefix).\(kind.rawValue.replacingOccurrences(of: "_", with: "-")).title"
        }

        static func ambitionHint(_ kind: ProCareerGoalMetricKind) -> String {
            "\(ambitionPrefix).\(kind.rawValue.replacingOccurrences(of: "_", with: "-")).hint"
        }

        static let metricKinds: [ProCareerGoalMetricKind] = [
            .anchorTeamSeasons,
            .anchorTeamLegacy,
            .hallOfFameProjection,
            .awards,
            .proSeasons,
            .majorServiceYears,
        ]

        static var allKeys: [String] {
            let metrics = metricKinds.flatMap { [ambitionTitle($0), ambitionHint($0)] }
            return metrics + [
                retiredNumberTitle, retiredNumberHint,
                retiredNumberSeasons, retiredNumberLegacy, retiredNumberFan,
                clubHallTitle, clubHallHint, clubHallSeasons, clubHallLegacy,
                hallOfFameTitle, hallOfFameHint,
                milestoneGamesTitle, milestoneGamesHint,
                milestoneStrikeoutsTitle, milestoneStrikeoutsHint,
                teamLegacyTitle, teamLegacyHint,
            ]
        }
    }

    private static func ambitionRows(state: ProCareerSnapshot) -> [ProGoalBoardRow] {
        guard let goal = state.journeyState?.activeGoal else { return [] }
        let progress = ProCareerGoalRules.progress(state: state, goal: goal)
        let locked = progress.completed
        return progress.metrics.map { metric in
            let target = max(metric.target, 1)
            let completed = locked || metric.current >= target
            return ProGoalBoardRow(
                id: "ambition.\(goal.ambition.rawValue).\(metric.kind.rawValue)",
                kind: .ambitionMetric,
                titleKey: Copy.ambitionTitle(metric.kind),
                current: metric.current,
                target: target,
                permille: permille(current: metric.current, target: target, completed: completed),
                completed: completed,
                hintKey: Copy.ambitionHint(metric.kind)
            )
        }
    }

    private static func retiredNumberRow(state: ProCareerSnapshot) -> ProGoalBoardRow {
        let preview = ProRetirementRules.preview(for: state)
        let subRows = [
            makeSubRow(
                id: "retiredNumber.seasons",
                kind: .retiredNumber,
                titleKey: Copy.retiredNumberSeasons,
                hintKey: Copy.retiredNumberHint,
                current: preview.lastTeamSeasons,
                target: 8
            ),
            makeSubRow(
                id: "retiredNumber.legacy",
                kind: .retiredNumber,
                titleKey: Copy.retiredNumberLegacy,
                hintKey: Copy.retiredNumberHint,
                current: preview.lastTeamLegacy,
                target: 80
            ),
            makeSubRow(
                id: "retiredNumber.fan",
                kind: .retiredNumber,
                titleKey: Copy.retiredNumberFan,
                hintKey: Copy.retiredNumberHint,
                current: preview.fanSupport,
                target: 60
            ),
        ]
        let completed = preview.retiredNumberEligible
        let composite = completed ? 1000 : (subRows.map(\.permille).min() ?? 0)
        return ProGoalBoardRow(
            id: "retiredNumber",
            kind: .retiredNumber,
            titleKey: Copy.retiredNumberTitle,
            current: subRows.filter(\.completed).count,
            target: subRows.count,
            permille: composite,
            completed: completed,
            hintKey: Copy.retiredNumberHint,
            subRows: subRows
        )
    }

    private static func clubHallRow(state: ProCareerSnapshot) -> ProGoalBoardRow {
        let preview = ProRetirementRules.preview(for: state)
        let rulesVersion = state.journeyState?.rulesVersion ?? 1
        let records = teamRecords(for: state)
        let completed = !preview.clubHallTeamIDs.isEmpty
        let record: ProTeamCareerRecord?
        if let teamID = preview.clubHallTeamIDs.first {
            record = ProTeamCareerRecordRules.record(teamID: teamID, in: records)
        } else {
            record = bestClubHallCandidate(preview: preview, records: records, rulesVersion: rulesVersion)
        }
        let seasons = record?.completedSeasons ?? 0
        let legacy = record.map { ProTeamLegacyRules.score(record: $0, rulesVersion: rulesVersion) } ?? 0
        let subRows = [
            makeSubRow(
                id: "clubHall.seasons",
                kind: .clubHall,
                titleKey: Copy.clubHallSeasons,
                hintKey: Copy.clubHallHint,
                current: seasons,
                target: 6,
                completed: completed || seasons >= 6
            ),
            makeSubRow(
                id: "clubHall.legacy",
                kind: .clubHall,
                titleKey: Copy.clubHallLegacy,
                hintKey: Copy.clubHallHint,
                current: legacy,
                target: 65,
                completed: completed || legacy >= 65
            ),
        ]
        let composite = completed ? 1000 : (subRows.map(\.permille).min() ?? 0)
        return ProGoalBoardRow(
            id: "clubHall",
            kind: .clubHall,
            titleKey: Copy.clubHallTitle,
            current: subRows.filter(\.completed).count,
            target: subRows.count,
            permille: composite,
            completed: completed,
            hintKey: Copy.clubHallHint,
            subRows: subRows
        )
    }

    private static func hallOfFameRow(state: ProCareerSnapshot) -> ProGoalBoardRow {
        let current: Int
        if let finalScore = state.hallOfFameScore {
            current = finalScore
        } else {
            current = ProCareerEngine.hallOfFameProjection(for: state)
        }
        let target = 70
        let completed = current >= target
        return ProGoalBoardRow(
            id: "hallOfFame",
            kind: .hallOfFame,
            titleKey: Copy.hallOfFameTitle,
            current: current,
            target: target,
            permille: permille(current: current, target: target, completed: completed),
            completed: completed,
            hintKey: Copy.hallOfFameHint
        )
    }

    private static func milestoneRow(
        id: String,
        kind: ProGoalBoardRowKind,
        titleKey: String,
        hintKey: String,
        current: Int,
        marks: [Int]
    ) -> ProGoalBoardRow {
        let next = ProCareerMilestoneRules.nextMark(current: current, marks: marks)
        let target = max(next.mark, 1)
        return ProGoalBoardRow(
            id: id,
            kind: kind,
            titleKey: titleKey,
            current: current,
            target: target,
            permille: permille(current: current, target: target, completed: next.completed),
            completed: next.completed,
            hintKey: hintKey
        )
    }

    private static func teamLegacyRow(state: ProCareerSnapshot) -> ProGoalBoardRow {
        let rulesVersion = state.journeyState?.rulesVersion ?? 1
        let records = teamRecords(for: state)
        let record = ProTeamCareerRecordRules.record(teamID: state.team.id, in: records)
        let score = record.map { ProTeamLegacyRules.score(record: $0, rulesVersion: rulesVersion) } ?? 0
        if let record, let next = ProTeamLegacyRules.nextTierProjection(record: record, rulesVersion: rulesVersion) {
            let target = max(next.minimumScore, 1)
            let completed = false
            return ProGoalBoardRow(
                id: "teamLegacyTier",
                kind: .teamLegacyTier,
                titleKey: Copy.teamLegacyTitle,
                current: score,
                target: target,
                permille: permille(current: score, target: target, completed: completed),
                completed: completed,
                hintKey: Copy.teamLegacyHint
            )
        }
        if record != nil {
            return ProGoalBoardRow(
                id: "teamLegacyTier",
                kind: .teamLegacyTier,
                titleKey: Copy.teamLegacyTitle,
                current: score,
                target: max(score, 1),
                permille: 1000,
                completed: true,
                hintKey: Copy.teamLegacyHint
            )
        }
        return ProGoalBoardRow(
            id: "teamLegacyTier",
            kind: .teamLegacyTier,
            titleKey: Copy.teamLegacyTitle,
            current: 0,
            target: 15,
            permille: 0,
            completed: false,
            hintKey: Copy.teamLegacyHint
        )
    }

    private static func makeSubRow(
        id: String,
        kind: ProGoalBoardRowKind,
        titleKey: String,
        hintKey: String,
        current: Int,
        target: Int,
        completed: Bool? = nil
    ) -> ProGoalBoardRow {
        let safeTarget = max(target, 1)
        let isComplete = completed ?? (current >= safeTarget)
        return ProGoalBoardRow(
            id: id,
            kind: kind,
            titleKey: titleKey,
            current: current,
            target: safeTarget,
            permille: permille(current: current, target: safeTarget, completed: isComplete),
            completed: isComplete,
            hintKey: hintKey
        )
    }

    private static func bestClubHallCandidate(
        preview: ProRetirementPreview,
        records: [ProTeamCareerRecord],
        rulesVersion: Int
    ) -> ProTeamCareerRecord? {
        let excluded = preview.retiredNumberEligible ? Set([preview.lastTeamID].compactMap { $0 }) : []
        let candidates = records.filter { !excluded.contains($0.teamID) }
        return candidates.max { lhs, rhs in
            let left = min(
                permille(current: lhs.completedSeasons, target: 6),
                permille(current: ProTeamLegacyRules.score(record: lhs, rulesVersion: rulesVersion), target: 65)
            )
            let right = min(
                permille(current: rhs.completedSeasons, target: 6),
                permille(current: ProTeamLegacyRules.score(record: rhs, rulesVersion: rulesVersion), target: 65)
            )
            if left != right { return left < right }
            return lhs.teamID > rhs.teamID
        }
    }

    private static func teamRecords(for state: ProCareerSnapshot) -> [ProTeamCareerRecord] {
        let journey = state.journeyState
        return ProTeamCareerRecordRules.backfill(
            careerStats: state.careerStats,
            recognitions: journey?.recognitions ?? [],
            existing: journey?.teamRecords ?? []
        )
    }

    private static func careerGames(_ state: ProCareerSnapshot) -> Int {
        careerTotal(state) { $0.games }
    }

    private static func careerStrikeouts(_ state: ProCareerSnapshot) -> Int {
        careerTotal(state) { $0.strikeouts }
    }

    private static func careerTotal(_ state: ProCareerSnapshot, _ value: (ProSeasonStats) -> Int) -> Int {
        let settled = state.careerStats.reduce(0) { $0 + value($1) }
        let alreadySettled = state.careerStats.contains {
            $0.season == state.currentStats.season && $0.teamID == state.currentStats.teamID
        }
        return settled + (alreadySettled ? 0 : value(state.currentStats))
    }

    private static func rowOrder(_ lhs: ProGoalBoardRow, _ rhs: ProGoalBoardRow) -> Bool {
        if lhs.completed != rhs.completed { return !lhs.completed && rhs.completed }
        if lhs.permille != rhs.permille { return lhs.permille > rhs.permille }
        return lhs.id < rhs.id
    }
}
