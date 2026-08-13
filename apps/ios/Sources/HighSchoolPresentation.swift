import Foundation
import SimulationCore

/// 고교 커리어 화면이 쓰는 표시 문구와 파생값. 데스크톱 `HighSchoolCareerView.tsx`의 라벨 표와
/// 같은 값을 쓰므로 두 플랫폼의 각성·기억 카드 설명이 갈리지 않는다.
enum HighSchoolPresentation {
    struct ChapterReviewGainRow: Identifiable, Equatable {
        /// Raw/stable identity used by SwiftUI diffing. The localized label is display-only.
        let id: String
        let label: String
        let delta: Int
    }

    // MARK: - 라벨

    /// 저장 규칙의 8개 진행 구간은 그대로 두고, 사용자가 한 번에 이해할 수 있는 네 장으로
    /// 묶는다. 파생값이라 옛 저장과 결정론을 건드리지 않는다.
    static func actNumber(chapter: Int) -> Int {
        min(4, max(1, (chapter + 1) / 2))
    }

    static func actTitle(chapter: Int) -> String {
        switch actNumber(chapter: chapter) {
        case 1: "1장 · 자리를 얻다"
        case 2: "2장 · 내 공을 만들다"
        case 3: "3장 · 책임을 지다"
        default: "4장 · 이름을 남기다"
        }
    }

    static func phase(_ phase: HighSchoolCareerPhase) -> String {
        switch phase {
        case .prologue: "다시 태어남"
        case .schoolSelection: "학교 선택"
        case .training: "훈련"
        case .relationship: "사람들"
        case .importantGame: "고교 공식 경기"
        case .awakening: "각성"
        case .chapterReview: "이야기 마무리"
        case .draft: "드래프트"
        case .legacy: "새 선수에게 남길 것"
        case .completed: "완료"
        }
    }

    static func localized(_ phase: HighSchoolCareerPhase, resolver: GameCopyResolver) -> String {
        resolver.resolve(phase.displayCopyToken)
    }

    static func localizedChapterTitle(
        _ chapter: CareerChapterSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(CareerChapterPresentationCatalog.descriptor(for: chapter).titleToken)
    }

    /// Reauthors the store's frozen Korean compatibility summary from stable state and typed
    /// numeric captures. Unknown source prose fails closed to neutral English.
    @MainActor static func localizedStoreSummary(
        _ raw: String,
        career: HighSchoolCareerStore,
        state: HighSchoolCareerSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language == .english else { return raw }

        switch raw {
        case "UI 테스트용 미지명 직전 상태를 준비했습니다.",
             "UI 테스트용 지명 완료 상태를 준비했습니다.":
            return resolver.resolve(.highSchoolSummaryFixture)
        case "현재 환생 기록을 읽지 못해 직전 정상 백업으로 복구했습니다.",
             "iCloud 환생 기록을 읽지 못해 직전 정상 백업으로 복구했습니다.":
            return resolver.resolve(.highSchoolSummaryBackupRecovered)
        case "시드는 카드에 적힌 숫자만 입력할 수 있습니다. 다시 확인해 주세요.":
            return resolver.resolve(.highSchoolSummarySeedInvalid)
        case "기록 없는 도전 — 이 판의 결과는 선수 기록과 계승에 남지 않습니다.":
            return resolver.resolve(.highSchoolSummaryChallengeStarted)
        case "고교 첫 해가 시작됩니다.":
            return resolver.resolve(.highSchoolSummaryFirstYear)
        case "프로 커리어를 마치면 고교 시절과 통산 기록을 함께 돌아봅니다.":
            return resolver.resolve(.highSchoolSummaryProPending)
        case "프로 커리어를 마쳤습니다. 이제 당시 규칙대로 남길 기억을 고릅니다.":
            return resolver.resolve(.highSchoolSummaryProMemoryChoice)
        case "고교 시절과 프로 통산 기록에서 대표 유산 세 가지를 찾았습니다.":
            return resolver.resolve(.highSchoolSummaryProLegacyFound)
        case "다른 기기의 진행을 불러왔습니다.":
            return resolver.resolve(.highSchoolSummaryCloudLoaded)
        case "iCloud 환생 기록을 읽지 못해 이 기기의 진행을 유지합니다.":
            return resolver.resolve(.highSchoolSummaryCloudKeptLocal)
        case "등판을 중단했습니다. 다음 마운드는 새 이닝입니다.":
            return resolver.resolve(.highSchoolSummaryOutingAbandoned)
        default:
            break
        }

        if let values = summaryCaptures(raw, pattern: #"^같은 훈련 (\d+)회 완료 · 능력 성장 \+(\d+)$"#),
           values.count == 2, let count = Int(values[0]), let growth = Int(values[1]) {
            return resolver.resolve(
                .highSchoolSummaryRepeatTraining,
                arguments: [.integer(count), .integer(growth)]
            )
        }

        if raw.hasSuffix("번째 선수. 대표 유산 하나로 다시 시작합니다.")
            || raw.contains("번째 선수. 기억 ") {
            let memoryCount = career.inheritance.memories.count
            let inherited: String
            if career.inheritance.equippedSignatureLegacyID != nil, memoryCount > 0 {
                inherited = resolver.resolve(.highSchoolSummaryRebirthBoth, arguments: [.integer(memoryCount)])
            } else if career.inheritance.equippedSignatureLegacyID != nil {
                inherited = resolver.resolve(.highSchoolSummaryRebirthSignature)
            } else {
                inherited = resolver.resolve(.highSchoolSummaryRebirthMemories, arguments: [.integer(memoryCount)])
            }
            return resolver.resolve(
                .highSchoolSummaryRebirthStarted,
                arguments: [.integer(state.lifeNumber), .userText(inherited)]
            )
        }

        if let game = HighSchoolConclusionPresentation.localizedStoreGameSummary(raw, resolver: resolver) {
            return game
        }

        if let values = summaryCaptures(raw, pattern: #"^(.+) 완수\. 삼진 (\d+)개"#),
           values.count == 2, let strikeouts = Int(values[1]),
           let frame = chapterGoalFrame(koreanTitle: values[0]) {
            let title = resolver.resolve(.gameContent("content.chapter-goal.\(frame.rawValue).title"))
            return resolver.resolve(
                .highSchoolSummaryGoalCompleted,
                arguments: [.userText(title), .integer(strikeouts)]
            )
        }

        if let values = summaryCaptures(raw, pattern: #"^이제 사람들이 '([^']+)'"#),
           let rawTitle = values.first {
            let title = HighSchoolConclusionPresentation.localizedNicknameTitle(rawTitle, resolver: resolver)
            return resolver.resolve(.highSchoolSummaryNicknameEarned, arguments: [.userText(title)])
        }

        if let values = summaryCaptures(raw, pattern: #"^기억 (\d+)장을 새 선수에게 남깁니다\.$"#),
           let count = values.first.flatMap(Int.init) {
            return resolver.resolve(.highSchoolSummaryMemoriesLeft, arguments: [.integer(count)])
        }
        if raw.hasSuffix("새 선수에게 남깁니다."),
           let signature = career.pendingRecap?.record.signatureLegacy {
            let title = HighSchoolConclusionPresentation.localizedSignature(
                signature, resolver: resolver
            ).title
            return resolver.resolve(.highSchoolSummarySignatureLeft, arguments: [.userText(title)])
        }

        if raw.hasPrefix("목표를 정했습니다:"), let pledge = career.pledge {
            return resolver.resolve(
                .highSchoolSummaryPledgeChosen,
                arguments: [
                    .userText(LegacyPresentation.pledgeTitle(pledge, resolver: resolver)),
                    .integer(pledge.rewardPermille / 10),
                ]
            )
        }

        if let receipt = career.trainingReceipt, raw == receipt.detail {
            return localizedTrainingResultDetail(receipt, resolver: resolver)
        }

        if let relationship = state.lastRelationship,
           let event = HighSchoolContentCatalog.relationshipEvents.first(where: { $0.title == relationship.title }),
           let choice = RelationshipPresentationCatalog.cardDescriptor(for: event).choiceDescriptors
               .first(where: { $0.response == relationship.response }) {
            let abilityChange: String
            if let focus = relationship.growthFocus,
               let before = relationship.abilityBefore,
               let after = relationship.abilityAfter {
                abilityChange = resolver.resolve(
                    .highSchoolSummaryRelationshipAbility,
                    arguments: [
                        .userText(resolver.resolve(focus.displayCopyToken)),
                        .integer(after - before),
                    ]
                )
            } else {
                abilityChange = ""
            }
            return resolver.resolve(
                .highSchoolSummaryRelationship,
                arguments: [
                    .userText(resolver.resolve(choice.detailToken)),
                    .integer(relationship.trustAfter - relationship.trustBefore),
                    .integer(relationship.fatigueAfter - relationship.fatigueBefore),
                    .integer(relationship.fanInterestAfter - relationship.fanInterestBefore),
                    .userText(abilityChange),
                ]
            )
        }

        let chapter = CareerChapterPresentationCatalog.descriptor(for: state.chapter)
        if raw == "\(state.chapter.title) · \(state.chapter.season)" {
            return resolver.resolve(
                .highSchoolSummaryChapterAdvanced,
                arguments: [
                    .userText(resolver.resolve(chapter.titleToken)),
                    .userText(resolver.resolve(chapter.seasonToken)),
                ]
            )
        }

        if let awakening = state.selectedAwakenings.last,
           raw.contains(HighSchoolPresentation.awakening(awakening).title) {
            return resolver.resolve(
                .highSchoolSummaryAwakening,
                arguments: [
                    .userText(localizedAwakeningTitle(awakening, resolver: resolver)),
                    .userText(localizedAwakeningDetail(awakening, resolver: resolver)),
                ]
            )
        }

        if let draft = state.draftResult {
            return HighSchoolConclusionPresentation.localizedDraftSummary(draft, resolver: resolver)
        }
        return resolver.resolve(.highSchoolSummaryUpdated)
    }

    static func localizedSummaryCue(
        _ cue: MobileCareerStore.FeedbackCue,
        resolver: GameCopyResolver
    ) -> String {
        let key: LegacyUICopyKey = switch cue {
        case .setback: .highSchoolSummaryCueSetback
        case .growth: .highSchoolSummaryCueGrowth
        case .success: .highSchoolSummaryCueSuccess
        case .neutral: .highSchoolSummaryCueNeutral
        }
        return resolver.resolve(key)
    }

    static func localizedPersonalityTraitTitle(
        _ trait: PersonalityTrait,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language == .english else { return trait.title }
        return resolver.resolve(.gameContent("content.personality-trait.\(trait.rawValue).title"))
    }

    static func localizedPersonalityTraitActivation(
        _ trait: PersonalityTrait,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language == .english else { return trait.activationLine }
        return resolver.resolve(.gameContent("content.personality-trait.\(trait.rawValue).activation"))
    }

    static func focus(_ focus: TrainingFocus) -> String {
        switch focus {
        case .velocity: "구위"
        case .command: "제구"
        case .breakingBall: "변화구"
        case .stamina: "체력"
        case .recovery: "회복"
        case .gamePlanning: "승부 설계"
        }
    }

    static func localized(_ focus: TrainingFocus, resolver: GameCopyResolver) -> String {
        resolver.resolve(focus.displayCopyToken)
    }

    static func localizedSchoolName(
        _ school: SchoolSnapshot,
        rawRegion: String,
        resolver: GameCopyResolver
    ) -> String {
        if let region = SchoolRegionID.strictLookup(rawRegion: rawRegion) {
            let copy = CopyToken.schoolSelectionDescriptor(region: region, schoolID: school.id)
            return resolver.resolve(copy.schoolNameToken)
        }
        // A legacy Korean region is intentionally left untouched so opening an old career does
        // not rewrite its visible school identity. English uses a non-regional SchoolID fallback
        // rather than the Seoul-specific generic catalog entry.
        if resolver.language == .korean { return school.name }
        return resolver.resolve(school.id.fallbackNameCopyToken)
    }

    static func localizedSchoolCastName(
        _ school: SchoolSnapshot,
        rawRegion: String,
        role: SchoolCastRole,
        resolver: GameCopyResolver
    ) -> String {
        let baseName: String
        if let region = SchoolRegionID.strictLookup(rawRegion: rawRegion) {
            let copy = CopyToken.schoolSelectionDescriptor(region: region, schoolID: school.id)
            let token = role == .coach ? copy.coachNameToken : copy.catcherNameToken
            baseName = resolver.resolve(token)
        } else if resolver.language == .korean {
            // This is the only visible legacy-name path. It preserves the exact Korean payload
            // from an old save; the RelationshipCard itself only calls this semantic resolver.
            baseName = role == .coach ? school.coachName : school.catcherName
        } else {
            baseName = resolver.resolve(
                CopyToken.schoolFallbackCastName(schoolID: school.id, role: role)
            )
        }

        let suffixKey = role == .coach ? AppCopyKey.schoolSelectionCoach : AppCopyKey.schoolSelectionCatcher
        return resolver.resolve(suffixKey, arguments: [.userText(baseName)])
    }

    static func localizedRelationshipSpeaker(
        event: CareerEventContent,
        resolver: GameCopyResolver
    ) -> String {
        let descriptor = RelationshipPresentationCatalog.eventDescriptor(for: event)
        return resolver.resolve(descriptor.speakerLabelToken)
    }

    static func localizedRelationshipCategory(
        event: CareerEventContent,
        resolver: GameCopyResolver
    ) -> String {
        let descriptor = RelationshipPresentationCatalog.eventDescriptor(for: event)
        return resolver.resolve(descriptor.categoryLabelToken)
    }

    /// Portrait seeds are visual-only and are never copied into a visible label. Keeping this
    /// legacy-data read here leaves the relationship card's visible source boundary semantic.
    static func relationshipPortraitSeed(
        category: String,
        state: HighSchoolCareerSnapshot
    ) -> (seed: String, role: AvatarFace.Role)? {
        switch category {
        case "coach":
            guard let school = state.school else { return nil }
            return (school.coachName, .coach)
        case "catcher":
            guard let school = state.school else { return nil }
            return (school.catcherName, .catcher)
        case "rival":
            return (state.rival.name, .rival)
        default:
            return nil
        }
    }

    static func localizedRelationshipEventTitle(
        _ event: CareerEventContent,
        resolver: GameCopyResolver
    ) -> String {
        let descriptor = RelationshipPresentationCatalog.eventDescriptor(for: event)
        if descriptor.isKnownEvent { return resolver.resolve(descriptor.titleToken) }
        return resolver.language == .korean
            ? event.title
            : resolver.resolve(descriptor.titleToken)
    }

    static func localizedRelationshipEventSummary(
        _ event: CareerEventContent,
        resolver: GameCopyResolver
    ) -> String {
        let descriptor = RelationshipPresentationCatalog.eventDescriptor(for: event)
        if descriptor.isKnownEvent { return resolver.resolve(descriptor.summaryToken) }
        return resolver.language == .korean
            ? event.summary
            : resolver.resolve(descriptor.summaryToken)
    }

    static func relationshipTrustBand(
        for event: CareerEventContent,
        manager: Int,
        catcher: Int,
        rival: Int,
        resolver: GameCopyResolver
    ) -> RelationshipVoiceCatalog.TrustBand {
        let descriptor = RelationshipPresentationCatalog.cardDescriptor(for: event)
        if descriptor.event.isKnownEvent {
            return RelationshipVoiceCatalog.trustBand(
                for: descriptor.sceneSpeaker,
                manager: manager,
                catcher: catcher,
                rival: rival
            )
        }
        guard resolver.language == .korean,
              let scene = RelationshipVoiceCatalog.scene(eventID: event.id, category: event.category) else {
            return .mid
        }
        return RelationshipVoiceCatalog.trustBand(
            for: scene.speaker,
            manager: manager,
            catcher: catcher,
            rival: rival
        )
    }

    static func localizedRelationshipQuote(
        event: CareerEventContent,
        band: RelationshipVoiceCatalog.TrustBand,
        playerName: String,
        resolver: GameCopyResolver
    ) -> String {
        let descriptor = RelationshipPresentationCatalog.cardDescriptor(for: event)
        if descriptor.event.isKnownEvent {
            guard descriptor.quoteDescriptors.contains(where: { $0.trustBand == band }) else {
                return ""
            }
            return resolver.resolve(
                RelationshipVoiceCatalog.quoteCopyToken(
                    eventID: event.id,
                    trustBand: band,
                    playerName: playerName
                )
            )
        }
        if resolver.language == .korean,
           let scene = RelationshipVoiceCatalog.scene(eventID: event.id, category: event.category) {
            return scene.quote(band).replacingOccurrences(of: "{player}", with: playerName)
        }
        return resolver.resolve(.relationshipFallbackQuote())
    }

    static func localizedRelationshipChoiceTitle(
        event: CareerEventContent,
        response: RelationshipResponse,
        resolver: GameCopyResolver
    ) -> String {
        let descriptor = RelationshipPresentationCatalog.cardDescriptor(for: event)
        if descriptor.event.isKnownEvent,
           let choice = descriptor.choiceDescriptors.first(where: { $0.response == response }) {
            return resolver.resolve(choice.titleToken)
        }
        if resolver.language == .korean,
           let choice = RelationshipVoiceCatalog.scene(eventID: event.id, category: event.category)?
               .choices.first(where: { $0.response == response }) {
            return choice.title
        }
        return resolver.resolve(.relationshipFallbackChoiceTitle(response: response))
    }

    static func localizedRelationshipChoiceDetail(
        event: CareerEventContent,
        response: RelationshipResponse,
        resolver: GameCopyResolver
    ) -> String {
        let descriptor = RelationshipPresentationCatalog.cardDescriptor(for: event)
        if descriptor.event.isKnownEvent,
           let choice = descriptor.choiceDescriptors.first(where: { $0.response == response }) {
            return resolver.resolve(choice.detailToken)
        }
        if resolver.language == .korean,
           let choice = RelationshipVoiceCatalog.scene(eventID: event.id, category: event.category)?
               .choices.first(where: { $0.response == response }) {
            return choice.detail
        }
        return resolver.resolve(.relationshipFallbackChoiceDetail(response: response))
    }

    static func localizedRivalName(
        _ rival: RivalSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        let descriptor = RivalPresentationCatalog.descriptor(for: rival.id)
        if descriptor.isKnownRival { return resolver.resolve(descriptor.nameToken) }
        return resolver.language == .korean ? rival.name : resolver.resolve(descriptor.nameToken)
    }

    static func localizedRivalArchetype(
        _ rival: RivalSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        let descriptor = RivalPresentationCatalog.descriptor(for: rival.id)
        if descriptor.isKnownRival { return resolver.resolve(descriptor.archetypeToken) }
        return resolver.language == .korean
            ? rival.archetype
            : resolver.resolve(descriptor.archetypeToken)
    }

    static func localizedRivalSignature(
        _ rival: RivalSnapshot,
        resolver: GameCopyResolver
    ) -> String? {
        guard rival.signatureRecord != nil || descriptorForRival(rival).isKnownRival else { return nil }
        let descriptor = descriptorForRival(rival)
        if descriptor.isKnownRival { return resolver.resolve(descriptor.signatureToken) }
        return resolver.language == .korean
            ? rival.signatureRecord
            : resolver.resolve(descriptor.signatureToken)
    }

    // MARK: - Chapter review

    static func localizedChapterReviewTitle(
        _ chapter: CareerChapterSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        let chapterCopy = CareerChapterPresentationCatalog.descriptor(for: chapter)
        return resolver.resolve(
            AppCopyKey.chapterReviewCardTitle,
            arguments: [.userText(resolver.resolve(chapterCopy.titleToken))]
        )
    }

    static func localizedChapterReviewVerdict(
        _ performance: CareerPerformanceSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(ChapterReviewPresentationCatalog.descriptor(for: performance).token)
    }

    static func localizedChapterReviewStatLine(
        _ performance: CareerPerformanceSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.chapterReviewStatLine,
            arguments: [
                .integer(performance.importantGamesCompleted),
                .integer(performance.strikeouts),
                .integer(performance.walks),
            ]
        )
    }

    static func localizedChapterReviewGrowthEmpty(
        trainingCount: Int,
        resolver: GameCopyResolver
    ) -> String {
        if trainingCount == 0 {
            return resolver.resolve(AppCopyKey.chapterReviewGrowthEmptyNoTraining)
        }
        return resolver.resolve(
            AppCopyKey.chapterReviewGrowthEmptyWithTraining,
            arguments: [.integer(trainingCount)]
        )
    }

    static func localizedChapterReviewGrowthSummary(
        trainingCount: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.chapterReviewGrowthSummary,
            arguments: [.integer(trainingCount)]
        )
    }

    /// Sorts the persisted raw gain map exactly as the pre-migration card did, then localizes
    /// each stable ability identity. In particular, localized labels never participate in sort.
    static func localizedChapterReviewGainRows(
        _ gains: [String: Int],
        resolver: GameCopyResolver
    ) -> [ChapterReviewGainRow] {
        gains.sorted { $0.value > $1.value }.map { rawLabel, delta in
            let ability: TalentAbility? = switch rawLabel {
            case "구위": .stuff
            case "제구": .command
            case "변화구": .movement
            case "체력": .stamina
            default: nil
            }
            return ChapterReviewGainRow(
                id: ability?.rawValue ?? "legacy.\(rawLabel)",
                label: ability.map { resolver.resolve($0.displayCopyToken) }
                    ?? (resolver.language == .korean ? rawLabel : GameCopyResolver.unavailableText),
                delta: delta
            )
        }
    }

    static func localizedChapterReviewRivalLine(
        _ rival: RivalSnapshot,
        resolver: GameCopyResolver
    ) -> String? {
        let descriptor = RivalPresentationCatalog.descriptor(for: rival.id)
        guard descriptor.isKnownRival || !rival.name.isEmpty else { return nil }
        return resolver.resolve(
            AppCopyKey.chapterReviewNextStoryRival,
            arguments: [.userText(localizedRivalName(rival, resolver: resolver))]
        )
    }

    // MARK: - Tournament card

    static func localizedTournamentName(
        chapterNumber: Int,
        resolver: GameCopyResolver
    ) -> String {
        guard let descriptor = TournamentPresentationCatalog.tournamentNameDescriptor(for: chapterNumber) else {
            return GameCopyResolver.unavailableText
        }
        return resolver.resolve(descriptor.token)
    }

    static func localizedTournamentRound(
        rawRound: String,
        resolver: GameCopyResolver
    ) -> String {
        guard let descriptor = TournamentPresentationCatalog.roundDescriptor(for: rawRound) else {
            return GameCopyResolver.unavailableText
        }
        return resolver.resolve(descriptor.token)
    }

    static func localizedTournamentOpponentSchool(
        rawSchoolName: String,
        resolver: GameCopyResolver
    ) -> String {
        guard let descriptor = TournamentPresentationCatalog.opponentSchoolDescriptor(for: rawSchoolName) else {
            return GameCopyResolver.unavailableText
        }
        return resolver.resolve(descriptor.token)
    }

    static func localizedTournamentAceStart(
        round: String,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.tournamentAceStart,
            arguments: [.userText(localizedTournamentRound(rawRound: round, resolver: resolver))]
        )
    }

    // MARK: - Chapter goal card

    static func localizedChapterGoalTitle(
        _ goal: ChapterGoal.Goal,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(ChapterGoalPresentationCatalog.descriptor(for: goal).titleToken)
    }

    static func localizedChapterGoalDetail(
        _ goal: ChapterGoal.Goal,
        resolver: GameCopyResolver
    ) -> String {
        let descriptor = ChapterGoalPresentationCatalog.descriptor(for: goal)
        return resolver.resolve(
            .chapterGoalDetail(descriptor.frame, targetStrikeouts: goal.targetStrikeouts)
        )
    }

    static func localizedChapterGoalProgress(
        progress: Int,
        targetStrikeouts: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.chapterGoalProgress,
            arguments: [.integer(progress), .integer(targetStrikeouts)]
        )
    }

    // MARK: - Important game

    /// The scenario's title and narrative are resolved by ID. Legacy title/narrative fields are
    /// deliberately never used as visible fallback text.
    static func localizedImportantGameScenarioTitle(
        _ scenario: ImportantGameScenarioContent,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(ImportantGamePresentationCatalog.descriptor(for: scenario.id).titleToken)
    }

    static func localizedImportantGameScenarioNarrative(
        _ scenario: ImportantGameScenarioContent,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(ImportantGamePresentationCatalog.descriptor(for: scenario.id).narrativeToken)
    }

    static func localizedImportantGameSituation(
        _ scenario: ImportantGameScenarioContent,
        resolver: GameCopyResolver
    ) -> String {
        let safeOuts = max(0, scenario.outs)
        let inning = GameFormatters.inningLabel(inning: scenario.inning, language: resolver.language)
        let key: GameCopyKey
        var arguments: [LocalizedCopyArgument] = [.userText(inning)]
        switch safeOuts {
        case 0:
            key = AppCopyKey.importantGameSituationZero
        case 1:
            key = AppCopyKey.importantGameSituationOne
        default:
            key = AppCopyKey.importantGameSituationMany
            arguments.append(.integer(safeOuts))
        }
        return resolver.resolve(key, arguments: arguments)
    }

    static func localizedImportantGameScenarioAccessibility(
        title: String,
        situation: String,
        narrative: String,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.importantGameScenarioAccessibility,
            arguments: [.userText(title), .userText(situation), .userText(narrative)]
        )
    }

    static func localizedImportantGameOpponentTitle(
        isFinalShowdown: Bool,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            isFinalShowdown
                ? AppCopyKey.importantGameFinalShowdownTitle
                : AppCopyKey.importantGameOpponentTitle
        )
    }

    static func localizedImportantGameFinalShowdownBody(
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(AppCopyKey.importantGameFinalShowdownBody)
    }

    static func localizedImportantGameCareerMatchup(
        _ ledger: HighSchoolCareerStore.RivalLedger,
        resolver: GameCopyResolver
    ) -> String? {
        guard ledger.plateAppearances > 0 else { return nil }
        return resolver.resolve(
            AppCopyKey.importantGameCareerMatchup,
            arguments: [
                .integer(ledger.plateAppearances),
                .integer(ledger.strikeouts),
                .integer(ledger.hits),
            ]
        )
    }

    static func localizedImportantGameRivalAccessibility(
        name: String,
        archetype: String,
        signature: String?,
        resolver: GameCopyResolver
    ) -> String {
        let key = signature == nil
            ? AppCopyKey.importantGameRivalAccessibility
            : AppCopyKey.importantGameRivalAccessibilitySignature
        var arguments: [LocalizedCopyArgument] = [.userText(name), .userText(archetype)]
        if let signature {
            arguments.append(.userText(signature))
        }
        return resolver.resolve(
            key,
            arguments: arguments
        )
    }

    static func localizedImportantGameStartAction(resolver: GameCopyResolver) -> String {
        resolver.resolve(AppCopyKey.importantGameStartAction)
    }

    /// The raw legacy name is retained only as a deterministic portrait seed. It is never passed
    /// to a visible label or accessibility value.
    static func importantGameRivalPortraitSeed(_ rival: RivalSnapshot) -> String {
        rival.name
    }

    static func localizedChallengeOutcome(
        _ outcome: DraftOutcome?,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            outcome == .drafted
                ? AppCopyKey.challengeEndOutcomeDrafted
                : AppCopyKey.challengeEndOutcomeUndrafted
        )
    }

    static func localizedRelationshipWindLine(
        category: String,
        wind: CareerWind,
        resolver: GameCopyResolver
    ) -> String? {
        let target = HighSchoolCareerEngine.relationshipTarget(forEventCategory: category)
        let descriptor = RelationshipPresentationCatalog.windDescriptor(for: wind, target: target)
        guard !descriptor.effectTokens.isEmpty else { return nil }
        let title = resolver.resolve(descriptor.careerWind.titleToken)
        let effects = descriptor.effectTokens.map(resolver.resolve).joined(separator: " · ")
        return resolver.resolve(.relationshipWindLine(title: title, effects: effects))
    }

    static func localizedRelationshipEventAccessibility(
        speaker: String,
        name: String,
        title: String,
        primaryText: String,
        summary: String,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            .relationshipAccessibilityEvent(
                speaker: speaker,
                name: name,
                title: title,
                primaryText: primaryText,
                summary: summary
            )
        )
    }

    static func localizedRelationshipChoiceAccessibility(
        title: String,
        detail: String,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(.relationshipAccessibilityChoice(title: title, detail: detail))
    }

    private static func descriptorForRival(_ rival: RivalSnapshot) -> RivalPresentationCopyDescriptor {
        RivalPresentationCatalog.descriptor(for: rival.id)
    }

    static func focusDetail(_ focus: TrainingFocus) -> String {
        switch focus {
        case .velocity: "구위가 오릅니다. 직구가 빨라지고 헛스윙이 늘어납니다. 피로가 큽니다."
        case .command: "제구가 오릅니다."
        case .breakingBall: "변화구가 오릅니다. 공이 더 꺾이고 떨어집니다."
        case .stamina: "체력이 오릅니다."
        case .recovery: "피로가 줄고 팔 상태가 회복됩니다."
        case .gamePlanning: "포수와의 호흡과 승부 판단이 좋아집니다."
        }
    }

    static func localizedFocusDetail(_ focus: TrainingFocus, resolver: GameCopyResolver) -> String {
        resolver.resolve(focus.detailCopyToken)
    }

    static func localizedFocusTradeoff(_ focus: TrainingFocus, resolver: GameCopyResolver) -> String {
        resolver.resolve(focus.tradeoffCopyToken)
    }

    static func localizedFocusMetric(_ focus: TrainingFocus, resolver: GameCopyResolver) -> String {
        resolver.resolve(focus.metricCopyToken)
    }

    static func focusSymbol(_ focus: TrainingFocus) -> String {
        switch focus {
        case .velocity: "flame"
        case .command: "scope"
        case .breakingBall: "tornado"
        case .stamina: "figure.run"
        case .recovery: "bed.double"
        case .gamePlanning: "brain.head.profile"
        }
    }

    /// 강도 이름. **무엇을 하느냐에 따라 달라진다.**
    ///
    /// "회복을 몰아붙이기로 한다"는 말이 안 된다. 계산상으로는 뜻이 있다 — 회복은 피로를
    /// 18 줄이고 강도가 그만큼 도로 쌓으므로, 몰아붙이면 실제로 3만 회복된다. 즉 "쉬면서
    /// 얼마나 몸을 쓰느냐"다. 그러면 그렇게 불러야 한다.
    static func intensity(_ level: TrainingIntensity, focus: TrainingFocus) -> String {
        guard focus == .recovery else { return intensity(level) }
        switch level {
        case .light: return "푹 쉰다"
        case .standard: return "가볍게 몸만 푼다"
        case .intensive: return "쉬면서도 던진다"
        }
    }

    static func intensity(_ intensity: TrainingIntensity) -> String {
        switch intensity {
        case .light: "가볍게"
        case .standard: "보통"
        case .intensive: "몰아붙이기"
        }
    }

    static func localized(
        _ intensity: TrainingIntensity,
        focus: TrainingFocus,
        resolver: GameCopyResolver
    ) -> String {
        focus == .recovery
            ? resolver.resolve(intensity.recoveryCopyToken)
            : resolver.resolve(intensity.displayCopyToken)
    }

    static func localizedOutlook(
        _ outlook: HighSchoolCareerEngine.TrainingGrowthOutlook,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(outlook.detailCopyToken)
    }

    /// 대화 응답 문구. **상황에 따라 달라진다.**
    ///
    /// 코어의 판정은 세 가지 태도(듣는다·설명한다·증명한다) 위에 서 있고 그건 그대로 둔다.
    /// 바뀌는 건 말이다. 예전에는 부모님 전화에도 "다음 승부로 증명한다"가 붙었는데,
    /// 전화기에 대고 할 말이 아니다. 같은 태도라도 상대가 감독인지 부모인지 기자인지에
    /// 따라 사람은 다르게 말한다.
    static func response(_ response: RelationshipResponse, category: String) -> String {
        switch category {
        case "life":
            switch response {
            case .listen: "끝까지 듣는다"
            case .explain: "내 생각을 솔직히 말한다"
            case .challenge: "걱정 마시라고 말한다"
            }
        case "coach":
            switch response {
            case .listen: "지시를 그대로 받는다"
            case .explain: "내 판단을 말해 본다"
            case .challenge: "다음 등판으로 보여드리겠다고 한다"
            }
        case "catcher":
            switch response {
            case .listen: "포수 리드에 맡긴다"
            case .explain: "던지고 싶은 공을 설명한다"
            case .challenge: "내 공을 믿어 달라고 한다"
            }
        case "rival":
            switch response {
            case .listen: "말을 아낀다"
            case .explain: "실력은 실력으로 가리자고 한다"
            case .challenge: "다음 승부에서 보자고 한다"
            }
        case "media", "fan":
            switch response {
            case .listen: "질문을 끝까지 듣는다"
            case .explain: "지금 하는 준비를 설명한다"
            case .challenge: "기록으로 답하겠다고 한다"
            }
        case "health":
            switch response {
            case .listen: "코치에게 알리고 쉰다"
            case .explain: "상태를 정확히 설명한다"
            case .challenge: "괜찮다고 하고 계속 던진다"
            }
        case "team":
            switch response {
            case .listen: "동료의 말을 먼저 듣는다"
            case .explain: "내 입장을 설명한다"
            case .challenge: "결과로 정리하자고 한다"
            }
        case "draft":
            switch response {
            case .listen: "평가를 그대로 듣는다"
            case .explain: "내가 준비한 것을 말한다"
            case .challenge: "남은 경기로 뒤집겠다고 한다"
            }
        default:
            switch response {
            case .listen: "먼저 듣는다"
            case .explain: "내 생각을 말한다"
            case .challenge: "다음 승부로 증명한다"
            }
        }
    }

    static func responseDetail(_ response: RelationshipResponse) -> String {
        switch response {
        case .listen: "상대와의 믿음을 쌓는 가장 안전한 선택입니다."
        case .explain: "믿음이 오르고 관련 능력이 조금 오릅니다."
        case .challenge: "위험하지만 성공하면 능력이 크게 오릅니다."
        }
    }

    static func localized(
        _ response: RelationshipResponse,
        category: String,
        resolver: GameCopyResolver
    ) -> String {
        if resolver.language == .korean {
            return Self.response(response, category: category)
        }
        return resolver.resolve(response.displayCopyToken)
    }

    static func armHealth(_ state: ArmHealthState) -> (label: String, tone: BaseballCardTone) {
        switch state {
        case .normal: ("팔 상태 정상", .positive)
        case .caution: ("팔에 부담이 쌓임", .warning)
        case .warning: ("팔 상태 경고", .negative)
        case .recovering: ("회복 중", .raised)
        }
    }

    static func localizedArmHealth(
        _ state: ArmHealthState,
        resolver: GameCopyResolver
    ) -> (label: String, tone: BaseballCardTone) {
        let tone: BaseballCardTone = switch state {
        case .normal: .positive
        case .caution: .warning
        case .warning: .negative
        case .recovering: .raised
        }
        return (resolver.resolve(state.displayCopyToken), tone)
    }

    static func localizedOpportunityReason(
        _ opportunity: TrainingOpportunitySnapshot,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(opportunity.copyDescriptor.token)
    }

    static func localizedTrainingResultTitle(
        _ receipt: HighSchoolCareerStore.TrainingReceipt,
        resolver: GameCopyResolver
    ) -> String {
        if receipt.bloom != nil {
            return resolver.resolve(AppCopyKey.trainingResultTitleBloom)
        }
        if receipt.jackpot {
            return resolver.resolve(AppCopyKey.trainingResultTitleJackpot)
        }
        return receipt.gains.contains { $0.after > $0.before }
            ? resolver.resolve(AppCopyKey.trainingResultTitleGrowth)
            : resolver.resolve(AppCopyKey.trainingResultTitleNoGrowth)
    }

    static func localizedTrainingResultHeadline(
        _ receipt: HighSchoolCareerStore.TrainingReceipt,
        resolver: GameCopyResolver
    ) -> String {
        let gains = receipt.gains.filter { $0.after > $0.before }
        guard !gains.isEmpty else {
            return resolver.resolve(AppCopyKey.trainingResultHeadlineNoGain)
        }
        return gains.map { gain in
            resolver.resolve(
                AppCopyKey.trainingResultGainValue,
                arguments: [
                    .userText(resolver.resolve(gain.ability.displayCopyToken)),
                    .integer(gain.after - gain.before),
                ]
            )
        }.joined(separator: " · ")
    }

    static func localizedTrainingGainRow(
        _ gain: MobileCareerStore.AbilityGain,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.trainingResultGainRow,
            arguments: [
                .userText(resolver.resolve(gain.ability.displayCopyToken)),
                .integer(gain.before),
                .integer(gain.after),
            ]
        )
    }

    static func localizedTrainingResultBloom(
        _ bloom: HighSchoolCareerStore.Bloom,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            GameCopyKey.gameContent("content.training-result.bloom-headline"),
            arguments: [
                .userText(resolver.resolve(bloom.ability.displayCopyToken)),
                .userText(resolver.resolve(bloom.grade.displayCopyToken)),
                .integer(bloom.grade.ceiling),
            ]
        )
    }

    static func localizedTrainingResultDetail(
        _ receipt: HighSchoolCareerStore.TrainingReceipt,
        resolver: GameCopyResolver
    ) -> String {
        // Korean receipts are already the shipped Korean copy, including dynamic rehab and
        // talent-wall wording. Preserve that behavior verbatim; the English branch below is
        // the strict semantic reauthoring boundary and never interpolates the raw sentence.
        if resolver.language == .korean {
            return receipt.detail
        }

        let base: String
        if let repeatCount = receipt.repeatCount {
            base = resolver.resolve(
                GameCopyKey.gameContent("content.training-result.detail.repeat"),
                arguments: [
                    .userText(resolver.resolve(receipt.focus.displayCopyToken)),
                    .integer(repeatCount),
                ]
            )
        } else if let bloom = receipt.bloom {
            base = localizedTrainingResultBloom(bloom, resolver: resolver)
        } else if receipt.detail.contains("재능의 한계") {
            base = resolver.resolve(
                GameCopyKey.gameContent("content.training-result.detail.blocked"),
                arguments: [
                    .userText(resolver.resolve(TalentAbility.from(receipt.focus).displayCopyToken)),
                ]
            )
        } else if receipt.detail.hasPrefix("재활 훈련으로 팔 상태를 회복합니다.") {
            base = resolver.resolve(GameCopyKey.gameContent("content.training-result.detail.rehab"))
        } else if receipt.growth > 0 {
            let metric = resolver.resolve(receipt.focus.metricCopyToken)
            if receipt.fatigueChange < 0 {
                base = resolver.resolve(
                    GameCopyKey.gameContent("content.training-result.detail.growth-recovery"),
                    arguments: [
                        .userText(metric),
                        .integer(receipt.growth),
                        .integer(-receipt.fatigueChange),
                    ]
                )
            } else {
                base = resolver.resolve(
                    GameCopyKey.gameContent("content.training-result.detail.growth"),
                    arguments: [.userText(metric), .integer(receipt.growth)]
                )
            }
        } else if receipt.focus == .recovery, receipt.fatigueChange < 0 {
            base = resolver.resolve(
                GameCopyKey.gameContent("content.training-result.detail.recovery"),
                arguments: [.integer(-receipt.fatigueChange)]
            )
        } else if knownNoGrowthFeedback.contains(receipt.detail) {
            base = resolver.resolve(GameCopyKey.gameContent("content.training-result.detail.no-growth"))
        } else if receipt.detail.isEmpty || receipt.detail == "훈련을 마쳤습니다." {
            base = resolver.resolve(GameCopyKey.gameContent("content.training-result.detail.unknown"))
        } else {
            // A future or corrupted legacy sentence is deliberately not interpolated. The
            // structured result above is the only source allowed into English rendering.
            base = resolver.resolve(GameCopyKey.gameContent("content.training-result.detail.unknown"))
        }

        guard receipt.jackpot else { return base }
        return resolver.resolve(
            GameCopyKey.gameContent("content.training-result.detail.jackpot"),
            arguments: [.userText(base)]
        )
    }

    /// The engine still stores Korean feedback in legacy-compatible snapshots. Keep the
    /// English boundary strict: only the six current authored no-growth sentences may select
    /// the semantic no-growth token; arbitrary legacy text remains the neutral fallback.
    private static let knownNoGrowthFeedback: Set<String> = [
        "오늘은 공 끝의 힘이 달라지지 않았습니다. 다음에는 투구 수나 강도를 조절해 볼 수 있습니다.",
        "미트에서 벗어나는 폭이 그대로입니다. 낮은 강도로 릴리스 지점을 먼저 맞춰 볼 수 있습니다.",
        "회전축이 손에 붙지 않았습니다. 그립과 손목 각도를 다시 잡아 볼 수 있습니다.",
        "후반 동작이 버티는 시간은 그대로입니다. 훈련 강도와 휴식 간격을 바꿔 볼 수 있습니다.",
        "몸의 무거움이 충분히 가시지 않았습니다. 다음 일정도 회복 간격을 남겨 두는 편이 좋습니다.",
        "타자 반응을 읽는 속도가 아직 공 배합으로 이어지지 않았습니다. 영상 범위를 좁혀 다시 볼 수 있습니다.",
    ]

    static func localizedTrainingFatigue(
        _ receipt: HighSchoolCareerStore.TrainingReceipt,
        resolver: GameCopyResolver
    ) -> String {
        if receipt.fatigueChange == 0 {
            return resolver.resolve(
                AppCopyKey.trainingResultFatigueSteady,
                arguments: [.integer(receipt.fatigueAfter)]
            )
        }
        return resolver.resolve(
            AppCopyKey.trainingResultFatigueChanged,
            arguments: [.integer(receipt.fatigueAfter), .integer(receipt.fatigueChange)]
        )
    }

    static func karma(_ karma: KarmaID) -> (title: String, detail: String) {
        switch karma {
        case .unknownLand: ("낯선 땅", "연고가 없는 지역에서 시작합니다.")
        case .stubbornCoach: ("고집 센 감독", "감독의 믿음을 얻기가 어렵습니다.")
        case .singleWeapon: ("단 하나의 무기", "구종 하나에만 기댈 수 있습니다.")
        case .geniusGeneration: ("천재들의 세대", "같은 학년에 뛰어난 투수가 많습니다.")
        case .erasedMemory: ("지워진 기억", "가져갈 기억 카드가 줄어듭니다.")
        case .noLastChance: ("마지막 기회는 없다", "부상 한 번이 커리어를 끝낼 수 있습니다.")
        }
    }

    static func awakening(_ id: AwakeningID) -> (title: String, detail: String) {
        switch id {
        case .explosiveFastball: ("폭발하는 포심", "구위 +4 · 제구 -2 · 직구 구속과 헛스윙 증가")
        case .pinpointEdge: ("바늘끝 제구", "제구 +4 · 구위 -1 · 스트라이크존 끝 제구 향상")
        case .disappearingBreaker: ("사라지는 변화구", "변화구 +4 · 제구 -1 · 변화구 헛스윙 증가")
        case .ironArm: ("강철의 어깨", "체력 +5 · 변화구 -1 · 공마다 쌓이는 피로 감소")
        case .calmUnderPressure: ("고요한 마운드", "제구 +2 · 체력 +1 · 주자가 있을 때 제구 향상")
        case .batterySync: ("포수와 한마음", "제구 +2 · 변화구 +1 · 빗맞은 타구 증가")
        case .risingFourSeam: ("떠오르는 포심", "직구의 위력과 헛스윙 증가 · 변화구 -1")
        case .sinkerTunnel: ("같은 길에서 갈라지는 공", "변화구 +3 · 직구와 체인지업의 빗맞은 타구 증가")
        case .frozenChangeup: ("멈춘 체인지업", "체인지업 궤적·헛스윙 상승 · 체력 -1")
        case .sweepingSlider: ("스위퍼 궤도", "변화구 +4 · 제구 -1 · 슬라이더 헛스윙 증가")
        case .curveballClock: ("일정한 커브 타이밍", "변화구 +4 · 체력 -1 · 커브 헛스윙 증가")
        case .repeatableRelease: ("흔들리지 않는 투구 동작", "제구 +4 · 구위 -1 · 모든 구종의 제구 향상")
        case .pickoffRhythm: ("주자를 묶는 리듬", "제구 +1 · 체력 +2 · 주자가 있을 때 흔들림 감소")
        case .twoStrikePlan: ("2스트라이크 승부법", "제구·변화구 +2 · 체력 -1 · 변화구 헛스윙 증가")
        case .firstPitchStrike: ("초구 스트라이크", "제구 +3 · 체력 -1 · 초구 스트라이크 증가")
        case .trafficController: ("주자를 두고도 침착하게", "제구·체력 +2 · 구위 -1 · 빗맞은 타구 증가")
        case .lateInningReserve: ("후반에도 남는 힘", "체력 +4 · 공마다 쌓이는 피로 감소")
        case .scoutComposure: ("압박 속 침착함", "구위·제구 +2 · 체력 -1")
        }
    }

    // MARK: - Awakening skill tree localization boundary

    /// The legacy Korean tuple above remains available to non-migrated clients. The scoped iOS
    /// skill-tree surface resolves the same stable IDs through GameContent instead.
    static func localizedAwakeningTitle(
        _ id: AwakeningID,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(id.titleCopyToken)
    }

    static func localizedAwakeningDetail(
        _ id: AwakeningID,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(id.detailCopyToken)
    }

    static func localizedAwakeningBranchTitle(
        _ branch: AwakeningTree.Branch,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(branch.titleCopyToken)
    }

    static func localizedAwakeningBranchDetail(
        _ branch: AwakeningTree.Branch,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(branch.detailCopyToken)
    }

    static func localizedAwakeningReadOnlySummary(
        selectedCount: Int,
        total: Int,
        resolver: GameCopyResolver
    ) -> String {
        guard selectedCount > 0 else {
            return resolver.resolve(AppCopyKey.awakeningReadOnlyEmpty)
        }
        return resolver.resolve(
            AppCopyKey.awakeningReadOnlyProgress,
            arguments: [
                .integer(selectedCount),
                .integer(total),
                .integer(max(0, total - selectedCount)),
            ]
        )
    }

    static func localizedAwakeningCounter(
        total: Int,
        current: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.awakeningCounter,
            arguments: [.integer(total), .integer(current)]
        )
    }

    static func localizedAwakeningSelectionGuidance(
        total: Int,
        selectedCount: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.awakeningSelectionGuidance,
            arguments: [.integer(max(0, total - selectedCount - 1))]
        )
    }

    static func localizedAwakeningSpark(
        sparks: Int?,
        beforeFirstGame: Bool,
        resolver: GameCopyResolver
    ) -> (text: String, tone: BaseballCardTone) {
        if (sparks ?? AwakeningTree.leapSparks) >= AwakeningTree.leapSparks {
            return (
                resolver.resolve(AppCopyKey.awakeningSparkLeaps),
                .milestone
            )
        }
        if beforeFirstGame {
            return (
                resolver.resolve(AppCopyKey.awakeningSparkBeforeFirstGame),
                .standard
            )
        }
        return (
            resolver.resolve(AppCopyKey.awakeningSparkNeedsProof),
            .standard
        )
    }

    static func localizedAwakeningConfirmationTitle(
        _ id: AwakeningID,
        resolver: GameCopyResolver
    ) -> String {
        let title = localizedAwakeningTitle(id, resolver: resolver)
        let subject = resolver.language == .korean
            ? "'\(title)'\(KoreanCopy.ro(title))"
            : "'\(title)'"
        return resolver.resolve(
            AppCopyKey.awakeningConfirmationTitle,
            arguments: [.userText(subject)]
        )
    }

    static func localizedAwakeningConfirmationMessage(
        _ id: AwakeningID,
        resolver: GameCopyResolver
    ) -> String {
        let node = AwakeningTree.node(id)
        return resolver.resolve(
            AppCopyKey.awakeningConfirmationMessage,
            arguments: [
                .userText(localizedAwakeningBranchTitle(node.branch, resolver: resolver)),
                .integer(node.tier),
                .userText(localizedAwakeningDetail(id, resolver: resolver)),
            ]
        )
    }

    static func localizedAwakeningBranchCardTitle(
        _ branch: AwakeningTree.Branch,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.awakeningBranchTitle,
            arguments: [.userText(localizedAwakeningBranchTitle(branch, resolver: resolver))]
        )
    }

    static func localizedAwakeningSelectedCount(
        _ count: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.awakeningBranchSelectedCount,
            arguments: [.integer(count)]
        )
    }

    static func localizedAwakeningTierLabel(
        _ tier: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(AppCopyKey.awakeningTierLabel, arguments: [.integer(tier)])
    }

    static func localizedAwakeningActionLabel(
        readOnly: Bool,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(readOnly ? AppCopyKey.awakeningNextLabel : AppCopyKey.awakeningSelectLabel)
    }

    static func localizedAwakeningLeapLabel(resolver: GameCopyResolver) -> String {
        resolver.resolve(AppCopyKey.awakeningLeapLabel)
    }

    static func localizedAwakeningLockReason(
        _ node: AwakeningTree.Node,
        selected: [AwakeningID],
        resolver: GameCopyResolver
    ) -> String? {
        let taken = Set(selected)
        let missing = node.parents.filter { !taken.contains($0) }
        guard !missing.isEmpty else { return nil }
        let names = missing
            .map { localizedAwakeningTitle($0, resolver: resolver) }
            .joined(separator: " · ")
        return resolver.resolve(
            AppCopyKey.awakeningLockReason,
            arguments: [.userText(names)]
        )
    }

    static func localizedAwakeningNodeVoiceLabel(
        _ node: AwakeningTree.Node,
        owned: Bool,
        open: Bool,
        readOnly: Bool,
        selected: [AwakeningID],
        resolver: GameCopyResolver
    ) -> String {
        let argumentsBase: [LocalizedCopyArgument] = [
            .userText(localizedAwakeningBranchTitle(node.branch, resolver: resolver)),
            .integer(node.tier),
            .userText(localizedAwakeningTitle(node.id, resolver: resolver)),
        ]
        if owned {
            return resolver.resolve(
                AppCopyKey.awakeningNodeVoiceOwned,
                arguments: argumentsBase
            )
        }
        if open {
            let key = readOnly
                ? AppCopyKey.awakeningNodeVoiceAvailableNext
                : AppCopyKey.awakeningNodeVoiceAvailableNow
            return resolver.resolve(
                key,
                arguments: argumentsBase + [
                    .userText(localizedAwakeningDetail(node.id, resolver: resolver)),
                ]
            )
        }
        return resolver.resolve(
            AppCopyKey.awakeningNodeVoiceLocked,
            arguments: argumentsBase + [
                .userText(
                    localizedAwakeningLockReason(node, selected: selected, resolver: resolver) ?? ""
                ),
            ]
        )
    }

    static func localizedAwakeningSummaryTitle(
        selectedCount: Int,
        total: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.awakeningSummaryTitle,
            arguments: [.integer(selectedCount), .integer(total)]
        )
    }

    static func localizedAwakeningSummaryEmpty(resolver: GameCopyResolver) -> String {
        resolver.resolve(AppCopyKey.awakeningSummaryEmpty)
    }

    static func memory(_ id: MemoryCardID) -> (title: String, detail: String) {
        switch id {
        case .velocityBlueprint: ("직구 구속 훈련법", "직구 구속·헛스윙 증가, 제구 소폭 감소")
        case .fingertipMemory: ("손끝의 기억", "변화구 움직임 상승, 체력 소폭 감소")
        case .catcherNotebook: ("포수의 노트", "제구와 빗맞은 타구 유도 증가")
        case .rivalNotebook: ("라이벌 노트", "제구·변화구와 변화구 헛스윙 증가")
        case .recoveryRoutine: ("회복 방법", "체력 상승, 공마다 피로 소모 감소")
        case .pressureRehearsal: ("압박의 예행연습", "제구·체력과 위기 상황 제구 향상")
        case .firstPitchMap: ("초구 지도", "초구 제구 상승, 체력 소폭 감소")
        case .twoStrikeSequence: ("2스트라이크 구종 순서", "변화구 움직임·헛스윙 상승, 체력 소폭 감소")
        case .fatigueDiary: ("피로 일지", "체력과 후반 제구 상승")
        case .mechanicsVideo: ("투구 동작 교정 영상", "제구 향상, 공의 최고 위력 소폭 감소")
        case .schoolPlaybook: ("학교에서 배운 승부법", "제구·변화구 향상")
        case .coachLetter: ("코치의 편지", "제구·체력 향상")
        case .draftReport: ("구단 평가표", "구위·제구 향상")
        case .stadiumEcho: ("구장의 메아리", "구위·헛스윙 증가, 제구 소폭 감소")
        case .teamFirstPromise: ("팀을 위한 약속", "제구·체력과 빗맞은 타구 유도 증가")
        case .failureScorebook: ("실패의 스코어북", "제구·변화구 향상, 체력 소폭 감소")
        case .winterProgram: ("겨울 훈련표", "구위·체력 향상, 피로 누적 감소")
        case .bullpenCompass: ("불펜의 나침반", "구위·체력 향상, 피로 누적 감소")
        }
    }

    // MARK: - 승부 장면 파생

    /// 고교 후속 타순. 기본은 기존 세 타자를 유지하고, 긴 승부 장면만 다섯 타자까지
    /// 요청한다. 같은 seed/count는 언제나 같은 타순이라 저장 복구와 재현성이 흔들리지 않는다.
    static func followUpBatters(seedText: String, count: Int = 3) -> [BatterSnapshot] {
        var rng = SplitMix64(seed: seedValue(seedText))
        let names = ["구본휘", "설재빈", "천유겸", "봉시원", "옥준서", "석다온"]
        var used: Set<String> = []
        return (0..<min(max(0, count), names.count)).map { slot in
            var name = names[rng.nextInt(upperBound: names.count)]
            var attempts = 0
            while used.contains(name), attempts < names.count {
                name = names[rng.nextInt(upperBound: names.count)]
                attempts += 1
            }
            used.insert(name)
            return BatterSnapshot(
                id: "hs-lineup-\(slot)",
                name: name,
                // 고교 타자는 프로보다 낮고 편차가 크다.
                //
                // 기본선을 34/32/32에서 45/43/43으로 올렸다. 예전 타순은 평균 44 언저리라
                // 성장한 투수 앞에서 사실상 아웃 자판기였다 — 환생 한 번 없이 3~4경기
                // 연속 무실점이 나온 실제 원인이다. 지금도 평균은 프로 기준(50) 아래이고
                // 편차도 그대로지만, 라이벌 뒤의 타순이 실점을 만들 수 있다.
                //
                // 여기서 더 올리지 않는 이유: 실측에서 이 값은 지명률을 능력 +1당 약
                // 1%p밖에 못 움직인다(60시드에서 52/50/50 → 43%, 60/58/58 → 35%).
                // 목표치까지 밀려면 고교 타자가 프로 평균보다 강해져야 해서 설정이 깨진다.
                // 관문의 높이는 `draftThreshold`가 맡는다.
                contact: 45 + rng.nextInt(upperBound: 24),
                discipline: 43 + rng.nextInt(upperBound: 24),
                power: 43 + rng.nextInt(upperBound: 26),
                batSide: rng.nextInt(upperBound: 3) == 0 ? .left : .right
            )
        }
    }

    /// 우리 학교 수비. 고교라 프로보다 낮다.
    static func defense(schoolID: SchoolID?) -> DefenseSnapshot {
        var rng = SplitMix64(seed: seedValue("hs-defense|\(schoolID?.rawValue ?? "none")"))
        let names = ["유시환", "임태오", "나건우", "배준서", "하민규", "조유찬", "신태양", "도경훈"]
        let positions: [FielderPosition] = [
            .catcher, .firstBase, .secondBase, .shortstop, .leftField, .centerField, .rightField, .thirdBase
        ]
        var fielders = [FielderSnapshot(id: "f-p", name: "본인", position: .pitcher, range: 40, glove: 44, arm: 52)]
        for (index, position) in positions.enumerated() {
            fielders.append(
                FielderSnapshot(
                    id: "f-\(position.rawValue)",
                    name: names[index],
                    position: position,
                    range: 34 + rng.nextInt(upperBound: 22),
                    glove: 34 + rng.nextInt(upperBound: 22),
                    arm: 34 + rng.nextInt(upperBound: 24)
                )
            )
        }
        return DefenseSnapshot(infield: 44, outfield: 42, arm: 45, fielders: fielders)
    }

    /// 라이벌 스카우팅. 정보 명료도가 낮은 회차일수록 처음의 확신이 낮다.
    static func scouting(rival: RivalSnapshot, clarity: DifficultyLevel) -> BatterScoutingSnapshot {
        let powerHitter = rival.power >= 55
        let baseline: Int
        switch clarity {
        case .relaxed: baseline = 100
        case .standard: baseline = 45
        case .challenging: baseline = 22
        }
        return BatterScoutingSnapshot(
            hotZone: powerHitter ? PitchZone(row: 1, column: 1) : PitchZone(row: 1, column: 0),
            coldZone: powerHitter ? PitchZone(row: 2, column: 2) : PitchZone(row: 0, column: 2),
            pitchStrength: rival.contact >= 55 ? .slider : .fourSeam,
            pitchWeakness: powerHitter ? .changeup : .curveball,
            chaseTendency: min(80, max(20, 50 - (rival.discipline - 50))),
            reliability: baseline
        )
    }

    /// FNV-1a. 코어의 `StableHash`는 internal이라 셸에서 쓸 수 없어 같은 식을 여기에 둔다.
    private static func summaryCaptures(_ value: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let fullRange = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: fullRange) else { return nil }
        return (1..<match.numberOfRanges).compactMap { index in
            Range(match.range(at: index), in: value).map { String(value[$0]) }
        }
    }

    private static func chapterGoalFrame(koreanTitle: String) -> ChapterGoal.Frame? {
        switch koreanTitle {
        case "감독의 숙제": .coachAssignment
        case "스카우트의 시선": .scoutAttention
        case "포수의 내기": .catcherBet
        case "나와의 약속": .personalPromise
        default: nil
        }
    }

    private static func seedValue(_ value: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return hash
    }
}
