import Foundation
import SimulationCore

enum LegacyPresentation {
    static func pledgeTitle(_ pledge: RunPledge, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return pledge.title }
        return resolver.resolve(.gameContent("content.pledge.\(pledgeContentID(pledge)).title"))
    }

    static func pledgeDetail(_ pledge: RunPledge, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return pledge.detail }
        return resolver.resolve(.gameContent("content.pledge.\(pledgeContentID(pledge)).detail"))
    }

    static func archivedPledgeTitle(
        id: String,
        rawTitle: String?,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language != .korean else {
            return rawTitle ?? RunPledge.pledge(id: id, rulesVersion: RunPledge.legacyRulesVersion)?.title
                ?? resolver.resolve(.pledgeCardTitle)
        }
        let legacy = RunPledge.legacyV1.first { $0.id == id && $0.title == rawTitle }
        let contentID = (legacy == nil ? "" : "legacy-") + id.replacingOccurrences(of: "_", with: "-")
        return resolver.resolve(.gameContent("content.pledge.\(contentID).title"))
    }

    static func pledgeTier(_ tier: RunPledgeTier, resolver: GameCopyResolver) -> String {
        let key: LegacyUICopyKey = switch tier {
        case .safe: LegacyUICopyKey.pledgeTierSafe
        case .bold: LegacyUICopyKey.pledgeTierBold
        case .legendary: LegacyUICopyKey.pledgeTierLegendary
        }
        return resolver.resolve(key)
    }

    static func pledgeProgress(_ progress: RunPledgeProgress, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return progress.line }
        return resolver.resolve(
            .pledgeProgress,
            arguments: [.integer(progress.current), .integer(progress.target)]
        )
    }

    static func archivedPledgeProgress(
        current: Int,
        target: Int,
        rawLine: String?,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language != .korean else {
            return rawLine ?? resolver.resolve(.pledgeProgress, arguments: [.integer(current), .integer(target)])
        }
        return resolver.resolve(.pledgeProgress, arguments: [.integer(current), .integer(target)])
    }

    static func pledgeAlignment(
        _ pledge: RunPledge,
        state: HighSchoolCareerSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        let raw = pledge.alignmentReason(state: state)
        guard resolver.language != .korean else { return raw }
        let key: LegacyUICopyKey = switch raw {
        case "제구가 가장 높은 능력이라 볼넷 억제에 잘 맞습니다.": .pledgeAlignmentControl
        case "제구 강점을 전체 평가로 이어 가는 목표입니다.": .pledgeAlignmentEvaluation
        case "구위와 변화구 강점을 경기 결과로 바꾸는 목표입니다.": .pledgeAlignmentPower
        case "지금 가장 두터운 관계를 승부의 힘으로 잇는 목표입니다.": .pledgeAlignmentRelationship
        case "현재 팔 부담을 관리하며 완주하는 데 맞춘 목표입니다.": .pledgeAlignmentHealth
        case "이미 모인 팬 관심을 더 큰 이야기로 잇는 목표입니다.": .pledgeAlignmentFans
        case "현재 능력 구성과 무관하게 완주를 노리는 안전 목표입니다.": .pledgeAlignmentSafe
        case "현재 강점과 다른 방향까지 넓혀 보는 도전 목표입니다.": .pledgeAlignmentBold
        case "현재 강점을 넘어 한계를 시험하는 전설 목표입니다.": .pledgeAlignmentLegendary
        default: .pledgeAlignmentCurrent
        }
        return resolver.resolve(key)
    }

    static func pledgeAccessibility(
        pledge: RunPledge,
        progress: RunPledgeProgress,
        carried: Bool,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            carried ? .pledgeAccessibilityCarried : .pledgeAccessibility,
            arguments: [
                .userText(pledgeTier(pledge.tier, resolver: resolver)),
                .userText(pledgeTitle(pledge, resolver: resolver)),
                .userText(pledgeProgress(progress, resolver: resolver)),
                .integer(pledge.rewardPermille / 10),
            ]
        )
    }

    static func heartline(
        _ presentation: PlayerHeartlinePresentation,
        drafted: Bool,
        resolver: GameCopyResolver
    ) -> PlayerHeartline {
        guard resolver.language != .korean else { return presentation.line }
        let branch = switch presentation.branch {
        case .completed: drafted ? "completed-drafted" : "completed-undrafted"
        case .legacy: drafted ? "legacy-drafted" : "legacy-undrafted"
        default: presentation.branch.rawValue.replacingOccurrences(of: "_", with: "-")
        }
        return PlayerHeartline(
            mood: resolver.resolve(.gameContent("content.player-heart.\(branch).mood")),
            words: resolver.resolve(.gameContent("content.player-heart.\(branch).words"))
        )
    }

    static func playerLegacy(
        for record: HighSchoolCareerStore.LifeRecord,
        resolver: GameCopyResolver
    ) -> PlayerLegacy {
        guard resolver.language != .korean else {
            return record.playerLegacy ?? PlayerBondStory.legacy(for: record)
        }

        let titleBranch: String
        if record.signatureLegacy != nil { titleBranch = "signature" }
        else if record.drafted { titleBranch = "drafted" }
        else if record.pledgeAchieved == true { titleBranch = "pledge" }
        else if record.runsAllowed == 0, record.games > 0 { titleBranch = "scoreless" }
        else if record.strikeouts >= 30 { titleBranch = "strikeouts" }
        else { titleBranch = "together" }

        let openingBranch = record.drafted
            ? "drafted"
            : record.signatureLegacy == nil ? "undrafted" : "undrafted-signature"
        var openingArguments: [LocalizedCopyArgument] = []
        if let signature = record.signatureLegacy, openingBranch == "undrafted-signature" {
            openingArguments = [
                .userText(HighSchoolConclusionPresentation.localizedSignature(signature, resolver: resolver).evidence),
            ]
        }
        let opening = resolver.resolve(
            .gameContent("content.player-legacy.opening.\(openingBranch)"),
            arguments: openingArguments
        )

        let closingBranch: String
        var closingArguments: [LocalizedCopyArgument] = []
        if let signature = record.signatureLegacy {
            closingBranch = record.drafted ? "drafted-signature" : "undrafted-signature"
            closingArguments = [
                .userText(HighSchoolConclusionPresentation.localizedSignature(signature, resolver: resolver).title),
            ]
        } else {
            let memoryPrefix = record.memories.isEmpty ? "plain" : "memory"
            closingBranch = "\(memoryPrefix)-\(personalityBranch(record.personality))"
        }

        let closing = resolver.resolve(
            .gameContent("content.player-legacy.closing.\(closingBranch)"),
            arguments: closingArguments
        )
        return PlayerLegacy(
            title: resolver.resolve(.gameContent("content.player-legacy.title.\(titleBranch)")),
            definingMoment: definingMoment(for: record, resolver: resolver),
            farewell: "\(opening) \(closing)"
        )
    }

    static func archiveOutcome(
        _ record: HighSchoolCareerStore.LifeRecord,
        resolver: GameCopyResolver
    ) -> String {
        if record.drafted {
            let team = HighSchoolConclusionPresentation.localizedLifeTeamName(record.teamName, resolver: resolver)
                ?? resolver.resolve(.archiveTeamUnknown)
            return resolver.resolve(.archiveOutcomeDrafted, arguments: [.userText(team)])
        }
        return resolver.resolve(.archiveOutcomeUndrafted, arguments: [.integer(record.evaluationScore)])
    }

    static func rivalLine(_ raw: String, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return raw }
        let pattern = #"^숙적 (.+) — (\d+)타석 (\d+)삼진 (\d+)피안타$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return GameCopyResolver.unavailableText
        }
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        guard let match = regex.firstMatch(in: raw, range: range), match.numberOfRanges == 5 else {
            return GameCopyResolver.unavailableText
        }
        func capture(_ index: Int) -> String? {
            Range(match.range(at: index), in: raw).map { String(raw[$0]) }
        }
        guard let rawName = capture(1), let plateAppearances = capture(2).flatMap(Int.init),
              let strikeouts = capture(3).flatMap(Int.init), let hits = capture(4).flatMap(Int.init) else {
            return GameCopyResolver.unavailableText
        }
        let name = HighSchoolConclusionPresentation.localizedLifeRivalName(rawName, resolver: resolver)
            ?? GameCopyResolver.unavailableText
        return resolver.resolve(
            .recapRival,
            arguments: [
                .userText(name), .integer(plateAppearances), .integer(strikeouts), .integer(hits),
            ]
        )
    }

    static func schoolStrength(_ raw: String, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return raw }
        let focuses: [TrainingFocus] = [.velocity, .command, .breakingBall, .stamina, .recovery, .gamePlanning]
        guard let focus = focuses.first(where: { HighSchoolPresentation.focus($0) == raw }) else {
            return GameCopyResolver.unavailableText
        }
        return resolver.resolve(focus.displayCopyToken)
    }

    static func bloomMeaning(_ grade: TalentGrade, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return TalentRules.meaning(grade) }
        let key: LegacyUICopyKey = switch grade {
        case .d: LegacyUICopyKey.bloomMeaningD
        case .c: LegacyUICopyKey.bloomMeaningC
        case .b: LegacyUICopyKey.bloomMeaningB
        case .a: LegacyUICopyKey.bloomMeaningA
        case .s: LegacyUICopyKey.bloomMeaningS
        }
        return resolver.resolve(key)
    }

    private static func pledgeContentID(_ pledge: RunPledge) -> String {
        let isLegacy = RunPledge.legacyV1.contains { $0.id == pledge.id && $0.title == pledge.title }
            && !RunPledge.all.contains { $0.id == pledge.id && $0.title == pledge.title }
        return (isLegacy ? "legacy-" : "") + pledge.id.replacingOccurrences(of: "_", with: "-")
    }

    private static func personalityBranch(_ raw: String?) -> String {
        switch raw {
        case "불같은 승부사": "fiery"
        case "조용한 버팀목": "steady"
        case "차가운 분석가": "analyst"
        case "유연한 중심": "adaptable"
        default: "default"
        }
    }

    private static func definingMoment(
        for record: HighSchoolCareerStore.LifeRecord,
        resolver: GameCopyResolver
    ) -> String {
        if let signature = record.signatureLegacy {
            return HighSchoolConclusionPresentation.localizedSignature(signature, resolver: resolver).evidence
        }
        if let chronicle = record.chronicle {
            for line in chronicle.reversed() {
                let localized = HighSchoolConclusionPresentation.localizedChronicleLine(line, resolver: resolver)
                if localized != GameCopyResolver.unavailableText { return localized }
            }
        }
        if record.drafted {
            let team = HighSchoolConclusionPresentation.localizedLifeTeamName(record.teamName, resolver: resolver)
                ?? resolver.resolve(.archiveTeamUnknown)
            return resolver.resolve(
                .gameContent("content.player-legacy.moment.drafted"),
                arguments: [.userText(team), .userText(record.playerName)]
            )
        }
        let school = HighSchoolConclusionPresentation.localizedSchoolName(record.schoolName, resolver: resolver)
        return resolver.resolve(
            .gameContent("content.player-legacy.moment.undrafted"),
            arguments: [.userText(school)]
        )
    }
}
