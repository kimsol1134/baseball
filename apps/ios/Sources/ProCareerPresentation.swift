import Foundation
import SimulationCore

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

    static func teamName(_ team: DraftTeamSnapshot, resolver: GameCopyResolver) -> String {
        HighSchoolConclusionPresentation.localizedTeamName(team, resolver: resolver)
    }

    static func decisionDetail(_ decision: ProSeasonDecision, resolver: GameCopyResolver) -> String {
        guard resolver.language == .english else { return decision.detail }
        return resolver.resolve(.gameContent("content.pro-decision.\(decision.type.rawValue).detail"))
    }

    static func storeSummary(
        _ raw: String,
        state: ProCareerSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language == .english else { return raw }
        let team = teamName(state.team, resolver: resolver)
        switch raw {
        case "현재 저장본을 읽지 못해 직전 정상 백업으로 복구했습니다.":
            return legacy("content.pro-summary.backup-recovered", resolver: resolver)
        case let value where value.hasSuffix("입단. 2군에서 첫 시즌을 시작합니다."):
            return legacy("content.pro-summary.joined-direct", [.userText(team)], resolver: resolver)
        case let value where value.hasSuffix("입단. 고교 3년의 능력을 그대로 안고 시작합니다."):
            return legacy("content.pro-summary.joined-high-school", [.userText(team)], resolver: resolver)
        case "등판을 중단했습니다. 다음 마운드는 새 이닝입니다.":
            return legacy("content.pro-summary.outing-abandoned", resolver: resolver)
        case "시즌 기록을 통산 기록에 확정했습니다.":
            return legacy("content.pro-summary.season-recorded", resolver: resolver)
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
        guard resolver.language == .english else { return raw }
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
        guard resolver.language == .english else { return raw }
        let patterns: [(String, String)] = [
            (#"^시즌 (\d+) 탈삼진상$"#, "content.pro-award.strikeouts"),
            (#"^시즌 (\d+) 최소 실점상$"#, "content.pro-award.run-prevention"),
            (#"^시즌 (\d+) 정밀 제구상$"#, "content.pro-award.command"),
            (#"^시즌 (\d+) 피안타 억제상$"#, "content.pro-award.hit-prevention"),
            (#"^시즌 (\d+) 이닝 책임상$"#, "content.pro-award.innings"),
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
        guard resolver.language == .english else { return raw }
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
        default:
            break
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

    static func choiceTitle(_ choice: ProSeasonDecisionChoice, resolver: GameCopyResolver) -> String {
        guard resolver.language == .english else { return choice.title }
        return resolver.resolve(.gameContent("content.pro-decision.choice.\(choice.id).title"))
    }

    static func choiceDetail(_ choice: ProSeasonDecisionChoice, resolver: GameCopyResolver) -> String {
        guard resolver.language == .english else { return choice.detail }
        return resolver.resolve(.gameContent("content.pro-decision.choice.\(choice.id).detail"))
    }

    static func decisionRecordTitle(_ record: ProDecisionRecord, resolver: GameCopyResolver) -> String {
        guard resolver.language == .english else { return record.choiceTitle }
        return resolver.resolve(.gameContent("content.pro-decision.choice.\(record.choiceID).title"))
    }

    static func effect(_ effect: ProDecisionEffect, resolver: GameCopyResolver) -> String {
        guard resolver.language == .english else { return effect.summary }
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
        guard resolver.language == .english else { return identity.label }
        return resolver.resolve(.gameContent("content.pitcher-build.\(identity.rawValue).label"))
    }

    static func buildStrength(_ identity: PitcherBuildIdentity, resolver: GameCopyResolver) -> String {
        guard resolver.language == .english else { return identity.strength }
        return resolver.resolve(.gameContent("content.pitcher-build.\(identity.rawValue).strength"))
    }

    static func buildTradeoff(_ identity: PitcherBuildIdentity, resolver: GameCopyResolver) -> String {
        guard resolver.language == .english else { return identity.tradeoff }
        return resolver.resolve(.gameContent("content.pitcher-build.\(identity.rawValue).tradeoff"))
    }

    static func rival(_ rival: ProRivalBatter, resolver: GameCopyResolver) -> RivalCopy {
        guard resolver.language == .english else {
            return RivalCopy(
                name: rival.name,
                teamName: rival.teamName,
                archetype: rival.archetype,
                record: rival.record,
                profile: rival.profile
            )
        }
        let prefix = "content.pro-rival.\(rival.id)"
        let team = HighSchoolCareerEngine.teams.first { $0.id == rival.teamID }
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
        guard resolver.language == .english else {
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
            switch PitcherBuildRules.identity(for: state.pitcher) {
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
        guard resolver.language == .english else { return rawName }
        guard let team = HighSchoolCareerEngine.teams.first(where: { $0.name == rawName }) else {
            return GameCopyResolver.unavailableText
        }
        return teamName(team, resolver: resolver)
    }

    static func leaguePitcherName(
        _ rawName: String,
        isPlayer: Bool,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language == .english, !isPlayer else { return rawName }
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
