import Foundation
import SwiftUI
import SimulationCore
import BaseballIOSDomain

/// English-safe projection for professional-career snapshots.
///
/// Professional saves written before localization contain complete Korean sentences. Those fields
/// remain untouched for save and iCloud compatibility. This projection uses stable enum values,
/// choice IDs, team IDs, rival IDs, and numeric fields to author the visible English copy.
enum ProCareerPresentation {
    struct RivalCopy: Equatable {
        let name: String
        let teamName: String
        let archetype: String
        let record: String
        let profile: String
    }

    struct TensionCopy: Equatable {
        let title: String
        let detail: String
    }

    static func goalTitle(_ ambition: ProCareerAmbition, resolver: GameCopyResolver) -> String {
        let key: ProUICopyKey = switch ambition {
        case .franchiseIcon: .directionGoalFranchise
        case .recordBook: .directionGoalRecord
        case .enduringPro: .directionGoalEnduring
        }
        return resolver.resolve(key)
    }

    static func goalMetricTitle(_ kind: ProCareerGoalMetricKind, resolver: GameCopyResolver) -> String {
        let key: ProUICopyKey = switch kind {
        case .anchorTeamSeasons: .goalMetricAnchorSeasons
        case .anchorTeamLegacy: .goalMetricAnchorLegacy
        case .hallOfFameProjection: .goalMetricHOF
        case .awards: .goalMetricAwards
        case .proSeasons: .goalMetricProSeasons
        case .majorServiceYears: .goalMetricMajorService
        }
        return resolver.resolve(key)
    }

    static func teamRecords(for state: ProCareerSnapshot) -> [ProTeamCareerRecord] {
        MobileCareerStore.teamCareerRecords(for: state)
    }

    static func teamName(_ teamID: String, resolver: GameCopyResolver) -> String {
        guard let team = MobileCareerStore.team(id: teamID) else {
            return teamID
        }
        return teamName(team, resolver: resolver)
    }

    static func honorTitle(_ kind: ProRetirementHonorKind, resolver: GameCopyResolver) -> String {
        let key: ProUICopyKey = switch kind {
        case .hallOfFame: .retirementHonorHallOfFame
        case .retiredNumber: .retirementHonorRetiredNumber
        case .clubHall: .retirementHonorClubHall
        case .ambitionCompleted: .retirementHonorAmbition
        case .careerEarnings: .retirementHonorEarnings
        case .nationalGold: .retirementHonorNationalGold
        }
        return resolver.resolve(key)
    }

    static func teamName(_ team: DraftTeamSnapshot, resolver: GameCopyResolver) -> String {
        HighSchoolConclusionPresentation.localizedTeamName(team, resolver: resolver)
    }

    static func decisionDetail(_ decision: ProSeasonDecision, resolver: GameCopyResolver) -> String {
        if decision.type == .mediaOpportunity {
            return resolver.resolve(.gameContent("content.pro-media-opportunity.detail"))
        }
        if isContentKey(decision.detail) {
            return resolver.resolve(.gameContent(decision.detail))
        }
        guard resolver.language != .korean else { return decision.detail }
        return resolver.resolve(.gameContent("content.pro-decision.\(decision.type.rawValue).detail"))
    }

    static func decisionTitle(_ decision: ProSeasonDecision, resolver: GameCopyResolver) -> String {
        if decision.type == .mediaOpportunity {
            return resolver.resolve(.gameContent("content.pro-media-opportunity.title"))
        }
        if isContentKey(decision.title) {
            return resolver.resolve(.gameContent(decision.title))
        }
        if resolver.language == .korean { return decision.title }
        return resolver.resolve(decision.type.displayCopyToken)
    }

    static func decisionTiming(
        for decision: ProSeasonDecision,
        resolver: GameCopyResolver
    ) -> String {
        if decision.type.isWeeklyBinaryDecision {
            return resolver.resolve(.decisionFollowUpLater)
        }
        return decision.type == .mediaOpportunity
            ? resolver.resolve(.decisionImmediateEffect)
            : resolver.resolve(.decisionFollowUp)
    }

    static func decisionTiming(
        for choice: ProSeasonDecisionChoice,
        resolver: GameCopyResolver
    ) -> String {
        if choice.id.hasPrefix("rotation_push.")
            || choice.id.hasPrefix("new_pitch_trial.")
            || choice.id.hasPrefix("farm_reset.")
            || choice.id.hasPrefix("veteran_mentor.") {
            return resolver.resolve(.decisionFollowUpLater)
        }
        return choice.id.hasPrefix("media_opportunity.")
            ? resolver.resolve(.decisionImmediateEffect)
            : resolver.resolve(.decisionFollowUp)
    }

    static func choiceFollowUpLine(
        _ choice: ProSeasonDecisionChoice,
        resolver: GameCopyResolver
    ) -> String? {
        let suffix = ordinaryDecisionChoiceContentID(choice.id)
        let key = "content.pro-decision.choice.\(suffix).follow-up"
        guard GameCopyKey.isSemanticID(key) else { return nil }
        let resolved = resolver.resolve(.gameContent(key))
        return resolved == GameCopyResolver.unavailableText ? nil : resolved
    }

    static func followUpSummary(
        _ followUp: ProDecisionFollowUp,
        resolver: GameCopyResolver
    ) -> String {
        if isContentKey(followUp.summaryKey) {
            var parts = [resolver.resolve(.gameContent(followUp.summaryKey))]
            if let qualityStarts = followUp.qualityStarts {
                parts.append("QS \(qualityStarts)")
            }
            if let runs = followUp.runsAllowed {
                parts.append(resolver.resolve(.decisionFollowUpRuns, arguments: [.integer(runs)]))
            }
            if let restored = followUp.commandRestored, restored != 0 {
                parts.append(resolver.resolve(
                    restored > 0 ? .effectCommandGain : .effectCommandLoss,
                    arguments: [.integer(abs(restored))]
                ))
            }
            if let trust = followUp.managerTrustDelta, trust != 0 {
                parts.append(resolver.resolve(
                    trust > 0 ? .effectManagerGain : .effectManagerLoss,
                    arguments: [.integer(abs(trust))]
                ))
            }
            return parts.joined(separator: " · ")
        }
        return followUp.summaryKey
    }

    static func isContentKey(_ raw: String) -> Bool {
        raw.hasPrefix("content.pro-decision.") || raw.hasPrefix("content.pro-media-opportunity.")
    }

    /// Week-range token for the weekly result banner. Spring camp and a single
    /// completed week never render as `N~M` with start > end or a duplicated bound.
    static func weekSpanLabel(
        beforeWeek: Int,
        afterWeek: Int,
        resolver: GameCopyResolver
    ) -> String {
        if afterWeek <= 0 {
            return resolver.resolve(.summaryWeekSpanSpringCamp)
        }
        if afterWeek <= beforeWeek {
            return resolver.resolve(.summaryWeekSpanSingle, arguments: [.integer(afterWeek)])
        }
        let start = beforeWeek + 1
        let end = afterWeek
        if start > end {
            return resolver.resolve(.summaryWeekSpanSingle, arguments: [.integer(end)])
        }
        if start == end {
            return resolver.resolve(.summaryWeekSpanSingle, arguments: [.integer(end)])
        }
        return resolver.resolve(
            .summaryWeekSpanRange,
            arguments: [.integer(start), .integer(end)]
        )
    }

    /// 주간 진행 요약 한 줄("1주차 · 1주 · 0경기(선발 0) · 0이닝 · 감독의 믿음 -1 · 피로 +0 · …")을
    /// 분해한다. 1.2.9 가독성 교정: 같은 값이 요약 줄과 아래 상태 타일에 두 번 찍히던 것을
    /// 타일 캡션 하나로 모으기 위한 것이다. 요약 형식이 아니면 nil.
    struct WeekProgressSummary: Equatable {
        let managerTrustDelta: Int
        let fatigueDelta: Int
        /// 승격·역할 변경·주요 기록처럼 숫자 타일에 담기지 않는 나머지 항목.
        let extras: [String]
    }

    static func weekProgress(_ raw: String) -> WeekProgressSummary? {
        let parts = raw.components(separatedBy: " · ")
        guard parts.count >= 6,
              parts[1].hasSuffix("주"),
              parts[3].hasSuffix("이닝"),
              let trustIndex = parts.firstIndex(where: { $0.hasPrefix("감독의 믿음 ") }),
              trustIndex + 1 < parts.count,
              parts[trustIndex + 1].hasPrefix("피로 "),
              let trust = Int(parts[trustIndex].dropFirst("감독의 믿음 ".count)),
              let fatigue = Int(parts[trustIndex + 1].dropFirst("피로 ".count))
        else { return nil }
        return WeekProgressSummary(
            managerTrustDelta: trust,
            fatigueDelta: fatigue,
            extras: Array(parts[(trustIndex + 2)...])
        )
    }

    static func storeSummary(
        _ raw: String,
        state: ProCareerSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language != .korean else { return raw }
        let team = teamName(state.team, resolver: resolver)
        switch raw {
        case "현재 저장본을 읽지 못해 직전 정상 백업으로 복구했습니다.":
            return legacy("content.pro-summary.backup-recovered", resolver: resolver)
        case let value where value.hasSuffix("입단. 2군에서 첫 시즌을 시작합니다."):
            return legacy("content.pro-summary.joined-direct", [.userText(team)], resolver: resolver)
        case let value where value.hasSuffix("입단. 고교 3년의 능력을 그대로 안고 시작합니다."):
            return legacy("content.pro-summary.joined-high-school", [.userText(team)], resolver: resolver)
        case let value where value.hasSuffix("지명. 신인 계약 제안을 확인해 주세요."):
            return legacy("content.pro-summary.rookie-offer", [.userText(team)], resolver: resolver)
        case "등판을 중단했습니다. 다음 마운드는 새 이닝입니다.":
            return legacy("content.pro-summary.outing-abandoned", resolver: resolver)
        case "연투를 선택했습니다. 추가 피로를 반영했습니다.":
            return resolver.resolve(.postseasonAvailabilityPitchSummary)
        case "한 경기를 쉬고 다음 등판을 준비합니다.":
            return resolver.resolve(.postseasonAvailabilityRestSummary)
        case "시즌 기록을 통산 기록에 확정했습니다.":
            return legacy("content.pro-summary.season-recorded", resolver: resolver)
        case "계약을 확정했습니다.":
            return legacy("content.pro-summary.contract-signed", resolver: resolver)
        case "현재 구단에서 다음 시즌을 준비합니다.":
            return legacy("content.pro-summary.continue", [.userText(team)], resolver: resolver)
        case "두 시즌의 군 복무를 마치고 돌아옵니다.":
            return legacy("content.pro-summary.military", resolver: resolver)
        case "FA를 신청했습니다.":
            return legacy("content.pro-summary.free-agency", resolver: resolver)
        case "은퇴를 선택했습니다.":
            return legacy("content.pro-summary.retire", resolver: resolver)
        case "다음 일정이 준비됐습니다.":
            return legacy("content.pro-summary.ready", resolver: resolver)
        case "1군 출전 명단에 합류했습니다. 다음 주목받는 등판이 바로 이어집니다.":
            return legacy("content.pro-summary.call-up", resolver: resolver)
        default:
            break
        }

        if raw.hasPrefix("감독 면담 뒤 역할이 ") {
            return legacy(
                "content.pro-summary.role-changed",
                [.userText(resolver.resolve(state.role.displayCopyToken))],
                resolver: resolver
            )
        }
        if raw.hasPrefix("새 주요 기록 · "), let latest = state.milestones.last {
            return legacy(
                "content.pro-summary.milestone",
                [.userText(milestone(latest, resolver: resolver))],
                resolver: resolver
            )
        }
        if let values = captures(
            raw,
            pattern: #"^(\d+)주차 완료 · 감독의 믿음 ([+-]?\d+) · 피로 ([+-]?\d+)$"#
        ), values.count == 3,
           let week = Int(values[0]), let trust = Int(values[1]), let fatigue = Int(values[2]) {
            return legacy(
                "content.pro-summary.week",
                [.integer(week), .integer(trust), .integer(fatigue)],
                resolver: resolver
            )
        }
        if let week = captures(raw, pattern: #"^시즌 결정 · (\d+)주차$"#)?.first.flatMap(Int.init) {
            return legacy("content.pro-news.weekly-decision", [.integer(week)], resolver: resolver)
        }
        if let record = state.decisionHistory?.last, raw.contains(" — ") {
            return legacy(
                "content.pro-summary.decision",
                [
                    .userText(resolver.resolve(record.type.displayCopyToken)),
                    .userText(decisionRecordTitle(record, resolver: resolver)),
                    .userText(effect(record.effect, resolver: resolver)),
                ],
                resolver: resolver
            )
        }
        return legacy("content.pro-summary.updated", resolver: resolver)
    }

    static func milestone(_ raw: String, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return raw }
        let exact: [String: String] = [
            "프로 지명": "content.pro-milestone.drafted",
            "신인 계약": "content.pro-milestone.rookie-contract",
            "프로 첫 공식 등판": "content.pro-milestone.first-appearance",
            "1군 콜업": "content.pro-milestone.call-up",
            "1군 첫 중요 승부": "content.pro-milestone.first-major-moment",
        ]
        if let key = exact[raw] { return legacy(key, resolver: resolver) }
        if let values = captures(raw, pattern: #"^(\d+)시즌 (선발|긴 이닝 구원|필승조|마무리) 역할$"#),
           values.count == 2, let season = Int(values[0]), let role = role(forLegacyName: values[1]) {
            return legacy(
                "content.pro-milestone.season-role",
                [.integer(season), .userText(resolver.resolve(role.displayCopyToken))],
                resolver: resolver
            )
        }
        if let values = captures(raw, pattern: #"^프로 통산 (\d+)경기$"#),
           let games = values.first.flatMap(Int.init) {
            return legacy("content.pro-milestone.games", [.integer(games)], resolver: resolver)
        }
        if let values = captures(raw, pattern: #"^프로 통산 (\d+)탈삼진$"#),
           let strikeouts = values.first.flatMap(Int.init) {
            return legacy("content.pro-milestone.strikeouts", [.integer(strikeouts)], resolver: resolver)
        }
        if let values = captures(raw, pattern: #"^(\d+)시즌 완주$"#),
           let season = values.first.flatMap(Int.init) {
            return legacy("content.pro-milestone.season-complete", [.integer(season)], resolver: resolver)
        }
        if let values = captures(raw, pattern: #"^은퇴 · 통산 (\d+)시즌$"#),
           let seasons = values.first.flatMap(Int.init) {
            return legacy("content.pro-milestone.retired", [.integer(seasons)], resolver: resolver)
        }
        return GameCopyResolver.unavailableText
    }

    static func award(_ raw: String, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return raw }
        let patterns: [(String, String)] = [
            (#"^시즌 (\d+) 탈삼진상$"#, "content.pro-award.strikeouts"),
            (#"^시즌 (\d+) 최소 실점상$"#, "content.pro-award.run-prevention"),
            (#"^시즌 (\d+) 정밀 제구상$"#, "content.pro-award.command"),
            (#"^시즌 (\d+) 피안타 억제상$"#, "content.pro-award.hit-prevention"),
            (#"^시즌 (\d+) 이닝 책임상$"#, "content.pro-award.innings"),
            (#"^시즌 (\d+) 가을 왕중전 우승$"#, "content.pro-award.autumn-champion"),
            (#"^시즌 (\d+) 플레이오프 우승$"#, "content.pro-award.autumn-champion"),
        ]
        for (pattern, key) in patterns {
            if let value = captures(raw, pattern: pattern)?.first.flatMap(Int.init) {
                return legacy(key, [.integer(value)], resolver: resolver)
            }
        }
        return GameCopyResolver.unavailableText
    }

    static func news(
        _ raw: String,
        state: ProCareerSnapshot? = nil,
        resolver: GameCopyResolver
    ) -> String {
        if let mediaKey = mediaNewsKey(raw) {
            return resolver.resolve(.gameContent(mediaKey))
        }
        if raw.hasPrefix("content.pro-news.role-request.")
            || raw.hasPrefix("content.pro-news.advancement.")
            || raw.hasPrefix("content.pro-news.national-team.") {
            return resolver.resolve(.gameContent(raw))
        }
        guard resolver.language != .korean else { return raw }
        if raw == "연투를 택했습니다. 다음 경기에도 마운드에 오릅니다." {
            return resolver.resolve(.postseasonNewsPitchAgain)
        }
        if let game = captures(
            raw,
            pattern: #"^한 경기를 쉬었습니다\. 우승 결정전 (\d+)차전을 준비합니다\.$"#
        )?.first.flatMap(Int.init) {
            return resolver.resolve(.postseasonNewsRested, arguments: [.integer(game)])
        }
        if let values = captures(
            raw,
            pattern: #"^한 경기를 쉬었습니다\. (와일드카드|준플레이오프|플레이오프|우승 결정전) (\d+)차전을 준비합니다\.$"#
        ), values.count == 2, let game = Int(values[1]) {
            return resolver.resolve(
                .postseasonNewsRoundRested,
                arguments: [.userText(localizedPostseasonRound(values[0], resolver: resolver)), .integer(game)]
            )
        }
        if let values = captures(
            raw,
            pattern: #"^우승 결정전 (\d+)차전이 남았습니다\. 시리즈 (\d+)-(\d+)\.$"#
        ), values.count == 3,
           let game = Int(values[0]), let wins = Int(values[1]), let losses = Int(values[2]) {
            return resolver.resolve(
                .postseasonNewsSeriesContinues,
                arguments: [.integer(game), .integer(wins), .integer(losses)]
            )
        }
        if let values = captures(
            raw,
            pattern: #"^(와일드카드|준플레이오프|플레이오프|우승 결정전) (\d+)차전이 남았습니다\. 시리즈 (\d+)-(\d+)\.$"#
        ), values.count == 4,
           let game = Int(values[1]), let wins = Int(values[2]), let losses = Int(values[3]) {
            return resolver.resolve(
                .postseasonNewsRoundContinues,
                arguments: [
                    .userText(localizedPostseasonRound(values[0], resolver: resolver)),
                    .integer(game), .integer(wins), .integer(losses),
                ]
            )
        }
        if let values = captures(
            raw,
            pattern: #"^우승 결정전 (\d+)차전 자동 진행 · (\d+)-(\d+) (승|패)$"#
        ), values.count == 4,
           let game = Int(values[0]), let teamRuns = Int(values[1]), let opponentRuns = Int(values[2]) {
            return resolver.resolve(
                values[3] == "승" ? .postseasonNewsAutomaticWin : .postseasonNewsAutomaticLoss,
                arguments: [.integer(game), .integer(teamRuns), .integer(opponentRuns)]
            )
        }
        if let values = captures(
            raw,
            pattern: #"^우승 결정전 (\d+)차전 잔여 경기 진행 · (\d+)-(\d+) (승|패)$"#
        ), values.count == 4,
           let game = Int(values[0]), let teamRuns = Int(values[1]), let opponentRuns = Int(values[2]) {
            return resolver.resolve(
                values[3] == "승" ? .postseasonNewsDirectWin : .postseasonNewsDirectLoss,
                arguments: [.integer(game), .integer(teamRuns), .integer(opponentRuns)]
            )
        }
        if let values = captures(
            raw,
            pattern: #"^가을 직접 등판 뒤 잔여 경기 진행 · (\d+)-(\d+) (승|패)$"#
        ), values.count == 3,
           let teamRuns = Int(values[0]), let opponentRuns = Int(values[1]) {
            return resolver.resolve(
                values[2] == "승" ? .postseasonNewsRemainderWin : .postseasonNewsRemainderLoss,
                arguments: [.integer(teamRuns), .integer(opponentRuns)]
            )
        }
        switch raw {
        case "명예의 전당 헌액이 확정됐습니다.":
            return legacy("content.pro-news.retirement.hall-of-fame", resolver: resolver)
        case "은퇴식에서 선수 생활의 마지막 공을 돌아봤습니다.":
            return legacy("content.pro-news.retirement.ceremony", resolver: resolver)
        case "신인 계약에 서명했습니다. 2군 선발 경쟁이 시작됩니다.":
            return legacy("content.pro-news.rookie-contract", resolver: resolver)
        case "2군 기록과 감독의 믿음을 쌓아 1군 출전 명단에 합류했습니다.":
            return legacy("content.pro-news.call-up", resolver: resolver)
        case "최근 등판이 이어지지 않아 2군으로 내려갑니다. 기록을 다시 쌓아야 합니다.":
            return legacy("content.pro-news.demotion", resolver: resolver)
        case "두 시즌의 군 복무를 마치고 복귀했습니다.":
            return legacy("content.pro-news.military-return", resolver: resolver)
        case "스프링캠프가 열렸습니다. 새 시즌 준비를 시작합니다.":
            return legacy("content.pro-news.segment.spring-camp", resolver: resolver)
        case "개막 시리즈가 시작됐습니다. 첫인상을 남길 시간입니다.":
            return legacy("content.pro-news.segment.opening", resolver: resolver)
        case "전반기 레이스에 들어섰습니다. 긴 시즌의 리듬을 잡습니다.":
            return legacy("content.pro-news.segment.first-half", resolver: resolver)
        case "올스타 휴식기입니다. 몸을 추스르고 후반기를 준비합니다.":
            return legacy("content.pro-news.segment.all-star", resolver: resolver)
        case "순위 경쟁이 뜨거워집니다. 한 경기의 무게가 커집니다.":
            return legacy("content.pro-news.segment.pennant-race", resolver: resolver)
        case "시즌 막바지, 마지막 순위 싸움이 남았습니다.":
            return legacy("content.pro-news.segment.finale", resolver: resolver)
        case "가을 왕중전 우승. 올해의 마지막 공이 남았습니다.",
             "플레이오프 우승. 올해의 마지막 공이 남았습니다.":
            return legacy("content.pro-news.autumn.champion", resolver: resolver)
        case "결승에서 멈췄습니다. 가을은 여기까지입니다.":
            return legacy("content.pro-news.autumn.runner-up", resolver: resolver)
        case "가을 왕중전에서 탈락했습니다.":
            return legacy("content.pro-news.autumn.eliminated", resolver: resolver)
        case "다음 라운드가 열립니다.":
            return legacy("content.pro-news.autumn.advanced", resolver: resolver)
        case "와일드카드 2차전이 남았습니다.":
            return legacy("content.pro-news.autumn.wild-card-game-two", resolver: resolver)
        case "정규시즌 1위입니다. 우승 결정전 한 판이 남았습니다.",
             "정규시즌 1위입니다. 우승 결정전에서 기다립니다.":
            return legacy("content.pro-news.autumn.seed-1", resolver: resolver)
        case "정규시즌 2위입니다. 플레이오프 한 판부터 올라갑니다.",
             "정규시즌 2위입니다. 플레이오프부터 올라갑니다.":
            return legacy("content.pro-news.autumn.seed-2", resolver: resolver)
        case "정규시즌 3위입니다. 준플레이오프 한 판부터 시작합니다.",
             "정규시즌 3위입니다. 준플레이오프부터 시작합니다.":
            return legacy("content.pro-news.autumn.seed-3", resolver: resolver)
        case "정규시즌 4위입니다. 와일드카드에서 한 승이면 올라갑니다.":
            return legacy("content.pro-news.autumn.seed-4", resolver: resolver)
        case "정규시즌 5위입니다. 와일드카드에서 두 번을 이겨야 합니다.":
            return legacy("content.pro-news.autumn.seed-5", resolver: resolver)
        case "정규시즌이 끝났습니다. 올해는 플레이오프에 들지 못했습니다.",
             "정규시즌이 끝났습니다. 올해는 가을 왕중전에 들지 못했습니다.":
            return legacy("content.pro-news.autumn.did-not-qualify", resolver: resolver)
        case "플레이오프가 열립니다.",
             "정규시즌 5위 안에 들었습니다. 플레이오프가 열립니다.":
            return legacy("content.pro-news.autumn.opens", resolver: resolver)
        case "구단은 가을에 올랐지만 2군이라 마운드에 서지 못했습니다.":
            return legacy("content.pro-news.autumn.unavailable-minor", resolver: resolver)
        case "구단은 가을에 올랐지만 부상으로 마운드에 서지 못했습니다.":
            return legacy("content.pro-news.autumn.unavailable-injury", resolver: resolver)
        case "와일드카드에서 탈락했습니다.":
            return legacy("content.pro-news.autumn.eliminated-wild-card", resolver: resolver)
        case "준플레이오프에서 탈락했습니다.":
            return legacy("content.pro-news.autumn.eliminated-semifinal", resolver: resolver)
        case "플레이오프에서 탈락했습니다.":
            return legacy("content.pro-news.autumn.eliminated-playoff", resolver: resolver)
        case "가을이 이어집니다.":
            return legacy("content.pro-news.autumn.continues", resolver: resolver)
        case "가을이 닫혔습니다.":
            return legacy("content.pro-news.autumn.closed", resolver: resolver)
        default:
            break
        }

        if raw == "새 구종 완성 · 이제 보조 구종으로 승부합니다."
            || raw == "새 구종을 보조 구종으로 완성했습니다." {
            return legacy("content.pro-news.pitch-learning.completed", resolver: resolver)
        }
        if raw == "구종 연구 진전 · 다음 공식 경기에서 개발 구종을 시험할 수 있습니다." {
            return legacy("content.pro-news.pitch-learning.game-ready", resolver: resolver)
        }
        if let value = captures(raw, pattern: #"^구종 연구 진전 · 반복 감각 \+(\d+)$"#)?.first.flatMap(Int.init) {
            return legacy("content.pro-news.pitch-learning.practice", [.integer(value)], resolver: resolver)
        }
        if let value = captures(raw, pattern: #"^개발 구종 실전 감각 \+(\d+)\.$"#)?.first.flatMap(Int.init) {
            return legacy("content.pro-news.pitch-learning.live", [.integer(value)], resolver: resolver)
        }
        if let week = captures(raw, pattern: #"^(\d+)주차 · 상대 타선이 흔들린다"#)?.first.flatMap(Int.init) {
            return legacy("content.pro-news.climate.hot", [.integer(week)], resolver: resolver)
        }
        if let week = captures(raw, pattern: #"^(\d+)주차 · 리그는 평이하다"#)?.first.flatMap(Int.init) {
            return legacy("content.pro-news.climate.even", [.integer(week)], resolver: resolver)
        }
        if let week = captures(raw, pattern: #"^(\d+)주차 · 타선이 직구를 기다리기 시작했다"#)?.first.flatMap(Int.init) {
            return legacy("content.pro-news.climate.slump", [.integer(week)], resolver: resolver)
        }
        if let week = captures(raw, pattern: #"^(\d+)주차 · 상대 벤치가 내 구종 순서를 읽고 있다"#)?.first.flatMap(Int.init) {
            return legacy("content.pro-news.climate.adapted", [.integer(week)], resolver: resolver)
        }
        if let age = captures(raw, pattern: #"^(\d+)세 · 전성기가 기울며 구위가 한 단계 떨어졌습니다\.$"#)?.first.flatMap(Int.init) {
            return legacy("content.pro-news.aging.decline", [.integer(age)], resolver: resolver)
        }
        if let week = captures(raw, pattern: #"^시즌 결정 · (\d+)주차$"#)?.first.flatMap(Int.init) {
            return legacy("content.pro-news.weekly-decision", [.integer(week)], resolver: resolver)
        }
        if raw == "결정 결과" {
            return legacy("content.pro-news.decision-followup.generic", resolver: resolver)
        }
        if raw.hasPrefix("결정 결과 · ") {
            if let values = captures(
                raw,
                pattern: #"^결정 결과 · 등판 간격 · QS (\d+) · 실점 (\d+)$"#
            ), values.count == 2, let qualityStarts = Int(values[0]), let runs = Int(values[1]) {
                return legacy(
                    "content.pro-news.decision-followup.rotation-push",
                    [.integer(qualityStarts), .integer(runs)],
                    resolver: resolver
                )
            }
            if let restored = captures(
                raw,
                pattern: #"^결정 결과 · 신구종 실전 · 제구 회복 \+(\d+)$"#
            )?.first.flatMap(Int.init) {
                return legacy(
                    "content.pro-news.decision-followup.new-pitch-trial",
                    [.integer(restored)],
                    resolver: resolver
                )
            }
            if raw == "결정 결과 · 2군 재정비 · 복귀 · 감독의 믿음 +4" {
                return legacy("content.pro-news.decision-followup.farm-reset", resolver: resolver)
            }
            if let values = captures(
                raw,
                pattern: #"^결정 결과 · 베테랑 조언 · 성장 구위 ([+-]?\d+) · 제구 ([+-]?\d+) · 변화구 ([+-]?\d+)$"#
            ), values.count == 3,
               let stuff = Int(values[0]), let command = Int(values[1]), let movement = Int(values[2]) {
                return legacy(
                    "content.pro-news.decision-followup.veteran-mentor",
                    [.integer(stuff), .integer(command), .integer(movement)],
                    resolver: resolver
                )
            }
        }

        if let values = captures(raw, pattern: #"^신인 계약 제안 · (.+) · (.+)$"#), values.count == 2 {
            let localizedTeam = leagueTeamName(values[0], resolver: resolver)
            return legacy(
                "content.pro-news.rookie-offer",
                [.userText(localizedTeam), .userText(values[1])],
                resolver: resolver
            )
        }
        if let values = captures(raw, pattern: #"^프로 첫 공식 등판을 마쳤습니다\. (\d+)경기에서 (\d+)개의 삼진을 잡았습니다\.$"#),
           values.count == 2, let games = Int(values[0]), let strikeouts = Int(values[1]) {
            return legacy(
                "content.pro-news.first-appearance",
                [.integer(games), .integer(strikeouts)],
                resolver: resolver
            )
        }
        if let values = captures(raw, pattern: #"^(\d+)주차 · (\d+)경기 · (\d+)K · (\d+)볼넷 · (\d+)실점$"#),
           values.count == 5, let week = Int(values[0]), let games = Int(values[1]),
           let strikeouts = Int(values[2]), let walks = Int(values[3]), let runs = Int(values[4]) {
            return legacy(
                "content.pro-news.week",
                [.integer(week), .integer(games), .integer(strikeouts), .integer(walks), .integer(runs)],
                resolver: resolver
            )
        }
        if let values = captures(raw, pattern: #"^감독 면담 뒤 다음 등판부터 (선발|긴 이닝 구원|필승조|마무리) 역할을 맡습니다\.$"#),
           let roleName = values.first, let role = role(forLegacyName: roleName) {
            return legacy(
                "content.pro-news.role",
                [.userText(resolver.resolve(role.displayCopyToken))],
                resolver: resolver
            )
        }
        if let values = captures(raw, pattern: #"^과부하로 (\d+)주 부상자 명단에 올랐습니다\.$"#),
           let weeks = values.first.flatMap(Int.init) {
            return legacy("content.pro-news.injury", [.integer(weeks)], resolver: resolver)
        }
        if let values = captures(raw, pattern: #"^시즌 (\d+) 종료 · (\d+)경기 · (\d+)K · 9이닝당 실점 ([0-9.]+)$"#),
           values.count == 4, let season = Int(values[0]), let games = Int(values[1]),
           let strikeouts = Int(values[2]) {
            return legacy(
                "content.pro-news.season-end",
                [.integer(season), .integer(games), .integer(strikeouts), .userText(values[3])],
                resolver: resolver
            )
        }
        if let values = captures(raw, pattern: #"^FA 계약: (.+)과 새 도전을 시작합니다\.$"#),
           let team = values.first {
            return legacy(
                "content.pro-news.free-agency",
                [.userText(leagueTeamName(team, resolver: resolver))],
                resolver: resolver
            )
        }
        if let values = captures(raw, pattern: #"^통산 (\d+)시즌 · (\d+)경기 · (\d+)탈삼진 · 9이닝당 실점 ([0-9.]+)$"#),
           values.count == 4, let seasons = Int(values[0]), let games = Int(values[1]),
           let strikeouts = Int(values[2]) {
            return legacy(
                "content.pro-news.retirement.totals",
                [.integer(seasons), .integer(games), .integer(strikeouts), .userText(values[3])],
                resolver: resolver
            )
        }
        if let values = captures(raw, pattern: #"^가장 빛난 해는 (\d+)시즌 — (\d+)경기에서 (\d+)개의 탈삼진을 잡았습니다\.$"#),
           values.count == 3, let season = Int(values[0]), let games = Int(values[1]),
           let strikeouts = Int(values[2]) {
            return legacy(
                "content.pro-news.retirement.best-season",
                [.integer(season), .integer(games), .integer(strikeouts)],
                resolver: resolver
            )
        }
        if raw.hasPrefix("첫 기록: ") {
            let body = String(raw.dropFirst("첫 기록: ".count))
            let pieces = body.components(separatedBy: " · 마지막 수상: ")
            let first = milestone(pieces[0], resolver: resolver)
            if pieces.count == 2 {
                return legacy(
                    "content.pro-news.retirement.first-and-award",
                    [.userText(first), .userText(award(pieces[1], resolver: resolver))],
                    resolver: resolver
                )
            }
            return legacy("content.pro-news.retirement.first", [.userText(first)], resolver: resolver)
        }
        if let values = captures(raw, pattern: #"^마지막 공은 (.+)의 유니폼으로 던졌습니다\.$"#),
           let team = values.first {
            return legacy(
                "content.pro-news.retirement.last-team",
                [.userText(leagueTeamName(team, resolver: resolver))],
                resolver: resolver
            )
        }

        // A legacy sentence can be unknown after a future core update. Never leak it into English.
        return GameCopyResolver.unavailableText
    }

    private static func localizedPostseasonRound(
        _ raw: String,
        resolver: GameCopyResolver
    ) -> String {
        let key: ProUICopyKey = switch raw {
        case "와일드카드": .postseasonRoundWildCard
        case "준플레이오프": .postseasonRoundSemifinal
        case "플레이오프": .postseasonRoundPlayoff
        case "우승 결정전": .postseasonRoundFinal
        default: .postseasonRoundUnknown
        }
        return resolver.resolve(key)
    }

    private static func mediaNewsKey(_ raw: String) -> String? {
        switch raw {
        case "content.pro-media-opportunity.resolved.advertising_shoot",
             "content.pro-media-opportunity.resolved.fan_together_shoot",
             "content.pro-media-opportunity.resolved.focus_on_season":
            return raw
        default:
            return nil
        }
    }

    static func choiceTitle(_ choice: ProSeasonDecisionChoice, resolver: GameCopyResolver) -> String {
        if isContentKey(choice.title) {
            return resolver.resolve(.gameContent(choice.title))
        }
        if choice.id.hasPrefix("media_opportunity.") {
            let suffix = String(choice.id.dropFirst("media_opportunity.".count))
            let contentSuffix = switch suffix {
            case "advertising_shoot": "advertising"
            case "fan_together_shoot": "fan_together"
            case "focus_on_season": "focus"
            default: suffix
            }
            return resolver.resolve(.gameContent("content.pro-media-opportunity.choice.\(contentSuffix).title"))
        }
        guard resolver.language != .korean else { return choice.title }
        return resolver.resolve(.gameContent(
            "content.pro-decision.choice.\(ordinaryDecisionChoiceContentID(choice.id)).title"
        ))
    }

    static func choiceDetail(_ choice: ProSeasonDecisionChoice, resolver: GameCopyResolver) -> String {
        if isContentKey(choice.detail) {
            return resolver.resolve(.gameContent(choice.detail))
        }
        if choice.id.hasPrefix("media_opportunity.") {
            let suffix = String(choice.id.dropFirst("media_opportunity.".count))
            let contentSuffix = switch suffix {
            case "advertising_shoot": "advertising"
            case "fan_together_shoot": "fan_together"
            case "focus_on_season": "focus"
            default: suffix
            }
            return resolver.resolve(.gameContent("content.pro-media-opportunity.choice.\(contentSuffix).detail"))
        }
        guard resolver.language != .korean else { return choice.detail }
        return resolver.resolve(.gameContent(
            "content.pro-decision.choice.\(ordinaryDecisionChoiceContentID(choice.id)).detail"
        ))
    }

    static func decisionRecordTitle(_ record: ProDecisionRecord, resolver: GameCopyResolver) -> String {
        if isContentKey(record.choiceTitle) {
            return resolver.resolve(.gameContent(record.choiceTitle))
        }
        if record.type == .mediaOpportunity {
            let suffix = String(record.choiceID.dropFirst("media_opportunity.".count))
            let contentSuffix = switch suffix {
            case "advertising_shoot": "advertising"
            case "fan_together_shoot": "fan_together"
            case "focus_on_season": "focus"
            default: suffix
            }
            return resolver.resolve(.gameContent("content.pro-media-opportunity.choice.\(contentSuffix).title"))
        }
        guard resolver.language != .korean else { return record.choiceTitle }
        return resolver.resolve(.gameContent(
            "content.pro-decision.choice.\(ordinaryDecisionChoiceContentID(record.choiceID)).title"
        ))
    }

    /// Core decision IDs are namespaced as `<decision-type>.<choice>`, while the shared copy
    /// catalog intentionally keys choices by the reusable suffix only. Older persisted rows may
    /// already contain an unnamespaced suffix, so keep those unchanged.
    private static func ordinaryDecisionChoiceContentID(_ persistedID: String) -> String {
        persistedID.split(separator: ".", omittingEmptySubsequences: true).last.map(String.init)
            ?? persistedID
    }

    static func journeyEffect(_ effect: ProJourneyEffect?, resolver: GameCopyResolver) -> String? {
        guard let effect else { return nil }
        var parts: [String] = []
        if effect.income != 0 {
            parts.append(resolver.resolve(
                .journeyEffectIncome,
                arguments: [.userText(GameFormatters.krw(Int(clamping: effect.income), language: resolver.language))]
            ))
        }
        if effect.fanDelta != 0 {
            parts.append(resolver.resolve(.journeyEffectFan, arguments: [.integer(effect.fanDelta)]))
        }
        if effect.communityDelta != 0 {
            parts.append(resolver.resolve(.journeyEffectCommunity, arguments: [.integer(effect.communityDelta)]))
        }
        return parts.isEmpty ? resolver.resolve(.journeyEffectNone) : parts.joined(separator: " · ")
    }

    static func combinedEffect(
        _ effect: ProDecisionEffect,
        journeyEffect: ProJourneyEffect?,
        resolver: GameCopyResolver
    ) -> String {
        var parts = [ProCareerPresentation.effect(effect, resolver: resolver)]
        if let journey = Self.journeyEffect(journeyEffect, resolver: resolver), !journey.isEmpty {
            parts.append(journey)
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// 시즌 결정 선택지의 효과를 칩 하나당 항목 하나로 나눈다(1.2.9 가독성 교정).
    /// 문장("구위 +1 · 피로 +12")에 섞여 있던 비용을 이득과 색으로 분리하기 위한 것이다.
    struct EffectChipModel: Identifiable, Equatable {
        let id: String
        let text: String
        let tone: EffectChip.Tone
    }

    static func effectChips(
        _ effect: ProDecisionEffect,
        journeyEffect: ProJourneyEffect?,
        resolver: GameCopyResolver
    ) -> [EffectChipModel] {
        var chips: [EffectChipModel] = []
        func ability(_ id: String, _ delta: Int, gain: ProUICopyKey, loss: ProUICopyKey) {
            guard delta != 0 else { return }
            chips.append(EffectChipModel(
                id: id,
                text: resolver.resolve(delta > 0 ? gain : loss, arguments: [.integer(abs(delta))]),
                tone: delta > 0 ? .gain : .cost
            ))
        }
        ability("stuff", effect.stuffDelta, gain: .effectStuffGain, loss: .effectStuffLoss)
        ability("command", effect.commandDelta, gain: .effectCommandGain, loss: .effectCommandLoss)
        ability("movement", effect.movementDelta, gain: .effectMovementGain, loss: .effectMovementLoss)
        ability("stamina", effect.staminaDelta, gain: .effectStaminaGain, loss: .effectStaminaLoss)
        ability("manager", effect.managerTrustDelta, gain: .effectManagerGain, loss: .effectManagerLoss)
        ability("catcher", effect.catcherTrustDelta, gain: .effectCatcherGain, loss: .effectCatcherLoss)
        if effect.fatigueDelta != 0 {
            // 피로는 부호가 반대다 — 오르면 비용, 내리면 이득.
            chips.append(EffectChipModel(
                id: "fatigue",
                text: resolver.resolve(
                    effect.fatigueDelta > 0 ? .effectFatigueGain : .effectFatigueLoss,
                    arguments: [.integer(abs(effect.fatigueDelta))]
                ),
                tone: effect.fatigueDelta > 0 ? .cost : .gain
            ))
        }
        if let role = effect.roleTarget {
            chips.append(EffectChipModel(
                id: "role",
                text: resolver.resolve(.effectRole, arguments: [.userText(resolver.resolve(role.displayCopyToken))]),
                tone: .neutral
            ))
        }
        if let journey = journeyEffect {
            if journey.income != 0 {
                chips.append(EffectChipModel(
                    id: "income",
                    text: resolver.resolve(
                        .journeyEffectIncome,
                        arguments: [.userText(GameFormatters.krw(Int(clamping: journey.income), language: resolver.language))]
                    ),
                    tone: journey.income > 0 ? .gain : .cost
                ))
            }
            if journey.fanDelta != 0 {
                chips.append(EffectChipModel(
                    id: "fan",
                    text: resolver.resolve(.journeyEffectFan, arguments: [.integer(journey.fanDelta)]),
                    tone: journey.fanDelta > 0 ? .gain : .cost
                ))
            }
            if journey.communityDelta != 0 {
                chips.append(EffectChipModel(
                    id: "community",
                    text: resolver.resolve(.journeyEffectCommunity, arguments: [.integer(journey.communityDelta)]),
                    tone: journey.communityDelta > 0 ? .gain : .cost
                ))
            }
        }
        if chips.isEmpty {
            chips.append(EffectChipModel(id: "none", text: resolver.resolve(.journeyEffectNone), tone: .neutral))
        }
        return chips
    }

    static func effect(_ effect: ProDecisionEffect, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return effect.summary }
        var parts: [String] = []
        append(effect.stuffDelta, gain: .effectStuffGain, loss: .effectStuffLoss, to: &parts, resolver: resolver)
        append(effect.commandDelta, gain: .effectCommandGain, loss: .effectCommandLoss, to: &parts, resolver: resolver)
        append(effect.movementDelta, gain: .effectMovementGain, loss: .effectMovementLoss, to: &parts, resolver: resolver)
        append(effect.staminaDelta, gain: .effectStaminaGain, loss: .effectStaminaLoss, to: &parts, resolver: resolver)
        append(effect.managerTrustDelta, gain: .effectManagerGain, loss: .effectManagerLoss, to: &parts, resolver: resolver)
        append(effect.catcherTrustDelta, gain: .effectCatcherGain, loss: .effectCatcherLoss, to: &parts, resolver: resolver)
        append(effect.fatigueDelta, gain: .effectFatigueGain, loss: .effectFatigueLoss, to: &parts, resolver: resolver)
        if let role = effect.roleTarget {
            parts.append(resolver.resolve(.effectRole, arguments: [.userText(resolver.resolve(role.displayCopyToken))]))
        }
        return parts.joined(separator: " · ")
    }

    static func buildLabel(_ identity: PitcherBuildIdentity, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return identity.label }
        return resolver.resolve(.gameContent("content.pitcher-build.\(identity.rawValue).label"))
    }

    static func buildStrength(_ identity: PitcherBuildIdentity, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return identity.strength }
        return resolver.resolve(.gameContent("content.pitcher-build.\(identity.rawValue).strength"))
    }

    static func buildTradeoff(_ identity: PitcherBuildIdentity, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return identity.tradeoff }
        return resolver.resolve(.gameContent("content.pitcher-build.\(identity.rawValue).tradeoff"))
    }

    static func rival(_ rival: ProRivalBatter, resolver: GameCopyResolver) -> RivalCopy {
        guard resolver.language != .korean else {
            return RivalCopy(
                name: rival.name,
                teamName: rival.teamName,
                archetype: rival.archetype,
                record: rival.record,
                profile: rival.profile
            )
        }
        let prefix = "content.pro-rival.\(rival.id)"
        let team = HighSchoolCareerStore.teams.first { $0.id == rival.teamID }
        return RivalCopy(
            name: resolver.resolve(.gameContent("\(prefix).name")),
            teamName: team.map { teamName($0, resolver: resolver) } ?? GameCopyResolver.unavailableText,
            archetype: resolver.resolve(.gameContent("\(prefix).archetype")),
            record: resolver.resolve(.gameContent("\(prefix).record")),
            profile: resolver.resolve(.gameContent("\(prefix).profile"))
        )
    }

    static func tension(
        _ tension: ProSeasonTension,
        state: ProCareerSnapshot,
        resolver: GameCopyResolver
    ) -> TensionCopy {
        guard resolver.language != .korean else {
            return TensionCopy(title: tension.title, detail: tension.detail)
        }
        switch tension.kind {
        case "role":
            let competitor = resolver.resolve(
                .gameContent("content.draft-team.\(state.team.id).position-competitor")
            )
            return TensionCopy(
                title: legacy("content.pro-tension.role.title", [.userText(competitor)], resolver: resolver),
                detail: legacy(
                    "content.pro-tension.role.detail",
                    [.userText(resolver.resolve(state.role.displayCopyToken))],
                    resolver: resolver
                )
            )
        case "record":
            let skill = (state.pitcher.stuff + state.pitcher.command + state.pitcher.movement + state.pitcher.stamina) / 4
            switch CareerDisplayRules.pitcherIdentity(for: state.pitcher) {
            case .power:
                let goal = state.level == .major ? max(120, skill * 2) : max(80, skill * 3 / 2)
                return TensionCopy(
                    title: legacy("content.pro-tension.record.power.title", [.integer(goal)], resolver: resolver),
                    detail: legacy("content.pro-tension.record.power.detail", resolver: resolver)
                )
            case .command:
                let goal = state.level == .major ? "2.5" : "3.0"
                return TensionCopy(
                    title: legacy("content.pro-tension.record.command.title", [.userText(goal)], resolver: resolver),
                    detail: legacy("content.pro-tension.record.command.detail", resolver: resolver)
                )
            case .movement:
                let goal = state.level == .major ? "8.5" : "9.0"
                return TensionCopy(
                    title: legacy("content.pro-tension.record.movement.title", [.userText(goal)], resolver: resolver),
                    detail: legacy("content.pro-tension.record.movement.detail", resolver: resolver)
                )
            case .stamina:
                let innings = state.role == .starter ? max(120, skill * 2) : max(70, skill)
                return TensionCopy(
                    title: legacy("content.pro-tension.record.stamina.title", [.integer(innings)], resolver: resolver),
                    detail: legacy("content.pro-tension.record.stamina.detail", resolver: resolver)
                )
            }
        case "rival":
            guard let rawRival = rivalForLegacyTitle(tension.title) else {
                return TensionCopy(title: GameCopyResolver.unavailableText, detail: GameCopyResolver.unavailableText)
            }
            let copy = rival(rawRival, resolver: resolver)
            return TensionCopy(
                title: legacy("content.pro-tension.rival.title", [.userText(copy.name)], resolver: resolver),
                detail: legacy(
                    "content.pro-tension.rival.detail",
                    [.userText(copy.teamName), .userText(copy.archetype)],
                    resolver: resolver
                )
            )
        default:
            return TensionCopy(title: GameCopyResolver.unavailableText, detail: GameCopyResolver.unavailableText)
        }
    }

    static func leagueTeamName(_ rawName: String, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return rawName }
        guard let team = HighSchoolCareerStore.teams.first(where: { $0.name == rawName }) else {
            return GameCopyResolver.unavailableText
        }
        return teamName(team, resolver: resolver)
    }

    static func leaguePitcherName(
        _ rawName: String,
        isPlayer: Bool,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language != .korean, !isPlayer else { return rawName }
        let surnameIDs: [(String, String)] = [
            ("김", "gim"), ("이", "i"), ("박", "bak"), ("최", "choe"),
            ("정", "jeong"), ("강", "gang"), ("조", "jo"), ("윤", "yun"),
            ("장", "jang"), ("임", "im"), ("한", "han"), ("오", "o"),
            ("서", "seo"), ("신", "sin"), ("권", "gwon"), ("황", "hwang"),
        ]
        guard let surname = surnameIDs.first(where: { rawName.hasPrefix($0.0) }) else {
            return GameCopyResolver.unavailableText
        }
        let givenRaw = String(rawName.dropFirst(surname.0.count))
        let givenIDs: [String: String] = [
            "도현": "dohyeon", "지훈": "jihun", "성민": "seongmin", "우진": "ujin",
            "재원": "jaewon", "하준": "hajun", "시우": "siu", "건우": "geonu",
            "예준": "yejun", "선우": "seonu", "태윤": "taeyun", "민석": "minseok",
            "현우": "hyeonu", "정후": "jeonghu", "승현": "seunghyeon", "주환": "juhwan",
        ]
        guard let givenID = givenIDs[givenRaw] else { return GameCopyResolver.unavailableText }
        let surnameValue = resolver.resolve(.gameContent("content.league-name.surname.\(surname.1)"))
        let givenValue = resolver.resolve(.gameContent("content.league-name.given.\(givenID)"))
        return "\(surnameValue) \(givenValue)"
    }

    static func gameRole(_ line: ProGameLine, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            RecordUICopyKey.role,
            arguments: [
                .userText(resolver.resolve(
                    line.started ? AppCopyKey.proRoleStarter : AppCopyKey.proRoleReliever
                )),
                .userText(GameFormatters.innings(outs: line.outs, language: resolver.language)),
            ]
        )
    }

    static func gameSummary(_ line: ProGameLine, resolver: GameCopyResolver) -> String {
        let key = line.hits == nil ? AppCopyKey.proOutingSummary : AppCopyKey.proOutingSummaryHits
        let role = resolver.resolve(line.started ? AppCopyKey.proRoleStarter : AppCopyKey.proRoleReliever)
        var arguments: [LocalizedCopyArgument] = [
            .userText(role),
            .userText(GameFormatters.innings(outs: line.outs, language: resolver.language)),
        ]
        if let hits = line.hits { arguments.append(.integer(hits)) }
        arguments.append(contentsOf: [
            .integer(line.strikeouts),
            .integer(line.walks),
            .integer(line.runsAllowed),
        ])
        return resolver.resolve(key, arguments: arguments)
    }

    /// 직접 던진 포스트시즌 경기의 한 줄 박스스코어. 이 표기가 생기기 전에는 플레이오프
    /// 등판이 승패 집계 말고는 어디에도 남지 않았다. K·피안타가 없는 구저장본 라인은
    /// nil을 돌려 요약 줄만 남긴다.
    static func postseasonDirectLine(
        _ game: ProPostseasonGameLine,
        resolver: GameCopyResolver
    ) -> String? {
        guard game.directlyPlayed, let outs = game.playerOuts, let strikeouts = game.playerStrikeouts else {
            return nil
        }
        let roundKey: ProUICopyKey = switch game.round {
        case .wildCard: .postseasonRoundWildCard
        case .semifinal: .postseasonRoundSemifinal
        case .playoff: .postseasonRoundPlayoff
        case .final: .postseasonRoundFinal
        case nil: .postseasonRoundUnknown
        }
        let started = game.playerStarted ?? true
        let resultKey: GameCopyKey = game.won ? AppCopyKey.proDecisionWin : AppCopyKey.proDecisionLoss
        return resolver.resolve(
            RecordUICopyKey.careerPostseasonDirectLine,
            arguments: [
                .userText(resolver.resolve(roundKey)),
                .integer(game.gameNumber),
                .userText(resolver.resolve(started ? AppCopyKey.proRoleStarter : AppCopyKey.proRoleReliever)),
                .userText(GameFormatters.innings(outs: outs, language: resolver.language)),
                .integer(strikeouts),
                .integer(game.playerRunsAllowed ?? 0),
                .userText("\(game.teamRuns):\(game.opponentRuns)"),
                .userText(resolver.resolve(resultKey)),
            ]
        )
    }

    static func gameDecision(_ decision: PitchingDecision, resolver: GameCopyResolver) -> String? {
        let key: GameCopyKey?
        switch decision {
        case .win: key = AppCopyKey.proDecisionWin
        case .loss: key = AppCopyKey.proDecisionLoss
        case .save: key = AppCopyKey.proDecisionSave
        case .noDecision: key = nil
        }
        return key.map { resolver.resolve($0) }
    }

    static func gameAccessibility(_ line: ProGameLine, resolver: GameCopyResolver) -> String {
        let decision = gameDecision(line.decision, resolver: resolver)
        var arguments: [LocalizedCopyArgument] = [
            .integer(line.week),
            .userText(resolver.resolve(line.started ? AppCopyKey.proRoleStarter : AppCopyKey.proRoleReliever)),
            .userText(GameFormatters.innings(outs: line.outs, language: resolver.language)),
            .userText(gameSummary(line, resolver: resolver)),
            .integer(line.teamRuns),
            .integer(line.opponentRuns),
        ]
        if let decision { arguments.append(.userText(decision)) }
        let key: GameCopyKey = switch (decision, line.played) {
        case (nil, false): AppCopyKey.proOutingAccessibility
        case (nil, true): AppCopyKey.proOutingAccessibilityPlayed
        case (.some, false): AppCopyKey.proOutingAccessibilityDecision
        case (.some, true): AppCopyKey.proOutingAccessibilityDecisionPlayed
        }
        return resolver.resolve(key, arguments: arguments)
    }

    private static func append(
        _ value: Int,
        gain: ProUICopyKey,
        loss: ProUICopyKey,
        to parts: inout [String],
        resolver: GameCopyResolver
    ) {
        guard value != 0 else { return }
        parts.append(resolver.resolve(value > 0 ? gain : loss, arguments: [.integer(abs(value))]))
    }

    private static func legacy(
        _ key: String,
        _ arguments: [LocalizedCopyArgument] = [],
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(.gameContent(key), arguments: arguments)
    }

    private static func role(forLegacyName value: String) -> ProRole? {
        switch value {
        case "선발": .starter
        case "긴 이닝 구원": .longRelief
        case "필승조": .setup
        case "마무리": .closer
        default: nil
        }
    }

    private static func rivalForLegacyTitle(_ title: String) -> ProRivalBatter? {
        let identities: [(name: String, id: String, teamID: String)] = [
            ("강도훈", "pro-rival-seoul", "seoul_comets"),
            ("마태오", "pro-rival-busan", "busan_marines"),
            ("백건우", "pro-rival-incheon", "incheon_waves"),
            ("노진성", "pro-rival-daegu", "daegu_forge"),
            ("천우재", "pro-rival-daejeon", "daejeon_rockets"),
            ("서강윤", "pro-rival-gwangju", "gwangju_phoenix"),
            ("구본혁", "pro-rival-suwon", "suwon_guardians"),
            ("류성권", "pro-rival-changwon", "changwon_meteors"),
            ("문태경", "pro-rival-jeonju", "jeonju_hanok"),
            ("한도결", "pro-rival-jeju", "jeju_storm"),
        ]
        guard let value = identities.first(where: { title.hasPrefix($0.name) }) else { return nil }
        return ProRivalBatter(
            id: value.id,
            name: value.name,
            archetype: "",
            teamID: value.teamID,
            teamName: "",
            record: "",
            profile: ""
        )
    }

    private static func captures(_ value: String, pattern: String) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = expression.firstMatch(in: value, range: range), match.range == range else { return nil }
        return (1..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: value) else { return nil }
            return String(value[range])
        }
    }
}

struct GoalPermilleBar: View {
    let permille: Int
    let completed: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(BaseballTheme.surfaceRaised)
                Capsule()
                    .fill(completed ? BaseballTheme.milestone : BaseballTheme.action)
                    .frame(
                        width: max(4, proxy.size.width * CGFloat(min(1000, max(0, permille))) / 1000)
                    )
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

struct ProCareerGoalMetricsView: View {
    let progress: ProCareerGoalProgress
    var identifierPrefix = "pro.goal"
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(progress.metrics.enumerated()), id: \.offset) { index, metric in
                let filled = progress.completed || metric.current >= metric.target
                VStack(alignment: .leading, spacing: 4) {
                    Text(copyResolver.resolve(
                        .directionGoalMetric,
                        arguments: [
                            .userText(ProCareerPresentation.goalMetricTitle(metric.kind, resolver: copyResolver)),
                            .integer(metric.current),
                            .integer(metric.target),
                        ]
                    ))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(filled ? BaseballTheme.milestone : BaseballTheme.textSecondary)
                    GoalPermilleBar(
                        permille: CareerDisplayRules.goalPermille(
                            current: metric.current,
                            target: metric.target,
                            completed: progress.completed
                        ),
                        completed: filled
                    )
                }
                .accessibilityIdentifier("\(identifierPrefix).metric.\(index)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(identifierPrefix).metrics")
    }
}
