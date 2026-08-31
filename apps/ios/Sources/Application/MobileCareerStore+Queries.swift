import Foundation
import Observation
import SimulationCore
import BaseballIOSDomain
import BaseballIOSPersistence

extension MobileCareerStore {
    nonisolated static func gains(before: PitcherSnapshot?, after: PitcherSnapshot) -> [AbilityGain] {
        guard let before else { return [] }
        let pairs = [
            (TalentAbility.stuff, before.stuff, after.stuff),
            (TalentAbility.command, before.command, after.command),
            (TalentAbility.movement, before.movement, after.movement),
            (TalentAbility.stamina, before.stamina, after.stamina)
        ]
        return pairs.compactMap { ability, from, to in
            to > from ? AbilityGain(ability: ability, before: from, after: to) : nil
        }
    }

    nonisolated static func mergingGains(
        _ existing: [AbilityGain],
        _ incoming: [AbilityGain]
    ) -> [AbilityGain] {
        var merged = existing
        for gain in incoming {
            if let index = merged.firstIndex(where: { $0.ability == gain.ability }) {
                let previous = merged[index]
                merged[index] = AbilityGain(
                    ability: gain.ability,
                    before: min(previous.before, gain.before),
                    after: max(previous.after, gain.after)
                )
            } else {
                merged.append(gain)
            }
        }
        return merged.filter { $0.after > $0.before }
    }

    static func logMasteryChanges(
        before: PitcherSnapshot?,
        after: PitcherSnapshot,
        mode: String
    ) {
        guard let before else { return }
        let beforeMastery = before.effectiveMastery
        let afterMastery = after.effectiveMastery
        for ability in TalentAbility.allCases {
            let from = beforeMastery.value(for: ability)
            let to = afterMastery.value(for: ability)
            guard to > from else { continue }
            CareerTelemetry.log(.masteryGained, [
                "ability": ability.rawValue,
                "level_band": MasteryEffectRules.levelBand(to),
                "source": "growth",
                "mode": mode,
            ])
            if MasteryEffectRules.isMilestone(to) {
                CareerTelemetry.log(.masteryMilestone, [
                    "ability": ability.rawValue,
                    "milestone": to,
                    "mode": mode,
                ])
            }
        }
    }

    func progressSummary(before: ProCareerSnapshot?, after: ProCareerSnapshot) -> String {
        guard let before else { return "다음 일정이 준비됐습니다." }
        let weeks = max(1, after.week - before.week)
        let games = max(0, after.currentStats.games - before.currentStats.games)
        let starts = max(0, after.currentStats.starts - before.currentStats.starts)
        let outs = max(0, after.currentStats.inningsOuts - before.currentStats.inningsOuts)
        let fatigue = after.fatigue - before.fatigue
        let trust = after.managerTrust - before.managerTrust
        var values = [
            "\(before.week + 1)~\(after.week)주차",
            "\(weeks)주",
            "\(games)경기(선발 \(starts))",
            Self.inningsText(outs),
            "감독의 믿음 \(trust >= 0 ? "+" : "")\(trust)",
            "피로 \(fatigue >= 0 ? "+" : "")\(fatigue)",
        ]
        if before.level != after.level {
            values.append(after.level == .major ? "1군 합류" : "2군 이동")
        }
        if before.role != after.role { values.append("역할 변경: \(Self.roleName(after.role))") }
        if after.milestones.count > before.milestones.count {
            values.append("주요 기록: \(after.milestones.last ?? "선수 기록")")
        }
        return values.joined(separator: " · ")
    }

    nonisolated static func inningsText(_ outs: Int) -> String {
        let safeOuts = max(0, outs)
        let innings = safeOuts / 3
        switch safeOuts % 3 {
        case 1: return "\(innings)⅓이닝"
        case 2: return "\(innings)⅔이닝"
        default: return "\(innings)이닝"
        }
    }

    nonisolated static func roleName(_ role: ProRole) -> String {
        GameCopyResolver(language: .korean, policy: .releaseSafe).resolve(role.displayCopyToken)
    }

    nonisolated static func developmentTicksRequired(
        for plan: ProWeekPlan,
        pitcher: PitcherSnapshot,
        proRulesVersion: Int?
    ) -> Int? {
        ProCareerEngine.developmentTicksRequired(
            for: plan,
            pitcher: pitcher,
            proRulesVersion: proRulesVersion
        )
    }

    nonisolated static func usesAgencyRules(_ state: ProCareerSnapshot) -> Bool {
        ProCareerEngine.usesAgencyRules(state)
    }

    nonisolated static func careerStanding(for state: ProCareerSnapshot) -> ProCareerStanding {
        ProCareerEngine.careerStanding(for: state)
    }

    nonisolated static func expectedRemainingOutings(for state: ProCareerSnapshot) -> Int {
        ProCareerEngine.expectedRemainingOutings(for: state)
    }

    nonisolated static func retirementPreview(for state: ProCareerSnapshot) -> ProRetirementPreview {
        ProCareerEngine.retirementPreview(for: state)
    }

    nonisolated static func hallOfFameProjection(for state: ProCareerSnapshot) -> Int {
        ProCareerEngine.hallOfFameProjection(for: state)
    }

    nonisolated static func team(id: String) -> DraftTeamSnapshot? {
        ProCareerEngine.proTeams.first(where: { $0.id == id })
    }

    struct TeamLegacyProjection: Equatable {
        let record: ProTeamCareerRecord?
        let score: Int
        let tier: ProTeamLegacyTier?
        let nextMinimumScore: Int?
        let nextTier: ProTeamLegacyTier?
        let nextMinimumCompletedSeasons: Int?

        var next: Bool { nextTier != nil }
    }

    nonisolated static func teamCareerRecords(for state: ProCareerSnapshot) -> [ProTeamCareerRecord] {
        guard let journey = state.journeyState else { return [] }
        return ProTeamCareerRecordRules.backfill(
            careerStats: state.careerStats,
            recognitions: journey.recognitions,
            existing: journey.teamRecords
        )
    }

    nonisolated static func teamLegacyProjection(
        teamID: String,
        records: [ProTeamCareerRecord],
        rulesVersion: Int
    ) -> TeamLegacyProjection {
        let record = ProTeamCareerRecordRules.record(teamID: teamID, in: records)
        guard let record else {
            return TeamLegacyProjection(
                record: nil,
                score: 0,
                tier: nil,
                nextMinimumScore: nil,
                nextTier: nil,
                nextMinimumCompletedSeasons: nil
            )
        }
        let next = ProTeamLegacyRules.nextTierProjection(record: record, rulesVersion: rulesVersion)
        return TeamLegacyProjection(
            record: record,
            score: ProTeamLegacyRules.score(record: record, rulesVersion: rulesVersion),
            tier: ProTeamLegacyRules.tier(record: record, rulesVersion: rulesVersion),
            nextMinimumScore: next?.minimumScore,
            nextTier: next?.tier,
            nextMinimumCompletedSeasons: next?.minimumCompletedSeasons
        )
    }

    nonisolated static func goalProgress(
        state: ProCareerSnapshot,
        goal: ProCareerGoalState
    ) -> ProCareerGoalProgress {
        ProCareerGoalRules.progress(state: state, goal: goal)
    }

    nonisolated static func recommendedRepertoire(presetID: String) -> StartingRepertoireSelection {
        CareerDisplayRules.recommendedRepertoire(presetID: presetID)
    }

    nonisolated static var pitchLearningPracticeCap: Int {
        CareerDisplayRules.pitchLearningPracticeCap
    }

    nonisolated static var pitchLearningQualityUses: Int {
        CareerDisplayRules.pitchLearningQualityUses
    }

    nonisolated static func pitcherIdentity(for pitcher: PitcherSnapshot) -> PitcherBuildIdentity {
        CareerDisplayRules.pitcherIdentity(for: pitcher)
    }

    nonisolated static func investmentCost(for investment: ProOffseasonInvestment) -> Int64 {
        CareerDisplayRules.investmentCost(for: investment)
    }

    nonisolated static func masteryBonusPermille(level: Int) -> Int {
        CareerDisplayRules.masteryBonusPermille(level: level)
    }
}
