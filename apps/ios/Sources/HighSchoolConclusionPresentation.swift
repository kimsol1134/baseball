import Foundation
import SimulationCore

/// Display-only projection for the high-school conclusion surfaces.
///
/// The conclusion payloads intentionally remain the old Codable values. This type recognizes
/// those values at the edge of the app and resolves only known semantic content into the active
/// language. An unrecognized system-owned value is never interpolated into English UI.
enum HighSchoolConclusionPresentation {
    struct MemoryCopy {
        let title: String
        let detail: String
    }

    struct SignatureCopy {
        let title: String
        let detail: String
        let evidence: String
    }

    struct RateLine {
        let innings: String
        let ra9: String
        let whip: String
        let strikeoutsPerNine: String
    }

    // MARK: - Draft result

    static func localizedDraftProjectedRange(
        _ rawValue: String,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language == .english else { return rawValue }
        switch rawValue {
        case "1라운드": return resolver.resolve(AppCopyKey.conclusionProjectedFirstRound)
        case "2~3라운드": return resolver.resolve(AppCopyKey.conclusionProjectedMiddleRounds)
        case "4~6라운드": return resolver.resolve(AppCopyKey.conclusionProjectedLateRounds)
        case "미지명": return resolver.resolve(AppCopyKey.conclusionProjectedUndrafted)
        default: return GameCopyResolver.unavailableText
        }
    }

    static func localizedDraftSummary(
        _ draft: DraftResultSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language == .english else { return draft.summary }
        switch draft.outcome {
        case .undrafted:
            guard draft.summary == "마지막 라운드까지 이름이 불리지 않았습니다. 다음 선수에게 남길 기록을 고르세요." else {
                return GameCopyResolver.unavailableText
            }
            return resolver.resolve(AppCopyKey.conclusionDraftSummaryUndrafted)
        case .drafted:
            guard let team = draft.team,
                  let descriptor = DraftTeamPresentationCatalog.descriptor(for: team.id),
                  draft.summary == "지명 구단 · \(team.name). 구위와 고교 경기 기록에서 높은 평가를 받았습니다." else {
                return GameCopyResolver.unavailableText
            }
            return resolver.resolve(
                AppCopyKey.conclusionDraftSummaryDrafted,
                arguments: [.userText(resolver.resolve(descriptor.token))]
            )
        }
    }

    static func localizedFirstSeasonGoal(
        _ rawValue: String?,
        resolver: GameCopyResolver
    ) -> String? {
        guard let rawValue else { return nil }
        guard resolver.language == .english else { return rawValue }
        guard rawValue == "퓨처스 선발 10경기와 볼넷률 8% 이하" else {
            return GameCopyResolver.unavailableText
        }
        return resolver.resolve(AppCopyKey.conclusionFirstSeasonGoal)
    }

    static func localizedEvaluationBreakdown(
        _ rawValues: [String]?,
        resolver: GameCopyResolver
    ) -> [String]? {
        guard let rawValues else { return nil }
        guard resolver.language == .english else { return rawValues }
        return rawValues.map { localizedBreakdownItem($0, resolver: resolver) }
    }

    static func evaluationAccessibility(
        _ rawValues: [String],
        resolver: GameCopyResolver
    ) -> String {
        let items = localizedEvaluationBreakdown(rawValues, resolver: resolver) ?? []
        return resolver.resolve(
            AppCopyKey.conclusionEvaluationBreakdownAccessibility,
            arguments: [.userText(items.joined(separator: ", "))]
        )
    }

    private static func localizedBreakdownItem(
        _ rawValue: String,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language == .english else { return rawValue }
        let definitions: [(String, GameCopyKey, Bool)] = [
            ("능력 ", AppCopyKey.conclusionBreakdownAbility, false),
            ("고교 공식 경기 ", AppCopyKey.conclusionBreakdownHighSchool, true),
            ("시즌 기록 ", AppCopyKey.conclusionBreakdownSeason, true),
            ("각성 +", AppCopyKey.conclusionBreakdownAwakening, false),
            ("관계 ", AppCopyKey.conclusionBreakdownRelationship, true),
            ("핸디캡 -", AppCopyKey.conclusionBreakdownHandicap, false),
            ("팔 상태 -", AppCopyKey.conclusionBreakdownArm, false),
        ]
        for (prefix, key, signed) in definitions where rawValue.hasPrefix(prefix) {
            let suffix = String(rawValue.dropFirst(prefix.count))
            guard let value = Int(suffix), signed || value >= 0 else { continue }
            return resolver.resolve(key, arguments: [.integer(value)])
        }
        return GameCopyResolver.unavailableText
    }

    // MARK: - Draft team, personality, memories, and signature legacy

    static func localizedTeamName(
        _ team: DraftTeamSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        localizedTeamField(team, field: .name, resolver: resolver)
    }

    static func localizedTeamField(
        _ team: DraftTeamSnapshot,
        field: DraftTeamConclusionFieldID,
        resolver: GameCopyResolver
    ) -> String {
        guard let rawValue = rawTeamField(team, field: field) else {
            return resolver.language == .korean ? "" : GameCopyResolver.unavailableText
        }
        guard resolver.language == .english else { return rawValue }
        guard let descriptor = DraftConclusionPresentationCatalog.teamFieldDescriptor(
            teamID: team.id, field: field
        ), descriptor.rawValue == rawValue else {
            return GameCopyResolver.unavailableText
        }
        return resolver.resolve(descriptor.token)
    }

    static func localizedPersonalityTitle(
        _ personality: Personality,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language == .english else { return personality.title }
        guard let descriptor = DraftConclusionPresentationCatalog.personalityDescriptor(for: personality.trait) else {
            return GameCopyResolver.unavailableText
        }
        return resolver.resolve(descriptor.titleToken)
    }

    static func localizedPersonalityScoutLine(
        _ personality: Personality,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language == .english else { return personality.scoutLine }
        guard let descriptor = DraftConclusionPresentationCatalog.personalityDescriptor(for: personality.trait) else {
            return GameCopyResolver.unavailableText
        }
        return resolver.resolve(descriptor.scoutLineToken)
    }

    static func localizedMemory(
        _ id: MemoryCardID,
        resolver: GameCopyResolver
    ) -> MemoryCopy {
        let raw = HighSchoolPresentation.memory(id)
        guard resolver.language == .english else {
            return MemoryCopy(title: raw.title, detail: raw.detail)
        }
        let descriptor = DraftConclusionPresentationCatalog.memoryDescriptors.first { $0.id == id }
        return MemoryCopy(
            title: descriptor.map { resolver.resolve($0.titleToken) } ?? GameCopyResolver.unavailableText,
            detail: descriptor.map { resolver.resolve($0.detailToken) } ?? GameCopyResolver.unavailableText
        )
    }

    static func localizedSignature(
        _ legacy: CareerSignatureLegacy,
        resolver: GameCopyResolver
    ) -> SignatureCopy {
        guard resolver.language == .english else {
            return SignatureCopy(
                title: legacy.title,
                detail: legacy.detail,
                evidence: legacy.evidence.summary
            )
        }
        let descriptor = DraftConclusionPresentationCatalog.signatureLegacyDescriptors.first { $0.id == legacy.id }
        return SignatureCopy(
            title: descriptor.map { resolver.resolve($0.titleToken) } ?? GameCopyResolver.unavailableText,
            detail: descriptor.map { resolver.resolve($0.detailToken) } ?? GameCopyResolver.unavailableText,
            evidence: localizedSignatureEvidence(legacy, resolver: resolver)
        )
    }

    private static func localizedSignatureEvidence(
        _ legacy: CareerSignatureLegacy,
        resolver: GameCopyResolver
    ) -> String {
        let evidence = legacy.evidence
        var facts: [String] = []
        if let growth = evidence.ratingGrowth {
            facts.append("rating growth +\(growth)")
        }
        if let performance = evidence.performance {
            facts.append("\(performance.importantGamesCompleted) high-school games")
            facts.append("\(performance.strikeouts) strikeouts")
            facts.append("\(performance.walks) walks")
            facts.append("\(performance.runsAllowed) runs allowed")
        }
        if !evidence.matchedAwakenings.isEmpty {
            facts.append("\(evidence.matchedAwakenings.count) matching awakenings")
        }
        if let target = evidence.relationshipTarget, let trust = evidence.relationshipTrust {
            facts.append("\(resolver.resolve(target.displayCopyToken)) trust \(trust)")
        }
        if let pro = evidence.proPerformance {
            facts.append("\(pro.seasons) pro seasons")
            facts.append("\(pro.games) games")
            facts.append("\(pro.strikeouts) strikeouts")
            facts.append("\(pro.walks) walks")
        }
        guard !facts.isEmpty else {
            return resolver.resolve(AppCopyKey.conclusionSignatureEvidenceDynamic)
        }
        return resolver.resolve(
            AppCopyKey.conclusionSignatureEvidenceDynamic,
            arguments: [.userText(facts.joined(separator: " · "))]
        )
    }

    @MainActor
    static func localizedSignatureEffect(
        _ effect: CareerSignatureLegacyEffect,
        resolver: GameCopyResolver
    ) -> String {
        // The existing setup formatter owns this wording and its exact Korean particle behavior.
        if resolver.language == .korean {
            return HighSchoolSetupView.signatureLegacyEffectLine(effect)
        }
        let fields = [
            ("Stuff", effect.stuff), ("Control", effect.command),
            ("Breaking", effect.movement), ("Stamina", effect.stamina),
        ].filter { $0.1 != 0 }.map { "\($0.0) +\($0.1)" }
        return fields.isEmpty ? GameCopyResolver.unavailableText : fields.joined(separator: " · ")
    }

    static func localizedWind(
        _ wind: CareerWind,
        resolver: GameCopyResolver
    ) -> (title: String, detail: String) {
        guard resolver.language == .english else { return (wind.title, wind.detail) }
        let descriptor = CareerWindPresentationCatalog.descriptor(for: wind)
        return (resolver.resolve(descriptor.titleToken), resolver.resolve(descriptor.detailToken))
    }

    // MARK: - Chronicle

    static func localizedChronicleStage(
        _ rawStage: String,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language == .english else { return rawStage }
        let parts = rawStage.split(separator: " ", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let year = Int(parts[0].replacingOccurrences(of: "학년", with: "")),
              (1...3).contains(year),
              let season = ChapterSeasonID(rawSeason: parts[1]) else {
            return GameCopyResolver.unavailableText
        }
        return resolver.resolve(
            AppCopyKey.conclusionChronicleStage,
            arguments: [.integer(year), .userText(resolver.resolve(.chapterSeason(season)))]
        )
    }

    static func localizedChronicleEntry(
        _ entry: HighSchoolCareerStore.ChronicleEntry,
        resolver: GameCopyResolver
    ) -> (stage: String, text: String) {
        (
            localizedChronicleStage(entry.stage, resolver: resolver),
            localizedChronicleText(entry.text, resolver: resolver)
        )
    }

    /// `LifeRecord` stores flattened chronicle lines. The same projection is used so a share card
    /// cannot silently reintroduce the persisted Korean sentence after the conclusion view was
    /// migrated.
    static func localizedChronicleLine(
        _ rawLine: String,
        resolver: GameCopyResolver
    ) -> String {
        guard let separator = rawLine.range(of: " — ") else {
            return resolver.language == .korean ? rawLine : GameCopyResolver.unavailableText
        }
        let stage = String(rawLine[..<separator.lowerBound])
        let text = String(rawLine[separator.upperBound...])
        guard resolver.language == .english else { return rawLine }
        let localizedStage = localizedChronicleStage(stage, resolver: resolver)
        let localizedText = localizedChronicleText(text, resolver: resolver)
        guard localizedStage != GameCopyResolver.unavailableText,
              localizedText != GameCopyResolver.unavailableText else {
            return GameCopyResolver.unavailableText
        }
        return "\(localizedStage) — \(localizedText)"
    }

    static func localizedChronicleText(
        _ rawText: String,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language == .english else { return rawText }

        if rawText == "프로 유니폼을 입었습니다." {
            return resolver.resolve(AppCopyKey.conclusionChronicleProStart)
        }
        if rawText == "드래프트 미지명. 하지만 이 3년은 새 선수의 밑천이 됩니다." {
            return resolver.resolve(AppCopyKey.conclusionChronicleUndrafted)
        }
        if let draft = localizedDraftChronicle(rawText, resolver: resolver) { return draft }
        if let admission = localizedAdmissionChronicle(rawText, resolver: resolver) { return admission }
        if let personality = localizedPersonalityChronicle(rawText, resolver: resolver) { return personality }
        if let awakening = localizedAwakeningChronicle(rawText, resolver: resolver) { return awakening }
        if let nickname = localizedNicknameChronicle(rawText, resolver: resolver) { return nickname }
        if let game = localizedGameChronicle(rawText, resolver: resolver) { return game }
        if let goal = localizedGoalChronicle(rawText, resolver: resolver) { return goal }
        if let pledge = localizedPledgeChronicle(rawText, resolver: resolver) { return pledge }
        if let bloom = localizedBloomChronicle(rawText, resolver: resolver) { return bloom }
        return GameCopyResolver.unavailableText
    }

    private static func localizedDraftChronicle(
        _ rawText: String,
        resolver: GameCopyResolver
    ) -> String? {
        let draftedPrefix = "드래프트 "
        guard rawText.hasPrefix(draftedPrefix), rawText.hasSuffix(" 지명. 3년이 응답받았습니다.") else {
            return nil
        }
        let body = String(rawText.dropFirst(draftedPrefix.count))
        let suffix = " 지명. 3년이 응답받았습니다."
        let middle = String(body.dropLast(suffix.count))
        if let roundRange = middle.range(of: "라운드 "),
           let round = Int(middle[..<roundRange.lowerBound]),
           let team = DraftTeamPresentationCatalog.descriptors.first(where: {
               $0.rawTeamName == String(middle[roundRange.upperBound...])
           }) {
            return resolver.resolve(
                AppCopyKey.conclusionChronicleDrafted,
                arguments: [.integer(round), .userText(resolver.resolve(team.token))]
            )
        }
        if let team = DraftTeamPresentationCatalog.descriptors.first(where: { $0.rawTeamName == middle }) {
            return resolver.resolve(
                AppCopyKey.conclusionChronicleDraftedNoRound,
                arguments: [.userText(resolver.resolve(team.token))]
            )
        }
        return GameCopyResolver.unavailableText
    }

    private static func localizedAdmissionChronicle(
        _ rawText: String,
        resolver: GameCopyResolver
    ) -> String? {
        let suffix = " 입학. 3년이 시작됩니다."
        guard rawText.hasSuffix(suffix) else { return nil }
        let rawSchool = String(rawText.dropLast(suffix.count))
        for region in HighSchoolCareerEngine.regions {
            if let school = HighSchoolCareerEngine.schools(for: region).first(where: { $0.name == rawSchool }) {
                return resolver.resolve(
                    AppCopyKey.conclusionChronicleAdmission,
                    arguments: [.userText(HighSchoolPresentation.localizedSchoolName(
                        school, rawRegion: region, resolver: resolver
                    ))]
                )
            }
        }
        return GameCopyResolver.unavailableText
    }

    private static func localizedPersonalityChronicle(
        _ rawText: String,
        resolver: GameCopyResolver
    ) -> String? {
        for descriptor in DraftConclusionPresentationCatalog.personalityDescriptors {
            let settledPrefix = "성격이 자리 잡았습니다 — '\(descriptor.rawTitle)'. "
            if rawText.hasPrefix(settledPrefix), rawText == settledPrefix + descriptor.rawScoutLine {
                return resolver.resolve(
                    AppCopyKey.conclusionChroniclePersonality,
                    arguments: [
                        .userText(resolver.resolve(descriptor.titleToken)),
                        .userText(resolver.resolve(descriptor.scoutLineToken)),
                    ]
                )
            }
            let changed = "성격이 달라졌습니다 — '\(descriptor.rawTitle)'. 사람은 고정된 값이 아닙니다."
            if rawText == changed {
                return resolver.resolve(
                    AppCopyKey.conclusionChroniclePersonalityChanged,
                    arguments: [.userText(resolver.resolve(descriptor.titleToken))]
                )
            }
        }
        return nil
    }

    private static func localizedAwakeningChronicle(
        _ rawText: String,
        resolver: GameCopyResolver
    ) -> String? {
        guard rawText.hasPrefix("‘"), let titleEnd = rawText.range(of: "’을 익혔습니다. ") else {
            return nil
        }
        let rawTitle = String(rawText[rawText.index(after: rawText.startIndex)..<titleEnd.lowerBound])
        guard let id = AwakeningID.allCases.first(where: { HighSchoolPresentation.awakening($0).title == rawTitle }) else {
            return GameCopyResolver.unavailableText
        }
        let detail = HighSchoolPresentation.localizedAwakeningDetail(id, resolver: resolver)
        return resolver.resolve(
            AppCopyKey.conclusionChronicleAwakening,
            arguments: [
                .userText(HighSchoolPresentation.localizedAwakeningTitle(id, resolver: resolver)),
                .userText(detail),
            ]
        )
    }

    private static func localizedNicknameChronicle(
        _ rawText: String,
        resolver: GameCopyResolver
    ) -> String? {
        guard rawText.hasPrefix("'"),
              let closingQuote = rawText.dropFirst().firstIndex(of: "'") else { return nil }
        let rawTitle = String(rawText[rawText.index(after: rawText.startIndex)..<closingQuote])
        let remainder = String(rawText[rawText.index(after: closingQuote)...])
        let reason: String
        if remainder.hasPrefix("이라는 별명을 얻었습니다. ") {
            reason = String(remainder.dropFirst("이라는 별명을 얻었습니다. ".count))
        } else if remainder.hasPrefix("라는 별명을 얻었습니다. ") {
            reason = String(remainder.dropFirst("라는 별명을 얻었습니다. ".count))
        } else {
            return GameCopyResolver.unavailableText
        }
        guard let descriptor = NicknamePresentationCatalog.descriptors.first(where: {
            $0.koreanTitle == rawTitle
        }) else { return GameCopyResolver.unavailableText }
        let localizedReason = localizedNicknameReason(
            id: descriptor.id, rawReason: reason, resolver: resolver
        )
        guard localizedReason != GameCopyResolver.unavailableText else { return localizedReason }
        return resolver.resolve(
            AppCopyKey.conclusionChronicleNickname,
            arguments: [
                .userText(resolver.resolve(descriptor.titleToken)),
                .userText(localizedReason),
            ]
        )
    }

    private static func localizedNicknameReason(
        id: String,
        rawReason: String,
        resolver: GameCopyResolver
    ) -> String {
        let key = GameCopyKey.gameContent("content.nickname.\(id).reason")
        if id == "k-monster" || id == "k-machine" || id == "k-hunter",
           let value = numberAfter(rawReason, prefix: "통산 탈삼진 ") {
            return resolver.resolve(key, arguments: [.integer(value)])
        }
        if id == "iron-wall" || id == "zero",
           let value = numberAfter(rawReason, prefix: "") {
            return resolver.resolve(key, arguments: [.integer(value)])
        }
        if id == "flawless",
           let value = numberBefore(rawReason, marker: "경기 볼넷") {
            return resolver.resolve(key, arguments: [.integer(value)])
        }
        if id == "workhorse",
           let value = numberBefore(rawReason, marker: "번의 고교 공식 경기") {
            return resolver.resolve(key, arguments: [.integer(value)])
        }
        if id == "wild-thing",
           let value = numberAfter(rawReason, prefix: "경기당 볼넷 ") {
            return resolver.resolve(key, arguments: [.integer(value)])
        }
        if id == "batting-practice",
           let value = numberAfter(rawReason, prefix: "경기당 실점 ") {
            return resolver.resolve(key, arguments: [.integer(value)])
        }
        if ["pinpoint", "untouchable", "nine-k", "rough-diamond"].contains(id),
           !rawReason.isEmpty {
            return resolver.resolve(key)
        }
        return GameCopyResolver.unavailableText
    }

    private static func localizedGameChronicle(
        _ rawText: String,
        resolver: GameCopyResolver
    ) -> String? {
        let prefixes: [(String, GameCopyKey)] = [
            ("첫 공식 등판 — ", AppCopyKey.conclusionChronicleGameFirst),
            ("무실점 호투 — ", AppCopyKey.conclusionChronicleGameShutout),
            ("탈삼진 ", AppCopyKey.conclusionChronicleGameStrikeouts),
            ("무너진 날 — ", AppCopyKey.conclusionChronicleGameRough),
        ]
        for (prefix, key) in prefixes where rawText.hasPrefix(prefix) {
            if key == AppCopyKey.conclusionChronicleGameStrikeouts {
                guard let marker = rawText.range(of: "개로 압도 — "),
                      let strikeouts = Int(String(rawText.dropFirst(prefix.count).prefix(upTo: marker.lowerBound))) else {
                    return GameCopyResolver.unavailableText
                }
                let summary = String(rawText[marker.upperBound...])
                guard let localizedSummary = localizedGameSummary(summary, resolver: resolver) else {
                    return GameCopyResolver.unavailableText
                }
                return resolver.resolve(key, arguments: [.integer(strikeouts), .userText(localizedSummary)])
            }
            let summary = String(rawText.dropFirst(prefix.count))
            let rough = key == AppCopyKey.conclusionChronicleGameRough
            let summaryWithoutReminder = rough
                ? summary.replacingOccurrences(of: ". 이 경기를 기억해야 합니다.", with: "")
                : summary
            guard let localizedSummary = localizedGameSummary(summaryWithoutReminder, resolver: resolver) else {
                return GameCopyResolver.unavailableText
            }
            return resolver.resolve(key, arguments: [.userText(localizedSummary)])
        }
        return nil
    }

    private static func localizedGameSummary(
        _ rawSummary: String,
        resolver: GameCopyResolver
    ) -> String? {
        let pattern = #"^(\d+)구 · (\d+)탈삼진 · (\d+)볼넷 · (\d+)실점(?: · (.*?))?(?:\. (.*))?$"#
        guard let match = firstMatch(pattern, in: rawSummary), match.count >= 5,
              let pitches = Int(match[1]), let strikeouts = Int(match[2]),
              let walks = Int(match[3]), let runs = Int(match[4]) else {
            return nil
        }
        var result = "\(pitches) pitches · \(strikeouts) strikeouts · \(walks) walks · \(runs) runs allowed"
        if match.count > 5, !match[5].isEmpty {
            let growth = match[5]
            if let growthCopy = localizedGrowthSummary(growth, resolver: resolver) {
                result += " · \(growthCopy)"
            } else {
                return nil
            }
        }
        if match.count > 6, !match[6].isEmpty {
            // A future detail sentence is system-owned content. Do not leak it into English.
            return nil
        }
        return result
    }

    /// Compatibility bridge for the transient result banner. The raw Korean sentence is parsed
    /// only to recover typed numeric facts; it is never returned to an English UI.
    static func localizedStoreGameSummary(
        _ rawSummary: String,
        resolver: GameCopyResolver
    ) -> String? {
        localizedGameSummary(rawSummary, resolver: resolver)
    }

    private static func localizedGrowthSummary(
        _ rawValue: String,
        resolver: GameCopyResolver
    ) -> String? {
        guard rawValue.hasPrefix("경기 기반 성장 · ") else { return nil }
        let body = String(rawValue.dropFirst("경기 기반 성장 · ".count))
        if body.hasSuffix(" 한계 압박") {
            let ability = String(body.dropLast(" 한계 압박".count))
            guard let copy = localizedAbilityLabel(raw: ability, resolver: resolver) else { return nil }
            return "Game-based growth · \(copy) pressure at the talent wall"
        }
        guard let plus = body.range(of: " +"),
              let value = Int(body[plus.upperBound...]),
              let copy = localizedAbilityLabel(raw: String(body[..<plus.lowerBound]), resolver: resolver) else {
            return nil
        }
        return "Game-based growth · \(copy) +\(value)"
    }

    private static func localizedAbilityLabel(raw: String, resolver: GameCopyResolver) -> String? {
        let map: [String: TalentAbility] = ["구위": .stuff, "제구": .command, "변화구": .movement, "체력": .stamina]
        return map[raw].map { resolver.resolve($0.displayCopyToken) }
    }

    private static func localizedGoalChronicle(
        _ rawText: String,
        resolver: GameCopyResolver
    ) -> String? {
        let suffix = " 완수 — 이번 이야기 탈삼진 "
        guard let range = rawText.range(of: suffix), rawText.hasSuffix("개.") else { return nil }
        let rawTitle = String(rawText[..<range.lowerBound])
        let numberEnd = rawText.index(rawText.endIndex, offsetBy: -2)
        let numberText = String(rawText[range.upperBound..<numberEnd])
        guard let progress = Int(numberText) else { return GameCopyResolver.unavailableText }
        let frames: [String: ChapterGoal.Frame] = [
            "감독의 숙제": .coachAssignment,
            "스카우트의 시선": .scoutAttention,
            "포수의 내기": .catcherBet,
            "나와의 약속": .personalPromise,
        ]
        guard let frame = frames[rawTitle] else { return GameCopyResolver.unavailableText }
        let titleKey = GameCopyKey.gameContent("content.chapter-goal.\(frame.rawValue).title")
        let title = resolver.resolve(titleKey)
        return resolver.resolve(
            AppCopyKey.conclusionChronicleChapterGoal,
            arguments: [
                .userText(title),
                .integer(progress),
            ]
        )
    }

    private static func localizedPledgeChronicle(
        _ rawText: String,
        resolver: GameCopyResolver
    ) -> String? {
        let prefix = "고교 3년 목표 — "
        guard rawText.hasPrefix(prefix), rawText.hasSuffix(".") else { return nil }
        let rawTitle = String(rawText.dropFirst(prefix.count).dropLast())
        let currentID = RunPledge.all.first(where: { $0.title == rawTitle })?.id
        let legacyID = RunPledge.legacyV1.first(where: { $0.title == rawTitle })?.id
        guard let id = currentID ?? legacyID else { return GameCopyResolver.unavailableText }
        let keyID = (currentID == nil ? "legacy-" : "") + id.replacingOccurrences(of: "_", with: "-")
        return resolver.resolve(
            AppCopyKey.conclusionChroniclePledge,
            arguments: [.userText(resolver.resolve(GameCopyKey.gameContent("content.pledge.\(keyID).title")))]
        )
    }

    private static func localizedBloomChronicle(
        _ rawText: String,
        resolver: GameCopyResolver
    ) -> String? {
        let prefix = "만개 — 막혀 있던 "
        let middle = " 재능이 "
        let suffix = "까지 열렸습니다."
        guard rawText.hasPrefix(prefix), let middleRange = rawText.range(of: middle), rawText.hasSuffix(suffix) else {
            return nil
        }
        let rawAbility = String(rawText.dropFirst(prefix.count).prefix(upTo: middleRange.lowerBound))
        let rawGrade = String(rawText[middleRange.upperBound..<rawText.index(rawText.endIndex, offsetBy: -suffix.count)])
        guard let ability = [TalentAbility.stuff, .command, .movement, .stamina].first(where: { $0.label == rawAbility }),
              let grade = TalentGrade.allCases.first(where: { $0.label == rawGrade }) else {
            return GameCopyResolver.unavailableText
        }
        return resolver.resolve(
            AppCopyKey.conclusionChronicleBloom,
            arguments: [
                .userText(resolver.resolve(ability.displayCopyToken)),
                .userText(resolver.resolve(grade.displayCopyToken)),
            ]
        )
    }

    // MARK: - Season record

    static func localizedSeasonSummary(
        lines: [ProGameLine],
        resolver: GameCopyResolver
    ) -> String {
        let outs = lines.reduce(0) { $0 + $1.outs }
        let strikeouts = lines.reduce(0) { $0 + $1.strikeouts }
        let walks = lines.reduce(0) { $0 + $1.walks }
        let runs = lines.reduce(0) { $0 + $1.runsAllowed }
        if resolver.language == .korean {
            return "\(lines.count)경기 · \(outs / 3)이닝 · \(strikeouts)K \(walks)BB \(runs)실점"
        }
        return resolver.resolve(
            AppCopyKey.conclusionSeasonSummary,
            arguments: [
                .integer(lines.count), .userText(GameFormatters.innings(outs: outs, language: resolver.language)),
                .integer(strikeouts), .integer(walks), .integer(runs),
            ]
        )
    }

    static func localizedSeasonRA9(lines: [ProGameLine], resolver: GameCopyResolver) -> String {
        let outs = lines.reduce(0) { $0 + $1.outs }
        let runs = lines.reduce(0) { $0 + $1.runsAllowed }
        if resolver.language == .korean {
            return "9이닝당 실점 \(GameLineFormat.runsPerNine(outs: outs, runs: runs))"
        }
        return resolver.resolve(
            AppCopyKey.conclusionSeasonRA9,
            arguments: [.userText(GameFormatters.ra9(runsAllowed: runs, outs: outs, language: resolver.language))]
        )
    }

    static func localizedSeasonRole(_ line: ProGameLine, resolver: GameCopyResolver) -> String {
        if resolver.language == .korean { return GameLineFormat.role(line) }
        let key = line.started ? AppCopyKey.conclusionRoleStarter : AppCopyKey.conclusionRoleReliever
        return resolver.resolve(
            key,
            arguments: [.userText(GameFormatters.innings(outs: line.outs, language: resolver.language))]
        )
    }

    static func localizedSeasonDecision(_ decision: PitchingDecision, resolver: GameCopyResolver) -> String? {
        if resolver.language == .korean { return GameLineFormat.decisionLabel(decision) }
        switch decision {
        case .win: return resolver.resolve(AppCopyKey.conclusionDecisionWin)
        case .loss: return resolver.resolve(AppCopyKey.conclusionDecisionLoss)
        case .save: return resolver.resolve(AppCopyKey.conclusionDecisionSave)
        case .noDecision: return nil
        }
    }

    static func localizedSeasonLineAccessibility(_ line: ProGameLine, resolver: GameCopyResolver) -> String {
        if resolver.language == .korean { return GameLineFormat.accessibilityLabel(line) }
        var pitching = "\(line.strikeouts) strikeouts, \(line.walks) walks, \(line.runsAllowed) runs allowed"
        if let hits = line.hits { pitching = "\(hits) hits, " + pitching }
        return resolver.resolve(
            AppCopyKey.conclusionLineAccessibility,
            arguments: [
                .integer(line.week), .userText(localizedSeasonRole(line, resolver: resolver)),
                .userText(pitching), .userText("\(line.teamRuns) to \(line.opponentRuns)"),
                .userText(localizedSeasonDecision(line.decision, resolver: resolver) ?? "No decision"),
            ]
        )
    }

    // MARK: - Life card helpers

    static func localizedNicknameTitle(_ rawTitle: String, resolver: GameCopyResolver) -> String {
        guard resolver.language == .english else { return rawTitle }
        guard let descriptor = NicknamePresentationCatalog.descriptors.first(where: { $0.koreanTitle == rawTitle }) else {
            return GameCopyResolver.unavailableText
        }
        return resolver.resolve(descriptor.titleToken)
    }

    static func localizedSchoolName(_ rawName: String?, resolver: GameCopyResolver) -> String {
        guard let rawName else { return resolver.resolve(AppCopyKey.conclusionLifeCardSchoolUnknown) }
        guard resolver.language == .english else { return rawName }
        for region in HighSchoolCareerEngine.regions {
            if let school = HighSchoolCareerEngine.schools(for: region).first(where: { $0.name == rawName }) {
                return HighSchoolPresentation.localizedSchoolName(school, rawRegion: region, resolver: resolver)
            }
        }
        return GameCopyResolver.unavailableText
    }

    static func localizedLifeTeamName(_ rawName: String?, resolver: GameCopyResolver) -> String? {
        guard let rawName else { return nil }
        guard resolver.language == .english else { return rawName }
        guard let descriptor = DraftTeamPresentationCatalog.descriptors.first(where: { $0.rawTeamName == rawName }) else {
            return GameCopyResolver.unavailableText
        }
        return resolver.resolve(descriptor.token)
    }

    static func localizedLifePersonality(_ rawTitle: String?, resolver: GameCopyResolver) -> String? {
        guard let rawTitle else { return nil }
        guard resolver.language == .english else { return rawTitle }
        guard let descriptor = DraftConclusionPresentationCatalog.personalityDescriptors.first(where: { $0.rawTitle == rawTitle }) else {
            return GameCopyResolver.unavailableText
        }
        return resolver.resolve(descriptor.titleToken)
    }

    static func localizedLifeWind(id: String?, rawTitle: String?, resolver: GameCopyResolver) -> String? {
        guard let id, let rawTitle else { return nil }
        guard resolver.language == .english else { return rawTitle }
        let winds = CareerWindPresentationCatalog.v1Winds + CareerWindPresentationCatalog.v2Winds
        guard let wind = winds.first(where: { $0.id == id && $0.title == rawTitle }) else {
            return GameCopyResolver.unavailableText
        }
        return localizedWind(wind, resolver: resolver).title
    }

    static func localizedLifeCastName(
        rawName: String?,
        schoolName: String?,
        role: SchoolCastRole,
        resolver: GameCopyResolver
    ) -> String? {
        guard let rawName else { return nil }
        guard resolver.language == .english else { return rawName }
        for region in HighSchoolCareerEngine.regions {
            for school in HighSchoolCareerEngine.schools(for: region) where school.name == schoolName {
                let expected = role == .coach ? school.coachName : school.catcherName
                if expected == rawName {
                    return HighSchoolPresentation.localizedSchoolCastName(
                        school, rawRegion: region, role: role, resolver: resolver
                    )
                }
            }
        }
        return GameCopyResolver.unavailableText
    }

    static func localizedLifeRivalName(_ rawName: String?, resolver: GameCopyResolver) -> String? {
        guard let rawName else { return nil }
        guard resolver.language == .english else { return rawName }
        let rawRivals: [String: String] = [
            "서하준": "rival-seo", "권태오": "rival-lee", "남도현": "rival-park", "배시우": "rival-kang",
            "류건우": "rival-yoon", "정세현": "rival-choi", "강이안": "rival-home-run", "문재윤": "rival-speed",
        ]
        guard let id = rawRivals[rawName] else { return GameCopyResolver.unavailableText }
        return resolver.resolve(RivalPresentationCatalog.descriptor(for: id).nameToken)
    }

    static func localizedLifeRateLine(
        outs: Int?, runsAllowed: Int, walks: Int, hits: Int?, strikeouts: Int,
        resolver: GameCopyResolver
    ) -> RateLine? {
        guard let outs, outs > 0 else { return nil }
        let innings = resolver.language == .korean
            ? "\(outs / 3).\(outs % 3)"
            : GameFormatters.innings(outs: outs, language: resolver.language)
        return RateLine(
            innings: innings,
            ra9: GameFormatters.ra9(runsAllowed: runsAllowed, outs: outs, language: resolver.language)
                .replacingOccurrences(of: " RA9", with: ""),
            whip: GameFormatters.whip(hits: hits ?? 0, walks: walks, outs: outs, language: resolver.language)
                .replacingOccurrences(of: " WHIP", with: ""),
            strikeoutsPerNine: GameFormatters.metricK9(strikeouts: strikeouts, outs: outs, language: resolver.language)
        )
    }

    static func localizedLifeSeasonLine(
        pitches: Int?, strikeouts: Int, walks: Int, resolver: GameCopyResolver
    ) -> String {
        if resolver.language == .korean {
            var parts: [String] = []
            if let pitches, pitches > 0 { parts.append("\(pitches)구") }
            if walks > 0 {
                parts.append(String(format: "탈삼진/볼넷 %.1f", Double(strikeouts) / Double(walks)))
            } else if strikeouts > 0 {
                parts.append("볼넷 없이 \(strikeouts)탈삼진")
            }
            parts.append("직접 등판 기준")
            return parts.joined(separator: " · ")
        }
        if walks == 0 {
            if strikeouts > 0 {
                return resolver.resolve(AppCopyKey.conclusionLifeCardSeasonLineNoWalks,
                                        arguments: [.integer(strikeouts)])
            }
            return resolver.resolve(AppCopyKey.conclusionLifeCardSeasonLineEmpty)
        }
        let ratio = String(format: "%.1f", Double(strikeouts) / Double(walks))
        let key = (pitches ?? 0) > 0
            ? AppCopyKey.conclusionLifeCardSeasonLine
            : AppCopyKey.conclusionLifeCardSeasonLineNoPitches
        let arguments: [LocalizedCopyArgument] = (pitches ?? 0) > 0
            ? [.integer(pitches ?? 0), .userText(ratio)]
            : [.userText(ratio)]
        return resolver.resolve(key, arguments: arguments)
    }

    static func localizedDisplayName(
        baseName: String,
        nicknames: [Nickname],
        resolver: GameCopyResolver
    ) -> String {
        guard let nickname = nicknames.last else { return baseName }
        let title = localizedNicknameTitle(nickname.title, resolver: resolver)
        return "'\(title)' \(baseName)"
    }

    // MARK: - Private raw-value helpers

    private static func rawTeamField(_ team: DraftTeamSnapshot, field: DraftTeamConclusionFieldID) -> String? {
        switch field {
        case .name: team.name
        case .developmentPlan: team.developmentPlan
        case .positionCompetitor: team.positionCompetitor
        case .proCoach: team.proCoach
        case .competitorProfile: team.competitorProfile
        case .competitorRecord: team.competitorRecord
        case .coachProfile: team.coachProfile
        case .coachRecord: team.coachRecord
        }
    }

    private static func numberAfter(_ value: String, prefix: String) -> Int? {
        let body = prefix.isEmpty ? value : String(value.dropFirst(prefix.count))
        guard prefix.isEmpty || value.hasPrefix(prefix) else { return nil }
        return Int(body.split(whereSeparator: { !$0.isNumber }).first.map(String.init) ?? "")
    }

    private static func numberBefore(_ value: String, marker: String) -> Int? {
        guard let range = value.range(of: marker), let number = Int(value[..<range.lowerBound]) else { return nil }
        return number
    }

    private static func firstMatch(_ pattern: String, in value: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: range) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            let capture = match.range(at: index)
            guard capture.location != NSNotFound, let swiftRange = Range(capture, in: value) else { return "" }
            return String(value[swiftRange])
        }
    }
}

private extension GameFormatters {
    static func metricK9(strikeouts: Int, outs: Int, language: AppLanguage) -> String {
        guard outs > 0 else { return language == .english ? "—" : "—" }
        let value = Double(max(0, strikeouts)) * 27 / Double(outs)
        return String(format: "%.1f", value)
    }
}
